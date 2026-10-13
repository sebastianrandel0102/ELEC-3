"""Compare presentation callbacks and queries with a pre-redesign git revision.

Usage: py tools/verify_ui_preservation.py [revision]
No Flutter, Firebase, network or database operations are performed.
"""
from collections import Counter
from pathlib import Path
import re
import subprocess
import sys

revision = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'
presentation = {
    'main.dart', 'design_system.dart', 'currency_settings_screen.dart',
    'currency_widgets.dart', 'currency_savings_dialog.dart',
    'decrease_savings_dialog.dart', 'password_dialog.dart',
    'password_recovery_dialog.dart', 'profile_photo_widgets.dart',
    'shared_savings_screens.dart', 'smart_suggestions.dart',
}
pattern = re.compile(
    r'//[^\n]*|/\*[\s\S]*?\*/|'
    r'r?"""[\s\S]*?"""|r?\x27\x27\x27[\s\S]*?\x27\x27\x27|'
    r'r?"(?:\\.|[^"\\])*"|r?\x27(?:\\.|[^\x27\\])*\x27|'
    r'[A-Za-z_$][\w$]*|[^\s]'
)

def tokens(text):
    return [m.group() for m in pattern.finditer(text)
            if not m.group().startswith(('//', '/*'))]

def expression(values, start):
    level = 0
    result = []
    for token in values[start:]:
        if token in (',', ')', ']', '}') and level == 0:
            break
        if token in ('(', '[', '{'):
            level += 1
        elif token in (')', ']', '}'):
            level -= 1
        result.append(token)
    return tuple(result)

callbacks = {
    'onPressed', 'onTap', 'onSelected', 'onChanged', 'validator', 'onConfirm',
    'onDestinationSelected', 'onFieldSubmitted', 'onAddTask', 'onOpenTask',
    'onCompleteTask', 'onRefresh', 'onPassword', 'onSignOut',
}

critical_methods = {
    'main.dart': {'main', '_signInWithGoogle', '_submit', '_resetPassword',
                 'currencySummary', '_goals', '_tasks', '_number', '_money',
                 '_dateKey', '_shortDate', '_dateTitle', '_deleteGoal',
                 'setPlannerTaskCompleted'},
    'currency_savings_dialog.dart': {'confirm'},
    'decrease_savings_dialog.dart': {'_confirm'},
    'password_recovery_dialog.dart': {'_send', '_startCooldown'},
    'shared_savings_screens.dart': {'_canCorrect', 'sharedDisplayMoney',
                                  'sharedTotalMoney', 'pick', 'submit', 'issue',
                                  'run', 'load'},
    'profile_photo_widgets.dart': {'_resolve', '_recover', '_actions', '_preview',
                                 '_persist', '_confirm', '_run'},
    'smart_suggestions.dart': {'_calculate', '_scheduleTick', '_complete'},
}

def methods(text, names):
    values = tokens(text)
    found = Counter()
    for i, name in enumerate(values[:-2]):
        if name not in names or values[i+1] != '(':
            continue
        depth = 1
        j = i + 2
        while j < len(values) and depth:
            depth += (values[j] == '(') - (values[j] == ')')
            j += 1
        if j < len(values) and values[j] == 'async':
            j += 1
        if values[j:j+2] == ['=', '>']:
            end = j + 2
            while end < len(values) and values[end] != ';':
                end += 1
        elif j < len(values) and values[j] == '{':
            depth = 1
            end = j + 1
            while end < len(values) and depth:
                depth += (values[end] == '{') - (values[end] == '}')
                end += 1
        else:
            continue
        found[(name, tuple(values[i:end]))] += 1
    return found

def bindings(text):
    values = tokens(text)
    return Counter((t, expression(values, i + 2))
                   for i, t in enumerate(values[:-2])
                   if t in callbacks and values[i + 1] == ':')

def gates(text):
    values = tokens(text)
    names = {'enabled', 'canPop', 'absorbing', 'barrierDismissible'}
    return Counter((t, expression(values, i + 2))
                   for i, t in enumerate(values[:-2])
                   if t in names and values[i + 1] == ':')

def queries(text):
    values = tokens(text)
    names = {'where', 'orderBy', 'limit', 'collection', 'snapshots',
             'startAfterDocument'}
    found = Counter()
    for i, name in enumerate(values[:-2]):
        if name not in names or values[i + 1] != '(':
            continue
        depth = 1
        end = i + 2
        while end < len(values) and depth:
            depth += (values[end] == '(') - (values[end] == ')')
            end += 1
        found[(name, tuple(values[i + 2:end]))] += 1
    return found

failures = []
callback_count = 0
query_count = 0
method_count = 0
gate_count = 0
unchanged = []
for file in sorted(Path('lib').glob('*.dart')):
    old = subprocess.check_output(['git', 'show', f'{revision}:{file.as_posix()}'])
    before = old.decode('utf-8')
    after = file.read_text(encoding='utf-8')
    if file.name not in presentation:
        if before.replace('\r\n', '\n') != after.replace('\r\n', '\n'):
            failures.append(f'{file}: non-presentation source changed')
        else:
            unchanged.append(file.name)
    elif file.name != 'design_system.dart':
        a, b = gates(before), gates(after)
        if a != b:
            failures.append(f'{file}: enabled/dismissal bindings differ')
        gate_count += sum(a.values())
        names = critical_methods.get(file.name, set())
        a, b = methods(before, names), methods(after, names)
        if a != b:
            failures.append(f'{file}: financial/auth/operation methods differ')
        method_count += sum(a.values())
        for label, collect in [('callbacks', bindings), ('queries', queries)]:
            a, b = collect(before), collect(after)
            if a != b:
                failures.append(f'{file}: {label} differ ({sum((a-b).values())} removed, {sum((b-a).values())} added)')
                for item in (a-b):
                    print(f'  Removed: {label} {item[0]} {" ".join(item[1])[:150]}')
            if label == 'callbacks':
                callback_count += sum(a.values())
            else:
                query_count += sum(a.values())

if failures:
    print('\n'.join(failures))
    sys.exit(1)
print(f'PASS: {callback_count} callback/validator bindings and {query_count} query expressions unchanged.')
print(f'PASS: {len(unchanged)} non-presentation Dart files unchanged.')
print(f'PASS: {method_count} financial/auth/operation methods unchanged.')
print(f'PASS: {gate_count} enabled/dismissal bindings unchanged.')
print('This is a source comparison, not a live Firebase acceptance test.')
