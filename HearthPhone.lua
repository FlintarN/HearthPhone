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
local ICON_PADDING = 14
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

local function UpdateStatusBar()
    local h, m = GetGameTime()
    timeText:SetText(format("%02d:%02d", h, m))

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

-- Scrollable home content
local homeScroll = CreateFrame("ScrollFrame", nil, homePage)
homeScroll:SetAllPoints()
homeScroll:EnableMouseWheel(true)
homeScroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll()
    local maxS = max(0, (self.contentHeight or 0) - self:GetHeight())
    local newS = min(maxS, max(0, cur - delta * 40))
    self:SetVerticalScroll(newS)
end)

local homeContent = CreateFrame("Frame", nil, homeScroll)
homeContent:SetWidth(PHONE_WIDTH - BEZEL_INSET_LEFT - BEZEL_INSET_RIGHT)
homeContent:SetHeight(400)
homeScroll:SetScrollChild(homeContent)

-- Fitness page container (leave 28px at bottom for home button)
local fitnessPage = CreateFrame("Frame", nil, screen)
fitnessPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
fitnessPage:SetPoint("BOTTOMRIGHT", 0, 28)
fitnessPage:Hide()

-- Snake page container
local snakePage = CreateFrame("Frame", "HearthPhoneSnakePage", screen)
snakePage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
snakePage:SetPoint("BOTTOMRIGHT", 0, 28)
snakePage:Hide()

-- Guild chat page container
local gchatPage = CreateFrame("Frame", nil, screen)
gchatPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
gchatPage:SetPoint("BOTTOMRIGHT", 0, 28)
gchatPage:Hide()

-- Tetris page container
local tetrisPage = CreateFrame("Frame", "HearthPhoneTetrisPage", screen)
tetrisPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
tetrisPage:SetPoint("BOTTOMRIGHT", 0, 28)
tetrisPage:Hide()

-- Tic-Tac-Toe page container
local tictactoePage = CreateFrame("Frame", nil, screen)
tictactoePage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
tictactoePage:SetPoint("BOTTOMRIGHT", 0, 28)
tictactoePage:Hide()

-- Music page container
local musicPage = CreateFrame("Frame", nil, screen)
musicPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
musicPage:SetPoint("BOTTOMRIGHT", 0, 28)
musicPage:Hide()

-- Uber page container
local uberPage = CreateFrame("Frame", nil, screen)
uberPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
uberPage:SetPoint("BOTTOMRIGHT", 0, 28)
uberPage:Hide()

-- Candy Crush page container
local candyPage = CreateFrame("Frame", nil, screen)
candyPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
candyPage:SetPoint("BOTTOMRIGHT", 0, 28)
candyPage:Hide()

-- Notes page container
local notesPage = CreateFrame("Frame", nil, screen)
notesPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
notesPage:SetPoint("BOTTOMRIGHT", 0, 28)
notesPage:Hide()

-- 2048 page container
local page2048 = CreateFrame("Frame", nil, screen)
page2048:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
page2048:SetPoint("BOTTOMRIGHT", 0, 28)
page2048:Hide()

-- Minesweeper page container
local minesPage = CreateFrame("Frame", nil, screen)
minesPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
minesPage:SetPoint("BOTTOMRIGHT", 0, 28)
minesPage:Hide()

-- Flappy Bird page container
local flappyPage = CreateFrame("Frame", nil, screen)
flappyPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
flappyPage:SetPoint("BOTTOMRIGHT", 0, 28)
flappyPage:Hide()

-- Wordle page container
local wordlePage = CreateFrame("Frame", nil, screen)
wordlePage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
wordlePage:SetPoint("BOTTOMRIGHT", 0, 28)
wordlePage:Hide()

-- Weather page container
local weatherPage = CreateFrame("Frame", nil, screen)
weatherPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
weatherPage:SetPoint("BOTTOMRIGHT", 0, 28)
weatherPage:Hide()

-- Calculator page container
local calcPage = CreateFrame("Frame", nil, screen)
calcPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
calcPage:SetPoint("BOTTOMRIGHT", 0, 28)
calcPage:Hide()

-- Angry Birds page container
local angrybirdsPage = CreateFrame("Frame", nil, screen)
angrybirdsPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
angrybirdsPage:SetPoint("BOTTOMRIGHT", 0, 28)
angrybirdsPage:Hide()

-- Space Shooter page container
local shooterPage = CreateFrame("Frame", nil, screen)
shooterPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
shooterPage:SetPoint("BOTTOMRIGHT", 0, 28)
shooterPage:Hide()

local templerunPage = CreateFrame("Frame", nil, screen)
templerunPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
templerunPage:SetPoint("BOTTOMRIGHT", 0, 28)
templerunPage:Hide()

local subwayPage = CreateFrame("Frame", nil, screen)
subwayPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
subwayPage:SetPoint("BOTTOMRIGHT", 0, 28)
subwayPage:Hide()

local timerPage = CreateFrame("Frame", nil, screen)
timerPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
timerPage:SetPoint("BOTTOMRIGHT", 0, 28)
timerPage:Hide()

local calendarPage = CreateFrame("Frame", nil, screen)
calendarPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
calendarPage:SetPoint("BOTTOMRIGHT", 0, 28)
calendarPage:Hide()

local dpsMeterPage = CreateFrame("Frame", nil, screen)
dpsMeterPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
dpsMeterPage:SetPoint("BOTTOMRIGHT", 0, 28)
dpsMeterPage:Hide()

local cameraPage = CreateFrame("Frame", nil, screen)
cameraPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
cameraPage:SetPoint("BOTTOMRIGHT", 0, 28)
cameraPage:Hide()

-- Gallery page container
local galleryPage = CreateFrame("Frame", nil, screen)
galleryPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
galleryPage:SetPoint("BOTTOMRIGHT", 0, 28)
galleryPage:Hide()

-- Battleship page container
local battleshipPage = CreateFrame("Frame", nil, screen)
battleshipPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
battleshipPage:SetPoint("BOTTOMRIGHT", 0, 28)
battleshipPage:Hide()

-- Toys page container
local toysPage = CreateFrame("Frame", nil, screen)
toysPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
toysPage:SetPoint("BOTTOMRIGHT", 0, 28)
toysPage:Hide()

local socialPage = CreateFrame("Frame", nil, screen)
socialPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
socialPage:SetPoint("BOTTOMRIGHT", 0, 28)
socialPage:Hide()

local agarioPage = CreateFrame("Frame", nil, screen)
agarioPage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
agarioPage:SetPoint("BOTTOMRIGHT", 0, 28)
agarioPage:Hide()

-- Phone Call page container
local phonePage = CreateFrame("Frame", nil, screen)
phonePage:SetPoint("TOPLEFT", 0, -(STATUS_BAR_HEIGHT + 6))
phonePage:SetPoint("BOTTOMRIGHT", 0, 28)
phonePage:Hide()

local homeBtn -- forward declaration

local homeBtnBar -- forward declaration

local function ShowPage(page)
    currentPage = page
    screenBg:SetShown(page == "home")
    homePage:SetShown(page == "home")
    fitnessPage:SetShown(page == "fitness")
    snakePage:SetShown(page == "snake")
    gchatPage:SetShown(page == "gchat")
    tetrisPage:SetShown(page == "tetris")
    tictactoePage:SetShown(page == "tictactoe")
    musicPage:SetShown(page == "music")
    uberPage:SetShown(page == "uber")
    candyPage:SetShown(page == "candy")
    notesPage:SetShown(page == "notes")
    page2048:SetShown(page == "2048")
    minesPage:SetShown(page == "mines")
    flappyPage:SetShown(page == "flappy")
    wordlePage:SetShown(page == "wordle")
    weatherPage:SetShown(page == "weather")
    calcPage:SetShown(page == "calc")
    angrybirdsPage:SetShown(page == "angrybirds")
    phonePage:SetShown(page == "phone")
    shooterPage:SetShown(page == "shooter")
    templerunPage:SetShown(page == "templerun")
    subwayPage:SetShown(page == "subway")
    battleshipPage:SetShown(page == "battleship")
    toysPage:SetShown(page == "toys")
    socialPage:SetShown(page == "social")
    agarioPage:SetShown(page == "agario")
    timerPage:SetShown(page == "timer")
    calendarPage:SetShown(page == "calendar")
    dpsMeterPage:SetShown(page == "dpsmeter")
    cameraPage:SetShown(page == "camera")
    galleryPage:SetShown(page == "gallery")
    -- Notify apps of show/hide
    if page == "snake" then PhoneSnakeGame:OnShow() else PhoneSnakeGame:OnHide() end
    if page == "tetris" then PhoneTetrisGame:OnShow() else PhoneTetrisGame:OnHide() end
    if page == "fitness" then WowSoFitApp:OnShow() else WowSoFitApp:OnHide() end
    if page == "tictactoe" then PhoneTicTacToeGame:OnShow() else PhoneTicTacToeGame:OnHide() end
    if page == "music" then PhoneMusicApp:OnShow() else PhoneMusicApp:OnHide() end
    if page == "uber" then PhoneUberApp:OnShow() else PhoneUberApp:OnHide() end
    if page == "candy" then PhoneCandyCrushGame:OnShow() else PhoneCandyCrushGame:OnHide() end
    if page == "notes" then PhoneNotesApp:OnShow() else PhoneNotesApp:OnHide() end
    if page == "2048" then Phone2048Game:OnShow() else Phone2048Game:OnHide() end
    if page == "mines" then PhoneMinesweeperGame:OnShow() else PhoneMinesweeperGame:OnHide() end
    if page == "flappy" then PhoneFlappyBirdGame:OnShow() else PhoneFlappyBirdGame:OnHide() end
    if page == "wordle" then PhoneWordleGame:OnShow() else PhoneWordleGame:OnHide() end
    if page == "weather" then PhoneWeatherApp:OnShow() else PhoneWeatherApp:OnHide() end
    if page == "calc" then PhoneCalculatorApp:OnShow() else PhoneCalculatorApp:OnHide() end
    if page == "angrybirds" then PhoneAngryBirdsGame:OnShow() else PhoneAngryBirdsGame:OnHide() end
    if page == "phone" then PhoneCallApp:OnShow() else PhoneCallApp:OnHide() end
    if page == "shooter" then PhoneSpaceShooterGame:OnShow() else PhoneSpaceShooterGame:OnHide() end
    if page == "templerun" then PhoneTempleRunGame:OnShow() else PhoneTempleRunGame:OnHide() end
    if page == "subway" then PhoneSubwaySurfersGame:OnShow() else PhoneSubwaySurfersGame:OnHide() end
    if page == "battleship" then PhoneBattleshipGame:OnShow() else PhoneBattleshipGame:OnHide() end
    if page == "toys" then PhoneToysApp:OnShow() else PhoneToysApp:OnHide() end
    if page == "social" then PhoneSocialApp:OnShow() else PhoneSocialApp:OnHide() end
    if page == "agario" then PhoneAgarioGame:OnShow() else PhoneAgarioGame:OnHide() end
    if page == "timer" then PhoneTimerApp:OnShow() else PhoneTimerApp:OnHide() end
    if page == "calendar" then PhoneCalendarApp:OnShow() else PhoneCalendarApp:OnHide() end
    if page == "dpsmeter" then PhoneDamageMeterApp:OnShow() else PhoneDamageMeterApp:OnHide() end
    if page == "camera" then PhoneCameraApp:OnShow() else PhoneCameraApp:OnHide() end
    if page == "gallery" then PhoneGalleryApp:OnShow() else PhoneGalleryApp:OnHide() end
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

-- Lock screen overlay
local ToggleLock -- forward declaration
local notifBanner, notifConvoId, notifTimer -- forward declarations
local lockScreen = CreateFrame("Frame", nil, screen)
lockScreen:SetPoint("TOPLEFT", -4, 4)
lockScreen:SetPoint("BOTTOMRIGHT", 4, -4)
lockScreen:SetFrameLevel(screen:GetFrameLevel() + 20)
lockScreen:EnableMouse(true) -- block clicks through to apps
lockScreen:SetScript("OnMouseDown", function() ToggleLock() end)

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

local phoneLocked = true

local function UpdateLockScreen()
    local h, m = GetGameTime()
    lockTime:SetText(format("%02d:%02d", h, m))
    lockZone:SetText(GetMinimapZoneText() or "")
    lockDate:SetText(date("%A"))
end

ToggleLock = function()
    phoneLocked = not phoneLocked
    lockScreen:SetShown(phoneLocked)
    if phoneLocked then
        UpdateLockScreen()
        ShowPage("home")
    else
        -- Dismiss sticky lock-screen notification on unlock
        notifBanner:Hide()
        notifConvoId = nil
        if notifTimer then notifTimer:Cancel(); notifTimer = nil end
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
local function ShowNotification(senderName, message, convoId)
    -- Don't show if we're already looking at this conversation
    if currentPage == "gchat" and activeConvo == convoId then return end
    -- Don't show social mentions if already viewing that post
    if currentPage == "social" and convoId and convoId:match("^social:") then return end
    -- Don't show if phone is hidden
    if not phone:IsVisible() then return end

    notifSender:SetText("|cff40c0ff" .. senderName .. "|r")
    local preview = message
    if #preview > 35 then preview = preview:sub(1, 33) .. ".." end
    notifMsg:SetText(preview)
    notifConvoId = convoId
    notifBanner:Show()

    -- Vibrate the phone
    StartVibrate()

    -- Auto-hide: stay permanently when locked, 8 seconds when unlocked
    if notifTimer then notifTimer:Cancel() end
    if not phoneLocked then
        notifTimer = C_Timer.NewTimer(8, function()
            HideNotification()
        end)
    end
end

-- Global reference so other modules can trigger notifications
HearthPhoneNotify = ShowNotification

notifBanner:SetScript("OnClick", function()
    local id = notifConvoId
    HideNotification()
    if id then
        if phoneLocked then
            phoneLocked = false
            lockScreen:Hide()
        end
        -- Social app mention notification — route to social app
        local socialPostId = id:match("^social:(.+)$")
        if socialPostId then
            ShowPage("social")
            if PhoneSocialApp.OpenPostById then
                PhoneSocialApp:OpenPostById(tonumber(socialPostId) or 0)
            end
            return
        end
        -- Ensure conversation exists before opening
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
        OpenConvo(id)
    end
end)

---------------------------------------------------------------------------
-- Home screen widget (clock + location, top row)
---------------------------------------------------------------------------
local widget = CreateFrame("Frame", nil, homeContent)
widget:SetPoint("TOPLEFT", 4, -2)
widget:SetPoint("TOPRIGHT", -4, -2)
widget:SetHeight(WIDGET_HEIGHT)

-- No background — text floats over gallery image with shadows for readability

-- Time display
local widgetTime = widget:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
widgetTime:SetPoint("TOP", 0, -3)
widgetTime:SetTextColor(1, 1, 1, 1)
local wtFont = widgetTime:GetFont()
if wtFont then widgetTime:SetFont(wtFont, 18, "OUTLINE") end
widgetTime:SetShadowColor(0, 0, 0, 0.8)
widgetTime:SetShadowOffset(1, -1)

-- Zone name
local widgetZone = widget:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
widgetZone:SetPoint("TOP", widgetTime, "BOTTOM", 0, -1)
widgetZone:SetTextColor(0.9, 0.9, 0.95, 1)
local wzFont = widgetZone:GetFont()
if wzFont then widgetZone:SetFont(wzFont, 9, "OUTLINE") end
widgetZone:SetShadowColor(0, 0, 0, 0.8)
widgetZone:SetShadowOffset(1, -1)

-- Date line
local widgetDate = widget:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
widgetDate:SetPoint("TOP", widgetZone, "BOTTOM", 0, -1)
widgetDate:SetTextColor(0.95, 0.95, 1, 1)
local wdtFont = widgetDate:GetFont()
if wdtFont then widgetDate:SetFont(wdtFont, 8, "OUTLINE") end
widgetDate:SetShadowColor(0, 0, 0, 0.8)
widgetDate:SetShadowOffset(1, -1)

local DAY_NAMES = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"}
local MONTH_NAMES = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}

local function UpdateWidget()
    local h, m = GetGameTime()
    widgetTime:SetText(format("%02d:%02d", h, m))
    widgetZone:SetText(GetMinimapZoneText() or "")

    -- Real-world date
    local d = date("*t")
    widgetDate:SetText(format("%s, %s %d", DAY_NAMES[d.wday], MONTH_NAMES[d.month], d.day))
end

---------------------------------------------------------------------------
-- App icon buttons (home page)
---------------------------------------------------------------------------
local APP_Y_OFFSET = WIDGET_HEIGHT + 16

local function CreateAppButton(parent, appData, index)
    local row = floor((index - 1) / COLS)
    local col = (index - 1) % COLS

    local parentWidth = PHONE_WIDTH - BEZEL_INSET_LEFT - BEZEL_INSET_RIGHT - 4
    local totalIconWidth = COLS * ICON_SIZE + (COLS - 1) * ICON_PADDING
    local offsetX = (parentWidth - totalIconWidth) / 2

    local xPos = offsetX + col * (ICON_SIZE + ICON_PADDING)
    local yPos = -(APP_Y_OFFSET + row * (ICON_SIZE + ICON_PADDING + 14))

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetPoint("TOPLEFT", xPos, yPos)
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

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.28, 0.28, 0.35, 0.9)
        self:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.8)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.18, 0.18, 0.22, 0.9)
        self:SetBackdropBorderColor(0.25, 0.25, 0.30, 0.6)
    end)

    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOP", btn, "BOTTOM", 0, -1)
    label:SetText(appData.label)
    label:SetTextColor(0.75, 0.75, 0.8, 1)
    local fontFile = label:GetFont()
    if fontFile then label:SetFont(fontFile, 8, "OUTLINE") end

    btn:SetScript("OnClick", function()
        if appData.page then
            ShowPage(appData.page)
            return
        end
        if InCombatLockdown() then
            print("|cffff4444[Phone]|r Can't open panels in combat.")
            return
        end
        appData.action()
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(appData.label)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    return btn
end

-- Defer icon creation until all addons are loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local idx = 1
    for _, app in ipairs(apps) do
        local btn = CreateAppButton(homeContent, app, idx)
        if btn then idx = idx + 1 end
    end
    -- Set scroll content height based on number of rows
    local totalApps = idx - 1
    local rows = ceil(totalApps / COLS)
    local contentH = APP_Y_OFFSET + rows * (ICON_SIZE + ICON_PADDING + 14) + 10
    homeContent:SetHeight(contentH)
    homeScroll.contentHeight = contentH
    -- Initialize built-in apps (pcall to prevent one failure from blocking the rest)
    local inits = {
        { PhoneSnakeGame, snakePage },
        { PhoneTetrisGame, tetrisPage },
        { PhoneTicTacToeGame, tictactoePage },
        { WowSoFitApp, fitnessPage },
        { PhoneMusicApp, musicPage },
        { PhoneUberApp, uberPage },
        { PhoneCandyCrushGame, candyPage },
        { PhoneNotesApp, notesPage },
        { Phone2048Game, page2048 },
        { PhoneMinesweeperGame, minesPage },
        { PhoneFlappyBirdGame, flappyPage },
        { PhoneWordleGame, wordlePage },
        { PhoneWeatherApp, weatherPage },
        { PhoneCalculatorApp, calcPage },
        { PhoneAngryBirdsGame, angrybirdsPage },
        { PhoneCallApp, phonePage },
        { PhoneSpaceShooterGame, shooterPage },
        { PhoneTempleRunGame, templerunPage },
        { PhoneSubwaySurfersGame, subwayPage },
        { PhoneBattleshipGame, battleshipPage },
        { PhoneToysApp, toysPage },
        { PhoneSocialApp, socialPage },
        { PhoneAgarioGame, agarioPage },
        { PhoneTimerApp, timerPage },
        { PhoneCalendarApp, calendarPage },
        { PhoneDamageMeterApp, dpsMeterPage },
        { PhoneCameraApp, cameraPage },
        { PhoneGalleryApp, galleryPage },
    }
    for _, pair in ipairs(inits) do
        local ok, err = pcall(pair[1].Init, pair[1], pair[2])
        if not ok then
            print("|cffff4444[HearthPhone]|r Init error: " .. tostring(err))
        end
    end

    -- Give PhoneCallApp a way to force-show the phone on the call page
    PhoneCallApp.ForceShowCall = function()
        phone:Show()
        ShowPage("phone")
    end

    -- Give games a way to force-show their page (for incoming challenges)
    PhoneTicTacToeGame.ForceShow = function()
        phone:Show()
        ShowPage("tictactoe")
    end
    PhoneBattleshipGame.ForceShow = function()
        phone:Show()
        ShowPage("battleship")
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

-- Helper: get class color hex for a player name
local function GetClassColorHex(classFile)
    if classFile then
        local cc = RAID_CLASS_COLORS[classFile]
        if cc then return cc:GenerateHexColor():sub(3) end
    end
    return "33ff99"
end

---------------------------------------------------------------------------
-- Conversation list view (inside gchatPage)
---------------------------------------------------------------------------
local convoListView = CreateFrame("Frame", nil, gchatPage)
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
local chatView = CreateFrame("Frame", nil, gchatPage)
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
newChatView = CreateFrame("Frame", nil, gchatPage)
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
        -- Apply saved gallery images
        PhoneGalleryApp:ApplyWallpapers()
    end
    UpdateStatusBar()
end)

-- Update time + fitness page
local elapsed = 0
phone:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed >= 0.5 then
        elapsed = 0
        UpdateStatusBar()
        UpdateWidget()
        if phoneLocked then UpdateLockScreen() end
        WowSoFitApp:Update()
    end
end)

-- Test command: fake a whisper notification
SLASH_PHONETEST1 = "/phonetest"
SlashCmdList["PHONETEST"] = function()
    ShowNotification("TestFriend", "Hey, are you there?", "dm:TestFriend")
end

-- Test command: fake a social @mention notification (creates a real post)
SLASH_PHONETESTMENTION1 = "/phonetestmention"
SlashCmdList["PHONETESTMENTION"] = function()
    local myName = UnitName("player") or "You"
    -- Create a fake post that mentions the player
    local db = HearthPhoneDB and HearthPhoneDB.social
    if db and db.posts then
        local post = {
            id = time() * 1000 + math.random(999),
            author = "TestUser-TestRealm",
            authorClass = "MAGE",
            text = "Hey @" .. myName .. " check this out!",
            timestamp = time(),
            comments = {},
        }
        table.insert(db.posts, 1, post)
        if PhoneSocialApp.RefreshFeed then PhoneSocialApp:RefreshFeed() end
        ShowNotification("[Social] TestUser", "mentioned you: Hey @" .. myName .. " check...", "social:" .. post.id)
        print("|cff00ccff[Phone]|r Created test mention post. Click the notification!")
    end
end

print("|cff00ccff[Phone]|r Loaded! Type /phone to toggle. /phonetest to test notifications.")
