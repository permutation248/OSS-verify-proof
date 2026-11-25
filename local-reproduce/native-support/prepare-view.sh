#!/usr/bin/env bash
# Native staging only: no compilation, program execution, containers or core-source edits.
set -euo pipefail
REPO=${1:?Usage: prepare-view.sh /absolute/path/to/oss-verify-proofs}
REPO=$(cd -- "$REPO" && pwd -P)
NATIVE="$HOME/projects/oss-verify-native-env"
SCRATCH=/var/tmp/wupeihan-oss-verify-reproduce/ad0a85d4
ARCHIVE="$NATIVE/downloads/oss-verify-proofs-ad0a85d.tar.gz"
PY="$NATIVE/python-venv/bin/python"
mkdir -p "$SCRATCH/preparation-logs" "$NATIVE/logs"
exec 9>"$SCRATCH/.prepare.lock"
flock -n 9 || { echo 'Another preparation is running' >&2; exit 1; }
LOG="$SCRATCH/preparation-logs/$(TZ=Asia/Shanghai date +%Y%m%dT%H%M%S)-prepare-$$.log"
exec > >(tee -a "$LOG") 2>&1
trap 'rc=$?; printf "PREPARE_EXIT_STATUS=%s\n" "$rc"; date -Iseconds; cp "$LOG" "$NATIVE/logs/$(basename "$LOG")" || :; exit "$rc"' EXIT
date -Iseconds
printf 'ROOT=%s\nSCRATCH=%s\nARCHIVE=%s\n' "$REPO" "$SCRATCH" "$ARCHIVE"
export PYTHONDONTWRITEBYTECODE=1
export PYTHONSAFEPATH=1
if [[ ! -f "$SCRATCH/full-unpacked.json" ]]; then
  if [[ -e "$SCRATCH/full" ]]; then
    echo 'Refusing an existing full directory without the completion marker' >&2
    exit 1
  fi
  mkdir -p "$SCRATCH/full"
  printf '+ sha256sum %q\n' "$ARCHIVE"
  sha256sum "$ARCHIVE" | tee "$SCRATCH/archive.sha256"
  [[ $(cut -d ' ' -f 1 "$SCRATCH/archive.sha256") == 48c946dd504ab88a8e26e84d6103832bdd67d0d85f1cc9edfb61cc863a39631a ]] || { echo 'Archive digest differs from the independently recorded archive' >&2; exit 1; }
  printf '+ tar -xzf %q -C %q --strip-components=1\n' "$ARCHIVE" "$SCRATCH/full"
  tar -xzf "$ARCHIVE" -C "$SCRATCH/full" --strip-components=1
  "$PY" - "$SCRATCH" "$ARCHIVE" <<'PY'
import json,pathlib,sys
s=pathlib.Path(sys.argv[1]); a=pathlib.Path(sys.argv[2])
(s/'full-unpacked.json').write_text(json.dumps({'archive':str(a),'archive_sha256':(s/'archive.sha256').read_text().split()[0], 'expected_commit':'ad0a85d4c37bc1c985ef72826a02ee33b01cbbd6', 'expected_tree':'a36ade652af3a438ecfa227a79240b7480b00ed4'},indent=2)+'\n')
PY
fi
export PYTHONPATH="$SCRATCH/full/tools"
"$PY" - "$REPO" "$SCRATCH" <<'PY'
import concurrent.futures,hashlib,json,os,pathlib,shutil,stat,subprocess,sys,time
from oft import facts,fetch,generate,unitpaths,yamlio
repo=pathlib.Path(sys.argv[1]); scratch=pathlib.Path(sys.argv[2]); full=scratch/'full'
view=scratch/'view'; factsdir=scratch/'facts'; unit='zlib/checksum_fuzzer'
unitrel=pathlib.Path('projects/zlib/checksum_fuzzer')
binrel=pathlib.Path('projects/zlib/bin/checksum_fuzzer')
factsfile=factsdir/'zlib/checksum_fuzzer.yaml'
statefile=scratch/'prepared.json'
def log(*v): print(*v,flush=True)
def digest(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()
def record(base,roots):
    out={}; files=set()
    def visit(rel):
        if rel in out or rel in files:return
        p=base/rel
        if p.is_dir() and not p.is_symlink():
            out[rel]={'kind':'dir','execute':p.stat().st_mode & 0o111}
            with os.scandir(p) as entries:
                for e in sorted(entries,key=lambda e:e.name):
                    child=rel+'/'+e.name
                    if e.is_dir(follow_symlinks=False):visit(child)
                    else:files.add(child)
        else:files.add(rel)
    def one(rel):
        p=base/rel;s=p.lstat()
        if stat.S_ISLNK(s.st_mode):return rel,{'kind':'link','target':os.readlink(p)}
        if stat.S_ISREG(s.st_mode):return rel,{'kind':'file','size':s.st_size,'execute':s.st_mode & 0o111,'sha256':digest(p)}
        raise RuntimeError('Unsupported file type: '+str(p))
    for rel in sorted(set(roots)):visit(rel)
    log('HASH_START',base,len(files),'files; workers=8')
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for count,(rel,item) in enumerate(pool.map(one,sorted(files)),1):
            out[rel]=item
            if count%1000==0:log('HASH_PROGRESS',base,count,'/',len(files))
    return out
def save(p,obj):p.write_text(json.dumps(obj,ensure_ascii=False,sort_keys=True,indent=2)+'\n')
def compare(label,expected,actual):
    differences=[p for p in sorted(expected.keys()|actual.keys()) if expected.get(p)!=actual.get(p)]
    if differences:raise RuntimeError(label+' differs: '+', '.join(differences[:30])+(' ...' if len(differences)>30 else ''))
    log(label+': PASS',len(expected),'entries')
def paths(base):return unitpaths.view(str(base),unit,'build')
def reduced_dune(base):
    forms=unitpaths.forms((base/'dune-project').read_text())
    stem=facts.read_release_names(str(base))[1]
    return '\n\n'.join(unitpaths.dune_project_forms(forms,'zlib',stem)[2])+'\n'
def readonly(base):
    for dp,dn,fn in os.walk(base,topdown=False,followlinks=False):
        for name in fn:
            p=pathlib.Path(dp)/name
            if not p.is_symlink():p.chmod(p.stat().st_mode & ~0o222)
        pathlib.Path(dp).chmod(pathlib.Path(dp).stat().st_mode & ~0o222)
def official_binary_check():
    h=facts.load_unit(str(view),yamlio.load_file(str(factsfile)),unit,{'statements','proofs'})
    counts=fetch.verify_builds(str(view),h,sys.stdout)
    if counts[1]:raise RuntimeError('Official ELF hash verification failed: '+str(counts))
    log('OFFICIAL_VERIFY_BUILDS',counts)
if statefile.exists():
    state=json.loads(statefile.read_text())
    for name,key in [('source-manifest.json','source_manifest_sha256'),('view-manifest.json','view_manifest_sha256')]:
        if digest(scratch/name)!=state[key]:raise RuntimeError('Saved manifest changed: '+name)
    if paths(repo)!=state['unitpaths']:raise RuntimeError('Main source path set differs from prepared snapshot')
    compare('Main source closure',json.loads((scratch/'source-manifest.json').read_text()),record(repo,state['source_roots']))
    compare('Native view source',json.loads((scratch/'view-manifest.json').read_text()),record(view,state['view_roots']))
    if digest(factsfile)!=state['facts_sha256']:raise RuntimeError('Facts snapshot changed')
    if reduced_dune(repo)!=(view/'dune-project').read_text():raise RuntimeError('Generated dune-project differs')
    official_binary_check()
    log('Existing native preparation validated; no source or build files rewritten')
else:
    if not (full/binrel).exists():
        (full/binrel).parent.mkdir(parents=True,exist_ok=True)
        shutil.copytree(repo/binrel,full/binrel,symlinks=True)
    # CI normalizes this generated file before freezing facts/views. The published
    # tree already has it, so require equality without editing any source file.
    namespace,stem=facts.read_release_names(str(full))
    library_dune=full/unitrel/'proofs/lib/dune'
    want=generate.proof_lib_dune(namespace,stem,'zlib','checksum_fuzzer')
    if library_dune.read_text()!=want:raise RuntimeError('Published lib/dune differs from official generation')
    log('Official lib/dune rendering matches unchanged source')
    readonly(full)
    factsdir.mkdir(exist_ok=True)
    cmd=[sys.executable,'-m','oft.check','--root',str(full),'--facts-to',str(factsdir),unit]
    log('COMMAND',json.dumps(cmd))
    result=subprocess.run(cmd)
    log('FACTS_TO_EXIT_STATUS',result.returncode)
    if result.returncode:raise RuntimeError('Official whole-tree facts/rules validation failed')
    listfile=scratch/'unitpaths.txt'; generated=scratch/'generated-dune-project'
    cmd=[sys.executable,'-m','oft.unitpaths','--root',str(full),'--part','build','--dune-project-to',str(generated),unit]
    log('COMMAND',json.dumps(cmd))
    with listfile.open('w') as f:subprocess.run(cmd,stdout=f,check=True)
    selected=listfile.read_text().splitlines()
    if selected!=paths(repo):raise RuntimeError('Main source unitpaths differ from official archive snapshot')
    roots=sorted(set(selected+['tools','oft','release.yaml','dune-project']))
    manifest=record(full,roots)
    save(scratch/'source-manifest.json',manifest)
    compare('Main source closure',manifest,record(repo,roots))
    temporary=scratch/'view.preparing'
    if temporary.exists():temporary.rename(scratch/('view.preparing.failed.'+str(time.time_ns())))
    if view.exists():raise RuntimeError('Refusing existing view with no prepared marker')
    temporary.mkdir()
    for rel in sorted(set(selected+['tools','oft','release.yaml'])):
        src=full/rel;dst=temporary/rel;dst.parent.mkdir(parents=True,exist_ok=True)
        if src.is_dir():shutil.copytree(src,dst,symlinks=True)
        else:shutil.copy2(src,dst,follow_symlinks=False)
    shutil.copy2(generated,temporary/'dune-project')
    temporary.rename(view)
    official_binary_check()
    readonly(factsdir);readonly(view)
    view.chmod(view.stat().st_mode | stat.S_IWUSR)
    vm=record(view,roots)
    # Every copied original byte is preserved; only dune-project is the
    # officially selected list of forms, checked against official generation.
    original=manifest.copy();actual=vm.copy()
    del original['dune-project'];del actual['dune-project']
    compare('View copied source bytes',original,actual)
    if (view/'dune-project').read_text()!=reduced_dune(full):raise RuntimeError('Bad reduced dune-project')
    save(scratch/'view-manifest.json',vm)
    state={'commit':'ad0a85d4c37bc1c985ef72826a02ee33b01cbbd6','unit':unit,'unitpaths':selected,'source_roots':roots,'view_roots':roots,'facts_sha256':digest(factsfile),'source_manifest_sha256':digest(scratch/'source-manifest.json'),'view_manifest_sha256':digest(scratch/'view-manifest.json'),'archive_sha256':json.loads((scratch/'full-unpacked.json').read_text())['archive_sha256']}
    save(statefile,state)
    for p in (scratch/'source-manifest.json',scratch/'view-manifest.json',statefile):p.chmod(0o444)
    log('PREPARED',len(selected),'official view paths;',len(vm),'manifest entries')
    log('PROOF_DIRECTORIES',len([p for p in (view/unitrel/'proofs').iterdir() if p.is_dir() and p.name not in ('lib','provenance')]))
    log('PROOF_LIBRARY_V_FILES',sum(1 for p in (view/unitrel/'proofs/lib').rglob('*.v')))
(scratch/'check-work').mkdir(exist_ok=True)
log('VIEW='+str(view));log('FACTS='+str(factsdir));log('TMPDIR='+str(scratch/'check-work'))
log('Native preparation only: no Dune/Rocq build and no Program execution performed')
log('CHECK_COMMAND',str(view/'oft'),'check',unit,'--facts-from',str(factsdir),'--parts statements')
log('CHECK_COMMAND',str(view/'oft'),'check',unit,'--facts-from',str(factsdir),'--parts proofs --statements plain_halts')
PY
