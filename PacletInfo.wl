PacletObject[ <|
    "Name"           -> "Wolfram/Chatbook",
    "PublisherID"    -> "Wolfram",
    "Version"        -> "2.0.10",
    "WolframVersion" -> "14.1+",
    "Description"    -> "Wolfram Notebooks + LLMs",
    "License"        -> "MIT",
    "Creator"        -> "Connor Gray, Theodore Gray, Richard Hennigan, Kevin Daily",
    "Icon"           -> "Assets/Images/PacletIcon.png",
    "ReleaseID"      -> "77b070ff19460dd8279e568c1a733c2171de52fe",
    "ReleaseDate"    -> "2024-12-31T15:03:28Z",
    "ReleaseURL"     -> "https://github.com/WolframResearch/Chatbook/releases/tag/v2.0.9",
    "ActionURL"      -> "https://github.com/WolframResearch/Chatbook/actions/runs/12560994546",
    "CommitURL"      -> "https://github.com/WolframResearch/Chatbook/commit/77b070ff19460dd8279e568c1a733c2171de52fe",
    "Loading"        -> "Startup",
    "PrimaryContext" -> "Wolfram`Chatbook`",
    "Extensions"     -> {
        (* NOTE: The BeginStartup and EndStartup contexts are special, and need to
        be listed first and last, respectively, among all contexts provided by
        this paclet. This is a workaround used to prevent the contexts from this
        paclet from being present in $ContextPath post Kernel-startup. *)
        { "Kernel",
            "Root"    -> "Source/Startup/Begin",
            "Context" -> "Wolfram`Chatbook`BeginStartup`"
        },
        { "Kernel",
            "Root"    -> "Source/Chatbook",
            "Context" -> "Wolfram`Chatbook`"
        },
        { "Kernel",
            "Root"    -> "Source/Startup/End",
            "Context" -> "Wolfram`Chatbook`EndStartup`"
        },
        { "Asset",
            "Root"    -> "Assets",
            "Assets"  -> {
                { "AIAssistant"     , "AIAssistant"          },
                { "DisplayFunctions", "DisplayFunctions.wxf" },
                { "Icons"           , "Icons.wxf"            },
                { "SandboxMessages" , "SandboxMessages.wl"   },
                { "Tokenizers"      , "Tokenizers"           }
            }
        },
        { "LLMConfiguration",
            "Personas" -> {
                "PlainChat",
                "CodeAssistant",
                "CodeWriter",
                "NotebookAssistant",
                "RawModel",
                "Wolfie",
                "Birdnardo"
            }
        },
        { "FrontEnd",
            "Prepend" -> True
        }
    }
|> ]
