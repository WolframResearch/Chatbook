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

VerificationTest[
    Context @ $DefaultSkills,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "DefaultSkillsContext"
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
    TestID   -> "TestDefinitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Built-in Skills*)
VerificationTest[
    $skillsAssetDirectory = PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "Skills" ],
    _String? DirectoryQ,
    SameTest -> MatchQ,
    TestID   -> "BuiltInSkills-AssetLocation"
]

VerificationTest[
    AssociationQ @ $DefaultSkills && AllTrue[ $DefaultSkills, MatchQ @ HoldPattern @ LLMSkill[ _Association, ___ ] ],
    True,
    SameTest -> SameQ,
    TestID   -> "BuiltInSkills-DefaultSkills"
]

(* Every skill directory in Assets/Skills should load successfully: *)
VerificationTest[
    Sort @ Keys @ $DefaultSkills,
    Sort[ FileNameTake /@ FileNames[ All, $skillsAssetDirectory ] ],
    SameTest -> SameQ,
    TestID   -> "BuiltInSkills-AllSkillsLoad"
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
    TestID   -> "BuiltInSkills-TestSkill"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`skillDirectory @ $testSkill,
    FileNameJoin @ { $skillsAssetDirectory, "test-skill" },
    SameTest -> SameQ,
    TestID   -> "BuiltInSkills-TestSkill-Directory"
]

(* Built-in skills are selected by directory name before they are imported, so names must match directory names: *)
VerificationTest[
    Select[
        FileNames[ "SKILL.md", $skillsAssetDirectory, { 2 } ],
        Function[
            file,
            Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[
                Wolfram`Chatbook`Skills`Private`readSkillText @ file
            ][ "Frontmatter", "name" ] =!= FileNameTake[ file, { -2 } ]
        ]
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "BuiltInSkills-NamesMatchDirectories"
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
    TestID   -> "ParseSkillMarkdown-Basic"
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
    TestID   -> "ParseSkillMarkdown-LineEndings"
]

(* Unquoted colons in values are invalid YAML, but are common in skills written for other clients: *)
VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[
        "---\nname: pdf-skill\ndescription: Use this skill when: the user asks about PDFs\n---\nBody"
    ][ "Frontmatter" ],
    <| "name" -> "pdf-skill", "description" -> "Use this skill when: the user asks about PDFs" |>,
    SameTest -> SameQ,
    TestID   -> "ParseSkillMarkdown-UnquotedColon"
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
    TestID   -> "ParseSkillMarkdown-QuotedColon"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[ "# No frontmatter\n\nJust markdown." ],
    Failure[ "InvalidSkill", KeyValuePattern[ "MessageParameters" -> { _String? (StringContainsQ[ "---" ]) } ] ],
    SameTest -> MatchQ,
    TestID   -> "ParseSkillMarkdown-MissingFrontmatter"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[ "---\nname: my-skill\ndescription: Unclosed.\n" ],
    Failure[ "InvalidSkill", _ ],
    SameTest -> MatchQ,
    TestID   -> "ParseSkillMarkdown-UnclosedFrontmatter"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`parseSkillMarkdown[ "---\nname: [unclosed\n---\nBody", "SKILL.md" ],
    Failure[ "InvalidSkill", KeyValuePattern[ "MessageParameters" -> { "SKILL.md", _String } ] ],
    SameTest -> MatchQ,
    TestID   -> "ParseSkillMarkdown-InvalidYAML"
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
    TestID   -> "ImportSkill-Directory"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`importSkill @ File @ FileNameJoin @ { $sampleSkillDir, "SKILL.md" },
    $sampleSkill,
    SameTest -> SameQ,
    TestID   -> "ImportSkill-File"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`importSkill @ $unnamedSkillDir,
    HoldPattern @ LLMSkill[ KeyValuePattern[ "Name" -> "unnamed-skill" ], ___ ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-NameFromDirectory"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`makeSkill[
        <| "name" -> "", "description" -> "An empty name." |>,
        "Body",
        FileNameJoin @ { $unnamedSkillDir, "SKILL.md" }
    ],
    HoldPattern @ LLMSkill[ KeyValuePattern[ "Name" -> "unnamed-skill" ], ___ ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-EmptyName"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`importSkill @ $noDescriptionSkillDir,
    Failure[ "InvalidSkill", KeyValuePattern[ "MessageParameters" -> { _, _String? (StringContainsQ[ "description" ]) } ] ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-MissingDescription"
]

VerificationTest[
    Wolfram`Chatbook`Skills`Private`importSkill @ FileNameJoin @ { $tempRoot, "does-not-exist" },
    Failure[ "MissingSkillFile", _ ],
    SameTest -> MatchQ,
    TestID   -> "ImportSkill-MissingFile"
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
    TestID   -> "ImportSkill-CacheInvalidation"
]

(* Hidden files and ignored directories are not listed: *)
VerificationTest[
    Wolfram`Chatbook`Skills`Private`skillResourceFiles @ $sampleSkillDir,
    { "data.bin", "references/guide.md", "scripts/run.wl" },
    SameTest -> SameQ,
    TestID   -> "SkillResourceFiles"
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
    TestID   -> "ResolveSkills-Automatic-TestSkillIsOptIn"
]

VerificationTest[
    MemberQ[ resolvedSkillNames[ All ], "test-skill" ],
    True,
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-All"
]

VerificationTest[
    resolvedSkillNames /@ { None, { }, "test-skill", { "test-skill" } },
    { { }, { }, { "test-skill" }, { "test-skill" } },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-Names"
]

VerificationTest[
    resolvedSkillNames @ { "test-skill", $sampleSkill, "test-skill" },
    { "test-skill", "sample-skill" },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-LLMSkillObjects"
]

(* ParentList inherits the default skills: *)
VerificationTest[
    resolvedSkillNames @ { $sampleSkill, ParentList },
    { "sample-skill" },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-ParentList"
]

VerificationTest[
    resolvedSkillNames @ { "does-not-exist", "test-skill" },
    { "test-skill" },
    { Chatbook::SkillNotFound },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-NotFound"
]

VerificationTest[
    resolvedSkillNames @ { 123 },
    { },
    { Chatbook::InvalidSkillSpecification },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-InvalidSpecification"
]

(* LLMSkill expressions that were not validated by LLMFunctions need a name and a body: *)
VerificationTest[
    resolvedSkillNames @ { System`Private`ConstructNoEntry[ LLMSkill, <| "Name" -> "no-body" |> ] },
    { },
    { Chatbook::InvalidSkillSpecification },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-InvalidSkillObject"
]

(* Skills can only be activated with a tool call: *)
VerificationTest[
    resolvedSkillNames[ All, False ],
    { },
    SameTest -> SameQ,
    TestID   -> "ResolveSkills-ToolsDisabled"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Lazy Built-in Skills*)
(* Importing a skill is slow (the first YAML import loads the importer), so built-in skills are only imported when the
   specification can use them: *)
VerificationTest[
    importedBuiltInSkills // ClearAll;

    (* Gives the names of the resolved skills and the directory names of the skill files that were imported: *)
    importedBuiltInSkills[ spec_ ] := Module[ { imported = { } },
        Internal`InheritedBlock[ { Wolfram`Chatbook`Skills`Private`importSkill },
            PrependTo[
                DownValues @ Wolfram`Chatbook`Skills`Private`importSkill,
                HoldPattern @ Wolfram`Chatbook`Skills`Private`importSkill[ file_String ] :>
                    Null /; (AppendTo[ imported, FileNameTake[ file, { -2 } ] ]; False)
            ];
            {
                Wolfram`Chatbook`Skills`Private`skillName /@ Wolfram`Chatbook`Skills`Private`getSkills @ spec,
                imported
            }
        ]
    ];

    $automaticBuiltInSkills = DeleteCases[ Keys @ $DefaultSkills, Alternatives @@ Wolfram`Chatbook`Skills`Private`$optInSkills ];

    MemberQ[ Wolfram`Chatbook`Skills`Private`$optInSkills, "test-skill" ],
    True,
    SameTest -> SameQ,
    TestID   -> "LazyBuiltInSkills-Definitions"
]

VerificationTest[
    importedBuiltInSkills /@ { Automatic, Inherited, ParentList },
    ConstantArray[ { $automaticBuiltInSkills, $automaticBuiltInSkills }, 3 ],
    SameTest -> SameQ,
    TestID   -> "LazyBuiltInSkills-Automatic-SkipsOptIn"
]

VerificationTest[
    importedBuiltInSkills /@ { "test-skill", { "test-skill" }, { None, { "test-skill" } } },
    ConstantArray[ { { "test-skill" }, { "test-skill" } }, 3 ],
    SameTest -> SameQ,
    TestID   -> "LazyBuiltInSkills-Names"
]

VerificationTest[
    importedBuiltInSkills @ All,
    { Keys @ $DefaultSkills, Keys @ $DefaultSkills },
    SameTest -> SameQ,
    TestID   -> "LazyBuiltInSkills-All"
]

(* Specifications that can't use built-in skills don't look for them: *)
VerificationTest[
    Module[ { touched = False },
        Block[ { Wolfram`Chatbook`Skills`Private`$builtInSkillsDirectory },
            Wolfram`Chatbook`Skills`Private`$builtInSkillsDirectory := (touched = True; $Failed);
            {
                Wolfram`Chatbook`Skills`Private`getSkills /@ { None, { }, { None }, { $sampleSkill } },
                touched
            }
        ]
    ],
    { { { }, { }, { }, { $sampleSkill } }, False },
    SameTest -> SameQ,
    TestID   -> "LazyBuiltInSkills-None"
]

(* Resolving skills gives the same result as importing all built-in skills first: *)
VerificationTest[
    $fakeBuiltInSkillsDir = FileNameJoin @ { $tempRoot, "built-in" };
    Scan[
        writeTestFile[
            FileNameJoin @ { $fakeBuiltInSkillsDir, #, "SKILL.md" },
            "---\nname: " <> # <> "\ndescription: The " <> # <> " skill.\n---\nBody of " <> # <> "\n"
        ] &,
        { "alpha-skill", "beta-skill", "opt-in-skill" }
    ];
    writeTestFile[ FileNameJoin @ { $fakeBuiltInSkillsDir, "broken-skill", "SKILL.md" }, "---\nname: broken-skill\n---\n" ];

    Block[
        {
            Wolfram`Chatbook`Skills`Private`$builtInSkillsDirectory = $fakeBuiltInSkillsDir,
            Wolfram`Chatbook`Skills`Private`$optInSkills            = { "opt-in-skill" }
        },
        {
            Keys @ $DefaultSkills,
            Select[
                {
                    Automatic,
                    Inherited,
                    ParentList,
                    None,
                    All,
                    { },
                    "alpha-skill",
                    "opt-in-skill",
                    { "opt-in-skill", Automatic },
                    { Automatic, "opt-in-skill", "beta-skill" },
                    { $sampleSkill, ParentList },
                    { { "opt-in-skill" }, All },
                    { None, $sampleSkill }
                },
                Wolfram`Chatbook`Skills`Private`getSkills[ # ] =!=
                    Wolfram`Chatbook`Skills`Private`getSkills[ #, $DefaultSkills ] &
            ]
        }
    ],
    { { "alpha-skill", "beta-skill", "opt-in-skill" }, { } },
    SameTest -> SameQ,
    TestID   -> "LazyBuiltInSkills-SameResult"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Skills`Private`$builtInSkillsDirectory = $fakeBuiltInSkillsDir,
            Wolfram`Chatbook`Skills`Private`$optInSkills            = { "opt-in-skill" }
        },
        importedBuiltInSkills /@ { Automatic, None, "opt-in-skill", { "beta-skill", "opt-in-skill" }, All }
    ],
    {
        { { "alpha-skill", "beta-skill" }, { "alpha-skill", "beta-skill", "broken-skill" } },
        { { }, { } },
        { { "opt-in-skill" }, { "opt-in-skill" } },
        { { "beta-skill", "opt-in-skill" }, { "beta-skill", "opt-in-skill" } },
        {
            { "alpha-skill", "beta-skill", "opt-in-skill" },
            { "alpha-skill", "beta-skill", "broken-skill", "opt-in-skill" }
        }
    },
    SameTest -> SameQ,
    TestID   -> "LazyBuiltInSkills-ImportedSkills"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Tool*)
VerificationTest[
    $skillTool = Wolfram`Chatbook`Skills`Private`makeSkillTool @ { $testSkill, $sampleSkill },
    HoldPattern[ _LLMTool ],
    SameTest -> MatchQ,
    TestID   -> "SkillTool-Create"
]

VerificationTest[
    KeyTake[ $skillTool[ "Data" ], { "Name", "CanonicalName", "ShortName" } ],
    <| "Name" -> "activate_skill", "CanonicalName" -> "ActivateSkill", "ShortName" -> "skill" |>,
    SameTest -> SameQ,
    TestID   -> "SkillTool-Names"
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
    TestID   -> "SkillTool-Schema"
]

VerificationTest[
    activate // ClearAll;
    activate[ name_String ] := activate[ name, Missing[ "NoInput" ] ];
    activate[ name_String, path_ ] := $skillTool[ "Function" ][ <| "name" -> name, "path" -> path |> ];
    $sampleInstructions = activate[ "sample-skill" ],
    _String? (StringStartsQ[ "<skill_content name=\"sample-skill\">\n# Sample Skill\n" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillTool-Instructions"
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
    TestID   -> "SkillTool-Instructions-Content"
]

(* Optional parameters can arrive as Missing or empty strings, and SKILL.md can be requested explicitly: *)
VerificationTest[
    activate[ "sample-skill", # ] & /@ { "", "SKILL.md", "./SKILL.md", "skill.md", "." },
    ConstantArray[ $sampleInstructions, 5 ],
    SameTest -> SameQ,
    TestID   -> "SkillTool-Instructions-DefaultPath"
]

VerificationTest[
    activate[ "sample-skill", "references/guide.md" ],
    "<skill_file name=\"sample-skill\" path=\"references/guide.md\">\n# Guide\n\nThe guide code is 12345.\n</skill_file>",
    SameTest -> SameQ,
    TestID   -> "SkillTool-ReadFile"
]

VerificationTest[
    activate[ "sample-skill", # ] & /@ {
        "references\\guide.md",
        "./references/guide.md",
        FileNameJoin @ { $sampleSkillDir, "references", "guide.md" }
    },
    ConstantArray[ activate[ "sample-skill", "references/guide.md" ], 3 ],
    SameTest -> SameQ,
    TestID   -> "SkillTool-ReadFile-PathForms"
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
    TestID   -> "SkillTool-ReadFile-InvalidPaths"
]

VerificationTest[
    activate[ "sample-skill", "references/missing.md" ],
    KeyValuePattern @ {
        "Result" -> Failure[ "SkillFileNotFound", _ ],
        "String" -> _String? (StringContainsQ[ "Available files: data.bin, references/guide.md, scripts/run.wl" ])
    },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-ReadFile-NotFound"
]

VerificationTest[
    activate[ "sample-skill", "references" ],
    KeyValuePattern[ "Result" -> Failure[ "SkillPathIsDirectory", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "SkillTool-ReadFile-Directory"
]

VerificationTest[
    activate[ "sample-skill", "data.bin" ],
    KeyValuePattern[ "Result" -> Failure[ "SkillFileNotText", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "SkillTool-ReadFile-Binary"
]

VerificationTest[
    activate[ "does-not-exist" ],
    KeyValuePattern @ {
        "Result" -> Failure[ "SkillNotAvailable", _ ],
        "String" -> _String? (StringContainsQ[ "Available skills: test-skill, sample-skill" ])
    },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-SkillNotAvailable"
]

(* The built-in test skill can read its own reference file: *)
VerificationTest[
    activate[ "test-skill", "references/verification.md" ],
    _String? (StringContainsQ[ "SLATE-HERON-3908" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillTool-TestSkill-Reference"
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
    TestID   -> "SkillTool-NoDirectory"
]

(* Files can only be read from directories that contain a SKILL.md file: *)
VerificationTest[
    Wolfram`Chatbook`Skills`Private`skillDirectory /@ { File @ $tempRoot, File @ $sampleSkillDir, None },
    { _Missing, $sampleSkillDir, _Missing },
    SameTest -> MatchQ,
    TestID   -> "SkillTool-SkillDirectory"
]

(* Tool calls through LLMFunctions: *)
VerificationTest[
    GenerateLLMToolResponse[
        LLMConfiguration @ <| "Tools" -> { $skillTool } |>,
        LLMToolRequest[ "activate_skill", { "name" -> "test-skill" } ]
    ][ "Output" ],
    _String? (StringContainsQ[ "MAROON-ORCHID-7214" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillTool-GenerateLLMToolResponse"
]

VerificationTest[
    GenerateLLMToolResponse[
        LLMConfiguration @ <| "Tools" -> { $skillTool } |>,
        LLMToolRequest[ "activate_skill", { "name" -> "not-a-skill" } ]
    ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "SkillTool-GenerateLLMToolResponse-InvalidName"
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
    TestID   -> "SymbolicLinks-Setup"
]

(* Links are only listed if they point to a readable file in the skill, and linked directories are not followed: *)
VerificationTest[
    If[ $linksSupported, Wolfram`Chatbook`Skills`Private`skillResourceFiles @ $linkedSkillDir, Missing[ "TestSkipped" ] ],
    Missing[ "TestSkipped" ] | { "references/guide.md", "references/inside.md" },
    SameTest -> MatchQ,
    TestID   -> "SymbolicLinks-Listing"
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
    TestID   -> "SymbolicLinks-ReadInside"
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
    TestID   -> "SymbolicLinks-ReadOutside"
]

VerificationTest[
    If[ $linksSupported, readLinked[ "broken.md" ], Missing[ "TestSkipped" ] ],
    Missing[ "TestSkipped" ] | KeyValuePattern[ "Result" -> Failure[ "SkillFileNotFound", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "SymbolicLinks-BrokenLink"
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
    TestID   -> "SymbolicLinks-LinkedSkillDirectory"
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
    TestID   -> "SymbolicLinks-SkillFile"
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
    TestID   -> "SkillsPrompt"
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
    TestID   -> "SkillsPrompt-Content"
]

VerificationTest[
    Wolfram`Chatbook`Common`getSkillsPrompt @ <| "ToolsEnabled" -> True, "ToolMethod" -> "Simple", "Skills" -> { $testSkill } |>,
    _String? (StringContainsQ[ "call the /skill tool" ]),
    SameTest -> MatchQ,
    TestID   -> "SkillsPrompt-SimpleToolMethod"
]

VerificationTest[
    Wolfram`Chatbook`Common`getSkillsPrompt /@ {
        <| "ToolsEnabled" -> True, "Skills" -> { } |>,
        <| "ToolsEnabled" -> False, "Skills" -> { $testSkill } |>,
        <| "Skills" -> Automatic |>
    },
    { _Missing, _Missing, _Missing },
    SameTest -> MatchQ,
    TestID   -> "SkillsPrompt-NoSkills"
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
    TestID   -> "SkillsPrompt-Escaping"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Settings*)
VerificationTest[
    Wolfram`Chatbook`Common`$defaultChatSettings[ "Skills" ],
    Automatic,
    SameTest -> SameQ,
    TestID   -> "ChatSettings-Default"
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
    TestID   -> "ChatSettings-ResolveSkills"
]

VerificationTest[
    Wolfram`Chatbook`Common`makeCurrentRole[ $skillSettings ][ "Content" ],
    _String? (StringContainsQ[ "<available_skills>" ]),
    SameTest -> MatchQ,
    TestID   -> "ChatSettings-SystemPrompt"
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
    TestID   -> "ChatSettings-NoSkills"
]

(* The skill tool works with the "Simple" tool method, so it should not change the automatic choice of tool method: *)
VerificationTest[
    Wolfram`Chatbook`Common`skillToolQ /@ { $skillTool, First @ $DefaultTools, "ActivateSkill" },
    { True, False, False },
    SameTest -> SameQ,
    TestID   -> "ChatSettings-SkillToolQ"
]

VerificationTest[
    Wolfram`Chatbook`Settings`Private`simpleToolQ @ $skillTool,
    True,
    SameTest -> SameQ,
    TestID   -> "ChatSettings-SimpleToolQ"
]

VerificationTest[
    Wolfram`Chatbook`Settings`Private`chooseToolMethod /@ {
        <| "Tools" -> Values @ $DefaultTools |>,
        <| "Tools" -> Append[ Values @ $DefaultTools, $skillTool ] |>,
        <| "Tools" -> { $skillTool, LLMTool[ { "custom_tool", "A custom tool." }, { "x" -> "String" }, # & ] } |>
    },
    { "Simple", "Simple", Automatic },
    SameTest -> SameQ,
    TestID   -> "ChatSettings-ChooseToolMethod"
]

VerificationTest[
    $skillSettings[ "ToolMethod" ],
    $defaultSettings[ "ToolMethod" ],
    SameTest -> SameQ,
    TestID   -> "ChatSettings-ToolMethod"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Simple Tool Method*)
VerificationTest[
    Wolfram`Chatbook`Tools`Private`simpleToolSchema @ $skillTool,
    _String? (StringStartsQ[ "Activate Skill (/skill)\n" ]),
    SameTest -> MatchQ,
    TestID   -> "SimpleToolMethod-Schema"
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
    TestID   -> "SimpleToolMethod-Instructions"
]

VerificationTest[
    simpleSkillToolCall /@ {
        "/skill\ntest-skill\nreferences/verification.md\n",
        "/skill\nname: test-skill\npath: references/verification.md\n"
    },
    { _String? (StringContainsQ[ "SLATE-HERON-3908" ]).. },
    SameTest -> MatchQ,
    TestID   -> "SimpleToolMethod-ReadFile"
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
    TestID   -> "GenerateLLMConfiguration-Skills"
]

VerificationTest[
    MemberQ[ #[ "Data" ][ "CanonicalName" ] & /@ $config[ "Tools" ], "ActivateSkill" ],
    True,
    SameTest -> SameQ,
    TestID   -> "GenerateLLMConfiguration-Skills-Tool"
]

VerificationTest[
    StringContainsQ[ StringJoin @ Select[ $config[ "Prompts" ], StringQ ], "<name>test-skill</name>" ],
    True,
    SameTest -> SameQ,
    TestID   -> "GenerateLLMConfiguration-Skills-Prompt"
]

VerificationTest[
    MemberQ[ #[ "Data" ][ "CanonicalName" ] & /@ GenerateLLMConfiguration[ "NotebookAssistant" ][ "Tools" ], "ActivateSkill" ],
    False,
    SameTest -> SameQ,
    TestID   -> "GenerateLLMConfiguration-NoSkills"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteDirectory[ $tempRoot, DeleteContents -> True ],
    Null,
    SameTest -> SameQ,
    TestID   -> "Cleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
