BeginPackage[ "Wolfram`Chatbook`Common`" ];

`$absoluteCurrentSettingsCache;
`$allowConnectionDialog;
`$alwaysOpen;
`$attachments;
`$autoOpen;
`$availableServices;
`$basePrompt;
`$basePromptComponents;
`$baseStyle;
`$cachedTokenizers;
`$cellReferences;
`$cellStringBudget;
`$chatDataTag;
`$chatEvaluationID;
`$chatInputIndicator;
`$chatStartTime;
`$chatState;
`$cloudEvaluationNotebook;
`$cloudInlineReferenceButtons;
`$contextPrompt;
`$conversionRules;
`$corePersonaNames;
`$countImageTokens;
`$CurrentCell;
`$currentChatSettings;
`$currentSettingsCache;
`$customToolFormatter;
`$defaultAppName;
`$defaultChatSettings;
`$defaultChatTools;
`$defaultMaxCellStringLength;
`$defaultMaxOutputCellStringLength;
`$defaultPromptGenerators;
`$dialogInputAllowed;
`$documentationMarkdownBaseURL;
`$dynamicSplitRules;
`$dynamicText;
`$dynamicTrigger;
`$enableLLMServices;
`$evaluationCell;
`$evaluationNotebook;
`$filterDocumentationRAG;
`$finalCell;
`$fixedProgressText;
`$fullBasePrompt;
`$includeCellXML;
`$includeStackTrace;
`$inDialog;
`$inEpilog;
`$initialCellStringBudget;
`$inlineChatState;
`$lastCellObject;
`$lastChatString;
`$lastMessages;
`$lastSettings;
`$lastTask;
`$leftSelectionIndicator;
`$llmKit;
`$llmKitService;
`$longNameCharacters;
`$multimodalMessages;
`$nextTaskEvaluation;
`$noSemanticSearch;
`$notebookAssistanceExtraInstructions;
`$notebookEditorEnabled;
`$openToolCallBoxes;
`$preferencesScope;
`$progressContainer;
`$progressText;
`$progressWidth;
`$rasterCache;
`$receivedToolCall;
`$resultCellCache;
`$rightSelectionIndicator;
`$sandboxKernelCommandLine;
`$selectedTools;
`$selectionPrompt;
`$serviceCache;
`$serviceCaller;
`$servicesLoaded;
`$showProgressBar;
`$showProgressCancelButton;
`$showProgressText;
`$simpleToolMethod;
`$statelessProgressIndicator;
`$suppressButtonAppearance;
`$templateBoxOptionsCache;
`$thinkingEnd;
`$thinkingStart;
`$timingLog;
`$tinyHashLength;
`$tokenBudget;
`$tokenBudgetLog;
`$tokenPressure;
`$toolCallCount;
`$toolConfiguration;
`$toolEvaluationResults;
`$toolOptions;
`$toolResultStringLength;
`$useLLMServices;
`$useRasterCache;
`accentIncludedCells;
`acv;
`addHandlerArguments;
`addProcessingArguments;
`allowedMultimodalRoles;
`apiKeyDialog;
`applyHandlerFunction;
`applyProcessingFunction;
`applyPromptGenerators;
`assistantMessageBox;
`assistantMessageBoxActive;
`assistantMessageLabel;
`associationKeyDeflatten;
`attachAssistantMessageButtons;
`attachInlineChatInput;
`attachMenuCell;
`attachWorkspaceChatInput;
`autoAssistQ;
`autoCorrect;
`boxDataQ;
`cachedTokenizer;
`cellFlatten;
`cellInformation;
`cellOpenQ;
`cellPrint;
`cellPrintAfter;
`cellReference;
`cellsToChatNB;
`cellStyles;
`channelCleanup;
`chatExcludedQ;
`chatHandlerFunctionsKeys;
`chatInputCellQ;
`chatModelQ;
`checkEvaluationCell;
`chooseDefaultModelName;
`clearMinimizedChats;
`clickToCopy;
`compressUntilViewed;
`constructMessages;
`containsWordsQ;
`contextBlock;
`convertUTF8;
`createDialog;
`createFETask;
`createNewInlineOutput;
`createPreferencesContent;
`currentChatSettings;
`cv;
`cvExpand;
`dialogBody;
`dialogHeader;
`dialogSubHeader;
`discourageExtraToolCallsQ;
`displayInlineChat;
`documentationSearchAPI;
`dynamicAutoFormatQ;
`dynamicSplitQ;
`errorMessageBox;
`escapeMarkdownString;
`evaluateInlineChat;
`evaluateWithProgress;
`evaluateWorkspaceChat;
`expandMultimodalString;
`explodeCell;
`exportDataURI;
`expressionURIKey;
`expressionURIKeyQ;
`expressionURIQ;
`extractBodyChunks;
`fakeOpenerView;
`fastFileHash;
`feParentObject;
`filterChatCells;
`fixCloudCell;
`fixLineEndings;
`floatingButtonGrid;
`forceRefreshCloudPreferences;
`formatNotebookTitle;
`functionTemplateBoxes;
`getAvailableServiceNames;
`getBoxObjectFromBoxID;
`getChatConversationData;
`getChatGroupSettings;
`getChatMetadata;
`getEmbedding;
`getEmbeddings;
`getHandlerFunctions;
`getInlineChatPrompt;
`getModelList;
`getPersonaIcon;
`getPersonaMenuIcon;
`getPrecedingDelimiter;
`getProcessingFunction;
`getProcessingFunctions;
`getServiceModelList;
`getSnippets;
`getTokenizer;
`getTokenizerName;
`getToolByName;
`getToolDisplayName;
`getToolFormattingFunction;
`getToolIcon;
`getUserNotebook;
`getUserNotebooks;
`getWorkspacePrompt;
`graphicsQ;
`grayDialogButtonLabel;
`image2DQ;
`importDataURI;
`initFETaskWidget;
`initializeProgressContainer;
`initTools;
`inlineExpressionURIs;
`insertCodeBelow;
`insertFunctionInputBox;
`insertFunctionTemplate;
`insertModifierInputBox;
`insertModifierTemplate;
`insertPersonaInputBox;
`insertPersonaTemplate;
`insertTrailingFunctionInputBox;
`insertWLTemplate;
`llmSynthesize;
`llmSynthesizeSubmit;
`logUsage;
`makeCellStringBudget;
`makeChatCloudDefaultNotebookDockedCell;
`makeChatCloudDockedCellContents;
`makeChatMessages;
`makeChatNotebookOptions;
`makeChatNotebookSettings;
`makeExpressionURI;
`makeFailureString;
`makeInteractiveCodeCell;
`makeModelSelector;
`makeOutputDingbat;
`makeTeXBoxes;
`makeTokenBudget;
`makeToolConfiguration;
`makeToolResponseString;
`makeWorkspaceChatDockedCell;
`menuMagnification;
`mergeChatSettings;
`mergeCodeBlocks;
`messagesToString;
`modelDisplayName;
`modelListCachedQ;
`modifierTemplateBoxes;
`mouseDown;
`moveToChatInputField;
`multimodalModelQ;
`multimodalPacletsAvailable;
`needsBasePrompt;
`nextCell;
`notebookInformation;
`notebookObjectQ;
`notebookRead;
`openerView;
`openPreferencesPage;
`parentCell;
`parentNotebook;
`parseInlineReferences;
`parseSimpleToolCallParameterStrings;
`personaDisplayName;
`personaTemplateBoxes;
`preprocessSandboxString;
`rasterHash;
`rasterize;
`rasterizeBlock;
`readString;
`redDialogButtonLabel;
`reformatTextData;
`relativeTimeString;
`removeBasePrompt;
`removeCellAccents;
`removeChatMenus;
`removeToolPreferencePrompt;
`renameCodeAssistanceFiles;
`replaceCellContext;
`resizeMenuIcon;
`resizeMultimodalImage;
`resolveAutoSettings;
`resolveFullModelSpec;
`resolveInlineReferences;
`resolveTools;
`revertMultimodalContent;
`rootEvaluationCell;
`sandboxEvaluate;
`sandboxFormatter;
`scrollOutputQ;
`selectByCurrentValue;
`selectionEvaluateCreateCell;
`sendChat;
`sendFeedback;
`serviceFrameworkAvailable;
`serviceIcon;
`serviceName;
`setCV;
`setProgressDisplay;
`simpleResultQ;
`simpleToolRequestParser;
`snapshotModelQ;
`standardizeMessageKeys;
`standardizeModelData;
`stringToBoxes;
`stringTrimMiddle;
`systemCredential;
`throwFailureToChatOutput;
`tinyHash;
`toAPIKey;
`toCompressedBoxes;
`toImageURI;
`toModelName;
`toolAutoFormatter;
`toolData;
`toolName;
`toolOptionValue;
`toolRequestParser;
`toolSelectedQ;
`toolsEnabledQ;
`toolShortName;
`topParentCell;
`toSmallSettings;
`trackedDynamic;
`truncateString;
`unsetCV;
`updateCellDingbats;
`updateDynamics;
`userMessageBox;
`userMessageLabel;
`usingFrontEnd;
`withApproximateProgress;
`withBasePromptBuilder;
`withChatState;
`withChatStateAndFEObjects;
`withCredentialsProvider;
`withToolBox;
`withWorkspaceGlobalProgress;
`wlTemplateBoxes;
`writeInlineChatOutputCell;
`writeReformattedCell;
`writeWorkspaceChatSubDockedCell;

EndPackage[ ];