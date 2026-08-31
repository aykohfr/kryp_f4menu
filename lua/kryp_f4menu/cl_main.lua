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
    size = 18,
    weight = 650,
    antialias = true,
})

surface.CreateFont("KRYPF4.JobName", {
    font = "Roboto",
    size = 20,
    weight = 800,
    antialias = true,
})

surface.CreateFont("KRYPF4.JobDesc", {
    font = "Roboto",
    size = 14,
    weight = 450,
    antialias = true,
})

surface.CreateFont("KRYPF4.Small", {
    font = "Roboto",
    size = 13,
    weight = 650,
    antialias = true,
})

surface.CreateFont("KRYPF4.Button", {
    font = "Roboto",
    size = 14,
    weight = 800,
    antialias = true,
})

surface.CreateFont("KRYPF4.Status", {
    font = "Roboto",
    size = 12,
    weight = 800,
    antialias = true,
})

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
        poly[#poly + 1] = {
            x = x + math.sin(angle) * radius,
            y = y + math.cos(angle) * radius,
        }
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

    -- Fallback pour les dérivés DarkRP qui n'exposent pas les catégories classiques.
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

local function getVisualState(teamID, hovered)
    local state = statusFor(teamID)

    if state.protected and state.hasWhitelist then
        return {
            bg = hovered and C.whitelistAllowedHover or C.whitelistAllowed,
            border = C.whitelistAllowedBorder,
            accent = C.whitelistAllowedAccent,
            pill = C.whitelistAllowedPill,
            statusText = "WHITELIST OK",
            statusColor = C.whitelistAllowedText,
            denied = false,
        }
    end

    if state.protected and not state.hasWhitelist then
        return {
            bg = hovered and C.whitelistDeniedHover or C.whitelistDenied,
            border = C.whitelistDeniedBorder,
            accent = C.whitelistDeniedAccent,
            pill = C.whitelistDeniedPill,
            statusText = "WHITELIST REQUISE",
            statusColor = C.whitelistDeniedText,
            denied = true,
        }
    end

    return {
        bg = hovered and C.normalHover or C.normal,
        border = C.normalBorder,
        accent = C.normalAccent,
        pill = C.normalPill,
        statusText = "PUBLIC",
        statusColor = C.normalStatusText,
        denied = false,
    }
end

local function createJobCard(parent, job, scale)
    local teamID = getTeamID(job)
    if not teamID then return end

    local cardHeight = math.floor(CFG.JobCardHeight * scale)
    local spacing = math.max(5, math.floor(CFG.JobSpacing * scale))

    local card = vgui.Create("DPanel")
    parent:AddItem(card)
    card:Dock(TOP)
    card:DockMargin(0, 0, 6, spacing)
    card:SetTall(cardHeight)
    card:SetMouseInputEnabled(true)

    card.Paint = function(self, w, h)
        local visual = getVisualState(teamID, self:IsHovered())
        local current = LocalPlayer():Team() == teamID

        roundedBox(7, 0, 0, w, h, visual.bg)

        surface.SetDrawColor(visual.border)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        -- Barre d'état discrète à gauche de la carte.
        roundedBox(6, 0, 0, math.max(4, math.floor(4 * scale)), h, visual.accent)

        local circleX = math.floor(39 * scale)
        local circleY = math.floor(h * 0.5)
        local circleRadius = math.max(17, math.floor(23 * scale))
        local circleColor = job.color or Color(58, 58, 58)

        drawCircle(circleX, circleY, circleRadius, Color(12, 13, 14, 225))
        drawCircle(circleX, circleY, circleRadius - 3, Color(circleColor.r, circleColor.g, circleColor.b, 235))

        local textX = math.floor(75 * scale)
        local rightReserve = math.floor(222 * scale)
        local maxTextW = math.max(110, w - textX - rightReserve)

        draw.SimpleText(
            truncateText(job.name or team.GetName(teamID), "KRYPF4.JobName", maxTextW),
            "KRYPF4.JobName",
            textX,
            math.floor(h * 0.33),
            C.text,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        local description = job.description or "Aucune description pour ce métier."
        description = string.gsub(description, "[\r\n]+", " ")

        draw.SimpleText(
            truncateText(description, "KRYPF4.JobDesc", maxTextW),
            "KRYPF4.JobDesc",
            textX,
            math.floor(h * 0.64),
            C.muted,
            TEXT_ALIGN_LEFT,
            TEXT_ALIGN_CENTER
        )

        local rightX = w - math.floor(18 * scale)

        if CFG.ShowJobSlots then
            local maximum = tonumber(job.max) or 0
            local slots = maximum == 0 and tostring(team.NumPlayers(teamID)) or (team.NumPlayers(teamID) .. "/" .. maximum)
            local slotsText = current and (slots .. "  •  ACTUEL") or slots

            draw.SimpleText(
                slotsText,
                "KRYPF4.Small",
                rightX,
                math.floor(h * 0.22),
                C.slotText,
                TEXT_ALIGN_RIGHT,
                TEXT_ALIGN_CENTER
            )
        end

        surface.SetFont("KRYPF4.Status")
        local statusW = math.max(math.floor(78 * scale), surface.GetTextSize(visual.statusText) + math.floor(20 * scale))
        local statusH = math.max(20, math.floor(24 * scale))
        local statusX = rightX - statusW
        local statusY = math.floor(h * 0.38)

        roundedBox(5, statusX, statusY, statusW, statusH, visual.pill)
        draw.SimpleText(
            visual.statusText,
            "KRYPF4.Status",
            statusX + statusW * 0.5,
            statusY + statusH * 0.5,
            visual.statusColor,
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER
        )
    end

    local select = vgui.Create("DButton", card)
    select:SetText("")
    select:SetCursor("hand")

    local buttonW = math.floor(145 * scale)
    local buttonH = math.max(28, math.floor(32 * scale))
    select:SetSize(buttonW, buttonH)

    select.Think = function(self)
        if not IsValid(card) then return end
        self:SetPos(card:GetWide() - buttonW - math.floor(18 * scale), card:GetTall() - buttonH - math.floor(10 * scale))
    end

    select.Paint = function(self, w, h)
        local visual = getVisualState(teamID, self:IsHovered())
        local current = LocalPlayer():Team() == teamID
        local color
        local textColor = color_white

        if visual.denied then
            color = self:IsHovered() and C.buttonDeniedHover or C.buttonDenied
        elseif current then
            color = self:IsHovered() and C.buttonCurrentHover or C.buttonCurrent
            textColor = C.buttonCurrentText
        else
            color = self:IsHovered() and C.buttonNormalHover or C.buttonNormal
        end

        roundedBox(5, 0, 0, w, h, color)

        local label = visual.denied and "Non autorisé" or (current and "Métier actuel" or "Devenir")
        draw.SimpleText(label, "KRYPF4.Button", w * 0.5, h * 0.5, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    select.DoClick = function()
        local state = statusFor(teamID)

        -- Aucun son de clic : l'interface reste volontairement silencieuse.
        if state.protected and not state.hasWhitelist then return end
        if LocalPlayer():Team() == teamID then return end

        net.Start("krypf4_select_job")
            net.WriteUInt(teamID, 16)
        net.SendToServer()

        if CFG.CloseAfterJobRequest and IsValid(frame) then
            frame:Close()
        end
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

    -- Garde une petite marge même sur des résolutions atypiques.
    width = math.min(width, ScrW() - 32)
    height = math.min(height, ScrH() - 32)

    return width, height
end

local function createMenu()
    if IsValid(frame) then
        frame:Close()
        return
    end

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

    -- La première pression qui ouvre le menu ne doit pas le refermer immédiatement.
    frame.KRYPF4F4WasDown = input.IsKeyDown(KEY_F4)

    frame.Think = function(self)
        local isDown = input.IsKeyDown(KEY_F4)

        if isDown and not self.KRYPF4F4WasDown then
            self:Close()
            return
        end

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

    frame.OnClose = function()
        frame = nil
    end

    local function px(value)
        return math.floor(menuW * value)
    end

    local function py(value)
        return math.floor(menuH * value)
    end

    local categoriesPanel = vgui.Create("DScrollPanel", frame)
    categoriesPanel:SetPos(px(CFG.Layout.categoryX), py(CFG.Layout.categoryY))
    categoriesPanel:SetSize(px(CFG.Layout.categoryW), py(CFG.Layout.categoryH))

    local categoriesBar = categoriesPanel:GetVBar()
    categoriesBar:SetWide(3)
    categoriesBar.Paint = function() end
    categoriesBar.btnUp.Paint = function() end
    categoriesBar.btnDown.Paint = function() end
    categoriesBar.btnGrip.Paint = function(self, w, h)
        roundedBox(2, 0, 0, w, h, Color(105, 108, 114, 145))
    end

    local jobsPanel = vgui.Create("DScrollPanel", frame)
    jobsPanel:SetPos(px(CFG.Layout.jobsX), py(CFG.Layout.jobsY))
    jobsPanel:SetSize(px(CFG.Layout.jobsW), py(CFG.Layout.jobsH))

    local jobsBar = jobsPanel:GetVBar()
    jobsBar:SetWide(3)
    jobsBar.Paint = function() end
    jobsBar.btnUp.Paint = function() end
    jobsBar.btnDown.Paint = function() end
    jobsBar.btnGrip.Paint = function(self, w, h)
        roundedBox(2, 0, 0, w, h, Color(105, 108, 114, 145))
    end

    local selectedButton

    local function showCategory(category, button)
        jobsPanel:GetCanvas():Clear()
        selectedButton = button

        for _, job in ipairs(category.members or {}) do
            if jobVisible(job) then
                createJobCard(jobsPanel, job, scale)
            end
        end
    end

    local categories = getCategories()

    for index, category in ipairs(categories) do
        local btn = vgui.Create("DButton")
        categoriesPanel:AddItem(btn)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 6, math.max(5, math.floor(CFG.CategorySpacing * scale)))
        btn:SetTall(math.floor(CFG.CategoryButtonHeight * scale))
        btn:SetText("")
        btn:SetCursor("hand")

        btn.Paint = function(self, w, h)
            local selected = selectedButton == self
            local color = selected and C.categorySelected or (self:IsHovered() and C.categoryHover or C.category)
            local border = selected and C.categorySelectedBorder or C.categoryBorder

            roundedBox(6, 0, 0, w, h, color)
            surface.SetDrawColor(border)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            if selected then
                roundedBox(5, 0, math.floor(h * 0.18), math.max(3, math.floor(3 * scale)), math.floor(h * 0.64), C.categoryAccent)
            end

            local label = category.name or "Catégorie"
            if CFG.ShowCategoryCount then
                label = label .. "  (" .. tostring(#(category.members or {})) .. ")"
            end

            draw.SimpleText(
                truncateText(label, "KRYPF4.Category", w - math.floor(28 * scale)),
                "KRYPF4.Category",
                math.floor(16 * scale),
                h * 0.5,
                selected and C.text or C.categoryText,
                TEXT_ALIGN_LEFT,
                TEXT_ALIGN_CENTER
            )
        end

        btn.DoClick = function()
            -- Aucun son lors du changement de catégorie.
            showCategory(category, btn)
        end

        if index == 1 then
            timer.Simple(0, function()
                if IsValid(frame) and IsValid(btn) then
                    showCategory(category, btn)
                end
            end)
        end
    end

    -- Zone cliquable directement au-dessus de « F4 - Fermer » présent dans le PNG.
    -- On n'ajoute aucun texte supplémentaire pour conserver exactement le design du fond.
    local closeHitbox = vgui.Create("DButton", frame)
    closeHitbox:SetText("")
    closeHitbox:SetCursor("hand")
    closeHitbox:SetPos(px(0.020), py(0.905))
    closeHitbox:SetSize(px(0.125), py(0.065))
    closeHitbox.Paint = function(self, w, h)
        if self:IsHovered() then
            roundedBox(5, 0, 0, w, h, Color(255, 255, 255, 8))
        end
    end
    closeHitbox.DoClick = function()
        if IsValid(frame) then frame:Close() end
    end
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
