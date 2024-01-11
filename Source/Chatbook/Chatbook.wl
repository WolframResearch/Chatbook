PreemptProtect[ BeginPackage[ "Wolfram`Chatbook`" ]; EndPackage[ ] ];

Wolfram`ChatbookLoader`$MXFile = FileNameJoin @ {
    DirectoryName @ $InputFileName,
    ToString @ $SystemWordLength <> "Bit",
    "Chatbook.mx"
};

Quiet[
    If[ FileExistsQ @ Wolfram`ChatbookLoader`$MXFile
        ,
        Unprotect[ "Wolfram`Chatbook`*" ];
        ClearAll[ "Wolfram`Chatbook`*" ];
        ClearAll[ "Wolfram`Chatbook`*`*" ];
        Get @ Wolfram`ChatbookLoader`$MXFile;
        (* Ensure all subcontexts are in $Packages to avoid reloading subcontexts out of order: *)
        WithCleanup[
            Unprotect @ $Packages,
            $Packages = DeleteDuplicates @ Join[
                $Packages,
                Select[ Contexts[ "Wolfram`Chatbook`*" ], StringFreeQ[ "`Private`" ] ]
            ],
            Protect @ $Packages
        ]
        ,
        WithCleanup[
            PreemptProtect[
                Quiet[
                    Unprotect[ "Wolfram`Chatbook`*" ];
                    ClearAll[ "Wolfram`Chatbook`*" ];
                    Remove[ "Wolfram`Chatbook`*`*" ],
                    { Remove::rmnsm }
                ];
                Get[ "Wolfram`Chatbook`Main`" ]
            ],
            { $Context, $ContextPath, $ContextAliases } = { ## }
        ] & [ $Context, $ContextPath, $ContextAliases ]
    ],
    General::shdw
];

(* Set the paclet object for this paclet, ensuring that it corresponds to the one that's actually loaded: *)
Wolfram`Chatbook`Common`$thisPaclet = PacletObject @ File @ DirectoryName[ $InputFileName, 3 ];

(* Redraw any dynamics that might might have pink-boxed while loading *)
Wolfram`Chatbook`Dynamics`updateDynamics[ All ];