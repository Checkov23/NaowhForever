local f = assert(io.open(arg[1], "rb"))
local source = f:read("*a"); f:close()
local chunk = assert(source:match("(local LOGO = .*)"))
for _, saved in ipairs({{}, {minimap={minimapPos=47,hide=true}}}) do
    local event, object, registered, clicked, opened
    local modules = {}
    local original = saved.minimap
    local ns = { MEDIA = dofile("Tools/regression/core_media.lua"), AccountSettings=function() return saved end, L=function(t) return t end,
        ToggleOptionsWindow=function() clicked=true end, SaveModuleDefaults=function() end,
        ThemeTint=function(_,literal) return literal end }
    local frame = {
        SetScript=function(_,_,fn) event=fn end,
        RegisterEvent=function(_,name) assert(name=="PLAYER_LOGIN" and event) end,
        UnregisterEvent=function(_,name) assert(name=="PLAYER_LOGIN") end,
    }
    local libs = {
        ["LibDataBroker-1.1"]={NewDataObject=function(_,name,data)
            if name~="NaowhForever" then modules[name]={data=data}; return data end
            object=data; return data end},
        ["LibDBIcon-1.0"]={Register=function(_,name,data,db)
            if name~="NaowhForever" then assert(modules[name].data==data); modules[name].db=db; return end
            assert(data==object and db==saved.minimap)
            registered=true end},
    }
    local dq = { name="Dungeon Quests", command="dq", short="DQ", micro=true, icon="dq" }
    local gear = { name="Gear Sets", command="gear", short="Gear", icon="gear" }
    local env = setmetatable({ns=ns,CreateFrame=function() return frame end,
        LibStub=function(name) return assert(libs[name]) end, hooksecurefunc=function() end,
        MODULES={ {name="QoL"}, dq, gear },
        MinimapButtonOn=function(mod) return mod.micro==true end,
        OpenModule=function(mod) opened=mod end, Loaded=function() return true end}, {__index=_G})
    local launcher = assert(loadstring(chunk, "launcher")); setfenv(launcher, env); launcher()
    assert(not registered)
    event(frame)
    assert(registered and object.type=="launcher")
    if original then assert(saved.minimap==original and original.minimapPos==47 and original.hide)
    else assert(saved.minimap.minimapPos==220) end
    object.OnClick(); assert(clicked)
    local lines=0
    object.OnTooltipShow({AddLine=function(_,text) assert(type(text)=="string"); lines=lines+1 end})
    assert(lines==3)
    -- One launcher per module with a command, hidden while its minimap switch is off.
    assert(modules.NaowhForeverDQ and modules.NaowhForeverGear and not modules.NaowhForeverQoL)
    assert(modules.NaowhForeverDQ.data.icon=="dq" and modules.NaowhForeverDQ.db.hide==false)
    assert(modules.NaowhForeverGear.db.hide==true)
    assert(saved.moduleButtons["Dungeon Quests"]==modules.NaowhForeverDQ.db)
    modules.NaowhForeverGear.data.OnClick(); assert(opened==gear)
end
-- Feature launchers: the broker launcher is made at login for the Top Bar, the minimap button only while it is on.
for _, saved in ipairs({{}, {featureButtons={Scrap={minimapPos=10,hide=false}}}}) do
    local event, objects, registered, icons, shown, hidden, opened = nil, {}, {}, {}, {}, {}, 0
    local ns = { MEDIA = dofile("Tools/regression/core_media.lua"), AccountSettings=function() return saved end, L=function(t) return t end,
        ToggleOptionsWindow=function() end, SaveModuleDefaults=function() end,
        ThemeTint=function(_,literal) return literal end }
    local frame = { SetScript=function(_,_,fn) event=fn end, RegisterEvent=function() end, UnregisterEvent=function() end }
    local libs = {
        ["LibDataBroker-1.1"]={NewDataObject=function(_,name,data) objects[name]=data; return data end},
        ["LibDBIcon-1.0"]={Register=function(_,name,data,db) registered[name]=db; icons[name]=data end,
            Show=function(_,name) shown[name]=true end, Hide=function(_,name) hidden[name]=true end},
    }
    local env = setmetatable({ns=ns,CreateFrame=function() return frame end,
        LibStub=function(name) return assert(libs[name]) end, hooksecurefunc=function() end,
        MODULES={}, MinimapButtonOn=function() return false end,
        OpenModule=function() end, Loaded=function() return true end}, {__index=_G})
    local launcher = assert(loadstring(chunk, "launcher")); setfenv(launcher, env); launcher()
    local scrap = { id="Scrap", name="Scrap List", icon="scrap", tooltip="Click to open the Scrap List.",
        open=function() opened=opened+1 end }
    ns.RegisterMinimapFeature(scrap)
    assert(#ns.MinimapFeatures==1)
    event(frame)
    if saved.featureButtons then
        assert(registered.NaowhForeverScrap==saved.featureButtons.Scrap and ns.MinimapFeatureOn(scrap), "a saved on button is built at login")
    else
        assert(objects.NaowhForeverScrap and not registered.NaowhForeverScrap and not ns.MinimapFeatureOn(scrap) and saved.featureButtons==nil,
            "off by default: the launcher exists for the Top Bar, no minimap button is built")
        ns.SetMinimapFeature(scrap, false)
        assert(not registered.NaowhForeverScrap and not hidden.NaowhForeverScrap, "off stays free")
        ns.SetMinimapFeature(scrap, true)
        assert(registered.NaowhForeverScrap and registered.NaowhForeverScrap.hide==false and registered.NaowhForeverScrap.minimapPos==220
            and shown.NaowhForeverScrap and ns.MinimapFeatureOn(scrap), "turning it on builds the button")
    end
    local object = objects.NaowhForeverScrap
    assert(icons.NaowhForeverScrap==object, "the minimap button shows the launcher made at login")
    assert(object.type=="launcher" and object.icon=="scrap" and object.label=="Scrap List")
    object.OnClick(); assert(opened==1)
    local lines=0
    object.OnTooltipShow({AddLine=function() lines=lines+1 end})
    assert(lines==2)
    ns.SetMinimapFeature(scrap, false)
    assert(hidden.NaowhForeverScrap and not ns.MinimapFeatureOn(scrap) and saved.featureButtons.Scrap.hide==true, "turning it off hides it")
end
print("PASS: login registration, fresh/saved position, click and tooltip, module and feature launchers, feature launchers while their icon is off")
