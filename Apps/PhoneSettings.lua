-- PhoneSettings - Settings app for HearthPhone

PhoneSettingsApp = {}

local parent
local controls = {}

local SOUND_ENTRIES = {
    { vol = "Sound_MasterVolume",   toggle = "Sound_EnableAllSound",  label = "Master" },
    { vol = "Sound_MusicVolume",    toggle = "Sound_EnableMusic",     label = "Music" },
    { vol = "Sound_SFXVolume",      toggle = "Sound_EnableSFX",       label = "Effects" },
    { vol = "Sound_AmbienceVolume", toggle = "Sound_EnableAmbience",  label = "Ambience" },
    { vol = "Sound_DialogVolume",   toggle = "Sound_EnableDialog",    label = "Dialog" },
}

local SLIDER_W = 140
local BAR_H = 6

---------------------------------------------------------------------------
-- Volume row: slider + mute toggle
---------------------------------------------------------------------------
local function CreateVolumeRow(parentFrame, entry, yOffset)
    local label = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, yOffset)
    label:SetText(entry.label)
    label:SetTextColor(0.75, 0.78, 0.85)

    local valText = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    valText:SetPoint("LEFT", label, "RIGHT", 4, 0)
    valText:SetTextColor(0.5, 0.7, 1.0)

    -- Mute button at the right side
    local muteBtn = CreateFrame("Button", nil, parentFrame)
    muteBtn:SetPoint("TOPLEFT", label, "TOPLEFT", SLIDER_W + 10, 0)
    muteBtn:SetSize(20, 20)
    local muteIcon = muteBtn:CreateTexture(nil, "ARTWORK")
    muteIcon:SetAllPoints()
    muteIcon:SetTexture("Interface\\Common\\VoiceChat-Speaker")

    -- Red diagonal strike (bottom-left to top-right) using stacked segments
    local muteLines = {}
    local SEGMENTS = 5
    local btnSize = 20
    local segH = 2
    for i = 0, SEGMENTS - 1 do
        local seg = muteBtn:CreateTexture(nil, "OVERLAY")
        local frac = i / SEGMENTS
        local x = 2 + frac * (btnSize - 4)
        local y = 2 + frac * (btnSize - 4)
        seg:SetPoint("BOTTOMLEFT", muteBtn, "BOTTOMLEFT", x, y)
        seg:SetSize((btnSize - 4) / SEGMENTS, segH)
        seg:SetColorTexture(0.8, 0.2, 0.2, 1)
        seg:Hide()
        muteLines[#muteLines + 1] = seg
    end

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
        local vol = tonumber(GetCVar(entry.vol)) or 0
        local enabled = GetCVar(entry.toggle) == "1"
        local pct = math.floor(vol * 100 + 0.5)
        if enabled then
            valText:SetText(pct .. "%")
            valText:SetTextColor(0.5, 0.7, 1.0)
            sliderFill:SetColorTexture(0.3, 0.5, 0.9, 1)
            sliderFill:SetWidth(math.max(1, SLIDER_W * vol))
            muteIcon:SetVertexColor(1, 1, 1)
            for _, seg in ipairs(muteLines) do seg:Hide() end
        else
            valText:SetText("Muted")
            valText:SetTextColor(0.5, 0.4, 0.4)
            sliderFill:SetColorTexture(0.3, 0.25, 0.25, 1)
            sliderFill:SetWidth(math.max(1, SLIDER_W * vol))
            muteIcon:SetVertexColor(0.7, 0.3, 0.3)
            for _, seg in ipairs(muteLines) do seg:Show() end
        end
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
        SetCVar(entry.vol, tostring(pct))
        UpdateVisual()
    end

    hitArea:SetScript("OnMouseDown", function() dragging = true; SetFromMouse() end)
    hitArea:SetScript("OnMouseUp", function() dragging = false end)
    hitArea:SetScript("OnUpdate", function() if dragging then SetFromMouse() end end)

    muteBtn:SetScript("OnClick", function()
        local val = GetCVar(entry.toggle)
        SetCVar(entry.toggle, val == "1" and "0" or "1")
        UpdateVisual()
    end)

    return { update = UpdateVisual }
end

---------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------
local currentView
local mainFrame, phoneFrame, volumeFrame, notifFrame, displayFrame, aboutFrame
local titleText, backBtn

local function ShowView(view)
    currentView = view
    mainFrame:SetShown(view == "main")
    phoneFrame:SetShown(view == "phone")
    volumeFrame:SetShown(view == "volume")
    notifFrame:SetShown(view == "notif")
    displayFrame:SetShown(view == "display")
    aboutFrame:SetShown(view == "about")

    if backBtn then
        backBtn:SetShown(view ~= "main")
    end

    if view == "main" then
        titleText:SetText("Settings")
    elseif view == "phone" then
        titleText:SetText("Phone")
    elseif view == "volume" then
        titleText:SetText("Volume")
    elseif view == "notif" then
        titleText:SetText("Notifications")
    elseif view == "display" then
        titleText:SetText("Display")
    elseif view == "about" then
        titleText:SetText("About")
    end

    for _, c in ipairs(controls) do
        c.update()
    end
end

---------------------------------------------------------------------------
-- Menu row helper
---------------------------------------------------------------------------
local function CreateMenuRow(parentFrame, label, yOffset, onClick)
    local row = CreateFrame("Button", nil, parentFrame)
    row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 6, yOffset)
    row:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -6, yOffset)
    row:SetHeight(28)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.17, 0.22, 0.8)

    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", 10, 0)
    text:SetText(label)
    text:SetTextColor(0.8, 0.83, 0.9)

    local arrow = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText(">")
    arrow:SetTextColor(0.5, 0.55, 0.65)

    row:SetScript("OnEnter", function() bg:SetColorTexture(0.2, 0.23, 0.3, 0.9) end)
    row:SetScript("OnLeave", function() bg:SetColorTexture(0.15, 0.17, 0.22, 0.8) end)
    row:SetScript("OnClick", onClick)

    return row
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
function PhoneSettingsApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    -- Title bar (also acts as back button on subpages)
    titleText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("TOP", 0, -8)
    titleText:SetText("Settings")
    titleText:SetTextColor(0.8, 0.83, 0.9)

    backBtn = CreateFrame("Button", nil, parent)
    backBtn:SetPoint("TOPLEFT", 6, -5)
    backBtn:SetSize(60, 16)
    backBtn:Hide()

    local backChevron = backBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    backChevron:SetPoint("LEFT", 0, 0)
    backChevron:SetText("<")
    backChevron:SetTextColor(0.35, 0.6, 1.0)

    local backLabel = backBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    backLabel:SetPoint("LEFT", backChevron, "RIGHT", 2, 0)
    backLabel:SetText("Settings")
    backLabel:SetTextColor(0.35, 0.6, 1.0)

    backBtn:SetScript("OnEnter", function()
        backChevron:SetTextColor(0.55, 0.78, 1.0)
        backLabel:SetTextColor(0.55, 0.78, 1.0)
    end)
    backBtn:SetScript("OnLeave", function()
        backChevron:SetTextColor(0.35, 0.6, 1.0)
        backLabel:SetTextColor(0.35, 0.6, 1.0)
    end)
    backBtn:SetScript("OnClick", function()
        if currentView ~= "main" then
            ShowView("main")
        end
    end)

    -----------------------------------------------------------------------
    -- Main menu
    -----------------------------------------------------------------------
    mainFrame = CreateFrame("Frame", nil, parent)
    mainFrame:SetPoint("TOPLEFT", 0, -26)
    mainFrame:SetPoint("BOTTOMRIGHT")

    CreateMenuRow(mainFrame, "Phone",         -6,   function() ShowView("phone") end)
    CreateMenuRow(mainFrame, "Display",       -38,  function() ShowView("display") end)
    CreateMenuRow(mainFrame, "Notifications", -70,  function() ShowView("notif") end)
    CreateMenuRow(mainFrame, "Volume",        -102, function() ShowView("volume") end)
    CreateMenuRow(mainFrame, "About",         -134, function() ShowView("about") end)

    -----------------------------------------------------------------------
    -- Phone subpage (scale)
    -----------------------------------------------------------------------
    phoneFrame = CreateFrame("Frame", nil, parent)
    phoneFrame:SetPoint("TOPLEFT", 0, -26)
    phoneFrame:SetPoint("BOTTOMRIGHT")
    phoneFrame:Hide()

    local SCALE_MIN = 0.5
    local SCALE_MAX = 2.0
    local SCALE_STEP = 0.1

    local function GetPhoneScale()
        return HearthPhoneDB and HearthPhoneDB.phoneScale or 1.0
    end

    local function ApplyScale(val)
        HearthPhoneDB.phoneScale = val
        if HearthPhoneFrame then
            HearthPhoneFrame:SetScale(val)
        end
    end

    local py = -10
    local scaleLabel = phoneFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", phoneFrame, "TOPLEFT", 10, py)
    scaleLabel:SetText("Phone Scale")
    scaleLabel:SetTextColor(0.75, 0.78, 0.85)

    local scaleValText = phoneFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scaleValText:SetPoint("LEFT", scaleLabel, "LEFT", SLIDER_W + 16, -14)
    scaleValText:SetTextColor(0.5, 0.7, 1.0)

    local scaleBg = phoneFrame:CreateTexture(nil, "BACKGROUND")
    scaleBg:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -2)
    scaleBg:SetSize(SLIDER_W, BAR_H)
    scaleBg:SetColorTexture(0.15, 0.17, 0.25, 1)

    local scaleFill = phoneFrame:CreateTexture(nil, "ARTWORK")
    scaleFill:SetPoint("TOPLEFT", scaleBg, "TOPLEFT")
    scaleFill:SetHeight(BAR_H)
    scaleFill:SetColorTexture(0.3, 0.5, 0.9, 1)

    local scaleHit = CreateFrame("Button", nil, phoneFrame)
    scaleHit:SetPoint("TOPLEFT", scaleBg, "TOPLEFT", 0, 4)
    scaleHit:SetSize(SLIDER_W, BAR_H + 8)

    local function UpdateScaleVisual()
        local val = GetPhoneScale()
        local norm = (val - SCALE_MIN) / (SCALE_MAX - SCALE_MIN)
        scaleValText:SetText(string.format("%.1fx", val))
        scaleFill:SetWidth(math.max(1, SLIDER_W * norm))
    end

    local scaleDragging = false
    local dragLeft, dragRight

    local function CalcScaleFromMouse()
        if not dragLeft or not dragRight or dragRight <= dragLeft then return GetPhoneScale() end
        local cx = GetCursorPosition()
        local pct = (cx - dragLeft) / (dragRight - dragLeft)
        pct = math.max(0, math.min(1, pct))
        local val = SCALE_MIN + pct * (SCALE_MAX - SCALE_MIN)
        val = math.floor(val / SCALE_STEP + 0.5) * SCALE_STEP
        return math.max(SCALE_MIN, math.min(SCALE_MAX, val))
    end

    local function PreviewScale()
        local val = CalcScaleFromMouse()
        local norm = (val - SCALE_MIN) / (SCALE_MAX - SCALE_MIN)
        scaleValText:SetText(string.format("%.1fx", val))
        scaleFill:SetWidth(math.max(1, SLIDER_W * norm))
    end

    scaleHit:SetScript("OnMouseDown", function()
        local scale = scaleBg:GetEffectiveScale()
        dragLeft = scaleBg:GetLeft() * scale
        dragRight = scaleBg:GetRight() * scale
        scaleDragging = true
        PreviewScale()
    end)
    scaleHit:SetScript("OnMouseUp", function()
        if scaleDragging then
            local val = CalcScaleFromMouse()
            ApplyScale(val)
            UpdateScaleVisual()
        end
        scaleDragging = false
    end)
    scaleHit:SetScript("OnUpdate", function()
        if scaleDragging then PreviewScale() end
    end)

    table.insert(controls, { update = UpdateScaleVisual })

    -- PIN Lock setting
    local pinLabel = phoneFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pinLabel:SetPoint("TOPLEFT", phoneFrame, "TOPLEFT", 10, py - 40)
    pinLabel:SetText("PIN Lock")
    pinLabel:SetTextColor(0.75, 0.78, 0.85)

    local pinStatusText = phoneFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pinStatusText:SetPoint("LEFT", pinLabel, "RIGHT", 8, 0)
    pinStatusText:SetTextColor(0.5, 0.7, 1.0)

    local pinBtn = CreateFrame("Button", nil, phoneFrame)
    pinBtn:SetPoint("TOPLEFT", pinLabel, "BOTTOMLEFT", 0, -4)
    pinBtn:SetSize(SLIDER_W, 20)

    local pinBtnBg = pinBtn:CreateTexture(nil, "BACKGROUND")
    pinBtnBg:SetAllPoints()
    pinBtnBg:SetColorTexture(0.2, 0.24, 0.32, 0.9)

    local pinBtnTxt = pinBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pinBtnTxt:SetPoint("CENTER")
    pinBtnTxt:SetTextColor(0.5, 0.7, 1.0)

    pinBtn:SetScript("OnEnter", function() pinBtnBg:SetColorTexture(0.28, 0.32, 0.42, 1) end)
    pinBtn:SetScript("OnLeave", function() pinBtnBg:SetColorTexture(0.2, 0.24, 0.32, 0.9) end)

    -- PIN entry dialog (overlays the settings page)
    local pinDialog = CreateFrame("Frame", nil, parent)
    pinDialog:SetAllPoints()
    pinDialog:SetFrameLevel(parent:GetFrameLevel() + 10)
    pinDialog:EnableMouse(true)
    pinDialog:Hide()

    local pinDlgBg = pinDialog:CreateTexture(nil, "BACKGROUND")
    pinDlgBg:SetAllPoints()
    pinDlgBg:SetColorTexture(0.08, 0.1, 0.15, 0.97)

    local pinDlgTitle = pinDialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    pinDlgTitle:SetPoint("TOP", 0, -12)
    pinDlgTitle:SetTextColor(0.8, 0.83, 0.9)

    local pinDlgDots = pinDialog:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    pinDlgDots:SetPoint("CENTER", 0, 50)
    pinDlgDots:SetTextColor(0.9, 0.9, 0.95, 1)
    do local f = pinDlgDots:GetFont(); if f then pinDlgDots:SetFont(f, 20, "OUTLINE") end end

    local pinDlgError = pinDialog:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pinDlgError:SetPoint("TOP", pinDlgDots, "BOTTOM", 0, -4)
    pinDlgError:SetTextColor(0.9, 0.3, 0.3, 1)

    local pinDlgEntry = ""
    local pinDlgStep = ""  -- "verify_old", "enter_new", "confirm_new"
    local pinDlgNewPin = ""

    local function UpdateDlgDots()
        local dots = ""
        for i = 1, 4 do
            dots = dots .. (i <= #pinDlgEntry and "|cffffffffo|r " or "|cff555555o|r ")
        end
        pinDlgDots:SetText(dots)
    end

    local function ClosePinDialog()
        pinDialog:Hide()
        pinDlgEntry = ""
        pinDlgNewPin = ""
    end

    local function OnDlgDigit(digit)
        if #pinDlgEntry >= 4 then return end
        pinDlgEntry = pinDlgEntry .. digit
        pinDlgError:SetText("")
        UpdateDlgDots()
        if #pinDlgEntry == 4 then
            C_Timer.After(0.15, function()
                if pinDlgStep == "verify_old" then
                    if pinDlgEntry == HearthPhoneDB.pin then
                        pinDlgEntry = ""
                        pinDlgStep = "enter_new"
                        pinDlgTitle:SetText("Enter New PIN")
                        UpdateDlgDots()
                    else
                        pinDlgEntry = ""
                        UpdateDlgDots()
                        pinDlgError:SetText("Wrong PIN")
                    end
                elseif pinDlgStep == "enter_new" then
                    pinDlgNewPin = pinDlgEntry
                    pinDlgEntry = ""
                    pinDlgStep = "confirm_new"
                    pinDlgTitle:SetText("Confirm PIN")
                    UpdateDlgDots()
                elseif pinDlgStep == "confirm_new" then
                    if pinDlgEntry == pinDlgNewPin then
                        HearthPhoneDB.pin = pinDlgNewPin
                        ClosePinDialog()
                        -- Update button text
                        pinBtnTxt:SetText("Change PIN  |  Remove PIN")
                        pinStatusText:SetText("On")
                    else
                        pinDlgEntry = ""
                        pinDlgNewPin = ""
                        pinDlgStep = "enter_new"
                        pinDlgTitle:SetText("Enter New PIN")
                        UpdateDlgDots()
                        pinDlgError:SetText("PINs didn't match")
                    end
                elseif pinDlgStep == "verify_remove" then
                    if pinDlgEntry == HearthPhoneDB.pin then
                        HearthPhoneDB.pin = nil
                        ClosePinDialog()
                        pinBtnTxt:SetText("Set PIN")
                        pinStatusText:SetText("Off")
                    else
                        pinDlgEntry = ""
                        UpdateDlgDots()
                        pinDlgError:SetText("Wrong PIN")
                    end
                end
            end)
        end
    end

    local function OnDlgBackspace()
        if #pinDlgEntry > 0 then
            pinDlgEntry = pinDlgEntry:sub(1, -2)
            pinDlgError:SetText("")
            UpdateDlgDots()
        end
    end

    -- Cancel button
    local pinDlgCancel = CreateFrame("Button", nil, pinDialog)
    pinDlgCancel:SetPoint("TOPLEFT", 6, -4)
    pinDlgCancel:SetSize(50, 16)
    local cancelTxt = pinDlgCancel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    cancelTxt:SetPoint("LEFT")
    cancelTxt:SetText("Cancel")
    cancelTxt:SetTextColor(0.35, 0.6, 1.0)
    pinDlgCancel:SetScript("OnEnter", function() cancelTxt:SetTextColor(0.55, 0.78, 1.0) end)
    pinDlgCancel:SetScript("OnLeave", function() cancelTxt:SetTextColor(0.35, 0.6, 1.0) end)
    pinDlgCancel:SetScript("OnClick", ClosePinDialog)

    -- Number pad for dialog
    do
        local padKeys = { "1","2","3","4","5","6","7","8","9","","0","<" }
        local BS, BG = 32, 4
        for i, key in ipairs(padKeys) do
            if key ~= "" then
                local row = math.floor((i - 1) / 3)
                local col = (i - 1) % 3
                local bx = (col - 1) * (BS + BG)
                local by = -10 - row * (BS + BG)
                local btn = CreateFrame("Button", nil, pinDialog)
                btn:SetPoint("TOP", pinDlgDots, "BOTTOM", bx, by - 10)
                btn:SetSize(BS, BS)
                local bg = btn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetTexture("Interface\\Buttons\\WHITE8x8")
                bg:SetVertexColor(0.2, 0.22, 0.3, 0.8)
                local txt = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                txt:SetPoint("CENTER")
                txt:SetText(key)
                txt:SetTextColor(0.9, 0.9, 0.95, 1)
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetTexture("Interface\\Buttons\\WHITE8x8")
                hl:SetVertexColor(0.4, 0.45, 0.55, 0.3)
                if key == "<" then
                    btn:SetScript("OnClick", OnDlgBackspace)
                else
                    local d = key
                    btn:SetScript("OnClick", function() OnDlgDigit(d) end)
                end
            end
        end
    end

    -- PIN button click handler
    pinBtn:SetScript("OnClick", function()
        local hasPin = HearthPhoneDB and HearthPhoneDB.pin and HearthPhoneDB.pin ~= ""
        pinDlgEntry = ""
        pinDlgNewPin = ""
        pinDlgError:SetText("")
        if hasPin then
            -- Show a choice: Change or Remove
            -- For simplicity, alternate: left half = change, right half = remove
            -- Actually let's use two separate clicks based on mouse position
            local cx = GetCursorPosition() / pinBtn:GetEffectiveScale()
            local mid = (pinBtn:GetLeft() + pinBtn:GetRight()) / 2
            if cx < mid then
                -- Change PIN: verify old first
                pinDlgStep = "verify_old"
                pinDlgTitle:SetText("Enter Current PIN")
            else
                -- Remove PIN: verify old
                pinDlgStep = "verify_remove"
                pinDlgTitle:SetText("Enter PIN to Remove")
            end
        else
            -- Set new PIN
            pinDlgStep = "enter_new"
            pinDlgTitle:SetText("Enter New PIN")
        end
        UpdateDlgDots()
        pinDialog:Show()
    end)

    local function UpdatePinStatus()
        local hasPin = HearthPhoneDB and HearthPhoneDB.pin and HearthPhoneDB.pin ~= ""
        if hasPin then
            pinBtnTxt:SetText("Change PIN  |  Remove PIN")
            pinStatusText:SetText("On")
        else
            pinBtnTxt:SetText("Set PIN")
            pinStatusText:SetText("Off")
        end
    end
    table.insert(controls, { update = UpdatePinStatus })

    -- Auto-lock timer setting
    local AUTO_LOCK_OPTIONS = {
        { label = "Off",  seconds = 0 },
        { label = "15s",  seconds = 15 },
        { label = "30s",  seconds = 30 },
        { label = "1m",   seconds = 60 },
        { label = "2m",   seconds = 120 },
        { label = "5m",   seconds = 300 },
    }

    local alLabel = phoneFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    alLabel:SetPoint("TOPLEFT", phoneFrame, "TOPLEFT", 10, py - 86)
    alLabel:SetText("Auto-Lock")
    alLabel:SetTextColor(0.75, 0.78, 0.85)

    local alBtn = CreateFrame("Button", nil, phoneFrame)
    alBtn:SetPoint("TOPLEFT", alLabel, "BOTTOMLEFT", 0, -4)
    alBtn:SetSize(SLIDER_W, 20)

    local alBtnBg = alBtn:CreateTexture(nil, "BACKGROUND")
    alBtnBg:SetAllPoints()
    alBtnBg:SetColorTexture(0.2, 0.24, 0.32, 0.9)

    local alBtnTxt = alBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    alBtnTxt:SetPoint("CENTER")
    alBtnTxt:SetTextColor(0.5, 0.7, 1.0)

    alBtn:SetScript("OnEnter", function() alBtnBg:SetColorTexture(0.28, 0.32, 0.42, 1) end)
    alBtn:SetScript("OnLeave", function() alBtnBg:SetColorTexture(0.2, 0.24, 0.32, 0.9) end)

    local function GetAutoLockIndex()
        local cur = HearthPhoneDB and HearthPhoneDB.autoLockSeconds or 0
        for i, opt in ipairs(AUTO_LOCK_OPTIONS) do
            if opt.seconds == cur then return i end
        end
        return 1
    end

    alBtn:SetScript("OnClick", function()
        local idx = GetAutoLockIndex() + 1
        if idx > #AUTO_LOCK_OPTIONS then idx = 1 end
        HearthPhoneDB.autoLockSeconds = AUTO_LOCK_OPTIONS[idx].seconds
        alBtnTxt:SetText(AUTO_LOCK_OPTIONS[idx].label)
    end)

    local function UpdateAutoLock()
        alBtnTxt:SetText(AUTO_LOCK_OPTIONS[GetAutoLockIndex()].label)
    end
    table.insert(controls, { update = UpdateAutoLock })

    -----------------------------------------------------------------------
    -- Volume subpage (sliders + mute toggles)
    -----------------------------------------------------------------------
    volumeFrame = CreateFrame("ScrollFrame", nil, parent)
    volumeFrame:SetPoint("TOPLEFT", 0, -26)
    volumeFrame:SetPoint("BOTTOMRIGHT")
    volumeFrame:Hide()

    local volContent = CreateFrame("Frame", nil, volumeFrame)
    volContent:SetWidth(SLIDER_W + 60)
    volumeFrame:SetScrollChild(volContent)
    volumeFrame:EnableMouseWheel(true)

    local volScrollOffset = 0
    local volContentH = 0

    volumeFrame:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = math.max(0, volContentH - volumeFrame:GetHeight())
        volScrollOffset = math.max(0, math.min(maxScroll, volScrollOffset - delta * 20))
        volumeFrame:SetVerticalScroll(volScrollOffset)
    end)

    local vy = -10
    for _, entry in ipairs(SOUND_ENTRIES) do
        local s = CreateVolumeRow(volContent, entry, vy)
        table.insert(controls, s)
        vy = vy - 34
    end
    volContentH = math.abs(vy) + 10
    volContent:SetHeight(volContentH)

    -----------------------------------------------------------------------
    -- Notifications subpage
    -----------------------------------------------------------------------
    notifFrame = CreateFrame("Frame", nil, parent)
    notifFrame:SetPoint("TOPLEFT", 0, -26)
    notifFrame:SetPoint("BOTTOMRIGHT")
    notifFrame:Hide()

    local function CreateToggleRow(parentFrame, label, yOffset, getVal, setVal)
        local row = CreateFrame("Frame", nil, parentFrame)
        row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 6, yOffset)
        row:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -6, yOffset)
        row:SetHeight(28)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.15, 0.17, 0.22, 0.8)

        local txt = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        txt:SetPoint("LEFT", 10, 0)
        txt:SetText(label)
        txt:SetTextColor(0.8, 0.83, 0.9)

        -- Toggle switch
        local toggle = CreateFrame("Button", nil, row)
        toggle:SetPoint("RIGHT", -10, 0)
        toggle:SetSize(32, 16)

        local trackBg = toggle:CreateTexture(nil, "BACKGROUND")
        trackBg:SetAllPoints()
        trackBg:SetColorTexture(0.25, 0.28, 0.35, 1)

        local knob = toggle:CreateTexture(nil, "ARTWORK")
        knob:SetSize(14, 14)

        local function UpdateToggle()
            if getVal() then
                trackBg:SetColorTexture(0.2, 0.5, 0.3, 1)
                knob:SetColorTexture(0.3, 0.8, 0.4, 1)
                knob:SetPoint("RIGHT", toggle, "RIGHT", -1, 0)
            else
                trackBg:SetColorTexture(0.25, 0.28, 0.35, 1)
                knob:SetColorTexture(0.5, 0.52, 0.58, 1)
                knob:SetPoint("LEFT", toggle, "LEFT", 1, 0)
            end
        end

        toggle:SetScript("OnClick", function()
            setVal(not getVal())
            knob:ClearAllPoints()
            UpdateToggle()
        end)

        return { update = UpdateToggle }
    end

    local bannerToggle = CreateToggleRow(notifFrame, "Show Banners", -6,
        function() return not (HearthPhoneDB and HearthPhoneDB.muteBanners) end,
        function(val) HearthPhoneDB.muteBanners = not val end
    )
    table.insert(controls, bannerToggle)

    local vibrateToggle = CreateToggleRow(notifFrame, "Vibration", -38,
        function() return not (HearthPhoneDB and HearthPhoneDB.muteVibration) end,
        function(val) HearthPhoneDB.muteVibration = not val end
    )
    table.insert(controls, vibrateToggle)

    -----------------------------------------------------------------------
    -- Display subpage (clock format + timezone)
    -----------------------------------------------------------------------
    displayFrame = CreateFrame("Frame", nil, parent)
    displayFrame:SetPoint("TOPLEFT", 0, -26)
    displayFrame:SetPoint("BOTTOMRIGHT")
    displayFrame:Hide()

    -- Clock format toggle (12h / 24h)
    local clockLabel = displayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    clockLabel:SetPoint("TOPLEFT", displayFrame, "TOPLEFT", 10, -10)
    clockLabel:SetText("Clock Format")
    clockLabel:SetTextColor(0.75, 0.78, 0.85)

    local clockBtn = CreateFrame("Button", nil, displayFrame)
    clockBtn:SetPoint("TOPLEFT", clockLabel, "BOTTOMLEFT", 0, -4)
    clockBtn:SetSize(SLIDER_W, 20)

    local clockBtnBg = clockBtn:CreateTexture(nil, "BACKGROUND")
    clockBtnBg:SetAllPoints()
    clockBtnBg:SetColorTexture(0.2, 0.24, 0.32, 0.9)

    local clockBtnTxt = clockBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    clockBtnTxt:SetPoint("CENTER")
    clockBtnTxt:SetTextColor(0.5, 0.7, 1.0)

    clockBtn:SetScript("OnEnter", function() clockBtnBg:SetColorTexture(0.28, 0.32, 0.42, 1) end)
    clockBtn:SetScript("OnLeave", function() clockBtnBg:SetColorTexture(0.2, 0.24, 0.32, 0.9) end)
    clockBtn:SetScript("OnClick", function()
        HearthPhoneDB.clock12h = not HearthPhoneDB.clock12h
        clockBtnTxt:SetText(HearthPhoneDB.clock12h and "12-hour (AM/PM)" or "24-hour")
    end)

    local function UpdateClockBtn()
        clockBtnTxt:SetText(HearthPhoneDB.clock12h and "12-hour (AM/PM)" or "24-hour")
    end
    table.insert(controls, { update = UpdateClockBtn })

    -- Timezone offset slider (-12 to +12)
    local tzLabel = displayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tzLabel:SetPoint("TOPLEFT", displayFrame, "TOPLEFT", 10, -56)
    tzLabel:SetText("Timezone Offset")
    tzLabel:SetTextColor(0.75, 0.78, 0.85)

    local tzValText = displayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tzValText:SetPoint("LEFT", tzLabel, "RIGHT", 8, 0)
    tzValText:SetTextColor(0.5, 0.7, 1.0)

    local tzBg = displayFrame:CreateTexture(nil, "BACKGROUND")
    tzBg:SetPoint("TOPLEFT", tzLabel, "BOTTOMLEFT", 0, -2)
    tzBg:SetSize(SLIDER_W, BAR_H)
    tzBg:SetColorTexture(0.15, 0.17, 0.25, 1)

    local tzFill = displayFrame:CreateTexture(nil, "ARTWORK")
    tzFill:SetPoint("TOPLEFT", tzBg, "TOPLEFT")
    tzFill:SetHeight(BAR_H)
    tzFill:SetColorTexture(0.3, 0.5, 0.9, 1)

    local tzHit = CreateFrame("Button", nil, displayFrame)
    tzHit:SetPoint("TOPLEFT", tzBg, "TOPLEFT", 0, 4)
    tzHit:SetSize(SLIDER_W, BAR_H + 8)

    local TZ_MIN = -12
    local TZ_MAX = 12

    local function GetTzOffset()
        return HearthPhoneDB and HearthPhoneDB.timezoneOffset or 0
    end

    local function UpdateTzVisual()
        local val = GetTzOffset()
        local norm = (val - TZ_MIN) / (TZ_MAX - TZ_MIN)
        tzFill:SetWidth(math.max(1, SLIDER_W * norm))
        local sign = val >= 0 and "+" or ""
        tzValText:SetText(sign .. val .. "h")
    end

    local tzDragging = false

    local function SetTzFromMouse()
        local left = tzBg:GetLeft()
        local right = tzBg:GetRight()
        if not left or not right or right <= left then return end
        local cx = GetCursorPosition()
        local scale = tzBg:GetEffectiveScale()
        cx = cx / scale
        local pct = (cx - left) / (right - left)
        pct = math.max(0, math.min(1, pct))
        local val = TZ_MIN + pct * (TZ_MAX - TZ_MIN)
        val = math.floor(val + 0.5)
        HearthPhoneDB.timezoneOffset = val
        UpdateTzVisual()
    end

    tzHit:SetScript("OnMouseDown", function() tzDragging = true; SetTzFromMouse() end)
    tzHit:SetScript("OnMouseUp", function() tzDragging = false end)
    tzHit:SetScript("OnUpdate", function() if tzDragging then SetTzFromMouse() end end)

    table.insert(controls, { update = UpdateTzVisual })

    -- Preview text showing current time with settings applied
    local previewLabel = displayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    previewLabel:SetPoint("TOPLEFT", displayFrame, "TOPLEFT", 10, -100)
    previewLabel:SetText("Preview")
    previewLabel:SetTextColor(0.75, 0.78, 0.85)

    local previewTime = displayFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewTime:SetPoint("TOPLEFT", previewLabel, "BOTTOMLEFT", 0, -4)
    previewTime:SetTextColor(0.9, 0.9, 0.95)

    local function UpdatePreview()
        if HearthPhone_GetTime then
            previewTime:SetText(HearthPhone_GetTime())
        end
    end
    table.insert(controls, { update = UpdatePreview })

    -- Update preview live while on this page
    displayFrame:SetScript("OnUpdate", function()
        if HearthPhone_GetTime then
            previewTime:SetText(HearthPhone_GetTime())
        end
    end)

    -----------------------------------------------------------------------
    -- About subpage
    -----------------------------------------------------------------------
    aboutFrame = CreateFrame("Frame", nil, parent)
    aboutFrame:SetPoint("TOPLEFT", 0, -26)
    aboutFrame:SetPoint("BOTTOMRIGHT")
    aboutFrame:Hide()

    local aboutTitle = aboutFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    aboutTitle:SetPoint("TOP", 0, -16)
    aboutTitle:SetText("HearthPhone")
    aboutTitle:SetTextColor(0.5, 0.7, 1.0)

    local aboutVer = aboutFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    aboutVer:SetPoint("TOP", aboutTitle, "BOTTOM", 0, -4)
    aboutVer:SetText("v0.1")
    aboutVer:SetTextColor(0.5, 0.52, 0.58)

    local aboutBy = aboutFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    aboutBy:SetPoint("TOP", aboutVer, "BOTTOM", 0, -12)
    aboutBy:SetText("Made by FlintarN")
    aboutBy:SetTextColor(0.75, 0.78, 0.85)

    local aboutMsg = aboutFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    aboutMsg:SetPoint("TOP", aboutBy, "BOTTOM", 0, -8)
    aboutMsg:SetPoint("LEFT", aboutFrame, "LEFT", 14, 0)
    aboutMsg:SetPoint("RIGHT", aboutFrame, "RIGHT", -14, 0)
    aboutMsg:SetJustifyH("CENTER")
    aboutMsg:SetText("Thanks for using HearthPhone!\nBuilt with love for the WoW community.\nReport bugs or ideas on CurseForge.")
    aboutMsg:SetTextColor(0.55, 0.58, 0.65)

    -----------------------------------------------------------------------
    ShowView("main")
end

function PhoneSettingsApp:OnShow()
    ShowView("main")
end

function PhoneSettingsApp:OnHide()
end
