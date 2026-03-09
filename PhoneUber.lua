-- PhoneUber - Mount summoning & Teleport app (Uber-style) for HearthPhone

PhoneUberApp = {}

local parent
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROW_H = 28

-- ============================================================
-- MOUNTS
-- ============================================================
local mountList = {}
local filteredMounts = {}
local selectedMount = nil
local currentFilter = "all"
local searchText = ""

local mountScroll, mountContent, mountButtons = nil, nil, {}
local summonBtn, summonLabel
local selectedNameFs, selectedIconTex, etaFs
local filterBtns = {}
local searchBox

local GROUND_TYPES = { [230] = true, [241] = true, [284] = true }
local FLYING_TYPES = { [248] = true }
local AQUATIC_TYPES = { [254] = true, [269] = true }

local function LoadMounts()
    wipe(mountList)
    local ids = C_MountJournal.GetMountIDs()
    for _, id in ipairs(ids) do
        local name, spellID, icon, isActive, isUsable, sourceType, isFavorite,
              isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID =
              C_MountJournal.GetMountInfoByID(id)
        if isCollected and not shouldHideOnChar then
            local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(id)
            table.insert(mountList, {
                id = mountID,
                name = name,
                icon = icon,
                isFavorite = isFavorite,
                isUsable = isUsable,
                mountType = mountTypeID or 230,
            })
        end
    end
    table.sort(mountList, function(a, b) return a.name < b.name end)
end

local function FilterMounts()
    wipe(filteredMounts)
    local search = searchText:lower()
    for _, m in ipairs(mountList) do
        local pass = true
        if currentFilter == "ground" then
            pass = GROUND_TYPES[m.mountType] or false
        elseif currentFilter == "flying" then
            pass = FLYING_TYPES[m.mountType] or false
        elseif currentFilter == "aquatic" then
            pass = AQUATIC_TYPES[m.mountType] or false
        elseif currentFilter == "favorites" then
            pass = m.isFavorite
        end
        if pass and search ~= "" then
            pass = m.name:lower():find(search, 1, true) ~= nil
        end
        if pass then
            table.insert(filteredMounts, m)
        end
    end
end

local BuildMountList, UpdateSelection, UpdateFilterBtns

local flavorTexts = {
    "Arriving now...",
    "Your ride is here!",
    "Saddling up...",
    "En route to you!",
    "Mount inbound!",
    "Ride confirmed!",
}

UpdateSelection = function()
    if selectedMount then
        selectedNameFs:SetText("|cffffffff" .. selectedMount.name .. "|r")
        selectedIconTex:SetTexture(selectedMount.icon)
        selectedIconTex:Show()
        summonLabel:SetText("|cffffffff" .. "Request " .. selectedMount.name .. "|r")
        etaFs:SetText("")
    else
        selectedNameFs:SetText("|cff888888Select a mount|r")
        selectedIconTex:Hide()
        summonLabel:SetText("|cffffffffRequest Ride|r")
        etaFs:SetText("")
    end
    for _, btn in ipairs(mountButtons) do
        if btn:IsShown() and btn.mountData then
            if selectedMount and btn.mountData.id == selectedMount.id then
                btn.bg:SetVertexColor(0.12, 0.12, 0.18, 1)
                btn.border:Show()
            else
                btn.bg:SetVertexColor(0.08, 0.08, 0.1, 1)
                btn.border:Hide()
            end
        end
    end
end

UpdateFilterBtns = function()
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

BuildMountList = function()
    for _, btn in ipairs(mountButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(mountButtons)

    FilterMounts()

    local listW = mountScroll:GetWidth()
    if not listW or listW < 10 then listW = 160 end

    for i, m in ipairs(filteredMounts) do
        local btn = CreateFrame("Button", nil, mountContent)
        btn:SetHeight(ROW_H)
        btn:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_H))
        btn:SetPoint("RIGHT", mountContent, "RIGHT", 0, 0)
        btn.mountData = m

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(WHITE)
        bg:SetVertexColor(0.08, 0.08, 0.1, 1)
        btn.bg = bg

        local border = btn:CreateTexture(nil, "BORDER")
        border:SetSize(2, ROW_H)
        border:SetPoint("LEFT", 0, 0)
        border:SetTexture(WHITE)
        border:SetVertexColor(1, 1, 1, 1)
        border:Hide()
        btn.border = border

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(WHITE)
        hl:SetVertexColor(0.15, 0.15, 0.2, 0.4)

        local ico = btn:CreateTexture(nil, "ARTWORK")
        ico:SetSize(20, 20)
        ico:SetPoint("LEFT", 6, 0)
        ico:SetTexture(m.icon)
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local nameFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        nameFs:SetPoint("LEFT", ico, "RIGHT", 6, 0)
        nameFs:SetPoint("RIGHT", -4, 0)
        nameFs:SetJustifyH("LEFT")
        local nameColor = m.isUsable ~= false and "cccccc" or "555555"
        nameFs:SetText("|cff" .. nameColor .. m.name .. "|r")
        local nf = nameFs:GetFont()
        if nf then nameFs:SetFont(nf, 8, "") end

        if m.isFavorite then
            local star = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            star:SetPoint("RIGHT", -4, 0)
            star:SetText("|cfff0c040*|r")
            local sf = star:GetFont()
            if sf then star:SetFont(sf, 9, "OUTLINE") end
        end

        btn:SetScript("OnClick", function()
            selectedMount = m
            UpdateSelection()
        end)

        mountButtons[i] = btn
    end

    mountContent:SetSize(listW, #filteredMounts * ROW_H)
    mountScroll:SetVerticalScroll(0)
    UpdateSelection()
end

local function DoSummon()
    if selectedMount then
        C_MountJournal.SummonByID(selectedMount.id)
        etaFs:SetText("|cff888888" .. flavorTexts[math.random(#flavorTexts)] .. "|r")
    else
        C_MountJournal.SummonByID(0)
        etaFs:SetText("|cff888888Finding you a ride...|r")
    end
end

-- ============================================================
-- TELEPORTS
-- ============================================================
-- Hearthstone toy IDs (from TeleportMenu)
local hearthstoneToys = {
    54452, 64488, 93672, 142542, 162973, 163045, 163206, 165669,
    165670, 165802, 166746, 166747, 168907, 172179, 180290, 182773,
    183716, 184353, 188952, 190196, 190237, 193588, 200630, 206195,
    208704, 209035, 212337, 228940, 236687, 235016, 245970, 246565,
    257736, 263489, 265100,
}

-- Item teleports (non-toy items in bags)
local itemTeleportIds = {
    6948,   -- Hearthstone
    141605, -- Flight Master's Whistle
    32757,  -- Blessed Medallion of Karabor
    37863,  -- Direbrew's Remote
    40586, 44935, 40585, 44934, -- Kirin Tor rings
    45688, 45690, 45691, 45689,
    48954, 48955, 48956, 48957,
    51557, 51558, 51559, 51560,
    52251,  -- Jaina's Locket
    46874,  -- Argent Crusader's Tabard
    50287,  -- Boots of the Bay
    63206, 63207, -- Wraps of Unity
    63352, 63353, -- Shroud of Cooperation
    65274, 65360, -- Cloak of Coordination
    139599, -- Empowered Ring of the Kirin Tor
}

-- Toy teleports (non-hearthstone toys that teleport)
local toyTeleportIds = {
    64488,  -- The Innkeeper's Daughter (also hearthstone)
    103678, -- Time-Lost Artifact
    117389, -- Draenor Archaeologist's Lodestone
    128353, -- Admiral's Compass
    136849, -- Nature's Beacon
    140324, -- Mobile Telemancy Beacon
    142298, -- Astonishingly Scarlet Slippers
    142469, -- Violet Seal of the Grand Magus
}

-- Wormhole generators (engineering toys)
local wormholeIds = {
    30542,  -- Dimensional Ripper - Area 52
    18984,  -- Dimensional Ripper - Everlook
    18986,  -- Ultrasafe Transporter: Gadgetzan
    30544,  -- Ultrasafe Transporter: Toshley's Station
    48933,  -- Wormhole Generator: Northrend
    87215,  -- Wormhole Generator: Pandaria
    112059, -- Wormhole Centrifuge
    151652, -- Wormhole Generator: Argus
    167075, -- Ultrasafe Transporter: Mechagon
    168807, -- Wormhole Generator: Kul Tiras
    168808, -- Wormhole Generator: Zandalar
    172924, -- Wormhole Generator: Shadowlands
    198156, -- Wyrmhole Generator: Dragon Isles
    221966, -- Wormhole Generator: Khaz Algar
    248485, -- Wormhole Generator: Quel'Thalas
}

-- Class/racial spell teleports (non-mage, checked by IsSpellKnown)
local spellTeleports = {
    -- Class
    { id = 556,    spell = "Astral Recall",       class = "SHAMAN" },
    { id = 126892, spell = "Zen Pilgrimage",      class = "MONK" },
    { id = 193753, spell = "Dreamwalk",           class = "DRUID" },
    { id = 50977,  spell = "Death Gate",          class = "DEATHKNIGHT" },
    { id = 18960,  spell = "Teleport: Moonglade", class = "DRUID" },
    -- Racial
    { id = 265225, spell = "Mole Machine",    race = "DarkIronDwarf" },
    { id = 312372, spell = "Return to Camp",  race = "Vulpera" },
    { id = 1238686, spell = "Rootwalking",    race = "Haranir" },
}

-- Mage teleport/portal flyouts (read dynamically like Hero's Path)
local mageFlyouts = {
    { flyoutId = 8,  cat = "mage_tp",     label = "Mage Teleports" },  -- Teleport (Alliance)
    { flyoutId = 1,  cat = "mage_tp",     label = "Mage Teleports" },  -- Teleport (Horde)
    { flyoutId = 12, cat = "mage_portal", label = "Mage Portals" },    -- Portal (Alliance)
    { flyoutId = 11, cat = "mage_portal", label = "Mage Portals" },    -- Portal (Horde)
}

-- Hero's Path flyouts: { flyoutId, categoryKey, label }
-- These are read dynamically via GetFlyoutInfo / GetFlyoutSlotInfo
local heroPathFlyouts = {
    { flyoutId = 230, cat = "dg_cata",      label = "Cataclysm" },
    { flyoutId = 84,  cat = "dg_mop",       label = "Mists of Pandaria" },
    { flyoutId = 96,  cat = "dg_wod",       label = "Warlords of Draenor" },
    { flyoutId = 224, cat = "dg_legion",     label = "Legion" },
    { flyoutId = 223, cat = "dg_bfa",       label = "Battle for Azeroth" },
    { flyoutId = 220, cat = "dg_sl",        label = "Shadowlands" },
    { flyoutId = 222, cat = "dg_sl_raid",   label = "Shadowlands Raids" },
    { flyoutId = 227, cat = "dg_df",        label = "Dragonflight" },
    { flyoutId = 231, cat = "dg_df_raid",   label = "Dragonflight Raids" },
    { flyoutId = 232, cat = "dg_tww",       label = "The War Within" },
    { flyoutId = 242, cat = "dg_tww_raid",  label = "The War Within Raids" },
    { flyoutId = 246, cat = "dg_midnight",   label = "Midnight" },
}

-- Current M+ season portals (spells not in flyouts yet, from TeleportMenu seasonal data)
local seasonalPortalSpells = {
    -- TWW S2
    { id = 467553, faction = "Alliance" }, -- The MOTHERLODE!!
    { id = 467555, faction = "Horde" },    -- The MOTHERLODE!!
    { id = 373274 }, -- Operation: Mechagon - Workshop
    { id = 354467 }, -- Theater of Pain
    { id = 445444 }, -- Priory of the Sacred Flame
    { id = 445443 }, -- The Rookery
    { id = 445441 }, -- Darkflame Cleft
    { id = 445440 }, -- Cinderbrew Meadery
    { id = 1216786 }, -- Operation: Floodgate
    -- TWW S3
    { id = 1237215 }, -- Eco-Dome Al'dani
    { id = 354465 },  -- Halls of Atonement
    { id = 445417 },  -- Ara-Kara, City of Echoes
    { id = 367416 },  -- Tazavesh: So'leah's Gambit
    { id = 445414 },  -- The Dawnbreaker
    -- Midnight S1
    { id = 1254557 }, -- Skyreach
    { id = 393273 },  -- Algeth'ar Academy
    { id = 1254555 }, -- Pit of Saron
    { id = 1254400 }, -- Windrunner Spire
    { id = 1254572 }, -- Magisters' Terrace
    { id = 1254563 }, -- Nexus-Point Xenas
    { id = 1254559 }, -- Maisara Caverns
    { id = 1254551 }, -- Seat of the Triumvirate
}

-- Each entry: { name, icon, actionType, actionValue, category }
local allTeleports = {}
local displayList = {}
local teleportScroll, teleportContent, teleportButtons = nil, nil, {}
local currentTPFilter = "all"
local tpFilterBtns = {}

local function GetItemInfo_Safe(id)
    local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
    if not name then
        C_Item.RequestLoadItemDataByID(id)
    end
    return name, icon
end

local function LoadTeleports()
    wipe(allTeleports)
    local _, playerClass = UnitClass("player")
    local _, playerRace = UnitRace("player")
    local playerFaction = UnitFactionGroup("player")
    local IsSpellKnown = C_SpellBook.IsSpellKnown
    local added = {}

    local function addEntry(entry, cat)
        entry.category = cat
        table.insert(allTeleports, entry)
    end

    -- ---- Hearthstones ----
    if C_Item.GetItemCount(6948) > 0 then
        local name, icon = GetItemInfo_Safe(6948)
        addEntry({
            name = name or "Hearthstone",
            icon = icon or 134414,
            actionType = "item",
            actionValue = "item:6948",
        }, "hearth")
        added[6948] = true
    end

    for _, toyId in ipairs(hearthstoneToys) do
        if not added[toyId] and PlayerHasToy(toyId) and C_ToyBox.IsToyUsable(toyId) then
            local _, toyName, toyIcon = C_ToyBox.GetToyInfo(toyId)
            if toyName then
                addEntry({ name = toyName, icon = toyIcon or 134414, actionType = "item", actionValue = "item:" .. toyId }, "hearth")
                added[toyId] = true
            end
        end
    end

    -- ---- Class & Racial ----
    for _, def in ipairs(spellTeleports) do
        local pass = true
        if def.class and def.class ~= playerClass then pass = false end
        if def.faction and def.faction ~= playerFaction then pass = false end
        if def.race and playerRace ~= def.race then pass = false end
        if pass and IsSpellKnown(def.id) then
            local spellInfo = C_Spell.GetSpellInfo(def.id)
            if spellInfo then
                addEntry({ name = spellInfo.name or def.spell, icon = spellInfo.iconID or 136235, actionType = "spell", actionValue = def.spell }, "class")
            end
        end
    end

    -- ---- Mage Teleports & Portals (flyout-based) ----
    for _, mf in ipairs(mageFlyouts) do
        local _, _, numSlots, flyoutKnown = GetFlyoutInfo(mf.flyoutId)
        if flyoutKnown and numSlots and numSlots > 0 then
            for i = 1, numSlots do
                local spellId = select(1, GetFlyoutSlotInfo(mf.flyoutId, i))
                if spellId and IsSpellKnown(spellId) then
                    local spellInfo = C_Spell.GetSpellInfo(spellId)
                    if spellInfo then
                        addEntry({ name = spellInfo.name, icon = spellInfo.iconID or 237509, actionType = "spell", actionValue = spellInfo.name }, mf.cat)
                    end
                end
            end
        end
    end

    -- ---- Dungeon Portals (Hero's Path flyouts, grouped by expansion) ----
    local flyoutSpellsSeen = {}
    for _, hp in ipairs(heroPathFlyouts) do
        local _, _, numSlots, flyoutKnown = GetFlyoutInfo(hp.flyoutId)
        if flyoutKnown and numSlots and numSlots > 0 then
            for i = 1, numSlots do
                local spellId = select(1, GetFlyoutSlotInfo(hp.flyoutId, i))
                if spellId and IsSpellKnown(spellId) and not flyoutSpellsSeen[spellId] then
                    flyoutSpellsSeen[spellId] = true
                    local spellInfo = C_Spell.GetSpellInfo(spellId)
                    if spellInfo then
                        addEntry({ name = spellInfo.name, icon = spellInfo.iconID or 136235, actionType = "spell", actionValue = spellInfo.name }, hp.cat)
                    end
                end
            end
        end
    end

    -- ---- Seasonal M+ Portals (current season, not yet in flyouts) ----
    for _, portal in ipairs(seasonalPortalSpells) do
        if not portal.faction or portal.faction == playerFaction then
            if IsSpellKnown(portal.id) and not flyoutSpellsSeen[portal.id] then
                local spellInfo = C_Spell.GetSpellInfo(portal.id)
                if spellInfo then
                    addEntry({ name = spellInfo.name, icon = spellInfo.iconID or 136235, actionType = "spell", actionValue = spellInfo.name }, "dg_season")
                end
            end
        end
    end

    -- ---- Items & Toys ----
    for _, itemId in ipairs(itemTeleportIds) do
        if not added[itemId] then
            local isToy = C_ToyBox.GetToyInfo(itemId) ~= nil
            local hasToy = isToy and PlayerHasToy(itemId)
            local hasItem = (C_Item.GetItemCount(itemId) or 0) > 0
            if isToy and hasToy then
                if C_ToyBox.IsToyUsable(itemId) then
                    local _, n, ic = C_ToyBox.GetToyInfo(itemId)
                    if n then
                        addEntry({ name = n, icon = ic or 134400, actionType = "item", actionValue = "item:" .. itemId }, "items")
                        added[itemId] = true
                    end
                end
            elseif hasItem then
                local name, icon = GetItemInfo_Safe(itemId)
                if name then
                    addEntry({ name = name, icon = icon or 134400, actionType = "item", actionValue = "item:" .. itemId }, "items")
                    added[itemId] = true
                end
            end
        end
    end

    for _, toyId in ipairs(toyTeleportIds) do
        if not added[toyId] and PlayerHasToy(toyId) and C_ToyBox.IsToyUsable(toyId) then
            local _, toyName, toyIcon = C_ToyBox.GetToyInfo(toyId)
            if toyName then
                addEntry({ name = toyName, icon = toyIcon or 134400, actionType = "item", actionValue = "item:" .. toyId }, "items")
                added[toyId] = true
            end
        end
    end

    -- ---- Engineering Wormholes ----
    for _, toyId in ipairs(wormholeIds) do
        if not added[toyId] and PlayerHasToy(toyId) and C_ToyBox.IsToyUsable(toyId) then
            local _, toyName, toyIcon = C_ToyBox.GetToyInfo(toyId)
            if toyName then
                addEntry({ name = toyName, icon = toyIcon or 134065, actionType = "item", actionValue = "item:" .. toyId }, "engi")
                added[toyId] = true
            end
        end
    end
end

-- Category display order and labels
-- Dungeon subcategories use dg_ prefix; the "dungeon" filter matches all of them
local categoryOrder = {
    "hearth", "class", "mage_tp", "mage_portal",
    "dg_season", "dg_midnight",
    "dg_tww_raid", "dg_tww",
    "dg_df_raid", "dg_df",
    "dg_sl_raid", "dg_sl",
    "dg_bfa", "dg_legion", "dg_wod", "dg_mop", "dg_cata",
    "items", "engi",
}
local categoryLabels = {
    hearth       = "Hearthstones",
    class        = "Class & Racial",
    mage_tp      = "Mage Teleports",
    mage_portal  = "Mage Portals",
    dg_season    = "Current Season",
    dg_midnight  = "Midnight",
    dg_tww_raid  = "The War Within Raids",
    dg_tww       = "The War Within",
    dg_df_raid   = "Dragonflight Raids",
    dg_df        = "Dragonflight",
    dg_sl_raid   = "Shadowlands Raids",
    dg_sl        = "Shadowlands",
    dg_bfa       = "Battle for Azeroth",
    dg_legion    = "Legion",
    dg_wod       = "Warlords of Draenor",
    dg_mop       = "Mists of Pandaria",
    dg_cata      = "Cataclysm",
    items        = "Items & Toys",
    engi         = "Engineering",
}

-- Which top-level filter each category belongs to
local function GetFilterGroup(cat)
    if cat:sub(1, 3) == "dg_" then return "dungeon" end
    if cat:sub(1, 5) == "mage_" then return "class" end
    return cat
end

local function FilterTeleports()
    wipe(displayList)
    local buckets = {}
    for _, cat in ipairs(categoryOrder) do buckets[cat] = {} end

    for _, entry in ipairs(allTeleports) do
        local filterGroup = GetFilterGroup(entry.category)
        if currentTPFilter == "all" or filterGroup == currentTPFilter or entry.category == currentTPFilter then
            local bucket = buckets[entry.category]
            if bucket then
                table.insert(bucket, entry)
            end
        end
    end

    for _, cat in ipairs(categoryOrder) do
        local bucket = buckets[cat]
        if #bucket > 0 then
            table.sort(bucket, function(a, b) return a.name < b.name end)
            table.insert(displayList, { isHeader = true, label = categoryLabels[cat] })
            for _, e in ipairs(bucket) do table.insert(displayList, e) end
        end
    end
end

local function UpdateTPFilterBtns()
    for key, btn in pairs(tpFilterBtns) do
        if key == currentTPFilter then
            btn.bg:SetVertexColor(0.15, 0.15, 0.2, 1)
            btn.label:SetTextColor(1, 1, 1, 1)
        else
            btn.bg:SetVertexColor(0.08, 0.08, 0.1, 1)
            btn.label:SetTextColor(0.5, 0.5, 0.55, 1)
        end
    end
end

local BuildTeleportList

local HEADER_H = 18

local teleportHeaderPool = {}
local function GetOrCreateHeader(index, parentFrame)
    local hdr = teleportHeaderPool[index]
    if not hdr then
        hdr = CreateFrame("Frame", nil, parentFrame)
        hdr:SetHeight(HEADER_H)

        local bg = hdr:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(WHITE)
        bg:SetVertexColor(0.1, 0.1, 0.13, 1)
        hdr.bg = bg

        local label = hdr:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("LEFT", 6, 0)
        label:SetJustifyH("LEFT")
        hdr.label = label
        local lf = label:GetFont()
        if lf then label:SetFont(lf, 7, "OUTLINE") end

        teleportHeaderPool[index] = hdr
    end
    return hdr
end

BuildTeleportList = function()
    -- Hide all existing elements
    for _, btn in ipairs(teleportButtons) do btn:Hide() end
    for _, hdr in ipairs(teleportHeaderPool) do hdr:Hide() end

    local listW = teleportScroll:GetWidth()
    if not listW or listW < 10 then listW = 160 end

    local yOffset = 0
    local btnIndex = 0
    local hdrIndex = 0

    for _, entry in ipairs(displayList) do
        if entry.isHeader then
            hdrIndex = hdrIndex + 1
            local hdr = GetOrCreateHeader(hdrIndex, teleportContent)
            hdr:ClearAllPoints()
            hdr:SetPoint("TOPLEFT", 0, -yOffset)
            hdr:SetPoint("RIGHT", teleportContent, "RIGHT", 0, 0)
            hdr.label:SetText("|cff888888" .. entry.label .. "|r")
            hdr:Show()
            yOffset = yOffset + HEADER_H
        else
            btnIndex = btnIndex + 1
            local btn = teleportButtons[btnIndex]
            if not btn then
                btn = CreateFrame("Button", "PhoneUberTP" .. btnIndex, teleportContent, "SecureActionButtonTemplate")
                btn:SetHeight(ROW_H)
                btn:RegisterForClicks("AnyDown", "AnyUp")

                local bg = btn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetTexture(WHITE)
                bg:SetVertexColor(0.08, 0.08, 0.1, 1)
                btn.bg = bg

                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetTexture(WHITE)
                hl:SetVertexColor(0.15, 0.15, 0.2, 0.4)

                local ico = btn:CreateTexture(nil, "ARTWORK")
                ico:SetSize(20, 20)
                ico:SetPoint("LEFT", 6, 0)
                ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                btn.ico = ico

                local nameFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                nameFs:SetPoint("LEFT", ico, "RIGHT", 6, 0)
                nameFs:SetPoint("RIGHT", -4, 0)
                nameFs:SetJustifyH("LEFT")
                btn.nameFs = nameFs
                local nf = nameFs:GetFont()
                if nf then nameFs:SetFont(nf, 8, "") end

                teleportButtons[btnIndex] = btn
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 0, -yOffset)
            btn:SetPoint("RIGHT", teleportContent, "RIGHT", 0, 0)

            btn.ico:SetTexture(entry.icon)
            btn.nameFs:SetText("|cffcccccc" .. entry.name .. "|r")

            btn:SetAttribute("type", entry.actionType)
            btn:SetAttribute(entry.actionType, entry.actionValue)

            btn:Show()
            yOffset = yOffset + ROW_H
        end
    end

    teleportContent:SetSize(listW, yOffset)
    teleportScroll:SetVerticalScroll(0)
end

-- ============================================================
-- Tab switching
-- ============================================================
local mountView, teleportView
local tabRides, tabTP
local subtitle

local function ShowTab(tab)
    currentTab = tab
    if tab == "mounts" then
        mountView:Show()
        teleportView:Hide()
        tabRides.bg:SetVertexColor(0.15, 0.15, 0.2, 1)
        tabRides.label:SetTextColor(1, 1, 1, 1)
        tabTP.bg:SetVertexColor(0.08, 0.08, 0.1, 1)
        tabTP.label:SetTextColor(0.5, 0.5, 0.55, 1)
        subtitle:SetText("|cff888888Mount Service|r")
    else
        mountView:Hide()
        teleportView:Show()
        tabTP.bg:SetVertexColor(0.15, 0.15, 0.2, 1)
        tabTP.label:SetTextColor(1, 1, 1, 1)
        tabRides.bg:SetVertexColor(0.08, 0.08, 0.1, 1)
        tabRides.label:SetTextColor(0.5, 0.5, 0.55, 1)
        subtitle:SetText("|cff888888Teleport Service|r")
        LoadTeleports()
        FilterTeleports()
        BuildTeleportList()
    end
end

-- ============================================================
-- Init
-- ============================================================
function PhoneUberApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local W = parent:GetWidth() or 170

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffffffffUber|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 11, "OUTLINE") end

    -- Subtitle
    subtitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -1)
    subtitle:SetText("|cff888888Mount Service|r")
    local stf = subtitle:GetFont()
    if stf then subtitle:SetFont(stf, 7, "") end

    -- Top-level tabs: Rides | Teleport
    local topTabW = math.floor((W - 12) / 2)
    local topTabY = -22

    tabRides = CreateFrame("Button", nil, parent)
    tabRides:SetSize(topTabW - 2, 16)
    tabRides:SetPoint("TOPLEFT", 4, topTabY)

    local trBg = tabRides:CreateTexture(nil, "BACKGROUND")
    trBg:SetAllPoints()
    trBg:SetTexture(WHITE)
    trBg:SetVertexColor(0.15, 0.15, 0.2, 1)
    tabRides.bg = trBg

    local trHl = tabRides:CreateTexture(nil, "HIGHLIGHT")
    trHl:SetAllPoints()
    trHl:SetTexture(WHITE)
    trHl:SetVertexColor(0.2, 0.2, 0.25, 0.3)

    local trLabel = tabRides:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    trLabel:SetPoint("CENTER")
    trLabel:SetText("Rides")
    trLabel:SetTextColor(1, 1, 1, 1)
    local trlf = trLabel:GetFont()
    if trlf then trLabel:SetFont(trlf, 8, "") end
    tabRides.label = trLabel

    tabRides:SetScript("OnClick", function() ShowTab("mounts") end)

    tabTP = CreateFrame("Button", nil, parent)
    tabTP:SetSize(topTabW - 2, 16)
    tabTP:SetPoint("TOPLEFT", 4 + topTabW, topTabY)

    local ttBg = tabTP:CreateTexture(nil, "BACKGROUND")
    ttBg:SetAllPoints()
    ttBg:SetTexture(WHITE)
    ttBg:SetVertexColor(0.08, 0.08, 0.1, 1)
    tabTP.bg = ttBg

    local ttHl = tabTP:CreateTexture(nil, "HIGHLIGHT")
    ttHl:SetAllPoints()
    ttHl:SetTexture(WHITE)
    ttHl:SetVertexColor(0.2, 0.2, 0.25, 0.3)

    local ttLabel = tabTP:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ttLabel:SetPoint("CENTER")
    ttLabel:SetText("Teleport")
    ttLabel:SetTextColor(0.5, 0.5, 0.55, 1)
    local ttlf = ttLabel:GetFont()
    if ttlf then ttLabel:SetFont(ttlf, 8, "") end
    tabTP.label = ttLabel

    tabTP:SetScript("OnClick", function() ShowTab("teleports") end)

    -- =========================================================
    -- Mount view (everything below the top tabs)
    -- =========================================================
    mountView = CreateFrame("Frame", nil, parent)
    mountView:SetPoint("TOPLEFT", 0, topTabY - 18)
    mountView:SetPoint("BOTTOMRIGHT")

    -- Search bar
    searchBox = CreateFrame("EditBox", nil, mountView)
    searchBox:SetSize(W - 16, 16)
    searchBox:SetPoint("TOP", 0, -2)
    searchBox:SetFontObject(GameFontNormalSmall)
    local sbf = searchBox:GetFont()
    if sbf then searchBox:SetFont(sbf, 8, "") end
    searchBox:SetTextColor(1, 1, 1, 1)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(30)

    local searchBg = searchBox:CreateTexture(nil, "BACKGROUND")
    searchBg:SetPoint("TOPLEFT", -4, 4)
    searchBg:SetPoint("BOTTOMRIGHT", 4, -4)
    searchBg:SetTexture(WHITE)
    searchBg:SetVertexColor(0.12, 0.12, 0.15, 1)

    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText("|cff555555Where to?|r")
    local phf = placeholder:GetFont()
    if phf then placeholder:SetFont(phf, 8, "") end

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        searchText = text or ""
        placeholder:SetShown(searchText == "")
        BuildMountList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Category filter tabs
    local categories = {
        { key = "all",       label = "All" },
        { key = "favorites", label = "VIP" },
        { key = "ground",    label = "UberX" },
        { key = "flying",    label = "Air" },
        { key = "aquatic",   label = "Sea" },
    }

    local catY = -22
    local catH = 16
    local catW = math.floor((W - 12) / #categories)

    for ci, cat in ipairs(categories) do
        local btn = CreateFrame("Button", nil, mountView)
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
            BuildMountList()
        end)

        filterBtns[cat.key] = btn
    end

    -- Separator
    local sep = mountView:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 4, catY - catH - 2)
    sep:SetPoint("RIGHT", -4, 0)
    sep:SetTexture(WHITE)
    sep:SetVertexColor(0.2, 0.2, 0.25, 0.6)

    -- Mount list
    local listTop = catY - catH - 4
    mountScroll = CreateFrame("ScrollFrame", nil, mountView)
    mountScroll:SetPoint("TOPLEFT", 2, listTop)
    mountScroll:SetPoint("BOTTOMRIGHT", -2, 60)

    mountContent = CreateFrame("Frame", nil, mountScroll)
    mountContent:SetSize(1, 1)
    mountScroll:SetScrollChild(mountContent)

    mountScroll:EnableMouseWheel(true)
    mountScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = max(0, mountContent:GetHeight() - self:GetHeight())
        local newS = min(maxS, max(0, cur - delta * 40))
        self:SetVerticalScroll(newS)
    end)

    -- Bottom panel
    local bottomPanel = CreateFrame("Frame", nil, mountView)
    bottomPanel:SetHeight(56)
    bottomPanel:SetPoint("BOTTOMLEFT", 0, 0)
    bottomPanel:SetPoint("BOTTOMRIGHT", 0, 0)

    local bottomBg = bottomPanel:CreateTexture(nil, "BACKGROUND")
    bottomBg:SetAllPoints()
    bottomBg:SetTexture(WHITE)
    bottomBg:SetVertexColor(0.06, 0.06, 0.08, 1)

    local bottomSep = bottomPanel:CreateTexture(nil, "ARTWORK")
    bottomSep:SetHeight(1)
    bottomSep:SetPoint("TOPLEFT")
    bottomSep:SetPoint("TOPRIGHT")
    bottomSep:SetTexture(WHITE)
    bottomSep:SetVertexColor(0.2, 0.2, 0.25, 0.6)

    selectedIconTex = bottomPanel:CreateTexture(nil, "ARTWORK")
    selectedIconTex:SetSize(20, 20)
    selectedIconTex:SetPoint("TOPLEFT", 8, -6)
    selectedIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    selectedIconTex:Hide()

    selectedNameFs = bottomPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    selectedNameFs:SetPoint("LEFT", selectedIconTex, "RIGHT", 6, 0)
    selectedNameFs:SetPoint("RIGHT", -8, 0)
    selectedNameFs:SetJustifyH("LEFT")
    selectedNameFs:SetText("|cff888888Select a mount|r")
    local snf = selectedNameFs:GetFont()
    if snf then selectedNameFs:SetFont(snf, 8, "") end

    etaFs = bottomPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    etaFs:SetPoint("TOPLEFT", selectedIconTex, "BOTTOMLEFT", 0, -1)
    etaFs:SetPoint("RIGHT", -8, 0)
    etaFs:SetJustifyH("LEFT")
    local ef = etaFs:GetFont()
    if ef then etaFs:SetFont(ef, 7, "") end

    summonBtn = CreateFrame("Button", nil, bottomPanel)
    summonBtn:SetHeight(20)
    summonBtn:SetPoint("BOTTOMLEFT", 6, 4)
    summonBtn:SetPoint("BOTTOMRIGHT", -6, 4)

    local sumBg = summonBtn:CreateTexture(nil, "BACKGROUND")
    sumBg:SetAllPoints()
    sumBg:SetTexture(WHITE)
    sumBg:SetVertexColor(0.15, 0.15, 0.2, 1)

    local sumHl = summonBtn:CreateTexture(nil, "HIGHLIGHT")
    sumHl:SetAllPoints()
    sumHl:SetTexture(WHITE)
    sumHl:SetVertexColor(0.25, 0.25, 0.3, 0.4)

    summonLabel = summonBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    summonLabel:SetPoint("CENTER")
    summonLabel:SetText("|cffffffffRequest Ride|r")
    local slf = summonLabel:GetFont()
    if slf then summonLabel:SetFont(slf, 9, "OUTLINE") end

    summonBtn:SetScript("OnClick", DoSummon)

    UpdateFilterBtns()

    -- =========================================================
    -- Teleport view
    -- =========================================================
    teleportView = CreateFrame("Frame", nil, parent)
    teleportView:SetPoint("TOPLEFT", 0, topTabY - 18)
    teleportView:SetPoint("BOTTOMRIGHT")
    teleportView:Hide()

    -- Filter tabs
    local tpCategories = {
        { key = "all",     label = "All" },
        { key = "hearth",  label = "Hearth" },
        { key = "class",   label = "Class" },
        { key = "dungeon", label = "M+" },
        { key = "items",   label = "Items" },
        { key = "engi",    label = "Engi" },
    }

    local tpCatH = 16
    local tpCatW = math.floor((W - 12) / #tpCategories)

    for ci, cat in ipairs(tpCategories) do
        local btn = CreateFrame("Button", nil, teleportView)
        btn:SetSize(tpCatW - 2, tpCatH)
        btn:SetPoint("TOPLEFT", 4 + (ci - 1) * tpCatW, -2)

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
            currentTPFilter = key
            UpdateTPFilterBtns()
            FilterTeleports()
            BuildTeleportList()
        end)

        tpFilterBtns[cat.key] = btn
    end

    UpdateTPFilterBtns()

    -- Separator
    local tpSep = teleportView:CreateTexture(nil, "ARTWORK")
    tpSep:SetHeight(1)
    tpSep:SetPoint("TOPLEFT", 4, -2 - tpCatH - 2)
    tpSep:SetPoint("RIGHT", -4, 0)
    tpSep:SetTexture(WHITE)
    tpSep:SetVertexColor(0.2, 0.2, 0.25, 0.6)

    -- Teleport list (scrollable, secure buttons)
    local tpListTop = -2 - tpCatH - 4
    teleportScroll = CreateFrame("ScrollFrame", nil, teleportView)
    teleportScroll:SetPoint("TOPLEFT", 2, tpListTop)
    teleportScroll:SetPoint("BOTTOMRIGHT", -2, 4)

    teleportContent = CreateFrame("Frame", nil, teleportScroll)
    teleportContent:SetSize(1, 1)
    teleportScroll:SetScrollChild(teleportContent)

    teleportScroll:EnableMouseWheel(true)
    teleportScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = max(0, teleportContent:GetHeight() - self:GetHeight())
        local newS = min(maxS, max(0, cur - delta * 40))
        self:SetVerticalScroll(newS)
    end)
end

function PhoneUberApp:OnShow()
    LoadMounts()
    BuildMountList()
end

function PhoneUberApp:OnHide()
end
