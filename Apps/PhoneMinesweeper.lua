-- PhoneMinesweeper - Classic minesweeper for HearthPhone

PhoneMinesweeperGame = {}

local parent
local COLS, ROWS = 8, 10
local CELL = 18
local MINES = 10
local grid = {}       -- 0-8 = adjacent count, -1 = mine
local revealed = {}
local flagged = {}
local cells = {}
local gameOver = false
local gameWon = false
local firstClick = true
local mineCount = MINES
local minesFs, msgFs, timerFs
local startTime = 0
local timerTicker

local UNREVEALED_COLOR = {0.18, 0.18, 0.22}
local REVEALED_COLOR = {0.10, 0.10, 0.13}
local MINE_COLOR = {0.5, 0.1, 0.1}
local FLAG_COLOR = {0.3, 0.25, 0.1}

local NUM_COLORS = {
    [1] = "4488ff",
    [2] = "44aa44",
    [3] = "ff4444",
    [4] = "8844cc",
    [5] = "cc8800",
    [6] = "44cccc",
    [7] = "444444",
    [8] = "aaaaaa",
}

local function InitGrid()
    for c = 1, COLS do
        grid[c] = {}
        revealed[c] = {}
        flagged[c] = {}
        for r = 1, ROWS do
            grid[c][r] = 0
            revealed[c][r] = false
            flagged[c][r] = false
        end
    end
end

local function PlaceMines(safeC, safeR)
    local placed = 0
    while placed < MINES do
        local c = math.random(1, COLS)
        local r = math.random(1, ROWS)
        if grid[c][r] ~= -1 and not (math.abs(c - safeC) <= 1 and math.abs(r - safeR) <= 1) then
            grid[c][r] = -1
            placed = placed + 1
        end
    end
    -- Calculate numbers
    for c = 1, COLS do
        for r = 1, ROWS do
            if grid[c][r] ~= -1 then
                local count = 0
                for dc = -1, 1 do
                    for dr = -1, 1 do
                        local nc, nr = c + dc, r + dr
                        if nc >= 1 and nc <= COLS and nr >= 1 and nr <= ROWS then
                            if grid[nc][nr] == -1 then count = count + 1 end
                        end
                    end
                end
                grid[c][r] = count
            end
        end
    end
end

local UpdateDisplay

local function CheckWin()
    for c = 1, COLS do
        for r = 1, ROWS do
            if grid[c][r] ~= -1 and not revealed[c][r] then
                return false
            end
        end
    end
    return true
end

local function Flood(c, r)
    if c < 1 or c > COLS or r < 1 or r > ROWS then return end
    if revealed[c][r] or flagged[c][r] then return end
    revealed[c][r] = true
    if grid[c][r] == 0 then
        for dc = -1, 1 do
            for dr = -1, 1 do
                if dc ~= 0 or dr ~= 0 then
                    Flood(c + dc, r + dr)
                end
            end
        end
    end
end

local function RevealAll()
    for c = 1, COLS do
        for r = 1, ROWS do
            revealed[c][r] = true
        end
    end
end

local function OnLeftClick(c, r)
    if gameOver or gameWon then return end
    if flagged[c][r] then return end

    if firstClick then
        PlaceMines(c, r)
        firstClick = false
        startTime = GetTime()
    end

    if grid[c][r] == -1 then
        -- Hit mine
        gameOver = true
        RevealAll()
        msgFs:SetText("|cffff4444Boom!|r")
        if timerTicker then timerTicker:Cancel() end
        UpdateDisplay()
        return
    end

    Flood(c, r)

    if CheckWin() then
        gameWon = true
        RevealAll()
        local elapsed = math.floor(GetTime() - startTime)
        msgFs:SetText("|cff44ff44Cleared! " .. elapsed .. "s|r")
        if timerTicker then timerTicker:Cancel() end
    end

    UpdateDisplay()
end

local function OnRightClick(c, r)
    if gameOver or gameWon then return end
    if revealed[c][r] then return end

    flagged[c][r] = not flagged[c][r]
    mineCount = mineCount + (flagged[c][r] and -1 or 1)
    minesFs:SetText("|cffff4444" .. mineCount .. "|r")
    UpdateDisplay()
end

UpdateDisplay = function()
    for c = 1, COLS do
        for r = 1, ROWS do
            local cell = cells[c][r]
            if revealed[c][r] then
                local v = grid[c][r]
                if v == -1 then
                    cell.bg:SetVertexColor(MINE_COLOR[1], MINE_COLOR[2], MINE_COLOR[3], 1)
                    cell.label:SetText("|cffff0000*|r")
                    cell.label:Show()
                elseif v > 0 then
                    cell.bg:SetVertexColor(REVEALED_COLOR[1], REVEALED_COLOR[2], REVEALED_COLOR[3], 1)
                    cell.label:SetText("|cff" .. NUM_COLORS[v] .. v .. "|r")
                    cell.label:Show()
                else
                    cell.bg:SetVertexColor(REVEALED_COLOR[1], REVEALED_COLOR[2], REVEALED_COLOR[3], 1)
                    cell.label:Hide()
                end
            elseif flagged[c][r] then
                cell.bg:SetVertexColor(FLAG_COLOR[1], FLAG_COLOR[2], FLAG_COLOR[3], 1)
                cell.label:SetText("|cffffff00F|r")
                cell.label:Show()
            else
                cell.bg:SetVertexColor(UNREVEALED_COLOR[1], UNREVEALED_COLOR[2], UNREVEALED_COLOR[3], 1)
                cell.label:Hide()
            end
        end
    end
end

local function NewGame()
    gameOver = false
    gameWon = false
    firstClick = true
    mineCount = MINES
    startTime = 0
    msgFs:SetText("")
    minesFs:SetText("|cffff4444" .. mineCount .. "|r")
    if timerTicker then timerTicker:Cancel() end
    timerFs:SetText("|cff8888880:00|r")
    InitGrid()
    UpdateDisplay()

    timerTicker = C_Timer.NewTicker(1, function()
        if not firstClick and not gameOver and not gameWon then
            local elapsed = math.floor(GetTime() - startTime)
            local m = math.floor(elapsed / 60)
            local s = elapsed - m * 60
            timerFs:SetText("|cff888888" .. m .. ":" .. format("%02d", s) .. "|r")
        end
    end)
end

function PhoneMinesweeperGame:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffffffffMinesweeper|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Mine count
    minesFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    minesFs:SetPoint("TOPLEFT", 6, -16)
    minesFs:SetText("|cffff4444" .. MINES .. "|r")
    local mcf = minesFs:GetFont()
    if mcf then minesFs:SetFont(mcf, 9, "") end

    -- Timer
    timerFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    timerFs:SetPoint("TOPRIGHT", -6, -16)
    timerFs:SetText("|cff8888880:00|r")
    local tmf = timerFs:GetFont()
    if tmf then timerFs:SetFont(tmf, 9, "") end

    -- New game button
    local newBtn = CreateFrame("Button", nil, parent)
    newBtn:SetSize(28, 14)
    newBtn:SetPoint("TOP", 0, -15)

    local newBg = newBtn:CreateTexture(nil, "BACKGROUND")
    newBg:SetAllPoints()
    newBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    newBg:SetVertexColor(0.15, 0.15, 0.2, 1)

    local newHl = newBtn:CreateTexture(nil, "HIGHLIGHT")
    newHl:SetAllPoints()
    newHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    newHl:SetVertexColor(0.25, 0.25, 0.3, 0.4)

    local newLabel = newBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    newLabel:SetPoint("CENTER")
    newLabel:SetText("|cffffffffNew|r")
    local nlf = newLabel:GetFont()
    if nlf then newLabel:SetFont(nlf, 7, "") end
    newBtn:SetScript("OnClick", NewGame)

    -- Message
    msgFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    msgFs:SetPoint("TOP", 0, -30)
    local mf = msgFs:GetFont()
    if mf then msgFs:SetFont(mf, 8, "OUTLINE") end

    -- Grid
    local gridW = COLS * CELL
    local gridH = ROWS * CELL
    local gridFrame = CreateFrame("Frame", nil, parent)
    gridFrame:SetSize(gridW, gridH)
    gridFrame:SetPoint("BOTTOM", 0, 8)

    local gridBg = gridFrame:CreateTexture(nil, "BACKGROUND")
    gridBg:SetAllPoints()
    gridBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    gridBg:SetVertexColor(0.04, 0.04, 0.06, 1)

    for c = 1, COLS do
        cells[c] = {}
        for r = 1, ROWS do
            local btn = CreateFrame("Button", nil, gridFrame)
            btn:SetSize(CELL - 1, CELL - 1)
            btn:SetPoint("TOPLEFT", (c - 1) * CELL, -((r - 1) * CELL))
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(0.18, 0.18, 0.22, 1)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Buttons\\WHITE8x8")
            hl:SetVertexColor(1, 1, 1, 0.1)

            local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            label:SetPoint("CENTER")
            local lf = label:GetFont()
            if lf then label:SetFont(lf, 9, "OUTLINE") end

            local cc, rr = c, r
            btn:SetScript("OnClick", function(_, button)
                if button == "LeftButton" then
                    OnLeftClick(cc, rr)
                elseif button == "RightButton" then
                    OnRightClick(cc, rr)
                end
            end)

            cells[c][r] = {
                btn = btn,
                bg = bg,
                label = label,
            }
        end
    end

    InitGrid()
end

function PhoneMinesweeperGame:OnShow()
    if firstClick and not gameOver and not gameWon then
        NewGame()
    else
        UpdateDisplay()
    end
end

function PhoneMinesweeperGame:OnHide()
    if timerTicker then timerTicker:Cancel() end
end
