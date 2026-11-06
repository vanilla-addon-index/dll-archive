import sys
from pathlib import Path
sys.path.insert(0, str(Path("work/python-deps").resolve()))
from lupa.lua51 import LuaRuntime
PACKAGE=Path(__file__).resolve().parent.parent
core=(PACKAGE/"LockPort.lua").read_text(encoding="utf-8")
setup=r'''
now=100; raidSize=5; partySize=0; moving=0; casting=nil; nativeOK=true
function GetTime() return now end
function GetRaidRosterInfo() return nil end
function GetNumRaidMembers() return raidSize end
function GetNumPartyMembers() return partySize end
function GetLockPortVersion() return "1.2.1" end
function LockPortNativeSummon(unit) nativeCalls=(nativeCalls or 0)+1; lastUnit=unit; return nativeOK end
function GetUnitSpeed() return moving end
function UnitName(u) if u=="player" then return "Tester" end return "Bob" end
function UnitClass() return "Warlock","WARLOCK" end
function UnitAffectingCombat() return false end
function UnitIsConnected() return true end
function UnitIsDeadOrGhost() return false end
function CreateFrame() return {RegisterEvent=function() end, SetScript=function() end} end
function SendAddonMessage() end
function SendChatMessage() end
function GetZoneText() return "Test" end
function GetSubZoneText() return "" end
function TargetUnit() end
function CastSpellByName() manualCalls=(manualCalls or 0)+1 end
C_Spell={UnitCastingInfo=function() return casting end,UnitChannelInfo=function() return nil end}
SlashCmdList={}
LockPortOptions={announceOpen=false,askHelpers=false,autoRemove=true}
'''
def env():
    L=LuaRuntime()
    L.execute(setup); L.execute(core)
    L.execute(r'''
LP=LockPort; LP.mods={}
LP.Print=function(self,text) lastPrint=text end
LP.RefreshOptions=function() end; LP.UpdateUI=function() end
LP.OpenAnnounce=function() openCalls=(openCalls or 0)+1 end
LP.ReadyState=function() return true end
LP.NextCandidate=function() if LP.autoRetryAfter and LP.autoRetryAfter.Bob and now<LP.autoRetryAfter.Bob then return nil end;return {name="Bob"} end
LP.Summon=function(self,name,automatic) casts=(casts or 0)+1; wasAutomatic=automatic end
''')
    return L
def check(name,script):
    L=env(); L.execute(script); print("PASS",name)
check("off without native DLL",r'''GetLockPortVersion=nil; LP:SetRaidAutoSummon(true); assert(not LP.raidAutoSummon)''')
check("requires group",r'''raidSize=0; LP:SetRaidAutoSummon(true); assert(not LP.raidAutoSummon)''')
check("enables open announcements",r'''LP:SetRaidAutoSummon(true); assert(LP.raidAutoSummon and LockPortOptions.announceOpen and openCalls==1)''')
check("auto starts without input after settling",r'''LP:SetRaidAutoSummon(true); LP:CheckRaidAutoSummon(100); LP:CheckRaidAutoSummon(101); assert(not casts); LP:CheckRaidAutoSummon(102); assert(casts==1 and wasAutomatic)''')
check("no duplicate or immediate uncertain retry",r'''LP:SetRaidAutoSummon(true); LP:CheckRaidAutoSummon(100); now=102;LP:CheckRaidAutoSummon(now); now=103;LP:CheckRaidAutoSummon(now);now=106;LP:CheckRaidAutoSummon(now); assert(casts==1)''')
check("movement pauses auto casting",r'''LP:SetRaidAutoSummon(true);moving=7; LP:CheckRaidAutoSummon(100);LP:CheckRaidAutoSummon(110);assert(not casts)''')
check("live ClassicAPI casting pauses auto casting",r'''LP:SetRaidAutoSummon(true);casting="Shadow Bolt"; LP:CheckRaidAutoSummon(100);LP:CheckRaidAutoSummon(110);assert(not casts)''')
check("works without ClassicAPI",r'''GetUnitSpeed=nil;C_Spell=nil;LP:SetRaidAutoSummon(true); LP:CheckRaidAutoSummon(100); LP:CheckRaidAutoSummon(102);assert(casts==1)''')
check("not ready pauses auto casting",r'''LP.ReadyState=function() return false end;LP:SetRaidAutoSummon(true);LP:CheckRaidAutoSummon(100);LP:CheckRaidAutoSummon(102);assert(not casts)''')
check("leaving raid disables and restores announcements",r'''LP:SetRaidAutoSummon(true);raidSize=0;LP.CheckRaidAutoSummon(LP,101);assert(not LP.raidAutoSummon and not LockPortOptions.announceOpen)''')
check("disabling auto always disables announcements",r'''LockPortOptions.announceOpen=true;LP:SetRaidAutoSummon(true);LP:SetRaidAutoSummon(false);assert(not LockPortOptions.announceOpen)''')
check("native disappearance disables",r'''LP:SetRaidAutoSummon(true);LockPortNativeSummon=nil;LP:CheckRaidAutoSummon(101);assert(not LP.raidAutoSummon)''')
# Test actual FinishPending and arrival watcher, with mocked game state.
for arrived in (True,False):
    L=env()
    L.execute(r'''
LP.pending={name="Bob",unit="raid2",started=true,interrupted=true}
LP.ScanRoster=function() return {Bob={unit="raid3"}} end
LP.IsNearby=function() return '''+("true" if arrived else "false")+r''' end
LP.RemoveRequest=function() removed=true end
LP.AddRequest=function() requeued=true end
LP.Fail=function() failureAnnouncements=(failureAnnouncements or 0)+1 end
LP:FinishPending()
assert(not failureAnnouncements)
assert(not LP.failCount.Bob)
''')
    L.execute('assert(removed)' if arrived else 'assert(requeued and LP.watch.unconfirmed)')
    print("PASS interruption with "+("arrival" if arrived else "unconfirmed completion"))
# Real Summon path: native attempt, manual fallback, and native rejection.
for native in (True,False):
    L=env();L.execute(core)
    L.execute(r'''
LP=LockPort;LP.Print=function() end;LP.UpdateUI=function() end
LP.IsWarlock=function() return true end;LP.KnowsRitual=function() return true end
LP.ScanRoster=function() return {Bob={unit="raid2"}} end
LP.TargetProblem=function() return nil end;LP.CountShards=function() return 5 end
LP.CountHelpers=function() return 2 end;LP.SendAddon=function() end
LP:Summon("Bob",'''+("true" if native else "false")+r''')
assert(LP.pending.name=="Bob")
''')
    L.execute('assert(nativeCalls==1 and not manualCalls)' if native else 'assert(manualCalls==1 and not nativeCalls)')
    print("PASS "+("automatic native spellbook" if native else "manual")+" Summon dispatch")
# All delivered Lua files parse with a Lua 5.1 runtime; source uses Lua 5.0 syntax.
L=LuaRuntime()
for p in PACKAGE.glob("*.lua"):
    L.execute('assert(loadstring(...))',p.read_text(encoding="utf-8"))
    print("PASS syntax",p.name)

# Build UI with lightweight frame mocks to check control placement and gating.
L=env()
L.execute(r'''
StaticPopupDialogs={};UISpecialFrames={};RAID_CLASS_COLORS={}
frames={}
local methods={}
function methods:GetName() return self.name end
function methods:SetText(v) self.text=v end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:Hide() self.visible=false end
function methods:Show() self.visible=true end
function methods:IsVisible() return self.visible end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:SetChecked(v) self.checked=v end
function methods:GetChecked() return self.checked end
local function frame(name)
 local f={name=name,scripts={},visible=true,enabled=true}
 setmetatable(f,{__index=function(t,k) return methods[k] or function() end end})
 if name then _G[name]=f;frames[name]=f end
 return f
end
function methods:CreateTexture(name) return frame(name) end
function methods:CreateFontString(name) return frame(name) end
function CreateFrame(kind,name) return frame(name) end
function getglobal(name) return _G[name] end
function GetBindingKey() return nil end
function PlaySound() end
LP.RefreshOptions=function() end
LP.ScanRoster=function() return {} end
LP.SortedRequests=function() return {} end
LP.CountShards=function() return 5 end
LP.InGroup=function() return raidSize>0 or partySize>0 end
LP.CountHelpers=function() return 2 end
LockPortOptions.theme="classic"
''')
L.execute((PACKAGE/"LockPort_UI.lua").read_text(encoding="utf-8"))
L.execute(r'''
LP:CreateUI()
LockPortFrame:Show();LP:RefreshList()
assert(LockPortFrame.raidAuto.visible)
assert(LockPortFrame.raidAuto.width==95 and LockPortFrame.groupSummon.width==95)
assert(LockPortFrame.groupSummon.visible and LockPortFrame.groupSummon.point[2]==LockPortFrame.raidAuto)
LP:ToggleGroups();assert(LockPortGroupsFrame.visible)
this=LockPortGroupsNone;this.scripts.OnClick();assert(LockPortOptions.summonGroups and not next(LockPortOptions.summonGroups))
this=LockPortGroupsFrame.groups[3];this.scripts.OnClick();assert(LockPortOptions.summonGroups[3])
this=LockPortGroupsAll;this.scripts.OnClick();assert(not LockPortOptions.summonGroups)
assert(LockPortFrame.summon.width==95 and LockPortFrame.chatToggle.width==95)
this=LockPortFrame.chatToggle;this.scripts.OnClick();assert(LockPortOptions.chatMuted)
LP:RefreshList();assert(string.find(this.text,"Off"))
this.scripts.OnClick();assert(not LockPortOptions.chatMuted)
local nativeHeight=LockPortFrame.height
assert(LockPortFrame.raidAuto.point[1]=="TOPLEFT")
assert(LockPortFrame.raidAuto.point[3]=="BOTTOMLEFT" and LockPortFrame.raidAuto.point[5]==-2)
GetLockPortVersion=nil;LP:RefreshList()
assert(not LockPortFrame.raidAuto.visible and LockPortFrame.groupSummon.visible and LockPortFrame.height==nativeHeight)
GetLockPortVersion=function() return "1.2.1" end;raidSize=0;LP:RefreshList()
assert(LockPortFrame.raidAuto.visible and not LockPortFrame.raidAuto.enabled)
assert(LockPortFrame.groupSummon.visible and not LockPortFrame.groupSummon.enabled and not LockPortGroupsFrame.visible)
partySize=3;LP:RefreshList();assert(LockPortFrame.groupSummon.visible and not LockPortFrame.groupSummon.enabled)
GetLockPortVersion=nil;LP:RefreshList();assert(LockPortFrame.groupSummon.visible and not LockPortFrame.groupSummon.enabled and LockPortFrame.height==nativeHeight)
GetLockPortVersion=function() return "1.2.1" end;partySize=0
raidSize=5;LP:RefreshList();assert(LockPortFrame.raidAuto.enabled and LockPortFrame.groupSummon.enabled)
this=LockPortFrame.raidAuto;this.checked=true
this.scripts.OnClick()
assert(LP.raidAutoSummon and LockPortOptions.announceOpen)
''')
print("PASS UI native-only visibility, expanded layout, raid gating, and button toggle")

check("party enables automatic casting",r'''raidSize=0;partySize=3;LP:SetRaidAutoSummon(true);assert(LP.raidAutoSummon and LockPortOptions.announceOpen);LP:CheckRaidAutoSummon(100);LP:CheckRaidAutoSummon(102);assert(casts==1 and wasAutomatic)''')
check("raid to party conversion stays enabled",r'''LP:SetRaidAutoSummon(true);raidSize=0;partySize=3;LP:CheckRaidAutoSummon(100);assert(LP.raidAutoSummon);LP:CheckRaidAutoSummon(102);assert(casts==1)''')
check("leaving party disables and restores announcements",r'''raidSize=0;partySize=3;LP:SetRaidAutoSummon(true);partySize=0;LP:CheckRaidAutoSummon(101);assert(not LP.raidAutoSummon and not LockPortOptions.announceOpen)''')
check("old raid-only DLL is rejected",r'''GetLockPortVersion=function() return "1.0.0" end;assert(not LP:HasNativeMod());LP:SetRaidAutoSummon(true);assert(not LP.raidAutoSummon)''')

check("live idle clears stale busy flag",r'''LP.castBusy=true;LP:RecoverCastTracking(100);assert(not LP.castBusy)''')
check("missing stop event releases pending summon conservatively",r'''LP.pending={name="Bob",unit="party1",t=90,started=true};LP.FinishPending=function(self) assert(self.pending.interrupted);self.pending.done=true end;LP:RecoverCastTracking(100);assert(not LP.pending.done);LP:RecoverCastTracking(102);assert(LP.pending.done)''')
check("active channel is never cleared by recovery",r'''C_Spell.UnitChannelInfo=function() return "Ritual of Summoning" end;LP.pending={name="Bob",t=90,started=true};LP:RecoverCastTracking(100);LP:RecoverCastTracking(105);assert(not LP.pending.done and LP.castBusy)''')
check("unknown live state preserves tracking",r'''C_Spell=nil;LP.castBusy=true;LP.pending={name="Bob",t=90,started=true};LP:RecoverCastTracking(100);LP:RecoverCastTracking(105);assert(not LP.pending.done and LP.castBusy)''')
check("brief idle gap during casting is tolerated",r'''LP.pending={name="Bob",t=90,started=true};LP:RecoverCastTracking(100);casting="Ritual of Summoning";LP:RecoverCastTracking(101);assert(not LP.pending.inactiveSince and not LP.pending.done)''')

# Exercise the real scheduler, candidate checks, Summon, and start-event handler together.
for unit in ("party2", "raid2"):
    L=env();L.execute(core)
    L.execute(r'''
LP=LockPort
raidSize='''+("0" if unit.startswith("party") else "5")+r''';partySize=3
LP.Print=function() end;LP.UpdateUI=function() end;LP.RefreshOptions=function() end
LP.OpenAnnounce=function() end;LP.SendAddon=function() end
LP.KnowsRitual=function() return true end
LP.CountShards=function() return 5 end;LP.CountHelpers=function() return 2 end
LP.TargetProblem=function() return nil end
LP.roster={Bob={unit="'''+unit+r'''",online=true}}
LP.ScanRoster=function(self) return self.roster end
LP.SortedRequests=function(self) return {{name="Bob",info=self.roster.Bob}} end
LP.requests={{name="Bob",t=90}}
LockPortNativeSummon=function(unit) actualCasts=actualCasts+1;arg1=LP.SPELL;LP:OnEvent("SPELLCAST_START");return true,"spellbook request sent" end
actualCasts=0
CastSpellByName=function(name)
 actualCasts=actualCasts+1;arg1=name;LP:OnEvent("SPELLCAST_START")
end
LP:SetRaidAutoSummon(true)
LP:CheckRaidAutoSummon(100)
now=102;LP:CheckRaidAutoSummon(now)
assert(actualCasts==1 and LP.pending.started and LP.pending.automatic)
assert(not LP.requests[1] and #LP.autoTrace>0)
''')
    print("PASS integrated automatic "+unit+" cast receives start event")

check("off clears announcements even when already off",r'''LP.raidAutoSummon=false;LockPortOptions.announceOpen=true;LP:SetRaidAutoSummon(false);assert(not LP.raidAutoSummon and not LockPortOptions.announceOpen)''')
# Simulate SavedVariables surviving a reload while addon runtime state is recreated.
for enabled_by_auto in (True, False):
    before=env()
    if enabled_by_auto:
        before.execute("LP:SetRaidAutoSummon(true)")
    else:
        before.execute("LockPortOptions.announceOpen=true")
    after=env()
    after.globals().LockPortOptions.announceOpen=before.globals().LockPortOptions.announceOpen
    after.execute(r'''
    LP.DetectMods=function(self) self.mods={} end
    LP.CreateUI=function() end
    GetAddOnMetadata=function() return "test" end
    LP:Initialize()
    assert(not LP.raidAutoSummon and not LockPortOptions.announceOpen)
    sent=0;SendChatMessage=function() sent=sent+1 end
    ''')
    # env overrides OpenAnnounce; restore the production method before exercising its timer gate.
    after.execute(core)
    after.execute("LockPort:OpenAnnounce(1000); assert(sent==0)")
    print("PASS reload clears announcements", "auto" if enabled_by_auto else "manual")

# Chat dispatch uses stable message/sender values and never replays an outer chat
# event while handling a nested spell or addon-sync event.
def chat_check(name, reader, globals_text="123", globals_sender="Bob"):
    L=env()
    L.globals().arg1=globals_text; L.globals().arg2=globals_sender
    L.execute(r'''
    LP.MatchesTrigger=function(self,text) return text=="123" end
    LP.ScanRoster=function() arg1="clobbered";arg2="Wrong";return {Bob={unit="raid2"}} end
    LP.OnTrigger=function(self,name,info,event) triggered=(triggered or 0)+1;assert(name=="Bob" and info.unit=="raid2");triggerEvent=event end
    ''')
    L.execute(reader)
    L.execute('LP:OnEvent("CHAT_MSG_RAID");assert(triggered==1 and triggerEvent=="CHAT_MSG_RAID")')
    print("PASS",name)
chat_check("ClassicAPI chat payload survives overwritten globals",'GetCurrentChatEvent=function() return "CHAT_MSG_RAID","123","Bob" end',"wrong","Wrong")
chat_check("legacy chat fallback snapshots sender before roster scan",'GetCurrentChatEvent=nil')
chat_check("empty ClassicAPI chat result uses legacy fallback",'GetCurrentChatEvent=function() end')
chat_check("ClassicAPI chat errors use legacy fallback",'GetCurrentChatEvent=function() error("unavailable") end')
check("non-request actual payload does not use corrupted trigger globals",r'''GetCurrentChatEvent=function() return "CHAT_MSG_RAID","hello","Bob" end;arg1="123";arg2="Bob";LP.OnTrigger=function() error("false request") end;LP:OnEvent("CHAT_MSG_RAID")''')
check("nested spell event does not replay outer chat",r'''GetCurrentChatEvent=function() return "CHAT_MSG_RAID","123","Bob" end;LP.OnTrigger=function() error("duplicate request") end;arg1="Shadow Bolt";LP:OnEvent("SPELLCAST_START");assert(LP.castBusy)''')
check("addon sync payload is not replaced by chat reader",r'''GetCurrentChatEvent=function() error("must not read addon sync") end;LP.AddRequest=function(self,name) assert(name=="Bob");synced=true end;LP.ScanRoster=function() return {} end;arg1="RSAdd";arg2="Bob";arg4="Other";LockPortOptions.autoRemove=false;LP:OnEvent("CHAT_MSG_ADDON");assert(synced)''')

check("mute blocks summon say and whisper then resumes",r'''LP.CountShards=function() return 5 end;LP.RemoveRequest=function() end;LP.SendAddon=function() end;sent=0;SendChatMessage=function() sent=sent+1 end;LockPortOptions.whisper=true;LP:SetChatMuted(true);LP.pending={name="Bob"};LP:OnRitualStarted();assert(sent==0 and LP.pending.started);LP:SetChatMuted(false);LP.pending={name="Bob"};LP:OnRitualStarted();assert(sent==2)''')
check("mute clears pending status whispers and skips new replies",r'''LP.whisperQueue={{key="status:Bob",name="Bob",text="old",at=0}};LP:SetChatMuted(true);assert(table.getn(LP.whisperQueue)==0);LockPortOptions.whisperStatus=true;LP:QueueWhisper("Bob","status","new");assert(table.getn(LP.whisperQueue)==0);LP:SetChatMuted(false);LP:ProcessWhisperQueue(100);assert(table.getn(LP.whisperQueue)==0)''')
L=env();L.execute(core);L.execute(r'''LP=LockPort;LockPortOptions.chatMuted=true;GetNumRaidMembers=function() error("must stop before sending") end;LP:OpenAnnounce(100,true)''');print("PASS mute blocks forced availability announcements")

check("raid group selection defaults to all and supports none",r'''assert(LP:IsSelectedRaidGroup({subgroup=8}));LP:SetSummonGroups({});assert(not LP:IsSelectedRaidGroup({subgroup=1}));LP:SetSummonGroups(nil);assert(LP:IsSelectedRaidGroup({subgroup=1}))''')
check("group selection ignores party roster",r'''raidSize=0;partySize=3;LP:SetSummonGroups({[8]=true});assert(LP:IsSelectedRaidGroup({unit="party1"}))''')
check("group selection releases outstanding reservation",r'''LP.coordReservation={id=1,target="Bob",phase="reserve"};LP.autoReadyName="Bob";LP:SetSummonGroups({[2]=true});assert(not LP.coordReservation and not LP.autoReadyName);assert(LP:IsSelectedRaidGroup({subgroup=2}) and not LP:IsSelectedRaidGroup({subgroup=1}))''')
# Parse the real raid roster's third field and immediately follow subgroup moves.
L=env();L.execute(r'''raidSize=1;group=4;function GetRaidRosterInfo() return "Bob",0,group,60,"Warrior","WARRIOR","Test",true,false end;LP:SetSummonGroups({[4]=true});assert(LP:IsSelectedRaidGroup(LP:ScanRoster().Bob));group=5;assert(not LP:IsSelectedRaidGroup(LP:ScanRoster().Bob))''');print("PASS real raid roster subgroup parsing and subgroup changes")
# Exercise real candidate selection and direct casts against an assignment.
L=env();L.execute(core);L.execute(r'''
LP=LockPort;LP.Print=function() end;LP.UpdateUI=function() end;LP.SendAddon=function() end
LP.roster={Alice={unit="raid2",subgroup=1,online=true},Bob={unit="raid3",subgroup=2,online=true}}
LP.ScanRoster=function(self) return self.roster end;LP.TargetProblem=function() return nil end
LP.CountShards=function() return 5 end;LP.CountHelpers=function() return 2 end;LP.KnowsRitual=function() return true end
LP.requests={{name="Alice",t=1},{name="Bob",t=2}}
LP:SetSummonGroups({[2]=true});assert(LP:NextCandidate().name=="Bob")
LP:Summon("Alice");assert(not LP.pending and not manualCalls)
LP:SummonNext();assert(LP.pending.name=="Bob" and manualCalls==1)
LP.pending=nil;LP:SetSummonGroups({});assert(not LP:NextCandidate())
''');print("PASS Summon and direct row casts respect raid group selection")

check("saved raid group selection survives initialization",r'''LockPortOptions.summonGroups={[2]=true,[7]=true};LP.DetectMods=function(self) self.mods={} end;LP.CreateUI=function() end;GetAddOnMetadata=function() return "3.9.0" end;LP:Initialize();assert(LockPortOptions.summonGroups[2] and LockPortOptions.summonGroups[7] and not LockPortOptions.summonGroups[1])''')
