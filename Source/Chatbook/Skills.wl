(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Skills`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

HoldComplete[
    System`LLMSkill;
    System`LLMTool;
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$skillFileName         = "SKILL.md";
$skillToolName         = "ActivateSkill";
$skillToolMachineName  = "activate_skill";
$skillToolShortName    = "skill";
$maxSkillResources     = 50;
$maxSkillResourceDepth = 5;
$maxSkillFileBytes     = 2^22;
$maxSkillFileLength    = 2^16;

(* Built-in skills that are only used when requested by name or with "Skills" -> All: *)
$optInSkills = { "test-skill" };

(* Directories that are never listed or read from skills (in addition to hidden files): *)
$ignoredSkillFileNames = { "__pycache__", "node_modules" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Patterns*)
$$llmSkill = HoldPattern[ LLMSkill[ _Association? AssociationQ, ___ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
Chatbook::SkillNotFound             = "Skill `1` not found.";
Chatbook::InvalidSkillSpecification = "Expected a skill name or an LLMSkill object instead of `1`.";

$skillFailureTemplates = <|
    "InvalidSkillPath"     -> "Invalid path \"`2`\" for the skill \"`1`\". Paths must be relative to the skill directory and cannot refer to parent directories or hidden files.",
    "MissingSkillFile"     -> "The skill file `1` does not exist.",
    "SkillFileNotFound"    -> "The file \"`2`\" does not exist in the skill \"`1`\". Available files: `3`.",
    "SkillFileNotText"     -> "The file \"`2`\" in the skill \"`1`\" is not a text file. Only text files can be read.",
    "SkillFileTooLarge"    -> "The file \"`2`\" in the skill \"`1`\" is too large to read (`3` bytes).",
    "SkillFileUnreadable"  -> "The file \"`2`\" in the skill \"`1`\" could not be read.",
    "SkillHasNoDirectory"  -> "The skill \"`1`\" does not have a directory, so only its instructions can be read. Omit the path parameter to read them.",
    "SkillNotAvailable"    -> "The skill \"`1`\" is not available. Available skills: `2`.",
    "SkillPathIsDirectory" -> "The path \"`2`\" is a directory in the skill \"`1`\", not a file. Available files: `3`."
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompts*)
$skillsPromptTemplate = StringTemplate[ "\
# Skills

Skills provide specialized instructions and workflows for specific tasks. \
When a task matches a skill's description, call the %%Tool%% tool with the skill's name to load its full instructions \
before proceeding. \
If the instructions refer to other files in the skill (such as `references/REFERENCE.md`), call the %%Tool%% tool again \
with the file's relative path to read them.

<available_skills>
%%Skills%%
</available_skills>",
Delimiters -> "%%"
];


$skillToolDescription = "\
Load the full instructions for one of the available skills listed in the system prompt, or read a file bundled with a \
skill. Call this when the task at hand matches a skill's description, before proceeding with the task. \
Skill instructions may refer to other files in the skill's directory (such as references or templates). \
To read one, call this tool again with the same skill name and the file's relative path.";


$skillPathHelp = "\
Path of a file to read, relative to the skill's directory (e.g. references/REFERENCE.md). \
Omit this to read SKILL.md, which contains the skill's main instructions.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Built-in Skills*)
$DefaultSkills := getBuiltInSkills[ ];

$builtInSkillsDirectory := $thisPaclet[ "AssetLocation", "Skills" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getBuiltInSkills*)
getBuiltInSkills // beginDefinition;

getBuiltInSkills[ ] := getBuiltInSkills @ $builtInSkillsDirectory;

getBuiltInSkills[ dir_String? DirectoryQ ] := Association @ Cases[
    importSkill /@ FileNames[ $skillFileName, dir, { 2 } ],
    skill: $$llmSkill :> skillName @ skill -> skill
];

getBuiltInSkills[ _ ] := <| |>;

getBuiltInSkills // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Loading Skills*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*importSkill*)
importSkill // beginDefinition;

importSkill[ File[ path_String ] ] := importSkill @ path;

importSkill[ dir_String ] /; DirectoryQ @ dir := importSkill @ FileNameJoin @ { dir, $skillFileName };

importSkill[ file_String ] := importSkill[ ExpandFileName @ file, Quiet @ FileDate[ file, "Modification" ] ];

(* Parsed skills are cached until the file is modified: *)
importSkill[ file_String, date_DateObject ] := importSkill[ file, date ] = importSkill0 @ file;

importSkill[ file_String, _ ] := skillFailure[ "MissingSkillFile", file ];

importSkill // endDefinition;


importSkill0 // beginDefinition;

importSkill0[ file_String ] := Enclose[
    Catch @ Module[ { text, parsed },
        text = readSkillText @ file;
        If[ ! StringQ @ text, Throw @ invalidSkillFailure[ file, "the file could not be read as UTF-8 text" ] ];
        parsed = ConfirmMatch[ parseSkillMarkdown[ text, file ], _Association | _Failure, "Parsed" ];
        If[ FailureQ @ parsed, Throw @ parsed ];
        ConfirmMatch[ makeSkill[ parsed, file ], $$llmSkill | _Failure, "Skill" ]
    ],
    throwInternalFailure
];

importSkill0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parseSkillMarkdown*)
(* Splits the contents of a SKILL.md file into its YAML frontmatter and markdown body. *)
parseSkillMarkdown // beginDefinition;

parseSkillMarkdown[ text_String ] := parseSkillMarkdown[ text, None ];

parseSkillMarkdown[ text_String, source_ ] := Enclose[
    Catch @ Module[ { lines, close, frontmatter, body },

        lines = StringSplit[ normalizeSkillText @ text, "\n", All ];

        If[ StringTrim @ First[ lines, "" ] =!= "---",
            Throw @ invalidSkillFailure[ source, "missing YAML frontmatter delimited by ---" ]
        ];

        close = FirstPosition[ Rest @ lines, _String? (StringTrim[ # ] === "---" &), Missing[ ], { 1 }, Heads -> False ];
        If[ MissingQ @ close, Throw @ invalidSkillFailure[ source, "missing closing --- for the YAML frontmatter" ] ];
        close = ConfirmBy[ First @ close + 1, IntegerQ, "Close" ];

        frontmatter = parseSkillFrontmatter @ StringRiffle[ lines[[ 2 ;; close - 1 ]], "\n" ];
        If[ ! AssociationQ @ frontmatter, Throw @ invalidSkillFailure[ source, "the YAML frontmatter could not be parsed" ] ];

        body = StringTrim @ StringRiffle[ lines[[ close + 1 ;; ]], "\n" ];

        <| "Frontmatter" -> frontmatter, "Body" -> body |>
    ],
    throwInternalFailure
];

parseSkillMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseSkillFrontmatter*)
parseSkillFrontmatter // beginDefinition;

parseSkillFrontmatter[ yaml_String ] := parseSkillFrontmatter[ yaml, importYAML @ yaml ];

parseSkillFrontmatter[ yaml_, data_? AssociationQ ] := data;

(* Skills written for other clients often contain values with unquoted colons, which are invalid YAML: *)
parseSkillFrontmatter[ yaml_, _ ] := Replace[ importYAML @ repairYAML @ yaml, Except[ _? AssociationQ ] -> $Failed ];

parseSkillFrontmatter // endDefinition;


importYAML // beginDefinition;
importYAML[ yaml_String ] := Quiet @ ImportString[ yaml, "YAML" ];
importYAML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*repairYAML*)
(* Converts top-level values that contain unquoted colons (e.g. "description: Use when: ...") to block scalars. *)
repairYAML // beginDefinition;

repairYAML[ yaml_String ] := StringReplace[
    yaml,
    StartOfLine ~~ key: (WordCharacter|"-").. ~~ ":" ~~ (" "|"\t").. ~~ value: Except[ "\n" ].. /;
        unquotedColonValueQ @ value :>
            key <> ": |-\n  " <> StringTrim @ value
];

repairYAML // endDefinition;


unquotedColonValueQ // beginDefinition;

unquotedColonValueQ[ value_String ] :=
    With[ { v = StringTrim @ value },
        StringContainsQ[ v, ":" ~~ (" "|"\t"|EndOfString) ] && ! StringStartsQ[ v, "\""|"'"|"|"|">"|"["|"{" ]
    ];

unquotedColonValueQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSkill*)
makeSkill // beginDefinition;

makeSkill[ KeyValuePattern @ { "Frontmatter" -> frontmatter_Association, "Body" -> body_String }, file_String ] :=
    makeSkill[ frontmatter, body, file ];

makeSkill[ frontmatter_Association, body_String, file_String ] := Enclose[
    Catch @ Module[ { dir, name, description, data },

        dir = ConfirmBy[ FileNameDrop[ file, -1 ], StringQ, "Directory" ];

        (* The name falls back to the directory name, but a description is required for the model to use the skill: *)
        name        = nonEmptyString[ frontmatterString @ Lookup[ frontmatter, "name" ], FileNameTake @ dir ];
        description = nonEmptyString[ frontmatterString @ Lookup[ frontmatter, "description" ], Missing[ ] ];

        If[ ! StringQ @ name, Throw @ invalidSkillFailure[ file, "the frontmatter does not specify a name" ] ];
        If[ ! StringQ @ description, Throw @ invalidSkillFailure[ file, "the frontmatter does not specify a description" ] ];

        data = DeleteMissing @ <|
            "Name"             -> name,
            "Description"      -> description,
            "Location"         -> File @ dir,
            "Body"             -> body,
            "License"          -> frontmatterString @ Lookup[ frontmatter, "license", Missing[ ] ],
            "Compatibility"    -> frontmatterString @ Lookup[ frontmatter, "compatibility", Missing[ ] ],
            "Metadata"         -> Replace[ Lookup[ frontmatter, "metadata", Missing[ ] ], Except[ _Association ] -> Missing[ ] ],
            "AllowedTools"     -> frontmatterString @ Lookup[ frontmatter, "allowed-tools", Missing[ ] ],
            "Options"          -> { },
            "LLMPacletVersion" -> $llmFunctionsVersion
        |>;

        constructSkill @ data
    ],
    throwInternalFailure
];

makeSkill // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*frontmatterString*)
frontmatterString // beginDefinition;
frontmatterString[ string_String ] := StringTrim @ StringReplace[ string, WhitespaceCharacter.. -> " " ];
frontmatterString[ number: _Integer|_Real ] := TextString @ number;
frontmatterString[ _ ] := Missing[ "NotAvailable" ];
frontmatterString // endDefinition;


nonEmptyString // beginDefinition;
nonEmptyString[ string_String, default_ ] /; StringLength @ string > 0 := string;
nonEmptyString[ _, default_ ] := default;
nonEmptyString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*constructSkill*)
constructSkill // beginDefinition;

(* LLMSkill validates the data when it's defined by LLMFunctions, otherwise the expression is inert: *)
constructSkill[ data_Association ] := constructSkill[ data, Quiet @ LLMSkill @ data ];
constructSkill[ data_, skill: $$llmSkill ] := skill;
constructSkill[ data_, _ ] := invalidSkillFailure[ data[ "Location" ], "LLMSkill rejected the skill data" ];

constructSkill // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$llmFunctionsVersion*)
$llmFunctionsVersion := Replace[
    Quiet @ PacletObject[ "Wolfram/LLMFunctions" ][ "Version" ],
    Except[ _String ] -> "0.0.0"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*invalidSkillFailure*)
invalidSkillFailure // beginDefinition;

invalidSkillFailure[ None, reason_String ] :=
    Failure[ "InvalidSkill", <| "MessageTemplate" -> "Invalid skill: `1`.", "MessageParameters" -> { reason } |> ];

invalidSkillFailure[ source_, reason_String ] := Failure[
    "InvalidSkill",
    <|
        "MessageTemplate"   -> "Invalid skill `1`: `2`.",
        "MessageParameters" -> { source, reason },
        "Source"            -> source
    |>
];

invalidSkillFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Reading Skill Files*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readSkillText*)
(* Reads a file as UTF-8 text, giving Missing[...] for binary, oversized, or unreadable files. *)
readSkillText // beginDefinition;

readSkillText[ file_String ] := readSkillText[ file, Quiet @ FileByteCount @ file ];
readSkillText[ file_String, size_Integer ] /; size > $maxSkillFileBytes := Missing[ "TooLarge", size ];
readSkillText[ file_String, 0 ] := "";
readSkillText[ file_String, _Integer ] := decodeSkillText @ Quiet @ ReadByteArray @ file;
readSkillText[ file_String, _ ] := Missing[ "Unreadable" ];

readSkillText // endDefinition;


decodeSkillText // beginDefinition;

decodeSkillText[ bytes_ByteArray ] :=
    If[ binaryBytesQ @ bytes,
        Missing[ "NotText" ],
        Replace[
            Quiet @ Check[ ByteArrayToString[ bytes, "UTF-8" ], $Failed ],
            { text_String :> normalizeSkillText @ text, _ :> Missing[ "NotText" ] }
        ]
    ];

decodeSkillText[ EndOfFile ] := "";
decodeSkillText[ _ ] := Missing[ "Unreadable" ];

decodeSkillText // endDefinition;


(* Treat files with null bytes near the beginning as binary: *)
binaryBytesQ // beginDefinition;
binaryBytesQ[ bytes_ByteArray ] := MemberQ[ Normal @ Take[ bytes, UpTo[ 8000 ] ], 0 ];
binaryBytesQ // endDefinition;


normalizeSkillText // beginDefinition;

normalizeSkillText[ text_String ] :=
    StringReplace[ StringDelete[ text, StartOfString ~~ "\:feff" ], { "\r\n" -> "\n", "\r" -> "\n" } ];

normalizeSkillText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Properties*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillData*)
skillData // beginDefinition;
skillData[ HoldPattern @ LLMSkill[ as_Association? AssociationQ, ___ ] ] := as;
skillData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillName*)
skillName // beginDefinition;
skillName[ skill: $$llmSkill ] := Replace[ Lookup[ skillData @ skill, "Name" ], Except[ _String ] -> Missing[ "NotAvailable" ] ];
skillName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillDescription*)
skillDescription // beginDefinition;

skillDescription[ skill: $$llmSkill ] := Replace[
    Lookup[ skillData @ skill, "Description" ],
    { s_String :> frontmatterString @ s, _ :> "" }
];

skillDescription // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillDirectory*)
(* Resources can only be read from a skill whose location is a directory that contains a SKILL.md file. *)
skillDirectory // beginDefinition;

skillDirectory[ skill: $$llmSkill ] := skillDirectory @ Lookup[ skillData @ skill, "Location" ];
skillDirectory[ File[ path_String ] ] := skillDirectory @ path;

skillDirectory[ path_String ] :=
    With[ { dir = If[ FileNameTake @ path === $skillFileName, FileNameDrop[ path, -1 ], path ] },
        If[ FileExistsQ @ FileNameJoin @ { dir, $skillFileName },
            StringDelete[ ExpandFileName @ dir, ("/"|"\\").. ~~ EndOfString ],
            Missing[ "NotAvailable" ]
        ]
    ];

skillDirectory[ _ ] := Missing[ "NotAvailable" ];

skillDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillResourceFiles*)
(* Lists the files bundled with a skill as relative paths, skipping SKILL.md itself and hidden files. *)
skillResourceFiles // beginDefinition;

skillResourceFiles[ dir_String ] :=
    Sort @ DeleteCases[ Flatten @ listSkillFiles[ dir, "", 1 ], $skillFileName ];

skillResourceFiles // endDefinition;


listSkillFiles // beginDefinition;

listSkillFiles[ dir_String, prefix_String, depth_Integer ] /; depth > $maxSkillResourceDepth := { };

listSkillFiles[ dir_String, prefix_String, depth_Integer ] := Map[
    Function[
        path,
        With[ { name = FileNameTake @ path },
            Which[
                ignoredSkillFileNameQ @ name, Nothing,
                DirectoryQ @ path, listSkillFiles[ path, prefix <> name <> "/", depth + 1 ],
                True, prefix <> name
            ]
        ]
    ],
    FileNames[ All, dir ]
];

listSkillFiles // endDefinition;


ignoredSkillFileNameQ // beginDefinition;
ignoredSkillFileNameQ[ name_String ] := StringStartsQ[ name, "." ] || MemberQ[ $ignoredSkillFileNames, name ];
ignoredSkillFileNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Settings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveSkills*)
(* Resolves the "Skills" setting to a list of LLMSkill objects. *)
resolveSkills // beginDefinition;

resolveSkills[ settings: KeyValuePattern[ "ToolsEnabled" -> True ] ] := Enclose[
    <|
        settings,
        "Skills" -> ConfirmMatch[ getSkills @ Lookup[ settings, "Skills", Automatic ], { $$llmSkill... }, "Skills" ]
    |>,
    throwInternalFailure
];

(* Skills can only be activated with a tool call: *)
resolveSkills[ settings_Association ] := <| settings, "Skills" -> { } |>;

resolveSkills // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSkills*)
getSkills // beginDefinition;
getSkills[ spec_ ] := getSkills[ spec, $DefaultSkills ];
getSkills[ spec_, builtIn_Association ] := Values @ Association @ toSkillRules[ spec, builtIn ];
getSkills // endDefinition;


toSkillRules // beginDefinition;
toSkillRules[ None, builtIn_ ] := { };
toSkillRules[ Automatic|Inherited|ParentList, builtIn_ ] := Normal[ KeyDrop[ builtIn, $optInSkills ], Association ];
toSkillRules[ All, builtIn_ ] := Normal[ builtIn, Association ];
toSkillRules[ specs_List, builtIn_ ] := Flatten[ toSkillRules[ #, builtIn ] & /@ specs ];
toSkillRules[ skill: $$llmSkill, builtIn_ ] := skillRule[ skillName @ skill, skill ];
toSkillRules[ name_String, builtIn_ ] := skillRule[ name, Lookup[ builtIn, name, Missing[ "NotFound" ] ] ];
toSkillRules[ other_, builtIn_ ] := (messagePrint[ "InvalidSkillSpecification", other ]; { });
toSkillRules // endDefinition;


skillRule // beginDefinition;
skillRule[ name_String, skill: $$llmSkill ] /; StringQ @ Lookup[ skillData @ skill, "Body" ] := { name -> skill };
skillRule[ name_String, Missing[ "NotFound" ] ] := (messagePrint[ "SkillNotFound", name ]; { });
skillRule[ _, skill_ ] := (messagePrint[ "InvalidSkillSpecification", skill ]; { });
skillRule // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectSkillTool*)
(* Adds the skill activation tool to the selected tools when skills are available, and removes it otherwise. *)
selectSkillTool // beginDefinition;

selectSkillTool[ settings_Association ] :=
    selectSkillTool @ Cases[ Flatten @ { Lookup[ settings, "Skills", { } ] }, $$llmSkill ];

selectSkillTool[ { } ] :=
    KeyDropFrom[ $selectedTools, $skillToolName ];

selectSkillTool[ skills: { __ } ] :=
    $selectedTools[ $skillToolName ] = makeSkillTool @ skills;

selectSkillTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skills Prompt*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSkillsPrompt*)
(* Lists the available skills in the system prompt so the model knows when to activate them. *)
getSkillsPrompt // beginDefinition;

getSkillsPrompt[ settings: KeyValuePattern @ { "ToolsEnabled" -> True, "Skills" -> skills_List } ] :=
    makeSkillsPrompt[ settings, Cases[ skills, $$llmSkill ] ];

getSkillsPrompt[ _Association ] :=
    Missing[ "NotAvailable" ];

getSkillsPrompt // endDefinition;


makeSkillsPrompt // beginDefinition;

makeSkillsPrompt[ settings_, { } ] :=
    Missing[ "NotAvailable" ];

makeSkillsPrompt[ settings_, skills: { __ } ] := TemplateApply[
    $skillsPromptTemplate,
    <|
        "Tool"   -> skillToolReference @ settings,
        "Skills" -> StringRiffle[ skillCatalogEntry /@ skills, "\n" ]
    |>
];

makeSkillsPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillCatalogEntry*)
skillCatalogEntry // beginDefinition;

skillCatalogEntry[ skill: $$llmSkill ] :=
    skillCatalogEntry[ skillName @ skill, skillDescription @ skill ];

skillCatalogEntry[ name_String, "" ] :=
    "  <skill>\n    <name>" <> escapeXML @ name <> "</name>\n  </skill>";

skillCatalogEntry[ name_String, description_String ] := StringJoin[
    "  <skill>\n    <name>",
    escapeXML @ name,
    "</name>\n    <description>",
    escapeXML @ description,
    "</description>\n  </skill>"
];

skillCatalogEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillToolReference*)
(* The name the model uses to call the skill tool depends on the tool calling method: *)
skillToolReference // beginDefinition;
skillToolReference[ KeyValuePattern[ "ToolMethod" -> "Simple" ] ] := "/" <> $skillToolShortName;
skillToolReference[ _ ] := $skillToolMachineName;
skillToolReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Skill Tool*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSkillTool*)
makeSkillTool // beginDefinition;

makeSkillTool[ skills: { $$llmSkill.. } ] := Enclose[
    Module[ { lookup, names },

        lookup = ConfirmBy[ Association[ skillName @ # -> # & /@ skills ], AssociationQ, "Lookup" ];
        names  = ConfirmMatch[ Keys @ lookup, { __String }, "Names" ];

        ConfirmMatch[
            LLMTool @ <|
                "Name"               -> $skillToolMachineName,
                "CanonicalName"      -> $skillToolName,
                "DisplayName"        -> "Activate Skill",
                "ShortName"          -> $skillToolShortName,
                "Description"        -> $skillToolDescription,
                "Function"           -> activateSkillFunction @ lookup,
                "FormattingFunction" -> toolAutoFormatter,
                "Origin"             -> "BuiltIn",
                "Parameters"         -> {
                    "name" -> <|
                        "Interpreter" -> names,
                        "Help"        -> "The name of the skill, exactly as it appears in the available skills.",
                        "Required"    -> True
                    |>,
                    "path" -> <|
                        "Interpreter" -> "String",
                        "Help"        -> $skillPathHelp,
                        "Required"    -> False
                    |>
                },
                "Options"            -> { },
                "LLMPacletVersion"   -> $llmFunctionsVersion
            |>,
            HoldPattern[ _LLMTool ],
            "Tool"
        ]
    ],
    throwInternalFailure
];

makeSkillTool // endDefinition;


activateSkillFunction // beginDefinition;
activateSkillFunction[ lookup_Association ] := Function[ params, activateSkill[ lookup, params ] ];
activateSkillFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillToolQ*)
skillToolQ // beginDefinition;
skillToolQ[ HoldPattern @ LLMTool[ as_Association? AssociationQ, ___ ] ] := Lookup[ as, "CanonicalName" ] === $skillToolName;
skillToolQ[ _ ] := False;
skillToolQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*activateSkill*)
activateSkill // beginDefinition;

activateSkill[ lookup_Association, params_Association ] :=
    activateSkill[ lookup, Lookup[ params, "name" ], Lookup[ params, "path", Missing[ ] ] ];

activateSkill[ lookup_Association, name_String, path_ ] /; KeyExistsQ[ lookup, name ] :=
    skillToolResult @ readSkillResource[ lookup[ name ], toSkillPath @ path ];

activateSkill[ lookup_Association, name_, path_ ] :=
    skillToolResult @ skillFailure[ "SkillNotAvailable", TextString @ name, StringRiffle[ Keys @ lookup, ", " ] ];

activateSkill // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toSkillPath*)
(* Optional parameters can arrive as Missing or empty strings when the LLM omits them. *)
toSkillPath // beginDefinition;
toSkillPath[ path_String ] := With[ { p = StringTrim @ path }, If[ p === "", $skillFileName, p ] ];
toSkillPath[ _ ] := $skillFileName;
toSkillPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillToolResult*)
skillToolResult // beginDefinition;
skillToolResult[ result_String ] := result;
skillToolResult[ failure_Failure ] := <| "Result" -> failure, "String" -> "Error: " <> ToString @ failure[ "Message" ] |>;
skillToolResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readSkillResource*)
readSkillResource // beginDefinition;

readSkillResource[ skill_, path_String ] :=
    readSkillResource[ skill, path, skillDirectory @ skill ];

(* Skills that were not loaded from a directory only have instructions: *)
readSkillResource[ skill_, path_String, _Missing ] :=
    If[ skillFileNameQ @ path,
        skillInstructions[ skill, Missing[ "NotAvailable" ] ],
        skillFailure[ "SkillHasNoDirectory", skillName @ skill ]
    ];

readSkillResource[ skill_, path_String, dir_String ] :=
    readSkillResource[ skill, path, dir, skillPathComponents[ dir, path ] ];

readSkillResource[ skill_, path_String, dir_String, $Failed ] :=
    skillFailure[ "InvalidSkillPath", skillName @ skill, path ];

readSkillResource[ skill_, path_String, dir_String, { } | { _String? skillFileNameQ } ] :=
    skillInstructions[ skill, dir ];

readSkillResource[ skill_, path_String, dir_String, parts: { __String } ] :=
    readSkillFile[ skill, dir, StringRiffle[ parts, "/" ], FileNameJoin @ Prepend[ parts, dir ] ];

readSkillResource // endDefinition;


skillFileNameQ // beginDefinition;
skillFileNameQ[ path_String ] := ToLowerCase @ StringDelete[ path, StartOfString ~~ "./" ] === ToLowerCase @ $skillFileName;
skillFileNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillPathComponents*)
(* Splits a path into components relative to the skill directory, giving $Failed for paths outside of it. *)
skillPathComponents // beginDefinition;

skillPathComponents[ dir_String, path0_String ] :=
    Module[ { root, path, parts },

        root = StringReplace[ dir, "\\" -> "/" ];
        path = StringReplace[ StringTrim @ path0, "\\" -> "/" ];

        (* Absolute paths are allowed when they point inside the skill directory: *)
        If[ StringStartsQ[ path, root <> "/" ], path = StringDrop[ path, StringLength @ root + 1 ] ];

        parts = DeleteCases[ StringSplit[ path, "/", All ], "." | "" ];

        Which[
            StringStartsQ[ path, "/" | "~" ] || StringMatchQ[ path, LetterCharacter ~~ ":" ~~ ___ ], $Failed,
            AnyTrue[ parts, StringStartsQ[ "." ] ], $Failed,
            True, parts
        ]
    ];

skillPathComponents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillInstructions*)
(* The body of SKILL.md without frontmatter, followed by the skill directory and a listing of bundled files. *)
skillInstructions // beginDefinition;

skillInstructions[ skill_, dir_ ] := Enclose[
    Module[ { name, body },
        name = ConfirmBy[ skillName @ skill, StringQ, "Name" ];
        body = ConfirmBy[ Lookup[ skillData @ skill, "Body" ], StringQ, "Body" ];
        StringJoin[
            "<skill_content name=\"", escapeXML @ name, "\">\n",
            StringTrim @ body,
            skillDirectoryInformation @ dir,
            "\n</skill_content>"
        ]
    ],
    throwInternalFailure
];

skillInstructions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillDirectoryInformation*)
skillDirectoryInformation // beginDefinition;

skillDirectoryInformation[ _Missing ] := "";

skillDirectoryInformation[ dir_String ] :=
    skillDirectoryInformation[ dir, skillResourceFiles @ dir ];

skillDirectoryInformation[ dir_String, { } ] := StringJoin[
    "\n\nSkill directory: ", dir,
    "\nRelative paths in this skill are relative to the skill directory."
];

skillDirectoryInformation[ dir_String, files: { __String } ] := StringJoin[
    "\n\nSkill directory: ", dir,
    "\nRelative paths in this skill are relative to the skill directory. ",
    "To read one of the files listed below, use this tool again with the file's relative path as the path parameter.",
    "\n\n<skill_resources>\n",
    StringRiffle[ "<file>" <> escapeXML[ # ] <> "</file>" & /@ Take[ files, UpTo[ $maxSkillResources ] ], "\n" ],
    If[ Length @ files > $maxSkillResources,
        "\n(" <> ToString[ Length @ files - $maxSkillResources ] <> " more files are not listed)",
        ""
    ],
    "\n</skill_resources>"
];

skillDirectoryInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readSkillFile*)
readSkillFile // beginDefinition;

readSkillFile[ skill_, dir_String, path_String, file_String ] := Which[
    DirectoryQ @ file,
        skillFailure[ "SkillPathIsDirectory", skillName @ skill, path, availableSkillFiles @ dir ],
    ! FileExistsQ @ file,
        skillFailure[ "SkillFileNotFound", skillName @ skill, path, availableSkillFiles @ dir ],
    True,
        skillFileContent[ skillName @ skill, path, readSkillText @ file ]
];

readSkillFile // endDefinition;


availableSkillFiles // beginDefinition;

availableSkillFiles[ dir_String ] :=
    Replace[ skillResourceFiles @ dir, { { } -> "none", files_ :> StringRiffle[ Take[ files, UpTo[ 20 ] ], ", " ] } ];

availableSkillFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*skillFileContent*)
skillFileContent // beginDefinition;

skillFileContent[ name_String, path_String, text0_String ] :=
    With[ { text = StringDelete[ text0, "\n".. ~~ EndOfString ] },
        StringJoin[
            "<skill_file name=\"", escapeXML @ name, "\" path=\"", escapeXML @ path, "\">\n",
            If[ StringLength @ text > $maxSkillFileLength,
                StringJoin[
                    StringTake[ text, $maxSkillFileLength ],
                    "\n\n[Content truncated: showing the first ",
                    ToString @ $maxSkillFileLength,
                    " of ",
                    ToString @ StringLength @ text,
                    " characters.]"
                ],
                text
            ],
            "\n</skill_file>"
        ]
    ];

skillFileContent[ name_, path_, Missing[ "NotText" ] ] := skillFailure[ "SkillFileNotText", name, path ];
skillFileContent[ name_, path_, Missing[ "TooLarge", size_ ] ] := skillFailure[ "SkillFileTooLarge", name, path, size ];
skillFileContent[ name_, path_, _Missing ] := skillFailure[ "SkillFileUnreadable", name, path ];

skillFileContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*skillFailure*)
skillFailure // beginDefinition;

skillFailure[ tag_String, params___ ] := Failure[
    tag,
    <| "MessageTemplate" -> $skillFailureTemplates[ tag ], "MessageParameters" -> { params } |>
];

skillFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*escapeXML*)
escapeXML // beginDefinition;
escapeXML[ string_String ] := StringReplace[ string, { "&" -> "&amp;", "<" -> "&lt;", ">" -> "&gt;", "\"" -> "&quot;" } ];
escapeXML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
