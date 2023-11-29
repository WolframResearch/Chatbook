PacletObject[ <|
    "Name"           -> "Wolfram/Chatbook",
    "PublisherID"    -> "Wolfram",
    "Version"        -> "1.3.2",
    "WolframVersion" -> "13.3+",
    "Description"    -> "Wolfram Notebooks + LLMs",
    "License"        -> "MIT",
    "Creator"        -> "Connor Gray, Theodore Gray, Richard Hennigan",
    "Icon"           -> "Assets/Images/PacletIcon.png",
    "ReleaseID"      -> "$RELEASE_ID$",
    "ReleaseDate"    -> "$RELEASE_DATE$",
    "ReleaseURL"     -> "$RELEASE_URL$",
    "ActionURL"      -> "$ACTION_URL$",
    "CommitURL"      -> "$COMMIT_URL$",
    "Loading" 		 -> "Startup",
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
                { "Icons"           , "Icons.wxf"            },
                { "DisplayFunctions", "DisplayFunctions.wxf" },
                { "AIAssistant"     , "AIAssistant"          },
                { "SandboxMessages" , "SandboxMessages.wl"   }
            }
        },
        { "LLMConfiguration",
            "Personas" -> {
                "PlainChat",
                "CodeAssistant",
                "CodeWriter",
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
