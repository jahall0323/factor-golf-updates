import importlib.util,io,json,tempfile,unittest,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('builder',ROOT/'tools/build_candidate.py');builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
class CandidatePackageTests(unittest.TestCase):
 def test_determinism_integrity_and_provenance(self):
  with tempfile.TemporaryDirectory() as t:
   p=builder.build('a'*40,Path(t));first=p.read_bytes();self.assertEqual(first,builder.build('a'*40,Path(t)).read_bytes())
   with zipfile.ZipFile(io.BytesIO(first)) as outer:
    self.assertIsNone(outer.testzip());m=json.loads(outer.read('candidate-manifest.json'));payload=outer.read('candidate-payload.zip')
    self.assertEqual(builder.sha(payload),m['payload_sha256']);self.assertEqual(builder.sha(outer.read('Bootstrap_Update.ps1')),m['updater_sha256'])
    with zipfile.ZipFile(io.BytesIO(payload)) as z:
     self.assertEqual(set(z.namelist()),set(m['files']));self.assertIsNone(z.testzip())
     for name in z.namelist():self.assertEqual(builder.sha(z.read(name)),m['files'][name])
     build=json.loads(z.read('candidate_build.json'));self.assertEqual(build['source_commit'],'a'*40)
     self.assertEqual(build['app_version'],'0.8.14');self.assertNotIn('config.json',z.namelist())
     self.assertFalse(any(n.startswith('secrets/') for n in z.namelist()))
 def test_full_commit_required(self):
  with self.assertRaises(ValueError):builder.build('main',Path('unused'))
