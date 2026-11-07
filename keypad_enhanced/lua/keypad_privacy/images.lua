local KP=KeypadPrivacy
local cache,queue={},{}
local count,active=0,0
local maxBytes=KP.Config.MaxImageBytes
local maxDim=KP.Config.MaxImageDimension
local function be(s,p,n)
    local value=0
    for i=p,p+n-1 do local byte=s:byte(i) if not byte then return 0 end value=value*256+byte end
    return value
end
function KP.ImageDimensions(body)
    if body:sub(1,8)=='\137PNG\13\10\26\10' and body:sub(13,16)=='IHDR' then return be(body,17,4),be(body,21,4),'png' end
    if body:sub(1,2)~='\255\216' then return end
    local p=3
    while p<#body do
        if body:byte(p)~=255 then return end
        local marker=body:byte(p+1) p=p+2
        if marker==255 then p=p-1
        elseif marker==218 or marker==217 then return
        else
            local size=be(body,p,2)
            if size<2 or p+size-1>#body then return end
            if marker==192 or marker==193 or marker==194 then return be(body,p+5,2),be(body,p+3,2),'jpg' end
            p=p+size
        end
    end
end
file.CreateDir('keypad_privacy/images')
-- Session cache only; remove previous session files so disk use cannot grow forever.
for _,name in ipairs(file.Find('keypad_privacy/images/*','DATA')) do file.Delete('keypad_privacy/images/'..name) end
local function pump()
    if active>=2 or #queue==0 then return end
    local item=table.remove(queue,1) active=active+1
    local request=item.url
    if request:find('https://media.discordapp.net/',1,true)==1 then
        request=request:gsub('([?&]format=)[^&]*','%1png')
    end
    local function done() active=active-1 pump() end
    http.Fetch(request,function(body,size,_,code)
        if (code==200 or code==206) and size<=maxBytes then
            local w,h,ext=KP.ImageDimensions(body)
            if w and w>0 and h>0 and w<=maxDim and h<=maxDim then
                local path='keypad_privacy/images/'..util.SHA256(item.url)..'.'..ext
                file.Write(path,body)
                local mat=Material('data/'..path,'smooth noclamp')
                if not mat:IsError() then item.material=mat end
            end
        end
        item.finished=true done()
    end,function() item.finished=true done() end,{Range='bytes=0-'..(maxBytes-1)})
    pump()
end
function KP.CasingImage(url)
    if url=='' then return end
    local item=cache[url]
    if not item then
        if not KP.ValidImageURL(url) then return end
        if count>=KP.Config.MaxCachedImages then return end
        count=count+1 item={url=url} cache[url]=item queue[#queue+1]=item pump()
    end
    return item.material
end
