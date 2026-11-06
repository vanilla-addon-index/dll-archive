import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import * as upstream from './providers.mjs';

export const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
const json=value=>JSON.stringify(value,null,2)+'\n';
export async function readJson(file,fallback){try{return JSON.parse(await fs.readFile(file,'utf8'));}catch(e){if(e.code==='ENOENT')return fallback;throw e;}}
async function write(file,data){await fs.mkdir(path.dirname(file),{recursive:true});await fs.writeFile(file,data);}
function allocate(name,used,suffix){const base=upstream.safeName(name);let next=base;if(used.has(next.toLowerCase()))next+='--'+upstream.safeName(String(suffix));let n=2;while(used.has(next.toLowerCase()))next=base+'--'+upstream.safeName(String(suffix))+'--'+n++;used.add(next.toLowerCase());return next;}

export function reconcile(registry,rows,config){
 if(!Array.isArray(rows)||!rows.length)throw new Error('Empty or invalid catalogue; preserving registry');
 const client=rows.filter(r=>r.entry_type==='dll');if(!client.length)throw new Error('No DLL entries; refusing to replace registry');
 const ids=new Set();for(const e of client){if(!Number.isSafeInteger(e.id)||ids.has(e.id)||!e.name||!Array.isArray(e.versions))throw new Error('Invalid or duplicate catalogue entry');ids.add(e.id);}
 const entries=structuredClone(registry.entries??[]);
 const folders=new Set(['docs','.github','.work','readme.md','operations.md','license','config.json','package.json','.gitattributes','.gitignore',...entries.map(e=>e.folder.toLowerCase())]);
 for(const e of entries){e.active=ids.has(e.id);for(const c of e.components)c.active=false;}
 for(const entry of client){
  let e=entries.find(e=>e.id===entry.id);
  if(!e){e={id:entry.id,name:entry.name,folder:allocate(entry.name,folders,entry.id),components:[]};entries.push(e);}
  e.name=entry.name;e.active=true;e.kind=entry.category;e.site=`https://vanilla-addon-index.github.io/dll/${entry.slug}`;
  const excluded=new Set(config.excludedSources?.[String(entry.id)]??[]);
  e.components=e.components.filter(c=>!excluded.has(c.originalUrl));
  const urls=[...new Set([...entry.versions.map(v=>v.url),...(config.extraSources?.[String(entry.id)]??[])])].filter(url=>!excluded.has(url));
  const names=new Set(['source','releases','readme.md','mirror.json','sha256sums',...e.components.map(c=>c.folder.toLowerCase())]);
  for(const url of urls){
   let c=e.components.find(c=>c.originalUrl===url);
   if(!c){
    const override=config.overrides?.[url]??{};let source,error;
    try{source=upstream.parseSource(url,override);}catch(err){error=err.message;}
    const single=urls.length===1&&e.components.length===0;
    const suffix=source?.owner??hash(url).slice(0,8);
    const folder=single?'':allocate(override.folder??source?.name??'unrecognized',names,suffix);
    if(single)names.add('');
    c={originalUrl:url,folder,source:source??null,status:error?'unsupported':'new',error:error??null};e.components.push(c);
   }
   c.active=true;
  }
 }
 return {version:1,entries:entries.sort((a,b)=>a.id-b.id)};
}

export function detectLicense(documents,spdx){
 const known=['MIT','Zlib','BSD-2-Clause','BSD-3-Clause','Apache-2.0','GPL-2.0','GPL-3.0','LGPL-2.1','LGPL-3.0','Unlicense','ISC'];
 const text=Object.entries(documents).filter(([n])=>/^(licen[cs]e(?:\..*)?|copying(?:\..*)?)$/i.test(n)).map(([,t])=>t).join('\n');
 if(/personal use only|all rights reserved[\s\S]*express written permission/i.test(text))return null;
 if(known.includes(spdx))return spdx;
 if(/Permission is hereby granted, free of charge/i.test(text))return 'MIT';
 if(/GNU (?:LESSER )?GENERAL PUBLIC LICENSE/i.test(text))return /GNU LESSER/i.test(text)?'LGPL':'GPL';
 if(/Redistribution and use in source and binary forms[\s\S]*are permitted/.test(text))return 'BSD';
 if(/This is free and unencumbered software released into the public domain/.test(text))return 'Unlicense';
 if(/Permission to use, copy, modify, and(?:\/or)? distribute this software/.test(text))return 'ISC';
 if(/This software is provided 'as-is'[\s\S]*Permission is granted to anyone to use this software/.test(text))return 'Zlib';
 return null;
}
async function rootDocs(root){const docs={};for(const item of await fs.readdir(root,{withFileTypes:true})){if(item.isFile()&&/^(licen[cs]e|copying|third.party|project.identity)/i.test(item.name)){const f=path.join(root,item.name);if((await fs.stat(f)).size<200000)docs[item.name]=await fs.readFile(f,'utf8');}}return docs;}

export async function copySource(from,to,config,objects){
 const files={},links={};
 async function walk(src,dst,relative=''){
  await fs.mkdir(dst,{recursive:true});
  for(const ent of (await fs.readdir(src,{withFileTypes:true})).sort((a,b)=>a.name.localeCompare(b.name))){
   if(ent.name==='.git')continue;
   const name=['.gitattributes','.gitignore'].includes(ent.name)?ent.name+'.upstream':ent.name;
    if(['.gitattributes','.gitignore'].includes(ent.name) && await exists(path.join(src,name)))throw new Error('Inert attributes filename collision');
    const r=relative?relative+'/'+name:name;const a=path.join(src,ent.name),b=path.join(dst,name);
   if(ent.isDirectory())await walk(a,b,r);
   else {
    let content;if(ent.isSymbolicLink()){const target=await fs.readlink(a);links[r]=target;content=Buffer.from(target);}else if(ent.isFile()){const size=(await fs.stat(a)).size;if(size>config.maxFileBytes)throw new Error(`Source file too large: ${r}`);content=await fs.readFile(a);}else throw new Error('Unsupported source file type');
    if(content.subarray(0,90).toString().startsWith('version https://git-lfs.github.com/spec/v1\n'))throw new Error('Unresolved upstream LFS pointer: '+r);
    const sha=hash(content);addObject(objects,sha,content.length,config);await fs.writeFile(b,content);files[r]={sha256:sha,bytes:content.length};
   }
  }
 }
 await walk(from,to);return {files,symlinks:links};
}
function addObject(objects,sha,bytes,config){if(!objects[sha]){const total=Object.values(objects).reduce((a,b)=>a+b,0);if(total+bytes>config.maxArchiveBytes)throw new Error('Archive storage allowance reached; increase maxArchiveBytes after review');objects[sha]=bytes;}}
async function download(url,dest,config,objects,provider){const data=await provider.request(url,{maxBytes:config.maxFileBytes});const sha=hash(data);addObject(objects,sha,data.length,config);await write(dest,data);return {sha256:sha,bytes:data.length};}
async function exists(p){try{await fs.access(p);return true;}catch(e){if(e.code==='ENOENT')return false;throw e;}}
function componentDir(root,e,c){return path.join(root,e.folder,c.folder);}

export function selectReleases(releases, scope){
 if(scope!=='latest')return releases;
 const stable=releases.filter(r=>!r.prerelease);
 const candidates=stable.length?stable:releases;
 return [...candidates].sort((a,b)=>(Date.parse(b.published)||0)-(Date.parse(a.published)||0)).slice(0,1);
}

export async function syncComponent(root,e,c,config,objects,provider=upstream){
 const originalObjects={...objects};let checkout,stage;
 const dest=componentDir(root,e,c);const previous=await readJson(path.join(dest,'mirror.json'),{});
 try{
  const permission=config.permissions?.[c.originalUrl]??config.permissions?.[c.source?.url]??{};
  if(!c.source)throw new Error(c.error??'Unsupported source');
  let state={...previous,upstream:c.originalUrl,source:c.source};
  if(c.source.kind==='repository'){
   const info=await provider.sourceInfo(c.source);
   checkout=await provider.temporaryCheckout(c.source);
   const docs=await rootDocs(checkout.root);const license=detectLicense(docs,info.license);
   // A project-wide license must not override an explicit third-party exception.
   const mixed=Object.entries(docs).some(([n,t])=>/third.party|project.identity/i.test(n)&&/does not override|not automatically|not covered|separate permission|no redistribution|restricted|retain their own/i.test(t));
   const permitted=permission.source!==false && (config.personalBackup || permission.source===true || license&&!mixed);
   if(!permitted){c.status='needs-permission';c.error=permission.reason??(mixed?'Third-party redistribution terms need review':'No clear redistribution license found');c.license=license;return;}
   c.license=license??permission.license??'Unspecified upstream license (private personal backup)';
   const list=selectReleases(await provider.releases(c.source),config.releaseScope);
   stage=await fs.mkdtemp(path.join(os.tmpdir(),'dll-mirror-stage-'));const work=path.join(stage,'component');
   if(await exists(dest))await fs.cp(dest,work,{recursive:true});else await fs.mkdir(work,{recursive:true});
   if(previous.commit!==checkout.commit || !await exists(path.join(work,'source'))){
    await fs.rm(path.join(work,'source'),{recursive:true,force:true});
    const snap=await copySource(checkout.root,path.join(work,'source'),config,objects);
    state={...state,commit:checkout.commit,sourceFiles:snap.files,symlinks:{...snap.symlinks,...checkout.symlinks}};
   }
   const releasePermission=permission.releases!==false;
   if(releasePermission){
    state.releases??={};
    if(config.releaseScope==='latest' && list.length){
      const selected=new Set(list.map(r=>r.id));
      for(const [id,old] of Object.entries(state.releases))if(!selected.has(id)){
       await fs.rm(path.join(work,'releases',old.folder),{recursive:true,force:true});delete state.releases[id];
      }
     }
     let releaseNumber=0;
    for(const release of list){
     if(list.length>10&&releaseNumber++%10===0)console.log(`  releases ${releaseNumber}/${list.length}: ${release.tag}`);
     const folder=upstream.safeName(release.tag)+'--'+upstream.safeName(release.id);const dir=path.join(work,'releases',folder);
     let saved=state.releases[release.id]??{tag:release.tag,folder,assets:{}};
     const sourceTemp=path.join(stage,'release-source');const result=await download(release.sourceUrl,sourceTemp,config,objects,provider);
     if(saved.source&&saved.source.sha256!==result.sha256){const revision=`releases/${folder}/revisions/${saved.source.sha256}/upstream-source.tar.gz`;await fs.mkdir(path.dirname(path.join(work,revision)),{recursive:true});await fs.copyFile(path.join(work,saved.source.path),path.join(work,revision));saved.revisions??=[];if(!saved.revisions.some(r=>r.path===revision))saved.revisions.push({...saved.source,path:revision});}
     await fs.mkdir(dir,{recursive:true});await fs.copyFile(sourceTemp,path.join(dir,'upstream-source.tar.gz'));
     saved.source={...result,path:`releases/${folder}/upstream-source.tar.gz`,url:release.sourceUrl};
     for(const asset of release.assets){
      const name=upstream.safeName(asset.name);if(name!==asset.name)throw new Error('Unsafe release asset filename');
      const old=saved.assets[asset.id];
      // Undigested assets are fetched weekly too: timestamps and sizes alone cannot detect replacement.
      if(old&&asset.digest===`sha256:${old.sha256}`&&old.name===asset.name)continue;
      const temp=path.join(stage,'asset');const record=await download(asset.url,temp,config,objects,provider);
      if(asset.digest?.startsWith('sha256:')&&asset.digest!==`sha256:${record.sha256}`)throw new Error('Upstream release digest mismatch');
      if(old&&(old.sha256!==record.sha256||old.name!==asset.name)){const oldFile=path.join(work,old.path);if(await exists(oldFile)){const revision=`releases/${folder}/revisions/${old.sha256}/${old.name}`;await fs.mkdir(path.dirname(path.join(work,revision)),{recursive:true});await fs.copyFile(oldFile,path.join(work,revision));await fs.rm(oldFile);saved.revisions??=[];if(!saved.revisions.some(r=>r.path===revision))saved.revisions.push({...old,path:revision});}}
      const relative=`releases/${folder}/assets/${name}`;
      if(Object.entries(saved.assets).some(([id,a])=>id!==asset.id&&a.path===relative&&a.sha256!==record.sha256))throw new Error('Release assets collide by filename');
      await fs.mkdir(path.dirname(path.join(work,relative)),{recursive:true});await fs.copyFile(temp,path.join(work,relative));
      saved.assets[asset.id]={...record,id:asset.id,name:asset.name,url:asset.url,path:relative};
     }
     const metadata={id:release.id,tag:release.tag,name:release.name,body:release.body,published:release.published,prerelease:release.prerelease,url:release.url};
     await write(path.join(dir,'release.json'),json(metadata));state.releases[release.id]=saved;
    }
   }
   c.status=releasePermission?'mirrored':'source-only';c.error=releasePermission?null:permission.reason??'Release redistribution needs permission';
  }else{
   if(permission.source===false || !config.personalBackup && permission.source!==true){c.status='needs-permission';c.error=permission.reason??'Backup file redistribution permission needs review';return;}
   stage=await fs.mkdtemp(path.join(os.tmpdir(),'dll-mirror-stage-'));const work=path.join(stage,'component');
   if(await exists(dest))await fs.cp(dest,work,{recursive:true});else await fs.mkdir(work,{recursive:true});
   const temp=path.join(stage,'file');const record=await download(c.source.url,temp,config,objects,provider);const relative=`releases/files/${c.source.filename}`;
   if(previous.file&&previous.file.sha256!==record.sha256){const old=path.join(work,previous.file.path);if(await exists(old)){const revision=`releases/revisions/${previous.file.sha256}/${c.source.filename}`;await fs.mkdir(path.dirname(path.join(work,revision)),{recursive:true});await fs.copyFile(old,path.join(work,revision));await fs.rm(old);state.revisions??=[];if(!state.revisions.some(r=>r.path===revision))state.revisions.push({...previous.file,path:revision});}}
   await fs.mkdir(path.dirname(path.join(work,relative)),{recursive:true});await fs.copyFile(temp,path.join(work,relative));state.file={...record,path:relative,url:c.source.url};c.status='mirrored';c.error=null;
  }
  const work=path.join(stage,'component');await write(path.join(work,'mirror.json'),json(state));
  const checks=Object.entries(state.sourceFiles??{}).map(([p,v])=>[v.sha256,'source/'+p]);
  for(const r of Object.values(state.releases??{})){if(r.source)checks.push([r.source.sha256,r.source.path]);for(const a of [...Object.values(r.assets??{}),...(r.revisions??[])])checks.push([a.sha256,a.path]);}
  for(const a of [...(state.file?[state.file]:[]),...(state.revisions??[])])checks.push([a.sha256,a.path]);
  await write(path.join(work,'SHA256SUMS'),checks.sort((a,b)=>a[1].localeCompare(b[1])).map(([sha,p])=>`${sha}  ${p}\n`).join(''));
  // Replace only owned component content. Root components can also have sibling components and the project README.
  await fs.mkdir(dest,{recursive:true});
  for(const name of ['source','releases','mirror.json','SHA256SUMS']){if(await exists(path.join(work,name))){await fs.rm(path.join(dest,name),{recursive:true,force:true});await fs.rename(path.join(work,name),path.join(dest,name));}}
 }catch(error){Object.keys(objects).forEach(k=>delete objects[k]);Object.assign(objects,originalObjects);c.status='error';c.error=error.message;}
 finally{if(checkout?.temp)await fs.rm(checkout.temp,{recursive:true,force:true});if(stage)await fs.rm(stage,{recursive:true,force:true});}
}

export async function render(root,registry){
 const index=['# DLL archive','','Backups of the Vanilla Addon Index client-mod collection. Current source snapshots and the latest published release for each project; upstream Git history is not imported.','','See [OPERATIONS.md](OPERATIONS.md) for backup, schedules, permissions and recovery.','','| Entry | Kind | Components | Status |','|---|---|---:|---|'];
 for(const e of registry.entries){
  const lines=[`# ${e.name}`,'',`[Original listing](${e.site}) · ${e.kind} · ${e.active?'Listed':'No longer listed; archive retained'}`,'','| Component | Upstream | Status |','|---|---|---|'];
  for(const c of e.components){const label=c.folder||e.name;lines.push(`| ${label} | ${c.originalUrl} | ${c.status}${c.error?' — '+c.error.replaceAll('|','/'):''} |`);}
  lines.push('','Original READMEs and license files live inside each `source/` directory. `mirror.json` records commits, releases and SHA-256 digests. Downloaded programs are upstream originals; this archive does not build or execute them.','');
  await write(path.join(root,e.folder,'README.md'),lines.join('\n'));
  const statuses=[...new Set(e.components.map(c=>c.status))].join(', ');index.push(`| [${e.name}](${encodeURI(e.folder)}/) | ${e.kind} | ${e.components.length} | ${statuses} |`);
 }
 index.push('','This repository’s automation is MIT licensed. Upstream files keep their own licenses. Metadata-only folders need permission or provider support before content can be published.','');
 await write(path.join(root,'README.md'),index.join('\n'));
}

export async function verify(root,registry){
 let count=0;const errors=[];
 for(const e of registry.entries)for(const c of e.components){const dir=componentDir(root,e,c);let text;try{text=await fs.readFile(path.join(dir,'SHA256SUMS'),'utf8');}catch(err){if(err.code==='ENOENT'){if(['mirrored','source-only'].includes(c.status))errors.push(`${e.name}: missing checksums`);continue;}throw err;}
  for(const line of text.trim().split('\n').filter(Boolean)){const m=line.match(/^([a-f0-9]{64})  (.+)$/);if(!m){errors.push('Invalid checksum line');continue;}const full=path.resolve(dir,m[2]);if(!full.startsWith(path.resolve(dir)+path.sep)){errors.push('Unsafe checksum path');continue;}try{const data=await fs.readFile(full);const pointer=process.env.ARCHIVE_ALLOW_LFS_POINTERS==='1'&&data.toString().match(/^version https:\/\/git-lfs.github.com\/spec\/v1\r?\noid sha256:([a-f0-9]{64})\r?\nsize \d+\r?\n$/);if((pointer?pointer[1]:hash(data))!==m[1])errors.push(`${e.name}: checksum mismatch ${m[2]}`);else count++;}catch{errors.push(`${e.name}: missing ${m[2]}`);}}
 }
 if(errors.length)throw new Error(errors.slice(0,20).join('\n'));return count;
}

async function main(){
 const root=process.cwd(),mode=process.argv[2];if(!['discover','update','verify'].includes(mode))throw new Error('Use discover, update or verify');
 const config=await readJson(path.join(root,'config.json'));let registry=await readJson(path.join(root,'.github/state/registry.json'),{version:1,entries:[]});
 if(mode==='verify'){console.log(`Verified ${await verify(root,registry)} archived files.`);return;}
 if(config.personalBackup){
  if(!/^[\w.-]+\/[\w.-]+$/.test(config.repository??''))throw new Error('Set the archive repository for the private backup guard');
  if(process.env.GITHUB_REPOSITORY&&process.env.GITHUB_REPOSITORY!==config.repository)throw new Error('Personal backup workflows must run in the configured private repository');
  const repo=await upstream.request(`https://api.github.com/repos/${config.repository}`,{json:true});
  if(repo.private!==true)throw new Error('Personal backup import requires a PRIVATE repository');
 }
 const rows=await upstream.request(config.catalogue,{json:true,maxBytes:30*1024*1024});registry=reconcile(registry,rows,config);
 const objects=await readJson(path.join(root,'.github/state/objects.json'),{});let failures=0;
 for(const e of registry.entries)for(const c of e.components){
  if(mode==='discover'&&!['new','error'].includes(c.status))continue;
  console.log(`${mode}: ${e.name}${c.folder?'/'+c.folder:''}`);
  await syncComponent(root,e,c,config,objects);
  if(c.status==='error')failures++;console.log(`  ${c.status}${c.error?': '+c.error:''}`);
  // Checkpoint successful components so an interrupted bootstrap can resume.
  await write(path.join(root,'.github/state/registry.json'),json(registry));await write(path.join(root,'.github/state/objects.json'),json(objects));
 }
 await render(root,registry);await write(path.join(root,'.github/state/registry.json'),json(registry));await write(path.join(root,'.github/state/objects.json'),json(objects));
 const verified=await verify(root,registry);console.log(`Verified ${verified} files. ${failures} source errors.`);
 // Catch nonstandard oversized files before committing; ordinary release/binary extensions are already LFS tracked.
 if(process.env.ARCHIVE_TRACK_LARGE==='1'){
  for(const e of registry.entries){async function walk(dir){for(const ent of await fs.readdir(dir,{withFileTypes:true})){const p=path.join(dir,ent.name);if(ent.isDirectory())await walk(p);else if((await fs.stat(p)).size>=50*1024*1024)execFileSync('git',['lfs','track','--filename',path.relative(root,p).split(path.sep).join('/')],{cwd:root});}}await walk(path.join(root,e.folder));}
 }
 const summary=`Archive: ${registry.entries.length} entries; ${verified} verified files; ${registry.entries.flatMap(e=>e.components).filter(c=>c.status==='needs-permission').length} permission reviews; ${failures} fetch errors.\n`;
 if(process.env.GITHUB_STEP_SUMMARY)await fs.appendFile(process.env.GITHUB_STEP_SUMMARY,summary);
 // Commit partial successes in the workflow, then report a failing run for actual fetch errors.
 if(failures)process.exitCode=2;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))main().catch(error=>{console.error(error.message);process.exitCode=1;});
