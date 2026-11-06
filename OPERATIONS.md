# Using this archive

This is a **private personal backup**, organized by the entries in the site's DLL collection. Related DLLs, settings addons and alternative repositories have component subfolders. It contains current upstream source files and the latest published release for each project, not upstream Git history. Original READMEs, source files and license notices are kept under `source/`. Upstream `.gitattributes` and `.gitignore` files are preserved with an added `.upstream` suffix so their filter and ignore rules cannot alter or omit backup files. Rename them back when restoring an upstream working tree. Release assets keep their original filenames under `releases/<tag>--<release-id>/assets/`. Each release also has its notes and a source archive for that release tag.

The archive automation is MIT licensed. That does not relicense the mirrored projects. Keep this repository and any personal-backup copies private. The importer checks repository visibility before copying anything in personal-backup mode. Do not change this repository to public without a separate redistribution review.

The newest stable release is selected by publication date; projects with only prereleases use their newest prerelease. All assets of that release are retained. Older release folders are replaced after a successful update; previously committed versions remain recoverable from Git and LFS history. Failed updates preserve the last good copy.

## Automatic checks

- **Discover new client mods:** nightly at 01:23 UTC (02:23 in Copenhagen winter time, 03:23 in summer). Reads the site's published shared `addons.json`; adds new DLL-section entries and new repository links. Retries fetch errors. Existing mirrors are refreshed by the weekly job. A new catalogue entry will be discovered after the site's next successful snapshot publication.
- **Update covered mirrors:** Sundays at 02:41 UTC (03:41 winter / 04:41 summer in Copenhagen). Reconciles the list, checks current source commits, and archives the latest published release and its assets. Source-tag archives and assets without trusted SHA-256 digests are downloaded again to detect replacements. Replaced files move into `revisions/<old-sha256>/`.
- Both workflows have a **Run workflow** button. A shared writer lock prevents concurrent commits. Unchanged content produces no commit. GitHub schedule times are best effort, not an exact-time guarantee.
- A removed listing or link is marked inactive but its backup is retained. Upstream failures preserve the last successful component and fail the run visibly. Other successful components are still saved.

## Copying to your local Git server

Install Git and Git LFS first. Binary files and release archives use LFS; a normal bare Git mirror alone is **not** a complete backup.

```sh
git clone --mirror https://github.com/vanilla-addon-index/dll-archive.git
cd dll-archive.git
git lfs fetch --all
git remote add local YOUR_PRIVATE_LOCAL_GIT_URL
git push --mirror local
git lfs push --all local
```

Your local server needs Git LFS support. Check a fresh working clone from that server with `git lfs pull` and `npm run verify`. `--mirror` copies all refs and can delete destination refs, so use a dedicated empty destination repository. To make a standalone filesystem backup instead, clone normally, run `git lfs pull`, and copy the hydrated working directory.

GitHub Actions deliberately checks out LFS pointers rather than downloading all existing binaries on each run. Checksums validate those pointers' object IDs; source/release downloads validate actual content, and Git LFS checks objects during upload. This avoids repeated archive LFS download bandwidth. A full local `npm run verify` requires hydrated files and hashes their actual bytes.

## Configuration

`config.json` selects the catalogue, source overrides, extra companion repositories, intentionally excluded sources and private backup repository. `excludedSources` is keyed by stable site ID; an excluded upstream is removed from the registry and skipped even while it remains in the published catalogue. Remove its existing folder when applying an exclusion. Automation code, tests and registry data live under `.github/`; `.github/state/registry.json` maps stable site IDs and upstream URLs to persistent folders, while `.github/state/objects.json` records unique content hashes and cumulative logical bytes. `mirror.json` and `SHA256SUMS` record component provenance and integrity.

PerfBoost's individually linked backup files are scoped file mirrors rather than copies of the entire unrelated backup repository. No1600x1200 is scoped to its DLL. SuperAPI and PandaConquest Companion are explicitly included with their parent entries. New source hosts or unusual URL formats produce an unsupported status until a provider or override is added.

The initial cumulative content allowance is **8 GiB**, with a **2 GiB per-file limit**. This is a conservative importer guard, not an account billing limit. GitHub LFS also counts historical objects, may have other repositories consuming the same allowance, and has separate download bandwidth limits. Check your organization budget and allowance before raising the limits. Never silently omit oversized files: the affected component reports an error and retains its last valid copy.

For a local manual run:

```sh
# Authenticate gh first, then set GH_TOKEN without printing it.
export GH_TOKEN="$(gh auth token)"
npm test
npm run discover
npm run update
npm run verify
```

The scripts download public upstream repositories anonymously through Git; the token is used only for GitHub API requests, including the archive privacy check. Upstream build scripts and workflows are never run. Submodule transports are restricted; source symlinks are stored as inert link-text files, with their original targets recorded in `mirror.json` for deliberate restoration. Missing source or assets are reported, never invented or rebuilt.

To retry a single failed mirror, use either workflow (discovery retries errors). To approve a public mirror outside personal-backup mode, record explicit source/release permissions and evidence under `permissions` in `config.json`. Do not use that as a substitute for upstream terms.
