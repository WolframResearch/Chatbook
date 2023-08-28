Function[
 Graphics[
  {
   #1,
   Disk[ { 0, 0 }, 2.5 ],
   White,
   Thickness[ 0.13 ],
   CapForm[ "Round" ],
   Line @ { { { -1, -1 }, { 1, 1 } }, { { 1, -1 }, { -1, 1 } } }
  },
  ImageSize -> 14 * { 1, 1 },
  ImagePadding -> { { 0, 1 }, { 1, 0 } },
  BaselinePosition -> Scaled[ 0.1 ]
 ]
]