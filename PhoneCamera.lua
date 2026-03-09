-- PhoneCamera - S.E.L.F.I.E. Camera app for HearthPhone

PhoneCameraApp = {}

local parent
local WHITE = "Interface\\Buttons\\WHITE8x8"
local SELFIE_TOY_ID = 122637   -- S.E.L.F.I.E. Camera MkII
local SELFIE_TOY_ID_ALT = 122674  -- S.E.L.F.I.E. Camera (original)

local shutterBtn, statusFs, viewfinder
local activateBtn -- secure button to enter selfie mode

-- ============================================================
-- Init
-- ============================================================
function PhoneCameraApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local PAD = 3

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cff44ccffCamera|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 10, "OUTLINE") end

    -- Viewfinder area (dark rectangle simulating camera preview)
    viewfinder = CreateFrame("Frame", nil, parent)
    viewfinder:SetPoint("TOPLEFT", PAD, -18)
    viewfinder:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
    viewfinder:SetHeight(140)

    local vfBg = viewfinder:CreateTexture(nil, "BACKGROUND")
    vfBg:SetAllPoints()
    vfBg:SetTexture(WHITE)
    vfBg:SetVertexColor(0.05, 0.05, 0.08, 1)

    -- Crosshair lines
    local hLine = viewfinder:CreateTexture(nil, "ARTWORK")
    hLine:SetSize(40, 1)
    hLine:SetPoint("CENTER")
    hLine:SetTexture(WHITE)
    hLine:SetVertexColor(1, 1, 1, 0.2)

    local vLine = viewfinder:CreateTexture(nil, "ARTWORK")
    vLine:SetSize(1, 40)
    vLine:SetPoint("CENTER")
    vLine:SetTexture(WHITE)
    vLine:SetVertexColor(1, 1, 1, 0.2)

    -- Corner brackets
    local function CreateCorner(point, xOff, yOff)
        local ch = viewfinder:CreateTexture(nil, "ARTWORK")
        ch:SetSize(16, 1)
        ch:SetPoint(point, xOff, yOff)
        ch:SetTexture(WHITE)
        ch:SetVertexColor(1, 1, 1, 0.35)
        local cv = viewfinder:CreateTexture(nil, "ARTWORK")
        cv:SetSize(1, 16)
        cv:SetPoint(point, xOff, yOff)
        cv:SetTexture(WHITE)
        cv:SetVertexColor(1, 1, 1, 0.35)
    end
    CreateCorner("TOPLEFT", 8, -8)
    CreateCorner("TOPRIGHT", -8, -8)
    CreateCorner("BOTTOMLEFT", 8, 8)
    CreateCorner("BOTTOMRIGHT", -8, 8)

    -- "S.E.L.F.I.E." label inside viewfinder
    local selfieLabel = viewfinder:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    selfieLabel:SetPoint("TOP", 0, -12)
    selfieLabel:SetText("|cff888888S.E.L.F.I.E.|r")
    local sf = selfieLabel:GetFont()
    if sf then selfieLabel:SetFont(sf, 7, "") end

    -- REC dot
    local recDot = viewfinder:CreateTexture(nil, "ARTWORK")
    recDot:SetSize(6, 6)
    recDot:SetPoint("TOPLEFT", 12, -12)
    recDot:SetTexture(WHITE)
    recDot:SetVertexColor(1, 0.2, 0.2, 0.8)

    -- "Activate Camera" secure button — covers the viewfinder area
    -- User must click this first to enter selfie mode, then shutter takes photos
    activateBtn = CreateFrame("Button", "PhoneCameraActivate", viewfinder, "SecureActionButtonTemplate")
    activateBtn:SetAllPoints()
    activateBtn:RegisterForClicks("AnyDown")
    activateBtn:SetAttribute("type", "macro")
    activateBtn:SetAttribute("macrotext", "/use item:122637\n/use item:122674")
    activateBtn:SetFrameLevel(viewfinder:GetFrameLevel() + 10)

    local inSelfie = false

    -- Overlay text on the activate button
    local activateFs = activateBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    activateFs:SetPoint("CENTER", 0, -10)
    activateFs:SetText("|cff44ccffTap to activate camera|r")
    local af = activateFs:GetFont()
    if af then activateFs:SetFont(af, 9, "") end

    local activateHl = activateBtn:CreateTexture(nil, "HIGHLIGHT")
    activateHl:SetAllPoints()
    activateHl:SetTexture(WHITE)
    activateHl:SetVertexColor(1, 1, 1, 0.08)

    activateBtn:HookScript("OnClick", function()
        if not (PlayerHasToy(SELFIE_TOY_ID) or PlayerHasToy(SELFIE_TOY_ID_ALT)) then
            statusFs:SetText("|cffff4444You don't have the\nS.E.L.F.I.E. Camera toy!|r")
            return
        end
        if not inSelfie then
            -- Entering selfie mode
            inSelfie = true
            activateBtn:SetAttribute("macrotext", "/click OverrideActionBarButton6")
            activateFs:SetText("|cffff6666Tap to exit camera|r")
            statusFs:SetText("|cff44ff44Camera active!|r")
            -- Hide ALL UI by reparenting the phone out of UIParent, then hiding UIParent
            C_Timer.After(0.5, function()
                -- Walk up from our page to find the phone frame
                local phoneFrame = parent:GetParent() -- screen
                if phoneFrame then phoneFrame = phoneFrame:GetParent() end -- phone
                if phoneFrame and phoneFrame:GetParent() == UIParent then
                    phoneFrame._cameraOrigScale = phoneFrame:GetScale()
                    phoneFrame:SetParent(WorldFrame)
                    phoneFrame:SetFrameStrata("TOOLTIP")
                    phoneFrame:SetScale((phoneFrame._cameraOrigScale or 1) * 0.65)
                    UIParent:Hide()
                end
            end)
            C_Timer.After(2, function()
                statusFs:SetText("|cff888888Tap shutter to take photo|r")
            end)
        else
            -- Exiting selfie mode — restore UI
            inSelfie = false
            UIParent:Show()
            local phoneFrame = parent:GetParent()
            if phoneFrame then phoneFrame = phoneFrame:GetParent() end
            if phoneFrame and phoneFrame:GetParent() == WorldFrame then
                phoneFrame:SetParent(UIParent)
                phoneFrame:SetFrameStrata("HIGH")
                phoneFrame:SetScale(phoneFrame._cameraOrigScale or 1)
            end
            activateBtn:SetAttribute("macrotext", "/use item:122637\n/use item:122674")
            activateFs:SetText("|cff44ccffTap to activate camera|r")
            statusFs:SetText("|cff888888Activate camera first|r")
        end
    end)

    -- Status text (below viewfinder)
    statusFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusFs:SetPoint("TOP", viewfinder, "BOTTOM", 0, -6)
    statusFs:SetText("|cff888888Activate camera first|r")
    local stf = statusFs:GetFont()
    if stf then statusFs:SetFont(stf, 8, "") end

    -- Shutter button (secure — clicks ActionButton1 to take the selfie photo)
    shutterBtn = CreateFrame("Button", "PhoneCameraShutter", parent, "SecureActionButtonTemplate")
    shutterBtn:SetSize(50, 50)
    shutterBtn:SetPoint("TOP", viewfinder, "BOTTOM", 0, -24)
    shutterBtn:RegisterForClicks("AnyDown")
    shutterBtn:SetAttribute("type", "macro")
    shutterBtn:SetAttribute("macrotext", "/click OverrideActionBarButton1")

    -- Outer ring
    local outerRing = shutterBtn:CreateTexture(nil, "BACKGROUND")
    outerRing:SetAllPoints()
    outerRing:SetTexture(WHITE)
    outerRing:SetVertexColor(0.3, 0.3, 0.35, 1)

    -- Inner circle
    local innerCircle = shutterBtn:CreateTexture(nil, "ARTWORK")
    innerCircle:SetSize(42, 42)
    innerCircle:SetPoint("CENTER")
    innerCircle:SetTexture(WHITE)
    innerCircle:SetVertexColor(0.9, 0.9, 0.95, 1)

    -- Highlight
    local hl = shutterBtn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(WHITE)
    hl:SetVertexColor(1, 1, 1, 0.15)

    shutterBtn:HookScript("OnClick", function()
        -- Flash effect
        local flash = parent:CreateTexture(nil, "OVERLAY")
        flash:SetAllPoints()
        flash:SetTexture(WHITE)
        flash:SetVertexColor(1, 1, 1, 0.6)
        C_Timer.After(0.15, function()
            flash:SetVertexColor(1, 1, 1, 0.3)
        end)
        C_Timer.After(0.3, function()
            flash:Hide()
            flash:SetParent(nil)
        end)
        -- Re-hide UIParent if we're in selfie mode (taking photo re-shows it)
        if inSelfie then
            C_Timer.After(0.1, function()
                if inSelfie and UIParent:IsShown() then
                    UIParent:Hide()
                end
            end)
        end
    end)

    -- Filter buttons (action buttons 2-5 in selfie mode)
    local filters = { "Sketch", "Death", "B&W", "BG" }
    local filterColors = {
        {0.35, 0.30, 0.25},
        {0.30, 0.15, 0.15},
        {0.25, 0.25, 0.25},
        {0.20, 0.30, 0.20},
    }
    local FILTER_W = 30
    local totalW = #filters * FILTER_W + (#filters - 1) * 4
    local startX = -totalW / 2 + FILTER_W / 2

    for i, name in ipairs(filters) do
        local fb = CreateFrame("Button", "PhoneCameraFilter" .. i, parent, "SecureActionButtonTemplate")
        fb:SetSize(FILTER_W, 20)
        fb:RegisterForClicks("AnyDown")
        fb:SetAttribute("type", "macro")
        fb:SetAttribute("macrotext", "/click OverrideActionBarButton" .. (i + 1))
        fb:SetPoint("TOP", shutterBtn, "BOTTOM", startX + (i - 1) * (FILTER_W + 4), -8)

        local fbBg = fb:CreateTexture(nil, "BACKGROUND")
        fbBg:SetAllPoints()
        fbBg:SetTexture(WHITE)
        local c = filterColors[i]
        fbBg:SetVertexColor(c[1], c[2], c[3], 1)

        local fbHl = fb:CreateTexture(nil, "HIGHLIGHT")
        fbHl:SetAllPoints()
        fbHl:SetTexture(WHITE)
        fbHl:SetVertexColor(1, 1, 1, 0.12)

        local fbFs = fb:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fbFs:SetPoint("CENTER")
        fbFs:SetText("|cffffffff" .. name .. "|r")
        local ff = fbFs:GetFont()
        if ff then fbFs:SetFont(ff, 7, "") end
    end

    -- Tip at bottom
    local tip = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tip:SetPoint("BOTTOM", 0, 6)
    tip:SetText("|cff555555Uses S.E.L.F.I.E. Camera toy|r")
    local tipf = tip:GetFont()
    if tipf then tip:SetFont(tipf, 7, "") end
end

function PhoneCameraApp:OnShow()
    if not statusFs then return end
    if activateBtn then activateBtn:Show() end
    if not (PlayerHasToy(SELFIE_TOY_ID) or PlayerHasToy(SELFIE_TOY_ID_ALT)) then
        statusFs:SetText("|cffff4444S.E.L.F.I.E. Camera\ntoy not collected!|r")
    else
        statusFs:SetText("|cff888888Activate camera first|r")
    end
end

function PhoneCameraApp:OnHide()
end
