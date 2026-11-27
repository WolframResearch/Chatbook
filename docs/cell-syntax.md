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

- The attributes are in this order, and one without a value is left out. Values are in single quotes, with `&amp;`, `&apos;`, `&lt;` and `&#10;` (a line break) for those characters.

### The Body

The body is the cell's content alone. What the tag says is not repeated: a heading has no `##`, an item no `*`, code no fence and no `In[1]:=`, and a delimiter has an empty body.
