"""Contract checks for the comparison harness (no J or Mojo required)."""
import unittest

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

    def test_dtype_difference_does_not_hide_equal_values(self):
        left = parse_results('RESULT|x|Float64|0|0.0', False)['x']
        right = parse_results('RESULT|x|1|0|0', True)['x']
        self.assertTrue(equal_values(left, right))
        self.assertNotEqual(left['dtype'], right['dtype'])
        self.assertIs(left['dtype'], DType.FLOAT)
        self.assertIs(left['status'], Status.VALUE)

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
        self.assertIn('Float64(1)', mojo_noun({'dtype': 'Float64', 'rank': 1, 'values': [1]}))


if __name__ == '__main__':
    unittest.main()
