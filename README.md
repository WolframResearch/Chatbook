# Chatbook

This repository contains *Chatbook*, a paclet adding support for ChatGPT-powered
notebooks to Wolfram.

## Getting Started

To start using Chatbook, install this paclet by evaluating:

```
PacletInstall[ResourceObject["https://wolfr.am/1c2WoIEpe"]]
```

which will install the
[ConnorGray/Chatbook](https://www.wolframcloud.com/obj/connorg/DeployedResources/Paclet/ConnorGray/Chatbook/)
paclet resource.

Once installed, start using Chatbook by first creating an empty notebook,
and then selecting the `Format > Stylesheet > Chatbook` menu item to change
the notebook stylesheet.

Create new chat input cells by either:

* Selecting the `Format > Style > ChatGPTInput` menu item.

* Typing '/' when the cursor is in-between cells, or as the first character in
  an Input cell.

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


