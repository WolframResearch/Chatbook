## Solving equations symbolically and numerically

Wolfram Language distinguishes between *symbolic* solvers, which return exact solutions, and *numeric* solvers, which return approximations. Choosing the right one depends on the equation.

### Polynomial equations

For a quadratic equation $a x^2 + b x + c = 0$, [`Solve`](paclet:ref/Solve) returns the familiar formula:

```wl
In[1]:= Solve[a x^2 + b x + c == 0, x]

Out[1]= {{x -> (-b - Sqrt[b^2 - 4 a c])/(2 a)}, {x -> (-b + Sqrt[b^2 - 4 a c])/(2 a)}}
```

In traditional notation, that's

$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$

The expression under the square root, \(\Delta = b^2 - 4ac\), is the *discriminant*:

- If \(\Delta > 0\), there are two distinct real roots.
- If \(\Delta = 0\), there is one repeated real root.
- If \(\Delta < 0\), the roots are complex conjugates.

For higher-degree polynomials, `Solve` may return [`Root`](paclet:ref/Root) objects, which are exact representations of algebraic numbers:

```wl
Solve[x^5 - x + 1 == 0, x]
```

Use `N` to get numerical values: `N[Solve[x^5 - x + 1 == 0, x]]`.

### Systems of equations

Solve a linear system by listing the equations:

```wl
Solve[{2 x + 3 y == 7, x - y == 1}, {x, y}]
(* {{x -> 2, y -> 1}} *)
```

For a system in matrix form \(A \mathbf{x} = \mathbf{b}\), [`LinearSolve`](paclet:ref/LinearSolve) is faster:

```wl
A = {{2, 3}, {1, -1}};
b = {7, 1};
LinearSolve[A, b]
```

### Restricting the domain

By default, `Solve` works over the complex numbers. To get only real solutions, specify the domain:

```wl
In[5]:= Solve[x^4 == 16, x]

Out[5]= {{x -> -2}, {x -> -2 I}, {x -> 2 I}, {x -> 2}}

In[6]:= Solve[x^4 == 16, x, Reals]

Out[6]= {{x -> -2}, {x -> 2}}
```

You can also add conditions like `x > 0` directly to the equations: `Solve[x^4 == 16 && x > 0, x]`.

### Transcendental equations

Equations involving $\sin$, $e^x$, or $\log$ often have infinitely many solutions or no closed form. `Solve` will return solutions with a `ConditionalExpression` and integer parameter $c_1$:

```wl
Solve[Sin[x] == 1/2, x]
```

which corresponds to

\[ x = \frac{\pi}{6} + 2\pi c_1 \quad \text{or} \quad x = \frac{5\pi}{6} + 2\pi c_1, \quad c_1 \in \mathbb{Z} \]

For a numerical root near a starting point, use [`FindRoot`](paclet:ref/FindRoot):

```wl
FindRoot[Cos[x] == x, {x, 1}]
(* {x -> 0.739085} *)
```

> `FindRoot` finds *one* root near the starting value. If you need all roots in an interval, use `NSolve` with a domain restriction, or `Reduce`.

### Differential equations

[`DSolve`](paclet:ref/DSolve) finds symbolic solutions of ODEs. For the harmonic oscillator $y''(t) + \omega^2 y(t) = 0$:

```wl
DSolve[y''[t] + w^2 y[t] == 0, y[t], t]
```

The general solution is $y(t) = c_1 \cos(\omega t) + c_2 \sin(\omega t)$. With initial conditions:

```wl
DSolve[{y''[t] + 4 y[t] == 0, y[0] == 1, y'[0] == 0}, y[t], t]
(* {{y[t] -> Cos[2 t]}} *)
```

For nonlinear equations without closed-form solutions, use [`NDSolve`](paclet:ref/NDSolve):

```wl
sol = NDSolve[{x''[t] + Sin[x[t]] == 0, x[0] == 1, x'[0] == 0}, x, {t, 0, 20}];
Plot[Evaluate[x[t] /. sol], {t, 0, 20}]
```

This is the nonlinear pendulum, $\ddot{\theta} + \sin\theta = 0$, which for small angles reduces to $\ddot{\theta} + \theta = 0$.

### Inequalities and Reduce

[`Reduce`](paclet:ref/Reduce) gives a complete description of the solution set, including all the conditions:

```wl
In[12]:= Reduce[x^2 - 3 x + 2 < 0, x]

Out[12]= 1 < x < 2
```

The result says $1 < x < 2$, which matches factoring: $(x - 1)(x - 2) < 0$.

### Summary

| Function | Result | Use when |
|:---------|:-------|:---------|
| `Solve` | Exact solutions | Algebraic equations, small systems |
| `NSolve` | Numerical solutions | Polynomials, all roots needed |
| `FindRoot` | One numerical root | Transcendental equations |
| `Reduce` | Complete solution set | Inequalities, parameters |
| `DSolve` | Symbolic ODE/PDE solution | Linear ODEs, many classical forms |
| `NDSolve` | Interpolating function | Nonlinear ODEs, PDEs |

The cost of each tool grows quickly with the number of variables. As a rough guide, a system of $n$ polynomial equations of degree $d$ can have up to $d^n$ solutions (Bézout's theorem), so `Solve` can be slow for even moderately sized nonlinear systems.
