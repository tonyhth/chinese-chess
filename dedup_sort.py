def dedup_sort(numbers: list[int] | list[float]) -> list:
    """去重并升序排序。结果与原始顺序无关。"""
    return sorted(set(numbers))


if __name__ == "__main__":
    # 基本测试
    assert dedup_sort([3, 1, 2, 3, 1]) == [1, 2, 3]
    assert dedup_sort([5, 5, 5]) == [5]
    assert dedup_sort([]) == []
    assert dedup_sort([-1, 3, 0, -1]) == [-1, 0, 3]
    # 浮点数
    assert dedup_sort([1.5, 2.0, 1.5]) == [1.5, 2.0]
    assert dedup_sort([3, 2.5, 3, 1]) == [1, 2.5, 3]
    print("All tests passed.")
