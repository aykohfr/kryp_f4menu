KRYPF4 = KRYPF4 or {}

if SERVER then
    AddCSLuaFile("kryp_f4menu/sh_config.lua")
    AddCSLuaFile("kryp_f4menu/cl_main.lua")

    include("kryp_f4menu/sh_config.lua")
    include("kryp_f4menu/sv_bwhitelist.lua")
    include("kryp_f4menu/sv_main.lua")
else
    include("kryp_f4menu/sh_config.lua")
    include("kryp_f4menu/cl_main.lua")
end
