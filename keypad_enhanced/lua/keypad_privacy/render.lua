local KP=include('keypad_privacy/shared.lua')
if KP.InstallClientPanel then return KP.InstallClientPanel end
local fonts={}
for id,font in pairs(KP.Fonts) do
    fonts[id]={}
    for kind,size in pairs({Digit=70,Action=38,Display=78}) do
        local name='KeypadPrivacy.'..id..'.'..kind
        surface.CreateFont(name,{font=font.family,size=size,weight=700}) fonts[id][kind]=name
    end
end
local displayColour=Color(208,227,191)
local grantedColour,deniedColour=Color(100,230,150),Color(240,110,110)
local keyColour,clearColour,okColour=Color(88,88,91),Color(103,45,42),Color(43,94,55)
local textColour=Color(239,235,225)
local function hoveredElement(self) return KP.PrivateHover(self) end
local function paint(self,w,h)
    local colour=self:GetCasingColour()
    surface.SetDrawColor(colour.x*255,colour.y*255,colour.z*255) surface.DrawRect(0,0,w,h)
    local image=KP.CasingImage(self:GetCasingImage())
    if image then surface.SetMaterial(image) surface.SetDrawColor(255,255,255) surface.DrawTexturedRect(0,0,w,h) end
    if KP.PrivateFocusEntity()==self then surface.SetDrawColor(215,192,137) surface.DrawOutlinedRect(0,0,w,h,4) end
    surface.SetDrawColor(57,69,58) surface.DrawRect(w*.075,h*.04,w*.85,h*.22)
    local status=self:GetStatus()
    local text,color=KP.EntryDisplay(self),displayColour
    if status==self.Status_Granted then text,color='GRANTED',grantedColour
    elseif status==self.Status_Denied then text,color='DENIED',deniedColour end
    local f=fonts[self:GetKeypadFont()] or fonts.default
    draw.SimpleText(text,f.Display,w*.5,h*.15,color,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    local hovered=self:GetHoveredElement()
    for _,button in ipairs(KP.Buttons) do
        local x,y,bw,bh=w*button.x,h*button.y,w*button.w,h*button.h
        local base=button.kind=='submit' and okColour or button.kind=='clear' and clearColour or keyColour
        surface.SetDrawColor(base) surface.DrawRect(x,y,bw,bh)
        if button==hovered then surface.SetDrawColor(215,192,137) surface.DrawOutlinedRect(x,y,bw,bh,5) end
        draw.SimpleText(button.label,button.kind=='digit' and f.Digit or f.Action,x+bw/2,y+bh/2,textColour,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
    end
end

function KP.InstallClientPanel(ENT)
    ENT.GetHoveredElement=hoveredElement
    ENT.Paint=paint
end
return KP.InstallClientPanel
