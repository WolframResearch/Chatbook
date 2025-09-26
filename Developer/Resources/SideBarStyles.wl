(* ::Package:: *)

(* ::Section:: *)
(*Package Header*)


Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];


(* ::Section:: *)
(*Path setup*)


workspacePath = $darkFloatStyleSheetTarget (* 15.0+ stylesheet *)
corePath      = FileNameJoin[ { $InstallationDirectory, "SystemFiles", "FrontEnd", "StyleSheets", "Core.nb" } ]

ssName = "WorkspaceChat.nb";


prependRoot[ { path__ }, filename_ ] := FrontEnd`FileName[ { $RootDirectory, path }, filename ]


(* ::Section:: *)
(*Styles assuming current inheritance (WorkspaceChat.nb > Chatbook.nb > Default.nb > Core.nb)*)


(* Get all styles and environments from the original notebook before any changes were made: *)

env = CreateUUID[ ];

nbExpr = Get[ workspacePath ];
environments = Append[ Union @ Flatten @ Cases[ nbExpr, Cell[ sd : StyleData[ Except[ _Rule ], env_String, ___ ], ___ ] :> env, Infinity ], env ];
styles = Union[ Flatten[ Cases[ nbExpr, Cell[ sd : StyleData[ style : All | "All" | _String, ___ ], ___ ] :> style, Infinity ] ] ] /. All -> "All";

beforeTempPath = FileNameJoin[ { $TemporaryDirectory, "OLD" } ];

CreateDirectory[ beforeTempPath, CreateIntermediateDirectories -> True ];
CopyFile[ workspacePath, FileNameJoin[ { beforeTempPath, ssName } ], OverwriteTarget -> True ]

(* Calculate the options for all combinations of styles and environments: *)
WithCleanup[
    nb = CreateDocument[ { }, StyleDefinitions -> prependRoot[ FileNameSplit[ beforeTempPath ], ssName ] ];
    before = Table[ e -> Table[ s -> AbsoluteCurrentValue[ nb, { StyleDefinitions, { s, e } } ], { s, styles } ], { e, environments } ];
    ,
    NotebookClose @ nb ]


(* ::Section:: *)
(*Styles assuming only Core.nb*)


afterTempPath = FileNameJoin[ { $TemporaryDirectory, "NEW" } ];
CreateDirectory[ afterTempPath, CreateIntermediateDirectories -> True ];
CopyFile[ corePath, FileNameJoin[ { afterTempPath, ssName } ], OverwriteTarget -> True ];

(* Re-calculate the same set of styles and environments: *)
WithCleanup[
    nb = CreateDocument[ { }, StyleDefinitions -> prependRoot[ FileNameSplit[ afterTempPath ], ssName ] ];
    after = Table[ e -> Table[ s -> AbsoluteCurrentValue[ nb, { StyleDefinitions, { s, e } } ], { s, styles } ], { e, environments } ];
    ,
    NotebookClose @ nb ]


(* ::Section:: *)
(*Find style differences*)


(* Steps: *)
(* 1. Extract any cases where the previous data disagrees with the data pulled from the updated stylesheet: *)
(* 2. Remove specific styles that cannot be applied at the notebook scope in the side bar. *)

fails = Cases[ Table[ { e, s } -> Lookup[ Lookup[ before, e ], s ] === Lookup[ Lookup[ after, e ], s ], { s, styles }, { e, environments } ] // Flatten, HoldPattern[ val_ -> False ] :> val ]
fails = DeleteCases[ fails, { _, "Notebook" | "PrintTemporary" | "CellExpression" | "AttachedCell" | "DockedCell" } ];

(* 3. Only include styles that aren't included in, or are modified from, CoreExtensions.nb. Directly inherit within CoreExtensions.nb. *)
(* 4. CellFrameLabels is not supported by inline cells so use AttachCell instead *)

SideBarCoreExtensionCells[ ] :=
MapThread[
    Module[ { b, a, optionsList },
        b = Lookup[ Lookup[ before, #1 ], #2 ];
        a = Lookup[ Lookup[ after,  #1 ], #2 ];
        optionsList = DeleteCases[ SortBy[ Complement[ b, a ], First ], _[ System`MenuCommandKey | System`MenuSortingValue, _ ] ];
        Switch[ #2,
            "ChatInput",
                optionsList = Flatten @
                    Replace[ optionsList,
                        {
                            _[ CellFrameLabelMargins, _ ] :> None,
                            _[ CellFrameLabels, { { _, c_Cell }, _ } ] :> {
                                CellFrameLabels -> None,
                                Initialization :> AttachCell[ EvaluationCell[ ], c, { Right, Top }, Offset[ { 0, -5 }, 0 ], { Center, Top } ] } },
                        1],
            "ChatOutput",
                optionsList = Flatten @
                    Replace[ optionsList,
                        {
                            _[ CellFrameLabelMargins, _ ] :> None,
                            _[ CellFrameLabels, { { c_Cell, _ }, _ } ] :> {
                                CellFrameLabels -> None,
                                Initialization :> AttachCell[ EvaluationCell[ ], c, { Left, Top }, Offset[ { -5 , -5 }, 0 ], { Center, Top } ] } },
                        1],
            _, Null];
        
        Cell[
            StyleData[
                "NotebookAssistant`SideBar`" <> #2,
                If[ a === { }, Sequence @@ { }, StyleDefinitions -> StyleData[ #2 ] ] ],
            Sequence @@ optionsList ]
    ]&,
    (Transpose @ fails) ]


(* ::Section:: *)
(*Package Footer*)


End[ ];
