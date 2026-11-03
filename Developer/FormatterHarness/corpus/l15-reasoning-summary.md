<think type='summary' id='rs8f2k1m9q0zx'>
**Understanding the request**

The user wants to compute the eigenvalues of a large sparse matrix and is running out of memory with `Eigenvalues`. I should explain why dense methods fail and point them to the sparse options.
</think>
<think type='summary' id='rs3n7b5v1c8lp'>
**Choosing an approach**

For a sparse matrix, the Arnoldi method computes a few eigenvalues without forming a dense matrix. In Wolfram Language this is `Eigenvalues[m, k, Method -> "Arnoldi"]`. I'll also mention `"Criteria"` and shift-invert for interior eigenvalues.
</think>
When `Eigenvalues` runs out of memory on a large matrix, it's usually because it's computing **all** eigenvalues with a dense method, which needs $O(n^2)$ memory and $O(n^3)$ time. For a $50{,}000 \times 50{,}000$ matrix, the dense representation alone takes about 20 GB.

## Use a sparse matrix and ask for only a few eigenvalues

First, make sure the matrix is stored as a [`SparseArray`](paclet:ref/SparseArray):

```wl
n = 50000;
m = SparseArray[{
    Band[{1, 1}] -> 2.,
    Band[{1, 2}] -> -1.,
    Band[{2, 1}] -> -1.
  }, {n, n}];
ByteCount[m]
```

Then request only the eigenvalues you need. The second argument `k` gives the number of eigenvalues, and `Method -> "Arnoldi"` uses an iterative algorithm that only needs matrix-vector products:

```wl
Eigenvalues[m, 6, Method -> {"Arnoldi", "Criteria" -> "RealPart"}]
```

## Which eigenvalues you get

| `k` | Result |
|:----|:-------|
| `k` (positive) | the $k$ largest in absolute value |
| `-k` (negative) | the $k$ smallest in absolute value |
| `{k1, k2}` | the $k_1$-th through $k_2$-th largest |

For the smallest eigenvalues of a symmetric positive definite matrix, the **shift-invert** mode is much faster:

```wl
Eigenvalues[m, -6, Method -> {"Arnoldi", "Shift" -> 0}]
```

For this tridiagonal matrix, the exact eigenvalues are $\lambda_j = 2 - 2\cos\left(\frac{j\pi}{n + 1}\right)$, so you can check the result.
