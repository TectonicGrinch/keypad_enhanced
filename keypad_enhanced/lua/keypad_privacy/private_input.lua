local KP=KeypadPrivacy
local active,returnView
local nextID,nextPress=0,0
local masks={[0]='READY'}
for i=1,8 do masks[i]=string.rep('*',i) end
local function unhook()
    hook.Remove('InputMouseApply','KeypadPrivacy.PrivateMouse')
    hook.Remove('CreateMove','KeypadPrivacy.PrivateCommand')
    hook.Remove('CalcView','KeypadPrivacy.PrivateView')
    hook.Remove('Think','KeypadPrivacy.PrivateCheck')
    hook.Remove('EntityRemoved','KeypadPrivacy.PrivateRemoved')
    hook.Remove('PlayerButtonDown','KeypadPrivacy.PrivateEscape')
end
local function returning(pos,angles,fov)
    local record=returnView local player=LocalPlayer()
    if not record or not IsValid(player) or not player:Alive() or RealTime()-record.time>=.12 then
        hook.Remove('CalcView','KeypadPrivacy.PrivateReturn') returnView=nil return
    end
    local t=math.Clamp((RealTime()-record.time)/.12,0,1)
    local k=1-t*t*(3-2*t)
    return {origin=pos,angles=angles+record.offset*k,fov=fov}
end
local function stop(reason,notify)
    KP.PrivateLastStop=reason
    local old=active active=nil
    unhook()
    if old and notify~=false and IsValid(LocalPlayer()) then
        net.Start('KeypadPrivacy.FocusEnd') net.WriteUInt(old.id,32) net.SendToServer()
    end
    hook.Remove('CalcView','KeypadPrivacy.PrivateReturn') returnView=nil
    local ply=LocalPlayer()
    if old and IsValid(ply) and ply:Alive() and not gui.IsGameUIVisible() then
        if reason=='looked away' or reason=='submitted' then
            -- Release on leaving the surface or pressing OK, never on a digit.
            -- Both successful and failed attempts continue from the OK direction.
            ply:SetEyeAngles(Angle(old.view.p,old.view.y,0))
            return false
        end
        returnView={time=RealTime(),offset=Angle(math.AngleDifference(old.view.p,old.public.p),math.AngleDifference(old.view.y,old.public.y),0)}
        hook.Add('CalcView','KeypadPrivacy.PrivateReturn',function(_,pos,angles,fov) return returning(pos,angles,fov) end)
    end
    return false
end
local function valid()
    local s=active
    if not s then return false end
    local p=LocalPlayer()
    if not IsValid(p) or not p:Alive() or p:InVehicle() or p:GetViewEntity()~=p or not system.HasFocus() or gui.IsGameUIVisible() or vgui.CursorVisible() then return stop('inactive') end
    if not KP.IsKeypad(s.ent) or p:GetActiveWeapon()~=s.weapon or p:EyePos():DistToSqr(s.ent:GetPos())>120*120 or RealTime()>s.deadline then return stop('ended') end
    if s.ent:GetStatus()~=s.ent.Status_None then return stop('busy') end
    local eye=p:EyePos()
    -- Once per frame unless the private mouse ray changed during that frame.
    if s.frame~=FrameNumber() then
        s.frame=FrameNumber()
        local button,inside=KP.ButtonForRay(eye,s.view:Forward(),s.ent)
        if not inside then return stop('looked away') end
        local trace=util.TraceLine({start=eye,endpos=eye+s.public:Forward()*65,filter=p})
        if trace.Entity~=s.ent then return stop('blocked') end
        s.button=button
    end
    return true
end
function KP.CancelPrivateInput() return stop('cancel') end
function KP.PrivateIsActive() return active~=nil end
function KP.PrivateFocusEntity() return active and active.ent or NULL end
function KP.LocalEntry(ent) return active and active.ent==ent and active.text or '' end
function KP.EntryDisplay(ent)
    if active and active.ent==ent and active.text=='' then return active.pending and 'WAIT' or 'PIN' end
    return masks[#KP.LocalEntry(ent)]
end
function KP.PrivateHover(ent)
    if active and active.ent==ent and valid() then return active.button end
end
function KP.StartPrivateInput(ent)
    local ply=LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or not KP.IsKeypad(ent) or ent:GetStatus()~=ent.Status_None then return false end
    local trace=ply:GetEyeTrace()
    if trace.Entity~=ent or ply:EyePos():DistToSqr(trace.HitPos)>65*65 or (ply:EyePos()-ent:GetPos()):Dot(ent:GetForward())<=0 then return false end
    local facing=ply:EyeAngles()
    if returnView then
        local rendered=returning(ply:EyePos(),facing,90)
        if rendered then facing=rendered.angles end
    end
    if active then stop('replace') end
    hook.Remove('CalcView','KeypadPrivacy.PrivateReturn') returnView=nil
    nextID=(nextID+1)%4294967296
    -- Preserve the entry view; only subsequent selection movement stays local.
    facing.p=math.NormalizeAngle(facing.p) facing.y=math.NormalizeAngle(facing.y) facing.r=0
    active={ent=ent,id=nextID,public=facing,view=Angle(facing.p,facing.y,0),weapon=ply:GetActiveWeapon(),text='',pending=true,deadline=RealTime()+2}
    hook.Add('InputMouseApply','KeypadPrivacy.PrivateMouse',function(cmd,x,y)
        if not valid() then return end
        local s=active
        local yaw=GetConVar('m_yaw') local pitch=GetConVar('m_pitch')
        s.view.y=math.NormalizeAngle(s.view.y-x*(yaw and yaw:GetFloat() or .022))
        s.view.p=math.Clamp(math.NormalizeAngle(s.view.p+y*(pitch and pitch:GetFloat() or .022)),-89,89)
        s.frame=nil
        cmd:SetMouseX(0) cmd:SetMouseY(0) cmd:SetViewAngles(s.public)
        if not valid() and KP.PrivateLastStop=='looked away' then
            -- Do not overwrite the release angle with the old locked command.
            cmd:SetViewAngles(Angle(s.view.p,s.view.y,0))
        end
        return true
    end)
    hook.Add('CreateMove','KeypadPrivacy.PrivateCommand',function(cmd)
        if not valid() then return end
        if cmd:GetForwardMove()~=0 or cmd:GetSideMove()~=0 or cmd:GetUpMove()~=0 or cmd:KeyDown(IN_JUMP) or cmd:KeyDown(IN_DUCK) or cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2) then stop('action') return end
        cmd:SetViewAngles(active.public) cmd:SetMouseX(0) cmd:SetMouseY(0)
        cmd:RemoveKey(IN_USE)
    end)
    hook.Add('CalcView','KeypadPrivacy.PrivateView',function(_,pos,angles,fov)
        local s=active
        if valid() then return {origin=pos,angles=Angle(active.view.p,active.view.y,0),fov=fov} end
        if s and KP.PrivateLastStop=='looked away' then return {origin=pos,angles=Angle(s.view.p,s.view.y,0),fov=fov} end
        return returning(pos,angles,fov)
    end)
    hook.Add('Think','KeypadPrivacy.PrivateCheck',valid)
    hook.Add('EntityRemoved','KeypadPrivacy.PrivateRemoved',function(ent) if active and active.ent==ent then stop('removed') end end)
    hook.Add('PlayerButtonDown','KeypadPrivacy.PrivateEscape',function(player,key)
        if player==LocalPlayer() and key==KEY_ESCAPE then stop('escape') end
    end)
    net.Start('KeypadPrivacy.FocusBegin') net.WriteEntity(ent) net.WriteUInt(nextID,32) net.SendToServer()
    return true
end
net.Receive('KeypadPrivacy.FocusReply',function()
    local ent,id,accepted=net.ReadEntity(),net.ReadUInt(32),net.ReadBool()
    if not active or active.id~=id then return end
    if not accepted or active.ent~=ent then stop('rejected',false) return end
    active.pending=false active.deadline=RealTime()+29
end)
function KP.UseLookButton(ent)
    if not active then return KP.StartPrivateInput(ent) end
    if active.ent~=ent or not valid() then return false end
    local s=active
    if s.pending or RealTime()<nextPress then return true end
    local button=s.button
    if not button then return true end
    nextPress=RealTime()+.12
    if button.kind=='digit' then
        if #s.text>=8 then surface.PlaySound('buttons/button10.wav') return true end
        s.text=s.text..button.digit
    elseif button.kind=='clear' then s.text=''
    elseif button.kind=='submit' then
        if not KP.ValidPIN(s.text) then surface.PlaySound('buttons/button10.wav') return true end
        net.Start('KeypadPrivacy.PrivateSubmit') net.WriteEntity(ent) net.WriteUInt(s.id,32) net.WriteString(s.text) net.SendToServer()
        stop('submitted',false)
    end
    surface.PlaySound('buttons/button15.wav') return true
end
KP.Open=KP.UseLookButton
hook.Add('PlayerBindPress','Keypad',function(player,bind,pressed)
    if not pressed then return end
    if bind:find('+use',1,true) then
        local ent=active and active.ent or player:GetEyeTrace().Entity
        if KP.IsKeypad(ent) and KP.UseLookButton(ent) then return true end
    elseif active and (bind=='+attack' or bind=='+attack2') then stop('action') return true
    elseif active and (bind:find('slot',1,true)==1 or bind=='invnext' or bind=='invprev' or bind=='lastinv' or bind=='+menu' or bind=='+menu_context') then stop('action') end
end)
