(* ::Package:: *)

(* ::Text:: *)
(*Kernel initialization file that starts a front end server automatically.*)
(**)
(*Usage (normally done for you by `fe.py launch`):*)
(*    export WOLFRAMINIT="-initfile /path/to/Chatbook/Developer/FrontEndServer/Init.wl"*)
(*    WolframNB*)
(**)
(*Optional environment variables:*)
(*    CHATBOOK_FE_SERVER_PORT      port to listen on (default: first free port in 2400-2499)*)
(*    CHATBOOK_FE_SERVER_TOKEN     access token (default: random UUID, written to the registry file)*)
(*    CHATBOOK_FE_SERVER_NAME      display name for the server*)
(*    CHATBOOK_FE_SERVER_REGISTRY  directory for registry files*)
(*    CHATBOOK_FE_SERVER_CHATBOOK  path to a Chatbook paclet directory to load into the kernel at startup*)
(**)
(*WOLFRAMINIT is inherited by every kernel the front end (or its kernels) launch, so only the main kernel of a front end*)
(*starts a server: the front end's "-sandbox" system kernel and kernels without a front end (subkernels, sandboxes) are skipped.*)
(*With a fixed port (CHATBOOK_FE_SERVER_PORT, which `fe.py launch` sets), other kernels of the same front end (e.g. of an*)
(*evaluator added by `fe.py snoop --evaluator-only`) find the port taken by its server and leave it at that; without*)
(*one, each of them starts a server of its own. When `fe.py snoop` moves the server to a new kernel, that kernel starts*)
(*it again.*)


If[ $FrontEnd =!= Null && ! MemberQ[ $CommandLine, "-sandbox" ] && ! TrueQ @ Wolfram`ChatbookFrontEndServer`Private`$autoStarted,
    Wolfram`ChatbookFrontEndServer`Private`$autoStarted = True;
    Module[ { env, chatbook, port, token, start, servedQ, result },
        env = Function[ name, Replace[ Environment @ name, Except[ s_String /; StringLength[ s ] > 0 ] -> Automatic ] ];

        Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "FrontEndServer.wl" };

        chatbook = env[ "CHATBOOK_FE_SERVER_CHATBOOK" ];
        If[ StringQ @ chatbook,
            Quiet[ PacletDirectoryLoad @ chatbook; Get[ "Wolfram`Chatbook`" ] ]
        ];

        port  = Replace[ env[ "CHATBOOK_FE_SERVER_PORT" ], s_String :> ToExpression @ s ];
        token = env[ "CHATBOOK_FE_SERVER_TOKEN" ];
        start = Function @ Wolfram`ChatbookFrontEndServer`StartFrontEndServer[
            port,
            "Token" -> token,
            "Name"  -> env[ "CHATBOOK_FE_SERVER_NAME" ]
        ];

        (* Whether another kernel of this front end runs the server (its registry file has this front end's token): *)
        servedQ = Function @ And[
            IntegerQ @ port,
            StringQ @ token,
            MatchQ[
                Quiet @ Import[
                    FileNameJoin @ { Wolfram`ChatbookFrontEndServer`$FrontEndServerRegistryDirectory, ToString @ port <> ".json" },
                    "RawJSON"
                ],
                KeyValuePattern[ "Token" -> token ]
            ]
        ];

        result = start[ ];
        (* The kernel that hands the server over to this one may not have closed the port yet: *)
        Do[ If[ FailureQ @ result && IntegerQ @ port && ! servedQ[ ], Pause[ 1 ]; result = start[ ] ], { 5 } ];

        If[ FailureQ @ result && ! servedQ[ ], Print[ "Failed to start front end server: ", result ] ]
    ]
];
