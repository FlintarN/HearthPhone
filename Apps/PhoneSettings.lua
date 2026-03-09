-- PhoneSettings - Volume/Sound settings for HearthPhone

PhoneSettingsApp = {}

local parent
local controls = {}

local SOUND_CVARS = {
    { cvar = "Sound_MasterVolume",   label = "Master Volume" },
    { cvar = "Sound_MusicVolume",    label = "Music Volume" },
    { cvar = "Sound_SFXVolume",      label = "Effects Volume" },
    { cvar = "Sound_AmbienceVolume", label = "Ambience Volume" },
    { cvar = "Sound_DialogVolume",   label = "Dialog Volume" },
}

local SOUND_TOGGLES = {
    { cvar = "Sound_EnableAllSound",    label = "Enable Sound" },
    { cvar = "Sound_EnableMusic",       label = "Enable Music" },
    { cvar = "Sound_EnableSFX",         label = "Enable Effects" },
    { cvar = "Sound_EnableAmbience",    label = "Enable Ambience" },
    { cvar = "Sound_EnableDialog",      label = "Enable Dialog" },
}

local SLIDER_W = 140
local BAR_H = 6

local function CreateSlider(parentFrame, cvarInfo, yOffset)
    local label = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, yOffset)
    label:SetText(cvarInfo.label)
    label:SetTextColor(0.75, 0.78, 0.85)

    local valText = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    valText:SetPoint("LEFT", label, "LEFT", SLIDER_W + 16, -14)
    valText:SetTextColor(0.5, 0.7, 1.0)

    local sliderBg = parentFrame:CreateTexture(nil, "BACKGROUND")
    sliderBg:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    sliderBg:SetSize(SLIDER_W, BAR_H)
    sliderBg:SetColorTexture(0.15, 0.17, 0.25, 1)

    local sliderFill = parentFrame:CreateTexture(nil, "ARTWORK")
    sliderFill:SetPoint("TOPLEFT", sliderBg, "TOPLEFT")
    sliderFill:SetHeight(BAR_H)
    sliderFill:SetColorTexture(0.3, 0.5, 0.9, 1)

    local hitArea = CreateFrame("Button", nil, parentFrame)
    hitArea:SetPoint("TOPLEFT", sliderBg, "TOPLEFT", 0, 4)
    hitArea:SetSize(SLIDER_W, BAR_H + 8)

    local function UpdateVisual()
        local vol = tonumber(GetCVar(cvarInfo.cvar)) or 0
        local pct = math.floor(vol * 100 + 0.5)
        valText:SetText(pct .. "%")
        sliderFill:SetWidth(math.max(1, SLIDER_W * vol))
    end

    local dragging = false

    local function SetFromMouse()
        local left = sliderBg:GetLeft()
        local right = sliderBg:GetRight()
        if not left or not right or right <= left then return end
        local cx = GetCursorPosition()
        local scale = sliderBg:GetEffectiveScale()
        cx = cx / scale
        local pct = (cx - left) / (right - left)
        pct = math.max(0, math.min(1, pct))
        pct = math.floor(pct * 20 + 0.5) / 20
        SetCVar(cvarInfo.cvar, tostring(pct))
        UpdateVisual()
    end

    hitArea:SetScript("OnMouseDown", function()
        dragging = true
        SetFromMouse()
    end)
    hitArea:SetScript("OnMouseUp", function()
        dragging = false
    end)
    hitArea:SetScript("OnUpdate", function()
        if dragging then SetFromMouse() end
    end)

    return { update = UpdateVisual }
end

local function CreateToggle(parentFrame, cvarInfo, yOffset)
    local row = CreateFrame("Button", nil, parentFrame)
    row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, yOffset)
    row:SetSize(SLIDER_W + 30, 18)

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(cvarInfo.label)
    label:SetTextColor(0.75, 0.78, 0.85)

    local status = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    status:SetPoint("LEFT", label, "RIGHT", 8, 0)

    local function UpdateVisual()
        local val = GetCVar(cvarInfo.cvar)
        if val == "1" then
            status:SetText("ON")
            status:SetTextColor(0.3, 0.8, 0.4)
        else
            status:SetText("OFF")
            status:SetTextColor(0.6, 0.3, 0.3)
        end
    end

    row:SetScript("OnClick", function()
        local val = GetCVar(cvarInfo.cvar)
        SetCVar(cvarInfo.cvar, val == "1" and "0" or "1")
        UpdateVisual()
    end)

    return { update = UpdateVisual }
end

function PhoneSettingsApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", 0, -8)
    title:SetText("Settings")
    title:SetTextColor(0.8, 0.83, 0.9)

    -- Scroll container
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetPoint("TOPLEFT", 0, -26)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 2)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(SLIDER_W + 60)
    scrollFrame:SetScrollChild(content)

    local scrollOffset = 0
    local contentHeight = 0

    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = math.max(0, contentHeight - scrollFrame:GetHeight())
        scrollOffset = math.max(0, math.min(maxScroll, scrollOffset - delta * 20))
        scrollFrame:SetVerticalScroll(scrollOffset)
    end)
    scrollFrame:EnableMouseWheel(true)

    local y = -4

    -- Volume header
    local volHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    volHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    volHeader:SetText("Volume")
    volHeader:SetTextColor(0.5, 0.7, 1.0)
    y = y - 18

    for _, info in ipairs(SOUND_CVARS) do
        local s = CreateSlider(content, info, y)
        table.insert(controls, s)
        y = y - 34
    end

    y = y - 8

    -- Toggles header
    local togHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    togHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    togHeader:SetText("Sound Toggles")
    togHeader:SetTextColor(0.5, 0.7, 1.0)
    y = y - 18

    for _, info in ipairs(SOUND_TOGGLES) do
        local t = CreateToggle(content, info, y)
        table.insert(controls, t)
        y = y - 22
    end

    contentHeight = math.abs(y) + 10
    content:SetHeight(contentHeight)
end

function PhoneSettingsApp:OnShow()
    for _, c in ipairs(controls) do
        c.update()
    end
end

function PhoneSettingsApp:OnHide()
end
