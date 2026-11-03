Here's the full transcript, including printed output, echoes, and messages:

```wl
In[1]:= Do[Print[i^2], {i, 3}]

During evaluation of In[1]:= 1

During evaluation of In[1]:= 4

During evaluation of In[1]:= 9

In[2]:= Echo[Range[5], "range:"] // Total

>> range: {1, 2, 3, 4, 5}

Out[2]= 15

In[3]:= 1/0

Power::infy: Infinite expression 1/0 encountered.

Out[3]= ComplexInfinity

In[4]:= EchoTiming[Pause[0.5]; 42]

\[WatchIcon] 0.500982

Out[4]= 42
```

And a block with only an output label:

```wl
Out[7]= {1, 2, 3}
```

And one with a single input label:

```wl
In[8]:= Range[3]
```
