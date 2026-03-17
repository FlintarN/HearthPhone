-- PhonePresence - Shared presence/heartbeat system for HearthPhone
-- Tracks which BNet and character friends have HearthPhone installed.
-- Uses BNSendGameData (cross-realm, cross-faction) as primary transport,
-- with addon whisper fallback for character-only friends.

PhonePresence = {}

local ADDON_PREFIX = "xHP"  -- short prefix shared across all HearthPhone presence
local knownUsers = {}       -- [name] = true
local callbacks = {}        -- list of function(sender) called on new user discovery
local pingCooldown = 0
local PING_INTERVAL = 10    -- seconds between ping sweeps

-- ============================================================
-- Shared utility: compare two character names ignoring realm suffix
-- e.g. "Ifnotm" matches "Ifnotm-Silvermoon"
-- ============================================================
function PhonePresence.NamesMatch(a, b)
    if not a or not b then return false end
    if a == b then return true end
    return Ambiguate(a, "short") == Ambiguate(b, "short")
end

-- ============================================================
-- Helpers
-- ============================================================
local function GetMyName()
    local name, realm = UnitFullName("player")
    realm = realm or GetNormalizedRealmName() or ""
    if realm ~= "" then return name .. "-" .. realm end
    return name
end

local function ResolveBNetSender(gameAccountID)
    local acctInfo = C_BattleNet.GetGameAccountInfoByID(gameAccountID)
    if not acctInfo or not acctInfo.characterName then return nil end
    local sender = acctInfo.characterName
    if acctInfo.realmName and acctInfo.realmName ~= "" then
        local myRealm = GetNormalizedRealmName() or ""
        local theirRealm = acctInfo.realmName:gsub("%s+", "")
        if theirRealm ~= myRealm then
            sender = sender .. "-" .. theirRealm
        end
    end
    return sender
end

local function MarkUser(sender)
    local shortName = Ambiguate(sender, "short")
    local bareName = strsplit("-", sender)  -- just "Name" without realm
    local isNew = not knownUsers[sender]
    knownUsers[shortName] = true
    knownUsers[sender] = true
    if bareName then knownUsers[bareName] = true end
    if isNew then
        for _, cb in ipairs(callbacks) do
            pcall(cb, sender)
        end
    end
end

-- ============================================================
-- Public API
-- ============================================================

--- Check if a player is known to have HearthPhone
function PhonePresence:HasAddon(name)
    return knownUsers[name] == true
end

--- Register a callback for when a new HearthPhone user is discovered
function PhonePresence:OnUserDiscovered(callback)
    table.insert(callbacks, callback)
end

--- Get the full table of known users (read-only use)
function PhonePresence:GetKnownUsers()
    return knownUsers
end

--- Ping all online friends to discover HearthPhone users
function PhonePresence:PingFriends()
    local now = GetTime()
    if now - pingCooldown < PING_INTERVAL then return end

    local myRealm = GetNormalizedRealmName() or ""
    local friends = PhoneFriends and PhoneFriends:GetList() or {}
    local sent = 0
    for _, f in ipairs(friends) do
        if f.isOnline and f.charName then
            if f.gameAccountID then
                -- BNet friends: cross-realm, cross-faction safe
                pcall(function()
                    BNSendGameData(f.gameAccountID, ADDON_PREFIX, "PING")
                end)
                sent = sent + 1
            else
                -- Character friends: only whisper if same realm
                local theirRealm = f.realmName and f.realmName:gsub("%s+", "") or myRealm
                if theirRealm == "" or theirRealm == myRealm then
                    local target = PhoneFriends:WhisperTarget(f)
                    if target and target ~= "?" then
                        pcall(function()
                            C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "PING", "WHISPER", target)
                        end)
                        sent = sent + 1
                    end
                end
            end
        end
    end
    -- Only set cooldown if we actually sent pings (friends list may not be loaded yet)
    if sent > 0 then
        pingCooldown = now
    end
end

--- Send a message to a friend, preferring BNet when available
function PhonePresence:SendToFriend(friend, prefix, message)
    if friend.gameAccountID then
        pcall(function()
            BNSendGameData(friend.gameAccountID, prefix, message)
        end)
        return true
    elseif friend.charName then
        local target = PhoneFriends:WhisperTarget(friend)
        if target and target ~= "?" then
            pcall(function()
                C_ChatInfo.SendAddonMessage(prefix, message, "WHISPER", target)
            end)
            return true
        end
    end
    return false
end

--- Find a friend entry by character name (for sending responses)
function PhonePresence:FindFriend(charName)
    local friends = PhoneFriends and PhoneFriends:GetList() or {}
    local shortName = Ambiguate(charName, "short")
    for _, f in ipairs(friends) do
        if f.charName == shortName or f.charName == charName then
            return f
        end
    end
    return nil
end

-- ============================================================
-- Message handling
-- ============================================================
local function OnPresenceMessage(prefix, message, sender)
    if prefix ~= ADDON_PREFIX then return end
    if PhonePresence.NamesMatch(sender, GetMyName()) then return end

    if message == "PING" then
        -- Respond via whisper (best effort) so they know we have HearthPhone
        pcall(function()
            C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "PONG", "WHISPER", sender)
        end)
        -- Also respond via BNet if we can find them
        local friend = PhonePresence:FindFriend(sender)
        if friend and friend.gameAccountID then
            pcall(function()
                BNSendGameData(friend.gameAccountID, ADDON_PREFIX, "PONG")
            end)
        end
        MarkUser(sender)
    elseif message == "PONG" then
        MarkUser(sender)
    end
end

-- ============================================================
-- Init (called once from HearthPhone.lua or first app that needs it)
-- ============================================================
local initialized = false

function PhonePresence:Init()
    if initialized then return end
    initialized = true

    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("BN_CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
    eventFrame:RegisterEvent("FRIENDLIST_UPDATE")
    local friendListPinged = false
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            local prefix, message, channel, sender = ...
            OnPresenceMessage(prefix, message, sender)
        elseif event == "BN_CHAT_MSG_ADDON" then
            local prefix, message, _, senderID = ...
            local sender = ResolveBNetSender(senderID)
            if sender then
                OnPresenceMessage(prefix, message, sender)
            end
        elseif (event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "FRIENDLIST_UPDATE") and not friendListPinged then
            -- Friends data just became available, do the first real ping
            local numBNet = BNGetNumFriends()
            if numBNet > 0 then
                friendListPinged = true
                PhonePresence:PingFriends()
            end
        end
    end)
end
