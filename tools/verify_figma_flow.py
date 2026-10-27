"""Read-only preservation and substantive source-count audit for Figma Flow.

Run with: py tools/verify_figma_flow.py [starting_revision]
"""
from pathlib import Path
import difflib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
revision = sys.argv[1] if len(sys.argv) > 1 else 'HEAD'

def git(*args):
    return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.DEVNULL)

def before(path):
    try:
        return git('show', f'{revision}:{path}').decode('utf-8').replace('\r\n', '\n')
    except subprocess.CalledProcessError:
        return ''

# Reuse the established token-level function extractor, without executing its
# earlier edition's fixed list of allowed presentation files.
namespace = {}
helper = (root / 'tools/verify_ui_preservation.py').read_text(encoding='utf-8')
exec(helper[:helper.index('failures = []')], namespace)
methods = namespace['methods']
critical = dict(namespace['critical_methods'])
critical['home_atelier.dart'] = {'_chooseSavingsGoal', '_subscribe', '_reload', '_read', 'upcomingReminders'}
critical['reminder_agenda.dart'] = {'reminderAgenda'}
failures = []
checked = 0
for filename, names in critical.items():
    path = 'lib/' + filename
    current = (root / path).read_text(encoding='utf-8')
    old = methods(before(path), names)
    new = methods(current, names)
    checked += sum(old.values())
    if old != new:
        failures.append(path + ': protected financial/auth/scheduling methods changed')

presentation = {
    'lib/design_system.dart', 'lib/figma_flow_components.dart',
    'lib/precision_components.dart', 'lib/precision_flows.dart',
    'lib/main.dart', 'lib/home_atelier.dart', 'lib/reminder_agenda.dart',
    'lib/shared_savings_screens.dart', 'lib/currency_settings_screen.dart',
    'lib/ai_coach/ai_theme.dart', 'lib/agent_studio/agent_screen.dart',
    'lib/agent_studio/presentation/agent_widgets.dart',
    'lib/home_widgets/widget_visuals.dart',
    'lib/password_dialog.dart', 'lib/password_recovery_dialog.dart',
    'lib/smart_suggestions.dart', 'lib/goal_cover_widgets.dart',
}
immutable = []
tracked = git('ls-files').decode().splitlines()
for path in tracked:
    protected = ((path.startswith('lib/') and path.endswith('.dart') and path not in presentation)
                 or path in {'firestore.rules', 'firestore.indexes.json', 'storage.rules',
                             'firebase.json', 'pubspec.yaml', 'pubspec.lock',
                             'android/app/src/main/AndroidManifest.xml'}
                 or path.startswith('functions/')
                 or (path.startswith('android/app/src/main/kotlin/') and path.endswith('.kt')))
    if protected:
        try:
            current = (root / path).read_text(encoding='utf-8').replace('\r\n', '\n')
        except (UnicodeDecodeError, IsADirectoryError):
            continue
        if before(path) != current:
            failures.append(path + ': protected service/configuration changed')
        else:
            immutable.append(path)

changed = set(git('diff', '--name-only', revision).decode().splitlines())
changed.update(git('ls-files', '--others', '--exclude-standard').decode().splitlines())
counts = {'production_dart': {'added': 0, 'removed': 0}, 'native_xml': {'added': 0, 'removed': 0}, 'test_dart': {'added': 0, 'removed': 0}}
inventory = []
def meaningful(text):
    return [line.strip() for line in text.splitlines() if line.strip() and not line.strip().startswith(('//', '///', '/*', '*', '<!--'))]
for path in sorted(changed):
    category = ('production_dart' if path.startswith('lib/') and path.endswith('.dart') else
                'test_dart' if path.startswith('test/') and path.endswith('.dart') else
                'native_xml' if path.startswith('android/') and path.endswith('.xml') else None)
    if category is None:
        continue
    old = meaningful(before(path))
    new = meaningful((root / path).read_text(encoding='utf-8'))
    added = removed = 0
    for operation, a, b, c, d in difflib.SequenceMatcher(a=old, b=new, autojunk=False).get_opcodes():
        if operation in ('replace', 'delete'):
            removed += b - a
        if operation in ('replace', 'insert'):
            added += d - c
    counts[category]['added'] += added
    counts[category]['removed'] += removed
    inventory.append({'path': path, 'added': added, 'removed': removed})
report = {'starting_revision': git('rev-parse', revision).decode().strip(),
          'protected_methods_verified': checked, 'unchanged_services_and_configuration': immutable,
          'source_counts': counts, 'files': inventory, 'failures': failures}
output = root / 'docs/figma-flow-preservation-results.json'
output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: v for k, v in report.items() if k not in {'unchanged_services_and_configuration', 'files'}}, indent=2))
print(f'{len(immutable)} service/configuration files unchanged; report: {output}')
raise SystemExit(bool(failures))
