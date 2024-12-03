(*
	NOTE: DO NOT MODIFY THIS FILE.

	This file is copied from the ErrorHandling paclet, and will eventually be
	removed from Chatbook.

	Any Chatbook-specific error handling functionality should go in
	another file.
*)

(* cSpell: ignore rebranding, downvalue, assertfail, applyable *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::Module:: *)

BeginPackage["Wolfram`Chatbook`ErrorUtils`"]

Needs[ "Wolfram`Chatbook`Common`" ];

(* Avoiding context aliasing due to bug 434990: *)
Needs[ "GeneralUtilities`" -> None ];

GeneralUtilities`SetUsage[CreateErrorType, "
CreateErrorType[symbol$, expansions$] registers an error tag that can be used with CreateFailure and Raise.
"]

GeneralUtilities`SetUsage[CreateFailure, "
CreateFailure[tag$] expands tag$ and returns a Failure.
CreateFailure[tag$, assoc$] expands tag$ and returns a Failure.
CreateFailure[tag$, assoc$, {formatString$, args$}] expands tag$ and returns a Failure with the specified formatted message.
CreateFailure[tag$, {formatString$, args$}] expands tag$ and returns a Failure with the specified formatted message.
Experimental: CreateFailure[tag$, formatString$, formatArgs$\[Ellipsis]]
Experimental: CreateFailure[tag$, assoc$, formatString$, formatArgs$\[Ellipsis]]
"]

GeneralUtilities`SetUsage[Raise, "
Raise[tag$, assoc$] expands tag$ and raises a Failure exception.
Raise[tag$, assoc$, {formatString$, args$}] expands tag$ and raises a Failure exception with the specified formatted message.
Raise[tag$, {formatString$, args$}] expands tag$ and raises a Failure exception with the specified formatted message.
Experimental: Raise[tag$, formatString$, formatArgs$\[Ellipsis]]
Experimental: Raise[tag$, assoc$, formatString$, formatArgs$\[Ellipsis]]
"]

GeneralUtilities`SetUsage[Handle, "
Handle[expr$, pattern$] catches any raised failure that matches pattern$.
Handle[expr$, rules$] catches any raised failure that matches one of the specified handler rules$.
Handle[spec$] represents an operator form of Handle that can be applied to an expression.
"]

GeneralUtilities`SetUsage[FailurePattern, "FailurePattern[tags$] is a pattern that matches any Failure with one or more of the specified tags$."]

(* TODO: This should be the same as ConfirmAssert? *)
GeneralUtilities`SetUsage[RaiseAssert, "
RaiseAssert[cond$] raises a Failure if cond$ is not True.
RaiseAssert[cond$, formatStr$, formatArgs$\[Ellipsis]] raises a Failure with the specified formatted string message if cond$ is not True.
"]

GeneralUtilities`SetUsage[WrapFailure, "
WrapFailure[failure$, tags$] constructs a new Failure from tags$ with a \"CausedBy\ -> failure$ field.
WrapFailure[failure$, tags$, formatString$, formatArgs$\[Ellipsis]] constructs a new Failure  from tags$ and the format string message with a \"CausedBy\" -> failure$ field.
"]

GeneralUtilities`SetUsage[WrapRaised, "
WrapRaised[tag$, formatString$, formatArgs$\[Ellipsis]][expr$] wraps any Failure's raised by the evaluation of expr$ in an outer Failure where the original error is the \"CausedBy\" field of the new error.
"]

GeneralUtilities`SetUsage[SetFallthroughError, "
SetFallthroughError[symbol] sets a \"fallthrough\" down value on symbol$ that raises an error if no other down values match.
"]

(* TODO: This should be the same as Confirm[_]? *)
GeneralUtilities`SetUsage[RaiseConfirm, "
RaiseConfirm[expr$] confirms that expr$ is not considered a failure, otherwise raising an error.
"]

(* TODO: This should be the same as ConfirmMatch[_]? *)
GeneralUtilities`SetUsage[RaiseConfirmMatch, "
RaiseConfirmMatch[expr$, form$] confirms that expr$ matches the pattern form$, otherwise raising a Failure.
"]

GeneralUtilities`SetUsage[ConfirmReplace, "
ConfirmReplace[expr$, rules$] applies a rule or list of rules in an attempt to transform the entire expression expr$, and raises an error if no rule matches.
"]

$RaiseThrowTag = $catchTopTag;

$RegisteredErrorTags = <||>

(*------------------------------------------*)
(* Experiment with Raise => Fail rebranding *)
(*------------------------------------------*)

Fail2 = Raise
FailAssert = RaiseAssert
WrapFailed = WrapRaised
FailConfirm = RaiseConfirm
FailConfirmMatch = RaiseConfirmMatch

(*====================================*)
(* Advice                             *)
(*====================================*)

RegisterAdviceListener

$AdviceListeners = <||>

Advice::usage = "Advice -- TODO"
Apprise

(*====================================*)
(* Standard Error Tags                *)
(*====================================*)

GeneralUtilities`SetUsage[AssertFailedError, "
AssertFailedError is an error tag indicating a failed RaiseAssert[..]
"]

GeneralUtilities`SetUsage[DownValueFallthroughError, "
DownValueFallthroughError is an error tag indicating that a function was called with arguments that fell through to the catch-all definition set by SetFallthroughError.
"]

GeneralUtilities`SetUsage[ConfirmError, "
ConfirmError is an error tag indicating that a *Confirm* function was called with an argument that is considered a failure.
"]

GeneralUtilities`SetUsage[ConfirmReplaceError, "
ConfirmReplaceError is an error tag indicating that ConfirmReplace was unable to transform an expression.
"]

GeneralUtilities`SetUsage[ConfirmMatchError, "
ConfirmMatchError is an error tag indicating that RaiseConfirmMatch was called with an expression and pattern that did not match.
"]

(*====================================*)
(* Utilities                          *)
(*====================================*)

TagQ

(* TODO: Make this private *)
ExpandTag

Begin["`Private`"]


SetFallthroughError[symbol_Symbol] := (
	symbol[args___] := With[ {
		failure = CreateFailure[
			DownValueFallthroughError,
			<|
				"Symbol" -> symbol,
				"ArgumentList" -> HoldComplete[{args}]
			|>,
			"Arguments applied to symbol `` did not match any DownValues.",
			HoldForm[symbol]
		]
	},
		throwInternalFailure[symbol[args], failure]
	]
)

(* TODO:
	Replace strict argument type patterns with internal validation of each
	argument, so that better errors can be returned. Also add catch-all
	downvalue cases.*)
(*========================================================*)
(* Core Functionality                                     *)
(*========================================================*)

CreateErrorType[tag_?TagQ, expansions:{___?TagQ}] := Module[{},
	If[MemberQ[$RegisteredErrorTags, tag],
		throwInternalFailure @ CreateErrorType[ tag, expansions ];
	];

	data = <|
		"Expansions" -> expansions,
		"Validator" -> None
	|>;

	AssociateTo[$RegisteredErrorTags, tag -> data];

	Success["RegisteredErrorType", data]
]

SetFallthroughError[CreateErrorType]

(*====================================*)

CreateFailure[
	tag_?TagQ,
	assoc : _?AssociationQ : <||>
] := Module[{
	failure,
	validator
},
	(*----------------------------------------------------------------------*)
	(* Construct the Failure[..] object, and included automatic properties. *)
	(*----------------------------------------------------------------------*)

	(* TODO: If a "Validator" is registered for `tag`, use it to validate this
	         Failure. *)

	(* TODO: Include a "Stacktrace" field if stacktrace capturing is enabled. *)
	failure = Failure[
		Replace[ExpandTag[tag], {one_} :> one],
		assoc
	];

	(*----------------------------------------------------*)
	(* Use the user-provided failure validation function. *)
	(*----------------------------------------------------*)

	Assert[AssociationQ[$RegisteredErrorTags]];

	validator = Part[$RegisteredErrorTags, Key[tag], "Validator"];

	If[!MissingQ[validator] && validator =!= None,
		result = validator[failure];

		If[result =!= failure,
			throwInternalFailure @ CreateFailure[ tag, assoc ];
		];
	];

	failure
]

(*------------------------------------*)

CreateFailure[
	tag_?TagQ,
	assoc0: _?AssociationQ : <||>,
	{formatStr_?StringQ, formatArgs___}
] := Module[{
	assoc
},
	(* Note:
		This will clobber any "MessageTemplate"/"MessageParameters" fields
		already in assoc0.

		TODO: Should these be an error or a warning? Or is this a feature, in
			that it's a one-step way to override an error message while
			preserving other metadata?
	*)
	assoc = Join[
		assoc0,
		<| "MessageTemplate" -> formatStr, "MessageParameters" -> {formatArgs}|>
	];

	CreateFailure[tag, assoc]
]

(*------------------------------------*)

CreateFailure[
	tag_?TagQ,
	assoc0: _?AssociationQ : <||>,
	message : PatternSequence[_?StringQ, ___]
] := CreateFailure[tag, assoc0, {message}]

SetFallthroughError[CreateFailure]

(*====================================*)

(*------------------------------------*)
(* Raise of structured data           *)
(*------------------------------------*)

Raise[tag_?TagQ, assoc_?AssociationQ] :=
	Throw[CreateFailure[tag, assoc], $RaiseThrowTag]

Raise[
	tag: _?TagQ,
	assoc: _?AssociationQ : <||>,
	message: {_?StringQ, ___}
] := Throw[CreateFailure[tag, assoc, message], $RaiseThrowTag]

Raise[
	tag_?TagQ,
	assoc: _?AssociationQ : <||>,
	message : PatternSequence[_?StringQ, ___]
] := Throw[CreateFailure[tag, assoc, message], $RaiseThrowTag]

(*------------------------------------*)

Raise[failure:Failure[_?TagQ, _?AssociationQ]] :=
	Throw[failure, $RaiseThrowTag]

(*------------------------------------*)
(* Malformed Raise calls              *)
(*------------------------------------*)

Raise[failure:Failure[_, _?AssociationQ]] :=
	Throw[failure, $RaiseThrowTag]

Raise[args___] :=
	Throw[CreateFailure["TODO:ArgumentError", <| "Arguments" -> {args} |>], $RaiseThrowTag]

SetFallthroughError[Raise]

(*====================================*)

(*
Begin["`Errors`"]

$BuiltinErrorTypes =
	"GeneralError" -> <|
		"Abort" -> <|
			"UserAbort" -> {},
			"ProgrammaticAbort" -> {TimeConstraint | MemoryConstraint}
		|>,
		"LogicError" -> <|
			"PartOutOfBounds" -> {},
			"ImproperArguments" -> {},
			"UncaughtException" -> {},
			"AssertionFailed" -> {}
		|>,
		"ResourceExhaustion" -> {}
	|>;

CreateErrorType[$BuiltinErrorTypes]

End[]
*)

(*====================================*)

Attributes[Handle] = HoldFirst

Handle[spec_] :=
	Function[
		{expr},
		Handle[expr, spec],
		HoldFirst
	]

(*------------------------------------*)

(* Handle[expr_, symbols0_?TagsQ] := Module[{
	symbols = ToTags[symbols0],
	result
},
	result = Catch[expr, $RaiseThrowTag];

	Replace[result, {
		Failure[tag_?TagQ, _] /; MemberQ[symbols, tag] :> result,
		Failure[tags_?TagsQ, _] /; IntersectingQ[symbols, tags] :> result,
		Failure[_?TagQ | _?TagsQ, _?AssociationQ] :> Raise[result]
	}]
] *)

(*------------------------------------*)

Handle[
	expr_,
	handlers0: _Rule | _RuleDelayed | {(_Rule|_RuleDelayed)...}
] := Module[{
	handlers = Replace[handlers0, rule:Except[_List] :> {rule}],
	$magicHead,
	failure,
	result
},
	result = Catch[expr, $RaiseThrowTag, $magicHead];

	failure = Replace[result, {
		$magicHead[
			failure:Failure[tags_?TagsQ, _],
			$RaiseThrowTag
		] :> failure,
		$magicHead[___] :> throwInternalFailure @ Handle[ result, handlers ],
		other_ :> Return[other, Module]
	}];

	(* If no user-provided handlers apply, re-throw the failure. *)
	handlers = Append[
		handlers,
		other_ :> Raise[failure]
	];

	(* If a user-provided handler does apply, this will return normally. *)
	Replace[failure, handlers]
]

(*------------------------------------*)

Handle[expr_, pattern_] :=
	Handle[expr, {obj:pattern :> obj}]

SetFallthroughError[Handle]

(*====================================*)

FailurePattern[tags0_?TagsQ] :=
	Failure[
		failureTags0_?TagsQ /;
			IntersectingQ[ToTags[tags0], ToTags[failureTags0]],
		_?AssociationQ
	]

(*========================================================*)
(* Convenience Functions                                  *)
(*========================================================*)

Attributes[RaiseConfirm] = {HoldFirst}

RaiseConfirm[expr_] :=
	Replace[expr, {
		f_Failure :> Raise[f],
		result:($Failed | _?MissingQ) :> Raise[
			ConfirmError,
			<| "Expression" -> result |>,
			"Confirmation failure evaluating ``: result was: ``",
			HoldForm[expr],
			result
		]
	}]

SetFallthroughError[RaiseConfirm]

(*====================================*)

ConfirmReplace[
	expr_,
	rules0 : ((Rule|RuleDelayed)[_, _] | {(Rule|RuleDelayed)[_, _]...})
] := Module[{
	rules = Replace[rules0, rule:(Rule|RuleDelayed)[_, _] :> {rule}]
},
	Replace[
		expr,
		Append[
			rules,
			result_ :> Raise[
				ConfirmReplaceError,
				<| "Expression" -> result, "Rules" -> rules |>,
				"Result of evaluating `` could not be replaced by any rule in ``: ``",
				HoldForm[expr],
				Map[
					Replace[{
						(head:(Rule|RuleDelayed))[lhs_, _] :> head[InputForm[lhs], "\[Ellipsis]"],
						(* TODO: Throw a LogicError-like thing here? *)
						other_ :> throwInternalFailure @ ConfirmReplace[ expr, rules0 ]
					}],
					rules
				],
				result
			]
		]
	]
]

SetFallthroughError[ConfirmReplace]

(*====================================*)

Attributes[RaiseAssert] = {HoldFirst}

RaiseAssert::assertfail = "``"

RaiseAssert[
	cond_,
	assoc : _?AssociationQ : <||>,
	formatStr_?StringQ,
	formatArgs___
] :=
	If[!TrueQ[cond],
		Message[
			RaiseAssert::assertfail,
			(* Note: Use '@@' to avoid behavior described in bug #240412. *)
			"RaiseAssert[..] failed: " <> ToString[StringForm @@ {formatStr, formatArgs}]
		];

		Raise @ Failure[AssertFailedError, Join[
			<|
				"MessageTemplate" -> "RaiseAssert[..] failed: " <> formatStr,
				"MessageParameters" -> {formatArgs},
				"AssertConditionExpression" -> HoldForm[cond]
			|>,
			assoc
		]]
	]

RaiseAssert[cond_] :=
	If[!TrueQ[cond],
		Message[
			RaiseAssert::assertfail,
			"RaiseAssert[..] condition was not True: " <> ToString[HoldForm @ InputForm @ cond]
		];

		Raise @ Failure[AssertFailedError, <|
			"MessageTemplate" -> "RaiseAssert[..] condition was not True: ``",
			"MessageParameters" -> {HoldForm @ InputForm @ cond},
			"AssertConditionExpression" -> HoldForm[cond]
		|>]
	]

SetFallthroughError[RaiseAssert]

(*====================================*)

Attributes[RaiseConfirmMatch] = {HoldFirst}

RaiseConfirmMatch[expr_, pattern_] := With[{
	(* Evaluate `expr` argument, which is HoldFirst. *)
	result = expr
},
	If[!TrueQ[MatchQ[result, pattern]],
		Raise[
			ConfirmMatchError,
			<| "Expression" :> result, "Pattern" -> pattern |>,
			"Result of evaluating `` did not match ``: ``",
			HoldForm[expr],
			pattern,
			HoldForm[result]
		]
	];

	result
]

SetFallthroughError[RaiseConfirmMatch]

(*====================================*)

WrapFailure[
	failure_Failure,
	tags_?TagsQ,
	message : PatternSequence[_?StringQ, ___] : Automatic
] :=
	CreateFailure[
		tags,
		<| "CausedBy" -> failure |>,
		passOptionalFormatSequence[message]
	]

SetFallthroughError[WrapFailure]

(*====================================*)

(* TODO?:
	WrapRaised that only adds context to raised Failure's that match a
	particular pattern?

	WrapRaised[failurePatt_, tags_?TagsQ, {formatStr_?StringQ, args___}]
*)

WrapRaised[
	tag_?TagQ,
	message : PatternSequence[_?StringQ, ___] : Automatic
] :=
	Handle[{
		err_Failure :> (
			Raise @ WrapFailure[
				err,
				tag,
				passOptionalFormatSequence[message]
			]
		)
	}]

SetFallthroughError[WrapRaised]

(*========================================================*)
(* Advice                                                 *)
(*========================================================*)

(advice:Advice[
	tags: _?TagsQ,
	data: _?AssociationQ
])[key_?StringQ] :=
	Lookup[data, key, Missing["AdviceKeyAbsent", {advice, key}]]

(*========================================================*)

(*
	Association of:

		<| {__?TagQ} -> {applyable_ ...} |>
*)
$AdviceListeners = <||>

Apprise[advice: Advice[adviceTags0: _?TagsQ, meta: _?AssociationQ]] := Module[{
	adviceTags = Replace[adviceTags0, tag_?TagQ :> {tag}]
},
	Scan[
		{rule} |-> Module[{
			listenerTags = rule[[1]],
			listenerFunctions = rule[[2]]
		},
			Assert[MatchQ[listenerTags], {___?TagQ}];

			If[IntersectingQ[listenerTags, adviceTags],
				Scan[#[advice]&, listenerFunctions]
			]
		],
		Normal[$AdviceListeners]
	]
]

RegisterAdviceListener[tags0: _?TagsQ, listenerFunction: _] := Module[{
	tags = Replace[tags0, tag_?TagQ :> {tag}]
},
	$AdviceListeners[tags] = Append[
		Lookup[$AdviceListeners, Key[tags], {}],
		listenerFunction
	];
]

(*========================================================*)
(* Helpers                                                *)
(*========================================================*)

ExpandTag[tag0_?TagQ] := Module[{
	expansions
},
	If[!KeyMemberQ[$RegisteredErrorTags, tag0],
		throwInternalFailure @ ExpandTag @ tag0;
	];

	expansions = Flatten @ FixedPointList[
		tags |-> (
			Flatten @ Map[
				entry |-> Lookup[entry, "Expansions"],
				Lookup[$RegisteredErrorTags, tags]
			]
		),
		(* Start with tag0 *)
		{tag0},
		(* FIXME: Better limiting behavior. *)
		5
	];

	Assert[MatchQ[expansions, {___?TagQ}]];

	expansions
]

(*------------------------------------*)
(* Tag Checking                       *)
(*------------------------------------*)

TagQ[expr_] := StringQ[expr] || MatchQ[expr, _Symbol?AtomQ]

TagsQ[expr_] := MatchQ[expr, _?TagQ | {___?TagQ}]

ToTags[tag_?TagQ] := {tag}
ToTags[list_?ListQ] := list

(*------------------------------------*)

Attributes[passOptionalFormatSequence] := {SequenceHold}

passOptionalFormatSequence[Automatic] := Sequence[]
passOptionalFormatSequence[args___] := args

(*========================================================*)
(* Standard Error Hierarchy                               *)
(*========================================================*)

(* NOTE:
	This section has to come at the end because we want all the
	functions above to be defined before we try running this initialization
	code. *)

CreateErrorType[AssertFailedError, {}]
CreateErrorType[DownValueFallthroughError, {}]
(* Generated by RaiseConfirm *)
CreateErrorType[ConfirmError, {}]
(* Generated by ConfirmReplace *)
CreateErrorType[ConfirmReplaceError, {}]
(* Generated by ConfirmMatch *)
CreateErrorType[ConfirmMatchError, {}]


End[]

EndPackage[]

(* :!CodeAnalysis::EndBlock:: *)