(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Serialization`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ErrorUtils`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inputFormLine*)
inputFormLine // beginDefinition;

(* InputForm on one line in printable ASCII, with every symbol outside of System` written with its context: *)
inputFormLine[ expr_ ] :=
    Block[ { $Context = "System`", $ContextPath = { "System`" } },
        ToString[ Unevaluated @ expr, InputForm, PageWidth -> Infinity, CharacterEncoding -> "PrintableASCII" ]
    ];

inputFormLine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
