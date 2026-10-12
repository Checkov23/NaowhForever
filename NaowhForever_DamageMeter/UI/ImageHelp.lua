-- ImageHelp.lua: a dialog that says how to put a picture of your own behind a window.
local ns = _G.NaowhForever

local DM = ns.DamageMeter

local DIALOG = "damageMeterImages"
local WIDTH, PAD, BUTTON_W, BUTTON_H = 480, 16, 90, 24
local HEAD_SIZE, TITLE_SIZE, TEXT_SIZE = 14, 12, 11
local HEAD_GAP, TITLE_GAP, BLOCK_GAP, BUTTON_GAP = 12, 2, 10, 14
local TEXT_HEAD, TEXT_CLOSE = "Add Your Own Image", "Close"

DM.IMAGE_HELP = {
    { title = "The picture", text = "A .png, .tga or .blp file. Make its width and height powers of two, "
        .. "such as 128, 256, 512 or 1024, to be safe; a small one, 128 or 256, is good for a pattern that "
        .. "is repeated with Tile Image, and Tile Size says how wide each repeat is. A .jpg is most "
        .. "likely not read by the game: open it and save it as a .png first." },
    { title = "Where it goes", text = "In the game's Interface\\AddOns folder make a folder of your own, "
        .. "such as MyBackgrounds, and put the file in it, for instance MyBackgrounds\\panel.png. A folder "
        .. "of your own is not touched when add-ons are updated. Restart the game once so it finds "
        .. "the file." },
    { title = "What to do in the settings", text = "In the Window card, under Picture, pick Your Own Picture "
        .. "in Image, and write the path from Interface in Custom Image, with backslashes and with the "
        .. "file's extension: Interface\\AddOns\\MyBackgrounds\\panel.png. Pick None or another "
        .. "picture in Image to go back." },
    { title = "If it is a green square", text = "The game did not find the file. Check the folder name, "
        .. "the spelling and the extension, and that the game was restarted after the file was added." },
    { title = "Or a media add-on", text = "An add-on that adds pictures to the shared media, such as a "
        .. "SharedMedia pack, lists them under Image. The game's plain ones, Solid among them, are left out." },
}

function DM.ShowImageHelp()
    local UI, T = ns.UI, ns.THEME
    local dimmer, panel = ns.MakeModal(WIDTH, BUTTON_H, DIALOG)
    local head = UI.KeepFont(panel, "head", HEAD_SIZE, "OUTLINE", T.accent)
    head:SetPoint("TOPLEFT", PAD, -PAD)
    head:SetText(TEXT_HEAD)
    local above, gap, used = head, HEAD_GAP, PAD + head:GetStringHeight()
    for i, part in ipairs(DM.IMAGE_HELP) do
        local title = UI.KeepFont(panel, "title" .. i, TITLE_SIZE, "OUTLINE", T.fg)
        title:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
        title:SetWidth(WIDTH - 2 * PAD)
        title:SetJustifyH("LEFT")
        title:SetText(part.title)
        local text = UI.KeepFont(panel, "text" .. i, TEXT_SIZE, nil, T.muted)
        text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -TITLE_GAP)
        text:SetWidth(WIDTH - 2 * PAD)
        text:SetJustifyH("LEFT")
        text:SetText(part.text)
        used = used + gap + title:GetStringHeight() + TITLE_GAP + text:GetStringHeight()
        above, gap = text, BLOCK_GAP
    end
    panel:SetHeight(used + BUTTON_GAP + BUTTON_H + PAD)
    UI.KeepButton(panel, "close", TEXT_CLOSE, BUTTON_W, BUTTON_H, function() dimmer:Hide() end)
        :SetPoint("BOTTOM", panel, "BOTTOM", 0, PAD)
    dimmer:Show()
end
