#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*incrementPacletVersion*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::LeakedVariable:: *)
incrementPacletVersion[ dir_ ] := Enclose[
    Catch @ Module[
        { cs, file, string, version, newVersion, new },

        cs      = ConfirmBy[ #1, StringQ, #2 ] &;
        file    = cs[ FileNameJoin @ { dir, "PacletInfo.wl" }, "PacletInfo" ];
        string  = cs[ ReadString @ file, "ReadString" ];
        version = cs[ PacletObject[ Flatten @ File @ dir ][ "Version" ], "Version" ];

        If[ StringEndsQ[ version, "." ~~ "0".. ~~ EndOfString ],
            Print[ "Skipping paclet version update: ", version ];
            Throw @ version
        ];

        newVersion = cs[
            StringReplace[
                version,
                "." ~~ v: DigitCharacter.. ~~ EndOfString :> "." <> ToString[ ToExpression @ v + 1 ]
            ],
            "NewVersion"
        ];

        ConfirmAssert[ PacletNewerQ[ newVersion, version ], "PacletNewerQ" ];

        new = cs[
            StringReplace[
                string,
                pre: ("\"Version\"" ~~ $$ws ~~ "->" ~~ $$ws) ~~ "\"" ~~ version ~~ "\"" :>
                    pre <> "\"" <> newVersion <> "\""
            ],
            "UpdatedPacletInfo"
        ];

        Print[ "Incrementing version: ", version, " -> ", newVersion ];
        Confirm[ WithCleanup[ BinaryWrite[ file, new ], Close @ file ], "WritePacletInfo" ];

        ConfirmMatch[
            PacletObject[ Flatten @ File @ dir ][ "Version" ],
            newVersion,
            "PacletObject"
        ]
    ],
    Function[
        Print[ "::error::Failed to increment paclet version." ];
        Print[ "    ", ToString[ #, InputForm ] ];
        If[ StringQ @ Environment[ "GITHUB_ACTION" ], Exit[ 1 ] ]
    ]
];
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
result = cicd`ScriptConfirmBy[ incrementPacletVersion @ $pacletDir, StringQ ];

EndPackage[ ];

Wolfram`ChatbookScripts`result