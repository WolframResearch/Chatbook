PreemptProtect[ BeginPackage[ "Wolfram`Chatbook`" ]; EndPackage[ ] ];

Wolfram`ChatbookLoader`$MXFile = FileNameJoin @ {
    DirectoryName @ $InputFileName,
    ToString @ $SystemWordLength <> "Bit",
    "Chatbook.mx"
};

Quiet[
    If[ FileExistsQ @ Wolfram`ChatbookLoader`$MXFile,
        Get @ Wolfram`ChatbookLoader`$MXFile,
        WithCleanup[
            Get[ "Wolfram`Chatbook`Main`" ],
            { $Context, $ContextPath, $ContextAliases } = { ## }
        ] & [ $Context, $ContextPath, $ContextAliases ]
    ],
    General::shdw
];
