import json
import math
import random
from pathlib import Path


def fast_progress(xp, base, step):
    def cost(count):
        return count * base + step * count * (count - 1) / 2

    completed = 0
    if step == 0:
        completed = math.floor(xp / base)
    elif xp > 0:
        linear = base - step / 2
        root = math.sqrt(linear * linear + 2 * step * xp)
        completed = math.floor(2 * xp / (root + linear) if linear >= 0 else (root - linear) / step)
        if cost(completed) > xp:
            completed = max(0, completed - 1)
        if cost(completed + 1) <= xp:
            completed += 1
    return completed + 1, int(xp - cost(completed)), base + step * completed


def oracle_progress(xp, base, step):
    def cost(count):
        return count * base + step * count * (count - 1) // 2

    low, high = 0, xp + 1
    while low + 1 < high:
        candidate = (low + high) // 2
        if cost(candidate) <= xp:
            low = candidate
        else:
            high = candidate
    return low + 1, xp - cost(low), base + step * low


def main():
    random_source = random.Random(20261003)
    cases = []
    for base in (1, 2, 100, 999999, 1000000000):
        for step in (0, 1, 50, 999999, 1000000000):
            for xp in (0, 1, 99, 100, 249, 250, 999999999, 1000000000):
                cases.append((xp, base, step))
            for completed in (1, 2, 3, 20, 1000, 40000):
                threshold = completed * base + step * completed * (completed - 1) // 2
                for xp in (threshold - 1, threshold, threshold + 1):
                    if 0 <= xp <= 1000000000:
                        cases.append((xp, base, step))
    for _ in range(10000):
        cases.append((random_source.randrange(1000000001), random_source.choice((1, 100, random_source.randrange(1, 1000000001))), random_source.choice((0, 1, 50, random_source.randrange(1000000001)))))
    for xp, base, step in cases:
        actual = fast_progress(xp, base, step)
        expected = oracle_progress(xp, base, step)
        assert actual == expected, ((xp, base, step), actual, expected)
        assert 0 <= actual[1] < actual[2]
    result = {"passed": len(cases), "oracle": "Exact integer binary search", "algorithm": "Bounded quadratic inversion matching Luau source", "maxXP": 1000000000, "externalWrites": 0, "actualLuauRuntimeStillRequiresStudioFixtures": True}
    (Path(__file__).parent / "level-curve-checks.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
