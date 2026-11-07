local KP=KeypadPrivacy
KP.Config=include('keypad_privacy/config.lua')
KP.Fonts={}
for index,font in ipairs(KP.Config.Fonts) do
    if index>16 then break end
    if isstring(font.id) and font.id:match('^[a-z0-9_]+$') and #font.id<=32 and isstring(font.family) then
        KP.Fonts[font.id]=font
        if SERVER and font.file and font.file:match('^resource/fonts/[%w_%-]+%.ttf$') then resource.AddFile(font.file) end
    end
end
KP.Fonts.default=KP.Fonts.default or {id='default',name='Classic',family='Roboto'}
KP.Access={font='keypad customize font',colour='keypad customize colour',image='keypad customize image'}
function KP.CanStyle(ply,kind)
    if not IsValid(ply) then return false end
    -- A global lookup is enough; no addon scans, timers, or disk checks.
    if not ulx then return true end
    if ply:IsSuperAdmin() then return true end
    return ULib and ULib.ucl and ULib.ucl.query(ply,KP.Access[kind])==true or false
end
function KP.ValidImageURL(url)
    if not isstring(url) or #url>511 then return false end
    if url=='' then return true end
    if url:find('[%c%s]') then return false end
    local host,path=url:match('^https://([a-z0-9%.%-]+)(/[^#]+)$')
    if host=='i.imgur.com' then return path:match('^/[%w]+%.png$')~=nil or path:match('^/[%w]+%.jpg$')~=nil or path:match('^/[%w]+%.jpeg$')~=nil end
    if host~='cdn.discordapp.com' and host~='media.discordapp.net' then return false end
    local bare=path and path:match('^([^?]+)')
    return bare and bare:match('^/attachments/%d+/%d+/[^/]+%.[%w]+$')~=nil and (bare:lower():match('%.png$')~=nil or bare:lower():match('%.jpe?g$')~=nil) or false
end
function KP.CleanStyle(raw)
    raw=istable(raw) and raw or {}
    return {font=KP.Fonts[raw.font] and raw.font or 'default',r=KP.Number(raw.r,36,0,255,true),g=KP.Number(raw.g,36,0,255,true),b=KP.Number(raw.b,36,0,255,true),image=KP.ValidImageURL(raw.image) and raw.image or ''}
end
function KP.FilterStyle(ply,raw,previous)
    local result=KP.CleanStyle(previous)
    local proposed=KP.CleanStyle(raw)
    if KP.CanStyle(ply,'font') then result.font=proposed.font end
    if KP.CanStyle(ply,'colour') then result.r,result.g,result.b=proposed.r,proposed.g,proposed.b end
    if KP.CanStyle(ply,'image') then result.image=proposed.image end
    return result
end
if SERVER then
    local function register()
        if not ULib or not ULib.ucl then return end
        for kind,right in pairs(KP.Access) do ULib.ucl.registerAccess(right,ULib.ACCESS_SUPERADMIN,'Customize keypad '..kind,'Keypads') end
    end
    hook.Add('Initialize','KeypadPrivacy.Access',register)
    hook.Add('ULibInitialized','KeypadPrivacy.Access',register)
    timer.Simple(0,register)
end
return KP
