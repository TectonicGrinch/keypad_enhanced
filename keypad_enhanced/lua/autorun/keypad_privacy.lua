if SERVER then
    AddCSLuaFile("keypad_privacy/shared.lua")
    AddCSLuaFile("keypad_privacy/client.lua")
    AddCSLuaFile("keypad_privacy/config.lua")
    AddCSLuaFile("keypad_privacy/appearance.lua")
    AddCSLuaFile("keypad_privacy/tool_client.lua")
    AddCSLuaFile("keypad_privacy/images.lua")
    AddCSLuaFile("keypad_privacy/render.lua")
    AddCSLuaFile("keypad_privacy/private_input.lua")
    include("keypad_privacy/server.lua")
end

