-- PhoneFriends - Shared friends list module for HearthPhone
-- Provides GetFriendsList() and reusable UI components (search bar, scrollable list).

PhoneFriends = {}

-- Returns a sorted list of friends: { bnetName, charName, realmName, isOnline, gameAccountID }
function PhoneFriends:GetList()
    local friends = {}
    local numBNet = BNGetNumFriends()
    for i = 1, numBNet do
        local acctInfo = C_BattleNet.GetFriendAccountInfo(i)
        if acctInfo then
            local bnetName = acctInfo.accountName or "?"
            local gameInfo = acctInfo.gameAccountInfo
            local charName, realmName, isOnline, gameAcctID
            if gameInfo then
                charName = gameInfo.characterName
                realmName = gameInfo.realmName
                isOnline = gameInfo.isOnline
                gameAcctID = gameInfo.gameAccountID
            end
            table.insert(friends, {
                bnetName = bnetName,
                charName = charName,
                realmName = realmName,
                isOnline = isOnline or false,
                gameAccountID = gameAcctID,
            })
        end
    end
    local numChar = C_FriendList.GetNumFriends()
    for i = 1, numChar do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.name then
            -- info.name may be "Name" or "Name-Realm"
            local cName, cRealm = strsplit("-", info.name)
            table.insert(friends, {
                bnetName = nil,
                charName = cName,
                realmName = cRealm,
                isOnline = info.connected or false,
            })
        end
    end
    table.sort(friends, function(a, b)
        if a.isOnline ~= b.isOnline then return a.isOnline end
        local aName = a.charName or a.bnetName or ""
        local bName = b.charName or b.bnetName or ""
        return aName < bName
    end)
    return friends
end

-- Filter friends by search text (matches charName or bnetName, case-insensitive)
function PhoneFriends:Filter(friends, searchText)
    if not searchText or searchText == "" then return friends end
    local q = searchText:lower()
    local result = {}
    for _, f in ipairs(friends) do
        local cn = (f.charName or ""):lower()
        local bn = (f.bnetName or ""):lower()
        if cn:find(q, 1, true) or bn:find(q, 1, true) then
            table.insert(result, f)
        end
    end
    return result
end

-- Returns displayName for a friend entry
function PhoneFriends:DisplayName(f)
    if f.charName and f.bnetName then
        return f.charName .. " |cff888888(" .. f.bnetName .. ")|r"
    elseif f.charName then
        return f.charName
    else
        return f.bnetName or "?"
    end
end

-- Returns the best whisper target name for a friend (includes realm for cross-realm)
function PhoneFriends:WhisperTarget(f)
    if f.charName and f.realmName and f.realmName ~= "" then
        local myRealm = GetNormalizedRealmName() or ""
        local theirRealm = f.realmName:gsub("%s+", "")  -- normalize spaces
        if theirRealm ~= myRealm and theirRealm ~= "" then
            return f.charName .. "-" .. theirRealm
        end
    end
    return f.charName or f.bnetName or nil
end

-- Check if a friend entry has the addon (tries multiple name forms)
function PhoneFriends:FriendHasAddon(f)
    if not PhonePresence then return false end
    if f.charName and PhonePresence:HasAddon(f.charName) then return true end
    -- Try Ambiguated form
    if f.charName and f.realmName and f.realmName ~= "" then
        local full = f.charName .. "-" .. f.realmName:gsub("%s+", "")
        if PhonePresence:HasAddon(full) then return true end
        local short = Ambiguate(full, "short")
        if short ~= f.charName and PhonePresence:HasAddon(short) then return true end
    end
    return false
end

-- Returns friends sorted: addon users first, then online, then alphabetical
function PhoneFriends:GetSortedList(searchText)
    local friends = self:GetList()
    if searchText and searchText ~= "" then
        friends = self:Filter(friends, searchText)
    end
    table.sort(friends, function(a, b)
        local aAddon = self:FriendHasAddon(a) and 1 or 0
        local bAddon = self:FriendHasAddon(b) and 1 or 0
        if aAddon ~= bAddon then return aAddon > bAddon end
        if a.isOnline ~= b.isOnline then return a.isOnline end
        local aName = a.charName or a.bnetName or ""
        local bName = b.charName or b.bnetName or ""
        return aName < bName
    end)
    return friends
end

-- Create a reusable friend row button. opts fields:
--   actionLabel: string shown on the right (e.g. "Play", "Call"), or nil for status mode
--   showStatus: if true, adds a second line status fontstring
--   showSeparator: if true, adds a bottom separator line
local FRIEND_ROW_H = 22

function PhoneFriends:EnsureRow(parent, pool, index, opts)
    opts = opts or {}
    if pool[index] then return pool[index] end

    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(FRIEND_ROW_H)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.10, 0.12, 0.10, 0.5)
    btn.bg = bg

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\Buttons\\WHITE8x8")
    hl:SetVertexColor(0.2, 0.2, 0.2, 0.3)

    local nameFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    nameFs:SetPoint("LEFT", 6, opts.showStatus and 2 or 0)
    nameFs:SetPoint("RIGHT", -50, opts.showStatus and 2 or 0)
    nameFs:SetJustifyH("LEFT")
    local nf = nameFs:GetFont()
    if nf then nameFs:SetFont(nf, 8, "") end
    btn.nameFs = nameFs

    -- Right-side label (action or status)
    local rightFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    rightFs:SetPoint("RIGHT", -6, 0)
    rightFs:SetJustifyH("RIGHT")
    local rf = rightFs:GetFont()
    if rf then rightFs:SetFont(rf, 7, "") end
    if opts.actionLabel then
        rightFs:SetText("|cff44cc44" .. opts.actionLabel .. "|r")
    end
    btn.statusFs = rightFs

    -- Optional second-line status
    if opts.showStatus then
        local statusFs2 = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        statusFs2:SetPoint("LEFT", 6, -6)
        statusFs2:SetJustifyH("LEFT")
        local sf = statusFs2:GetFont()
        if sf then statusFs2:SetFont(sf, 7, "") end
        btn.statusFs2 = statusFs2
    end

    -- Optional separator
    if opts.showSeparator then
        local sep = btn:CreateTexture(nil, "BORDER")
        sep:SetPoint("BOTTOMLEFT", 4, 0)
        sep:SetPoint("BOTTOMRIGHT", -4, 0)
        sep:SetHeight(1)
        sep:SetTexture("Interface\\Buttons\\WHITE8x8")
        sep:SetVertexColor(0.25, 0.25, 0.3, 0.4)
    end

    btn:Hide()
    pool[index] = btn
    return btn
end

-- Populate a friend row with standard display (addon-aware)
-- If the row has an actionLabel (e.g. "Play", "Call"), the HP tag goes in the name;
-- otherwise HP/Online/Offline goes in the statusFs.
function PhoneFriends:StyleRow(btn, f, opts)
    opts = opts or {}
    local displayName = self:DisplayName(f)
    local hasAddon = self:FriendHasAddon(f)
    local hasAction = opts.actionLabel

    if f.isOnline then
        local hpTag = hasAddon and " |cff40c0ff[HP]|r" or ""
        btn.nameFs:SetText("|cffffffff" .. displayName .. hpTag)
        if not hasAction then
            if hasAddon then
                btn.statusFs:SetText("|cff40c0ffHP|r")
            elseif f.charName then
                btn.statusFs:SetText("|cff33ff99Online|r")
            else
                btn.statusFs:SetText("|cff66aaffBNet|r")
            end
        end
        if btn.bg then btn.bg:SetVertexColor(0.10, 0.12, 0.10, 0.5) end
    else
        local plain = f.bnetName or f.charName or "?"
        btn.nameFs:SetText("|cff666666" .. plain .. "|r")
        if not hasAction then
            btn.statusFs:SetText("|cff666666Offline|r")
        end
        if btn.bg then btn.bg:SetVertexColor(0.10, 0.10, 0.12, 0.3) end
    end
end

-- Render a full friend list into a scroll content frame. opts fields:
--   pool: table of reusable row buttons
--   contentFrame: the scroll child frame
--   scrollFrame: the parent ScrollFrame (for sizing)
--   searchText: current search filter (optional)
--   onlineOnly: if true, skip offline friends
--   rowOpts: passed to EnsureRow (actionLabel, showStatus, showSeparator)
--   onClick(friend, target): called when a row is clicked
--   styleRow(btn, friend, hasAddon): optional custom styling override
-- Returns: number of rows rendered
function PhoneFriends:RenderList(opts)
    local friends = self:GetSortedList(opts.searchText)
    for _, btn in ipairs(opts.pool) do btn:Hide() end

    local row = 0
    for _, f in ipairs(friends) do
        if not opts.onlineOnly or f.isOnline then
            row = row + 1
            local btn = self:EnsureRow(opts.contentFrame, opts.pool, row, opts.rowOpts)

            if opts.styleRow then
                opts.styleRow(btn, f, self:FriendHasAddon(f))
            else
                self:StyleRow(btn, f, opts.rowOpts)
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", 0, -((row - 1) * FRIEND_ROW_H))
            btn:SetPoint("RIGHT", opts.contentFrame, "RIGHT", 0, 0)

            local target = self:WhisperTarget(f) or "?"
            if opts.onClick then
                btn:SetScript("OnClick", function()
                    if target ~= "?" then opts.onClick(f, target) end
                end)
            end
            btn:Show()
        end
    end

    local contentW = opts.scrollFrame and opts.scrollFrame:GetWidth() or 150
    opts.contentFrame:SetSize(contentW, math.max(row * FRIEND_ROW_H, 1))
    return row
end

-- Create a search bar EditBox inside parentFrame. Returns the editBox and placeholder fontstring.
-- onChanged(text) is called when text changes.
function PhoneFriends:CreateSearchBar(parentFrame, anchorTo, anchorPoint, offsetX, offsetY, onChanged)
    anchorPoint = anchorPoint or "TOP"
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    local searchFrame = CreateFrame("Frame", nil, parentFrame)
    searchFrame:SetHeight(20)
    if anchorTo then
        searchFrame:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", offsetX, offsetY)
        searchFrame:SetPoint("TOPRIGHT", anchorTo, "BOTTOMRIGHT", offsetX, offsetY)
    else
        searchFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 4 + offsetX, offsetY)
        searchFrame:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -4 + offsetX, offsetY)
    end

    local bg = searchFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.10, 0.10, 0.13, 1)

    local searchBox = CreateFrame("EditBox", nil, searchFrame)
    searchBox:SetPoint("TOPLEFT", 4, -2)
    searchBox:SetPoint("BOTTOMRIGHT", -4, 2)
    searchBox:SetFontObject(GameFontNormalSmall)
    local sbf = searchBox:GetFont()
    if sbf then searchBox:SetFont(sbf, 8, "") end
    searchBox:SetTextColor(1, 1, 1, 1)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(30)

    local placeholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    placeholder:SetPoint("LEFT", 2, 0)
    placeholder:SetText("|cff666666Search...|r")
    local phf = placeholder:GetFont()
    if phf then placeholder:SetFont(phf, 8, "") end

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        placeholder:SetShown(text == "")
        if onChanged then onChanged(text) end
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    return searchFrame, searchBox
end
