import { useEffect, useState, useSyncExternalStore } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { open } from '@tauri-apps/plugin-dialog';
import { FolderX, Layers, Music, Pencil, Plus, RefreshCw, Trash2 } from 'lucide-react';
import { api, errorText, formatBytes, type ModStatus, type MpqEntry } from '../lib/ipc';
import { useJobs } from '../lib/jobs';
import { useSettings } from '../lib/settings';
import { toast } from '../lib/toast';
import { confirm, Modal } from '../lib/dialog';
import { Button, cn, Empty, PageHeader, Switch, Panel } from '../components/ui';
import { CreditsPanel, type Credit } from '../components/CreditsPanel';

const PATCH_CREDITS: Credit[] = [
	['OctoWoW Patch-O', 'https://dl.octowow.st/client/latest/Data/patch-O.mpq'],
	['Darker Nights — Project Reforged', 'https://projectreforged.github.io/vanilla/downloads/turtle/'],
	['Pretty Night Sky — RetroCro archive', 'https://github.com/RetroCro/TurtleWoW-Mods'],
	['Epoch Water — RetroCro archive', 'https://github.com/RetroCro/TurtleWoW-Mods'],
	['Fog Pushback — RetroCro archive', 'https://github.com/RetroCro/TurtleWoW-Mods'],
	['Pink Herbs', 'https://github.com/seacrabsam/patch-herb'],
	['NoErrorSounds', 'https://github.com/Macumbafeh/NoErrorSounds'],
	['FishPing', 'https://github.com/notsureawake/FishPing'],
	['Warlock Muted Demons', 'https://github.com/spzilyk/Warlock-Muted-Demons'],
	['Mute Billy — RaidVisuals reference', 'https://octowow.st/git/Rook/RaidVisuals-OctoWoW'],
];

const AUDIO_FILES: Record<string, string> = {
	'no-error-sounds': 'Sound/Spells/Fizzle/*.wav, Sound/interface/*.wav',
	'fish-ping': 'Sound/Spells/Tradeskills/FishBite.wav',
	'muted-demons': 'Data/Sound/Creature/**/*.wav',
};

// ---------- queue of .mpq files waiting for their details dialog ----------

let queue: string[] = [];
const listeners = new Set<() => void>();
const notify = () => listeners.forEach(l => l());

/** Add dropped / picked .mpq paths; each gets a "New Game Mod" dialog in turn. */
export const queueMpqs = (paths: string[]) => {
	queue = [...queue, ...paths.filter(p => p.toLowerCase().endsWith('.mpq'))];
	notify();
};
const shiftQueue = () => {
	queue = queue.slice(1);
	notify();
};
const useQueueHead = () =>
	useSyncExternalStore(
		l => (listeners.add(l), () => listeners.delete(l)),
		() => queue[0]
	);

const fileName = (path: string) => path.split(/[\\/]/).pop() ?? path;
/** "patch-hd-water.mpq" → "Patch Hd Water", like v2.6. */
const defaultTitle = (name: string) => name.replace(/\.mpq$/i, '').replace(/-/g, ' ').replace(/\b\w/g, c => c.toUpperCase());

const DetailsDialog = ({ file, isNew, onDone }: { file: string; isNew: boolean; onDone: (saved: { title: string; description: string } | null) => void }) => {
	const { settings } = useSettings();
	const meta = settings.gameModsMeta[file];
	const [title, setTitle] = useState(meta?.title || defaultTitle(file));
	const [description, setDescription] = useState(meta?.description ?? '');
	return (
		<Modal
			title={isNew ? 'New Game Mod Detected' : 'Edit Mod Details'}
			subtitle={`File: ${file}`}
			onClose={() => onDone(null)}
			footer={
				<>
					<Button onClick={() => onDone(null)}>{isNew ? 'Skip' : 'Cancel'}</Button>
					<Button variant="primary" onClick={() => onDone({ title: title.trim(), description: description.trim() })}>
						{isNew ? 'Install Mod' : 'Save'}
					</Button>
				</>
			}
		>
			<label className="block text-xs font-medium text-muted">Title</label>
			<input
				autoFocus
				value={title}
				onChange={e => setTitle(e.target.value)}
				className="mt-1.5 h-9 w-full rounded-lg border border-line-strong bg-black/30 px-3 text-[13px] outline-none focus:border-accent"
			/>
			<label className="mt-4 block text-xs font-medium text-muted">Description</label>
			<textarea
				value={description}
				onChange={e => setDescription(e.target.value)}
				rows={3}
				placeholder="What does this patch change?"
				className="mt-1.5 w-full resize-none rounded-lg border border-line-strong bg-black/30 px-3 py-2 text-[13px] outline-none placeholder:text-subtle focus:border-accent"
			/>
		</Modal>
	);
};

const CuratedMods = () => {
    const { settings } = useSettings();
    const qc = useQueryClient();
    const jobs = useJobs();
    const running = jobs.some(j => j.status === 'running');
    const [busy, setBusy] = useState<string | null>(null);
    const [install, setInstall] = useState<{ job: number; id: string; wowDir: string } | null>(null);
    const catalog = useQuery({ queryKey: ['modCatalog'], queryFn: api.getModCatalog, staleTime: Infinity });
    const inventoryKey = ['modInventory', settings.wowDir];
    const inventory = useQuery({ queryKey: inventoryKey, queryFn: () => api.checkModUpdates(false), enabled: !!settings.wowDir });
    const updates = useQuery({
        queryKey: ['modUpdates', settings.wowDir],
        queryFn: () => api.checkModUpdates(true),
        enabled: !!settings.wowDir,
        staleTime: Infinity,
        retry: false,
        retryOnMount: false,
        refetchOnMount: false,
        refetchOnWindowFocus: false,
        refetchOnReconnect: false,
    });

    useEffect(() => {
        if (!install) return;
        const job = jobs.find(entry => entry.id === install.job);
        if (!job || job.status === 'running') return;
        if (job.status === 'finished') {
            qc.setQueryData<ModStatus[]>(['modUpdates', install.wowDir], list => list?.map(patch =>
                patch.id === install.id ? { ...patch, updateAvailable: false, detail: 'Up to date' } : patch));
        }
        setInstall(null);
    }, [install, jobs, qc]);

    const act = async (id: string, enabled?: boolean) => {
        setBusy(id);
        try {
            if (enabled === undefined) {
                const job = await api.catalogModInstall(id);
                setInstall({ job, id, wowDir: settings.wowDir });
                toast.success('Patch installation started. Progress appears below.');
            } else {
                await api.catalogModToggle(id, enabled);
                qc.setQueryData<ModStatus[]>(inventoryKey, list => list?.map(patch =>
                    patch.id === id ? { ...patch, enabled } : patch));
            }
        } catch(e) { toast.error(errorText(e)); }
        finally { setBusy(null); }
    };
    return <>
        <div className="mb-3 flex items-center gap-3"><Button icon={RefreshCw} disabled={!settings.wowDir || updates.isFetching} onClick={() => updates.refetch()}>Check Custom Patches Updates</Button>{updates.isFetching && <span className="text-xs text-muted">Checking sources…</span>}{updates.error && <span className="text-xs text-amber-400">{errorText(updates.error)}</span>}</div>
        {(['Visual', 'Audio'] as const).map(category => <Panel key={category} icon={category === 'Audio' ? Music : Layers} title={category}>
            {catalog.data?.filter(m => m.category === category).map(m => {
                const status = inventory.data?.find(s => s.id === m.id);
                const update = updates.data?.find(s => s.id === m.id);
                const updateAvailable = !!status?.installed && !!update?.updateAvailable;
                const unavailable = !!updates.error || update?.detail.startsWith('Update check unavailable');
                const action = !status ? 'Checking…'
                    : updateAvailable ? 'Update'
                    : !status.installed ? 'Install'
                    : !status.managed ? 'Track'
                    : unavailable ? 'Check unavailable'
                    : update?.detail === 'Up to date' ? 'Up to date' : 'Check for updates';
                return <div key={m.id} className="flex items-center gap-3 px-4 py-3" title={m.title + ': ' + m.description}>
                    {status?.managed && <Switch label={'Enable ' + m.title} checked={status.enabled} disabled={busy !== null || install?.id === m.id} onChange={v => act(m.id, v)} />}
                    <div className="min-w-0 flex-1">
                        <div className="text-[13px] font-medium">{m.title} {updateAvailable && <span className="text-amber-400" aria-label="Update available" title={update?.detail}>↑</span>}</div>
                        <p className="mt-1 text-xs text-muted">{m.description}</p>
                        <p className="mt-1 wrap-anywhere font-mono text-[11px] text-muted">{m.file ? fileName(m.file).toLowerCase() : AUDIO_FILES[m.id]}</p>
                        {status?.installed && <p className="mt-1 text-[11px] text-subtle">{status.enabled ? 'Installed' : 'Disabled'}</p>}
                    </div>
                    <Button size="sm" title={update?.detail || undefined} disabled={!settings.wowDir || !status || busy !== null || install !== null || running || updates.isFetching || (status.managed && !updateAvailable)} onClick={() => act(m.id)}>{action}</Button>
                </div>;
            })}
        </Panel>)}
    </>;
};

export const GameModsPage = () => {
	const { settings, update } = useSettings();
	const qc = useQueryClient();
	const key = ['gameMods', settings.wowDir];
	const mods = useQuery({ queryKey: key, queryFn: api.scanGameMods, enabled: !!settings.wowDir });
	const pendingPath = useQueueHead();
	const [editing, setEditing] = useState<string | null>(null);

	const setMeta = (file: string, meta: { title: string; description: string } | null) =>
		update(s => {
			const next = { ...s.gameModsMeta };
			if (meta) next[file] = meta;
			else delete next[file];
			return { ...s, gameModsMeta: next };
		});

	const addMods = async () => {
		const picked = await open({ multiple: true, title: 'Select Game Mods', filters: [{ name: 'MPQ patches', extensions: ['mpq', 'MPQ'] }] });
		if (picked) queueMpqs(Array.isArray(picked) ? picked : [picked]);
	};

	const finishNew = async (saved: { title: string; description: string } | null) => {
		const path = pendingPath!;
		shiftQueue();
		if (!saved) return;
		try {
			const name = await api.mpqInstall(path);
			setMeta(name, saved);
			toast.success(`Installed ${saved.title || name}`);
		} catch (e) {
			toast.error(errorText(e));
		}
	};

	const toggle = async (m: MpqEntry, enabled: boolean) => {
		qc.setQueryData<MpqEntry[]>(key, list => list?.map(x => (x.baseName === m.baseName ? { ...x, enabled } : x)));
		try {
			await api.mpqSetEnabled(m.baseName, enabled);
		} catch (e) {
			toast.error(errorText(e));
			qc.invalidateQueries({ queryKey: ['gameMods'] });
		}
	};

	const remove = async (m: MpqEntry, title: string) => {
		const ok = await confirm({ title: `Delete ${title}?`, message: `${m.fileName} will be permanently deleted from your Data folder.`, confirmLabel: 'Delete', danger: true });
		if (!ok) return;
		try {
			await api.mpqDelete(m.fileName);
			setMeta(m.baseName, null);
		} catch (e) {
			toast.error(errorText(e));
		}
	};

	return (
		<>
			<PageHeader
				title="Custom Patches"
				description="Manage custom MPQ modifications. Drag and drop .mpq files anywhere to install."
			/>
			<CuratedMods />
			<div className="mb-3 flex flex-wrap items-center justify-between gap-2">
				<h2 className="text-sm font-medium">Custom MPQ Files</h2>
				<div className="flex items-center gap-2">
					<Button size="sm" icon={RefreshCw} onClick={() => mods.refetch()} disabled={!settings.wowDir || mods.isFetching} title="Rescan local MPQ files" aria-label="Rescan local MPQ files" />
					<Button size="sm" icon={Plus} onClick={addMods} disabled={!settings.wowDir}>Add Mod</Button>
				</div>
			</div>
			{!settings.wowDir ? (
				<Empty icon={FolderX} title="No game folder">
					Please set a valid WoW directory in Game Settings to manage MPQs.
				</Empty>
			) : mods.error ? (
				<Empty icon={FolderX} title="Couldn't read Data folder">
					{errorText(mods.error)}
				</Empty>
			) : mods.data?.length === 0 ? (
				<Empty icon={Layers} title="No custom patches found in your Data folder">
					Click Add Mod, or drop an .mpq file onto the window.
				</Empty>
			) : (
				<div className="grid grid-cols-1 gap-2.5">
					{mods.data?.map(m => {
						// Titles live in settings; read them here so edits show instantly.
						const meta = settings.gameModsMeta[m.baseName];
						const title = meta?.title || m.title;
						return (
							<div
								key={m.baseName}
								title={title + ': ' + (meta?.description || m.description || 'No description provided.')}
								className={cn('lazy-row group flex items-center gap-4 rounded-xl border border-line bg-panel px-4 py-3.5 transition-colors hover:bg-panel-hover', !m.enabled && 'opacity-60')}
							>
								<Switch checked={m.enabled} onChange={v => toggle(m, v)} label={`Enable ${title}`} />
								<div
									className={cn(
										'flex h-10 w-10 shrink-0 items-center justify-center rounded-xl',
										m.enabled ? 'brand-gradient text-white shadow-[0_4px_14px_-4px_rgb(139_92_246/0.6)]' : 'border border-line bg-white/[0.04] text-subtle'
									)}
								>
									<Layers size={18} />
								</div>
								<div className="min-w-0 flex-1">
									<div className="wrap-anywhere text-[13px] font-medium">{title}</div>
									<div className="mt-1 text-xs text-muted">{meta?.description || 'No description provided.'}</div>
									<div className="mt-0.5 font-mono text-[11px] text-subtle">
										File: {m.baseName} · {formatBytes(m.size)}
									</div>
								</div>
								<div className="flex opacity-0 transition-opacity group-hover:opacity-100">
									<Button variant="ghost" size="sm" icon={Pencil} onClick={() => setEditing(m.baseName)} title="Edit details" />
									<Button variant="danger" size="sm" icon={Trash2} onClick={() => remove(m, title)} title="Delete MPQ file" />
								</div>
							</div>
						);
					})}
				</div>
			)}

			<div className="mt-4">
				<CreditsPanel credits={PATCH_CREDITS} description="Sources for the visual and audio patches in this catalog." linkLabel="Patch" />
			</div>

			{pendingPath && !editing && <DetailsDialog key={pendingPath} file={fileName(pendingPath)} isNew onDone={finishNew} />}
			{editing && (
				<DetailsDialog
					file={editing}
					isNew={false}
					onDone={saved => {
						if (saved) setMeta(editing, saved);
						setEditing(null);
					}}
				/>
			)}
		</>
	);
};
