"""Independent Lua clients; simulated WoW APIs and delayed addon-message bus.

Runs the real scheduler, reservation, candidate, cast-start and queue code.
No WoW process, network server, or native DLL is executed.
"""
import heapq
import random
import sys
from pathlib import Path
from zipfile import ZipFile
sys.path.insert(0, str(Path('work/python-deps').resolve()))
from lupa.lua51 import LuaRuntime
PACKAGE = Path(__file__).resolve().parent.parent
CORE = (PACKAGE/'LockPort.lua').read_text(encoding='utf-8')
# Frozen pre-reservation code, used as a real mixed-version client.
LEGACY = (PACKAGE/'tests/fixtures/LockPort-3.7.8.lua').read_text(encoding='utf-8')

class World:
    def __init__(self, names=('Alpha', 'Bravo', 'Charlie'), targets=3, delay=0.2, seed=0, party=False):
        self.now=100.0; self.rng=random.Random(seed); self.delay=delay
        self.names=list(names); self.targets=['Target'+str(i+1) for i in range(targets)]
        self.members=self.names+['HelperOne','HelperTwo']+self.targets
        if party:self.members=self.names+self.targets+['HelperOne','HelperTwo'][:max(0,5-len(self.names)-len(self.targets))]
        self.subgroups={n:8 for n in self.members}; self.subgroups.update({n:i+1 for i,n in enumerate(self.targets)})
        self.online={n:True for n in self.members}; self.clients={};self.events=[];self.serial=0
        self.casts=[];self.messages=[];self.drop=lambda *args:False;self.party=party
        self.reject=set();self.no_start=set();self.extra_delay=lambda *args:0

    def later(self, delay, fn):
        self.serial+=1;heapq.heappush(self.events,(self.now+delay,self.serial,fn))

    def send(self,sender,prefix,message,channel):
        assert "|" not in message, "Invalid escape code in addon message: " + message
        self.messages.append((self.now,sender,prefix,message))
        for receiver in self.clients:
            if receiver==sender or not self.online.get(receiver):continue
            if self.drop(sender,receiver,prefix,message):continue
            delay=self.delay(self.rng) if callable(self.delay) else self.delay
            delay+=self.extra_delay(sender,receiver,prefix,message)
            self.later(delay,lambda r=receiver:self.deliver(r,prefix,message,channel,sender))

    def deliver(self,receiver,prefix,message,channel,sender):
        if not self.online.get(receiver):return
        c=self.clients[receiver];g=c.globals()
        g.arg1,g.arg2,g.arg3,g.arg4=prefix,message,channel,sender
        c.execute('LockPort:OnEvent("CHAT_MSG_ADDON")')

    def roster(self,L,me):
        return L.table_from({n:L.table_from(dict(unit=('party' if self.party else 'raid')+str(i+1),
             online=self.online[n], subgroup=self.subgroups[n], **{'class':'WARLOCK' if n in self.names else 'WARRIOR'}))
             for i,n in enumerate([n for n in self.members if not self.party or n!=me]) if self.online[n]})

    def client(self,name,legacy=False,source=None):
        L=LuaRuntime();g=L.globals();g.me=name;g.now=self.now
        unit_names=[n for n in self.members if not self.party or n!=name]
        g.pyUnitName=lambda u: name if u=='player' else unit_names[int(u[5:] if u.startswith('party') else u[4:])-1]
        g.pyRoster=lambda:self.roster(L,name)
        g.pySend=lambda prefix,msg,chan:self.send(name,prefix,msg,chan)
        g.pyConnected=lambda unit:self.online.get(g.pyUnitName(unit),False)
        g.pyNative=lambda unit:self.cast(name,unit)
        L.execute(r'''
        function GetTime() return now end
        function UnitName(u) return pyUnitName(u) end
        function UnitClass(u) return "Warlock","WARLOCK" end
        function UnitIsConnected(u) return pyConnected(u) end
        function UnitIsDeadOrGhost() return false end
        function UnitAffectingCombat() return false end
        function UnitIsVisible() return false end
        function GetLockPortVersion() return "1.2.1" end
        function LockPortNativeSummon(u) return pyNative(u) end
        function CastSpellByName() return pyNative(LockPort.pending.unit) end
        function TargetUnit() end
        function GetUnitSpeed() return moving and 1 or 0 end
        C_Spell={UnitCastingInfo=function() return nil end,UnitChannelInfo=function() return channel end}
        function CreateFrame() return {RegisterEvent=function() end,SetScript=function() end} end
        function SendAddonMessage(p,m,c) pySend(p,m,c) end
        function SendChatMessage() chatCount=(chatCount or 0)+1 end
        function GetZoneText() return "Test Zone" end
        function GetSubZoneText() return "" end
        function PlaySound() end
        function GetAddOnMetadata() return "3.8.0" end
        function GetNumRaidMembers() return inParty and 0 or memberCount end
        function GetNumPartyMembers() return inParty and (memberCount-1) or 0 end
        function IsInGuild() return false end
        SlashCmdList={}
        LockPortOptions={announceOpen=false,askHelpers=false,autoRemove=false,sound=false,
          readySound=false,flash=false,whisperStatus=false,chatMuted=true,triggers="123"}
        ''')
        g.inParty=self.party;g.memberCount=len(self.members)
        L.execute(source if source is not None else (LEGACY if legacy else CORE))
        L.execute(r'''
        LP=LockPort;LP.mods={}
        LP.Print=function(self,msg) lastPrint=msg end
        LP.UpdateUI=function() end;LP.RefreshOptions=function() end
        LP.ScanRoster=function(self) self.roster=pyRoster();return self.roster end
        LP.CountShards=function() return noShards and 0 or 5 end
        LP.CountHelpers=function() return noHelpers and 0 or 2 end
        LP.IsNearby=function() return false end
        LP.KnowsRitual=function() return true end
        LP.InstanceBlock=function() return nil end
        LP:ScanRoster()
        ''')
        self.clients[name]=L
        for target in self.targets:L.globals().LP.AddRequest(L.globals().LP,target,False)
        return L

    def enable(self,name):
        self.clients[name].execute('LP:SetRaidAutoSummon(true)')

    def cast(self,name,unit):
        L=self.clients[name];target=L.globals().LP.pending.name
        if name in self.reject:return False
        self.casts.append((round(self.now,2),name,target))
        if name not in self.no_start:
            L.globals().channel='Ritual of Summoning';L.globals().arg1='Ritual of Summoning'
            L.execute('LP:OnEvent("SPELLCAST_START")')
            self.later(3,lambda:self.stop(name))
        return True

    def stop(self,name):
        if not self.online.get(name):return
        L=self.clients[name];L.globals().channel=None
        L.execute('LP:OnEvent("SPELLCAST_CHANNEL_STOP")')

    def run(self,seconds,order=None):
        end=self.now+seconds
        while self.now<end-0.001:
            self.now=round(self.now+0.1,4)
            for L in self.clients.values():L.globals().now=self.now
            while self.events and self.events[0][0]<=self.now+0.00001:
                _,_,fn=heapq.heappop(self.events);fn()
            for name in order or self.clients:
                if self.online.get(name):self.clients[name].execute('LP:OnUpdate(0.1)')

    def unique(self,expected=None):
        targets=[c[2] for c in self.casts]
        assert len(targets)==len(set(targets)),self.casts
        if expected is not None:assert len(targets)==expected,self.casts


def suite():
    # Demonstrate the actual old bug before applying the new protocol.
    w=World(names=('Alpha','Bravo'),targets=1,delay=0.3)
    for n in w.names:w.client(n,legacy=True)
    for n in w.names:w.enable(n)
    w.run(6)
    assert len(w.casts)==2 and w.casts[0][2]==w.casts[1][2],w.casts
    print('PASS reproduced duplicate cast with two uncoordinated 3.7.8 clients')

    for count in (2,3):
        for party in (False,True):
            targets=min(count,5-count) if party else count
            w=World(names=('Alpha','Bravo','Charlie')[:count],targets=targets,party=party)
            for n in w.names:w.client(n)
            for n in w.names:w.enable(n)
            w.run(16);w.unique(targets)
            assert len(set(c[1] for c in w.casts))==min(count,targets),w.casts
            print('PASS',count,'warlocks split requests in', 'party' if party else 'raid',w.casts)

    for seed in range(40):
        w=World(targets=5,delay=lambda rng:rng.uniform(0.05,1.4),seed=seed)
        for n in w.names:w.client(n)
        for n in reversed(w.names):w.enable(n)
        w.run(35,order=list(reversed(w.names)));w.unique(5)
    print('PASS 40 randomized delayed/reordered three-client runs, five requests each')

    w=World(targets=1)
    for n in w.names:w.client(n)
    for n in w.names:w.enable(n)
    w.extra_delay=lambda s,r,p,m:2.6 if p=='LPCoord' and ':A:' in m else 0
    w.run(14);w.unique(1)
    assert w.casts[0][0]>=104.0,w.casts
    print('PASS delayed acknowledgements prevent early cast')

    w=World(targets=1)
    for n in w.names:w.client(n)
    for n in w.names:w.enable(n)
    w.drop=lambda s,r,p,m:p=='LPCoord' and ':A:' in m
    w.run(15);assert not w.casts,w.casts
    w.drop=lambda *a:False;w.run(15);w.unique(1)
    print('PASS lost acknowledgements hold casting; recovery after delivery resumes')

    for reason in ('moving','noHelpers','noShards'):
        w=World(targets=2)
        for n in w.names:w.client(n)
        w.clients['Alpha'].globals()[reason]=True
        for n in w.names:w.enable(n)
        w.run(18);w.unique(2);assert all(c[1]!='Alpha' for c in w.casts)
        print('PASS unready warlock excluded:',reason)

    for action in ('off','disconnect','movement'):
        w=World(names=('Alpha','Bravo'),targets=1)
        for n in w.names:w.client(n)
        for n in w.names:w.enable(n)
        w.run(1.2)
        if action=='off':w.clients['Alpha'].execute('LP:SetRaidAutoSummon(false)')
        elif action=='disconnect':w.online['Alpha']=False
        else:w.clients['Alpha'].globals().moving=True
        w.run(14);w.unique(1);assert w.casts[0][1]=='Bravo',w.casts
        print('PASS reservation handoff after',action)

    for kind in ('reject','no-start'):
        w=World(names=('Alpha','Bravo'),targets=1)
        for n in w.names:w.client(n)
        for n in w.names:w.enable(n)
        if kind=='reject':w.reject.add('Alpha')
        else:w.no_start.add('Alpha')
        w.run(15)
        if kind=='reject':w.unique(1);assert w.casts[0][1]=='Bravo'
        else:
            assert len(w.casts)==2 and w.casts[0][1]=='Alpha' and w.casts[1][1]=='Bravo',w.casts
            assert w.casts[1][0]-w.casts[0][0]>4,w.casts
        print('PASS handoff after native',kind)

    w=World(names=('Alpha','Bravo'),targets=1)
    w.client('Alpha');w.client('Bravo',legacy=True)
    w.enable('Alpha');w.clients['Bravo'].execute('LP:Summon("Target1")')
    w.run(10);w.unique(1);assert w.casts[0][1]=='Bravo'
    print('PASS old manual summon claim prevents new automatic duplicate')

    # Verify real legacy list add/remove without substituting legacy OnEvent.
    w=World(names=('Alpha','Bravo'),targets=1)
    for n in w.names:w.client(n,legacy=n=='Bravo');w.clients[n].execute('LP.requests={}')
    w.clients['Alpha'].execute('LP:AddRequest("Target1",true)');w.run(1)
    assert w.clients['Bravo'].eval('table.getn(LP.requests)')==1
    w.clients['Bravo'].execute('LP:RemoveRequest("Target1",true)');w.run(1)
    assert w.clients['Alpha'].eval('table.getn(LP.requests)')==0
    print('PASS bidirectional list synchronization with 3.7.8')

    # Old auto peers cannot ACK: explicitly demonstrate that this is NOT guaranteed.
    w=World(names=('Alpha','Bravo'),targets=1,delay=0.3)
    w.client('Alpha');w.client('Bravo',legacy=True)
    for n in w.names:w.enable(n)
    w.run(7)
    assert len(w.casts)==2,w.casts
    print('KNOWN LIMIT mixed new/3.7.8 simultaneous auto can still duplicate:',w.casts)

    # A partition during initial discovery is unknowable; do not claim consensus.
    w=World(names=('Alpha','Bravo'),targets=1)
    for n in w.names:w.client(n)
    w.drop=lambda *a:True
    for n in w.names:w.enable(n)
    w.run(7);assert len(w.casts)==2,w.casts
    print('KNOWN LIMIT total message loss before peer discovery can duplicate')

if __name__=='__main__':suite()


def extended_suite():
    # ACKs from a previous transaction may never authorize a replacement.
    w=World(names=('Alpha','Bravo'),targets=1)
    for n in w.names:w.client(n)
    for n in w.names:w.enable(n)
    w.run(1.2)
    L=w.clients['Alpha'];old=L.globals().LP.coordReservation.id
    L.execute('LP:CoordRelease();LP:CoordReserve("Target1",now)')
    fresh=L.globals().LP.coordReservation.id
    assert fresh>old
    session=L.globals().LP.coordSession
    w.deliver('Alpha','LPCoord',f'1:A:{session}:{old}:Target1:Alpha','RAID','Bravo')
    assert not L.eval('LP.coordReservation.acks.Bravo')
    print('PASS delayed ACK cannot authorize a newer reservation')

    # A release arriving before its reserve leaves a tombstone.
    w=World(names=('Alpha','Bravo'),targets=1)
    for n in w.names:w.client(n)
    w.deliver('Bravo','LPCoord','1:X:100000:5:Target1:','RAID','Alpha')
    w.deliver('Bravo','LPCoord','1:R:100000:5:Target1:','RAID','Alpha')
    assert not w.clients['Bravo'].eval('LP.coordPeers.Alpha.reservation')
    print('PASS out-of-order release prevents a stale reservation from returning')

    w=World(names=('Alpha','Bravo'),targets=2)
    for n in w.names:w.client(n)
    w.deliver('Bravo','LPCoord','1:S:100000:1:Target1:','RAID','Alpha')
    w.deliver('Bravo','LPCoord','1:C:100000:2:Target2:','RAID','Alpha')
    L=w.clients['Bravo'];assert L.eval('LP:CoordBlocked("Target1",now)')
    w.now+=131;L.globals().now=w.now
    assert not L.eval('LP:CoordBlocked("Target1",now)')
    print('PASS acceptance hold survives owner starting another target and later expires')

    w=World(names=('Alpha','Bravo'),targets=1)
    for n in w.names:w.client(n)
    for n in w.names:w.enable(n)
    w.run(1.2);w.client('Alpha');w.enable('Alpha');w.run(14);w.unique(1)
    print('PASS reload during reservation re-handshakes without duplicate cast')

    w=World(names=('Alpha','Bravo'),targets=1)
    for n in w.names:w.client(n)
    for n in w.names:w.enable(n)
    w.run(1.6)
    w.clients['Bravo'].execute('LP:Summon("Target1")')
    assert not w.casts
    w.run(10);w.unique(1)
    print('PASS updated manual click respects another updated warlock reservation')

    w=World(names=('Alpha','Bravo'),targets=1)
    for n in w.names:w.client(n)
    for sender,chan,msg in [('Outsider','RAID','1:R:100000:1:Target1:'),
                            ('HelperOne','RAID','1:R:100000:1:Target1:'),
                            ('Alpha','WHISPER','1:R:100000:1:Target1:'),
                            ('Alpha','RAID','2:R:100000:1:Target1:'),
                            ('Alpha','RAID','broken')]:
        w.deliver('Bravo','LPCoord',msg,chan,sender)
    assert not w.clients['Bravo'].eval('LP.coordPeers and next(LP.coordPeers)')
    print('PASS malformed, non-warlock, outsider and wrong-channel messages ignored')

    # A private request initially exists on just one client; real RSAdd shares it.
    w=World(targets=1)
    for n in w.names:w.client(n);w.clients[n].execute('LP.requests={}')
    for n in w.names:w.enable(n)
    w.clients['Charlie'].execute('LP:AddRequest("Target1",true)')
    w.run(14);w.unique(1)
    print('PASS request initially visible to one warlock is shared and cast once')

    for seed in range(60):
        w=World(targets=6,delay=lambda rng:rng.uniform(0,1.8),seed=seed+100)
        for n in w.names:w.client(n)
        for n in w.names:w.enable(n)
        order=w.names[:];w.rng.shuffle(order)
        w.run(55,order=order);w.unique(6)
    print('PASS 60 additional randomized three-client runs, six requests each')

if __name__=='__main__':extended_suite()


def original_compatibility():
    source=(PACKAGE/'tests/fixtures/LockPort-original.lua').read_text(encoding='utf-8')
    w=World(names=('Alpha','Bravo'),targets=1)
    w.client('Alpha');w.client('Bravo',source=source)
    for L in w.clients.values():L.execute('LP.requests={}')
    w.clients['Alpha'].execute('LP:AddRequest("Target1",true)');w.run(1)
    assert w.clients['Bravo'].eval('table.getn(LP.requests)')==1
    w.clients['Bravo'].execute('LP:RemoveRequest("Target1",true)');w.run(1)
    assert w.clients['Alpha'].eval('table.getn(LP.requests)')==0
    for L in w.clients.values():L.execute('LP:AddRequest("Target1",false)')
    w.enable('Alpha');w.clients['Bravo'].execute('LP:Summon("Target1")')
    w.run(10);w.unique(1);assert w.casts[0][1]=='Bravo'
    print('PASS original repository addon: list sync both directions and manual cast claim')

if __name__=='__main__':original_compatibility()

def raid_group_suite():
    # Different assignments share one synchronized queue but each caster only
    # reserves its own raid subgroups. No 123 requests are needed.
    w=World(targets=6)
    for n in w.names:w.client(n);w.clients[n].execute('LP.requests={}')
    assignments={'Alpha':(1,2),'Bravo':(3,4),'Charlie':(5,6)}
    for n,groups in assignments.items():
        w.clients[n].execute('LP:SetSummonGroups({'+','.join('['+str(g)+']=true' for g in groups)+'})')
        w.enable(n)
        assert w.clients[n].eval('LP:QueueSelectedGroups()')==2
    w.run(30);w.unique(6)
    for _,caster,target in w.casts:assert w.subgroups[target] in assignments[caster],w.casts
    print('PASS three warlocks queue assigned raid groups without requests and split six targets')

    w=World(names=('Alpha','Bravo'),targets=2)
    for n in w.names:w.client(n);w.clients[n].execute('LP:SetSummonGroups({[1]=true,[2]=true})');w.enable(n)
    w.run(14);w.unique(2)
    print('PASS overlapping group assignments still coordinate without duplicate casts')

    w=World(names=('Alpha','Bravo'),targets=2)
    for n in w.names:w.client(n);w.clients[n].execute('LP:SetSummonGroups({[1]=true})');w.enable(n)
    w.run(12);w.unique(1);assert w.casts[0][2]=='Target1'
    assert all(w.clients[n].eval('LP:FindRequest("Target2")') for n in w.names)
    print('PASS unassigned-group requests stay queued and are not summoned')

    w=World(names=('Alpha','Bravo'),targets=2)
    for n in w.names:w.client(n);w.enable(n)
    w.run(1.6);w.clients['Alpha'].execute('LP:SetSummonGroups({[2]=true})');w.clients['Bravo'].execute('LP:SetSummonGroups({[1]=true})')
    w.run(18);w.unique(2)
    assert {caster:target for _,caster,target in w.casts}=={'Alpha':'Target2','Bravo':'Target1'},w.casts
    print('PASS assignment change during reservation releases and reassigns targets')

    w=World(names=('Alpha',),targets=2)
    L=w.client('Alpha');L.execute('LP.requests={};LP:SetSummonGroups({[1]=true,[2]=true})')
    w.online['Target2']=False
    assert L.eval('LP:QueueSelectedGroups()')==1
    assert L.eval('LP:QueueSelectedGroups()')==0
    w.online['Target2']=True
    assert L.eval('LP:QueueSelectedGroups()')==1
    L.execute('LP:SetSummonGroups({})');assert L.eval('LP:QueueSelectedGroups()')==0
    print('PASS group queue skips offline players, is idempotent, and handles no selection')

    w=World(names=('Alpha',),targets=2)
    L=w.client('Alpha');L.execute('LP:SetSummonGroups({[2]=true})')
    w.subgroups['Target1']=2;w.subgroups['Target2']=1
    w.enable('Alpha');w.run(10);w.unique(1);assert w.casts[0][2]=='Target1'
    print('PASS current raid subgroup moves are honored before casting')

if __name__=='__main__':raid_group_suite()
