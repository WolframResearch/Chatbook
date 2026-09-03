#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet Directory*)
$scriptFile = If[ StringQ @ $InputFileName && $InputFileName =!= "", $InputFileName, "" ];

If[ $scriptFile === "",
    Print[ "Cannot locate this script: $InputFileName is unset." ];
    Exit[ 1 ]
];

$pacletDir = DirectoryName[ ExpandFileName @ $scriptFile, 2 ];

(* Guard the recursive deletes below against ever running outside the paclet. *)
If[ ! DirectoryQ @ $pacletDir || ! FileExistsQ @ FileNameJoin @ { $pacletDir, "PacletInfo.wl" },
    Print[ "Refusing to clean: no PacletInfo.wl found in ", $pacletDir ];
    Exit[ 1 ]
];

relative[ path_String ] := StringDelete[ path, StartOfString ~~ $pacletDir ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Artifact Groups*)

(* Each group is { label, paths }; the paths are collected once and reused for
   both the report and the deletion, so the two can never disagree. *)
$groups = {
    { "Compiled MX file",
      Select[
          { FileNameJoin @ {
                $pacletDir, "Source", "Chatbook",
                ToString[ $SystemWordLength ] <> "Bit", "Chatbook.mx"
            } },
          FileExistsQ
      ] },

    { "Build directory contents",
      FileNames[ "*", FileNameJoin @ { $pacletDir, "build" }, 1 ] },

    { "Test stack history",
      FileNames[ "*StackHistory.wxf", $pacletDir, 1 ] }
};

$targets = DeleteDuplicates @ Flatten[ Last /@ $groups ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Report*)
If[ $targets === { },
    Print[ "Nothing to clean in ", $pacletDir ];
    Exit[ 0 ]
];

Print[ "Removing:" ];

Scan[
    Function[ group,
        If[ Last @ group =!= { },
            Print[ "  ", First @ group, ":" ];
            Scan[ Print[ "    ", relative @ # ] &, Last @ group ]
        ]
    ],
    $groups
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Delete*)
Scan[
    If[ DirectoryQ @ #, DeleteDirectory[ #, DeleteContents -> True ], DeleteFile @ # ] &,
    $targets
];

Print[ "Done!" ];

EndPackage[ ];
