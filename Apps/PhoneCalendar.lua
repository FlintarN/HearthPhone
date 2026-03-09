-- PhoneCalendar - WoW Calendar viewer for HearthPhone
-- Shows current month, upcoming events, and raid lockouts

PhoneCalendarApp = {}

local parent
local WHITE = "Interface\\Buttons\\WHITE8x8"

local monthLabel, yearLabel
local dayCells = {}
local dayHeaders = {}
local eventRows = {}
local eventScroll, eventContent
local gridFrame

local viewMonth, viewYear
local todayDay, todayMonth, todayYear
local selectedDay
local eventsHeaderFs

-- ============================================================
-- Helpers
-- ============================================================
local MONTH_NAMES = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
}

local DAY_NAMES = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }

local function DaysInMonth(month, year)
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 then
        if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then
            return 29
        end
    end
    return days[month]
end

local function FirstWeekday(month, year)
    local t = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
    if month < 3 then year = year - 1 end
    local day = (year + math.floor(year / 4) - math.floor(year / 100) + math.floor(year / 400) + t[month] + 1) % 7
    return day + 1
end

-- ============================================================
-- Layout: dynamically size cells to fill the grid
-- ============================================================
local function LayoutGrid()
    if not gridFrame then return end
    local gw = gridFrame:GetWidth()
    local gh = gridFrame:GetHeight()
    if not gw or gw < 10 then return end

    local cellW = math.floor(gw / 7)
    local headerH = 12
    local cellH = math.floor((gh - headerH) / 6)

    for i = 1, 7 do
        local fs = dayHeaders[i]
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", (i - 1) * cellW, 0)
            fs:SetWidth(cellW)
        end
    end

    for row = 0, 5 do
        for col = 0, 6 do
            local idx = row * 7 + col + 1
            local cell = dayCells[idx]
            if cell then
                cell:ClearAllPoints()
                cell:SetSize(cellW, cellH)
                cell:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", col * cellW, -(row * cellH + headerH))
                cell.bg:SetAllPoints(cell)
            end
        end
    end
end

-- ============================================================
-- Calendar grid update
-- ============================================================
local function UpdateCalendar()
    if not monthLabel then return end

    monthLabel:SetText("|cffffffff" .. MONTH_NAMES[viewMonth] .. "|r")
    yearLabel:SetText("|cff888888" .. viewYear .. "|r")

    local numDays = DaysInMonth(viewMonth, viewYear)
    local startDay = FirstWeekday(viewMonth, viewYear)

    local isCurrentMonth = (viewMonth == todayMonth and viewYear == todayYear)

    -- Query event counts per day
    pcall(function() C_Calendar.SetAbsMonth(viewMonth, viewYear) end)

    for i = 1, 42 do
        local cell = dayCells[i]
        if not cell then break end
        local dayNum = i - startDay + 1
        if dayNum >= 1 and dayNum <= numDays then
            local isToday = isCurrentMonth and dayNum == todayDay
            local isSelected = (dayNum == selectedDay)
            if isSelected then
                cell.fs:SetText("|cffffffff" .. dayNum .. "|r")
                cell.bg:SetVertexColor(0.25, 0.4, 0.55, 1)
                cell.bg:Show()
            elseif isToday then
                cell.fs:SetText("|cff44ccff" .. dayNum .. "|r")
                cell.bg:SetVertexColor(0.15, 0.25, 0.35, 1)
                cell.bg:Show()
            else
                cell.fs:SetText("|cffcccccc" .. dayNum .. "|r")
                cell.bg:Hide()
            end
            cell.dayNum = dayNum
            cell:EnableMouse(true)

            -- Show dot if day has events
            local hasEvents = false
            pcall(function()
                local n = C_Calendar.GetNumDayEvents(0, dayNum)
                if n and n > 0 then hasEvents = true end
            end)
            cell.dot:SetShown(hasEvents)
        else
            cell.fs:SetText("")
            cell.bg:Hide()
            cell.dot:Hide()
            cell.dayNum = nil
            cell:EnableMouse(false)
        end
    end

    LayoutGrid()
    UpdateEventList()
end

local function ChangeMonth(delta)
    viewMonth = viewMonth + delta
    if viewMonth > 12 then
        viewMonth = 1
        viewYear = viewYear + 1
    elseif viewMonth < 1 then
        viewMonth = 12
        viewYear = viewYear - 1
    end
    UpdateCalendar()
end

-- ============================================================
-- Events list
-- ============================================================
local ROW_H = 20
local ICON_SIZE = 18

local function GetOrCreateEventRow(index)
    if eventRows[index] then return eventRows[index] end

    local row = CreateFrame("Frame", nil, eventContent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT", eventContent, "RIGHT", 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", 1, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    local f = row.label:GetFont()
    if f then row.label:SetFont(f, 9, "") end

    eventRows[index] = row
    return row
end

function UpdateEventList()
    if not eventContent then return end

    -- Hide all existing rows
    for _, row in ipairs(eventRows) do row:Hide() end

    -- Update header to show selected day
    if eventsHeaderFs then
        if selectedDay then
            eventsHeaderFs:SetText("|cff888888" .. MONTH_NAMES[viewMonth] .. " " .. selectedDay .. "|r")
        else
            eventsHeaderFs:SetText("|cff888888Select a day|r")
        end
    end

    if not selectedDay then
        local row = GetOrCreateEventRow(1)
        row.icon:Hide()
        row.label:SetText("|cff666666Tap a day to see events|r")
        row:Show()
        eventContent:SetHeight(20)
        return
    end

    local events = {}

    pcall(function()
        C_Calendar.SetAbsMonth(viewMonth, viewYear)
        local numEvents = C_Calendar.GetNumDayEvents(0, selectedDay)
        for i = 1, numEvents do
            local event = C_Calendar.GetDayEvent(0, selectedDay, i)
            if event and event.title then
                table.insert(events, {
                    title = event.title,
                    calType = event.calendarType or "",
                    icon = event.iconTexture,
                })
            end
        end
    end)

    -- Show lockouts only when viewing today
    local isCurrentMonth = (viewMonth == todayMonth and viewYear == todayYear)
    if isCurrentMonth and selectedDay == todayDay then
        pcall(function()
            local numSaved = GetNumSavedInstances()
            if numSaved and numSaved > 0 then
                for i = 1, numSaved do
                    local name, _, reset, _, _, _, _, _, _, diffName = GetSavedInstanceInfo(i)
                    if name and reset and reset > 0 then
                        local hours = math.floor(reset / 3600)
                        table.insert(events, {
                            title = name .. (diffName and (" (" .. diffName .. ")") or ""),
                            calType = "LOCKOUT",
                            resetHours = hours,
                            icon = 136025, -- Interface\\Icons\\INV_Misc_Key_04 (lock icon)
                        })
                    end
                end
            end
        end)
    end

    if #events == 0 then
        local row = GetOrCreateEventRow(1)
        row.icon:Hide()
        row.label:SetText("|cff666666No events|r")
        row:Show()
        eventContent:SetHeight(20)
        return
    end

    table.sort(events, function(a, b) return a.title < b.title end)

    for idx, ev in ipairs(events) do
        local row = GetOrCreateEventRow(idx)

        -- Icon
        if ev.icon then
            row.icon:SetTexture(ev.icon)
            row.icon:Show()
            row.label:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
        else
            row.icon:Hide()
            row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        end

        -- Color + text
        local color = "cccccc"
        if ev.calType == "HOLIDAY" then
            color = "44cc44"
        elseif ev.calType == "RAID_LOCKOUT" or ev.calType == "LOCKOUT" then
            color = "ff8844"
        elseif ev.calType == "PLAYER" then
            color = "44aaff"
        end

        if ev.resetHours then
            row.label:SetText("|cffff8844" .. ev.title .. " - " .. ev.resetHours .. "h|r")
        else
            row.label:SetText("|cff" .. color .. ev.title .. "|r")
        end

        row:Show()
    end

    eventContent:SetHeight(math.max(20, #events * ROW_H + 4))
end

-- ============================================================
-- Init
-- ============================================================
function PhoneCalendarApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local PAD = 2

    -- Get current date
    local dateInfo = C_DateAndTime.GetCurrentCalendarTime()
    todayDay = dateInfo.monthDay
    todayMonth = dateInfo.month
    todayYear = dateInfo.year
    viewMonth = todayMonth
    viewYear = todayYear

    -- Month/year header with arrows
    local headerFrame = CreateFrame("Frame", nil, parent)
    headerFrame:SetHeight(20)
    headerFrame:SetPoint("TOPLEFT", PAD, -2)
    headerFrame:SetPoint("TOPRIGHT", -PAD, -2)

    local prevBtn = CreateFrame("Button", nil, headerFrame)
    prevBtn:SetSize(24, 20)
    prevBtn:SetPoint("LEFT", 0, 0)
    local prevFs = prevBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    prevFs:SetPoint("CENTER")
    prevFs:SetText("|cffffffff<|r")
    local pvf = prevFs:GetFont()
    if pvf then prevFs:SetFont(pvf, 12, "") end
    local prevHl = prevBtn:CreateTexture(nil, "HIGHLIGHT")
    prevHl:SetAllPoints()
    prevHl:SetTexture(WHITE)
    prevHl:SetVertexColor(1, 1, 1, 0.1)
    prevBtn:SetScript("OnClick", function() ChangeMonth(-1) end)

    local nextBtn = CreateFrame("Button", nil, headerFrame)
    nextBtn:SetSize(24, 20)
    nextBtn:SetPoint("RIGHT", 0, 0)
    local nextFs = nextBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    nextFs:SetPoint("CENTER")
    nextFs:SetText("|cffffffff>|r")
    local nxf = nextFs:GetFont()
    if nxf then nextFs:SetFont(nxf, 12, "") end
    local nextHl = nextBtn:CreateTexture(nil, "HIGHLIGHT")
    nextHl:SetAllPoints()
    nextHl:SetTexture(WHITE)
    nextHl:SetVertexColor(1, 1, 1, 0.1)
    nextBtn:SetScript("OnClick", function() ChangeMonth(1) end)

    monthLabel = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    monthLabel:SetPoint("CENTER", -10, 0)
    local mf = monthLabel:GetFont()
    if mf then monthLabel:SetFont(mf, 10, "OUTLINE") end

    yearLabel = headerFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    yearLabel:SetPoint("LEFT", monthLabel, "RIGHT", 4, 0)
    local yf = yearLabel:GetFont()
    if yf then yearLabel:SetFont(yf, 9, "") end

    -- Calendar grid: fills ~55% of the vertical space
    gridFrame = CreateFrame("Frame", nil, parent)
    gridFrame:SetPoint("TOPLEFT", PAD, -24)
    gridFrame:SetPoint("RIGHT", -PAD, 0)
    gridFrame:SetHeight(130)

    -- Day name headers
    for i = 1, 7 do
        local dayFs = gridFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        dayFs:SetJustifyH("CENTER")
        dayFs:SetText("|cff888888" .. DAY_NAMES[i] .. "|r")
        local df = dayFs:GetFont()
        if df then dayFs:SetFont(df, 8, "") end
        dayHeaders[i] = dayFs
    end

    -- 6 rows x 7 cols of day cells (buttons for click)
    for row = 0, 5 do
        for col = 0, 6 do
            local idx = row * 7 + col + 1
            local cell = CreateFrame("Button", nil, gridFrame)
            cell:SetSize(20, 18)

            local bg = cell:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetTexture(WHITE)
            bg:SetVertexColor(0.15, 0.25, 0.35, 1)
            bg:Hide()

            local hl = cell:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetTexture(WHITE)
            hl:SetVertexColor(1, 1, 1, 0.08)

            local fs = cell:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            fs:SetPoint("CENTER")
            local cf = fs:GetFont()
            if cf then fs:SetFont(cf, 8, "") end

            local dot = cell:CreateTexture(nil, "OVERLAY")
            dot:SetSize(4, 4)
            dot:SetPoint("BOTTOM", 0, 1)
            dot:SetTexture(WHITE)
            dot:SetVertexColor(0.4, 0.8, 1, 0.8)
            dot:Hide()

            cell.bg = bg
            cell.fs = fs
            cell.dot = dot
            cell:SetScript("OnClick", function(self)
                if self.dayNum then
                    selectedDay = self.dayNum
                    UpdateCalendar()
                end
            end)
            dayCells[idx] = cell
        end
    end

    gridFrame:SetScript("OnSizeChanged", LayoutGrid)

    -- Separator line
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", gridFrame, "BOTTOMLEFT", 2, -2)
    sep:SetPoint("TOPRIGHT", gridFrame, "BOTTOMRIGHT", -2, -2)
    sep:SetHeight(1)
    sep:SetTexture(WHITE)
    sep:SetVertexColor(0.3, 0.3, 0.35, 0.5)

    -- Events header
    local eventsLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    eventsLabel:SetPoint("TOPLEFT", gridFrame, "BOTTOMLEFT", 2, -6)
    eventsLabel:SetText("|cff888888Events & Lockouts|r")
    local elf = eventsLabel:GetFont()
    if elf then eventsLabel:SetFont(elf, 8, "OUTLINE") end

    -- Scrollable event list (fills remaining space)
    eventScroll = CreateFrame("ScrollFrame", nil, parent)
    eventScroll:SetPoint("TOPLEFT", eventsLabel, "BOTTOMLEFT", 0, -2)
    eventScroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    eventScroll:EnableMouseWheel(true)
    eventScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = math.max(0, (eventContent:GetHeight() or 20) - self:GetHeight())
        self:SetVerticalScroll(math.min(maxS, math.max(0, cur - delta * 16)))
    end)

    eventContent = CreateFrame("Frame", nil, eventScroll)
    eventScroll:SetScrollChild(eventContent)

    C_Timer.After(0, function()
        local w = eventScroll:GetWidth()
        if w and w > 10 then
            eventContent:SetSize(w, 20)
        else
            eventContent:SetSize(140, 20)
        end
    end)

    -- Event rows are created on demand in UpdateEventList

    C_Timer.After(0.1, function()
        LayoutGrid()
        UpdateCalendar()
    end)
end

function PhoneCalendarApp:OnShow()
    local dateInfo = C_DateAndTime.GetCurrentCalendarTime()
    todayDay = dateInfo.monthDay
    todayMonth = dateInfo.month
    todayYear = dateInfo.year
    -- Fix event content width
    if eventScroll and eventContent then
        local w = eventScroll:GetWidth()
        if w and w > 10 then eventContent:SetWidth(w) end
    end
    UpdateCalendar()
end

function PhoneCalendarApp:OnHide()
end
