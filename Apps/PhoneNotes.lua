-- PhoneNotes - Simple notepad app for HearthPhone
-- Saves notes to SavedVariables (HearthPhoneDB.notes)

PhoneNotesApp = {}

local parent
local notesList = {}
local currentNote = nil
local listView, editView
local listScroll, listContent, noteButtons
local titleBox, bodyBox, saveBtn, deleteBtn, backBtn
local noNotesFs

local ROW_H = 26

local function SaveNotes()
    HearthPhoneDB = HearthPhoneDB or {}
    HearthPhoneDB.notes = notesList
end

local function LoadNotes()
    HearthPhoneDB = HearthPhoneDB or {}
    notesList = HearthPhoneDB.notes or {}
end

local function ShowEdit(note)
    currentNote = note
    titleBox:SetText(note and note.title or "")
    bodyBox:SetText(note and note.body or "")
    listView:Hide()
    editView:Show()
    titleBox:SetFocus()
end

local function ShowList()
    currentNote = nil
    editView:Hide()
    listView:Show()
end

local function BuildList()
    if noteButtons then
        for _, btn in ipairs(noteButtons) do
            btn:Hide()
            btn:SetParent(nil)
        end
    end
    noteButtons = {}

    noNotesFs:SetShown(#notesList == 0)

    local W = listScroll:GetWidth()
    if not W or W < 10 then W = 160 end

    for i, note in ipairs(notesList) do
        local btn = CreateFrame("Button", nil, listContent)
        btn:SetHeight(ROW_H)
        btn:SetPoint("TOPLEFT", 0, -((i - 1) * ROW_H))
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8x8")
        bg:SetVertexColor(0.1, 0.1, 0.13, 1)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture("Interface\\Buttons\\WHITE8x8")
        hl:SetVertexColor(0.2, 0.2, 0.25, 0.4)

        local titleFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        titleFs:SetPoint("TOPLEFT", 6, -3)
        titleFs:SetPoint("RIGHT", -6, 0)
        titleFs:SetJustifyH("LEFT")
        local displayTitle = note.title ~= "" and note.title or "Untitled"
        titleFs:SetText("|cffffffff" .. displayTitle .. "|r")
        local tf = titleFs:GetFont()
        if tf then titleFs:SetFont(tf, 8, "") end

        local previewFs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        previewFs:SetPoint("BOTTOMLEFT", 6, 3)
        previewFs:SetPoint("RIGHT", -6, 0)
        previewFs:SetJustifyH("LEFT")
        local preview = (note.body or ""):sub(1, 30):gsub("\n", " ")
        previewFs:SetText("|cff666666" .. preview .. "|r")
        local pf = previewFs:GetFont()
        if pf then previewFs:SetFont(pf, 7, "") end

        -- Separator
        local sep = btn:CreateTexture(nil, "ARTWORK")
        sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT", 4, 0)
        sep:SetPoint("BOTTOMRIGHT", -4, 0)
        sep:SetTexture("Interface\\Buttons\\WHITE8x8")
        sep:SetVertexColor(0.2, 0.2, 0.25, 0.5)

        local idx = i
        btn:SetScript("OnClick", function()
            ShowEdit(notesList[idx])
        end)

        noteButtons[i] = btn
    end

    listContent:SetSize(W, #notesList * ROW_H)
    listScroll:SetVerticalScroll(0)
end

function PhoneNotesApp:Init(parentFrame)
    if parent then return end
    parent = parentFrame

    local W = parent:GetWidth() or 170

    -- ======== LIST VIEW ========
    listView = CreateFrame("Frame", nil, parent)
    listView:SetAllPoints()

    local title = listView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -2)
    title:SetText("|cffffffffNotes|r")
    local ttf = title:GetFont()
    if ttf then title:SetFont(ttf, 11, "OUTLINE") end

    -- New note button
    local newBtn = CreateFrame("Button", nil, listView)
    newBtn:SetSize(20, 14)
    newBtn:SetPoint("TOPRIGHT", -4, -2)

    local newBg = newBtn:CreateTexture(nil, "BACKGROUND")
    newBg:SetAllPoints()
    newBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    newBg:SetVertexColor(0.15, 0.15, 0.2, 1)

    local newHl = newBtn:CreateTexture(nil, "HIGHLIGHT")
    newHl:SetAllPoints()
    newHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    newHl:SetVertexColor(0.25, 0.25, 0.3, 0.4)

    local newLabel = newBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    newLabel:SetPoint("CENTER")
    newLabel:SetText("|cffffffff+|r")
    local nlf = newLabel:GetFont()
    if nlf then newLabel:SetFont(nlf, 10, "OUTLINE") end

    newBtn:SetScript("OnClick", function()
        local note = { title = "", body = "" }
        table.insert(notesList, 1, note)
        SaveNotes()
        ShowEdit(note)
    end)

    -- No notes message
    noNotesFs = listView:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    noNotesFs:SetPoint("CENTER", 0, -10)
    noNotesFs:SetText("|cff555555No notes yet.\nTap + to create one.|r")
    local nnf = noNotesFs:GetFont()
    if nnf then noNotesFs:SetFont(nnf, 8, "") end

    -- Scroll area
    listScroll = CreateFrame("ScrollFrame", nil, listView)
    listScroll:SetPoint("TOPLEFT", 2, -18)
    listScroll:SetPoint("BOTTOMRIGHT", -2, 2)

    listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(1, 1)
    listScroll:SetScrollChild(listContent)

    listScroll:EnableMouseWheel(true)
    listScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = max(0, listContent:GetHeight() - self:GetHeight())
        local newS = min(maxS, max(0, cur - delta * 40))
        self:SetVerticalScroll(newS)
    end)

    -- ======== EDIT VIEW ========
    editView = CreateFrame("Frame", nil, parent)
    editView:SetAllPoints()
    editView:Hide()

    -- Back button
    backBtn = CreateFrame("Button", nil, editView)
    backBtn:SetSize(24, 14)
    backBtn:SetPoint("TOPLEFT", 4, -2)

    local backBg = backBtn:CreateTexture(nil, "BACKGROUND")
    backBg:SetAllPoints()
    backBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    backBg:SetVertexColor(0.15, 0.15, 0.2, 1)

    local backHl = backBtn:CreateTexture(nil, "HIGHLIGHT")
    backHl:SetAllPoints()
    backHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    backHl:SetVertexColor(0.25, 0.25, 0.3, 0.4)

    local backLabel = backBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    backLabel:SetPoint("CENTER")
    backLabel:SetText("|cffffffff< Back|r")
    local blf = backLabel:GetFont()
    if blf then backLabel:SetFont(blf, 7, "") end

    backBtn:SetScript("OnClick", function()
        -- Auto-save on back
        if currentNote then
            currentNote.title = titleBox:GetText() or ""
            currentNote.body = bodyBox:GetText() or ""
            -- Remove if empty
            if currentNote.title == "" and currentNote.body == "" then
                for i, n in ipairs(notesList) do
                    if n == currentNote then
                        table.remove(notesList, i)
                        break
                    end
                end
            end
            SaveNotes()
        end
        BuildList()
        ShowList()
    end)

    -- Delete button
    deleteBtn = CreateFrame("Button", nil, editView)
    deleteBtn:SetSize(24, 14)
    deleteBtn:SetPoint("TOPRIGHT", -4, -2)

    local delBg = deleteBtn:CreateTexture(nil, "BACKGROUND")
    delBg:SetAllPoints()
    delBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    delBg:SetVertexColor(0.3, 0.08, 0.08, 1)

    local delHl = deleteBtn:CreateTexture(nil, "HIGHLIGHT")
    delHl:SetAllPoints()
    delHl:SetTexture("Interface\\Buttons\\WHITE8x8")
    delHl:SetVertexColor(0.5, 0.15, 0.15, 0.4)

    local delLabel = deleteBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    delLabel:SetPoint("CENTER")
    delLabel:SetText("|cffff4444Del|r")
    local dlf = delLabel:GetFont()
    if dlf then delLabel:SetFont(dlf, 7, "") end

    deleteBtn:SetScript("OnClick", function()
        if currentNote then
            for i, n in ipairs(notesList) do
                if n == currentNote then
                    table.remove(notesList, i)
                    break
                end
            end
            SaveNotes()
        end
        BuildList()
        ShowList()
    end)

    -- Title input
    titleBox = CreateFrame("EditBox", nil, editView)
    titleBox:SetSize(W - 12, 16)
    titleBox:SetPoint("TOP", 0, -20)
    titleBox:SetFontObject(GameFontNormalSmall)
    local tbf = titleBox:GetFont()
    if tbf then titleBox:SetFont(tbf, 9, "") end
    titleBox:SetTextColor(1, 1, 1, 1)
    titleBox:SetAutoFocus(false)
    titleBox:SetMaxLetters(50)

    local titleBg = titleBox:CreateTexture(nil, "BACKGROUND")
    titleBg:SetPoint("TOPLEFT", -4, 4)
    titleBg:SetPoint("BOTTOMRIGHT", 4, -4)
    titleBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    titleBg:SetVertexColor(0.12, 0.12, 0.15, 1)

    local titlePh = titleBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    titlePh:SetPoint("LEFT", 2, 0)
    titlePh:SetText("|cff555555Title...|r")
    local tphf = titlePh:GetFont()
    if tphf then titlePh:SetFont(tphf, 9, "") end

    titleBox:SetScript("OnTextChanged", function(self)
        titlePh:SetShown((self:GetText() or "") == "")
    end)
    titleBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    titleBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        bodyBox:SetFocus()
    end)

    -- Separator
    local editSep = editView:CreateTexture(nil, "ARTWORK")
    editSep:SetHeight(1)
    editSep:SetPoint("TOPLEFT", 4, -40)
    editSep:SetPoint("RIGHT", -4, 0)
    editSep:SetTexture("Interface\\Buttons\\WHITE8x8")
    editSep:SetVertexColor(0.2, 0.2, 0.25, 0.5)

    -- Body input (multi-line)
    local bodyScroll = CreateFrame("ScrollFrame", "PhoneNotesBodyScroll", editView, "UIPanelScrollFrameTemplate")
    bodyScroll:SetPoint("TOPLEFT", 4, -44)
    bodyScroll:SetPoint("BOTTOMRIGHT", -4, 4)

    bodyBox = CreateFrame("EditBox", nil, bodyScroll)
    bodyBox:SetWidth(W - 20)
    bodyBox:SetFontObject(GameFontNormalSmall)
    local bbf = bodyBox:GetFont()
    if bbf then bodyBox:SetFont(bbf, 8, "") end
    bodyBox:SetTextColor(0.9, 0.9, 0.9, 1)
    bodyBox:SetAutoFocus(false)
    bodyBox:SetMultiLine(true)
    bodyBox:SetMaxLetters(1000)
    bodyScroll:SetScrollChild(bodyBox)

    bodyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
end

function PhoneNotesApp:OnShow()
    LoadNotes()
    BuildList()
    ShowList()
end

function PhoneNotesApp:OnHide()
    -- Auto-save current note
    if currentNote and editView:IsShown() then
        currentNote.title = titleBox:GetText() or ""
        currentNote.body = bodyBox:GetText() or ""
        if currentNote.title == "" and currentNote.body == "" then
            for i, n in ipairs(notesList) do
                if n == currentNote then
                    table.remove(notesList, i)
                    break
                end
            end
        end
        SaveNotes()
    end
end
