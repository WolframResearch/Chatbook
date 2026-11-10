## Unicode in strings — 文字列とユニコード

Wolfram Language strings are fully Unicode. For example, `StringLength["日本語"]` gives `3`, and `ToCharacterCode["é"]` gives `{233}`.

* Greek: α β γ Δ Ω, written in code as `\[Alpha]` or typed directly as `α`
* Math: ∫ ∑ ∏ √ ∞ ≤ ≥ ≠ → ⇒ ∈ ∀ ∃
* Emoji: 🎉 🚀 👍🏽 👩‍💻 (the last one is a ZWJ sequence)
* Combining marks: é (e + U+0301) vs é (precomposed)
* Right-to-left: مرحبا بالعالم and שלום
* CJK: 你好，世界！ 안녕하세요
* Invisible: zero​width​space and non breaking space

| Language | Greeting | Length |
|:---------|:---------|-------:|
| 日本語 | こんにちは | 5 |
| Ελληνικά | Γειά σου | 8 |
| Emoji | 👋🌍 | 2 |

```wl
StringLength /@ {"こんにちは", "Γειά σου", "👋🌍"}
(* {5, 8, 2} *)
ToUpperCase["straße"]
```

**Ünïcödé in bold**, *ítálíc*, and `côdé` inline. Formula: $\alpha^2 + β = γ$ and €100 or ¥500 or £20.

> “Curly quotes” and ‘single ones’ — plus an ellipsis… and a dash – here.
