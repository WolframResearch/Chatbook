(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`InlineChat`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluate Inline Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateInlineChat*)
evaluateInlineChat // beginDefinition;

evaluateInlineChat[ cell_CellObject, root_CellObject, Dynamic[ input_ ], Dynamic[ messageCells_ ] ] := Enclose[
    Catch @ Module[ { text },
        If[ ! validInputStringQ @ input, input = ""; Throw @ Null ];
        text = input;
        input = "";

        ConfirmMatch[
            AppendTo[ messageCells, Cell[ text, "ChatInput", Background -> White ] ],
            { __Cell },
            "MessageCells"
        ];

        Block[
            {
                $InlineChat = True,
                $inlineChatState = <|
                    "CurrentInput"   -> text,
                    "InlineChatCell" -> cell,
                    "MessageCells"   -> Dynamic @ messageCells
                |>
            },
            ConfirmMatch[ ChatCellEvaluate @ root, _ChatObject|Null, "ChatCellEvaluate" ]
        ]
    ],
    throwInternalFailure
];

evaluateInlineChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validInputStringQ*)
validInputStringQ // beginDefinition;
validInputStringQ[ input_String? StringQ ] := ! StringMatchQ[ input, WhitespaceCharacter... ];
validInputStringQ[ _ ] := False
validInputStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createNewInlineOutput*)
createNewInlineOutput // beginDefinition;
createNewInlineOutput[ settings_, target_, cell_ ] := createNewInlineOutput0[ settings, cell, $inlineChatState ];
createNewInlineOutput // endDefinition;


createNewInlineOutput0 // beginDefinition;

createNewInlineOutput0[
    settings_,
    cell_Cell,
    KeyValuePattern @ {
        "InlineChatCell" -> chatCell_,
        "MessageCells"   -> Dynamic[ messageCells_ ]
    }
] := Enclose[
    ConfirmMatch[ AppendTo[ messageCells, cell ], { __Cell }, "MessageCells" ];
    chatCell,
    throwInternalFailure
];

createNewInlineOutput0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeInlineChatOutputCell*)
writeInlineChatOutputCell // beginDefinition;
writeInlineChatOutputCell[ cell_, new_Cell, settings_ ] := Null; (* FIXME: Do the thing *)
writeInlineChatOutputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
