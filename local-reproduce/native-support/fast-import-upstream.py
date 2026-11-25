#!/usr/bin/env python3
"""Reconstruct exact upstream Git objects from the official immutable source tar."""
import hashlib, json, os, pathlib, subprocess, sys, tarfile, time
BASE=pathlib.Path('/home/wupeihan/projects/oss-verify-native-env')
ARCHIVE=BASE/'downloads/oss-verify-proofs-ad0a85d.tar.gz'
META=BASE/'downloads/upstream-commit.json'
WORK=pathlib.Path('/var/tmp/wupeihan-oss-verify-git-import')
REPO=WORK/'upstream.git'
EXPECTED_COMMIT='ad0a85d4c37bc1c985ef72826a02ee33b01cbbd6'
EXPECTED_TREE='a36ade652af3a438ecfa227a79240b7480b00ed4'
start=time.monotonic()
def log(s): print(time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),s,flush=True)
def git(*args,input=None):
 return subprocess.check_output(['git','--git-dir='+str(REPO),*args],input=input).decode().strip()
def quote(path):
 # Git C-quoting; use octal escapes for non-ASCII bytes, control chars and escapes.
 return b'"'+b''.join(bytes([b]) if 32<=b<127 and b not in (34,92) else ('\\%03o'%b).encode() for b in os.fsencode(path))+b'"'
metadata=json.loads(META.read_text())
assert metadata['sha']==EXPECTED_COMMIT
assert metadata['tree']['sha']==EXPECTED_TREE
assert metadata['verification']['verified'] is True
WORK.mkdir(mode=0o700,exist_ok=True)
if REPO.exists(): raise SystemExit('Refusing to overwrite existing import repository')
subprocess.run(['git','init','--bare','--initial-branch=main',str(REPO)],check=True)
subprocess.run(['git','--git-dir='+str(REPO),'config','gc.auto','0'],check=True)
log('Reading official archive '+str(ARCHIVE))
p=subprocess.Popen(['git','-c','core.compression=0','-c','pack.compression=0','--git-dir='+str(REPO),'fast-import','--quiet','--done','--depth=0','--max-pack-size=100g'],stdin=subprocess.PIPE)
w=p.stdin
w.write(b'commit refs/heads/archive-import\ncommitter Archive Import <archive-import@localhost> 0 +0000\ndata 0\n\n')
count=0; total=0; prefix=None
try:
 with tarfile.open(ARCHIVE,'r|gz') as archive:
  for m in archive:
   top,sep,path=m.name.partition('/')
   if prefix is None: prefix=top
   if top!=prefix: raise RuntimeError('Unexpected multiple tar roots')
   if not sep or not path or m.isdir(): continue
   if path.startswith('/') or '..' in pathlib.PurePosixPath(path).parts: raise RuntimeError('Unsafe tar path '+path)
   if m.issym():
    mode=b'120000'; content=os.fsencode(m.linkname); size=len(content); source=None
   elif m.isfile():
    mode=b'100755' if m.mode & 0o111 else b'100644'; size=m.size; source=archive.extractfile(m)
   else: raise RuntimeError('Unexpected tar member type '+repr((m.name,m.type)))
   w.write(b'M '+mode+b' inline '+quote(path)+b'\ndata '+str(size).encode()+b'\n')
   if source is None: w.write(content)
   else:
    left=size
    while left:
     block=source.read(min(left,1024*1024))
     if not block: raise RuntimeError('Truncated tar member '+path)
     w.write(block); left-=len(block)
    source.close()
   w.write(b'\n'); count+=1; total+=size
   if count%1000==0: log('imported files=%d bytes=%d elapsed=%.1fs last=%s'%(count,total,time.monotonic()-start,path))
 w.write(b'\ndone\n'); w.close()
 status=p.wait()
 if status: raise RuntimeError('git fast-import exited '+str(status))
except BaseException:
 p.kill(); p.wait(); raise
log('Archive import complete files=%d bytes=%d elapsed=%.1fs'%(count,total,time.monotonic()-start))
tree=git('rev-parse','refs/heads/archive-import^{tree}')
log('ACTUAL_TREE='+tree)
if tree!=EXPECTED_TREE: raise SystemExit('TREE MISMATCH: preserving artifacts for diagnosis')
v=metadata['verification']; header,message=v['payload'].split('\n\n',1)
commit=(header+'\ngpgsig '+v['signature'].replace('\n','\n ')+'\n\n'+message).encode()
sha=hashlib.sha1(b'commit '+str(len(commit)).encode()+b'\0'+commit).hexdigest()
log('RECONSTRUCTED_COMMIT='+sha)
if sha!=EXPECTED_COMMIT: raise SystemExit('COMMIT MISMATCH: not writing upstream ref')
actual=git('hash-object','-t','commit','-w','--stdin',input=commit)
assert actual==EXPECTED_COMMIT
subprocess.run(['git','--git-dir='+str(REPO),'update-ref','refs/heads/main',actual],check=True)
subprocess.run(['git','--git-dir='+str(REPO),'update-ref','-d','refs/heads/archive-import'],check=True)
(REPO/'shallow').write_text(actual+'\n')
subprocess.run(['git','--git-dir='+str(REPO),'symbolic-ref','HEAD','refs/heads/main'],check=True)
log('Final HEAD='+git('rev-parse','HEAD'))
log('Final TREE='+git('rev-parse','HEAD^{tree}'))
for path in sorted((REPO/'objects/pack').iterdir()): log('PACK_FILE %s bytes=%s'%(path,path.stat().st_size))
log('SUCCESS elapsed=%.1fs'%(time.monotonic()-start))
