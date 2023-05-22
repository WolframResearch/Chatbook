Needs["Wolfram`Chatbook`ServerSentEventUtils`"]


(*=================================================*)
(* Test: CreateChunkToServerSentEventGenerator *)
(*=================================================*)

Module[{
	generator = CreateChunkToServerSentEventGenerator[]
},
	VerificationTest[
  generator["data:"],
  Missing["IncompleteData"],
  TestID -> "Untitled-7@@Tests/SSETests.wlt:11,2-15,2"
];

	VerificationTest[
  generator[" foo\n"],
  Missing["IncompleteData"],
  TestID -> "Untitled-8@@Tests/SSETests.wlt:17,2-21,2"
];

	VerificationTest[
  generator["\n"],
  {Association["Data" -> "foo"]},
  TestID -> "Untitled-9@@Tests/SSETests.wlt:23,2-27,2"
];
]

(*===========================================*)
(* Test: ServerSentEventBodyChunkTransformer *)
(*===========================================*)

$events = {}
$func = ServerSentEventBodyChunkTransformer[event |-> AppendTo[$events, event]]

VerificationTest[
  {$func[Association["BodyChunk" -> "data: "]], $events},
  {Null, {}},
  TestID -> "Untitled-10@@Tests/SSETests.wlt:37,1-41,2"
]

VerificationTest[
  {$func[Association["BodyChunk" -> "foo\n"]], $events},
  {Null, {}},
  TestID -> "Untitled-11@@Tests/SSETests.wlt:43,1-47,2"
]

VerificationTest[
  {$func[Association["BodyChunk" -> "\n\n"]], $events},
  {Null, {Association["Data" -> "foo"]}},
  TestID -> "Untitled-12@@Tests/SSETests.wlt:49,1-53,2"
]