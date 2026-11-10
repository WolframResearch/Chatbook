### Short answer

Use `DeleteDuplicates` to remove repeated elements while keeping the original order.

### Example

```wl
DeleteDuplicates[{3, 1, 3, 2, 1}]
(* {3, 1, 2} *)
```

### Alternatives

`Union` also removes duplicates, but it **sorts** the result: `Union[{3, 1, 3, 2, 1}]` gives `{1, 2, 3}`.
