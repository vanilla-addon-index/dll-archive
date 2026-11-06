import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {safeName,parseSource,httpsUrl} from '../scripts/providers.mjs';
import {selectReleases,reconcile,syncComponent,verify,hash,detectLicense} from '../scripts/archive.mjs';

const config={personalBackup:true,maxArchiveBytes:10000000,maxFileBytes:1000000,overrides:{},extraSources:{}};
const rows=[{id:1,name:'PerfBoost',slug:'perfboost',category:'DLL',entry_type:'dll',versions:[{url:'https://github.com/example/perf_boost'},{url:'https://github.com/example/PerfBoostSettings'}]}];
async function fixture(t){const root=await fs.mkdtemp(path.join(os.tmpdir(),'archive-test-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));return root;}
function provider(){
 const state={commit:'a'.repeat(40),source:'hello',asset:'binary-one',tagSource:'tag-source',fail:false};
 const api={
  sourceInfo:async()=>({license:'MIT'}),
  temporaryCheckout:async()=>{const temp=await fs.mkdtemp(path.join(os.tmpdir(),'archive-upstream-'));await fs.writeFile(path.join(temp,'README.md'),state.source);return {temp,root:temp,commit:state.commit};},
  releases:async()=>[{id:'10',tag:'v1.0',name:'Release one',body:'notes',sourceUrl:'https://example.com/source.tar.gz',assets:[{id:'20',name:'mod.dll',url:'https://example.com/mod.dll',digest:'sha256:'+hash(state.asset)}]}],
  request:async url=>{if(state.fail)throw new Error('upstream offline');return Buffer.from(url.endsWith('mod.dll')?state.asset:state.tagSource);}
 };return {api,state};
}

test('discovery groups companion repositories, retains paths and removed entries',()=>{
 let registry=reconcile({entries:[]},rows,config);assert.equal(registry.entries[0].folder,'PerfBoost');assert.deepEqual(registry.entries[0].components.map(c=>c.folder),['perf_boost','PerfBoostSettings']);
 const renamed=structuredClone(rows);renamed[0].name='New name';renamed[0].versions.pop();registry=reconcile(registry,renamed,config);
 assert.equal(registry.entries[0].folder,'PerfBoost');assert.equal(registry.entries[0].components[1].active,false);
 registry=reconcile(registry,[{...rows[0],id:2,name:'Another',versions:[]}],config);assert.equal(registry.entries.find(e=>e.id===1).active,false);
 assert.throws(()=>reconcile(registry,[],config));assert.throws(()=>reconcile(registry,[rows[0],rows[0]],config));
});

test('folder collisions and component URL shapes are explicit and traversal-safe',()=>{
 assert.equal(safeName('CON'),'_CON');assert.throws(()=>safeName('..'));
 for(const u of ['http://example.com/a','https://127.0.0.1/a','https://user:password@example.com/a','https://[::1]/a'])assert.throws(()=>httpsUrl(u));
 assert.equal(parseSource('https://github.com/owner/repo.git').repo,'repo');
 const file=parseSource('https://github.com/RetroCro/TurtleWoW-Mods/blob/main/Archive/DLL%20BACKUP/a.dll');assert.equal(file.kind,'file');assert.equal(file.filename,'a.dll');assert.match(file.url,/raw.githubusercontent.com/);
 assert.equal(parseSource('https://octowow.st/git/owner/repo').api,'https://octowow.st/git/api/v1/repos/owner/repo');
 const list=[...rows,{...rows[0],id:2,name:'perfboost'}];const r=reconcile({entries:[]},list,config);assert.notEqual(r.entries[0].folder.toLowerCase(),r.entries[1].folder.toLowerCase());
});

test('initial copy, no-op update, replaced binaries, tag changes and failure preservation',async t=>{
 const root=await fixture(t),r=reconcile({entries:[]},rows,config),e=r.entries[0],c=e.components[0],objects={};const {api,state}=provider();
 await syncComponent(root,e,c,config,objects,api);assert.equal(c.status,'mirrored');assert.equal(await verify(root,{entries:[{...e,components:[c]}]}),3);
 const dir=path.join(root,e.folder,c.folder);const original=await fs.readFile(path.join(dir,'mirror.json'),'utf8');
 await syncComponent(root,e,c,config,objects,api);assert.equal(await fs.readFile(path.join(dir,'mirror.json'),'utf8'),original);
 state.asset='binary-two';state.tagSource='new-source-for-retagged-release';state.commit='b'.repeat(40);state.source='updated README';
 await syncComponent(root,e,c,config,objects,api);let saved=JSON.parse(await fs.readFile(path.join(dir,'mirror.json'),'utf8'));assert.equal(saved.releases['10'].revisions.length,2);assert.equal(await verify(root,{entries:[{...e,components:[c]}]}),5);
 const before=await fs.readFile(path.join(dir,'mirror.json'),'utf8');const ledger=JSON.stringify(objects);state.fail=true;state.commit='c'.repeat(40);await syncComponent(root,e,c,config,objects,api);
 assert.equal(c.status,'error');assert.equal(await fs.readFile(path.join(dir,'mirror.json'),'utf8'),before);assert.equal(JSON.stringify(objects),ledger);
});

test('checksums detect tampering; an LFS pointer can be verified without downloading the object',async t=>{
 const root=await fixture(t),r=reconcile({entries:[]},rows,config),e=r.entries[0],c=e.components[0];const {api,state}=provider();await syncComponent(root,e,c,config,{},api);
 const dir=path.join(root,e.folder,c.folder),file=path.join(dir,'releases/v1.0--10/assets/mod.dll');await fs.writeFile(file,'tampered');await assert.rejects(()=>verify(root,{entries:[{...e,components:[c]}]}),/checksum mismatch/);
 await fs.writeFile(file,`version https://git-lfs.github.com/spec/v1\noid sha256:${hash(state.asset)}\nsize ${state.asset.length}\n`);
 process.env.ARCHIVE_ALLOW_LFS_POINTERS='1';try{assert.equal(await verify(root,{entries:[{...e,components:[c]}]}),3);}finally{delete process.env.ARCHIVE_ALLOW_LFS_POINTERS;}
});

test('unlicensed public mirrors are metadata-only; private backup mode is explicit',async t=>{
 const root=await fixture(t),r=reconcile({entries:[]},rows,config),e=r.entries[0],c=e.components[0];const {api}=provider();api.sourceInfo=async()=>({license:null});
 await syncComponent(root,e,c,{...config,personalBackup:false},{},api);assert.equal(c.status,'needs-permission');
 assert.equal(detectLicense({'LICENSE':'This program is licensed for personal use only.'},null),null);
 await syncComponent(root,e,c,config,{},api);assert.equal(c.status,'mirrored');
});

test('file backup replacements are preserved and storage limits do not erase a valid copy',async t=>{
 const root=await fixture(t),e={folder:'Files'},c={originalUrl:'https://example.com/a.dll',folder:'dll',source:{kind:'file',url:'https://example.com/a.dll',filename:'a.dll'}};let content='one';const api={request:async()=>Buffer.from(content)},objects={};
 await syncComponent(root,e,c,config,objects,api);content='two';await syncComponent(root,e,c,config,objects,api);assert.equal(await verify(root,{entries:[{...e,name:'Files',components:[c]}]}),2);
 const before=await fs.readFile(path.join(root,'Files/dll/releases/files/a.dll'),'utf8');content='many bytes exceed allowance';await syncComponent(root,e,c,{...config,maxArchiveBytes:1},objects,api);assert.equal(c.status,'error');assert.equal(await fs.readFile(path.join(root,'Files/dll/releases/files/a.dll'),'utf8'),before);
});

test('unsafe upstream release filenames cannot escape the entry folder',async t=>{
 const root=await fixture(t),r=reconcile({entries:[]},rows,config),e=r.entries[0],c=e.components[0];const {api}=provider();api.releases=async()=>[{id:'1',tag:'../v1',sourceUrl:'https://example.com/s.tar.gz',assets:[{id:'2',name:'../escape.dll',url:'https://example.com/a.dll'}]}];
 await syncComponent(root,e,c,config,{},api);assert.equal(c.status,'error');assert.match(c.error,/Unsafe release/);
});

 test('latest release selection prefers stable releases and sorts publication dates',()=>{
 const releases=[{id:'old',published:'2024-01-01'},{id:'preview',published:'2026-01-01',prerelease:true},{id:'new',published:'2025-01-01'}];
 assert.deepEqual(selectReleases(releases,'latest').map(r=>r.id),['new']);
 assert.deepEqual(selectReleases([releases[1]],'latest').map(r=>r.id),['preview']);
 assert.deepEqual(selectReleases([],'latest'),[]);
 assert.equal(selectReleases(releases,'all').length,3);
 });

test('latest scope removes older release folders only after a successful refresh',async t=>{
 const root=await fixture(t),{api,state}=provider();
 const entry={folder:'project'},component={folder:'',source:parseSource('https://github.com/example/project'),originalUrl:'https://github.com/example/project'};
 const objects={};await syncComponent(root,entry,component,config,objects,api);
 const old=api.releases;api.releases=async()=>[...(await old()),{...(await old())[0],id:'11',tag:'v2.0',published:'2026-01-01',assets:[]}];
 state.fail=true;await syncComponent(root,entry,component,{...config,releaseScope:'latest'},objects,api);
 assert.equal(component.status,'error');assert.equal((await fs.stat(path.join(root,'project/releases/v1.0--10'))).isDirectory(),true);
 state.fail=false;await syncComponent(root,entry,component,{...config,releaseScope:'latest'},objects,api);
 assert.equal(component.status,'mirrored');await assert.rejects(fs.stat(path.join(root,'project/releases/v1.0--10')),{code:'ENOENT'});
 const saved=JSON.parse(await fs.readFile(path.join(root,'project/mirror.json')));assert.deepEqual(Object.keys(saved.releases),['11']);
 await verify(root,{entries:[{...entry,components:[{...component,folder:''}]}]});
});


test('upstream Git rules are preserved inertly without changing or hiding archived files',async t=>{
 const root=await fixture(t),{api}=provider(),checkout=api.temporaryCheckout;
 api.temporaryCheckout=async()=>{const c=await checkout();await fs.writeFile(path.join(c.root,'.gitignore'),'README.md\n');await fs.writeFile(path.join(c.root,'.gitattributes'),'* text=auto\n');return c;};
 const entry={folder:'project'},component={folder:'',source:parseSource('https://github.com/example/project'),originalUrl:'https://github.com/example/project'};
 await syncComponent(root,entry,component,config,{},api);
 assert.equal(component.status,'mirrored');
 assert.equal(await fs.readFile(path.join(root,'project/source/.gitignore.upstream'),'utf8'),'README.md\n');
 assert.equal(await fs.readFile(path.join(root,'project/source/.gitattributes.upstream'),'utf8'),'* text=auto\n');
 await assert.rejects(fs.stat(path.join(root,'project/source/.gitattributes')),{code:'ENOENT'});
});
