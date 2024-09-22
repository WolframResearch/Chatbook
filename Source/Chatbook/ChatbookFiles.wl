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
$ChatbookFilesDirectory := chatbookFilesDirectory @ { };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatbookFilesDirectory*)
ChatbookFilesDirectory // beginDefinition;
ChatbookFilesDirectory[ ] := catchMine @ chatbookFilesDirectory @ { };
ChatbookFilesDirectory[ name_String ] := catchMine @ chatbookFilesDirectory @ { name };
ChatbookFilesDirectory[ { names___String } ] := catchMine @ chatbookFilesDirectory @ { names };
ChatbookFilesDirectory // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatbookFilesDirectory*)
chatbookFilesDirectory // beginDefinition;

chatbookFilesDirectory[ { names___String } ] := Enclose[
    ConfirmBy[ GeneralUtilities`EnsureDirectory @ { $chatbookRoot, names }, DirectoryQ, "Directory" ],
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
