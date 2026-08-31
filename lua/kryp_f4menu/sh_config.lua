KRYPF4 = KRYPF4 or {}
KRYPF4.Config = KRYPF4.Config or {}

local CFG = KRYPF4.Config

-- Image de fond complète du menu. Elle est téléchargée côté client puis mise en cache dans data/.
CFG.BackgroundURL = "https://i.imgur.com/LQc6hHO.png"
CFG.BackgroundDataPath = "kryp_f4menu/background.png"

-- Le menu n'occupe volontairement pas tout l'écran.
-- L'image de fond est conservée dans son ratio original afin d'éviter toute déformation.
CFG.MenuWidthFraction = 0.86
CFG.MenuHeightFraction = 0.82
CFG.MenuAspectRatio = 1648 / 928

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

CFG.CategoryButtonHeight = 54
CFG.CategorySpacing = 9
CFG.JobCardHeight = 88
CFG.JobSpacing = 9
CFG.CloseAfterJobRequest = true
CFG.ShowJobSlots = true
CFG.ShowCategoryCount = false

-- Couleurs de l'interface.
-- Gris = public, vert = whitelist possédée, rouge = whitelist manquante.
CFG.Colors = {
    text = Color(242, 242, 242),
    muted = Color(155, 158, 163),
    slotText = Color(202, 205, 211),

    category = Color(23, 24, 26, 235),
    categoryHover = Color(31, 32, 35, 245),
    categorySelected = Color(40, 42, 46, 250),
    categoryBorder = Color(72, 74, 80, 150),
    categorySelectedBorder = Color(110, 114, 123, 195),
    categoryAccent = Color(218, 220, 225, 235),
    categoryText = Color(205, 207, 212),

    normal = Color(29, 30, 33, 242),
    normalHover = Color(36, 38, 42, 248),
    normalBorder = Color(78, 81, 87, 175),
    normalAccent = Color(111, 115, 123, 230),
    normalPill = Color(52, 54, 59, 235),
    normalStatusText = Color(207, 210, 216),

    whitelistAllowed = Color(21, 57, 37, 242),
    whitelistAllowedHover = Color(25, 69, 44, 248),
    whitelistAllowedBorder = Color(52, 145, 86, 205),
    whitelistAllowedAccent = Color(67, 194, 111, 245),
    whitelistAllowedPill = Color(34, 105, 63, 235),
    whitelistAllowedText = Color(181, 246, 204),

    whitelistDenied = Color(66, 25, 28, 242),
    whitelistDeniedHover = Color(79, 29, 33, 248),
    whitelistDeniedBorder = Color(169, 53, 59, 210),
    whitelistDeniedAccent = Color(224, 72, 79, 245),
    whitelistDeniedPill = Color(124, 37, 43, 235),
    whitelistDeniedText = Color(255, 190, 194),

    buttonNormal = Color(52, 139, 87, 245),
    buttonNormalHover = Color(61, 159, 100, 255),
    buttonDenied = Color(145, 47, 52, 245),
    buttonDeniedHover = Color(165, 54, 60, 255),
    buttonCurrent = Color(65, 67, 72, 245),
    buttonCurrentHover = Color(74, 77, 82, 255),
    buttonCurrentText = Color(196, 198, 203),
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
