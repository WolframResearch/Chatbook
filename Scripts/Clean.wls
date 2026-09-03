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

$exitCode = 0;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Artifact Groups*)

(* Each group is { label, paths }; the paths are collected once and reused for
   both the report and the deletion, so the two can never disagree. *)
$groups = {
    (* Every *Bit subdirectory, so a stale MX from another word length also goes. *)
    { "Compiled MX file",
      FileNames[ "Chatbook.mx", FileNameJoin @ { $pacletDir, "Source", "Chatbook" }, 2 ] },

    { "Build directory",
      Select[ { FileNameJoin @ { $pacletDir, "build" } }, DirectoryQ ] },

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
$failures = { };

removePath[ path_String ] := (
    Quiet @ If[ DirectoryQ @ path,
                DeleteDirectory[ path, DeleteContents -> True ],
                DeleteFile @ path
            ];
    (* Trust the filesystem rather than the return value. *)
    If[ FileExistsQ @ path || DirectoryQ @ path, AppendTo[ $failures, path ] ]
);

Scan[ removePath, $targets ];

If[ $failures =!= { },
    Print[ "Failed to remove ", Length @ $failures, " item(s):" ];
    Scan[ Print[ "    ", relative @ # ] &, $failures ];
    $exitCode = 1
    ,
    Print[ "Removed ", Length @ $targets, " item(s)." ]
];

EndPackage[ ];

(* Fully qualified: EndPackage has already popped the context. *)
Exit[ Wolfram`ChatbookScripts`$exitCode ]
