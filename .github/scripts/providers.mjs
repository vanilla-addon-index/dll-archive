import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
const exec = promisify(execFile);

export function safeName(value) {
 const name=String(value).normalize('NFC').replace(/[<>:"/\\|?*\x00-\x1f]/g,'-').replace(/[ .]+$/g,'').trim();
 if(!name || name==='.' || name==='..') throw new Error('Empty or unsafe name');
 return /^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)/i.test(name) ? '_'+name : name;
}
export function httpsUrl(value) {
 const u=new URL(value);
 if(u.protocol!=='https:' || u.username || u.password || u.port && u.port!=='443' || /^(localhost|127\.|10\.|192\.168\.|169\.254\.|0\.|\[|172\.(1[6-9]|2\d|3[01])\.)/i.test(u.hostname)) throw new Error('Only public HTTPS sources are allowed');
 return u;
}
export function parseSource(value,override={}) {
 const u=httpsUrl(override.url??value);const p=u.pathname.split('/').filter(Boolean).map(decodeURIComponent);
 if(override.kind==='file' || u.hostname==='raw.githubusercontent.com') return {kind:'file',url:u.href,filename:safeName(override.filename??p.at(-1)),name:override.folder??p.at(-1)};
 let host=u.hostname,owner,repo,ref,subpath;
 if(host==='github.com') { [owner,repo]=p; if(p[2]==='blob') return {kind:'file',url:`https://raw.githubusercontent.com/${p[0]}/${p[1]}/${p.slice(3).map(encodeURIComponent).join('/')}`,filename:safeName(p.at(-1)),name:p.at(-1)}; if(p[2]==='tree'){ref=p[3];subpath=p.slice(4).join('/');} }
 else if(host==='octowow.st' && p[0]==='git') {[owner,repo]=p.slice(1);if(p.length>3)throw new Error('Review non-root OctoWoW repository link');}
 else if(['codeberg.org','gitea.com'].includes(host)){[owner,repo]=p;if(p.length>2)throw new Error('Review non-root repository link');}
 else throw new Error('Unsupported source host; needs a provider');
 if(!owner||!repo || /[\s\\/#?]/.test(owner+repo) || ['.','..'].includes(owner) || ['.','..'].includes(repo))throw new Error('Invalid repository');
 repo=repo.replace(/\.git$/,'');
 return {kind:'repository',host,owner,repo,name:repo,ref,subpath,url:`https://${host}/${host==='octowow.st'?'git/':''}${owner}/${repo}`,api:host==='github.com'?`https://api.github.com/repos/${owner}/${repo}`:`https://${host}/${host==='octowow.st'?'git/':''}api/v1/repos/${owner}/${repo}`};
}

export async function request(url,{json=false,maxBytes=2**31}={}) {
 for(let redirects=0;redirects<8;redirects++) {
  const u=httpsUrl(url);const headers={'User-Agent':'vanilla-addon-index-dll-archive'};
  const token=process.env.GH_TOKEN??process.env.GITHUB_TOKEN;
  if(u.hostname==='api.github.com' && token)headers.Authorization=`Bearer ${token}`;
  const r=await fetch(u,{headers,redirect:'manual',signal:AbortSignal.timeout(600000)});
  if([301,302,303,307,308].includes(r.status)){url=new URL(r.headers.get('location'),u).href;continue;}
  if(!r.ok)throw new Error(`HTTP ${r.status}: ${u.origin}${u.pathname}`);
  if(Number(r.headers.get('content-length'))>maxBytes)throw new Error('Download exceeds file limit');
  const parts=[];let bytes=0;for await(const chunk of r.body){bytes+=chunk.length;if(bytes>maxBytes)throw new Error('Download exceeds file limit');parts.push(chunk);}
  const data=Buffer.concat(parts);return json?JSON.parse(data.toString('utf8')):data;
 }
 throw new Error('Too many redirects');
}
export async function paginate(base,github) {
 const items=[];
 for(let page=1;page<=10000;page++){
  const list=await request(`${base}${base.includes('?')?'&':'?'}${github?'per_page=100':'limit=50'}&page=${page}`,{json:true,maxBytes:30*1024*1024});
  if(!Array.isArray(list))throw new Error('Expected release list');
  items.push(...list);if(list.length<(github?100:50))return items;
 }
 throw new Error('Release pagination limit reached');
}

const gitEnv=()=>Object.fromEntries(Object.entries({...process.env,GIT_TERMINAL_PROMPT:'0',GIT_LFS_SKIP_SMUDGE:'1',GIT_CONFIG_NOSYSTEM:'1'}).filter(([k])=>!['GH_TOKEN','GITHUB_TOKEN'].includes(k)));
async function git(args,cwd) {
 return (await exec('git',['-c','credential.helper=','-c','core.hooksPath=/dev/null','-c','protocol.file.allow=never','-c','protocol.ext.allow=never',...args],{cwd,env:gitEnv(),maxBuffer:20*1024*1024,timeout:600000})).stdout.trim();
}
export async function checkout(source,destination,depth=0) {
 if(depth>10)throw new Error('Submodule nesting limit');
 if(source.host!=='github.com')return archiveCheckout(source,destination,depth);
 await git(['-c','core.symlinks=false','clone','--depth','1','--no-tags',source.url+'.git',destination]);
 if(source.ref){await git(['fetch','--depth','1','origin',source.ref],destination);await git(['checkout','--detach','FETCH_HEAD'],destination);}
 const commit=await git(['rev-parse','HEAD'],destination);
 // Check submodule transports before Git contacts them. Relative URLs stay on the same public HTTPS host.
 const roots=[destination];
 async function modules(dir,depth=0){
  if(depth>10)throw new Error('Submodule nesting limit');
  let text;try{text=await fs.readFile(path.join(dir,'.gitmodules'),'utf8');}catch(e){if(e.code==='ENOENT')return;throw e;}
  for(const line of text.split('\n')){const m=line.match(/^\s*url\s*=\s*(.+?)\s*$/);if(m&&!m[1].startsWith('../')&&!m[1].startsWith('./'))httpsUrl(m[1]);}
  await git(['submodule','update','--init','--depth','1'],dir);
  let output;try{output=await git(['config','--file','.gitmodules','--get-regexp','^submodule\..*\.path$'],dir);}catch(e){if(e.code===1)return;throw e;}
  const paths=output.split('\n').filter(Boolean).map(x=>x.slice(x.indexOf(' ')+1));
  for(const p of paths){const full=path.resolve(dir,p);if(!full.startsWith(path.resolve(dir)+path.sep))throw new Error('Unsafe submodule path');roots.push(full);await modules(full,depth+1);}
 }
 await modules(destination);
 const symlinks={};
 for(const dir of roots){
  try{const text=await fs.readFile(path.join(dir,'.lfsconfig'),'utf8');for(const line of text.split('\n')){const m=line.match(/^\s*url\s*=\s*(.+?)\s*$/);if(m)httpsUrl(m[1]);}}catch(e){if(e.code!=='ENOENT')throw e;}
  const listing=await git(['ls-files','--stage','-z'],dir);
  for(const item of listing.split('\0'))if(item.startsWith('120000 ')){const relative=item.slice(item.indexOf('\t')+1),file=path.resolve(dir,relative);if(!file.startsWith(path.resolve(dir)+path.sep))throw new Error('Unsafe symlink path');const stat=await fs.lstat(file);symlinks[path.relative(destination,file).split(path.sep).join('/')]=stat.isSymbolicLink()?await fs.readlink(file):await fs.readFile(file,'utf8');}
 }
 // Fetch real LFS objects, including objects within submodules, without forwarding archive credentials.
 await git(['lfs','pull'],destination);
 await git(['submodule','foreach','--recursive','git -c credential.helper= lfs pull'],destination);
 let root=destination;
 if(source.subpath){root=path.resolve(destination,source.subpath);if(!root.startsWith(path.resolve(destination)+path.sep))throw new Error('Unsafe source path');}
 return {commit,root,symlinks};
}

async function archiveCheckout(source,destination,depth){
 const meta=await sourceInfo(source);
 const ref=source.ref??meta.defaultBranch;
 const revision=await request(`${source.api}/git/commits/${encodeURIComponent(ref)}`,{json:true});const commit=revision.sha;
 if(!/^[a-f0-9]{40,64}$/.test(commit??''))throw new Error('Invalid upstream commit');
 const data=await request(`${source.api}/archive/${commit}.tar.gz`);
 const tar=destination+'.tar.gz';await fs.mkdir(path.dirname(destination),{recursive:true});await fs.writeFile(tar,data);
 let symlinks;
 try{const output=await exec(process.platform==='win32'?'python':'python3',[fileURLToPath(new URL('./unpack.py',import.meta.url)),tar,destination],{maxBuffer:20*1024*1024,timeout:600000});symlinks=JSON.parse(output.stdout);}finally{await fs.rm(tar,{force:true});}
 // Source archives omit submodule content. Resolve the recorded Git tree entries explicitly.
 try{
  await fs.access(path.join(destination,'.gitmodules'));
  let output;try{output=await git(['config','--file','.gitmodules','--get-regexp','^submodule\..*\.path$'],destination);}catch(e){if(e.code===1)return {commit,root:destination,symlinks};throw e;}
  const tree=await request(`${source.api}/git/trees/${commit}?recursive=1`,{json:true,maxBytes:30*1024*1024});
  for(const line of output.split('\n').filter(Boolean)){
   const split=line.indexOf(' '),key=line.slice(0,split),relative=line.slice(split+1),url=await git(['config','--file','.gitmodules','--get',key.replace(/\.path$/,'.url')],destination);
   const resolved=url.startsWith('../')||url.startsWith('./')?new URL(url,source.url+'.git/').href:url;httpsUrl(resolved);
   let item=tree.tree?.find(x=>x.path===relative&&x.type==='commit');
   if(!item){
    let treeSha=revision.tree?.sha??commit;
    const parts=relative.split('/');
    for(let i=0;i<parts.length;i++){
     const level=await request(`${source.api}/git/trees/${treeSha}`,{json:true,maxBytes:30*1024*1024});
     const node=level.tree?.find(x=>x.path===parts[i]);
     if(!node)throw new Error('Missing submodule tree path');
     if(i===parts.length-1){if(node.type==='commit')item=node;}else{if(node.type!=='tree')throw new Error('Invalid submodule tree path');treeSha=node.sha;}
    }
   }
   if(!item)throw new Error('Missing submodule commit');
   const target=path.resolve(destination,relative);if(!target.startsWith(path.resolve(destination)+path.sep))throw new Error('Unsafe submodule path');
   const result=await checkout({...parseSource(resolved),ref:item.sha},target,depth+1);for(const [p,value] of Object.entries(result.symlinks??{}))symlinks[relative+'/'+p]=value;
  }
 }catch(e){if(e.code!=='ENOENT')throw e;}
 const root=source.subpath?path.resolve(destination,source.subpath):destination;
 if(root!==destination&&!root.startsWith(path.resolve(destination)+path.sep))throw new Error('Unsafe source path');
 return {commit,root,symlinks};
}

export async function sourceInfo(source) {
 const meta=await request(source.api,{json:true,maxBytes:10*1024*1024});
 return {defaultBranch:meta.default_branch,license:meta.license?.spdx_id??null};
}
export async function releases(source) {
 const github=source.host==='github.com';
 const list=await paginate(source.api+'/releases',github);
 return list.filter(r=>!r.draft).map(r=>({
  id:String(r.id),tag:r.tag_name,name:r.name??r.tag_name,body:r.body??'',published:r.published_at,prerelease:!!r.prerelease,url:r.html_url,
  sourceUrl:github?r.tarball_url:`${source.api}/archive/${encodeURIComponent(r.tag_name)}.tar.gz`,
  assets:(Array.isArray(r.assets)?r.assets:r.assets?.links??r.attachments??[]).map(a=>({id:String(a.id),name:a.name,url:a.browser_download_url??a.download_url,size:a.size??null,updated:a.updated_at??null,digest:a.digest??null}))
 }));
}
export async function temporaryCheckout(source) {
 const temp=await fs.mkdtemp(path.join(os.tmpdir(),'dll-archive-'));
 try {return {...await checkout(source,path.join(temp,'repo')),temp};}catch(e){await fs.rm(temp,{recursive:true,force:true});throw e;}
}
