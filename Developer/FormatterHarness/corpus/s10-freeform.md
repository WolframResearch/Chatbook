You can use natural language input directly in your code. Type Ctrl+= in a notebook to get a free-form input box, which looks like this:

```wl
\[FreeformPrompt]["population of France"]
```

That resolves to an `Entity`, and you can use it like any other expression:

```wl
EntityValue[Entity["Country", "France"], "Population"]
```

Inline, it looks like `\[FreeformPrompt]["capital of Spain"]`, which gives `Entity["City", {"Madrid", "Madrid", "Spain"}]`.
