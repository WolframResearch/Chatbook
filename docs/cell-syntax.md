# Cell Syntax

## Who Calls It and What It Needs

- `"PreserveBoxes"` is `True`, `False` or `Automatic` (exact for all but generated cells: `Output`, `Print`, `Echo`, `Message`, `MSG` and chat outputs, which keep the lossy Markdown and its length limit). Without `"IncludeXML"` it gives exact bodies inside the decoration of the default Markdown, for reading only. The defaults of the two options are `$includeCellXML` and `$preserveCellBoxes`, which a caller sets for the code that it calls.

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

## Originals

- A caller that sets `$cellOriginals` to an association gets `<|id -> <|text -> boxes|>|>` in it: Markdown under its text (`**bold**`), `<RawBoxes>` under the text between its tags. Reading a cell again replaces its records, and nothing is recorded for a cell without an id.
- In one cell a piece of Markdown stands for one thing: boxes that would read as Markdown that already stands for other boxes in the cell are `<RawBoxes>`.
