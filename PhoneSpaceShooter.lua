-- PhoneSpaceShooter - Space Invaders style game for HearthPhone

PhoneSpaceShooterGame = {}

local CELL = 8
local GRID_W = 18
local GRID_H = 26
local SPRITE_PATH = "Interface\\AddOns\\HearthPhone\\Textures\\"

local gameFrame, scoreText, msgText, livesText
local cells = {}
local gameRunning = false
local gameover = false
local score = 0
local lives = 3
local level = 1

-- Animation
local animFrame = 0
local animTimer = 0
local ANIM_RATE = 0.5

-- Player
local playerX = 9
local playerBullets = {}
local shootCooldown = 0
local SHOOT_CD = 0.28

-- Sprites
local shipSprite
local alienPool = {}
local MAX_ALIEN_SPRITES = 40
local explosionPool = {}
local MAX_EXPLOSIONS = 8

-- Aliens
local aliens = {}
local alienDir = 1
local alienMoveTimer = 0
local alienBullets = {}
local alienShootTimer = 0

-- Explosions
local explosions = {}

-- Input
local holdLeft = false
local holdRight = false
local holdShoot = false
local moveCooldown = 0
local MOVE_CD = 0.055

-- Bullet timers
local bulletTimer = 0
local BULLET_TICK = 0.035
local alienBulletTimer = 0
local ALIEN_BULLET_TICK = 0.055

-- Stars
local stars = {}

-- Colors (grid elements only)
local C_BG    = { 0.03, 0.03, 0.07, 1 }
local C_GRID  = { 0.05, 0.05, 0.09, 1 }
local C_BULLET = { 1, 1, 0.4, 1 }
local C_ABULL = { 1, 0.25, 0.25, 1 }

-- ============================================================
-- Helpers
-- ============================================================
local function SetCell(x, y, r, g, b, a)
    if x < 1 or x > GRID_W or y < 1 or y > GRID_H then return end
    local tex = cells[x .. "," .. y]
    if tex then tex:SetVertexColor(r, g, b, a or 1) end
end

local function ClearGrid()
    for _, tex in pairs(cells) do
        tex:SetVertexColor(unpack(C_GRID))
    end
end

local function InitStars()
    stars = {}
    for _ = 1, 25 do
        table.insert(stars, {
            x = math.random(1, GRID_W),
            y = math.random(1, GRID_H),
            b = math.random(8, 18) / 100,
        })
    end
end

local function DrawStars()
    for _, s in ipairs(stars) do
        SetCell(s.x, s.y, s.b, s.b, s.b * 0.8, 1)
    end
end

-- Grid coord to pixel offset from gameFrame TOPLEFT
local function GridToPixel(gx, gy)
    return (gx - 1) * CELL + CELL / 2, -((gy - 1) * CELL + CELL / 2)
end

-- Bounding box collision
local function PointHitsAlien(px, py, alien)
    return px >= alien.x - 1 and px <= alien.x + 1
       and py >= alien.y - 1 and py <= alien.y + 1
end

local function PointHitsShip(px, py)
    return py >= GRID_H - 2 and py <= GRID_H
       and px >= playerX - 2 and px <= playerX + 2
end

local function AlienBoundsX()
    local minX, maxX = GRID_W + 1, 0
    for _, a in ipairs(aliens) do
        if a.alive then
            if a.x - 1 < minX then minX = a.x - 1 end
            if a.x + 1 > maxX then maxX = a.x + 1 end
        end
    end
    return minX, maxX
end

local function AlienMaxY()
    local maxY = 0
    for _, a in ipairs(aliens) do
        if a.alive then
            if a.y + 1 > maxY then maxY = a.y + 1 end
        end
    end
    return maxY
end

-- ============================================================
-- Sprite Management
-- ============================================================
local function HideAllSprites()
    if shipSprite then shipSprite:Hide() end
    for _, s in ipairs(alienPool) do s:Hide() end
    for _, e in ipairs(explosionPool) do e:Hide() end
end

local function GetAlienTexture(row)
    local typeIdx = ((row - 1) % 3) + 1
    local suffix = animFrame == 0 and "a" or "b"
    return SPRITE_PATH .. "SpriteAlien" .. typeIdx .. suffix
end

local function UpdateSprites()
    if not shipSprite then return end

    -- Ship
    if gameRunning and lives > 0 then
        local sx, sy = GridToPixel(playerX, GRID_H - 1)
        shipSprite:ClearAllPoints()
        shipSprite:SetPoint("CENTER", gameFrame, "TOPLEFT", sx, sy)
        shipSprite:Show()
    else
        shipSprite:Hide()
    end

    -- Aliens
    local idx = 0
    for _, a in ipairs(aliens) do
        if a.alive then
            idx = idx + 1
            if idx <= MAX_ALIEN_SPRITES then
                local af = alienPool[idx]
                af.tex:SetTexture(GetAlienTexture(a.row))
                local ax, ay = GridToPixel(a.x, a.y)
                af:ClearAllPoints()
                af:SetPoint("CENTER", gameFrame, "TOPLEFT", ax, ay)
                af:Show()
            end
        end
    end
    for i = idx + 1, MAX_ALIEN_SPRITES do
        alienPool[i]:Hide()
    end

    -- Explosions
    local eIdx = 0
    for _, e in ipairs(explosions) do
        eIdx = eIdx + 1
        if eIdx <= MAX_EXPLOSIONS then
            local ef = explosionPool[eIdx]
            local ex, ey = GridToPixel(e.x, e.y)
            ef:ClearAllPoints()
            ef:SetPoint("CENTER", gameFrame, "TOPLEFT", ex, ey)
            ef:Show()
        end
    end
    for i = eIdx + 1, MAX_EXPLOSIONS do
        explosionPool[i]:Hide()
    end
end

-- ============================================================
-- Spawning
-- ============================================================
local function SpawnAliens()
    aliens = {}
    local cols = math.min(5 + math.floor(level / 3), 6)
    local rows = math.min(3 + math.floor(level / 2), 5)
    local spacing = 3
    local totalW = (cols - 1) * spacing
    local startX = math.floor((GRID_W - totalW) / 2) + 1
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            table.insert(aliens, {
                x = startX + col * spacing,
                y = 3 + row * 3,
                alive = true,
                row = row + 1,
            })
        end
    end
    alienDir = 1
    alienMoveTimer = 0
    alienShootTimer = 0
    alienBullets = {}
end

local function AliveCount()
    local n = 0
    for _, a in ipairs(aliens) do
        if a.alive then n = n + 1 end
    end
    return n
end

local function GetAlienSpeed()
    local alive = AliveCount()
    local total = math.max(#aliens, 1)
    local base = 0.45 - (level - 1) * 0.025
    if base < 0.12 then base = 0.12 end
    local ratio = alive / total
    return base * (0.3 + ratio * 0.7)
end

-- ============================================================
-- Drawing
-- ============================================================
local function DrawGame()
    ClearGrid()
    DrawStars()

    -- Player bullets (grid cells with trail)
    for _, b in ipairs(playerBullets) do
        SetCell(b.x, b.y, unpack(C_BULLET))
        SetCell(b.x, b.y + 1, C_BULLET[1] * 0.4, C_BULLET[2] * 0.4, C_BULLET[3] * 0.4, 0.6)
    end

    -- Alien bullets (grid cells with trail)
    for _, b in ipairs(alienBullets) do
        SetCell(b.x, b.y, unpack(C_ABULL))
        SetCell(b.x, b.y - 1, C_ABULL[1] * 0.4, C_ABULL[2] * 0.4, C_ABULL[3] * 0.4, 0.6)
    end

    -- Sprite overlays
    UpdateSprites()

    scoreText:SetText(format("Score:|cffffd700%d|r Lv:|cff88ff88%d|r", score, level))
    local lstr = ""
    for _ = 1, lives do lstr = lstr .. "|cff44ccff^|r" end
    livesText:SetText(lstr)
end

-- ============================================================
-- Game Logic
-- ============================================================
local function AddExplosion(x, y)
    table.insert(explosions, { x = x, y = y, t = 0.3 })
end

local function PlayerHit()
    lives = lives - 1
    AddExplosion(playerX, GRID_H - 1)
    playerBullets = {}
    alienBullets = {}
    if lives <= 0 then
        gameRunning = false
        gameover = true
        DrawGame()
        HideAllSprites()
        msgText:SetText("|cffff4444GAME OVER|r\n|cffaaaaaa" .. score .. " pts|r\nPress any key")
    end
end

local function NextLevel()
    level = level + 1
    playerBullets = {}
    alienBullets = {}
    explosions = {}
    SpawnAliens()
end

local function StartGame()
    score = 0
    lives = 3
    level = 1
    playerX = math.floor(GRID_W / 2)
    playerBullets = {}
    alienBullets = {}
    explosions = {}
    shootCooldown = 0
    moveCooldown = 0
    bulletTimer = 0
    alienBulletTimer = 0
    animFrame = 0
    animTimer = 0
    gameover = false
    gameRunning = true
    holdLeft = false
    holdRight = false
    holdShoot = false
    InitStars()
    SpawnAliens()
    DrawGame()
    msgText:SetText("")
end

local function Tick(dt)
    if not gameRunning then return end

    -- Animation toggle
    animTimer = animTimer + dt
    if animTimer >= ANIM_RATE then
        animTimer = animTimer - ANIM_RATE
        animFrame = 1 - animFrame
    end

    -- Fade explosions
    local newExp = {}
    for _, e in ipairs(explosions) do
        e.t = e.t - dt
        if e.t > 0 then table.insert(newExp, e) end
    end
    explosions = newExp

    -- Player movement
    moveCooldown = moveCooldown - dt
    if moveCooldown <= 0 then
        if holdLeft and playerX > 3 then
            playerX = playerX - 1
            moveCooldown = MOVE_CD
        elseif holdRight and playerX < GRID_W - 2 then
            playerX = playerX + 1
            moveCooldown = MOVE_CD
        end
    end

    -- Player shooting
    shootCooldown = shootCooldown - dt
    if holdShoot and shootCooldown <= 0 then
        table.insert(playerBullets, { x = playerX, y = GRID_H - 3 })
        shootCooldown = SHOOT_CD
        PlaySound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115, "SFX")
    end

    -- Move player bullets
    bulletTimer = bulletTimer + dt
    if bulletTimer >= BULLET_TICK then
        bulletTimer = bulletTimer - BULLET_TICK
        local kept = {}
        for _, b in ipairs(playerBullets) do
            b.y = b.y - 1
            if b.y >= 1 then
                local hit = false
                for _, a in ipairs(aliens) do
                    if a.alive and PointHitsAlien(b.x, b.y, a) then
                        a.alive = false
                        hit = true
                        score = score + 10 + math.max(0, 6 - a.row) * 5
                        AddExplosion(a.x, a.y)
                        break
                    end
                end
                if not hit then table.insert(kept, b) end
            end
        end
        playerBullets = kept
    end

    -- Alien movement
    alienMoveTimer = alienMoveTimer + dt
    local alienSpeed = GetAlienSpeed()
    if alienMoveTimer >= alienSpeed then
        alienMoveTimer = alienMoveTimer - alienSpeed

        local minX, maxX = AlienBoundsX()
        local needDrop = false
        if alienDir == 1 and maxX + 1 > GRID_W then
            needDrop = true
        elseif alienDir == -1 and minX - 1 < 1 then
            needDrop = true
        end

        if needDrop then
            alienDir = -alienDir
            for _, a in ipairs(aliens) do
                if a.alive then a.y = a.y + 1 end
            end
            if AlienMaxY() >= GRID_H - 3 then
                PlayerHit()
                if not gameRunning then return end
                for _, a in ipairs(aliens) do
                    if a.alive then a.y = a.y - 5 end
                    if a.y < 1 then a.y = 1 end
                end
            end
        else
            for _, a in ipairs(aliens) do
                if a.alive then a.x = a.x + alienDir end
            end
        end
    end

    -- Alien shooting
    alienShootTimer = alienShootTimer + dt
    local shootRate = 1.2 - (level - 1) * 0.08
    if shootRate < 0.3 then shootRate = 0.3 end
    if alienShootTimer >= shootRate then
        alienShootTimer = alienShootTimer - shootRate
        local shooters = {}
        for _, a in ipairs(aliens) do
            if a.alive then table.insert(shooters, a) end
        end
        if #shooters > 0 then
            local s = shooters[math.random(#shooters)]
            table.insert(alienBullets, { x = s.x, y = s.y + 2 })
        end
    end

    -- Move alien bullets
    alienBulletTimer = alienBulletTimer + dt
    if alienBulletTimer >= ALIEN_BULLET_TICK then
        alienBulletTimer = alienBulletTimer - ALIEN_BULLET_TICK
        local kept = {}
        for _, b in ipairs(alienBullets) do
            b.y = b.y + 1
            if b.y <= GRID_H then
                if PointHitsShip(b.x, b.y) then
                    PlayerHit()
                    if not gameRunning then return end
                else
                    table.insert(kept, b)
                end
            end
        end
        alienBullets = kept
    end

    -- Level complete?
    if AliveCount() == 0 then
        NextLevel()
    end

    DrawGame()
end

-- ============================================================
-- Input
-- ============================================================
local function HandleKeyDown(key)
    if gameover or not gameRunning then
        StartGame()
        return
    end
    if key == "A" or key == "LEFT" then holdLeft = true
    elseif key == "D" or key == "RIGHT" then holdRight = true
    elseif key == "W" or key == "UP" or key == "SPACE" then holdShoot = true
    end
end

local function HandleKeyUp(key)
    if key == "A" or key == "LEFT" then holdLeft = false
    elseif key == "D" or key == "RIGHT" then holdRight = false
    elseif key == "W" or key == "UP" or key == "SPACE" then holdShoot = false
    end
end

-- ============================================================
-- Init
-- ============================================================
function PhoneSpaceShooterGame:Init(parentFrame)
    if gameFrame then return end

    local gridPxW = GRID_W * CELL
    local gridPxH = GRID_H * CELL

    -- Score
    scoreText = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreText:SetPoint("TOPLEFT", 4, -2)
    local sf = scoreText:GetFont()
    if sf then scoreText:SetFont(sf, 8, "OUTLINE") end
    scoreText:SetText("Score:|cffffd7000|r Lv:|cff88ff881|r")

    -- Lives
    livesText = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    livesText:SetPoint("TOPRIGHT", -4, -2)
    local lf = livesText:GetFont()
    if lf then livesText:SetFont(lf, 8, "OUTLINE") end
    livesText:SetText("|cff44ccff^|r|cff44ccff^|r|cff44ccff^|r")

    -- Game frame
    gameFrame = CreateFrame("Frame", nil, parentFrame)
    gameFrame:SetSize(gridPxW + 2, gridPxH + 2)
    gameFrame:SetPoint("TOP", 0, -14)

    local border = gameFrame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.12, 0.12, 0.3, 0.5)

    local bg = gameFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(unpack(C_BG))

    -- Grid cells (for stars, bullets, and effects)
    for gx = 1, GRID_W do
        for gy = 1, GRID_H do
            local tex = gameFrame:CreateTexture(nil, "ARTWORK")
            tex:SetSize(CELL - 1, CELL - 1)
            tex:SetPoint("TOPLEFT", (gx - 1) * CELL + 1, -((gy - 1) * CELL + 1))
            tex:SetTexture("Interface\\Buttons\\WHITE8x8")
            tex:SetVertexColor(unpack(C_GRID))
            cells[gx .. "," .. gy] = tex
        end
    end

    -- Ship sprite overlay
    shipSprite = CreateFrame("Frame", nil, gameFrame)
    shipSprite:SetSize(32, 28)
    shipSprite:SetFrameLevel(gameFrame:GetFrameLevel() + 2)
    local sTex = shipSprite:CreateTexture(nil, "OVERLAY")
    sTex:SetAllPoints()
    sTex:SetTexture(SPRITE_PATH .. "SpriteShip")
    shipSprite:Hide()

    -- Alien sprite pool
    for i = 1, MAX_ALIEN_SPRITES do
        local af = CreateFrame("Frame", nil, gameFrame)
        af:SetSize(24, 20)
        af:SetFrameLevel(gameFrame:GetFrameLevel() + 1)
        local at = af:CreateTexture(nil, "OVERLAY")
        at:SetAllPoints()
        af.tex = at
        af:Hide()
        alienPool[i] = af
    end

    -- Explosion sprite pool
    for i = 1, MAX_EXPLOSIONS do
        local ef = CreateFrame("Frame", nil, gameFrame)
        ef:SetSize(26, 26)
        ef:SetFrameLevel(gameFrame:GetFrameLevel() + 3)
        local et = ef:CreateTexture(nil, "OVERLAY")
        et:SetAllPoints()
        et:SetTexture(SPRITE_PATH .. "SpriteExplosion")
        ef:Hide()
        explosionPool[i] = ef
    end

    -- Message overlay (on high-level frame so it draws above sprites)
    local msgFrame = CreateFrame("Frame", nil, gameFrame)
    msgFrame:SetAllPoints()
    msgFrame:SetFrameLevel(gameFrame:GetFrameLevel() + 10)
    msgText = msgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgText:SetPoint("CENTER", 0, 10)
    local mf = msgText:GetFont()
    if mf then msgText:SetFont(mf, 10, "OUTLINE") end
    msgText:SetText("|cff88ccffSPACE INVADERS|r\n|cff888888Press any key|r")

    -- Keyboard input
    local keyFrame = CreateFrame("Frame", "PhoneSpaceShooterKeyFrame", parentFrame)
    keyFrame:SetAllPoints(parentFrame)
    keyFrame:EnableKeyboard(false)
    keyFrame:SetPropagateKeyboardInput(true)

    keyFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(true)
            return
        end
        self:SetPropagateKeyboardInput(false)
        HandleKeyDown(key)
    end)

    keyFrame:SetScript("OnKeyUp", function(self, key)
        self:SetPropagateKeyboardInput(true)
        HandleKeyUp(key)
    end)

    PhoneSpaceShooterGame.keyFrame = keyFrame

    -- OnUpdate
    gameFrame:SetScript("OnUpdate", function(_, dt)
        Tick(dt)
    end)
end

function PhoneSpaceShooterGame:OnShow()
    if PhoneSpaceShooterGame.keyFrame then
        PhoneSpaceShooterGame.keyFrame:EnableKeyboard(true)
        PhoneSpaceShooterGame.keyFrame:SetPropagateKeyboardInput(true)
    end
    if not gameRunning and not gameover then
        ClearGrid()
        HideAllSprites()
        if msgText then
            msgText:SetText("|cff88ccffSPACE INVADERS|r\n|cff888888Press any key|r")
        end
    end
end

function PhoneSpaceShooterGame:OnHide()
    holdLeft = false
    holdRight = false
    holdShoot = false
    HideAllSprites()
    if PhoneSpaceShooterGame.keyFrame then
        PhoneSpaceShooterGame.keyFrame:EnableKeyboard(false)
        PhoneSpaceShooterGame.keyFrame:SetPropagateKeyboardInput(true)
    end
end
