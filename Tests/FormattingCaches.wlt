(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingCaches.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingCaches.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::VariableError::Block:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* The formatter's caches live for the whole session, so each one is bounded (see addToCache in
   Formatting/Formatting.wl). cacheBehavior gives a cache room for 4 entries, calls f on each input and gives the number
   of entries after each call. When a cache is full, its oldest half is discarded, so 10 new keys give the lengths in
   $cacheBehavior. It then replaces the stored values with "Cached" and calls f on the last input again, which must
   give "Cached", so that f looks up the key that it stores: *)
VerificationTest[
    cacheBehavior // Attributes = { HoldFirst };
    cacheBehavior[ { cache_Symbol, size_Symbol }, f_, inputs_List ] :=
        Block[ { cache = <| |>, size = 4 },
            {
                Table[ f @ input; Length @ cache, { input, inputs } ],
                cache = "Cached" & /@ cache; f @ Last @ inputs
            }
        ];
    $cacheBehavior = { { 1, 2, 3, 4, 3, 4, 3, 4, 3, 4 }, "Cached" },
    { { 1, 2, 3, 4, 3, 4, 3, 4, 3, 4 }, "Cached" },
    SameTest -> MatchQ,
    TestID   -> "Caches-Definitions@@Tests/FormattingCaches.wlt:31,1-44,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*addToCache*)

(* A full cache keeps its newest half before the new entry is added: *)
VerificationTest[
    Module[ { cache = <| |>, values },
        values = Table[
            Wolfram`Chatbook`Formatting`Private`addToCache[ cache, 4, key, ToUpperCase @ key ],
            { key, { "a", "b", "c", "d", "e" } }
        ];
        { values, cache }
    ],
    { { "A", "B", "C", "D", "E" }, <| "c" -> "C", "d" -> "D", "e" -> "E" |> },
    SameTest -> MatchQ,
    TestID   -> "Caches-AddToCache@@Tests/FormattingCaches.wlt:51,1-62,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bounded Caches*)
VerificationTest[
    cacheBehavior[
        {
            Wolfram`Chatbook`Formatting`Private`$htmlEntityCache,
            Wolfram`Chatbook`Formatting`Private`$maxHTMLEntityCacheSize
        },
        Wolfram`Chatbook`Formatting`Private`importHTMLEntity,
        Table[ "&e" <> ToString @ i <> ";", { i, 10 } ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-HTMLEntity@@Tests/FormattingCaches.wlt:67,1-79,2"
]

VerificationTest[
    cacheBehavior[
        {
            Wolfram`Chatbook`Formatting`Private`$correctedCodeCache,
            Wolfram`Chatbook`Formatting`Private`$maxCorrectedCodeCacheSize
        },
        Wolfram`Chatbook`Formatting`Private`autoCorrectWLCodeBlock,
        Table[ "x + " <> ToString @ i, { i, 10 } ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-CorrectedCode@@Tests/FormattingCaches.wlt:81,1-93,2"
]

VerificationTest[
    cacheBehavior[
        {
            Wolfram`Chatbook`Formatting`Private`$externalLanguageCache,
            Wolfram`Chatbook`Formatting`Private`$maxExternalLanguageCacheSize
        },
        Wolfram`Chatbook`Formatting`Private`externalLanguageQ,
        Table[ "lang" <> ToString @ i, { i, 10 } ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-ExternalLanguage@@Tests/FormattingCaches.wlt:95,1-107,2"
]

(* A failed import is checked for a cloud URL, which needs a $CloudBase: *)
VerificationTest[
    Block[ { $CloudBase = "https://www.wolframcloud.com/" },
        cacheBehavior[
            {
                Wolfram`Chatbook`Formatting`Private`$importedImageCache,
                Wolfram`Chatbook`Formatting`Private`$maxImportedImageCacheSize
            },
            Wolfram`Chatbook`Formatting`Private`importImage,
            Table[ FileNameJoin @ { $TemporaryDirectory, "missing-image-" <> ToString @ i <> ".png" }, { i, 10 } ]
        ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-ImportedImage@@Tests/FormattingCaches.wlt:110,1-124,2"
]

VerificationTest[
    cacheBehavior[
        {
            Wolfram`Chatbook`Formatting`Private`$resizedImageCache,
            Wolfram`Chatbook`Formatting`Private`$maxResizedImageCacheSize
        },
        Wolfram`Chatbook`Formatting`Private`resizeImage,
        Table[ Image @ { { i / 10 } }, { i, 10 } ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-ResizedImage@@Tests/FormattingCaches.wlt:126,1-138,2"
]

VerificationTest[
    cacheBehavior[
        { Wolfram`Chatbook`Formatting`Private`$boxCache, Wolfram`Chatbook`Formatting`Private`$maxBoxCacheSize },
        CachedBoxes,
        Table[ { i }, { i, 10 } ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-BoxCache@@Tests/FormattingCaches.wlt:140,1-149,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Formatting`Private`$boxQueueCache =
                AssociationMap[ RowBox @ { ToString @ # } &, Range[ 10 ] ]
        },
        cacheBehavior[
            {
                Wolfram`Chatbook`Formatting`Private`$base64Cache,
                Wolfram`Chatbook`Formatting`Private`$maxBase64CacheSize
            },
            Wolfram`Chatbook`Formatting`Private`getBase64,
            Range[ 10 ]
        ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-Base64@@Tests/FormattingCaches.wlt:151,1-169,2"
]

VerificationTest[
    cacheBehavior[
        {
            Wolfram`Chatbook`Formatting`Private`$decodedBase64Cache,
            Wolfram`Chatbook`Formatting`Private`$maxDecodedBase64CacheSize
        },
        DisplayBase64Boxes,
        Table[ BaseEncode @ BinarySerialize @ RawBoxes @ RowBox @ { ToString @ i }, { i, 10 } ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-DecodedBase64@@Tests/FormattingCaches.wlt:171,1-183,2"
]

VerificationTest[
    cacheBehavior[
        {
            Wolfram`Chatbook`Formatting`Private`$entityBoxesCache,
            Wolfram`Chatbook`Formatting`Private`$maxEntityBoxesCacheSize
        },
        Wolfram`Chatbook`Formatting`Private`formatEntityBoxes,
        Table[ RowBox @ { "List", "[", ToString @ i, "]" }, { i, 10 } ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-EntityBoxes@@Tests/FormattingCaches.wlt:185,1-197,2"
]

VerificationTest[
    cacheBehavior[
        {
            Wolfram`Chatbook`Formatting`Private`$inlineTemplateBoxesCache,
            Wolfram`Chatbook`Formatting`Private`$maxInlineTemplateBoxesCacheSize
        },
        Wolfram`Chatbook`Formatting`Private`checkTemplateBoxes[ #, True ] &,
        Table[ RowBox @ { ToString @ i }, { i, 10 } ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-InlineTemplateBoxes@@Tests/FormattingCaches.wlt:199,1-211,2"
]

(* WolframAlpha is replaced here, so that the test doesn't need the internet: *)
VerificationTest[
    Block[ { WolframAlpha = RowBox @ { ## } & },
        cacheBehavior[
            {
                Wolfram`Chatbook`Formatting`Private`$freeformBoxesCache,
                Wolfram`Chatbook`Formatting`Private`$maxFreeformBoxesCacheSize
            },
            Wolfram`Chatbook`Formatting`Private`formatNLInputSlow,
            Table[ "\"query " <> ToString @ i <> "\"", { i, 10 } ]
        ]
    ],
    $cacheBehavior,
    SameTest -> MatchQ,
    TestID   -> "Caches-FreeformBoxes@@Tests/FormattingCaches.wlt:214,1-228,2"
]

(* :!CodeAnalysis::EndBlock:: *)
