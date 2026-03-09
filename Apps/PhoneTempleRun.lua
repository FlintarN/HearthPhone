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
local turnEvents = {}

-- Turn input: player must press matching direction
local turnInputPending = false  -- a turn is in the reaction zone
local turnInputDir = nil        -- which direction is needed ("LEFT"/"RIGHT")
local turnHandled = false       -- player pressed correct direction

-- Timers
local obsTimer, coinTimer, turnTimer, nextTurnAt

-- Texture pools
local obsPool = {}
local coinPool = {}
local turnWallPool = {}
local sidePathPool = {}
local arrowPool = {}

-- Visual elements
local playerTex
local pathStrips = {}
local pathEdgeL = {}
local pathEdgeR = {}
local tileLines = {}
local monkeyTex, monkeyGlow

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

-- ============================================================
-- Turn offset: path bends at turn points
-- Returns horizontal pixel offset for a given screenY
-- ============================================================
local function GetTurnOffset(screenY)
    local offset = 0
    for _, t in ipairs(turnEvents) do
        if screenY > t.scrollY and t.scrollY > 0 then
            -- Above the turn point: path curves away
            local dist = screenY - t.scrollY
            local maxBend = 60  -- max pixel offset
            local bendFrac = dist / 80
            if bendFrac > 1 then bendFrac = 1 end
            -- Smooth ease-in curve
            local bend = maxBend * bendFrac * bendFrac
            if t.dir == "LEFT" then
                offset = offset - bend
            else
                offset = offset + bend
            end
        end
    end
    return offset
end

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
    while #coinPool < count do
        local tex = gameFrame:CreateTexture(nil, "ARTWORK", nil, 2)
        tex:SetTexture(SPRITE_PATH .. "SpriteRunCoin")
        tex:Hide()
        coinPool[#coinPool + 1] = tex
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
        local cx = fw / 2 + GetTurnOffset(midY)
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
            local cx = fw / 2 + GetTurnOffset(baseY)
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
    local kind
    if distance < 40 then
        kind = math.random(1, 2) == 1 and "root" or "fire"
    elseif distance < 100 then
        local r = math.random(1, 10)
        if r <= 4 then kind = "root"
        elseif r <= 6 then kind = "fire"
        elseif r <= 8 then kind = "beam"
        else kind = "gap" end
    else
        local r = math.random(1, 12)
        if r <= 3 then kind = "root"
        elseif r <= 5 then kind = "fire"
        elseif r <= 7 then kind = "beam"
        elseif r <= 9 then kind = "gap"
        else
            kind = math.random(1, 2) == 1 and "root" or "fire"
            local lane2 = lane
            while lane2 == lane do lane2 = math.random(1, LANES) end
            table.insert(obstacles, {
                lane = lane2,
                scrollY = (frameH or 200) + 20,
                kind = kind,
                passed = false,
            })
        end
    end
    table.insert(obstacles, {
        lane = lane,
        scrollY = (frameH or 200) + 20,
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

local function SpawnTurn()
    local dir = math.random(1, 2) == 1 and "LEFT" or "RIGHT"
    table.insert(turnEvents, {
        scrollY = (frameH or 200) + 60,
        dir = dir,
        handled = false,
        reactionZone = false,
    })
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
    scrollSpeed = 70
    stumbles = 0
    lastTime = 0
    obsTimer = 0
    coinTimer = 0
    turnTimer = 0
    nextTurnAt = 5 + math.random() * 3
    tileScrollOffset = 0
    turnInputPending = false
    turnInputDir = nil
    turnHandled = false

    wipe(obstacles)
    wipe(coins)
    wipe(turnEvents)
    for _, f in ipairs(obsPool) do f:Hide() end
    for _, f in ipairs(coinPool) do f:Hide() end
    for _, f in ipairs(turnWallPool) do f:Hide() end
    for _, f in ipairs(sidePathPool) do f:Hide() end
    for _, f in ipairs(arrowPool) do f:Hide() end

    scoreFs:SetText("|cffffffff0m|r")
    coinFs:SetText("|cffffff000|r")
    msgFs:SetText("")
    startMsg:Show()

    if monkeyTex then monkeyTex:Hide() end
    if monkeyGlow then monkeyGlow:Hide() end

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
    local obsH = 16 * s
    if obsScreenY > PLAYER_Y + PLAYER_H or obsScreenY + obsH < PLAYER_Y then
        return false
    end
    if obs.kind == "root" or obs.kind == "fire" then
        if jumpOffset > 8 then return false end
        return true
    elseif obs.kind == "beam" then
        if isDucking then return false end
        return true
    elseif obs.kind == "gap" then
        if jumpOffset > 4 then return false end
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

    -- Speed ramp
    scrollSpeed = 70 + distance * 0.4
    if scrollSpeed > 200 then scrollSpeed = 200 end

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
    local obsInterval = 1.0 - distance * 0.003
    if obsInterval < 0.45 then obsInterval = 0.45 end
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

    -- Spawn turns
    turnTimer = turnTimer + dt
    if turnTimer >= nextTurnAt and distance > 30 then
        turnTimer = 0
        nextTurnAt = 4 + math.random() * 4
        SpawnTurn()
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

    -- Move turns + handle turn logic
    turnInputPending = false
    turnInputDir = nil
    toRm = {}
    for i, t in ipairs(turnEvents) do
        t.scrollY = t.scrollY - scrollSpeed * dt * 0.85

        -- Reaction zone: turn is close to player (within ~50px above)
        local REACT_TOP = PLAYER_Y + 60
        local REACT_BOT = PLAYER_Y - 5

        if t.scrollY < REACT_TOP and t.scrollY > REACT_BOT and not t.handled then
            turnInputPending = true
            turnInputDir = t.dir

            -- Check if player already pressed correct direction
            if turnHandled then
                t.handled = true
                turnHandled = false
            end
        end

        -- Turn passed player without being handled = crash into wall
        if t.scrollY <= REACT_BOT and not t.handled then
            t.handled = true
            gameOver = true
        end

        if t.scrollY < -80 then
            table.insert(toRm, i)
        end
    end
    for ri = #toRm, 1, -1 do
        table.remove(turnEvents, toRm[ri])
    end

    -- Collision: obstacles
    for _, obs in ipairs(obstacles) do
        if not obs.passed and PlayerHitsObs(obs) then
            stumbles = stumbles + 1
            if stumbles >= 3 then
                gameOver = true
            else
                obs.passed = true
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

    -- Player (offset by turn bending at player Y)
    local pH = isDucking and DUCK_H or PLAYER_H
    local pY = PLAYER_Y + jumpOffset
    local pTurnOff = GetTurnOffset(PLAYER_Y)
    playerTex:ClearAllPoints()
    playerTex:SetSize(PLAYER_W, pH)
    playerTex:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT",
        LaneX(playerLane, PLAYER_Y) + pTurnOff, pY)

    -- Demon monkey
    if stumbles > 0 and monkeyTex then
        local alpha = stumbles * 0.35
        if alpha > 1 then alpha = 1 end
        monkeyTex:SetAlpha(alpha)
        monkeyTex:Show()
        monkeyGlow:SetAlpha(alpha * 0.5)
        monkeyGlow:Show()
    elseif monkeyTex then
        monkeyTex:Hide()
        monkeyGlow:Hide()
    end

    -- Obstacles (positioned with turn offset)
    local obsCount = 0
    for _, obs in ipairs(obstacles) do
        if obs.scrollY > 0 and obs.scrollY < fh + 10 then
            obsCount = obsCount + 1
            EnsurePool(obsPool, obsCount, "ARTWORK", 4)
            local tex = obsPool[obsCount]
            local s = PerspScale(obs.scrollY)
            local w = 18 * s
            local h = 12 * s
            local tOff = GetTurnOffset(obs.scrollY)

            tex:ClearAllPoints()
            tex:SetSize(math.max(w, 2), math.max(h, 2))
            tex:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT",
                LaneX(obs.lane, obs.scrollY) + tOff, obs.scrollY)

            if obs.kind == "root" then
                tex:SetVertexColor(0.35, 0.25, 0.12, 1)
            elseif obs.kind == "fire" then
                tex:SetVertexColor(0.9, 0.35, 0.05, 1)
            elseif obs.kind == "beam" then
                tex:SetVertexColor(0.30, 0.22, 0.10, 1)
                tex:SetSize(math.max(w * 1.3, 3), math.max(h * 0.5, 2))
            elseif obs.kind == "gap" then
                tex:SetVertexColor(0.02, 0.02, 0.02, 1)
                tex:SetSize(math.max(w * 1.2, 3), math.max(h * 0.8, 2))
            end
            tex:Show()
        end
    end
    for i = obsCount + 1, #obsPool do obsPool[i]:Hide() end

    -- Turn walls + direction arrows on ground
    local twCount = 0
    local arCount = 0
    for _, t in ipairs(turnEvents) do
        -- Wall at the turn point
        if t.scrollY > -20 and t.scrollY < fh + 20 then
            twCount = twCount + 1
            EnsurePool(turnWallPool, twCount, "ARTWORK", 5)
            local tex = turnWallPool[twCount]
            local s = PerspScale(t.scrollY)
            local halfW = PathHalfW(t.scrollY)
            local cx = fw / 2 + GetTurnOffset(t.scrollY)
            local wallH = math.max(22 * s, 3)

            tex:ClearAllPoints()
            tex:SetVertexColor(0.45, 0.38, 0.28, 0.95)
            tex:SetSize(halfW * 2, wallH)
            tex:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", cx, t.scrollY)
            tex:Show()
        end

        -- Arrow indicators on the path approaching the turn
        -- Draw 3 arrows below the turn point (between turn and player)
        for a = 1, 3 do
            local arrowY = t.scrollY - a * 18
            if arrowY > 5 and arrowY < fh then
                arCount = arCount + 1
                EnsurePool(arrowPool, arCount, "ARTWORK", 3)
                local atex = arrowPool[arCount]
                local aS = PerspScale(arrowY)
                local aCx = fw / 2 + GetTurnOffset(arrowY)
                local arrowW = math.max(10 * aS, 3)
                local arrowH = math.max(4 * aS, 2)

                -- Offset arrow in the turn direction to hint where to go
                local arrowOff = (t.dir == "LEFT") and (-8 * aS) or (8 * aS)

                atex:ClearAllPoints()
                -- Gold/yellow arrow color, pulsing with distance
                local pulse = 0.7 + 0.3 * math.abs(math.sin(now * 4 + a))
                atex:SetVertexColor(0.9 * pulse, 0.7 * pulse, 0.1, 0.8)
                atex:SetSize(arrowW, arrowH)
                atex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT",
                    aCx + arrowOff, arrowY)
                atex:Show()
            end
        end
    end
    for i = twCount + 1, #turnWallPool do turnWallPool[i]:Hide() end
    for i = arCount + 1, #arrowPool do arrowPool[i]:Hide() end

    -- Coins (with turn offset)
    local cCount = 0
    for _, c in ipairs(coins) do
        if not c.collected and c.scrollY > 0 and c.scrollY < fh + 10 then
            cCount = cCount + 1
            EnsureCoinPool(cCount)
            local tex = coinPool[cCount]
            local s = PerspScale(c.scrollY)
            local sz = math.max(8 * s, 2)
            local tOff = GetTurnOffset(c.scrollY)
            tex:ClearAllPoints()
            tex:SetSize(sz, sz)
            tex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT",
                LaneX(c.lane, c.scrollY) + tOff, c.scrollY)
            tex:Show()
        end
    end
    for i = cCount + 1, #coinPool do coinPool[i]:Hide() end
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
        -- Check if this is a turn response
        if turnInputPending and turnInputDir == "LEFT" then
            turnHandled = true
        end
        if playerLane > 1 then playerLane = playerLane - 1 end
        return true
    elseif key == "RIGHT" or key == "d" or key == "D" then
        if turnInputPending and turnInputDir == "RIGHT" then
            turnHandled = true
        end
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
        -- Left: turn response + dodge
        if turnInputPending and turnInputDir == "LEFT" then
            turnHandled = true
        end
        if playerLane > 1 then playerLane = playerLane - 1 end
    elseif localX > fw - thirdW then
        -- Right: turn response + dodge
        if turnInputPending and turnInputDir == "RIGHT" then
            turnHandled = true
        end
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

    -- Demon monkey (red eyes at top)
    monkeyGlow = gameFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    monkeyGlow:SetSize(60, 30)
    monkeyGlow:SetPoint("TOP", gameFrame, "TOP", 0, 0)
    monkeyGlow:SetTexture(WHITE)
    monkeyGlow:SetVertexColor(0.6, 0.0, 0.0, 0.5)
    monkeyGlow:Hide()

    monkeyTex = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    monkeyTex:SetPoint("TOP", gameFrame, "TOP", 0, -2)
    local mkf = monkeyTex:GetFont()
    if mkf then monkeyTex:SetFont(mkf, 14, "OUTLINE") end
    monkeyTex:SetText("|cffff0000> . <|r")
    monkeyTex:Hide()

    -- Start message
    startMsg = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    startMsg:SetPoint("CENTER", 0, 20)
    startMsg:SetText("|cff888888Click or press a key!\n\n"
        .. "|cffddaa44Left/Right|r|cff888888 = dodge + turn\n"
        .. "|cffddaa44Up/Space|r|cff888888 = jump\n"
        .. "|cffddaa44Down|r|cff888888 = slide\n\n"
        .. "Follow where the path goes!|r")
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
