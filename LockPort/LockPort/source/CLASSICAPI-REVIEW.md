# ClassicAPI 1.17.6 follow-up

Compared tagged v1.17.1 with v1.17.6. LockPort 3.7.5 optionally uses the new
GetCurrentChatEvent() for summon-request message and sender values. The reader
is feature-detected, protected with pcall, and falls back to snapshotted legacy
arguments if unavailable, empty, or failing. It is used only in the supported
request-chat event branch; spell and addon-sync events keep their original paths.
Roster membership remains mandatory. The DLL stays at 1.2.1.

Regression coverage includes overwritten globals, legacy fallback, reader errors,
non-trigger payloads, nested spell events, and addon synchronization.

The new profiling APIs are useful for developer diagnostics, but are not enabled
or queried automatically. The modifier-key fix benefits Lua bindings upstream.
Player-cache improvements are unnecessary for the current group roster logic.

Sources:
- https://github.com/brues-code/ClassicAPI/releases/tag/v1.17.6
- https://github.com/brues-code/ClassicAPI/compare/v1.17.1...v1.17.6
- https://github.com/brues-code/ClassicAPI/blob/v1.17.6/docs/API.md#getcurrentchatevent

---

# ClassicAPI 1.17.1 review

Reviewed the tagged 1.17.1 API documentation, release, and source comparison
against 1.16.0, rather than assuming the current default branch matches the release.

## What changed

The 1.17.1 patch itself replaces the Cooldown frame's Model-based indicator with
native cooldown drawing (sweep, flash, reverse, and edge behavior). LockPort has
no cooldown-sweep UI, so this patch offers no direct summon fix.

The broader 1.16.0 -> 1.17.1 comparison includes corrected spell-failure events:
UNIT_SPELLCAST_INTERRUPTED versus UNIT_SPELLCAST_FAILED follows the engine's
failure reason, with improved cast identity and stop handling.
These are useful for a future event-tracking revision, but a successful ritual
spell event still needs interpretation: starting/completing the portal and the
target actually arriving are different stages. This build keeps the conservative
arrival/uncertain-completion fix rather than mixing another event stream into it.

## Useful APIs used in this build

Verified present in 1.17.1:
- GetUnitSpeed("player"): pause automatic summons while moving.
- C_Spell.UnitCastingInfo("player"): pause while another regular cast is active.
- C_Spell.UnitChannelInfo("player"): pause while another channel is active.

These are optional, feature-detected improvements. Their presence in 1.17.1 does
not mean they were newly introduced in 1.17.1. LockPort continues to work without
ClassicAPI, using its existing cast-event tracking.
UnitXP already supplies accurate distance information in your setup, so another
distance provider would add little value.

## Primary sources

- Release: https://github.com/brues-code/ClassicAPI/releases/tag/v1.17.1
- Exact patch: https://github.com/brues-code/ClassicAPI/compare/v1.17.0...v1.17.1
- Since 1.16.0: https://github.com/brues-code/ClassicAPI/compare/v1.16.0...v1.17.1
- Tagged API reference: https://github.com/brues-code/ClassicAPI/blob/v1.17.1/docs/API.md
- Spell-event correction: https://github.com/brues-code/ClassicAPI/commit/ff57450b7c7fc6b4ae9d3d8a58d51f654ccd1bd4
- Native function ABI/offset reference: https://github.com/brues-code/nampower/blob/main/nampower/main.hpp
- Native offset reference: https://github.com/brues-code/nampower/blob/main/nampower/offsets.hpp
