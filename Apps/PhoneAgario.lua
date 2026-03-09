-- PhoneAgario.lua  –  Agar.io-style multiplayer blob game
-- Runs on a shared addon channel so all addon users are in the same persistent arena.

PhoneAgarioGame = {}

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local ADDON_PREFIX = "PhoneAgar"
local CHANNEL_NAME = "xtHearthAgar"
local SEP = "\001"
local ARENA_W, ARENA_H = 600, 600       -- world size
local FOOD_COUNT = 40                     -- food dots on screen
local START_RADIUS = 8
local MIN_RADIUS = 6
local MAX_RADIUS = 60
local TICK_RATE = 0.05                    -- game loop interval (20 fps)
local SYNC_RATE = 0.4                     -- broadcast position every 0.4s
local TIMEOUT = 8                         -- remove player after 8s silence
local SPEED_BASE = 80                     -- pixels/sec at radius 8
local EAT_RATIO = 0.85                    -- must be this fraction smaller to be eaten

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local gameFrame, canvas
local myBlob = { x = 0, y = 0, r = START_RADIUS, alive = true }
local remotePlobs = {}       -- [name] = { x, y, r, class, lastSeen, tex, label }
local foodDots = {}          -- { x, y, tex }
local moveDir = { x = 0, y = 0 }  -- normalized direction
local camX, camY = 0, 0     -- camera offset (centered on player)
local highScore = 0
local channelReady = false
local isRunning = false
local syncTimer = 0
local leaderRows = {}
local foodTextures = {}
local myTex, myLabel
local gridLines = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function GetMyName()
    local name, realm = UnitFullName("player")
    realm = realm or GetNormalizedRealmName() or ""
    if realm ~= "" then return name .. "-" .. realm end
    return name
end

local function GetMyClass()
    local _, cls = UnitClass("player")
    return cls or "WARRIOR"
end

local CLASS_COLORS = {
    WARRIOR     = {0.78, 0.61, 0.43},
    PALADIN     = {0.96, 0.55, 0.73},
    HUNTER      = {0.67, 0.83, 0.45},
    ROGUE       = {1.00, 0.96, 0.41},
    PRIEST      = {1.00, 1.00, 1.00},
    DEATHKNIGHT = {0.77, 0.12, 0.23},
    SHAMAN      = {0.00, 0.44, 0.87},
    MAGE        = {0.25, 0.78, 0.92},
    WARLOCK     = {0.53, 0.53, 0.93},
    MONK        = {0.00, 1.00, 0.60},
    DRUID       = {1.00, 0.49, 0.04},
    DEMONHUNTER = {0.64, 0.19, 0.79},
    EVOKER      = {0.20, 0.58, 0.50},
}

local function ClassColor(cls)
    return CLASS_COLORS[cls] or {0.5, 0.5, 0.5}
end

local function Dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

---------------------------------------------------------------------------
-- Food
---------------------------------------------------------------------------
local FOOD_COLORS = {
    {1, 0.3, 0.3}, {0.3, 1, 0.3}, {0.3, 0.3, 1},
    {1, 1, 0.3},   {1, 0.3, 1},   {0.3, 1, 1},
    {1, 0.6, 0.2}, {0.8, 0.4, 1},
}

local function SpawnFood(idx)
    local f = foodDots[idx]
    if not f then
        f = {}
        foodDots[idx] = f
    end
    f.x = math.random(10, ARENA_W - 10)
    f.y = math.random(10, ARENA_H - 10)
    f.colorIdx = math.random(1, #FOOD_COLORS)
    if f.tex then
        f.tex:Show()
    end
end

local function InitFood()
    for i = 1, FOOD_COUNT do
        SpawnFood(i)
    end
end

---------------------------------------------------------------------------
-- Networking
---------------------------------------------------------------------------
local sendQueue = {}
local function QueueSend(msg)
    table.insert(sendQueue, msg)
end

local function FlushQueue()
    if not channelReady then return end
    local chanId = GetChannelName(CHANNEL_NAME)
    if chanId == 0 then return end
    for _, msg in ipairs(sendQueue) do
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, msg, "CHANNEL", chanId)
    end
    sendQueue = {}
end

local function BroadcastPosition()
    if not myBlob.alive then return end
    local msg = "POS" .. SEP .. GetMyName() .. SEP .. GetMyClass() .. SEP
                .. string.format("%.0f", myBlob.x) .. SEP
                .. string.format("%.0f", myBlob.y) .. SEP
                .. string.format("%.1f", myBlob.r)
    QueueSend(msg)
end

local function BroadcastDeath(victimName)
    local msg = "EAT" .. SEP .. GetMyName() .. SEP .. victimName
    QueueSend(msg)
end

local function BroadcastLeave()
    local msg = "LEAVE" .. SEP .. GetMyName()
    QueueSend(msg)
end

---------------------------------------------------------------------------
-- Saved data (highscore)
---------------------------------------------------------------------------
local function GetDB()
    HearthPhoneDB = HearthPhoneDB or {}
    HearthPhoneDB.agario = HearthPhoneDB.agario or {}
    return HearthPhoneDB.agario
end

local function LoadHighScore()
    local db = GetDB()
    highScore = db.highScore or 0
end

local function SaveHighScore()
    local db = GetDB()
    if myBlob.r > highScore then
        highScore = myBlob.r
        db.highScore = highScore
    end
end

---------------------------------------------------------------------------
-- Respawn
---------------------------------------------------------------------------
local function Respawn()
    myBlob.x = math.random(50, ARENA_W - 50)
    myBlob.y = math.random(50, ARENA_H - 50)
    myBlob.r = START_RADIUS
    myBlob.alive = true
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
local function WorldToScreen(wx, wy)
    if not canvas then return 0, 0 end
    local cw, ch = canvas:GetWidth(), canvas:GetHeight()
    local sx = (wx - camX) + cw / 2
    local sy = (wy - camY) + ch / 2
    return sx, sy
end

local function UpdateCamera()
    camX = myBlob.x
    camY = myBlob.y
end

-- Create or reuse a circle texture for a blob
local function GetBlobTexture(parent, existing, r, cr, cg, cb)
    local tex = existing
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
    end
    local size = r * 2
    tex:SetSize(size, size)
    tex:SetVertexColor(cr, cg, cb, 0.9)
    return tex
end

local function GetBlobLabel(parent, existing, name)
    local fs = existing
    if not fs then
        fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local f = fs:GetFont()
        if f then fs:SetFont(f, 7, "OUTLINE") end
        fs:SetTextColor(1, 1, 1, 1)
    end
    local shortName = Ambiguate(name, "short")
    fs:SetText(shortName)
    return fs
end

-- Out-of-bounds border textures (created once, repositioned each frame)
local borderTop, borderBot, borderLeft, borderRight, borderLine

local function RenderFrame()
    if not canvas or not isRunning then return end
    local cw, ch = canvas:GetWidth(), canvas:GetHeight()

    -- Create border textures once
    if not borderTop then
        local function MakeBorder()
            local t = canvas:CreateTexture(nil, "BACKGROUND", nil, 1)
            t:SetTexture("Interface\\Buttons\\WHITE8x8")
            t:SetVertexColor(0.18, 0.18, 0.22, 0.9)
            return t
        end
        borderTop = MakeBorder()
        borderBot = MakeBorder()
        borderLeft = MakeBorder()
        borderRight = MakeBorder()
        -- Thin white border line at arena edge
        local function MakeLine()
            local t = canvas:CreateTexture(nil, "BACKGROUND", nil, 3)
            t:SetTexture("Interface\\Buttons\\WHITE8x8")
            t:SetVertexColor(0.4, 0.4, 0.5, 0.6)
            return t
        end
        borderLine = { MakeLine(), MakeLine(), MakeLine(), MakeLine() } -- top, bot, left, right
    end

    -- Position out-of-bounds areas
    -- Calculate top/bottom insets for clipping left/right borders
    local topH = 0
    local botH = 0

    -- Top border (above arena)
    local topScreenY = camY - ch / 2  -- world Y at top of screen
    if topScreenY < 0 then
        topH = math.min(ch, (0 - topScreenY))
        borderTop:ClearAllPoints()
        borderTop:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, 0)
        borderTop:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, 0)
        borderTop:SetHeight(topH)
        borderTop:Show()
    else
        borderTop:Hide()
    end

    -- Bottom border (below arena)
    local botScreenY = camY + ch / 2  -- world Y at bottom of screen
    if botScreenY > ARENA_H then
        botH = math.min(ch, (botScreenY - ARENA_H))
        borderBot:ClearAllPoints()
        borderBot:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 0, 0)
        borderBot:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", 0, 0)
        borderBot:SetHeight(botH)
        borderBot:Show()
    else
        borderBot:Hide()
    end

    -- Left border (clipped between top and bottom borders)
    local leftScreenX = camX - cw / 2
    if leftScreenX < 0 then
        local w = math.min(cw, (0 - leftScreenX))
        borderLeft:ClearAllPoints()
        borderLeft:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -topH)
        borderLeft:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", 0, botH)
        borderLeft:SetWidth(w)
        borderLeft:Show()
    else
        borderLeft:Hide()
    end

    -- Right border (clipped between top and bottom borders)
    local rightScreenX = camX + cw / 2
    if rightScreenX > ARENA_W then
        local w = math.min(cw, (rightScreenX - ARENA_W))
        borderRight:ClearAllPoints()
        borderRight:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -topH)
        borderRight:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", 0, botH)
        borderRight:SetWidth(w)
        borderRight:Show()
    else
        borderRight:Hide()
    end

    -- Border lines (thin lines at arena edge, clipped to arena screen bounds)
    local lineW = 2
    -- Raw screen positions of arena edges (unclamped)
    local rawLeft  = (0 - camX) + cw / 2
    local rawRight = (ARENA_W - camX) + cw / 2
    local rawTop   = (0 - camY) + ch / 2
    local rawBot   = (ARENA_H - camY) + ch / 2
    -- Clamped to visible canvas
    local clipL = math.max(0, rawLeft)
    local clipR = math.min(cw, rawRight)
    local clipT = math.max(0, rawTop)
    local clipB = math.min(ch, rawBot)

    -- Top line (world Y=0)
    if rawTop >= 1 and rawTop <= ch - 1 and clipR - clipL > 1 then
        borderLine[1]:ClearAllPoints()
        borderLine[1]:SetPoint("TOPLEFT", canvas, "TOPLEFT", clipL, -rawTop)
        borderLine[1]:SetSize(clipR - clipL, lineW)
        borderLine[1]:Show()
    else borderLine[1]:Hide() end
    -- Bottom line (world Y=ARENA_H)
    if rawBot >= 1 and rawBot <= ch - 1 and clipR - clipL > 1 then
        borderLine[2]:ClearAllPoints()
        borderLine[2]:SetPoint("TOPLEFT", canvas, "TOPLEFT", clipL, -rawBot)
        borderLine[2]:SetSize(clipR - clipL, lineW)
        borderLine[2]:Show()
    else borderLine[2]:Hide() end
    -- Left line (world X=0)
    if rawLeft >= 1 and rawLeft <= cw - 1 and clipB - clipT > 1 then
        borderLine[3]:ClearAllPoints()
        borderLine[3]:SetPoint("TOPLEFT", canvas, "TOPLEFT", rawLeft, -clipT)
        borderLine[3]:SetSize(lineW, clipB - clipT)
        borderLine[3]:Show()
    else borderLine[3]:Hide() end
    -- Right line (world X=ARENA_W)
    if rawRight >= 1 and rawRight <= cw - 1 and clipB - clipT > 1 then
        borderLine[4]:ClearAllPoints()
        borderLine[4]:SetPoint("TOPLEFT", canvas, "TOPLEFT", rawRight, -clipT)
        borderLine[4]:SetSize(lineW, clipB - clipT)
        borderLine[4]:Show()
    else borderLine[4]:Hide() end

    -- Food
    for i, f in ipairs(foodDots) do
        local sx, sy = WorldToScreen(f.x, f.y)
        if not f.tex then
            f.tex = canvas:CreateTexture(nil, "BACKGROUND", nil, 2)
            f.tex:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
            f.tex:SetSize(6, 6)
        end
        local fc = FOOD_COLORS[f.colorIdx] or FOOD_COLORS[1]
        f.tex:SetVertexColor(fc[1], fc[2], fc[3], 0.8)
        if sx > -10 and sx < cw + 10 and sy > -10 and sy < ch + 10 then
            f.tex:ClearAllPoints()
            f.tex:SetPoint("CENTER", canvas, "TOPLEFT", sx, -sy)
            f.tex:Show()
        else
            f.tex:Hide()
        end
    end

    -- Remote players
    for name, p in pairs(remotePlobs) do
        local sx, sy = WorldToScreen(p.x, p.y)
        local cc = ClassColor(p.class)
        p.tex = GetBlobTexture(canvas, p.tex, p.r, cc[1], cc[2], cc[3])
        p.label = GetBlobLabel(canvas, p.label, name)
        if sx > -MAX_RADIUS and sx < cw + MAX_RADIUS and sy > -MAX_RADIUS and sy < ch + MAX_RADIUS then
            p.tex:ClearAllPoints()
            p.tex:SetPoint("CENTER", canvas, "TOPLEFT", sx, -sy)
            p.tex:Show()
            p.label:ClearAllPoints()
            p.label:SetPoint("CENTER", p.tex, "CENTER", 0, 0)
            p.label:Show()
        else
            p.tex:Hide()
            p.label:Hide()
        end
    end

    -- My blob
    if myBlob.alive then
        local sx, sy = WorldToScreen(myBlob.x, myBlob.y)
        local cc = ClassColor(GetMyClass())
        myTex = GetBlobTexture(canvas, myTex, myBlob.r, cc[1], cc[2], cc[3])
        myTex:SetDrawLayer("ARTWORK", 7)
        myTex:ClearAllPoints()
        myTex:SetPoint("CENTER", canvas, "TOPLEFT", sx, -sy)
        myTex:Show()

        myLabel = GetBlobLabel(canvas, myLabel, GetMyName())
        myLabel:ClearAllPoints()
        myLabel:SetPoint("CENTER", myTex, "CENTER", 0, 0)
        myLabel:Show()
    else
        if myTex then myTex:Hide() end
        if myLabel then myLabel:Hide() end
    end
end

---------------------------------------------------------------------------
-- Leaderboard
---------------------------------------------------------------------------
local leaderFrame
local function UpdateLeaderboard()
    if not leaderFrame then return end
    -- Gather all blobs
    local entries = {}
    if myBlob.alive then
        table.insert(entries, { name = Ambiguate(GetMyName(), "short"), r = myBlob.r, me = true })
    end
    for name, p in pairs(remotePlobs) do
        table.insert(entries, { name = Ambiguate(name, "short"), r = p.r, me = false })
    end
    table.sort(entries, function(a, b) return a.r > b.r end)

    for i = 1, 5 do
        local row = leaderRows[i]
        if row then
            local e = entries[i]
            if e then
                local prefix = e.me and "|cff44ff44" or "|cffcccccc"
                row:SetText(prefix .. i .. ". " .. e.name .. " (" .. string.format("%.0f", e.r) .. ")|r")
                row:Show()
            else
                row:Hide()
            end
        end
    end
end

---------------------------------------------------------------------------
-- Game loop
---------------------------------------------------------------------------
local elapsed = 0
local function OnUpdate(self, dt)
    if not isRunning then return end
    elapsed = elapsed + dt
    if elapsed < TICK_RATE then return end
    local frameDt = elapsed
    elapsed = 0

    -- Movement
    if myBlob.alive and (moveDir.x ~= 0 or moveDir.y ~= 0) then
        local speed = SPEED_BASE / (myBlob.r / START_RADIUS) ^ 0.5
        myBlob.x = myBlob.x + moveDir.x * speed * frameDt
        myBlob.y = myBlob.y + moveDir.y * speed * frameDt
        -- Clamp to arena
        myBlob.x = math.max(myBlob.r, math.min(ARENA_W - myBlob.r, myBlob.x))
        myBlob.y = math.max(myBlob.r, math.min(ARENA_H - myBlob.r, myBlob.y))
    end

    -- Eat food
    if myBlob.alive then
        for i, f in ipairs(foodDots) do
            local d = Dist(myBlob.x, myBlob.y, f.x, f.y)
            if d < myBlob.r then
                myBlob.r = math.min(MAX_RADIUS, myBlob.r + 0.3)
                SpawnFood(i)
                SaveHighScore()
            end
        end
    end

    -- Eat smaller remote players
    if myBlob.alive then
        for name, p in pairs(remotePlobs) do
            if p.r < myBlob.r * EAT_RATIO then
                local d = Dist(myBlob.x, myBlob.y, p.x, p.y)
                if d < myBlob.r then
                    -- Absorb mass
                    myBlob.r = math.min(MAX_RADIUS, myBlob.r + p.r * 0.5)
                    BroadcastDeath(name)
                    -- Remove remote
                    if p.tex then p.tex:Hide() end
                    if p.label then p.label:Hide() end
                    remotePlobs[name] = nil
                    SaveHighScore()
                end
            end
        end
    end

    -- Slow shrink over time (prevents stalemate)
    if myBlob.alive and myBlob.r > START_RADIUS then
        myBlob.r = math.max(START_RADIUS, myBlob.r - 0.02 * frameDt)
    end

    -- Sync broadcast
    syncTimer = syncTimer + frameDt
    if syncTimer >= SYNC_RATE then
        syncTimer = 0
        BroadcastPosition()
        FlushQueue()
    end

    -- Timeout stale remote players
    local now = GetTime()
    for name, p in pairs(remotePlobs) do
        if now - p.lastSeen > TIMEOUT then
            if p.tex then p.tex:Hide() end
            if p.label then p.label:Hide() end
            remotePlobs[name] = nil
        end
    end

    UpdateCamera()
    RenderFrame()
    UpdateLeaderboard()
end

---------------------------------------------------------------------------
-- Input (click/drag direction)
---------------------------------------------------------------------------
local function SetupInput()
    canvas:EnableMouse(true)
    canvas:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            -- Respawn if dead
            if not myBlob.alive then
                Respawn()
                return
            end
            -- Set direction toward mouse
            local cx, cy = self:GetCenter()
            local mx, my = GetCursorPosition()
            local scale = self:GetEffectiveScale()
            mx, my = mx / scale, my / scale
            local dx = mx - cx
            local dy = my - cy  -- WoW Y is up
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 1 then
                moveDir.x = dx / len
                moveDir.y = -(dy / len)  -- flip Y for our coord system (down = +y)
            end
        end
    end)

    canvas:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            moveDir.x = 0
            moveDir.y = 0
        end
    end)

    -- WASD keyboard movement
    local keyState = { W = false, A = false, S = false, D = false }
    local usingKeys = false

    -- Create invisible buttons for key bindings
    local function MakeKeyBtn(key)
        local btn = CreateFrame("Button", "PhoneAgarKey" .. key, canvas, "SecureActionButtonTemplate")
        btn:SetSize(1, 1)
        btn:SetPoint("CENTER")
        btn:RegisterForClicks("AnyDown", "AnyUp")
        btn:SetScript("OnClick", function(self, _, down)
            if not isRunning or not myBlob.alive then return end
            keyState[key] = down
            usingKeys = keyState.W or keyState.A or keyState.S or keyState.D
        end)
        SetOverrideBindingClick(btn, false, key, btn:GetName(), "LeftButton")
        return btn
    end

    local keyBtns = {}
    gameFrame.EnableKeys = function()
        if #keyBtns > 0 then return end
        for _, k in ipairs({"W", "A", "S", "D"}) do
            table.insert(keyBtns, MakeKeyBtn(k))
        end
    end

    gameFrame.DisableKeys = function()
        for _, btn in ipairs(keyBtns) do
            ClearOverrideBindings(btn)
            btn:Hide()
        end
        keyBtns = {}
        keyState.W = false
        keyState.A = false
        keyState.S = false
        keyState.D = false
        usingKeys = false
        moveDir.x = 0
        moveDir.y = 0
    end

    -- Continuous direction update (mouse + keyboard)
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function()
        if not isRunning then return end
        if not myBlob.alive then return end

        -- Keyboard takes priority when any key is held
        if usingKeys then
            local kx, ky = 0, 0
            if keyState.W then ky = ky - 1 end
            if keyState.S then ky = ky + 1 end
            if keyState.A then kx = kx - 1 end
            if keyState.D then kx = kx + 1 end
            local len = math.sqrt(kx * kx + ky * ky)
            if len > 0 then
                moveDir.x = kx / len
                moveDir.y = ky / len
            else
                moveDir.x = 0
                moveDir.y = 0
            end
            return
        end

        -- Mouse fallback
        if IsMouseButtonDown("LeftButton") and canvas:IsMouseOver() then
            local cx, cy = canvas:GetCenter()
            local mx, my = GetCursorPosition()
            local scale = canvas:GetEffectiveScale()
            mx, my = mx / scale, my / scale
            local dx = mx - cx
            local dy = my - cy
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 1 then
                moveDir.x = dx / len
                moveDir.y = -(dy / len)
            end
        end
    end)
end

---------------------------------------------------------------------------
-- Message handler
---------------------------------------------------------------------------
local function OnMessage(prefix, msg, channel, sender)
    if prefix ~= ADDON_PREFIX then return end
    if sender == GetMyName() then return end

    local parts = { strsplit(SEP, msg) }
    local msgType = parts[1]

    if msgType == "POS" then
        local name = parts[2]
        local cls = parts[3]
        local px = tonumber(parts[4])
        local py = tonumber(parts[5])
        local pr = tonumber(parts[6])
        if name and px and py and pr then
            if not remotePlobs[name] then
                remotePlobs[name] = {}
            end
            local p = remotePlobs[name]
            p.x = px
            p.y = py
            p.r = pr
            p.class = cls or "WARRIOR"
            p.lastSeen = GetTime()
        end

    elseif msgType == "EAT" then
        local eater = parts[2]
        local victim = parts[3]
        if victim == GetMyName() and myBlob.alive then
            -- I got eaten
            myBlob.alive = false
            SaveHighScore()
        end
        -- Remove victim from remote list
        if victim and remotePlobs[victim] then
            if remotePlobs[victim].tex then remotePlobs[victim].tex:Hide() end
            if remotePlobs[victim].label then remotePlobs[victim].label:Hide() end
            remotePlobs[victim] = nil
        end

    elseif msgType == "LEAVE" then
        local name = parts[2]
        if name and remotePlobs[name] then
            if remotePlobs[name].tex then remotePlobs[name].tex:Hide() end
            if remotePlobs[name].label then remotePlobs[name].label:Hide() end
            remotePlobs[name] = nil
        end
    end
end

---------------------------------------------------------------------------
-- Channel setup
---------------------------------------------------------------------------
local function JoinChannel()
    local chanId = GetChannelName(CHANNEL_NAME)
    if chanId == 0 then
        JoinTemporaryChannel(CHANNEL_NAME)
        C_Timer.After(1, function()
            channelReady = GetChannelName(CHANNEL_NAME) ~= 0
        end)
    else
        channelReady = true
    end
end

---------------------------------------------------------------------------
-- Build UI
---------------------------------------------------------------------------
local function BuildUI(parentFrame)
    gameFrame = parentFrame

    -- Arena background
    canvas = CreateFrame("Frame", nil, parentFrame)
    canvas:SetAllPoints()
    canvas:SetClipsChildren(true)

    local bg = canvas:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.05, 0.07, 0.10, 1)

    -- Arena border indicators (subtle lines at world edges rendered in game loop)

    -- Leaderboard overlay (top-right)
    leaderFrame = CreateFrame("Frame", nil, canvas)
    leaderFrame:SetSize(80, 60)
    leaderFrame:SetPoint("TOPRIGHT", -4, -4)
    local lbg = leaderFrame:CreateTexture(nil, "BACKGROUND")
    lbg:SetAllPoints()
    lbg:SetTexture("Interface\\Buttons\\WHITE8x8")
    lbg:SetVertexColor(0, 0, 0, 0.5)

    local lTitle = leaderFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lTitle:SetPoint("TOP", 0, -2)
    local ltf = lTitle:GetFont()
    if ltf then lTitle:SetFont(ltf, 7, "OUTLINE") end
    lTitle:SetText("|cffeeee44Top 5|r")

    for i = 1, 5 do
        local row = leaderFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        row:SetPoint("TOPLEFT", 4, -(8 + i * 9))
        row:SetPoint("RIGHT", -4, 0)
        row:SetJustifyH("LEFT")
        local rf = row:GetFont()
        if rf then row:SetFont(rf, 7, "OUTLINE") end
        row:Hide()
        leaderRows[i] = row
    end

    -- Score / status overlay (top-left)
    local scoreFs = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scoreFs:SetPoint("TOPLEFT", 4, -4)
    local scf = scoreFs:GetFont()
    if scf then scoreFs:SetFont(scf, 8, "OUTLINE") end
    gameFrame.scoreFs = scoreFs

    -- Highscore
    local hiFs = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hiFs:SetPoint("TOPLEFT", 4, -14)
    local hif = hiFs:GetFont()
    if hif then hiFs:SetFont(hif, 7, "OUTLINE") end
    gameFrame.hiFs = hiFs

    -- Death message
    local deathFs = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    deathFs:SetPoint("CENTER", 0, 10)
    local df = deathFs:GetFont()
    if df then deathFs:SetFont(df, 11, "OUTLINE") end
    deathFs:SetText("|cffff4444You were eaten!|r\n|cffaaaaaa(Click to respawn)|r")
    deathFs:Hide()
    gameFrame.deathFs = deathFs

    SetupInput()
end

---------------------------------------------------------------------------
-- Score display update (called from render)
---------------------------------------------------------------------------
local origUpdateLeaderboard = UpdateLeaderboard
UpdateLeaderboard = function()
    origUpdateLeaderboard()
    if gameFrame and gameFrame.scoreFs then
        if myBlob.alive then
            gameFrame.scoreFs:SetText("|cff88ccffSize: " .. string.format("%.0f", myBlob.r) .. "|r")
            gameFrame.deathFs:Hide()
        else
            gameFrame.scoreFs:SetText("|cffff6666Dead|r")
            gameFrame.deathFs:Show()
        end
    end
    if gameFrame and gameFrame.hiFs then
        gameFrame.hiFs:SetText("|cff888888Best: " .. string.format("%.0f", highScore) .. "|r")
    end
end

---------------------------------------------------------------------------
-- Init / Show / Hide
---------------------------------------------------------------------------
local initialized = false

function PhoneAgarioGame:Init(parentFrame)
    if initialized then return end
    initialized = true

    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
    BuildUI(parentFrame)
    InitFood()
    LoadHighScore()
    Respawn()

    -- Register message handler
    local evFrame = CreateFrame("Frame")
    evFrame:RegisterEvent("CHAT_MSG_ADDON")
    evFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    evFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "CHAT_MSG_ADDON" then
            OnMessage(...)
        elseif event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(3, JoinChannel)
        end
    end)

    -- Game loop
    local loopFrame = CreateFrame("Frame")
    loopFrame:SetScript("OnUpdate", OnUpdate)

    -- Join channel
    C_Timer.After(2, JoinChannel)
end

function PhoneAgarioGame:OnShow()
    if not initialized and gameFrame then
        self:Init(gameFrame)
    end
    -- Always start fresh when opening the game
    Respawn()
    isRunning = true
    if gameFrame and gameFrame.EnableKeys then
        gameFrame.EnableKeys()
    end
end

function PhoneAgarioGame:OnHide()
    -- Save highscore before leaving
    SaveHighScore()
    -- Mark as dead + not running so nothing processes while closed
    myBlob.alive = false
    isRunning = false
    moveDir.x = 0
    moveDir.y = 0
    if gameFrame and gameFrame.DisableKeys then
        gameFrame.DisableKeys()
    end
    BroadcastLeave()
    FlushQueue()
end
