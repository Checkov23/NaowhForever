-- Settings.lua: every settings page, declared once (ns.Shared.Settings): pages, cards, rows, what was changed, reset and the search index.
local ns = _G.NaowhForever
local Shared = ns.Shared

local KINDS = { "toggle", "slider", "choice", "colour", "font", "texture", "sound", "text", "button", "binding" }
local FONT_SIZE_RANGE = { 6, 32, 1 }
local BG_ALPHA_RANGE = Shared.Style.ALPHA_RANGE
local BG_ALPHA_SCALE = Shared.Style.PERCENT_SCALE
local DEFAULT_ORDER = 100
local SAME_WITHIN = 0.002
local NO_KEYS = {}
local CARD_UID = "^(.*):([^:]+)$"
local TEXT_TEXT = "Text"
local TEXT_BAR = "Bar"
local TEXT_BACKGROUND = "Background"
local TEXT_FONT = "Font"
local TEXT_FONT_SIZE = "Font Size"
local TEXT_OUTLINE = "Outline"
local TEXT_BAR_TEXTURE = "Bar Texture"
local TEXT_BG_ALPHA = "Background Opacity"
local TEXT_PERCENT = "%"
local TEXT_OUTLINE_HELP = "A black outline round the text, in place of the soft shadow."
local TEXT_BACKGROUND_HELP = "A card behind the text, a soft dark fade, or nothing at all."
local TEXT_NEEDS = "Needs %s"
local ERROR_NO_KIND = "Settings: a row without a kind on "
local ERROR_CARD = "Settings: a card needs an id and a name"
local ERROR_TWO_CARDS = "Settings: two cards named "
local ERROR_INFO = "Settings: an info card needs an id and a name"

local Settings = {}
Shared.Settings = Settings

local pages = {}
local open = {}

local Page = {}
Page.__index = Page

local function LookKey(prefix, keys, suffix)
    local key = keys[suffix]
    if key ~= nil then return key end
    if prefix == "" then return suffix:sub(1, 1):lower() .. suffix:sub(2) end
    return prefix .. suffix
end

local function AddLook(look, title, suffix, row)
    local key = LookKey(look.prefix, look.keys, suffix)
    if not key then return end
    local rows = look.rows
    if look.group ~= title then
        look.group = title
        rows[#rows + 1] = Settings.Group(title)
    end
    row.key, row.needs, row.why = key, look.opts.needs, look.opts.why
    rows[#rows + 1] = row
end

local function AddLookText(look)
    local opts = look.opts
    if not opts.text then return end
    AddLook(look, TEXT_TEXT, "Font", { label = TEXT_FONT, font = true })
    AddLook(look, TEXT_TEXT, "FontSize", { label = TEXT_FONT_SIZE, slider = opts.size or FONT_SIZE_RANGE })
    AddLook(look, TEXT_TEXT, "Outline", { label = TEXT_OUTLINE, choice = Shared.Parts.HUD_OUTLINES,
        help = TEXT_OUTLINE_HELP })
end

local function AddLookBackground(look)
    local opts = look.opts
    if opts.background == "card" then
        AddLook(look, TEXT_BACKGROUND, "Background", { label = TEXT_BACKGROUND,
            choice = Shared.Parts.HUD_BACKGROUNDS, help = TEXT_BACKGROUND_HELP })
    elseif opts.background == "alpha" then
        AddLook(look, opts.bar and TEXT_BAR or TEXT_BACKGROUND, "BgAlpha", { label = TEXT_BG_ALPHA,
            slider = BG_ALPHA_RANGE, unit = TEXT_PERCENT, scale = BG_ALPHA_SCALE })
    end
end

local function Flatten(rows)
    local out = {}
    for _, row in ipairs(rows) do
        if row[1] then
            for _, inner in ipairs(row) do out[#out + 1] = inner end
        else
            out[#out + 1] = row
        end
    end
    return out
end

local function KindOf(row)
    for _, kind in ipairs(KINDS) do
        if row[kind] ~= nil then return kind end
    end
end

local function BindColour(row, store, key)
    row.get = function()
        local c = store.Get(key)
        if type(c) ~= "table" then return 1, 1, 1, 1 end
        return c.r, c.g, c.b, c.a
    end
    row.set = function(r, g, b, a)
        store.Set(key, { r = r, g = g, b = b, a = row.colour == "alpha" and a or nil })
    end
end

local function BindStore(row)
    local store, key = row.store, row.key
    if not (key and store and not row.get) then return end
    if row.kind == "colour" then
        BindColour(row, store, key)
        return
    end
    row.get = function() return store.Get(key) end
    row.set = function(v) store.Set(key, v) end
end

local function BindScale(row)
    local scale = row.scale
    if not (scale and row.get) then return end
    local get, set = row.get, row.set
    row.get = function()
        local v = get()
        return v and math.floor(v / scale + 0.5) or nil
    end
    row.set = function(v) set(v * scale) end
end

local function Icons(row)
    if not row.cog or row.cogIcon then return end
    local cog = { tip = row.cog.tip, cogFor = row }
    local icons = { cog }
    for _, icon in ipairs(row.icons or NO_KEYS) do icons[#icons + 1] = icon end
    row.cogIcon, row.icons = cog, icons
end

local function Normalise(row, card)
    row.card = card
    if row.group then
        row.kind = "group"
        return row
    end
    if row.under ~= nil then row.hidden = true end
    Icons(row)
    row.kind = KindOf(row) or row.kind
    assert(row.kind, ERROR_NO_KIND .. card.uid .. ": " .. tostring(row.label))
    row.store = row.store or card.store
    BindStore(row)
    BindScale(row)
    return row
end

local function Switch(card)
    local switch = card.switch
    if type(switch) == "string" then
        local store = card.store
        card.switchGet = function() return store.Get(switch) end
        card.switchSet = function(v) store.Set(switch, v and true or false) end
        card.switchSetting = { store = store, key = switch, kind = "toggle" }
    elseif type(switch) == "table" then
        card.switchGet, card.switchSet = switch.get, switch.set
    end
end

local function Before(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.seq < b.seq
end

local function Insert(page, item)
    item.seq = #page.items + 1
    page.items[#page.items + 1] = item
    table.sort(page.items, Before)
end

local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if type(v) == "number" and type(b[k]) == "number" then
            if math.abs(v - b[k]) > SAME_WITHIN then return false end
        elseif type(v) == "table" then
            if not Same(v, b[k]) then return false end
        elseif b[k] ~= v then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end

local function LabelOf(card, key)
    for _, row in ipairs(card.rows) do
        if row.key == key then return row.label end
    end
end

local function Needing(row, key)
    local label = LabelOf(row.card, key)
    return true, row.why or (label and ns.L(TEXT_NEEDS, ns.L(label)))
end

local function CountCards(page)
    local cards, first = 0, nil
    for _, item in ipairs(page.items) do
        if not item.window then
            cards = cards + 1
            first = first or item
        end
    end
    return cards, first
end

local function Static(text)
    return type(text) == "string" and text or ""
end

local function IndexWindow(item, add)
    add(item.uid, item.text or Static(item.headline), Static(item.headline) .. " " .. Static(item.detail))
end

local function SearchText(spec)
    if not spec.search then return spec.help end
    return (spec.help or "") .. " " .. spec.search
end

local function IndexCard(item, add)
    add(item.uid, item.name, SearchText(item))
    local group
    for _, row in ipairs(Settings.Rows(item)) do
        if row.kind == "group" then
            group = row.group
        elseif row.label then
            add(item.uid, row.label, SearchText(row), item.name, group)
        end
    end
end

function Page:Card(spec)
    assert(spec.id and spec.name, ERROR_CARD)
    assert(not self.cards[spec.id], ERROR_TWO_CARDS .. spec.id .. " on " .. self.key)
    spec.page = self
    spec.uid = self.key .. ":" .. spec.id
    spec.store = spec.store or self.store
    spec.order = spec.order or DEFAULT_ORDER
    if type(spec.rows) == "function" then
        spec.rowsFn, spec.rows = spec.rows, {}
    end
    spec.rows = Flatten(spec.rows or {})
    Switch(spec)
    for _, row in ipairs(spec.rows) do Normalise(row, spec) end
    self.cards[spec.id] = spec
    Insert(self, spec)
    return spec
end

function Page:Window(spec)
    spec.window = true
    if spec.text then spec.uid = self.key .. ":" .. spec.text end
    spec.order = spec.order or 0
    Insert(self, spec)
    return spec
end

function Page:Info(spec)
    assert(spec.id and spec.name, ERROR_INFO)
    spec.info = true
    spec.page = self
    spec.uid = self.key .. ":" .. spec.id
    spec.order = spec.order or #self.items + 1
    spec.rows = spec.lines or {}
    self.cards[spec.id] = spec
    Insert(self, spec)
    return spec
end

Settings.pages = pages

function Settings.Page(key, store)
    local page = pages[key]
    if not page then
        page = setmetatable({ key = key, items = {}, cards = {} }, Page)
        pages[key] = page
    end
    page.store = store or page.store
    return page
end

function Settings.Group(title)
    return { group = title }
end

function Settings.Look(prefix, opts)
    local look = { prefix = prefix, keys = opts.keys or NO_KEYS, rows = {}, opts = opts }
    AddLookText(look)
    if opts.bar then AddLook(look, TEXT_BAR, "Texture", { label = TEXT_BAR_TEXTURE, texture = opts.bar }) end
    AddLookBackground(look)
    return look.rows
end

function Settings.Rows(card)
    if card.rowsFn then
        card.rows = Flatten(card.rowsFn())
        for _, row in ipairs(card.rows) do
            if row.card ~= card then Normalise(row, card) end
        end
    end
    return card.rows
end

function Settings.Openable(card)
    return card.studio ~= nil or card.info or #Settings.Rows(card) > 0
end

function Settings.Changed(row)
    local store, key, field = row.store, row.key, row.field
    if not (key and store and store.Raw) then return false end
    local raw, default = store.Raw(key), store.Default(key)
    if field then
        if type(raw) ~= "table" then return false end
        raw, default = raw[field], default[field]
    end
    if raw == nil then return false end
    return not Same(raw, default)
end

function Settings.ChangedCount(card)
    local n = 0
    for _, row in ipairs(card.rows) do
        if row.kind ~= "group" and not row.lent and Settings.Changed(row) then n = n + 1 end
    end
    return n
end

function Settings.ResetRow(row)
    local store, key = row.store, row.key
    if not (key and store and store.Default and Settings.Changed(row)) then return end
    local value = Copy(store.Default(key))
    if row.field then
        local entries = Copy(store.Raw(key))
        entries[row.field] = value[row.field]
        value = entries
    end
    store.Set(key, value)
end

function Settings.Reset(card)
    for _, row in ipairs(card.rows) do
        if not row.lent then Settings.ResetRow(row) end
    end
end

function Settings.UnderOf(card, label)
    for _, row in ipairs(card.rows) do
        if row.label == label and row.under ~= nil then return row.under end
    end
end

function Settings.CogChanged(card, label)
    for _, row in ipairs(card.rows) do
        if row.under == label and Settings.Changed(row) then return true end
    end
    return false
end

function Settings.Off(row)
    local card = row.card
    if card.switchGet and not row.always and not card.switchGet() then return true end
    local needs = row.needs
    if not needs then return false end
    if type(needs) == "function" then
        if needs() then return false end
        return true, row.why
    end
    local store = row.store
    if type(needs) == "string" then
        if store.Get(needs) then return false end
        return Needing(row, needs)
    end
    for i = 1, #needs do
        if not store.Get(needs[i]) then return Needing(row, needs[i]) end
    end
    return false
end

function Settings.IsOpen(card)
    local state = open[card.uid]
    if state ~= nil then return state end
    if card.info then return card.open == true end
    if card.collapsed then return false end
    local cards, first = CountCards(card.page)
    return cards == 1 or (first == card and card.studio ~= nil)
end

function Settings.SetOpen(card, on)
    open[card.uid] = on and true or false
end

function Settings.Index(pageKey, add)
    local page = pages[pageKey]
    if not page then return false end
    for _, item in ipairs(page.items) do
        if item.window then
            if item.uid then IndexWindow(item, add) end
        elseif not item.info then
            IndexCard(item, add)
        end
    end
    return true
end

function Settings.CardOf(uid)
    local pageKey, id = uid:match(CARD_UID)
    local page = pageKey and pages[pageKey]
    return page and page.cards[id]
end
