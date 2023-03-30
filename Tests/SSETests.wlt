Needs["ConnorGray`ServerSentEventUtils`"]

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