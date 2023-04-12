BeginPackage["Wolfram`LLMTools`OpenAILink`Image`"];

Begin["`Private`"];

Needs["Wolfram`LLMTools`OpenAILink`"]
Needs["Wolfram`LLMTools`OpenAILink`Constants`"]
Needs["Wolfram`LLMTools`OpenAILink`Request`"]



(***********************************************************************************)
(******************************** OpenAIGenerateImage ********************************)
(***********************************************************************************)

(*
	OpenAIGenerateImage[prompt]
		creates an image from the specified prompt.

	OpenAIGenerateImage[prompt, n]
		creates a list of n images.
*)

Options[OpenAIGenerateImage] = {
	OpenAIKey  :> $OpenAIKey,
	OpenAIUser :> $OpenAIUser,
	ImageSize  -> Automatic
};

OpenAIGenerateImage[prompt_String, n_Integer, opts:OptionsPattern[]] :=
	Enclose[
		conformImages[
			OpenAIRequest[
				{"v1", "images", "generations"},
				Select[
					<|
						"prompt" -> prompt,
						"size" -> Confirm@conformImageSizeSpec[OptionValue[ImageSize]],
						"n" -> n,
						"response_format" -> "b64_json"
					|>,
					# =!= Automatic&
				],
				{opts},
				OpenAIGenerateImage
			]
		],
		"InheritedFailure"
	]

OpenAIGenerateImage[prompt_String, opts:OptionsPattern[]] :=
	Enclose[
		First@Confirm@OpenAIGenerateImage[prompt, 1, opts],
		"InheritedFailure"
	]


conformImageSizeSpec[spec_String] := spec
conformImageSizeSpec[Automatic] := Automatic
conformImageSizeSpec[Small] := "256x256"
conformImageSizeSpec[Medium] := "512x512"
conformImageSizeSpec[Large] := "1024x1024"
conformImageSizeSpec[{256,256}] := "256x256"
conformImageSizeSpec[{512,512}] := "512x512"
conformImageSizeSpec[{1024,1024}] := "1024x1024"
conformImageSizeSpec[n_Integer] := conformImageSizeSpec[{n,n}]
conformImageSizeSpec[spec_] :=
	(
		Message[OpenAIGenerateImage::invImageSize, spec];
		Failure["InvalidImageSize", <|
			"MessageTemplate" :> OpenAIGenerateImage::invImageSize,
			"MessageParameters" -> {spec},
			"ImageSizeSpecification" -> spec
		|>]
	)



conformImages[resp_] :=
	Enclose[
		conformSingleImage /@ Confirm[resp["data"]],
		invalidCreateImageResponse[resp]&
	]

conformImages[fail_?FailureQ] :=
	fail

conformSingleImage[imgResp_] :=
	Enclose[
		Confirm[ImportByteArray[ConfirmBy[BaseDecode[Confirm[imgResp["b64_json"]]], ByteArrayQ]], ImageQ],
		invalidCreateImageResponse[imgResp]&
	]


invalidCreateImageResponse[data_] :=
	(
		Message[OpenAIGenerateImage::invOpenAIGenerateImageResponse, data];
		Failure["InvalidOpenAIGenerateImageResponse", <|
			"MessageTemplate" :> OpenAIGenerateImage::invOpenAIGenerateImageResponse,
			"MessageParameters" -> {data}
		|>]
	)


End[];
EndPackage[];
