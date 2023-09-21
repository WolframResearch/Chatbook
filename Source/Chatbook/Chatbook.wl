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
        Get @ Wolfram`ChatbookLoader`$MXFile
        ,
        WithCleanup[
            Get[ "Wolfram`Chatbook`Main`" ],
            { $Context, $ContextPath, $ContextAliases } = { ## }
        ] & [ $Context, $ContextPath, $ContextAliases ]
    ],
    General::shdw
];

(* Redraw any dynamics that might might have pink-boxed while loading *)
Wolfram`Chatbook`Dynamics`updateDynamics[ All ];