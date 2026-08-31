# Kryp F4 Menu

Menu F4 DarkRP basé sur l'image :
`https://i.imgur.com/LQc6hHO.png`

## Fonctionnement

- Remplace l'ouverture F4 standard via `ShowSpare2`.
- Télécharge l'image Imgur côté client et la met en cache dans `data/kryp_f4menu/background.png`.
- Lit automatiquement les catégories et jobs chargés par DarkRP / `darkrpmodification` via `DarkRP.getCategories().jobs` et `RPExtraTeams`.
- Les jobs publics sont gris.
- Les jobs bWhitelist détectés sont verts si le joueur possède la whitelist et rouges sinon.
- Le changement de job passe par le serveur puis par les callbacks de commandes DarkRP ; les hooks DarkRP/bWhitelist restent donc actifs.
- Les jobs à vote utilisent automatiquement `vote<command>` quand `vote`/`RequiresVote` l'exige.

## Installation

Copier le dossier `kryp_f4menu` dans :

`garrysmod/addons/kryp_f4menu/`

Puis redémarrer complètement le serveur.

Dépendances attendues :

- DarkRP
- darkrpmodification pour tes jobs/catégories
- GmodAdminSuite + Billy's Whitelist si tu veux les états whitelist

## bWhitelist

L'API publique vérifiable de Billy's Whitelist expose notamment :

`GAS.JobWhitelist:IsWhitelisted(player, teamID)`

Les versions de bWhitelist peuvent différer sur la façon d'exposer le fait qu'un TEAM est configuré comme "whitelist". L'addon tente plusieurs méthodes/tables courantes sans toucher aux fichiers de bWhitelist.

Si, sur ta version, les joueurs non whitelistés voient malgré tout un job whitelisté en gris, ajoute simplement le `command` DarkRP de ce job dans :

`lua/kryp_f4menu/sh_config.lua`

Exemple :

```lua
CFG.BWhitelist.fallbackProtectedCommands = {
    ["mtf"] = true,
    ["scientifique"] = true,
}
```

Cela ne remplace pas bWhitelist : bWhitelist continue de décider qui possède réellement l'accès grâce à `IsWhitelisted`.

## Réglage de la position

L'image de fond contient déjà le séparateur. Les zones sont définies dans :

```lua
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
```

Ces valeurs sont des ratios de l'écran, donc le menu reste aligné en 16:9 et s'adapte aux résolutions courantes.

## Commande de test

Dans la console client :

`kryp_f4`
