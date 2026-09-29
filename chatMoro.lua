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
    { name = "Litvin",      id = nil, file = "Litvin.mp3",  url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/Litvin.mp3" },
    { name = "Payment",     id = nil, file = "payment.mp3", url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/payment.mp3" },
    { name = "Soft",        id = nil, file = "soft.mp3",    url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/soft.mp3" },
    { name = "Tuntun",      id = nil, file = "tuntun.mp3",  url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/tuntun.mp3" },
    { name = "Vibe",        id = nil, file = "vibe.mp3",    url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/Sounds/vibe.mp3" },
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
    toastSize = 320,
    muted = {},
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
    if not settings.toastSize then settings.toastSize = defaultSettings.toastSize end
    if type(settings.muted) ~= "table" then settings.muted = {} end
end

local function saveConfig()
    local toSave = cloneTable(settings)
    toSave.openKey = settings.openKey.Name
    toSave.typeKey = settings.typeKey.Name
    toSave.muted = settings.muted or {}
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(toSave)) end)
end

loadConfig()
local theme = themes[settings.theme] or themes.default

--// HELPERS
local function corner(o, r) local c=Instance.new("UICorner",o); c.CornerRadius=UDim.new(0,r); return c end
local function stroke(o,col,th,tr) local s=Instance.new("UIStroke",o); s.Color=col; s.Thickness=th or 1; s.Transparency=tr or 0; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s end
local function grad(o,c1,c2,rot) local g=Instance.new("UIGradient",o); g.Color=ColorSequence.new(c1,c2); g.Rotation=rot or 0; return g end
local function pad(o,l,r,t,b) local p=Instance.new("UIPadding",o); p.PaddingLeft=UDim.new(0,l or 0); p.PaddingRight=UDim.new(0,r or 0); p.PaddingTop=UDim.new(0,t or 0); p.PaddingBottom=UDim.new(0,b or 0); return p end
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

    -- TOASTS CONTAINER (CENTER TOP)
    local toastContainer = Instance.new("Frame", gui)
    toastContainer.AnchorPoint = Vector2.new(0.5, 0)
    toastContainer.Position = UDim2.new(0.5, 0, 0, 16)
    toastContainer.Size = UDim2.new(0, settings.toastSize or 320, 1, -20)
    toastContainer.BackgroundTransparency = 1
    toastContainer.ClipsDescendants = false
    toastContainer.Active = false
    toastContainer.ZIndex = 10
    local toastLayout = Instance.new("UIListLayout", toastContainer)
    toastLayout.Padding = UDim.new(0, 8)
    toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    toastLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local toastOrder = 0

    local function showToast(sender, text)
        if not settings.toasts then return end

        sender = tostring(sender or "?")
        if settings.muted and settings.muted[sender] then return end
        text = tostring(text or "")
        if #text > 240 then text = text:sub(1, 240) .. "..." end

        local currentWidth = settings.toastSize or 320
        local textWidth = math.max(currentWidth - 28, 80)
        local maxWordLen = math.max(10, math.floor(textWidth / 8))
        local formattedText = breakLongWords(text, maxWordLen)

        -- Считаем высоту текста с учётом переноса
        local textSize = TextService:GetTextSize(formattedText, 13, Enum.Font.GothamMedium, Vector2.new(textWidth, 10000))
        local msgH = math.max(textSize.Y, 18)

        -- Общая высота: отступ(8) + title(20) + отступ(4) + msgH + отступ(8)
        local toastH = 8 + 20 + 4 + msgH + 8

        toastOrder = toastOrder - 1

        local slot = Instance.new("Frame", toastContainer)
        slot.Size = UDim2.new(1, 0, 0, 0)
        slot.BackgroundTransparency = 1
        slot.ClipsDescendants = false
        slot.LayoutOrder = toastOrder
        slot.ZIndex = 10

        local toast = Instance.new("Frame", slot)
        toast.Size = UDim2.new(1, 0, 0, toastH)
        toast.Position = UDim2.new(0, 0, 0, -toastH - 50)
        toast.BackgroundColor3 = theme.panel
        toast.BackgroundTransparency = 1
        toast.Active = true
        toast.ZIndex = 10
        corner(toast, 12)
        local toastStroke = stroke(toast, theme.accent, 1, 1)

        local title = Instance.new("TextLabel", toast)
        title.Size = UDim2.new(1, -24, 0, 20)
        title.Position = UDim2.new(0, 12, 0, 8)
        title.BackgroundTransparency = 1
        title.Text = sender
        title.TextColor3 = theme.accent
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextTransparency = 1
        title.Active = false
        title.ZIndex = 11

        local msg = Instance.new("TextLabel", toast)
        msg.Size = UDim2.new(1, -24, 0, msgH)
        msg.Position = UDim2.new(0, 12, 0, 32)
        msg.BackgroundTransparency = 1
        msg.Text = formattedText
        msg.TextColor3 = theme.text
        msg.Font = Enum.Font.GothamMedium
        msg.TextSize = 13
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.TextYAlignment = Enum.TextYAlignment.Top
        msg.TextWrapped = true
        msg.TextTruncate = Enum.TextTruncate.None
        msg.TextTransparency = 1
        msg.Active = false
        msg.ZIndex = 11

        local isDismissed = false
        local dismissCounter = 0
        local connChanged = nil
        local connEnded = nil

        local function cleanupConnections()
            if connChanged then connChanged:Disconnect(); connChanged = nil end
            if connEnded then connEnded:Disconnect(); connEnded = nil end
        end

        local function dismiss(flyDirection)
            if isDismissed then return end
            isDismissed = true
            dismissCounter = dismissCounter + 1
            cleanupConnections()

            local targetPos
            if flyDirection == "left" then
                targetPos = UDim2.new(0, -currentWidth - 100, 0, toast.Position.Y.Offset)
            elseif flyDirection == "right" then
                targetPos = UDim2.new(0, currentWidth + 100, 0, toast.Position.Y.Offset)
            else
                -- "up" (плавный уезд наверх)
                targetPos = UDim2.new(0, toast.Position.X.Offset, 0, -toastH - 50)
            end

            tw(toast, 0.35, {Position = targetPos, BackgroundTransparency = 1}, Enum.EasingStyle.Quart)
            tw(toastStroke, 0.3, {Transparency = 1})
            tw(title, 0.25, {TextTransparency = 1})
            tw(msg, 0.25, {TextTransparency = 1})

            task.delay(0.12, function()
                if slot and slot.Parent then
                    tw(slot, 0.28, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quart)
                end
            end)

            task.delay(0.42, function()
                if slot and slot.Parent then
                    slot:Destroy()
                end
            end)
        end

        -- Плавное появление: слот расширяется, тост выезжает сверху
        tw(slot, 0.35, {Size = UDim2.new(1, 0, 0, toastH)}, Enum.EasingStyle.Quart)
        tw(toast, 0.45, {Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0}, Enum.EasingStyle.Quart)
        tw(toastStroke, 0.4, {Transparency = 0.5})
        tw(title, 0.4, {TextTransparency = 0})
        tw(msg, 0.4, {TextTransparency = 0})

        -- Авто-закрытие через 4.5 секунды
        local thisDismissId = dismissCounter
        task.delay(4.5, function()
            if not isDismissed and dismissCounter == thisDismissId then
                dismiss("up")
            end
        end)

        -- Смахивание (swipe-to-dismiss как на телефоне)
        local dragging = false
        local startInputPos = nil
        local activeInput = nil

        local function endDrag()
            if not dragging then return end
            dragging = false
            activeInput = nil
            cleanupConnections()

            if isDismissed then return end

            local dX = toast.Position.X.Offset
            local dY = toast.Position.Y.Offset

            if dY < -20 then
                dismiss("up")
            elseif dX < -50 then
                dismiss("left")
            elseif dX > 50 then
                dismiss("right")
            else
                -- Возвращаем на исходную позицию
                tw(toast, 0.25, {Position = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Quart)
                dismissCounter = dismissCounter + 1
                local resumeId = dismissCounter
                task.delay(3.5, function()
                    if not isDismissed and dismissCounter == resumeId then
                        dismiss("up")
                    end
                end)
            end
        end

        toast.InputBegan:Connect(function(inp)
            if isDismissed then return end
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                activeInput = inp
                startInputPos = inp.Position
                dismissCounter = dismissCounter + 1 -- приостанавливаем таймер при касании

                cleanupConnections()

                connChanged = UserInputService.InputChanged:Connect(function(moveInp)
                    if not dragging or isDismissed then return end
                    local isTouch = (activeInput and activeInput.UserInputType == Enum.UserInputType.Touch and moveInp == activeInput)
                    local isMouse = (activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1 and moveInp.UserInputType == Enum.UserInputType.MouseMovement)
                    if isTouch or isMouse then
                        local delta = moveInp.Position - startInputPos
                        local clampY = math.min(delta.Y, 20)
                        toast.Position = UDim2.new(0, delta.X, 0, clampY)
                    end
                end)

                connEnded = UserInputService.InputEnded:Connect(function(endInp)
                    local isTouchEnd = (activeInput and activeInput.UserInputType == Enum.UserInputType.Touch and endInp == activeInput)
                    local isMouseEnd = (activeInput and activeInput.UserInputType == Enum.UserInputType.MouseButton1 and endInp.UserInputType == Enum.UserInputType.MouseButton1)
                    if isTouchEnd or isMouseEnd then
                        endDrag()
                    end
                end)
            end
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
    inputBar.ClipsDescendants=true
    corner(inputBar,12); local inStroke=stroke(inputBar,theme.accent,1.5,0.8)

    local box=Instance.new("TextBox",inputBar)
    box.Size=UDim2.new(1,-58,1,-14); box.Position=UDim2.new(0,14,0,8)
    box.BackgroundTransparency=1; box.PlaceholderText="Message..."; box.PlaceholderColor3=theme.dim
    box.Text=""; box.TextColor3=theme.text; box.Font=Enum.Font.GothamMedium; box.TextSize=14
    box.TextXAlignment=Enum.TextXAlignment.Left; box.TextYAlignment=Enum.TextYAlignment.Top
    box.TextWrapped=true; box.MultiLine=true; box.ClearTextOnFocus=false; box.ClipsDescendants=true; box.ZIndex=3

    local send=Instance.new("TextButton",inputBar)
    send.Size=UDim2.new(0,34,0,34)
    send.AnchorPoint=Vector2.new(1,1)
    send.Position=UDim2.new(1,-5,1,-5)
    send.BackgroundColor3=theme.accent; send.Text=""; send.AutoButtonColor=false; send.ZIndex=3
    corner(send,10); grad(send,theme.accent,theme.accent2,45)
    local sIco=icon(send,"send",16,theme.bg); sIco.AnchorPoint=Vector2.new(0.5,0.5); sIco.Position=UDim2.new(0.5,0,0.5,0); sIco.ZIndex=4

    local function updateInputHeight()
        local text = box.Text
        local availWidth = box.AbsoluteSize.X
        if availWidth <= 0 then
            availWidth = math.max(100, (settings.width or 380) - 20 - 58 - 14)
        end
        local textH = 16
        if text and text ~= "" then
            local textSize = TextService:GetTextSize(text, 14, Enum.Font.GothamMedium, Vector2.new(availWidth, 1000))
            textH = math.max(16, textSize.Y)
        end
        local barH = math.clamp(textH + 20, 44, 104)
        inputBar.Size = UDim2.new(1, -20, 0, barH)
        inputBar.Position = UDim2.new(0, 10, 1, -(barH + 2))
        serverChat.Size = UDim2.new(1, -20, 1, -(barH + 16))
        globalChat.Size = UDim2.new(1, -20, 1, -(barH + 16))
    end

    box:GetPropertyChangedSignal("Text"):Connect(updateInputHeight)
    box:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateInputHeight)

    box.Focused:Connect(function() tw(inStroke,0.2,{Transparency=0}) end)
    box.FocusLost:Connect(function() tw(inStroke,0.2,{Transparency=0.8}) end)

    ------------------------------------------------------------------ ADD MESSAGE (FIXED TEXT WRAPPING)
    local muteUpdaters = {}

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

        local hasMute = (not isMine) and (sender and sender ~= "" and sender ~= "?" and sender ~= myName)

        local nameLbl = Instance.new("TextLabel", bub)
        nameLbl.Size = hasMute and UDim2.new(1,-42,0,12) or UDim2.new(1,-20,0,12)
        nameLbl.Position = UDim2.new(0,10,0,6)
        nameLbl.BackgroundTransparency = 1; nameLbl.Text = sender
        nameLbl.TextColor3 = isMine and theme.bg or theme.accent
        nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 4
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

        if hasMute then
            local muteBtn = Instance.new("TextButton", bub)
            muteBtn.Size = UDim2.new(0, 18, 0, 18)
            muteBtn.Position = UDim2.new(1, -24, 0, 3)
            muteBtn.BackgroundTransparency = 1
            muteBtn.AutoButtonColor = false
            muteBtn.Text = ""
            muteBtn.ZIndex = 5

            local muteIco = icon(muteBtn, "volume-x", 13, theme.dim)
            muteIco.AnchorPoint = Vector2.new(0.5, 0.5)
            muteIco.Position = UDim2.new(0.5, 0, 0.5, 0)
            muteIco.ZIndex = 6

            local function refreshMuteVisual()
                if not muteIco or not muteIco.Parent then return end
                local isMuted = settings.muted and settings.muted[sender]
                if isMuted then
                    muteIco.ImageColor3 = theme.danger
                    muteIco.ImageTransparency = 0
                else
                    muteIco.ImageColor3 = theme.dim
                    muteIco.ImageTransparency = 0.55
                end
            end
            refreshMuteVisual()

            muteBtn.MouseEnter:Connect(function()
                local isMuted = settings.muted and settings.muted[sender]
                if not isMuted then
                    tw(muteIco, 0.15, {ImageTransparency = 0, ImageColor3 = theme.accent})
                end
            end)
            muteBtn.MouseLeave:Connect(function()
                refreshMuteVisual()
            end)

            muteBtn.MouseButton1Click:Connect(function()
                if not settings.muted then settings.muted = {} end
                local isMuted = not settings.muted[sender]
                if isMuted then
                    settings.muted[sender] = true
                else
                    settings.muted[sender] = nil
                end
                saveConfig()
                for _, updater in ipairs(muteUpdaters) do
                    pcall(updater)
                end
            end)

            table.insert(muteUpdaters, refreshMuteVisual)
            muteBtn.AncestryChanged:Connect(function(_, parent)
                if not parent then
                    for idx, fn in ipairs(muteUpdaters) do
                        if fn == refreshMuteVisual then
                            table.remove(muteUpdaters, idx)
                            break
                        end
                    end
                end
            end)
        end

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

    local themeListeners = {}
    table.insert(themeListeners, function()
        for _, fn in ipairs(muteUpdaters) do pcall(fn) end
    end)
    local activeDropdownCloser = nil

    local function dropdownRow(labelTxt, iconName, getVal, items, onSelect)
        local row = Instance.new("Frame", setScroll)
        row.Size = UDim2.new(1, 0, 0, 50)
        row.BackgroundColor3 = theme.panel
        row.ZIndex = 2
        row.ClipsDescendants = true
        corner(row, 12)

        local ico = icon(row, iconName, 20, theme.accent)
        ico.Position = UDim2.new(0, 14, 0, 15)
        ico.ZIndex = 3

        local l = Instance.new("TextLabel", row)
        l.Size = UDim2.new(0.5, -40, 0, 50)
        l.Position = UDim2.new(0, 44, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = labelTxt
        l.TextColor3 = theme.text
        l.Font = Enum.Font.GothamMedium
        l.TextSize = 14
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = 3

        local dropBtn = Instance.new("TextButton", row)
        dropBtn.Size = UDim2.new(0, 125, 0, 34)
        dropBtn.Position = UDim2.new(1, -137, 0, 8)
        dropBtn.BackgroundColor3 = theme.input
        dropBtn.AutoButtonColor = false
        dropBtn.ZIndex = 3
        dropBtn.Text = ""
        corner(dropBtn, 8)
        local dStroke = stroke(dropBtn, theme.accent, 1, 0.6)

        local curValLbl = Instance.new("TextLabel", dropBtn)
        curValLbl.Size = UDim2.new(1, -24, 1, 0)
        curValLbl.Position = UDim2.new(0, 8, 0, 0)
        curValLbl.BackgroundTransparency = 1
        curValLbl.TextColor3 = theme.accent
        curValLbl.Font = Enum.Font.GothamBold
        curValLbl.TextSize = 13
        curValLbl.TextXAlignment = Enum.TextXAlignment.Left
        curValLbl.TextTruncate = Enum.TextTruncate.AtEnd
        curValLbl.Text = tostring(getVal() or "")
        curValLbl.ZIndex = 4

        local chevron = Instance.new("TextLabel", dropBtn)
        chevron.Size = UDim2.new(0, 16, 1, 0)
        chevron.Position = UDim2.new(1, -20, 0, 0)
        chevron.BackgroundTransparency = 1
        chevron.Text = "▾"
        chevron.TextColor3 = theme.accent
        chevron.Font = Enum.Font.GothamBold
        chevron.TextSize = 13
        chevron.ZIndex = 4

        local maxVisible = math.min(#items, 5)
        local itemH = 28
        local scrollH = maxVisible * (itemH + 2) + 6

        local optScroll = Instance.new("ScrollingFrame", row)
        optScroll.Size = UDim2.new(1, -28, 0, scrollH)
        optScroll.Position = UDim2.new(0, 14, 0, 48)
        optScroll.BackgroundColor3 = theme.bg2
        optScroll.BackgroundTransparency = 0.2
        optScroll.BorderSizePixel = 0
        optScroll.ScrollBarThickness = 3
        optScroll.ScrollBarImageColor3 = theme.accent
        optScroll.CanvasSize = UDim2.new(0, 0, 0, #items * (itemH + 2) + 6)
        optScroll.Visible = false
        optScroll.ZIndex = 5
        corner(optScroll, 8)
        local sStroke = stroke(optScroll, theme.accent, 1, 0.8)

        local optList = Instance.new("UIListLayout", optScroll)
        optList.Padding = UDim.new(0, 2)
        optList.SortOrder = Enum.SortOrder.LayoutOrder

        local optPad = Instance.new("UIPadding", optScroll)
        optPad.PaddingTop = UDim.new(0, 3)
        optPad.PaddingBottom = UDim.new(0, 3)
        optPad.PaddingLeft = UDim.new(0, 3)
        optPad.PaddingRight = UDim.new(0, 3)

        local optionButtons = {}
        local function updateDisplay()
            local cur = tostring(getVal() or "")
            curValLbl.Text = cur
            for _, entry in ipairs(optionButtons) do
                local isSel = (entry.name == cur)
                entry.btn.BackgroundColor3 = isSel and theme.accent or theme.input
                entry.btn.BackgroundTransparency = isSel and 0.1 or 0.7
                entry.lbl.TextColor3 = isSel and theme.bg or theme.text
            end
        end

        local isOpen = false
        local function closeDropdown()
            if not isOpen then return end
            isOpen = false
            if activeDropdownCloser == closeDropdown then activeDropdownCloser = nil end
            chevron.Text = "▾"
            tw(row, 0.18, { Size = UDim2.new(1, 0, 0, 50) })
            task.delay(0.18, function()
                if not isOpen then optScroll.Visible = false end
            end)
        end

        local function openDropdown()
            if activeDropdownCloser and activeDropdownCloser ~= closeDropdown then
                activeDropdownCloser()
            end
            isOpen = true
            activeDropdownCloser = closeDropdown
            chevron.Text = "▴"
            optScroll.Visible = true
            updateDisplay()
            local totalH = 50 + scrollH + 6
            tw(row, 0.18, { Size = UDim2.new(1, 0, 0, totalH) })
        end

        dropBtn.MouseButton1Click:Connect(function()
            if isOpen then closeDropdown() else openDropdown() end
        end)

        for idx, itm in ipairs(items) do
            local itmName = (type(itm) == "table" and itm.name) or tostring(itm)
            local ob = Instance.new("TextButton", optScroll)
            ob.Size = UDim2.new(1, 0, 0, itemH)
            ob.BackgroundColor3 = theme.input
            ob.BackgroundTransparency = 0.7
            ob.AutoButtonColor = false
            ob.Text = ""
            ob.LayoutOrder = idx
            ob.ZIndex = 6
            corner(ob, 6)

            local ol = Instance.new("TextLabel", ob)
            ol.Size = UDim2.new(1, -12, 1, 0)
            ol.Position = UDim2.new(0, 8, 0, 0)
            ol.BackgroundTransparency = 1
            ol.Text = itmName
            ol.TextColor3 = theme.text
            ol.Font = Enum.Font.GothamMedium
            ol.TextSize = 13
            ol.TextXAlignment = Enum.TextXAlignment.Left
            ol.ZIndex = 7

            ob.MouseButton1Click:Connect(function()
                closeDropdown()
                onSelect(itm, idx)
                updateDisplay()
            end)

            table.insert(optionButtons, { name = itmName, btn = ob, lbl = ol })
        end

        table.insert(themeListeners, function()
            row.BackgroundColor3 = theme.panel
            ico.ImageColor3 = theme.accent
            lbl.TextColor3 = theme.text
            dStroke.Color = theme.accent
            curValLbl.TextColor3 = theme.accent
            chevron.TextColor3 = theme.accent
            optScroll.BackgroundColor3 = theme.bg2
            optScroll.ScrollBarImageColor3 = theme.accent
            sStroke.Color = theme.accent
            updateDisplay()
        end)

        updateDisplay()
        return row
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
        
        for _, fn in ipairs(themeListeners) do pcall(fn) end

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
    
    -- Sound selector row (dropdown)
    dropdownRow("Sound Type", "music", function()
        local idx = math.clamp(settings.soundIndex or 1, 1, #soundPresets)
        return soundPresets[idx] and soundPresets[idx].name or "Sound"
    end, soundPresets, function(preset, idx)
        settings.soundIndex = idx
        saveConfig()
        if settings.sound then playNotifSound() end
    end)
    
    sectionLabel("APPEARANCE")
    -- UI Theme row (dropdown)
    dropdownRow("UI Theme", "palette", function()
        return settings.theme or "default"
    end, themeNames, function(name)
        applyTheme(name)
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
    
    sliderRow("Toast Size","bell",200,600,
    function() return settings.toastSize or 320 end,
    function(v) 
        settings.toastSize=v
        toastContainer.Size=UDim2.new(0,v,1,-20)
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
    send.MouseEnter:Connect(function() tw(send, 0.15, {Size = UDim2.new(0,36,0,36), Position = UDim2.new(1,-4,1,-4)}) end)
    send.MouseLeave:Connect(function() tw(send, 0.15, {Size = UDim2.new(0,34,0,34), Position = UDim2.new(1,-5,1,-5)}) end)
    send.MouseButton1Down:Connect(function() tw(send, 0.08, {Size = UDim2.new(0,32,0,32), Position = UDim2.new(1,-6,1,-6)}) end)
    send.MouseButton1Up:Connect(function() tw(send, 0.12, {Size = UDim2.new(0,34,0,34), Position = UDim2.new(1,-5,1,-5)}) end)

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
        local msg = box.Text:gsub("\r", ""):gsub("^%s*\n+", ""):gsub("\n+%s*$", "")
        if msg:gsub("%s","") == "" then return end
        box.Text = ""
        updateInputHeight()
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

    UserInputService.InputBegan:Connect(function(inp)
        if inp.KeyCode == Enum.KeyCode.Return and box:IsFocused() then
            local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
            if not shift then
                task.defer(function()
                    box.Text = box.Text:gsub("\r", ""):gsub("\n$", "")
                    box:ReleaseFocus(true)
                end)
            end
        end
    end)

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
                    local isSenderMuted = settings.muted and settings.muted[m.s]
                    local msgOnVisibleTab = (scope == currentTab)
                    local shouldNotify = ((not isOpen) or (not msgOnVisibleTab)) and (not isSenderMuted)
                    
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
