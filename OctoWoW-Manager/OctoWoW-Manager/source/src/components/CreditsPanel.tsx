import { openUrl } from '@tauri-apps/plugin-opener';
import { ArrowUpRight, ScrollText } from 'lucide-react';
import { cn, Panel } from './ui';

export type Credit = [name: string, mod: string | null, addon?: string | null];

const LinkChip = ({ url, label, tone }: { url: string; label: string; tone: 'accent' | 'success' }) => (
	<button
		onClick={() => openUrl(url)}
		className={cn('inline-flex h-6 items-center gap-0.5 rounded-md bg-white/[0.05] px-2 text-[11px] font-semibold hover:bg-white/[0.1]', tone === 'accent' ? 'text-violet-300' : 'text-green-400')}
	>
		{label}
		<ArrowUpRight size={11} />
	</button>
);

export const CreditsPanel = ({ credits, description, linkLabel = 'Mod' }: { credits: readonly Credit[]; description: string; linkLabel?: string }) => (
	<Panel icon={ScrollText} title="Open-Source Credits & Sources" description={description}>
		<div className="grid grid-cols-3 gap-2 p-4">
			{credits.map(([name, mod, addon]) => (
				<div key={name} className="rounded-lg border border-line bg-white/[0.02] px-3 py-2.5">
					<div className="text-[13px] font-medium">{name}</div>
					<div className="mt-1.5 flex gap-1.5">
						{mod && <LinkChip url={mod} label={linkLabel} tone="accent" />}
						{addon && <LinkChip url={addon} label="Addon" tone="success" />}
						{!mod && !addon && <span className="text-[11px] text-subtle italic">Legacy engine file</span>}
					</div>
				</div>
			))}
		</div>
	</Panel>
);
