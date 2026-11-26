# Why care about terseness (aka expressiveness) in the age of LLM's?

Ask an LLM for a finite impulse response filter and you can have a loop, a matrix expression, or a library call before you’ve decided what to name the output. If the case for a terse language rests on saving keystrokes, that case just got considerably weaker.

Now ask the model to turn convolution into correlation. It hands you a diff. Before you accept it, what do you look for?

## The one-word edit

Suppose the first three samples are `1, 2, 4` in time order, and the filter coefficients (the *taps*) are `1, 2, 3`. The first tap multiplies the newest sample. The first full window should give $1(4)+2(2)+3(1)=11$. For cross-correlation with these real taps, pair the first tap with the oldest sample instead. Now the answer should be $1(1)+2(2)+3(4)=17$. A three-point moving average would make a lousy test here. Reverse three equal weights and you get the same answer.

Here’s the filter at the Mojj prompt. Mojj is a J-inspired array language embedded in Mojo. The prompt accepts `=:` for assignment. Type a name on its own to inspect the value.

```text
samples =: 1 2 4 8 16
taps =: 1 2 3
windows =: (tally taps) (identity prefix) samples
filtered =: windows dot (reverse taps)
filtered
```

The answer is `[11, 22, 44]`. Keep the windows and evaluate one more line.

```text
windows dot taps
```

That gives `[17, 34, 68]`. I like `reverse taps` because I can point to the convention I’m most likely to get wrong. I can predict what removing it will do and check that prediction with pencil arithmetic. I find `identity prefix` harder to read. You have to know that `prefix`, given a width on its left, visits each complete sliding window. Applying `identity` returns the window itself. NumPy’s `sliding_window_view` spends more characters to tell a newcomer what’s happening. I’d give NumPy the point on that line. [Run the filter and compare the spellings](ALGORITHMS.md#filter-a-signal).

That’s the qualification I’d put on the “aka” in the title. Terseness counts how little you write. Expressiveness concerns which ideas you can say directly. They coincide when a short expression names the very thing you want to inspect or change. Sometimes adding a word buys you that economy.

## Six weights in four spellings

Consider one line of backpropagation. Two input features feed three hidden units. We already know how sensitive the loss is to each unit’s preactivation. To get the gradient for a particular weight, multiply its input feature by the sensitivity of the unit it feeds. We need all six pairings.

| Notation | Gradient of the input weights |
| --- | --- |
| Mathematics, with $x$ and $d_z$ defined as row vectors | $x^{\mathsf T} d_z$ |
| NumPy | `np.outer(x, dz)` |
| Mojj words | `x times table dz` |
| J | `x */ dz` |

The equation is lovely if the vector orientations are fresh in your mind. Arrive halfway down the page and you may have to scroll back to discover why that product gives a matrix. NumPy answers the question with one word, `outer`. Mojj offers another way to see it. Picture a multiplication table with two inputs labeling the rows and three sensitivities labeling the columns. You can tell me both the shape of the result and what goes in the bottom-right cell.

What does J buy with `*/`? For a reader who knows J, the multiplication sign is a replaceable part. Change `*` to `+` and the same construction gives every pairwise sum. In Mojj the corresponding edit is `times table` to `plus table`. The time spent learning `table` pays off across operations. For someone reading this gradient once, `outer` may still be the better bargain. [Run the training step and inspect its gradients](ALGORITHMS.md#train-a-two-layer-network-for-one-step).

An LLM can explain any of those spellings. It can also confidently explain a transposed gradient. The outer product with its arguments swapped still gives six plausible numbers. If you know to expect two rows and three columns, you have a check independent of the explanation. This is where the cost of reading matters most to me. I can delegate the first draft and still want a representation in which I can catch my own mistake about what I asked for.

## How short should an FFT be?

For someone processing an audio signal, `np.fft.fft(samples)` may say everything necessary. For someone studying the fast Fourier transform, the interesting decision is hidden inside the call. Even the typeset Fourier sum leaves a question open. Evaluating that sum independently for each of $N$ outputs costs order $N^2$ operations. Where does the fast algorithm save the work?

Take a radix-2 transform with a power-of-two length. Let $E_k$ and $O_k$ be the transforms of the even- and odd-indexed samples, and let $W_N=e^{-2\pi i/N}$. Each pair of outputs shares a product.

$$
X_k = E_k + W_N^k O_k, \qquad
X_{k+N/2} = E_k - W_N^k O_k.
$$

In code I’d spend an extra line on `t = twiddle * odd`, then write `even + t` and `even - t`. The name makes the reuse visible. The other half of the explanation lives one level up. Compute each half-size transform once, spend linear work combining the results, and repeat across $\log_2 N$ levels. Both the butterfly and the decomposition belong in an explanation of the algorithm. For an edit to the inverse transform, I’d want to find two conventions just as easily as I found `reverse taps`. Where is the sign in the twiddle factor set, and where does the normalization by $N$ happen?

## When the equation runs out

Imagine flooding an image from two labeled seeds. Each basin spreads to neighboring pixels as the water rises. On a flat patch, two fronts can reach a pixel at the same height. Which label does it receive? Could it have been reached diagonally? A call like `watershed(image, markers)` can be perfectly readable while telling you little about either decision.

For the neighbor question, I’d sooner read a four-pixel example than another paragraph of API description. Put a seed in the upper-left pixel of a two-by-two mask. Allow flooding only there and in the lower-right pixel. With four-neighbor connectivity the seed has nowhere to go. With eight-neighbor connectivity it can label the lower-right pixel in one step. That tiny mask settles the meaning of an edit. A separate fixture with two seeds on a plateau would expose the tie rule. Here the most economical notation might be a picture beside the call.

## Give the reader an edit

When comparing languages, give the reader a change to make. Keep the inputs fixed. Ask which line they would touch and which output should change. Turning convolution into correlation tests whether the coefficient order is visible. Switching the network to leaky ReLU asks the reader to find both the forward activation and the backward derivative. An input that drives a hidden unit below zero makes a missed edit show up in its gradient.

This changes what I ask an LLM for, too. “Make it shorter” is easy to satisfy badly. “Write it so I can see which coefficient multiplies the newest sample” identifies a decision I’ll need to review. Sometimes the result will be a two-character idiom. Sometimes it will be a descriptive function name, a second line for a shared product, or a little matrix printed beside the calculation.

I care about terseness because there’s a moment after the code arrives when I still have to decide whether it says what I mean. In the filter I can point to one word and tell you, before I run the edit, that 11 will become 17. That’s the kind of short I want.
