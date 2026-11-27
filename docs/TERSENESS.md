# Why terseness still matters in the age of LLMs

Ask an LLM for a finite impulse response filter and you can have a loop, a matrix expression, or a library call before you’ve decided what to name the output. If the case for a terse language rests on saving keystrokes, that case just got considerably weaker.

Now ask the model to turn convolution into correlation. It hands you a diff. Before you accept it, what do you look for?

I’d look for the coefficient that multiplies the newest sample. I want to recognize that decision in code someone else wrote. That requires a distinction between terseness and expressiveness. Terseness counts how little I write. By *expressiveness* I mean how directly I can state an idea I care about. The two coincide when a short phrase lets me locate a decision, predict the effect of changing it, and check my prediction.

## The one-word edit

Suppose the samples, from oldest to newest, are `1, 2, 4, 8, 16`. The filter coefficients (the *taps*) are `1, 2, 3`. We want one output for each complete three-sample window, with the first tap multiplying the newest sample. On the first window I get $1(4)+2(2)+3(1)=11$.

Trace the first pass through this Python loop. The name `age` gives the minus sign a physical meaning. At age zero, the sample arrived just now.

```python
samples = [1, 2, 4, 8, 16]
taps = [1, 2, 3]
filtered = []
for newest in range(len(taps) - 1, len(samples)):
    filtered.append(sum(tap * samples[newest - age]
                        for age, tap in enumerate(taps)))
```

Here’s the same calculation at the Mojj prompt. Mojj is a J-inspired array language embedded in Mojo. Start it with `pixi run mojj` from the repository root. Use `=:` to save a value and type its name to see it.

<pre data-mojj="mojj"><code><em>samples</em> =: <em>1</em> <em>2</em> <em>4</em> <em>8</em> <em>16</em>
<em>taps</em> =: <em>1</em> <em>2</em> <em>3</em>
<em>windows</em> =: (<strong>tally</strong> <em>taps</em>) (<strong>identity</strong> <ins>prefix</ins>) <em>samples</em>
<em>windows</em>
<em>filtered</em> =: <em>windows</em> <strong>dot</strong> (<strong>reverse</strong> <em>taps</em>)
<em>filtered</em></code></pre>

`tally taps` supplies the width. With a width on its left, `prefix` visits complete sliding windows, and `identity` returns each window as it stands. Read the rows it produces below. The dot product pairs each row with the reversed taps, `3 2 1`.

| Window in time order | With reversed taps | With original taps |
| --- | ---: | ---: |
| 1, 2, 4 | 11 | 17 |
| 2, 4, 8 | 22 | 34 |
| 4, 8, 16 | 44 | 68 |

For valid cross-correlation with these real taps, the first tap multiplies the oldest sample. At the same prompt, drop `reverse` and enter `windows dot taps`. The corresponding Python edit is `enumerate(reversed(taps))`. Either way, I can predict the new first output, $1(1)+2(2)+3(4)=17$. Reversing the *outputs* would put 44 first. That’s a different edit, and these five samples tell the difference.

What did brevity buy here? Read the Python loop again and account for its two indices. To check tap order, I also have to check where `newest` starts and what `age` counts. In `windows dot (reverse taps)` I can see the weights, their order, and the operation that consumes them in one glance. The indexing work is already accounted for by the rows on the screen. Replacing `windows` and `taps` with `u` and `v` would save more letters and give me two more things to remember.

I still have to look twice at Mojj’s `identity prefix`. NumPy’s `sliding_window_view` spends more characters to tell me what I’m about to get. A colleague who reads NumPy every day could reasonably choose its spelling for both of us. [Compare the filter across languages](ALGORITHMS.md#filter-a-signal).

## Why learn the notation if the model can translate it?

Here’s the strongest objection I know. Keep the conventional implementation in the repository. When I want to see the math, ask for the equation. When my colleague wants to understand an index, ask for a loop. Why make either of us learn another language?

For a one-off use of an established operation, I’d take that bargain. If the job is to apply valid convolution, `np.convolve(samples, taps, mode="valid")` is an excellent line to keep. The name tells the next reader where to look up the contract. With the table above in a test, I’d be happy to let a model write that call and move on.

The bargain changes when the convention itself is under development. Suppose the model writes a correlation, calls it a convolution, and illustrates it with a three-point moving average. Its explanation can agree with every output it shows. Reversing three equal taps leaves them unchanged. Asking for a second spelling of that example buys me very little. Choosing taps `1, 2, 3` and calculating 11 *before* I inspect the answer gives me an independent check. The model can do the translation. Someone still has to decide which two meanings a test ought to distinguish.

There is a benefit on the next edit, too. In the Mojj version the windows have a name. I can inspect them, keep them fixed while I change the weights, or give them to the next person investigating a boundary error. A generated explanation lives beside the running program. A named value in the program lets both of us ask the running calculation the same question. Python can name the windows too. That’s a reason to keep the intermediate in either language. The further question for Mojj is whether learning a word once helps me read or invent an operation I haven’t seen before.

## Six weights and one silent mistake

Consider a single training example for a neural network. Two input features feed three hidden units. We know the input vector `x` and the sensitivity `dz` of the loss to each hidden unit’s input. What gradient belongs to the weight connecting feature $i$ to unit $j$? The chain rule gives $x_i\,dz_j$. We need all six pairings.

| Notation | Gradient of the input weights |
| --- | --- |
| Mathematics, with $x$ and $d_z$ defined as row vectors | $x^{\mathsf T} d_z$ |
| NumPy | `np.outer(x, dz)` |
| Mojj words | <code data-mojj><em>x</em> <strong>times</strong> <ins>table</ins> <em>dz</em></code> |
| J | <code data-mojj><em>x</em> <strong>&#42;</strong><ins>/</ins> <em>dz</em></code> |

I can read the Mojj line as instructions for a multiplication table. Write the two features down the side, the three sensitivities across the top, and fill in the cells. Swapping the operands still produces six plausible numbers. Drawing the table tells me which shape to expect and which weight each number will update. The two characters in the J spelling do separate jobs. Change `*` to `+` in `x */ dz` and you get every pairwise sum. The Mojj edit is `times table` to `plus table`. Once I know what `table` does, I can use it to pose a new question without first asking whether the library has a function named for it.

Suppose I ask the model, “Make the hidden units leaky so negative inputs can learn.” The existing network uses ReLU, which sets negative inputs to zero. We want it to pass a tenth of each negative input and leave positive inputs alone. That changes two calculations during training. Start a fresh Mojj session and run this example with the original weights, before taking an optimizer step.

<pre data-mojj="mojj"><code><em>x</em> =: <em>1</em> <em>2</em>
<em>W</em> =: <em>2</em> <em>3</em> <strong>reshape</strong> <em>1</em> <em>_1</em> <em>0.5</em> <em>0</em> <em>0.25</em> <em>0.5</em>
<em>w</em> =: <em>0.5</em> <em>1</em> <em>_1</em>
<em>target</em> =: <em>1.0</em>
<em>alpha</em> =: <em>0.1</em>
<em>z</em> =: <em>x</em> <strong>dot</strong> <em>W</em>
<em>h</em> =: <em>z</em> <strong>max</strong> (<em>alpha</em> <strong>*</strong> <em>z</em>)
<em>err</em> =: (<em>h</em> <strong>dot</strong> <em>w</em>) <strong>-</strong> <em>target</em>
<em>slope</em> =: <em>alpha</em> <strong>+</strong> ((<em>1</em> <strong>-</strong> <em>alpha</em>) <strong>*</strong> (<em>z</em> <strong>greater</strong> <em>0</em>))
<em>dz</em> =: (<em>err</em> <strong>*</strong> <em>w</em>) <strong>*</strong> <em>slope</em>
<em>x</em> <strong>times</strong> <ins>table</ins> <em>dz</em></code></pre>

The middle unit is the interesting one. Its input is $-1+2(0.25)=-0.5$. It used to output zero and now outputs $-0.05$. Its output weight is 1, so this lowers the network’s prediction from $-1$ to $-1.05$. A test of the prediction would pass as soon as we changed `h`.

Can the middle unit now *learn*? Under half-squared error the new prediction error is $-2.05$. Multiply by the middle output weight (1) and by the slope on the negative side (0.1). The middle unit’s sensitivity is $-0.205$. Its column in the gradient table should therefore contain $-0.205$ and $-0.410$, one entry for each input feature. If the backward pass still uses the old zero-or-one ReLU mask, both entries are zero. The correct forward prediction can coexist with an incorrect gradient.

There’s a way to check the first entry without trusting the backward pass at all. Nudge the middle unit’s first weight from $-1$ to $-0.999$. Its input goes up by $0.001$, its output by $0.0001$. The loss changes from $2.05^2/2$ to $2.0499^2/2$. Divide that change by the weight nudge and you get about $-0.205$, matching the gradient entry to the precision of this finite-difference check.

That column is what I’d ask to see in review. I’d also apply the new activation when measuring the prediction after the weight update. Naming `h`, `slope`, and `dz` costs a few lines and gives a reviewer somewhere to stop before the weights move. The full training example shows the original ReLU and the update together. [Run the training step](ALGORITHMS.md#train-a-two-layer-network-for-one-step).

## How short should an FFT be?

For someone processing audio, `np.fft.fft(samples)` may say everything necessary. For someone implementing the fast Fourier transform, even a beautifully typeset Fourier sum can leave out the most interesting thing. Evaluating the sum separately at each of $N$ frequencies takes order $N^2$ operations. What work can the frequencies share?

Take a power-of-two length $N$. Compute the half-length transforms $E$ and $O$ of the even- and odd-indexed samples. With $W_N=e^{-2\pi i/N}$, two outputs share one product.

$$
t_k=W_N^k O_k,\qquad X_k=E_k+t_k,\qquad X_{k+N/2}=E_k-t_k.
$$

Those three expressions give the *butterfly*, the step that combines two smaller transforms. Halving the problem gives $\log_2 N$ levels, with order $N$ work per level. Here I’d spend an extra name on $t_k$ even on a very narrow blackboard. It lets a student point at the multiplication we get to use twice.

Try changing this transform into its inverse. Take a four-sample pulse one position after the origin, `[0, 1, 0, 0]`. Its even samples transform to `[0, 0]`, its odd samples to `[1, 1]`. The two forward multipliers are $1$ and $-i$. The butterfly gives $[1,-i,-1,i]$. To recover the pulse, use the positive sign in the exponent at each level and divide the completed transform by four. Keep the forward sign by mistake and dividing by four gives `[0, 0, 0, 1]`. A pulse at the origin would come back to the right place under either sign.

I’d keep the library call in the audio program, the butterfly in a lesson, and the shifted pulse beside an implementation of the inverse. Each gives its reader a different thing to check. Mojj currently supports real numeric and Boolean arrays. Expressing the example as paired real and imaginary arrays would bury the sign change under bookkeeping, so I’d keep the complex arithmetic on the page. [Mojj’s supported array types](COMPATIBILITY.md).

## When a picture says more than a formula

A watershed grows regions in an image from labeled seeds, as if water were rising from separate basins. Imagine a flat strip of five pixels with a seed at each end. Suppose each front advances one pixel per step. After the first step only the middle pixel is unsettled. A request to “label the basins” still admits both of these results.

| Choice on this plateau | Left to right |
| --- | --- |
| Seeds before flooding | `A . . . B` |
| Give equal-distance ties to label A | `A A A B B` |
| Leave a ridge at a meeting of the fronts | `A A │ B B` |

Now give the algorithm a two-by-two mask with only the upper-left and lower-right pixels open and put seed A in the upper left. With four-neighbor connectivity the lower-right pixel stays unlabeled. Allow diagonal steps and it gets A. With one seed there can be no tie. On the strip there could be no diagonal. Each fixture settles one question.

If I asked an LLM to port this segmentation, I’d hand it the two fixtures and say which cells must receive a label. A compact call such as `watershed(image, markers)` would be fine once its behavior matched those decisions. Neither an array expression nor a longer flood loop can recover a preference I never supplied. Here the cheapest way to express the missing part of the specification was to draw five pixels.

## What I’d keep in the repository

When a model offers three equivalent versions, I’d give them all the same audition. Pick the change the next maintainer will actually make. Cover the output and try to predict what will move. For the filter, which tap reaches the newest sample? For the network, which column starts learning? If the answer depends on a convention outside the expression, write down one input on which the competing conventions disagree. That input earns its place alongside the code.

I’d use words for the colleague seeing `table` for the first time. I’d happily use the J spelling in a room where everyone reads it. Learning a small, composable vocabulary pays off when tomorrow’s problem uses today’s words in a new combination. In a one-off script for a NumPy shop, a familiar function and a well-chosen example can buy the same ease of review at a lower cost.

Cheap code generation lets me ask for as many spellings as I please. The scarce moment is the one after they arrive, when I have to decide which program I’m willing to maintain. In the filter I can put my finger on one word and tell you, before either of us runs the edit, that 11 will become 17. That’s the kind of short I want.
