-- PhoneWordle - Wordle word guessing game for HearthPhone

PhoneWordleGame = {}

local parent
local WORD_LEN = 5
local MAX_GUESSES = 6
local currentRow = 1
local currentCol = 1
local targetWord = ""
local guesses = {}
local gameOver = false
local gameWon = false
local cells = {}
local msgFs
local keyButtons = {}

-- WoW-themed 5-letter words
local WORDS = {
    "GNOME", "DWARF", "TROLL", "DRUID", "ROGUE",
    "MAGES", "MOUNT", "QUEST", "ARMOR", "SWORD",
    "STAFF", "SPELL", "FROST", "FLAME", "HEALS",
    "GUILD", "RAIDS", "FLASK", "RELIC", "RUNIC",
    "CHAOS", "LIGHT", "DEATH", "BLOOD", "SHADE",
    "MIGHT", "POWER", "STORM", "EARTH", "STONE",
    "GREED", "HONOR", "VALOR", "PRIDE", "WRATH",
    "DEMON", "BEAST", "TITAN", "WORLD", "REALM",
    "FORGE", "ANVIL", "HEART", "CROWN", "BLADE",
    "LUNAR", "SOLAR", "MAGIC", "NIGHT", "SHIRE",
    "GOLEM", "GHOST", "CRYPT", "TOWER", "WITCH",
    "FEAST", "DANCE", "BRAWL", "SCOUT", "THIEF",
    "CHAIN", "PLATE", "CLOTH", "SKULL", "FERAL",
    "TOTEM", "SIGIL", "GLYPH", "SCALE", "TALON",
    "ABYSS", "SIEGE", "TRAPS", "GUARD", "FIEND",
    "ELDER", "GRIME", "HAUNT", "MURKY", "SHARD",
}

local CORRECT_COLOR = {0.30, 0.55, 0.25}  -- Green
local PRESENT_COLOR = {0.60, 0.55, 0.15}  -- Yellow
local ABSENT_COLOR  = {0.15, 0.15, 0.18}  -- Dark
local EMPTY_COLOR   = {0.10, 0.10, 0.13}
local UNTRIED_COLOR = {0.20, 0.20, 0.24}

local keyStates = {}  -- letter -> "correct", "present", "absent", nil

local UpdateDisplay, UpdateKeyboard

local function PickWord()
    targetWord = WORDS[math.random(#WORDS)]
end

local function CheckGuess(guess)
    local result = {}
    local targetLetters = {}

    -- First pass: correct positions
    for i = 1, WORD_LEN do
        local g = guess:sub(i, i)
        local t = targetWord:sub(i, i)
        if g == t then
            result[i] = "correct"
        else
            targetLetters[t] = (targetLetters[t] or 0) + 1
        end
    end

    -- Second pass: present but wrong position
    for i = 1, WORD_LEN do
        if not result[i] then
            local g = guess:sub(i, i)
            if targetLetters[g] and targetLetters[g] > 0 then
                result[i] = "present"
                targetLetters[g] = targetLetters[g] - 1
            else
                result[i] = "absent"
            end
        end
    end

    return result
end

local function GetColor(state)
    if state == "correct" then return CORRECT_COLOR
    elseif state == "present" then return PRESENT_COLOR
    elseif state == "absent" then return ABSENT_COLOR
    else return EMPTY_COLOR end
end

local function SubmitGuess()
    if gameOver or gameWon then return end
    if currentCol <= WORD_LEN then return end  -- Not enough letters

    local guess = guesses[currentRow]
    local result = CheckGuess(guess)

    -- Update cell colors
    for i = 1, WORD_LEN do
        local c = GetColor(result[i])
        cells[currentRow][i].bg:SetVertexColor(c[1], c[2], c[3], 1)

        -- Update keyboard state
        local letter = guess:sub(i, i)
        local current = keyStates[letter]
        if result[i] == "correct" then
            keyStates[letter] = "correct"
        elseif result[i] == "present" and current ~= "correct" then
            keyStates[letter] = "present"
        elseif not current then
            keyStates[letter] = "absent"
        end
    end

    UpdateKeyboard()

    -- Check win
    local allCorrect = true
    for i = 1, WORD_LEN do
        if result[i] ~= "correct" then allCorrect = false end
    end

    if allCorrect then
        gameWon = true
        msgFs:SetText("|cff44ff44Got it!|r")
        return
    end

    currentRow = currentRow + 1
    currentCol = 1
    guesses[currentRow] = ""

    if currentRow > MAX_GUESSES then
        gameOver = true
        msgFs:SetText("|cffff4444" .. targetWord .. "|r")
    end
end

local function TypeLetter(letter)
    if gameOver or gameWon then return end
    if currentCol > WORD_LEN then return end

    guesses[currentRow] = (guesses[currentRow] or "") .. letter
    cells[currentRow][currentCol].label:SetText("|cffffffff" .. letter .. "|r")
    currentCol = currentCol + 1
end

local function Backspace()
    if gameOver or gameWon then return end
    if currentCol <= 1 then return end

    currentCol = currentCol - 1
    guesses[currentRow] = guesses[currentRow]:sub(1, currentCol - 1)
    cells[currentRow][currentCol].label:SetText("")
end

local function NewGame()
    PickWord()
    currentRow = 1
    currentCol = 1
    gameOver = false
    gameWon = false
    guesses = { "" }
    wipe(keyStates)
    msgFs:SetText("")

    for r = 1, MAX_GUESSES do
        for c = 1, WORD_LEN do
            cells[r][c].bg:SetVertexColor(EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3], 1)
            cells[r][c].label:SetText("")
        end
    end

    UpdateKeyboard()
end

UpdateKeyboard = function()
    for letter, btn in pairs(keyButtons) do
        local state = keyStates[letter]
        if state == "correct" then
            btn.bg:SetVertexColor(CORRECT_COLOR[1], CORRECT_COLOR[2], CORRECT_COLOR[3], 1)
        elseif state == "present" then
            btn.bg:SetVertexColor(PRESENT_COLOR[1], PRESENT_COLOR[2], PRESENT_COLOR[3], 1)
        elseif state == "absent" then
            btn.bg:SetVertexColor(ABSENT_COLOR[1], ABSENT_COLOR[2], ABSENT_COLOR[3], 1)
        else
            btn.bg:SetVertexColor(UNTRIED_COLOR[1], UNTRIED_COLOR[2], UNTRIED_COLOR[3], 1)
        end
    end
end

function PhoneWordleGame:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local W = parent:GetWidth()
    if W < 10 then W = 170 end

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffffffffWordle|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 11, "OUTLINE") end

    -- New game button
    local newBtn = CreateFrame("Button", nil, parent)
    newBtn:SetSize(28, 14)
    newBtn:SetPoint("TOPRIGHT", -4, -2)

    local newBg = newBtn:CreateTexture(nil, "BACKGROUND")
    newBg:SetAllPoints()
    newBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    newBg:SetVertexColor(0.15, 0.15, 0.2, 1)

    local newHl = newBtn:CreateTexture(nil, "HIGHLIGHT")
    newHl:SetAllPoints()
    newHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    newHl:SetVertexColor(0.25, 0.25, 0.3, 0.4)

    local newLabel = newBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    newLabel:SetPoint("CENTER")
    newLabel:SetText("|cffffffffNew|r")
    local nlf = newLabel:GetFont()
    if nlf then newLabel:SetFont(nlf, 7, "") end
    newBtn:SetScript("OnClick", NewGame)

    -- Message
    msgFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    msgFs:SetPoint("TOP", 0, -16)
    local mf = msgFs:GetFont()
    if mf then msgFs:SetFont(mf, 8, "OUTLINE") end

    -- Grid: 6 rows x 5 cols
    local cellSize = 24
    local cellGap = 3
    local gridW = WORD_LEN * cellSize + (WORD_LEN - 1) * cellGap
    local gridStartX = (W - gridW) / 2
    local gridStartY = -26

    for r = 1, MAX_GUESSES do
        cells[r] = {}
        for c = 1, WORD_LEN do
            local f = CreateFrame("Frame", nil, parent)
            f:SetSize(cellSize, cellSize)
            f:SetPoint("TOPLEFT", gridStartX + (c - 1) * (cellSize + cellGap), gridStartY - (r - 1) * (cellSize + cellGap))

            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(EMPTY_COLOR[1], EMPTY_COLOR[2], EMPTY_COLOR[3], 1)

            local label = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            label:SetPoint("CENTER")
            local lf = label:GetFont()
            if lf then label:SetFont(lf, 11, "OUTLINE") end

            cells[r][c] = { frame = f, bg = bg, label = label }
        end
    end

    -- Keyboard
    local rows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
    local keyW = 15
    local keyH = 18
    local keyGap = 2
    local kbStartY = gridStartY - MAX_GUESSES * (cellSize + cellGap) - 6

    for ri, row in ipairs(rows) do
        local rowW = #row * keyW + (#row - 1) * keyGap
        local rowStartX = (W - rowW) / 2

        for ki = 1, #row do
            local letter = row:sub(ki, ki)
            local btn = CreateFrame("Button", nil, parent)
            btn:SetSize(keyW, keyH)
            btn:SetPoint("TOPLEFT", rowStartX + (ki - 1) * (keyW + keyGap), kbStartY - (ri - 1) * (keyH + keyGap))

            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture("Interface\\Buttons\\WHITE8x8")
            bg:SetVertexColor(UNTRIED_COLOR[1], UNTRIED_COLOR[2], UNTRIED_COLOR[3], 1)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture("Interface\\Buttons\\WHITE8x8")
            hl:SetVertexColor(1, 1, 1, 0.15)

            local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            label:SetPoint("CENTER")
            label:SetText("|cffffffff" .. letter .. "|r")
            local lf = label:GetFont()
            if lf then label:SetFont(lf, 8, "") end

            local l = letter
            btn:SetScript("OnClick", function() TypeLetter(l) end)

            keyButtons[letter] = { btn = btn, bg = bg }
        end
    end

    -- Backspace and Enter buttons
    local actionY = kbStartY - 3 * (keyH + keyGap)

    local bsBtn = CreateFrame("Button", nil, parent)
    bsBtn:SetSize(40, keyH)
    bsBtn:SetPoint("TOPLEFT", 6, actionY)

    local bsBg = bsBtn:CreateTexture(nil, "BACKGROUND")
    bsBg:SetAllPoints()
    bsBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bsBg:SetVertexColor(0.25, 0.15, 0.15, 1)

    local bsHl = bsBtn:CreateTexture(nil, "HIGHLIGHT")
    bsHl:SetAllPoints()
    bsHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    bsHl:SetVertexColor(1, 1, 1, 0.15)

    local bsLabel = bsBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bsLabel:SetPoint("CENTER")
    bsLabel:SetText("|cffffffffDel|r")
    local bslf = bsLabel:GetFont()
    if bslf then bsLabel:SetFont(bslf, 8, "") end
    bsBtn:SetScript("OnClick", Backspace)

    local enterBtn = CreateFrame("Button", nil, parent)
    enterBtn:SetSize(40, keyH)
    enterBtn:SetPoint("TOPRIGHT", -6, actionY)

    local enterBg = enterBtn:CreateTexture(nil, "BACKGROUND")
    enterBg:SetAllPoints()
    enterBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    enterBg:SetVertexColor(0.15, 0.25, 0.15, 1)

    local enterHl = enterBtn:CreateTexture(nil, "HIGHLIGHT")
    enterHl:SetAllPoints()
    enterHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    enterHl:SetVertexColor(1, 1, 1, 0.15)

    local enterLabel = enterBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    enterLabel:SetPoint("CENTER")
    enterLabel:SetText("|cffffffffEnter|r")
    local elf = enterLabel:GetFont()
    if elf then enterLabel:SetFont(elf, 8, "") end
    enterBtn:SetScript("OnClick", SubmitGuess)
end

function PhoneWordleGame:OnShow()
    if not targetWord or targetWord == "" then
        NewGame()
    end
end

function PhoneWordleGame:OnHide()
end
