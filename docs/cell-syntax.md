# Cell Syntax

Chatbook shows notebook cells to an LLM, and reads cells back from an LLM, in one syntax: Markdown wherever Markdown can say it, and boxes inside XML tags where it cannot.

```
<cell id='c4' style='Input' CellLabel='In[1]:='>
Solve[<RawBoxes>SuperscriptBox["x", "2"]</RawBoxes> + a x + 1 == 0, x]
</cell>

<cell id='c6' style='Text'>
A [link](https://www.wolfram.com) in **bold** text with $$\lim_{x \to 2} f(x) = 5$$.
</cell>
```

## Who Calls It and What It Needs

| Function | File | Called by | Needs |
|---|---|---|---|
| `CellToString` with `"IncludeXML"` (cell tags) and `"PreserveBoxes"` (exact bodies) | `Serialization.wl` (the tag), `CellSyntax/ExactBodies.wl` (the bodies) | The notebook tools (`cellText`), the notebook context of a chat that has the tools (`withNotebookCellSyntax`), the assistant's warm-up (`initializeCellSyntax`) | No front end. Code needs CodeParser, which the first read loads (about 0.8 s from the MX build; the warm-up does it). |
| `cellsFromString` | `CellSyntax/CellsFromString.wl` | The notebook tools (WriteCells, EditInCell) | A front end for code, the chat formatter for a table, the TeX input assistant for a formula, the evaluator tool for `<MakeBoxes>` and `<ToBoxes>` |
| `evaluateToBoxes` | same | The notebook tools (`evaluate`) | The evaluator tool |

- The two files of `CellSyntax/` are loaded by `Serialization.wl` and share its private context.
- `"PreserveBoxes"` is `True`, `False` or `Automatic` (exact for all but generated cells: `Output`, `Print`, `Echo`, `Message`, `MSG` and chat outputs, which keep the lossy Markdown and its length limit). Without `"IncludeXML"` it gives exact bodies inside the decoration of the default Markdown, for reading only. The defaults of the two options are `$includeCellXML` and `$preserveCellBoxes`, which a caller sets for the code that it calls.
- What changes for chats without the notebook tools is listed in [notebook-tools.md](notebook-tools.md#what-changes-for-chats-without-the-tools).

## Guarantees and Known Gaps

Measured over 87 notebooks (20 sample notebooks and 67 documentation pages): 29,600 cells, of which 21,574 are not generated and 8,734 are `Input` or `Code` cells with boxes. [Tests](#tests) says how to run it again.

| Guarantee | Measured |
|---|---|
| Without the options, `CellToString` gives what it gave before | 0 differences in 29,600 cells against the previous version (also with length limits, with images, and for whole notebooks) |
| A body that is written back as it was read gives the identical cell, with or without what reading recorded | 21,574 of 21,574 cells, both ways |
| Code that is edited still parses, and what the edit left alone is read by the kernel as before | In this corpus no cell that parsed before parses no more; in another one, 1 of 8,459 cells does after a line is appended or when it is written as a new cell (see the known gaps). One identifier renamed: 8,360 cells are the cell with that change, and 9 are tokenized again and read as the same expression. One number changed: 5,452 and 9. A line appended: 8,703 read as before with the new statement, 27 as another expression. Written as a new cell: 5,750 identical, 2,859 the same expression, 24 another expression, 100 refused. |
| Nothing that a model writes runs code when the cell is shown, read or evaluated as data, beyond what it could run with the evaluator tool | [What Is Refused](#what-is-refused); `Tests/CellSyntax.wlt`, "What Is Refused" |

Known gaps:

- A model can't write a `TemplateBox`: not a quantity, not a template of the documentation. Only the ones that the notebook has are kept ([Originals](#originals)).
- With a sandboxed evaluator, typeset results with a `TemplateBox`, graphics or dynamic content are refused. With `"Method" -> "Session"` results are written unchecked, since the model's code runs in the user's kernel anyway.
- Data is evaluated once it has passed the rule, so an up-value of a ``System` `` symbol that it names runs. A value of the evaluator behind a URI is typeset in Chatbook's kernel.
- A hyperlink can have any address, also a `file:` URL or a local path.
- A table is made by the chat formatter and not by the writer's own rules, so some of what the writer reads elsewhere has no place in it: a URI, three backticks and an unreadable image link are refused in a table.
- Code that is tokenized again is not always read as before. The 27 cells that read differently with a line appended are `~~` chains that the notebook had nested, `??name`, and statements in one row (which the kernel read as a product). A fourth kind is an operator in a box of its own, found in another corpus (1 of 6,600 code cells with boxes): `Tutorials/ImageProcessing.nb` has a `;` as `StyleBox[";", FontSize -> 9]`, and with a line appended its `smiley = m;` reads as `smiley = (m;)`, which assigns `Null`. Of the 100 cells that can't be written as a new cell, 76 have a `TemplateBox`.
- Code whose tokens are each in a box of their own parses no more once it is tokenized again: in `Tutorials/NeuralNetworksAudioAnalysis.nb` (a corpus of 20 sample notebooks and about 80 other documentation pages, 8,459 code cells with boxes) one cell has every token in a `StyleBox[token, CellFrame -> True]`, so its brackets are single `<RawBoxes>` that the front end puts into a flat row. Written back unchanged, and with only names, numbers and strings changed, it is the cell that it was; with a line appended, or as a new cell, the kernel finds no opening bracket.
- Markdown as in a chat reply is not read: only cell tags are ([What Is Refused](#what-is-refused)).
- A `</cell>` that is content can't be written as it is, also not in a string or a comment of code, since the body ends there ([Writing](#writing)). It is written as the reader writes it: `&lt;/cell>` in text, and in code its token in `<RawBoxes>` with `\.3c` for the `<`. In a string of code `"</" <> "cell>"` also does.

## The Syntax

### The Cell Tag

| Attribute | Value |
|---|---|
| `id` | `c1`, `c2`, …: numbered in the order of one `CellToString` call. A caller that keeps ids across calls gives them with `$cellIDFunction`. |
| `style` | The cell's styles, joined with `, `. |
| `CellLabel` | The label, if it is a string. |
| `CellTags` | The tags, joined with `,`. |
| `options` | Every other option as `name -> value` in InputForm, joined with `, `. Left out: `ExpressionUUID`, `CellChangeTimes`, `CellID`, `GeneratedCell`, `CellAutoOverwrite`, `CellObject`, and any option longer than 200 characters. |
| `truncated` | `true` if the body was shortened to fit a length limit. An exact body is only shortened if the caller gives `"MaxCellStringLength"`. |

- The attributes are in this order, and one without a value is left out. Values are in single quotes, with `&amp;`, `&apos;`, `&lt;` and `&#10;` (a line break) for those characters.
- InputForm is on one line and in printable ASCII, here and in `<RawBoxes>`. A symbol outside of ``System` `` is written with its context.
- The opening tag is a line, the body follows, and `</cell>` is a line. Cells are separated by a blank line. No body has a cell tag or a `</cell>` in it: an exact body escapes every tag of this syntax that is text, and a lossy body escapes `<cell` and `</cell`.
- Selected cells are between a `<selection>` line and a `</selection>` line, outside of the cell tags. A selection inside a cell is `<selection>…</selection>` in its body (the caller gives the markers as `Verbatim["<selection>"]` items). The markers are not content: the writer takes them out, except in a string or a comment of code.

### The Body

The body is the cell's content alone. What the tag says is not repeated: a heading has no `##`, an item no `*`, code no fence and no `In[1]:=`, and a delimiter has an empty body.

| Content of the cell | Exact body |
|---|---|
| Boxes in a code cell (`Input`, `Code`, `Output`, `Print`, `Echo`, `Message`, `MSG`, `Program`, `ExternalLanguage`) | Code, see below, whatever the boxes are: input that was typed in `TraditionalForm` is one `<RawBoxes>`, not a formula |
| A string in a code cell | The string as it is, since `a*b*c` is not Markdown there |
| A string or `TextData` in another cell | Text, see below |
| Boxes in another cell (a `DisplayFormula`, a table) | What they would be as an inline cell in text |
| Anything else (`RawData`, …) | One `<RawBoxes>` |

**Code** is the tokens of the boxes, as they are: strings with their escapes, numbers with all their digits and marks, comments unchanged.

- Spacing is `CellToString`'s: one space on each side of an infix operator and one after a comma, none at the ends of a line, none after a prefix `-` or `+`. The cell's own spaces at those places are left out.
- Code with spacing of its own has exactly its own spaces: a `Code` cell (where the front end adds no spacing), and code that has a space token next to an infix operator or after a comma.
- Two tokens get a space if they would not read as the same two tokens without it (`a x`, `x_ .y`, `% 2`, `n! !`). CodeParser decides, on the two tokens written together.
- After a `\[IndentingNewLine]` the next line is indented by 4 spaces for each open bracket; after a `"\n"` the spaces are the cell's.
- Operator characters are ASCII: `->`, `:>`, `==`, `!=`, `<=`, `>=`, `|->`, `<->`, `[[`, `]]`, `<|`, `|>`. Other private use characters are long names (`\[ImaginaryI]`), also in strings and comments.
- Any other box is one `<RawBoxes>`. So is a token or a comment that code can't say: one with a tag or a URI of this syntax, a control character or linear syntax, and a comment with the text of a long name.

**Text** is Markdown for what Markdown can say, and `<RawBoxes>` for the rest:

| Content | Markdown |
|---|---|
| Plain text | As it is, with `\` before `\`, `` ` ``, `$`, `*`, `\|`, before a `_` at a word boundary, a `~` of two in a row and a `]` before `(`. `<` is `&lt;` where a tag of this syntax would start, and `&` is `&amp;` where an entity would. |
| Bold, italic, struck through | `**…**`, `*…*`, `~~…~~` and their combinations, for a `StyleBox` of a string with only those options |
| Links | `[label](url)` for every hyperlink form. The label keeps its spaces, and the address can hold parentheses in pairs. |
| Inline code | ``` ``code`` ``` for the inline code and inline formula styles, with nothing escaped |
| Math | `$$tex$$` for a `TraditionalForm` formula in an inline cell without a style: the LaTeX it was made from (without dollars of its own), or a conversion of boxes that are only layout |
| Tables | A Markdown table, for the table that the chat formatter makes, and for a `GridBox` whose entries are all plain text on one line in an inline cell without a style (with an empty header row if it has no headings) |

- A piece that its Markdown could not hold is `<RawBoxes>`: emphasis with a space at an end or next to a letter or a digit, a table that is not on lines of its own, a link with a bracket in its label, inline code with a double backtick, LaTeX with a dollar at an end. So is the part of a string with a control character or linear syntax.
- Adjacent strings are one text, and the `ExpressionUUID` of an inline cell is left out.
- A heading or an item whose text starts like its own marker (`## `, `- `, `1. `) has its first character as an entity (`&#45; dash`), since the writer drops such a marker.

### Boxes That Are Not `<RawBoxes>`

Boxes with graphics (`GraphicsBox`, `Graphics3DBox`, `RasterBox`, `Raster3DBox`) or something dynamic (`DynamicBox`, `DynamicModuleBox`, `DynamicWrapperBox`, `Dynamic`), and boxes over 2000 characters, are an expression URI (`Tools/ExpressionURIs.wl`):

- A graphic is `![Image](attachment://content-id)`, in the form that is made an image for multimodal chats. Other boxes have their head as the label (`![DynamicModuleBox](expression://content-id)`). In a cell tag the lossy body of a generated cell has the same link for each of its graphics, whatever `"ContentTypes"` is.
- `$attachments` holds the boxes themselves for the URI. They are stored as they are and never interpreted. The evaluator tool reads them as input in its own kernel.
- What exact reading adds to `$attachments` is bounded (`$notebookAttachments`): beyond 200 URIs or 2×10⁸ bytes the ones that were read longest ago are dropped. Reading a cell again brings its URIs back.

## Writing

`cellsFromString[text, "Cells" -> cells, "Originals" -> $cellOriginals, "ExtraAttributes" -> {names}]` gives a record for each cell tag, in the order of the text, or a `Failure` whose message tells the model what to fix:

```wl
<|"ID" -> id | None, "Cell" -> Cell[…] | Missing["Unchanged"], "Attributes" -> <|"Styles" -> {…}, "Options" -> {…}|>,
  "Extra" -> <|name -> value, …|>, "Tag" -> n|>
```

- `"Cells"` gives the existing cell of an id: an association, or a function that gives the `Cell` or a `Missing` and is asked once for a tag. A tag with an `id` replaces that cell, and one without is a new cell. An id is read as models write it: `C3`, `#c3`, `#3` and `3` are `c3`, in the record, for `"Cells"` and for the records of the cell.
- `"ExtraAttributes"` are attributes of the caller's own (the tools' `after`, `before`, `delete`). They are not read: `"Extra"` has the ones that the tag gives. `"Tag"` is the number of the cell tag in the text, by which a message names a new cell (`Cell tag 2 (a new cell)`).
- Attributes that are left out keep their values, an empty one removes its value, and `options` replaces the options that the tag shows. `<cell id='c3' CellTags='x'/>` changes attributes only (`"Cell"` is `Missing["Unchanged"]`).
- A cell tag is read wherever it starts outside of a body, so tags can follow one another on a line. A body ends at its first `</cell>`, wherever that is: in the middle of a line, in a string or a comment of code, inside of `<RawBoxes>`. A cell tag before it is content unless it starts a line: `<cell id='c1'>A <cell id='c2'>B</cell>` is c1 with the second tag in it. The names of tags are read without regard to case, a value can be in double quotes, and HTML entities are read in it.
- The kind of a body is the kind of the existing cell's content, unless the tag gives the cell a style of another kind; the kind of a new cell is that of its style. A body is read as an exact one, so a lossy body must not be written back.
- Nothing is written to a notebook, and no code of the text is run except in `<MakeBoxes>` and `<ToBoxes>`. A `Failure` with another tag than `"CellSyntax"` is an internal failure (no front end, a defect).

| Body | Content |
|---|---|
| What the reader writes for the cell | The content of the cell, unchanged, whatever it holds |
| Code with the tokens of the cell one for one, in which only names, numbers and strings differ | Those tokens are changed in the cell's content: every `RowBox` and every box stays |
| Other code | Tokenized again by the front end (`FrontEnd`ReparseBoxStructurePacket`). The grouping is then the front end's; operators are the characters (`\[Rule]`) only if the cell had no other form of them; the line break is the one the cell uses (`\[IndentingNewLine]` in a new cell, `"\n"` in a new `Code` cell); the spaces that the reader wrote are taken out, and in code with spacing of its own every typed space is kept. Lines outside of brackets are statements: `BoxData[{box, "\[IndentingNewLine]", box}]`, as the front end makes it of typed input. |
| Text | Plain text is read from left to right: `\` before one of ``\ ` $ * \| ] ~ _ #``, a long name, an HTML entity. Markdown: `**…**`, `*…*`, `~~…~~`, `__…__`, `_…_` (only where the markers are not inside of a word, so `2*3*4` is text), `[label](url)` and `![label](url)` (a link: nothing is fetched), ``` ``code`` ``` and `` `code` ``, `$$tex$$`, `\(tex\)` and `\[tex\]`, and a table (a header row with a row of dashes under it). A body is one cell: a `#` or a `-` at the start of a later line is text. |

- The boxes of tags and URIs are tokens of code. An operator with limits (`∫`, `∑`, `∂` in a script box) is that operator, so that it is grouped with its operand.
- An item of `TextData` is text: a string, an inline cell, or a `StyleBox` or a link that holds those. Other boxes go into an inline cell, since the front end corrupts a cell that has them directly in its text.
- The content of a text cell is a string, `TextData` of one item or `TextData` of a list, as the cell had it. A body that is one piece gives `BoxData` for a cell that had boxes, and for a new `DisplayFormula`, `DisplayFormulaNumbered` or `Picture` cell.

| Tag in a body | Meaning |
|---|---|
| `<RawBoxes>boxes</RawBoxes>` | The boxes as they are |
| `![label](uri)`, `<!uri!>` | The boxes that the URI was read from, into any cell. Any other URI is a value of the evaluator, which is typeset in Chatbook's kernel. |
| `<MakeBoxes>expr</MakeBoxes>`, `<ToBoxes>expr</ToBoxes>` | The boxes of the expression, unevaluated or evaluated, typeset in the kernel of the WolframLanguageEvaluator tool (30 seconds each, in the order of the text; `form='TraditionalForm'`). Without the tool they are refused. A tag has run when something after it in the text is refused. |

## What Is Refused

What a model writes is checked by two rules, and everything that is made of its text is checked after it is made. The user's own content is not checked ([Originals](#originals)). A refusal is `Failure["CellSyntax", <|"MessageTemplate" -> …, "MessageParameters" -> {…}|>]`; `TemplateApply` of the two gives the message, which names the cell and says what to write instead.

| Written | Refused |
|---|---|
| Any text: a body, a new `CellLabel`, `CellTags` or `style`, the strings of what is made | Control characters (all but tab and line feed), and linear syntax: its characters and the opener `\!\(`, and in code and boxes also `\*` and the escapes of its characters (`\:f7c1`). A `\!` alone is text. (`requireInertText`) |
| Data: `<RawBoxes>`, new `options`, and the results of a sandboxed evaluator | Anything but boxes and plain data, decided on the held expression before it is evaluated (`dataQ`). Heads are from a list: boxes that typeset, lists, rules, associations, colors, `Directive`, `URL`, `Cell`, `BoxData`, `TextData`, `Scaled`, `Offset`, and arithmetic on numbers and `Inherited`. Symbols are ``System` `` symbols that evaluate to themselves or to plain data (`Center`, `Red`, `Infinity`): no `$` variable, no `Now`. Not data: a `TemplateBox` (it does what its stylesheet style says; [Originals](#originals) has the one exception), a dynamic box, graphics, an option that holds code (`ButtonFunction`, `CellEventActions`, …, also named as a string) or `InitializationCell`, a string with linear syntax, a `TagBox` whose tag is not a string, and a `ButtonBox` that is more than a link (`BaseStyle -> "Hyperlink"` or `"Link"`, `ButtonData`, `ButtonNote`). No symbol is made to tell: the text may only name ``System` `` symbols that exist. |
| `options` | Also the ones that a tag never shows |
| What is made of text (emphasis, links, a formula, a table, tokens of code) | A dynamic box or an option that holds code in it (`requireInert`) |
| The tags and their places | Text outside of cell tags: anything but white space and selection markers before the first cell tag, between a `</cell>` or a `/>` and the next cell tag, and after the last one. An unknown attribute or id; a body with `truncated`; a body that no `</cell>` ends; a cell tag that starts a line of a body; a `</cell>`, `<RawBoxes>`, `<MakeBoxes>` or `<ToBoxes>` without its other tag; LaTeX that can't be read; a URI that is not known any more |

## Originals

Different boxes read as the same Markdown (`[link](url)` may be a `ButtonBox` or a `TemplateBox`), and a model can't write every box that it reads. So the reader records what each piece stands for, and the writer puts a piece that it finds back as it was, unchecked: it is the user's own content.

- A caller that sets `$cellOriginals` to an association gets `<|id -> <|text -> boxes|>|>` in it: Markdown under its text (`**bold**`), `<RawBoxes>` under the text between its tags. Reading a cell again replaces its records, and nothing is recorded for a cell without an id.
- In one cell a piece of Markdown stands for one thing: boxes that would read as Markdown that already stands for other boxes in the cell are `<RawBoxes>`.
- The writer looks a piece up in the records of its cell first, then in those of the other cells, where a text that stands for different boxes is not used. A piece without a record is new: a link is a `ButtonBox`, a formula a `TeXAssistantTemplate` formula, inline code an `InlineCode` cell.
- `<RawBoxes>` without a record are the model's, but a `TemplateBox` in them that the existing cell holds is not (`ownTemplates`): a table with a link template in one entry can have another entry changed. The template is found by its text as the cell was read, so one that is written in another way is refused like any template of the model's. A string stands for it while the rest is read and checked, and the template of the cell is written in its place, unchecked. A new cell, `options` and the results of a sandboxed evaluator have no such templates.

## In Chat Replies

The tags are not read in chat replies, where a tag is the text that it is, and the `"CellSyntax"` prompt tells the model not to write them there.

## Tests

| File | Covers |
|---|---|
| `Tests/CellToString.wlt` | The default Markdown, which the options leave unchanged |
| `Tests/CellSyntax.wlt` | The tag, exact bodies, the writer, the two tables of refusals, round trips |
| `Tests/NotebookTools.wlt`, `Tests/Context.wlt`, `Tests/NotebookReader.wlt` | The callers |

The corpus measures are `Developer/CellSyntaxCorpus.wls` (the sample notebooks are not in the repository; the documentation pages are listed in the script):

```
wolframscript -f Developer/CellSyntaxCorpus.wls roundtrip <notebooks or directories>
wolframscript -f Developer/CellSyntaxCorpus.wls default out.wxf <notebooks or directories>   (in each of two checkouts)
wolframscript -f Developer/CellSyntaxCorpus.wls compare a.wxf b.wxf
```
