-- PhoneWeather - Weather display app for HearthPhone
-- Uses WEATHER_UPDATE event for real weather data

PhoneWeatherApp = {}

local parent
local weatherType = 0    -- 0=none, 1=rain, 2=snow, 3=sandstorm
local weatherIntensity = 0
local zoneText, tempFs, conditionFs, intensityBar, intensityFill
local iconTex, detailFs, feelsLikeFs
local forecastFrames = {}

local WEATHER_INFO = {
    [0] = { name = "Clear",      icon = "Interface\\Icons\\Spell_Nature_StarFall",        color = {0.95, 0.85, 0.30} },
    [1] = { name = "Rain",       icon = "Interface\\Icons\\Spell_Nature_RainNormal",      color = {0.40, 0.60, 0.90} },
    [2] = { name = "Snow",       icon = "Interface\\Icons\\Spell_Frost_ArcticWinds",      color = {0.80, 0.90, 1.00} },
    [3] = { name = "Sandstorm",  icon = "Interface\\Icons\\Spell_Nature_Cyclone",         color = {0.85, 0.70, 0.40} },
}

-- Fake forecast based on zone biome
local function GetZoneBiome()
    local zone = GetRealZoneText() or ""
    local sub = GetSubZoneText() or ""
    local z = (zone .. " " .. sub):lower()

    if z:find("ice") or z:find("snow") or z:find("frost") or z:find("winter") or z:find("storm peaks")
       or z:find("dun morogh") or z:find("northrend") or z:find("dragonblight") then
        return "cold"
    elseif z:find("desert") or z:find("sand") or z:find("tanaris") or z:find("uldum") or z:find("silithus")
       or z:find("badlands") or z:find("durotar") or z:find("barrens") then
        return "hot"
    elseif z:find("swamp") or z:find("marsh") or z:find("wetland") or z:find("zangar") then
        return "humid"
    elseif z:find("forest") or z:find("grove") or z:find("ashenvale") or z:find("feralas")
       or z:find("elwynn") or z:find("teldrassil") then
        return "temperate"
    end
    return "temperate"
end

local function GetFakeTemp()
    local biome = GetZoneBiome()
    local base
    if biome == "cold" then base = math.random(-15, 5)
    elseif biome == "hot" then base = math.random(28, 42)
    elseif biome == "humid" then base = math.random(18, 30)
    else base = math.random(10, 25) end

    -- Adjust by weather
    if weatherType == 1 then base = base - math.random(2, 5)
    elseif weatherType == 2 then base = base - math.random(5, 12)
    elseif weatherType == 3 then base = base + math.random(2, 8) end

    return base
end

local function GetIntensityLabel(intensity)
    if intensity < 0.2 then return "Light"
    elseif intensity < 0.5 then return "Moderate"
    elseif intensity < 0.8 then return "Heavy"
    else return "Severe" end
end

local function GetFakeForecast()
    local forecast = {}
    local biome = GetZoneBiome()
    local hours = { "Now", "+3h", "+6h", "+9h", "+12h" }
    for i = 1, 5 do
        local wt = 0
        local roll = math.random(100)
        if biome == "cold" then
            if roll < 40 then wt = 2
            elseif roll < 55 then wt = 1 end
        elseif biome == "hot" then
            if roll < 20 then wt = 3
            elseif roll < 25 then wt = 1 end
        elseif biome == "humid" then
            if roll < 50 then wt = 1 end
        else
            if roll < 25 then wt = 1
            elseif roll < 30 then wt = 2 end
        end
        local temp
        if biome == "cold" then temp = math.random(-15, 5)
        elseif biome == "hot" then temp = math.random(28, 42)
        elseif biome == "humid" then temp = math.random(18, 30)
        else temp = math.random(10, 25) end

        table.insert(forecast, {
            time = hours[i],
            weatherType = wt,
            temp = temp,
        })
    end
    return forecast
end

local function UpdateWeatherDisplay()
    local info = WEATHER_INFO[weatherType] or WEATHER_INFO[0]
    local zone = GetRealZoneText() or "Unknown"

    zoneText:SetText("|cffffffff" .. zone .. "|r")
    iconTex:SetTexture(info.icon)

    local temp = GetFakeTemp()
    tempFs:SetText("|cffffffff" .. temp .. "°C|r")

    local condition = info.name
    if weatherType > 0 then
        condition = GetIntensityLabel(weatherIntensity) .. " " .. condition
    end
    conditionFs:SetText("|cff" .. format("%02x%02x%02x", info.color[1] * 255, info.color[2] * 255, info.color[3] * 255) .. condition .. "|r")

    -- Feels like
    local feelsTemp = temp
    if weatherType == 2 then feelsTemp = temp - math.random(3, 8)
    elseif weatherType == 3 then feelsTemp = temp + math.random(3, 6)
    elseif weatherType == 1 then feelsTemp = temp - math.random(1, 4) end
    feelsLikeFs:SetText("|cff888888Feels like " .. feelsTemp .. "°C|r")

    -- Intensity bar
    if weatherType > 0 then
        intensityBar:Show()
        intensityFill:SetWidth(math.max(1, weatherIntensity * (intensityBar:GetWidth() - 2)))
        local c = info.color
        intensityFill:SetVertexColor(c[1], c[2], c[3], 0.8)
    else
        intensityBar:Hide()
    end

    -- Detail
    local details = {
        [0] = "Clear skies across the zone.",
        [1] = "Rainfall detected. Pack your umbrella!",
        [2] = "Snowfall in progress. Watch for ice.",
        [3] = "Sand particles reducing visibility.",
    }
    detailFs:SetText("|cff888888" .. (details[weatherType] or "") .. "|r")

    -- Forecast
    local forecast = GetFakeForecast()
    for i, fc in ipairs(forecastFrames) do
        local fdata = forecast[i]
        if fdata then
            local finfo = WEATHER_INFO[fdata.weatherType] or WEATHER_INFO[0]
            fc.timeFs:SetText("|cff888888" .. fdata.time .. "|r")
            fc.iconTex:SetTexture(finfo.icon)
            fc.tempFs:SetText("|cffcccccc" .. fdata.temp .. "°|r")
            fc.frame:Show()
        else
            fc.frame:Hide()
        end
    end
end

function PhoneWeatherApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local W = parent:GetWidth() or 170

    -- Title
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffffffffWeather|r")
    local tf = title:GetFont()
    if tf then title:SetFont(tf, 11, "OUTLINE") end

    -- Zone name
    zoneText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    zoneText:SetPoint("TOP", 0, -16)
    local ztf = zoneText:GetFont()
    if ztf then zoneText:SetFont(ztf, 8, "") end

    -- Weather icon
    iconTex = parent:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(36, 36)
    iconTex:SetPoint("TOP", 0, -28)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Temperature
    tempFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tempFs:SetPoint("TOP", iconTex, "BOTTOM", 0, -4)
    local tpf = tempFs:GetFont()
    if tpf then tempFs:SetFont(tpf, 14, "OUTLINE") end

    -- Condition text
    conditionFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    conditionFs:SetPoint("TOP", tempFs, "BOTTOM", 0, -2)
    local ccf = conditionFs:GetFont()
    if ccf then conditionFs:SetFont(ccf, 9, "") end

    -- Feels like
    feelsLikeFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    feelsLikeFs:SetPoint("TOP", conditionFs, "BOTTOM", 0, -2)
    local flf = feelsLikeFs:GetFont()
    if flf then feelsLikeFs:SetFont(flf, 7, "") end

    -- Intensity bar
    intensityBar = CreateFrame("Frame", nil, parent)
    intensityBar:SetSize(W - 40, 6)
    intensityBar:SetPoint("TOP", feelsLikeFs, "BOTTOM", 0, -6)

    local barBg = intensityBar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    barBg:SetVertexColor(0.08, 0.08, 0.1, 1)

    intensityFill = intensityBar:CreateTexture(nil, "ARTWORK")
    intensityFill:SetHeight(4)
    intensityFill:SetPoint("LEFT", 1, 0)
    intensityFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    intensityFill:SetWidth(1)
    intensityBar:Hide()

    -- Detail text
    detailFs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detailFs:SetPoint("TOP", intensityBar, "BOTTOM", 0, -8)
    detailFs:SetPoint("LEFT", 10, 0)
    detailFs:SetPoint("RIGHT", -10, 0)
    detailFs:SetJustifyH("CENTER")
    detailFs:SetWordWrap(true)
    local df = detailFs:GetFont()
    if df then detailFs:SetFont(df, 7, "") end

    -- Separator
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("LEFT", 10, 0)
    sep:SetPoint("RIGHT", -10, 0)
    sep:SetPoint("TOP", detailFs, "BOTTOM", 0, -8)
    sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep:SetVertexColor(0.2, 0.2, 0.25, 0.5)

    -- Forecast label
    local fcLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    fcLabel:SetPoint("TOP", sep, "BOTTOM", 0, -4)
    fcLabel:SetText("|cff888888Forecast|r")
    local fcf = fcLabel:GetFont()
    if fcf then fcLabel:SetFont(fcf, 8, "") end

    -- Forecast items
    local fcW = math.floor((W - 12) / 5)
    for i = 1, 5 do
        local f = CreateFrame("Frame", nil, parent)
        f:SetSize(fcW, 46)
        f:SetPoint("TOPLEFT", fcLabel, "BOTTOMLEFT", (i - 1) * fcW - fcW * 2 + 2, -4)

        local timeFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        timeFs:SetPoint("TOP", 0, 0)
        local tmf = timeFs:GetFont()
        if tmf then timeFs:SetFont(tmf, 7, "") end

        local ico = f:CreateTexture(nil, "ARTWORK")
        ico:SetSize(18, 18)
        ico:SetPoint("TOP", 0, -10)
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local tpFs = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        tpFs:SetPoint("TOP", ico, "BOTTOM", 0, -2)
        local tpff = tpFs:GetFont()
        if tpff then tpFs:SetFont(tpff, 8, "") end

        forecastFrames[i] = {
            frame = f,
            timeFs = timeFs,
            iconTex = ico,
            tempFs = tpFs,
        }
    end

    -- Register for weather/zone events
    local eventFrame = CreateFrame("Frame")
    -- WEATHER_UPDATE doesn't exist in retail; skip it
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "WEATHER_UPDATE" then
            local wType, intensity = ...
            weatherType = wType or 0
            weatherIntensity = intensity or 0
        end
        if parent:IsShown() then
            UpdateWeatherDisplay()
        end
    end)
end

function PhoneWeatherApp:OnShow()
    UpdateWeatherDisplay()
end

function PhoneWeatherApp:OnHide()
end
