Here's what happens when you evaluate it:

```wl
In[1]:= f[x_] := x^2 + 1

In[2]:= f /@ Range[5]

Out[2]= {2, 5, 10, 17, 26}

In[3]:= Integrate[f[x], {x, 0, 1}]

Out[3]= 4/3
```

The definition in `In[1]` uses `SetDelayed` (`:=`), so the right-hand side is evaluated each time `f` is called.
