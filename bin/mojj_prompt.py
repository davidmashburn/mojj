"""Live lexical highlighting for the interactive Mojj prompt."""
import re
from enum import Enum

from prompt_toolkit import PromptSession, print_formatted_text
from prompt_toolkit.formatted_text import FormattedText
from prompt_toolkit.lexers import Lexer
from prompt_toolkit.styles import Style


class Role(Enum):
    PLAIN = ""
    NOUN = "class:noun"
    VERB = "class:verb"
    MODIFIER = "class:modifier"


# Spellings from Syntax.tokenize. In particular, the word 'dot' is a
# derived verb, while the symbol '.' is a conjunction that takes two verbs.
VERB_WORDS = frozenset("""
    abs and append behead cap ceil ceiling circle complement copy cos curtail
    decrement divide dot double drop eq equal filter floor gather ge greater
    greater_equal gt halve head identity increment iota laminate le left less
    less_equal logarithm log lt match max maximum mean min minimum minus nand
    ne negate nor not or plus pow power ravel reshape residue reverse right
    root rotate shape sin sqrt square stitch sum tail take tally times transpose
    unequal
""".split())
MODIFIER_WORDS = frozenset("""
    atop bind infix insert of outfix prefix rank reflex repeat scan suffix table
""".split())
GROUP_WORDS = {"group", "end"}

VERB_SYMBOLS = """
    ] [ + - * % *: +: %: # [: = ~: < > <: >: -: -. +. *. <. >. | ^ ^.
    o. $ i. , ,. ,: { {. {: }. }: |. |:
""".split()
MODIFIER_SYMBOLS = ("/", "\\", "\\.", "@", "@:", "&", "~", '"', "^:", ".")
SYMBOLS = {symbol: Role.VERB for symbol in VERB_SYMBOLS}
SYMBOLS.update(dict.fromkeys(MODIFIER_SYMBOLS, Role.MODIFIER))
SYMBOLS["=:"] = Role.PLAIN

# Try longer symbols first. Numeric literals take precedence over the dot
# conjunction, and i. and o. take precedence over identifiers.
_SYMBOL_PATTERN = "|".join(re.escape(s) for s in sorted(SYMBOLS, key=len, reverse=True))
_TOKEN = re.compile(
    r"(?P<number>(?:_?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][_+-]?[0-9]+)?|__?):?)"
    rf"|(?P<symbol>{_SYMBOL_PATTERN})"
    r"|(?P<word>[a-zA-Z][a-zA-Z0-9_]*)|\s+|."
)
STYLE = Style.from_dict({
    "noun": "ansigreen",
    "verb": "ansicyan bold",
    "modifier": "ansimagenta underline",
})


def highlight(line):
    """Color lexical roles even while a sentence is incomplete."""
    if line.strip() == ":quit":
        return [(Role.PLAIN.value, line)]
    fragments = []
    for match in _TOKEN.finditer(line):
        token = match[0]
        role = Role.PLAIN
        if match.lastgroup == "number":
            role = Role.VERB if token.endswith(":") else Role.NOUN
        elif match.lastgroup == "symbol":
            role = SYMBOLS[token]
        elif match.lastgroup == "word":
            if token in VERB_WORDS:
                role = Role.VERB
            elif token in MODIFIER_WORDS:
                role = Role.MODIFIER
            elif token not in GROUP_WORDS:
                role = Role.NOUN
        fragments.append((role.value, token))
    return fragments


class MojjLexer(Lexer):
    def lex_document(self, document):
        lines = document.lines
        return lambda index: highlight(lines[index]) if 0 <= index < len(lines) else []


def highlighted_prompt():
    legend = FormattedText([
        (Role.VERB.value, "verbs"), ("", "   "),
        (Role.NOUN.value, "nouns"), ("", "   "),
        (Role.MODIFIER.value, "modifiers"),
    ])
    print_formatted_text(legend, style=STYLE)
    return PromptSession(lexer=MojjLexer(), style=STYLE).prompt
