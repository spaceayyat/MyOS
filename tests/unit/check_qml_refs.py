#!/usr/bin/env python3
"""Static cross-reference check for the My OS QML (no Qt needed).

Verifies that names used in QML exist where they are defined:
  Sys.<x>   -> Q_PROPERTY / Q_INVOKABLE in shared/system-api/systemapi.h
  Shell.<x> -> Q_PROPERTY / Q_INVOKABLE in desktop/shell/shellstate.h
  th.<x>    -> property / function in shared/theme/Theme.qml
  every QML file under desktop/ and shared/ is listed in a CMake resource list
Prints one line per problem; exit status 1 if any.
"""
import re, sys, pathlib

root = pathlib.Path(__file__).resolve().parents[2]
read = lambda p: (root / p).read_text()

def header_names(text):
    names = set(re.findall(r'Q_PROPERTY\([^)]*?\b(\w+)\s+READ', text))
    names |= set(re.findall(r'Q_INVOKABLE\s+[\w:<>]+\s+(\w+)\s*\(', text))
    return names

sys_names = header_names(read('shared/system-api/systemapi.h'))
shell_names = header_names(read('desktop/shell/shellstate.h'))
theme_src = read('shared/theme/Theme.qml')
theme_names = set(re.findall(r'(?:readonly\s+)?property\s+\w+\s+(\w+)', theme_src))
theme_names |= set(re.findall(r'function\s+(\w+)\s*\(', theme_src))

qml = sorted(p for d in ('desktop', 'shared') for p in (root / d).rglob('*.qml'))
problems = []
for p in qml:
    text = p.read_text()
    rel = p.relative_to(root)
    for m in set(re.findall(r'\bSys\.(\w+)', text)):
        # prefs is a map: Sys.prefs.<key> is checked separately below
        if m not in sys_names:
            problems.append(f'{rel}: Sys.{m} is not defined in systemapi.h')
    for m in set(re.findall(r'\bShell\.(\w+)', text)):
        if m not in shell_names:
            problems.append(f'{rel}: Shell.{m} is not defined in shellstate.h')
    for m in set(re.findall(r'\bth\.(\w+)', text)):
        if m not in theme_names:
            problems.append(f'{rel}: th.{m} is not defined in Theme.qml')
    pref_keys = set(re.findall(r'Sys\.prefs\.(\w+)', text)) | set(re.findall(r'setPref\("(\w+)"', text))
    for k in pref_keys:
        if f'{{QStringLiteral("{k}")' not in read('shared/system-api/systemapi.cpp'):
            problems.append(f'{rel}: preference "{k}" has no default in systemapi.cpp')

cmake = ''.join(p.read_text() for p in root.rglob('CMakeLists.txt'))
for p in qml:
    if p.name not in cmake:
        problems.append(f'{p.relative_to(root)}: not listed in any CMakeLists.txt')

print(f'checked {len(qml)} QML files; Sys names={len(sys_names)} Shell names={len(shell_names)} Theme names={len(theme_names)}')
for line in problems:
    print('PROBLEM', line)
sys.exit(1 if problems else 0)
