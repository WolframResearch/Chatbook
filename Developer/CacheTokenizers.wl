(* This is used to backport tokenizers from later versions of WL to 13.3 so they can be included in the MX build. *)

(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`ChatbookDeveloper`" ];

`CacheTokenizers;

Begin[ "`Private`" ];

PacletInstall[ "Wolfram/LLMFunctions" ];
Block[ { $ContextPath }, Get[ "Wolfram`LLMFunctions`" ] ];

Get[ "Wolfram`Chatbook`" ];
Needs[ "Wolfram`Chatbook`Common`" ];
Needs[ "Developer`" -> None ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paths*)
$pacletDirectory    = DirectoryName[ $InputFileName, 2 ];
$tokenizerDirectory = FileNameJoin @ { $pacletDirectory, "Assets", "Tokenizers" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Aliases*)
ensureDirectory = GeneralUtilities`EnsureDirectory;
readWXFFile     = Developer`ReadWXFFile;
writeWXFFile    = Developer`WriteWXFFile;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CacheTokenizers*)
CacheTokenizers // ClearAll;

CacheTokenizers[ ] :=
    Enclose @ Module[ { tokenizers, exported },
        tokenizers = ConfirmBy[ Select[ cachedTokenizer @ All, MatchQ[ _NetEncoder ] ], AssociationQ, "Tokenizers" ];
        ConfirmAssert[ Length @ tokenizers > 0, "LengthCheck" ];
        exported = ConfirmBy[ Association @ KeyValueMap[ exportTokenizer, tokenizers ], AssociationQ, "Exported" ];
        exported
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exportTokenizer*)
exportTokenizer // ClearAll;
exportTokenizer[ name_String, tokenizer_NetEncoder ] :=
    Enclose @ Module[ { dir, file, exported },
        dir = ConfirmBy[ ensureDirectory @ $tokenizerDirectory, DirectoryQ, "Directory" ];
        file = FileNameJoin @ { dir, name <> ".wxf" };
        exported = ConfirmBy[ writeWXFFile[ file, tokenizer, PerformanceGoal -> "Size" ], FileExistsQ, "Export" ];
        ConfirmMatch[ readWXFFile[ exported ][ "Hello world" ], { __Integer }, "Verification" ];
        name -> exported
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
