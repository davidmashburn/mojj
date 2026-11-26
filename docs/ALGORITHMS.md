# Algorithms in Mojj

For a closer look at what these spellings make easy to read and change, see [Why care about terseness (aka expressiveness) in the age of LLM's?](TERSENESS.md).

## Filter a signal

A finite impulse response (FIR) filter takes a weighted sum of recent samples. Suppose the samples are `[1, 2, 4, 8, 16]` and the taps are `[1, 2, 3]`, with the first tap multiplying the newest sample. Compute only outputs with a full window. With zero-based indexing and $K$ taps, the definition is

$$
y_i = \sum_{j=0}^{K-1} h_j x_{i+K-1-j}, \qquad 0 \le i \le N-K.
$$

The first window, in time order, is `[1, 2, 4]`. Its output is $3(1)+2(2)+1(4)=11$. Asymmetric taps make a reversal mistake visible.

| Environment | Build overlapping windows and apply the weights |
| --- | --- |
| Wolfram Language (Mathematica) | `Partition[samples, Length[taps], 1] . Reverse[taps]` |
| NumPy | `np.lib.stride_tricks.sliding_window_view(samples, len(taps)) @ taps[::-1]` |
| MATLAB (row-vector inputs) | `k = numel(taps); windows = samples((1:numel(samples)-k+1).' + (0:k-1));`<br>`filtered = (windows * flip(taps(:))).';` |
| NuMojo | `var k = taps.size`<br>`var weights = nm.flip(taps)`<br>`var filtered = nm.zeros[i64](Shape(samples.size-k+1))`<br>`for i in range(filtered.size): filtered[Item(i)] = nm.dot(samples[i:i+k], weights).item()` |
| Mojj words | <code data-mojj><em>windows</em> =: (<strong>tally</strong> <em>taps</em>) (<strong>identity</strong> <ins>prefix</ins>) <em>samples</em></code><br><code data-mojj><em>filtered</em> =: <em>windows</em> <strong>dot</strong> (<strong>reverse</strong> <em>taps</em>)</code> |
| Mojj symbols | <code data-mojj><em>windows</em> =: (<strong>#</strong> <em>taps</em>) <strong>&#93;</strong><ins>&#92;</ins> <em>samples</em></code><br><code data-mojj><em>filtered</em> =: <em>windows</em> <strong>+</strong><ins>/</ins> <ins>.</ins> <strong>&#42;</strong> (<strong>&#124;.</strong> <em>taps</em>)</code> |
| J | <code data-mojj><em>windows</em> =: (<strong>#</strong> <em>taps</em>) <strong>&#93;</strong><ins>&#92;</ins> <em>samples</em></code><br><code data-mojj><em>filtered</em> =: <em>windows</em> <strong>+</strong><ins>/</ins> <ins>.</ins> <strong>&#42;</strong> (<strong>&#124;.</strong> <em>taps</em>)</code> |

Run `pixi run mojj < examples/algorithms/fir.mojj`. The output is `[11, 22, 44]`. NumPy also offers the complete operation as `np.convolve(samples, taps, mode="valid")` for these inputs.

**Try one edit.** To compute valid cross-correlation with these real taps, keep the windows and use the taps in their original order. The first output becomes 17. The equation makes the time index explicit. The staged Mojj program gives you a place to inspect the windows, and the edit is local to `reverse taps`. Reading `identity prefix` takes some vocabulary: with a width on the left, `prefix` visits each complete window, and `identity` returns its contents.

## Train a two-layer network for one step

Run `pixi run mojj < examples/algorithms/neural_step.mojj`. This is one SGD update on one example, with a ReLU hidden layer, a scalar linear output, fixed initial weights, and zero biases. The script computes both weight gradients explicitly.

Let $x$ be a row of two features, $W$ a $2\times3$ matrix, and $w$ three output weights. The forward pass and half-squared loss are

$$
z=xW,\qquad h=\max(0,z),\qquad \hat y=h\cdot w,\qquad L=\tfrac12(\hat y-y)^2.
$$

With $e=\hat y-y$, the hidden gradient is $d_z=e\,w\odot\mathbf{1}_{z>0}$. The input-weight gradient is the outer product $x^\mathsf{T} d_z$, treating $d_z$ as a row. These three lines show where the notation matters.

| Step | Wolfram Language | NumPy | MATLAB (row vectors) | NuMojo | Mojj words | Mojj symbols | J |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Hidden preactivation | `x . W` | `x @ W` | `x * W` | `x @ W` | <code data-mojj><em>x</em> <strong>dot</strong> <em>W</em></code> | <code data-mojj><em>x</em> <strong>+</strong><ins>/</ins> <ins>.</ins> <strong>&#42;</strong> <em>W</em></code> | <code data-mojj><em>x</em> <strong>+</strong><ins>/</ins> <ins>.</ins> <strong>&#42;</strong> <em>W</em></code> |
| Hidden gradient | `(err w) (Boole[# > 0] & /@ z)` | `(err * w) * (z > 0)` | `(err .* w) .* (z > 0)` | `(err * w) * (z > 0).astype[f64]()` | <code data-mojj>(<em>err</em> <strong>&#42;</strong> <em>w</em>) <strong>&#42;</strong> (<em>z</em> <strong>greater</strong> <em>0</em>)</code> | <code data-mojj>(<em>err</em> <strong>&#42;</strong> <em>w</em>) <strong>&#42;</strong> (<em>z</em> <strong>&gt;</strong> <em>0</em>)</code> | <code data-mojj>(<em>err</em> <strong>&#42;</strong> <em>w</em>) <strong>&#42;</strong> (<em>z</em> <strong>&gt;</strong> <em>0</em>)</code> |
| Input-weight gradient | `Outer[Times, x, dz]` | `np.outer(x, dz)` | `x.' * dz` | `nm.outer(x, dz)` | <code data-mojj><em>x</em> <strong>times</strong> <ins>table</ins> <em>dz</em></code> | <code data-mojj><em>x</em> <strong>&#42;</strong><ins>/</ins> <em>dz</em></code> | <code data-mojj><em>x</em> <strong>&#42;</strong><ins>/</ins> <em>dz</em></code> |

**Try one edit.** Change the learning rate from 0.1 to zero. The script prints the loss before and after the update. At 0.1 the loss falls from 2 to 0.045 on this example. At zero both losses are 2. All gradients use the original weights. Moving the update of `w` before the calculation of `dz` would silently change the algorithm.

Here mathematical notation distinguishes elementwise multiplication ($\odot$) from a matrix product by typography. Mojj spells the three operations `*`, `dot`, and `times table`. The last spelling makes sense once you picture the table containing every pairwise product. Named intermediates let you inspect the activation mask and gradients in the CLI.
