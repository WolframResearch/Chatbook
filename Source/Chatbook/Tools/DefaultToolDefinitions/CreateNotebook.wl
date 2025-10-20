(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Icon*)
$createNotebookIcon = RawBoxes @ DynamicBox @ FEPrivate`FrontEndResource[ "FEBitmaps", "NotebookIcon" ][
    LightDarkSwitched[ GrayLevel[ 0.651 ], GrayLevel[ 0.6317181 ] ],
    LightDarkSwitched[ RGBColor[ 0.86667, 0.066667, 0. ], RGBColor[ 1, 0.4537951, 0.3912115 ] ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
$createNotebookDescription = "\
Create a new notebook for the user by providing the content as markdown. \
The tool will automatically convert the markdown to a notebook and open it for the user.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "CreateNotebook" ] = <|
    toolDefaultData[ "CreateNotebook" ],
    "ShortName"          -> "create_nb",
    "Icon"               -> $createNotebookIcon,
    "Description"        -> $createNotebookDescription,
    "Enabled"            :> ! TrueQ @ $AutomaticAssistance,
    "Function"           -> createNotebook,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "content" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The content of the notebook given as markdown",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createNotebook*)
createNotebook // beginDefinition;

createNotebook[ KeyValuePattern[ "content" -> content_ ] ] :=
    createNotebook @ content;

createNotebook[ content_String ] := Enclose[
    Module[ { formatted, exploded, notebook, nbo },
        formatted = FormatChatOutput[ content, <| "Status" -> "Finished" |> ];
        exploded = ConfirmMatch[ ExplodeCell @ formatted, { ___Cell }, "Exploded" ];
        notebook = Notebook @ exploded;
        nbo = NotebookPut @ notebook;
        <| "Result" -> nbo, "String" -> ToString[ nbo, InputForm ] |>
    ],
    throwInternalFailure
];

createNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
