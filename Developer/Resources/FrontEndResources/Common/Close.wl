(* Created with the Wolfram Language : www.wolfram.com *)
Function[Evaluate @ ToBoxes @
 Graphics[{{EdgeForm[#1], FaceForm[#2], Disk[{0, 0}, 9]}, {#3, 
   Line[4 {{-1, -1}, {1, 1}}], Line[4 {{1, -1}, {-1, 1}}]}}, 
 ImageSize -> {18, 18}, PlotRange -> {{-9, 9}, {-9, 9}}, 
 PlotRangePadding -> 0.5, ImageMargins -> {{0, 1}, {1, 0}}]]