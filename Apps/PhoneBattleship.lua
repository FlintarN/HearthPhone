-- PhoneBattleship - Battleship for HearthPhone (AI + PvP via PhoneGameChallenge)

PhoneBattleshipGame = {}

local GAME_ID = "battleship"
local GS = 8  -- grid size
local GAP = 2

local SHIPS = {
    {name = "Carrier",   size = 4},
    {name = "Cruiser",   size = 3},
    {name = "Submarine", size = 3},
    {name = "Destroyer", size = 2},
}

-- Textures
local TEX_PATH = "Interface\\AddOns\\HearthPhone\\Textures\\"
local TEX_HIT = TEX_PATH .. "HitExplosion"
local TEX_SPLASH = TEX_PATH .. "MissSplash"

-- Colors
local CW  = {0.08, 0.16, 0.30}  -- water
local CS  = {0.38, 0.40, 0.46}  -- ship
local CH  = {0.85, 0.18, 0.12}  -- hit
local CU  = {0.11, 0.20, 0.34}  -- unknown
local CPO = {0.22, 0.52, 0.28}  -- preview ok
local CPB = {0.58, 0.18, 0.12}  -- preview bad

-- State
local gameFrame, statusText
local phase = "menu"  -- menu, placing, battle, gameover
local pvpMode, opponentName, demoActive = false, nil, false
local myTurn, iGoFirst = false, false
local opponentReady, imReady = false, false
local visible = false

-- Grids [r][c]
local myGrid = {}       -- 0=water, 1-4=ship index
local myHits = {}       -- nil/"hit"/"miss" (opponent's shots on me)
local enemyView = {}    -- nil/"hit"/"miss" (my shots on enemy)

-- Ship state
local myShips = {}      -- {name, size, cells, hits, sunk}
local enemySunk = 0

-- AI state
local aiGrid = {}
local aiShips = {}
local aiShots = {}      -- [r][c]=true
local aiQueue = {}

-- Placement
local placeIdx = 1
local placeHoriz = true

-- UI refs
local modeView, playView
local cells = {}        -- [r][c] = {btn, bg, mark}
local prevCells = {}    -- preview highlights
local viewMyGrid = false

-- Placement UI
local placePanel, shipLabel, readyBtn, rotBtn, autoBtn
-- Battle UI
local battlePanel, toggleBtn, fleetLabel
-- Bottom buttons
local newBtn

-- Challenge list (PvP) - same pattern as TicTacToe
local challengeRows = {}
local challengeScroll, challengeContent
local challengeSearchText = ""
local selectView, waitingView, incomingView
local waitingTargetFs, waitingStatusFs, incomingFromFs, incomingGameFs

-- Forward declarations
local ShowMenu, ShowPlay, StartPlacement, StartBattle
local RefreshGrid, RefreshStatus
local OnCellClick, OnCellEnter, OnCellLeave
local HandleData, AIDoFire, ShowSelectView

-- ============================================================
-- Grid helpers
-- ============================================================
local function MkGrid()
    local g = {}
    for r = 1, GS do g[r] = {}; for c = 1, GS do g[r][c] = 0 end end
    return g
end

local function MkEmpty()
    local g = {}
    for r = 1, GS do g[r] = {} end
    return g
end

local function CanPlace(grid, r, c, sz, horiz)
    for i = 0, sz - 1 do
        local rr = horiz and r or r + i
        local cc = horiz and c + i or c
        if rr < 1 or rr > GS or cc < 1 or cc > GS or grid[rr][cc] ~= 0 then return false end
    end
    return true
end

local function DoPlace(grid, ships, idx, r, c, sz, horiz)
    local cl = {}
    for i = 0, sz - 1 do
        local rr = horiz and r or r + i
        local cc = horiz and c + i or c
        grid[rr][cc] = idx
        cl[#cl + 1] = {rr, cc}
    end
    ships[idx] = {name = SHIPS[idx].name, size = sz, cells = cl, hits = 0, sunk = false}
end

local function AutoPlace(grid, ships)
    for r = 1, GS do for c = 1, GS do grid[r][c] = 0 end end
    for idx, def in ipairs(SHIPS) do
        local ok = false
        for _ = 1, 200 do
            local h = math.random(2) == 1
            local r = math.random(h and GS or GS - def.size + 1)
            local c = math.random(h and GS - def.size + 1 or GS)
            if CanPlace(grid, r, c, def.size, h) then
                DoPlace(grid, ships, idx, r, c, def.size, h)
                ok = true; break
            end
        end
        if not ok then return false end
    end
    return true
end

local function ProcessShot(grid, ships, r, c)
    if grid[r][c] == 0 then return "MISS" end
    local s = ships[grid[r][c]]
    s.hits = s.hits + 1
    if s.hits >= s.size then s.sunk = true; return "SUNK", s.name end
    return "HIT"
end

local function CountAlive(ships)
    local n = 0
    for _, s in ipairs(ships) do if not s.sunk then n = n + 1 end end
    return n
end

local function AllSunk(ships)
    return CountAlive(ships) == 0
end

-- ============================================================
-- AI targeting
-- ============================================================
local function AIReset()
    aiShots = MkEmpty()
    aiQueue = {}
end

local function AIPickTarget()
    while #aiQueue > 0 do
        local t = table.remove(aiQueue, 1)
        if t[1] >= 1 and t[1] <= GS and t[2] >= 1 and t[2] <= GS and not aiShots[t[1]][t[2]] then
            return t[1], t[2]
        end
    end
    local opts = {}
    for r = 1, GS do for c = 1, GS do
        if not aiShots[r][c] then opts[#opts + 1] = {r, c} end
    end end
    if #opts == 0 then return nil end
    local p = opts[math.random(#opts)]
    return p[1], p[2]
end

AIDoFire = function()
    local r, c = AIPickTarget()
    if not r then return end
    aiShots[r][c] = true
    local res = ProcessShot(myGrid, myShips, r, c)
    if res == "HIT" or res == "SUNK" then
        myHits[r][c] = "hit"
        if res == "HIT" then
            for _, d in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
                aiQueue[#aiQueue + 1] = {r + d[1], c + d[2]}
            end
        end
    else
        myHits[r][c] = "miss"
    end
    RefreshGrid()
    RefreshStatus()
    if AllSunk(myShips) then
        phase = "gameover"
        statusText:SetText("|cffff4444You lose!|r")
        if newBtn then newBtn:Show() end
        return
    end
    myTurn = true
    statusText:SetText("|cff88ccffYour turn - Fire!|r")
end

-- ============================================================
-- UI refresh
-- ============================================================
RefreshGrid = function()
    for r = 1, GS do for c = 1, GS do
        local cl = cells[r][c]
        cl.mark:SetText("")
        cl.overlay:Hide()

        if phase == "placing" then
            if myGrid[r][c] ~= 0 then
                cl.bg:SetVertexColor(unpack(CS))
            else
                cl.bg:SetVertexColor(unpack(CW))
            end

        elseif phase == "battle" or phase == "gameover" then
            if viewMyGrid then
                local h = myHits[r] and myHits[r][c]
                if h == "hit" then
                    cl.bg:SetVertexColor(unpack(CH))
                    cl.overlay:SetTexture(TEX_HIT)
                    cl.overlay:SetVertexColor(1, 1, 1, 0.9)
                    cl.overlay:Show()
                elseif h == "miss" then
                    cl.bg:SetVertexColor(unpack(CW))
                    cl.overlay:SetTexture(TEX_SPLASH)
                    cl.overlay:SetVertexColor(1, 1, 1, 0.7)
                    cl.overlay:Show()
                elseif myGrid[r][c] ~= 0 then
                    cl.bg:SetVertexColor(unpack(CS))
                else
                    cl.bg:SetVertexColor(unpack(CW))
                end
            else
                local s = enemyView[r] and enemyView[r][c]
                if s == "hit" then
                    cl.bg:SetVertexColor(0.15, 0.15, 0.18)
                    cl.overlay:SetTexture(TEX_HIT)
                    cl.overlay:SetVertexColor(1, 1, 1, 0.95)
                    cl.overlay:Show()
                elseif s == "miss" then
                    cl.bg:SetVertexColor(unpack(CU))
                    cl.overlay:SetTexture(TEX_SPLASH)
                    cl.overlay:SetVertexColor(1, 1, 1, 0.6)
                    cl.overlay:Show()
                else
                    cl.bg:SetVertexColor(unpack(CU))
                end
            end
        end
    end end
end

RefreshStatus = function()
    if not fleetLabel then return end
    local myAlive = CountAlive(myShips)
    local enAlive = #SHIPS - enemySunk
    fleetLabel:SetText("|cff88ccffYou: " .. myAlive .. "/" .. #SHIPS
        .. "  |cffff6644Foe: " .. enAlive .. "/" .. #SHIPS .. "|r")
end

-- ============================================================
-- Phase transitions
-- ============================================================
ShowMenu = function()
    if modeView then modeView:Show() end
    if playView then playView:Hide() end
    if pvpMode and not demoActive and PhoneGameChallenge:GetState() == "active" then
        PhoneGameChallenge:Forfeit()
    end
    pvpMode = false
    opponentName = nil
    demoActive = false
    ShowSelectView()
end

ShowPlay = function()
    if modeView then modeView:Hide() end
    if playView then playView:Show() end
end

StartPlacement = function()
    phase = "placing"
    placeIdx = 1
    placeHoriz = true
    myGrid = MkGrid()
    myHits = MkEmpty()
    enemyView = MkEmpty()
    myShips = {}
    enemySunk = 0
    imReady = false
    opponentReady = false
    viewMyGrid = false

    ShowPlay()
    if placePanel then placePanel:Show() end
    if battlePanel then battlePanel:Hide() end
    if newBtn then newBtn:Hide() end
    if readyBtn then readyBtn:Hide() end
    if rotBtn then rotBtn:Show() end
    if autoBtn then autoBtn:Show() end

    local def = SHIPS[placeIdx]
    statusText:SetText("|cffaaaaaaPlace your " .. def.name .. " (" .. def.size .. ")|r")
    if shipLabel then shipLabel:SetText(def.name .. " (" .. def.size .. ")") end
    RefreshGrid()
end

StartBattle = function()
    phase = "battle"
    viewMyGrid = false

    if placePanel then placePanel:Hide() end
    if battlePanel then battlePanel:Show() end
    if newBtn then newBtn:Hide() end
    if toggleBtn then toggleBtn:SetText("|cffffffffMy Fleet|r") end

    myTurn = iGoFirst
    if myTurn then
        statusText:SetText("|cff88ccffYour turn - Fire!|r")
    else
        statusText:SetText("|cffff6644" .. Ambiguate(opponentName or "AI", "short") .. "'s turn|r")
        if not pvpMode then
            C_Timer.After(0.8, function()
                if phase == "battle" then AIDoFire() end
            end)
        end
    end
    RefreshGrid()
    RefreshStatus()
end

-- ============================================================
-- Preview (placement hover)
-- ============================================================
local function ClearPreview()
    for _, pc in ipairs(prevCells) do
        local cl = cells[pc[1]][pc[2]]
        if myGrid[pc[1]][pc[2]] ~= 0 then
            cl.bg:SetVertexColor(unpack(CS))
        else
            cl.bg:SetVertexColor(unpack(CW))
        end
    end
    prevCells = {}
end

OnCellEnter = function(r, c)
    if phase ~= "placing" or placeIdx > #SHIPS then return end
    ClearPreview()
    local def = SHIPS[placeIdx]
    local ok = CanPlace(myGrid, r, c, def.size, placeHoriz)
    local col = ok and CPO or CPB
    for i = 0, def.size - 1 do
        local rr = placeHoriz and r or r + i
        local cc = placeHoriz and c + i or c
        if rr >= 1 and rr <= GS and cc >= 1 and cc <= GS then
            cells[rr][cc].bg:SetVertexColor(unpack(col))
            prevCells[#prevCells + 1] = {rr, cc}
        end
    end
end

OnCellLeave = function()
    if phase == "placing" then ClearPreview() end
end

-- ============================================================
-- Cell click
-- ============================================================
OnCellClick = function(r, c)
    if phase == "placing" then
        if placeIdx > #SHIPS then return end
        local def = SHIPS[placeIdx]
        if not CanPlace(myGrid, r, c, def.size, placeHoriz) then
            statusText:SetText("|cffff4444Can't place there!|r")
            return
        end
        DoPlace(myGrid, myShips, placeIdx, r, c, def.size, placeHoriz)
        placeIdx = placeIdx + 1
        ClearPreview()
        RefreshGrid()

        if placeIdx > #SHIPS then
            statusText:SetText("|cff44ff44All ships placed!|r")
            if shipLabel then shipLabel:SetText("") end
            if readyBtn then readyBtn:Show() end
            if rotBtn then rotBtn:Hide() end
            if autoBtn then autoBtn:Hide() end
        else
            local nxt = SHIPS[placeIdx]
            statusText:SetText("|cffaaaaaaPlace your " .. nxt.name .. " (" .. nxt.size .. ")|r")
            if shipLabel then shipLabel:SetText(nxt.name .. " (" .. nxt.size .. ")") end
        end

    elseif phase == "battle" and not viewMyGrid and myTurn then
        if enemyView[r][c] then return end

        if pvpMode then
            myTurn = false
            statusText:SetText("|cffaaaaaaFiring...|r")
            PhoneGameChallenge:SendGameData("FIRE," .. r .. "," .. c)
        else
            -- AI mode
            myTurn = false
            local res, sn = ProcessShot(aiGrid, aiShips, r, c)
            if res == "HIT" or res == "SUNK" then
                enemyView[r][c] = "hit"
                if res == "SUNK" then enemySunk = enemySunk + 1 end
            else
                enemyView[r][c] = "miss"
            end
            RefreshGrid()
            RefreshStatus()

            if AllSunk(aiShips) then
                phase = "gameover"
                statusText:SetText("|cff44ff44You win!|r")
                if newBtn then newBtn:Show() end
                return
            end

            local msg = res == "SUNK" and ("|cffffff00Sunk " .. (sn or "") .. "!|r")
                or res == "HIT" and "|cff44ff44Hit!|r"
                or "|cffaaaaaaMiss|r"
            statusText:SetText(msg)

            C_Timer.After(0.7, function()
                if phase ~= "battle" then return end
                statusText:SetText("|cffff6644AI firing...|r")
                C_Timer.After(0.4, function()
                    if phase == "battle" then AIDoFire() end
                end)
            end)
        end
    end
end

-- ============================================================
-- PvP data handling
-- ============================================================
HandleData = function(sender, data)
    local parts = {strsplit(",", data)}
    local cmd = parts[1]

    if cmd == "READY" then
        opponentReady = true
        if imReady then
            StartBattle()
        else
            statusText:SetText("|cffaaaaaa" .. Ambiguate(opponentName or "?", "short") .. " is ready|r")
        end

    elseif cmd == "FIRE" then
        local r, c = tonumber(parts[2]), tonumber(parts[3])
        if not r or not c then return end
        local res, sn = ProcessShot(myGrid, myShips, r, c)
        if res == "HIT" then
            myHits[r][c] = "hit"
            PhoneGameChallenge:SendGameData("HIT," .. r .. "," .. c)
        elseif res == "SUNK" then
            myHits[r][c] = "hit"
            PhoneGameChallenge:SendGameData("SUNK," .. r .. "," .. c .. "," .. sn)
        else
            myHits[r][c] = "miss"
            PhoneGameChallenge:SendGameData("MISS," .. r .. "," .. c)
        end
        RefreshGrid()
        RefreshStatus()
        if AllSunk(myShips) then
            phase = "gameover"
            statusText:SetText("|cffff4444You lose!|r")
            if newBtn then newBtn:Show() end
        else
            myTurn = true
            statusText:SetText("|cff88ccffYour turn - Fire!|r")
        end

    elseif cmd == "HIT" then
        local r, c = tonumber(parts[2]), tonumber(parts[3])
        if r and c then enemyView[r][c] = "hit" end
        RefreshGrid()
        statusText:SetText("|cff44ff44Hit!|r")
        C_Timer.After(1, function()
            if phase == "battle" then
                statusText:SetText("|cffff6644" .. Ambiguate(opponentName or "?", "short") .. "'s turn|r")
            end
        end)

    elseif cmd == "MISS" then
        local r, c = tonumber(parts[2]), tonumber(parts[3])
        if r and c then enemyView[r][c] = "miss" end
        RefreshGrid()
        statusText:SetText("|cffaaaaaaMiss|r")
        C_Timer.After(1, function()
            if phase == "battle" then
                statusText:SetText("|cffff6644" .. Ambiguate(opponentName or "?", "short") .. "'s turn|r")
            end
        end)

    elseif cmd == "SUNK" then
        local r, c = tonumber(parts[2]), tonumber(parts[3])
        local sn = parts[4]
        if r and c then enemyView[r][c] = "hit" end
        enemySunk = enemySunk + 1
        RefreshGrid()
        RefreshStatus()
        if enemySunk >= #SHIPS then
            phase = "gameover"
            statusText:SetText("|cff44ff44You win!|r")
            if newBtn then newBtn:Show() end
        else
            statusText:SetText("|cffffff00Sunk " .. (sn or "ship") .. "!|r")
            C_Timer.After(1.5, function()
                if phase == "battle" then
                    statusText:SetText("|cffff6644" .. Ambiguate(opponentName or "?", "short") .. "'s turn|r")
                end
            end)
        end

    elseif cmd == "RESET" then
        opponentReady = false
        imReady = false
        enemySunk = 0
        StartPlacement()
    end
end

-- ============================================================
-- PvP friend list (same pattern as TicTacToe)
-- ============================================================
local function ShowWaitingView(targetName)
    if selectView then selectView:Hide() end
    if waitingView then waitingView:Show() end
    if incomingView then incomingView:Hide() end
    if waitingTargetFs then waitingTargetFs:SetText("|cffffffff" .. Ambiguate(targetName or "?", "short") .. "|r") end
    if waitingStatusFs then waitingStatusFs:SetText("|cffaaaaaaChallenging...|r") end
end

local function ShowIncomingView(fromName, gameName)
    if selectView then selectView:Hide() end
    if waitingView then waitingView:Hide() end
    if incomingView then incomingView:Show() end
    if incomingFromFs then incomingFromFs:SetText("|cffffffff" .. fromName .. "|r") end
    if incomingGameFs then incomingGameFs:SetText("|cff44ff44wants to play " .. gameName .. "|r") end
end

ShowSelectView = function()
    if selectView then selectView:Show() end
    if waitingView then waitingView:Hide() end
    if incomingView then incomingView:Hide() end
end

local function RefreshChallengeList()
    if not challengeContent then return end

    local rowCount = PhoneFriends:RenderList({
        pool = challengeRows,
        contentFrame = challengeContent,
        scrollFrame = challengeScroll,
        searchText = challengeSearchText,
        onlineOnly = true,
        rowOpts = { actionLabel = "Play" },
        onClick = function(_, target)
            if PhoneGameChallenge:GetState() ~= "idle" then return end
            local ok = PhoneGameChallenge:Challenge(target, GAME_ID)
            if ok then ShowWaitingView(target) end
        end,
    })

    if rowCount == 0 then
        statusText:SetText("|cff666666No online friends.\nBoth need HearthPhone.|r")
    end
end

-- ============================================================
-- Register with PhoneGameChallenge
-- ============================================================
local function RegisterWithChallenge()
    PhoneGameChallenge:RegisterGame({
        id = GAME_ID,
        name = "Battleship",
        onStart = function(opponent, goFirst)
            pvpMode = true
            opponentName = opponent
            iGoFirst = goFirst
            StartPlacement()
        end,
        onData = function(sender, data)
            HandleData(sender, data)
        end,
        onEnd = function(reason)
            if reason == "forfeit" then
                phase = "gameover"
                if statusText then statusText:SetText("|cffffff00Opponent forfeited!|r") end
                if newBtn then newBtn:Show() end
            elseif reason == "decline" then
                if waitingStatusFs then waitingStatusFs:SetText("|cffff4444Declined|r") end
                C_Timer.After(1.5, function() ShowSelectView() end)
            elseif reason == "busy" then
                if waitingStatusFs then waitingStatusFs:SetText("|cffff8800Busy|r") end
                C_Timer.After(1.5, function() ShowSelectView() end)
            elseif reason == "timeout" then
                if waitingStatusFs then waitingStatusFs:SetText("|cffff4444No response|r") end
                C_Timer.After(1.5, function() ShowSelectView() end)
            end
        end,
        onIncoming = function(from, gameName)
            ShowIncomingView(from, gameName)
            if PhoneBattleshipGame.ForceShow then PhoneBattleshipGame.ForceShow(from, gameName) end
        end,
        onResponse = function(accepted, reason) end,
        onSessionEnd = function(reason) ShowSelectView() end,
    })
end

-- ============================================================
-- Helper: styled button
-- ============================================================
local function MakeButton(parentFrame, w, h, r, g, b, label, fontSize)
    local btn = CreateFrame("Button", nil, parentFrame)
    btn:SetSize(w, h)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(r, g, b, 1)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8x8")
    hl:SetVertexColor(1, 1, 1, 0.15)
    local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText("|cffffffff" .. label .. "|r")
    local f = fs:GetFont()
    if f then fs:SetFont(f, fontSize or 9, "") end
    btn.label = fs
    return btn
end

-- ============================================================
-- Init
-- ============================================================
function PhoneBattleshipGame:Init(parent)
    if gameFrame then return end
    gameFrame = parent

    RegisterWithChallenge()

    local SCREEN_W = parent:GetWidth() or 170
    local CELL_SZ = math.floor((SCREEN_W - 10 - (GS - 1) * GAP) / GS)
    local GRID_PX = CELL_SZ * GS + GAP * (GS - 1)

    -- ========== MODE SELECTION VIEW ==========
    modeView = CreateFrame("Frame", nil, parent)
    modeView:SetAllPoints()

    -- === SELECT SUB-VIEW ===
    selectView = CreateFrame("Frame", nil, modeView)
    selectView:SetAllPoints()

    local modeTitle = selectView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    modeTitle:SetPoint("TOP", 0, -2)
    modeTitle:SetText("|cff4488ccBattleship|r")
    local mtf = modeTitle:GetFont()
    if mtf then modeTitle:SetFont(mtf, 10, "OUTLINE") end

    local aiBtn = MakeButton(selectView, 120, 28, 0.12, 0.22, 0.40, "Play vs AI", 10)
    aiBtn:SetPoint("TOP", 0, -24)
    aiBtn:SetScript("OnClick", function()
        pvpMode = false
        opponentName = nil
        demoActive = false
        iGoFirst = true
        -- Place AI ships
        aiGrid = MkGrid()
        aiShips = {}
        AutoPlace(aiGrid, aiShips)
        AIReset()
        StartPlacement()
    end)

    local pvpHeader = selectView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pvpHeader:SetPoint("TOP", aiBtn, "BOTTOM", 0, -12)
    pvpHeader:SetText("|cff44cc44Play vs Friend|r")
    local phf = pvpHeader:GetFont()
    if phf then pvpHeader:SetFont(phf, 9, "OUTLINE") end

    local searchBar = PhoneFriends:CreateSearchBar(selectView, nil, nil, 0, 0, function(text)
        challengeSearchText = text or ""
        RefreshChallengeList()
    end)
    searchBar:ClearAllPoints()
    searchBar:SetPoint("LEFT", selectView, "LEFT", 4, 0)
    searchBar:SetPoint("RIGHT", selectView, "RIGHT", -4, 0)
    searchBar:SetPoint("TOP", pvpHeader, "BOTTOM", 0, -4)

    challengeScroll = CreateFrame("ScrollFrame", nil, selectView)
    challengeScroll:SetPoint("TOP", searchBar, "BOTTOM", 0, -2)
    challengeScroll:SetPoint("LEFT", 2, 0)
    challengeScroll:SetPoint("RIGHT", -2, 0)
    challengeScroll:SetPoint("BOTTOM", 0, 4)

    challengeContent = CreateFrame("Frame", nil, challengeScroll)
    challengeContent:SetSize(1, 1)
    challengeScroll:SetScrollChild(challengeContent)

    challengeScroll:EnableMouseWheel(true)
    challengeScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, challengeContent:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxS, math.max(0, cur - delta * 25)))
    end)

    -- === WAITING SUB-VIEW ===
    waitingView = CreateFrame("Frame", nil, modeView)
    waitingView:SetAllPoints()
    waitingView:Hide()

    local wBg = waitingView:CreateTexture(nil, "BACKGROUND")
    wBg:SetAllPoints()
    wBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    wBg:SetVertexColor(0.06, 0.06, 0.08, 0.95)

    local wIcon = waitingView:CreateTexture(nil, "ARTWORK")
    wIcon:SetSize(50, 50)
    wIcon:SetPoint("TOP", 0, -40)
    wIcon:SetTexture("Interface\\Icons\\INV_Misc_Bomb_04")
    wIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    waitingTargetFs = waitingView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    waitingTargetFs:SetPoint("TOP", wIcon, "BOTTOM", 0, -8)
    local wtf = waitingTargetFs:GetFont()
    if wtf then waitingTargetFs:SetFont(wtf, 12, "OUTLINE") end

    waitingStatusFs = waitingView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    waitingStatusFs:SetPoint("TOP", waitingTargetFs, "BOTTOM", 0, -4)
    local wsf = waitingStatusFs:GetFont()
    if wsf then waitingStatusFs:SetFont(wsf, 9, "") end

    local wTitle = waitingView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    wTitle:SetPoint("TOP", 0, -6)
    wTitle:SetText("|cff4488ccBattleship|r")
    local wtf2 = wTitle:GetFont()
    if wtf2 then wTitle:SetFont(wtf2, 10, "OUTLINE") end

    local cancelBtn = MakeButton(waitingView, 60, 24, 0.55, 0.10, 0.10, "Cancel", 10)
    cancelBtn:SetPoint("BOTTOM", 0, 30)
    cancelBtn:SetScript("OnClick", function()
        PhoneGameChallenge:CancelChallenge()
        ShowSelectView()
    end)

    -- === INCOMING SUB-VIEW ===
    incomingView = CreateFrame("Frame", nil, modeView)
    incomingView:SetAllPoints()
    incomingView:Hide()

    local iBg = incomingView:CreateTexture(nil, "BACKGROUND")
    iBg:SetAllPoints()
    iBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    iBg:SetVertexColor(0.06, 0.06, 0.08, 0.95)

    local iIcon = incomingView:CreateTexture(nil, "ARTWORK")
    iIcon:SetSize(50, 50)
    iIcon:SetPoint("TOP", 0, -40)
    iIcon:SetTexture("Interface\\Icons\\INV_Misc_Bomb_04")
    iIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    incomingFromFs = incomingView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    incomingFromFs:SetPoint("TOP", iIcon, "BOTTOM", 0, -8)
    local iff = incomingFromFs:GetFont()
    if iff then incomingFromFs:SetFont(iff, 12, "OUTLINE") end

    incomingGameFs = incomingView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    incomingGameFs:SetPoint("TOP", incomingFromFs, "BOTTOM", 0, -4)
    local igf = incomingGameFs:GetFont()
    if igf then incomingGameFs:SetFont(igf, 9, "") end

    local iTitle = incomingView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    iTitle:SetPoint("TOP", 0, -6)
    iTitle:SetText("|cff4488ccGame Challenge!|r")
    local itf = iTitle:GetFont()
    if itf then iTitle:SetFont(itf, 10, "OUTLINE") end

    local acceptBtn = MakeButton(incomingView, 55, 24, 0.10, 0.50, 0.10, "Accept", 10)
    acceptBtn:SetPoint("BOTTOMRIGHT", incomingView, "BOTTOM", -4, 30)
    acceptBtn:SetScript("OnClick", function()
        PhoneGameChallenge:AcceptChallenge()
    end)

    local declineBtn = MakeButton(incomingView, 55, 24, 0.55, 0.10, 0.10, "Decline", 10)
    declineBtn:SetPoint("BOTTOMLEFT", incomingView, "BOTTOM", 4, 30)
    declineBtn:SetScript("OnClick", function()
        PhoneGameChallenge:DeclineChallenge()
        ShowSelectView()
    end)

    -- ========== PLAY VIEW (placement + battle) ==========
    playView = CreateFrame("Frame", nil, parent)
    playView:SetAllPoints()
    playView:Hide()

    -- Title
    local title = playView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cff4488ccBattleship|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Status text
    statusText = playView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusText:SetPoint("TOP", 0, -16)
    local sf = statusText:GetFont()
    if sf then statusText:SetFont(sf, 8, "") end

    -- === Placement panel (below status, above grid) ===
    placePanel = CreateFrame("Frame", nil, playView)
    placePanel:SetPoint("TOPLEFT", playView, "TOPLEFT", 4, -28)
    placePanel:SetPoint("TOPRIGHT", playView, "TOPRIGHT", -4, -28)
    placePanel:SetHeight(22)

    shipLabel = placePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    shipLabel:SetPoint("LEFT", 2, 0)
    local slF = shipLabel:GetFont()
    if slF then shipLabel:SetFont(slF, 8, "") end

    rotBtn = MakeButton(placePanel, 44, 18, 0.25, 0.25, 0.35, "Rotate", 7)
    rotBtn:SetPoint("RIGHT", placePanel, "RIGHT", -52, 0)
    rotBtn:SetScript("OnClick", function()
        placeHoriz = not placeHoriz
        rotBtn.label:SetText("|cffffffff" .. (placeHoriz and "Horiz" or "Vert") .. "|r")
    end)

    autoBtn = MakeButton(placePanel, 40, 18, 0.20, 0.35, 0.20, "Auto", 7)
    autoBtn:SetPoint("RIGHT", placePanel, "RIGHT", -2, 0)
    autoBtn:SetScript("OnClick", function()
        myShips = {}
        if AutoPlace(myGrid, myShips) then
            placeIdx = #SHIPS + 1
            ClearPreview()
            RefreshGrid()
            statusText:SetText("|cff44ff44All ships placed!|r")
            if shipLabel then shipLabel:SetText("") end
            -- Show Ready, hide placement buttons
            if readyBtn then readyBtn:Show() end
            rotBtn:Hide()
            autoBtn:Hide()
        end
    end)

    readyBtn = MakeButton(placePanel, 80, 18, 0.15, 0.50, 0.15, "Ready!", 9)
    readyBtn:SetPoint("CENTER", placePanel, "CENTER", 0, 0)
    readyBtn:Hide()
    readyBtn:SetScript("OnClick", function()
        imReady = true
        readyBtn:Hide()
        if pvpMode then
            PhoneGameChallenge:SendGameData("READY")
            if opponentReady then
                StartBattle()
            else
                statusText:SetText("|cffaaaaaaWaiting for opponent...|r")
            end
        else
            -- AI mode: start immediately
            StartBattle()
        end
    end)

    -- === Battle panel (toggle + ship counts) ===
    battlePanel = CreateFrame("Frame", nil, playView)
    battlePanel:SetPoint("TOPLEFT", playView, "TOPLEFT", 4, -28)
    battlePanel:SetPoint("TOPRIGHT", playView, "TOPRIGHT", -4, -28)
    battlePanel:SetHeight(18)
    battlePanel:Hide()

    toggleBtn = MakeButton(battlePanel, 60, 16, 0.18, 0.18, 0.25, "My Fleet", 7)
    toggleBtn:SetPoint("LEFT", 0, 0)
    toggleBtn:SetScript("OnClick", function()
        viewMyGrid = not viewMyGrid
        toggleBtn.label:SetText("|cffffffff" .. (viewMyGrid and "Attack" or "My Fleet") .. "|r")
        RefreshGrid()
    end)

    fleetLabel = battlePanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fleetLabel:SetPoint("RIGHT", -2, 0)
    local flF = fleetLabel:GetFont()
    if flF then fleetLabel:SetFont(flF, 7, "") end

    -- === Grid ===
    local gridFrame = CreateFrame("Frame", nil, playView)
    gridFrame:SetSize(GRID_PX, GRID_PX)
    gridFrame:SetPoint("TOP", 0, -50)

    local gridBg = gridFrame:CreateTexture(nil, "BACKGROUND")
    gridBg:SetAllPoints()
    gridBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    gridBg:SetVertexColor(0.15, 0.25, 0.40, 0.6)

    for r = 1, GS do
        cells[r] = {}
        for c = 1, GS do
            local btn = CreateFrame("Button", nil, gridFrame)
            btn:SetSize(CELL_SZ, CELL_SZ)
            local xOff = (c - 1) * (CELL_SZ + GAP)
            local yOff = -((r - 1) * (CELL_SZ + GAP))
            btn:SetPoint("TOPLEFT", xOff, yOff)

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(unpack(CW))

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Buttons\\WHITE8x8")
            hl:SetVertexColor(0.3, 0.4, 0.5, 0.25)

            local mark = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            mark:SetPoint("CENTER")
            mark:SetText("")
            local mf = mark:GetFont()
            if mf then mark:SetFont(mf, math.max(math.floor(CELL_SZ * 0.45), 6), "OUTLINE") end

            -- Overlay texture for explosion/splash effects
            local overlay = btn:CreateTexture(nil, "OVERLAY")
            overlay:SetAllPoints()
            overlay:Hide()

            local rr, cc = r, c
            btn:SetScript("OnClick", function() OnCellClick(rr, cc) end)
            btn:SetScript("OnEnter", function() OnCellEnter(rr, cc) end)
            btn:SetScript("OnLeave", function() OnCellLeave() end)

            cells[r][c] = {btn = btn, bg = bg, mark = mark, overlay = overlay}
        end
    end

    -- === Bottom buttons ===
    newBtn = MakeButton(playView, 50, 18, 0.2, 0.35, 0.5, "New", 8)
    newBtn:SetPoint("BOTTOMRIGHT", playView, "BOTTOM", -2, 6)
    newBtn:Hide()
    newBtn:SetScript("OnClick", function()
        if pvpMode then
            PhoneGameChallenge:SendGameData("RESET")
        end
        enemySunk = 0
        if not pvpMode then
            -- AI: re-randomize AI ships
            aiGrid = MkGrid()
            aiShips = {}
            AutoPlace(aiGrid, aiShips)
            AIReset()
        end
        StartPlacement()
    end)

    local backBtn = MakeButton(playView, 50, 18, 0.4, 0.2, 0.2, "Back", 8)
    backBtn:SetPoint("BOTTOMLEFT", playView, "BOTTOM", 2, 6)
    backBtn:SetScript("OnClick", function()
        ShowMenu()
    end)

    ShowMenu()
end

-- ============================================================
-- Show/Hide callbacks
-- ============================================================
function PhoneBattleshipGame:OnShow()
    visible = true
    if modeView and modeView:IsShown() then
        if PhonePresence then PhonePresence:PingFriends() end
        RefreshChallengeList()
        C_Timer.After(1.5, function()
            if visible and modeView and modeView:IsShown() then
                RefreshChallengeList()
            end
        end)
    end
end

function PhoneBattleshipGame:OnHide()
    visible = false
end

-- ============================================================
-- Demo commands
-- ============================================================
local origSendGameData = PhoneGameChallenge.SendGameData

local function DemoHandleData(data)
    local parts = {strsplit(",", data)}
    local cmd = parts[1]

    if cmd == "READY" then
        opponentReady = true
        if imReady then StartBattle() end

    elseif cmd == "FIRE" then
        local r, c = tonumber(parts[2]), tonumber(parts[3])
        if not r or not c then return end
        local res, sn = ProcessShot(aiGrid, aiShips, r, c)
        local response
        if res == "SUNK" then
            response = "SUNK," .. r .. "," .. c .. "," .. sn
        elseif res == "HIT" then
            response = "HIT," .. r .. "," .. c
        else
            response = "MISS," .. r .. "," .. c
        end
        -- Simulate receiving the result, then AI fires back
        C_Timer.After(0.3, function()
            HandleData("DemoBot", response)
            if phase == "battle" and not AllSunk(aiShips) then
                C_Timer.After(0.8, function()
                    if phase == "battle" then AIDoFire() end
                end)
            end
        end)

    elseif cmd == "RESET" then
        opponentReady = false
        imReady = false
        enemySunk = 0
        aiGrid = MkGrid()
        aiShips = {}
        AutoPlace(aiGrid, aiShips)
        AIReset()
        StartPlacement()
    end
end

PhoneGameChallenge.SendGameData = function(self, data)
    if demoActive and pvpMode then
        DemoHandleData(data)
        return
    end
    origSendGameData(self, data)
end

SLASH_BSDEMO1 = "/bsdemo"
SlashCmdList["BSDEMO"] = function()
    if not gameFrame then
        print("|cff4488cc[Battleship]|r Open the Battleship app first, then run /bsdemo again.")
        return
    end
    demoActive = true
    pvpMode = true
    opponentName = "DemoBot"
    iGoFirst = true
    aiGrid = MkGrid()
    aiShips = {}
    AutoPlace(aiGrid, aiShips)
    AIReset()
    StartPlacement()
    print("|cff4488cc[Battleship]|r Demo PvP started! Place your ships, then hit Ready. DemoBot responds automatically.")
end

SLASH_BSFAKE1 = "/bsfake"
SlashCmdList["BSFAKE"] = function(input)
    if not gameFrame then
        print("|cff4488cc[Battleship]|r Open the Battleship app first, then run /bsfake again.")
        return
    end
    local fakeName = strtrim(input or "")
    if fakeName == "" then fakeName = "FriendBot" end

    ShowMenu()
    ShowIncomingView(fakeName, "Battleship")

    demoActive = true
    aiGrid = MkGrid()
    aiShips = {}
    AutoPlace(aiGrid, aiShips)
    AIReset()

    local origAccept = PhoneGameChallenge.AcceptChallenge
    PhoneGameChallenge.AcceptChallenge = function(self2)
        PhoneGameChallenge.AcceptChallenge = origAccept
        pvpMode = true
        opponentName = fakeName
        iGoFirst = false
        StartPlacement()
        print("|cff4488cc[Battleship]|r Accepted fake challenge from " .. fakeName .. ".")
    end
    print("|cff4488cc[Battleship]|r Fake incoming challenge from " .. fakeName .. "! Accept or Decline.")
end
