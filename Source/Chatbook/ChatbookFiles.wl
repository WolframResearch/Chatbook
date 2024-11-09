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
(*Rename Code Assistance Files*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*renameCodeAssistanceFiles*)
(* This is a temporary measure to ensure that files associated with the renamed "CodeAssistance" app name are
   preserved under the new name. It can and should be removed before official release. *)
renameCodeAssistanceFiles // beginDefinition;

renameCodeAssistanceFiles[ ] := Enclose[
    Module[ { root, chats1, chats2, search1, search2 },
        root = ConfirmBy[ $chatbookRoot, StringQ, "Root" ];

        chats1 = FileNameJoin @ { root, "SavedChats", "CodeAssistance" };
        chats2 = FileNameJoin @ { root, "SavedChats", "NotebookAssistance" };
        If[ DirectoryQ @ chats1 && ! DirectoryQ @ chats2, RenameDirectory[ chats1, chats2 ] ];

        search1 = FileNameJoin @ { root, "Search", "CodeAssistance" };
        search2 = FileNameJoin @ { root, "Search", "NotebookAssistance" };
        If[ DirectoryQ @ search1 && ! DirectoryQ @ search2, RenameDirectory[ search1, search2 ] ];

        renameCodeAssistanceFiles[ ] = Null;
    ] // LogChatTiming[ "RenameCodeAssistanceFiles" ],
    throwInternalFailure
];

renameCodeAssistanceFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
