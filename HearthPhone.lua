-- HearthPhone
-- A phone-style UI panel for quick access to Blizzard panels

-- The bezel texture is 256x512, we scale it down to a nice on-screen size
local PHONE_WIDTH = 210
local PHONE_HEIGHT = 420
local BEZEL_INSET_LEFT = 10 * (PHONE_WIDTH / 256)
local BEZEL_INSET_RIGHT = 10 * (PHONE_WIDTH / 256)
local BEZEL_INSET_TOP = 60 * (PHONE_HEIGHT / 512)
local BEZEL_INSET_BOTTOM = 50 * (PHONE_HEIGHT / 512)

local ICON_SIZE = 34
local ICON_PADDING = 10
local COLS = 4
local WIDGET_HEIGHT = 40
local STATUS_BAR_HEIGHT = 18

local ADDON_PATH = "Interface\\AddOns\\HearthPhone\\Textures\\"

-- App definitions (tools first, then games)
local apps = {
    -- Tools
    {
        label = "Messages",
        icon = "communities-icon-chat",
        page = "gchat",
    },
    {
        label = "Phone",
        texture = ADDON_PATH .. "IconPhone",
        page = "phone",
    },
    {
        label = "Social",
        texture = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
        page = "social",
    },
    {
        label = "Music",
        texture = "Interface\\Icons\\INV_Misc_Drum_01",
        page = "music",
    },
    {
        label = "Notes",
        texture = ADDON_PATH .. "IconNotes",
        page = "notes",
    },
    {
        label = "Calc",
        texture = ADDON_PATH .. "IconCalculator",
        page = "calc",
    },
    {
        label = "Weather",
        texture = ADDON_PATH .. "IconWeather",
        page = "weather",
    },
    {
        label = "Timer",
        texture = ADDON_PATH .. "IconTimer",
        page = "timer",
    },
    {
        label = "Calendar",
        texture = ADDON_PATH .. "IconCalendar",
        page = "calendar",
    },
    {
        label = "DPS Meter",
        texture = "Interface\\Icons\\Ability_Warrior_BattleShout",
        page = "dpsmeter",
    },
    {
        label = "Uber",
        texture = "Interface\\Icons\\Ability_Mount_RidingHorse",
        page = "uber",
    },
    {
        label = "Fitness",
        icon = "UI-HUD-MicroMenu-AdventureGuide-Mouseover",
        page = "fitness",
    },
    {
        label = "Camera",
        texture = "Interface\\Icons\\INV_Misc_SpyGlass_03",
        page = "camera",
    },
    {
        label = "Gallery",
        texture = "Interface\\Icons\\INV_Misc_Film_01",
        page = "gallery",
    },
    {
        label = "Settings",
        texture = "Interface\\Icons\\INV_Gizmo_02",
        page = "settings",
    },
    {
        label = "Toys",
        texture = ADDON_PATH .. "IconToys",
        page = "toys",
    },
    -- Games
    {
        label = "Snake",
        icon = "WildBattlePetCapturable",
        page = "snake",
    },
    {
        label = "Tetris",
        texture = ADDON_PATH .. "IconTetris",
        page = "tetris",
    },
    {
        label = "TicTacToe",
        texture = ADDON_PATH .. "IconTicTacToe",
        page = "tictactoe",
    },
    {
        label = "Candy",
        texture = ADDON_PATH .. "IconCandyCrush",
        page = "candy",
    },
    {
        label = "2048",
        texture = ADDON_PATH .. "Icon2048",
        page = "2048",
    },
    {
        label = "Mines",
        texture = ADDON_PATH .. "IconMinesweeper",
        page = "mines",
    },
    {
        label = "Flappy",
        texture = ADDON_PATH .. "IconFlappy",
        page = "flappy",
    },
    {
        label = "Wordle",
        texture = ADDON_PATH .. "IconWordle",
        page = "wordle",
    },
    {
        label = "Angry Birds",
        texture = ADDON_PATH .. "IconAngryBirds",
        page = "angrybirds",
    },
    {
        label = "Invaders",
        texture = ADDON_PATH .. "IconSpaceInvader",
        page = "shooter",
    },
    {
        label = "Temple Run",
        texture = ADDON_PATH .. "IconTempleRun",
        page = "templerun",
    },
    {
        label = "Subway",
        texture = ADDON_PATH .. "IconSubwaySurf",
        page = "subway",
    },
    {
        label = "Battleship",
        texture = ADDON_PATH .. "IconBattleship",
        page = "battleship",
    },
    {
        label = "Agar.io",
        texture = "Interface\\Icons\\INV_Misc_Slime_01",
        page = "agario",
    },
    {
        label = "Survivor",
        texture = ADDON_PATH .. "IconRoguelike",
        page = "roguelike",
    },
    {
        label = "Tower TD",
        texture = ADDON_PATH .. "IconTowerDefense",
        page = "towerdefense",
    },
}

-- Saved position
HearthPhoneDB = HearthPhoneDB or {}

---------------------------------------------------------------------------
-- Main phone frame
---------------------------------------------------------------------------
local phone = CreateFrame("Frame", "HearthPhoneFrame", UIParent)
phone:SetSize(PHONE_WIDTH, PHONE_HEIGHT)
phone:SetPoint("CENTER")
phone:SetMovable(true)
phone:EnableMouse(true)
phone:RegisterForDrag("LeftButton")
phone:SetClampedToScreen(true)
phone:SetFrameStrata("HIGH")
phone:SetScript("OnDragStart", phone.StartMoving)
phone:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    HearthPhoneDB.point = point
    HearthPhoneDB.relPoint = relPoint
    HearthPhoneDB.x = x
    HearthPhoneDB.y = y
end)

---------------------------------------------------------------------------
-- Screen background
---------------------------------------------------------------------------
-- Solid black fallback behind the gallery image
local screenBgFallback = phone:CreateTexture(nil, "BACKGROUND", nil, 0)
screenBgFallback:SetPoint("TOPLEFT", BEZEL_INSET_LEFT, -BEZEL_INSET_TOP)
screenBgFallback:SetPoint("BOTTOMRIGHT", -BEZEL_INSET_RIGHT, BEZEL_INSET_BOTTOM - 4)
screenBgFallback:SetTexture("Interface\\Buttons\\WHITE8x8")
screenBgFallback:SetVertexColor(0.08, 0.08, 0.10, 1)

-- Home screen gallery image
local screenBg = phone:CreateTexture(nil, "BACKGROUND", nil, 1)
screenBg:SetPoint("TOPLEFT", BEZEL_INSET_LEFT, -BEZEL_INSET_TOP)
screenBg:SetPoint("BOTTOMRIGHT", -BEZEL_INSET_RIGHT, BEZEL_INSET_BOTTOM - 4)
screenBg:SetVertexColor(0.5, 0.5, 0.5, 1)
PhoneGalleryApp._screenBg = screenBg

---------------------------------------------------------------------------
-- Phone bezel overlay
---------------------------------------------------------------------------
local bezel = phone:CreateTexture(nil, "OVERLAY", nil, 7)
bezel:SetAllPoints()
bezel:SetTexture(ADDON_PATH .. "PhoneBezel")

---------------------------------------------------------------------------
-- Screen content area
---------------------------------------------------------------------------
local screen = CreateFrame("Frame", nil, phone)
screen:SetPoint("TOPLEFT", BEZEL_INSET_LEFT + 2, -(BEZEL_INSET_TOP + 2))
screen:SetPoint("BOTTOMRIGHT", -(BEZEL_INSET_RIGHT + 2), BEZEL_INSET_BOTTOM + 2)
screen:SetFrameLevel(phone:GetFrameLevel() + 1)

---------------------------------------------------------------------------
-- Status bar
---------------------------------------------------------------------------
local statusBar = CreateFrame("Frame", nil, screen)
statusBar:SetPoint("TOPLEFT", -6, 2)
statusBar:SetPoint("TOPRIGHT", 6, 2)
statusBar:SetHeight(STATUS_BAR_HEIGHT + 2)
statusBar:SetFrameLevel(screen:GetFrameLevel() + 5)

-- Background on phone so it renders BELOW the bezel overlay but above the gallery image
local statusBarBg = phone:CreateTexture(nil, "ARTWORK", nil, 1)
statusBarBg:SetPoint("TOPLEFT", statusBar, "TOPLEFT")
statusBarBg:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT")
statusBarBg:SetTexture("Interface\\Buttons\\WHITE8x8")
statusBarBg:SetVertexColor(0.04, 0.04, 0.06, 0.82)

local timeText = statusBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
timeText:SetPoint("CENTER")
timeText:SetTextColor(0.9, 0.9, 0.9, 1)

local goldText = statusBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
goldText:SetPoint("RIGHT", -4, 0)
goldText:SetTextColor(1, 0.84, 0, 1)

local zoneText = statusBar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
zoneText:SetPoint("LEFT", 4, 0)
zoneText:SetPoint("RIGHT", timeText, "LEFT", -4, 0)
zoneText:SetJustifyH("LEFT")
zoneText:SetWordWrap(false)
zoneText:SetTextColor(0.6, 0.6, 0.65, 1)

-- Shared time formatting: respects clock format + timezone offset
-- Stored globally so settings and other files can use it too
function HearthPhone_GetTime()
    local h, m = GetGameTime()
    local offset = HearthPhoneDB and HearthPhoneDB.timezoneOffset or 0
    if offset ~= 0 then
        h = h + offset
        if h >= 24 then h = h - 24
        elseif h < 0 then h = h + 24 end
    end
    local use12h = HearthPhoneDB and HearthPhoneDB.clock12h
    if use12h then
        local suffix = h >= 12 and "PM" or "AM"
        local h12 = h % 12
        if h12 == 0 then h12 = 12 end
        return format("%d:%02d %s", h12, m, suffix)
    end
    return format("%02d:%02d", h, m)
end

local function UpdateStatusBar()
    timeText:SetText(HearthPhone_GetTime())

    local gold = floor(GetMoney() / 10000)
    goldText:SetText(gold .. "g")

    local zone = GetMinimapZoneText() or ""
    if #zone > 16 then zone = zone:sub(1, 15) .. ".." end
    zoneText:SetText(zone)
end

local sep = screen:CreateTexture(nil, "ARTWORK")
sep:SetPoint("TOPLEFT", statusBar, "BOTTOMLEFT", 0, -1)
sep:SetPoint("TOPRIGHT", statusBar, "BOTTOMRIGHT", 0, -1)
sep:SetHeight(1)
sep:SetTexture("Interface\\Buttons\\WHITE8x8")
sep:SetVertexColor(0.3, 0.3, 0.35, 0.5)

---------------------------------------------------------------------------
-- Page system: home (apps) and fitness
---------------------------------------------------------------------------
local currentPage = "home"

-- Home page container (app icons, leave 28px at bottom for home button)
local homePage = CreateFrame("Frame", nil, screen)
homePage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
homePage:SetPoint("BOTTOMRIGHT", 0, 28)

-- App page frames (consolidated into table to save locals)
local pg = {}
local function MakeAppPage(name, globalName)
    local f = CreateFrame("Frame", globalName, screen)
    f:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
    f:SetPoint("BOTTOMRIGHT", 0, 28)
    f:Hide()
    pg[name] = f
end
MakeAppPage("fitness"); MakeAppPage("snake", "HearthPhoneSnakePage")
MakeAppPage("gchat"); MakeAppPage("tetris", "HearthPhoneTetrisPage")
MakeAppPage("tictactoe"); MakeAppPage("music"); MakeAppPage("uber")
MakeAppPage("candy"); MakeAppPage("notes"); MakeAppPage("2048")
MakeAppPage("mines"); MakeAppPage("flappy"); MakeAppPage("wordle")
MakeAppPage("weather"); MakeAppPage("calc"); MakeAppPage("angrybirds")
MakeAppPage("shooter"); MakeAppPage("templerun"); MakeAppPage("subway")
MakeAppPage("timer"); MakeAppPage("calendar"); MakeAppPage("dpsmeter")
MakeAppPage("camera"); MakeAppPage("gallery"); MakeAppPage("battleship")
MakeAppPage("toys"); MakeAppPage("social"); MakeAppPage("agario")
MakeAppPage("settings"); MakeAppPage("phone"); MakeAppPage("roguelike")
MakeAppPage("towerdefense")

-- Map page names to app objects for OnShow/OnHide
pg.appMap = {
    fitness = WowSoFitApp, snake = PhoneSnakeGame, tetris = PhoneTetrisGame,
    tictactoe = PhoneTicTacToeGame, music = PhoneMusicApp, uber = PhoneUberApp,
    candy = PhoneCandyCrushGame, notes = PhoneNotesApp, ["2048"] = Phone2048Game,
    mines = PhoneMinesweeperGame, flappy = PhoneFlappyBirdGame, wordle = PhoneWordleGame,
    weather = PhoneWeatherApp, calc = PhoneCalculatorApp, angrybirds = PhoneAngryBirdsGame,
    phone = PhoneCallApp, shooter = PhoneSpaceShooterGame, templerun = PhoneTempleRunGame,
    subway = PhoneSubwaySurfersGame, battleship = PhoneBattleshipGame, toys = PhoneToysApp,
    social = PhoneSocialApp, agario = PhoneAgarioGame, timer = PhoneTimerApp,
    calendar = PhoneCalendarApp, dpsmeter = PhoneDamageMeterApp, camera = PhoneCameraApp,
    gallery = PhoneGalleryApp, settings = PhoneSettingsApp,
    roguelike = PhoneRoguelikeGame,
    towerdefense = PhoneTowerDefenseGame,
}

-- Multi-page home screen state
local home = {
    frames = {},       -- page frame containers (1, 2, ...)
    dots = {},         -- page indicator dot textures
    dotFrame = nil,    -- frame holding dots
    buttons = {},      -- all app icon buttons
    currentIdx = 1,    -- which home page is showing
    editMode = false,
    selectedSlot = nil,
    totalPages = 1,
    ROWS_PAGE1 = 4,    -- rows on page with widget
    ROWS_OTHER = 5,    -- rows on pages without widget
    ROW_HEIGHT = 50,
    DOT_SIZE = 6,
    DOT_GAP = 6,
    widgetPage = 1,    -- which page has the widget
}

function home:SlotsForPage(pageIdx)
    return (pageIdx == self.widgetPage and self.ROWS_PAGE1 or self.ROWS_OTHER) * COLS
end

function home:AppYOffset(pageIdx)
    return pageIdx == self.widgetPage and (WIDGET_HEIGHT + 12) or 4
end

local homeBtn -- forward declaration
local homeBtnBar -- forward declaration

local function ShowPage(page)
    currentPage = page
    screenBg:SetShown(page == "home")
    homePage:SetShown(page == "home")
    for name, frame in pairs(pg) do
        if name ~= "appMap" then
            frame:SetShown(name == page)
        end
    end
    for name, app in pairs(pg.appMap) do
        if name == page then app:OnShow() else app:OnHide() end
    end
end

---------------------------------------------------------------------------
-- Home button (bottom bezel, always visible on app pages)
---------------------------------------------------------------------------
homeBtn = CreateFrame("Button", nil, screen)
homeBtn:SetSize(24, 24)
homeBtn:SetPoint("BOTTOM", 0, 4)
homeBtn:SetFrameLevel(screen:GetFrameLevel() + 15)

local homeBtnBg = homeBtn:CreateTexture(nil, "ARTWORK")
homeBtnBg:SetSize(20, 20)
homeBtnBg:SetPoint("CENTER")
homeBtnBg:SetTexture("Interface\\Buttons\\WHITE8x8")
homeBtnBg:SetVertexColor(0.35, 0.35, 0.4, 0.7)

local homeBtnIcon = homeBtn:CreateTexture(nil, "ARTWORK", nil, 1)
homeBtnIcon:SetSize(14, 14)
homeBtnIcon:SetPoint("CENTER")
pcall(function() homeBtnIcon:SetAtlas("Garr_Building_MageTowerComplete") end)

local homeBtnHl = homeBtn:CreateTexture(nil, "HIGHLIGHT")
homeBtnHl:SetSize(20, 20)
homeBtnHl:SetPoint("CENTER")
homeBtnHl:SetTexture("Interface\\Buttons\\WHITE8x8")
homeBtnHl:SetVertexColor(0.5, 0.5, 0.6, 0.3)

-- Phone state: "lock" → "pin" → "unlocked"
local ToggleLock -- forward declaration
local notifBanner, notifConvoId, notifTimer -- forward declarations
local phoneState = "lock"  -- "lock", "pin", "unlocked"

-- Lock screen (wallpaper + time, tap to unlock or show PIN)
local lockScreen = CreateFrame("Frame", nil, screen)
lockScreen:SetPoint("TOPLEFT", -4, 4)
lockScreen:SetPoint("BOTTOMRIGHT", 4, -4)
lockScreen:SetFrameLevel(screen:GetFrameLevel() + 20)
lockScreen:EnableMouse(true)

-- Solid black fallback behind the lock gallery image
local lockBgFallback = lockScreen:CreateTexture(nil, "BACKGROUND", nil, 0)
lockBgFallback:SetAllPoints()
lockBgFallback:SetTexture("Interface\\Buttons\\WHITE8x8")
lockBgFallback:SetVertexColor(0.05, 0.05, 0.08, 1)

-- Lock screen gallery image
local lockBg = lockScreen:CreateTexture(nil, "BACKGROUND", nil, 1)
lockBg:SetAllPoints()
lockBg:SetVertexColor(0.5, 0.5, 0.5, 1)
PhoneGalleryApp._lockBg = lockBg

-- Dark overlay so lock screen text remains readable
local lockOverlay = lockScreen:CreateTexture(nil, "BACKGROUND", nil, 2)
lockOverlay:SetAllPoints()
lockOverlay:SetTexture("Interface\\Buttons\\WHITE8x8")
lockOverlay:SetVertexColor(0, 0, 0, 0.4)

local lockTime = lockScreen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
lockTime:SetPoint("CENTER", 0, 20)
lockTime:SetTextColor(0.9, 0.9, 0.95, 1)
local ltFont = lockTime:GetFont()
if ltFont then lockTime:SetFont(ltFont, 28, "OUTLINE") end

local lockZone = lockScreen:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
lockZone:SetPoint("TOP", lockTime, "BOTTOM", 0, -6)
lockZone:SetTextColor(0.5, 0.5, 0.55, 1)
local lzFont = lockZone:GetFont()
if lzFont then lockZone:SetFont(lzFont, 10, "") end

local lockDate = lockScreen:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
lockDate:SetPoint("BOTTOM", lockTime, "TOP", 0, 4)
lockDate:SetTextColor(0.5, 0.5, 0.55, 1)
local ldFont = lockDate:GetFont()
if ldFont then lockDate:SetFont(ldFont, 9, "") end

local phoneLocked = true  -- kept for backward compat with other code that checks this

---------------------------------------------------------------------------
-- PIN pad for lock screen (consolidated into pin table to save locals)
---------------------------------------------------------------------------
local pin = {
    entry = "",
    DOT_COUNT = 4,
    BTN_SIZE = 32,
    BTN_GAP = 4,
}

pin.frame = CreateFrame("Frame", nil, lockScreen)
pin.frame:SetPoint("TOPLEFT")
pin.frame:SetPoint("BOTTOMRIGHT")
pin.frame:SetFrameLevel(lockScreen:GetFrameLevel() + 2)
pin.frame:EnableMouse(true)
pin.frame:Hide()

pin.dots = lockScreen:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
pin.dots:SetPoint("CENTER", lockScreen, "CENTER", 0, 50)
pin.dots:SetTextColor(0.9, 0.9, 0.95, 1)
do local f = pin.dots:GetFont(); if f then pin.dots:SetFont(f, 20, "OUTLINE") end end

pin.status = lockScreen:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
pin.status:SetPoint("BOTTOM", pin.dots, "TOP", 0, 4)
pin.status:SetTextColor(0.6, 0.6, 0.65, 1)

pin.error = lockScreen:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
pin.error:SetPoint("TOP", pin.dots, "BOTTOM", 0, -4)
pin.error:SetTextColor(0.9, 0.3, 0.3, 1)

local function HasPin()
    return HearthPhoneDB and HearthPhoneDB.pin and HearthPhoneDB.pin ~= ""
end

local function UpdatePinDots()
    local dots = ""
    for i = 1, pin.DOT_COUNT do
        dots = dots .. (i <= #pin.entry and "|cffffffffo|r " or "|cff555555o|r ")
    end
    pin.dots:SetText(dots)
end

local ResetPinTimeout  -- forward declaration, defined after SetPhoneState
local pendingNotifRoute = nil  -- convoId to navigate to after PIN unlock
local OnPendingRoute = nil     -- callback set by InitNotifClick to handle routing

local function OnPinDigit(digit)
    if #pin.entry >= pin.DOT_COUNT then return end
    pin.entry = pin.entry .. digit
    pin.error:SetText("")
    ResetPinTimeout()
    UpdatePinDots()
    if #pin.entry == pin.DOT_COUNT then
        C_Timer.After(0.15, function()
            if pin.entry == HearthPhoneDB.pin then
                pin.entry = ""
                ToggleLock()
                if pendingNotifRoute and OnPendingRoute then
                    local id = pendingNotifRoute
                    pendingNotifRoute = nil
                    OnPendingRoute(id)
                end
            else
                pin.entry = ""
                UpdatePinDots()
                pin.error:SetText("Wrong PIN")
            end
        end)
    end
end

local function OnPinBackspace()
    if #pin.entry > 0 then
        pin.entry = pin.entry:sub(1, -2)
        pin.error:SetText("")
        ResetPinTimeout()
        UpdatePinDots()
    end
end

do
    local padKeys = { "1","2","3","4","5","6","7","8","9","","0","<" }
    for i, key in ipairs(padKeys) do
        if key ~= "" then
            local row = math.floor((i - 1) / 3)
            local col = (i - 1) % 3
            local x = (col - 1) * (pin.BTN_SIZE + pin.BTN_GAP)
            local y = -10 - row * (pin.BTN_SIZE + pin.BTN_GAP)
            local btn = CreateFrame("Button", nil, pin.frame)
            btn:SetPoint("TOP", pin.dots, "BOTTOM", x, y - 10)
            btn:SetSize(pin.BTN_SIZE, pin.BTN_SIZE)
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(0.2, 0.22, 0.3, 0.8)
            local txt = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            txt:SetPoint("CENTER")
            txt:SetText(key)
            txt:SetTextColor(0.9, 0.9, 0.95, 1)
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Buttons\\WHITE8x8")
            hl:SetVertexColor(0.4, 0.45, 0.55, 0.3)
            if key == "<" then
                btn:SetScript("OnClick", OnPinBackspace)
            else
                local digit = key
                btn:SetScript("OnClick", function() OnPinDigit(digit) end)
            end
        end
    end
end

local function ShowPinPad()
    pin.entry = ""
    pin.error:SetText("")
    pin.status:SetText("Enter PIN")
    UpdatePinDots()
    pin.frame:Show()
    pin.dots:Show()
    pin.status:Show()
    pin.error:Show()
end

local function HidePinPad()
    pinPadActive = false
    pin.frame:Hide()
    pin.dots:Hide()
    pin.status:Hide()
    pin.error:Hide()
end

local pinTimeout = nil

local function SetPhoneState(state)
    phoneState = state
    phoneLocked = (state ~= "unlocked")
    lockScreen:SetShown(state == "lock" or state == "pin")
    -- Cancel any existing PIN timeout
    if pinTimeout then pinTimeout:Cancel(); pinTimeout = nil end
    if state == "lock" then
        HidePinPad()
        pendingNotifRoute = nil
        lockTime:SetPoint("CENTER", 0, 20)
        lockZone:SetShown(true)
        lockDate:SetShown(true)
    elseif state == "pin" then
        ShowPinPad()
        lockTime:SetPoint("CENTER", 0, 110)
        lockZone:SetShown(false)
        lockDate:SetShown(false)
        -- Auto-return to lock screen after 10 seconds of inactivity
        pinTimeout = C_Timer.NewTimer(10, function()
            if phoneState == "pin" then
                SetPhoneState("lock")
            end
        end)
    elseif state == "unlocked" then
        HidePinPad()
        notifBanner:Hide()
        notifConvoId = nil
        if notifTimer then notifTimer:Cancel(); notifTimer = nil end
        HearthPhone_ResetActivity()
    end
end

local function UpdateLockScreen()
    lockTime:SetText(HearthPhone_GetTime())
    lockZone:SetText(GetMinimapZoneText() or "")
    lockDate:SetText(date("%A"))
end

ResetPinTimeout = function()
    if pinTimeout then pinTimeout:Cancel() end
    pinTimeout = C_Timer.NewTimer(10, function()
        if phoneState == "pin" then
            SetPhoneState("lock")
        end
    end)
end

-- Tap lock screen → unlock (no PIN) or show PIN pad (has PIN)
lockScreen:SetScript("OnMouseDown", function()
    if phoneState == "pin" then
        return  -- let PIN buttons handle it
    end
    if HasPin() then
        SetPhoneState("pin")
    else
        SetPhoneState("unlocked")
    end
end)

-- ToggleLock: called by home button and PIN success
ToggleLock = function()
    if phoneState == "unlocked" then
        SetPhoneState("lock")
        UpdateLockScreen()
        ShowPage("home")
    else
        SetPhoneState("unlocked")
    end
end

-- Home button bar background (above screen content so it doesn't blend with gallery image)
homeBtnBar = CreateFrame("Frame", nil, screen)
homeBtnBar:SetFrameLevel(screen:GetFrameLevel() + 14)
homeBtnBar:SetPoint("BOTTOMLEFT", -4, -4)
homeBtnBar:SetPoint("BOTTOMRIGHT", 4, -4)
homeBtnBar:SetHeight(36)
-- Background on phone so it renders BELOW the bezel overlay but above the gallery image
local homeBtnBarBg = phone:CreateTexture(nil, "ARTWORK", nil, 1)
homeBtnBarBg:SetPoint("TOPLEFT", homeBtnBar, "TOPLEFT")
homeBtnBarBg:SetPoint("BOTTOMRIGHT", homeBtnBar, "BOTTOMRIGHT")
homeBtnBarBg:SetTexture("Interface\\Buttons\\WHITE8x8")
homeBtnBarBg:SetVertexColor(0.06, 0.06, 0.08, 0.7)

homeBtn:SetScript("OnClick", function()
    if home.editMode then
        home:ExitEditMode()
        return
    end
    if currentPage == "home" then
        ToggleLock()
    else
        ShowPage("home")
    end
end)

---------------------------------------------------------------------------
-- Notification banner (whisper alerts, sits above everything)
---------------------------------------------------------------------------
notifBanner = CreateFrame("Button", nil, phone)
notifBanner:SetPoint("TOPLEFT", screen, "TOPLEFT", 4, -22)
notifBanner:SetPoint("RIGHT", screen, "RIGHT", -4, 0)
notifBanner:SetHeight(38)
notifBanner:SetFrameStrata("DIALOG")
notifBanner:SetFrameLevel(50)
notifBanner:Hide()
notifBanner:EnableMouse(true)

local notifBg = notifBanner:CreateTexture(nil, "BACKGROUND")
notifBg:SetAllPoints()
notifBg:SetTexture("Interface\\Buttons\\WHITE8x8")
notifBg:SetVertexColor(0.12, 0.15, 0.22, 0.97)

-- Border edges
local notifBorderTop = notifBanner:CreateTexture(nil, "ARTWORK")
notifBorderTop:SetPoint("TOPLEFT", 0, 1)
notifBorderTop:SetPoint("TOPRIGHT", 0, 1)
notifBorderTop:SetHeight(1)
notifBorderTop:SetTexture("Interface\\Buttons\\WHITE8x8")
notifBorderTop:SetVertexColor(0.3, 0.5, 0.8, 0.7)

local notifBorderBot = notifBanner:CreateTexture(nil, "ARTWORK")
notifBorderBot:SetPoint("BOTTOMLEFT", 0, -1)
notifBorderBot:SetPoint("BOTTOMRIGHT", 0, -1)
notifBorderBot:SetHeight(1)
notifBorderBot:SetTexture("Interface\\Buttons\\WHITE8x8")
notifBorderBot:SetVertexColor(0.3, 0.5, 0.8, 0.7)

local notifSender = notifBanner:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
notifSender:SetPoint("TOPLEFT", 8, -4)
notifSender:SetPoint("RIGHT", -8, 0)
notifSender:SetJustifyH("LEFT")
local nsFont = notifSender:GetFont()
if nsFont then notifSender:SetFont(nsFont, 9, "OUTLINE") end

local notifMsg = notifBanner:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
notifMsg:SetPoint("TOPLEFT", 8, -16)
notifMsg:SetPoint("RIGHT", -8, 0)
notifMsg:SetJustifyH("LEFT")
notifMsg:SetTextColor(0.7, 0.7, 0.75, 1)
local nmFont = notifMsg:GetFont()
if nmFont then notifMsg:SetFont(nmFont, 8, "") end

local notifHl = notifBanner:CreateTexture(nil, "HIGHLIGHT")
notifHl:SetAllPoints()
notifHl:SetTexture("Interface\\Buttons\\WHITE8x8")
notifHl:SetVertexColor(0.3, 0.4, 0.5, 0.2)

notifConvoId = nil
notifTimer = nil

local function HideNotification()
    notifBanner:Hide()
    notifConvoId = nil
    if notifTimer then
        notifTimer:Cancel()
        notifTimer = nil
    end
end

-- Vibrate effect: quick shake of the phone frame (uses its own hidden frame)
local vibrateFrame = CreateFrame("Frame")
local vibrateShakes = 0
local vibrateElapsed = 0
local vibrateOrigX, vibrateOrigY, vibratePoint, vibrateRelPoint

local function StopVibrate()
    vibrateShakes = 0
    vibrateFrame:SetScript("OnUpdate", nil)
    if vibrateOrigX and vibrateOrigY then
        phone:ClearAllPoints()
        phone:SetPoint(vibratePoint or "CENTER", UIParent, vibrateRelPoint or "CENTER", vibrateOrigX, vibrateOrigY)
    end
end

local function StartVibrate()
    if vibrateShakes > 0 then return end
    local pt, _, relPt, x, y = phone:GetPoint()
    vibratePoint = pt
    vibrateRelPoint = relPt
    vibrateOrigX = x
    vibrateOrigY = y
    vibrateShakes = 6
    vibrateElapsed = 0
    vibrateFrame:SetScript("OnUpdate", function(self, dt)
        vibrateElapsed = vibrateElapsed + dt
        if vibrateElapsed >= 0.03 then
            vibrateElapsed = 0
            vibrateShakes = vibrateShakes - 1
            if vibrateShakes <= 0 then
                StopVibrate()
                return
            end
            local offsetX = (vibrateShakes % 2 == 0) and 2 or -2
            phone:ClearAllPoints()
            phone:SetPoint(vibratePoint, UIParent, vibrateRelPoint, vibrateOrigX + offsetX, vibrateOrigY)
        end
    end)
end

-- Global vibrate function so any app can call it
function HearthPhone_Vibrate()
    StartVibrate()
end

-- Exposed globally so other modules (e.g. PhoneSocial) can trigger notifications
-- Map convoId prefix to WoW ChatTypeInfo key
local NOTIF_CHAT_TYPES = {
    dm       = "WHISPER",
    guild    = "GUILD",
    party    = "PARTY",
    raid     = "RAID",
    instance = "INSTANCE_CHAT",
}
local NOTIF_SPECIAL_COLORS = {
    social = { 0.25, 0.80, 0.65 },  -- teal
    game   = { 0.95, 0.70, 0.20 },  -- gold/amber
}

local function GetNotifColor(convoId)
    if not convoId then
        local info = ChatTypeInfo["WHISPER"]
        return { info.r, info.g, info.b }
    end
    local prefix = convoId:match("^(%a+)")
    if NOTIF_SPECIAL_COLORS[prefix] then return NOTIF_SPECIAL_COLORS[prefix] end
    local chatType = NOTIF_CHAT_TYPES[prefix]
    if chatType then
        local info = ChatTypeInfo[chatType]
        if info then return { info.r, info.g, info.b } end
    end
    local info = ChatTypeInfo["WHISPER"]
    return { info.r, info.g, info.b }
end

local function ShowNotification(senderName, message, convoId)
    -- Don't show if we're already looking at this conversation
    if currentPage == "gchat" and activeConvo == convoId then return end
    -- Don't show social mentions if already viewing that post
    if currentPage == "social" and convoId and convoId:match("^social:") then return end
    -- Don't show if phone is hidden
    if not phone:IsVisible() then return end

    -- Check notification settings
    local showBanner = not (HearthPhoneDB and HearthPhoneDB.muteBanners)
    local doVibrate = not (HearthPhoneDB and HearthPhoneDB.muteVibration)

    if not showBanner and not doVibrate then return end

    notifConvoId = convoId

    if showBanner then
        local clr = GetNotifColor(convoId)
        notifBg:SetVertexColor(clr[1] * 0.15, clr[2] * 0.15, clr[3] * 0.15, 0.97)
        notifBorderTop:SetVertexColor(clr[1], clr[2], clr[3], 0.7)
        notifBorderBot:SetVertexColor(clr[1], clr[2], clr[3], 0.7)
        notifSender:SetText("|cff" .. string.format("%02x%02x%02x", clr[1] * 255, clr[2] * 255, clr[3] * 255) .. senderName .. "|r")
        local preview = message
        if #preview > 35 then preview = preview:sub(1, 33) .. ".." end
        notifMsg:SetText(preview)
        notifBanner:Show()
    end

    -- Vibrate the phone
    if doVibrate then
        StartVibrate()
    end

    -- Auto-hide: stay permanently when locked, 8 seconds when unlocked
    if showBanner then
        if notifTimer then notifTimer:Cancel() end
        if not phoneLocked then
            notifTimer = C_Timer.NewTimer(8, function()
                HideNotification()
            end)
        end
    end
end

-- Global reference so other modules can trigger notifications
HearthPhoneNotify = ShowNotification

-- Notification click handler — set up later via InitNotifClick() after conversations system exists
local function InitNotifClick(conversations, GetConvo, OpenConvo)
    local function RouteToNotif(id)
        -- Game challenge notification
        local gamePage = id:match("^game:(.+)$")
        if gamePage then
            ShowPage(gamePage)
            return
        end
        -- Social mention notification
        local socialPostId = id:match("^social:(.+)$")
        if socialPostId then
            ShowPage("social")
            if PhoneSocialApp.OpenPostById then
                PhoneSocialApp:OpenPostById(tonumber(socialPostId) or 0)
            end
            return
        end
        if not conversations[id] then
            local name = id:match("^dm:(.+)$")
            if name then
                GetConvo(id, name, "WHISPER")
            elseif id == "guild" then
                GetConvo(id, "Guild Chat", "GUILD")
            elseif id == "party" then
                GetConvo(id, "Party Chat", "PARTY")
            elseif id == "raid" then
                GetConvo(id, "Raid Chat", "RAID")
            elseif id == "instance" then
                GetConvo(id, "Instance Chat", "INSTANCE_CHAT")
            else
                GetConvo(id, id, "GUILD")
            end
        end
        ShowPage("gchat")
        pcall(OpenConvo, id)
    end

    -- Set the callback for pending routes after PIN unlock
    OnPendingRoute = RouteToNotif

    notifBanner:SetScript("OnClick", function()
        local id = notifConvoId
        HideNotification()
        if id then
            if phoneLocked then
                if HasPin() then
                    pendingNotifRoute = id
                    SetPhoneState("pin")
                    return
                end
                SetPhoneState("unlocked")
            end
            RouteToNotif(id)
        end
    end)
end

---------------------------------------------------------------------------
-- Home screen widget (clock + location, top row)
---------------------------------------------------------------------------
local widget = CreateFrame("Frame", nil, homePage)
widget:SetPoint("TOPLEFT", 4, -2)
widget:SetPoint("TOPRIGHT", -4, -2)
widget:SetHeight(WIDGET_HEIGHT)

local widgetTime = widget:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
widgetTime:SetPoint("TOP", 0, -3)
widgetTime:SetTextColor(1, 1, 1, 1)
do local f = widgetTime:GetFont(); if f then widgetTime:SetFont(f, 18, "OUTLINE") end end
widgetTime:SetShadowColor(0, 0, 0, 0.8)
widgetTime:SetShadowOffset(1, -1)

local widgetZone = widget:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
widgetZone:SetPoint("TOP", widgetTime, "BOTTOM", 0, -1)
widgetZone:SetTextColor(0.9, 0.9, 0.95, 1)
do local f = widgetZone:GetFont(); if f then widgetZone:SetFont(f, 9, "OUTLINE") end end
widgetZone:SetShadowColor(0, 0, 0, 0.8)
widgetZone:SetShadowOffset(1, -1)

local widgetDate = widget:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
widgetDate:SetPoint("TOP", widgetZone, "BOTTOM", 0, -1)
widgetDate:SetTextColor(0.95, 0.95, 1, 1)
do local f = widgetDate:GetFont(); if f then widgetDate:SetFont(f, 8, "OUTLINE") end end
widgetDate:SetShadowColor(0, 0, 0, 0.8)
widgetDate:SetShadowOffset(1, -1)

home.DAY_NAMES = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}
home.MONTH_NAMES = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}

local function UpdateWidget()
    widgetTime:SetText(HearthPhone_GetTime())
    widgetZone:SetText(GetMinimapZoneText() or "")
    local d = date("*t")
    widgetDate:SetText(format("%s, %s %d", home.DAY_NAMES[d.wday], home.MONTH_NAMES[d.month], d.day))
end

---------------------------------------------------------------------------
-- Multi-page home system: app grid, dots, swiping, edit mode
---------------------------------------------------------------------------

-- Build an app lookup table keyed by page name
home.appByPage = {}
for _, app in ipairs(apps) do
    if app.page then home.appByPage[app.page] = app end
end

-- Default layout: fill pages in app table order
local function BuildDefaultLayout()
    local layout = {}
    local pageIdx = 1
    local slot = 1
    layout[pageIdx] = {}
    for _, app in ipairs(apps) do
        local maxSlots = home:SlotsForPage(pageIdx)
        if slot > maxSlots then
            pageIdx = pageIdx + 1
            slot = 1
            layout[pageIdx] = {}
        end
        layout[pageIdx][slot] = app.page
        slot = slot + 1
    end
    return layout
end

-- Create a single app icon button (unpositioned, reusable)
local function CreateAppButton(parentFrame, appData)
    local btn = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    btn:SetBackdropColor(0.18, 0.18, 0.22, 0.9)
    btn:SetBackdropBorderColor(0.18, 0.18, 0.22, 0.9)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE - 10, ICON_SIZE - 10)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if appData.texture then
        icon:SetTexture(appData.texture)
    elseif appData.icon then
        pcall(function() icon:SetAtlas(appData.icon) end)
    end

    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOP", btn, "BOTTOM", 0, -1)
    label:SetText(appData.label)
    label:SetTextColor(0.75, 0.75, 0.8, 1)
    do local f = label:GetFont(); if f then label:SetFont(f, 8, "OUTLINE") end end

    -- Edit mode highlight overlays
    local editGlow = btn:CreateTexture(nil, "OVERLAY")
    editGlow:SetPoint("TOPLEFT", -2, 2)
    editGlow:SetPoint("BOTTOMRIGHT", 2, -2)
    editGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    editGlow:SetVertexColor(1, 1, 1, 0.12)
    editGlow:Hide()
    btn.editGlow = editGlow

    local selTex = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    selTex:SetAllPoints()
    selTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    selTex:SetVertexColor(0.3, 0.6, 1.0, 0.5)
    selTex:Hide()
    btn.selTex = selTex
    btn.appData = appData
    btn.appLabel = label

    -- Wiggle animation state (randomize per button so they don't all sync)
    btn.wiggleOffset = math.random() * 6.28
    btn.wiggleAnchor = nil  -- set when entering edit mode

    btn:SetScript("OnEnter", function(self)
        if not home.editMode then
            self:SetBackdropColor(0.28, 0.28, 0.35, 0.9)
            self:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.8)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(appData.label)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if not home.editMode then
            self:SetBackdropColor(0.18, 0.18, 0.22, 0.9)
            self:SetBackdropBorderColor(0.25, 0.25, 0.30, 0.6)
        end
        GameTooltip_Hide()
    end)

    -- Forward mouse wheel to home page switching
    btn:EnableMouseWheel(true)
    btn:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            home:SetPage(home.currentIdx - 1)
        else
            home:SetPage(home.currentIdx + 1)
        end
    end)
    -- Track drag on app buttons for page swiping
    btn:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            home.dragStartX = GetCursorPosition()
            home.dragSwiped = false
        end
    end)
    btn:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and home.dragStartX then
            local dx = GetCursorPosition() - home.dragStartX
            local threshold = 30 * (phone:GetEffectiveScale() or 1)
            if dx > threshold then
                home:SetPage(home.currentIdx - 1)
                home.dragSwiped = true
            elseif dx < -threshold then
                home:SetPage(home.currentIdx + 1)
                home.dragSwiped = true
            end
            home.dragStartX = nil
        end
    end)
    btn:SetScript("OnClick", function()
        if home.dragSwiped then home.dragSwiped = false; return end
        if home.editMode then
            home:OnEditClick(appData.page)
            return
        end
        if appData.page then
            ShowPage(appData.page)
            return
        end
        if InCombatLockdown() then
            print("|cffff4444[Phone]|r Can't open panels in combat.")
            return
        end
        if appData.action then appData.action() end
    end)

    return btn
end

-- Position a button in the grid
local function PositionAppButton(btn, pageFrame, slotIdx, pageIdx)
    local row = floor((slotIdx - 1) / COLS)
    local col = (slotIdx - 1) % COLS
    local parentWidth = PHONE_WIDTH - BEZEL_INSET_LEFT - BEZEL_INSET_RIGHT - 4
    local totalIconWidth = COLS * ICON_SIZE + (COLS - 1) * ICON_PADDING
    local offsetX = (parentWidth - totalIconWidth) / 2
    local yOff = home:AppYOffset(pageIdx)
    local xPos = offsetX + col * (ICON_SIZE + ICON_PADDING)
    local yPos = -(yOff + row * home.ROW_HEIGHT)
    btn:ClearAllPoints()
    btn:SetParent(pageFrame)
    btn:SetPoint("TOPLEFT", xPos, yPos)
    btn:Show()
end

-- Switch home page
function home:SetPage(idx)
    idx = max(1, min(idx, self.totalPages))
    self.currentIdx = idx
    for i, frame in ipairs(self.frames) do
        frame:SetShown(i == idx)
    end
    -- Re-parent widget to the page that has it
    widget:SetParent(self.frames[self.widgetPage] or self.frames[1])
    widget:SetShown(idx == self.widgetPage)
    self:UpdateDots()
end

-- Update dot indicators
function home:UpdateDots()
    for i, dot in ipairs(self.dots) do
        if i == self.currentIdx then
            dot:SetVertexColor(1, 1, 1, 0.9)
        else
            dot:SetVertexColor(0.4, 0.4, 0.45, 0.6)
        end
    end
end

-- Build/rebuild the entire home grid from layout
function home:RefreshGrid()
    local layout = HearthPhoneDB.appLayout
    if not layout or #layout == 0 then
        layout = BuildDefaultLayout()
        HearthPhoneDB.appLayout = layout
    end

    -- Determine total pages (in edit mode, add one extra if last page has apps)
    local numPages = #layout
    if self.editMode then
        local lastPage = layout[numPages]
        if lastPage and #lastPage > 0 then
            numPages = numPages + 1
            layout[numPages] = layout[numPages] or {}
        end
    end
    self.totalPages = max(1, numPages)

    -- Create page frames as needed
    for i = 1, self.totalPages do
        if not self.frames[i] then
            local f = CreateFrame("Frame", nil, homePage)
            f:SetAllPoints()
            f:Hide()
            -- Empty slot click handler for edit mode
            f:EnableMouse(false)
            self.frames[i] = f
        end
    end
    -- Hide excess page frames
    for i = self.totalPages + 1, #self.frames do
        self.frames[i]:Hide()
    end

    -- Hide all existing buttons
    for _, btn in pairs(self.buttons) do
        btn:Hide()
    end

    -- Place buttons according to layout
    for pageIdx = 1, self.totalPages do
        local pageSlots = layout[pageIdx] or {}
        local maxSlots = self:SlotsForPage(pageIdx)
        for slotIdx = 1, maxSlots do
            local appKey = pageSlots[slotIdx]
            if appKey then
                local appData = self.appByPage[appKey]
                if appData then
                    local btn = self.buttons[appKey]
                    if not btn then
                        btn = CreateAppButton(self.frames[pageIdx], appData)
                        self.buttons[appKey] = btn
                    end
                    PositionAppButton(btn, self.frames[pageIdx], slotIdx, pageIdx)
                    btn.selTex:SetShown(self.editMode and self.selectedSlot and self.selectedSlot.appKey == appKey)
                end
            end
        end
    end

    -- Create/update dots
    if not self.dotFrame then
        self.dotFrame = CreateFrame("Frame", nil, homePage)
        self.dotFrame:SetHeight(self.DOT_SIZE + 4)
        self.dotFrame:SetPoint("BOTTOMLEFT", 0, 2)
        self.dotFrame:SetPoint("BOTTOMRIGHT", 0, 2)
    end
    -- Clear old dots
    for _, dot in ipairs(self.dots) do
        dot:Hide()
    end
    self.dots = {}
    local totalDotsWidth = self.totalPages * self.DOT_SIZE + (self.totalPages - 1) * self.DOT_GAP
    local dotStartX = (self.dotFrame:GetWidth() or 170) / 2 - totalDotsWidth / 2
    for i = 1, self.totalPages do
        local dot = self.dotFrame:CreateTexture(nil, "ARTWORK")
        dot:SetSize(self.DOT_SIZE, self.DOT_SIZE)
        dot:SetPoint("LEFT", self.dotFrame, "LEFT", dotStartX + (i - 1) * (self.DOT_SIZE + self.DOT_GAP), 0)
        dot:SetTexture("Interface\\Buttons\\WHITE8x8")
        self.dots[i] = dot
    end

    self:SetPage(min(self.currentIdx, self.totalPages))
end

-- Edit mode: click on an app to select, click another to swap
function home:OnEditClick(appKey)
    if not self.selectedSlot then
        -- Select this app
        self.selectedSlot = { appKey = appKey }
        if self.buttons[appKey] then
            self.buttons[appKey].selTex:Show()
        end
        return
    end

    -- Clicking same app again = deselect
    if self.selectedSlot.appKey == appKey then
        if self.buttons[appKey] then
            self.buttons[appKey].selTex:Hide()
        end
        self.selectedSlot = nil
        return
    end

    -- Swap the two apps in layout
    local layout = HearthPhoneDB.appLayout
    local fromPage, fromSlot, toPage, toSlot
    for pi, pageSlots in ipairs(layout) do
        for si, key in pairs(pageSlots) do
            if key == self.selectedSlot.appKey then fromPage, fromSlot = pi, si end
            if key == appKey then toPage, toSlot = pi, si end
        end
    end
    if fromPage and toPage then
        layout[fromPage][fromSlot], layout[toPage][toSlot] = layout[toPage][toSlot], layout[fromPage][fromSlot]
    end
    self.selectedSlot = nil
    self:RefreshGrid()
    self:ShowEmptySlots()
    self:RecordWiggleAnchors()
end

-- Click empty slot in edit mode to move selected app there
function home:OnEmptySlotClick(pageIdx, slotIdx)
    if not self.selectedSlot then return end
    local layout = HearthPhoneDB.appLayout
    -- Find and remove the selected app from its old position
    for pi, pageSlots in ipairs(layout) do
        for si, key in pairs(pageSlots) do
            if key == self.selectedSlot.appKey then
                pageSlots[si] = nil
            end
        end
    end
    -- Place it in the new slot
    layout[pageIdx] = layout[pageIdx] or {}
    layout[pageIdx][slotIdx] = self.selectedSlot.appKey
    self.selectedSlot = nil
    self:RefreshGrid()
    self:ShowEmptySlots()
    self:RecordWiggleAnchors()
end

-- Create/show empty slot buttons for edit mode
function home:ShowEmptySlots()
    if not self.editMode then return end
    local layout = HearthPhoneDB.appLayout
    for pageIdx = 1, self.totalPages do
        local pageSlots = layout[pageIdx] or {}
        local maxSlots = self:SlotsForPage(pageIdx)
        for slotIdx = 1, maxSlots do
            if not pageSlots[slotIdx] then
                local slotKey = pageIdx .. ":" .. slotIdx
                if not self.buttons[slotKey] then
                    local f = CreateFrame("Button", nil, self.frames[pageIdx])
                    f:SetSize(ICON_SIZE, ICON_SIZE)
                    local bg = f:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
                    bg:SetVertexColor(0.2, 0.2, 0.25, 0.4)
                    local hl = f:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetTexture("Interface\\Buttons\\WHITE8x8")
                    hl:SetVertexColor(1, 1, 1, 0.15)
                    self.buttons[slotKey] = f
                    f.isEmptySlot = true
                end
                local f = self.buttons[slotKey]
                f.emptyPageIdx = pageIdx
                f.emptySlotIdx = slotIdx
                f:SetScript("OnClick", function()
                    self:OnEmptySlotClick(pageIdx, slotIdx)
                end)
                PositionAppButton(f, self.frames[pageIdx], slotIdx, pageIdx)
            end
        end
    end
end

-- Re-record wiggle anchors and show edit glows (call after RefreshGrid in edit mode)
function home:RecordWiggleAnchors()
    for key, btn in pairs(self.buttons) do
        if not btn.isEmptySlot and btn.editGlow then
            btn.editGlow:Show()
            local point, rel, relPoint, x, y = btn:GetPoint(1)
            btn.wiggleAnchor = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
        end
    end
end

function home:EnterEditMode()
    self.editMode = true
    self.selectedSlot = nil
    self:RefreshGrid()
    self:ShowEmptySlots()
    self:RecordWiggleAnchors()
    -- Start wiggle animation
    if not self.wiggleFrame then
        self.wiggleFrame = CreateFrame("Frame")
    end
    self.wiggleTime = 0
    self.wiggleFrame:SetScript("OnUpdate", function(_, dt)
        self.wiggleTime = (self.wiggleTime or 0) + dt
        local t = self.wiggleTime
        for key, btn in pairs(self.buttons) do
            if not btn.isEmptySlot and btn.wiggleAnchor then
                local a = btn.wiggleAnchor
                local phase = t * 30 + (btn.wiggleOffset or 0)
                local dx = math.sin(phase) * 0.35
                btn:ClearAllPoints()
                btn:SetPoint(a.point, a.rel, a.relPoint, a.x + dx, a.y)
            end
        end
    end)
end

function home:ExitEditMode()
    self.editMode = false
    self.selectedSlot = nil
    -- Stop wiggle animation
    if self.wiggleFrame then
        self.wiggleFrame:SetScript("OnUpdate", nil)
    end
    -- Reset buttons: hide glows, restore positions
    for key, btn in pairs(self.buttons) do
        if btn.isEmptySlot then
            btn:Hide()
        end
        if btn.editGlow then btn.editGlow:Hide() end
        if btn.selTex then btn.selTex:Hide() end
        if btn.wiggleAnchor then
            local a = btn.wiggleAnchor
            btn:ClearAllPoints()
            btn:SetPoint(a.point, a.rel, a.relPoint, a.x, a.y)
            btn.wiggleAnchor = nil
        end
    end
    -- Clean up trailing empty pages from layout
    local layout = HearthPhoneDB.appLayout
    for i = #layout, 2, -1 do
        local hasApp = false
        for _, v in pairs(layout[i]) do
            if v then hasApp = true; break end
        end
        if not hasApp then table.remove(layout, i) else break end
    end
    self:RefreshGrid()
end

-- Defer icon creation until all addons are loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()

    -- Load or build layout
    HearthPhoneDB = HearthPhoneDB or {}
    if not HearthPhoneDB.appLayout then
        HearthPhoneDB.appLayout = BuildDefaultLayout()
    end

    -- Validate layout: ensure all apps exist in layout, add missing ones
    local placed = {}
    for _, pageSlots in ipairs(HearthPhoneDB.appLayout) do
        for _, key in pairs(pageSlots) do
            if key then placed[key] = true end
        end
    end
    for _, app in ipairs(apps) do
        if app.page and not placed[app.page] then
            -- Find first available slot
            local added = false
            for pi, pageSlots in ipairs(HearthPhoneDB.appLayout) do
                local maxSlots = home:SlotsForPage(pi)
                for si = 1, maxSlots do
                    if not pageSlots[si] then
                        pageSlots[si] = app.page
                        added = true
                        break
                    end
                end
                if added then break end
            end
            if not added then
                local newPage = #HearthPhoneDB.appLayout + 1
                HearthPhoneDB.appLayout[newPage] = { app.page }
            end
        end
    end

    -- Build the grid
    home:RefreshGrid()

    -- Set up mouse wheel page switching on homePage
    homePage:EnableMouseWheel(true)
    homePage:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            home:SetPage(home.currentIdx - 1)
        else
            home:SetPage(home.currentIdx + 1)
        end
    end)

    -- Horizontal drag to switch pages
    homePage:EnableMouse(true)
    homePage:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            local x = GetCursorPosition()
            home.dragStartX = x
        end
    end)
    homePage:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and home.dragStartX then
            local x = GetCursorPosition()
            local dx = x - home.dragStartX
            local threshold = 30 * (phone:GetEffectiveScale() or 1)
            if dx > threshold then
                home:SetPage(home.currentIdx - 1)
            elseif dx < -threshold then
                home:SetPage(home.currentIdx + 1)
            end
            home.dragStartX = nil
        end
    end)

    -- Initialize built-in apps
    for name, app in pairs(pg.appMap) do
        if app and app.Init and pg[name] then
            local ok, err = pcall(app.Init, app, pg[name])
            if not ok then
                print("|cffff4444[HearthPhone]|r Init error (" .. name .. "): " .. tostring(err))
            end
        end
    end
    -- gchat has no entry in appMap, init separately if needed
    -- (gchat UI is built inline below, not via an app object)

    -- Expose ShowPage and home for settings app
    PhoneSettingsApp._showPage = ShowPage
    PhoneSettingsApp._home = home

    -- Give PhoneCallApp a way to force-show the phone on the call page
    PhoneCallApp.ForceShowCall = function()
        phone:Show()
        ShowPage("phone")
    end

    -- Give games a way to force-show their page (for incoming challenges)
    local function GameForceShow(gamePage, from, gameName)
        phone:Show()
        if not phoneLocked then
            ShowPage(gamePage)
        else
            local lbl = gameName or gamePage
            ShowNotification("Game Challenge", (from or "Someone") .. " wants to play " .. lbl, "game:" .. gamePage)
        end
    end

    PhoneTicTacToeGame.ForceShow = function(from, gameName)
        GameForceShow("tictactoe", from, gameName)
    end
    PhoneBattleshipGame.ForceShow = function(from, gameName)
        GameForceShow("battleship", from, gameName)
    end
end)

-- Fitness page UI is built in WowSoFit.lua (WowSoFitApp)

---------------------------------------------------------------------------
-- Messages app (conversation list + individual chat views)
---------------------------------------------------------------------------

-- Conversation data storage (session only)
local conversations = {}  -- keyed by id: { id, name, chatType, messages={}, unread=0 }
local activeConvo = nil   -- currently open conversation id

-- Helper: get or create a conversation
local function GetConvo(id, name, chatType)
    if not conversations[id] then
        conversations[id] = { id = id, name = name, chatType = chatType, messages = {}, unread = 0 }
    end
    return conversations[id]
end

-- Initialize guild chat conversation
GetConvo("guild", "Guild Chat", "GUILD")

-- InitNotifClick called later, after OpenConvo is defined

-- Helper: get class color hex for a player name
local function GetClassColorHex(classFile)
    if classFile then
        local cc = RAID_CLASS_COLORS[classFile]
        if cc then return cc:GenerateHexColor():sub(3) end
    end
    return "33ff99"
end

---------------------------------------------------------------------------
-- Conversation list view (inside pg.gchat)
---------------------------------------------------------------------------
local convoListView = CreateFrame("Frame", nil, pg.gchat)
convoListView:SetAllPoints()

local msgTitle = convoListView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
msgTitle:SetPoint("TOP", 0, -2)
msgTitle:SetText("|cff40c0ffMessages|r")
local mtFont = msgTitle:GetFont()
if mtFont then msgTitle:SetFont(mtFont, 10, "OUTLINE") end

-- New Chat button (inline with title, right side)
local newChatBtn = CreateFrame("Button", nil, convoListView)
newChatBtn:SetSize(16, 14)
newChatBtn:SetPoint("LEFT", msgTitle, "RIGHT", 4, 0)
local ncLabel = newChatBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ncLabel:SetPoint("CENTER", 0, 0)
ncLabel:SetText("|cff40c0ff+|r")
local ncf = ncLabel:GetFont()
if ncf then ncLabel:SetFont(ncf, 12, "OUTLINE") end
local ncHl = newChatBtn:CreateTexture(nil, "HIGHLIGHT")
ncHl:SetAllPoints()
ncHl:SetTexture("Interface\\Buttons\\WHITE8x8")
ncHl:SetVertexColor(0.3, 0.4, 0.6, 0.2)

-- Scrollable area for conversation rows (no visible scrollbar)
local convoScroll = CreateFrame("ScrollFrame", nil, convoListView)
convoScroll:SetPoint("TOPLEFT", 2, -16)
convoScroll:SetPoint("BOTTOMRIGHT", -2, 4)

local convoContent = CreateFrame("Frame", nil, convoScroll)
convoContent:SetSize(1, 1)
convoScroll:SetScrollChild(convoContent)

convoScroll:EnableMouseWheel(true)
convoScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local maxScroll = max(0, convoContent:GetHeight() - self:GetHeight())
    local newScroll = min(maxScroll, max(0, cur - delta * 28))
    self:SetVerticalScroll(newScroll)
end)

local convoButtons = {}
local RefreshConvoList  -- forward declaration

---------------------------------------------------------------------------
-- Chat view (individual conversation)
---------------------------------------------------------------------------
local newChatView  -- forward declaration
local chatView = CreateFrame("Frame", nil, pg.gchat)
chatView:SetAllPoints()
chatView:Hide()

-- Back button
local backBtn = CreateFrame("Button", nil, chatView)
backBtn:SetSize(30, 14)
backBtn:SetPoint("TOPLEFT", 2, -1)
local backBtnBg = backBtn:CreateTexture(nil, "BACKGROUND")
backBtnBg:SetAllPoints()
backBtnBg:SetTexture("Interface\\Buttons\\WHITE8x8")
backBtnBg:SetVertexColor(0.2, 0.2, 0.25, 0.7)
local backBtnHl = backBtn:CreateTexture(nil, "HIGHLIGHT")
backBtnHl:SetAllPoints()
backBtnHl:SetTexture("Interface\\Buttons\\WHITE8x8")
backBtnHl:SetVertexColor(0.4, 0.4, 0.5, 0.3)
local backLabel = backBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
backLabel:SetPoint("CENTER")
backLabel:SetText("|cffffffffBack|r")
local blFont = backLabel:GetFont()
if blFont then backLabel:SetFont(blFont, 8, "OUTLINE") end

-- Chat title
local chatTitle = chatView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
chatTitle:SetPoint("TOP", 0, -2)
chatTitle:SetTextColor(0.9, 0.9, 0.95, 1)
local ctFont = chatTitle:GetFont()
if ctFont then chatTitle:SetFont(ctFont, 9, "OUTLINE") end

-- Chat message display
local chatScroll = CreateFrame("ScrollingMessageFrame", nil, chatView)
chatScroll:SetPoint("TOPLEFT", 4, -16)
chatScroll:SetPoint("BOTTOMRIGHT", -4, 24)
chatScroll:SetFontObject(GameFontNormalSmall)
local csFont = chatScroll:GetFont()
if csFont then chatScroll:SetFont(csFont, 9, "") end
chatScroll:SetJustifyH("LEFT")
chatScroll:SetMaxLines(200)
chatScroll:SetFading(false)
chatScroll:SetInsertMode("BOTTOM")
chatScroll:EnableMouseWheel(true)
chatScroll:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
end)

local chatBg = chatView:CreateTexture(nil, "BACKGROUND")
chatBg:SetPoint("TOPLEFT", chatScroll, -2, 2)
chatBg:SetPoint("BOTTOMRIGHT", chatScroll, 2, -2)
chatBg:SetTexture("Interface\\Buttons\\WHITE8x8")
chatBg:SetVertexColor(0.05, 0.07, 0.05, 0.8)

-- Input box
local chatInput = CreateFrame("EditBox", nil, chatView, "InputBoxTemplate")
chatInput:SetPoint("BOTTOMLEFT", 6, 4)
chatInput:SetPoint("BOTTOMRIGHT", -6, 4)
chatInput:SetHeight(18)
chatInput:SetAutoFocus(false)
chatInput:SetMaxLetters(255)
local ciFont = chatInput:GetFont()
if ciFont then chatInput:SetFont(ciFont, 9, "") end

chatInput:SetScript("OnEnterPressed", function(self)
    local msg = self:GetText()
    if msg and msg ~= "" and activeConvo then
        local convo = conversations[activeConvo]
        if convo then
            if convo.chatType == "GUILD" then
                SendChatMessage(msg, "GUILD")
            elseif convo.chatType == "WHISPER" then
                SendChatMessage(msg, "WHISPER", nil, convo.name)
            elseif convo.chatType == "PARTY" then
                SendChatMessage(msg, "PARTY")
            elseif convo.chatType == "RAID" then
                SendChatMessage(msg, "RAID")
            elseif convo.chatType == "INSTANCE_CHAT" then
                SendChatMessage(msg, "INSTANCE_CHAT")
            end
        end
        self:SetText("")
    end
    self:ClearFocus()
end)

chatInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
end)

---------------------------------------------------------------------------
-- Open / close conversation
---------------------------------------------------------------------------
local function OpenConvo(id)
    local convo = conversations[id]
    if not convo then return end
    activeConvo = id
    convo.unread = 0
    chatTitle:SetText("|cff40c0ff" .. convo.name .. "|r")
    chatScroll:Clear()
    for _, m in ipairs(convo.messages) do
        chatScroll:AddMessage(m)
    end
    convoListView:Hide()
    if newChatView then newChatView:Hide() end
    chatView:Show()
    chatInput:SetFocus()
end

-- Wire up the notification click handler now that conversations, GetConvo, and OpenConvo all exist
InitNotifClick(conversations, GetConvo, OpenConvo)

local function CloseConvo()
    activeConvo = nil
    chatView:Hide()
    newChatView:Hide()
    convoListView:Show()
    chatInput:ClearFocus()
end

backBtn:SetScript("OnClick", CloseConvo)

---------------------------------------------------------------------------
-- New Chat view (friend picker + manual name input)
---------------------------------------------------------------------------
newChatView = CreateFrame("Frame", nil, pg.gchat)
newChatView:SetAllPoints()
newChatView:Hide()

-- Back button
local ncBackBtn = CreateFrame("Button", nil, newChatView)
ncBackBtn:SetSize(30, 14)
ncBackBtn:SetPoint("TOPLEFT", 2, -1)
local ncBackBg = ncBackBtn:CreateTexture(nil, "BACKGROUND")
ncBackBg:SetAllPoints()
ncBackBg:SetTexture("Interface\\Buttons\\WHITE8x8")
ncBackBg:SetVertexColor(0.2, 0.2, 0.25, 0.7)
local ncBackHl = ncBackBtn:CreateTexture(nil, "HIGHLIGHT")
ncBackHl:SetAllPoints()
ncBackHl:SetTexture("Interface\\Buttons\\WHITE8x8")
ncBackHl:SetVertexColor(0.4, 0.4, 0.5, 0.3)
local ncBackLabel = ncBackBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ncBackLabel:SetPoint("CENTER")
ncBackLabel:SetText("|cffffffffBack|r")
local ncbf = ncBackLabel:GetFont()
if ncbf then ncBackLabel:SetFont(ncbf, 8, "OUTLINE") end

local ncTitle = newChatView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ncTitle:SetPoint("TOP", 0, -2)
ncTitle:SetText("|cff40c0ffNew Chat|r")
local nctf = ncTitle:GetFont()
if nctf then ncTitle:SetFont(nctf, 9, "OUTLINE") end

-- Manual name input
local ncInputLabel = newChatView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ncInputLabel:SetPoint("TOPLEFT", 6, -18)
ncInputLabel:SetText("|cffaaaaaaName or Name-Realm:|r")
local nilf = ncInputLabel:GetFont()
if nilf then ncInputLabel:SetFont(nilf, 8, "") end

local ncInput = CreateFrame("EditBox", nil, newChatView, "InputBoxTemplate")
ncInput:SetPoint("TOPLEFT", 6, -28)
ncInput:SetPoint("RIGHT", -36, 0)
ncInput:SetHeight(16)
ncInput:SetAutoFocus(false)
ncInput:SetMaxLetters(50)
local ncif = ncInput:GetFont()
if ncif then ncInput:SetFont(ncif, 9, "") end

local ncGoBtn = CreateFrame("Button", nil, newChatView)
ncGoBtn:SetSize(26, 16)
ncGoBtn:SetPoint("LEFT", ncInput, "RIGHT", 2, 0)
local ncGoBg = ncGoBtn:CreateTexture(nil, "BACKGROUND")
ncGoBg:SetAllPoints()
ncGoBg:SetTexture("Interface\\Buttons\\WHITE8x8")
ncGoBg:SetVertexColor(0.2, 0.45, 0.3, 0.9)
local ncGoHl = ncGoBtn:CreateTexture(nil, "HIGHLIGHT")
ncGoHl:SetAllPoints()
ncGoHl:SetTexture("Interface\\Buttons\\WHITE8x8")
ncGoHl:SetVertexColor(0.3, 0.6, 0.4, 0.3)
local ncGoLabel = ncGoBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ncGoLabel:SetPoint("CENTER")
ncGoLabel:SetText("|cffffffffGo|r")
local ncgf = ncGoLabel:GetFont()
if ncgf then ncGoLabel:SetFont(ncgf, 8, "OUTLINE") end

-- Forward declare
local StartChatWithName

-- Autocomplete dropdown (overlays on top of friends list)
local acDropdown = CreateFrame("Frame", nil, newChatView)
acDropdown:SetPoint("TOPLEFT", ncInput, "BOTTOMLEFT", -2, -1)
acDropdown:SetPoint("RIGHT", newChatView, "RIGHT", -2, 0)
acDropdown:SetHeight(1)
acDropdown:SetFrameLevel(newChatView:GetFrameLevel() + 10)
acDropdown:Hide()

local acDropBg = acDropdown:CreateTexture(nil, "BACKGROUND")
acDropBg:SetAllPoints()
acDropBg:SetTexture("Interface\\Buttons\\WHITE8x8")
acDropBg:SetVertexColor(0.1, 0.1, 0.13, 0.95)

local acButtons = {}
local AC_ROW_H = 18
local AC_MAX = 5

for i = 1, AC_MAX do
    local btn = CreateFrame("Button", nil, acDropdown)
    btn:SetHeight(AC_ROW_H)
    btn:SetPoint("TOPLEFT", 0, -((i - 1) * AC_ROW_H))
    btn:SetPoint("RIGHT", acDropdown, "RIGHT", 0, 0)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8x8")
    hl:SetVertexColor(0.25, 0.35, 0.5, 0.4)

    local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fs:SetPoint("LEFT", 6, 0)
    fs:SetPoint("RIGHT", -6, 0)
    fs:SetJustifyH("LEFT")
    local af = fs:GetFont()
    if af then fs:SetFont(af, 9, "") end
    btn.label = fs

    btn:Hide()
    acButtons[i] = btn
end

-- Gather all known names for autocomplete
local function GetAllKnownNames()
    local names = {}
    local seen = {}
    -- BNet friends
    local numBNet = BNGetNumFriends()
    for i = 1, numBNet do
        local acctInfo = C_BattleNet.GetFriendAccountInfo(i)
        if acctInfo then
            local gameInfo = acctInfo.gameAccountInfo
            if gameInfo and gameInfo.characterName then
                local name = Ambiguate(gameInfo.characterName, "short")
                if not seen[name:lower()] then
                    seen[name:lower()] = true
                    local label = name
                    if acctInfo.accountName then
                        label = name .. " |cff888888(" .. acctInfo.accountName .. ")|r"
                    end
                    if gameInfo.isOnline then
                        label = label .. " |cff33ff99*|r"
                    end
                    table.insert(names, { name = name, label = label, online = gameInfo.isOnline })
                end
            end
        end
    end
    -- Character-level friends
    local numChar = C_FriendList.GetNumFriends()
    for i = 1, numChar do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name then
            local name = Ambiguate(info.name, "short")
            if not seen[name:lower()] then
                seen[name:lower()] = true
                local label = name
                if info.connected then label = label .. " |cff33ff99*|r" end
                table.insert(names, { name = name, label = label, online = info.connected })
            end
        end
    end
    -- Guild members
    if IsInGuild() then
        local numGuild = GetNumGuildMembers()
        for i = 1, numGuild do
            local fullName, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
            if fullName then
                local name = Ambiguate(fullName, "short")
                if not seen[name:lower()] then
                    seen[name:lower()] = true
                    local label = name .. " |cff33ff99(Guild)|r"
                    table.insert(names, { name = name, label = label, online = isOnline })
                end
            end
        end
    end
    -- Existing conversations
    for _, convo in pairs(conversations) do
        if convo.chatType == "WHISPER" and not seen[convo.name:lower()] then
            seen[convo.name:lower()] = true
            table.insert(names, { name = convo.name, label = convo.name .. " |cff888888(Recent)|r", online = false })
        end
    end
    -- Sort: online first, then alpha
    table.sort(names, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name < b.name
    end)
    return names
end

local function UpdateAutocomplete(text)
    text = strtrim(text or ""):lower()
    for i = 1, AC_MAX do acButtons[i]:Hide() end
    if text == "" then
        acDropdown:Hide()
        return
    end

    local allNames = GetAllKnownNames()
    local matches = {}
    for _, entry in ipairs(allNames) do
        if entry.name:lower():sub(1, #text) == text then
            table.insert(matches, entry)
            if #matches >= AC_MAX then break end
        end
    end

    if #matches == 0 then
        acDropdown:Hide()
        return
    end

    for i, entry in ipairs(matches) do
        local btn = acButtons[i]
        btn.label:SetText(entry.label)
        local pickName = entry.name
        btn:SetScript("OnClick", function()
            ncInput:SetText(pickName)
            ncInput:SetCursorPosition(#pickName)
            acDropdown:Hide()
            StartChatWithName(pickName)
        end)
        btn:Show()
    end
    acDropdown:SetHeight(#matches * AC_ROW_H)
    acDropdown:Show()
end

-- Separator
local ncSep = newChatView:CreateTexture(nil, "ARTWORK")
ncSep:SetPoint("TOPLEFT", 4, -48)
ncSep:SetPoint("RIGHT", -4, 0)
ncSep:SetHeight(1)
ncSep:SetTexture("Interface\\Buttons\\WHITE8x8")
ncSep:SetVertexColor(0.3, 0.3, 0.35, 0.6)

local ncFriendsLabel = newChatView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
ncFriendsLabel:SetPoint("TOPLEFT", 6, -52)
ncFriendsLabel:SetText("|cffaaaaaaFriends:|r")
local nflf = ncFriendsLabel:GetFont()
if nflf then ncFriendsLabel:SetFont(nflf, 8, "") end

-- Scrollable friends list (no visible scrollbar)
local ncFriendScroll = CreateFrame("ScrollFrame", nil, newChatView)
ncFriendScroll:SetPoint("TOPLEFT", 2, -62)
ncFriendScroll:SetPoint("BOTTOMRIGHT", -2, 4)

local ncFriendContent = CreateFrame("Frame", nil, ncFriendScroll)
ncFriendContent:SetSize(1, 1)
ncFriendScroll:SetScrollChild(ncFriendContent)

ncFriendScroll:EnableMouseWheel(true)
ncFriendScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local maxScroll = max(0, ncFriendContent:GetHeight() - self:GetHeight())
    local newScroll = min(maxScroll, max(0, cur - delta * 22))
    self:SetVerticalScroll(newScroll)
end)

local ncFriendButtons = {}

local function CreateFriendRow(parent, pool, row)
    local ROW_H = 22
    local btn = pool[row]
    if not btn then
        btn = CreateFrame("Button", nil, parent)
        btn:SetHeight(ROW_H)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.12, 0.12, 0.15, 0.8)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(0.3, 0.3, 0.4, 0.3)

        local nameFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        nameFs:SetPoint("LEFT", 6, 0)
        nameFs:SetPoint("RIGHT", btn, "RIGHT", -50, 0)
        nameFs:SetJustifyH("LEFT")
        local bnf = nameFs:GetFont()
        if bnf then nameFs:SetFont(bnf, 9, "") end
        btn.nameFs = nameFs

        local statusFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        statusFs:SetPoint("RIGHT", -6, 0)
        statusFs:SetJustifyH("RIGHT")
        local bsf = statusFs:GetFont()
        if bsf then statusFs:SetFont(bsf, 8, "") end
        btn.statusFs = statusFs

        local sep = btn:CreateTexture(nil, "BORDER")
        sep:SetPoint("BOTTOMLEFT", 4, 0)
        sep:SetPoint("BOTTOMRIGHT", -4, 0)
        sep:SetHeight(1)
        sep:SetTexture("Interface\\Buttons\\WHITE8x8")
        sep:SetVertexColor(0.25, 0.25, 0.3, 0.4)

        pool[row] = btn
    end
    return btn
end

-- Friends list is provided by PhoneFriends shared module

local function OpenNewChat()
    convoListView:Hide()
    chatView:Hide()
    newChatView:Show()
    ncInput:SetText("")

    for _, btn in ipairs(ncFriendButtons) do btn:Hide() end

    local ROW_H = 22
    local friends = PhoneFriends:GetList()
    local row = 0

    for _, f in ipairs(friends) do
        row = row + 1
        local btn = CreateFriendRow(ncFriendContent, ncFriendButtons, row)

        local displayName = PhoneFriends:DisplayName(f)

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", 0, -((row - 1) * ROW_H))
        btn:SetPoint("RIGHT", ncFriendContent, "RIGHT", 0, 0)

        if f.isOnline then
            btn.nameFs:SetText("|cffffffff" .. displayName)
            if f.charName then
                btn.statusFs:SetText("|cff33ff99Online|r")
            else
                btn.statusFs:SetText("|cff66aaff BNet|r")
            end
        else
            local plainName = f.bnetName or f.charName or "?"
            btn.nameFs:SetText("|cff666666" .. plainName .. "|r")
            btn.statusFs:SetText("|cff666666Offline|r")
        end

        local targetName = PhoneFriends:WhisperTarget(f) or "?"
        btn:SetScript("OnClick", function()
            if targetName == "?" then return end
            local convoId = "dm:" .. targetName
            GetConvo(convoId, targetName, "WHISPER")
            RefreshConvoList()
            newChatView:Hide()
            OpenConvo(convoId)
        end)
        btn:Show()
    end

    local contentW = ncFriendScroll:GetWidth() or 150
    ncFriendContent:SetSize(contentW, math.max(row * ROW_H, 1))
end

StartChatWithName = function(input)
    local name = strtrim(input or "")
    if name == "" then return end
    name = name:sub(1, 1):upper() .. name:sub(2)
    local convoId = "dm:" .. name
    GetConvo(convoId, name, "WHISPER")
    RefreshConvoList()
    newChatView:Hide()
    acDropdown:Hide()
    OpenConvo(convoId)
end

ncBackBtn:SetScript("OnClick", function()
    newChatView:Hide()
    convoListView:Show()
end)

ncGoBtn:SetScript("OnClick", function()
    StartChatWithName(ncInput:GetText())
end)

ncInput:SetScript("OnEnterPressed", function(self)
    StartChatWithName(self:GetText())
    self:ClearFocus()
end)

ncInput:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    acDropdown:Hide()
end)

ncInput:SetScript("OnTextChanged", function(self)
    UpdateAutocomplete(self:GetText())
end)

newChatBtn:SetScript("OnClick", OpenNewChat)

---------------------------------------------------------------------------
-- Build / refresh conversation list rows
---------------------------------------------------------------------------
RefreshConvoList = function()
    -- Hide all existing buttons
    for _, btn in ipairs(convoButtons) do btn:Hide() end

    -- Build ordered list: group chats first, then DMs sorted by name
    local ordered = {}
    local groupIds = { "guild", "party", "raid", "instance" }
    for _, gid in ipairs(groupIds) do
        if conversations[gid] then
            table.insert(ordered, conversations[gid])
        end
    end
    local friendConvos = {}
    for id, convo in pairs(conversations) do
        if convo.chatType == "WHISPER" then
            table.insert(friendConvos, convo)
        end
    end
    table.sort(friendConvos, function(a, b) return a.name < b.name end)
    for _, c in ipairs(friendConvos) do
        table.insert(ordered, c)
    end

    local ROW_HEIGHT = 28
    local contentWidth = convoScroll:GetWidth() or 150
    convoContent:SetSize(contentWidth, math.max(#ordered * ROW_HEIGHT, 1))

    for i, convo in ipairs(ordered) do
        local btn = convoButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, convoContent)
            btn:SetHeight(ROW_HEIGHT)

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(0.12, 0.12, 0.15, 0.8)
            btn.bg = bg

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Buttons\\WHITE8x8")
            hl:SetVertexColor(0.3, 0.3, 0.4, 0.3)

            local nameFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            nameFs:SetPoint("TOPLEFT", 6, -3)
            nameFs:SetJustifyH("LEFT")
            local nf = nameFs:GetFont()
            if nf then nameFs:SetFont(nf, 9, "") end
            btn.nameFs = nameFs

            local previewFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            previewFs:SetPoint("TOPLEFT", 6, -14)
            previewFs:SetPoint("RIGHT", -6, 0)
            previewFs:SetJustifyH("LEFT")
            previewFs:SetTextColor(0.5, 0.5, 0.55, 1)
            local pf = previewFs:GetFont()
            if pf then previewFs:SetFont(pf, 8, "") end
            btn.previewFs = previewFs

            local unreadFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            unreadFs:SetPoint("RIGHT", -6, 2)
            unreadFs:SetTextColor(0.3, 0.8, 1, 1)
            local uf = unreadFs:GetFont()
            if uf then unreadFs:SetFont(uf, 8, "OUTLINE") end
            btn.unreadFs = unreadFs

            -- Close button
            local closeBtn = CreateFrame("Button", nil, btn)
            closeBtn:SetSize(14, 14)
            closeBtn:SetPoint("TOPRIGHT", -2, -2)
            closeBtn:SetFrameLevel(btn:GetFrameLevel() + 2)
            local closeLabel = closeBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            closeLabel:SetPoint("CENTER", 0, 0)
            closeLabel:SetText("|cff666666x|r")
            local clf = closeLabel:GetFont()
            if clf then closeLabel:SetFont(clf, 9, "OUTLINE") end
            closeBtn:SetScript("OnEnter", function() closeLabel:SetText("|cffff4444x|r") end)
            closeBtn:SetScript("OnLeave", function() closeLabel:SetText("|cff666666x|r") end)
            btn.closeBtn = closeBtn

            -- Separator line
            local sepLine = btn:CreateTexture(nil, "BORDER")
            sepLine:SetPoint("BOTTOMLEFT", 4, 0)
            sepLine:SetPoint("BOTTOMRIGHT", -4, 0)
            sepLine:SetHeight(1)
            sepLine:SetTexture("Interface\\Buttons\\WHITE8x8")
            sepLine:SetVertexColor(0.25, 0.25, 0.3, 0.5)

            convoButtons[i] = btn
        end

        btn:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        btn:SetPoint("RIGHT", convoContent, "RIGHT", 0, 0)

        -- Name display
        local groupColors = {
            GUILD = "33ff99",
            PARTY = "aaaaff",
            RAID = "ff7f00",
            INSTANCE_CHAT = "ffcc66",
        }
        local gc = groupColors[convo.chatType]
        if gc then
            btn.nameFs:SetText("|cff" .. gc .. convo.name .. "|r")
            btn.closeBtn:Hide()
        else
            btn.nameFs:SetText("|cffffffff" .. convo.name .. "|r")
            btn.closeBtn:Show()
            local convoId = convo.id
            btn.closeBtn:SetScript("OnClick", function()
                conversations[convoId] = nil
                if activeConvo == convoId then activeConvo = nil end
                RefreshConvoList()
            end)
        end

        -- Preview (last message, stripped of color codes, truncated)
        local preview = ""
        if #convo.messages > 0 then
            preview = convo.messages[#convo.messages]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if #preview > 30 then preview = preview:sub(1, 28) .. ".." end
        end
        btn.previewFs:SetText(preview)

        -- Unread badge
        if convo.unread > 0 then
            btn.unreadFs:SetText(convo.unread)
            btn.unreadFs:Show()
        else
            btn.unreadFs:SetText("")
            btn.unreadFs:Hide()
        end

        btn:SetScript("OnClick", function() OpenConvo(convo.id) end)
        btn:Show()
    end
end

---------------------------------------------------------------------------
-- Listen for chat events
---------------------------------------------------------------------------
local msgEvents = CreateFrame("Frame")
msgEvents:RegisterEvent("CHAT_MSG_GUILD")
msgEvents:RegisterEvent("CHAT_MSG_GUILD_ACHIEVEMENT")
msgEvents:RegisterEvent("CHAT_MSG_PARTY")
msgEvents:RegisterEvent("CHAT_MSG_PARTY_LEADER")
msgEvents:RegisterEvent("CHAT_MSG_RAID")
msgEvents:RegisterEvent("CHAT_MSG_RAID_LEADER")
msgEvents:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
msgEvents:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
msgEvents:RegisterEvent("CHAT_MSG_WHISPER")
msgEvents:RegisterEvent("CHAT_MSG_WHISPER_INFORM")

-- Track messages we've already handled (to avoid duplicates from dual-hook)
local handledMsgIds = {}
local handledCleanupTimer = 0

local function HandleWhisper(msg, sender, guid)
    local name = Ambiguate(sender, "short")
    local color = "33ff99"
    -- Try to get class color from GUID
    if guid and guid ~= "" then
        local _, classFile = GetPlayerInfoByGUID(guid)
        if classFile then
            color = GetClassColorHex(classFile)
        end
    end
    local convoId = "dm:" .. name
    local formatted = format("|cff%s%s|r: %s", color, name, msg)
    local convo = GetConvo(convoId, name, "WHISPER")
    table.insert(convo.messages, formatted)
    if activeConvo == convoId then
        chatScroll:AddMessage(formatted)
    else
        convo.unread = convo.unread + 1
        ShowNotification(name, msg, convoId)
    end
    RefreshConvoList()
end

local function HandleWhisperInform(msg, sender)
    local target = Ambiguate(sender, "short")
    local convoId = "dm:" .. target
    local playerName = UnitName("player")
    local formatted = format("|cff88bbff%s|r: %s", playerName, msg)
    local convo = GetConvo(convoId, target, "WHISPER")
    table.insert(convo.messages, formatted)
    if activeConvo == convoId then
        chatScroll:AddMessage(formatted)
    end
    RefreshConvoList()
end

msgEvents:SetScript("OnEvent", function(self, event, msg, sender, ...)
    if event == "CHAT_MSG_GUILD" then
        local name = Ambiguate(sender, "short")
        local _, _, _, _, _, _, _, _, _, _, lineID, guid = ...
        local color = "33ff99"
        if guid and guid ~= "" then
            local _, classFile = GetPlayerInfoByGUID(guid)
            if classFile then color = GetClassColorHex(classFile) end
        end
        local formatted = format("|cff%s%s|r: %s", color, name, msg)
        local convo = GetConvo("guild", "Guild Chat", "GUILD")
        table.insert(convo.messages, formatted)
        if activeConvo == "guild" then
            chatScroll:AddMessage(formatted)
        else
            convo.unread = convo.unread + 1
            ShowNotification("[Guild] " .. name, msg, "guild")
        end
        RefreshConvoList()

    elseif event == "CHAT_MSG_GUILD_ACHIEVEMENT" then
        local name = Ambiguate(sender, "short")
        local formatted = format("|cffffff00%s earned: %s|r", name, msg)
        local convo = GetConvo("guild", "Guild Chat", "GUILD")
        table.insert(convo.messages, formatted)
        if activeConvo == "guild" then
            chatScroll:AddMessage(formatted)
        else
            convo.unread = convo.unread + 1
        end
        RefreshConvoList()

    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER"
        or event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        local name = Ambiguate(sender, "short")
        local _, _, _, _, _, _, _, _, _, _, lineID, guid = ...
        local color = "33ff99"
        if guid and guid ~= "" then
            local _, classFile = GetPlayerInfoByGUID(guid)
            if classFile then color = GetClassColorHex(classFile) end
        end
        local isRaid = (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER")
        local convoId = isRaid and "raid" or "party"
        local convoName = isRaid and "Raid Chat" or "Party Chat"
        local chatType = isRaid and "RAID" or "PARTY"
        local prefix = isRaid and "[Raid] " or "[Party] "
        local formatted = format("|cff%s%s|r: %s", color, name, msg)
        local convo = GetConvo(convoId, convoName, chatType)
        table.insert(convo.messages, formatted)
        if activeConvo == convoId then
            chatScroll:AddMessage(formatted)
        else
            convo.unread = convo.unread + 1
            ShowNotification(prefix .. name, msg, convoId)
        end
        RefreshConvoList()

    elseif event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
        local name = Ambiguate(sender, "short")
        local _, _, _, _, _, _, _, _, _, _, _, guid = ...
        local color = "33ff99"
        if guid and guid ~= "" then
            local _, classFile = GetPlayerInfoByGUID(guid)
            if classFile then color = GetClassColorHex(classFile) end
        end
        local formatted = format("|cff%s%s|r: %s", color, name, msg)
        local convo = GetConvo("instance", "Instance Chat", "INSTANCE_CHAT")
        table.insert(convo.messages, formatted)
        if activeConvo == "instance" then
            chatScroll:AddMessage(formatted)
        else
            convo.unread = convo.unread + 1
            ShowNotification("[Instance] " .. name, msg, "instance")
        end
        RefreshConvoList()

    elseif event == "CHAT_MSG_WHISPER" then
        local _, _, _, _, _, _, _, _, lineID, guid = ...
        local msgKey = "w:" .. (lineID or "") .. ":" .. msg
        if handledMsgIds[msgKey] then return end
        handledMsgIds[msgKey] = GetTime()
        HandleWhisper(msg, sender, guid)

    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        local _, _, _, _, _, _, _, _, lineID = ...
        local msgKey = "wi:" .. (lineID or "") .. ":" .. msg
        if handledMsgIds[msgKey] then return end
        handledMsgIds[msgKey] = GetTime()
        HandleWhisperInform(msg, sender)
    end
end)

-- Secondary hook: ChatFrame_AddMessageEventFilter fires BEFORE any addon can
-- filter or suppress the message. This guarantees we see every whisper even if
-- another addon (like WIM) intercepts the event pipeline.
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", function(self, event, msg, sender, ...)
    local _, _, _, _, _, _, _, _, lineID, guid = ...
    local msgKey = "w:" .. (lineID or "") .. ":" .. msg
    if not handledMsgIds[msgKey] then
        handledMsgIds[msgKey] = GetTime()
        HandleWhisper(msg, sender, guid)
    end
    return false  -- never filter; just observe
end)

ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", function(self, event, msg, sender, ...)
    local _, _, _, _, _, _, _, _, lineID = ...
    local msgKey = "wi:" .. (lineID or "") .. ":" .. msg
    if not handledMsgIds[msgKey] then
        handledMsgIds[msgKey] = GetTime()
        HandleWhisperInform(msg, sender)
    end
    return false
end)

-- Periodically clean up old handled message IDs to prevent memory leak
msgEvents:SetScript("OnUpdate", function(self, dt)
    handledCleanupTimer = handledCleanupTimer + dt
    if handledCleanupTimer < 60 then return end
    handledCleanupTimer = 0
    local now = GetTime()
    for k, t in pairs(handledMsgIds) do
        if now - t > 30 then handledMsgIds[k] = nil end
    end
end)

-- Conversations are only created when messages are sent/received.
-- Friends are available through the New Chat picker only.

-- Initial list build
RefreshConvoList()

---------------------------------------------------------------------------
-- Toggle with slash command
---------------------------------------------------------------------------
SLASH_PHONE1 = "/phone"
SlashCmdList["PHONE"] = function()
    phone:SetShown(not phone:IsShown())
end

-- (phone closes via /phone only)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
phone:RegisterEvent("PLAYER_ENTERING_WORLD")
phone:RegisterEvent("ZONE_CHANGED_NEW_AREA")
phone:RegisterEvent("ZONE_CHANGED")
phone:RegisterEvent("ZONE_CHANGED_INDOORS")
phone:RegisterEvent("PLAYER_MONEY")

phone:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if HearthPhoneDB.point then
            self:ClearAllPoints()
            self:SetPoint(HearthPhoneDB.point, UIParent, HearthPhoneDB.relPoint, HearthPhoneDB.x, HearthPhoneDB.y)
        end
        if HearthPhoneDB.phoneScale then
            self:SetScale(HearthPhoneDB.phoneScale)
        end
        -- Apply saved gallery images
        PhoneGalleryApp:ApplyWallpapers()
    end
    UpdateStatusBar()
end)

-- Auto-lock: track last interaction and lock after timeout
HearthPhone_LastActivity = GetTime()

function HearthPhone_ResetActivity()
    HearthPhone_LastActivity = GetTime()
end

-- Hook the screen frame to detect any mouse interaction
screen:HookScript("OnMouseDown", HearthPhone_ResetActivity)
screen:HookScript("OnMouseUp", HearthPhone_ResetActivity)

-- Update time + fitness page + auto-lock
local elapsed = 0
phone:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed >= 0.5 then
        elapsed = 0
        UpdateStatusBar()
        UpdateWidget()
        if phoneLocked then UpdateLockScreen() end
        WowSoFitApp:Update()
        -- Auto-lock check
        local timeout = HearthPhoneDB and HearthPhoneDB.autoLockSeconds or 0
        if timeout > 0 and not phoneLocked and phone:IsVisible() then
            local idle = GetTime() - HearthPhone_LastActivity
            if idle >= timeout then
                SetPhoneState("lock")
                UpdateLockScreen()
                ShowPage("home")
            end
        end
    end
end)

-- Test command: fake a whisper notification
SLASH_PHONETEST1 = "/phonetest"
SlashCmdList["PHONETEST"] = function()
    ShowNotification("TestFriend", "Hey, are you there?", "dm:TestFriend")
end

-- Test command: fake a social @mention notification (no persistent post)
SLASH_PHONETESTMENTION1 = "/phonetestmention"
SlashCmdList["PHONETESTMENTION"] = function()
    local myName = UnitName("player") or "You"
    ShowNotification("[Social] TestUser", "mentioned you: Hey @" .. myName .. " check...", "social:0")
end

-- Test command: fake a game challenge notification
SLASH_PHONETESTGAME1 = "/phonetestgame"
SlashCmdList["PHONETESTGAME"] = function()
    ShowNotification("Game Challenge", "TestPlayer wants to play Tic Tac Toe", "game:tictactoe")
end

SLASH_PHONERESET1 = "/phonereset"
SlashCmdList["PHONERESET"] = function()
    if HearthPhoneDB then HearthPhoneDB.phoneScale = 1.0 end
    if HearthPhoneFrame then HearthPhoneFrame:SetScale(1.0) end
    print("|cff00ccff[Phone]|r Scale reset to 1.0")
end

print("|cff00ccff[Phone]|r Loaded! Type /phone to toggle. /phonereset to reset size.")
