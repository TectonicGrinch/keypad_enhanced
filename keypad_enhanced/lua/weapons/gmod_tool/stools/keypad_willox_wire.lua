-- Hidden compatibility tool. New and old commands use the combined keypad.
include('weapons/gmod_tool/stools/keypad_willox.lua')
TOOL.AddToMenu=false
function TOOL:GetClientNumber(key,default)
    return self:GetOwner():GetInfoNum('keypad_willox_'..key,default or 0)
end
