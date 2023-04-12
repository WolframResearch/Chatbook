# Chatbook

This repository contains *Chatbook*, a paclet adding support for ChatGPT-powered
notebooks to Wolfram.

**Latest Release:** v0.0.7, released 2023-03-21 1:34pm CT.

## Getting Started

To start using Chatbook, install this paclet by evaluating:

```
PacletInstall[ResourceObject["https://wolfr.am/1c2WoIEpe"]]
```

which will install the
[Wolfram/LLMTools](https://www.wolframcloud.com/obj/connorg/DeployedResources/Paclet/Wolfram/LLMTools/)
paclet resource.

Once installed, start using Chatbook by first creating an empty notebook,
and then selecting the `Format > Stylesheet > Chatbook` menu item to change
the notebook stylesheet.

Create new chat input cells by either:

* Selecting the `Format > Style > ChatUserInput` menu item.

* Typing '/' when the cursor is in-between cells, or as the first character in
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

![Example of text cell in chat output](./docs/images/example-of-text-output-2.png)

### Generate immediately evaluatable Wolfram code:

![Example of Input cell in chat output](./docs/images/example-of-wolfram-output-2.png)

Wolfram code in the chat output can be evaluated in place immediately:

![Example of evaluation of Input cell from chat output](./docs/images/example-of-wolfram-output-evaluated-2.png)

### Generate immediately evaluatable code in any language supported by [ExternalEvaluate]:

![Example of ExternalEvaluate cell in chat output](./docs/images/example-of-external-evaluate-output-2.png)

[ExternalEvaluate]: https://reference.wolfram.com/language/ref/ExternalEvaluate

## License

Licensed under the MIT license ([LICENSE-MIT](./LICENSE-MIT) or <https://opensource.org/license/MIT/>)

## Contributing

See [**Development.md**](./docs/Development.md) for instructions on how to
perform common development tasks when contributing to this project.
