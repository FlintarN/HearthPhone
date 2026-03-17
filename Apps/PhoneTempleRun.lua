-- PhoneTempleRun - Faithful Temple Run recreation for HearthPhone
-- Perspective stone path that bends at turns, jump/slide, demon monkey

PhoneTempleRunGame = {}

local parent
local gameFrame, scoreFs, coinFs, msgFs, startMsg
local SPRITE_PATH = "Interface\\AddOns\\HearthPhone\\Textures\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local frameW, frameH

-- Layout
local LANES = 3
local PLAYER_Y = 28
local LANE_SPACING_BOT = 28
local PERSP_SCALE_TOP = 0.25
local VANISH_Y_FRAC = 0.92

-- Player
local PLAYER_W = 14
local PLAYER_H = 20
local DUCK_H = 8
local JUMP_VEL = 210
local GRAVITY = 600

-- State
local score, bestScore, coinCount, distance
local gameActive, gameOver
local lastTime = 0
local playerLane, jumpOffset, playerVelY, isJumping, isDucking
local scrollSpeed, stumbles

-- Objects
local obstacles = {}
local coins = {}

-- Timers
local obsTimer, coinTimer

-- Texture pools (consolidated to stay under Lua 5.1's 60-upvalue limit)
local pools = {
    obs = {},
    obsPost = {},
    coin = {},
    pillarL = {},
    pillarR = {},
}

-- Visual elements
local playerTex
local pathStrips = {}
local pathEdgeL = {}
local pathEdgeR = {}
local tileLines = {}
local livesFs
local stumbleFs, stumbleTimer
local hintFs
local hitFlash

-- ============================================================
-- Perspective math
-- ============================================================
local function PerspScale(screenY)
    local vanishY = (frameH or 200) * VANISH_Y_FRAC
    local t = screenY / vanishY
    if t > 1 then t = 1 end
    if t < 0 then t = 0 end
    return 1.0 - t * (1.0 - PERSP_SCALE_TOP)
end

local function LaneX(lane, screenY)
    local s = PerspScale(screenY)
    local cx = (frameW or 140) / 2
    return cx + (lane - 2) * LANE_SPACING_BOT * s
end

local function PathHalfW(screenY)
    local s = PerspScale(screenY)
    return LANE_SPACING_BOT * (LANES + 0.4) * s * 0.5
end

-- Turn offset is always 0 — turns are camera-clip events, path stays straight

-- ============================================================
-- Frame pool helpers
-- ============================================================
local function EnsurePool(pool, count, layer, sublayer)
    while #pool < count do
        local tex = gameFrame:CreateTexture(nil, layer or "ARTWORK", nil, sublayer or 0)
        tex:SetTexture(WHITE)
        tex:Hide()
        pool[#pool + 1] = tex
    end
end

local function EnsureCoinPool(count)
    while #pools.coin < count do
        local tex = gameFrame:CreateTexture(nil, "ARTWORK", nil, 2)
        tex:SetTexture(SPRITE_PATH .. "SpriteRunCoin")
        tex:Hide()
        pools.coin[#pools.coin + 1] = tex
    end
end

-- ============================================================
-- Path rendering (dynamic, called each frame)
-- ============================================================
local PATH_STRIPS = 30
local pathCreated = false

local function CreatePathTextures()
    if pathCreated then return end
    pathCreated = true
    for i = 1, PATH_STRIPS do
        pathStrips[i] = gameFrame:CreateTexture(nil, "BORDER", nil, 1)
        pathStrips[i]:SetTexture(WHITE)
        pathEdgeL[i] = gameFrame:CreateTexture(nil, "BORDER", nil, 2)
        pathEdgeL[i]:SetTexture(WHITE)
        pathEdgeL[i]:SetVertexColor(0.18, 0.14, 0.10, 1)
        pathEdgeR[i] = gameFrame:CreateTexture(nil, "BORDER", nil, 2)
        pathEdgeR[i]:SetTexture(WHITE)
        pathEdgeR[i]:SetVertexColor(0.18, 0.14, 0.10, 1)
    end
    for i = 1, 12 do
        tileLines[i] = gameFrame:CreateTexture(nil, "BORDER", nil, 3)
        tileLines[i]:SetTexture(WHITE)
        tileLines[i]:SetVertexColor(0.20, 0.16, 0.12, 0.5)
    end
end

local function UpdatePath()
    local fh = frameH or 200
    local fw = frameW or 140
    local stripH = fh / PATH_STRIPS

    for i = 1, PATH_STRIPS do
        local y = (i - 1) * stripH
        local midY = y + stripH / 2
        local s = PerspScale(midY)
        local halfW = LANE_SPACING_BOT * (LANES + 0.4) * s * 0.5
        local cx = fw / 2
        local edgeW = math.max(2 * s, 1)

        -- Alternate stone colors
        local shade = (i % 2 == 0) and 0.28 or 0.25
        pathStrips[i]:SetVertexColor(shade, shade - 0.03, shade - 0.07, 1)
        pathStrips[i]:ClearAllPoints()
        pathStrips[i]:SetSize(halfW * 2, stripH + 1)
        pathStrips[i]:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", cx - halfW, y)
        pathStrips[i]:Show()

        pathEdgeL[i]:ClearAllPoints()
        pathEdgeL[i]:SetSize(edgeW, stripH + 1)
        pathEdgeL[i]:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", cx - halfW, y)
        pathEdgeL[i]:Show()

        pathEdgeR[i]:ClearAllPoints()
        pathEdgeR[i]:SetSize(edgeW, stripH + 1)
        pathEdgeR[i]:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", cx + halfW - edgeW, y)
        pathEdgeR[i]:Show()
    end
end

local tileScrollOffset = 0
local pillarScrollOffset = 0

local function UpdateTileLines(dt)
    if not tileLines[1] then return end
    local fh = frameH or 200
    local fw = frameW or 140
    local spacing = 18

    tileScrollOffset = tileScrollOffset + scrollSpeed * dt
    if tileScrollOffset >= spacing then
        tileScrollOffset = tileScrollOffset - spacing
    end

    for i = 1, 12 do
        local baseY = (i - 1) * spacing - tileScrollOffset
        if baseY >= 0 and baseY < fh then
            local s = PerspScale(baseY)
            local halfW = LANE_SPACING_BOT * (LANES + 0.4) * s * 0.5
            local cx = fw / 2
            tileLines[i]:ClearAllPoints()
            tileLines[i]:SetSize(halfW * 2 - 4 * s, math.max(1, 1 * s))
            tileLines[i]:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT",
                cx - halfW + 2 * s, baseY)
            tileLines[i]:Show()
        else
            tileLines[i]:Hide()
        end
    end
end

-- ============================================================
-- Spawning
-- ============================================================
local function SpawnObstacle()
    local lane = math.random(1, LANES)
    -- Two types only: "jump" (ground obstacle) and "beam" (overhead, slide under)
    local kind
    if distance < 50 then
        -- Early game: jump only, learn the basics
        kind = "jump"
    else
        -- Mix in beams after 50m
        kind = math.random(1, 3) == 1 and "beam" or "jump"
    end
    -- Occasionally spawn in two lanes at higher distance
    if distance > 120 and math.random(1, 5) == 1 then
        local lane2 = lane
        while lane2 == lane do lane2 = math.random(1, LANES) end
        table.insert(obstacles, {
            lane = lane2,
            scrollY = (frameH or 200) + 40,
            kind = kind,
            passed = false,
        })
    end
    table.insert(obstacles, {
        lane = lane,
        scrollY = (frameH or 200) + 40,
        kind = kind,
        passed = false,
    })
end

local function SpawnCoinTrail()
    local lane = math.random(1, LANES)
    local count = math.random(3, 5)
    local startY = (frameH or 200) + 10
    for i = 1, count do
        table.insert(coins, {
            lane = lane,
            scrollY = startY + (i - 1) * 14,
            collected = false,
        })
    end
end

-- ============================================================
-- Reset
-- ============================================================
local function ResetGame()
    frameW = gameFrame:GetWidth() or 140
    frameH = gameFrame:GetHeight() or 200

    playerLane = 2
    jumpOffset = 0
    playerVelY = 0
    isJumping = false
    isDucking = false
    score = 0
    coinCount = 0
    distance = 0
    gameOver = false
    gameActive = false
    scrollSpeed = 50
    stumbles = 0
    lastTime = 0
    obsTimer = 0
    coinTimer = 0
    tileScrollOffset = 0
    pillarScrollOffset = 0

    wipe(obstacles)
    wipe(coins)
    for _, p in pairs(pools) do
        for _, f in ipairs(p) do f:Hide() end
    end
    if hitFlash then hitFlash:Hide() end

    scoreFs:SetText("|cffffffff0m|r")
    coinFs:SetText("|cffffff000|r")
    msgFs:SetText("")
    startMsg:Show()

    if livesFs then livesFs:SetText("|cffff0000<3 <3 <3|r") end
    if stumbleFs then stumbleFs:SetText(""); stumbleTimer = 0 end
    if hintFs then hintFs:Hide() end

    playerTex:ClearAllPoints()
    playerTex:SetSize(PLAYER_W, PLAYER_H)
    playerTex:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT",
        LaneX(2, PLAYER_Y), PLAYER_Y)
    playerTex:Show()
end

-- ============================================================
-- Collision
-- ============================================================
local function PlayerHitsObs(obs)
    if obs.lane ~= playerLane then return false end
    local obsScreenY = obs.scrollY
    local s = PerspScale(obsScreenY)
    local obsH = 12 * s
    -- Collision at feet level: obstacle must overlap player's foot zone (PLAYER_Y to PLAYER_Y + 8)
    local footTop = PLAYER_Y + 8
    if obsScreenY > footTop or obsScreenY + obsH < PLAYER_Y then
        return false
    end
    if obs.kind == "jump" then
        -- Ground obstacle: jump clears it
        if jumpOffset > 8 then return false end
        return true
    elseif obs.kind == "beam" then
        -- Overhead beam: slide under it
        if isDucking then return false end
        return true
    end
    return false
end

-- ============================================================
-- Update
-- ============================================================
local function OnUpdate()
    if not gameActive or gameOver then return end

    local now = GetTime()
    if lastTime == 0 then lastTime = now end
    local dt = now - lastTime
    lastTime = now
    if dt > 0.05 then dt = 0.05 end
    if dt <= 0 then return end

    local fh = frameH or 200
    local fw = frameW or 140

    -- Speed ramp (starts slower, ramps up gradually)
    scrollSpeed = 50 + distance * 0.35
    if scrollSpeed > 180 then scrollSpeed = 180 end

    -- Distance scoring
    distance = distance + scrollSpeed * dt * 0.15
    score = math.floor(distance) + coinCount * 5
    scoreFs:SetText("|cffffffff" .. math.floor(distance) .. "m|r")

    -- Jump physics
    if isJumping then
        playerVelY = playerVelY - GRAVITY * dt
        jumpOffset = jumpOffset + playerVelY * dt
        if jumpOffset <= 0 then
            jumpOffset = 0
            playerVelY = 0
            isJumping = false
        end
    end

    -- Update path with turn bending
    UpdatePath()
    UpdateTileLines(dt)

    -- Spawn obstacles
    obsTimer = obsTimer + dt
    local obsInterval = 1.4 - distance * 0.003
    if obsInterval < 0.5 then obsInterval = 0.5 end
    if obsTimer >= obsInterval then
        obsTimer = 0
        SpawnObstacle()
    end

    -- Spawn coin trails
    coinTimer = coinTimer + dt
    if coinTimer >= 1.5 then
        coinTimer = 0
        SpawnCoinTrail()
    end

    -- Move obstacles
    local toRm = {}
    for i, obs in ipairs(obstacles) do
        obs.scrollY = obs.scrollY - scrollSpeed * dt
        if obs.scrollY < -20 then
            table.insert(toRm, i)
        end
    end
    for ri = #toRm, 1, -1 do
        table.remove(obstacles, toRm[ri])
    end

    -- Move coins
    toRm = {}
    for i, c in ipairs(coins) do
        c.scrollY = c.scrollY - scrollSpeed * dt
        if c.scrollY < -20 then
            table.insert(toRm, i)
        end
    end
    for ri = #toRm, 1, -1 do
        table.remove(coins, toRm[ri])
    end

    -- Collision: obstacles
    for _, obs in ipairs(obstacles) do
        if not obs.passed and PlayerHitsObs(obs) then
            stumbles = stumbles + 1
            obs.passed = true
            if stumbles >= 3 then
                gameOver = true
            else
                -- Show stumble reason
                if stumbleFs then
                    local reason
                    if obs.kind == "jump" then
                        reason = "Press W to jump!"
                    elseif obs.kind == "beam" then
                        reason = "Press S to slide!"
                    end
                    stumbleFs:SetText("|cffff6644" .. (reason or "Ouch!") .. "|r")
                    stumbleTimer = 2.0
                end
                -- Red flash
                if hitFlash then
                    hitFlash:Show()
                    C_Timer.After(0.15, function() if hitFlash then hitFlash:Hide() end end)
                end
                -- Update lives display
                if livesFs then
                    local hearts = 3 - stumbles
                    local txt = ""
                    for h = 1, 3 do
                        if h <= hearts then
                            txt = txt .. "|cffff0000<3|r"
                        else
                            txt = txt .. "|cff444444<3|r"
                        end
                    end
                    livesFs:SetText(txt)
                end
            end
        elseif obs.scrollY < PLAYER_Y - 10 and not obs.passed then
            obs.passed = true
        end
    end

    -- Coin collection
    for _, c in ipairs(coins) do
        if not c.collected and c.lane == playerLane then
            if c.scrollY > PLAYER_Y - 10 and c.scrollY < PLAYER_Y + PLAYER_H + 5 then
                c.collected = true
                coinCount = coinCount + 1
                coinFs:SetText("|cffffff00" .. coinCount .. "|r")
            end
        end
    end

    -- Game over
    if gameOver then
        if score > bestScore then
            bestScore = score
            HearthPhoneDB = HearthPhoneDB or {}
            HearthPhoneDB.bestTempleRun = bestScore
        end
        msgFs:SetText("|cffff4444Game Over!|r\n|cffffffff"
            .. math.floor(distance) .. "m  " .. coinCount .. " coins|r")
        return
    end

    -- ==============================
    -- DRAW
    -- ==============================

    -- Pillars along path edges (stone columns like temple ruins)
    local PILLAR_SPACING = 40
    pillarScrollOffset = pillarScrollOffset + scrollSpeed * dt
    if pillarScrollOffset >= PILLAR_SPACING then
        pillarScrollOffset = pillarScrollOffset - PILLAR_SPACING
    end
    local pillarOffset = pillarScrollOffset
    local pIdx = 0
    for i = 0, 7 do
        local baseY = i * PILLAR_SPACING - pillarOffset
        if baseY >= 0 and baseY < fh then
            local s = PerspScale(baseY)
            local halfW = PathHalfW(baseY)
            local cx = fw / 2
            local pilW = math.max(4 * s, 2)
            local pilH = math.max(14 * s, 3)

            -- Left pillar
            pIdx = pIdx + 1
            EnsurePool(pools.pillarL, pIdx, "ARTWORK", 1)
            local lp = pools.pillarL[pIdx]
            lp:ClearAllPoints()
            lp:SetVertexColor(0.35, 0.30, 0.22, 1)
            lp:SetSize(pilW, pilH)
            lp:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", cx - halfW - pilW, baseY)
            lp:Show()

            -- Right pillar
            EnsurePool(pools.pillarR, pIdx, "ARTWORK", 1)
            local rp = pools.pillarR[pIdx]
            rp:ClearAllPoints()
            rp:SetVertexColor(0.35, 0.30, 0.22, 1)
            rp:SetSize(pilW, pilH)
            rp:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", cx + halfW, baseY)
            rp:Show()
        end
    end
    for i = pIdx + 1, #pools.pillarL do pools.pillarL[i]:Hide() end
    for i = pIdx + 1, #pools.pillarR do pools.pillarR[i]:Hide() end

    -- Stumble feedback timer
    if stumbleTimer and stumbleTimer > 0 then
        stumbleTimer = stumbleTimer - dt
        if stumbleTimer <= 0 and stumbleFs then
            stumbleFs:SetText("")
        end
    end

    -- Obstacle approach hint
    local showingHint = false
    for _, obs in ipairs(obstacles) do
        if not obs.passed and obs.lane == playerLane
            and obs.scrollY > PLAYER_Y and obs.scrollY < PLAYER_Y + 120 then
            showingHint = true
            if hintFs then
                if obs.kind == "jump" then
                    hintFs:SetText("|cff44ff44^ JUMP ^|r")
                elseif obs.kind == "beam" then
                    hintFs:SetText("|cff44aaff- SLIDE -|r")
                end
                hintFs:Show()
            end
            break
        end
    end
    if not showingHint and hintFs then
        hintFs:Hide()
    end

    -- Player (offset by turn bending at player Y)
    local pH = isDucking and DUCK_H or PLAYER_H
    local pY = PLAYER_Y + jumpOffset
    playerTex:ClearAllPoints()
    playerTex:SetSize(PLAYER_W, pH)
    playerTex:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT",
        LaneX(playerLane, PLAYER_Y), pY)

    -- Obstacles (positioned with turn offset)
    local obsCount = 0
    local postCount = 0
    for _, obs in ipairs(obstacles) do
        if obs.scrollY > 0 and obs.scrollY < fh + 10 then
            obsCount = obsCount + 1
            EnsurePool(pools.obs, obsCount, "ARTWORK", 4)
            local tex = pools.obs[obsCount]
            local s = PerspScale(obs.scrollY)
            local w = 18 * s
            local h = 12 * s
            local cx = LaneX(obs.lane, obs.scrollY)

            if obs.kind == "jump" then
                -- Hurdle: horizontal bar on top of two posts
                local barW = math.max(w * 1.3, 5)
                local barH = math.max(3 * s, 2)
                local postW = math.max(3 * s, 2)
                local postH = math.max(h * 0.8, 4)

                -- Bar (top crossbar) — bright orange
                tex:ClearAllPoints()
                tex:SetVertexColor(0.95, 0.4, 0.05, 1)
                tex:SetSize(barW, barH)
                tex:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", cx, obs.scrollY + postH)
                tex:Show()

                -- Left post
                postCount = postCount + 1
                EnsurePool(pools.obsPost, postCount, "ARTWORK", 3)
                local lPost = pools.obsPost[postCount]
                lPost:ClearAllPoints()
                lPost:SetVertexColor(0.7, 0.3, 0.05, 1)
                lPost:SetSize(postW, postH)
                lPost:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", cx - barW * 0.35, obs.scrollY)
                lPost:Show()

                -- Right post
                postCount = postCount + 1
                EnsurePool(pools.obsPost, postCount, "ARTWORK", 3)
                local rPost = pools.obsPost[postCount]
                rPost:ClearAllPoints()
                rPost:SetVertexColor(0.7, 0.3, 0.05, 1)
                rPost:SetSize(postW, postH)
                rPost:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", cx + barW * 0.35, obs.scrollY)
                rPost:Show()

            elseif obs.kind == "beam" then
                -- Wide blue-grey beam across path — slide under
                tex:ClearAllPoints()
                tex:SetVertexColor(0.3, 0.4, 0.55, 1)
                tex:SetSize(math.max(w * 2.0, 5), math.max(h * 0.3, 2))
                tex:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", cx, obs.scrollY + h * 0.6)
                tex:Show()
            end
        end
    end
    for i = obsCount + 1, #pools.obs do pools.obs[i]:Hide() end
    for i = postCount + 1, #pools.obsPost do pools.obsPost[i]:Hide() end

    -- Coins
    local cCount = 0
    for _, c in ipairs(coins) do
        if not c.collected and c.scrollY > 0 and c.scrollY < fh + 10 then
            cCount = cCount + 1
            EnsureCoinPool(cCount)
            local tex = pools.coin[cCount]
            local s = PerspScale(c.scrollY)
            local sz = math.max(8 * s, 2)
            tex:ClearAllPoints()
            tex:SetSize(sz, sz)
            tex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT",
                LaneX(c.lane, c.scrollY), c.scrollY)
            tex:Show()
        end
    end
    for i = cCount + 1, #pools.coin do pools.coin[i]:Hide() end
end

-- ============================================================
-- Input
-- ============================================================
local function HandleInput(key)
    if gameOver then
        ResetGame()
        return true
    end
    if not gameActive then
        gameActive = true
        startMsg:Hide()
        lastTime = 0
        return true
    end

    if key == "LEFT" or key == "a" or key == "A" then
        if playerLane > 1 then playerLane = playerLane - 1 end
        return true
    elseif key == "RIGHT" or key == "d" or key == "D" then
        if playerLane < LANES then playerLane = playerLane + 1 end
        return true
    elseif key == "UP" or key == "w" or key == "W" or key == "SPACE" then
        if not isJumping then
            isJumping = true
            isDucking = false
            playerVelY = JUMP_VEL
        end
        return true
    elseif key == "DOWN" or key == "s" or key == "S" then
        if not isJumping then
            isDucking = true
        end
        return true
    end
    return false
end

local function HandleKeyUp(key)
    if key == "DOWN" or key == "s" or key == "S" then
        isDucking = false
    end
end

local function HandleClick(localX, localY)
    if gameOver then ResetGame() return end
    if not gameActive then
        gameActive = true
        startMsg:Hide()
        lastTime = 0
        return
    end

    local fw = frameW or 140
    local fh = frameH or 200
    local thirdW = fw / 3
    local midY = fh / 2

    if localY > midY + fh * 0.15 then
        -- Top area: jump
        if not isJumping then
            isJumping = true
            isDucking = false
            playerVelY = JUMP_VEL
        end
    elseif localY < midY - fh * 0.15 then
        -- Bottom area: slide
        if not isJumping then isDucking = true end
        C_Timer.After(0.4, function() isDucking = false end)
    elseif localX < thirdW then
        if playerLane > 1 then playerLane = playerLane - 1 end
    elseif localX > fw - thirdW then
        if playerLane < LANES then playerLane = playerLane + 1 end
    else
        -- Center: jump
        if not isJumping then
            isJumping = true
            isDucking = false
            playerVelY = JUMP_VEL
        end
    end
end

-- ============================================================
-- Init
-- ============================================================
function PhoneTempleRunGame:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.bestTempleRun or 0

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 6, -2)
    title:SetText("|cffddaa44Temple Run|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Score
    scoreFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreFs:SetPoint("TOPRIGHT", -6, -2)
    scoreFs:SetText("|cffffffff0m|r")
    local scf = scoreFs:GetFont()
    if scf then scoreFs:SetFont(scf, 9, "OUTLINE") end

    -- Coin counter
    coinFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    coinFs:SetPoint("TOPRIGHT", -6, -12)
    coinFs:SetText("|cffffff000|r")
    local ccf = coinFs:GetFont()
    if ccf then coinFs:SetFont(ccf, 8, "OUTLINE") end

    -- Message (centered for game over)
    msgFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    msgFs:SetPoint("CENTER", parent, "CENTER", 0, 10)
    local mf = msgFs:GetFont()
    if mf then msgFs:SetFont(mf, 8, "OUTLINE") end

    -- Game area
    gameFrame = CreateFrame("Button", nil, parent)
    gameFrame:SetPoint("TOPLEFT", 2, -22)
    gameFrame:SetPoint("BOTTOMRIGHT", -2, 8)
    gameFrame:SetClipsChildren(true)

    -- Dark jungle background
    local gameBg = gameFrame:CreateTexture(nil, "BACKGROUND")
    gameBg:SetAllPoints()
    gameBg:SetTexture(WHITE)
    gameBg:SetVertexColor(0.04, 0.06, 0.03, 1)

    -- Player
    playerTex = gameFrame:CreateTexture(nil, "OVERLAY", nil, 5)
    playerTex:SetSize(PLAYER_W, PLAYER_H)
    playerTex:SetTexture(SPRITE_PATH .. "SpriteRunner")

    -- Hit flash overlay (full screen red flash on damage)
    hitFlash = gameFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    hitFlash:SetAllPoints()
    hitFlash:SetTexture(WHITE)
    hitFlash:SetVertexColor(0.8, 0.0, 0.0, 0.4)
    hitFlash:Hide()

    -- Lives display (top left of game area)
    livesFs = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    livesFs:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", 4, -2)
    local lvf = livesFs:GetFont()
    if lvf then livesFs:SetFont(lvf, 9, "OUTLINE") end
    livesFs:SetText("|cffff0000<3 <3 <3|r")

    -- Stumble feedback (center, below top)
    stumbleFs = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stumbleFs:SetPoint("TOP", gameFrame, "TOP", 0, -16)
    local stf = stumbleFs:GetFont()
    if stf then stumbleFs:SetFont(stf, 8, "OUTLINE") end

    -- Obstacle hint (above player)
    hintFs = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintFs:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", (frameW or 140) / 2, PLAYER_Y + PLAYER_H + 20)
    local hf = hintFs:GetFont()
    if hf then hintFs:SetFont(hf, 8, "OUTLINE") end
    hintFs:Hide()

    -- Start message
    startMsg = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    startMsg:SetPoint("CENTER", 0, 20)
    startMsg:SetText("|cff888888Click or press a key!\n\n"
        .. "|cffddaa44A / D|r|cff888888 = switch lane\n"
        .. "|cffddaa44W|r|cff888888 = jump over |r|cffee6622blocks|r\n"
        .. "|cffddaa44S|r|cff888888 = slide under |r|cff4466aabeams|r")
    local smf = startMsg:GetFont()
    if smf then startMsg:SetFont(smf, 8, "") end

    -- Click handler
    gameFrame:SetScript("OnClick", function(self)
        local scale = self:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx = cx / scale
        cy = cy / scale
        local left = self:GetLeft() or 0
        local bot = self:GetBottom() or 0
        HandleClick(cx - left, cy - bot)
    end)

    -- Keyboard
    local keyFrame = CreateFrame("Frame", "PhoneTempleRunKeyFrame", gameFrame)
    keyFrame:SetAllPoints()
    keyFrame:SetPropagateKeyboardInput(true)
    keyFrame:SetScript("OnKeyDown", function(self, key)
        if not parent:IsShown() then return end
        if HandleInput(key) then
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    keyFrame:SetScript("OnKeyUp", function(self, key)
        if not parent:IsShown() then return end
        HandleKeyUp(key)
    end)

    -- Game loop
    gameFrame:SetScript("OnUpdate", OnUpdate)

    C_Timer.After(0, function()
        frameW = gameFrame:GetWidth() or 140
        frameH = gameFrame:GetHeight() or 200
        CreatePathTextures()
        UpdatePath()
        ResetGame()
    end)
end

function PhoneTempleRunGame:OnShow()
    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.bestTempleRun or 0
    lastTime = 0
    if gameFrame then
        frameW = gameFrame:GetWidth() or 140
        frameH = gameFrame:GetHeight() or 200
        CreatePathTextures()
        UpdatePath()
    end
    ResetGame()
    if PhoneTempleRunKeyFrame then
        PhoneTempleRunKeyFrame:EnableKeyboard(true)
    end
end

function PhoneTempleRunGame:OnHide()
    gameActive = false
    if PhoneTempleRunKeyFrame then
        PhoneTempleRunKeyFrame:EnableKeyboard(false)
    end
end
