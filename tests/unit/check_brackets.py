"""Check that (), [] and {} are balanced in QML / C++ files.

Comments, string literals and character literals are ignored. This is a cheap
typo catcher, not a parser. Usage: python3 -I check_brackets.py FILE [FILE...]
"""
import re
import sys

PAIRS = {")": "(", "]": "[", "}": "{"}


def strip(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
    source = re.sub(r"//[^\n]*", "", source)
    source = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', source)
    source = re.sub(r"'(?:\\.|[^'\\\n])+'", "''", source)
    return source


def check(path: str) -> bool:
    with open(path, encoding="utf-8") as handle:
        text = strip(handle.read())
    stack = []
    line = 1
    for char in text:
        if char == "\n":
            line += 1
        elif char in "([{":
            stack.append((char, line))
        elif char in PAIRS:
            if not stack or stack.pop()[0] != PAIRS[char]:
                print(f"{path}: unbalanced '{char}' near line {line}")
                return False
    if stack:
        print(f"{path}: unclosed '{stack[-1][0]}' opened at line {stack[-1][1]}")
        return False
    return True


if __name__ == "__main__":
    results = [check(p) for p in sys.argv[1:]]
    sys.exit(0 if all(results) else 1)
