-- PhoneMusic - Music player for HearthPhone

PhoneMusicApp = {}

local parent
local isPlaying = false
local currentTrack = 1

local ADDON_NAME = "HearthPhone"
local MUSIC_ADDON_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Music\\"

-- ============================================================
-- ALBUMS (organized by expansion)
-- ============================================================
local albums = {
    {
        -- ============================================================
        -- YOUR CUSTOM TRACKS
        -- Drop .mp3/.ogg files into the Music subfolder
        -- Then use the Add Song button to add them.
        -- ============================================================
        name = "My Music",
        color = "ff6699",
        icon = "+",
        wowIcon = "Interface\\Icons\\INV_Misc_Drum_01",
        tracks = {},
    },
    {
        name = "Classic",
        color = "f0c040",
        icon = "C",
        wowIcon = "Interface\\Icons\\Achievement_Character_Human_Male",
        tracks = {
            { name = "Legends of Azeroth",  fileId = 53223  },  -- login theme
            { name = "Stormwind",           fileId = 53205  },
            { name = "Stormwind (Cata)",    fileId = 441764 },
            { name = "Orgrimmar",           fileId = 53198  },
            { name = "Ironforge",           fileId = 53192  },
            { name = "Darnassus",           fileId = 53184  },
            { name = "Thunder Bluff",       fileId = 53213  },
            { name = "Undercity",           fileId = 53216  },
            { name = "Elwynn Forest",       fileId = 441521 },
            { name = "Ashenvale",           fileId = 441521 },
            { name = "Winterspring",        fileId = 441853 },
            { name = "Barrens",             fileId = 441754 },
            { name = "Tanaris",             fileId = 441776 },
            { name = "Tavern (Alliance)",   fileId = 53748  },
            { name = "Tavern (Horde)",      fileId = 53744  },
            { name = "Tavern (Dwarf)",      fileId = 53739  },
            { name = "Tavern (Pirate)",     fileId = 53762  },
        },
    },
    {
        name = "Burning Crusade",
        color = "1eff00",
        icon = "B",
        wowIcon = "Interface\\Icons\\Achievement_Boss_Illidan",
        tracks = {
            { name = "Lament of Highborne", fileId = 53221  },  -- login/credits
            { name = "Shattrath",           fileId = 53806  },
            { name = "Zangarmarsh",         fileId = 53819  },
            { name = "Nagrand",             fileId = 53585  },
            { name = "Karazhan",            fileId = 53554  },
            { name = "Eversong Woods",      fileId = 53184  },
        },
    },
    {
        name = "Wrath",
        color = "69ccf0",
        icon = "W",
        wowIcon = "Interface\\Icons\\Achievement_Boss_LichKing",
        tracks = {
            { name = "WotLK Login",         fileId = 53567  },
            { name = "Grizzly Hills",       fileId = 165484 },
            { name = "Howling Fjord",        fileId = 116821 },
            { name = "Borean Tundra",       fileId = 53367  },
            { name = "Dragonblight",        fileId = 53439  },
            { name = "Storm Peaks",         fileId = 229953 },
            { name = "Sholazar Basin",      fileId = 229942 },
            { name = "Dalaran",             fileId = 229800 },
            { name = "Icecrown Citadel",    fileId = 349998 },
        },
    },
    {
        name = "Cataclysm",
        color = "ff4400",
        icon = "D",
        wowIcon = "Interface\\Icons\\Achievement_Boss_Madness_of_Deathwing",
        tracks = {
            { name = "Nightsong (Hyjal)",   fileId = 441673 },
            { name = "Deepholm",            fileId = 441576 },
            { name = "Vashj'ir",            fileId = 441838 },
        },
    },
    {
        name = "Mists of Pandaria",
        color = "00ff96",
        icon = "P",
        wowIcon = "Interface\\Icons\\Achievement_Guild_ClassyPanda",
        tracks = {
            { name = "Heart of Pandaria",   fileId = 625753  },  -- login theme
            { name = "Jade Forest",         fileId = 642139  },
            { name = "Vale of Blossoms",    fileId = 642333  },
        },
    },
    {
        name = "Warlords",
        color = "c41f3b",
        icon = "G",
        wowIcon = "Interface\\Icons\\Achievement_Boss_Archimonde_3",
        tracks = {
            { name = "WoD Main Title",      fileId = 1042428 },  -- login theme
            { name = "Frostfire Ridge",     fileId = 936339  },
            { name = "Shadowmoon Valley",   fileId = 936324  },
            { name = "Nagrand (Draenor)",   fileId = 1080422 },
        },
    },
    {
        name = "Legion",
        color = "a335ee",
        icon = "L",
        wowIcon = "Interface\\Icons\\Spell_Fire_FelFlameRing",
        tracks = {
            { name = "Legion Main Title",   fileId = 1496267 },  -- login theme
            { name = "Val'sharah",          fileId = 441664  },
            { name = "Highmountain",        fileId = 1417319 },
            { name = "Suramar",             fileId = 1417380 },
        },
    },
    {
        name = "Battle for Azeroth",
        color = "ff7d0a",
        icon = "A",
        wowIcon = "Interface\\Icons\\INV_HeartOfAzeroth",
        tracks = {
            { name = "Before the Storm",    fileId = 2146580 },  -- login theme
            { name = "BfA Login",           fileId = 2146580 },
            { name = "Drustvar",            fileId = 1780918 },
            { name = "Zuldazar",            fileId = 2143543 },
            { name = "Stormsong Valley",    fileId = 2144121 },
        },
    },
    {
        name = "Shadowlands",
        color = "33ccff",
        icon = "S",
        wowIcon = "Interface\\Icons\\Spell_Animamaw_Buff",
        tracks = {
            { name = "Shadowlands Login",   fileId = 3850553 },  -- login theme
            { name = "Bastion",             fileId = 3853412 },
            { name = "Ardenweald",          fileId = 3853400 },
            { name = "Maldraxxus",          fileId = 3853636 },
            { name = "Revendreth",          fileId = 3853768 },
        },
    },
    {
        name = "Dragonflight",
        color = "3fc7eb",
        icon = "F",
        wowIcon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        tracks = {
            { name = "Dragonflight Login",  fileId = 4880327 },  -- login theme
            { name = "Ohn'ahran Plains",    fileId = 4872472 },
            { name = "Azure Span",          fileId = 4872416 },
        },
    },
    {
        name = "The War Within",
        color = "b0a0ff",
        icon = "T",
        wowIcon = "Interface\\Icons\\Spell_Nature_Web",
        tracks = {
            { name = "TWW Main Title",      fileId = 6075186 },  -- login theme
            { name = "Isle of Dorn",        fileId = 6034326 },
            { name = "Ringing Deeps",       fileId = 6034320 },
            { name = "Azj-Kahet",           fileId = 6065816 },
            { name = "Hallowfall",          fileId = 6055471 },
        },
    },
}

-- Merge saved custom tracks into My Music on load
local myMusicAlbum = albums[1]

-- Build flat playlist from all albums (for prev/next navigation)
local playlist = {}
local trackToAlbum = {}

local function RebuildPlaylist()
    wipe(playlist)
    wipe(trackToAlbum)
    for ai, album in ipairs(albums) do
        for _, t in ipairs(album.tracks) do
            local entry = {
                name = t.name,
                fileId = t.fileId,
                album = album.name,
                albumColor = album.color,
                albumIcon = album.wowIcon,
            }
            if t.custom and t.file then
                entry.custom = true
                entry.addonPath = MUSIC_ADDON_PATH .. t.file
            end
            table.insert(playlist, entry)
            trackToAlbum[#playlist] = ai
        end
    end
end

RebuildPlaylist()

-- Load saved custom tracks after SavedVariables are available
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= ADDON_NAME then return end
    loadFrame:UnregisterEvent("ADDON_LOADED")
    HearthPhoneDB = HearthPhoneDB or {}
    HearthPhoneDB.customMusic = HearthPhoneDB.customMusic or {}
    -- Merge saved tracks into My Music album (avoid duplicates)
    local existing = {}
    for _, t in ipairs(myMusicAlbum.tracks) do
        existing[t.file] = true
    end
    for _, saved in ipairs(HearthPhoneDB.customMusic) do
        if not existing[saved.file] then
            table.insert(myMusicAlbum.tracks, { name = saved.name, file = saved.file, custom = true })
        end
    end
    RebuildPlaylist()
end)

-- Current album filter (nil = show album grid)
local currentAlbumIndex = nil

local trackNameFs, artistFs
local playBtn, prevBtn, nextBtn, shuffleBtn
local progressBg, progressFill
local trackListScroll, trackListContent, trackButtons = nil, nil, {}
local albumView, trackView, backBtn, listLabel
local albumButtons = {}
local artIconTex
local addSongView, addSongInput, addSongStatus, addSongBtn
local playerFrame

-- Forward declarations
local UpdateTrackDisplay, ShowAlbumView, ShowTrackView, BuildTrackList, ShowAddSongView

local currentSoundHandle = nil
local savedMusicVol = nil

local function DoPlay(track)
    if track.custom and track.addonPath then
        -- Mute WoW music volume so zone music is silent, but keep the system on
        savedMusicVol = GetCVar("Sound_MusicVolume")
        SetCVar("Sound_MusicVolume", "0")
        StopMusic()
        -- Play custom track on the Master channel (unaffected by music volume)
        local ok, handle = PlaySoundFile(track.addonPath, "Master")
        if ok then
            currentSoundHandle = handle
            return true
        end
        -- Restore volume if failed
        SetCVar("Sound_MusicVolume", savedMusicVol or "0.5")
        savedMusicVol = nil
        return false
    elseif track.fileId then
        -- Restore music volume if it was muted for a custom track
        if savedMusicVol then
            SetCVar("Sound_MusicVolume", savedMusicVol)
            savedMusicVol = nil
        end
        PlayMusic(track.fileId)
        currentSoundHandle = nil
        return true
    end
    return false
end

local function DoStop()
    StopMusic()
    if currentSoundHandle then
        StopSound(currentSoundHandle)
        currentSoundHandle = nil
    end
    -- Restore music volume if we muted it
    if savedMusicVol then
        SetCVar("Sound_MusicVolume", savedMusicVol)
        savedMusicVol = nil
    end
end

local function PlayTrack(index)
    if index < 1 then index = #playlist end
    if index > #playlist then index = 1 end
    currentTrack = index
    DoStop()
    local track = playlist[currentTrack]
    if track then
        isPlaying = DoPlay(track)
    end
    UpdateTrackDisplay()
end

local function TogglePlay()
    if isPlaying then
        DoStop()
        isPlaying = false
    else
        local track = playlist[currentTrack]
        if track then
            isPlaying = DoPlay(track)
        end
    end
    UpdateTrackDisplay()
end

local function NextTrack()
    PlayTrack(currentTrack + 1)
end

local function PrevTrack()
    PlayTrack(currentTrack - 1)
end

local function ShufflePlay()
    local index = math.random(1, #playlist)
    PlayTrack(index)
end

UpdateTrackDisplay = function()
    local track = playlist[currentTrack]
    if track then
        trackNameFs:SetText("|cffffffff" .. track.name .. "|r")
        artistFs:SetText("|cff" .. (track.albumColor or "888888") .. track.album .. "|r")
        if artIconTex and track.albumIcon then
            artIconTex:SetTexture(track.albumIcon)
        end
    else
        trackNameFs:SetText("|cff888888No track|r")
        artistFs:SetText("")
    end

    if isPlaying then
        playBtn.label:SetText("|cffffffff||  |||r")
    else
        playBtn.label:SetText("|cffffffff>|r")
    end

    for i, btn in ipairs(trackButtons) do
        if btn:IsShown() and btn.playlistIdx then
            local idx = btn.playlistIdx
            if idx == currentTrack then
                btn.bg:SetVertexColor(0.15, 0.22, 0.35, 1)
                btn.nameFs:SetText("|cff1DB954" .. playlist[idx].name .. "|r")
            else
                btn.bg:SetVertexColor(0.1, 0.1, 0.13, 0.8)
                btn.nameFs:SetText("|cffcccccc" .. playlist[idx].name .. "|r")
            end
        end
    end
end

-- Helper: create a control button
local function CreateControlBtn(parentFrame, size)
    local btn = CreateFrame("Button", nil, parentFrame)
    btn:SetSize(size, size)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.18, 0.18, 0.22, 0.9)
    btn.bg = bg

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8x8")
    hl:SetVertexColor(0.3, 0.4, 0.5, 0.3)

    local label = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    btn.label = label

    return btn
end

local ROW_H = 20

BuildTrackList = function(albumIdx)
    -- Clear old buttons
    for _, btn in ipairs(trackButtons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    wipe(trackButtons)

    local album = albums[albumIdx]
    if not album then return end

    -- Find playlist indices for this album's tracks
    local indices = {}
    for pi, t in ipairs(playlist) do
        if t.album == album.name then
            table.insert(indices, pi)
        end
    end

    for row, pi in ipairs(indices) do
        local track = playlist[pi]
        local btn = CreateFrame("Button", nil, trackListContent)
        btn:SetHeight(ROW_H)
        btn:SetPoint("TOPLEFT", 0, -((row - 1) * ROW_H))
        btn:SetPoint("RIGHT", trackListContent, "RIGHT", 0, 0)
        btn.playlistIdx = pi

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.1, 0.1, 0.13, 0.8)
        btn.bg = bg

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(0.2, 0.3, 0.2, 0.3)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", 3, 0)
        if track.albumIcon then
            icon:SetTexture(track.albumIcon)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        local nameFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        nameFs:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        nameFs:SetPoint("RIGHT", -4, 0)
        nameFs:SetJustifyH("LEFT")
        nameFs:SetText("|cffcccccc" .. track.name .. "|r")
        local bnf = nameFs:GetFont()
        if bnf then nameFs:SetFont(bnf, 8, "") end
        btn.nameFs = nameFs

        local idx = pi
        btn:SetScript("OnClick", function() PlayTrack(idx) end)

        trackButtons[row] = btn
    end

    local listW = trackListScroll:GetWidth()
    if not listW or listW < 10 then listW = 160 end
    trackListContent:SetSize(listW, #indices * ROW_H)
    trackListScroll:SetVerticalScroll(0)
    UpdateTrackDisplay()
end

ShowAlbumView = function()
    currentAlbumIndex = nil
    if trackView then trackView:Hide() end
    if addSongView then addSongView:Hide() end
    if playerFrame then playerFrame:Show() end
    if albumView then albumView:Show() end
    if backBtn then backBtn:Hide() end
    if addSongBtn then addSongBtn:Hide() end
    if listLabel then listLabel:Show() end
    if listLabel then listLabel:SetText("|cff888888Albums:|r") end
end

ShowTrackView = function(albumIdx)
    currentAlbumIndex = albumIdx
    if albumView then albumView:Hide() end
    if addSongView then addSongView:Hide() end
    if playerFrame then playerFrame:Show() end
    if trackView then trackView:Show() end
    if backBtn then backBtn:Show() end
    if listLabel then listLabel:Show() end
    if addSongBtn then
        -- Show "+" button only for My Music album
        if albumIdx == 1 then
            addSongBtn:Show()
        else
            addSongBtn:Hide()
        end
    end
    local album = albums[albumIdx]
    if listLabel and album then
        listLabel:SetText("|cff" .. album.color .. album.name .. "|r")
    end
    BuildTrackList(albumIdx)
end

ShowAddSongView = function()
    if trackView then trackView:Hide() end
    if albumView then albumView:Hide() end
    if playerFrame then playerFrame:Hide() end
    if backBtn then backBtn:Hide() end
    if listLabel then listLabel:Hide() end
    if addSongBtn then addSongBtn:Hide() end
    if addSongView then addSongView:Show() end
    if addSongInput then
        addSongInput:SetText("")
        addSongInput:SetFocus()
    end
    if addSongStatus then addSongStatus:SetText("|cff888888Enter the song name (no extension needed).|r") end
end

function PhoneMusicApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local W = parent:GetWidth() or 170

    -- Player area (hidden when Add Song view is shown)
    playerFrame = CreateFrame("Frame", nil, parent)
    playerFrame:SetPoint("TOPLEFT")
    playerFrame:SetPoint("TOPRIGHT")
    playerFrame:SetHeight(168)

    -- Title
    local title = playerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cff1DB954Music|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- "Album art" area
    local artFrame = CreateFrame("Frame", nil, playerFrame)
    artFrame:SetSize(60, 60)
    artFrame:SetPoint("TOP", 0, -16)

    local artBg = artFrame:CreateTexture(nil, "BACKGROUND")
    artBg:SetAllPoints()
    artBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    artBg:SetVertexColor(0.1, 0.12, 0.15, 1)

    artIconTex = artFrame:CreateTexture(nil, "ARTWORK")
    artIconTex:SetSize(50, 50)
    artIconTex:SetPoint("CENTER")
    artIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    artIconTex:SetTexture("Interface\\Icons\\INV_Misc_Drum_01")

    -- Track name
    trackNameFs = playerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    trackNameFs:SetPoint("TOP", artFrame, "BOTTOM", 0, -4)
    trackNameFs:SetWidth(W - 12)
    trackNameFs:SetJustifyH("CENTER")
    local tnf = trackNameFs:GetFont()
    if tnf then trackNameFs:SetFont(tnf, 9, "OUTLINE") end

    -- Artist / album name
    artistFs = playerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    artistFs:SetPoint("TOP", trackNameFs, "BOTTOM", 0, -1)
    local af = artistFs:GetFont()
    if af then artistFs:SetFont(af, 8, "") end

    -- Progress bar
    progressBg = playerFrame:CreateTexture(nil, "BACKGROUND")
    progressBg:SetPoint("TOPLEFT", artistFs, "BOTTOMLEFT", -35, -6)
    progressBg:SetPoint("TOPRIGHT", artistFs, "BOTTOMRIGHT", 35, -6)
    progressBg:SetHeight(2)
    progressBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    progressBg:SetVertexColor(0.2, 0.2, 0.25, 0.8)

    progressFill = playerFrame:CreateTexture(nil, "ARTWORK")
    progressFill:SetPoint("TOPLEFT", progressBg)
    progressFill:SetHeight(2)
    progressFill:SetWidth(1)
    progressFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    progressFill:SetVertexColor(0.11, 0.73, 0.33, 1)

    -- Control buttons
    local controlAnchor = CreateFrame("Frame", nil, playerFrame)
    controlAnchor:SetSize(1, 1)
    controlAnchor:SetPoint("TOP", progressBg, "BOTTOM", 0, -16)

    prevBtn = CreateControlBtn(playerFrame, 24)
    prevBtn:SetPoint("RIGHT", controlAnchor, "LEFT", -18, 0)
    prevBtn.label:SetText("|cffffffff<<|r")
    local pvf = prevBtn.label:GetFont()
    if pvf then prevBtn.label:SetFont(pvf, 9, "OUTLINE") end
    prevBtn:SetScript("OnClick", PrevTrack)

    playBtn = CreateControlBtn(playerFrame, 30)
    playBtn:SetPoint("CENTER", controlAnchor)
    playBtn.label:SetText("|cffffffff>|r")
    playBtn.bg:SetVertexColor(0.11, 0.73, 0.33, 0.9)
    local plf = playBtn.label:GetFont()
    if plf then playBtn.label:SetFont(plf, 12, "OUTLINE") end
    playBtn:SetScript("OnClick", TogglePlay)

    nextBtn = CreateControlBtn(playerFrame, 24)
    nextBtn:SetPoint("LEFT", controlAnchor, "RIGHT", 18, 0)
    nextBtn.label:SetText("|cffffffff>>|r")
    local nxf = nextBtn.label:GetFont()
    if nxf then nextBtn.label:SetFont(nxf, 9, "OUTLINE") end
    nextBtn:SetScript("OnClick", NextTrack)

    shuffleBtn = CreateControlBtn(playerFrame, 20)
    shuffleBtn:SetPoint("LEFT", nextBtn, "RIGHT", 6, 0)
    shuffleBtn.label:SetText("|cff888888?|r")
    local shf = shuffleBtn.label:GetFont()
    if shf then shuffleBtn.label:SetFont(shf, 9, "OUTLINE") end
    shuffleBtn:SetScript("OnClick", ShufflePlay)

    -- Volume slider
    local volLabel = playerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    volLabel:SetPoint("TOPLEFT", 8, -152)
    volLabel:SetText("|cff888888Vol|r")
    local vlf = volLabel:GetFont()
    if vlf then volLabel:SetFont(vlf, 7, "") end

    local volBarBg = CreateFrame("Frame", nil, playerFrame)
    volBarBg:SetHeight(6)
    volBarBg:SetPoint("LEFT", volLabel, "RIGHT", 4, 0)
    volBarBg:SetPoint("RIGHT", playerFrame, "RIGHT", -8, 0)

    local volBgTex = volBarBg:CreateTexture(nil, "BACKGROUND")
    volBgTex:SetAllPoints()
    volBgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    volBgTex:SetVertexColor(0.15, 0.15, 0.18, 1)

    local volFill = volBarBg:CreateTexture(nil, "ARTWORK")
    volFill:SetPoint("TOPLEFT")
    volFill:SetPoint("BOTTOMLEFT")
    volFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    volFill:SetVertexColor(0.11, 0.73, 0.33, 1)

    local function UpdateVolFill()
        -- Show the intended volume: savedMusicVol during custom playback, else actual CVar
        local vol = savedMusicVol and tonumber(savedMusicVol) or tonumber(GetCVar("Sound_MusicVolume")) or 0.5
        local barW = volBarBg:GetWidth()
        if barW and barW > 0 then
            volFill:SetWidth(max(1, barW * vol))
        end
    end

    volBarBg:EnableMouse(true)
    volBarBg:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            local x = select(1, GetCursorPosition()) / self:GetEffectiveScale()
            local left = self:GetLeft()
            local w = self:GetWidth()
            if w and w > 0 then
                local pct = max(0, min(1, (x - left) / w))
                if savedMusicVol then
                    -- Custom track playing: store intended vol, keep CVar at 0
                    savedMusicVol = tostring(pct)
                else
                    SetCVar("Sound_MusicVolume", pct)
                end
                UpdateVolFill()
            end
        end
    end)

    -- Update fill on show
    volBarBg:SetScript("OnShow", function() C_Timer.After(0, UpdateVolFill) end)
    C_Timer.After(0, UpdateVolFill)

    -- Back button (hidden by default, shown in track view)
    backBtn = CreateFrame("Button", nil, parent)
    backBtn:SetSize(20, 14)
    backBtn:SetPoint("TOPLEFT", 4, -168)
    local backLabel = backBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    backLabel:SetPoint("CENTER")
    backLabel:SetText("|cff888888<|r")
    local blf = backLabel:GetFont()
    if blf then backLabel:SetFont(blf, 9, "OUTLINE") end
    backBtn:SetScript("OnClick", function() ShowAlbumView() end)
    local backHl = backBtn:CreateTexture(nil, "HIGHLIGHT")
    backHl:SetAllPoints()
    backHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    backHl:SetVertexColor(0.3, 0.3, 0.3, 0.3)
    backBtn:Hide()

    -- List label
    listLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    listLabel:SetPoint("LEFT", backBtn, "RIGHT", 2, 0)
    listLabel:SetText("|cff888888Albums:|r")
    local llf = listLabel:GetFont()
    if llf then listLabel:SetFont(llf, 8, "") end

    -- "+" button to add songs (shown only in My Music track view)
    addSongBtn = CreateFrame("Button", nil, parent)
    addSongBtn:SetSize(20, 14)
    addSongBtn:SetPoint("TOPRIGHT", -4, -168)
    local addBtnLabel = addSongBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addBtnLabel:SetPoint("CENTER")
    addBtnLabel:SetText("|cffff6699+|r")
    local abf = addBtnLabel:GetFont()
    if abf then addBtnLabel:SetFont(abf, 10, "OUTLINE") end
    addSongBtn:SetScript("OnClick", function() ShowAddSongView() end)
    local addBtnHl = addSongBtn:CreateTexture(nil, "HIGHLIGHT")
    addBtnHl:SetAllPoints()
    addBtnHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    addBtnHl:SetVertexColor(0.3, 0.3, 0.3, 0.3)
    addSongBtn:Hide()

    -- ========== ALBUM GRID VIEW (scrollable) ==========
    albumView = CreateFrame("ScrollFrame", nil, parent)
    albumView:SetPoint("TOPLEFT", 2, -184)
    albumView:SetPoint("BOTTOMRIGHT", -2, 2)

    local albumContent = CreateFrame("Frame", nil, albumView)
    albumContent:SetSize(1, 1)
    albumView:SetScrollChild(albumContent)

    albumView:EnableMouseWheel(true)
    albumView:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = max(0, albumContent:GetHeight() - self:GetHeight())
        local newS = min(maxS, max(0, cur - delta * 30))
        self:SetVerticalScroll(newS)
    end)

    local ALBUM_ROW_H = 28
    local visibleIdx = 0
    for i, album in ipairs(albums) do
        if #album.tracks > 0 or i == 1 then
            local yOff = -(visibleIdx * ALBUM_ROW_H)
            visibleIdx = visibleIdx + 1

            local abtn = CreateFrame("Button", nil, albumContent)
            abtn:SetHeight(ALBUM_ROW_H - 2)
            abtn:SetPoint("TOPLEFT", 0, yOff)
            abtn:SetPoint("RIGHT", albumView, "RIGHT", 0, 0)

            local r = tonumber(album.color:sub(1,2), 16) / 255
            local g = tonumber(album.color:sub(3,4), 16) / 255
            local b = tonumber(album.color:sub(5,6), 16) / 255

            local abg = abtn:CreateTexture(nil, "BACKGROUND")
            abg:SetAllPoints()
            abg:SetTexture("Interface\\Buttons\\WHITE8x8")
            abg:SetVertexColor(r * 0.2, g * 0.2, b * 0.2, 0.9)

            local ahl = abtn:CreateTexture(nil, "HIGHLIGHT")
            ahl:SetAllPoints()
            ahl:SetTexture("Interface\\Buttons\\WHITE8x8")
            ahl:SetVertexColor(r * 0.15, g * 0.15, b * 0.15, 0.5)

            -- Icon square
            local iconBg = abtn:CreateTexture(nil, "ARTWORK")
            iconBg:SetSize(22, 22)
            iconBg:SetPoint("LEFT", 4, 0)
            if album.wowIcon then
                iconBg:SetTexture(album.wowIcon)
                iconBg:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                iconBg:SetTexture("Interface\\Buttons\\WHITE8x8")
                iconBg:SetVertexColor(r * 0.4, g * 0.4, b * 0.4, 1)
                local aicon = abtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                aicon:SetPoint("CENTER", iconBg)
                aicon:SetText("|cff" .. album.color .. album.icon .. "|r")
                local aicf = aicon:GetFont()
                if aicf then aicon:SetFont(aicf, 11, "OUTLINE") end
            end

            -- Album name
            local aname = abtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            aname:SetPoint("LEFT", iconBg, "RIGHT", 6, 2)
            aname:SetPoint("RIGHT", -4, 0)
            aname:SetJustifyH("LEFT")
            aname:SetText("|cff" .. album.color .. album.name .. "|r")
            local anf = aname:GetFont()
            if anf then aname:SetFont(anf, 8, "OUTLINE") end

            -- Track count
            local count = abtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            count:SetPoint("LEFT", iconBg, "RIGHT", 6, -8)
            count:SetText("|cff666666" .. #album.tracks .. " tracks|r")
            local cf = count:GetFont()
            if cf then count:SetFont(cf, 7, "") end

            local idx = i
            abtn:SetScript("OnClick", function() ShowTrackView(idx) end)
            albumButtons[i] = abtn
        end
    end

    local albumListW = albumView:GetWidth()
    if not albumListW or albumListW < 10 then albumListW = 160 end
    albumContent:SetSize(albumListW, visibleIdx * ALBUM_ROW_H)

    -- ========== TRACK LIST VIEW (hidden by default) ==========
    trackView = CreateFrame("Frame", nil, parent)
    trackView:SetPoint("TOPLEFT", 2, -184)
    trackView:SetPoint("BOTTOMRIGHT", -2, 2)
    trackView:Hide()

    trackListScroll = CreateFrame("ScrollFrame", nil, trackView)
    trackListScroll:SetAllPoints()

    trackListContent = CreateFrame("Frame", nil, trackListScroll)
    trackListContent:SetSize(1, 1)
    trackListScroll:SetScrollChild(trackListContent)

    trackListScroll:EnableMouseWheel(true)
    trackListScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxScroll = max(0, trackListContent:GetHeight() - self:GetHeight())
        local newScroll = min(maxScroll, max(0, cur - delta * 20))
        self:SetVerticalScroll(newScroll)
    end)

    -- ========== ADD SONG VIEW (hidden by default, takes full screen) ==========
    addSongView = CreateFrame("Frame", nil, parent)
    addSongView:SetPoint("TOPLEFT", 2, -2)
    addSongView:SetPoint("BOTTOMRIGHT", -2, 2)
    addSongView:Hide()

    -- Back button inside add song view
    local addBackBtn = CreateFrame("Button", nil, addSongView)
    addBackBtn:SetSize(20, 14)
    addBackBtn:SetPoint("TOPLEFT", 4, -4)
    local addBackLabel = addBackBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addBackLabel:SetPoint("CENTER")
    addBackLabel:SetText("|cff888888<|r")
    local abkf = addBackLabel:GetFont()
    if abkf then addBackLabel:SetFont(abkf, 9, "OUTLINE") end
    addBackBtn:SetScript("OnClick", function() ShowTrackView(1) end)
    local addBackHl = addBackBtn:CreateTexture(nil, "HIGHLIGHT")
    addBackHl:SetAllPoints()
    addBackHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    addBackHl:SetVertexColor(0.3, 0.3, 0.3, 0.3)

    local addTitle = addSongView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addTitle:SetPoint("LEFT", addBackBtn, "RIGHT", 2, 0)
    addTitle:SetText("|cffff6699Add Song|r")
    local atf2 = addTitle:GetFont()
    if atf2 then addTitle:SetFont(atf2, 11, "") end

    -- Instructions
    local addInstr = addSongView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addInstr:SetPoint("TOPLEFT", addBackBtn, "BOTTOMLEFT", 2, -8)
    addInstr:SetPoint("RIGHT", -6, 0)
    addInstr:SetJustifyH("LEFT")
    addInstr:SetWordWrap(true)
    addInstr:SetText("|cffccccccDrop .mp3/.ogg files into:|r\n|cff888888..\\" .. ADDON_NAME .. "\\Music\\|r")
    local aif2 = addInstr:GetFont()
    if aif2 then addInstr:SetFont(aif2, 9, "") end

    -- Label
    local inputLabel = addSongView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    inputLabel:SetPoint("TOPLEFT", addInstr, "BOTTOMLEFT", 0, -10)
    inputLabel:SetText("|cffccccccFilename:|r")
    local ilf = inputLabel:GetFont()
    if ilf then inputLabel:SetFont(ilf, 10, "") end

    -- Input box
    local inputFrame = CreateFrame("Frame", nil, addSongView)
    inputFrame:SetHeight(24)
    inputFrame:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 0, -3)
    inputFrame:SetPoint("RIGHT", addSongView, "RIGHT", -6, 0)

    local inputBg = inputFrame:CreateTexture(nil, "BACKGROUND")
    inputBg:SetAllPoints()
    inputBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    inputBg:SetVertexColor(0.08, 0.08, 0.10, 1)

    addSongInput = CreateFrame("EditBox", nil, inputFrame)
    addSongInput:SetAllPoints()
    addSongInput:SetFontObject(GameFontNormalSmall)
    local esf = addSongInput:GetFont()
    if esf then addSongInput:SetFont(esf, 10, "") end
    addSongInput:SetTextInsets(4, 4, 0, 0)
    addSongInput:SetAutoFocus(false)
    addSongInput:SetMaxLetters(200)

    -- Add button
    local confirmBtn = CreateFrame("Button", nil, addSongView)
    confirmBtn:SetSize(60, 22)
    confirmBtn:SetPoint("TOPLEFT", inputFrame, "BOTTOMLEFT", 0, -6)

    local confirmBg = confirmBtn:CreateTexture(nil, "BACKGROUND")
    confirmBg:SetAllPoints()
    confirmBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    confirmBg:SetVertexColor(0.15, 0.30, 0.15, 1)

    local confirmHl = confirmBtn:CreateTexture(nil, "HIGHLIGHT")
    confirmHl:SetAllPoints()
    confirmHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    confirmHl:SetVertexColor(0.2, 0.4, 0.2, 0.4)

    local confirmLabel = confirmBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    confirmLabel:SetPoint("CENTER")
    confirmLabel:SetText("|cffffffffAdd|r")
    local clf = confirmLabel:GetFont()
    if clf then confirmLabel:SetFont(clf, 10, "") end

    -- Status message
    -- Status message - constrained within the phone screen
    local statusContainer = CreateFrame("Frame", nil, addSongView)
    statusContainer:SetPoint("TOPLEFT", confirmBtn, "BOTTOMLEFT", 0, -4)
    statusContainer:SetPoint("RIGHT", addSongView, "RIGHT", -6, 0)
    statusContainer:SetPoint("BOTTOM", addSongView, "BOTTOM", 0, 4)
    statusContainer:SetClipsChildren(true)

    addSongStatus = statusContainer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addSongStatus:SetPoint("TOPLEFT")
    addSongStatus:SetPoint("RIGHT")
    addSongStatus:SetJustifyH("LEFT")
    addSongStatus:SetWordWrap(true)
    local ssf = addSongStatus:GetFont()
    if ssf then addSongStatus:SetFont(ssf, 9, "") end

    local function DoAddSong()
        local input = strtrim(addSongInput:GetText() or "")
        if input == "" then
            addSongStatus:SetText("|cffff4444Enter a filename or song name.|r")
            return
        end

        -- Build list of filenames to try
        local hasExt = input:match("%.[^%.]+$")
        local tryFiles = {}
        if hasExt then
            table.insert(tryFiles, input)
        else
            -- Auto-probe common extensions
            table.insert(tryFiles, input .. ".mp3")
            table.insert(tryFiles, input .. ".ogg")
        end

        local foundFile
        for _, filename in ipairs(tryFiles) do
            local path = MUSIC_ADDON_PATH .. filename
            local ok, handle = PlaySoundFile(path, "Master")
            if ok then
                StopSound(handle)
                foundFile = filename
                break
            end
        end

        if foundFile then
            local displayName = foundFile:match("^(.+)%.[^%.]+$") or foundFile

            -- Check duplicates
            HearthPhoneDB = HearthPhoneDB or {}
            HearthPhoneDB.customMusic = HearthPhoneDB.customMusic or {}
            for _, saved in ipairs(HearthPhoneDB.customMusic) do
                if saved.file == foundFile then
                    addSongStatus:SetText("|cffffff00Already in My Music.|r")
                    return
                end
            end

            table.insert(HearthPhoneDB.customMusic, { file = foundFile, name = displayName })
            table.insert(myMusicAlbum.tracks, { name = displayName, file = foundFile, custom = true })
            RebuildPlaylist()
            addSongStatus:SetText("|cff44ff44Added: " .. displayName .. "|r")
            addSongInput:SetText("")
        else
            addSongStatus:SetText("|cffff4444File not found!|r\n|cff888888Tried: " .. table.concat(tryFiles, ", ") .. "|r")
        end
    end

    confirmBtn:SetScript("OnClick", DoAddSong)
    addSongInput:SetScript("OnEnterPressed", function()
        DoAddSong()
        addSongInput:ClearFocus()
    end)
    addSongInput:SetScript("OnEscapePressed", function()
        addSongInput:ClearFocus()
    end)

    -- Back from add song view goes to My Music track list
    backBtn:HookScript("OnClick", function()
        if addSongView:IsShown() then
            ShowTrackView(1)
        end
    end)

    -- Progress animation
    local progressElapsed = 0
    parent:SetScript("OnUpdate", function(self, dt)
        if not isPlaying then return end
        progressElapsed = progressElapsed + dt
        local pct = (progressElapsed % 30) / 30
        local maxW = progressBg:GetWidth()
        if maxW and maxW > 0 then
            progressFill:SetWidth(max(1, maxW * pct))
        end
    end)

    UpdateTrackDisplay()
end

function PhoneMusicApp:OnShow()
    UpdateTrackDisplay()
end

function PhoneMusicApp:OnHide()
end

-- /musictest <id> - Test a FileDataID directly
SLASH_MUSICTEST1 = "/musictest"
SlashCmdList["MUSICTEST"] = function(input)
    input = strtrim(input or "")
    local num = tonumber(input)
    if not num then
        print("|cff1DB954[Music]|r Usage: /musictest <FileDataID>  e.g. /musictest 53567")
        return
    end
    print("|cff1DB954[Music]|r Playing FileDataID: " .. num)
    StopMusic()
    PlayMusic(num)
end

-- /musichook - Hook PlayMusic to capture IDs the game plays (zone music etc.)
local musicHookActive = false
SLASH_MUSICHOOK1 = "/musichook"
SlashCmdList["MUSICHOOK"] = function()
    if musicHookActive then
        print("|cff1DB954[Music]|r Hook already active. Walk around zones to see IDs.")
        return
    end
    musicHookActive = true
    hooksecurefunc("PlayMusic", function(id)
        print("|cff1DB954[Music Hook]|r PlayMusic called with: " .. tostring(id))
    end)
    print("|cff1DB954[Music]|r Hook active! Walk around zones and music IDs will be printed.")
    print("|cff1DB954[Music]|r Use /musicadd <id> <name> to add a discovered track.")
end

-- /musicadd <id> <name> - Add a track by FileDataID to the playlist
SLASH_MUSICADD1 = "/musicadd"
SlashCmdList["MUSICADD"] = function(input)
    input = strtrim(input or "")
    local id, name = input:match("^(%d+)%s+(.+)$")
    id = tonumber(id)
    if not id or not name then
        print("|cff1DB954[Music]|r Usage: /musicadd <FileDataID> <Track Name>")
        print("|cff1DB954[Music]|r Example: /musicadd 555067 Stormwind Theme")
        return
    end
    -- Add to Zone Music album and playlist
    table.insert(albums[2].tracks, { name = name, fileId = id })
    table.insert(playlist, { name = name, fileId = id, album = "Zone Music", albumColor = "5599ff" })
    print("|cff1DB954[Music]|r Added: " .. name .. " (ID: " .. id .. ") to Zone Music")
    -- Refresh track view if currently viewing Zone Music
    if currentAlbumIndex == 2 then
        BuildTrackList(2)
    end
end

