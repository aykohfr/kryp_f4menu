KRYPF4 = KRYPF4 or {}
KRYPF4.Config = KRYPF4.Config or {}

local CFG = KRYPF4.Config

-- Image de fond complète du menu. Elle est téléchargée côté client puis mise en cache dans data/.
CFG.BackgroundURL = "https://i.imgur.com/LQc6hHO.png"
CFG.BackgroundDataPath = "kryp_f4menu/background.png"

-- Le fond fourni contient déjà le cadre, le titre, le logo et le séparateur vertical.
-- Ces ratios définissent uniquement les zones interactives par-dessus l'image.
CFG.Layout = {
    categoryX = 0.042,
    categoryY = 0.115,
    categoryW = 0.220,
    categoryH = 0.770,

    jobsX = 0.305,
    jobsY = 0.115,
    jobsW = 0.655,
    jobsH = 0.770,
}

CFG.CategoryButtonHeight = 58
CFG.CategorySpacing = 10
CFG.JobCardHeight = 82
CFG.JobSpacing = 10
CFG.CloseAfterJobRequest = true
CFG.ShowJobSlots = true
CFG.ShowCategoryCount = false

-- Couleurs de l'interface.
CFG.Colors = {
    text = Color(242, 242, 242),
    muted = Color(155, 155, 155),

    category = Color(28, 28, 28, 235),
    categoryHover = Color(39, 39, 39, 245),
    categorySelected = Color(54, 54, 54, 250),
    categoryBorder = Color(75, 75, 75, 180),

    normal = Color(31, 31, 31, 238),
    normalHover = Color(39, 39, 39, 245),
    normalBorder = Color(74, 74, 74, 190),

    whitelistAllowed = Color(21, 78, 44, 228),
    whitelistAllowedHover = Color(27, 96, 53, 238),
    whitelistAllowedBorder = Color(62, 190, 101, 220),

    whitelistDenied = Color(95, 24, 24, 230),
    whitelistDeniedHover = Color(117, 29, 29, 240),
    whitelistDeniedBorder = Color(219, 57, 57, 225),

    buttonNormal = Color(53, 133, 82, 245),
    buttonNormalHover = Color(64, 154, 95, 255),
    buttonDenied = Color(159, 35, 35, 245),
    buttonDeniedHover = Color(183, 44, 44, 255),
}

-- Compatibilité Billy's Whitelist / bWhitelist (GAS.JobWhitelist).
CFG.BWhitelist = {
    enabled = true,

    -- Si l'API de ta version de bWhitelist n'expose pas directement la liste des jobs
    -- protégés, ajoute ici LE "command" DarkRP des jobs concernés.
    -- Exemple : ["mtf"] = true, ["scientifique"] = true
    fallbackProtectedCommands = {
        -- ["mtf"] = true,
    },

    -- Même fallback, mais par TEAM_* numérique si tu préfères.
    fallbackProtectedTeams = {
        -- [TEAM_MTF] = true,
    },
}

-- Masquer des catégories ou des jobs sans modifier darkrpmodification.
CFG.HiddenCategories = {
    -- ["Citizens"] = true,
}

CFG.HiddenJobCommands = {
    -- ["citizen"] = true,
}
