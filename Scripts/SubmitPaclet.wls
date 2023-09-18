#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "PacletResource`" -> None ];
SetOptions[ PacletResource`Notebooks`ProcessNotebookForEmbedding, "EmbeddedHTMLImages" -> True ];

result = checkResult @ cicd`SubmitPaclet[ $defNB, "ExitOnFail" -> True ];

EndPackage[ ];

Wolfram`ChatbookScripts`result