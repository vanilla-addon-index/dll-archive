import { useQuery, useQueryClient } from '@tanstack/react-query';
import { open } from '@tauri-apps/plugin-dialog';
import { CreditsPanel, type Credit } from '../components/CreditsPanel';
import { RefreshCw, Plug, Plus, Star, Trash2, Wrench } from 'lucide-react';
import { api, errorText, type PluginInfo, type PluginSource } from '../lib/ipc';
import { confirm } from '../lib/dialog';
import { useSettings } from '../lib/settings';
import { toast } from '../lib/toast';
import { Button, cn, Empty, PageHeader, Panel, Select, Switch } from '../components/ui';

type SourceOption = { value: PluginSource; label: string };

const latestSourceLabel = ({ file, source }: PluginInfo) => {
	const owner = file === 'UnitXP_SP3.dll' ? 'brues-Code'
		: file === 'Lexara112.dll' ? 'Lexara112'
		: source?.replace(/^(octogit|codeberg):/, '').split('/')[0];
	return owner ? `Latest (${owner})` : 'Latest';
};

/** [name, mod URL, companion addon URL] — same list as v2.6. */
const CREDITS: Credit[] = [
	['DucielPerf', 'https://octowow.st/git/Hapto/DucielPerf/releases', null],
	['VanillaFixes', 'https://github.com/hannesmann/vanillafixes', null],
	['VanillaHelpers', 'https://github.com/isfir/VanillaHelpers', null],
	['PerfBoost', 'https://raw.githubusercontent.com/RetroCro/TurtleWoW-Mods/refs/heads/main/Archive/DLL%20BACKUP/perf_boost.dll', 'https://octowow.st/git/Dusk/PerfBoostSettings'],
	['UnitXP_SP3', 'https://codeberg.org/konaka/UnitXP_SP3', 'https://codeberg.org/konaka/UnitXP_SP3_Addon'],
	['UnitXP_SP3 (brues-code fork)', 'https://github.com/brues-code/UnitXP_SP3', 'https://github.com/brues-code/UnitXP_SP3_Addon'],
	['Nampower', 'https://github.com/brues-code/nampower', 'https://github.com/brues-code/NampowerSettings'],
	['SuperWoW', 'https://github.com/balakethelock/SuperWoW', 'https://github.com/balakethelock/SuperAPI'],
	['ClassicAPI', 'https://github.com/brues-code/ClassicAPI', null],
	['Vanilla-Autologin', 'https://github.com/MarcelineVQ/turtle-autologin', null],
	['WeirdUtils (MarcelineVQ)', 'https://codeberg.org/MarcelineVQ/WeirdUtils/releases'],
	['AuctionQueryThrottle', 'https://github.com/brues-code/AuctionQueryThrottle/releases', null],
	['Lexara112', 'https://github.com/xnobus/lexara112/releases', null],
	['OctoLogin', 'https://github.com/fmustafayaman/OctoLogin/releases', null],
	['Vanilla Tweaks', 'https://github.com/brndd/vanilla-tweaks', null],
	['DXVK', 'https://github.com/doitsujin/dxvk', null],
	['RetroCro’s TurtleWoW Mods archive', 'https://github.com/RetroCro/TurtleWoW-Mods'],
	['no1600x1200', 'https://raw.githubusercontent.com/RetroCro/TurtleWoW-Mods/refs/heads/main/Archive/DLL%20BACKUP/no1600x1200.dll']
];

/** Compact toggle row, like v2.6: switch + DLL name, optional source picker on the right. */
/** What Apply will install for a plugin with a GitHub source: the newest release tag, or the bundled copy. */
const VersionTag = ({ source, latest, loading, bundled, archived }: { source: PluginSource; latest: string | undefined; loading: boolean; bundled?: string | null; archived: boolean }) => {
	const label = archived ? 'Version from RetroCro'
		: source === 'Recommended' ? (bundled ?? 'Version unknown') : (latest ?? (loading ? '…' : 'Version unknown'));
	const title =
		source !== 'Recommended'
			? latest
				? `Apply will download release ${latest} from upstream.`
				: loading
					? 'Checking upstream for the newest release…'
					: (bundled !== undefined ? "Upstream unavailable. Apply can use Recommended." : "Upstream unavailable. Apply keeps any installed copy.")
			: 'Apply will install the copy bundled with the manager.';
	return (
		<span title={archived ? 'Apply will download the DLL from RetroCro’s archive.' : title} className="max-w-full rounded-md bg-white/[0.05] px-2 py-0.5 font-mono text-[11px] text-muted">
			{label}
		</span>
	);
};

const PluginToggle = ({ p, latest, loading, update, bundled, installed }: { p: PluginInfo; latest?: string; loading: boolean; update?: string; bundled?: string | null; installed?: string | null }) => {
	const { settings, stage } = useSettings();
	const customSetting = Object.entries(settings.customPlugins).find(([file]) => file.toLowerCase() === p.file.toLowerCase());
	const enabled = settings.plugins[p.file] ?? customSetting?.[1] ?? p.defaultEnabled;
	const hasBundle = bundled !== undefined;
	const selected = settings.pluginSources[p.file];
	const source = hasBundle && selected !== 'Latest' ? 'Recommended' : 'Latest';
	const archived = p.source?.startsWith('https://') ?? false;
	const latestLabel = latestSourceLabel(p);
	const options: SourceOption[] = [
		{ value: 'Recommended', label: 'Recommended' },
		{ value: 'Latest', label: latestLabel }
	];
	return (
		<div className="flex min-h-11 flex-wrap items-center gap-x-3 gap-y-2 px-4 py-2" title={p.file + ': ' + p.description}>
			<Switch checked={enabled} onChange={v => stage(s => ({ ...s, plugins: { ...s.plugins, [p.file]: v } }))} label={p.file} />
			<div className="min-w-0 flex-[1_0_10rem] wrap-anywhere">
				<div className={cn('text-[13px] font-medium', enabled ? 'text-fg' : 'text-muted')}>{p.file}</div>
				<p className="mt-1 text-xs text-muted">{p.description}</p>
				<p className="mt-1 text-[11px] text-subtle">Installed: {installed ?? (installed === null ? 'Version unknown' : '—')}</p>
			</div>
			{(p.source || hasBundle) && (
				<>
					<>{update && <span className="text-amber-400 text-xs" title={update.startsWith("!") ? "Update check unavailable: " + update.slice(1) : `Latest release ${update} from the selected source differs from your installed DLL.`} aria-label={update.startsWith("!") ? "Update check unavailable" : "Update available"}>{update.startsWith("!") ? "?" : "↑"}</span>}</><VersionTag source={source} latest={latest} loading={loading} bundled={bundled} archived={archived} />
					{p.source && hasBundle ? <Select
						value={source}
						options={options}
						onChange={v => stage(s => ({ ...s, pluginSources: { ...s.pluginSources, [p.file]: v } }))}
					/> : p.source && !archived && <span className="text-xs text-muted">{latestLabel}</span>}
				</>
			)}
		</div>
	);
};

export const ClientTweaksPage = () => {
	const { settings, stage } = useSettings();
	const queryClient = useQueryClient();
	const inventory = useQuery({ queryKey: ['pluginInventory', settings.wowDir, Object.keys(settings.customPlugins).sort()], queryFn: api.getPluginInventory });
	const catalog = useQuery({ queryKey: ['plugins'], queryFn: api.getPluginCatalog, staleTime: Infinity });
	const versions = useQuery({ queryKey: ['pluginVersions'], queryFn: api.getPluginLatestVersions, staleTime: 10 * 60 * 1000, retry: false });
	const updates = useQuery({ queryKey: ['pluginUpdates', settings.wowDir, settings.pluginSources], queryFn: () => api.checkPluginUpdates(settings.pluginSources), enabled: !!settings.wowDir, staleTime: 10 * 60 * 1000, retry: false });
	const core = catalog.data?.filter(p => p.group === 'core') ?? [];
	const optional = catalog.data?.filter(p => p.group === 'optional') ?? [];
	const hidden = new Set([...(catalog.data ?? []).map(p => p.file.toLowerCase()), 'weirdperformance.dll', 'transmogfix.dll', 'worldmarkers.dll', 'interact.dll']);
	const custom = Object.entries(settings.customPlugins).filter(([file]) => !hidden.has(file.toLowerCase()));

	const addCustom = async () => {
		const picked = await open({ multiple: true, title: 'Select Custom DLL', filters: [{ name: 'DLL files', extensions: ['dll', 'DLL'] }] });
		for (const path of picked ? (Array.isArray(picked) ? picked : [picked]) : []) {
			await addCustomDll(path, stage);
		}
	};

	const removeCustom = async (file: string) => {
		const ok = await confirm({
			title: `Remove ${file}?`,
			message: 'This deletes the file from your game folder and removes it from the manager.',
			confirmLabel: 'Remove',
			danger: true
		});
		if (!ok) return;
		try {
			await api.customDllRemove(file);
			void queryClient.invalidateQueries({ queryKey: ['pluginInventory'] });
			stage(s => {
				const next = { ...s.customPlugins };
				delete next[file];
				return { ...s, customPlugins: next };
			});
		} catch (e) {
			toast.error(errorText(e));
		}
	};

	return (
		<>
			<PageHeader title="Client Mods" description="Toggle core engine modifications and utilities." />
			<div className="mb-3"><Button icon={RefreshCw} disabled={!settings.wowDir || updates.isFetching} onClick={() => { updates.refetch(); versions.refetch(); inventory.refetch(); }}>{updates.isFetching ? 'Checking…' : 'Check DLL Updates'}</Button></div>
            <p className="mb-4 text-xs text-muted">↑ means the release from the selected source differs from your installed DLL. Hover for details. Checks cover DLLs with an upstream source; custom DLLs are unmanaged.</p>

			<Panel icon={Star} title="Recommended Client Mods" description="Highly Recommended for stability, performance, and gameplay enhancement.">
				{core.map(p => (
					<PluginToggle key={p.file} p={p} latest={versions.data?.[p.file]} loading={versions.isLoading}
						bundled={inventory.data?.bundled[p.file]} installed={updates.data?.installed[p.file] ?? inventory.data?.installed[p.file]} update={updates.data?.updates[p.file]} />
				))}
			</Panel>
			<Panel icon={Wrench} title="Optional Client Mods" description="Additional quality-of-life plugins.">
				{optional.map(p => (
					<PluginToggle key={p.file} p={p} latest={versions.data?.[p.file]} loading={versions.isLoading}
						bundled={inventory.data?.bundled[p.file]} installed={updates.data?.installed[p.file] ?? inventory.data?.installed[p.file]} update={updates.data?.updates[p.file]} />
				))}
			</Panel>

			<Panel
				icon={Plug}
				title="Custom User Client Mods"
				description="Manage your own third-party DLLs. They will automatically be added/removed from your dlls.txt file."
				actions={
					<Button size="sm" icon={Plus} onClick={addCustom} disabled={!settings.wowDir}>
						Add Custom DLL
					</Button>
				}
			>
				{custom.length === 0 ? (
					<div className="p-4">
						<Empty icon={Plug} title="No custom DLLs managed">
							Click "Add Custom DLL" to import one, or drop a .dll onto the window.
						</Empty>
					</div>
				) : (
					custom.map(([file, on]) => (
						<div key={file} className="group flex min-h-11 items-center gap-3 px-4 py-2" title={file}>
							<Switch checked={on} onChange={v => stage(s => ({ ...s, customPlugins: { ...s.customPlugins, [file]: v } }))} label={file} />
							<span className="min-w-0 flex-1 wrap-anywhere text-[13px]">{file}<small className="block text-subtle">Installed: {inventory.data?.installed[file] ?? (inventory.data?.installed[file] === null ? 'Version unknown' : '—')}</small></span>
							<Button
								variant="danger"
								size="sm"
								icon={Trash2}
								title="Remove"
								className="opacity-0 group-hover:opacity-100"
								onClick={() => removeCustom(file)}
							/>
						</div>
					))
				)}
			</Panel>

			<CreditsPanel credits={CREDITS} description="This tool packages the work of several open-source developers." />
		</>
	);
};

/** Copies a DLL into the game folder and enables it (used by drag & drop too). */
export const addCustomDll = async (path: string, stage: ReturnType<typeof useSettings>['stage']) => {
	try {
		const name = await api.customDllAdd(path);
		stage(s => ({ ...s, customPlugins: { ...s.customPlugins, [name]: true } }));
		toast.success(`Added ${name}. Click Apply Changes to load it.`);
	} catch (e) {
		toast.error(errorText(e));
	}
};
