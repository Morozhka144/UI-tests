--[[ MORO CHAT — Premium Edition v3.0 (Notifications Fix + Sound Selection) ]]--
local Library = {}
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")
local TextService      = game:GetService("TextService")
local SoundService     = game:GetService("SoundService")

local request = (syn and syn.request) or (http and http.request) or http_request
or (fluxus and fluxus.request) or (getgenv and getgenv().request) or request
if not request then warn("[MoroChat] Injector does not support request()!"); return end

local writefile = writefile or function() end
local readfile = readfile or function() return "" end
local isfile = isfile or function() return false end

local function cloneTable(t) local res = {} for k, v in pairs(t) do res[k] = v end return res end

--// LUCIDE ICONS
local Lucide
pcall(function()
    Lucide = loadstring(game:HttpGet("https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/lucide-roblox.luau"))()
end)

local function getIcon(name)
    if not Lucide then return nil end
    local ok, data = pcall(function()
        if Lucide.GetAsset then return Lucide.GetAsset(name) end
        if Lucide.Icons and Lucide.Icons[name] then return Lucide.Icons[name] end
        if type(Lucide) == "function" then return Lucide(name) end
        return Lucide[name]
    end)
    if ok and data then
        if type(data) == "table" then return data.Image or data.id or data.Id or data.asset, data end
        return data
    end
    return nil
end

--// THEMES
local themes = {
    default = { bg=Color3.fromRGB(18,19,26), bg2=Color3.fromRGB(26,28,38), panel=Color3.fromRGB(32,35,48), input=Color3.fromRGB(38,41,56), accent=Color3.fromRGB(120,145,255), accent2=Color3.fromRGB(180,120,255), text=Color3.fromRGB(240,242,250), dim=Color3.fromRGB(140,146,165), online=Color3.fromRGB(80,220,130), danger=Color3.fromRGB(255,80,100) },
    amoled = { bg=Color3.fromRGB(0,0,0), bg2=Color3.fromRGB(15,15,15), panel=Color3.fromRGB(25,25,25), input=Color3.fromRGB(35,35,35), accent=Color3.fromRGB(0,255,150), accent2=Color3.fromRGB(0,200,100), text=Color3.fromRGB(255,255,255), dim=Color3.fromRGB(120,120,120), online=Color3.fromRGB(0,255,150), danger=Color3.fromRGB(255,50,50) },
    sunset = { bg=Color3.fromRGB(30,15,20), bg2=Color3.fromRGB(45,20,30), panel=Color3.fromRGB(60,30,40), input=Color3.fromRGB(75,40,50), accent=Color3.fromRGB(255,120,80), accent2=Color3.fromRGB(255,180,100), text=Color3.fromRGB(255,240,240), dim=Color3.fromRGB(180,140,140), online=Color3.fromRGB(100,255,150), danger=Color3.fromRGB(255,80,80) },
    ocean = { bg=Color3.fromRGB(10,20,30), bg2=Color3.fromRGB(15,30,45), panel=Color3.fromRGB(20,40,60), input=Color3.fromRGB(25,50,75), accent=Color3.fromRGB(0,180,255), accent2=Color3.fromRGB(100,220,255), text=Color3.fromRGB(230,245,255), dim=Color3.fromRGB(120,150,180), online=Color3.fromRGB(80,220,130), danger=Color3.fromRGB(255,100,100) }
}
local themeNames = {"default", "amoled", "sunset", "ocean"}

--// SOUND PRESETS
local customAsset = getcustomasset or getsynasset
local soundPresets = {
    { name = "Achievement", id = "rbxassetid://10469938989" },
    { name = "Tone",        id = nil, file = "tone.mp3", url = "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/tone%20notification.mp3" },
    { name = "Alert",       id = nil, file = "alert.mp3", url = "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/alert%20notification.mp3" },
    { name = "Windows XP",  id = nil, file = "xp.ogg",   url = "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/windows%20xp%20exclamation.ogg" },
    { name = "GTA Cell",    id = nil, file = "gta.ogg",  url = "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/gta%20notification.ogg" },
    { name = "Litvin",      id = nil, file = "Litvin.m4a",  url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/Litvin.m4a" },
    { name = "Payment",     id = nil, file = "payment.mp3", url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/payment.mp3" },
    { name = "Soft",        id = nil, file = "soft.mp3",    url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/soft.mp3" },
    { name = "Tuntun",      id = nil, file = "tuntun.mp3",  url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/tuntun.mp3" },
    { name = "Vibe",        id = nil, file = "vibe.m4a",    url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/vibe.m4a" },
    { name = "Voiced",      id = nil, file = "voiced.mp3",  url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/voiced.mp3" },
}

pcall(function()
    if isfolder and makefolder and writefile and isfile and customAsset then
        if not isfolder("moro") then
            makefolder("moro")
        end
        if not isfolder("moro/Notification Sounds") then
            makefolder("moro/Notification Sounds")
        end
        for _, preset in ipairs(soundPresets) do
            if preset.url then
                local path = "moro/Notification Sounds/" .. preset.file
                if not isfile(path) then
                    pcall(function() writefile(path, game:HttpGet(preset.url)) end)
                end
                if isfile(path) then
                    local ok, asset = pcall(function() return customAsset(path) end)
                    if ok and asset then preset.id = asset end
                end
            end
        end
    end
end)

--// CONFIG SYSTEM
local CONFIG_FILE = "moro_chat_config.json"
local defaultSettings = {
    openKey  = Enum.KeyCode.RightShift,
    typeKey  = Enum.KeyCode.Slash,
    showHistory = true,
    notifications = true,
    toasts = true,
    sound = true,
    soundIndex = 1,
    transparency = 0,
    width = 380,
    height = 250,
    bubbleSize = 54,
    theme = "default"
}
local settings = cloneTable(defaultSettings)

local function loadConfig()
    if isfile(CONFIG_FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                if (k == "openKey" or k == "typeKey") and type(v) == "string" then
                    settings[k] = Enum.KeyCode[v] or defaultSettings[k]
                else
                    settings[k] = v
                end
            end
        end
    end
end

local function saveConfig()
    local toSave = cloneTable(settings)
    toSave.openKey = settings.openKey.Name
    toSave.typeKey = settings.typeKey.Name
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(toSave)) end)
end

loadConfig()
local theme = themes[settings.theme] or themes.default

--// HELPERS
local function corner(o, r) local c=Instance.new("UICorner",o); c.CornerRadius=UDim.new(0,r); return c end
local function stroke(o,col,th,tr) local s=Instance.new("UIStroke",o); s.Color=col; s.Thickness=th or 1; s.Transparency=tr or 0; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s end
local function grad(o,c1,c2,rot) local g=Instance.new("UIGradient",o); g.Color=ColorSequence.new(c1,c2); g.Rotation=rot or 0; return g end
local function pad(o,l,r,t,b) local p=Instance.new("UIPadding",o); p.PaddingLeft=UDim.new(0,l or 0); p.PaddingRight=UDim.new(0,r or 0); p.PaddingTop=UDim.new(0,t or 0); p.PaddingBottom=UDim.new(0,b or 0); return p end
local function tw(o,t,props,style)
    local tween=TweenService:Create(o,TweenInfo.new(t,style or Enum.EasingStyle.Quart,Enum.EasingDirection.Out),props)
    tween:Play(); return tween
end
local function icon(parent, name, size, col)
    local img = Instance.new("ImageLabel", parent)
    img.BackgroundTransparency = 1
    img.Size = UDim2.new(0, size, 0, size)
    img.ImageColor3 = col or theme.text
    local id, data = getIcon(name)
    if id then
        img.Image = tostring(id):match("rbxassetid") and tostring(id) or ("rbxassetid://"..tostring(id))
        if data and data.ImageRectSize then img.ImageRectOffset=data.ImageRectOffset; img.ImageRectSize=data.ImageRectSize end
    end
    return img
end
local function draggable(handle, target)
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; startInput=i.Position; startPos=target.Position
            local c; c=i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false; c:Disconnect() end end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-startInput
            target.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
end

--// SOUND
local notifSound = Instance.new("Sound")
notifSound.Name = "MoroChatSound"
notifSound.Volume = 0.65
pcall(function() notifSound.Parent = SoundService end)

local function playNotifSound()
    local idx = math.clamp(settings.soundIndex or 1, 1, #soundPresets)
    local preset = soundPresets[idx]
    local sndId = (preset and preset.id) or soundPresets[1].id
    if sndId and notifSound then
        pcall(function()
            notifSound.SoundId = sndId
            notifSound.TimePosition = 0
            notifSound:Play()
        end)
    end
end

--// FIREBASE
local function getDB()
    local h = os.date("!*t").hour
    if h<4 then return "https://moro-chat-a0c9b-default-rtdb.europe-west1.firebasedatabase.app/messages.json"
    elseif h<8 then return "https://moro-chat-2-default-rtdb.europe-west1.firebasedatabase.app/messages.json"
    elseif h<12 then return "https://moro-chat-3-default-rtdb.europe-west1.firebasedatabase.app/messages.json"
    elseif h<16 then return "https://moro-chat-3-60789-default-rtdb.europe-west1.firebasedatabase.app/messages.json"
    elseif h<20 then return "https://moro-chat-5-default-rtdb.europe-west1.firebasedatabase.app/messages.json"
    else return "https://moro-chat-6-default-rtdb.europe-west1.firebasedatabase.app/messages.json" end
end

function Library:CreateChatWindow()
    local myName  = Players.LocalPlayer.DisplayName
    local myJobId = game.JobId ~= "" and game.JobId or "studio"
    local HISTORY_LIMIT = 15
    
    local gui = Instance.new("ScreenGui")
    gui.Name="MoroChat"; gui.ResetOnSpawn=false
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.IgnoreGuiInset=true
    pcall(function() gui.Parent=game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui") end

    -- TOASTS CONTAINER
    local toastContainer = Instance.new("Frame", gui)
    toastContainer.Size = UDim2.new(0, 300, 1, 0)
    toastContainer.Position = UDim2.new(1, -320, 0, 20)
    toastContainer.BackgroundTransparency = 1
    toastContainer.ZIndex = 10
    local toastLayout = Instance.new("UIListLayout", toastContainer)
    toastLayout.Padding = UDim.new(0, 10)
    toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    toastLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function showToast(sender, text)
        if not settings.toasts then return end

        -- Ширина тоста фиксированная (контейнер 300px, минус паддинги)
        local toastWidth = 300
        local textWidth = toastWidth - 20  -- отступы по 10 с каждой стороны

        -- Считаем высоту текста с учётом переноса
        local textSize = TextService:GetTextSize(text, 13, Enum.Font.GothamMedium, Vector2.new(textWidth, 10000))
        local msgH = math.max(textSize.Y, 20)

        -- Общая высота: title(20) + отступ(8) + текст + нижний паддинг(8)
        local toastH = 8 + 20 + 4 + msgH + 8

        local toast = Instance.new("Frame", toastContainer)
        toast.Size = UDim2.new(1, 0, 0, toastH)
        toast.BackgroundColor3 = theme.panel
        corner(toast, 12)
        stroke(toast, theme.accent, 1, 0.5)
        toast.BackgroundTransparency = 1

        local title = Instance.new("TextLabel", toast)
        title.Size = UDim2.new(1, -20, 0, 20)
        title.Position = UDim2.new(0, 10, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = sender
        title.TextColor3 = theme.accent
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextTransparency = 1

        local msg = Instance.new("TextLabel", toast)
        msg.Size = UDim2.new(1, -20, 0, msgH)
        msg.Position = UDim2.new(0, 10, 0, 30)
        msg.BackgroundTransparency = 1
        msg.Text = text
        msg.TextColor3 = theme.text
        msg.Font = Enum.Font.GothamMedium
        msg.TextSize = 13
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.TextYAlignment = Enum.TextYAlignment.Top
        msg.TextWrapped = true                      -- перенос включён
        msg.TextTruncate = Enum.TextTruncate.None   -- НЕ обрезаем
        msg.TextTransparency = 1

        tw(toast, 0.3, {BackgroundTransparency = 0})
        tw(title, 0.3, {TextTransparency = 0})
        tw(msg, 0.3, {TextTransparency = 0})

        task.delay(4, function()
            tw(toast, 0.3, {BackgroundTransparency = 1})
            tw(title, 0.3, {TextTransparency = 1})
            tw(msg, 0.3, {TextTransparency = 1})
            task.delay(0.3, function() toast:Destroy() end)
        end)
    end

    ------------------------------------------------------------------ BUBBLE
    local bubble = Instance.new("TextButton", gui)
    bubble.Size=UDim2.new(0,settings.bubbleSize,0,settings.bubbleSize); bubble.Position=UDim2.new(0,28,0.5,-settings.bubbleSize/2)
    bubble.BackgroundColor3=theme.bg2; bubble.Text=""; bubble.AutoButtonColor=false
    corner(bubble,settings.bubbleSize/2); stroke(bubble,theme.accent,1.5,0.2); grad(bubble,theme.bg2,theme.bg,90)
    draggable(bubble,bubble)
    
    local bIco = icon(bubble,"message-circle",math.floor(settings.bubbleSize*0.48),theme.accent)
    bIco.AnchorPoint=Vector2.new(0.5,0.5); bIco.Position=UDim2.new(0.5,0,0.5,0)
    
    local badge=Instance.new("Frame",bubble)
    badge.Size=UDim2.new(0,22,0,22); badge.Position=UDim2.new(1,-16,0,-4)
    badge.BackgroundColor3=theme.danger; badge.Visible=false; badge.ZIndex=5
    corner(badge,11); stroke(badge,theme.bg,2)
    local badgeT=Instance.new("TextLabel",badge)
    badgeT.Size=UDim2.new(1,0,1,0); badgeT.BackgroundTransparency=1; badgeT.Text="0"
    badgeT.TextColor3=Color3.new(1,1,1); badgeT.Font=Enum.Font.GothamBold; badgeT.TextSize=12; badgeT.ZIndex=6

    ------------------------------------------------------------------ WINDOW
    local win=Instance.new("Frame",gui)
    win.Size=UDim2.new(0,settings.width,0,settings.height); win.Position=UDim2.new(0.5,-settings.width/2,0.5,-settings.height/2)
    win.BackgroundColor3=theme.bg; win.Visible=false; win.ClipsDescendants=true
    corner(win,18); local winStroke=stroke(win,theme.accent,1,0.5)
    grad(win,theme.bg,theme.bg2,140)
    win.BackgroundTransparency = settings.transparency

    -- HEADER
    local header=Instance.new("Frame",win)
    header.Size=UDim2.new(1,0,0,42); header.BackgroundColor3=theme.bg2; header.ZIndex=2
    header.BorderSizePixel=0
    header.BackgroundTransparency = settings.transparency
    draggable(header,win)
    
    local hIco=icon(header,"message-square",18,theme.accent)
    hIco.Position=UDim2.new(0,14,0,12); hIco.ZIndex=3
    
    local title=Instance.new("TextLabel",header)
    title.Size=UDim2.new(0,180,0,18); title.Position=UDim2.new(0,40,0,12)
    title.BackgroundTransparency=1; title.Text="MORO CHAT"; title.TextColor3=theme.text
    title.Font=Enum.Font.GothamBold; title.TextSize=16; title.TextXAlignment=Enum.TextXAlignment.Left; title.ZIndex=3
    
    local statusDot=Instance.new("Frame",header)
    statusDot.Size=UDim2.new(0,6,0,6); statusDot.Position=UDim2.new(0,42,0,32)
    statusDot.BackgroundColor3=theme.online; corner(statusDot,3); statusDot.ZIndex=3
    
    local status=Instance.new("TextLabel",header)
    status.Size=UDim2.new(0,150,0,12); status.Position=UDim2.new(0,52,0,30)
    status.BackgroundTransparency=1; status.Text="online"; status.TextColor3=theme.online
    status.Font=Enum.Font.GothamMedium; status.TextSize=11; status.TextXAlignment=Enum.TextXAlignment.Left; status.ZIndex=3

    local function headerBtn(iconName, xoff)
        local b=Instance.new("TextButton",header)
        b.Size=UDim2.new(0,30,0,30); b.Position=UDim2.new(1,xoff,0,6)
        b.BackgroundColor3=theme.input; b.Text=""; b.AutoButtonColor=false; b.ZIndex=3
        corner(b,8)
        local i=icon(b,iconName,16,theme.dim); i.AnchorPoint=Vector2.new(0.5,0.5); i.Position=UDim2.new(0.5,0,0.5,0); i.ZIndex=4
        b.MouseEnter:Connect(function() tw(b,0.15,{BackgroundColor3=theme.accent}); tw(i,0.15,{ImageColor3=theme.bg}) end)
        b.MouseLeave:Connect(function() tw(b,0.15,{BackgroundColor3=theme.input}); tw(i,0.15,{ImageColor3=theme.dim}) end)
        return b,i
    end
    local settingsBtn, settingsIco = headerBtn("settings", -74)
    local closeBtn    = headerBtn("x", -38)

    ------------------------------------------------------------------ TABS BAR
    local tabBar=Instance.new("Frame",win)
    tabBar.Size=UDim2.new(1,-20,0,36); tabBar.Position=UDim2.new(0,10,0,48)
    tabBar.BackgroundColor3=theme.bg2; tabBar.ZIndex=2; corner(tabBar,12)
    local currentTab="server"
    local tabIndicator=Instance.new("Frame",tabBar)
    tabIndicator.Size=UDim2.new(0.5,-6,1,-6); tabIndicator.Position=UDim2.new(0,3,0,3)
    tabIndicator.BackgroundColor3=theme.accent; tabIndicator.ZIndex=2; corner(tabIndicator,9)
    grad(tabIndicator,theme.accent,theme.accent2,0)

    local function makeTab(name, txt, iconName, xScale)
        local b=Instance.new("TextButton",tabBar)
        b.Size=UDim2.new(0.5,0,1,0); b.Position=UDim2.new(xScale,0,0,0)
        b.BackgroundTransparency=1; b.Text=""; b.AutoButtonColor=false; b.ZIndex=4
        local i=icon(b,iconName,14, name==currentTab and theme.bg or theme.dim)
        i.AnchorPoint=Vector2.new(0,0.5); i.Position=UDim2.new(0,24,0.5,0); i.ZIndex=5
        local l=Instance.new("TextLabel",b)
        l.Size=UDim2.new(1,-36,1,0); l.Position=UDim2.new(0,42,0,0)
        l.BackgroundTransparency=1; l.Text=txt
        l.TextColor3=name==currentTab and theme.bg or theme.dim
        l.Font=Enum.Font.GothamBold; l.TextSize=12; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=5
        return b,i,l
    end
    local serverBtn, serverIco, serverLbl = makeTab("server","Server","users",0)
    local globalBtn, globalIco, globalLbl = makeTab("global","Global","globe",0.5)

    ------------------------------------------------------------------ CHAT PAGE
    local chatPage=Instance.new("Frame",win)
    chatPage.Size=UDim2.new(1,0,1,-90); chatPage.Position=UDim2.new(0,0,0,90)
    chatPage.BackgroundTransparency=1; chatPage.ZIndex=2

    local function makeChatScroll()
        local sc=Instance.new("ScrollingFrame",chatPage)
        sc.Size=UDim2.new(1,-20,1,-60); sc.Position=UDim2.new(0,10,0,4)
        sc.BackgroundTransparency=1; sc.ScrollBarThickness=3
        sc.ScrollBarImageColor3=theme.accent; sc.CanvasSize=UDim2.new(0,0,0,0); sc.ZIndex=2
        local ll=Instance.new("UIListLayout",sc); ll.Padding=UDim.new(0,8); ll.SortOrder=Enum.SortOrder.LayoutOrder
        pad(sc,0,0,4,20)
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            sc.CanvasSize=UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+24)
        end)
        return sc, ll
    end
    local serverChat, serverList = makeChatScroll()
    local globalChat, globalList = makeChatScroll()
    globalChat.Visible=false

    local inputBar=Instance.new("Frame",chatPage)
    inputBar.Size=UDim2.new(1,-20,0,44); inputBar.Position=UDim2.new(0,10,1,-46)
    inputBar.BackgroundColor3=theme.input; inputBar.ZIndex=2
    corner(inputBar,12); local inStroke=stroke(inputBar,theme.accent,1.5,0.8)

    local box=Instance.new("TextBox",inputBar)
    box.Size=UDim2.new(1,-58,1,0); box.Position=UDim2.new(0,14,0,0)
    box.BackgroundTransparency=1; box.PlaceholderText="Message..."; box.PlaceholderColor3=theme.dim
    box.Text=""; box.TextColor3=theme.text; box.Font=Enum.Font.GothamMedium; box.TextSize=14
    box.TextXAlignment=Enum.TextXAlignment.Left; box.ClearTextOnFocus=false; box.ZIndex=3

    local send=Instance.new("TextButton",inputBar)
    send.Size=UDim2.new(0,36,0,36); send.Position=UDim2.new(1,-40,0,4)
    send.BackgroundColor3=theme.accent; send.Text=""; send.AutoButtonColor=false; send.ZIndex=3
    corner(send,10); grad(send,theme.accent,theme.accent2,45)
    local sIco=icon(send,"send",16,theme.bg); sIco.AnchorPoint=Vector2.new(0.5,0.5); sIco.Position=UDim2.new(0.5,0,0.5,0); sIco.ZIndex=4

    box.Focused:Connect(function() tw(inStroke,0.2,{Transparency=0}) end)
    box.FocusLost:Connect(function() tw(inStroke,0.2,{Transparency=0.8}) end)

    ------------------------------------------------------------------ ADD MESSAGE (FIXED TEXT WRAPPING)
    local function breakLongWords(str, maxLen)
        return str:gsub("(%S+)", function(word)
            if #word > maxLen then
                local broken = ""
                for i = 1, #word, maxLen do
                    broken = broken .. word:sub(i, i + maxLen - 1) .. " "
                end
                return broken:sub(1, -2)
            end
            return word
        end)
    end

    local function addMessage(parentScroll, parentList, sender, text, isMine)
        if #text > 300 then text = text:sub(1, 300) .. "..." end

        -- ДИНАМИЧЕСКАЯ ширина пузыря относительно ширины окна.
        -- Окно: settings.width. Скролл: width - 20 (паддинги chatPage).
        -- Пузырь занимает ~72% доступной ширины, но не меньше 120px.
        local scrollWidth = settings.width - 20
        local bubbleWidth = math.max(120, math.floor(scrollWidth * 0.72))

        -- Ломаем слишком длинные слова под текущую ширину пузыря.
        -- Примерно: сколько символов влезает (ширина пузыря / ~8px на символ).
        local maxWordLen = math.max(10, math.floor((bubbleWidth - 20) / 8))
        text = breakLongWords(text, maxWordLen)

        local holder = Instance.new("Frame", parentScroll)
        holder.BackgroundTransparency = 1; holder.ZIndex = 2

        -- Доступная ширина ТЕКСТА = ширина пузыря - паддинги (по 10)
        local availableWidth = bubbleWidth - 20
        local textSize = TextService:GetTextSize(text, 14, Enum.Font.GothamMedium, Vector2.new(availableWidth, 10000))
        local textH = math.max(textSize.Y, 16)

        -- Высота пузыря = имя(12) + отступ + текст + отступ + время(10) + паддинги
        local bubH = textH + 42

        holder.Size = UDim2.new(1, 0, 0, bubH)
        local bub = Instance.new("Frame", holder)
        bub.Size = UDim2.new(0, bubbleWidth, 0, bubH)
        bub.Position = isMine and UDim2.new(1,0,0,0) or UDim2.new(0,0,0,0)
        bub.AnchorPoint = isMine and Vector2.new(1,0) or Vector2.new(0,0)
        bub.BackgroundColor3 = isMine and theme.accent or theme.panel
        bub.ZIndex = 3; corner(bub, 14)
        if isMine then grad(bub, theme.accent, theme.accent2, 45) end

        local nameLbl = Instance.new("TextLabel", bub)
        nameLbl.Size = UDim2.new(1,-20,0,12); nameLbl.Position = UDim2.new(0,10,0,6)
        nameLbl.BackgroundTransparency = 1; nameLbl.Text = sender
        nameLbl.TextColor3 = isMine and theme.bg or theme.accent
        nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 4
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

        local msgLbl = Instance.new("TextLabel", bub)
        msgLbl.Size = UDim2.new(1,-20,0,textH); msgLbl.Position = UDim2.new(0,10,0,22)
        msgLbl.BackgroundTransparency = 1; msgLbl.Text = text
        msgLbl.TextColor3 = isMine and theme.bg or theme.text
        msgLbl.Font = Enum.Font.GothamMedium; msgLbl.TextSize = 14
        msgLbl.TextXAlignment = Enum.TextXAlignment.Left; msgLbl.TextYAlignment = Enum.TextYAlignment.Top
        msgLbl.TextWrapped = true; msgLbl.TextTruncate = Enum.TextTruncate.None; msgLbl.ZIndex = 4

        local timeLbl = Instance.new("TextLabel", bub)
        timeLbl.Size = UDim2.new(1,-20,0,10); timeLbl.Position = UDim2.new(0,10,1,-14)
        timeLbl.BackgroundTransparency = 1; timeLbl.Text = os.date("%H:%M")
        timeLbl.TextColor3 = isMine and theme.bg or theme.dim
        timeLbl.Font = Enum.Font.GothamMedium; timeLbl.TextSize = 9
        timeLbl.TextXAlignment = Enum.TextXAlignment.Left; timeLbl.ZIndex = 4

        bub.BackgroundTransparency = 1; nameLbl.TextTransparency = 1; msgLbl.TextTransparency = 1; timeLbl.TextTransparency = 1
        tw(bub, 0.3, {BackgroundTransparency = 0})
        tw(nameLbl, 0.3, {TextTransparency = 0})
        tw(msgLbl, 0.3, {TextTransparency = 0})
        tw(timeLbl, 0.3, {TextTransparency = 0.5})

        task.wait()
        parentScroll.CanvasSize = UDim2.new(0, 0, 0, parentList.AbsoluteContentSize.Y + 24)
        tw(parentScroll, 0.3, {CanvasPosition = Vector2.new(0, parentList.AbsoluteContentSize.Y)})
    end

    ------------------------------------------------------------------ SETTINGS PAGE
    local setPage=Instance.new("Frame",win)
    setPage.Size=UDim2.new(1,0,1,-42); setPage.Position=UDim2.new(1,0,0,42)
    setPage.BackgroundTransparency=1; setPage.ZIndex=2; setPage.Visible=false
    local setScroll=Instance.new("ScrollingFrame",setPage)
    setScroll.Size=UDim2.new(1,-24,1,-12); setScroll.Position=UDim2.new(0,12,0,6)
    setScroll.BackgroundTransparency=1; setScroll.ScrollBarThickness=3; setScroll.ScrollBarImageColor3=theme.accent
    setScroll.CanvasSize=UDim2.new(0,0,0,0); setScroll.ZIndex=2
    local setList=Instance.new("UIListLayout",setScroll); setList.Padding=UDim.new(0,10); setList.SortOrder=Enum.SortOrder.LayoutOrder
    setList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        setScroll.CanvasSize=UDim2.new(0,0,0,setList.AbsoluteContentSize.Y+10)
    end)

    local function sectionLabel(txt)
        local l=Instance.new("TextLabel",setScroll)
        l.Size=UDim2.new(1,0,0,20); l.BackgroundTransparency=1; l.Text=txt
        l.TextColor3=theme.dim; l.Font=Enum.Font.GothamBold; l.TextSize=12
        l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=3
        return l
    end

    local listeningFor = nil
    local function keybindRow(labelTxt, iconName, getKey, setKey)
        local row=Instance.new("Frame",setScroll)
        row.Size=UDim2.new(1,0,0,50); row.BackgroundColor3=theme.panel; row.ZIndex=2
        corner(row,12)
        local i=icon(row,iconName,20,theme.accent); i.Position=UDim2.new(0,14,0,15); i.ZIndex=3
        local l=Instance.new("TextLabel",row)
        l.Size=UDim2.new(0.5,-40,1,0); l.Position=UDim2.new(0,44,0,0)
        l.BackgroundTransparency=1; l.Text=labelTxt; l.TextColor3=theme.text
        l.Font=Enum.Font.GothamMedium; l.TextSize=14; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=3
        local btn=Instance.new("TextButton",row)
        btn.Size=UDim2.new(0,110,0,34); btn.Position=UDim2.new(1,-122,0,8)
        btn.BackgroundColor3=theme.input; btn.AutoButtonColor=false; btn.ZIndex=3
        btn.Text=getKey().Name; btn.TextColor3=theme.accent
        btn.Font=Enum.Font.GothamBold; btn.TextSize=13
        corner(btn,8); stroke(btn,theme.accent,1,0.6)
        btn.MouseButton1Click:Connect(function()
            listeningFor = { button = btn, setKey = function(k) setKey(k); saveConfig() end }
            btn.Text = "[ wait... ]"; btn.TextColor3 = theme.dim
        end)
        return row
    end

    local function toggleRow(labelTxt, iconName, getVal, setVal)
        local row=Instance.new("Frame",setScroll)
        row.Size=UDim2.new(1,0,0,50); row.BackgroundColor3=theme.panel; row.ZIndex=2
        corner(row,12)
        local i=icon(row,iconName,20,theme.accent); i.Position=UDim2.new(0,14,0,15); i.ZIndex=3
        local l=Instance.new("TextLabel",row)
        l.Size=UDim2.new(0.6,0,1,0); l.Position=UDim2.new(0,44,0,0)
        l.BackgroundTransparency=1; l.Text=labelTxt; l.TextColor3=theme.text
        l.Font=Enum.Font.GothamMedium; l.TextSize=14; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=3
        local sw=Instance.new("TextButton",row)
        sw.Size=UDim2.new(0,48,0,26); sw.Position=UDim2.new(1,-62,0,12)
        sw.BackgroundColor3=getVal() and theme.accent or theme.input
        sw.Text=""; sw.AutoButtonColor=false; sw.ZIndex=3; corner(sw,13)
        local knob=Instance.new("Frame",sw)
        knob.Size=UDim2.new(0,20,0,20); knob.Position=getVal() and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)
        knob.BackgroundColor3=Color3.new(1,1,1); knob.ZIndex=4; corner(knob,10)
        sw.MouseButton1Click:Connect(function()
            local v=not getVal(); setVal(v); saveConfig()
            tw(sw,0.2,{BackgroundColor3=v and theme.accent or theme.input})
            tw(knob,0.2,{Position=v and UDim2.new(1,-23,0.5,-10) or UDim2.new(0,3,0.5,-10)})
        end)
        return row
    end

    local function sliderRow(labelTxt, iconName, minV, maxV, getVal, setVal, suffix)
        local row=Instance.new("Frame",setScroll)
        row.Size=UDim2.new(1,0,0,64); row.BackgroundColor3=theme.panel; row.ZIndex=2
        corner(row,12)
        local i=icon(row,iconName,20,theme.accent); i.Position=UDim2.new(0,14,0,12); i.ZIndex=3
        local l=Instance.new("TextLabel",row)
        l.Size=UDim2.new(0.6,0,0,20); l.Position=UDim2.new(0,44,0,8)
        l.BackgroundTransparency=1; l.Text=labelTxt; l.TextColor3=theme.text
        l.Font=Enum.Font.GothamMedium; l.TextSize=14; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=3
        local valLbl=Instance.new("TextLabel",row)
        valLbl.Size=UDim2.new(0,80,0,20); valLbl.Position=UDim2.new(1,-90,0,8)
        valLbl.BackgroundTransparency=1; valLbl.TextColor3=theme.accent
        valLbl.Font=Enum.Font.GothamBold; valLbl.TextSize=13; valLbl.TextXAlignment=Enum.TextXAlignment.Right; valLbl.ZIndex=3
        local track=Instance.new("Frame",row)
        track.Size=UDim2.new(1,-28,0,6); track.Position=UDim2.new(0,14,1,-18)
        track.BackgroundColor3=theme.input; track.ZIndex=3; corner(track,3)
        local fill=Instance.new("Frame",track)
        fill.BackgroundColor3=theme.accent; fill.ZIndex=4; corner(fill,3)
        grad(fill,theme.accent,theme.accent2,0)
        local knob=Instance.new("Frame",track)
        knob.Size=UDim2.new(0,14,0,14); knob.AnchorPoint=Vector2.new(0.5,0.5)
        knob.BackgroundColor3=Color3.new(1,1,1); knob.ZIndex=5; corner(knob,7)
        local function refresh(v)
            local a=math.clamp((v-minV)/(maxV-minV),0,1)
            fill.Size=UDim2.new(a,0,1,0); knob.Position=UDim2.new(a,0,0.5,0)
            valLbl.Text=tostring(math.floor(v))..(suffix or "")
        end
        refresh(getVal())
        local dragging=false
        local function moveTo(px)
            local rel=math.clamp((px-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local v=math.floor(minV+(maxV-minV)*rel+0.5)
            refresh(v); setVal(v); saveConfig()
        end
        track.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                dragging=true; moveTo(inp.Position.X)
            end
        end)
        track.InputEnded:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
                moveTo(inp.Position.X)
            end
        end)
        return row
    end
    
    local function buttonRow(labelTxt, iconName, btnText, onClick, danger)
        local row=Instance.new("Frame",setScroll)
        row.Size=UDim2.new(1,0,0,50); row.BackgroundColor3=theme.panel; row.ZIndex=2
        corner(row,12)
        local i=icon(row,iconName,20,danger and theme.danger or theme.accent); i.Position=UDim2.new(0,14,0,15); i.ZIndex=3
        local l=Instance.new("TextLabel",row)
        l.Size=UDim2.new(0.5,-40,1,0); l.Position=UDim2.new(0,44,0,0)
        l.BackgroundTransparency=1; l.Text=labelTxt; l.TextColor3=theme.text
        l.Font=Enum.Font.GothamMedium; l.TextSize=14; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=3
        local btn=Instance.new("TextButton",row)
        btn.Size=UDim2.new(0,110,0,34); btn.Position=UDim2.new(1,-122,0,8)
        btn.BackgroundColor3=theme.input; btn.AutoButtonColor=false; btn.ZIndex=3
        btn.Text=btnText; btn.TextColor3=danger and theme.danger or theme.accent
        btn.Font=Enum.Font.GothamBold; btn.TextSize=13
        corner(btn,8); stroke(btn,danger and theme.danger or theme.accent,1,0.6)
        btn.MouseButton1Click:Connect(onClick)
        return row, btn
    end

    local function applyTheme(name)
        if not themes[name] then return end
        settings.theme = name
        theme = themes[name]
        win.BackgroundColor3 = theme.bg
        header.BackgroundColor3 = theme.bg2
        bubble.BackgroundColor3 = theme.bg2
        tabBar.BackgroundColor3 = theme.bg2
        inputBar.BackgroundColor3 = theme.input
        setPage.BackgroundColor3 = theme.bg
        winStroke.Color = theme.accent
        send.BackgroundColor3 = theme.accent
        
        local g1 = win:FindFirstChildOfClass("UIGradient")
        if g1 then g1.Color = ColorSequence.new(theme.bg, theme.bg2) end
        local g2 = bubble:FindFirstChildOfClass("UIGradient")
        if g2 then g2.Color = ColorSequence.new(theme.bg2, theme.bg) end
        local g3 = tabIndicator:FindFirstChildOfClass("UIGradient")
        if g3 then g3.Color = ColorSequence.new(theme.accent, theme.accent2) end
        local g4 = send:FindFirstChildOfClass("UIGradient")
        if g4 then g4.Color = ColorSequence.new(theme.accent, theme.accent2) end
        
        saveConfig()
    end

    ------------------------------------------------------------------ SETTINGS CONTENT (ENGLISH)
    sectionLabel("KEYBINDS")
    keybindRow("Toggle Chat","keyboard",function() return settings.openKey end,function(k) settings.openKey=k end)
    keybindRow("Quick Type","message-square-plus",function() return settings.typeKey end,function(k) settings.typeKey=k end)
    
    sectionLabel("GENERAL")
    toggleRow("Load History","history",function() return settings.showHistory end,function(v) settings.showHistory=v end)
    toggleRow("Badge Notifications","bell",function() return settings.notifications end,function(v) settings.notifications=v end)
    toggleRow("Toast Popups","layout-grid",function() return settings.toasts end,function(v) settings.toasts=v end)
    toggleRow("Notification Sound","volume-2",function() return settings.sound end,function(v) settings.sound=v end)
    
    -- Sound selector row
    local soundRow, soundBtn = buttonRow("Sound Type","music",soundPresets[settings.soundIndex or 1].name,function()
        local idx = settings.soundIndex or 1
        idx = (idx % #soundPresets) + 1
        settings.soundIndex = idx
        soundBtn.Text = soundPresets[idx].name
        saveConfig()
        -- Preview the selected sound
        if settings.sound then playNotifSound() end
    end)
    
    sectionLabel("APPEARANCE")
    local themeRow, themeBtn = buttonRow("UI Theme","palette",settings.theme,function()
        local idx = 1
        for i, n in ipairs(themeNames) do if n == settings.theme then idx = i break end end
        local nextName = themeNames[(idx % #themeNames) + 1]
        applyTheme(nextName)
        themeBtn.Text = nextName
    end)
    
    sliderRow("Transparency","eye",0,80,
    function() return settings.transparency*100 end,
    function(v)
        settings.transparency=v/100
        win.BackgroundTransparency=settings.transparency
        header.BackgroundTransparency=settings.transparency
    end,"%")
    
    sliderRow("Window Width","move-horizontal",100,650,
    function() return settings.width end,
    function(v) settings.width=v; win.Size=UDim2.new(0,settings.width,0,settings.height) end,"px")
    
    sliderRow("Window Height","move-vertical",100,650,
    function() return settings.height end,
    function(v) settings.height=v; win.Size=UDim2.new(0,settings.width,0,settings.height) end,"px")
    
    sliderRow("Bubble Size","circle",30,80,
    function() return settings.bubbleSize end,
    function(v) 
        settings.bubbleSize=v
        bubble.Size=UDim2.new(0,v,0,v)
        corner(bubble,v/2)
        bIco.Size=UDim2.new(0,math.floor(v*0.48),0,math.floor(v*0.48))
    end,"px")

    sectionLabel("INFO")
    do
        local info=Instance.new("TextLabel",setScroll)
        info.Size=UDim2.new(1,0,0,60); info.BackgroundColor3=theme.panel; info.ZIndex=2
        info.Text="  MORO CHAT v3.0\n  User: "..myName; info.TextColor3=theme.dim
        info.Font=Enum.Font.GothamMedium; info.TextSize=13; info.TextXAlignment=Enum.TextXAlignment.Left
        info.TextYAlignment=Enum.TextYAlignment.Center; corner(info,12)
    end
    
    sectionLabel("DANGER ZONE")
    buttonRow("Unload Script","trash-2","UNLOAD",function()
        gui:Destroy()
        pcall(function() notifSound:Destroy() end)
    end, true)

    ------------------------------------------------------------------ TAB SWITCH
    local function switchTab(name)
        if currentTab==name then return end
        currentTab=name
        local isServer=(name=="server")
        serverChat.Visible=isServer
        globalChat.Visible=not isServer
        tw(tabIndicator,0.25,{Position=isServer and UDim2.new(0,3,0,3) or UDim2.new(0.5,3,0,3)})
        tw(serverIco,0.2,{ImageColor3=isServer and theme.bg or theme.dim})
        tw(serverLbl,0.2,{TextColor3=isServer and theme.bg or theme.dim})
        tw(globalIco,0.2,{ImageColor3=isServer and theme.dim or theme.bg})
        tw(globalLbl,0.2,{TextColor3=isServer and theme.dim or theme.bg})
    end
    serverBtn.MouseButton1Click:Connect(function() switchTab("server") end)
    globalBtn.MouseButton1Click:Connect(function() switchTab("global") end)

    ------------------------------------------------------------------ PAGE SWITCH
    local onSettings=false
    local function showSettings(v)
        onSettings=v
        if v then
            setPage.Visible=true
            tw(chatPage,0.3,{Position=UDim2.new(-1,0,0,90)})
            tw(tabBar,0.3,{Position=UDim2.new(-1,10,0,48)})
            tw(setPage,0.3,{Position=UDim2.new(0,0,0,42)})
            tw(settingsIco,0.3,{Rotation=180})
        else
            chatPage.Visible=true; tabBar.Visible=true
            tw(chatPage,0.3,{Position=UDim2.new(0,0,0,90)})
            tw(tabBar,0.3,{Position=UDim2.new(0,10,0,48)})
            tw(setPage,0.3,{Position=UDim2.new(1,0,0,42)})
            tw(settingsIco,0.3,{Rotation=0})
            task.delay(0.3,function() if onSettings==false then setPage.Visible=false end end)
        end
    end
    settingsBtn.MouseButton1Click:Connect(function() showSettings(not onSettings) end)

    ------------------------------------------------------------------ OPEN/CLOSE
    local unread, isOpen = 0, false
    local function toggle()
        isOpen = not isOpen
        if isOpen then
            win.Visible = true
            win.Size = UDim2.new(0, settings.width, 0, 0)
            tw(win, 0.35, {Size = UDim2.new(0, settings.width, 0, settings.height)}, Enum.EasingStyle.Back)
            unread = 0; badge.Visible = false; badgeT.Text = "0"
            if onSettings then showSettings(false) end
        else
            tw(win, 0.25, {Size = UDim2.new(0, settings.width, 0, 0)})
            task.delay(0.25, function() if not isOpen then win.Visible = false end end)
            pcall(function() UserInputService:ReleaseFocus() end)
            if box:IsFocused() then box:ReleaseFocus() end
        end
    end
    closeBtn.MouseButton1Click:Connect(toggle)
    send.MouseEnter:Connect(function() tw(send, 0.15, {Size = UDim2.new(0,38,0,38), Position = UDim2.new(1,-41,0,3)}) end)
    send.MouseLeave:Connect(function() tw(send, 0.15, {Size = UDim2.new(0,36,0,36), Position = UDim2.new(1,-40,0,4)}) end)

    ------------------------------------------------------------------ SEND / RECEIVE
    local seenServer, seenGlobal = {}, {}
    local firstLoad = true
    local lastSendTime = 0
    local lastSeenTs = 0        -- timestamp of the newest message we've seen
    local MAX_RENDERED = 50     -- max bubbles per chat scroll before pruning old ones
    local POLL_NORMAL = 2       -- normal poll interval (seconds)
    local POLL_IDLE = 5         -- idle poll interval (seconds)
    local POLL_ERROR_MAX = 10   -- max backoff on errors (seconds)
    local emptyPolls = 0        -- counter for consecutive empty polls
    local errorStreak = 0       -- counter for consecutive errors
    local serverMsgCount = 0    -- rendered bubble count in server chat
    local globalMsgCount = 0    -- rendered bubble count in global chat

    -- Build Firebase REST URL with query params to fetch only what we need
    local function buildQueryUrl()
        local base = getDB()
        if firstLoad then
            -- First load: get only the last HISTORY_LIMIT messages (sorted by ts)
            local limit = settings.showHistory and HISTORY_LIMIT or 1
            return base .. '?orderBy="ts"&limitToLast=' .. tostring(limit)
        else
            -- Subsequent polls: get only messages newer than lastSeenTs
            return base .. '?orderBy="ts"&startAt=' .. tostring(lastSeenTs + 1) .. '&limitToLast=50'
        end
    end

    -- Prune old bubbles from a scroll when over the limit
    local function pruneChat(scroll, layout, count)
        if count <= MAX_RENDERED then return count end
        local toRemove = count - MAX_RENDERED
        local children = scroll:GetChildren()
        local removed = 0
        for _, child in ipairs(children) do
            if child:IsA("Frame") and not child:IsA("UIListLayout") and child.ClassName ~= "UIPadding" then
                child:Destroy()
                removed = removed + 1
                if removed >= toRemove then break end
            end
        end
        return count - removed
    end

    local function onSend()
        if tick() - lastSendTime < 1 then return end
        local msg = box.Text
        if msg:gsub("%s","") == "" then return end
        box.Text = ""
        lastSendTime = tick()
        
        -- Reset idle counter on user activity
        emptyPolls = 0
        
        local data = {
            s = myName, t = msg, j = myJobId,
            scope = currentTab,
            ts = os.time()*1000 + math.random(0,999)
        }
        task.spawn(function()
            pcall(function()
                request({
                    Url = getDB(), Method = "POST",
                    Headers = {["Content-Type"]="application/json"},
                    Body = HttpService:JSONEncode(data)
                })
            end)
        end)
    end
    send.MouseButton1Click:Connect(onSend)
    box.FocusLost:Connect(function(enter) if enter then onSend() end end)

    local function loop()
        while true do
            -- Adaptive poll interval
            local interval = POLL_NORMAL
            if errorStreak > 0 then
                interval = math.min(POLL_NORMAL * (2 ^ errorStreak), POLL_ERROR_MAX)
            elseif emptyPolls >= 10 then
                interval = POLL_IDLE
            end
            task.wait(interval)
            
            if not gui or not gui.Parent then break end
            
            local queryUrl = buildQueryUrl()
            local ok, resp = pcall(function()
                return request({ Url = queryUrl, Method = "GET" })
            end)
            
            if not ok or not resp or resp.StatusCode ~= 200 then
                errorStreak = math.min(errorStreak + 1, 5)
                continue
            end
            errorStreak = 0 -- reset on success
            
            if not resp.Body or resp.Body == "null" then
                emptyPolls = emptyPolls + 1
                if firstLoad then firstLoad = false end
                continue
            end
            
            local success, data = pcall(function() return HttpService:JSONDecode(resp.Body) end)
            if not success or type(data) ~= "table" then
                emptyPolls = emptyPolls + 1
                if firstLoad then firstLoad = false end
                continue
            end
            
            -- Collect and sort only the new messages
            local newMessages = {}
            for id, m in pairs(data) do
                if type(m) == "table" and m.t then
                    m._id = id
                    table.insert(newMessages, m)
                end
            end
            
            if #newMessages == 0 then
                emptyPolls = emptyPolls + 1
                if firstLoad then firstLoad = false end
                continue
            end
            
            -- Got new data — reset idle counter
            emptyPolls = 0
            
            table.sort(newMessages, function(a, b) return (a.ts or 0) < (b.ts or 0) end)
            
            -- Track the highest ts for next startAt query
            local maxTs = lastSeenTs
            
            for _, m in ipairs(newMessages) do
                local ts = m.ts or 0
                if ts > maxTs then maxTs = ts end
                
                local scope = m.scope or "global"
                local isMine = (m.s == myName)
                local isNew = false
                
                if scope == "server" and m.j == myJobId then
                    if not seenServer[m._id] then
                        seenServer[m._id] = true
                        isNew = true
                        addMessage(serverChat, serverList, m.s or "?", m.t or "", isMine)
                        serverMsgCount = serverMsgCount + 1
                        serverMsgCount = pruneChat(serverChat, serverList, serverMsgCount)
                    end
                elseif scope == "global" then
                    if not seenGlobal[m._id] then
                        seenGlobal[m._id] = true
                        isNew = true
                        addMessage(globalChat, globalList, m.s or "?", m.t or "", isMine)
                        globalMsgCount = globalMsgCount + 1
                        globalMsgCount = pruneChat(globalChat, globalList, globalMsgCount)
                    end
                end
                
                -- Unified notification logic for BOTH server and global messages
                if isNew and not firstLoad and not isMine then
                    local msgOnVisibleTab = (scope == currentTab)
                    local shouldNotify = (not isOpen) or (not msgOnVisibleTab)
                    
                    if shouldNotify then
                        if settings.toasts then showToast(m.s or "?", m.t or "") end
                        if settings.sound then playNotifSound() end
                        
                        if settings.notifications then
                            unread = unread + 1; badge.Visible = true
                            badgeT.Text = unread > 99 and "99+" or tostring(unread)
                            tw(bubble, 0.12, {Size = UDim2.new(0, settings.bubbleSize + 6, 0, settings.bubbleSize + 6)})
                            task.delay(0.12, function() tw(bubble, 0.12, {Size = UDim2.new(0, settings.bubbleSize, 0, settings.bubbleSize)}) end)
                        end
                    end
                end
            end
            
            lastSeenTs = maxTs
            firstLoad = false
        end
    end
    task.spawn(loop)

    ------------------------------------------------------------------ KEYBINDS
    bubble.MouseButton1Click:Connect(toggle)
    UserInputService.InputBegan:Connect(function(input, gpe)
        if listeningFor and input.UserInputType == Enum.UserInputType.Keyboard then
            local key = input.KeyCode
            listeningFor.setKey(key)
            listeningFor.button.Text = key.Name
            listeningFor.button.TextColor3 = theme.accent
            listeningFor = nil
            return
        end
        if gpe then return end
        if input.KeyCode == settings.openKey then
            if box:IsFocused() then box:ReleaseFocus() end
            toggle()
        elseif input.KeyCode == settings.typeKey then
            if not isOpen then toggle() end
            if onSettings then showSettings(false) end
            task.wait(0.05)
            box:CaptureFocus()
        end
    end)

    ------------------------------------------------------------------ HOVER BUBBLE
    bubble.MouseEnter:Connect(function() tw(bubble, 0.15, {Size = UDim2.new(0,settings.bubbleSize+4,0,settings.bubbleSize+4)}) end)
    bubble.MouseLeave:Connect(function() if not isOpen then tw(bubble, 0.15, {Size = UDim2.new(0,settings.bubbleSize,0,settings.bubbleSize)}) end end)
end

Library:CreateChatWindow()
