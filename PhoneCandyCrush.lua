-- PhoneCandyCrush - Match-3 game with levels for HearthPhone

PhoneCandyCrushGame = {}

local parent
local COLS = 7
local ROWS = 8
local CELL = 24
local NUM_COLORS = 6

-- Grid values: -1 = block, 0 = empty, 1-6 = candy, 7 = bomb
local BLOCK = -1
local BOMB = 7

local grid = {}
local cells = {}
local selected = nil
local score = 0
local currentLevel = 1
local isProcessing = false
local gameActive = false

-- UI refs
local scoreFs, levelFs, targetFs, msgFs, gridFrame

-- Raid mark icons and tint colors
local CANDY = {
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", r = 0.95, g = 0.85, b = 0.15 },  -- Star
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", r = 0.95, g = 0.50, b = 0.10 },  -- Circle
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", r = 0.70, g = 0.30, b = 0.90 },  -- Diamond
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", r = 0.20, g = 0.80, b = 0.30 },  -- Triangle
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", r = 0.55, g = 0.75, b = 0.95 },  -- Moon
    { icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", r = 0.90, g = 0.20, b = 0.20 },  -- Cross
}

local BOMB_ICON = "Interface\\Icons\\INV_Misc_Bomb_04"

-- ============================================================
-- LEVEL DEFINITIONS
-- ============================================================
local LEVELS = {
    {
        name = "Level 1",
        subtitle = "The Basics",
        target = 300,
        bombs = false,
        blocks = {},
    },
    {
        name = "Level 2",
        subtitle = "Stone Walls",
        target = 600,
        bombs = false,
        blocks = {
            {2, 3}, {6, 3},
            {4, 4}, {4, 5},
            {2, 6}, {6, 6},
        },
    },
    {
        name = "Level 3",
        subtitle = "Bombs Away",
        target = 1000,
        bombs = true,
        blocks = {
            {1, 1}, {7, 1}, {1, 8}, {7, 8},
            {3, 4}, {5, 4},
            {3, 5}, {5, 5},
        },
    },
}

local function GenerateLevel(lvlNum)
    local target = 500 + (lvlNum - 1) * 400
    local numBlocks = math.min(lvlNum + 4, 16)
    local blocks = {}
    local used = {}
    for _ = 1, numBlocks do
        local tries = 0
        while tries < 50 do
            local c = math.random(1, COLS)
            local r = math.random(1, ROWS)
            local key = c .. "," .. r
            if not used[key] then
                used[key] = true
                table.insert(blocks, { c, r })
                break
            end
            tries = tries + 1
        end
    end
    return {
        name = "Level " .. lvlNum,
        subtitle = "Endless",
        target = target,
        bombs = true,
        blocks = blocks,
    }
end

local function GetLevel(idx)
    if idx <= #LEVELS then
        return LEVELS[idx]
    end
    return GenerateLevel(idx)
end

-- ============================================================
-- GRID LOGIC
-- ============================================================

local function IsCandy(v)
    return v and v >= 1 and v <= NUM_COLORS
end

local function HasMatchAt(c, r)
    local color = grid[c] and grid[c][r]
    if not IsCandy(color) then return false end
    if c >= 3 and grid[c-1][r] == color and grid[c-2][r] == color then return true end
    if r >= 3 and grid[c][r-1] == color and grid[c][r-2] == color then return true end
    return false
end

local function InitGrid()
    local lvl = GetLevel(currentLevel)
    -- Build block set
    local blockSet = {}
    for _, b in ipairs(lvl.blocks) do
        blockSet[b[1] .. "," .. b[2]] = true
    end

    for c = 1, COLS do
        grid[c] = grid[c] or {}
        for r = 1, ROWS do
            if blockSet[c .. "," .. r] then
                grid[c][r] = BLOCK
            else
                repeat
                    grid[c][r] = math.random(1, NUM_COLORS)
                until not HasMatchAt(c, r)
            end
        end
    end
end

-- Returns matched (2D bool array) and groups (list of position lists with length)
local function FindMatches()
    local matched = {}
    for c = 1, COLS do
        matched[c] = {}
        for r = 1, ROWS do
            matched[c][r] = false
        end
    end
    local found = false
    local groups = {}

    -- Horizontal
    for r = 1, ROWS do
        local c = 1
        while c <= COLS do
            local color = grid[c][r]
            if IsCandy(color) then
                local len = 1
                while c + len <= COLS and grid[c + len][r] == color do
                    len = len + 1
                end
                if len >= 3 then
                    local group = {}
                    for i = 0, len - 1 do
                        matched[c + i][r] = true
                        table.insert(group, { c = c + i, r = r })
                    end
                    table.insert(groups, group)
                    found = true
                end
                c = c + len
            else
                c = c + 1
            end
        end
    end

    -- Vertical
    for c = 1, COLS do
        local r = 1
        while r <= ROWS do
            local color = grid[c][r]
            if IsCandy(color) then
                local len = 1
                while r + len <= ROWS and grid[c][r + len] == color do
                    len = len + 1
                end
                if len >= 3 then
                    local group = {}
                    for i = 0, len - 1 do
                        matched[c][r + i] = true
                        table.insert(group, { c = c, r = r + i })
                    end
                    table.insert(groups, group)
                    found = true
                end
                r = r + len
            else
                r = r + 1
            end
        end
    end

    if found then
        return matched, groups
    end
    return nil, nil
end

local function RemoveMatches(matched)
    local count = 0
    -- First pass: clear matched cells
    for c = 1, COLS do
        for r = 1, ROWS do
            if matched[c][r] then
                grid[c][r] = 0
                count = count + 1
            end
        end
    end
    -- Second pass: detonate bombs adjacent to any cleared cell
    local bombsToDetonate = {}
    for c = 1, COLS do
        for r = 1, ROWS do
            if matched[c][r] then
                for dc = -1, 1 do
                    for dr = -1, 1 do
                        if dc ~= 0 or dr ~= 0 then
                            local nc, nr = c + dc, r + dr
                            if nc >= 1 and nc <= COLS and nr >= 1 and nr <= ROWS then
                                if grid[nc][nr] == BOMB then
                                    bombsToDetonate[nc .. "," .. nr] = { c = nc, r = nr }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- Detonate found bombs (3x3 clear)
    local detonated = {}
    for _, pos in pairs(bombsToDetonate) do
        table.insert(detonated, pos)
        grid[pos.c][pos.r] = 0
        count = count + 1
        for dc = -1, 1 do
            for dr = -1, 1 do
                if dc ~= 0 or dr ~= 0 then
                    local nc, nr = pos.c + dc, pos.r + dr
                    if nc >= 1 and nc <= COLS and nr >= 1 and nr <= ROWS then
                        local v = grid[nc][nr]
                        if v > 0 then
                            grid[nc][nr] = 0
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return count, detonated
end

-- Gravity with block support: pieces fall within segments between blocks
local function ApplyGravity()
    for c = 1, COLS do
        local r = ROWS
        while r >= 1 do
            if grid[c][r] == BLOCK then
                r = r - 1
            else
                -- Find top of this free segment
                local bottom = r
                local top = r
                while top > 1 and grid[c][top - 1] ~= BLOCK do
                    top = top - 1
                end
                -- Compact within [top..bottom]
                local write = bottom
                for row = bottom, top, -1 do
                    local v = grid[c][row]
                    if v > 0 then
                        if write ~= row then
                            grid[c][write] = v
                            grid[c][row] = 0
                        end
                        write = write - 1
                    end
                end
                -- Fill remaining empty
                for row = write, top, -1 do
                    if grid[c][row] == 0 then
                        grid[c][row] = math.random(1, NUM_COLORS)
                    end
                end
                r = top - 1
            end
        end
    end
end

-- Forward declarations
local UpdateDisplay, ProcessChain, CheckLevelComplete, UpdateUI

local function HasValidMoves()
    for c = 1, COLS do
        for r = 1, ROWS do
            local v = grid[c][r]
            if IsCandy(v) or v == BOMB then
                -- Try swap right
                if c < COLS and (IsCandy(grid[c+1][r]) or grid[c+1][r] == BOMB) then
                    grid[c][r], grid[c+1][r] = grid[c+1][r], grid[c][r]
                    if FindMatches() then
                        grid[c][r], grid[c+1][r] = grid[c+1][r], grid[c][r]
                        return true
                    end
                    grid[c][r], grid[c+1][r] = grid[c+1][r], grid[c][r]
                end
                -- Try swap down
                if r < ROWS and (IsCandy(grid[c][r+1]) or grid[c][r+1] == BOMB) then
                    grid[c][r], grid[c][r+1] = grid[c][r+1], grid[c][r]
                    if FindMatches() then
                        grid[c][r], grid[c][r+1] = grid[c][r+1], grid[c][r]
                        return true
                    end
                    grid[c][r], grid[c][r+1] = grid[c][r+1], grid[c][r]
                end
            end
        end
    end
    return false
end

ProcessChain = function()
    local matched, groups = FindMatches()
    if not matched then
        isProcessing = false
        CheckLevelComplete()
        if not HasValidMoves() then
            -- Reshuffle (keep blocks)
            local lvl = GetLevel(currentLevel)
            local blockSet = {}
            for _, b in ipairs(lvl.blocks) do
                blockSet[b[1] .. "," .. b[2]] = true
            end
            for c = 1, COLS do
                for r = 1, ROWS do
                    if grid[c][r] ~= BLOCK then
                        repeat
                            grid[c][r] = math.random(1, NUM_COLORS)
                        until not HasMatchAt(c, r)
                    end
                end
            end
            UpdateDisplay()
            msgFs:SetText("|cff888888Reshuffled!|r")
            C_Timer.After(1.5, function() msgFs:SetText("") end)
        end
        return
    end

    -- Check for bomb creation (match 4+ and bombs enabled)
    local lvl = GetLevel(currentLevel)
    local bombPositions = {}
    if lvl.bombs and groups then
        for _, group in ipairs(groups) do
            if #group >= 4 then
                local mid = group[math.ceil(#group / 2)]
                table.insert(bombPositions, mid)
            end
        end
    end

    -- Flash matched cells
    for c = 1, COLS do
        for r = 1, ROWS do
            if matched[c][r] and cells[c] and cells[c][r] then
                cells[c][r].bg:SetVertexColor(1, 1, 1, 1)
            end
        end
    end

    C_Timer.After(0.15, function()
        -- Don't remove cells that will become bombs
        for _, bp in ipairs(bombPositions) do
            matched[bp.c][bp.r] = false
        end

        local count, detonated = RemoveMatches(matched)
        score = score + count * 10

        -- Bonus points for each bomb detonation
        if detonated and #detonated > 0 then
            score = score + #detonated * 50
        end

        -- Place bombs
        for _, bp in ipairs(bombPositions) do
            grid[bp.c][bp.r] = BOMB
            score = score + 20  -- bonus for creating a bomb
        end

        scoreFs:SetText("|cffffffff" .. score .. "|r")

        -- Explosion animation for detonated bombs
        if detonated and #detonated > 0 then
            -- Flash the 3x3 area around each bomb
            for _, pos in ipairs(detonated) do
                for dc = -1, 1 do
                    for dr = -1, 1 do
                        local nc, nr = pos.c + dc, pos.r + dr
                        if nc >= 1 and nc <= COLS and nr >= 1 and nr <= ROWS then
                            local cell = cells[nc] and cells[nc][nr]
                            if cell then
                                cell.bg:SetVertexColor(1, 0.6, 0, 1)
                                cell.symbol:SetTexture("Interface\\Buttons\\WHITE8x8")
                                cell.symbol:SetVertexColor(1, 0.9, 0.3, 1)
                                cell.symbol:Show()
                            end
                        end
                    end
                end
            end

            -- Second flash: expand to bright white-yellow
            C_Timer.After(0.08, function()
                for _, pos in ipairs(detonated) do
                    for dc = -1, 1 do
                        for dr = -1, 1 do
                            local nc, nr = pos.c + dc, pos.r + dr
                            if nc >= 1 and nc <= COLS and nr >= 1 and nr <= ROWS then
                                local cell = cells[nc] and cells[nc][nr]
                                if cell then
                                    cell.bg:SetVertexColor(1, 1, 0.7, 1)
                                    cell.symbol:SetVertexColor(1, 1, 1, 1)
                                end
                            end
                        end
                    end
                end

                -- Fade out and continue
                C_Timer.After(0.1, function()
                    UpdateDisplay()
                    C_Timer.After(0.1, function()
                        ApplyGravity()
                        UpdateDisplay()
                        C_Timer.After(0.12, function()
                            ProcessChain()
                        end)
                    end)
                end)
            end)
        else
            UpdateDisplay()
            C_Timer.After(0.1, function()
                ApplyGravity()
                UpdateDisplay()
                C_Timer.After(0.12, function()
                    ProcessChain()
                end)
            end)
        end
    end)
end

CheckLevelComplete = function()
    local lvl = GetLevel(currentLevel)
    if score >= lvl.target then
        msgFs:SetText("|cff44ff44Level Complete!|r")
        C_Timer.After(1.5, function()
            currentLevel = currentLevel + 1
            score = 0
            selected = nil
            isProcessing = false
            InitGrid()
            UpdateUI()
            UpdateDisplay()
            msgFs:SetText("")
        end)
    end
end

local function TrySwap(c1, r1, c2, r2)
    if isProcessing then return end
    local dc = math.abs(c1 - c2)
    local dr = math.abs(r1 - r2)
    if dc + dr ~= 1 then return end

    local v1, v2 = grid[c1][r1], grid[c2][r2]
    -- Can't swap blocks
    if v1 == BLOCK or v2 == BLOCK then return end
    -- Can't swap empty
    if v1 == 0 or v2 == 0 then return end

    -- Normal swap
    grid[c1][r1], grid[c2][r2] = grid[c2][r2], grid[c1][r1]

    local matched = FindMatches()
    if matched then
        isProcessing = true
        selected = nil
        UpdateDisplay()
        ProcessChain()
    else
        grid[c1][r1], grid[c2][r2] = grid[c2][r2], grid[c1][r1]
        selected = nil
        UpdateDisplay()
    end
end

local function OnCellClick(c, r)
    if isProcessing then return end
    local v = grid[c][r]
    if v == BLOCK or v == 0 then return end

    if selected then
        if selected.c == c and selected.r == r then
            selected = nil
            UpdateDisplay()
        else
            TrySwap(selected.c, selected.r, c, r)
        end
    else
        selected = { c = c, r = r }
        UpdateDisplay()
    end
end

-- ============================================================
-- DISPLAY
-- ============================================================

UpdateUI = function()
    local lvl = GetLevel(currentLevel)
    levelFs:SetText("|cffff6699" .. lvl.name .. "|r |cff888888- " .. lvl.subtitle .. "|r")
    targetFs:SetText("|cff888888Goal: " .. lvl.target .. "|r")
    scoreFs:SetText("|cffffffff" .. score .. "|r")
end

UpdateDisplay = function()
    for c = 1, COLS do
        for r = 1, ROWS do
            local cell = cells[c] and cells[c][r]
            if cell then
                local v = grid[c][r]
                if v == BLOCK then
                    -- Stone block: bright grey, distinct from board
                    cell.bg:SetVertexColor(0.35, 0.33, 0.30, 1)
                    cell.shine:SetVertexColor(0.50, 0.48, 0.44, 0.7)
                    cell.shine:Show()
                    cell.symbol:SetTexture("Interface\\Buttons\\WHITE8x8")
                    cell.symbol:SetVertexColor(0.25, 0.23, 0.20, 1)
                    cell.symbol:Show()
                    cell.btn:Show()
                elseif v == BOMB then
                    -- Bomb: bright red-orange bg with skull
                    cell.bg:SetVertexColor(0.55, 0.10, 0.05, 1)
                    cell.shine:SetVertexColor(0.80, 0.25, 0.10, 0.6)
                    cell.shine:Show()
                    cell.symbol:SetTexture(BOMB_ICON)
                    cell.symbol:SetVertexColor(1, 1, 1, 1)
                    cell.symbol:Show()
                    cell.btn:Show()
                elseif IsCandy(v) then
                    local cc = CANDY[v]
                    cell.bg:SetVertexColor(cc.r * 0.3, cc.g * 0.3, cc.b * 0.3, 1)
                    cell.shine:SetVertexColor(cc.r * 0.5, cc.g * 0.5, cc.b * 0.5, 0.4)
                    cell.shine:Show()
                    cell.symbol:SetTexture(cc.icon)
                    cell.symbol:SetVertexColor(1, 1, 1, 1)
                    cell.symbol:Show()
                    cell.btn:Show()
                else
                    cell.bg:SetVertexColor(0.05, 0.05, 0.07, 0.3)
                    cell.shine:Hide()
                    cell.symbol:Hide()
                end

                if selected and selected.c == c and selected.r == r then
                    cell.border:Show()
                else
                    cell.border:Hide()
                end
            end
        end
    end
end

local function StartLevel(lvlIdx)
    currentLevel = lvlIdx or 1
    score = 0
    selected = nil
    isProcessing = false
    gameActive = true
    InitGrid()
    if scoreFs then
        UpdateUI()
        UpdateDisplay()
        msgFs:SetText("")
    end
end

-- ============================================================
-- INIT
-- ============================================================

function PhoneCandyCrushGame:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    -- Title
    local titleFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    titleFs:SetPoint("TOP", 0, -2)
    titleFs:SetText("|cffff6699Candy|r |cff66ccffCrush|r")
    local tf = titleFs:GetFont()
    if tf then titleFs:SetFont(tf, 10, "OUTLINE") end

    -- Level name + subtitle
    levelFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    levelFs:SetPoint("TOP", titleFs, "BOTTOM", 0, -2)
    local lf = levelFs:GetFont()
    if lf then levelFs:SetFont(lf, 7, "") end

    -- Score
    scoreFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreFs:SetPoint("TOPLEFT", 6, -28)
    scoreFs:SetText("|cffffffff0|r")
    local scf = scoreFs:GetFont()
    if scf then scoreFs:SetFont(scf, 9, "OUTLINE") end

    -- Target
    targetFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    targetFs:SetPoint("TOPRIGHT", -6, -28)
    local tgf = targetFs:GetFont()
    if tgf then targetFs:SetFont(tgf, 7, "") end

    -- Message (level complete, reshuffled, etc.)
    msgFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    msgFs:SetPoint("TOP", 0, -38)
    local mf = msgFs:GetFont()
    if mf then msgFs:SetFont(mf, 8, "OUTLINE") end

    -- New game button
    local newBtn = CreateFrame("Button", nil, parent)
    newBtn:SetSize(36, 12)
    newBtn:SetPoint("TOPLEFT", 6, -28)

    local newBg = newBtn:CreateTexture(nil, "BACKGROUND")
    newBg:SetAllPoints()
    newBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    newBg:SetVertexColor(0.15, 0.15, 0.2, 0.9)

    local newHl = newBtn:CreateTexture(nil, "HIGHLIGHT")
    newHl:SetAllPoints()
    newHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    newHl:SetVertexColor(0.3, 0.3, 0.35, 0.4)

    local newLabel = newBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    newLabel:SetPoint("CENTER")
    newLabel:SetText("|cff888888Reset|r")
    local nlf = newLabel:GetFont()
    if nlf then newLabel:SetFont(nlf, 7, "") end

    newBtn:SetScript("OnClick", function() StartLevel(1) end)

    -- Move score to not overlap with Reset button
    scoreFs:ClearAllPoints()
    scoreFs:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)

    -- Grid frame (anchored to bottom with margin)
    local gridW = COLS * CELL
    local gridH = ROWS * CELL

    gridFrame = CreateFrame("Frame", nil, parent)
    gridFrame:SetSize(gridW, gridH)
    gridFrame:SetPoint("BOTTOM", 0, 10)

    local gridBg = gridFrame:CreateTexture(nil, "BACKGROUND")
    gridBg:SetAllPoints()
    gridBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    gridBg:SetVertexColor(0.04, 0.04, 0.06, 1)

    -- Create cell buttons
    for c = 1, COLS do
        cells[c] = {}
        for r = 1, ROWS do
            local btn = CreateFrame("Button", nil, gridFrame)
            btn:SetSize(CELL - 2, CELL - 2)
            btn:SetPoint("TOPLEFT", (c - 1) * CELL + 1, -((r - 1) * CELL + 1))

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(0.3, 0.3, 0.3, 1)

            local shine = btn:CreateTexture(nil, "ARTWORK")
            shine:SetSize(CELL * 0.5, CELL * 0.5)
            shine:SetPoint("TOPLEFT", 1, -1)
            shine:SetTexture("Interface\\Buttons\\WHITE8x8")
            shine:SetVertexColor(1, 1, 1, 0.3)

            local symbol = btn:CreateTexture(nil, "OVERLAY")
            symbol:SetSize(CELL - 4, CELL - 4)
            symbol:SetPoint("CENTER")

            local border = CreateFrame("Frame", nil, btn)
            border:SetPoint("TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", 1, -1)

            local bTop = border:CreateTexture(nil, "OVERLAY")
            bTop:SetHeight(1)
            bTop:SetPoint("TOPLEFT")
            bTop:SetPoint("TOPRIGHT")
            bTop:SetTexture("Interface\\Buttons\\WHITE8x8")
            bTop:SetVertexColor(1, 1, 1, 0.9)

            local bBot = border:CreateTexture(nil, "OVERLAY")
            bBot:SetHeight(1)
            bBot:SetPoint("BOTTOMLEFT")
            bBot:SetPoint("BOTTOMRIGHT")
            bBot:SetTexture("Interface\\Buttons\\WHITE8x8")
            bBot:SetVertexColor(1, 1, 1, 0.9)

            local bLeft = border:CreateTexture(nil, "OVERLAY")
            bLeft:SetWidth(1)
            bLeft:SetPoint("TOPLEFT")
            bLeft:SetPoint("BOTTOMLEFT")
            bLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
            bLeft:SetVertexColor(1, 1, 1, 0.9)

            local bRight = border:CreateTexture(nil, "OVERLAY")
            bRight:SetWidth(1)
            bRight:SetPoint("TOPRIGHT")
            bRight:SetPoint("BOTTOMRIGHT")
            bRight:SetTexture("Interface\\Buttons\\WHITE8x8")
            bRight:SetVertexColor(1, 1, 1, 0.9)

            border:Hide()

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Buttons\\WHITE8x8")
            hl:SetVertexColor(1, 1, 1, 0.15)

            local cc, rr = c, r
            btn:SetScript("OnClick", function() OnCellClick(cc, rr) end)

            cells[c][r] = {
                btn = btn,
                bg = bg,
                shine = shine,
                symbol = symbol,
                border = border,
            }
        end
    end
end

function PhoneCandyCrushGame:OnShow()
    if not gameActive then
        StartLevel(1)
    end
end

function PhoneCandyCrushGame:OnHide()
end
