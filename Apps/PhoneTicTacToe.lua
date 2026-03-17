-- PhoneTicTacToe - Tic-Tac-Toe for HearthPhone (AI + PvP via PhoneGameChallenge)

PhoneTicTacToeGame = {}

local GAME_ID = "tictactoe"

local gameFrame, statusText, resetBtn
local cellButtons = {}
local board = {}  -- 1-9, values: nil, "X", "O"
local currentTurn = "X"
local gameOver = false
local visible = false

-- PvP state
local pvpMode = false
local myMark = "X"     -- "X" or "O"
local opponentName = nil
local demoActive = false

-- Mode selection UI
local modeView, gameView

local COLOR_X = { 0.3, 0.7, 1, 1 }
local COLOR_O = { 1, 0.4, 0.3, 1 }
local COLOR_BG = { 0.12, 0.12, 0.15, 1 }

local WIN_LINES = {
    { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 },  -- rows
    { 1, 4, 7 }, { 2, 5, 8 }, { 3, 6, 9 },  -- cols
    { 1, 5, 9 }, { 3, 5, 7 },                -- diagonals
}

local winHighlight = {}

-- ============================================================
-- Board logic
-- ============================================================
local function CellColor(mark)
    local c = mark == "X" and COLOR_X or COLOR_O
    return format("|cff%02x%02x%02x%s|r", c[1]*255, c[2]*255, c[3]*255, mark)
end

local function CheckWinner()
    for _, line in ipairs(WIN_LINES) do
        local a, b, c = line[1], line[2], line[3]
        if board[a] and board[a] == board[b] and board[b] == board[c] then
            return board[a], line
        end
    end
    local full = true
    for i = 1, 9 do
        if not board[i] then full = false; break end
    end
    if full then return "draw", nil end
    return nil, nil
end

local function HighlightWin(line)
    for i, idx in ipairs(line) do
        local hl = winHighlight[i]
        if not hl then
            hl = gameFrame:CreateTexture(nil, "ARTWORK", nil, 2)
            hl:SetTexture("Interface\\Buttons\\WHITE8x8")
            winHighlight[i] = hl
        end
        hl:SetVertexColor(1, 1, 0.3, 0.25)
        hl:ClearAllPoints()
        hl:SetAllPoints(cellButtons[idx])
        hl:Show()
    end
end

local function ResetBoard()
    for i = 1, 9 do
        board[i] = nil
        if cellButtons[i] then cellButtons[i].label:SetText("") end
    end
    for _, hl in ipairs(winHighlight) do hl:Hide() end
    currentTurn = "X"
    gameOver = false
end

-- ============================================================
-- Minimax AI
-- ============================================================
local function Minimax(b, isMaximizing)
    for _, line in ipairs(WIN_LINES) do
        local a, c2, c3 = line[1], line[2], line[3]
        if b[a] and b[a] == b[c2] and b[c2] == b[c3] then
            if b[a] == "O" then return 10 end
            return -10
        end
    end
    local hasEmpty = false
    for i = 1, 9 do
        if not b[i] then hasEmpty = true; break end
    end
    if not hasEmpty then return 0 end

    if isMaximizing then
        local best = -100
        for i = 1, 9 do
            if not b[i] then
                b[i] = "O"
                local score = Minimax(b, false)
                b[i] = nil
                if score > best then best = score end
            end
        end
        return best
    else
        local best = 100
        for i = 1, 9 do
            if not b[i] then
                b[i] = "X"
                local score = Minimax(b, true)
                b[i] = nil
                if score < best then best = score end
            end
        end
        return best
    end
end

local function AIMove()
    local bestScore = -100
    local bestIdx = nil
    for i = 1, 9 do
        if not board[i] then
            board[i] = "O"
            local score = Minimax(board, false)
            board[i] = nil
            if score > bestScore then
                bestScore = score
                bestIdx = i
            end
        end
    end
    return bestIdx
end

-- ============================================================
-- Place a mark on the board (shared by AI and PvP)
-- ============================================================
local function PlaceMark(idx, mark)
    if board[idx] or gameOver then return end
    board[idx] = mark
    cellButtons[idx].label:SetText(CellColor(mark))

    local winner, line = CheckWinner()
    if winner then
        gameOver = true
        if winner == "draw" then
            statusText:SetText("|cffffff00Draw!|r")
        elseif pvpMode then
            if winner == myMark then
                statusText:SetText("|cff88ccffYou win!|r")
            else
                statusText:SetText("|cffff6644" .. Ambiguate(opponentName or "???", "short") .. " wins!|r")
            end
            HighlightWin(line)
        else
            if winner == "X" then
                statusText:SetText("|cff88ccffYou win!|r")
            else
                statusText:SetText("|cffff6644AI wins!|r")
            end
            HighlightWin(line)
        end
    end
end

-- ============================================================
-- Cell click handler
-- ============================================================
local function OnCellClick(idx)
    if gameOver or board[idx] then return end

    if pvpMode then
        -- PvP: only allow clicks on my turn
        if currentTurn ~= myMark then return end
        PlaceMark(idx, myMark)
        currentTurn = (myMark == "X") and "O" or "X"
        if not gameOver then
            statusText:SetText("|cffff6644" .. Ambiguate(opponentName or "???", "short") .. "'s turn|r")
        end
        -- Send move to opponent
        PhoneGameChallenge:SendGameData(tostring(idx))
    else
        -- AI mode
        if currentTurn ~= "X" then return end
        PlaceMark(idx, "X")
        if gameOver then return end

        currentTurn = "O"
        statusText:SetText("|cffff6644AI thinking...|r")

        C_Timer.After(0.3, function()
            if gameOver then return end
            local aiIdx = AIMove()
            if aiIdx then PlaceMark(aiIdx, "O") end
            if not gameOver then
                currentTurn = "X"
                statusText:SetText("|cff88ccffYour turn (X)|r")
            end
        end)
    end
end

-- ============================================================
-- Mode switching
-- ============================================================
local ShowSelectView  -- forward declaration

local function ShowModeView()
    if modeView then modeView:Show() end
    if gameView then gameView:Hide() end
    -- End any active PvP session
    if pvpMode and not demoActive and PhoneGameChallenge:GetState() == "active" then
        PhoneGameChallenge:Forfeit()
    end
    pvpMode = false
    opponentName = nil
    demoActive = false
    ShowSelectView()
end

local function ShowGameView()
    if modeView then modeView:Hide() end
    if gameView then gameView:Show() end
end

local function StartAIGame()
    pvpMode = false
    myMark = "X"
    opponentName = nil
    ResetBoard()
    statusText:SetText("|cff88ccffYour turn (X)|r")
    ShowGameView()
end

local function StartPvPGame(opponent, iGoFirst)
    pvpMode = true
    opponentName = opponent
    myMark = iGoFirst and "X" or "O"
    ResetBoard()
    if iGoFirst then
        statusText:SetText("|cff88ccffYour turn (" .. myMark .. ")|r")
    else
        statusText:SetText("|cffff6644" .. Ambiguate(opponent, "short") .. "'s turn|r")
    end
    ShowGameView()
end

-- ============================================================
-- PvP challenge UI (friends list for challenging)
-- ============================================================
local challengeRows = {}
local challengeScroll, challengeContent
local challengeStatusFs
local challengeSearchText = ""
local pvpState = "idle"  -- idle, waiting, incoming

-- Sub-views within modeView
local selectView, waitingView, incomingView
local waitingTargetFs, waitingStatusFs
local incomingFromFs, incomingGameFs

ShowSelectView = function()
    if selectView then selectView:Show() end
    if waitingView then waitingView:Hide() end
    if incomingView then incomingView:Hide() end
    pvpState = "idle"
end

local function ShowWaitingView(targetName)
    if selectView then selectView:Hide() end
    if waitingView then waitingView:Show() end
    if incomingView then incomingView:Hide() end
    pvpState = "waiting"
    if waitingTargetFs then waitingTargetFs:SetText("|cffffffff" .. Ambiguate(targetName or "???", "short") .. "|r") end
    if waitingStatusFs then waitingStatusFs:SetText("|cffaaaaaa Challenging...|r") end
end

local function ShowIncomingView(fromName, gameName)
    if selectView then selectView:Hide() end
    if waitingView then waitingView:Hide() end
    if incomingView then incomingView:Show() end
    pvpState = "incoming"
    if incomingFromFs then incomingFromFs:SetText("|cffffffff" .. fromName .. "|r") end
    if incomingGameFs then incomingGameFs:SetText("|cff44ff44wants to play " .. gameName .. "|r") end
end

local function UpdateChallengeStatus(text)
    if challengeStatusFs then challengeStatusFs:SetText(text) end
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
        onClick = function(f, target)
            if PhoneGameChallenge:GetState() ~= "idle" then return end
            local ok = PhoneGameChallenge:Challenge(target, GAME_ID)
            if ok then
                ShowWaitingView(target)
            end
        end,
    })

    if rowCount == 0 then
        UpdateChallengeStatus("|cff666666No online friends found.\nBoth players need HearthPhone.|r")
    else
        if pvpState == "idle" then
            UpdateChallengeStatus("|cffaaaaaaSelect a friend to challenge|r")
        end
    end
end

-- ============================================================
-- Register with PhoneGameChallenge
-- ============================================================
local function RegisterWithChallenge()
    PhoneGameChallenge:RegisterGame({
        id = GAME_ID,
        name = "Tic-Tac-Toe",
        onStart = function(opponent, iGoFirst)
            StartPvPGame(opponent, iGoFirst)
        end,
        onData = function(sender, data)
            if data == "RESET" then
                -- Opponent wants a rematch - swap marks and reset
                myMark = (myMark == "X") and "O" or "X"
                ResetBoard()
                currentTurn = "X"
                if myMark == "X" then
                    statusText:SetText("|cff88ccffYour turn (" .. myMark .. ")|r")
                else
                    statusText:SetText("|cffff6644" .. Ambiguate(opponentName or "???", "short") .. "'s turn|r")
                end
                return
            end
            -- Opponent placed a mark
            local idx = tonumber(data)
            if not idx or idx < 1 or idx > 9 then return end
            local opMark = (myMark == "X") and "O" or "X"
            PlaceMark(idx, opMark)
            if not gameOver then
                currentTurn = myMark
                statusText:SetText("|cff88ccffYour turn (" .. myMark .. ")|r")
            end
        end,
        onEnd = function(reason)
            if reason == "forfeit" then
                gameOver = true
                if statusText then statusText:SetText("|cffffff00Opponent forfeited!|r") end
            elseif reason == "decline" then
                if waitingStatusFs then waitingStatusFs:SetText("|cffff4444Declined|r") end
                C_Timer.After(1.5, function()
                    if pvpState == "waiting" then ShowSelectView() end
                end)
            elseif reason == "busy" then
                if waitingStatusFs then waitingStatusFs:SetText("|cffff8800Busy|r") end
                C_Timer.After(1.5, function()
                    if pvpState == "waiting" then ShowSelectView() end
                end)
            elseif reason == "timeout" then
                if waitingStatusFs then waitingStatusFs:SetText("|cffff4444No response|r") end
                C_Timer.After(1.5, function()
                    if pvpState == "waiting" then ShowSelectView() end
                end)
            end
        end,
        -- Per-game UI callbacks (so multiple games can coexist)
        onIncoming = function(from, gameName)
            ShowIncomingView(from, gameName)
            if PhoneTicTacToeGame.ForceShow then PhoneTicTacToeGame.ForceShow(from, gameName) end
        end,
        onResponse = function(accepted, reason)
            -- game onStart handles the transition to game view
        end,
        onSessionEnd = function(reason)
            ShowSelectView()
        end,
    })
end

-- ============================================================
-- Init
-- ============================================================
function PhoneTicTacToeGame:Init(parent)
    if gameFrame then return end
    gameFrame = parent

    RegisterWithChallenge()

    local SCREEN_W = parent:GetWidth() or 170
    local SCREEN_H = parent:GetHeight() or 300

    -- ========== MODE SELECTION VIEW ==========
    modeView = CreateFrame("Frame", nil, parent)
    modeView:SetAllPoints()

    -- Helper to make a styled button
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

    -- ===== SELECT SUB-VIEW (AI button + friend list) =====
    selectView = CreateFrame("Frame", nil, modeView)
    selectView:SetAllPoints()

    local modeTitle = selectView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    modeTitle:SetPoint("TOP", 0, -2)
    modeTitle:SetText("|cff40c0ffTic-Tac-Toe|r")
    local mtf = modeTitle:GetFont()
    if mtf then modeTitle:SetFont(mtf, 10, "OUTLINE") end

    local aiBtn = MakeButton(selectView, 120, 28, 0.15, 0.25, 0.45, "Play vs AI", 10)
    aiBtn:SetPoint("TOP", 0, -24)
    aiBtn:SetScript("OnClick", StartAIGame)

    local pvpHeader = selectView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pvpHeader:SetPoint("TOP", aiBtn, "BOTTOM", 0, -12)
    pvpHeader:SetText("|cff44cc44Play vs Friend|r")
    local phf = pvpHeader:GetFont()
    if phf then pvpHeader:SetFont(phf, 9, "OUTLINE") end

    -- Search bar (full width, below pvpHeader)
    local searchBar = PhoneFriends:CreateSearchBar(selectView, nil, nil, 0, 0, function(text)
        challengeSearchText = text or ""
        RefreshChallengeList()
    end)
    searchBar:ClearAllPoints()
    searchBar:SetPoint("LEFT", selectView, "LEFT", 4, 0)
    searchBar:SetPoint("RIGHT", selectView, "RIGHT", -4, 0)
    searchBar:SetPoint("TOP", pvpHeader, "BOTTOM", 0, -4)

    -- Friends scroll list
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

    -- ===== WAITING SUB-VIEW (outgoing challenge, like call screen) =====
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
    wIcon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend")
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
    wTitle:SetText("|cff40c0ffTic-Tac-Toe|r")
    local wtf2 = wTitle:GetFont()
    if wtf2 then wTitle:SetFont(wtf2, 10, "OUTLINE") end

    local cancelBtn = MakeButton(waitingView, 60, 24, 0.55, 0.10, 0.10, "Cancel", 10)
    cancelBtn:SetPoint("BOTTOM", 0, 30)
    cancelBtn:SetScript("OnClick", function()
        PhoneGameChallenge:CancelChallenge()
        ShowSelectView()
    end)

    -- ===== INCOMING SUB-VIEW (someone challenges us, like incoming call) =====
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
    iIcon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend")
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
    iTitle:SetText("|cff40c0ffGame Challenge!|r")
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

    -- ========== GAME VIEW ==========
    gameView = CreateFrame("Frame", nil, parent)
    gameView:SetAllPoints()
    gameView:Hide()

    -- Title
    local title = gameView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cff40c0ffTic-Tac-Toe|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Status text
    statusText = gameView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusText:SetPoint("TOP", 0, -16)
    local sf = statusText:GetFont()
    if sf then statusText:SetFont(sf, 9, "") end

    -- Grid
    local CELL_SIZE = math.floor(math.min(SCREEN_W - 16, SCREEN_H - 80) / 3)
    local GRID_SIZE = CELL_SIZE * 3
    local GAP = 3

    local gridFrame = CreateFrame("Frame", nil, gameView)
    gridFrame:SetSize(GRID_SIZE + GAP * 2, GRID_SIZE + GAP * 2)
    gridFrame:SetPoint("CENTER", 0, -5)

    local gridBg = gridFrame:CreateTexture(nil, "BACKGROUND")
    gridBg:SetAllPoints()
    gridBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    gridBg:SetVertexColor(0.25, 0.25, 0.3, 0.8)

    for i = 1, 9 do
        local row = math.floor((i - 1) / 3)
        local col = (i - 1) % 3

        local btn = CreateFrame("Button", nil, gridFrame)
        btn:SetSize(CELL_SIZE - GAP, CELL_SIZE - GAP)
        local xOff = col * CELL_SIZE + GAP
        local yOff = -(row * CELL_SIZE + GAP)
        btn:SetPoint("TOPLEFT", xOff, yOff)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(unpack(COLOR_BG))

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(0.3, 0.3, 0.4, 0.3)

        local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        label:SetPoint("CENTER")
        local lf = label:GetFont()
        if lf then label:SetFont(lf, math.floor(CELL_SIZE * 0.5), "OUTLINE") end
        label:SetText("")

        btn.label = label
        btn:SetScript("OnClick", function() OnCellClick(i) end)

        cellButtons[i] = btn
    end

    -- Bottom buttons
    resetBtn = CreateFrame("Button", nil, gameView)
    resetBtn:SetSize(50, 18)
    resetBtn:SetPoint("BOTTOMRIGHT", gameView, "BOTTOM", -2, 6)

    local rbg = resetBtn:CreateTexture(nil, "BACKGROUND")
    rbg:SetAllPoints()
    rbg:SetTexture("Interface\\Buttons\\WHITE8x8")
    rbg:SetVertexColor(0.2, 0.35, 0.5, 0.9)

    local rhl = resetBtn:CreateTexture(nil, "HIGHLIGHT")
    rhl:SetAllPoints()
    rhl:SetTexture("Interface\\Buttons\\WHITE8x8")
    rhl:SetVertexColor(0.4, 0.5, 0.6, 0.3)

    local rlabel = resetBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    rlabel:SetPoint("CENTER")
    rlabel:SetText("New")
    rlabel:SetTextColor(0.9, 0.95, 1, 1)
    local rf = rlabel:GetFont()
    if rf then rlabel:SetFont(rf, 8, "OUTLINE") end

    resetBtn:SetScript("OnClick", function()
        if pvpMode then
            -- In PvP, "New" resets the board for a rematch
            -- Swap who goes first each round
            myMark = (myMark == "X") and "O" or "X"
            ResetBoard()
            currentTurn = "X"
            if myMark == "X" then
                statusText:SetText("|cff88ccffYour turn (" .. myMark .. ")|r")
            else
                statusText:SetText("|cffff6644" .. Ambiguate(opponentName or "???", "short") .. "'s turn|r")
            end
            PhoneGameChallenge:SendGameData("RESET")
        else
            ResetBoard()
            statusText:SetText("|cff88ccffYour turn (X)|r")
        end
    end)

    -- Back button
    local backBtn = CreateFrame("Button", nil, gameView)
    backBtn:SetSize(50, 18)
    backBtn:SetPoint("BOTTOMLEFT", gameView, "BOTTOM", 2, 6)

    local bbg = backBtn:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints()
    bbg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bbg:SetVertexColor(0.4, 0.2, 0.2, 0.9)

    local bhl = backBtn:CreateTexture(nil, "HIGHLIGHT")
    bhl:SetAllPoints()
    bhl:SetTexture("Interface\\Buttons\\WHITE8x8")
    bhl:SetVertexColor(0.5, 0.3, 0.3, 0.3)

    local blabel = backBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    blabel:SetPoint("CENTER")
    blabel:SetText("Back")
    blabel:SetTextColor(0.9, 0.95, 1, 1)
    local bf = blabel:GetFont()
    if bf then blabel:SetFont(bf, 8, "OUTLINE") end

    backBtn:SetScript("OnClick", function()
        ShowModeView()
    end)

    ShowModeView()
end

function PhoneTicTacToeGame:OnShow()
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

function PhoneTicTacToeGame:OnHide()
    visible = false
end

-- ============================================================
-- Demo / testing commands
-- ============================================================

local function DemoAIRespond()
    if not demoActive or gameOver then return end
    local empty = {}
    for i = 1, 9 do
        if not board[i] then empty[#empty + 1] = i end
    end
    if #empty == 0 then return end

    -- Use minimax for a smart demo opponent
    local aiMark = (myMark == "X") and "O" or "X"
    local bestScore = -100
    local bestIdx = nil
    for _, i in ipairs(empty) do
        board[i] = aiMark
        local score = Minimax(board, false)
        if aiMark == "X" then score = -score end
        board[i] = nil
        if score > bestScore then
            bestScore = score
            bestIdx = i
        end
    end
    if not bestIdx then bestIdx = empty[math.random(#empty)] end

    PlaceMark(bestIdx, aiMark)
    if not gameOver then
        currentTurn = myMark
        statusText:SetText("|cff88ccffYour turn (" .. myMark .. ")|r")
    end
end

-- Hook SendGameData: in demo mode, respond with AI instead of sending addon messages
local origSendGameData = PhoneGameChallenge.SendGameData
PhoneGameChallenge.SendGameData = function(self, data)
    if demoActive and pvpMode then
        if data == "RESET" then
            -- Demo rematch: swap the demo opponent's mark too
            -- If the demo opponent now goes first (myMark == "O"), they need to move
            C_Timer.After(0.5, function()
                if demoActive and not gameOver and currentTurn ~= myMark then
                    DemoAIRespond()
                end
            end)
        else
            C_Timer.After(0.4, function()
                if demoActive and not gameOver then
                    DemoAIRespond()
                end
            end)
        end
        return
    end
    origSendGameData(self, data)
end

-- /tttdemo - Start a fake PvP game against DemoBot (you challenge them)
SLASH_TTTDEMO1 = "/tttdemo"
SlashCmdList["TTTDEMO"] = function()
    if not gameFrame then
        print("|cff40c0ff[TicTacToe]|r Open the TicTacToe app on your phone first, then run /tttdemo again.")
        return
    end
    demoActive = true
    StartPvPGame("DemoBot", true)
    print("|cff40c0ff[TicTacToe]|r Demo PvP started! You are X. DemoBot responds automatically.")
end

-- /tttfake [Name] - Simulate an incoming game challenge
SLASH_TTTFAKE1 = "/tttfake"
SlashCmdList["TTTFAKE"] = function(input)
    if not gameFrame then
        print("|cff40c0ff[TicTacToe]|r Open the TicTacToe app on your phone first, then run /tttfake again.")
        return
    end
    local fakeName = strtrim(input or "")
    if fakeName == "" then fakeName = "FriendBot" end

    -- Show the incoming challenge screen
    ShowModeView()  -- reset to mode view first
    ShowIncomingView(fakeName, "Tic-Tac-Toe")

    -- Store fake challenger info so Accept works
    demoActive = true
    -- Override AcceptChallenge temporarily for the fake flow
    local origAccept = PhoneGameChallenge.AcceptChallenge
    PhoneGameChallenge.AcceptChallenge = function(self)
        PhoneGameChallenge.AcceptChallenge = origAccept  -- restore immediately
        StartPvPGame(fakeName, false)  -- fake challenger goes first, we are O
        print("|cff40c0ff[TicTacToe]|r Accepted fake challenge from " .. fakeName .. ". You are O.")
        -- Fake opponent makes the first move after a short delay
        C_Timer.After(0.6, function()
            if demoActive and not gameOver then
                DemoAIRespond()
            end
        end)
    end
    print("|cff40c0ff[TicTacToe]|r Fake incoming challenge from " .. fakeName .. "! Accept or Decline on the phone.")
end
