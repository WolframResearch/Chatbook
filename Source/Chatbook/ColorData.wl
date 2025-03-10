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
dominantColor[ "NA_ChatOutput"           ] := RGBColor["#F9FDFF"];
dominantColor[ "NA_Toolbar"              ] := RGBColor["#66ADD2"];
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
		 "Dark"   -> RGBColor[0.2460643, 0.2460643, 0.2460643],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "Chat bubble around assistant's message"
	|>,
	"AssistantMessageBoxFrame" -> <|
		 "Light"  -> RGBColor[0.7882352, 0.8, 0.8156862],
		 "Dark"   -> RGBColor[0.5115420, 0.5270474, 0.5529387],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> ""
	|>,
	"AssistantOutputBackground" -> <|
		 "Light"  -> RGBColor[0.9294117, 0.9490196, 0.9686274],
		 "Dark"   -> RGBColor[0.2486712, 0.2830753, 0.3371478],
		 "Method" -> "Background",
		 "DC"     -> "AssisstantOutput",
		 "Notes"  -> ""
	|>,
	"AssistantOutputErrorBackground" -> <|
		 "Light"  -> RGBColor[0.9921568, 0.9568627, 0.9568627],
		 "Dark"   -> RGBColor[0.4528378, 0.1916237, 0.1489361],
		 "Method" -> "Background",
		 "DC"     -> "AssisstantOutputError",
		 "Notes"  -> ""
	|>,
	"AssistantOutputErrorFrame" -> <|
		 "Light"  -> RGBColor[0.9450980, 0.8705882, 0.8705882],
		 "Dark"   -> RGBColor[0.5421097, 0.3064788, 0.2760967],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutputError",
		 "Notes"  -> ""
	|>,
	"AssistantOutputErrorMenuButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.9450980, 0.8705882, 0.8705882],
		 "Dark"   -> RGBColor[0.5421097, 0.3064788, 0.2760967],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutputError",
		 "Notes"  -> ""
	|>,
	"AssistantOutputFrame" -> <|
		 "Light"  -> RGBColor[0.8156862, 0.8705882, 0.9254901],
		 "Dark"   -> RGBColor[0.3347994, 0.3937122, 0.4723452],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutput",
		 "Notes"  -> ""
	|>,
	"AssistantOutputMenuButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.8156862, 0.8705882, 0.9254901],
		 "Dark"   -> RGBColor[0.3347994, 0.3937122, 0.4723452],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutput",
		 "Notes"  -> "Same as AssistantOutputFrame"
	|>,
	"AssistantOutputWarningBackground" -> <|
		 "Light"  -> RGBColor[0.9921568, 0.9803921, 0.9568627],
		 "Dark"   -> RGBColor[0.2935857, 0.2887161, 0.1789777],
		 "Method" -> "Background",
		 "DC"     -> "AssisstantOutputWarning",
		 "Notes"  -> ""
	|>,
	"AssistantOutputWarningFrame" -> <|
		 "Light"  -> RGBColor[0.9450980, 0.9058823, 0.8705882],
		 "Dark"   -> RGBColor[0.3950579, 0.3530192, 0.2793738],
		 "Method" -> "Feature",
		 "DC"     -> "AssisstantOutputWarning",
		 "Notes"  -> ""
	|>,
	"AssistantOutputWarningMenuButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.9450980, 0.9058823, 0.8705882],
		 "Dark"   -> RGBColor[0.3950579, 0.3530192, 0.2793738],
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
		 "Dark"   -> RGBColor[0.2460643, 0.2460643, 0.2460643],
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
	"ChatInputFrame" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.7882352, 0.9490196],
		 "Dark"   -> RGBColor[0.3992328, 0.5826271, 0.7859294],
		 "Method" -> "Feature",
		 "DC"     -> "White",
		 "Notes"  -> "Acccent6"
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
		 "Dark"   -> RGBColor[0.2460643, 0.2460643, 0.2460643],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> ""
	|>,
	"ChatOutputMenuButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.9254901, 0.9411764, 0.9607843],
		 "Dark"   -> RGBColor[0.1812288, 0.1981285, 0.2389377],
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
	"DiscardedMaterialOpenerBackground" -> <|
		 "Light"  -> RGBColor[0.9490196, 0.9686274, 0.9882352],
		 "Dark"   -> RGBColor[0.1855636, 0.2253820, 0.2891428],
		 "Method" -> "Background",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> "In ChatOutput UI"
	|>,
	"DiscardedMaterialOpenerFrame" -> <|
		 "Light"  -> RGBColor[0.9098039, 0.9333333, 0.9529411],
		 "Dark"   -> RGBColor[0.3121731, 0.3527505, 0.4013962],
		 "Method" -> "Feature",
		 "DC"     -> "ChatOutput",
		 "Notes"  -> ""
	|>,
	"FramedChatCellFrame" -> <|
		 "Light"  -> RGBColor[0.9254901, 0.9411764, 0.9607843],
		 "Dark"   -> RGBColor[0.3017228, 0.3342865, 0.3986351],
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
	"NA_ChatCodeBlockTemplateFrame" -> <|
		 "Light"  -> GrayLevel[0.89804],
		 "Dark"   -> GrayLevel[0.3921327],
		 "Method" -> "Feature",
		 "DC"     -> "NA_ChatOutput",
		 "Notes"  -> "Different DC from non-NA version"
	|>,
	"NA_NotebookBackground" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[0.0999191],
		 "Method" -> "Content",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"NA_Toolbar" -> <|
		 "Light"  -> RGBColor[0.4, 0.6784313, 0.8235294],
		 "Dark"   -> RGBColor[0.3561395, 0.5318399, 0.6365366],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarButtonBackgroundHover" -> <|
		 "Light"  -> RGBColor[0.5294117, 0.7647058, 0.8901960],
		 "Dark"   -> RGBColor[0.4436413, 0.6218816, 0.7263344],
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
		 "Dark"   -> RGBColor[0., 0., 0.],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarButtonFramePressed" -> <|
		 "Light"  -> RGBColor[0.2117647, 0.5372549, 0.7098039],
		 "Dark"   -> RGBColor[0.2420709, 0.5899503, 0.7708906],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarFont" -> <|
		 "Light"  -> GrayLevel[1],
		 "Dark"   -> GrayLevel[1.6995766*^-16],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarLightButtonBackground" -> <|
		 "Light"  -> RGBColor[0.9450980, 0.9725490, 0.9882352],
		 "Dark"   -> RGBColor[0.7234795, 0.8525465, 0.9284766],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarLightButtonFont" -> <|
		 "Light"  -> RGBColor[0.2745098, 0.6196078, 0.7960784],
		 "Dark"   -> RGBColor[0.2679819, 0.4244284, 0.5267637],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarLightButtonFontHover" -> <|
		 "Light"  -> RGBColor[1, 1, 1],
		 "Dark"   -> RGBColor[4.8210629*^-16, 0, 2.2638497*^-16],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarLightButtonFrame" -> <|
		 "Light"  -> RGBColor[0.9450980, 0.9725490, 0.9882352],
		 "Dark"   -> RGBColor[0., 0., 0.],
		 "Method" -> "Feature",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarTitleBackground" -> <|
		 "Light"  -> RGBColor[0.8666666, 0.9372549, 0.9764705],
		 "Dark"   -> RGBColor[0.6402878, 0.8166298, 0.9160979],
		 "Method" -> "Background",
		 "DC"     -> "NA_Toolbar",
		 "Notes"  -> ""
	|>,
	"NA_ToolbarTitleFont" -> <|
		 "Light"  -> RGBColor[0.2, 0.5137254, 0.6745098],
		 "Dark"   -> RGBColor[0.2540833, 0.6172958, 0.7951958],
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
		 "Light"  -> RGBColor[0.9450980, 0.9686274, 0.9921568],
		 "Dark"   -> RGBColor[0.1641904, 0.2037068, 0.2676196],
		 "Method" -> "Background",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"SendChatButtonFrame" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.7882352, 0.9490196],
		 "Dark"   -> RGBColor[0.3992328, 0.5826271, 0.7859294],
		 "Method" -> "Feature",
		 "DC"     -> "White",
		 "Notes"  -> "Implemented as CellFrameLabel"
	|>,
	"SideChatBackground" -> <|
		 "Light"  -> RGBColor[0.9803921, 0.9882352, 1.],
		 "Dark"   -> RGBColor[0.2207969, 0.2207969, 0.2207969],
		 "Method" -> "Background",
		 "DC"     -> "White",
		 "Notes"  -> ""
	|>,
	"SideChatDingbatFrame" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.7882352, 0.9490196],
		 "Dark"   -> RGBColor[0.3992328, 0.5826271, 0.7859294],
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
		 "Dark"   -> RGBColor[0.2469639, 0.3051983, 0.4024247],
		 "Method" -> "Background",
		 "DC"     -> "UserMessageBox",
		 "Notes"  -> "Chat bubble around user's message"
	|>,
	"UserMessageBoxFrame" -> <|
		 "Light"  -> RGBColor[0.6392156, 0.7882352, 0.9490196],
		 "Dark"   -> RGBColor[0.3750297, 0.5381765, 0.7268942],
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
		 "Dark"   -> RGBColor[0.2981658, 0.3301173, 0.3936214],
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
					shortenReals @
					ToString[ Last @ DarkModeMigration`ExpandLightDarkSwitched @
						DarkModeMigration`ColorToDarkMode[
							#2["Light"],
							If[#2["Method"] === "Content", "Content", {#2["Method"], dominantColor @ #2["DC"]}]
						],
						InputForm
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
