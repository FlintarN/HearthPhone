-- PhoneDamageMeter - Personal DPS/HPS tracker for HearthPhone
-- Uses C_DamageMeter API (12.0+) when available, falls back to combat log

PhoneDamageMeterApp = {}

local parent
local WHITE = "Interface\\Buttons\\WHITE8x8"

local inCombat = false
local startTime = 0
local damage = 0
local healing = 0
local duration = 0
local history = {}
local currentEncounter = nil -- set by ENCOUNTER_START, cleared by ENCOUNTER_END

local dpsFs, hpsFs, durationFs, totalDmgFs, totalHealFs, statusFs
local historyRows = {}
local histEmptyFs
local histScroll, histContent

local MAX_HISTORY = 50

local function SaveHistory()
    if not HearthPhoneDB then HearthPhoneDB = {} end
    HearthPhoneDB.dmHistory = history
end

local function LoadHistory()
    if HearthPhoneDB and HearthPhoneDB.dmHistory then
        history = HearthPhoneDB.dmHistory
    end
end

-- Detect native Blizzard damage meter (12.0+)
local useNativeDM = (C_DamageMeter ~= nil)
local pollThrottle = 0
local POLL_INTERVAL = 1

-- ============================================================
-- Helpers
-- ============================================================
local function FormatNumber(n)
    if n >= 1000000 then
        return format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return format("%.1fK", n / 1000)
    end
    return format("%d", n)
end

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
    if f then fs:SetFont(f, 10, "") end
    btn:SetScript("OnClick", onClick)
    btn.label = fs
    return btn
end

-- ============================================================
-- Native C_DamageMeter polling (12.0+)
-- ============================================================
local function PollNativeDM()
    if not useNativeDM then return end
    pcall(function()
        local playerGUID = UnitGUID("player")
        local dmgSession = C_DamageMeter.GetCombatSessionFromType(
            Enum.DamageMeterSessionType.Current,
            Enum.DamageMeterType.DamageDone
        )
        if dmgSession then
            duration = dmgSession.durationSeconds or 0
            damage = 0
            for _, src in ipairs(dmgSession.combatSources) do
                if src.sourceGUID == playerGUID then
                    damage = src.totalAmount or 0
                    break
                end
            end
        end
        local healSession = C_DamageMeter.GetCombatSessionFromType(
            Enum.DamageMeterSessionType.Current,
            Enum.DamageMeterType.HealingDone
        )
        if healSession then
            healing = 0
            for _, src in ipairs(healSession.combatSources) do
                if src.sourceGUID == playerGUID then
                    healing = src.totalAmount or 0
                    break
                end
            end
        end
    end)
end

-- ============================================================
-- Legacy CLEU parser (pre-12.0 fallback)
-- ============================================================
local function OnCombatLogEvent()
    if useNativeDM then return end
    if not inCombat then return end
    local _, subEvent, _, sourceGUID = CombatLogGetCurrentEventInfo()
    if sourceGUID ~= UnitGUID("player") then return end

    if subEvent == "SWING_DAMAGE" then
        local amt = select(12, CombatLogGetCurrentEventInfo())
        if amt and type(amt) == "number" then
            damage = damage + amt
        end
    elseif subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" or subEvent == "RANGE_DAMAGE" then
        local amt = select(15, CombatLogGetCurrentEventInfo())
        if amt and type(amt) == "number" then
            damage = damage + amt
        end
    elseif subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
        local amt = select(15, CombatLogGetCurrentEventInfo())
        local over = select(16, CombatLogGetCurrentEventInfo()) or 0
        if amt and type(amt) == "number" then
            healing = healing + amt - over
        end
    end
end

-- ============================================================
-- Display
-- ============================================================
local function UpdateDisplay()
    if not dpsFs then return end

    local dur = tonumber(duration) or 0
    if not useNativeDM and inCombat and startTime > 0 then
        dur = (tonumber(GetTime()) or 0) - startTime
    end
    dur = math.max(dur, 1)

    dpsFs:SetText("|cffff4444" .. FormatNumber(damage / dur) .. "|r")
    hpsFs:SetText("|cff44ff44" .. FormatNumber(healing / dur) .. "|r")
    totalDmgFs:SetText("|cff888888Dmg: |r|cffcccccc" .. FormatNumber(damage) .. "|r")
    totalHealFs:SetText("|cff888888Heal: |r|cffcccccc" .. FormatNumber(healing) .. "|r")
    durationFs:SetText("|cff888888" .. format("%d:%02d", math.floor(dur / 60), math.floor(dur % 60)) .. "|r")

    if inCombat then
        statusFs:SetText("|cffff4444In Combat|r")
    else
        statusFs:SetText("|cff44ff44Out of Combat|r")
    end
end

local ROW_HEIGHT = 26
local ROW_PAD = 2
local HEADER_HEIGHT = 16
local MARGIN = 4

local histHeaders = {} -- instance group header FontStrings

local function GetOrCreateRow(idx)
    if historyRows[idx] then return historyRows[idx] end
    if not histContent then return nil end

    local row = CreateFrame("Frame", nil, histContent)
    row:SetHeight(ROW_HEIGHT)

    -- Left cell: timer (full height, centered)
    local timerFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    timerFs:SetPoint("LEFT", 0, 0)
    timerFs:SetWidth(36)
    timerFs:SetJustifyH("CENTER")
    local tf = timerFs:GetFont()
    if tf then timerFs:SetFont(tf, 10, "") end

    -- Top-right: DPS
    local dpsFs2 = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dpsFs2:SetPoint("TOPLEFT", 38, -2)
    dpsFs2:SetJustifyH("LEFT")
    local df = dpsFs2:GetFont()
    if df then dpsFs2:SetFont(df, 9, "") end

    -- Top-right: HPS
    local hpsFs2 = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hpsFs2:SetPoint("LEFT", row, "LEFT", 116, 0)
    hpsFs2:SetPoint("TOP", 0, -2)
    hpsFs2:SetJustifyH("LEFT")
    local hf = hpsFs2:GetFont()
    if hf then hpsFs2:SetFont(hf, 9, "") end

    -- Bottom-left: total damage
    local dmgFs2 = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dmgFs2:SetPoint("BOTTOMLEFT", 38, 2)
    dmgFs2:SetJustifyH("LEFT")
    local dmf = dmgFs2:GetFont()
    if dmf then dmgFs2:SetFont(dmf, 9, "") end

    -- Bottom-right: total healing (aligned with HPS)
    local healFs2 = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    healFs2:SetPoint("LEFT", hpsFs2, "LEFT", 0, 0)
    healFs2:SetPoint("BOTTOM", row, "BOTTOM", 0, 2)
    healFs2:SetJustifyH("LEFT")
    local hlf = healFs2:GetFont()
    if hlf then healFs2:SetFont(hlf, 9, "") end

    row.timerFs = timerFs
    row.dpsFs = dpsFs2
    row.hpsFs = hpsFs2
    row.dmgFs = dmgFs2
    row.healFs = healFs2
    historyRows[idx] = row
    return row
end

local histNameLabels = {} -- per-fight name labels
local NAME_LABEL_HEIGHT = 12
local SEP_HEIGHT = 3 -- 1px line + 2px spacing

local histSeps = {} -- separator texture pool

local function GetOrCreateSep(idx)
    if histSeps[idx] then return histSeps[idx] end
    if not histContent then return nil end

    local tex = histContent:CreateTexture(nil, "ARTWORK")
    tex:SetHeight(1)
    tex:SetTexture(WHITE)
    tex:SetVertexColor(0.3, 0.3, 0.35, 0.3)
    histSeps[idx] = tex
    return tex
end

local function GetOrCreateHeader(idx)
    if histHeaders[idx] then return histHeaders[idx] end
    if not histContent then return nil end

    local fs = histContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    local f = fs:GetFont()
    if f then fs:SetFont(f, 9, "OUTLINE") end
    histHeaders[idx] = fs
    return fs
end

local function GetOrCreateNameLabel(idx)
    if histNameLabels[idx] then return histNameLabels[idx] end
    if not histContent then return nil end

    local fs = histContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    local f = fs:GetFont()
    if f then fs:SetFont(f, 8, "") end
    histNameLabels[idx] = fs
    return fs
end

local function UpdateHistory()
    if not histContent then return end
    if #history == 0 then
        if histEmptyFs then histEmptyFs:Show() end
        for _, r in ipairs(historyRows) do r:Hide() end
        for _, h in ipairs(histHeaders) do h:Hide() end
        for _, n in ipairs(histNameLabels) do n:Hide() end
        for _, s in ipairs(histSeps) do s:Hide() end
        histContent:SetHeight(20)
        return
    end
    if histEmptyFs then histEmptyFs:Hide() end

    local yOffset = 0
    local rowCount = 0
    local headerCount = 0
    local lastInstance = nil

    for i = #history, math.max(1, #history - 19), -1 do
        local h = history[i]

        -- Instance group header
        local inst = h.instance or "Open World"
        if inst ~= lastInstance then
            headerCount = headerCount + 1
            local header = GetOrCreateHeader(headerCount)
            if header then
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", histContent, "TOPLEFT", MARGIN, -yOffset)
                header:SetPoint("RIGHT", histContent, "RIGHT", -MARGIN, 0)
                header:SetText("|cff44aaff" .. inst .. "|r")
                header:Show()
                yOffset = yOffset + HEADER_HEIGHT
            end
            lastInstance = inst
        end

        -- Separator line above name
        rowCount = rowCount + 1
        local sepTex = GetOrCreateSep(rowCount)
        if sepTex then
            sepTex:ClearAllPoints()
            sepTex:SetPoint("TOPLEFT", histContent, "TOPLEFT", MARGIN, -yOffset)
            sepTex:SetPoint("RIGHT", histContent, "RIGHT", -MARGIN, 0)
            sepTex:Show()
            yOffset = yOffset + SEP_HEIGHT
        end

        -- Name label above the data row
        local nameLabel = GetOrCreateNameLabel(rowCount)
        if nameLabel then
            nameLabel:ClearAllPoints()
            nameLabel:SetPoint("TOPLEFT", histContent, "TOPLEFT", MARGIN, -yOffset)
            nameLabel:SetPoint("RIGHT", histContent, "RIGHT", -MARGIN, 0)
            local name = h.name or "Trash"
            local nameColor = (name ~= "Trash") and "ffcc44" or "666666"
            nameLabel:SetText("|cff" .. nameColor .. name .. "|r")
            nameLabel:Show()
            yOffset = yOffset + NAME_LABEL_HEIGHT
        end

        local row = GetOrCreateRow(rowCount)
        if not row then break end
        local dur = math.max(h.duration, 1)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", MARGIN, -yOffset)
        row:SetPoint("RIGHT", histContent, "RIGHT", -MARGIN, 0)

        row.timerFs:SetText("|cff888888" .. format("%d:%02d", math.floor(dur / 60), math.floor(dur % 60)) .. "|r")
        row.dpsFs:SetText("|cffff4444" .. FormatNumber(h.damage / dur) .. " dps|r")
        row.hpsFs:SetText("|cff44ff44" .. FormatNumber(h.healing / dur) .. " hps|r")
        row.dmgFs:SetText("|cffcccccc" .. FormatNumber(h.damage) .. " dmg|r")
        row.healFs:SetText("|cffcccccc" .. FormatNumber(h.healing) .. " heal|r")
        row:Show()

        yOffset = yOffset + ROW_HEIGHT + ROW_PAD
    end

    -- Hide unused
    for j = rowCount + 1, #historyRows do historyRows[j]:Hide() end
    for j = rowCount + 1, #histNameLabels do histNameLabels[j]:Hide() end
    for j = rowCount + 1, #histSeps do histSeps[j]:Hide() end
    for j = headerCount + 1, #histHeaders do histHeaders[j]:Hide() end

    histContent:SetHeight(math.max(20, yOffset))
end

-- ============================================================
-- Combat events
-- ============================================================
local function OnCombatStart()
    inCombat = true
    if not useNativeDM then
        damage = 0
        healing = 0
        startTime = GetTime()
        duration = 0
    end
    UpdateDisplay()
end

local function OnCombatEnd()
    if not inCombat then return end
    inCombat = false

    if useNativeDM then
        PollNativeDM()
    else
        if startTime > 0 then
            duration = (tonumber(GetTime()) or 0) - startTime
        end
    end

    if damage > 0 or healing > 0 then
        local name = currentEncounter or "Trash"
        local instance = nil
        pcall(function()
            local instName, instType = GetInstanceInfo()
            if instName and instType ~= "none" then
                instance = instName
            end
        end)
        table.insert(history, {
            damage = damage,
            healing = healing,
            duration = math.max(duration, 1),
            name = name,
            instance = instance,
        })
        while #history > MAX_HISTORY do
            table.remove(history, 1)
        end
        SaveHistory()
        UpdateHistory()
    end
    UpdateDisplay()
end

local function CombatReset()
    damage = 0
    healing = 0
    duration = 0
    startTime = 0
    history = {}
    SaveHistory()
    if useNativeDM then
        pcall(function() C_DamageMeter.ResetAllCombatSessions() end)
    end
    UpdateDisplay()
end

-- ============================================================
-- Init
-- ============================================================
function PhoneDamageMeterApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame
    LoadHistory()

    local PAD = 4

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -4)
    title:SetText("|cffff4444Damage Meter|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 11, "OUTLINE") end

    -- Status
    statusFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusFs:SetPoint("TOP", 0, -20)
    statusFs:SetText("|cff44ff44Out of Combat|r")
    local sf = statusFs:GetFont()
    if sf then statusFs:SetFont(sf, 9, "") end

    -- DPS
    local dpsLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dpsLabel:SetPoint("TOP", -45, -36)
    dpsLabel:SetText("|cff888888DPS|r")
    local dlf = dpsLabel:GetFont()
    if dlf then dpsLabel:SetFont(dlf, 9, "") end

    dpsFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dpsFs:SetPoint("TOP", -45, -50)
    dpsFs:SetText("|cffff44440|r")
    local dpf = dpsFs:GetFont()
    if dpf then dpsFs:SetFont(dpf, 24, "") end

    -- HPS
    local hpsLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hpsLabel:SetPoint("TOP", 45, -36)
    hpsLabel:SetText("|cff888888HPS|r")
    local hlf = hpsLabel:GetFont()
    if hlf then hpsLabel:SetFont(hlf, 9, "") end

    hpsFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hpsFs:SetPoint("TOP", 45, -50)
    hpsFs:SetText("|cff44ff440|r")
    local hpf = hpsFs:GetFont()
    if hpf then hpsFs:SetFont(hpf, 24, "") end

    -- Duration
    durationFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    durationFs:SetPoint("TOP", 0, -78)
    durationFs:SetText("|cff8888880:00|r")
    local cdf = durationFs:GetFont()
    if cdf then durationFs:SetFont(cdf, 12, "") end

    -- Totals
    totalDmgFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalDmgFs:SetPoint("TOPLEFT", PAD + 2, -96)
    totalDmgFs:SetText("|cff888888Dmg: |r|cffcccccc0|r")
    local tdf = totalDmgFs:GetFont()
    if tdf then totalDmgFs:SetFont(tdf, 9, "") end

    totalHealFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalHealFs:SetPoint("TOPRIGHT", -(PAD + 2), -96)
    totalHealFs:SetText("|cff888888Heal: |r|cffcccccc0|r")
    local thf = totalHealFs:GetFont()
    if thf then totalHealFs:SetFont(thf, 9, "") end

    -- Reset button (top-right corner)
    local resetBtn = CreateBtn(parent, 36, 14, "Reset", {0.35, 0.2, 0.2}, function()
        CombatReset()
        UpdateHistory()
    end)
    resetBtn:SetPoint("TOPRIGHT", -PAD, -4)

    -- Separator
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", PAD, -112)
    sep:SetPoint("TOPRIGHT", -PAD, -112)
    sep:SetHeight(1)
    sep:SetTexture(WHITE)
    sep:SetVertexColor(0.3, 0.3, 0.35, 0.5)

    -- History label
    local histLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    histLabel:SetPoint("TOPLEFT", PAD + 2, -116)
    histLabel:SetText("|cff888888Fight History|r")
    local hlf2 = histLabel:GetFont()
    if hlf2 then histLabel:SetFont(hlf2, 9, "OUTLINE") end

    -- History scroll
    histScroll = CreateFrame("ScrollFrame", nil, parent)
    histScroll:SetPoint("TOPLEFT", PAD, -130)
    histScroll:SetPoint("BOTTOMRIGHT", -PAD, 4)
    histScroll:EnableMouseWheel(true)
    histScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, (histContent:GetHeight() or 20) - self:GetHeight())
        self:SetVerticalScroll(math.min(maxS, math.max(0, cur - delta * 16)))
    end)

    histContent = CreateFrame("Frame", nil, histScroll)
    histScroll:SetScrollChild(histContent)

    C_Timer.After(0, function()
        local w = histScroll:GetWidth()
        if w and w > 10 then
            histContent:SetSize(w, 20)
        else
            histContent:SetSize(140, 20)
        end
    end)

    histEmptyFs = histContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    histEmptyFs:SetPoint("TOPLEFT", 0, 0)
    histEmptyFs:SetJustifyH("LEFT")
    local chf = histEmptyFs:GetFont()
    if chf then histEmptyFs:SetFont(chf, 9, "") end
    histEmptyFs:SetText("|cff666666No fights yet|r")

    -- Event frame (always active, even when app is hidden)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("ENCOUNTER_START")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    if not useNativeDM then
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            OnCombatStart()
        elseif event == "PLAYER_REGEN_ENABLED" then
            OnCombatEnd()
        elseif event == "ENCOUNTER_START" then
            local _, encounterName = ...
            currentEncounter = encounterName
        elseif event == "ENCOUNTER_END" then
            -- keep currentEncounter set so OnCombatEnd can use it, clear after a short delay
            C_Timer.After(1, function() currentEncounter = nil end)
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            OnCombatLogEvent()
        end
    end)

    -- Throttled display update (every 3s while in combat)
    -- Use eventFrame (always visible) so updates fire even when app page is hidden
    eventFrame:SetScript("OnUpdate", function()
        if not inCombat then return end
        local now = GetTime()
        if now - pollThrottle < POLL_INTERVAL then return end
        pollThrottle = now
        if useNativeDM then
            PollNativeDM()
        end
        UpdateDisplay()
    end)
end

function PhoneDamageMeterApp:OnShow()
    if useNativeDM then PollNativeDM() end
    UpdateDisplay()
    UpdateHistory()
    if histScroll and histContent then
        local w = histScroll:GetWidth()
        if w and w > 10 then histContent:SetWidth(w) end
    end
end

function PhoneDamageMeterApp:OnHide()
end
