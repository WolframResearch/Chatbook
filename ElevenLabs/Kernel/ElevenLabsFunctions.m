BeginPackage["ElevenLabsFunctions`"]

System`AudioStreams

AudioStreamFromFile

Needs["AudioFileStreamTools`"]


Begin["`Private`"]


waitReadStream[file_String, timeConstraint_] := Block[{stream},
    TimeConstrained[
        While[! Quiet @ Check[stream = FileStreamOpenRead[file]; True, False, FileStreamOpenRead::openreadfail], Pause[0.1]];
        stream,
        timeConstraint
    ]
]


AudioStreamFromFile[file_String, initTimeConstraint_ : 10, timeConstraint_ : 1] := Enclose @ Module[{
    stream,
    info,
    sampleRate,
    channels
},
    stream = Confirm @ waitReadStream[ConfirmBy[file, FileExistsQ], initTimeConstraint];
    info = FileStreamGetMetaInformation[stream];
    sampleRate = info["SampleRate"];
    channels = info["ChannelCount"];
    prevFrameCount = info["TotalFrameCount"];
    AudioStream[times |->
        Block[{bufferSize = Length[times], begin, end, frameCount = prevFrameCount},
            begin = Floor[ sampleRate * First[times] ];
            end = Round[ sampleRate * Last[times] ];
            If[ end > frameCount,
                TimeConstrained[
                    While[prevFrameCount === frameCount,
                        FileStreamClose[stream];
                        stream = FileStreamOpenRead[file];
                        frameCount = FileStreamGetMetaInformation[stream]["TotalFrameCount"];
                        Pause[0.1]
                    ],
                    timeConstraint
                ]
            ];
            prevFrameCount = frameCount;
            If[ begin > frameCount,
                FileStreamClose[stream]; {},
                FileStreamSetReadPosition[stream, begin];
                If[ end > frameCount,
                    PadRight[Normal[FileStreamReadN[stream, frameCount - begin + 1]], {channels, bufferSize}],
                    FileStreamReadN[stream, bufferSize]
                ]
            ]
        ],
        SampleRate -> sampleRate,
        "BufferSize" -> 8192,
        "BufferLatencyCount" -> 1
    ]
]

End[]
EndPackage[]

