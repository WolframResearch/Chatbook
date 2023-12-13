(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Dynamics`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`trackedDynamic;
`trackedDynamicWrapper;
`updateDynamics;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$dynamicTriggers = <|
    "ChatBlock"   :> $chatBlockTrigger,
    "Models"      :> $modelsTrigger,
    "Personas"    :> $personasTrigger,
    "Preferences" :> $preferencesTrigger,
    "Services"    :> $servicesTrigger,
    "Tools"       :> $toolsTrigger
|>;

Cases[ $dynamicTriggers, sym_Symbol :> (sym = 0) ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tracked Dynamics*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*trackedDynamic*)
trackedDynamic // beginDefinition;
trackedDynamic // Attributes = { HoldFirst };

trackedDynamic[ expr_, name_String, opts___ ] :=
    trackedDynamic[ expr, { name }, opts ];

trackedDynamic[ expr_, names: { __String }, opts___ ] :=
    trackedDynamic[ expr, extractTriggers @ names, opts ];

trackedDynamic[ Dynamic[ expr_, opts1___ ], names_, opts2___ ] :=
    trackedDynamic[ expr, names, opts1, opts2 ];

trackedDynamic[ expr_, triggers: HoldComplete[ __Symbol ], opts: OptionsPattern[ ] ] := Enclose[
    Module[ { tracked, combined, options },

        tracked  = ConfirmMatch[
            Replace[
                OptionValue[ Dynamic, { opts }, TrackedSymbols, HoldComplete ],
                HoldComplete[ All ] -> HoldComplete @ { }
            ],
            HoldComplete @ { ___Symbol },
            "TrackedSymbols"
        ];

        combined = ConfirmMatch[
            makeTrackList[ triggers, tracked ],
            HoldComplete[ __Symbol ],
            "Combined"
        ];

        options = Sequence @@ DeleteCases[ Flatten @ { opts }, TrackedSymbols :> _ ];

        buildDynamic[ expr, combined, options ]
    ],
    throwInternalFailure[ trackedDynamic[ expr, triggers, opts ], ## ] &
];

trackedDynamic // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*trackedDynamicWrapper*)
trackedDynamicWrapper // beginDefinition;
trackedDynamicWrapper // Attributes = { HoldRest };
trackedDynamicWrapper[ display_, args___ ] := trackedDynamicWrapper0[ display, trackedDynamic @ args ];
trackedDynamicWrapper // endDefinition;

trackedDynamicWrapper0 // beginDefinition;
trackedDynamicWrapper0[ display_, Dynamic[ expr_, opts___ ] ] := DynamicWrapper[ display, expr, opts ];
trackedDynamicWrapper0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractTriggers*)
extractTriggers // beginDefinition;

extractTriggers[ names: { __String } ] /; ContainsAll[ Keys @ $dynamicTriggers, names ] :=
    extractTriggers[ names, Extract[ $dynamicTriggers, List /@ Key /@ names, HoldComplete ] ];

extractTriggers[ names_, { held__HoldComplete } ] :=
    Flatten @ HoldComplete @ held;

extractTriggers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeTrackList*)
makeTrackList // beginDefinition;
makeTrackList[ HoldComplete[ a___ ], HoldComplete[ { b___ } ] ] := DeleteDuplicates @ HoldComplete[ a, b ];
makeTrackList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buildDynamic*)
buildDynamic // beginDefinition;
buildDynamic // Attributes = { HoldFirst };

buildDynamic[ expr_, HoldComplete[ s__Symbol ], opts___ ] :=
    Dynamic[ Catch[ s; expr, _ ], TrackedSymbols :> { s }, opts ];

buildDynamic // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*updateDynamics*)
updateDynamics // beginDefinition;

updateDynamics[ ] :=
    updateDynamics @ All;

updateDynamics[ All ] :=
    Cases[ $dynamicTriggers, s_Symbol :> If[ IntegerQ @ s, s++, s = 1 ] ];

updateDynamics[ name_String ] /; KeyExistsQ[ $dynamicTriggers, name ] :=
    updateDynamics[ name, Extract[ $dynamicTriggers, Key @ name, HoldComplete ] ];

updateDynamics[ name_String, HoldComplete[ s_Symbol ] ] :=
    s = If[ IntegerQ @ s, s + 1, 1 ];

updateDynamics[ names_List ] :=
    updateDynamics /@ names;

updateDynamics // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
