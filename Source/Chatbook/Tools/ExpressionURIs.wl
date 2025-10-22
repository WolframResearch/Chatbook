(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$expressionSchemes = { "attachment", "audio", "dynamic", "expression", "video" };
$$expressionScheme = Alternatives @@ $expressionSchemes;

$$expressionURIKey := "content-" ~~ Repeated[ LetterCharacter|DigitCharacter, $tinyHashLength ];

$attachmentTypes     = { "Expressions", "ToolCalls" };
$$attachmentProperty = Alternatives @@ $attachmentTypes;

$attachments = <| |>;

$$attachmentURI := $$expressionScheme ~~ "://" ~~ $$expressionURIKey;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FormatToolResponse*)
FormatToolResponse // ClearAll;
FormatToolResponse[ response_ ] := makeToolResponseString @ response;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeToolResponseString*)
makeToolResponseString // beginDefinition;

makeToolResponseString[ failure_Failure ] := makeFailureString @ failure;

makeToolResponseString[ expr_? simpleResultQ ] :=
    With[ { string = fixLineEndings @ TextString @ expr },
        If[ StringLength @ string < $toolResultStringLength,
            If[ StringContainsQ[ string, "\n" ], "\n" <> string, string ],
            StringJoin[
                "\n",
                fixLineEndings @ ToString[
                    Unevaluated @ Short[ expr, Floor[ $toolResultStringLength / 100 ] ],
                    OutputForm,
                    PageWidth -> 100
                ],
                "\n\n\n",
                makeExpressionURI[ "expression", "Formatted Result", Unevaluated @ expr ]
            ]
        ]
    ];

makeToolResponseString[ expr_ ] := makeExpressionURI @ expr;

makeToolResponseString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MakeExpressionURI*)
MakeExpressionURI // ClearAll;
MakeExpressionURI[ args___, expr_ ] := makeExpressionURI[ args, Unevaluated @ expr ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeExpressionURI*)
makeExpressionURI // beginDefinition;

makeExpressionURI[ expr_ ] :=
    makeExpressionURI[ Automatic, Unevaluated @ expr ];

makeExpressionURI[ label_, expr_ ] :=
    makeExpressionURI[ Automatic, label, Unevaluated @ expr ];

makeExpressionURI[ Automatic, label_, expr_ ] :=
    makeExpressionURI[ expressionURIScheme @ expr, label, Unevaluated @ expr ];

makeExpressionURI[ scheme_, Automatic, expr_ ] :=
    makeExpressionURI[ scheme, expressionURILabel @ expr, Unevaluated @ expr ];

makeExpressionURI[ scheme_, label_, expr_ ] :=
    With[ { id = "content-" <> tinyHash @ Unevaluated @ expr },
        $attachments[ id ] = expandMarkdownExpressions @ HoldComplete @ expr;
        "![" <> TextString @ label <> "](" <> TextString @ scheme <> "://" <> id <> ")"
    ];

makeExpressionURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expandMarkdownExpressions*)
expandMarkdownExpressions // beginDefinition;

expandMarkdownExpressions[ expr_ ] := ReplaceRepeated[
    expr,
    {
        markdownExpression[ uri_String ] :> RuleCondition @ GetExpressionURI[ uri, heldMarkdownExpression ],
        heldMarkdownExpression[ e___ ] :> e
    }
];

expandMarkdownExpressions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*markdownExpression*)
markdownExpression // ClearAll;

Scan[
    Function[ markdownExpression /: Format[ markdownExpression[ str_String ], # ] := OutputForm @ str ],
    $OutputForms
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*heldMarkdownExpression*)
heldMarkdownExpression // ClearAll;
heldMarkdownExpression // Attributes = { HoldAllComplete };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expressionURIScheme*)
expressionURIScheme // beginDefinition;
expressionURIScheme // Attributes = { HoldAllComplete };
expressionURIScheme[ _Video ] := (needsURIPrompt[ "SpecialURIVideo" ]; "video");
expressionURIScheme[ _Audio ] := (needsURIPrompt[ "SpecialURIAudio" ]; "audio");
expressionURIScheme[ _Manipulate|_DynamicModule|_Dynamic ] := (needsURIPrompt[ "SpecialURIDynamic" ]; "dynamic");
expressionURIScheme[ gfx_ ] /; graphicsQ @ Unevaluated @ gfx := "attachment";
expressionURIScheme[ _ ] := "expression";
expressionURIScheme // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*needsURIPrompt*)
needsURIPrompt // beginDefinition;

needsURIPrompt[ name_String ] := (
    needsBasePrompt[ name ];
    If[ toolSelectedQ[ "WolframLanguageEvaluator" ], needsBasePrompt[ "SpecialURIImporting" ] ]
);

needsURIPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*expressionURILabel*)
expressionURILabel // beginDefinition;
expressionURILabel // Attributes = { HoldAllComplete };

(* Audio *)
expressionURILabel[ Audio[ path_String, ___ ] ] := "Audio Player: " <> path;
expressionURILabel[ Audio[ File[ path_String ], ___ ] ] := "Audio Player: " <> path;
expressionURILabel[ _Audio ] := "Embedded Audio Player";

(* Video *)
expressionURILabel[ Video[ path_String, ___ ] ] := "Video Player: " <> path;
expressionURILabel[ Video[ File[ path_String ], ___ ] ] := "Video Player: " <> path;
expressionURILabel[ _Video ] := "Embedded Video Player";

(* Dynamic *)
expressionURILabel[ _Manipulate ] := "Embedded Interactive Content";

(* Graphics *)
expressionURILabel[ _Graph|_Graph3D ] := "Graph";
expressionURILabel[ _Tree ] := "Tree";
expressionURILabel[ gfx_ ] /; graphicsQ @ Unevaluated @ gfx := "Image";

(* Data *)
expressionURILabel[ _List|_Association ] := "Data";

(* Other *)
expressionURILabel[ _ ] := "Content";

expressionURILabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetExpressionURIs*)
GetExpressionURIs // ClearAll;
GetExpressionURIs // Options = { Tooltip -> Automatic };

GetExpressionURIs[ str_, opts: OptionsPattern[ ] ] :=
    GetExpressionURIs[ str, ## &, opts ];

GetExpressionURIs[ str_String, wrapper_, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $uriTooltip = OptionValue @ Tooltip },
        StringSplit[
            str,
            link: Shortest[ "![" ~~ __ ~~ "](" ~~ __ ~~ ")" ] /; expressionURIQ @ link :>
                catchAlways @ GetExpressionURI[ link, wrapper ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*expressionURIQ*)
expressionURIQ // beginDefinition;
expressionURIQ[ str_String ] := expressionURIKeyQ @ expressionURIKey @ str;
expressionURIQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*expressionURIKeyQ*)
expressionURIKeyQ // beginDefinition;
expressionURIKeyQ[ key_String ] := StringMatchQ[ key, $$expressionURIKey ];
expressionURIKeyQ[ _ ] := False;
expressionURIKeyQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*expressionURIKey*)
expressionURIKey // beginDefinition;

expressionURIKey[ str_String ] := expressionURIKey[ str ] = FixedPoint[
    StringDelete @ {
        StartOfString ~~ ("!["|"[") ~~ __ ~~ "](",
        StartOfString ~~ LetterCharacter.. ~~ "://",
        ")"~~EndOfString
    },
    str
];

expressionURIKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetExpressionURI*)
GetExpressionURI // beginDefinition;
GetExpressionURI // Options = { Tooltip -> Automatic };

GetExpressionURI[ uri_, opts: OptionsPattern[ ] ] :=
    catchMine @ GetExpressionURI[ uri, ## &, opts ];

GetExpressionURI[ URL[ uri_ ], wrapper_, opts: OptionsPattern[ ] ] :=
    catchMine @ GetExpressionURI[ uri, wrapper, opts ];

GetExpressionURI[ uri_String, wrapper_, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Module[ { held },
        held = ConfirmMatch[ getExpressionURI[ uri, OptionValue[ Tooltip ] ], _HoldComplete, "GetExpressionURI" ];
        wrapper @@ held
    ],
    throwInternalFailure
];

GetExpressionURI[ All, wrapper_, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Module[ { attachments },
        attachments = ConfirmBy[ $attachments, AssociationQ, "Attachments" ];
        ConfirmAssert[ AllTrue[ attachments, MatchQ[ _HoldComplete ] ], "HeldAttachments" ];
        Replace[ attachments, HoldComplete[ a___ ] :> RuleCondition @ wrapper @ a, { 1 } ]
    ],
    throwInternalFailure
];

GetExpressionURI // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getExpressionURI*)
getExpressionURI // beginDefinition;
getExpressionURI[ uri_, tooltip_ ] := Block[ { $tooltip = tooltip }, getExpressionURI0 @ uri ];
getExpressionURI // endDefinition;


getExpressionURI0 // beginDefinition;

getExpressionURI0[ str_String ] :=
    Module[ { split },

        split = First[
            StringSplit[ str, "![" ~~ alt__ ~~ "](" ~~ url__ ~~ ")" :> { alt, StringReplace[ url, "\\/" -> "/" ] } ],
            $Failed
        ];

        getExpressionURI0 @@ split /; MatchQ[ split, { _String, _String } ]
    ];

getExpressionURI0[ uri_String ] := getExpressionURI0[ None, uri ];

getExpressionURI0[ tooltip_, uri_String? expressionURIKeyQ ] :=
    getExpressionURI0[ tooltip, uri, <| "Domain" -> uri |> ];

getExpressionURI0[ tooltip_, uri_String ] := getExpressionURI0[ tooltip, uri, URLParse @ uri ];

getExpressionURI0[ tooltip_, uri_, as: KeyValuePattern[ "Domain" -> key_? expressionURIKeyQ ] ] :=  Enclose[
    ConfirmMatch[ displayAttachment[ uri, tooltip, key ], _HoldComplete, "DisplayAttachment" ],
    throwInternalFailure
];

getExpressionURI0[ tooltip_, uri_String, as_ ] :=
    throwFailure[ "InvalidExpressionURI", uri ];

getExpressionURI0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*displayAttachment*)
displayAttachment // beginDefinition;

displayAttachment[ uri_, None, key_ ] :=
    getAttachment[ uri, key ];

displayAttachment[ uri_, tooltip_String, key_ ] := Enclose[
    Replace[
        ConfirmMatch[ getAttachment[ uri, key ], _HoldComplete, "GetAttachment" ],
        HoldComplete[ expr_ ] :>
            If[ TrueQ @ $tooltip,
                HoldComplete @ Tooltip[ expr, tooltip ],
                HoldComplete @ expr
            ]
    ],
    throwInternalFailure
];

displayAttachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAttachment*)
getAttachment // beginDefinition;

getAttachment[ uri_String, key_String ] :=
    Lookup[ $attachments, key, throwFailure[ "URIUnavailable", uri ] ];

getAttachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetAttachments*)
GetAttachments // beginDefinition;

GetAttachments[ ] :=
    GetAttachments[ None, All ];

GetAttachments[ prop: $$attachmentProperty ] :=
    GetAttachments[ None, prop ];

GetAttachments[ messages_ ] :=
    catchMine @ GetAttachments[ messages, All ];

GetAttachments[ messages: $$chatMessages|None, prop: $$attachmentProperty|All ] :=
    catchMine @ getAttachments[ messages, prop ];

GetAttachments[ content_, prop: $$attachmentProperty|All ] :=
    catchMine @ getAttachments[ ensureChatMessages @ content, prop ];

GetAttachments // endExportedDefinition;

(* TODO: this should identify expression and tool call keys from earlier sessions and give Missing[...] for those *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAttachments*)
getAttachments // beginDefinition;

getAttachments[ messages_List, All ] := Enclose[
    Catch @ Module[ { allExprKeys, allToolKeys, string, exprKeys, toolKeys, exprs, toolCalls },
        allExprKeys = ConfirmMatch[ Keys @ $attachments, { ___String }, "ExpressionKeys" ];
        allToolKeys = ConfirmMatch[ Keys @ $toolEvaluationResults, { ___String }, "ToolKeys" ];
        string = ConfirmBy[ messagesToString[ messages, "MessageTemplate" -> None ], StringQ, "String" ];
        exprKeys = DeleteDuplicates @ StringCases[ string, allExprKeys ];
        toolKeys = DeleteDuplicates @ StringCases[ string, "ENDRESULT("~~key:allToolKeys~~")" :> key ];
        exprs = ConfirmBy[ KeyTake[ $attachments, exprKeys ], AssociationQ, "Expressions" ];
        toolCalls = ConfirmBy[ KeyTake[ $toolEvaluationResults, toolKeys ], AssociationQ, "ToolCalls" ];
        <| "Expressions" -> exprs, "ToolCalls" -> toolCalls |>
    ],
    throwInternalFailure
];

getAttachments[ None, All ] := Enclose[
    <|
        "Expressions" -> ConfirmBy[ $attachments, AssociationQ, "Expressions" ],
        "ToolCalls"   -> ConfirmBy[ $toolEvaluationResults, AssociationQ, "ToolCalls" ]
    |>,
    throwInternalFailure
];

getAttachments[ messages_, prop: $$attachmentProperty ] := Enclose[
    ConfirmBy[ getAttachments[ messages, All ][ prop ], AssociationQ, "Result" ],
    throwInternalFailure
];

getAttachments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LoadAttachments*)
LoadAttachments // beginDefinition;
LoadAttachments[ as_Association ] := catchMine @ LoadAttachments[ "Expressions", as ];
LoadAttachments[ type: "Expressions"|"ToolCalls", as_Association ] := catchMine @ loadAttachments[ type, as ];
LoadAttachments // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadAttachments*)
loadAttachments // beginDefinition;

loadAttachments[ "Expressions", expressions_Association ] := Enclose[
    $attachments = ConfirmBy[ <| $attachments, expressions |>, AssociationQ, "Attachments" ],
    throwInternalFailure
];

loadAttachments[ "ToolCalls", toolCalls_Association ] := Enclose[
    $toolEvaluationResults = ConfirmBy[ <| $toolEvaluationResults, toolCalls |>, AssociationQ, "ToolCalls" ],
    throwInternalFailure
];

loadAttachments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
