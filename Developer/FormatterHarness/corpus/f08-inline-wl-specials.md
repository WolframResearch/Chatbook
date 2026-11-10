Some special expressions that get formatted inside code:

```wl
ResourceFunction["RandomPoem"][]
ResourceFunction["BirdSay"]["Hello!"]
```

```wl
Entity["Country", "France"]["Population"]
Quantity[3.5, "Meters"] + Quantity[20, "Centimeters"]
DateObject[{2024, 3, 14}, "Day"]
```

```wl
PacletSymbol["Wolfram/Chatbook", "Wolfram`Chatbook`FormatChatOutput"]
Placeholder["your code here"]
```

```wl
\[FreeformPrompt]["distance from Earth to Mars"]
```

Inline versions: `ResourceFunction["RandomPoem"]`, `Entity["Planet", "Mars"]`, `Placeholder["x"]`, `<|"a" -> 1, "b" :> 2|>`, `a != b`, `x >= 0`, `f[[1]]`, and a long symbol name `Developer`PackedArrayQ`. Also a system symbol on its own: `PacletInstall`, a lowercase word `pacletinstall`, and a quoted string `"hello"`.

A link labeled with code: [`ResourceFunction["BirdSay"]`](https://resources.wolframcloud.com/FunctionRepository/resources/BirdSay/).

Math that is really a symbol name: $Pi$ and $Sin$, and numbers like $3.14$ and $1,000$.
