VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["first_symbol = 1;\nsecond_symbol = 2;\nfirst_symbol + second_symbol"], "firstSymbol = 1;\nsecondSymbol = 2;\nfirstSymbol + secondSymbol"
	,TestID->"1_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["x_1 = 1;\nx_2 = 2;\ny_1_2 = f[x_1, x_2]"], "x1 = 1;\nx2 = 2;\ny12 = f[x1, x2]"
	,TestID->"2_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["f[my_symbol] = 123"], Missing["No errors detected"]
	,TestID->"3_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["f[my_cool_symbol] = 123"], "f[myCoolSymbol] = 123"
	,TestID->"4_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_cool_symbol[a]"], "myCoolSymbol[a]"
	,TestID->"5_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_cool_1[a]"], "myCool1[a]"
	,TestID->"6_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_cool[a]"], "myCool[a]"
	,TestID->"7_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_1[a]"], "my1[a]"
	,TestID->"8_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_symbol := 123"], Missing["No errors detected"]
	,TestID->"9_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_cool_symbol := 123"], "myCoolSymbol := 123"
	,TestID->"10_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["f[x_1, x_2]"], "f[x1, x2]"
	,TestID->"11_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["x_1=2"], "x1=2"
	,TestID->"12_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["f[x_ 1, x_ 2]"], Missing["No errors detected"]
	,TestID->"13_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_offset = 123;\n(* my_string_length is a really neat function *)\nmy_string_length[test_String] := StringLength[test] + my_offset;\nmy_string_length[\"my_string_length\"]"], "myOffset = 123;\n(* my_string_length is a really neat function *)\nmyStringLength[testString] := StringLength[test] + myOffset;\nmyStringLength[\"my_string_length\"]"
	,TestID->"14_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_a=1"]["FixedCode"], "xA=1"
	,TestID->"15_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_a+1"]["FixedCode"], Missing["No errors detected"]
	,TestID->"16_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_ a =1"]["FixedCode"], Missing["Pattern not handled", {{"Error", "ImplicitTimesInSet"}}]
	,TestID->"17_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_ a +1"]["FixedCode"], Missing["No errors detected"]
	,TestID->"18_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_123=1"]["FixedCode"], "x123=1"
	,TestID->"19_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_123+1"]["FixedCode"], "x123+1"
	,TestID->"20_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_ 123=1"]["FixedCode"], Missing["Pattern not handled", {{"Error", "ImplicitTimesInSet"}}]
	,TestID->"21_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_ 123+1"]["FixedCode"], Missing["No errors detected"]
	,TestID->"22_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a=1"]["FixedCode"], "x1a=1"
	,TestID->"23_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a+1"]["FixedCode"], "x1a+1"
	,TestID->"24_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a9=1"]["FixedCode"], "x1a9=1"
	,TestID->"25_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a9+1"]["FixedCode"], "x1a9+1"
	,TestID->"26_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1 a9=1"]["FixedCode"], Missing["Pattern not handled", {{"Error", "ImplicitTimesInSet"}}]
	,TestID->"27_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1 a9+1"]["FixedCode"], "x1 a9+1"
	,TestID->"28_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a 9+1"]["FixedCode"], "x1a 9+1"
	,TestID->"29_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1_2=1"]["FixedCode"], "x12=1"
	,TestID->"30_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1_2:=1"]["FixedCode"], "x12:=1"
	,TestID->"31_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x__1___2:=1"]["FixedCode"], "x12:=1"
	,TestID->"32_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x___a_1__2b_CC__2:=1"]["FixedCode"], "xA12bCC2:=1"
	,TestID->"33_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_a=1; y__b_2_d=2;x_a + x_b + x__c_1"]["FixedCode"], "xA=1; yB2D=2;xA + x_b + xC1"
	,TestID->"34_badSnakeUsage_UT"]