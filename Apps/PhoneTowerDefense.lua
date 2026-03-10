-- PhoneTowerDefense - Classic tower defense for HearthPhone

PhoneTowerDefenseGame = {}

local CELL = 16
local COLS = 11
local ROWS = 12
local GRID_W = COLS * CELL
local GRID_H = ROWS * CELL
local MAX_ENEMIES = 40
local MAX_PROJECTILES = 30

-- Forward declarations
local Render

-- State
local gameFrame, cells, hudGold, hudLives, hudWave, msgText
local btnFrame, towerBtns, upgradeBtn, sellBtn, infoText, rangeCircle
local gameRunning = false
local gameover = false

local gold = 0
local lives = 0
local wave = 0
local waveTimer = 0
local waveDelay = 0
local spawnTimer = 0
local enemiesSpawned = 0
local enemiesToSpawn = 0
local enemiesAlive = 0
local selectedTower = nil  -- tower type to place ("arrow","cannon","ice")
local selectedCell = nil   -- {col, row} of clicked tower for upgrade

-- Path waypoints (col, row) - 1-indexed
local PATH = {
    {1, 1}, {10, 1},
    {10, 4}, {2, 4},
    {2, 8}, {10, 8},
    {10, 12},
}

-- Expanded path cells (for rendering and collision)
local pathCells = {}
local pathSegments = {}  -- list of {x1,y1,x2,y2} pixel coords for enemy movement

-- Tower definitions
local TOWERS = {
    arrow = {
        name = "Arrow", cost = 30,
        levels = {
            { damage = 8,  rate = 0.5, range = 3.0, color = {0.2, 0.6, 0.2} },
            { damage = 15, rate = 0.4, range = 3.5, color = {0.3, 0.75, 0.3}, cost = 45 },
            { damage = 25, rate = 0.3, range = 4.0, color = {0.4, 0.9, 0.4}, cost = 70 },
        },
    },
    cannon = {
        name = "Cannon", cost = 50,
        levels = {
            { damage = 20, rate = 1.2, range = 2.8, splash = 1.8, color = {0.7, 0.45, 0.15} },
            { damage = 40, rate = 1.0, range = 3.3, splash = 2.2, color = {0.85, 0.55, 0.2}, cost = 75 },
            { damage = 70, rate = 0.8, range = 3.8, splash = 2.8, color = {1.0, 0.65, 0.25}, cost = 110 },
        },
    },
    ice = {
        name = "Ice", cost = 40,
        levels = {
            { damage = 5,  rate = 0.7, range = 2.8, slow = 0.5, slowDur = 1.5, color = {0.3, 0.5, 0.9} },
            { damage = 10, rate = 0.6, range = 3.2, slow = 0.4, slowDur = 2.0, color = {0.4, 0.6, 1.0}, cost = 60 },
            { damage = 18, rate = 0.5, range = 3.6, slow = 0.3, slowDur = 2.5, color = {0.5, 0.7, 1.0}, cost = 90 },
        },
    },
}

-- Placed towers: key = "col,row", value = {type, level, cooldown}
local towers = {}
local towerLabels = {}  -- key = "col,row", FontString showing level

-- Enemy pool
local enemies = {}
local enemyFrames = {}

-- Projectile pool
local projectiles = {}
local projFrames = {}

-- ============================================================
-- Helpers
-- ============================================================
local floor, max, min, sqrt, abs = math.floor, math.max, math.min, math.sqrt, math.abs
local format = string.format

local function CellKey(c, r) return c .. "," .. r end

local function CellCenter(c, r)
    return (c - 0.5) * CELL, (r - 0.5) * CELL
end

local function Dist(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return sqrt(dx * dx + dy * dy)
end

local function IsPath(c, r)
    return pathCells[CellKey(c, r)] == true
end

-- ============================================================
-- Build path
-- ============================================================
local function BuildPath()
    pathCells = {}
    pathSegments = {}

    for i = 1, #PATH - 1 do
        local c1, r1 = PATH[i][1], PATH[i][2]
        local c2, r2 = PATH[i+1][1], PATH[i+1][2]

        -- Mark cells along this segment
        if c1 == c2 then
            local rMin, rMax = min(r1, r2), max(r1, r2)
            for r = rMin, rMax do
                pathCells[CellKey(c1, r)] = true
            end
        else
            local cMin, cMax = min(c1, c2), max(c1, c2)
            for c = cMin, cMax do
                pathCells[CellKey(c, r1)] = true
            end
        end

        -- Store pixel segment for enemy movement
        local px1, py1 = CellCenter(c1, r1)
        local px2, py2 = CellCenter(c2, r2)
        table.insert(pathSegments, {x1=px1, y1=py1, x2=px2, y2=py2})
    end
end

-- ============================================================
-- Grid rendering
-- ============================================================
local C_BG     = {0.08, 0.08, 0.06, 1}
local C_PATH   = {0.35, 0.30, 0.20, 1}
local C_BUILD  = {0.10, 0.12, 0.08, 1}
local C_SELECT = {0.9, 0.9, 0.3, 1}
local C_START  = {0.15, 0.55, 0.15, 1}
local C_END    = {0.6, 0.15, 0.15, 1}

local function SetCell(c, r, cr, cg, cb, ca)
    local tex = cells[CellKey(c, r)]
    if tex then tex:SetVertexColor(cr, cg, cb, ca or 1) end
end

local function DrawMap()
    for r = 1, ROWS do
        for c = 1, COLS do
            if IsPath(c, r) then
                SetCell(c, r, unpack(C_PATH))
            else
                SetCell(c, r, unpack(C_BUILD))
            end
        end
    end

    -- Hide all tower labels first
    for _, lbl in pairs(towerLabels) do lbl:Hide() end

    -- Draw towers with level numbers
    for key, tower in pairs(towers) do
        local tdef = TOWERS[tower.type]
        local ldef = tdef.levels[tower.level]
        local col = tower.col
        local row = tower.row
        SetCell(col, row, ldef.color[1], ldef.color[2], ldef.color[3], 1)
        -- Level label
        local lbl = towerLabels[key]
        if not lbl then
            lbl = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            do local f2 = lbl:GetFont(); if f2 then lbl:SetFont(f2, 7, "OUTLINE") end end
            towerLabels[key] = lbl
        end
        lbl:ClearAllPoints()
        lbl:SetPoint("CENTER", gameFrame, "TOPLEFT", (col - 0.5) * CELL, -((row - 0.5) * CELL))
        lbl:SetText(tower.level)
        lbl:Show()
    end

    -- Highlight selected cell
    if selectedCell then
        local c, r = selectedCell.col, selectedCell.row
        SetCell(c, r, C_SELECT[1], C_SELECT[2], C_SELECT[3], C_SELECT[4])
    end

    -- Draw path entry/exit markers
    local ec, er = PATH[1][1], PATH[1][2]
    SetCell(ec, er, C_START[1], C_START[2], C_START[3], C_START[4])
    local xc, xr = PATH[#PATH][1], PATH[#PATH][2]
    SetCell(xc, xr, C_END[1], C_END[2], C_END[3], C_END[4])
end

-- ============================================================
-- Enemy system
-- ============================================================
local function SpawnEnemy()
    if #enemies >= MAX_ENEMIES then return end

    local hpBase = 40 + wave * 8 + wave * wave * wave
    local speedBase = 24 + wave * 1.5
    local bounty = 4 + floor(wave / 3)
    local cr, cg, cb = 0.8, 0.2, 0.2  -- red
    local size = 6

    -- Every 5th wave: boss
    if wave % 5 == 0 and enemiesSpawned == 0 then
        hpBase = hpBase * 4
        speedBase = speedBase * 0.6
        bounty = bounty * 3
        cr, cg, cb = 0.6, 0.1, 0.6  -- purple boss
        size = 8
    elseif math.random(100) <= 25 and wave >= 3 then
        -- Fast enemy
        hpBase = hpBase * 0.5
        speedBase = speedBase * 1.6
        bounty = bounty + 2
        cr, cg, cb = 0.9, 0.8, 0.2  -- yellow
        size = 5
    elseif math.random(100) <= 15 and wave >= 5 then
        -- Tank enemy
        hpBase = hpBase * 2.5
        speedBase = speedBase * 0.7
        bounty = bounty + 3
        cr, cg, cb = 0.5, 0.3, 0.7  -- purple
        size = 7
    end

    local startX, startY = CellCenter(PATH[1][1], PATH[1][2])

    table.insert(enemies, {
        x = startX, y = startY,
        hp = floor(hpBase),
        maxHp = floor(hpBase),
        speed = speedBase,
        baseSpeed = speedBase,
        segIdx = 1,       -- current path segment
        segT = 0,         -- progress along current segment (0-1)
        alive = true,
        bounty = bounty,
        cr = cr, cg = cg, cb = cb,
        size = size,
        slowTimer = 0,
        slowFactor = 1,
    })
    enemiesSpawned = enemiesSpawned + 1
    enemiesAlive = enemiesAlive + 1
end

local function MoveEnemy(e, dt)
    if not e.alive then return end

    -- Slow effect
    if e.slowTimer > 0 then
        e.slowTimer = e.slowTimer - dt
        if e.slowTimer <= 0 then
            e.slowFactor = 1
        end
    end

    local speed = e.speed * e.slowFactor

    -- Move along path segments
    local seg = pathSegments[e.segIdx]
    if not seg then
        -- Reached the end
        e.alive = false
        enemiesAlive = enemiesAlive - 1
        lives = lives - 1
        if lives <= 0 then
            gameRunning = false
            gameover = true
            if msgText then
                msgText:SetText("|cffff4444DEFEATED|r\n|cffaaaaaa" .. wave .. " waves|r\n|cff888888Click to start|r")
            end
        end
        return
    end

    local dx = seg.x2 - seg.x1
    local dy = seg.y2 - seg.y1
    local segLen = sqrt(dx * dx + dy * dy)
    if segLen < 0.1 then
        e.segIdx = e.segIdx + 1
        return
    end

    local move = speed * dt / segLen
    e.segT = e.segT + move

    if e.segT >= 1 then
        e.segT = 0
        e.segIdx = e.segIdx + 1
        if e.segIdx <= #pathSegments then
            local nextSeg = pathSegments[e.segIdx]
            e.x = nextSeg.x1
            e.y = nextSeg.y1
        end
    else
        e.x = seg.x1 + dx * e.segT
        e.y = seg.y1 + dy * e.segT
    end
end

-- ============================================================
-- Tower shooting
-- ============================================================
local function FindTarget(tower)
    local tdef = TOWERS[tower.type]
    local ldef = tdef.levels[tower.level]
    local tx, ty = CellCenter(tower.col, tower.row)
    local rangePx = ldef.range * CELL
    local nearest = nil
    local bestProgress = -1

    for _, e in ipairs(enemies) do
        if e.alive and Dist(tx, ty, e.x, e.y) <= rangePx then
            -- Prioritize enemies furthest along the path
            local progress = e.segIdx + e.segT
            if progress > bestProgress then
                bestProgress = progress
                nearest = e
            end
        end
    end
    return nearest
end

local function FireProjectile(tower, target)
    if #projectiles >= MAX_PROJECTILES then return end
    local tx, ty = CellCenter(tower.col, tower.row)
    local tdef = TOWERS[tower.type]
    local ldef = tdef.levels[tower.level]

    table.insert(projectiles, {
        x = tx, y = ty,
        targetX = target.x, targetY = target.y,
        target = target,
        speed = 120,
        damage = ldef.damage,
        splash = ldef.splash or 0,
        slow = ldef.slow or 0,
        slowDur = ldef.slowDur or 0,
        alive = true,
        towerType = tower.type,
    })
end

local function UpdateTowers(dt)
    for _, tower in pairs(towers) do
        tower.cooldown = tower.cooldown - dt
        if tower.cooldown <= 0 then
            local target = FindTarget(tower)
            if target then
                FireProjectile(tower, target)
                local tdef = TOWERS[tower.type]
                local ldef = tdef.levels[tower.level]
                tower.cooldown = ldef.rate
            else
                tower.cooldown = 0.1  -- check again soon
            end
        end
    end
end

local function UpdateProjectiles(dt)
    for _, p in ipairs(projectiles) do
        if p.alive then
            -- Move toward target's current position (homing)
            if p.target and p.target.alive then
                p.targetX = p.target.x
                p.targetY = p.target.y
            end
            local dx = p.targetX - p.x
            local dy = p.targetY - p.y
            local d = sqrt(dx * dx + dy * dy)
            if d < 3 then
                -- Hit!
                p.alive = false
                -- Apply damage
                if p.splash > 0 then
                    local splashPx = p.splash * CELL
                    for _, e in ipairs(enemies) do
                        if e.alive and Dist(p.x, p.y, e.x, e.y) <= splashPx then
                            e.hp = e.hp - p.damage
                            if e.hp <= 0 then
                                e.alive = false
                                enemiesAlive = enemiesAlive - 1
                                gold = gold + e.bounty
                            end
                        end
                    end
                else
                    if p.target and p.target.alive then
                        p.target.hp = p.target.hp - p.damage
                        -- Apply slow
                        if p.slow > 0 then
                            p.target.slowFactor = p.slow
                            p.target.slowTimer = p.slowDur
                        end
                        if p.target.hp <= 0 then
                            p.target.alive = false
                            enemiesAlive = enemiesAlive - 1
                            gold = gold + p.target.bounty
                        end
                    end
                end
            else
                local step = p.speed * dt / d
                p.x = p.x + dx * step
                p.y = p.y + dy * step
            end
        end
    end
end

-- ============================================================
-- Wave system
-- ============================================================
local function StartWave()
    wave = wave + 1
    enemiesToSpawn = 6 + wave * 3
    if enemiesToSpawn > 40 then enemiesToSpawn = 40 end
    enemiesSpawned = 0
    spawnTimer = 0
    waveDelay = 2.0
    if msgText then
        msgText:SetText("|cffff8844Wave " .. wave .. "|r")
    end
end

-- ============================================================
-- UI: tower buttons, selection
-- ============================================================
local function UpdateInfoText()
    if not infoText then return end
    if selectedCell then
        local key = CellKey(selectedCell.col, selectedCell.row)
        local tower = towers[key]
        if tower then
            local tdef = TOWERS[tower.type]
            local ldef = tdef.levels[tower.level]
            local txt = format("%s Lv%d", tdef.name, tower.level)
            if tower.level < 3 then
                local nextCost = tdef.levels[tower.level + 1].cost
                txt = txt .. format("  Up:%d", nextCost)
            else
                txt = txt .. " (MAX)"
            end
            local sellValue = floor(tdef.cost * 0.6)
            for i = 2, tower.level do
                sellValue = sellValue + floor(tdef.levels[i].cost * 0.6)
            end
            txt = txt .. format("  Sell:%d", sellValue)
            infoText:SetText("|cffffd700" .. txt .. "|r")
            if upgradeBtn then
                if tower.level < 3 then
                    local nextCost = tdef.levels[tower.level + 1].cost
                    upgradeBtn.text:SetText("Up " .. nextCost)
                    upgradeBtn:Show()
                else
                    upgradeBtn:Hide()
                end
            end
            if sellBtn then sellBtn:Show() end
            -- Show range circle
            if rangeCircle then
                local cx, cy = CellCenter(selectedCell.col, selectedCell.row)
                local rangePx = ldef.range * CELL
                rangeCircle:ClearAllPoints()
                rangeCircle:SetSize(rangePx * 2, rangePx * 2)
                rangeCircle:SetPoint("CENTER", gameFrame, "TOPLEFT", cx, -cy)
                rangeCircle:Show()
            end
            return
        end
    end
    if selectedTower then
        local tdef = TOWERS[selectedTower]
        infoText:SetText("|cff88ccff" .. tdef.name .. " - " .. tdef.cost .. "g|r")
    else
        infoText:SetText("")
    end
    if upgradeBtn then upgradeBtn:Hide() end
    if sellBtn then sellBtn:Hide() end
    if rangeCircle then rangeCircle:Hide() end
end

local function DeselectAll()
    selectedTower = nil
    selectedCell = nil
    for _, btn in ipairs(towerBtns) do
        btn:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.6)
    end
    UpdateInfoText()
end

local function PlaceTower(c, r, towerType)
    if IsPath(c, r) then return false end
    local key = CellKey(c, r)
    if towers[key] then return false end
    local tdef = TOWERS[towerType]
    if gold < tdef.cost then return false end
    gold = gold - tdef.cost
    towers[key] = {
        type = towerType,
        level = 1,
        cooldown = 0,
        col = c,
        row = r,
    }
    return true
end

local function UpgradeTower(c, r)
    local key = CellKey(c, r)
    local tower = towers[key]
    if not tower then return false end
    if tower.level >= 3 then return false end
    local nextLevel = tower.level + 1
    local tdef = TOWERS[tower.type]
    local cost = tdef.levels[nextLevel].cost
    if gold < cost then return false end
    gold = gold - cost
    tower.level = nextLevel
    return true
end

local function SellTower(c, r)
    local key = CellKey(c, r)
    local tower = towers[key]
    if not tower then return false end
    local tdef = TOWERS[tower.type]
    local refund = floor(tdef.cost * 0.6)
    for i = 2, tower.level do
        refund = refund + floor(tdef.levels[i].cost * 0.6)
    end
    gold = gold + refund
    towers[key] = nil
    if towerLabels[key] then towerLabels[key]:Hide() end
    return true
end

-- ============================================================
-- Game start/reset
-- ============================================================
local function StartGame()
    gold = 100
    lives = 20
    wave = 0
    towers = {}
    enemies = {}
    projectiles = {}
    enemiesAlive = 0
    gameover = false
    gameRunning = true
    selectedTower = nil
    selectedCell = nil
    StartWave()
end

-- ============================================================
-- Game tick
-- ============================================================
local function Tick(dt)
    if not gameRunning then return end
    dt = min(dt, 0.05)

    -- Wave delay
    if waveDelay > 0 then
        waveDelay = waveDelay - dt
        if waveDelay <= 0 and msgText then
            msgText:SetText("")
        end
    end

    -- Spawning
    if enemiesSpawned < enemiesToSpawn and waveDelay <= 0 then
        local interval = max(0.3, 0.8 - wave * 0.02)
        spawnTimer = spawnTimer + dt
        if spawnTimer >= interval then
            spawnTimer = spawnTimer - interval
            SpawnEnemy()
        end
    end

    -- Move enemies
    for _, e in ipairs(enemies) do
        if e.alive then MoveEnemy(e, dt) end
    end

    -- Tower shooting
    UpdateTowers(dt)

    -- Move projectiles
    UpdateProjectiles(dt)

    -- Clean up dead
    local kept = {}
    for _, e in ipairs(enemies) do
        if e.alive then table.insert(kept, e) end
    end
    enemies = kept

    local keptP = {}
    for _, p in ipairs(projectiles) do
        if p.alive then table.insert(keptP, p) end
    end
    projectiles = keptP

    -- Wave complete?
    if enemiesAlive <= 0 and enemiesSpawned >= enemiesToSpawn and waveDelay <= 0 then
        -- Bonus gold between waves
        gold = gold + 5 + floor(wave * 0.5)
        StartWave()
    end

    -- Render
    Render()
end

-- ============================================================
-- Rendering
-- ============================================================
Render = function()
    DrawMap()

    -- Enemies
    for i = 1, MAX_ENEMIES do
        local ef = enemyFrames[i]
        local e = enemies[i]
        if e and e.alive then
            ef:ClearAllPoints()
            ef:SetPoint("CENTER", gameFrame, "TOPLEFT", e.x, -e.y)
            ef:SetSize(e.size, e.size)
            ef.tex:SetVertexColor(e.cr, e.cg, e.cb, 1)
            -- Flash blue if slowed
            if e.slowTimer > 0 then
                ef.tex:SetVertexColor(0.4, 0.5, 1.0, 1)
            end
            ef:Show()
            -- Health bar
            if ef.hpBg and e.hp < e.maxHp then
                ef.hpBg:Show()
                ef.hpBar:Show()
                local pct = max(0, e.hp / e.maxHp)
                ef.hpBar:SetWidth(max(0.1, e.size * pct))
                if pct > 0.5 then
                    ef.hpBar:SetVertexColor(0.2, 0.8, 0.2, 1)
                elseif pct > 0.25 then
                    ef.hpBar:SetVertexColor(0.9, 0.7, 0.1, 1)
                else
                    ef.hpBar:SetVertexColor(0.9, 0.2, 0.1, 1)
                end
            else
                if ef.hpBg then ef.hpBg:Hide() end
                if ef.hpBar then ef.hpBar:Hide() end
            end
        else
            ef:Hide()
        end
    end

    -- Projectiles
    for i = 1, MAX_PROJECTILES do
        local pf = projFrames[i]
        local p = projectiles[i]
        if p and p.alive then
            pf:ClearAllPoints()
            pf:SetPoint("CENTER", gameFrame, "TOPLEFT", p.x, -p.y)
            -- Color by tower type
            if p.towerType == "arrow" then
                pf.tex:SetVertexColor(0.9, 0.9, 0.5, 1)
            elseif p.towerType == "cannon" then
                pf.tex:SetVertexColor(1.0, 0.5, 0.1, 1)
            else
                pf.tex:SetVertexColor(0.5, 0.7, 1.0, 1)
            end
            pf:Show()
        else
            pf:Hide()
        end
    end

    -- HUD
    if hudGold then hudGold:SetText(format("|cffffd700%dg|r", gold)) end
    if hudLives then hudLives:SetText(format("|cffff4444%d|r HP", lives)) end
    if hudWave then hudWave:SetText(format("W:|cff88ff88%d|r", wave)) end
    UpdateInfoText()
end

-- ============================================================
-- Init
-- ============================================================
function PhoneTowerDefenseGame:Init(parentFrame)
    if gameFrame then return end

    BuildPath()

    -- Game grid frame
    gameFrame = CreateFrame("Frame", nil, parentFrame)
    gameFrame:SetSize(GRID_W, GRID_H)
    gameFrame:SetPoint("TOP", 0, -12)

    local bg = gameFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.08, 0.08, 0.06, 1)

    -- Grid cells
    cells = {}
    for r = 1, ROWS do
        for c = 1, COLS do
            local tex = gameFrame:CreateTexture(nil, "ARTWORK")
            tex:SetSize(CELL - 1, CELL - 1)
            tex:SetPoint("TOPLEFT", (c - 1) * CELL, -((r - 1) * CELL))
            tex:SetTexture("Interface\\Buttons\\WHITE8x8")
            cells[CellKey(c, r)] = tex
        end
    end

    -- HUD bar: Gold | Wave | HP | Reset  (4 even columns)
    local hudW = floor(GRID_W / 4)

    hudGold = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hudGold:SetPoint("TOPLEFT", 4, -2)
    hudGold:SetWidth(hudW)
    hudGold:SetJustifyH("LEFT")
    do local f = hudGold:GetFont(); if f then hudGold:SetFont(f, 8, "OUTLINE") end end

    hudWave = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hudWave:SetPoint("TOPLEFT", hudW, -2)
    hudWave:SetWidth(hudW)
    hudWave:SetJustifyH("CENTER")
    do local f = hudWave:GetFont(); if f then hudWave:SetFont(f, 8, "OUTLINE") end end

    hudLives = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hudLives:SetPoint("TOPLEFT", hudW * 2, -2)
    hudLives:SetWidth(hudW)
    hudLives:SetJustifyH("CENTER")
    do local f = hudLives:GetFont(); if f then hudLives:SetFont(f, 8, "OUTLINE") end end

    -- Restart button in 4th column (float right)
    local restartBtn = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
    restartBtn:SetSize(30, 10)
    restartBtn:SetPoint("TOPRIGHT", -2, -2)
    restartBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    restartBtn:SetBackdropColor(0.4, 0.12, 0.12, 0.9)
    restartBtn:SetBackdropBorderColor(0.5, 0.2, 0.2, 0.8)
    local restartLabel = restartBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    restartLabel:SetPoint("CENTER", 0, 0)
    do local f2 = restartLabel:GetFont(); if f2 then restartLabel:SetFont(f2, 6, "OUTLINE") end end
    restartLabel:SetText("Reset")
    restartBtn:SetScript("OnClick", function()
        StartGame()
    end)

    -- Center message
    local msgOverlay = CreateFrame("Frame", nil, gameFrame)
    msgOverlay:SetAllPoints()
    msgOverlay:SetFrameLevel(gameFrame:GetFrameLevel() + 10)
    msgText = msgOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgText:SetPoint("CENTER", 0, 20)
    do local f = msgText:GetFont(); if f then msgText:SetFont(f, 10, "OUTLINE") end end
    msgText:SetText("|cff88ccffTOWER DEFENSE|r\n|cff888888Click to start|r")

    -- Range circle for selected tower
    rangeCircle = gameFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    rangeCircle:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    rangeCircle:SetVertexColor(1, 1, 0.5, 0.15)
    rangeCircle:Hide()

    -- ============================================================
    -- Bottom panel (always visible grey box)
    -- ============================================================
    btnFrame = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    btnFrame:SetSize(GRID_W, 60)
    btnFrame:SetPoint("TOP", gameFrame, "BOTTOM", 0, -2)
    btnFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btnFrame:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    btnFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)

    -- Tower buy buttons (top row of panel)
    towerBtns = {}
    local towerOrder = {"arrow", "cannon", "ice"}
    local btnColors = {
        arrow = {0.2, 0.6, 0.2},
        cannon = {0.7, 0.45, 0.15},
        ice = {0.3, 0.5, 0.9},
    }
    local numBtns = #towerOrder
    local padding = 6
    local btnGap = 4
    local totalGap = padding * 2 + btnGap * (numBtns - 1)
    local btnW = floor((GRID_W - totalGap) / numBtns)
    for i, ttype in ipairs(towerOrder) do
        local tdef = TOWERS[ttype]
        local btn = CreateFrame("Button", nil, btnFrame, "BackdropTemplate")
        btn:SetSize(btnW, 18)
        btn:SetPoint("TOPLEFT", padding + (i - 1) * (btnW + btnGap), -4)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        local bc = btnColors[ttype]
        btn:SetBackdropColor(bc[1] * 0.4, bc[2] * 0.4, bc[3] * 0.4, 0.9)
        btn:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.6)
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        do local f2 = label:GetFont(); if f2 then label:SetFont(f2, 7, "OUTLINE") end end
        label:SetText(tdef.name .. " " .. tdef.cost)
        btn.towerType = ttype
        btn:SetScript("OnClick", function()
            if not gameRunning then return end
            selectedCell = nil
            if selectedTower == ttype then
                DeselectAll()
            else
                DeselectAll()
                selectedTower = ttype
                btn:SetBackdropBorderColor(1, 1, 0.5, 1)
                UpdateInfoText()
            end
        end)
        towerBtns[i] = btn
    end

    -- Info text (bottom row of panel, left side)
    infoText = btnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("TOPLEFT", 6, -26)
    infoText:SetWidth(GRID_W - 12)
    infoText:SetJustifyH("LEFT")
    do local f = infoText:GetFont(); if f then infoText:SetFont(f, 7, "OUTLINE") end end

    -- Upgrade button (bottom row, right side)
    upgradeBtn = CreateFrame("Button", nil, btnFrame, "BackdropTemplate")
    upgradeBtn:SetSize(50, 18)
    upgradeBtn:SetPoint("BOTTOMRIGHT", -4, 4)
    upgradeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    upgradeBtn:SetBackdropColor(0.15, 0.35, 0.15, 0.9)
    upgradeBtn:SetBackdropBorderColor(0.3, 0.5, 0.3, 0.8)
    upgradeBtn.text = upgradeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    upgradeBtn.text:SetPoint("CENTER")
    do local f2 = upgradeBtn.text:GetFont(); if f2 then upgradeBtn.text:SetFont(f2, 7, "OUTLINE") end end
    upgradeBtn:SetScript("OnClick", function()
        if selectedCell then
            if UpgradeTower(selectedCell.col, selectedCell.row) then
                UpdateInfoText()
            end
        end
    end)
    upgradeBtn:Hide()

    -- Sell button (bottom row, next to upgrade)
    sellBtn = CreateFrame("Button", nil, btnFrame, "BackdropTemplate")
    sellBtn:SetSize(40, 18)
    sellBtn:SetPoint("RIGHT", upgradeBtn, "LEFT", -4, 0)
    sellBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    sellBtn:SetBackdropColor(0.35, 0.15, 0.15, 0.9)
    sellBtn:SetBackdropBorderColor(0.5, 0.3, 0.3, 0.8)
    local sellLabel = sellBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sellLabel:SetPoint("CENTER")
    do local f2 = sellLabel:GetFont(); if f2 then sellLabel:SetFont(f2, 7, "OUTLINE") end end
    sellLabel:SetText("Sell")
    sellBtn:SetScript("OnClick", function()
        if selectedCell then
            if SellTower(selectedCell.col, selectedCell.row) then
                DeselectAll()
            end
        end
    end)
    sellBtn:Hide()

    -- Click on grid to place/select tower
    gameFrame:EnableMouse(true)
    gameFrame:SetScript("OnMouseDown", function(_, button)
        if not gameRunning then StartGame() return end

        local mx, my = GetCursorPosition()
        local scale = gameFrame:GetEffectiveScale()
        mx, my = mx / scale, my / scale
        local left = gameFrame:GetLeft()
        local top = gameFrame:GetTop()
        local localX = mx - left
        local localY = top - my
        local col = floor(localX / CELL) + 1
        local row = floor(localY / CELL) + 1

        if col < 1 or col > COLS or row < 1 or row > ROWS then return end

        local key = CellKey(col, row)

        if button == "RightButton" then
            -- Right-click: select existing tower for upgrade/sell
            if towers[key] then
                selectedTower = nil
                for _, btn in ipairs(towerBtns) do
                    btn:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.6)
                end
                selectedCell = { col = col, row = row }
                UpdateInfoText()
            else
                DeselectAll()
            end
            return
        end

        -- Left-click on existing tower: always select it (even if buy mode active)
        if towers[key] then
            selectedTower = nil
            for _, btn in ipairs(towerBtns) do
                btn:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.6)
            end
            selectedCell = { col = col, row = row }
            UpdateInfoText()
            return
        end

        -- Left-click empty cell: place if buy mode, otherwise deselect
        if selectedTower then
            PlaceTower(col, row, selectedTower)
        else
            DeselectAll()
        end
    end)

    -- Enemy sprite pool
    for i = 1, MAX_ENEMIES do
        local ef = CreateFrame("Frame", nil, gameFrame)
        ef:SetSize(6, 6)
        ef:SetFrameLevel(gameFrame:GetFrameLevel() + 2)
        local t = ef:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        ef.tex = t
        -- HP bar background
        local hpBg = ef:CreateTexture(nil, "OVERLAY")
        hpBg:SetSize(8, 2)
        hpBg:SetPoint("BOTTOM", ef, "TOP", 0, 1)
        hpBg:SetTexture("Interface\\Buttons\\WHITE8x8")
        hpBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
        ef.hpBg = hpBg
        hpBg:Hide()
        -- HP bar fill
        local hpBar = ef:CreateTexture(nil, "OVERLAY", nil, 1)
        hpBar:SetSize(8, 2)
        hpBar:SetPoint("LEFT", hpBg, "LEFT")
        hpBar:SetTexture("Interface\\Buttons\\WHITE8x8")
        hpBar:SetVertexColor(0.2, 0.8, 0.2, 1)
        ef.hpBar = hpBar
        hpBar:Hide()
        ef:Hide()
        enemyFrames[i] = ef
    end

    -- Projectile pool
    for i = 1, MAX_PROJECTILES do
        local pf = CreateFrame("Frame", nil, gameFrame)
        pf:SetSize(3, 3)
        pf:SetFrameLevel(gameFrame:GetFrameLevel() + 3)
        local t = pf:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetTexture("Interface\\Buttons\\WHITE8x8")
        pf.tex = t
        pf:Hide()
        projFrames[i] = pf
    end

    -- Keyboard for start/restart
    local keyFrame = CreateFrame("Frame", "PhoneTDKeyFrame", parentFrame)
    keyFrame:SetAllPoints(parentFrame)
    keyFrame:EnableKeyboard(false)
    keyFrame:SetPropagateKeyboardInput(true)
    keyFrame:SetScript("OnKeyDown", function(kf, key)
        if key == "ESCAPE" then
            kf:SetPropagateKeyboardInput(true)
            if gameRunning then DeselectAll() end
            return
        end
        if not gameRunning then
            kf:SetPropagateKeyboardInput(false)
            StartGame()
            return
        end
        kf:SetPropagateKeyboardInput(true)
    end)
    PhoneTowerDefenseGame.keyFrame = keyFrame

    -- Game loop
    gameFrame:SetScript("OnUpdate", function(_, dt)
        Tick(dt)
    end)
end

function PhoneTowerDefenseGame:OnShow()
    if PhoneTowerDefenseGame.keyFrame then
        PhoneTowerDefenseGame.keyFrame:EnableKeyboard(true)
        PhoneTowerDefenseGame.keyFrame:SetPropagateKeyboardInput(true)
    end
    if not gameRunning and not gameover then
        if msgText then
            msgText:SetText("|cff88ccffTOWER DEFENSE|r\n|cff888888Click to start|r")
        end
    end
end

function PhoneTowerDefenseGame:OnHide()
    if PhoneTowerDefenseGame.keyFrame then
        PhoneTowerDefenseGame.keyFrame:EnableKeyboard(false)
        PhoneTowerDefenseGame.keyFrame:SetPropagateKeyboardInput(true)
    end
    DeselectAll()
end
