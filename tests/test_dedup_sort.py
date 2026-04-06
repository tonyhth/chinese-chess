"""dedup_sort.py 测试套件 — Tina 编写"""

import pytest
from dedup_sort import dedup_sort


class TestBasicFunctionality:
    """核心功能"""

    def test_basic_dedup_and_sort(self):
        assert dedup_sort([3, 1, 2, 3, 1]) == [1, 2, 3]

    def test_all_duplicates(self):
        assert dedup_sort([5, 5, 5]) == [5]

    def test_already_sorted_unique(self):
        assert dedup_sort([1, 2, 3]) == [1, 2, 3]

    def test_reverse_order(self):
        assert dedup_sort([3, 2, 1]) == [1, 2, 3]

    def test_single_element(self):
        assert dedup_sort([42]) == [42]

    def test_empty_list(self):
        assert dedup_sort([]) == []


class TestFloats:
    """浮点数"""

    def test_float_only(self):
        assert dedup_sort([1.5, 2.0, 1.5]) == [1.5, 2.0]

    def test_mixed_int_float(self):
        assert dedup_sort([3, 2.5, 3, 1]) == [1, 2.5, 3]

    def test_float_zero_and_int_zero_dedup(self):
        # 0.0 == 0 in Python, set will dedup them
        assert dedup_sort([0, 0.0, 1]) == [0, 1]


class TestNegative:
    """负数"""

    def test_negative_numbers(self):
        assert dedup_sort([-1, 3, 0, -1]) == [-1, 0, 3]

    def test_all_negative(self):
        assert dedup_sort([-3, -1, -2, -3]) == [-3, -2, -1]

    def test_negative_floats(self):
        assert dedup_sort([-1.5, -2.5, -1.5]) == [-2.5, -1.5]


class TestEdgeCases:
    """边界情况"""

    def test_very_large_numbers(self):
        assert dedup_sort([10**18, 1, 10**18]) == [1, 10**18]

    def test_very_small_floats(self):
        result = dedup_sort([1e-308, -1e-308, 1e-308])
        assert result == [-1e-308, 1e-308]

    def test_large_list(self):
        nums = [1, 2, 3] * 1000
        assert dedup_sort(nums) == [1, 2, 3]


class TestInvalidInput:
    """异常输入 — Ruby P2 清单：输入验证"""

    def test_string_in_list(self):
        with pytest.raises(TypeError):
            dedup_sort([1, "a", 2])

    def test_none_in_list(self):
        with pytest.raises(TypeError):
            dedup_sort([1, None, 2])

    def test_non_list_input(self):
        with pytest.raises(TypeError):
            dedup_sort("1,2,3")

    def test_none_input(self):
        with pytest.raises(TypeError):
            dedup_sort(None)

    def test_nested_list(self):
        # list 内含 list，set() 会 TypeError
        with pytest.raises(TypeError):
            dedup_sort([[1], [2]])
