-- Offline behavior checks; these do not emulate client taint or rendering.
local TocFiles = dofile('Tools/regression/toc_files.lua')
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end
local function fixture(settings, withSettings)
    local s = { now = 0, frames = {}, named = {}, timers = {}, tickers = {}, sounds = 0,
        combat = false, secret = false, reads = 0, group = true, raid = false,
        units = {
            player = { name = 'You', class = 'PALADIN', threat = { false, 1, 81.8, 90, 900 } },
            party1 = { name = 'Tank', class = 'WARRIOR', threat = { true, 3, 100, 100, 1000 } },
            party2 = { name = 'Healer', class = 'PRIEST', threat = { false, 0, 20, 22, 220 } },
            pet = { name = 'Pet', threat = { false, 0, 10, 11, 110 } },
            target = { name = 'Target', guid = 'mob-a', hostile = true },
            focus = { name = 'Focus', guid = 'mob-b', hostile = true },
        }, settings = settings or {}, cards = {}, cx = 0, cy = 0 }
    local function frame(kind, name, parent)
        local f = { kind = kind, scripts = {}, events = {}, shown = true, w = 280, h = 240, parent = parent }
        setmetatable(f, { __index = function(_, k) if k:match('^%u') then return function() end end end })
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(k) self.events[k] = true end
        function f:RegisterUnitEvent(k) self.events[k] = true end
        function f:UnregisterEvent(k) self.events[k] = nil end
        function f:UnregisterAllEvents() self.events = {} end
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
        function f:SetShown(v) if v then self:Show() else self:Hide() end end
        function f:IsShown() return self.shown end
        function f:SetSize(w,h) assert(type(w)=='number' and type(h)=='number'); self.w,self.h=w,h end
        function f:GetWidth() return self.w end
        function f:GetHeight() return self.h end
        function f:GetEffectiveScale() return 1 end
        function f:SetAlpha(a) self.alpha=a end
        function f:GetFrameLevel() return 1 end
        function f:GetLeft() return 100 end
        function f:GetTop() return 600 end
        function f:SetPoint(...) self.point={...} end
        function f:SetText(t) assert(type(t)~='boolean','boolean passed to SetText'); self.text=t end
        function f:SetFont(path,size,flags) assert(type(path)=='string' and type(size)=='number'); self.fontSize,self.flags=size,flags end
        function f:SetStatusBarTexture(t) self.barTexture=t end
        function f:SetTexture(t) self.texture=t end
        function f:SetDesaturated(v) self.desaturated=v end
        function f:SetStatusBarColor(...) self.color={...} end
        function f:SetColorTexture(...) self.colorTexture={...} end
        function f:SetValue(v) self.valueNumber=v end
        function f:CreateTexture() return frame('Texture',nil,self) end
        s.frames[#s.frames+1]=f; if name then s.named[name]=f end
        return f
    end
    local ns={ L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower, MEDIA = dofile("Tools/regression/core_media.lua"), THEME={bg={},fg={r=1,g=1,b=1},muted={r=0.6,g=0.6,b=0.6},accent={r=0,g=0.7,b=1}},
        UIFontPath=function() return 'font.ttf' end, Print=function() end,
        Apply=function() end, ShowUnlockMode=function() end, HideUnlockMode=function() end,
        Font=function() return frame('FontString') end,
        Border=function(_,color) local b=frame('Border'); b.edge=color; return {_frame=b} end,
        AllowOffscreen=function() end,
        Solid=function(_,_,color,alpha) local t=frame('Texture'); t.solid={color=color,alpha=alpha}; return t end,
        ThemeTint=function(_,literal) return literal end, Tooltip=function() end,
        Button=function(parent,text,w,h,fn) local b=frame('Button',nil,parent); b.label=frame('FontString'); b.label:SetText(text); b.scripts.OnClick=fn; return b end,
        OpenOptionsWindow=function(name) s.opened=name end,
        UI={STATUS={},FontPath=function() return 'font.ttf' end,AttachMover=function() return frame('Mover') end,
            TexturePath=function(name,fallback) if name=='Solid' then return 'solid' end return fallback end,
            SoundPathFor=function() return 'sound' end,_PlayLSMSound=function() s.sounds=s.sounds+1 end},
    }
    ns.UI.ModuleSettings=function(_, given)
        -- Written against the meter's original defaults.
        local defaults=setmetatable({enabled=false,width=280,height=240,barHeight=24,locked=true,fontSize=12,
            statusPos='bottom'},{__index=given})
        return {Get=function(k) if s.settings[k]~=nil then return s.settings[k] end return defaults[k] end,
            Set=function(k,v) s.settings[k]=v end, DB=function() return s.settings end}
    end
    local env={_G={NaowhForever=ns},MAX_RAID_MEMBERS=40,MAX_PARTY_MEMBERS=4,
        UIParent=frame('Parent'),CreateFrame=frame,
        RAID_CLASS_COLORS={PALADIN={r=1,g=0.5,b=0.8},WARRIOR={r=0.8,g=0.6,b=0.4},PRIEST={r=1,g=1,b=1},HUNTER={r=0.5,g=0.9,b=0.5}},
        UnitExists=function(u) return s.units[u]~=nil end,
        UnitCanAttack=function(_,u) return s.units[u] and s.units[u].hostile or false end,
        UnitName=function(u) return s.units[u] and s.units[u].name end,
        UnitGUID=function(u) return s.units[u] and s.units[u].guid end,
        UnitClass=function(u) return 'class',s.units[u] and s.units[u].class end,
        UnitIsUnit=function(a,b) return a==b end,
        UnitDetailedThreatSituation=function(u,mob)
            s.reads=s.reads+1; s.readMob=mob
            if s.secret then local v={secret=true};return v,v,v,v,v end
            return unpack(s.units[u].threat or {})
        end,
        UnitAffectingCombat=function() return s.combat end,InCombatLockdown=function() return s.combat end,
        IsInGroup=function() return s.group end,IsInRaid=function() return s.raid end,
        GetNumGroupMembers=function() return s.raid and 12 or 3 end,
        GetNumSubgroupMembers=function() return s.group and 2 or 0 end,
        UnitGroupRolesAssigned=function() return s.role or 'DAMAGER' end,
        GetShapeshiftFormID=function() return s.form end,
        issecretvalue=function(v) return type(v)=='table' and v.secret==true end,
        C_Timer={After=function(delay,fn) s.timers[#s.timers+1]={at=s.now+delay,fn=fn} end,
            NewTicker=function(delay,fn) local t={fn=fn,cancelled=false};function t:Cancel() self.cancelled=true end;s.tickers[#s.tickers+1]=t;return t end},
        hooksecurefunc=function(t,k,fn) local old=t[k];t[k]=function(...) old(...);fn(...) end end,
        GetCursorPosition=function() return s.cx,s.cy end,
        wipe=function(t) for k in pairs(t) do t[k]=nil end return t end,
        IsShiftKeyDown=function() return s.shift end,IsControlKeyDown=function() return s.ctrl end,
        MenuUtil={CreateContextMenu=function(owner,gen) s.menu={owner=owner,gen=gen} end},
    }
    s.newFrame=frame
    env.GameTooltip=frame('Tooltip')
    function env.GameTooltip:SetOwner(o) self.owner=o end
    function env.GameTooltip:GetOwner() return self.owner end
    ns.Shared={Parts={HudFont=function(fs,font,size,outline) fs:SetFont('font.ttf',size,outline);fs.shadowFor=outline=='' end},
        Style=setmetatable({RED_RGB={r=0.97,g=0.44,b=0.44},HAVE_RGB={r=0.3,g=0.82,b=0.48},WARN_RGB={r=0.98,g=0.57,b=0.24}},
            {__index=dofile('Tools/regression/shared_style.lua')})}
    if withSettings then
        ns.Shared.Settings={Group=function(name) return {group=name} end,Look=function(_,opts) s.look=opts;return {} end,
            Snap=function(v,range)
                local low,high,step=range[1],range[2],range[3]
                v=low+math.floor((v-low)/step+0.5)*step
                return math.max(low,math.min(high,v))
            end,
            Page=function() return {Window=function() end,Card=function(_,c) s.cards[c.id]=c end} end}
    end
    setmetatable(env,{__index=_G})
    local files=TocFiles('^NaowhForever_ThreatMeter/.*%.lua$')
    table.insert(files,1,'Core/Features.lua')
    for _,path in ipairs(files) do local chunk=assert(loadfile(path));setfenv(chunk,env);chunk() end
    s.ns=ns
    function s.fire(event,unit)
        local all={};for i,f in ipairs(s.frames) do all[i]=f end
        for _,f in ipairs(all) do if f.events[event] then f.scripts.OnEvent(f,event,unit) end end
    end
    function s.advance(dt)
        s.now=s.now+dt
        local again=true
        while again do
            again=false
            for i,t in ipairs(s.timers) do if t.at<=s.now then table.remove(s.timers,i);t.fn();again=true;break end end
        end
    end
    function s.set(k,v) ns.ThreatMeterSettings.Set(k,v);s.advance(0.21) end
    function s.bars()
        local out={};for _,f in ipairs(s.frames) do if f.kind=='StatusBar' and f.shown then out[#out+1]=f end end;return out
    end
    function s.bar(name) for _,f in ipairs(s.bars()) do if f.name.text==name then return f end end end
    function s.listens(event) for _,f in ipairs(s.frames) do if f.events[event] then return true end end return false end
    s.fire('PLAYER_LOGIN');s.window=s.named.NaowhForeverThreatMeter
    return s
end

do
 local s=fixture()
 check('disabled allocates no meter',not s.window)
 check('disabled registers no threat events',not s.listens('UNIT_THREAT_LIST_UPDATE'))
 s.set('fontSize',14);check('disabled does not queue updates',#s.timers==0)
end
do
 local s=fixture({enabled=true})
 check('target resolves',s.readMob=='target')
 check('pull line sorts before tank',s.bars()[1].name.text=='Aggro Line')
 check('pull line does not consume a rank',s.bar('Tank').rank.text=='1')
 check('player percent uses pull threshold',s.bar('You').percent.text=='82%')
 s.set('percentMode','tank');check('tank-relative percent is distinct',s.bar('You').percent.text=='90%')
 check('pull line shows its share of the tank threat',s.bar('Aggro Line').percent.text=='110%')
 check('pet inherits owner class icon',s.bar('Pet').icon.texture:find('PALADIN',1,true)~=nil)
 check('pet icon is desaturated',s.bar('Pet').icon.desaturated)
 s.set('ignorePets',true);check('pet filter removes row',not s.bar('Pet'))
 s.set('showValue',false);check('value column hides independently',s.bar('You').value.text=='')
 s.set('showPercent',false);check('percent column hides independently',s.bar('You').percent.text=='')
 s.set('focusEnabled',true);s.set('source','focus');check('focus source selected',s.readMob=='focus')
 s.units.focus.hostile=false;s.units.focustarget={name='Tank target',guid='mob-c',hostile=true};s.combat=true
 s.fire('UNIT_TARGET','focus');s.advance(0.21)
 check('friendly focus follows its target',s.readMob=='focustarget')
 check('derived source starts follow ticker',#s.tickers>0 and not s.tickers[#s.tickers].cancelled)
 s.set('enabled',false);check('disable cancels follow ticker',s.tickers[#s.tickers].cancelled)
 check('disable hides meter',not s.window.shown)
 check('disable unregisters threat events',not s.listens('UNIT_THREAT_LIST_UPDATE'))
end
do
 local s=fixture({enabled=true,warnSound=true,warnSoundKey='test'})
 check('threshold warns once',s.sounds==1)
 s.fire('UNIT_THREAT_LIST_UPDATE','target');s.advance(0.21);check('same target does not repeat',s.sounds==1)
 s.units.target.guid='new-mob';s.fire('PLAYER_TARGET_CHANGED');s.advance(0.21)
 check('new target rearms warning',s.sounds==2)
 s.units.player.threat[3]=50;s.fire('UNIT_THREAT_LIST_UPDATE','target');s.advance(0.21)
 s.units.player.threat[3]=85;s.fire('UNIT_THREAT_LIST_UPDATE','target');s.advance(0.21)
 check('dropping below threshold rearms warning',s.sounds==3)
 s.role='TANK';s.units.target.guid='third-mob';s.fire('PLAYER_TARGET_CHANGED');s.advance(0.21)
 check('tank role suppresses warning',s.sounds==3)
 s.role=nil;s.form=8;s.units.target.guid='fourth-mob';s.fire('PLAYER_TARGET_CHANGED');s.advance(0.21)
 check('tank form suppresses warning',s.sounds==3)
 s.settings.warnSkipTank=false;s.units.target.guid='fifth-mob';s.fire('PLAYER_TARGET_CHANGED');s.advance(0.21)
 check('tank forms warn with Not While Tanking off',s.sounds==4)
end
do
 local s=fixture({enabled=true});local reads=s.reads
 s.secret=true;s.fire('UNIT_THREAT_LIST_UPDATE','target');s.advance(0.21)
 check('secret threat values are read without error',s.reads>reads)
 check('restricted data hides when empty',not s.window.shown)
 s.set('visibility','always');check('empty window can remain visible',s.window.shown and s.window.empty.shown)
 s.units.target=nil;s.fire('PLAYER_TARGET_CHANGED');s.advance(0.21)
 check('no mob unregisters threat events',not s.listens('UNIT_THREAT_LIST_UPDATE'))
 s.set('visibility','combat');check('combat visibility hides idle window',not s.window.shown)
 s.set('visibility','group');s.group=false;s.fire('GROUP_ROSTER_UPDATE');s.advance(0.21)
 check('group visibility hides solo window',not s.window.shown)
end
do
 local s=fixture({enabled=true,height=120,pullBar=false})
 check('fixed height limits visible rows',#s.bars()==1)
 local first=s.bars()[1].name.text;s.window.scripts.OnMouseWheel(s.window,-1)
 check('mouse wheel scrolls to next entry',s.bars()[1].name.text~=first)
 s.units.target.guid='new';s.fire('PLAYER_TARGET_CHANGED');s.advance(0.21)
 check('target switch resets scroll',s.bars()[1].name.text==first)
 local downY=s.bars()[1].point[5]
 s.set('statusPos','top');check('status line moves under the title bar',s.window.footer.point[1]=='TOPRIGHT')
 check('rows start below a top status line',s.bars()[1].point[5]==downY-24)
 check('locked grip hides with a top status line',not s.window.grip.shown)
 s.set('locked',false);check('unlocked grip shows with a top status line',s.window.grip.shown)
 s.set('locked',true)
 s.set('statusPos','bottom');check('status line returns to the bottom',s.window.footer.point[1]=='BOTTOMRIGHT')
 s.set('growUp',true);check('grow up anchors rows above footer',s.bars()[1].point[1]=='BOTTOMLEFT')
 s.ns.PreviewThreatMeter();check('preview displays synthetic title',s.window.header.text.text=='Edwin VanCleef')
 s.advance(10);check('preview returns to live target',s.window.header.text.text=='Target')
 s.fire('UNIT_THREAT_LIST_UPDATE','target');s.set('enabled',false);s.advance(1)
 check('stale queued update cannot reshow disabled meter',not s.window.shown)
end
do
 local s=fixture({enabled=true})
 s.window.grip.scripts.OnMouseDown(s.window.grip,'LeftButton')
 check('locked window cannot resize',s.window.sizing~=true)
 s.set('locked',false)
 s.window.grip.scripts.OnMouseDown(s.window.grip,'LeftButton')
 check('unlocked window starts resizing',s.window.sizing==true)
 local oldHeight=s.bar('You'):GetHeight()
 local oldFont=s.bar('You').name.fontSize
 local readsBeforeResize=s.reads
 s.window:SetSize(350,310)
 s.window.scripts.OnSizeChanged(s.window)
 check('resizing reuses collected threat',s.reads==readsBeforeResize)
 check('bars grow during drag',s.bar('You'):GetHeight()>oldHeight)
 check('text grows during drag',s.bar('You').name.fontSize>oldFont)
 s.window.grip.scripts.OnMouseUp(s.window.grip)
 s.advance(0.21)
 check('resize saves dimensions',s.settings.width==350 and s.settings.height==310)
 check('resize saves position',s.settings.threatPos.point=='TOPLEFT')
 local large=s.settings.barHeight
 check('resize persists larger bars',large>oldHeight)
 s.window.grip.scripts.OnMouseDown(s.window.grip,'LeftButton')
 s.window:SetSize(280,240);s.window.scripts.OnSizeChanged(s.window)
 check('bars shrink during drag',s.bar('You'):GetHeight()<large)
 s.window.grip.scripts.OnMouseUp(s.window.grip);s.advance(0.21)
 check('resize back restores bar height',math.abs(s.settings.barHeight-oldHeight)<0.001)
 s.combat=true
 s.window.grip.scripts.OnMouseDown(s.window.grip,'LeftButton')
 check('combat prevents resizing',s.window.sizing~=true)
end
do
 local s=fixture({enabled=true,width=240,barHeight=72,fontSize=24,height=400})
 local row=s.bar('You')
 check('large row icons stay compact',row.icon.w==32)
 check('narrow window reduces rendered font',row.name.fontSize<24)
 local nameSpace=row.w-16-18-38-5-99*row.name.fontSize/12
 check('narrow window reserves readable names',nameSpace>=47.99)
 check('render fit preserves font preference',s.settings.fontSize==24)
end
do
 local s=fixture({enabled=true})
 local bg,border=s.window.background,s.window.border._frame
 check('default background follows the theme',bg.colorTexture[1]==0.025 and bg.colorTexture[2]==0.04 and bg.colorTexture[3]==0.055)
 check('border is drawn at full background',bg.alpha==0.94 and border.alpha==0.94)
 s.set('backgroundAlpha',0);check('hidden background hides the border',bg.alpha==0 and border.alpha==0)
 s.set('backgroundAlpha',0.5);check('border fades with the background',border.alpha==0.5)
 s.set('backgroundColor',{r=0.3,g=0.2,b=0.1})
 check('picked background colour paints the window',bg.colorTexture[1]==0.3 and bg.colorTexture[2]==0.2 and bg.colorTexture[3]==0.1)
 check('picked colour keeps the opacity',bg.alpha==0.5)
end
do
 local s=fixture({enabled=true},true)
 local row
 for _,r in ipairs(s.cards.meter.rows) do if r.key=='backgroundColor' then row=r end end
 check('background colour row sits in the card',row and row.colour==true)
 local r,g,b=row.get();check('colour row shows the theme colour while unset',r==0.025 and g==0.04 and b==0.055)
 row.set(0.5,0.6,0.7);local c=s.settings.backgroundColor
 check('colour row saves the pick',c.r==0.5 and c.g==0.6 and c.b==0.7)
end
do
 local s=fixture({enabled=true,showHeader=false,width=160,height=50,pullBar=false},true)
 check('narrow width is kept',s.window.w==160)
 check('short window keeps one row and the status line',s.window.h==24+24+16 and #s.bars()==1)
 s.set('width',100);check('width stops at the minimum',s.window.w==160)
 local row=s.bar(s.bars()[1].name.text)
 check('narrow rows keep the name inside the row',row.w-8-18-(row.icon.w+6)-5-99*row.name.fontSize/12-8>0)
 local width,height
 for _,r in ipairs(s.cards.meter.rows) do
     if r.key=='width' then width=r.slider[1] elseif r.key=='height' then height=r.slider[1] end
 end
 check('sliders go below the old minimums',width==160 and height==50)
end
do
 -- With Custom Colors off the window paints exactly the surfaces it always did.
 local s=fixture({enabled=true})
 local function solid(r,g,b) for _,f in ipairs(s.frames) do local sd=rawget(f,'solid'); local c=sd and sd.color
     if c and c.r==r and c.g==g and c.b==b and sd.alpha==1 then return true end end end
 local function edge(r,g,b) for _,f in ipairs(s.frames) do local c=rawget(f,'edge')
     if c and c.r==r and c.g==g and c.b==b then return true end end end
 local function rowBg(r,g,b) for _,f in ipairs(s.frames) do local c=rawget(f,'colorTexture')
     if c and c[1]==r and c[2]==g and c[3]==b and c[4]==1 then return true end end end
 check('window background is unchanged',solid(0.025,0.04,0.055))
 check('header background is unchanged',solid(0.04,0.075,0.095))
 check('window border is unchanged',edge(0.10,0.19,0.24))
 check('row background is unchanged',rowBg(0.065,0.085,0.105))
end
do
 local s=fixture({enabled=true})
 check('new profile shows only with threat',s.settings.visibility=='threat')
 s=fixture({enabled=true,onlyWithThreat=true,visibility='always'})
 check('Hide When Empty on migrates to With Threat',s.settings.visibility=='threat' and s.settings.onlyWithThreat==nil)
 s=fixture({enabled=true,onlyWithThreat=false})
 check('Hide When Empty off keeps Always',s.settings.visibility=='always' and s.settings.onlyWithThreat==nil)
 s=fixture({enabled=true,onlyWithThreat=true,visibility='combat'})
 check('In Combat with Hide When Empty migrates to With Threat',s.settings.visibility=='threat')
 s=fixture({enabled=true,onlyWithThreat=false,visibility='combat'})
 check('In Combat without Hide When Empty is kept',s.settings.visibility=='combat')
 s=fixture({enabled=true,onlyWithThreat=true,visibility='group'})
 check('In a Group is kept',s.settings.visibility=='group' and s.settings.onlyWithThreat==nil)
 s=fixture({enabled=true,visibilityMerged=true,visibility='always'})
 check('migration runs once per profile',s.settings.visibility=='always')
end
do
 -- The Meter card's preview edits settings from the plain preview frames, never the live meter.
 local s=fixture({enabled=true},true)
 local studio=s.cards.meter.studio
 local shot=studio.new(s.newFrame('Frame'))
 studio.paint(shot,'tanking')
 local live={w=s.window.w,h=s.window.h}
 check('preview is editable while on',shot.edit.shown and shot.note.text:find('Drag the corner',1,true)==1)
 local wheel=shot.rowsHit.scripts.OnMouseWheel
 wheel(shot.rowsHit,1);check('wheel raises row height by one step',s.settings.barHeight==25)
 s.shift=true;wheel(shot.rowsHit,1);s.shift=false
 check('shift wheel sets row spacing',s.settings.barSpacing==4 and s.settings.barHeight==25)
 s.ctrl=true;wheel(shot.rowsHit,-1);s.ctrl=false
 check('ctrl wheel sets text size',s.settings.fontSize==11)
 s.settings.barHeight=72;wheel(shot.rowsHit,1);check('wheel stays inside the slider range',s.settings.barHeight==72)
 s.settings.barHeight=24.4;wheel(shot.rowsHit,-1);check('wheel snaps to the slider step',s.settings.barHeight==23)
 shot.headerHit.scripts.OnClick(shot.headerHit,'LeftButton');check('name click hides the target name',s.settings.showHeader==false)
 studio.paint(shot,'tanking')
 check('hidden name leaves a strip to click',shot.headerHit.point[1]=='TOPRIGHT')
 shot.headerHit.scripts.OnClick(shot.headerHit,'LeftButton');check('name click shows it again',s.settings.showHeader==true)
 shot.statusHit.scripts.OnClick(shot.statusHit,'LeftButton');check('status click moves it to the top',s.settings.statusPos=='top')
 shot.statusHit.scripts.OnClick(shot.statusHit,'LeftButton');check('status click cycles back',s.settings.statusPos=='bottom')
 shot.rowsHit.scripts.OnMouseUp(shot.rowsHit,'LeftButton');check('left click opens no menu',s.menu==nil)
 shot.rowsHit.scripts.OnMouseUp(shot.rowsHit,'RightButton');check('right click opens the row menu',s.menu and s.menu.owner==shot.rowsHit)
 local boxes={}
 local root={CreateTitle=function() end,CreateCheckbox=function(_,label,isOn,set,data) boxes[#boxes+1]={label=label,isOn=isOn,set=set,data=data} end}
 s.menu.gen(nil,root)
 check('row menu lists five switches',#boxes==5 and boxes[4].label=='Rank Numbers')
 check('row menu reads the setting',boxes[4].isOn(boxes[4].data)==true)
 boxes[4].set(boxes[4].data);check('row menu flips the setting',s.settings.showRanks==false)
 studio.paint(shot,'tanking')
 local grip,meter=shot.grip,shot.meter
 shot.part='meter';grip:Show()
 s.cx,s.cy=500,500;grip.scripts.OnMouseDown(grip,'LeftButton')
 check('corner drag runs only while dragging',grip.scripts.OnUpdate~=nil)
 s.cx,s.cy=560,440;grip.scripts.OnUpdate(grip)
 check('preview follows the drag',meter.w==340 and meter.h==300)
 check('nothing is saved mid-drag',s.settings.width==nil and s.settings.height==nil)
 s.cx,s.cy=5000,-5000;grip.scripts.OnUpdate(grip)
 check('drag stays inside the slider ranges',meter.w==520 and meter.h==700)
 s.cx,s.cy=560.4,440.3;grip.scripts.OnUpdate(grip)
 grip.scripts.OnMouseUp(grip,'LeftButton')
 check('release saves snapped width and height',s.settings.width==340 and s.settings.height==300)
 check('release stops the drag update',grip.scripts.OnUpdate==nil and not meter.sizing)
 check('live meter is not resized by the preview',s.window.w==live.w and s.window.h==live.h)
 studio.paint(shot,'tanking')
 function meter:GetEffectiveScale() return 0.5 end
 s.cx,s.cy=100,100;grip.scripts.OnMouseDown(grip,'LeftButton')
 s.cx,s.cy=130,100;grip.scripts.OnUpdate(grip);grip.scripts.OnMouseUp(grip,'LeftButton')
 check('cursor moves are converted by the fit scale',s.settings.width==400)
 s.cx,s.cy=0,0;grip.scripts.OnMouseDown(grip,'LeftButton');grip.scripts.OnMouseUp(grip,'LeftButton')
 check('a click on the corner saves nothing',s.settings.width==400 and s.settings.height==300)
 grip.scripts.OnMouseDown(grip,'LeftButton');shot:Hide()
 check('hiding the preview ends a drag',grip.scripts.OnUpdate==nil)
 s.settings.enabled=false;studio.paint(shot,'tanking')
 check('preview is not editable while off',not shot.edit.shown and shot.note.text:find('Turn on',1,true)==1)
end
do
 local s=fixture({enabled=true})
 local row=s.bar('You')
 check('rows draw the Naowh Gradient by default',row.barTexture:find('NaowhGradient',1,true)~=nil)
 check('rows are outlined by default',row.name.flags=='OUTLINE' and row.value.flags=='OUTLINE' and row.percent.flags=='OUTLINE')
 s.set('outline','');check('a changed outline relays the rows',s.bar('You').name.flags=='' and s.bar('You').name.shadowFor)
 s.set('texture','Solid');check('a SharedMedia texture is drawn',s.bar('You').barTexture=='solid')
end
do
 local s=fixture({enabled=true,texture='smooth'})
 check('the old Naowh Gradient value becomes the default',s.settings.texture==nil)
 check('it still draws the gradient',s.bar('You').barTexture:find('NaowhGradient',1,true)~=nil)
 s=fixture({enabled=true,texture='flat'})
 check('the old Flat value becomes Solid',s.settings.texture=='Solid' and s.bar('You').barTexture=='solid')
 s=fixture({texture='flat'})
 check('the texture moves over while the meter is off too',s.settings.texture=='Solid')
end
do
 local s=fixture({enabled=true},true)
 check('the meter card takes the shared text and bar rows',s.look and s.look.text and s.look.bar=='Naowh Gradient')
end
do
 local s=fixture({enabled=true,source='focus'})
 check('saved focus source waits for Focus Tracking',s.readMob=='target' and s.window.source.label.text=='Target')
 s.set('focusEnabled',true);check('Focus Tracking brings the saved source back',s.readMob=='focus')
end
do
 local s=fixture({enabled=true,tankColorOn=true})
 local line,tank=s.bar('Aggro Line').color,s.bar('Tank').color
 check('pull line takes the house warning colour',line[1]==0.98 and line[2]==0.57 and line[3]==0.24)
 check('tank bar takes the house have colour',tank[1]==0.3 and tank[2]==0.82 and tank[3]==0.48)
 s.set('playerColorOn',true);local own=s.bar('You').color
 check('your bar takes the house red',own[1]==0.97 and own[2]==0.44 and own[3]==0.44)
end
do
 local s=fixture({enabled=true})
 s.units.party1.threat[5]=900;s.units.player.threat[5]=900;s.fire('UNIT_THREAT_LIST_UPDATE','target');s.advance(0.21)
 check('equal threat keeps the read order',s.bar('You').rank.text=='1' and s.bar('Tank').rank.text=='2')
end
print(checks..' threat-meter checks passed')
