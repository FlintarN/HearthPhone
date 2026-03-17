-- PhoneGameChallenge - Generic PvP game invite/session framework
-- Handles: challenge, accept/decline, game data sync, forfeit
-- Games register themselves and get callbacks for state changes.

PhoneGameChallenge = {}

local ADDON_PREFIX = "PhoneGame"
local myName

-- Registered games: [gameId] = { name, onStart, onData, onEnd }
local registeredGames = {}

-- Session state
local session = {
    state = "idle",    -- idle, challenging, incoming, active
    gameId = nil,      -- which game
    opponent = nil,    -- opponent's full name
    iAmFirst = false,  -- true = I go first (challenger goes first)
}

-- Pending incoming challenge (so UI can show it)
local pendingChallenge = nil  -- { from, gameId, gameName }

-- Callbacks for the phone UI (popup, etc)
local onIncomingChallenge = nil  -- function(from, gameName)
local onChallengeResponse = nil  -- function(accepted)
local onSessionEnd = nil         -- function(reason)

-- ============================================================
-- Helpers
-- ============================================================
local function GetMyName()
    if myName then return myName end
    local name, realm = UnitFullName("player")
    realm = realm or GetNormalizedRealmName() or ""
    if realm ~= "" then
        myName = name .. "-" .. realm
    else
        myName = name
    end
    return myName
end

local function NamesMatch(a, b)
    return PhonePresence.NamesMatch(a, b)
end

local function Send(target, msgType, data)
    local payload = msgType
    if data then payload = msgType .. ":" .. data end
    C_ChatInfo.SendAddonMessage(ADDON_PREFIX, payload, "WHISPER", target)
end

-- ============================================================
-- Public API: Register a game
-- ============================================================
-- gameDef = {
--     id = "tictactoe",
--     name = "Tic-Tac-Toe",
--     onStart = function(opponent, iGoFirst) end,
--     onData = function(opponent, data) end,
--     onEnd = function(reason) end,  -- "forfeit", "decline", "busy", "timeout"
-- }
function PhoneGameChallenge:RegisterGame(gameDef)
    registeredGames[gameDef.id] = gameDef
end

-- ============================================================
-- Public API: Challenge a player
-- ============================================================
function PhoneGameChallenge:Challenge(targetName, gameId)
    if session.state ~= "idle" then
        print("|cffff4444[Games]|r Already in a game session.")
        return false
    end
    local game = registeredGames[gameId]
    if not game then
        print("|cffff4444[Games]|r Unknown game: " .. tostring(gameId))
        return false
    end

    session.state = "challenging"
    session.gameId = gameId
    session.opponent = targetName
    session.iAmFirst = true  -- challenger goes first

    Send(targetName, "CHALLENGE", gameId)

    -- Timeout after 20 seconds
    session.timeoutTimer = C_Timer.NewTimer(20, function()
        if session.state == "challenging" then
            local game2 = registeredGames[session.gameId]
            if game2 and game2.onEnd then game2.onEnd("timeout") end
            if game2 and game2.onResponse then game2.onResponse(false, "timeout")
            elseif onChallengeResponse then onChallengeResponse(false, "timeout") end
            session.state = "idle"
            session.gameId = nil
            session.opponent = nil
        end
    end)

    return true
end

-- ============================================================
-- Public API: Accept/Decline incoming challenge
-- ============================================================
function PhoneGameChallenge:AcceptChallenge()
    if session.state ~= "incoming" or not pendingChallenge then return end

    session.state = "active"
    session.iAmFirst = false  -- accepter goes second
    Send(session.opponent, "ACCEPT", session.gameId)

    local game = registeredGames[session.gameId]
    if game and game.onStart then
        game.onStart(session.opponent, false)
    end

    pendingChallenge = nil
end

function PhoneGameChallenge:DeclineChallenge()
    if session.state ~= "incoming" or not pendingChallenge then return end

    Send(session.opponent, "DECLINE", session.gameId)
    session.state = "idle"
    session.gameId = nil
    session.opponent = nil
    pendingChallenge = nil
end

-- ============================================================
-- Public API: Send game data during active session
-- ============================================================
function PhoneGameChallenge:SendGameData(data)
    if session.state ~= "active" or not session.opponent then return end
    Send(session.opponent, "GAMEDATA", data)
end

-- ============================================================
-- Public API: Forfeit / end session
-- ============================================================
function PhoneGameChallenge:Forfeit()
    if session.state == "idle" then return end
    if session.opponent then
        Send(session.opponent, "FORFEIT", session.gameId or "")
    end
    local game = registeredGames[session.gameId]
    if game and game.onEnd then game.onEnd("forfeit_self") end
    if onSessionEnd then onSessionEnd("forfeit_self") end
    session.state = "idle"
    session.gameId = nil
    session.opponent = nil
    if session.timeoutTimer then session.timeoutTimer:Cancel(); session.timeoutTimer = nil end
end

-- ============================================================
-- Public API: Cancel outgoing challenge
-- ============================================================
function PhoneGameChallenge:CancelChallenge()
    if session.state ~= "challenging" then return end
    if session.opponent then
        Send(session.opponent, "CANCEL", session.gameId or "")
    end
    if onChallengeResponse then onChallengeResponse(false, "cancelled") end
    session.state = "idle"
    session.gameId = nil
    session.opponent = nil
    if session.timeoutTimer then session.timeoutTimer:Cancel(); session.timeoutTimer = nil end
end

-- ============================================================
-- Public API: Query state
-- ============================================================
function PhoneGameChallenge:GetState()
    return session.state
end

function PhoneGameChallenge:GetOpponent()
    return session.opponent
end

function PhoneGameChallenge:GetGameId()
    return session.gameId
end

function PhoneGameChallenge:GetPendingChallenge()
    return pendingChallenge
end

function PhoneGameChallenge:IsFirst()
    return session.iAmFirst
end

function PhoneGameChallenge:GetRegisteredGames()
    return registeredGames
end

-- ============================================================
-- Public API: Set callbacks for UI integration
-- ============================================================
function PhoneGameChallenge:SetCallbacks(onIncoming, onResponse, onEnd)
    onIncomingChallenge = onIncoming
    onChallengeResponse = onResponse
    onSessionEnd = onEnd
end

-- ============================================================
-- Message handler
-- ============================================================
local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_PREFIX then return end
    if NamesMatch(sender, GetMyName()) then return end

    local msgType, data = strsplit(":", message, 2)

    if msgType == "CHALLENGE" then
        local gameId = data
        local game = registeredGames[gameId]
        if not game then
            Send(sender, "DECLINE", gameId or "")
            return
        end
        if session.state ~= "idle" then
            Send(sender, "BUSY", gameId)
            return
        end

        session.state = "incoming"
        session.gameId = gameId
        session.opponent = sender

        pendingChallenge = {
            from = sender,
            gameId = gameId,
            gameName = game.name,
        }

        if game.onIncoming then
            game.onIncoming(Ambiguate(sender, "short"), game.name)
        elseif onIncomingChallenge then
            onIncomingChallenge(Ambiguate(sender, "short"), game.name)
        end

    elseif msgType == "ACCEPT" then
        if session.state == "challenging" and NamesMatch(sender, session.opponent) then
            if session.timeoutTimer then session.timeoutTimer:Cancel(); session.timeoutTimer = nil end
            session.state = "active"
            local game = registeredGames[session.gameId]
            if game and game.onStart then
                game.onStart(session.opponent, true)
            end
            local g = registeredGames[session.gameId]
            if g and g.onResponse then g.onResponse(true)
            elseif onChallengeResponse then onChallengeResponse(true) end
        end

    elseif msgType == "DECLINE" then
        if session.state == "challenging" and NamesMatch(sender, session.opponent) then
            if session.timeoutTimer then session.timeoutTimer:Cancel(); session.timeoutTimer = nil end
            local game = registeredGames[session.gameId]
            if game and game.onEnd then game.onEnd("decline") end
            if game and game.onResponse then game.onResponse(false, "decline")
            elseif onChallengeResponse then onChallengeResponse(false, "decline") end
            session.state = "idle"
            session.gameId = nil
            session.opponent = nil
        end

    elseif msgType == "BUSY" then
        if session.state == "challenging" and NamesMatch(sender, session.opponent) then
            if session.timeoutTimer then session.timeoutTimer:Cancel(); session.timeoutTimer = nil end
            local game = registeredGames[session.gameId]
            if game and game.onEnd then game.onEnd("busy") end
            if game and game.onResponse then game.onResponse(false, "busy")
            elseif onChallengeResponse then onChallengeResponse(false, "busy") end
            session.state = "idle"
            session.gameId = nil
            session.opponent = nil
        end

    elseif msgType == "GAMEDATA" then
        if session.state == "active" and NamesMatch(sender, session.opponent) then
            local game = registeredGames[session.gameId]
            if game and game.onData then
                game.onData(sender, data)
            end
        end

    elseif msgType == "FORFEIT" then
        if NamesMatch(sender, session.opponent) then
            local game = registeredGames[session.gameId]
            if game and game.onEnd then game.onEnd("forfeit") end
            if game and game.onSessionEnd then game.onSessionEnd("forfeit")
            elseif onSessionEnd then onSessionEnd("forfeit") end
            session.state = "idle"
            session.gameId = nil
            session.opponent = nil
        end

    elseif msgType == "CANCEL" then
        if session.state == "incoming" and NamesMatch(sender, session.opponent) then
            local game = registeredGames[session.gameId]
            if game and game.onEnd then game.onEnd("cancelled") end
            session.state = "idle"
            session.gameId = nil
            session.opponent = nil
            pendingChallenge = nil
        end
    end
end

-- ============================================================
-- Init
-- ============================================================
function PhoneGameChallenge:Init()
    C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            OnAddonMessage(...)
        end
    end)
end

-- Auto-init on load
PhoneGameChallenge:Init()
