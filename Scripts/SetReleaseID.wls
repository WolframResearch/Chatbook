#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::LeakedVariable:: *)

(* cSpell: ignore gitSHAQ *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

$$ws = WhitespaceCharacter...;
$$id = "\"" ~~ Except[ "\"" ].. ~~ "\"";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setPacletReleaseID*)
setPacletReleaseID // ClearAll;

setPacletReleaseID[ File[ dir_ ] ] :=
    Enclose @ Module[ { id, file, bytes, string, new },
        id = ConfirmBy[ getReleaseID @ dir, StringQ, "ReleaseID" ];
        file = ConfirmBy[ FileNameJoin @ { dir, "PacletInfo.wl" }, FileExistsQ, "PacletInfoFile" ];
        bytes = ConfirmBy[ ReadByteArray @ file, ByteArrayQ, "ByteArray" ];
        Quiet @ Close @ file;
        string = ConfirmBy[ ByteArrayToString @ bytes, StringQ, "String" ];
        new = StringReplace[ string, before: ("\"ReleaseID\""~~$$ws~~"->"~~$$ws) ~~ $$id :> before<>"\""<>id<>"\"" ];
        cicd`ConsoleNotice @ SequenceForm[ "Setting paclet release ID: ", id ];
        WithCleanup[ BinaryWrite[ file, StringToByteArray @ new ], Close @ file ];
        id
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getReleaseID*)
getReleaseID // ClearAll;

getReleaseID[ dir_ ] := getReleaseID[ dir, $ScriptCommandLine ];
getReleaseID[ dir_, { _, id_? gitSHAQ } ] := StringTrim @ id;

getReleaseID[ dir_, _ ] :=
    Module[ { sha },
        sha = Quiet @ RunProcess[ { "git", "rev-parse", "HEAD" }, "StandardOutput", ProcessDirectory -> dir ];
        If[ gitSHAQ @ sha, StringTrim @ sha, "$RELEASE_ID$" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*gitSHAQ*)
gitSHAQ // ClearAll;
gitSHAQ[ id_String ] := StringMatchQ[ id, $$ws ~~ Repeated[ HexadecimalCharacter, { 40 } ] ~~ $$ws ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)

result = cicd`ScriptConfirmBy[ setPacletReleaseID @ Flatten @ File @ $pacletDir, StringQ ]

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];

Wolfram`ChatbookScripts`result