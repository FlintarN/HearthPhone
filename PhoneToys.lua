-- PhoneToys - Browse and use your collected toys from the phone

PhoneToysApp = {}

local parent
local visible = false
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- UI refs
local searchBar, scrollFrame, scrollContent
local toyRows = {}
local searchText = ""
local currentFilter = "all"
local filterBtns = {}
local countFs
local cdTicker

-- Get toy cooldown remaining (seconds), returns 0 if not on cooldown
local function GetToyCooldown(itemId)
    local result = 0

    -- Approach 1: Get spell from item, then check spell cooldown
    pcall(function()
        local _, spellID = C_Item.GetItemSpell(itemId)
        if spellID and spellID > 0 then
            local info = C_Spell.GetSpellCooldown(spellID)
            if info and info.duration and info.duration > 1.5 then
                local rem = (info.startTime + info.duration) - GetTime()
                if rem > 1 then result = rem end
            end
        end
    end)
    if result > 0 then return result end

    -- Approach 2: Get spell from toy link
    pcall(function()
        local link = C_ToyBox.GetToyLink(itemId)
        if link then
            local _, spellID = C_Item.GetItemSpell(link)
            if spellID and spellID > 0 then
                local info = C_Spell.GetSpellCooldown(spellID)
                if info and info.duration and info.duration > 1.5 then
                    local rem = (info.startTime + info.duration) - GetTime()
                    if rem > 1 then result = rem end
                end
            end
        end
    end)
    if result > 0 then return result end

    -- Approach 3: Global GetItemCooldown
    pcall(function()
        if GetItemCooldown then
            local start, dur, enable = GetItemCooldown(itemId)
            if start and dur and dur > 1.5 and enable == 1 then
                local rem = (start + dur) - GetTime()
                if rem > 1 then result = rem end
            end
        end
    end)
    if result > 0 then return result end

    -- Approach 4: C_Container.GetItemCooldown (newer API)
    pcall(function()
        if C_Container and C_Container.GetItemCooldown then
            local start, dur, enable = C_Container.GetItemCooldown(itemId)
            if start and dur and dur > 1.5 and enable == 1 then
                local rem = (start + dur) - GetTime()
                if rem > 1 then result = rem end
            end
        end
    end)

    return result
end

local function FormatCooldown(sec)
    if sec >= 3600 then
        return string.format("%dh %dm", math.floor(sec / 3600), math.floor((sec % 3600) / 60))
    elseif sec >= 60 then
        return string.format("%dm %ds", math.floor(sec / 60), math.floor(sec % 60))
    else
        return string.format("%ds", math.floor(sec))
    end
end

-- Cached toy list
local toyCache = {}
local lastRefresh = 0

-- ============================================================
-- Toy data helpers
-- ============================================================
local function RefreshToyCache()
    local now = GetTime()
    if now - lastRefresh < 1 and #toyCache > 0 then return end
    lastRefresh = now

    toyCache = {}
    local numToys = C_ToyBox.GetNumTotalDisplayedToys()
    for i = 1, numToys do
        local itemID = C_ToyBox.GetToyFromIndex(i)
        if itemID and itemID > 0 then
            local id, name, icon, isFav, hasFanfare, quality = C_ToyBox.GetToyInfo(itemID)
            if id and PlayerHasToy(id) then
                local usable = C_ToyBox.IsToyUsable(id)
                toyCache[#toyCache + 1] = {
                    id = id,
                    name = name or ("Toy #" .. id),
                    icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                    isFav = isFav or false,
                    usable = usable,
                    quality = quality or 1,
                }
            end
        end
    end

    -- Sort: favorites first, then alphabetical
    table.sort(toyCache, function(a, b)
        if a.isFav ~= b.isFav then return a.isFav end
        return a.name < b.name
    end)
end

local function FilteredToys()
    local out = {}
    local query = searchText:lower()
    for _, t in ipairs(toyCache) do
        local match = true
        if currentFilter == "fav" and not t.isFav then match = false end
        if currentFilter == "usable" and not t.usable then match = false end
        if query ~= "" and not t.name:lower():find(query, 1, true) then match = false end
        if match then out[#out + 1] = t end
    end
    return out
end

-- ============================================================
-- UI refresh
-- ============================================================
local function UpdateFilterBtns()
    for key, btn in pairs(filterBtns) do
        if key == currentFilter then
            btn.bg:SetVertexColor(0.15, 0.15, 0.2, 1)
            btn.label:SetTextColor(1, 1, 1, 1)
        else
            btn.bg:SetVertexColor(0.08, 0.08, 0.1, 1)
            btn.label:SetTextColor(0.5, 0.5, 0.55, 1)
        end
    end
end

local function RefreshList()
    if not scrollContent then return end
    RefreshToyCache()

    for _, row in ipairs(toyRows) do row:Hide() end

    local filtered = FilteredToys()
    local ROW_H = 28
    local rowIdx = 0

    for _, toy in ipairs(filtered) do
        rowIdx = rowIdx + 1
        local row = toyRows[rowIdx]
        if not row then
            row = CreateFrame("Button", "PhoneToyBtn" .. rowIdx, scrollContent, "SecureActionButtonTemplate")
            row:SetHeight(ROW_H)
            row:RegisterForClicks("AnyDown", "AnyUp")

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(WHITE)
            bg:SetVertexColor(0.10, 0.10, 0.14, 0.6)
            row.bg = bg

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture(WHITE)
            hl:SetVertexColor(0.2, 0.2, 0.2, 0.3)

            local iconTex = row:CreateTexture(nil, "ARTWORK")
            iconTex:SetSize(22, 22)
            iconTex:SetPoint("LEFT", 3, 0)
            iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.iconTex = iconTex

            local nameFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            nameFs:SetPoint("LEFT", iconTex, "RIGHT", 4, 0)
            nameFs:SetPoint("RIGHT", -50, 0)
            nameFs:SetJustifyH("LEFT")
            nameFs:SetWordWrap(false)
            local nf = nameFs:GetFont()
            if nf then nameFs:SetFont(nf, 8, "") end
            row.nameFs = nameFs

            local cdFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            cdFs:SetPoint("RIGHT", -4, 1)
            local cdf = cdFs:GetFont()
            if cdf then cdFs:SetFont(cdf, 7, "") end
            row.cdFs = cdFs

            local favStar = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            favStar:SetPoint("RIGHT", cdFs, "LEFT", -2, 0)
            local sf = favStar:GetFont()
            if sf then favStar:SetFont(sf, 10, "") end
            row.favStar = favStar

            toyRows[rowIdx] = row
        end

        -- Quality color
        local r, g, b = GetItemQualityColor(toy.quality or 1)
        row.nameFs:SetText(string.format("|cff%02x%02x%02x%s|r",
            math.floor((r or 1) * 255), math.floor((g or 1) * 255), math.floor((b or 1) * 255),
            toy.name))

        row.iconTex:SetTexture(toy.icon)
        if toy.usable then
            row.iconTex:SetDesaturated(false)
            row.iconTex:SetVertexColor(1, 1, 1)
            row.bg:SetVertexColor(0.10, 0.10, 0.14, 0.6)
        else
            row.iconTex:SetDesaturated(true)
            row.iconTex:SetVertexColor(0.6, 0.6, 0.6)
            row.bg:SetVertexColor(0.08, 0.08, 0.10, 0.4)
        end

        row.favStar:SetText(toy.isFav and "|cffffff00*|r" or "")

        -- Cooldown display
        local cdRemaining = GetToyCooldown(toy.id)
        if cdRemaining > 0 then
            row.cdFs:SetText("|cffff8800" .. FormatCooldown(cdRemaining) .. "|r")
            row.bg:SetVertexColor(0.25, 0.05, 0.05, 0.7)
        else
            row.cdFs:SetText("")
        end

        -- Store toyId for cooldown ticker
        row.toyId = toy.id

        -- Secure left-click uses the toy via item: attribute
        row:SetAttribute("type", "item")
        row:SetAttribute("item", "item:" .. toy.id)

        -- Right-click toggles favorite (via PostClick, non-secure is fine)
        local toyId = toy.id
        local toyIsFav = toy.isFav
        row:SetScript("PostClick", function(_, button)
            if button == "RightButton" then
                C_ToyBox.SetIsFavorite(toyId, not toyIsFav)
                lastRefresh = 0
                RefreshList()
            end
        end)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -((rowIdx - 1) * ROW_H))
        row:SetPoint("RIGHT", scrollContent, "RIGHT", 0, 0)
        row:Show()
    end

    scrollContent:SetSize(scrollFrame:GetWidth() or 150, math.max(rowIdx * ROW_H, 1))

    -- Update count
    if countFs then
        countFs:SetText("|cff888888" .. #filtered .. "/" .. #toyCache .. " toys|r")
    end
end

-- ============================================================
-- Init
-- ============================================================
function PhoneToysApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local W = parent:GetWidth() or 170

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffcc88ffToys|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Count label
    countFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    countFs:SetPoint("TOP", title, "BOTTOM", 0, -1)
    local cf = countFs:GetFont()
    if cf then countFs:SetFont(cf, 7, "") end
    countFs:SetText("")

    -- Category filter tabs (like Uber)
    local categories = {
        { key = "all",    label = "All" },
        { key = "fav",    label = "Favs" },
        { key = "usable", label = "Usable" },
    }

    local catY = -22
    local catH = 16
    local catW = math.floor((W - 12) / #categories)

    for ci, cat in ipairs(categories) do
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(catW - 2, catH)
        btn:SetPoint("TOPLEFT", 4 + (ci - 1) * catW, catY)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(WHITE)
        bg:SetVertexColor(0.08, 0.08, 0.1, 1)
        btn.bg = bg

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(WHITE)
        hl:SetVertexColor(0.2, 0.2, 0.25, 0.3)

        local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("CENTER")
        label:SetText(cat.label)
        local lf = label:GetFont()
        if lf then label:SetFont(lf, 7, "") end
        btn.label = label

        local key = cat.key
        btn:SetScript("OnClick", function()
            currentFilter = key
            UpdateFilterBtns()
            RefreshList()
        end)

        filterBtns[cat.key] = btn
    end

    UpdateFilterBtns()

    -- Separator
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 4, catY - catH - 2)
    sep:SetPoint("RIGHT", -4, 0)
    sep:SetTexture(WHITE)
    sep:SetVertexColor(0.2, 0.2, 0.25, 0.6)

    -- Search bar
    local searchFrame = CreateFrame("Frame", nil, parent)
    searchFrame:SetPoint("TOPLEFT", 4, catY - catH - 4)
    searchFrame:SetPoint("TOPRIGHT", -4, catY - catH - 4)
    searchFrame:SetHeight(18)

    local searchBg = searchFrame:CreateTexture(nil, "BACKGROUND")
    searchBg:SetAllPoints()
    searchBg:SetTexture(WHITE)
    searchBg:SetVertexColor(0.08, 0.08, 0.10, 0.9)

    searchBar = CreateFrame("EditBox", nil, searchFrame)
    searchBar:SetPoint("TOPLEFT", 4, -2)
    searchBar:SetPoint("BOTTOMRIGHT", -4, 2)
    searchBar:SetAutoFocus(false)
    searchBar:SetFontObject("GameFontNormalSmall")
    local sbf = searchBar:GetFont()
    if sbf then searchBar:SetFont(sbf, 8, "") end
    searchBar:SetTextColor(0.9, 0.9, 0.9)
    searchBar:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        RefreshList()
    end)
    searchBar:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBar:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local placeholder = searchFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    placeholder:SetPoint("LEFT", 4, 0)
    placeholder:SetText("|cff555555Search toys...|r")
    local pf = placeholder:GetFont()
    if pf then placeholder:SetFont(pf, 8, "") end

    searchBar:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    searchBar:SetScript("OnEditFocusLost", function()
        if searchBar:GetText() == "" then placeholder:Show() end
    end)

    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", nil, parent)
    scrollFrame:SetPoint("TOP", searchFrame, "BOTTOM", 0, -2)
    scrollFrame:SetPoint("LEFT", 2, 0)
    scrollFrame:SetPoint("RIGHT", -2, 0)
    scrollFrame:SetPoint("BOTTOM", 0, 4)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, scrollContent:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxS, math.max(0, cur - delta * 40)))
    end)
end

-- Lightweight cooldown-only update (no full rebuild)
local function UpdateCooldowns()
    for _, row in ipairs(toyRows) do
        if row:IsShown() and row.toyId then
            local cdRemaining = GetToyCooldown(row.toyId)
            if cdRemaining > 0 then
                row.cdFs:SetText("|cffff8800" .. FormatCooldown(cdRemaining) .. "|r")
                row.bg:SetVertexColor(0.25, 0.05, 0.05, 0.7)
            else
                row.cdFs:SetText("")
                row.bg:SetVertexColor(0.10, 0.10, 0.14, 0.6)
            end
        end
    end
end

function PhoneToysApp:OnShow()
    visible = true
    -- Clear filters from ToyBox so we see all toys
    pcall(function()
        C_ToyBox.SetAllSourceTypeFilters(true)
        C_ToyBox.SetFilterString("")
        C_ToyBox.SetCollectedShown(true)
        C_ToyBox.SetUncollectedShown(false)
    end)
    lastRefresh = 0 -- force refresh on show
    RefreshList()
    -- Tick cooldowns every second
    if cdTicker then cdTicker:Cancel() end
    cdTicker = C_Timer.NewTicker(1, function()
        if visible then UpdateCooldowns() end
    end)
end

function PhoneToysApp:OnHide()
    visible = false
    if cdTicker then cdTicker:Cancel(); cdTicker = nil end
end
