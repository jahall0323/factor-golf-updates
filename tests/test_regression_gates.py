import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('gates', ROOT / 'tools/check_regressions.py')
gates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gates)

class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / 'repo'
        shutil.copytree(ROOT, self.root)
    def tearDown(self):
        self.temp.cleanup()
    def errors(self):
        return gates.audit(self.root)[0]
    def test_accepted_baseline_passes(self):
        self.assertEqual(self.errors(), [])
    def test_navigation_tampering_is_rejected(self):
        path = self.root / 'src/workers/Halliseum_Range_Nav.ps1'
        path.write_bytes(path.read_bytes() + b'\n# unreviewed change\n')
        self.assertTrue(any('Range_Nav' in e for e in self.errors()))
    def test_missing_worker_is_rejected(self):
        (self.root / 'src/workers/Halliseum_Club_Cheat_Watcher.ps1').unlink()
        self.assertTrue(any('Club_Cheat_Watcher' in e for e in self.errors()))
    def test_version_drift_is_rejected(self):
        (self.root / 'src/app_version.txt').write_text('0.8.15')
        self.assertIn('Baseline version mismatch', self.errors())
    def test_removed_worker_is_rejected(self):
        (self.root / 'src/workers/Halliseum_Coach_Controls.ps1').write_text('')
        self.assertIn('Removed Coach Controls worker reintroduced', self.errors())
    def test_invalid_xaml_is_rejected(self):
        path = self.root / 'src/workers/Halliseum_Settings.ps1'
        path.write_text(path.read_text(encoding='utf-8-sig').replace('</Window>', '</BrokenWindow>'))
        self.assertTrue(any('Invalid XAML' in e for e in self.errors()))

if __name__ == '__main__':
    unittest.main()
