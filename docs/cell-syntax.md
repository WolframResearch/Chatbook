# Cell Syntax

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
| Anything else (`RawData`, …) | One `<RawBoxes>` |

**Code** is the tokens of the boxes, as they are: strings with their escapes, numbers with all their digits and marks, comments unchanged.

- Spacing is `CellToString`'s: one space on each side of an infix operator and one after a comma, none at the ends of a line, none after a prefix `-` or `+`. The cell's own spaces at those places are left out.
- Code with spacing of its own has exactly its own spaces: a `Code` cell (where the front end adds no spacing), and code that has a space token next to an infix operator or after a comma.
- Two tokens get a space if they would not read as the same two tokens without it (`a x`, `x_ .y`, `% 2`, `n! !`). CodeParser decides, on the two tokens written together.
- After a `\[IndentingNewLine]` the next line is indented by 4 spaces for each open bracket; after a `"\n"` the spaces are the cell's.
- Operator characters are ASCII: `->`, `:>`, `==`, `!=`, `<=`, `>=`, `|->`, `<->`, `[[`, `]]`, `<|`, `|>`. Other private use characters are long names (`\[ImaginaryI]`), also in strings and comments.
- Any other box is one `<RawBoxes>`. So is a token or a comment that code can't say: one with a tag or a URI of this syntax, a control character or linear syntax, and a comment with the text of a long name.
