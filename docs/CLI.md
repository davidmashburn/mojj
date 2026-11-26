# The Mojj command line

From the repository root, run `pixi run mojj`. Type a Mojj sentence and press Enter. A sentence that produces a value prints it. An assignment saves the value for later commands in the same session.

<pre data-mojj="text"><code>mojj&gt; <em>readings</em> =: <em>1</em> <em>2</em> <em>3</em> <em>4</em>
mojj&gt; <em>doubled</em> =: <em>2</em> <strong>*</strong> <em>readings</em>
mojj&gt; <strong>sum</strong> <em>doubled</em>
20
mojj&gt; <em>readings</em> =: <em>readings</em> <strong>+</strong> <em>10</em>
mojj&gt; <em>readings</em>
[11, 12, 13, 14]
mojj&gt; <em>doubled</em>
[2, 4, 6, 8]</code></pre>

Assignment evaluates the right side once. Updating `readings` leaves the earlier value of `doubled` available. A failed assignment preserves the previous binding. Use `=:` for assignment and `=` for equality.

## Read the colors

The interactive prompt highlights each token as you type. Try `totals =: sum rank 1 readings` after assigning `readings`.

| Appearance | Role | In this sentence |
| --- | --- | --- |
| Bold cyan | Verb (an operation) | <code data-mojj><strong>sum</strong></code> adds the items |
| Green | Noun (data or a name for data) | <code data-mojj><em>readings</em></code> supplies the array, <code data-mojj><em>1</em></code> the rank, and <code data-mojj><em>totals</em></code> names the result |
| Underlined magenta | Modifier (changes how an operation applies) | <code data-mojj><ins>rank</ins></code> applies <code data-mojj><strong>sum</strong></code> to rank-1 cells |

The same colors apply to symbols. In `+/ readings`, `+` is a verb and `/` modifies it to add across the items. Names take the noun color even while you’re typing a new name. Pressing Enter evaluates the sentence and reports any undefined names.

Set `NO_COLOR=1` for plain input. Scripts, redirected output, and terminals with `TERM=dumb` also use plain text. The colors belong to the Mojj prompt started by `pixi run mojj`; the underlying Mojo REPL has its own display.

## Continue a sentence on the next line

An open parenthesis gives you a continuation prompt. Close the group and press Enter to evaluate the whole sentence. The same rule works with piped input.

<pre data-mojj="text"><code>mojj&gt; <em>batches</em> =: (<em>2</em> <em>2</em> <strong>reshape</strong>
... <em>doubled</em>)
mojj&gt; <em>batches</em>
shape [2, 2] [2, 4, 6, 8]
mojj&gt; <strong>sum</strong> <ins>rank</ins> <em>1</em> <em>batches</em>
[6, 14]</code></pre>

Higher-rank arrays display their shape followed by the elements in row-major order. Enter `:quit` to leave the session. For a script, put the same commands in a text file without the prompts and run `pixi run mojj < readings.mojj`. Errors go to standard error. A script continues after a failed sentence and exits with a nonzero status if any sentence failed.

## What runs under the hood?

The `mojj` launcher starts one `pixi run mojo repl` process with Mojj on its import path. For each command the launcher sends a Mojo cell containing the quoted phrase. Mojo compiles the phrase with Mojj’s parser and runs the same verbs used by `jj`. The running Mojo process owns the session’s noun values. Starting a new session starts with an empty set of names.

Here is the batch example directly in the **Mojo REPL**. Start it with `cd src && pixi run mojo repl` from the repository root. Submit the block with a blank line.

<pre data-mojj="mojo"><code>from mojj import jj
var doubled = jj([2, 4, 6, 8])
var batches = jj["<strong>reshape</strong>"](jj([2, 2]), doubled)
print(jj["<strong>sum</strong> <ins>rank</ins> <em>1</em>"](batches).as_ints())  # [6, 14]</code></pre>

Use the Mojj prompt for array calculations. Use the Mojo prompt for Mojo imports, types, functions, or mixing Mojj with other libraries. At the Mojj prompt, names inside a sentence refer to saved nouns. In ordinary Mojo code, supply runtime data through the parentheses after `jj["phrase"]`.

Mojo also accepts a triple-quoted string for a single Mojj phrase. Line breaks separate tokens just like spaces. The following complete sentence gives the same row totals.

<pre data-mojj="mojo"><code>print(jj["""<strong>sum</strong> <ins>rank</ins> <em>1</em> (
    <em>2</em> <em>2</em> <strong>reshape</strong>
    <em>2</em> <em>4</em> <em>6</em> <em>8</em>
)"""]().as_ints())  # [6, 14]</code></pre>

Session names start with an ASCII letter and can contain letters, digits, and underscores. Mojj vocabulary words are reserved. Assignment stores scalars and arrays. Write verbs directly in each sentence and use literals for operands that form a derived verb, such as the rank in `sum rank 1`. To give a verb a reusable name in Mojo, use a compile-time `Expr` as shown in the [words walkthrough](WORDS.md#run-it-as-a-program). Each input phrase has the library’s usual [syntax limits](SYNTAX.md).
