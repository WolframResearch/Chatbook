Function[
 Graphics[
  {
   #1,
   CapForm[ "Butt" ],
   JoinForm[ "Round" ],
   Thickness[ 0.105 ],
   JoinedCurve[
    { { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } } },
    { { { 7.81, 0.38 }, { 1.08, 0.38 }, { 0.45, 8.92 }, { 8.44, 8.92 }, { 7.81, 0.38 } } },
    CurveClosed -> { 1 }
   ],
   JoinedCurve[ { { { 0, 2, 0 } } }, { { { 3.2, 7.02 }, { 3.2, 2.38 } } }, CurveClosed -> { 0 } ],
   JoinedCurve[ { { { 0, 2, 0 } } }, { { { 5.56, 7.02 }, { 5.56, 2.38 } } }, CurveClosed -> { 0 } ],
   JoinedCurve[ { { { 0, 2, 0 } } }, { { { 0.0, 10.79 }, { 8.83, 10.79 } } }, CurveClosed -> { 0 } ],
   JoinedCurve[
    { { { 0, 2, 0 } } },
    { { { 6.04, 11.81 }, { 2.78, 11.81 } } },
    CurveClosed -> { 0 }
   ]
  },
  ImageSize -> { 11.077, 16.0 },
  PlotRange -> { { 0.0, 8.83 }, { 0.0, 12.31 } },
  AspectRatio -> Automatic,
  ImagePadding -> { { 0, 1 }, { 1, 0 } },
  BaselinePosition -> Scaled[ 0 ]
 ]
]