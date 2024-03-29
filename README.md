# Chatbook

[![Build](https://github.com/WolframResearch/Chatbook/actions/workflows/Build.yml/badge.svg)](https://github.com/WolframResearch/Chatbook/actions/workflows/Build.yml) [![Release](https://github.com/WolframResearch/Chatbook/actions/workflows/Release.yml/badge.svg)](https://github.com/WolframResearch/Chatbook/actions/workflows/Release.yml)

#### [Changelog](./docs/CHANGELOG.md)


This repository contains *Chatbook*, a paclet adding support for LLM-powered
notebooks to Wolfram.


## Getting Started

To start using Chatbook, install this paclet by evaluating:

```
PacletInstall[ResourceObject["Wolfram/Chatbook"]]
```

which will install the
[Wolfram/Chatbook](https://paclets.com/Wolfram/Chatbook/)
paclet resource.

Once installed, start using Chatbook by first creating an empty notebook,
and then selecting the `Format > Stylesheet > Chatbook` menu item to change
the notebook stylesheet.

Create new chat input cells by either:

* Selecting the `Format > Style > ChatUserInput` menu item.

* Typing `'` when the cursor is in-between cells, or as the first character in
  an Input cell.

### Configuration

Before you can perform chat queries, you must specify your OpenAI API key by
performing the following evaluation:

```wolfram
SystemCredential["OPENAI_API_KEY"] = "<YOUR KEY>"
```

where `<YOUR_KEY>` is a valid OpenAI API key.

*Note: This credential is the same as that used by the
[ChristopherWolfram/OpenAILink](https://paclets.com/ChristopherWolfram/OpenAILink) paclet*.

## Features

### Interact with ChatGPT:

![Example of text cell in chat output](./docs/images/example-of-text-output.png)

### Generate immediately evaluatable Wolfram code:

![Example of Input cell in chat output](./docs/images/example-of-wolfram-output.png)

Wolfram code in the chat output can be evaluated in place immediately:

![Example of evaluation of Input cell from chat output](./docs/images/example-of-evaluating-generated-wolfram.gif)

<!-- ### Generate immediately evaluatable code in any language supported by [ExternalEvaluate]:

![Example of ExternalEvaluate cell in chat output](./docs/images/example-of-external-evaluate-output.png)

[ExternalEvaluate]: https://reference.wolfram.com/language/ref/ExternalEvaluate -->

## License

Licensed under the MIT license ([LICENSE-MIT](./LICENSE-MIT) or <https://opensource.org/license/MIT/>)

## Contributing

See [**Development.md**](./docs/Development.md) for instructions on how to
perform common development tasks when contributing to this project.
