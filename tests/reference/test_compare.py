"""Contract checks for the comparison harness (no J or Mojo required)."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from compare import conformance
from compare import benchmark_match, DType, Status, equal_values, expectation_met, j_noun, mojo_noun, parse_results


class ComparisonTests(unittest.TestCase):
    def test_exact_integer_is_not_rounded_through_float(self):
        left = parse_results('RESULT|large|Int|0|9007199254740993', False)['large']
        right = parse_results('RESULT|large|4|0|9007199254740992', True)['large']
        self.assertFalse(equal_values(left, right))

    def test_mixed_integer_float_precision_is_exact(self):
        integer = parse_results('RESULT|x|Int|0|9007199254740993', False)['x']
        floating = parse_results('RESULT|x|8|0|9007199254740992.0', True)['x']
        self.assertFalse(equal_values(integer, floating))
        self.assertFalse(equal_values(floating, integer))
        integer['values'] = [9007199254740992]
        self.assertTrue(equal_values(integer, floating))

    def test_float_tolerance_is_retained(self):
        left = parse_results('RESULT|x|Float64|0|1', False)['x']
        right = parse_results('RESULT|x|8|0|1.0000000000001', True)['x']
        self.assertTrue(equal_values(left, right))

    def test_benchmark_rejects_different_dtype(self):
        left = parse_results('RESULT|x|Float64|0|0.0', False)['x']
        right = parse_results('RESULT|x|1|0|0', True)['x']
        self.assertTrue(equal_values(left, right))
        self.assertFalse(benchmark_match(left, right))

    def test_rank_and_length_are_part_of_comparison(self):
        scalar = parse_results('RESULT|x|Int|0|7', False)['x']
        vector = parse_results('RESULT|x|4|1|7', True)['x']
        self.assertFalse(equal_values(scalar, vector))
        self.assertFalse(equal_values(vector, {**vector, 'values': [7, 8]}))

    def test_same_rank_and_size_can_have_different_shapes(self):
        left = parse_results('RESULT|x|Int|2|2 3|1 2 3 4 5 6', False)['x']
        right = parse_results('RESULT|x|4|2|3 2|1 2 3 4 5 6', True)['x']
        self.assertFalse(equal_values(left, right))

    def test_dtype_difference_does_not_hide_equal_values(self):
        left = parse_results('RESULT|x|Float64|0|0.0', False)['x']
        right = parse_results('RESULT|x|1|0|0', True)['x']
        self.assertTrue(equal_values(left, right))
        self.assertNotEqual(left['dtype'], right['dtype'])
        self.assertIs(left['dtype'], DType.FLOAT)
        self.assertIs(left['status'], Status.VALUE)
        case = {"expected": "match", "j_status": "value", "mojj_status": "value"}
        self.assertTrue(expectation_met(case, right, left))
        case["require_dtype_match"] = True
        self.assertFalse(expectation_met(case, right, left))
        integer = parse_results('RESULT|x|4|0|1', True)['x']
        self.assertTrue(expectation_met(case, integer, integer))

    def test_expected_domain_boundary(self):
        left = parse_results('ERROR|root', False)['root']
        right = parse_results('RESULT|root|16|0|0j1', True)['root']
        self.assertFalse(equal_values(left, right))

    def test_shared_unexpected_errors_cannot_pass(self):
        case = {"expected": "match", "j_status": "value", "mojj_status": "value"}
        error = {"status": Status.ERROR}
        self.assertFalse(expectation_met(case, error, error))
        case.update(j_status="error", mojj_status="error")
        self.assertTrue(expectation_met(case, error, error))

    def test_reversed_domain_failure_cannot_pass(self):
        case = {"expected": "different", "j_status": "value", "mojj_status": "error"}
        value = {"status": Status.VALUE, "dtype": DType.COMPLEX, "rank": 0, "values": ["0j1"]}
        error = {"status": Status.ERROR}
        self.assertTrue(expectation_met(case, value, error))
        self.assertFalse(expectation_met(case, error, value))

    def test_j_negative_exponent(self):
        result = parse_results('RESULT|x|8|1|_3.5e_1 2.5', True)['x']
        self.assertEqual(result['values'], [-0.35, 2.5])

    def test_empty_and_float_inputs(self):
        self.assertEqual(mojo_noun({'dtype': 'Float64', 'rank': 1, 'values': []}),
                         'Noun(List[Float64]())')
        self.assertEqual(j_noun({'dtype': 'Float64', 'rank': 1, 'values': []}), '(0$0.0)')
        self.assertIn('Float64(1.0)', mojo_noun({'dtype': 'Float64', 'rank': 1, 'values': [1]}))
        self.assertEqual(j_noun({'dtype': 'Float64', 'rank': 1, 'values': [1.0e20, -1.0e-20]}),
                         '(,1e20 _1e_20)')

    def test_shaped_noun_uses_row_major_atoms(self):
        noun = {"dtype": "Int", "rank": 2, "shape": [2, 1], "values": [2, -3]}
        self.assertEqual(mojo_noun(noun), 'Noun(List[Int]([Int(2), Int(-3)])).with_shape([2, 1])')
        self.assertEqual(j_noun(noun), '(2 1$2 _3)')

    def test_shaped_noun_keeps_all_axes_when_empty(self):
        noun = {"dtype": "Float64", "rank": 3, "shape": [2, 0, 3], "values": []}
        self.assertEqual(mojo_noun(noun), 'Noun(List[Float64]()).with_shape([2, 0, 3])')
        self.assertEqual(j_noun(noun), '(2 0 3$0.0)')

    def test_dtype_is_explicit_for_boolean_looking_inputs(self):
        literals = (
            ([], [1], '(1)', '(0+(1))', '(1.0)'),
            ([2], [0, 1], '(,0 1)', '(0+(,0 1))', '(,0.0 1.0)'),
            ([2, 2], [0, 1, 1, 0], '(2 2$0 1 1 0)', '(0+(2 2$0 1 1 0))', '(2 2$0.0 1.0 1.0 0.0)'),
            ([0], [], '(0$0)', '(0+(0$0))', '(0$0.0)'),
            ([2, 0], [], '(2 0$0)', '(0+(2 0$0))', '(2 0$0.0)'),
        )
        for shape, values, *expressions in literals:
            for dtype, expression in zip((DType.BOOL, DType.INT, DType.FLOAT), expressions, strict=True):
                with self.subTest(dtype=dtype, shape=shape):
                    noun = {"dtype": dtype, "rank": len(shape), "shape": shape, "values": values}
                    self.assertEqual(j_noun(noun), expression)

    def test_invalid_values_for_declared_dtype_are_rejected(self):
        for dtype, value in ((DType.INT, 1.0), (DType.INT, 1 << 63),
                             (DType.BOOL, 2), (DType.FLOAT, float("inf"))):
            for render in (mojo_noun, j_noun):
                with self.subTest(dtype=dtype, value=value, render=render.__name__):
                    with self.assertRaisesRegex(ValueError, f"{dtype} input noun values"):
                        render({"dtype": dtype, "rank": 0, "values": [value]})

    def test_invalid_noun_shapes_are_rejected_before_running_either_runtime(self):
        noun = {"dtype": "Int", "rank": 2, "shape": [2, 1], "values": [2, 3]}
        case = {"id": "shape", "expression": "]", "mode": "monad", "y": noun}
        invalid_shapes = (
            ({"rank": -2}, "rank must be a nonnegative integer"),
            ({"rank": 2.0}, "rank must be a nonnegative integer"),
            ({"shape": None}, "shape must contain 2 axes"),
            ({"shape": [2]}, "shape must contain 2 axes"),
            ({"shape": [2, -1]}, "axes must be nonnegative Int64 integers"),
            ({"shape": [2, 1.0]}, "axes must be nonnegative Int64 integers"),
            ({"shape": [2, True]}, "axes must be nonnegative Int64 integers"),
            ({"shape": [0, 1 << 63], "values": []}, "axes must be nonnegative Int64 integers"),
            ({"shape": [2, 2]}, "atom count must match the number of values"),
            ({"shape": [2, 0]}, "atom count must match the number of values"),
            ({"rank": 0, "shape": []}, "atom count must match the number of values"),
            ({"rank": 0, "shape": [2], "values": [2]}, "shape must contain 0 axes"),
            ({"rank": 1, "shape": [3]}, "atom count must match the number of values"),
            ({"rank": 1, "shape": [-2]}, "axes must be nonnegative Int64 integers"),
        )
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "cases.json"
            with patch("compare.HERE", fixture.parent), patch("compare.j_run") as j_run, patch("compare.mojo_build") as mojo_build:
                for invalid, diagnostic in invalid_shapes:
                    malformed = {**case, "id": "invalid", "y": {**noun, **invalid}}
                    with self.subTest(invalid=invalid):
                        for render in (mojo_noun, j_noun):
                            with self.assertRaisesRegex(ValueError, diagnostic):
                                render(malformed["y"])
                        fixture.write_text(json.dumps([case, malformed]))
                        with self.assertRaisesRegex(ValueError, diagnostic):
                            conformance(Path("unused"), {})
                j_run.assert_not_called()
                mojo_build.assert_not_called()


if __name__ == '__main__':
    unittest.main()
