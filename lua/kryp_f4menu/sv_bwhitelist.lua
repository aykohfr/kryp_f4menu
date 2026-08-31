KRYPF4 = KRYPF4 or {}
KRYPF4.BWhitelist = KRYPF4.BWhitelist or {}

local BW = KRYPF4.BWhitelist
local CFG = KRYPF4.Config.BWhitelist or {}

local protectedMethodNames = {
    "IsJobWhitelisted",
    "IsJobWhitelist",
    "IsWhitelistEnabled",
    "JobRequiresWhitelist",
    "IsJobRestricted",
    "IsJobProtected",
}

local candidateDataTables = {
    "WhitelistedJobs",
    "WhitelistJobs",
    "JobData",
    "Jobs",
    "jobData",
    "jobs",
    "whitelisted_jobs",
}

local function safeBooleanMethod(object, name, ...)
    local fn = object and object[name]
    if not isfunction(fn) then return nil, false end

    local ok, result = pcall(fn, object, ...)
    if not ok or not isbool(result) then return nil, false end

    return result, true
end

local function lowerString(value)
    return isstring(value) and string.lower(value) or nil
end

local function parseProtectionEntry(entry)
    if isbool(entry) then return entry, true end
    if not istable(entry) then return nil, false end

    local booleanKeys = {
        "whitelist", "whitelisted", "isWhitelist", "is_whitelist",
        "whitelistEnabled", "whitelist_enabled",
    }

    for _, key in ipairs(booleanKeys) do
        if isbool(entry[key]) then
            return entry[key], true
        end
    end

    local stringKeys = {"mode", "type", "access", "accessType", "listType"}
    for _, key in ipairs(stringKeys) do
        local value = lowerString(entry[key])
        if value then
            if string.find(value, "whitelist", 1, true) then return true, true end
            if value == "public" or value == "none" or value == "disabled" then return false, true end
        end
    end

    return nil, false
end

local function inspectKnownTables(jobWhitelist, teamID)
    for _, tableName in ipairs(candidateDataTables) do
        local data = jobWhitelist[tableName]
        if not istable(data) then continue end

        local entry = data[teamID] or data[tostring(teamID)]
        if entry ~= nil then
            local value, known = parseProtectionEntry(entry)
            if known then return value, true end

            -- Une entrée explicite pour ce TEAM dans une table dédiée aux jobs WL est
            -- déjà un indice suffisamment fort pour considérer le job comme protégé.
            if tableName == "WhitelistedJobs" or tableName == "WhitelistJobs" or tableName == "whitelisted_jobs" then
                return true, true
            end
        end
    end

    return nil, false
end

function BW.IsAvailable()
    return CFG.enabled ~= false
        and istable(GAS)
        and istable(GAS.JobWhitelist)
        and isfunction(GAS.JobWhitelist.IsWhitelisted)
end

function BW.PlayerHasWhitelist(ply, teamID)
    if not BW.IsAvailable() then return false, false end

    local ok, result = pcall(GAS.JobWhitelist.IsWhitelisted, GAS.JobWhitelist, ply, teamID)
    if not ok or not isbool(result) then return false, false end

    return result, true
end

function BW.IsJobProtected(teamID, job, ply)
    if CFG.enabled == false then return false, true end

    -- Fallback explicite : fiable et indépendant des changements internes de bWhitelist.
    if CFG.fallbackProtectedTeams and CFG.fallbackProtectedTeams[teamID] == true then
        return true, true
    end

    if job and job.command and CFG.fallbackProtectedCommands and CFG.fallbackProtectedCommands[job.command] == true then
        return true, true
    end

    if not istable(GAS) or not istable(GAS.JobWhitelist) then
        return false, true
    end

    local jobWhitelist = GAS.JobWhitelist

    -- Certaines versions/forks exposent directement un booléen par TEAM.
    -- On teste les deux signatures usuelles avant de conclure, afin qu'un appel
    -- avec de mauvais arguments ne transforme pas un job WL en faux négatif.
    for _, methodName in ipairs(protectedMethodNames) do
        local valueTeam, knownTeam = safeBooleanMethod(jobWhitelist, methodName, teamID)
        local valuePlayer, knownPlayer = nil, false

        if IsValid(ply) then
            valuePlayer, knownPlayer = safeBooleanMethod(jobWhitelist, methodName, ply, teamID)
        end

        if (knownTeam and valueTeam == true) or (knownPlayer and valuePlayer == true) then
            return true, true
        end

        if knownTeam and (not IsValid(ply) or knownPlayer) and valueTeam == false and (not knownPlayer or valuePlayer == false) then
            return false, true
        end
    end

    local value, known = inspectKnownTables(jobWhitelist, teamID)
    if known then return value, true end

    -- GetJobData existe dans plusieurs versions de bWhitelist. On l'utilise uniquement
    -- s'il renvoie synchroniquement une table exploitable ; aucun comportement interne
    -- n'est modifié si la version utilise un callback/réseau.
    if isfunction(jobWhitelist.GetJobData) then
        local ok, result = pcall(jobWhitelist.GetJobData, jobWhitelist, teamID)
        if ok and result ~= nil then
            value, known = parseProtectionEntry(result)
            if known then return value, true end
        end
    end

    -- Dernier indice : si le joueur apparaît dans la whitelist du TEAM, le TEAM est
    -- considéré comme protégé pour l'affichage. En revanche l'absence d'entrée ne suffit
    -- pas à conclure que le job est protégé : on laisse donc le statut "inconnu/gris".
    if IsValid(ply) then
        local hasWhitelist, hasKnown = BW.PlayerHasWhitelist(ply, teamID)
        if hasKnown and hasWhitelist then
            return true, true
        end
    end

    return false, false
end

function BW.GetStatus(ply, teamID, job)
    local protected, protectionKnown = BW.IsJobProtected(teamID, job, ply)
    local hasWhitelist, whitelistKnown = BW.PlayerHasWhitelist(ply, teamID)

    if protected and not whitelistKnown then
        hasWhitelist = false
    end

    return {
        protected = protected == true,
        hasWhitelist = hasWhitelist == true,
        protectionKnown = protectionKnown == true,
        whitelistKnown = whitelistKnown == true,
        available = BW.IsAvailable(),
    }
end
