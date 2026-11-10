You can create and modify notebooks entirely from code. Here's an overview of the main functions, with examples you can run directly.

## Creating notebooks

[`CreateDocument`](paclet:ref/CreateDocument) creates and opens a new notebook from a list of cells:

```wl
nb = CreateDocument[{
   Cell["Monthly Report", "Title"],
   Cell["Summary", "Section"],
   Cell["This report was generated automatically.", "Text"],
   ExpressionCell[Plot[Sin[x], {x, 0, 2 Pi}], "Output"]
}]
```

The result is a `NotebookObject`, which you can use to modify the notebook later. If you want to create the notebook without displaying it, use `CreateDocument[cells, Visible -> False]`, and save it with `NotebookSave[nb, "report.nb"]`.

### Cell styles

| Style | Typical use |
|:------|:------------|
| `"Title"` | notebook title |
| `"Section"`, `"Subsection"` | headings |
| `"Text"` | paragraphs |
| `"Input"` | code to evaluate |
| `"Output"` | results |
| `"Item"`, `"Subitem"` | bulleted lists |
| `"Code"` | initialization code |

## Writing to an existing notebook

[`NotebookWrite`](paclet:ref/NotebookWrite) writes at the current selection. Move the selection first with `SelectionMove`:

```wl
SelectionMove[nb, After, Notebook];
NotebookWrite[nb, Cell["Appendix", "Section"]];
NotebookWrite[nb, Cell[BoxData[ToBoxes[Table[i^2, {i, 10}]]], "Output"]]
```

To evaluate a cell after writing it:

```wl
NotebookWrite[nb, Cell["RandomInteger[100, 5]", "Input"], All];
SelectionEvaluate[nb]
```

## Reading notebook content

You can get the cells of a notebook with [`Cells`](paclet:ref/Cells) and read them with `NotebookRead`:

```wl
In[1]:= cells = Cells[nb, CellStyle -> "Section"]

Out[1]= {CellObject[<<1>>], CellObject[<<2>>]}

In[2]:= NotebookRead[First[cells]]

Out[2]= Cell["Summary", "Section"]
```

For a notebook file that isn't open, use `Import["file.nb", "Notebook"]` or `Get["file.nb"]` to get the `Notebook` expression without opening a window.

### Searching for cells

```wl
codeCells = Cells[nb, CellStyle -> {"Input", "Code"}];
withErrors = Select[codeCells, MemberQ[CurrentValue[#, CellTags], "Error"] &];
```

## Modifying cell options

Change any option with `SetOptions` or `CurrentValue`:

```wl
SetOptions[First[cells], Background -> LightYellow, CellFrame -> {{2, 0}, {0, 0}}]
CurrentValue[nb, {TaggingRules, "Author"}] = "Report bot";
```

Values set through `TaggingRules` are saved with the notebook, which makes them a good place to store metadata.

## Dynamic content

Notebooks can contain live, interactive content. The basic building blocks are:

- `Dynamic[expr]` — displays `expr` and updates it whenever the values it depends on change
- `DynamicModule[{vars}, body]` — creates local variables that are saved with the notebook
- `Manipulate[expr, controls]` — a complete interface with sliders, menus, and other controls
  - `Manipulate[Plot[Sin[a x], {x, 0, 2 Pi}], {a, 1, 5}]`
  - `Manipulate[Graphics[Disk[{0, 0}, r]], {{r, 1, "radius"}, 0.1, 2}]`

```wl
DynamicModule[{color = Red},
  Column[{
    ColorSlider[Dynamic[color]],
    Dynamic @ Graphics[{color, Disk[]}, ImageSize -> 100]
  }]
]
```

> **Performance tip:** By default, a `Dynamic` updates whenever *any* symbol it reads changes. Use `TrackedSymbols :> {color}` to restrict updates to the symbols you care about.

## Palettes and buttons

You can create a palette with buttons that act on the selected notebook:

```wl
CreatePalette[
  Column[{
    Button["Insert timestamp",
      NotebookWrite[InputNotebook[], DateString[]]],
    Button["Clear outputs",
      NotebookDelete[Cells[InputNotebook[], GeneratedCell -> True]]]
  }],
  WindowTitle -> "My Tools"
]
```

Use `InputNotebook[]` (the notebook with keyboard focus) inside button actions, and `EvaluationNotebook[]` for the notebook that contains the code being evaluated.

## A complete example

This creates a notebook with one section per file in a directory, showing the first few lines of each file:

```wl
makeFileReport[dir_] := Module[{files, cells},
  files = FileNames["*.txt", dir];
  cells = Flatten @ Map[
    {
      Cell[FileNameTake[#], "Section"],
      Cell[StringRiffle[Take[StringSplit[ReadString[#], "\n"], UpTo[5]], "\n"], "Program"]
    } &,
    files
  ];
  CreateDocument[Prepend[cells, Cell["File report", "Title"]], WindowTitle -> "File report"]
]
```

### Notes

1. `ReadString` returns `EndOfFile` for an empty file, so you may want to guard against that.
2. For large directories, consider `Visible -> False` and `NotebookSave` to avoid opening a huge window.
3. All of these functions require a front end. In a script run with `wolframscript`, wrap the code in [`UsingFrontEnd`](paclet:ref/UsingFrontEnd).
