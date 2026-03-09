-- PhoneWallpaper - Gallery & Wallpaper picker for HearthPhone

PhoneGalleryApp = {}

local parent
local ADDON_NAME = "HearthPhone"
local WALLPAPER_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Wallpapers\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"

-- Forward declarations
local galleryScroll, galleryContent, galleryButtons
local addView, addInput, addStatus
local previewView, previewTex, previewLabel
local ShowGalleryView, ShowAddView, ShowPreviewView, RefreshGallery
local currentPreviewEntry

-- ============================================================
-- Init
-- ============================================================
function PhoneGalleryApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cff44ccffGallery|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    ---------------------------------------------------------------------------
    -- Gallery view (scrollable grid of wallpaper thumbnails)
    ---------------------------------------------------------------------------
    local galleryView = CreateFrame("Frame", nil, parent)
    galleryView:SetPoint("TOPLEFT", 3, -16)
    galleryView:SetPoint("BOTTOMRIGHT", -3, 4)

    galleryScroll = CreateFrame("ScrollFrame", nil, galleryView)
    galleryScroll:SetPoint("TOPLEFT", 0, 0)
    galleryScroll:SetPoint("BOTTOMRIGHT", 0, 26)
    galleryScroll:EnableMouseWheel(true)
    galleryScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, (self.contentHeight or 0) - self:GetHeight())
        local newS = math.min(maxS, math.max(0, cur - delta * 40))
        self:SetVerticalScroll(newS)
    end)

    galleryContent = CreateFrame("Frame", nil, galleryScroll)
    galleryContent:SetWidth(galleryView:GetWidth() or 170)
    galleryContent:SetHeight(400)
    galleryScroll:SetScrollChild(galleryContent)

    galleryButtons = {}

    -- "Add Image" button at bottom of gallery view
    local addBtn = CreateFrame("Button", nil, galleryView)
    addBtn:SetSize(170, 22)
    addBtn:SetPoint("BOTTOM", 0, 2)

    local addBtnBg = addBtn:CreateTexture(nil, "BACKGROUND")
    addBtnBg:SetAllPoints()
    addBtnBg:SetTexture(WHITE)
    addBtnBg:SetVertexColor(0.15, 0.35, 0.15, 1)

    local addBtnHl = addBtn:CreateTexture(nil, "HIGHLIGHT")
    addBtnHl:SetAllPoints()
    addBtnHl:SetTexture(WHITE)
    addBtnHl:SetVertexColor(1, 1, 1, 0.1)

    local addBtnFs = addBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addBtnFs:SetPoint("CENTER")
    addBtnFs:SetText("|cff44ff44+ Add Image|r")
    local abf = addBtnFs:GetFont()
    if abf then addBtnFs:SetFont(abf, 9, "") end

    addBtn:SetScript("OnClick", function() ShowAddView() end)

    ---------------------------------------------------------------------------
    -- Add Image view
    ---------------------------------------------------------------------------
    addView = CreateFrame("Frame", nil, parent)
    addView:SetPoint("TOPLEFT", 3, -16)
    addView:SetPoint("BOTTOMRIGHT", -3, 4)
    addView:Hide()

    local addTitle = addView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addTitle:SetPoint("TOP", 0, -4)
    addTitle:SetText("|cff44ccffAdd Image|r")
    local atf = addTitle:GetFont()
    if atf then addTitle:SetFont(atf, 10, "OUTLINE") end

    -- Instructions
    local instructions = addView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    instructions:SetPoint("TOP", 0, -22)
    instructions:SetPoint("LEFT", 4, 0)
    instructions:SetPoint("RIGHT", -4, 0)
    instructions:SetJustifyH("LEFT")
    instructions:SetWordWrap(true)
    instructions:SetText("|cff888888Drop PNG/TGA/BLP files into:\nHearthPhone\\Wallpapers\\\n\nThen type the filename below.\nImages should be power-of-2\n(e.g. 256x512).|r")
    local inf = instructions:GetFont()
    if inf then instructions:SetFont(inf, 8, "") end

    -- Input box
    addInput = CreateFrame("EditBox", nil, addView, "InputBoxTemplate")
    addInput:SetSize(150, 20)
    addInput:SetPoint("TOP", instructions, "BOTTOM", 0, -8)
    addInput:SetAutoFocus(false)
    addInput:SetMaxLetters(100)
    local aif = addInput:GetFont()
    if aif then addInput:SetFont(aif, 9, "") end

    -- Confirm button
    local confirmBtn = CreateFrame("Button", nil, addView)
    confirmBtn:SetSize(80, 20)
    confirmBtn:SetPoint("TOP", addInput, "BOTTOM", 0, -6)

    local confirmBg = confirmBtn:CreateTexture(nil, "BACKGROUND")
    confirmBg:SetAllPoints()
    confirmBg:SetTexture(WHITE)
    confirmBg:SetVertexColor(0.15, 0.35, 0.15, 1)

    local confirmHl = confirmBtn:CreateTexture(nil, "HIGHLIGHT")
    confirmHl:SetAllPoints()
    confirmHl:SetTexture(WHITE)
    confirmHl:SetVertexColor(1, 1, 1, 0.1)

    local confirmFs = confirmBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    confirmFs:SetPoint("CENTER")
    confirmFs:SetText("|cff44ff44Add|r")
    local cf = confirmFs:GetFont()
    if cf then confirmFs:SetFont(cf, 9, "") end

    -- Status text
    local statusContainer = CreateFrame("Frame", nil, addView)
    statusContainer:SetPoint("LEFT", addView, "LEFT", 4, 0)
    statusContainer:SetPoint("RIGHT", addView, "RIGHT", -4, 0)
    statusContainer:SetPoint("TOP", confirmBtn, "BOTTOM", 0, -6)
    statusContainer:SetPoint("BOTTOM", addView, "BOTTOM", 0, 4)
    statusContainer:SetClipsChildren(true)

    addStatus = statusContainer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    addStatus:SetPoint("TOPLEFT")
    addStatus:SetPoint("RIGHT")
    addStatus:SetJustifyH("LEFT")
    addStatus:SetWordWrap(true)
    local ssf = addStatus:GetFont()
    if ssf then addStatus:SetFont(ssf, 8, "") end

    -- Back button
    local backBtn = CreateFrame("Button", nil, addView)
    backBtn:SetSize(40, 16)
    backBtn:SetPoint("TOPLEFT", 2, -2)

    local backBg = backBtn:CreateTexture(nil, "BACKGROUND")
    backBg:SetAllPoints()
    backBg:SetTexture(WHITE)
    backBg:SetVertexColor(0.2, 0.2, 0.25, 0.8)

    local backHl = backBtn:CreateTexture(nil, "HIGHLIGHT")
    backHl:SetAllPoints()
    backHl:SetTexture(WHITE)
    backHl:SetVertexColor(1, 1, 1, 0.1)

    local backFs = backBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    backFs:SetPoint("CENTER")
    backFs:SetText("|cffffffff< Back|r")
    local bf = backFs:GetFont()
    if bf then backFs:SetFont(bf, 8, "") end

    backBtn:SetScript("OnClick", function()
        ShowGalleryView()
    end)

    -- Add image logic
    local function DoAddImage()
        local input = strtrim(addInput:GetText() or "")
        if input == "" then
            addStatus:SetText("|cffff4444Enter a filename.|r")
            return
        end

        -- Build list of filenames to try
        local hasExt = input:match("%.[^%.]+$")
        local tryFiles = {}
        if hasExt then
            table.insert(tryFiles, input)
        else
            table.insert(tryFiles, input .. ".png")
            table.insert(tryFiles, input .. ".tga")
            table.insert(tryFiles, input .. ".blp")
        end

        local foundFile
        for _, filename in ipairs(tryFiles) do
            local path = WALLPAPER_PATH .. filename
            -- Try creating a texture to see if the file exists
            local testTex = parent:CreateTexture(nil, "BACKGROUND")
            testTex:SetSize(1, 1)
            testTex:SetTexture(path)
            -- If the texture loaded, GetTexture() returns the path
            local loaded = testTex:GetTexture()
            testTex:Hide()
            testTex:SetParent(nil)
            if loaded then
                foundFile = filename
                break
            end
        end

        if foundFile then
            local displayName = foundFile:match("^(.+)%.[^%.]+$") or foundFile

            HearthPhoneDB = HearthPhoneDB or {}
            HearthPhoneDB.wallpapers = HearthPhoneDB.wallpapers or {}

            -- Check duplicates
            for _, saved in ipairs(HearthPhoneDB.wallpapers) do
                if saved.file == foundFile then
                    addStatus:SetText("|cffffff00Already in gallery.|r")
                    return
                end
            end

            table.insert(HearthPhoneDB.wallpapers, { file = foundFile, name = displayName })
            addStatus:SetText("|cff44ff44Added: " .. displayName .. "|r")
            addInput:SetText("")
            RefreshGallery()
        else
            addStatus:SetText("|cffff4444File not found!\n|cff888888Tried: " .. table.concat(tryFiles, ", ") .. "|r")
        end
    end

    confirmBtn:SetScript("OnClick", DoAddImage)
    addInput:SetScript("OnEnterPressed", function()
        DoAddImage()
        addInput:ClearFocus()
    end)
    addInput:SetScript("OnEscapePressed", function()
        addInput:ClearFocus()
    end)

    ---------------------------------------------------------------------------
    -- Preview / Set wallpaper view
    ---------------------------------------------------------------------------
    previewView = CreateFrame("Frame", nil, parent)
    previewView:SetPoint("TOPLEFT", 3, -16)
    previewView:SetPoint("BOTTOMRIGHT", -3, 4)
    previewView:Hide()

    -- Preview image
    previewTex = previewView:CreateTexture(nil, "ARTWORK")
    previewTex:SetPoint("TOP", 0, -4)
    previewTex:SetSize(120, 160)

    previewLabel = previewView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    previewLabel:SetPoint("BOTTOM", previewView, "BOTTOM", 0, 96)
    previewLabel:SetTextColor(0.9, 0.9, 0.9, 1)
    local plf = previewLabel:GetFont()
    if plf then previewLabel:SetFont(plf, 9, "") end

    -- "Set as Home Screen" button
    local setHomeBtn = CreateFrame("Button", nil, previewView)
    setHomeBtn:SetSize(140, 20)
    setHomeBtn:SetPoint("BOTTOM", previewView, "BOTTOM", 0, 72)

    local setHomeBg = setHomeBtn:CreateTexture(nil, "BACKGROUND")
    setHomeBg:SetAllPoints()
    setHomeBg:SetTexture(WHITE)
    setHomeBg:SetVertexColor(0.12, 0.25, 0.45, 1)

    local setHomeHl = setHomeBtn:CreateTexture(nil, "HIGHLIGHT")
    setHomeHl:SetAllPoints()
    setHomeHl:SetTexture(WHITE)
    setHomeHl:SetVertexColor(1, 1, 1, 0.1)

    local setHomeFs = setHomeBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    setHomeFs:SetPoint("CENTER")
    setHomeFs:SetText("|cff88bbffSet as Home Screen|r")
    local shf = setHomeFs:GetFont()
    if shf then setHomeFs:SetFont(shf, 9, "") end

    -- "Set as Lock Screen" button
    local setLockBtn = CreateFrame("Button", nil, previewView)
    setLockBtn:SetSize(140, 20)
    setLockBtn:SetPoint("BOTTOM", previewView, "BOTTOM", 0, 48)

    local setLockBg = setLockBtn:CreateTexture(nil, "BACKGROUND")
    setLockBg:SetAllPoints()
    setLockBg:SetTexture(WHITE)
    setLockBg:SetVertexColor(0.35, 0.15, 0.40, 1)

    local setLockHl = setLockBtn:CreateTexture(nil, "HIGHLIGHT")
    setLockHl:SetAllPoints()
    setLockHl:SetTexture(WHITE)
    setLockHl:SetVertexColor(1, 1, 1, 0.1)

    local setLockFs = setLockBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    setLockFs:SetPoint("CENTER")
    setLockFs:SetText("|cffcc88ffSet as Lock Screen|r")
    local slf = setLockFs:GetFont()
    if slf then setLockFs:SetFont(slf, 9, "") end

    -- Delete button
    local deleteBtn = CreateFrame("Button", nil, previewView)
    deleteBtn:SetSize(140, 20)
    deleteBtn:SetPoint("BOTTOM", previewView, "BOTTOM", 0, 24)

    local deleteBg = deleteBtn:CreateTexture(nil, "BACKGROUND")
    deleteBg:SetAllPoints()
    deleteBg:SetTexture(WHITE)
    deleteBg:SetVertexColor(0.45, 0.12, 0.12, 1)

    local deleteHl = deleteBtn:CreateTexture(nil, "HIGHLIGHT")
    deleteHl:SetAllPoints()
    deleteHl:SetTexture(WHITE)
    deleteHl:SetVertexColor(1, 1, 1, 0.1)

    local deleteFs = deleteBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    deleteFs:SetPoint("CENTER")
    deleteFs:SetText("|cffff6666Remove from Gallery|r")
    local df = deleteFs:GetFont()
    if df then deleteFs:SetFont(df, 9, "") end

    -- Preview status
    local previewStatus = previewView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    previewStatus:SetPoint("BOTTOM", previewView, "BOTTOM", 0, 4)
    previewStatus:SetTextColor(0.5, 0.8, 0.5, 1)
    local psf = previewStatus:GetFont()
    if psf then previewStatus:SetFont(psf, 8, "") end

    -- Preview back button
    local previewBack = CreateFrame("Button", nil, previewView)
    previewBack:SetSize(40, 16)
    previewBack:SetPoint("TOPLEFT", 2, -2)

    local pbBg = previewBack:CreateTexture(nil, "BACKGROUND")
    pbBg:SetAllPoints()
    pbBg:SetTexture(WHITE)
    pbBg:SetVertexColor(0.2, 0.2, 0.25, 0.8)

    local pbHl = previewBack:CreateTexture(nil, "HIGHLIGHT")
    pbHl:SetAllPoints()
    pbHl:SetTexture(WHITE)
    pbHl:SetVertexColor(1, 1, 1, 0.1)

    local pbFs = previewBack:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pbFs:SetPoint("CENTER")
    pbFs:SetText("|cffffffff< Back|r")
    local pbff = pbFs:GetFont()
    if pbff then pbFs:SetFont(pbff, 8, "") end

    previewBack:SetScript("OnClick", function()
        ShowGalleryView()
    end)

    -- Button logic
    setHomeBtn:SetScript("OnClick", function()
        if not currentPreviewEntry then return end
        HearthPhoneDB = HearthPhoneDB or {}
        HearthPhoneDB.homeWallpaper = currentPreviewEntry.path
        HearthPhoneDB.homeWallpaperCrop = currentPreviewEntry.crop
        previewStatus:SetText("|cff44ff44Set as home screen!|r")
        -- Apply immediately
        PhoneGalleryApp:ApplyWallpapers()
    end)

    setLockBtn:SetScript("OnClick", function()
        if not currentPreviewEntry then return end
        HearthPhoneDB = HearthPhoneDB or {}
        HearthPhoneDB.lockWallpaper = currentPreviewEntry.path
        HearthPhoneDB.lockWallpaperCrop = currentPreviewEntry.crop
        previewStatus:SetText("|cff44ff44Set as lock screen!|r")
        PhoneGalleryApp:ApplyWallpapers()
    end)

    deleteBtn:SetScript("OnClick", function()
        if not currentPreviewEntry or not currentPreviewEntry.file then
            previewStatus:SetText("|cffff4444Cannot remove this.|r")
            return
        end
        HearthPhoneDB = HearthPhoneDB or {}
        HearthPhoneDB.wallpapers = HearthPhoneDB.wallpapers or {}
        for i, saved in ipairs(HearthPhoneDB.wallpapers) do
            if saved.file == currentPreviewEntry.file then
                table.remove(HearthPhoneDB.wallpapers, i)
                break
            end
        end
        -- Clear wallpaper if this image was set as home or lock screen
        local removedPath = currentPreviewEntry.path
        if removedPath and HearthPhoneDB.homeWallpaper == removedPath then
            HearthPhoneDB.homeWallpaper = nil
            HearthPhoneDB.homeWallpaperCrop = nil
        end
        if removedPath and HearthPhoneDB.lockWallpaper == removedPath then
            HearthPhoneDB.lockWallpaper = nil
            HearthPhoneDB.lockWallpaperCrop = nil
        end
        PhoneGalleryApp:ApplyWallpapers()
        previewStatus:SetText("|cffff6666Removed.|r")
        C_Timer.After(0.5, function() ShowGalleryView() end)
    end)

    ---------------------------------------------------------------------------
    -- Gallery layout helpers
    ---------------------------------------------------------------------------
    local THUMB_SIZE = 52
    local THUMB_PAD = 6
    local COLS = 3

    ShowGalleryView = function()
        galleryView:Show()
        addView:Hide()
        previewView:Hide()
        RefreshGallery()
    end

    ShowAddView = function()
        galleryView:Hide()
        addView:Show()
        previewView:Hide()
        addInput:SetText("")
        addStatus:SetText("|cff888888Enter the image name\n(no extension needed).|r")
    end

    ShowPreviewView = function(entry)
        galleryView:Hide()
        addView:Hide()
        previewView:Show()
        currentPreviewEntry = entry
        previewTex:SetTexture(entry.path)
        if entry.crop then
            previewTex:SetTexCoord(unpack(entry.crop))
        else
            previewTex:SetTexCoord(0, 1, 0, 1)
        end
        previewTex:SetVertexColor(1, 1, 1, 1)
        previewLabel:SetText(entry.name or "Wallpaper")
        previewStatus:SetText("")
    end

    RefreshGallery = function()
        -- Hide old buttons
        for _, btn in ipairs(galleryButtons) do
            btn:Hide()
        end

        -- Build full image list from saved wallpapers
        local images = {}
        HearthPhoneDB = HearthPhoneDB or {}
        HearthPhoneDB.wallpapers = HearthPhoneDB.wallpapers or {}

        for _, saved in ipairs(HearthPhoneDB.wallpapers) do
            table.insert(images, {
                name = saved.name,
                file = saved.file,
                path = WALLPAPER_PATH .. saved.file,
                crop = nil, -- user wallpapers are assumed portrait-ready
            })
        end

        -- Layout as grid
        local w = galleryScroll:GetWidth() or 170
        local startX = (w - (COLS * THUMB_SIZE + (COLS - 1) * THUMB_PAD)) / 2

        for i, img in ipairs(images) do
            local btn = galleryButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, galleryContent)
                btn:SetSize(THUMB_SIZE, THUMB_SIZE)

                local bg = btn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetTexture(WHITE)
                bg:SetVertexColor(0.12, 0.12, 0.15, 1)

                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", 2, -2)
                tex:SetPoint("BOTTOMRIGHT", -2, 2)
                btn.tex = tex

                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetTexture(WHITE)
                hl:SetVertexColor(1, 1, 1, 0.15)

                local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                label:SetPoint("BOTTOM", 0, 3)
                label:SetWidth(THUMB_SIZE - 4)
                label:SetWordWrap(false)
                btn.label = label
                local lf = label:GetFont()
                if lf then label:SetFont(lf, 7, "OUTLINE") end

                galleryButtons[i] = btn
            end

            local col = (i - 1) % COLS
            local row = math.floor((i - 1) / COLS)
            btn:SetPoint("TOPLEFT", galleryContent, "TOPLEFT", startX + col * (THUMB_SIZE + THUMB_PAD), -(row * (THUMB_SIZE + THUMB_PAD + 12) + 4))

            btn.tex:SetTexture(img.path)
            if img.crop then
                btn.tex:SetTexCoord(unpack(img.crop))
            else
                btn.tex:SetTexCoord(0, 1, 0, 1)
            end
            btn.tex:SetVertexColor(0.8, 0.8, 0.8, 1)
            btn.label:SetText(img.name or "")
            btn:SetScript("OnClick", function() ShowPreviewView(img) end)
            btn:Show()
        end

        -- Empty state
        if #images == 0 then
            local emptyBtn = galleryButtons[1]
            if not emptyBtn then
                emptyBtn = CreateFrame("Button", nil, galleryContent)
                emptyBtn:SetSize(170, 60)
                local emptyFs = emptyBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                emptyFs:SetAllPoints()
                emptyFs:SetJustifyH("CENTER")
                emptyFs:SetJustifyV("MIDDLE")
                emptyFs:SetWordWrap(true)
                emptyBtn.label = emptyFs
                local ef = emptyFs:GetFont()
                if ef then emptyFs:SetFont(ef, 8, "") end
                emptyBtn.tex = emptyBtn:CreateTexture(nil, "BACKGROUND")
                emptyBtn.tex:SetSize(1, 1)
                emptyBtn.tex:Hide()
                galleryButtons[1] = emptyBtn
            end
            emptyBtn:SetPoint("TOPLEFT", galleryContent, "TOPLEFT", 0, -10)
            emptyBtn.label:SetText("|cff666666No images yet.\nTap '+ Add Image' below\nto add wallpapers.|r")
            emptyBtn:SetScript("OnClick", nil)
            emptyBtn:Show()
        end

        -- Update scroll height
        local rows = math.ceil(math.max(1, #images) / COLS)
        local contentH = rows * (THUMB_SIZE + THUMB_PAD + 12) + 20
        galleryContent:SetHeight(contentH)
        galleryScroll.contentHeight = contentH
    end

    -- Start on gallery view
    ShowGalleryView()
end

-- ============================================================
-- Apply wallpapers (called from HearthPhone.lua)
-- ============================================================
-- These are set by HearthPhone.lua so we can update them
PhoneGalleryApp._screenBg = nil
PhoneGalleryApp._lockBg = nil

function PhoneGalleryApp:ApplyWallpapers()
    HearthPhoneDB = HearthPhoneDB or {}

    if self._screenBg then
        if HearthPhoneDB.homeWallpaper then
            self._screenBg:SetTexture(HearthPhoneDB.homeWallpaper)
            if HearthPhoneDB.homeWallpaperCrop then
                self._screenBg:SetTexCoord(unpack(HearthPhoneDB.homeWallpaperCrop))
            else
                self._screenBg:SetTexCoord(0, 1, 0, 1)
            end
            self._screenBg:SetVertexColor(0.5, 0.5, 0.5, 1)
        else
            self._screenBg:SetTexture(nil)
        end
    end

    if self._lockBg then
        if HearthPhoneDB.lockWallpaper then
            self._lockBg:SetTexture(HearthPhoneDB.lockWallpaper)
            if HearthPhoneDB.lockWallpaperCrop then
                self._lockBg:SetTexCoord(unpack(HearthPhoneDB.lockWallpaperCrop))
            else
                self._lockBg:SetTexCoord(0, 1, 0, 1)
            end
            self._lockBg:SetVertexColor(0.5, 0.5, 0.5, 1)
        else
            self._lockBg:SetTexture(nil)
        end
    end
end

function PhoneGalleryApp:OnShow()
    if RefreshGallery then
        ShowGalleryView()
    end
end

function PhoneGalleryApp:OnHide()
end
