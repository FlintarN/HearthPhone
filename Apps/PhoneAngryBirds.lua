-- PhoneAngryBirds - Angry Birds style game for HearthPhone

PhoneAngryBirdsGame = {}

local parent
local gameFrame, scoreFs, msgFs, levelFs
local blocks, blockFrames = {}, {}
local pigs, pigFrames = {}, {}
local projTex, slingshotTex
local dotFrames = {}

local SPRITE_PATH = "Interface\\AddOns\\HearthPhone\\Textures\\"
local BIRD_SIZE = 14
local PIG_SIZE = 16
local BLOCK_W = 16
local BLOCK_H = 10
local GROUND_Y = 16
local GRAVITY = 200
local SLING_X = 45
local SLING_Y = 40
local MAX_PULL = 40
local LAUNCH_MULT = 4.0
local NUM_DOTS = 8

local frameW, frameH
local score, bestScore
local gameOver, launched, aiming
local birdsLeft
local dragBirdX, dragBirdY
local projX, projY, projVelX, projVelY
local lastTime = 0
local level = 1

-- ============================================================
-- Levels
-- ============================================================
local function BuildLevel(lvl)
    wipe(blocks)
    wipe(pigs)
    local fw = frameW or 160
    local groundY = GROUND_Y
    local baseX = fw * 0.72

    if lvl == 1 then
        table.insert(blocks, { x = baseX, y = groundY, w = BLOCK_W * 3, h = BLOCK_H, hp = 2 })
        table.insert(blocks, { x = baseX - BLOCK_W, y = groundY + BLOCK_H, w = BLOCK_W, h = BLOCK_H * 3, hp = 2 })
        table.insert(blocks, { x = baseX + BLOCK_W, y = groundY + BLOCK_H, w = BLOCK_W, h = BLOCK_H * 3, hp = 2 })
        table.insert(blocks, { x = baseX, y = groundY + BLOCK_H * 4, w = BLOCK_W * 3, h = BLOCK_H, hp = 2 })
        table.insert(pigs, { x = baseX, y = groundY + BLOCK_H * 4 + PIG_SIZE / 2 + 1, hp = 1 })
    elseif lvl == 2 then
        table.insert(blocks, { x = baseX, y = groundY, w = BLOCK_W * 4, h = BLOCK_H, hp = 2 })
        table.insert(blocks, { x = baseX - BLOCK_W * 1.2, y = groundY + BLOCK_H, w = BLOCK_W, h = BLOCK_H * 4, hp = 3 })
        table.insert(blocks, { x = baseX + BLOCK_W * 1.2, y = groundY + BLOCK_H, w = BLOCK_W, h = BLOCK_H * 4, hp = 3 })
        table.insert(blocks, { x = baseX, y = groundY + BLOCK_H * 5, w = BLOCK_W * 4, h = BLOCK_H, hp = 2 })
        table.insert(pigs, { x = baseX - 6, y = groundY + BLOCK_H + PIG_SIZE / 2, hp = 1 })
        table.insert(pigs, { x = baseX + 6, y = groundY + BLOCK_H * 5 + PIG_SIZE / 2 + 1, hp = 1 })
    elseif lvl == 3 then
        for i = -1, 1 do
            local bx = baseX + i * (BLOCK_W * 2)
            table.insert(blocks, { x = bx, y = groundY, w = BLOCK_W, h = BLOCK_H * 3, hp = 2 })
            table.insert(blocks, { x = bx, y = groundY + BLOCK_H * 3, w = BLOCK_W * 1.5, h = BLOCK_H, hp = 1 })
            table.insert(pigs, { x = bx, y = groundY + BLOCK_H * 3 + PIG_SIZE / 2 + 1, hp = 1 })
        end
    else
        local extra = math.floor((lvl - 1) / 3)
        for i = -1, 1 do
            local bx = baseX + i * (BLOCK_W * 2)
            table.insert(blocks, { x = bx, y = groundY, w = BLOCK_W, h = BLOCK_H * 3, hp = 2 + extra })
            table.insert(blocks, { x = bx, y = groundY + BLOCK_H * 3, w = BLOCK_W * 1.5, h = BLOCK_H, hp = 1 + extra })
            table.insert(pigs, { x = bx, y = groundY + BLOCK_H * 3 + PIG_SIZE / 2 + 1, hp = 1 + extra })
        end
    end
end

-- ============================================================
-- Rendering
-- ============================================================
local function EnsureFrames(list, count, layer)
    while #list < count do
        local tex = gameFrame:CreateTexture(nil, layer or "ARTWORK")
        tex:SetTexture("Interface\\Buttons\\WHITE8x8")
        tex:Hide()
        list[#list + 1] = tex
    end
end

local function DrawScene()
    -- Blocks
    EnsureFrames(blockFrames, #blocks)
    for i, b in ipairs(blocks) do
        local tex = blockFrames[i]
        if b.hp > 0 then
            tex:ClearAllPoints()
            tex:SetSize(b.w, b.h)
            tex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", b.x, b.y + b.h / 2)
            if b.hp >= 3 then
                tex:SetVertexColor(0.45, 0.30, 0.15, 1)
            elseif b.hp == 2 then
                tex:SetVertexColor(0.60, 0.45, 0.20, 1)
            else
                tex:SetVertexColor(0.75, 0.60, 0.30, 1)
            end
            tex:Show()
        else
            tex:Hide()
        end
    end
    for i = #blocks + 1, #blockFrames do blockFrames[i]:Hide() end

    -- Pigs
    EnsureFrames(pigFrames, #pigs)
    for i, p in ipairs(pigs) do
        local tex = pigFrames[i]
        if p.hp > 0 then
            tex:ClearAllPoints()
            tex:SetSize(PIG_SIZE, PIG_SIZE)
            tex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", p.x, p.y)
            tex:SetTexture(SPRITE_PATH .. "SpritePig")
            tex:SetVertexColor(1, 1, 1, 1)
            tex:Show()
        else
            tex:Hide()
        end
    end
    for i = #pigs + 1, #pigFrames do pigFrames[i]:Hide() end

    -- Bird position
    if projTex then
        if launched and projX then
            projTex:ClearAllPoints()
            projTex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", projX, projY)
            projTex:Show()
        elseif aiming and dragBirdX then
            projTex:ClearAllPoints()
            projTex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", dragBirdX, dragBirdY)
            projTex:Show()
        elseif not launched and birdsLeft and birdsLeft > 0 then
            projTex:ClearAllPoints()
            projTex:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", SLING_X, SLING_Y)
            projTex:Show()
        else
            projTex:Hide()
        end
    end
end

local function HideDots()
    for _, d in ipairs(dotFrames) do d:Hide() end
end

local function ShowTrajectory(velX, velY)
    EnsureFrames(dotFrames, NUM_DOTS, "ARTWORK")
    local px, py = SLING_X, SLING_Y
    local vx, vy = velX, velY
    local step = 0.06
    for i = 1, NUM_DOTS do
        px = px + vx * step
        vy = vy - GRAVITY * step
        py = py + vy * step
        local dot = dotFrames[i]
        dot:ClearAllPoints()
        dot:SetSize(4, 4)
        dot:SetPoint("CENTER", gameFrame, "BOTTOMLEFT", px, py)
        dot:SetVertexColor(1, 1, 1, 0.4 - i * 0.03)
        dot:Show()
    end
end


-- ============================================================
-- Game logic
-- ============================================================
local function AllPigsDead()
    for _, p in ipairs(pigs) do
        if p.hp > 0 then return false end
    end
    return true
end

local function SaveBest()
    if score > bestScore then
        bestScore = score
        HearthPhoneDB = HearthPhoneDB or {}
        HearthPhoneDB.bestAngryBirds = bestScore
    end
end

-- Find the highest support point beneath a pig
local function FindSupport(px, py)
    local pigHalf = PIG_SIZE / 2
    local pigLeft = px - pigHalf
    local pigRight = px + pigHalf
    local bestTop = GROUND_Y -- ground is the minimum support

    for _, b in ipairs(blocks) do
        if b.hp > 0 then
            local bLeft = b.x - b.w / 2
            local bRight = b.x + b.w / 2
            local bTop = b.y + b.h
            -- Block overlaps pig horizontally and its top is below (or at) the pig
            if pigRight > bLeft and pigLeft < bRight and bTop <= py + 1 then
                if bTop > bestTop then
                    bestTop = bTop
                end
            end
        end
    end

    return bestTop + pigHalf
end

-- Settle pigs that lost support; kill them if they fall far enough
local function SettlePhysics()
    local settled = false
    for _, p in ipairs(pigs) do
        if p.hp > 0 then
            local supportY = FindSupport(p.x, p.y)
            local fallDist = p.y - supportY
            if fallDist > 2 then
                p.y = supportY
                settled = true
                -- Big fall kills the pig
                if fallDist > PIG_SIZE then
                    p.hp = p.hp - 1
                    score = score + 50
                end
            end
        end
    end
    if settled then
        scoreFs:SetText("|cffffffff" .. score .. "|r")
    end
    return settled
end

local function CheckCollisions()
    if not projX or not projY then return false end
    local hit = false

    for _, b in ipairs(blocks) do
        if b.hp > 0 then
            local left = b.x - b.w / 2
            local right = b.x + b.w / 2
            local bot = b.y
            local top = b.y + b.h
            if projX + BIRD_SIZE / 2 > left and projX - BIRD_SIZE / 2 < right
                and projY + BIRD_SIZE / 2 > bot and projY - BIRD_SIZE / 2 < top then
                b.hp = b.hp - 1
                score = score + 10
                hit = true
            end
        end
    end

    for _, p in ipairs(pigs) do
        if p.hp > 0 then
            local dx = projX - p.x
            local dy = projY - p.y
            if math.sqrt(dx * dx + dy * dy) < (BIRD_SIZE + PIG_SIZE) / 2 then
                p.hp = p.hp - 1
                score = score + 50
                hit = true
            end
        end
    end

    if hit then
        scoreFs:SetText("|cffffffff" .. score .. "|r")
        SettlePhysics()
    end
    return hit
end

local function BirdLanded()
    CheckCollisions()
    launched = false

    if AllPigsDead() then
        SaveBest()
        msgFs:SetText("|cff44ff44Level cleared!|r")
        C_Timer.After(1.0, function()
            if not gameOver then
                level = level + 1
                birdsLeft = 3
                levelFs:SetText("|cffaaaaaaLv " .. level .. "|r")
                msgFs:SetText("")
                BuildLevel(level)
                DrawScene()
            end
        end)
        return
    end

    birdsLeft = birdsLeft - 1
    if birdsLeft <= 0 then
        gameOver = true
        SaveBest()
        msgFs:SetText("|cffff4444Game Over!  Score: " .. score .. "|r")
    else
        msgFs:SetText("|cff888888Pull back to launch|r")
    end
    DrawScene()
end

local function OnUpdate(_, elapsed)
    if not launched or gameOver or not projX then return end

    local now = GetTime()
    if lastTime == 0 then lastTime = now end
    local dt = now - lastTime
    lastTime = now
    if dt > 0.05 then dt = 0.05 end
    if dt <= 0 then return end

    projVelY = projVelY - GRAVITY * dt
    projX = projX + projVelX * dt
    projY = projY + projVelY * dt

    -- Ground
    if projY < BIRD_SIZE / 2 then
        projY = BIRD_SIZE / 2
        BirdLanded()
        return
    end

    -- Off screen
    if projX > (frameW or 160) + 20 or projX < -20 or projY > (frameH or 200) + 50 then
        BirdLanded()
        return
    end

    -- In-flight hits
    if CheckCollisions() then
        projVelX = projVelX * 0.6
        projVelY = projVelY * 0.6
    end

    if AllPigsDead() then
        launched = false
        SaveBest()
        msgFs:SetText("|cff44ff44Level cleared!|r")
        C_Timer.After(1.0, function()
            if not gameOver then
                level = level + 1
                birdsLeft = 3
                levelFs:SetText("|cffaaaaaaLv " .. level .. "|r")
                msgFs:SetText("")
                BuildLevel(level)
                DrawScene()
            end
        end)
    end

    DrawScene()
end

local function GetDragOffset(self)
    local scale = self:GetEffectiveScale()
    local cx = select(1, GetCursorPosition()) / scale
    local cy = select(2, GetCursorPosition()) / scale
    local left = gameFrame:GetLeft() or 0
    local bot = gameFrame:GetBottom() or 0
    -- Cursor in game-frame local coords
    local localX = cx - left
    local localY = cy - bot
    -- Offset from sling
    local dx = SLING_X - localX
    local dy = SLING_Y - localY
    return dx, dy
end

local function ResetGame()
    frameW = gameFrame:GetWidth() or 160
    frameH = gameFrame:GetHeight() or 200
    score = 0
    level = 1
    birdsLeft = 3
    gameOver = false
    launched = false
    aiming = false
    dragBirdX, dragBirdY = nil, nil
    projX, projY = nil, nil
    lastTime = 0
    scoreFs:SetText("|cffffffff0|r")
    levelFs:SetText("|cffaaaaaaLv 1|r")
    msgFs:SetText("|cff888888Pull back to launch|r")
    HideDots()

    BuildLevel(level)
    DrawScene()
end

-- ============================================================
-- Init
-- ============================================================
function PhoneAngryBirdsGame:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.bestAngryBirds or 0

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffff4444Angry Birds|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Score (right)
    scoreFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreFs:SetPoint("TOPRIGHT", -6, -2)
    scoreFs:SetText("|cffffffff0|r")
    local scf = scoreFs:GetFont()
    if scf then scoreFs:SetFont(scf, 9, "OUTLINE") end

    -- Level (left)
    levelFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    levelFs:SetPoint("TOPLEFT", 6, -2)
    levelFs:SetText("|cffaaaaaaLv 1|r")
    local lvf = levelFs:GetFont()
    if lvf then levelFs:SetFont(lvf, 7, "") end

    -- Message
    msgFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    msgFs:SetPoint("TOP", 0, -14)
    local mf = msgFs:GetFont()
    if mf then msgFs:SetFont(mf, 7, "") end

    -- Game area
    gameFrame = CreateFrame("Frame", nil, parent)
    gameFrame:SetPoint("TOPLEFT", 2, -24)
    gameFrame:SetPoint("BOTTOMRIGHT", -2, 8)
    gameFrame:SetClipsChildren(true)

    local gameBg = gameFrame:CreateTexture(nil, "BACKGROUND")
    gameBg:SetAllPoints()
    gameBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    gameBg:SetVertexColor(0.35, 0.65, 0.90, 1)

    -- Ground
    local ground = gameFrame:CreateTexture(nil, "BORDER")
    ground:SetHeight(14)
    ground:SetPoint("BOTTOMLEFT")
    ground:SetPoint("BOTTOMRIGHT")
    ground:SetTexture("Interface\\Buttons\\WHITE8x8")
    ground:SetVertexColor(0.35, 0.55, 0.20, 1)

    -- Slingshot (Y-shape: base + two prongs)
    slingshotTex = gameFrame:CreateTexture(nil, "BORDER")
    slingshotTex:SetSize(5, 22)
    slingshotTex:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", SLING_X, 14)
    slingshotTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    slingshotTex:SetVertexColor(0.40, 0.25, 0.10, 1)

    local slingLeft = gameFrame:CreateTexture(nil, "BORDER")
    slingLeft:SetSize(4, 8)
    slingLeft:SetPoint("BOTTOMRIGHT", slingshotTex, "TOPLEFT", 1, -2)
    slingLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
    slingLeft:SetVertexColor(0.40, 0.25, 0.10, 1)

    local slingRight = gameFrame:CreateTexture(nil, "BORDER")
    slingRight:SetSize(4, 8)
    slingRight:SetPoint("BOTTOMLEFT", slingshotTex, "TOPRIGHT", -1, -2)
    slingRight:SetTexture("Interface\\Buttons\\WHITE8x8")
    slingRight:SetVertexColor(0.40, 0.25, 0.10, 1)

    -- Bird
    projTex = gameFrame:CreateTexture(nil, "OVERLAY")
    projTex:SetSize(BIRD_SIZE, BIRD_SIZE)
    projTex:SetTexture(SPRITE_PATH .. "SpriteAngryBird")

    -- Birds remaining indicators (small sprites near sling)
    local birdDots = {}
    for i = 1, 3 do
        local d = gameFrame:CreateTexture(nil, "ARTWORK")
        d:SetSize(8, 8)
        d:SetPoint("BOTTOM", gameFrame, "BOTTOMLEFT", SLING_X - 14 + (i - 1) * 9, 15)
        d:SetTexture(SPRITE_PATH .. "SpriteAngryBird")
        d:SetAlpha(0.8)
        birdDots[i] = d
    end

    local function UpdateBirdDots()
        for i = 1, 3 do
            -- Don't count the current bird on the sling
            birdDots[i]:SetShown(i <= (birdsLeft or 0) - 1)
        end
    end

    -- Mouse interaction
    local mouseFrame = CreateFrame("Frame", nil, gameFrame)
    mouseFrame:SetAllPoints()
    mouseFrame:EnableMouse(true)

    mouseFrame:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if gameOver then
            ResetGame()
            UpdateBirdDots()
            return
        end
        if launched or (birdsLeft or 0) <= 0 then return end

        aiming = true
        dragBirdX, dragBirdY = SLING_X, SLING_Y
        msgFs:SetText("")
    end)

    mouseFrame:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not aiming then return end
        aiming = false
        HideDots()
    

        local dx, dy = GetDragOffset(self)
        local pull = math.sqrt(dx * dx + dy * dy)

        if pull < 5 then
            -- Too small, snap back
            dragBirdX, dragBirdY = nil, nil
            DrawScene()
            return
        end

        -- Clamp
        if pull > MAX_PULL then
            dx = dx * MAX_PULL / pull
            dy = dy * MAX_PULL / pull
        end

        -- Launch!
        projX, projY = SLING_X, SLING_Y
        projVelX = dx * LAUNCH_MULT
        projVelY = dy * LAUNCH_MULT
        launched = true
        lastTime = 0
        dragBirdX, dragBirdY = nil, nil
        UpdateBirdDots()
    end)

    mouseFrame:SetScript("OnUpdate", function(self, dt)
        if aiming then
            local dx, dy = GetDragOffset(self)
            local pull = math.sqrt(dx * dx + dy * dy)

            -- Clamp pull distance
            if pull > MAX_PULL then
                dx = dx * MAX_PULL / pull
                dy = dy * MAX_PULL / pull
                pull = MAX_PULL
            end

            -- Bird sits opposite the pull direction (slingshot feel)
            dragBirdX = SLING_X - dx
            dragBirdY = SLING_Y - dy

            -- Show rubber band


            -- Show trajectory preview if pulling enough
            if pull > 5 then
                ShowTrajectory(dx * LAUNCH_MULT, dy * LAUNCH_MULT)
            else
                HideDots()
            end

            DrawScene()
        end

        if launched and not gameOver then
            OnUpdate(self, dt)
        end
    end)

    -- Store updater for bird dots
    C_Timer.After(0, function()
        frameW = gameFrame:GetWidth() or 160
        frameH = gameFrame:GetHeight() or 200
        UpdateBirdDots()
    end)
end

function PhoneAngryBirdsGame:OnShow()
    HearthPhoneDB = HearthPhoneDB or {}
    bestScore = HearthPhoneDB.bestAngryBirds or 0
    lastTime = 0
    ResetGame()
end

function PhoneAngryBirdsGame:OnHide()
    launched = false
    aiming = false
    HideDots()

end
