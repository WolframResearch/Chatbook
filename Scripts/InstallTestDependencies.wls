#!/usr/bin/env wolframscript

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

PacletSiteUpdate @ PacletSites[ ];

PacletInstall[ "OAuth" ];
PacletInstall[ "ServiceConnection_OpenAI" ];
PacletInstall[ "ServiceConnectionUtilities" ];
PacletInstall[ "Wolfram/LLMFunctions" ];

(* A prebuilt version of the SemanticSearch paclet is included for running tests on 13.3: *)
If[ ! PacletObjectQ @ Quiet @ PacletInstall[ "SemanticSearch" ],
    PacletInstall @ FileNameJoin @ {
        DirectoryName[ $InputFileName, 2 ],
        "Developer/Resources/Paclets/SemanticSearch.paclet"
    }
];

Scan[
    Print[ "Name: ", #[ "Name" ], "\t\tVersion: ", #[ "Version" ] ] &,
    PacletObject /@ {
        "OAuth",
        "ServiceConnection_OpenAI",
        "ServiceConnectionUtilities",
        "Wolfram/LLMFunctions",
        "SemanticSearch"
    }
];

If[ ! PacletObjectQ @ PacletObject[ "SemanticSearch" ],
    Print[ "::error::Failed to install SemanticSearch." ];
    Exit[ 1 ]
];
(* :!CodeAnalysis::EndBlock:: *)