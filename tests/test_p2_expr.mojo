"""P2 vocabulary through the public expression facade."""

from std.collections import List
from std.math import abs
from std.testing import assert_equal, assert_raises, assert_true

from mojj import Expr, Noun


def aliases[words: StringLiteral, symbols: StringLiteral]() raises:
    assert_equal(Expr[words].describe(), Expr[symbols].describe())


def close(actual: Float64, expected: Float64) raises:
    assert_true(abs(actual - expected) < 1e-12)


def test_numeric_vocabulary() raises:
    aliases["halve", "-:"]()
    aliases["decrement", "<:"]()
    aliases["increment", ">:"]()
    aliases["minimum", "<."]()
    aliases["maximum", ">."]()
    aliases["abs", "|"]()
    aliases["power", "^"]()
    aliases["log", "^."]()
    aliases["root", "%:"]()
    aliases["circle", "o."]()
    aliases["sin", "1&o."]()
    aliases["cos", "2&o."]()

    assert_equal(Expr["-:8"].value().as_float(), 4.0)
    assert_equal(Expr["decrement 4"].value().as_int(), 3)
    assert_equal(Expr["increment 4"].value().as_int(), 5)
    assert_equal(Expr["floor _1.25"].value().as_float(), -2.0)
    assert_equal(Expr[">.1.25"].value().as_float(), 2.0)
    assert_equal(Expr["5 min 3"].value().as_int(), 3)
    assert_equal(Expr["5 max 3"].value().as_int(), 5)
    assert_equal(Expr["|_7"].value().as_int(), 7)
    assert_equal(Expr["3|_7"].value().as_int(), 2)
    assert_equal(Expr["2^3"].value().as_float(), 8.0)
    assert_equal(Expr["^0"].value().as_float(), 1.0)
    assert_equal(Expr["^.1"].value().as_float(), 0.0)
    close(Expr["2 log 8"].value().as_float(), 3.0)
    close(Expr["3%:27"].value().as_float(), 3.0)
    close(Expr["o.1"].value().as_float(), 3.141592653589793)
    close(Expr["sin 0"].value().as_float(), 0.0)
    close(Expr["2 o. 0"].value().as_float(), 1.0)
    with assert_raises():
        _ = Expr["^. _2"].value()


def test_predicates_and_insertion() raises:
    aliases["equal", "="]()
    aliases["unequal", "~:"]()
    aliases["less", "<"]()
    aliases["greater", ">"]()
    aliases["less_equal", "<:"]()
    aliases["greater_equal", ">:"]()
    aliases["match", "-:"]()
    aliases["complement", "-."]()
    aliases["or", "+."]()
    aliases["and", "*."]()
    aliases["nor", "+:"]()
    aliases["nand", "*:"]()

    assert_equal(Expr["1.0=1.00000000000001"].value().as_bool(), True)
    assert_equal(Expr["9007199254740993~:9007199254740992"].value().as_bool(), True)
    assert_equal(Expr["1<2"].value().as_bool(), True)
    assert_equal(Expr["1>2"].value().as_bool(), False)
    assert_equal(Expr["2<:2"].value().as_bool(), True)
    assert_equal(Expr["2>:2"].value().as_bool(), True)
    assert_equal(Expr["1 2 -: 1 2"].value().as_bool(), True)
    assert_equal(Expr["-.1"].value().as_bool(), False)
    assert_equal(Expr["0+.1"].value().as_bool(), True)
    assert_equal(Expr["0*.1"].value().as_bool(), False)
    assert_equal(Expr["0+:0"].value().as_bool(), True)
    assert_equal(Expr["1*:1"].value().as_bool(), False)
    assert_equal(Expr["<./ 3 1 8"].value().as_int(), 1)
    assert_equal(Expr[">./ 3 1 8"].value().as_int(), 8)
    assert_equal(Expr["*./ 1 0 1"].value().as_bool(), False)
    assert_equal(Expr["+./ 0 0 1"].value().as_bool(), True)
    assert_equal(Expr["*./"].monad(Noun(List[Bool]())).as_bool(), True)
    assert_equal(Expr["+./"].monad(Noun(List[Bool]())).as_bool(), False)


def test_modifier_structure() raises:
    aliases["minus bind square", "-&*:"]()
    aliases["minus reflex", "-~"]()
    assert_equal(Expr["-&*:"].apply(3.0), -9.0)
    assert_equal(Expr["4 -&*: 3"].value().as_int(), 7)
    assert_equal(Expr["-~ 3"].value().as_int(), 0)
    assert_equal(Expr["3-~10"].value().as_int(), 7)
    assert_equal(Expr["3%~12"].value().as_float(), 4.0)
    assert_equal(Expr["3 (-&*:)~ 4"].value().as_int(), 7)
    assert_equal(Expr["(10&-)~"].describe(), Expr["group 10 bind minus end reflex"].describe())
    assert_true(Expr["-&*:"].describe() != Expr["-@:*:"].describe())


def main() raises:
    test_numeric_vocabulary()
    test_predicates_and_insertion()
    test_modifier_structure()
    print("PASS test_p2_expr")
