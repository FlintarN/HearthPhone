-- PhoneFlappyBird - Flappy bird clone for HearthPhone

PhoneFlappyBirdGame = {}

local parent
local gameFrame, birdTex, scoreFs, msgFs, startMsg
local pipes = {}
local pipeFrames = {}

local SPRITE_PATH = "Interface\\AddOns\\HearthPhone\\Textures\\"
local BIRD_SIZE = 14
local GRAVITY = 400
local FLAP_VEL = 150
local PIPE_SPEED = 55
local PIPE_WIDTH = 18

local birdX, birdY, birdVel
local score, bestScore
local gameActive, gameOver
local frameW, frameH
local lastTime = 0

-- Difficulty scales with score
local function GetPipeGap()
    local gap = 90 - (score or 0) * 3
    if gap < 40 then gap = 40 end
    return gap
end

local function GetPipeSpacing()
    local sp = 120 - (score or 0) * 3
    if sp < 60 then sp = 60 end
    return sp
end

local function ResetGame()
    frameW = gameFrame:GetWidth() or 160
    frameH = gameFrame:GetHeight() or 220
    birdX = math.floor(frameW * 0.25)
    birdY = frameH * 0.5
    birdVel = 0
    score = 0
    gameOver = false
    gameActive = false
    scoreFs:SetText("|cffffffff0|r")
    msgFs:SetText("")
    startMsg:Show()
    lastTime = 0

    for _, pf in ipairs(pipeFrames) do
        pf.top:Hide()
        pf.topCap:Hide()
        pf.bottom:Hide()
        pf.botCap:Hide()
    end
    wipe(pipes)

    -- Position bird
    birdTex:ClearAllPoints()
    birdTex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", birdX, birdY)
end

local function SpawnPipe(x)
    local gap = GetPipeGap()
    local margin = math.floor(gap * 0.8)
    local gapCenter = math.random(margin, math.floor(frameH - margin))
    table.insert(pipes, {
        x = x,
        gapCenter = gapCenter,
        gap = gap,
        scored = false,
    })
end

local function Flap()
    if gameOver then
        ResetGame()
        return
    end
    if not gameActive then
        gameActive = true
        startMsg:Hide()
        wipe(pipes)
        -- Spawn initial pipes starting off-screen right
        for i = 1, 4 do
            SpawnPipe(frameW + (i - 1) * GetPipeSpacing())
        end
    end
    birdVel = FLAP_VEL
end

local function EnsurePipeFrames(count)
    while #pipeFrames < count do
        local topBody = gameFrame:CreateTexture(nil, "ARTWORK")
        topBody:SetTexture(SPRITE_PATH .. "SpritePipeBody")
        topBody:Hide()

        local topCap = gameFrame:CreateTexture(nil, "ARTWORK")
        topCap:SetTexture(SPRITE_PATH .. "SpritePipeCap")
        topCap:SetTexCoord(0, 1, 1, 0) -- flip vertically for top pipe cap
        topCap:Hide()

        local botBody = gameFrame:CreateTexture(nil, "ARTWORK")
        botBody:SetTexture(SPRITE_PATH .. "SpritePipeBody")
        botBody:Hide()

        local botCap = gameFrame:CreateTexture(nil, "ARTWORK")
        botCap:SetTexture(SPRITE_PATH .. "SpritePipeCap")
        botCap:Hide()

        pipeFrames[#pipeFrames + 1] = { top = topBody, topCap = topCap, bottom = botBody, botCap = botCap }
    end
end

local function OnUpdate()
    if not gameActive or gameOver then return end

    local now = GetTime()
    if lastTime == 0 then lastTime = now end
    local dt = now - lastTime
    lastTime = now
    if dt > 0.05 then dt = 0.05 end
    if dt <= 0 then return end

    -- Bird physics: birdY is from bottom, positive = up
    birdVel = birdVel - GRAVITY * dt
    birdY = birdY + birdVel * dt

    -- Hit ceiling
    if birdY > frameH - BIRD_SIZE / 2 then
        birdY = frameH - BIRD_SIZE / 2
        birdVel = 0
    end

    -- Hit ground
    if birdY < BIRD_SIZE / 2 then
        birdY = BIRD_SIZE / 2
        gameOver = true
        msgFs:SetText("|cffff4444Game Over!|r")
        if score > bestScore then
            bestScore = score
            HearthPhoneDB = HearthPhoneDB or {}
            HearthPhoneDB.bestFlappy = bestScore
        end
        return
    end

    -- Move pipes
    local toRemove = {}
    for i, pipe in ipairs(pipes) do
        pipe.x = pipe.x - PIPE_SPEED * dt

        -- Score
        if not pipe.scored and pipe.x + PIPE_WIDTH < birdX then
            pipe.scored = true
            score = score + 1
            scoreFs:SetText("|cffffffff" .. score .. "|r")
        end

        -- Collision
        local bLeft = birdX - BIRD_SIZE / 2
        local bRight = birdX + BIRD_SIZE / 2
        local bBot = birdY - BIRD_SIZE / 2
        local bTop = birdY + BIRD_SIZE / 2

        if bRight > pipe.x and bLeft < pipe.x + PIPE_WIDTH then
            local gapBot = pipe.gapCenter - pipe.gap / 2
            local gapTop = pipe.gapCenter + pipe.gap / 2
            if bBot < gapBot or bTop > gapTop then
                gameOver = true
                msgFs:SetText("|cffff4444Score: " .. score .. "|r")
                if score > bestScore then
                    bestScore = score
                    HearthPhoneDB = HearthPhoneDB or {}
                    HearthPhoneDB.bestFlappy = bestScore
                end
                return
            end
        end

        if pipe.x + PIPE_WIDTH < -5 then
            table.insert(toRemove, i)
        end
    end

    -- Remove off-screen, spawn new
    for ri = #toRemove, 1, -1 do
        table.remove(pipes, toRemove[ri])
        local lastPipeX = 0
        for _, p in ipairs(pipes) do
            if p.x > lastPipeX then lastPipeX = p.x end
        end
        SpawnPipe(lastPipeX + GetPipeSpacing())
    end

    -- Update visuals
    birdTex:ClearAllPoints()
    birdTex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", birdX, birdY)

    local CAP_H = 6
    EnsurePipeFrames(#pipes)
    for i, pipe in ipairs(pipes) do
        local pf = pipeFrames[i]
        local visible = pipe.x > -PIPE_WIDTH and pipe.x < frameW + PIPE_WIDTH

        -- Bottom pipe: from bottom up to gap
        local botH = pipe.gapCenter - pipe.gap / 2
        if botH > CAP_H and visible then
            pf.bottom:ClearAllPoints()
            pf.bottom:SetSize(PIPE_WIDTH, botH - CAP_H)
            pf.bottom:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", pipe.x, 0)
            pf.bottom:Show()
            pf.botCap:ClearAllPoints()
            pf.botCap:SetSize(PIPE_WIDTH + 4, CAP_H)
            pf.botCap:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", pipe.x - 2, botH - CAP_H)
            pf.botCap:Show()
        else
            pf.bottom:SetShown(botH > 0 and visible)
            if botH > 0 and visible then
                pf.bottom:ClearAllPoints()
                pf.bottom:SetSize(PIPE_WIDTH, botH)
                pf.bottom:SetPoint("BOTTOMLEFT", gameFrame, "BOTTOMLEFT", pipe.x, 0)
            end
            pf.botCap:Hide()
        end

        -- Top pipe: from top down to gap
        local topH = frameH - (pipe.gapCenter + pipe.gap / 2)
        if topH > CAP_H and visible then
            pf.top:ClearAllPoints()
            pf.top:SetSize(PIPE_WIDTH, topH - CAP_H)
            pf.top:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", pipe.x, 0)
            pf.top:Show()
            pf.topCap:ClearAllPoints()
            pf.topCap:SetSize(PIPE_WIDTH + 4, CAP_H)
            pf.topCap:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", pipe.x - 2, -(topH - CAP_H))
            pf.topCap:Show()
        else
            pf.top:SetShown(topH > 0 and visible)
            if topH > 0 and visible then
                pf.top:ClearAllPoints()
                pf.top:SetSize(PIPE_WIDTH, topH)
                pf.top:SetPoint("TOPLEFT", gameFrame, "TOPLEFT", pipe.x, 0)
            end
            pf.topCap:Hide()
        end
    end

    -- Hide unused
    for i = #pipes + 1, #pipeFrames do
        pipeFrames[i].top:Hide()
        pipeFrames[i].topCap:Hide()
        pipeFrames[i].bottom:Hide()
        pipeFrames[i].botCap:Hide()
    end
end

function PhoneFlappyBirdGame:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.bestFlappy or 0

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffffffffFlappy|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 11, "OUTLINE") end

    -- Score
    scoreFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreFs:SetPoint("TOP", 0, -16)
    scoreFs:SetText("|cffffffff0|r")
    local scf = scoreFs:GetFont()
    if scf then scoreFs:SetFont(scf, 10, "OUTLINE") end

    -- Message
    msgFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    msgFs:SetPoint("TOP", 0, -28)
    local mf = msgFs:GetFont()
    if mf then msgFs:SetFont(mf, 8, "OUTLINE") end

    -- Game area (clamp children to frame bounds)
    gameFrame = CreateFrame("Button", nil, parent)
    gameFrame:SetPoint("TOPLEFT", 2, -38)
    gameFrame:SetPoint("BOTTOMRIGHT", -2, 8)
    gameFrame:SetClipsChildren(true)

    local gameBg = gameFrame:CreateTexture(nil, "BACKGROUND")
    gameBg:SetAllPoints()
    gameBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    gameBg:SetVertexColor(0.04, 0.06, 0.10, 1)

    -- Ground
    local ground = gameFrame:CreateTexture(nil, "BORDER")
    ground:SetHeight(4)
    ground:SetPoint("BOTTOMLEFT")
    ground:SetPoint("BOTTOMRIGHT")
    ground:SetTexture("Interface\\Buttons\\WHITE8x8")
    ground:SetVertexColor(0.25, 0.45, 0.15, 1)

    -- Bird
    birdTex = gameFrame:CreateTexture(nil, "OVERLAY")
    birdTex:SetSize(BIRD_SIZE, BIRD_SIZE)
    birdTex:SetTexture(SPRITE_PATH .. "SpriteFlappyBird")

    -- Start message
    startMsg = gameFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    startMsg:SetPoint("CENTER")
    startMsg:SetText("|cff888888Click to flap!|r")
    local smf = startMsg:GetFont()
    if smf then startMsg:SetFont(smf, 9, "") end

    -- Click to flap
    gameFrame:SetScript("OnClick", Flap)

    -- Keyboard (space) to flap
    local keyFrame = CreateFrame("Frame", "PhoneFlappyKeyFrame", gameFrame)
    keyFrame:SetAllPoints()
    keyFrame:SetPropagateKeyboardInput(true)
    keyFrame:SetScript("OnKeyDown", function(self, key)
        if not parent:IsShown() then return end
        if key == "SPACE" then
            self:SetPropagateKeyboardInput(false)
            Flap()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    -- Game loop
    gameFrame:SetScript("OnUpdate", OnUpdate)

    birdY = 100
    birdVel = 0
    gameActive = false
    gameOver = false
end

function PhoneFlappyBirdGame:OnShow()
    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.bestFlappy or 0
    lastTime = 0
    ResetGame()
    if PhoneFlappyKeyFrame then
        PhoneFlappyKeyFrame:EnableKeyboard(true)
    end
end

function PhoneFlappyBirdGame:OnHide()
    gameActive = false
    if PhoneFlappyKeyFrame then
        PhoneFlappyKeyFrame:EnableKeyboard(false)
    end
end
