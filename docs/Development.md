# Development

## Quick Command Reference

**Run the tests:**

```shell
$ wolfram-cli paclet test . ./Tests
```

**Build optimized MX for package code:**

```shell
$ ./Scripts/BuildMX.wls
```

## Changing the Chatbook stylesheet

To make changes to the `Chatbook.nb` stylesheet, do the following:

1. Edit style definitions in [Developer/Resources/Styles.wl](../Developer/Resources/Styles.wl)
2. Run `Get` on [Developer/StylesheetBuilder.wl](../Developer/StylesheetBuilder.wl)
3. Evaluate `BuildChatbookStylesheet[]`

To quickly prototype changes to the stylesheet, the symbol `$ChatbookStylesheet`
is defined as a convenience, and can be used as in:

```
Get["Chatbook/Developer/StylesheetBuilder.wl"];

NotebookPut[
    Notebook[{Cell["", "ChatInput"]}, StyleDefinitions -> $ChatbookStylesheet]
]
```