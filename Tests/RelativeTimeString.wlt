(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $hour = 3600;
    $day  = 86400;

    (* Each row is { now, time, expected }, where now is a date list in the local time zone and time is either a local
       date list or an offset in seconds from now. The expected values are the results of version 1.0.0 of
       ResourceFunction[ "RelativeTimeString" ] with Now set to now. For "this morning", that is only the case on the
       day that the resource function first computes its (cached) "this morning" interval. *)
    relativeTimeMismatches[ rows_List ] := Cases[
        rows,
        { now_, time_, expected_ } :> With[
            { actual = Wolfram`Chatbook`Common`relativeTimeString[ toAbsoluteTime[ now, time ], AbsoluteTime @ now ] },
            { now, time, expected, actual } /; actual =!= expected
        ]
    ];

    toAbsoluteTime[ now_, time_List ] := AbsoluteTime @ time;
    toAbsoluteTime[ now_, offset_ ] := AbsoluteTime @ now + offset,

    Null,
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Durations*)
VerificationTest[
    relativeTimeMismatches @ {
        { { 2026, 10, 28, 13, 30, 12.345 }, 0, "now" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -0.0004, "just now" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 0.0004, "now" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -0.9994, "just now" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -0.9996, "a second ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 0.9996, "in a second" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -1, "a second ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -10, "10 seconds ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -44, "44 seconds ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -45, "45 seconds ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -59.4, "59 seconds ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -60, "a minute ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -61, "a minute ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -89, "a minute ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -90, "2 minutes ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -150, "2 minutes ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -3569, "59 minutes ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -3570, "an hour ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -3599, "an hour ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -$hour, "an hour ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -5400, "2 hours ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -7 * $hour, "7 hours ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -28799, "8 hours ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -1209601, "14 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -15 * $day, "15 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -20 * $day, "20 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -29 * $day, "29 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -30 * $day, "30 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -31 * $day, "a month ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -45 * $day, "a month ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -60 * $day, "2 months ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -70 * $day, "2 months ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -200 * $day, "7 months ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -364 * $day, "a year ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -365 * $day, "a year ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -400 * $day, "a year ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -800 * $day, "2 years ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -3650 * $day, "10 years ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 1, "in a second" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 10, "in 10 seconds" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 61, "in a minute" },
        { { 2026, 10, 28, 13, 30, 12.345 }, $hour, "in an hour" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 5400, "in 2 hours" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 7 * $hour, "in 7 hours" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 15 * $day, "in 15 days" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 40 * $day, "in a month" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 400 * $day, "in a year" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 800 * $day, "in 2 years" }
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-Durations"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Named Days*)
VerificationTest[
    (* Wednesday afternoon: *)
    relativeTimeMismatches @ {
        { { 2026, 10, 28, 13, 30, 12.345 }, -8 * $hour, "8 hours ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -10 * $hour, "10 hours ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -16 * $hour, "last night" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -20 * $hour, "yesterday" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -23 * $hour, "yesterday" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -$day, "yesterday" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -30 * $hour, "yesterday" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -36 * $hour, "yesterday" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -47 * $hour, "2 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -2 * $day, "2 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -3 * $day, "3 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -4 * $day, "4 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -5 * $day, "last week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -6 * $day, "last week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -7 * $day, "last week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -10 * $day, "last week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -13 * $day, "13 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, -14 * $day, "14 days ago" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 8 * $hour, "in 8 hours" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 12 * $hour, "tomorrow" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 20 * $hour, "tomorrow morning" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 30 * $hour, "tomorrow" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 36 * $hour, "in 2 days" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 47 * $hour, "in 2 days" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 3 * $day, "in 3 days" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 4 * $day, "next week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 5 * $day, "next week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 6 * $day, "next week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 7 * $day, "next week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 10 * $day, "next week" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 13 * $day, "in 13 days" },
        { { 2026, 10, 28, 13, 30, 12.345 }, 14 * $day, "in 14 days" }
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-NamedDays-Weekday"
]

VerificationTest[
    (* Saturday evening: *)
    relativeTimeMismatches @ {
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 31, 3, 59, 59.999 }, "18 hours ago" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 31, 4, 0, 0 }, "this morning" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 31, 11, 59, 59.999 }, "this morning" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 31, 12, 0, 0 }, "10 hours ago" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 31, 13, 29, 59.999 }, "8 hours ago" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 30, 19, 59, 59.999 }, "yesterday" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 30, 20, 0, 0 }, "last night" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 30, 23, 59, 59.999 }, "last night" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 31, 0, 0, 0 }, "22 hours ago" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 30, 0, 0, 0 }, "yesterday" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 29, 23, 59, 59.999 }, "2 days ago" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 25, 0, 0, 0 }, "a week ago" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 24, 23, 59, 59.999 }, "last week" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 18, 0, 0, 0 }, "last week" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 17, 23, 59, 59.999 }, "14 days ago" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 1, 5, 29, 59.999 }, "in 8 hours" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 1, 5, 30, 0 }, "tomorrow morning" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 1, 15, 59, 59.999 }, "tomorrow morning" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 1, 16, 0, 0 }, "tomorrow" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 1, 23, 59, 59.999 }, "tomorrow" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 2, 0, 0, 0 }, "in a day" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 4, 21, 29, 59.999 }, "in 4 days" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 4, 21, 30, 0 }, "next week" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 7, 23, 59, 59.999 }, "next week" },
        { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 8, 0, 0, 0 }, "in a week" }
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-NamedDays-Evening"
]

VerificationTest[
    (* Sunday morning, so there's no "this morning" or "last night" yet, and "last week" ends today: *)
    relativeTimeMismatches @ {
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 25, 1, 59, 59.999 }, "8 hours ago" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 25, 2, 0, 0 }, "8 hours ago" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 24, 20, 0, 0 }, "last night" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 24, 12, 0, 0 }, "yesterday" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 24, 0, 0, 0 }, "yesterday" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 23, 23, 59, 59.999 }, "a day ago" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 21, 10, 0, 0 }, "4 days ago" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 21, 10, 0, 0.001 }, "4 days ago" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 18, 0, 0, 0 }, "last week" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 17, 23, 59, 59.999 }, "a week ago" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 11, 10, 0, 0 }, "14 days ago" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 25, 18, 0, 0 }, "in 8 hours" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 25, 22, 0, 0 }, "in 12 hours" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 26, 0, 0, 0 }, "tomorrow" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 26, 4, 0, 0 }, "tomorrow morning" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 26, 23, 59, 59.999 }, "tomorrow" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 27, 0, 0, 0 }, "in 2 days" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 29, 9, 59, 59.999 }, "in 4 days" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 10, 29, 10, 0, 0 }, "next week" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 11, 1, 0, 0, 0 }, "in a week" },
        { { 2026, 10, 25, 10, 0, 0 }, { 2026, 11, 7, 10, 0, 0 }, "in 13 days" }
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-NamedDays-SundayMorning"
]

VerificationTest[
    (* Just after midnight at the start of a month: *)
    relativeTimeMismatches @ {
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 31, 16, 29, 59.999 }, "yesterday" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 31, 16, 30, 0 }, "8 hours ago" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 31, 4, 0, 0 }, "yesterday" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 31, 0, 0, 0 }, "yesterday" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 30, 23, 59, 59.999 }, "a day ago" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 28, 0, 30, 0 }, "4 days ago" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 25, 0, 0, 0 }, "last week" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 24, 23, 59, 59.999 }, "a week ago" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 10, 18, 0, 30, 0 }, "14 days ago" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 11, 1, 8, 30, 0 }, "in 8 hours" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 11, 1, 12, 30, 0 }, "in 12 hours" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 11, 2, 0, 0, 0 }, "tomorrow" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 11, 2, 4, 0, 0 }, "tomorrow morning" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 11, 2, 16, 0, 0 }, "tomorrow" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 11, 3, 0, 0, 0 }, "in 2 days" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 11, 5, 0, 30, 0 }, "next week" },
        { { 2026, 11, 1, 0, 30, 0 }, { 2026, 11, 8, 0, 0, 0 }, "in a week" }
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-NamedDays-Midnight"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Time Zones*)
VerificationTest[
    (* Date lists and absolute times are both in $TimeZone, so the results do not depend on it: *)
    Table[
        Block[ { $TimeZone = tz },
            relativeTimeMismatches @ {
                { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 31, 4, 0, 0 }, "this morning" },
                { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 30, 20, 0, 0 }, "last night" },
                { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 30, 0, 0, 0 }, "yesterday" },
                { { 2026, 10, 31, 21, 30, 0 }, { 2026, 10, 24, 23, 59, 59.999 }, "last week" },
                { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 1, 5, 30, 0 }, "tomorrow morning" },
                { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 1, 16, 0, 0 }, "tomorrow" },
                { { 2026, 10, 31, 21, 30, 0 }, { 2026, 11, 4, 21, 30, 0 }, "next week" },
                { { 2026, 10, 31, 21, 30, 0 }, -40 * $day, "a month ago" }
            }
        ],
        { tz, { 0, 5.5, -11, 13, "America/New_York" } }
    ],
    { { }, { }, { }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-TimeZones"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DateObjects*)
VerificationTest[
    (* Saved chat dates, as used in the history view: *)
    With[ { now = AbsoluteTime[ TimeZone -> 0 ] },
        Wolfram`Chatbook`Common`relativeTimeString @ DateObject[ now - #, TimeZone -> 0 ] & /@ {
            61,
            2 * $hour,
            20 * $day,
            40 * $day,
            400 * $day
        }
    ],
    { "a minute ago", "2 hours ago", "20 days ago", "a month ago", "a year ago" },
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-DateObject-UTC"
]

VerificationTest[
    (* Front end timestamps, as used in notebook information: *)
    With[ { now = AbsoluteTime[ TimeZone -> 0 ] },
        Wolfram`Chatbook`Common`relativeTimeString @ TimeZoneConvert @ DateObject[ now - #, TimeZone -> 0 ] & /@ {
            61,
            2 * $hour,
            20 * $day,
            40 * $day,
            400 * $day
        }
    ],
    { "a minute ago", "2 hours ago", "20 days ago", "a month ago", "a year ago" },
    SameTest -> MatchQ,
    TestID   -> "RelativeTimeString-DateObject-LocalTimeZone"
]

(* :!CodeAnalysis::EndBlock:: *)
