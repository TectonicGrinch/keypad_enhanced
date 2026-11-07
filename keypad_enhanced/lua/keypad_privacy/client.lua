local KP=include('keypad_privacy/shared.lua')
if KP.ClientLoaded then return KP end
KP.ClientLoaded=true
net.Receive('KeypadPrivacy.Result',function() notification.AddLegacy(net.ReadString(),NOTIFY_GENERIC,4) end)
include('keypad_privacy/tool_client.lua')
include('keypad_privacy/images.lua')
include('keypad_privacy/private_input.lua')
return KP
