(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`ContentSuggestions`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

$ContentSuggestions = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$suggestionsService             := $llmKitService;
$suggestionsAuthentication      := "LLMKit";
$stripWhitespace                 = True;
$defaultWLContextString          = "";
$finishReason                    = None;
$contentSuggestionsProgressWidth = 250;

$contentSuggestionsOverrides = <|
    "MaxCellStringLength"       -> 1000,
    "MaxOutputCellStringLength" -> 200
|>;

$maxContextTokens = <|
    "WL"       -> 2^12,
    "Text"     -> 2^12,
    "Notebook" -> 2^15
|>;

$inputStyle      = "Input";
$$inputStyle     = "Input"|"Code";
$$generatedStyle = "Echo"|"EchoAfter"|"EchoBefore"|"EchoTiming"|"Message"|"Output"|"Print";

$$whitespaceString = _String? (StringMatchQ[ WhitespaceCharacter... ])
$$whitespace       = $$whitespaceString | TextData @ $$whitespaceString | TextData @ { $$whitespaceString... };


(* TODO: stop tokens for resource notebooks:
    CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ResourceCreateNotebook" } ]
*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Wolfram Language Suggestions*)
$wlSuggestionsModel       = "gpt-4o";
$wlSuggestionsMultimodal  = False;
$wlSuggestionsCount       = 3;
$wlSuggestionsMaxTokens   = 128;
$wlSuggestionsTemperature = 0.9;
$wlPlaceholderString      = "\:2758";
$wlCellsBefore            = 25;
$wlCellsAfter             = 10;
$wlDocMaxItems            = 5;
$wlFilterDocResults       = False;
$wlFilteredDocCount       = 5;

$wlSuggestionsPrompt := If[ TrueQ @ $wlFIM, $wlFIMPrompt, $wlSuggestionsPrompt0 ];

(* TODO: make the language a template parameter to support ExternalLanguage cells too: *)
$wlSuggestionsPrompt0 = StringTemplate[ "\
Complete the following Wolfram Language code by writing text that can be inserted into \"%%Placeholder%%\".
Do your best to match the existing style (whitespace, line breaks, etc.).
Your suggested text will be inserted into %%Placeholder%%, so be careful not to repeat the immediately surrounding text.
Use `%` to refer to the previous output or `%n` for earlier outputs (where n is an output number) when appropriate.
Limit your suggested completion to approximately one or two lines of code.
Respond with the completion text and nothing else.
Do not include any formatting in your response. Do not include outputs or `In[]:=` cell labels.

%%RelatedDocumentation%%",
Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Fill-in-the-Middle Completions*)
$wlFIM                 = False;
$wlFIMService          = "Ollama";
$wlFIMModel            = "deepseek-coder-v2";
$wlFIMAuthentication   = Automatic;
$wlFIMTemperature      = 0.7;
$wlFIMSuggestionsCount = 1;

$wlFIMOptions = <|
    "num_predict" -> $wlSuggestionsMaxTokens,
    "stop"        -> { "\n\n" },
    "temperature" -> $wlFIMTemperature
|>;

$wlFIMPrompt = StringTemplate[ "\
Complete the following Wolfram Language code.
Do your best to match the existing style (whitespace, line breaks, etc.).
Use `%` to refer to the previous output or `%n` for earlier outputs (where n is an output number) when appropriate.
Limit your suggested completion to approximately one or two lines of code.
Do not include any formatting in your response. Do not include outputs or `In[]:=` cell labels.",
Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TextData Suggestions*)
$textSuggestionsModel       = "gpt-4o";
$textSuggestionsMultimodal  = False;
$textSuggestionsCount       = 3;
$textSuggestionsMaxTokens   = 256;
$textSuggestionsTemperature = 0.7;
$textPlaceholderString      = "\:2758";
$textCellsBefore            = 25;
$textCellsAfter             = 10;

$textSuggestionsPrompt = StringTemplate[ "\
Complete the following by writing text that can be inserted into \"%%Placeholder%%\".
The current cell style is \"%%Style%%\", so only write content that would be appropriate for this cell type.\
%%StyleNotes%%
Do your best to match the existing style (whitespace, line breaks, etc.).
Write built-in Wolfram Language symbols as markdown links: [Table](paclet:ref/Table).
Your suggested text will be inserted into %%Placeholder%%, so be careful not to repeat the immediately surrounding text.
Respond with the completion text and nothing else.",
Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Notebook Content Suggestions*)
$notebookSuggestionsModel       = "gpt-4o";
$notebookSuggestionsMultimodal  = False;
$notebookSuggestionsCount       = 1;
$notebookSuggestionsMaxTokens   = 1024;
$notebookSuggestionsTemperature = 0.7;
$notebookPlaceholderString      = "\:2758";
$notebookCellsBefore            = 50;
$notebookCellsAfter             = 25;
$notebookDocMaxItems            = 20;
$notebookFilterDocResults       = True;
$notebookFilteredDocCount       = 5;

$notebookSuggestionsPrompt := If[ $inputStyle === "Code", $packageSuggestionsPrompt, $notebookSuggestionsPrompt0 ];

$notebookSuggestionsPrompt0 = StringTemplate[ "\
Complete the following by writing markdown text that can be inserted into \"%%Placeholder%%\".
Do your best to match the existing style (whitespace, line breaks, etc.).

- In text, format built-in Wolfram Language symbols as markdown links: [Table](paclet:ref/Table).
- When writing code, only write the inputs.\
 Do not include the corresponding output and do not state what the expected output will be.\
 The user will be given the opportunity to run all inputs to regenerate outputs as needed.
- Write Wolfram Language code as code blocks, specifying `wl` as the language. For example:
```wl
Table[i^2, {i, 10}]
```
- Your suggested text will be inserted into %%Placeholder%%,\
 so be careful not to repeat the immediately surrounding text.
- Respond with the completion text and nothing else.

%%RelatedDocumentation%%",
Delimiters -> "%%" ];

$packageSuggestionsPrompt = StringTemplate[ "\
Complete the following by writing text that can be inserted into \"%%Placeholder%%\".
Do your best to match the existing style (whitespace, line breaks, etc.).
You can use markdown to format your response.
Your suggested text will be inserted into %%Placeholder%%, so be careful not to repeat the immediately surrounding text.
Respond with the completion text and nothing else.

%%RelatedDocumentation%%",
Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Patterns*)
$$emptyItem       = "" | { } | { "" };
$$emptySuggestion = $$emptyItem | BoxData @ $$emptyItem | TextData @ $$emptyItem;

$$inLabel  = "In["  ~~ (DigitCharacter...|"\:f759") ~~ "]" ~~ WhitespaceCharacter... ~~ ":=";
$$outLabel = "Out[" ~~ (DigitCharacter...|"\:f759") ~~ "]" ~~ WhitespaceCharacter... ~~ ("="|"//");

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowContentSuggestions*)
ShowContentSuggestions // beginDefinition;
ShowContentSuggestions[ ] := catchMine @ withChatState @ LogChatTiming @ showContentSuggestions @ InputNotebook[ ];
ShowContentSuggestions[ nbo_ ] := catchMine @ withChatState @ LogChatTiming @ showContentSuggestions @ nbo;
ShowContentSuggestions // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showContentSuggestions*)
showContentSuggestions // beginDefinition;

showContentSuggestions[ $Failed ] :=
    Null;

showContentSuggestions[ nbo_NotebookObject ] :=
    showContentSuggestions[ nbo, SelectedCells @ nbo ];

showContentSuggestions[ nbo_NotebookObject, { selected_CellObject } ] :=
    withSuggestionsProgress @ showContentSuggestions0[ nbo, selected ];

showContentSuggestions[ nbo_NotebookObject, { } ] :=
    withSuggestionsProgress @ showContentSuggestions0[ nbo, nbo ];

showContentSuggestions[ _NotebookObject, _ ] :=
    Null;

showContentSuggestions // endDefinition;


showContentSuggestions0 // beginDefinition;

showContentSuggestions0[ nbo_NotebookObject, root: $$feObj ] := Enclose[
    Catch @ Module[ { selectionType, contentData, info },

        NotebookDelete @ Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedContentSuggestions" ];
        selectionType = CurrentValue[ nbo, "SelectionType" ];
        If[ selectionType === None && Cells @ nbo =!= { }, Throw @ Null ];
        $lastSelectionType = selectionType;
        If[ ! MatchQ[ selectionType, "CellCaret"|"TextCaret"|"TextRange"|None ], Throw @ Null ];
        contentData = If[ MatchQ[ root, _CellObject ], cellInformation[ root, "ContentData" ], None ];
        info = <| "ContentData" -> contentData, "SelectionType" -> selectionType |>;

        ConfirmMatch[
            setServiceCaller[ showContentSuggestions0[ nbo, root, info ], "ContentSuggestions" ],
            _CellObject | Null,
            "ShowContentSuggestions"
        ]
    ],
    throwInternalFailure
];

showContentSuggestions0[ nbo_NotebookObject, root: $$feObj, selectionInfo_Association ] := Enclose[
    Catch @ Module[ { type, selection, suggestionsContainer, attached, settings, context },

        (* Do not show suggestions if selection is in an output cell: *)
        If[ CurrentValue[ root, GeneratedCell ],
            NotebookDelete @ Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedContentSuggestions" ];
            Throw @ Null
        ];

        type = ConfirmBy[ suggestionsType @ selectionInfo, StringQ, "Type" ];
        selection = selectionInfo[ "SelectionType" ];

        $progressContainer = HoldComplete @ suggestionsContainer;
        setProgressDisplay[ "GeneratingSuggestions", 0.0 ];
        $fixedProgressText = True;

        attached = ConfirmMatch[
            If[ selection === None,
                AttachCell[
                    nbo,
                    contentSuggestionsCell[ Dynamic[ suggestionsContainer ] ],
                    { Center, Top },
                    0,
                    { Center, Top },
                    RemovalConditions -> { "EvaluatorQuit", "MouseClickOutside" }
                ],
                AttachCell[
                    NotebookSelection @ nbo,
                    contentSuggestionsCell[ Dynamic[ suggestionsContainer ] ],
                    { "WindowCenter", Bottom },
                    0,
                    { Center, Top },
                    RemovalConditions -> { "EvaluatorQuit", "MouseClickOutside" }
                ]
            ],
            _CellObject,
            "Attached"
        ];

        ClearAttributes[ suggestionsContainer, Temporary ];

        redirectFailures[
            suggestionsContainer,

            withApproximateProgress[
                settings = ConfirmBy[
                    LogChatTiming @ AbsoluteCurrentChatSettings @ root,
                    AssociationQ,
                    "Settings"
                ];

                settings = mergeChatSettings @ {
                    settings,
                    $contentSuggestionsOverrides,
                    <| "MaxContextTokens" -> determineMaxContextTokens @ type |>
                },
                Inherited,
                0.25
            ];

            context = withApproximateProgress[
                ConfirmBy[
                    Replace[ LogChatTiming @ getSuggestionsContext[ type, nbo, settings ], None -> "" ],
                    StringQ,
                    "Context"
                ],
                Inherited,
                0.2
            ];

            $contextPrompt   = None;
            $selectionPrompt = None;

            withApproximateProgress[
                ConfirmMatch[
                    LogChatTiming @ generateSuggestions[
                        type,
                        Dynamic[ suggestionsContainer ],
                        nbo,
                        root,
                        context,
                        settings
                    ],
                    _Pane,
                    "Generate"
                ],
                Inherited,
                0.4
            ];
        ];

        $progressContainer = None;

        attached
    ],
    throwInternalFailure
];

showContentSuggestions0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*redirectFailures*)
redirectFailures // beginDefinition;
redirectFailures // Attributes = { HoldAllComplete };

redirectFailures[ container_, eval_ ] :=
    Block[ { throwFailureToChatOutput = redirectFailureToContainer @ container },
        Catch[ eval, $redirectTag ]
    ];

redirectFailures // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*redirectFailureToContainer*)
redirectFailureToContainer // beginDefinition;
redirectFailureToContainer // Attributes = { HoldFirst };

redirectFailureToContainer[ container_ ] :=
    redirectFailureToContainer[ container, # ] &;

redirectFailureToContainer[ container_, failure_Failure ] := Enclose[
    Module[ { boxes },
        boxes = ConfirmMatch[ errorMessageBox @ failure, _Framed, "Boxes" ];
        Throw[ container = boxes, $redirectTag ]
    ],
    throwInternalFailure
];

redirectFailureToContainer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*withSuggestionsProgress*)
withSuggestionsProgress // beginDefinition;
withSuggestionsProgress // Attributes = { HoldFirst };

withSuggestionsProgress[ eval_ ] := Block[
    {
        $ContentSuggestions       = True,
        $finishReason             = None,
        $progressWidth            = $contentSuggestionsProgressWidth,
        $showProgressText         = True,
        $showProgressBar          = True,
        $showProgressCancelButton = True,
        $fixedProgressText        = $fixedProgressText
    },
    CheckAbort[ eval, NotebookDelete @ Cells[ CellStyle -> "AttachedContentSuggestions", AttachedCell -> True ] ]
];

withSuggestionsProgress // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*determineMaxContextTokens*)
determineMaxContextTokens // beginDefinition;
determineMaxContextTokens[ type_String ] := $maxContextTokens[ type ];
determineMaxContextTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSuggestionsContext*)
getSuggestionsContext // beginDefinition;

getSuggestionsContext[ "WL", nbo_NotebookObject, settings_ ] := getContextFromSelection[
    None,
    nbo,
    settings,
    "NotebookInstructionsPrompt" -> False,
    "MaxCellsBeforeSelection"    -> $wlCellsBefore,
    "MaxCellsAfterSelection"     -> $wlCellsAfter
];

getSuggestionsContext[ "Text", nbo_NotebookObject, settings_ ] := getContextFromSelection[
    None,
    nbo,
    settings,
    "NotebookInstructionsPrompt" -> False,
    "MaxCellsBeforeSelection"    -> $textCellsBefore,
    "MaxCellsAfterSelection"     -> $textCellsAfter
];

getSuggestionsContext[ "Notebook", nbo_NotebookObject, settings_ ] := getContextFromSelection[
    None,
    nbo,
    settings,
    "NotebookInstructionsPrompt" -> False,
    "MaxCellsBeforeSelection"    -> $notebookCellsBefore,
    "MaxCellsAfterSelection"     -> $notebookCellsAfter
];

getSuggestionsContext // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contentSuggestionsCell*)
contentSuggestionsCell // beginDefinition;

contentSuggestionsCell[ Dynamic[ container_Symbol ] ] := Cell[
    BoxData @ ToBoxes @ Framed[
        Dynamic[ container(*, Deinitialization :> Quiet @ Remove @ container*) ],
        Background     -> RGBColor[ "#F3FAFF" ],
        FrameStyle     -> RGBColor[ "#C9D9E5" ],
        RoundingRadius -> 5
    ],
    "AttachedContentSuggestions",
    Magnification -> Dynamic @ AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ]
];

contentSuggestionsCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*suggestionsType*)
suggestionsType // beginDefinition;
suggestionsType[ selectionInfo_Association ] := suggestionsType @ selectionInfo[ "ContentData" ];
suggestionsType[ BoxData  ] := "WL";
suggestionsType[ TextData ] := "Text";
suggestionsType[ _        ] := "Notebook";
suggestionsType // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateSuggestions*)
generateSuggestions // beginDefinition;
generateSuggestions[ "WL"      , args__ ] := generateWLSuggestions @ args;
generateSuggestions[ "Text"    , args__ ] := generateTextSuggestions @ args;
generateSuggestions[ "Notebook", args__ ] := generateNotebookSuggestions @ args;
generateSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateWLSuggestions*)
generateWLSuggestions // beginDefinition;

generateWLSuggestions[ Dynamic[ container_ ], nbo_, root_CellObject, context0_String, settings_ ] := Enclose[
    Module[ { context, preprocessed, relatedDocs, as, instructions, response, style, suggestions, stripped },

        context = ConfirmBy[
            StringReplace[
                context0,
                Shortest[ $leftSelectionIndicator~~___~~$rightSelectionIndicator ] :> $wlPlaceholderString
            ],
            StringQ,
            "Context"
        ];

        If[ TrueQ @ $wlSuggestionsMultimodal,
            context = ConfirmMatch[ GetExpressionURIs @ context, { (_String|_Image)... }, "MultimodalContext" ]
        ];

        $lastSuggestionContext = context;

        preprocessed = ConfirmBy[ preprocessRelatedDocsContext @ context, StringQ, "Preprocessing" ];

        relatedDocs = ConfirmBy[
            LogChatTiming @ RelatedDocumentation[
                preprocessed,
                "Prompt",
                MaxItems        -> $wlDocMaxItems,
                "FilterResults" -> $wlFilterDocResults,
                "FilteredCount" -> $wlFilteredDocCount
            ] // withApproximateProgress[ 0.25 ],
            StringQ,
            "RelatedDocumentation"
        ];

        as = <|
            "Context"              -> context,
            "Placeholder"          -> $wlPlaceholderString,
            "RelatedDocumentation" -> relatedDocs
        |>;

        instructions = StringTrim @ ConfirmBy[ TemplateApply[ $wlSuggestionsPrompt, as ], StringQ, "Instructions" ];
        as[ "Instructions" ] = instructions;

        $lastInstructions = instructions;

        response = ConfirmMatch[
            executeWLSuggestions @ as,
            KeyValuePattern[ "Content" -> { __String } | _String ],
            "Response"
        ];

        style = First[ ConfirmMatch[ cellStyles @ root, { ___String }, "Styles" ], "Input" ];

        suggestions = DeleteDuplicates @ ConfirmMatch[
            getWLSuggestions[ style, response ],
            { __BoxData },
            "Suggestions"
        ];

        (* FIXME: strip surrounding code in getWLSuggestions instead of going from string -> boxes -> string -> boxes *)
        stripped = Take[
            ConfirmMatch[ stripSurroundingWLCode[ style, suggestions, context ], { __BoxData }, "Stripped" ],
            UpTo[ $wlSuggestionsCount ]
        ];

        $lastSuggestions = suggestions;

        container = formatSuggestions[ Dynamic[ container ], stripped, nbo, root, context, settings ]
    ],
    throwInternalFailure
];

generateWLSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*executeWLSuggestions*)
executeWLSuggestions // beginDefinition;
executeWLSuggestions[ as_ ] := If[ TrueQ @ $wlFIM, executeWLSuggestionsFIM @ as, executeWLSuggestions0 @ as ];
executeWLSuggestions // endDefinition;


executeWLSuggestions0 // beginDefinition;

executeWLSuggestions0[ KeyValuePattern @ { "Instructions" -> instructions_, "Context" -> context_ } ] :=
    executeWLSuggestions0[ instructions, context ];

executeWLSuggestions0[ instructions_, context_ ] := setServiceCaller[
    LogChatTiming @ suggestionServiceExecute[
        $suggestionsService,
        "Chat",
        {
            "Messages" -> {
                <| "Role" -> "System", "Content" -> instructions |>,
                <| "Role" -> "User"  , "Content" -> context      |>
            },
            "Model"       -> $wlSuggestionsModel,
            "N"           -> $wlSuggestionsCount,
            "MaxTokens"   -> $wlSuggestionsMaxTokens,
            "Temperature" -> $wlSuggestionsTemperature
        }
    ],
    "WLSuggestions"
];

executeWLSuggestions0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*executeWLSuggestionsFIM*)
executeWLSuggestionsFIM // beginDefinition;

executeWLSuggestionsFIM[ as_Association ] := Enclose[
    Module[ { instructions, context, docs, before, after, prompt, suffix, responses, strings },

        instructions = ConfirmBy[ as[ "Instructions"         ], StringQ, "Instructions" ];
        context      = ConfirmBy[ as[ "Context"              ], StringQ, "Context"      ];
        docs         = ConfirmBy[ as[ "RelatedDocumentation" ], StringQ, "RelatedDocs"  ];

        { before, after } = ConfirmMatch[
            StringSplit[ context, $wlPlaceholderString ],
            { _String, _String },
            "Split"
        ];

        prompt = ConfirmBy[ instructions<>"\n\n\n"<>before, StringQ, "Prompt" ];
        suffix = ConfirmBy[ after<>"\n\n\n"<>docs, StringQ, "Suffix" ];

        responses = ConfirmMatch[
            setServiceCaller[
                Table[
                    LogChatTiming @ suggestionServiceExecute[
                        $wlFIMService,
                        "RawCompletion",
                        DeleteMissing @ <|
                            "model"   -> $wlFIMModel,
                            "prompt"  -> prompt,
                            "suffix"  -> suffix,
                            "stream"  -> False,
                            "options" -> $wlFIMOptions
                        |>
                    ],
                    $wlFIMSuggestionsCount
                ],
                "WLSuggestions"
            ],
            { __Association },
            "Responses"
        ];

        strings = ConfirmMatch[ #[ "response" ] & /@ responses, { __String }, "Strings" ];

        <| "Content" -> strings |>
    ],
    throwInternalFailure
];

executeWLSuggestionsFIM // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessRelatedDocsContext*)
preprocessRelatedDocsContext // beginDefinition;

preprocessRelatedDocsContext[ context_String ] := Enclose[
    Module[ { processed, noPlaceholder },
        processed     = ConfirmBy[ preprocessRelatedDocsContext0 @ context, StringQ, "Processed" ];
        noPlaceholder = ConfirmBy[ StringDelete[ processed, $wlPlaceholderString ], StringQ, "NoPlaceholder" ];
        ConfirmBy[
            StringTrim @ StringReplace[
                StringTrim @ noPlaceholder,
                StartOfString ~~ "```wl" ~~ WhitespaceCharacter... ~~ "```" ~~ EndOfString :> $defaultWLContextString
            ],
            StringQ,
            "Result"
        ]
    ],
    throwInternalFailure
];

preprocessRelatedDocsContext // endDefinition;


preprocessRelatedDocsContext0 // beginDefinition;

preprocessRelatedDocsContext0[ context_String ] :=
    preprocessRelatedDocsContext0[
        context,
        DeleteCases[
            StringSplit[ context, code: Shortest[ "```" ~~ __ ~~ "```" ] :> codeBlock @ code ],
            _String? (StringMatchQ[ WhitespaceCharacter... ])
        ]
    ];

preprocessRelatedDocsContext0[ context_, { ___, text_String, codeBlock[ code_String ] } ] :=
    StringJoin[ text, code ];

(* SentenceBERT doesn't do well with pure code, so don't try to include documentation RAG if that's all we have: *)
preprocessRelatedDocsContext0[ context_, { ___codeBlock } ] :=
    "";

(* TODO: in cases like this, it might be best to just use heuristics to choose relevant documentation from symbols. *)

preprocessRelatedDocsContext0[ context_String, { (_String|_codeBlock)... } ] :=
    context;

preprocessRelatedDocsContext0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripSurroundingWLCode*)
stripSurroundingWLCode // beginDefinition;

stripSurroundingWLCode[ style_, suggestions_, context_ ] :=
    Block[ { $stripWhitespace = stripWhitespaceQ @ style },
        stripSurroundingWLCode[ suggestions, context ]
    ];

stripSurroundingWLCode[ suggestions: { __BoxData }, context_String ] := Enclose[
    Catch @ Module[ { surrounding, stripped },

        surrounding = ConfirmMatch[ getSurroundingWLCode @ context, { _String, _String }, "Surrounding" ];
        If[ StringTrim @ surrounding === { "", "" }, Throw @ suggestions ];

        stripped = ConfirmMatch[
            Flatten[ stripSurroundingWLCode[ #, surrounding ] & /@ suggestions ],
            { suggestionWrapper[ _Integer, _BoxData ].. },
            "Result"
        ];

        ConfirmMatch[ DeleteDuplicates @ SortBy[ stripped, First ][[ All, 2 ]], { __BoxData }, "Result" ]
    ],
    throwInternalFailure
];

stripSurroundingWLCode[ suggestion_BoxData, { before_String, after_String } ] := Enclose[
    Catch @ Module[ { string, stripped, boxes },
        string = ConfirmBy[ CellToString @ StyleBox[ suggestion, ShowStringCharacters -> True ], StringQ, "String" ];

        stripped = ConfirmBy[
            If[ StringMatchQ[ string, before ~~ ___ ~~ after ],
                StringDelete[ string, { StartOfString~~before, after~~EndOfString } ],
                Throw @ { suggestionWrapper[ 1, suggestion ] }
            ],
            StringQ,
            "Stripped"
        ];

        boxes = ConfirmMatch[ postProcessWLSuggestions @ stripped, _BoxData, "Result" ];

        DeleteDuplicatesBy[ { suggestionWrapper[ 0, boxes ], suggestionWrapper[ 1, suggestion ] }, Last ]
    ],
    throwInternalFailure
];

stripSurroundingWLCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSurroundingWLCode*)
getSurroundingWLCode // beginDefinition;

getSurroundingWLCode[ context_String ] := Enclose[
    Catch @ Module[ { strings, boxes },
        strings = ConfirmMatch[
            First[
                StringCases[
                    context,
                    StringExpression[
                        "```wl\n",
                        a___ /; StringFreeQ[ a, "```" ],
                        $wlPlaceholderString,
                        b___ /; StringFreeQ[ b, "```" ],
                        "\n```"
                    ] :> { a, b },
                    1
                ],
                Throw @ { "", "" }
            ],
            { _String, _String },
            "Strings"
        ];

        boxes = ConfirmMatch[ postProcessWLSuggestions @ strings, { _BoxData, _BoxData }, "Boxes" ];

        ConfirmMatch[ CellToString /@ boxes, { _String, _String }, "Result" ]
    ],
    throwInternalFailure
];

getSurroundingWLCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWLSuggestions*)
getWLSuggestions // beginDefinition;

getWLSuggestions[ style_, content_ ] :=
    Block[ { $stripWhitespace = stripWhitespaceQ @ style },
        postProcessWLSuggestions @ getSuggestions @ content
    ];

getWLSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripWhitespaceQ*)
stripWhitespaceQ // beginDefinition;
stripWhitespaceQ[ "Code"  ] := False;
stripWhitespaceQ[ _String ] := True;
stripWhitespaceQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postProcessWLSuggestions*)
postProcessWLSuggestions // beginDefinition;

postProcessWLSuggestions[ suggestions_List ] :=
    postProcessWLSuggestions /@ suggestions;

postProcessWLSuggestions[ suggestion_String ] := Enclose[
    Module[ { noOutputs, noBlocks, noLabels },

        noOutputs = StringDelete[
            StringDelete[
                suggestion,
                {
                    $wlPlaceholderString,
                    "```" ~~ Except[ "\n" ]... ~~ WhitespaceCharacter... ~~ $$outLabel ~~ ___ ~~ EndOfString
                }
            ],
            $$outLabel ~~ ___ ~~ EndOfString
        ];

        noBlocks = StringTrim[
                StringTrim @ StringDelete[
                If[ StringContainsQ[ noOutputs, "```"~~__~~"```" ],
                    ConfirmBy[
                        First @ StringCases[
                            noOutputs,
                            "```" ~~ Except[ "\n" ]... ~~ "\n" ~~ code___ ~~ "```" :> code,
                            1
                        ],
                        StringQ,
                        "NoBlocks"
                    ],
                    noOutputs
                ],
                {
                    StartOfLine ~~ WhitespaceCharacter... ~~ "```" ~~ Except[ "\n" ]... ~~ EndOfLine,
                    "```" ~~ WhitespaceCharacter... ~~ EndOfLine
                }
            ],
            Longest @ Repeated[ "`", { 1, 3 } ]
        ];

        noLabels = StringTrim @ StringDelete[ noBlocks, $$inLabel ];

        ConfirmMatch[
            If[ TrueQ @ $stripWhitespace,
                Flatten @ BoxData @ StringToBoxes[ noLabels, "WL" ],
                Flatten @ BoxData @ simpleStringToBoxes @ noLabels
            ],
            _BoxData,
            "Result"
        ]
    ],
    throwInternalFailure
];

postProcessWLSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleStringToBoxes*)
simpleStringToBoxes // beginDefinition;

simpleStringToBoxes[ string_String ] := Enclose[
    ConfirmBy[ usingFrontEnd @ FrontEndExecute @ FrontEnd`ReparseBoxStructurePacket @ string, boxDataQ, "Boxes" ],
    throwInternalFailure
];

simpleStringToBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateTextSuggestions*)
generateTextSuggestions // beginDefinition;

generateTextSuggestions[ Dynamic[ container_ ], nbo_, root_CellObject, context0_String, settings_ ] := Enclose[
    Module[ { style, context, instructions, response, suggestions },

        style = First[ ConfirmMatch[ cellStyles @ root, { ___String }, "Styles" ], "Text" ];

        context = ConfirmBy[
            StringReplace[
                context0,
                Shortest[ $leftSelectionIndicator~~___~~$rightSelectionIndicator ] :> $textPlaceholderString
            ],
            StringQ,
            "Context"
        ];

        If[ TrueQ @ $textSuggestionsMultimodal,
            context = ConfirmMatch[ GetExpressionURIs @ context, { (_String|_Image)... }, "MultimodalContext" ]
        ];

        $lastSuggestionContext = context;

        instructions = ConfirmBy[
            TemplateApply[
                $textSuggestionsPrompt,
                <|
                    "Placeholder" -> $textPlaceholderString,
                    "Style"       -> style,
                    "StyleNotes"  -> styleNotes @ style
                |> ],
            StringQ,
            "Instructions"
        ];

        $lastInstructions = instructions;

        response = setServiceCaller[
            LogChatTiming @ suggestionServiceExecute[
                $suggestionsService,
                "Chat",
                {
                    "Messages" -> {
                        <| "Role" -> "System", "Content" -> instructions |>,
                        <| "Role" -> "User"  , "Content" -> context      |>
                    },
                    "Model"       -> $textSuggestionsModel,
                    "N"           -> $textSuggestionsCount,
                    "MaxTokens"   -> $textSuggestionsMaxTokens,
                    "Temperature" -> $textSuggestionsTemperature,
                    "StopTokens"  -> { "\n\n" }
                }
            ],
            "TextSuggestions"
        ];

        suggestions = DeleteDuplicates @ ConfirmMatch[ getTextSuggestions @ response, { __TextData }, "Suggestions" ];

        $lastSuggestions = suggestions;

        container = formatSuggestions[ Dynamic[ container ], suggestions, nbo, root, context, settings ]
    ],
    throwInternalFailure
];

generateTextSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*styleNotes*)
styleNotes // beginDefinition;

styleNotes[ "Title" ] := "
A title cell should be a short, descriptive phrase that summarizes the content that follows.
Remember: You are only to complete the current title cell, so only write a few words at most.";

styleNotes[ "Section" ] := "
Section cells should be used to divide the notebook into logical sections.
They should be short and descriptive.
Remember: You are only to complete the current section cell, so only write a few words at most.";

styleNotes[ "Subsection" ] := "
Subsection cells should be used to further divide the notebook into logical parts.
They should be short and descriptive.
Remember: You are only to complete the current subsection cell, so only write a few words at most.";

styleNotes[ "Subsubsection" ] := "
Subsubsection cells should be used to further divide the notebook into logical parts.
They should be short and descriptive.
Remember: You are only to complete the current subsubsection cell, so only write a few words at most.";

styleNotes[ "Subsubsubsection" ] := "
Subsubsubsection cells should be used to further divide the notebook into logical parts.
They should be short and descriptive.
Remember: You are only to complete the current subsubsubsection cell, so only write a few words at most.";

styleNotes[ "Text" ] := "
Text cells are for normal text, which may include inline markdown formatting.
Do not write any code blocks in a text cell.";

styleNotes[ "CodeText" ] := "
CodeText cells typically contain a short one-line caption ending in a colon (:) that describe the next input.";

styleNotes[ _ ] := "";

styleNotes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getTextSuggestions*)
getTextSuggestions // beginDefinition;
getTextSuggestions[ content_ ] := postProcessTextSuggestions @ getSuggestions @ content;
getTextSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postProcessTextSuggestions*)
postProcessTextSuggestions // beginDefinition;

postProcessTextSuggestions[ suggestions_List ] :=
    postProcessTextSuggestions /@ suggestions;

(* FIXME: need to create an option for FormatChatOutput to control $stripWhitespace *)
postProcessTextSuggestions[ s_String ] :=
    postProcessTextSuggestions[ s, FormatChatOutput @ StringDelete[ s, $textPlaceholderString|$$stdFormBoxes ] ];

postProcessTextSuggestions[ s_, RawBoxes[ cell_Cell ] ] :=
    postProcessTextSuggestions[ s, ExplodeCell @ cell ];

postProcessTextSuggestions[ s_, { cell_Cell, ___ } ] :=
    toTextData @ cell;

postProcessTextSuggestions // endDefinition;


$$stdFormBoxes = "\\!\\(" ~~ ("\\*"|"") ~~ LetterCharacter.. ~~ "[\"" ~~ Shortest[ __ ] ~~ "\"]\\)";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toTextData*)
toTextData // beginDefinition;
toTextData[ Cell[ text_, ___ ] ] := toTextData @ text;
toTextData[ text_TextData ] := text;
toTextData[ text: $$textData ] := TextData @ Flatten @ { text };
toTextData[ boxes_BoxData ] := TextData @ { Cell[ postProcessWLSuggestions @ CellToString @ boxes, "InlineCode" ] };
toTextData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateNotebookSuggestions*)
generateNotebookSuggestions // beginDefinition;

generateNotebookSuggestions[ container_, nbo_NotebookObject, root_, context_, settings_ ] :=
    Block[ { $inputStyle = determineInputStyle @ nbo, $stripWhitespace },
        $stripWhitespace = $inputStyle =!= "Code";
        generateNotebookSuggestions0[ container, nbo, root, context, settings ]
    ];

generateNotebookSuggestions // endDefinition;


generateNotebookSuggestions0 // beginDefinition;

generateNotebookSuggestions0[ Dynamic[ container_ ], nbo_, root_NotebookObject, context0_String, settings_ ] := Enclose[
    Module[ { context, preprocessed, relatedDocs, as, instructions, response, suggestions },

        context = ConfirmBy[
            StringReplace[
                context0,
                Shortest[ $leftSelectionIndicator~~___~~$rightSelectionIndicator ] :> $notebookPlaceholderString
            ],
            StringQ,
            "Context"
        ];

        If[ TrueQ @ $notebookSuggestionsMultimodal,
            context = ConfirmMatch[ GetExpressionURIs @ context, { (_String|_Image)... }, "MultimodalContext" ]
        ];

        $lastSuggestionContext = context;

        preprocessed = ConfirmBy[ preprocessRelatedDocsContext @ context, StringQ, "Preprocessing" ];

        relatedDocs = ConfirmBy[
            LogChatTiming @ RelatedDocumentation[
                preprocessed,
                "Prompt",
                MaxItems        -> $notebookDocMaxItems,
                "FilterResults" -> $notebookFilterDocResults,
                "FilteredCount" -> $notebookFilteredDocCount
            ] // withApproximateProgress[ 0.4 ],
            StringQ,
            "RelatedDocumentation"
        ];

        as = <|
            "Context"              -> context,
            "Placeholder"          -> $wlPlaceholderString,
            "RelatedDocumentation" -> relatedDocs
        |>;

        instructions = StringTrim @ ConfirmBy[
            TemplateApply[ $notebookSuggestionsPrompt, as ],
            StringQ,
            "Instructions"
        ];
        as[ "Instructions" ] = instructions;

        $lastInstructions = instructions;

        response = setServiceCaller[
            LogChatTiming @ suggestionServiceExecute[
                $suggestionsService,
                "Chat",
                {
                    "Messages" -> {
                        <| "Role" -> "System", "Content" -> instructions |>,
                        <| "Role" -> "User"  , "Content" -> context      |>
                    },
                    "Model"       -> $notebookSuggestionsModel,
                    "N"           -> $notebookSuggestionsCount,
                    "MaxTokens"   -> $notebookSuggestionsMaxTokens,
                    "Temperature" -> $notebookSuggestionsTemperature
                }
            ],
            "NotebookSuggestions"
        ];

        $finishReason = response[ "FinishReason" ];

        suggestions = DeleteDuplicates @ ConfirmMatch[
            getNotebookSuggestions[ context, response ],
            { __Cell },
            "Suggestions"
        ];

        $lastSuggestions = suggestions;

        container = formatSuggestions[ Dynamic[ container ], suggestions, nbo, root, context, settings ]
    ],
    throwInternalFailure
];

generateNotebookSuggestions0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*determineInputStyle*)
determineInputStyle // beginDefinition;
determineInputStyle[ nbo_NotebookObject ] := determineInputStyle[ nbo, CurrentValue[ nbo, DefaultNewCellStyle ] ];
determineInputStyle[ nbo_, style: $$inputStyle ] := style;
determineInputStyle[ nbo_, style_ ] := "Input";
determineInputStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNotebookSuggestions*)
getNotebookSuggestions // beginDefinition;

getNotebookSuggestions[ context_, content_ ] := Flatten @ {
    LogChatTiming @ postProcessNotebookSuggestions[ context, getSuggestions @ content ]
};

getNotebookSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postProcessNotebookSuggestions*)
postProcessNotebookSuggestions // beginDefinition;

postProcessNotebookSuggestions[ context_String, suggestions_List ] :=
    postProcessNotebookSuggestions[ context, # ] & /@ suggestions;

postProcessNotebookSuggestions[ context_String, string0_String ] := Enclose[
    Module[ { before, after, string, s, maxPrefix, commonPrefix, maxSuffix, commonSuffix, trimmed },

        { before, after } = ConfirmMatch[
            Replace[
                StringSplit[ context, $notebookPlaceholderString :> Placeholder ],
                {
                    { b_String, Placeholder, a_String } :> { b , a  },
                    { b_String, Placeholder           } :> { b , "" },
                    {           Placeholder, a_String } :> { "", a  },
                    {                                 } :> { "", "" }
                }
            ],
            { _String, _String },
            "Split"
        ];

        string = ConfirmBy[ StringDelete[ string0, $notebookPlaceholderString ], StringQ, "String" ];
        If[ StringMatchQ[ string, ("```\n"|"```markdown\n") ~~__~~ "\n```", IgnoreCase -> True ],
            string = StringDelete[ string, { StartOfString~~("```\n"|"```markdown\n"), "\n```"~~EndOfString } ]
        ];

        (* TODO: this could be generalized: *)
        maxPrefix = Min[ StringLength @ before, StringLength @ string ];
        commonPrefix = "";
        Do[ If[ (s = StringTake[ before, -i ]) === StringTake[ string, i ], commonPrefix = s ], { i, maxPrefix } ];
        maxSuffix = Min[ StringLength @ after, StringLength @ string ];
        commonSuffix = "";
        Do[ If[ (s = StringTake[ string, -i ]) === StringTake[ after, i ], commonSuffix = s ], { i, maxSuffix } ];
        trimmed = StringDelete[ string, { StartOfString~~commonPrefix, commonSuffix~~EndOfString } ];

        postProcessNotebookSuggestions0[ string0, FormatChatOutput @ trimmed ]
    ],
    throwInternalFailure
];

postProcessNotebookSuggestions // endDefinition;



postProcessNotebookSuggestions0 // beginDefinition;

postProcessNotebookSuggestions0[ s_, RawBoxes[ cell_Cell ] ] :=
    postProcessNotebookSuggestions0[ s, ExplodeCell @ cell ];

postProcessNotebookSuggestions0[ s_, cells0: { ___Cell, Cell[ __, $$generatedStyle, ___ ], ___Cell } ] :=
    With[ { cells = DeleteCases[ cells0, Cell[ __, $$generatedStyle, ___ ] | Cell[ $$whitespace, "Text", ___ ] ] },
        postProcessNotebookSuggestions0[ s, cells ] /; cells =!= { }
    ];

postProcessNotebookSuggestions0[ s_, cells: { __Cell } ] := Enclose[
    Module[ { processed, trimmed },
        processed = ConfirmMatch[ Flatten[ postProcessNotebookSuggestion /@ cells ], { __Cell }, "Processed" ];
        trimmed = ConfirmMatch[ trimUnfinishedInput @ processed, { __Cell }, "Trimmed" ];
        Cell @ CellGroupData[ trimmed, Open ]
    ],
    throwInternalFailure
];

postProcessNotebookSuggestions0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*trimUnfinishedInput*)
trimUnfinishedInput // beginDefinition;

trimUnfinishedInput[ cells: { keep__, Cell[ __, $$inputStyle, ___ ] } ] :=
    If[ $finishReason === "length" && Length @ cells > 5,
        { keep },
        cells
    ];

trimUnfinishedInput[ cells_List ] :=
    cells;

trimUnfinishedInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postProcessNotebookSuggestion*)
postProcessNotebookSuggestion // beginDefinition;

postProcessNotebookSuggestion[ Cell[ a__, $$inputStyle, b___ ] ] :=
    divideCell @ Cell[ a, $inputStyle, b, If[ $inputStyle === "Input", CellLabel -> "In[\:f759]:=", Sequence @@ { } ] ];

postProcessNotebookSuggestion[ cell_Cell ] :=
    cell;

postProcessNotebookSuggestion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*divideCell*)
divideCell // beginDefinition;

divideCell[ cell_Cell ] :=
    With[ { divided = Quiet @ NotebookTools`DivideCell[ cell, { $inputStyle, Automatic, True } ] },
        If[ MatchQ[ divided, { __Cell } ], divided, cell ]
    ];

divideCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSuggestions*)
getSuggestions // beginDefinition;
getSuggestions[ KeyValuePattern[ "Content"|"content"|"choices"|"message" -> data_ ] ] := getSuggestions @ data;
getSuggestions[ content_String ] := content;
getSuggestions[ items_List ] := DeleteCases[ getSuggestions /@ items, $$emptySuggestion ];
getSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatSuggestions*)
formatSuggestions // beginDefinition;

formatSuggestions[
    container_,
    suggestions: { __ },
    nbo_NotebookObject,
    root: $$feObj,
    context_,
    settings_
] := Enclose[
    Module[ { styles, formatted },
        styles = If[ MatchQ[ root, _CellObject ], ConfirmMatch[ cellStyles @ root, { ___String }, "Styles" ], None ];
        formatted = ConfirmMatch[ formatSuggestion[ root, nbo, styles ] /@ suggestions, { __EventHandler }, "Formatted" ];
        Pane[ Column[ formatted, Spacings -> 0 ], ImageSize -> { UpTo[ Scaled[ 0.9 ] ], Automatic } ]
    ],
    throwInternalFailure
];

formatSuggestions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatSuggestion*)
formatSuggestion // beginDefinition;

formatSuggestion[ root: $$feObj, nbo_NotebookObject, styles_ ] :=
    formatSuggestion[ root, nbo, styles, # ] &;

(* This is an EventHandler wrapped around a Button rather than a naked Button to work around a crash *)
(* bug in 14.1, 453621.  Note the first step might be unnecessary, but I can't prove it, and it's cheap. *)
(* - FEPrivate`SetWindowCursorVisible[True] dirties the mouse cursor for the window *)
(* - The EventHandler updates the cursor after it finishes handling the MouseClicked event *)
(* - While updating the cursor, an internal variable pointing to the current moused-over cell is cleared *)
(* - Therefore, a bug that leaves that internal variable pointing to a now-deleted inline cell is avoided *)
formatSuggestion[ root: $$feObj, nbo_NotebookObject, { styles___String }, suggestion_BoxData ] := EventHandler[Button[
    RawBoxes @ Cell[
        suggestion,
        styles,
        If[ MemberQ[ { styles }, "Input"|"Code" ],
            Sequence @@ {
                ShowStringCharacters -> True,
                ShowAutoStyles       -> True,
                LanguageCategory     -> "Input",
                LineBreakWithin      -> Automatic,
                LineIndent           -> 1,
                PageWidth            :> WindowWidth
            },
            Sequence @@ { }
        ]
    ], Alignment->Left],
    "MouseClicked" :> (NotebookDelete @ EvaluationCell[ ];
    If[$VersionNumber === 14.1, FE`Evaluate[FEPrivate`SetWindowCursorVisible[True]]];
    NotebookWrite[ nbo, suggestion, After ])
];

formatSuggestion[ root: $$feObj, nbo_NotebookObject, { styles___String }, suggestion_TextData ] := EventHandler[Button[
    RawBoxes @ Cell[ suggestion, styles, Deployed -> True, Selectable -> False ], Alignment->Left],
    "MouseClicked" :> (NotebookDelete @ EvaluationCell[ ];
    If[$VersionNumber === 14.1, FE`Evaluate[FEPrivate`SetWindowCursorVisible[True]]];
    NotebookWrite[ nbo, suggestion, After ])
];

formatSuggestion[ root: $$feObj, nbo_NotebookObject, None, suggestion: Cell[ _CellGroupData ] ] := EventHandler[Button[
    Column[ formatSuggestionCells /@ cellFlatten @ suggestion, Spacings -> 2 ], Alignment->Left],
    "MouseClicked" :> (NotebookDelete @ EvaluationCell[ ];
    If[$VersionNumber === 14.1, FE`Evaluate[FEPrivate`SetWindowCursorVisible[True]]];
    NotebookWrite[ nbo, suggestion, All ])
];

formatSuggestion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatSuggestionCells*)
formatSuggestionCells // beginDefinition;

formatSuggestionCells[ cell: Cell[ _CellGroupData, ___ ] ] :=
    formatSuggestionCells @ cellFlatten @ cell;

formatSuggestionCells[ cells: { __Cell } ] :=
    formatSuggestionCells /@ cells;

formatSuggestionCells[ Cell[ a__, CellLabel -> label_, b___ ] ] := Grid[
    { {
        Pane[
            Style[ label, "CellLabelExpired", FontSlant -> Plain ],
            Alignment -> Right,
            ImageSize -> { 50, Automatic }
        ],
        formatSuggestionCells @ Cell[ a, b ]
    } },
    Alignment -> { { Right, Left }, Top }
];

formatSuggestionCells[ Cell[ a__, style: "Code"|"Input", b___ ] ] :=
    RawBoxes @ Cell[
        a,
        style,
        b,
        Deployed             -> True,
        Selectable           -> False,
        ShowStringCharacters -> True,
        ShowAutoStyles       -> True,
        LanguageCategory     -> "Input",
        LineBreakWithin      -> Automatic,
        LineIndent           -> 1,
        PageWidth            :> WindowWidth
    ];

formatSuggestionCells[ Cell[ a__ ] ] :=
    RawBoxes @ Cell[ a, Deployed -> True, Selectable -> False ];

formatSuggestionCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Service Utilities*)

Chatbook::SuggestionServiceUnavailable = "The AI suggestion service is currently unavailable. Please try again later.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*suggestionServiceExecute*)
suggestionServiceExecute // beginDefinition;

suggestionServiceExecute[ service_, args___ ] := Enclose[
    Module[ { auth, result, cleanup },
        auth = $suggestionsAuthentication;

        result = Quiet[
            ServiceExecute[ service, args, Authentication -> auth ],
            ServiceExecute::apierr
        ];

        cleanup = Function @ NotebookDelete @ Cells[
            EvaluationNotebook[ ],
            AttachedCell -> True,
            CellStyle    -> "AttachedContentSuggestions"
        ];

        $lastSuggestionsResponse = result;

        If[ TrueQ @ llmKitSubscriptionMissingQ[ auth, result ],
            cleanup[ ];
            throwTop[
                Needs[ "Wolfram`LLMFunctions`APIs`Common`" ];
                Wolfram`LLMFunctions`APIs`Common`ConnectToService[ service, "LLMKit" ]
            ]
        ];

        If[ serviceUnavailableQ[ auth, result ],
            cleanup[ ];
            throwMessageDialog[ "SuggestionServiceUnavailable", result ]
        ];

        If[ FailureQ @ result, throwFailureToChatOutput @ result ];

        ConfirmBy[ result, AssociationQ, "Result" ]
    ],
    throwInternalFailure
];

suggestionServiceExecute // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*llmKitSubscriptionMissingQ*)
llmKitSubscriptionMissingQ // beginDefinition;
llmKitSubscriptionMissingQ[ "LLMKit", failure_Failure ] := ! FreeQ[ failure, $$subscriptionError ];
llmKitSubscriptionMissingQ[ _, _ ] := False;
llmKitSubscriptionMissingQ // endDefinition;


$$subscriptionError = KeyValuePattern[ "error" -> KeyValuePattern[ "code" -> "subscription-required" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serviceUnavailableQ*)
serviceUnavailableQ // beginDefinition;
serviceUnavailableQ[ "LLMKit", failure_Failure ] := ! FreeQ[ failure, Failure[ "APIError", _ ] ];
serviceUnavailableQ[ _, _ ] := False;
serviceUnavailableQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
