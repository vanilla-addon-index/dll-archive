"""Extract an upstream source tar without allowing paths or links to escape it."""
import json
import pathlib
import shutil
import sys
import tarfile

archive, destination = sys.argv[1:]
root = pathlib.Path(destination).resolve()
root.mkdir(parents=True, exist_ok=True)
links = {}
top = None
with tarfile.open(archive, "r:gz") as tar:
    for member in tar:
        parts = pathlib.PurePosixPath(member.name).parts
        if not parts or member.name.startswith("/") or ".." in parts or "\\" in member.name:
            raise ValueError("Unsafe source archive path")
        if top is None:
            top = parts[0]
        if parts[0] != top:
            raise ValueError("Multiple source archive roots")
        parts = parts[1:]
        if not parts or ".git" in parts:
            continue
        target = root.joinpath(*parts).resolve()
        if not target.is_relative_to(root):
            raise ValueError("Source archive escaped its directory")
        if member.isdir():
            target.mkdir(parents=True, exist_ok=True)
        elif member.isfile():
            if member.size > 2 * 1024**3:
                raise ValueError("Source file exceeds allowance")
            target.parent.mkdir(parents=True, exist_ok=True)
            with tar.extractfile(member) as source, target.open("wb") as out:
                shutil.copyfileobj(source, out)
            target.chmod(0o755 if member.mode & 0o111 else 0o644)
        elif member.issym() or member.islnk():
            # Inert link text; never ask the OS to follow an upstream link.
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(member.linkname, encoding="utf-8")
            links["/".join(parts)] = member.linkname
        else:
            raise ValueError("Unsupported source archive entry")
print(json.dumps(links))
