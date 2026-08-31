KRYPF4 = KRYPF4 or {}

util.AddNetworkString("krypf4_request_states")
util.AddNetworkString("krypf4_send_states")
util.AddNetworkString("krypf4_select_job")

local nextStateRequest = setmetatable({}, {__mode = "k"})
local nextJobRequest = setmetatable({}, {__mode = "k"})

local function notify(ply, message)
    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, 1, 4, message)
    else
        ply:ChatPrint(message)
    end
end

local function validJob(teamID)
    return isnumber(teamID) and istable(RPExtraTeams) and istable(RPExtraTeams[teamID])
end

local function sendStates(ply)
    if not IsValid(ply) then return end
    if not istable(RPExtraTeams) then return end

    local states = {}

    for teamID, job in pairs(RPExtraTeams) do
        if not isnumber(teamID) or not istable(job) then continue end

        local status = KRYPF4.BWhitelist.GetStatus(ply, teamID, job)
        states[#states + 1] = {
            teamID = teamID,
            protected = status.protected,
            hasWhitelist = status.hasWhitelist,
            protectionKnown = status.protectionKnown,
            whitelistAvailable = status.available,
        }
    end

    net.Start("krypf4_send_states")
        net.WriteUInt(#states, 16)
        for _, state in ipairs(states) do
            net.WriteUInt(state.teamID, 16)
            net.WriteBool(state.protected)
            net.WriteBool(state.hasWhitelist)
            net.WriteBool(state.protectionKnown)
            net.WriteBool(state.whitelistAvailable)
        end
    net.Send(ply)
end

net.Receive("krypf4_request_states", function(_, ply)
    local now = CurTime()
    if (nextStateRequest[ply] or 0) > now then return end
    nextStateRequest[ply] = now + 0.35

    sendStates(ply)
end)

local function shouldUseVote(job, ply, teamID)
    local useVote = job.vote == true

    if isfunction(job.RequiresVote) then
        local ok, result = pcall(job.RequiresVote, ply, teamID)
        if ok and isbool(result) then
            useVote = result
        end
    end

    return useVote
end

local function executeDarkRPJobCommand(ply, teamID, job)
    if not DarkRP or not DarkRP.getChatCommand then
        notify(ply, "DarkRP n'est pas prêt.")
        return
    end

    local command = tostring(job.command or "")
    if command == "" then
        notify(ply, "Ce job n'a pas de commande DarkRP valide.")
        return
    end

    local commandName = shouldUseVote(job, ply, teamID) and ("vote" .. command) or command
    local commandData = DarkRP.getChatCommand(commandName)

    if not commandData or not isfunction(commandData.callback) then
        notify(ply, "Commande DarkRP introuvable : /" .. commandName)
        return
    end

    -- Reproduit le délai de la commande console DarkRP afin d'éviter le spam réseau.
    ply.DrpCommandDelays = ply.DrpCommandDelays or {}
    local delay = tonumber(commandData.delay) or 0
    local last = ply.DrpCommandDelays[commandName] or 0

    if delay > 0 and last > CurTime() - delay then return end
    ply.DrpCommandDelays[commandName] = CurTime()

    commandData.callback(ply, "")
end

net.Receive("krypf4_select_job", function(_, ply)
    local now = CurTime()
    if (nextJobRequest[ply] or 0) > now then return end
    nextJobRequest[ply] = now + 0.25

    local teamID = net.ReadUInt(16)
    if not validJob(teamID) then return end

    if ply:Team() == teamID then
        notify(ply, "Tu occupes déjà ce métier.")
        return
    end

    local job = RPExtraTeams[teamID]
    local status = KRYPF4.BWhitelist.GetStatus(ply, teamID, job)

    -- Si le job est identifié comme protégé, on refuse explicitement avant même de
    -- lancer la commande DarkRP. Ensuite DarkRP + bWhitelist restent également la
    -- dernière couche de validation via playerCanChangeTeam.
    if status.protected and not status.hasWhitelist then
        notify(ply, "Tu n'as pas la whitelist requise pour ce métier.")
        sendStates(ply)
        return
    end

    executeDarkRPJobCommand(ply, teamID, job)

    timer.Simple(0.35, function()
        if IsValid(ply) then sendStates(ply) end
    end)
end)

hook.Add("PlayerDisconnected", "KRYPF4_CleanupRateLimits", function(ply)
    nextStateRequest[ply] = nil
    nextJobRequest[ply] = nil
end)
