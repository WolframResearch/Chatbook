BeginPackage["Wolfram`LLMTools`OpenAILink`Audio`"];

Begin["`Private`"];

Needs["Wolfram`LLMTools`OpenAILink`"]
Needs["Wolfram`LLMTools`OpenAILink`Constants`"]
Needs["Wolfram`LLMTools`OpenAILink`Request`"]



(***********************************************************************************)
(******************************** OpenAITranscribeAudio ****************************)
(***********************************************************************************)

(*
	OpenAITranscribeAudio[audio]
		transcribes audio.
*)

Options[OpenAITranscribeAudio] = {
	OpenAIKey  :> $OpenAIKey,
	OpenAIUser :> $OpenAIUser,
	OpenAITemperature -> 0,
	"Language" -> "en"
};

OpenAITranscribeAudio[audio_ ? AudioQ, prompt_String : Automatic, opts : OptionsPattern[]] :=
	Enclose[
		Confirm @ OpenAIRequest[
			{"v1", "audio", "transcriptions"},
			Select[
				<|
					"file" -> <|
						"Content" -> ExportByteArray[audio, "MP3"],
						"MIMEType" -> "audio/mp3",
						"Name" -> "wolfram_audio.mp3"
					|>,
					"model" -> "whisper-1",
					"prompt" -> prompt,
					"response_format" -> "json",
					"temperature" -> ConfirmBy[OptionValue[OpenAITemperature], Between[{0, 1}]],
					"language" -> ConfirmBy[First[Interpreter["Language"][OptionValue["Language"]]["Codes"]], StringQ]
				|>,
				# =!= Automatic &
			],
			{opts},
			OpenAITranscribeAudio
		]["text"],
		"InheritedFailure"
	]



(***********************************************************************************)
(******************************** OpenAITranslateAudio ****************************)
(***********************************************************************************)

(*
	OpenAITranslateAudio[audio]
		translates audio into English.
*)

Options[OpenAITranslateAudio] = {
	OpenAIKey  :> $OpenAIKey,
	OpenAIUser :> $OpenAIUser,
	OpenAITemperature -> 0
};

OpenAITranslateAudio[audio_ ? AudioQ, prompt_String : Automatic, opts : OptionsPattern[]] :=
	Enclose[
		Confirm @ OpenAIRequest[
			{"v1", "audio", "translations"},
			Select[
				<|
					"file" -> <|
						"Content" -> ExportByteArray[audio, "MP3"],
						"MIMEType" -> "audio/mp3",
						"Name" -> "wolfram_audio.mp3"
					|>,
					"model" -> "whisper-1",
					"prompt" -> prompt,
					"response_format" -> "json",
					"temperature" -> ConfirmBy[OptionValue[OpenAITemperature], Between[{0, 1}]]
				|>,
				# =!= Automatic &
			],
			{opts},
			OpenAITranslateAudio
		]["text"],
		"InheritedFailure"
	]


End[];
EndPackage[];
