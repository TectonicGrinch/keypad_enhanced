KeypadPrivacy = KeypadPrivacy or {}
local KP = KeypadPrivacy
if KP.SharedLoaded then
    return KP
end
KP.SharedLoaded = true

function KP.ValidPIN(value)
    return (((type(value) == "string") and ((#value) >= 1)) and ((#value) <= 8)) and
        (value:match("^%d+$") ~= nil)
end

function KP.Number(value, fallback, minimum, maximum, whole)
    if (type(value) ~= "number") and (type(value) ~= "string") then
        return fallback
    end
    local number = tonumber(value)
    if (((not number) or (number ~= number)) or (number == math.huge)) or (number == (-math.huge)) then
        return fallback
    end
    number = math.Clamp(number, minimum, maximum)
    return (whole and math.floor(number)) or number
end

function KP.Normalize(data)
    if type(data) ~= "table" then
        return nil
    end
    local password = data.Password
    if type(password) == "number" then
        password = tostring(password)
    end
    if not KP.ValidPIN(password) then
        return nil
    end
    local result = {Password = password, Secure = true}
    for _, suffix in ipairs({"Granted", "Denied"}) do
        result["Repeats" .. suffix] = KP.Number(data["Repeats" .. suffix], 0, 0, 5, true)
        result["Length" .. suffix] = KP.Number(data["Length" .. suffix], 0.1, 0.1, 10)
        result["Delay" .. suffix] = KP.Number(data["Delay" .. suffix], 0, 0, 10)
        result["InitDelay" .. suffix] = KP.Number(data["InitDelay" .. suffix], 0, 0, 10)
        result["Key" .. suffix] =
            KP.Number(data["Key" .. suffix], 0, 0, BUTTON_CODE_LAST or 159, true)
    end
    result.OutputOn = KP.Number(data.OutputOn, 1, -1000, 1000)
    result.OutputOff = KP.Number(data.OutputOff, 0, -1000, 1000)
    return result
end

function KP.IsKeypad(ent)
    if not IsValid(ent) then
        return false
    end
    local class = ent:GetClass()
    return (class == "keypad") or (class == "keypad_wire")
end
-- One fixed physical layout is shared by rendering and server aim validation.
KP.Buttons={}
for digit=1,9 do
    KP.Buttons[#KP.Buttons+1]={kind='digit',digit=tostring(digit),label=tostring(digit),x=.075+.3*((digit-1)%3),y=.30+.165*math.floor((digit-1)/3),w=.25,h=.14}
end
KP.Buttons[#KP.Buttons+1]={kind='clear',label='CLEAR',x=.075,y=.795,w=.25,h=.14}
KP.Buttons[#KP.Buttons+1]={kind='digit',digit='0',label='0',x=.375,y=.795,w=.25,h=.14}
KP.Buttons[#KP.Buttons+1]={kind='submit',label='OK',x=.675,y=.795,w=.25,h=.14}
function KP.RenderGeometry(ent)
    local mins,maxs=ent:OBBMins(),ent:OBBMaxs()
    local pos=ent:GetPos()+ent:GetForward()*(maxs.x+.15)+ent:GetRight()*maxs.y+ent:GetUp()*maxs.z
    local ang=ent:GetAngles() ang:RotateAroundAxis(ang:Right(),-90) ang:RotateAroundAxis(ang:Up(),90)
    local scale=ent.Scale or .02
    return pos,ang,(maxs.y-mins.y)/scale,(maxs.z-mins.z)/scale,scale
end
function KP.LookButton(player,ent)
    if not IsValid(player) or not KP.IsKeypad(ent) then return end
    local trace=player:GetEyeTrace()
    if trace.Entity~=ent then return end
    local eye=player:EyePos()
    if eye:DistToSqr(trace.HitPos)>65*65 or (eye-ent:GetPos()):Dot(ent:GetForward())<=0 then return end
    local pos,ang,w,h,scale=KP.RenderGeometry(ent)
    local hit=util.IntersectRayWithPlane(eye,player:GetAimVector(),pos,ent:GetForward())
    if not hit then return end
    local diff=pos-hit
    local x,y=diff:Dot(-ang:Forward())/scale,diff:Dot(-ang:Right())/scale
    for _,button in ipairs(KP.Buttons) do
        if x>=w*button.x and x<=w*(button.x+button.w) and y>=h*button.y and y<=h*(button.y+button.h) then return button end
    end
end
-- Private-view selection uses a local ray, never the public player aim.
function KP.ButtonForRay(eye,direction,ent)
    if not KP.IsKeypad(ent) or (eye-ent:GetPos()):Dot(ent:GetForward())<=0 then return nil,false end
    local trace=util.TraceLine({start=eye,endpos=eye+direction*65,filter=LocalPlayer()})
    if trace.Entity~=ent then return nil,false end
    local pos,ang,w,h,scale=KP.RenderGeometry(ent)
    local hit=util.IntersectRayWithPlane(eye,direction,pos,ent:GetForward())
    if not hit then return nil,false end
    local diff=pos-hit
    local x,y=diff:Dot(-ang:Forward())/scale,diff:Dot(-ang:Right())/scale
    if x<0 or x>w or y<0 or y>h then return nil,false end
    for _,button in ipairs(KP.Buttons) do
        if x>=w*button.x and x<=w*(button.x+button.w) and y>=h*button.y and y<=h*(button.y+button.h) then return button,true end
    end
    return nil,true
end
include('keypad_privacy/appearance.lua')
return KP

