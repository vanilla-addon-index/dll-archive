# Turtle WoW Script API additions — `C:\WoW\Octo\WoW.exe`

Lua globals registered by this Turtle build that are **not** present in
vanilla 1.12.1. Same extraction methodology as
[`BlizzardScriptAPI.md`](BlizzardScriptAPI.md) — these functions sit in two
extra `{name, func}` batches in `.data` that get walked by the same loop
pattern at startup.

These are likely Turtle additions (no vendor name is encoded in the binary),
flagged by the function-name set:

* The lottery batch references a vendor / drawing / past-results system that
  has no analog in retail vanilla.
* The minigame batch is a 3-function "type / move / state" surface, also not
  in vanilla.

## Lottery `[table 0x008481B8 — registered @ 0x004C473F]` — 12

```
  0: 0x004C4210  CloseLottery
  1: 0x004C4220  GetLastLotteryNumbers
  2: 0x004C4290  SubmitNumbers
  3: 0x004C43D0  IsVendorActive
  4: 0x004C4400  BuyRandomPicks
  5: 0x004C44B0  GetNumLotteryPrizes
  6: 0x004C44E0  GetLotteryPrizeInfo
  7: 0x004C45D0  GetJackpotAmount
  8: 0x004C45F0  GetMoneyPrizes
  9: 0x004C4630  GetNextDrawTime
 10: 0x004C4660  GetNumPastDrawResults
 11: 0x004C4690  GetPastDrawResult
```

## Minigame `[table 0x0084838C — registered @ 0x004C4E1F]` — 3

```
  0: 0x004C4D50  GetMinigameType
  1: 0x004C4D80  MakeMinigameMove
  2: 0x004C4DF0  GetMinigameState
```

## Notes

* Both batches register from the same code region (`0x004C4xxx`), strongly
  suggesting they were added together by the same patcher.
* No matching frame method tables — these are pure Lua globals.
* If you're writing an addon meant to run on retail vanilla / other private
  servers, do not depend on these. Otherwise they're called the same way as
  any other engine global.
