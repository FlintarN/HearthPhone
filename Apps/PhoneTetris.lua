-- PhoneTetris - Tetris game for HearthPhone

local GRID_W = 10
local GRID_H = 20
local TICK_BASE = 0.5
local TICK_MIN = 0.08
local TICK_SPEEDUP = 0.015 -- per 10 lines cleared

-- DAS (Delayed Auto Shift) for key repeat
local DAS_DELAY = 0.18  -- initial delay before repeat starts
local DAS_RATE  = 0.05  -- repeat interval once repeating

-- Global table so HearthPhone can detect us
PhoneTetrisGame = {}

local gameFrame, scoreText, levelText, msgText
local nextPreviewCells = {}   -- 4x4 grid for next piece preview
local nextPreviewFrame = nil
local cells = {}
local board = {} -- board[x][y] = color or nil
local curPiece = nil
local nextPiece = nil
local curX, curY = 0, 0
local curRotation = 0
local gameRunning = false
local gameover = false
local score = 0
local linesCleared = 0
local speedLevel = 0  -- internal speed tier (every 10 lines)
local tickTimer = 0
local tickRate = TICK_BASE

-- Line clear animation state
local animating = false
local animLines = {}      -- rows being cleared
local animTimer = 0
local ANIM_DURATION = 0.35  -- flash duration in seconds
local ANIM_FLASHES = 3      -- number of flashes

-- Key repeat state
local heldKey = nil
local heldTimer = 0
local heldRepeating = false

local COLOR_BG   = { 0.10, 0.10, 0.14, 1 }
local COLOR_GRID  = { 0.16, 0.16, 0.20, 1 }

-- Tetromino definitions: each is a table of rotations, each rotation is {x,y} offsets
local PIECES = {
    -- I
    { color = { 0.3, 0.9, 0.9, 1 }, rotations = {
        { {0,0}, {1,0}, {2,0}, {3,0} },
        { {1,0}, {1,1}, {1,2}, {1,3} },
        { {0,1}, {1,1}, {2,1}, {3,1} },
        { {2,0}, {2,1}, {2,2}, {2,3} },
    }},
    -- O
    { color = { 0.9, 0.9, 0.3, 1 }, rotations = {
        { {0,0}, {1,0}, {0,1}, {1,1} },
        { {0,0}, {1,0}, {0,1}, {1,1} },
        { {0,0}, {1,0}, {0,1}, {1,1} },
        { {0,0}, {1,0}, {0,1}, {1,1} },
    }},
    -- T
    { color = { 0.7, 0.3, 0.9, 1 }, rotations = {
        { {0,0}, {1,0}, {2,0}, {1,1} },
        { {1,0}, {0,1}, {1,1}, {1,2} },
        { {1,0}, {0,1}, {1,1}, {2,1} },
        { {0,0}, {0,1}, {1,1}, {0,2} },
    }},
    -- S
    { color = { 0.3, 0.9, 0.3, 1 }, rotations = {
        { {1,0}, {2,0}, {0,1}, {1,1} },
        { {0,0}, {0,1}, {1,1}, {1,2} },
        { {1,0}, {2,0}, {0,1}, {1,1} },
        { {0,0}, {0,1}, {1,1}, {1,2} },
    }},
    -- Z
    { color = { 0.9, 0.3, 0.3, 1 }, rotations = {
        { {0,0}, {1,0}, {1,1}, {2,1} },
        { {1,0}, {0,1}, {1,1}, {0,2} },
        { {0,0}, {1,0}, {1,1}, {2,1} },
        { {1,0}, {0,1}, {1,1}, {0,2} },
    }},
    -- L
    { color = { 0.9, 0.6, 0.2, 1 }, rotations = {
        { {0,0}, {0,1}, {1,1}, {2,1} },
        { {0,0}, {1,0}, {0,1}, {0,2} },
        { {0,0}, {1,0}, {2,0}, {2,1} },
        { {1,0}, {1,1}, {0,2}, {1,2} },
    }},
    -- J
    { color = { 0.3, 0.4, 0.9, 1 }, rotations = {
        { {2,0}, {0,1}, {1,1}, {2,1} },
        { {0,0}, {0,1}, {0,2}, {1,2} },
        { {0,0}, {1,0}, {2,0}, {0,1} },
        { {0,0}, {1,0}, {1,1}, {1,2} },
    }},
}

-- Keys that support auto-repeat
local REPEATABLE_KEYS = {
    A = true, LEFT = true,
    D = true, RIGHT = true,
    S = true, DOWN = true,
}

local function GetCell(x, y)
    return cells[x .. "," .. y]
end

local function SetCellColor(x, y, r, g, b, a)
    local tex = GetCell(x, y)
    if tex then tex:SetVertexColor(r, g, b, a or 1) end
end

local function InitBoard()
    board = {}
    for x = 1, GRID_W do
        board[x] = {}
    end
end

local function GetPieceBlocks(piece, rotation, px, py)
    local blocks = {}
    local rot = piece.rotations[(rotation % 4) + 1]
    for _, off in ipairs(rot) do
        table.insert(blocks, { x = px + off[1], y = py + off[2] })
    end
    return blocks
end

local function IsValid(piece, rotation, px, py)
    local blocks = GetPieceBlocks(piece, rotation, px, py)
    for _, b in ipairs(blocks) do
        if b.x < 1 or b.x > GRID_W or b.y < 1 or b.y > GRID_H then
            return false
        end
        if board[b.x][b.y] then
            return false
        end
    end
    return true
end

local function LockPiece()
    local blocks = GetPieceBlocks(curPiece, curRotation, curX, curY)
    for _, b in ipairs(blocks) do
        if b.x >= 1 and b.x <= GRID_W and b.y >= 1 and b.y <= GRID_H then
            board[b.x][b.y] = curPiece.color
        end
    end
end

local function FindFullLines()
    local lines = {}
    for y = 1, GRID_H do
        local full = true
        for x = 1, GRID_W do
            if not board[x][y] then
                full = false
                break
            end
        end
        if full then
            table.insert(lines, y)
        end
    end
    return lines
end

local function RemoveFullLines()
    -- Re-scan and remove using while-loop so shifting never skips a line
    local cleared = 0
    local y = GRID_H
    while y >= 1 do
        local full = true
        for x = 1, GRID_W do
            if not board[x][y] then
                full = false
                break
            end
        end
        if full then
            cleared = cleared + 1
            for shiftY = y, 2, -1 do
                for x = 1, GRID_W do
                    board[x][shiftY] = board[x][shiftY - 1]
                end
            end
            for x = 1, GRID_W do
                board[x][1] = nil
            end
            -- Don't decrement y: new content shifted into this row, check again
        else
            y = y - 1
        end
    end
    return cleared
end

local function DrawNextPreview()
    if not nextPiece or not nextPreviewFrame then return end
    -- Clear preview cells
    for _, tex in pairs(nextPreviewCells) do
        tex:SetVertexColor(unpack(COLOR_BG))
    end
    -- Draw next piece blocks in the 4x4 preview
    local rot = nextPiece.rotations[1]
    for _, off in ipairs(rot) do
        local key = (off[1] + 1) .. "," .. (off[2] + 1)
        if nextPreviewCells[key] then
            nextPreviewCells[key]:SetVertexColor(unpack(nextPiece.color))
        end
    end
end

local function SpawnPiece()
    if nextPiece then
        curPiece = nextPiece
    else
        curPiece = PIECES[math.random(#PIECES)]
    end
    nextPiece = PIECES[math.random(#PIECES)]
    curRotation = 0
    curX = math.floor(GRID_W / 2) - 1
    curY = 1
    DrawNextPreview()
    if not IsValid(curPiece, curRotation, curX, curY) then
        return false
    end
    return true
end

local function DrawGame()
    for x = 1, GRID_W do
        for y = 1, GRID_H do
            local c = board[x][y]
            if c then
                SetCellColor(x, y, c[1], c[2], c[3], c[4])
            else
                SetCellColor(x, y, unpack(COLOR_GRID))
            end
        end
    end
    -- Flash animation on cleared lines
    if animating and #animLines > 0 then
        local phase = math.floor(animTimer / (ANIM_DURATION / (ANIM_FLASHES * 2)))
        local bright = (phase % 2 == 0)
        for _, row in ipairs(animLines) do
            for x = 1, GRID_W do
                if bright then
                    SetCellColor(x, row, 1, 1, 1, 1)
                else
                    SetCellColor(x, row, 0.3, 0.3, 0.1, 1)
                end
            end
        end
    end
    -- Ghost piece
    if curPiece and not animating then
        local ghostY = curY
        while IsValid(curPiece, curRotation, curX, ghostY + 1) do
            ghostY = ghostY + 1
        end
        if ghostY > curY then
            local ghostBlocks = GetPieceBlocks(curPiece, curRotation, curX, ghostY)
            for _, b in ipairs(ghostBlocks) do
                if b.x >= 1 and b.x <= GRID_W and b.y >= 1 and b.y <= GRID_H and not board[b.x][b.y] then
                    local c = curPiece.color
                    SetCellColor(b.x, b.y, c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.7)
                end
            end
        end
    end
    -- Current piece
    if curPiece and not animating then
        local blocks = GetPieceBlocks(curPiece, curRotation, curX, curY)
        for _, b in ipairs(blocks) do
            if b.x >= 1 and b.x <= GRID_W and b.y >= 1 and b.y <= GRID_H then
                SetCellColor(b.x, b.y, unpack(curPiece.color))
            end
        end
    end
    scoreText:SetText(format("Score: |cffffd700%d|r", score))
    levelText:SetText(format("Lines: |cff88ccff%d|r", linesCleared))
end

local function GameOver()
    gameRunning = false
    gameover = true
    heldKey = nil
    msgText:SetText("|cffff4444GAME OVER|r\nPress any key")
end

local function StartGame()
    InitBoard()
    score = 0
    linesCleared = 0
    speedLevel = 0
    tickRate = TICK_BASE
    gameover = false
    gameRunning = true
    tickTimer = 0
    heldKey = nil
    animating = false
    animLines = {}
    animTimer = 0
    nextPiece = nil
    if not SpawnPiece() then
        GameOver()
        return
    end
    DrawGame()
    msgText:SetText("")
end

local function HandleLinesCleared(cleared)
    if cleared > 0 then
        linesCleared = linesCleared + cleared
        -- NES Tetris scoring: 40, 100, 300, 1200 * (speedLevel + 1)
        local points = ({ 40, 100, 300, 1200 })[cleared] or 1200
        score = score + points * (speedLevel + 1)
        -- Speed up every 10 lines
        local newSpeed = math.floor(linesCleared / 10)
        if newSpeed > speedLevel then
            speedLevel = newSpeed
            tickRate = math.max(TICK_MIN, TICK_BASE - speedLevel * TICK_SPEEDUP)
        end
    end
end

local function StartClearAnim(fullLines)
    animating = true
    animLines = fullLines
    animTimer = 0
    curPiece = nil  -- hide current piece during animation
end

local function FinishClearAnim()
    local cleared = RemoveFullLines()
    HandleLinesCleared(cleared)
    animating = false
    animLines = {}
    animTimer = 0
    if not SpawnPiece() then
        GameOver()
    end
    DrawGame()
end

local function LockAndCheck()
    LockPiece()
    local fullLines = FindFullLines()
    if #fullLines > 0 then
        StartClearAnim(fullLines)
        DrawGame()
    else
        if not SpawnPiece() then
            GameOver()
        end
        DrawGame()
    end
end

local function Tick()
    if not gameRunning or animating then return end

    if IsValid(curPiece, curRotation, curX, curY + 1) then
        curY = curY + 1
    else
        LockAndCheck()
        return
    end

    DrawGame()
end

local function HardDrop()
    if not gameRunning or not curPiece or animating then return end
    local dropped = 0
    while IsValid(curPiece, curRotation, curX, curY + 1) do
        curY = curY + 1
        dropped = dropped + 1
    end
    score = score + dropped * 2
    LockAndCheck()
    tickTimer = 0
end

local function DoMove(key)
    if not gameRunning or animating then return end

    if key == "A" or key == "LEFT" then
        if IsValid(curPiece, curRotation, curX - 1, curY) then
            curX = curX - 1
            DrawGame()
        end
    elseif key == "D" or key == "RIGHT" then
        if IsValid(curPiece, curRotation, curX + 1, curY) then
            curX = curX + 1
            DrawGame()
        end
    elseif key == "S" or key == "DOWN" then
        if IsValid(curPiece, curRotation, curX, curY + 1) then
            curY = curY + 1
            score = score + 1
            tickTimer = 0
            DrawGame()
        end
    end
end

local function HandleKey(key)
    if gameover then
        StartGame()
        return
    end
    if not gameRunning then
        StartGame()
        return
    end

    if animating then return end

    if key == "W" or key == "UP" then
        local newRot = (curRotation + 1) % 4
        if IsValid(curPiece, newRot, curX, curY) then
            curRotation = newRot
            DrawGame()
        elseif IsValid(curPiece, newRot, curX - 1, curY) then
            curX = curX - 1
            curRotation = newRot
            DrawGame()
        elseif IsValid(curPiece, newRot, curX + 1, curY) then
            curX = curX + 1
            curRotation = newRot
            DrawGame()
        end
    elseif key == "SPACE" then
        HardDrop()
    else
        DoMove(key)
        -- Start DAS for repeatable keys
        if REPEATABLE_KEYS[key] then
            heldKey = key
            heldTimer = 0
            heldRepeating = false
        end
    end
end

local function HandleKeyUp(key)
    if heldKey == key then
        heldKey = nil
    end
end

function PhoneTetrisGame:Init(parent)
    if gameFrame then return end

    -- Calculate cell size to fill parent with square cells.
    local HEADER = 14  -- space for score/level text
    local CELL

    -- Game area frame - centered
    gameFrame = CreateFrame("Frame", nil, parent)
    gameFrame:SetPoint("TOP", 0, -HEADER)

    local cellSized = false

    local function BuildGrid()
        if cellSized then return end
        local availW = parent:GetWidth()
        local availH = parent:GetHeight() - HEADER
        if availW < 10 or availH < 10 then return end

        -- Square cells: use the largest that fits both dimensions
        local cellFromW = math.floor(availW / GRID_W)
        local cellFromH = math.floor(availH / GRID_H)
        CELL = math.min(cellFromW, cellFromH)
        if CELL < 4 then CELL = 4 end

        local gridPxW = GRID_W * CELL
        local gridPxH = GRID_H * CELL
        gameFrame:SetSize(gridPxW, gridPxH)

        -- Background
        local bg = gameFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(unpack(COLOR_BG))

        -- Create grid cells (1px gap between cells)
        for gx = 1, GRID_W do
            for gy = 1, GRID_H do
                local tex = gameFrame:CreateTexture(nil, "ARTWORK")
                tex:SetSize(CELL - 1, CELL - 1)
                tex:SetPoint("TOPLEFT", (gx - 1) * CELL, -((gy - 1) * CELL))
                tex:SetTexture("Interface\\Buttons\\WHITE8x8")
                tex:SetVertexColor(unpack(COLOR_GRID))
                cells[gx .. "," .. gy] = tex
            end
        end

        -- Message text
        msgText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        msgText:SetPoint("CENTER")
        local mf = msgText:GetFont()
        if mf then msgText:SetFont(mf, 10, "OUTLINE") end
        msgText:SetText("|cff88ff88Press any key|r\n|cff888888to start|r")

        cellSized = true
    end

    -- Score text above grid
    scoreText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreText:SetPoint("TOPLEFT", 4, -2)
    scoreText:SetTextColor(0.9, 0.9, 0.9, 1)
    local sf = scoreText:GetFont()
    if sf then scoreText:SetFont(sf, 8, "OUTLINE") end
    scoreText:SetText("Score: |cffffd7000|r")

    levelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    levelText:SetPoint("TOPRIGHT", -4, -2)
    levelText:SetTextColor(0.9, 0.9, 0.9, 1)
    local lf = levelText:GetFont()
    if lf then levelText:SetFont(lf, 8, "OUTLINE") end
    levelText:SetText("Lines: |cff88ccff0|r")

    -- Next piece preview (4x4 grid, right of game grid)
    local PREVIEW_CELL = 6
    nextPreviewFrame = CreateFrame("Frame", nil, parent)
    nextPreviewFrame:SetSize(PREVIEW_CELL * 4 + 2, PREVIEW_CELL * 4 + 2)
    nextPreviewFrame:SetPoint("TOPLEFT", gameFrame, "TOPRIGHT", 4, -12)
    local prevBg = nextPreviewFrame:CreateTexture(nil, "BACKGROUND")
    prevBg:SetAllPoints()
    prevBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    prevBg:SetVertexColor(0.06, 0.06, 0.08, 1)
    local nextLabel = nextPreviewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextLabel:SetPoint("BOTTOM", nextPreviewFrame, "TOP", 0, 1)
    local nlf = nextLabel:GetFont()
    if nlf then nextLabel:SetFont(nlf, 7, "OUTLINE") end
    nextLabel:SetText("|cff888888Next|r")
    for px = 1, 4 do
        for py = 1, 4 do
            local tex = nextPreviewFrame:CreateTexture(nil, "ARTWORK")
            tex:SetSize(PREVIEW_CELL - 1, PREVIEW_CELL - 1)
            tex:SetPoint("TOPLEFT", 1 + (px - 1) * PREVIEW_CELL, -(1 + (py - 1) * PREVIEW_CELL))
            tex:SetTexture("Interface\\Buttons\\WHITE8x8")
            tex:SetVertexColor(unpack(COLOR_BG))
            nextPreviewCells[px .. "," .. py] = tex
        end
    end

    -- Keyboard input frame
    local keyFrame = CreateFrame("Frame", "PhoneTetrisKeyFrame", parent)
    keyFrame:SetAllPoints(parent)
    keyFrame:EnableKeyboard(false)
    keyFrame:SetPropagateKeyboardInput(true)

    keyFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(true)
            return
        end
        self:SetPropagateKeyboardInput(false)
        HandleKey(key)
    end)

    keyFrame:SetScript("OnKeyUp", function(self, key)
        HandleKeyUp(key)
    end)

    PhoneTetrisGame.keyFrame = keyFrame

    -- Game tick + DAS repeat + animation in OnUpdate
    parent:SetScript("OnUpdate", function(self, dt)
        -- Build grid on first frame when size is known
        if not cellSized then BuildGrid() end

        if not gameRunning then return end

        -- Line clear animation
        if animating then
            animTimer = animTimer + dt
            if animTimer >= ANIM_DURATION then
                FinishClearAnim()
            else
                DrawGame()
            end
            return
        end

        -- Game gravity tick
        tickTimer = tickTimer + dt
        if tickTimer >= tickRate then
            tickTimer = tickTimer - tickRate
            Tick()
        end

        -- DAS key repeat
        if heldKey and REPEATABLE_KEYS[heldKey] then
            heldTimer = heldTimer + dt
            if not heldRepeating then
                if heldTimer >= DAS_DELAY then
                    heldRepeating = true
                    heldTimer = 0
                    DoMove(heldKey)
                end
            else
                if heldTimer >= DAS_RATE then
                    heldTimer = heldTimer - DAS_RATE
                    DoMove(heldKey)
                end
            end
        end
    end)

    InitBoard()
end

function PhoneTetrisGame:OnShow()
    if PhoneTetrisGame.keyFrame then
        PhoneTetrisGame.keyFrame:EnableKeyboard(true)
        PhoneTetrisGame.keyFrame:SetPropagateKeyboardInput(true)
    end
    if not gameRunning and not gameover then
        for x = 1, GRID_W do
            for y = 1, GRID_H do
                SetCellColor(x, y, unpack(COLOR_GRID))
            end
        end
        if msgText then
            msgText:SetText("|cff88ff88Press any key|r\n|cff888888to start|r")
        end
    end
end

function PhoneTetrisGame:OnHide()
    if PhoneTetrisGame.keyFrame then
        PhoneTetrisGame.keyFrame:EnableKeyboard(false)
        PhoneTetrisGame.keyFrame:SetPropagateKeyboardInput(true)
    end
    heldKey = nil
end
