In HTML, special characters must be written as entities. For example, `&lt;` produces &lt; and `&amp;` produces &amp;.

Some common ones:

* &amp;copy; renders as &copy;
* &amp;mdash; renders as &mdash; (an em dash)
* &amp;nbsp; is a non-breaking space: "a&nbsp;b"
* &amp;#8364; is the euro sign: &#8364;
* &amp;hearts; renders as &hearts;

In Wolfram Language, you can convert entities with `ImportString["&lt;b&gt;", "HTML"]`, which gives `"<b>"`. Note that `x &lt; y &amp;&amp; y &gt; z` in text becomes x &lt; y &amp;&amp; y &gt; z.

Unknown entities like &foo; and malformed ones like &amp or & ; are left as they are. A long one like &notanentity; also stays.

| Entity | Character |
|:-------|:---------:|
| `&lt;` | &lt; |
| `&gt;` | &gt; |
| `&quot;` | &quot; |
