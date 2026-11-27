# Learn Mojj with words

Start with four readings. By the end of this walkthrough, you’ll have used the same readings to select a subset, total batches, slide a window, and build a reusable root mean square calculation.

Inside the phrase quotes, **bold** marks verbs, *italics* mark nouns, and <ins>underlining</ins> marks modifiers. You can select and copy each expression directly.

From the repository root, start the Mojo REPL. Paste each Mojo block in order and press Enter on a blank line to run it. For a complete source file, see [Run it as a program](#run-it-as-a-program).

```sh
cd src && pixi run mojo repl
```

<pre data-mojj="mojo"><code>from mojj import jj
var readings = jj([1, 2, 3, 4])
print(jj["<strong>sum</strong>"](readings).as_int())  # 10</code></pre>

`jj(data)` wraps Mojo data as a **noun**, Mojj’s name for a scalar or array. `jj["sum"]` names a calculation. The parentheses after the brackets run it, and their argument count determines whether it is a complete sentence, a monad, or a dyad.

<pre data-mojj="mojo"><code>print(jj["<em>10</em> <strong>-</strong> <em>3</em>"]().as_int())             # 7
print(jj["<strong>square</strong>"](jj(3)).as_int())        # 9
print(jj["<strong>-</strong>"](jj(10), jj(3)).as_int())     # 7</code></pre>

With zero arguments the phrase supplies its own data. With one argument the verb acts on that input (a **monad**). With two it takes a left and a right input (a **dyad**). Every call returns a noun. Keep it in that form to feed another verb, and use accessors like `.as_int()` or `.as_ints()` when you want a Mojo value to print. The explicit forms are `Noun(data)`, `Expr[phrase].value()`, `Expr[phrase].monad(y)`, and `Expr[phrase].dyad(x, y)`.

## Work with the readings

A scalar paired with a vector acts on each item. To double the readings and then keep only values above five, build a mask and pass it to `filter`.

<pre data-mojj="mojo"><code>var doubled = jj["<strong>*</strong>"](readings, jj(2))
var keep = jj["<strong>greater</strong>"](doubled, jj(5))
print(doubled.as_ints())                       # [2, 4, 6, 8]
print(jj["<strong>filter</strong>"](keep, doubled).as_ints())   # [6, 8]</code></pre>

For two-input arithmetic, `+`, `-`, and `*` mean add, subtract, and multiply. Write `divide` for division. In a Mojj phrase, `/` is a modifier. Inside a phrase, Mojj evaluates from right to left. Parenthesize a step when its grouping matters.

<pre data-mojj="mojo"><code>print(jj["<strong>divide</strong>"](readings, jj(2)).as_floats())  # [0.5, 1.0, 1.5, 2.0]
print(jj["<em>2</em> <strong>*</strong> <em>3</em> <strong>+</strong> <em>4</em>"]().as_int())                 # 14
print(jj["(<em>2</em> <strong>*</strong> <em>3</em>) <strong>+</strong> <em>4</em>"]().as_int())               # 10</code></pre>

## Split the readings into batches

Treat the first two readings as one batch and the last two as another. Give `reshape` the dimensions on the left and the data on the right. Row indices start at zero.

<pre data-mojj="mojo"><code>var batches = jj["<strong>reshape</strong>"](jj([2, 2]), readings)
print(jj["<strong>shape</strong>"](batches).as_ints())           # [2, 2]
print(jj["<strong>gather</strong>"](jj(0), batches).as_ints())  # [1, 2]
print(jj["<strong>gather</strong>"](jj(1), batches).as_ints())  # [3, 4]</code></pre>

Which total do you want? Plain `sum` adds the two rows together, giving one total for each position in a batch. To total each batch separately, write `sum rank 1`. The `1` tells Mojj to give `sum` one vector at a time. In a matrix, each row is such a vector.

<pre data-mojj="mojo"><code>print(jj["<strong>sum</strong>"](batches).as_ints())         # [4, 6]
print(jj["<strong>sum</strong> <ins>rank</ins> <em>1</em>"](batches).as_ints())  # [3, 7]</code></pre>

## Slide a window

Go back to the original sequence. With one argument, `sum prefix` totals successively longer prefixes. Supply a window length on the left and the same phrase totals each window instead.

<pre data-mojj="mojo"><code>print(jj["<strong>sum</strong> <ins>prefix</ins>"](readings).as_ints())          # [1, 3, 6, 10]
print(jj["<strong>sum</strong> <ins>prefix</ins>"](jj(2), readings).as_ints())   # [3, 5, 7]
print(jj["<strong>sum</strong> <ins>prefix</ins>"](jj(-2), readings).as_ints())  # [3, 7]</code></pre>

A positive width slides one item at a time, so the middle window contains 2 and 3. A negative width takes disjoint blocks, retaining a shorter final block if needed. Here both blocks have two items, so their totals agree with the batch totals above.

What if you want to **exclude** each pair and find the lowest reading left? `min insert` takes the minimum of a group. Adding `suffix` and supplying a width makes that group everything outside each window.

<pre data-mojj="mojo"><code>print(jj["<strong>min</strong> <ins>insert</ins> <ins>suffix</ins>"](jj(2), readings).as_ints())  # [3, 1, 1]</code></pre>

For the first window, removing 1 and 2 leaves 3 and 4, whose minimum is 3. Slide once and the remaining readings are 1 and 4. The final window leaves 1 and 2.

## Build a statistic

The root mean square (RMS) of the readings is the square root of their mean square. Write that definition almost as you would say it. The word `of` composes verbs, so the rightmost step runs first.

<pre data-mojj="mojo"><code>print(jj["<strong>square</strong>"](readings).as_ints())                 # [1, 4, 9, 16]
print(jj["<strong>mean</strong> <ins>of</ins> <strong>square</strong>"](readings).as_float())        # 7.5
print(jj["<strong>sqrt</strong> <ins>of</ins> <strong>mean</strong> <ins>of</ins> <strong>square</strong>"](readings).as_float())  # about 2.738613</code></pre>

## Run it as a program

To reuse the phrase, give it a compile-time name with `Expr`. Its `.monad()` method applies it to one noun. Save this as `readings.mojo` in the repository root, then run `pixi run mojo run -I src readings.mojo` from that directory.

<pre data-mojj="mojo"><code>from mojj import Expr, jj

def main() raises:
    comptime RMS = Expr["<strong>sqrt</strong> <ins>of</ins> <strong>mean</strong> <ins>of</ins> <strong>square</strong>"]
    var readings = jj([1, 2, 3, 4])
    print(RMS.monad(readings).as_float())        # about 2.738613
    print(RMS.monad(jj([3, 4])).as_float())      # about 3.535534</code></pre>

Explore more operations in the [syntax guide](SYNTAX.md), or find equivalent recipes in the [side-by-side showcase](SHOWCASE.md).
