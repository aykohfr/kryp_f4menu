KRYPF4 = KRYPF4 or {}
KRYPF4.JobStates = KRYPF4.JobStates or {}

local CFG = KRYPF4.Config
local C = CFG.Colors

local frame
local backgroundMaterial
local backgroundLoading = false
local teamIdCache = setmetatable({}, {__mode = "k"})

local fontScale = math.Clamp(ScrH() / 1080, 0.85, 1.15)

surface.CreateFont("KRYPF4.Category", {font = "Roboto", size = math.floor(18 * fontScale), weight = 650, antialias = true})
surface.CreateFont("KRYPF4.JobName", {font = "Roboto", size = math.floor(20 * fontScale), weight = 850, antialias = true})
surface.CreateFont("KRYPF4.JobDesc", {font = "Roboto", size = math.floor(14 * fontScale), weight = 450, antialias = true})
surface.CreateFont("KRYPF4.MetaLabel", {font = "Roboto", size = math.floor(10 * fontScale), weight = 800, antialias = true})
surface.CreateFont("KRYPF4.MetaValue", {font = "Roboto", size = math.floor(13 * fontScale), weight = 800, antialias = true})
surface.CreateFont("KRYPF4.Button", {font = "Roboto", size = math.floor(14 * fontScale), weight = 850, antialias = true})
surface.CreateFont("KRYPF4.Status", {font = "Roboto", size = math.floor(10 * fontScale), weight = 850, antialias = true})

local function roundedBox(radius, x, y, w, h, color)
    draw.RoundedBox(radius, x, y, w, h, color)
end

local function truncateText(text, font, maxWidth)
    text = tostring(text or "")
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxWidth then return text end

    local suffix = "..."
    local suffixW = surface.GetTextSize(suffix)
    local low, high = 0, #text
    local best = ""

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local candidate = string.sub(text, 1, mid)
        local width = surface.GetTextSize(candidate)
        if width + suffixW <= maxWidth then
            best = candidate
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return best .. suffix
end

local function drawCircle(x, y, radius, color)
    draw.NoTexture()
    surface.SetDrawColor(color)
    local poly = {}
    local segments = 32
    for i = 0, segments do
        local angle = math.rad((i / segments) * -360)
        poly[#poly + 1] = {x = x + math.sin(angle) * radius, y = y + math.cos(angle) * radius}
    end
    surface.DrawPoly(poly)
end

local function getTeamID(job)
    if teamIdCache[job] then return teamIdCache[job] end
    for teamID, current in pairs(RPExtraTeams or {}) do
        if current == job or (job.command and current.command == job.command) then
            teamIdCache[job] = teamID
            return teamID
        end
    end
end

local function setBackgroundFromData()
    if not file.Exists(CFG.BackgroundDataPath, "DATA") then return false end
    backgroundMaterial = Material("../data/" .. CFG.BackgroundDataPath, "smooth noclamp")
    return backgroundMaterial and not backgroundMaterial:IsError()
end

local function loadBackground(forceRefresh)
    if backgroundLoading then return end
    if not forceRefresh and setBackgroundFromData() then return end
    backgroundLoading = true

    http.Fetch(CFG.BackgroundURL,
        function(body, _, _, code)
            backgroundLoading = false
            if code and (code < 200 or code >= 300) then return end
            if not isstring(body) or #body < 8 then return end
            if string.byte(body, 1) ~= 137 or string.sub(body, 2, 4) ~= "PNG" then return end
            file.CreateDir("kryp_f4menu")
            file.Write(CFG.BackgroundDataPath, body)
            setBackgroundFromData()
        end,
        function()
            backgroundLoading = false
        end
    )
end

local function requestStates()
    net.Start("krypf4_request_states")
    net.SendToServer()
end

net.Receive("krypf4_send_states", function()
    local count = net.ReadUInt(16)
    for _ = 1, count do
        local teamID = net.ReadUInt(16)
        KRYPF4.JobStates[teamID] = {
            protected = net.ReadBool(),
            hasWhitelist = net.ReadBool(),
            protectionKnown = net.ReadBool(),
            whitelistAvailable = net.ReadBool(),
        }
    end
end)

local function categoryVisible(category)
    if not category or CFG.HiddenCategories[category.name] then return false end
    if isfunction(category.canSee) then
        local ok, result = pcall(category.canSee, LocalPlayer())
        if ok and result == false then return false end
    end
    return true
end

local function jobVisible(job)
    return job and not CFG.HiddenJobCommands[job.command or ""]
end

local function getCategories()
    local output = {}
    if DarkRP and DarkRP.getCategories then
        local all = DarkRP.getCategories()
        local jobs = all and all.jobs or nil
        if istable(jobs) then
            for _, category in ipairs(jobs) do
                if categoryVisible(category) then output[#output + 1] = category end
            end
        end
    end

    if #output == 0 and istable(RPExtraTeams) then
        local byName = {}
        for _, job in pairs(RPExtraTeams) do
            local name = job.category or "Autres"
            byName[name] = byName[name] or {name = name, members = {}}
            byName[name].members[#byName[name].members + 1] = job
        end
        for _, category in SortedPairs(byName) do output[#output + 1] = category end
    end
    return output
end

local function statusFor(teamID)
    return KRYPF4.JobStates[teamID] or {protected = false, hasWhitelist = false, protectionKnown = false, whitelistAvailable = false}
end

local function getVisualState(teamID, hovered)
    local state = statusFor(teamID)
    if state.protected and state.hasWhitelist then
        return {bg = hovered and C.whitelistAllowedHover or C.whitelistAllowed, border = C.whitelistAllowedBorder, accent = C.whitelistAllowedAccent, pill = C.whitelistAllowedPill, statusText = "Whitelist OK", statusColor = C.whitelistAllowedText, denied = false}
    end
    if state.protected and not state.hasWhitelist then
        return {bg = hovered and C.whitelistDeniedHover or C.whitelistDenied, border = C.whitelistDeniedBorder, accent = C.whitelistDeniedAccent, pill = C.whitelistDeniedPill, statusText = "Whitelist requise", statusColor = C.whitelistDeniedText, denied = true}
    end
    return {bg = hovered and C.normalHover or C.normal, border = C.normalBorder, accent = C.normalAccent, pill = C.normalPill, statusText = "Public", statusColor = C.normalStatusText, denied = false}
end

local function createJobCard(parent, job, scale)
    local teamID = getTeamID(job)
    if not teamID then return end

    -- Hauteur minimale volontaire : empêche le bouton, les places et le badge de se chevaucher.
    local cardHeight = math.max(100, math.floor(114 * scale))
    local spacing = math.max(8, math.floor((CFG.JobSpacing or 9) * scale))
    local card = vgui.Create("DPanel")
    parent:AddItem(card)
    card:Dock(TOP)
    card:DockMargin(0, 0, 7, spacing)
    card:SetTall(cardHeight)
    card:SetMouseInputEnabled(true)

    local select

    card.Paint = function(self, w, h)
        local hovered = self:IsHovered() or (IsValid(select) and select:IsHovered())
        local visual = getVisualState(teamID, hovered)
        local current = LocalPlayer():Team() == teamID

        roundedBox(8, 0, 0, w, h, visual.bg)
        surface.SetDrawColor(visual.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        -- La couleur de statut reste sur le bord gauche : plus lisible et moins agressif.
        roundedBox(7, 0, 0, math.max(4, math.floor(4 * scale)), h, visual.accent)

        local padding = math.max(14, math.floor(16 * scale))
        local circleRadius = math.max(18, math.floor(22 * scale))
        local circleX = padding + circleRadius
        local circleY = math.floor(h * 0.5)
        local circleColor = job.color or Color(58, 58, 58)

        drawCircle(circleX, circleY, circleRadius + 2, Color(9, 10, 11, 235))
        drawCircle(circleX, circleY, circleRadius, Color(circleColor.r, circleColor.g, circleColor.b, 235))

        local buttonW = math.max(118, math.floor(132 * scale))
        local actionX = w - padding - buttonW
        local infoW = math.max(112, math.floor(128 * scale))
        local infoGap = math.max(12, math.floor(14 * scale))
        local infoX = actionX - infoGap - infoW

        -- Bloc dédié aux informations secondaires.
        roundedBox(6, infoX - math.floor(10 * scale), math.floor(12 * scale), infoW + math.floor(16 * scale), h - math.floor(24 * scale), Color(0, 0, 0, 28))

        local textX = circleX + circleRadius + math.max(14, math.floor(16 * scale))
        local textMax = math.max(100, infoX - textX - math.max(14, math.floor(16 * scale)))

        draw.SimpleText(truncateText(job.name or team.GetName(teamID), "KRYPF4.JobName", textMax), "KRYPF4.JobName", textX, math.floor(h * 0.35), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local description = tostring(job.description or "Aucune description pour ce métier.")
        description = string.gsub(description, "[\r\n]+", " ")
        draw.SimpleText(truncateText(description, "KRYPF4.JobDesc", textMax), "KRYPF4.JobDesc", textX, math.floor(h * 0.65), C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- PLACES et ACCÈS sont séparés du bouton d'action.
        draw.SimpleText("PLACES", "KRYPF4.MetaLabel", infoX, math.floor(h * 0.25), Color(132, 136, 143), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local maximum = tonumber(job.max) or 0
        local players = team.NumPlayers(teamID)
        local slots = maximum == 0 and tostring(players) or (players .. " / " .. maximum)
        draw.SimpleText(slots, "KRYPF4.MetaValue", infoX, math.floor(h * 0.43), C.slotText or Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        surface.SetFont("KRYPF4.Status")
        local statusW = math.min(infoW, math.max(math.floor(74 * scale), surface.GetTextSize(visual.statusText) + math.floor(20 * scale)))
        local statusH = math.max(21, math.floor(23 * scale))
        local statusY = math.floor(h * 0.61)
        roundedBox(5, infoX, statusY, statusW, statusH, visual.pill)
        draw.SimpleText(visual.statusText, "KRYPF4.Status", infoX + statusW * 0.5, statusY + statusH * 0.5, visual.statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        if current then
            draw.SimpleText("MÉTIER ACTUEL", "KRYPF4.MetaLabel", actionX + buttonW * 0.5, math.floor(h * 0.24), Color(168, 173, 181), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    select = vgui.Create("DButton", card)
    select:SetText("")
    select:SetCursor("hand")
    local buttonW = math.max(118, math.floor(132 * scale))
    local buttonH = math.max(38, math.floor(40 * scale))
    select:SetSize(buttonW, buttonH)

    select.Think = function(self)
        if not IsValid(card) then return end
        local padding = math.max(14, math.floor(16 * scale))
        self:SetPos(card:GetWide() - padding - buttonW, math.floor((card:GetTall() - buttonH) * 0.5))
    end

    select.Paint = function(self, w, h)
        local visual = getVisualState(teamID, self:IsHovered())
        local current = LocalPlayer():Team() == teamID
        local color = self:IsHovered() and C.buttonNormalHover or C.buttonNormal
        local textColor = color_white

        if visual.denied then
            color = self:IsHovered() and C.buttonDeniedHover or C.buttonDenied
        elseif current then
            color = self:IsHovered() and C.buttonCurrentHover or C.buttonCurrent
            textColor = C.buttonCurrentText
        end

        roundedBox(6, 0, 0, w, h, color)
        local label = visual.denied and "Verrouillé" or (current and "Actuel" or "Devenir")
        draw.SimpleText(label, "KRYPF4.Button", w * 0.5, h * 0.5, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    select.DoClick = function()
        local state = statusFor(teamID)
        if state.protected and not state.hasWhitelist then return end
        if LocalPlayer():Team() == teamID then return end

        net.Start("krypf4_select_job")
            net.WriteUInt(teamID, 16)
        net.SendToServer()

        if CFG.CloseAfterJobRequest and IsValid(frame) then frame:Close() end
    end
end

local function calculateMenuSize()
    local width = math.floor(ScrW() * (CFG.MenuWidthFraction or 0.86))
    local maxHeight = math.floor(ScrH() * (CFG.MenuHeightFraction or 0.82))
    local aspect = CFG.MenuAspectRatio or (1648 / 928)
    local height = math.floor(width / aspect)
    if height > maxHeight then
        height = maxHeight
        width = math.floor(height * aspect)
    end
    width = math.min(width, ScrW() - 32)
    height = math.min(height, ScrH() - 32)
    return width, height
end

local function createMenu()
    if IsValid(frame) then frame:Close() return end

    loadBackground(false)
    requestStates()

    local menuW, menuH = calculateMenuSize()
    local scale = math.Clamp(menuH / 928, 0.72, 1.05)

    frame = vgui.Create("DFrame")
    frame:SetSize(menuW, menuH)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:SetSizable(false)
    frame:SetDeleteOnClose(true)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(true)
    frame:SetMouseInputEnabled(true)
    frame.KRYPF4F4WasDown = input.IsKeyDown(KEY_F4)

    frame.Think = function(self)
        local isDown = input.IsKeyDown(KEY_F4)
        if isDown and not self.KRYPF4F4WasDown then self:Close() return end
        self.KRYPF4F4WasDown = isDown
    end

    frame.Paint = function(_, w, h)
        if backgroundMaterial and not backgroundMaterial:IsError() then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(backgroundMaterial)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            surface.SetDrawColor(13, 14, 15, 255)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("Rejoignez votre métier.", "KRYPF4.JobName", w * 0.5, h * 0.055, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(80, 80, 80, 220)
            surface.DrawLine(math.floor(w * 0.288), math.floor(h * 0.11), math.floor(w * 0.288), math.floor(h * 0.89))
        end
    end

    frame.OnClose = function() frame = nil end
    local function px(value) return math.floor(menuW * value) end
    local function py(value) return math.floor(menuH * value) end

    local categoriesPanel = vgui.Create("DScrollPanel", frame)
    categoriesPanel:SetPos(px(CFG.Layout.categoryX), py(CFG.Layout.categoryY))
    categoriesPanel:SetSize(px(CFG.Layout.categoryW), py(CFG.Layout.categoryH))
    local categoriesBar = categoriesPanel:GetVBar()
    categoriesBar:SetWide(3)
    categoriesBar.Paint = function() end
    categoriesBar.btnUp.Paint = function() end
    categoriesBar.btnDown.Paint = function() end
    categoriesBar.btnGrip.Paint = function(self, w, h) roundedBox(2, 0, 0, w, h, Color(105, 108, 114, 145)) end

    local jobsPanel = vgui.Create("DScrollPanel", frame)
    jobsPanel:SetPos(px(CFG.Layout.jobsX), py(CFG.Layout.jobsY))
    jobsPanel:SetSize(px(CFG.Layout.jobsW), py(CFG.Layout.jobsH))
    local jobsBar = jobsPanel:GetVBar()
    jobsBar:SetWide(3)
    jobsBar.Paint = function() end
    jobsBar.btnUp.Paint = function() end
    jobsBar.btnDown.Paint = function() end
    jobsBar.btnGrip.Paint = function(self, w, h) roundedBox(2, 0, 0, w, h, Color(105, 108, 114, 145)) end

    local selectedButton
    local function showCategory(category, button)
        jobsPanel:GetCanvas():Clear()
        selectedButton = button
        for _, job in ipairs(category.members or {}) do
            if jobVisible(job) then createJobCard(jobsPanel, job, scale) end
        end
    end

    local categories = getCategories()
    for index, category in ipairs(categories) do
        local btn = vgui.Create("DButton")
        categoriesPanel:AddItem(btn)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 6, math.max(5, math.floor((CFG.CategorySpacing or 9) * scale)))
        btn:SetTall(math.floor((CFG.CategoryButtonHeight or 54) * scale))
        btn:SetText("")
        btn:SetCursor("hand")

        btn.Paint = function(self, w, h)
            local selected = selectedButton == self
            local color = selected and C.categorySelected or (self:IsHovered() and C.categoryHover or C.category)
            local border = selected and C.categorySelectedBorder or C.categoryBorder
            roundedBox(6, 0, 0, w, h, color)
            surface.SetDrawColor(border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            if selected then roundedBox(5, 0, math.floor(h * 0.18), math.max(3, math.floor(3 * scale)), math.floor(h * 0.64), C.categoryAccent) end
            local label = category.name or "Catégorie"
            if CFG.ShowCategoryCount then label = label .. "  (" .. tostring(#(category.members or {})) .. ")" end
            draw.SimpleText(truncateText(label, "KRYPF4.Category", w - math.floor(28 * scale)), "KRYPF4.Category", math.floor(16 * scale), h * 0.5, selected and C.text or C.categoryText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function() showCategory(category, btn) end
        if index == 1 then
            timer.Simple(0, function()
                if IsValid(frame) and IsValid(btn) then showCategory(category, btn) end
            end)
        end
    end

    local closeHitbox = vgui.Create("DButton", frame)
    closeHitbox:SetText("")
    closeHitbox:SetCursor("hand")
    closeHitbox:SetPos(px(0.020), py(0.905))
    closeHitbox:SetSize(px(0.125), py(0.065))
    closeHitbox.Paint = function(self, w, h)
        if self:IsHovered() then roundedBox(5, 0, 0, w, h, Color(255, 255, 255, 8)) end
    end
    closeHitbox.DoClick = function() if IsValid(frame) then frame:Close() end end
end

hook.Add("ShowSpare2", "KRYPF4_ReplaceDarkRPF4", function()
    createMenu()
    return true
end)

concommand.Add("kryp_f4", createMenu)

hook.Add("ShutDown", "KRYPF4_Cleanup", function()
    if IsValid(frame) then frame:Remove() end
    frame = nil
end)
