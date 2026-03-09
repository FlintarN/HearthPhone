-- PhoneRoguelike - Top-down roguelike shooter for HearthPhone

PhoneRoguelikeGame = {}

local SPRITE_PATH = "Interface\\AddOns\\HearthPhone\\Textures\\"
local GAME_W = 176
local GAME_H = 260
local PLAYER_SIZE = 16
local MONSTER_SIZE = 16
local BULLET_SIZE = 6
local LOOT_SIZE = 10
local MAX_MONSTERS = 30
local MAX_BULLETS = 25
local MAX_ENEMY_BULLETS = 15
local MAX_LOOT = 8
local MAX_EXPLOSIONS = 10

-- State
local gameFrame, hudFrame, scoreText, waveText, hpText, msgText
local gameRunning = false
local gameover = false
local score = 0
local wave = 0
local waveTimer = 0
local waveDelay = 0
local spawnTimer = 0
local monstersSpawned = 0
local monstersToSpawn = 0
local monstersAlive = 0

-- Player
local player = {
    x = 0, y = 0,
    hp = 5, maxHp = 5,
    speed = 70,
    damage = 1,
    fireRate = 0.35,
    projSpeed = 140,
    projCount = 1,
    fireCooldown = 0,
    invTimer = 0,  -- invincibility after hit
}

-- Object pools
local monsters = {}
local playerBullets = {}
local enemyBullets = {}
local lootDrops = {}
local explosions = {}

-- Sprite pools (frames)
local playerSprite
local monsterPool = {}
local bulletPool = {}
local enemyBulletPool = {}
local lootPool = {}
local explosionPool = {}

-- Input
local keyState = { W = false, A = false, S = false, D = false }
local keyBtns = {}

-- Monster types
local MONSTER_TYPES = {
    zombie = {
        tex = "SpriteZombie",
        hp = 3, speed = 25, size = 16,
        color = {0.5, 0.7, 0.4},
        score = 10,
        ranged = false,
    },
    imp = {
        tex = "SpriteImp",
        hp = 1, speed = 55, size = 14,
        color = {0.7, 0.2, 0.2},
        score = 15,
        ranged = false,
    },
    demon = {
        tex = "SpriteDemon",
        hp = 6, speed = 20, size = 18,
        color = {0.4, 0.15, 0.5},
        score = 30,
        ranged = true,
        shootRate = 2.0,
    },
}

-- Loot definitions
local LOOT_TYPES = {
    { key = "multishot", tex = "SpriteLootMultishot", color = {0.3, 0.9, 0.3}, label = "+Multishot" },
    { key = "speed",     tex = "SpriteLootSpeed",     color = {0.3, 0.6, 1.0}, label = "+Speed" },
    { key = "damage",    tex = "SpriteLootDamage",    color = {1.0, 0.3, 0.2}, label = "+Damage" },
    { key = "firerate",  tex = "SpriteLootFireRate",   color = {1.0, 0.9, 0.2}, label = "+Fire Rate" },
    { key = "health",    tex = "SpriteLootHealth",     color = {1.0, 0.4, 0.6}, label = "+Health" },
}

-- ============================================================
-- Helpers
-- ============================================================
local sqrt, sin, cos, random, floor, max, min, pi = math.sqrt, math.sin, math.cos, math.random, math.floor, math.max, math.min, math.pi

local function Dist(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return sqrt(dx * dx + dy * dy)
end

local function Normalize(dx, dy)
    local len = sqrt(dx * dx + dy * dy)
    if len < 0.001 then return 0, 0 end
    return dx / len, dy / len
end

local function Clamp(v, lo, hi) return max(lo, min(hi, v)) end

-- ============================================================
-- Sprite pool helpers
-- ============================================================
local function MakeSprite(parent, size, textureName, level)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    f:SetFrameLevel(parent:GetFrameLevel() + (level or 1))
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    if textureName then
        tex:SetTexture(SPRITE_PATH .. textureName)
    end
    f.tex = tex
    f:Hide()
    return f
end

local function PlaceSprite(sprite, x, y)
    sprite:ClearAllPoints()
    sprite:SetPoint("CENTER", gameFrame, "TOPLEFT", x, -y)
    sprite:Show()
end

-- ============================================================
-- Wave system
-- ============================================================
local function GetWaveConfig(w)
    local count = min(5 + w * 2, 25)
    local hpMul = 1 + floor((w - 1) / 3) * 0.5
    local speedMul = 1 + (w - 1) * 0.05
    local spawnInterval = max(0.25, 1.0 - w * 0.05)
    return count, hpMul, speedMul, spawnInterval
end

local function PickMonsterType(w)
    local roll = random(100)
    if w >= 7 and roll <= 15 then return "demon"
    elseif w >= 4 and roll <= 40 then return "imp"
    else return "zombie"
    end
end

local function SpawnMonster()
    if #monsters >= MAX_MONSTERS then return end
    local typeName = PickMonsterType(wave)
    local mtype = MONSTER_TYPES[typeName]
    local _, hpMul, speedMul = GetWaveConfig(wave)

    -- Spawn from random edge
    local x, y
    local edge = random(4)
    if edge == 1 then     -- top
        x, y = random(10, GAME_W - 10), -10
    elseif edge == 2 then -- bottom
        x, y = random(10, GAME_W - 10), GAME_H + 10
    elseif edge == 3 then -- left
        x, y = -10, random(10, GAME_H - 10)
    else                  -- right
        x, y = GAME_W + 10, random(10, GAME_H - 10)
    end

    table.insert(monsters, {
        x = x, y = y,
        hp = floor(mtype.hp * hpMul),
        maxHp = floor(mtype.hp * hpMul),
        speed = mtype.speed * speedMul,
        size = mtype.size,
        type = typeName,
        score = mtype.score,
        ranged = mtype.ranged,
        shootTimer = mtype.shootRate and (mtype.shootRate * (0.5 + random() * 0.5)) or 0,
        shootRate = mtype.shootRate or 0,
        alive = true,
        flashTimer = 0,
    })
    monstersSpawned = monstersSpawned + 1
    monstersAlive = monstersAlive + 1
end

local function StartWave()
    wave = wave + 1
    local count, _, _, interval = GetWaveConfig(wave)
    monstersToSpawn = count
    monstersSpawned = 0
    spawnTimer = 0
    waveDelay = 1.5
    if msgText then
        msgText:SetText("|cffff8844Wave " .. wave .. "|r")
    end
end

-- ============================================================
-- Loot
-- ============================================================
local function TryDropLoot(x, y)
    if #lootDrops >= MAX_LOOT then return end
    if random(100) > 25 then return end  -- 25% drop chance
    local ltype = LOOT_TYPES[random(#LOOT_TYPES)]
    table.insert(lootDrops, {
        x = x, y = y,
        type = ltype,
        timer = 14.0,
        alive = true,
        pulse = 0,
    })
end

local pickupMsg = nil
local pickupTimer = 0

local function ApplyLoot(ltype)
    if ltype.key == "multishot" then
        player.projCount = min(player.projCount + 1, 7)
    elseif ltype.key == "speed" then
        player.speed = player.speed + 10
    elseif ltype.key == "damage" then
        player.damage = player.damage + 1
    elseif ltype.key == "firerate" then
        player.fireRate = max(0.08, player.fireRate - 0.04)
    elseif ltype.key == "health" then
        player.hp = min(player.hp + 1, player.maxHp)
    end
    pickupMsg = ltype.label
    pickupTimer = 1.0
end

-- ============================================================
-- Shooting
-- ============================================================
local aimAngle = 0  -- updated each frame from cursor position

local function FireBullets()
    local baseAngle = aimAngle
    local spread = 0.15  -- radians between each extra projectile

    for i = 1, player.projCount do
        if #playerBullets >= MAX_BULLETS then break end
        local offset = (i - (player.projCount + 1) / 2) * spread
        local angle = baseAngle + offset
        local vx = cos(angle) * player.projSpeed
        local vy = sin(angle) * player.projSpeed
        table.insert(playerBullets, {
            x = player.x, y = player.y,
            vx = vx, vy = vy,
            damage = player.damage,
            alive = true,
        })
    end
    PlaySound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115, "SFX")
end

local function FireEnemyBullet(m)
    if #enemyBullets >= MAX_ENEMY_BULLETS then return end
    local dx, dy = Normalize(player.x - m.x, player.y - m.y)
    local speed = 60 + wave * 3
    table.insert(enemyBullets, {
        x = m.x, y = m.y,
        vx = dx * speed, vy = dy * speed,
        alive = true,
    })
end

-- ============================================================
-- Explosions
-- ============================================================
local function AddExplosion(x, y)
    table.insert(explosions, { x = x, y = y, timer = 0.25 })
end

-- ============================================================
-- Game start / reset
-- ============================================================
local function ResetPlayer()
    player.x = GAME_W / 2
    player.y = GAME_H * 0.75
    player.hp = 5
    player.maxHp = 5
    player.speed = 70
    player.damage = 1
    player.fireRate = 0.35
    player.projSpeed = 140
    player.projCount = 1
    player.fireCooldown = 0
    player.invTimer = 0
end

local function StartGame()
    score = 0
    wave = 0
    monsters = {}
    playerBullets = {}
    enemyBullets = {}
    lootDrops = {}
    explosions = {}
    monstersAlive = 0
    gameover = false
    gameRunning = true
    pickupMsg = nil
    pickupTimer = 0
    ResetPlayer()
    StartWave()
end

-- ============================================================
-- Game tick
-- ============================================================
local function Tick(dt)
    if not gameRunning then return end

    -- Cap dt to prevent huge jumps
    dt = min(dt, 0.05)

    -- Wave delay (show wave text)
    if waveDelay > 0 then
        waveDelay = waveDelay - dt
        if waveDelay <= 0 and msgText then
            msgText:SetText("")
        end
    end

    -- Pickup message fade
    if pickupTimer > 0 then
        pickupTimer = pickupTimer - dt
        if pickupTimer <= 0 then pickupMsg = nil end
    end

    -- Player movement
    local mx, my = 0, 0
    if keyState.W then my = my - 1 end
    if keyState.S then my = my + 1 end
    if keyState.A then mx = mx - 1 end
    if keyState.D then mx = mx + 1 end
    local mlen = sqrt(mx * mx + my * my)
    if mlen > 0 then
        mx, my = mx / mlen, my / mlen
        player.x = Clamp(player.x + mx * player.speed * dt, 8, GAME_W - 8)
        player.y = Clamp(player.y + my * player.speed * dt, 8, GAME_H - 8)
    end

    -- Player invincibility timer
    if player.invTimer > 0 then
        player.invTimer = player.invTimer - dt
    end

    -- Update aim angle from cursor
    if gameFrame then
        local cx, cy = gameFrame:GetCenter()
        local mx, my = GetCursorPosition()
        local scale = gameFrame:GetEffectiveScale()
        mx, my = mx / scale, my / scale
        -- Convert to game-local coords (WoW Y is up, game Y is down)
        local gx = mx - (cx - GAME_W / 2)
        local gy = (cy + GAME_H / 2) - my
        aimAngle = math.atan2(gy - player.y, gx - player.x)
    end

    -- Auto-fire toward cursor
    player.fireCooldown = player.fireCooldown - dt
    if player.fireCooldown <= 0 then
        FireBullets()
        player.fireCooldown = player.fireRate
    end

    -- Spawning
    if monstersSpawned < monstersToSpawn and waveDelay <= 0 then
        local _, _, _, interval = GetWaveConfig(wave)
        spawnTimer = spawnTimer + dt
        if spawnTimer >= interval then
            spawnTimer = spawnTimer - interval
            SpawnMonster()
        end
    end

    -- Move player bullets
    for _, b in ipairs(playerBullets) do
        if b.alive then
            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
            -- Off screen?
            if b.x < -10 or b.x > GAME_W + 10 or b.y < -10 or b.y > GAME_H + 10 then
                b.alive = false
            end
        end
    end

    -- Move enemy bullets
    for _, b in ipairs(enemyBullets) do
        if b.alive then
            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
            if b.x < -10 or b.x > GAME_W + 10 or b.y < -10 or b.y > GAME_H + 10 then
                b.alive = false
            end
            -- Hit player?
            if player.invTimer <= 0 and Dist(b.x, b.y, player.x, player.y) < 8 then
                b.alive = false
                player.hp = player.hp - 1
                player.invTimer = 1.0
                if player.hp <= 0 then
                    gameRunning = false
                    gameover = true
                    AddExplosion(player.x, player.y)
                    if msgText then
                        msgText:SetText("|cffff4444GAME OVER|r\n|cffaaaaaa" .. score .. " pts|r\n|cff888888Press any key|r")
                    end
                    return
                end
            end
        end
    end

    -- Move monsters + AI
    for _, m in ipairs(monsters) do
        if m.alive then
            local dx, dy = Normalize(player.x - m.x, player.y - m.y)
            m.x = m.x + dx * m.speed * dt
            m.y = m.y + dy * m.speed * dt

            -- Contact damage
            if player.invTimer <= 0 and Dist(m.x, m.y, player.x, player.y) < (m.size / 2 + PLAYER_SIZE / 2 - 2) then
                player.hp = player.hp - 1
                player.invTimer = 1.0
                AddExplosion(player.x, player.y)
                if player.hp <= 0 then
                    gameRunning = false
                    gameover = true
                    if msgText then
                        msgText:SetText("|cffff4444GAME OVER|r\n|cffaaaaaa" .. score .. " pts|r\n|cff888888Press any key|r")
                    end
                    return
                end
            end

            -- Ranged attack
            if m.ranged and m.shootRate > 0 then
                m.shootTimer = m.shootTimer - dt
                if m.shootTimer <= 0 then
                    m.shootTimer = m.shootRate
                    FireEnemyBullet(m)
                end
            end

            -- Flash timer (hit feedback)
            if m.flashTimer > 0 then
                m.flashTimer = m.flashTimer - dt
            end
        end
    end

    -- Bullet vs monster collision
    for _, b in ipairs(playerBullets) do
        if b.alive then
            for _, m in ipairs(monsters) do
                if m.alive and Dist(b.x, b.y, m.x, m.y) < (m.size / 2 + 3) then
                    b.alive = false
                    m.hp = m.hp - b.damage
                    m.flashTimer = 0.1
                    if m.hp <= 0 then
                        m.alive = false
                        monstersAlive = monstersAlive - 1
                        score = score + m.score
                        AddExplosion(m.x, m.y)
                        TryDropLoot(m.x, m.y)
                    end
                    break
                end
            end
        end
    end

    -- Player vs loot collision
    for _, l in ipairs(lootDrops) do
        if l.alive then
            l.timer = l.timer - dt
            l.pulse = l.pulse + dt
            if l.timer <= 0 then
                l.alive = false
            elseif Dist(player.x, player.y, l.x, l.y) < (PLAYER_SIZE / 2 + LOOT_SIZE / 2 + 2) then
                l.alive = false
                ApplyLoot(l.type)
            end
        end
    end

    -- Fade explosions
    for _, e in ipairs(explosions) do
        e.timer = e.timer - dt
    end

    -- Clean up dead objects
    local function FilterAlive(list)
        local kept = {}
        for _, obj in ipairs(list) do
            if obj.alive then table.insert(kept, obj) end
        end
        return kept
    end
    playerBullets = FilterAlive(playerBullets)
    enemyBullets = FilterAlive(enemyBullets)
    monsters = FilterAlive(monsters)
    lootDrops = FilterAlive(lootDrops)

    local keptExp = {}
    for _, e in ipairs(explosions) do
        if e.timer > 0 then table.insert(keptExp, e) end
    end
    explosions = keptExp

    -- Wave complete?
    if monstersAlive <= 0 and monstersSpawned >= monstersToSpawn and waveDelay <= 0 then
        StartWave()
    end

    -- Render
    Render()
end

-- ============================================================
-- Rendering
-- ============================================================
function Render()
    if not gameFrame then return end

    -- Player
    if gameRunning then
        PlaceSprite(playerSprite, player.x, player.y)
        -- Blink during invincibility
        if player.invTimer > 0 then
            local blink = floor(player.invTimer * 10) % 2 == 0
            playerSprite:SetAlpha(blink and 1.0 or 0.3)
        else
            playerSprite:SetAlpha(1.0)
        end
    else
        playerSprite:Hide()
    end

    -- Monsters
    for i = 1, MAX_MONSTERS do
        local pool = monsterPool[i]
        local m = monsters[i]
        if m and m.alive then
            local mtype = MONSTER_TYPES[m.type]
            pool.tex:SetTexture(SPRITE_PATH .. mtype.tex)
            pool:SetSize(m.size, m.size)
            PlaceSprite(pool, m.x, m.y)
            -- Flash white on hit
            if m.flashTimer > 0 then
                pool.tex:SetVertexColor(1, 1, 1, 1)
            else
                local c = mtype.color
                pool.tex:SetVertexColor(c[1], c[2], c[3], 1)
            end
        else
            pool:Hide()
        end
    end

    -- Player bullets
    for i = 1, MAX_BULLETS do
        local pool = bulletPool[i]
        local b = playerBullets[i]
        if b then
            PlaceSprite(pool, b.x, b.y)
        else
            pool:Hide()
        end
    end

    -- Enemy bullets
    for i = 1, MAX_ENEMY_BULLETS do
        local pool = enemyBulletPool[i]
        local b = enemyBullets[i]
        if b then
            PlaceSprite(pool, b.x, b.y)
        else
            pool:Hide()
        end
    end

    -- Loot
    for i = 1, MAX_LOOT do
        local pool = lootPool[i]
        local l = lootDrops[i]
        if l then
            PlaceSprite(pool, l.x, l.y)
            pool.tex:SetTexture(SPRITE_PATH .. l.type.tex)
            -- Pulse alpha
            local alpha = 0.7 + 0.3 * sin(l.pulse * 4)
            pool:SetAlpha(alpha)
            -- Blink when about to expire
            if l.timer < 2.0 then
                local blink = floor(l.timer * 5) % 2 == 0
                pool:SetAlpha(blink and alpha or 0.2)
            end
        else
            pool:Hide()
        end
    end

    -- Explosions
    for i = 1, MAX_EXPLOSIONS do
        local pool = explosionPool[i]
        local e = explosions[i]
        if e then
            PlaceSprite(pool, e.x, e.y)
            pool:SetAlpha(e.timer / 0.25)
            local s = 16 + (1 - e.timer / 0.25) * 12
            pool:SetSize(s, s)
        else
            pool:Hide()
        end
    end

    -- HUD
    if scoreText then
        scoreText:SetText(format("|cffffd700%d|r  W:|cff88ff88%d|r", score, wave))
    end
    if hpText then
        local hearts = ""
        for i = 1, player.maxHp do
            if i <= player.hp then
                hearts = hearts .. "|cffff4444<3|r"
            else
                hearts = hearts .. "|cff444444<3|r"
            end
        end
        hpText:SetText(hearts)
    end
    -- Pickup message
    if waveText then
        if pickupMsg and pickupTimer > 0 then
            waveText:SetText("|cff44ff44" .. pickupMsg .. "|r")
            waveText:SetAlpha(min(1, pickupTimer * 2))
        else
            waveText:SetText("")
        end
    end
end

-- ============================================================
-- Input setup (Agario-style override bindings)
-- ============================================================
local function MakeKeyBtn(parent, key)
    local btn = CreateFrame("Button", "PhoneRogueKey" .. key, parent, "SecureActionButtonTemplate")
    btn:SetSize(1, 1)
    btn:SetPoint("CENTER")
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetScript("OnClick", function(_, _, down)
        if not gameRunning then
            if down then StartGame() end
            return
        end
        keyState[key] = down
    end)
    SetOverrideBindingClick(btn, false, key, btn:GetName(), "LeftButton")
    return btn
end

local function EnableKeys(parent)
    if #keyBtns > 0 then return end
    for _, k in ipairs({"W", "A", "S", "D"}) do
        table.insert(keyBtns, MakeKeyBtn(parent, k))
    end
end

local function DisableKeys()
    for _, btn in ipairs(keyBtns) do
        ClearOverrideBindings(btn)
        btn:Hide()
    end
    keyBtns = {}
    keyState.W = false
    keyState.A = false
    keyState.S = false
    keyState.D = false
end

-- ============================================================
-- Init
-- ============================================================
function PhoneRoguelikeGame:Init(parentFrame)
    if gameFrame then return end

    -- Background for the game area
    gameFrame = CreateFrame("Frame", nil, parentFrame)
    gameFrame:SetSize(GAME_W, GAME_H)
    gameFrame:SetPoint("TOP", 0, -12)

    local bg = gameFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.06, 0.06, 0.08, 1)

    -- Floor decoration: subtle grid lines
    for i = 0, floor(GAME_W / 20) do
        local line = gameFrame:CreateTexture(nil, "BORDER")
        line:SetSize(1, GAME_H)
        line:SetPoint("TOPLEFT", i * 20, 0)
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetVertexColor(0.1, 0.1, 0.12, 0.3)
    end
    for i = 0, floor(GAME_H / 20) do
        local line = gameFrame:CreateTexture(nil, "BORDER")
        line:SetSize(GAME_W, 1)
        line:SetPoint("TOPLEFT", 0, -(i * 20))
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        line:SetVertexColor(0.1, 0.1, 0.12, 0.3)
    end

    -- Border
    local border = gameFrame:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetVertexColor(0.2, 0.15, 0.1, 0.6)

    -- HUD: score (top-left)
    scoreText = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreText:SetPoint("TOPLEFT", 4, -2)
    do
        local f = scoreText:GetFont()
        if f then scoreText:SetFont(f, 8, "OUTLINE") end
    end

    -- HUD: HP (top-right)
    hpText = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hpText:SetPoint("TOPRIGHT", -4, -2)
    do
        local f = hpText:GetFont()
        if f then hpText:SetFont(f, 7, "OUTLINE") end
    end

    -- Center message (wave announce, game over) + pickup text
    local msgFrame = CreateFrame("Frame", nil, gameFrame)
    msgFrame:SetAllPoints()
    msgFrame:SetFrameLevel(gameFrame:GetFrameLevel() + 10)
    msgText = msgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgText:SetPoint("CENTER", 0, 20)
    do
        local f = msgText:GetFont()
        if f then msgText:SetFont(f, 10, "OUTLINE") end
    end

    -- Pickup text (on msgFrame so it draws above sprites)
    waveText = msgFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    waveText:SetPoint("BOTTOM", gameFrame, "BOTTOM", 0, 6)
    do
        local f = waveText:GetFont()
        if f then waveText:SetFont(f, 8, "OUTLINE") end
    end
    msgText:SetText("|cffff6644SURVIVOR|r\n|cff888888Press any key|r")

    -- Player sprite
    playerSprite = MakeSprite(gameFrame, PLAYER_SIZE, "SpritePlayer", 3)

    -- Monster pool
    for i = 1, MAX_MONSTERS do
        monsterPool[i] = MakeSprite(gameFrame, MONSTER_SIZE, "SpriteZombie", 2)
    end

    -- Bullet pools
    for i = 1, MAX_BULLETS do
        bulletPool[i] = MakeSprite(gameFrame, BULLET_SIZE, "SpriteBullet", 4)
    end
    for i = 1, MAX_ENEMY_BULLETS do
        enemyBulletPool[i] = MakeSprite(gameFrame, BULLET_SIZE, "SpriteEnemyBullet", 4)
    end

    -- Loot pool
    for i = 1, MAX_LOOT do
        lootPool[i] = MakeSprite(gameFrame, LOOT_SIZE, nil, 2)
    end

    -- Explosion pool
    for i = 1, MAX_EXPLOSIONS do
        local e = MakeSprite(gameFrame, 16, "HitExplosion", 5)
        explosionPool[i] = e
    end

    -- Keyboard frame for any-key start/restart
    local keyFrame = CreateFrame("Frame", "PhoneRoguelikeKeyFrame", parentFrame)
    keyFrame:SetAllPoints(parentFrame)
    keyFrame:EnableKeyboard(false)
    keyFrame:SetPropagateKeyboardInput(true)
    keyFrame:SetScript("OnKeyDown", function(kf, key)
        if key == "ESCAPE" then
            kf:SetPropagateKeyboardInput(true)
            return
        end
        if not gameRunning then
            kf:SetPropagateKeyboardInput(false)
            StartGame()
            return
        end
        kf:SetPropagateKeyboardInput(true)
    end)
    PhoneRoguelikeGame.keyFrame = keyFrame

    -- Game loop
    gameFrame:SetScript("OnUpdate", function(_, dt)
        Tick(dt)
    end)
end

function PhoneRoguelikeGame:OnShow()
    EnableKeys(gameFrame)
    if PhoneRoguelikeGame.keyFrame then
        PhoneRoguelikeGame.keyFrame:EnableKeyboard(true)
        PhoneRoguelikeGame.keyFrame:SetPropagateKeyboardInput(true)
    end
    if not gameRunning and not gameover then
        if msgText then
            msgText:SetText("|cffff6644SURVIVOR|r\n|cff888888Press any key|r")
        end
    end
end

function PhoneRoguelikeGame:OnHide()
    DisableKeys()
    if PhoneRoguelikeGame.keyFrame then
        PhoneRoguelikeGame.keyFrame:EnableKeyboard(false)
        PhoneRoguelikeGame.keyFrame:SetPropagateKeyboardInput(true)
    end
    keyState.W = false
    keyState.A = false
    keyState.S = false
    keyState.D = false
end
