"""Read-only migration gates. These checks do not prove GSPro/hardware behavior."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CRITICAL = ('Halliseum_Control_Center.ps1', 'workers/Halliseum_Range_Nav.ps1',
            'workers/Halliseum_Minimize_Connectors.ps1', 'workers/FactorGolf_Display_Helper.ps1',
            'workers/Halliseum_Self_Update.ps1')

def digest(data):
    return hashlib.sha256(data).hexdigest()

def audit(root=ROOT):
    errors = []
    hashes = json.loads((root / 'docs/migration/09_FILE_HASHES.json').read_text())
    for old, expected in hashes.items():
        if old.startswith('source_baseline_v0.8.14/'):
            path = root / 'src' / old.split('/', 1)[1]
        elif old.startswith('rejected_v0.8.15_diff/') or old.endswith('.zip'):
            path = root / 'evidence' / old
        else:
            path = root / 'docs/migration' / old
        if not path.is_file() or digest(path.read_bytes()) != expected:
            errors.append(f'Baseline/evidence hash mismatch: {path.relative_to(root)}')
    src = root / 'src'
    try:
        version = (src / 'app_version.txt').read_text().strip()
        config = json.loads((src / 'config.default.json').read_text(encoding='utf-8-sig'))
        if version != '0.8.14' or config['Version'] != version:
            errors.append('Baseline version mismatch')
    except (ValueError, KeyError, OSError) as exc:
        errors.append(f'Configuration/version invalid: {exc}')
    blocks = 0
    for script in src.rglob('*.ps1'):
        text = script.read_text(encoding='utf-8-sig')
        for block in re.findall(r"@['\"]\r?\n(.*?)\r?\n['\"]@", text, re.S):
            if block.lstrip().startswith(('<Window', '<ResourceDictionary', '<UserControl')):
                blocks += 1
                try:
                    ET.fromstring(block)
                except ET.ParseError as exc:
                    errors.append(f'Invalid XAML XML in {script.name}: {exc}')
        for worker in re.findall(r"['\"](?:workers[\\/])?((?:Halliseum_|FactorGolf_)[A-Za-z_]+\.ps1)['\"]", text):
            # Obsolete worker strings in process-cleanup regexes are not launch dependencies.
            if worker == 'Halliseum_Coach_Controls.ps1':
                continue
            if not (src / worker).exists() and not (src / 'workers' / worker).exists():
                errors.append(f'Missing worker reference: {worker} in {script.name}')
    if blocks != 7:
        errors.append(f'Expected 7 baseline XAML XML blocks; found {blocks}')
    if (src / 'workers/Halliseum_Coach_Controls.ps1').exists():
        errors.append('Removed Coach Controls worker reintroduced')
    archives = []
    for archive in sorted((root / 'evidence').glob('*.zip')):
        with zipfile.ZipFile(archive) as z:
            bad = z.testzip()
            if bad:
                errors.append(f'Corrupt archive member: {bad}')
            archives.append({n: z.read(n) for n in z.namelist() if not n.endswith('/')})
    if len(archives) != 2:
        errors.append('Both accepted and rejected packages are required')
    else:
        accepted, rejected = archives
        changed = sorted(n for n in accepted.keys() | rejected.keys() if accepted.get(n) != rejected.get(n))
        expected = ['app_version.txt', 'config.default.json', 'workers/Halliseum_Club_Cheat_Watcher.ps1', 'workers/Halliseum_Settings.ps1']
        if changed != expected:
            errors.append(f'Unexpected rejected-package diff: {changed}')
        for path in CRITICAL:
            if accepted.get(path) != rejected.get(path):
                errors.append(f'Critical worker changed in rejected package: {path}')
        actual_files = {p.relative_to(src).as_posix() for p in src.rglob('*') if p.is_file()}
        if actual_files != set(accepted):
            errors.append('Source inventory differs from accepted package')
    return errors, blocks

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=ROOT)
    args = parser.parse_args()
    errors, blocks = audit(args.root)
    print(f'Parsed {blocks} embedded XAML XML blocks')
    for error in errors:
        print('FAIL:', error)
    print('FAIL' if errors else 'PASS: exact baseline, evidence, versions, workers, ZIPs and XAML XML')
    print('NOT RUN HERE: Windows PowerShell parser, WPF runtime, install/upgrade, GSPro, hardware, voice, cloud feed')
    raise SystemExit(bool(errors))
