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


If[ $FrontEnd =!= Null && ! MemberQ[ $CommandLine, "-sandbox" ] && ! TrueQ @ Wolfram`ChatbookFrontEndServer`Private`$autoStarted,
    Wolfram`ChatbookFrontEndServer`Private`$autoStarted = True;
    Module[ { env, chatbook, result },
        env = Function[ name, Replace[ Environment @ name, Except[ s_String /; StringLength[ s ] > 0 ] -> Automatic ] ];

        Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "FrontEndServer.wl" };

        chatbook = env[ "CHATBOOK_FE_SERVER_CHATBOOK" ];
        If[ StringQ @ chatbook,
            Quiet[ PacletDirectoryLoad @ chatbook; Get[ "Wolfram`Chatbook`" ] ]
        ];

        result = Wolfram`ChatbookFrontEndServer`StartFrontEndServer[
            Replace[ env[ "CHATBOOK_FE_SERVER_PORT" ], s_String :> ToExpression @ s ],
            "Token" -> env[ "CHATBOOK_FE_SERVER_TOKEN" ],
            "Name"  -> env[ "CHATBOOK_FE_SERVER_NAME" ]
        ];

        If[ FailureQ @ result, Print[ "Failed to start front end server: ", result ] ]
    ]
];
