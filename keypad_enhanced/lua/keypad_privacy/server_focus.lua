local KP=KeypadPrivacy
local focus=setmetatable({},{__mode='k'})
local traffic=setmetatable({},{__mode='k'})
util.AddNetworkString('KeypadPrivacy.FocusBegin')
util.AddNetworkString('KeypadPrivacy.FocusEnd')
util.AddNetworkString('KeypadPrivacy.FocusReply')
function KP.CanFocus(ply,ent)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or ply:InVehicle() or not KP.IsKeypad(ent) then return false end
    local eye=ply:EyePos()
    if eye:DistToSqr(ent:GetPos())>120*120 or (eye-ent:GetPos()):Dot(ent:GetForward())<=0 then return false end
    local trace=ply:GetEyeTrace()
    return trace.Entity==ent and eye:DistToSqr(trace.HitPos)<=65*65
end
net.Receive('KeypadPrivacy.FocusBegin',function(bits,ply)
    if bits~=45 or not IsValid(ply) then return end -- 13-bit entity + 32-bit session ID.
    local now=CurTime()
    if (traffic[ply] or 0)>now then return end
    traffic[ply]=now+.25
    local ent,id=net.ReadEntity(),net.ReadUInt(32)
    local accepted=KP.CanFocus(ply,ent) and ent:GetStatus()==ent.Status_None
    focus[ply]=accepted and {ent=ent,id=id,expires=now+30} or nil
    net.Start('KeypadPrivacy.FocusReply') net.WriteEntity(accepted and ent or NULL) net.WriteUInt(id,32) net.WriteBool(accepted) net.Send(ply)
end)
net.Receive('KeypadPrivacy.FocusEnd',function(bits,ply)
    if bits~=32 then return end
    local record=focus[ply]
    if record and record.id==net.ReadUInt(32) then focus[ply]=nil end
end)
function KP.ValidFocus(ply,ent,id)
    local record=focus[ply]
    if not record or record.ent~=ent or record.id~=id then return false end
    if record.expires<CurTime() or not KP.CanFocus(ply,ent) then focus[ply]=nil return false end
    return true
end
function KP.FinishFocus(ply,id)
    if focus[ply] and focus[ply].id==id then focus[ply]=nil end
end
hook.Add('PlayerDeath','KeypadPrivacy.FocusDeath',function(ply) focus[ply]=nil end)
hook.Add('PlayerDisconnected','KeypadPrivacy.FocusDisconnect',function(ply) focus[ply],traffic[ply]=nil,nil end)
