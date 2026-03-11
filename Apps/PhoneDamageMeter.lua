-- PhoneDamageMeter - Personal DPS/HPS tracker for HearthPhone
-- Uses C_DamageMeter API (12.0+). During combat, values are "secret" (tainted)
-- but can still be passed to WoW C-side functions (SetText, AbbreviateNumbers)
-- for live display. We avoid pure Lua math on tainted values.

PhoneDamageMeterApp = {}

local parent
local WHITE = "Interface\\Buttons\\WHITE8x8"

local inCombat = false
local startTime = 0
local damage = 0
local healing = 0
local duration = 0
local history = {}
local currentEncounter = nil

local liveDps = nil
local liveHps = nil
local liveDmgTotal = nil
local liveHealTotal = nil

local dpsFs, hpsFs, durationFs, totalDmgFs, totalHealFs, statusFs
local historyRows = {}
local histEmptyFs
local histScroll, histContent

local MAX_HISTORY = 50

-- Tab state
local currentTab = "personal"
local tabFrames = {}
local tabButtons = {}

-- Captured recapId from Blizzard's system
local lastRecapId = nil

local function SaveHistory()
    if not HearthPhoneDB then HearthPhoneDB = {} end
    HearthPhoneDB.dmHistory = history
end

local function LoadHistory()
    if HearthPhoneDB and HearthPhoneDB.dmHistory then
        history = HearthPhoneDB.dmHistory
    end
end

local useNativeDM = (C_DamageMeter ~= nil)

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
-- C_DamageMeter live polling
-- ============================================================
local function PollLiveDM()
    if not useNativeDM then return end
    pcall(function()
        local dmgSession = C_DamageMeter.GetCombatSessionFromType(
            Enum.DamageMeterSessionType.Current,
            Enum.DamageMeterType.DamageDone
        )
        if dmgSession then
            for _, src in ipairs(dmgSession.combatSources) do
                if src.isLocalPlayer then
                    liveDps = src.amountPerSecond
                    liveDmgTotal = src.totalAmount
                    break
                end
            end
        end
        local healSession = C_DamageMeter.GetCombatSessionFromType(
            Enum.DamageMeterSessionType.Current,
            Enum.DamageMeterType.HealingDone
        )
        if healSession then
            for _, src in ipairs(healSession.combatSources) do
                if src.isLocalPlayer then
                    liveHps = src.amountPerSecond
                    liveHealTotal = src.totalAmount
                    break
                end
            end
        end
    end)
end

local secretWaitTicker
local function PollCleanDM()
    if not useNativeDM then return false end
    local gotData = false
    pcall(function()
        local dmgSession = C_DamageMeter.GetCombatSessionFromType(
            Enum.DamageMeterSessionType.Current,
            Enum.DamageMeterType.DamageDone
        )
        if dmgSession then
            if issecretvalue and issecretvalue(dmgSession.durationSeconds) then
                return
            end
            duration = dmgSession.durationSeconds or 0
            for _, src in ipairs(dmgSession.combatSources) do
                if src.isLocalPlayer then
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
            for _, src in ipairs(healSession.combatSources) do
                if src.isLocalPlayer then
                    healing = src.totalAmount or 0
                    break
                end
            end
        end
        gotData = true
    end)
    return gotData
end

-- ============================================================
-- Personal tab display
-- ============================================================
local function UpdatePersonalDisplay()
    if not dpsFs then return end

    local dur
    if inCombat and startTime > 0 then
        dur = GetTime() - startTime
    else
        dur = math.max(duration, 0)
    end
    local durSafe = math.max(dur, 1)

    if inCombat and liveDps ~= nil then
        dpsFs:SetText("|cffff4444" .. AbbreviateNumbers(liveDps) .. "|r")
        hpsFs:SetText("|cff44ff44" .. AbbreviateNumbers(liveHps or 0) .. "|r")
        totalDmgFs:SetText("|cff888888Dmg: |r|cffcccccc" .. AbbreviateNumbers(liveDmgTotal or 0) .. "|r")
        totalHealFs:SetText("|cff888888Heal: |r|cffcccccc" .. AbbreviateNumbers(liveHealTotal or 0) .. "|r")
    else
        dpsFs:SetText("|cffff4444" .. FormatNumber(damage / durSafe) .. "|r")
        hpsFs:SetText("|cff44ff44" .. FormatNumber(healing / durSafe) .. "|r")
        totalDmgFs:SetText("|cff888888Dmg: |r|cffcccccc" .. FormatNumber(damage) .. "|r")
        totalHealFs:SetText("|cff888888Heal: |r|cffcccccc" .. FormatNumber(healing) .. "|r")
    end

    durationFs:SetText("|cff888888" .. format("%d:%02d", math.floor(dur / 60), math.floor(dur % 60)) .. "|r")

    if inCombat then
        statusFs:SetText("|cffff4444In Combat|r")
    elseif secretWaitTicker then
        statusFs:SetText("|cffffff00Loading...|r")
    else
        statusFs:SetText("|cff44ff44Out of Combat|r")
    end
end

-- ============================================================
-- Group leaderboard tabs (Damage, Healing, Taken)
-- ============================================================
local BOARD_ROW_HEIGHT = 20
local BOARD_MAX_ROWS = 20

-- Pool of leaderboard rows per tab
local boardRows = {}    -- [tabKey] = { rows }
local boardScrolls = {} -- [tabKey] = scrollFrame
local boardContents = {} -- [tabKey] = contentFrame
local boardStatusFs = {} -- [tabKey] = status font string
local boardTitleFs = {} -- [tabKey] = title font string

local boardConfig = {
    damage = {
        title = "Damage Done",
        titleColor = "ff4444",
        meterType = "DamageDone",
        barColor = {0.8, 0.2, 0.2},
        valueColor = "ff4444",
        psLabel = "dps",
    },
    healing = {
        title = "Healing Done",
        titleColor = "44ff44",
        meterType = "HealingDone",
        barColor = {0.2, 0.7, 0.2},
        valueColor = "44ff44",
        psLabel = "hps",
    },
    taken = {
        title = "Damage Taken",
        titleColor = "ff8844",
        meterType = "DamageTaken",
        barColor = {0.7, 0.4, 0.15},
        valueColor = "ff8844",
        psLabel = "dtps",
    },
    deaths = {
        title = "Deaths",
        titleColor = "aaaaaa",
        meterType = "Deaths",
        barColor = {0.4, 0.4, 0.4},
        valueColor = "aaaaaa",
        psLabel = "deaths",
    },
}

local function GetOrCreateBoardRow(tabKey, idx, contentFrame)
    if not boardRows[tabKey] then boardRows[tabKey] = {} end
    if boardRows[tabKey][idx] then return boardRows[tabKey][idx] end

    local row = CreateFrame("Frame", nil, contentFrame)
    row:SetHeight(BOARD_ROW_HEIGHT)

    -- Bar background
    local bar = row:CreateTexture(nil, "BACKGROUND")
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetWidth(1)
    bar:SetTexture(WHITE)
    local cfg = boardConfig[tabKey]
    bar:SetVertexColor(cfg.barColor[1], cfg.barColor[2], cfg.barColor[3], 0.3)
    row.bar = bar

    -- Rank
    local rankFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    rankFs:SetPoint("LEFT", 2, 0)
    rankFs:SetWidth(14)
    rankFs:SetJustifyH("CENTER")
    local rf = rankFs:GetFont()
    if rf then rankFs:SetFont(rf, 8, "") end
    row.rankFs = rankFs

    -- Name
    local nameFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    nameFs:SetPoint("LEFT", 18, 0)
    nameFs:SetWidth(60)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetWordWrap(false)
    local nf = nameFs:GetFont()
    if nf then nameFs:SetFont(nf, 8, "") end
    row.nameFs = nameFs

    -- Per-second value
    local psFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    psFs:SetPoint("RIGHT", -2, 0)
    psFs:SetJustifyH("RIGHT")
    local pf = psFs:GetFont()
    if pf then psFs:SetFont(pf, 8, "") end
    row.psFs = psFs

    -- Total value
    local totalFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalFs:SetPoint("RIGHT", psFs, "LEFT", -4, 0)
    totalFs:SetJustifyH("RIGHT")
    local tf = totalFs:GetFont()
    if tf then totalFs:SetFont(tf, 8, "") end
    row.totalFs = totalFs

    boardRows[tabKey][idx] = row
    return row
end

local function UpdateBoardTab(tabKey)
    if not useNativeDM then return end
    if not boardContents[tabKey] then return end

    local cfg = boardConfig[tabKey]
    local contentFrame = boardContents[tabKey]

    -- Update status
    if boardStatusFs[tabKey] then
        if inCombat then
            boardStatusFs[tabKey]:SetText("|cffff4444In Combat|r")
        else
            boardStatusFs[tabKey]:SetText("|cff44ff44Out of Combat|r")
        end
    end

    pcall(function()
        local meterEnum = Enum.DamageMeterType[cfg.meterType]
        local session = C_DamageMeter.GetCombatSessionFromType(
            Enum.DamageMeterSessionType.Current,
            meterEnum
        )
        if not session then
            -- No session, hide all rows
            for _, row in ipairs(boardRows[tabKey] or {}) do
                row:Hide()
            end
            return
        end

        local sources = session.combatSources
        local count = #sources
        local maxCount = math.min(count, BOARD_MAX_ROWS)
        local yOffset = 0
        local rowWidth = contentFrame:GetWidth()
        if rowWidth < 10 then rowWidth = 140 end

        for i = 1, maxCount do
            local src = sources[i]
            local row = GetOrCreateBoardRow(tabKey, i, contentFrame)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -yOffset)
            row:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)

            -- Rank
            row.rankFs:SetText("|cff888888" .. i .. "|r")

            -- Name (tainted — pass directly to SetText)
            local displayName = src.name
            pcall(function()
                local resolved = UnitName(src.name)
                if resolved then displayName = resolved end
            end)
            if src.isLocalPlayer then
                row.nameFs:SetText("|cffffff00" .. displayName .. "|r")
            else
                row.nameFs:SetText("|cffcccccc" .. displayName .. "|r")
            end

            -- Values (tainted — use AbbreviateNumbers)
            if tabKey == "deaths" then
                row.totalFs:SetText("|cffff0000Dead|r")
                row.psFs:SetText("")
            else
                row.totalFs:SetText("|cffcccccc" .. AbbreviateNumbers(src.totalAmount) .. "|r")
                row.psFs:SetText("|cff" .. cfg.valueColor .. AbbreviateNumbers(src.amountPerSecond) .. " " .. cfg.psLabel .. "|r")
            end

            -- Bar width (we can't do math on tainted topValue, so just fill proportionally by rank)
            local barFraction = (maxCount - i + 1) / maxCount
            row.bar:SetWidth(math.max(1, rowWidth * barFraction))

            row:Show()
            yOffset = yOffset + BOARD_ROW_HEIGHT + 1
        end

        -- Hide unused rows
        for j = maxCount + 1, #(boardRows[tabKey] or {}) do
            boardRows[tabKey][j]:Hide()
        end

        contentFrame:SetHeight(math.max(20, yOffset))
    end)
end

-- ============================================================
-- History (personal tab)
-- ============================================================
local ROW_HEIGHT = 26
local ROW_PAD = 2
local HEADER_HEIGHT = 16
local MARGIN = 4
local histHeaders = {}
local histNameLabels = {}
local NAME_LABEL_HEIGHT = 12
local SEP_HEIGHT = 3
local histSeps = {}

local function GetOrCreateRow(idx)
    if historyRows[idx] then return historyRows[idx] end
    if not histContent then return nil end

    local row = CreateFrame("Frame", nil, histContent)
    row:SetHeight(ROW_HEIGHT)

    local timerFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    timerFs:SetPoint("LEFT", 0, 0)
    timerFs:SetWidth(36)
    timerFs:SetJustifyH("CENTER")
    local tf = timerFs:GetFont()
    if tf then timerFs:SetFont(tf, 10, "") end

    local dpsFs2 = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dpsFs2:SetPoint("TOPLEFT", 38, -2)
    dpsFs2:SetJustifyH("LEFT")
    local df = dpsFs2:GetFont()
    if df then dpsFs2:SetFont(df, 9, "") end

    local hpsFs2 = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hpsFs2:SetPoint("LEFT", row, "LEFT", 116, 0)
    hpsFs2:SetPoint("TOP", 0, -2)
    hpsFs2:SetJustifyH("LEFT")
    local hf = hpsFs2:GetFont()
    if hf then hpsFs2:SetFont(hf, 9, "") end

    local dmgFs2 = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dmgFs2:SetPoint("BOTTOMLEFT", 38, 2)
    dmgFs2:SetJustifyH("LEFT")
    local dmf = dmgFs2:GetFont()
    if dmf then dmgFs2:SetFont(dmf, 9, "") end

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

local UpdateHistory
UpdateHistory = function()
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

        rowCount = rowCount + 1
        local sepTex = GetOrCreateSep(rowCount)
        if sepTex then
            sepTex:ClearAllPoints()
            sepTex:SetPoint("TOPLEFT", histContent, "TOPLEFT", MARGIN, -yOffset)
            sepTex:SetPoint("RIGHT", histContent, "RIGHT", -MARGIN, 0)
            sepTex:Show()
            yOffset = yOffset + SEP_HEIGHT
        end

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

    for j = rowCount + 1, #historyRows do historyRows[j]:Hide() end
    for j = rowCount + 1, #histNameLabels do histNameLabels[j]:Hide() end
    for j = rowCount + 1, #histSeps do histSeps[j]:Hide() end
    for j = headerCount + 1, #histHeaders do histHeaders[j]:Hide() end

    histContent:SetHeight(math.max(20, yOffset))
end

-- ============================================================
-- Death Recap tab
-- ============================================================
local recapRows = {}
local recapScroll, recapContent, recapEmptyFs, recapTitleFs, recapStatusFs
local RECAP_ROW_HEIGHT = 28

local function GetOrCreateRecapRow(idx)
    if recapRows[idx] then return recapRows[idx] end
    if not recapContent then return nil end

    local row = CreateFrame("Frame", nil, recapContent)
    row:SetHeight(RECAP_ROW_HEIGHT)

    -- Icon (left edge)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", 2, 0)
    icon:SetSize(18, 18)
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    row.icon = icon

    -- Spell name (top, after icon + timestamp gap)
    local spellFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    spellFs:SetPoint("TOPLEFT", 50, -2)
    spellFs:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    spellFs:SetJustifyH("LEFT")
    spellFs:SetWordWrap(false)
    local sf = spellFs:GetFont()
    if sf then spellFs:SetFont(sf, 8, "") end
    row.spellFs = spellFs

    -- Source name (bottom, after icon + timestamp gap)
    local srcFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    srcFs:SetPoint("BOTTOMLEFT", 50, 2)
    srcFs:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    srcFs:SetJustifyH("LEFT")
    srcFs:SetWordWrap(false)
    local srf = srcFs:GetFont()
    if srf then srcFs:SetFont(srf, 7, "") end
    row.srcFs = srcFs

    -- Damage amount (right side)
    local amtFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    amtFs:SetPoint("RIGHT", -2, 4)
    amtFs:SetJustifyH("RIGHT")
    local af = amtFs:GetFont()
    if af then amtFs:SetFont(af, 9, "") end
    row.amtFs = amtFs

    -- HP remaining (below amount)
    local hpFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hpFs:SetPoint("RIGHT", -2, -5)
    hpFs:SetJustifyH("RIGHT")
    local hf = hpFs:GetFont()
    if hf then hpFs:SetFont(hf, 7, "") end
    row.hpFs = hpFs

    -- Timestamp (between icon and spell text)
    local timeFs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timeFs:SetPoint("LEFT", 22, 0)
    timeFs:SetWidth(26)
    timeFs:SetJustifyH("CENTER")
    local tmf = timeFs:GetFont()
    if tmf then timeFs:SetFont(tmf, 7, "") end
    row.timeFs = timeFs

    recapRows[idx] = row
    return row
end

local function UpdateRecapTab()
    if not recapContent then return end

    -- Hide all first
    for _, row in ipairs(recapRows) do row:Hide() end
    if recapEmptyFs then recapEmptyFs:Hide() end

    if not C_DeathRecap then
        if recapEmptyFs then
            recapEmptyFs:SetText("|cff666666Death recap unavailable|r")
            recapEmptyFs:Show()
        end
        return
    end

    -- Find the most recent death recap
    local hasRecap = false
    local events
    local maxHealth = 1

    pcall(function()
        -- Load Blizzard's DeathRecap addon if not yet loaded (provides DeathRecap_GetEvents)
        if not DeathRecap_GetEvents and C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_DeathRecap")
        end

        -- Use Blizzard's global function (same one Details! uses)
        local getEvents = DeathRecap_GetEvents or (C_DeathRecap and C_DeathRecap.GetRecapEvents)
        local hasEvents = C_DeathRecap and C_DeathRecap.HasRecapEvents
        local getMaxHP = C_DeathRecap and C_DeathRecap.GetRecapMaxHealth
        if not getEvents or not hasEvents then return end

        -- If we captured the recapId from Blizzard's hook, use it directly
        if lastRecapId and hasEvents(lastRecapId) then
            local evts = getEvents(lastRecapId)
            if evts and #evts > 0 then
                events = evts
                if getMaxHP then maxHealth = getMaxHP(lastRecapId) or 1 end
                hasRecap = true
                return
            end
        end

        -- Fallback: scan all IDs, no hard cap — stop after 5 consecutive misses
        local bestTs = 0
        local misses = 0
        local recapId = 1
        while misses < 5 do
            if hasEvents(recapId) then
                misses = 0
                local evts = getEvents(recapId)
                if evts and #evts > 0 then
                    local ts = evts[1].timestamp or 0
                    if ts > bestTs then
                        bestTs = ts
                        events = evts
                        if getMaxHP then maxHealth = getMaxHP(recapId) or 1 end
                        hasRecap = true
                    end
                end
            else
                misses = misses + 1
            end
            recapId = recapId + 1
        end
    end)

    if not hasRecap or not events or #events == 0 then
        if recapEmptyFs then
            recapEmptyFs:SetText("|cff666666No recent deaths|r")
            recapEmptyFs:Show()
        end
        recapContent:SetHeight(20)
        return
    end

    local yOffset = 0
    local count = math.min(#events, 15)

    -- Compute relative timestamps (seconds before death)
    -- events are chronological: events[1]=most recent hit, events[#events]=oldest
    local deathTime = events[1] and events[1].timestamp
    local timeDiffs = {}
    if deathTime then
        for i = 1, #events do
            if events[i].timestamp then
                timeDiffs[i] = format("%.1fs", events[i].timestamp - deathTime)
            end
        end
    end

    -- Show events in API order (index 1 at top)
    for i = 1, count do
        local ev = events[i]
        local row = GetOrCreateRecapRow(i)
        if not row then break end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -yOffset)
        row:SetPoint("RIGHT", recapContent, "RIGHT", 0, 0)

        -- Spell icon
        local spellName = ev.spellName or "Melee"
        local spellIcon = nil
        pcall(function()
            if ev.spellId and ev.spellId > 0 then
                local info = C_Spell.GetSpellInfo(ev.spellId)
                if info then
                    spellName = info.name or spellName
                    spellIcon = info.iconID
                end
            end
        end)
        if spellIcon then
            row.icon:SetTexture(spellIcon)
            row.icon:Show()
        else
            row.icon:SetTexture(136235) -- default melee icon
            row.icon:Show()
        end

        -- Spell name
        row.spellFs:SetText("|cffcccccc" .. spellName .. "|r")

        -- Source
        local srcName = ev.sourceName or UNKNOWN
        row.srcFs:SetText("|cff888888" .. srcName .. "|r")

        -- Amount: show raw damage like Blizzard, absorbed in parens
        local amt = ev.amount or 0
        local absorbed = ev.absorbed or 0
        if amt > 0 and absorbed > 0 then
            row.amtFs:SetText("|cffff4444-" .. AbbreviateNumbers(amt) .. "|r |cff888888(" .. AbbreviateNumbers(absorbed) .. ")|r")
        elseif amt > 0 then
            row.amtFs:SetText("|cffff4444-" .. AbbreviateNumbers(amt) .. "|r")
        elseif absorbed > 0 then
            row.amtFs:SetText("|cff888888(" .. AbbreviateNumbers(absorbed) .. ")|r")
        else
            row.amtFs:SetText("")
        end

        -- HP remaining / overkill
        local hp = ev.currentHP or 0
        local overkill = ev.overkill or 0
        if overkill > 0 then
            row.hpFs:SetText("|cffff0000" .. AbbreviateNumbers(overkill) .. " overkill|r")
        elseif hp <= 0 then
            row.hpFs:SetText("|cffff0000DEAD|r")
        else
            row.hpFs:SetText("|cff888888" .. AbbreviateNumbers(hp) .. " HP|r")
        end

        -- Relative timestamp
        if row.timeFs then
            if timeDiffs[i] then
                row.timeFs:SetText("|cff666666" .. timeDiffs[i] .. "|r")
            else
                row.timeFs:SetText("")
            end
        end

        row:Show()
        yOffset = yOffset + RECAP_ROW_HEIGHT + 1
    end

    -- Hide excess rows
    for j = count + 1, #recapRows do
        recapRows[j]:Hide()
    end

    recapContent:SetHeight(math.max(20, yOffset))
end

-- ============================================================
-- Tab switching
-- ============================================================
local function ShowTab(tabKey)
    currentTab = tabKey
    for key, frame in pairs(tabFrames) do
        if key == tabKey then
            frame:Show()
        else
            frame:Hide()
        end
    end
    for key, btn in pairs(tabButtons) do
        if key == tabKey then
            btn.bg:SetVertexColor(0.3, 0.3, 0.4, 1)
        else
            btn.bg:SetVertexColor(0.15, 0.15, 0.18, 1)
        end
    end
    if tabKey == "personal" then
        UpdatePersonalDisplay()
        UpdateHistory()
    elseif tabKey == "recap" then
        UpdateRecapTab()
    else
        UpdateBoardTab(tabKey)
    end
end

-- ============================================================
-- Combat events
-- ============================================================
local function OnCombatStart()
    inCombat = true
    damage = 0
    healing = 0
    liveDps = nil
    liveHps = nil
    liveDmgTotal = nil
    liveHealTotal = nil
    startTime = GetTime()
    duration = 0
    -- Clear recap display for fresh data
    for _, row in ipairs(recapRows) do row:Hide() end
    if recapEmptyFs then
        recapEmptyFs:SetText("|cff666666In combat...|r")
        recapEmptyFs:Show()
    end
    if currentTab == "personal" then
        UpdatePersonalDisplay()
    else
        UpdateBoardTab(currentTab)
    end
end

local function RecordHistory()
    if damage <= 0 and healing <= 0 then return end
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

local function WaitForSecretsDrop()
    if secretWaitTicker then return end
    local attempts = 0
    secretWaitTicker = C_Timer.NewTicker(1, function(ticker)
        attempts = attempts + 1
        local gotData = PollCleanDM()
        if (gotData and damage > 0) or attempts >= 10 then
            ticker:Cancel()
            secretWaitTicker = nil
            RecordHistory()
            if currentTab == "personal" then
                UpdatePersonalDisplay()
            end
        end
    end)
end

local function OnCombatEnd()
    if not inCombat then return end
    inCombat = false

    if startTime > 0 then
        duration = GetTime() - startTime
    end

    local gotClean = PollCleanDM()
    if gotClean and damage > 0 then
        RecordHistory()
    else
        WaitForSecretsDrop()
    end
    if currentTab == "personal" then
        UpdatePersonalDisplay()
    elseif currentTab == "recap" then
        UpdateRecapTab()
    else
        UpdateBoardTab(currentTab)
    end
end

local function CombatReset()
    damage = 0
    healing = 0
    duration = 0
    startTime = 0
    liveDps = nil
    liveHps = nil
    liveDmgTotal = nil
    liveHealTotal = nil
    history = {}
    SaveHistory()
    if secretWaitTicker then
        secretWaitTicker:Cancel()
        secretWaitTicker = nil
    end
    if useNativeDM then
        pcall(function() C_DamageMeter.ResetAllCombatSessions() end)
    end
    if currentTab == "personal" then
        UpdatePersonalDisplay()
    end
end

-- ============================================================
-- Hook Blizzard's DeathRecapFrame_OpenRecap to capture the exact recapId
-- ============================================================
local function SetupRecapHook()
    if not DeathRecap_GetEvents and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_DeathRecap")
    end
    if DeathRecapFrame_OpenRecap and not PhoneDamageMeterApp._recapHooked then
        hooksecurefunc("DeathRecapFrame_OpenRecap", function(recapId)
            lastRecapId = recapId
            if currentTab == "recap" then
                UpdateRecapTab()
            end
        end)
        PhoneDamageMeterApp._recapHooked = true
    end
end

-- ============================================================
-- Event frame
-- ============================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("PLAYER_DEAD")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()
    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()
    elseif event == "ENCOUNTER_START" then
        local _, name = ...
        currentEncounter = name
    elseif event == "ENCOUNTER_END" then
        C_Timer.After(1, function() currentEncounter = nil end)
    elseif event == "PLAYER_DEAD" then
        -- Ensure our hook is set up to capture the recapId
        SetupRecapHook()
        -- Delay slightly so Blizzard populates the recap data
        C_Timer.After(0.5, function()
            if currentTab == "recap" then
                UpdateRecapTab()
            end
        end)
    end
end)

eventFrame:SetScript("OnUpdate", function()
    if not inCombat then return end
    local now = GetTime()
    if now - (eventFrame.lastUpdate or 0) < 1 then return end
    eventFrame.lastUpdate = now
    if useNativeDM then PollLiveDM() end
    if currentTab == "personal" then
        UpdatePersonalDisplay()
    elseif currentTab == "recap" then
        -- recap doesn't update during combat
    else
        UpdateBoardTab(currentTab)
    end
end)

-- ============================================================
-- Init
-- ============================================================
function PhoneDamageMeterApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame
    LoadHistory()
    SetupRecapHook()

    local PAD = 4
    local TAB_HEIGHT = 16
    local TAB_TOP = -4
    local TABS_PER_ROW = 3

    -- Tab bar — two rows of 3
    local tabDefs = {
        { key = "personal", label = "Me" },
        { key = "damage",   label = "Dmg" },
        { key = "healing",  label = "Heal" },
        { key = "taken",    label = "Taken" },
        { key = "deaths",   label = "Deaths" },
        { key = "recap",    label = "Recap" },
    }
    local totalWidth = (parent:GetWidth() or 160) - PAD * 2
    local tabWidth = math.floor(totalWidth / TABS_PER_ROW)
    if tabWidth < 30 then tabWidth = 40 end

    for i, def in ipairs(tabDefs) do
        local col = (i - 1) % TABS_PER_ROW
        local row = math.floor((i - 1) / TABS_PER_ROW)
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(tabWidth, TAB_HEIGHT)
        btn:SetPoint("TOPLEFT", PAD + col * tabWidth, TAB_TOP - row * (TAB_HEIGHT + 1))

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(WHITE)
        bg:SetVertexColor(0.15, 0.15, 0.18, 1)
        btn.bg = bg

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(WHITE)
        hl:SetVertexColor(1, 1, 1, 0.08)

        local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        local f = fs:GetFont()
        if f then fs:SetFont(f, 9, "") end
        fs:SetText("|cffffffff" .. def.label .. "|r")
        btn.label = fs

        btn:SetScript("OnClick", function() ShowTab(def.key) end)
        tabButtons[def.key] = btn
    end

    local numRows = math.ceil(#tabDefs / TABS_PER_ROW)
    local contentTop = TAB_TOP - numRows * (TAB_HEIGHT + 1) - 1

    -- ============================================================
    -- Personal tab content
    -- ============================================================
    local personalFrame = CreateFrame("Frame", nil, parent)
    personalFrame:SetPoint("TOPLEFT", PAD, contentTop)
    personalFrame:SetPoint("BOTTOMRIGHT", -PAD, 4)
    tabFrames["personal"] = personalFrame

    statusFs = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusFs:SetPoint("TOP", 0, -2)
    statusFs:SetText("|cff44ff44Out of Combat|r")
    local sf = statusFs:GetFont()
    if sf then statusFs:SetFont(sf, 9, "") end

    local dpsLabel = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dpsLabel:SetPoint("TOP", -45, -16)
    dpsLabel:SetText("|cff888888DPS|r")
    local dlf = dpsLabel:GetFont()
    if dlf then dpsLabel:SetFont(dlf, 9, "") end

    dpsFs = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dpsFs:SetPoint("TOP", -45, -28)
    dpsFs:SetText("|cffff44440|r")
    local dpf = dpsFs:GetFont()
    if dpf then dpsFs:SetFont(dpf, 24, "") end

    local hpsLabel = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hpsLabel:SetPoint("TOP", 45, -16)
    hpsLabel:SetText("|cff888888HPS|r")
    local hlf = hpsLabel:GetFont()
    if hlf then hpsLabel:SetFont(hlf, 9, "") end

    hpsFs = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hpsFs:SetPoint("TOP", 45, -28)
    hpsFs:SetText("|cff44ff440|r")
    local hpf = hpsFs:GetFont()
    if hpf then hpsFs:SetFont(hpf, 24, "") end

    durationFs = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    durationFs:SetPoint("TOP", 0, -56)
    durationFs:SetText("|cff8888880:00|r")
    local cdf = durationFs:GetFont()
    if cdf then durationFs:SetFont(cdf, 12, "") end

    totalDmgFs = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalDmgFs:SetPoint("TOPLEFT", 2, -72)
    totalDmgFs:SetText("|cff888888Dmg: |r|cffcccccc0|r")
    local tdf = totalDmgFs:GetFont()
    if tdf then totalDmgFs:SetFont(tdf, 9, "") end

    totalHealFs = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    totalHealFs:SetPoint("TOPRIGHT", -2, -72)
    totalHealFs:SetText("|cff888888Heal: |r|cffcccccc0|r")
    local thf = totalHealFs:GetFont()
    if thf then totalHealFs:SetFont(thf, 9, "") end

    local resetBtn = CreateBtn(personalFrame, 36, 14, "Reset", {0.35, 0.2, 0.2}, function()
        CombatReset()
        UpdateHistory()
    end)
    resetBtn:SetPoint("TOPRIGHT", 0, 0)

    local sep = personalFrame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 0, -86)
    sep:SetPoint("TOPRIGHT", 0, -86)
    sep:SetHeight(1)
    sep:SetTexture(WHITE)
    sep:SetVertexColor(0.3, 0.3, 0.35, 0.5)

    local histLabel = personalFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    histLabel:SetPoint("TOPLEFT", 2, -90)
    histLabel:SetText("|cff888888Fight History|r")
    local hlf2 = histLabel:GetFont()
    if hlf2 then histLabel:SetFont(hlf2, 9, "OUTLINE") end

    histScroll = CreateFrame("ScrollFrame", nil, personalFrame)
    histScroll:SetPoint("TOPLEFT", 0, -104)
    histScroll:SetPoint("BOTTOMRIGHT", 0, 0)
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

    -- ============================================================
    -- Board tabs (Damage, Healing, Taken, Deaths)
    -- ============================================================
    for _, tabKey in ipairs({"damage", "healing", "taken", "deaths"}) do
        local cfg = boardConfig[tabKey]
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetPoint("TOPLEFT", PAD, contentTop)
        frame:SetPoint("BOTTOMRIGHT", -PAD, 4)
        frame:Hide()
        tabFrames[tabKey] = frame

        -- Title
        local titleFs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        titleFs:SetPoint("TOP", 0, -2)
        titleFs:SetText("|cff" .. cfg.titleColor .. cfg.title .. "|r")
        local btf = titleFs:GetFont()
        if btf then titleFs:SetFont(btf, 11, "OUTLINE") end
        boardTitleFs[tabKey] = titleFs

        -- Status
        local bsFs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        bsFs:SetPoint("TOP", 0, -18)
        bsFs:SetText("|cff44ff44Out of Combat|r")
        local bsf = bsFs:GetFont()
        if bsf then bsFs:SetFont(bsf, 9, "") end
        boardStatusFs[tabKey] = bsFs

        -- Scrollable leaderboard
        local scroll = CreateFrame("ScrollFrame", nil, frame)
        scroll:SetPoint("TOPLEFT", 0, -32)
        scroll:SetPoint("BOTTOMRIGHT", 0, 0)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local cur = self:GetVerticalScroll()
            local content = boardContents[tabKey]
            local maxS = math.max(0, (content:GetHeight() or 20) - self:GetHeight())
            self:SetVerticalScroll(math.min(maxS, math.max(0, cur - delta * 16)))
        end)
        boardScrolls[tabKey] = scroll

        local content = CreateFrame("Frame", nil, scroll)
        scroll:SetScrollChild(content)
        boardContents[tabKey] = content

        C_Timer.After(0, function()
            local w = scroll:GetWidth()
            if w and w > 10 then
                content:SetSize(w, 20)
            else
                content:SetSize(140, 20)
            end
        end)
    end

    -- ============================================================
    -- Recap tab
    -- ============================================================
    do
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetPoint("TOPLEFT", PAD, contentTop)
        frame:SetPoint("BOTTOMRIGHT", -PAD, 4)
        frame:Hide()
        tabFrames["recap"] = frame

        local titleFs = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        titleFs:SetPoint("TOP", 0, -2)
        titleFs:SetText("|cffff4444Death Recap|r")
        local rtf = titleFs:GetFont()
        if rtf then titleFs:SetFont(rtf, 11, "OUTLINE") end

        local rScroll = CreateFrame("ScrollFrame", nil, frame)
        rScroll:SetPoint("TOPLEFT", 0, -18)
        rScroll:SetPoint("BOTTOMRIGHT", 0, 0)
        rScroll:EnableMouseWheel(true)
        rScroll:SetScript("OnMouseWheel", function(self, delta)
            local cur = self:GetVerticalScroll()
            local maxS = math.max(0, (recapContent:GetHeight() or 20) - self:GetHeight())
            self:SetVerticalScroll(math.min(maxS, math.max(0, cur - delta * 16)))
        end)
        recapScroll = rScroll

        recapContent = CreateFrame("Frame", nil, rScroll)
        rScroll:SetScrollChild(recapContent)

        C_Timer.After(0, function()
            local w = rScroll:GetWidth()
            if w and w > 10 then
                recapContent:SetSize(w, 20)
            else
                recapContent:SetSize(140, 20)
            end
        end)

        recapEmptyFs = recapContent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        recapEmptyFs:SetPoint("TOPLEFT", 0, 0)
        recapEmptyFs:SetJustifyH("LEFT")
        local ref = recapEmptyFs:GetFont()
        if ref then recapEmptyFs:SetFont(ref, 9, "") end
        recapEmptyFs:SetText("|cff666666No recent deaths|r")
    end

    -- Start on personal tab
    ShowTab("personal")
end

function PhoneDamageMeterApp:OnShow()
    if useNativeDM and not inCombat then PollCleanDM() end
    if currentTab == "personal" then
        UpdatePersonalDisplay()
        UpdateHistory()
    elseif currentTab == "recap" then
        UpdateRecapTab()
    else
        UpdateBoardTab(currentTab)
    end
    if histScroll and histContent then
        local w = histScroll:GetWidth()
        if w and w > 10 then histContent:SetWidth(w) end
    end
end

function PhoneDamageMeterApp:OnHide()
end
