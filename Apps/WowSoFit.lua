-- WowSoFit - Fitness Tracker for World of Warcraft
-- Because your character deserves to hit their step goal too.

local ADDON_NAME = "HearthPhone"
local UPDATE_INTERVAL = 0.2

-- Saved data
WowSoFitDB = WowSoFitDB or {}

-- Global state table (read by HearthPhone)
WowSoFitState = {
    running = false,
    freeMode = false,
    totalDist = 0,
    startTime = 0,
    currentPinIndex = 1,
    totalPins = 0,
}

-- Runtime state
local running = false
local freeMode = false
local runData = nil
local pins = {}
local currentPinIndex = 1
local lastX, lastY = 0, 0
local pinMode = false
local RefreshMapPins -- forward declaration
local CmdClearPins -- forward declaration

-- Jump tracker (per run)
local runJumps = 0

hooksecurefunc("JumpOrAscendStart", function()
    if running then
        runJumps = runJumps + 1
    end
end)

-- Get player world position (returns x, y in yards)
local function GetPlayerPos()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil, nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return nil, nil end
    local y, x = UnitPosition("player")
    return x, y
end

-- Distance between two world points in yards
local function Distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--------------------------------------------------------------------------
-- Sync global state (called every update tick)
--------------------------------------------------------------------------
local function SyncState()
    WowSoFitState.running = running
    WowSoFitState.freeMode = freeMode
    WowSoFitState.totalDist = runData and runData.totalDist or 0
    WowSoFitState.startTime = runData and runData.startTime or 0
    WowSoFitState.stoppedElapsed = runData and runData.stoppedElapsed or nil
    WowSoFitState.currentPinIndex = currentPinIndex
    WowSoFitState.totalPins = #pins
end

--------------------------------------------------------------------------
-- Waypoint navigation
--------------------------------------------------------------------------
local function SetWaypointToPin(index)
    if index > #pins then
        pcall(C_Map.ClearUserWaypoint)
        print("|cff00ff00[WowSoFit]|r Route complete! You reached all pins!")
        return
    end
    local pin = pins[index]
    if pin.mapID and pin.mapX and pin.mapY then
        local ok, err = pcall(function()
            local uiMapPoint = UiMapPoint.CreateFromCoordinates(pin.mapID, pin.mapX, pin.mapY)
            C_Map.SetUserWaypoint(uiMapPoint)
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end)
        if ok then
            print(format("|cff00ff00[WowSoFit]|r Head to pin %d/%d! (map %d, %.1f%% %.1f%%)", index, #pins, pin.mapID,
                pin.mapX * 100, pin.mapY * 100))
        else
            print(format("|cff00ff00[WowSoFit]|r Head to pin %d/%d! (waypoint failed: %s)", index, #pins, tostring(err)))
        end
    else
        print(format("|cffff4444[WowSoFit]|r Pin %d has no map data!", index))
    end
end

local function CheckPinReached()
    if freeMode then return end
    if currentPinIndex > #pins then return end
    local pin = pins[currentPinIndex]

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID or mapID ~= pin.mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end

    local dx = pos.x - pin.mapX
    local dy = pos.y - pin.mapY
    local mapDist = math.sqrt(dx * dx + dy * dy)

    -- ~0.01 in map coords is roughly 30-40 yards depending on zone
    if mapDist < 0.01 then
        print(format("|cff00ff00[WowSoFit]|r Reached pin %d/%d!", currentPinIndex, #pins))
        currentPinIndex = currentPinIndex + 1
        SetWaypointToPin(currentPinIndex)
        RefreshMapPins()
    end
end

--------------------------------------------------------------------------
-- Tracking update
--------------------------------------------------------------------------
local elapsed_timer = 0
local tracker = CreateFrame("Frame")
tracker:SetScript("OnUpdate", function(self, elapsed)
    if not running then return end
    elapsed_timer = elapsed_timer + elapsed
    if elapsed_timer < UPDATE_INTERVAL then return end
    elapsed_timer = 0

    local x, y = GetPlayerPos()
    if not x or not y then return end

    if lastX ~= 0 or lastY ~= 0 then
        local d = Distance(lastX, lastY, x, y)
        if d < 100 and d > 0.1 then
            runData.totalDist = runData.totalDist + d
        end
    end
    lastX, lastY = x, y

    CheckPinReached()
    SyncState()
end)

--------------------------------------------------------------------------
-- Map Pin Markers + Route Lines (shown on world map)
--------------------------------------------------------------------------
local mapPinFrames = {}
local mapLineFrames = {}

local function AddPinToList(pin)
    table.insert(pins, pin)
    WowSoFitDB.pins = WowSoFitDB.pins or {}
    table.insert(WowSoFitDB.pins, pin)
end

RefreshMapPins = function()
    for _, f in ipairs(mapPinFrames) do f:Hide() end
    for _, l in ipairs(mapLineFrames) do l:Hide() end

    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end

    local canvas = WorldMapFrame.ScrollContainer.Child
    if not canvas then return end

    local currentMapID = WorldMapFrame:GetMapID()
    if not currentMapID then return end

    local canvasW, canvasH = canvas:GetSize()
    local visiblePins = {}

    for i, pin in ipairs(pins) do
        if pin.mapID == currentMapID then
            local f = mapPinFrames[i]
            if not f then
                f = CreateFrame("Frame", nil, canvas)
                f:SetSize(24, 24)
                f:SetFrameStrata("HIGH")
                f:SetFrameLevel(10)

                f.bg = f:CreateTexture(nil, "BACKGROUND")
                f.bg:SetAllPoints()
                f.bg:SetColorTexture(0.1, 0.8, 0.1, 0.7)

                f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
                f.text:SetTextColor(1, 1, 1, 1)
                f:EnableMouse(true)
                f:SetScript("OnMouseUp", function(self, btn)
                    if btn == "RightButton" and self.pinIndex then
                        table.remove(pins, self.pinIndex)
                        WowSoFitDB.pins = pins
                        if currentPinIndex > self.pinIndex then
                            currentPinIndex = currentPinIndex - 1
                        end
                        if currentPinIndex > #pins then
                            currentPinIndex = math.max(1, #pins)
                        end
                        print(format("|cff00ff00[WowSoFit]|r Removed pin %d. %d pin(s) remaining.", self.pinIndex, #pins))
                        RefreshMapPins()
                    end
                end)

                mapPinFrames[i] = f
            end

            if running and not freeMode and i == currentPinIndex then
                f.bg:SetColorTexture(1, 0.4, 0, 0.9)
                f:SetSize(28, 28)
            else
                f.bg:SetColorTexture(0.1, 0.8, 0.1, 0.7)
                f:SetSize(24, 24)
            end

            f.text:SetText(i)
            f.pinIndex = i
            f:SetParent(canvas)
            f:ClearAllPoints()
            local px = pin.mapX * canvasW
            local py = -pin.mapY * canvasH
            f:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
            f:Show()

            table.insert(visiblePins, { x = px, y = py, index = i })
        end
    end

    for li = 1, #visiblePins - 1 do
        local p1 = visiblePins[li]
        local p2 = visiblePins[li + 1]

        local line = mapLineFrames[li]
        if not line then
            local lineFrame = CreateFrame("Frame", nil, canvas)
            lineFrame:SetAllPoints(canvas)
            lineFrame:SetFrameStrata("HIGH")
            lineFrame:SetFrameLevel(5)
            line = lineFrame:CreateLine(nil, "OVERLAY")
            line:SetThickness(2)
            line._parent = lineFrame
            mapLineFrames[li] = line
        end

        line._parent:SetParent(canvas)
        line._parent:SetAllPoints(canvas)
        line._parent:Show()

        if running and not freeMode and p1.index < currentPinIndex then
            line:SetColorTexture(0.2, 1, 0.2, 0.8)
        else
            line:SetColorTexture(1, 0.85, 0, 0.6)
        end

        line:SetStartPoint("TOPLEFT", canvas, p1.x, p1.y)
        line:SetEndPoint("TOPLEFT", canvas, p2.x, p2.y)
        line:Show()
    end
end

--------------------------------------------------------------------------
-- Map click handler for pin placement
--------------------------------------------------------------------------
local function OnMapClick(canvas, button)
    if not pinMode then return end
    if button ~= "LeftButton" then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end

    local child = WorldMapFrame.ScrollContainer.Child
    local cursorX, cursorY = GetCursorPosition()
    local scale = child:GetEffectiveScale()
    local left, top = child:GetLeft(), child:GetTop()
    local canvasW, canvasH = child:GetSize()

    local mapX = (cursorX / scale - left) / canvasW
    local mapY = (top - cursorY / scale) / canvasH

    if mapX < 0 or mapX > 1 or mapY < 0 or mapY > 1 then return end

    local pin = {
        mapID = mapID,
        mapX = mapX,
        mapY = mapY,
        worldX = nil,
        worldY = nil,
    }

    local _, pos1 = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
    local _, pos2 = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
    if pos1 and pos2 then
        pin.worldX = pos1.x + mapX * (pos2.x - pos1.x)
        pin.worldY = pos1.y + mapY * (pos2.y - pos1.y)
    end

    AddPinToList(pin)
    print(format("|cff00ff00[WowSoFit]|r Pin %d placed on map! (%.1f%%, %.1f%%)", #pins, mapX * 100, mapY * 100))
    RefreshMapPins()
end

--------------------------------------------------------------------------
-- World Map integration - button + click hook
--------------------------------------------------------------------------
local mapButton = nil
local mapHooked = false

local function SetupMapButton()
    if mapButton then return end

    mapButton = CreateFrame("Button", "WowSoFitMapButton", WorldMapFrame.ScrollContainer, "UIPanelButtonTemplate")
    mapButton:SetSize(120, 26)
    local canvasContainer = WorldMapFrame:GetCanvasContainer()
    mapButton:SetPoint("TOPLEFT", canvasContainer, "TOPLEFT", 4, -4)
    mapButton:SetFrameStrata("TOOLTIP")
    mapButton:SetText("WowSoFit: Plan")

    local function UpdateButtonText()
        if pinMode then
            mapButton:SetText("|cff00ff00Planning...|r")
        else
            mapButton:SetText("WowSoFit (" .. #pins .. ")")
        end
    end

    mapButton:SetScript("OnClick", function()
        pinMode = not pinMode
        UpdateButtonText()
        if pinMode then
            print("|cff00ff00[WowSoFit]|r Click the map to place pins. Right-click a pin to remove it.")
        else
            print(format("|cff00ff00[WowSoFit]|r Planning done. %d pin(s) in route.", #pins))
        end
    end)

    -- Clear button next to plan button
    local clearMapBtn = CreateFrame("Button", nil, WorldMapFrame.ScrollContainer, "UIPanelButtonTemplate")
    clearMapBtn:SetSize(70, 26)
    clearMapBtn:SetPoint("LEFT", mapButton, "RIGHT", 4, 0)
    clearMapBtn:SetFrameStrata("TOOLTIP")
    clearMapBtn:SetText("Clear")
    clearMapBtn:SetScript("OnClick", function()
        CmdClearPins()
        pinMode = false
        UpdateButtonText()
        print("|cff00ff00[WowSoFit]|r Route cleared.")
    end)

    mapButton:SetScript("OnShow", function()
        UpdateButtonText()
        RefreshMapPins()
    end)

    if not mapHooked then
        WorldMapFrame.ScrollContainer:HookScript("OnMouseUp", function(self, btn)
            if pinMode then
                OnMapClick(self, btn)
            end
        end)
        mapHooked = true
    end

    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        RefreshMapPins()
    end)
end

--------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------
local function CmdStart()
    if running then return end

    -- Resume from paused state if we have existing data
    if runData and runData.stoppedElapsed then
        -- Resume: adjust startTime so elapsed continues from where we left off
        running = true
        runData.startTime = GetTime() - runData.stoppedElapsed
        runData.stoppedElapsed = nil
        lastX, lastY = 0, 0
        elapsed_timer = 0

        if not freeMode and currentPinIndex <= #pins then
            SetWaypointToPin(currentPinIndex)
        end
        SyncState()
        return
    end

    -- Fresh start
    if #pins < 1 then
        freeMode = true
    else
        freeMode = false
    end

    running = true
    runJumps = 0
    runData = {
        startTime = GetTime(),
        totalDist = 0,
    }
    lastX, lastY = 0, 0
    currentPinIndex = 1
    elapsed_timer = 0
    pinMode = false

    if not freeMode then
        SetWaypointToPin(1)
    end
    SyncState()
end

local function CmdStop()
    if not running then return end
    running = false
    if not freeMode then
        pcall(C_Map.ClearUserWaypoint)
    end

    local elapsed = GetTime() - runData.startTime
    runData.stoppedElapsed = elapsed
    SyncState()
end

local function CmdClear()
    running = false
    freeMode = false
    runData = nil
    currentPinIndex = 1
    pcall(C_Map.ClearUserWaypoint)
    SyncState()
end

CmdClearPins = function()
    pins = {}
    currentPinIndex = 1
    WowSoFitDB.pins = {}
    pcall(C_Map.ClearUserWaypoint)
    RefreshMapPins()
    SyncState()
end

local function CmdRoute()
    if #pins == 0 then
        print("|cff00ff00[WowSoFit]|r No pins set. Open the map and click 'WowSoFit' to plan!")
        return
    end
    print(format("|cff00ff00[WowSoFit]|r Route has %d pin(s):", #pins))
    for i, pin in ipairs(pins) do
        print(format("  %d. Map coords: (%.1f%%, %.1f%%)", i, (pin.mapX or 0) * 100, (pin.mapY or 0) * 100))
    end
end

local function CmdUndo()
    if #pins == 0 then
        print("|cff00ff00[WowSoFit]|r No pins to undo.")
        return
    end
    table.remove(pins)
    WowSoFitDB.pins = pins
    RefreshMapPins()
    print(format("|cff00ff00[WowSoFit]|r Removed last pin. %d pin(s) remaining.", #pins))
end

--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- Load saved pins + setup map button when map loads
--------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addon)
    if addon ~= ADDON_NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    WowSoFitDB = WowSoFitDB or {}
    if WowSoFitDB.pins then
        pins = WowSoFitDB.pins
    end

    if WorldMapFrame then
        SetupMapButton()
    else
        local mapWaiter = CreateFrame("Frame")
        mapWaiter:RegisterEvent("ADDON_LOADED")
        mapWaiter:SetScript("OnEvent", function(mw, ev, name)
            if name == "Blizzard_WorldMap" then
                mw:UnregisterEvent("ADDON_LOADED")
                SetupMapButton()
            end
        end)
    end

    print("|cff00ff00WowSoFit|r loaded! Type /wsf start for free run, or plan a route on the map.")
end)

--------------------------------------------------------------------------
-- Phone UI App (Init/OnShow/OnHide/Update pattern)
--------------------------------------------------------------------------
WowSoFitApp = {}

local YARDS_PER_STEP = 2.5
local CALORIES_PER_YARD = 0.05

local fitPage, fitVisible = nil, false
local fitTitle, fitStatus, fitDist, fitSteps, fitCal, fitTime, fitPace, fitPin
local fitJumps, mapHint
local mapArea, mapBg, playerDot, arrowFrame, phoneArrowTex, phoneArrowDist
local mapTiles = {}
local miniPinDots = {}
local miniRouteLines = {}
local lastMapTextureID = nil

local function FormatTime(sec)
    local m = math.floor(sec / 60)
    local s = math.floor(sec % 60)
    return format("%d:%02d", m, s)
end

local function FormatPace(yards, seconds)
    if yards < 1 then return "--:--" end
    local yardPerSec = yards / seconds
    local secPerMile = 1760 / yardPerSec
    return FormatTime(secPerMile) .. "/mi"
end

local function UpdateMapTexture()
    for _, t in ipairs(mapTiles) do t:Hide() end

    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end

    local layers = C_Map.GetMapArtLayers(mapID)
    if not layers or not layers[1] then return end

    local layer = layers[1]
    local tileW = layer.tileWidth or 256
    local tileH = layer.tileHeight or 256
    local fullW = layer.layerWidth or tileW
    local fullH = layer.layerHeight or tileH
    local cols = math.ceil(fullW / tileW)
    local rows = math.ceil(fullH / tileH)

    local filePrefix = C_Map.GetMapArtID(mapID)
    if not filePrefix then return end

    local areaW, areaH = mapArea:GetSize()
    local tilePxW = areaW / cols
    local tilePxH = areaH / rows

    local idx = 0
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            idx = idx + 1
            local tex = mapTiles[idx]
            if not tex then
                tex = mapArea:CreateTexture(nil, "BACKGROUND", nil, 1)
                mapTiles[idx] = tex
            end
            local texPath = format("Interface\\WorldMap\\%d\\%d-%d-%d", filePrefix, filePrefix, row, col)
            tex:SetTexture(texPath)
            tex:SetSize(tilePxW, tilePxH)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", mapArea, "TOPLEFT", col * tilePxW, -(row * tilePxH))
            tex:SetDesaturated(true)
            tex:SetVertexColor(0.6, 0.7, 0.6, 0.9)
            tex:Show()
        end
    end
end

function WowSoFitApp:Init(parent)
    if fitPage then return end
    fitPage = parent

    local SCREEN_W = parent:GetWidth() or 170
    local SCREEN_H = parent:GetHeight() or 300

    -- Title
    fitTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fitTitle:SetPoint("TOP", 0, -2)
    fitTitle:SetText("|cff33ff33WowSoFit|r")
    local fitTitleFont = fitTitle:GetFont()
    if fitTitleFont then fitTitle:SetFont(fitTitleFont, 10, "OUTLINE") end

    -- Mini route map area
    mapArea = CreateFrame("Frame", nil, parent)
    mapArea:SetPoint("TOPLEFT", 4, -20)
    mapArea:SetPoint("TOPRIGHT", -4, -20)
    mapArea:SetHeight(SCREEN_H * 0.38)

    mapBg = mapArea:CreateTexture(nil, "BACKGROUND")
    mapBg:SetAllPoints()
    mapBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    mapBg:SetVertexColor(0.05, 0.08, 0.05, 0.9)

    -- Map border
    local mapBorder = mapArea:CreateTexture(nil, "BORDER")
    mapBorder:SetPoint("TOPLEFT", -1, 1)
    mapBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    mapBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    mapBorder:SetVertexColor(0.2, 0.5, 0.2, 0.5)

    -- Hint text when no route is set
    mapHint = mapArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mapHint:SetPoint("CENTER", 0, 0)
    mapHint:SetWidth(mapArea:GetWidth() or 140)
    mapHint:SetJustifyH("CENTER")
    mapHint:SetText("|cff66aa66Open the World Map\nand click WowSoFit\nto plan a route!|r")
    local hf = mapHint:GetFont()
    if hf then mapHint:SetFont(hf, 8, "") end

    -- Player dot
    playerDot = mapArea:CreateTexture(nil, "OVERLAY")
    playerDot:SetSize(8, 8)
    playerDot:SetTexture("Interface\\Buttons\\WHITE8x8")
    playerDot:SetVertexColor(0.3, 0.6, 1, 1)

    -- Direction arrow
    arrowFrame = CreateFrame("Frame", nil, mapArea)
    arrowFrame:SetSize(20, 20)
    arrowFrame:SetPoint("BOTTOMRIGHT", -3, 3)
    arrowFrame:SetFrameLevel(mapArea:GetFrameLevel() + 5)

    phoneArrowTex = arrowFrame:CreateTexture(nil, "OVERLAY")
    phoneArrowTex:SetSize(18, 18)
    phoneArrowTex:SetPoint("CENTER")
    pcall(function() phoneArrowTex:SetAtlas("Navigation-Tracked-Arrow") end)
    phoneArrowTex:SetVertexColor(1, 0.7, 0.2, 1)

    phoneArrowDist = mapArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    phoneArrowDist:SetPoint("RIGHT", arrowFrame, "LEFT", -2, 0)
    phoneArrowDist:SetTextColor(0.9, 0.8, 0.4, 1)
    local adFont = phoneArrowDist:GetFont()
    if adFont then phoneArrowDist:SetFont(adFont, 7, "OUTLINE") end

    -- Stats area
    local statsArea = CreateFrame("Frame", nil, parent)
    statsArea:SetPoint("TOPLEFT", mapArea, "BOTTOMLEFT", 0, -4)
    statsArea:SetPoint("TOPRIGHT", mapArea, "BOTTOMRIGHT", 0, -4)
    statsArea:SetHeight(SCREEN_H * 0.38)

    local function MakeFitLabel(yOff)
        local fs = statsArea:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 4, yOff)
        fs:SetPoint("TOPRIGHT", -4, yOff)
        fs:SetJustifyH("LEFT")
        local f = fs:GetFont()
        if f then fs:SetFont(f, 9, "") end
        return fs
    end

    fitStatus = MakeFitLabel(-2)
    fitDist   = MakeFitLabel(-14)
    fitSteps  = MakeFitLabel(-26)
    fitJumps  = MakeFitLabel(-38)
    fitCal    = MakeFitLabel(-50)
    fitTime   = MakeFitLabel(-62)
    fitPace   = MakeFitLabel(-74)
    fitPin    = MakeFitLabel(-86)

    -- Control buttons
    local ctrlArea = CreateFrame("Frame", nil, parent)
    ctrlArea:SetPoint("BOTTOMLEFT", 4, 4)
    ctrlArea:SetPoint("BOTTOMRIGHT", -4, 4)
    ctrlArea:SetHeight(22)

    local function MakeCtrlButton(label, xAnchor, width)
        local btn = CreateFrame("Button", nil, ctrlArea)
        btn:SetSize(width, 18)
        btn:SetPoint("LEFT", xAnchor, 0)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        local bgOk = pcall(function() bg:SetAtlas("UI-HUD-ActionBar-Gryphon-FillSmall") end)
        if not bgOk or not bg:GetAtlas() then
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        end
        bg:SetVertexColor(0.25, 0.5, 0.3, 0.9)

        local bTop = btn:CreateTexture(nil, "BORDER")
        bTop:SetPoint("TOPLEFT") bTop:SetPoint("TOPRIGHT") bTop:SetHeight(1)
        bTop:SetTexture("Interface\\Buttons\\WHITE8x8") bTop:SetVertexColor(0.4, 0.7, 0.4, 0.6)
        local bBot = btn:CreateTexture(nil, "BORDER")
        bBot:SetPoint("BOTTOMLEFT") bBot:SetPoint("BOTTOMRIGHT") bBot:SetHeight(1)
        bBot:SetTexture("Interface\\Buttons\\WHITE8x8") bBot:SetVertexColor(0.1, 0.2, 0.1, 0.6)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(0.5, 0.8, 0.5, 0.3)

        local text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(label)
        text:SetTextColor(0.9, 1, 0.9, 1)
        local f = text:GetFont()
        if f then text:SetFont(f, 8, "OUTLINE") end

        btn.label = text
        return btn
    end

    local btnWidth = math.floor((SCREEN_W - 8) / 3)
    local startBtn = MakeCtrlButton("Start", 0, btnWidth)
    local stopBtn  = MakeCtrlButton("Stop", btnWidth + 2, btnWidth)
    local clearBtn = MakeCtrlButton("Clear", (btnWidth + 2) * 2, btnWidth)

    startBtn:SetScript("OnClick", function() CmdStart() end)
    stopBtn:SetScript("OnClick", function() CmdStop() end)
    clearBtn:SetScript("OnClick", function() CmdClear() end)
end

function WowSoFitApp:OnShow()
    fitVisible = true
end

function WowSoFitApp:OnHide()
    fitVisible = false
end

function WowSoFitApp:Update()
    if not fitVisible or not fitPage then return end

    -- Refresh map texture when zone changes
    local curMapID = C_Map.GetBestMapForUnit("player")
    if curMapID ~= lastMapTextureID then
        lastMapTextureID = curMapID
        UpdateMapTexture()
    end

    -- Read state
    local state = WowSoFitState
    if not state then
        fitStatus:SetText("|cff888888NO DATA|r")
        arrowFrame:Hide()
        phoneArrowDist:Hide()
        return
    end

    local wsfRunning = state.running
    local wsfFreeMode = state.freeMode
    local wsfPins = (WowSoFitDB and WowSoFitDB.pins) or {}

    local dist = state.totalDist or 0
    local hasData = dist > 0 or wsfRunning

    if wsfRunning then
        local elapsed = GetTime() - (state.startTime or GetTime())
        local steps = math.floor(dist / YARDS_PER_STEP)
        local cal = dist * CALORIES_PER_YARD

        if wsfFreeMode then
            fitStatus:SetText("|cff88ccffFREE RUN|r")
        else
            fitStatus:SetText("|cff33ff33RUNNING|r")
        end
        fitDist:SetText(format("Distance: |cffffd700%.0f|r yards", dist))
        fitSteps:SetText(format("Steps: |cffffd700%d|r", steps))
        fitCal:SetText(format("Calories: |cffffd700%.1f|r kcal", cal))
        fitTime:SetText("Time: |cffffd700" .. FormatTime(elapsed) .. "|r")
        fitPace:SetText("Pace: |cffffd700" .. FormatPace(dist, elapsed) .. "|r")
    elseif hasData and state.stoppedElapsed then
        local elapsed = state.stoppedElapsed
        local steps = math.floor(dist / YARDS_PER_STEP)
        local cal = dist * CALORIES_PER_YARD

        fitStatus:SetText("|cffffaa00STOPPED|r")
        fitDist:SetText(format("Distance: |cffffd700%.0f|r yards", dist))
        fitSteps:SetText(format("Steps: |cffffd700%d|r", steps))
        fitCal:SetText(format("Calories: |cffffd700%.1f|r kcal", cal))
        fitTime:SetText("Time: |cffffd700" .. FormatTime(elapsed) .. "|r")
        fitPace:SetText("Pace: |cffffd700" .. FormatPace(dist, elapsed) .. "|r")
    else
        fitStatus:SetText("|cff888888IDLE|r")
        fitDist:SetText("Distance: |cffffd700--|r")
        fitSteps:SetText("Steps: |cffffd700--|r")
        fitCal:SetText("Calories: |cffffd700--|r")
        fitTime:SetText("Time: |cffffd700--|r")
        fitPace:SetText("Pace: |cffffd700--|r")
    end

    -- Route progress
    if #wsfPins > 0 and not wsfFreeMode then
        local pinIdx = state.currentPinIndex or 1
        if pinIdx > #wsfPins then
            fitPin:SetText(format("Route: |cff33ff33Complete!|r (%d pins)", #wsfPins))
        else
            fitPin:SetText(format("Route: |cffffd700%d|r / %d pins", pinIdx, #wsfPins))
        end
    else
        fitPin:SetText("")
    end

    -- Jump tracker
    fitJumps:SetText(format("Jumps: |cffffd700%d|r", runJumps))

    -- Direction arrow
    local targetPin = nil
    if wsfRunning and not wsfFreeMode then
        local pinIdx = state.currentPinIndex or 1
        if pinIdx <= #wsfPins then
            targetPin = wsfPins[pinIdx]
        end
    end

    local arrowMapID = C_Map.GetBestMapForUnit("player")
    if targetPin and arrowMapID and targetPin.mapID == arrowMapID then
        local pos = C_Map.GetPlayerMapPosition(arrowMapID, "player")
        if pos then
            local dx = targetPin.mapX - pos.x
            local dy = -(targetPin.mapY - pos.y)
            local angle = math.atan2(dx, dy)
            local facing = GetPlayerFacing() or 0
            phoneArrowTex:SetRotation(-(angle + facing))

            local mapDist = math.sqrt(dx * dx + dy * dy)
            local estYards = mapDist * 3500
            if estYards > 1000 then
                phoneArrowDist:SetText(format("%.1f mi", estYards / 1760))
            else
                phoneArrowDist:SetText(format("%.0f yds", estYards))
            end
            arrowFrame:Show()
            phoneArrowDist:Show()
        end
    else
        arrowFrame:Hide()
        phoneArrowDist:Hide()
    end

    -- Map hint
    mapHint:SetShown(#wsfPins == 0 and not wsfRunning)

    -- Mini route map
    for _, d in ipairs(miniPinDots) do d:Hide() end
    for _, l in ipairs(miniRouteLines) do l:Hide() end

    if #wsfPins == 0 then
        playerDot:Hide()
        return
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local visiblePins = {}
    for i, pin in ipairs(wsfPins) do
        if pin.mapID == mapID then
            table.insert(visiblePins, { x = pin.mapX, y = pin.mapY, index = i })
        end
    end

    if #visiblePins == 0 then
        playerDot:Hide()
        return
    end

    local minX, maxX, minY, maxY = 1, 0, 1, 0
    for _, p in ipairs(visiblePins) do
        if p.x < minX then minX = p.x end
        if p.x > maxX then maxX = p.x end
        if p.y < minY then minY = p.y end
        if p.y > maxY then maxY = p.y end
    end

    local playerPos = C_Map.GetPlayerMapPosition(mapID, "player")
    if playerPos then
        if playerPos.x < minX then minX = playerPos.x end
        if playerPos.x > maxX then maxX = playerPos.x end
        if playerPos.y < minY then minY = playerPos.y end
        if playerPos.y > maxY then maxY = playerPos.y end
    end

    local padX = math.max((maxX - minX) * 0.15, 0.01)
    local padY = math.max((maxY - minY) * 0.15, 0.01)
    minX = minX - padX
    maxX = maxX + padX
    minY = minY - padY
    maxY = maxY + padY
    local rangeX = math.max(maxX - minX, 0.001)
    local rangeY = math.max(maxY - minY, 0.001)

    local mapW, mapH = mapArea:GetSize()

    local function ToPixel(mx, my)
        local px = ((mx - minX) / rangeX) * mapW
        local py = -((my - minY) / rangeY) * mapH
        return px, py
    end

    -- Route lines
    for li = 1, #visiblePins - 1 do
        local p1 = visiblePins[li]
        local p2 = visiblePins[li + 1]
        local line = miniRouteLines[li]
        if not line then
            line = mapArea:CreateLine(nil, "ARTWORK")
            line:SetThickness(1.5)
            miniRouteLines[li] = line
        end
        local x1, y1 = ToPixel(p1.x, p1.y)
        local x2, y2 = ToPixel(p2.x, p2.y)
        line:SetStartPoint("TOPLEFT", mapArea, x1, y1)
        line:SetEndPoint("TOPLEFT", mapArea, x2, y2)
        line:SetColorTexture(0.4, 0.9, 0.3, 0.6)
        line:Show()
    end

    -- Pin dots
    for i, p in ipairs(visiblePins) do
        local dot = miniPinDots[i]
        if not dot then
            dot = mapArea:CreateTexture(nil, "OVERLAY")
            dot:SetSize(6, 6)
            dot:SetTexture("Interface\\Buttons\\WHITE8x8")
            miniPinDots[i] = dot
        end
        local px, py = ToPixel(p.x, p.y)
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", mapArea, "TOPLEFT", px, py)
        dot:SetVertexColor(0.2, 1, 0.2, 1)
        dot:Show()
    end

    -- Player dot
    if playerPos then
        local px, py = ToPixel(playerPos.x, playerPos.y)
        playerDot:ClearAllPoints()
        playerDot:SetPoint("CENTER", mapArea, "TOPLEFT", px, py)
        playerDot:Show()
    else
        playerDot:Hide()
    end
end
