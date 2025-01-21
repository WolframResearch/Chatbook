(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Graphics`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$graphicsPattern = HoldPattern @ Alternatives[
    _System`AstroGraphics,
    _GeoGraphics,
    _Graphics,
    _Graphics3D,
    _Image,
    _Image3D,
    _Legended,
    Dynamic[ RawBoxes[ _FEPrivate`ImportImage ], ___ ]
];

$$definitelyNotGraphics = HoldPattern @ Alternatives[
    _Association,
    _CloudObject,
    _File,
    _List,
    _String,
    _URL,
    Null,
    True|False
];

$$graphicsBoxIgnoredHead = HoldPattern @ Alternatives[
    BoxData,
    Cell,
    FormBox,
    PaneBox,
    StyleBox,
    TagBox
];

$$graphicsBoxIgnoredTemplates = Alternatives[
    "Labeled",
    "Legended"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Graphics Testing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*graphicsQ*)
graphicsQ // beginDefinition;
graphicsQ[ $$graphicsPattern       ] := True;
graphicsQ[ $$definitelyNotGraphics ] := False;
graphicsQ[ RawBoxes[ boxes_ ]      ] := graphicsBoxQ @ Unevaluated @ boxes;
graphicsQ[ g_                      ] := MatchQ[ Quiet @ Show @ Unevaluated @ g, $$graphicsPattern ];
graphicsQ[ ___                     ] := False;
graphicsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*graphicsBoxQ*)
graphicsBoxQ // beginDefinition;
graphicsBoxQ[ _GraphicsBox|_Graphics3DBox ] := True;
graphicsBoxQ[ $$graphicsBoxIgnoredHead[ box_, ___ ] ] := graphicsBoxQ @ Unevaluated @ box;
graphicsBoxQ[ TemplateBox[ { box_, ___ }, $$graphicsBoxIgnoredTemplates, ___ ] ] := graphicsBoxQ @ Unevaluated @ box;
graphicsBoxQ[ RowBox[ boxes_List ] ] := AnyTrue[ boxes, graphicsBoxQ ];
graphicsBoxQ[ TemplateBox[ boxes_List, "RowDefault", ___ ] ] := AnyTrue[ boxes, graphicsBoxQ ];
graphicsBoxQ[ GridBox[ boxes_List, ___ ] ] := AnyTrue[ Flatten @ boxes, graphicsBoxQ ];
graphicsBoxQ[ StyleBox[ _, "GraphicsRawBoxes", ___ ] ] := True;
graphicsBoxQ[ ___ ] := False;
graphicsBoxQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validGraphicsQ*)
validGraphicsQ // beginDefinition;
validGraphicsQ[ g_? graphicsQ ] := getPinkBoxErrors @ Unevaluated @ g === { };
validGraphicsQ[ ___ ] := False;
validGraphicsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getPinkBoxErrors*)
getPinkBoxErrors // beginDefinition;
(* TODO: hook this up to evaluator outputs and CellToString to give feedback about pink boxes *)

getPinkBoxErrors[ { } ] :=
    { };

getPinkBoxErrors[ cells: _CellObject | { __CellObject } ] :=
    getPinkBoxErrors @ NotebookRead @ cells;

getPinkBoxErrors[ cells: _Cell | { __Cell } ] :=
    Module[ { nbo },
        UsingFrontEnd @ WithCleanup[
            nbo = NotebookPut[ Notebook @ Flatten @ { cells }, Visible -> False ],
            SelectionMove[ nbo, All, Notebook ];
            MathLink`CallFrontEnd @ FrontEnd`GetErrorsInSelectionPacket @ nbo,
            NotebookClose @ nbo
        ]
    ];

getPinkBoxErrors[ data: _TextData | _BoxData | { __BoxData } ] :=
    getPinkBoxErrors @ Cell @ data;

getPinkBoxErrors[ exprs_List ] :=
    getPinkBoxErrors[ Cell @* BoxData /@ MakeBoxes /@ Unevaluated @ exprs ];

getPinkBoxErrors[ expr_ ] :=
    getPinkBoxErrors @ { Cell @ BoxData @ MakeBoxes @ expr };

getPinkBoxErrors // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*image2DQ*)
(* Matches against the head in addition to checking ImageQ to avoid passing Image3D when a 2D image is expected: *)
image2DQ // beginDefinition;
image2DQ[ HoldPattern[ _Image? ImageQ ] ] := True;
image2DQ[ _ ] := False;
image2DQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
