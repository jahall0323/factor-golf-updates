"""Deterministic test-candidate packaging. Never updates a feed or release."""
import argparse,hashlib,io,json,re,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ID='0.8.14-halliseum-candidate.1'
def sha(data):return hashlib.sha256(data).hexdigest()
def encoded(value):return (json.dumps(value,indent=2,sort_keys=True)+'\n').encode()
def archive(files):
    output=io.BytesIO()
    with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data in sorted(files.items()):
            item=zipfile.ZipInfo(name,(2026,10,5,0,0,0));item.compress_type=zipfile.ZIP_DEFLATED;item.external_attr=0o100644<<16
            z.writestr(item,data)
    result=output.getvalue()
    with zipfile.ZipFile(io.BytesIO(result)) as z:
        if z.testzip():raise ValueError('ZIP integrity failed')
    return result
def build(source_commit,destination):
    if not re.fullmatch('[0-9a-f]{40}',source_commit):raise ValueError('Full source commit required')
    src=ROOT/'src';files={p.relative_to(src).as_posix():p.read_bytes() for p in src.rglob('*') if p.is_file()}
    if any(n=='config.json' or n.startswith(('secrets/','diagnostics/')) for n in files):raise ValueError('Private state in source payload')
    version=files['app_version.txt'].decode().strip()
    if version!='0.8.14' or json.loads(files['config.default.json'].decode('utf-8-sig'))['Version']!=version:raise ValueError('Base version mismatch')
    source_files={n:sha(b) for n,b in files.items()}
    provenance=json.loads((ROOT/'docs/INTEGRATION_INPUTS.json').read_text())
    files['candidate_build.json']=encoded(dict(candidate_id=ID,source_commit=source_commit,app_version=version,inputs=provenance,source_files=source_files))
    payload=archive(files);updater=files['workers/Halliseum_Self_Update.ps1']
    manifest=dict(channel='halliseum-candidate',candidate_id=ID,app_version=version,source_commit=source_commit,payload_sha256=sha(payload),updater_sha256=sha(updater),files={n:sha(b) for n,b in files.items()})
    bundle={p.name:p.read_bytes() for p in (ROOT/'packaging').iterdir() if p.is_file()}
    bundle.update({'candidate-payload.zip':payload,'Bootstrap_Update.ps1':updater,'candidate-manifest.json':encoded(manifest)})
    destination.mkdir(parents=True,exist_ok=True)
    path=destination/'Factor_Golf_Halliseum_Candidate_1.zip';data=archive(bundle);path.write_bytes(data)
    (destination/'SHA256SUMS.txt').write_text(sha(data)+'  '+path.name+'\n')
    return path
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source-commit',required=True);p.add_argument('--out',type=Path,default=ROOT/'dist');a=p.parse_args();print(build(a.source_commit,a.out))
