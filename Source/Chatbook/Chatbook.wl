PreemptProtect[ BeginPackage[ "Wolfram`Chatbook`" ]; EndPackage[ ] ];

Wolfram`ChatbookLoader`$MXFile = FileNameJoin @ {
    DirectoryName @ $InputFileName,
    ToString @ $SystemWordLength <> "Bit",
    "Chatbook.mx"
};

If[ MemberQ[ $Packages, "Wolfram`Chatbook`" ]
    ,
    Wolfram`ChatbookLoader`$protectedNames = Replace[
        Wolfram`Chatbook`$ChatbookProtectedNames,
        Except[ _List ] :> Names[ "Wolfram`Chatbook`*" ]
    ];

    Wolfram`ChatbookLoader`$allNames = Replace[
        Wolfram`Chatbook`$ChatbookNames,
        Except[ _List ] :> Union[ Wolfram`ChatbookLoader`$protectedNames, Names[ "Wolfram`Chatbook`*`*" ] ]
    ];

    Unprotect @@ Wolfram`ChatbookLoader`$protectedNames;
    ClearAll @@ Wolfram`ChatbookLoader`$allNames;
];

Quiet[
    If[ FileExistsQ @ Wolfram`ChatbookLoader`$MXFile
        ,
        Get @ Wolfram`ChatbookLoader`$MXFile;
        (* Ensure all subcontexts are in $Packages to avoid reloading subcontexts out of order: *)
        If[ MatchQ[ Wolfram`Chatbook`$ChatbookContexts, { __String } ],
            WithCleanup[
                Unprotect @ $Packages,
                $Packages = DeleteDuplicates @ Join[ $Packages, Wolfram`Chatbook`$ChatbookContexts ],
                Protect @ $Packages
            ]
        ]
        ,
        WithCleanup[
            PreemptProtect @ Get[ "Wolfram`Chatbook`Main`" ],
            { $Context, $ContextPath, $ContextAliases } = { ## }
        ] & [ $Context, $ContextPath, $ContextAliases ]
    ],
    General::shdw
];

(* Redraw any dynamics that might might have pink-boxed while loading *)
Wolfram`Chatbook`Common`updateDynamics[ All ];

(* Set the paclet object for this paclet, ensuring that it corresponds to the one that's actually loaded: *)
Wolfram`Chatbook`Common`$thisPaclet = PacletObject @ File @ DirectoryName[ $InputFileName, 3 ];