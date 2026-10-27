"""Audit the UI revision against a git baseline; no account or network access.

Checks every tracked Dart domain file, all query calls, validators, and selected
financial/auth/permission methods. UI callbacks may move between components.
This is source preservation evidence, not live Firebase acceptance testing.
Usage: py tools/verify_mint_atelier.py [baseline revision]
"""
from collections import Counter
from pathlib import Path
import re
import subprocess
import sys

revision = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
presentation = set('''lib/design_system.dart lib/precision_components.dart
lib/main.dart lib/home_atelier.dart lib/goal_cover_widgets.dart
lib/shared_savings_screens.dart lib/currency_savings_dialog.dart
lib/reminder_widgets.dart lib/ai_coach/ai_coach_screen.dart
lib/ai_coach/ai_conversation_widgets.dart lib/ai_coach/ai_theme.dart
lib/ai_coach/ai_widgets.dart lib/agent_studio/agent_step_editor.dart
lib/agent_studio/presentation/agent_widgets.dart
lib/home_widgets/widget_visuals.dart'''.split())
critical = {
    'lib/main.dart': {'main', '_submit', '_signInWithGoogle', '_resetPassword',
                     'currencySummary', '_goals', '_tasks', '_number', '_money',
                     '_dateKey', '_shortDate', '_dateTitle', '_deleteGoal',
                     'setPlannerTaskCompleted'},
    'lib/currency_savings_dialog.dart': {'confirm'},
    'lib/shared_savings_screens.dart': {'_canCorrect', 'sharedDisplayMoney',
                                      'sharedTotalMoney', 'submit', 'issue',
                                      'run', 'load'},
    'lib/goal_cover_widgets.dart': {'_resolve', '_invalidated', '_persist',
                                   '_run', '_confirm'},
}
pattern = re.compile(
    r'//[^\n]*|/\*[\s\S]*?\*/|'
    r'r?"""[\s\S]*?"""|r?\x27\x27\x27[\s\S]*?\x27\x27\x27|'
    r'r?"(?:\\.|[^"\\])*"|r?\x27(?:\\.|[^\x27\\])*\x27|'
    r'[A-Za-z_$][\w$]*|[^\s]'
)


def tokens(source):
    return [m.group() for m in pattern.finditer(source)
            if not m.group().startswith(('//', '/*'))]


def balanced(values, start, opening, closing):
    depth = 1
    end = start + 1
    while end < len(values) and depth:
        depth += (values[end] == opening) - (values[end] == closing)
        end += 1
    return end


def calls(values, names):
    result = Counter()
    for index, value in enumerate(values[:-1]):
        if value in names and values[index + 1] == '(':
            end = balanced(values, index + 1, '(', ')')
            result[(value, tuple(values[index + 2:end]))] += 1
    return result


def methods(values, names):
    result = Counter()
    for index, value in enumerate(values[:-1]):
        if value not in names or values[index + 1] != '(':
            continue
        end = balanced(values, index + 1, '(', ')')
        if end < len(values) and values[end] == 'async':
            end += 1
        if values[end:end + 2] == ['=', '>']:
            end += 2
            while end < len(values) and values[end] != ';':
                end += 1
        elif end < len(values) and values[end] == '{':
            end = balanced(values, end, '{', '}')
        else:
            continue
        result[(value, tuple(values[index:end]))] += 1
    return result


files = subprocess.check_output(
    ['git', 'ls-tree', '-r', '--name-only', revision, 'lib'], text=True
).splitlines()
failures = []
counts = Counter()
for name in files:
    if not name.endswith('.dart'):
        continue
    before = subprocess.check_output(['git', 'show', f'{revision}:{name}']).decode('utf-8')
    after = Path(name).read_text(encoding='utf-8')
    if name not in presentation:
        if before.replace('\r\n', '\n') != after.replace('\r\n', '\n'):
            failures.append(f'{name}: domain source changed')
        counts['domain files'] += 1
    a, b = tokens(before), tokens(after)
    for label, collect in [
        ('query calls', lambda v: calls(v, {'where', 'orderBy', 'limit'})),
        ('critical methods', lambda v: methods(v, critical.get(name, set()))),
    ]:
        original, current = collect(a), collect(b)
        if original != current:
            failures.append(f'{name}: {label} differ')
        counts[label] += sum(original.values())
    # Validators include closures; collect their expression until its balanced
    # argument boundary. Wrapping a field does not change validation behavior.
    def validators(values):
        result = Counter()
        for i in range(len(values) - 2):
            if values[i:i + 2] != ['validator', ':']:
                continue
            depth = 0
            end = i + 2
            while end < len(values):
                t = values[end]
                if depth == 0 and t in {',', ')', ']', '}'}:
                    break
                depth += t in {'(', '[', '{'}
                depth -= t in {')', ']', '}'}
                end += 1
            result[tuple(values[i + 2:end])] += 1
        return result
    if validators(a) != validators(b):
        failures.append(f'{name}: validators differ')
    counts['validators'] += sum(validators(a).values())

if failures:
    print('\n'.join(failures))
    sys.exit(1)
for label, count in counts.items():
    print(f'PASS: {count} {label} unchanged against {revision}.')
print('UI picker adapters, sorting controls and startup retry are reviewed separately.')
