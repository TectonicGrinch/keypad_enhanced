include 'sh_init.lua'
include 'cl_maths.lua'
include 'cl_panel.lua'
local mat=CreateMaterial('KeypadPrivacy.Casing','VertexLitGeneric',{['$basetexture']='color/white'})
local tint=Color(36,36,36)
function ENT:Draw()
    local c=self:GetCasingColour()
    tint.r,tint.g,tint.b=c.x*255,c.y*255,c.z*255
    render.SetMaterial(mat)
    render.DrawBox(self:GetPos(),self:GetAngles(),self.Mins,self.Maxs,tint,true)
    local pos,ang=self:CalculateRenderPos(),self:CalculateRenderAng()
    cam.Start3D2D(pos,ang,self.Scale) self:Paint(self.Width2D,self.Height2D) cam.End3D2D()
end
function ENT:OpenPrivateEntry() return KeypadPrivacy.Open(self) end
