-- PhoneSnake - Snake game for HearthPhone

local CELL = 10
local GRID_W = 16
local GRID_H = 20
local TICK_RATE = 0.15

-- Global table so HearthPhone can detect us
PhoneSnakeGame = {}

local gameFrame, scoreText, msgText
local cells = {}
local snake = {}
local food = nil
local dir = { x = 1, y = 0 }
local nextDir = { x = 1, y = 0 }
local gameRunning = false
local gameover = false
local score = 0
local tickTimer = 0

local COLOR_BG    = { 0.08, 0.08, 0.1, 1 }
local COLOR_SNAKE  = { 0.3, 0.9, 0.3, 1 }
local COLOR_HEAD   = { 0.5, 1, 0.5, 1 }
local COLOR_FOOD   = { 1, 0.3, 0.3, 1 }
local COLOR_GRID   = { 0.12, 0.12, 0.15, 1 }

local function GetCell(x, y)
    local key = x .. "," .. y
    return cells[key]
end

local function SetCellColor(x, y, r, g, b, a)
    local tex = GetCell(x, y)
    if tex then tex:SetVertexColor(r, g, b, a or 1) end
end

local function ClearGrid()
    for _, tex in pairs(cells) do
        tex:SetVertexColor(unpack(COLOR_GRID))
    end
end

local function SpawnFood()
    local open = {}
    local occupied = {}
    for _, s in ipairs(snake) do
        occupied[s.x .. "," .. s.y] = true
    end
    for gx = 1, GRID_W do
        for gy = 1, GRID_H do
            if not occupied[gx .. "," .. gy] then
                table.insert(open, { x = gx, y = gy })
            end
        end
    end
    if #open > 0 then
        food = open[math.random(#open)]
    end
end

local function DrawGame()
    ClearGrid()
    -- Draw food
    if food then
        SetCellColor(food.x, food.y, unpack(COLOR_FOOD))
    end
    -- Draw snake
    for i, s in ipairs(snake) do
        if i == 1 then
            SetCellColor(s.x, s.y, unpack(COLOR_HEAD))
        else
            SetCellColor(s.x, s.y, unpack(COLOR_SNAKE))
        end
    end
    scoreText:SetText(format("Score: |cffffd700%d|r", score))
end

local function StartGame()
    snake = {}
    local startX = math.floor(GRID_W / 2)
    local startY = math.floor(GRID_H / 2)
    for i = 0, 3 do
        table.insert(snake, { x = startX - i, y = startY })
    end
    dir = { x = 1, y = 0 }
    nextDir = { x = 1, y = 0 }
    score = 0
    gameover = false
    gameRunning = true
    tickTimer = 0
    SpawnFood()
    DrawGame()
    msgText:SetText("")
end

local function GameOver()
    gameRunning = false
    gameover = true
    msgText:SetText("|cffff4444GAME OVER|r\nPress any key")
end

local function Tick()
    if not gameRunning then return end

    dir.x = nextDir.x
    dir.y = nextDir.y

    local head = snake[1]
    local nx = head.x + dir.x
    local ny = head.y + dir.y

    -- Wall collision
    if nx < 1 or nx > GRID_W or ny < 1 or ny > GRID_H then
        GameOver()
        return
    end

    -- Self collision
    for _, s in ipairs(snake) do
        if s.x == nx and s.y == ny then
            GameOver()
            return
        end
    end

    -- Move
    table.insert(snake, 1, { x = nx, y = ny })

    -- Eat food?
    if food and nx == food.x and ny == food.y then
        score = score + 10
        SpawnFood()
    else
        table.remove(snake)
    end

    DrawGame()
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

    if key == "W" or key == "UP" then
        if dir.y ~= 1 then nextDir = { x = 0, y = -1 } end
    elseif key == "S" or key == "DOWN" then
        if dir.y ~= -1 then nextDir = { x = 0, y = 1 } end
    elseif key == "A" or key == "LEFT" then
        if dir.x ~= 1 then nextDir = { x = -1, y = 0 } end
    elseif key == "D" or key == "RIGHT" then
        if dir.x ~= -1 then nextDir = { x = 1, y = 0 } end
    end
end

function PhoneSnakeGame:Init(parent)
    if gameFrame then return end

    local gridPxW = GRID_W * CELL
    local gridPxH = GRID_H * CELL

    -- Score text above grid
    scoreText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreText:SetPoint("TOP", 0, -2)
    scoreText:SetTextColor(0.9, 0.9, 0.9, 1)
    local sf = scoreText:GetFont()
    if sf then scoreText:SetFont(sf, 9, "OUTLINE") end
    scoreText:SetText("Score: |cffffd7000|r")

    -- Game area frame
    gameFrame = CreateFrame("Frame", nil, parent)
    gameFrame:SetSize(gridPxW + 2, gridPxH + 2)
    gameFrame:SetPoint("TOP", 0, -16)

    -- Border
    local border = gameFrame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.3, 0.3, 0.4, 0.5)

    -- Background
    local bg = gameFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(unpack(COLOR_BG))

    -- Create grid cells
    for gx = 1, GRID_W do
        for gy = 1, GRID_H do
            local tex = gameFrame:CreateTexture(nil, "ARTWORK")
            tex:SetSize(CELL - 1, CELL - 1)
            tex:SetPoint("TOPLEFT", (gx - 1) * CELL + 1, -((gy - 1) * CELL + 1))
            tex:SetTexture("Interface\\Buttons\\WHITE8x8")
            tex:SetVertexColor(unpack(COLOR_GRID))
            cells[gx .. "," .. gy] = tex
        end
    end

    -- Message text (game over / start)
    msgText = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgText:SetPoint("CENTER")
    local mf = msgText:GetFont()
    if mf then msgText:SetFont(mf, 11, "OUTLINE") end
    msgText:SetText("|cff88ff88Press any key|r\n|cff888888to start|r")

    -- Keyboard input frame (only active when snake page is shown)
    local keyFrame = CreateFrame("Frame", "PhoneSnakeKeyFrame", parent)
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

    PhoneSnakeGame.keyFrame = keyFrame

    -- Game tick
    gameFrame:SetScript("OnUpdate", function(self, dt)
        if not gameRunning then return end
        tickTimer = tickTimer + dt
        if tickTimer >= TICK_RATE then
            tickTimer = tickTimer - TICK_RATE
            Tick()
        end
    end)
end

function PhoneSnakeGame:OnShow()
    if PhoneSnakeGame.keyFrame then
        PhoneSnakeGame.keyFrame:EnableKeyboard(true)
        PhoneSnakeGame.keyFrame:SetPropagateKeyboardInput(true)
    end
    if not gameRunning and not gameover then
        ClearGrid()
        if msgText then
            msgText:SetText("|cff88ff88Press any key|r\n|cff888888to start|r")
        end
    end
end

function PhoneSnakeGame:OnHide()
    if PhoneSnakeGame.keyFrame then
        PhoneSnakeGame.keyFrame:EnableKeyboard(false)
        PhoneSnakeGame.keyFrame:SetPropagateKeyboardInput(true)
    end
end
