## Developer documentation pages needed

* [ ] Settings
  - Source: `Source/Chatbook/Settings.wl`
  - [x] Listing of available settings
    - Add descriptions for settings that are fully defined in Settings.wl
    - For other settings, leave a `[TODO]` placeholder in that section for now
  - [ ] How to add support for new models
* [ ] Citations
  - Source: `Source/Chatbook/Citations.wl`
* [ ] Base prompts
  - Source: `Source/Chatbook/Prompting.wl`
* [ ] Prompt generators
  - [ ] Vector databases
  - [ ] Related documentation
  - [ ] Related Wolfram Alpha results
* [ ] Tools
  - [ ] WL evaluator
    - Source: `Source/Chatbook/Sandbox.wl`
* [ ] Personas
* [ ] Notebook Assistant
  - Source: `Source/Chatbook/ChatModes/ShowNotebookAssistance.wl`
* [ ] Markdown conversion
  - [ ] Converting notebook content to Markdown
    - Source: `Source/Chatbook/Serialization.wl`
  - [ ] Converting Markdown to notebook content
    - Source: `Source/Chatbook/Formatting.wl`

## Creating new documentation pages

Create new developer documentation pages as Markdown files in the `docs` directory. If there are subitems, create a directory in the `docs` directory for them. Each directory should have a `README.md` file that summarizes the contents of the directory.

Before writing the new page, thoroughly explore and review the relevant source code to ensure that all the relevant information is understood. Ask clarifying questions if needed.

Link to other relevant documentation pages as needed.