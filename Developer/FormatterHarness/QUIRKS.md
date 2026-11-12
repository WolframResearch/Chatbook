# Formatter quirks found while writing characterization tests

Each item was reproduced against main (375156fb). **[not encoded]** means no test pins the current behavior (it looks wrong), so a rewrite may change it freely. **[encoded]** means a test pins the current behavior because it is plausibly intentional; changing it means updating that test.

## Blocks (37)

### CRLF line endings: plain-text line breaks disappear in the front end; \r stays in heading/item text and breaks heading serialization [not encoded]

- **Repro:** `FormatMarkdown["Line one\r\nLine two"]; FormatMarkdown["> a\r\n> b"]; FormatMarkdown["## Heading\r\n\r\nText\r\n- item\r\n- item2"]; MarkdownRoundTrip["## Heading\r\n\r\nText"]`
- **Observed:** Strings keep "\r\n". In a Chatbook notebook (screenshot) "Line one\r\nLine two" displays as "Line oneLine two", and "Para one\r\n\r\nPara two" as "Para onePara two". Quotes keep "a\r\nb". The heading box is "\"Heading\\r\"", item text is "item\r", and there is text "Text\r \n"; the front end shows extra blank lines around these. The heading serializes as "## Heading\\r" (a literal backslash-r). Only the cell styles are encoded (Blocks-Paragraph-CRLF-Blocks)
- **Expected:** Normalize \r\n to \n before parsing

### Closing hashes of ATX headings are displayed [not encoded]

- **Repro:** `FormatMarkdown["## Trailing hashes ##"]`
- **Observed:** InlineSection with text "Trailing hashes ##"
- **Expected:** Heading text "Trailing hashes" (CommonMark strips the closing # sequence)

### Indented headings are not recognized [not encoded]

- **Repro:** `FormatMarkdown["   ## indented heading"]`
- **Observed:** {"## indented heading"}: plain text, with the leading spaces trimmed
- **Expected:** A Section heading (CommonMark allows up to 3 leading spaces)

### Extra space after # is kept in heading text [not encoded]

- **Repro:** `FormatMarkdown["#  Two spaces"]`
- **Observed:** Title heading whose box string is "\" Two spaces\"" (the leading space is shown)
- **Expected:** Heading text "Two spaces"

### Spaced thematic breaks become bullets, italics or text instead of rules [not encoded]

- **Repro:** `FormatMarkdown /@ {"* * *", "- - -", "_ _ _", "-- -"}`
- **Observed:** '* * *' -> InlineItem holding StyleBox["", FontSlant -> Italic] (a lone bullet). '- - -' -> InlineItem with text "- -". '_ _ _' -> {StyleBox["", FontSlant->Italic], " _"} (shows ' _', checked in the front end). '-- -' -> literal text. The bullet rule comes before $$delimiter, and $$delimiter only allows unbroken runs
- **Expected:** MarkdownDelimiter cells (all four are CommonMark thematic breaks)

### Horizontal rule with trailing or leading spaces is plain text [not encoded]

- **Repro:** `FormatMarkdown["--- \n\nText after spaced rule"]; FormatMarkdown[" ---"]`
- **Observed:** Literal "---" text. $$delimiter needs EndOfLine right after the run and StartOfLine right before it
- **Expected:** MarkdownDelimiter cell

### Setext-style underline '---' after text is a rule, not a heading; '=====' underlines stay text [encoded]

- **Repro:** `FormatMarkdown["Above\n---\nBelow"]; FormatMarkdown["Heading\n=====\n\nText"]`
- **Observed:** {"Above \n", MarkdownDelimiter, "\nBelow"}; '=====' stays plain text
- **Expected:** CommonMark makes these h2/h1 headings. LLMs rarely write setext headings, so this is plausibly intended

### Indented code blocks are plain text [encoded]

- **Repro:** `FormatMarkdown["Text\n\n    code line"]`
- **Observed:** {"Text\n\n    code line"}, with the indentation shown
- **Expected:** CommonMark: an indented code block. LLMs almost always use fences, so this is plausibly fine

### Plain-text block quotes serialize with literal quote characters [not encoded]

- **Repro:** `MarkdownRoundTrip["> A quote"]; MarkdownRoundTrip["> line one\n> line two"]`
- **Observed:** "> \"A quote\"" and "> \"line one\n> line two\"". The PaneBox holds the ToBoxes string box, and the BlockQuote serializer, unlike InlineSection, does not set $showStringCharacters = False. The display has no quote marks. Quotes with formatted content serialize correctly
- **Expected:** "> A quote"

### The newline after a block quote is lost [not encoded]

- **Repro:** `FormatMarkdown["> quote\n- item"]; FormatMarkdown["> q\nBody"]; MarkdownRoundTrip["Before\n> quoted\nAfter"]; FormatMarkdown["> q\n---"]`
- **Observed:** $$blockQuoteLine consumes the trailing "\n". '> quote\n- item' -> {BlockQuote, "- item"} (no bullet). '> q\nBody' -> {BlockQuote, "Body"}. The serialization is "Before \n\n> \"quoted\"After", which puts After inside the quote. '> q\n---' gives no \n between the cells
- **Expected:** Keep the \n after the quote, as every other block does

### '>' followed by a newline pulls the next line into the quote [not encoded]

- **Repro:** `FormatMarkdown[">\nfoo"]`
- **Observed:** A BlockQuote containing "\nfoo". $$ws (Shortest[WhitespaceCharacter...]) in $$blockQuoteLine can match the newline. The same thing makes '> q1\n>\n> q2' come out right by accident
- **Expected:** An empty quote (or no quote) followed by the paragraph "foo"

### Nested quotes, headings, lists and code fences inside quotes are not parsed [not encoded]

- **Repro:** FormatMarkdown /@ {">> nested", "> ## heading in quote", "> - item in quote", "> ```\n> code\n> ```", "> Text\n> ```wl\n> 1+1\n> ```"}
- **Observed:** Quotes with the literal text "> nested", "## heading in quote", "- item in quote". A fenced block in a quote becomes plain text "\ncode\n" (formatTextString deletes the outer fences), and a fence in the middle of a quote shows literally ("```wl\n1+1\n"). The heading case serializes as "> \"\\#\\# heading in quote\""
- **Expected:** A nested quote, a heading, a list, and a code block inside the quote

### Quoted tables become tables with a '>' column [not encoded]

- **Repro:** `FormatMarkdown["> | a | b |\n> | c | d |"]`
- **Observed:** A TextTableForm grid with rows {">","a","b"},{">","c","d"}. The table rule comes before the quote rule, and $$mdRow2 accepts the leading '>'
- **Expected:** A block quote containing a table, or at least a quote containing the text

### Tabs are not accepted as list indentation or after markers [not encoded]

- **Repro:** `FormatMarkdown["- one\n\t- tabbed"]; FormatMarkdown["-\titem"]; FormatMarkdown["##\tTab"]`
- **Observed:** {InlineItem one, "\n\t- tabbed"}, {"-\titem"}, {"##\tTab"}: all literal text
- **Expected:** An InlineSubitem, a bullet item, and a heading

### An indented first item loses its indentation [not encoded]

- **Repro:** `FormatMarkdown["  - leading subitem\n- normal"]`
- **Observed:** The first cell is InlineSubitem with indent "" (trimWhitespaceL descends into the first cell's TextData). It serializes as "* leading subitem"
- **Expected:** Either InlineItem, or InlineSubitem with its indentation kept

### Extra spaces after a bullet marker are displayed [not encoded]

- **Repro:** `FormatMarkdown["-   spaced item\n- b"]; MarkdownRoundTrip["-   spaced item\n- b"]`
- **Observed:** Item text "  spaced item": the front end shows a gap after the bullet (screenshot). It serializes as "*   spaced item\n* b"
- **Expected:** Item text "spaced item" (CommonMark absorbs up to 4 spaces after the marker)

### Whitespace-only lines are not treated as blank lines [not encoded]

- **Repro:** `FormatMarkdown["Para\n  \n- a"]; FormatMarkdown["Para\n \n## H"]; FormatMarkdown["## H\n  \nText"]`
- **Observed:** {"Para\n   \n", item}: a blank line shows before the list (screenshot), while "Para\n\n- a" shows none. The same happens for headings and quotes. After a heading, {H, "\n  \nText"} gives an extra blank line, while "## H\n\nText" gives {H, "\nText"}
- **Expected:** The same output as with an empty blank line

### Numbered lists and '+' bullets get no list formatting [encoded]

- **Repro:** `FormatMarkdown["1. first\n2. second"]; FormatMarkdown["1) a\n2) b"]; FormatMarkdown["+ plus one\n+ plus two"]`
- **Observed:** Plain text, with inline formatting still applied. Numbered lists read fine; '+' shows literally
- **Expected:** Possibly numbered or bulleted items. Kept as is because the plain text is readable

### Task list items show literal brackets [encoded]

- **Repro:** `FormatMarkdown["- [ ] task\n- [x] done"]`
- **Observed:** InlineItems with the text "[ ] task" and "[x] done"
- **Expected:** GFM checkboxes. Readable as is

### Lines after an item without a marker are not part of the item [encoded]

- **Repro:** `FormatMarkdown["- item\ncontinuation line"]; FormatMarkdown["- item\n  indented continuation"]`
- **Observed:** {item, "\ncontinuation line"}: the continuation starts at the left margin. In the indented case the two spaces are literal text, so the line is not aligned with the item text (not encoded)
- **Expected:** CommonMark: a (lazy) continuation of the item paragraph. Readable as is

### Heading markers inside a list item are literal [not encoded]

- **Repro:** `FormatMarkdown["- # heading"]`
- **Observed:** InlineItem with text "# heading", serialized as "* \\# heading"
- **Expected:** CommonMark: a list item containing a heading

### Headings deeper than six levels are level-six headings [encoded]

- **Repro:** `FormatMarkdown["####### Seven"]; MarkdownRoundTrip["####### Seven"]`
- **Observed:** Subsubsubsubsection heading; serialized as "###### Seven"
- **Expected:** CommonMark: a plain paragraph. Showing a heading is plausibly better for users

### Empty markers display literally [encoded]

- **Repro:** `FormatMarkdown["# "]; FormatMarkdown["- "]; FormatMarkdown[">"]; FormatMarkdown["## ", "Streaming"]`
- **Observed:** {"#"}, {"-"}, {">"}, {"##"}. A lone '> ' gives an empty BlockQuote instead (see the next quirk)
- **Expected:** CommonMark gives an empty heading, item, or quote. This is harmless and mostly seen while streaming

### Empty block quote for '> ' [encoded]

- **Repro:** `FormatMarkdown["> ", "Streaming"]; FormatMarkdown["> "]`
- **Observed:** A BlockQuote cell with an empty string box, in both Streaming and Finished
- **Expected:** Plausible: a partial quote shows an empty quote box

### Entity decoding lowercases arbitrary '&...;' text [not encoded]

- **Repro:** `FormatMarkdown["Tom & Jerry; fun"]; FormatMarkdown["R&D; costs"]`
- **Observed:** {"Tom & jerry; fun"} and {"R&d; costs"}. importHTMLEntities matches '&' + 1-6 non-newline characters + ';', and importHTMLEntity returns ImportString[ToLowerCase@entity, "HTML"] whenever that is a string
- **Expected:** Text unchanged unless it is a real entity

### Uppercase named entities decode to lowercase letters [not encoded]

- **Repro:** `FormatMarkdown["&Eacute;cole"]; FormatMarkdown["&Omega; vs &omega;"]; FormatMarkdown["&Agrave;"]`
- **Observed:** {"\[EAcute]cole"}, {"\[Omega] vs \[Omega]"}, {"\[AGrave]"}, because of ToLowerCase in importHTMLEntity. ('&AMP;' -> '&' is correct and is encoded in Blocks-HTMLEntities-Case-Insensitive)
- **Expected:** \[CapitalEAcute]cole, \[CapitalOmega] vs \[Omega], \[CapitalAGrave] (entity names are case-sensitive)

### Entities longer than 6 characters are not decoded [not encoded]

- **Repro:** `FormatMarkdown /@ {"&#128512; smile", "&#x1F600; hex", "&epsilon; small"}`
- **Observed:** All three are left as literal text: the pattern allows only 1-6 characters between & and ;
- **Expected:** The emoji and \[Epsilon]

### &nbsp; and &#160; are deleted [not encoded]

- **Repro:** `FormatMarkdown["non&nbsp;breaking"]; FormatMarkdown["&#160;x"]`
- **Observed:** {"nonbreaking"}, {"x"} (ImportString[..., "HTML"] gives "")
- **Expected:** A non-breaking space (or a plain space)

### Escaped entities are decoded twice [not encoded]

- **Repro:** `FormatMarkdown["&amp;lt;"]; FormatMarkdown["- a &amp;lt; b"]`
- **Observed:** {"<"} and item text "a < b". The match takes "&amp;lt;" as one entity, and ImportString HTML decodes it fully
- **Expected:** "&lt;"

### Entity-encoded markdown and tags are parsed as markdown [not encoded]

- **Repro:** `FormatMarkdown["&#42;not italic&#42;"]; FormatMarkdown["&#35;&#35; heading"]; FormatMarkdown["&lt;think&gt;hi&lt;/think&gt;"]`
- **Observed:** Italic text, a Section heading, and a ThoughtsOpener cell. Entities are decoded before any parsing
- **Expected:** Literal "*not italic*", "## heading", "<think>hi</think>"

### Entities are decoded inside inline code and code blocks [encoded]

- **Repro:** MarkdownRoundTrip["Use `a &amp; b` code"]; MarkdownRoundTrip["```wl\nx &amp;&amp; y\n```"]
- **Observed:** "Use ``a & b`` code" and "```wl\nx && y\n```"
- **Expected:** CommonMark keeps entities literal in code. Models that HTML-escape output usually escape code too, so decoding is probably intended

### Prose that starts with a symbol call is rendered entirely as WL code [not encoded]

- **Repro:** `FormatMarkdown["Plot[x] and Plot[y]"]; FormatMarkdown["- Plot[x] and Plot[y]"]`
- **Observed:** A single InlineWL cell for the whole sentence (RowBox[{Plot[x], and, Plot[y]}]). almostCertainlyWLCodeQ matches systemName ~~ "[" ~~ ___ ~~ "]" against the whole part. Parts that are only code ("Range[10]") are encoded as InlineWL
- **Expected:** Inline code only for the code, and text for the rest

### A paragraph after a list or quote is separated by one newline [encoded]

- **Repro:** `FormatMarkdown["- two\n\nAfter list"]; MarkdownRoundTrip["- two\n\nAfter list"]`
- **Observed:** {item, "\nAfter list"}: no blank line between the list and the paragraph (screenshot). The serialized form "* two\nAfter list" makes After a lazy continuation in markdown. This comes from formatTextString mapping a leading "\n\n" to "\n", which also applies after headings, rules and code blocks, where the cell provides the spacing. The display is encoded (Blocks-List-After-Paragraph, Blocks-Paragraph-Text-After-Block, Blocks-Document-Structure). The serialization is pinned only through the reformat-is-stable check
- **Expected:** Plausibly intended tight spacing. If it is changed, a blank line after lists, serialized as "* two\n\nAfter list"

### Extra blank lines are displayed but collapsed when serialized; asymmetric around headings and bullets [encoded]

- **Repro:** `FormatMarkdown["Para one\n\n\nPara two"]; MarkdownRoundTrip["Para one\n\n\nPara two"]; FormatMarkdown["Para\n\n\n## H"]; FormatMarkdown["## H\n\n\nBody"]`
- **Observed:** The display keeps \n\n\n, and serialization gives "Para one\n\nPara two". Blank lines before headings and bullets are consumed, but blank lines after them (and around rules and quotes) are kept minus one. Loose lists collapse to tight lists
- **Expected:** Plausibly intended

### Space inserted before the trailing newline of text that precedes a block [encoded]

- **Repro:** `First@FormatMarkdown["Intro\n## H"]`
- **Observed:** "Intro \n" (joinAdjacentStrings0, front end line-break workaround from commit fe31de80). It also shows up in serialization ("Intro \n\n## H")
- **Expected:** Intentional workaround. Keep it, or check in the front end before dropping it

### Escaped-markdown path drops the line break after a code block [not encoded]

- **Repro:** FormatMarkdown["Cost \\$5\n\n```wl\n1+1\n```\n\n- a"] vs FormatMarkdown["Cost $5\n\n```wl\n1+1\n```\n\n- a"]; the same with "Text" or "## After" after the code block
- **Observed:** With an escape: {..., ChatCodeBlock, item}. Without: {..., ChatCodeBlock, "\n", item}. Each text piece is reformatted separately and joinAdjacentStrings drops its leading "\n". The display is identical (screenshot), but serialization differs: "```\n* a" vs "```\n\n* a" and "```\nText" vs "```\n\nText" (headings, rules and quotes serialize the same)
- **Expected:** The same output as the unescaped path (escapes/code-block area)

### A fence in the middle of a line opens a code block [not encoded]

- **Repro:** FormatMarkdown["Text```\n\nMore"]
- **Observed:** {"Text", ChatCodeBlock containing "More"}
- **Expected:** Plain text (code-block area)

## Inline (36)

### Emphasis around inline code at paragraph level is not applied; markers shown literally [not encoded]

- **Repro:** FormatMarkdown["**`Plot`**"]; FormatMarkdown["*`Plot`*"]; FormatMarkdown["**bold with `code` inside**"]; FormatMarkdown["Use `Plot`, then **`Plot`**"]
- **Observed:** {"**", TextRefLink, "**"}; {"*", link, "*"}; {"**bold with ", StyleBox["code","TI"], " inside**"}. $textDataFormatRules splits out inline code before the emphasis rules in $stringFormatRules see the text (verified)
- **Expected:** Emphasis applied around the code, with no literal asterisks (as happens in list items)

### Emphasis whose content formats to more than one item loses its style [not encoded]

- **Repro:** FormatMarkdown["**See [docs](https://example.com) here**"]; FormatMarkdown["**Bold with _italic_ inside**"]; FormatMarkdown["- **bold `Plot`** item"]
- **Observed:** {"See ", ButtonBox[...], " here"} with no bold; {"Bold with ", italic, " inside"} with no bold; list item {"bold ", link, " item"} with no bold and the asterisks removed. styleBox falls through to styleBox[a_, ___] := a (verified)
- **Expected:** Bold applied to every part

### Nested emphasis with the same marker character is garbled [not encoded]

- **Repro:** `FormatMarkdown["**bold *nested italic* text**"]; FormatMarkdown["*italic **nested bold** text*"]`
- **Observed:** {"*", StyleBox["bold ", Italic], "nested italic", StyleBox[" text", Italic], "*"}; {Italic "italic ", "", Italic "nested bold", "", Italic " text"} (inner bold lost) (verified)
- **Expected:** Bold text with an italic part; italic text with a bold-italic part

### Markers next to whitespace still mark emphasis (arithmetic gets italicized) [not encoded]

- **Repro:** `FormatMarkdown["5 * 3 = 15 and 2 * 4 = 8"]; FormatMarkdown["a * b * c"]; FormatMarkdown["**bold **"]; FormatMarkdown["** bold**"]`
- **Observed:** {"5 ", StyleBox[" 3 = 15 and 2 ", Italic], " 4 = 8"}; {"a ", StyleBox[" b ", Italic], " c"}; "**bold **" and "** bold**" both give StyleBox["bold", Bold] (verified)
- **Expected:** Plain text. CommonMark requires the opening marker not to be followed by whitespace and the closing marker not to be preceded by whitespace

### Paragraph break next to inline code collapses to a single line break [not encoded]

- **Repro:** FormatMarkdown["Use `Plot`\n\nNext paragraph"]; FormatMarkdown["First paragraph\n\n`Plot` is great"]; FormatMarkdown["Use `foo bar`\n\nNext"]
- **Observed:** {"Use ", link, "\nNext paragraph"}; {"First paragraph \n", link, " is great"}. formatTextString replaces a leading or trailing "\n\n" with "\n" on every fragment. The round trip gives "Use [Plot](paclet:ref/Plot)\nNext paragraph" (verified)
- **Expected:** "\n\n" kept, as in 'Use `Plot`.\n\nNext', which is fine and now tested in Inline-Code-Paragraph-Break

### Link labels containing inline code break the link at paragraph level [not encoded]

- **Repro:** FormatMarkdown["See [`code` more](https://example.com) now"]; FormatMarkdown["See [the `Plot` function](paclet:ref/Plot) now"]; FormatMarkdown["[`f[x]`](https://example.com)"]
- **Observed:** {"See [", StyleBox["code","TI"], " more](https://example.com) now"}; {"See [the ", link, " function](paclet:ref/Plot) now"}; {"[", template "f[x]", "](https://example.com)"} (verified)
- **Expected:** A link whose label contains the code

### Link with a partly formatted label is dropped [not encoded]

- **Repro:** `FormatMarkdown["See [**Bold** link](https://example.com) now"]`
- **Observed:** {"See ", StyleBox["Bold", Bold], " link now"}: no ButtonBox (hyperlink[a_, ___] := a) (verified)
- **Expected:** A hyperlink whose label is a bold 'Bold' followed by ' link'

### paclet: link labels are not markdown-formatted [not encoded]

- **Repro:** `FormatMarkdown["[**Plot**](paclet:ref/Plot)"]`
- **Observed:** TextRefLink with label "**Plot**" (literal asterisks) (verified)
- **Expected:** Label 'Plot' (bold or plain)

### URLs with parentheses are truncated [not encoded]

- **Repro:** `FormatMarkdown["See [label](https://example.com/a_(b)) now"]`
- **Observed:** ButtonBox with URL "https://example.com/a_(b" followed by the text ") now" (verified)
- **Expected:** URL "https://example.com/a_(b)" (CommonMark allows balanced parentheses)

### Link titles and spaces around the URL become part of the URL [not encoded]

- **Repro:** `FormatMarkdown["See [label](https://example.com \"title\") now"]; FormatMarkdown["[a]( https://x.com )"]`
- **Observed:** ButtonData -> {URL["https://example.com \"title\""], None}; ButtonData -> {URL[" https://x.com "], None} with ButtonNote " https://x.com " (verified)
- **Expected:** URL "https://example.com" / "https://x.com" (title ignored or used as ButtonNote, surrounding spaces trimmed)

### paclet: URI with a fragment produces a broken web URL [not encoded]

- **Repro:** `FormatMarkdown["See [x](paclet:ref/Plot#123) now"]`
- **Observed:** TextRefLink third argument "https://reference.wolfram.com/language/ref/Plot#123.html". The re-formatted \[FreeformPrompt] link gets ".../KnowledgeRepresentationAndAccess#203374175.html" the same way (verified)
- **Expected:** "https://reference.wolfram.com/language/ref/Plot.html#123"

### Four-backtick inline code: raw inlineCodeCell head leaks in list items, backticks shown in paragraphs [not encoded]

- **Repro:** FormatMarkdown["- a ````x```` b"]; FormatMarkdown["a ````x```` b"]
- **Observed:** List item: TextData contains Wolfram`Chatbook`Formatting`Private`inlineCodeCell["x"], and CellToString gives "\\[Bullet] a x b". Paragraph: code template with content "`x`" (literal backticks). autoCorrect rewrites ````x```` to ```x``` (verified)
- **Expected:** An inline code cell for x (makeResultCell @ inlineCodeCell @ code), as with the other inline code rules

### Empty emphasis renders as nothing [not encoded]

- **Repro:** `FormatMarkdown["** **"]; FormatMarkdown["_ _"]`
- **Observed:** {StyleBox["", FontWeight -> Bold]}; {StyleBox["", FontSlant -> Italic]}; the round trip gives "" (verified)
- **Expected:** Literal "** **" / "_ _"

### Link with empty label vanishes [not encoded]

- **Repro:** `FormatMarkdown["See [](https://example.com) now"]`
- **Observed:** {"See  now"} (verified)
- **Expected:** A visible link (e.g. the URL as label) or the literal text

### Unbalanced backtick runs are mis-split [not encoded]

- **Repro:** FormatMarkdown["`Plot``ListPlot`"]; FormatMarkdown["Use ``x` here"]
- **Observed:** {template "Plot`", "ListPlot`"} (inlineSyntaxQ accepts "Plot`" as a context name); {"Use `", StyleBox["x","TI"], " here"} (stray backtick plus code) (verified)
- **Expected:** Two inline code items for the first. Literal text "Use ``x` here" (CommonMark) for the second

### Backticked ResourceFunction link label in list items keeps the backticks in the WL cell [not encoded]

- **Repro:** FormatMarkdown["- [`ResourceFunction[\"Foo\"]`](https://example.com/Foo)", "Streaming"]
- **Observed:** InlineWL cell with BoxData["`\!\(\*TagBox[...FunctionResourceBox...]\)`"]: backticks around the box string (verified)
- **Expected:** The same resource function box as at paragraph level, without backticks

### Autolinks are not supported [not encoded]

- **Repro:** `FormatMarkdown["See <https://example.com> now"]`
- **Observed:** {"See <https://example.com> now"} (verified)
- **Expected:** A hyperlink to https://example.com (CommonMark autolink)

### Nested TeX text commands not supported [not encoded]

- **Repro:** `FormatMarkdown["Both \\textbf{\\textit{x}}"]`
- **Observed:** {"Both \\textbf{", StyleBox["x", Italic], "}"} (verified)
- **Expected:** Bold italic x

### TeX text commands match case-insensitively [not encoded]

- **Repro:** `FormatMarkdown["\\TEXTBF{x} and \\TextIt{y}"]`
- **Observed:** {StyleBox["x", Bold], " and ", StyleBox["y", Italic]}. formatTextString's StringSplit uses IgnoreCase -> True, so the \\textit{ / \\textbf{ literals match any case (verified)
- **Expected:** Only lowercase \\textit / \\textbf (LaTeX is case-sensitive). Harmless, but a rewrite that drops IgnoreCase will change this

### Double-backtick code spans line breaks and even paragraph breaks [not encoded]

- **Repro:** FormatMarkdown["Use ``a\nb`` here"]; FormatMarkdown["First ``a\n\nSecond paragraph`` end"]
- **Observed:** Code template containing "a\nb"; one code template containing "a\n\nSecond paragraph", so the paragraph break is swallowed into the code. The "``" ~~ code__ ~~ "``" rule has no newline restriction, unlike single backticks and emphasis (verified)
- **Expected:** No code span across a blank line (CommonMark). Within a paragraph, CommonMark turns the line break into a space

### Whole-fragment WL shortcut: false positive on prose, and whitespace-sensitive [not encoded]

- **Repro:** `FormatMarkdown["Plot[x] and Plot[y]"]; FormatMarkdown["Plot[x]\n"]; FormatMarkdown["  Plot[x]"]`
- **Observed:** The whole sentence becomes one InlineWL cell (RowBox with "and" as a symbol). With a trailing newline or leading spaces, the same code is plain text "Plot[x]" (verified)
- **Expected:** Prose stays text. Whitespace around a code-only response should not change the result

### Code span padding spaces are kept [not encoded]

- **Repro:** FormatMarkdown["Use `` `code` `` here"]; FormatMarkdown["Use `` Plot `` here"]
- **Observed:** Code template " `code` "; code template " Plot " (not linked) (verified)
- **Expected:** CommonMark strips one leading and one trailing space: "`code`" and a Plot ref link

### Serializer markdown-escapes inside inline code [not encoded]

- **Repro:** MarkdownRoundTrip /@ {"Use `f[x_] := x^2` here", "Use `#` here", "Use `a*b*c` here", "Use `Wolfram`Chatbook`` here", "Use `*` here", "Use ``a`b`` here"}
- **Observed:** "Use ``f[x\\_] := x^2`` here", "Use ``\\#`` here", "Use ``a\\*b\\*c`` here", "Use ``Wolfram\\`Chatbook\\``` here", "Use `` * `` here", "Use ``a\\`b`` here". Re-formatting gives the same boxes (Inline-RoundTrip-Reformat-Stable), but the chat history shows backslashes inside code (verified)
- **Expected:** Code content serialized verbatim, e.g. "``f[x_] := x^2``"

### Serializer turns backslash-t / backslash-n in text into tab / newline [not encoded]

- **Repro:** `CellToString[Cell[TextData[{"a \\textit{x} b"}], "ChatOutput"]]; MarkdownRoundTrip["\\textit{a{b}c}"]; CellToString[Cell[TextData[{"a \\n b"}], "ChatOutput"]]`
- **Observed:** "a <TAB>extit{x} b"; "extit{a{b}c}" (the leading tab is trimmed away); "a <newline> b". The formatter output is correct; Serialization.wl interprets the escape sequences (verified)
- **Expected:** Backslashes preserved: "a \\textit{x} b"

### Serializer spacing around some inline items [not encoded]

- **Repro:** MarkdownRoundTrip["*`Plot`*"]; MarkdownRoundTrip["`Plot`/`ListPlot`"]
- **Observed:** "* [Plot](paclet:ref/Plot) *"; "[Plot](paclet:ref/Plot) / [ListPlot](paclet:ref/ListPlot)". Re-formatting the second gives {link, " / ", link} instead of {link, "/", link} (verified)
- **Expected:** "*[Plot](paclet:ref/Plot)*" and "[Plot](paclet:ref/Plot)/[ListPlot](paclet:ref/ListPlot)"

### Escaped brackets around a symbol name are treated as display math and swallow surrounding spaces (math area, noted only) [not encoded]

- **Repro:** `FormatMarkdown["Use \\[Plot\\] here"]`
- **Observed:** {"Use", TextRefLink Plot, "here"}; the round trip gives "Use[Plot](paclet:ref/Plot)here" (verified)
- **Expected:** "Use [Plot] here" as text, or at least the spaces preserved

### Streaming \[FreeformPrompt]["query"] in inline code keeps the closing quote in the query box (not checked in the front end) [not encoded]

- **Repro:** FormatMarkdown["Use `\[FreeformPrompt][\"population\"]` here", "Streaming"]
- **Observed:** The OverlayBox/FrameBox contains StyleBox["population\"", ShowStringCharacters -> False]: the box string is population followed by an unmatched quote (verified in the boxes; not looked at in the front end)
- **Expected:** A query box showing just 'population'

### Emphasis and single-backtick code never span a line break [encoded]

- **Repro:** FormatMarkdown["**bold\nacross** lines"]; FormatMarkdown["Use `multi\nline` here"]
- **Observed:** Literal text with the markers. Every emphasis rule has /; StringFreeQ[text, "\n"], and single-backtick code uses Except["`"|"\n"]
- **Expected:** CommonMark allows both across a soft line break. Plausibly intentional: it stops a stray marker from pairing with one on a later line. Tested in Inline-Emphasis-Not-Across-Lines and Inline-Code-Not-Code

### \[FreeformPrompt] in inline code renders inconsistently [encoded]

- **Repro:** FormatMarkdown["Use `\[FreeformPrompt] population` here"]; FormatMarkdown["Use `x \[FreeformPrompt] y` here"]; the same two with "Streaming"; FormatMarkdown["**\[FreeformPrompt]**"]
- **Observed:** A leading FP stays a plain character (the makeResultCell0 almostCertainlyWLCodeQ clause skips the FP replacement). A non-leading FP becomes the small colored $freeformPromptBox in Finished mode only: in Streaming the BoxData string is not split, so it stays plain. A bold FP in text becomes a bold InlineWL cell, not the HyperlinkPaclet link used for an FP in plain text
- **Expected:** Probably the same FP rendering everywhere. Minor visual difference

### A link label that is entirely WL code (or code in a list item) becomes a cell inside the ButtonBox [encoded]

- **Repro:** FormatMarkdown["See [Plot[x]](https://example.com) now"]; FormatMarkdown["- [`foo bar`](https://example.com)"]
- **Observed:** ButtonBox[Cell[BoxData[RowBox[{"Plot","[","x","]"}]], "InlineWL", ...], BaseStyle -> "Hyperlink", ...]; ButtonBox[code template cell, ...]. Serializes as [``Plot[x]``](url) / [``foo bar``](url)
- **Expected:** Plausible: consistent with the whole-fragment WL shortcut and with list-item code labels. I did not check in the front end that a link with an inline cell as its label is still clickable. Tested in Inline-Link-Cell-Label

### Emphasis around a documentation link is dropped [encoded]

- **Repro:** FormatMarkdown["**[Plot](paclet:ref/Plot)**"]; FormatMarkdown["- **`Plot`**"]
- **Observed:** {TextRefLink Plot} with no bold (explicit styleBox clause) (verified)
- **Expected:** Plausibly intentional (TextRefLink has its own style)

### [`code`](url) differs between paragraphs and list items [encoded]

- **Repro:** FormatMarkdown["See [`code`](https://example.com) now"]; FormatMarkdown["- [`code`](https://example.com)"]
- **Observed:** Paragraph: ButtonBox["code"] (a $textDataFormatRules rewrite strips the backticks). List item: ButtonBox[StyleBox["code", "TI"]] (verified)
- **Expected:** Probably the same in both places; both are reasonable

### Escaped backticks are allowed inside single-backtick code [encoded]

- **Repro:** FormatMarkdown["Use `a\\`b` here"]
- **Observed:** Code template "a`b"
- **Expected:** CommonMark would end the code at the escaped backtick. The current behavior is friendlier and matches how the serializer escapes

### ResourceFunction links drop their URL [encoded]

- **Repro:** FormatMarkdown["See [`ResourceFunction[\"Foo\"]`](https://example.com/Foo) now", "Streaming"]
- **Observed:** InlineWL resource function box; the URL is discarded
- **Expected:** Intentional (explicit rules)

### \textit/\textbf may span a line break, markdown emphasis may not [encoded]

- **Repro:** `FormatMarkdown["\\textit{line\nbreak}"]`
- **Observed:** {StyleBox["line\nbreak", FontSlant -> Italic]}
- **Expected:** Plausibly fine (LaTeX allows it)

### \[FreeformPrompt] text serializes as a markdown link [encoded]

- **Repro:** `MarkdownRoundTrip["Ask \[FreeformPrompt] here"]`
- **Observed:** "Ask [\[FreeformPrompt]](paclet:guide/KnowledgeRepresentationAndAccess#203374175) here". Re-formatting gives a TextRefLink (with the broken '#203374175.html' web URL) instead of the HyperlinkPaclet box (verified)
- **Expected:** Plausibly intentional (HyperlinkPaclet is in $$refLinkTemplate). The re-formatted URL is wrong (see the paclet fragment quirk)

## Math (22)

### Dollar amounts with an operator between them become math [not encoded]

- **Repro:** `FormatChatOutput["$5-$10"]; FormatChatOutput["costs $5 - $10 total"]; FormatChatOutput["x = $5 and y = $6"]; FormatChatOutput["$5 + $x$"]; FormatChatOutput["The total is $5 + tax and $$x^2$$"]`
- **Observed:** {math["5-"], "10"}; {"costs ", math["5 -"], "10 total"}; {"x = ", math["5 and y ="], "6"}; {math["5 +"], "x$"}; {"The total is ", math["5 + tax and"], math["x^2"], "$"} (re-verified). probablyMathQ accepts any span that contains + - = ^.
- **Expected:** Text with literal dollar amounts. For example, the pandoc rule: the opening $ is followed by a non-space, and the closing $ follows a non-space and is not followed by a digit.

### Top-level emphasis, strikethrough and links around math are broken [not encoded]

- **Repro:** `FormatChatOutput["**$x^2$**"]; FormatChatOutput["*$x$*"]; FormatChatOutput["~~$x$~~"]; FormatChatOutput["[link $x$](http://example.com)"]; FormatChatOutput["a **b $y$** c"]`
- **Observed:** {"**", math, "**"}; {"*", math, "*"}; {"~~", math, "~~"}; {"[link ", math, "](http://example.com)"}; {"a **b ", math, "** c"}. The $textDataFormatRules math rules split the math out before $stringFormatRules sees the markers. CellToString gives "\\*\\*$$x^2$$\\*\\*" (re-verified).
- **Expected:** Bold, italic or struck-through math, and a hyperlink whose label contains math. This already works inside list items ("- **$x^2$**" gives the math Cell FontWeight -> Bold).

### Emphasis spanning text plus math drops the style [not encoded]

- **Repro:** `FormatChatOutput["- **the value $x^2$** item"]`
- **Observed:** InlineItem {bullet, " ", "the value ", math, " item"}, with no bold anywhere (re-verified). styleBox[{"the value ", Cell[...]}, FontWeight -> Bold] falls through to styleBox[a_, ___] := a.
- **Expected:** "the value " in bold, and the math too.

### Whitespace-delimited \[...\] loses the whitespace and line breaks around it [not encoded]

- **Repro:** `FormatChatOutput["Before \\[x^2\\] after"]; FormatChatOutput["Here:\n\n\\[x^2\\]\n\nmore"]; FormatChatOutput["Here:\n\\[\n\\begin{aligned} a &= b \\\\ c &= d \\end{aligned}\n\\]\nDone"]; FormatChatOutput["\\[a\\] and \\[b\\]"]; MarkdownRoundTrip["a \\[x^2\\] b"]`
- **Observed:** {"Before", math, "after"}; {"Here:", math, "more"}; {"Here:", math[aligned], "Done"}, which serializes as "Here:$$\\begin{aligned}...$$Done"; {math, "and", math}; "a$$x^2$$b" (re-verified). On the escaped path each text part between matches goes through reformatTextData0 separately and is trimmed by joinAdjacentStrings/trimWhitespace.
- **Expected:** The same as with $$: {"Before ", math, " after"} and {"Here:\n", math, "\nmore"}. This is the common GPT style for display math, \[ ... \] on its own lines. The tests check only the order.

### \[...\] in a list item or heading is pulled out of it [not encoded]

- **Repro:** `FormatChatOutput["- item \\[x^2\\] end"]; FormatChatOutput["## Heading \\[x\\]"]`
- **Observed:** {InlineItem[bullet, "item"], math, "end"}; {InlineSection["Heading "], math} (re-verified). The \[ regex split runs before the bullet and heading rules.
- **Expected:** The math inside the InlineItem or InlineSection.

### Escaped brackets with whitespace around them are parsed as math [not encoded]

- **Repro:** `FormatChatOutput["See \\[1\\] for details."]; FormatChatOutput["\\[Optional\\] parameter"]`
- **Observed:** {"See1for details."}: the math is numeric, so it becomes plain text, and the spaces are trimmed. {TextRefLink["Optional"], "parameter"} (re-verified).
- **Expected:** "See [1] for details." and "[Optional] parameter". This is ambiguous with \[ display math; requiring TeX-like content or a line of its own would help.

### \[...\] next to punctuation is not math [not encoded]

- **Repro:** `FormatChatOutput["\\[x\\]."]; FormatChatOutput["(\\[x\\])"]`
- **Observed:** {"[x]."}; {"([x])"} (re-verified). The regex (?<!\S)\\\[.+?\\\](?!\S) needs whitespace on both sides. The case with no whitespace at all, "items\\[0\\]" giving "items[0]", is encoded as escaped brackets.
- **Expected:** Probably math when punctuation follows a display \[...\].

### probablyMathQ misses common inline math [not encoded]

- **Repro:** `FormatChatOutput /@ {"$x_1$ here", "$x > y$", "$a < b$", "$|x|$", "$3.14$", "$1,000$", "$" <> StringRepeat["a+", 50] <> "$"}`
- **Observed:** Each one is shown as literal text with its dollar signs, e.g. "$x_1$ here" (re-verified). Subscripts, relations, absolute values and decimals don't pass the gate, and neither does math of 100 or more characters.
- **Expected:** Rendered math. For numbers, plain text without the dollars, as $$3.14$$ gives "3.14".

### Markdown escapes inside single-dollar math stop it from being math [not encoded]

- **Repro:** `FormatChatOutput["$a\\_b$"]; FormatChatOutput["$\\$5$"]`
- **Observed:** {"$a_b$"} and {"$$5$"}: literal text, with the backslash dropped (re-verified). probablyMathQ sees the escape sentinel characters, not the letters. "$$a\\_b$$" works.
- **Expected:** Math with TeX input "a\\_b" or "\\$5".

### Thousands-comma preprocessing mangles numbers like 1,000,000 [not encoded]

- **Repro:** `FormatChatOutput["$$1,000,000 + x$$"]`
- **Observed:** TeX input "1,000000 + x", serialized as "$$1,000000 + x$$" (re-verified). The $preprocessTeXRules pattern needs exactly 3 digits before the first comma.
- **Expected:** "1000000 + x", or the number left unchanged.

### Adjacent display math without a space is misparsed [not encoded]

- **Repro:** `FormatChatOutput["$$a$$$$b$$"]; MarkdownRoundTrip["$$a$$$$b$$"]`
- **Observed:** {math["a$", state Error], math["b"], "$"}; the round trip gives "$$a $b$$\\$" (re-verified).
- **Expected:** Two math cells, a and b.

### Table serialization escapes \| inside math a second time [not encoded]

- **Repro:** `MarkdownRoundTrip["| a | b |\n|---|---|\n| $$\\|x\\|$$ | 1 |"]`
- **Observed:** "| a           | b |\n| ----------- | - |\n| $$\\\\|x\\\\|$$ | 1 |": two backslashes before each pipe (re-verified). This changes the TeX and splits the cell when it is parsed again.
- **Expected:** The cell serializes as "$$\\|x\\|$$".

### CRLF next to math gives "\r \n" strings [not encoded]

- **Repro:** `FormatChatOutput["Text\r\n$$x^2$$\r\nMore"]; FormatChatOutput["$x$\r\n$y$"]`
- **Observed:** {"Text\r \n", math, "\r\nMore"}; {math, "\r \n", math} (re-verified). joinAdjacentStrings0 inserts " " before a trailing "\n" without considering "\r". This is a general formatter issue, not specific to math.
- **Expected:** "Text\n" (or "\r\n" kept intact). The test now requires a line break but doesn't pin the exact strings.

### Whitespace-only or padded numeric math [not encoded]

- **Repro:** `FormatChatOutput["$$ $$"]; FormatChatOutput["$$ 12 $$ items"]`
- **Observed:** {""} (nothing shown); {"12  items"}: the numeric clause returns the untrimmed math, which gives a double space (re-verified).
- **Expected:** Probably "$$ $$" left as text, and "12 items".

### Padded System names are TeX, unpadded ones are doc links [not encoded]

- **Repro:** `FormatChatOutput /@ {"\\( Sin \\)", "$$ Sin $$", "$$Sin$$"}`
- **Observed:** The first two are TeX math with input "Sin" (rendered as italic S i n); "$$Sin$$" is a TextRefLink. The systemNameQ clause of mathCell checks the untrimmed string, while makeTeXBoxes trims it.
- **Expected:** The same result with or without padding (trim before the clause checks).

### $$ math spans blank lines (paragraphs) [encoded]

- **Repro:** `FormatChatOutput["$$a\n\nb$$"]; FormatChatOutput["It costs $$5.\n\nOr $$3."]`
- **Observed:** {math["a\n\nb", "Error"]}; {"It costs ", math["5.\n\nOr", "Error"], "3."}. The $$ pattern ends at the next $$ anywhere, so it swallows paragraph breaks and gives an Error-state math box.
- **Expected:** Arguable. CommonMark/pandoc and MathJax-in-HTML would split the paragraphs first and leave the text alone, while LaTeX itself treats a blank line in display math as an error. Math-Invalid-Unknown-Command encodes the "$$a\n\nb$$" case.

### Display math is rendered inline [encoded]

- **Repro:** `FormatChatOutput["The formula $$E = mc^2$$ is famous."]; FormatChatOutput["Here:\n\n$$x^2$$\n\nmore"]`
- **Observed:** {"The formula ", math, " is famous."}: $$ math is the same inline Cell as $ math, never centered or set apart, and the blank lines around a display-math paragraph become single "\n".
- **Expected:** Probably intentional (it's a Chatbook design choice), but KaTeX and MathJax render $$ as centered display math. Encoded by Math-Delimiters-Display-Inline and Math-Delimiters-Display-Paragraph.

### Unterminated \[ shows as "[" while streaming [encoded]

- **Repro:** `FormatChatOutput["Text\n\\[ x", <|"Status" -> "Streaming"|>]`
- **Observed:** {"Text\n[ x"}: the backslash is dropped as a markdown escape until \] arrives. Finished output is the same, which is standard CommonMark (re-verified).
- **Expected:** Fine as a transient streaming display. A rewrite might prefer to keep "\\[" to avoid flicker.

### Adjacent math cells merge on serialization [encoded]

- **Repro:** `MarkdownRoundTrip["$x$$y$"]; MarkdownRoundTrip["\\(a\\)\\(b\\)"]`
- **Observed:** "$$x y$$" and "$$a b$$" (re-verified). The Serialization.wl rule Shortest["$$" ~~ a ~~ "$$$$" ~~ b ~~ "$$"] joins them.
- **Expected:** Probably intentional: the TeX is equivalent.

### Serialized TeX is the preprocessed or retried TeX, not the original [encoded]

- **Repro:** `MarkdownRoundTrip /@ {"$$α + β$$", "$$100,000 + x$$", "$$\\text{if \\alpha > 0}$$"}`
- **Observed:** "$$\\alpha + \\beta$$", "$$100000 + x$$", "$$\\text{if $\\alpha$ > 0}$$" (re-verified).
- **Expected:** Probably intentional, since this is the TeX that parsed. A rewrite must take "input" from the makeTeXBoxes result, not from the markdown source.

### Streaming math serializes through TeX export, not its source [not encoded]

- **Repro:** `MarkdownRoundTrip["$$\\frac{1}{2}$$", "Streaming"]; MarkdownRoundTrip["$x^2$", "Streaming"]; MarkdownRoundTrip["$$\\frac{a}{b$$", "Streaming"]`
- **Observed:** "(1/2)"; "``x``^2"; a "Failure[\"TeXAssistantError\", ...]" string (re-verified). StyleBox[..., "TeXAssistantBoxes"] has no "input".
- **Expected:** Only matters if streaming cells are ever serialized; normally the finished output replaces them. Not tested.

### Math that is a System symbol name becomes a doc link [encoded]

- **Repro:** `FormatChatOutput["$$Gamma$$"]; FormatChatOutput["$Plot$"]; FormatChatOutput["$Pi$"]`
- **Observed:** TextRefLink to paclet:ref/Gamma, Plot or Pi, serialized as "[Gamma](paclet:ref/Gamma)" (re-verified).
- **Expected:** Probably intentional, but it can misfire for math such as $Re$, $Det$ or $Pi$ that happens to be a System name.

## Tables (30)

### Text right after a table with no blank line renders on the same line as the table [not encoded]

- **Repro:** `FormatChatOutput["Before\n| a | b |\n|---|---|\n| 1 | 2 |\nAfter text here"]`
- **Observed:** TextData {"Before \n", table, "After text here"} with no line break after the table. The writer's screenshot shows the text drawn to the right of the bottom row. The round trip gives "...| 1 | 2 |After text here".
- **Expected:** {..., table, "\n", "After text here"}

### A list item or heading directly after a table (no blank line) is literal text [not encoded]

- **Repro:** `FormatChatOutput["| a | b |\n|---|---|\n| 1 | 2 |\n- item"] and "| a | b |\n|---|---|\n| 1 | 2 |\n## Next"`
- **Observed:** {table, "- item"} / {table, "## Next"} as plain text next to the table. The table consumed the "\n" that the bullet and section rules need.
- **Expected:** An InlineItem or InlineSection cell after the table

### Indented tables (including tables under list items) are broken [not encoded]

- **Repro:** `FormatChatOutput["  | a | b |\n  |---|---|\n  | 1 | 2 |"], "- Item\n  | a | b |\n  |---|---|\n  | 1 | 2 |", "| a | b |\n |---|---|\n | 1 | 2 |"`
- **Observed:** A headless grid {{a,b,""},{"",---,---},{"",1,2}}: the leading spaces of the later lines become an empty first cell, so the delimiter row is not recognized
- **Expected:** Trim each line before splitting, giving a headed table

### Trailing whitespace on rows or \r\n line endings break the delimiter row [not encoded]

- **Repro:** `FormatChatOutput["| a | b |  \n|---|---|  \n| 1 | 2 |  "] and FormatChatOutput["| a | b |\r\n|---|---|\r\n| 1 | 2 |\r\n\r\nAfter"]`
- **Observed:** Headless grid {{a,b},{---,---},{1,2}}. With CRLF, "\r\nAfter" is also left in the text.
- **Expected:** A headed table (trim each line and normalize \r\n)

### A header plus delimiter row with no body rows shows '---' as a data row (also seen while streaming) [not encoded]

- **Repro:** `FormatChatOutput["| a | b |\n|---|---|"]. Streaming: "| a | b |\n|---|", "| a | b |\n|---|---|\n", "| a | b |\n|---|---|\n| 1", "| a | b |\n|---|---|\n| 1 | 2". Also "| | |\n|---|---|".`
- **Observed:** A headless grid {{a,b},{---,---}} (or {---,""}). In the last two streaming states, the partial body row is also shown as text after the table.
- **Expected:** A headed table with no body (or the header shown as headings while streaming)

### While streaming, a partial later row is shown as text next to the table [not encoded]

- **Repro:** `FormatChatOutput["| a | b |\n|---|---|\n| 1 | 2 |\n| 3", <|"Status" -> "Streaming"|>] and the same ending in "| 3 | 4"`
- **Observed:** {table, "| 3"} / {table, "| 3 | 4"}: the raw row text appears on the table's line until its closing pipe arrives. Then it joins the table (this part is encoded in Tables-Streaming-Later-Rows).
- **Expected:** Hide the partial row, or add it to the table as it streams

### Headings are dropped when every body row is shorter than the header [not encoded]

- **Repro:** `FormatChatOutput["| a | b |\n|---|---|\n| 1 |"]`
- **Observed:** Grid {{a},{1}}: heading "b" is gone. The rectangular body is not padded, and TableForm truncates TableHeadings to the data width. The same thing loses headings when a pipe inside code, math or an entity adds a header cell.
- **Expected:** Pad body rows to the header width

### Two-column tables without outer pipes, and tables with only leading pipes, are not detected [not encoded]

- **Repro:** `FormatChatOutput["a | b\n--- | ---\n1 | 2"] and FormatChatOutput["| a | b\n|---|---\n| 1 | 2"]`
- **Observed:** Plain text. $$mdRow2 needs 2+ pipes per row; the 3-column leading-pipe form works.
- **Expected:** Tables (both are valid GFM)

### Consecutive lines of prose, numbered list items or inline code with 2+ pipes become a table [not encoded]

- **Repro:** FormatChatOutput["Use a | b | c syntax.\nAnd x | y | z."], "1. a | b | c\n2. d | e | f", "`a|b|c`\n`d|e|f`"
- **Observed:** Headless tables with cells like "Use a", "1. a", "`a" / "c`". (Bullet items with pipes stay list items, which is encoded.)
- **Expected:** Text. GFM needs a delimiter row; a heuristic may be needed because headless tables are supported on purpose.

### Code blocks whose every line has 2+ pipes become tables, whatever the fence language [not encoded]

- **Repro:** FormatChatOutput["```bash\ncat a.txt | grep x | sort\nls -l | wc -l | head\n```"] or "```wl\nf[x_Integer | x_Real | x_String] := x\ng[a | b | c] := 2\n```"
- **Observed:** A headless TextTableForm with cells "cat a.txt", "grep x", ... The code block is lost.
- **Expected:** Code stays code (convert only bare or markdown fences, or only content with a delimiter row)

### Blockquoted tables are broken [not encoded]

- **Repro:** `FormatChatOutput["> | a | b |\n> |---|---|\n> | 1 | 2 |"]`
- **Observed:** Headless grid {{>,a,b},{>,---,---},{>,1,2}}: the table rule beats the blockquote rule
- **Expected:** A BlockQuote containing a table

### Pipes inside math or inline code split cells and drop headings [not encoded]

- **Repro:** FormatChatOutput["| $|x|$ | b |\n|---|---|\n| 1 | 2 |"] and "| `a|b` | c |\n|---|---|\n| 1 | 2 |"
- **Observed:** Headings {"$","x"} or {"`a","b`"}. The last header cells are dropped (see the short-body quirk).
- **Expected:** At least keep all headings. GFM itself splits on unescaped pipes in code spans.

### Escaped pipes inside fenced tables are not handled [not encoded]

- **Repro:** FormatChatOutput["```\n| a \\| b | c |\n|---|---|\n| 1 | 2 |\n```"]
- **Observed:** Headings `a \` and `b`: the backslash is visible and "c" is lost. In the escaped path, $textDataFormatRulesNoMarkdownUnescape splits out the fence before the escape rules run, so makeTableCell splits the raw text on the escaped pipe. The same table without a fence works.
- **Expected:** Headings "a | b", "c", as for an unfenced table

### HTML entity pipes (&#124;, &vert;) split cells [not encoded]

- **Repro:** `FormatChatOutput["| a &#124; b | c |\n|---|---|\n| 1 | 2 |"]`
- **Observed:** Headings {"a","b"} and "c" is lost: importHTMLEntities runs before table detection, so the entity becomes a separator
- **Expected:** A literal | in the cell: headings "a | b", "c". GFM splits cells before decoding entities. LLMs use &#124; to put pipes in cells.

### Display math \[...\] in a cell breaks the table [not encoded]

- **Repro:** `FormatChatOutput["| \\[x^2\\] | b |\n|---|---|\n| 1 | 2 |"]`
- **Observed:** {"|", math cell, table with headings {"b",""}}. The escaped path's display-math regex in $textDataFormatRulesNoMarkdownUnescape takes the math out of the table before tables are detected.
- **Expected:** A table whose first heading is the math

### A whitespace-only line between two tables merges them [not encoded]

- **Repro:** `FormatChatOutput["| a | b |\n|---|---|\n| 1 | 2 |\n  \n| c | d |\n|---|---|\n| 3 | 4 |"]`
- **Observed:** One headed table with rows {1,2},{"",""},{c,d},{---,---},{3,4}. makeTableCell only splits on an exact "\n\n".
- **Expected:** Two tables, as with an empty line

### A delimiter row in any position other than the second is shown as data [not encoded]

- **Repro:** `FormatChatOutput["| a | b |\n| c | d |\n|---|---|\n| 1 | 2 |"]`
- **Observed:** Headless grid {{a,b},{c,d},{---,---},{1,2}}
- **Expected:** Rare in LLM output. GFM would give a paragraph "| a | b |" and a table with headings c, d.

### Escaped pipe inside inline code in a cell is double-escaped when serialized [not encoded]

- **Repro:** MarkdownRoundTrip["| `a\\|b` | c |\n|---|---|\n| 1 | 2 |"]
- **Observed:** "| a\\\\|b | c |..." (text a\\|b). The display (a|b) is correct.
- **Expected:** One escape (a\\|b), or the code with backticks

### Column alignment is lost in serialization [not encoded]

- **Repro:** `MarkdownRoundTrip["| a | b | c | d |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |"]`
- **Observed:** Delimiter row "| - | - | - | - |". createAlignedDelimiters only reads GridBoxAlignment, but the formatter sets ColumnAlignments. The same happens for headless tables.
- **Expected:** "| :- | :-: | -: | - |"-style delimiters

### A one-row table serializes as tab-separated text [not encoded]

- **Repro:** `MarkdownRoundTrip["| | |\n|---|---|\n| 1 | 2 |"] and MarkdownRoundTrip["| a | b |\n|---|---|\n| 1 | 2 |\n\n| x | y |"]`
- **Observed:** "1\t2". The second gives "...| 1 | 2 |\nx\ty". $simplifyTables turns single-row GridBoxes into tab-separated text.
- **Expected:** A markdown table with an empty header row

### Two adjacent tables serialize as one table [not encoded]

- **Repro:** `MarkdownRoundTrip["| a | b |\n|---|---|\n| 1 | 2 |\n\n| c | d |\n|---|---|\n| 3 | 4 |"]`
- **Observed:** "| a | b |\n| - | - |\n| 1 | 2 |\n| c | d |\n| - | - |\n| 3 | 4 |" (no blank line between them)
- **Expected:** A blank line between the two tables

### The blank line after a table is lost in serialization [not encoded]

- **Repro:** `MarkdownRoundTrip["Before\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter"]`
- **Observed:** "Before \n| a | b |\n| - | - |\n| 1 | 2 |\nAfter". In GFM "After" would become a table row. Formatting it again puts it on the table's line.
- **Expected:** "...| 1 | 2 |\n\nAfter"

### A leading '||' empty cell is dropped, and a body of only '||' shows '{}' [not encoded]

- **Repro:** `FormatChatOutput["|| b |\n| 1 | 2 |"] and FormatChatOutput["| a | b |\n|---|---|\n||"]`
- **Observed:** The first gives {{b,""},{1,2}}: cells shift left. The second gives a grid with a single literal "{}" item and no headings (the body {{}} is MatrixQ). '||' as the first row gives an empty row.
- **Expected:** {{"",b},{1,2}} (StringSplit[..., "|", All], dropping only the outer pieces). An empty row under the headings.

### All-empty columns: kept in a rectangular display, trimmed in a ragged display, always dropped by CellToString [not encoded]

- **Repro:** `FormatChatOutput["| a | b | |\n| 1 | 2 | |"] vs FormatChatOutput["| a | b | |\n| 1 | 2 |"]. MarkdownRoundTrip["| a |  | c |\n|---|---|---|\n| 1 || 3 |"]`
- **Observed:** The rectangular table shows an empty third column; the ragged one trims it (only the ragged case is encoded). Serialization drops every all-empty column, including middle ones: the last repro gives "| a | c |...". The writer's report said the rectangular empty column is serialized, which is wrong.
- **Expected:** Consistent handling: probably trim trailing empty columns in both, and keep middle columns in serialization

### <br> in cells is shown literally [not encoded]

- **Repro:** `FormatChatOutput["| a<br>b | c |\n|---|---|\n| 1 | 2 |"]`
- **Observed:** Cell text "a<br>b"
- **Expected:** A line break inside the cell

### Long cell text is clipped, not wrapped [not encoded]

- **Repro:** `FormatChatOutput["| Name | Description |\n|---|---|\n| x | " <> StringRepeat["long ", 50] <> "|"]`
- **Observed:** Text runs past the window edge (seen in the writer's screenshot; I did not re-check visually). The grid has no width or wrapping settings.
- **Expected:** Cells wrap within the available width

### A fenced table keeps a blank line before it, but an unfenced table does not [encoded]

- **Repro:** FormatMarkdown["Text\n\n```markdown\n| a | b |\n|---|---|\n| 1 | 2 |\n```\n\nAfter"] vs the same without the fence
- **Observed:** {"Text\n\n", table, "\nAfter"} vs {"Text \n", table, "\nAfter"}
- **Expected:** Probably the same spacing either way

### A lone row after a table and a blank line becomes its own table [encoded]

- **Repro:** `FormatMarkdown["| a | b |\n|---|---|\n| 1 | 2 |\n\n| x | y |"]`
- **Observed:** {headed table, "\n", headless 1-row table {{x,y}}}. A lone row anywhere else stays text. (Its serialization as "x\ty" is the one-row quirk.)
- **Expected:** Plausible either way

### Inline code and doc links in cells are serialized without backticks [encoded]

- **Repro:** MarkdownRoundTrip["| `code` | `Table` | `Plot[x, {x, 0, 1}]` |\n|---|---|---|\n| `x = 1` | y | c |"]
- **Observed:** "| code  | Table | Plot[x, {x, 0, 1}] |..." (grid items are serialized with $inlineCode = True)
- **Expected:** Probably intentional

### Headed tables have two nested PaneBoxes with the same ImageMargins [encoded]

- **Repro:** `FormatMarkdown["| a | b |\n|---|---|\n| 1 | 2 |"]`
- **Observed:** PaneBox[PaneBox[StyleBox[...], ImageMargins -> {{0,0},{5,5}}], ImageMargins -> {{0,0},{5,5}}]. Headless tables have one, so headed tables get twice the vertical margin.
- **Expected:** Probably unintentional. Pinned in Tables-Structure-Headed because it affects spacing.

## Codeblocks (24)

### Text after the language tag on the opening fence line swallows the code and shows the closing fence as content [not encoded]

- **Repro:** FormatMarkdown["```wl 1+1\n```"]
- **Observed:** A ChatPreformatted block with CodeLanguage "wl 1+1" whose content is the literal closing fence "```".
- **Expected:** Either an empty block with info string "wl 1+1" (CommonMark) or a WL block with code "1+1". Showing "```" as code is wrong.

### Fences of four or five backticks don't work, and longer fences can't wrap a ``` fence [not encoded]

- **Repro:** FormatMarkdown["````\n```wl\nx\n```\n````"]; FormatMarkdown["`````\nx\n`````"]; FormatMarkdown["``````\n```wl\nx\n```\n``````"]
- **Observed:** 4 backticks: language "`", code "```wl\nx", then a stray "`". 5 backticks: language "``", code "x", stray "``" text. 6 backticks work only because a leading ``` is deleted from the tag (tested in CodeBlocks-Six-Backtick-Fence), but an inner ``` fence still closes the block early.
- **Expected:** A fence closes only on a closing fence at least as long as the opener, so the inner fence is kept verbatim as code.

### Info strings with extra words are not recognized as the language [not encoded]

- **Repro:** FormatMarkdown["```python {cmd=true}\nx = 1\n```"] (likewise "```mathematica 13")
- **Observed:** A ChatPreformatted block with language "python {cmd=true}", not a Python ExternalLanguage cell.
- **Expected:** Use the first word of the info string as the language (CommonMark).

### Tilde fences are not supported [not encoded]

- **Repro:** `FormatMarkdown["~~~python\nx = 1\n~~~"]`
- **Observed:** {"~~~python\nx = 1\n~~~"} as raw text.
- **Expected:** A Python code block (CommonMark allows ~~~ fences).

### An empty WL code block becomes an empty transcript grid that serializes as garbage [not encoded]

- **Repro:** FormatMarkdown["```wl\n\n```"]; MarkdownRoundTrip["```wl\n\n```"]
- **Observed:** {Cell[BoxData[GridBox[{}, GridBoxAlignment -> ...]], "CellGroupBlock"]}, serialized as "GridBox[{}, \n GridBoxAlignment -> {...}]". parseCellGroupBlock[""] gives no rows and falls through to the grid case.
- **Expected:** An empty WL code block (like the empty ExternalLanguage cell from "```python\n\n```") that serializes as "```wl\n\n```".

### A transcript label with nothing after it inserts a raw private expression and draws an error box [not encoded]

- **Repro:** FormatMarkdown["```wl\nIn[1]:= x\nOut[1]=\n```"]
- **Observed:** The GridBox row is Wolfram`Chatbook`Formatting`Private`label["Output", "Out[1]="] (unconverted), so the front end draws the whole transcript as a small pink error box (rasterized).
- **Expected:** A labeled row with an empty output, or the dangling label dropped.

### The single In/Out label shortcut in parseCellGroupBlock is dead code [encoded]

- **Repro:** FormatMarkdown["```wl\nIn[1]:= 1+1\n```"]
- **Observed:** A one-row CellGroupBlock grid with an In[1]:= label and a nested code block. The branch { label["In"|"Out", _], s_String } :> Throw @ s never matches, because labels are created as label["Input", ...] and label["Output", ...].
- **Expected:** Probably intended: a plain WL code block with code "1+1". The current output looks reasonable, so it is tested as is (CodeBlocks-Transcript-Single-In-Label, -Single-Out-Label).

### Transcripts serialize as a markdown table instead of fenced In/Out code [not encoded]

- **Repro:** MarkdownRoundTrip["```wl\nIn[1]:= 1+1\nOut[1]= 2\n```"]
- **Observed:** "|         |                   |\n| ------: | :---------------- |\n| In[1]:= |  ```wl 1 + 1 ```  |\n| Out[1]= | 2                 |". Single-row grids give "In[1]:=\t\n```wl\n1 + 1\n```" or "Out[1]=\t2". A message on its own gives the bare message text with no fence.
- **Expected:** "```wl\nIn[1]:= 1 + 1\nOut[1]= 2\n```". Only content order is tested (CodeBlocks-Transcript-Serialization-Content).

### Printed and echoed text in transcripts is parsed as WL, so prose is spaced like code [not encoded]

- **Repro:** FormatMarkdown["```wl\nIn[1]:= Print[\"Hello, world! It's done.\"]\nDuring evaluation of In[1]:= Hello, world! It's done.\n```"]
- **Observed:** The Print cell holds RowBox[{"Hello", ",", RowBox[{RowBox[{"world", "!"}], " ", RowBox[{"It", "'"}], "s", ...}]}] and renders as "Hello, world ! It' s done." (rasterized). Print/Echo/EchoTiming/Output rows all go through StringToBoxes[s, "WL"], including CodeCheckFix.
- **Expected:** Printed text shown as written (at least for Print rows, which are usually text).

### Multi-line WL code serializes with a tab after every line break [not encoded]

- **Repro:** MarkdownRoundTrip["```wolfram\nx = {1, 2, 3};\nTotal[x]\n```"]; MarkdownRoundTrip["```wl\nf[x_] := Module[{y = x},\n  y + 1\n]\n```"]
- **Observed:** "```wl\nx = {1, 2, 3};\n\tTotal[x]\n```" and "```wl\nf[x_] := Module[{y = x}, \n\t  y + 1\n\t]\n```". adjustBoxSpacing turns \n into \[IndentingNewLine], which the serializer writes as \n\t.
- **Expected:** The lines as written, without added tabs or the space before the line break. The test strips \n\t to \n.

### CRLF line endings inside code blocks (any language) and text lose their line breaks in the display [not encoded]

- **Repro:** FormatMarkdown["```python\r\na = 1\r\nb = 2\r\n```"]; FormatMarkdown["```wl\r\na = 1;\r\nb = 2\r\n```"]; FormatMarkdown["Line one\r\nLine two\r\n\r\n```foo\r\na\r\nb\r\n```"]
- **Observed:** Inner \r\n is kept ("a = 1\r\nb = 2"; for WL the boxes get RowBox[{"\r\nb", "=", "2"}]). The front end draws "a = 1b = 2", "ab" and "Line oneLine two" on single lines (rasterized). Only the \r at the ends of the fence line and the code is trimmed. WL serialization keeps \r\n.
- **Expected:** Normalize \r\n to \n before formatting, so the lines display as with \n endings.

### An image-only code block with leading whitespace disappears [not encoded]

- **Repro:** FormatMarkdown["```\n  ![alt](file:///tmp/some-existing.png)  \n```"]
- **Observed:** {""}. makeCodeBlockCell matches the image after StringTrim but calls image @ code on the untrimmed code. image[str_String] takes First @ StringSplit[...], which is the leading "  ".
- **Expected:** The image, the same as without the leading spaces.

### The streaming freeform prompt shows stray quotes and extra arguments [not encoded]

- **Repro:** FormatMarkdown["```wl\n\[FreeformPrompt][\"population of france\"]\n```", "Streaming"]; FormatMarkdown["```wl\n\[FreeformPrompt][\"q\", \"Expression\"]\n```", "Streaming"]; FormatMarkdown["```wl\n\[FreeformPrompt][\"population of fr"]
- **Observed:** The string rule "\[FreeformPrompt][\"" ~~ q: Except["]"].. captures q including the closing quote (shows 'population of france"') and any extra argument (shows 'q", "Expression"'). In finished mode, an unterminated query goes through the box rule and shows a leading quote ('"population of fr').
- **Expected:** Only the query text, without quotes or other arguments. Tests only check that the query text and an OverlayBox are present.

### A partial PacletSymbol shows an extra closing bracket while streaming [not encoded]

- **Repro:** FormatMarkdown["```wl\nPacletSymbol[\"Chatbook\", \"Fo", "Streaming"] (also with "Wolfram/Chatbook")
- **Observed:** The block shows PacletSymbol["Chatbook", "Fo]. formatPacletSymbol appends "]" to try parsing, and when that fails it returns the modified string instead of the original.
- **Expected:** The partial text as written: PacletSymbol["Chatbook", "Fo.

### A partial closing fence or language tag is shown, while streaming and in truncated responses [not encoded]

- **Repro:** FormatMarkdown["Here:\n\n```python\nprint(1)\n``", "Streaming"]; FormatMarkdown["Here:\n\n```pyth", "Streaming"]; FormatMarkdown["```python\nprint(1)\n``"]; FormatMarkdown["```wl\n1+1\n``"]
- **Observed:** The code shows "print(1)\n``" until the third backtick arrives. An opening fence whose language tag hasn't ended shows as raw text "```pyth". A finished truncated response keeps the "``" too, including in WL code (RowBox[{RowBox[{"1","+","1"}], "\[IndentingNewLine]", "``"}]).
- **Expected:** Hide trailing backticks at the end of a code block and a partial opening fence line, as is already done for a lone "```".

### The escaped-markdown path drops the line break after a code block [not encoded]

- **Repro:** FormatMarkdown["Before \\*x\\*\n\n```python\nx\n```\n\nAfter"] vs FormatMarkdown["Before x\n\n```python\nx\n```\n\nAfter"]
- **Observed:** Escaped path: {"Before *x* \n", block, "After"}. Normal path: {"Before x \n", block, "\nAfter"}. Serialization differs ("```\nAfter" vs "```\n\nAfter").
- **Expected:** The same separator as the normal path. Only the text before the block is asserted for the escaped path.

### An opening fence with a language but no code shows the language as text [not encoded]

- **Repro:** FormatMarkdown["```python\n"] (also while streaming)
- **Observed:** {"python"}: the backticks are dropped and the tag is shown as plain text.
- **Expected:** Nothing (like a lone "```"), or an empty Python block.

### A tagged fence holding only a markdown table renders as a table [not encoded]

- **Repro:** FormatMarkdown["```markdown\n| a | b |\n|---|---|\n| 1 | 2 |\n```"] (also ```python)
- **Observed:** A TextTableForm table cell with no code block, whatever the language. The rule checks StringMatchQ[code, $$mdTable] without looking at the tag.
- **Expected:** Rendering is plausible for an untagged fence (tested as CodeBlocks-Table-Only-Block). A tagged fence, especially ```markdown where the user asked for source, should stay code.

### DateObject literals in code are evaluated and normalized [encoded]

- **Repro:** MarkdownRoundTrip["```wl\nDateObject[{2024, 13, 45}]\n```"]; MarkdownRoundTrip["```wl\nDateObject[{2024, 1, 15, 10, 30, 0}]\n```"]
- **Observed:** Displayed as a date and serialized as "```wl\nDateObject[{2025, 2, 14}, \"Day\"]\n```". DateObject[{2024, 1, 15}] gains "Day". A date with a time serializes with the kernel's time zone ("DateObject[{2024, 1, 15, 10, 30, 0}, \"Instant\", \"Gregorian\", -5.]"), so chat history depends on the machine. Only date-only lists are tested.
- **Expected:** Plausibly intentional (it's what the expression evaluates to), but the model's code changes. Date-only cases are tested as is.

### Streaming output loses fences or syntax when serialized [not encoded]

- **Repro:** MarkdownRoundTrip["```python\nprint(1)\n```", "Streaming"]; MarkdownRoundTrip["```wl\n\[FreeformPrompt][\"population of france\"]\n```", "Streaming"]
- **Observed:** "print(1)" with no fence, because streaming ChatPreformatted cells have no TaggingRules. The freeform prompt gives "```wl\npopulation of france\n```". ResourceFunction gives "```wl\n[\[FilledSmallSquare]]\tBirdSay [\"hi\"]\n```". Plain streaming WL code does round-trip.
- **Expected:** Only matters if streaming display content is ever serialized. Otherwise fenced code with the original syntax.

### Streaming WL code shows raw attachment URIs [not encoded]

- **Repro:** FormatMarkdown["```wl\nTotal[<!attachment://content-xxxxx!>]\n```", "Streaming"] with a real key from MakeExpressionURI
- **Observed:** Cell[BoxData["Total[<!attachment://content-38ru7!>]"], "ChatCodeActive"]: the raw URI is shown until the block is finished, then it becomes the expression. preprocessSandboxString (which turns URIs into InlinedExpression) is skipped while streaming, so StringToBoxes' streaming placeholder never applies in code blocks.
- **Expected:** A placeholder (\[LeftSkeleton]\[Ellipsis]\[RightSkeleton], as StringToBoxes[s] gives while streaming) instead of the raw URI.

### Code that mentions TOOLCALL: anywhere becomes inline code with stray backticks [not encoded]

- **Repro:** FormatMarkdown["```python\nprint('TOOLCALL: x')\n```"]; MarkdownRoundTrip["```python\nprint('TOOLCALL: x')\n```"]
- **Observed:** toolCallStringFreeQ rejects the code, so the fence rule doesn't match and the inline-code rule takes "``" ... "``": a ChatCodeInlineTemplate cell holding "`python\nprint('TOOLCALL: x')\n`", shown with visible backticks (rasterized). It serializes as "``\\`python\nprint('TOOLCALL: x')\n\\```".
- **Expected:** A Python code block. Only code that is an actual tool call (e.g. starts with TOOLCALL:) should be excluded.

### A fenced code block inside a block quote is shown as plain text [not encoded]

- **Repro:** FormatMarkdown["> ```python\n> x = 1\n> ```"]; MarkdownRoundTrip["> ```python\n> x = 1\n> ```"]
- **Observed:** The block quote rule matches first (at an earlier position), giving a BlockQuote cell that shows "python" and "x = 1" as quoted text with the backticks gone (rasterized). It serializes as "> \"python\n> x = 1\n> \"".
- **Expected:** A Python code block inside the quote (or at least the fence text kept verbatim).

### A missing relative image in a code block emits URLParse::invuri [not encoded]

- **Repro:** FormatMarkdown["```\n![alt](cb-missing-image.png)\n```"] in a kernel where $CloudBase is Automatic
- **Observed:** "URLParse::invuri: The URI Automatic is invalid." from cloudURLQ -> URLParse[$CloudBase, "Domain"] when the import fails. The output is the ImageNotFound template. This is in the images area, but code blocks reach it. The tests use an existing local file.
- **Expected:** No message.

## Escapes (24)

### Escaped path drops the line break before a code block unless there is a blank line [not encoded]

- **Repro:** FormatChatOutput["Text \\$5:\n```wl\n1+1\n```"]; FormatChatOutput["1. Step \\$5\n   ```wl\n   1+1\n   ```\n2. Next"]
- **Observed:** {"Text $5:", code} (plain path: {"Text $5: \n", code}). For the list: {"1. Step $5", code, "2. Next"} (plain path: {"1. Step $5\n   ", code, "\n2. Next"}). The writer checked in the front end that the text before the code block wraps badly. When the fence is on the same line ("Text \\$5: ```wl"), the plain path gives "Text $5: " with no line break either, so that variant is not a path difference.
- **Expected:** Same as the plain path. Cause: each text part is formatted on its own and trimmed by joinAdjacentStrings, and textBeforeCodeBlock only covers text that ends with "\n\n".

### Escaped path drops the line break before a think tag [not encoded]

- **Repro:** `FormatChatOutput["Answer \\$5\n\n<think>more</think>\n\nEnd"]`
- **Observed:** {"Answer $5", ThoughtsOpener, "\nEnd"}, which shows "Answer $5" and the opener on one line.
- **Expected:** Plain path: {"Answer $5 \n", ThoughtsOpener, "\n\nEnd"}.

### Spacing after a think tag differs between paths [not encoded]

- **Repro:** `Compare FormatChatOutput["<think>thoughts</think>\n\nAnswer \\$5"] with the same text using a plain $5. Same while streaming, and after a code block inside think content.`
- **Observed:** Escaped: {opener, "\nAnswer $5"}. Plain: {opener, "\n\nAnswer $5"}, which shows one extra blank line. Inside thoughts after a code block: "b" vs "\nb".
- **Expected:** Both paths the same. The tests accept either form.

### Two adjacent code blocks lose the line break between them in the escaped path [not encoded]

- **Repro:** FormatChatOutput["```wl\n1\n```\n```wl\n2\n```\n\\$5"]
- **Observed:** {code, code, "$5"} (the writer saw the "$" sit next to the second block in the front end). With a blank line between the blocks, both paths give code, "\n", code (now tested).
- **Expected:** Plain path: {code, "\n", code, "\n$5"}. The missing leading "\n" on text after a single code block is invisible and is accepted by the tests.

### Three or more line breaks before a code block: plain path shows an extra blank line, escaped path collapses them [encoded]

- **Repro:** FormatChatOutput["Text $5:\n\n\n```wl\n1+1\n```"] vs the same with \\$5
- **Observed:** Plain: {"Text $5:\n\n", code}. Escaped: {"Text $5: \n", code}, because reformatTextBeforeCodeBlock explicitly collapses the trailing newlines. In prose (no code block), both paths keep all blank lines ("A\n\n\n\nB").
- **Expected:** The same in both paths. The escaped result is encoded (Escapes-Text-Before-Code-Block-Extra-Newlines).

### Whitespace-delimited \[...\] is display math even when it is meant as escaped brackets, and the whitespace around it is removed [not encoded]

- **Repro:** `FormatChatOutput["Use \\[1, 2\\] here"]; FormatChatOutput["List \\[1\\]"]; FormatChatOutput["| a | b |\n|---|---|\n| \\[1\\] | 2 |"]`
- **Observed:** "Use1, 2here" (digit-only math becomes plain text, and the brackets and spaces are gone); "List1"; the table is split into a 1-row table followed by "|1| 2 |". ("f\\[x\\]" correctly gives "f[x]".)
- **Expected:** "Use [1, 2] here" and an intact table. At minimum the surrounding spaces should be kept.

### Whitespace and line breaks around \[...\] display math are removed [not encoded]

- **Repro:** `FormatChatOutput["Display \\[x^2\\] here"]; FormatChatOutput["Formula:\n\n\\[x^2\\]\n\nDone"]`
- **Observed:** {"Display", math, "here"} and {"Formula:", math, "Done"}, which shows "Displayx²here" on one line.
- **Expected:** Spacing kept, as for $$x^2$$ ({"Display \n", math, "\nhere"}). FormattingMath.wlt already notes this as a known issue.

### Inline code unescapes \*, \_, \# and \| [not encoded]

- **Repro:** FormatChatOutput["Use `\\*` here"]
- **Observed:** The code shows "*". Since #1794, \\, \[ and \] in inline code keep their backslash, so `\[Alpha]` and `StringReplace[s, "\\" -> "/"]` show as written (Escapes-Inline-Code-Backslashes-Kept-GH#1794).
- **Expected:** CommonMark keeps backslashes in code spans. These four can only be kept once serialization stops escaping them in inline code (see "Inline code content is markdown-escaped when serialized"). Unescaping \$ and \` is intentional (the existing `\$Failed` test) and stays encoded.

### A backslash before the closing backtick of a code span escapes the backtick (new) [not encoded]

- **Repro:** FormatChatOutput["Use `C:\\Users\\` here"]; FormatChatOutput["Press `\\` key"]; FormatChatOutput["Press `\\` key and `x`"]
- **Observed:** "Use `C:\Users` here" as plain text, with the trailing backslash gone and no code formatting; "Press `` key"; in the last case the code span becomes "` key and " followed by text "x`".
- **Expected:** Code spans "C:\Users\" and "\" (backslash escapes don't apply inside code spans). Escapes are replaced across the whole text before code spans are found.

### Only nine characters are escapable; other CommonMark escapes show their backslash [not encoded]

- **Repro:** `FormatChatOutput /@ {"\\- not a bullet", "1\\. Not a list", "\\> not a quote", "~~strike \\~ x~~", "\\+ plus", "Line\\\nbreak", "\\-\\-\\-"}`
- **Observed:** The backslash is shown in every case ("\- not a bullet", "1\. Not a list", ...). With "\~" the strikethrough also fails, and there is no hard line break.
- **Expected:** A backslash before any ASCII punctuation is removed (CommonMark).

### An HTML entity for a backslash becomes an escape only in the escaped path [not encoded]

- **Repro:** `FormatChatOutput["&#92;* entity"] vs FormatChatOutput["&#92;* entity \\$5"]`
- **Observed:** Plain path: "\* entity". Escaped path: "* entity $5" (entities are decoded before escapes are replaced). Entity-encoded stars (&#42;x&#42;) act as emphasis in both paths.
- **Expected:** Literal backslash in both paths. Rare.

### Fenced tables in escaped text keep cell backslashes and have different spacing from the plain path [not encoded]

- **Repro:** FormatChatOutput["Intro\n\n```\n| a | b |\n|---|---|\n| \\* | 1 |\n```"]; FormatChatOutput["Intro \\$5\n\n```\n| a | b |\n|---|---|\n| 1 | 2 |\n```\n\nAfter"] vs the same with $5
- **Observed:** Fenced table cell "\*" (an unfenced table shows "*"). Spacing: escaped {"Intro $5 \n", table, "After"} vs plain {"Intro $5\n\n", table, "\nAfter"}.
- **Expected:** Cell escapes handled as in unfenced tables, and the same spacing in both paths. Escapes-Fenced-Table checks only the rows.

### An escaped backslash before a marker changes meaning after a round trip [not encoded]

- **Repro:** `MarkdownRoundTrip["a\\\\*b*"]; MarkdownRoundTrip["a\\\\\\*b*"]`
- **Observed:** "a\" + italic b serializes as "a\*b*", which re-formats as "a*b*". The display "a\*b*" serializes as "a\*b\*", which re-formats as "a*b*".
- **Expected:** Backslashes before escapable characters are escaped when serialized.

### Brackets are not escaped on serialization, so escaped link syntax becomes a link [not encoded]

- **Repro:** `MarkdownRoundTrip["\\[not a link\\](https://example.com) end"]`
- **Observed:** "[not a link](https://example.com) end", which formats as a hyperlink.
- **Expected:** "\[not a link\](https://example.com) end".

### Table cell text is not escaped on serialization [not encoded]

- **Repro:** `MarkdownRoundTrip["| a | b |\n|---|---|\n| \\*star\\* | x |"]`
- **Observed:** "| *star* | x |", which re-formats as italic (escapeMarkdownCharactersQ is False for TextTableForm).
- **Expected:** "\*star\*" in the cell.

### A string item that is exactly an operator such as "*" is padded and not escaped when serialized [not encoded]

- **Repro:** MarkdownRoundTrip["\\**partial*"]; MarkdownRoundTrip["Use `\\*` here"]; CellToString[Cell[TextData[{"*"}], "ChatOutput"]]
- **Observed:** "* *partial*" (re-formats as a bullet item); "Use `` * `` here"; "*".
- **Expected:** "\**partial*", "Use ``*`` here".

### Inline code content is markdown-escaped when serialized [not encoded]

- **Repro:** MarkdownRoundTrip["Use `x*y` and `a|b` and `#x` and `$y` here"]
- **Observed:** "Use ``x\*y`` and ``a\|b`` and ``\#x`` and ``\$y`` here". The inline-code rule in Serialization.wl sets $escapeMarkdown = False, but boxToString[cell: Cell[a_, ___]] turns it back on for the inner Cell[code, Background -> None]. The display survives a round trip only because the formatter unescapes inside code spans.
- **Expected:** Code serialized verbatim (``x*y``). Fix this together with the formatter's code-span unescaping. Changed from encoded:true: the test now ignores the backslashes.

### Block quotes serialize with literal quote characters (both paths) [not encoded]

- **Repro:** `MarkdownRoundTrip["> quote star"]`
- **Observed:** "> \"quote star\""; re-formatting shows the quotes inside the block quote.
- **Expected:** "> quote star". Not specific to escapes (blocks area).

### CRLF line endings: the escaped path trims all line breaks around code blocks [not encoded]

- **Repro:** FormatChatOutput["Text \\$5\r\n\r\n```wl\r\n1+1\r\n```\r\n\r\nAfter"]
- **Observed:** {"Text $5", code, "After"}. Plain path: {"Text $5\r\n\r \n", code, "\r\n\r\nAfter"}.
- **Expected:** CRLF normalized, so both paths give {"Text $5 \n", code, "\nAfter"}.

### A tool call wrapped in a code fence leaves the closing fence, which starts a code block that swallows the following text (both paths) [not encoded]

- **Repro:** FormatChatOutput["Before\n```\nTOOLCALL: wolfram_language_evaluator\n{\"code\":\"1+1\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\n2\nENDRESULT(def456)\n```\nAfter"]
- **Observed:** {"Before \n", InlineToolCall, "\n", <untagged code block containing \"After\">}.
- **Expected:** Consume the closing fence too and show "After" as text. Not specific to escapes.

### Private-use placeholder text in the input is converted when the text has an escape [not encoded]

- **Repro:** `FormatChatOutput["x \[EntityStart]42\[EntityEnd] y \\$"]`
- **Observed:** "x * y $".
- **Expected:** Text left as typed. Extremely unlikely in practice.

### Escaped path drops paragraph indentation after the last code block (new, minor) [not encoded]

- **Repro:** FormatChatOutput["```wl\n1\n```\n\n   After \\$5"] vs the same with $5
- **Observed:** Escaped: {code, "After $5"}. Plain: {code, "\n   After $5"}, which keeps the 3-space indentation. Between two code blocks, both paths keep the indentation (encoded in Escapes-Text-Before-Code-Block-Indentation).
- **Expected:** The same in both paths. CommonMark would strip up to 3 leading spaces, so the escaped result may be the better one.

### Plaintext code block round trip removes doubled backslashes again on each re-format (new, minor) [not encoded]

- **Repro:** FormatMarkdown[MarkdownRoundTrip["```text\na\\\\\\\\b\n```"]]
- **Observed:** "a\\\\b" (4 backslashes) displays "a\\b", serializes as "```Plaintext\na\\b\n```", and re-formats as "a\b".
- **Expected:** A stable round trip, either by re-escaping on serialization or by applying unescapePlainTextCodeBlock only to model output. Low impact.

### Speech input parts always give an internal failure (new, both paths) [not encoded]

- **Repro:** `FormatChatOutput["<speech-input>\n<transcript>\nhello\n</transcript>\n</speech-input>\n\nAnswer"]`
- **Observed:** A General::ChatbookInternal message, with a Failure in the TextData. formatSpeechInput calls templateBox[<|"Audio" -> ..., "Transcript" -> ...|>, "NotebookAssistantSpeechInput"], but templateBox only accepts a List of arguments.
- **Expected:** A NotebookAssistantSpeechInput cell. The bug is in SpeechInput.wl, not escape-specific, and no test covers it.

## Toolcalls (23)

### Closing code fence after a fenced tool call starts a new code block [not encoded]

- **Repro:** FormatChatOutput["Text\n```\nTOOLCALL: web_fetcher\n{\"x\":\"1\"}\nRESULT\nok\nENDRESULT(efgh5678)\n```\nAfter"] (the same happens with '/wl\n1+1\n/exec\nRESULT\nx\nENDRESULT(abc123)' inside the fence)
- **Observed:** {"Text\n", InlineToolCall, "\n", ChatCodeBlock containing "After"}. The tool call rule consumes only the opening fence, so the leftover "```\nAfter" becomes an unterminated code block. (Re-verified.)
- **Expected:** The closing fence is consumed or dropped too, and "After" is plain text

### A literal "TOOLCALL:" in prose swallows the rest of the response [not encoded]

- **Repro:** `FormatChatOutput["The TOOLCALL: prefix starts a call.\n\nMore text **here**."]; also FormatChatOutput["Use TOOLCALL: web_fetcher {\"a\":1} to fetch.\nMore."]`
- **Observed:** {"The ", InlineToolCall} with the 'Using tool...' loading label. Everything after "TOOLCALL:" becomes one tool call (no ENDRESULT, so it matches to EndOfString). If a '{' follows, it shows 'Using Web Fetcher' with a spinner instead. (Re-verified.)
- **Expected:** Plain text in finished output unless it looks like a real tool call (e.g. at the start of a line, followed by a tool name and JSON)

### An unterminated tool call in finished output hides the text after it [not encoded]

- **Repro:** `FormatChatOutput["Text\n\nTOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDTOOLCALL\n\nMore text after the call."]; Block[{$ChatHandlerData = <|"ToolShortNames" -> <|"wl" -> wlTool|>|>}, FormatChatOutput["Text\n/wl\n1+1\n/exec\nMore text after the call."]]`
- **Observed:** {"Text\n", InlineToolCall}: the ToolCall tag includes "More text after the call.", and the text is only visible in the Raw tab, behind a 'Using Web Fetcher' spinner or 'Using tool...' label. This happens when the LLM keeps writing after a tool call that was never evaluated (no ENDRESULT appended). The writer's ToolCalls-Simple-Registered-Command test encoded this; I changed it.
- **Expected:** In finished output an unterminated tool call ends at its last line ("/exec" or "ENDTOOLCALL"), and the text after it is shown. While streaming, extending to the end is correct.

### Lowercase "toolcall:" is a tool call (IgnoreCase) but can't be parsed [not encoded]

- **Repro:** `FormatChatOutput["toolcall: web_fetcher\n{\"x\":\"1\"}\nRESULT\nok\nENDRESULT(efgh5678)\n\nDone."]`
- **Observed:** StringSplit uses IgnoreCase -> True, so this is split out as a tool call. parseToolCallID and parsePartialToolCallString are case-sensitive, so the finished cell shows only the 'Using tool...' loading label (TaggingRules <|ToolCall -> ...|>). (Re-verified.)
- **Expected:** Either case-sensitive recognition (plain text) or case-insensitive parsing

### TOOLCALL syntax with ToolMethod "Simple" causes an internal failure [not encoded]

- **Repro:** `Block[{$ChatHandlerData = <|"ToolShortNames" -> <|"wl" -> wlTool|>, "ChatNotebookSettings" -> <|"ToolMethod" -> "Simple"|>|>}, FormatChatOutput["Text\nTOOLCALL: web_fetcher\n{\"url\":\"q\"}\nRESULT\nok\nENDRESULT(zz9)\nAfter"]]`
- **Observed:** General::ChatbookInternal from parsePartialToolCallString (ConfirmMatch 'Command'). With the Simple method, the simple branch is used for every partial parse, and it fails when the string doesn't start with '/command'. (Re-verified.)
- **Expected:** TOOLCALL strings use the TOOLCALL parser (or the loading label) whatever the tool method

### /retry without a preceding tool call deletes surrounding line breaks; /retry is not anchored to line start [not encoded]

- **Repro:** `FormatChatOutput["Hello\n/retry\nWorld"]; FormatChatOutput["Type /retry to try again."]; FormatChatOutput[tc <> "\nBad.\n/retry\nAlso bad\n/retry\nDone."]; FormatChatOutput[tc <> "\nType /retry to retry. More text"] where tc is a finished TOOLCALL`
- **Observed:** "HelloWorld"; "Typeto try again."; {DiscardedMaterial, "\nAlso badDone."}; {DiscardedMaterial, "\nto retry. More text"}. The rule $$ws ~~ "/retry" ~~ (WhitespaceCharacter|EndOfString) eats the whitespace on both sides and matches mid-line. discardBadToolCalls deletes it when there's no tool call before it, and a mid-line '/retry' after a tool call discards that tool call. (Re-verified.)
- **Expected:** Only a line consisting of /retry is a retry. When nothing is discarded, the line break is kept ("Hello\nWorld"), and mid-line text is left alone.

### FailedToolCall cells serialize as the Failure expression instead of the tool call text [not encoded]

- **Repro:** `Block[{$ChatHandlerData = <|"ChatNotebookSettings" -> <|"ToolMethod" -> "Simple"|>|>}, MarkdownRoundTrip["Before\n/zz\nfoo\n/exec\nRESULT\nx\nENDRESULT(abc998)\nAfter"]] (also failures from $toolEvaluationResults)`
- **Observed:** "Before \nFailure[\"InvalidToolCall\", <|\"MessageTemplate\" -> ..., \n  \"MessageParameters\" -> {\"zz\"}|>]\nAfter". Serialization.wl only has a boxToString rule for "InlineToolCall" cells, so the FailedToolCall cell falls back to its boxes, although its TaggingRules have "ToolCall". (Re-verified.)
- **Expected:** "Before\n/zz\nfoo\n/exec\nRESULT\nx\nENDRESULT(abc998)\nAfter" (the ToolCall tagging rule), as for InlineToolCall

### All-CRLF tool calls show 'Using' with a progress indicator after finishing [not encoded]

- **Repro:** `FormatChatOutput[StringReplace["A\n\nTOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nok\nENDRESULT(abcd1234)\n\nB", "\n" -> "\r\n"]]`
- **Observed:** The partial parser looks for "RESULT\n" ~~ r ~~ "\nENDRESULT", which fails when the RESULT/ENDRESULT lines use \r\n. Result is "", so the finished opener shows 'Using Web Fetcher' with the spinner, and Parameters keep the \r characters. Correction to the writer's report: Chatbook appends the result with \n (SendChat.wl), so the common mixed case (LLM text with \r\n, appended result with \n) works: 'Used', now tested in ToolCalls-Mixed-Line-Endings. Only fully converted text (e.g. reloaded or pasted with CRLF) hits this.
- **Expected:** Normalize line endings: 'Used', with the result parsed

### A tool call inside a bullet item is not recognized [not encoded]

- **Repro:** `FormatChatOutput["- Use TOOLCALL: web_fetcher\n{\"url\":\"https://example.com/8\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nok8\nENDRESULT(abc8)\nText"]`
- **Observed:** InlineItem "Use TOOLCALL: web_fetcher", then the JSON/RESULT/ENDRESULT lines as raw text. The bullet rule matches at an earlier position, so it wins over the tool call rule. A tool call on the line after a bullet list works. (Re-verified.)
- **Expected:** The tool call is recognized, as it is mid-line in plain text

### Fenced code block whose content contains 'TOOLCALL:' becomes inline code [not encoded]

- **Repro:** FormatChatOutput["Example:\n```\nUse TOOLCALL: name\n```\nMore text"] or FormatChatOutput["Example:\n```\nfoo\nTOOLCALL: x\n{}\nRESULT\nok\nENDRESULT(abc10)\n```\nMore"]
- **Observed:** {"Example:\n", ChatCodeActive inline code, "\nMore text"}. toolCallStringFreeQ rejects the code block rule, and then the "``" ~~ code ~~ "``" inline code rule matches the whole fenced block (code "`\nUse TOOLCALL: name\n`"). In the second case the tool call isn't formatted either. (Re-verified.)
- **Expected:** An ordinary code block, or a code block plus a tool call when the content really is a tool call

### Simple command with arguments or a tab on its line: '/exec' becomes the command [not encoded]

- **Repro:** `FormatChatOutput["Text\n/wl 1+1\n/exec\nRESULT\nx\nENDRESULT(abc123)\nAfter"]; FormatChatOutput["Text /wl\n1+1\n/exec\nRESULT\nx\nENDRESULT(abc124)\nAfter"]; FormatChatOutput["Text\n/wl\t\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(id)\nAfter"]`
- **Observed:** "Text\n/wl 1+1\n" stays text, and "/exec\nRESULT\nx\nENDRESULT(abc123)" becomes the tool call (any line with only '/cmd' and a later ENDRESULT is a tool call). New: a tab after the command is the same, because $$eol only allows spaces. If the ID is in $toolEvaluationResults, the '/exec...' tool call is even fully parsed and shown as 'Used Wolfram Language Evaluator', while the command and code stay text above it. (Re-verified.)
- **Expected:** The whole malformed call is one tool call or stays text. '/exec' is never the command, and trailing tabs are accepted like spaces (parseToolCallID already allows any whitespace).

### Code block starting with a registered short command swallows the closing fence and the rest [not encoded]

- **Repro:** Block[{$ChatHandlerData = <|"ToolShortNames" -> <|"wl" -> wlTool|>|>}, FormatChatOutput["Code:\n```\n/wl\n1+1\n```\nAfter"]]
- **Observed:** {"Code:\n", InlineToolCall} with ToolCall "/wl\n1+1\n```\nAfter" (loading label). The code block is rejected because its content is a simple tool call, the fence prefix is dropped, and with no ENDRESULT the tool call runs to the end of the response. (Re-verified.)
- **Expected:** The tool call ends at the closing fence, or the block stays a code block

### Streaming discarded material placeholder uses the tool (blue) colors [not encoded]

- **Repro:** `FormatChatOutput[tc1 <> "\nBad.\n/retry\n" <> tc2 <> "\nDone.", <|"Status" -> "Streaming"|>]`
- **Observed:** fakeOpenerView always uses openerViewColors["Tool"], so the DiscardedMaterial placeholder is blue RGBColors while streaming and turns gray (GrayLevel 'Discarded' colors) when the response finishes. (Re-verified.)
- **Expected:** Gray 'Discarded' colors in both states

### Formatting a very long single line is very slow (affects tool results) [not encoded]

- **Repro:** `AbsoluteTiming[FormatChatOutput[StringRepeat["word ", 2000]]]; AbsoluteTiming[FormatChatOutput["TOOLCALL: web_fetcher\n{\"url\":\"q\"}\nRESULT\n" <> StringRepeat["word ", 2000] <> "\nENDRESULT(x)"]]`
- **Observed:** My re-measurement: 5 KB single line 0.28 s, 10 KB 2.5 s (the writer measured 20 KB at about 18 s); the same 10 KB with line breaks takes 0.017 s. A finished tool call with a 10 KB single-line result takes 3.5 s, because toolAutoFormatter formats the whole result as markdown when the opener is built. Streaming is fast (placeholder only).
- **Expected:** Close to linear time, and tool results formatted lazily or cheaply

### Line breaks between a table or block quote and a following tool call are lost in serialization [not encoded]

- **Repro:** `MarkdownRoundTrip["| a | b |\n|---|---|\n| 1 | 2 |\n/wl\n1\n/exec\nRESULT\n1\nENDRESULT(nb16)\nText"]; MarkdownRoundTrip["> quote\n" <> tc <> "\nText"]`
- **Observed:** "| a | b |\n| - | - |\n| 1 | 2 |/wl\n1\n/exec..." and "> \"quote\"TOOLCALL: ...". The items are {TextTableForm, InlineToolCall, ...} with no "\n". This is the general table/quote behavior ("| 1 | 2 |Text"), but for tool calls it breaks the history: a simple tool call is no longer at the start of a line. Not tested here (tables/blocks area).
- **Expected:** A line break between the table or quote and the tool call in the serialized text

### ENDRESULT IDs with non-alphanumeric characters leave '(id)' as text [not encoded]

- **Repro:** `FormatChatOutput["TOOLCALL: web_fetcher\n{\"x\":\"1\"}\nRESULT\nok\nENDRESULT(call_abc12)\nDone."]`
- **Observed:** {InlineToolCall (ToolCall ends with "ENDRESULT"), "(call_abc12)\nDone."}. $$toolCallEnd only accepts letters and digits. Chatbook's own IDs are alphanumeric (tinyHash), so this only affects external or hand-written text. Low priority.
- **Expected:** The whole 'ENDRESULT(...)' is part of the tool call, or the ID charset is documented

### Unterminated tool call in finished output keeps 'Using' and the spinner [encoded]

- **Repro:** `FormatChatOutput["Before\n\nTOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL\n"]`
- **Observed:** Finished opener labeled 'Using Web Fetcher' with ChatbookActiveToolProgress; Parameters "" (e.g. when a response is stopped while a tool is evaluating). The 'Using' state depends only on Result === "", not on $dynamicText.
- **Expected:** Plausibly intentional (the tool has no result); a 'stopped' state might be better

### Unparseable tool calls show the 'Using tool...' loading label in finished output [encoded]

- **Repro:** `FormatChatOutput["TOOLCALL: web_fetcher"] or, without the Simple method and without tool evaluation results, FormatChatOutput["/wl\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(abc123)"]`
- **Observed:** BoxData[DynamicBox[FormattingToolUsingLoading resource]] with TaggingRules <|ToolCall -> ...|> and no opener, even when finished and even with a RESULT
- **Expected:** Plausibly an intentional fallback; a finished state that isn't 'loading' might be better

### TOOLCALL 'Parameters' text includes the tool name and the ENDARGUMENTS/ENDTOOLCALL lines [encoded]

- **Repro:** `FormatChatOutput["TOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nok\nENDRESULT(id1)"] (ID not in $toolEvaluationResults, e.g. a restored chat)`
- **Observed:** TaggingRules Parameters -> "web_fetcher\n{...}\nENDARGUMENTS\nENDTOOLCALL", and the Interpreted view's INPUT section shows all of it
- **Expected:** Plausibly only the JSON arguments; encoded as current behavior because it's stored in TaggingRules

### Unknown tools parsed from text show the raw snake_case name [encoded]

- **Repro:** `FormatChatOutput["TOOLCALL: made_up_tool\n{\"x\":\"1\"}\nRESULT\nok\nENDRESULT(id)"]`
- **Observed:** Label 'Used made_up_tool'. getToolDisplayName[tool, name] returns the raw name as DisplayName, so makeToolCallBoxLabel's Name fallback ('Made Up Tool', used by FormatToolCall when there is no DisplayName) is never reached for parsed TOOLCALLs
- **Expected:** Plausibly fine; possibly 'Made Up Tool' for consistency

### OpenToolCallBoxes only applies to tool calls with evaluation results [encoded]

- **Repro:** Block[{Wolfram`Chatbook`Common`$openToolCallBoxes = True}, FormatChatOutput[finished TOOLCALL whose ID is not in $toolEvaluationResults]]
- **Observed:** The opener is closed; only parseFullToolCallString sets "Open"
- **Expected:** Probably fine (the setting is used for live chats, where results exist)

### Line breaks between tool calls depend on the syntax [encoded]

- **Repro:** `FormatChatOutput["A\n" <> tc1 <> "\n\n\n" <> tc2] (TOOLCALL) vs the same with simple '/wl' tool calls`
- **Observed:** For TOOLCALL, one blank line becomes "\n" and two or more become "\n\n". For simple tool calls, the leading $$ws of $$simpleToolCommand puts preceding blank lines into the tool call (trimmed later), so they always get a single "\n"
- **Expected:** Consistent spacing; the TOOLCALL behavior is encoded

### Discarded material leaves a blank line in serialization [encoded]

- **Repro:** `MarkdownRoundTrip["Intro\n" <> tc1 <> "\nBad.\n/retry\n" <> tc2 <> "\nDone."]`
- **Observed:** "Intro \n\n" <> tc2 <> "\nDone.": the DiscardedMaterial cell is ignored, but the "\n" after it is kept
- **Expected:** Harmless; encoded

## Thinking (20)

### formatSpeechInput always fails: templateBox is called with an Association [not encoded]

- **Repro:** `FormatChatOutput["<speech-input><audio>not available</audio><transcript>Hi</transcript></speech-input>"]`
- **Observed:** General::ChatbookInternal message, and a Failure in the TextData instead of a box. In SpeechInput.wl line 51, templateBox[<|"Audio" -> ..., "Transcript" -> ...|>, "NotebookAssistantSpeechInput"] fails because templateBox (Common.wl 1384-1388) only has args_List definitions. Re-verified. The same happens for speech elements inside thoughts.
- **Expected:** Cell[BoxData[TemplateBox[<|"Audio" -> None, "Transcript" -> "Hi"|>, "NotebookAssistantSpeechInput"]], "NotebookAssistantSpeechInput", Background -> None]. This is the shape that serializeSpeechInput reads.

### Empty <think></think> shows as an in-progress Thinking box containing the closing tag [not encoded]

- **Repro:** `FormatChatOutput["<think></think>\nAnswer"] (same for <thinking></thinking>)`
- **Observed:** A ThinkingOpener ("Thinking...", expanded) whose thoughts are TextData[{"</think>\nAnswer"}]. The answer is swallowed into the open box. The literal closed rules need at least one character (thoughts__), so the unterminated rule matches. Summary tags with no content correctly give EmptyThoughts (tested in Thinking-Empty-Summary).
- **Expected:** An EmptyThoughts box followed by "\n\nAnswer", as for "<think> </think>".

### A complete opening tag with nothing after it is shown as raw text [not encoded]

- **Repro:** `FormatChatOutput["<think>"]; FormatChatOutput["<thinking>", <|"Status" -> "Streaming"|>]`
- **Observed:** TextData[{"<think>"}]. Partial tags at the end of a streamed chunk ("<thi", "<think type='summary' id='abc'") are also shown raw. "<think type='summary' id='x'>" and "<think>\n" correctly give an empty ThinkingOpener.
- **Expected:** An empty ThinkingOpener for "<think>" and "<thinking>". Hiding partial tags while streaming is optional.

### Mismatched closing tags never close the block [not encoded]

- **Repro:** `FormatChatOutput["<thinking>a</think>\nAnswer"]; FormatChatOutput["<think>a</thinking>\nAnswer"]; FormatChatOutput["<think type='summary' id='a'>x</thinking>\nAnswer"]`
- **Observed:** A ThinkingOpener ("Thinking..." forever) whose thoughts include the wrong closing tag and the answer text.
- **Expected:** Probably accept either closing tag, so that the block closes and the answer is shown outside it.

### Partial closing tag is shown inside the open thinking box while streaming [not encoded]

- **Repro:** `FormatChatOutput["<think>abc</thi", <|"Status" -> "Streaming"|>]`
- **Observed:** A ThinkingOpener with thoughts TextData[{"abc</thi"}]. The box is expanded while thinking, so the partial tag is briefly visible.
- **Expected:** Trailing partial "</think" / "</thinking" hidden from the thoughts.

### Code block inside an open think tag is split out as static content while streaming [not encoded]

- **Repro:** fmt-rewrite harness: WithFormatterEnvironment["x.md", SimulateStream["<think>\nLet me compute:\n```wl\n1+1\n```\nThat gives 2.\n</think>\nThe answer is 2.", 20]]
- **Observed:** Re-verified. At 40 characters, a static cell is written that holds a ThinkingOpener ("Thinking...") with the code block inside. The dynamic display then shows "That gives 2.\n</think>\nThe answer is 2." as raw text, including the literal "</think>". Only the final reformat is correct (a ThoughtsOpener, then "\n\nThe answer is 2."). $dynamicSplitRules (Formatting.wl 1894) has no think-tag awareness. dropReasoningPositions in SendChat.wl only handles emulated stop tokens. Images and tool calls inside thoughts most likely split the same way (not verified).
- **Expected:** No split points inside an open think tag, or a split that keeps the thoughts in one box.

### Escaped-markdown path drops the line breaks and spaces around think boxes and speech elements [not encoded]

- **Repro:** `FormatChatOutput["\\*not italic\\*\n<think>**bold**</think>\nafter"]; FormatChatOutput["Price \\$5 <think>x</think> done"]; MarkdownRoundTrip["\\*not italic\\*\n<think>**bold**</think>\nafter"]`
- **Observed:** {"*not italic*", box, "\nafter"}: the box is on the same line as the text before it, and the blank line after it is missing too. Without escapes the result is {"not italic\n", box, "\n\nafter"}. {"Price $5", box, "\ndone"}: spaces are lost. The round trip gives "\\*not italic\\*<think>\n**bold**\n</think>\n\nafter". Speech elements behave the same way: {"*x*", speech, "Done"}. Each string part is trimmed separately in reformatTextDataEscaped0, and only code blocks get the textBeforeCodeBlock fix.
- **Expected:** The same line breaks and spaces as the unescaped path. The tests assert this loosely.

### HTML entities inside thoughts are decoded twice [not encoded]

- **Repro:** `FormatChatOutput["a &amp;amp; b <think>c &amp;amp; d</think>"]`
- **Observed:** The outer text shows "a &amp; b " but the thoughts show "c & d". importHTMLEntities runs on the whole string, then again when formatThoughts calls reformatTextData.
- **Expected:** "c &amp; d" (decoded once).

### Think tags inside list items, block quotes, headings and table cells, or inside inline styles, are not handled [not encoded]

- **Repro:** `FormatChatOutput /@ {"- item <think>x</think>\n- two", "> quote <think>x</think>", "# Title <think>x</think>", "| a | b |\n|---|---|\n| <think>x</think> | 2 |", "**bold <think>x</think> more**"}`
- **Observed:** The raw text "<think>x</think>" appears inside the InlineItem, BlockQuote, InlineSection or TextTableForm cell. In the bold case the box is created but splits the bold span, which leaves visible "**bold " and "\n more**". The block rule matches first at an earlier position, and formatTextString has no think rule.
- **Expected:** Arguably a think box, or at least no stray markup. Models rarely do this, so it's low priority.

### <thinking> tags with attributes are not recognized [not encoded]

- **Repro:** `FormatChatOutput["<thinking foo='bar'>x</thinking>"]; FormatChatOutput["<thinking type='summary' id='a'>x</thinking>"]`
- **Observed:** Raw text TextData[{"<thinking foo='bar'>x</thinking>"}]. The attribute rules only match "<think" ~~ $$thinkTagAttributes (which must start with whitespace), and the plain <thinking> rules need ">" right after the name. Attributes containing "<" (e.g. "<think a='<'>x</think>") are shown raw too.
- **Expected:** A literal ThoughtsOpener, as for <think foo='bar'>. Low priority, since Chatbook only writes attributes on <think>.

### Rest of the paragraph after a mid-paragraph think tag starts with a space [not encoded]

- **Repro:** `FormatChatOutput["Hello <think>x</think> world"]`
- **Observed:** {"Hello ", box, "\n world"}. The round trip gives "Hello <think>\nx\n</think>\n\n world".
- **Expected:** "\nworld". The test only asserts the line break and the trimmed text.

### CRLF around and inside think tags leaves stray \r characters [not encoded]

- **Repro:** `FormatChatOutput["Before\r\n<think>\r\nSome thoughts\r\n</think>\r\nAfter"]; MarkdownRoundTrip["<think>\r\nLine one\r\nLine two\r\n</think>\r\nDone"]; FormatChatOutput["<think>\r\n- a\r\n- b\r\n</think>"]`
- **Observed:** Items "Before\r \n" and "\n\r\nAfter". The round trip gives "<think>\nLine one\r\nLine two\n</think>\n\n\r\nDone". The list item keeps "a\r". This is general CRLF handling, not specific to think tags.
- **Expected:** \r\n handled like \n. The tests only assert trimmed text.

### Think tags don't nest: the first closing tag ends the block [encoded]

- **Repro:** `FormatChatOutput["<think>a<think>b</think>c</think>"]`
- **Observed:** A ThoughtsOpener with thoughts "a<think>b", followed by raw text "\nc</think>".
- **Expected:** Plausibly fine (models don't nest think tags). Encoded in Thinking-First-Closing-Tag-Wins.

### All literal think blocks in a response get the same duration label [encoded]

- **Repro:** Block[{Wolfram`Chatbook`Common`$thinkingStart = 10., Wolfram`Chatbook`Common`$thinkingEnd = 13.}, FormatChatOutput["<think>A</think>\nB\n<think>C</think>"]]
- **Observed:** Both labels are "Thought for 3 seconds". There is one timer pair per chat, and $thinkingEnd is set by the first closed box. Summaries use their own stored Duration.
- **Expected:** Probably intended, since literal think tags are usually a single leading block.

### Closed literal think tags get the fallback label unless the thinking box was shown first [encoded]

- **Repro:** Block[{Wolfram`Chatbook`Common`$thinkingStart = None, Wolfram`Chatbook`Common`$thinkingEnd = None}, FormatChatOutput["<think>x</think>"]]; also FormatChatOutput outside a chat, where the timers are unset symbols
- **Observed:** The label is the "FormattingThinkingCompleteFallback" resource ("Thought"). Timing only works if an unterminated ThinkingOpener was formatted earlier in the same chat state.
- **Expected:** Plausibly intended (no timing information).

### Serialization normalizes literal tags and closes unterminated ones [encoded]

- **Repro:** `MarkdownRoundTrip /@ {"<thinking>x</thinking>", "<THINK foo='bar'>x</THINK>", "<think>Still going", "<think type=\"summary\" id=\"abc\">x</think>"}`
- **Observed:** All are written as <think>\n...\n</think>. Attributes of literal tags are dropped, unterminated tags are closed, and summary attributes use single quotes.
- **Expected:** Intended (canonical form for chat history).

### Summary durations round half to even [encoded]

- **Repro:** `$reasoningData = <|"a" -> <|"Duration" -> 2.5|>|>; FormatChatOutput["<think type='summary' id='a'>x</think>"]`
- **Observed:** "Thought for 2 seconds" (Round[2.5] = 2). Durations below 1 s, including 0 and negative values, give the singular label.
- **Expected:** Fine either way.

### Speech element match is case-insensitive but transcript parsing is case-sensitive [encoded]

- **Repro:** Wolfram`Chatbook`SpeechInput`Private`parseSpeechTranscript["<TRANSCRIPT>x</TRANSCRIPT>"]
- **Observed:** The element is recognized (IgnoreCase -> True), but the transcript is "". parseSpeechTranscript and parseAudio use case-sensitive StringCases.
- **Expected:** Consistent case handling. Trivial, since Chatbook writes the element in lower case.

### Speech elements are formatted inside thoughts; empty or unterminated speech elements stay raw [encoded]

- **Repro:** `FormatChatOutput["<think>a <speech-input>A</speech-input> b</think>"]; FormatChatOutput["<speech-input></speech-input>"]`
- **Observed:** The speech rule is not in $$thoughtsExcludedRule, so it applies inside thoughts. An element with no characters between the tags, or one with no closing tag, is plain text.
- **Expected:** Plausibly fine.

### Serialized audio reference embeds a markdown image link inside AudioBox[...] [encoded]

- **Repro:** `MakeExpressionURI["audio", "Recorded Speech Input", Audio[ConstantArray[0., 800], SampleRate -> 8000]] (as called by serializeSpeechInput)`
- **Observed:** Re-verified. It returns "![Recorded Speech Input](audio://content-zfais)", so the result is <audio>\!\(\*AudioBox["![Recorded Speech Input](audio://...)"]\)</audio>. parseAudio still reads it back.
- **Expected:** Probably only the URI was intended. It works, so the test asserts it loosely and accepts either form.

## Images (28)

### Attachment image serialization drops the URL scheme [not encoded]

- **Repro:** Block[{Wolfram`Chatbook`Common`$attachments = <|"content-abc12" -> HoldComplete[{1,2,3}]|>}, MarkdownRoundTrip["![alt](attachment://content-abc12)"]]
- **Observed:** "![alt](content-abc12)". CellToStringData uses the matched key, not the URL as written. Real MakeExpressionURI URIs behave the same. file:// and attachment:// URLs to local files serialize as the bare path. The bare key still resolves through GetExpressionURI and expressionURIQ, so the tests accept either form.
- **Expected:** "![alt](attachment://content-abc12)" (the markdown as written)

### Empty-alt images from files/URLs serialize as a bare or bogus URL, not image markdown [not encoded]

- **Repro:** `MarkdownRoundTrip["![](/tmp/dir/small.png)"] (existing or missing file); MarkdownRoundTrip["![](nonexistent.png)"]; MarkdownRoundTrip["![](file:///tmp/dir/missing.png)"]`
- **Observed:** "expression:///tmp/dir/small.png", "expression://nonexistent.png", and "file:///tmp/dir/missing.png" (a bare URL with no ![](...) wrapper). Cause: the _Failure branch of toMIBoxURI.
- **Expected:** "![](/tmp/dir/small.png)" etc.

### Missing attachment key renders inside a Wolfram Language code block and serializes as a wl code fence [not encoded]

- **Repro:** `FormatMarkdown["![alt](attachment://content-zzz99)"] and MarkdownRoundTrip of the same (key not in $attachments); also "![](attachment://content-zzz99)"`
- **Observed:** The ImageNotFound placeholder is wrapped in ChatCodeBlockTemplate with a ChatCode/Input cell (ChatCodeActive while streaming). The round trip gives "```wl\n![alt](attachment://content-zzz99)\n```". An expression:// URL also serializes with attachment://. With empty alt the round trip is "```wl\nattachment://content-zzz99\n```". Cause: attachment[alt, key, _Missing] substitutes $missingImage (RawBoxes, not an Image), so the generic-expression branch runs.
- **Expected:** A plain placeholder, as for missing files, serializing as "![alt](attachment://content-zzz99)"

### Inline <!...!> URI with an unknown key causes an internal failure [not encoded]

- **Repro:** `FormatMarkdown["See <!attachment://content-zzz99!> here"]; also "<!foo://content-zzz99!>" and short keys such as "<!attachment://content-abc1!>"`
- **Observed:** A General::ChatbookInternal message and a Failure inside the TextData. attachment[None, key] and importedImage[None, url] have no definitions for alt None.
- **Expected:** The ImageNotFound placeholder, with no message

### Expression link with an unknown key issues a message and embeds a Failure [not encoded]

- **Repro:** `FormatMarkdown["Click [this](expression://content-zzz99) now"]`
- **Observed:** A GetExpressionURI::URIUnavailable message, and the TextExpressionLink data is a BinarySerialized Failure. expressionURIQ only checks the shape of the key.
- **Expected:** No message; plain text, or a link marked as unavailable

### TextExpressionLink loses the link on serialization and adds quotes [not encoded]

- **Repro:** `Block[{$attachments=<||>}, uri = MakeExpressionURI[{1,2,3}]; MarkdownRoundTrip["Click [this](expression://" <> key <> ") now"]]`
- **Observed:** "Click \"this\" now". The label is ToBoxes[label] (a quoted string box), and Serialization.wl has no rule for TextExpressionLink. Streaming gives "Click this now". The display is fine, because the template's BaseStyle "Text" hides the quotes.
- **Expected:** "Click [this](expression://content-xxxxx) now"

### Expression link labels are not markdown-formatted [not encoded]

- **Repro:** `FormatMarkdown["[**this**](expression://<real key>)"]`
- **Observed:** The template label is "\"**this**\"", so the asterisks show literally. Ordinary hyperlinks run formatTextString on their labels.
- **Expected:** Bold label text

### Indented image inside a code fence disappears [not encoded]

- **Repro:** FormatMarkdown["```\n  ![alt](attachment://content-abc12)\n```"] (key in $attachments)
- **Observed:** {""}, so nothing is shown. image[str] takes First of StringSplit, which is the leading whitespace.
- **Expected:** The image

### Code fence with two images (or image-like start/end) becomes one garbled image [not encoded]

- **Repro:** FormatMarkdown["```\n![a](attachment://content-abc12)\n![b](attachment://content-abc12)\n```"]; also "```\n![a](attachment://content-abc12) trailing)\n```"
- **Observed:** One image whose tooltip is "a](attachment://content-abc12)\n![b", with CellToStringData "![a](attachment://content-abc12)\n![b](content-abc12)". image[str] uses greedy alt__/url__, and the fence condition only checks that the content starts with "![" and ends with ")".
- **Expected:** Two images, or a code block

### Nested link syntax in alt text breaks the image; the exclusion condition is effectively dead [not encoded]

- **Repro:** `FormatMarkdown["![see [link](/tmp/dir/nolink) here](/tmp/dir/small.png)"]`
- **Observed:** A missing image for /tmp/dir/nolink with alt "see [link", followed by literal " here](/tmp/dir/small.png)". The Shortest alt stops at the first "](", so StringFreeQ[alt, "["~~___~~"]("~~__~~")"] almost never rejects.
- **Expected:** The image of small.png (CommonMark alt "see link here")

### Image title syntax not supported [not encoded]

- **Repro:** `FormatMarkdown["![alt](/tmp/dir/small.png \"title\")"]`
- **Observed:** The title becomes part of the URL, so the image shows as not found, and CellToStringData keeps the title.
- **Expected:** The image, with the title ignored or used as the tooltip

### Image URLs containing parentheses are cut at the first ")" [not encoded]

- **Repro:** `FormatMarkdown["![a](/tmp/dir/x(1).png)"]`
- **Observed:** A missing image for "/tmp/dir/x(1" followed by literal ".png)". The URL pattern is Shortest[Except[")"]..].
- **Expected:** The image of x(1).png (CommonMark allows balanced parentheses in link destinations)

### Linked images leave stray brackets [not encoded]

- **Repro:** `FormatMarkdown["[![alt](attachment://content-abc12)](https://example.com)"]; also "[see ![a](attachment://content-abc12)](https://example.com)"`
- **Observed:** {"[", <image>, "](https://example.com)"} (and {"[see ", <image>, "](https://example.com)"})
- **Expected:** A clickable image or link, or at least no stray markdown

### Emphasis spanning an image is broken [not encoded]

- **Repro:** `FormatMarkdown["**bold ![a](attachment://content-abc12) text**"], "*see ![a](attachment://content-abc12)*", and "* **bold ![a](attachment://content-abc12) text**"`
- **Observed:** At the top level, a literal "**" or "*" appears around the parts because the block-level image split happens first. In a list item the bold is silently dropped, because styleBox returns a mixed {String, Cell, String} list unstyled.
- **Expected:** Bold or italic text around the image

### Escaped "\!" before an image shows a stray backslash [not encoded]

- **Repro:** `FormatMarkdown["\\![a](attachment://content-abc12)"] (markdown text \![a](...))`
- **Observed:** {"\\", <image>}: a literal backslash, then the image
- **Expected:** A literal "!" followed by a link (CommonMark), or at least no visible backslash

### Markdown in alt text is shown literally in the tooltip [not encoded]

- **Repro:** `FormatMarkdown["![**bold**](attachment://content-abc12)"]`
- **Observed:** Tooltip "**bold**"
- **Expected:** Tooltip "bold" (CommonMark uses the plain-text content of the alt)

### Imported images get a duplicate nested tooltip [not encoded]

- **Repro:** `FormatMarkdown["![  alt  ](/tmp/dir/small.png)"] or any missing file`
- **Observed:** TooltipBox[TagBox[TooltipBox[img, "\"  alt  \"", TooltipStyle -> "TextStyling"], Annotation[...]], "\"alt\""]. importedImage's tooltip[] and markdownImageBoxes both add a tooltip, and the inner one has the untrimmed alt. Alt "result" skips the inner one.
- **Expected:** A single tooltip

### Missing images issue URLParse::invuri when $CloudBase is Automatic [not encoded]

- **Repro:** `Block[{$CloudBase = Automatic}, FormatChatOutput["![alt](/nonexistent.png)"]] ($CloudBase is Automatic in wolframscript and the test runner)`
- **Observed:** URLParse::invuri "The URI Automatic is invalid." from cloudURLQ, which calls URLParse[$CloudBase, "Domain"]
- **Expected:** No message. The tests Block $CloudBase to a string to avoid it.

### Streaming display size differs from finished size for medium images [not encoded]

- **Repro:** `A 250x300 PNG: FormatMarkdown["![a](file)", "Streaming"] vs "Finished"`
- **Observed:** Streaming: a 167x200 raster shown at ImageSize {UpTo[334], UpTo[400]}. Finished: the natural 250x300. Any image whose largest dimension is in (200, 800] is shown with largest dimension 400 while streaming, so its size jumps when the response finishes.
- **Expected:** The same display size in both states

### Size discontinuity at the 800 px limit [encoded]

- **Repro:** `800x10 PNG vs 801x10 PNG, finished`
- **Observed:** The 800x10 image shows at its natural 800 px. The 801x10 image is resized to 800x10 and shown at {UpTo[400], UpTo[5]} (half size, a HiDPI assumption).
- **Expected:** Plausibly intentional (large images are assumed to be high resolution)

### Large Image values in $attachments are never resized [not encoded]

- **Repro:** `Block[{$attachments = <|"content-img01" -> HoldComplete[Image[ConstantArray[0.5,{900,1000}]]]|>}, FormatMarkdown["![pic](attachment://content-img01)"]]`
- **Observed:** Shown at the full 1000x900 with no ImageSize, because the key-match branch of image[] bypasses resizeImage. attachment[]'s resize branch is unreachable for existing keys.
- **Expected:** Resized like imported images

### Held attachment values are evaluated for display [not encoded]

- **Repro:** `Block[{$attachments = <|"content-abc12" -> HoldComplete[1+1]|>}, FormatMarkdown["![alt](attachment://content-abc12)"]]`
- **Observed:** Shows "2". Replace[..., HoldComplete[e_] :> e] evaluates the value, whereas attachment[] uses Defer.
- **Expected:** Probably the held expression, without re-evaluating it

### Any URL containing a known key shows the attachment [encoded]

- **Repro:** `FormatMarkdown["![alt](/tmp/content-abc12.png)"] or "![alt](attachment://CONTENT-ABC12)" with content-abc12 in $attachments`
- **Observed:** The attachment is shown (StringContainsQ with IgnoreCase -> True), and CellToStringData uses the real key
- **Expected:** Plausibly intentional (tolerates URIs that models mangle)

### Imported images are cached by path for the session, including failures [not encoded]

- **Repro:** `Export a PNG to p, FormatMarkdown["![a](p)"], re-Export different content to p, FormatMarkdown again; or format a missing path, then create the file and format again`
- **Observed:** The old image is still shown, and a path that failed once stays missing after the file appears. The importImage memo is unbounded.
- **Expected:** A fresh import, or a bounded cache keyed on file modification time

### Trailing spaces after an image keep an extra blank line [not encoded]

- **Repro:** `FormatMarkdown["![a](attachment://content-abc12)   \n\nNext"] vs "![a](attachment://content-abc12)\n\nNext"`
- **Observed:** "   \n\nNext" (a blank line, even after NormalizeTextData) vs "\nNext". The round trips are "![a](content-abc12)   \n\nNext" vs "![a](content-abc12)\nNext".
- **Expected:** The same spacing in both

### Paragraph breaks around an image on its own line are lost in serialization [not encoded]

- **Repro:** `MarkdownRoundTrip["Before\n\n![a](attachment://content-abc12)\n\nAfter"] (key in $attachments); the same happens for a real Graphics URI between paragraphs`
- **Observed:** "Before \n![a](content-abc12)\nAfter". In markdown this is a single paragraph with soft breaks, so the image becomes inline in the history. The display has "Before \n", image, "\nAfter", where the pane's margins provide the spacing.
- **Expected:** "Before\n\n![a](...)\n\nAfter". The test accepts any whitespace that includes a line break on each side.

### Alt trimming is inconsistent between paths [not encoded]

- **Repro:** `"![  spaced alt  ](attachment://content-abc12)" vs "![  spaced alt  ](/tmp/dir/small.png)"`
- **Observed:** The attachment path keeps the untrimmed alt in the tooltip ("\"  spaced alt  \"") and in the serialization ("![  spaced alt  ](content-abc12)"). The imported path trims both. Confirmed by running it.
- **Expected:** Consistent trimming

### Empty-alt attachment serializes as a regenerated canonical URI [encoded]

- **Repro:** `Block[{$attachments=<||>}, uri = MakeExpressionURI[{1,2,3}]; MarkdownRoundTrip["![](attachment://" <> key <> ")"]]; also Block[{$attachments = <|"content-abc12" -> HoldComplete[{1,2,3}]|>}, MarkdownRoundTrip["See <!attachment://content-abc12!> here"]]`
- **Observed:** The first gives uri ("![Data](expression://content-xxxxx)"), with an invented label, and the scheme can change from attachment to expression. In the second, the key itself changes: "See ![Data](expression://content-38ru7) here", because MakeExpressionURI regenerates the hash-based key. toMIBoxURI also writes the new key into $attachments during formatting.
- **Expected:** Plausibly intentional for keys made by MakeExpressionURI (the key is then unchanged). A non-canonical key is silently replaced.
