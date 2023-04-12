Needs["Wolfram`LLMTools`Chatbook`Streaming`"]

(*====================================*)

content[str_?StringQ] :=
	<|
		"choices" -> {
			<| "delta" -> <| "content" -> str|> |>
		}
	|>;

(*===============================================*)
(* Test: CreateChatEventToOutputEventGenerator[] *)
(*===============================================*)

Module[{
	generator = CreateChatEventToOutputEventGenerator[]
},
	VerificationTest[generator[content["Hello\n"]],   {"Write"["Hello"], "Write"["\n"]}];
	VerificationTest[generator[content["world"]],     {"Write"["world"]}];
]

(*====================================*)

Module[{
	generator = CreateChatEventToOutputEventGenerator[]
},
	VerificationTest[
		generator[content["Hello\nworld"]],
		{
			"Write"["Hello"], "Write"["\nworld"],
			(* FIXME: This test output seems incorrect... what causes all
				these empty writes, and why don't they go on forever? *)
			"Write"[""], "Write"[""], "Write"[""], "Write"[""], "Write"[""]
		}
	];
]

(*====================================*)

Module[{
	generator = CreateChatEventToOutputEventGenerator[]
},
	VerificationTest[generator[content["``"]],             Missing["IncompleteData"]];
	VerificationTest[generator[content["`wolfram\n"]],     {"BeginCodeBlock"["wolfram"]}];
	VerificationTest[generator[content["2+2\n"]],          {"Write"["2+2"], "Write"["\n"]}];
	VerificationTest[generator[content["``"]],             Missing["IncompleteData"]];
	(* TODO: Test what happens if this event doens't have a newline. *)
	VerificationTest[generator[content["`\n"]],            {"BeginText"}];
]
