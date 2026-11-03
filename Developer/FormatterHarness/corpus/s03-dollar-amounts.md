Based on the current pricing, the Standard plan costs $25 per month, while the Pro plan is $45 per month (or $450 per year if billed annually). Adding an extra seat is $10.

So for a team of three on the Pro plan, you'd pay $45 + 2 × $10 = $65 per month.

If you want to model this in Wolfram Language, you can use `Quantity` with currency units:

```wl
cost[n_] := Quantity[45, "USDollars"] + (n - 1) Quantity[10, "USDollars"]
cost[3]
```

The general formula is $C(n) = 45 + 10(n - 1)$ for $n \geq 1$ users.
