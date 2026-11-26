// Mirror of src-tauri/src/core/plugins.rs for the browser preview only.
import type { PluginInfo } from './ipc';

const core = (file: string, description: string, extra: Partial<PluginInfo> = {}): PluginInfo => ({
	file, group: 'core', description, defaultEnabled: true, source: null, companionAddon: null, ...extra
});
const optional = (file: string, description: string): PluginInfo => ({
	file, group: 'optional', description, defaultEnabled: false, source: 'codeberg:MarcelineVQ/WeirdUtils', companionAddon: null
});

export const CATALOG: PluginInfo[] = [
	core('ClassicAPI.dll', 'Backports a massive part of the modern WoW API (550+ functions, Lua 5.1 syntax).', { source: 'brues-code/ClassicAPI' }),
	core('nampower.dll', 'Reduces spell input latency and enables spell queueing. Recommended bundles the brues-code build at 99d8d36.', { source: 'brues-code/nampower' }),
	core('ducielperf.dll', 'Improves client performance and adds diagnostics, world markers, and an Interact key. Configure it in game with /dperf.', { source: 'octogit:Hapto/DucielPerf' }),
	core('no1600x1200.dll', 'Removes the hardcoded 1600x1200 resolution limit.', { source: 'https://raw.githubusercontent.com/RetroCro/TurtleWoW-Mods/refs/heads/main/Archive/DLL%20BACKUP/no1600x1200.dll' }),
	core('perf_boost.dll', 'Provides dynamic render distance controls (culling).', { source: 'https://raw.githubusercontent.com/RetroCro/TurtleWoW-Mods/refs/heads/main/Archive/DLL%20BACKUP/perf_boost.dll' }),
	core('SuperWoWhook.dll', 'Injects a massively expanded Lua API. Increases macro limit.', { source: 'balakethelock/SuperWoW' }),
	core('UnitXP_SP3.dll', 'Engine-level optimizations replacing legacy assembly.', { source: 'brues-code/UnitXP_SP3' }),
	core('VanillaHelpers.dll', 'Expands engine limits. Raises the client memory allocator from 2GB to 4GB.', { source: 'isfir/VanillaHelpers' }),
	optional('bigcursor.dll', 'Upscales the hardware cursor for improved visibility on modern resolutions.'),
	optional('customassets.dll', 'Enables loading loose game asset files from the Data/ directory.'),
	optional('logsessions.dll', 'Organizes combat and chat logs into clean, per-character, per-day files automatically.'),
	optional('minimapicons.dll', 'Adds TBC/WotLK-style minimap tracking icons for NPCs and objects.'),
	optional('pngscreenshots.dll', 'Saves screenshots as compressed PNG files to completely eliminate frame drops.'),
	{ ...optional('AuctionQueryThrottle.dll', 'Makes auction-house searches fast'), source: 'brues-code/AuctionQueryThrottle' },
	{ ...optional('Lexara112.dll', 'HD font renderer'), source: 'xnobus/lexara112' },
	{ ...optional('OctoLogin.dll', 'Keeps your login working while OctoWoW moves its servers around'), source: 'fmustafayaman/OctoLogin' }
];
