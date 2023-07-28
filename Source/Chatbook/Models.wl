BeginPackage["Wolfram`Chatbook`Models`"]

Needs["GeneralUtilities`" -> None]


Begin["`Private`"]


Options[SetModel]={"SetLLMEvaluator"->True}

SetModel[args___]:=Catch[setModel[args],"SetModel"]

setModel[name_String,opts:OptionValue[SetModel]]:=setModel[$FrontEndSession,name,opts]

setModel[scope_,model_Association,opts:OptionValue[SetModel]]:=(
  Needs["GeneralUtilities`"];
  If[TrueQ[OptionValue["SetLLMEvaluator"]],
  	System`$LLMEvaluator=System`LLMConfiguration[System`$LLMEvaluator,model];
  ];
  CurrentValue[scope, TaggingRules] = 
  	GeneralUtilities`ToAssociations @CurrentValue[$FrontEndSession, TaggingRules];
  CurrentValue[scope, {TaggingRules, "ChatNotebookSettings"}] = Join[
		Replace[CurrentValue[scope, {TaggingRules, "ChatNotebookSettings"}],Except[_Association]-><||>,{0}],
		model
  ]
)

setModel[scope_,name_String,opts:OptionValue[SetModel]]:=Enclose[With[{model=ConfirmBy[standardizeModelName[name],StringQ]},
  Needs["GeneralUtilities`"];
  If[TrueQ[OptionValue["SetLLMEvaluator"]],
  	System`$LLMEvaluator=System`LLMConfiguration[System`$LLMEvaluator,<|"Model"->model|>];
  ];
  CurrentValue[scope, TaggingRules] = 
  	GeneralUtilities`ToAssociations @CurrentValue[$FrontEndSession, TaggingRules];
  CurrentValue[scope, {TaggingRules, "ChatNotebookSettings","Model"}] = model
]
]

standardizeModelName[gpt4_String]:="gpt-4"/;StringMatchQ[StringDelete[gpt4,WhitespaceCharacter|"-"|"_"],"gpt4",IgnoreCase->True]
standardizeModelName[gpt35_String]:="gpt-3.5-turbo"/;StringMatchQ[StringDelete[gpt35,WhitespaceCharacter|"-"|"_"],"gpt3.5"|"gpt3.5turbo",IgnoreCase->True]
standardizeModelName[name_String]:=name

End[]
EndPackage[]