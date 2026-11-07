if SERVER then
    CreateConVar("sbox_maxkeypads", 10)
end

TOOL.Category = "Construction"
TOOL.Name = "Keypad"
TOOL.Command = nil

TOOL.ClientConVar["weld"] = "1"
TOOL.ClientConVar["freeze"] = "1"

-- Setup PINs use an explicit private packet, never tool userinfo convars.
TOOL.ClientConVar["secure"] = "1" -- Kept for saved presets; privacy is always enabled.

TOOL.ClientConVar["repeats_granted"] = "0"
TOOL.ClientConVar["repeats_denied"] = "0"

TOOL.ClientConVar["length_granted"] = "0.1"
TOOL.ClientConVar["length_denied"] = "0.1"

TOOL.ClientConVar["delay_granted"] = "0"
TOOL.ClientConVar["delay_denied"] = "0"

TOOL.ClientConVar["init_delay_granted"] = "0"
TOOL.ClientConVar["init_delay_denied"] = "0"

TOOL.ClientConVar["key_granted"] = "0"
TOOL.ClientConVar["key_denied"] = "0"
TOOL.ClientConVar["output_on"] = "1"
TOOL.ClientConVar["output_off"] = "0"

cleanup.Register("keypads")

if CLIENT then
    language.Add("tool.keypad_willox.name", "Keypad")
    language.Add("tool.keypad_willox.0", "Left Click: Create, Right Click: Update")
    language.Add("tool.keypad_willox.desc", "Creates Keypads for secure access")

    language.Add("Undone_Keypad", "Undone Keypad")
    language.Add("Cleanup_keypads", "Keypads")
    language.Add("Cleaned_keypads", "Cleaned up all Keypads")

    language.Add("SBoxLimit_keypads", "You've hit the Keypad limit!")
end

function TOOL:SetupKeypad(ent, pass)
    local data = {
        Password = pass,
        RepeatsGranted = self:GetClientNumber("repeats_granted"),
        RepeatsDenied = self:GetClientNumber("repeats_denied"),
        LengthGranted = self:GetClientNumber("length_granted"),
        LengthDenied = self:GetClientNumber("length_denied"),
        DelayGranted = self:GetClientNumber("delay_granted"),
        DelayDenied = self:GetClientNumber("delay_denied"),
        InitDelayGranted = self:GetClientNumber("init_delay_granted"),
        InitDelayDenied = self:GetClientNumber("init_delay_denied"),
        KeyGranted = self:GetClientNumber("key_granted"),
        KeyDenied = self:GetClientNumber("key_denied"),
        OutputOn = self:GetClientNumber("output_on",1),
        OutputOff = self:GetClientNumber("output_off",0),
        Secure = util.tobool(self:GetClientNumber("secure"))
    }

    ent:SetKeypadOwner(self:GetOwner())
    data.Appearance = KeypadPrivacy.GetSetupStyle(self:GetOwner(), false) or ent:GetData().Appearance
    ent:SetData(data, self:GetOwner())
end

function TOOL:RightClick(tr)
    if not KeypadPrivacy.IsKeypad(tr.Entity) then
        return false
    end

    if CLIENT then
        return true
    end

    local ply = self:GetOwner()
    if not IsValid(ply) then
        return false
    end
    local password = KeypadPrivacy.GetSetupPIN(ply, false)

    local spawn_pos = tr.HitPos
    local trace_ent = tr.Entity

    if not KeypadPrivacy.ValidPIN(password) then
        ply:PrintMessage(3, "Enter a PIN in the tool panel.")
        return false
    end
    if KeypadPrivacy.CanConfigure(ply, trace_ent) then
        self:SetupKeypad(trace_ent, password)

        return true
    end
end

function TOOL:LeftClick(tr)
    if IsValid(tr.Entity) and (tr.Entity:GetClass():lower() == "player") then
        return false
    end

    if CLIENT then
        return true
    end

    local ply = self:GetOwner()
    if not IsValid(ply) then
        return false
    end
    local password = KeypadPrivacy.GetSetupPIN(ply, false)

    local spawn_pos = tr.HitPos + tr.HitNormal
    local trace_ent = tr.Entity

    if not KeypadPrivacy.ValidPIN(password) then
        ply:PrintMessage(3, "Enter a PIN in the tool panel.")
        return false
    end

    if not self:GetWeapon():CheckLimit("keypads") then
        return false
    end

    local ent = ents.Create("keypad")
    ent:SetPos(spawn_pos)
    ent:SetAngles(tr.HitNormal:Angle())
    ent:Spawn()

    ent:SetPlayer(ply)
    ent:SetCreator(ply)

    local freeze = util.tobool(self:GetClientNumber("freeze"))
    local weld = util.tobool(self:GetClientNumber("weld"))

    if freeze or weld then
        local phys = ent:GetPhysicsObject()

        if IsValid(phys) then
            phys:EnableMotion(false)
        end
    end

    if weld then
        local weld = constraint.Weld(ent, trace_ent, 0, 0, 0, true, false)
    end

    self:SetupKeypad(ent, password)

    undo.Create("Keypad")
    undo.AddEntity(ent)
    undo.SetPlayer(ply)
    undo.Finish()

    ply:AddCount("keypads", ent)
    ply:AddCleanup("keypads", ent)

    return true
end

if CLIENT then
    local defaultSettings=table.Copy(TOOL.ClientConVar)
    local function ResetSettings(ply)
        for key,value in pairs(defaultSettings) do
            RunConsoleCommand('keypad_willox_'..key,value)
        end
        KeypadPrivacy.ResetToolPreferences(false)
    end

    concommand.Add("keypad_willox_reset", ResetSettings)

    function TOOL.BuildCPanel(CPanel)
        KeypadPrivacy.BuildToolSettings(CPanel, false)
        CPanel:CheckBox("Weld", "keypad_willox_weld")
        CPanel:CheckBox("Freeze", "keypad_willox_freeze")

        local ctrl = vgui.Create("CtrlNumPad", CPanel)
        ctrl:SetConVar1("keypad_willox_key_granted")
        ctrl:SetConVar2("Keypad_willox_key_denied")
        ctrl:SetLabel1("Access Granted Key")
        ctrl:SetLabel2("Access Denied Key")
        CPanel:AddPanel(ctrl)
        if WireLib then
            local outputs=vgui.Create('DForm') outputs:SetName('Wire outputs')
            outputs:NumSlider('On','keypad_willox_output_on',-1000,1000,2)
            outputs:NumSlider('Off','keypad_willox_output_off',-1000,1000,2)
            CPanel:AddItem(outputs)
        end

        local granted = vgui.Create("DForm")
        granted:SetName("Access Granted Settings")

        granted:NumSlider("Hold Length:", "keypad_willox_length_granted", 0.1, 10, 2)
        granted:NumSlider("Initial Delay:", "keypad_willox_init_delay_granted", 0, 10, 2)
        granted:NumSlider("Multiple Press Delay:", "keypad_willox_delay_granted", 0, 10, 2)
        granted:NumSlider("Additional Repeats:", "keypad_willox_repeats_granted", 0, 5, 0)
        CPanel:AddItem(granted)

        local denied = vgui.Create("DForm")
        denied:SetName("Access Denied Settings")

        denied:NumSlider("Hold Length:", "keypad_willox_length_denied", 0.1, 10, 2)
        denied:NumSlider("Initial Delay:", "keypad_willox_init_delay_denied", 0, 10, 2)
        denied:NumSlider("Multiple Press Delay:", "keypad_willox_delay_denied", 0, 10, 2)
        denied:NumSlider("Additional Repeats:", "keypad_willox_repeats_denied", 0, 5, 0)
        CPanel:AddItem(denied)

        CPanel:Button("Default Settings", "keypad_willox_reset")

        CPanel:Help("")

        local faq = CPanel:Help("Information")
        faq:SetFont("GModWorldtip")

        CPanel:Help("Press E to use. Look at each button and press E. Escape to leave.")
        KeypadPrivacy.BuildProfiles(CPanel)
    end
end

