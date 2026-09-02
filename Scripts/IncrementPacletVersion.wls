#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*githubRepository*)
githubRepository[ dir_ ] := Enclose[
    Module[ { env, url },
        env = Environment[ "GITHUB_REPOSITORY" ];
        If[ StringQ @ env,
            env,
            url = ConfirmBy[ gitCommand[ { "remote", "get-url", "origin" }, dir ], StringQ, "OriginURL" ];
            ConfirmBy[
                First[
                    StringCases[
                        url,
                        "github.com" ~~ (":" | "/") ~~ owner: Except[ "/" ].. ~~ "/" ~~ name: Except[ "/" ].. :>
                            owner <> "/" <> StringDelete[ name, ".git" ~~ EndOfString ]
                    ],
                    $Failed
                ],
                StringQ,
                "Repository"
            ]
        ]
    ],
    $Failed &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseAssetURL*)
releaseAssetURL[ dir_, version_ ] := Enclose[
    Module[ { repo, name, file },
        repo = ConfirmBy[ githubRepository @ dir, StringQ, "Repository" ];
        name = ConfirmBy[ PacletObject[ Flatten @ File @ dir ][ "Name" ], StringQ, "PacletName" ];
        file = StringReplace[ name, "/" -> "__" ] <> "-" <> version <> ".paclet";
        TemplateApply[ "https://github.com/`1`/releases/download/v`2`/`3`", { repo, version, file } ]
    ],
    $Failed &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*versionReleasedQ*)
$releaseCheckTimeout = 30;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
versionReleasedQ[ dir_, version_ ] :=
    versionReleasedQ[ dir, version, releaseAssetURL[ dir, version ] ];

versionReleasedQ[ _, _, url_String ] :=
    Module[ { status },
        status = Quiet @ URLRead[
            HTTPRequest[ url, <| "Method" -> "HEAD" |> ],
            "StatusCode",
            FollowRedirects -> True, (* Avoids a 302 response *)
            TimeConstraint  -> $releaseCheckTimeout
        ];
        Which[
            status === 200,
                Print[ "Release artifact found: ", url ];
                True,
            status === 404,
                Print[ "Release artifact not found: ", url ];
                False,
            True,
                Print[ "::warning::Release artifact check failed (", ToString[ status, InputForm ], "): ", url ];
                False
        ]
    ];

versionReleasedQ[ _, version_, _ ] := (
    Print[ "::warning::Unable to determine release artifact URL for version ", version, "." ];
    False
);
(* :!CodeAnalysis::EndBlock:: *)

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

        If[ StringEndsQ[ version, "." ~~ "0".. ~~ EndOfString ] && ! TrueQ @ versionReleasedQ[ dir, version ],
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