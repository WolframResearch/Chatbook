(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ColorData`" ];
Begin["`Private`"];


Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];


System`LightDark;
System`LightDarkSwitched;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*dominantColor*)


dominantColor // beginDefinition;

dominantColor[ "AssisstantOutput"        ] := RGBColor["#EDF2F7"];
dominantColor[ "AssisstantOutputError"   ] := RGBColor["#FDF4F4"];
dominantColor[ "AssisstantOutputWarning" ] := RGBColor["#FDFAF4"];
dominantColor[ "ChatMenu"                ] := GrayLevel[0.98];
dominantColor[ "ChatOutput"              ] := RGBColor["#FCFDFF"];
dominantColor[ "CloudToolbar"            ] := White;
dominantColor[ "ErrorMessageBlocked"     ] := RGBColor[ "#F3FBFF" ];
dominantColor[ "ErrorMessageFatal"       ] := RGBColor[ "#FFF3F1" ];
dominantColor[ "ErrorMessageNonFatal"    ] := RGBColor[ "#FFFAF2" ];
dominantColor[ "NA_ChatOutput"           ] := RGBColor["#F9FDFF"];
dominantColor[ "NA_OverlayMenu"          ] := White;
dominantColor[ "NA_Toolbar"              ] := RGBColor["#66ADD2"];
dominantColor[ "NA_CloudToolbar"         ] := RGBColor["#E9F7FF"];
dominantColor[ "UserMessageBox"          ] := RGBColor["#EDF4FC"];
dominantColor[ "White"                   ] := White;

dominantColor // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*iColor*)


iColorData // beginDefinition;

iColorData =
Dispatch[{
	"AssistantMessageBoxBackground" -> <|
		 "Light"  -> RGBColor[0.9882352, 0.9921568, 1.],
		 "Dark"   -> RGBColor[0.2460642, 0.2460642, 0.2460642],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "Chat bubble around assistant's message"
	|>,
	"AssistantMessageBoxFrame" -> <|
		 "Light"  -> RGBColor[0.7882352, 0.8, 0.8156862],
		 "Dark"   -> RGBColor[0.5115420, 0.5270474, 0.5529384],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> ""
	|>,
	"AssistantOutputBackground" -> <|
		 "Light"  -> RGBColor[0.9294117, 0.9490196, 0.9686274],
		 "Dark"   -> RGBColor[0.2486711, 0.2830753, 0.3371476],
		 "Method" -> "Background",
		 "DC"     -> "AssisstantOutput",
		 "Notes"  -> ""
	|>,
	"AssistantOutputErrorBackground" -> <|
		 "Light"  -> RGBColor[0.9921568, 0.9568627, 0.9568627],
		 "Dark"   -> RGBColor[0.4528376, 0.1916238, 0.1489362],
		 "Method" -> "Background",
		 "DC"     -> "AssisstantOutputError",
		 "Notes"  -> ""
	|>,
	"AssistantOutputErrorFrame" -> <|
		 "Light"  -> RGBColor[0.945098, 0.8705882, 0.8705882],
		 "Dark"   -> RGBColor[0.5421097, 0.3064789, 0.2760968],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutputError",
		 "Notes"  -> ""
	|>,
	"AssistantOutputErrorMenuButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.945098, 0.8705882, 0.8705882],
		 "Dark"   -> RGBColor[0.5421097, 0.3064789, 0.2760968],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutputError",
		 "Notes"  -> ""
	|>,
	"AssistantOutputFrame" -> <|
		 "Light"  -> RGBColor[0.8156862, 0.8705882, 0.9254901],
		 "Dark"   -> RGBColor[0.3347995, 0.3937123, 0.4723452],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutput",
		 "Notes"  -> ""
	|>,
	"AssistantOutputMenuButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.8156862, 0.8705882, 0.9254901],
		 "Dark"   -> RGBColor[0.3347995, 0.3937123, 0.4723452],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutput",
		 "Notes"  -> "Same as AssistantOutputFrame"
	|>,
	"AssistantOutputWarningBackground" -> <|
		 "Light"  -> RGBColor[0.9921568, 0.9803921, 0.9568627],
		 "Dark"   -> RGBColor[0.2935857, 0.2887160, 0.1789782],
		 "Method" -> "Background",
		 "DC"     -> "AssisstantOutputWarning",
		 "Notes"  -> ""
	|>,
	"AssistantOutputWarningFrame" -> <|
		 "Light"  -> RGBColor[0.945098, 0.9058823, 0.8705882],
		 "Dark"   -> RGBColor[0.3950580, 0.3530192, 0.2793739],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutputWarning",
		 "Notes"  -> ""
	|>,
	"AssistantOutputWarningMenuButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.945098, 0.9058823, 0.8705882],
		 "Dark"   -> RGBColor[0.3950580, 0.3530192, 0.2793739],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutputWarning",
		 "Notes"  -> "Same as AssistantOutputWarningFrame"
	|>,
	"ChatBlockDividerFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9612557],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"ChatBlockDividerFrame" -> <|
		 "Light"  -> GrayLevel[0.74902],
		 "Dark"   -> GrayLevel[0.5494749],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> "Like a Section cell, this is a bar across the top"
	|>,
	"ChatCodeBlockTemplateBackgroundBottom" -> <|
		 "Light"  -> RGBColor[0.9882352, 0.9921568, 1.],
		 "Dark"   -> RGBColor[0.2460642, 0.2460642, 0.2460642],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI, copy/insert button area, matches the ChatOutput background"
	|>,
	"ChatCodeBlockTemplateBackgroundTop" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.2536661],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI, code block background for known programming languages"
	|>,
	"ChatCodeBlockTemplateFrame" -> <|
		 "Light"  -> GrayLevel[0.92941],
		 "Dark"   -> GrayLevel[0.3474138],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI, frame around code blocks"
	|>,
	"ChatCodeInlineTemplateBackground" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.2536661],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"ChatCodeInlineTemplateFrame" -> <|
		 "Light"  -> GrayLevel[0.92941],
		 "Dark"   -> GrayLevel[0.3474138],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"ChatCounterLabelFont" -> <|
		 "Light"  -> RGBColor[0.55433, 0.707942, 0.925795],
		 "Dark"   -> RGBColor[0.4635437, 0.6228900, 0.8538312],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"ChatDelimiterBackground" -> <|
		 "Light"  -> GrayLevel[0.95],
		 "Dark"   -> GrayLevel[0.2437777],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> "Solid bar across the cell content area"
	|>,
	"ChatDingbatBackgroundHover" -> <|
		 "Light"  -> GrayLevel[0.960784],
		 "Dark"   -> GrayLevel[0.2194089],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> "Dingbat for ChatInput/Output"
	|>,
	"ChatDingbatFrameHover" -> <|
		 "Light"  -> GrayLevel[0.74902],
		 "Dark"   -> GrayLevel[0.5494749],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> "Dingbat for ChatInput/Output"
	|>,
	"ChatInputFrame" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.7882352, 0.9490196],
		 "Dark"   -> RGBColor[0.3992328, 0.5826272, 0.7859296],
		 "Method" -> "Feature",
		 "DC"     -> "White",
		 "Notes"  -> "Acccent6"
	|>,
	"ChatMenuCheckboxLabelFont" -> <|
		 "Light"  -> GrayLevel[0.],
		 "Dark"   -> GrayLevel[0.9999999],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuCheckboxLabelFontDisabled" -> <|
		 "Light"  -> GrayLevel[0.5],
		 "Dark"   -> GrayLevel[0.7953969],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuCheckboxLabelFontHover" -> <|
		 "Light"  -> GrayLevel[0.537],
		 "Dark"   -> GrayLevel[0.7673870],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuFrame" -> <|
		 "Light"  -> GrayLevel[0.85],
		 "Dark"   -> GrayLevel[0.4484549],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuItemBackground" -> <|
		 "Light"  -> GrayLevel[0.98],
		 "Dark"   -> GrayLevel[0.2325145],
		 "Method" -> "Background",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuItemBackgroundHover" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.2508895],
		 "Method" -> "Background",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuItemDelimiter" -> <|
		 "Light"  -> GrayLevel[0.9],
		 "Dark"   -> GrayLevel[0.3766262],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuItemFrame" -> <|
		 "Light"  -> GrayLevel[0.98],
		 "Dark"   -> GrayLevel[0.2325145],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuItemFrameHover" -> <|
		 "Light"  -> GrayLevel[0.8],
		 "Dark"   -> GrayLevel[0.5121850],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuLabelFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9628223],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuSectionBackground" -> <|
		 "Light"  -> GrayLevel[0.937],
		 "Dark"   -> GrayLevel[0.1930434],
		 "Method" -> "Background",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatMenuSectionLabelFont" -> <|
		 "Light"  -> GrayLevel[0.35],
		 "Dark"   -> GrayLevel[0.8924651],
		 "Method" -> "Feature",
		 "DC"     -> "ChatMenu",
		 "Notes"  -> ""
	|>,
	"ChatOutputBackground" -> <|
		 "Light"  -> RGBColor[0.9882352, 0.9921568, 1.],
		 "Dark"   -> RGBColor[0.2460642, 0.2460642, 0.2460642],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> ""
	|>,
	"ChatOutputMenuButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.9254901, 0.9411764, 0.9607843],
		 "Dark"   -> RGBColor[0.1812287, 0.1981284, 0.2389377],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "Light color matches FramedChatCellFrame on hover"
	|>,
	"ChatOutputMenuButtonFrame" -> <|
		 "Light"  -> GrayLevel[1, 0],
		 "Dark"   -> GrayLevel[0.2141508, 0.],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI, vertical ellipsis button, fully transparent frame"
	|>,
	"ChatPreformattedBackground" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.2536661],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI, code block background color for unknown programming languages"
	|>,
	"CloudToolbarFont" -> <|
		 "Light"  -> RGBColor[0.2, 0.2, 0.2],
		 "Dark"   -> RGBColor[0.9640047, 0.9640047, 0.9640047],
		 "Method" -> "Feature",
		 "DC"     -> "CloudToolbar",
		 "Notes"  -> "Cloud only: Chatbook top docked cell"
	|>,
	"CloudToolbarMenuShortcutFont" -> <|
		 "Light"  -> GrayLevel[0.75],
		 "Dark"   -> GrayLevel[0.5516041],
		 "Method" -> "Feature",
		 "DC"     -> "NA_CloudToolbar",
		 "Notes"  -> "Cloud only: cell style action menu has white background"
	|>,
	"CloudToolbarPreferencesCellBackground" -> <|
		 "Light"  -> GrayLevel[0.75],
		 "Dark"   -> GrayLevel[0.5483285],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> "Cloud only: cell content is used in multiple places, so leave as content color"
	|>,
	"DiscardedMaterialBackground" -> <|
		 "Light"  -> RGBColor[0.94902, 0.96863, 0.98824],
		 "Dark"   -> RGBColor[0.1855605, 0.2253845, 0.2891527],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"DiscardedMaterialBackgroundHover" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.2536661],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"DiscardedMaterialFrame" -> <|
		 "Light"  -> RGBColor[0.9098, 0.93333, 0.95294],
		 "Dark"   -> RGBColor[0.3121773, 0.3527556, 0.4014066],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"DiscardedMaterialIcon" -> <|
		 "Light"  -> GrayLevel[0.7451],
		 "Dark"   -> GrayLevel[0.5845390],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"DiscardedMaterialIconHover" -> <|
		 "Light"  -> RGBColor[0.3451, 0.72157, 0.98039],
		 "Dark"   -> RGBColor[0.3407180, 0.6837218, 0.9285837],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"DiscardedMaterialOpenerBackground" -> <|
		 "Light"  -> RGBColor[0.9490196, 0.9686274, 0.9882352],
		 "Dark"   -> RGBColor[0.1855637, 0.2253819, 0.2891426],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"DiscardedMaterialOpenerFrame" -> <|
		 "Light"  -> RGBColor[0.9098039, 0.9333333, 0.9529411],
		 "Dark"   -> RGBColor[0.3121732, 0.3527505, 0.4013961],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedBackground" -> <|
		 "Light"  -> RGBColor[0.9529411, 0.9843137, 1.],
		 "Dark"   -> RGBColor[0.2943442, 0.2943442, 0.2943442],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedCloseButtonBackground" -> <|
		 "Light"  -> RGBColor[0.490196, 0.7803921, 0.9333333],
		 "Dark"   -> RGBColor[0.0671212, 0.0904723, 0.1111824],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedCloseButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.8352941, 0.9411764],
		 "Dark"   -> RGBColor[0.1008307, 0.1333261, 0.1615458],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedCloseButtonBackgroundPressed" -> <|
		 "Light"  -> RGBColor[0.2, 0.5137254, 0.6745098],
		 "Dark"   -> RGBColor[0.0404292, 0.0689282, 0.0912857],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedCloseButtonCrossPressed" -> <|
		 "Light"  -> RGBColor[1., 1., 1.],
		 "Dark"   -> RGBColor[0.1806958, 0.1806958, 0.1806958],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedCloseButtonFrame" -> <|
		 "Light"  -> RGBColor[0.490196, 0.7803921, 0.9333333],
		 "Dark"   -> RGBColor[0.3934073, 0.6102920, 0.7373154],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedCloseButtonFrameHover" -> <|
		 "Light"  -> RGBColor[0.7843137, 0.9137254, 0.9843137],
		 "Dark"   -> RGBColor[0.2759687, 0.4060457, 0.4940583],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedCloseButtonFramePressed" -> <|
		 "Light"  -> RGBColor[0.2, 0.5137254, 0.6745098],
		 "Dark"   -> RGBColor[0.3083640, 0.7163947, 0.9061990],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9627260],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedFontPressed" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.1806958],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedFrame" -> <|
		 "Light"  -> RGBColor[0.6666666, 0.8549019, 0.9568627],
		 "Dark"   -> RGBColor[0.3397979, 0.5035732, 0.6066078],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedIcon" -> <|
		 "Light"  -> RGBColor[0.2745098, 0.6196078, 0.7960784],
		 "Dark"   -> RGBColor[0.3435086, 0.7242286, 0.9108964],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedLabelButtonBackground" -> <|
		 "Light"  -> RGBColor[0.490196, 0.7803921, 0.9333333],
		 "Dark"   -> RGBColor[0.0671212, 0.0904723, 0.1111824],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedLabelButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.7843137, 0.9137254, 0.9843137],
		 "Dark"   -> RGBColor[0.1585996, 0.2217496, 0.2717914],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedLabelButtonBackgroundPressed" -> <|
		 "Light"  -> RGBColor[0.2, 0.5137254, 0.6745098],
		 "Dark"   -> RGBColor[0.0404292, 0.0689282, 0.0912857],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedLabelButtonFrameHover" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.8352941, 0.9411764],
		 "Dark"   -> RGBColor[0.1008307, 0.1333261, 0.1615458],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageBlockedLinkFontHover" -> <|
		 "Light"  -> RGBColor[0.2666666, 0.6156862, 0.8],
		 "Dark"   -> RGBColor[0.3360057, 0.7234408, 0.9192360],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageBlocked",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalBackground" -> <|
		 "Light"  -> RGBColor[1., 0.9529411, 0.945098],
		 "Dark"   -> RGBColor[0.4517255, 0.2377211, 0.1427876],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalCloseButtonBackground" -> <|
		 "Light"  -> RGBColor[1., 0.5411764, 0.4784313],
		 "Dark"   -> RGBColor[0.1287881, 0.0725871, 0.0319215],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalCloseButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[1., 0.7921568, 0.7607843],
		 "Dark"   -> RGBColor[0.2763024, 0.1494118, 0.0925141],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalCloseButtonBackgroundPressed" -> <|
		 "Light"  -> RGBColor[0.9294117, 0.3960784, 0.2549019],
		 "Dark"   -> RGBColor[0.1113292, 0.0672978, 0.0281494],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalCloseButtonCrossPressed" -> <|
		 "Light"  -> RGBColor[1., 1., 1.],
		 "Dark"   -> RGBColor[0.1334814, 0.1334814, 0.1334814],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalCloseButtonFrame" -> <|
		 "Light"  -> RGBColor[1., 0.5411764, 0.4784313],
		 "Dark"   -> RGBColor[0.9576001, 0.4924693, 0.4239362],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalCloseButtonFrameHover" -> <|
		 "Light"  -> RGBColor[1., 0.6470588, 0.5921568],
		 "Dark"   -> RGBColor[0.9021690, 0.4037872, 0.3139713],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalCloseButtonFramePressed" -> <|
		 "Light"  -> RGBColor[0.9294117, 0.3960784, 0.2549019],
		 "Dark"   -> RGBColor[0.9652456, 0.5546388, 0.4554928],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9617783],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalFontPressed" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.1334814],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalFrame" -> <|
		 "Light"  -> RGBColor[1., 0.7686274, 0.7294117],
		 "Dark"   -> RGBColor[0.7628285, 0.3148004, 0.1983050],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalLabelButtonBackground" -> <|
		 "Light"  -> RGBColor[1., 0.5411764, 0.4784313],
		 "Dark"   -> RGBColor[0.1287881, 0.0725871, 0.0319215],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalLabelButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[1., 0.7921568, 0.7607843],
		 "Dark"   -> RGBColor[0.2763024, 0.1494118, 0.0925141],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalLabelButtonBackgroundPressed" -> <|
		 "Light"  -> RGBColor[0.9294117, 0.3960784, 0.2549019],
		 "Dark"   -> RGBColor[0.1113292, 0.0672978, 0.0281494],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalLabelButtonFrameHover" -> <|
		 "Light"  -> RGBColor[1., 0.6470588, 0.5921568],
		 "Dark"   -> RGBColor[0.1334990, 0.0777925, 0.0381452],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageFatalLinkFontHover" -> <|
		 "Light"  -> RGBColor[0.8823529, 0.3294117, 0.2196078],
		 "Dark"   -> RGBColor[0.9499245, 0.5631079, 0.4940351],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalBackground" -> <|
		 "Light"  -> RGBColor[1., 0.9803921, 0.9490196],
		 "Dark"   -> RGBColor[0.3232215, 0.3067767, 0.1467494],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalCloseButtonBackground" -> <|
		 "Light"  -> RGBColor[0.9803921, 0.7568627, 0.3019607],
		 "Dark"   -> RGBColor[0.1499358, 0.1375774, 0.0693818],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalCloseButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[1., 0.8862745, 0.6549019],
		 "Dark"   -> RGBColor[0.2504328, 0.2389279, 0.1166336],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalCloseButtonBackgroundPressed" -> <|
		 "Light"  -> RGBColor[0.9411764, 0.572549, 0.0823529],
		 "Dark"   -> RGBColor[0.1081289, 0.0859514, 0.0325836],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalCloseButtonCrossPressed" -> <|
		 "Light"  -> RGBColor[1., 1., 1.],
		 "Dark"   -> RGBColor[0.1926573, 0.1926573, 0.1926573],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalCloseButtonFrame" -> <|
		 "Light"  -> RGBColor[0.9803921, 0.7568627, 0.3019607],
		 "Dark"   -> RGBColor[0.6134560, 0.5104481, 0.2260647],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalCloseButtonFrameHover" -> <|
		 "Light"  -> RGBColor[0.9843137, 0.7607843, 0.3058823],
		 "Dark"   -> RGBColor[0.6081888, 0.5064229, 0.2198045],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalCloseButtonFramePressed" -> <|
		 "Light"  -> RGBColor[0.9411764, 0.572549, 0.0823529],
		 "Dark"   -> RGBColor[0.9166031, 0.5738551, 0.1475756],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9630005],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalFontPressed" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.1926573],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalFrame" -> <|
		 "Light"  -> RGBColor[1., 0.8470588, 0.6705882],
		 "Dark"   -> RGBColor[0.4940377, 0.4035166, 0.1981610],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalLabelButtonBackground" -> <|
		 "Light"  -> RGBColor[0.9803921, 0.7568627, 0.3019607],
		 "Dark"   -> RGBColor[0.1499358, 0.1375774, 0.0693818],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalLabelButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[1., 0.8862745, 0.6549019],
		 "Dark"   -> RGBColor[0.2504328, 0.2389279, 0.1166336],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalLabelButtonBackgroundPressed" -> <|
		 "Light"  -> RGBColor[0.9411764, 0.572549, 0.0823529],
		 "Dark"   -> RGBColor[0.1081289, 0.0859514, 0.0325836],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalLabelButtonFrameHover" -> <|
		 "Light"  -> RGBColor[0.9843137, 0.7607843, 0.3058823],
		 "Dark"   -> RGBColor[0.1545818, 0.1418314, 0.0706557],
		 "Method" -> "Background",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"ErrorMessageNonFatalLinkFontHover" -> <|
		 "Light"  -> RGBColor[0.8117647, 0.545098, 0.],
		 "Dark"   -> RGBColor[0.9094903, 0.5997460, 0.0487317],
		 "Method" -> "Feature",
		 "DC"     -> "ErrorMessageNonFatal",
		 "Notes"  -> ""
	|>,
	"FramedChatCellFrame" -> <|
		 "Light"  -> RGBColor[0.9254901, 0.9411764, 0.9607843],
		 "Dark"   -> RGBColor[0.3017229, 0.3342866, 0.3986354],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "DC is ChatOutputBackground"
	|>,
	"InlineReferenceTextFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9612557],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"LinkFont" -> <|
		 "Light"  -> RGBColor[0.02, 0.286, 0.651],
		 "Dark"   -> RGBColor[0.7045361, 0.8002698, 0.9939886],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"LinkFontHover" -> <|
		 "Light"  -> RGBColor[0.855, 0.396, 0.145],
		 "Dark"   -> RGBColor[0.9799549, 0.6520260, 0.5217897],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"NA_AssistantMessageBoxBackground" -> <|
		 "Light"  -> RGBColor[0.9764705, 0.9921568, 1.],
		 "Dark"   -> RGBColor[0.2640989, 0.2640989, 0.2640989],
		 "Method" -> "Background",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> "Chat bubble around assistant's message, slight difference from non-NA version"
	|>,
	"NA_AssistantMessageBoxFrame" -> <|
		 "Light"  -> RGBColor[0.8784313, 0.9372549, 0.9686274],
		 "Dark"   -> RGBColor[0.2783110, 0.3609622, 0.4198378],
		 "Method" -> "Feature",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> "Different DC from non-NA version"
	|>,
	"NA_ChatCodeBlockTemplateBackgroundBottom" -> <|
		 "Light"  -> RGBColor[0.9764705, 0.9921568, 1.],
		 "Dark"   -> RGBColor[0.2640989, 0.2640989, 0.2640989],
		 "Method" -> "Background",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> "Different DC from non-NA version"
	|>,
	"NA_ChatCodeBlockTemplateBackgroundTop" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.2739766],
		 "Method" -> "Background",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> "Different DC from non-NA version"
	|>,
	"NA_ChatCodeBlockTemplateButtonFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9633727],
		 "Method" -> "Feature",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> ""
	|>,
	"NA_ChatCodeBlockTemplateButtonFrameHover" -> <|
		 "Light"  -> RGBColor[0.8313725, 0.8980392, 0.9294117],
		 "Dark"   -> RGBColor[0.1448949, 0.1727086, 0.1929935],
		 "Method" -> "Background",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> "Used in both NA and Chatbooks"
	|>,
	"NA_ChatCodeBlockTemplateFrame" -> <|
		 "Light"  -> GrayLevel[0.89804],
		 "Dark"   -> GrayLevel[0.3921327],
		 "Method" -> "Feature",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> "Different DC from non-NA version"
	|>,
	"NA_CloudToolbarBackground" -> <|
		 "Light"  -> RGBColor[0.9137254, 0.9686274, 1.],
		 "Dark"   -> RGBColor[0.2495220, 0.3536671, 0.4315410],
		 "Method" -> "Background",
		 "DC"     -> "NA_CloudToolbar",
		 "Notes"  -> "Cloud only: default notebook optional docked cell"
	|>,
	"NA_CloudToolbarButtonFrame" -> <|
		 "Light"  -> RGBColor[0.9137254, 0.9686274, 1.],
		 "Dark"   -> RGBColor[0.1756673, 0.2419843, 0.2966992],
		 "Method" -> "Feature",
		 "DC"     -> "NA_CloudToolbar",
		 "Notes"  -> ""
	|>,
	"NA_CloudToolbarButtonFrameHover" -> <|
		 "Light"  -> RGBColor[0.6313725, 0.8039215, 0.8941176],
		 "Dark"   -> RGBColor[0.4100845, 0.5415207, 0.6208044],
		 "Method" -> "Feature",
		 "DC"     -> "NA_CloudToolbar",
		 "Notes"  -> ""
	|>,
	"NA_CloudToolbarFont" -> <|
		 "Light"  -> RGBColor[0.2, 0.2, 0.2],
		 "Dark"   -> RGBColor[0.9614924, 0.9614924, 0.9614924],
		 "Method" -> "Feature",
		 "DC"     -> "NA_CloudToolbar",
		 "Notes"  -> ""
	|>,
	"NA_CloudToolbarIconInsertChatCell_1" -> <|
		 "Light"  -> RGBColor[0.6470588, 0.7529411, 0.8117647],
		 "Dark"   -> RGBColor[0.5027361, 0.5822059, 0.6314907],
		 "Method" -> "Feature",
		 "DC"     -> "NA_CloudToolbar",
		 "Notes"  -> ""
	|>,
	"NA_CloudToolbarIconInsertChatCell_2" -> <|
		 "Light"  -> RGBColor[0.2745098, 0.6196078, 0.7960784],
		 "Dark"   -> RGBColor[0.3406807, 0.7196094, 0.9058676],
		 "Method" -> "Feature",
		 "DC"     -> "NA_CloudToolbar",
		 "Notes"  -> ""
	|>,
	"NA_CloudToolbarIconNewChat" -> <|
		 "Light"  -> RGBColor[0.2784313, 0.6235294, 0.7960784],
		 "Dark"   -> RGBColor[0.3437993, 0.7197632, 0.9010030],
		 "Method" -> "Feature",
		 "DC"     -> "NA_CloudToolbar",
		 "Notes"  -> ""
	|>,
	"NA_NotebookBackground" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.0999191],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuBackground" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.2325145],
		 "Method" -> "Background",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9640047],
		 "Method" -> "Feature",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuFont_2" -> <|
		 "Light"  -> GrayLevel[0.6],
		 "Dark"   -> GrayLevel[0.7255594],
		 "Method" -> "Feature",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuFontSubtle" -> <|
		 "Light"  -> GrayLevel[0.6509803],
		 "Dark"   -> GrayLevel[0.6816802],
		 "Method" -> "Feature",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuFrame" -> <|
		 "Light"  -> GrayLevel[0.8196078],
		 "Dark"   -> GrayLevel[0.5079930],
		 "Method" -> "Feature",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuHeaderBackground" -> <|
		 "Light"  -> GrayLevel[0.9607843],
		 "Dark"   -> GrayLevel[0.1965747],
		 "Method" -> "Background",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuIcon_Blue" -> <|
		 "Light"  -> RGBColor[0.4, 0.67843, 0.82353],
		 "Dark"   -> RGBColor[0.4271693, 0.7167508, 0.8646465],
		 "Method" -> "Feature",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuIcon_Gray" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9640047],
		 "Method" -> "Feature",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuItemBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.9294117, 0.9686274, 0.9882352],
		 "Dark"   -> RGBColor[0.1509433, 0.2053128, 0.2456591],
		 "Method" -> "Background",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_OverlayMenuPercolate" -> <|
		 "Light"  -> GrayLevel[0.7490196],
		 "Dark"   -> GrayLevel[0.5867762],
		 "Method" -> "Feature",
		 "DC"     -> "NA_OverlayMenu",
		 "Notes"  -> ""
	|>,
	"NA_SourcesDockedCellFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9255081],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_Toolbar" -> <|
		 "Light"  -> RGBColor[0.4, 0.6784313, 0.8235294],
		 "Dark"   -> RGBColor[0.3561395, 0.5318398, 0.6365366],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.5294117, 0.7647058, 0.890196],
		 "Dark"   -> RGBColor[0.4436413, 0.6218815, 0.7263343],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarButtonBackgroundPressed" -> <|
		 "Light"  -> RGBColor[0.2117647, 0.5372549, 0.7098039],
		 "Dark"   -> RGBColor[0.2359915, 0.3864898, 0.4889553],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarButtonFrameHover" -> <|
		 "Light"  -> RGBColor[0.6039215, 0.7921568, 0.8941176],
		 "Dark"   -> RGBColor[0.4804729, 0.6542139, 0.7548048],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> "This frame is a transitional color"
	|>,
	"NA_ToolbarButtonFramePressed" -> <|
		 "Light"  -> RGBColor[0.2117647, 0.5372549, 0.7098039],
		 "Dark"   -> RGBColor[0.2359915, 0.3864898, 0.4889553],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> "This frame is a transitional color"
	|>,
	"NA_ToolbarFont" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[1],
		 "Method" -> "Same",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarLightButtonBackground" -> <|
		 "Light"  -> RGBColor[0.945098, 0.972549, 0.9882352],
		 "Dark"   -> RGBColor[0.7234794, 0.8525465, 0.9284763],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarLightButtonFont" -> <|
		 "Light"  -> RGBColor[0.2745098, 0.6196078, 0.7960784],
		 "Dark"   -> RGBColor[0.2679819, 0.4244285, 0.5267638],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarLightButtonFrame" -> <|
		 "Light"  -> RGBColor[0.945098, 0.972549, 0.9882352],
		 "Dark"   -> RGBColor[0.7234794, 0.8525465, 0.9284763],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> "This frame is a transitional color"
	|>,
	"NA_ToolbarTitleBackground" -> <|
		 "Light"  -> RGBColor[0.8666666, 0.9372549, 0.9764705],
		 "Dark"   -> RGBColor[0.6402876, 0.8166299, 0.9160977],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarTitleFont" -> <|
		 "Light"  -> RGBColor[0.2, 0.5137254, 0.6745098],
		 "Dark"   -> RGBColor[0.2540833, 0.6172958, 0.7951960],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NotebookAssistant`InlineReferenceTextFont" -> <|
		 "Light"  -> GrayLevel[0.2],
		 "Dark"   -> GrayLevel[0.9640047],
		 "Method" -> "Feature",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"SendChatButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.945098, 0.9686274, 0.9921568],
		 "Dark"   -> RGBColor[0.1641904, 0.2037067, 0.2676195],
		 "Method" -> "Background",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"SendChatButtonFrame" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.7882352, 0.9490196],
		 "Dark"   -> RGBColor[0.3992328, 0.5826272, 0.7859296],
		 "Method" -> "Feature",
		 "DC"     -> "White",
		 "Notes"  -> "Implemented as CellFrameLabel"
	|>,
	"SideChatBackground" -> <|
		 "Light"  -> RGBColor[0.9803921, 0.9882352, 1.],
		 "Dark"   -> RGBColor[0.2207968, 0.2207968, 0.2207968],
		 "Method" -> "Background",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"SideChatDingbatFrame" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.7882352, 0.9490196],
		 "Dark"   -> RGBColor[0.3992328, 0.5826272, 0.7859296],
		 "Method" -> "Feature",
		 "DC"     -> "White",
		 "Notes"  -> "Same color as ChatInputFrame"
	|>,
	"ThinkingContentBackground" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.2536661],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"ThinkingContentDivider" -> <|
		 "Light"  -> GrayLevel[0.8196],
		 "Dark"   -> GrayLevel[0.4999564],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"ThinkingContentFont" -> <|
		 "Light"  -> GrayLevel[0.35],
		 "Dark"   -> GrayLevel[0.8945403],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"ThinkingOpenerFont" -> <|
		 "Light"  -> GrayLevel[0.4666],
		 "Dark"   -> GrayLevel[0.8228443],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"ThinkingOpenerFontHover" -> <|
		 "Light"  -> GrayLevel[0.39215],
		 "Dark"   -> GrayLevel[0.8703883],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"UserMessageBoxBackground" -> <|
		 "Light"  -> RGBColor[0.9294117, 0.9568627, 0.9882352],
		 "Dark"   -> RGBColor[0.2469639, 0.3051983, 0.4024244],
		 "Method" -> "Background",
		 "DC"     -> "UserMessageBox",
		 "Notes"  -> "Chat bubble around user's message"
	|>,
	"UserMessageBoxFrame" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.7882352, 0.9490196],
		 "Dark"   -> RGBColor[0.3750297, 0.5381766, 0.7268945],
		 "Method" -> "Feature",
		 "DC"     -> "UserMessageBox",
		 "Notes"  -> "Chat bubble around user's message"
	|>,
	"WelcomeToCodeAssistanceSplashBackground" -> <|
		 "Light"  -> RGBColor[0.9764705, 0.9921568, 1.],
		 "Dark"   -> RGBColor[0.2640989, 0.2640989, 0.2640989],
		 "Method" -> "Background",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> ""
	|>,
	"WelcomeToCodeAssistanceSplashFont" -> <|
		 "Light"  -> GrayLevel[0.5],
		 "Dark"   -> GrayLevel[0.7985881],
		 "Method" -> "Feature",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> ""
	|>,
	"WelcomeToCodeAssistanceSplashFrame" -> <|
		 "Light"  -> RGBColor[0.9254901, 0.9411764, 0.9607843],
		 "Dark"   -> RGBColor[0.2981659, 0.3301174, 0.3936217],
		 "Method" -> "Feature",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> ""
	|>,
	"WelcomeToCodeAssistanceSplashTitleFont" -> <|
		 "Light"  -> GrayLevel[0.25],
		 "Dark"   -> GrayLevel[0.9433838],
		 "Method" -> "Feature",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> ""
	|>(* ,
	"" -> <|
		"Light"  -> ,
		"Dark"   -> ,
		"Method" -> ,
		"DC"     -> ,
		"Notes"  -> ""
	|>, *)
}];

iColorData // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*color*)


color // beginDefinition;

With[{colordata = iColorData},

	color[ name_String ] := LightDarkSwitched[ #Light, #Dark ]& @ Replace[ name, iColorData ] /; BoxForm`sufficientVersionQ[ 14.3 ];
	
	color[ name_String ] := #Light& @ Replace[ name, iColorData ]

];

color // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*remakeDispatch*)


$digits = 5;

shortenReals // beginDefinition;
shortenReals[str_] := StringReplace[str, "." ~~ x:Longest[DigitCharacter..] :> "." <> StringTake[x, UpTo[$digits + 2]]];
shortenReals // endDefinition;

roundColor // beginDefinition;
roundColor[c:LightDarkSwitched[___]] := roundColor /@ c;
roundColor[c_?ColorQ] := Replace[c, r_Real :> Round[r, 10.`^-$digits], {1}];
roundColor // endDefinition;


remakeDispatch // beginDefinition

(* Copy resulting expression as a string and paste above. *)
remakeDispatch[ d_Dispatch ] := (Needs["DarkModeMigration`"];
StringJoin[
	"Dispatch[{\n",
	StringRiffle[
		KeyValueMap[
			StringJoin[
				"\t", ToString[#1, InputForm], " -> <|",
				"\n\t\t \"Light\"  -> ", shortenReals @ ToString[#2["Light"], InputForm], ",",
				"\n\t\t \"Dark\"   -> ",
					If[ #2["Method"] === "Same",
						shortenReals @ ToString[#2["Light"], InputForm]
						,
						shortenReals @
						ToString[ Last @ DarkModeMigration`ExpandLightDarkSwitched @
							DarkModeMigration`ColorToDarkMode[
								#2["Light"],
								If[#2["Method"] === "Content", "Content", {#2["Method"], dominantColor @ #2["DC"]}]
							],
							InputForm
						]
					], ",",
				"\n\t\t \"Method\" -> ", ToString[#2["Method"], InputForm], ",",
				"\n\t\t \"DC\"     -> ", ToString[#2["DC"], InputForm], ",",
				"\n\t\t \"Notes\"  -> ", ToString[#2["Notes"], InputForm],
				"\n\t|>"
			]&,
			KeySort @ Association @ Normal @ d
		],
		",\n"
	],
	"(* ,\n\t\"\" -> <|\n\t\t\"Light\"  -> ,\n\t\t\"Dark\"   -> ,\n\t\t\"Method\" -> ,\n\t\t\"DC\"     -> ,\n\t\t\"Notes\"  -> \"\"\n\t|>, *)",
	"\n}]"
]
)

remakeDispatch // endDefinition


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*end package*)


End[]


EndPackage[]
