-- PhoneCalculator - Calculator app for HearthPhone

PhoneCalculatorApp = {}

local parent
local display, equationFs
local currentVal = "0"
local storedVal = nil
local pendingOp = nil
local justEvaluated = false

local function UpdateDisplay()
    -- Truncate for display
    local text = currentVal
    if #text > 12 then
        local num = tonumber(text)
        if num then
            text = format("%.6g", num)
        else
            text = text:sub(1, 12)
        end
    end
    display:SetText("|cffffffff" .. text .. "|r")

    -- Show equation
    if equationFs then
        if storedVal and pendingOp then
            equationFs:SetText("|cff888888" .. storedVal .. " " .. pendingOp .. "|r")
        elseif justEvaluated then
            equationFs:SetText("")
        end
    end
end

local function Clear()
    currentVal = "0"
    storedVal = nil
    pendingOp = nil
    justEvaluated = false
    if equationFs then equationFs:SetText("") end
    UpdateDisplay()
end

local function InputDigit(d)
    if justEvaluated then
        currentVal = d
        justEvaluated = false
    elseif currentVal == "0" and d ~= "." then
        currentVal = d
    else
        if d == "." and currentVal:find("%.") then return end
        currentVal = currentVal .. d
    end
    UpdateDisplay()
end

local function Evaluate()
    if not storedVal or not pendingOp then return end
    local a = tonumber(storedVal)
    local b = tonumber(currentVal)
    if not a or not b then return end

    -- Build equation string before we lose the values
    local eqText = storedVal .. " " .. pendingOp .. " " .. currentVal .. " ="

    local result
    if pendingOp == "+" then result = a + b
    elseif pendingOp == "-" then result = a - b
    elseif pendingOp == "x" then result = a * b
    elseif pendingOp == "/" then
        if b == 0 then
            currentVal = "Error"
            storedVal = nil
            pendingOp = nil
            justEvaluated = true
            if equationFs then equationFs:SetText("|cff888888" .. eqText .. "|r") end
            UpdateDisplay()
            return
        end
        result = a / b
    end

    if result then
        if result == math.floor(result) and math.abs(result) < 1e12 then
            currentVal = tostring(math.floor(result))
        else
            currentVal = tostring(result)
        end
    end

    storedVal = nil
    pendingOp = nil
    justEvaluated = true
    if equationFs then equationFs:SetText("|cff888888" .. eqText .. "|r") end
    UpdateDisplay()
end

local function InputOp(op)
    if storedVal and pendingOp and not justEvaluated then
        Evaluate()
    end
    storedVal = currentVal
    pendingOp = op
    justEvaluated = true
end

local function Negate()
    if currentVal == "0" or currentVal == "Error" then return end
    if currentVal:sub(1, 1) == "-" then
        currentVal = currentVal:sub(2)
    else
        currentVal = "-" .. currentVal
    end
    UpdateDisplay()
end

local function Percent()
    local n = tonumber(currentVal)
    if n then
        currentVal = tostring(n / 100)
        justEvaluated = true
        UpdateDisplay()
    end
end

function PhoneCalculatorApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    -- Button grid: 5 rows x 4 cols, anchored to bottom of parent
    local buttons = {
        { "C",  "+-", "%",  "/" },
        { "7",  "8",  "9",  "x" },
        { "4",  "5",  "6",  "-" },
        { "1",  "2",  "3",  "+" },
        { "0",  "0",  ".",  "=" },
    }

    local PAD = 3
    local btnGap = 2
    local numRows = #buttons
    local numCols = 4
    local btnH = 36
    local gridH = numRows * btnH + (numRows - 1) * btnGap

    -- Button grid container anchored to bottom
    local gridFrame = CreateFrame("Frame", nil, parent)
    gridFrame:SetHeight(gridH)
    gridFrame:SetPoint("BOTTOMLEFT", PAD, PAD)
    gridFrame:SetPoint("BOTTOMRIGHT", -PAD, PAD)

    -- Display fills everything above the grid
    local dispFrame = CreateFrame("Frame", nil, parent)
    dispFrame:SetPoint("TOPLEFT", PAD, -2)
    dispFrame:SetPoint("TOPRIGHT", -PAD, -2)
    dispFrame:SetPoint("BOTTOM", gridFrame, "TOP", 0, 4)

    local dispBg = dispFrame:CreateTexture(nil, "BACKGROUND")
    dispBg:SetAllPoints()
    dispBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    dispBg:SetVertexColor(0.06, 0.06, 0.08, 1)

    -- Equation line (smaller, above the result)
    equationFs = dispFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    equationFs:SetPoint("RIGHT", -10, 0)
    equationFs:SetPoint("TOP", 0, -6)
    equationFs:SetJustifyH("RIGHT")
    local eqf = equationFs:GetFont()
    if eqf then equationFs:SetFont(eqf, 10, "") end

    -- Result number
    display = dispFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    display:SetPoint("RIGHT", -10, 0)
    display:SetPoint("BOTTOM", 0, 8)
    display:SetJustifyH("RIGHT")
    display:SetText("|cffffffff0|r")
    local df = display:GetFont()
    if df then display:SetFont(df, 28, "") end

    local OP_COLOR = {0.20, 0.20, 0.30}
    local NUM_COLOR = {0.14, 0.14, 0.18}
    local FUNC_COLOR = {0.18, 0.18, 0.22}
    local EQ_COLOR = {0.25, 0.35, 0.25}

    -- Calculate button width from grid frame width (defer with OnSizeChanged)
    local allBtns = {}

    for ri, row in ipairs(buttons) do
        for ci, label in ipairs(row) do
            if ri == 5 and ci == 2 then
                -- skip, handled by wide 0 button
            else
                local btn = CreateFrame("Button", nil, gridFrame)
                local colSpan = 1
                if ri == 5 and ci == 1 then colSpan = 2 end

                -- Store layout info for resize
                btn._row = ri
                btn._col = ci
                btn._colSpan = colSpan

                local bgColor
                if label == "=" then
                    bgColor = EQ_COLOR
                elseif label == "/" or label == "x" or label == "-" or label == "+" then
                    bgColor = OP_COLOR
                elseif label == "C" or label == "+-" or label == "%" then
                    bgColor = FUNC_COLOR
                else
                    bgColor = NUM_COLOR
                end

                local bg = btn:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetTexture("Interface\\Buttons\\WHITE8x8")
                bg:SetVertexColor(bgColor[1], bgColor[2], bgColor[3], 1)

                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetTexture("Interface\\Buttons\\WHITE8x8")
                hl:SetVertexColor(1, 1, 1, 0.12)

                local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                fs:SetPoint("CENTER")
                fs:SetText("|cffffffff" .. label .. "|r")
                local fsf = fs:GetFont()
                if fsf then fs:SetFont(fsf, 12, "") end

                local l = label
                btn:SetScript("OnClick", function()
                    if l == "C" then Clear()
                    elseif l == "+-" then Negate()
                    elseif l == "%" then Percent()
                    elseif l == "=" then Evaluate()
                    elseif l == "+" or l == "-" or l == "x" or l == "/" then InputOp(l)
                    else InputDigit(l)
                    end
                end)

                table.insert(allBtns, btn)
            end
        end
    end

    -- Position buttons based on actual grid width
    local function LayoutButtons()
        local gw = gridFrame:GetWidth()
        if not gw or gw < 10 then gw = 164 end
        local bw = math.floor((gw - (numCols - 1) * btnGap) / numCols)
        for _, btn in ipairs(allBtns) do
            local ri = btn._row
            local ci = btn._col
            local span = btn._colSpan
            local w = bw * span + (span - 1) * btnGap
            local x = (ci - 1) * (bw + btnGap)
            local y = -((ri - 1) * (btnH + btnGap))
            btn:ClearAllPoints()
            btn:SetSize(w, btnH)
            btn:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", x, y)
        end
    end

    gridFrame:SetScript("OnSizeChanged", LayoutButtons)
    -- Also lay out immediately with fallback width
    C_Timer.After(0, LayoutButtons)
end

function PhoneCalculatorApp:OnShow()
    UpdateDisplay()
end

function PhoneCalculatorApp:OnHide()
end
