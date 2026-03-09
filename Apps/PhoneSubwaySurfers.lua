-- PhoneSubwaySurfers - Subway Surfers style endless runner for HearthPhone
-- Vertical top-down scrolling: player runs forward, obstacles scroll toward player

PhoneSubwaySurfersGame = {}

local parent
local gameFrame, scoreFs, msgFs, startMsg
local SPRITE_PATH = "Interface\\AddOns\\HearthPhone\\Textures\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local LANES = 3
local LANE_SPACING = 22
local PLAYER_W = 14
local PLAYER_H = 18
local PLAYER_Y = 30        -- player Y from bottom
local OBS_W = 18
local OBS_H = 14
local COIN_SIZE = 7
local TRAIN_W = 20
local TRAIN_H = 32

-- Jump
local JUMP_VEL = 180
local GRAVITY = 500
local DUCK_TIME = 0.4

local frameW, frameH
local score, bestScore, coinCount
local gameActive, gameOver
local lastTime = 0

local playerLane
local isJumping, jumpVelY, jumpZ
local isDucking, duckTimer

local obstacles = {}
local coins = {}
local trains = {}

local obsPool = {}
local coinPool = {}
local trainPool = {}
local playerTex

local scrollSpeed
local spawnTimer
local distance

-- Track visuals
local trackStrips = {}
local trackEdgeL, trackEdgeR
local tileLines = {}
local TILE_LINE_COUNT = 10
local tileScrollOffset = 0

-- ============================================================
-- Helpers
-- ============================================================
local function LaneX(lane)
    -- lane 1=left, 2=center, 3=right
    local cx = (frameW or 140) / 2
    return cx + (lane - 2) * LANE_SPACING
end

local function EnsurePool(pool, count, layer, sublevel)
    while #pool < count do
        local tex = gameFrame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
        tex:Hide()
        pool[#pool + 1] = tex
    end
end

local function SpawnObstacle()
    local lane = math.random(1, LANES)
    local kind = math.random(1, 5)
    local topY = (frameH or 200) + 20

    if kind <= 2 then
        -- Barrier obstacle (must jump over)
        table.insert(obstacles, {
            lane = lane,
            y = topY,
            w = OBS_W,
            h = OBS_H,
            otype = "barrier",
        })
    elseif kind <= 3 then
        -- Low obstacle (must jump or dodge)
        table.insert(obstacles, {
            lane = lane,
            y = topY,
            w = OBS_W,
            h = OBS_H,
            otype = "low",
        })
    else
        -- Train (stationary-looking, tall, must dodge around)
        table.insert(trains, {
            lane = lane,
            y = topY,
            w = TRAIN_W,
            h = TRAIN_H,
        })
    end

    -- Coins in another lane
    if math.random() < 0.65 then
        local coinLane = lane
        while coinLane == lane do
            coinLane = math.random(1, LANES)
        end
        local count = math.random(3, 5)
        for c = 0, count - 1 do
            table.insert(coins, {
                lane = coinLane,
                y = topY + c * 12,
                collected = false,
            })
        end
    end
end

local function CreateTrackVisuals()
    -- Track background strips (3 lane columns)
    local colors = {
        { 0.20, 0.20, 0.26 },
        { 0.16, 0.16, 0.22 },
        { 0.20, 0.20, 0.26 },
    }
    for i = 1, LANES do
        if not trackStrips[i] then
            trackStrips[i] = gameFrame:CreateTexture(nil, "BORDER")
            trackStrips[i]:SetTexture(WHITE)
        end
        local c = colors[i]
        trackStrips[i]:SetVertexColor(c[1], c[2], c[3], 1)
    end

    -- Track edges
    if not trackEdgeL then
        trackEdgeL = gameFrame:CreateTexture(nil, "BORDER", nil, 1)
        trackEdgeL:SetTexture(WHITE)
        trackEdgeL:SetVertexColor(0.35, 0.35, 0.15, 1)
    end
    if not trackEdgeR then
        trackEdgeR = gameFrame:CreateTexture(nil, "BORDER", nil, 1)
        trackEdgeR:SetTexture(WHITE)
        trackEdgeR:SetVertexColor(0.35, 0.35, 0.15, 1)
    end

    -- Horizontal tile lines for scrolling ground effect
    for i = 1, TILE_LINE_COUNT do
        if not tileLines[i] then
            tileLines[i] = gameFrame:CreateTexture(nil, "BORDER", nil, 2)
            tileLines[i]:SetTexture(WHITE)
            tileLines[i]:SetVertexColor(0.25, 0.25, 0.30, 0.5)
        end
    end
end

local function UpdateTrackVisuals()
    if not frameW or not frameH then return end
    local cx = frameW / 2
    local trackW = LANE_SPACING * LANES + 8

    for i = 1, LANES do
        local lx = LaneX(i)
        trackStrips[i]:ClearAllPoints()
        trackStrips[i]:SetSize(LANE_SPACING, frameH)
        trackStrips[i]:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", lx, frameH / 2)
        trackStrips[i]:Show()
    end

    -- Edges
    local leftEdge = cx - trackW / 2
    local rightEdge = cx + trackW / 2
    trackEdgeL:ClearAllPoints()
    trackEdgeL:SetSize(3, frameH)
    trackEdgeL:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", leftEdge, frameH / 2)
    trackEdgeL:Show()
    trackEdgeR:ClearAllPoints()
    trackEdgeR:SetSize(3, frameH)
    trackEdgeR:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", rightEdge, frameH / 2)
    trackEdgeR:Show()
end

local function UpdateTileLines(dt)
    if not frameW or not frameH then return end
    local spacing = frameH / TILE_LINE_COUNT
    tileScrollOffset = tileScrollOffset + scrollSpeed * dt
    if tileScrollOffset >= spacing then
        tileScrollOffset = tileScrollOffset - spacing
    end

    local cx = frameW / 2
    local trackW = LANE_SPACING * LANES + 4

    for i = 1, TILE_LINE_COUNT do
        local y = frameH - (i - 1) * spacing + tileScrollOffset
        if y > frameH + spacing then y = y - frameH - spacing end
        tileLines[i]:ClearAllPoints()
        tileLines[i]:SetSize(trackW, 1)
        tileLines[i]:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", cx, y)
        tileLines[i]:Show()
    end
end

local function ResetGame()
    frameW = gameFrame:GetWidth() or 140
    frameH = gameFrame:GetHeight() or 200

    playerLane = 2
    isJumping = false
    jumpVelY = 0
    jumpZ = 0
    isDucking = false
    duckTimer = 0
    score = 0
    coinCount = 0
    distance = 0
    gameOver = false
    gameActive = false
    scrollSpeed = 80
    spawnTimer = 0
    lastTime = 0
    tileScrollOffset = 0

    wipe(obstacles)
    wipe(coins)
    wipe(trains)
    for _, f in ipairs(obsPool) do f:Hide() end
    for _, f in ipairs(coinPool) do f:Hide() end
    for _, f in ipairs(trainPool) do f:Hide() end

    scoreFs:SetText("|cffffffff0|r")
    msgFs:SetText("")
    startMsg:Show()

    playerTex:ClearAllPoints()
    playerTex:SetSize(PLAYER_W, PLAYER_H)
    playerTex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", LaneX(playerLane), PLAYER_Y)
    playerTex:Show()

    UpdateTrackVisuals()
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

    -- Distance & speed ramp
    distance = distance + scrollSpeed * dt * 0.15
    scrollSpeed = 80 + distance * 0.5
    if scrollSpeed > 220 then scrollSpeed = 220 end

    -- Score
    score = math.floor(distance) + coinCount * 5
    scoreFs:SetText("|cffffffff" .. score .. "|r")

    -- Duck timer
    if isDucking then
        duckTimer = duckTimer - dt
        if duckTimer <= 0 then
            isDucking = false
            playerTex:SetSize(PLAYER_W, PLAYER_H)
        end
    end

    -- Jump physics
    if isJumping then
        jumpZ = jumpZ + jumpVelY * dt
        jumpVelY = jumpVelY - GRAVITY * dt
        if jumpZ <= 0 then
            jumpZ = 0
            isJumping = false
            jumpVelY = 0
        end
    end

    -- Spawn
    spawnTimer = spawnTimer + dt
    local interval = 0.9 - distance * 0.004
    if interval < 0.35 then interval = 0.35 end
    if spawnTimer >= interval then
        spawnTimer = 0
        SpawnObstacle()
    end

    -- Tile lines
    UpdateTileLines(dt)

    -- Move obstacles toward player
    local toRemove = {}
    for i, obs in ipairs(obstacles) do
        obs.y = obs.y - scrollSpeed * dt
        if obs.y < -30 then
            table.insert(toRemove, i)
        end
    end
    for ri = #toRemove, 1, -1 do
        table.remove(obstacles, toRemove[ri])
    end

    -- Move trains toward player (they scroll with the ground)
    toRemove = {}
    for i, tr in ipairs(trains) do
        tr.y = tr.y - scrollSpeed * dt
        if tr.y < -40 then
            table.insert(toRemove, i)
        end
    end
    for ri = #toRemove, 1, -1 do
        table.remove(trains, toRemove[ri])
    end

    -- Move coins toward player
    toRemove = {}
    for i, coin in ipairs(coins) do
        coin.y = coin.y - scrollSpeed * dt
        if coin.y < -20 then
            table.insert(toRemove, i)
        end
    end
    for ri = #toRemove, 1, -1 do
        table.remove(coins, toRemove[ri])
    end

    -- Collision detection
    local px = LaneX(playerLane)
    local pBot = PLAYER_Y - PLAYER_H / 2
    local pTop = PLAYER_Y + PLAYER_H / 2

    -- Obstacles
    for _, obs in ipairs(obstacles) do
        if obs.lane == playerLane then
            local oBot = obs.y - obs.h / 2
            local oTop = obs.y + obs.h / 2
            if pTop > oBot and pBot < oTop then
                -- Can jump over barriers
                if obs.otype == "barrier" and jumpZ > 12 then
                    -- cleared
                else
                    gameOver = true
                end
            end
        end
    end

    -- Trains
    for _, tr in ipairs(trains) do
        if tr.lane == playerLane then
            local tBot = tr.y - tr.h / 2
            local tTop = tr.y + tr.h / 2
            if pTop > tBot and pBot < tTop then
                -- Cannot jump over trains (too tall)
                gameOver = true
            end
        end
    end

    -- Coin collection
    for _, coin in ipairs(coins) do
        if not coin.collected and coin.lane == playerLane then
            local dy = PLAYER_Y - coin.y
            if math.abs(dy) < (PLAYER_H + COIN_SIZE) / 2 then
                coin.collected = true
                coinCount = coinCount + 1
            end
        end
    end

    if gameOver then
        local finalScore = score
        if finalScore > bestScore then
            bestScore = finalScore
            HearthPhoneDB = HearthPhoneDB or {}
            HearthPhoneDB.bestSubway = bestScore
        end
        msgFs:SetText("|cffff4444Game Over!|r\n|cffffffff" .. finalScore .. "m|r")
        return
    end

    -- Draw player
    local drawY = PLAYER_Y + jumpZ
    playerTex:ClearAllPoints()
    playerTex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", px, drawY)

    -- Draw obstacles
    EnsurePool(obsPool, #obstacles, "ARTWORK", 2)
    for i, obs in ipairs(obstacles) do
        local tex = obsPool[i]
        if not tex.textureSet then
            tex:SetTexture(SPRITE_PATH .. "SpriteRunObstacle")
            tex.textureSet = true
        end
        tex:ClearAllPoints()
        tex:SetSize(obs.w, obs.h)
        tex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", LaneX(obs.lane), obs.y)
        if obs.otype == "barrier" then
            tex:SetVertexColor(0.8, 0.5, 0.2, 1)
        else
            tex:SetVertexColor(0.7, 0.7, 0.7, 1)
        end
        tex:Show()
    end
    for i = #obstacles + 1, #obsPool do obsPool[i]:Hide() end

    -- Draw trains
    EnsurePool(trainPool, #trains, "ARTWORK", 1)
    for i, tr in ipairs(trains) do
        local tex = trainPool[i]
        if not tex.textureSet then
            tex:SetTexture(SPRITE_PATH .. "SpriteRunTrain")
            tex.textureSet = true
        end
        tex:ClearAllPoints()
        tex:SetSize(tr.w, tr.h)
        tex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", LaneX(tr.lane), tr.y)
        tex:Show()
    end
    for i = #trains + 1, #trainPool do trainPool[i]:Hide() end

    -- Draw coins
    EnsurePool(coinPool, #coins, "OVERLAY", 0)
    for i, coin in ipairs(coins) do
        local tex = coinPool[i]
        if not tex.textureSet then
            tex:SetTexture(SPRITE_PATH .. "SpriteRunCoin")
            tex.textureSet = true
        end
        if not coin.collected then
            tex:ClearAllPoints()
            tex:SetSize(COIN_SIZE, COIN_SIZE)
            tex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", LaneX(coin.lane), coin.y)
            tex:Show()
        else
            tex:Hide()
        end
    end
    for i = #coins + 1, #coinPool do coinPool[i]:Hide() end
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
            jumpVelY = JUMP_VEL
            jumpZ = 0
        end
        return true
    elseif key == "DOWN" or key == "s" or key == "S" then
        isDucking = true
        duckTimer = DUCK_TIME
        playerTex:SetSize(PLAYER_W, PLAYER_H * 0.5)
        return true
    end

    return false
end

local function HandleClick(localX, localY)
    if gameOver then
        ResetGame()
        return
    end
    if not gameActive then
        gameActive = true
        startMsg:Hide()
        lastTime = 0
        return
    end

    local fw = frameW or 140
    local fh = frameH or 200
    local thirdW = fw / 3

    if localX < thirdW then
        -- Left third: dodge left
        if playerLane > 1 then playerLane = playerLane - 1 end
    elseif localX > fw - thirdW then
        -- Right third: dodge right
        if playerLane < LANES then playerLane = playerLane + 1 end
    elseif localY > fh * 0.5 then
        -- Upper center: jump
        if not isJumping then
            isJumping = true
            jumpVelY = JUMP_VEL
            jumpZ = 0
        end
    else
        -- Lower center: duck
        isDucking = true
        duckTimer = DUCK_TIME
        playerTex:SetSize(PLAYER_W, PLAYER_H * 0.5)
    end
end

-- ============================================================
-- Init
-- ============================================================
function PhoneSubwaySurfersGame:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.bestSubway or 0

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cff44ccffSubway Surf|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Score
    scoreFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreFs:SetPoint("TOPRIGHT", -6, -2)
    scoreFs:SetText("|cffffffff0|r")
    local scf = scoreFs:GetFont()
    if scf then scoreFs:SetFont(scf, 9, "OUTLINE") end

    -- Message
    msgFs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    msgFs:SetPoint("CENTER", 0, 20)
    local mf = msgFs:GetFont()
    if mf then msgFs:SetFont(mf, 8, "OUTLINE") end

    -- Game area
    gameFrame = CreateFrame("Button", nil, parent)
    gameFrame:SetPoint("TOPLEFT", 2, -26)
    gameFrame:SetPoint("BOTTOMRIGHT", -2, 8)
    gameFrame:SetClipsChildren(true)

    local gameBg = gameFrame:CreateTexture(nil, "BACKGROUND")
    gameBg:SetAllPoints()
    gameBg:SetTexture(WHITE)
    gameBg:SetVertexColor(0.12, 0.12, 0.18, 1)

    -- Player
    playerTex = gameFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    playerTex:SetSize(PLAYER_W, PLAYER_H)
    playerTex:SetTexture(SPRITE_PATH .. "SpriteSurfer")

    -- Start message
    startMsg = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    startMsg:SetPoint("CENTER", 0, 20)
    startMsg:SetText("|cff888888Click or press a key!\nL/R to dodge, Up=jump|r")
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
    local keyFrame = CreateFrame("Frame", "PhoneSubwayKeyFrame", gameFrame)
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

    -- Game loop
    gameFrame:SetScript("OnUpdate", OnUpdate)

    -- Create track visuals
    CreateTrackVisuals()

    C_Timer.After(0, function()
        frameW = gameFrame:GetWidth() or 140
        frameH = gameFrame:GetHeight() or 200
        UpdateTrackVisuals()
        ResetGame()
    end)
end

function PhoneSubwaySurfersGame:OnShow()
    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.bestSubway or 0
    lastTime = 0
    if gameFrame then
        frameW = gameFrame:GetWidth() or 140
        frameH = gameFrame:GetHeight() or 200
        UpdateTrackVisuals()
    end
    ResetGame()
    if PhoneSubwayKeyFrame then
        PhoneSubwayKeyFrame:EnableKeyboard(true)
    end
end

function PhoneSubwaySurfersGame:OnHide()
    gameActive = false
    if PhoneSubwayKeyFrame then
        PhoneSubwayKeyFrame:EnableKeyboard(false)
    end
end
