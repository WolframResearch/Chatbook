(*
	This file contains functions for working with streaming chat response
*)

BeginPackage["ConnorGray`Chatbook`Streaming`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[CreateChatEventToOutputEventGenerator, "
CreateChatEventToOutputEventGenerator[] returns a generator function, which
should be called with parsed chat server sent events, and will return either
Missing['IncompleteData'], or a list of parsed chat output event structures.

The returned generator function is a closure that maintains internal state
between calls.
"]


Begin["`Private`"]

Needs["ConnorGray`Chatbook`Errors`"]
Needs["ConnorGray`Chatbook`ErrorUtils`"]

(*========================================================*)

SetFallthroughError[CreateChatEventToOutputEventGenerator]

(*
	The returned generator function can currently return the following events:

		* "Write"["<...>"]
		* "BeginCodeBlock"["<spec>"]
		* "BeginText"
*)
CreateChatEventToOutputEventGenerator[] := Module[{
	$state
},
	$state["Buffer"] = "";
	$state["CurrentOutputType"] = None;

	$state[args___] := Raise[
		ChatbookError,
		"Invalid chat event to output event $state args: ``",
		{args}
	];

	Function[ssevent, handleChatEvent[$state, ssevent]]
]

(*------------------------------------*)

SetFallthroughError[handleChatEvent]

handleChatEvent[
	$state_Symbol,
	ssevent_?AssociationQ
] := Module[{
	data = ssevent,
	outputEvents = {}
},
	RaiseAssert[
		MatchQ[data, _?AssociationQ],
		"Unexpected chat streaming response JSON parse result: ``",
		InputForm[json]
	];

	data = ConfirmReplace[data, {
		KeyValuePattern[{
			(* TODO: What about other possible choices? *)
			"choices" -> {firstChoice_, ___}
		}] :> firstChoice,
		other_ :> Raise[
			ChatbookError,
			"Unexpected chat streaming response object form: ``",
			InputForm[other]
		]
	}];

	ConfirmReplace[data, {
		KeyValuePattern[{
			"delta" -> KeyValuePattern[{
				"content" -> text_?StringQ
			}]
		}] :> (
			(* Print["Chunk: ", InputForm[text]]; *)
			$state["Buffer"] = StringJoin[$state["Buffer"], text];
		),
		(* FIXME: Handle this change in role by changing cell type if necessary? *)
		KeyValuePattern[{
			"delta" -> KeyValuePattern[{
				"role" -> "assistant"
			}]
		}] :> Null,
		(* FIXME: Handle this streaming end better. *)
		KeyValuePattern[{
			"delta" -> <||>,
			"finish_reason" -> "stop"
		}] :> (
			(*
				If there is any remaining data in the buffer that wasn't
				written out, write it out now. This can happen if the last token
				is a string that is ambiguous to parse (e.g. "`").
			*)
			If[$state["Buffer"] =!= "",
				(* FIXME: Test this case. *)
				AppendTo[outputEvents, "Write"[$state["Buffer"]]];
				$state["Buffer"] = "";
			];
		),
		other_ :> Raise[
			ChatbookError,
			"Unexpected chat streaming response object form: ``",
			InputForm[other]
		]
	}];

	(*--------------------------------*)
	(* Process the buffer.            *)
	(*--------------------------------*)

	RaiseAssert[StringQ[$state["Buffer"]]];

	While[$state["Buffer"] =!= "",
		(* Print["Buffer => ", InputForm[$state["Buffer"]]]; *)

		RaiseAssert[StringQ[$state["Buffer"]]];

		StringReplace[$state["Buffer"], {
			StartOfString ~~ prefix:Repeated[Except["`" | "\n"]] ~~ rest___ ~~ EndOfString :> (
				AppendTo[outputEvents, "Write"[prefix]];
				$state["Buffer"] = rest;
			),
			(* Recognize incomplete input that might be a ``` code block start
				or end marker. *)
			StartOfString ~~ RepeatedNull["\n", 1] ~~ Repeated["`", {1, 2}] ~~ EndOfString :> (
				(*
					We don't have enough buffered data to know if we should
					start or end a code block or not. Break out of the buffer
					processing loop until we recieve more input.
				*)
				Break[];
			),
			(*--------------------------------------------------*)
			(* Recognize a ``` that starts or ends a code block *)
			(*--------------------------------------------------*)
			StartOfString
			~~ RepeatedNull["\n", 1] ~~ "```" ~~ spec:RepeatedNull[Except["`" | "\n"]]
			~~ RepeatedNull["\n", 1] ~~ rest___ ~~ EndOfString :> (
				ConfirmReplace[$state["CurrentOutputType"], {
					(* If we haven't written any cell yet, then this ``` must
						be the first thing sent from the LLM, so make the
						initial cell a code output cell. *)
					None :> (
						$state["CurrentOutputType"] = "Code";
						AppendTo[outputEvents, "BeginCodeBlock"[spec]];
					),
					(* If the current cell is a non-code cell, then this
						"```" must be starting a code block. *)
					"Text" :> (
						$state["CurrentOutputType"] = "Code";
						AppendTo[outputEvents, "BeginCodeBlock"[spec]];
					),
					(* If the current cell is a code cell, then this
						"```" must be ending a code block. *)
					"Code" :> (
						(* FIXME: This can fail if ChatGPT generates
							syntactically invalid Markdown output, which doesn't
							seem inconveivable. Maybe fail more gracefully if
							that happens? *)
						RaiseAssert[spec === ""];

						$state["CurrentOutputType"] = "Text";
						AppendTo[outputEvents, "BeginText"];
					)
				}];

				$state["Buffer"] = rest;
			),
			(* Write any other input out directly. *)
			_ :> (
				AppendTo[outputEvents, "Write"[$state["Buffer"]]];

				$state["Buffer"] = "";
			)
		}];
	];

	If[outputEvents === {},
		Missing["IncompleteData"]
		,
		outputEvents
	]
]

(*========================================================*)

End[]

EndPackage[]