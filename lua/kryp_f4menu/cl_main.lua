KRYPF4 = KRYPF4 or {}
KRYPF4.JobStates = KRYPF4.JobStates or {}

local CFG = KRYPF4.Config
local C = CFG.Colors

local frame
local backgroundMaterial
local backgroundLoading = false
local teamIdCache = setmetatable({}, {__mode = "k"})

surface.CreateFont("KRYPF4.Category", {
    font = "Roboto",
    size = 20,
    weight = 500,
    antialias = true,
})

surface.CreateFont("KRYPF4.JobName", {
    font = "Roboto",
    size = 21,
    weight = 800,
    antialias = true,
})

surface.CreateFont("KRYPF4.JobDesc", {
    font = "Roboto",
    size = 15,
    weight = 400,
    antialias = true,
})

surface.CreateFont("KRYPF4.Small", {
    font = "Roboto",
    size = 14,
    weight = 600,
    antialias = true,
})

surface.CreateFont("KRYPF4.Button", {
    font = "Roboto",
    size = 16,
    weight = 700,
    antialias = true,
})

local function sx(value)
    return math.floor(ScrW() * value)
end

local function sy(value)
    return math.floor(ScrH() * value)
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

            -- Signature PNG : 89 50 4E 47 0D 0A 1A 0A
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
    if not job or CFG.HiddenJobCommands[job.command or ""] then return false end
    return true
end

local function getCategories()
    local output = {}

    if DarkRP and DarkRP.getCategories then
        local all = DarkRP.getCategories()
        local jobs = all and all.jobs or nil

        if istable(jobs) then
            for _, category in ipairs(jobs) do
                if categoryVisible(category) then
                    output[#output + 1] = category
                end
            end
        end
    end

    -- Fallback si un gamemode dérivé n'expose pas les catégories DarkRP classiques.
    if #output == 0 and istable(RPExtraTeams) then
        local byName = {}
        for _, job in pairs(RPExtraTeams) do
            local name = job.category or "Autres"
            byName[name] = byName[name] or {name = name, members = {}}
            byName[name].members[#byName[name].members + 1] = job
        end
        for _, category in SortedPairs(byName) do
            output[#output + 1] = category
        end
    end

    return output
end

local function statusFor(teamID)
    return KRYPF4.JobStates[teamID] or {
        protected = false,
        hasWhitelist = false,
        protectionKnown = false,
        whitelistAvailable = false,
    }
end

local function cardColors(teamID, hovered)
    local state = statusFor(teamID)

    if state.protected and state.hasWhitelist then
        return hovered and C.whitelistAllowedHover or C.whitelistAllowed, C.whitelistAllowedBorder
    end

    if state.protected and not state.hasWhitelist then
        return hovered and C.whitelistDeniedHover or C.whitelistDenied, C.whitelistDeniedBorder
    end

    return hovered and C.normalHover or C.normal, C.normalBorder
end

local function createJobCard(parent, job)
    local teamID = getTeamID(job)
    if not teamID then return end

    local card = vgui.Create("DPanel")
    parent:AddItem(card)
    card:Dock(TOP)
    card:DockMargin(0, 0, 5, CFG.JobSpacing)
    card:SetTall(CFG.JobCardHeight)
    card:SetMouseInputEnabled(true)

    card.Paint = function(self, w, h)
        local hovered = self:IsHovered()
        local bg, border = cardColors(teamID, hovered)

        roundedBox(5, 0, 0, w, h, bg)
        surface.SetDrawColor(border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local circleX = 35
        local circleY = h * 0.5
        local circleColor = job.color or Color(58, 58, 58)
        draw.NoTexture()
        surface.SetDrawColor(Color(circleColor.r, circleColor.g, circleColor.b, 230))

        local poly = {}
        local radius = 25
        local segments = 32
        for i = 0, segments do
            local a = math.rad((i / segments) * -360)
            poly[#poly + 1] = {
                x = circleX + math.sin(a) * radius,
                y = circleY + math.cos(a) * radius,
            }
        end
        surface.DrawPoly(poly)

        local rightReserve = 205
        local textX = 72
        local maxTextW = math.max(100, w - textX - rightReserve)

        draw.SimpleText(truncateText(job.name or team.GetName(teamID), "KRYPF4.JobName", maxTextW), "KRYPF4.JobName", textX, 18, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local description = job.description or "Aucune description pour ce métier."
        description = string.gsub(description, "[\r\n]+", " ")
        draw.SimpleText(truncateText(description, "KRYPF4.JobDesc", maxTextW), "KRYPF4.JobDesc", textX, 46, C.muted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if CFG.ShowJobSlots then
            local maximum = tonumber(job.max) or 0
            local slots = maximum == 0 and tostring(team.NumPlayers(teamID)) or (team.NumPlayers(teamID) .. "/" .. maximum)
            draw.SimpleText(slots, "KRYPF4.Small", w - 170, 17, Color(205, 205, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local state = statusFor(teamID)
        local statusText = "Public"
        local statusColor = Color(170, 170, 170)

        if state.protected and state.hasWhitelist then
            statusText = "Whitelist obtenue"
            statusColor = Color(126, 235, 155)
        elseif state.protected then
            statusText = "Whitelist requise"
            statusColor = Color(255, 135, 135)
        elseif not state.protectionKnown and state.whitelistAvailable then
            statusText = "Public / non détecté"
        end

        draw.SimpleText(statusText, "KRYPF4.Small", w - 170, 39, statusColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local select = vgui.Create("DButton", card)
    select:SetText("")
    select:SetSize(142, 34)
    select:SetPos(card:GetWide() - 152, CFG.JobCardHeight - 41)

    select.Think = function(self)
        self:SetPos(card:GetWide() - 152, CFG.JobCardHeight - 41)
    end

    select.Paint = function(self, w, h)
        local state = statusFor(teamID)
        local denied = state.protected and not state.hasWhitelist
        local current = LocalPlayer():Team() == teamID

        local color
        if denied then
            color = self:IsHovered() and C.buttonDeniedHover or C.buttonDenied
        elseif current then
            color = Color(70, 70, 70, 245)
        else
            color = self:IsHovered() and C.buttonNormalHover or C.buttonNormal
        end

        roundedBox(4, 0, 0, w, h, color)

        local label = denied and "Non autorisé" or (current and "Actuel" or "Devenir")
        draw.SimpleText(label, "KRYPF4.Button", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    select.DoClick = function()
        local state = statusFor(teamID)
        if state.protected and not state.hasWhitelist then
            surface.PlaySound("buttons/button10.wav")
            return
        end

        if LocalPlayer():Team() == teamID then return end

        net.Start("krypf4_select_job")
            net.WriteUInt(teamID, 16)
        net.SendToServer()

        surface.PlaySound("buttons/button15.wav")

        if CFG.CloseAfterJobRequest and IsValid(frame) then
            frame:Close()
        end
    end
end

local function createMenu()
    if IsValid(frame) then
        frame:Remove()
        frame = nil
        return
    end

    loadBackground(false)
    requestStates()

    frame = vgui.Create("DFrame")
    frame:SetSize(ScrW(), ScrH())
    frame:SetPos(0, 0)
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(true)

    frame.Paint = function(_, w, h)
        if backgroundMaterial and not backgroundMaterial:IsError() then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(backgroundMaterial)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            surface.SetDrawColor(13, 14, 15, 255)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("Rejoignez votre métier.", "KRYPF4.JobName", w * 0.5, 42, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(80, 80, 80, 220)
            surface.DrawLine(sx(0.288), sy(0.11), sx(0.288), sy(0.89))
        end
    end

    frame.OnClose = function()
        frame = nil
    end

    local categoriesPanel = vgui.Create("DScrollPanel", frame)
    categoriesPanel:SetPos(sx(CFG.Layout.categoryX), sy(CFG.Layout.categoryY))
    categoriesPanel:SetSize(sx(CFG.Layout.categoryW), sy(CFG.Layout.categoryH))

    local categoriesBar = categoriesPanel:GetVBar()
    categoriesBar:SetWide(3)
    categoriesBar.Paint = function() end
    categoriesBar.btnUp.Paint = function() end
    categoriesBar.btnDown.Paint = function() end
    categoriesBar.btnGrip.Paint = function(self, w, h)
        roundedBox(2, 0, 0, w, h, Color(95, 95, 95, 150))
    end

    local jobsPanel = vgui.Create("DScrollPanel", frame)
    jobsPanel:SetPos(sx(CFG.Layout.jobsX), sy(CFG.Layout.jobsY))
    jobsPanel:SetSize(sx(CFG.Layout.jobsW), sy(CFG.Layout.jobsH))

    local jobsBar = jobsPanel:GetVBar()
    jobsBar:SetWide(3)
    jobsBar.Paint = function() end
    jobsBar.btnUp.Paint = function() end
    jobsBar.btnDown.Paint = function() end
    jobsBar.btnGrip.Paint = function(self, w, h)
        roundedBox(2, 0, 0, w, h, Color(95, 95, 95, 150))
    end

    local selectedButton

    local function showCategory(category, button)
        jobsPanel:GetCanvas():Clear()
        selectedButton = button

        for _, job in ipairs(category.members or {}) do
            if jobVisible(job) then
                createJobCard(jobsPanel, job)
            end
        end
    end

    local categories = getCategories()

    for index, category in ipairs(categories) do
        local btn = vgui.Create("DButton")
        categoriesPanel:AddItem(btn)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 7, CFG.CategorySpacing)
        btn:SetTall(CFG.CategoryButtonHeight)
        btn:SetText("")

        btn.Paint = function(self, w, h)
            local selected = selectedButton == self
            local color = selected and C.categorySelected or (self:IsHovered() and C.categoryHover or C.category)

            roundedBox(4, 0, 0, w, h, color)
            surface.SetDrawColor(C.categoryBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            local label = category.name or "Catégorie"
            if CFG.ShowCategoryCount then
                label = label .. "  (" .. tostring(#(category.members or {})) .. ")"
            end

            draw.SimpleText(truncateText(label, "KRYPF4.Category", w - 28), "KRYPF4.Category", w * 0.5, h * 0.5, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function()
            showCategory(category, btn)
            surface.PlaySound("buttons/lightswitch2.wav")
        end

        if index == 1 then
            timer.Simple(0, function()
                if IsValid(frame) and IsValid(btn) then
                    showCategory(category, btn)
                end
            end)
        end
    end
end

hook.Add("ShowSpare2", "KRYPF4_ReplaceDarkRPF4", function()
    createMenu()
    return true
end)

concommand.Add("kryp_f4", createMenu)

hook.Add("OnScreenSizeChanged", "KRYPF4_CloseOnResolutionChange", function()
    if IsValid(frame) then frame:Remove() end
    frame = nil
end)
