# Building a Paclet from Scratch

A paclet is the standard way to distribute Wolfram Language code. This guide covers the directory layout, the `PacletInfo.wl` file, writing the package code, testing, and building a `.paclet` archive.

## Directory layout

A minimal paclet looks like this:

```text
MyTools/
├── PacletInfo.wl
├── Kernel/
│   ├── MyTools.wl
│   └── Utilities.wl
├── Documentation/
│   └── English/
└── Tests/
    └── MyTools.wlt
```

The name of the top-level directory doesn't matter, but by convention it matches the paclet name.

## The PacletInfo.wl file

`PacletInfo.wl` describes the paclet. The most important fields are `Name`, `Version`, and the `Extensions`:

```wl
PacletObject[
  <|
    "Name" -> "YourName/MyTools",
    "Description" -> "Utilities for working with strings and files",
    "Creator" -> "Your Name",
    "Version" -> "1.0.0",
    "WolframVersion" -> "13.3+",
    "PublisherID" -> "YourName",
    "License" -> "MIT",
    "Extensions" -> {
      {"Kernel", "Root" -> "Kernel", "Context" -> "YourName`MyTools`"},
      {"Documentation", "Language" -> "English"}
    }
  |>
]
```

A few things to keep in mind:

* The `"Name"` should include your publisher ID (e.g. `"YourName/MyTools"`) if you plan to submit it to the [Wolfram Language Paclet Repository](https://resources.wolframcloud.com/PacletRepository/).
* `"Version"` must follow the `major.minor.patch` format.
* The `"Context"` in the `"Kernel"` extension determines what `Needs` loads.

## Writing the package code

The main file in `Kernel/MyTools.wl` declares the public symbols and loads the implementation:

```wl
BeginPackage["YourName`MyTools`"];

SlugifyString::usage = "SlugifyString[str] converts str into a URL-friendly slug.";
FileSizeSummary::usage = "FileSizeSummary[dir] gives the total size of files in dir, grouped by extension.";

Begin["`Private`"];

SlugifyString[str_String] :=
  StringTrim[
    StringReplace[
      ToLowerCase @ RemoveDiacritics[str],
      {Except[WordCharacter] .. -> "-"}
    ],
    "-"
  ];

FileSizeSummary[dir_?DirectoryQ] :=
  Module[{files},
    files = FileNames["*", dir, Infinity];
    files = Select[files, FileType[#] === File &];
    ReverseSort @ GroupBy[files, FileExtension -> FileByteCount, Total]
  ];

End[];

EndPackage[];
```

Some conventions that make packages easier to maintain:

1. Put **usage messages** for every public symbol at the top, before `Begin["`Private`"]`.
2. Keep implementation details in the `` `Private` `` context so they don't pollute the user's namespace.
3. Use argument patterns like `str_String` and `dir_?DirectoryQ` so that bad input stays unevaluated instead of producing confusing errors.
4. Avoid global variables. If you need a cache, give it a clearly private name like `$slugCache`.

### Splitting code across files

For larger paclets, split the implementation into multiple files and load them from the main file:

```wl
(* In Kernel/MyTools.wl, after Begin["`Private`"] *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "Utilities.wl"}]];
```

Each file should use the same `` YourName`MyTools`Private` `` context, or you can create subcontexts like `` YourName`MyTools`Utilities` ``.

## Loading during development

While you're developing, load the paclet directly from its directory so that you don't need to rebuild it after every change:

```wl
PacletDirectoryLoad["/path/to/MyTools"];
Needs["YourName`MyTools`"]
```

After editing the source, reload it with `Get["YourName`MyTools`"]`. Note that `Needs` won't reload a package that's already loaded.

## Testing

Write tests in `.wlt` files using [`VerificationTest`](paclet:ref/VerificationTest):

```wl
VerificationTest[
  SlugifyString["Hello, World!"],
  "hello-world",
  TestID -> "Slugify-Basic"
]

VerificationTest[
  SlugifyString["Crème brûlée"],
  "creme-brulee",
  TestID -> "Slugify-Diacritics"
]

VerificationTest[
  SlugifyString[123],
  SlugifyString[123],
  TestID -> "Slugify-BadInput"
]
```

Then run them with [`TestReport`](paclet:ref/TestReport):

```wl
In[1]:= report = TestReport["/path/to/MyTools/Tests/MyTools.wlt"]

Out[1]= TestReportObject[<|"Title" -> "Test Report: MyTools.wlt", "TestsSucceededCount" -> 3, "TestsFailedCount" -> 0|>]

In[2]:= report["TestsFailedCount"]

Out[2]= 0
```

You can also run tests from the command line, which is useful in CI:

```bash
wolframscript -code 'TestReport["Tests/MyTools.wlt"]["AllTestsSucceeded"]'
```

## Building the paclet

To create a `.paclet` archive, use [`CreatePacletArchive`](paclet:ref/CreatePacletArchive):

```wl
CreatePacletArchive["/path/to/MyTools", "/path/to/build"]
```

For paclets that you plan to submit, the [PacletCICD](https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/PacletCICD/) paclet provides `CheckPaclet`, `BuildPaclet`, and `SubmitPaclet`, and can also set up GitHub Actions workflows for you:

```wl
PacletInstall["Wolfram/PacletCICD"];
Needs["Wolfram`PacletCICD`"];
CheckPaclet["/path/to/MyTools"]
```

Typical output from `CheckPaclet` lists any problems it finds:

| Level | Tag | Message |
|:------|:----|:--------|
| Error | `PacletFileNotFound` | The file `Documentation/English/Guides/MyTools.nb` was not found |
| Warning | `MissingDescription` | No description specified |
| Suggestion | `PacletIcon` | Consider adding an icon |

## Versioning

Follow [semantic versioning](https://semver.org/):

- **Major** version: incompatible API changes
- **Minor** version: new functionality that's backward compatible
- **Patch** version: backward-compatible bug fixes

Bump the version in `PacletInfo.wl` before each release, and don't reuse version numbers. If you install a new build with the same version number, `PacletInstall` will refuse with a `PacletInstall::samevers` message unless you pass `ForceVersionInstall -> True`.

## Common problems

> **"Needs: Context YourName`MyTools` was not created when Needs was evaluated."**
>
> This usually means the context in `BeginPackage` doesn't match the `"Context"` in `PacletInfo.wl`. Check for typos and missing backticks.

Another frequent issue is symbols that end up in the `Global` context because they were mentioned before the package was loaded. If you see `General::shdw` messages, run `Remove["Global`SlugifyString"]` and reload the package.

---

Once the paclet is working locally, you can publish it with `SubmitPaclet` or share the `.paclet` file directly. Let me know if you'd like an example of a documentation notebook or a GitHub Actions workflow for automated testing.
