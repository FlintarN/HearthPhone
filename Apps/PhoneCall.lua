-- PhoneCall - Call system for HearthPhone
-- Uses custom chat channels and addon messaging for signaling.

PhoneCallApp = {}

local ADDON_PREFIX = "PhoneCall"
local parent
local callState = "idle" -- idle, calling, ringing, active
local callTarget = nil
local callTimer = 0
local ringTimer = 0
local ringCount = 0
local MAX_RING_TIME = 20

-- UI elements
local contactsView, callView, dialView
local statusFs, targetFs, timerFs, callerIconTex, channelFs
local hangupBtn, answerBtn, declineBtn
local contactRows = {}
local contactScroll, contactContent
local dialInput
local recentRows = {}
local recentCalls = {}
local tabContacts, tabRecents, tabDial
local contactsList, recentsList, dialPage
local contactSearchText = ""

-- ============================================================
-- Helpers
-- ============================================================
local function GetMyName()
    local name, realm = UnitFullName("player")
    realm = realm or GetNormalizedRealmName() or ""
    if realm ~= "" then return name .. "-" .. realm end
    return name
end

local function FormatTime(sec)
    local m = math.floor(sec / 60)
    local s = math.floor(sec % 60)
    return string.format("%d:%02d", m, s)
end

local function SendCallMessage(target, msgType, data)
    local payload = msgType
    if data then payload = msgType .. ":" .. data end
    -- Prefer BNet transport via PhonePresence (cross-realm, cross-faction)
    if PhonePresence then
        local friend = PhonePresence:FindFriend(target)
        if friend then
            local sent = PhonePresence:SendToFriend(friend, ADDON_PREFIX, payload)
            if sent then return end
        end
    end
    -- Fallback: direct whisper (same realm/faction only)
    pcall(function()
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, payload, "WHISPER", target)
    end)
end

local function PlayRingtone()
    PlaySound(3081, "Master")
    if HearthPhone_Vibrate then HearthPhone_Vibrate() end
end

-- Friends list is provided by PhoneFriends shared module

-- ============================================================
-- Voice Channel (disabled — WoW addons cannot start voice chat)
-- ============================================================

-- ============================================================
-- UI Updates
-- ============================================================
local function ShowContactsView()
    if contactsView then contactsView:Show() end
    if callView then callView:Hide() end
end

local function ShowCallView()
    if contactsView then contactsView:Hide() end
    if callView then callView:Show() end
end

local function UpdateCallUI()
    if not callView then return end

    if callState == "idle" then
        ShowContactsView()
        return
    end

    ShowCallView()

    if channelFs then channelFs:SetText("|cff666666Voice chat not available via addons|r") end

    if callState == "calling" then
        targetFs:SetText("|cffffffff" .. (callTarget or "???") .. "|r")
        statusFs:SetText("|cffaaaaaa Calling...|r")
        timerFs:SetText("")
        if answerBtn then answerBtn:Hide() end
        if declineBtn then declineBtn:Hide() end
        if hangupBtn then hangupBtn:Show() end
    elseif callState == "ringing" then
        targetFs:SetText("|cffffffff" .. (callTarget or "???") .. "|r")
        statusFs:SetText("|cff44ff44 Incoming Call|r")
        timerFs:SetText("")
        if answerBtn then answerBtn:Show() end
        if declineBtn then declineBtn:Show() end
        if hangupBtn then hangupBtn:Hide() end
    elseif callState == "active" then
        targetFs:SetText("|cffffffff" .. (callTarget or "???") .. "|r")
        statusFs:SetText("|cff44ff44 Connected|r")
        timerFs:SetText("|cffaaaaaa" .. FormatTime(callTimer) .. "|r")
        if channelFs then
            channelFs:SetText("|cff666666Voice chat not available via addons|r")
        end
        if answerBtn then answerBtn:Hide() end
        if declineBtn then declineBtn:Hide() end
        if hangupBtn then hangupBtn:Show() end
    end
end

-- ============================================================
-- Call Logic
-- ============================================================
local function AddToRecents(name, callType)
    table.insert(recentCalls, 1, { name = name, type = callType, time = date("%H:%M") })
    if #recentCalls > 20 then table.remove(recentCalls) end
end

local function EndCall(reason)
    if callState == "idle" then return end
    local wasTarget = callTarget
    if wasTarget then SendCallMessage(wasTarget, "HANGUP") end
    callState = "idle"
    callTarget = nil
    callTimer = 0
    ringTimer = 0
    ringCount = 0
    UpdateCallUI()
end

local function StartCall(targetName)
    if callState ~= "idle" then
        print("|cffff4444[Phone]|r Already in a call.")
        return
    end
    if not targetName or targetName == "" then return end

    callState = "calling"
    callTarget = targetName
    callTimer = 0
    ringTimer = 0

    SendCallMessage(targetName, "RING")
    AddToRecents(targetName, "outgoing")
    UpdateCallUI()
end

local function AcceptCall()
    if callState ~= "ringing" then return end
    SendCallMessage(callTarget, "ACCEPT")
    callState = "active"
    callTimer = 0
    AddToRecents(callTarget or "???", "incoming")
    UpdateCallUI()
end

local function DeclineCall()
    if callState ~= "ringing" then return end
    AddToRecents(callTarget or "???", "missed")
    SendCallMessage(callTarget, "DECLINE")
    callState = "idle"
    callTarget = nil
    ringTimer = 0
    ringCount = 0
    UpdateCallUI()
end

-- ============================================================
-- Addon presence (delegates to shared PhonePresence module)
-- ============================================================
local function PingOnlineFriends()
    if PhonePresence then PhonePresence:PingFriends() end
end

function PhoneCallApp:HasAddon(name)
    return PhonePresence and PhonePresence:HasAddon(name) or false
end

function PhoneCallApp:OnNewAddonUser(callback)
    if PhonePresence then PhonePresence:OnUserDiscovered(callback) end
end

-- ============================================================
-- Addon Message Handler
-- ============================================================
local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end
    if PhonePresence.NamesMatch(sender, GetMyName()) then return end

    local msgType = strsplit(":", message, 2)
    local function isTarget(s) return PhonePresence.NamesMatch(s, callTarget) end

    if msgType == "RING" then
        if callState ~= "idle" then
            SendCallMessage(sender, "BUSY")
            return
        end
        callState = "ringing"
        callTarget = sender
        ringTimer = 0
        ringCount = 0
        PlayRingtone()
        UpdateCallUI()
        if PhoneCallApp.ForceShowCall then PhoneCallApp.ForceShowCall() end
    elseif msgType == "ACCEPT" then
        if callState == "calling" and isTarget(sender) then
            callState = "active"
            callTimer = 0
            UpdateCallUI()
        end
    elseif msgType == "DECLINE" then
        if callState == "calling" and isTarget(sender) then
            if statusFs then statusFs:SetText("|cffff4444 Declined|r") end
            C_Timer.After(1.5, function()
                if callState == "calling" then
                    callState = "idle"
                    callTarget = nil
                    UpdateCallUI()
                end
            end)
        end
    elseif msgType == "BUSY" then
        if callState == "calling" and isTarget(sender) then
            if statusFs then statusFs:SetText("|cffff8800 Busy|r") end
            C_Timer.After(1.5, function()
                if callState == "calling" then
                    callState = "idle"
                    callTarget = nil
                    UpdateCallUI()
                end
            end)
        end
    elseif msgType == "HANGUP" then
        if isTarget(sender) then
            local wasRinging = callState == "ringing"
            callState = "idle"
            callTarget = nil
            callTimer = 0
            ringTimer = 0
            if wasRinging then AddToRecents(sender, "missed") end
            UpdateCallUI()
        end
    end
end

-- ============================================================
-- Tab helpers
-- ============================================================
local activeTab = "contacts"

local function SetActiveTab(tab)
    activeTab = tab
    if contactsList then contactsList:SetShown(tab == "contacts") end
    if recentsList then recentsList:SetShown(tab == "recents") end
    if dialPage then dialPage:SetShown(tab == "dial") end

    if tabContacts then
        if tab == "contacts" then
            tabContacts.bg:SetVertexColor(0.20, 0.45, 0.20, 1)
        else
            tabContacts.bg:SetVertexColor(0.12, 0.12, 0.15, 1)
        end
    end
    if tabRecents then
        if tab == "recents" then
            tabRecents.bg:SetVertexColor(0.20, 0.45, 0.20, 1)
        else
            tabRecents.bg:SetVertexColor(0.12, 0.12, 0.15, 1)
        end
    end
    if tabDial then
        if tab == "dial" then
            tabDial.bg:SetVertexColor(0.20, 0.45, 0.20, 1)
        else
            tabDial.bg:SetVertexColor(0.12, 0.12, 0.15, 1)
        end
    end
end

-- ============================================================
-- Init
-- ============================================================
function PhoneCallApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

    -- Event handling
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("BN_CHAT_MSG_ADDON")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            OnAddonMessage(...)
        elseif event == "BN_CHAT_MSG_ADDON" then
            local prefix, message, _, senderID = ...
            if prefix ~= ADDON_PREFIX then return end
            local acctInfo = C_BattleNet.GetGameAccountInfoByID(senderID)
            if acctInfo and acctInfo.characterName then
                local sender = acctInfo.characterName
                if acctInfo.realmName and acctInfo.realmName ~= "" then
                    local myRealm = GetNormalizedRealmName() or ""
                    local theirRealm = acctInfo.realmName:gsub("%s+", "")
                    if theirRealm ~= myRealm then
                        sender = sender .. "-" .. theirRealm
                    end
                end
                OnAddonMessage(prefix, message, "BN", sender)
            end
        end
    end)

    -- ========== CONTACTS VIEW (tabs + content) ==========
    contactsView = CreateFrame("Frame", nil, parent)
    contactsView:SetPoint("TOPLEFT", 2, -2)
    contactsView:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Title
    local title = contactsView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -4)
    title:SetText("|cff44cc44Phone|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 11, "OUTLINE") end

    -- Tab bar
    local tabBar = CreateFrame("Frame", nil, contactsView)
    tabBar:SetHeight(18)
    tabBar:SetPoint("TOPLEFT", 0, -18)
    tabBar:SetPoint("TOPRIGHT", 0, -18)

    local NUM_TABS = 3
    local function CreateTab(label, tabId)
        local tab = CreateFrame("Button", nil, tabBar)
        tab:SetHeight(16)

        local bg = tab:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.12, 0.12, 0.15, 1)
        tab.bg = bg

        local hl = tab:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(0.2, 0.2, 0.2, 0.3)

        local fs = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        fs:SetText(label)
        local fnt = fs:GetFont()
        if fnt then fs:SetFont(fnt, 8, "") end

        tab:SetScript("OnClick", function() SetActiveTab(tabId) end)
        return tab
    end

    tabContacts = CreateTab("|cffffffffContacts", "contacts")
    tabRecents = CreateTab("|cffffffffRecents", "recents")
    tabDial = CreateTab("|cffffffffDial", "dial")

    -- Position tabs to split the full width evenly (OnSizeChanged handles dynamic sizing)
    local function LayoutTabs()
        local barW = tabBar:GetWidth()
        local tabW = barW / NUM_TABS
        tabContacts:ClearAllPoints()
        tabContacts:SetPoint("TOPLEFT", tabBar, "TOPLEFT", 0, 0)
        tabContacts:SetSize(tabW, 16)
        tabRecents:ClearAllPoints()
        tabRecents:SetPoint("TOPLEFT", tabBar, "TOPLEFT", tabW, 0)
        tabRecents:SetSize(tabW, 16)
        tabDial:ClearAllPoints()
        tabDial:SetPoint("TOPLEFT", tabBar, "TOPLEFT", tabW * 2, 0)
        tabDial:SetSize(tabW, 16)
    end
    tabBar:SetScript("OnSizeChanged", LayoutTabs)
    C_Timer.After(0, LayoutTabs)

    -- Content area starts below tabs
    local contentTop = -38

    -- ========== CONTACTS LIST ==========
    contactsList = CreateFrame("Frame", nil, contactsView)
    contactsList:SetPoint("TOPLEFT", 0, contentTop)
    contactsList:SetPoint("BOTTOMRIGHT", 0, 0)

    -- Search bar
    local searchFrame = PhoneFriends:CreateSearchBar(contactsList, nil, nil, 0, -2, function(text)
        contactSearchText = text or ""
        if self.RefreshContacts then self:RefreshContacts() end
    end)

    contactScroll = CreateFrame("ScrollFrame", nil, contactsList)
    contactScroll:SetPoint("TOPLEFT", searchFrame, "BOTTOMLEFT", -2, -2)
    contactScroll:SetPoint("BOTTOMRIGHT", -2, 0)

    contactContent = CreateFrame("Frame", nil, contactScroll)
    contactContent:SetSize(1, 1)
    contactScroll:SetScrollChild(contactContent)

    contactScroll:EnableMouseWheel(true)
    contactScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = max(0, contactContent:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(min(maxS, max(0, cur - delta * 25)))
    end)

    -- ========== RECENTS LIST ==========
    recentsList = CreateFrame("Frame", nil, contactsView)
    recentsList:SetPoint("TOPLEFT", 0, contentTop)
    recentsList:SetPoint("BOTTOMRIGHT", 0, 0)
    recentsList:Hide()

    local recentsScroll = CreateFrame("ScrollFrame", nil, recentsList)
    recentsScroll:SetPoint("TOPLEFT", 2, 0)
    recentsScroll:SetPoint("BOTTOMRIGHT", -2, 0)

    local recentsContent = CreateFrame("Frame", nil, recentsScroll)
    recentsContent:SetSize(1, 1)
    recentsScroll:SetScrollChild(recentsContent)

    recentsScroll:EnableMouseWheel(true)
    recentsScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = max(0, recentsContent:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(min(maxS, max(0, cur - delta * 25)))
    end)

    -- ========== DIAL PAD ==========
    dialPage = CreateFrame("Frame", nil, contactsView)
    dialPage:SetPoint("TOPLEFT", 0, contentTop)
    dialPage:SetPoint("BOTTOMRIGHT", 0, 0)
    dialPage:Hide()

    local dialLabel = dialPage:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dialLabel:SetPoint("TOPLEFT", 8, -6)
    dialLabel:SetText("|cffccccccPlayer name:|r")
    local dlf = dialLabel:GetFont()
    if dlf then dialLabel:SetFont(dlf, 9, "") end

    local dialInputFrame = CreateFrame("Frame", nil, dialPage)
    dialInputFrame:SetHeight(22)
    dialInputFrame:SetPoint("TOPLEFT", dialLabel, "BOTTOMLEFT", 0, -4)
    dialInputFrame:SetPoint("RIGHT", dialPage, "RIGHT", -8, 0)

    local dialInputBg = dialInputFrame:CreateTexture(nil, "BACKGROUND")
    dialInputBg:SetAllPoints()
    dialInputBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    dialInputBg:SetVertexColor(0.08, 0.08, 0.10, 1)

    dialInput = CreateFrame("EditBox", nil, dialInputFrame)
    dialInput:SetAllPoints()
    dialInput:SetFontObject(GameFontNormalSmall)
    local dif = dialInput:GetFont()
    if dif then dialInput:SetFont(dif, 9, "") end
    dialInput:SetTextInsets(4, 4, 0, 0)
    dialInput:SetAutoFocus(false)
    dialInput:SetMaxLetters(100)
    dialInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    dialInput:SetScript("OnEnterPressed", function(self)
        local t = strtrim(self:GetText() or "")
        if t ~= "" then StartCall(t) end
        self:ClearFocus()
    end)

    local dialCallBtn = CreateFrame("Button", nil, dialPage)
    dialCallBtn:SetSize(60, 24)
    dialCallBtn:SetPoint("TOPLEFT", dialInputFrame, "BOTTOMLEFT", 0, -6)

    local dcbBg = dialCallBtn:CreateTexture(nil, "BACKGROUND")
    dcbBg:SetAllPoints()
    dcbBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    dcbBg:SetVertexColor(0.15, 0.45, 0.15, 1)

    local dcbHl = dialCallBtn:CreateTexture(nil, "HIGHLIGHT")
    dcbHl:SetAllPoints()
    dcbHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    dcbHl:SetVertexColor(0.2, 0.5, 0.2, 0.4)

    local dcbLabel = dialCallBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dcbLabel:SetPoint("CENTER")
    dcbLabel:SetText("|cffffffffCall|r")
    local dcblf = dcbLabel:GetFont()
    if dcblf then dcbLabel:SetFont(dcblf, 10, "") end

    dialCallBtn:SetScript("OnClick", function()
        local t = strtrim(dialInput:GetText() or "")
        if t ~= "" then StartCall(t) end
    end)

    local dialHint = dialPage:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dialHint:SetPoint("TOPLEFT", dialCallBtn, "BOTTOMLEFT", 0, -10)
    dialHint:SetPoint("RIGHT", dialPage, "RIGHT", -8, 0)
    dialHint:SetJustifyH("LEFT")
    dialHint:SetWordWrap(true)
    dialHint:SetText("|cff666666Both players need HearthPhone.\nVoice chat must be enabled.|r")
    local dhf = dialHint:GetFont()
    if dhf then dialHint:SetFont(dhf, 8, "") end

    -- ========== ACTIVE CALL VIEW ==========
    callView = CreateFrame("Frame", nil, parent)
    callView:SetPoint("TOPLEFT", 2, -2)
    callView:SetPoint("BOTTOMRIGHT", -2, 2)
    callView:Hide()

    -- Dark background
    local callBg = callView:CreateTexture(nil, "BACKGROUND")
    callBg:SetAllPoints()
    callBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    callBg:SetVertexColor(0.06, 0.06, 0.08, 0.95)

    -- Caller icon
    callerIconTex = callView:CreateTexture(nil, "ARTWORK")
    callerIconTex:SetSize(50, 50)
    callerIconTex:SetPoint("TOP", 0, -30)
    callerIconTex:SetTexture("Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend")
    callerIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Target name
    targetFs = callView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    targetFs:SetPoint("TOP", callerIconTex, "BOTTOM", 0, -8)
    local tgf = targetFs:GetFont()
    if tgf then targetFs:SetFont(tgf, 12, "OUTLINE") end

    -- Status
    statusFs = callView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusFs:SetPoint("TOP", targetFs, "BOTTOM", 0, -4)
    local stf = statusFs:GetFont()
    if stf then statusFs:SetFont(stf, 9, "") end

    -- Timer
    timerFs = callView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    timerFs:SetPoint("TOP", statusFs, "BOTTOM", 0, -6)
    local tmf = timerFs:GetFont()
    if tmf then timerFs:SetFont(tmf, 14, "OUTLINE") end

    -- Channel name (subtle, bottom)
    channelFs = callView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    channelFs:SetPoint("BOTTOM", 0, 10)
    local chf = channelFs:GetFont()
    if chf then channelFs:SetFont(chf, 7, "") end
    channelFs:SetText("")

    -- Hang up button (red, centered)
    hangupBtn = CreateFrame("Button", nil, callView)
    hangupBtn:SetSize(54, 26)
    hangupBtn:SetPoint("BOTTOM", 0, 30)

    local huBg = hangupBtn:CreateTexture(nil, "BACKGROUND")
    huBg:SetAllPoints()
    huBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    huBg:SetVertexColor(0.65, 0.10, 0.10, 1)

    local huHl = hangupBtn:CreateTexture(nil, "HIGHLIGHT")
    huHl:SetAllPoints()
    huHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    huHl:SetVertexColor(0.8, 0.2, 0.2, 0.4)

    local huLabel = hangupBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    huLabel:SetPoint("CENTER")
    huLabel:SetText("|cffffffffEnd|r")
    local hulf = huLabel:GetFont()
    if hulf then huLabel:SetFont(hulf, 10, "") end
    hangupBtn:SetScript("OnClick", function() EndCall("hangup") end)
    hangupBtn:Hide()

    -- Answer button (green, left)
    answerBtn = CreateFrame("Button", nil, callView)
    answerBtn:SetSize(54, 26)
    answerBtn:SetPoint("BOTTOMRIGHT", callView, "BOTTOM", -4, 30)

    local anBg = answerBtn:CreateTexture(nil, "BACKGROUND")
    anBg:SetAllPoints()
    anBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    anBg:SetVertexColor(0.10, 0.55, 0.10, 1)

    local anHl = answerBtn:CreateTexture(nil, "HIGHLIGHT")
    anHl:SetAllPoints()
    anHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    anHl:SetVertexColor(0.2, 0.6, 0.2, 0.4)

    local anLabel = answerBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    anLabel:SetPoint("CENTER")
    anLabel:SetText("|cffffffffAnswer|r")
    local alf = anLabel:GetFont()
    if alf then anLabel:SetFont(alf, 10, "") end
    answerBtn:SetScript("OnClick", AcceptCall)
    answerBtn:Hide()

    -- Decline button (red, right)
    declineBtn = CreateFrame("Button", nil, callView)
    declineBtn:SetSize(54, 26)
    declineBtn:SetPoint("BOTTOMLEFT", callView, "BOTTOM", 4, 30)

    local dcBg = declineBtn:CreateTexture(nil, "BACKGROUND")
    dcBg:SetAllPoints()
    dcBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    dcBg:SetVertexColor(0.65, 0.10, 0.10, 1)

    local dcHl = declineBtn:CreateTexture(nil, "HIGHLIGHT")
    dcHl:SetAllPoints()
    dcHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    dcHl:SetVertexColor(0.8, 0.2, 0.2, 0.4)

    local dcLabel = declineBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dcLabel:SetPoint("CENTER")
    dcLabel:SetText("|cffffffffDecline|r")
    local dcf = dcLabel:GetFont()
    if dcf then dcLabel:SetFont(dcf, 9, "") end
    declineBtn:SetScript("OnClick", DeclineCall)
    declineBtn:Hide()

    -- ========== Timers (OnUpdate) ==========
    parent:SetScript("OnUpdate", function(_, dt)
        if callState == "active" then
            callTimer = callTimer + dt
            if timerFs then timerFs:SetText("|cffaaaaaa" .. FormatTime(callTimer) .. "|r") end
        elseif callState == "calling" then
            ringTimer = ringTimer + dt
            if ringTimer > MAX_RING_TIME then
                if statusFs then statusFs:SetText("|cffff4444 No answer|r") end
                C_Timer.After(1.5, function()
                    if callState == "calling" then EndCall("timeout") end
                end)
            end
        elseif callState == "ringing" then
            ringTimer = ringTimer + dt
            local newCount = math.floor(ringTimer / 3)
            if newCount > ringCount then
                ringCount = newCount
                PlayRingtone()
            end
            if ringTimer > MAX_RING_TIME then
                AddToRecents(callTarget or "???", "missed")
                SendCallMessage(callTarget, "HANGUP")
                callState = "idle"
                callTarget = nil
                ringTimer = 0
                ringCount = 0
                UpdateCallUI()
            end
        end
    end)

    -- ========== Build/Refresh Functions ==========
    local ROW_H = 22

    -- Reuse EnsureContactRow for recents (needs callIcon)
    local function EnsureContactRow(parentFrame, list, index)
        local btn = PhoneFriends:EnsureRow(parentFrame, list, index, { showStatus = true, actionLabel = "Call" })
        if not btn.callIcon then btn.callIcon = btn.statusFs end  -- alias for recents compatibility
        return btn
    end

    function self:RefreshContacts()
        PhoneFriends:RenderList({
            pool = contactRows,
            contentFrame = contactContent,
            scrollFrame = contactScroll,
            searchText = contactSearchText,
            rowOpts = { showStatus = true, actionLabel = "Call" },
            styleRow = function(btn, f, hasAddon)
                local displayName = PhoneFriends:DisplayName(f)
                local hpTag = hasAddon and " |cff40c0ff[HP]|r" or ""
                if f.isOnline then
                    btn.nameFs:SetText("|cffffffff" .. displayName .. hpTag)
                    if hasAddon then
                        btn.statusFs2:SetText("|cff40c0ffHP - Online|r")
                    else
                        btn.statusFs2:SetText("|cff33ff99Online|r")
                    end
                    btn.statusFs:SetText("|cff44cc44Call|r")
                    btn.bg:SetVertexColor(0.10, 0.12, 0.10, 0.5)
                else
                    local plain = f.bnetName or f.charName or "?"
                    btn.nameFs:SetText("|cff666666" .. plain .. "|r")
                    btn.statusFs2:SetText("|cff666666Offline|r")
                    btn.statusFs:SetText("|cff444444Call|r")
                    btn.bg:SetVertexColor(0.10, 0.10, 0.12, 0.3)
                end
            end,
            onClick = function(_, target)
                StartCall(target)
            end,
        })
    end

    function self:RefreshRecents()
        for _, r in ipairs(recentRows) do r:Hide() end

        for i, entry in ipairs(recentCalls) do
            if i > 15 then break end
            local btn = EnsureContactRow(recentsContent, recentRows, i)

            local typeColor, arrow
            if entry.type == "outgoing" then
                typeColor = "44ff44"
                arrow = "-> "
            elseif entry.type == "incoming" then
                typeColor = "4488ff"
                arrow = "<- "
            else
                typeColor = "ff4444"
                arrow = "x "
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_H))
            btn:SetPoint("RIGHT", recentsContent, "RIGHT", 0, 0)

            btn.nameFs:SetText("|cff" .. typeColor .. arrow .. "|r|cffffffff" .. entry.name .. "|r")
            btn.statusFs:SetText("|cff888888" .. entry.time .. "|r")
            btn.callIcon:SetText("|cff44cc44Call|r")

            local target = entry.name
            btn:SetScript("OnClick", function()
                if target and target ~= "???" then StartCall(target) end
            end)
            btn:Show()
        end

        local contentW = recentsScroll:GetWidth() or 150
        recentsContent:SetSize(contentW, math.max(#recentCalls * ROW_H, 1))
    end

    SetActiveTab("contacts")
end

function PhoneCallApp:OnShow()
    if callState == "idle" then
        ShowContactsView()
        -- Ping online friends to detect who has the addon
        PingOnlineFriends()
        -- Refresh after a short delay to show results
        C_Timer.After(1, function()
            if self.RefreshContacts then self:RefreshContacts() end
        end)
        if self.RefreshContacts then self:RefreshContacts() end
        if self.RefreshRecents then self:RefreshRecents() end
    else
        ShowCallView()
    end
    UpdateCallUI()
end

function PhoneCallApp:OnHide()
    -- Call continues in background
end

-- /call PlayerName
SLASH_PHONECALL1 = "/call"
SlashCmdList["PHONECALL"] = function(input)
    input = strtrim(input or "")
    if input == "" then
        print("|cff44cc44[Phone]|r Usage: /call PlayerName")
        return
    end
    StartCall(input)
end

-- /calldemo - Demo outgoing call: creates a voice channel and joins it so you can verify it works
SLASH_PHONECALLDEMO1 = "/calldemo"
SlashCmdList["PHONECALLDEMO"] = function()
    if callState ~= "idle" then
        print("|cff44cc44[Phone]|r End current call first.")
        return
    end

    local demoTarget = "DemoCall"
    callState = "calling"
    callTarget = demoTarget
    callTimer = 0
    ringTimer = 0

    AddToRecents(demoTarget, "outgoing")
    UpdateCallUI()
    if PhoneCallApp.ForceShowCall then PhoneCallApp.ForceShowCall() end

    -- Auto-connect after a moment to simulate the other side answering
    C_Timer.After(3, function()
        if callState == "calling" and callTarget == demoTarget then
            callState = "active"
            callTimer = 0
            print("|cff44cc44[Phone]|r Demo call connected!")
            UpdateCallUI()
        end
    end)
end

-- /callfake [Name] - Demo incoming call: simulates receiving a call
SLASH_PHONECALLFAKE1 = "/callfake"
SlashCmdList["PHONECALLFAKE"] = function(input)
    if callState ~= "idle" then
        print("|cff44cc44[Phone]|r End current call first.")
        return
    end

    local fakeCaller = strtrim(input or "")
    if fakeCaller == "" then fakeCaller = "Mom" end

    callState = "ringing"
    callTarget = fakeCaller
    ringTimer = 0
    ringCount = 0
    PlayRingtone()
    UpdateCallUI()
    if PhoneCallApp.ForceShowCall then PhoneCallApp.ForceShowCall() end
end
