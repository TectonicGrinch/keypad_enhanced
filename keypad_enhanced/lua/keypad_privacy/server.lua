local KP = include("keypad_privacy/shared.lua")
if KP.ServerLoaded then
    return KP
end
KP.ServerLoaded = true
util.AddNetworkString("KeypadPrivacy.PrivateSubmit")
include('keypad_privacy/server_focus.lua')
util.AddNetworkString("KeypadPrivacy.Result")
util.AddNetworkString("KeypadPrivacy.SetupPIN")
util.AddNetworkString('KeypadPrivacy.SetupStyle')

local setup = setmetatable({}, {__mode = "k"})
local attempts = setmetatable({}, {__mode = "k"})
local traffic = setmetatable({}, {__mode = "k"})
local runtime = setmetatable({}, {__mode = "k"})
local nextTimer = 0
local function reply(player, text)
    net.Start("KeypadPrivacy.Result")
    net.WriteString(text)
    net.Send(player)
end
local function allowTraffic(player, kind, interval)
    local record = traffic[player] or {}
    traffic[player] = record
    if (record[kind] or 0) > CurTime() then
        return false
    end
    record[kind] = CurTime() + interval
    return true
end

function KP.CanConfigure(player, ent)
    if ((not IsValid(player)) or (not player:IsPlayer())) or (not KP.IsKeypad(ent)) then
        return false
    end
    if ent.CPPICanTool then
        local mode = ((ent:GetClass() == "keypad_wire") and "keypad_willox_wire") or "keypad_willox"
        local allowed = ent:CPPICanTool(player, mode)
        if allowed ~= nil then
            return allowed == true
        end
    end
    local owner = ent:GetKeypadOwner()
    local creator = ent:GetCreator()
    return ((owner == player) or (creator == player)) or player:IsAdmin()
end

function KP.GetSetupPIN(player, wire)
    local record = setup[player]
    local value = record and record[(wire and "wire") or "normal"]
    if value then
        return value.pin
    end
end
net.Receive(
    "KeypadPrivacy.SetupPIN",
    function(length, player)
        if (((length < 9) or (length > 128)) or (not IsValid(player))) or (not player:IsPlayer()) then
            return
        end
        if not allowTraffic(player, "setup", 0.1) then
            return
        end
        local wire, pin = net.ReadBool(), net.ReadString()
        if pin~='' and not KP.ValidPIN(pin) then return end
        setup[player] = setup[player] or {}
        setup[player][(wire and "wire") or "normal"] = {pin = pin}
    end
)

net.Receive('KeypadPrivacy.SetupStyle',function(bits,ply)
    if bits>9000 or bits<40 or not IsValid(ply) or not allowTraffic(ply,'style',.1) then return end
    local wire=net.ReadBool()
    local raw={font=net.ReadString(),r=net.ReadUInt(8),g=net.ReadUInt(8),b=net.ReadUInt(8),image=net.ReadString()}
    setup[ply]=setup[ply] or {}
    setup[ply][wire and 'wireStyle' or 'normalStyle']=KP.FilterStyle(ply,raw)
end)
function KP.GetSetupStyle(ply,wire)
    local record=setup[ply]
    return record and record[wire and 'wireStyle' or 'normalStyle'] or nil
end

net.Receive(
    "KeypadPrivacy.PrivateSubmit",
    function(length, player)
        if
            ((((length < 61) or (length > 256)) or (not IsValid(player))) or (not player:IsPlayer())) or
                (not player:Alive())
         then
            return
        end
        if not allowTraffic(player, "submit", 0.75) then
            return
        end
        local ent, id, pin = net.ReadEntity(), net.ReadUInt(32), net.ReadString()
        if (not KP.IsKeypad(ent)) or (not KP.ValidPIN(pin)) then
            return
        end
        if not KP.ValidFocus(player,ent,id) then return end
        KP.FinishFocus(player,id)
        if ent:GetStatus() ~= ent.Status_None then
            reply(player, "Keypad is busy. Try again shortly.")
            return
        end
        local pads = attempts[player]
        if not pads then
            pads = setmetatable({}, {__mode = "k"})
            attempts[player] = pads
        end
        local record = pads[ent] or {count = 0, expires = 0, locked = 0}
        pads[ent] = record
        local owns=ent:GetKeypadOwner()==player
        if not owns and record.locked > CurTime() then
            reply(player, "Too many attempts. Wait 30 seconds.")
            return
        end
        if record.expires < CurTime() then
            record.count = 0
        end
        if ent:GetPassword() == "" then
            reply(player, "This keypad has not been configured.")
            return
        end
        local granted = pin == ent:GetPassword()
        if granted or owns then
            record.count, record.locked = 0, 0
        else
            record.count, record.expires = record.count + 1, CurTime() + 60
            if record.count >= 10 then
                record.locked, record.count = CurTime() + 30, 0
            end
        end
        -- The attempted PIN stays in this handler: no entity text/buffer or broadcast.
        ent:Process(granted)
        reply(player, (granted and "Access granted.") or "Access denied.")
    end
)

hook.Add(
    "PlayerDisconnected",
    "KeypadPrivacy.Forget",
    function(player)
        setup[player], attempts[player], traffic[player] = nil, nil, nil
    end
)

local function wireOutput(ent, name, value)
    if ((WireLib and WireLib.TriggerOutput) and ent.Outputs) and ent.Outputs[name] then
        WireLib.TriggerOutput(ent, name, value)
    end
end

function KP.InstallEntity(ENT, wire)
    function ENT:SetValue()
        self.Value = ""
        self:SetText("PRIVATE") -- Never replicate entered digits or their length.
    end
    function ENT:GetValue()
        return ""
    end
    function ENT:CancelKeypadOutput()
        local state = runtime[self]
        if not state then return end
        state.token = state.token + 1
        for name in pairs(state.timers) do
            timer.Remove(name)
            state.timers[name] = nil
        end
        local active = state.active
        state.active = nil
        if not active then
            return
        end
        wireOutput(self, active.output, active.off)
        if active.on and IsValid(active.owner) then
            numpad.Deactivate(active.owner, active.key, true)
        end
    end
    function ENT:GetData()
        if not self.KeypadData then
            self.KeypadData = KP.Normalize({Password = "1"})
            self.KeypadData.Password = "" -- Unconfigured entities never use a known default PIN.
        end
        return self.KeypadData
    end
    function ENT:Reset()
        self:CancelKeypadOutput()
        self:SetValue()
        self:SetStatus(self.Status_None)
        self:SetSecure(true)
        if self.Outputs then
            local data = self:GetData()
            wireOutput(self, "Access Granted", data.OutputOff)
            wireOutput(self, "Access Denied", data.OutputOff)
        end
    end
    function ENT:SetData(raw,actor)
        -- Older duplications stored PINs as numbers; normalize them server-side.
        if type(raw) ~= "table" then
            return false
        end
        local data = KP.Normalize(raw)
        if not data then
            return false
        end
        data.Appearance=IsValid(actor) and KP.FilterStyle(actor,raw.Appearance,self:GetData().Appearance) or KP.CleanStyle(raw.Appearance)
        local style=data.Appearance
        self:SetKeypadFont(style.font)
        self:SetCasingImage(style.image)
        self:SetCasingColour(Vector(style.r/255,style.g/255,style.b/255))
        self.KeypadData = data
        self:SetPassword(data.Password)
        self:Reset()
        local modifier =
            (wire and "keypad_wire_password_passthrough") or "keypad_password_passthrough"
        duplicator.ClearEntityModifier(self, modifier)
        duplicator.StoreEntityModifier(self, modifier, data)
        return true
    end
    function ENT:Process(granted)
        if self:GetStatus() ~= self.Status_None then
            return false
        end
        local data = self:GetData()
        if data.Password == "" then
            return false
        end
        local suffix = (granted and "Granted") or "Denied"
        local length, delay = data["Length" .. suffix], data["Delay" .. suffix]
        local initial, repeats = data["InitDelay" .. suffix], data["Repeats" .. suffix]
        self:CancelKeypadOutput()
        local state = runtime[self]
        if not state then
            state = {token = 0, timers = {}}
            runtime[self] = state
        end
        local generation = state.token
        local active = {
            owner = self:GetKeypadOwner(),
            key = data["Key" .. suffix],
            output = "Access " .. suffix,
            off = data.OutputOff,
            on = false
        }
        state.active = active
        self:SetValue()
        self:SetStatus((granted and self.Status_Granted) or self.Status_Denied)
        local function stillCurrent()
            return ((IsValid(self) and (runtime[self] == state)) and (state.token == generation)) and
                (state.active == active)
        end
        local function schedule(delay, callback)
            nextTimer = nextTimer + 1
            local name = "KeypadPrivacy.Output." .. nextTimer
            state.timers[name] = true
            timer.Create(
                name,
                math.max(delay, 0.001),
                1,
                function()
                    state.timers[name] = nil
                    callback()
                end
            )
        end
        for i = 0, repeats do
            local start = initial + ((length + delay) * i)
            schedule(
                start,
                function()
                    if not stillCurrent() then
                        return
                    end
                    active.on = true
                    wireOutput(self, active.output, data.OutputOn)
                    if IsValid(active.owner) then
                        numpad.Activate(active.owner, active.key, true)
                    end
                end
            )
            schedule(
                start + length,
                function()
                    if not stillCurrent() then
                        return
                    end
                    active.on = false
                    wireOutput(self, active.output, data.OutputOff)
                    if IsValid(active.owner) then
                        numpad.Deactivate(active.owner, active.key, true)
                    end
                end
            )
        end
        schedule(
            math.max(((initial + (length * (repeats + 1))) + (delay * repeats)) + 0.25, 2),
            function()
                if stillCurrent() then
                    self:Reset()
                end
            end
        )
        self:EmitSound((granted and "buttons/button9.wav") or "buttons/button11.wav", 75, 100)
        return true
    end
    local previousRemove = ENT.OnRemove
    function ENT:OnRemove()
        self:CancelKeypadOutput()
        runtime[self] = nil
        if previousRemove then
            previousRemove(self)
        end
        if WireLib and WireLib.Remove and self.Outputs then WireLib.Remove(self) end
    end
    local class = (wire and "keypad_wire") or "keypad"
    function ENT:PostEntityPaste(player,entity,created)
        -- Engine duplication may also restore DT values / Lua fields. Re-authorize
        -- against a clean default, never a copied "previous" appearance.
        local data=table.Copy(self:GetData())
        data.Appearance=KP.FilterStyle(player,data.Appearance)
        self.KeypadData=nil
        self:SetData(data,player)
        if WireLib and self.EntityMods and self.EntityMods.WireDupeInfo then
            WireLib.ApplyDupeInfo(player,self,self.EntityMods.WireDupeInfo,function(id,default)
                if id==0 then return game.GetWorld() end
                local ent=created and created[id]
                return IsValid(ent) and ent or default
            end)
        end
        self.DuplicationInProgress=nil
    end
    function ENT:OnDuplicated() self.DuplicationInProgress=true end
    function ENT:PreEntityCopy()
        if not WireLib then return end
        duplicator.ClearEntityModifier(self,'WireDupeInfo')
        local info=WireLib.BuildDupeInfo(self)
        if info then duplicator.StoreEntityModifier(self,'WireDupeInfo',info) end
    end
    function ENT:BuildDupeInfo()
        return WireLib and WireLib.BuildDupeInfo(self) or nil
    end
    function ENT:ApplyDupeInfo(player,ent,info,lookup)
        if WireLib then WireLib.ApplyDupeInfo(player,ent,info,lookup) end
    end
    function ENT:OnRestore()
        if WireLib and self.Outputs then WireLib.Restored(self) end
    end
    function ENT:OnEntityCopyTableFinish(data)
        data.OverlayData=nil data.lastWireOverlayUpdate=nil data.WireDebugName=nil
    end
    duplicator.RegisterEntityModifier(
        (wire and "keypad_wire_password_passthrough") or "keypad_password_passthrough",
        function(player, ent, data)
            if ((not IsValid(player)) or (not IsValid(ent))) or (ent:GetClass() ~= class) then
                return
            end
            if not KP.CanConfigure(player, ent) then
                return
            end
            ent:SetKeypadOwner(player)
            ent.KeypadData=nil
            ent:SetData(data,player)
        end
    )
    if not wire then
        duplicator.RegisterEntityModifier('keypad_wire_password_passthrough',function(player,ent,data)
            if not KP.IsKeypad(ent) or not KP.CanConfigure(player,ent) then return end
            ent:SetKeypadOwner(player) ent.KeypadData=nil ent:SetData(data,player)
        end)
    end
end
return KP

