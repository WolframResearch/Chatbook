BeginPackage["Wolfram`LLMTools`APIFunctions`"]

ImageSynthesize
TextSynthesize
CreateChat
ChatEvaluate
ChatObject
ChatObjectQ

Needs["Wolfram`LLMTools`APIFunctions`Chat`"]
Needs["Wolfram`LLMTools`APIFunctions`ImageSynthesize`"]
Needs["Wolfram`LLMTools`APIFunctions`TextSynthesize`"]

(* error message copied from NeuralFunctions *)

ImageSynthesize::bdprompt = 
TextSynthesize::bdprompt = "The value of the text `1` is not a string."
ImageSynthesize::bdspec = "The value of the\
 specification `1` is not a string, an image or an valid association."
TextSynthesize::bdspec = "Valid property expected instead of `1`."
TextSynthesize::bdprop = "The property `1` should be one of: `2`."
ImageSynthesize::invbatch = "The value of the batch size specification `1` is\
 not an integer `2`."
TextSynthesize::invbatch = "The value of the batch size specification `1` is\
 not a positive integer."
ImageSynthesize::noopt =
TextSynthesize::noopt = "The option `1` is not implemented yet."
ImageSynthesize::bdopt =
TextSynthesize::bdopt = "The value `1` of the option `2` should be any of `3`."
TextSynthesize::invlim = "The value `1` of the option `2` is not a positive\
 integer or exceed the maximum allowed value `3`."
ImageSynthesize::noimg = "Seeding with an image is not implemented yet."

ImageSynthesize::bdauth =
TextSynthesize::bdauth =
CreateChat::bdauth =
ChatObject::bdauth = "Authentication method `1` is not available."
CreateChat::bdmethod = "Method `1` is not available."
ChatObject::deadcon = "The linked connection is not available anymore."

EndPackage[]