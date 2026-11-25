from pathlib import Path
import re, subprocess, hashlib, concurrent.futures
root=Path.home()/'projects/oss-verify-native-env'
packages=['dune.3.23.0','rocq-core.9.2.0','rocq-stdlib.9.2.0','rocq-stdpp.1.13.0','coq-flocq.4.2.2','rocq-read-file.0.0.2']
def fetch(pkg):
    name=pkg.split('.')[0]
    paths=[root/'deps/rocq-opam/released/packages'/name/pkg/'opam',root/'deps/opam-default/packages'/name/pkg/'opam']
    path=next((p for p in paths if p.exists()),None)
    if not path: print('MISSING',pkg,flush=True);return
    txt=path.read_text(); urltxt=txt[txt.rfind('url {'):]; m=re.search(r'(sha256|sha512)=([0-9a-f]+)',urltxt)
    if not m:print('NO_SHA256',pkg,flush=True);return
    algo,sha=m[1],m[2]; dst=root/'opam-root/download-cache'/algo/sha[:2]/sha
    if dst.exists():print('CACHED',pkg,flush=True);return
    dst.parent.mkdir(parents=True,exist_ok=True)
    urls=['https://opam.ocaml.org/cache/'+algo+'/'+sha[:2]+'/'+sha]
    src=re.search(r'src:\s*"([^"]+)"',urltxt)[1]
    if '/archive/' in src: urls.append(src.replace('https://github.com/','https://codeload.github.com/').replace('/archive/','/tar.gz/').removesuffix('.tar.gz'))
    if pkg=='rocq-stdlib.9.2.0':urls.append('https://opam.ocaml.org/cache/sha256/f2/f2ee1cb0b9af3e7b20625f0e9ec4becb7a27bb453d53b9bc0ea3d67bc8b3142c')
    for url in urls:
      print('DOWNLOAD',pkg,url,flush=True)
      out=dst.with_suffix('.part')
      p=subprocess.run(['curl','--max-time','90','-fLsS',url,'-o',str(out)])
      if p.returncode==0 and hashlib.new(algo,out.read_bytes()).hexdigest()==sha:
        out.replace(dst);print('VERIFIED',pkg,sha,flush=True);return
    print('FAILED',pkg,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:list(ex.map(fetch,packages))
