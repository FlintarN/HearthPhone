-- Phone2048 - 2048 number puzzle game for HearthPhone

Phone2048Game = {}

local parent
local GRID = 4
local CELL = 38
local GAP = 3
local grid = {}
local cells = {}
local score = 0
local bestScore = 0
local gameOver = false
local gameWon = false
local scoreFs, bestFs, msgFs, gridFrame

local COLORS = {
    [0]    = { bg = {0.08, 0.08, 0.10}, text = {0.3, 0.3, 0.3} },
    [2]    = { bg = {0.75, 0.71, 0.66}, text = {1, 1, 1} },
    [4]    = { bg = {0.74, 0.70, 0.60}, text = {1, 0.95, 0.8} },
    [8]    = { bg = {0.90, 0.55, 0.30}, text = {1, 1, 0.9} },
    [16]   = { bg = {0.90, 0.42, 0.25}, text = {1, 0.9, 0.7} },
    [32]   = { bg = {0.90, 0.33, 0.25}, text = {1, 0.85, 0.6} },
    [64]   = { bg = {0.90, 0.22, 0.12}, text = {1, 0.8, 0.5} },
    [128]  = { bg = {0.85, 0.78, 0.35}, text = {1, 1, 0.7} },
    [256]  = { bg = {0.85, 0.76, 0.28}, text = {1, 0.95, 0.6} },
    [512]  = { bg = {0.85, 0.74, 0.20}, text = {1, 0.9, 0.5} },
    [1024] = { bg = {0.85, 0.72, 0.12}, text = {1, 0.85, 0.4} },
    [2048] = { bg = {0.85, 0.70, 0.05}, text = {1, 1, 0.3} },
}

local function GetColor(val)
    return COLORS[val] or COLORS[2048]
end

local function InitGrid()
    for c = 1, GRID do
        grid[c] = {}
        for r = 1, GRID do
            grid[c][r] = 0
        end
    end
end

local function EmptyCells()
    local empty = {}
    for c = 1, GRID do
        for r = 1, GRID do
            if grid[c][r] == 0 then
                table.insert(empty, {c = c, r = r})
            end
        end
    end
    return empty
end

local function SpawnTile()
    local empty = EmptyCells()
    if #empty == 0 then return end
    local pos = empty[math.random(#empty)]
    grid[pos.c][pos.r] = math.random() < 0.9 and 2 or 4
end

local UpdateDisplay

local function HasMoves()
    for c = 1, GRID do
        for r = 1, GRID do
            if grid[c][r] == 0 then return true end
            if c < GRID and grid[c][r] == grid[c+1][r] then return true end
            if r < GRID and grid[c][r] == grid[c][r+1] then return true end
        end
    end
    return false
end

local function SlideLine(line)
    -- Remove zeros
    local nums = {}
    for i = 1, #line do
        if line[i] ~= 0 then
            table.insert(nums, line[i])
        end
    end
    -- Merge
    local merged = {}
    local i = 1
    while i <= #nums do
        if i < #nums and nums[i] == nums[i+1] then
            local val = nums[i] * 2
            table.insert(merged, val)
            score = score + val
            i = i + 2
        else
            table.insert(merged, nums[i])
            i = i + 1
        end
    end
    -- Pad with zeros
    while #merged < GRID do
        table.insert(merged, 0)
    end
    return merged
end

local function Move(dir)
    if gameOver then return false end

    local moved = false
    local oldGrid = {}
    for c = 1, GRID do
        oldGrid[c] = {}
        for r = 1, GRID do
            oldGrid[c][r] = grid[c][r]
        end
    end

    if dir == "left" then
        for r = 1, GRID do
            local line = {}
            for c = 1, GRID do table.insert(line, grid[c][r]) end
            local result = SlideLine(line)
            for c = 1, GRID do grid[c][r] = result[c] end
        end
    elseif dir == "right" then
        for r = 1, GRID do
            local line = {}
            for c = GRID, 1, -1 do table.insert(line, grid[c][r]) end
            local result = SlideLine(line)
            for ci = 1, GRID do grid[GRID - ci + 1][r] = result[ci] end
        end
    elseif dir == "up" then
        for c = 1, GRID do
            local line = {}
            for r = 1, GRID do table.insert(line, grid[c][r]) end
            local result = SlideLine(line)
            for r = 1, GRID do grid[c][r] = result[r] end
        end
    elseif dir == "down" then
        for c = 1, GRID do
            local line = {}
            for r = GRID, 1, -1 do table.insert(line, grid[c][r]) end
            local result = SlideLine(line)
            for ri = 1, GRID do grid[c][GRID - ri + 1] = result[ri] end
        end
    end

    -- Check if anything changed
    for c = 1, GRID do
        for r = 1, GRID do
            if grid[c][r] ~= oldGrid[c][r] then
                moved = true
                break
            end
        end
        if moved then break end
    end

    if moved then
        SpawnTile()
        if score > bestScore then
            bestScore = score
            HearthPhoneDB = HearthPhoneDB or {}
            HearthPhoneDB.best2048 = bestScore
        end
        UpdateDisplay()

        -- Check for 2048
        if not gameWon then
            for c = 1, GRID do
                for r = 1, GRID do
                    if grid[c][r] == 2048 then
                        gameWon = true
                        msgFs:SetText("|cffffff002048! You win!|r")
                    end
                end
            end
        end

        if not HasMoves() then
            gameOver = true
            msgFs:SetText("|cffff4444Game Over!|r")
        end
    end

    return moved
end

UpdateDisplay = function()
    scoreFs:SetText("|cffffffff" .. score .. "|r")
    bestFs:SetText("|cffaaaaaa" .. bestScore .. "|r")

    for c = 1, GRID do
        for r = 1, GRID do
            local cell = cells[c][r]
            local val = grid[c][r]
            local color = GetColor(val)

            cell.bg:SetVertexColor(color.bg[1], color.bg[2], color.bg[3], 1)

            if val > 0 then
                local text = tostring(val)
                cell.label:SetText(text)
                local tc = color.text
                cell.label:SetTextColor(tc[1], tc[2], tc[3], 1)
                -- Scale font size based on digit count
                local fontSize = 14
                if #text == 2 then fontSize = 12
                elseif #text == 3 then fontSize = 10
                elseif #text >= 4 then fontSize = 8 end
                local fontPath = cell.label:GetFont()
                if fontPath then cell.label:SetFont(fontPath, fontSize, "OUTLINE") end
                cell.label:Show()
            else
                cell.label:Hide()
            end
        end
    end
end

local function NewGame()
    score = 0
    gameOver = false
    gameWon = false
    msgFs:SetText("")
    InitGrid()
    SpawnTile()
    SpawnTile()
    UpdateDisplay()
end

-- Swipe detection
local startX, startY, isDragging

function Phone2048Game:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.best2048 or 0

    local W = parent:GetWidth() or 170

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffffffff2048|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 11, "OUTLINE") end

    -- Score labels
    local scoreLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreLabel:SetPoint("TOPLEFT", 6, -16)
    scoreLabel:SetText("|cff888888Score|r")
    local slf = scoreLabel:GetFont()
    if slf then scoreLabel:SetFont(slf, 7, "") end

    scoreFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreFs:SetPoint("TOPLEFT", 6, -24)
    scoreFs:SetText("|cffffffff0|r")
    local scf = scoreFs:GetFont()
    if scf then scoreFs:SetFont(scf, 9, "") end

    local bestLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bestLabel:SetPoint("TOP", 0, -16)
    bestLabel:SetText("|cff888888Best|r")
    local blf = bestLabel:GetFont()
    if blf then bestLabel:SetFont(blf, 7, "") end

    bestFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bestFs:SetPoint("TOP", 0, -24)
    bestFs:SetText("|cffaaaaaa0|r")
    local bsf = bestFs:GetFont()
    if bsf then bestFs:SetFont(bsf, 9, "") end

    -- New game button
    local newBtn = CreateFrame("Button", nil, parent)
    newBtn:SetSize(28, 14)
    newBtn:SetPoint("TOPRIGHT", -4, -18)

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

    -- Message area
    msgFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    msgFs:SetPoint("TOP", 0, -36)
    local mf = msgFs:GetFont()
    if mf then msgFs:SetFont(mf, 8, "OUTLINE") end

    -- Grid frame
    local gridW = GRID * CELL + (GRID + 1) * GAP
    gridFrame = CreateFrame("Frame", nil, parent)
    gridFrame:SetSize(gridW, gridW)
    gridFrame:SetPoint("BOTTOM", 0, 10)

    local gridBg = gridFrame:CreateTexture(nil, "BACKGROUND")
    gridBg:SetAllPoints()
    gridBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    gridBg:SetVertexColor(0.06, 0.06, 0.08, 1)

    -- Create cells
    for c = 1, GRID do
        cells[c] = {}
        for r = 1, GRID do
            local x = GAP + (c - 1) * (CELL + GAP)
            local y = -(GAP + (r - 1) * (CELL + GAP))

            local cellFrame = CreateFrame("Frame", nil, gridFrame)
            cellFrame:SetSize(CELL, CELL)
            cellFrame:SetPoint("TOPLEFT", x, y)

            local bg = cellFrame:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(0.08, 0.08, 0.10, 1)

            local label = cellFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            label:SetPoint("CENTER")
            label:SetText("")
            local lf = label:GetFont()
            if lf then label:SetFont(lf, 10, "OUTLINE") end

            cells[c][r] = {
                frame = cellFrame,
                bg = bg,
                label = label,
            }
        end
    end

    -- Swipe detection overlay
    local swipeFrame = CreateFrame("Frame", nil, gridFrame)
    swipeFrame:SetAllPoints()
    swipeFrame:EnableMouse(true)

    swipeFrame:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            startX, startY = GetCursorPosition()
            isDragging = true
        end
    end)

    swipeFrame:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and isDragging then
            isDragging = false
            local endX, endY = GetCursorPosition()
            local dx = endX - startX
            local dy = endY - startY
            local threshold = 15

            if math.abs(dx) > math.abs(dy) then
                if dx > threshold then
                    Move("right")
                elseif dx < -threshold then
                    Move("left")
                end
            else
                if dy > threshold then
                    Move("up")
                elseif dy < -threshold then
                    Move("down")
                end
            end
        end
    end)

    -- Keyboard input (WASD + arrow keys)
    local keyFrame = CreateFrame("Frame", "Phone2048KeyFrame", gridFrame)
    keyFrame:SetAllPoints()
    keyFrame:SetPropagateKeyboardInput(true)
    keyFrame:SetScript("OnKeyDown", function(self, key)
        if not parent:IsShown() then return end
        local dir
        if key == "W" or key == "UP" then dir = "up"
        elseif key == "S" or key == "DOWN" then dir = "down"
        elseif key == "A" or key == "LEFT" then dir = "left"
        elseif key == "D" or key == "RIGHT" then dir = "right"
        end
        if dir then
            self:SetPropagateKeyboardInput(false)
            Move(dir)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    InitGrid()
end

function Phone2048Game:OnShow()
    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.best2048 or 0
    if not gameOver and EmptyCells and #EmptyCells() == 16 then
        NewGame()
    else
        UpdateDisplay()
    end
    if Phone2048KeyFrame then
        Phone2048KeyFrame:EnableKeyboard(true)
    end
end

function Phone2048Game:OnHide()
    if Phone2048KeyFrame then
        Phone2048KeyFrame:EnableKeyboard(false)
    end
end
