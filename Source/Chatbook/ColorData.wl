(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ColorData`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notes*)
(* Colors used in more than one place by the Chatbook UI are the LightDarkSwitched values below, looked up with
   color[ "Name" ]. A color used in only one place is written as a LightDarkSwitched literal where it is used.
   The same values are used in the kernel sources, the stylesheets and the front end resources, so there is a
   single set of stylesheets and resources that switch between light and dark mode on their own.

   Names describe the value rather than where it is used:
       "Gray<light>_<dark>"          gray levels, as percentages (e.g. "Gray100_10" is white in light mode, 10% gray in dark mode)
       "<Hue>_<light hex>_<dark hex>" other colors, named by hue family and their light and dark mode values
       "..._Auto"                    a single light mode value that the front end converts for dark mode
       "..._A<light>[_<dark>]"       opacity in percent, when not fully opaque

   Colors that look the same (CIEDE2000 difference under 1 in both modes, same opacity) share one entry.

   A comment after an entry lists the hover and pressed colors it replaced (names from the earlier, longer version of
   this file). Use those entries for hover and pressed states: their dark values were picked by hand, so hover stays
   lighter than the default in dark mode. To make a new dark value for a UI feature, use
   DarkModeMigration`ColorToDarkMode[ c, { "Feature", White } ], and check that hover is still lighter than the default.

   When a color appears inside a Dynamic (or anything else the front end evaluates later), resolve it before
   it gets there, e.g. With[ { c = color @ "Gray20_94" }, Dynamic[ If[ hover, c, ... ] ] ], so the front end
   sees the literal LightDarkSwitched value and never calls the kernel for it.

   After changing a value here, rebuild the stylesheets (Developer/StylesheetBuilder.wl, BuildStylesheets[ ])
   and the front end resources (Developer/FrontEndResourceBuilder.wl, WriteTextResource[ All ]) if they use it.

   Adding or changing a color, step by step:
       1. Look for an entry that already looks the same in both modes: compare the light values, then the dark values,
          with ColorDistance[ a, b, DistanceFunction -> "CIEDE2000" ] (under 0.01, which is 1 on the usual 0-100 scale,
          is the same color). Reuse it if one exists, even if its name came from a different part of the UI.
       2. If the color is used in only one place, write LightDarkSwitched[ light, dark ] there instead of adding an
          entry. Tests/ColorData.wlt checks that every entry here is used at least twice, and that every name used
          in Source/ and Developer/ is defined here.
       3. Otherwise add an entry, named by the rules above, in sorted order (grays from light to dark, then hue
          families). Use RGBColor[ "#RRGGBB" ] or GrayLevel[ g ] values, and the two-argument LightDarkSwitched unless
          the front end's automatic dark value is what you want ("..._Auto").
       4. In a hover or pressed state, check the dark value against the default state's dark value: hover lighter,
          pressed darker, as in light mode. Tests/ColorData.wlt checks this for the inline reference chips.

   Where color can't be called:
       - Inside held code that the front end evaluates (Dynamic, DynamicBox, DynamicWrapper's second argument,
         RuleDelayed values, Button actions, Initialization): resolve it first with With, as above.
       - In resource definitions under Developer/Resources that are box expressions (GraphicsBox, DynamicBox, ...),
         since boxes aren't evaluated when the resources are built. Write them as Graphics (or other expressions)
         instead, or use the literal value. Tests/ColorData.wlt doesn't check this; look for color[ in the built
         FrontEnd/TextResources/ChatbookResources.tr after rebuilding.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$colorData*)
$colorData = <|
    "Gray100_10"           -> LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[ 0.098 ] ], (* hover: NA_BlueHueButtonBackgroundHover, NA_ChatCodeBlockTemplateButtonBackgroundHover *)
    "Gray100_14"           -> LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[ 0.139 ] ],
    "Gray100_15"           -> LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[ 0.153 ] ],
    "Gray100_20"           -> LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[ 0.1989 ] ],
    "Gray100_23"           -> LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[ 0.2325 ] ], (* hover: NA_RaftMenuItemBackgroundHover *)
    "Gray100_26"           -> LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[ 0.257 ] ], (* hover: ChatMenuItemBackgroundHover, DiscardedMaterialBackgroundHover *)
    "Gray100_28"           -> LightDarkSwitched[ GrayLevel[ 1 ], GrayLevel[ 0.2783 ] ],
    "Gray100_31"           -> LightDarkSwitched[ GrayLevel[ 1 ], RGBColor[ "#4E4E4E" ] ], (* hover: inline reference chip background (lighter than Blue_F1F8FF_474747 in dark mode) *)
    "Gray98_17"            -> LightDarkSwitched[ GrayLevel[ 0.9765 ], GrayLevel[ 0.1725 ] ],
    "Gray98_19"            -> LightDarkSwitched[ GrayLevel[ 0.98 ], GrayLevel[ 0.1922 ] ],
    "Gray96_23"            -> LightDarkSwitched[ GrayLevel[ 0.9608 ], GrayLevel[ 0.2314 ] ],
    "Gray95_15"            -> LightDarkSwitched[ GrayLevel[ 0.95 ], GrayLevel[ 0.153 ] ],
    "Gray94_20"            -> LightDarkSwitched[ GrayLevel[ 0.9412 ], GrayLevel[ 0.2 ] ],
    "Gray93_32"            -> LightDarkSwitched[ GrayLevel[ 0.9294 ], GrayLevel[ 0.3232 ] ],
    "Gray90_23"            -> LightDarkSwitched[ GrayLevel[ 0.898 ], GrayLevel[ 0.2325 ] ],
    "Gray90_29_A50_50"     -> LightDarkSwitched[ GrayLevel[ 0.898, 0.5 ], GrayLevel[ 0.2863, 0.5 ] ],
    "Gray90_33"            -> LightDarkSwitched[ GrayLevel[ 0.898 ], GrayLevel[ 0.3256 ] ],
    "Gray90_35"            -> LightDarkSwitched[ GrayLevel[ 0.9 ], GrayLevel[ 0.3478 ] ],
    "Gray90_36"            -> LightDarkSwitched[ GrayLevel[ 0.898 ], GrayLevel[ 0.364 ] ],
    "Gray85_39"            -> LightDarkSwitched[ GrayLevel[ 0.851 ], GrayLevel[ 0.3878 ] ],
    "Gray85_41"            -> LightDarkSwitched[ GrayLevel[ 0.85 ], GrayLevel[ 0.4104 ] ],
    "Gray85_43"            -> LightDarkSwitched[ GrayLevel[ 0.85 ], GrayLevel[ 0.4303 ] ],
    "Gray82_28"            -> LightDarkSwitched[ GrayLevel[ 0.8196 ], GrayLevel[ 0.2785 ] ],
    "Gray82_46"            -> LightDarkSwitched[ GrayLevel[ 0.82 ], GrayLevel[ 0.464 ] ], (* hover: NA_RaftMenuItemFrameHover *)
    "Gray80_47"            -> LightDarkSwitched[ GrayLevel[ 0.8 ], GrayLevel[ 0.4683 ] ], (* hover: ChatMenuItemFrameHover *)
    "Gray80_49"            -> LightDarkSwitched[ GrayLevel[ 0.8 ], GrayLevel[ 0.4856 ] ],
    "Gray75_Auto"          -> LightDarkSwitched[ GrayLevel[ 0.75 ] ],
    "Gray75_51"            -> LightDarkSwitched[ GrayLevel[ 0.75 ], GrayLevel[ 0.505 ] ],
    "Gray75_52"            -> LightDarkSwitched[ GrayLevel[ 0.75 ], GrayLevel[ 0.5223 ] ],
    "Gray75_54"            -> LightDarkSwitched[ GrayLevel[ 0.749 ], GrayLevel[ 0.5385 ] ], (* pressed: NA_RaftMenuItemFramePressed *)
    "Gray75_71"            -> LightDarkSwitched[ GrayLevel[ 0.749 ], GrayLevel[ 0.7065 ] ],
    "Gray65_63"            -> LightDarkSwitched[ GrayLevel[ 0.65 ], GrayLevel[ 0.6326 ] ],
    "Gray63_68"            -> LightDarkSwitched[ GrayLevel[ 0.6274 ], GrayLevel[ 0.6772 ] ],
    "Gray60_68"            -> LightDarkSwitched[ GrayLevel[ 0.6 ], GrayLevel[ 0.6764 ] ],
    "Gray54_Auto"          -> LightDarkSwitched[ GrayLevel[ 0.5373 ] ],
    "Gray54_50"            -> LightDarkSwitched[ GrayLevel[ 0.5372 ], GrayLevel[ 0.4987 ] ],
    "Gray54_71"            -> LightDarkSwitched[ GrayLevel[ 0.5373 ], GrayLevel[ 0.7111 ] ], (* hover: ChatMenuCheckboxLabelFontHover *)
    "Gray50_75"            -> LightDarkSwitched[ GrayLevel[ 0.502 ], GrayLevel[ 0.7484 ] ],
    "Gray50_79"            -> LightDarkSwitched[ GrayLevel[ 0.5 ], GrayLevel[ 0.7863 ] ],
    "Gray47_78"            -> LightDarkSwitched[ GrayLevel[ 0.4666 ], GrayLevel[ 0.7797 ] ],
    "Gray45_85"            -> LightDarkSwitched[ GrayLevel[ 0.45 ], GrayLevel[ 0.85 ] ],
    "Gray39_72"            -> LightDarkSwitched[ GrayLevel[ 0.3922 ], GrayLevel[ 0.72 ] ],
    "Gray39_83"            -> LightDarkSwitched[ GrayLevel[ 0.3922 ], GrayLevel[ 0.8329 ] ], (* hover: ThinkingOpenerFontHover *)
    "Gray35_86"            -> LightDarkSwitched[ GrayLevel[ 0.35 ], GrayLevel[ 0.8583 ] ], (* pressed: PreferencesContentServicesNAInfoIconPressed *)
    "Gray25_92"            -> LightDarkSwitched[ GrayLevel[ 0.25 ], GrayLevel[ 0.9188 ] ],
    "Gray20_Auto"          -> LightDarkSwitched[ GrayLevel[ 0.2 ] ],
    "Gray20_94"            -> LightDarkSwitched[ GrayLevel[ 0.2 ], GrayLevel[ 0.9432 ] ],
    "Gray12_90"            -> LightDarkSwitched[ GrayLevel[ 0.12 ], GrayLevel[ 0.9 ] ],
    "Gray0_0"              -> LightDarkSwitched[ GrayLevel[ 0 ], GrayLevel[ 0 ] ],
    "Gray0_100"            -> LightDarkSwitched[ GrayLevel[ 0 ], GrayLevel[ 1 ] ],
    "Red_DD1100_EE1F22"    -> LightDarkSwitched[ RGBColor[ "#DD1100" ], RGBColor[ "#EE1F22" ] ],
    "Red_ED6541_A72F1E"    -> LightDarkSwitched[ RGBColor[ "#ED6541" ], RGBColor[ "#A72F1E" ] ], (* pressed: ErrorMessageFatalCloseButtonBackgroundPressed, ErrorMessageFatalCloseButtonFramePressed, ErrorMessageFatalLabelButtonBackgroundPressed *)
    "Red_F1DEDE_804840"    -> LightDarkSwitched[ RGBColor[ "#F1DEDE" ], RGBColor[ "#804840" ] ], (* hover: AssistantOutputErrorMenuButtonBackgroundHover *)
    "Red_FF8A7A_A74436"    -> LightDarkSwitched[ RGBColor[ "#FF8A7A" ], RGBColor[ "#A74436" ] ],
    "Red_FFA597_CF5443"    -> LightDarkSwitched[ RGBColor[ "#FFA597" ], RGBColor[ "#CF5443" ] ], (* hover: ErrorMessageFatalCloseButtonFrameHover, ErrorMessageFatalLabelButtonFrameHover *)
    "Red_FFCAC2_CF5443"    -> LightDarkSwitched[ RGBColor[ "#FFCAC2" ], RGBColor[ "#CF5443" ] ], (* hover: ErrorMessageFatalCloseButtonBackgroundHover, ErrorMessageFatalLabelButtonBackgroundHover *)
    "Orange_F09215_B25B02" -> LightDarkSwitched[ RGBColor[ "#F09215" ], RGBColor[ "#B25B02" ] ], (* pressed: ErrorMessageNonFatalCloseButtonBackgroundPressed, ErrorMessageNonFatalCloseButtonFramePressed, ErrorMessageNonFatalLabelButtonBackgroundPressed *)
    "Orange_F1E7DE_5D5442" -> LightDarkSwitched[ RGBColor[ "#F1E7DE" ], RGBColor[ "#5D5442" ] ], (* hover: AssistantOutputWarningMenuButtonBackgroundHover *)
    "Orange_FAC14D_CD7E16" -> LightDarkSwitched[ RGBColor[ "#FAC14D" ], RGBColor[ "#CD7E16" ] ],
    "Orange_FBC24E_F09215" -> LightDarkSwitched[ RGBColor[ "#FBC24E" ], RGBColor[ "#F09215" ] ], (* hover: ErrorMessageNonFatalCloseButtonFrameHover, ErrorMessageNonFatalLabelButtonFrameHover *)
    "Orange_FFE2A7_F09215" -> LightDarkSwitched[ RGBColor[ "#FFE2A7" ], RGBColor[ "#F09215" ] ], (* hover: ErrorMessageNonFatalCloseButtonBackgroundHover, ErrorMessageNonFatalLabelButtonBackgroundHover *)
    "Teal_004A54_009CB2"   -> LightDarkSwitched[ RGBColor[ "#004A54" ], RGBColor[ "#009CB2" ] ],
    "Teal_0094A9_009CB2"   -> LightDarkSwitched[ RGBColor[ "#0094A9" ], RGBColor[ "#009CB2" ] ],
    "Teal_80CAD4_3D6166"   -> LightDarkSwitched[ RGBColor[ "#80CAD4" ], RGBColor[ "#3D6166" ] ],
    "Teal_8CA5AA_91ABB0"   -> LightDarkSwitched[ RGBColor[ "#8CA5AA" ], RGBColor[ "#91ABB0" ] ],
    "Blue_008AC5_3FB9F9"   -> LightDarkSwitched[ RGBColor[ "#008AC5" ], RGBColor[ "#3FB9F9" ] ],
    "Blue_0549A6_48AAF2"   -> LightDarkSwitched[ RGBColor[ "#0549A6" ], RGBColor[ "#48AAF2" ] ],
    "Blue_128ED1_7FC7FB"   -> LightDarkSwitched[ RGBColor[ "#128ED1" ], RGBColor[ "#7FC7FB" ] ], (* hover: ThumbsUpDownIconHover *)
    "Blue_169ED0_46B9EA"   -> LightDarkSwitched[ RGBColor[ "#169ED0" ], RGBColor[ "#46B9EA" ] ],
    "Blue_2FA7DC_87D0F9"   -> LightDarkSwitched[ RGBColor[ "#2FA7DC" ], RGBColor[ "#87D0F9" ] ],
    "Blue_3383AC_145F89"   -> LightDarkSwitched[ RGBColor[ "#3383AC" ], RGBColor[ "#145F89" ] ], (* pressed: ErrorMessageBlockedCloseButtonBackgroundPressed, ErrorMessageBlockedCloseButtonFramePressed, ErrorMessageBlockedLabelButtonBackgroundPressed *)
    "Blue_3383AC_58BBEA"   -> LightDarkSwitched[ RGBColor[ "#3383AC" ], RGBColor[ "#58BBEA" ] ], (* hover: NA_ChatInputFieldFocusNotebookIconHover_3 *)
    "Blue_3383AC_BDE4FF"   -> LightDarkSwitched[ RGBColor[ "#3383AC" ], RGBColor[ "#BDE4FF" ] ], (* hover: NA_OverlayMenuIconHover *)
    "Blue_3DCBFF_4799BE"   -> LightDarkSwitched[ RGBColor[ "#3DCBFF" ], RGBColor[ "#4799BE" ] ], (* hover: ManagerGridPeelOffIconHover *)
    "Blue_469ECB_469ECB"   -> LightDarkSwitched[ RGBColor[ "#469ECB" ], RGBColor[ "#469ECB" ] ],
    "Blue_469ECB_56B2E1"   -> LightDarkSwitched[ RGBColor[ "#469ECB" ], RGBColor[ "#56B2E1" ] ],
    "Blue_469ECB_659FE1"   -> LightDarkSwitched[ RGBColor[ "#469ECB" ], RGBColor[ "#659FE1" ] ],
    "Blue_4A95CC_67B5EC"   -> LightDarkSwitched[ RGBColor[ "#4A95CC" ], RGBColor[ "#67B5EC" ] ],
    "Blue_536266_B4CED3"   -> LightDarkSwitched[ RGBColor[ "#536266" ], RGBColor[ "#B4CED3" ] ],
    "Blue_55B1D8_5BA6C8"   -> LightDarkSwitched[ RGBColor[ "#55B1D8" ], RGBColor[ "#5BA6C8" ] ], (* hover: PreferencesContentLLMSignInButtonFontHover *)
    "Blue_66ADD2_659FE1"   -> LightDarkSwitched[ RGBColor[ "#66ADD2" ], RGBColor[ "#659FE1" ] ],
    "Blue_66ADD2_66ADD2"   -> LightDarkSwitched[ RGBColor[ "#66ADD2" ], RGBColor[ "#66ADD2" ] ],
    "Blue_678E9C_98C7D6"   -> LightDarkSwitched[ RGBColor[ "#678E9C" ], RGBColor[ "#98C7D6" ] ],
    "Blue_75C2EB_669CBD"   -> LightDarkSwitched[ RGBColor[ "#75C2EB" ], RGBColor[ "#669CBD" ] ], (* hover: NA_ChatInputFieldFocusFontHover; pressed: NA_BlueHueButtonFramePressed, NA_ChatbarMinimizedButtonFramePressed, NA_ChatCodeBlockTemplateButtonFramePressed *)
    "Blue_7DC7EE_3389B9"   -> LightDarkSwitched[ RGBColor[ "#7DC7EE" ], RGBColor[ "#3389B9" ] ],
    "Blue_96CFED_Auto"     -> LightDarkSwitched[ RGBColor[ "#96CFED" ] ],
    "Blue_97CFED_577C94"   -> LightDarkSwitched[ RGBColor[ "#97CFED" ], RGBColor[ "#577C94" ] ], (* hover: NA_ChatInputFieldFocusNotebookIconHover_2 *)
    "Blue_A1CDE4_607E91"   -> LightDarkSwitched[ RGBColor[ "#A1CDE4" ], RGBColor[ "#607E91" ] ], (* hover: NA_CloudToolbarButtonFrameHover *)
    "Blue_A3C9F2_5F88B8"   -> LightDarkSwitched[ RGBColor[ "#A3C9F2" ], RGBColor[ "#5F88B8" ] ],
    "Blue_A3D5F0_3E9CD1"   -> LightDarkSwitched[ RGBColor[ "#A3D5F0" ], RGBColor[ "#3E9CD1" ] ], (* hover: ErrorMessageBlockedCloseButtonBackgroundHover, ErrorMessageBlockedLabelButtonFrameHover *)
    "Blue_B1D5E8_607D8F"   -> LightDarkSwitched[ RGBColor[ "#B1D5E8" ], RGBColor[ "#607D8F" ] ], (* hover: NA_BlueHueButtonFrameHover, NA_ChatbarMinimizedButtonFrameHover, NA_ChatCodeBlockTemplateButtonFrameHover *)
    "Blue_BFC8CC_7E8588"   -> LightDarkSwitched[ RGBColor[ "#BFC8CC" ], RGBColor[ "#7E8588" ] ],
    "Blue_C8E9FB_3E9CD1"   -> LightDarkSwitched[ RGBColor[ "#C8E9FB" ], RGBColor[ "#3E9CD1" ] ], (* hover: ErrorMessageBlockedCloseButtonFrameHover, ErrorMessageBlockedLabelButtonBackgroundHover *)
    "Blue_D0DEEC_4F5C6F"   -> LightDarkSwitched[ RGBColor[ "#D0DEEC" ], RGBColor[ "#4F5C6F" ] ], (* hover: AssistantOutputMenuButtonBackgroundHover *)
    "Blue_D4F0FF_344858"   -> LightDarkSwitched[ RGBColor[ "#D4F0FF" ], RGBColor[ "#344858" ] ],
    "Blue_D4F0FF_385061"   -> LightDarkSwitched[ RGBColor[ "#D4F0FF" ], RGBColor[ "#385061" ] ], (* pressed: NA_BlueHueButtonBackgroundPressed, NA_ChatCodeBlockTemplateButtonBackgroundPressed *)
    "Blue_D5E6F5_293B4D"   -> LightDarkSwitched[ RGBColor[ "#D5E6F5" ], RGBColor[ "#293B4D" ] ],
    "Blue_DDEFF9_2B658F"   -> LightDarkSwitched[ RGBColor[ "#DDEFF9" ], RGBColor[ "#2B658F" ] ],
    "Blue_E0F2FC_344858"   -> LightDarkSwitched[ RGBColor[ "#E0F2FC" ], RGBColor[ "#344858" ] ], (* pressed: NA_ChatbarMinimizedButtonBackgroundPressed *)
    "Blue_E8EEF3_4A545F"   -> LightDarkSwitched[ RGBColor[ "#E8EEF3" ], RGBColor[ "#4A545F" ] ],
    "Blue_E9F7FF_2D3E4C"   -> LightDarkSwitched[ RGBColor[ "#E9F7FF" ], RGBColor[ "#2D3E4C" ] ],
    "Blue_E9F7FF_405A6E"   -> LightDarkSwitched[ RGBColor[ "#E9F7FF" ], RGBColor[ "#405A6E" ] ],
    "Blue_EBF3F7_37424A"   -> LightDarkSwitched[ RGBColor[ "#EBF3F7" ], RGBColor[ "#37424A" ] ],
    "Blue_ECF0F5_48505F"   -> LightDarkSwitched[ RGBColor[ "#ECF0F5" ], RGBColor[ "#48505F" ] ],
    "Blue_EEF9FF_263541"   -> LightDarkSwitched[ RGBColor[ "#EEF9FF" ], RGBColor[ "#263541" ] ], (* hover: NA_ChatbarMinimizedButtonBackgroundHover *)
    "Blue_F1F8FF_474747"   -> LightDarkSwitched[ RGBColor[ "#F1F8FF" ], RGBColor[ "#474747" ] ], (* inline reference chip background; its hover is Gray100_31 *)
    "Blue_F2F7FC_2D3646"   -> LightDarkSwitched[ RGBColor[ "#F2F7FC" ], RGBColor[ "#2D3646" ] ],
    "Blue_F9FDFF_1D1F21"   -> LightDarkSwitched[ RGBColor[ "#F9FDFF" ], RGBColor[ "#1D1F21" ] ],
    "Blue_FCFDFF_232A32"   -> LightDarkSwitched[ RGBColor[ "#FCFDFF" ], RGBColor[ "#232A32" ] ],
    "Blue_FFFFFF_212326"   -> LightDarkSwitched[ GrayLevel[ 1 ], RGBColor[ "#212326" ] ]
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*color*)
color // beginDefinition;
color[ name_String ] := With[ { c = $colorData @ name }, c /; MatchQ[ c, _LightDarkSwitched ] ];
color // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
