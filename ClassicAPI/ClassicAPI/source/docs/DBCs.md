# DBC files in vanilla 1.12.1 (`C:\WoW\Octo\WoW.exe`)

Catalogue of every `.dbc` table the client loads. 151 files total, recovered
by binary analysis — each one shows up as a name string in `.rdata`, a
matching path-getter `mov eax, &"<name>"; ret` function in `.text`, and a
20-byte class instance in `.data` whose `{base, count}` fields hold the
loaded record array pointer and record count at runtime.

## How DBCs are wired in the client

Every DBC has the same C++ object shape — a 5-DWORD class instance in `.data`:

```
+0x00  unknown / vtable-ish
+0x04  unknown
+0x08  void *records          ← the 1-based array of record pointers
+0x0C  int   count            ← max ID; 0xFFFFFFFF (-1) means "not loaded"
+0x10  unknown
```

At static-link time these instances live in BSS-style uninitialised `.data`
(zeros / sentinel `-1`). They get populated when the engine loads the DBC
at boot. To read records from any DBC, the standard pattern (also in the
project's [`CLAUDE.md`](../CLAUDE.md)) is:

```cpp
if (id <= 0 || id > *(int*)addrCount) return nullptr;
auto **records = *(SomeRecord *const **)(addrBase);
SomeRecord *rec = records[id];          // may be NULL — check
```

### Per-DBC reset functions

Each DBC has a tiny **reset function** in `.text` that zeroes its instance
and writes `-1` into the count slot (the "unloaded" sentinel). All 151 of
them follow the exact same 32-byte template, which is how this catalogue
was built:

```asm
33 C0                  xor   eax, eax
A3 <inst+0x00>         mov   [inst+0x00], eax
A3 <inst+0x08>         mov   [inst+0x08], eax        ; clear records
A3 <inst+0x04>         mov   [inst+0x04], eax
C7 05 <inst+0x0C> -1   mov   [inst+0x0C], 0xFFFFFFFF ; count = -1
A3 <inst+0x10>         mov   [inst+0x10], eax
C3                     ret
```

The compiler emits one of these for every DBC class. Greping the binary
for the byte template gives back exactly 151 hits — same as the count of
`.dbc` filename strings.

### Per-DBC path-getters

Each DBC also has a one-instruction "what's my filename?" method:

```asm
B8 <strVA>             mov   eax, &"DBFilesClient\Foo.dbc"
C3                     ret
```

Searching for `B8 <strVA> C3` where `<strVA>` is a `.dbc` filename string
also produces exactly 151 hits.

### Pairing names ↔ instance addresses

The path-getters and reset functions are emitted in the **same source
order**. Sort each list by VA and they line up by index — verified against
the four DBCs whose instance addresses were already known
(`Spell.dbc` / `SpellRange.dbc` / `SpellIcon.dbc` / `SpellCastTimes.dbc`,
all four match). That pairing is what builds the full table below.

## Known schemas

Pulled from [`CLAUDE.md`](../CLAUDE.md). Other DBCs follow similar
fixed-stride layouts; deriving each one is a hex-dumping exercise the
caller's interest will dictate.

### `Spell.dbc` record (verified)

| Offset   | Field             | Notes                                          |
|----------|-------------------|------------------------------------------------|
| `+0x18`  | `Attributes`      | u32 flags                                      |
| `+0x1C`  | `AttributesEx`    | u32; bit 6 (`0x40`) = funnel (per schema)      |
| `+0x24`  | `AttributesEx2`   | u32                                            |
| `+0x48`  | `CastingTimeIndex`| → `SpellCastTimes.dbc`                         |
| `+0x7C`  | `PowerType`       | 0=mana, 1=rage, 2=focus, 3=energy, 4=happiness |
| `+0x80`  | `ManaCost`        | base cost                                      |
| `+0x90`  | `RangeIndex`      | → `SpellRange.dbc`                             |
| `+0x1D4` | `SpellIconID`     | → `SpellIcon.dbc`                              |
| `+0x1E0` | `Name[9]`         | 9 locale string ptrs (4 bytes each)            |
| `+0x204` | `Rank[9]`         | 9 locale string ptrs                           |

### Sub-DBC record layouts

- **`SpellIcon.dbc`**: `{ id@+0, char *path@+4 }` — stride 8.
- **`SpellCastTimes.dbc`**: `{ id@+0, baseTimeMS@+4 (i32), perLevelMS@+8 (i32), minTimeMS@+0xC (i32) }` — stride 0x10.
- **`SpellRange.dbc`**: `{ id@+0, minRange@+4 (f32), maxRange@+8 (f32), flags@+0xC, name[9]@+0x10, shortName[9]@+0x34 }` — stride 0x58.

The locale-aware string fields use the global locale index at `0x00C0E080`
(0..8) to pick which of the 9 string slots to read.

## All 151 DBCs

Sorted alphabetically. Each row gives the `.data` instance address (5-DWORD
class), the records-array pointer slot (`+0x08`), the count slot (`+0x0C`),
and the two function VAs (path-getter and reset) you'd point a debugger at
to verify in IDA.

| DBC | Instance | Base (records) | Count | Path-getter | Reset |
|-----|----------|----------------|-------|-------------|-------|
| `AnimationData.dbc` | `0x00C0E068` | `0x00C0E070` | `0x00C0E074` | `0x005738C0` | `0x005388F0` |
| `AreaPOI.dbc` | `0x00C0E054` | `0x00C0E05C` | `0x00C0E060` | `0x00573AB0` | `0x005389B0` |
| `AreaTable.dbc` | `0x00C0E040` | `0x00C0E048` | `0x00C0E04C` | `0x00574040` | `0x00538A70` |
| `AreaTrigger.dbc` | `0x00C0E02C` | `0x00C0E034` | `0x00C0E038` | `0x00574450` | `0x00538B30` |
| `AttackAnimKits.dbc` | `0x00C0E018` | `0x00C0E020` | `0x00C0E024` | `0x00574660` | `0x00538BF0` |
| `AttackAnimTypes.dbc` | `0x00C0E004` | `0x00C0E00C` | `0x00C0E010` | `0x005747D0` | `0x00538CB0` |
| `AuctionHouse.dbc` | `0x00C0DFF0` | `0x00C0DFF8` | `0x00C0DFFC` | `0x005748F0` | `0x00538D60` |
| `BankBagSlotPrices.dbc` | `0x00C0DFDC` | `0x00C0DFE4` | `0x00C0DFE8` | `0x00574BD0` | `0x00538E20` |
| `CameraShakes.dbc` | `0x00C0DFC8` | `0x00C0DFD0` | `0x00C0DFD4` | `0x00574CD0` | `0x00538ED0` |
| `Cfg_Categories.dbc` | `0x00C0DFB4` | `0x00C0DFBC` | `0x00C0DFC0` | `0x00574EA0` | `0x00538F90` |
| `Cfg_Configs.dbc` | `0x00C0DFA0` | `0x00C0DFA8` | `0x00C0DFAC` | `0x00575140` | `0x00539050` |
| `CharacterFacialHairStyles.dbc` | `0x00C0DF28` | `0x00C0DF30` | `0x00C0DF34` | `0x00575A50` | `0x005394C0` |
| `CharBaseInfo.dbc` | `0x00C0DF8C` | `0x00C0DF94` | `0x00C0DF98` | `0x00575280` | `0x00539110` |
| `CharHairGeosets.dbc` | `0x00C0DF78` | `0x00C0DF80` | `0x00C0DF84` | `0x00575380` | `0x005391C0` |
| `CharSections.dbc` | `0x00C0DF64` | `0x00C0DF6C` | `0x00C0DF70` | `0x00575510` | `0x00539280` |
| `CharStartOutfit.dbc` | `0x00C0DF50` | `0x00C0DF58` | `0x00C0DF5C` | `0x00575760` | `0x00539340` |
| `CharVariations.dbc` | `0x00C0DF3C` | `0x00C0DF44` | `0x00C0DF48` | `0x00575930` | `0x00539400` |
| `ChatChannels.dbc` | `0x00C0DF14` | `0x00C0DF1C` | `0x00C0DF20` | `0x00575C00` | `0x00539580` |
| `ChatProfanity.dbc` | `0x00C0DF00` | `0x00C0DF08` | `0x00C0DF0C` | `0x00576050` | `0x00539640` |
| `ChrClasses.dbc` | `0x00C0DEEC` | `0x00C0DEF4` | `0x00C0DEF8` | `0x00576170` | `0x005396F0` |
| `ChrRaces.dbc` | `0x00C0DED8` | `0x00C0DEE0` | `0x00C0DEE4` | `0x005764F0` | `0x005397B0` |
| `CinematicCamera.dbc` | `0x00C0DEC4` | `0x00C0DECC` | `0x00C0DED0` | `0x00576A50` | `0x00539870` |
| `CinematicSequences.dbc` | `0x00C0DEB0` | `0x00C0DEB8` | `0x00C0DEBC` | `0x00576C20` | `0x00539930` |
| `CreatureDisplayInfo.dbc` | `0x00C0DE88` | `0x00C0DE90` | `0x00C0DE94` | `0x00576F70` | `0x00539AB0` |
| `CreatureDisplayInfoExtra.dbc` | `0x00C0DE9C` | `0x00C0DEA4` | `0x00C0DEA8` | `0x00576D40` | `0x005399F0` |
| `CreatureFamily.dbc` | `0x00C0DE74` | `0x00C0DE7C` | `0x00C0DE80` | `0x00577200` | `0x00539B70` |
| `CreatureModelData.dbc` | `0x00C0DE60` | `0x00C0DE68` | `0x00C0DE6C` | `0x00577570` | `0x00539C30` |
| `CreatureSoundData.dbc` | `0x00C0DE4C` | `0x00C0DE54` | `0x00C0DE58` | `0x00577870` | `0x00539CF0` |
| `CreatureSpellData.dbc` | `0x00C0DE38` | `0x00C0DE40` | `0x00C0DE44` | `0x00577C50` | `0x00539DB0` |
| `CreatureType.dbc` | `0x00C0DE24` | `0x00C0DE2C` | `0x00C0DE30` | `0x00577D70` | `0x00539E70` |
| `DeathThudLookups.dbc` | `0x00C0DE10` | `0x00C0DE18` | `0x00C0DE1C` | `0x00578010` | `0x00539F30` |
| `DurabilityCosts.dbc` | `0x00C0DDFC` | `0x00C0DE04` | `0x00C0DE08` | `0x00578180` | `0x00539FF0` |
| `DurabilityQuality.dbc` | `0x00C0DDE8` | `0x00C0DDF0` | `0x00C0DDF4` | `0x005782A0` | `0x0053A0B0` |
| `Emotes.dbc` | `0x00C0DDD4` | `0x00C0DDDC` | `0x00C0DDE0` | `0x005783A0` | `0x0053A160` |
| `EmotesText.dbc` | `0x00C0DD98` | `0x00C0DDA0` | `0x00C0DDA4` | `0x00578960` | `0x0053A3A0` |
| `EmotesTextData.dbc` | `0x00C0DDC0` | `0x00C0DDC8` | `0x00C0DDCC` | `0x00578570` | `0x0053A220` |
| `EmotesTextSound.dbc` | `0x00C0DDAC` | `0x00C0DDB4` | `0x00C0DDB8` | `0x005787F0` | `0x0053A2E0` |
| `EnvironmentalDamage.dbc` | `0x00C0DD84` | `0x00C0DD8C` | `0x00C0DD90` | `0x00578AD0` | `0x0053A460` |
| `Exhaustion.dbc` | `0x00C0DD70` | `0x00C0DD78` | `0x00C0DD7C` | `0x00578BF0` | `0x0053A520` |
| `Faction.dbc` | `0x00C0DD48` | `0x00C0DD50` | `0x00C0DD54` | `0x005791E0` | `0x0053A6A0` |
| `FactionGroup.dbc` | `0x00C0DD5C` | `0x00C0DD64` | `0x00C0DD68` | `0x00578F10` | `0x0053A5E0` |
| `FactionTemplate.dbc` | `0x00C0DD34` | `0x00C0DD3C` | `0x00C0DD40` | `0x005796F0` | `0x0053A760` |
| `FootprintTextures.dbc` | `0x00C0DD20` | `0x00C0DD28` | `0x00C0DD2C` | `0x005798C0` | `0x0053A820` |
| `FootstepTerrainLookup.dbc` | `0x00C0DD0C` | `0x00C0DD14` | `0x00C0DD18` | `0x005799E0` | `0x0053A8D0` |
| `GameObjectArtKit.dbc` | `0x00C0DCF8` | `0x00C0DD00` | `0x00C0DD04` | `0x00579B50` | `0x0053A990` |
| `GameObjectDisplayInfo.dbc` | `0x00C0DCE4` | `0x00C0DCEC` | `0x00C0DCF0` | `0x00579D80` | `0x0053AA50` |
| `GameTips.dbc` | `0x00C0DCD0` | `0x00C0DCD8` | `0x00C0DCDC` | `0x00579ED0` | `0x0053AB10` |
| `GMSurveyCurrentSurvey.dbc` | `0x00C0DCBC` | `0x00C0DCC4` | `0x00C0DCC8` | `0x0057A150` | `0x0053ABD0` |
| `GMSurveyQuestions.dbc` | `0x00C0DCA8` | `0x00C0DCB0` | `0x00C0DCB4` | `0x0057A250` | `0x0053AC80` |
| `GMSurveySurveys.dbc` | `0x00C0DC94` | `0x00C0DC9C` | `0x00C0DCA0` | `0x0057A4D0` | `0x0053AD40` |
| `GMTicketCategory.dbc` | `0x00C0DC80` | `0x00C0DC88` | `0x00C0DC8C` | `0x0057A5D0` | `0x0053AE00` |
| `GroundEffectDoodad.dbc` | `0x00C0DC6C` | `0x00C0DC74` | `0x00C0DC78` | `0x0057A850` | `0x0053AEC0` |
| `GroundEffectTexture.dbc` | `0x00C0DC58` | `0x00C0DC60` | `0x00C0DC64` | `0x0057A9A0` | `0x0053AF80` |
| `HelmetGeosetVisData.dbc` | `0x00C0DC44` | `0x00C0DC4C` | `0x00C0DC50` | `0x0057AAE0` | `0x0053B040` |
| `ItemBagFamily.dbc` | `0x00C0DC30` | `0x00C0DC38` | `0x00C0DC3C` | `0x0057ABE0` | `0x0053B100` |
| `ItemClass.dbc` | `0x00C0DC1C` | `0x00C0DC24` | `0x00C0DC28` | `0x0057AE60` | `0x0053B1C0` |
| `ItemDisplayInfo.dbc` | `0x00C0DC08` | `0x00C0DC10` | `0x00C0DC14` | `0x0057B120` | `0x0053B280` |
| `ItemGroupSounds.dbc` | `0x00C0DBF4` | `0x00C0DBFC` | `0x00C0DC00` | `0x0057B520` | `0x0053B340` |
| `ItemPetFood.dbc` | `0x00C0DBE0` | `0x00C0DBE8` | `0x00C0DBEC` | `0x0057B620` | `0x0053B400` |
| `ItemRandomProperties.dbc` | `0x00C0DBCC` | `0x00C0DBD4` | `0x00C0DBD8` | `0x0057B8A0` | `0x0053B4C0` |
| `ItemSet.dbc` | `0x00C0DBB8` | `0x00C0DBC0` | `0x00C0DBC4` | `0x0057BB70` | `0x0053B580` |
| `ItemSubClass.dbc` | `0x00C0DB90` | `0x00C0DB98` | `0x00C0DB9C` | `0x0057C140` | `0x0053B700` |
| `ItemSubClassMask.dbc` | `0x00C0DBA4` | `0x00C0DBAC` | `0x00C0DBB0` | `0x0057BEA0` | `0x0053B640` |
| `ItemVisualEffects.dbc` | `0x00C0DB7C` | `0x00C0DB84` | `0x00C0DB88` | `0x0057C6B0` | `0x0053B7C0` |
| `ItemVisuals.dbc` | `0x00C0DB68` | `0x00C0DB70` | `0x00C0DB74` | `0x0057C7D0` | `0x0053B870` |
| `Languages.dbc` | `0x00C0DB40` | `0x00C0DB48` | `0x00C0DB4C` | `0x0057CA20` | `0x0053B9F0` |
| `LanguageWords.dbc` | `0x00C0DB54` | `0x00C0DB5C` | `0x00C0DB60` | `0x0057C8D0` | `0x0053B930` |
| `LfgDungeons.dbc` | `0x00C0DB2C` | `0x00C0DB34` | `0x00C0DB38` | `0x0057CCA0` | `0x0053BAB0` |
| `Light.dbc` | `0x00CE9D88` | `0x00CE9D90` | `0x00CE9D94` | `0x005891F0` | `0x006D5D80` |
| `LightFloatBand.dbc` | `0x00C518C8` | `0x00C518D0` | `0x00C518D4` | `0x00588D80` | `0x00641020` |
| `LightIntBand.dbc` | `0x00CE9DB0` | `0x00CE9DB8` | `0x00CE9DBC` | `0x00588EC0` | `0x006D5C10` |
| `LightParams.dbc` | `0x00CE9D9C` | `0x00CE9DA4` | `0x00CE9DA8` | `0x00589000` | `0x006D5CC0` |
| `LightSkybox.dbc` | `0x00CE9D74` | `0x00CE9D7C` | `0x00CE9D80` | `0x005893C0` | `0x006D5E40` |
| `LiquidType.dbc` | `0x00C0DB18` | `0x00C0DB20` | `0x00C0DB24` | `0x0057CFA0` | `0x0053BB70` |
| `LoadingScreens.dbc` | `0x00C0DB04` | `0x00C0DB0C` | `0x00C0DB10` | `0x0057D110` | `0x0053BC30` |
| `LoadingScreenTaxiSplines.dbc` | `0x00C0DAF0` | `0x00C0DAF8` | `0x00C0DAFC` | `0x0057D270` | `0x0053BCF0` |
| `Lock.dbc` | `0x00C0DADC` | `0x00C0DAE4` | `0x00C0DAE8` | `0x0057D3E0` | `0x0053BDB0` |
| `LockType.dbc` | `0x00C0DAC8` | `0x00C0DAD0` | `0x00C0DAD4` | `0x0057D550` | `0x0053BE70` |
| `MailTemplate.dbc` | `0x00C0DAB4` | `0x00C0DABC` | `0x00C0DAC0` | `0x0057DB80` | `0x0053BF30` |
| `Map.dbc` | `0x00C0DAA0` | `0x00C0DAA8` | `0x00C0DAAC` | `0x0057DE00` | `0x0053BFF0` |
| `Material.dbc` | `0x00C0DA8C` | `0x00C0DA94` | `0x00C0DA98` | `0x0057E650` | `0x0053C0B0` |
| `NameGen.dbc` | `0x00C0DA78` | `0x00C0DA80` | `0x00C0DA84` | `0x0057E770` | `0x0053C170` |
| `NamesProfanity.dbc` | `0x00C0DA50` | `0x00C0DA58` | `0x00C0DA5C` | `0x0057E9E0` | `0x0053C2F0` |
| `NamesReserved.dbc` | `0x00C0DA3C` | `0x00C0DA44` | `0x00C0DA48` | `0x0057EB00` | `0x0053C3A0` |
| `NPCSounds.dbc` | `0x00C0DA64` | `0x00C0DA6C` | `0x00C0DA70` | `0x0057E8E0` | `0x0053C230` |
| `Package.dbc` | `0x00C0DA28` | `0x00C0DA30` | `0x00C0DA34` | `0x0057EC20` | `0x0053C450` |
| `PageTextMaterial.dbc` | `0x00C0DA14` | `0x00C0DA1C` | `0x00C0DA20` | `0x0057EEF0` | `0x0053C510` |
| `PaperDollItemFrame.dbc` | `0x00C0DA00` | `0x00C0DA08` | `0x00C0DA0C` | `0x0057F010` | `0x0053C5C0` |
| `PetLoyalty.dbc` | `0x00C0D9EC` | `0x00C0D9F4` | `0x00C0D9F8` | `0x0057F170` | `0x0053C680` |
| `PetPersonality.dbc` | `0x00C0D9D8` | `0x00C0D9E0` | `0x00C0D9E4` | `0x0057F3F0` | `0x0053C740` |
| `QuestInfo.dbc` | `0x00C0D9C4` | `0x00C0D9CC` | `0x00C0D9D0` | `0x0057F6D0` | `0x0053C800` |
| `QuestSort.dbc` | `0x00C0D9B0` | `0x00C0D9B8` | `0x00C0D9BC` | `0x0057F950` | `0x0053C8C0` |
| `Resistances.dbc` | `0x00C0D99C` | `0x00C0D9A4` | `0x00C0D9A8` | `0x0057FBD0` | `0x0053C980` |
| `ServerMessages.dbc` | `0x00C0D988` | `0x00C0D990` | `0x00C0D994` | `0x0057FE90` | `0x0053CA40` |
| `SheatheSoundLookups.dbc` | `0x00C0D974` | `0x00C0D97C` | `0x00C0D980` | `0x00580110` | `0x0053CB00` |
| `SkillCostsData.dbc` | `0x00C0D960` | `0x00C0D968` | `0x00C0D96C` | `0x005802C0` | `0x0053CBC0` |
| `SkillLine.dbc` | `0x00C0D924` | `0x00C0D92C` | `0x00C0D930` | `0x00580910` | `0x0053CE00` |
| `SkillLineAbility.dbc` | `0x00C0D94C` | `0x00C0D954` | `0x00C0D958` | `0x005803E0` | `0x0053CC80` |
| `SkillLineCategory.dbc` | `0x00C0D938` | `0x00C0D940` | `0x00C0D944` | `0x00580670` | `0x0053CD40` |
| `SkillRaceClassInfo.dbc` | `0x00C0D910` | `0x00C0D918` | `0x00C0D91C` | `0x00580D90` | `0x0053CEC0` |
| `SkillTiers.dbc` | `0x00C0D8FC` | `0x00C0D904` | `0x00C0D908` | `0x00580F60` | `0x0053CF80` |
| `SoundAmbience.dbc` | `0x00C0D8E8` | `0x00C0D8F0` | `0x00C0D8F4` | `0x00581080` | `0x0053D040` |
| `SoundEntries.dbc` | `0x00C0D8D4` | `0x00C0D8DC` | `0x00C0D8E0` | `0x00581180` | `0x0053D100` |
| `SoundProviderPreferences.dbc` | `0x00C0D8C0` | `0x00C0D8C8` | `0x00C0D8CC` | `0x00581570` | `0x0053D1C0` |
| `SoundSamplePreferences.dbc` | `0x00C0D8AC` | `0x00C0D8B4` | `0x00C0D8B8` | `0x00581970` | `0x0053D280` |
| `SoundWaterType.dbc` | `0x00C0D898` | `0x00C0D8A0` | `0x00C0D8A4` | `0x00581C60` | `0x0053D340` |
| `SpamMessages.dbc` | `0x00C0D884` | `0x00C0D88C` | `0x00C0D890` | `0x00581DA0` | `0x0053D400` |
| `Spell.dbc` | `0x00C0D780` | `0x00C0D788` | `0x00C0D78C` | `0x00583720` | `0x0053DD90` |
| `SpellCastTimes.dbc` | `0x00C0D870` | `0x00C0D878` | `0x00C0D87C` | `0x00581EC0` | `0x0053D4B0` |
| `SpellCategory.dbc` | `0x00C0D85C` | `0x00C0D864` | `0x00C0D868` | `0x00582000` | `0x0053D570` |
| `SpellChainEffects.dbc` | `0x00C0D848` | `0x00C0D850` | `0x00C0D854` | `0x00582100` | `0x0053D620` |
| `SpellDispelType.dbc` | `0x00C0D834` | `0x00C0D83C` | `0x00C0D840` | `0x005822F0` | `0x0053D6E0` |
| `SpellDuration.dbc` | `0x00C0D820` | `0x00C0D828` | `0x00C0D82C` | `0x005825C0` | `0x0053D7A0` |
| `SpellEffectCameraShakes.dbc` | `0x00C0D80C` | `0x00C0D814` | `0x00C0D818` | `0x00582700` | `0x0053D860` |
| `SpellFocusObject.dbc` | `0x00C0D7F8` | `0x00C0D800` | `0x00C0D804` | `0x00582800` | `0x0053D920` |
| `SpellIcon.dbc` | `0x00C0D7E4` | `0x00C0D7EC` | `0x00C0D7F0` | `0x00582A80` | `0x0053D9E0` |
| `SpellItemEnchantment.dbc` | `0x00C0D7D0` | `0x00C0D7D8` | `0x00C0D7DC` | `0x00582BA0` | `0x0053DA90` |
| `SpellMechanic.dbc` | `0x00C0D7BC` | `0x00C0D7C4` | `0x00C0D7C8` | `0x00582EE0` | `0x0053DB50` |
| `SpellRadius.dbc` | `0x00C0D7A8` | `0x00C0D7B0` | `0x00C0D7B4` | `0x00583160` | `0x0053DC10` |
| `SpellRange.dbc` | `0x00C0D794` | `0x00C0D79C` | `0x00C0D7A0` | `0x005832A0` | `0x0053DCD0` |
| `SpellShapeshiftForm.dbc` | `0x00C0D76C` | `0x00C0D774` | `0x00C0D778` | `0x00584CB0` | `0x0053DE50` |
| `SpellVisual.dbc` | `0x00C0D730` | `0x00C0D738` | `0x00C0D73C` | `0x00585460` | `0x0053E090` |
| `SpellVisualEffectName.dbc` | `0x00C0D758` | `0x00C0D760` | `0x00C0D764` | `0x00584FB0` | `0x0053DF10` |
| `SpellVisualKit.dbc` | `0x00C0D744` | `0x00C0D74C` | `0x00C0D750` | `0x00585150` | `0x0053DFD0` |
| `StableSlotPrices.dbc` | `0x00C0D71C` | `0x00C0D724` | `0x00C0D728` | `0x00585730` | `0x0053E150` |
| `Startup_Strings.dbc` | `0x008824FC` | `0x00882504` | `0x00882508` | `0x004567F0` | `0x00401200` |
| `Stationery.dbc` | `0x00C0D708` | `0x00C0D710` | `0x00C0D714` | `0x00585830` | `0x0053E200` |
| `StringLookups.dbc` | `0x00C0D6F4` | `0x00C0D6FC` | `0x00C0D700` | `0x005859A0` | `0x0053E2C0` |
| `Talent.dbc` | `0x00C0D6E0` | `0x00C0D6E8` | `0x00C0D6EC` | `0x00585AC0` | `0x0053E370` |
| `TalentTab.dbc` | `0x00C0D6CC` | `0x00C0D6D4` | `0x00C0D6D8` | `0x00585CB0` | `0x0053E430` |
| `TaxiNodes.dbc` | `0x00C0D6B8` | `0x00C0D6C0` | `0x00C0D6C4` | `0x00585FE0` | `0x0053E4F0` |
| `TaxiPath.dbc` | `0x00C0D690` | `0x00C0D698` | `0x00C0D69C` | `0x005864F0` | `0x0053E670` |
| `TaxiPathNode.dbc` | `0x00C0D6A4` | `0x00C0D6AC` | `0x00C0D6B0` | `0x00586300` | `0x0053E5B0` |
| `TerrainType.dbc` | `0x00C0D67C` | `0x00C0D684` | `0x00C0D688` | `0x00586630` | `0x0053E730` |
| `TerrainTypeSounds.dbc` | `0x00C0D668` | `0x00C0D670` | `0x00C0D674` | `0x005867E0` | `0x0053E7F0` |
| `TransportAnimation.dbc` | `0x00C0D654` | `0x00C0D65C` | `0x00C0D660` | `0x005868C0` | `0x0053E8A0` |
| `UISoundLookups.dbc` | `0x00C0D640` | `0x00C0D648` | `0x00C0D64C` | `0x00586A70` | `0x0053E960` |
| `UnitBlood.dbc` | `0x00C0D618` | `0x00C0D620` | `0x00C0D624` | `0x00586CC0` | `0x0053EAE0` |
| `UnitBloodLevels.dbc` | `0x00C0D62C` | `0x00C0D634` | `0x00C0D638` | `0x00586BC0` | `0x0053EA20` |
| `VideoHardware.dbc` | `0x00CE9D60` | `0x00CE9D68` | `0x00CE9D6C` | `0x00689A70` | `0x006D5F00` |
| `VocalUISounds.dbc` | `0x00C0D604` | `0x00C0D60C` | `0x00C0D610` | `0x00586EE0` | `0x0053EBA0` |
| `WeaponImpactSounds.dbc` | `0x00C0D5DC` | `0x00C0D5E4` | `0x00C0D5E8` | `0x00587420` | `0x0053ED20` |
| `WeaponSwingSounds2.dbc` | `0x00C0D5C8` | `0x00C0D5D0` | `0x00C0D5D4` | `0x00587590` | `0x0053EDE0` |
| `WMOAreaTable.dbc` | `0x00C0D5F0` | `0x00C0D5F8` | `0x00C0D5FC` | `0x00587050` | `0x0053EC60` |
| `WorldMapArea.dbc` | `0x00C0D5B4` | `0x00C0D5BC` | `0x00C0D5C0` | `0x005876D0` | `0x0053EEA0` |
| `WorldMapContinent.dbc` | `0x00C0D5A0` | `0x00C0D5A8` | `0x00C0D5AC` | `0x005878C0` | `0x0053EF60` |
| `WorldMapOverlay.dbc` | `0x00C0D58C` | `0x00C0D594` | `0x00C0D598` | `0x00587B30` | `0x0053F020` |
| `WorldSafeLocs.dbc` | `0x00C0D578` | `0x00C0D580` | `0x00C0D584` | `0x00587DE0` | `0x0053F0E0` |
| `WorldStateUI.dbc` | `0x00C0D564` | `0x00C0D56C` | `0x00C0D570` | `0x005880E0` | `0x0053F1A0` |
| `ZoneIntroMusicTable.dbc` | `0x00C0D550` | `0x00C0D558` | `0x00C0D55C` | `0x00588880` | `0x0053F260` |
| `ZoneMusic.dbc` | `0x00C0D53C` | `0x00C0D544` | `0x00C0D548` | `0x00588A10` | `0x0053F320` |

## Reading records from any DBC

Given the table above, this is enough to read records from any DBC. Example
for a hypothetical `Foo.dbc`:

```cpp
constexpr uintptr_t addrFooBase  = 0x00????????;   // from the table
constexpr uintptr_t addrFooCount = 0x00????????;

FooRecord* GetFoo(int id) {
    int count = *(int*)addrFooCount;
    if (id <= 0 || id > count) return nullptr;
    auto **records = *(FooRecord *const **)addrFooBase;
    return records[id];                       // may be NULL — check
}
```

The record stride and field layout still need to be derived per DBC. Two
working approaches:

1. **DBC header at runtime** — a loaded DBC is `WDBC` magic + 5×u32 header
   (signature, recordCount, fieldCount, recordSize, stringBlockSize) followed
   by `recordCount * recordSize` bytes. Patch a hook into the loader and
   read the header. The `recordSize` tells you the stride immediately.
2. **Cross-reference an accessor** — find a function that calls a known
   helper to look up a record (pattern `cmp eax, [count]; jae err; mov edx,
   [records]; mov eax, [edx + eax*4]`) and follow the field offsets it
   reads. The Spell schema in this doc was built that way.

## Cross-references inside the client

`Spell.dbc` is the densest reader: 1 write (the reset, zeroing) and 242
reads of `0xC0D788` from across the binary. The DBC slot is the universal
"give me records" handle; once it's set up, the rest of the engine just
indirects through it.

The accessor helpers near `0x006E33xx` (`SpellInfo_GetCostByLevel` ~
`0x006E3320`, `SpellInfo_GetCastTime` ~ `0x006E3340`, `SpellInfo_GetRange`
~ `0x006E3510`) are the canonical sites if you need to mirror the engine's
own level-scaling math when reading those DBCs.

## Methodology, for whoever has to redo this

1. Grep `.rdata` for any string ending in `.dbc\0`. → 151 strings.
2. Grep `.text` for the byte template `B8 <strVA> C3` against each filename
   VA. → 151 path-getters.
3. Grep `.text` for the 32-byte reset template
   `33 C0 A3 _ A3 _ A3 _ C7 05 _ FF FF FF FF A3 _ C3`. → 151 resets, each
   yielding the 5 instance field VAs (and so the records-array slot
   `[+0x08]` and count slot `[+0x0C]`).
4. Sort getters by VA and resets by VA, pair by index. Source-order
   emission means index `i` of the path-getter list corresponds to index
   `i` of the reset list (verified against four known DBCs).

