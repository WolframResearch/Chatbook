PacletObject[ <|
    "Name"           -> "Wolfram/Chatbook",
    "PublisherID"    -> "Wolfram",
    "Version"        -> "2.4.33",
    "WolframVersion" -> "14.2+",
    "Description"    -> "Wolfram Notebooks + LLMs",
    "License"        -> "MIT",
    "Creator"        -> "Connor Gray, Theodore Gray, Richard Hennigan, Kevin Daily",
    "Icon"           -> "Assets/Images/PacletIcon.png",
    "ReleaseID"      -> "$RELEASE_ID$",
    "ReleaseDate"    -> "$RELEASE_DATE$",
    "ReleaseURL"     -> "$RELEASE_URL$",
    "ActionURL"      -> "$ACTION_URL$",
    "CommitURL"      -> "$COMMIT_URL$",
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
                { "AIAssistant"         , "AIAssistant"              },
                { "DisplayFunctions"    , "DisplayFunctions.wxf"     },
                { "DisplayFunctionsDark", "DisplayFunctionsDark.wxf" },
                { "Snippets"            , "Snippets"                 },
                { "Icons"               , "Icons.wxf"                },
                { "SandboxMessages"     , "SandboxMessages.wl"       },
                { "TemplateBoxOptions"  , "TemplateBoxOptions.wxf"   },
                { "Tokenizers"          , "Tokenizers"               }
            }
        },
        { "LLMConfiguration",
            "Personas" -> {
                "AgentOne",
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
            "Root" -> "FrontEnd",
            Prepend -> True
        },
        { "FrontEnd",
            "Root" -> "DarkModeSupport",
            "WolframVersion" -> "14.3+",
            Prepend -> True
        }
    }
|> ]
