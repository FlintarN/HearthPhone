-- PhoneTimer - Stopwatch / Timer app for HearthPhone

PhoneTimerApp = {}

local parent
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- Stopwatch state
local swRunning = false
local swElapsed = 0
local swLastTick = 0
local swDisplay
local swLapFs
local laps = {}
local lapScroll, lapContent

-- Timer state
local tmRunning = false
local tmRemaining = 0
local tmLastTick = 0
local tmDisplay
local tmInputMode = true -- true = setting time, false = counting down
local tmMinutes = 0
local tmSeconds = 0
local tmSetMinFs, tmSetSecFs
local tmInputFrame, tmCountFrame
local tmAlarmFlash, tmAlarmTimer

local tabStopwatch, tabTimer

-- ============================================================
-- Format helpers
-- ============================================================
local function FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    local ms = math.floor((seconds % 1) * 100)
    return format("%02d:%02d.%02d", m, s, ms)
end

local function FormatTimerDisplay(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return format("%02d:%02d", m, s)
end

-- ============================================================
-- Stopwatch
-- ============================================================
local function UpdateStopwatch()
    if swDisplay then
        swDisplay:SetText("|cffffffff" .. FormatTime(swElapsed) .. "|r")
    end
end

local function UpdateLapList()
    if not swLapFs then return end
    local text = ""
    for i = #laps, 1, -1 do
        text = text .. "|cff888888Lap " .. i .. ":|r |cffffffff" .. FormatTime(laps[i]) .. "|r\n"
    end
    swLapFs:SetText(text)
    if lapContent then
        lapContent:SetHeight(math.max(20, #laps * 14))
    end
end

local function StopwatchStart()
    swRunning = true
    swLastTick = GetTime()
end

local function StopwatchStop()
    swRunning = false
end

local function StopwatchLap()
    table.insert(laps, swElapsed)
    UpdateLapList()
end

local function StopwatchReset()
    swRunning = false
    swElapsed = 0
    wipe(laps)
    UpdateStopwatch()
    UpdateLapList()
end

-- ============================================================
-- Timer
-- ============================================================
local function ShowTimerInput()
    tmInputMode = true
    if tmInputFrame then tmInputFrame:Show() end
    if tmCountFrame then tmCountFrame:Hide() end
    if tmAlarmFlash then tmAlarmFlash:Hide() end
    if tmAlarmTimer then tmAlarmTimer:Cancel(); tmAlarmTimer = nil end
end

local function ShowTimerCount()
    tmInputMode = false
    if tmInputFrame then tmInputFrame:Hide() end
    if tmCountFrame then tmCountFrame:Show() end
end

local function UpdateTimerDisplay()
    if tmDisplay then
        if tmRemaining <= 0 and not tmRunning then
            tmDisplay:SetText("|cffff4444Time's up!|r")
        else
            tmDisplay:SetText("|cffffffff" .. FormatTimerDisplay(tmRemaining) .. "|r")
        end
    end
end

local function UpdateTimerInputDisplay()
    if tmSetMinFs then tmSetMinFs:SetText("|cffffffff" .. format("%02d", tmMinutes) .. "|r") end
    if tmSetSecFs then tmSetSecFs:SetText("|cffffffff" .. format("%02d", tmSeconds) .. "|r") end
end

local function TimerStart()
    if tmInputMode then
        tmRemaining = tmMinutes * 60 + tmSeconds
        if tmRemaining <= 0 then return end
        ShowTimerCount()
    end
    tmRunning = true
    tmLastTick = GetTime()
    UpdateTimerDisplay()
end

local function TimerStop()
    tmRunning = false
end

local function TimerReset()
    tmRunning = false
    tmRemaining = 0
    tmMinutes = 0
    tmSeconds = 0
    ShowTimerInput()
    UpdateTimerInputDisplay()
end

local function TimerAlarm()
    tmRunning = false

    -- Play alarm sound (ReadyCheck ping — distinct and alarmy)
    PlaySound(8960, "Master")

    -- Vibrate the phone
    if HearthPhone_Vibrate then HearthPhone_Vibrate() end

    -- Repeat alarm sound a few times
    local alarmRepeat = 0
    local alarmTicker = C_Timer.NewTicker(1.5, function()
        alarmRepeat = alarmRepeat + 1
        if alarmRepeat >= 3 then return end
        PlaySound(8960, "Master")
        if HearthPhone_Vibrate then HearthPhone_Vibrate() end
    end)

    -- Flash effect
    if tmAlarmFlash then
        local flashCount = 0
        tmAlarmTimer = C_Timer.NewTicker(0.4, function()
            flashCount = flashCount + 1
            if flashCount > 12 then
                tmAlarmFlash:Hide()
                if tmAlarmTimer then tmAlarmTimer:Cancel(); tmAlarmTimer = nil end
                if alarmTicker then alarmTicker:Cancel() end
                return
            end
            if flashCount % 2 == 1 then
                tmAlarmFlash:Show()
            else
                tmAlarmFlash:Hide()
            end
        end)
    end

    if tmDisplay then
        tmDisplay:SetText("|cffff4444Time's up!|r")
    end
end

-- ============================================================
-- Tab switching
-- ============================================================
local swFrame, tmFrame

local function ShowTab(tab)
    if swFrame then swFrame:SetShown(tab == "stopwatch") end
    if tmFrame then tmFrame:SetShown(tab == "timer") end
    if tabStopwatch then
        if tab == "stopwatch" then
            tabStopwatch.bg:SetVertexColor(0.25, 0.25, 0.35, 1)
        else
            tabStopwatch.bg:SetVertexColor(0.14, 0.14, 0.18, 1)
        end
    end
    if tabTimer then
        if tab == "timer" then
            tabTimer.bg:SetVertexColor(0.25, 0.25, 0.35, 1)
        else
            tabTimer.bg:SetVertexColor(0.14, 0.14, 0.18, 1)
        end
    end
end

-- ============================================================
-- Helper: small button
-- ============================================================
local function CreateBtn(parentF, w, h, label, color, onClick)
    local btn = CreateFrame("Button", nil, parentF)
    btn:SetSize(w, h)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(color[1], color[2], color[3], 1)
    btn.bg = bg
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(WHITE)
    hl:SetVertexColor(1, 1, 1, 0.12)
    local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText("|cffffffff" .. label .. "|r")
    local f = fs:GetFont()
    if f then fs:SetFont(f, 9, "") end
    btn:SetScript("OnClick", onClick)
    btn.label = fs
    return btn
end

-- ============================================================
-- Init
-- ============================================================
function PhoneTimerApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local PAD = 3

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cff44ccffClock|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Tab bar
    local tabBar = CreateFrame("Frame", nil, parent)
    tabBar:SetHeight(22)
    tabBar:SetPoint("TOPLEFT", PAD, -16)
    tabBar:SetPoint("TOPRIGHT", -PAD, -16)

    tabStopwatch = CreateFrame("Button", nil, tabBar)
    tabStopwatch:SetHeight(22)
    tabStopwatch:SetPoint("TOPLEFT")
    tabStopwatch:SetPoint("TOPRIGHT", tabBar, "TOP")
    tabStopwatch.bg = tabStopwatch:CreateTexture(nil, "BACKGROUND")
    tabStopwatch.bg:SetAllPoints()
    tabStopwatch.bg:SetTexture(WHITE)
    local swTabFs = tabStopwatch:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    swTabFs:SetPoint("CENTER")
    swTabFs:SetText("|cffffffffStopwatch|r")
    local stf = swTabFs:GetFont()
    if stf then swTabFs:SetFont(stf, 8, "") end
    tabStopwatch:SetScript("OnClick", function() ShowTab("stopwatch") end)

    tabTimer = CreateFrame("Button", nil, tabBar)
    tabTimer:SetHeight(22)
    tabTimer:SetPoint("TOPLEFT", tabBar, "TOP")
    tabTimer:SetPoint("TOPRIGHT")
    tabTimer.bg = tabTimer:CreateTexture(nil, "BACKGROUND")
    tabTimer.bg:SetAllPoints()
    tabTimer.bg:SetTexture(WHITE)
    local tmTabFs = tabTimer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tmTabFs:SetPoint("CENTER")
    tmTabFs:SetText("|cffffffffTimer|r")
    local ttf = tmTabFs:GetFont()
    if ttf then tmTabFs:SetFont(ttf, 8, "") end
    tabTimer:SetScript("OnClick", function() ShowTab("timer") end)

    -- ============================================================
    -- Stopwatch panel
    -- ============================================================
    swFrame = CreateFrame("Frame", nil, parent)
    swFrame:SetPoint("TOPLEFT", PAD, -40)
    swFrame:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    -- Time display
    swDisplay = swFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    swDisplay:SetPoint("TOP", 0, -10)
    swDisplay:SetText("|cffffffff00:00.00|r")
    local sdf = swDisplay:GetFont()
    if sdf then swDisplay:SetFont(sdf, 22, "") end

    -- Buttons row
    local btnY = -50
    local startBtn
    startBtn = CreateBtn(swFrame, 48, 24, "Start", {0.2, 0.35, 0.2}, function()
        if swRunning then
            StopwatchStop()
            startBtn.label:SetText("|cffffffffStart|r")
            startBtn.bg:SetVertexColor(0.2, 0.35, 0.2, 1)
        else
            StopwatchStart()
            startBtn.label:SetText("|cffffffffStop|r")
            startBtn.bg:SetVertexColor(0.45, 0.15, 0.15, 1)
        end
    end)
    startBtn:SetPoint("TOP", -30, btnY)

    local lapBtn = CreateBtn(swFrame, 48, 24, "Lap", {0.25, 0.25, 0.35}, function()
        if swRunning then StopwatchLap() end
    end)
    lapBtn:SetPoint("TOP", 30, btnY)

    local resetBtn = CreateBtn(swFrame, 48, 24, "Reset", {0.35, 0.2, 0.2}, function()
        StopwatchReset()
        startBtn.label:SetText("|cffffffffStart|r")
        startBtn.bg:SetVertexColor(0.2, 0.35, 0.2, 1)
    end)
    resetBtn:SetPoint("TOP", 0, btnY - 28)

    -- Lap list (scrollable area)
    lapScroll = CreateFrame("ScrollFrame", nil, swFrame)
    lapScroll:SetPoint("TOPLEFT", 4, btnY - 58)
    lapScroll:SetPoint("BOTTOMRIGHT", -4, 4)
    lapScroll:EnableMouseWheel(true)
    lapScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, (lapContent:GetHeight() or 20) - self:GetHeight())
        self:SetVerticalScroll(math.min(maxS, math.max(0, cur - delta * 20)))
    end)

    lapContent = CreateFrame("Frame", nil, lapScroll)
    lapScroll:SetScrollChild(lapContent)

    -- Size the lapContent to match the scroll frame width after layout
    C_Timer.After(0, function()
        local w = lapScroll:GetWidth()
        if w and w > 10 then
            lapContent:SetSize(w, 20)
        else
            lapContent:SetSize(120, 20)
        end
    end)

    swLapFs = lapContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    swLapFs:SetPoint("TOPLEFT", 0, 0)
    swLapFs:SetPoint("RIGHT", lapContent, "RIGHT", 0, 0)
    swLapFs:SetJustifyH("LEFT")
    swLapFs:SetWordWrap(true)
    local lf = swLapFs:GetFont()
    if lf then swLapFs:SetFont(lf, 8, "") end

    -- ============================================================
    -- Timer panel
    -- ============================================================
    tmFrame = CreateFrame("Frame", nil, parent)
    tmFrame:SetPoint("TOPLEFT", PAD, -40)
    tmFrame:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    tmFrame:Hide()

    -- Input mode: pick minutes and seconds
    tmInputFrame = CreateFrame("Frame", nil, tmFrame)
    tmInputFrame:SetAllPoints()

    local inputLabel = tmInputFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    inputLabel:SetPoint("TOP", 0, -10)
    inputLabel:SetText("|cff888888Set Timer|r")
    local ilf = inputLabel:GetFont()
    if ilf then inputLabel:SetFont(ilf, 10, "") end

    -- Minutes
    local minLabel = tmInputFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    minLabel:SetPoint("TOP", -30, -30)
    minLabel:SetText("|cff666666min|r")
    local mlf = minLabel:GetFont()
    if mlf then minLabel:SetFont(mlf, 7, "") end

    tmSetMinFs = tmInputFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tmSetMinFs:SetPoint("TOP", -30, -42)
    tmSetMinFs:SetText("|cffffffff00|r")
    local mdf = tmSetMinFs:GetFont()
    if mdf then tmSetMinFs:SetFont(mdf, 20, "") end

    local minUp = CreateBtn(tmInputFrame, 30, 18, "+", {0.22, 0.22, 0.30}, function()
        tmMinutes = math.min(99, tmMinutes + 1)
        UpdateTimerInputDisplay()
    end)
    minUp:SetPoint("TOP", -30, -66)

    local minDown = CreateBtn(tmInputFrame, 30, 18, "-", {0.22, 0.22, 0.30}, function()
        tmMinutes = math.max(0, tmMinutes - 1)
        UpdateTimerInputDisplay()
    end)
    minDown:SetPoint("TOP", -30, -86)

    -- Colon
    local colon = tmInputFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    colon:SetPoint("TOP", 0, -42)
    colon:SetText("|cffffffff:|r")
    local cf = colon:GetFont()
    if cf then colon:SetFont(cf, 20, "") end

    -- Seconds
    local secLabel = tmInputFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    secLabel:SetPoint("TOP", 30, -30)
    secLabel:SetText("|cff666666sec|r")
    local slf = secLabel:GetFont()
    if slf then secLabel:SetFont(slf, 7, "") end

    tmSetSecFs = tmInputFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tmSetSecFs:SetPoint("TOP", 30, -42)
    tmSetSecFs:SetText("|cffffffff00|r")
    local sdf2 = tmSetSecFs:GetFont()
    if sdf2 then tmSetSecFs:SetFont(sdf2, 20, "") end

    local secUp = CreateBtn(tmInputFrame, 30, 18, "+", {0.22, 0.22, 0.30}, function()
        tmSeconds = math.min(59, tmSeconds + 1)
        UpdateTimerInputDisplay()
    end)
    secUp:SetPoint("TOP", 30, -66)

    local secDown = CreateBtn(tmInputFrame, 30, 18, "-", {0.22, 0.22, 0.30}, function()
        tmSeconds = math.max(0, tmSeconds - 1)
        UpdateTimerInputDisplay()
    end)
    secDown:SetPoint("TOP", 30, -86)

    -- Start timer button
    local tmStartBtn = CreateBtn(tmInputFrame, 80, 28, "Start", {0.2, 0.35, 0.2}, function()
        TimerStart()
    end)
    tmStartBtn:SetPoint("TOP", 0, -115)

    -- Countdown mode
    tmCountFrame = CreateFrame("Frame", nil, tmFrame)
    tmCountFrame:SetAllPoints()
    tmCountFrame:Hide()

    tmDisplay = tmCountFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tmDisplay:SetPoint("TOP", 0, -30)
    local tdf = tmDisplay:GetFont()
    if tdf then tmDisplay:SetFont(tdf, 28, "") end

    -- Alarm flash overlay
    tmAlarmFlash = tmCountFrame:CreateTexture(nil, "OVERLAY")
    tmAlarmFlash:SetAllPoints()
    tmAlarmFlash:SetTexture(WHITE)
    tmAlarmFlash:SetVertexColor(1, 0.3, 0.3, 0.3)
    tmAlarmFlash:Hide()

    local tmPauseBtn, tmCancelBtn
    tmPauseBtn = CreateBtn(tmCountFrame, 55, 24, "Pause", {0.3, 0.3, 0.2}, function()
        if tmRunning then
            TimerStop()
            tmPauseBtn.label:SetText("|cffffffffResume|r")
        else
            tmRunning = true
            tmLastTick = GetTime()
            tmPauseBtn.label:SetText("|cffffffffPause|r")
        end
    end)
    tmPauseBtn:SetPoint("TOP", -35, -75)

    tmCancelBtn = CreateBtn(tmCountFrame, 55, 24, "Cancel", {0.35, 0.2, 0.2}, function()
        TimerReset()
        tmPauseBtn.label:SetText("|cffffffffPause|r")
    end)
    tmCancelBtn:SetPoint("TOP", 35, -75)

    -- OnUpdate for both stopwatch and timer
    parent:SetScript("OnUpdate", function()
        local now = GetTime()

        -- Stopwatch
        if swRunning then
            if swLastTick == 0 then swLastTick = now end
            local dt = now - swLastTick
            swLastTick = now
            swElapsed = swElapsed + dt
            UpdateStopwatch()
        end

        -- Timer countdown
        if tmRunning and not tmInputMode then
            if tmLastTick == 0 then tmLastTick = now end
            local dt = now - tmLastTick
            tmLastTick = now
            tmRemaining = tmRemaining - dt
            if tmRemaining <= 0 then
                tmRemaining = 0
                TimerAlarm()
            end
            UpdateTimerDisplay()
        end
    end)

    ShowTab("stopwatch")
    UpdateTimerInputDisplay()
end

function PhoneTimerApp:OnShow()
    swLastTick = GetTime()
    tmLastTick = GetTime()
    UpdateStopwatch()
    if tmInputMode then
        UpdateTimerInputDisplay()
    else
        UpdateTimerDisplay()
    end
    -- Resize lap content to match scroll width
    if lapScroll and lapContent then
        local w = lapScroll:GetWidth()
        if w and w > 10 then
            lapContent:SetWidth(w)
        end
    end
end

function PhoneTimerApp:OnHide()
    -- Keep running in background (stopwatch/timer persist)
end
