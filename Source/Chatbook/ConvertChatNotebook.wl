(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ConvertChatNotebook`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* TODO:
    * This should also handle conversion from a regular chat notebook to workspace chat.
    * Move code for inline chat conversion to this file.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$popOutSettings = { "LLMEvaluator", "MaxContextTokens", "MaxToolResponses", "Model" };

$$convertible        = _Notebook | _NotebookObject;
$$convertChatOptions = OptionsPattern[ { ConvertChatNotebook, Notebook } ];
$$conversionType     = "CloudPublish" | "CloudSave" | "ChatNotebook" | "DefaultNotebook";
$$conversionFormat   = "Notebook" | "NotebookObject";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ConvertChatNotebook*)
ConvertChatNotebook // beginDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Options*)
Needs[ "Wolfram`Chatbook`Settings`" ]; (* Needed for $defaultChatSettings *)
ConvertChatNotebook // Options = Normal[
    KeySort @ <| $defaultChatSettings, "CreateNewNotebook" -> False |>,
    Association
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
GeneralUtilities`SetUsage[ ConvertChatNotebook, "\
ConvertChatNotebook[notebook$, \"type$\"] converts notebook$ to a new chat notebook using rules specified by \"type$\".
ConvertChatNotebook[notebook$, \"type$\", \"fmt$\"] converts notebook$ and gives the result in the specified format.

* The given notebook$ should be a workspace chat and can be given as a Notebook or NotebookObject.
* Some possible values for \"type$\" are:
| \"CloudPublish\"    | Convert the notebook for cloud publishing.  |
| \"CloudSave\"       | Convert the notebook for saving to cloud.   |
| \"ChatNotebook\"    | Convert the notebook to a chat notebook.    |
| \"DefaultNotebook\" | Convert the notebook to a default notebook. |
* Possible values for \"fmt$\" are:
| \"Notebook\"       | Return the result as a Notebook expression.      |
| \"NotebookObject\" | Return the result as a NotebookObject.           |
| Automatic          | Return the result in the same form as notebook$. |
* ConvertChatNotebook accepts the same options as CreateChatNotebook with the following addition:
| CreateNewNotebook | False | Whether to create a new NotebookObject or overwrite the existing one. |
* The CreateNewNotebook option only has an effect when notebook$ is a NotebookObject and \"fmt$\" is \"NotebookObject\".
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definition*)
(* Default arguments and argument normalization: *)
ConvertChatNotebook[ nb_, type_, opts: $$convertChatOptions ] :=
    catchMine @ ConvertChatNotebook[ nb, type, Automatic, opts ];

ConvertChatNotebook[ nb: $$convertible, type_, Automatic, opts: $$convertChatOptions ] :=
    catchMine @ ConvertChatNotebook[ nb, type, Head @ nb, opts ];

ConvertChatNotebook[ nb_, type_, fmt: Notebook|NotebookObject, opts: $$convertChatOptions ] :=
    catchMine @ ConvertChatNotebook[ nb, type, ToString @ fmt, opts ];


(* Main definition: *)
ConvertChatNotebook[ nb: $$convertible, type: $$conversionType, fmt: $$conversionFormat, opts: $$convertChatOptions ] :=
    catchMine @ Enclose[
        Module[ { nbSettings, settings, options, notebook, createNew },

            nbSettings = ConfirmBy[ extractNotebookChatSettings @ nb, AssociationQ, "NotebookSettings" ];

            settings = ConfirmBy[
                makeChatNotebookSettings @ Association @ FilterRules[ { opts }, Options @ ConvertChatNotebook ],
                AssociationQ,
                "Settings"
            ];

            settings = ConfirmBy[
                mergeChatSettings @ { nbSettings, settings },
                AssociationQ,
                "MergedSettings"
            ];

            options = ConfirmMatch[
                Flatten @ { makeChatNotebookOptions[ settings, opts ] },
                { OptionsPattern[ ] },
                "Options"
            ];

            notebook = ConfirmMatch[ toNotebookExpression @ nb, _Notebook, "Notebook" ];
            createNew = OptionValue[ "CreateNewNotebook" ] =!= False && MatchQ[ nb, _NotebookObject ];

            ConfirmMatch[
                convertChatNotebook[ nb, notebook, type, fmt, settings, options, createNew ],
                _Notebook | _NotebookObject,
                "Converted"
            ]
        ],
        throwInternalFailure
    ];

ConvertChatNotebook // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertChatNotebook*)
convertChatNotebook // beginDefinition;

convertChatNotebook[ nb_, notebook_, type_, fmt_, settings_, options_, createNew_ ] := Enclose[
    Module[ { converted, nbObject },
        converted = ConfirmMatch[ convertChatNotebook0[ notebook, type, settings, options ], _Notebook, "Converted" ];
        nbObject = fmt === "NotebookObject";
        Which[
            nbObject && TrueQ @ createNew,
                NotebookPut @ converted,
            nbObject,
                NotebookPut[ converted, nb ],
            True,
                converted
        ]
    ],
    throwInternalFailure
];

convertChatNotebook // endDefinition;


convertChatNotebook0 // beginDefinition;
convertChatNotebook0[ nb_, "CloudPublish"   , settings_, opts_ ] := convertForCloudPublish[ nb, settings, opts ];
convertChatNotebook0[ nb_, "CloudSave"      , settings_, opts_ ] := convertForCloudSave[ nb, settings, opts ];
convertChatNotebook0[ nb_, "ChatNotebook"   , settings_, opts_ ] := convertToChatNotebook[ nb, settings, opts ];
convertChatNotebook0[ nb_, "DefaultNotebook", settings_, opts_ ] := convertToDefaultNotebook[ nb, settings, opts ];
convertChatNotebook0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertForCloudPublish*)
convertForCloudPublish // beginDefinition;
convertForCloudPublish[ nb_, settings_, opts_ ] := convertToChatNotebook[ nb, settings, opts ];
convertForCloudPublish // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertForCloudSave*)
convertForCloudSave // beginDefinition;
convertForCloudSave[ nb_, settings_, opts_ ] := convertToChatNotebook[ nb, settings, opts ];
convertForCloudSave // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertToChatNotebook*)
convertToChatNotebook // beginDefinition;

convertToChatNotebook[ Notebook[ cells_, ___ ], settings_, { opts: OptionsPattern[ ] } ] :=
    Enclose[
        Module[ { converted, options, newCells },
            converted = ConfirmMatch[ cellsToChatNB[ cells, settings ], _Notebook, "Converted" ];
            options = ConfirmMatch[
                DeleteDuplicatesBy[ Flatten @ { opts }, ToString @* First ],
                { OptionsPattern[ ] },
                "Options"
            ];
            newCells = ConfirmMatch[ First @ converted, { ___Cell }, "NewCells" ];
            Notebook[ newCells, Sequence @@ options ]
        ],
        throwInternalFailure
    ];

convertToChatNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*convertToDefaultNotebook*)
convertToDefaultNotebook // beginDefinition;

(* TODO: explode cells? *)
convertToDefaultNotebook[ nb_, settings_, opts_ ] := Replace[
    convertToChatNotebook[ nb, settings, opts ],
    HoldPattern[ StyleDefinitions -> "Chatbook.nb" ] :> StyleDefinitions -> "Default.nb",
    { 1 }
];

convertToDefaultNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractNotebookChatSettings*)
extractNotebookChatSettings // beginDefinition;

extractNotebookChatSettings[ nbo_NotebookObject ] :=
    With[ { as = Association @ CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings" } ] },
        If[ AssociationQ @ as, as, <| |> ]
    ];

extractNotebookChatSettings[ Notebook[ __, TaggingRules -> KeyValuePattern[ "ChatNotebookSettings" -> as0_ ], ___ ] ] :=
    With[ { as = Association @ as0 },
        If[ AssociationQ @ as, as, <| |> ]
    ];

extractNotebookChatSettings[ _Notebook ] :=
    <| |>;

extractNotebookChatSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toNotebookExpression*)
toNotebookExpression // beginDefinition;
toNotebookExpression[ nb_Notebook ] := nb;
toNotebookExpression[ nb_NotebookObject ] := NotebookGet @ nb;
toNotebookExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellsToChatNB*)
cellsToChatNB // beginDefinition;

cellsToChatNB[ cells: { ___Cell } ] :=
    Notebook[ cells /. $fromWorkspaceChatConversionRules, StyleDefinitions -> "Chatbook.nb" ];

cellsToChatNB[ cells: { ___Cell }, settings_Association ] :=
    Module[ { dingbat, notebook },

        dingbat = Cell[ BoxData @ makeOutputDingbat @ settings, Background -> None ];
        notebook = updateCellDingbats[ cellsToChatNB @ cells, dingbat ];

        Append[
            notebook,
            TaggingRules -> <| "ChatNotebookSettings" -> KeyTake[ settings, $popOutSettings ] |>
        ]
    ];

cellsToChatNB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*updateCellDingbats*)
updateCellDingbats // beginDefinition;

updateCellDingbats[ cells_, outputDingbat_ ] := ReplaceAll[
    cells,
    {
        Cell[ a__, "ChatInput" , b___ ] :> Cell[ a, "ChatInput" , b, CellDingbat -> $evaluatedChatInputDingbat ],
        Cell[ a__, "ChatOutput", b___ ] :> Cell[ a, "ChatOutput", b, CellDingbat -> outputDingbat ]
    }
];

updateCellDingbats // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*$evaluatedChatInputDingbat*)
(* TODO: we should really have something better for this *)
$evaluatedChatInputDingbat = Cell[
    BoxData @ DynamicBox @ ToBoxes[
        If[ TrueQ @ CloudSystem`$CloudNotebooks,
            RawBoxes @ TemplateBox[ { }, "ChatIconUser" ],
            RawBoxes @ TemplateBox[ { }, "ChatInputCellDingbat" ]
        ],
        StandardForm
    ],
    Background  -> None,
    CellFrame   -> 0,
    CellMargins -> 0
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$fromWorkspaceChatConversionRules*)
$fromWorkspaceChatConversionRules := {
    (* Workspace chat *)
    Cell[ BoxData @ TemplateBox[ { Cell[ TextData[ text_ ], ___ ] }, "UserMessageBox", ___ ], "ChatInput", ___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatInput" ]
    ,
    Cell[ BoxData @ TemplateBox[ { text_ }, "UserMessageBox", ___ ], "ChatInput", ___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatInput" ]
    ,
    Cell[ BoxData @ TemplateBox[ { Cell[ text_, ___ ] }, "AssistantMessageBox", ___ ], "ChatOutput", ___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatOutput" ]
    ,
    (* side bar chat *)
    Cell[ BoxData @ TemplateBox[ { Cell[ TextData[ text_ ], ___ ] }, "NotebookAssistant`SideBar`UserMessageBox", ___ ], "NotebookAssistant`SideBar`ChatInput", ___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatInput" ]
    ,
    Cell[ BoxData @ TemplateBox[ { text_ }, "NotebookAssistant`SideBar`UserMessageBox", ___ ], "NotebookAssistant`SideBar`ChatInput", ___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatInput" ]
    ,
    Cell[ BoxData @ TemplateBox[ { Cell[ text_, ___ ] }, "NotebookAssistant`SideBar`AssistantMessageBox", ___ ], "NotebookAssistant`SideBar`ChatOutput", ___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatOutput" ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
