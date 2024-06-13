(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];
Needs[ "Wolfram`Chatbook`Serialization`"     ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Options*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SetToolOptions*)
SetToolOptions // ClearAll;

SetToolOptions[ name_String, opts: OptionsPattern[ ] ] :=
    SetToolOptions[ $FrontEnd, name, opts ];

SetToolOptions[ scope_, name_String, opts: OptionsPattern[ ] ] := UsingFrontEnd[
    KeyValueMap[
        (CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", "ToolOptions", name, ToString[ #1 ] } ] = #2) &,
        Association @ Reverse @ { opts }
    ];
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", "ToolOptions" } ]
];

SetToolOptions[ name_String, Inherited ] :=
    SetToolOptions[ $FrontEnd, name, Inherited ];

SetToolOptions[ scope_, name_String, Inherited ] := UsingFrontEnd[
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", "ToolOptions", name } ] = Inherited;
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", "ToolOptions" } ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolOptionValue*)
toolOptionValue // beginDefinition;
toolOptionValue[ name_String, key_String ] := toolOptionValue[ name, $toolOptions[ name ], key ];
toolOptionValue[ name_String, _Missing, key_String ] := toolOptionValue0[ $DefaultToolOptions[ name ], key ];
toolOptionValue[ name_String, opts_Association, key_String ] := toolOptionValue0[ opts, key ];
toolOptionValue // endDefinition;

toolOptionValue0 // beginDefinition;
toolOptionValue0[ opts_Association, key_String ] := Lookup[ opts, key, Lookup[ $DefaultToolOptions, key ] ];
toolOptionValue0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolOptions*)
toolOptions // beginDefinition;

toolOptions[ name_String ] :=
    toolOptions[ name, $toolOptions[ name ], $DefaultToolOptions[ name ] ];

toolOptions[ name_, opts_Association, defaults_Association ] :=
    toolOptions[ name, <| DeleteCases[ defaults, Inherited ], DeleteCases[ opts, Inherited ] |> ];

toolOptions[ name_, _Missing, defaults_Association ] :=
    toolOptions[ name, DeleteCases[ defaults, Inherited ] ];

toolOptions[ name_, opts_Association ] :=
    Normal[ KeyMap[ toOptionKey, opts ], Association ];

toolOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toOptionKey*)
toOptionKey // beginDefinition;
toOptionKey[ name_String ] /; StringContainsQ[ name, "`" ] := toOptionKey @ Last @ StringSplit[ name, "`" ];
toOptionKey[ name_String ] /; NameQ[ "System`" <> name ] := Symbol @ name;
toOptionKey[ symbol_Symbol ] := symbol;
toOptionKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
