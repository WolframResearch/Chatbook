BeginPackage["ConnorGray`ServerSentEventUtils`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[ServerSentEventBodyChunkTransformer, "
ServerSentEventBodyChunkTransformer[func$] transforms a sequence of raw recieved \
data chunks into a sequence of server-sent events.

ServerSentEventBodyChunkTransformer[func$] constructs a new function that can be \
used as the value of the \"BodyChunkRecieved\" handler of URLSubmit.

The inner func$ will be called once for each complete server-sent event that is \
recieved.
"]

GU`SetUsage[CreateChunkToServerSentEventGenerator, "
CreateChunkToServerSentEventGenerator[] returns a generator function, which
should be called with chunks of recieved string data, and will return either
Missing['IncompleteData'], or a list of parsed server-sent event structures.

The returned generator function is a closure that maintains internal state
between calls.
"]

Begin["`Private`"]

Needs["ConnorGray`Chatbook`ErrorUtils`"]

CreateErrorType[ServerSentEventError, {}]

(*====================================*)

SetFallthroughError[ServerSentEventBodyChunkTransformer]

(*
	See also: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events#event_stream_format
*)
ServerSentEventBodyChunkTransformer[func_] := Module[{
	$sseGenerator = CreateChunkToServerSentEventGenerator[]
},
	Function[args, Module[{
		chunk
	},
		chunk = ConfirmReplace[args["BodyChunk"], {
			c_?StringQ :> c,
			other_ :> Raise[
				ServerSentEventError,
				"Unexpected \"BodyChunk\" value: ``",
				InputForm[other]
			]
		}];

		Replace[$sseGenerator[chunk], {
			Missing["IncompleteData"] :> Null,
			events_?ListQ :> Scan[func, events],
			other_ :> Raise[
				ServerSentEventError,
				"Unexpected server-sent event generator result: ``",
				InputForm[other]
			]
		}];
	]]
]

(*====================================*)

SetFallthroughError[CreateChunkToServerSentEventGenerator]

CreateChunkToServerSentEventGenerator[] := Module[{
	(*
		This buffer is accumulated to across multiple calls to the
		generator function.

		This is necessary to support large events that are sent in multiple
		TCP packets (i.e. multiple "chunks"). In other works, a single
		server-sent event may require multiple chunks to be recieved before
		all of the event data has been recieved.
	*)
	$buffer = ""
},
	Function[chunk, Catch @ Module[{
		pos,
		event,
		events = {}
	},
		(* FIXME: Handle EndOfFile as well, to generate an error if there was
			any remaining data in $buffer that couldn't be parsed as
			a complete server-sent event. *)
		If[!MatchQ[chunk, _?StringQ],
			Fail2[
				ServerSentEventError,
				"Invalid argument passed to server sent event generator: ``",
				InputForm[chunk]
			];
		];

		RaiseAssert[StringQ[$buffer]];

		$buffer = StringJoin[$buffer, chunk];

		(*
			If `buffer` doesn't contain a "\n\n" substring, then we haven't
			accumulated enough chunks to end the current message, so this loop
			won't run.
		*)
		While[(pos = StringPosition[$buffer, "\n\n", 1]) =!= {},
			pos = ConfirmReplace[pos, {{start_Integer, _}, ___} :> start];

			(* -1 so we don't include the first \n in `event`. *)
			event = StringTake[$buffer, pos - 1];

			(* +1 to include the second \n. *)
			$buffer = StringDrop[$buffer, pos + 1];

			(* Process the textual content of the event into an Association. *)
			event = Which[
				StringStartsQ[event, "data: "],
					<| "Data" -> StringDelete[event, StartOfString ~~ "data: "] |>,
				True,
					(* FIXME: Handle other types of event fields. *)
					Raise[
						ServerSentEventError,
						"Invalid server-sent event syntax: ``",
						InputForm[event]
					]
			];

			AppendTo[events, event];
		];

		If[events === {},
			(* We need to recieve more input chunks before we can proceed. *)
			Missing["IncompleteData"]
			,
			events
		]
	]]
]

(*====================================*)

End[]

EndPackage[]