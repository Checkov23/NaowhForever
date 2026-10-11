-- Offline behavior tests. Does not emulate client rendering or security restrictions.
local checks = 0
local function check(name, value) assert(value, name); checks = checks + 1 end
local secret = setmetatable({}, { __tostring = function() error("formatted secret") end })
local settings = { enabled=true, tooltipDisplay=true, tooltipSpellID=true, tooltipItemID=true,
    tooltipNPCID=true, tooltipRestricted="hide", tooltipCopy=true, tooltipModifier="CTRL-SHIFT",
    tooltipKey="C", tooltipCopyFormat="url", tooltipCopyHint=true, copyModifier="CTRL", copyKey="C", copyTooltipIds=true }
local frames, callbacks, combat, focus, ctrl, shift, alt = {}, {}, false, nil, true, true, false
local lastPanel, lastDimmer
local function noop() end
local function Frame()
    local f = { scripts={}, events={}, shown=true, lines={}, cache={} }
    setmetatable(f,{__index=function() return noop end})
    function f:SetScript(k,v) self.scripts[k]=v end
    function f:HookScript(k,v) self.scripts[k]=v end
    function f:RegisterEvent(k) self.events[k]=true end
    function f:SetPropagateKeyboardInput(v) assert(not combat);self.propagate=v end
    function f:EnableKeyboard(v) self.keyboard=v end
    function f:SetText(v) assert(v~=secret);self.text=v end
    function f:GetText() return self.text end
    function f:SetTexture(v) self.texture=v end
    function f:IsForbidden() return self.forbidden==true end
    function f:IsShown() return self.shown end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false;if type(self.onClose)=='function' then self.onClose() end end
    function f:SetFocus() focus=self end
    function f:ClearFocus() if focus==self then focus=nil end end
    function f:GetPrimaryTooltipData() return self.data end
    function f:CreateTexture() return Frame() end
    function f:AddLine(...) self.lines[#self.lines+1]={...} end
    function f:NumLines() return #self.lines end
    function f:GetName() return self.name end
    function f:AddDoubleLine(...) self.lines[#self.lines+1]={...} end
    frames[#frames+1]=f;return f
end
local ns={ L = dofile("Tools/regression/locale_stub.lua").L, Upper = string.upper, Lower = string.lower,Shared={Style=dofile('Tools/regression/shared_style.lua')},THEME={accent={r=0,g=.7,b=1},muted={r=.5,g=.6,b=.7},bg={}},UI={},Print=noop,Apply=noop,
 QoLConstants=dofile('Tools/regression/qol_constants.lua')}
ns.QoLSettings={Get=function(k) return settings[k] end,Set=function(k,v) settings[k]=v end}
ns.MakeModal=function() lastDimmer,lastPanel=Frame(),Frame();return lastDimmer,lastPanel end
ns.Solid=function() return Frame() end;ns.Border=noop;ns.NewEditBox=function() return Frame() end
ns.UI.Keep=function(parent,key,fn) local f=fn(parent);parent.cache[key]=f;return f end
ns.UI.KeepFont=function(parent,key) local f=Frame();parent.cache[key]=f;return f end
ns.UI.SlimScroll=function() return Frame() end
ns.UI.KeepButton=function(parent,key,text,w,h,fn) local f=Frame();f.label=Frame();f.label:SetText(text);f.click=fn;parent.cache[key]=f;return f end
local tooltip=Frame();local title=Frame();title:SetText('Test name')
local env={_G={NaowhForever=ns},GameTooltip=tooltip,ItemRefTooltip=Frame(),ShoppingTooltip1=Frame(),ShoppingTooltip2=Frame(),GameTooltipTextLeft1=title,
    CreateFrame=Frame,Enum={TooltipDataType={Spell=1,Item=2,Unit=3}},SlashCmdList={},
    issecretvalue=function(v) return rawequal(v,secret) end,canaccessvalue=function(v) return not rawequal(v,secret) end,
    issecrettable=function(v) return rawequal(v,secret) end,
    TooltipDataProcessor={AddTooltipPostCall=function(k,v) callbacks[k]=v end},
    C_Spell={GetSpellTexture=function() return 135812 end},C_Item={GetItemIconByID=function() return 134400 end},
    InCombatLockdown=function() return combat end,GetCurrentKeyBoardFocus=function() return focus end,
    IsControlKeyDown=function() return ctrl end,IsShiftKeyDown=function() return shift end,IsAltKeyDown=function() return alt end,
    hooksecurefunc=function(t,k,fn) local old=t[k];t[k]=function(...) old(...);fn(...) end end,
    strsplit=function(delim,s) local a={};for part in s:gmatch('[^'..delim..']+') do a[#a+1]=part end;return unpack(a) end,
}
-- A tooltip's line font strings by name, as the game has them: GameTooltipTextLeft2 and so on.
setmetatable(env,{__index=function(_,key)
 local name,n=tostring(key):match('^(.-)TextLeft(%d+)$')
 local tip=name and rawget(env,name)
 if tip then local line=tip.lines[tonumber(n)];return {GetText=function() return line and line[1] end} end
 return _G[key]
end})
setmetatable(env._G,{__index=env})
-- The copy box is the Core's (ns.ShowCopyBox): load that function alone from it.
local core=assert(io.open('Core/Core.lua','rb')):read('*a'):gsub('\r\n','\n')
local constants=assert(core:match('\n(local MODULE_KEY = .-\n)\nlocal ns = {}\n'),'Core constants')
local first=assert(core:find('local function NewCopyScroll',1,true))
local last=assert(core:find('local function ConfirmHead',first,true))
local copy=assert(loadstring(constants..core:sub(first,last-1)));setfenv(copy,setmetatable({ns=ns},{__index=env}));copy()
for _,path in ipairs({'Shared/UI/CopyCard.lua','NaowhForever_QoL/Interface/GlobalCopy.lua'}) do local chunk=assert(loadfile(path));setfenv(chunk,env);chunk() end
for name,tip in pairs({GameTooltip=tooltip,ItemRefTooltip=env.ItemRefTooltip,ShoppingTooltip1=env.ShoppingTooltip1,
 ShoppingTooltip2=env.ShoppingTooltip2}) do tip.name=name end
local function clear()
 tooltip.lines={}
end
local function show(data)
 clear();tooltip.data=data;callbacks[data.type](tooltip,data)
end
local function boot(event) for _,f in ipairs(frames) do if f.events[event] then f.scripts.OnEvent(f,event) end end end
local function keyboard() for _,f in ipairs(frames) do if f.scripts.OnKeyDown then return f end end end
show({type=1,id=133});check('spell footer',tooltip.lines[2][1]=='Spell ID' and tooltip.lines[2][2]=='133')
check('no hook on the tooltip being cleared',tooltip.scripts.OnTooltipCleared==nil)
callbacks[1](tooltip,tooltip.data);check('no duplicate footer',#tooltip.lines==3)
-- The game builds a tooltip again in place (an item's data arriving): lines cleared, the post-call run again.
tooltip.lines={{'Fireball'}};callbacks[1](tooltip,tooltip.data);check('footer back after a rebuild',#tooltip.lines==4 and tooltip.lines[3][2]=='133')
settings.tooltipCopyHint=false;show({type=1,id=133});check('hint off: the ID stays, its key line goes',#tooltip.lines==2 and tooltip.lines[2][2]=='133');settings.tooltipCopyHint=true
show({type=2,id=6948});check('item footer',tooltip.lines[2][2]=='6948')
show({type=3,guid='Creature-0-1-2-3-12345-0001'});check('NPC entry ID',tooltip.lines[2][2]=='12345')
show({type=3,guid='Vehicle-0-1-2-3-678-0001'});check('vehicle entry ID',tooltip.lines[2][2]=='678')
show({type=3,guid='Player-1-12345'});check('player GUID excluded',#tooltip.lines==0)
show({type=1,id=secret});check('secret hidden by default',#tooltip.lines==0)
settings.tooltipRestricted='hidden';show({type=1,id=secret});check('secret placeholder',tooltip.lines[2][2]=='Hidden' and #tooltip.lines==2)
show({type=3,guid=secret});check('secret GUID placeholder',tooltip.lines[2][2]=='Hidden')
clear();callbacks[1](tooltip,secret);check('secret table ignored',#tooltip.lines==0)
clear();callbacks[1](tooltip,{type=secret,id=133});check('secret type ignored',#tooltip.lines==0)
show({type=1,id=0});check('invalid ID ignored',#tooltip.lines==0)
settings.tooltipSpellID=false;show({type=1,id=133});check('spell toggle',#tooltip.lines==0);settings.tooltipSpellID=true
settings.tooltipDisplay=false;show({type=2,id=6948});check('master toggle',#tooltip.lines==0);settings.tooltipDisplay=true
boot('PLAYER_LOGIN');local k=keyboard();check('shortcut listener enabled',k.keyboard==true)
show({type=1,id=133});k.scripts.OnKeyDown(k,'C');check('Forever spell URL',lastPanel.cache.value.text=='https://www.wowhead.com/forever/spell=133')
check('card gets focus',focus==lastPanel.cache.value);check('listener yields to card',k.keyboard==false)
lastPanel.cache.id.click();check('ID tab',lastPanel.cache.value.text=='133')
lastPanel.cache.link.click();check('URL tab',lastPanel.cache.value.text:find('spell=133',1,true)~=nil)
lastPanel.cache.classic.click();check('Classic, for a page Forever has not got',lastPanel.cache.value.text=='https://www.wowhead.com/classic/spell=133')
lastDimmer:Hide();check('close restores keyboard',focus==nil and k.keyboard==true)
local prior=lastPanel;focus={};k.scripts.OnKeyDown(k,'C');check('typing ignored',lastPanel==prior);focus=nil
shift=false;k.scripts.OnKeyDown(k,'C');check('exact modifier required',lastPanel==prior);shift=true
combat=true;k.scripts.OnKeyDown(k,'C');check('combat does not open card',lastPanel==prior);combat=false
show({type=1,id=secret});k.scripts.OnKeyDown(k,'C');check('secret never copied',lastPanel==prior)
show({type=2,id=6948});k.scripts.OnKeyDown(k,'C');check('Forever item URL',lastPanel.cache.value.text=='https://www.wowhead.com/forever/item=6948');lastDimmer:Hide()
show({type=3,guid='Creature-0-1-2-3-12345-0001'});k.scripts.OnKeyDown(k,'C');check('NPC URL',lastPanel.cache.value.text=='https://www.wowhead.com/forever/npc=12345');lastDimmer:Hide()
settings.tooltipItemID=false;show({type=2,id=6948});prior=lastPanel;k.scripts.OnKeyDown(k,'C');check('disabled type not copied',lastPanel==prior)
ns.QoLSettings.Set('enabled',false);check('disabled listener',k.keyboard==false)
combat=true;ns.QoLSettings.Set('enabled',true);check('combat settings deferred',k.keyboard==false);combat=false;boot('PLAYER_REGEN_ENABLED');check('deferred listener restored',k.keyboard==true)
ns.PreviewTooltipCopyCard();check('preview opens card',lastPanel.cache.name.text=='Fireball - Preview')
lastDimmer:Hide()
tooltip.forbidden=true;show({type=1,id=133});check('forbidden tooltip untouched',#tooltip.lines==0)
prior=lastPanel;k.scripts.OnKeyDown(k,'C');check('forbidden tooltip not copied',lastPanel==prior);tooltip.forbidden=false
show({type=1,id=133});title:SetText('Readable');title.text=secret;k.scripts.OnKeyDown(k,'C');check('secret title uses generic label',lastPanel.cache.name.text=='Spell ID');lastDimmer:Hide();title.text='Test name'
settings.globalCopy=true;shift=false;k.scripts.OnKeyDown(k,'C');check('legacy copy shortcut preserved',lastPanel.cache.scroll.box.text=='133');lastDimmer:Hide()
shift=true;settings.globalCopy=false;ns.QoLSettings.Set('tooltipCopy',false);check('copy disabled independently',k.keyboard==false)
show({type=1,id=133});check('IDs remain with copy disabled',tooltip.lines[2][2]=='133' and #tooltip.lines==2)
ns.QoLSettings.Set('tooltipCopy',true);settings.tooltipItemID=true
tooltip.shown=false;env.ItemRefTooltip.data={type=2,id=6948};env.ItemRefTooltipTextLeft1=title
k.scripts.OnKeyDown(k,'C');check('chat-link tooltip copies its ID',lastPanel.cache.value.text=='https://www.wowhead.com/forever/item=6948');lastDimmer:Hide()
env.ItemRefTooltip.shown=false;prior=lastPanel;k.scripts.OnKeyDown(k,'C');check('hidden chat link is not copied',lastPanel==prior)
callbacks[2](env.ShoppingTooltip1,{type=2,id=6948})
settings.tooltipItemID=true;callbacks[2](env.ShoppingTooltip1,{type=2,id=6948})
check('comparison tooltip does not advertise unsupported shortcut',#env.ShoppingTooltip1.lines==2)
print(checks..' tooltip-display checks passed')
