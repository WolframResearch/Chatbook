(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Skills.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Skills.wlt:11,1-16,2"
]

VerificationTest[
    Context @ $DefaultSkills,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "DefaultSkillsContext@@Tests/Skills.wlt:18,1-23,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Test Definitions*)
VerificationTest[
    writeTestFile // ClearAll;

    writeTestFile[ file_String, bytes_ByteArray ] := (
        Quiet @ CreateDirectory[ DirectoryName @ file, CreateIntermediateDirectories -> True ];
        WithCleanup[ stream = OpenWrite[ file, BinaryFormat -> True ], BinaryWrite[ stream, bytes ], Close @ stream ];
        file
    );

    writeTestFile[ file_String, text_String ] := writeTestFile[ file, StringToByteArray[ text, "UTF-8" ] ];

    $tempRoot = CreateDirectory[ ];

    (* A skill using CRLF line endings, a byte order mark, and a multi-line description: *)
    $sampleSkillDir = FileNameJoin @ { $tempRoot, "sample-skill" };
    writeTestFile[
        FileNameJoin @ { $sampleSkillDir, "SKILL.md" },
        StringJoin[
            "\:feff---\r\n",
            "name: sample-skill\r\n",
            "description: >\r\n",
            "  A sample skill\r\n",
            "  for testing.\r\n",
            "license: MIT\r\n",
            "---\r\n",
            "\r\n",
            "# Sample Skill\r\n",
            "\r\n",
            "Read references/guide.md for details.\r\n"
        ]
    ];

    writeTestFile[ FileNameJoin @ { $sampleSkillDir, "references", "guide.md" }, "# Guide\n\nThe guide code is 12345.\n" ];
    writeTestFile[ FileNameJoin @ { $sampleSkillDir, "scripts", "run.wl" }, "Print[ \"hello\" ]\n" ];
    writeTestFile[ FileNameJoin @ { $sampleSkillDir, "data.bin" }, ByteArray @ { 0, 1, 2, 3, 0, 255 } ];
    writeTestFile[ FileNameJoin @ { $sampleSkillDir, ".env" }, "SECRET=1\n" ];
    writeTestFile[ FileNameJoin @ { $sampleSkillDir, ".hidden", "secret.txt" }, "secret\n" ];
    writeTestFile[ FileNameJoin @ { $sampleSkillDir, "__pycache__", "cached.pyc" }, "cached\n" ];

    (* A skill without a name in its frontmatter: *)
    $unnamedSkillDir = FileNameJoin @ { $tempRoot, "unnamed-skill" };
    writeTestFile[ FileNameJoin @ { $unnamedSkillDir, "SKILL.md" }, "---\ndescription: No name here.\n---\nBody\n" ];

    (* A skill without a description: *)
    $noDescriptionSkillDir = FileNameJoin @ { $tempRoot, "no-description" };
    writeTestFile[ FileNameJoin @ { $noDescriptionSkillDir, "SKILL.md" }, "---\nname: no-description\n---\nBody\n" ];

    DirectoryQ @ $sampleSkillDir,
    True,
    SameTest -> SameQ,
    TestID   -> "TestDefinitions@@Tests/Skills.wlt:31,1-82,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Built-in Skills*)
VerificationTest[
    $skillsAssetDirectory = PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "Skills" ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "BuiltInSkills-AssetLocation@@Tests/Skills.wlt:87,1-92,2"
]

VerificationTest[
    AssociationQ @ $DefaultSkills && AllTrue[ $DefaultSkills, MatchQ @ HoldPattern @ LLMSkill[ _Association, ___ ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "BuiltInSkills-DefaultSkills@@Tests/Skills.wlt:94,1-99,2"
]

(* Every skill directory in Assets/Skills should load successfully: *)
VerificationTest[
    Sort @ Keys @ $DefaultSkills,
    Sort[ FileNameTake /@ FileNames[ All, $skillsAssetDirectory ] ],
    SameTest -> SameQ,
    TestID   -> "BuiltInSkills-AllSkillsLoad@@Tests/Skills.wlt:102,1-107,2"
]

VerificationTest[
    $testSkill = $DefaultSkills[ "test-skill" ],
    HoldPattern @ LLMSkill[
        KeyValuePattern @ {
            "Name"        -> "test-skill",
            "Description" -> _String? (StringContainsQ[ "test skills" ]),
            "Location"    -> File[ _String? DirectoryQ ],
            "Body"        -> _String? (StringContainsQ[ #, "MAROON-ORCHID-7214" ] && StringFreeQ[ #, "---" ] &)
        },
        ___
    ],
    SameTest -> MatchQ,
    TestID   -> "BuiltInSkills-TestSkill@@Tests/Skills.wlt:109,1-122,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`skillDirectory @ $testSkill,
    FileNameJoin @ { $skillsAssetDirectory, "test-skill" },
    SameTest -> SameQ,
    TestID   -> "BuiltInSkills-TestSkill-Directory@@Tests/Skills.wlt:124,1-129,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parsing*)
VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[
        "---\nname: my-skill\ndescription: Does things.\n---\n\n# Body\n\nText\n"
    ],
    <|
        "Frontmatter" -> <| "name" -> "my-skill", "description" -> "Does things." |>,
        "Body"        -> "# Body\n\nText"
    |>,
    SameTest -> SameQ,
    TestID   -> "ParseSkillMarkdown-Basic@@Tests/Skills.wlt:134,1-144,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[
        "\:feff---\r\nname: my-skill\r\ndescription: Does things.\r\n---\r\nLine 1\r\nLine 2\r\n"
    ],
    <|
        "Frontmatter" -> <| "name" -> "my-skill", "description" -> "Does things." |>,
        "Body"        -> "Line 1\nLine 2"
    |>,
    SameTest -> SameQ,
    TestID   -> "ParseSkillMarkdown-LineEndings@@Tests/Skills.wlt:146,1-156,2"
]

(* Unquoted colons in values are invalid YAML, but are common in skills written for other clients: *)
VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[
        "---\nname: pdf-skill\ndescription: Use this skill when: the user asks about PDFs\n---\nBody"
    ][ "Frontmatter" ],
    <| "name" -> "pdf-skill", "description" -> "Use this skill when: the user asks about PDFs" |>,
    SameTest -> SameQ,
    TestID   -> "ParseSkillMarkdown-UnquotedColon@@Tests/Skills.wlt:159,1-166,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[
        "---\nname: my-skill\ndescription: \"Quoted: with a colon\"\nallowed-tools: Bash(git:*) Read\n---\n"
    ],
    <|
        "Frontmatter" -> <|
            "name"          -> "my-skill",
            "description"   -> "Quoted: with a colon",
            "allowed-tools" -> "Bash(git:*) Read"
        |>,
        "Body" -> ""
    |>,
    SameTest -> SameQ,
    TestID   -> "ParseSkillMarkdown-QuotedColon@@Tests/Skills.wlt:168,1-182,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[ "# No frontmatter\n\nJust markdown." ],
    Failure[ "InvalidSkill", KeyValuePattern[ "MessageParameters" -> { _String? (StringContainsQ[ "---" ]) } ] ],
    SameTest -> MatchQ,
    TestID   -> "ParseSkillMarkdown-MissingFrontmatter@@Tests/Skills.wlt:184,1-189,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[ "---\nname: my-skill\ndescription: Unclosed.\n" ],
    Failure[ "InvalidSkill", _ ],
    SameTest -> MatchQ,
    TestID   -> "ParseSkillMarkdown-UnclosedFrontmatter@@Tests/Skills.wlt:191,1-196,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[ "---\nname: [unclosed\n---\nBody", "SKILL.md" ],
    Failure[ "InvalidSkill", KeyValuePattern[ "MessageParameters" -> { "SKILL.md", _String } ] ],
    SameTest -> MatchQ,
    TestID   -> "ParseSkillMarkdown-InvalidYAML@@Tests/Skills.wlt:198,1-203,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Loading Skills*)
VerificationTest[
    $sampleSkill = Wolfram`Chatbook`Skills`Private`importSkill @ $sampleSkillDir,
    HoldPattern @ LLMSkill[
        KeyValuePattern @ {
            "Name"        -> "sample-skill",
            "Description" -> "A sample skill for testing.",
            "Location"    -> File[ dir_ /; dir === $sampleSkillDir ],
            "Body"        -> "# Sample Skill\n\nRead references/guide.md for details.",
            "License"     -> "MIT"
        },
        ___
    ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-Directory@@Tests/Skills.wlt:208,1-222,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`importSkill @ File @ FileNameJoin @ { $sampleSkillDir, "SKILL.md" },
    $sampleSkill,
    SameTest -> SameQ,
    TestID   -> "ImportSkill-File@@Tests/Skills.wlt:224,1-229,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`importSkill @ $unnamedSkillDir,
    HoldPattern @ LLMSkill[ KeyValuePattern[ "Name" -> "unnamed-skill" ], ___ ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-NameFromDirectory@@Tests/Skills.wlt:231,1-236,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`makeSkill[
        <| "name" -> "", "description" -> "An empty name." |>,
        "Body",
        FileNameJoin @ { $unnamedSkillDir, "SKILL.md" }
    ],
    HoldPattern @ LLMSkill[ KeyValuePattern[ "Name" -> "unnamed-skill" ], ___ ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-EmptyName@@Tests/Skills.wlt:238,1-247,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`importSkill @ $noDescriptionSkillDir,
    Failure[ "InvalidSkill", KeyValuePattern[ "MessageParameters" -> { _, _String? (StringContainsQ[ "description" ]) } ] ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-MissingDescription@@Tests/Skills.wlt:249,1-254,2"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`importSkill @ FileNameJoin @ { $tempRoot, "does-not-exist" },
    Failure[ "MissingSkillFile", _ ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-MissingFile@@Tests/Skills.wlt:256,1-261,2"
]

(* Parsed skills are cached until the file is modified: *)
VerificationTest[
    Module[ { file, before, after },
        file = FileNameJoin @ { $unnamedSkillDir, "SKILL.md" };
        before = Wolfram`Chatbook`Skills`Private`importSkill @ $unnamedSkillDir;
        writeTestFile[ file, "---\ndescription: Updated.\n---\nNew body\n" ];
        SetFileDate[ file, DateObject[ { 2020, 1, 1, 0, 0, 0 } ], "Modification" ];
        after = Wolfram`Chatbook`Skills`Private`importSkill @ $unnamedSkillDir;
        Wolfram`Chatbook`Skills`Private`skillDescription /@ { before, after }
    ],
    { "No name here.", "Updated." },
    SameTest -> SameQ,
    TestID   -> "ImportSkill-CacheInvalidation@@Tests/Skills.wlt:264,1-276,2"
]

(* Hidden files and ignored directories are not listed: *)
VerificationTest[
    Wolfram`Chatbook`Skills`Private`skillResourceFiles @ $sampleSkillDir,
    { "data.bin", "references/guide.md", "scripts/run.wl" },
    SameTest -> SameQ,
    TestID   -> "SkillResourceFiles@@Tests/Skills.wlt:279,1-284,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resolving Skills*)
VerificationTest[
    resolvedSkillNames // ClearAll;
    resolvedSkillNames[ spec_ ] := resolvedSkillNames[ spec, True ];
    resolvedSkillNames[ spec_, toolsEnabled_ ] :=
        Wolfram`Chatbook`Skills`Private`skillName /@ Wolfram`Chatbook`Common`resolveSkills[
            <| "ToolsEnabled" -> toolsEnabled, "Skills" -> spec |>
        ][ "Skills" ];
    resolvedSkillNames[ Automatic ],
    { },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-Automatic-TestSkillIsOptIn@@Tests/Skills.wlt:289,1-300,2"
]

VerificationTest[
    MemberQ[ resolvedSkillNames[ All ], "test-skill" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-All@@Tests/Skills.wlt:302,1-307,2"
]

VerificationTest[
    resolvedSkillNames /@ { None, { }, "test-skill", { "test-skill" } },
    { { }, { }, { "test-skill" }, { "test-skill" } },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-Names@@Tests/Skills.wlt:309,1-314,2"
]

VerificationTest[
    resolvedSkillNames @ { "test-skill", $sampleSkill, "test-skill" },
    { "test-skill", "sample-skill" },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-LLMSkillObjects@@Tests/Skills.wlt:316,1-321,2"
]

(* ParentList inherits the default skills: *)
VerificationTest[
    resolvedSkillNames @ { $sampleSkill, ParentList },
    { "sample-skill" },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-ParentList@@Tests/Skills.wlt:324,1-329,2"
]

VerificationTest[
    resolvedSkillNames @ { "does-not-exist", "test-skill" },
    { "test-skill" },
    { Chatbook::SkillNotFound },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-NotFound@@Tests/Skills.wlt:331,1-337,2"
]

VerificationTest[
    resolvedSkillNames @ { 123 },
    { },
    { Chatbook::InvalidSkillSpecification },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-InvalidSpecification@@Tests/Skills.wlt:339,1-345,2"
]

(* LLMSkill expressions that were not validated by LLMFunctions need a name and a body: *)
VerificationTest[
    resolvedSkillNames @ { System`Private`ConstructNoEntry[ LLMSkill, <| "Name" -> "no-body" |> ] },
    { },
    { Chatbook::InvalidSkillSpecification },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-InvalidSkillObject@@Tests/Skills.wlt:348,1-354,2"
]

(* Skills can only be activated with a tool call: *)
VerificationTest[
    resolvedSkillNames[ All, False ],
    { },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-ToolsDisabled@@Tests/Skills.wlt:357,1-362,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Tool*)
VerificationTest[
    $skillTool = Wolfram`Chatbook`Skills`Private`makeSkillTool @ { $testSkill, $sampleSkill },
    HoldPattern[ _LLMTool ],
    SameTest -> MatchQ,
    TestID   -> "SkillTool-Create@@Tests/Skills.wlt:367,1-372,2"
]

VerificationTest[
    KeyTake[ $skillTool[ "Data" ], { "Name", "CanonicalName", "ShortName" } ],
    <| "Name" -> "activate_skill", "CanonicalName" -> "ActivateSkill", "ShortName" -> "skill" |>,
    SameTest -> SameQ,
    TestID   -> "SkillTool-Names@@Tests/Skills.wlt:374,1-379,2"
]

VerificationTest[
    $skillTool[ "JSONSchema" ],
    KeyValuePattern @ {
        "properties" -> KeyValuePattern @ {
            "name" -> KeyValuePattern[ "enum" -> { "test-skill", "sample-skill" } ],
            "path" -> KeyValuePattern[ "type" -> "string" ]
        },
        "required" -> { "name" }
    },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-Schema@@Tests/Skills.wlt:381,1-392,2"
]

VerificationTest[
    activate // ClearAll;
    activate[ name_String ] := activate[ name, Missing[ "NoInput" ] ];
    activate[ name_String, path_ ] := $skillTool[ "Function" ][ <| "name" -> name, "path" -> path |> ];
    $sampleInstructions = activate[ "sample-skill" ],
    _String? (StringStartsQ[ "<skill_content name=\"sample-skill\">\n# Sample Skill\n" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillTool-Instructions@@Tests/Skills.wlt:394,1-402,2"
]

VerificationTest[
    StringContainsQ[ $sampleInstructions, # ] & /@ {
        "Skill directory: " <> $sampleSkillDir,
        "<file>references/guide.md</file>",
        "<file>scripts/run.wl</file>",
        ".env",
        "secret.txt",
        "cached.pyc",
        "name: sample-skill"
    },
    { True, True, True, False, False, False, False },
    SameTest -> SameQ,
    TestID   -> "SkillTool-Instructions-Content@@Tests/Skills.wlt:404,1-417,2"
]

(* Optional parameters can arrive as Missing or empty strings, and SKILL.md can be requested explicitly: *)
VerificationTest[
    activate[ "sample-skill", # ] & /@ { "", "SKILL.md", "./SKILL.md", "skill.md", "." },
    ConstantArray[ $sampleInstructions, 5 ],
    SameTest -> SameQ,
    TestID   -> "SkillTool-Instructions-DefaultPath@@Tests/Skills.wlt:420,1-425,2"
]

VerificationTest[
    activate[ "sample-skill", "references/guide.md" ],
    "<skill_file name=\"sample-skill\" path=\"references/guide.md\">\n# Guide\n\nThe guide code is 12345.\n</skill_file>",
    SameTest -> SameQ,
    TestID   -> "SkillTool-ReadFile@@Tests/Skills.wlt:427,1-432,2"
]

VerificationTest[
    activate[ "sample-skill", # ] & /@ {
        "references\\guide.md",
        "./references/guide.md",
        FileNameJoin @ { $sampleSkillDir, "references", "guide.md" }
    },
    ConstantArray[ activate[ "sample-skill", "references/guide.md" ], 3 ],
    SameTest -> SameQ,
    TestID   -> "SkillTool-ReadFile-PathForms@@Tests/Skills.wlt:434,1-443,2"
]

VerificationTest[
    activate[ "sample-skill", # ] & /@ {
        "../unnamed-skill/SKILL.md",
        "/etc/passwd",
        "~/.bashrc",
        ".env",
        ".hidden/secret.txt",
        "__pycache__/cached.pyc"
    },
    { KeyValuePattern @ { "Result" -> Failure[ "InvalidSkillPath", _ ], "String" -> _String? (StringStartsQ[ "Error: " ]) } .. },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-ReadFile-InvalidPaths@@Tests/Skills.wlt:445,1-457,2"
]

VerificationTest[
    activate[ "sample-skill", "references/missing.md" ],
    KeyValuePattern @ {
        "Result" -> Failure[ "SkillFileNotFound", _ ],
        "String" -> _String? (StringContainsQ[ "Available files: data.bin, references/guide.md, scripts/run.wl" ])
    },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-ReadFile-NotFound@@Tests/Skills.wlt:459,1-467,2"
]

VerificationTest[
    activate[ "sample-skill", "references" ],
    KeyValuePattern[ "Result" -> Failure[ "SkillPathIsDirectory", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "SkillTool-ReadFile-Directory@@Tests/Skills.wlt:469,1-474,2"
]

VerificationTest[
    activate[ "sample-skill", "data.bin" ],
    KeyValuePattern[ "Result" -> Failure[ "SkillFileNotText", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "SkillTool-ReadFile-Binary@@Tests/Skills.wlt:476,1-481,2"
]

VerificationTest[
    activate[ "does-not-exist" ],
    KeyValuePattern @ {
        "Result" -> Failure[ "SkillNotAvailable", _ ],
        "String" -> _String? (StringContainsQ[ "Available skills: test-skill, sample-skill" ])
    },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-SkillNotAvailable@@Tests/Skills.wlt:483,1-491,2"
]

(* The built-in test skill can read its own reference file: *)
VerificationTest[
    activate[ "test-skill", "references/verification.md" ],
    _String? (StringContainsQ[ "SLATE-HERON-3908" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillTool-TestSkill-Reference@@Tests/Skills.wlt:494,1-499,2"
]

(* Skills that were not loaded from a directory only have instructions: *)
VerificationTest[
    $memorySkill = Wolfram`Chatbook`Skills`Private`constructSkill @ <|
        "Name"             -> "memory-skill",
        "Description"      -> "A skill that only exists in memory.",
        "Location"         -> None,
        "Body"             -> "Remember this.",
        "Options"          -> { },
        "LLMPacletVersion" -> Wolfram`Chatbook`Skills`Private`$llmFunctionsVersion
    |>;
    $memoryTool = Wolfram`Chatbook`Skills`Private`makeSkillTool @ { $memorySkill };
    {
        $memoryTool[ "Function" ][ <| "name" -> "memory-skill" |> ],
        $memoryTool[ "Function" ][ <| "name" -> "memory-skill", "path" -> "references/guide.md" |> ]
    },
    {
        "<skill_content name=\"memory-skill\">\nRemember this.\n</skill_content>",
        KeyValuePattern[ "Result" -> Failure[ "SkillHasNoDirectory", _ ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-NoDirectory@@Tests/Skills.wlt:502,1-522,2"
]

(* Files can only be read from directories that contain a SKILL.md file: *)
VerificationTest[
    Wolfram`Chatbook`Skills`Private`skillDirectory /@ { File @ $tempRoot, File @ $sampleSkillDir, None },
    { _Missing, $sampleSkillDir, _Missing },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-SkillDirectory@@Tests/Skills.wlt:525,1-530,2"
]

(* Tool calls through LLMFunctions: *)
VerificationTest[
    GenerateLLMToolResponse[
        LLMConfiguration @ <| "Tools" -> { $skillTool } |>,
        LLMToolRequest[ "activate_skill", { "name" -> "test-skill" } ]
    ][ "Output" ],
    _String? (StringContainsQ[ "MAROON-ORCHID-7214" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillTool-GenerateLLMToolResponse@@Tests/Skills.wlt:533,1-541,2"
]

VerificationTest[
    GenerateLLMToolResponse[
        LLMConfiguration @ <| "Tools" -> { $skillTool } |>,
        LLMToolRequest[ "activate_skill", { "name" -> "not-a-skill" } ]
    ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "SkillTool-GenerateLLMToolResponse-InvalidName@@Tests/Skills.wlt:543,1-551,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Symbolic Links*)
(* A skill can contain links to files anywhere on the machine (e.g. from a cloned repository), which must not be
   readable through the skill tool: *)
VerificationTest[
    createLink // ClearAll;
    createLink[ target_String, link_String ] := RunProcess[ { "ln", "-s", target, link } ][ "ExitCode" ] === 0;

    $linksSupported = $OperatingSystem =!= "Windows";
    $outsideDir     = FileNameJoin @ { $tempRoot, "outside" };
    $linkedSkillDir = FileNameJoin @ { $tempRoot, "linked-skill" };

    writeTestFile[ FileNameJoin @ { $outsideDir, "secret.txt" }, "OUTSIDE-SECRET\n" ];
    writeTestFile[ FileNameJoin @ { $outsideDir, "SKILL.md" }, "---\nname: outside\ndescription: Outside.\n---\nOUTSIDE\n" ];
    writeTestFile[ FileNameJoin @ { $linkedSkillDir, "SKILL.md" }, "---\nname: linked-skill\ndescription: Links.\n---\nBody\n" ];
    writeTestFile[ FileNameJoin @ { $linkedSkillDir, "references", "guide.md" }, "INSIDE-GUIDE\n" ];
    writeTestFile[ FileNameJoin @ { $linkedSkillDir, ".env" }, "SECRET=1\n" ];

    If[ $linksSupported,
        AllTrue[
            {
                createLink[ "guide.md", FileNameJoin @ { $linkedSkillDir, "references", "inside.md" } ],
                createLink[ "../../outside/secret.txt", FileNameJoin @ { $linkedSkillDir, "references", "relative.md" } ],
                createLink[ FileNameJoin @ { $outsideDir, "secret.txt" }, FileNameJoin @ { $linkedSkillDir, "references", "absolute.md" } ],
                createLink[ "../outside", FileNameJoin @ { $linkedSkillDir, "outside-dir" } ],
                createLink[ "references", FileNameJoin @ { $linkedSkillDir, "refs" } ],
                createLink[ ".", FileNameJoin @ { $linkedSkillDir, "loop" } ],
                createLink[ ".env", FileNameJoin @ { $linkedSkillDir, "env.md" } ],
                createLink[ FileNameJoin @ { $tempRoot, "does-not-exist" }, FileNameJoin @ { $linkedSkillDir, "broken.md" } ],
                createLink[ $linkedSkillDir, FileNameJoin @ { $tempRoot, "linked-skill-alias" } ]
            },
            TrueQ
        ],
        True
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "SymbolicLinks-Setup@@Tests/Skills.wlt:558,1-592,2"
]

(* Links are only listed if they point to a readable file in the skill, and linked directories are not followed: *)
VerificationTest[
    If[ $linksSupported, Wolfram`Chatbook`Skills`Private`skillResourceFiles @ $linkedSkillDir, Missing[ "TestSkipped" ] ],
    Missing[ "TestSkipped" ] | { "references/guide.md", "references/inside.md" },
    SameTest -> MatchQ,
    TestID   -> "SymbolicLinks-Listing@@Tests/Skills.wlt:595,1-600,2"
]

VerificationTest[
    If[ $linksSupported,
        $linkedTool = Wolfram`Chatbook`Skills`Private`makeSkillTool @ {
            Wolfram`Chatbook`Skills`Private`importSkill @ $linkedSkillDir
        };
        readLinked // ClearAll;
        readLinked[ path_String ] := $linkedTool[ "Function" ][ <| "name" -> "linked-skill", "path" -> path |> ];
        readLinked /@ { "references/inside.md", "refs/guide.md", "loop/references/guide.md" },
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | { _String? (StringContainsQ[ "INSIDE-GUIDE" ]).. },
    SameTest -> MatchQ,
    TestID   -> "SymbolicLinks-ReadInside@@Tests/Skills.wlt:602,1-615,2"
]

VerificationTest[
    If[ $linksSupported,
        readLinked /@ { "references/relative.md", "references/absolute.md", "outside-dir/secret.txt", "env.md" },
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | {
        KeyValuePattern @ {
            "Result" -> Failure[ "SkillPathOutsideDirectory", _ ],
            "String" -> _String? (StringFreeQ[ "OUTSIDE-SECRET" | "SECRET=1" ])
        }..
    },
    SameTest -> MatchQ,
    TestID   -> "SymbolicLinks-ReadOutside@@Tests/Skills.wlt:617,1-630,2"
]

VerificationTest[
    If[ $linksSupported, readLinked[ "broken.md" ], Missing[ "TestSkipped" ] ],
    Missing[ "TestSkipped" ] | KeyValuePattern[ "Result" -> Failure[ "SkillFileNotFound", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "SymbolicLinks-BrokenLink@@Tests/Skills.wlt:632,1-637,2"
]

(* The skill directory itself can be a link: *)
VerificationTest[
    If[ $linksSupported,
        Module[ { tool },
            tool = Wolfram`Chatbook`Skills`Private`makeSkillTool @ {
                Wolfram`Chatbook`Skills`Private`importSkill @ FileNameJoin @ { $tempRoot, "linked-skill-alias" }
            };
            tool[ "Function" ][ <| "name" -> "linked-skill", "path" -> # |> ] & /@ {
                "references/guide.md",
                "references/relative.md"
            }
        ],
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | {
        _String? (StringContainsQ[ "INSIDE-GUIDE" ]),
        KeyValuePattern[ "Result" -> Failure[ "SkillPathOutsideDirectory", _ ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "SymbolicLinks-LinkedSkillDirectory@@Tests/Skills.wlt:640,1-659,2"
]

(* SKILL.md itself cannot be a link to a file outside of the skill directory: *)
VerificationTest[
    If[ $linksSupported,
        Module[ { dir },
            dir = CreateDirectory @ FileNameJoin @ { $tempRoot, "linked-instructions" };
            createLink[ FileNameJoin @ { $outsideDir, "SKILL.md" }, FileNameJoin @ { dir, "SKILL.md" } ];
            Wolfram`Chatbook`Skills`Private`importSkill @ dir
        ],
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | Failure[ "InvalidSkill", _ ],
    SameTest -> MatchQ,
    TestID   -> "SymbolicLinks-SkillFile@@Tests/Skills.wlt:662,1-674,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skills Prompt*)
VerificationTest[
    $skillsPrompt = Wolfram`Chatbook`Common`getSkillsPrompt @ <|
        "ToolsEnabled" -> True,
        "ToolMethod"   -> Automatic,
        "Skills"       -> { $testSkill, $sampleSkill }
    |>,
    _String? (StringStartsQ[ "# Skills\n" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillsPrompt@@Tests/Skills.wlt:679,1-688,2"
]

VerificationTest[
    StringContainsQ[ $skillsPrompt, # ] & /@ {
        "activate_skill",
        "<available_skills>",
        "<name>test-skill</name>",
        "<name>sample-skill</name>",
        "<description>A sample skill for testing.</description>",
        "MAROON-ORCHID-7214"
    },
    { True, True, True, True, True, False },
    SameTest -> SameQ,
    TestID   -> "SkillsPrompt-Content@@Tests/Skills.wlt:690,1-702,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`getSkillsPrompt @ <| "ToolsEnabled" -> True, "ToolMethod" -> "Simple", "Skills" -> { $testSkill } |>,
    _String? (StringContainsQ[ "call the /skill tool" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillsPrompt-SimpleToolMethod@@Tests/Skills.wlt:704,1-709,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`getSkillsPrompt /@ {
        <| "ToolsEnabled" -> True, "Skills" -> { } |>,
        <| "ToolsEnabled" -> False, "Skills" -> { $testSkill } |>,
        <| "Skills" -> Automatic |>
    },
    { _Missing, _Missing, _Missing },
    SameTest -> MatchQ,
    TestID   -> "SkillsPrompt-NoSkills@@Tests/Skills.wlt:711,1-720,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`getSkillsPrompt @ <|
        "ToolsEnabled" -> True,
        "Skills"       -> {
            Wolfram`Chatbook`Skills`Private`constructSkill @ <|
                "Name"             -> "escaped-skill",
                "Description"      -> "Use <b>this</b> &\n  that.",
                "Location"         -> None,
                "Body"             -> "Body",
                "Options"          -> { },
                "LLMPacletVersion" -> Wolfram`Chatbook`Skills`Private`$llmFunctionsVersion
            |>
        }
    |>,
    _String? (StringContainsQ[ "<description>Use &lt;b&gt;this&lt;/b&gt; &amp; that.</description>" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillsPrompt-Escaping@@Tests/Skills.wlt:722,1-739,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Settings*)
VerificationTest[
    Wolfram`Chatbook`Common`$defaultChatSettings[ "Skills" ],
    Automatic,
    SameTest -> SameQ,
    TestID   -> "ChatSettings-Default@@Tests/Skills.wlt:744,1-749,2"
]

VerificationTest[
    $skillSettings = Wolfram`Chatbook`Common`resolveAutoSettings @ <|
        Wolfram`Chatbook`Common`$defaultChatSettings,
        "Skills" -> { "test-skill" }
    |>;
    {
        Wolfram`Chatbook`Skills`Private`skillName /@ $skillSettings[ "Skills" ],
        MemberQ[ Wolfram`Chatbook`Common`toolName /@ $skillSettings[ "Tools" ], "ActivateSkill" ]
    },
    { { "test-skill" }, True },
    SameTest -> SameQ,
    TestID   -> "ChatSettings-ResolveSkills@@Tests/Skills.wlt:751,1-763,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`makeCurrentRole[ $skillSettings ][ "Content" ],
    _String? (StringContainsQ[ "<available_skills>" ]),
    SameTest -> MatchQ,
    TestID   -> "ChatSettings-SystemPrompt@@Tests/Skills.wlt:765,1-770,2"
]

(* The skill tool is removed again when skills are no longer used: *)
VerificationTest[
    $defaultSettings = Wolfram`Chatbook`Common`resolveAutoSettings @ Wolfram`Chatbook`Common`$defaultChatSettings;
    {
        $defaultSettings[ "Skills" ],
        MemberQ[ Wolfram`Chatbook`Common`toolName /@ $defaultSettings[ "Tools" ], "ActivateSkill" ],
        StringContainsQ[ Wolfram`Chatbook`Common`makeCurrentRole[ $defaultSettings ][ "Content" ], "available_skills" ]
    },
    { { }, False, False },
    SameTest -> SameQ,
    TestID   -> "ChatSettings-NoSkills@@Tests/Skills.wlt:773,1-783,2"
]

(* The skill tool works with the "Simple" tool method, so it should not change the automatic choice of tool method: *)
VerificationTest[
    Wolfram`Chatbook`Common`skillToolQ /@ { $skillTool, First @ $DefaultTools, "ActivateSkill" },
    { True, False, False },
    SameTest -> SameQ,
    TestID   -> "ChatSettings-SkillToolQ@@Tests/Skills.wlt:786,1-791,2"
]

VerificationTest[
    Wolfram`Chatbook`Settings`Private`simpleToolQ @ $skillTool,
    True,
    SameTest -> SameQ,
    TestID   -> "ChatSettings-SimpleToolQ@@Tests/Skills.wlt:793,1-798,2"
]

VerificationTest[
    Wolfram`Chatbook`Settings`Private`chooseToolMethod /@ {
        <| "Tools" -> Values @ $DefaultTools |>,
        <| "Tools" -> Append[ Values @ $DefaultTools, $skillTool ] |>,
        <| "Tools" -> { $skillTool, LLMTool[ { "custom_tool", "A custom tool." }, { "x" -> "String" }, # & ] } |>
    },
    { "Simple", "Simple", Automatic },
    SameTest -> SameQ,
    TestID   -> "ChatSettings-ChooseToolMethod@@Tests/Skills.wlt:800,1-809,2"
]

VerificationTest[
    $skillSettings[ "ToolMethod" ],
    $defaultSettings[ "ToolMethod" ],
    SameTest -> SameQ,
    TestID   -> "ChatSettings-ToolMethod@@Tests/Skills.wlt:811,1-816,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Simple Tool Method*)
VerificationTest[
    Wolfram`Chatbook`Tools`Private`simpleToolSchema @ $skillTool,
    _String? (StringStartsQ[ "Activate Skill (/skill)\n" ]),
    SameTest -> MatchQ,
    TestID   -> "SimpleToolMethod-Schema@@Tests/Skills.wlt:821,1-826,2"
]

VerificationTest[
    simpleSkillToolCall // ClearAll;
    simpleSkillToolCall[ response_String ] :=
        Module[ { request },
            request = Block[ { Wolfram`Chatbook`Common`$selectedTools = <| "ActivateSkill" -> $skillTool |> },
                Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ response
            ];
            GenerateLLMToolResponse[ LLMConfiguration @ <| "Tools" -> { $skillTool } |>, request ][ "Output" ]
        ];
    simpleSkillToolCall[ "I'll check that skills are working.\n\n/skill\ntest-skill\n" ],
    _String? (StringContainsQ[ "MAROON-ORCHID-7214" ]),
    SameTest -> MatchQ,
    TestID   -> "SimpleToolMethod-Instructions@@Tests/Skills.wlt:828,1-841,2"
]

VerificationTest[
    simpleSkillToolCall /@ {
        "/skill\ntest-skill\nreferences/verification.md\n",
        "/skill\nname: test-skill\npath: references/verification.md\n"
    },
    { _String? (StringContainsQ[ "SLATE-HERON-3908" ]).. },
    SameTest -> MatchQ,
    TestID   -> "SimpleToolMethod-ReadFile@@Tests/Skills.wlt:843,1-851,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateLLMConfiguration*)
VerificationTest[
    $config = Quiet[
        GenerateLLMConfiguration[ "NotebookAssistant", <| "Skills" -> { "test-skill" } |> ],
        LLMServices`Defaults`Private`LLMFunctions::llmrstrt
    ],
    HoldPattern @ LLMConfiguration[ _Association? AssociationQ, ___ ],
    SameTest -> MatchQ,
    TestID   -> "GenerateLLMConfiguration-Skills@@Tests/Skills.wlt:856,1-864,2"
]

VerificationTest[
    MemberQ[ #[ "Data" ][ "CanonicalName" ] & /@ $config[ "Tools" ], "ActivateSkill" ],
    True,
    SameTest -> SameQ,
    TestID   -> "GenerateLLMConfiguration-Skills-Tool@@Tests/Skills.wlt:866,1-871,2"
]

VerificationTest[
    StringContainsQ[ StringJoin @ Select[ $config[ "Prompts" ], StringQ ], "<name>test-skill</name>" ],
    True,
    SameTest -> SameQ,
    TestID   -> "GenerateLLMConfiguration-Skills-Prompt@@Tests/Skills.wlt:873,1-878,2"
]

VerificationTest[
    MemberQ[ #[ "Data" ][ "CanonicalName" ] & /@ GenerateLLMConfiguration[ "NotebookAssistant" ][ "Tools" ], "ActivateSkill" ],
    False,
    SameTest -> SameQ,
    TestID   -> "GenerateLLMConfiguration-NoSkills@@Tests/Skills.wlt:880,1-885,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteDirectory[ $tempRoot, DeleteContents -> True ],
    Null,
    SameTest -> SameQ,
    TestID   -> "Cleanup@@Tests/Skills.wlt:890,1-895,2"
]

(* :!CodeAnalysis::EndBlock:: *)
