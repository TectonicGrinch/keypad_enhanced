AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_maths.lua")
AddCSLuaFile("cl_panel.lua")
AddCSLuaFile("sh_init.lua")
include("sh_init.lua")
local KP = include("keypad_privacy/server.lua")
KP.InstallEntity(ENT, false)

