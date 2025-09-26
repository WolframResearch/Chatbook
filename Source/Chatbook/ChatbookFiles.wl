(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatbookFiles`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$chatbookRoot := FileNameJoin @ { ExpandFileName @ LocalObject @ $LocalBase, "Chatbook" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$ChatbookFilesDirectory*)
$ChatbookFilesDirectory := chatbookFilesDirectory[ { }, False ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatbookFilesDirectory*)
ChatbookFilesDirectory // beginDefinition;
ChatbookFilesDirectory // Options = { "EnsureDirectory" -> True };

ChatbookFilesDirectory[ opts: OptionsPattern[ ] ] :=
    catchMine @ chatbookFilesDirectory[ { }, OptionValue[ "EnsureDirectory" ] ];

ChatbookFilesDirectory[ name_String, opts: OptionsPattern[ ] ] :=
    catchMine @ chatbookFilesDirectory[ { name }, OptionValue[ "EnsureDirectory" ] ];

ChatbookFilesDirectory[ { names___String }, opts: OptionsPattern[ ] ] :=
    catchMine @ chatbookFilesDirectory[ { names }, OptionValue[ "EnsureDirectory" ] ];

ChatbookFilesDirectory // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatbookFilesDirectory*)
chatbookFilesDirectory // beginDefinition;

chatbookFilesDirectory[ { names___String }, ensure_ ] := Enclose[
    If[ TrueQ @ ensure,
        ConfirmBy[ GeneralUtilities`EnsureDirectory @ { $chatbookRoot, names }, DirectoryQ, "Directory" ],
        ConfirmBy[ FileNameJoin @ { $chatbookRoot, names }, StringQ, "Directory" ]
    ],
    throwInternalFailure
];

chatbookFilesDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
