local KP=KeypadPrivacy
local path='keypad_privacy/preferences.json'
local saved=util.JSONToTable(file.Read(path,'DATA') or '') or {}
if not istable(saved) then saved={} end
local panels=setmetatable({},{__mode='k'})
local pinEntries=setmetatable({},{__mode='k'})
local preferences={}
local function prefs(wire)
    local key=wire and 'wire' or 'normal'
    if preferences[key] then return preferences[key] end
    if not istable(saved[key]) then saved[key]={} end
    local p=saved[key]
    p.pin=KP.ValidPIN(p.pin) and p.pin or ''
    p.style=KP.CleanStyle(p.style)
    preferences[key]=p
    return p
end
local function save()
    timer.Create('KeypadPrivacy.SavePreferences',.3,1,function()
        file.CreateDir('keypad_privacy') file.Write(path,util.TableToJSON(saved))
    end)
end
local sent,pending={},{}
local nextSend=0
local function flush()
    if not IsValid(LocalPlayer()) then return end
    if RealTime()<nextSend then timer.Create('KeypadPrivacy.FlushPreferences',nextSend-RealTime(),1,flush) return end
    local key,request=next(pending)
    if not key then return end
    pending[key]=nil
    local wire=key=='wire'
    local p=prefs(wire) local s=p.style
    local previous=sent[key] or {}
    local styleKey=s.font..':'..s.r..':'..s.g..':'..s.b..':'..s.image
    local sentAny=false
    if request.force or previous.pin~=p.pin then
        net.Start('KeypadPrivacy.SetupPIN') net.WriteBool(wire) net.WriteString(p.pin) net.SendToServer()
        previous.pin=p.pin sentAny=true
    end
    if request.force or previous.style~=styleKey then
        net.Start('KeypadPrivacy.SetupStyle') net.WriteBool(wire) net.WriteString(s.font)
        net.WriteUInt(s.r,8) net.WriteUInt(s.g,8) net.WriteUInt(s.b,8) net.WriteString(s.image) net.SendToServer()
        previous.style=styleKey sentAny=true
    end
    sent[key]=previous
    if sentAny then nextSend=RealTime()+.12 end
    if next(pending) then timer.Create('KeypadPrivacy.FlushPreferences',math.max(nextSend-RealTime(),.001),1,flush) end
end
function KP.SendToolPreferences(wire,force)
    local key=wire and 'wire' or 'normal'
    local request=pending[key] or {}
    request.force=request.force or force
    pending[key]=request
    flush()
end
local function changed(wire)
    save()
    timer.Create('KeypadPrivacy.Send.'..tostring(wire),.15,1,function() KP.SendToolPreferences(wire) end)
end
local function entry(panel,label,value,onChange,onCommit)
    panel:Help(label)
    local e=vgui.Create('DTextEntry',panel) e:SetTall(24) e:SetValue(value) e:SetUpdateOnType(true)
    e.OnValueChange=function(self,text) onChange(self,text) end
    e.OnEnter=function() onCommit() end
    e.OnLoseFocus=function() onCommit() end
    panel:AddItem(e) return e
end
local function refreshPanels()
    for panel in pairs(panels) do
        if IsValid(panel) then panel:RefreshPermissions() else panels[panel]=nil end
    end
    if not next(panels) then timer.Remove('KeypadPrivacy.ToolPermissions') end
end
local function refreshToolFields(wire)
    local p=prefs(wire)
    for entry,kind in pairs(pinEntries) do
        if IsValid(entry) and kind==wire then entry:SetText(p.pin) entry:SetCaretPos(#p.pin) end
    end
    for panel,record in pairs(panels) do
        if record.wire==wire then record.signature='' end
    end
    refreshPanels()
end
function KP.ResetToolPreferences(wire)
    local p=prefs(wire)
    p.pin='' p.style=KP.CleanStyle(nil)
    timer.Remove('KeypadPrivacy.Send.'..tostring(wire))
    refreshToolFields(wire)
    save()
    KP.SendToolPreferences(wire,true)
end
function KP.BuildToolSettings(panel,wire)
    local p=prefs(wire)
    local pin=entry(panel,'PIN',p.pin,function(self,text)
        local caret=self:GetCaretPos()
        local clean=text:gsub('[^0-9]',''):sub(1,8)
        if clean~=text then
            self:SetText(clean)
            self:SetCaretPos(math.min(#clean,#text:sub(1,caret):gsub('[^0-9]','')))
        end
        p.pin=clean changed(wire)
    end,function() KP.SendToolPreferences(wire) end)
    pin.KeypadPIN=true
    pinEntries[pin]=wire
    local appearance=vgui.Create('DForm',panel) appearance:SetName('Appearance') panel:AddItem(appearance)
    panels[appearance]={wire=wire,signature=''}
    function appearance:RefreshPermissions()
        local fontAllowed=KP.CanStyle(LocalPlayer(),'font')
        local colourAllowed=KP.CanStyle(LocalPlayer(),'colour')
        local imageAllowed=KP.CanStyle(LocalPlayer(),'image')
        local signature=(fontAllowed and 1 or 0)+(colourAllowed and 2 or 0)+(imageAllowed and 4 or 0)
        if panels[self].signature==signature then return end
        panels[self].signature=signature self:Clear()
        local any=false
        if fontAllowed then
            any=true local box=vgui.Create('DComboBox',self) box:SetTall(24)
            for _,font in ipairs(KP.Config.Fonts) do if KP.Fonts[font.id] then box:AddChoice(font.name,font.id,p.style.font==font.id) end end
            box.OnSelect=function(_,_,_,id) p.style.font=id changed(wire) end self:AddItem(box)
        end
        if colourAllowed then
            any=true local mixer=vgui.Create('DColorMixer',self) mixer:SetTall(150) mixer:SetPalette(false) mixer:SetAlphaBar(false)
            mixer:SetColor(Color(p.style.r,p.style.g,p.style.b))
            mixer.ValueChanged=function(_,c) p.style.r,p.style.g,p.style.b=math.Round(c.r),math.Round(c.g),math.Round(c.b) changed(wire) end
            self:AddItem(mixer)
        end
        if imageAllowed then
            any=true local e=entry(self,'Casing image',p.style.image,function(_,text)
                if #text<=511 then p.style.image=text changed(wire) end
            end,function()
                if not KP.ValidImageURL(p.style.image) then notification.AddLegacy('Use a direct Imgur or Discord PNG/JPG link.',NOTIFY_ERROR,4) return end
                KP.SendToolPreferences(wire)
            end)
            e:SetPlaceholderText('Discord / Imgur link')
        end
        self:SetVisible(any) self:InvalidateLayout(true)
    end
    appearance:RefreshPermissions()
    if not timer.Exists('KeypadPrivacy.ToolPermissions') then timer.Create('KeypadPrivacy.ToolPermissions',1,0,refreshPanels) end
    KP.SendToolPreferences(wire,true)
end
hook.Add('InitPostEntity','KeypadPrivacy.RestoreTool',function()
    timer.Simple(2,function() KP.SendToolPreferences(false) end)
end)
-- Flush text on the first tool click as well as Enter/focus loss.
hook.Add('PlayerBindPress','KeypadPrivacy.FlushTool',function(_,bind,pressed)
    if not pressed or (bind~='+attack' and bind~='+attack2') then return end
    local ply=LocalPlayer() local gun=ply:GetActiveWeapon()
    if not IsValid(gun) or gun:GetClass()~='gmod_tool' then return end
    local mode=GetConVar('gmod_toolmode'):GetString()
    if mode=='keypad_willox' or mode=='keypad_willox_wire' then KP.SendToolPreferences(false) end
end)
KP.ToolPreferences=prefs

-- Local profiles use one bounded data file; profile names never become paths.
local profilePath='keypad_privacy/profiles.json'
local profiles
local rules={weld={1,0,1},freeze={1,0,1},secure={1,1,1},
    repeats_granted={0,0,5},repeats_denied={0,0,5},
    length_granted={.1,.1,10,true},length_denied={.1,.1,10,true},
    delay_granted={0,0,10,true},delay_denied={0,0,10,true},
    init_delay_granted={0,0,10,true},init_delay_denied={0,0,10,true},
    key_granted={0,0,BUTTON_CODE_LAST or 159},key_denied={0,0,BUTTON_CODE_LAST or 159},
    output_on={1,-1000,1000,true},output_off={0,-1000,1000,true}}
local function profileName(name)
    if not isstring(name) then return end
    name=string.Trim(name)
    if name=='' or #name>96 or name:find('%c') then return end
    return name
end
local function cleanProfile(raw)
    if not istable(raw) then return end
    local result={pin=KP.ValidPIN(raw.pin) and raw.pin or '',style=KP.CleanStyle(raw.style),settings={}}
    -- Retain a server-specific font ID in the saved profile for other servers.
    local font=istable(raw.style) and raw.style.font
    if isstring(font) and #font<=32 and font:match('^[a-z0-9_]+$') then result.style.font=font end
    local settings=istable(raw.settings) and raw.settings or {}
    for key,rule in pairs(rules) do result.settings[key]=KP.Number(settings[key],rule[1],rule[2],rule[3],not rule[4]) end
    return result
end
local function readProfiles()
    if profiles then return profiles end
    profiles={}
    if file.Size(profilePath,'DATA')>256*1024 then return profiles end
    local raw=util.JSONToTable(file.Read(profilePath,'DATA') or '')
    if not istable(raw) or not istable(raw.profiles) then return profiles end
    local count=0
    for name,value in pairs(raw.profiles) do
        local clean=profileName(name) local p=cleanProfile(value)
        if clean and p and not profiles[clean] then profiles[clean]=p count=count+1 if count>=64 then break end end
    end
    return profiles
end
local function writeProfiles()
    file.CreateDir('keypad_privacy')
    file.Write(profilePath,util.TableToJSON({version=1,profiles=profiles}))
end
function KP.ProfileNames()
    local names={} for name in pairs(readProfiles()) do names[#names+1]=name end
    table.sort(names) return names
end
function KP.SaveProfile(name)
    name=profileName(name)
    if not name then return false,'Enter a short profile name.' end
    local list=readProfiles()
    if not list[name] and table.Count(list)>=64 then return false,'Delete a profile first (64 maximum).' end
    local p=prefs(false) local raw={pin=p.pin,style=p.style,settings={}}
    for key in pairs(rules) do
        local cv=GetConVar('keypad_willox_'..key)
        raw.settings[key]=cv and cv:GetString() or nil
    end
    list[name]=cleanProfile(raw) writeProfiles() return true
end
function KP.DeleteProfile(name)
    local list=readProfiles()
    if not isstring(name) or not list[name] then return false,'Select a profile.' end
    list[name]=nil writeProfiles() return true
end
function KP.LoadProfile(name)
    local raw=isstring(name) and readProfiles()[name]
    if not raw then return false,'Select a profile.' end
    local record=cleanProfile(raw) local p=prefs(false) local style=KP.CleanStyle(nil)
    local player=LocalPlayer()
    if KP.CanStyle(player,'font') and KP.Fonts[record.style.font] then style.font=record.style.font end
    if KP.CanStyle(player,'colour') then style.r,style.g,style.b=record.style.r,record.style.g,record.style.b end
    if KP.CanStyle(player,'image') then style.image=record.style.image end
    p.pin,p.style=record.pin,style
    for key,value in pairs(record.settings) do RunConsoleCommand('keypad_willox_'..key,tostring(value)) end
    timer.Remove('KeypadPrivacy.Send.false')
    refreshToolFields(false) save() KP.SendToolPreferences(false,true)
    return true
end
function KP.BuildProfiles(panel)
    local form=vgui.Create('DForm',panel) form:SetName('Profiles') panel:AddItem(form)
    local dropdown=vgui.Create('DComboBox',form) dropdown:SetTall(24) dropdown:SetValue('Choose a profile') form:AddItem(dropdown)
    local name=vgui.Create('DTextEntry',form) name:SetTall(24) name:SetPlaceholderText('Profile name') form:AddItem(name)
    local selected
    local function refresh(chosen)
        selected=chosen dropdown:Clear() dropdown:SetValue(chosen or 'Choose a profile')
        for _,value in ipairs(KP.ProfileNames()) do dropdown:AddChoice(value,value,value==chosen) end
    end
    local function feedback(ok,message) if not ok then notification.AddLegacy(message,NOTIFY_ERROR,3) end end
    dropdown.OnSelect=function(_,_,value)
        local ok,message=KP.LoadProfile(value) feedback(ok,message)
        if ok then selected=value name:SetText(value) end
    end
    local row=vgui.Create('DPanel',form) row:SetTall(24) row.Paint=function() end form:AddItem(row)
    local saveButton=vgui.Create('DButton',row) saveButton:SetText('Save') saveButton:Dock(LEFT) saveButton:DockMargin(0,0,4,0)
    local deleteButton=vgui.Create('DButton',row) deleteButton:SetText('Delete') deleteButton:Dock(FILL)
    row.OnSizeChanged=function(_,width) saveButton:SetWide(math.max(1,math.floor(width/2)-2)) end
    saveButton.DoClick=function()
        local value=profileName(name:GetText()) local ok,message=KP.SaveProfile(value) feedback(ok,message)
        if ok then refresh(value) name:SetText(value) end
    end
    deleteButton.DoClick=function()
        local ok,message=KP.DeleteProfile(selected) feedback(ok,message)
        if ok then refresh() name:SetText('') end
    end
    refresh()
end
