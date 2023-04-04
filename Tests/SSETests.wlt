Needs["ConnorGray`ServerSentEventUtils`"]


(*=================================================*)
(* Test: CreateChunkToServerSentEventGenerator *)
(*=================================================*)

Module[{
	generator = CreateChunkToServerSentEventGenerator[]
},
	VerificationTest[
		generator["data:"]
		,
		Missing["IncompleteData"]
	];

	VerificationTest[
		generator[" foo\n"]
		,
		Missing["IncompleteData"]
	];

	VerificationTest[
		generator["\n"]
		,
		{<|"Data" -> "foo"|>}
	];
]

(*===========================================*)
(* Test: ServerSentEventBodyChunkTransformer *)
(*===========================================*)

$events = {}
$func = ServerSentEventBodyChunkTransformer[event |-> AppendTo[$events, event]]

VerificationTest[
	{
		$func[<| "BodyChunk" -> "data: " |>],
		$events
	}
	,
	{Null, {}}
]

VerificationTest[
	{
		$func[<| "BodyChunk" -> "foo\n" |>],
		$events
	}
	,
	{Null, {}}
]

VerificationTest[
	{
		$func[<| "BodyChunk" -> "\n\n" |>],
		$events
	}
	,
	{Null, {<| "Data" -> "foo" |>}}
]