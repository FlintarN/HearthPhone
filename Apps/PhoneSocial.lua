-- PhoneSocial - Profile/Feed social app for HearthPhone
-- Twitter/Reddit-style: profiles, posts, comments, feed

PhoneSocialApp = {}

local parent
local visible = false

-- Sub-pages: "feed", "profile", "post_detail", "new_post", "user_profile"
local currentView = "feed"
local viewStack = {}  -- for back navigation

-- Currently viewed data
local selectedPostIdx = nil
local viewedUser = nil  -- author name for user_profile view
local editingPostIdx = nil  -- set when editing a post (reuses new_post view)

-- UI refs
local titleBar, backBtn, titleText
local feedFrame, profileFrame, postDetailFrame, newPostFrame, userProfileFrame
local feedScrollContent, feedRows
local profileBio, profilePostRows
local detailRows
local newPostInput

-- Class colors for author names
local CLASS_COLORS = {
    WARRIOR     = "ffc79c6e",
    PALADIN     = "fff58cba",
    HUNTER      = "ffabd473",
    ROGUE       = "fffff569",
    PRIEST      = "ffffffff",
    DEATHKNIGHT = "ffc41f3b",
    SHAMAN      = "ff0070de",
    MAGE        = "ff40c7eb",
    WARLOCK     = "ff8787ed",
    MONK        = "ff00ff96",
    DRUID       = "ffff7d0a",
    DEMONHUNTER = "ffa330c9",
    EVOKER      = "ff33937f",
}

local function GetDB()
    HearthPhoneDB = HearthPhoneDB or {}
    HearthPhoneDB.social = HearthPhoneDB.social or {}
    HearthPhoneDB.social.profile = HearthPhoneDB.social.profile or {}
    HearthPhoneDB.social.posts = HearthPhoneDB.social.posts or {}
    HearthPhoneDB.social.profiles = HearthPhoneDB.social.profiles or {}
    HearthPhoneDB.social.tombstones = HearthPhoneDB.social.tombstones or {}
    return HearthPhoneDB.social
end

local function GetMyName()
    local name = UnitName("player")
    local realm = GetRealmName()
    return name .. "-" .. realm
end

-- Track all characters on this account so we can recognize our own posts across alts
local function RegisterMyCharacter()
    local db = GetDB()
    db.myCharacters = db.myCharacters or {}
    db.myCharacters[GetMyName()] = true
end

local function IsMe(authorName)
    local db = GetDB()
    if authorName == GetMyName() then return true end
    if db.myCharacters and db.myCharacters[authorName] then return true end
    return false
end

local function GetMyClass()
    local _, cls = UnitClass("player")
    return cls or "WARRIOR"
end

local function GetClassColor(cls)
    return CLASS_COLORS[cls] or "ffcccccc"
end

local function UpdateOwnProfile()
    local db = GetDB()
    local _, cls = UnitClass("player")
    db.profiles[GetMyName()] = {
        class = cls or "",
        race = UnitRace("player") or "",
        level = UnitLevel("player") or 0,
        guild = GetGuildInfo("player") or "",
        bio = db.profile.bio or "",
    }
end

local function FormatTime(timestamp)
    local now = time()
    local diff = now - timestamp
    if diff < 60 then return "just now"
    elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
    elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
    else return math.floor(diff / 86400) .. "d ago"
    end
end

local function GenerateId()
    return time() * 1000 + math.random(999)
end

---------------------------------------------------------------------------
-- Emoji System: shortcodes → WoW inline textures
---------------------------------------------------------------------------
local EMOJI_SIZE = 14
local EMOJIS = {
    -- Faces / expressions
    { code = ":happy:",   icon = "Interface\\Icons\\INV_Valentinescandy",               label = "Happy" },
    { code = ":sad:",     icon = "Interface\\Icons\\Spell_Shadow_Possession",            label = "Sad" },
    { code = ":angry:",   icon = "Interface\\Icons\\Ability_Warrior_InnerRage",          label = "Angry" },
    { code = ":love:",    icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",        label = "Love" },
    { code = ":lol:",     icon = "Interface\\Icons\\INV_Misc_Note_06",                  label = "LOL" },
    { code = ":cool:",    icon = "Interface\\Icons\\INV_Helm_Goggles_01",               label = "Cool" },
    { code = ":think:",   icon = "Interface\\Icons\\Spell_Shadow_Brainwash",            label = "Think" },
    { code = ":sleep:",   icon = "Interface\\Icons\\Spell_Nature_Sleep",                label = "Sleep" },
    { code = ":cry:",     icon = "Interface\\Icons\\Ability_Druid_Cower",               label = "Cry" },
    -- Reactions
    { code = ":thumbsup:",icon = "Interface\\Icons\\Achievement_PVP_A_01",              label = "Thumbs Up" },
    { code = ":star:",    icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",          label = "Star" },
    { code = ":fire:",    icon = "Interface\\Icons\\Spell_Fire_Immolation",             label = "Fire" },
    { code = ":skull:",   icon = "Interface\\Icons\\Spell_Shadow_DeathCoil",            label = "Skull" },
    { code = ":heart:",   icon = "Interface\\Icons\\INV_ValentinesCandy",               label = "Heart" },
    { code = ":gem:",     icon = "Interface\\Icons\\INV_Misc_Gem_Diamond_02",           label = "Gem" },
    -- WoW themed
    { code = ":sword:",   icon = "Interface\\Icons\\INV_Sword_04",                      label = "Sword" },
    { code = ":shield:",  icon = "Interface\\Icons\\INV_Shield_09",                     label = "Shield" },
    { code = ":potion:",  icon = "Interface\\Icons\\INV_Potion_54",                     label = "Potion" },
    { code = ":gold:",    icon = "Interface\\Icons\\INV_Misc_Coin_01",                  label = "Gold" },
    { code = ":beer:",    icon = "Interface\\Icons\\INV_Drink_04",                      label = "Beer" },
    { code = ":food:",    icon = "Interface\\Icons\\INV_Misc_Food_14",                  label = "Food" },
    { code = ":mount:",   icon = "Interface\\Icons\\Ability_Mount_RidingHorse",         label = "Mount" },
    { code = ":music:",   icon = "Interface\\Icons\\INV_Misc_Drum_01",                  label = "Music" },
    -- Raid markers
    { code = ":rstar:",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1",   label = "Raid Star" },
    { code = ":rcircle:", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2",   label = "Raid Circle" },
    { code = ":rdiamond:",icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3",   label = "Raid Diamond" },
    { code = ":rtriangle:",icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4",  label = "Raid Triangle" },
    { code = ":rmoon:",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5",   label = "Raid Moon" },
    { code = ":rsquare:", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6",   label = "Raid Square" },
    { code = ":rcross:",  icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7",   label = "Raid Cross" },
    { code = ":rskull:",  icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",   label = "Raid Skull" },
}

-- Build a fast lookup from code → icon path
local EMOJI_LOOKUP = {}
for _, e in ipairs(EMOJIS) do
    EMOJI_LOOKUP[e.code] = e.icon
end

-- Replace :shortcodes: with inline textures for display
local function ReplaceEmojis(text)
    if not text then return "" end
    -- Replace emoji shortcodes
    text = text:gsub("(:[%w_]+:)", function(match)
        local icon = EMOJI_LOOKUP[match]
        if icon then
            return "|T" .. icon .. ":" .. EMOJI_SIZE .. "|t"
        end
        return match
    end)
    -- Highlight @mentions in blue
    text = text:gsub("@([%w]+)", "|cff40c0ff@%1|r")
    return text
end

-- Check if text mentions the local player (matches @CharName, case insensitive)
local function TextMentionsMe(text)
    if not text then return false end
    local myName = UnitName("player")
    if not myName then return false end
    for mention in text:gmatch("@([%w]+)") do
        if mention:lower() == myName:lower() then
            return true
        end
    end
    return false
end

-- Reusable emoji module: creates a button that opens a picker for any EditBox
local emojiPickerFrame = nil

local function ShowEmojiPicker(anchorFrame, targetEditBox)
    if emojiPickerFrame then
        emojiPickerFrame:Hide()
        emojiPickerFrame = nil
        return
    end

    local COLS = 8
    local BTN_SIZE = 20
    local PAD = 2
    local rows = math.ceil(#EMOJIS / COLS)
    local width = COLS * (BTN_SIZE + PAD) + PAD
    local height = rows * (BTN_SIZE + PAD) + PAD

    local picker = CreateFrame("Frame", nil, anchorFrame, "BackdropTemplate")
    picker:SetSize(width, height)
    picker:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -2)
    picker:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    picker:SetBackdropColor(0.1, 0.1, 0.14, 0.95)
    picker:SetBackdropBorderColor(0.4, 0.4, 0.5, 0.8)
    picker:SetFrameStrata("DIALOG")

    for idx, emoji in ipairs(EMOJIS) do
        local col = (idx - 1) % COLS
        local row = math.floor((idx - 1) / COLS)
        local btn = CreateFrame("Button", nil, picker)
        btn:SetSize(BTN_SIZE, BTN_SIZE)
        btn:SetPoint("TOPLEFT", PAD + col * (BTN_SIZE + PAD), -(PAD + row * (BTN_SIZE + PAD)))

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture(emoji.icon)

        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(emoji.label .. "  " .. emoji.code, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        btn:SetScript("OnClick", function()
            targetEditBox:Insert(emoji.code)
            targetEditBox:SetFocus()
            picker:Hide()
            emojiPickerFrame = nil
        end)
    end

    emojiPickerFrame = picker
end

-- Creates a small emoji button that can be placed anywhere.
-- Returns the button frame so the caller can position it.
local function CreateEmojiButton(parentFrame, targetEditBox, size)
    size = size or 18
    local btn = CreateFrame("Button", nil, parentFrame)
    btn:SetSize(size, size)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.3, 0.3, 0.4, 0.9)
    local ico = btn:CreateTexture(nil, "ARTWORK")
    ico:SetSize(size - 4, size - 4)
    ico:SetPoint("CENTER")
    ico:SetTexture("Interface\\Icons\\Spell_Holy_PrayerOfHealing")
    btn:SetScript("OnClick", function()
        ShowEmojiPicker(btn, targetEditBox)
    end)
    return btn
end

-- Networking constants (must be above functions that use them)
local SEP = "\001"  -- field separator (non-printable, won't appear in text)
local MAX_MSG = 250  -- safe limit under 255 bytes

-- Forward declarations for networking (defined further down)
local BroadcastToAddonUsers, SerializePost, SerializeComment, SerializeProfile

local function CreatePost(text)
    local db = GetDB()
    local post = {
        id = GenerateId(),
        author = GetMyName(),
        authorClass = GetMyClass(),
        text = text,
        timestamp = time(),
        comments = {},
        -- Future: community = nil (for subreddit-like posting)
    }
    table.insert(db.posts, 1, post)  -- newest first
    -- Broadcast to other addon users
    BroadcastToAddonUsers(SerializePost(post))
    return post
end

local function AddComment(postIdx, text)
    local db = GetDB()
    local post = db.posts[postIdx]
    if not post then return end
    local comment = {
        author = GetMyName(),
        authorClass = GetMyClass(),
        text = text,
        timestamp = time(),
    }
    table.insert(post.comments, comment)
    -- Broadcast comment to addon users
    if post.id then
        BroadcastToAddonUsers(SerializeComment(post.id, comment))
    end
end

local function EditComment(postIdx, commentIdx, newText)
    local db = GetDB()
    local post = db.posts[postIdx]
    if not post then return end
    local comment = post.comments and post.comments[commentIdx]
    if not comment then return end
    if not IsMe(comment.author) then return end
    comment.text = newText
    comment.editedAt = time()
    -- Broadcast edit with editedAt so others know this is newer
    if post.id then
        local text = newText:gsub(SEP, " ")
        local msg = "CEDIT" .. SEP .. post.id .. SEP .. comment.author .. SEP
                    .. comment.authorClass .. SEP .. comment.timestamp .. SEP
                    .. comment.editedAt .. SEP .. text
        if #msg > MAX_MSG then msg = msg:sub(1, MAX_MSG) end
        BroadcastToAddonUsers(msg)
    end
end

local function DeleteComment(postIdx, commentIdx)
    local db = GetDB()
    local post = db.posts[postIdx]
    if not post then return end
    local comment = post.comments and post.comments[commentIdx]
    if not comment then return end
    if not IsMe(comment.author) then return end
    local author = comment.author
    local ts = comment.timestamp
    local deletedAt = time()
    table.remove(post.comments, commentIdx)
    -- Store tombstone so synced comments don't resurrect it
    if post.id then
        local tombKey = post.id .. ":" .. author .. ":" .. ts
        db.tombstones[tombKey] = deletedAt
        local msg = "CDEL" .. SEP .. post.id .. SEP .. author .. SEP .. ts .. SEP .. deletedAt
        BroadcastToAddonUsers(msg)
    end
end

local function EditPost(postIdx, newText)
    local db = GetDB()
    local post = db.posts[postIdx]
    if not post then return end
    if not IsMe(post.author) then return end
    post.text = newText
    post.editedAt = time()
    -- Broadcast edit
    BroadcastToAddonUsers(SerializePost(post))
end

local function DeletePost(postIdx)
    local db = GetDB()
    local post = db.posts[postIdx]
    if not post then return end
    if not IsMe(post.author) then return end
    local deletedAt = time()
    -- Tombstone the post itself
    local postTombKey = "post:" .. post.id
    db.tombstones[postTombKey] = deletedAt
    -- Tombstone all its comments too so they don't resurrect
    for _, c in ipairs(post.comments or {}) do
        local tombKey = post.id .. ":" .. c.author .. ":" .. c.timestamp
        db.tombstones[tombKey] = deletedAt
    end
    table.remove(db.posts, postIdx)
    -- Broadcast delete
    local msg = "PDEL" .. SEP .. post.id .. SEP .. deletedAt
    BroadcastToAddonUsers(msg)
end

local function GetPostsByAuthor(authorName)
    local db = GetDB()
    local result = {}
    for i, post in ipairs(db.posts) do
        if post.author == authorName then
            table.insert(result, { idx = i, post = post })
        end
    end
    return result
end

-- Get posts from all characters on this account
local function GetMyPosts()
    local db = GetDB()
    local result = {}
    for i, post in ipairs(db.posts) do
        if IsMe(post.author) then
            table.insert(result, { idx = i, post = post })
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Addon Messaging / Sync (channel-based, like TRP3)
-- All addon users join a hidden custom channel and broadcast on it.
-- No whispers — everything goes through the shared channel.
---------------------------------------------------------------------------
local SOCIAL_PREFIX = "PhoneSocial"
local CHANNEL_NAME = "xtHearthSocial"  -- hidden addon channel (all users join)

-- Channel state
local channelIndex = nil  -- numeric index once joined

-- Throttle state
local outQueue = {}         -- queued outgoing messages
local outBusy = false
local SEND_INTERVAL = 0.15  -- seconds between each queued message
local MAX_POSTS_SYNC = 20   -- max posts to send per sync response
local MAX_POSTS_DB = 200    -- max posts stored locally
local MAX_POSTS_PER_USER = 30
local feedDirty = false
local feedRefreshTimer = nil

-- Prune DB: cap total posts and per-user posts
local function PruneDB()
    local db = GetDB()
    local authorCount = {}
    local i = 1
    while i <= #db.posts do
        local author = db.posts[i].author
        authorCount[author] = (authorCount[author] or 0) + 1
        if authorCount[author] > MAX_POSTS_PER_USER then
            table.remove(db.posts, i)
        else
            i = i + 1
        end
    end
    while #db.posts > MAX_POSTS_DB do
        table.remove(db.posts)
    end
    -- Prune old tombstones (older than 7 days)
    local cutoff = time() - (7 * 86400)
    for key, deletedAt in pairs(db.tombstones) do
        if deletedAt < cutoff then
            db.tombstones[key] = nil
        end
    end
end

-- Find post by ID
local function FindPostById(id)
    local db = GetDB()
    for i, post in ipairs(db.posts) do
        if post.id == id then return i, post end
    end
    return nil, nil
end

-- Serialize helpers (assign to forward-declared locals)
SerializePost = function(post)
    local text = (post.text or ""):gsub(SEP, " ")
    local editedAt = post.editedAt or 0
    local msg = "POST" .. SEP .. post.id .. SEP .. post.author .. SEP
                .. post.authorClass .. SEP .. post.timestamp .. SEP .. editedAt .. SEP .. text
    if #msg > MAX_MSG then msg = msg:sub(1, MAX_MSG) end
    return msg
end

SerializeComment = function(postId, comment)
    local text = (comment.text or ""):gsub(SEP, " ")
    local editedAt = comment.editedAt or 0
    local msg = "CMT" .. SEP .. postId .. SEP .. comment.author .. SEP
                .. comment.authorClass .. SEP .. comment.timestamp .. SEP .. editedAt .. SEP .. text
    if #msg > MAX_MSG then msg = msg:sub(1, MAX_MSG) end
    return msg
end

SerializeProfile = function()
    local db = GetDB()
    local _, cls = UnitClass("player")
    local race = UnitRace("player") or ""
    local lvl = tostring(UnitLevel("player") or 0)
    local guild = GetGuildInfo("player") or ""
    local bio = (db.profile.bio or ""):gsub(SEP, " ")
    local name = GetMyName()
    local msg = "PROF" .. SEP .. name .. SEP .. (cls or "") .. SEP .. race .. SEP .. lvl .. SEP .. guild .. SEP .. bio
    if #msg > MAX_MSG then msg = msg:sub(1, MAX_MSG) end
    return msg
end

-- Serialize a stored remote profile for gossip propagation
local function SerializeStoredProfile(userName, prof)
    local bio = (prof.bio or ""):gsub(SEP, " ")
    local msg = "PROF" .. SEP .. userName .. SEP .. (prof.class or "") .. SEP
                .. (prof.race or "") .. SEP .. tostring(prof.level or 0) .. SEP
                .. (prof.guild or "") .. SEP .. bio
    if #msg > MAX_MSG then msg = msg:sub(1, MAX_MSG) end
    return msg
end

-- Get channel index (refresh if needed)
local function GetChannelIndex()
    if channelIndex then return channelIndex end
    local id = GetChannelName(CHANNEL_NAME)
    if id and id > 0 then
        channelIndex = id
        return id
    end
    return nil
end

-- Send a message on the hidden channel (queued + throttled)
local function QueueSend(message)
    table.insert(outQueue, message)
end

local function DrainQueue()
    if outBusy then return end
    if #outQueue == 0 then return end
    outBusy = true
    local function SendNext()
        if #outQueue == 0 then
            outBusy = false
            return
        end
        local msg = table.remove(outQueue, 1)
        local idx = GetChannelIndex()
        if idx then
            pcall(function()
                C_ChatInfo.SendAddonMessage(SOCIAL_PREFIX, msg, "CHANNEL", idx)
            end)
        end
        C_Timer.After(SEND_INTERVAL, SendNext)
    end
    SendNext()
end

-- Broadcast to the channel (one message reaches everyone)
BroadcastToAddonUsers = function(message)
    QueueSend(message)
    DrainQueue()
end

-- Insert a remote post if we don't already have it
local function InsertRemotePost(id, author, authorClass, timestamp, editedAt, text)
    -- Check post tombstone — don't resurrect deleted posts
    local db = GetDB()
    local postTombKey = "post:" .. id
    if db.tombstones[postTombKey] then return false end

    local existingIdx, existingPost = FindPostById(id)
    if existingPost then
        -- Already have it — only update if incoming is newer edit
        local localEdited = existingPost.editedAt or 0
        local remoteEdited = editedAt or 0
        if remoteEdited > localEdited then
            existingPost.text = text
            existingPost.editedAt = editedAt
            return true
        end
        return false
    end

    local post = {
        id = id,
        author = author,
        authorClass = authorClass,
        text = text,
        timestamp = timestamp,
        editedAt = editedAt,
        comments = {},
    }
    local inserted = false
    for i, existing in ipairs(db.posts) do
        if timestamp > existing.timestamp then
            table.insert(db.posts, i, post)
            inserted = true
            break
        end
    end
    if not inserted then
        table.insert(db.posts, post)
    end
    return true
end

-- Insert a remote comment on a post we have
local function InsertRemoteComment(postId, author, authorClass, timestamp, editedAt, text)
    local _, post = FindPostById(postId)
    if not post then return false end

    -- Check tombstones — don't resurrect deleted comments
    local db = GetDB()
    local tombKey = postId .. ":" .. author .. ":" .. timestamp
    local tombstone = db.tombstones[tombKey]
    if tombstone then
        -- Only accept if editedAt is after deletion (shouldn't happen, but safe)
        if not editedAt or editedAt == 0 or editedAt <= tombstone then
            return false
        end
    end

    -- Check if comment already exists
    for _, c in ipairs(post.comments) do
        if c.author == author and c.timestamp == timestamp then
            -- Already have it — only update if incoming is newer edit
            local localEdited = c.editedAt or 0
            local remoteEdited = editedAt or 0
            if remoteEdited > localEdited then
                c.text = text
                c.editedAt = editedAt
                return true
            end
            return false
        end
    end

    table.insert(post.comments, {
        author = author,
        authorClass = authorClass,
        text = text,
        timestamp = timestamp,
        editedAt = editedAt,
    })
    return true
end

-- Handle SYNC/HELLO: broadcast our posts back on the channel (throttled).
-- Everyone receives them but duplicates are ignored via dedup.
local function HandleSyncRequest(sender, sinceTimestamp)
    local db = GetDB()
    local ts = tonumber(sinceTimestamp) or 0
    local count = 0
    for _, post in ipairs(db.posts) do
        if post.timestamp > ts and count < MAX_POSTS_SYNC then
            QueueSend(SerializePost(post))
            for _, comment in ipairs(post.comments or {}) do
                QueueSend(SerializeComment(post.id, comment))
            end
            count = count + 1
        end
    end
    -- Also share known profiles (gossip propagation)
    for userName, prof in pairs(db.profiles) do
        QueueSend(SerializeStoredProfile(userName, prof))
    end
    -- Share tombstones so deleted posts/comments stay dead
    for tombKey, deletedAt in pairs(db.tombstones) do
        if tombKey:sub(1, 5) == "post:" then
            -- Post tombstone
            local postId = tombKey:sub(6)
            local msg = "PDEL" .. SEP .. postId .. SEP .. deletedAt
            QueueSend(msg)
        else
            -- Comment tombstone
            local postId, author, timestamp = strsplit(":", tombKey, 3)
            if postId and author and timestamp then
                local msg = "CDEL" .. SEP .. postId .. SEP .. author .. SEP .. timestamp .. SEP .. deletedAt
                QueueSend(msg)
            end
        end
    end
    DrainQueue()
end

-- Batch feed refresh
local function MarkFeedDirty()
    feedDirty = true
    if feedRefreshTimer then return end
    feedRefreshTimer = C_Timer.After(0.5, function()
        feedRefreshTimer = nil
        if feedDirty and visible then
            feedDirty = false
            if currentView == "feed" then
                PhoneSocialApp:RefreshFeed()
            elseif currentView == "post_detail" then
                PhoneSocialApp:RefreshPostDetail()
            end
        end
    end)
end

-- Incoming addon message handler (works for both CHANNEL and WHISPER)
local function OnSocialMessage(prefix, message, channel, sender)
    if prefix ~= SOCIAL_PREFIX then return end
    if sender == GetMyName() then return end

    local msgType, rest = strsplit(SEP, message, 2)

    if msgType == "POST" then
        local id, author, authorClass, timestamp, editedAt, text = strsplit(SEP, rest, 6)
        id = tonumber(id)
        timestamp = tonumber(timestamp)
        editedAt = tonumber(editedAt) or 0
        if editedAt == 0 then editedAt = nil end
        if id and author and authorClass and timestamp and text then
            if timestamp > time() + 60 then return end
            if InsertRemotePost(id, author, authorClass, timestamp, editedAt, text) then
                PruneDB()
                MarkFeedDirty()
            end
            -- Notify if this post mentions me
            if TextMentionsMe(text) and HearthPhoneNotify then
                local shortAuthor = Ambiguate(author, "short")
                HearthPhoneNotify("[Social] " .. shortAuthor, "mentioned you: " .. text:sub(1, 30), "social:" .. id)
            end
        end

    elseif msgType == "CMT" then
        local postId, author, authorClass, timestamp, editedAt, text = strsplit(SEP, rest, 6)
        postId = tonumber(postId)
        timestamp = tonumber(timestamp)
        editedAt = tonumber(editedAt) or 0
        if editedAt == 0 then editedAt = nil end
        if postId and author and authorClass and timestamp and text then
            if timestamp > time() + 60 then return end
            if InsertRemoteComment(postId, author, authorClass, timestamp, editedAt, text) then
                PruneDB()
                MarkFeedDirty()
            end
            -- Notify if this comment mentions me
            if TextMentionsMe(text) and HearthPhoneNotify then
                local shortAuthor = Ambiguate(author, "short")
                HearthPhoneNotify("[Social] " .. shortAuthor, "mentioned you: " .. text:sub(1, 30), "social:" .. postId)
            end
        end

    elseif msgType == "CEDIT" then
        local postId, author, authorClass, timestamp, editedAt, newText = strsplit(SEP, rest, 6)
        postId = tonumber(postId)
        timestamp = tonumber(timestamp)
        editedAt = tonumber(editedAt) or 0
        if postId and author and timestamp and newText and editedAt > 0 then
            local _, post = FindPostById(postId)
            if post and post.comments then
                for _, c in ipairs(post.comments) do
                    if c.author == author and c.timestamp == timestamp then
                        local localEdited = c.editedAt or 0
                        if editedAt > localEdited then
                            c.text = newText
                            c.editedAt = editedAt
                            MarkFeedDirty()
                        end
                        break
                    end
                end
            end
        end

    elseif msgType == "CDEL" then
        local postId, author, timestamp, deletedAt = strsplit(SEP, rest, 4)
        postId = tonumber(postId)
        timestamp = tonumber(timestamp)
        deletedAt = tonumber(deletedAt) or time()
        if postId and author and timestamp then
            -- Store tombstone
            local db = GetDB()
            local tombKey = postId .. ":" .. author .. ":" .. timestamp
            local existing = db.tombstones[tombKey]
            if not existing or deletedAt > existing then
                db.tombstones[tombKey] = deletedAt
            end
            -- Remove the comment locally
            local _, post = FindPostById(postId)
            if post and post.comments then
                for i, c in ipairs(post.comments) do
                    if c.author == author and c.timestamp == timestamp then
                        table.remove(post.comments, i)
                        MarkFeedDirty()
                        break
                    end
                end
            end
        end

    elseif msgType == "PDEL" then
        local postId, deletedAt = strsplit(SEP, rest, 2)
        postId = tonumber(postId)
        deletedAt = tonumber(deletedAt) or time()
        if postId then
            local db = GetDB()
            local postTombKey = "post:" .. postId
            local existing = db.tombstones[postTombKey]
            if not existing or deletedAt > existing then
                db.tombstones[postTombKey] = deletedAt
            end
            -- Remove post and tombstone its comments
            local idx, post = FindPostById(postId)
            if post then
                for _, c in ipairs(post.comments or {}) do
                    local tombKey = postId .. ":" .. c.author .. ":" .. c.timestamp
                    db.tombstones[tombKey] = deletedAt
                end
                table.remove(db.posts, idx)
                MarkFeedDirty()
            end
        end

    elseif msgType == "SYNC" then
        HandleSyncRequest(sender, rest)

    elseif msgType == "PROF" then
        local profUser, cls, race, lvl, guild, bio = strsplit(SEP, rest, 6)
        if profUser and profUser ~= "" and profUser ~= GetMyName() then
            GetDB().profiles[profUser] = {
                class = cls or "",
                race = race or "",
                level = tonumber(lvl) or 0,
                guild = guild or "",
                bio = bio or "",
            }
            -- Refresh user profile view if we're looking at this person
            if currentView == "user_profile" and viewedUser == profUser then
                PhoneSocialApp:RefreshUserProfile()
            end
        end

    elseif msgType == "HELLO" then
        -- Someone joined and broadcast their newest timestamp.
        HandleSyncRequest(sender, rest)
        -- Send our profile so they can see it
        QueueSend(SerializeProfile())
        DrainQueue()
    end
end

-- Join the hidden addon channel and hide it from chat frames
local function JoinSocialChannel()
    JoinChannelByName(CHANNEL_NAME)
    channelIndex = nil  -- force refresh
    local idx = GetChannelIndex()
    if idx then
        -- Hide this channel from all chat frames so the user doesn't see it
        for i = 1, 10 do
            local cf = _G["ChatFrame" .. i]
            if cf then
                pcall(ChatFrame_RemoveChannel, cf, CHANNEL_NAME)
            end
        end
    end
end

-- Broadcast a HELLO on the channel, existing users will see it and can
-- respond with posts we're missing
local function BroadcastHello()
    local db = GetDB()
    local newest = 0
    for _, post in ipairs(db.posts) do
        if post.timestamp > newest then newest = post.timestamp end
    end
    -- HELLO contains our newest timestamp so others know what we need
    QueueSend("HELLO" .. SEP .. newest)
    -- Also broadcast our profile so others can see it
    QueueSend(SerializeProfile())
    DrainQueue()
end

---------------------------------------------------------------------------
-- UI Helpers
---------------------------------------------------------------------------
local function CreateSeparator(parentFrame, offsetY)
    local sep = parentFrame:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 4, offsetY)
    sep:SetPoint("TOPRIGHT", -4, offsetY)
    sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep:SetVertexColor(0.25, 0.25, 0.30, 0.5)
    return sep
end

local function MakeScrollFrame(parentFrame)
    local scroll = CreateFrame("ScrollFrame", nil, parentFrame)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(maxS, math.max(0, cur - delta * 25)))
    end)
    return scroll, content
end

---------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------
local function ShowView(view, skipPush)
    if not skipPush and currentView ~= view then
        table.insert(viewStack, currentView)
    end
    currentView = view

    if feedFrame then feedFrame:SetShown(view == "feed") end
    if profileFrame then profileFrame:SetShown(view == "profile") end
    if postDetailFrame then postDetailFrame:SetShown(view == "post_detail") end
    if newPostFrame then newPostFrame:SetShown(view == "new_post") end
    if userProfileFrame then userProfileFrame:SetShown(view == "user_profile") end

    backBtn:SetShown(view ~= "feed")

    if view == "feed" then
        titleText:SetText("|cff4488ffFeed|r")
    elseif view == "profile" then
        titleText:SetText("|cff44cc88My Profile|r")
    elseif view == "post_detail" then
        titleText:SetText("|cffccccccPost|r")
    elseif view == "new_post" then
        titleText:SetText(editingPostIdx and "|cffeeee44Edit Post|r" or "|cffeeee44New Post|r")
    elseif view == "user_profile" then
        titleText:SetText("|cff4488ff" .. (viewedUser or "User") .. "|r")
    end
end

local GoBack  -- forward declaration

GoBack = function()
    if #viewStack > 0 then
        local prev = table.remove(viewStack)
        ShowView(prev, true)  -- skipPush
        -- Refresh the view we're going back to
        if prev == "feed" then PhoneSocialApp:RefreshFeed() end
        if prev == "post_detail" then PhoneSocialApp:RefreshPostDetail() end
        if prev == "profile" then PhoneSocialApp:RefreshProfile() end
        if prev == "user_profile" then PhoneSocialApp:RefreshUserProfile() end
    else
        ShowView("feed", true)
        PhoneSocialApp:RefreshFeed()
    end
end

-- Navigate to edit a post (reuses new_post view in edit mode)
local function StartEditPost(postIdx)
    editingPostIdx = postIdx
    ShowView("new_post")
    PhoneSocialApp:RefreshNewPost()
end

-- Delete a post and refresh current view
local function StartDeletePost(postIdx)
    DeletePost(postIdx)
    if currentView == "post_detail" then
        GoBack()
    elseif currentView == "feed" then
        PhoneSocialApp:RefreshFeed()
    elseif currentView == "profile" then
        PhoneSocialApp:RefreshProfile()
    elseif currentView == "user_profile" then
        PhoneSocialApp:RefreshUserProfile()
    end
end

---------------------------------------------------------------------------
-- Feed View
---------------------------------------------------------------------------
local ROW_HEIGHT = 46
local MAX_ROWS = 40

local function BuildFeed(parentFrame)
    local topBar = CreateFrame("Frame", nil, parentFrame)
    topBar:SetHeight(22)
    topBar:SetPoint("TOPLEFT", 0, 0)
    topBar:SetPoint("TOPRIGHT", 0, 0)

    -- Tab buttons
    local feedTabBtn = CreateFrame("Button", nil, topBar)
    feedTabBtn:SetSize(50, 18)
    feedTabBtn:SetPoint("LEFT", 4, 0)
    local feedTabBg = feedTabBtn:CreateTexture(nil, "BACKGROUND")
    feedTabBg:SetAllPoints()
    feedTabBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    feedTabBg:SetVertexColor(0.2, 0.35, 0.6, 0.8)
    local feedTabTxt = feedTabBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    feedTabTxt:SetPoint("CENTER")
    local ftf = feedTabTxt:GetFont()
    if ftf then feedTabTxt:SetFont(ftf, 9, "OUTLINE") end
    feedTabTxt:SetText("Feed")
    feedTabBtn:SetScript("OnClick", function()
        viewStack = {}
        ShowView("feed", true)
        PhoneSocialApp:RefreshFeed()
    end)

    local profileTabBtn = CreateFrame("Button", nil, topBar)
    profileTabBtn:SetSize(50, 18)
    profileTabBtn:SetPoint("LEFT", feedTabBtn, "RIGHT", 4, 0)
    local profileTabBg = profileTabBtn:CreateTexture(nil, "BACKGROUND")
    profileTabBg:SetAllPoints()
    profileTabBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    profileTabBg:SetVertexColor(0.2, 0.5, 0.35, 0.8)
    local profileTabTxt = profileTabBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    profileTabTxt:SetPoint("CENTER")
    local ptf = profileTabTxt:GetFont()
    if ptf then profileTabTxt:SetFont(ptf, 9, "OUTLINE") end
    profileTabTxt:SetText("Profile")
    profileTabBtn:SetScript("OnClick", function()
        viewStack = {}
        ShowView("profile", true)
        PhoneSocialApp:RefreshProfile()
    end)

    -- New Post button
    local newBtn = CreateFrame("Button", nil, topBar)
    newBtn:SetSize(14, 14)
    newBtn:SetPoint("RIGHT", -2, 0)
    local newBg = newBtn:CreateTexture(nil, "BACKGROUND")
    newBg:SetAllPoints()
    newBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    newBg:SetVertexColor(0.3, 0.5, 0.8, 0.9)
    local newTxt = newBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    newTxt:SetPoint("CENTER", 0, 1)
    local nf = newTxt:GetFont()
    if nf then newTxt:SetFont(nf, 10, "OUTLINE") end
    newTxt:SetText("+")
    newBtn:SetScript("OnClick", function()
        editingPostIdx = nil
        ShowView("new_post")
        PhoneSocialApp:RefreshNewPost()
    end)

    CreateSeparator(parentFrame, -22)

    -- Scroll area
    local scrollContainer = CreateFrame("Frame", nil, parentFrame)
    scrollContainer:SetPoint("TOPLEFT", 0, -24)
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 0)

    local scroll, content = MakeScrollFrame(scrollContainer)
    feedScrollContent = content

    feedRows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, content)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.12, 0.12, 0.16, (i % 2 == 0) and 0.4 or 0.2)

        local authorFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        authorFs:SetPoint("TOPLEFT", 4, -3)
        local af = authorFs:GetFont()
        if af then authorFs:SetFont(af, 9, "OUTLINE") end
        row.authorFs = authorFs

        local timeFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        timeFs:SetPoint("TOPRIGHT", -4, -3)
        local tf = timeFs:GetFont()
        if tf then timeFs:SetFont(tf, 8, "OUTLINE") end
        timeFs:SetTextColor(0.5, 0.5, 0.5, 1)
        row.timeFs = timeFs

        local textFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        textFs:SetPoint("TOPLEFT", 4, -14)
        textFs:SetPoint("RIGHT", -4, 0)
        textFs:SetJustifyH("LEFT")
        textFs:SetWordWrap(true)
        textFs:SetMaxLines(2)
        local txf = textFs:GetFont()
        if txf then textFs:SetFont(txf, 9, "") end
        textFs:SetTextColor(0.85, 0.85, 0.85, 1)
        row.textFs = textFs

        local commentFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        commentFs:SetPoint("BOTTOMLEFT", 4, 3)
        local cf = commentFs:GetFont()
        if cf then commentFs:SetFont(cf, 8, "OUTLINE") end
        commentFs:SetTextColor(0.5, 0.6, 0.8, 1)
        row.commentFs = commentFs

        -- Edit/Delete buttons (own posts only, wired in RefreshFeed)
        local editPBtn = CreateFrame("Button", nil, row)
        editPBtn:SetSize(28, 14)
        editPBtn:SetPoint("BOTTOMRIGHT", -34, 3)
        local epBg = editPBtn:CreateTexture(nil, "BACKGROUND")
        epBg:SetAllPoints()
        epBg:SetColorTexture(0.3, 0.4, 0.55, 0.5)
        local epFs = editPBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        epFs:SetPoint("CENTER")
        local epf = epFs:GetFont()
        if epf then epFs:SetFont(epf, 8, "OUTLINE") end
        epFs:SetText("|cff88aaccEdit|r")
        editPBtn:Hide()
        row.editPostBtn = editPBtn

        local delPBtn = CreateFrame("Button", nil, row)
        delPBtn:SetSize(26, 14)
        delPBtn:SetPoint("BOTTOMRIGHT", -4, 3)
        local dpBg = delPBtn:CreateTexture(nil, "BACKGROUND")
        dpBg:SetAllPoints()
        dpBg:SetColorTexture(0.55, 0.2, 0.2, 0.5)
        local dpFs = delPBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        dpFs:SetPoint("CENTER")
        local dpf = dpFs:GetFont()
        if dpf then dpFs:SetFont(dpf, 8, "OUTLINE") end
        dpFs:SetText("|cffcc4444Del.|r")
        delPBtn:Hide()
        row.delPostBtn = delPBtn

        row:SetScript("OnClick", function()
            if row.postIdx then
                selectedPostIdx = row.postIdx
                ShowView("post_detail")
                PhoneSocialApp:RefreshPostDetail()
            end
        end)

        row:Hide()
        feedRows[i] = row
    end
end

function PhoneSocialApp:RefreshFeed()
    local db = GetDB()
    local posts = db.posts
    local myName = GetMyName()

    local contentWidth = feedScrollContent:GetParent():GetWidth() - 12
    if contentWidth < 20 then contentWidth = 120 end
    feedScrollContent:SetWidth(contentWidth)

    for i = 1, MAX_ROWS do
        local row = feedRows[i]
        local post = posts[i]
        if post then
            row:SetWidth(contentWidth)
            local cc = GetClassColor(post.authorClass)
            row.authorFs:SetText("|c" .. cc .. post.author .. "|r")
            row.timeFs:SetText(FormatTime(post.timestamp))
            row.textFs:SetText(ReplaceEmojis(post.text))
            local numComments = post.comments and #post.comments or 0
            if numComments > 0 then
                row.commentFs:SetText(numComments .. " comment" .. (numComments > 1 and "s" or ""))
            else
                row.commentFs:SetText("")
            end
            row.postIdx = i
            row:Show()

            if IsMe(post.author) then
                row.editPostBtn:Show()
                row.delPostBtn:Show()
                local idx = i
                row.editPostBtn:SetScript("OnClick", function() StartEditPost(idx) end)
                row.delPostBtn:SetScript("OnClick", function() StartDeletePost(idx) end)
            else
                row.editPostBtn:Hide()
                row.delPostBtn:Hide()
            end
        else
            row:Hide()
        end
    end

    local totalH = math.max(1, #posts * ROW_HEIGHT)
    feedScrollContent:SetHeight(totalH)
end

---------------------------------------------------------------------------
-- Profile View
---------------------------------------------------------------------------
local function BuildProfile(parentFrame)
    -- Character info header
    local infoFrame = CreateFrame("Frame", nil, parentFrame)
    infoFrame:SetHeight(124)
    infoFrame:SetPoint("TOPLEFT", 0, 0)
    infoFrame:SetPoint("TOPRIGHT", 0, 0)

    local nameFs = infoFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameFs:SetPoint("TOPLEFT", 6, -6)
    local nf = nameFs:GetFont()
    if nf then nameFs:SetFont(nf, 12, "OUTLINE") end
    infoFrame.nameFs = nameFs

    local infoFs = infoFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    infoFs:SetPoint("TOPLEFT", 6, -24)
    local inf = infoFs:GetFont()
    if inf then infoFs:SetFont(inf, 10, "OUTLINE") end
    infoFs:SetTextColor(0.7, 0.7, 0.7, 1)
    infoFrame.infoFs = infoFs

    local guildFs = infoFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    guildFs:SetPoint("TOPLEFT", 6, -38)
    local gf = guildFs:GetFont()
    if gf then guildFs:SetFont(gf, 9, "OUTLINE") end
    guildFs:SetTextColor(0.5, 0.8, 0.5, 1)
    infoFrame.guildFs = guildFs

    -- Bio section
    local bioLabel = infoFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bioLabel:SetPoint("TOPLEFT", 6, -56)
    local bf = bioLabel:GetFont()
    if bf then bioLabel:SetFont(bf, 9, "OUTLINE") end
    bioLabel:SetText("|cff888888Bio:|r")

    -- Edit / Save button
    local editBtn = CreateFrame("Button", nil, infoFrame, "UIPanelButtonTemplate")
    editBtn:SetSize(40, 16)
    editBtn:SetPoint("TOPRIGHT", -4, -54)
    editBtn:SetText("Edit")
    editBtn:SetNormalFontObject("GameFontNormalSmall")
    infoFrame.editBtn = editBtn

    -- Multiline bio box with backdrop
    local bioContainer = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
    bioContainer:SetPoint("TOPLEFT", 6, -74)
    bioContainer:SetPoint("RIGHT", -6, 0)
    bioContainer:SetHeight(48)
    bioContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bioContainer:SetBackdropColor(0.08, 0.08, 0.1, 0.8)
    bioContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)

    local bioBox = CreateFrame("EditBox", nil, bioContainer)
    bioBox:SetPoint("TOPLEFT", 4, -4)
    bioBox:SetPoint("BOTTOMRIGHT", -4, 4)
    bioBox:SetAutoFocus(false)
    bioBox:SetMultiLine(true)
    local bbf = bioBox:GetFont() or "Fonts\\FRIZQT__.TTF"
    bioBox:SetFont(bbf, 9, "")
    bioBox:SetTextColor(0.9, 0.9, 0.9, 1)
    bioBox:SetMaxLetters(200)
    bioBox:EnableMouse(false)
    bioBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    bioBox:SetScript("OnEditFocusGained", function(self)
        self:SetCursorPosition(#(self:GetText() or ""))
    end)
    profileBio = bioBox

    -- Emoji button for bio (hidden until edit mode)
    local bioEmojiBtn = CreateEmojiButton(parentFrame, bioBox, 16)
    bioEmojiBtn:SetPoint("TOPLEFT", bioContainer, "BOTTOMLEFT", 0, -2)
    bioEmojiBtn:Hide()

    local sepProfile = CreateSeparator(parentFrame, -126)
    local postsLabel = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    postsLabel:SetPoint("TOPLEFT", 6, -132)

    -- Edit mode toggle logic
    local profileEditing = false
    -- Posts scroll
    local scrollContainer = CreateFrame("Frame", nil, parentFrame)
    scrollContainer:SetPoint("TOPLEFT", 0, -146)
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 0)

    local function UpdateProfileLayout()
        if profileEditing then
            -- Push separator, label, and scroll down to make room for emoji button
            sepProfile:SetPoint("TOPLEFT", 4, -146)
            sepProfile:SetPoint("TOPRIGHT", -4, -146)
            postsLabel:SetPoint("TOPLEFT", 6, -152)
            scrollContainer:SetPoint("TOPLEFT", 0, -166)
        else
            sepProfile:SetPoint("TOPLEFT", 4, -126)
            sepProfile:SetPoint("TOPRIGHT", -4, -126)
            postsLabel:SetPoint("TOPLEFT", 6, -132)
            scrollContainer:SetPoint("TOPLEFT", 0, -146)
        end
    end

    editBtn:SetScript("OnClick", function()
        profileEditing = not profileEditing
        if profileEditing then
            editBtn:SetText("Save")
            bioBox:EnableMouse(true)
            bioBox:SetTextColor(1, 1, 1, 1)
            bioContainer:SetBackdropBorderColor(0.4, 0.6, 1, 0.8)
            bioEmojiBtn:Show()
        else
            editBtn:SetText("Edit")
            local db = GetDB()
            db.profile.bio = bioBox:GetText()
            UpdateOwnProfile()
            bioBox:ClearFocus()
            bioBox:EnableMouse(false)
            -- Broadcast updated profile to other users
            QueueSend(SerializeProfile())
            DrainQueue()
            bioBox:SetTextColor(0.9, 0.9, 0.9, 1)
            bioContainer:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.6)
            bioEmojiBtn:Hide()
        end
        UpdateProfileLayout()
    end)

    -- My posts label
    local plf = postsLabel:GetFont()
    if plf then postsLabel:SetFont(plf, 9, "OUTLINE") end
    postsLabel:SetText("|cffaaaaaamyposts|r")
    infoFrame.postsLabel = postsLabel

    local scroll, content = MakeScrollFrame(scrollContainer)
    infoFrame.scrollContent = content

    profilePostRows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, content)
        row:SetHeight(40)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * 40))
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.12, 0.12, 0.16, (i % 2 == 0) and 0.4 or 0.2)

        local timeFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        timeFs:SetPoint("TOPRIGHT", -4, -2)
        local tf = timeFs:GetFont()
        if tf then timeFs:SetFont(tf, 9, "OUTLINE") end
        timeFs:SetTextColor(0.5, 0.5, 0.5, 1)
        row.timeFs = timeFs

        local textFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        textFs:SetPoint("TOPLEFT", 4, -3)
        textFs:SetPoint("RIGHT", -30, 0)
        textFs:SetJustifyH("LEFT")
        textFs:SetWordWrap(true)
        textFs:SetMaxLines(2)
        local txf = textFs:GetFont()
        if txf then textFs:SetFont(txf, 9, "") end
        textFs:SetTextColor(0.85, 0.85, 0.85, 1)
        row.textFs = textFs

        local commentFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        commentFs:SetPoint("BOTTOMLEFT", 4, 2)
        local cf = commentFs:GetFont()
        if cf then commentFs:SetFont(cf, 9, "OUTLINE") end
        commentFs:SetTextColor(0.5, 0.6, 0.8, 1)
        row.commentFs = commentFs

        -- Edit/Delete buttons (always shown — these are your own posts)
        local editPBtn = CreateFrame("Button", nil, row)
        editPBtn:SetSize(28, 14)
        editPBtn:SetPoint("BOTTOMRIGHT", -34, 2)
        local epBg = editPBtn:CreateTexture(nil, "BACKGROUND")
        epBg:SetAllPoints()
        epBg:SetColorTexture(0.3, 0.4, 0.55, 0.5)
        local epFs = editPBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        epFs:SetPoint("CENTER")
        local epf = epFs:GetFont()
        if epf then epFs:SetFont(epf, 8, "OUTLINE") end
        epFs:SetText("|cff88aaccEdit|r")
        row.editPostBtn = editPBtn

        local delPBtn = CreateFrame("Button", nil, row)
        delPBtn:SetSize(26, 14)
        delPBtn:SetPoint("BOTTOMRIGHT", -4, 2)
        local dpBg = delPBtn:CreateTexture(nil, "BACKGROUND")
        dpBg:SetAllPoints()
        dpBg:SetColorTexture(0.55, 0.2, 0.2, 0.5)
        local dpFs = delPBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        dpFs:SetPoint("CENTER")
        local dpf = dpFs:GetFont()
        if dpf then dpFs:SetFont(dpf, 8, "OUTLINE") end
        dpFs:SetText("|cffcc4444Del.|r")
        row.delPostBtn = delPBtn

        row:SetScript("OnClick", function()
            if row.postIdx then
                selectedPostIdx = row.postIdx
                ShowView("post_detail")
                PhoneSocialApp:RefreshPostDetail()
            end
        end)

        row:Hide()
        profilePostRows[i] = row
    end

    profileFrame = parentFrame
    profileFrame.info = infoFrame
end

function PhoneSocialApp:RefreshProfile()
    local db = GetDB()
    local info = profileFrame.info

    local myName = GetMyName()
    local cc = GetClassColor(GetMyClass())
    info.nameFs:SetText("|c" .. cc .. myName .. "|r")

    local lvl = UnitLevel("player")
    local _, cls = UnitClass("player")
    local race = UnitRace("player")
    local guild = GetGuildInfo("player") or "No Guild"
    info.infoFs:SetText("Lvl " .. lvl .. " " .. (race or "") .. " " .. (cls or ""))
    info.guildFs:SetText("<" .. guild .. ">")

    profileBio:SetText(ReplaceEmojis(db.profile.bio or ""))

    local myPosts = GetMyPosts()
    info.postsLabel:SetText("|cffaaaaaaMy Posts (" .. #myPosts .. ")|r")

    local contentWidth = info.scrollContent:GetParent():GetWidth() - 12
    if contentWidth < 20 then contentWidth = 120 end
    info.scrollContent:SetWidth(contentWidth)

    for i = 1, MAX_ROWS do
        local row = profilePostRows[i]
        local entry = myPosts[i]
        if entry then
            row:SetWidth(contentWidth)
            row.timeFs:SetText(FormatTime(entry.post.timestamp))
            row.textFs:SetText(ReplaceEmojis(entry.post.text))
            local numC = entry.post.comments and #entry.post.comments or 0
            row.commentFs:SetText(numC > 0 and (numC .. " comment" .. (numC > 1 and "s" or "")) or "")
            row.postIdx = entry.idx
            local idx = entry.idx
            row.editPostBtn:SetScript("OnClick", function() StartEditPost(idx) end)
            row.delPostBtn:SetScript("OnClick", function() StartDeletePost(idx) end)
            row:Show()
        else
            row:Hide()
        end
    end

    info.scrollContent:SetHeight(math.max(1, #myPosts * 40))
end

---------------------------------------------------------------------------
-- Post Detail View (post + comments)
---------------------------------------------------------------------------
local function BuildPostDetail(parentFrame)
    -- Comment input bar pinned at bottom
    local inputBar = CreateFrame("Frame", nil, parentFrame)
    inputBar:SetHeight(26)
    inputBar:SetPoint("BOTTOMLEFT", 0, 0)
    inputBar:SetPoint("BOTTOMRIGHT", 0, 0)
    inputBar:SetFrameLevel(parentFrame:GetFrameLevel() + 5)
    local inputBg = inputBar:CreateTexture(nil, "BACKGROUND")
    inputBg:SetAllPoints()
    inputBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    inputBg:SetVertexColor(0.15, 0.15, 0.20, 0.9)

    local cmtEmojiBtn = CreateEmojiButton(inputBar, nil, 18)
    cmtEmojiBtn:SetPoint("LEFT", 4, 0)

    local commentBox = CreateFrame("EditBox", nil, inputBar, "InputBoxTemplate")
    commentBox:SetHeight(18)
    commentBox:SetPoint("LEFT", cmtEmojiBtn, "RIGHT", 6, 0)
    commentBox:SetPoint("RIGHT", -34, 0)
    commentBox:SetAutoFocus(false)
    local cbf = commentBox:GetFont()
    if cbf then commentBox:SetFont(cbf, 8, "") end
    commentBox:SetMaxLetters(280)
    commentBox:SetScript("OnEditFocusGained", function(self)
        self:SetCursorPosition(#(self:GetText() or ""))
    end)

    -- Wire emoji button to the comment box now that it exists
    cmtEmojiBtn:SetScript("OnClick", function()
        ShowEmojiPicker(cmtEmojiBtn, commentBox)
    end)

    local sendBtn = CreateFrame("Button", nil, inputBar)
    sendBtn:SetSize(28, 18)
    sendBtn:SetPoint("RIGHT", -3, 0)
    local sendBg = sendBtn:CreateTexture(nil, "BACKGROUND")
    sendBg:SetAllPoints()
    sendBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    sendBg:SetVertexColor(0.2, 0.4, 0.7, 0.9)
    local sendTxt = sendBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    sendTxt:SetPoint("CENTER")
    local sf = sendTxt:GetFont()
    if sf then sendTxt:SetFont(sf, 8, "OUTLINE") end
    sendTxt:SetText("Send")

    local function DoSend()
        local txt = commentBox:GetText()
        if txt and txt:trim() ~= "" and selectedPostIdx then
            AddComment(selectedPostIdx, txt:trim())
            commentBox:SetText("")
            commentBox:ClearFocus()
            PhoneSocialApp:RefreshPostDetail()
        end
    end
    sendBtn:SetScript("OnClick", DoSend)
    commentBox:SetScript("OnEnterPressed", DoSend)
    commentBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Single scroll frame for the entire view (post + comments)
    local scrollContainer = CreateFrame("Frame", nil, parentFrame)
    scrollContainer:SetPoint("TOPLEFT", 0, 0)
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 28)

    local scroll, content = MakeScrollFrame(scrollContainer)

    postDetailFrame = parentFrame
    postDetailFrame.commentBox = commentBox
    postDetailFrame.scroll = scroll
    postDetailFrame.scrollContent = content

    -- Post section (all inside scroll content)
    local postFrame = CreateFrame("Frame", nil, content)
    postFrame:SetHeight(40)
    postFrame:SetPoint("TOPLEFT", 0, 0)
    postFrame:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    local authorFs = postFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    authorFs:SetPoint("TOPLEFT", 4, -3)
    local af = authorFs:GetFont()
    if af then authorFs:SetFont(af, 9, "OUTLINE") end
    postFrame.authorFs = authorFs

    local authorBtn = CreateFrame("Button", nil, postFrame)
    authorBtn:SetPoint("TOPLEFT", authorFs, "TOPLEFT", -2, 2)
    authorBtn:SetPoint("BOTTOMRIGHT", authorFs, "BOTTOMRIGHT", 2, -2)
    authorBtn:SetScript("OnClick", function()
        local db = GetDB()
        local post = db.posts[selectedPostIdx]
        if post then
            viewedUser = post.author
            ShowView("user_profile")
            PhoneSocialApp:RefreshUserProfile()
        end
    end)
    postFrame.authorBtn = authorBtn

    local timeFs = postFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    timeFs:SetPoint("TOPRIGHT", -4, -3)
    local tf = timeFs:GetFont()
    if tf then timeFs:SetFont(tf, 8, "OUTLINE") end
    timeFs:SetTextColor(0.5, 0.5, 0.5, 1)
    postFrame.timeFs = timeFs

    local textFs = postFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    textFs:SetPoint("TOPLEFT", 4, -15)
    textFs:SetPoint("RIGHT", -4, 0)
    textFs:SetJustifyH("LEFT")
    textFs:SetWordWrap(true)
    local txf = textFs:GetFont()
    if txf then textFs:SetFont(txf, 9, "") end
    textFs:SetTextColor(0.9, 0.9, 0.9, 1)
    postFrame.textFs = textFs

    -- Edit/Delete buttons for own post
    local editPBtn = CreateFrame("Button", nil, postFrame)
    editPBtn:SetSize(28, 14)
    editPBtn:SetPoint("BOTTOMRIGHT", -34, 2)
    local epBg = editPBtn:CreateTexture(nil, "BACKGROUND")
    epBg:SetAllPoints()
    epBg:SetColorTexture(0.3, 0.4, 0.55, 0.5)
    local epFs = editPBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    epFs:SetPoint("CENTER")
    local epf = epFs:GetFont()
    if epf then epFs:SetFont(epf, 8, "OUTLINE") end
    epFs:SetText("|cff88aaccEdit|r")
    editPBtn:Hide()
    postFrame.editPostBtn = editPBtn

    local delPBtn = CreateFrame("Button", nil, postFrame)
    delPBtn:SetSize(26, 14)
    delPBtn:SetPoint("BOTTOMRIGHT", -4, 2)
    local dpBg = delPBtn:CreateTexture(nil, "BACKGROUND")
    dpBg:SetAllPoints()
    dpBg:SetColorTexture(0.55, 0.2, 0.2, 0.5)
    local dpFs = delPBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    dpFs:SetPoint("CENTER")
    local dpf = dpFs:GetFont()
    if dpf then dpFs:SetFont(dpf, 8, "OUTLINE") end
    dpFs:SetText("|cffcc4444Del.|r")
    delPBtn:Hide()
    postFrame.delPostBtn = delPBtn

    postDetailFrame.postInfo = postFrame

    -- Separator (positioned dynamically in Refresh)
    local sep = content:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("LEFT", 4, 0)
    sep:SetPoint("RIGHT", -4, 0)
    sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep:SetVertexColor(0.3, 0.3, 0.35, 0.5)
    postDetailFrame.postSep = sep

    -- Comments label (positioned dynamically in Refresh)
    local commLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    local clf = commLabel:GetFont()
    if clf then commLabel:SetFont(clf, 8, "OUTLINE") end
    commLabel:SetTextColor(0.6, 0.6, 0.7, 1)
    postDetailFrame.commLabel = commLabel

    -- Comment rows (inside scroll content, positioned dynamically in Refresh)
    detailRows = {}
    for i = 1, 50 do
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(28)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.14, 0.14, 0.18, (i % 2 == 0) and 0.3 or 0.15)

        local cAuthor = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        cAuthor:SetPoint("TOPLEFT", 6, -2)
        local caf = cAuthor:GetFont()
        if caf then cAuthor:SetFont(caf, 8, "OUTLINE") end
        row.authorFs = cAuthor

        local cTime = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        cTime:SetPoint("TOPRIGHT", -4, -2)
        local ctf = cTime:GetFont()
        if ctf then cTime:SetFont(ctf, 8, "OUTLINE") end
        cTime:SetTextColor(0.5, 0.5, 0.5, 1)
        row.timeFs = cTime

        local cText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        cText:SetPoint("TOPLEFT", 6, -12)
        cText:SetPoint("RIGHT", -4, 0)
        cText:SetJustifyH("LEFT")
        cText:SetWordWrap(true)
        cText:SetMaxLines(2)
        local ctxf = cText:GetFont()
        if ctxf then cText:SetFont(ctxf, 8, "") end
        cText:SetTextColor(0.8, 0.8, 0.8, 1)
        row.textFs = cText

        -- Edit button (only visible on own comments)
        local editCBtn = CreateFrame("Button", nil, row)
        editCBtn:SetSize(28, 14)
        editCBtn:SetPoint("BOTTOMRIGHT", -34, 2)
        local ecBg = editCBtn:CreateTexture(nil, "BACKGROUND")
        ecBg:SetAllPoints()
        ecBg:SetColorTexture(0.3, 0.4, 0.55, 0.5)
        local editCFs = editCBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        editCFs:SetPoint("CENTER")
        local ecf = editCFs:GetFont()
        if ecf then editCFs:SetFont(ecf, 8, "OUTLINE") end
        editCFs:SetText("|cff88aaccEdit|r")
        editCBtn:Hide()
        row.editBtn = editCBtn

        -- Delete button (only visible on own comments)
        local delCBtn = CreateFrame("Button", nil, row)
        delCBtn:SetSize(26, 14)
        delCBtn:SetPoint("BOTTOMRIGHT", -4, 2)
        local dcBg = delCBtn:CreateTexture(nil, "BACKGROUND")
        dcBg:SetAllPoints()
        dcBg:SetColorTexture(0.55, 0.2, 0.2, 0.5)
        local delCFs = delCBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        delCFs:SetPoint("CENTER")
        local dcf = delCFs:GetFont()
        if dcf then delCFs:SetFont(dcf, 8, "OUTLINE") end
        delCFs:SetText("|cffcc4444Del.|r")
        delCBtn:Hide()
        row.delBtn = delCBtn

        -- Inline edit area (hidden by default, shown when editing)
        local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        editBox:SetPoint("TOPLEFT", 24, -11)
        editBox:SetPoint("RIGHT", -4, 0)
        editBox:SetHeight(18)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEditFocusGained", function(self)
            self:SetCursorPosition(#(self:GetText() or ""))
        end)
        local ebf = editBox:GetFont()
        if ebf then editBox:SetFont(ebf, 8, "") end
        editBox:SetMaxLetters(280)
        editBox:Hide()
        row.editBox = editBox

        local editEmojiBtn = CreateEmojiButton(row, editBox, 14)
        editEmojiBtn:SetPoint("TOPLEFT", 6, -12)
        editEmojiBtn:Hide()
        row.editEmojiBtn = editEmojiBtn

        local saveBtn = CreateFrame("Button", nil, row)
        saveBtn:SetSize(28, 14)
        saveBtn:SetPoint("BOTTOMRIGHT", -34, 2)
        local svBg = saveBtn:CreateTexture(nil, "BACKGROUND")
        svBg:SetAllPoints()
        svBg:SetColorTexture(0.2, 0.5, 0.3, 0.6)
        local svFs = saveBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        svFs:SetPoint("CENTER")
        local svf = svFs:GetFont()
        if svf then svFs:SetFont(svf, 8, "OUTLINE") end
        svFs:SetText("|cff88dd88Save|r")
        saveBtn:Hide()
        row.saveBtn = saveBtn

        local cancelBtn = CreateFrame("Button", nil, row)
        cancelBtn:SetSize(26, 14)
        cancelBtn:SetPoint("BOTTOMRIGHT", -4, 2)
        local cnBg = cancelBtn:CreateTexture(nil, "BACKGROUND")
        cnBg:SetAllPoints()
        cnBg:SetColorTexture(0.4, 0.4, 0.4, 0.5)
        local cnFs = cancelBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        cnFs:SetPoint("CENTER")
        local cnf = cnFs:GetFont()
        if cnf then cnFs:SetFont(cnf, 8, "OUTLINE") end
        cnFs:SetText("|cffaaaaaaCncl|r")
        cancelBtn:Hide()
        row.cancelBtn = cancelBtn

        row:Hide()
        detailRows[i] = row
    end
end

function PhoneSocialApp:RefreshPostDetail()
    local db = GetDB()
    local post = db.posts[selectedPostIdx]
    if not post then return end

    local content = postDetailFrame.scrollContent
    local scrollW = postDetailFrame.scroll:GetWidth()
    if scrollW and scrollW > 10 then content:SetWidth(scrollW) end
    local info = postDetailFrame.postInfo
    local cc = GetClassColor(post.authorClass)
    info.authorFs:SetText("|c" .. cc .. post.author .. "|r")
    info.authorBtn:SetSize(info.authorFs:GetStringWidth() + 4, info.authorFs:GetStringHeight() + 4)
    info.timeFs:SetText(FormatTime(post.timestamp))
    info.textFs:SetText(ReplaceEmojis(post.text))

    -- Show edit/delete on own posts
    local showBtns = IsMe(post.author)
    if showBtns then
        info.editPostBtn:Show()
        info.delPostBtn:Show()
        info.editPostBtn:SetScript("OnClick", function() StartEditPost(selectedPostIdx) end)
        info.delPostBtn:SetScript("OnClick", function() StartDeletePost(selectedPostIdx) end)
    else
        info.editPostBtn:Hide()
        info.delPostBtn:Hide()
    end

    -- Dynamically size post frame based on text height
    local textH = info.textFs:GetStringHeight() or 12
    local btnRow = showBtns and 18 or 4
    local postH = 15 + textH + btnRow
    info:SetHeight(postH)

    -- Position separator below post frame
    local curY = postH + 2
    postDetailFrame.postSep:ClearAllPoints()
    postDetailFrame.postSep:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -curY)
    postDetailFrame.postSep:SetPoint("RIGHT", content, "RIGHT", -4, 0)
    curY = curY + 4

    -- Comments label
    local comments = post.comments or {}
    postDetailFrame.commLabel:SetText("Comments (" .. #comments .. ")")
    postDetailFrame.commLabel:ClearAllPoints()
    postDetailFrame.commLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -curY)
    curY = curY + 14

    -- Position comment rows
    local myName = GetMyName()
    for i = 1, 50 do
        local row = detailRows[i]
        local c = comments[i]
        if c then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -curY)
            row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
            local ccc = GetClassColor(c.authorClass)
            row.authorFs:SetText("|c" .. ccc .. c.author .. "|r")
            row.timeFs:SetText(FormatTime(c.timestamp))
            row.textFs:SetText(ReplaceEmojis(c.text))
            row:Show()
            curY = curY + 28

            -- Always hide inline edit state on refresh
            row.editBox:Hide()
            row.editEmojiBtn:Hide()
            row.saveBtn:Hide()
            row.cancelBtn:Hide()
            row.textFs:Show()
            row:SetHeight(28)

            -- Show edit/delete only on own comments
            if IsMe(c.author) then
                row.editBtn:Show()
                row.delBtn:Show()
                local commentIdx = i
                row.editBtn:SetScript("OnClick", function()
                    -- Enter inline edit mode — expand row
                    row.textFs:Hide()
                    row.editBtn:Hide()
                    row.delBtn:Hide()
                    row:SetHeight(42)
                    row.editBox:SetText(c.text)
                    row.editBox:Show()
                    row.editBox:SetFocus()
                    row.editEmojiBtn:Show()
                    row.saveBtn:Show()
                    row.cancelBtn:Show()
                end)
                row.delBtn:SetScript("OnClick", function()
                    DeleteComment(selectedPostIdx, commentIdx)
                    PhoneSocialApp:RefreshPostDetail()
                end)
                row.saveBtn:SetScript("OnClick", function()
                    local newText = row.editBox:GetText()
                    if newText and newText:trim() ~= "" then
                        EditComment(selectedPostIdx, commentIdx, newText:trim())
                    end
                    PhoneSocialApp:RefreshPostDetail()
                end)
                row.editBox:SetScript("OnEnterPressed", function()
                    local newText = row.editBox:GetText()
                    if newText and newText:trim() ~= "" then
                        EditComment(selectedPostIdx, commentIdx, newText:trim())
                    end
                    PhoneSocialApp:RefreshPostDetail()
                end)
                row.editBox:SetScript("OnEscapePressed", function()
                    PhoneSocialApp:RefreshPostDetail()
                end)
                row.cancelBtn:SetScript("OnClick", function()
                    PhoneSocialApp:RefreshPostDetail()
                end)
            else
                row.editBtn:Hide()
                row.delBtn:Hide()
            end
        else
            row:Hide()
        end
    end

    -- Set total scroll content height
    content:SetHeight(math.max(1, curY))
    postDetailFrame.scroll:SetVerticalScroll(0)
end

---------------------------------------------------------------------------
-- New Post View
---------------------------------------------------------------------------
local function BuildNewPost(parentFrame)
    -- Scroll container for the whole new post view
    local scrollContainer = CreateFrame("Frame", nil, parentFrame)
    scrollContainer:SetPoint("TOPLEFT", 0, 0)
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 0)
    local scroll, content = MakeScrollFrame(scrollContainer)

    local label = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 4, -6)
    local lf = label:GetFont()
    if lf then label:SetFont(lf, 9, "OUTLINE") end
    label:SetText("|cffccccccWhat's on your mind?|r")

    local editBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    editBg:SetPoint("TOPLEFT", 4, -18)
    editBg:SetPoint("RIGHT", content, "RIGHT", -4, 0)
    editBg:SetHeight(60)
    editBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    editBg:SetBackdropColor(0.08, 0.08, 0.12, 0.9)
    editBg:SetBackdropBorderColor(0.25, 0.25, 0.30, 0.5)

    local editBox = CreateFrame("EditBox", nil, editBg)
    editBox:SetPoint("TOPLEFT", 4, -4)
    editBox:SetPoint("BOTTOMRIGHT", -4, 4)
    editBox:SetAutoFocus(false)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(280)
    local ef = editBox:GetFont() or "Fonts\\FRIZQT__.TTF"
    editBox:SetFont(ef, 9, "")
    editBox:SetTextColor(0.9, 0.9, 0.9, 1)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:SetCursorPosition(#(self:GetText() or ""))
    end)
    -- Make background click focus the edit box
    editBg:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)
    newPostInput = editBox

    -- Emoji + Post buttons on same row below text box
    local emojiBtn = CreateEmojiButton(content, editBox, 18)
    emojiBtn:SetPoint("TOPLEFT", editBg, "BOTTOMLEFT", 0, -4)

    local postBtn = CreateFrame("Button", nil, content)
    postBtn:SetSize(60, 18)
    postBtn:SetPoint("TOPRIGHT", editBg, "BOTTOMRIGHT", 0, -4)
    local postBg = postBtn:CreateTexture(nil, "BACKGROUND")
    postBg:SetAllPoints()
    postBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    postBg:SetVertexColor(0.2, 0.5, 0.3, 0.9)
    local postTxt = postBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    postTxt:SetPoint("CENTER")
    local pf = postTxt:GetFont()
    if pf then postTxt:SetFont(pf, 9, "OUTLINE") end
    postTxt:SetText("|cffffffffPost|r")

    local statusFs = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusFs:SetPoint("TOP", postBtn, "BOTTOM", 0, -4)
    local sf = statusFs:GetFont()
    if sf then statusFs:SetFont(sf, 8, "OUTLINE") end

    newPostFrame = parentFrame
    newPostFrame.statusFs = statusFs
    newPostFrame.label = label
    newPostFrame.postTxt = postTxt
    newPostFrame.editBg = editBg
    newPostFrame.scrollContent = content
    newPostFrame.scroll = scroll

    -- Grow text box and scroll content as user types
    local function UpdateLayout()
        local numLines = editBox:GetNumLetters() > 0 and editBox:GetHeight() or 0
        -- Measure actual text height
        local textH = editBox:GetHeight()
        if textH < 52 then textH = 52 end
        local boxH = textH + 8
        if boxH < 60 then boxH = 60 end
        editBg:SetHeight(boxH)
        -- Total content: 18(label) + boxH + 4(gap) + 18(buttons) + 4(gap) + 14(status) + 10(pad)
        content:SetHeight(18 + boxH + 4 + 18 + 4 + 14 + 10)
    end

    editBox:SetScript("OnTextChanged", function(self, userInput)
        -- Recalculate height based on text content
        local text = self:GetText() or ""
        local lines = 1
        for _ in text:gmatch("\n") do lines = lines + 1 end
        local lineH = 12  -- approximate line height at font size 9
        local textH = math.max(52, lines * lineH)
        editBg:SetHeight(textH + 8)
        content:SetHeight(18 + textH + 8 + 4 + 18 + 4 + 14 + 10)
    end)

    postBtn:SetScript("OnClick", function()
        local txt = newPostInput:GetText()
        if txt and txt:trim() ~= "" then
            if editingPostIdx then
                EditPost(editingPostIdx, txt:trim())
                editingPostIdx = nil
                newPostInput:SetText("")
                newPostInput:ClearFocus()
                GoBack()
            else
                CreatePost(txt:trim())
                newPostInput:SetText("")
                newPostInput:ClearFocus()
                GoBack()
            end
        else
            statusFs:SetText("|cffff4444Write something first.|r")
        end
    end)
end

function PhoneSocialApp:RefreshNewPost()
    -- Set scroll content width
    if newPostFrame and newPostFrame.scroll and newPostFrame.scrollContent then
        local scrollW = newPostFrame.scroll:GetWidth()
        if scrollW and scrollW > 10 then newPostFrame.scrollContent:SetWidth(scrollW) end
        newPostFrame.scrollContent:SetHeight(18 + 60 + 4 + 18 + 4 + 14 + 10)
    end
    if newPostInput then
        if editingPostIdx then
            -- Edit mode: pre-fill with existing post text
            local db = GetDB()
            local post = db.posts[editingPostIdx]
            if post then
                newPostInput:SetText(post.text)
            end
            if newPostFrame.label then
                newPostFrame.label:SetText("|cffccccccEditing post:|r")
            end
            if newPostFrame.postTxt then
                newPostFrame.postTxt:SetText("|cffffffffSave|r")
            end
        else
            newPostInput:SetText("")
            if newPostFrame.label then
                newPostFrame.label:SetText("|cffccccccWhat's on your mind?|r")
            end
            if newPostFrame.postTxt then
                newPostFrame.postTxt:SetText("|cffffffffPost|r")
            end
        end
    end
    if newPostFrame and newPostFrame.statusFs then
        newPostFrame.statusFs:SetText("")
    end
end

---------------------------------------------------------------------------
-- User Profile View (view another user's posts)
---------------------------------------------------------------------------
local userProfilePostRows = {}

local function BuildUserProfile(parentFrame)
    -- Profile header
    local nameFs = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameFs:SetPoint("TOPLEFT", 6, -6)
    local nf = nameFs:GetFont()
    if nf then nameFs:SetFont(nf, 12, "OUTLINE") end
    parentFrame.nameFs = nameFs

    local infoFs = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    infoFs:SetPoint("TOPLEFT", 6, -24)
    local inf = infoFs:GetFont()
    if inf then infoFs:SetFont(inf, 10, "OUTLINE") end
    infoFs:SetTextColor(0.7, 0.7, 0.7, 1)
    parentFrame.infoFs = infoFs

    local guildFs = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    guildFs:SetPoint("TOPLEFT", 6, -38)
    local gf = guildFs:GetFont()
    if gf then guildFs:SetFont(gf, 9, "OUTLINE") end
    guildFs:SetTextColor(0.5, 0.8, 0.5, 1)
    parentFrame.guildFs = guildFs

    -- Bio display (read-only)
    local bioLabel = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bioLabel:SetPoint("TOPLEFT", 6, -56)
    local bf = bioLabel:GetFont()
    if bf then bioLabel:SetFont(bf, 9, "OUTLINE") end
    bioLabel:SetText("|cff888888Bio:|r")

    local bioFs = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bioFs:SetPoint("TOPLEFT", 6, -70)
    bioFs:SetPoint("RIGHT", -6, 0)
    bioFs:SetJustifyH("LEFT")
    bioFs:SetWordWrap(true)
    local bof = bioFs:GetFont()
    if bof then bioFs:SetFont(bof, 9, "") end
    bioFs:SetTextColor(0.85, 0.85, 0.85, 1)
    parentFrame.bioFs = bioFs

    -- Posts count
    local countFs = parentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    countFs:SetPoint("TOPLEFT", 6, -96)
    local cf = countFs:GetFont()
    if cf then countFs:SetFont(cf, 8, "OUTLINE") end
    countFs:SetTextColor(0.6, 0.6, 0.7, 1)
    parentFrame.countFs = countFs

    CreateSeparator(parentFrame, -108)

    local scrollContainer = CreateFrame("Frame", nil, parentFrame)
    scrollContainer:SetPoint("TOPLEFT", 0, -112)
    scrollContainer:SetPoint("BOTTOMRIGHT", 0, 0)

    local scroll, content = MakeScrollFrame(scrollContainer)
    parentFrame.scrollContent = content

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, content)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.12, 0.12, 0.16, (i % 2 == 0) and 0.4 or 0.2)

        local timeFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        timeFs:SetPoint("TOPRIGHT", -4, -3)
        local tf = timeFs:GetFont()
        if tf then timeFs:SetFont(tf, 8, "OUTLINE") end
        timeFs:SetTextColor(0.5, 0.5, 0.5, 1)
        row.timeFs = timeFs

        local textFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        textFs:SetPoint("TOPLEFT", 4, -3)
        textFs:SetPoint("RIGHT", -30, 0)
        textFs:SetJustifyH("LEFT")
        textFs:SetWordWrap(true)
        textFs:SetMaxLines(2)
        local txf = textFs:GetFont()
        if txf then textFs:SetFont(txf, 9, "") end
        textFs:SetTextColor(0.85, 0.85, 0.85, 1)
        row.textFs = textFs

        local commentFs = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        commentFs:SetPoint("BOTTOMLEFT", 4, 3)
        local ccf = commentFs:GetFont()
        if ccf then commentFs:SetFont(ccf, 8, "OUTLINE") end
        commentFs:SetTextColor(0.5, 0.6, 0.8, 1)
        row.commentFs = commentFs

        -- Edit/Delete buttons (shown only on own posts, wired in RefreshUserProfile)
        local editPBtn = CreateFrame("Button", nil, row)
        editPBtn:SetSize(28, 14)
        editPBtn:SetPoint("BOTTOMRIGHT", -34, 3)
        local epBg = editPBtn:CreateTexture(nil, "BACKGROUND")
        epBg:SetAllPoints()
        epBg:SetColorTexture(0.3, 0.4, 0.55, 0.5)
        local epFs = editPBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        epFs:SetPoint("CENTER")
        local epf = epFs:GetFont()
        if epf then epFs:SetFont(epf, 8, "OUTLINE") end
        epFs:SetText("|cff88aaccEdit|r")
        editPBtn:Hide()
        row.editPostBtn = editPBtn

        local delPBtn = CreateFrame("Button", nil, row)
        delPBtn:SetSize(26, 14)
        delPBtn:SetPoint("BOTTOMRIGHT", -4, 3)
        local dpBg = delPBtn:CreateTexture(nil, "BACKGROUND")
        dpBg:SetAllPoints()
        dpBg:SetColorTexture(0.55, 0.2, 0.2, 0.5)
        local dpFs = delPBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        dpFs:SetPoint("CENTER")
        local dpf = dpFs:GetFont()
        if dpf then dpFs:SetFont(dpf, 8, "OUTLINE") end
        dpFs:SetText("|cffcc4444Del.|r")
        delPBtn:Hide()
        row.delPostBtn = delPBtn

        row:SetScript("OnClick", function()
            if row.postIdx then
                selectedPostIdx = row.postIdx
                ShowView("post_detail")
                PhoneSocialApp:RefreshPostDetail()
            end
        end)

        row:Hide()
        userProfilePostRows[i] = row
    end

    userProfileFrame = parentFrame
end

function PhoneSocialApp:RefreshUserProfile()
    if not viewedUser then return end
    local myName = GetMyName()

    -- Try to get profile data and class color
    local prof = GetDB().profiles[viewedUser]
    local cc = "ff4488ff"  -- default blue if no class known

    -- Also check posts for class info
    if not prof then
        local db = GetDB()
        for _, post in ipairs(db.posts) do
            if post.author == viewedUser and post.authorClass then
                cc = GetClassColor(post.authorClass)
                break
            end
        end
    else
        if prof.class and prof.class ~= "" then
            cc = GetClassColor(prof.class)
        end
    end

    userProfileFrame.nameFs:SetText("|c" .. cc .. viewedUser .. "|r")

    if prof then
        local infoLine = ""
        if prof.level and prof.level > 0 then
            infoLine = "Lvl " .. prof.level
        end
        if prof.race and prof.race ~= "" then
            infoLine = infoLine .. " " .. prof.race
        end
        if prof.class and prof.class ~= "" then
            infoLine = infoLine .. " " .. prof.class
        end
        userProfileFrame.infoFs:SetText(infoLine)
        userProfileFrame.guildFs:SetText(prof.guild and prof.guild ~= "" and ("<" .. prof.guild .. ">") or "")
        userProfileFrame.bioFs:SetText(prof.bio and prof.bio ~= "" and ReplaceEmojis(prof.bio) or "|cff555555No bio set.|r")
    else
        userProfileFrame.infoFs:SetText("")
        userProfileFrame.guildFs:SetText("")
        userProfileFrame.bioFs:SetText("|cff555555Profile not yet received.|r")
    end

    local posts = GetPostsByAuthor(viewedUser)
    userProfileFrame.countFs:SetText(#posts .. " post" .. (#posts ~= 1 and "s" or ""))

    local contentWidth = userProfileFrame.scrollContent:GetParent():GetWidth() - 12
    if contentWidth < 20 then contentWidth = 120 end
    userProfileFrame.scrollContent:SetWidth(contentWidth)

    for i = 1, MAX_ROWS do
        local row = userProfilePostRows[i]
        local entry = posts[i]
        if entry then
            row:SetWidth(contentWidth)
            row.timeFs:SetText(FormatTime(entry.post.timestamp))
            row.textFs:SetText(ReplaceEmojis(entry.post.text))
            local numC = entry.post.comments and #entry.post.comments or 0
            row.commentFs:SetText(numC > 0 and (numC .. " comment" .. (numC > 1 and "s" or "")) or "")
            row.postIdx = entry.idx

            if viewedUser == myName then
                row.editPostBtn:Show()
                row.delPostBtn:Show()
                local idx = entry.idx
                row.editPostBtn:SetScript("OnClick", function() StartEditPost(idx) end)
                row.delPostBtn:SetScript("OnClick", function() StartDeletePost(idx) end)
            else
                row.editPostBtn:Hide()
                row.delPostBtn:Hide()
            end

            row:Show()
        else
            row:Hide()
        end
    end

    userProfileFrame.scrollContent:SetHeight(math.max(1, #posts * ROW_HEIGHT))
end

---------------------------------------------------------------------------
-- Init / OnShow / OnHide
---------------------------------------------------------------------------
function PhoneSocialApp:Init(parentFrame)
    parent = parentFrame
    RegisterMyCharacter()

    -- Title bar with back button
    titleBar = CreateFrame("Frame", nil, parent)
    titleBar:SetHeight(16)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)

    backBtn = CreateFrame("Button", nil, titleBar)
    backBtn:SetSize(20, 14)
    backBtn:SetPoint("LEFT", 2, 0)
    local backBg = backBtn:CreateTexture(nil, "BACKGROUND")
    backBg:SetAllPoints()
    backBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    backBg:SetVertexColor(0.25, 0.25, 0.30, 0.7)
    local backTxt = backBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    backTxt:SetPoint("CENTER")
    local btf = backTxt:GetFont()
    if btf then backTxt:SetFont(btf, 9, "OUTLINE") end
    backTxt:SetText("<")
    backBtn:SetScript("OnClick", GoBack)
    backBtn:Hide()

    titleText = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("CENTER")
    local tf = titleText:GetFont()
    if tf then titleText:SetFont(tf, 10, "OUTLINE") end
    titleText:SetText("|cff4488ffFeed|r")

    -- Create sub-view frames
    local function MakeSubFrame()
        local f = CreateFrame("Frame", nil, parent)
        f:SetPoint("TOPLEFT", 0, -16)
        f:SetPoint("BOTTOMRIGHT", 0, 0)
        f:Hide()
        return f
    end

    feedFrame = MakeSubFrame()
    profileFrame = MakeSubFrame()
    postDetailFrame = MakeSubFrame()
    newPostFrame = MakeSubFrame()
    userProfileFrame = MakeSubFrame()

    BuildFeed(feedFrame)
    BuildProfile(profileFrame)
    BuildPostDetail(postDetailFrame)
    BuildNewPost(newPostFrame)
    BuildUserProfile(userProfileFrame)

    -- Register addon message prefix and listen for incoming social messages
    C_ChatInfo.RegisterAddonMessagePrefix(SOCIAL_PREFIX)
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            OnSocialMessage(...)
        elseif event == "PLAYER_ENTERING_WORLD" then
            UpdateOwnProfile()
            -- Join the hidden channel once the player is in the world
            C_Timer.After(5, function()
                JoinSocialChannel()
                -- Say hello so existing users know we're here
                C_Timer.After(2, BroadcastHello)
            end)
        end
    end)
end

function PhoneSocialApp:OnShow()
    visible = true
    viewStack = {}
    ShowView("feed", true)
    self:RefreshFeed()
    -- Make sure we're in the channel and say hello
    JoinSocialChannel()
    C_Timer.After(1, BroadcastHello)
end

function PhoneSocialApp:OnHide()
    visible = false
end

-- Navigate directly to a post by its ID (used by notification click)
function PhoneSocialApp:OpenPostById(postId)
    local idx, post = FindPostById(postId)
    if idx and post then
        selectedPostIdx = idx
        viewStack = {}  -- clear nav stack, we're coming from outside
        ShowView("post_detail")
        self:RefreshPostDetail()
    else
        -- Post not found, just show feed
        viewStack = {}
        ShowView("feed", true)
        self:RefreshFeed()
    end
end
