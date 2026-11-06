# Raid group workload tests — LockPort 3.9.0

The full 3.8.0 suite below still passes with the group filter enabled by default
for all raid groups. Additional tests cover:

- Three warlocks assigned groups 1–2 / 3–4 / 5–6 queue six targets without 123
  requests, and summon each once through the real scheduler and message bus.
- Overlapping selections retain duplicate prevention.
- Requests in unassigned groups stay queued without being summoned.
- Changing assignment during reservation releases and reassigns targets.
- Bulk queueing skips offline players, tolerates repeated clicks without
  duplicate entries, and queues nobody with no groups selected.
- Raid subgroup moves are read from the current roster before casting.
- Unit checks cover default All / None, parties ignoring the raid filter,
  reservation cancellation, actual GetRaidRosterInfo subgroup parsing, direct
  and next-in-line manual casts, and group-picker UI controls.

These are simulated tests. Live UI and multi-client checks are still pending.
The older-version and communication-loss limits below remain applicable.

---

# Coordination test report — LockPort 3.8.0

Tested on 2026-10-27 using independent Lua 5.1 runtimes. Production addon
source retains Lua 5.0-compatible syntax. The game APIs, channel start/stop,
and network transport are simulated; no live WoW clients or server were used.

## Results

The frozen 3.7.8 fixture reproduces the original race: two warlocks both cast
at the same target at 103.3 seconds with 300 ms message latency.

With 3.8.0 on every automatic caster:

- Two and three warlocks divide queued targets in raids and valid five-player
  parties. Party unit indices exclude self and stay within party1..party4.
- 100 randomized three-client runs process 560 requests without a duplicate.
  Forty runs use 50–1400 ms per-message delay and five requests each; sixty
  use 0–1800 ms delay and six requests each. Delays independently reorder messages.
- Delayed ACKs defer casting. Dropped ACKs block casts while peer heartbeats
  continue; delivering messages again restores progress.
- Movement, missing helpers, and missing shards exclude an unready caster.
- Disabling Auto Summon, disconnecting, moving, native rejection, and no-start
  timeout release a reservation for another caster.
- A stale ACK cannot authorize a newer reservation. A release delivered before
  its reserve prevents the old reserve from returning.
- Reloading during reservation performs a fresh handshake.
- A confirmed start holds the target for 130 seconds even when the owner starts
  another target. The hold expires rather than blocking forever.
- An updated manual click respects a received remote reservation.
- A request initially received by one caster is shared and summoned once.
- Outsiders, non-warlocks, malformed/unknown protocol messages, and messages
  from the wrong chat channel do not create reservations.
- Existing chat-mute, cast tracking, UI, request handling, and ClassicAPI
  regression checks continue to pass.

## Older versions

Real frozen addon fixtures, not a rewritten legacy event handler, are used:

- LockPort 3.7.8 from the delivered package.
- Original repository addon from commit c7fe979ddb90f005f727e9bc561d6dd456847f80:
  https://github.com/OEVG2/LockPort/blob/c7fe979ddb90f005f727e9bc561d6dd456847f80/LockPort/LockPort.lua

Both fixtures share add/remove messages in both directions. A received older
manual summon claim prevents the updated automatic client from duplicating it.
This verifies those specific versions and message orders, not every old fork.

## Explicit limits reproduced by the tests

A 3.7.8 automatic caster cannot participate in the new reservation/ACK protocol.
When it and 3.8.0 start together, duplicate casts remain possible. Upgrade all
automatic casters to 3.8.0 for the new coordination.

Total message loss before discovering another automatic caster can also produce
duplicates. Heartbeat expiry permits recovery but cannot prove that an
unreachable client stopped casting. No finite timeout guarantees exclusivity
under arbitrary network partitions. A manual cast made before receiving a
reservation or claim can likewise race with an automatic cast.

These are executable known-limit demonstrations, not claimed passing guarantees.

## Protocol

LPCoord protocol 1 is hidden addon traffic, separate from public chat. Heartbeats
advertise enabled/disabled Auto Summon every 2 seconds. A caster reserves one
target, waits at least 2 seconds, and requires ACKs from discovered enabled peers.
Competing reservations yield by character-name order; losers pick another target.
Reservation leases last 6 seconds and peer heartbeats expire after 8 seconds.
Cast attempts and confirmed starts are separate states. Existing RSAdd, RSRemove,
lp VERSION and LPWhisper messages remain compatible. Chat Off mutes player-facing
messages while retaining synchronization and reservations.

Run from the package/repository root:

    python -m pip install lupa
    python tests/test_addon.py
    python tests/test_coordination.py

## Live check still required

Update two warlocks to 3.8.0, restart/reload the addon, enable Auto Summon on both,
and have two distant group members request summons together. Confirm each is
summoned once, then repeat with one caster moving or turning Auto Summon off.
DLL 1.2.1 is unchanged. This build still needs live multi-warlock validation.
