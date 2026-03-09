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
