--[[
    DOORS SCRIPT (MoroLumina Edition)
    Converted from Obsidian/Linoria to MoroLumina UI
]]

local httpService = game:GetService("HttpService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local marketplaceService = game:GetService("MarketplaceService")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local soundService = game:GetService("SoundService")
local lighting = game:GetService("Lighting")
local textChatService = game:GetService("TextChatService")
local coreGui = game:GetService("CoreGui")
local virtualUser = game:GetService("VirtualUser")
local proximityPromptService = game:GetService("ProximityPromptService")
local tweenService = game:GetService("TweenService")
local contextActionService = game:GetService("ContextActionService")
local virtualInputManager = game:GetService("VirtualInputManager")
local stats = game:GetService("Stats")
local workspace = game:GetService("Workspace")
local pathfindingService = game:GetService("PathfindingService")
local logService = game:GetService("LogService")


-- =====================================================================
--                   MOROLUMINA UI — DOORS SCRIPT
--                 Converted from Obsidian to Lumina
-- =====================================================================

local function safeLoad(src, chunkName)
    if not src or type(src) ~= "string" or #src == 0 then
        return nil, "empty source"
    end
    local fn, err = loadstring(src, chunkName)
    if not fn then
        return nil, err
    end
    local success, result = pcall(fn)
    if not success then
        return nil, result
    end
    return result
end

local RAW_URL = "https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"
local Lumina

local ok, res = pcall(function()
    local src = game:HttpGet(RAW_URL)
    return safeLoad(src, "MoroLumina")
end)
if ok and res then
    Lumina = res
else
    pcall(function()
        if readfile and isfile and isfile("Lumina.lua") then
            Lumina = safeLoad(readfile("Lumina.lua"), "MoroLuminaLocal")
        end
    end)
end
if not Lumina then
    error("[Moro] Failed to load MoroLumina UI library! Check your internet connection or GitHub access.")
end

local library = {}
library.Toggles = {}
library.Options = {}
library.TabButtons = {}
library.ScreenGui = nil

local MoroWindow = nil

local dummyToggle = {
    Value = false,
    SetValue = function() end,
    SetDisabled = function() end,
    OnChanged = function() end,
    AddColorPicker = function()
        return { Value = Color3.new(1,1,1), SetValue = function() end, OnChanged = function() end }
    end,
    AddKeyPicker = function()
        return { Value = Enum.KeyCode.F, SetValue = function() end, OnChanged = function() end }
    end,
}
local dummyOption = {
    Value = false,
    SetValue = function() end,
    SetDisabled = function() end,
    OnChanged = function() end,
    GetState = function() return {} end,
}
setmetatable(library.Toggles, {
    __index = function(t, k) return dummyToggle end
})
setmetatable(library.Options, {
    __index = function(t, k) return dummyOption end
})

local dummySection = {
    AddToggle = function() return dummyToggle end,
    AddSlider = function() return dummyOption end,
    AddDropdown = function() return dummyOption end,
    AddButton = function() end,
    AddLabel = function() return { SetText = function() end, AddKeyPicker = function() return dummyOption end } end,
    AddDivider = function() end,
    AddInput = function() return dummyOption end,
    AddImage = function() return { SetImage = function() end, SetVisible = function() end } end,
}
local dummyTab = {
    AddLeftGroupbox = function() return dummySection end,
    AddRightGroupbox = function() return dummySection end,
    AddLeftTabbox = function() return { AddTab = function() return dummySection end } end,
    AddRightTabbox = function() return { AddTab = function() return dummySection end } end,
    SetVisible = function() end,
}

local function wrapSection(luminaSec, tab, colName)
    local secProxy = {
        _raw = luminaSec,
        _tab = tab,
    }

    function secProxy:AddToggle(flag, cfg)
        cfg = cfg or {}
        local name = cfg.Text or flag
        local luminaTgl = luminaSec:AddToggle({
            Name = name,
            Default = cfg.Default or false,
            Flag = flag,
            Callback = cfg.Callback,
        })

        local tglProxy = {
            _raw = luminaTgl,
            _flag = flag,
            _listeners = {},
            SetValue = function(self, val)
                if luminaTgl and luminaTgl.Set then
                    luminaTgl.Set(val)
                end
            end,
            SetDisabled = function(self, dis) end,
            OnChanged = function(self, fn)
                table.insert(self._listeners, fn)
                if luminaTgl and luminaTgl.AddListener then
                    luminaTgl.AddListener(fn)
                end
            end,
            AddColorPicker = function(self, cpFlag, cpCfg)
                cpCfg = cpCfg or {}
                local luminaCP = luminaTgl:AddColorPicker({
                    Default = cpCfg.Default or Color3.fromRGB(255, 255, 255),
                    Flag = cpFlag,
                    Callback = cpCfg.Callback,
                })
                local cpProxy = {
                    _raw = luminaCP,
                    _flag = cpFlag,
                    _listeners = {},
                    SetValue = function(self, col)
                        if luminaCP and luminaCP.Set then luminaCP.Set(col) end
                    end,
                    SetValueRGB = function(self, col)
                        if luminaCP and luminaCP.Set then luminaCP.Set(col) end
                    end,
                    OnChanged = function(self, fn)
                        table.insert(self._listeners, fn)
                        if luminaCP and luminaCP.AddListener then luminaCP.AddListener(fn) end
                    end,
                }
                setmetatable(cpProxy, {
                    __index = function(t, k)
                        if k == "Value" then
                            return (luminaCP and luminaCP.Get and luminaCP.Get()) or cpCfg.Default or Color3.fromRGB(255, 255, 255)
                        end
                        return rawget(t, k)
                    end,
                    __newindex = function(t, k, v)
                        if k == "Value" then t:SetValue(v) else rawset(t, k, v) end
                    end,
                })
                library.Options[cpFlag] = cpProxy
                return cpProxy
            end,
            AddKeyPicker = function(self, kpFlag, kpCfg)
                kpCfg = kpCfg or {}
                local defKey = kpCfg.Default
                if type(defKey) == "string" then
                    defKey = Enum.KeyCode[defKey] or Enum.KeyCode.F
                end
                local luminaKB = luminaTgl:AddKeybind({
                    Default = defKey,
                    Mode = kpCfg.Mode or "Toggle",
                    Flag = kpFlag,
                })
                local kbProxy = {
                    _raw = luminaKB,
                    _flag = kpFlag,
                    _listeners = {},
                    SetValue = function(self, key, mode)
                        if luminaKB and luminaKB.Set then luminaKB.Set(key) end
                        if mode and luminaKB and luminaKB.SetMode then luminaKB.SetMode(mode) end
                    end,
                    OnChanged = function(self, fn)
                        table.insert(self._listeners, fn)
                        if luminaKB and luminaKB.AddListener then luminaKB.AddListener(fn) end
                    end,
                }
                setmetatable(kbProxy, {
                    __index = function(t, k)
                        if k == "Value" then
                            return (luminaKB and luminaKB.Get and luminaKB.Get()) or defKey
                        end
                        return rawget(t, k)
                    end,
                    __newindex = function(t, k, v)
                        if k == "Value" then t:SetValue(v) else rawset(t, k, v) end
                    end,
                })
                library.Options[kpFlag] = kbProxy
                return kbProxy
            end,
        }
        setmetatable(tglProxy, {
            __index = function(t, k)
                if k == "Value" then
                    return luminaTgl.Get()
                end
                return rawget(t, k)
            end,
            __newindex = function(t, k, v)
                if k == "Value" then t:SetValue(v) else rawset(t, k, v) end
            end,
        })
        library.Toggles[flag] = tglProxy
        return tglProxy
    end

    function secProxy:AddSlider(flag, cfg)
        cfg = cfg or {}
        local luminaSlider = luminaSec:AddSlider({
            Name = cfg.Text or flag,
            Min = cfg.Min or 0,
            Max = cfg.Max or 100,
            Default = cfg.Default or cfg.Min or 0,
            Decimals = cfg.Rounding or 0,
            Suffix = cfg.Suffix or "",
            Flag = flag,
            Callback = cfg.Callback,
        })
        local sliderProxy = {
            _raw = luminaSlider,
            _flag = flag,
            _listeners = {},
            SetValue = function(self, val)
                if luminaSlider and luminaSlider.Set then luminaSlider.Set(val) end
            end,
            OnChanged = function(self, fn)
                table.insert(self._listeners, fn)
                if luminaSlider and luminaSlider.AddListener then luminaSlider.AddListener(fn) end
            end,
        }
        setmetatable(sliderProxy, {
            __index = function(t, k)
                if k == "Value" then
                    return (luminaSlider and luminaSlider.Get and luminaSlider.Get()) or cfg.Default or 0
                end
                return rawget(t, k)
            end,
            __newindex = function(t, k, v)
                if k == "Value" then t:SetValue(v) else rawset(t, k, v) end
            end,
        })
        library.Options[flag] = sliderProxy
        return sliderProxy
    end

    function secProxy:AddDropdown(flag, cfg)
        cfg = cfg or {}
        if cfg.Multi then
            local defs = {}
            if type(cfg.Default) == "table" then
                for k, v in pairs(cfg.Default) do
                    if type(k) == "number" then table.insert(defs, v)
                    elseif v == true then table.insert(defs, k) end
                end
            elseif type(cfg.Default) == "string" then
                table.insert(defs, cfg.Default)
            end
            local luminaMulti = luminaSec:AddMultiDropdown({
                Name = cfg.Text or flag,
                Options = cfg.Values or {},
                Default = defs,
                Flag = flag,
                Callback = cfg.Callback,
            })
            local multiProxy = {
                _raw = luminaMulti,
                _flag = flag,
                _listeners = {},
                GetState = function(self)
                    return (luminaMulti and luminaMulti.GetSet and luminaMulti.GetSet()) or {}
                end,
                SetValue = function(self, val)
                    if luminaMulti and luminaMulti.Set then
                        if type(val) == "table" then
                            local list = {}
                            for k, v in pairs(val) do
                                if type(k) == "number" then table.insert(list, v)
                                elseif v == true then table.insert(list, k) end
                            end
                            luminaMulti.Set(list)
                        end
                    end
                end,
                OnChanged = function(self, fn)
                    table.insert(self._listeners, fn)
                end,
            }
            setmetatable(multiProxy, {
                __index = function(t, k)
                    if k == "Value" then
                        return (luminaMulti and luminaMulti.GetSet and luminaMulti.GetSet()) or {}
                    end
                    return rawget(t, k)
                end,
                __newindex = function(t, k, v)
                    if k == "Value" then t:SetValue(v) else rawset(t, k, v) end
                end,
            })
            library.Options[flag] = multiProxy
            return multiProxy
        else
            local def = cfg.Default
            if type(def) == "number" and cfg.Values and cfg.Values[def] then
                def = cfg.Values[def]
            end
            local luminaDrop = luminaSec:AddDropdown({
                Name = cfg.Text or flag,
                Options = cfg.Values or {},
                Default = def or (cfg.Values and cfg.Values[1]) or "",
                Flag = flag,
                Callback = cfg.Callback,
            })
            local dropProxy = {
                _raw = luminaDrop,
                _flag = flag,
                _listeners = {},
                SetValue = function(self, val)
                    if luminaDrop and luminaDrop.Set then luminaDrop.Set(val) end
                end,
                OnChanged = function(self, fn)
                    table.insert(self._listeners, fn)
                end,
            }
            setmetatable(dropProxy, {
                __index = function(t, k)
                    if k == "Value" then
                        return (luminaDrop and luminaDrop.Get and luminaDrop.Get()) or def or ""
                    end
                    return rawget(t, k)
                end,
                __newindex = function(t, k, v)
                    if k == "Value" then t:SetValue(v) else rawset(t, k, v) end
                end,
            })
            library.Options[flag] = dropProxy
            return dropProxy
        end
    end

    function secProxy:AddButton(cfg)
        cfg = cfg or {}
        local cb = cfg.Callback or cfg.Func
        return luminaSec:AddButton({
            Name = cfg.Text or "Button",
            Callback = cb,
        })
    end

    function secProxy:AddLabel(cfg)
        local text = type(cfg) == "table" and cfg.Text or tostring(cfg or "")
        local cleanText = text:gsub("<[^>]+>", "")
        local luminaLbl = luminaSec:AddLabel(cleanText)
        local lblProxy = {
            _raw = luminaLbl,
            SetText = function(self, t)
                if luminaLbl and luminaLbl.Set then
                    luminaLbl.Set(tostring(t):gsub("<[^>]+>", ""))
                end
            end,
            AddKeyPicker = function(self, kpFlag, kpCfg)
                kpCfg = kpCfg or {}
                local defKey = kpCfg.Default
                if type(defKey) == "string" then
                    defKey = Enum.KeyCode[defKey] or Enum.KeyCode.RightShift
                end
                local luminaKB = luminaSec:AddKeybind({
                    Name = kpCfg.Text or cleanText or kpFlag,
                    Default = defKey,
                    Mode = kpCfg.Mode or "Toggle",
                    Flag = kpFlag,
                })
                local kbProxy = {
                    _raw = luminaKB,
                    _flag = kpFlag,
                    SetValue = function(self, key, mode)
                        if luminaKB and luminaKB.Set then luminaKB.Set(key) end
                        if mode and luminaKB and luminaKB.SetMode then luminaKB.SetMode(mode) end
                    end,
                    OnChanged = function(self, fn)
                        if luminaKB and luminaKB.AddListener then luminaKB.AddListener(fn) end
                    end,
                }
                setmetatable(kbProxy, {
                    __index = function(t, k)
                        if k == "Value" then
                            return (luminaKB and luminaKB.Get and luminaKB.Get()) or defKey
                        end
                        return rawget(t, k)
                    end,
                })
                library.Options[kpFlag] = kbProxy
                return kbProxy
            end,
        }
        return lblProxy
    end

    function secProxy:AddDivider() end

    function secProxy:AddInput(flag, cfg)
        cfg = cfg or {}
        local luminaBox = luminaSec:AddTextbox({
            Name = cfg.Text or flag,
            Placeholder = cfg.Placeholder or "",
            Default = cfg.Default or "",
            Numeric = cfg.Numeric or false,
            Flag = flag,
            Callback = cfg.Callback,
        })
        local inputProxy = {
            _raw = luminaBox,
            _flag = flag,
            SetValue = function(self, v)
                if luminaBox and luminaBox.Set then luminaBox.Set(v) end
            end,
            OnChanged = function(self, fn) end,
        }
        setmetatable(inputProxy, {
            __index = function(t, k)
                if k == "Value" then
                    return (luminaBox and luminaBox.Get and luminaBox.Get()) or cfg.Default or ""
                end
                return rawget(t, k)
            end,
            __newindex = function(t, k, v)
                if k == "Value" then t:SetValue(v) else rawset(t, k, v) end
            end,
        })
        library.Options[flag] = inputProxy
        return inputProxy
    end

    function secProxy:AddImage(...)
        return { SetImage = function() end, SetVisible = function() end }
    end

    return secProxy
end

local function wrapTab(luminaTab)
    local tabProxy = {
        _raw = luminaTab,
    }

    function tabProxy:AddLeftGroupbox(name)
        luminaTab:Column("left")
        local sec = luminaTab:CreateSection({ Name = name, Collapsible = true })
        return wrapSection(sec, luminaTab, "left")
    end

    function tabProxy:AddRightGroupbox(name)
        luminaTab:Column("right")
        local sec = luminaTab:CreateSection({ Name = name, Collapsible = true })
        return wrapSection(sec, luminaTab, "right")
    end

    function tabProxy:AddLeftTabbox(name)
        luminaTab:Column("left")
        return {
            AddTab = function(_, subName)
                local sec = luminaTab:CreateSection({ Name = subName, Collapsible = true })
                return wrapSection(sec, luminaTab, "left")
            end
        }
    end

    function tabProxy:AddRightTabbox(name)
        luminaTab:Column("right")
        return {
            AddTab = function(_, subName)
                local sec = luminaTab:CreateSection({ Name = subName, Collapsible = true })
                return wrapSection(sec, luminaTab, "right")
            end
        }
    end

    function tabProxy:SetVisible(vis) end

    return tabProxy
end

function library:CreateWindow(cfg)
    cfg = cfg or {}
    MoroWindow = Lumina:CreateWindow({
        Title = cfg.Title or "MOROLUMINA.lua",
        ToggleKey = cfg.ToggleKeybind or cfg.ToggleKey or Enum.KeyCode.RightShift,
    })
    library.ScreenGui = MoroWindow.Gui or MoroWindow.ScreenGui

    local winProxy = {
        _raw = MoroWindow,
        AddSettingsTab = function(self)
            if MoroWindow and MoroWindow.AddSettingsTab then
                MoroWindow:AddSettingsTab()
            end
        end,
    }

    function winProxy:AddTab(name, icon)
        local luminaTab = MoroWindow:CreateTab({
            Name = name,
            Icon = icon or "menu",
        })
        local wrapped = wrapTab(luminaTab)
        wrapped.Button = luminaTab.Button
        wrapped._Button = luminaTab.Button
        return wrapped
    end

    return winProxy
end

function library:Notify(cfg)
    cfg = cfg or {}
    local title = cfg.Title or "Moro"
    local desc = cfg.Description or cfg.Content or cfg.Text or ""
    local dur = cfg.Time or cfg.Duration or 4
    if MoroWindow and MoroWindow.Notify then
        MoroWindow:Notify({
            Title = title,
            Content = desc,
            Duration = dur,
            Type = cfg.Type or "Info"
        })
    elseif Lumina and Lumina.Notify then
        Lumina:Notify({
            Title = title,
            Content = desc,
            Duration = dur,
            Type = cfg.Type or "Info"
        })
    end
end

library.KeybindFrame = { Visible = false }
setmetatable(library.KeybindFrame, {
    __newindex = function(t, k, v)
        rawset(t, k, v)
        if k == "Visible" and MoroWindow and MoroWindow.GetKeybindList then
            pcall(function()
                MoroWindow:GetKeybindList().SetVisible(v)
            end)
        end
    end
})

function library:Toggle(v)
    if MoroWindow and MoroWindow.Toggle then
        MoroWindow:Toggle()
    end
end

local _unloadCallbacks = {}
function library:OnUnload(fn)
    table.insert(_unloadCallbacks, fn)
end

function library:Unload()
    for _, fn in ipairs(_unloadCallbacks) do
        pcall(fn)
    end
    if library.ScreenGui then
        pcall(function() library.ScreenGui:Destroy() end)
    end
    pcall(function()
        local g = (gethui and gethui()) or CoreGui
        local m = g:FindFirstChild("MoroLumina")
        if m then m:Destroy() end
    end)
end

function library:AddDraggableLabel(initialText)
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MoroDisplayInfo"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 999
    pcall(function()
        local parent = (gethui and gethui()) or CoreGui
        screenGui.Parent = parent
    end)

    local frame = Instance.new("Frame")
    frame.Name = "DisplayInfoFrame"
    frame.BackgroundColor3 = Color3.fromRGB(14, 15, 14)
    frame.BorderSizePixel = 0
    frame.Position = UDim2.new(0, 40, 0, 40)
    frame.Size = UDim2.new(0, 360, 0, 28)
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 225, 134)
    stroke.Thickness = 1
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(235, 240, 238)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = initialText or "moro | loading..."
    label.Parent = frame

    return {
        SetText = function(self, t)
            label.Text = tostring(t)
        end,
        SetVisible = function(self, v)
            screenGui.Enabled = v
        end,
        Destroy = function(self)
            screenGui:Destroy()
        end
    }
end

LoadStart = tick()
if not string.split then
  function string:split(p3)
    local val41 = {}
    local val42 = 1

    while true do
      local val43, findResult = string.find(self, p3, val42, true)

      if not val43 then
        break
      end

      table.insert(val41, string.sub(self, val42, val43 - 1))
      val42 = findResult + 1
    end

    table.insert(val41, string.sub(self, val42))
    return val41
  end
end

if not table.find then
  function table:find(p4)
    for n = 1, #self do
      if self[n] == p4 then
        return n
      end
    end

    return nil
  end
end


local function safeCall4(val45)
  if typeof(val45) == "string" then
    local val46, success2 = pcall(Color3.fromHex, val45)

    if val46 then
      return success2
    end
  end

  local function safeCall5(val47)
    local val48, success3 = pcall(string.sub, val45, val47, val47 + 1)

    if not val48 then
      return 0
    end

    local val49, success4 = pcall(tonumber, success3, 16)
    return val49 and success4 or 0
  end

  return Color3.fromRGB(safeCall5(1), safeCall5(3), safeCall5(5))
end

local function helper2(val50)
  if typeof(val50) == "string" then
    return val50
  end

  local val51, jsonData = pcall(function() return httpService:JSONDecode("\"" .. val50 .. "\"") end)

  if val51 and typeof(jsonData) == "string" then
    return jsonData
  end

  local val52, success5 = pcall(string.len, val50)

  if val52 and success5 > 0 then
    local val53 = {}

    for i6 = 1, success5 do
      local val54, success6 = pcall(string.byte, val50, i6)
      local val55

      if val54 then
        val55 = success6
      end

      if val55 then
        val53[#val53 + 1] = string.char(val55)
      end
    end

    if #val53 > 0 then
      local val56, success7 = pcall(table.concat, val53)

      if val56 then
        return success7
      end
    end
  end

  return ""
end

local function helper3(val57)
  if type(val57) ~= "table" then
    return nil
  end

  if val57.Button and typeof(val57.Button) == "Instance" then
    return val57.Button
  end

  if val57._Button and typeof(val57._Button) == "Instance" then
    return val57._Button
  end

  return nil
end

local function safeCall6(val58)
  local object = helper3(val58)

  if object then
    local val59, success8 = pcall(function() return object:FindFirstChild("TextLabel", true) end)

    if val59 and success8 then
      return success8
    end
  end

  if val58._Label and typeof(val58._Label) == "Instance" then
    return val58._Label
  end

  return nil
end

local function helper4(val60)
  if not val60 then
    return false
  end

  if library.ActiveTab == val60 then
    return true
  end

  local activeTab = library.ActiveTab

  if type(activeTab) == "string" then
    if val60.Name == activeTab then
      return true
    end

    if val60.OriginalName == activeTab then
      return true
    end
  end

  return false
end
local val70 = 1

if game.PlaceId ~= 6516141723 and game.PlaceId ~= 6839171747 and game.PlaceId ~= 110258689672370
  and game.PlaceId ~= 10549820578 then
  return
end

function TableClear(val71)
  for key3 in pairs(val71) do
    val71[key3] = nil
  end
end

function TableFind(val72, val73)
  for i7 = 1, #val72 do
    if val72[i7] == val73 then
      return i7
    end
  end

  return nil
end

-- FinishedLoadingRoom kept intact to avoid RemoteListener crash
local httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua = game:HttpGet("https://raw.githubusercontent.com/bocaj111004/ESPLibrary/refs/heads/main/Library.lua")

httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua = httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua:gsub(
  "']</font>'", "'M]</font>'"
)

httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua = httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua:gsub(
  "Frame%.Visible = OnScreen", "Frame.Visible = OnScreen and Library.ShowESPText ~= false"
)

httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua = httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua:gsub(
  "local ScreenPoint, OnScreen = Camera:WorldToViewportPoint%(ObjectPos%)", "local ScreenPoint, OnScreen = Camera:WorldToViewportPoint(ObjectPos); if OnScreen then local Dist = (Camera.CFrame.Position - ObjectPos).Magnitude; local ObjMaxDist = Library.ObjectMaxDistance and Library.ObjectMaxDistance[Object]; if Dist > (ObjMaxDist or Library.MaxDistance) then OnScreen = false end end"
)

httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua = httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua:gsub(
  "Tracers = false,", "Tracers = false, TracersEnabled = {},"
)

httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua = httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua:gsub(
  "LineData%[1%].Visible = OnScreen", "LineData[1].Visible = OnScreen and (Library.Tracers == true or Library.TracersEnabled[Object])"
)

httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua = httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua:gsub(
  "if LineData and CachedHighlight and Library.Tracers == true and OnScreen then", "if LineData and CachedHighlight and (Library.Tracers == true or Library.TracersEnabled[Object]) and OnScreen then"
)

httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua = httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua:gsub("TracersFrame.Parent = ScreenGui", [[
TracersFrame.Parent = ScreenGui

function Library:SetTracersEnabled(Object, Value)
	if Value then
		Library.TracersEnabled[Object] = true
		TracersFrame.Visible = true
	else
		Library.TracersEnabled[Object] = nil
		local any = false
		for _ in pairs(Library.TracersEnabled) do any = true break end
		TracersFrame.Visible = any or Library.Tracers
	end
end]])

local loader = safeLoad(httpsRawGithubusercontentComBocaj111004ESPLibraryRefsHeadsMainLibraryLua, "ESPLibrary")
if not loader then
    warn("[Moro] Failed to load ESP Library, using fallback stub")
    loader = {
        ObjectMaxDistance = {},
        TracersEnabled = {},
        Add = function() return { Destroy = function() end } end,
        Remove = function() end,
    }
end
loader.ObjectMaxDistance = {}

SoundService = soundService
Lighting = lighting
TextChatService = textChatService
CoreGui = coreGui
VirtualUser = virtualUser
ProximityPromptService = proximityPromptService
TweenService = tweenService
ContextActionService = contextActionService
VirtualInputManager = virtualInputManager
local localPlayer2 = players.LocalPlayer
local playerGui = localPlayer2:FindFirstChildOfClass("PlayerGui")
local currentCamera = workspace.CurrentCamera
local currentRooms = workspace:FindFirstChild("CurrentRooms")

_CameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
  currentCamera = workspace.CurrentCamera
end)

PartProperties = {}
local element2

local function helper5()
  local latestRoom = replicatedStorage:FindFirstChild("GameData")
    and replicatedStorage.GameData:FindFirstChild("LatestRoom")

  if not latestRoom then
    latestRoom = replicatedStorage:FindFirstChild("FloorReplicated")
      and replicatedStorage.FloorReplicated:FindFirstChild("LatestRoom")
  end

  if latestRoom and latestRoom ~= element2 then
    element2 = latestRoom

    if element2.Value then
      localPlayer2:SetAttribute("CurrentRoom", element2.Value)
    end

    element2.Changed:Connect(function(p25)
      localPlayer2:SetAttribute("CurrentRoom", p25)

      if Toggles and Toggles.AmbientToggle and Toggles.AmbientToggle.Value then
        TweenService:Create(Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
          Ambient = Options.AmbientColor.Value, }):Play()
      end
    end)
  end

  return latestRoom
end

helper5()

local function helper6(val82)
  val82.ChildAdded:Connect(function(child)
    if child.Name == "LatestRoom" then
      helper5()
    end
  end)

  if val82:FindFirstChild("LatestRoom") then
    helper5()
  end
end

local gameData = replicatedStorage:FindFirstChild("GameData")

if gameData then
  helper6(gameData)
else
  replicatedStorage.ChildAdded:Connect(function(child2)
    if child2.Name == "GameData" then
      helper6(child2)
    end
  end)
end

do
  local floorReplicated = replicatedStorage:FindFirstChild("FloorReplicated")

  if floorReplicated then
    floorReplicated.ChildAdded:Connect(function(child3)
      if child3.Name == "LatestRoom" then
        helper5()
      end
    end)
  end
end

local toggles = library.Toggles
local options = library.Options

local val83 = {
  Sunk = false,
  ActiveThreats = {},
  ThreatNames = {
    RushMoving = true, Rush = true,
    AmbushMoving = true, Ambush = true,
    A60 = true, A60Moving = true, ["A-60"] = true,
    A120 = true, ["A-120"] = true,
    BackdoorRush = true, BlitzMoving = true, Blitz = true,
    ["RNIUSHCG=="] = true, GlitchRush = true,
    AR0xMBUSH = true, GlitchAmbush = true, FrozenAmbush = true,
    CustomEntity = true, BashMoving = true, Bash = true,
    DronesStampede = true, JeffTheKiller = true,
  },
}

local function HasActiveThreat()
  for threat, _ in pairs(val83.ActiveThreats) do
    if threat and threat.Parent and threat:IsDescendantOf(workspace) then
      return true
    else
      val83.ActiveThreats[threat] = nil
    end
  end

  for _, child in ipairs(workspace:GetChildren()) do
    if val83.ThreatNames[child.Name] then
      val83.ActiveThreats[child] = true
      return true
    end
  end

  if rawget(_G, "Functions") or Functions then
    local fn = rawget(_G, "Functions") or Functions
    if fn and fn.GetNearestEntity then
      local ok, nearest = pcall(fn.GetNearestEntity)
      if ok and nearest and nearest.Parent then
        return true
      end
    end
  end

  return false
end

local function helper7()
  local value6 = options.GodmodeMethod and options.GodmodeMethod.Value

  if typeof(value6) == "number" then
    return value6 == 2 and 2 or 1
  end

  if value6 == "On entity spawn" then
    return 2
  end

  return 1
end

local function helper8()
  if not (toggles and toggles.Godmode and toggles.Godmode.Value) then
    return false
  end

  local method = helper7()
  if method == 1 then
    return true
  elseif method == 2 then
    return HasActiveThreat()
  end

  return false
end

local function helper9(val84)
  if not val84 or not val83.ThreatNames[val84.Name] then
    return
  end

  if val83.ActiveThreats[val84] then
    return
  end

  val83.ActiveThreats[val84] = true

  pcall(function()
    val84.AncestryChanged:Connect(function(p28, p29)
      if not p29 or not val84:IsDescendantOf(workspace) then
        val83.ActiveThreats[val84] = nil
      end
    end)
    if val84.Destroying then
      val84.Destroying:Connect(function()
        val83.ActiveThreats[val84] = nil
      end)
    end
  end)
end

workspace.DescendantAdded:Connect(helper9)

for v94, v95 in workspace:GetDescendants() do
  helper9(v95)
end

local character, humanoidRootPart

local function helper10()
  if not character or not humanoidRootPart then
    return
  end

  TableClear(PartProperties)

  CustomPhysics = PhysicalProperties.new(
    100, humanoidRootPart.CustomPhysicalProperties.Friction, humanoidRootPart.CustomPhysicalProperties.Elasticity, humanoidRootPart.CustomPhysicalProperties.FrictionWeight, humanoidRootPart.CustomPhysicalProperties.ElasticityWeight
  )

  for v96, v97 in character:GetDescendants() do
    if v97:IsA("BasePart") then
      PartProperties[v97] = v97.CustomPhysicalProperties

      if toggles.RemoveAcceleration and toggles.RemoveAcceleration.Value then
        v97.CustomPhysicalProperties = CustomPhysics
      end
    end
  end
end

local function helper11()
  if workspace:FindFirstChild("Lobby") then
    return "Lobby"
  end

  local gameData2 = replicatedStorage:FindFirstChild("GameData")

  if not gameData2 then
    return "Lobby"
  end

  local floor3 = gameData2:FindFirstChild("Floor")

  if not floor3 then
    return "Lobby"
  end

  local strVal2 = tostring(floor3.Value)

  if strVal2 == "" then
    return "Lobby"
  end

  if strVal2 == "Hotel" then
    local remotesFolder = replicatedStorage:FindFirstChild("RemotesFolder")
      or replicatedStorage:FindFirstChild("Bricks")

    if remotesFolder and remotesFolder.Name == "Bricks" then
      return "OldHotel"
    end
  end

  return strVal2
end

CurrentFloor = nil
OldJump = false
OldSlide = false

local function helper12()
  if JumpAttributeConnection then
    JumpAttributeConnection:Disconnect()
  end

  if SlideAttributeConnection then
    SlideAttributeConnection:Disconnect()
  end

  if not character then
    return
  end

  OldJump = character:GetAttribute("CanJump") or false
  OldSlide = character:GetAttribute("CanSlide") or false

  if toggles.EnableCharacterJump and toggles.EnableCharacterJump.Value then
    character:SetAttribute("CanJump", true)
  end

  if toggles.EnableCharacterSlide and toggles.EnableCharacterSlide.Value then
    character:SetAttribute("CanSlide", true)
  end

  JumpAttributeConnection = character:GetAttributeChangedSignal("CanJump"):Connect(function()
    local canJump = character:GetAttribute("CanJump")

    if toggles.EnableCharacterJump and toggles.EnableCharacterJump.Value and canJump ~= true
      or not (toggles.EnableCharacterJump and toggles.EnableCharacterJump.Value) then
      OldJump = canJump
    end

    if toggles.EnableCharacterJump and toggles.EnableCharacterJump.Value then
      character:SetAttribute("CanJump", true)
    end
  end)

  SlideAttributeConnection = character:GetAttributeChangedSignal("CanSlide"):Connect(function()
    local canSlide = character:GetAttribute("CanSlide")

    if toggles.EnableCharacterSlide and toggles.EnableCharacterSlide.Value and canSlide ~= true
      or not (toggles.EnableCharacterSlide and toggles.EnableCharacterSlide.Value) then
      OldSlide = canSlide
    end

    if toggles.EnableCharacterSlide and toggles.EnableCharacterSlide.Value then
      character:SetAttribute("CanSlide", true)
    end
  end)
end

local humanoid, collision, collisionPart, val85

local function helper13()
  character = localPlayer2.Character

  if character then
    humanoid = character:FindFirstChildOfClass("Humanoid")
    humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

    collision = character:FindFirstChild("Collision")
      or character:FindFirstChild("CollisionPart")

    collisionPart = character:FindFirstChild("CollisionPart")
      or character:FindFirstChild("Collision")

    helper10()
    helper12()

    if val85 then
      local lowerTorso = character:FindFirstChild("LowerTorso")
      local root = lowerTorso and lowerTorso:FindFirstChild("Root")

      if root then
        val85.OriginalC1 = root.C1
      end

      val83.Sunk = false
    end
  end
end

FakePrompts = {}
Connections = {}
local remotesFolder2

do
  local connect, connect2
  local connect3

  function SetupCharacterAnticheat()
    if not character then
      return
    end

    if connect then
      connect:Disconnect()
      connect = nil
    end

    if connect2 then
      connect2:Disconnect()
      connect2 = nil
    end

    if connect3 then
      connect3:Disconnect()
      connect3 = nil
    end

    connect = character:GetAttributeChangedSignal("Climbing"):Connect(function()
      if character:GetAttribute("Climbing") == true and toggles.DisableAnticheat.Value
        and not val85.AnticheatDisabled then
        task.wait(0.25)
        character:SetAttribute("Climbing", false)
        val85.AnticheatDisabled = true

        library:Notify({
          Title = "Disabled anticheat", Description = "Re-enables after cutscenes or halt", Time = 5, })
      end
    end)

    if remotesFolder2 then
      connect2 = remotesFolder2:WaitForChild("Cutscene").OnClientEvent:Connect(function(p30)
        if val85.AnticheatDisabled and not p30:find("SewerSeek") then
          val85.AnticheatDisabled = false

          library:Notify({
            Title = "Anticheat re-enabled", Description = "Interact with a ladder for re-disabling", Time = 5, })
        end
      end)

      connect3 = remotesFolder2:WaitForChild("UseEnemyModule").OnClientEvent:Connect(function(p31)
        if p31 == "Void" or p31 == "Glitch" then
          if val85.AnticheatDisabled then
            val85.AnticheatDisabled = false

            library:Notify({
              Title = "Anticheat re-enabled", Description = "Interact with a ladder for re-disabling", Time = 5, })
          end

          if element2 then
            localPlayer2:SetAttribute("CurrentRoom", element2.Value)
          end
        end
      end)
    end

    character:SetAttribute("Climbing", nil)
  end
end

helper13()
local helper14, helper15, helper16, helper17, helper18, onEvent

localPlayer2.CharacterAdded:Connect(function()
  task.wait(0.5)
  helper13()
  helper14()

  if toggles.FlyToggle.Value then
    helper15()
  end

  if toggles.ArchiveChairFly.Value
    or toggles.StairwellChairFly and toggles.StairwellChairFly.Value then
    StopChairBypass()
  end

  helper16()
  helper17()
  helper18()
  onEvent()

  task.spawn(function()
    task.wait(1)

    if helper8() and val83 and not val83.Sunk and CurrentFloor ~= "Fools" and CurrentFloor ~= "OldHotel" then
      if humanoidRootPart and humanoid and remotesFolder2 then
        humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, -2.346, 0)
        humanoid.HipHeight = 0.05
        local crouch = remotesFolder2:FindFirstChild("Crouch")

        if crouch then
          crouch:FireServer(true, true)
        end

        val83.Sunk = true
      end
    end
  end)

  SetupCharacterAnticheat()
  SetupBringItems()
end)

remotesFolder2 = replicatedStorage:FindFirstChild("RemotesFolder")

if not remotesFolder2 then
  if replicatedStorage:FindFirstChild("EntityInfo") then
    remotesFolder2 = replicatedStorage:FindFirstChild("EntityInfo")
  elseif replicatedStorage:FindFirstChild("Bricks") then
    remotesFolder2 = replicatedStorage:FindFirstChild("Bricks")
  end
end

FakeEvents = {
  Screech = Instance.new("RemoteEvent"), Shade = Instance.new("RemoteEvent"), A90 = Instance.new("RemoteEvent"), Surge = Instance.new("RemoteEvent"), }

FakeEvents.Screech.Name = "Screech"
FakeEvents.Shade.Name = "ShadeResult"
FakeEvents.A90.Name = "A90"
FakeEvents.Surge.Name = "SurgeRemote"

if remotesFolder2 then
  FakeEvents.Screech_Real = remotesFolder2:FindFirstChild("Screech") or remotesFolder2:WaitForChild("Screech", 2)
  FakeEvents.Shade_Real = remotesFolder2:FindFirstChild("ShadeResult") or remotesFolder2:WaitForChild("ShadeResult", 2)
  FakeEvents.A90_Real = remotesFolder2:FindFirstChild("A90") or remotesFolder2:WaitForChild("A90", 2)
  FakeEvents.Surge_Real = remotesFolder2:FindFirstChild("SurgeRemote") or remotesFolder2:WaitForChild("SurgeRemote", 2)
end

local function helper19()
  local playerGui2 = localPlayer2:FindFirstChildOfClass("PlayerGui")
  local mainUI = playerGui2 and playerGui2:FindFirstChild("MainUI")
  local initiator = mainUI and mainUI:FindFirstChild("Initiator")
  local mainGame = initiator and initiator:FindFirstChild("Main_Game")
  local remoteListener = mainGame and mainGame:FindFirstChild("RemoteListener")
  return remoteListener and remoteListener:FindFirstChild("Modules")
end


local moroWindow = library:CreateWindow({
  Title = "MOROLUMINA.lua",
  ToggleKey = Enum.KeyCode.RightShift,
})

local element3 = {
  Home = dummyTab, -- Home tab removed as requested
  Main = moroWindow:AddTab("Main", "house"),
  AutoFarm = moroWindow:AddTab("Auto Farm", "bot"),
  Visuals = moroWindow:AddTab("Visuals", "scan-eye"),
  Exploits = moroWindow:AddTab("Exploits", "sparkle"),
  Miscellaneous = moroWindow:AddTab("Miscellaneous", "settings"),
  Mines = moroWindow:AddTab("Mines", "gem"),
  FoolsHotel = moroWindow:AddTab("Hotel-/Fools", "party-popper"),
  Rooms = moroWindow:AddTab("Rooms", "bed-double"),
  Garden = moroWindow:AddTab("Outdoors", "tree-pine"),
  Archives = moroWindow:AddTab("Archives", "archive"),
  Stairwell = moroWindow:AddTab("Stairwell", "tv"),
}
moroWindow:AddSettingsTab()
do
  local val86 = safeCall6(element3.FoolsHotel)

  if val86 then
    element3.FoolsHotel.TabLabelRef = val86
  end
end

Groupboxes = {}
Groupboxes.SubfloorsFools = element3.FoolsHotel:AddLeftGroupbox("Fools")

Groupboxes.SubfloorsFools:AddToggle("BypassKillbricks", {
  Text = "Anti Killbricks", Default = false, Tooltip = "Disables Lava from hurting you", })

Groupboxes.SubfloorsFools:AddToggle("BypassSeekingWall", {
  Text = "Anti Seeking Wall", Default = false, Tooltip = "Disables ScaryWall from hurting you", })

Groupboxes.SubfloorsFools:AddToggle("BypassBanana", {
  Text = "Anti Banana", Default = false, Tooltip = "Disables Banana Peel from making you slip", })

Groupboxes.SubfloorsFools:AddToggle("BypassJeff", {
  Text = "Anti Jeff", Default = false, Tooltip = "Disables Jeff the Killer from stabbing you", })

Groupboxes.SubfloorsFools:AddDivider()

Groupboxes.SubfloorsFools:AddToggle("RemoveSeekTrigger", {
  Text = "Delete Seek Trigger", Default = false, Tooltip = "Deletes/disables the Seek cutscene trigger", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.SubfloorsFools:AddToggle("RemoveFigure", {
  Text = "Delete Figure", Default = false, Tooltip = "Removes Figure, however this is inconsistent", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.SubfloorsFools:AddToggle("AutoRevive", {
  Text = "Infinite Revives", Default = false, Tooltip = "Automatically revives after dying without using a revive and having infinite usage", })

Groupboxes.SubfloorsFools:AddToggle("FigureGodmode", {
  Text = "Figure Godmode", Default = false, Tooltip = "Prevents Figure from hurting you", })

Groupboxes.SubfloorsFools:AddDivider()

Groupboxes.SubfloorsFools:AddToggle("RemoveBasementGate", {
  Text = "Remove Basement Gate", Default = false, Tooltip = "Removes the gate from basement rooms", })

Groupboxes.SubfloorsFools:AddToggle("RemovePaintingsDoor", {
  Text = "Remove Paintings Door", Default = false, Tooltip = "Removes the fireplace doors from painting rooms", })

Groupboxes.SubfloorsFools:AddToggle("RemoveSkeletonDoor", {
  Text = "Remove Skeleton Door", Default = false, Tooltip = "Removes the skeleton door from the infirmary", })

Groupboxes.SubfloorsFools:AddToggle("AutoRoomSkip", {
  Text = "Auto Room-Skip", Default = false, Tooltip = "Automatically teleports to the next room", })

Groupboxes.SubfloorsFools:AddButton({
  Text = "Skip Current Room", Tooltip = "Teleports you to the current room's door", Func = function()
    task.spawn(function()
      local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

      if not currentRooms2 then
        return
      end

      local value7 = element2 and element2.Value or localPlayer2:GetAttribute("CurrentRoom")

      if not value7 then
        return
      end

      local findFirstChild = currentRooms2:FindFirstChild(tostring(value7))

      if not findFirstChild then
        return
      end

      local findFirstChild2 = findFirstChild:FindFirstChild("Door", true)

      if not findFirstChild2 or not findFirstChild2:IsA("MeshPart") then
        local val87 = {}

        for v103, v104 in findFirstChild:GetDescendants() do
          if v104:IsA("MeshPart") and v104.Name == "Door" then
            table.insert(val87, v104)
          end
        end

        findFirstChild2 = val87[#val87]

        if not findFirstChild2 then
          return
        end
      end

      local character2 = localPlayer2.Character

      if character2 then
        character2:PivotTo(CFrame.new(findFirstChild2.Position))
      end
    end)
  end, })

Groupboxes.SubfloorsOutdoors = false

Hour = tonumber(os.date("%H"))

if Hour >= 6 and Hour < 12 then
  Greeting = "Good morning"
elseif Hour >= 12 and Hour < 18 then
  Greeting = "Good afternoon"
else
  Greeting = "Good evening"
end

RootEnv = nil
pcall(function() RootEnv = getfenv(0) end)

if type(RootEnv) ~= "table" then
  RootEnv = _G
end

Executor = {
  isnetworkowner = RootEnv.isnetworkowner, firetouchinterest = RootEnv.firetouchinterest, replicatesignal = RootEnv.replicatesignal, fireproximityprompt = RootEnv.fireproximityprompt, hookmetamethod = RootEnv.hookmetamethod, newcclosure = RootEnv.newcclosure, getnamecallmethod = RootEnv.getnamecallmethod, require = RootEnv.require, }

Groupboxes.HomeFunctions = element3.Home:AddLeftGroupbox("Functions & Features")

local function helper20(val90)
  return val90 and "â" or "â"
end

hasFirePrompt = Executor.fireproximityprompt ~= nil
hasFireTouch = Executor.firetouchinterest ~= nil
hasReplicateSignal = Executor.replicatesignal ~= nil
hasNetworkOwner = Executor.isnetworkowner ~= nil

hasHookMeta = Executor.hookmetamethod ~= nil and Executor.newcclosure ~= nil
  and Executor.getnamecallmethod ~= nil

hasRequire = Executor.require ~= nil

Groupboxes.Misc = element3.Miscellaneous:AddLeftGroupbox("Miscellaneous")

Groupboxes.Misc:AddButton({
  Text = "Play Again", Callback = function()
    pcall(function()
      local playAgain = remotesFolder2 and remotesFolder2:FindFirstChild("PlayAgain")

      if playAgain then
        playAgain:FireServer()
      end
    end)
  end, })

Groupboxes.Misc:AddButton({
  Text = "Return to Lobby", Callback = function()
    pcall(function()
      local lobby = remotesFolder2 and remotesFolder2:FindFirstChild("Lobby")

      if lobby then
        lobby:FireServer()
      end
    end)
  end, })

Groupboxes.Misc:AddButton({
  Text = "Reset Character", Callback = function()
    pcall(function()
      if humanoid then
        humanoid.Health = 0
      end

      local underwater = remotesFolder2 and remotesFolder2:FindFirstChild("Underwater")

      if underwater then
        underwater:FireServer(true)
      end
    end)
  end, })

Groupboxes.Misc:AddButton({
  Text = "Give Star Jug", Tooltip = "Gives a star jug", Callback = function()
    task.spawn(function()
      local wait = character or localPlayer2.CharacterAdded:Wait()
      local humanoid2 = humanoid or wait:WaitForChild("Humanoid")
      local parent = game:GetObjects("rbxassetid://119885581324516")[1]

      if not parent then
        return
      end

      local val91 = 4
      local val92 = false
      parent:SetAttribute("Durability", val91)
      local instance = Instance.new("NumberValue", parent)
      parent.Parent = localPlayer2.Backpack
      local animations = parent:WaitForChild("Animations")
      local element4 = {}

      for v113, v114 in animations:GetChildren() do
        element4[v114.Name] = humanoid2:LoadAnimation(v114)

        if v114.Name == "idle" then
          element4[v114.Name].Priority = Enum.AnimationPriority.Idle
          element4[v114.Name].Looped = true
        end
      end

      parent.Equipped:Connect(function()
        element4.equip:Play()
        task.wait(element4.equip.Length)

        if parent:IsDescendantOf(wait) then
          element4.idle:Play()
        end
      end)

      parent.Unequipped:Connect(function()
        if element4.idle.IsPlaying then
          element4.idle:Stop()
        end
      end)

      parent.Activated:Connect(function()
        if val92 then
          return
        end

        val92 = true
        element4.open:Play()

        if val91 - 1 ~= 0 then
          val91 = val91 - 1
          parent:SetAttribute("Durability", val91)
        else
          parent:Destroy()
        end

        local parent2 = character

        if not parent2 or not parent2.Parent then
          val92 = false
          return
        end

        parent2:SetAttribute("Starlight", true)
        parent2:SetAttribute("StarlightHuge", true)

        local val93 = false

        local collisionPart2 = parent2:FindFirstChild("CollisionPart")
          or parent2:FindFirstChild("Collision")

        local crouch2 = remotesFolder2 and remotesFolder2:FindFirstChild("Crouch")

        if collisionPart2 and not parent2:FindFirstChild("CollisionClone") then
          local collisionClone = collisionPart2:Clone()
          collisionClone.CanCollide = false
          collisionClone.Massless = true
          collisionClone.RootPriority = 127
          collisionClone.Anchored = false
          collisionClone.Name = "CollisionClone"

          local collisionCrouch = collisionClone:FindFirstChild("CollisionCrouch")

          if collisionCrouch then
            collisionCrouch:Destroy()
          end

          collisionClone.Parent = parent2

          task.spawn(function()
            while not val93 do
              collisionClone.Massless = not collisionClone.Massless

              if crouch2 then
                crouch2:FireServer(true, true)
              end

              task.wait(0.21)
            end

            collisionClone.Massless = true
            collisionClone:Destroy()
          end)
        end

        instance.Value = 35
        TweenService:Create(instance, TweenInfo.new(70, Enum.EasingStyle.Linear), { Value = 0 }):Play()

        local connect4 = instance:GetPropertyChangedSignal("Value"):Connect(function()
          if parent2 and parent2.Parent then
            parent2:SetAttribute("SpeedBoost", instance.Value)
          end
        end)

        task.wait(35)
        val93 = true
        connect4:Disconnect()
        instance:Destroy()

        if parent2 and parent2.Parent then
          parent2:SetAttribute("Starlight", false)
          parent2:SetAttribute("StarlightHuge", false)
          parent2:SetAttribute("SpeedBoost", 0)
        end

        val92 = false
      end)
    end)
  end, })

Groupboxes.Misc:AddDivider()


Groupboxes.Misc:AddToggle("ShowKeybinds", {
  Text = "Show Keybinds", Default = false, Tooltip = "Shows all registered keybinds", })

toggles.ShowKeybinds:OnChanged(function(visible2) library.KeybindFrame.Visible = visible2 end)

Groupboxes.Misc:AddToggle("AntiLag", {
  Text = "Anti-Lag", Default = false, Tooltip = "Reduces lag by setting all parts in the current rooms to Plastic material", })

toggles.AntiLag:OnChanged(function(p34)
  local currentRooms3 = workspace.CurrentRooms

  if not currentRooms3 then
    return
  end

  if p34 then
    for v120, v121 in currentRooms3:GetDescendants() do
      if v121:IsA("BasePart") then
        v121:SetAttribute("Mat", v121.Material)
        v121.Material = "Plastic"
      end
    end
  else
    for v122, v123 in currentRooms3:GetDescendants() do
      if v123:IsA("BasePart") then
        if v123:GetAttribute("Mat") then
          v123.Material = v123:GetAttribute("Mat") or "Plastic"
        end
      end
    end
  end
end)

Groupboxes.Misc:AddDivider()

Groupboxes.Misc:AddToggle("DisableIdleKick", {
  Text = "Disable Idle Kick", Default = false, Tooltip = "Disables the kick from being afk for 20 minutes", })

DisableIdleKickConn = nil

toggles.DisableIdleKick:OnChanged(function(p35)
  if DisableIdleKickConn then
    DisableIdleKickConn:Disconnect()
    DisableIdleKickConn = nil
  end

  if p35 then
    DisableIdleKickConn = localPlayer2.Idled:Connect(function()
      VirtualUser:CaptureController()
      VirtualUser:ClickButton2(Vector2.new())
    end)
  end
end)

Groupboxes.Misc:AddToggle("DisplayInfo", {
  Text = "Display Info", Default = false, Tooltip = "Shows an overlay with FPS, ping, executor, and username", })

DisplayInfoFPS = 60
DisplayInfoFC = 0
DisplayInfoFT = tick()

toggles.DisplayInfo:OnChanged(function(p37)
  if DisplayInfoLabel then
    DisplayInfoLabel:Destroy()
    DisplayInfoLabel = nil
  end

  if DisplayInfoConn then
    DisplayInfoConn:Disconnect()
    DisplayInfoConn = nil
  end

  if p37 then
    DisplayInfoFC = 0
    DisplayInfoFT = tick()
    DisplayInfoLabel = library:AddDraggableLabel("moro | loading...")

    if val85.UILibrary == "Obsidian" then
      local label = DisplayInfoLabel.Label or DisplayInfoLabel
      pcall(function() label.TextColor3 = Color3.fromHex("ebebeb") end)
    end

    DisplayInfoConn = runService.RenderStepped:Connect(function()
      if _Unloading then
        return
      end

      DisplayInfoFC = DisplayInfoFC + 1
      local val95 = tick()

      if val95 - DisplayInfoFT >= 1 then
        DisplayInfoFPS = DisplayInfoFC
        DisplayInfoFT = val95
        DisplayInfoFC = 0
      end

      local success15 = pcall(function()
        return math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue())
      end) and math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue()) or 0

      local success16 = pcall(identifyexecutor) and identifyexecutor() or "Unknown"

      DisplayInfoLabel:SetText(("moro | FPS: %d | Ping: %dms | Executor: %s | User: %s"):format(
        math.floor(DisplayInfoFPS), success15, success16, localPlayer2.Name
      ))
    end)
  end
end)

Groupboxes.MiscFun = element3.Miscellaneous:AddRightGroupbox("Fun")

Groupboxes.MiscFun:AddToggle("Uhhhh", {
  Text = "uhhhh", Default = false, Tooltip = "content (this makes a lot of lag btw)", })

UhhhhDecals = {}
UhhhhConn = nil

toggles.Uhhhh:OnChanged(function(p38)
  if p38 then
    for key4, value8 in pairs(workspace:GetDescendants()) do
      if value8:IsA("BasePart") then
        local model = value8:FindFirstAncestorWhichIsA("Model")

        if not (model and model:FindFirstChild("Humanoid")) then
          for index4, value9 in ipairs(Enum.NormalId:GetEnumItems()) do
            local decal = Instance.new("Decal")
            decal.Texture = "http://www.roblox.com/asset/?id=135666356081915"
            decal.Face = value9
            decal.Parent = value8

            table.insert(UhhhhDecals, decal)
          end
        end
      end
    end

    UhhhhConn = workspace.DescendantAdded:Connect(function(descendant)
      if descendant:IsA("BasePart") then
        local model2 = descendant:FindFirstAncestorWhichIsA("Model")

        if not (model2 and model2:WaitForChild("Humanoid")) then
          for index5, value10 in ipairs(Enum.NormalId:GetEnumItems()) do
            local decal2 = Instance.new("Decal")
            decal2.Texture = "http://www.roblox.com/asset/?id=135666356081915"
            decal2.Face = value10
            decal2.Parent = descendant

            table.insert(UhhhhDecals, decal2)
          end
        end
      end
    end)
  else
    if UhhhhConn then
      UhhhhConn:Disconnect()
      UhhhhConn = nil
    end

    for index6, value11 in ipairs(UhhhhDecals) do
      if value11 and value11.Parent then
        value11:Destroy()
      end
    end

    TableClear(UhhhhDecals)
  end
end)

Groupboxes.MiscFun:AddButton({
  Text = "uhhhh val", Tooltip = "content", Callback = function()
    local content = Instance.new("ScreenGui")
    content.Name = "content"
    content.ResetOnSpawn = false
    content.IgnoreGuiInset = true
    content.Parent = CoreGui

    local frame5 = Instance.new("Frame")
    frame5.Size = UDim2.new(1, 0, 1, 0)
    frame5.BackgroundColor3 = Color3.new(0, 0, 0)
    frame5.BackgroundTransparency = 1
    frame5.Parent = content

    local textLabel2 = Instance.new("TextLabel")
    textLabel2.Size = UDim2.new(1, -40, 1, -40)
    textLabel2.Position = UDim2.new(0, 20, 0, 20)
    textLabel2.BackgroundTransparency = 1
    textLabel2.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel2.TextTransparency = 1
    textLabel2.TextScaled = true
    textLabel2.Font = Enum.Font.Code
    textLabel2.TextXAlignment = Enum.TextXAlignment.Center
    textLabel2.TextYAlignment = Enum.TextYAlignment.Center

    textLabel2.Text = "MORO"

    textLabel2.Parent = frame5

    TweenService:Create(
      frame5, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.1 }
    ):Play()

    TweenService:Create(
      textLabel2, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }
    ):Play()

    library:Toggle(false)
    task.wait(6)

    TweenService:Create(
      frame5, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }
    ):Play()

    TweenService:Create(
      textLabel2, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }
    ):Play()

    task.wait(1)
    content:Destroy()
  end, })

Groupboxes.MiscFun:AddButton({
  Text = "Death Farm", Tooltip = "Execute this in the hotel at a start of run, either use it from here or execute the actual script", Callback = function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/doram44/cheesy/refs/heads/main/stuff/deathfarm.lua"))()
  end, })

Groupboxes.MiscFun:AddToggle("OrbitItems", {
  Text = "Orbit Items", Default = false, Tooltip = "Items that you have dropped will spin around you on the floor", DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.MiscFun:AddSlider("OrbitYOffset", {
  Text = "Orbit Y Offset", Min = 0, Max = 2, Default = 2, Rounding = 1, Tooltip = "The Y position of the item orbit", })

Groupboxes.MiscFun:AddSlider("OrbitSpeed", {
  Text = "Orbit Speed", Min = 2, Max = 5, Default = 2, Rounding = 1, Tooltip = "The speed of the item orbit", })

OrbitConn = nil

toggles.OrbitItems:OnChanged(function()
  if OrbitConn then
    OrbitConn:Disconnect()
    OrbitConn = nil
  end

  if not toggles.OrbitItems.Value then
    return
  end

  if not character or not humanoidRootPart then
    return
  end

  OrbitConn = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not toggles.OrbitItems.Value or not character or not humanoidRootPart then
      return
    end

    if CurrentFloor == "Fools" then
      return
    end

    local drops = workspace:FindFirstChild("Drops")

    if not drops then
      return
    end

    local getChildren = drops:GetChildren()
    local val96 = #getChildren

    if val96 == 0 then
      return
    end

    local val97 = tick()

    for index7, value12 in ipairs(getChildren) do
      if value12:IsA("Model") then
        local val98 = val97 * options.OrbitSpeed.Value + index7 / val96 * math.pi * 2

        local vector = Vector3.new(
          math.cos(val98) * 4, -options.OrbitYOffset.Value, math.sin(val98) * 4
        )

        value12:PivotTo(CFrame.new(humanoidRootPart.Position + vector))
      end
    end
  end)
end)

BringItemsConn = nil
BringItemsBVs = {}

local function helper22()
  TableClear(BringItemsBVs)
end

local function helper23()
  if BringItemsConn then
    BringItemsConn:Disconnect()
    BringItemsConn = nil
  end

  helper22()
end

local function helper24(val99)
  if val99:IsA("BasePart") then
    return val99
  end

  if val99:IsA("Model") then
    return val99.PrimaryPart or val99:FindFirstChildWhichIsA("BasePart")
  end

  return nil
end

function SetupBringItems()
  helper23()

  if _Unloading then
    return
  end

  if not toggles.BringItems.Value then
    return
  end

  BringItemsConn = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not toggles.BringItems.Value then
      return
    end

    if CurrentFloor == "Fools" then
      return
    end

    local character3 = character or localPlayer2.Character
    local humanoid3 = character3 and character3:FindFirstChildOfClass("Humanoid")
    local currentCamera2 = workspace.CurrentCamera

    if not humanoid3 or not currentCamera2 or humanoid3.Health <= 0
      or humanoid3:GetState() == Enum.HumanoidStateType.Dead then
      helper22()
      return
    end

    local val100 = currentCamera2.CFrame.Position + currentCamera2.CFrame.LookVector * 2
      + Vector3.new(0, -0.4, 0)

    local drops2 = workspace:FindFirstChild("Drops")

    if not drops2 then
      return
    end

    for index8, value13 in ipairs(drops2:GetChildren()) do
      local element6 = helper24(value13)

      if not element6 then
        continue
      end

      if element6.Anchored then
        pcall(function() element6.Anchored = false end)
      end

      local bringItemsVelocity = element6:FindFirstChildOfClass("BodyVelocity")

      if not bringItemsVelocity then
        bringItemsVelocity = Instance.new("BodyVelocity")
        bringItemsVelocity.Name = "BringItemsVelocity"
        bringItemsVelocity.MaxForce = Vector3.new(9000000000, 9000000000, 9000000000)
        bringItemsVelocity.Parent = element6

        table.insert(BringItemsBVs, bringItemsVelocity)
      end

      local element7 = val100 - element6.Position

      if element7.Magnitude > 2 then
        element6.CFrame = element6.CFrame:Lerp(CFrame.new(val100), 0.4)
      end

      bringItemsVelocity.Velocity = element7 * 40
    end
  end)
end

Groupboxes.MiscFun:AddToggle("BringItems", {
  Text = "Bring Items", Default = false, Tooltip = "Floats all dropped items in front of your mouse", })

toggles.BringItems:OnChanged(SetupBringItems)

Groupboxes.MiscFun:AddToggle("TwerkDance", {
  Text = "Twerk", Default = false, Tooltip = "Plays the mspaint twerking animation (i think)", })

local loadAnimation

toggles.TwerkDance:OnChanged(function(p40)
  local character4 = localPlayer2.Character

  if not character4 then
    return
  end

  if p40 then
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://12874447851"

    local humanoid4 = character4:FindFirstChildOfClass("Humanoid")

    if not humanoid4 then
      return
    end

    loadAnimation = humanoid4:LoadAnimation(animation)
    loadAnimation.Looped = true
    loadAnimation:Play()
  elseif loadAnimation then
    loadAnimation:Stop()
  end
end)

Functions = {
  FirePrompt = nil, GetLibraryCode = nil, HasItem = nil, HandleHidingTransparency = nil, }

Connections = {}

if localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
  and localPlayer2.Character:FindFirstChild("Collision") then
end

Groupboxes.Character = element3.Main:AddLeftGroupbox("Character")
Groupboxes.Other = element3.Main:AddRightGroupbox("Other")

Groupboxes.AutoFarm = element3.AutoFarm:AddLeftGroupbox("Knob Farm")
Groupboxes.AutoFarm_Settings = element3.AutoFarm:AddRightGroupbox("Settings")

Groupboxes.AutoFarm:AddToggle("AutoFarmEnabled", {
  Text = "Enable Knob Farm",
  Default = false,
  Tooltip = "Automates traversing rooms, looting gold, solving obstacles, and farming knobs",
})

Groupboxes.AutoFarm_Status = Groupboxes.AutoFarm:AddLabel("Status: Idle")

Groupboxes.AutoFarm_Settings:AddSlider("AutoFarmSpeed", {
  Text = "Fly Speed",
  Min = 15,
  Max = 80,
  Default = 45,
  Rounding = 0,
  Suffix = " studs/s",
  Compact = true,
})

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmLootDrawers", {
  Text = "Loot Drawers & Tables",
  Default = true,
  Tooltip = "Visits nearby drawers, chests, and tables to collect gold",
})

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmRunTo100", {
  Text = "Farm to Door 100",
  Default = true,
  Tooltip = "Continues farming through the Library (50) and reaches the Electrical Room (100)",
})

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmPlayAgain", {
  Text = "Auto Play Again (7s)",
  Default = true,
  Tooltip = "Automatically clicks Play Again 7 seconds after dying or beating the game",
})

Groupboxes.SpamBuy = element3.Exploits:AddLeftGroupbox("Pre-Run")

Groupboxes.SpamBuy:AddButton({
  Text = "Buy Items", DisabledTooltip = "This feature doesn't work in this floor", Callback = function()
    task.spawn(function()
      local preRunShop = replicatedStorage.RemotesFolder:FindFirstChild("PreRunShop")

      if not preRunShop then
        return
      end

      local value14 = options.SpamBuyItems.Value
      local val101 = {}

      if value14 then
        for key5, value15 in pairs(value14) do
          table.insert(val101, key5)
        end
      end

      if #val101 > 0 then
        local value16 = options.SpamBuyCount.Value
        local val102 = {}

        for i8 = 1, value16 do
          for index9, value17 in ipairs(val101) do
            table.insert(val102, value17)
          end
        end

        preRunShop:FireServer(val102, false)
      end
    end)
  end, })

Groupboxes.SpamBuy:AddSlider("SpamBuyCount", {
  Text = "Purchase Count", Min = 1, Max = 6, Default = 3, Rounding = 0, Compact = true, DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.SpamBuy:AddDropdown("SpamBuyItems", {
  Text = "Items to Buy", Values = { "Lockpick", "Lighter", "Flashlight", "Vitamins", "Crucifix", "Skeleton Key" }, Multi = true, AllowNull = true, DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.SpamBuy:AddToggle("ShowCrucifix", {
  Text = "Show Crucifix", Default = false, Tooltip = "Shows/hides the crucifix in the item shop", DisabledTooltip = "This feature doesn't work in this floor", })

toggles.ShowCrucifix:OnChanged(function(visible3)
  if helper11() ~= "OldHotel" then
    return
  end

  local itemShopCrucifix = localPlayer2 and localPlayer2.PlayerGui
    and localPlayer2.PlayerGui:FindFirstChild("MainUI")
    and localPlayer2.PlayerGui.MainUI:FindFirstChild("ItemShop")
    and localPlayer2.PlayerGui.MainUI.ItemShop:FindFirstChild("Items")
    and localPlayer2.PlayerGui.MainUI.ItemShop.Items:FindFirstChild("ItemShop_Crucifix")

  if itemShopCrucifix then
    itemShopCrucifix.Visible = visible3
  end
end)

Groupboxes.SpamBuy:AddToggle("ShowSkeletonKey", {
  Text = "Show Skeleton Key", Default = false, Tooltip = "Shows/hides the skeleton key in the item shop", DisabledTooltip = "This feature doesn't work in this floor", })

toggles.ShowSkeletonKey:OnChanged(function(visible4)
  if helper11() ~= "OldHotel" then
    return
  end

  local itemShopSkeletonKey = localPlayer2 and localPlayer2.PlayerGui
    and localPlayer2.PlayerGui:FindFirstChild("MainUI")
    and localPlayer2.PlayerGui.MainUI:FindFirstChild("ItemShop")
    and localPlayer2.PlayerGui.MainUI.ItemShop:FindFirstChild("Items")
    and localPlayer2.PlayerGui.MainUI.ItemShop.Items:FindFirstChild("ItemShop_Skeleton Key")

  if itemShopSkeletonKey then
    itemShopSkeletonKey.Visible = visible4
  end
end)

Groupboxes.Prompts = element3.Exploits:AddLeftGroupbox("Prompts")

Groupboxes.Prompts:AddToggle("InstantInteract", {
  Text = "Instant Interact", Default = false, Tooltip = "Removes the wait time for interactions e.g. locks", })

Groupboxes.Prompts:AddToggle("PromptClip", {
  Text = "Prompt Clip", Default = false, Tooltip = "Allows you to interact through walls", })

Groupboxes.Prompts:AddToggle("PromptReach", {
  Text = "Prompt Reach", Default = false, Tooltip = "Increases the range of all proximity prompts", })

Groupboxes.Prompts:AddSlider("PromptRange", {
  Text = "Prompt Range", Min = 1, Max = 2, Default = 1, Rounding = 1, Compact = true, })

_TrackedPrompts = {}

options.PromptRange:OnChanged(function(p41)
  if toggles.PromptReach.Value then
    for index10, value18 in ipairs(_TrackedPrompts) do
      value18.MaxActivationDistance = value18:GetAttribute("MaxActivationDistance_Old") * p41
    end
  end
end)

Groupboxes.Exploits = element3.Exploits:AddLeftGroupbox("Exploits")

Groupboxes.Exploits:AddToggle("InfiniteItemsToggle", {
  Text = "Infinite Items", Default = false, Tooltip = "Allows you to use lockpicks, shears, skeleton keys, and multitools without draining the usage", DisabledTooltip = "Your executor doesn't support this feature :(", })

local val103

Connections.InfiniteItemsHandler = ProximityPromptService.PromptTriggered:Connect(function(p42)
  if not p42:GetAttribute("FakePrompt") then
    return
  end

  local val104 = {
    "Lockpick", "Shears", "SkeletonKey", "Key", "GeneratorFuse", "KeyElectrical", "KeyBackdoor", "KeyIron", "Multitool", }

  local val105 = {
    "Lockpick", "Shears", "SkeletonKey", "Key", "KeyElectrical", "KeyBackdoor", "KeyIron", "Multitool", }

  local findFirstChild3

  for index11, value19 in ipairs(val104) do
    findFirstChild3 = character:FindFirstChild(value19)

    if findFirstChild3 then
      break
    end
  end

  local val106 = {
    UnlockPrompt = true, SkullPrompt = true, LockPrompt = true, ThingToEnable = true, FusesPrompt = true, }

  local parent = val106[p42.Name]
    or p42.Parent and p42.Parent:GetAttribute("Locked") == true
    or p42.Parent and p42.Parent.Parent and p42.Parent.Parent.Name == "Locker_Small_Locked"
      and p42.Name == "ActivateEventPrompt"

  if parent then
    if options.AutoInteractIgnoreList.Value.Locks then
      return
    end

    local val107 = {
      "Key", "GeneratorFuse", "KeyBackdoor", "KeyElectrical", "KeyIron", "Lockpick", "SkeletonKey", "Shears", "Multitool", }

    local val108 = { "Key", "GeneratorFuse", "KeyElectrical", "KeyIron" }
    local val109 = false

    for index12, value20 in ipairs(val107) do
      if Functions.HasItem(value20, true) then
        val109 = true
        break
      end
    end

    for index13, value21 in ipairs(val108) do
      if Functions.HasItem(value21) then
        val109 = true
        break
      end
    end

    if not val109 then
      return
    end
  end

  if p42.Parent.Name == "CuttableVines" and not Functions.HasItem("Shears", true)
      and not Functions.HasItem("Multitool", true)
    or p42.Parent.Name == "Chest_Vine" and not Functions.HasItem("Shears", true)
      and not Functions.HasItem("Multitool", true)
    or p42.Parent.Name == "Cellar" and not Functions.HasItem("Shears", true)
      and not Functions.HasItem("Multitool", true) then
    return
  end

  if p42.Parent.Name == "SkullLock" and not Functions.HasItem("SkeletonKey", true) then
    return
  end

  if p42.Parent.Name == "Lock1" and not Functions.HasItem("Lockpick", true)
      and not Functions.HasItem("Multitool", true)
    or p42.Parent.Name == "Lock2" and not Functions.HasItem("Lockpick", true)
      and not Functions.HasItem("Multitool", true) then
    return
  end

  if Functions.HasItem("Shears", true) and parent and p42.Parent.Name ~= "CuttableVines"
    and p42.Parent.Name ~= "Chest_Vine" and p42.Parent.Name ~= "Cellar" then
    return
  end

  if findFirstChild3 and TableFind(val105, findFirstChild3.Name) and val85.UseAnimation
    and val85.UseAnimationBreak then
    val85.UseAnimation:Stop()
    val85.UseAnimationBreak:Stop()
    val85.UseAnimationBreak:Play()

    if findFirstChild3.Name == "Shears" then
      findFirstChild3:WaitForChild("Handle"):WaitForChild("sound_prompt"):Play()
    end
  end

  local tool = character:FindFirstChildOfClass("Tool")
  local val110 = tool and val103[tool.Name]

  if tool and val110 and toggles.InfiniteItemsToggle.Value and ({
    Lockpicks = true, ["Skeleton Key"] = true, Shears = true, Multitool = true, })[val110] then
    workspace:FindFirstChild("Drops").ChildAdded:Once(function(p43)
      local modulePrompt = p43:FindFirstChild("ModulePrompt")
      Functions.FirePrompt(modulePrompt)
      Functions.FirePrompt(FakePrompts[p42])
    end)

    character.ChildAdded:Once(function(p44)
      if p44.Name == "Shears" then
        p44:WaitForChild("Handle"):WaitForChild("sound_promptend"):Play()
      end
    end)

    remotesFolder2.DropItem:FireServer(tool)
  else
    Functions.FirePrompt(FakePrompts[p42])
  end
end)

Groupboxes.Exploits:AddToggle("InfiniteCrucifix", {
  Text = "Infinite Crucifix", Default = false, Tooltip = "Performs a glitch that doesn't use up your crucifix when used on a rushlike entity (rush, ambush, a60, a120, blitz), however, this is inconsistent", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.Exploits:AddToggle("AutoHeartbeatMinigame", {
  Text = "Win Heartbeat Minigame", Default = false, Tooltip = "Automatically passes the heartbeat minigame when it starts", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.Exploits:AddButton({
  Text = "Fake Revive", Tooltip = "This doesnt always work, and interacting with a bandage will disable it, and will not be able to enable it back. Sometimes you will not be able to fully finish the run, but you can still go through doors/finish", DisabledTooltip = "Your executor doesn't support this feature :(", Callback = function()
    task.spawn(function()
      local gravity = workspace.Gravity
      local connect5

      local function helper25()
        local humanoid5 = localPlayer2.Character
            and localPlayer2.Character:FindFirstChild("Humanoid")
          or localPlayer2.Character:WaitForChild("Humanoid")

        if connect5 then
          connect5:Disconnect()
        end

        connect5 = humanoid5.Died:Connect(function()
          task.delay(0.5, function()
            workspace.Gravity = 0
            local character5 = localPlayer2.Character

            if not character5 then
              return
            end

            local humanoid6 = character5:FindFirstChild("Humanoid")
            local humanoidRootPart2 = character5:FindFirstChild("HumanoidRootPart")

            if not humanoid6 or not humanoidRootPart2 then
              return
            end

            local playerGui3 = localPlayer2:FindFirstChild("PlayerGui")

            if playerGui3 then
              local mainUI2 = playerGui3:FindFirstChild("MainUI")

              if mainUI2 then
                local deathPanel = mainUI2:FindFirstChild("DeathPanel")

                if deathPanel then
                  deathPanel:Destroy()
                end

                local death = mainUI2:FindFirstChild("Death")

                if death then
                  death:Destroy()
                end
              end
            end

            humanoid6.Health = humanoid6.MaxHealth
            humanoid6.AutomaticScalingEnabled = true

            if character5:GetAttribute("Stunned") then
              character5:SetAttribute("Stunned", false)
            end

            task.delay(1, function()
              if connect5 then
                workspace.Gravity = gravity
              end
            end)
          end)
        end)
      end

      local currentRoom = localPlayer2:GetAttribute("CurrentRoom")
        or replicatedStorage:FindFirstChild("GameData")
          and replicatedStorage.GameData:FindFirstChild("LatestRoom")
          and replicatedStorage.GameData.LatestRoom.Value

      if currentRoom and currentRoom >= 1 then
        helper25()
        localPlayer2.CharacterAdded:Connect(function() helper25() end)
        task.wait(1)

        if Executor.replicatesignal then
          Executor.replicatesignal(localPlayer2.kill)
        elseif remotesFolder2 and remotesFolder2:FindFirstChild("Underwater") then
          remotesFolder2.Underwater:FireServer(true)
        else
          localPlayer2.Character.Humanoid.Health = 0
        end

        task.wait(1)
        coreGui:FindFirstChild("RobloxGui").Backpack.Visible = true

        localPlayer2:SetAttribute("Alive", true)
        localPlayer2:SetAttribute("FakeDeath", true)

        library:Notify({ Title = "Pick up a bandage to restore all interactions", Time = 5 })
      end
    end)
  end, })

local function helper26(val111)
  if not val111:GetAttribute("HoldDuration_Old") then
    val111:SetAttribute("HoldDuration_Old", val111.HoldDuration)
    val111:SetAttribute("RequiresLineOfSight_Old", val111.RequiresLineOfSight)
    val111:SetAttribute("MaxActivationDistance_Old", val111.MaxActivationDistance)
  end

  if toggles.InstantInteract.Value then
    val111.HoldDuration = 0
  end

  if toggles.PromptClip.Value then
    val111.RequiresLineOfSight = false
  end

  if toggles.PromptReach.Value then
    val111.MaxActivationDistance = val111:GetAttribute("MaxActivationDistance_Old")
      * options.PromptRange.Value
  end
end

FakePrompts = {}

local promptContainer = Instance.new("Folder")
promptContainer.Name = "PromptContainer"
promptContainer.Parent = CoreGui

local function helper27(val112)
  if val112.ClassName ~= "ProximityPrompt" or val112:GetAttribute("FakePrompt") then
    return
  end

  table.insert(_TrackedPrompts, val112)
  helper26(val112)

  local val113 = {
    UnlockPrompt = true, SkullPrompt = true, LockPrompt = true, ThingToEnable = true, FusesPrompt = true, }

  if Executor.fireproximityprompt then
    local currentFloor = localPlayer2:GetAttribute("CurrentFloor") or ""

    if currentFloor ~= "OldHotel" and currentFloor ~= "Fools" then
      if val113[val112.Name]
        or val112.Parent and val112.Parent:GetAttribute("Locked") == true
        or val112.Parent and val112.Parent.Parent and val112.Parent.Parent.Name == "Locker_Small_Locked"
          and val112.Name == "ActivateEventPrompt" then
        local clone = val112:Clone()
        clone:SetAttribute("FakePrompt", true)

        task.wait()

        clone.Parent = val112.Parent
        clone:SetAttribute("HoldDuration_Old", val112:GetAttribute("HoldDuration_Old"))

        clone:SetAttribute(
          "RequiresLineOfSight_Old", val112:GetAttribute("RequiresLineOfSight_Old")
        )

        clone:SetAttribute(
          "MaxActivationDistance_Old", val112:GetAttribute("MaxActivationDistance_Old")
        )

        clone.HoldDuration = val112.HoldDuration
        clone.RequiresLineOfSight = val112.RequiresLineOfSight
        clone.MaxActivationDistance = val112.MaxActivationDistance

        if toggles.InstantInteract.Value then
          clone.HoldDuration = 0
        end

        if toggles.PromptClip.Value then
          clone.RequiresLineOfSight = false
        end

        clone.MaxActivationDistance = clone:GetAttribute("MaxActivationDistance_Old")
          * options.PromptRange.Value

        FakePrompts[clone] = val112
        table.insert(_TrackedPrompts, clone)
        clone.Destroying:Once(function() local v146 = TableFind(_TrackedPrompts, clone) end)
        pcall(function() val112.Parent = promptContainer end)

        local connect6 = val112:GetPropertyChangedSignal("Enabled"):Connect(function()
          clone.Enabled = val112.Enabled
        end)

        val112:GetPropertyChangedSignal("ActionText"):Once(function()
          val112.Parent = clone.Parent
          clone:Destroy()
          connect6:Disconnect()
        end)

        val112.Destroying:Once(function()
          clone:Destroy()
          connect6:Disconnect()
        end)

        clone.Enabled = false
        task.wait()
        clone.Enabled = val112.Enabled
      end
    end
  end

  val112.Destroying:Once(function() local v147 = TableFind(_TrackedPrompts, val112) end)
end

toggles.InstantInteract:OnChanged(function()
  for index14, value22 in ipairs(_TrackedPrompts) do
    value22.HoldDuration = toggles.InstantInteract.Value and 0
      or value22:GetAttribute("HoldDuration_Old")
  end
end)

toggles.PromptClip:OnChanged(function()
  for index15, value23 in ipairs(_TrackedPrompts) do
    if toggles.PromptClip.Value then
      value23.RequiresLineOfSight = false
    else
      value23.RequiresLineOfSight = value23:GetAttribute("RequiresLineOfSight_Old")
    end
  end
end)

toggles.PromptReach:OnChanged(function()
  for index16, value24 in ipairs(_TrackedPrompts) do
    if toggles.PromptReach.Value then
      value24.MaxActivationDistance = value24:GetAttribute("MaxActivationDistance_Old")
        * options.PromptRange.Value
    else
      value24.MaxActivationDistance = value24:GetAttribute("MaxActivationDistance_Old")
    end
  end
end)

options.PromptRange:OnChanged(function()
  if toggles.PromptReach.Value then
    for index17, value25 in ipairs(_TrackedPrompts) do
      value25.MaxActivationDistance = value25:GetAttribute("MaxActivationDistance_Old")
        * options.PromptRange.Value
    end
  end
end)

Groupboxes.Exploits_BypassBox = element3.Exploits:AddRightTabbox("Bypasses")
Groupboxes.Exploits_Bypasses = Groupboxes.Exploits_BypassBox:AddTab("Bypasses")
Groupboxes.Exploits_Removals = Groupboxes.Exploits_BypassBox:AddTab("Removals")
Groupboxes.Exploits_Damage = Groupboxes.Exploits_BypassBox:AddTab("Damage")

Groupboxes.Exploits_Bypasses:AddToggle("BypassGiggle", {
  Text = "Anti Giggle", Default = false, Tooltip = "Prevents Giggle from attacking you", })

Groupboxes.Exploits_Bypasses:AddToggle("BypassDupe", {
  Text = "Anti Dupe", Default = false, Tooltip = "Prevents you from opening Dupe doors", })

Groupboxes.Exploits_Bypasses:AddToggle("BypassEyes", {
  Text = "Anti Eyes", Default = false, Tooltip = "Prevents Eyes from hurting you", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.Exploits_Bypasses:AddToggle("BypassLookman", {
  Text = "Anti Lookman", Default = false, Tooltip = "Prevents Lookman from hurting you", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.Exploits_Bypasses:AddToggle("BypassGloombatEggs", {
  Text = "Anti Gloombat Eggs", Default = false, Tooltip = "Prevents taking damage from stepping on Gloombat eggs", })

Groupboxes.Exploits_Bypasses:AddToggle("BypassSeekObstructions", {
  Text = "Anti Seek Obstructions", Default = false, Tooltip = "Prevents obstacles in the Seek chase from harming you", })

Groupboxes.Exploits_Bypasses:AddToggle("BypassVacuum", {
  Text = "Anti Vacuum", Default = false, Tooltip = "Prevents you from falling into Vacuum fake doors", })

Groupboxes.Exploits_Bypasses:AddToggle("BypassSnare", {
  Text = "Anti Snare", Default = false, Tooltip = "Prevents Snare from trapping you", })

local val114 = {
  Entities = {}, EventTriggers = {}, Obstructions = {}, HidingSpots = {}, SeekObstructions = {}, SeekBridges = {}, SeekNodes = {}, SeekDuckBoards = {}, SeekHighlights = {}, EyestalkHighlights = {}, PathLights = {}, }

EntityNames = {
  GiggleCeiling = true, DoorFake = true, FakeDoor = true, GloombatEgg = true, GloombatEggs = true, Snare = true, Figure = true, FigureRig = true, FigureRagdoll = true, GloomPile = true, TriggerEventCollision = true, Seek_Arm = true, ChandelierObstruction = true, SeekFloodline = true, Bridge = true, MinecartRig = true, RunnerNodes = true, DuckBoard = true, PathLights = true, SeekMovingNewClone = true, SideroomSpace = true, MandrakeLive = true, }

local function helper28(val115)
  if not val115 or not val115.Parent then
    return
  end

  local name = val115.Name

  if not EntityNames[name] then
    return
  end

  if name == "GiggleCeiling" then
    table.insert(val114.Entities, val115)

    if toggles.BypassGiggle.Value then
      local hitbox = val115:WaitForChild("Hitbox")
      hitbox.CanTouch = false
    end
  elseif name == "DoorFake" or name == "FakeDoor" then
    if val115.Parent and val115:FindFirstChild("Hidden") then
      if toggles.BypassDupe.Value then
        val115:WaitForChild("Hidden").CanTouch = false
        local lock = val115:FindFirstChild("Lock")

        if lock and lock:FindFirstChild("UnlockPrompt") then
          lock.UnlockPrompt.Enabled = false
        end
      end

      if toggles.EntitiesESP.Value then
        local value26 = options.EntitiesESPAllowed and options.EntitiesESPAllowed.Value

        if not value26 or next(value26) == nil or value26.Dupe then
          Functions.AddESP({
            Object = val115, Text = "Dupe", Color = options.EntitiesESPColor.Value, })
        end
      end

      table.insert(val114.Entities, val115)
    end
  elseif name == "SideroomSpace" then
    if toggles.BypassVacuum.Value then
      val115:WaitForChild("Collision").CanCollide = true
      val115:WaitForChild("Collision").CanTouch = false
    end

    table.insert(val114.Entities, val115)
  elseif name == "GloombatEgg" or name == "GloombatEggs" or name == "GloomPile" then
    if toggles.BypassGloombatEggs.Value then
      for v149, v150 in val115:GetDescendants() do
        if v150:IsA("BasePart") then
          v150.CanTouch = false
        end
      end
    end

    local connect7 = val115.DescendantAdded:Connect(function(descendant2)
      if descendant2:IsA("BasePart") then
        descendant2.CanTouch = false
      end
    end)

    table.insert(val114.Entities, val115)
  elseif name == "Snare" then
    for v151, v152 in val115:GetDescendants() do
      if v152:IsA("BasePart") then
        v152.CanTouch = not toggles.BypassSnare.Value
      end
    end

    local connect8 = val115.DescendantAdded:Connect(function(descendant3)
      if descendant3:IsA("BasePart") then
        descendant3.CanTouch = not toggles.BypassSnare.Value
      end
    end)

    table.insert(val114.Entities, val115)

    if val115:FindFirstChild("Snare") then
      val115:WaitForChild("Snare"):WaitForChild("Roots").Transparency = 1
      val115:WaitForChild("Snare"):WaitForChild("SnareBase").Transparency = 1
    end

    if val115:FindFirstChild("Void") then
      val115.Void.Transparency = 0
      val115.Void.Color = Color3.fromRGB(76, 67, 55)
    end
  elseif name == "Figure" or name == "FigureRig" or name == "FigureRagdoll" then
    for v153, v154 in val115:GetDescendants() do
      if v154:IsA("BasePart") then
        v154.CanTouch = false
      end
    end

    table.insert(val114.Entities, val115)

    if (toggles.RemoveFigure and toggles.RemoveFigure.Value
        or toggles.RemoveFigureMines and toggles.RemoveFigureMines.Value)
      and Executor.isnetworkowner then
      local val116 = helper11()

      if val116 == "Mines" then
        for v156, v157 in val115:GetDescendants() do
          local element8 = v157

          if v157:IsA("BasePart") then
            task.spawn(function()
              if pcall(function() return Executor.isnetworkowner(element8) end) then
                element8.Position = Vector3.new(-49999, -49999, -49999)
              end
            end)
          end
        end
      elseif val116 == "OldHotel" or val116 == "Fools" then
        local currentRooms4 = workspace:FindFirstChild("CurrentRooms")

        if currentRooms4 then
          currentRooms4.ChildAdded:Wait()
        end

        for v159, v160 in val115:GetDescendants() do
          local element9 = v160

          if v160:IsA("BasePart") then
            v160.CanCollide = false

            task.spawn(function()
              while pcall(function() return Executor.isnetworkowner(element9) end) do
                element9.Position = Vector3.new(
                  math.random(-29999, 29999), math.random(-29999, 29999), math.random(-29999, 29999)
                )

                task.wait()
              end
            end)
          end
        end
      end
    end
  elseif name == "TriggerEventCollision" then
    table.insert(val114.EventTriggers, val115)
    table.insert(val114.Entities, val115)
  elseif name == "Seek_Arm" or name == "ChandelierObstruction" then
    local function helper29(val117)
      if val117:IsA("BasePart") then
        val117.CanTouch = not toggles.BypassSeekObstructions.Value
        table.insert(val114.SeekObstructions, val117)
      end
    end

    for v162, v163 in val115:GetDescendants() do
      helper29(v163)
    end

    val115.DescendantAdded:Connect(helper29)
  elseif name == "SeekFloodline" then
    val115.CanCollide = toggles.BypassSeekObstructions.Value

    local connect9 = val115:GetPropertyChangedSignal("CanCollide"):Connect(function()
      if val115.CanCollide ~= toggles.BypassSeekObstructions.Value then
        val115.CanCollide = toggles.BypassSeekObstructions.Value
      end
    end)

    val115.Destroying:Once(function() connect9:Disconnect() end)
    table.insert(val114.SeekObstructions, val115)
  elseif name == "Bridge" then
    for v164, v165 in val115:GetChildren() do
      if v165.Name == "PlayerBarrier" and v165.Size.Y == 2.75
        and (v165.Rotation.X == 0 or v165.Rotation.X == 180) then
        local clone2 = v165:Clone()
        clone2.CFrame = clone2.CFrame * CFrame.new(0, 0, -5)
        clone2.Name = tostring(math.random(100000000, 999999999))
        clone2.Size = Vector3.new(clone2.Size.X, clone2.Size.Y, 11)
        clone2.Parent = val115
        clone2.CanCollide = toggles.BypassSeekObstructions.Value
        clone2.Color = Color3.fromRGB(0, 255, 255)
        clone2.Transparency = toggles.BypassSeekObstructions.Value and 0 or 1
        clone2.Material = Enum.Material.ForceField

        table.insert(val114.SeekBridges, clone2)
      end

      task.wait()
    end
  elseif name == "MinecartRig" then
    val85.Minecart = val115
  elseif name == "RunnerNodes" then
    local function helper30(val118, val119)
      local position = (val118.CFrame + val118.CFrame.LookVector).Position
      local position2 = (val118.CFrame + val118.CFrame.LookVector * -1).Position
      return (position - val119.Position).Magnitude > (position2 - val119.Position).Magnitude
    end

    local function helper31(val120, val121)
      local dot = val120.CFrame.RightVector:Dot(val120.Position - val121.Position)

      if dot > 0.5 then
        return helper30(val120, val121) and "Right" or "Left"
      end

      if dot < -0.5 then
        return helper30(val120, val121) and "Left" or "Right"
      end

      return "Straight"
    end

    local function helper32(val122)
      local val123, huge = nil, math.huge
      local numVal = tonumber(val122.Name:split("MinecartNode")[2])

      for v168, v169 in val115:GetChildren() do
        local numVal2 = tonumber(v169.Name:split("MinecartNode")[2])

        if v169 ~= val122 and numVal2 and numVal and numVal2 > numVal then
          local magnitude = (val122.Position - v169.Position).Magnitude

          if magnitude < huge and v169:GetAttribute("DistanceBlacklist") ~= true then
            huge = magnitude
            val123 = v169
          end
        end
      end

      return val123
    end

    for v171, v172 in val115:GetChildren() do
      local numVal3 = tonumber(v172.Name:split("MinecartNode")[2])

      if v172:GetAttribute("DeathType") then
        v172:SetAttribute("DistanceBlacklist", true)
      end

      for i9 = 1, 20 do
        local findFirstChild4 = numVal3 and val115:FindFirstChild("MinecartNode" .. numVal3 + i9)

        if findFirstChild4 and findFirstChild4:GetAttribute("DeathType") ~= nil then
          v172:SetAttribute("DistanceBlacklist", true)
        end
      end

      local findFirstChild5 = numVal3 and val115:FindFirstChild("MinecartNode" .. numVal3 - 1)

      if findFirstChild5 and findFirstChild5:GetAttribute("ForceConnect") then
        v172:SetAttribute("DistanceBlacklist", nil)
      end

      task.wait()
    end

    for v174, v175 in val115:GetChildren() do
      if v175:GetAttribute("ForceConnect") then
        local val124 = helper32(v175)

        if val124 then
          v175:SetAttribute("Turn", helper31(v175, val124))
          table.insert(val114.SeekNodes, v175)
        end
      end

      task.wait()
    end
  elseif name == "DuckBoard" then
    table.insert(val114.SeekDuckBoards, val115)
  elseif name == "PathLights" then
    local val125 = {}
    local connect10 = val115.ChildAdded:Connect(function(child4) table.insert(val125, child4) end)

    for v178, v179 in val115:GetChildren() do
      table.insert(val125, v179)
    end

    local val126

    local function helper33(val127)
      if val127.Name ~= "SeekGuidingLight" or val127:GetAttribute("Highlighted") then
        return
      end

      val127:SetAttribute("Highlighted", true)

      local seekLightNode = Instance.new("Part")
      seekLightNode.Size = Vector3.one
      seekLightNode.Transparency = 1
      seekLightNode.Parent = val85.SeekNodesFolder
      seekLightNode.Anchored = true
      seekLightNode.CFrame = val127.CFrame
      seekLightNode.CanCollide = false
      seekLightNode.Name = "SeekLightNode"

      local val128 = val126 or seekLightNode
      val126 = seekLightNode
      local beam = Instance.new("Beam")

      local value27 = rawget(toggles, "ShowSeekPathColor") and options.ShowSeekPathColor.Value
        or Color3.fromRGB(0, 255, 0)

      beam.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, value27), ColorSequenceKeypoint.new(1, value27), })

      beam.FaceCamera = true
      beam.Width0 = 0.2
      beam.Width1 = 0.2
      beam.Brightness = 10
      beam.LightInfluence = 0
      beam.LightEmission = 0
      beam.Enabled = true

      local value28 = rawget(toggles, "ShowSeekPathToggle") and toggles.ShowSeekPathToggle.Value
          and 0
        or 1

      beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, value28), NumberSequenceKeypoint.new(1, value28), })

      beam.Parent = val85.SeekNodesFolder

      local instance2 = Instance.new("Attachment", seekLightNode)
      local instance3 = Instance.new("Attachment", val128)

      beam.Attachment0 = instance2
      beam.Attachment1 = instance3

      table.insert(val114.SeekHighlights, beam)
    end

    task.spawn(function()
      while task.wait() do
        local val129 = table.remove(val125, 1)

        if val129 then
          helper33(val129)
        end
      end
    end)

    table.insert(Connections, connect10)
    table.insert(val114.PathLights, val115)

    val115.Destroying:Once(function() connect10:Disconnect() end)
  elseif name == "SeekMovingNewClone" then
    local connect11 = val115.Destroying:Connect(function()
      for key6, value29 in pairs(val114.PathLights) do
      end

      if val85.SeekNodesFolder then
        val85.SeekNodesFolder:ClearAllChildren()
      end
    end)
  elseif name == "MandrakeLive" then
    local mandrake = val115:FindFirstChild("Mandrake")

    if mandrake then
      local root2 = mandrake:FindFirstChild("Root")

      if root2 then
        table.insert(val114.Entities, val115.Hole)
        table.insert(val114.Entities, root2)

        if toggles.RemoveMandrake and toggles.RemoveMandrake.Value then
          local antiMandrakeForce = root2:FindFirstChild("AntiMandrakeForce")

          if not antiMandrakeForce then
            antiMandrakeForce = Instance.new("BodyForce")
            antiMandrakeForce.Name = "AntiMandrakeForce"
            antiMandrakeForce.Parent = root2
          end

          antiMandrakeForce.Force = Vector3.new(100000, -99999999, 100000)
        end
      end
    end
  end
end

for v183, v184 in workspace:GetDescendants() do
  task.spawn(helper28, v184)
end

workspace.DescendantAdded:Connect(helper28)

local function helper34(val130)
  if val130.Name ~= "ForgetMeNotVineDoors" then
    return
  end

  if not (val130.Parent and localPlayer2 and val130.Parent.Name == localPlayer2.Name) then
    return
  end

  task.spawn(function()
    local waitForChild = val130:WaitForChild("Base", 10)

    if not waitForChild then
      return
    end

    local val131 = tick() + 15

    while waitForChild.Parent and val130.Parent and not waitForChild:GetAttribute("BaseDirection")
      and tick() < val131 do
      task.wait(0.2)
    end

    if waitForChild.Parent and val130.Parent and waitForChild:GetAttribute("BaseDirection") then
      if toggles.EntitiesESP and toggles.EntitiesESP.Value then
        Functions.AddESP({
          Object = waitForChild, Text = "Wrong Door", Color = options.EntitiesESPColor and options.EntitiesESPColor.Value
            or Color3.fromRGB(255, 0, 0), })
      end
    end
  end)
end

for v186, v187 in workspace:GetDescendants() do
  task.spawn(helper34, v187)
end

workspace.DescendantAdded:Connect(helper34)

toggles.BypassGiggle:OnChanged(function(p56)
  for index18, value30 in ipairs(val114.Entities) do
    if value30.Name == "GiggleCeiling" then
      local hitbox2 = value30:FindFirstChild("Hitbox")

      if hitbox2 then
        hitbox2.CanTouch = not p56
      end
    end
  end
end)

toggles.BypassDupe:OnChanged(function(p57)
  for v188, v189 in val114.Entities do
    if v189.Name == "DoorFake" or v189.Name == "FakeDoor" then
      v189:WaitForChild("Hidden").CanTouch = not p57

      if v189:FindFirstChild("Lock") then
        v189.Lock.UnlockPrompt.Enabled = not p57
      end
    end
  end
end)

toggles.BypassEyes:OnChanged(function(p58)
  if p58 and val85.IsEyes then
    local val132 = helper11()

    if val132 == "Fools" or val132 == "OldHotel" then
      remotesFolder2.MotorReplication:FireServer(
        0, val85.SpoofOffset == 200 and 65 or -65, 0, false
      )
    else
      remotesFolder2.MotorReplication:FireServer(-650)
    end
  end
end)

toggles.BypassLookman:OnChanged(function(p59)
  if p59 and val85.IsLookman then
    local val133 = helper11()

    if val133 == "Fools" or val133 == "OldHotel" then
      remotesFolder2.MotorReplication:FireServer(
        0, val85.SpoofOffset == 200 and 65 or -65, 0, false
      )
    else
      remotesFolder2.MotorReplication:FireServer(-650)
    end
  end
end)

toggles.BypassGloombatEggs:OnChanged(function(p60)
  for index19, value31 in ipairs(val114.Entities) do
    if value31.Name == "GloombatEgg" or value31.Name == "GloombatEggs"
      or value31.Name == "GloomPile" then
      for v192, v193 in value31:GetDescendants() do
        if v193:IsA("BasePart") then
          v193.CanTouch = not p60
        end
      end
    end
  end
end)

toggles.BypassSeekObstructions:OnChanged(function(p61)
  for index20, value32 in ipairs(val114.SeekObstructions) do
    value32.CanTouch = not p61

    if value32.Name == "SeekFloodline" then
      value32.CanCollide = p61
    end
  end

  for index21, value33 in ipairs(val114.SeekBridges) do
    value33.CanCollide = p61
    value33.Transparency = p61 and 0 or 1
  end
end)

toggles.BypassVacuum:OnChanged(function(p62)
  for v194, v195 in val114.Entities do
    if v195.Name == "SideroomSpace" then
      v195:WaitForChild("Collision").CanCollide = p62
      v195:WaitForChild("Collision").CanTouch = not p62
    end
  end
end)

toggles.BypassSnare:OnChanged(function(p63)
  for index22, value34 in ipairs(val114.Entities) do
    if value34.Name == "Snare" then
      for v196, v197 in value34:GetDescendants() do
        if v197:IsA("BasePart") then
          v197.CanTouch = not p63
        end
      end
    end
  end
end)

Groupboxes.Exploits_Removals:AddToggle("RemoveA90", {
  Text = "Remove A-90", Default = false, Tooltip = "Prevents A-90 from spawning", })

Groupboxes.Exploits_Removals:AddToggle("RemoveDread", {
  Text = "Remove Dread", Default = false, Tooltip = "Prevents Dread from spawning", })

Groupboxes.Exploits_Removals:AddDivider()

Groupboxes.Exploits_Removals:AddToggle("RemoveFootstepSounds", {
  Text = "Remove Footstep Sounds", Default = false, Tooltip = "Removes the sounds when walking", })

Groupboxes.Exploits_Removals:AddToggle("RemoveJamminMusic", {
  Text = "Remove Jammin Music", Default = false, Tooltip = "Removes the music and muffle effect from the Jammin modifier", })

Groupboxes.Exploits_Removals:AddToggle("RemoveInteractingSounds", {
  Text = "Remove Interacting Sounds", Default = false, Tooltip = "Removes the sounds when interacting with proximity prompts", })

Groupboxes.Exploits_Removals:AddToggle("RemoveHasteSound", {
  Text = "Remove Haste Sound", Default = false, Tooltip = "Mutes the ambience sound when Haste is active", })

Groupboxes.Exploits_Removals:AddToggle("RemoveClosetDelay", {
  Text = "Remove Closet Delay", Default = false, Tooltip = "Removes the short window where you can't exit out of a closet after the animation finishes.", })

toggles.RemoveA90:OnChanged(function(p64)
  local object2 = helper19()

  if not object2 then
    return
  end

  local a90 = object2:FindFirstChild("A90")

  if a90 then
    a90.Name = p64 and "A90_Disabled" or "A90"
  end
end)

toggles.RemoveDread:OnChanged(function(p65)
  local object3 = helper19()

  if not object3 then
    return
  end

  local dread = object3:FindFirstChild("Dread")

  if dread then
    dread.Name = p65 and "Dread_Disabled" or "Dread"
  end
end)

toggles.RemoveFootstepSounds:OnChanged(function(p66)
  local character6 = localPlayer2.Character

  if not character6 then
    return
  end

  for v200, v201 in character6:GetDescendants() do
    if v201:IsA("Sound") and v201.Name == "Sound" then
      v201.Volume = p66 and 0 or 1
    end
  end
end)

toggles.RemoveJamminMusic:OnChanged(function(p67)
  local playerGui4 = localPlayer2:FindFirstChildOfClass("PlayerGui")
  local mainUI3 = playerGui4 and playerGui4:FindFirstChild("MainUI")
  local initiator2 = mainUI3 and mainUI3:FindFirstChild("Initiator")
  local mainGame2 = initiator2 and initiator2:FindFirstChild("Main_Game")

  if not mainGame2 then
    return
  end

  local health = mainGame2:FindFirstChild("Health")

  if not health then
    return
  end

  local jam = health:FindFirstChild("Jam")

  if jam then
    jam.Volume = p67 and 0 or 0.45
  end
end)

toggles.RemoveInteractingSounds:OnChanged(function(p68)
  local playerGui5 = localPlayer2:FindFirstChildOfClass("PlayerGui")
  local mainUI4 = playerGui5 and playerGui5:FindFirstChild("MainUI")
  local initiator3 = mainUI4 and mainUI4:FindFirstChild("Initiator")
  local mainGame3 = initiator3 and initiator3:FindFirstChild("Main_Game")

  if not mainGame3 then
    return
  end

  local promptService = mainGame3:FindFirstChild("PromptService")

  if promptService then
    local triggered = promptService:FindFirstChild("Triggered")

    if triggered then
      triggered.Volume = p68 and 0 or 0.04
    end

    local holding = promptService:FindFirstChild("Holding")

    if holding then
      holding.Volume = p68 and 0 or 0.1
    end

    local notification = promptService:FindFirstChild("Notification")

    if notification then
      notification.Volume = p68 and 0 or 0.03
    end
  end

  local reminder = mainGame3:FindFirstChild("Reminder")

  if reminder then
    local caption = reminder:FindFirstChild("Caption")

    if caption then
      caption.Volume = p68 and 0 or 0.1
    end
  end
end)

Groupboxes.Exploits_Damage:AddToggle("NoScreechDamage", {
  Text = "No Screech Damage", Default = false, Tooltip = "Prevents Screech from hurting you", })

Groupboxes.Exploits_Damage:AddToggle("NoA90Damage", {
  Text = "No A-90 Damage", Default = false, Tooltip = "Prevents A-90 from hurting you", })

toggles.NoScreechDamage:OnChanged(function(p69)
  if not remotesFolder2 then
    return
  end

  if p69 then
    if FakeEvents.Screech_Real and FakeEvents.Screech_Real.Parent then
      FakeEvents.Screech.Parent = remotesFolder2
      FakeEvents.Screech_Real.Parent = nil
    end
  elseif FakeEvents.Screech_Real then
    FakeEvents.Screech_Real.Parent = remotesFolder2
    FakeEvents.Screech.Parent = nil
  end
end)

Groupboxes.Exploits_Damage:AddToggle("NoHaltDamage", {
  Text = "No Halt Damage", Default = false, Tooltip = "Prevents Halt from hurting you", })

toggles.NoHaltDamage:OnChanged(function(p70)
  if not remotesFolder2 then
    return
  end

  if p70 then
    if FakeEvents.Shade_Real and FakeEvents.Shade_Real.Parent then
      FakeEvents.Shade.Parent = remotesFolder2
      FakeEvents.Shade_Real.Parent = nil
    end
  elseif FakeEvents.Shade_Real then
    FakeEvents.Shade_Real.Parent = remotesFolder2
    FakeEvents.Shade.Parent = nil
  end
end)

toggles.NoA90Damage:OnChanged(function(p71)
  if not remotesFolder2 then
    return
  end

  if p71 then
    if FakeEvents.A90_Real and FakeEvents.A90_Real.Parent then
      FakeEvents.A90.Parent = remotesFolder2
      FakeEvents.A90_Real.Parent = nil
    end
  elseif FakeEvents.A90_Real then
    FakeEvents.A90_Real.Parent = remotesFolder2
    FakeEvents.A90.Parent = nil
  end
end)

Groupboxes.Exploits_Automation = element3.Exploits:AddRightGroupbox("Automation")

Groupboxes.Exploits_Automation:AddToggle("AutoUnlockPadlockToggle", {
  Text = "Auto Unlock Padlock", Default = false, Tooltip = "Instantly unlocks the room 50 padlock when you get close, but you need the books required", DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.Exploits_Automation:AddButton({
  Text = "Show Library Code", Tooltip = "Displays the current library code in a notification", DisabledTooltip = "This feature doesn't work in this floor", Callback = function()
    local functions = Functions.GetLibraryCode()

    if functions then
      library:Notify({ Title = "Library code: " .. functions, Time = 5 })
    else
      library:Notify({ Title = "Could not read library code", Time = 5 })
    end
  end, })

Groupboxes.Exploits_Automation:AddToggle("AutoBreakerBox", {
  Text = "Auto Breaker Box", Default = false, Tooltip = "Automatically solves the breaker box.", DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.Exploits_Automation:AddDropdown("BreakerBoxMethod", {
  Text = "Breaker Box Method", Values = { "Instant", "Legit" }, Default = 1, Multi = false, })

Groupboxes.Exploits_Automation:AddToggle("AutoLibraryBruteForce", {
  Text = "Auto Brute-Force Padlock", Default = false, Tooltip = "Automatically brute-forces codes in the library code when near the padlock until it finds the correct code", DisabledTooltip = "This feature doesn't work in this floor", })

if replicatedStorage:FindFirstChild("FloorReplicated")
  and replicatedStorage.FloorReplicated:FindFirstChild("ClientRemote")
  and replicatedStorage.FloorReplicated.ClientRemote:FindFirstChild("Haste") then
  local connect12 = replicatedStorage.FloorReplicated.ClientRemote.Haste.Ambience:GetPropertyChangedSignal("Playing"):Connect(function()
    if toggles.RemoveHasteSound.Value then
      replicatedStorage.FloorReplicated.ClientRemote.Haste.Ambience.Playing = false
    end
  end)
end

table.insert(Connections, workspace.DescendantAdded:Connect(function(descendant4)
  if toggles.AntiLag and toggles.AntiLag.Value and descendant4:IsA("BasePart") then
    descendant4:SetAttribute("Mat", descendant4.Material)
    descendant4.Material = "Plastic"
  end
end))

val85 = {
  UseAnimation = nil, UseAnimationBreak = nil, BreakerBoxNotified = false, BreakerBoxStartNotified = false, BreakerBoxInteracted = false, BreakerBoxFinishedNotified = false, FogInstances = {}, OldFog = nil, InLobby = false, LobbyGuardConnection = nil, RoomsAutoWalkActive = false, IsEyes = false, IsLookman = false, AnticheatDisabled = false, SeekNodesFolder = nil, AutoMinecartDucked = false, LastDuck = 0, NearestTurnNode = nil, Minecart = nil, OriginalGetMoveVector = nil, SurgeFrame = nil, KnobFarmActive = false, KnobFarmStarted = false, UILibrary = uiLibrary, RedeemingCodes = false, SpoofOffset = 0, }

val85.CodesList = {
  "67", "54", "41", "CHEDDAR BALLS", "XQC", "PENGUINZ0", "KREEKCRAFT", "ISHOWSPEED", "DANTDM", "KUBZ SCOUTS", "FIND THE TROLLFACES", "THINKNOODLES", "W", "RAGDOLL UNIVERSE", "RAGDOLL MAYHEM", "BIJUU MIKE", "8BITRYAN", "SCREECHSUCKS", "LORE", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "FIND THE TROLLFACES", "3rd", "LAZYDEVS", "RAGDOLL COMBAT", "VOCAB HAVOC", "PATHSWAP", "JUMP OVER THE BRICK", }

if character then
  task.spawn(SetupCharacterAnticheat)
end

if Executor.fireproximityprompt then
  Functions.FirePrompt = Executor.fireproximityprompt
  Functions.ForceFirePrompt = Executor.fireproximityprompt
else
  local val134 = {}
  local val135 = {}

  function Functions.FirePrompt(p72)
    if not p72:IsA("ProximityPrompt") or val135[p72] or not currentCamera then
      return
    end

    table.insert(val134, p72)
  end

  Functions.ForceFirePrompt = Functions.FirePrompt

  task.spawn(function()
    while task.wait() do
      local parent3 = table.remove(val134, 1)

      if parent3 then
        val135[parent3] = true
        local parent2 = parent3.Parent

        parent3.MaxActivationDistance = 99999
        parent3.Enabled = true
        parent3.HoldDuration = 0
        parent3.RequiresLineOfSight = false

        local part = Instance.new("Part")
        part.Parent = workspace
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Anchored = true
        part.Transparency = 1
        part.Size = Vector3.new(0.001, 0.001, 0.001)
        part.Position = currentCamera.CFrame:ToWorldSpace(CFrame.new(0, 0, -0.1)).Position

        if parent3 and parent2 then
          pcall(function() parent3.Parent = part end)
          local val136, val137 = false, false

          local connect13 = proximityPromptService.PromptShown:Connect(function(p73)
            if p73 == parent3 then
              val136 = true
            end
          end)

          local connect14 = parent3.Triggered:Connect(function() val137 = true end)
          local count3 = 0

          while not val136 and count3 < 5 do
            count3 = count3 + 1
            task.wait()
          end

          local count4 = 0

          while not val137 and count4 < 5 do
            parent3:InputHoldBegin()
            parent3:InputHoldEnd()

            count4 = count4 + 1
            task.wait()
          end

          parent3.MaxActivationDistance = parent3.MaxActivationDistance
          parent3.Enabled = parent3.Enabled
          parent3.HoldDuration = parent3.HoldDuration
          parent3.RequiresLineOfSight = parent3.RequiresLineOfSight

          pcall(function() parent3.Parent = parent2 end)
          task.wait()
          connect13:Disconnect()
          connect14:Disconnect()
        else
          part:Destroy()
        end

        val135[parent3] = nil
      end
    end
  end)
end

function Functions.HasItem(p74, p75)
  if not p75 and localPlayer2.Backpack:FindFirstChild(p74) then
    return localPlayer2.Backpack:FindFirstChild(p74)
  elseif character:FindFirstChild(p74) then
    return character:FindFirstChild(p74)
  end

  return nil
end

function Functions.GetLibraryCode()
  local libraryHintPaper = character:FindFirstChild("LibraryHintPaper")
    or character:FindFirstChild("LibraryHintPaperHard")
    or localPlayer2.Backpack:FindFirstChild("LibraryHintPaper")
    or localPlayer2.Backpack:FindFirstChild("LibraryHintPaperHard")

  if libraryHintPaper and libraryHintPaper:FindFirstChild("UI") then
    local val138 = {}

    for i10 = 1, CurrentFloor and tostring(CurrentFloor):find("Fools") and 10 or 5 do
      val138[i10] = "_"
    end

    local getChildren2 = localPlayer2.PlayerGui:FindFirstChild("PermUI")
        and localPlayer2.PlayerGui.PermUI:FindFirstChild("Hints")
        and localPlayer2.PlayerGui.PermUI.Hints:GetChildren()
      or {}

    local getChildren3 = libraryHintPaper.UI:GetChildren()

    for index23, value35 in ipairs(getChildren2) do
      for index24, value36 in ipairs(getChildren3) do
        if value35:IsA("ImageLabel") and value36:IsA("ImageLabel")
          and value35.ImageRectOffset == value36.ImageRectOffset
          and val138[tonumber(value36.Name)] then
          val138[tonumber(value36.Name)] = value35.TextLabel.Text
        end
      end
    end

    return table.concat(val138)
  end

  return CurrentFloor and tostring(CurrentFloor):find("Fools") and "__________" or "_____"
end

function Functions.HandleHidingTransparency(p76)
  local val139 = {}

  for v209, v210 in p76:GetDescendants() do
    if v210:IsA("BasePart") then
      v210:SetAttribute("Transparency_Old", v210.Transparency)
      table.insert(val139, v210)
    end

    if v210.Name == "HiddenPlayer" then
      local element10 = v210

      local connect15 = element10:GetPropertyChangedSignal("Value"):Connect(function()
        for index25, value37 in ipairs(val139) do
          if value37:GetAttribute("Transparency_Old") then
            TweenService:Create(value37, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
              Transparency = element10.Value == character
                  and toggles.TransparentHidingSpotsToggle.Value
                  and options.TransparentHidingSpotsSlider.Value
                or value37:GetAttribute("Transparency_Old"), }):Play()
          end
        end
      end)

      table.insert(Connections, connect15)

      p76.Destroying:Once(function()
        connect15:Disconnect()
        local v212 = TableFind(Connections, connect15)
      end)
    end
  end
end

function Functions.GetMinecart()
  return currentCamera:FindFirstChild("MinecartRig") ~= nil
end

function Functions.GetNearestTurnNode()
  local element11 = { Distance = math.huge, Object = nil }

  for index26, value38 in ipairs(val114.SeekNodes) do
    local distanceFromCharacter = localPlayer2:DistanceFromCharacter(value38.Position)

    if distanceFromCharacter < options.AutoSteerMinecartTurnDistance.Value
      and distanceFromCharacter < element11.Distance then
      element11.Distance = distanceFromCharacter
      element11.Object = value38
    end
  end

  return element11.Object
end

function Functions.GetNearestDuckBoard()
  local element12 = { Distance = math.huge, Object = nil }

  for index27, value39 in ipairs(val114.SeekDuckBoards) do
    if value39.PrimaryPart then
      local distanceFromCharacter2 = localPlayer2:DistanceFromCharacter(value39.PrimaryPart.Position)

      if distanceFromCharacter2 < options.AutoSteerMinecartDuckDistance.Value
        and distanceFromCharacter2 < element12.Distance then
        element12.Distance = distanceFromCharacter2
        element12.Object = value39
      end
    end
  end

  return element12.Object
end

function Functions.SendChat(p77)
  local defaultChat = replicatedStorage:FindFirstChild("DefaultChatSystemEvents") or Instance.new("Folder")
  local sayMessage = defaultChat:FindFirstChild("SayMessageRequest") or Instance.new("RemoteEvent")
  sayMessage:FireServer(p77, "All")

  local textChannels = TextChatService:FindFirstChild("TextChannels")
  local rbxGeneral = textChannels and textChannels:FindFirstChild("RBXGeneral") or Instance.new("TextChannel")
  rbxGeneral:SendAsync(p77)
end

function Functions.GetNearestHidingSpot()
  local element13 = { Distance = math.huge, Object = nil }

  for index28, value40 in ipairs(val114.HidingSpots) do
    if value40.PrimaryPart and value40:FindFirstChild("HidePrompt") then
      local distanceFromCharacter3 = localPlayer2:DistanceFromCharacter(value40.PrimaryPart.Position)

      if distanceFromCharacter3 < element13.Distance
        and distanceFromCharacter3 < value40.HidePrompt.MaxActivationDistance
        and value40.PrimaryPart.Position.Y > -10 then
        local findFirstChild6 = value40:FindFirstChild("HiddenPlayer", true)

        if findFirstChild6 and not findFirstChild6.Value then
          element13.Distance = distanceFromCharacter3
          element13.Object = value40
        end
      end
    end
  end

  return element13.Object
end

function Functions.GetNearestEntity(p78, p79)
  local val140 = {
    RushMoving = 85, AmbushMoving = 150, A60 = 125, A120 = 85, GlitchRush = 90, GlitchAmbush = 175, BackdoorRush = 85, CustomEntity = 85, }

  local element14 = { Distance = math.huge, Object = nil }

  for v218, v219 in workspace:GetChildren() do
    if v219 and val140[v219.Name] and v219.PrimaryPart then
      local element15 = EntityNotifyData[v219.Name]

      if not (p79 and element15 and p79[element15.Alias]) then
        local distanceFromCharacter4 = localPlayer2:DistanceFromCharacter(v219.PrimaryPart.Position)

        if distanceFromCharacter4 < val140[v219.Name] and distanceFromCharacter4 < element14.Distance then
          if not p78 or v219:GetAttribute("Inactive") ~= true then
            element14.Distance = distanceFromCharacter4
            element14.Object = v219
          end
        end
      end
    end
  end

  return element14.Object
end

local function helper35()
  if not Executor.hookmetamethod or not Executor.newcclosure or not Executor.getnamecallmethod then
    return
  end

  MainHook = Executor.hookmetamethod(game, "__namecall", Executor.newcclosure(function(p80, ...)
    local val141 = { ... }
    local executor = Executor.getnamecallmethod()

    if p80.Name == "MotorReplication" and executor == "FireServer" then
      if toggles.BypassEyes.Value and val85.IsEyes
        or toggles.BypassLookman.Value and val85.IsLookman then
        local currentFloor2 = CurrentFloor

        if currentFloor2 == "Fools" or currentFloor2 == "OldHotel" then
          val141[1] = 0
          val141[2] = val85.SpoofOffset == 200 and 65 or -65
          val141[3] = 0
          val141[4] = false
        else
          val141[1] = -650
        end
      end
    end

    if p80.Name == "Crouch" and executor == "FireServer" then
      if toggles.Godmode and toggles.Godmode.Value then
        val141[1] = true
      end

      val141[2] = true
    end

    if toggles.AutoHeartbeatMinigame and toggles.AutoHeartbeatMinigame.Value
      and executor == "FireServer" then
      if p80.Name == "ClutchHeartbeat" then
        return MainHook(p80, true)
      end

      if p80.Name == "HideMonster" then
        return MainHook(p80, true)
      end
    end

    if toggles.AntiDrone and toggles.AntiDrone.Value and executor == "FireServer" then
      if p80.Name == "ShoulderChecked" or p80.Name == "WalkedInto" then
        return
      end
    end

    if toggles.AntiRansom and toggles.AntiRansom.Value and executor == "FireServer" then
      if p80.Name == "RansomAttack" then
        val141[1] = "didnt"
      end
    end

    if toggles.AntiScribbles and toggles.AntiScribbles.Value and executor == "FireServer" then
      if p80.Name == "IfYoureExploitingDeleteThis" then
        return
      end
    end

    local minecartTeleportState = val85.MinecartTeleportState

    if minecartTeleportState and executor == "FireServer"
      and p80 == minecartTeleportState.MinecartPos then
      if minecartTeleportState.LatestRoom < 49 then
        local element16 = minecartTeleportState.GetDoor()

        if element16 then
          local getPivot = element16:GetPivot()

          local minecartRig = workspace.CurrentCamera
            and workspace.CurrentCamera:FindFirstChild("MinecartRig")

          if minecartRig then
            minecartRig:PivotTo(getPivot)
          end

          pcall(function() element16.ClientOpen:FireServer() end)
          val141[1] = getPivot
        end
      else
        if minecartTeleportState.DecodeHook and minecartTeleportState.RestoreDecode then
          pcall(function() minecartTeleportState.RestoreDecode(minecartTeleportState.Decode) end)
        end

        if minecartTeleportState.LatestRoomConn then
          pcall(function() minecartTeleportState.LatestRoomConn:Disconnect() end)
        end

        val85.MinecartTeleportState = nil
      end
    end

    return MainHook(p80, table.unpack(val141))
  end))

  OtherHook = Executor.hookmetamethod(game, "__index", Executor.newcclosure(function(p81, p82)
    local val142 = OtherHook(p81, p82)

    if p82 == "MoveDirection" and p81 == humanoid and val85.RoomsAutoWalkActive
      and toggles.RoomsAutoWalkSpoofFootsteps.Value and CurrentFloor == "Rooms"
      and not (character and character:GetAttribute("Hiding")) then
      if humanoidRootPart then
        local velocity = humanoidRootPart.Velocity

        if velocity.Magnitude > 0.1 then
          return velocity.Unit
        end

        return humanoidRootPart.CFrame.LookVector
      end

      return val142
    end

    return val142
  end))
end

helper35()

local function helper36(val143)
  local currentRooms5 = workspace:FindFirstChild("CurrentRooms")

  if currentRooms5 and val143.Parent == currentRooms5 then
    local firedamp = val143:GetAttribute("Firedamp")
    val143:SetAttribute("Firedamp_Old", firedamp ~= nil and firedamp or false)

    if toggles.DisableFiredampEffect.Value then
      val143:SetAttribute("Firedamp", false)
    end
  end

  local name2 = val143.Name

  if name2 == "Padlock" then
    Connections.PadlockConnection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if val143.PrimaryPart then
        local distanceFromCharacter5 = localPlayer2:DistanceFromCharacter(val143.PrimaryPart.Position)

        if toggles.AutoUnlockPadlockToggle.Value then
          local functions2 = Functions.GetLibraryCode()

          if functions2 and tonumber(functions2) and distanceFromCharacter5 < 50 then
            remotesFolder2.PL:FireServer(functions2)
          end
        end

        if toggles.AutoLibraryBruteForce.Value and distanceFromCharacter5 < 50 then
          local functions3 = Functions.GetLibraryCode()

          if functions3 and string.find(functions3, "_") then
            local text2 = ""

            for i11 = 1, #functions3 do
              local substring = string.sub(functions3, i11, i11)
              text2 = text2 .. (substring == "_" and math.random(0, 9) or substring)
            end

            if remotesFolder2 and remotesFolder2:FindFirstChild("PL") then
              remotesFolder2.PL:FireServer(text2)
            end

            val85.BruteForceCount = (val85.BruteForceCount or 0) + 1

            if val85.BruteForceCount % 750 == 0 then
              task.spawn(function()
                library:Notify({
                  Title = "Brute-force: checked " .. val85.BruteForceCount .. " codes", Description = "Not found yet", Time = 2, })
              end)
            end
          end
        end
      end
    end)

    val143.Destroying:Once(function()
      if val85.BruteForceCount and val85.BruteForceCount > 0 then
        task.spawn(function()
          library:Notify({
            Title = "Padlock code found after " .. val85.BruteForceCount .. " attempts!", Description = "yay", Time = 5, })
        end)
      end

      val85.BruteForceCount = nil

      if Connections.PadlockConnection then
        Connections.PadlockConnection:Disconnect()
        Connections.PadlockConnection = nil
      end
    end)
  elseif name2 == "ElevatorBreaker" then
    if toggles.AutoBreakerBox.Value and not val85.BreakerBoxNotified then
      val85.BreakerBoxNotified = true
    end

    local code = val143:WaitForChild("SurfaceGui"):WaitForChild("Frame"):WaitForChild("Code")

    local function waitLoop()
      if toggles.AutoBreakerBox.Value then
        local value41 = options.BreakerBoxMethod and options.BreakerBoxMethod.Value or "Instant"

        if value41 == "Instant" then
          task.spawn(function()
            task.wait(1)

            pcall(function()
              if remotesFolder2 and remotesFolder2:FindFirstChild("EBF") then
                remotesFolder2.EBF:FireServer()
              end
            end)
          end)
        elseif value41 == "Legit" then
          local numVal4 = tonumber(code.Text)

          if not numVal4 then
            return
          end

          for v226, v227 in val143:GetDescendants() do
            if v227.Name == "BreakerSwitch" and v227:GetAttribute("ID") == numVal4 then
              local backgroundTransparency = code:WaitForChild("Frame").BackgroundTransparency
              local prismaticConstraint = v227:FindFirstChild("PrismaticConstraint")
              local light = v227:FindFirstChild("Light")
              local sound = v227:FindFirstChild("Sound")

              if backgroundTransparency == 0 then
                if v227:GetAttribute("Enabled") then
                  return
                end

                v227:SetAttribute("Enabled", true)

                if prismaticConstraint then
                  prismaticConstraint.TargetPosition = -0.2
                end

                if light then
                  light.Material = Enum.Material.Neon
                  local findFirstChild7 = light:FindFirstChild("Spark", true)

                  if findFirstChild7 then
                    findFirstChild7:Emit(1)
                  end
                end

                if sound then
                  sound:Play()
                end
              elseif backgroundTransparency == 1 then
                if not v227:GetAttribute("Enabled") then
                  return
                end

                v227:SetAttribute("Enabled", false)

                if prismaticConstraint then
                  prismaticConstraint.TargetPosition = 0.2
                end

                if light then
                  light.Material = Enum.Material.Glass
                end

                if sound then
                  sound:Play()
                end
              end

              break
            end
          end
        end

        if not val85.BreakerBoxStartNotified then
          val85.BreakerBoxStartNotified = true
        end
      end

      val85.BreakerBoxInteracted = true
    end

    Connections.BreakerConnection = code:GetPropertyChangedSignal("Text"):Connect(waitLoop)
    val85.RunBreakerFunc = waitLoop
    val143.Destroying:Once(function() val85.RunBreakerFunc = nil end)
  elseif name2 == "ElevatorCar" then
    local connect16 = val143.DescendantAdded:Connect(function(descendant5)
      if toggles.AutoBreakerBox.Value and descendant5.Name == "TouchInterest"
        and not val85.BreakerBoxFinishedNotified then
        val85.BreakerBoxFinishedNotified = true
      end
    end)

    val143.Destroying:Once(function() connect16:Disconnect() end)
  end
end

_promptTriggerLock = false

toggles.InfiniteCrucifix:OnChanged(function(p84)
  if not p84 then
    return
  end

  if val85.InfCrucifixRunning then
    return
  end

  val85.InfCrucifixRunning = true

  task.spawn(function()
    local val144 = {
      RushMoving = 49, AmbushMoving = 50, A60 = 49, A120 = 50, BackdoorRush = 49, }

    local function iterate2()
      for key7 in pairs(val144) do
        local findFirstChild8 = workspace:FindFirstChild(key7)
          or workspace:FindFirstChild(key7, true)

        if findFirstChild8 and (findFirstChild8:IsA("BasePart") or findFirstChild8:IsA("Model")) then
          return findFirstChild8, key7
        end
      end
    end

    local function helper37()
      local object4, val145 = iterate2()

      local humanoidRootPart3 = localPlayer2.Character
        and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

      if not object4 or not humanoidRootPart3 then
        return false
      end

      return (object4:GetPivot().Position - humanoidRootPart3.Position).Magnitude < val144[val145]
    end

    local function helper38(val146)
      local drops3 = workspace:FindFirstChild("Drops")

      if drops3 then
        for v231, v232 in drops3:GetChildren() do
          if v232.Name == "Crucifix" then
            return v232
          end
        end
      end

      for v233, v234 in workspace:GetDescendants() do
        if v234:IsA("Model") and v234.Name == "Crucifix"
          and not v234:IsDescendantOf(localPlayer2.Character) then
          if (v234:GetPivot().Position - val146.Position).Magnitude < 25 then
            return v234
          end
        end
      end
    end

    while toggles.InfiniteCrucifix.Value do
      task.wait(0.1)
      local character7 = localPlayer2.Character
      local tool2 = character7 and character7:FindFirstChildOfClass("Tool")

      if tool2 and tool2.Name == "Crucifix" and helper37() then
        local humanoidRootPart4 = character7:FindFirstChild("HumanoidRootPart")

        if humanoidRootPart4 and iterate2() and helper11() ~= "Rooms" then
          remotesFolder2.DropItem:FireServer(tool2)
          task.wait(0.1)
          local val147

          for i12 = 1, 40 do
            val147 = helper38(humanoidRootPart4)

            if val147 then
              break
            end

            task.wait(0.1)
          end

          if val147 then
            task.wait(0.4)

            local findFirstChildOfClass = val147:FindFirstChildOfClass("ProximityPrompt", true)
              or val147:FindFirstChild("ModulePrompt", true)

            if findFirstChildOfClass then
              pcall(function() Functions.FirePrompt(findFirstChildOfClass) end)
            end
          end
        end

        task.wait(2)
      end
    end

    val85.InfCrucifixRunning = false
  end)
end)

toggles.AutoBreakerBox:OnChanged(function(p86)
  if not p86 then
    return
  end

  if val85.RunBreakerFunc then
    if val85.BreakerBoxInteracted then
      val85.RunBreakerFunc()
    end
  elseif currentRooms:FindFirstChild("ElevatorBreaker", true) then
    if not val85.BreakerBoxInteracted then
      if not val85.BreakerBoxNotified then
        val85.BreakerBoxInteracted = true
      end
    else
      task.spawn(function()
        task.wait(1)

        pcall(function()
          if remotesFolder2 and remotesFolder2:FindFirstChild("EBF") then
            remotesFolder2.EBF:FireServer()
          end
        end)
      end)
    end
  end
end)

Groupboxes.Character:AddSlider("Walkspeed", {
  Text = "Walkspeed", Min = 16, Max = 150, Default = 16, Rounding = 0, Compact = true, })

Groupboxes.Character:AddDropdown("SpeedBypassMode", {
  Text = "Speed Bypass", Values = { "Default", "Boost" }, Default = 1, Multi = false, })

Groupboxes.Character:AddToggle("FlyToggle", { Text = "Fly", Default = false })

toggles.FlyToggle:AddKeyPicker("FlyKeybind", {
  Text = "Fly", Default = "F", Mode = "Toggle", SyncToggleState = true, })

Groupboxes.Character:AddSlider("FlySpeed", {
  Text = "Fly Speed", Min = 25, Max = 150, Default = 60, Rounding = 0, Compact = true, })

Groupboxes.Character:AddDivider()

Groupboxes.Character:AddToggle("RemoveAcceleration", {
  Text = "Remove Acceleration", Default = false, Tooltip = "Removes 'sliding' when moving at high speeds", })

Groupboxes.Character:AddDivider()

Groupboxes.Character:AddToggle("EnableCharacterJump", {
  Text = "Enable Jumping", Default = false, Tooltip = "Enables the doors jumping feature", })

Groupboxes.Character:AddToggle("InfiniteJumps", {
  Text = "Infinite Jump", Default = false, Tooltip = "Allows you to jump mid-air", })

Groupboxes.Character:AddDivider()

Groupboxes.Character:AddToggle("EnableCharacterSlide", {
  Text = "Enable Sliding", Default = false, Tooltip = "Enables the doors sliding feature (only at speeds above 20)", })

Groupboxes.Character:AddToggle("Noclip", {
  Text = "Noclip", Default = false, Tooltip = "Allows you to go through walls (rubberbands you)", })

toggles.Noclip:AddKeyPicker("NoclipKeybind", {
  Text = "Noclip", Default = "N", Mode = "Toggle", SyncToggleState = true, })

Groupboxes.Character:AddToggle("Phase", {
  Text = "Phase", Default = false, Tooltip = "Slowly floats you forward with noclip enabled for no rubberbanding", })

toggles.Phase:AddKeyPicker("PhaseKeybind", {
  Text = "Phase", Default = "T", Mode = "Toggle", SyncToggleState = true, })

Groupboxes.Other:AddToggle("AnticheatManipulation", {
  Text = "Anticheat Manipulation", Default = false, Tooltip = "Makes your character fly forwards fast to trick the anticheat to send you through walls", })

toggles.AnticheatManipulation:AddKeyPicker("AnticheatManipulationKeybind", {
  Text = "Anticheat Manipulation", Default = "B", Mode = "Hold", SyncToggleState = true, })

Groupboxes.Other:AddToggle("AutoInteract", {
  Text = "Auto Interact", Default = false, Tooltip = "Auto interacts with prompts near you (you can change it to be a hold keybind)", DisabledTooltip = "Your executor doesn't support this feature :(", })

toggles.AutoInteract:AddKeyPicker("AutoInteractKeybind", {
  Text = "Auto Interact", Default = "R", Mode = "Toggle", SyncToggleState = true, })

Groupboxes.Other:AddDropdown("AutoInteractIgnoreList", {
  Text = "Interact Blacklist", Values = { "Locks", "Glitch Fragments", "Dropped Items", "Mandrake" }, Default = { "Dropped Items" }, Multi = true, AllowNull = true, })

Groupboxes.Other:AddDivider()

Groupboxes.Other:AddToggle("Godmode", {
  Text = "Godmode", Default = false, Tooltip = "Makes your character appear underground on the server, protecting you from rush-like entities.", })

toggles.Godmode:AddKeyPicker("GodmodeKeybind", {
  Text = "Godmode", Default = "G", Mode = "Toggle", SyncToggleState = true, })

toggles.Godmode:OnChanged(function(p87)
  if not character or not humanoid or not humanoidRootPart then
    return
  end

  if val85 and not val85.OriginalC1 then
    local lowerTorso2 = character:FindFirstChild("LowerTorso")
    local root3 = lowerTorso2 and lowerTorso2:FindFirstChild("Root")

    if root3 then
      val85.OriginalC1 = root3.C1
    end
  end
end)

Groupboxes.Other:AddDropdown("GodmodeMethod", {
  Text = "Godmode Method", Values = { "Always enabled", "On entity spawn" }, Default = "On entity spawn", Tooltip = "Always enabled keeps godmode active while the toggle is on. On entity spawn only activates it when a listed entity exists.", })

Groupboxes.Other:AddToggle("NotifyVulnerable", {
  Text = "Notify When Vulnerable", Default = false, Tooltip = "Notifies you when your character moves 3+ studs upward", })

Groupboxes.Other:AddToggle("AutoClosetToggle", {
  Text = "Auto Closet", Default = false, Tooltip = "Automatically hides in a closet next to you when a rush-like entity is near", })

toggles.AutoClosetToggle:AddKeyPicker("AutoClosetKeybind", {
  Text = "Auto Closet", Default = "H", Mode = "Toggle", SyncToggleState = true, })

Groupboxes.Other:AddDropdown("AutoClosetEntityList", {
  Text = "Ignore List", Values = { "Rush", "Ambush", "Blitz", "A-60", "A-120", "Glitch Rush", "Glitch Ambush" }, Multi = true, AllowNull = true, })

Groupboxes.Other:AddDivider()

Groupboxes.Other:AddToggle("DoorReachToggle", {
  Text = "Door Reach", Default = false, Tooltip = "Increases your door opening reach by your chosen amount", })

Groupboxes.Other:AddSlider("DoorReachDistance", {
  Text = "Door Reach Distance", Min = 15, Max = 75, Default = 45, Rounding = 0, Compact = true, Suffix = " studs", })

Fly = { Connection = nil, Body = nil }
local val148 = nil

local function helper39()
  if BypassConnection then
    BypassConnection:Disconnect()
    BypassConnection = nil
  end

  local collisionClone2 = character and character:FindFirstChild("CollisionClone")

  if collisionClone2 then
    collisionClone2:Destroy()
  end

  if not toggles.FlyToggle.Value and humanoid then
    humanoid.WalkSpeed = 16
  end

  if character then
    character:SetAttribute("SpeedBoost", 0)
    character:SetAttribute("SpeedBoostBehind", 0)
    character:SetAttribute("SpeedBoostExtra", 0)
    character:SetAttribute("SpeedBoostMod", 0)
    character:SetAttribute("AntiSpeed", nil)
    character:SetAttribute("Antispeed", nil)
    character:SetAttribute("SpeedBypass", nil)
  end

  if humanoid then
    humanoid:SetAttribute("AntiSpeed", nil)
    humanoid:SetAttribute("Antispeed", nil)
  end

  pcall(function()
    local crouch3 = remotesFolder2 and remotesFolder2:FindFirstChild("Crouch")

    if crouch3 then
      crouch3:FireServer(false, false)
    end
  end)
end

local function helper40()
  if SpeedConnection then
    SpeedConnection:Disconnect()
    SpeedConnection = nil
  end
end

local function helper41()
  helper39()

  if not toggles.FlyToggle.Value and options.Walkspeed.Value == 16 then
    return
  end

  local crouch4 = remotesFolder2 and remotesFolder2:FindFirstChild("Crouch")

  if collisionPart and not character:FindFirstChild("CollisionClone") then
    local collisionClone3 = collisionPart:Clone()
    collisionClone3.Name = "CollisionClone"
    collisionClone3.RootPriority = 127
    collisionClone3.Anchored = false
    collisionClone3.CanCollide = false

    local collisionCrouch2 = collisionClone3:FindFirstChild("CollisionCrouch")

    if collisionCrouch2 then
      collisionCrouch2:Destroy()
    end

    collisionClone3.Parent = character
  end

  BypassConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not character or not humanoidRootPart or not humanoid then
      helper39()
      return
    end

    if crouch4 then
      crouch4:FireServer(true, true)
    end

    if not toggles.FlyToggle.Value then
      local collisionClone4 = character:FindFirstChild("CollisionClone")

      if collisionClone4 then
        collisionClone4.Massless = true
      end
    end
  end)
end

local function helper42()
  helper40()

  SpeedConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not humanoid or not humanoidRootPart or not character then
      return
    end

    local value42 = options.Walkspeed.Value

    if value42 == 16 then
      return
    end

    if not BypassConnection then
      helper41()
    end

    character:SetAttribute("AntiSpeed", true)
    character:SetAttribute("Antispeed", true)
    character:SetAttribute("SpeedBypass", true)

    humanoid:SetAttribute("AntiSpeed", true)
    humanoid:SetAttribute("Antispeed", true)
    humanoid.WalkSpeed = value42

    local moveDirection = humanoid.MoveDirection

    if moveDirection.Magnitude > 0 then
      humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
        moveDirection.X * value42, humanoidRootPart.AssemblyLinearVelocity.Y, moveDirection.Z * value42
      )
    end
  end)
end

local function helper43()
  helper40()
  helper39()

  if not toggles.FlyToggle.Value and options.Walkspeed.Value == 16 then
    return
  end

  SpeedConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not humanoid or not humanoidRootPart or not character then
      return
    end

    local value43 = options.Walkspeed.Value

    character:SetAttribute("SpeedBoost", value43 - 16)
    character:SetAttribute("SpeedBoostBehind", 0)
    character:SetAttribute("SpeedBoostExtra", 0)

    if remotesFolder2 and remotesFolder2:FindFirstChild("Crouch") then
      remotesFolder2.Crouch:FireServer(true, true)
    end

    if value43 ~= 16 then
      humanoid.WalkSpeed = value43
      local moveDirection2 = humanoid.MoveDirection

      if moveDirection2.Magnitude > 0 then
        humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
          moveDirection2.X * value43, humanoidRootPart.AssemblyLinearVelocity.Y, moveDirection2.Z * value43
        )
      end
    end
  end)
end

local function onEvent2()
  if Fly.Connection then
    Fly.Connection:Disconnect()
    Fly.Connection = nil
  end

  if Fly.Body then
    Fly.Body:Destroy()
    Fly.Body = nil
  end

  if humanoidRootPart then
    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
  end

  if humanoid then
    humanoid.PlatformStand = false
  end
end

function helper15()
  onEvent2()

  if not toggles.FlyToggle.Value or not humanoidRootPart then
    onEvent2()
    return
  end

  Fly.Body = Instance.new("BodyVelocity")
  Fly.Body.MaxForce = Vector3.new(9000000000, 9000000000, 9000000000)
  Fly.Body.P = math.huge
  Fly.Body.Parent = humanoidRootPart

  Fly.Connection = runService.RenderStepped:Connect(function()
    if _Unloading then
      return
    end

    if not toggles.FlyToggle.Value or not humanoid then
      onEvent2()
      return
    end

    local zero = Vector3.zero
    local moveDirection3 = humanoid.MoveDirection

    if moveDirection3.Magnitude > 0 then
      local lookVector = currentCamera.CFrame.LookVector
      local rightVector = currentCamera.CFrame.RightVector
      local dot2 = moveDirection3:Dot(lookVector)
      local dot3 = moveDirection3:Dot(rightVector)
      zero = lookVector * dot2 + rightVector * dot3
    end

    if userInputService:IsKeyDown(Enum.KeyCode.Space) then
      zero = zero + Vector3.yAxis
    end

    if userInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
      zero = zero - Vector3.yAxis
    end

    if zero.Magnitude > 0 then
      zero = zero.Unit
    end

    Fly.Body.Velocity = zero * options.FlySpeed.Value
  end)
end

local function helper44()
  local humanoidRootPart5 = character and character:FindFirstChild("HumanoidRootPart")

  if not humanoidRootPart5 then
    return nil
  end

  local val149, huge2 = nil, math.huge

  local function helper45(val150)
    if (val150.Name == "ArchivesOfficeChair" or val150.Name == "StairwellOfficeChair")
      and val150:IsA("Model") then
      local collider = val150:FindFirstChild("Collider") or val150.PrimaryPart
        or val150:FindFirstChildWhichIsA("BasePart")

      if collider and collider:IsA("BasePart") then
        local magnitude2 = (humanoidRootPart5.Position - collider.Position).Magnitude

        if magnitude2 < huge2 then
          huge2 = magnitude2
          val149 = val150
        end
      end
    end
  end

  local misc = workspace:FindFirstChild("Misc")

  if misc then
    for index29, value44 in ipairs(misc:GetDescendants()) do
      helper45(value44)
    end
  end

  local currentRooms6 = workspace:FindFirstChild("CurrentRooms")

  if currentRooms6 then
    for index30, value45 in ipairs(currentRooms6:GetChildren()) do
      local assets = value45:FindFirstChild("Assets")

      if assets then
        for index31, value46 in ipairs(assets:GetChildren()) do
          helper45(value46)
        end
      end
    end
  end

  return val149
end

local function helper46()
  local element17 = val148

  if not element17 then
    return
  end

  if element17.movement then
    element17.movement:Disconnect()
  end

  if element17.pollSeat then
    element17.pollSeat:Disconnect()
  end

  if element17.inputBegan then
    element17.inputBegan:Disconnect()
  end

  if element17.inputEnded then
    element17.inputEnded:Disconnect()
  end

  if element17.mouseInput then
    element17.mouseInput:Disconnect()
  end

  pcall(function() runService:UnbindFromRenderStep("ChairBypassCamera") end)
  pcall(function() ContextActionService:UnbindAction("ChairBypassBlockExit") end)

  if element17.originalCollision then
    for key8, value47 in pairs(element17.originalCollision) do
      if key8 and key8.Parent then
        key8.CanCollide = value47
      end
    end
  end

  if element17.collider then
    pcall(function()
      element17.collider.AssemblyLinearVelocity = element17.oldVelocity
      element17.collider.AssemblyAngularVelocity = element17.oldAngularVelocity
    end)

    if element17.chair and element17.chair.Parent then
      local humanoidRootPart6 = character and character:FindFirstChild("HumanoidRootPart")

      if humanoidRootPart6 and element17.collider.Parent then
        local element18 = element17.collider.CFrame * CFrame.new(3, 0, 0)
        humanoidRootPart6.CFrame = CFrame.lookAt(element18.Position, element17.collider.Position)
      end
    end
  end

  if element17.oldCameraType then
    pcall(function()
      workspace.CurrentCamera.CameraType = element17.oldCameraType
      workspace.CurrentCamera.CameraSubject = element17.oldCameraSubject
      userInputService.MouseBehavior = element17.oldMouseBehavior or Enum.MouseBehavior.Default
    end)
  end

  d_ = nil
  val148 = nil
end

local function helper47()
  local element19 = helper44()

  if not element19 then
    return false
  end

  local collider2 = element19:FindFirstChild("Collider") or element19.PrimaryPart
    or element19:FindFirstChildWhichIsA("BasePart")

  if not collider2 or not collider2:IsA("BasePart") then
    return false
  end

  helper46()

  local element20 = {
    chair = element19, collider = collider2, held = {}, originalCollision = {}, oldVelocity = collider2.AssemblyLinearVelocity, oldAngularVelocity = collider2.AssemblyAngularVelocity, oldCameraType = workspace.CurrentCamera.CameraType, oldCameraSubject = workspace.CurrentCamera.CameraSubject, oldMouseBehavior = userInputService.MouseBehavior, cameraYaw = 0, cameraPitch = 0, }

  local lookVector2 = workspace.CurrentCamera.CFrame.LookVector

  element20.cameraYaw = math.atan2(-lookVector2.X, -lookVector2.Z)
  element20.cameraPitch = math.asin(math.clamp(lookVector2.Y, -1, 1))

  val148 = element20
  d_ = element19

  pcall(function()
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    workspace.CurrentCamera.CameraSubject = humanoid
  end)

  for index32, value48 in ipairs(element19:GetDescendants()) do
    if value48:IsA("BasePart") then
      element20.originalCollision[value48] = value48.CanCollide
      value48.CanCollide = false
    end
  end

  pcall(function()
    ContextActionService:BindActionAtPriority("ChairBypassBlockExit", function(p89, p90, p91)
      if p91.KeyCode == Enum.KeyCode.LeftControl then
        if p90 == Enum.UserInputState.Begin then
          toggles.ArchiveChairFly:SetValue(false)
        end

        return Enum.ContextActionResult.Sink
      end

      if p91.KeyCode == Enum.KeyCode.Space or p91.KeyCode == Enum.KeyCode.LeftShift
        or p91.KeyCode == Enum.KeyCode.RightShift then
        if p90 == Enum.UserInputState.Begin then
          element20.held[p91.KeyCode] = true
        elseif p90 == Enum.UserInputState.End or p90 == Enum.UserInputState.Cancel then
          element20.held[p91.KeyCode] = nil
        end
      end

      return Enum.ContextActionResult.Sink
    end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.LeftControl)
  end)

  element20.inputBegan = userInputService.InputBegan:Connect(function(input, p92)
    if p92 then
      return
    end

    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space
      or input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift
      or input.KeyCode == Enum.KeyCode.LeftControl then
      return
    end

    element20.held[input.KeyCode] = true
  end)

  element20.inputEnded = userInputService.InputEnded:Connect(function(input2)
    element20.held[input2.KeyCode] = nil
  end)

  element20.mouseInput = userInputService.InputChanged:Connect(function(input3)
    if input3.UserInputType == Enum.UserInputType.MouseMovement and val148 == element20 then
      element20.cameraYaw = element20.cameraYaw - input3.Delta.X * 0.0025
      element20.cameraPitch = math.clamp(element20.cameraPitch - input3.Delta.Y * 0.0025, -1.25, 1.15)
    end
  end)

  pcall(function()
    runService:BindToRenderStep("ChairBypassCamera", Enum.RenderPriority.Camera.Value + 10, function()
      if val148 ~= element20 or not collider2.Parent then
        return
      end

      local currentCamera3 = workspace.CurrentCamera
      local cframe = CFrame.fromOrientation(element20.cameraPitch, element20.cameraYaw, 0)
      local val151 = collider2.Position + Vector3.new(0, 2, 0)
      local vectorToWorldSpace = cframe:VectorToWorldSpace(Vector3.new(0, 0, -1))

      currentCamera3.CameraType = Enum.CameraType.Scriptable
      currentCamera3.CFrame = CFrame.lookAt(val151, val151 + vectorToWorldSpace)

      userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end)
  end)

  element20.movement = runService.Heartbeat:Connect(function()
    if val148 ~= element20 or not collider2.Parent then
      return
    end

    for index33, value49 in ipairs(element19:GetDescendants()) do
      if value49:IsA("BasePart") then
        value49.CanCollide = false
      end
    end

    local cframe2 = workspace.CurrentCamera.CFrame
    local vector2 = Vector3.new(cframe2.LookVector.X, 0, cframe2.LookVector.Z)
    local vector3 = Vector3.new(cframe2.RightVector.X, 0, cframe2.RightVector.Z)

    if vector2.Magnitude > 0.01 then
      vector2 = vector2.Unit
    else
      vector2 = Vector3.new(0, 0, -1)
    end

    if vector3.Magnitude > 0.01 then
      vector3 = vector3.Unit
    else
      vector3 = Vector3.new(1, 0, 0)
    end

    local zero2 = Vector3.zero

    if element20.held[Enum.KeyCode.W] then
      zero2 = zero2 + vector2
    end

    if element20.held[Enum.KeyCode.S] then
      zero2 = zero2 - vector2
    end

    if element20.held[Enum.KeyCode.D] then
      zero2 = zero2 + vector3
    end

    if element20.held[Enum.KeyCode.A] then
      zero2 = zero2 - vector3
    end

    if zero2.Magnitude == 0 and humanoid.MoveDirection.Magnitude > 0 then
      local moveDirection4 = humanoid.MoveDirection
      zero2 = vector2 * moveDirection4:Dot(vector2) + vector3 * moveDirection4:Dot(vector3)
    end

    if element20.held[Enum.KeyCode.Space] then
      zero2 = zero2 + Vector3.yAxis
    end

    if element20.held[Enum.KeyCode.LeftShift] then
      zero2 = zero2 - Vector3.yAxis
    end

    local val152 = math.asin(math.clamp(cframe2.LookVector.Y, -1, 1))

    if zero2.Magnitude > 0 then
      local unit = zero2.Unit
      local v244 = unit * math.sin(val152) + Vector3.new(0, math.cos(val152), 0) * unit.Magnitude
      local element21 = Vector3.new(unit.X, 0, unit.Z) + Vector3.new(0, math.sin(val152), 0)

      if element21.Magnitude > 0.01 then
        collider2.AssemblyLinearVelocity = element21.Unit * options.ArchiveChairFlySpeed.Value
      else
        collider2.AssemblyLinearVelocity = Vector3.zero
      end
    else
      collider2.AssemblyLinearVelocity = Vector3.zero
    end

    collider2.AssemblyAngularVelocity = Vector3.zero
  end)

  return true
end

local function helper48()
  helper46()

  if helper47() then
    library:Notify({
      Title = "Chair anticheat bypass", Description = "Bypass active, prompts are not able to be used while active, press ctrl and then space or turn off the toggle to stop it", Time = 3, })

    return
  end

  local val153 = {}

  local connect17 = runService.Heartbeat:Connect(function()
    local value50 = toggles.ArchiveChairFly and toggles.ArchiveChairFly.Value
      or toggles.StairwellChairFly and toggles.StairwellChairFly.Value

    if not value50 or val148 ~= val153 then
      connect17:Disconnect()
      return
    end

    local humanoidRootPart7 = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoidRootPart7 then
      return
    end

    local element22 = helper44()

    if not element22 then
      return
    end

    local collider3 = element22:FindFirstChild("Collider") or element22.PrimaryPart
      or element22:FindFirstChildWhichIsA("BasePart")

    if collider3 and (humanoidRootPart7.Position - collider3.Position).Magnitude < 8 then
      connect17:Disconnect()

      if value50 and not val148 then
        helper47()

        library:Notify({
          Title = "Chair anticheat bypass", Description = "Bypass active, prompts are not able to be used while active, press ctrl and then space or turn off the toggle to stop it", Time = 3, })
      end
    end
  end)

  val153.pollSeat = connect17
  val148 = val153
end

function helper14()
  helper40()
  helper39()

  if options.SpeedBypassMode.Value == "Boost" then
    helper43()
  else
    helper42()

    if toggles.FlyToggle.Value or options.Walkspeed.Value ~= 16 then
      helper41()
    end
  end
end

options.Walkspeed:OnChanged(helper14)
options.SpeedBypassMode:OnChanged(helper14)

toggles.FlyToggle:OnChanged(function()
  if toggles.FlyToggle.Value then
    helper14()
    helper15()
  else
    onEvent2()
    helper14()
  end
end)

toggles.RemoveAcceleration:OnChanged(function(p93)
  for key9, value51 in pairs(PartProperties) do
    key9.CustomPhysicalProperties = p93 and CustomPhysics or value51
  end
end)

toggles.EnableCharacterJump:OnChanged(function(p94)
  if character then
    character:SetAttribute("CanJump", p94 and true or OldJump)
  end
end)

toggles.EnableCharacterSlide:OnChanged(function(p95)
  if character then
    character:SetAttribute("CanSlide", p95 and true or OldSlide)
  end
end)

NoclipConnection = nil
NoclipParts = {}

local function helper49()
  TableClear(NoclipParts)

  if not character then
    return
  end

  for v248, v249 in character:GetDescendants() do
    if v249:IsA("BasePart") then
      table.insert(NoclipParts, v249)
    end
  end

  if collisionPart then
    table.insert(NoclipParts, collisionPart)
    local collisionCrouch3 = collisionPart:FindFirstChild("CollisionCrouch")
  end

  local collisionClone5 = character:FindFirstChild("CollisionClone")

  if collisionClone5 then
    table.insert(NoclipParts, collisionClone5)
    local collisionCrouch4 = collisionClone5:FindFirstChild("CollisionCrouch")
  end
end

local function iterate3(canCollide)
  for index34, value52 in ipairs(NoclipParts) do
    if value52 then
      value52.CanCollide = canCollide
    end
  end
end

function helper17()
  if NoclipConnection then
    NoclipConnection:Disconnect()
    NoclipConnection = nil
  end

  if toggles.Noclip.Value then
    helper49()
    NoclipConnection = runService.Stepped:Connect(function() iterate3(false) end)
  else
    iterate3(true)
  end
end

toggles.Noclip:OnChanged(helper17)

local function helper50()
  val85.IsEyes = workspace:FindFirstChild("Eyes") ~= nil
    or workspace:FindFirstChild("Lookman") ~= nil

  val85.IsLookman = workspace:FindFirstChild("BackdoorLookman") ~= nil
end

helper50()

workspace.ChildAdded:Connect(function(child5)
  local name3 = child5.Name

  if name3 == "Eyes" or name3 == "Lookman" then
    val85.IsEyes = true
  elseif name3 == "BackdoorLookman" then
    val85.IsLookman = true
  end
end)

workspace.ChildRemoved:Connect(function(child6)
  local name4 = child6.Name

  if name4 == "Eyes" or name4 == "Lookman" then
    val85.IsEyes = workspace:FindFirstChild("Eyes") ~= nil
      or workspace:FindFirstChild("Lookman") ~= nil
  elseif name4 == "BackdoorLookman" then
    val85.IsLookman = workspace:FindFirstChild("BackdoorLookman") ~= nil
  end
end)

local connect18 = runService.RenderStepped:Connect(function()
  if _Unloading then
    return
  end

  if val85.InLobby then
    return
  end

  if options.FieldOfView then
    currentCamera.FieldOfView = options.FieldOfView.Value
  end

  if playerGui and not val85.SurgeFrame then
    local surgeVignetteDisabled = playerGui:FindFirstChild("SurgeVignette", true)

    if surgeVignetteDisabled then
      val85.SurgeFrame = surgeVignetteDisabled

      if toggles.RemoveSurge and toggles.RemoveSurge.Value then
        surgeVignetteDisabled.Name = "SurgeVignette_Disabled"
      end
    end
  end

  if toggles.BypassEyes.Value and val85.IsEyes or toggles.BypassLookman.Value and val85.IsLookman then
    local currentFloor3 = CurrentFloor

    if currentFloor3 == "Fools" or currentFloor3 == "OldHotel" then
      remotesFolder2.MotorReplication:FireServer(
        0, val85.SpoofOffset == 200 and 65 or -65, 0, false
      )
    else
      remotesFolder2.MotorReplication:FireServer(-650)
    end
  end
end)

TPTranspParts = {}

local function helper51()
  TableClear(TPTranspParts)

  if not character then
    return
  end

  for v250, v251 in character:GetDescendants() do
    if v251:IsA("BasePart")
      and (v251.Name == "Head" or v251.Parent and v251.Parent:IsA("Accessory")) then
      table.insert(TPTranspParts, v251)
    end
  end
end

local function waitLoop2()
  task.wait()
  helper51()
end

function helper18()
  if CameraConnection then
    CameraConnection:Disconnect()
    CameraConnection = nil
  end

  if _TPCharConn then
    _TPCharConn:Disconnect()
    _TPCharConn = nil
  end

  helper51()

  if character then
    _TPCharConn = character.ChildAdded:Connect(waitLoop2)
  end

  local raycastParams = RaycastParams.new()
  raycastParams.FilterType = Enum.RaycastFilterType.Exclude

  CameraConnection = runService.RenderStepped:Connect(function()
    if _Unloading then
      return
    end

    if not character then
      return
    end

    raycastParams.FilterDescendantsInstances = { character }

    if options.ThirdPersonOffsetX and options.ThirdPersonOffsetY and options.ThirdPersonOffsetZ then
      local cframe3 = CFrame.new(
        options.ThirdPersonOffsetX.Value, options.ThirdPersonOffsetY.Value, options.ThirdPersonOffsetZ.Value
      )

      if toggles.ThirdPerson.Value then
        local element23 = (currentCamera.CFrame * cframe3).Position - currentCamera.CFrame.Position

        local spherecast = workspace:Spherecast(
          currentCamera.CFrame.Position, 0.2, element23, raycastParams
        )

        if toggles.ThirdPersonWallCheck.Value and spherecast and spherecast.Instance.CanCollide then
          local val154 = currentCamera.CFrame.Position + element23.Unit * spherecast.Distance
          currentCamera.CFrame = CFrame.new(val154, val154 + currentCamera.CFrame.LookVector)
        else
          currentCamera.CFrame = currentCamera.CFrame * cframe3
        end
      end
    end

    for index35, value53 in ipairs(TPTranspParts) do
      value53.Transparency = toggles.ThirdPerson.Value and 0 or 1
      value53.LocalTransparencyModifier = toggles.ThirdPerson.Value and 0 or 1
    end
  end)
end

val85.LastCrouchFire = 0

Connections.GodmodeEnforce = runService.RenderStepped:Connect(function()
  if _Unloading then
    return
  end

  if not character or not humanoid or not humanoidRootPart then
    return
  end

  if not toggles or not toggles.Godmode then
    return
  end

  local val155 = helper8()

  if val155 and not val83.Sunk then
    if CurrentFloor ~= "Fools" and CurrentFloor ~= "OldHotel" then
      humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, -2.346, 0)
      humanoid.HipHeight = 0.05
      val83.Sunk = true

      if remotesFolder2 then
        local crouch5 = remotesFolder2:FindFirstChild("Crouch")

        if crouch5 then
          crouch5:FireServer(true, true)
        end
      end
    end
  end

  if not val155 and val83.Sunk then
    if CurrentFloor ~= "Fools" and CurrentFloor ~= "OldHotel" then
      humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 2.346, 0)
      humanoid.HipHeight = 2.396
      val83.Sunk = false
    end
  end

  if val155 and val83.Sunk and CurrentFloor ~= "Fools" and CurrentFloor ~= "OldHotel" then
    if humanoid.HipHeight ~= 0.05 then
      humanoid.HipHeight = 0.05
    end
  end

  if val155 and remotesFolder2 then
    local crouch6 = remotesFolder2:FindFirstChild("Crouch")

    if crouch6 then
      crouch6:FireServer(true, true)
    end
  end

  local collision2 = character:FindFirstChild("Collision")
  local collisionPart3 = character:FindFirstChild("CollisionPart")
  local collisionClone6 = character:FindFirstChild("CollisionClone")

  if CurrentFloor == "OldHotel" or CurrentFloor == "Fools" then
    local functions4 = val155 and Functions.GetNearestEntity() and 200
      or toggles.FigureGodmode.Value and Functions.GetNearestFigure() and 200 or 0

    val85.SpoofOffset = functions4

    if collision2 then
      collision2.Position = humanoidRootPart.Position + Vector3.new(0, functions4, 0)
      collision2.CanCollide = false
    end

    if CurrentFloor == "Fools" then
      local collisionCrouch5 = collision2 and collision2:FindFirstChild("CollisionCrouch")

      if collisionCrouch5 then
        collisionCrouch5.CanCollide = false
      end

      local collisionCrouch6 = collisionClone6
        and collisionClone6:FindFirstChild("CollisionCrouch")

      if collisionCrouch6 then
        collisionCrouch6.CanCollide = false
      end
    end

    humanoidRootPart.CanCollide = not toggles.Noclip.Value
  else
    if collision2 then
      collision2.CanCollide = false
      local collisionCrouch7 = collision2:FindFirstChild("CollisionCrouch")

      if collisionCrouch7 then
        collisionCrouch7.CanCollide = false
      end
    end

    local lowerTorso3 = character:FindFirstChild("LowerTorso")
    local root4 = lowerTorso3 and lowerTorso3:FindFirstChild("Root")

    if root4 and not val85.OriginalC1 then
      val85.OriginalC1 = root4.C1
    end

    if root4 and val85.OriginalC1 then
      root4.C1 = val85.OriginalC1 * CFrame.new(0, val155 and -2.346 or 0, 0)
    end

    local val156 = val155 and 2.328 or 0.18

    if collision2 then
      collision2.Position = humanoidRootPart.Position + Vector3.new(0, val156, 0)
    end

    if collisionPart3 then
      collisionPart3.Position = humanoidRootPart.Position + Vector3.new(0, val156, 0)
    end

    if collision2 and collisionClone6 then
      local collisionCrouch8 = collision2:FindFirstChild("CollisionCrouch")
      local collisionCrouch9 = collisionClone6:FindFirstChild("CollisionCrouch")

      if collisionCrouch8 and collisionCrouch9 then
        local val157 = val155 and 1.328 or -0.982
        collisionCrouch8.Position = humanoidRootPart.Position + Vector3.new(0, val157, 0)
        collisionCrouch9.CollisionGroup = collisionCrouch8.CollisionGroup
      end

      local collisionCrouch10 = collisionClone6:FindFirstChild("CollisionCrouch")

      if collisionCrouch10 then
        collisionCrouch10.Position = humanoidRootPart.Position
          + Vector3.new(0, val155 and 0.75 or -0.982, 0)
      end
    end
  end

  if collisionClone6 and collision2 then
    collisionClone6.CollisionGroup = collision2.CollisionGroup

    collisionClone6.Position = humanoidRootPart.Position
      + Vector3.new(0, val155 and 1.75 or 0.18, 0)
  end

  local crouch7 = remotesFolder2 and remotesFolder2:FindFirstChild("Crouch")

  if crouch7 and collisionPart and tick() - val85.LastCrouchFire > 0.1 then
    local functions5 = Functions.IsCrouching()

    if val155 then
      functions5 = true
    end

    crouch7:FireServer(functions5, true)
    val85.LastCrouchFire = tick()
  end
end)

VulnerableLastY = nil
VulnerableNotifCooldown = 0

function Functions.IsCrouching()
  if CurrentFloor == "Fools" or CurrentFloor == "OldHotel" then
    return character:GetAttribute("Crouching")
  end

  return collisionPart.CollisionGroup == "PlayerCrouching"
end

function Functions.GetNearestFigure()
  local element24 = { Distance = math.huge, Object = nil }
  local val158 = { FigureRig = true, FigureRagdoll = true, Figure = true }

  for v259, v260 in val114.Entities do
    if v260:IsA("Model") and v260.PrimaryPart and val158[v260.Name] then
      local distanceFromCharacter6 = localPlayer2:DistanceFromCharacter(v260.PrimaryPart.Position)

      if distanceFromCharacter6 < element24.Distance and distanceFromCharacter6 < 25 then
        element24.Distance = distanceFromCharacter6
        element24.Object = v260
      end
    end
  end

  return element24.Object
end

Phase = {
  Connection = nil, Body = nil, Parts = {}, CharConn = nil, }

local function helper52()
  TableClear(Phase.Parts)

  if not character then
    return
  end

  for v261, v262 in character:GetDescendants() do
    if v262:IsA("BasePart") then
      table.insert(Phase.Parts, v262)
    end
  end
end

function onEvent()
  if Phase.Connection then
    Phase.Connection:Disconnect()
    Phase.Connection = nil
  end

  if Phase.Body then
    Phase.Body:Destroy()
    Phase.Body = nil
  end

  if Phase.CharConn then
    Phase.CharConn:Disconnect()
    Phase.CharConn = nil
  end

  if toggles.Phase.Value then
    helper52()

    if character then
      Phase.CharConn = character.ChildAdded:Connect(function()
        task.wait()
        helper52()
      end)
    end

    Phase.Connection = runService.Stepped:Connect(function()
      if not character then
        return
      end

      for index36, value54 in ipairs(Phase.Parts) do
        if value54 then
          value54.CanCollide = false
        end
      end

      if collisionPart then
        collisionPart.CanCollide = false
        local collisionCrouch11 = collisionPart:FindFirstChild("CollisionCrouch")

        if collisionCrouch11 then
          collisionCrouch11.CanCollide = false
        end
      end

      local collisionClone7 = character:FindFirstChild("CollisionClone")

      if collisionClone7 then
        collisionClone7.CanCollide = false
        local collisionCrouch12 = collisionClone7:FindFirstChild("CollisionCrouch")

        if collisionCrouch12 then
          collisionCrouch12.CanCollide = false
        end
      end

      if humanoidRootPart then
        Phase.Body.Velocity = humanoidRootPart.CFrame.LookVector * 2.25
      end
    end)

    Phase.Body = Instance.new("BodyVelocity")
    Phase.Body.MaxForce = Vector3.new(9000000000, 9000000000, 9000000000)

    Phase.Body.Velocity = humanoidRootPart and humanoidRootPart.CFrame.LookVector * 2.25
      or Vector3.zero

    if humanoidRootPart then
      Phase.Body.Parent = humanoidRootPart
    end
  elseif not toggles.Noclip.Value then
    helper49()
    iterate3(true)
  end
end

toggles.Phase:OnChanged(onEvent)

toggles.AnticheatManipulation:OnChanged(function(p96)
  if AnticheatConnection then
    AnticheatConnection:Disconnect()
    AnticheatConnection = nil
  end

  if p96 then
    AnticheatConnection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if not character or not humanoidRootPart then
        return
      end

      local currentFloor4 = localPlayer2:GetAttribute("CurrentFloor") or ""

      if currentFloor4 ~= "Fools" and currentFloor4 ~= "OldHotel" then
        character:PivotTo(character:GetPivot() * CFrame.new(0, 0, 750))
      end
    end)
  end
end)

local element25 = {
  Connection = nil, LastFire = 0, Debounce = false, Blacklist = {
    HidePrompt = true, RiftPrompt = true, StarRiftPrompt = true, InteractPrompt = true, ClimbPrompt = true, DonatePrompt = true, DialoguePrompt = true, RevivePrompt = true, EnterPrompt = true, AnimatePrompt = true, ToolEventPrompt = true, Prompt = true, PropPrompt = true, }, }

HidingSpotNames = {
  Wardrobe = true, Backdoor_Wardrobe = true, Toolshed = true, RetroWardrobe = true, ["Wardrobe-FOOLS26"] = true, Locker_Large = true, Rooms_Locker = true, Rooms_Locker_Fridge = true, Bed = true, Double_Bed = true, CircularVent = true, Dumpster = true, }

LockPromptNames = {
  UnlockPrompt = true, SkullPrompt = true, LockPrompt = true, ThingToEnable = true, FusesPrompt = true, }

local function helper53(val159)
  if element25.Blacklist[val159.Name] then
    return
  end

  if val159:FindFirstAncestor("ArchivesWaitingSeats") or val159:FindFirstAncestor("ArchivesTrashcan")
    or val159:FindFirstAncestor("ArchivesOfficeChair") or val159:FindFirstAncestor("PrincipalChair")
    or val159:FindFirstAncestor("Vendor_ShakelightVendingMachine")
    or val159:FindFirstAncestor("ArchivesTerminal") or val159:FindFirstAncestor("Regal_Chair")
    or val159:FindFirstAncestor("Regal_Couch") or val159:FindFirstAncestor("ArchivesLargePrinter")
    or val159:FindFirstAncestor("ForgetMeNotVineDoors")
    or val159:FindFirstAncestor("StairwellTerminal")
    or val159:FindFirstAncestor("StairwellOfficeChair") then
    return
  end

  if not val159 or not val159.Parent then
    return
  end

  if element25.Debounce then
    return
  end

  if LockPromptNames[val159.Name]
    or val159.Parent and val159.Parent:GetAttribute("Locked") == true
    or val159.Parent and val159.Parent.Parent and val159.Parent.Parent.Name == "Locker_Small_Locked"
      and val159.Name == "ActivateEventPrompt" then
    if options.AutoInteractIgnoreList.Value.Locks then
      return
    end

    local val160 = {
      "Key", "GeneratorFuse", "KeyBackdoor", "KeyElectrical", "KeyIron", "Lockpick", "SkeletonKey", "Shears", "Multitool", }

    local val161 = { "Key", "GeneratorFuse", "KeyElectrical", "KeyIron" }
    local val162 = false

    for index37, value55 in ipairs(val160) do
      if Functions.HasItem(value55, true) then
        val162 = true
        break
      end
    end

    for index38, value56 in ipairs(val161) do
      if Functions.HasItem(value56) then
        val162 = true
        break
      end
    end

    if not val162 then
      return
    end
  end

  if HidingSpotNames[val159.Parent.Name] then
    return
  end

  if val159.Parent.Name == "GlitchCube"
    and options.AutoInteractIgnoreList.Value["Glitch Fragments"] then
    return
  end

  local parent3 = val159

  if options.AutoInteractIgnoreList.Value.Mandrake then
    while parent3 do
      local name5 = parent3.Name

      if name5 == "MandrakeLive" or name5 == "MandrakeHole" or name5 == "Mandrakes" then
        return
      end

      parent3 = parent3.Parent
    end
  end

  local drops4 = workspace:FindFirstChild("Drops")

  if drops4 and val159:IsDescendantOf(drops4)
    and options.AutoInteractIgnoreList.Value["Dropped Items"] then
    return
  end

  if val159.Parent.Name == "TrackLever" then
    return
  end

  if val159.Name == "ActivateEventPrompt" then
    if val159.ActionText == "Close" then
      return
    end

    if val159.Parent.Name == "Padlock" or val159.Parent.Name == "MinesAnchor" then
      return
    end
  end

  if val159.Parent.Name == "LeverForGate" and val159:GetAttribute("Interactions") then
    return
  end

  local parent4 = val159.Parent.Parent

  if parent4 and (parent4.Name == "DoorFake" or parent4.Name == "FakeDoor") then
    return
  end

  if val159.Parent:GetAttribute("JeffShop") then
    return
  end

  if val159:GetAttribute("AutoInteractIgnore") then
    return
  end

  if val159.Name == "PushPrompt" then
    return
  end

  if (val159.Parent.Name == "LibraryHintPaper" or val159.Parent.Name == "PickupItem")
    and (Functions.HasItem("LibraryHintPaper") or Functions.HasItem("LibraryHintPaperHard")) then
    return
  end

  Functions.ForceFirePrompt(val159)
  element25.Debounce = true

  if helper11() == "OldHotel" then
    task.wait()
  end

  element25.Debounce = false
end

toggles.AutoInteract:OnChanged(function(p98)
  if element25.Connection then
    element25.Connection:Disconnect()
    element25.Connection = nil
  end

  if p98 then
    element25.Connection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if not (toggles and toggles.AutoInteract and toggles.AutoInteract.Value
        or options and options.AutoInteractKeybind and options.AutoInteractKeybind:GetState()) then
        return
      end

      local val163 = tick()

      if val163 - element25.LastFire < 0.1 then
        return
      end

      element25.LastFire = val163

      for index39, value57 in ipairs(_TrackedPrompts) do
        local parentRoom = value57:GetAttribute("ParentRoom")

        if (not parentRoom
            or tonumber(parentRoom) == tonumber(localPlayer2:GetAttribute("CurrentRoom")))
          and value57.Parent
          and (value57.Parent:IsA("BasePart") or value57.Parent:IsA("Model")) then
          local distanceFromCharacter7

          if value57.Parent:IsA("BasePart") then
            distanceFromCharacter7 = localPlayer2:DistanceFromCharacter(value57.Parent.Position)
          else
            distanceFromCharacter7 = localPlayer2:DistanceFromCharacter(value57.Parent:GetPivot().Position)
          end

          if distanceFromCharacter7
              <= (value57:GetAttribute("MaxActivationDistance_Old")
                  or value57.MaxActivationDistance)
                + 5
            and (value57.Enabled or value57.Name == "LongPushPrompt"
              or value57.Name == "BigPropPrompt") then
            task.spawn(helper53, value57)
          end
        end
      end
    end)
  end
end)

function helper16()
  if InfiniteJumpConnection then
    InfiniteJumpConnection:Disconnect()
    InfiniteJumpConnection = nil
  end

  if not toggles.InfiniteJumps.Value then
    return
  end

  InfiniteJumpConnection = userInputService.InputBegan:Connect(function(input4)
    if input4.KeyCode == Enum.KeyCode.Space and humanoid then
      humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
  end)
end

toggles.InfiniteJumps:OnChanged(helper16)

ESPCategories = {
  Entities = {}, Doors = {}, Keys = {}, Objectives = {}, Items = {}, Gold = {}, Chests = {}, HidingSpots = {}, Ladders = {}, }

ESPBlacklist = {}
ESPCleanup = {}
ESPConnections = {}

local function helper54(val164)
  if not loader or not val164 then
    return
  end

  for index40, value58 in ipairs({
    "Entities", "Doors", "Keys", "Objectives", "Items", "Gold", "Chests", "HidingSpots", "Ladders", }) do
    local val165 = value58 .. "Tracers"

    if toggles[val165] and toggles[val165].Value and TableFind(ESPCategories[value58], val164) then
      loader:SetTracersEnabled(val164, true)
      break
    end
  end
end

function Functions:AddESP(p100)
  local object = self.Object

  if not object then
    return
  end

  if ESPBlacklist[object] then
    return
  end

  if p100 then
    local numVal5 = tonumber(localPlayer2:GetAttribute("CurrentRoom"))
    local numVal6 = tonumber(object:GetAttribute("ParentRoom"))

    if numVal6 == numVal5 or TableFind(ESPCategories.Doors, object) and numVal6 == numVal5 + 1 then
      loader:AddESP(self)
      helper54(object)
    end

    local connect19 = localPlayer2:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
      if loader.ColorTable and loader.ColorTable[object] then
        self.Color = loader.ColorTable[object]
      end

      local numVal7 = tonumber(localPlayer2:GetAttribute("CurrentRoom"))
      local numVal8 = tonumber(object:GetAttribute("ParentRoom"))

      if numVal8 == numVal7 or TableFind(ESPCategories.Doors, object) and numVal8 == numVal7 + 1 then
        if loader then
          loader:AddESP(self)
          helper54(object)
        end
      elseif loader then
        loader:RemoveESP(object)
        loader:SetTracersEnabled(object, false)
      end
    end)

    table.insert(Connections, connect19)
    ESPConnections[object] = connect19

    object.Destroying:Once(function()
      connect19:Disconnect()

      if loader then
        loader:RemoveESP(object)
        loader:SetTracersEnabled(object, false)
      end

      local v273 = TableFind(Connections, connect19)
      ESPConnections[object] = nil
    end)
  else
    loader:AddESP(self)
    helper54(object)
  end
end

function Functions:RemoveESP()
  local object5 = ESPConnections[self]

  if object5 then
    object5:Disconnect()
    ESPConnections[self] = nil
    local v275 = TableFind(Connections, object5)
  end

  if loader then
    loader:RemoveESP(self)
    loader:SetTracersEnabled(self, false)
  end
end

local val166 = {
  Door = true, Ladder = true, GoldPile = true, StardustPickup = true, KeyObtain = true, ElectricalKeyObtain = true, MinesGenerator = true, FuseObtain = true, LiveHintBook = true, LiveBreakerPolePickup = true, LibraryHintPaper = true, PickupItem = true, CringlePresent = true, LeverForGate = true, MinesGateButton = true, GardenGateButton = true, MinesAnchor = true, WaterPump = true, TimerLever = true, VineGuillotine = true, KeyObtainFake = true, GiggleCeiling = true, Snare = true, GrumbleRig = true, Drakobloxxer = true, LiveEntityBramble = true, Groundskeeper = true, Figure = true, FigureRig = true, FigureRagdoll = true, MandrakeLive = true, ChestBox = true, ChestBoxLocked = true, Chest_Vine = true, Toolbox = true, Toolbox_Locked = true, Toolshed_Small = true, Locker_Small_Locked = true, MouseHole = true, Wardrobe = true, Backdoor_Wardrobe = true, Toolshed = true, RetroWardrobe = true, ["Wardrobe-FOOLS26"] = true, Locker_Large = true, Rooms_Locker = true, Rooms_Locker_Fridge = true, Bed = true, Double_Bed = true, CircularVent = true, Dumpster = true, Lighter = true, Flashlight = true, Lockpick = true, Vitamins = true, Bandage = true, StarVial = true, StarBottle = true, StarJug = true, Shakelight = true, Straplight = true, Bulklight = true, Battery = true, Candle = true, Crucifix = true, CrucifixWall = true, Glowsticks = true, SkeletonKey = true, Candy = true, ShieldMini = true, ShieldBig = true, BandagePack = true, BatteryPack = true, RiftCandle = true, LaserPointer = true, HolyGrenade = true, Shears = true, Smoothie = true, Cheese = true, Bread = true, AlarmClock = true, RiftSmoothie = true, GweenSoda = true, GlitchCube = true, Scanner = true, Bomb = true, Knockbomb = true, Nanner = true, BigBomb = true, SnakeBox = true, GoldGun = true, StopSign = true, TipJar = true, Lantern = true, IronKey = true, LotusPetal = true, Compass = true, LotusPetalPickup = true, LanternLitItem = true, KeyIron = true, IronKeyForCrypt = true, LotusHolder = true, Multitool = true, RiftJar = true, AloeVera = true, Donut = true, Lotus = true, BoxingGloves = true, Green_Herb = true, PaperPlane = true, Pizza = true, FihFlakes = true, Leftovers = true, Briefcase = true, ArchivesTerminal = true, StairwellTerminal = true, }

local val167 = {
  RushMoving = true, AmbushMoving = true, A60 = true, A120 = true, Eyes = true, Lookman = true, BackdoorRush = true, BackdoorLookman = true, Groundskeeper = true, GloombatSwarm = true, AR0xMBUSH = true, ["RNIUSHCG=="] = true, MonumentEntity = true, JeffTheKiller = true, CustomEntity = true, FrozenAmbush = true, SallyMoving = true, Figure = true, FigureRig = true, FigureRagdoll = true, GiggleCeiling = true, GrumbleRig = true, DronesStampede = true, BashMoving = true, Water = true, TellerRig = true, Scribbles = true, Noise = true, Creak = true, }

val103 = {
  Lighter = "Lighter", Flashlight = "Flashlight", Lockpick = "Lockpicks", Vitamins = "Vitamins", Bandage = "Bandage", StarVial = "Starlight Vial", StarBottle = "Starlight Bottle", StarJug = "Starlight Barrel", Shakelight = "Gummy Flashlight", Straplight = "Straplight", Bulklight = "Spotlight", Battery = "Battery", Candle = "Candle", Crucifix = "Crucifix", CrucifixWall = "Crucifix", Glowsticks = "Glowstick", SkeletonKey = "Skeleton Key", Candy = "Candy", ShieldMini = "Mini Shield Potion", ShieldBig = "Big Shield Potion", BandagePack = "Bandage Pack", BatteryPack = "Battery Pack", RiftCandle = "Moonlight Candle", LaserPointer = "Laser Pointer", HolyGrenade = "Holy Hand Grenade", Shears = "Shears", Smoothie = "Smoothie", Cheese = "Cheese", Bread = "Bread", AlarmClock = "Alarm Clock", RiftSmoothie = "Moonlight Smoothie", GweenSoda = "Gween Soda", GlitchCube = "Glitch Fragment", Scanner = "Tablet", Bomb = "Bomb", Knockbomb = "Knockbomb", Nanner = "Nanner", BigBomb = "Big Bomb", SnakeBox = "Hiding Box", GoldGun = "Golden Gun", StopSign = "Stop Sign", TipJar = "Tip Jar", Lantern = "Lantern", IronKey = "Iron Key", LotusPetal = "Lotus Petal", Compass = "Compass", LotusPetalPickup = "Lotus Petal", LanternLitItem = "Lantern", KeyIron = "Iron Key", IronKeyForCrypt = "Iron Key", LotusHolder = "Lotus Petal", Multitool = "Multitool", RiftJar = "Rift Jar", AloeVera = "Aloe Vera", Donut = "Donut", Lotus = "Lotus", BoxingGloves = "Boxing Gloves", GoldPile = "Gold Pile", PaperPlane = "Paper Plane", Pizza = "Pizza", FihFlakes = "FihFlakes", Leftovers = "Leftovers", Briefcase = "Briefcase", }

function FunctionGetDoorNumber(val168)
  local numVal9 = tonumber(val168.Parent.Name)
    or tonumber(val168.Parent.Parent and val168.Parent.Parent.Name)

  if numVal9 then
    numVal9 = numVal9 + 1
  end

  if CurrentFloor == "Mines" then
    numVal9 = (numVal9 or 0) + 100
  end

  if CurrentFloor == "Backdoor" then
    numVal9 = (numVal9 or 0) - 50
  end

  return tostring(numVal9)
end

ESPToggleKeys = {
  Entities = "EntitiesESP", Doors = "DoorsESP", Keys = "KeysESP", Objectives = "ObjectivesESP", Items = "ItemsESP", Gold = "GoldESP", Chests = "ChestsESP", HidingSpots = "HidingSpotsESP", Ladders = "LaddersESP", }

local val169 = {
  Entities = "EntitiesESPColor", Doors = "DoorsESPColor", Keys = "KeysESPColor", Objectives = "ObjectivesESPColor", Items = "ItemsESPColor", Gold = "GoldESPColor", Chests = "ChestsESPColor", HidingSpots = "HidingSpotsESPColor", Ladders = "LaddersESPColor", }

function GetESPTarget(val170, p103)
  return val170
end

local val171 = {
  PlaySound = nil, ShowAchievement = nil, ActiveItem = 0, SoundAssets = nil, SoundInstance = nil, ActiveAchievement = nil, ActiveEntity = 0, }

local function helper55(val173, val172, val174)
  local isEnabled = toggles[ESPToggleKeys[val172]] and toggles[ESPToggleKeys[val172]].Value
  if not isEnabled then
    if val172 == "Keys" and toggles.ObjectivesESP and toggles.ObjectivesESP.Value then
      isEnabled = true
    elseif val172 == "Gold" and toggles.ItemsESP and toggles.ItemsESP.Value then
      isEnabled = true
    end
  end

  if not isEnabled then
    return
  end

  local colorOpt = options[val169[val172]]
  local value59 = colorOpt and colorOpt.Value or (val172 == "Gold" and Color3.fromRGB(255, 215, 0) or (val172 == "Keys" and Color3.fromRGB(0, 191, 255) or (val172 == "Items" and Color3.fromRGB(170, 85, 255) or Color3.fromRGB(255, 255, 255))))
  local value60 = toggles.ESPShowText.Value and val174 or ""
  local object2 = GetESPTarget(val173, val172)
  local val175 = val173:GetAttribute("ParentRoom") ~= nil
  Functions.AddESP({ Object = object2, Text = value60, Color = value59 }, val175)
end

local function iterate4(val176)
  for index41, value61 in ipairs(ESPCategories[val176] or {}) do
    Functions.RemoveESP(GetESPTarget(value61, val176))
  end
  if val176 == "Items" and not (toggles.GoldESP and toggles.GoldESP.Value) then
    for index41, value61 in ipairs(ESPCategories.Gold or {}) do
      Functions.RemoveESP(GetESPTarget(value61, "Gold"))
    end
  elseif val176 == "Objectives" and not (toggles.KeysESP and toggles.KeysESP.Value) then
    for index41, value61 in ipairs(ESPCategories.Keys or {}) do
      Functions.RemoveESP(GetESPTarget(value61, "Keys"))
    end
  end
end

local function helper56(val177, val178)
  if not toggles.NotifyItems.Value then
    return
  end

  local value62 = options.ItemList.Value

  if value62 and next(value62) ~= nil and not value62[val177] then
    return
  end

  if val171.ActiveItem >= 6 then
    return
  end

  val171.ActiveItem = val171.ActiveItem + 1
  val171.PlaySound("ItemNotifySound")

  local val179 = ""

  if val178 and val178.PrimaryPart then
    val179 = " ("
      .. math.floor(localPlayer2:DistanceFromCharacter(val178.PrimaryPart.Position) + 0.5)
      .. " m)"
  end

  library:Notify({ Title = "An item has spawned", Description = val177 .. val179, Time = 4 })

  if options.ItemNotifyStyle.Value ~= "Obsidian" then
    task.spawn(function() val171.ShowAchievement("An item has spawned", val177, val179) end)
  end

  if toggles.ItemChatToggle.Value then
    Functions.SendChat(val177 .. " " .. options.ItemChatMessage.Value)
  end

  task.delay(5, function() val171.ActiveItem = math.max(0, val171.ActiveItem - 1) end)
end

local helper57

local function helper58(val180)
  if not val180 or not val180.Parent then
    return
  end

  if ESPBlacklist[val180] then
    return
  end

  if not val166[val180.Name] and not val167[val180.Name] and not val180.Name:match("^HidingSpot%d+$") then
    return
  end

  local name6 = val180.Name

  if name6 == "Door" and not val180:GetAttribute("ESPDelayed") then
    val180:SetAttribute("ESPDelayed", true)

    task.spawn(function()
      task.wait(0.25)
      helper58(val180)
    end)

    return
  end

  local val181, locked

  if name6 == "Door" and val180.Parent and tonumber(val180.Parent.Name) then
    val181 = "Doors"
    local val182 = {}

    for v287, v288 in val180:GetChildren() do
      if v288.Name == "Door" and v288:IsA("BasePart") then
        table.insert(val182, v288)
      end
    end

    if #val182 == 0 then
      return
    end

    locked = "Door " .. FunctionGetDoorNumber(val180)

    if CurrentFloor == "Archives" then
      local sign = val180:FindFirstChild("Sign")
      local stinker = sign and sign:FindFirstChild("Stinker")

      if stinker and stinker:IsA("TextLabel") and stinker.Text ~= "" then
        locked = "Door " .. stinker.Text
      end
    end

    if CurrentFloor == "OldHotel" then
      val180:SetAttribute("ParentRoom", tonumber(val180.Parent.Name))
      table.insert(ESPCategories.Doors, val180)
      helper55(val180, "Doors", locked)

      if not ESPCleanup[val180] then
        ESPCleanup[val180] = val180.Destroying:Once(function()
          Functions.RemoveESP(val180)
          ESPCleanup[val180] = nil
        end)
      end
    else
      local highlightPart

      if #val182 == 2 then
        local highlightModel = Instance.new("Model")
        highlightModel.Name = "HighlightModel"

        Instance.new("Humanoid", highlightModel).Name = "HighlightHumanoid"
        highlightModel:SetAttribute("ParentRoom", tonumber(val180.Parent.Name))

        for index42, value64 in ipairs(val182) do
          local highlightPart2 = Instance.new("Part", highlightModel)
          highlightPart2.Transparency = 0.999
          highlightPart2.Size = value64.Size
          highlightPart2.CanCollide = false
          highlightPart2.CFrame = value64.CFrame
          highlightPart2.Name = "HighlightPart"
          highlightPart2.Material = Enum.Material.Glass
          highlightPart2:SetAttribute("ParentRoom", tonumber(val180.Parent.Name))

          local instance4 = Instance.new("WeldConstraint", highlightPart2)
          instance4.Part0 = highlightPart2
          instance4.Part1 = value64
          instance4.Enabled = true
        end

        highlightModel.Parent = workspace
        highlightPart = highlightModel
      else
        local element26 = val182[1]

        highlightPart = Instance.new("Part")
        highlightPart.Transparency = 0.999
        highlightPart.Size = element26.Size
        highlightPart.CanCollide = false
        highlightPart.CFrame = element26.CFrame
        highlightPart.Name = "HighlightPart"
        highlightPart.Material = Enum.Material.Glass
        highlightPart:SetAttribute("ParentRoom", tonumber(val180.Parent.Name))

        local instance5 = Instance.new("WeldConstraint", highlightPart)
        instance5.Part0 = highlightPart
        instance5.Part1 = element26
        instance5.Enabled = true

        Instance.new("Humanoid", val180).Name = "HighlightHumanoid"
        highlightPart.Parent = workspace
      end

      table.insert(ESPCategories.Doors, highlightPart)
      helper55(highlightPart, "Doors", locked)

      if not ESPCleanup[highlightPart] then
        ESPCleanup[highlightPart] = val180.Destroying:Once(function()
          Functions.RemoveESP(highlightPart)
          ESPCleanup[highlightPart] = nil
        end)
      end
    end

    local val183 = tick()

    local connect20 = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if val180:FindFirstChild("Door") and val180:FindFirstChild("ClientOpen") then
        if options
          and options.DoorReachDistance
          and localPlayer2:DistanceFromCharacter(val180.Door.Position)
            < options.DoorReachDistance.Value
          and tick() - val183 > 0.1
          and toggles
          and toggles.DoorReachToggle
          and toggles.DoorReachToggle.Value then
          val180.ClientOpen:FireServer()
          val183 = tick()
        end
      end
    end)

    local door = val180:FindFirstChild("Door")

    if door then
      local open = door:FindFirstChild("Open")

      if open then
        open.Played:Once(function() connect20:Disconnect() end)
      end
    end

    val180.Destroying:Once(function() connect20:Disconnect() end)
    return
  end

  if val167[name6] then
    if name6 == "Water" and CurrentFloor ~= "Archives" then
      return
    end

    if name6 == "Water" then
      if val180:FindFirstAncestor("Toilet") or val180:FindFirstAncestor("ArchivesBathroomSink")
        or val180:FindFirstAncestor("ArchivesFihTank") then
        return
      end

      if val180:FindFirstAncestor("WaterCup") then
        return
      end

      if val180:FindFirstAncestor("DeathBackgroundYellow") then
        return
      end

      if val180.Parent and val180.Parent.Name == "Parts"
        and val180.Parent:FindFirstAncestor("CurrentRooms") then
        return
      end

      if val180:IsDescendantOf(localPlayer2:WaitForChild("Backpack")) then
        return
      end

      table.insert(ESPCategories.Entities, val180)
      helper55(val180, "Entities", "Electric Puddle")
      helper57(val180)
      return
    end

    if not val180:IsA("Model") then
      return
    end

    task.spawn(function()
      while not val180.PrimaryPart and val180.Parent do
        for v291, v292 in val180:GetChildren() do
          if v292:IsA("BasePart") then
            val180.PrimaryPart = v292
            break
          end
        end

        task.wait()
      end

      task.wait(0.1)

      if not val180.Parent then
        return
      end

      if val180.PrimaryPart
        and localPlayer2:DistanceFromCharacter(val180.PrimaryPart.Position) >= 10000 then
        return
      end

      if not val180.PrimaryPart then
        local basePart = val180:FindFirstChildWhichIsA("BasePart")

        if basePart then
          val180.PrimaryPart = basePart
        end
      end

      if not val180:FindFirstChildOfClass("Humanoid") then
        local highlightHumanoid = Instance.new("Humanoid")
        highlightHumanoid.Name = "HighlightHumanoid"
        highlightHumanoid.Parent = val180
      end

      local primaryPart = val180.PrimaryPart

      if primaryPart then
        primaryPart.Transparency = 0.999
        primaryPart.Material = Enum.Material.Glass
      end

      table.insert(ESPCategories.Entities, val180)

      if loader and loader.ObjectMaxDistance then
        loader.ObjectMaxDistance[val180] = 10000
      end

      if toggles.EntitiesESP.Value then
        local alias = (name6 == "FigureRig" or name6 == "FigureRagdoll") and "Figure"
          or EntityNotifyData[name6] and EntityNotifyData[name6].Alias or name6

        local value65 = options.EntitiesESPAllowed and options.EntitiesESPAllowed.Value

        if not value65 or next(value65) == nil or value65[alias] then
          local val184 = val180:GetAttribute("ParentRoom") ~= nil

          Functions.AddESP({
            Object = val180, Text = alias, Color = options.EntitiesESPColor.Value, }, val184)
        end
      end

      helper57(val180)
    end)

    return
  end

  if name6 == "Ladder" then
    val181 = "Ladders"
    locked = "Ladder"
    table.insert(ESPCategories.Ladders, val180)

    if CurrentFloor == "Mines" then
      helper55(val180, val181, locked)
    end

    return
  elseif name6 == "GoldPile" and val180:GetAttribute("GoldValue") then
    val181 = "Gold"
    locked = "Gold Pile [" .. val180:GetAttribute("GoldValue") .. "]"
  elseif name6 == "StardustPickup" then
    val181 = "Objectives"
    locked = "Stardust"
  elseif (name6 == "SkeletonKey" or name6 == "IronKey" or name6 == "KeyIron" or name6 == "IronKeyForCrypt") and val180:FindFirstChild("ModulePrompt") then
    val181 = "Keys"
    locked = val103[name6] or "Key"

    if not val180:IsDescendantOf(localPlayer2) and val180.Parent.Name ~= "Drops" then
      helper56(locked, val180)
    end
  elseif val103[name6] and val180:FindFirstChild("ModulePrompt") then
    val181 = "Items"
    locked = val103[name6]

    if not val180:IsDescendantOf(localPlayer2) and val180.Parent.Name ~= "Drops" then
      helper56(val103[name6], val180)
    end
  elseif name6 == "Green_Herb" then
    val181 = "Items"
    locked = "Green Herb"
  elseif name6 == "ChestBox" or name6 == "ChestBoxLocked" then
    val181 = "Chests"
    locked = val180:GetAttribute("Locked") and "Locked Chest" or "Chest"
  elseif name6 == "Toolbox" or name6 == "Toolbox_Locked" then
    val181 = "Chests"
    locked = val180:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
  elseif name6 == "Chest_Vine" then
    val181 = "Chests"
    locked = "Vine Chest"
  elseif name6 == "Toolshed_Small" then
    val181 = "Chests"
    locked = "Toolshed"
  elseif name6 == "Locker_Small_Locked" then
    val181 = "Chests"
    locked = "Locked Locker"
  elseif name6 == "MouseHole" then
    val181 = "Chests"
    locked = "Mouse"
  elseif ({
    Wardrobe = true, Backdoor_Wardrobe = true, Toolshed = true, RetroWardrobe = true, ["Wardrobe-FOOLS26"] = true, Locker_Large = true, Rooms_Locker = true, Rooms_Locker_Fridge = true, Bed = true, Double_Bed = true, CircularVent = true, Dumpster = true, })[name6] then
    local val185 = {
      Wardrobe = "Closet", Backdoor_Wardrobe = "Closet", Toolshed = "Closet", RetroWardrobe = "Closet", ["Wardrobe-FOOLS26"] = "Closet", Locker_Large = "Locker", Rooms_Locker = "Locker", Rooms_Locker_Fridge = "Locker", Bed = "Bed", Double_Bed = "Double Bed", CircularVent = "Vent", Dumpster = "Dumpster", }

    val181 = "HidingSpots"
    locked = val185[name6]
    Functions.HandleHidingTransparency(val180)
    table.insert(val114.HidingSpots, val180)
  elseif name6:match("^HidingSpot%d+$") then
    val181 = "HidingSpots"
    locked = "Hiding Spot"
    Functions.HandleHidingTransparency(val180)
    table.insert(val114.HidingSpots, val180)
  elseif ({
    KeyObtain = "Key", ElectricalKeyObtain = "Electrical Key", MinesGenerator = "Generator", FuseObtain = "Fuse", LiveHintBook = "Book", LiveBreakerPolePickup = "Fuse Breaker", LibraryHintPaper = "LibraryPaper", PickupItem = "Library Paper", CringlePresent = "Present", LeverForGate = "Gate Lever", MinesGateButton = "Gate Button", GardenGateButton = "Gate Button", MinesAnchor = "Anchor", WaterPump = "Water Pump", TimerLever = "Timer Lever", VineGuillotine = "Vine Guillotine", })[name6] then
    local val186 = {
      KeyObtain = "Key", ElectricalKeyObtain = "Electrical Key", MinesGenerator = "Generator", FuseObtain = "Fuse", LiveHintBook = "Book", LiveBreakerPolePickup = "Fuse Breaker", LibraryHintPaper = "Library Paper", PickupItem = "Hint Paper", CringlePresent = "Present", LeverForGate = "Gate Lever", MinesGateButton = "Gate Button", GardenGateButton = "Gate Button", MinesAnchor = "Anchor", WaterPump = "Water Pump", TimerLever = "Timer Lever", VineGuillotine = "Vine Guillotine", }

    if name6 == "KeyObtain" or name6 == "ElectricalKeyObtain" then
      val181 = "Keys"
    else
      val181 = "Objectives"
    end
    locked = val186[name6]

    if name6 == "KeyObtain" then
      task.spawn(function()
        task.wait(6.25)

        if not val180 or not val180.Parent then
          return
        end

        table.insert(ESPCategories[val181], val180)
        helper55(val180, val181, locked)
      end)
    end

    if name6 == "TimerLever" then
      task.spawn(function()
        task.wait(1.25)

        if not val180 or not val180.Parent then
          return
        end

        table.insert(ESPCategories[val181], val180)
        helper55(val180, val181, locked)
      end)

      return
    end

    if name6 == "WaterPump" then
      task.spawn(function()
        local wheel = val180:FindFirstChild("Wheel")

        if wheel then
          local sound2 = wheel:FindFirstChild("Sound")

          if sound2 then
            sound2.Played:Once(function() val180:SetAttribute("CH_Completed", true) end)
          end
        end
      end)
    end
  elseif name6 == "ArchivesTerminal" and CurrentFloor == "Archives" then
    val181 = "Objectives"
    locked = "Archives Terminal"
  elseif name6 == "StairwellTerminal" and CurrentFloor == "Stairwell" then
    val181 = "Objectives"
    locked = "Stairwell Terminal"
  else
    return
  end

  table.insert(ESPCategories[val181], val180)
  helper55(val180, val181, locked)
end

local function helper59(val187, val188)
  local name7 = val187.Name

  if val188 == "Doors" then
    local parentRoom2 = val187:GetAttribute("ParentRoom")
    return "Door " .. (parentRoom2 and tostring(parentRoom2) or "")
  end

  if val188 == "Gold" then
    local gVal = val187:GetAttribute("GoldValue")
    return gVal and ("Gold Pile [" .. tostring(gVal) .. "]") or "Gold"
  end

  if val188 == "Keys" then
    local keyNames = {
      KeyObtain = "Key", ElectricalKeyObtain = "Electrical Key",
      KeyObtainFake = "Fake Key", SkeletonKey = "Skeleton Key",
      IronKey = "Iron Key", KeyIron = "Iron Key", IronKeyForCrypt = "Iron Key"
    }
    return keyNames[name7] or "Key"
  end

  if val188 == "Items" then
    return name7 == "Green_Herb" and "Green Herb" or val103[name7] or name7
  end

  if val188 == "Ladders" then
    return "Ladder"
  end

  if val188 == "Entities" then
    return EntityNotifyData[name7] and EntityNotifyData[name7].Alias or name7
  end

  local val189 = {
    Wardrobe = "Closet", Backdoor_Wardrobe = "Closet", Toolshed = "Closet", RetroWardrobe = "Closet", ["Wardrobe-FOOLS26"] = "Closet", Locker_Large = "Locker", Rooms_Locker = "Locker", Rooms_Locker_Fridge = "Locker", Bed = "Bed", Double_Bed = "Double Bed", CircularVent = "Vent", Dumpster = "Dumpster", }

  if val189[name7] then
    return val189[name7]
  end

  local val190 = {
    KeyObtain = "Key", ElectricalKeyObtain = "Electrical Key", MinesGenerator = "Generator", FuseObtain = "Generator Fuse", LiveHintBook = "Book", LiveBreakerPolePickup = "Fuse Breaker", LibraryHintPaper = "Library Paper", PickupItem = "Library Paper", CringlePresent = "Present", LeverForGate = "Gate Lever", MinesGateButton = "Gate Button", GardenGateButton = "Gate Button", MinesAnchor = "Anchor", WaterPump = "Water Pump", TimerLever = "Timer Lever", VineGuillotine = "Vine Guillotine", ChestBox = "Chest", ChestBoxLocked = "Locked Chest", Toolbox = "Toolbox", Toolbox_Locked = "Locked Toolbox", Chest_Vine = "Vine Chest", Toolshed_Small = "Toolshed", Locker_Small_Locked = "Locked Locker", MouseHole = "Mouse", GoldPile = "Gold", StardustPickup = "Stardust", }

  return val190[name7] or name7
end

local function iterate5(val191)
  local value66 = options[val169[val191]].Value
  local value67 = toggles.ESPShowText.Value
  local value68 = toggles[val191 .. "Tracers"] and toggles[val191 .. "Tracers"].Value

  local value69 = val191 == "Entities" and options.EntitiesESPAllowed
    and options.EntitiesESPAllowed.Value

  for index43, value70 in ipairs(ESPCategories[val191] or {}) do
    local val192 = true

    if value69 and next(value69) ~= nil then
      if not value69[EntityNotifyData[value70.Name] and EntityNotifyData[value70.Name].Alias or value70.Name] then
        val192 = false
      end
    end

    if val192 then
      local val193 = GetESPTarget(value70, val191)

      if val193 then
        local val194 = value70:GetAttribute("ParentRoom") ~= nil

        Functions.AddESP({
          Object = val193, Text = value67 and helper59(value70, val191) or "", Color = value66, }, val194)

        if value68 then
          loader:SetTracersEnabled(val193, true)
        end
      end
    end
  end

  if val191 == "Items" and (toggles.GoldESP and toggles.GoldESP.Value or toggles.ItemsESP and toggles.ItemsESP.Value) then
    for index43, value70 in ipairs(ESPCategories.Gold or {}) do
      local val193 = GetESPTarget(value70, "Gold")
      if val193 then
        local val194 = value70:GetAttribute("ParentRoom") ~= nil
        local gColor = options.GoldESPColor and options.GoldESPColor.Value or Color3.fromRGB(255, 215, 0)
        Functions.AddESP({ Object = val193, Text = value67 and helper59(value70, "Gold") or "", Color = gColor }, val194)
      end
    end
  elseif val191 == "Objectives" and (toggles.KeysESP and toggles.KeysESP.Value or toggles.ObjectivesESP and toggles.ObjectivesESP.Value) then
    for index43, value70 in ipairs(ESPCategories.Keys or {}) do
      local val193 = GetESPTarget(value70, "Keys")
      if val193 then
        local val194 = value70:GetAttribute("ParentRoom") ~= nil
        local kColor = options.KeysESPColor and options.KeysESPColor.Value or Color3.fromRGB(0, 191, 255)
        Functions.AddESP({ Object = val193, Text = value67 and helper59(value70, "Keys") or "", Color = kColor }, val194)
      end
    end
  end
end

local function helper60(val195, text3)
  local val196 = ESPToggleKeys[val195]
  local val197 = val169[val195]

  local val198 = {
    Entities = Color3.fromRGB(255, 0, 0),
    Doors = Color3.fromRGB(0, 255, 0),
    Keys = Color3.fromRGB(0, 191, 255),
    Objectives = Color3.fromRGB(121, 31, 255),
    Items = Color3.fromRGB(170, 85, 255),
    Gold = Color3.fromRGB(255, 215, 0),
    Chests = Color3.fromRGB(210, 150, 100),
    HidingSpots = Color3.fromRGB(255, 99, 225),
    Ladders = Color3.fromRGB(255, 255, 0),
  }

  Groupboxes.Visuals_ESP:AddToggle(val196, { Text = text3, Default = false })

  toggles[val196]:AddColorPicker(val197, { Text = text3, Default = val198[val195] })

  toggles[val196]:OnChanged(function(p115)
    if p115 then
      iterate5(val195)
    else
      iterate4(val195)
    end
  end)

  options[val197]:OnChanged(function(p116)
    for index44, value71 in ipairs(ESPCategories[val195]) do
      local val199 = GetESPTarget(value71, val195)

      if loader.ColorTable and loader.ColorTable[val199] then
        loader:UpdateObjectColor(val199, p116)
      end
    end
  end)
end

Groupboxes.Visuals_ESPBox = element3.Visuals:AddLeftTabbox("ESP / Settings")
Groupboxes.Visuals_ESP = Groupboxes.Visuals_ESPBox:AddTab("ESP")
Groupboxes.Visuals_Settings = Groupboxes.Visuals_ESPBox:AddTab("Settings")

helper60("Entities", "Entities")

Groupboxes.Visuals_ESP:AddDropdown("EntitiesESPAllowed", {
  Text = "Allowed Entities", Values = {
    "Rush", "Ambush", "A-60", "A-120", "Eyes", "Lookman", "Figure", "Backdoor Rush", "Backdoor Lookman", "Groundskeeper", "Gloombat Swarm", "Glitch Rush", "Glitch Ambush", "Frozen Ambush", "Monument", "Jeff the Killer", "Sally", "Dupe", "Giggle", "Snare", "Gloombat Eggs", "Grumble", "Bash", "Drones", "Electric Puddle", "Teller", "Scribbles", "Noise", "Creak", }, Multi = true, AllowNull = true, Tooltip = "Only show ESP for selected entities (leave empty to show all)", })

helper60("Doors", "Doors")
helper60("Keys", "Keys")
helper60("Objectives", "Objectives")
helper60("Items", "Items")
helper60("Gold", "Coins")
helper60("Chests", "Chests")
helper60("HidingSpots", "Hiding Spots")

Groupboxes.Visuals_ESP:AddToggle("PlayersESP", { Text = "Players", Default = false })

toggles.PlayersESP:AddColorPicker("PlayersESPColor", {
  Text = "Players", Default = Color3.fromRGB(255, 255, 255), })

local val200 = {}

local function iterate6()
  for index45, value72 in ipairs(val200) do
    loader:RemoveESP(value72)
    local object6 = ESPCleanup[value72]

    if object6 then
      object6:Disconnect()
      ESPCleanup[value72] = nil
    end
  end

  for i13 = #val200, 1, -1 do
    val200[i13] = nil
  end

  if not toggles.PlayersESP.Value then
    return
  end

  for v307, v308 in players:GetPlayers() do
    if v308 ~= localPlayer2 then
      local character8 = v308.Character

      if character8 then
        if character8:FindFirstChild("HumanoidRootPart")
          or character8:FindFirstChildOfClass("BasePart") then
          local humanoid7 = character8:FindFirstChildOfClass("Humanoid")

          loader:AddESP({
            Object = character8, Text = v308.Name
              .. (humanoid7 and " [" .. math.floor(humanoid7.Health) .. " HP]" or ""), Color = options.PlayersESPColor.Value, })

          ESPCleanup[character8] = character8.Destroying:Once(function()
            loader:RemoveESP(character8)
            ESPCleanup[character8] = nil
          end)

          table.insert(val200, character8)
        end
      end
    end
  end
end

local function helper61(val201)
  if val201 == localPlayer2 then
    return
  end

  local connect21 = val201.CharacterAdded:Connect(function(character9)
    task.wait(0.5)

    if toggles.PlayersESP and toggles.PlayersESP.Value and character9 then
      if character9:FindFirstChild("HumanoidRootPart")
        or character9:FindFirstChildOfClass("BasePart") then
        local humanoid8 = character9:FindFirstChildOfClass("Humanoid")

        loader:AddESP({
          Object = character9, Text = val201.Name
            .. (humanoid8 and " [" .. math.floor(humanoid8.Health) .. " HP]" or ""), Color = options.PlayersESPColor.Value, })

        ESPCleanup[character9] = character9.Destroying:Once(function()
          loader:RemoveESP(character9)
          ESPCleanup[character9] = nil
        end)

        table.insert(val200, character9)
      end
    end
  end)
end

toggles.PlayersESP:OnChanged(function(p118)
  if p118 then
    iterate6()
  else
    iterate6()
  end
end)

options.PlayersESPColor:OnChanged(function(p119)
  for index46, value73 in ipairs(val200) do
    loader:UpdateObjectColor(value73, p119)
  end
end)

players.PlayerAdded:Connect(helper61)

for v309, v310 in players:GetPlayers() do
  if v310 ~= localPlayer2 then
    helper61(v310)
  end
end

iterate6()

Groupboxes.Visuals_ESP:AddToggle("ESPFade", {
  Text = "ESP Fade", Default = false, Tooltip = "Enables smooth fading effect on ESP highlights", })

Groupboxes.Visuals_ESP:AddSlider("ESPFadeTime", {
  Text = "Fade Time", Min = 0, Max = 1, Default = 0.25, Rounding = 2, Compact = true, Suffix = "s", })

Groupboxes.Visuals_ESP:AddToggle("ESPArrowsToggle", {
  Text = "Enable Arrows", Default = false, Tooltip = "Shows arrows that point to off-screen objects", })

Groupboxes.Visuals_ESP:AddSlider("ESPArrowsRadius", {
  Text = "Arrow Radius", Min = 100, Max = 500, Default = 250, Rounding = 0, Compact = true, Suffix = " px", })

local val202 = { MainTab = nil, MainButton = nil, NoclipConn = nil }

LobbyFlyState = {
  Flying = false, FlyKeyDown = nil, FlyKeyUp = nil, BodyGyro = nil, BodyVelocity = nil, Control = nil, LastControl = nil, Speed = 0, SpeedCoeff = 1, }

local function helper62()
  if not LobbyFlyState.Flying then
    return
  end

  LobbyFlyState.Flying = false

  if LobbyFlyState.FlyKeyDown then
    LobbyFlyState.FlyKeyDown:Disconnect()
    LobbyFlyState.FlyKeyDown = nil
  end

  if LobbyFlyState.FlyKeyUp then
    LobbyFlyState.FlyKeyUp:Disconnect()
    LobbyFlyState.FlyKeyUp = nil
  end

  if LobbyFlyState.BodyGyro then
    LobbyFlyState.BodyGyro:Destroy()
    LobbyFlyState.BodyGyro = nil
  end

  if LobbyFlyState.BodyVelocity then
    LobbyFlyState.BodyVelocity:Destroy()
    LobbyFlyState.BodyVelocity = nil
  end

  local humanoid9 = character and character:FindFirstChildOfClass("Humanoid")

  if humanoid9 then
    humanoid9.PlatformStand = false
  end

  pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
end

local function helper63()
  if LobbyFlyState.Flying then
    return
  end

  if not character then
    return
  end

  local humanoid10 = character:FindFirstChildOfClass("Humanoid")

  if not humanoid10 then
    return
  end

  local rootPart = humanoid10.RootPart or character:FindFirstChild("HumanoidRootPart")
    or character:FindFirstChildOfClass("Part")

  if not rootPart then
    return
  end

  helper62()

  local lobbyFlyState = LobbyFlyState
  lobbyFlyState.Flying = true

  lobbyFlyState.Control = {
    F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0, }

  lobbyFlyState.LastControl = {
    F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0, }

  lobbyFlyState.Speed = 0
  lobbyFlyState.SpeedCoeff = (options.LobbyFlySpeed and options.LobbyFlySpeed.Value or 35) / 50

  local bodyGyro = Instance.new("BodyGyro")
  bodyGyro.P = 90000
  bodyGyro.MaxTorque = Vector3.new(9000000000, 9000000000, 9000000000)
  bodyGyro.CFrame = rootPart.CFrame
  bodyGyro.Parent = rootPart

  local bodyVelocity = Instance.new("BodyVelocity")
  bodyVelocity.Velocity = Vector3.new(0, 0, 0)
  bodyVelocity.MaxForce = Vector3.new(9000000000, 9000000000, 9000000000)
  bodyVelocity.Parent = rootPart

  lobbyFlyState.BodyGyro = bodyGyro
  lobbyFlyState.BodyVelocity = bodyVelocity

  lobbyFlyState.FlyKeyDown = userInputService.InputBegan:Connect(function(input5, p120)
    if p120 then
      return
    end

    local control = lobbyFlyState.Control
    local speedCoeff = lobbyFlyState.SpeedCoeff

    if input5.KeyCode == Enum.KeyCode.W then
      control.F = speedCoeff
    elseif input5.KeyCode == Enum.KeyCode.S then
      control.B = -speedCoeff
    elseif input5.KeyCode == Enum.KeyCode.A then
      control.L = -speedCoeff
    elseif input5.KeyCode == Enum.KeyCode.D then
      control.R = speedCoeff
    elseif input5.KeyCode == Enum.KeyCode.E then
      control.Q = speedCoeff * 2
    elseif input5.KeyCode == Enum.KeyCode.Q then
      control.E = -speedCoeff * 2
    end

    pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Track end)
  end)

  lobbyFlyState.FlyKeyUp = userInputService.InputEnded:Connect(function(input6, p121)
    if p121 then
      return
    end

    local control2 = lobbyFlyState.Control

    if input6.KeyCode == Enum.KeyCode.W then
      control2.F = 0
    elseif input6.KeyCode == Enum.KeyCode.S then
      control2.B = 0
    elseif input6.KeyCode == Enum.KeyCode.A then
      control2.L = 0
    elseif input6.KeyCode == Enum.KeyCode.D then
      control2.R = 0
    elseif input6.KeyCode == Enum.KeyCode.E then
      control2.Q = 0
    elseif input6.KeyCode == Enum.KeyCode.Q then
      control2.E = 0
    end
  end)

  task.spawn(function()
    repeat
      task.wait()

      if not lobbyFlyState.Flying then
        break
      end

      local currentCamera4 = workspace.CurrentCamera
      humanoid10.PlatformStand = true
      local control3 = lobbyFlyState.Control
      local lastControl = lobbyFlyState.LastControl
      local speed = lobbyFlyState.Speed

      if control3.L + control3.R ~= 0 or control3.F + control3.B ~= 0
        or control3.Q + control3.E ~= 0 then
        speed = 50
      elseif not (control3.L + control3.R ~= 0 or control3.F + control3.B ~= 0
          or control3.Q + control3.E ~= 0)
        and speed ~= 0 then
        speed = 0
      end

      if control3.L + control3.R ~= 0 or control3.F + control3.B ~= 0
        or control3.Q + control3.E ~= 0 then
        pcall(function()
          bodyVelocity.Velocity = (currentCamera4.CFrame.LookVector * (control3.F + control3.B) + (currentCamera4.CFrame * CFrame.new(
            control3.L + control3.R, (control3.F + control3.B + control3.Q + control3.E) * 0.2, 0
          ).Position - currentCamera4.CFrame.Position)) * speed
        end)

        lastControl.F, lastControl.B, lastControl.L, lastControl.R = control3.F, control3.B, control3.L, control3.R
      elseif control3.L + control3.R == 0 and control3.F + control3.B == 0
        and control3.Q + control3.E == 0 and speed ~= 0 then
        pcall(function()
          bodyVelocity.Velocity = (currentCamera4.CFrame.LookVector * (lastControl.F + lastControl.B) + (currentCamera4.CFrame * CFrame.new(
            lastControl.L + lastControl.R, (lastControl.F + lastControl.B + control3.Q + control3.E) * 0.2, 0
          ).Position - currentCamera4.CFrame.Position)) * speed
        end)
      else
        pcall(function() bodyVelocity.Velocity = Vector3.new(0, 0, 0) end)
      end

      pcall(function() bodyGyro.CFrame = currentCamera4.CFrame end)
      lobbyFlyState.Speed = speed
    until not lobbyFlyState.Flying

    helper62()
  end)
end

function val202.MainTab()
  if type(val202.MainTab) ~= "function" then
    return
  end

  local addTab2 = moroWindow:AddTab("LobbyMain", "house")

  val202.MainTab = addTab2
  val202.MainButton = helper3(addTab2)

  local label = safeCall6(addTab2)

  if label then
    label.Text = "Main"
  end

  if val202.MainButton then
    val202.MainButton.Visible = false
  end

  local stuff = addTab2:AddLeftGroupbox("Stuff")

  stuff:AddButton({
    Text = "Free Rooms", Callback = function()
      local createElevator = remotesFolder2 and remotesFolder2:FindFirstChild("CreateElevator")

      if createElevator then
        createElevator:FireServer({
          Mods = { "AdminPanel" }, Settings = {}, Destination = "Rooms", FriendsOnly = false, MaxPlayers = "1", })
      end
    end, })

  stuff:AddButton({
    Text = "Free Outdoors", Callback = function()
      local createElevator2 = remotesFolder2 and remotesFolder2:FindFirstChild("CreateElevator")

      if createElevator2 then
        createElevator2:FireServer({
          Mods = { "AdminPanel" }, Settings = {}, Destination = "Garden", FriendsOnly = false, MaxPlayers = "1", })
      end
    end, })

  stuff:AddLabel({
    Text = "<font size=\"16\">This puts you into a game of rooms/outdoors, but with the admin panel modifier, meaning that it is free, but you can not get any achievements/progress.</font>", DoesWrap = true, })

  stuff:AddDivider()

  stuff:AddToggle("AutoJoinElevator", {
    Text = "Auto Join Elevator", Default = false, Tooltip = "Automatically joins the selected player's elevator.", })

  stuff:AddDropdown("AutoJoinElevatorTarget", {
    Text = "Target", SpecialType = "Player", ExcludeLocalPlayer = true, Searchable = true, })

  stuff:AddButton({
    Text = "Redeem All Codes", Callback = function()
      if val85.RedeemingCodes then
        return
      end

      library:Notify({ Title = "Redeeming " .. #val85.CodesList .. " codes.", Time = 5 })
      val85.RedeemingCodes = true

      for index47, value74 in ipairs(val85.CodesList) do
        local shopCode = remotesFolder2 and remotesFolder2:FindFirstChild("ShopCode")

        if shopCode then
          shopCode:FireServer(value74)
        end

        task.wait(5.1)
      end

      val85.RedeemingCodes = false
    end, })

  local otherStuff = addTab2:AddRightGroupbox("Other stuff")
  otherStuff:AddToggle("LobbyNoclip", { Text = "Noclip", Default = false })

  toggles.LobbyNoclip:OnChanged(function(p122)
    if val202.NoclipConn then
      val202.NoclipConn:Disconnect()
    end

    if p122 and character then
      for v313, v314 in character:GetDescendants() do
        if v314:IsA("BasePart") then
          v314.CanCollide = false
        end
      end

      val202.NoclipConn = character.ChildAdded:Connect(function(child7)
        task.wait()

        if child7:IsA("BasePart") then
          child7.CanCollide = false
        end
      end)
    end
  end)

  otherStuff:AddToggle("LobbyFly", { Text = "Fly", Default = false })

  toggles.LobbyFly:OnChanged(function(p123)
    if p123 then
      helper63()
    else
      helper62()
    end
  end)

  otherStuff:AddSlider("LobbyFlySpeed", {
    Text = "Fly Speed", Min = 25, Max = 150, Default = 35, Rounding = 0, Compact = true, })

  options.LobbyFlySpeed:OnChanged(function()
    LobbyFlyState.SpeedCoeff = (options.LobbyFlySpeed and options.LobbyFlySpeed.Value or 35)
      / 50
  end)
end

local val203 = { "Main", "Visuals", "Exploits", "Miscellaneous", "Mines", "Archives", "Settings" }

local function helper64()
  local val204 = helper11()

  if val204 == CurrentFloor then
    return
  end

  CurrentFloor = val204
  local val205 = val204 == "" or val204 == "Lobby"
  local val206 = val204 == "Hotel" or val204 == "OldHotel"
  local val207 = val204 == "Mines"
  local val208 = val204 == "Garden"
  local val209 = val204 == "Fools"
  local val210 = val204 == "OldHotel"
  local val211 = val204 == "Rooms"
  local val212 = val204 == "Archives"
  local val213 = val204 == "Stairwell"

  if val205 then
    val85.InLobby = true
    val202.MainTab()

    if element3.Home then
      element3.Home:SetVisible(true)
    end

    for index48, value75 in ipairs(val203) do
      local object7 = element3[value75]

      if object7 then
        object7:SetVisible(false)
      end
    end

    if val202.MainButton then
      val202.MainButton.Visible = true
    end

    if not helper4(element3.Home) and not helper4(val202.MainTab) then
      element3.Home:Show()
    end

    for index49, value76 in ipairs({
      "Godmode", "ThirdPerson", "Noclip", "FlyToggle", "Phase", "AnticheatManipulation", "AutoInteract", "ArchiveChairFly", "StairwellChairFly", "AntiElectricPuddle", "AntiRansom", "AntiScribbles", "NoAlmaDamage", "AntiDrone", "DisableDroneStampede", "RoomsAutoWalk", "RoomsAutoWalkIgnoreA60", "RoomsAutoWalkShowPathToggle", "RoomsAutoWalkSpoofFootsteps", "RoomsPickupStardust", "RoomsPickupGold", "NoSurgeDamage", "RemoveSurge", "RemoveMandrake", "BypassKillbricks", "BypassSeekingWall", "BypassBanana", "BypassJeff", "BypassGiggle", "BypassDupe", "BypassEyes", "BypassLookman", "BypassGloombatEggs", "BypassSeekObstructions", "BypassVacuum", "BypassSnare", "RemoveSeekTrigger", "RemoveFigure", "RemoveFigureMines", "RemoveA90", "RemoveDread", "AutoRevive", "FigureGodmode", "AutoSteerMinecart", "AutoSolveAnchors", "MinecartTeleport", "AutoMinecart", "AutoHeartbeatMinigame", "AutoBreakerBox", "AutoLibraryBruteForce", "InfiniteItemsToggle", "InfiniteCrucifix", "ShowSeekPathToggle", }) do
      local element27 = toggles[value76]

      if element27 and element27.Value then
        element27:SetValue(false)
      end
    end

    if not val85.LobbyGuardConnection then
      val85.LobbyGuardConnection = runService.Heartbeat:Connect(function()
        if _Unloading then
          return
        end

        if not val85.InLobby then
          return
        end

        for index50, value77 in ipairs({
          "Godmode", "ThirdPerson", "Noclip", "FlyToggle", "Phase", "AnticheatManipulation", "AutoInteract", }) do
          local element28 = toggles[value77]

          if element28 and element28.Value then
            element28:SetValue(false)
          end
        end

        if toggles.AutoJoinElevator and toggles.AutoJoinElevator.Value then
          local character10

          if typeof(options.AutoJoinElevatorTarget.Value) == "Instance" then
            character10 = options.AutoJoinElevatorTarget.Value.Character
          elseif typeof(options.AutoJoinElevatorTarget.Value) == "string" then
            character10 = players:FindFirstChild(options.AutoJoinElevatorTarget.Value).Character
          end

          local val214 = false

          local lobbyElevators = workspace:FindFirstChild("Lobby")
            and workspace.Lobby:FindFirstChild("LobbyElevators")

          if lobbyElevators then
            for v330, v331 in lobbyElevators:GetChildren() do
              if character10 and v331 and character10:GetAttribute("InGameElevator")
                and v331:GetAttribute("ID")
                and v331:GetAttribute("ID") == character10:GetAttribute("InGameElevator") then
                val214 = true

                if remotesFolder2 and remotesFolder2:FindFirstChild("ElevatorJoin") then
                  remotesFolder2.ElevatorJoin:FireServer(v331)
                end
              end
            end
          end

          if not val214 and remotesFolder2 and remotesFolder2:FindFirstChild("ElevatorExit") then
            remotesFolder2.ElevatorExit:FireServer()
          end
        end
      end)
    end

    if element3.FoolsHotel then
      element3.FoolsHotel:SetVisible(false)
    end

    if element3.Rooms then
      element3.Rooms:SetVisible(false)
    end

    if element3.Stairwell then
      element3.Stairwell:SetVisible(false)
    end

    return
  end

  val85.InLobby = false

  if val85.LobbyGuardConnection then
    val85.LobbyGuardConnection:Disconnect()
    val85.LobbyGuardConnection = nil
  end

  if val202.MainTab then
    if val202.MainButton then
      val202.MainButton.Visible = false
    end

    if toggles.LobbyNoclip then
      toggles.LobbyNoclip:SetValue(false)
    end

    if toggles.LobbyFly then
      toggles.LobbyFly:SetValue(false)
    end

    if helper4(val202.MainTab) then
      element3.Home:Show()
    end
  end

  if CurrentFloor and CurrentFloor ~= "Lobby" then
    TableClear(ESPCleanup)
    TableClear(ESPBlacklist)

    for key10, value78 in pairs(ESPCategories) do
      TableClear(value78)
    end

    for index51, value79 in ipairs(val114.Entities) do
      if value79.Name == "FakeDoor" or value79.Name == "DoorFake" then
        local hidden = value79:FindFirstChild("Hidden")

        if hidden then
          hidden.CanTouch = true
        end

        local lock2 = value79:FindFirstChild("Lock")

        if lock2 and lock2:FindFirstChild("UnlockPrompt") then
          lock2.UnlockPrompt.Enabled = true
        end
      end

      if value79.Name == "SideroomSpace" then
        local collision3 = value79:FindFirstChild("Collision")

        if collision3 then
          collision3.CanCollide = false
          collision3.CanTouch = true
        end
      end
    end

    for index52, value80 in ipairs(val114.Entities) do
    end

    TableClear(val114.Entities)
    TableClear(val114.HidingSpots)
    TableClear(val114.Obstructions)
    TableClear(val114.SeekObstructions)
    TableClear(val114.SeekBridges)
    TableClear(val114.SeekNodes)
    TableClear(val114.SeekDuckBoards)
    TableClear(val114.SeekHighlights)
    TableClear(val114.EyestalkHighlights)
    TableClear(val114.PathLights)
    TableClear(val114.EventTriggers)
  end

  local val215 = not (val206 or val207)

  if options.SpamBuyCount then
    pcall(function() options.SpamBuyCount:SetDisabled(val215) end)
  end

  if options.SpamBuyItems then
    pcall(function() options.SpamBuyItems:SetDisabled(val215) end)
  end

  if val206 and options.SpamBuyItems then
    local val216 = { "Lockpick", "Lighter", "Flashlight", "Vitamins" }

    if val210 then
      table.insert(val216, "Crucifix")
      table.insert(val216, "Skeleton Key")
    end

    pcall(options.SpamBuyItems.SetValues, options.SpamBuyItems, val216)
  elseif val207 and options.SpamBuyItems then
    pcall(options.SpamBuyItems.SetValues, options.SpamBuyItems, {
      "Straplight", "Bulklight", "BandagePack", "Lockpick", })
  end

  if toggles.ShowCrucifix then
    pcall(function() toggles.ShowCrucifix:SetDisabled(not val210) end)
  end

  if toggles.ShowSkeletonKey then
    pcall(function() toggles.ShowSkeletonKey:SetDisabled(not val210) end)
  end

  local val217 = not (val206 or type(val204) == "string" and val204:find("Fools"))

  if toggles.AutoUnlockPadlockToggle then
    pcall(function() toggles.AutoUnlockPadlockToggle:SetDisabled(val217) end)
  end

  if toggles.AutoBreakerBox then
    pcall(function() toggles.AutoBreakerBox:SetDisabled(val217) end)
  end

  if toggles.AutoLibraryBruteForce then
    pcall(function() toggles.AutoLibraryBruteForce:SetDisabled(val217) end)
  end

  if toggles.OrbitItems then
    pcall(function() toggles.OrbitItems:SetDisabled(val209) end)
  end

  if element3.Mines then
    element3.Mines:SetVisible(val207)
  end

  for index53, value81 in ipairs(val203) do
    if value81 ~= "Mines" and value81 ~= "Archives" then
      local object8 = element3[value81]

      if object8 then
        object8:SetVisible(true)
      end
    end
  end

  if element3.Mines and not val207 and helper4(element3.Mines) then
    element3.Home:Show()
  end

  if element3.FoolsHotel then
    if val209 or val210 then
      element3.FoolsHotel:SetVisible(true)

      if element3.FoolsHotel.TabLabelRef then
        element3.FoolsHotel.TabLabelRef.Text = val209 and "Fools" or "Hotel-/Fools"
      end

      for index54, value82 in ipairs(Groupboxes.SubfloorsFools.Elements) do
        if index54 <= 5 then
          value82.Holder.Visible = val209
        end
      end
    else
      if helper4(element3.FoolsHotel) then
        element3.Home:Show()
      end

      element3.FoolsHotel:SetVisible(false)
    end
  end

  if element3.Garden then
    if val208 then
      element3.Garden:SetVisible(true)
    else
      if helper4(element3.Garden) then
        element3.Home:Show()
      end

      element3.Garden:SetVisible(false)
    end
  end

  if element3.Rooms then
    if val211 then
      element3.Rooms:SetVisible(true)
    else
      if helper4(element3.Rooms) then
        element3.Home:Show()
      end

      element3.Rooms:SetVisible(false)
    end
  end

  if element3.Archives then
    if val212 then
      element3.Archives:SetVisible(true)
    else
      if helper4(element3.Archives) then
        element3.Home:Show()
      end

      element3.Archives:SetVisible(false)
    end
  end

  if element3.Stairwell then
    if val213 then
      element3.Stairwell:SetVisible(true)
    else
      if helper4(element3.Stairwell) then
        element3.Home:Show()
      end

      element3.Stairwell:SetVisible(false)
    end
  end

  if toggles.LaddersESP and toggles.LaddersESP.Value then
    for index55, value83 in ipairs(ESPCategories.Ladders) do
      if val207 then
        helper55(value83, "Ladders", "Ladder")
      else
        Functions.RemoveESP(value83)
      end
    end
  end
end

local function helper65()
  local val218, val219 = nil, -1
  local currentRooms7 = workspace:FindFirstChild("CurrentRooms")

  if not currentRooms7 then
    return nil
  end

  for index56, value84 in ipairs(currentRooms7:GetChildren()) do
    local numVal10 = tonumber(value84.Name)

    if numVal10 and numVal10 >= val219 then
      local assets2 = value84:FindFirstChild("Assets")
      local archivesClock = assets2 and assets2:FindFirstChild("ArchivesClock")

      if archivesClock then
        val218, val219 = archivesClock, numVal10
      end
    end
  end

  return val218
end

local function helper66(val220)
  local floorVal = math.floor(val220 / 60)
  local val221 = val220 % 60
  local val222 = floorVal >= 12 and "PM" or "AM"
  local val223 = floorVal % 12

  if val223 == 0 then
    val223 = 12
  end

  return string.format("%d:%02d %s", val223, val221, val222)
end

Groupboxes.ArchivesMain = element3.Archives:AddLeftGroupbox("Archives")

Groupboxes.ArchivesMain:AddToggle("AntiDrone", {
  Text = "Anti Drone", Default = false, Tooltip = "Prevents you from bumping/falling over when walking into (singular) drones", })

Groupboxes.ArchivesMain:AddToggle("DisableDroneStampede", {
  Text = "Disable Drone Stampede (FE)", Default = false, Tooltip = "Disables the drone stampede from spawning FE", })

toggles.DisableDroneStampede:OnChanged(function(p125)
  if p125 and not val85.DisableDroneStampedeRunning then
    val85.DisableDroneStampedeRunning = true

    task.spawn(function()
      while toggles.DisableDroneStampede.Value do
        local object9 = helper65()
        local lookedAtRemote = object9 and object9:FindFirstChild("LookedAtRemote")

        if lookedAtRemote then
          pcall(function() lookedAtRemote:FireServer() end)
        end

        task.wait(0.5)
      end

      val85.DisableDroneStampedeRunning = false
    end)
  end
end)

Groupboxes.ArchivesMain:AddToggle("DroneTimer", {
  Text = "Drone Stampede Timer", Default = false, Tooltip = "Notifies you 60s and 30s before the 05:00 and 09:00 drone stampede", })

toggles.DroneTimer:OnChanged(function(p126)
  if p126 and not val85.DroneTimerRunning then
    val85.DroneTimerRunning = true

    task.spawn(function()
      local val224 = {}

      while toggles.DroneTimer.Value do
        local object10 = helper65()
        local time = object10 and object10:FindFirstChild("Time")
        local textLabel3 = time and time:FindFirstChild("TextLabel")
        local text4 = textLabel3 and textLabel3.Text

        if text4 then
          local val225, val226 = text4:match("(%d+):(%d+)")

          if val225 and val226 then
            local numVal11 = tonumber(val225) * 60 + tonumber(val226)

            for index57, value85 in ipairs({ 300, 540 }) do
              local val227 = (value85 - numVal11) % 1440

              if val227 > 90 then
                val224["h_" .. value85] = nil
                val224["m_" .. value85] = nil
              else
                if val227 <= 60 and val227 > 0 and not val224["h_" .. value85] then
                  val224["h_" .. value85] = true

                  library:Notify({
                    Title = "Drones", Description = string.format("Drone stampede in 1 hour (%s)", helper66(value85)), Time = 5, })
                end

                if val227 <= 30 and val227 > 0 and not val224["m_" .. value85] then
                  val224["m_" .. value85] = true

                  library:Notify({
                    Title = "Drones", Description = string.format(
                      "Drone stampede in 30 minutes (%s)", helper66(value85)
                    ), Time = 5, })
                end
              end
            end
          end
        end

        task.wait(1)
      end

      val85.DroneTimerRunning = false
    end)
  end
end)

Groupboxes.ArchivesMain:AddToggle("NoAlmaDamage", {
  Text = "Anti Alma", Default = false, Tooltip = "Prevents alma from ever interacting with you/you can look at her freely", })

toggles.NoAlmaDamage:OnChanged(function(p127)
  if p127 and not val85.NoAlmaDamageRunning then
    val85.NoAlmaDamageRunning = true

    local function helper67(val228)
      local waitForChild2 = val228:WaitForChild("Config", 5)

      if not waitForChild2 then
        return
      end

      for key11, value86 in pairs({
        idle_angerGain = 0, idle_angerIndirectGain = 0, idle_angerDecay = 100, aggro_initialWindup = 9999, aggro_subsequentWindups = 9999, attack_slashCount = 0, attack_dashSpeed = 0, attack_hitDistance = 0, attack_minigameLength = 9999, }) do
        local val229, val230 = key11:match("^([^_]+)_(.+)$")
        local findFirstChild9 = waitForChild2:FindFirstChild(val229)
        local findFirstChild10 = findFirstChild9 and findFirstChild9:FindFirstChild(val230)

        if findFirstChild10 and findFirstChild10:IsA("ValueBase") then
          findFirstChild10.Changed:Connect(function()
            if findFirstChild10.Value ~= value86 then
              findFirstChild10.Value = value86
            end
          end)

          findFirstChild10.Value = value86
        end
      end
    end

    local function helper68(val231)
      if val231:IsA("RemoteEvent") and val231.Name == "AlmaChangeState" then
        local parent5 = val231.Parent

        if parent5 then
          helper67(parent5)
        end
      end
    end

    Connections.NoAlmaDamage = workspace.DescendantAdded:Connect(helper68)

    for index58, value87 in ipairs(workspace:GetDescendants()) do
      helper68(value87)
    end
  elseif not p127 then
    val85.NoAlmaDamageRunning = false

    if Connections.NoAlmaDamage then
      Connections.NoAlmaDamage:Disconnect()
      Connections.NoAlmaDamage = nil
    end
  end
end)

Groupboxes.ArchivesMain:AddToggle("AntiElectricPuddle", {
  Text = "Anti Electric Puddle", Default = false, Tooltip = "Moves your character above to not step on electric puddles", })

toggles.AntiElectricPuddle:OnChanged(function(p130)
  if p130 then
    val85.DefaultHipHeight = val85.DefaultHipHeight or humanoid and humanoid.HipHeight or 2.396

    Connections.AntiElectricPuddle = runService.Heartbeat:Connect(function()
      if val83 and val83.Sunk then
        return
      end

      if humanoid and humanoid.FloorMaterial == Enum.Material.Glass then
        if humanoid.HipHeight ~= 3 then
          humanoid.HipHeight = 3
        end
      elseif humanoid and val85.DefaultHipHeight then
        if humanoid.HipHeight ~= val85.DefaultHipHeight then
          humanoid.HipHeight = val85.DefaultHipHeight
        end
      end
    end)
  else
    if Connections.AntiElectricPuddle then
      Connections.AntiElectricPuddle:Disconnect()
      Connections.AntiElectricPuddle = nil
    end

    if humanoid and val85.DefaultHipHeight then
      humanoid.HipHeight = val85.DefaultHipHeight
    end
  end
end)

Groupboxes.ArchivesMain:AddToggle("AntiRansom", {
  Text = "Anti Ransom", Default = false, Tooltip = "Prevents ransom from attacking you even when moving", Disabled = not (Executor.hookmetamethod and Executor.newcclosure and Executor.getnamecallmethod), DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.ArchivesMain:AddToggle("AntiScribbles", {
  Text = "No Scribbles Damage", Default = false, Tooltip = "Prevents scribbles from damaging you", Disabled = not (Executor.hookmetamethod and Executor.newcclosure and Executor.getnamecallmethod), DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.ArchivesMain:AddToggle("ArchiveChairFly", {
  Text = "Chair Anticheat Bypass", Default = false, Tooltip = "Allows you to bypass the anticheat by flying on a chair, allowing you to noclip and fly freely, drag an office chair, then sit in it and press the 'Start Bypass' button", })

Groupboxes.ArchivesMain:AddSlider("ArchiveChairFlySpeed", {
  Text = "Chair Speed", Min = 15, Max = 150, Default = 55, Rounding = 0, })

Groupboxes.ArchivesMain:AddButton({
  Text = "Start Bypass", Tooltip = "Press this AFTER you have dragged the chair and sat in it, shift to go down and ctrl and then space to exit (or just turn off the toggle)", Callback = function()
    if not toggles.ArchiveChairFly.Value then
      toggles.ArchiveChairFly:SetValue(true)
    else
      helper48()
    end
  end, })

toggles.ArchiveChairFly:OnChanged(function()
  if toggles.ArchiveChairFly.Value then
    helper48()
  else
    helper46()
  end
end)

Groupboxes.StairwellMain = element3.Stairwell:AddLeftGroupbox("Stairwell")

Groupboxes.StairwellMain:AddToggle("StairwellChairFly", {
  Text = "Chair Anticheat Bypass", Default = false, Tooltip = "Allows you to bypass the anticheat by flying on a chair, allowing you to noclip and fly freely, drag an office chair, then sit in it and press the 'Start Bypass' button", })

Groupboxes.StairwellMain:AddSlider("StairwellChairFlySpeed", {
  Text = "Chair Speed", Min = 15, Max = 150, Default = 55, Rounding = 0, })

Groupboxes.StairwellMain:AddButton({
  Text = "Start Bypass", Tooltip = "Press this AFTER you have dragged the chair and sat in it, shift to go down and ctrl and then space to exit (or just turn off the toggle)", Callback = function()
    if not toggles.StairwellChairFly.Value then
      toggles.StairwellChairFly:SetValue(true)
    else
      helper48()
    end
  end, })

toggles.StairwellChairFly:OnChanged(function()
  if toggles.StairwellChairFly.Value then
    helper48()
  else
    helper46()
  end
end)

Groupboxes.SubfloorsRooms = element3.Rooms:AddLeftGroupbox("Rooms")

Groupboxes.SubfloorsRooms:AddToggle("RoomsAutoWalk", {
  Text = "Auto Rooms", Default = false, Tooltip = "Automatically moves and hides from entities in The Rooms (stops at A-1000)", })

Groupboxes.SubfloorsRooms:AddSlider("RoomsAutoWalkPathfindTimeout", {
  Text = "Pathfind Timeout", Min = 0.5, Max = 3, Default = 1, Rounding = 1, })

Groupboxes.SubfloorsRooms:AddToggle("RoomsAutoWalkIgnoreA60", {
  Text = "Ignore A-60", Default = false, Tooltip = "Continues to walk if A-60 spawns, enables godmode", })

Groupboxes.SubfloorsRooms:AddToggle("RoomsAutoWalkShowPathToggle", {
  Text = "Show Path", Default = false, Tooltip = "Shows the current path of rooms auto-walk", })

toggles.RoomsAutoWalkShowPathToggle:AddColorPicker("RoomsAutoWalkShowPathColor", {
  Text = "Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0, })

Groupboxes.SubfloorsRooms:AddToggle("RoomsAutoWalkSpoofFootsteps", {
  Text = "Spoof Footsteps", Default = false, Tooltip = "Makes it appear as if your character is walking normally", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.SubfloorsRooms:AddDivider()

Groupboxes.SubfloorsRooms:AddToggle("RoomsPickupStardust", {
  Text = "Pickup Stardust", Default = false, Tooltip = "Automatically pathfinds to stardust in the current room", })

Groupboxes.SubfloorsRooms:AddToggle("RoomsPickupGold", {
  Text = "Pickup Gold", Default = false, Tooltip = "Automatically pathfinds to gold piles in the current room", })

Groupboxes.SubfloorsOutdoors = element3.Garden:AddLeftGroupbox("Outdoors")

Groupboxes.SubfloorsOutdoors:AddToggle("NoSurgeDamage", {
  Text = "No Surge Damage", Default = false, Tooltip = "Prevents Surge from hurting you", })

toggles.NoSurgeDamage:OnChanged(function(p131)
  if not remotesFolder2 then
    return
  end

  if p131 then
    if FakeEvents.Surge_Real and FakeEvents.Surge_Real.Parent then
      FakeEvents.Surge.Parent = remotesFolder2
      FakeEvents.Surge_Real.Parent = nil
    end
  elseif FakeEvents.Surge_Real then
    FakeEvents.Surge_Real.Parent = remotesFolder2
    FakeEvents.Surge.Parent = nil
  end
end)

Groupboxes.SubfloorsOutdoors:AddToggle("RemoveSurge", {
  Text = "Remove Surge", Default = false, Tooltip = "Prevents Surge from spawning", })

toggles.RemoveSurge:OnChanged(function(p132)
  if val85.SurgeFrame then
    val85.SurgeFrame.Name = p132 and "SurgeVignette_Disabled" or "SurgeVignette"
  end
end)

Groupboxes.SubfloorsOutdoors:AddToggle("RemoveMandrake", {
  Text = "Disable Mandrake (FE)", Default = false, Tooltip = "Prevents mandrakes from attacking you, but this is inconsistent", })

toggles.RemoveMandrake:OnChanged(function(p133)
  for v352, v353 in val114.Entities do
    if v353.Name == "Root" and v353:IsA("BasePart") then
      local antiMandrakeForce2 = v353:FindFirstChild("AntiMandrakeForce")

      if p133 then
        if not antiMandrakeForce2 then
          antiMandrakeForce2 = Instance.new("BodyForce")
          antiMandrakeForce2.Name = "AntiMandrakeForce"
          antiMandrakeForce2.Parent = v353
        end

        antiMandrakeForce2.Force = Vector3.new(100000, -99999999, 100000)
      elseif antiMandrakeForce2 then
        antiMandrakeForce2:Destroy()
      end
    end
  end
end)

Groupboxes.SubfloorsOutdoors:AddToggle("ShowEyestalkPathToggle", {
  Text = "Show Eyestalk Path", Default = false, Tooltip = "Shows you the correct path in the eyestalk chase", })

toggles.ShowEyestalkPathToggle:AddColorPicker("ShowEyestalkPathColor", {
  Text = "Eyestalk Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0, })

local iterate7

toggles.ShowEyestalkPathToggle:OnChanged(function(p134)
  iterate7(val114.EyestalkHighlights, "ShowEyestalkPathColor", p134)
end)

local iterate8
options.ShowEyestalkPathColor:OnChanged(function(p135) iterate8(val114.EyestalkHighlights, p135) end)
element3.Garden:SetVisible(false)

val85.RoomsNodesFolder = Instance.new("Folder")
val85.RoomsNodesFolder.Name = "RoomsPathNodes"
val85.RoomsNodesFolder.Parent = workspace
val85.SeekNodesFolder = Instance.new("Folder")
val85.SeekNodesFolder.Name = "SeekPathNodes"
val85.SeekNodesFolder.Parent = workspace

toggles.BypassKillbricks:OnChanged(function(p136)
  for v354, v355 in workspace:GetDescendants() do
    if v355.Name == "Lava" and v355:IsA("BasePart") then
      v355.CanTouch = not p136
    end
  end
end)

toggles.BypassSeekingWall:OnChanged(function(p137)
  for v356, v357 in workspace:GetDescendants() do
    if v357.Name == "ScaryWall" then
      for v358, v359 in v357:GetDescendants() do
        if v359:IsA("BasePart") then
          v359.CanTouch = not p137
          v359.CanCollide = not p137
        end
      end
    end
  end
end)

toggles.BypassBanana:OnChanged(function(p138)
  for v360, v361 in workspace:GetDescendants() do
    if v361.Name == "BananaPeel" and v361:IsA("BasePart") then
      v361.CanTouch = not p138
    end
  end
end)

toggles.BypassJeff:OnChanged(function(p139)
  for v362, v363 in workspace:GetDescendants() do
    if v363.Name == "JeffTheKiller" then
      for v364, v365 in v363:GetDescendants() do
        if v365:IsA("BasePart") then
          v365.CanCollide = not p139
          v365.CanTouch = not p139
        end
      end

      local humanoid11 = v363:FindFirstChildOfClass("Humanoid")

      if humanoid11 then
        humanoid11.Health = 0
      end
    end
  end
end)

toggles.RemoveSeekTrigger:OnChanged(function(p140)
  if p140 and Executor.firetouchinterest then
    for index59, value88 in ipairs(val114.Entities) do
      if value88.Name == "TriggerEventCollision" then
        for v366, v367 in value88:GetChildren() do
          if v367:IsA("BasePart") and humanoidRootPart then
            Executor.firetouchinterest(humanoidRootPart, v367, 0)
            task.wait()
            Executor.firetouchinterest(humanoidRootPart, v367, 1)
          end
        end
      end
    end

    task.spawn(function()
      while toggles.RemoveSeekTrigger.Value do
        for index60, value89 in ipairs(val114.Entities) do
          if value89.Name == "TriggerEventCollision" and humanoidRootPart then
            for v368, v369 in value89:GetChildren() do
              if v369:IsA("BasePart") then
                Executor.firetouchinterest(humanoidRootPart, v369, 0)
                task.wait()
                Executor.firetouchinterest(humanoidRootPart, v369, 1)
              end
            end
          end
        end

        task.wait(0.5)
      end
    end)
  end

  for v370, v371 in workspace:GetDescendants() do
    if v371.Name == "Seeking" or v371.Name == "SeekTrigger" or v371.Name == "ChaseStartTrigger" then
      for v372, v373 in v371:GetDescendants() do
        if v373:IsA("BasePart") then
          v373.CanTouch = not p140
        end
      end
    end
  end
end)

toggles.AutoRoomSkip:OnChanged(function(p141)
  if p141 then
    task.spawn(function()
      pcall(function()
        local val232 = 0
        local val233 = 0
        local val234 = false

        repeat
          local val235 = nil
          local val236 = 0

          for v379, v380 in workspace.CurrentRooms:GetChildren() do
            local numVal12 = tonumber(v380.Name)

            if numVal12 and numVal12 > val236 then
              local door2 = v380:FindFirstChild("Door")

              if door2 then
                val235 = door2
                val236 = numVal12
              end
            end
          end

          if val235 then
            if val236 > val232 then
              val232 = val236
              val233 = 0

              if val234 then
                toggles.Noclip:SetValue(false)
                val234 = false
              end
            end

            local basePart2 = val235:IsA("BasePart") and val235
              or val235:FindFirstChildWhichIsA("BasePart")

            if basePart2 then
              game.Players.LocalPlayer.Character:PivotTo(CFrame.new(basePart2.Position))
            end
          else
            val233 = val233 + 0.25

            if val233 >= 5 then
              if not toggles.Noclip.Value then
                toggles.Noclip:SetValue(true)
              end

              val234 = true
              local character11 = game.Players.LocalPlayer.Character

              if character11 and character11:FindFirstChild("HumanoidRootPart") then
                character11.HumanoidRootPart.CFrame = character11.HumanoidRootPart.CFrame
                  * CFrame.new(0, 0, 10)
              end

              val233 = 0
            end
          end

          task.wait(0.25)
        until not toggles.AutoRoomSkip.Value

        if val234 then
          toggles.Noclip:SetValue(false)
        end
      end)
    end)
  end
end)

toggles.RemoveFigure:OnChanged(function(p142)
  if p142 and Executor.isnetworkowner and workspace:FindFirstChild("Figure") then
    local val237 = helper11()

    for index61, value90 in ipairs(val114.Entities) do
      if value90.Name == "Figure" or value90.Name == "FigureRig"
        or value90.Name == "FigureRagdoll" then
        if val237 == "Mines" then
          for v383, v384 in value90:GetDescendants() do
            local element29 = v384

            if v384:IsA("BasePart")
              and pcall(function() return Executor.isnetworkowner(element29) end) then
              element29.Position = Vector3.new(-49999, -49999, -49999)
            end
          end
        elseif val237 == "OldHotel" or val237 == "Fools" then
          for v386, v387 in value90:GetDescendants() do
            local element30 = v387

            if v387:IsA("BasePart") then
              v387.CanCollide = false

              if pcall(function() return Executor.isnetworkowner(element30) end) then
                element30.Position = Vector3.new(
                  math.random(-29999, 29999), math.random(-29999, 29999), math.random(-29999, 29999)
                )
              end
            end
          end
        end
      end
    end
  end

  if p142 then
    local figure = workspace:FindFirstChild("Figure")

    if figure then
      for v389, v390 in figure:GetDescendants() do
        if v390:IsA("BasePart") then
          v390.CanCollide = false
        end
      end
    end
  end
end)

Connections.AutoReviveHandler = localPlayer2:GetAttributeChangedSignal("Alive"):Connect(function()
  if localPlayer2:GetAttribute("Alive") == false and toggles.AutoRevive.Value then
    local val238 = helper11()

    if val238 == "Fools" or val238 == "OldHotel" then
      while localPlayer2:GetAttribute("Alive") ~= true do
        local remotesFolder3 = replicatedStorage:FindFirstChild("RemotesFolder")

        if remotesFolder3 and remotesFolder3:FindFirstChild("Revive") then
          remotesFolder3.Revive:FireServer()
        end

        task.wait(0.5)
      end
    end
  end
end)

toggles.FigureGodmode:OnChanged(function(p143) end)

ObstructionNames = {
  ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor", }

for key12, value91 in pairs(ObstructionNames) do
  local val239 = key12

  toggles[value91]:OnChanged(function(p144)
    for v393, v394 in workspace:GetDescendants() do
      if v394.Name == val239 and v394:IsA("Model") then
        if p144 then
          v394:PivotTo(CFrame.new(-10000, -10000, -10000))
        else
          local originalPosition = v394:GetAttribute("OriginalPosition")

          if originalPosition then
            if typeof(originalPosition) == "string" then
              local val240, success17 = pcall(function()
                return httpService:JSONDecode(originalPosition)
              end)

              if val240 and typeof(success17) == "table" then
                v394:PivotTo(CFrame.new(unpack(success17)))
              end
            elseif typeof(originalPosition) == "table" and #originalPosition >= 12 then
              v394:PivotTo(CFrame.new(unpack(originalPosition)))
            end
          end
        end
      end
    end
  end)
end

Connections.DescendantAddedObstructions = workspace.DescendantAdded:Connect(function(descendant6)
  if descendant6:IsA("Model")
    and (descendant6.Name == "ThingToOpen" or descendant6.Name == "MovingDoor"
      or descendant6.Name == "Wax_Door") then
    local val241 = {
      ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor", }

    local val242, success18 = pcall(function()
      return httpService:JSONEncode({ descendant6:GetPivot():GetComponents() })
    end)

    if val242 and success18 then
      descendant6:SetAttribute("OriginalPosition", success18)
    end

    if toggles[val241[descendant6.Name]] and toggles[val241[descendant6.Name]].Value then
      descendant6:PivotTo(CFrame.new(-10000, -10000, -10000))
    end
  end
end)

toggles.RoomsAutoWalkShowPathToggle:OnChanged(function(p145)
  for v400, v401 in val85.RoomsNodesFolder:GetChildren() do
    if v401.Name == "PathNode" then
      v401.Transparency = p145 and 0.5 or 1
    end
  end
end)

options.RoomsAutoWalkShowPathColor:OnChanged(function(color)
  for v402, v403 in val85.RoomsNodesFolder:GetChildren() do
    if v403.Name == "PathNode" then
      v403.Color = color
    end
  end
end)

RoomsEntityList = {
  "RushMoving", "AmbushMoving", "BackdoorRush", "A60", "A120", "CustomEntity", "GlitchRush", "GlitchAmbush", }

Functions.RoomsAutoWalk = {}

function Functions.RoomsAutoWalk.GetNearestHidingSpot()
  local element31 = { Distance = math.huge, Object = nil }

  for index62, value92 in ipairs(val114.HidingSpots) do
    if value92.PrimaryPart and value92:FindFirstChild("HidePrompt") then
      local distanceFromCharacter8 = localPlayer2:DistanceFromCharacter(value92.PrimaryPart.Position)

      if distanceFromCharacter8 < element31.Distance and value92.PrimaryPart.Position.Y > -10 then
        local findFirstChild11 = value92:FindFirstChild("HiddenPlayer", true)

        if findFirstChild11 and not findFirstChild11.Value then
          element31.Distance = distanceFromCharacter8
          element31.Object = value92
        end
      end
    end
  end

  return element31.Object
end

local val243 = 0
local value93 = nil

function Functions.RoomsAutoWalk.GetPathfindTarget()
  if not element2 or not currentRooms then
    return
  end

  local strVal4 = currentRooms[tostring(element2.Value)]

  if not strVal4 then
    return
  end

  for v407, v408 in workspace:GetChildren() do
    if TableFind(RoomsEntityList, v408.Name) and v408.PrimaryPart then
      local y = v408.PrimaryPart.Position.Y

      if y > -10 and y < 150 then
        if v408.Name == "A60" and not toggles.RoomsAutoWalkIgnoreA60.Value or v408.Name ~= "A60" then
          return Functions.RoomsAutoWalk.GetNearestHidingSpot()
            or strVal4:FindFirstChild("RoomExit")
        end
      end
    end
  end

  if toggles.RoomsAutoWalkIgnoreA60.Value and Functions.GetNearestEntity() then
    return strVal4:FindFirstChild("RoomExit")
  end

  if (toggles.RoomsPickupStardust.Value or toggles.RoomsPickupGold.Value)
    and value93 ~= element2.Value then
    local element32 = { Distance = math.huge, Object = nil }

    for v410, v411 in strVal4:GetDescendants() do
      if v411.Name == "GoldPile" and v411:GetAttribute("GoldValue")
        and toggles.RoomsPickupGold.Value then
        local distanceFromCharacter9 = localPlayer2:DistanceFromCharacter(v411:GetPivot().Position)

        if distanceFromCharacter9 < element32.Distance then
          element32.Distance = distanceFromCharacter9
          element32.Object = v411
        end
      elseif v411.Name == "StardustPickup" and toggles.RoomsPickupStardust.Value then
        local distanceFromCharacter10 = localPlayer2:DistanceFromCharacter(v411:GetPivot().Position)

        if distanceFromCharacter10 < element32.Distance then
          element32.Distance = distanceFromCharacter10
          element32.Object = v411
        end
      end
    end

    if element32.Object then
      return element32.Object
    end
  end

  return strVal4:FindFirstChild("RoomExit")
end

toggles.RoomsAutoWalk:OnChanged(function(p146)
  for v412, v413 in val85.RoomsNodesFolder:GetChildren() do
    if v413.Name == "PathNode" then
      v413:Destroy()
    end
  end

  if p146 and not toggles.NoA90Damage.Value then
    toggles.NoA90Damage:SetValue(true)
  end
end)

Connections.RoomsAutoWalkHandler = runService.Heartbeat:Connect(function()
  if _Unloading then
    return
  end

  if not toggles.RoomsAutoWalk.Value or CurrentFloor ~= "Rooms" or val85.RoomsAutoWalkActive
    or not collisionPart then
    return
  end

  local val244, success19 = pcall(function() return element2 and element2.Value end)

  if not val244 or not success19 or success19 >= 1000 then
    return
  end

  val85.RoomsAutoWalkActive = true

  local path = pathfindingService:CreatePath({
    AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4, AgentRadius = 1.5, AgentHeight = 1.5, Costs = { StuckPart = 8 }, })

  if toggles.RoomsAutoWalkIgnoreA60.Value and not toggles.Godmode.Value then
    toggles.Godmode:SetValue(true)
  end

  local element33 = Functions.RoomsAutoWalk.GetPathfindTarget()

  if not element33 then
    val85.RoomsAutoWalkActive = false
    return
  end

  local position3

  if element33.Name == "RoomExit" then
    position3 = element33.Position
  elseif element33:FindFirstChild("HidePrompt") then
    for v417, v418 in element33:GetDescendants() do
      if v418:IsA("BasePart") then
        v418.CanCollide = false
      end
    end

    position3 = element33.PrimaryPart.Position
  elseif element33.Name == "GoldPile" or element33.Name == "StardustPickup" then
    position3 = element33:GetPivot().Position

    if val243 == 0 then
      val243 = tick()
    end
  end

  if element33.Name ~= "GoldPile" and element33.Name ~= "StardustPickup" then
    val243 = 0
  end

  if collisionPart.Anchored and not element33:FindFirstChild("HidePrompt") then
    character:SetAttribute("Hiding", true)
    remotesFolder2.CamLock:FireServer()
    character:SetAttribute("Hiding", false)
  end

  if not element2 or not currentRooms then
    val85.RoomsAutoWalkActive = false
    return
  end

  local strVal5 = currentRooms[tostring(element2.Value)]

  if not strVal5 then
    val85.RoomsAutoWalkActive = false
    return
  end

  if strVal5:FindFirstChild("Door") then
    strVal5.Door.Door.CanCollide = false
  end

  if not position3 or localPlayer2:DistanceFromCharacter(position3) >= 750 then
    val85.RoomsAutoWalkActive = false
    return
  end

  local v420, success20 = pcall(path.ComputeAsync, path, collisionPart.Position, position3)

  if success20 then
    val85.RoomsAutoWalkActive = false
    return
  end

  local getWaypoints = path:GetWaypoints()

  if #getWaypoints == 0 then
    local roomExit = strVal5:FindFirstChild("RoomExit")

    if roomExit then
      humanoid:MoveTo(roomExit.Position)
    end

    val85.RoomsAutoWalkActive = false
    return
  end

  for v422, v423 in val85.RoomsNodesFolder:GetChildren() do
    if v423.Name == "PathNode" then
      v423:Destroy()
    end
  end

  for index63, value94 in ipairs(getWaypoints) do
    local pathNode = Instance.new("Part", val85.RoomsNodesFolder)
    pathNode.Transparency = toggles.RoomsAutoWalkShowPathToggle.Value and 0.5 or 1
    pathNode.Size = Vector3.one
    pathNode.Position = value94.Position
    pathNode.Shape = Enum.PartType.Ball
    pathNode.CanCollide = false
    pathNode.Anchored = true
    pathNode.Name = "PathNode"
    pathNode.Color = options.RoomsAutoWalkShowPathColor.Value
    pathNode.Material = Enum.Material.Neon
  end

  local val245 = false

  for index64, value95 in ipairs(getWaypoints) do
    if val245 or not toggles.RoomsAutoWalk.Value then
      break
    end

    local val246 = false
    local val247 = tick()
    local val248 = value95

    local connect22 = runService.RenderStepped:Connect(function()
      if _Unloading then
        return
      end

      if val245 or not toggles.RoomsAutoWalk.Value then
        val246 = true
        return
      end

      local object11 = Functions.RoomsAutoWalk.GetPathfindTarget()

      if object11 and object11:FindFirstChild("HidePrompt") and not element33:FindFirstChild("HidePrompt") then
        val246 = true
        return
      end

      if element33.Name == "GoldPile" and (not element33.Parent or not element33:GetAttribute("GoldValue"))
        or element33.Name == "StardustPickup" and not element33.Parent then
        val246 = true
        return
      end

      if element33:FindFirstChild("HidePrompt") then
        local hidePrompt = element33:FindFirstChild("HidePrompt")

        if localPlayer2:DistanceFromCharacter(position3) < hidePrompt.MaxActivationDistance
          and character:GetAttribute("Hiding") ~= true then
          Functions.ForceFirePrompt(hidePrompt)
        end
      elseif element33.Name == "GoldPile" or element33.Name == "StardustPickup" then
        local lootPrompt = element33:FindFirstChild("LootPrompt")

        if lootPrompt
          and localPlayer2:DistanceFromCharacter(position3) < lootPrompt.MaxActivationDistance then
          Functions.ForceFirePrompt(lootPrompt)
        end
      end

      if localPlayer2:DistanceFromCharacter((Vector3.new(
        val248.Position.X, humanoidRootPart.Position.Y, val248.Position.Z
      ))) < 5 then
        val246 = true
      end

      humanoid:MoveTo(val248.Position)
    end)

    while not val246 do
      if tick() - val247 > options.RoomsAutoWalkPathfindTimeout.Value then
        local stuckPart = Instance.new("Part", val85.RoomsNodesFolder)
        stuckPart.Transparency = 1
        stuckPart.Size = Vector3.one
        stuckPart.CFrame = collision.CFrame
        stuckPart.Shape = Enum.PartType.Ball
        stuckPart.CanCollide = false
        stuckPart.Anchored = true
        stuckPart.Name = "StuckPart"

        local instance6 = Instance.new("PathfindingModifier", stuckPart)
        instance6.Label = "StuckPart"

        val245 = true
        break
      end

      if val243 > 0 and tick() - val243 > 5 then
        value93 = element2.Value
        val243 = 0
        val245 = true
        break
      end

      task.wait()
    end

    connect22:Disconnect()
    humanoid:MoveTo(humanoidRootPart.Position)
  end

  val85.RoomsAutoWalkActive = false
end)

if currentRooms then
  Connections.RoomsHandler = currentRooms.ChildAdded:Connect(function(child8)
    for v429, v430 in val85.RoomsNodesFolder:GetChildren() do
      if v430.Name == "StuckPart" then
        v430:Destroy()
      end
    end

    if child8:GetAttribute("RawName")
      and string.find(child8:GetAttribute("RawName"), "Eyestalk") then
      local val249

      local function createPart(position4)
        local seekLightNode2 = Instance.new("Part")
        seekLightNode2.Size = Vector3.one
        seekLightNode2.Transparency = 1
        seekLightNode2.Parent = val85.SeekNodesFolder
        seekLightNode2.Anchored = true
        seekLightNode2.Position = position4
        seekLightNode2.CanCollide = false
        seekLightNode2.Name = "SeekLightNode"

        local val250 = val249 or seekLightNode2
        val249 = seekLightNode2
        local beam2 = Instance.new("Beam")

        local value96 = rawget(toggles, "ShowEyestalkPathColor")
            and options.ShowEyestalkPathColor.Value
          or Color3.fromRGB(0, 255, 0)

        beam2.Color = ColorSequence.new({
          ColorSequenceKeypoint.new(0, value96), ColorSequenceKeypoint.new(1, value96), })

        beam2.FaceCamera = true
        beam2.Width0 = 0.2
        beam2.Width1 = 0.2
        beam2.Brightness = 10
        beam2.LightInfluence = 0
        beam2.LightEmission = 0
        beam2.Enabled = true

        local value97 = rawget(toggles, "ShowEyestalkPathToggle")
            and toggles.ShowEyestalkPathToggle.Value and 0
          or 1

        beam2.Transparency = NumberSequence.new({
          NumberSequenceKeypoint.new(0, value97), NumberSequenceKeypoint.new(1, value97), })

        beam2.Parent = val85.SeekNodesFolder

        local instance7 = Instance.new("Attachment", seekLightNode2)
        local instance8 = Instance.new("Attachment", val250)

        beam2.Attachment0 = instance7
        beam2.Attachment1 = instance8

        table.insert(val114.EyestalkHighlights, beam2)
      end

      child8:WaitForChild("RoomEntrance", 9000000000)
      child8:WaitForChild("RoomExit", 9000000000)

      while not child8:GetAttribute("PathFound") do
        if rawget(toggles, "ShowEyestalkPathToggle") and toggles.ShowEyestalkPathToggle.Value then
          local path2 = pathfindingService:CreatePath({
            AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 2, AgentRadius = 1, AgentHeight = 1, })

          local v433, success21 = pcall(
            path2.ComputeAsync, path2, humanoidRootPart.Position, child8.RoomExit.Position
          )

          if success21 then
            break
          end

          if path2.Status == Enum.PathStatus.Success then
            child8:SetAttribute("PathFound", true)

            for v435, v436 in path2:GetWaypoints() do
              createPart(v436.Position)
              task.wait()
            end

            break
          end
        end

        task.wait(0.25)
      end
    end
  end)
end

local function helper69()
  local gameData3 = replicatedStorage:FindFirstChild("GameData")

  if gameData3 then
    local floor4 = gameData3:FindFirstChild("Floor")

    if floor4 then
      _FloorConnection = floor4:GetPropertyChangedSignal("Value"):Connect(helper64)
      helper64()
      return
    end

    local connect23 = gameData3.ChildAdded:Connect(function(child9)
      if child9.Name == "Floor" then
        if connect23 then
          connect23:Disconnect()
        end

        helper69()
      end
    end)

    helper64()
    return
  end

  local connect24 = replicatedStorage.ChildAdded:Connect(function(child10)
    if child10.Name == "GameData" then
      if connect24 then
        connect24:Disconnect()
      end

      helper69()
    end
  end)

  helper64()
end

helper69()

Groupboxes.MinesLadder = element3.Mines:AddLeftGroupbox("Ladders")
Groupboxes.MinesLadder:AddToggle("LaddersESP", { Text = "Ladders", Default = false })

toggles.LaddersESP:AddColorPicker("LaddersESPColor", {
  Text = "Ladders", Default = Color3.fromRGB(255, 255, 0), })

Groupboxes.MinesLadder:AddToggle("LaddersTracers", { Text = "Ladders Tracers", Default = false })

toggles.LaddersTracers:OnChanged(function(p147)
  if p147 and not toggles.LaddersESP.Value then
    toggles.LaddersTracers:SetValue(false)
    return
  end

  for index65, value98 in ipairs(ESPCategories.Ladders) do
    local val251 = GetESPTarget(value98, "Ladders")

    if val251 then
      loader:SetTracersEnabled(val251, p147)
    end
  end
end)

toggles.LaddersESP:OnChanged(function(p148)
  if p148 then
    for index66, value99 in ipairs(ESPCategories.Ladders) do
      helper55(value99, "Ladders", "Ladder")
    end
  else
    iterate4("Ladders")
  end
end)

options.LaddersESPColor:OnChanged(function(p149)
  for index67, value100 in ipairs(ESPCategories.Ladders) do
    loader:UpdateObjectColor(GetESPTarget(value100, "Ladders"), p149)
  end
end)

Groupboxes.MinesAnticheat = element3.Mines:AddLeftGroupbox("Anticheat")

Groupboxes.MinesAnticheat:AddToggle("DisableAnticheat", {
  Text = "Anticheat Bypass", Default = false, Tooltip = "Completely disables the anticheat, after interacting with a ladder.", })

toggles.DisableAnticheat:OnChanged(function(p150)
  if val85.AnticheatDisabled == true and not p150 then
    remotesFolder2.ClimbLadder:FireServer()
    val85.AnticheatDisabled = false
  end
end)

Groupboxes.MinesAnticheat:AddDivider()

Groupboxes.MinesAnticheat:AddToggle("RemoveFigureMines", {
  Text = "Delete Figure", Default = false, Tooltip = "Removes Figure, however this is inconsistent", DisabledTooltip = "Your executor doesn't support this feature :(", })

toggles.RemoveFigureMines:OnChanged(function(p151)
  if p151 and Executor.isnetworkowner and workspace:FindFirstChild("Figure") then
    local val252 = helper11()

    for index68, value101 in ipairs(val114.Entities) do
      if value101.Name == "Figure" or value101.Name == "FigureRig"
        or value101.Name == "FigureRagdoll" then
        if val252 == "Mines" then
          for v439, v440 in value101:GetDescendants() do
            local element34 = v440

            if v440:IsA("BasePart")
              and pcall(function() return Executor.isnetworkowner(element34) end) then
              element34.Position = Vector3.new(-49999, -49999, -49999)
            end
          end
        elseif val252 == "OldHotel" or val252 == "Fools" then
          for v442, v443 in value101:GetDescendants() do
            local element35 = v443

            if v443:IsA("BasePart") then
              v443.CanCollide = false

              if pcall(function() return Executor.isnetworkowner(element35) end) then
                element35.Position = Vector3.new(
                  math.random(-29999, 29999), math.random(-29999, 29999), math.random(-29999, 29999)
                )
              end
            end
          end
        end
      end
    end
  end

  if p151 then
    local figure2 = workspace:FindFirstChild("Figure")

    if figure2 then
      for v445, v446 in figure2:GetDescendants() do
        if v446:IsA("BasePart") then
          v446.CanCollide = false
        end
      end
    end
  end
end)

function iterate7(val253, p153, val254)
  local val255 = val254 and 0 or 1

  local numberSequence = NumberSequence.new({
    NumberSequenceKeypoint.new(0, val255), NumberSequenceKeypoint.new(1, val255), })

  for index69, value102 in ipairs(val253) do
    value102.Transparency = numberSequence
  end
end

function iterate8(val256, val257)
  local colorSequence = ColorSequence.new({
    ColorSequenceKeypoint.new(0, val257), ColorSequenceKeypoint.new(1, val257), })

  for index70, value103 in ipairs(val256) do
    value103.Color = colorSequence
  end
end

Groupboxes.MinesAutomation = element3.Mines:AddRightGroupbox("Automation")

Groupboxes.MinesAutomation:AddToggle("AutoSteerMinecart", {
  Text = "Auto Minecart", Default = false, Tooltip = "Automatically completes the minecart section of the seek chase", })

Groupboxes.MinesAutomation:AddSlider("AutoSteerMinecartTurnDistance", {
  Text = "Turn Distance", Min = 20, Max = 40, Default = 30, Rounding = 0, })

Groupboxes.MinesAutomation:AddSlider("AutoSteerMinecartDuckDistance", {
  Text = "Crouch Distance", Min = 20, Max = 40, Default = 30, Rounding = 0, })

Groupboxes.MinesAutomation:AddToggle("AutoSolveAnchors", {
  Text = "Auto Solve Anchors", Default = false, Tooltip = "Automatically enters the correct code into anchors when you are near them.", })

Groupboxes.MinesAutomation:AddToggle("MinecartTeleport", {
  Text = "Minecart Teleport", Default = false, Tooltip = "Teleports your minecart to complete the seek chase", })

toggles.MinecartTeleport:OnChanged(function(p157)
  if not MainHook then
    return
  end

  if p157 then
    local findFirstChild12 = game:FindFirstChild("MinecartPos", true)

    if not findFirstChild12 then
      library:Notify({
        Title = "Minecart Teleport", Description = "Minecart chase is not active yet.", Time = 3, })

      return
    end

    local val258 = restorefunction or restore_function

    local element36 = {
      DecodeHook = nil, Decode = nil, MinecartPos = findFirstChild12, LatestRoom = tonumber(tostring(element2.Value)) or 0, LatestRoomConn = nil, GetDoor = nil, RestoreDecode = val258, }

    pcall(function() element36.Decode = require(replicatedStorage.NodeObject.MinecartNodes).Decode end)

    function element36.GetDoor()
      local findFirstChild13 = currentRooms
        and currentRooms:FindFirstChild(tostring(element36.LatestRoom))

      return findFirstChild13 and findFirstChild13:FindFirstChild("Door")
    end

    element36.LatestRoomConn = element2:GetPropertyChangedSignal("Value"):Connect(function()
      task.wait()
      element36.LatestRoom = tonumber(tostring(element2.Value)) or 0
    end)

    val85.MinecartTeleportState = element36
  else
    local minecartTeleportState2 = val85.MinecartTeleportState

    if minecartTeleportState2 then
      if minecartTeleportState2.LatestRoomConn then
        pcall(function() minecartTeleportState2.LatestRoomConn:Disconnect() end)
      end

      if minecartTeleportState2.DecodeHook and minecartTeleportState2.RestoreDecode then
        pcall(function() minecartTeleportState2.RestoreDecode(minecartTeleportState2.Decode) end)
      end

      val85.MinecartTeleportState = nil
    end
  end
end)

Groupboxes.MinesAutomation:AddButton({
  Text = "Complete Door 200", Tooltip = "Automatically teleports to and interacts with each water pump to complete the Dam Seek", Callback = function()
    if not character then
      library:Notify({ Title = "Error", Description = "Character not found", Time = 3 })
      return
    end

    library:Notify({
      Title = "Door 200", Description = "Starting water pump automation...", Time = 3, })

    local val259 = false

    local connect25 = remotesFolder2 and remotesFolder2:FindFirstChild("Cutscene") and remotesFolder2.Cutscene.OnClientEvent:Connect(function()
      val259 = true
      task.wait(7)
      val259 = false
    end)

    local function helper70()
      local element37 = { Height = -69420, Object = nil }
      local currentRooms8 = workspace:FindFirstChild("CurrentRooms")

      if not currentRooms8 then
        return nil
      end

      for v452, v453 in currentRooms8:GetChildren() do
        local waterPump = v453:FindFirstChild("WaterPump")

        if waterPump and waterPump:GetAttribute("CH_Completed") ~= true then
          local basePart3 = waterPump:FindFirstChildWhichIsA("BasePart")

          if basePart3 and basePart3.Position.Y > element37.Height then
            element37.Object = waterPump
            element37.Height = basePart3.Position.Y
          end
        end
      end

      return element37.Object
    end

    local function waitLoop3(val260)
      local count5 = 0

      while task.wait(0.1) do
        count5 = count5 + 1

        if count5 > 600 then
          break
        end

        if not val259 then
          if character then
            character:PivotTo(val260:GetPivot())
          end

          local findFirstChild14 = val260:FindFirstChild("ValvePrompt", true)

          if findFirstChild14 then
            Functions.ForceFirePrompt(findFirstChild14)
          end

          if val260:GetAttribute("CH_Completed") then
            break
          end
        end
      end
    end

    while task.wait(0.1) do
      local val261 = helper70()

      if val261 then
        waitLoop3(val261)
      else
        break
      end
    end

    if connect25 then
      connect25:Disconnect()
    end

    library:Notify({
      Title = "Door 200", Description = "Finished water pump automation", Time = 4, })
  end, })

toggles.AutoSolveAnchors:OnChanged(function()
  if AutoSolveAnchorsConnection then
    AutoSolveAnchorsConnection:Disconnect()
    AutoSolveAnchorsConnection = nil
  end

  if not toggles.AutoSolveAnchors.Value then
    return
  end

  local val262 = 0

  AutoSolveAnchorsConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not toggles.AutoSolveAnchors.Value or CurrentFloor ~= "Mines" then
      return
    end

    local val263 = os.clock()

    if val263 - val262 < 0.1 then
      return
    end

    val262 = val263
    local playerGui6 = localPlayer2:FindFirstChildOfClass("PlayerGui")

    if not playerGui6 then
      return
    end

    local findFirstChild15 = playerGui6:FindFirstChild("AnchorHintFrame", true)

    if not findFirstChild15 then
      return
    end

    local anchorCode = findFirstChild15:FindFirstChild("AnchorCode")
    local code2 = findFirstChild15:FindFirstChild("Code")

    if not anchorCode or not code2 then
      return
    end

    local strVal6 = tostring(anchorCode.Text or "")

    if strVal6 == "" then
      return
    end

    local currentRooms9 = workspace:FindFirstChild("CurrentRooms")

    if not currentRooms9 then
      return
    end

    for v458, v459 in currentRooms9:GetDescendants() do
      if v459.Name ~= "MinesAnchor" or not v459:IsA("Model") then
        continue
      end

      if v459:GetAttribute("Activated") then
        continue
      end

      local sign2 = v459:FindFirstChild("Sign")

      if not sign2 then
        continue
      end

      local textLabel4 = sign2:FindFirstChildOfClass("TextLabel")

      if not textLabel4 or textLabel4.Text ~= strVal6 then
        continue
      end

      local primaryPart2 = v459.PrimaryPart

      if not primaryPart2 then
        continue
      end

      local maxActivationDistance2 = v459:FindFirstChild("ActivateEventPrompt")
          and v459.ActivateEventPrompt.MaxActivationDistance
        or 20

      if humanoidRootPart
        and humanoidRootPart.Position
        and (humanoidRootPart.Position - primaryPart2.Position).Magnitude
          <= maxActivationDistance2 then
        local anchorRemote = v459:FindFirstChild("AnchorRemote")

        if anchorRemote then
          anchorRemote:InvokeServer(code2.Text)
        end

        break
      end
    end
  end)
end)

Groupboxes.MinesVisuals = element3.Mines:AddRightGroupbox("Visuals")

Groupboxes.MinesVisuals:AddToggle("ShowSeekPathToggle", {
  Text = "Show Seek Path", Default = false, Tooltip = "Shows you the correct path in the seek chase", })

toggles.ShowSeekPathToggle:AddColorPicker("ShowSeekPathColor", {
  Text = "Seek Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0, })

toggles.ShowSeekPathToggle:OnChanged(function(p159)
  iterate7(val114.SeekHighlights, "ShowSeekPathColor", p159)
end)

options.ShowSeekPathColor:OnChanged(function(p160) iterate8(val114.SeekHighlights, p160) end)

toggles.AutoSteerMinecart:OnChanged(function()
  if AutoMinecartConnection then
    AutoMinecartConnection:Disconnect()
    AutoMinecartConnection = nil
  end

  if val85.OriginalGetMoveVector then
    pcall(function()
      local getControls = require(localPlayer2.PlayerScripts.PlayerModule):GetControls()
      getControls.GetMoveVector = val85.OriginalGetMoveVector
    end)

    val85.OriginalGetMoveVector = nil
  end

  if not toggles.AutoSteerMinecart.Value then
    return
  end

  local playerGui7 = localPlayer2:FindFirstChildOfClass("PlayerGui")
  local mainUI5 = playerGui7 and playerGui7:FindFirstChild("MainUI")
  local initiator4 = mainUI5 and mainUI5:FindFirstChild("Initiator")
  local mainGame4 = initiator4 and initiator4:FindFirstChild("Main_Game")

  if not mainGame4 then
    return
  end

  local val264, success22 = pcall(require, mainGame4)

  if not val264 or not success22 then
    return
  end

  local val265, success23 = pcall(function()
    return require(localPlayer2.PlayerScripts.PlayerModule):GetControls()
  end)

  local element38

  if val265 and success23 then
    element38 = success23
  else
    return
  end

  local getMoveVector = element38.GetMoveVector
  val85.OriginalGetMoveVector = getMoveVector

  function element38.GetMoveVector(...)
    if toggles.AutoSteerMinecart.Value and CurrentFloor == "Mines" then
      local nearestTurnNode = val85.NearestTurnNode

      if nearestTurnNode and Functions.GetMinecart() then
        local turn = nearestTurnNode:GetAttribute("Turn")

        return turn == "Left" and Vector3.new(-1, 0, 0)
          or turn == "Right" and Vector3.new(1, 0, 0) or Vector3.zero
      end
    end

    return getMoveVector(...)
  end

  val85.AutoMinecartDucked = false
  val85.LastDuck = tick()

  AutoMinecartConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not toggles.AutoSteerMinecart.Value or not Functions.GetMinecart()
      or tick() - val85.LastDuck < 0.1 then
      return
    end

    val85.NearestTurnNode = Functions.GetNearestTurnNode()

    if not val85.AutoMinecartDucked and Functions.GetNearestDuckBoard() then
      success22.crouch(true)
      val85.AutoMinecartDucked = true
    elseif not Functions.GetNearestDuckBoard() and val85.AutoMinecartDucked then
      success22.crouch(false)
      val85.AutoMinecartDucked = false
    end

    if success22 then
      success22.fovtarget = options.FieldOfView.Value
    else
      currentCamera.FieldOfView = options.FieldOfView.Value
    end

    val85.LastDuck = tick()
  end)
end)

Groupboxes.Visuals_Camera = element3.Visuals:AddRightGroupbox("Camera")

Groupboxes.Visuals_Camera:AddToggle("Fullbright", {
  Text = "Fullbright", Default = false, Tooltip = "Makes your game very bright, and removes shadows", })

Groupboxes.Visuals_Camera:AddSlider("FullbrightBrightness", {
  Text = "Brightness Level", Default = 3, Min = 1, Max = 10, Rounding = 1, Compact = true, })

local function helper71()
  Lighting.Ambient = Color3.new(1, 1, 1)
  Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
  Lighting.GlobalShadows = false
  Lighting.Brightness = options.FullbrightBrightness.Value
  Lighting.ClockTime = 14
  Lighting.FogColor = Color3.new(1, 1, 1)
  Lighting.FogEnd = 1000000000
  Lighting.ColorShift_Top = Color3.new(1, 1, 1)
  Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
  Lighting.ExposureCompensation = 0

  local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")

  if atmosphere then
    atmosphere.Haze = 0
    atmosphere.Density = 0
    atmosphere.Offset = 0
    atmosphere.Color = Color3.new(1, 1, 1)
    atmosphere.Decay = Color3.new(1, 1, 1)
    atmosphere.Glare = 0
  end
end

local function helper72()
  if not fbDefaults then
    return
  end

  Lighting.Ambient = fbDefaults.Ambient
  Lighting.OutdoorAmbient = fbDefaults.OutdoorAmbient
  Lighting.GlobalShadows = fbDefaults.GlobalShadows
  Lighting.Brightness = fbDefaults.Brightness
  Lighting.ClockTime = fbDefaults.ClockTime
  Lighting.FogColor = fbDefaults.FogColor
  Lighting.FogEnd = fbDefaults.FogEnd
  Lighting.ColorShift_Top = fbDefaults.ColorShift_Top
  Lighting.ColorShift_Bottom = fbDefaults.ColorShift_Bottom
  Lighting.ExposureCompensation = fbDefaults.ExposureCompensation

  if fbAtmos and fbAtmosDefaults then
    fbAtmos.Haze = fbAtmosDefaults.Haze
    fbAtmos.Density = fbAtmosDefaults.Density
    fbAtmos.Offset = fbAtmosDefaults.Offset
    fbAtmos.Color = fbAtmosDefaults.Color
    fbAtmos.Decay = fbAtmosDefaults.Decay
    fbAtmos.Glare = fbAtmosDefaults.Glare
  end
end

toggles.Fullbright:OnChanged(function(p161)
  if _FullbrightConnection then
    _FullbrightConnection:Disconnect()
    _FullbrightConnection = nil
  end

  if _FullbrightRoomConn then
    _FullbrightRoomConn:Disconnect()
    _FullbrightRoomConn = nil
  end

  if p161 then
    fbDefaults = {
      Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, GlobalShadows = Lighting.GlobalShadows, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, ColorShift_Top = Lighting.ColorShift_Top, ColorShift_Bottom = Lighting.ColorShift_Bottom, ExposureCompensation = Lighting.ExposureCompensation, }

    fbAtmos = Lighting:FindFirstChildOfClass("Atmosphere")

    if fbAtmos then
      fbAtmosDefaults = {
        Haze = fbAtmos.Haze, Density = fbAtmos.Density, Offset = fbAtmos.Offset, Color = fbAtmos.Color, Decay = fbAtmos.Decay, Glare = fbAtmos.Glare, }
    end

    helper71()
    local val266 = 0

    _FullbrightConnection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      local val267 = tick()

      if val267 - val266 < 0.3 then
        return
      end

      val266 = val267
      helper71()
    end)

    local currentRooms10 = workspace:FindFirstChild("CurrentRooms")

    if currentRooms10 then
      _FullbrightRoomConn = currentRooms10.ChildAdded:Connect(function() helper71() end)
    end
  else
    helper72()
    fbDefaults = nil
    fbAtmosDefaults = nil
  end
end)

Groupboxes.Visuals_Camera:AddToggle("AmbientToggle", {
  Text = "Ambient", Default = false, Tooltip = "Changes the lighting color to the specified value", })

toggles.AmbientToggle:AddColorPicker("AmbientColor", {
  Text = "Ambient", Default = Color3.fromRGB(255, 255, 255), Transparency = 0, })

toggles.AmbientToggle:OnChanged(function(p162)
  local findFirstChild16 = currentRooms
    and currentRooms:FindFirstChild(tostring(localPlayer2:GetAttribute("CurrentRoom")))

  local ambient = findFirstChild16 and findFirstChild16:GetAttribute("Ambient")

  TweenService:Create(Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
    Ambient = p162 and options.AmbientColor.Value or ambient or Color3.fromRGB(255, 255, 255), }):Play()
end)

options.AmbientColor:OnChanged(function()
  if toggles.AmbientToggle and toggles.AmbientToggle.Value then
    TweenService:Create(Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
      Ambient = options.AmbientColor.Value, }):Play()
  end
end)

Groupboxes.Visuals_Camera:AddDivider()

Groupboxes.Visuals_Camera:AddSlider("FieldOfView", {
  Text = "Field of View", Min = 70, Max = 120, Default = 70, Rounding = 0, Compact = true, })

Groupboxes.Visuals_Camera:AddToggle("ThirdPerson", {
  Text = "Third Person", Default = false, Tooltip = "Puts your camera in a third person view", })

toggles.ThirdPerson:AddKeyPicker("ThirdPersonKeybind", {
  Text = "Third Person", Default = "V", Mode = "Toggle", SyncToggleState = true, })

Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetX", {
  Text = "X Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, })

Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetY", {
  Text = "Y Offset", Min = -10, Max = 10, Default = 0.5, Rounding = 1, Compact = true, })

Groupboxes.Visuals_Camera:AddSlider("ThirdPersonOffsetZ", {
  Text = "Z Offset", Min = -10, Max = 10, Default = 7.5, Rounding = 1, Compact = true, })

Groupboxes.Visuals_Camera:AddToggle("ThirdPersonWallCheck", {
  Text = "Wall Check", Default = false, Tooltip = "Prevents third person camera from going through walls", })

toggles.ThirdPerson:OnChanged(helper18)

Groupboxes.Visuals_Camera:AddDivider()

Groupboxes.Visuals_Camera:AddToggle("ViewmodelOffsetToggle", {
  Text = "Viewmodel Offset", Default = false, Tooltip = "Changes the offset of your viewmodel while holding an item.", })

Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetX", {
  Text = "X Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, })

Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetY", {
  Text = "Y Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, })

Groupboxes.Visuals_Camera:AddSlider("ViewmodelOffsetZ", {
  Text = "Z Offset", Min = -10, Max = 10, Default = 0, Rounding = 1, Compact = true, })

Groupboxes.Visuals_Camera:AddToggle("FreecamToggle", {
  Text = "Freecam", Default = false, Tooltip = "Enables freecam with WASD movement and mouse look", })

toggles.FreecamToggle:AddKeyPicker("FreecamKeybind", {
  Text = "Freecam", Default = "Q", Mode = "Toggle", SyncToggleState = true, })

Groupboxes.Visuals_Camera:AddSlider("FreecamSpeed", {
  Text = "Freecam Speed", Min = 10, Max = 300, Default = 75, Rounding = 0, Compact = true, })

Groupboxes.Visuals_Camera:AddDivider()

Groupboxes.Visuals_Camera:AddToggle("RemoveCameraBobbing", {
  Text = "Remove Camera Bobbing", Default = false, Tooltip = "Removes camera 'bobbing'", })

Groupboxes.Visuals_Camera:AddToggle("RemoveCameraShake", {
  Text = "Remove Camera Shake", Default = false, Tooltip = "Removes camera shake", })

Groupboxes.Visuals_Camera:AddToggle("RemoveCameraFog", {
  Text = "Remove Fog", Default = false, Tooltip = "Removes camera fog", })

Groupboxes.Visuals_Camera:AddToggle("DisableFiredampEffect", {
  Text = "Remove Firedamp Effect", Default = false, Tooltip = "Removes the firedamp fog/effect when inside a room", })

FreecamConnection = nil

local function helper73()
  local freecamPart = workspace:FindFirstChild("FreecamPart")

  if freecamPart then
    freecamPart:Destroy()
  end

  local humanoidRootPart8 = localPlayer2.Character
    and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

  if humanoidRootPart8 then
    humanoidRootPart8.Anchored = false
  end

  if localPlayer2:GetAttribute("fc_om") then
    localPlayer2.CameraMinZoomDistance = localPlayer2:GetAttribute("fc_om")
  end

  if localPlayer2:GetAttribute("fc_ox") then
    localPlayer2.CameraMaxZoomDistance = localPlayer2:GetAttribute("fc_ox")
  end
end

toggles.FreecamToggle:OnChanged(function(p163)
  if FreecamConnection then
    FreecamConnection:Disconnect()
  end

  if not p163 then
    helper73()
  else
    FreecamConnection = runService.RenderStepped:Connect(function(delta)
      if _Unloading then
        return
      end

      if not toggles.FreecamToggle.Value then
        return
      end

      local character12 = localPlayer2.Character
      local humanoid12 = character12 and character12:FindFirstChildOfClass("Humanoid")
      local humanoidRootPart9 = character12 and character12:FindFirstChild("HumanoidRootPart")

      if humanoidRootPart9 and not humanoidRootPart9.Anchored then
        humanoidRootPart9.Anchored = true
      end

      if not workspace:FindFirstChild("FreecamPart") then
        local freecamPart2 = Instance.new("Part")
        freecamPart2.Name = "FreecamPart"
        freecamPart2.Size = Vector3.new(0.01, 0.01, 0.01)
        freecamPart2.Transparency = 1
        freecamPart2.CanCollide = false
        freecamPart2.Anchored = true
        freecamPart2.CFrame = currentCamera.CFrame
        freecamPart2.Parent = workspace

        localPlayer2:SetAttribute("fc_om", localPlayer2.CameraMinZoomDistance)
        localPlayer2:SetAttribute("fc_ox", localPlayer2.CameraMaxZoomDistance)
        localPlayer2.CameraMinZoomDistance = 0
        localPlayer2.CameraMaxZoomDistance = 0

        local val268, val269, v469 = currentCamera.CFrame:ToOrientation()

        localPlayer2:SetAttribute("fc_p", math.deg(val268))
        localPlayer2:SetAttribute("fc_y", math.deg(val269))
      end

      local freecamPart3 = workspace:FindFirstChild("FreecamPart")
      local val270 = currentCamera

      if freecamPart3 and val270 then
        local getMouseDelta = userInputService:GetMouseDelta()
        local keyboardEnabled = userInputService.KeyboardEnabled and 0.3 or 0.6

        local val271 = (localPlayer2:GetAttribute("fc_p") or 0)
          - getMouseDelta.Y * keyboardEnabled

        local val272 = (localPlayer2:GetAttribute("fc_y") or 0)
          - getMouseDelta.X * keyboardEnabled

        val271 = math.max(-80, math.min(80, val271))

        localPlayer2:SetAttribute("fc_p", val271)
        localPlayer2:SetAttribute("fc_y", val272)

        freecamPart3.CFrame = CFrame.new(freecamPart3.Position)
          * CFrame.fromOrientation(math.rad(val271), math.rad(val272), 0)

        val270.CFrame = freecamPart3.CFrame
        val270.Focus = val270.CFrame * CFrame.new(0, 0, -10)

        if humanoid12 and humanoid12.MoveDirection.Magnitude > 0 then
          local value105 = options.FreecamSpeed and options.FreecamSpeed.Value or 75
          local vectorToObjectSpace = val270.CFrame:VectorToObjectSpace(humanoid12.MoveDirection)

          local val273 = val270.CFrame.RightVector * vectorToObjectSpace.X
            + val270.CFrame.LookVector * -vectorToObjectSpace.Z

          freecamPart3.Position = freecamPart3.Position + val273 * value105 * delta
        end
      end
    end)
  end
end)

Groupboxes.Visuals_Camera:AddDivider()

Groupboxes.Visuals_Camera:AddToggle("NotifyOxygen", {
  Text = "Oxygen Notifications", Default = false, Tooltip = "Shows a notification when your oxygen level changes", })

Groupboxes.Visuals_Camera:AddToggle("NotifyHasteTime", {
  Text = "Haste/Time Notifications", Default = false, Tooltip = "Shows a notification of the remaining time before Haste spawns", })

Groupboxes.Visuals_Camera:AddDivider()

Groupboxes.Visuals_Camera:AddToggle("TransparentHidingSpotsToggle", {
  Text = "Transparent Hiding Spots", Default = false, Tooltip = "Makes a hiding spot transparent when you enter it", })

Groupboxes.Visuals_Camera:AddSlider("TransparentHidingSpotsSlider", {
  Text = "Transparency", Min = 0, Max = 1, Default = 0.5, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Camera:AddDivider()

Groupboxes.Visuals_Camera:AddToggle("DisableJumpscares", {
  Text = "Disable Jumpscares", Default = false, Tooltip = "Removes jumpscares from the chosen entities", })

Groupboxes.Visuals_Camera:AddDropdown("JumpscaresList", {
  Text = "Jumpscares To Disable", Values = { "Glitch", "Timothy", "Void", "Rush", "Ambush", "Screech", "Figure", "Seek" }, Multi = true, AllowNull = true, })

Groupboxes.Visuals_Camera:AddDivider()

CutsceneNames = {
  "Figure", "FigureEnd", "FigureHotelEnd", "FigureHotelFire", "SeekIntroFools", "SeekIntroHotel", "SeekIntroMines", "SeekIntroMines2", "SerewSeekDrain", "SewerSeekLower", "GrumbleNestEnd", "EyestalkIntro", }

Groupboxes.Visuals_Camera:AddToggle("RemoveCutscenes", {
  Text = "Remove Cutscenes", Default = false, Tooltip = "Removes cutscenes that aren't needed for progression", })

toggles.RemoveCutscenes:OnChanged(function(p164)
  local playerGui8 = localPlayer2:FindFirstChildOfClass("PlayerGui")
  local mainUI6 = playerGui8 and playerGui8:FindFirstChild("MainUI")
  local initiator5 = mainUI6 and mainUI6:FindFirstChild("Initiator")
  local mainGame5 = initiator5 and initiator5:FindFirstChild("Main_Game")
  local remoteListener2 = mainGame5 and mainGame5:FindFirstChild("RemoteListener")

  if not remoteListener2 then
    return
  end

  local cutscenes = remoteListener2:FindFirstChild("Cutscenes")

  if cutscenes then
    for key13, value106 in pairs(cutscenes:GetChildren()) do
      if TableFind(CutsceneNames, value106.Name) and value106:IsA("ModuleScript")
        or TableFind(CutsceneNames, value106:GetAttribute("OriginalName"))
          and value106:IsA("ModuleScript") then
        value106.Name = p164 and value106.Name .. "_Disabled"
          or value106:GetAttribute("OriginalName") or value106.Name
      end
    end
  end

  local floorReplicated2 = replicatedStorage:FindFirstChild("FloorReplicated")

  if floorReplicated2 then
    for key14, value107 in pairs(floorReplicated2:GetChildren()) do
      if TableFind(CutsceneNames, value107.Name) and value107:IsA("ModuleScript")
        or TableFind(CutsceneNames, value107:GetAttribute("OriginalName"))
          and value107:IsA("ModuleScript") then
        value107.Name = p164 and value107.Name .. "_Disabled"
          or value107:GetAttribute("OriginalName") or value107.Name
      end
    end
  end
end)

Groupboxes.Visuals_Settings:AddToggle("ESPRainbow", { Text = "Rainbow ESP", Default = false })
Groupboxes.Visuals_Settings:AddDivider()

TracerCategories = { "Entities", "Doors", "Keys", "Objectives", "Items", "Gold", "Chests", "HidingSpots" }

for index71, value108 in ipairs(TracerCategories) do
  local val274 = value108
  local val275 = val274 .. "Tracers"
  local val276 = ESPToggleKeys[val274]
  local val277 = val274 == "HidingSpots" and "Hiding Spots" or (val274 == "Gold" and "Coins" or val274)
  Groupboxes.Visuals_Settings:AddToggle(val275, { Text = val277 .. " Tracers", Default = false })

  toggles[val275]:OnChanged(function(p165)
    if p165 and not toggles[val276].Value then
      toggles[val275]:SetValue(false)
      return
    end

    for index72, value109 in ipairs(ESPCategories[val274]) do
      local val278 = GetESPTarget(value109, val274)

      if val278 then
        loader:SetTracersEnabled(val278, p165)
      end
    end
  end)
end

Groupboxes.Visuals_Settings:AddDropdown("ESPTracerOrigin", {
  Text = "Tracer Origin", Values = { "Top", "Middle", "Bottom" }, Default = 3, })

Groupboxes.Visuals_Settings:AddToggle("ESPShowText", { Text = "Show ESP Text", Default = true })

Groupboxes.Visuals_Settings:AddToggle("ESPShowDistance", {
  Text = "Show Distance", Default = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPTextSize", {
  Text = "Text Size", Min = 8, Max = 24, Default = 15, Rounding = 0, Compact = true, })

Groupboxes.Visuals_Settings:AddDropdown("ESPTextFont", {
  Text = "Text Font", Values = {
    "Legacy", "Arial", "ArialBold", "SourceSans", "SourceSansBold", "SourceSansLight", "SourceSansItalic", "Bodoni", "Garamond", "Cartoon", "Code", "Highway", "SciFi", "Arcade", "Fantasy", "Antique", "SourceSansSemibold", "Gotham", "GothamMedium", "GothamBold", "GothamBlack", "AmaticSC", "Bangers", "Creepster", "DenkOne", "Fondamento", "FredokaOne", "GrenzeGotisch", "IndieFlower", "JosefinSans", "Jura", "Kalam", "LuckiestGuy", "Merriweather", "Michroma", "Nunito", "Oswald", "PatrickHand", "PermanentMarker", "Roboto", "RobotoCondensed", "RobotoMono", "Sarpanch", "SpecialElite", "TitilliumWeb", "Ubuntu", }, Default = 11, })

Groupboxes.Visuals_Settings:AddSlider("ESPRenderLimit", {
  Text = "ESP Highlight Limit", Min = 30, Max = 240, Default = 240, Rounding = 0, Compact = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPMaxDistance", {
  Text = "ESP Distance", Min = 50, Max = 500, Default = 250, Rounding = 0, Compact = true, Suffix = " studs", })

Groupboxes.Visuals_Settings:AddDivider()

Groupboxes.Visuals_Settings:AddToggle("UseESPOutlineColour", {
  Text = "Use ESP Outline (colour)", Default = false, Tooltip = "Makes the outline of all ESP the same colour as the ESP itself", })

toggles.UseESPOutlineColour:AddColorPicker("ESPOutline", {
  Text = "ESP Outline", Default = Color3.fromRGB(255, 255, 255), })

Groupboxes.Visuals_Settings:AddSlider("ESPFillTransparency", {
  Text = "Fill Transparency", Min = 0, Max = 1, Default = 0.75, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPOutlineTransparency", {
  Text = "Outline Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPTextTransparency", {
  Text = "Text Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPTextOutlineTransparency", {
  Text = "Text Outline Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPTracerThickness", {
  Text = "Tracer Thickness", Min = 0.5, Max = 2, Default = 0.75, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Notifs = element3.Visuals:AddLeftGroupbox("Entity Notifications")

Groupboxes.Visuals_Notifs:AddToggle("NotifyEntities", {
  Text = "Entity Notifications", Default = false, Tooltip = "Receive notifications/popups when entities spawn", })

Groupboxes.Visuals_Notifs:AddDropdown("EntityList", {
  Text = "Entity List", Values = {
    "Rush", "Ambush", "A-60", "A-120", "Blitz", "Eyes", "Lookman", "Monument", "Sally", "Gloombat Swarm", "Glitch Rush", "Glitch Ambush", "Drones", "Bash", "Electric Puddle", "Scribbles", }, Multi = true, AllowNull = true, Tooltip = "Only notify for selected entities (leave empty to notify all)", })

Groupboxes.Visuals_Notifs:AddDropdown("NotifyStyle", {
  Text = "Notification Style", Values = { "Obsidian", "Achievement" }, Default = 1, })

Groupboxes.Visuals_Notifs:AddDropdown("NotifySound", {
  Text = "Notification Sound", Values = { "Achievement", "Tone", "Alert", "Windows XP", "GTA Cell" }, Default = 5, })

Groupboxes.Visuals_Notifs:AddDivider()

Groupboxes.Visuals_Notifs:AddToggle("EntityChatToggle", {
  Text = "Notify Chat", Default = false, Tooltip = "Sends a message in the chat when an entity spawns", })

Groupboxes.Visuals_Notifs:AddInput("EntityChatMessage", {
  Text = "Message", Default = "spawned!", Numeric = false, Placeholder = "Message", })

Groupboxes.Visuals_ItemNotifs = element3.Visuals:AddLeftGroupbox("Item Notifications")

Groupboxes.Visuals_ItemNotifs:AddToggle("NotifyItems", {
  Text = "Item Notifications", Default = false, Tooltip = "Receive notifications/popups when items spawn (shows distance)", })

Groupboxes.Visuals_ItemNotifs:AddDropdown("ItemList", {
  Text = "Item List", Values = {
    "Alarm Clock", "Aloe Vera", "Bandage", "Bandage Pack", "Battery", "Battery Pack", "Big Bomb", "Big Shield Potion", "Bomb", "Boxing Gloves", "Briefcase", "Bread", "Candle", "Candy", "Cheese", "Compass", "Crucifix", "Donut", "Flashlight", "FihFlakes", "Glitch Fragment", "Glowstick", "Golden Gun", "Gummy Flashlight", "Gween Soda", "Hiding Box", "Holy Hand Grenade", "Iron Key", "Knockbomb", "Lantern", "Laser Pointer", "Lighter", "Lockpicks", "Lotus", "Lotus Petal", "Mini Shield Potion", "Moonlight Candle", "Moonlight Smoothie", "Multitool", "Nanner", "Paper Plane", "Pizza", "Leftovers", "Rift Jar", "Shears", "Skeleton Key", "Smoothie", "Spotlight", "Starlight Barrel", "Starlight Bottle", "Starlight Vial", "Stop Sign", "Straplight", "Tablet", "Tip Jar", "Vitamins", }, Multi = true, AllowNull = true, Tooltip = "Only notify for selected items (leave empty to notify all)", })

Groupboxes.Visuals_ItemNotifs:AddDropdown("ItemNotifyStyle", {
  Text = "Notification Style", Values = { "Obsidian", "Achievement" }, Default = 1, })

Groupboxes.Visuals_ItemNotifs:AddDropdown("ItemNotifySound", {
  Text = "Notification Sound", Values = { "Achievement", "Tone", "Alert", "Windows XP", "GTA Cell" }, Default = 4, })

Groupboxes.Visuals_ItemNotifs:AddDivider()

Groupboxes.Visuals_ItemNotifs:AddToggle("ItemChatToggle", {
  Text = "Notify Chat", Default = false, Tooltip = "Sends a message in the chat when an item spawns", })

Groupboxes.Visuals_ItemNotifs:AddInput("ItemChatMessage", {
  Text = "Message", Default = "spawned!", Numeric = false, Placeholder = "Message", })

toggles.ESPRainbow:OnChanged(function(p166) loader:SetRainbow(p166) end)

options.ESPTracerOrigin:OnChanged(function(p167)
  local val279 = { Top = "Top", Middle = "Center", Bottom = "Bottom" }
  loader:SetTracerOrigin(val279[p167] or "Bottom")
end)

toggles.ESPShowText:OnChanged(function(showESPText) loader.ShowESPText = showESPText end)
toggles.ESPShowDistance:OnChanged(function(p168) loader:SetShowDistance(p168) end)

options.ESPTextSize:OnChanged(function(p169) loader:SetTextSize(p169) end)
options.ESPTextFont:OnChanged(function(p170) loader:SetFont(Enum.Font[p170]) end)
options.ESPRenderLimit:OnChanged(function(p171) loader:SetRenderLimit(p171) end)
options.ESPMaxDistance:OnChanged(function(maxDistance) loader.MaxDistance = maxDistance end)
options.ESPFillTransparency:OnChanged(function(p172) loader:SetFillTransparency(p172) end)
options.ESPOutlineTransparency:OnChanged(function(p173) loader:SetOutlineTransparency(p173) end)
options.ESPTextTransparency:OnChanged(function(p174) loader:SetTextTransparency(p174) end)

options.ESPTextOutlineTransparency:OnChanged(function(p175)
  loader:SetTextOutlineTransparency(p175)
end)

options.ESPFadeTime:OnChanged(function(p176)
  if toggles.ESPFade.Value then
    loader:SetFadeTime(p176)
  end
end)

toggles.ESPFade:OnChanged(function(p177)
  loader:SetFadeTime(p177 and options.ESPFadeTime.Value or 0)
end)

toggles.ESPArrowsToggle:OnChanged(function(p178) loader:SetArrows(p178) end)

options.ESPArrowsRadius:OnChanged(function(p179) loader:SetArrowRadius(p179) end)
options.ESPTracerThickness:OnChanged(function(p180) loader:SetTracerSize(p180) end)

toggles.UseESPOutlineColour:OnChanged(function(p181) loader:SetMatchColors(p181) end)
options.ESPOutline:OnChanged(function(p182) loader:SetOutlineColor(p182) end)

loader:SetMatchColors(toggles.UseESPOutlineColour.Value)
loader:SetOutlineColor(options.ESPOutline.Value)
loader:SetShowDistance(true)
loader:SetFont(Enum.Font.Code)
loader:SetTextSize(15)
loader.ShowESPText = true
loader:SetRenderLimit(240)
loader.MaxDistance = 250
loader:SetFillTransparency(0.75)
loader:SetOutlineTransparency(0)
loader:SetTextTransparency(0)
loader:SetTextOutlineTransparency(0)
loader:SetFadeTime(toggles.ESPFade and toggles.ESPFade.Value and options.ESPFadeTime.Value or 0)
loader:SetArrows(false)
loader:SetArrowRadius(250)
loader:SetTracerSize(0.75)

local floorReplicated3 = replicatedStorage:FindFirstChild("FloorReplicated")

if not floorReplicated3 then
  floorReplicated3 = Instance.new("Folder")
end

local val280

local function helper74()
  if val280 then
    return val280
  end

  local playerGui9 = localPlayer2:FindFirstChildOfClass("PlayerGui")
  local mainUI7 = playerGui9 and playerGui9:FindFirstChild("MainUI")
  local initiator6 = mainUI7 and mainUI7:FindFirstChild("Initiator")
  local mainGame6 = initiator6 and initiator6:FindFirstChild("Main_Game")

  if mainGame6 then
    local val281, success24 = pcall(require, mainGame6)

    if val281 and success24 then
      val280 = success24
      return val280
    end
  end

  return nil
end

toggles.RemoveCameraBobbing:OnChanged(function(p183)
  local element39 = helper74()

  if element39 and element39.spring then
    element39.spring.Speed = p183 and 9000000000 or 8
  end
end)

toggles.RemoveCameraFog:OnChanged(function(p184)
  Lighting.FogEnd = p184 and 10000000 or val85.OldFog or Lighting.FogEnd

  for index73, value110 in ipairs(val85.FogInstances) do
    value110.Density = p184 and 0 or value110:GetAttribute("Density_Old")
  end
end)

toggles.DisableFiredampEffect:OnChanged(function(p185)
  local currentRooms11 = workspace:FindFirstChild("CurrentRooms")

  if currentRooms11 then
    for v484, v485 in currentRooms11:GetChildren() do
      if p185 then
        v485:SetAttribute("Firedamp", false)

        for v486, v487 in currentCamera:GetChildren() do
          if v487.Name == "LiveFiredamp" then
            v487:Destroy()
          end
        end
      else
        v485:SetAttribute("Firedamp", v485:GetAttribute("Firedamp_Old"))
      end
    end
  end

  local currentRoom2 = localPlayer2:GetAttribute("CurrentRoom")
  localPlayer2:SetAttribute("CurrentRoom", 0)
  task.wait()
  localPlayer2:SetAttribute("CurrentRoom", currentRoom2)
end)

local function iterate9(val282, val283)
  for index74, value111 in ipairs(ESPCategories.HidingSpots) do
    local val284 = false

    for v489, v490 in value111:GetDescendants() do
      if v490.Name == "HiddenPlayer" and v490.Value == character then
        val284 = true
        break
      end
    end

    for v491, v492 in value111:GetDescendants() do
      if v492:IsA("BasePart") and v492:GetAttribute("Transparency_Old") then
        TweenService:Create(v492, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
          Transparency = val282 and val284 and val283 or v492:GetAttribute("Transparency_Old"), }):Play()
      end
    end
  end
end

toggles.TransparentHidingSpotsToggle:OnChanged(function(p188)
  iterate9(p188, options.TransparentHidingSpotsSlider.Value)
end)

options.TransparentHidingSpotsSlider:OnChanged(function(p189)
  iterate9(toggles.TransparentHidingSpotsToggle.Value, p189)
end)

local function iterate10(val285)
  local playerGui10 = localPlayer2:FindFirstChildOfClass("PlayerGui")
  local mainUI8 = playerGui10 and playerGui10:FindFirstChild("MainUI")
  local initiator7 = mainUI8 and mainUI8:FindFirstChild("Initiator")
  local mainGame7 = initiator7 and initiator7:FindFirstChild("Main_Game")
  local remoteListener3 = mainGame7 and mainGame7:FindFirstChild("RemoteListener")
  local value112 = options.JumpscaresList.Value or {}

  pcall(function()
    local jumpscares = remoteListener3
      and (remoteListener3:FindFirstChild("Jumpscares")
        or remoteListener3:FindFirstChild("Jumpscares_Disabled"))

    if jumpscares then
      jumpscares.Name = val285 and "Jumpscares_Disabled" or "Jumpscares"

      for v493, v494 in jumpscares:GetDescendants() do
        if v494:IsA("ModuleScript") then
          local chOriginalName = v494:GetAttribute("CHOriginalName")
            or v494.Name:gsub("_Disabled", "")

          v494:SetAttribute("CHOriginalName", chOriginalName)

          for key15, value113 in pairs(value112) do
            if chOriginalName:lower():find(tostring(key15):lower(), 1, true) then
              v494.Name = val285 and chOriginalName .. "_Disabled" or chOriginalName
              break
            end
          end
        end
      end
    end
  end)
end

toggles.DisableJumpscares:OnChanged(iterate10)

options.JumpscaresList:OnChanged(function()
  if toggles.DisableJumpscares.Value then
    iterate10(true)
  end
end)

do
  local connect26 = runService.RenderStepped:Connect(function()
    if _Unloading then
      if connect26 then
        connect26:Disconnect()
      end

      return
    end

    local element40 = helper74()

    if element40 then
      if toggles.RemoveCameraShake.Value then
        element40.csgo = CFrame.new()
      end

      if toggles.ViewmodelOffsetToggle.Value then
        element40.tooloffset = Vector3.new(
          options.ViewmodelOffsetX.Value, options.ViewmodelOffsetY.Value, options.ViewmodelOffsetZ.Value
        )
      else
        element40.tooloffset = Vector3.zero
      end
    end

    if toggles.AmbientToggle and toggles.AmbientToggle.Value then
      TweenService:Create(Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
        Ambient = options.AmbientColor.Value, }):Play()
    end
  end)
end

EntityNotifyData = {
  RushMoving = { Alias = "Rush", Danger = true }, AmbushMoving = { Alias = "Ambush", Danger = true }, A60 = { Alias = "A-60", Danger = true }, A120 = {
    Alias = "A-120", Danger = true, GodmodeText = "A-120 is coming, godmode does not work, hide!", }, BackdoorRush = { Alias = "Blitz", Danger = true }, Eyes = { Alias = "Eyes", Text = "Eyes has spawned, look away!" }, Lookman = { Alias = "Lookman", Text = "Lookman has spawned, look away!" }, BackdoorLookman = { Alias = "Lookman", Text = "Lookman has spawned, look away!" }, MonumentEntity = { Alias = "Monument", Text = "Monument has spawned, look at it!" }, SallyMoving = { Alias = "Sally", Text = "Sally has spawned, drop an item for her!" }, GloombatSwarm = {
    Alias = "Gloombat Swarm", Text = "Gloombats have spawned, turn off lights!", }, ["RNIUSHCG=="] = { Alias = "Glitch Rush", Danger = true }, AR0xMBUSH = { Alias = "Glitch Ambush", Danger = true }, GlitchRush = { Alias = "Glitch Rush", Danger = true }, GlitchAmbush = { Alias = "Glitch Ambush", Danger = true }, GiggleCeiling = { Alias = "Giggle" }, GrumbleRig = { Alias = "Grumble" }, DronesStampede = { Alias = "Drones", Danger = true, Text = "Drones are stampeding, hide!" }, BashMoving = { Alias = "Bash", Danger = true }, Water = { Alias = "Electric Puddle", Danger = false, Text = "Electric Puddle nearby!" }, TellerRig = { Alias = "Teller", Danger = true, NoNotify = true }, Scribbles = {
    Alias = "Scribbles", Danger = true, Text = "Scribbles is coming, godmode does not work, hide!", }, Noise = { Alias = "Noise", Danger = true, NoNotify = true }, Creak = { Alias = "Creak", Danger = true, NoNotify = true }, }

local function helper75(val286)
  if val286.Text then
    return val286.Text
  end

  if val286.GodmodeText then
    return val286.GodmodeText
  end

  if val286.Danger then
    return val286.Alias .. " is coming, hide!"
  end

  return "Entity detected!"
end

val171.SoundAssets = {
  Achievement = "rbxassetid://10469938989", Tone = nil, Alert = nil, ["Windows XP"] = nil, ["GTA Cell"] = nil, }

pcall(function()
  if isfolder then
    if not isfolder("moro/Notification Sounds") then
      makefolder("moro/Notification Sounds")
    end

    local function fetchData2(val287, val288)
      local val289 = "moro/Notification Sounds" .. "/" .. val287 .. "."
        .. (val288:match("%.([a-zA-Z0-9]+)$") or "mp3")

      if not isfile(val289) then
        writefile(val289, game:HttpGet(val288))
      end

      return getcustomasset(val289)
    end

    val171.SoundAssets.Tone = fetchData2(
      "tone", "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/tone%20notification.mp3"
    )

    val171.SoundAssets.Alert = fetchData2(
      "alert", "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/alert%20notification.mp3"
    )

    val171.SoundAssets["Windows XP"] = fetchData2(
      "xp", "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/windows%20xp%20exclamation.ogg"
    )

    val171.SoundAssets["GTA Cell"] = fetchData2(
      "gta", "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/gta%20notification.ogg"
    )
  end
end)

val171.SoundInstance = Instance.new("Sound")
val171.SoundInstance.Name = "morohubnotifsound"
val171.SoundInstance.Volume = 0.65

pcall(function() val171.SoundInstance.Parent = SoundService end)

function val171.PlaySound(p194)
  p194 = p194 or "NotifySound"

  pcall(function()
    local achievement = val171.SoundAssets[options[p194].Value] or val171.SoundAssets.Achievement

    val171.SoundInstance.SoundId = achievement
    val171.SoundInstance.TimePosition = 0
    val171.SoundInstance:Play()
  end)
end

val171.ActiveAchievement = {}

local function helper76(val290)
  for i14 = val290, #val171.ActiveAchievement do
    local val291 = 72 + (i14 - 1) * 150

    TweenService:Create(
      val171.ActiveAchievement[i14], TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(1, -22, 0, val291) }
    ):Play()
  end
end

function val171.CustomAchievement(p196, p197, p198)
  local morohubentitynotif = Instance.new("ScreenGui")
  morohubentitynotif.Name = "morohubentitynotif"
  morohubentitynotif.ResetOnSpawn = false
  morohubentitynotif.IgnoreGuiInset = true
  morohubentitynotif.Parent = CoreGui

  local val292 = p198 and 110 or 90

  local frame6 = Instance.new("Frame")
  frame6.Size = UDim2.new(0, 350, 0, val292)
  frame6.AnchorPoint = Vector2.new(1, 0)
  frame6.BackgroundTransparency = 1
  frame6.Parent = morohubentitynotif

  local val293 = 72 + (#val171.ActiveAchievement + 1 - 1) * 150
  frame6.Position = UDim2.new(1, 370, 0, val293)
  table.insert(val171.ActiveAchievement, frame6)

  local textLabel5 = Instance.new("TextLabel")
  textLabel5.BackgroundTransparency = 1
  textLabel5.Position = UDim2.new(0, 0, 0, -30)
  textLabel5.Size = UDim2.new(1, 0, 0, 28)
  textLabel5.Font = Enum.Font.GothamBlack
  textLabel5.Text = "Entity detected"
  textLabel5.TextColor3 = Color3.fromRGB(255, 238, 216)
  textLabel5.TextStrokeTransparency = 0.75
  textLabel5.TextSize = 20
  textLabel5.TextXAlignment = Enum.TextXAlignment.Left
  textLabel5.Parent = frame6

  local frame7 = Instance.new("Frame")
  frame7.Name = "Frame"
  frame7.Size = UDim2.new(1, 0, 1, 0)
  frame7.BackgroundColor3 = Color3.fromRGB(35, 22, 18)
  frame7.BorderSizePixel = 0
  frame7.Parent = frame6

  Instance.new("UICorner", frame7).CornerRadius = UDim.new(0, 9)

  local instance9 = Instance.new("UIStroke", frame7)
  instance9.Color = Color3.fromRGB(255, 236, 214)
  instance9.Thickness = 3

  local imageLabel = Instance.new("ImageLabel")
  imageLabel.Name = "ImageLabel"
  imageLabel.BackgroundTransparency = 1
  imageLabel.Image = "rbxassetid://106990021902592"
  imageLabel.Size = UDim2.new(0, 76, 0, 76)
  imageLabel.Position = UDim2.new(0, 10, 0, 10)
  imageLabel.ScaleType = Enum.ScaleType.Fit
  imageLabel.Parent = frame7

  local details = Instance.new("Frame")
  details.Name = "Details"
  details.BackgroundTransparency = 1
  details.Position = UDim2.new(0, 96, 0, 10)
  details.Size = UDim2.new(1, -106, 1, -20)
  details.Parent = frame7

  local function createTextLabel(name8, text5, val294, val295, font)
    local textLabel6 = Instance.new("TextLabel")
    textLabel6.Name = name8
    textLabel6.BackgroundTransparency = 1
    textLabel6.Position = UDim2.new(0, 0, 0, val294)
    textLabel6.Size = UDim2.new(1, 0, 0, val295 + 12)
    textLabel6.Font = font
    textLabel6.Text = text5
    textLabel6.TextScaled = true
    textLabel6.TextSize = val295
    textLabel6.TextWrapped = true
    textLabel6.TextXAlignment = Enum.TextXAlignment.Left
    textLabel6.TextYAlignment = Enum.TextYAlignment.Top
    textLabel6.TextColor3 = Color3.fromRGB(255, 238, 216)
    textLabel6.TextStrokeTransparency = 0.8
    textLabel6.Parent = details
  end

  createTextLabel("Title", p196, 0, 18, Enum.Font.GothamBold)
  createTextLabel("Desc", p197, 34, 14, Enum.Font.Gotham)

  if p198 then
    createTextLabel("Reason", p198, 64, 14, Enum.Font.Gotham)
  end

  task.spawn(function()
    TweenService:Create(
      frame6, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(1, -22, 0, val293) }
    ):Play()

    task.wait(5.5)

    TweenService:Create(
      frame6, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, 370, 0, val293) }
    ):Play()

    task.wait(0.5)

    for index75, value115 in ipairs(val171.ActiveAchievement) do
      if value115 == frame6 then
        table.remove(val171.ActiveAchievement, index75)
        helper76(index75)
        break
      end
    end

    morohubentitynotif:Destroy()
  end)
end

function val171.ShowAchievement(p201, p202, p203, p204)
  if not localPlayer2 then
    val171.CustomAchievement(p201, p202, p203)
    return
  end

  local playerGui11 = localPlayer2:FindFirstChild("PlayerGui")

  local globalUI = playerGui11
    and (playerGui11:FindFirstChild("GlobalUI") or playerGui11:FindFirstChild("MainUI"))

  local achievementsHolder = globalUI and globalUI:FindFirstChild("AchievementsHolder")
  local achievement2 = achievementsHolder and achievementsHolder:FindFirstChild("Achievement")

  if not (globalUI and achievementsHolder and achievement2) then
    val171.CustomAchievement(p201, p202, p203)
    return
  end

  local function createSound(parent6, soundId, val296)
    local sound3 = Instance.new("Sound")
    sound3.SoundId = soundId
    sound3.Volume = val296 or 1
    sound3.Parent = parent6

    task.spawn(function()
      task.wait(0.1)

      sound3:Play()
      sound3.Ended:Wait()
      sound3:Destroy()
    end)
  end

  local liveAchievement = achievement2:Clone()
  liveAchievement.Size = UDim2.new(0, 0, 0, 0)
  liveAchievement.Frame.Position = UDim2.new(1.1, 0, 0, 0)
  liveAchievement.Name = "LiveAchievement"
  liveAchievement.Visible = true
  liveAchievement.Frame.TextLabel.Text = p201 or "NOTIFICATION"
  liveAchievement.Frame.Details.Title.Text = p204 or p201 or ""
  liveAchievement.Frame.Details.Desc.Text = p202 or ""
  liveAchievement.Frame.Details.Reason.Text = p203 or ""
  liveAchievement.Frame.TextLabel.TextWrapped = true
  liveAchievement.Frame.Details.Title.TextWrapped = true
  liveAchievement.Frame.Details.Desc.TextWrapped = true
  liveAchievement.Frame.Details.Reason.TextWrapped = true
  liveAchievement.Frame.ImageLabel.Image = "rbxassetid://106990021902592"

  local color2 = Color3.new(1, 1, 1)

  liveAchievement.Frame.TextLabel.TextColor3 = color2
  liveAchievement.Frame.UIStroke.Color = color2
  liveAchievement.Frame.Glow.ImageColor3 = color2
  liveAchievement.Parent = achievementsHolder

  createSound(achievementsHolder, "rbxassetid://10469938989", 1)

  task.spawn(function()
    liveAchievement:TweenSize(UDim2.new(1, 0, 0.2, 0), "In", "Quad", 0.8, true)
    task.wait(0.8)
    liveAchievement.Frame:TweenPosition(UDim2.new(0, 0, 0, 0), "Out", "Quad", 0.5, true)

    TweenService:Create(
      liveAchievement.Frame.Glow, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1 }
    ):Play()

    task.wait(5)
    liveAchievement.Frame:TweenPosition(UDim2.new(1.1, 0, 0, 0), "In", "Quad", 0.5, true)
    task.wait(0.5)
    liveAchievement:TweenSize(UDim2.new(1, 0, -0.1, 0), "InOut", "Quad", 0.5, true)
    task.wait(0.5)
    liveAchievement:Destroy()
  end)
end

val171.ActiveEntity = 0

function helper57(val297)
  if not val167[val297.Name] then
    return
  end

  local element41 = EntityNotifyData[val297.Name]

  if not element41 then
    return
  end

  if element41.NoNotify then
    return
  end

  if not toggles.NotifyEntities.Value then
    return
  end

  local value116 = options.EntityList.Value

  if value116 and next(value116) ~= nil and not value116[element41.Alias] then
    return
  end

  if val171.ActiveEntity >= 6 then
    return
  end

  val171.ActiveEntity = val171.ActiveEntity + 1
  val171.PlaySound()

  local val298 = helper75(element41)

  local val299 = {
    RushMoving = true, AmbushMoving = true, A60 = true, BackdoorRush = true, ["RNIUSHCG=="] = true, AR0xMBUSH = true, BashMoving = true, }

  if toggles.Godmode.Value and val299[val297.Name] then
    val298 = element41.Alias .. " is coming, but you have godmode enabled so don't worry!"
  end

  if options.NotifyStyle.Value == "Obsidian" then
    library:Notify({ Title = "Entity detected", Description = val298, Time = 5 })
  else
    task.spawn(function()
      val171.ShowAchievement(
        "Entity detected", val298, nil, "Entity '" .. (element41.Alias or "") .. "' has spawned"
      )
    end)
  end

  if toggles.EntityChatToggle.Value then
    Functions.SendChat(element41.Alias .. " " .. options.EntityChatMessage.Value)
  end

  task.delay(6, function() val171.ActiveEntity = math.max(0, val171.ActiveEntity - 1) end)
end

for v504, v505 in workspace:GetDescendants() do
  task.spawn(helper58, v505)
  task.spawn(helper27, v505)
  task.spawn(helper36, v505)
end

val85.OldFog = Lighting.FogEnd

for v506, v507 in Lighting:GetChildren() do
  if v507:IsA("Atmosphere") then
    local element42 = v507
    element42:SetAttribute("Density_Old", element42.Density)

    local connect27 = element42:GetPropertyChangedSignal("Density"):Connect(function()
      if element42.Density ~= 0 then
        element42:SetAttribute("Density_Old", element42.Density)
      end

      if toggles.RemoveCameraFog.Value then
        element42.Density = 0
      end
    end)

    v507.Destroying:Once(function() connect27:Disconnect() end)

    table.insert(Connections, connect27)
    table.insert(val85.FogInstances, v507)
  end
end

workspace.DescendantAdded:Connect(helper58)
workspace.DescendantAdded:Connect(helper27)
workspace.DescendantAdded:Connect(helper36)

for v509, v510 in workspace:GetDescendants() do
  if v510:IsA("ProximityPrompt") and not v510:GetAttribute("FakePrompt") then
    task.spawn(helper27, v510)
  end
end

local val300 = tick()

runService.Heartbeat:Connect(function()
  if _Unloading then
    return
  end

  if tick() - val300 <= 0.5 then
    return
  end

  val300 = tick()

  for index76, value117 in ipairs(_TrackedPrompts) do
    if value117 and value117.Parent then
      if value117:HasTag("DisableWhenEnabledOnClient") then
        value117:RemoveTag("DisableWhenEnabledOnClient")
      end

      if toggles and toggles.InstantInteract and toggles.InstantInteract.Value
        and value117.HoldDuration ~= 0 then
        value117.HoldDuration = 0
      end

      if toggles and toggles.PromptClip and toggles.PromptClip.Value
        and value117.RequiresLineOfSight ~= false then
        value117.RequiresLineOfSight = false
      end

      if toggles and toggles.PromptReach and toggles.PromptReach.Value then
        local maxActivationDistanceOld = value117:GetAttribute("MaxActivationDistance_Old")

        if maxActivationDistanceOld then
          local promptRange = options and options.PromptRange
            and maxActivationDistanceOld * options.PromptRange.Value

          if promptRange and value117.MaxActivationDistance ~= promptRange then
            value117.MaxActivationDistance = promptRange
          end
        end
      end
    end
  end

  if toggles and toggles.NotifyVulnerable and toggles.NotifyVulnerable.Value
    and humanoidRootPart then
    local val301 = humanoidRootPart.Position.Y

    if VulnerableLastY then
      if val301 - VulnerableLastY >= 3 and tick() - VulnerableNotifCooldown >= 3 then
        library:Notify({
          Title = "Vulnerable", Description = "You've moved 3+ studs upward!", Time = 3, })

        VulnerableNotifCooldown = tick()
      end
    end

    VulnerableLastY = val301
  end
end)

AutoHide = { Last = tick(), ThreatConns = {} }
toggles.AutoClosetToggle:OnChanged(function(p207)
  if _AutoHideConnection then
    _AutoHideConnection:Disconnect()
    _AutoHideConnection = nil
  end

  if p207 then
    _AutoHideConnection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if not character or not humanoidRootPart or not humanoid then
        return
      end

      if tick() - AutoHide.Last <= 0.1 then
        return
      end

      if Functions.GetNearestEntity(true, options.AutoClosetEntityList.Value) then
        local functions6 = Functions.GetNearestHidingSpot()

        if character:GetAttribute("Hiding") ~= true and functions6 then
          Functions.ForceFirePrompt(functions6.HidePrompt)
        end
      elseif character:GetAttribute("Hiding") == true then
        remotesFolder2.CamLock:FireServer()
      end

      if toggles.RemoveClosetDelay.Value and humanoid.MoveDirection ~= Vector3.zero
        and (collisionPart.Anchored or humanoidRootPart.Anchored)
        and character:GetAttribute("AnimatingClient") ~= true
        and character:GetAttribute("Hiding") == true then
        remotesFolder2.CamLock:FireServer()
      end

      AutoHide.Last = tick()
    end)
  end
end)

local function helper77()
  if character then
    local val302 = -1
    local val303 = { 80, 60, 40, 20 }

    character:GetAttributeChangedSignal("Oxygen"):Connect(function()
      local oxygen = character:GetAttribute("Oxygen")

      if toggles.NotifyOxygen and toggles.NotifyOxygen.Value then
        local floorVal2 = math.floor(oxygen + 0.5)

        if floorVal2 ~= val302 and TableFind(val303, floorVal2) then
          library:Notify({
            Title = "Oxygen decreasing", Description = "Your oxygen is at " .. tostring(floorVal2) .. "%", Time = 3, })

          val302 = floorVal2
        end
      end
    end)
  end

  if floorReplicated3:FindFirstChild("DigitalTimer") then
    local val304 = -1

    floorReplicated3.DigitalTimer:GetPropertyChangedSignal("Value"):Connect(function()
      if toggles.NotifyHasteTime and toggles.NotifyHasteTime.Value then
        local value118 = floorReplicated3.DigitalTimer.Value

        if TableFind({ 90, 60, 30, 15 }, value118) and value118 ~= val304 then
          val304 = value118

          library:Notify({
            Title = "Haste notification", Description = "Haste is coming in " .. value118 .. " seconds!", Time = 3, })
        end
      end
    end)
  end
end

helper77()

localPlayer2.CharacterAdded:Connect(function()
  task.wait(1)
  helper77()
end)

Connections.FogHandler = Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
  if Lighting.FogEnd ~= 10000000 then
    val85.OldFog = Lighting.FogEnd
  end

  if toggles.RemoveCameraFog.Value then
    Lighting.FogEnd = 10000000
  end
end)

Connections.FogHandler2 = Lighting.DescendantAdded:Connect(function(descendant7)
  if not descendant7:IsA("Atmosphere") then
    return
  end

  descendant7:SetAttribute("Density_Old", descendant7.Density)

  if toggles.RemoveCameraFog.Value then
    descendant7.Density = 0
  end

  local connect28 = descendant7:GetPropertyChangedSignal("Density"):Connect(function()
    if descendant7.Density ~= 0 then
      descendant7:SetAttribute("Density_Old", descendant7.Density)
    end

    if toggles.RemoveCameraFog.Value then
      descendant7.Density = 0
    end
  end)

  descendant7.Destroying:Once(function() connect28:Disconnect() end)

  table.insert(Connections, connect28)
  table.insert(val85.FogInstances, descendant7)
end)

localPlayer2.CharacterAppearanceLoaded:Connect(function()
  task.wait(1)
  local element43 = helper74()

  if toggles.RemoveCameraBobbing.Value and element43 and element43.spring then
    element43.spring.Speed = 9000000000
  end
end)

localPlayer2.CharacterAdded:Connect(function()
  task.wait(1)
  val280 = nil
  local element44 = helper74()

  if toggles.RemoveCameraBobbing.Value and element44 and element44.spring then
    element44.spring.Speed = 9000000000
  end

  if toggles.DisableJumpscares.Value then
    iterate10(true)
  end
end)


if moroWindow and moroWindow.AddSettingsTab then
  moroWindow:AddSettingsTab()
end

-- =====================================================================
--                   AUTONOMOUS KNOB FARM ENGINE
-- =====================================================================

local KnobFarm = {
  Active = false,
  Thread = nil,
  BodyVelocity = nil,
  NoclipConn = nil,
  CurrentTarget = nil,
  Status = "Idle",
  LootedObjects = {},
  LastRoomNumber = nil,
  OriginalGodmode = false,
}

local BlacklistedToolNames = {
  ["Lighter"] = true, ["Flashlight"] = true, ["Lockpick"] = true, ["Vitamins"] = true,
  ["Bandage"] = true, ["StarVial"] = true, ["StarBottle"] = true, ["StarJug"] = true,
  ["Shakelight"] = true, ["Straplight"] = true, ["Bulklight"] = true, ["Battery"] = true,
  ["Candle"] = true, ["Crucifix"] = true, ["CrucifixWall"] = true, ["Glowsticks"] = true,
  ["SkeletonKey"] = true, ["Candy"] = true, ["ShieldMini"] = true, ["ShieldBig"] = true,
  ["BandagePack"] = true, ["BatteryPack"] = true, ["RiftCandle"] = true, ["LaserPointer"] = true,
  ["HolyGrenade"] = true, ["Shears"] = true, ["Smoothie"] = true, ["Cheese"] = true,
  ["Bread"] = true, ["AlarmClock"] = true, ["RiftSmoothie"] = true, ["GweenSoda"] = true,
  ["GlitchCube"] = true, ["Scanner"] = true, ["Bomb"] = true, ["Knockbomb"] = true,
  ["Nanner"] = true, ["BigBomb"] = true, ["SnakeBox"] = true, ["GoldGun"] = true,
  ["StopSign"] = true, ["TipJar"] = true, ["Lantern"] = true, ["LotusPetal"] = true,
  ["Compass"] = true, ["LotusPetalPickup"] = true, ["LanternLitItem"] = true,
  ["Multitool"] = true, ["RiftJar"] = true, ["AloeVera"] = true, ["Donut"] = true,
  ["Lotus"] = true, ["BoxingGloves"] = true, ["Green_Herb"] = true, ["PaperPlane"] = true,
  ["Pizza"] = true, ["FihFlakes"] = true, ["Leftovers"] = true, ["Briefcase"] = true,
}

local function IsBlacklistedItem(modelOrPart)
  if not modelOrPart then return false end
  local name = modelOrPart.Name
  if BlacklistedToolNames[name] then return true end
  if modelOrPart.Parent and BlacklistedToolNames[modelOrPart.Parent.Name] then return true end
  return false
end

function KnobFarm.SetStatus(txt)
  KnobFarm.Status = tostring(txt)
  if Groupboxes.AutoFarm_Status and Groupboxes.AutoFarm_Status.SetText then
    pcall(function() Groupboxes.AutoFarm_Status:SetText("Status: " .. tostring(txt)) end)
  end
end

local function HasLineOfSight(fromPos, toPos, ignoreList)
  local rayParams = RaycastParams.new()
  rayParams.FilterType = Enum.RaycastFilterType.Exclude
  local filter = { character, workspace.CurrentCamera }
  if ignoreList then
    for _, item in ipairs(ignoreList) do table.insert(filter, item) end
  end
  rayParams.FilterDescendantsInstances = filter
  rayParams.IgnoreWater = true

  local dir = toPos - fromPos
  local result = workspace:Raycast(fromPos, dir, rayParams)
  if result and result.Instance then
    if result.Instance.CanCollide and result.Instance.Transparency < 0.9 then
      return false, result.Position
    end
  end
  return true, toPos
end

local function DisableDoorCollision(doorInstance)
  if not doorInstance then return end
  for _, part in ipairs(doorInstance:GetDescendants()) do
    if part:IsA("BasePart") and (part.Name == "Door" or part.Name == "Hidden" or part.Name == "Collision") then
      part.CanCollide = false
    end
  end
end

local function OpenDoorRemotes(doorInstance)
  if not doorInstance then return end
  local clientOpen = doorInstance:FindFirstChild("ClientOpen")
  if clientOpen then
    pcall(function()
      if clientOpen:IsA("RemoteFunction") then
        clientOpen:InvokeServer()
      elseif clientOpen:IsA("RemoteEvent") then
        clientOpen:FireServer()
      end
    end)
  end

  for _, pr in ipairs(doorInstance:GetDescendants()) do
    if pr:IsA("ProximityPrompt") and Functions.FirePrompt then
      Functions.FirePrompt(pr)
    end
  end
end

local function GetClearFlightVelocity(fromPos, targetDir, speed, filter)
  local rayParams = RaycastParams.new()
  rayParams.FilterType = Enum.RaycastFilterType.Exclude
  rayParams.FilterDescendantsInstances = filter
  rayParams.IgnoreWater = true

  local checkDist = 4.5
  local hit = workspace:Raycast(fromPos, targetDir * checkDist, rayParams)
  if not hit or not hit.Instance or not hit.Instance.CanCollide then
    return targetDir * speed
  end

  -- Obstacle / wall detected in front!
  local normal = hit.Normal
  -- Calculate tangent velocity along the wall surface (Wall Sliding)
  local slideDir = targetDir - (targetDir:Dot(normal) * normal)
  if slideDir.Magnitude > 0.15 then
    local slideHit = workspace:Raycast(fromPos, slideDir.Unit * checkDist, rayParams)
    if not slideHit or not slideHit.Instance or not slideHit.Instance.CanCollide then
      return slideDir.Unit * speed
    end
  end

  -- If tangent is blocked, slide perpendicular (left/right along wall)
  local rightWall = normal:Cross(Vector3.yAxis).Unit
  local leftWall = -rightWall

  local firstChoice = (rightWall:Dot(targetDir) >= 0) and rightWall or leftWall
  local secondChoice = (firstChoice == rightWall) and leftWall or rightWall

  local h1 = workspace:Raycast(fromPos, firstChoice * checkDist, rayParams)
  if not h1 or not h1.Instance or not h1.Instance.CanCollide then
    return firstChoice * speed
  end

  local h2 = workspace:Raycast(fromPos, secondChoice * checkDist, rayParams)
  if not h2 or not h2.Instance or not h2.Instance.CanCollide then
    return secondChoice * speed
  end

  -- Last resort: lift up slightly above obstacle
  local upDir = Vector3.new(0, 1, 0)
  local hUp = workspace:Raycast(fromPos, upDir * 4, rayParams)
  if not hUp or not hUp.Instance or not hUp.Instance.CanCollide then
    return (targetDir + Vector3.new(0, 1.2, 0)).Unit * speed
  end

  return targetDir * (speed * 0.3)
end

local function ComputePathWaypoints(startPos, endPos, room)
  local filter = { character, workspace.CurrentCamera }
  local rayParams = RaycastParams.new()
  rayParams.FilterType = Enum.RaycastFilterType.Exclude
  rayParams.FilterDescendantsInstances = filter
  rayParams.IgnoreWater = true

  -- Raycast down to find floor level
  local startFloor = workspace:Raycast(startPos + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), rayParams)
  local navStart = startFloor and (startFloor.Position + Vector3.new(0, 1.2, 0)) or startPos

  -- Determine floor level for destination:
  -- In Doors, destination is often a drawer/table/counter.
  -- Using startFloor Y level or raycasting with target model excluded gives the actual walkable floor!
  local destFloor = workspace:Raycast(endPos + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), rayParams)
  local floorY = (destFloor and destFloor.Position.Y) or (startFloor and startFloor.Position.Y) or (startPos.Y - 2.5)
  local navDest = Vector3.new(endPos.X, floorY + 1.2, endPos.Z)

  -- Offset destination slightly towards start so we land on walkable floor in front of furniture
  local toDest = (navDest - navStart)
  if toDest.Magnitude > 3.5 then
    navDest = navDest - toDest.Unit * 2.0
  end

  -- Attempt 1: Standard agent size with jumping enabled (for door sills, steps, carpets)
  local path = pathfindingService:CreatePath({
    AgentRadius = 1.4,
    AgentHeight = 3.0,
    AgentCanJump = true,
    AgentCanClimb = false,
    WaypointSpacing = 3,
    Costs = { Door = 1, StuckPart = 10 },
  })

  local ok, _ = pcall(path.ComputeAsync, path, navStart, navDest)
  if ok and path.Status == Enum.PathStatus.Success then
    local wps = path:GetWaypoints()
    if #wps > 1 then return wps end
  end

  -- Attempt 2: Narrow agent size (for narrow Doors corridors, tight doorways)
  local pathNarrow = pathfindingService:CreatePath({
    AgentRadius = 0.8,
    AgentHeight = 2.0,
    AgentCanJump = true,
    AgentCanClimb = false,
    WaypointSpacing = 3,
  })

  local ok2, _ = pcall(pathNarrow.ComputeAsync, pathNarrow, navStart, navDest)
  if ok2 and pathNarrow.Status == Enum.PathStatus.Success then
    local wps = pathNarrow:GetWaypoints()
    if #wps > 1 then return wps end
  end

  -- Attempt 3: Route via room center if moving within a room
  if room and room:IsA("Model") then
    local roomCenter = room:GetPivot().Position
    local navCenter = Vector3.new(roomCenter.X, floorY + 1.2, roomCenter.Z)

    local okC1, _ = pcall(pathNarrow.ComputeAsync, pathNarrow, navStart, navCenter)
    if okC1 and pathNarrow.Status == Enum.PathStatus.Success then
      local wpsCenter = pathNarrow:GetWaypoints()
      local okC2, _ = pcall(pathNarrow.ComputeAsync, pathNarrow, navCenter, navDest)
      if okC2 and pathNarrow.Status == Enum.PathStatus.Success then
        local wpsDest = pathNarrow:GetWaypoints()
        local merged = {}
        for _, wp in ipairs(wpsCenter) do table.insert(merged, wp) end
        for i = 2, #wpsDest do table.insert(merged, wpsDest[i]) end
        if #merged > 1 then return merged end
      end
    end
  end

  return nil
end

function KnobFarm.StartFlight()
  local hrp = character and character:FindFirstChild("HumanoidRootPart")
  if not hrp then return end

  if not KnobFarm.BodyVelocity or not KnobFarm.BodyVelocity.Parent then
    local bv = Instance.new("BodyVelocity")
    bv.Name = "FarmBV"
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.P = 1e5
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    KnobFarm.BodyVelocity = bv
  end

  if not KnobFarm.BodyGyro or not KnobFarm.BodyGyro.Parent then
    local bg = Instance.new("BodyGyro")
    bg.Name = "FarmBG"
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.P = 1e5
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp
    KnobFarm.BodyGyro = bg
  end

  if humanoid then
    humanoid.PlatformStand = true
  end
end

function KnobFarm.StopFlight()
  if KnobFarm.BodyVelocity then
    pcall(function() KnobFarm.BodyVelocity:Destroy() end)
    KnobFarm.BodyVelocity = nil
  end
  if KnobFarm.BodyGyro then
    pcall(function() KnobFarm.BodyGyro:Destroy() end)
    KnobFarm.BodyGyro = nil
  end
  if humanoid then
    humanoid.PlatformStand = false
  end
end

function KnobFarm.MoveTo(targetPos, customSpeed, stopDist, maxTime, targetRoom)
  if not toggles.AutoFarmEnabled.Value or _Unloading then return false end
  KnobFarm.StartFlight()

  stopDist = stopDist or 3.5
  local speed = customSpeed or (options.AutoFarmSpeed and options.AutoFarmSpeed.Value or 45)
  maxTime = maxTime or 12
  local startT = tick()

  local hrp = humanoidRootPart
  if not hrp then return false end

  local filter = { character, workspace.CurrentCamera }
  local distToTarget = (targetPos - hrp.Position).Magnitude
  local clearSight = distToTarget < 14 and HasLineOfSight(hrp.Position, targetPos)

  local waypoints
  if not clearSight then
    waypoints = ComputePathWaypoints(hrp.Position, targetPos, targetRoom)
  end

  -- Follow waypoints if a path was found
  if waypoints and #waypoints > 1 then
    for i = 2, #waypoints do
      if not toggles.AutoFarmEnabled.Value or _Unloading or (tick() - startT > maxTime) then
        break
      end
      if not character or not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
        return false
      end

      local wp = waypoints[i]
      local wpPos = wp.Position + Vector3.new(0, 2.5, 0)
      local wpStart = tick()
      local lastPos = humanoidRootPart.Position
      local lastPosT = tick()

      while toggles.AutoFarmEnabled.Value and not _Unloading do
        if tick() - startT > maxTime or tick() - wpStart > 2.0 then
          break
        end

        local curPos = humanoidRootPart.Position
        local delta = wpPos - curPos
        local d = delta.Magnitude

        if d <= 3.5 then
          break
        end

        -- Anti-stuck: if stuck in a doorway/corner for 0.65s, advance to next waypoint
        if (curPos - lastPos).Magnitude > 0.4 then
          lastPos = curPos
          lastPosT = tick()
        elseif tick() - lastPosT > 0.65 then
          break
        end

        if KnobFarm.BodyVelocity then
          local clearVel = GetClearFlightVelocity(curPos, delta.Unit, speed, filter)
          KnobFarm.BodyVelocity.Velocity = clearVel
        end
        if KnobFarm.BodyGyro and delta.Magnitude > 0.5 then
          KnobFarm.BodyGyro.CFrame = CFrame.lookAt(curPos, curPos + Vector3.new(delta.X, 0, delta.Z))
        end
        task.wait()
      end
    end
  end

  -- Final smooth approach directly to target with wall sliding
  local finalStart = tick()
  local lastPos = humanoidRootPart.Position
  local lastPosT = tick()

  while toggles.AutoFarmEnabled.Value and not _Unloading do
    if not character or not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
      return false
    end
    if tick() - startT > maxTime or tick() - finalStart > 3.5 then
      break
    end

    local curPos = humanoidRootPart.Position
    local delta = targetPos - curPos
    local d = delta.Magnitude

    if d <= stopDist then
      if KnobFarm.BodyVelocity then KnobFarm.BodyVelocity.Velocity = Vector3.zero end
      return true
    end

    if (curPos - lastPos).Magnitude > 0.4 then
      lastPos = curPos
      lastPosT = tick()
    elseif tick() - lastPosT > 0.8 then
      -- Stuck on target geometry, nudge slightly upwards
      if KnobFarm.BodyVelocity then
        KnobFarm.BodyVelocity.Velocity = Vector3.new(0, speed * 0.5, 0)
      end
      task.wait(0.15)
      lastPosT = tick()
    end

    if KnobFarm.BodyVelocity then
      local clearVel = GetClearFlightVelocity(curPos, delta.Unit, speed, filter)
      KnobFarm.BodyVelocity.Velocity = clearVel
    end
    if KnobFarm.BodyGyro and delta.Magnitude > 0.5 then
      KnobFarm.BodyGyro.CFrame = CFrame.lookAt(curPos, curPos + Vector3.new(delta.X, 0, delta.Z))
    end
    task.wait()
  end

  if KnobFarm.BodyVelocity then KnobFarm.BodyVelocity.Velocity = Vector3.zero end
  return ((targetPos - humanoidRootPart.Position).Magnitude <= (stopDist + 2))
end

function KnobFarm.PhaseThrough()
  if not character or not humanoidRootPart then return end
  if toggles.AnticheatManipulation then
    toggles.AnticheatManipulation:SetValue(true)
    task.wait(0.35)
    toggles.AnticheatManipulation:SetValue(false)
  else
    pcall(function()
      character:PivotTo(character:GetPivot() * CFrame.new(0, 0, 750))
    end)
    task.wait(0.15)
  end
end

function KnobFarm.GetUnlootedContainers(room)
  local list = {}
  if not room then return list end

  for _, obj in ipairs(room:GetDescendants()) do
    if not KnobFarm.LootedObjects[obj] then
      local name = obj.Name

      if name == "GoldPile" or name == "StardustPickup" then
        if not IsBlacklistedItem(obj) then
          table.insert(list, { Type = "Gold", Object = obj, Pos = obj:GetPivot().Position })
        end
      elseif name == "DrawerContainer" or name == "ChestBox" or name == "Toolbox" then
        if not IsBlacklistedItem(obj) then
          table.insert(list, { Type = "Container", Object = obj, Pos = obj:GetPivot().Position })
        end
      end
    end
  end

  return list
end

function KnobFarm.LootContainer(item, room)
  local obj = item.Object
  if not obj or not obj.Parent then return end
  KnobFarm.LootedObjects[obj] = true

  local targetPos = item.Pos
  KnobFarm.SetStatus("Looting: " .. obj.Name)

  KnobFarm.MoveTo(targetPos + Vector3.new(0, 1.5, 0), nil, 4, 3, room)

  if item.Type == "Gold" then
    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and Functions.FirePrompt then
      Functions.FirePrompt(prompt)
    end
    task.wait(0.1)

  elseif item.Type == "Container" then
    for _, prompt in ipairs(obj:GetDescendants()) do
      if prompt:IsA("ProximityPrompt") then
        local pName = prompt.Name
        if not IsBlacklistedItem(prompt.Parent) and (pName == "Open" or pName == "ActivateEventPrompt" or prompt.ActionText:lower():find("open") or prompt.ActionText:lower():find("search")) then
          if Functions.FirePrompt then
            Functions.FirePrompt(prompt)
          end
        end
      end
    end
    task.wait(0.2)

    for _, child in ipairs(obj:GetDescendants()) do
      if (child.Name == "GoldPile" or child.Name == "StardustPickup") and not KnobFarm.LootedObjects[child] then
        KnobFarm.LootedObjects[child] = true
        local p = child:FindFirstChildWhichIsA("ProximityPrompt", true)
        if p and Functions.FirePrompt then
          Functions.FirePrompt(p)
        end
      end
    end
  end
end

function KnobFarm.HandleKeyAndDoor(room, door)
  if not door then return end
  local lock = door:FindFirstChild("Lock") or door:FindFirstChild("UnlockPrompt", true)

  if lock then
    local hasKey = character:FindFirstChild("Key") or (localPlayer2.Backpack and localPlayer2.Backpack:FindFirstChild("Key"))
    if not hasKey then
      local keyObj = room:FindFirstChild("KeyObtain", true) or room:FindFirstChild("Key", true)
      if keyObj then
        KnobFarm.SetStatus("Collecting Key...")
        local keyPos = keyObj:GetPivot().Position
        KnobFarm.MoveTo(keyPos + Vector3.new(0, 1, 0), nil, 3, 5, room)
        local prompt = keyObj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and Functions.FirePrompt then
          Functions.FirePrompt(prompt)
        end
        task.wait(0.25)
      end
    end

    -- Equip key tool if in backpack
    if localPlayer2.Backpack and localPlayer2.Backpack:FindFirstChild("Key") and humanoid then
      pcall(function() humanoid:EquipTool(localPlayer2.Backpack.Key) end)
      task.wait(0.1)
    end

    KnobFarm.SetStatus("Unlocking Door...")
    local lockPos = lock:IsA("BasePart") and lock.Position or door:GetPivot().Position
    KnobFarm.MoveTo(lockPos, nil, 3.5, 4, room)
    local unlockPrompt = door:FindFirstChild("UnlockPrompt", true) or (lock:IsA("ProximityPrompt") and lock) or lock:FindFirstChildWhichIsA("ProximityPrompt", true)
    if unlockPrompt and Functions.FirePrompt then
      Functions.FirePrompt(unlockPrompt)
    end
    task.wait(0.3)
  end
end

function KnobFarm.HandleGate(room)
  local gate = room:FindFirstChild("Gate", true) or room:FindFirstChild("GateBars", true)
  local lever = room:FindFirstChild("LeverForGate", true)

  if gate and lever then
    KnobFarm.SetStatus("Bypassing Gate...")
    local gatePos = gate:GetPivot().Position
    KnobFarm.MoveTo(gatePos, nil, 5, 4, room)

    KnobFarm.PhaseThrough()
    task.wait(0.15)

    KnobFarm.SetStatus("Flipping Lever...")
    local leverPos = lever:GetPivot().Position
    KnobFarm.MoveTo(leverPos, nil, 3.5, 4, room)
    local prompt = lever:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and Functions.FirePrompt then
      Functions.FirePrompt(prompt)
    end
    task.wait(0.2)
  end
end

function KnobFarm.HandleSeek(room)
  KnobFarm.SetStatus("Seek Chase: Flying High...")

  local oldGodmode = toggles.Godmode and toggles.Godmode.Value
  if oldGodmode then
    toggles.Godmode:SetValue(false)
  end

  local door = room:FindFirstChild("Door")
  if door then
    DisableDoorCollision(door)
    local doorPos = door:GetPivot().Position
    local highPos = Vector3.new(doorPos.X, humanoidRootPart.Position.Y + 8, doorPos.Z)

    KnobFarm.MoveTo(highPos, (options.AutoFarmSpeed.Value or 45) + 5, 4, 8, room)
    KnobFarm.MoveTo(doorPos + Vector3.new(0, 1, 0), nil, 3, 3, room)
  end

  if oldGodmode and toggles.Godmode then
    toggles.Godmode:SetValue(true)
  end
end

function KnobFarm.HandleRoom50(room)
  KnobFarm.SetStatus("Room 50: Library...")

  local function GetSafeCeilingPos()
    local roomPivot = room:GetPivot().Position
    return Vector3.new(roomPivot.X, roomPivot.Y + 14, roomPivot.Z)
  end

  local ceilingPos = GetSafeCeilingPos()

  local paper = room:FindFirstChild("LibraryHintPaper", true) or room:FindFirstChild("HintPaper", true)
  if paper and not KnobFarm.LootedObjects[paper] then
    KnobFarm.SetStatus("Grabbing Library Paper...")
    local pPos = paper:GetPivot().Position
    KnobFarm.MoveTo(pPos + Vector3.new(0, 1.5, 0), nil, 3, 5, room)
    local pr = paper:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pr and Functions.FirePrompt then
      Functions.FirePrompt(pr)
    end
    KnobFarm.LootedObjects[paper] = true
    task.wait(0.2)
  end

  local booksCollected = 0
  local currentCode = (options and options.LibraryPadlockCode and options.LibraryPadlockCode.Value) or ""

  while #currentCode < 5 and booksCollected < 8 and toggles.AutoFarmEnabled.Value and not _Unloading do
    currentCode = (options and options.LibraryPadlockCode and options.LibraryPadlockCode.Value) or ""
    if #currentCode == 5 and not currentCode:find("_") then
      KnobFarm.SetStatus("Code Solved: " .. currentCode)
      break
    end

    local books = {}
    for _, b in ipairs(room:GetDescendants()) do
      if b.Name == "LiveHintBook" and not KnobFarm.LootedObjects[b] then
        table.insert(books, { Book = b, Pos = b:GetPivot().Position })
      end
    end

    if #books == 0 then break end

    local figure = workspace:FindFirstChild("FigureRig", true) or room:FindFirstChild("FigureRig", true)
    if figure and figure:FindFirstChild("HumanoidRootPart") then
      local fPos = figure.HumanoidRootPart.Position
      if (fPos - humanoidRootPart.Position).Magnitude < 25 then
        KnobFarm.SetStatus("Waiting for Figure to move...")
        KnobFarm.MoveTo(ceilingPos, 20, 2, 2, room)
        task.wait(1)
        continue
      end
    end

    local targetBook = books[1]
    KnobFarm.LootedObjects[targetBook.Book] = true
    KnobFarm.SetStatus("Collecting Book...")
    KnobFarm.MoveTo(targetBook.Pos + Vector3.new(0, 1.5, 0), nil, 3, 5, room)
    local p = targetBook.Book:FindFirstChildWhichIsA("ProximityPrompt", true)
    if p and Functions.FirePrompt then
      Functions.FirePrompt(p)
    end
    booksCollected = booksCollected + 1
    task.wait(0.2)
  end

  local padlock = room:FindFirstChild("Padlock", true)
  if padlock then
    local pPos = padlock:GetPivot().Position
    local figure = workspace:FindFirstChild("FigureRig", true) or room:FindFirstChild("FigureRig", true)
    if figure and figure:FindFirstChild("HumanoidRootPart") then
      local fPos = figure.HumanoidRootPart.Position
      if (fPos - pPos).Magnitude < 30 then
        KnobFarm.SetStatus("Waiting for safe moment at Padlock...")
        KnobFarm.MoveTo(ceilingPos, 20, 2, 3, room)
        local waitT = tick()
        while tick() - waitT < 6 do
          fPos = figure.HumanoidRootPart.Position
          if (fPos - pPos).Magnitude >= 30 then break end
          task.wait(0.5)
        end
      end
    end

    KnobFarm.SetStatus("Unlocking Padlock...")
    KnobFarm.MoveTo(pPos, nil, 3.5, 5, room)
    local finalCode = (options and options.LibraryPadlockCode and options.LibraryPadlockCode.Value) or ""
    if finalCode and not finalCode:find("_") and remotesFolder2 and remotesFolder2:FindFirstChild("PL") then
      remotesFolder2.PL:FireServer(finalCode)
    end
    task.wait(0.5)
  end

  local door51 = room:FindFirstChild("Door")
  if door51 then
    DisableDoorCollision(door51)
    OpenDoorRemotes(door51)
    KnobFarm.MoveTo(door51:GetPivot().Position + Vector3.new(0, 1, 0), nil, 3, 4, room)
  end
end

function KnobFarm.HandleRoom100(room)
  KnobFarm.SetStatus("Room 100: Electrical Room...")

  local elKey = room:FindFirstChild("ElectricalKey", true) or room:FindFirstChild("Key", true)
  if elKey and not KnobFarm.LootedObjects[elKey] then
    KnobFarm.SetStatus("Grabbing Electrical Key...")
    KnobFarm.MoveTo(elKey:GetPivot().Position + Vector3.new(0, 1, 0), nil, 3, 5, room)
    local pr = elKey:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pr and Functions.FirePrompt then
      Functions.FirePrompt(pr)
    end
    KnobFarm.LootedObjects[elKey] = true
    task.wait(0.2)
  end

  local elDoor = room:FindFirstChild("ElectricalDoor", true)
  if elDoor then
    DisableDoorCollision(elDoor)
    KnobFarm.SetStatus("Unlocking Electrical Door...")
    KnobFarm.MoveTo(elDoor:GetPivot().Position, nil, 3.5, 4, room)
    local pr = elDoor:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pr and Functions.FirePrompt then
      Functions.FirePrompt(pr)
    end
    task.wait(0.3)
  end

  KnobFarm.SetStatus("Collecting Fuses...")
  local fuseCount = 0
  for _, fuse in ipairs(room:GetDescendants()) do
    if fuse.Name == "Fuse" or fuse.Name == "FuseBoxItem" then
      if not KnobFarm.LootedObjects[fuse] then
        KnobFarm.LootedObjects[fuse] = true
        fuseCount = fuseCount + 1
        KnobFarm.SetStatus("Fuse " .. fuseCount .. "/10...")
        KnobFarm.MoveTo(fuse:GetPivot().Position + Vector3.new(0, 1, 0), nil, 3, 4, room)
        local pr = fuse:FindFirstChildWhichIsA("ProximityPrompt", true)
        if pr and Functions.FirePrompt then
          Functions.FirePrompt(pr)
        end
        task.wait(0.2)
        if fuseCount >= 10 then break end
      end
    end
  end

  local breaker = room:FindFirstChild("BreakerBox", true) or room:FindFirstChild("BreakerSwitch", true)
  if breaker then
    KnobFarm.SetStatus("Solving Breaker Box...")
    KnobFarm.MoveTo(breaker:GetPivot().Position, nil, 3.5, 5, room)
    local pr = breaker:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pr and Functions.FirePrompt then
      Functions.FirePrompt(pr)
    end

    if toggles and toggles.AutoBreakerBox and not toggles.AutoBreakerBox.Value then
      toggles.AutoBreakerBox:SetValue(true)
    end

    local waitBreaker = tick()
    while tick() - waitBreaker < 15 and toggles.AutoFarmEnabled.Value do
      local complete = room:GetAttribute("BreakerComplete") or (breaker and breaker:GetAttribute("Solved"))
      if complete then break end
      task.wait(0.5)
    end
  end

  KnobFarm.SetStatus("Breaker complete! Flying to Elevator...")
  local elevator = room:FindFirstChild("Elevator", true) or room:FindFirstChild("ElevatorDoor", true) or room:FindFirstChild("Door")
  if elevator then
    DisableDoorCollision(elevator)
    KnobFarm.MoveTo(elevator:GetPivot().Position, nil, 3, 6, room)
    local pr = elevator:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pr and Functions.FirePrompt then
      Functions.FirePrompt(pr)
    end
  end
end

function KnobFarm.RunLoop()
  while toggles.AutoFarmEnabled.Value and not _Unloading do
    if not character or not humanoidRootPart or not humanoid or humanoid.Health <= 0 then
      task.wait(1)
      continue
    end

    local currentRoomsObj = workspace:FindFirstChild("CurrentRooms")
    if not currentRoomsObj then
      task.wait(1)
      continue
    end

    local roomNum = (element2 and element2.Value) or (localPlayer2 and localPlayer2:GetAttribute("CurrentRoom")) or 0
    local room = currentRoomsObj:FindFirstChild(tostring(roomNum))

    if not room then
      task.wait(0.5)
      continue
    end

    -- Pre-disable door collisions across current room so pathfinding & flight are never blocked
    DisableDoorCollision(room)

    if KnobFarm.LastRoomNumber ~= roomNum then
      KnobFarm.LastRoomNumber = roomNum
      KnobFarm.LootedObjects = {}
      KnobFarm.SetStatus("Room " .. roomNum .. ": Exploring...")
    end

    if tonumber(roomNum) and tonumber(roomNum) >= 100 or room.Name == "100" then
      if toggles.AutoFarmRunTo100.Value then
        KnobFarm.HandleRoom100(room)
      else
        KnobFarm.SetStatus("Reached Room 100! Farm stopped.")
        toggles.AutoFarmEnabled:SetValue(false)
        break
      end
      task.wait(1)
      continue
    end

    if tonumber(roomNum) == 50 or room.Name == "50" then
      KnobFarm.HandleRoom50(room)
      task.wait(1)
      continue
    end

    local isSeek = room:FindFirstChild("Seek_Arm") or room:FindFirstChild("ChandelierObstruction")
      or room:FindFirstChild("SeekFloodline") or room:FindFirstChild("SeekMoving")
      or (room:GetAttribute("RawName") and tostring(room:GetAttribute("RawName")):find("Seek"))

    if isSeek then
      KnobFarm.HandleSeek(room)
      task.wait(1)
      continue
    end

    local gate = room:FindFirstChild("Gate", true)
    local lever = room:FindFirstChild("LeverForGate", true)
    if gate and lever then
      KnobFarm.HandleGate(room)
    end

    if toggles.AutoFarmLootDrawers.Value then
      local containers = KnobFarm.GetUnlootedContainers(room)
      local maxLootPerRoom = 25
      while #containers > 0 and maxLootPerRoom > 0 and toggles.AutoFarmEnabled.Value do
        maxLootPerRoom = maxLootPerRoom - 1
        table.sort(containers, function(a, b)
          local da = (humanoidRootPart.Position - a.Pos).Magnitude
          local db = (humanoidRootPart.Position - b.Pos).Magnitude
          return da < db
        end)

        local closest = containers[1]
        KnobFarm.LootContainer(closest, room)
        task.wait(0.05)
        containers = KnobFarm.GetUnlootedContainers(room)
      end
    end

    local door = room:FindFirstChild("Door")
    if door then
      -- 1. Disable collision on door so it never blocks us
      DisableDoorCollision(door)

      -- 2. Unlock door if locked
      KnobFarm.HandleKeyAndDoor(room, door)

      -- 3. Approach door
      KnobFarm.SetStatus("Room " .. roomNum .. ": Opening Door...")
      local doorPart = door:FindFirstChild("Door") or door:FindFirstChild("Hidden") or door:FindFirstChildWhichIsA("BasePart") or door
      local dPos = doorPart:GetPivot().Position
      KnobFarm.MoveTo(dPos, nil, 3.5, 5, room)

      -- 4. Open door via remote and prompt
      OpenDoorRemotes(door)
      DisableDoorCollision(door)
      task.wait(0.15)

      -- 5. Fly THROUGH the doorway into the next room
      KnobFarm.SetStatus("Room " .. roomNum .. ": Entering Next Room...")
      local nextRoomNum = tostring(tonumber(roomNum) + 1)
      local nextRoom = currentRoomsObj:FindFirstChild(nextRoomNum)

      local throughTarget
      if nextRoom then
        local roomStart = nextRoom:FindFirstChild("RoomStart") or nextRoom:FindFirstChild("Door") or nextRoom:FindFirstChildWhichIsA("BasePart")
        throughTarget = roomStart and roomStart:GetPivot().Position or (dPos + (nextRoom:GetPivot().Position - dPos).Unit * 12)
      else
        local roomCenter = room:GetPivot().Position
        local dirOut = (dPos - roomCenter)
        dirOut = Vector3.new(dirOut.X, 0, dirOut.Z).Unit
        throughTarget = dPos + dirOut * 12 + Vector3.new(0, 1.5, 0)
      end

      -- Fly past the threshold into room N+1
      KnobFarm.MoveTo(throughTarget, nil, 3.0, 4, room)

      -- 6. Await room attribute update
      local waitRoom = tick()
      while tick() - waitRoom < 4 do
        local newRoom = (element2 and element2.Value) or (localPlayer2 and localPlayer2:GetAttribute("CurrentRoom"))
        if newRoom and tostring(newRoom) ~= tostring(roomNum) then
          break
        end
        task.wait(0.15)
      end
    else
      task.wait(0.5)
    end

    task.wait(0.1)
  end

  KnobFarm.StopFlight()
  KnobFarm.SetStatus("Idle")
end

toggles.AutoFarmEnabled:OnChanged(function(enabled)
  if enabled then
    KnobFarm.Active = true
    if KnobFarm.Thread then task.cancel(KnobFarm.Thread) end
    KnobFarm.Thread = task.spawn(KnobFarm.RunLoop)
  else
    KnobFarm.Active = false
    KnobFarm.StopFlight()
    if KnobFarm.Thread then
      task.cancel(KnobFarm.Thread)
      KnobFarm.Thread = nil
    end
    KnobFarm.SetStatus("Idle")
  end
end)

-- Auto Play Again (7 seconds on Death or Win)
local function SetupAutoPlayAgain()
  local function onChar(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
      hum.Died:Connect(function()
        if toggles.AutoFarmEnabled and toggles.AutoFarmEnabled.Value and toggles.AutoFarmPlayAgain.Value then
          KnobFarm.SetStatus("Dead! Restarting in 7s...")
          task.delay(7, function()
            if toggles.AutoFarmPlayAgain.Value then
              pcall(function()
                local playAgain = remotesFolder2 and remotesFolder2:FindFirstChild("PlayAgain")
                if playAgain then
                  playAgain:FireServer()
                end
              end)
            end
          end)
        end
      end)
    end
  end

  if localPlayer2.Character then onChar(localPlayer2.Character) end
  localPlayer2.CharacterAdded:Connect(onChar)

  local pGui = localPlayer2:FindFirstChildOfClass("PlayerGui")
  if pGui then
    pGui.DescendantAdded:Connect(function(desc)
      if desc.Name == "GameOver" or desc.Name == "Death" then
        if toggles.AutoFarmEnabled and toggles.AutoFarmEnabled.Value and toggles.AutoFarmPlayAgain.Value then
          task.delay(7, function()
            pcall(function()
              local playAgain = remotesFolder2 and remotesFolder2:FindFirstChild("PlayAgain")
              if playAgain then playAgain:FireServer() end
            end)
          end)
        end
      end
    end)
  end
end

SetupAutoPlayAgain()

if CurrentFloor == "Lobby" then
  for index81, value126 in ipairs({
    "Godmode", "ThirdPerson", "Noclip", "FlyToggle", "Phase", "AnticheatManipulation", "AutoInteract", "ArchiveChairFly", "StairwellChairFly", "AntiElectricPuddle", "AntiRansom", "AntiScribbles", "NoAlmaDamage", "AntiDrone", "DisableDroneStampede", "RoomsAutoWalk", "RoomsAutoWalkIgnoreA60", "RoomsAutoWalkShowPathToggle", "RoomsAutoWalkSpoofFootsteps", "RoomsPickupStardust", "RoomsPickupGold", "NoSurgeDamage", "RemoveSurge", "RemoveMandrake", "BypassKillbricks", "BypassSeekingWall", "BypassBanana", "BypassJeff", "BypassGiggle", "BypassDupe", "BypassEyes", "BypassLookman", "BypassGloombatEggs", "BypassSeekObstructions", "BypassVacuum", "BypassSnare", "RemoveSeekTrigger", "RemoveFigure", "RemoveFigureMines", "RemoveA90", "RemoveDread", "AutoRevive", "FigureGodmode", "AutoSteerMinecart", "AutoSolveAnchors", "MinecartTeleport", "AutoMinecart", "AutoHeartbeatMinigame", "AutoBreakerBox", "AutoLibraryBruteForce", "InfiniteItemsToggle", "InfiniteCrucifix", "ShowSeekPathToggle", }) do
    local element46 = toggles[value126]

    if element46 and element46.Value then
      element46:SetValue(false)
    end
  end
end

local val313

local function safeCall11()
  _Unloading = true

  if KnobFarm and KnobFarm.StopFlight then
    pcall(KnobFarm.StopFlight)
  end
  if KnobFarm and KnobFarm.Thread then
    pcall(task.cancel, KnobFarm.Thread)
  end

  pcall(onEvent2)
  pcall(helper40)
  pcall(helper39)
  pcall(helper46)

  if FreecamConnection then
    FreecamConnection:Disconnect()
    FreecamConnection = nil
  end

  local freecamPart4 = workspace:FindFirstChild("FreecamPart")

  if freecamPart4 then
    freecamPart4:Destroy()

    local humanoidRootPart10 = localPlayer2.Character
      and localPlayer2.Character:FindFirstChild("HumanoidRootPart")

    if humanoidRootPart10 then
      humanoidRootPart10.Anchored = false
    end

    localPlayer2.CameraMinZoomDistance = localPlayer2:GetAttribute("fc_om") or 0.5
    localPlayer2.CameraMaxZoomDistance = localPlayer2:GetAttribute("fc_ox") or 128
  end

  if CameraConnection then
    CameraConnection:Disconnect()
    CameraConnection = nil
  end

  if _TPCharConn then
    _TPCharConn:Disconnect()
    _TPCharConn = nil
  end

  if currentCamera then
    currentCamera.CameraType = Enum.CameraType.Custom
  end

  if NoclipConnection then
    NoclipConnection:Disconnect()
    NoclipConnection = nil
    pcall(iterate3, true)
  end

  if connect18 then
    connect18:Disconnect()
    connect18 = nil
  end

  if _AutoHideConnection then
    _AutoHideConnection:Disconnect()
    _AutoHideConnection = nil
  end

  if AnticheatConnection then
    AnticheatConnection:Disconnect()
    AnticheatConnection = nil
  end

  if InfiniteJumpConnection then
    InfiniteJumpConnection:Disconnect()
    InfiniteJumpConnection = nil
  end

  if JumpAttributeConnection then
    JumpAttributeConnection:Disconnect()
    JumpAttributeConnection = nil
  end

  if SlideAttributeConnection then
    SlideAttributeConnection:Disconnect()
    SlideAttributeConnection = nil
  end

  if DisableIdleKickConn then
    DisableIdleKickConn:Disconnect()
    DisableIdleKickConn = nil
  end

  if DisplayInfoConn then
    DisplayInfoConn:Disconnect()
    DisplayInfoConn = nil
  end

  if UhhhhConn then
    UhhhhConn:Disconnect()
    UhhhhConn = nil
  end

  if OrbitConn then
    OrbitConn:Disconnect()
    OrbitConn = nil
  end

  pcall(helper23)

  if val313 then
    val313:Disconnect()
    val313 = nil
  end

  if _FloorConnection then
    _FloorConnection:Disconnect()
    _FloorConnection = nil
  end

  if val85 and val85.LobbyGuardConnection then
    val85.LobbyGuardConnection:Disconnect()
    val85.LobbyGuardConnection = nil
  end

  if Phase then
    if Phase.Connection then
      Phase.Connection:Disconnect()
      Phase.Connection = nil
    end

    if Phase.Body then
      Phase.Body:Destroy()
      Phase.Body = nil
    end

    if Phase.CharConn then
      Phase.CharConn:Disconnect()
      Phase.CharConn = nil
    end
  end

  helper62()

  if val202 and val202.NoclipConn then
    val202.NoclipConn:Disconnect()
    val202.NoclipConn = nil
  end

  if Connections then
    if Connections.InfiniteItemsHandler then
      Connections.InfiniteItemsHandler:Disconnect()
      Connections.InfiniteItemsHandler = nil
    end

    if Connections.PadlockConnection then
      Connections.PadlockConnection:Disconnect()
      Connections.PadlockConnection = nil
    end
  end

  if _FullbrightConnection then
    _FullbrightConnection:Disconnect()
    _FullbrightConnection = nil
  end

  if _FullbrightRoomConn then
    _FullbrightRoomConn:Disconnect()
    _FullbrightRoomConn = nil
  end

  pcall(helper72)

  if promptContainer then
    promptContainer:Destroy()
  end

  pcall(function()
    for key17, value127 in pairs(FakePrompts or {}) do
      pcall(function()
        value127.Parent = key17.Parent
        key17:Destroy()

        if value127.Parent then
          value127.HoldDuration = value127:GetAttribute("HoldDuration_Old")
            or value127.HoldDuration

          value127.RequiresLineOfSight = value127:GetAttribute("RequiresLineOfSight_Old")
            or value127.RequiresLineOfSight

          value127.MaxActivationDistance = value127:GetAttribute("MaxActivationDistance_Old")
            or value127.MaxActivationDistance
        end
      end)
    end
  end)

  if _TrackedPrompts then
    for index82, value128 in ipairs(_TrackedPrompts) do
      pcall(function()
        if value128.Parent then
          value128.HoldDuration = value128:GetAttribute("HoldDuration_Old")
            or value128.HoldDuration

          value128.RequiresLineOfSight = value128:GetAttribute("RequiresLineOfSight_Old")
            or value128.RequiresLineOfSight

          value128.MaxActivationDistance = value128:GetAttribute("MaxActivationDistance_Old")
            or value128.MaxActivationDistance
        end
      end)
    end
  end

  for v533, v534 in workspace:GetDescendants() do
    task.spawn(function() end)
  end

  pcall(loader.Unload, loader)

  pcall(function()
    if Executor.hookmetamethod and MainHook then
      Executor.hookmetamethod(game, "__namecall", MainHook)
    end
  end)

  pcall(function()
    if Executor.hookmetamethod and OtherHook then
      Executor.hookmetamethod(game, "__index", OtherHook)
    end
  end)

  pcall(function()
    local element47 = helper74()

    if element47 then
      element47.tooloffset = Vector3.zero
      element47.spring.Speed = 8
      element47.fovtarget = 70
      element47.csgo = CFrame.new()
    end
  end)

  pcall(function() workspace.CurrentCamera.FieldOfView = 70 end)
  pcall(function() workspace.Gravity = 196.2 end)
  pcall(function() Lighting.FogEnd = val85 and val85.OldFog or Lighting.FogEnd end)

  pcall(function()
    for index83, value129 in ipairs(val85.FogInstances or {}) do
      local densityOld = value129:GetAttribute("Density_Old")

      if densityOld then
        value129.Density = densityOld
      end
    end
  end)

  pcall(function()
    local haste = replicatedStorage:FindFirstChild("FloorReplicated")
      and replicatedStorage.FloorReplicated:FindFirstChild("ClientRemote")
      and replicatedStorage.FloorReplicated.ClientRemote:FindFirstChild("Haste")

    if haste then
      local ambience = haste:FindFirstChild("Ambience")

      if ambience then
        ambience.Playing = true
      end
    end
  end)

  pcall(function()
    local playerGui12 = localPlayer2:FindFirstChildOfClass("PlayerGui")

    if playerGui12 then
      local findFirstChild17 = playerGui12:FindFirstChild("DisplayInfoLabel", true)

      if findFirstChild17 then
        findFirstChild17:Destroy()
      end
    end
  end)

  if val85 then
    if val85.SeekNodesFolder then
      val85.SeekNodesFolder:Destroy()
    end

    if val85.RoomsNodesFolder then
      val85.RoomsNodesFolder:Destroy()
    end

    if val85.OriginalGetMoveVector then
      pcall(function()
        local getControls2 = require(localPlayer2.PlayerScripts.PlayerModule):GetControls()
        getControls2.GetMoveVector = val85.OriginalGetMoveVector
      end)

      val85.OriginalGetMoveVector = nil
    end

    val85.AnticheatDisabled = false
    val85.RoomsAutoWalkActive = false
  end

  pcall(function()
    if val85.ClearAddonGroupboxes then
      val85.ClearAddonGroupboxes()
    end
  end)

  if AutoMinecartConnection then
    AutoMinecartConnection:Disconnect()
    AutoMinecartConnection = nil
  end

  if character then
    pcall(function() character:SetAttribute("CanJump", OldJump or false) end)
    pcall(function() character:SetAttribute("CanSlide", OldSlide or false) end)
    pcall(function() character:SetAttribute("SpeedBoost", 0) end)
    pcall(function() character:SetAttribute("SpeedBoostBehind", 0) end)
    pcall(function() character:SetAttribute("SpeedBoostExtra", 0) end)
    pcall(function() character:SetAttribute("SpeedBoostMod", 0) end)
    pcall(function() character:SetAttribute("AntiSpeed", nil) end)
    pcall(function() character:SetAttribute("Antispeed", nil) end)
    pcall(function() character:SetAttribute("SpeedBypass", nil) end)
    pcall(function() character:SetAttribute("Climbing", nil) end)
  end

  if humanoid then
    pcall(function() humanoid.WalkSpeed = 16 end)
    pcall(function() humanoid.JumpPower = 5 end)
    pcall(function() humanoid.HipHeight = 2.367 end)
    pcall(function() humanoid.PlatformStand = false end)
    pcall(function() humanoid:SetAttribute("AntiSpeed", nil) end)
    pcall(function() humanoid:SetAttribute("Antispeed", nil) end)
  end

  if humanoidRootPart then
    humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
  end

  for key18, value130 in pairs(val114 or {}) do
    if type(value130) == "table" then
      for index84, value131 in ipairs(value130) do
      end

      TableClear(value130)
    end
  end

  for key19, value132 in pairs(PartProperties or {}) do
    pcall(function() value132.CustomPhysicalProperties = PartProperties[value132] end)
  end

  pcall(function()
    local object12 = helper19()

    if object12 then
      for index85, value133 in ipairs({
        "Screech", "GlitchScreech", "A90", "Dread", "SurgeVignette", }) do
        local findFirstChild18 = object12:FindFirstChild(value133 .. "_Disabled")

        if findFirstChild18 then
          findFirstChild18.Name = value133
        end
      end
    end
  end)

  if FakeEvents then
    if FakeEvents.Screech_Real then
      FakeEvents.Screech_Real.Parent = remotesFolder2
    end

    if FakeEvents.Shade_Real then
      FakeEvents.Shade_Real.Parent = remotesFolder2
    end

    if FakeEvents.A90_Real then
      FakeEvents.A90_Real.Parent = remotesFolder2
    end

    if FakeEvents.Surge_Real then
      FakeEvents.Surge_Real.Parent = remotesFolder2
    end

    for _, fakeName in ipairs({"Screech", "Shade", "A90", "Surge"}) do
      local fake = FakeEvents[fakeName]
      if typeof(fake) == "Instance" and fake:IsA("RemoteEvent") then
        pcall(fake.Destroy, fake)
      end
    end
  end

  if character then
    local collisionClone8 = character:FindFirstChild("CollisionClone")

    if collisionClone8 then
      collisionClone8:Destroy()
    end

    local collisionPartClone = character:FindFirstChild("CollisionPartClone")

    if collisionPartClone then
      collisionPartClone:Destroy()
    end
  end

  if localPlayer2 then
    localPlayer2.CameraMinZoomDistance = 0.5
    localPlayer2.CameraMaxZoomDistance = 128
    localPlayer2:SetAttribute("fc_om", nil)
    localPlayer2:SetAttribute("fc_ox", nil)
    localPlayer2:SetAttribute("fc_p", nil)
    localPlayer2:SetAttribute("fc_y", nil)
  end

  if element3.Stairwell then
    element3.Stairwell:SetVisible(false)
  end

  if element3.FoolsHotel then
    element3.FoolsHotel:SetVisible(false)
  end

  if element3.Rooms then
    element3.Rooms:SetVisible(false)
  end

end

getgenv().MoroUnload = safeCall11
getgenv().CheesyUnload = safeCall11

library:OnUnload(function()
  _Unloading = true
  safeCall11()
  getgenv().MoroUnload = nil
  getgenv().CheesyUnload = nil
end)

if library.ScreenGui then
  library.ScreenGui.Destroying:Once(function()
    _Unloading = true
    safeCall11()
  end)
end
do
  local connect29 = logService.MessageOut:Connect(function(p209)
    if p209 == "client teleporting" then
      if val85.AnticheatDisabled then
        val85.AnticheatDisabled = false

        library:Notify({
          Title = "Anticheat re-enabled", Description = "Interact with a ladder for re-disabling", Time = 5, })
      end

      connect29:Disconnect()
    end
  end)
end

element3.FoolsHotel:SetVisible(false)

library:Toggle(true)

library:Notify({
  Title = "Loaded moro in " .. math.floor((tick() - LoadStart) * 1000) / 1000 .. " seconds",
  Description = "MoroLumina UI Framework",
  Time = 5,
})
if toggles.AutoInteract then
  pcall(function() toggles.AutoInteract:SetDisabled(not hasFirePrompt) end)
end

if toggles.InfiniteItemsToggle then
  pcall(function() toggles.InfiniteItemsToggle:SetDisabled(not hasFirePrompt) end)
end

if toggles.InfiniteCrucifix then
  pcall(function() toggles.InfiniteCrucifix:SetDisabled(not hasFirePrompt) end)
end

if toggles.RemoveSeekTrigger then
  pcall(function() toggles.RemoveSeekTrigger:SetDisabled(not hasFireTouch) end)
end

if toggles.RemoveFigure then
  pcall(function() toggles.RemoveFigure:SetDisabled(not hasNetworkOwner) end)
end

if toggles.RemoveFigureMines then
  pcall(function() toggles.RemoveFigureMines:SetDisabled(not hasNetworkOwner) end)
end

if toggles.AutoHeartbeatMinigame then
  pcall(function() toggles.AutoHeartbeatMinigame:SetDisabled(not hasHookMeta) end)
end

if toggles.BypassEyes then
  pcall(function() toggles.BypassEyes:SetDisabled(not hasHookMeta) end)
end

if toggles.BypassLookman then
  pcall(function() toggles.BypassLookman:SetDisabled(not hasHookMeta) end)
end

if toggles.RoomsAutoWalkSpoofFootsteps then
  pcall(function() toggles.RoomsAutoWalkSpoofFootsteps:SetDisabled(not hasHookMeta) end)
end

pcall(function() execName = RootEnv.identifyexecutor() end)

if hasFirePrompt and hasFireTouch and hasReplicateSignal and hasNetworkOwner and hasHookMeta then
  library:Notify({
    Title = "Yay", Description = "All features should work as all used functions are supported :D ("
      .. tostring(execName) .. ")", Time = 5, })
else
  library:Notify({
    Title = "Uh oh", Description = "Some features may not work as not all used functions are supported :( ("
      .. tostring(execName) .. ")", Time = 5, })
end

pcall(function()
  local strVal7 = string.lower(tostring(execName))

  if strVal7:find("xeno", 1, true) or strVal7:find("solara", 1, true) then
    library:Notify({
      Title = "Executor not supported", Description = "Xeno and Solara are both very unstable and may/most likely will not work with the script, I advise using a better executor", Time = 10, })
  end
end)
