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

-- MoroElite from GitHub (cached to MoroElite.lua); the cache is only used when GitHub is unreachable
local RAW_URL = "https://raw.githubusercontent.com/Morozhka144/GUI2222/main/MoroElite.lua"
local CACHE_FILE = "MoroElite.lua"
local Lumina

local success9, result2 = pcall(function()
    local src = game:HttpGet(RAW_URL)
    local lib = safeLoad(src, "MoroElite")
    if lib and writefile then pcall(writefile, CACHE_FILE, src) end
    return lib
end)
if success9 and result2 then
    Lumina = result2
else
    pcall(function()
        if readfile and isfile and isfile(CACHE_FILE) then
            Lumina = safeLoad(readfile(CACHE_FILE), "MoroEliteCache")
        end
    end)
end
if not Lumina then
    error("[Moro] Failed to load MoroElite UI library! Check your internet connection or GitHub access.")
end

-- calls every listener; elements notify through their Callback so OnChanged works for every element type
local function fireListeners(list, ...)
    for _, fn in ipairs(list) do pcall(fn, ...) end
end
local function toSet(arr)
    local set = {}
    for _, v in ipairs(arr or {}) do set[v] = true end
    return set
end

local library = {}
library.Toggles = {}
library.Options = {}
library.TabButtons = {}
library.ScreenGui = nil

local MoroWindow = nil
local tabs = nil

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
setmetatable(dummyToggle, {
    __index = function(t, k)
        return function() end
    end
})

local dummyOption = {
    Value = false,
    SetValue = function() end,
    SetDisabled = function() end,
    OnChanged = function() end,
    GetState = function() return {} end,
}
setmetatable(dummyOption, {
    __index = function(t, k)
        return function() end
    end
})

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
    AddButton = function() return { OnClick = function() end } end,
    AddLabel = function() return { SetText = function() end, AddKeyPicker = function() return dummyOption end } end,
    AddDivider = function() end,
    AddInput = function() return dummyOption end,
    AddImage = function() return { SetImage = function() end, SetVisible = function() end } end,
}
setmetatable(dummySection, {
    __index = function(t, k)
        return function() end
    end
})

local dummyTab = {
    Name = "Home",
    OriginalName = "Home",
    AddLeftGroupbox = function() return dummySection end,
    AddRightGroupbox = function() return dummySection end,
    AddLeftTabbox = function() return { AddTab = function() return dummySection end } end,
    AddRightTabbox = function() return { AddTab = function() return dummySection end } end,
    SetVisible = function() end,
    Show = function(self)
        if tabs and tabs.Main and tabs.Main.Show then
            tabs.Main:Show()
        end
    end,
}
setmetatable(dummyTab, {
    __index = function(t, k)
        return function() end
    end
})

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
            Description = cfg.Tooltip,
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
                local cpListeners = {}
                local luminaCP = luminaTgl:AddColorPicker({
                    Default = cpCfg.Default or Color3.fromRGB(255, 255, 255),
                    Flag = cpFlag,
                    Callback = function(col)
                        if cpCfg.Callback then pcall(cpCfg.Callback, col) end
                        fireListeners(cpListeners, col)
                    end,
                })
                local cpProxy = {
                    _raw = luminaCP,
                    _flag = cpFlag,
                    _listeners = cpListeners,
                    SetValue = function(self, col)
                        if luminaCP and luminaCP.Set then luminaCP.Set(col) end
                    end,
                    SetValueRGB = function(self, col)
                        if luminaCP and luminaCP.Set then luminaCP.Set(col) end
                    end,
                    OnChanged = function(self, fn)
                        table.insert(cpListeners, fn)
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
        local sliderListeners = {}
        local luminaSlider = luminaSec:AddSlider({
            Name = cfg.Text or flag,
            Description = cfg.Tooltip,
            Min = cfg.Min or 0,
            Max = cfg.Max or 100,
            Default = cfg.Default or cfg.Min or 0,
            Decimals = cfg.Rounding or 0,
            Suffix = cfg.Suffix or "",
            Flag = flag,
            Callback = function(val)
                if cfg.Callback then pcall(cfg.Callback, val) end
                fireListeners(sliderListeners, val)
            end,
        })
        local sliderProxy = {
            _raw = luminaSlider,
            _flag = flag,
            _listeners = sliderListeners,
            SetValue = function(self, val)
                if luminaSlider and luminaSlider.Set then luminaSlider.Set(val) end
            end,
            OnChanged = function(self, fn)
                table.insert(sliderListeners, fn)
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
            local multiProxy
            local luminaMulti = luminaSec:AddMultiDropdown({
                Name = cfg.Text or flag,
                Description = cfg.Tooltip,
                Options = cfg.Values or {},
                Default = defs,
                Flag = flag,
                Callback = function(val)
                    if cfg.Callback then pcall(cfg.Callback, val) end
                    if multiProxy and multiProxy._listeners then
                        for _, fn in ipairs(multiProxy._listeners) do
                            pcall(fn, val)
                        end
                    end
                end,
            })
            multiProxy = {
                _raw = luminaMulti,
                _flag = flag,
                _listeners = {},
                GetState = function(self)
                    return (luminaMulti and luminaMulti.Get and toSet(luminaMulti.Get())) or {}
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
                    if self._listeners then
                        local cur = self:GetState()
                        for _, fn in ipairs(self._listeners) do
                            pcall(fn, cur)
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
                        return (luminaMulti and luminaMulti.Get and toSet(luminaMulti.Get())) or {}
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
            local dropProxy
            local luminaDrop = luminaSec:AddDropdown({
                Name = cfg.Text or flag,
                Description = cfg.Tooltip,
                Options = cfg.Values or {},
                Default = def or (cfg.Values and cfg.Values[1]) or "",
                Flag = flag,
                Callback = function(val)
                    if cfg.Callback then pcall(cfg.Callback, val) end
                    if dropProxy and dropProxy._listeners then
                        for _, fn in ipairs(dropProxy._listeners) do
                            pcall(fn, val)
                        end
                    end
                end,
            })
            dropProxy = {
                _raw = luminaDrop,
                _flag = flag,
                _listeners = {},
                SetValue = function(self, val)
                    if luminaDrop and luminaDrop.Set then luminaDrop.Set(val) end
                    if self._listeners then
                        for _, fn in ipairs(self._listeners) do
                            pcall(fn, val)
                        end
                    end
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
            Description = cfg.Tooltip,
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
                local kbListeners = {}
                local luminaKB = luminaSec:AddKeybind({
                    Name = kpCfg.Text or cleanText or kpFlag,
                    Default = defKey,
                    Mode = kpCfg.Mode or "Toggle",
                    Flag = kpFlag,
                    ChangedCallback = function(key) fireListeners(kbListeners, key) end,
                })
                local kbProxy = {
                    _raw = luminaKB,
                    _flag = kpFlag,
                    SetValue = function(self, key, mode)
                        if luminaKB and luminaKB.Set then luminaKB.Set(key) end
                        if mode and luminaKB and luminaKB.SetMode then luminaKB.SetMode(mode) end
                    end,
                    OnChanged = function(self, fn)
                        table.insert(kbListeners, fn)
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
        local inputListeners = {}
        local luminaBox = luminaSec:AddTextbox({
            Name = cfg.Text or flag,
            Description = cfg.Tooltip,
            Placeholder = cfg.Placeholder or "",
            Default = cfg.Default or "",
            Numeric = cfg.Numeric or false,
            Flag = flag,
            Callback = function(text)
                if cfg.Callback then pcall(cfg.Callback, text) end
                fireListeners(inputListeners, text)
            end,
        })
        local inputProxy = {
            _raw = luminaBox,
            _flag = flag,
            SetValue = function(self, v)
                if luminaBox and luminaBox.Set then luminaBox.Set(v) end
            end,
            OnChanged = function(self, fn)
                table.insert(inputListeners, fn)
            end,
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

-- icons for the section headers (name -> lucide icon)
local SECTION_ICONS = {
    ["Character"] = "user", ["Phantom Noclip"] = "ghost", ["Other"] = "sliders-horizontal",
    ["Knob Farm"] = "bot", ["Auto Door Skip"] = "door-open", ["Settings"] = "settings",
    ["ESP"] = "eye", ["Camera"] = "camera", ["Entity Notifications"] = "bell", ["Item Notifications"] = "bell-ring",
    ["Pre-Run"] = "rocket", ["Prompts"] = "mouse-pointer-click", ["Exploits"] = "zap", ["Crucifix Everything"] = "cross",
    ["Bypasses"] = "shield-off", ["Removals"] = "eraser", ["Damage"] = "heart-crack", ["Automation"] = "cpu",
    ["Miscellaneous"] = "wrench", ["Fun"] = "party-popper", ["Ladders"] = "arrow-up-down", ["Anticheat"] = "shield",
    ["Visuals"] = "eye", ["Archives"] = "archive", ["Anticheat Bypass"] = "shield", ["Archives Addons"] = "puzzle",
    ["Chams & Boxes"] = "box-select", ["Labels"] = "tag", ["Tracers & Arrows"] = "locate", ["Colors"] = "palette",
    ["Targets"] = "crosshair", ["ESP Preset"] = "wand-sparkles",
    ["Post FX Presets"] = "clapperboard", ["Color Grading"] = "palette", ["Bloom / Rays / Blur"] = "sun", ["Depth of Field / Fog"] = "aperture", ["Weather"] = "cloud-snow", ["Vignette"] = "circle",
    ["Screen Filter"] = "sparkles", ["Aura"] = "wand-sparkles", ["Entity Fun"] = "party-popper", ["HUD"] = "layout-dashboard", ["Model Library"] = "box", ["Model Search"] = "search", ["Swap Options"] = "sliders-horizontal",
}

-- subDefs = { { "Sub name", "icon", { "Groupbox name", ... } }, ... }: every groupbox / tabbox page of the
-- tab is routed to a sub-tab by its name, so the existing code keeps calling AddLeftGroupbox("...") unchanged
local function wrapTab(luminaTab, tabName, subDefs)
    local routes, firstSub = {}, nil
    if subDefs and luminaTab.SubTab then -- older MoroElite builds have no sub-tabs: everything stays on the tab
        for _, def in ipairs(subDefs) do
            local sub = luminaTab:SubTab({ Name = def[1], Icon = def[2] })
            firstSub = firstSub or sub
            for _, group in ipairs(def[3] or {}) do routes[group] = sub end
        end
    end
    local function targetFor(...)
        for i = 1, select("#", ...) do
            local hit = routes[(select(i, ...))]
            if hit then return hit end
        end
        return firstSub or luminaTab
    end
    local function makeSection(target, name, side)
        target:Column(side)
        return target:CreateSection({ Name = name, Icon = SECTION_ICONS[name], Collapsible = true })
    end

    local tabProxy = {
        _raw = luminaTab,
        Name = tabName or (luminaTab and luminaTab.Name) or "Tab",
        OriginalName = tabName or (luminaTab and luminaTab.Name) or "Tab",
        Button = luminaTab and (luminaTab._btn or luminaTab.Button),
        _Button = luminaTab and (luminaTab._btn or luminaTab.Button),
        _Label = luminaTab and luminaTab._label,
    }

    local origActivate = luminaTab and luminaTab._activate
    if origActivate then
        luminaTab._activate = function(...)
            library.ActiveTab = tabProxy
            return origActivate(...)
        end
    end

    function tabProxy:AddLeftGroupbox(name)
        local target = targetFor(name)
        return wrapSection(makeSection(target, name, "left"), target, "left")
    end

    function tabProxy:AddRightGroupbox(name)
        local target = targetFor(name)
        return wrapSection(makeSection(target, name, "right"), target, "right")
    end

    function tabProxy:AddLeftTabbox(name)
        return {
            AddTab = function(_, subName)
                local target = targetFor(subName, name)
                return wrapSection(makeSection(target, subName, "left"), target, "left")
            end
        }
    end

    function tabProxy:AddRightTabbox(name)
        return {
            AddTab = function(_, subName)
                local target = targetFor(subName, name)
                return wrapSection(makeSection(target, subName, "right"), target, "right")
            end
        }
    end

    function tabProxy:SetVisible(vis)
        local btn = luminaTab and (luminaTab._btn or luminaTab.Button)
        if btn then
            btn.Visible = (vis == true or vis == nil)
        end
        if not vis and library.ActiveTab == tabProxy then
            if tabs and tabs.Main and tabs.Main.Show then
                tabs.Main:Show()
            end
        end
    end

    function tabProxy:Show()
        if luminaTab and luminaTab.Select then
            luminaTab:Select()
        elseif luminaTab and luminaTab._activate then
            luminaTab._activate()
        end
        library.ActiveTab = tabProxy
    end

    setmetatable(tabProxy, {
        __index = function(t, k)
            if luminaTab and luminaTab[k] then
                return luminaTab[k]
            end
            return function() end
        end
    })

    return tabProxy
end

function library:CreateWindow(cfg)
    cfg = cfg or {}
    MoroWindow = Lumina:CreateWindow({
        Title = cfg.Title or "MOROLUMINA.lua",
        ToggleKey = cfg.ToggleKeybind or cfg.ToggleKey or Enum.KeyCode.RightShift,
        TeleportFile = cfg.TeleportFile or "Doors.lua",
    })
    library.ScreenGui = MoroWindow.Gui or MoroWindow.ScreenGui

    local winProxy = {
        _raw = MoroWindow,
        _hasSettingsTab = false,
        AddSettingsTab = function(self)
            if self._hasSettingsTab then return end
            self._hasSettingsTab = true
            if MoroWindow and MoroWindow.AddSettingsTab then
                MoroWindow:AddSettingsTab()
            end
        end,
    }

    function winProxy:AddTab(name, icon, subDefs)
        local luminaTab = MoroWindow:CreateTab({
            Name = name,
            Icon = icon or "menu",
        })
        local wrapped = wrapTab(luminaTab, name, subDefs)
        wrapped.Button = luminaTab._btn or luminaTab.Button
        wrapped._Button = luminaTab._btn or luminaTab.Button
        wrapped._Label = luminaTab._label
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
local _unloaded = false
function library:OnUnload(fn)
    table.insert(_unloadCallbacks, fn)
end

local function runUnloadCallbacks()
    if _unloaded then return end
    _unloaded = true
    for _, fn in ipairs(_unloadCallbacks) do
        pcall(fn)
    end
end
-- MoroElite's own "Unload Menu" (and re-running the script) must stop the Doors features too
if Lumina.OnUnload then Lumina:OnUnload(runUnloadCallbacks) end

function library:Unload()
    runUnloadCallbacks()
    if Lumina.Unload then
        pcall(function() Lumina:Unload() end)
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
  function string:split(separator)
    local parts = {}
    local searchStart = 1

    while true do
      local separatorIndex, findResult = string.find(self, separator, searchStart, true)

      if not separatorIndex then
        break
      end

      table.insert(parts, string.sub(self, searchStart, separatorIndex - 1))
      searchStart = findResult + 1
    end

    table.insert(parts, string.sub(self, searchStart))
    return parts
  end
end

if not table.find then
  function table:find(value)
    for n = 1, #self do
      if self[n] == value then
        return n
      end
    end

    return nil
  end
end


local function colorFromHex(hex)
  if typeof(hex) == "string" then
    local success, result = pcall(Color3.fromHex, hex)

    if success then
      return result
    end
  end

  local function parseHexByte(index)
    local success, result = pcall(string.sub, hex, index, index + 1)

    if not success then
      return 0
    end

    local success2, result3 = pcall(tonumber, result, 16)
    return success2 and result3 or 0
  end

  return Color3.fromRGB(parseHexByte(1), parseHexByte(3), parseHexByte(5))
end

local function decodeJson(data)
  if typeof(data) == "string" then
    return data
  end

  local success, result = pcall(function() return httpService:JSONDecode("\"" .. data .. "\"") end)

  if success and typeof(result) == "string" then
    return result
  end

  local success2, result3 = pcall(string.len, data)

  if success2 and result3 > 0 then
    local bytes = {}

    for i = 1, result3 do
      local success3, result4 = pcall(string.byte, data, i)
      local byteValue

      if success3 then
        byteValue = result4
      end

      if byteValue then
        bytes[#bytes + 1] = string.char(byteValue)
      end
    end

    if #bytes > 0 then
      local success3, result4 = pcall(table.concat, bytes)

      if success3 then
        return result4
      end
    end
  end

  return ""
end

local function getTabButton(addTab)
  if type(addTab) ~= "table" then
    return nil
  end

  if addTab.Button and typeof(addTab.Button) == "Instance" then
    return addTab.Button
  end

  if addTab._Button and typeof(addTab._Button) == "Instance" then
    return addTab._Button
  end

  return nil
end

local function getTabLabel(addTab)
  local object = getTabButton(addTab)

  if object then
    local success, result = pcall(function() return object:FindFirstChild("TextLabel", true) end)

    if success and result then
      return result
    end
  end

  if addTab._Label and typeof(addTab._Label) == "Instance" then
    return addTab._Label
  end

  return nil
end

local function isTabActive(tab)
  if not tab then
    return false
  end

  if library.ActiveTab == tab then
    return true
  end

  local activeTab = library.ActiveTab

  if type(activeTab) == "string" then
    if tab.Name == activeTab then
      return true
    end

    if tab.OriginalName == activeTab then
      return true
    end
  end

  return false
end
local unusedFlag = 1

if game.PlaceId ~= 6516141723 and game.PlaceId ~= 6839171747 and game.PlaceId ~= 110258689672370
  and game.PlaceId ~= 10549820578 then
  return
end

function TableClear(list)
  for key in pairs(list) do
    list[key] = nil
  end
end

function TableFind(list, item)
  for i = 1, #list do
    if list[i] == item then
      return i
    end
  end

  return nil
end

-- =====================================================================
--                  MOROESP — собственный ESP-движок
--  Боксы (Corners / Full / Rounded Glow / 3D Box), хамсы (Highlight),
--  пилюли с именем и дистанцией, полоска HP, скелет, трейсеры, стрелки.
--  API совместим со старой библиотекой: AddESP / RemoveESP / Set*.
-- =====================================================================
local loader -- локалов в этом файле много: движок живёт внутри do-блока
do
local function createESPEngine()
    local Lib = {
        MaxDistance = 250,
        ShowESPText = true,
        Tracers = false,
        TracersEnabled = {},
        ObjectMaxDistance = {},
        ColorTable = {},
    }

    -- настройки отображения (меню пишет сюда через Lib.Settings или Set*)
    local S = {
        box = "Rounded Glow", boxThick = 1.6, boxFill = 0.88,
        chams = "Flat", chamLimit = 31,
        nameStyle = "Pill", textSize = 15, font = Enum.Font.GothamBold, showDist = true,
        hpBar = true, hpText = true, skeleton = true, headDot = true, lookLine = true,
        rainbow = false, distFade = true,
        fillT = 0.6, outlineT = 0, textT = 0, textOutlineT = 0.4,
        matchColors = true, outlineColor = Color3.new(1, 1, 1),
        fadeTime = 0,
        tracerFrom = "Bottom", tracerThick = 0.75,
        arrows = false, arrowRadius = 250,
    }
    Lib.Settings = S

    local entries = {}
    local alive = true
    local cam = workspace.CurrentCamera
    local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

    -- ---------------------------------------------------------------- GUI
    local parent = (gethui and gethui()) or coreGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "MoroESP"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 20
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
    gui.Parent = parent

    local layer = Instance.new("Frame")
    layer.Name = "Layer"
    layer.BackgroundTransparency = 1
    layer.Size = UDim2.fromScale(1, 1)
    layer.Parent = gui

    local chamFolder = Instance.new("Folder")
    chamFolder.Name = "MoroESPChams"
    chamFolder.Parent = parent

    -- --------------------------------------------------------- UI helpers
    local function newFrame(par, props)
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.BackgroundColor3 = WHITE
        f.Visible = false
        for k, v in pairs(props or {}) do f[k] = v end
        f.Parent = par
        return f
    end
    local function newLine(par) return newFrame(par, { AnchorPoint = Vector2.new(0.5, 0.5) }) end
    local function setLine(f, a, b, thick, col, transp)
        local d = b - a
        f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
        f.Size = UDim2.fromOffset(d.Magnitude, thick)
        f.Rotation = math.deg(math.atan2(d.Y, d.X))
        f.BackgroundColor3 = col
        f.BackgroundTransparency = transp
        f.Visible = true
    end
    local function addStroke(f, thick, col, transp)
        local s = Instance.new("UIStroke")
        s.Thickness, s.Color, s.Transparency = thick, col, transp or 0
        s.Parent = f
        return s
    end
    local function addCorner(f, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = r
        c.Parent = f
        return c
    end
    local function newText(par, size)
        local t = Instance.new("TextLabel")
        t.BackgroundTransparency = 1
        t.Font = S.font
        t.TextSize = size or 13
        t.RichText = true
        t.TextColor3 = WHITE
        t.Visible = false
        t.Parent = par
        t.TextStrokeTransparency = 1
        local st = addStroke(t, 1, BLACK, 0.4)
        return t, st
    end
    local function esc(s)
        return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
    end
    local function hex(c)
        return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end
    local function rainbowAt(t, off) return Color3.fromHSV((t * 0.3 + off) % 1, 0.8, 1) end

    local CUBE_EDGES = { { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 }, { 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }
    local BONES_R15 = {
        { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
        { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
        { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
        { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
    }
    local BONES_R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }

    -- ------------------------------------------------------------ entries
    local function buildUI(e)
        local u = {}
        u.root = newFrame(layer, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = true })
        u.glow = newFrame(u.root, { BackgroundTransparency = 1 })
        addCorner(u.glow, UDim.new(0, 12))
        u.glowStroke = addStroke(u.glow, 5, WHITE, 0.8)
        u.boxFull = newFrame(u.root, {})
        u.boxCorner = addCorner(u.boxFull, UDim.new(0, 0))
        u.boxStroke = addStroke(u.boxFull, 1.5, WHITE, 0)
        u.fillGrad = Instance.new("UIGradient")
        u.fillGrad.Rotation = 90
        u.fillGrad.Parent = u.boxFull
        u.corners = {}
        for i = 1, 8 do u.corners[i] = newFrame(u.root, {}) end
        u.cube, u.bones = {}, {}
        u.hpBg = newFrame(u.root, { BackgroundColor3 = BLACK, BackgroundTransparency = 0.45 })
        u.hpFill = newFrame(u.hpBg, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Visible = true })
        u.pill = newFrame(u.root, { BackgroundColor3 = Color3.fromRGB(14, 14, 20), BackgroundTransparency = 0.15 })
        addCorner(u.pill, UDim.new(0, 7))
        u.pillStroke = addStroke(u.pill, 1, WHITE, 0.35)
        u.accent = newFrame(u.pill, { Position = UDim2.new(0, 4, 0, 4), Size = UDim2.new(0, 3, 1, -8), Visible = true })
        addCorner(u.accent, UDim.new(1, 0))
        u.nameT, u.nameS = newText(u.pill, 13)
        u.nameT.Visible = true
        u.nameT.TextXAlignment = Enum.TextXAlignment.Left
        u.nameT.Position = UDim2.fromOffset(13, 0)
        u.nameT.Size = UDim2.new(1, -16, 1, 0)
        u.plainT, u.plainS = newText(u.root, 13)
        u.plainT.AnchorPoint = Vector2.new(0.5, 1)
        u.plainT.Size = UDim2.fromOffset(260, 18)
        u.infoT, u.infoS = newText(u.root, 12)
        u.infoT.AnchorPoint = Vector2.new(0.5, 0)
        u.infoT.Size = UDim2.fromOffset(260, 16)
        u.tracer = newLine(u.root)
        u.lookLine = newLine(u.root)
        u.dot = newFrame(u.root, { AnchorPoint = Vector2.new(0.5, 0.5) })
        addCorner(u.dot, UDim.new(1, 0))
        addStroke(u.dot, 1, BLACK, 0.2)
        u.arrow = newText(layer, 20)
        u.arrow.Text = "▲"
        u.arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        u.arrow.Size = UDim2.fromOffset(26, 26)
        e.ui = u
    end

    local function destroyUI(e)
        local u = e.ui
        if u then
            pcall(function() u.root:Destroy() end)
            pcall(function() u.arrow:Destroy() end)
            e.ui = nil
        end
        if e.hl then
            pcall(function() e.hl:Destroy() end)
            e.hl = nil
        end
    end

    local function hideAll(e)
        local u = e.ui
        if u then
            u.root.Visible = false
            u.arrow.Visible = false
        end
        if e.hl then e.hl.Enabled = false end
    end

    local function newEntry(obj)
        local e = {
            obj = obj, text = "", color = WHITE, alpha = 0, target = 1,
            hue = math.random(), nextBB = 0, wantHL = true,
            isPart = obj:IsA("BasePart"), isModel = obj:IsA("Model"),
        }
        -- HP, скелет, точка на голове и линия взгляда рисуются только у игроков
        if e.isModel and players:GetPlayerFromCharacter(obj) then
            e.isPlayer = true
            e.hum = obj:FindFirstChildOfClass("Humanoid")
        end
        return e
    end

    local function refreshBox(e)
        local o = e.obj
        if e.isPart then
            e.size = o.Size
            return true
        elseif e.isModel then
            local success, result, result3 = pcall(o.GetBoundingBox, o)
            if success and result3 then
                e.size = Vector3.new(math.max(result3.X, 0.5), math.max(result3.Y, 0.5), math.max(result3.Z, 0.5))
                e.off = o:GetPivot():ToObjectSpace(result)
                return true
            end
        end
        return false
    end

    local function worldCF(e)
        if e.isPart then return e.obj.CFrame end
        return e.obj:GetPivot() * e.off
    end

    -- Highlight (хамсы) ---------------------------------------------------
    local function applyChams(e, col, t, tr)
        local style = S.chams
        local want = style ~= "Off" and e.wantHL
        if not want then
            if e.hl then e.hl:Destroy() e.hl = nil end
            return
        end
        if not e.hl then
            local hl = Instance.new("Highlight")
            hl.Adornee = e.obj
            hl.Parent = chamFolder
            e.hl = hl
        end
        local hl = e.hl
        hl.Enabled = true
        hl.DepthMode = style == "Visible Only" and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
        local fill, out = col, (S.matchColors and col or S.outlineColor)
        local fillT = S.fillT
        if style == "Glow" then
            fillT = math.clamp(S.fillT - 0.3, 0.1, 1)
            out = col:Lerp(WHITE, 0.5)
        elseif style == "Pulse" then
            fillT = math.clamp(S.fillT + math.sin(t * 3 + e.hue * 6) * 0.2, 0, 1)
        elseif style == "Rainbow" then
            fill = rainbowAt(t, e.hue)
            out = S.matchColors and fill or S.outlineColor
        elseif style == "Outline" then
            fillT = 1
        end
        hl.FillColor, hl.OutlineColor = fill, out
        hl.FillTransparency = tr(fillT)
        hl.OutlineTransparency = tr(S.outlineT)
    end

    -- рендер одного объекта -------------------------------------------------
    local function renderEntry(e, t, dt, camPos, vs, center)
        local o = e.obj
        if not o.Parent then e.dead = true return end
        if not e.size or t >= e.nextBB then
            if not refreshBox(e) then hideAll(e) return end
            e.nextBB = t + 0.25 + (e.hue * 0.1)
        end
        local cf = worldCF(e)
        local dist = (cf.Position - camPos).Magnitude
        local maxD = Lib.ObjectMaxDistance[o] or Lib.MaxDistance
        e.dist = dist

        -- fade in / out
        if S.fadeTime > 0 then
            local step = dt / S.fadeTime
            if e.alpha < e.target then e.alpha = math.min(e.alpha + step, e.target)
            elseif e.alpha > e.target then e.alpha = math.max(e.alpha - step, e.target) end
        else
            e.alpha = e.target
        end
        if e.target == 0 and e.alpha <= 0 then e.dead = true return end

        if dist > maxD then e.wantHL = false hideAll(e) return end
        if not e.ui then buildUI(e) end
        local u = e.ui

        local col = e.color
        if S.rainbow then col = rainbowAt(t, e.hue) end
        local df = S.distFade and math.clamp(dist / maxD, 0, 1) * 0.55 or 0
        local function tr(base) return 1 - (1 - base) * e.alpha * (1 - df) end

        applyChams(e, col, t, tr)

        -- проекция 8 углов
        local half = e.size / 2
        local pts, allIn, minX, minY, maxX, maxY, any = {}, true, math.huge, math.huge, -math.huge, -math.huge, false
        local i = 0
        for sx = -1, 1, 2 do
            for sy = -1, 1, 2 do
                for sz = -1, 1, 2 do
                    i = i + 1
                    local sp = cam:WorldToViewportPoint(cf * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
                    pts[i] = Vector2.new(sp.X, sp.Y)
                    if sp.Z > 0 then
                        any = true
                        minX, maxX = math.min(minX, sp.X), math.max(maxX, sp.X)
                        minY, maxY = math.min(minY, sp.Y), math.max(maxY, sp.Y)
                    else
                        allIn = false
                    end
                end
            end
        end
        local cp = cam:WorldToViewportPoint(cf.Position)
        local onScreen = any and cp.Z > 0 and maxX > -50 and minX < vs.X + 50 and maxY > -50 and minY < vs.Y + 50

        if not onScreen then
            u.root.Visible = false
            if S.arrows and e.alpha > 0 then
                local dir = Vector2.new(cp.X, cp.Y) - center
                if cp.Z < 0 then dir = -dir end
                if dir.Magnitude < 1 then dir = Vector2.new(0, 1) end
                local d = dir.Unit
                local rad = math.min(S.arrowRadius, math.min(vs.X, vs.Y) / 2 - 20)
                u.arrow.Position = UDim2.fromOffset(center.X + d.X * rad, center.Y + d.Y * rad)
                u.arrow.Rotation = math.deg(math.atan2(d.Y, d.X)) + 90
                u.arrow.TextColor3 = col
                u.arrow.TextTransparency = tr(S.textT)
                u.arrow.TextSize = 16 + (1 - math.clamp(dist / maxD, 0, 1)) * 10
                u.arrow.Visible = true
            else
                u.arrow.Visible = false
            end
            return
        end
        u.arrow.Visible = false
        u.root.Visible = true

        local x, y = minX, minY
        local w, h = math.max(maxX - minX, 4), math.max(maxY - minY, 4)
        local th = S.boxThick

        -- бокс
        u.boxFull.Visible, u.glow.Visible = false, false
        for _, f in ipairs(u.corners) do f.Visible = false end
        for _, f in ipairs(u.cube) do f.Visible = false end
        local style = S.box
        if style == "Full" or style == "Rounded Glow" then
            u.boxFull.Visible = true
            u.boxFull.Position, u.boxFull.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
            u.boxFull.BackgroundTransparency = tr(S.boxFill)
            u.fillGrad.Color = ColorSequence.new(col, col:Lerp(BLACK, 0.6))
            u.boxStroke.Thickness, u.boxStroke.Color, u.boxStroke.Transparency = th, col, tr(0)
            u.boxCorner.CornerRadius = UDim.new(0, style == "Rounded Glow" and 10 or 0)
            if style == "Rounded Glow" then
                u.glow.Visible = true
                u.glow.Position, u.glow.Size = UDim2.fromOffset(x - 2, y - 2), UDim2.fromOffset(w + 4, h + 4)
                u.glowStroke.Color, u.glowStroke.Transparency = col, tr(0.72)
            end
        elseif style == "Corners" then
            local L = math.max(math.min(w, h) * 0.28, 6)
            local defs = {
                { x, y, L, th }, { x, y, th, L }, { x + w - L, y, L, th }, { x + w - th, y, th, L },
                { x, y + h - th, L, th }, { x, y + h - L, th, L }, { x + w - L, y + h - th, L, th }, { x + w - th, y + h - L, th, L },
            }
            for k, d in ipairs(defs) do
                local f = u.corners[k]
                f.Position, f.Size = UDim2.fromOffset(d[1], d[2]), UDim2.fromOffset(d[3], d[4])
                f.BackgroundColor3, f.BackgroundTransparency, f.Visible = col, tr(0), true
            end
        elseif style == "3D Box" and allIn then
            for k, ed in ipairs(CUBE_EDGES) do
                local f = u.cube[k]
                if not f then f = newLine(u.root) u.cube[k] = f end
                setLine(f, pts[ed[1]], pts[ed[2]], th, col, tr(0))
            end
        end

        -- полоска HP
        local hum = e.hum
        if hum and not hum.Parent then hum = nil e.hum = nil end
        if S.hpBar and hum and hum.MaxHealth > 0 then
            local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            u.hpBg.Visible = true
            u.hpBg.Position, u.hpBg.Size = UDim2.fromOffset(x - 6, y), UDim2.fromOffset(3, h)
            u.hpBg.BackgroundTransparency = tr(0.45)
            u.hpFill.Size = UDim2.fromScale(1, ratio)
            u.hpFill.BackgroundColor3 = Color3.fromRGB(255, 70, 70):Lerp(Color3.fromRGB(80, 235, 130), ratio)
            u.hpFill.BackgroundTransparency = tr(0)
        else
            u.hpBg.Visible = false
        end

        -- подписи
        u.pill.Visible, u.plainT.Visible, u.infoT.Visible = false, false, false
        if Lib.ShowESPText ~= false and (e.text ~= "" or S.showDist) then
            local distTxt = S.showDist and string.format("%dm", math.floor(dist)) or nil
            local ts = S.textSize
            if S.nameStyle == "Pill" then
                local main = esc(e.text)
                if distTxt then main = main .. (main ~= "" and '  <font color="#9aa0b4">' or '<font color="#9aa0b4">') .. distTxt .. "</font>" end
                u.nameT.Font = S.font
                u.nameT.TextSize = ts
                u.nameT.Text = main
                u.nameT.TextTransparency = tr(S.textT)
                u.nameS.Transparency = tr(S.textOutlineT)
                local pw = u.nameT.TextBounds.X + 22
                local ph = ts + 10
                u.pill.Size = UDim2.fromOffset(pw, ph)
                u.pill.Position = UDim2.fromOffset(x + w / 2 - pw / 2, y - ph - 5)
                u.pill.BackgroundTransparency = tr(0.15)
                u.pill.Visible = true
                u.accent.BackgroundColor3 = col
                u.accent.BackgroundTransparency = tr(0)
                u.pillStroke.Color, u.pillStroke.Transparency = col, tr(0.35)
            else
                local main = '<font color="' .. hex(col) .. '">' .. esc(e.text) .. "</font>"
                if distTxt then main = main .. '  <font color="#c8ccda">' .. distTxt .. "</font>" end
                u.plainT.Font = S.font
                u.plainT.TextSize = ts
                u.plainT.Text = main
                u.plainT.TextTransparency = tr(S.textT)
                u.plainS.Transparency = tr(S.textOutlineT)
                u.plainT.Position = UDim2.fromOffset(x + w / 2, y - 3)
                u.plainT.Visible = true
            end
            if S.hpText and hum and hum.MaxHealth > 0 and hum.Health > 0 then
                u.infoT.Font = S.font
                u.infoT.TextSize = math.max(ts - 2, 9)
                u.infoT.Text = math.floor(hum.Health) .. " hp"
                u.infoT.TextTransparency = tr(S.textT)
                u.infoS.Transparency = tr(S.textOutlineT)
                u.infoT.Position = UDim2.fromOffset(x + w / 2, y + h + 3)
                u.infoT.Visible = true
            end
        end

        -- скелет / точка на голове / линия взгляда (только персонажи)
        local char = e.isModel and hum and o or nil
        if S.skeleton and char then
            local bones = char:FindFirstChild("UpperTorso") and BONES_R15 or BONES_R6
            for k, b in ipairs(bones) do
                local f = u.bones[k]
                if not f then f = newLine(u.root) u.bones[k] = f end
                local child, child2 = char:FindFirstChild(b[1]), char:FindFirstChild(b[2])
                if child and child2 then
                    local screenPoint, screenPoint2 = cam:WorldToViewportPoint(child.Position), cam:WorldToViewportPoint(child2.Position)
                    if screenPoint.Z > 0 and screenPoint2.Z > 0 then
                        setLine(f, Vector2.new(screenPoint.X, screenPoint.Y), Vector2.new(screenPoint2.X, screenPoint2.Y), 1.4, col, tr(0))
                    else
                        f.Visible = false
                    end
                else
                    f.Visible = false
                end
            end
        else
            for _, f in ipairs(u.bones) do f.Visible = false end
        end
        local head = char and char:FindFirstChild("Head")
        if S.headDot and head then
            local sp = cam:WorldToViewportPoint(head.Position)
            local d = math.clamp(h * 0.13, 5, 16)
            u.dot.Size = UDim2.fromOffset(d, d)
            u.dot.Position = UDim2.fromOffset(sp.X, sp.Y)
            u.dot.BackgroundColor3, u.dot.BackgroundTransparency = col, tr(0)
            u.dot.Visible = sp.Z > 0
        else
            u.dot.Visible = false
        end
        if S.lookLine and head then
            local a = cam:WorldToViewportPoint(head.Position)
            local b = cam:WorldToViewportPoint(head.Position + head.CFrame.LookVector * 7)
            if a.Z > 0 and b.Z > 0 then
                setLine(u.lookLine, Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y), 1.6, col, tr(0.15))
            else
                u.lookLine.Visible = false
            end
        else
            u.lookLine.Visible = false
        end

        -- трейсер
        if (Lib.Tracers == true or Lib.TracersEnabled[o]) and cp.Z > 0 then
            local from
            if S.tracerFrom == "Center" then from = center
            elseif S.tracerFrom == "Top" then from = Vector2.new(vs.X / 2, 0)
            else from = Vector2.new(vs.X / 2, vs.Y) end
            setLine(u.tracer, from, Vector2.new(cp.X, cp.Y), math.max(S.tracerThick, 0.5) + 0.5, col, tr(0.2))
        else
            u.tracer.Visible = false
        end
    end

    -- ближайшим N объектам даём Highlight (Roblox рисует не больше ~31)
    local lastRank = 0
    local function rankChams(camPos)
        local list = {}
        for _, e in pairs(entries) do
            if e.size then list[#list + 1] = e end
        end
        table.sort(list, function(a, b) return (a.dist or 1e9) < (b.dist or 1e9) end)
        local limit = math.min(S.chamLimit, 31)
        for rank, e in ipairs(list) do e.wantHL = rank <= limit end
    end

    local conn
    conn = runService.RenderStepped:Connect(function(dt)
        cam = workspace.CurrentCamera
        if not cam or not alive then return end
        local t = os.clock()
        local vs = cam.ViewportSize
        local center = vs / 2
        local camPos = cam.CFrame.Position
        if t - lastRank > 0.2 then
            lastRank = t
            pcall(rankChams, camPos)
        end
        local dead
        for obj, e in pairs(entries) do
            local ok = pcall(renderEntry, e, t, dt, camPos, vs, center)
            if not ok then hideAll(e) end
            if e.dead then
                dead = dead or {}
                dead[#dead + 1] = obj
            end
        end
        if dead then
            for _, obj in ipairs(dead) do
                local e = entries[obj]
                if e then destroyUI(e) end
                entries[obj] = nil
                Lib.ColorTable[obj] = nil
                Lib.TracersEnabled[obj] = nil
            end
        end
    end)

    -- ---------------------------------------------------------------- API
    function Lib:AddESP(data)
        local obj = data and data.Object
        if typeof(obj) ~= "Instance" then return end
        local e = entries[obj]
        if not e then
            e = newEntry(obj)
            entries[obj] = e
        end
        e.dead, e.target = nil, 1
        e.text = data.Text or ""
        e.color = data.Color or WHITE
        Lib.ColorTable[obj] = e.color
        return e
    end

    function Lib:RemoveESP(obj)
        local e = entries[obj]
        if not e then return end
        if S.fadeTime > 0 and e.ui then
            e.target = 0
        else
            destroyUI(e)
            entries[obj] = nil
            Lib.ColorTable[obj] = nil
        end
    end

    function Lib:UpdateObjectColor(obj, col)
        local e = entries[obj]
        if e then e.color = col end
        if e or Lib.ColorTable[obj] then Lib.ColorTable[obj] = col end
    end

    function Lib:SetTracersEnabled(obj, value)
        Lib.TracersEnabled[obj] = value and true or nil
    end

    function Lib:UpdateObjectText(obj, text)
        local e = entries[obj]
        if e then e.text = text or "" end
    end

    function Lib:SetSetting(key, value) S[key] = value end
    function Lib:SetRainbow(v) S.rainbow = v and true or false end
    function Lib:SetTracerOrigin(v) S.tracerFrom = v or "Bottom" end
    function Lib:SetShowDistance(v) S.showDist = v and true or false end
    function Lib:SetTextSize(v) S.textSize = v end
    function Lib:SetFont(v) S.font = v or Enum.Font.GothamBold end
    function Lib:SetRenderLimit(v) S.chamLimit = v end
    function Lib:SetFillTransparency(v) S.fillT = v end
    function Lib:SetOutlineTransparency(v) S.outlineT = v end
    function Lib:SetTextTransparency(v) S.textT = v end
    function Lib:SetTextOutlineTransparency(v) S.textOutlineT = v end
    function Lib:SetFadeTime(v) S.fadeTime = v or 0 end
    function Lib:SetArrows(v) S.arrows = v and true or false end
    function Lib:SetArrowRadius(v) S.arrowRadius = v end
    function Lib:SetTracerSize(v) S.tracerThick = v end
    function Lib:SetMatchColors(v) S.matchColors = v and true or false end
    function Lib:SetOutlineColor(v) S.outlineColor = v or WHITE end

    function Lib:Unload()
        if not alive then return end
        alive = false
        if conn then conn:Disconnect() end
        for _, e in pairs(entries) do destroyUI(e) end
        table.clear(entries)
        pcall(function() gui:Destroy() end)
        pcall(function() chamFolder:Destroy() end)
    end

    return Lib
end

local success, result = pcall(createESPEngine)
if success and result then
    loader = result
else
    warn("[Moro] ESP engine failed: " .. tostring(result))
    loader = {
        ObjectMaxDistance = {}, TracersEnabled = {}, ColorTable = {}, Settings = {},
        AddESP = function() end, RemoveESP = function() end, Unload = function() end,
    }
    setmetatable(loader, { __index = function() return function() end end })
end
end

SoundService = soundService
Lighting = lighting
TextChatService = textChatService
CoreGui = coreGui
VirtualUser = virtualUser
ProximityPromptService = proximityPromptService
TweenService = tweenService
ContextActionService = contextActionService
VirtualInputManager = virtualInputManager
local localPlayer = players.LocalPlayer
local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
local currentCamera = workspace.CurrentCamera
local currentRooms = workspace:FindFirstChild("CurrentRooms")

_CameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
  currentCamera = workspace.CurrentCamera
end)

PartProperties = {}
local latestRoomValue

local function trackLatestRoom()
  local latestRoom = replicatedStorage:FindFirstChild("GameData")
    and replicatedStorage.GameData:FindFirstChild("LatestRoom")

  if not latestRoom then
    latestRoom = replicatedStorage:FindFirstChild("FloorReplicated")
      and replicatedStorage.FloorReplicated:FindFirstChild("LatestRoom")
  end

  if latestRoom and latestRoom ~= latestRoomValue then
    latestRoomValue = latestRoom

    if latestRoomValue.Value then
      localPlayer:SetAttribute("CurrentRoom", latestRoomValue.Value)
    end

    latestRoomValue.Changed:Connect(function(value)
      localPlayer:SetAttribute("CurrentRoom", value)

      if Toggles and Toggles.AmbientToggle and Toggles.AmbientToggle.Value then
        TweenService:Create(Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
          Ambient = Options.AmbientColor.Value, }):Play()
      end
    end)
  end

  return latestRoom
end

trackLatestRoom()

local function watchGameData(gameData)
  gameData.ChildAdded:Connect(function(child)
    if child.Name == "LatestRoom" then
      trackLatestRoom()
    end
  end)

  if gameData:FindFirstChild("LatestRoom") then
    trackLatestRoom()
  end
end

local gameData = replicatedStorage:FindFirstChild("GameData")

if gameData then
  watchGameData(gameData)
else
  replicatedStorage.ChildAdded:Connect(function(child)
    if child.Name == "GameData" then
      watchGameData(child)
    end
  end)
end

do
  local floorReplicated = replicatedStorage:FindFirstChild("FloorReplicated")

  if floorReplicated then
    floorReplicated.ChildAdded:Connect(function(child)
      if child.Name == "LatestRoom" then
        trackLatestRoom()
      end
    end)
  end
end

local toggles = library.Toggles
local options = library.Options

local threatState = {
  Sunk = false, ActiveThreats = {}, ThreatNames = {
    RushMoving = true, Rush = true, AmbushMoving = true, Ambush = true, A60 = true, A60Moving = true, ["A-60"] = true, A120 = true, A120Moving = true, ["A-120"] = true, BackdoorRush = true, BlitzMoving = true, Blitz = true, ["RNIUSHCG=="] = true, GlitchRush = true, AR0xMBUSH = true, GlitchAmbush = true, FrozenAmbush = true, CustomEntity = true, BashMoving = true, }, }

-- Угроза «близко»: сзади ближе 100 стадов, спереди (по взгляду бота) ближе 50. scale > 1 даёт запас от мигания.
-- Расстояние плоское (XZ): Rush/Ambush бегут по этажу, высота комнаты в счёт не идёт.
threatState.IsClose = function(scale)
  scale = scale or 1
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not root then return false end
  local look = root.CFrame.LookVector
  local forward = Vector3.new(look.X, 0, look.Z)
  forward = forward.Magnitude > 0.01 and forward.Unit or Vector3.new(0, 0, -1)
  local checked = {}
  local function near(obj)
    if not obj or not obj.Parent or checked[obj] then return false end
    checked[obj] = true
    local ok, pivot = pcall(function() return obj:GetPivot().Position end)
    if not ok or not pivot then return true end
    local offset = Vector3.new(pivot.X - root.Position.X, 0, pivot.Z - root.Position.Z)
    return offset.Magnitude < ((offset:Dot(forward) > 0) and 50 or 100) * scale
  end
  for threat, active in pairs(threatState.ActiveThreats) do
    if active and near(threat) then return true end
  end
  for name in pairs(threatState.ThreatNames) do
    if near(workspace:FindFirstChild(name)) then return true end
  end
  return false
end

local function HasActiveThreat()
  if threatState and threatState.ActiveThreats then
    for threat, active in pairs(threatState.ActiveThreats) do
      if active and threat and threat.Parent then
        return true, threat
      end
    end
  end

  local threatCheckList = {
    "RushMoving", "Rush", "AmbushMoving", "Ambush", "BlitzMoving", "Blitz",
    "A60Moving", "A60", "A-60", "A120Moving", "A-120", "BackdoorRush",
    "GlitchRush", "GlitchAmbush", "FrozenAmbush", "BashMoving"
  }

  for _, n in ipairs(threatCheckList) do
    local obj = workspace:FindFirstChild(n)
    if obj then return true, obj end
  end

  local curRooms = workspace:FindFirstChild("CurrentRooms")
  if curRooms then
    for _, n in ipairs(threatCheckList) do
      local obj = curRooms:FindFirstChild(n, true)
      if obj then return true, obj end
    end
  end

  return false, nil
end

local function getGodmodeMode()
  local value = options.GodmodeMethod and options.GodmodeMethod.Value

  if typeof(value) == "number" then
    return value == 2 and 2 or 1
  end

  if value == "On entity spawn" then
    return 2
  end

  return 1
end

-- Годмод «топит» персонажа на 2,3 стада в пол. На лестнице ступени оказываются выше этой точки, и бот
-- проваливается сквозь неё в пустоту. Поэтому на лестнице (и пока не сойдёт с неё) не топим.
local function isStandingOnStairs()
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not root then return false end
  local params = RaycastParams.new()
  params.FilterType = Enum.RaycastFilterType.Exclude
  params.FilterDescendantsInstances = { char }
  local hit = workspace:Raycast(root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
  local part = hit and hit.Instance
  if not part then return false end
  local name = part.Name:lower()
  local parent = part.Parent and part.Parent.Name:lower() or ""
  return (name:find("stair", 1, true) or name:find("step", 1, true)
    or parent:find("stair", 1, true) or parent:find("step", 1, true)) ~= nil
end

local function isGodmodeActive()
  if KnobFarm and KnobFarm.Active then
    if KnobFarm.DisableGodmodeForBoss then
      return false
    end
    if KnobFarm.PassedFirstDoor then
      -- Уже утоплены — держим годмод до конца угрозы: утопленный персонаж находится внутри ступени, и проверка
      -- «на лестнице» мигала бы каждый кадр (годмод включался и выключался прямо под Rush).
      if not HasActiveThreat() then return false end
      -- Бот сам разрешил подъём по лестнице (угроза далеко): на это время не топимся, иначе провалится сквозь ступени
      if KnobFarm.StairsPass and tick() - KnobFarm.StairsPass < 0.6 then return false end
      return threatState.Sunk or not isStandingOnStairs()
    end
    return false
  end

  if not (toggles and toggles.Godmode and toggles.Godmode.Value) then
    return false
  end

  if KnobFarm and KnobFarm.ThreatGodmode then
    return true
  end

  if getGodmodeMode() == 1 then
    return true
  end

  if getGodmodeMode() == 2 then
    return HasActiveThreat()
  end

  return false
end

local function trackThreat(descendant)
  if not descendant or not threatState.ThreatNames[descendant.Name] then
    return
  end

  if threatState.ActiveThreats[descendant] then
    return
  end

  threatState.ActiveThreats[descendant] = true

  descendant.AncestryChanged:Connect(function(_, parent)
    if not parent then
      threatState.ActiveThreats[descendant] = nil
    end
  end)
end

workspace.DescendantAdded:Connect(trackThreat)

for _, descendant in workspace:GetDescendants() do
  trackThreat(descendant)
end

local character, humanoidRootPart

local function setupCustomPhysics()
  if not character or not humanoidRootPart then
    return
  end

  TableClear(PartProperties)

  CustomPhysics = PhysicalProperties.new(
    100, humanoidRootPart.CustomPhysicalProperties.Friction, humanoidRootPart.CustomPhysicalProperties.Elasticity, humanoidRootPart.CustomPhysicalProperties.FrictionWeight, humanoidRootPart.CustomPhysicalProperties.ElasticityWeight
  )

  for _, descendant in character:GetDescendants() do
    if descendant:IsA("BasePart") then
      PartProperties[descendant] = descendant.CustomPhysicalProperties

      if toggles.RemoveAcceleration and toggles.RemoveAcceleration.Value then
        descendant.CustomPhysicalProperties = CustomPhysics
      end
    end
  end
end

local function detectFloor()
  if workspace:FindFirstChild("Lobby") then
    return "Lobby"
  end

  local gameData2 = replicatedStorage:FindFirstChild("GameData")

  if not gameData2 then
    return "Lobby"
  end

  local floor = gameData2:FindFirstChild("Floor")

  if not floor then
    return "Lobby"
  end

  local text = tostring(floor.Value)

  if text == "" then
    return "Lobby"
  end

  if text == "Hotel" then
    local remotesFolder = replicatedStorage:FindFirstChild("RemotesFolder")
      or replicatedStorage:FindFirstChild("Bricks")

    if remotesFolder and remotesFolder.Name == "Bricks" then
      return "OldHotel"
    end
  end

  return text
end

CurrentFloor = nil
OldJump = false
OldSlide = false

local function applyCharacterAttributes()
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

local humanoid, collision, collisionPart, featureState

local function setupCharacter()
  character = localPlayer.Character

  if character then
    humanoid = character:FindFirstChildOfClass("Humanoid")
    humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

    collision = character:FindFirstChild("Collision")
      or character:FindFirstChild("CollisionPart")

    collisionPart = character:FindFirstChild("CollisionPart")
      or character:FindFirstChild("Collision")

    setupCustomPhysics()
    applyCharacterAttributes()

    if featureState then
      local lowerTorso = character:FindFirstChild("LowerTorso")
      local root = lowerTorso and lowerTorso:FindFirstChild("Root")

      if root then
        featureState.OriginalC1 = root.C1
      end

      threatState.Sunk = false
    end
  end
end

FakePrompts = {}
Connections = {}
local remotesFolder

do
  local connect, anticheatConnection2
  local anticheatConnection3

  function SetupCharacterAnticheat()
    if not character then
      return
    end

    if connect then
      connect:Disconnect()
      connect = nil
    end

    if anticheatConnection2 then
      anticheatConnection2:Disconnect()
      anticheatConnection2 = nil
    end

    if anticheatConnection3 then
      anticheatConnection3:Disconnect()
      anticheatConnection3 = nil
    end

    connect = character:GetAttributeChangedSignal("Climbing"):Connect(function()
      if character:GetAttribute("Climbing") == true and toggles.DisableAnticheat.Value
        and not featureState.AnticheatDisabled then
        task.wait(0.25)
        character:SetAttribute("Climbing", false)
        featureState.AnticheatDisabled = true

        library:Notify({
          Title = "Disabled anticheat", Description = "Re-enables after cutscenes or halt", Time = 5, })
      end
    end)

    if remotesFolder then
      anticheatConnection2 = remotesFolder:WaitForChild("Cutscene").OnClientEvent:Connect(function(arg1)
        if featureState.AnticheatDisabled and not arg1:find("SewerSeek") then
          featureState.AnticheatDisabled = false

          library:Notify({
            Title = "Anticheat re-enabled", Description = "Interact with a ladder for re-disabling", Time = 5, })
        end
      end)

      anticheatConnection3 = remotesFolder:WaitForChild("UseEnemyModule").OnClientEvent:Connect(function(arg1)
        if arg1 == "Void" or arg1 == "Glitch" then
          if featureState.AnticheatDisabled then
            featureState.AnticheatDisabled = false

            library:Notify({
              Title = "Anticheat re-enabled", Description = "Interact with a ladder for re-disabling", Time = 5, })
          end

          if latestRoomValue then
            localPlayer:SetAttribute("CurrentRoom", latestRoomValue.Value)
          end
        end
      end)
    end

    character:SetAttribute("Climbing", nil)
  end
end

setupCharacter()
local refreshWalkspeed, refreshFly, refreshInfiniteJump, refreshNoclip, refreshThirdPerson, refreshPhase

localPlayer.CharacterAdded:Connect(function()
  task.wait(0.5)
  setupCharacter()
  refreshWalkspeed()

  if toggles.FlyToggle.Value then
    refreshFly()
  end

  if toggles.ArchiveChairFly.Value
    or toggles.StairwellChairFly and toggles.StairwellChairFly.Value then
    StopChairBypass()
  end

  refreshInfiniteJump()
  refreshNoclip()
  refreshThirdPerson()
  refreshPhase()

  task.spawn(function()
    task.wait(1)

    if isGodmodeActive() and threatState and not threatState.Sunk and CurrentFloor ~= "Fools" and CurrentFloor ~= "OldHotel" then
      if humanoidRootPart and humanoid and remotesFolder then
        humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, -2.346, 0)
        humanoid.HipHeight = 0.05
        local crouch = remotesFolder:FindFirstChild("Crouch")

        if crouch then
          crouch:FireServer(true, true)
        end

        threatState.Sunk = true
      end
    end
  end)

  SetupCharacterAnticheat()
  SetupBringItems()
end)

remotesFolder = replicatedStorage:FindFirstChild("RemotesFolder")

if not remotesFolder then
  if replicatedStorage:FindFirstChild("EntityInfo") then
    remotesFolder = replicatedStorage:FindFirstChild("EntityInfo")
  elseif replicatedStorage:FindFirstChild("Bricks") then
    remotesFolder = replicatedStorage:FindFirstChild("Bricks")
  end
end

FakeEvents = {
  Screech = Instance.new("RemoteEvent"), Shade = Instance.new("RemoteEvent"), A90 = Instance.new("RemoteEvent"), Surge = Instance.new("RemoteEvent"), }

FakeEvents.Screech.Name = "Screech"
FakeEvents.Shade.Name = "ShadeResult"
FakeEvents.A90.Name = "A90"
FakeEvents.Surge.Name = "SurgeRemote"

if remotesFolder then
  FakeEvents.Screech_Real = remotesFolder:FindFirstChild("Screech") or remotesFolder:WaitForChild("Screech", 2)
  FakeEvents.Shade_Real = remotesFolder:FindFirstChild("ShadeResult") or remotesFolder:WaitForChild("ShadeResult", 2)
  FakeEvents.A90_Real = remotesFolder:FindFirstChild("A90") or remotesFolder:WaitForChild("A90", 2)
  FakeEvents.Surge_Real = remotesFolder:FindFirstChild("SurgeRemote") or remotesFolder:WaitForChild("SurgeRemote", 2)
end

local function getRemoteModules()
  local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")
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

tabs = {
  Home = dummyTab, -- Home tab removed as requested
  Main = moroWindow:AddTab("Main", "house", {
    { "Character", "user", { "Character" } },
    { "Noclip", "ghost", { "Phantom Noclip" } },
    { "Other", "sliders-horizontal", { "Other" } },
  }),
  AutoFarm = moroWindow:AddTab("Auto Farm", "bot", {
    { "Knob Farm", "bot", { "Knob Farm", "Settings" } },
    { "Door Skip", "door-open", { "Auto Door Skip" } },
  }),
  Visuals = moroWindow:AddTab("Visuals", "scan-eye", {
    { "ESP", "eye", { "Targets", "ESP Preset" } },
    { "ESP Style", "box-select", { "Chams & Boxes", "Labels", "Tracers & Arrows", "Colors" } },
    { "Notifications", "bell", { "Entity Notifications", "Item Notifications" } },
    { "Camera", "camera", { "Camera" } },
    { "Models", "box", { "Model Library", "Model Search", "Swap Options", "Swap: Players", "Swap: Figure", "Swap: Seek",
      "Swap: Rush and clones", "Swap: Ambush and clones", "Swap: A-60 / A-120", "Swap: Eyes / Lookman", "Swap: Companion", "Swap: Custom entity" } },
    { "Fun", "party-popper", { "Screen Filter", "Aura", "Entity Fun" } },
    { "Post FX", "clapperboard", { "Post FX Presets", "Color Grading", "Bloom / Rays / Blur", "Depth of Field / Fog", "Weather", "Vignette" } },
    { "HUD", "layout-dashboard", { "HUD" } },
  }),
  Exploits = moroWindow:AddTab("Exploits", "sparkle", {
    { "Pre-Run", "rocket", { "Pre-Run" } },
    { "Bypasses", "shield-off", { "Bypasses", "Removals", "Damage" } },
    { "Prompts", "mouse-pointer-click", { "Prompts", "Crucifix Everything" } },
    { "Exploits", "zap", { "Exploits" } },
    { "Automation", "cpu", { "Automation" } },
  }),
  Miscellaneous = moroWindow:AddTab("Misc", "settings", {
    { "Misc", "wrench", { "Miscellaneous" } },
    { "Fun", "party-popper", { "Fun" } },
  }),
  Mines = moroWindow:AddTab("Mines", "gem", {
    { "Ladders", "arrow-up-down", { "Ladders", "Anticheat" } },
    { "Automation", "cpu", { "Automation" } },
    { "Visuals", "eye", { "Visuals" } },
  }),
  FoolsHotel = moroWindow:AddTab("Hotel-/Fools", "party-popper"),
  Rooms = moroWindow:AddTab("Rooms", "bed-double"),
  Garden = moroWindow:AddTab("Outdoors", "tree-pine"),
  Archives = moroWindow:AddTab("Archives", "archive", {
    { "Archives", "archive", { "Archives" } },
    { "Anticheat", "shield", { "Anticheat Bypass" } },
    { "Addons", "puzzle", { "Archives Addons" } },
  }),
  Stairwell = moroWindow:AddTab("Stairwell", "tv"),
}
moroWindow:AddSettingsTab()
do
  local tabLabel = getTabLabel(tabs.FoolsHotel)

  if tabLabel then
    tabs.FoolsHotel.TabLabelRef = tabLabel
  end
end

Groupboxes = {}

-- handlers (named callbacks of the menu) and per-block menu builders
Handlers = {}
Menus = {}


function Handlers.SkipCurrentRoom()
  task.spawn(function()
    local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

    if not currentRooms2 then
      return
    end

    local value = latestRoomValue and latestRoomValue.Value or localPlayer:GetAttribute("CurrentRoom")

    if not value then
      return
    end

    local findFirstChild = currentRooms2:FindFirstChild(tostring(value))

    if not findFirstChild then
      return
    end

    local door = findFirstChild:FindFirstChild("Door", true)

    if not door or not door:IsA("MeshPart") then
      local doorMeshes = {}

      for _, descendant in findFirstChild:GetDescendants() do
        if descendant:IsA("MeshPart") and descendant.Name == "Door" then
          table.insert(doorMeshes, descendant)
        end
      end

      door = doorMeshes[#doorMeshes]

      if not door then
        return
      end
    end

    local character2 = localPlayer.Character

    if character2 then
      character2:PivotTo(CFrame.new(door.Position))
    end
  end)
end


Groupboxes.SubfloorsOutdoors = false

Hour = tonumber(os.date("%H"))

if Hour >= 6 and Hour < 12 then
  Greeting = "Good morning"
elseif Hour >= 12 and Hour < 18 then
  Greeting = "Good afternoon"
else
  Greeting = "Good evening"
end

local rawGenv = (type(getgenv) == "function" and getgenv()) or {}
RootEnv = setmetatable({}, {
  __index = function(_, k)
    if rawGenv[k] ~= nil then return rawGenv[k] end
    local success, result = pcall(function() return getfenv(0)[k] end)
    if success and result ~= nil then return result end
    local success2, result3 = pcall(function() return getfenv()[k] end)
    if success2 and result3 ~= nil then return result3 end
    return _G[k]
  end
})

Executor = {
  isnetworkowner = RootEnv.isnetworkowner, firetouchinterest = RootEnv.firetouchinterest, replicatesignal = RootEnv.replicatesignal, fireproximityprompt = RootEnv.fireproximityprompt, hookmetamethod = RootEnv.hookmetamethod, newcclosure = RootEnv.newcclosure, getnamecallmethod = RootEnv.getnamecallmethod, require = RootEnv.require, hookfunction = RootEnv.hookfunction or RootEnv.replaceclosure, getconnections = RootEnv.getconnections, }


local function statusIcon(enabled)
  return enabled and "â" or "â"
end

hasFirePrompt = Executor.fireproximityprompt ~= nil
hasFireTouch = Executor.firetouchinterest ~= nil
hasReplicateSignal = Executor.replicatesignal ~= nil
hasNetworkOwner = Executor.isnetworkowner ~= nil

hasHookMeta = Executor.hookmetamethod ~= nil and Executor.newcclosure ~= nil
  and Executor.getnamecallmethod ~= nil

hasRequire = Executor.require ~= nil


function Handlers.PlayAgain()
  pcall(function()
    local playAgain = remotesFolder and remotesFolder:FindFirstChild("PlayAgain")

    if playAgain then
      playAgain:FireServer()
    end
  end)
end


function Handlers.ReturnToLobby()
  pcall(function()
    local lobby = remotesFolder and remotesFolder:FindFirstChild("Lobby")

    if lobby then
      lobby:FireServer()
    end
  end)
end


function Handlers.ResetCharacter()
  pcall(function()
    if humanoid then
      humanoid.Health = 0
    end

    local underwater = remotesFolder and remotesFolder:FindFirstChild("Underwater")

    if underwater then
      underwater:FireServer(true)
    end
  end)
end


function Handlers.GiveStarJug()
  task.spawn(function()
    local wait = character or localPlayer.CharacterAdded:Wait()
    local humanoid2 = humanoid or wait:WaitForChild("Humanoid")
    local parent = game:GetObjects("rbxassetid://119885581324516")[1]

    if not parent then
      return
    end

    local durability = 4
    local isUsed = false
    parent:SetAttribute("Durability", durability)
    local instance = Instance.new("NumberValue", parent)
    parent.Parent = localPlayer.Backpack
    local animations = parent:WaitForChild("Animations")
    local animationTracks = {}

    for _, child in animations:GetChildren() do
      animationTracks[child.Name] = humanoid2:LoadAnimation(child)

      if child.Name == "idle" then
        animationTracks[child.Name].Priority = Enum.AnimationPriority.Idle
        animationTracks[child.Name].Looped = true
      end
    end

    parent.Equipped:Connect(function()
      animationTracks.equip:Play()
      task.wait(animationTracks.equip.Length)

      if parent:IsDescendantOf(wait) then
        animationTracks.idle:Play()
      end
    end)

    parent.Unequipped:Connect(function()
      if animationTracks.idle.IsPlaying then
        animationTracks.idle:Stop()
      end
    end)

    parent.Activated:Connect(function()
      if isUsed then
        return
      end

      isUsed = true
      animationTracks.open:Play()

      if durability - 1 ~= 0 then
        durability = durability - 1
        parent:SetAttribute("Durability", durability)
      else
        parent:Destroy()
      end

      local character2 = character

      if not character2 or not character2.Parent then
        isUsed = false
        return
      end

      character2:SetAttribute("Starlight", true)
      character2:SetAttribute("StarlightHuge", true)

      local hasTriggered = false

      local collisionPart2 = character2:FindFirstChild("CollisionPart")
        or character2:FindFirstChild("Collision")

      local crouch = remotesFolder and remotesFolder:FindFirstChild("Crouch")

      if collisionPart2 and not character2:FindFirstChild("CollisionClone") then
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

        collisionClone.Parent = character2

        task.spawn(function()
          while not hasTriggered do
            collisionClone.Massless = not collisionClone.Massless

            if crouch then
              crouch:FireServer(true, true)
            end

            task.wait(0.21)
          end

          collisionClone.Massless = true
          collisionClone:Destroy()
        end)
      end

      instance.Value = 35
      TweenService:Create(instance, TweenInfo.new(70, Enum.EasingStyle.Linear), { Value = 0 }):Play()

      local connection = instance:GetPropertyChangedSignal("Value"):Connect(function()
        if character2 and character2.Parent then
          character2:SetAttribute("SpeedBoost", instance.Value)
        end
      end)

      task.wait(35)
      hasTriggered = true
      connection:Disconnect()
      instance:Destroy()

      if character2 and character2.Parent then
        character2:SetAttribute("Starlight", false)
        character2:SetAttribute("StarlightHuge", false)
        character2:SetAttribute("SpeedBoost", 0)
      end

      isUsed = false
    end)
  end)
end


function Handlers.AntiLagChanged(value)
  local currentRooms2 = workspace.CurrentRooms

  if not currentRooms2 then
    return
  end

  if value then
    for _, descendant in currentRooms2:GetDescendants() do
      if descendant:IsA("BasePart") then
        descendant:SetAttribute("Mat", descendant.Material)
        descendant.Material = "Plastic"
      end
    end
  else
    for _, descendant in currentRooms2:GetDescendants() do
      if descendant:IsA("BasePart") then
        if descendant:GetAttribute("Mat") then
          descendant.Material = descendant:GetAttribute("Mat") or "Plastic"
        end
      end
    end
  end
end


DisableIdleKickConn = nil

function Handlers.DisableIdleKickChanged(value)
  if DisableIdleKickConn then
    DisableIdleKickConn:Disconnect()
    DisableIdleKickConn = nil
  end

  if value then
    DisableIdleKickConn = localPlayer.Idled:Connect(function()
      VirtualUser:CaptureController()
      VirtualUser:ClickButton2(Vector2.new())
    end)
  end
end


DisplayInfoFPS = 60
DisplayInfoFC = 0
DisplayInfoFT = tick()

function Handlers.DisplayInfoChanged(value)
  if DisplayInfoLabel then
    DisplayInfoLabel:Destroy()
    DisplayInfoLabel = nil
  end

  if DisplayInfoConn then
    DisplayInfoConn:Disconnect()
    DisplayInfoConn = nil
  end

  if value then
    DisplayInfoFC = 0
    DisplayInfoFT = tick()
    DisplayInfoLabel = library:AddDraggableLabel("moro | loading...")

    if featureState.UILibrary == "Obsidian" then
      local label = DisplayInfoLabel.Label or DisplayInfoLabel
      pcall(function() label.TextColor3 = Color3.fromHex("ebebeb") end)
    end

    DisplayInfoConn = runService.RenderStepped:Connect(function()
      if _Unloading then
        return
      end

      DisplayInfoFC = DisplayInfoFC + 1
      local now = tick()

      if now - DisplayInfoFT >= 1 then
        DisplayInfoFPS = DisplayInfoFC
        DisplayInfoFT = now
        DisplayInfoFC = 0
      end

      local success = pcall(function()
        return math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue())
      end) and math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue()) or 0

      local success2 = pcall(identifyexecutor) and identifyexecutor() or "Unknown"

      DisplayInfoLabel:SetText(("moro | FPS: %d | Ping: %dms | Executor: %s | User: %s"):format(
        math.floor(DisplayInfoFPS), success, success2, localPlayer.Name
      ))
    end)
  end
end


UhhhhDecals = {}
UhhhhConn = nil

function Handlers.UhhhhChanged(value)
  if value then
    for _, descendant in pairs(workspace:GetDescendants()) do
      if descendant:IsA("BasePart") then
        local model = descendant:FindFirstAncestorWhichIsA("Model")

        if not (model and model:FindFirstChild("Humanoid")) then
          for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
            local decal = Instance.new("Decal")
            decal.Texture = "http://www.roblox.com/asset/?id=135666356081915"
            decal.Face = face
            decal.Parent = descendant

            table.insert(UhhhhDecals, decal)
          end
        end
      end
    end

    UhhhhConn = workspace.DescendantAdded:Connect(function(descendant)
      if descendant:IsA("BasePart") then
        local model = descendant:FindFirstAncestorWhichIsA("Model")

        if not (model and model:WaitForChild("Humanoid")) then
          for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
            local decal = Instance.new("Decal")
            decal.Texture = "http://www.roblox.com/asset/?id=135666356081915"
            decal.Face = face
            decal.Parent = descendant

            table.insert(UhhhhDecals, decal)
          end
        end
      end
    end)
  else
    if UhhhhConn then
      UhhhhConn:Disconnect()
      UhhhhConn = nil
    end

    for _, UhhhhDecal in ipairs(UhhhhDecals) do
      if UhhhhDecal and UhhhhDecal.Parent then
        UhhhhDecal:Destroy()
      end
    end

    TableClear(UhhhhDecals)
  end
end


function Handlers.UhhhhVal()
  local content = Instance.new("ScreenGui")
  content.Name = "content"
  content.ResetOnSpawn = false
  content.IgnoreGuiInset = true
  content.Parent = CoreGui

  local frame = Instance.new("Frame")
  frame.Size = UDim2.new(1, 0, 1, 0)
  frame.BackgroundColor3 = Color3.new(0, 0, 0)
  frame.BackgroundTransparency = 1
  frame.Parent = content

  local textLabel = Instance.new("TextLabel")
  textLabel.Size = UDim2.new(1, -40, 1, -40)
  textLabel.Position = UDim2.new(0, 20, 0, 20)
  textLabel.BackgroundTransparency = 1
  textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  textLabel.TextTransparency = 1
  textLabel.TextScaled = true
  textLabel.Font = Enum.Font.Code
  textLabel.TextXAlignment = Enum.TextXAlignment.Center
  textLabel.TextYAlignment = Enum.TextYAlignment.Center

  textLabel.Text = "MORO"

  textLabel.Parent = frame

  TweenService:Create(
    frame, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 0.1 }
  ):Play()

  TweenService:Create(
    textLabel, TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }
  ):Play()

  library:Toggle(false)
  task.wait(6)

  TweenService:Create(
    frame, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }
  ):Play()

  TweenService:Create(
    textLabel, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }
  ):Play()

  task.wait(1)
  content:Destroy()
end


OrbitConn = nil

function Handlers.OrbitItemsChanged()
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
    local count = #getChildren

    if count == 0 then
      return
    end

    local now = tick()

    for index, getChildrenEntry in ipairs(getChildren) do
      if getChildrenEntry:IsA("Model") then
        local orbitAngle = now * options.OrbitSpeed.Value + index / count * math.pi * 2

        local vector = Vector3.new(
          math.cos(orbitAngle) * 4, -options.OrbitYOffset.Value, math.sin(orbitAngle) * 4
        )

        getChildrenEntry:PivotTo(CFrame.new(humanoidRootPart.Position + vector))
      end
    end
  end)
end


BringItemsConn = nil
BringItemsBVs = {}

local function clearBringItemVelocities()
  TableClear(BringItemsBVs)
end

local function stopBringItems()
  if BringItemsConn then
    BringItemsConn:Disconnect()
    BringItemsConn = nil
  end

  clearBringItemVelocities()
end

local function getBasePart(child)
  if child:IsA("BasePart") then
    return child
  end

  if child:IsA("Model") then
    return child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
  end

  return nil
end

function SetupBringItems()
  stopBringItems()

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

    local character2 = character or localPlayer.Character
    local humanoid2 = character2 and character2:FindFirstChildOfClass("Humanoid")
    local currentCamera2 = workspace.CurrentCamera

    if not humanoid2 or not currentCamera2 or humanoid2.Health <= 0
      or humanoid2:GetState() == Enum.HumanoidStateType.Dead then
      clearBringItemVelocities()
      return
    end

    local holdPosition = currentCamera2.CFrame.Position + currentCamera2.CFrame.LookVector * 2
      + Vector3.new(0, -0.4, 0)

    local drops = workspace:FindFirstChild("Drops")

    if not drops then
      return
    end

    for _, child in ipairs(drops:GetChildren()) do
      local dropPart = getBasePart(child)

      if not dropPart then
        continue
      end

      if dropPart.Anchored then
        pcall(function() dropPart.Anchored = false end)
      end

      local bringItemsVelocity = dropPart:FindFirstChildOfClass("BodyVelocity")

      if not bringItemsVelocity then
        bringItemsVelocity = Instance.new("BodyVelocity")
        bringItemsVelocity.Name = "BringItemsVelocity"
        bringItemsVelocity.MaxForce = Vector3.new(9000000000, 9000000000, 9000000000)
        bringItemsVelocity.Parent = dropPart

        table.insert(BringItemsBVs, bringItemsVelocity)
      end

      local offsetToHold = holdPosition - dropPart.Position

      if offsetToHold.Magnitude > 2 then
        dropPart.CFrame = dropPart.CFrame:Lerp(CFrame.new(holdPosition), 0.4)
      end

      bringItemsVelocity.Velocity = offsetToHold * 40
    end
  end)
end


local loadAnimation

function Handlers.TwerkDanceChanged(value)
  local character2 = localPlayer.Character

  if not character2 then
    return
  end

  if value then
    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://12874447851"

    local humanoid2 = character2:FindFirstChildOfClass("Humanoid")

    if not humanoid2 then
      return
    end

    loadAnimation = humanoid2:LoadAnimation(animation)
    loadAnimation.Looped = true
    loadAnimation:Play()
  elseif loadAnimation then
    loadAnimation:Stop()
  end
end


Functions = {
  FirePrompt = nil, GetLibraryCode = nil, HasItem = nil, HandleHidingTransparency = nil, }

Connections = {}

if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
  and localPlayer.Character:FindFirstChild("Collision") then
end


-- ========================================================
-- Auto Door Skip (Knob Farm / Room Cleared)
-- ========================================================


do
  

  

  

  

  

  local function safeFirePrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    pcall(function()
      prompt.HoldDuration = 0
      prompt.RequiresLineOfSight = false
      prompt.MaxActivationDistance = 30
      prompt.Enabled = true
    end)
    if fireproximityprompt then
      pcall(fireproximityprompt, prompt, 0, true)
      pcall(fireproximityprompt, prompt)
    end
    if Functions and Functions.ForceFirePrompt then
      pcall(Functions.ForceFirePrompt, prompt)
    end
  end

    function Handlers.TPToBook()
    task.spawn(function()
      local char = localPlayer and localPlayer.Character
      local root = char and char:FindFirstChild("HumanoidRootPart")
      if not root then return end
  
      local curRooms = workspace:FindFirstChild("CurrentRooms")
      local targetRoom = (curRooms and curRooms:FindFirstChild("50")) or workspace
      local targetBook = nil
  
      for _, desc in ipairs(targetRoom:GetDescendants()) do
        if desc.Name == "LiveHintBook" then
          local pr = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
          if pr and pr.Enabled then
            targetBook = desc
            break
          end
        end
      end
  
      if not targetBook and curRooms then
        for _, desc in ipairs(curRooms:GetDescendants()) do
          if desc.Name == "LiveHintBook" then
            targetBook = desc
            break
          end
        end
      end
  
      if targetBook then
        local pos = (targetBook:IsA("BasePart") and targetBook.Position)
          or (targetBook:IsA("Model") and targetBook:GetPivot().Position)
        if pos then
          pcall(function()
            if KnobFarm then KnobFarm.Teleporting = true end
          end)
          root.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
          root.AssemblyLinearVelocity = Vector3.zero
          local pr = targetBook:FindFirstChildWhichIsA("ProximityPrompt", true)
          if pr then
            safeFirePrompt(pr)
          end
          pcall(function()
            if library and library.Notify then
              library:Notify({ Title = "Teleported to Book!", Time = 3 })
            end
          end)
        end
      else
        pcall(function()
          if library and library.Notify then
            library:Notify({ Title = "No Books found in Room 50!", Time = 3 })
          end
        end)
      end
    end)
  end


    function Handlers.TPToLibraryPaper()
    task.spawn(function()
      local char = localPlayer and localPlayer.Character
      local root = char and char:FindFirstChild("HumanoidRootPart")
      if not root then return end
  
      local curRooms = workspace:FindFirstChild("CurrentRooms")
      local targetRoom = (curRooms and curRooms:FindFirstChild("50")) or workspace
      local paper = (targetRoom and targetRoom:FindFirstChild("LibraryHintPaper", true))
        or (curRooms and curRooms:FindFirstChild("LibraryHintPaper", true))
        or (targetRoom and targetRoom:FindFirstChild("PickupItem", true))
  
      if not paper and targetRoom then
        for _, pr in ipairs(targetRoom:GetDescendants()) do
          if pr:IsA("ProximityPrompt") and pr.ObjectText:lower():find("paper", 1, true) then
            paper = pr.Parent
            break
          end
        end
      end
  
      if paper then
        local pPos = (paper:IsA("BasePart") and paper.Position)
          or (paper:IsA("Model") and paper:GetPivot().Position)
        if pPos then
          pcall(function()
            if KnobFarm then KnobFarm.Teleporting = true end
          end)
          root.CFrame = CFrame.new(pPos + Vector3.new(0, 1.2, 0))
          root.AssemblyLinearVelocity = Vector3.zero
          local pr = paper:FindFirstChildWhichIsA("ProximityPrompt", true)
          if pr then
            safeFirePrompt(pr)
          end
          pcall(function()
            if library and library.Notify then
              library:Notify({ Title = "Teleported to Library Paper!", Time = 3 })
            end
          end)
        end
      else
        pcall(function()
          if library and library.Notify then
            library:Notify({ Title = "Library Paper not found!", Time = 3 })
          end
        end)
      end
    end)
  end


  local function HasRushAmbushBlitz()
    local threatNames = {
      RushMoving = true, Rush = true,
      AmbushMoving = true, Ambush = true,
      BlitzMoving = true, Blitz = true,
      ["RNIUSHCG=="] = true, AR0xMBUSH = true,
      GlitchRush = true, GlitchAmbush = true, FrozenAmbush = true,
    }

    if threatState and threatState.ActiveThreats then
      for threat, active in pairs(threatState.ActiveThreats) do
        if active and threat and threat.Parent and threatNames[threat.Name] then
          return true, threat
        end
      end
    end

    for name in pairs(threatNames) do
      local obj = workspace:FindFirstChild(name)
      if obj then return true, obj end
    end

    local curRooms = workspace:FindFirstChild("CurrentRooms")
    if curRooms then
      for name in pairs(threatNames) do
        local obj = curRooms:FindFirstChild(name, true)
        if obj then return true, obj end
      end
    end

    return false, nil
  end

  local function isSeekUpcoming(currentRoom, currentRoomNum)
    if currentRoom then
      if currentRoom:FindFirstChild("TriggerEventCollision", true)
        or currentRoom:FindFirstChild("Seek_Arm", true)
        or currentRoom:FindFirstChild("SeekTrigger", true)
        or currentRoom:FindFirstChild("Seeking", true)
        or currentRoom:FindFirstChild("ChaseStartTrigger", true) then
        return true
      end
    end

    local curRooms = workspace:FindFirstChild("CurrentRooms")
    if curRooms and currentRoomNum then
      local nextRoom = curRooms:FindFirstChild(tostring(currentRoomNum + 1))
      if nextRoom then
        if nextRoom:FindFirstChild("TriggerEventCollision", true)
          or nextRoom:FindFirstChild("Seek_Arm", true)
          or nextRoom:FindFirstChild("SeekTrigger", true)
          or nextRoom:FindFirstChild("Seeking", true)
          or nextRoom:FindFirstChild("ChaseStartTrigger", true)
          or nextRoom:FindFirstChild("SeekMoving", true)
          or nextRoom:FindFirstChild("SeekMovingNewClone", true) then
          return true
        end
      end
    end

    return false
  end

  local function isSeekThreatZone(currentRoom, currentRoomNum)
    if currentRoomNum and ((currentRoomNum >= 30 and currentRoomNum <= 40) or (currentRoomNum >= 80 and currentRoomNum <= 90)) then
      return true
    end
    if isSeekUpcoming(currentRoom, currentRoomNum) then
      return true
    end
    return false
  end

  local function isSeekChase(currentRoom, currentRoomNum)
    local curNum = tonumber(currentRoomNum) or 0
    if curNum < 60 and KnobFarm and KnobFarm.FirstChaseDone then
      return false
    end
    if curNum >= 60 and KnobFarm and KnobFarm.SecondChaseDone then
      return false
    end
    local rep = game:GetService("ReplicatedStorage")
    local gameData = rep:FindFirstChild("GameData")
    if gameData then
      local inChase = gameData:FindFirstChild("ChaseInSession")
      if inChase then
        return inChase.Value == true
      end
    end
    if currentRoom then
      local moving = currentRoom:FindFirstChild("SeekMoving")
        or currentRoom:FindFirstChild("SeekMovingNewClone")
        or currentRoom:FindFirstChild("SeekRig")
      if moving then return true end
      if currentRoom:FindFirstChild("TriggerEventCollision") or currentRoom:FindFirstChild("ChaseStartTrigger") then
        return true
      end
    end
    return false
  end

  local function getPromptPos(prompt)
    local parent = prompt.Parent
    if not parent then return nil end
    if parent:IsA("BasePart") then
      return parent.Position
    elseif parent:IsA("Attachment") then
      return parent.WorldPosition
    elseif parent:IsA("Model") then
      return parent:GetPivot().Position
    end
    local part = prompt:FindFirstAncestorWhichIsA("BasePart")
    if part then return part.Position end
    return nil
  end

  local function isVisiblePickupPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
    local action = prompt.ActionText:lower()
    local objText = prompt.ObjectText:lower()
    local parent = prompt.Parent
    if not parent then return false end
    local parentName = parent.Name

    -- Exclude doors, locks, levers, books, papers, fuses
    if parentName == "Door" or parentName == "Padlock" or parentName == "Lock"
      or parent:FindFirstAncestor("Door") or parentName == "DoorFake" or parentName == "FakeDoor"
      or parentName == "LeverForGate" or parentName == "TrackLever"
      or parentName == "LiveHintBook" or parentName == "LibraryHintPaper"
      or parentName == "FusePickup" or parentName == "FuseObtain" then
      return false
    end

    if action == "close" then return false end

    -- Visible gold & stardust only
    if parentName == "GoldPile" or parentName == "TinyGold" or parentName == "Gold"
      or parentName == "StardustPickup" or parentName == "Stardust"
      or parent:GetAttribute("GoldValue")
      or objText:find("gold") or objText:find("stardust")
      or (action:find("take") and (parentName:find("Gold") or parentName:find("Star"))) then
      return true
    end

    return false
  end

  local function fastLootRoom(room)
    local lootedPrompts = {}
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local prompts = {}
    for _, pr in ipairs(room:GetDescendants()) do
      if isVisiblePickupPrompt(pr) and not lootedPrompts[pr] then
        table.insert(prompts, pr)
      end
    end

    for _, pr in ipairs(prompts) do
      if not (toggles.AutoDoorSkip and toggles.AutoDoorSkip.Value) then break end
      if pr and pr.Parent and pr.Enabled and not lootedPrompts[pr] then
        local pos = getPromptPos(pr)
        if pos then
          root.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
          safeFirePrompt(pr)
          lootedPrompts[pr] = true
          task.wait(0.06)
        end
      end
    end
  end

  local function handleGate(room)
    local gate = room:FindFirstChild("Gate", true)
    local lever = room:FindFirstChild("LeverForGate", true)
    if gate and lever then
      local char = localPlayer.Character
      local root = char and char:FindFirstChild("HumanoidRootPart")
      if root then
        local leverPart = (lever:IsA("BasePart") and lever) or lever:FindFirstChildWhichIsA("BasePart", true) or lever.PrimaryPart
        if leverPart then
          root.CFrame = leverPart.CFrame * CFrame.new(0, 0, 2.5)
          local pr = lever:FindFirstChildWhichIsA("ProximityPrompt", true)
          if pr then
            safeFirePrompt(pr)
          end
          task.wait(0.2)
        end
      end
    end
  end

  local function handleKeyAndUnlock(room, door)
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root then return end

    local lock = door:FindFirstChild("Lock") or door:FindFirstChild("UnlockPrompt", true)
    if not lock then return end

    local function getUnlockTool()
      -- 1. Check for keys first (приоритет ключу для дверей)
      if char:FindFirstChild("Key") then return char:FindFirstChild("Key") end
      if bp and bp:FindFirstChild("Key") then return bp:FindFirstChild("Key") end
      for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") and item.Name:lower():find("key") and not item.Name:lower():find("skeleton") then return item end
      end
      if bp then
        for _, item in ipairs(bp:GetChildren()) do
          if item:IsA("Tool") and item.Name:lower():find("key") and not item.Name:lower():find("skeleton") then return item end
        end
      end

      -- 2. Check for lockpicks if no key
      local lp = (char and (char:FindFirstChild("Lockpick") or char:FindFirstChild("Lockpicks")))
        or (bp and (bp:FindFirstChild("Lockpick") or bp:FindFirstChild("Lockpicks")))
      if lp then return lp end
      if char then
        for _, item in ipairs(char:GetChildren()) do
          if item:IsA("Tool") and item.Name:lower():find("lockpick", 1, true) then return item end
        end
      end
      local bp = localPlayer:FindFirstChildOfClass("Backpack")
      if bp then
        for _, item in ipairs(bp:GetChildren()) do
          if item:IsA("Tool") and item.Name:lower():find("lockpick", 1, true) then return item end
        end
      end

      return nil
    end

    local unlockTool = getUnlockTool()
    if not unlockTool then
      local keyObj = room:FindFirstChild("KeyObtain", true) or room:FindFirstChild("Key", true)
      if not keyObj then
        for _, pr in ipairs(room:GetDescendants()) do
          if pr:IsA("ProximityPrompt") and (pr.ObjectText:lower():find("key") or pr.Name:lower():find("key")) then
            keyObj = pr.Parent
            break
          end
        end
      end

      if keyObj then
        local keyPos = (keyObj:IsA("BasePart") and keyObj.Position) or (keyObj:IsA("Model") and keyObj:GetPivot().Position)
        if keyPos then
          root.CFrame = CFrame.new(keyPos + Vector3.new(0, 1.2, 0))
          local keyPrompt = keyObj:FindFirstChildWhichIsA("ProximityPrompt", true)
          if keyPrompt then
            safeFirePrompt(keyPrompt)
          end
          task.wait(0.25)
        end
      end
      unlockTool = getUnlockTool()
    end

    if unlockTool and hum and unlockTool.Parent ~= char then
      pcall(function() hum:EquipTool(unlockTool) end)
      task.wait(0.15)
    end

    local lockPrompt = door:FindFirstChild("UnlockPrompt", true)
      or (lock:IsA("ProximityPrompt") and lock)
      or lock:FindFirstChildWhichIsA("ProximityPrompt", true)

    local lockPart = (lock:IsA("BasePart") and lock) or lock:FindFirstChildWhichIsA("BasePart", true) or door:FindFirstChild("Door") or door.PrimaryPart
    if lockPart then
      root.CFrame = lockPart.CFrame * CFrame.new(0, 0, 2.5)
      if lockPrompt then
        safeFirePrompt(lockPrompt)
      end
      task.wait(0.2)
    end
  end

  local function openRoomDoor(door)
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not door then return end

    local doorPart = door:FindFirstChild("Door") or door:FindFirstChild("Hidden") or door.PrimaryPart
    if doorPart then
      root.CFrame = doorPart.CFrame * CFrame.new(0, 0, 3)
    end
    local prompt = door:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
      safeFirePrompt(prompt)
    end
  end

  -- ROOM 50 SOLVER (Books, Paper, Padlock Code)
  local function handleRoom(room, door)
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- 1. Collect all Books (LiveHintBook)
    for _, desc in ipairs(room:GetDescendants()) do
      if desc.Name == "LiveHintBook" then
        local pr = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
        local pos = (desc:IsA("BasePart") and desc.Position) or (desc:IsA("Model") and desc:GetPivot().Position)
        if pos then
          root.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
          if pr then safeFirePrompt(pr) end
          task.wait(0.15)
        end
      end
    end

    -- 2. Collect paper (LibraryHintPaper)
    local paper = room:FindFirstChild("LibraryHintPaper", true) or room:FindFirstChild("PickupItem", true)
    if not paper then
      for _, pr in ipairs(room:GetDescendants()) do
        if pr:IsA("ProximityPrompt") and pr.ObjectText:lower():find("paper") then
          paper = pr.Parent
          break
        end
      end
    end
    if paper then
      local pPos = (paper:IsA("BasePart") and paper.Position) or (paper:IsA("Model") and paper:GetPivot().Position)
      if pPos then
        root.CFrame = CFrame.new(pPos + Vector3.new(0, 1.2, 0))
        local pr = paper:FindFirstChildWhichIsA("ProximityPrompt", true)
        if pr then safeFirePrompt(pr) end
        task.wait(0.2)
      end
    end

    -- 3. Teleport near door 50 Padlock
    local padlock = room:FindFirstChild("Padlock", true) or (door and door:FindFirstChild("Padlock", true))
    local padPart = (padlock and padlock:IsA("BasePart") and padlock)
      or (padlock and padlock:FindFirstChildWhichIsA("BasePart", true))
      or (door and door:FindFirstChild("Door"))
      or (door and door.PrimaryPart)

    if padPart then
      root.CFrame = padPart.CFrame * CFrame.new(0, 0, 2.5)
      task.wait(0.3)
    end

    -- 4. Solve Padlock with code / brute force
    local code = Functions and Functions.GetLibraryCode and Functions.GetLibraryCode()
    if code and remotesFolder and remotesFolder:FindFirstChild("PL") then
      if not string.find(code, "_") and code ~= "_____" then
        remotesFolder.PL:FireServer(code)
      else
        task.spawn(function()
          local function brute(s)
            local idx = string.find(s, "_")
            if not idx then
              pcall(function() remotesFolder.PL:FireServer(s) end)
              task.wait(0.02)
              return
            end
            for d = 0, 9 do
              local newS = string.sub(s, 1, idx - 1) .. tostring(d) .. string.sub(s, idx + 1)
              brute(newS)
            end
          end
          brute(code)
        end)
      end
    end

    -- Wait for padlock unlock
    local t = tick()
    while padlock and padlock.Parent and (tick() - t < 4) do
      task.wait(0.2)
    end

    if door then
      openRoomDoor(door)
    end
  end

  -- ROOM 100 SOLVER (Fuses, Gate Lever, Breaker Box, Elevator)
  local function handleRoom2(room)
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root then return end

    -- 1. Поднять ключ от щитка (ElectricalKeyObtain) если есть, и открыть дверь
    local elecKey = room:FindFirstChild("ElectricalKeyObtain", true) or room:FindFirstChild("KeyElectrical", true)
    if elecKey then
      local kPos = (elecKey:IsA("BasePart") and elecKey.Position) or (elecKey:IsA("Model") and elecKey:GetPivot().Position)
      if kPos then
        root.CFrame = CFrame.new(kPos + Vector3.new(0, 1.2, 0))
        local kPr = elecKey:FindFirstChildWhichIsA("ProximityPrompt", true)
        if kPr then safeFirePrompt(kPr) end
        task.wait(0.25)
      end
    end

    -- Открыть запертую электрическую дверь если есть
    local elecLock = room:FindFirstChild("KeyElectrical", true) or room:FindFirstChild("ElectricalLock", true)
    if elecLock then
      local bp = localPlayer:FindFirstChildOfClass("Backpack")
      local keyTool = (char and char:FindFirstChild("KeyElectrical")) or (bp and bp:FindFirstChild("KeyElectrical"))
      if keyTool and hum and keyTool.Parent ~= char then
        pcall(function() hum:EquipTool(keyTool) end)
        task.wait(0.15)
      end
      local lPos = (elecLock:IsA("BasePart") and elecLock.Position) or (elecLock:IsA("Model") and elecLock:GetPivot().Position)
      if lPos then
        root.CFrame = CFrame.new(lPos + Vector3.new(0, 1.2, 0))
        local lPr = elecLock:FindFirstChildWhichIsA("ProximityPrompt", true)
        if lPr then safeFirePrompt(lPr) end
        task.wait(0.2)
      end
    end

    -- 2. Поднять все фигни (предохранители / fuses / breaker poles)
    for _, desc in ipairs(room:GetDescendants()) do
      local isFuse = desc.Name == "FusePickup" or desc.Name == "FuseObtain" or desc.Name == "Fuse" or desc.Name == "LiveBreakerPolePickup"
      if not isFuse and desc:IsA("ProximityPrompt") and (desc.ObjectText:lower():find("fuse") or desc.ActionText:lower():find("fuse")) then
        isFuse = true
      end
      if isFuse then
        local pr = desc:IsA("ProximityPrompt") and desc or desc:FindFirstChildWhichIsA("ProximityPrompt", true)
        local target = desc:IsA("ProximityPrompt") and desc.Parent or desc
        local pos = (target:IsA("BasePart") and target.Position) or (target:IsA("Model") and target:GetPivot().Position)
        if pos then
          root.CFrame = CFrame.new(pos + Vector3.new(0, 1.2, 0))
          if pr then safeFirePrompt(pr) end
          task.wait(0.12)
        end
      end
    end

    -- 3. Дернуть рычаг (открывающий ворота)
    local lever = room:FindFirstChild("LeverForGate", true) or room:FindFirstChild("Lever", true)
    if lever then
      local lPos = (lever:IsA("BasePart") and lever.Position) or (lever:IsA("Model") and lever:GetPivot().Position)
      if lPos then
        root.CFrame = CFrame.new(lPos + Vector3.new(0, 1.2, 0))
        local lPr = lever:FindFirstChildWhichIsA("ProximityPrompt", true)
        if lPr then safeFirePrompt(lPr) end
        task.wait(0.3)
      end
    end

    -- 4. Выполнить щиток
    local breaker = room:FindFirstChild("ElevatorBreaker", true) or workspace:FindFirstChild("ElevatorBreaker")
    if breaker then
      local bPos = (breaker:IsA("BasePart") and breaker.Position) or (breaker:IsA("Model") and breaker:GetPivot().Position)
      if bPos then
        root.CFrame = CFrame.new(bPos + Vector3.new(0, 1.5, 2.5))
        for _, bPr in ipairs(breaker:GetDescendants()) do
          if bPr:IsA("ProximityPrompt") then
            safeFirePrompt(bPr)
          end
        end
        task.wait(0.5)

        if remotesFolder and remotesFolder:FindFirstChild("EBF") then
          pcall(function() remotesFolder.EBF:FireServer() end)
        end
        task.wait(2)
      end
    end

    -- 5. Тепнуться в лифт
    local elevator = room:FindFirstChild("ElevatorCar", true)
      or room:FindFirstChild("Elevator", true)
      or workspace:FindFirstChild("ElevatorCar")

    if elevator then
      local ePos = elevator:GetPivot().Position
      root.CFrame = CFrame.new(ePos + Vector3.new(0, 2, 0))
      local ePr = elevator:FindFirstChildWhichIsA("ProximityPrompt", true)
      if ePr then safeFirePrompt(ePr) end
    end
  end

  local lastProcessedRoom = nil
  local AutoDoorSkipInSeek = false

  task.spawn(function()
    while task.wait(0.1) do
      if toggles.AutoDoorSkip and toggles.AutoDoorSkip.Value then
        pcall(function()
          local rep = game:GetService("ReplicatedStorage")
          local gameData = rep:FindFirstChild("GameData")
          local latestRoom = gameData and gameData:FindFirstChild("LatestRoom")
          if not latestRoom then return end

          local roomNum = tostring(latestRoom.Value)
          local currentRoomNum = tonumber(latestRoom.Value) or 0
          local currentRooms = workspace:FindFirstChild("CurrentRooms")
          local currentRoom = currentRooms and currentRooms:FindFirstChild(roomNum)
          if not currentRoom then return end

          local door = currentRoom:FindFirstChild("Door")

          -- ROOM 50 LOGIC
          if (currentRoomNum == 50 or roomNum == "50") and toggles.AutoSkipSpecialRooms and toggles.AutoSkipSpecialRooms.Value then
            if lastProcessedRoom ~= roomNum then
              handleRoom(currentRoom, door)
              lastProcessedRoom = roomNum
            else
              if door then openRoomDoor(door) end
            end
            return
          end

          -- ROOM 100 LOGIC
          if (currentRoomNum >= 100 or roomNum == "100") and toggles.AutoSkipSpecialRooms and toggles.AutoSkipSpecialRooms.Value then
            if lastProcessedRoom ~= roomNum then
              handleRoom2(currentRoom)
              lastProcessedRoom = roomNum
            end
            return
          end

          -- Check Seek chase: turn off noclip & ONLY skip door (everything else disabled!)
          if isSeekChase(currentRoom, currentRoomNum) then
            AutoDoorSkipInSeek = true
            pcall(function()
              if toggles.PhantomNoclip and toggles.PhantomNoclip.Value then
                toggles.PhantomNoclip:SetValue(false)
              end
              if toggles.Noclip and toggles.Noclip.Value then
                toggles.Noclip:SetValue(false)
              end
              local char = localPlayer.Character
              if char then
                for _, p in ipairs(char:GetDescendants()) do
                  if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    p.CanCollide = true
                  end
                end
              end
            end)

            if door then
              openRoomDoor(door)
            end
            return
          elseif AutoDoorSkipInSeek then
            -- Погоня Сика завершилась: выключаем скип и включаем фарм!
            AutoDoorSkipInSeek = false
            pcall(function()
              if toggles.AutoDoorSkip and toggles.AutoDoorSkip.Value then
                toggles.AutoDoorSkip:SetValue(false)
              end
              if toggles.AutoFarmEnabled and not toggles.AutoFarmEnabled.Value then
                toggles.AutoFarmEnabled:SetValue(true)
              end
              if toggles.PhantomNoclip and not toggles.PhantomNoclip.Value then
                toggles.PhantomNoclip:SetValue(true)
              end
            end)
            return
          end

          -- Threat wait: ONLY in rooms 30-40 and 80-90 (before Seek chase begins)
          if isSeekThreatZone(currentRoom, currentRoomNum) and toggles.AutoSkipWaitThreats and toggles.AutoSkipWaitThreats.Value then
            if HasRushAmbushBlitz() then
              while HasRushAmbushBlitz() do
                task.wait(0.3)
              end
              task.wait(0.5)
            end
          end

          if not door then return end

          if lastProcessedRoom ~= roomNum then
            if toggles.AutoSkipFastLoot and toggles.AutoSkipFastLoot.Value then
              fastLootRoom(currentRoom)
            end

            if toggles.AutoSkipUnlock and toggles.AutoSkipUnlock.Value then
              handleGate(currentRoom)
              handleKeyAndUnlock(currentRoom, door)
            end

            lastProcessedRoom = roomNum
          else
            if toggles.AutoSkipUnlock and toggles.AutoSkipUnlock.Value then
              local lock = door:FindFirstChild("Lock") or door:FindFirstChild("UnlockPrompt", true)
              if lock then
                handleKeyAndUnlock(currentRoom, door)
              end
            end
          end

          -- Threat wait before opening door in Seek zones
          if isSeekThreatZone(currentRoom, currentRoomNum) and toggles.AutoSkipWaitThreats and toggles.AutoSkipWaitThreats.Value then
            if HasRushAmbushBlitz() then
              while HasRushAmbushBlitz() do
                task.wait(0.3)
              end
              task.wait(0.5)
            end
          end

          openRoomDoor(door)
        end)
      else
        lastProcessedRoom = nil
      end
    end
  end)
  -- menu of this block: built later, from the MENU section at the end of the file
  Menus.AutoDoorSkip = function()
    Groupboxes.AutoDoorSkip:AddToggle("AutoDoorSkip", {
      Text = "Auto Door Skip",
      Tooltip = "Automatically clears rooms (visible gold, keys, levers) and solves doors.",
      Default = false,
    })

    Groupboxes.AutoDoorSkip:AddToggle("AutoSkipFastLoot", {
      Text = "Fast Loot (Золото / Пыль)",
      Tooltip = "Teleports to visible gold piles and stardust on tables/floor.",
      Default = true,
    })

    Groupboxes.AutoDoorSkip:AddToggle("AutoSkipWaitThreats", {
      Text = "Wait Threat in Seek Zones (30-40, 80-90)",
      Tooltip = "Waits for Rush/Ambush/Blitz to despawn ONLY in rooms 30-40 and 80-90 (Seek chase zones).",
      Default = true,
    })

    Groupboxes.AutoDoorSkip:AddToggle("AutoSkipUnlock", {
      Text = "Auto Key & Gate",
      Tooltip = "Automatically teleports to keys and pulls gate levers if door is locked.",
      Default = true,
    })

    Groupboxes.AutoDoorSkip:AddToggle("AutoSkipSpecialRooms", {
      Text = "Auto Room 50 & 100",
      Tooltip = "Auto collects books + code in Room 50, and collects fuses + solves breaker + enters elevator in Room 100.",
      Default = true,
    })

    Groupboxes.AutoDoorSkip:AddButton({
      Text = "TP to Book",
      Tooltip = "Teleports to any uncollected book in Room 50",
      Callback = Handlers.TPToBook
    })

    Groupboxes.AutoDoorSkip:AddButton({
      Text = "TP to Library Paper",
      Tooltip = "Teleports to the hint paper with the code in Room 50",
      Callback = Handlers.TPToLibraryPaper
    })
  end

end


function Handlers.BuyItems()
  task.spawn(function()
    local preRunShop = replicatedStorage.RemotesFolder:FindFirstChild("PreRunShop")

    if not preRunShop then
      return
    end

    local value = options.SpamBuyItems.Value
    local spamItems = {}

    if value then
      for key, _ in pairs(value) do
        table.insert(spamItems, key)
      end
    end

    if #spamItems > 0 then
      local buyCount = options.SpamBuyCount.Value
      local spamQueue = {}

      for _ = 1, buyCount do
        for _, spamItem in ipairs(spamItems) do
          table.insert(spamQueue, spamItem)
        end
      end

      preRunShop:FireServer(spamQueue, false)
    end
  end)
end


function Handlers.ShowCrucifixChanged(visible)
  if detectFloor() ~= "OldHotel" then
    return
  end

  local itemShopCrucifix = localPlayer and localPlayer.PlayerGui
    and localPlayer.PlayerGui:FindFirstChild("MainUI")
    and localPlayer.PlayerGui.MainUI:FindFirstChild("ItemShop")
    and localPlayer.PlayerGui.MainUI.ItemShop:FindFirstChild("Items")
    and localPlayer.PlayerGui.MainUI.ItemShop.Items:FindFirstChild("ItemShop_Crucifix")

  if itemShopCrucifix then
    itemShopCrucifix.Visible = visible
  end
end


function Handlers.ShowSkeletonKeyChanged(visible)
  if detectFloor() ~= "OldHotel" then
    return
  end

  local itemShopSkeletonKey = localPlayer and localPlayer.PlayerGui
    and localPlayer.PlayerGui:FindFirstChild("MainUI")
    and localPlayer.PlayerGui.MainUI:FindFirstChild("ItemShop")
    and localPlayer.PlayerGui.MainUI.ItemShop:FindFirstChild("Items")
    and localPlayer.PlayerGui.MainUI.ItemShop.Items:FindFirstChild("ItemShop_Skeleton Key")

  if itemShopSkeletonKey then
    itemShopSkeletonKey.Visible = visible
  end
end


function Handlers.ConfirmShop()
  if Functions and Functions.ConfirmPreRunShop then
    Functions.ConfirmPreRunShop()
  end
end


local lastAutoLockpickBuy = 0

function Functions.ConfirmPreRunShop()
  local mainUI = localPlayer and localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("MainUI")
  local itemShop = mainUI and mainUI:FindFirstChild("ItemShop")

  local buttonClicked = false

  if itemShop then
    -- 1. Ищем кнопку Confirm среди всех элементов ItemShop
    local targetBtn = nil
    for _, desc in ipairs(itemShop:GetDescendants()) do
      if desc:IsA("GuiButton") then
        local nameLower = desc.Name:lower()
        if nameLower == "confirm" or nameLower:find("confirm") then
          targetBtn = desc
          break
        end
        if desc:IsA("TextButton") and desc.Text:lower():find("confirm") then
          targetBtn = desc
          break
        end
      end
    end

    if not targetBtn then
      for _, desc in ipairs(itemShop:GetDescendants()) do
        if desc:IsA("TextLabel") and desc.Text:lower():find("confirm") then
          local p = desc:FindFirstAncestorWhichIsA("GuiButton")
          if p then
            targetBtn = p
            break
          end
        end
      end
    end

    if targetBtn then
      -- Нажатие через firesignal (если доступно)
      if firesignal then
        pcall(function() firesignal(targetBtn.MouseButton1Click) end)
        pcall(function() firesignal(targetBtn.Activated) end)
        pcall(function() firesignal(targetBtn.MouseButton1Down) end)
        pcall(function() firesignal(targetBtn.MouseButton1Up) end)
      end

      -- Нажатие через getconnections
      if getconnections then
        pcall(function()
          for _, c in ipairs(getconnections(targetBtn.MouseButton1Click)) do
            pcall(c.Fire, c)
          end
          for _, c in ipairs(getconnections(targetBtn.Activated)) do
            pcall(c.Fire, c)
          end
        end)
      end

      -- Нажатие через VirtualInputManager (эмуляция реального клика мыши)
      pcall(function()
        local vim = game:GetService("VirtualInputManager")
        if vim and targetBtn.AbsoluteSize.X > 0 and targetBtn.AbsoluteSize.Y > 0 then
          local x = targetBtn.AbsolutePosition.X + targetBtn.AbsoluteSize.X / 2
          local y = targetBtn.AbsolutePosition.Y + targetBtn.AbsoluteSize.Y / 2
          vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
          task.wait(0.04)
          vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
        end
      end)

      buttonClicked = true
    end

    -- Визуально закрываем ItemShop
    pcall(function()
      itemShop.Visible = false
    end)
  end

  -- 2. Серверный вызов удаленного события PreRunShop (второй аргумент true = confirm)
  pcall(function()
    local preRunShop = (replicatedStorage and replicatedStorage:FindFirstChild("RemotesFolder") and replicatedStorage.RemotesFolder:FindFirstChild("PreRunShop"))
      or (remotesFolder and remotesFolder:FindFirstChild("PreRunShop"))
    if preRunShop then
      preRunShop:FireServer({}, true)
    end
  end)

  return buttonClicked
end

function Functions.CheckAndAutoBuyLockpick()
  if not toggles.AutoBuyLockpicks or not toggles.AutoBuyLockpicks.Value then
    return
  end

  if tick() - lastAutoLockpickBuy < 4.0 then
    return
  end

  local char = (localPlayer and localPlayer.Character) or character
  local bp = localPlayer and localPlayer:FindFirstChildOfClass("Backpack")
  if (char and char:FindFirstChild("Lockpick")) or (bp and bp:FindFirstChild("Lockpick")) then
    return
  end

  if Functions.HasItem and (Functions.HasItem("Lockpick") or Functions.HasItem("Lockpick", true)) then
    return
  end

  local preRunShop = (replicatedStorage and replicatedStorage:FindFirstChild("RemotesFolder") and replicatedStorage.RemotesFolder:FindFirstChild("PreRunShop"))
    or (remotesFolder and remotesFolder:FindFirstChild("PreRunShop"))

  if preRunShop then
    lastAutoLockpickBuy = tick()
    if KnobFarm then
      KnobFarm.LockpickBoughtThisRun = true
    end
    pcall(function()
      preRunShop:FireServer({ "Lockpick" }, false)
    end)
  end
end

function Handlers.AutoBuyLockpicksChanged(enabled)
  if enabled then
    task.spawn(Functions.CheckAndAutoBuyLockpick)
  end
end


task.spawn(function()
  local function setupItemShopListener(mainUI)
    if not mainUI then return end
    local itemShop = mainUI:WaitForChild("ItemShop", 5)
    if itemShop then
      local function onShopVisible()
        if not itemShop.Visible then return end
        task.spawn(function()
          -- Если включен автобай отмычек, сначала покупаем отмычку
          if toggles.AutoBuyLockpicks and toggles.AutoBuyLockpicks.Value then
            task.wait(0.4)
            Functions.CheckAndAutoBuyLockpick()
            task.wait(0.4)
          else
            task.wait(0.3)
          end
          -- Если включено авто-закрытие магазина или активен автофарм
          local shouldClose = (toggles.AutoClosePreRunShop and toggles.AutoClosePreRunShop.Value)
            or (KnobFarm and KnobFarm.Active)
          if shouldClose then
            Functions.ConfirmPreRunShop()
          end
        end)
      end

      itemShop:GetPropertyChangedSignal("Visible"):Connect(onShopVisible)
      if itemShop.Visible then
        onShopVisible()
      end
    end
  end

  if localPlayer and localPlayer:FindFirstChild("PlayerGui") then
    local mainUI = localPlayer.PlayerGui:FindFirstChild("MainUI")
    if mainUI then
      setupItemShopListener(mainUI)
    end
    localPlayer.PlayerGui.ChildAdded:Connect(function(child)
      if child.Name == "MainUI" then
        setupItemShopListener(child)
      end
    end)
  end
end)


_TrackedPrompts = {}

function Handlers.PromptRangeChanged(value)
  if toggles.PromptReach.Value then
    for _, _TrackedPrompt in ipairs(_TrackedPrompts) do
      _TrackedPrompt.MaxActivationDistance = _TrackedPrompt:GetAttribute("MaxActivationDistance_Old") * value
    end
  end
end


local lastPrompt

Connections.InfiniteItemsHandler = ProximityPromptService.PromptTriggered:Connect(function(prompt)
  if not prompt:GetAttribute("FakePrompt") then
    return
  end

  local curChar = localPlayer and localPlayer.Character
  local lockItemNames = {
    "Lockpick", "Lockpicks", "Shears", "SkeletonKey", "Key", "GeneratorFuse", "KeyElectrical", "KeyBackdoor", "KeyIron", "Multitool", }

  local toolItemNames = {
    "Lockpick", "Lockpicks", "Shears", "SkeletonKey", "Key", "KeyElectrical", "KeyBackdoor", "KeyIron", "Multitool", }

  local findFirstChild

  if curChar then
    for _, lockItemName in ipairs(lockItemNames) do
      findFirstChild = curChar:FindFirstChild(lockItemName)

      if findFirstChild then
        break
      end
    end
  end

  local lockPromptNames = {
    UnlockPrompt = true, SkullPrompt = true, LockPrompt = true, ThingToEnable = true, FusesPrompt = true, }

  local parent = lockPromptNames[prompt.Name]
    or prompt.Parent and prompt.Parent:GetAttribute("Locked") == true
    or prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name == "Locker_Small_Locked"
      and prompt.Name == "ActivateEventPrompt"

  if parent then
    if options.AutoInteractIgnoreList.Value.Locks then
      return
    end

    local unlockItemNames = {
      "Key", "GeneratorFuse", "KeyBackdoor", "KeyElectrical", "KeyIron", "Lockpick", "Lockpicks", "SkeletonKey", "Shears", "Multitool", }

    local keyItemNames = { "Key", "GeneratorFuse", "KeyElectrical", "KeyIron" }
    local hasUnlockItem = false

    for _, unlockItemName in ipairs(unlockItemNames) do
      if Functions.HasItem(unlockItemName, true) then
        hasUnlockItem = true
        break
      end
    end

    for _, keyItemName in ipairs(keyItemNames) do
      if Functions.HasItem(keyItemName) then
        hasUnlockItem = true
        break
      end
    end

    if not hasUnlockItem then
      return
    end
  end

  if prompt.Parent.Name == "CuttableVines" and not Functions.HasItem("Shears", true)
      and not Functions.HasItem("Multitool", true)
    or prompt.Parent.Name == "Chest_Vine" and not Functions.HasItem("Shears", true)
      and not Functions.HasItem("Multitool", true)
    or prompt.Parent.Name == "Cellar" and not Functions.HasItem("Shears", true)
      and not Functions.HasItem("Multitool", true) then
    return
  end

  if prompt.Parent.Name == "SkullLock" and not Functions.HasItem("SkeletonKey", true) then
    return
  end

  if prompt.Parent.Name == "Lock1" and not Functions.HasItem("Lockpick", true)
      and not Functions.HasItem("Multitool", true)
    or prompt.Parent.Name == "Lock2" and not Functions.HasItem("Lockpick", true)
      and not Functions.HasItem("Multitool", true) then
    return
  end

  if Functions.HasItem("Shears", true) and parent and prompt.Parent.Name ~= "CuttableVines"
    and prompt.Parent.Name ~= "Chest_Vine" and prompt.Parent.Name ~= "Cellar" then
    return
  end

  if findFirstChild and TableFind(toolItemNames, findFirstChild.Name) and featureState.UseAnimation
    and featureState.UseAnimationBreak then
    featureState.UseAnimation:Stop()
    featureState.UseAnimationBreak:Stop()
    featureState.UseAnimationBreak:Play()

    if findFirstChild.Name == "Shears" then
      findFirstChild:WaitForChild("Handle"):WaitForChild("sound_prompt"):Play()
    end
  end

  local tool = character:FindFirstChildOfClass("Tool")
  local tool2 = tool and lastPrompt[tool.Name]

  if tool and tool2 and toggles.InfiniteItemsToggle.Value and ({
    Lockpicks = true, ["Skeleton Key"] = true, Shears = true, Multitool = true, })[tool2] then
    workspace:FindFirstChild("Drops").ChildAdded:Once(function(child)
      local modulePrompt = child:FindFirstChild("ModulePrompt")
      Functions.FirePrompt(modulePrompt)
      Functions.FirePrompt(FakePrompts[prompt])
    end)

    character.ChildAdded:Once(function(child)
      if child.Name == "Shears" then
        child:WaitForChild("Handle"):WaitForChild("sound_promptend"):Play()
      end
    end)

    remotesFolder.DropItem:FireServer(tool)
  else
    Functions.FirePrompt(FakePrompts[prompt])
  end
end)


function Handlers.FakeRevive()
  task.spawn(function()
    local gravity = workspace.Gravity
    local deathConnection

    local function setupDeathHandler()
      local humanoid2 = localPlayer.Character
          and localPlayer.Character:FindFirstChild("Humanoid")
        or localPlayer.Character:WaitForChild("Humanoid")

      if deathConnection then
        deathConnection:Disconnect()
      end

      deathConnection = humanoid2.Died:Connect(function()
        task.delay(0.5, function()
          workspace.Gravity = 0
          local character2 = localPlayer.Character

          if not character2 then
            return
          end

          local humanoid3 = character2:FindFirstChild("Humanoid")
          local humanoidRootPart2 = character2:FindFirstChild("HumanoidRootPart")

          if not humanoid3 or not humanoidRootPart2 then
            return
          end

          local playerGui2 = localPlayer:FindFirstChild("PlayerGui")

          if playerGui2 then
            local mainUI = playerGui2:FindFirstChild("MainUI")

            if mainUI then
              local deathPanel = mainUI:FindFirstChild("DeathPanel")

              if deathPanel then
                deathPanel:Destroy()
              end

              local death = mainUI:FindFirstChild("Death")

              if death then
                death:Destroy()
              end
            end
          end

          humanoid3.Health = humanoid3.MaxHealth
          humanoid3.AutomaticScalingEnabled = true

          if character2:GetAttribute("Stunned") then
            character2:SetAttribute("Stunned", false)
          end

          task.delay(1, function()
            if deathConnection then
              workspace.Gravity = gravity
            end
          end)
        end)
      end)
    end

    local currentRoom = localPlayer:GetAttribute("CurrentRoom")
      or replicatedStorage:FindFirstChild("GameData")
        and replicatedStorage.GameData:FindFirstChild("LatestRoom")
        and replicatedStorage.GameData.LatestRoom.Value

    if currentRoom and currentRoom >= 1 then
      setupDeathHandler()
      localPlayer.CharacterAdded:Connect(function() setupDeathHandler() end)
      task.wait(1)

      if Executor.replicatesignal then
        Executor.replicatesignal(localPlayer.kill)
      elseif remotesFolder and remotesFolder:FindFirstChild("Underwater") then
        remotesFolder.Underwater:FireServer(true)
      else
        localPlayer.Character.Humanoid.Health = 0
      end

      task.wait(1)
      coreGui:FindFirstChild("RobloxGui").Backpack.Visible = true

      localPlayer:SetAttribute("Alive", true)
      localPlayer:SetAttribute("FakeDeath", true)

      library:Notify({ Title = "Pick up a bandage to restore all interactions", Time = 5 })
    end
  end)
end


-- ========================================================
-- Crucifix Everything (Exploits Left Groupbox)
-- ========================================================


do
  local CRUCIFIX_URL = "https://raw.githubusercontent.com/RegularVynixu/DOORS-Crucifix-Everything/main/init.luau"
  local CrucifixEverything = nil

  local function LoadCrucifix()
    if CrucifixEverything then return CrucifixEverything end
    local success, result = pcall(function()
      local source = game:HttpGet(CRUCIFIX_URL)
      if not source or source == "" then error("Empty source") end
      local loader = loadstring(source)
      if not loader then error("loadstring failed") end
      return loader()
    end)
    if success and result then
      CrucifixEverything = result
      return CrucifixEverything
    else
      warn("[Crucifix] Failed to load library: " .. tostring(result))
      return nil
    end
  end

  local crucifixType = 1
  local crucifixUses = nil
  local crucifixResist = false
  local crucifixEntitiesOnly = false
  local crucifixCustomColor = nil
  local crucifixIgnoreList = {}

    function Handlers.CrucifixType(val)
    if val == "guiding light" then
      crucifixType = 1
    elseif val == "curious light" then
      crucifixType = 2
    end
  end


    function Handlers.CrucifixUses(val)
    local lowerVal = string.lower(tostring(val or ""))
    if lowerVal == "nil" or lowerVal == "" then
      crucifixUses = nil
    else
      local n = tonumber(val)
      if n then crucifixUses = n end
    end
  end


  

  

    function Handlers.CrucifixColor(val)
    val = tostring(val or "")
    if val == "" then
      crucifixCustomColor = nil
      return
    end
    local r, g, b = string.match(val, "(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
    if r and g and b then
      crucifixCustomColor = Color3.fromRGB(math.clamp(tonumber(r), 0, 255), math.clamp(tonumber(g), 0, 255), math.clamp(tonumber(b), 0, 255))
    else
      crucifixCustomColor = nil
    end
  end


    function Handlers.CrucifixIgnoreList(val)
    val = tostring(val or "")
    crucifixIgnoreList = {}
    if val == "" then return end
    for name in string.gmatch(val, "([^,]+)") do
      name = name:gsub("^%s+", ""):gsub("%s+$", "")
      if name ~= "" then
        table.insert(crucifixIgnoreList, name)
      end
    end
  end


    function Handlers.GiveCrucifix()
    local lib = LoadCrucifix()
    if not lib then
      library:Notify({ Title = "Crucifix", Description = "Failed to load Crucifix library", Time = 5 })
      return
    end
    local success, result = pcall(function()
      lib:GiveCrucifix({
        Type = crucifixType,
        Uses = crucifixUses,
        Resist = crucifixResist,
        EntitiesOnly = crucifixEntitiesOnly,
        CustomColor = crucifixCustomColor,
        IgnoreList = crucifixIgnoreList,
      })
    end)
    if success then
      library:Notify({ Title = "Crucifix", Description = "Crucifix given successfully!", Time = 4 })
    else
      library:Notify({ Title = "Crucifix", Description = "Error: " .. tostring(result), Time = 5 })
    end
  end


    function Handlers.RemoveCrucifix()
    local removed = false
    local bp = localPlayer:FindFirstChildOfClass("Backpack")
    if bp then
      local c = bp:FindFirstChild("Crucifix")
      if c then c:Destroy(); removed = true end
    end
    local ch = localPlayer.Character
    if ch then
      local c = ch:FindFirstChild("Crucifix")
      if c then c:Destroy(); removed = true end
    end
    if removed then
      library:Notify({ Title = "Crucifix", Description = "Crucifix removed!", Time = 3 })
    else
      library:Notify({ Title = "Crucifix", Description = "No Crucifix found in inventory.", Time = 3 })
    end
  end


  -- menu of this block: built later, from the MENU section at the end of the file
  Menus.CrucifixEverything = function()
    Groupboxes.CrucifixEverything:AddDropdown("CrucifixType", {
      Text = "Crucifix Type",
      Values = { "guiding light", "curious light" },
      Default = "guiding light",
      Callback = Handlers.CrucifixType,
    })

    Groupboxes.CrucifixEverything:AddInput("CrucifixUses", {
      Text = "Crucifix Uses",
      Default = "nil",
      Placeholder = "number or nil (infinite)",
      Callback = Handlers.CrucifixUses,
    })

    Groupboxes.CrucifixEverything:AddToggle("CrucifixResist", {
      Text = "Resist",
      Tooltip = "Whether the crucifix succeeds or fails against the entity.",
      Default = false,
      Callback = function(val)
        crucifixResist = val
      end,
    })

    Groupboxes.CrucifixEverything:AddToggle("CrucifixEntitiesOnly", {
      Text = "Entities Only",
      Tooltip = "Only target custom entity models.",
      Default = false,
      Callback = function(val)
        crucifixEntitiesOnly = val
      end,
    })

    Groupboxes.CrucifixEverything:AddInput("CrucifixColor", {
      Text = "Custom Color",
      Default = "",
      Placeholder = "r, g, b (e.g. 255, 0, 0)",
      Callback = Handlers.CrucifixColor,
    })

    Groupboxes.CrucifixEverything:AddInput("CrucifixIgnoreList", {
      Text = "Ignore List",
      Default = "",
      Placeholder = "entity1, entity2",
      Callback = Handlers.CrucifixIgnoreList,
    })

    Groupboxes.CrucifixEverything:AddButton({
      Text = "Give Crucifix",
      Tooltip = "Spawns the configured crucifix in your inventory.",
      Callback = Handlers.GiveCrucifix,
    })

    Groupboxes.CrucifixEverything:AddButton({
      Text = "Remove Crucifix",
      Tooltip = "Removes any Crucifix from backpack and character.",
      Callback = Handlers.RemoveCrucifix,
    })
  end

end

local function patchPromptDefaults(prompt)
  if not prompt:GetAttribute("HoldDuration_Old") then
    prompt:SetAttribute("HoldDuration_Old", prompt.HoldDuration)
    prompt:SetAttribute("RequiresLineOfSight_Old", prompt.RequiresLineOfSight)
    local curDist = prompt.MaxActivationDistance
    if curDist and curDist >= 900 then curDist = 12 end
    prompt:SetAttribute("MaxActivationDistance_Old", curDist)
  end

  if prompt.MaxActivationDistance and prompt.MaxActivationDistance >= 900 then
    prompt.MaxActivationDistance = prompt:GetAttribute("MaxActivationDistance_Old") or 12
  end

  if toggles.InstantInteract.Value then
    prompt.HoldDuration = 0
  end

  if toggles.PromptClip.Value then
    prompt.RequiresLineOfSight = false
  end

  if toggles.PromptReach.Value then
    prompt.MaxActivationDistance = prompt:GetAttribute("MaxActivationDistance_Old")
      * options.PromptRange.Value
  end
end

FakePrompts = {}

local promptContainer = Instance.new("Folder")
promptContainer.Name = "PromptContainer"
promptContainer.Parent = CoreGui

local function registerPrompt(prompt)
  if prompt.ClassName ~= "ProximityPrompt" or prompt:GetAttribute("FakePrompt") then
    return
  end

  table.insert(_TrackedPrompts, prompt)
  patchPromptDefaults(prompt)

  local lockPromptNames = {
    UnlockPrompt = true, SkullPrompt = true, LockPrompt = true, ThingToEnable = true, FusesPrompt = true, }

  if Executor.fireproximityprompt then
    local currentFloor = localPlayer:GetAttribute("CurrentFloor") or ""

    if currentFloor ~= "OldHotel" and currentFloor ~= "Fools" then
      if toggles.InfiniteItemsToggle and toggles.InfiniteItemsToggle.Value and (lockPromptNames[prompt.Name]
        or prompt.Parent and prompt.Parent:GetAttribute("Locked") == true
        or prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name == "Locker_Small_Locked"
          and prompt.Name == "ActivateEventPrompt") then
        local clone = prompt:Clone()
        clone:SetAttribute("FakePrompt", true)

        task.wait()

        clone.Parent = prompt.Parent
        clone:SetAttribute("HoldDuration_Old", prompt:GetAttribute("HoldDuration_Old"))

        clone:SetAttribute(
          "RequiresLineOfSight_Old", prompt:GetAttribute("RequiresLineOfSight_Old")
        )

        clone:SetAttribute(
          "MaxActivationDistance_Old", prompt:GetAttribute("MaxActivationDistance_Old")
        )

        clone.HoldDuration = prompt.HoldDuration
        clone.RequiresLineOfSight = prompt.RequiresLineOfSight
        clone.MaxActivationDistance = prompt.MaxActivationDistance

        if toggles.InstantInteract.Value then
          clone.HoldDuration = 0
        end

        if toggles.PromptClip.Value then
          clone.RequiresLineOfSight = false
        end

        clone.MaxActivationDistance = clone:GetAttribute("MaxActivationDistance_Old")
          * options.PromptRange.Value

        FakePrompts[clone] = prompt
        table.insert(_TrackedPrompts, clone)
        clone.Destroying:Once(function() local _ = TableFind(_TrackedPrompts, clone) end)
        pcall(function() prompt.Parent = promptContainer end)

        local connection = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
          clone.Enabled = prompt.Enabled
        end)

        prompt:GetPropertyChangedSignal("ActionText"):Once(function()
          prompt.Parent = clone.Parent
          clone:Destroy()
          connection:Disconnect()
        end)

        prompt.Destroying:Once(function()
          clone:Destroy()
          connection:Disconnect()
        end)

        clone.Enabled = false
        task.wait()
        clone.Enabled = prompt.Enabled
      end
    end
  end

  prompt.Destroying:Once(function() local _ = TableFind(_TrackedPrompts, prompt) end)
end

function Handlers.InstantInteractChanged()
  for _, _TrackedPrompt in ipairs(_TrackedPrompts) do
    _TrackedPrompt.HoldDuration = toggles.InstantInteract.Value and 0
      or _TrackedPrompt:GetAttribute("HoldDuration_Old")
  end
end


function Handlers.PromptClipChanged()
  for _, _TrackedPrompt in ipairs(_TrackedPrompts) do
    if toggles.PromptClip.Value then
      _TrackedPrompt.RequiresLineOfSight = false
    else
      _TrackedPrompt.RequiresLineOfSight = _TrackedPrompt:GetAttribute("RequiresLineOfSight_Old")
    end
  end
end


function Handlers.PromptReachChanged()
  for _, _TrackedPrompt in ipairs(_TrackedPrompts) do
    if toggles.PromptReach.Value then
      _TrackedPrompt.MaxActivationDistance = _TrackedPrompt:GetAttribute("MaxActivationDistance_Old")
        * options.PromptRange.Value
    else
      _TrackedPrompt.MaxActivationDistance = _TrackedPrompt:GetAttribute("MaxActivationDistance_Old")
    end
  end
end


function Handlers.PromptRangeChanged2()
  if toggles.PromptReach.Value then
    for _, _TrackedPrompt in ipairs(_TrackedPrompts) do
      _TrackedPrompt.MaxActivationDistance = _TrackedPrompt:GetAttribute("MaxActivationDistance_Old")
        * options.PromptRange.Value
    end
  end
end


local function createProxyToggle(flag)
  local proxy = {
    Value = false,
    _listeners = {},
    SetValue = function(self, val)
      val = not not val
      if self.Value ~= val then
        self.Value = val
        for _, fn in ipairs(self._listeners) do
          pcall(fn, val)
        end
      end
    end,
    OnChanged = function(self, fn)
      table.insert(self._listeners, fn)
      return {
        Disconnect = function()
          for i, l in ipairs(self._listeners) do
            if l == fn then table.remove(self._listeners, i); break end
          end
        end
      }
    end,
    SetDisabled = function(self, d)
      self.Disabled = d
    end,
  }
  library.Toggles[flag] = proxy
  return proxy
end


local AntiEntityMapping = {
  ["Giggle"] = "BypassGiggle",
  ["Dupe"] = "BypassDupe",
  ["Eyes"] = "BypassEyes",
  ["Lookman"] = "BypassLookman",
  ["Gloombat Eggs"] = "BypassGloombatEggs",
  ["Seek Obstructions"] = "BypassSeekObstructions",
  ["Vacuum"] = "BypassVacuum",
  ["Snare"] = "BypassSnare",
}


local function syncAntiEntity()
  local master = toggles.AntiEntityMaster and toggles.AntiEntityMaster.Value
  local selected = options.AntiEntityList and options.AntiEntityList.Value or {}
  for name, flag in pairs(AntiEntityMapping) do
    local isEnabled = master and (selected[name] == true)
    if toggles[flag] then
      toggles[flag]:SetValue(isEnabled)
    end
  end
end


local worldObjects = {
  Entities = {}, EventTriggers = {}, Obstructions = {}, HidingSpots = {}, SeekObstructions = {}, SeekBridges = {}, SeekNodes = {}, SeekDuckBoards = {}, SeekHighlights = {}, EyestalkHighlights = {}, PathLights = {}, }

EntityNames = {
  GiggleCeiling = true, DoorFake = true, FakeDoor = true, GloombatEgg = true, GloombatEggs = true, Snare = true, Figure = true, FigureRig = true, FigureRagdoll = true, GloomPile = true, TriggerEventCollision = true, Seek_Arm = true, ChandelierObstruction = true, SeekFloodline = true, Bridge = true, MinecartRig = true, RunnerNodes = true, DuckBoard = true, PathLights = true, SeekMovingNewClone = true, SideroomSpace = true, MandrakeLive = true, }

local function handleEntity(entity)
  if not entity or not entity.Parent then
    return
  end

  local name = entity.Name

  if not EntityNames[name] then
    return
  end

  if name == "GiggleCeiling" then
    table.insert(worldObjects.Entities, entity)

    if toggles.BypassGiggle.Value then
      local hitbox = entity:WaitForChild("Hitbox")
      hitbox.CanTouch = false
    end
  elseif name == "DoorFake" or name == "FakeDoor" then
    if entity.Parent and entity:FindFirstChild("Hidden") then
      if toggles.BypassDupe.Value then
        entity:WaitForChild("Hidden").CanTouch = false
        local lock = entity:FindFirstChild("Lock")

        if lock and lock:FindFirstChild("UnlockPrompt") then
          lock.UnlockPrompt.Enabled = false
        end
      end

      if toggles.EntitiesESP.Value then
        local value = options.EntitiesESPAllowed and options.EntitiesESPAllowed.Value

        if not value or next(value) == nil or value.Dupe then
          Functions.AddESP({
            Object = entity, Text = "Dupe", Color = options.EntitiesESPColor.Value, })
        end
      end

      table.insert(worldObjects.Entities, entity)
    end
  elseif name == "SideroomSpace" then
    if toggles.BypassVacuum.Value then
      entity:WaitForChild("Collision").CanCollide = true
      entity:WaitForChild("Collision").CanTouch = false
    end

    table.insert(worldObjects.Entities, entity)
  elseif name == "GloombatEgg" or name == "GloombatEggs" or name == "GloomPile" then
    if toggles.BypassGloombatEggs.Value then
      for _, descendant in entity:GetDescendants() do
        if descendant:IsA("BasePart") then
          descendant.CanTouch = false
        end
      end
    end

    local connection = entity.DescendantAdded:Connect(function(descendant)
      if descendant:IsA("BasePart") then
        descendant.CanTouch = false
      end
    end)

    table.insert(worldObjects.Entities, entity)
  elseif name == "Snare" then
    for _, descendant in entity:GetDescendants() do
      if descendant:IsA("BasePart") then
        descendant.CanTouch = not toggles.BypassSnare.Value
      end
    end

    local connection = entity.DescendantAdded:Connect(function(descendant)
      if descendant:IsA("BasePart") then
        descendant.CanTouch = not toggles.BypassSnare.Value
      end
    end)

    table.insert(worldObjects.Entities, entity)

    if entity:FindFirstChild("Snare") then
      entity:WaitForChild("Snare"):WaitForChild("Roots").Transparency = 1
      entity:WaitForChild("Snare"):WaitForChild("SnareBase").Transparency = 1
    end

    if entity:FindFirstChild("Void") then
      entity.Void.Transparency = 0
      entity.Void.Color = Color3.fromRGB(76, 67, 55)
    end
  elseif name == "Figure" or name == "FigureRig" or name == "FigureRagdoll" then
    for _, descendant in entity:GetDescendants() do
      if descendant:IsA("BasePart") then
        descendant.CanTouch = false
      end
    end

    table.insert(worldObjects.Entities, entity)

    if (toggles.RemoveFigure and toggles.RemoveFigure.Value
        or toggles.RemoveFigureMines and toggles.RemoveFigureMines.Value)
      and Executor.isnetworkowner then
      local floorName = detectFloor()

      if floorName == "Mines" then
        for _, descendant in entity:GetDescendants() do
          local part = descendant

          if descendant:IsA("BasePart") then
            task.spawn(function()
              if pcall(function() return Executor.isnetworkowner(part) end) then
                part.Position = Vector3.new(-49999, -49999, -49999)
              end
            end)
          end
        end
      elseif floorName == "OldHotel" or floorName == "Fools" then
        local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

        if currentRooms2 then
          currentRooms2.ChildAdded:Wait()
        end

        for _, descendant in entity:GetDescendants() do
          local part = descendant

          if descendant:IsA("BasePart") then
            descendant.CanCollide = false

            task.spawn(function()
              while pcall(function() return Executor.isnetworkowner(part) end) do
                part.Position = Vector3.new(
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
    table.insert(worldObjects.EventTriggers, entity)
    table.insert(worldObjects.Entities, entity)
  elseif name == "Seek_Arm" or name == "ChandelierObstruction" then
    local function trackSeekObstruction(descendant)
      if descendant:IsA("BasePart") then
        descendant.CanTouch = not toggles.BypassSeekObstructions.Value
        table.insert(worldObjects.SeekObstructions, descendant)
      end
    end

    for _, descendant in entity:GetDescendants() do
      trackSeekObstruction(descendant)
    end

    entity.DescendantAdded:Connect(trackSeekObstruction)
  elseif name == "SeekFloodline" then
    entity.CanCollide = toggles.BypassSeekObstructions.Value

    local connection = entity:GetPropertyChangedSignal("CanCollide"):Connect(function()
      if entity.CanCollide ~= toggles.BypassSeekObstructions.Value then
        entity.CanCollide = toggles.BypassSeekObstructions.Value
      end
    end)

    entity.Destroying:Once(function() connection:Disconnect() end)
    table.insert(worldObjects.SeekObstructions, entity)
  elseif name == "Bridge" then
    for _, child in entity:GetChildren() do
      if child.Name == "PlayerBarrier" and child.Size.Y == 2.75
        and (child.Rotation.X == 0 or child.Rotation.X == 180) then
        local clone = child:Clone()
        clone.CFrame = clone.CFrame * CFrame.new(0, 0, -5)
        clone.Name = tostring(math.random(100000000, 999999999))
        clone.Size = Vector3.new(clone.Size.X, clone.Size.Y, 11)
        clone.Parent = entity
        clone.CanCollide = toggles.BypassSeekObstructions.Value
        clone.Color = Color3.fromRGB(0, 255, 255)
        clone.Transparency = toggles.BypassSeekObstructions.Value and 0 or 1
        clone.Material = Enum.Material.ForceField

        table.insert(worldObjects.SeekBridges, clone)
      end

      task.wait()
    end
  elseif name == "MinecartRig" then
    featureState.Minecart = entity
  elseif name == "RunnerNodes" then
    local function isTargetBehind(node, target)
      local position = (node.CFrame + node.CFrame.LookVector).Position
      local position2 = (node.CFrame + node.CFrame.LookVector * -1).Position
      return (position - target.Position).Magnitude > (position2 - target.Position).Magnitude
    end

    local function getTurnDirection(node, target)
      local dot = node.CFrame.RightVector:Dot(node.Position - target.Position)

      if dot > 0.5 then
        return isTargetBehind(node, target) and "Right" or "Left"
      end

      if dot < -0.5 then
        return isTargetBehind(node, target) and "Left" or "Right"
      end

      return "Straight"
    end

    local function findNextMinecartNode(child2)
      local closestNode, huge = nil, math.huge
      local numVal = tonumber(child2.Name:split("MinecartNode")[2])

      for _, child in entity:GetChildren() do
        local number = tonumber(child.Name:split("MinecartNode")[2])

        if child ~= child2 and number and numVal and number > numVal then
          local magnitude = (child2.Position - child.Position).Magnitude

          if magnitude < huge and child:GetAttribute("DistanceBlacklist") ~= true then
            huge = magnitude
            closestNode = child
          end
        end
      end

      return closestNode
    end

    for _, child in entity:GetChildren() do
      local number = tonumber(child.Name:split("MinecartNode")[2])

      if child:GetAttribute("DeathType") then
        child:SetAttribute("DistanceBlacklist", true)
      end

      for i = 1, 20 do
        local findFirstChild = number and entity:FindFirstChild("MinecartNode" .. number + i)

        if findFirstChild and findFirstChild:GetAttribute("DeathType") ~= nil then
          child:SetAttribute("DistanceBlacklist", true)
        end
      end

      local findFirstChild = number and entity:FindFirstChild("MinecartNode" .. number - 1)

      if findFirstChild and findFirstChild:GetAttribute("ForceConnect") then
        child:SetAttribute("DistanceBlacklist", nil)
      end

      task.wait()
    end

    for _, child in entity:GetChildren() do
      if child:GetAttribute("ForceConnect") then
        local nextNode = findNextMinecartNode(child)

        if nextNode then
          child:SetAttribute("Turn", getTurnDirection(child, nextNode))
          table.insert(worldObjects.SeekNodes, child)
        end
      end

      task.wait()
    end
  elseif name == "DuckBoard" then
    table.insert(worldObjects.SeekDuckBoards, entity)
  elseif name == "PathLights" then
    local pendingChildren = {}
    local connection = entity.ChildAdded:Connect(function(child) table.insert(pendingChildren, child) end)

    for _, child in entity:GetChildren() do
      table.insert(pendingChildren, child)
    end

    local onLightAdded

    local function markSeekGuidingLight(light)
      if light.Name ~= "SeekGuidingLight" or light:GetAttribute("Highlighted") then
        return
      end

      light:SetAttribute("Highlighted", true)

      local seekLightNode = Instance.new("Part")
      seekLightNode.Size = Vector3.one
      seekLightNode.Transparency = 1
      seekLightNode.Parent = featureState.SeekNodesFolder
      seekLightNode.Anchored = true
      seekLightNode.CFrame = light.CFrame
      seekLightNode.CanCollide = false
      seekLightNode.Name = "SeekLightNode"

      local seekLightNode2 = onLightAdded or seekLightNode
      onLightAdded = seekLightNode
      local beam = Instance.new("Beam")

      local value = rawget(toggles, "ShowSeekPathColor") and options.ShowSeekPathColor.Value
        or Color3.fromRGB(0, 255, 0)

      beam.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, value), ColorSequenceKeypoint.new(1, value), })

      beam.FaceCamera = true
      beam.Width0 = 0.2
      beam.Width1 = 0.2
      beam.Brightness = 10
      beam.LightInfluence = 0
      beam.LightEmission = 0
      beam.Enabled = true

      local pathVisible = rawget(toggles, "ShowSeekPathToggle") and toggles.ShowSeekPathToggle.Value
          and 0
        or 1

      beam.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, pathVisible), NumberSequenceKeypoint.new(1, pathVisible), })

      beam.Parent = featureState.SeekNodesFolder

      local instance = Instance.new("Attachment", seekLightNode)
      local instance2 = Instance.new("Attachment", seekLightNode2)

      beam.Attachment0 = instance
      beam.Attachment1 = instance2

      table.insert(worldObjects.SeekHighlights, beam)
    end

    task.spawn(function()
      while task.wait() do
        local nextLight = table.remove(pendingChildren, 1)

        if nextLight then
          markSeekGuidingLight(nextLight)
        end
      end
    end)

    table.insert(Connections, connection)
    table.insert(worldObjects.PathLights, entity)

    entity.Destroying:Once(function() connection:Disconnect() end)
  elseif name == "SeekMovingNewClone" then
    local connection = entity.Destroying:Connect(function()
      for _, _ in pairs(worldObjects.PathLights) do
      end

      if featureState.SeekNodesFolder then
        featureState.SeekNodesFolder:ClearAllChildren()
      end
    end)
  elseif name == "MandrakeLive" then
    local mandrake = entity:FindFirstChild("Mandrake")

    if mandrake then
      local root = mandrake:FindFirstChild("Root")

      if root then
        table.insert(worldObjects.Entities, entity.Hole)
        table.insert(worldObjects.Entities, root)

        if toggles.RemoveMandrake and toggles.RemoveMandrake.Value then
          local antiMandrakeForce = root:FindFirstChild("AntiMandrakeForce")

          if not antiMandrakeForce then
            antiMandrakeForce = Instance.new("BodyForce")
            antiMandrakeForce.Name = "AntiMandrakeForce"
            antiMandrakeForce.Parent = root
          end

          antiMandrakeForce.Force = Vector3.new(100000, -99999999, 100000)
        end
      end
    end
  end
end

for _, descendant in workspace:GetDescendants() do
  task.spawn(handleEntity, descendant)
end

workspace.DescendantAdded:Connect(handleEntity)

local function handleVineDoor(vineDoor)
  if vineDoor.Name ~= "ForgetMeNotVineDoors" then
    return
  end

  if not (vineDoor.Parent and localPlayer and vineDoor.Parent.Name == localPlayer.Name) then
    return
  end

  task.spawn(function()
    local waitForChild = vineDoor:WaitForChild("Base", 10)

    if not waitForChild then
      return
    end

    local deadline = tick() + 15

    while waitForChild.Parent and vineDoor.Parent and not waitForChild:GetAttribute("BaseDirection")
      and tick() < deadline do
      task.wait(0.2)
    end

    if waitForChild.Parent and vineDoor.Parent and waitForChild:GetAttribute("BaseDirection") then
      if toggles.EntitiesESP and toggles.EntitiesESP.Value then
        Functions.AddESP({
          Object = waitForChild, Text = "Wrong Door", Color = options.EntitiesESPColor and options.EntitiesESPColor.Value
            or Color3.fromRGB(255, 0, 0), })
      end
    end
  end)
end

for _, descendant in workspace:GetDescendants() do
  task.spawn(handleVineDoor, descendant)
end

workspace.DescendantAdded:Connect(handleVineDoor)

function Handlers.BypassGiggleChanged(value)
  for _, entity in ipairs(worldObjects.Entities) do
    if entity.Name == "GiggleCeiling" then
      local hitbox = entity:FindFirstChild("Hitbox")

      if hitbox then
        hitbox.CanTouch = not value
      end
    end
  end
end


function Handlers.BypassDupeChanged(value)
  for _, entity in worldObjects.Entities do
    if entity.Name == "DoorFake" or entity.Name == "FakeDoor" then
      entity:WaitForChild("Hidden").CanTouch = not value

      if entity:FindFirstChild("Lock") then
        entity.Lock.UnlockPrompt.Enabled = not value
      end
    end
  end
end


function Handlers.BypassEyesChanged(value)
  if value and featureState.IsEyes then
    local floorName = detectFloor()

    if floorName == "Fools" or floorName == "OldHotel" then
      remotesFolder.MotorReplication:FireServer(
        0, featureState.SpoofOffset == 200 and 65 or -65, 0, false
      )
    else
      remotesFolder.MotorReplication:FireServer(-650)
    end
  end
end


function Handlers.BypassLookmanChanged(value)
  if value and featureState.IsLookman then
    local floorName = detectFloor()

    if floorName == "Fools" or floorName == "OldHotel" then
      remotesFolder.MotorReplication:FireServer(
        0, featureState.SpoofOffset == 200 and 65 or -65, 0, false
      )
    else
      remotesFolder.MotorReplication:FireServer(-650)
    end
  end
end


function Handlers.BypassGloombatEggsChanged(value)
  for _, entity in ipairs(worldObjects.Entities) do
    if entity.Name == "GloombatEgg" or entity.Name == "GloombatEggs"
      or entity.Name == "GloomPile" then
      for _, descendant in entity:GetDescendants() do
        if descendant:IsA("BasePart") then
          descendant.CanTouch = not value
        end
      end
    end
  end
end


function Handlers.BypassSeekObstructionsChanged(value)
  for _, seekObstruction in ipairs(worldObjects.SeekObstructions) do
    seekObstruction.CanTouch = not value

    if seekObstruction.Name == "SeekFloodline" then
      seekObstruction.CanCollide = value
    end
  end

  for _, seekBridge in ipairs(worldObjects.SeekBridges) do
    seekBridge.CanCollide = value
    seekBridge.Transparency = value and 0 or 1
  end
end


function Handlers.BypassVacuumChanged(value)
  for _, entity in worldObjects.Entities do
    if entity.Name == "SideroomSpace" then
      entity:WaitForChild("Collision").CanCollide = value
      entity:WaitForChild("Collision").CanTouch = not value
    end
  end
end


function Handlers.BypassSnareChanged(value)
  for _, entity in ipairs(worldObjects.Entities) do
    if entity.Name == "Snare" then
      for _, descendant in entity:GetDescendants() do
        if descendant:IsA("BasePart") then
          descendant.CanTouch = not value
        end
      end
    end
  end
end


local RemoveMapping = {
  ["A-90"] = "RemoveA90",
  ["Dread"] = "RemoveDread",
  ["Footstep Sounds"] = "RemoveFootstepSounds",
  ["Jammin Music"] = "RemoveJamminMusic",
  ["Interacting Sounds"] = "RemoveInteractingSounds",
  ["Haste Sound"] = "RemoveHasteSound",
  ["Closet Delay"] = "RemoveClosetDelay",
}


local function syncRemove()
  local master = toggles.RemoveMaster and toggles.RemoveMaster.Value
  local selected = options.RemoveList and options.RemoveList.Value or {}
  for name, flag in pairs(RemoveMapping) do
    local isEnabled = master and (selected[name] == true)
    if toggles[flag] then
      toggles[flag]:SetValue(isEnabled)
    end
  end
end


local function disableScreechModule(moduleScript)
  if not moduleScript or not moduleScript:IsA("ModuleScript") then
    return
  end
  pcall(function()
    local mod = require(moduleScript)
    local target = nil
    if type(mod) == "function" then
      target = mod
    elseif type(mod) == "table" then
      for k, v in pairs(mod) do
        if type(v) == "function" and (Executor.hookfunction or RootEnv.hookfunction or RootEnv.replaceclosure) then
          local hooker = Executor.hookfunction or RootEnv.hookfunction or RootEnv.replaceclosure
          pcall(function()
            hooker(v, function(...)
              if toggles.RemoveScreech and toggles.RemoveScreech.Value then
                return
              end
              return v(...)
            end)
          end)
        end
      end
    end

    if target and (Executor.hookfunction or RootEnv.hookfunction or RootEnv.replaceclosure) then
      local hooker = Executor.hookfunction or RootEnv.hookfunction or RootEnv.replaceclosure
      pcall(function()
        hooker(target, function(...)
          if toggles.RemoveScreech and toggles.RemoveScreech.Value then
            return
          end
          return target(...)
        end)
      end)
    end
  end)
end

local function setScreechConnections(enabled)
  pcall(function()
    local realRemote = (FakeEvents and FakeEvents.Screech_Real) or (remotesFolder and remotesFolder:FindFirstChild("Screech"))
    local getconns = Executor.getconnections or RootEnv.getconnections
    if realRemote and getconns then
      for _, conn in ipairs(getconns(realRemote.OnClientEvent)) do
        pcall(function()
          if enabled then
            conn:Enable()
          else
            conn:Disable()
          end
        end)
      end
    end
  end)
end

function Handlers.RemoveScreechChanged(Value)
  setScreechConnections(not Value)

  local remoteModules = getRemoteModules()
  if remoteModules then
    local screech = remoteModules:FindFirstChild("Screech") or remoteModules:FindFirstChild("Screech_Disabled")
    if screech then
      screech.Name = Value and "Screech_Disabled" or "Screech"
      if Value then
        disableScreechModule(screech)
      end
    end
  end

  local clientModules = replicatedStorage:FindFirstChild("ModulesClient") or replicatedStorage:FindFirstChild("ClientModules")
  local entityModules = clientModules and clientModules:FindFirstChild("EntityModules")
  if entityModules then
    local screechM = entityModules:FindFirstChild("Screech") or entityModules:FindFirstChild("Screech_Disabled")
    if screechM then
      screechM.Name = Value and "Screech_Disabled" or "Screech"
      if Value then
        disableScreechModule(screechM)
      end
    end
  end

  local floorRep = replicatedStorage:FindFirstChild("FloorReplicated")
  if floorRep then
    local glitchScreech = floorRep:FindFirstChild("GlitchScreech", true) or floorRep:FindFirstChild("GlitchScreech_Disabled", true)
    if glitchScreech then
      glitchScreech.Name = Value and "GlitchScreech_Disabled" or "GlitchScreech"
      if Value then
        disableScreechModule(glitchScreech)
      end
    end
  end

  if remotesFolder and FakeEvents then
    if Value then
      if FakeEvents.Screech_Real and FakeEvents.Screech_Real.Parent then
        FakeEvents.Screech.Parent = remotesFolder
        FakeEvents.Screech_Real.Parent = nil
      end
    elseif not (toggles.NoScreechDamage and toggles.NoScreechDamage.Value) then
      if FakeEvents.Screech_Real then
        FakeEvents.Screech_Real.Parent = remotesFolder
        FakeEvents.Screech.Parent = nil
      end
    end
  end

  if Value then
    task.spawn(function()
      local handledScreech = {}
      while toggles.RemoveScreech and toggles.RemoveScreech.Value do
        local camera = workspace.CurrentCamera or workspace:FindFirstChild("Camera")
        if camera then
          local screech = camera:FindFirstChild("Screech")
          if screech and not handledScreech[screech] then
            handledScreech[screech] = true

            pcall(function() runService:UnbindFromRenderStep("Screech") end)
            pcall(function() runService:UnbindFromRenderStep("screech") end)
            pcall(function() runService:UnbindFromRenderStep("ScreechFollow") end)
            pcall(function() runService:UnbindFromRenderStep("ScreechAttack") end)
            pcall(function() runService:UnbindFromRenderStep("ScreechCamera") end)
            pcall(function() runService:UnbindFromRenderStep("ScreechLoop") end)

            pcall(function() screech:PivotTo(CFrame.new(0, -50000, 0)) end)

            for _, v in ipairs(screech:GetDescendants()) do
              pcall(function()
                if v:IsA("BasePart") then
                  v.Transparency = 1
                  v.CanCollide = false
                elseif v:IsA("Sound") then
                  v.Volume = 0
                  v:Stop()
                elseif v:IsA("ParticleEmitter") or v:IsA("Light") or v:IsA("BillboardGui") then
                  v.Enabled = false
                end
              end)
            end

            pcall(function()
              local rem = (remotesFolder and remotesFolder:FindFirstChild("Screech")) or (FakeEvents and FakeEvents.Screech_Real)
              if rem then
                rem:FireServer(true)
              end
            end)

            task.delay(0.5, function()
              pcall(function()
                if screech and screech.Parent then
                  screech:Destroy()
                end
              end)
              handledScreech[screech] = nil
            end)
          end
        end
        task.wait()
      end
    end)
  end
end


function Handlers.RemoveHaltChanged(Value)
  local clientModules = replicatedStorage:FindFirstChild("ModulesClient") or replicatedStorage:FindFirstChild("ClientModules")
  local entityModules = clientModules and clientModules:FindFirstChild("EntityModules")
  if entityModules then
    local shade = entityModules:FindFirstChild("Shade") or entityModules:FindFirstChild("Shade_Disabled")
    if shade then
      shade.Name = Value and "Shade_Disabled" or "Shade"
    end
  end

  local remoteModules = getRemoteModules()
  if remoteModules then
    local shade = remoteModules:FindFirstChild("Shade") or remoteModules:FindFirstChild("Shade_Disabled")
    if shade then
      shade.Name = Value and "Shade_Disabled" or "Shade"
    end
  end
end


function Handlers.RemoveA90Changed(value)
  local remoteModules = getRemoteModules()

  if not remoteModules then
    return
  end

  local a90Module = remoteModules:FindFirstChild("A90")

  if a90Module then
    a90Module.Name = value and "A90_Disabled" or "A90"
  end
end


function Handlers.RemoveDreadChanged(value)
  local remoteModules = getRemoteModules()

  if not remoteModules then
    return
  end

  local dread = remoteModules:FindFirstChild("Dread")

  if dread then
    dread.Name = value and "Dread_Disabled" or "Dread"
  end
end


function Handlers.RemoveFootstepSoundsChanged(value)
  local character2 = localPlayer.Character

  if not character2 then
    return
  end

  for _, descendant in character2:GetDescendants() do
    if descendant:IsA("Sound") and descendant.Name == "Sound" then
      descendant.Volume = value and 0 or 1
    end
  end
end


function Handlers.RemoveJamminMusicChanged(value)
  local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")
  local mainUI = playerGui2 and playerGui2:FindFirstChild("MainUI")
  local initiator = mainUI and mainUI:FindFirstChild("Initiator")
  local mainGame = initiator and initiator:FindFirstChild("Main_Game")

  if not mainGame then
    return
  end

  local health = mainGame:FindFirstChild("Health")

  if not health then
    return
  end

  local jam = health:FindFirstChild("Jam")

  if jam then
    jam.Volume = value and 0 or 0.45
  end
end


function Handlers.RemoveInteractingSoundsChanged(value)
  local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")
  local mainUI = playerGui2 and playerGui2:FindFirstChild("MainUI")
  local initiator = mainUI and mainUI:FindFirstChild("Initiator")
  local mainGame = initiator and initiator:FindFirstChild("Main_Game")

  if not mainGame then
    return
  end

  local promptService = mainGame:FindFirstChild("PromptService")

  if promptService then
    local triggered = promptService:FindFirstChild("Triggered")

    if triggered then
      triggered.Volume = value and 0 or 0.04
    end

    local holding = promptService:FindFirstChild("Holding")

    if holding then
      holding.Volume = value and 0 or 0.1
    end

    local notification = promptService:FindFirstChild("Notification")

    if notification then
      notification.Volume = value and 0 or 0.03
    end
  end

  local reminder = mainGame:FindFirstChild("Reminder")

  if reminder then
    local caption = reminder:FindFirstChild("Caption")

    if caption then
      caption.Volume = value and 0 or 0.1
    end
  end
end


local NoDamageMapping = {
  ["Screech"] = "NoScreechDamage",
  ["A-90"] = "NoA90Damage",
  ["Halt"] = "NoHaltDamage",
}


local function syncNoDamage()
  local master = toggles.NoDamageMaster and toggles.NoDamageMaster.Value
  local selected = options.NoDamageList and options.NoDamageList.Value or {}
  for name, flag in pairs(NoDamageMapping) do
    local isEnabled = master and (selected[name] == true)
    if toggles[flag] then
      toggles[flag]:SetValue(isEnabled)
    end
  end
end


function Handlers.NoScreechDamageChanged(value)
  if not remotesFolder then
    return
  end

  if value then
    if FakeEvents.Screech_Real and FakeEvents.Screech_Real.Parent then
      FakeEvents.Screech.Parent = remotesFolder
      FakeEvents.Screech_Real.Parent = nil
    end
  elseif FakeEvents.Screech_Real then
    FakeEvents.Screech_Real.Parent = remotesFolder
    FakeEvents.Screech.Parent = nil
  end
end


function Handlers.NoHaltDamageChanged(value)
  if not remotesFolder then
    return
  end

  if value then
    if FakeEvents.Shade_Real and FakeEvents.Shade_Real.Parent then
      FakeEvents.Shade.Parent = remotesFolder
      FakeEvents.Shade_Real.Parent = nil
    end
  elseif FakeEvents.Shade_Real then
    FakeEvents.Shade_Real.Parent = remotesFolder
    FakeEvents.Shade.Parent = nil
  end
end


function Handlers.NoA90DamageChanged(value)
  if not remotesFolder then
    return
  end

  if value then
    if FakeEvents.A90_Real and FakeEvents.A90_Real.Parent then
      FakeEvents.A90.Parent = remotesFolder
      FakeEvents.A90_Real.Parent = nil
    end
  elseif FakeEvents.A90_Real then
    FakeEvents.A90_Real.Parent = remotesFolder
    FakeEvents.A90.Parent = nil
  end
end


function Handlers.ShowLibraryCode()
  local functions = Functions.GetLibraryCode()

  if functions then
    library:Notify({ Title = "Library code: " .. functions, Time = 5 })
  else
    library:Notify({ Title = "Could not read library code", Time = 5 })
  end
end


if replicatedStorage:FindFirstChild("FloorReplicated")
  and replicatedStorage.FloorReplicated:FindFirstChild("ClientRemote")
  and replicatedStorage.FloorReplicated.ClientRemote:FindFirstChild("Haste") then
  local connection = replicatedStorage.FloorReplicated.ClientRemote.Haste.Ambience:GetPropertyChangedSignal("Playing"):Connect(function()
    if toggles.RemoveHasteSound.Value then
      replicatedStorage.FloorReplicated.ClientRemote.Haste.Ambience.Playing = false
    end
  end)
end

table.insert(Connections, workspace.DescendantAdded:Connect(function(descendant)
  if toggles.AntiLag and toggles.AntiLag.Value and descendant:IsA("BasePart") then
    descendant:SetAttribute("Mat", descendant.Material)
    descendant.Material = "Plastic"
  end
end))

featureState = {
  UseAnimation = nil, UseAnimationBreak = nil, BreakerBoxNotified = false, BreakerBoxStartNotified = false, BreakerBoxInteracted = false, BreakerBoxFinishedNotified = false, FogInstances = {}, OldFog = nil, InLobby = false, LobbyGuardConnection = nil, RoomsAutoWalkActive = false, IsEyes = false, IsLookman = false, AnticheatDisabled = false, SeekNodesFolder = nil, AutoMinecartDucked = false, LastDuck = 0, NearestTurnNode = nil, Minecart = nil, OriginalGetMoveVector = nil, SurgeFrame = nil, KnobFarmActive = false, KnobFarmStarted = false, UILibrary = uiLibrary, RedeemingCodes = false, SpoofOffset = 0, }

featureState.CodesList = {
  "67", "54", "41", "CHEDDAR BALLS", "XQC", "PENGUINZ0", "KREEKCRAFT", "ISHOWSPEED", "DANTDM", "KUBZ SCOUTS", "FIND THE TROLLFACES", "THINKNOODLES", "W", "RAGDOLL UNIVERSE", "RAGDOLL MAYHEM", "BIJUU MIKE", "8BITRYAN", "SCREECHSUCKS", "LORE", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "FIND THE TROLLFACES", "3rd", "LAZYDEVS", "RAGDOLL COMBAT", "VOCAB HAVOC", "PATHSWAP", "JUMP OVER THE BRICK", }

if character then
  task.spawn(SetupCharacterAnticheat)
end

if Executor.fireproximityprompt then
  Functions.FirePrompt = Executor.fireproximityprompt
  Functions.ForceFirePrompt = Executor.fireproximityprompt
else
  local queue = {}
  local firedPrompts = {}

  function Functions.FirePrompt(prompt)
    if not prompt:IsA("ProximityPrompt") or firedPrompts[prompt] or not currentCamera then
      return
    end

    table.insert(queue, prompt)
  end

  Functions.ForceFirePrompt = Functions.FirePrompt

  task.spawn(function()
    while task.wait() do
      local parent = table.remove(queue, 1)

      if parent then
        firedPrompts[parent] = true
        local parent2 = parent.Parent

        local origDist = parent:GetAttribute("MaxActivationDistance_Old") or parent.MaxActivationDistance
        local origHold = parent:GetAttribute("HoldDuration_Old") or parent.HoldDuration
        local origLOS = parent:GetAttribute("RequiresLineOfSight_Old") or parent.RequiresLineOfSight
        local origEnabled = parent.Enabled

        parent.MaxActivationDistance = 99999
        parent.Enabled = true
        parent.HoldDuration = 0
        parent.RequiresLineOfSight = false

        local part = Instance.new("Part")
        part.Parent = workspace
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.Anchored = true
        part.Transparency = 1
        part.Size = Vector3.new(0.001, 0.001, 0.001)
        part.Position = currentCamera.CFrame:ToWorldSpace(CFrame.new(0, 0, -0.1)).Position

        if parent and parent2 then
          pcall(function() parent.Parent = part end)
          local isShown, wasTriggered = false, false

          local connection = proximityPromptService.PromptShown:Connect(function(prompt)
            if prompt == parent then
              isShown = true
            end
          end)

          local connection2 = parent.Triggered:Connect(function() wasTriggered = true end)
          local count = 0

          while not isShown and count < 5 do
            count = count + 1
            task.wait()
          end

          local count2 = 0

          while not wasTriggered and count2 < 5 do
            parent:InputHoldBegin()
            parent:InputHoldEnd()

            count2 = count2 + 1
            task.wait()
          end

          parent.MaxActivationDistance = origDist
          parent.Enabled = origEnabled
          parent.HoldDuration = origHold
          parent.RequiresLineOfSight = origLOS

          pcall(function() parent.Parent = parent2 end)
          task.wait()
          connection:Disconnect()
          connection2:Disconnect()
        else
          part:Destroy()
        end

        firedPrompts[parent] = nil
      end
    end
  end)
end

function Functions.HasItem(itemName, includeEquipped)
  if not itemName then return nil end
  local char = localPlayer and localPlayer.Character
  local bp = localPlayer and localPlayer:FindFirstChildOfClass("Backpack")
  local hum = char and char:FindFirstChildOfClass("Humanoid")

  local aliases = { itemName }
  if itemName == "Lockpick" then
    table.insert(aliases, "Lockpicks")
  elseif itemName == "Lockpicks" then
    table.insert(aliases, "Lockpick")
  elseif itemName == "SkeletonKey" then
    table.insert(aliases, "Skeleton Key")
  elseif itemName == "Skeleton Key" then
    table.insert(aliases, "SkeletonKey")
  end

  -- 1. Check in Character (equipped)
  if char then
    for _, name in ipairs(aliases) do
      local it = char:FindFirstChild(name)
      if it then return it end
    end
    for _, it in ipairs(char:GetChildren()) do
      if it:IsA("Tool") then
        local iname = it.Name:lower()
        for _, name in ipairs(aliases) do
          if iname == name:lower() or iname:find(name:lower(), 1, true) then
            return it
          end
        end
      end
    end
  end

  -- 2. Check in Backpack
  if bp then
    for _, name in ipairs(aliases) do
      local it = bp:FindFirstChild(name)
      if it then
        if includeEquipped and hum then
          pcall(function() hum:EquipTool(it) end)
        end
        return it
      end
    end
    for _, it in ipairs(bp:GetChildren()) do
      if it:IsA("Tool") then
        local iname = it.Name:lower()
        for _, name in ipairs(aliases) do
          if iname == name:lower() or iname:find(name:lower(), 1, true) then
            if includeEquipped and hum then
              pcall(function() hum:EquipTool(it) end)
            end
            return it
          end
        end
      end
    end
  end

  return nil
end

function Functions.GetLibraryCode()
  local libraryHintPaper = character:FindFirstChild("LibraryHintPaper")
    or character:FindFirstChild("LibraryHintPaperHard")
    or localPlayer.Backpack:FindFirstChild("LibraryHintPaper")
    or localPlayer.Backpack:FindFirstChild("LibraryHintPaperHard")

  if libraryHintPaper and libraryHintPaper:FindFirstChild("UI") then
    local icons = {}

    for i = 1, CurrentFloor and tostring(CurrentFloor):find("Fools") and 10 or 5 do
      icons[i] = "_"
    end

    local getChildren = localPlayer.PlayerGui:FindFirstChild("PermUI")
        and localPlayer.PlayerGui.PermUI:FindFirstChild("Hints")
        and localPlayer.PlayerGui.PermUI.Hints:GetChildren()
      or {}

    local getChildren2 = libraryHintPaper.UI:GetChildren()

    for _, getChildrenEntry in ipairs(getChildren) do
      for _, other in ipairs(getChildren2) do
        if getChildrenEntry:IsA("ImageLabel") and other:IsA("ImageLabel")
          and getChildrenEntry.ImageRectOffset == other.ImageRectOffset
          and icons[tonumber(other.Name)] then
          icons[tonumber(other.Name)] = getChildrenEntry.TextLabel.Text
        end
      end
    end

    return table.concat(icons)
  end

  return CurrentFloor and tostring(CurrentFloor):find("Fools") and "__________" or "_____"
end

function Functions.HandleHidingTransparency(hidingSpot)
  local parts = {}

  for _, descendant2 in hidingSpot:GetDescendants() do
    if descendant2:IsA("BasePart") then
      descendant2:SetAttribute("Transparency_Old", descendant2.Transparency)
      table.insert(parts, descendant2)
    end

    if descendant2.Name == "HiddenPlayer" then
      local descendant = descendant2

      local connection = descendant:GetPropertyChangedSignal("Value"):Connect(function()
        for _, part in ipairs(parts) do
          if part:GetAttribute("Transparency_Old") then
            TweenService:Create(part, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
              Transparency = descendant.Value == character
                  and toggles.TransparentHidingSpotsToggle.Value
                  and options.TransparentHidingSpotsSlider.Value
                or part:GetAttribute("Transparency_Old"), }):Play()
          end
        end
      end)

      table.insert(Connections, connection)

      hidingSpot.Destroying:Once(function()
        connection:Disconnect()
        local _ = TableFind(Connections, connection)
      end)
    end
  end
end

function Functions.GetMinecart()
  return currentCamera:FindFirstChild("MinecartRig") ~= nil
end

function Functions.GetNearestTurnNode()
  local nearest = { Distance = math.huge, Object = nil }

  for _, seekNode in ipairs(worldObjects.SeekNodes) do
    local distanceFromCharacter = localPlayer:DistanceFromCharacter(seekNode.Position)

    if distanceFromCharacter < options.AutoSteerMinecartTurnDistance.Value
      and distanceFromCharacter < nearest.Distance then
      nearest.Distance = distanceFromCharacter
      nearest.Object = seekNode
    end
  end

  return nearest.Object
end

function Functions.GetNearestDuckBoard()
  local nearest = { Distance = math.huge, Object = nil }

  for _, seekDuckBoard in ipairs(worldObjects.SeekDuckBoards) do
    if seekDuckBoard.PrimaryPart then
      local distanceFromCharacter = localPlayer:DistanceFromCharacter(seekDuckBoard.PrimaryPart.Position)

      if distanceFromCharacter < options.AutoSteerMinecartDuckDistance.Value
        and distanceFromCharacter < nearest.Distance then
        nearest.Distance = distanceFromCharacter
        nearest.Object = seekDuckBoard
      end
    end
  end

  return nearest.Object
end

function Functions.SendChat(message)
  local defaultChat = replicatedStorage:FindFirstChild("DefaultChatSystemEvents") or Instance.new("Folder")
  local sayMessage = defaultChat:FindFirstChild("SayMessageRequest") or Instance.new("RemoteEvent")
  sayMessage:FireServer(message, "All")

  local textChannels = TextChatService:FindFirstChild("TextChannels")
  local rbxGeneral = textChannels and textChannels:FindFirstChild("RBXGeneral") or Instance.new("TextChannel")
  rbxGeneral:SendAsync(message)
end

function Functions.GetNearestHidingSpot()
  local nearest = { Distance = math.huge, Object = nil }

  for _, hidingSpot in ipairs(worldObjects.HidingSpots) do
    if hidingSpot.PrimaryPart and hidingSpot:FindFirstChild("HidePrompt") then
      local distanceFromCharacter = localPlayer:DistanceFromCharacter(hidingSpot.PrimaryPart.Position)

      if distanceFromCharacter < nearest.Distance
        and distanceFromCharacter < hidingSpot.HidePrompt.MaxActivationDistance
        and hidingSpot.PrimaryPart.Position.Y > -10 then
        local findFirstChild = hidingSpot:FindFirstChild("HiddenPlayer", true)

        if findFirstChild and not findFirstChild.Value then
          nearest.Distance = distanceFromCharacter
          nearest.Object = hidingSpot
        end
      end
    end
  end

  return nearest.Object
end

function Functions.GetNearestEntity(activeOnly, allowed)
  local entitySpeeds = {
    RushMoving = 85, AmbushMoving = 150, A60 = 125, A120 = 85, GlitchRush = 90, GlitchAmbush = 175, BackdoorRush = 85, CustomEntity = 85, }

  local nearest = { Distance = math.huge, Object = nil }

  for _, child in workspace:GetChildren() do
    if child and entitySpeeds[child.Name] and child.PrimaryPart then
      local entityData = EntityNotifyData[child.Name]

      if not (allowed and entityData and allowed[entityData.Alias]) then
        local distanceFromCharacter = localPlayer:DistanceFromCharacter(child.PrimaryPart.Position)

        if distanceFromCharacter < entitySpeeds[child.Name] and distanceFromCharacter < nearest.Distance then
          if not activeOnly or child:GetAttribute("Inactive") ~= true then
            nearest.Distance = distanceFromCharacter
            nearest.Object = child
          end
        end
      end
    end
  end

  return nearest.Object
end

local function installNamecallHook()
  if not Executor.hookmetamethod or not Executor.newcclosure or not Executor.getnamecallmethod then
    return
  end

  MainHook = Executor.hookmetamethod(game, "__namecall", Executor.newcclosure(function(self, ...)
    local args = { ... }
    local executor = Executor.getnamecallmethod()

    if executor == "BindToRenderStep" then
      local bindName = tostring(args[1] or "")
      local isScreechBinding = string.find(string.lower(bindName), "screech") ~= nil
      if not isScreechBinding and type(args[3]) == "function" then
        local src = ""
        pcall(function() src = debug.info(args[3], "s") or "" end)
        if string.find(string.lower(src), "screech") then
          isScreechBinding = true
        end
      end

      if isScreechBinding then
        if toggles.RemoveScreech and toggles.RemoveScreech.Value then
          return
        end
        local origCallback = args[3]
        if type(origCallback) == "function" then
          args[3] = function(...)
            local success, result = pcall(origCallback, ...)
            if success then
              return result
            end
          end
        end
      end
    end

    if self.Name == "Screech" and executor == "FireServer" then
      if (toggles.RemoveScreech and toggles.RemoveScreech.Value)
        or (toggles.NoScreechDamage and toggles.NoScreechDamage.Value) then
        return MainHook(self, true)
      end
    end

    if self.Name == "MotorReplication" and executor == "FireServer" then
      if toggles.BypassEyes.Value and featureState.IsEyes
        or toggles.BypassLookman.Value and featureState.IsLookman then
        local currentFloor = CurrentFloor

        if currentFloor == "Fools" or currentFloor == "OldHotel" then
          args[1] = 0
          args[2] = featureState.SpoofOffset == 200 and 65 or -65
          args[3] = 0
          args[4] = false
        else
          args[1] = -650
        end
      end
    end

    if self.Name == "Crouch" and executor == "FireServer" then
      if toggles.Godmode and toggles.Godmode.Value then
        args[1] = true
      end

      args[2] = true
    end

    if toggles.AutoHeartbeatMinigame and toggles.AutoHeartbeatMinigame.Value
      and executor == "FireServer" then
      if self.Name == "ClutchHeartbeat" then
        return MainHook(self, true)
      end

      if self.Name == "HideMonster" then
        return MainHook(self, true)
      end
    end

    if toggles.AntiDrone and toggles.AntiDrone.Value and executor == "FireServer" then
      if self.Name == "ShoulderChecked" or self.Name == "WalkedInto" then
        return
      end
    end

    if toggles.AntiRansom and toggles.AntiRansom.Value and executor == "FireServer" then
      if self.Name == "RansomAttack" then
        args[1] = "didnt"
      end
    end

    if toggles.AntiScribbles and toggles.AntiScribbles.Value and executor == "FireServer" then
      if self.Name == "IfYoureExploitingDeleteThis" then
        return
      end
    end

    local minecartTeleportState = featureState.MinecartTeleportState

    if minecartTeleportState and executor == "FireServer"
      and self == minecartTeleportState.MinecartPos then
      if minecartTeleportState.LatestRoom < 49 then
        local door = minecartTeleportState.GetDoor()

        if door then
          local getPivot = door:GetPivot()

          local minecartRig = workspace.CurrentCamera
            and workspace.CurrentCamera:FindFirstChild("MinecartRig")

          if minecartRig then
            minecartRig:PivotTo(getPivot)
          end

          pcall(function() door.ClientOpen:FireServer() end)
          args[1] = getPivot
        end
      else
        if minecartTeleportState.DecodeHook and minecartTeleportState.RestoreDecode then
          pcall(function() minecartTeleportState.RestoreDecode(minecartTeleportState.Decode) end)
        end

        if minecartTeleportState.LatestRoomConn then
          pcall(function() minecartTeleportState.LatestRoomConn:Disconnect() end)
        end

        featureState.MinecartTeleportState = nil
      end
    end

    return MainHook(self, table.unpack(args))
  end))

  OtherHook = Executor.hookmetamethod(game, "__index", Executor.newcclosure(function(target, key)
    local result = OtherHook(target, key)

    if key == "MoveDirection" and target == humanoid and featureState.RoomsAutoWalkActive
      and toggles.RoomsAutoWalkSpoofFootsteps.Value and CurrentFloor == "Rooms"
      and not (character and character:GetAttribute("Hiding")) then
      if humanoidRootPart then
        local velocity = humanoidRootPart.Velocity

        if velocity.Magnitude > 0.1 then
          return velocity.Unit
        end

        return humanoidRootPart.CFrame.LookVector
      end

      return result
    end

    return result
  end))

  pcall(function()
    local origBind = runService.BindToRenderStep
    runService.BindToRenderStep = function(self, name, priority, callback)
      local bindName = tostring(name or "")
      local isScreech = string.find(string.lower(bindName), "screech") ~= nil
      if not isScreech and type(callback) == "function" then
        local src = ""
        pcall(function() src = debug.info(callback, "s") or "" end)
        if string.find(string.lower(src), "screech") then
          isScreech = true
        end
      end

      if isScreech then
        if toggles.RemoveScreech and toggles.RemoveScreech.Value then
          return
        end
        local origCb = callback
        if type(origCb) == "function" then
          callback = function(...)
            local success, result = pcall(origCb, ...)
            if success then return result end
          end
        end
      end
      return origBind(self, name, priority, callback)
    end
  end)
end

installNamecallHook()

local function handleRoomObject(object)
  local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

  if currentRooms2 and object.Parent == currentRooms2 then
    local firedamp = object:GetAttribute("Firedamp")
    object:SetAttribute("Firedamp_Old", firedamp ~= nil and firedamp or false)

    if toggles.DisableFiredampEffect.Value then
      object:SetAttribute("Firedamp", false)
    end
  end

  local name = object.Name

  if name == "Padlock" then
    Connections.PadlockConnection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if object.PrimaryPart then
        local distanceFromCharacter = localPlayer:DistanceFromCharacter(object.PrimaryPart.Position)

        if toggles.AutoUnlockPadlockToggle.Value then
          local functions = Functions.GetLibraryCode()

          if functions and tonumber(functions) and distanceFromCharacter < 50 then
            remotesFolder.PL:FireServer(functions)
          end
        end

        if toggles.AutoLibraryBruteForce.Value and distanceFromCharacter < 50 then
          local functions = Functions.GetLibraryCode()

          if functions and string.find(functions, "_") then
            local text = ""

            for i = 1, #functions do
              local substring = string.sub(functions, i, i)
              text = text .. (substring == "_" and math.random(0, 9) or substring)
            end

            if remotesFolder and remotesFolder:FindFirstChild("PL") then
              remotesFolder.PL:FireServer(text)
            end

            featureState.BruteForceCount = (featureState.BruteForceCount or 0) + 1

            if featureState.BruteForceCount % 750 == 0 then
              task.spawn(function()
                library:Notify({
                  Title = "Brute-force: checked " .. featureState.BruteForceCount .. " codes", Description = "Not found yet", Time = 2, })
              end)
            end
          end
        end
      end
    end)

    object.Destroying:Once(function()
      if featureState.BruteForceCount and featureState.BruteForceCount > 0 then
        task.spawn(function()
          library:Notify({
            Title = "Padlock code found after " .. featureState.BruteForceCount .. " attempts!", Description = "yay", Time = 5, })
        end)
      end

      featureState.BruteForceCount = nil

      if Connections.PadlockConnection then
        Connections.PadlockConnection:Disconnect()
        Connections.PadlockConnection = nil
      end
    end)
  elseif name == "ElevatorBreaker" then
    if toggles.AutoBreakerBox.Value and not featureState.BreakerBoxNotified then
      featureState.BreakerBoxNotified = true
    end

    local code = object:WaitForChild("SurfaceGui"):WaitForChild("Frame"):WaitForChild("Code")

    local function waitLoop()
      if toggles.AutoBreakerBox.Value then
        local breakerBoxMethod = options.BreakerBoxMethod and options.BreakerBoxMethod.Value or "Instant"

        if breakerBoxMethod == "Instant" then
          task.spawn(function()
            task.wait(1)

            pcall(function()
              if remotesFolder and remotesFolder:FindFirstChild("EBF") then
                remotesFolder.EBF:FireServer()
              end
            end)
          end)
        elseif breakerBoxMethod == "Legit" then
          local number = tonumber(code.Text)

          if not number then
            return
          end

          for _, descendant in object:GetDescendants() do
            if descendant.Name == "BreakerSwitch" and descendant:GetAttribute("ID") == number then
              local backgroundTransparency = code:WaitForChild("Frame").BackgroundTransparency
              local prismaticConstraint = descendant:FindFirstChild("PrismaticConstraint")
              local light = descendant:FindFirstChild("Light")
              local sound = descendant:FindFirstChild("Sound")

              if backgroundTransparency == 0 then
                if descendant:GetAttribute("Enabled") then
                  return
                end

                descendant:SetAttribute("Enabled", true)

                if prismaticConstraint then
                  prismaticConstraint.TargetPosition = -0.2
                end

                if light then
                  light.Material = Enum.Material.Neon
                  local findFirstChild = light:FindFirstChild("Spark", true)

                  if findFirstChild then
                    findFirstChild:Emit(1)
                  end
                end

                if sound then
                  sound:Play()
                end
              elseif backgroundTransparency == 1 then
                if not descendant:GetAttribute("Enabled") then
                  return
                end

                descendant:SetAttribute("Enabled", false)

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

        if not featureState.BreakerBoxStartNotified then
          featureState.BreakerBoxStartNotified = true
        end
      end

      featureState.BreakerBoxInteracted = true
    end

    Connections.BreakerConnection = code:GetPropertyChangedSignal("Text"):Connect(waitLoop)
    featureState.RunBreakerFunc = waitLoop
    object.Destroying:Once(function() featureState.RunBreakerFunc = nil end)
  elseif name == "ElevatorCar" then
    local connection = object.DescendantAdded:Connect(function(descendant)
      if toggles.AutoBreakerBox.Value and descendant.Name == "TouchInterest"
        and not featureState.BreakerBoxFinishedNotified then
        featureState.BreakerBoxFinishedNotified = true
      end
    end)

    object.Destroying:Once(function() connection:Disconnect() end)
  end
end

_promptTriggerLock = false

function Handlers.InfiniteCrucifixChanged(value)
  if not value then
    return
  end

  if featureState.InfCrucifixRunning then
    return
  end

  featureState.InfCrucifixRunning = true

  task.spawn(function()
    local entityRanges = {
      RushMoving = 49, AmbushMoving = 50, A60 = 49, A120 = 50, BackdoorRush = 49, }

    local function findGuidingObject()
      for entityName in pairs(entityRanges) do
        local findFirstChild = workspace:FindFirstChild(entityName)
          or workspace:FindFirstChild(entityName, true)

        if findFirstChild and (findFirstChild:IsA("BasePart") or findFirstChild:IsA("Model")) then
          return findFirstChild, entityName
        end
      end
    end

    local function isNearGuidingObject()
      local entityObject, entityKey = findGuidingObject()

      local humanoidRootPart2 = localPlayer.Character
        and localPlayer.Character:FindFirstChild("HumanoidRootPart")

      if not entityObject or not humanoidRootPart2 then
        return false
      end

      return (entityObject:GetPivot().Position - humanoidRootPart2.Position).Magnitude < entityRanges[entityKey]
    end

    local function findNearbyCrucifix(rootPart)
      local drops = workspace:FindFirstChild("Drops")

      if drops then
        for _, child in drops:GetChildren() do
          if child.Name == "Crucifix" then
            return child
          end
        end
      end

      for _, descendant in workspace:GetDescendants() do
        if descendant:IsA("Model") and descendant.Name == "Crucifix"
          and not descendant:IsDescendantOf(localPlayer.Character) then
          if (descendant:GetPivot().Position - rootPart.Position).Magnitude < 25 then
            return descendant
          end
        end
      end
    end

    while toggles.InfiniteCrucifix.Value do
      task.wait(0.1)
      local character2 = localPlayer.Character
      local tool = character2 and character2:FindFirstChildOfClass("Tool")

      if tool and tool.Name == "Crucifix" and isNearGuidingObject() then
        local humanoidRootPart2 = character2:FindFirstChild("HumanoidRootPart")

        if humanoidRootPart2 and findGuidingObject() and detectFloor() ~= "Rooms" then
          remotesFolder.DropItem:FireServer(tool)
          task.wait(0.1)
          local crucifix

          for _ = 1, 40 do
            crucifix = findNearbyCrucifix(humanoidRootPart2)

            if crucifix then
              break
            end

            task.wait(0.1)
          end

          if crucifix then
            task.wait(0.4)

            local findFirstChildOfClass = crucifix:FindFirstChildOfClass("ProximityPrompt", true)
              or crucifix:FindFirstChild("ModulePrompt", true)

            if findFirstChildOfClass then
              pcall(function() Functions.FirePrompt(findFirstChildOfClass) end)
            end
          end
        end

        task.wait(2)
      end
    end

    featureState.InfCrucifixRunning = false
  end)
end


function Handlers.AutoBreakerBoxChanged(value)
  if not value then
    return
  end

  if featureState.RunBreakerFunc then
    if featureState.BreakerBoxInteracted then
      featureState.RunBreakerFunc()
    end
  elseif currentRooms:FindFirstChild("ElevatorBreaker", true) then
    if not featureState.BreakerBoxInteracted then
      if not featureState.BreakerBoxNotified then
        featureState.BreakerBoxInteracted = true
      end
    else
      task.spawn(function()
        task.wait(1)

        pcall(function()
          if remotesFolder and remotesFolder:FindFirstChild("EBF") then
            remotesFolder.EBF:FireServer()
          end
        end)
      end)
    end
  end
end


function Handlers.GodmodeChanged(_)
  if not character or not humanoid or not humanoidRootPart then
    return
  end

  if featureState and not featureState.OriginalC1 then
    local lowerTorso = character:FindFirstChild("LowerTorso")
    local root = lowerTorso and lowerTorso:FindFirstChild("Root")

    if root then
      featureState.OriginalC1 = root.C1
    end
  end
end


-- ========================================================
-- Phantom Noclip (Main Tab)
-- ========================================================


do
  local phantomTolerance = 3
  local phantomEnabled = false
  local lastSafeCFrame = nil
  local noclipConn = nil
  local antiTpConn = nil
  local charConn = nil

  local function setPhantomCollision(state)
    local char = localPlayer.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
      if obj:IsA("BasePart") then
        obj.CanCollide = not state
      end
    end
  end

  local function disablePhantom()
    phantomEnabled = false
    lastSafeCFrame = nil
    if noclipConn then
      noclipConn:Disconnect()
      noclipConn = nil
    end
    if antiTpConn then
      antiTpConn:Disconnect()
      antiTpConn = nil
    end
    setPhantomCollision(false)
  end

  local function enablePhantom()
    if phantomEnabled then return end
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    phantomEnabled = true
    lastSafeCFrame = root.CFrame

    noclipConn = runService.Stepped:Connect(function()
      if not phantomEnabled then return end
      setPhantomCollision(true)
    end)

    local postSim = runService.PostSimulation or runService.Heartbeat
    antiTpConn = postSim:Connect(function()
      if not phantomEnabled then return end
      local c = localPlayer.Character
      local currRoot = c and c:FindFirstChild("HumanoidRootPart")
      if not currRoot then
        lastSafeCFrame = nil
        return
      end
      if not lastSafeCFrame then
        lastSafeCFrame = currRoot.CFrame
        return
      end

      local distMoved = (currRoot.Position - lastSafeCFrame.Position).Magnitude
      if distMoved > phantomTolerance then
        if (KnobFarm and (KnobFarm.Teleporting or KnobFarm.InSeekChase or KnobFarm.SeekChaseStartRoom))
          or (toggles and toggles.AutoDoorSkip and toggles.AutoDoorSkip.Value) then
          lastSafeCFrame = currRoot.CFrame
        else
          currRoot.CFrame = lastSafeCFrame
          currRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
      else
        lastSafeCFrame = currRoot.CFrame
      end
    end)
  end

  charConn = localPlayer.CharacterAdded:Connect(function()
    if not phantomEnabled then return end
    lastSafeCFrame = nil
    task.wait(0.5)
    if phantomEnabled then
      local c = localPlayer.Character
      local r = c and c:FindFirstChild("HumanoidRootPart")
      if r then lastSafeCFrame = r.CFrame end
      setPhantomCollision(true)
    end
  end)

  

    function Handlers.PhantomNoclipChanged(val)
    if val then
      enablePhantom()
    else
      disablePhantom()
    end
  end


  
  -- menu of this block: built later, from the MENU section at the end of the file
  Menus.PhantomNoclip = function()
    Groupboxes.PhantomNoclip:AddToggle("PhantomNoclip", {
      Text = "Phantom Noclip",
      Tooltip = "Noclip with position flashback protection against fall/rollback.",
      Default = false,
    })

    toggles.PhantomNoclip:OnChanged(Handlers.PhantomNoclipChanged)

    Groupboxes.PhantomNoclip:AddSlider("PhantomTolerance", {
      Text = "Phantom Tolerance",
      Min = 1,
      Max = 20,
      Default = 3,
      Rounding = 1,
      Callback = function(val)
        phantomTolerance = val
      end,
    })
  end

end

Fly = { Connection = nil, Body = nil }
local chairSession = nil

local function stopSpeedBypass()
  if BypassConnection then
    BypassConnection:Disconnect()
    BypassConnection = nil
  end

  local collisionClone = character and character:FindFirstChild("CollisionClone")

  if collisionClone then
    collisionClone:Destroy()
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
    local crouch = remotesFolder and remotesFolder:FindFirstChild("Crouch")

    if crouch then
      crouch:FireServer(false, false)
    end
  end)
end

local function stopSpeedLoop()
  if SpeedConnection then
    SpeedConnection:Disconnect()
    SpeedConnection = nil
  end
end

local function startSpeedBypass()
  stopSpeedBypass()

  local walkspeedActive = (toggles.EnableWalkspeed and toggles.EnableWalkspeed.Value and options.Walkspeed.Value ~= 16)
  if not toggles.FlyToggle.Value and not walkspeedActive then
    return
  end

  local crouch = remotesFolder and remotesFolder:FindFirstChild("Crouch")

  if collisionPart and not character:FindFirstChild("CollisionClone") then
    local collisionClone = collisionPart:Clone()
    collisionClone.Name = "CollisionClone"
    collisionClone.RootPriority = 127
    collisionClone.Anchored = false
    collisionClone.CanCollide = false

    local collisionCrouch = collisionClone:FindFirstChild("CollisionCrouch")

    if collisionCrouch then
      collisionCrouch:Destroy()
    end

    collisionClone.Parent = character
  end

  BypassConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not character or not humanoidRootPart or not humanoid then
      stopSpeedBypass()
      return
    end

    if crouch then
      crouch:FireServer(true, true)
    end

    if not toggles.FlyToggle.Value then
      local collisionClone = character:FindFirstChild("CollisionClone")

      if collisionClone then
        collisionClone.Massless = true
      end
    end
  end)
end

local function runSpeedLoop()
  stopSpeedLoop()

  SpeedConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not humanoid or not humanoidRootPart or not character then
      return
    end

    local walkspeedActive = (toggles.EnableWalkspeed and toggles.EnableWalkspeed.Value)
    local walkspeedActive2 = walkspeedActive and options.Walkspeed.Value or 16

    if walkspeedActive2 == 16 then
      return
    end

    if not BypassConnection then
      startSpeedBypass()
    end

    character:SetAttribute("AntiSpeed", true)
    character:SetAttribute("Antispeed", true)
    character:SetAttribute("SpeedBypass", true)

    humanoid:SetAttribute("AntiSpeed", true)
    humanoid:SetAttribute("Antispeed", true)
    humanoid.WalkSpeed = walkspeedActive2

    local moveDirection = humanoid.MoveDirection

    if moveDirection.Magnitude > 0 then
      humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
        moveDirection.X * walkspeedActive2, humanoidRootPart.AssemblyLinearVelocity.Y, moveDirection.Z * walkspeedActive2
      )
    end
  end)
end

local function restartSpeedSystem()
  stopSpeedLoop()
  stopSpeedBypass()

  local walkspeedActive = (toggles.EnableWalkspeed and toggles.EnableWalkspeed.Value and options.Walkspeed.Value ~= 16)
  if not toggles.FlyToggle.Value and not walkspeedActive then
    return
  end

  SpeedConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not humanoid or not humanoidRootPart or not character then
      return
    end

    local walkspeedActive = (toggles.EnableWalkspeed and toggles.EnableWalkspeed.Value)
    local walkspeedActive2 = walkspeedActive and options.Walkspeed.Value or 16

    character:SetAttribute("SpeedBoost", walkspeedActive2 - 16)
    character:SetAttribute("SpeedBoostBehind", 0)
    character:SetAttribute("SpeedBoostExtra", 0)

    if remotesFolder and remotesFolder:FindFirstChild("Crouch") then
      remotesFolder.Crouch:FireServer(true, true)
    end

    if walkspeedActive2 ~= 16 then
      humanoid.WalkSpeed = walkspeedActive2
      local moveDirection = humanoid.MoveDirection

      if moveDirection.Magnitude > 0 then
        humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
          moveDirection.X * walkspeedActive2, humanoidRootPart.AssemblyLinearVelocity.Y, moveDirection.Z * walkspeedActive2
        )
      end
    end
  end)
end

local function stopFly()
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

function refreshFly()
  stopFly()

  if not toggles.FlyToggle.Value or not humanoidRootPart then
    stopFly()
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
      stopFly()
      return
    end

    local zero = Vector3.zero
    local moveDirection = humanoid.MoveDirection

    if moveDirection.Magnitude > 0 then
      local lookVector = currentCamera.CFrame.LookVector
      local rightVector = currentCamera.CFrame.RightVector
      local dot = moveDirection:Dot(lookVector)
      local dot2 = moveDirection:Dot(rightVector)
      zero = lookVector * dot + rightVector * dot2
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

local function findNearestChair()
  local humanoidRootPart2 = character and character:FindFirstChild("HumanoidRootPart")

  if not humanoidRootPart2 then
    return nil
  end

  local nearestChair, huge = nil, math.huge

  local function considerChair(descendant)
    if (descendant.Name == "ArchivesOfficeChair" or descendant.Name == "StairwellOfficeChair")
      and descendant:IsA("Model") then
      local collider = descendant:FindFirstChild("Collider") or descendant.PrimaryPart
        or descendant:FindFirstChildWhichIsA("BasePart")

      if collider and collider:IsA("BasePart") then
        local magnitude = (humanoidRootPart2.Position - collider.Position).Magnitude

        if magnitude < huge then
          huge = magnitude
          nearestChair = descendant
        end
      end
    end
  end

  local misc = workspace:FindFirstChild("Misc")

  if misc then
    for _, descendant in ipairs(misc:GetDescendants()) do
      considerChair(descendant)
    end
  end

  local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

  if currentRooms2 then
    for _, child in ipairs(currentRooms2:GetChildren()) do
      local assets = child:FindFirstChild("Assets")

      if assets then
        for _, child2 in ipairs(assets:GetChildren()) do
          considerChair(child2)
        end
      end
    end
  end

  return nearestChair
end

local function releaseChair()
  local session = chairSession

  if not session then
    return
  end

  if session.movement then
    session.movement:Disconnect()
  end

  if session.pollSeat then
    session.pollSeat:Disconnect()
  end

  if session.inputBegan then
    session.inputBegan:Disconnect()
  end

  if session.inputEnded then
    session.inputEnded:Disconnect()
  end

  if session.mouseInput then
    session.mouseInput:Disconnect()
  end

  pcall(function() runService:UnbindFromRenderStep("ChairBypassCamera") end)
  pcall(function() ContextActionService:UnbindAction("ChairBypassBlockExit") end)

  if session.originalCollision then
    for key, originalCollisionEntry in pairs(session.originalCollision) do
      if key and key.Parent then
        key.CanCollide = originalCollisionEntry
      end
    end
  end

  if session.collider then
    pcall(function()
      session.collider.AssemblyLinearVelocity = session.oldVelocity
      session.collider.AssemblyAngularVelocity = session.oldAngularVelocity
    end)

    if session.chair and session.chair.Parent then
      local humanoidRootPart2 = character and character:FindFirstChild("HumanoidRootPart")

      if humanoidRootPart2 and session.collider.Parent then
        local sideCFrame = session.collider.CFrame * CFrame.new(3, 0, 0)
        humanoidRootPart2.CFrame = CFrame.lookAt(sideCFrame.Position, session.collider.Position)
      end
    end
  end

  if session.oldCameraType then
    pcall(function()
      workspace.CurrentCamera.CameraType = session.oldCameraType
      workspace.CurrentCamera.CameraSubject = session.oldCameraSubject
      userInputService.MouseBehavior = session.oldMouseBehavior or Enum.MouseBehavior.Default
    end)
  end

  d_ = nil
  chairSession = nil
end

local function takeChairControl()
  local chair = findNearestChair()

  if not chair then
    return false
  end

  local collider = chair:FindFirstChild("Collider") or chair.PrimaryPart
    or chair:FindFirstChildWhichIsA("BasePart")

  if not collider or not collider:IsA("BasePart") then
    return false
  end

  releaseChair()

  local session = {
    chair = chair, collider = collider, held = {}, originalCollision = {}, oldVelocity = collider.AssemblyLinearVelocity, oldAngularVelocity = collider.AssemblyAngularVelocity, oldCameraType = workspace.CurrentCamera.CameraType, oldCameraSubject = workspace.CurrentCamera.CameraSubject, oldMouseBehavior = userInputService.MouseBehavior, cameraYaw = 0, cameraPitch = 0, }

  local lookVector = workspace.CurrentCamera.CFrame.LookVector

  session.cameraYaw = math.atan2(-lookVector.X, -lookVector.Z)
  session.cameraPitch = math.asin(math.clamp(lookVector.Y, -1, 1))

  chairSession = session
  d_ = chair

  pcall(function()
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    workspace.CurrentCamera.CameraSubject = humanoid
  end)

  for _, descendant in ipairs(chair:GetDescendants()) do
    if descendant:IsA("BasePart") then
      session.originalCollision[descendant] = descendant.CanCollide
      descendant.CanCollide = false
    end
  end

  pcall(function()
    ContextActionService:BindActionAtPriority("ChairBypassBlockExit", function(actionName, inputState, inputObject)
      if inputObject.KeyCode == Enum.KeyCode.LeftControl then
        if inputState == Enum.UserInputState.Begin then
          toggles.ArchiveChairFly:SetValue(false)
        end

        return Enum.ContextActionResult.Sink
      end

      if inputObject.KeyCode == Enum.KeyCode.Space or inputObject.KeyCode == Enum.KeyCode.LeftShift
        or inputObject.KeyCode == Enum.KeyCode.RightShift then
        if inputState == Enum.UserInputState.Begin then
          session.held[inputObject.KeyCode] = true
        elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
          session.held[inputObject.KeyCode] = nil
        end
      end

      return Enum.ContextActionResult.Sink
    end, false, Enum.ContextActionPriority.High.Value + 100, Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.LeftControl)
  end)

  session.inputBegan = userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
      return
    end

    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space
      or input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift
      or input.KeyCode == Enum.KeyCode.LeftControl then
      return
    end

    session.held[input.KeyCode] = true
  end)

  session.inputEnded = userInputService.InputEnded:Connect(function(input)
    session.held[input.KeyCode] = nil
  end)

  session.mouseInput = userInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and chairSession == session then
      session.cameraYaw = session.cameraYaw - input.Delta.X * 0.0025
      session.cameraPitch = math.clamp(session.cameraPitch - input.Delta.Y * 0.0025, -1.25, 1.15)
    end
  end)

  pcall(function()
    runService:BindToRenderStep("ChairBypassCamera", Enum.RenderPriority.Camera.Value + 10, function()
      if chairSession ~= session or not collider.Parent then
        return
      end

      local currentCamera2 = workspace.CurrentCamera
      local cframe = CFrame.fromOrientation(session.cameraPitch, session.cameraYaw, 0)
      local target = collider.Position + Vector3.new(0, 2, 0)
      local vectorToWorldSpace = cframe:VectorToWorldSpace(Vector3.new(0, 0, -1))

      currentCamera2.CameraType = Enum.CameraType.Scriptable
      currentCamera2.CFrame = CFrame.lookAt(target, target + vectorToWorldSpace)

      userInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    end)
  end)

  session.movement = runService.Heartbeat:Connect(function()
    if chairSession ~= session or not collider.Parent then
      return
    end

    for _, descendant in ipairs(chair:GetDescendants()) do
      if descendant:IsA("BasePart") then
        descendant.CanCollide = false
      end
    end

    local cframe = workspace.CurrentCamera.CFrame
    local vector = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z)
    local vector2 = Vector3.new(cframe.RightVector.X, 0, cframe.RightVector.Z)

    if vector.Magnitude > 0.01 then
      vector = vector.Unit
    else
      vector = Vector3.new(0, 0, -1)
    end

    if vector2.Magnitude > 0.01 then
      vector2 = vector2.Unit
    else
      vector2 = Vector3.new(1, 0, 0)
    end

    local zero = Vector3.zero

    if session.held[Enum.KeyCode.W] then
      zero = zero + vector
    end

    if session.held[Enum.KeyCode.S] then
      zero = zero - vector
    end

    if session.held[Enum.KeyCode.D] then
      zero = zero + vector2
    end

    if session.held[Enum.KeyCode.A] then
      zero = zero - vector2
    end

    if zero.Magnitude == 0 and humanoid.MoveDirection.Magnitude > 0 then
      local moveDirection = humanoid.MoveDirection
      zero = vector * moveDirection:Dot(vector) + vector2 * moveDirection:Dot(vector2)
    end

    if session.held[Enum.KeyCode.Space] then
      zero = zero + Vector3.yAxis
    end

    if session.held[Enum.KeyCode.LeftShift] then
      zero = zero - Vector3.yAxis
    end

    local pitch = math.asin(math.clamp(cframe.LookVector.Y, -1, 1))

    if zero.Magnitude > 0 then
      local unit = zero.Unit
      local _ = unit * math.sin(pitch) + Vector3.new(0, math.cos(pitch), 0) * unit.Magnitude
      local direction = Vector3.new(unit.X, 0, unit.Z) + Vector3.new(0, math.sin(pitch), 0)

      if direction.Magnitude > 0.01 then
        collider.AssemblyLinearVelocity = direction.Unit * options.ArchiveChairFlySpeed.Value
      else
        collider.AssemblyLinearVelocity = Vector3.zero
      end
    else
      collider.AssemblyLinearVelocity = Vector3.zero
    end

    collider.AssemblyAngularVelocity = Vector3.zero
  end)

  return true
end

local function toggleChairBypass()
  releaseChair()

  if takeChairControl() then
    library:Notify({
      Title = "Chair anticheat bypass", Description = "Bypass active, prompts are not able to be used while active, press ctrl and then space or turn off the toggle to stop it", Time = 3, })

    return
  end

  local heldParts = {}

  local connection = runService.Heartbeat:Connect(function()
    local archiveChairFly = toggles.ArchiveChairFly and toggles.ArchiveChairFly.Value
      or toggles.StairwellChairFly and toggles.StairwellChairFly.Value

    if not archiveChairFly or chairSession ~= heldParts then
      connect17:Disconnect()
      return
    end

    local humanoidRootPart2 = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoidRootPart2 then
      return
    end

    local chair = findNearestChair()

    if not chair then
      return
    end

    local collider = chair:FindFirstChild("Collider") or chair.PrimaryPart
      or chair:FindFirstChildWhichIsA("BasePart")

    if collider and (humanoidRootPart2.Position - collider.Position).Magnitude < 8 then
      connect17:Disconnect()

      if archiveChairFly and not chairSession then
        takeChairControl()

        library:Notify({
          Title = "Chair anticheat bypass", Description = "Bypass active, prompts are not able to be used while active, press ctrl and then space or turn off the toggle to stop it", Time = 3, })
      end
    end
  end)

  heldParts.pollSeat = connection
  chairSession = heldParts
end

function refreshWalkspeed()
  stopSpeedLoop()
  stopSpeedBypass()

  local walkspeedActive = (toggles.EnableWalkspeed and toggles.EnableWalkspeed.Value and options.Walkspeed.Value ~= 16)

  if not walkspeedActive and not (toggles.FlyToggle and toggles.FlyToggle.Value) then
    return
  end

  if options.SpeedBypassMode.Value == "Boost" then
    restartSpeedSystem()
  else
    runSpeedLoop()

    if toggles.FlyToggle.Value or walkspeedActive then
      startSpeedBypass()
    end
  end
end


function Handlers.FlyToggleChanged()
  if toggles.FlyToggle.Value then
    refreshWalkspeed()
    refreshFly()
  else
    stopFly()
    refreshWalkspeed()
  end
end


function Handlers.RemoveAccelerationChanged(value)
  for key, PartProperty in pairs(PartProperties) do
    key.CustomPhysicalProperties = value and CustomPhysics or PartProperty
  end
end


function Handlers.EnableCharacterJumpChanged(value)
  if character then
    character:SetAttribute("CanJump", value and true or OldJump)
  end
end


function Handlers.EnableCharacterSlideChanged(value)
  if character then
    character:SetAttribute("CanSlide", value and true or OldSlide)
  end
end


NoclipConnection = nil
NoclipParts = {}

local function collectNoclipParts()
  TableClear(NoclipParts)

  if not character then
    return
  end

  for _, descendant in character:GetDescendants() do
    if descendant:IsA("BasePart") then
      table.insert(NoclipParts, descendant)
    end
  end

  if collisionPart then
    table.insert(NoclipParts, collisionPart)
    local collisionCrouch = collisionPart:FindFirstChild("CollisionCrouch")
  end

  local collisionClone = character:FindFirstChild("CollisionClone")

  if collisionClone then
    table.insert(NoclipParts, collisionClone)
    local collisionCrouch = collisionClone:FindFirstChild("CollisionCrouch")
  end
end

local function setNoclipCollision(canCollide)
  for _, NoclipPart in ipairs(NoclipParts) do
    if NoclipPart then
      NoclipPart.CanCollide = canCollide
    end
  end
end

function refreshNoclip()
  if NoclipConnection then
    NoclipConnection:Disconnect()
    NoclipConnection = nil
  end

  if toggles.Noclip.Value then
    collectNoclipParts()
    NoclipConnection = runService.Stepped:Connect(function() setNoclipCollision(false) end)
  else
    setNoclipCollision(true)
  end
end


local function updateEntityFlags()
  featureState.IsEyes = workspace:FindFirstChild("Eyes") ~= nil
    or workspace:FindFirstChild("Lookman") ~= nil

  featureState.IsLookman = workspace:FindFirstChild("BackdoorLookman") ~= nil
end

updateEntityFlags()

workspace.ChildAdded:Connect(function(child)
  local name = child.Name

  if name == "Eyes" or name == "Lookman" then
    featureState.IsEyes = true
  elseif name == "BackdoorLookman" then
    featureState.IsLookman = true
  end
end)

workspace.ChildRemoved:Connect(function(child)
  local name = child.Name

  if name == "Eyes" or name == "Lookman" then
    featureState.IsEyes = workspace:FindFirstChild("Eyes") ~= nil
      or workspace:FindFirstChild("Lookman") ~= nil
  elseif name == "BackdoorLookman" then
    featureState.IsLookman = workspace:FindFirstChild("BackdoorLookman") ~= nil
  end
end)

local connection2 = runService.RenderStepped:Connect(function()
  if _Unloading then
    return
  end

  if featureState.InLobby then
    return
  end

  if options.FieldOfView then
    currentCamera.FieldOfView = options.FieldOfView.Value
  end

  if playerGui and not featureState.SurgeFrame then
    local surgeVignetteDisabled = playerGui:FindFirstChild("SurgeVignette", true)

    if surgeVignetteDisabled then
      featureState.SurgeFrame = surgeVignetteDisabled

      if toggles.RemoveSurge and toggles.RemoveSurge.Value then
        surgeVignetteDisabled.Name = "SurgeVignette_Disabled"
      end
    end
  end

  if toggles.BypassEyes.Value and featureState.IsEyes or toggles.BypassLookman.Value and featureState.IsLookman then
    local currentFloor = CurrentFloor

    if currentFloor == "Fools" or currentFloor == "OldHotel" then
      remotesFolder.MotorReplication:FireServer(
        0, featureState.SpoofOffset == 200 and 65 or -65, 0, false
      )
    else
      remotesFolder.MotorReplication:FireServer(-650)
    end
  end
end)

TPTranspParts = {}

local function collectTeleportParts()
  TableClear(TPTranspParts)

  if not character then
    return
  end

  for _, descendant in character:GetDescendants() do
    if descendant:IsA("BasePart")
      and (descendant.Name == "Head" or descendant.Parent and descendant.Parent:IsA("Accessory")) then
      table.insert(TPTranspParts, descendant)
    end
  end
end

local function waitLoop()
  task.wait()
  collectTeleportParts()
end

function refreshThirdPerson()
  if CameraConnection then
    CameraConnection:Disconnect()
    CameraConnection = nil
  end

  if _TPCharConn then
    _TPCharConn:Disconnect()
    _TPCharConn = nil
  end

  collectTeleportParts()

  if character then
    _TPCharConn = character.ChildAdded:Connect(waitLoop)
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
      local cframe = CFrame.new(
        options.ThirdPersonOffsetX.Value, options.ThirdPersonOffsetY.Value, options.ThirdPersonOffsetZ.Value
      )

      if toggles.ThirdPerson.Value then
        local offset = (currentCamera.CFrame * cframe).Position - currentCamera.CFrame.Position

        local spherecast = workspace:Spherecast(
          currentCamera.CFrame.Position, 0.2, offset, raycastParams
        )

        if toggles.ThirdPersonWallCheck.Value and spherecast and spherecast.Instance.CanCollide then
          local newPosition = currentCamera.CFrame.Position + offset.Unit * spherecast.Distance
          currentCamera.CFrame = CFrame.new(newPosition, newPosition + currentCamera.CFrame.LookVector)
        else
          currentCamera.CFrame = currentCamera.CFrame * cframe
        end
      end
    end

    for _, TPTranspPart in ipairs(TPTranspParts) do
      TPTranspPart.Transparency = toggles.ThirdPerson.Value and 0 or 1
      TPTranspPart.LocalTransparencyModifier = toggles.ThirdPerson.Value and 0 or 1
    end
  end)
end

featureState.LastCrouchFire = 0

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

  local godmodeActive = isGodmodeActive()

  if godmodeActive and not threatState.Sunk then
    if CurrentFloor ~= "Fools" and CurrentFloor ~= "OldHotel" then
      humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, -2.346, 0)
      humanoid.HipHeight = 0.05
      threatState.Sunk = true

      if remotesFolder then
        local crouch = remotesFolder:FindFirstChild("Crouch")

        if crouch then
          crouch:FireServer(true, true)
        end
      end
    end
  end

  if not godmodeActive and threatState.Sunk then
    if CurrentFloor ~= "Fools" and CurrentFloor ~= "OldHotel" then
      humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 2.346, 0)
      humanoid.HipHeight = 2.396
      threatState.Sunk = false
    end
  end

  if godmodeActive and threatState.Sunk and CurrentFloor ~= "Fools" and CurrentFloor ~= "OldHotel" then
    if humanoid.HipHeight ~= 0.05 then
      humanoid.HipHeight = 0.05
    end
  end

  if godmodeActive and remotesFolder then
    local crouch = remotesFolder:FindFirstChild("Crouch")

    if crouch then
      crouch:FireServer(true, true)
    end
  end

  local collision2 = character:FindFirstChild("Collision")
  local collisionPart2 = character:FindFirstChild("CollisionPart")
  local collisionClone = character:FindFirstChild("CollisionClone")

  if CurrentFloor == "OldHotel" or CurrentFloor == "Fools" then
    local functions = godmodeActive and Functions.GetNearestEntity() and 200
      or toggles.FigureGodmode.Value and Functions.GetNearestFigure() and 200 or 0

    featureState.SpoofOffset = functions

    if collision2 then
      collision2.Position = humanoidRootPart.Position + Vector3.new(0, functions, 0)
      collision2.CanCollide = false
    end

    if CurrentFloor == "Fools" then
      local collisionCrouch = collision2 and collision2:FindFirstChild("CollisionCrouch")

      if collisionCrouch then
        collisionCrouch.CanCollide = false
      end

      local collisionCrouch2 = collisionClone
        and collisionClone:FindFirstChild("CollisionCrouch")

      if collisionCrouch2 then
        collisionCrouch2.CanCollide = false
      end
    end

    humanoidRootPart.CanCollide = not toggles.Noclip.Value
  else
    if collision2 then
      collision2.CanCollide = false
      local collisionCrouch = collision2:FindFirstChild("CollisionCrouch")

      if collisionCrouch then
        collisionCrouch.CanCollide = false
      end
    end

    local lowerTorso = character:FindFirstChild("LowerTorso")
    local root = lowerTorso and lowerTorso:FindFirstChild("Root")

    if root and not featureState.OriginalC1 then
      featureState.OriginalC1 = root.C1
    end

    if root and featureState.OriginalC1 then
      root.C1 = featureState.OriginalC1 * CFrame.new(0, godmodeActive and -2.346 or 0, 0)
    end

    local collisionOffsetY = godmodeActive and 2.328 or 0.18

    if collision2 then
      collision2.Position = humanoidRootPart.Position + Vector3.new(0, collisionOffsetY, 0)
    end

    if collisionPart2 then
      collisionPart2.Position = humanoidRootPart.Position + Vector3.new(0, collisionOffsetY, 0)
    end

    if collision2 and collisionClone then
      local collisionCrouch = collision2:FindFirstChild("CollisionCrouch")
      local collisionCrouch2 = collisionClone:FindFirstChild("CollisionCrouch")

      if collisionCrouch and collisionCrouch2 then
        local crouchOffsetY = godmodeActive and 1.328 or -0.982
        collisionCrouch.Position = humanoidRootPart.Position + Vector3.new(0, crouchOffsetY, 0)
        collisionCrouch2.CollisionGroup = collisionCrouch.CollisionGroup
      end

      local collisionCrouch3 = collisionClone:FindFirstChild("CollisionCrouch")

      if collisionCrouch3 then
        collisionCrouch3.Position = humanoidRootPart.Position
          + Vector3.new(0, godmodeActive and 0.75 or -0.982, 0)
      end
    end
  end

  if collisionClone and collision2 then
    collisionClone.CollisionGroup = collision2.CollisionGroup

    collisionClone.Position = humanoidRootPart.Position
      + Vector3.new(0, godmodeActive and 1.75 or 0.18, 0)
  end

  local crouch = remotesFolder and remotesFolder:FindFirstChild("Crouch")

  if crouch and collisionPart and tick() - featureState.LastCrouchFire > 0.1 then
    local functions = Functions.IsCrouching()

    if godmodeActive then
      functions = true
    end

    crouch:FireServer(functions, true)
    featureState.LastCrouchFire = tick()
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
  local nearest = { Distance = math.huge, Object = nil }
  local figureNames = { FigureRig = true, FigureRagdoll = true, Figure = true }

  for _, entity in worldObjects.Entities do
    if entity:IsA("Model") and entity.PrimaryPart and figureNames[entity.Name] then
      local distanceFromCharacter = localPlayer:DistanceFromCharacter(entity.PrimaryPart.Position)

      if distanceFromCharacter < nearest.Distance and distanceFromCharacter < 25 then
        nearest.Distance = distanceFromCharacter
        nearest.Object = entity
      end
    end
  end

  return nearest.Object
end

Phase = {
  Connection = nil, Body = nil, Parts = {}, CharConn = nil, }

local function collectPhaseParts()
  TableClear(Phase.Parts)

  if not character then
    return
  end

  for _, descendant in character:GetDescendants() do
    if descendant:IsA("BasePart") then
      table.insert(Phase.Parts, descendant)
    end
  end
end

function refreshPhase()
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
    collectPhaseParts()

    if character then
      Phase.CharConn = character.ChildAdded:Connect(function()
        task.wait()
        collectPhaseParts()
      end)
    end

    Phase.Connection = runService.Stepped:Connect(function()
      if not character then
        return
      end

      for _, part in ipairs(Phase.Parts) do
        if part then
          part.CanCollide = false
        end
      end

      if collisionPart then
        collisionPart.CanCollide = false
        local collisionCrouch = collisionPart:FindFirstChild("CollisionCrouch")

        if collisionCrouch then
          collisionCrouch.CanCollide = false
        end
      end

      local collisionClone = character:FindFirstChild("CollisionClone")

      if collisionClone then
        collisionClone.CanCollide = false
        local collisionCrouch = collisionClone:FindFirstChild("CollisionCrouch")

        if collisionCrouch then
          collisionCrouch.CanCollide = false
        end
      end

      if humanoidRootPart then
        local pSpeed = Phase.Speed or 2.25
        if Phase.TargetPosition then
          local toTarget = Phase.TargetPosition - humanoidRootPart.Position
          if toTarget.Magnitude > 0.5 then
            Phase.Body.Velocity = toTarget.Unit * pSpeed
            local flatDir = Vector3.new(toTarget.X, 0, toTarget.Z)
            if flatDir.Magnitude > 0.2 then
              humanoidRootPart.CFrame = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + flatDir.Unit)
            end
          else
            Phase.Body.Velocity = Vector3.zero
          end
        else
          Phase.Body.Velocity = humanoidRootPart.CFrame.LookVector * pSpeed
        end
      end
    end)

    Phase.Body = Instance.new("BodyVelocity")
    Phase.Body.MaxForce = Vector3.new(9000000000, 9000000000, 9000000000)

    local initSpeed = Phase.Speed or 2.25
    local initVel = humanoidRootPart and humanoidRootPart.CFrame.LookVector * initSpeed or Vector3.zero
    if Phase.TargetPosition and humanoidRootPart then
      local toTarget = Phase.TargetPosition - humanoidRootPart.Position
      if toTarget.Magnitude > 0.5 then
        initVel = toTarget.Unit * initSpeed
      end
    end
    Phase.Body.Velocity = initVel

    if humanoidRootPart then
      Phase.Body.Parent = humanoidRootPart
    end
  elseif not toggles.Noclip.Value then
    collectNoclipParts()
    setNoclipCollision(true)
  end
end


function Handlers.AnticheatManipulationChanged(value)
  if AnticheatConnection then
    AnticheatConnection:Disconnect()
    AnticheatConnection = nil
  end

  if value then
    AnticheatConnection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if not character or not humanoidRootPart then
        return
      end

      local currentFloor = localPlayer:GetAttribute("CurrentFloor") or ""

      if currentFloor ~= "Fools" and currentFloor ~= "OldHotel" then
        character:PivotTo(character:GetPivot() * CFrame.new(0, 0, 750))
      end
    end)
  end
end


local autoInteractState = {
  Connection = nil, LastFire = 0, Debounce = false, Blacklist = {
    HidePrompt = true, RiftPrompt = true, StarRiftPrompt = true, InteractPrompt = true, ClimbPrompt = true, DonatePrompt = true, DialoguePrompt = true, RevivePrompt = true, EnterPrompt = true, AnimatePrompt = true, ToolEventPrompt = true, Prompt = true, PropPrompt = true, }, }

HidingSpotNames = {
  Wardrobe = true, Backdoor_Wardrobe = true, Toolshed = true, RetroWardrobe = true, ["Wardrobe-FOOLS26"] = true, Locker_Large = true, Rooms_Locker = true, Rooms_Locker_Fridge = true, Bed = true, Double_Bed = true, CircularVent = true, Dumpster = true, }

LockPromptNames = {
  UnlockPrompt = true, SkullPrompt = true, LockPrompt = true, ThingToEnable = true, FusesPrompt = true, }

local function autoInteractWith(prompt)
  if autoInteractState.Blacklist[prompt.Name] then
    return
  end

  -- В комнате 50 (библиотека Фигуры) авто-интеракт не трогает тумбочки/ящики:
  -- открытие ящиков шумит и привлекает Фигуру
  if KnobFarm and (KnobFarm.CurrentRoomNum == 50) then
    local pName = prompt.Parent and prompt.Parent.Name or ""
    local pNameLower = pName:lower()
    local objText = (prompt.ObjectText or ""):lower()
    local actText = (prompt.ActionText or ""):lower()
    if pNameLower:find("drawer", 1, true) or pNameLower:find("nightstand", 1, true)
      or pNameLower:find("dresser", 1, true) or pNameLower:find("chest", 1, true)
      or objText:find("drawer", 1, true) or objText:find("nightstand", 1, true)
      or objText:find("chest", 1, true)
      or actText == "open" or actText == "search" or actText == "loot" then
      return
    end
  end

  if prompt:FindFirstAncestor("ArchivesWaitingSeats") or prompt:FindFirstAncestor("ArchivesTrashcan")
    or prompt:FindFirstAncestor("ArchivesOfficeChair") or prompt:FindFirstAncestor("PrincipalChair")
    or prompt:FindFirstAncestor("Vendor_ShakelightVendingMachine")
    or prompt:FindFirstAncestor("ArchivesTerminal") or prompt:FindFirstAncestor("Regal_Chair")
    or prompt:FindFirstAncestor("Regal_Couch") or prompt:FindFirstAncestor("ArchivesLargePrinter")
    or prompt:FindFirstAncestor("ForgetMeNotVineDoors")
    or prompt:FindFirstAncestor("StairwellTerminal")
    or prompt:FindFirstAncestor("StairwellOfficeChair")
    or prompt:FindFirstAncestor("Fireplace")
    or prompt:FindFirstAncestor("FirePlace")
    or (prompt.Parent and prompt.Parent.Name:lower():find("fireplace", 1, true))
    or (prompt.Parent and prompt.Parent.Name:lower():find("hearth", 1, true))
    or (prompt.ObjectText and prompt.ObjectText:lower():find("fireplace", 1, true)) then
    return
  end

  if not prompt or not prompt.Parent then
    return
  end

  if autoInteractState.Debounce then
    return
  end

  if LockPromptNames[prompt.Name]
    or prompt.Parent and prompt.Parent:GetAttribute("Locked") == true
    or prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent.Name == "Locker_Small_Locked"
      and prompt.Name == "ActivateEventPrompt" then
    if options.AutoInteractIgnoreList.Value.Locks then
      return
    end

    local unlockItemNames = {
      "Key", "GeneratorFuse", "KeyBackdoor", "KeyElectrical", "KeyIron", "Lockpick", "Lockpicks", "SkeletonKey", "Shears", "Multitool", }

    local keyItemNames = { "Key", "GeneratorFuse", "KeyElectrical", "KeyIron" }
    local hasUnlockItem = false

    for _, itemName in ipairs(unlockItemNames) do
      if Functions.HasItem(itemName, true) then
        hasUnlockItem = true
        break
      end
    end

    for _, itemName in ipairs(keyItemNames) do
      if Functions.HasItem(itemName) then
        hasUnlockItem = true
        break
      end
    end

    if not hasUnlockItem then
      return
    end
  end

  if HidingSpotNames[prompt.Parent.Name] then
    return
  end

  if prompt.Parent.Name == "GlitchCube"
    and options.AutoInteractIgnoreList.Value["Glitch Fragments"] then
    return
  end

  local parent = prompt

  if options.AutoInteractIgnoreList.Value.Mandrake then
    while parent do
      local name = parent.Name

      if name == "MandrakeLive" or name == "MandrakeHole" or name == "Mandrakes" then
        return
      end

      parent = parent.Parent
    end
  end

  local drops = workspace:FindFirstChild("Drops")

  if drops and prompt:IsDescendantOf(drops)
    and options.AutoInteractIgnoreList.Value["Dropped Items"] then
    return
  end

  if prompt.Parent.Name == "TrackLever" then
    return
  end

  if prompt.Name == "ActivateEventPrompt" then
    if prompt.ActionText == "Close" then
      return
    end

    if prompt.Parent.Name == "Padlock" or prompt.Parent.Name == "MinesAnchor" then
      return
    end
  end

  if prompt.Parent.Name == "LeverForGate" and prompt:GetAttribute("Interactions") then
    return
  end

  local parent2 = prompt.Parent.Parent

  if parent2 and (parent2.Name == "DoorFake" or parent2.Name == "FakeDoor") then
    return
  end

  if prompt.Parent:GetAttribute("JeffShop") then
    return
  end

  if prompt:GetAttribute("AutoInteractIgnore") then
    return
  end

  if prompt.Name == "PushPrompt" then
    return
  end

  if (prompt.Parent.Name == "LibraryHintPaper" or prompt.Parent.Name == "PickupItem")
    and (Functions.HasItem("LibraryHintPaper") or Functions.HasItem("LibraryHintPaperHard")) then
    return
  end

  Functions.ForceFirePrompt(prompt)
  autoInteractState.Debounce = true

  if detectFloor() == "OldHotel" then
    task.wait()
  end

  autoInteractState.Debounce = false
end

function Handlers.AutoInteractChanged(value)
  if autoInteractState.Connection then
    autoInteractState.Connection:Disconnect()
    autoInteractState.Connection = nil
  end

  if value then
    autoInteractState.Connection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if not (toggles and toggles.AutoInteract and toggles.AutoInteract.Value
        or options and options.AutoInteractKeybind and options.AutoInteractKeybind:GetState()) then
        return
      end

      local now = tick()

      if now - autoInteractState.LastFire < 0.1 then
        return
      end

      autoInteractState.LastFire = now

      for _, _TrackedPrompt in ipairs(_TrackedPrompts) do
        local parentRoom = _TrackedPrompt:GetAttribute("ParentRoom")

        if (not parentRoom
            or tonumber(parentRoom) == tonumber(localPlayer:GetAttribute("CurrentRoom")))
          and _TrackedPrompt.Parent
          and (_TrackedPrompt.Parent:IsA("BasePart") or _TrackedPrompt.Parent:IsA("Model")) then
          local distanceFromCharacter

          if _TrackedPrompt.Parent:IsA("BasePart") then
            distanceFromCharacter = localPlayer:DistanceFromCharacter(_TrackedPrompt.Parent.Position)
          else
            distanceFromCharacter = localPlayer:DistanceFromCharacter(_TrackedPrompt.Parent:GetPivot().Position)
          end

          if distanceFromCharacter
              <= (_TrackedPrompt:GetAttribute("MaxActivationDistance_Old")
                  or _TrackedPrompt.MaxActivationDistance)
                + 5
            and (_TrackedPrompt.Enabled or _TrackedPrompt.Name == "LongPushPrompt"
              or _TrackedPrompt.Name == "BigPropPrompt") then
            task.spawn(autoInteractWith, _TrackedPrompt)
          end
        end
      end
    end)
  end
end


function refreshInfiniteJump()
  if InfiniteJumpConnection then
    InfiniteJumpConnection:Disconnect()
    InfiniteJumpConnection = nil
  end

  if not toggles.InfiniteJumps.Value then
    return
  end

  InfiniteJumpConnection = userInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space and humanoid then
      humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
  end)
end


ESPCategories = {
  Entities = {}, Doors = {}, Keys = {}, Objectives = {}, Items = {}, Gold = {}, Chests = {}, HidingSpots = {}, Ladders = {}, }

ESPBlacklist = {}
ESPCleanup = {}
ESPConnections = {}

local function applyCategoryTracers(object)
  if not loader or not object then
    return
  end

  for _, category in ipairs({
    "Entities", "Doors", "Keys", "Objectives", "Items", "Gold", "Chests", "HidingSpots", "Ladders", }) do
    local text = category .. "Tracers"

    if toggles[text] and toggles[text].Value and TableFind(ESPCategories[category], object) then
      loader:SetTracersEnabled(object, true)
      break
    end
  end
end

function Functions:AddESP(trackRoom)
  local object = self.Object

  if not object then
    return
  end

  if ESPBlacklist[object] then
    return
  end

  if trackRoom then
    local number = tonumber(localPlayer:GetAttribute("CurrentRoom"))
    local number2 = tonumber(object:GetAttribute("ParentRoom"))

    if number2 == number or TableFind(ESPCategories.Doors, object) and number2 == number + 1 then
      loader:AddESP(self)
      applyCategoryTracers(object)
    end

    local connection = localPlayer:GetAttributeChangedSignal("CurrentRoom"):Connect(function()
      if loader.ColorTable and loader.ColorTable[object] then
        self.Color = loader.ColorTable[object]
      end

      local number3 = tonumber(localPlayer:GetAttribute("CurrentRoom"))
      local number4 = tonumber(object:GetAttribute("ParentRoom"))

      if number4 == number3 or TableFind(ESPCategories.Doors, object) and number4 == number3 + 1 then
        if loader then
          loader:AddESP(self)
          applyCategoryTracers(object)
        end
      elseif loader then
        loader:RemoveESP(object)
        loader:SetTracersEnabled(object, false)
      end
    end)

    table.insert(Connections, connection)
    ESPConnections[object] = connection

    object.Destroying:Once(function()
      connection:Disconnect()

      if loader then
        loader:RemoveESP(object)
        loader:SetTracersEnabled(object, false)
      end

      local _ = TableFind(Connections, connection)
      ESPConnections[object] = nil
    end)
  else
    loader:AddESP(self)
    applyCategoryTracers(object)
  end
end

function Functions:RemoveESP()
  local connection = ESPConnections[self]

  if connection then
    connection:Disconnect()
    ESPConnections[self] = nil
    local _ = TableFind(Connections, connection)
  end

  if loader then
    loader:RemoveESP(self)
    loader:SetTracersEnabled(self, false)
  end
end

local espItemNames = {
  Door = true, Ladder = true, GoldPile = true, StardustPickup = true, KeyObtain = true, ElectricalKeyObtain = true, MinesGenerator = true, FuseObtain = true, LiveHintBook = true, LiveBreakerPolePickup = true, LibraryHintPaper = true, PickupItem = true, CringlePresent = true, LeverForGate = true, MinesGateButton = true, GardenGateButton = true, MinesAnchor = true, WaterPump = true, TimerLever = true, VineGuillotine = true, KeyObtainFake = true, GiggleCeiling = true, Snare = true, GrumbleRig = true, Drakobloxxer = true, LiveEntityBramble = true, Groundskeeper = true, Figure = true, FigureRig = true, FigureRagdoll = true, MandrakeLive = true, ChestBox = true, ChestBoxLocked = true, Chest_Vine = true, Toolbox = true, Toolbox_Locked = true, Toolshed_Small = true, Locker_Small_Locked = true, MouseHole = true, Wardrobe = true, Backdoor_Wardrobe = true, Toolshed = true, RetroWardrobe = true, ["Wardrobe-FOOLS26"] = true, Locker_Large = true, Rooms_Locker = true, Rooms_Locker_Fridge = true, Bed = true, Double_Bed = true, CircularVent = true, Dumpster = true, Lighter = true, Flashlight = true, Lockpick = true, Vitamins = true, Bandage = true, StarVial = true, StarBottle = true, StarJug = true, Shakelight = true, Straplight = true, Bulklight = true, Battery = true, Candle = true, Crucifix = true, CrucifixWall = true, Glowsticks = true, SkeletonKey = true, Candy = true, ShieldMini = true, ShieldBig = true, BandagePack = true, BatteryPack = true, RiftCandle = true, LaserPointer = true, HolyGrenade = true, Shears = true, Smoothie = true, Cheese = true, Bread = true, AlarmClock = true, RiftSmoothie = true, GweenSoda = true, GlitchCube = true, Scanner = true, Bomb = true, Knockbomb = true, Nanner = true, BigBomb = true, SnakeBox = true, GoldGun = true, StopSign = true, TipJar = true, Lantern = true, IronKey = true, LotusPetal = true, Compass = true, LotusPetalPickup = true, LanternLitItem = true, KeyIron = true, IronKeyForCrypt = true, LotusHolder = true, Multitool = true, RiftJar = true, AloeVera = true, Donut = true, Lotus = true, BoxingGloves = true, Green_Herb = true, PaperPlane = true, Pizza = true, FihFlakes = true, Leftovers = true, Briefcase = true, ArchivesTerminal = true, StairwellTerminal = true, }

local espEntityNames = {
  RushMoving = true, AmbushMoving = true, A60 = true, A120 = true, Eyes = true, Lookman = true, BackdoorRush = true, BackdoorLookman = true, Groundskeeper = true, GloombatSwarm = true, AR0xMBUSH = true, ["RNIUSHCG=="] = true, MonumentEntity = true, JeffTheKiller = true, CustomEntity = true, FrozenAmbush = true, SallyMoving = true, Figure = true, FigureRig = true, FigureRagdoll = true, GiggleCeiling = true, GrumbleRig = true, DronesStampede = true, BashMoving = true, Water = true, TellerRig = true, Scribbles = true, Noise = true, Creak = true, }

lastPrompt = {
  Lighter = "Lighter", Flashlight = "Flashlight", Lockpick = "Lockpicks", Vitamins = "Vitamins", Bandage = "Bandage", StarVial = "Starlight Vial", StarBottle = "Starlight Bottle", StarJug = "Starlight Barrel", Shakelight = "Gummy Flashlight", Straplight = "Straplight", Bulklight = "Spotlight", Battery = "Battery", Candle = "Candle", Crucifix = "Crucifix", CrucifixWall = "Crucifix", Glowsticks = "Glowstick", SkeletonKey = "Skeleton Key", Candy = "Candy", ShieldMini = "Mini Shield Potion", ShieldBig = "Big Shield Potion", BandagePack = "Bandage Pack", BatteryPack = "Battery Pack", RiftCandle = "Moonlight Candle", LaserPointer = "Laser Pointer", HolyGrenade = "Holy Hand Grenade", Shears = "Shears", Smoothie = "Smoothie", Cheese = "Cheese", Bread = "Bread", AlarmClock = "Alarm Clock", RiftSmoothie = "Moonlight Smoothie", GweenSoda = "Gween Soda", GlitchCube = "Glitch Fragment", Scanner = "Tablet", Bomb = "Bomb", Knockbomb = "Knockbomb", Nanner = "Nanner", BigBomb = "Big Bomb", SnakeBox = "Hiding Box", GoldGun = "Golden Gun", StopSign = "Stop Sign", TipJar = "Tip Jar", Lantern = "Lantern", IronKey = "Iron Key", LotusPetal = "Lotus Petal", Compass = "Compass", LotusPetalPickup = "Lotus Petal", LanternLitItem = "Lantern", KeyIron = "Iron Key", IronKeyForCrypt = "Iron Key", LotusHolder = "Lotus Petal", Multitool = "Multitool", RiftJar = "Rift Jar", AloeVera = "Aloe Vera", Donut = "Donut", Lotus = "Lotus", BoxingGloves = "Boxing Gloves", GoldPile = "Gold Pile", PaperPlane = "Paper Plane", Pizza = "Pizza", FihFlakes = "FihFlakes", Leftovers = "Leftovers", Briefcase = "Briefcase", }

function FunctionGetDoorNumber(door)
  local number = tonumber(door.Parent.Name)
    or tonumber(door.Parent.Parent and door.Parent.Parent.Name)

  if number then
    number = number + 1
  end

  if CurrentFloor == "Mines" then
    number = (number or 0) + 100
  end

  if CurrentFloor == "Backdoor" then
    number = (number or 0) - 50
  end

  return tostring(number)
end

ESPToggleKeys = {
  Entities = "EntitiesESP", Doors = "DoorsESP", Keys = "KeysESP", Objectives = "ObjectivesESP", Items = "ItemsESP", Gold = "GoldESP", Chests = "ChestsESP", HidingSpots = "HidingSpotsESP", Ladders = "LaddersESP", }

local colorFlags = {
  Entities = "EntitiesESPColor", Doors = "DoorsESPColor", Keys = "KeysESPColor", Objectives = "ObjectivesESPColor", Items = "ItemsESPColor", Gold = "GoldESPColor", Chests = "ChestsESPColor", HidingSpots = "HidingSpotsESPColor", Ladders = "LaddersESPColor", }

function GetESPTarget(object, _)
  return object
end

local notifier = {
  PlaySound = nil, ShowAchievement = nil, ActiveItem = 0, SoundAssets = nil, SoundInstance = nil, ActiveAchievement = nil, ActiveEntity = 0, }

local function addCategoryESP(highlightPart, category, locked)
  local isEnabled = toggles[ESPToggleKeys[category]] and toggles[ESPToggleKeys[category]].Value
  if not isEnabled then
    if category == "Keys" and toggles.ObjectivesESP and toggles.ObjectivesESP.Value then
      isEnabled = true
    elseif category == "Gold" and toggles.ItemsESP and toggles.ItemsESP.Value then
      isEnabled = true
    end
  end

  if not isEnabled then
    return
  end

  local colorOpt = options[colorFlags[category]]
  local color = colorOpt and colorOpt.Value or (category == "Gold" and Color3.fromRGB(255, 215, 0) or (category == "Keys" and Color3.fromRGB(0, 191, 255) or (category == "Items" and Color3.fromRGB(170, 85, 255) or Color3.fromRGB(255, 255, 255))))
  local value = toggles.ESPShowText.Value and locked or ""
  local remoteModules = GetESPTarget(highlightPart, category)
  local roomBound = highlightPart:GetAttribute("ParentRoom") ~= nil
  Functions.AddESP({ Object = remoteModules, Text = value, Color = color }, roomBound)
end

local function removeCategoryESP(category)
  for _, object in ipairs(ESPCategories[category] or {}) do
    Functions.RemoveESP(GetESPTarget(object, category))
  end
  if category == "Items" and not (toggles.GoldESP and toggles.GoldESP.Value) then
    for _, object in ipairs(ESPCategories.Gold or {}) do
      Functions.RemoveESP(GetESPTarget(object, "Gold"))
    end
  elseif category == "Objectives" and not (toggles.KeysESP and toggles.KeysESP.Value) then
    for _, object in ipairs(ESPCategories.Keys or {}) do
      Functions.RemoveESP(GetESPTarget(object, "Keys"))
    end
  end
end

local function notifyItemSpawn(locked, model)
  if not toggles.NotifyItems.Value then
    return
  end

  local value = options.ItemList.Value

  if value and next(value) ~= nil and not value[locked] then
    return
  end

  if notifier.ActiveItem >= 6 then
    return
  end

  notifier.ActiveItem = notifier.ActiveItem + 1
  notifier.PlaySound("ItemNotifySound")

  local distanceText = ""

  if model and model.PrimaryPart then
    distanceText = " ("
      .. math.floor(localPlayer:DistanceFromCharacter(model.PrimaryPart.Position) + 0.5)
      .. " m)"
  end

  library:Notify({ Title = "An item has spawned", Description = locked .. distanceText, Time = 4 })

  if options.ItemNotifyStyle.Value ~= "Obsidian" then
    task.spawn(function() notifier.ShowAchievement("An item has spawned", locked, distanceText) end)
  end

  if toggles.ItemChatToggle.Value then
    Functions.SendChat(locked .. " " .. options.ItemChatMessage.Value)
  end

  task.delay(5, function() notifier.ActiveItem = math.max(0, notifier.ActiveItem - 1) end)
end

local notifyEntitySpawn

local function handleESPObject(object)
  if not object or not object.Parent then
    return
  end

  if ESPBlacklist[object] then
    return
  end

  if not espItemNames[object.Name] and not espEntityNames[object.Name] and not object.Name:match("^HidingSpot%d+$") then
    return
  end

  local name = object.Name

  if name == "Door" and not object:GetAttribute("ESPDelayed") then
    object:SetAttribute("ESPDelayed", true)

    task.spawn(function()
      task.wait(0.25)
      handleESPObject(object)
    end)

    return
  end

  local doorCategory, locked

  if name == "Door" and object.Parent and tonumber(object.Parent.Name) then
    doorCategory = "Doors"
    local parts = {}

    for _, child in object:GetChildren() do
      if child.Name == "Door" and child:IsA("BasePart") then
        table.insert(parts, child)
      end
    end

    if #parts == 0 then
      return
    end

    locked = "Door " .. FunctionGetDoorNumber(object)

    if CurrentFloor == "Archives" then
      local sign = object:FindFirstChild("Sign")
      local stinker = sign and sign:FindFirstChild("Stinker")

      if stinker and stinker:IsA("TextLabel") and stinker.Text ~= "" then
        locked = "Door " .. stinker.Text
      end
    end

    if CurrentFloor == "OldHotel" then
      object:SetAttribute("ParentRoom", tonumber(object.Parent.Name))
      table.insert(ESPCategories.Doors, object)
      addCategoryESP(object, "Doors", locked)

      if not ESPCleanup[object] then
        ESPCleanup[object] = object.Destroying:Once(function()
          Functions.RemoveESP(object)
          ESPCleanup[object] = nil
        end)
      end
    else
      local highlightPart

      if #parts == 2 then
        local highlightModel = Instance.new("Model")
        highlightModel.Name = "HighlightModel"

        Instance.new("Humanoid", highlightModel).Name = "HighlightHumanoid"
        highlightModel:SetAttribute("ParentRoom", tonumber(object.Parent.Name))

        for _, part in ipairs(parts) do
          local part2 = Instance.new("Part", highlightModel)
          part2.Transparency = 0.999
          part2.Size = part.Size
          part2.CanCollide = false
          part2.CFrame = part.CFrame
          part2.Name = "HighlightPart"
          part2.Material = Enum.Material.Glass
          part2:SetAttribute("ParentRoom", tonumber(object.Parent.Name))

          local instance = Instance.new("WeldConstraint", part2)
          instance.Part0 = part2
          instance.Part1 = part
          instance.Enabled = true
        end

        highlightModel.Parent = workspace
        highlightPart = highlightModel
      else
        local firstPart = parts[1]

        highlightPart = Instance.new("Part")
        highlightPart.Transparency = 0.999
        highlightPart.Size = firstPart.Size
        highlightPart.CanCollide = false
        highlightPart.CFrame = firstPart.CFrame
        highlightPart.Name = "HighlightPart"
        highlightPart.Material = Enum.Material.Glass
        highlightPart:SetAttribute("ParentRoom", tonumber(object.Parent.Name))

        local instance = Instance.new("WeldConstraint", highlightPart)
        instance.Part0 = highlightPart
        instance.Part1 = firstPart
        instance.Enabled = true

        Instance.new("Humanoid", object).Name = "HighlightHumanoid"
        highlightPart.Parent = workspace
      end

      table.insert(ESPCategories.Doors, highlightPart)
      addCategoryESP(highlightPart, "Doors", locked)

      if not ESPCleanup[highlightPart] then
        ESPCleanup[highlightPart] = object.Destroying:Once(function()
          Functions.RemoveESP(highlightPart)
          ESPCleanup[highlightPart] = nil
        end)
      end
    end

    local now = tick()

    local connection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      if object:FindFirstChild("Door") and object:FindFirstChild("ClientOpen") then
        if options
          and options.DoorReachDistance
          and localPlayer:DistanceFromCharacter(object.Door.Position)
            < options.DoorReachDistance.Value
          and tick() - now > 0.1
          and toggles
          and toggles.DoorReachToggle
          and toggles.DoorReachToggle.Value then
          object.ClientOpen:FireServer()
          now = tick()
        end
      end
    end)

    local door = object:FindFirstChild("Door")

    if door then
      local open = door:FindFirstChild("Open")

      if open then
        open.Played:Once(function() connection:Disconnect() end)
      end
    end

    object.Destroying:Once(function() connection:Disconnect() end)
    return
  end

  if espEntityNames[name] then
    if name == "Water" and CurrentFloor ~= "Archives" then
      return
    end

    if name == "Water" then
      if object:FindFirstAncestor("Toilet") or object:FindFirstAncestor("ArchivesBathroomSink")
        or object:FindFirstAncestor("ArchivesFihTank") then
        return
      end

      if object:FindFirstAncestor("WaterCup") then
        return
      end

      if object:FindFirstAncestor("DeathBackgroundYellow") then
        return
      end

      if object.Parent and object.Parent.Name == "Parts"
        and object.Parent:FindFirstAncestor("CurrentRooms") then
        return
      end

      if object:IsDescendantOf(localPlayer:WaitForChild("Backpack")) then
        return
      end

      table.insert(ESPCategories.Entities, object)
      addCategoryESP(object, "Entities", "Electric Puddle")
      notifyEntitySpawn(object)
      return
    end

    if not object:IsA("Model") then
      return
    end

    task.spawn(function()
      while not object.PrimaryPart and object.Parent do
        for _, child in object:GetChildren() do
          if child:IsA("BasePart") then
            object.PrimaryPart = child
            break
          end
        end

        task.wait()
      end

      task.wait(0.1)

      if not object.Parent then
        return
      end

      if object.PrimaryPart
        and localPlayer:DistanceFromCharacter(object.PrimaryPart.Position) >= 10000 then
        return
      end

      if not object.PrimaryPart then
        local basePart = object:FindFirstChildWhichIsA("BasePart")

        if basePart then
          object.PrimaryPart = basePart
        end
      end

      if not object:FindFirstChildOfClass("Humanoid") then
        local highlightHumanoid = Instance.new("Humanoid")
        highlightHumanoid.Name = "HighlightHumanoid"
        highlightHumanoid.Parent = object
      end

      local primaryPart = object.PrimaryPart

      if primaryPart then
        primaryPart.Transparency = 0.999
        primaryPart.Material = Enum.Material.Glass
      end

      table.insert(ESPCategories.Entities, object)

      if loader and loader.ObjectMaxDistance then
        loader.ObjectMaxDistance[object] = 10000
      end

      if toggles.EntitiesESP.Value then
        local alias = (name == "FigureRig" or name == "FigureRagdoll") and "Figure"
          or EntityNotifyData[name] and EntityNotifyData[name].Alias or name

        local value = options.EntitiesESPAllowed and options.EntitiesESPAllowed.Value

        if not value or next(value) == nil or value[alias] then
          local roomBound = object:GetAttribute("ParentRoom") ~= nil

          Functions.AddESP({
            Object = object, Text = alias, Color = options.EntitiesESPColor.Value, }, roomBound)
        end
      end

      notifyEntitySpawn(object)
    end)

    return
  end

  if name == "Ladder" then
    doorCategory = "Ladders"
    locked = "Ladder"
    table.insert(ESPCategories.Ladders, object)

    if CurrentFloor == "Mines" then
      addCategoryESP(object, doorCategory, locked)
    end

    return
  elseif name == "GoldPile" and object:GetAttribute("GoldValue") then
    doorCategory = "Gold"
    locked = "Gold Pile [" .. object:GetAttribute("GoldValue") .. "]"
  elseif name == "StardustPickup" then
    doorCategory = "Objectives"
    locked = "Stardust"
  elseif (name == "SkeletonKey" or name == "IronKey" or name == "KeyIron" or name == "IronKeyForCrypt") and object:FindFirstChild("ModulePrompt") then
    doorCategory = "Keys"
    locked = lastPrompt[name] or "Key"

    if not object:IsDescendantOf(localPlayer) and object.Parent.Name ~= "Drops" then
      notifyItemSpawn(locked, object)
    end
  elseif lastPrompt[name] and object:FindFirstChild("ModulePrompt") then
    doorCategory = "Items"
    locked = lastPrompt[name]

    if not object:IsDescendantOf(localPlayer) and object.Parent.Name ~= "Drops" then
      notifyItemSpawn(lastPrompt[name], object)
    end
  elseif name == "Green_Herb" then
    doorCategory = "Items"
    locked = "Green Herb"
  elseif name == "ChestBox" or name == "ChestBoxLocked" then
    doorCategory = "Chests"
    locked = object:GetAttribute("Locked") and "Locked Chest" or "Chest"
  elseif name == "Toolbox" or name == "Toolbox_Locked" then
    doorCategory = "Chests"
    locked = object:GetAttribute("Locked") and "Locked Toolbox" or "Toolbox"
  elseif name == "Chest_Vine" then
    doorCategory = "Chests"
    locked = "Vine Chest"
  elseif name == "Toolshed_Small" then
    doorCategory = "Chests"
    locked = "Toolshed"
  elseif name == "Locker_Small_Locked" then
    doorCategory = "Chests"
    locked = "Locked Locker"
  elseif name == "MouseHole" then
    doorCategory = "Chests"
    locked = "Mouse"
  elseif ({
    Wardrobe = true, Backdoor_Wardrobe = true, Toolshed = true, RetroWardrobe = true, ["Wardrobe-FOOLS26"] = true, Locker_Large = true, Rooms_Locker = true, Rooms_Locker_Fridge = true, Bed = true, Double_Bed = true, CircularVent = true, Dumpster = true, })[name] then
    local closetNames = {
      Wardrobe = "Closet", Backdoor_Wardrobe = "Closet", Toolshed = "Closet", RetroWardrobe = "Closet", ["Wardrobe-FOOLS26"] = "Closet", Locker_Large = "Locker", Rooms_Locker = "Locker", Rooms_Locker_Fridge = "Locker", Bed = "Bed", Double_Bed = "Double Bed", CircularVent = "Vent", Dumpster = "Dumpster", }

    doorCategory = "HidingSpots"
    locked = closetNames[name]
    Functions.HandleHidingTransparency(object)
    table.insert(worldObjects.HidingSpots, object)
  elseif name:match("^HidingSpot%d+$") then
    doorCategory = "HidingSpots"
    locked = "Hiding Spot"
    Functions.HandleHidingTransparency(object)
    table.insert(worldObjects.HidingSpots, object)
  elseif ({
    KeyObtain = "Key", ElectricalKeyObtain = "Electrical Key", MinesGenerator = "Generator", FuseObtain = "Fuse", LiveHintBook = "Book", LiveBreakerPolePickup = "Fuse Breaker", LibraryHintPaper = "LibraryPaper", PickupItem = "Library Paper", CringlePresent = "Present", LeverForGate = "Gate Lever", MinesGateButton = "Gate Button", GardenGateButton = "Gate Button", MinesAnchor = "Anchor", WaterPump = "Water Pump", TimerLever = "Timer Lever", VineGuillotine = "Vine Guillotine", })[name] then
    local objectLabels = {
      KeyObtain = "Key", ElectricalKeyObtain = "Electrical Key", MinesGenerator = "Generator", FuseObtain = "Fuse", LiveHintBook = "Book", LiveBreakerPolePickup = "Fuse Breaker", LibraryHintPaper = "Library Paper", PickupItem = "Hint Paper", CringlePresent = "Present", LeverForGate = "Gate Lever", MinesGateButton = "Gate Button", GardenGateButton = "Gate Button", MinesAnchor = "Anchor", WaterPump = "Water Pump", TimerLever = "Timer Lever", VineGuillotine = "Vine Guillotine", }

    if name == "KeyObtain" or name == "ElectricalKeyObtain" then
      doorCategory = "Keys"
    else
      doorCategory = "Objectives"
    end
    locked = objectLabels[name]

    if name == "KeyObtain" then
      task.spawn(function()
        task.wait(6.25)

        if not object or not object.Parent then
          return
        end

        table.insert(ESPCategories[doorCategory], object)
        addCategoryESP(object, doorCategory, locked)
      end)
    end

    if name == "TimerLever" then
      task.spawn(function()
        task.wait(1.25)

        if not object or not object.Parent then
          return
        end

        table.insert(ESPCategories[doorCategory], object)
        addCategoryESP(object, doorCategory, locked)
      end)

      return
    end

    if name == "WaterPump" then
      task.spawn(function()
        local wheel = object:FindFirstChild("Wheel")

        if wheel then
          local sound = wheel:FindFirstChild("Sound")

          if sound then
            sound.Played:Once(function() object:SetAttribute("CH_Completed", true) end)
          end
        end
      end)
    end
  elseif name == "ArchivesTerminal" and CurrentFloor == "Archives" then
    doorCategory = "Objectives"
    locked = "Archives Terminal"
  elseif name == "StairwellTerminal" and CurrentFloor == "Stairwell" then
    doorCategory = "Objectives"
    locked = "Stairwell Terminal"
  else
    return
  end

  table.insert(ESPCategories[doorCategory], object)
  addCategoryESP(object, doorCategory, locked)
end

local function getESPLabel(object, category)
  local name = object.Name

  if category == "Doors" then
    local parentRoom = object:GetAttribute("ParentRoom")
    return "Door " .. (parentRoom and tostring(parentRoom) or "")
  end

  if category == "Gold" then
    local gVal = object:GetAttribute("GoldValue")
    return gVal and ("Gold Pile [" .. tostring(gVal) .. "]") or "Gold"
  end

  if category == "Keys" then
    local keyNames = {
      KeyObtain = "Key", ElectricalKeyObtain = "Electrical Key",
      KeyObtainFake = "Fake Key", SkeletonKey = "Skeleton Key",
      IronKey = "Iron Key", KeyIron = "Iron Key", IronKeyForCrypt = "Iron Key"
    }
    return keyNames[name] or "Key"
  end

  if category == "Items" then
    return name == "Green_Herb" and "Green Herb" or lastPrompt[name] or name
  end

  if category == "Ladders" then
    return "Ladder"
  end

  if category == "Entities" then
    return EntityNotifyData[name] and EntityNotifyData[name].Alias or name
  end

  local closetNames = {
    Wardrobe = "Closet", Backdoor_Wardrobe = "Closet", Toolshed = "Closet", RetroWardrobe = "Closet", ["Wardrobe-FOOLS26"] = "Closet", Locker_Large = "Locker", Rooms_Locker = "Locker", Rooms_Locker_Fridge = "Locker", Bed = "Bed", Double_Bed = "Double Bed", CircularVent = "Vent", Dumpster = "Dumpster", }

  if closetNames[name] then
    return closetNames[name]
  end

  local objectLabels = {
    KeyObtain = "Key", ElectricalKeyObtain = "Electrical Key", MinesGenerator = "Generator", FuseObtain = "Generator Fuse", LiveHintBook = "Book", LiveBreakerPolePickup = "Fuse Breaker", LibraryHintPaper = "Library Paper", PickupItem = "Library Paper", CringlePresent = "Present", LeverForGate = "Gate Lever", MinesGateButton = "Gate Button", GardenGateButton = "Gate Button", MinesAnchor = "Anchor", WaterPump = "Water Pump", TimerLever = "Timer Lever", VineGuillotine = "Vine Guillotine", ChestBox = "Chest", ChestBoxLocked = "Locked Chest", Toolbox = "Toolbox", Toolbox_Locked = "Locked Toolbox", Chest_Vine = "Vine Chest", Toolshed_Small = "Toolshed", Locker_Small_Locked = "Locked Locker", MouseHole = "Mouse", GoldPile = "Gold", StardustPickup = "Stardust", }

  return objectLabels[name] or name
end

local function refreshCategoryESP(category)
  local color = options[colorFlags[category]].Value
  local showText = toggles.ESPShowText.Value
  local useTracers = toggles[category .. "Tracers"] and toggles[category .. "Tracers"].Value

  local allowed = category == "Entities" and options.EntitiesESPAllowed
    and options.EntitiesESPAllowed.Value

  for _, object in ipairs(ESPCategories[category] or {}) do
    local isAllowed = true

    if allowed and next(allowed) ~= nil then
      if not allowed[EntityNotifyData[object.Name] and EntityNotifyData[object.Name].Alias or object.Name] then
        isAllowed = false
      end
    end

    if isAllowed then
      local target = GetESPTarget(object, category)

      if target then
        local roomBound = object:GetAttribute("ParentRoom") ~= nil

        Functions.AddESP({
          Object = target, Text = showText and getESPLabel(object, category) or "", Color = color, }, roomBound)

        if useTracers then
          loader:SetTracersEnabled(target, true)
        end
      end
    end
  end

  if category == "Items" and (toggles.GoldESP and toggles.GoldESP.Value or toggles.ItemsESP and toggles.ItemsESP.Value) then
    for _, object in ipairs(ESPCategories.Gold or {}) do
      local target = GetESPTarget(object, "Gold")
      if target then
        local roomBound = object:GetAttribute("ParentRoom") ~= nil
        local gColor = options.GoldESPColor and options.GoldESPColor.Value or Color3.fromRGB(255, 215, 0)
        Functions.AddESP({ Object = target, Text = showText and getESPLabel(object, "Gold") or "", Color = gColor }, roomBound)
      end
    end
  elseif category == "Objectives" and (toggles.KeysESP and toggles.KeysESP.Value or toggles.ObjectivesESP and toggles.ObjectivesESP.Value) then
    for _, object in ipairs(ESPCategories.Keys or {}) do
      local target = GetESPTarget(object, "Keys")
      if target then
        local roomBound = object:GetAttribute("ParentRoom") ~= nil
        local kColor = options.KeysESPColor and options.KeysESPColor.Value or Color3.fromRGB(0, 191, 255)
        Functions.AddESP({ Object = target, Text = showText and getESPLabel(object, "Keys") or "", Color = kColor }, roomBound)
      end
    end
  end
end

local function addESPCategoryControls(category, text)
  local toggleKey = ESPToggleKeys[category]
  local colorKey = colorFlags[category]

  local defaultColors = {
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

  Groupboxes.Visuals_ESP:AddToggle(toggleKey, { Text = text, Default = false })

  toggles[toggleKey]:AddColorPicker(colorKey, { Text = text, Default = defaultColors[category] })

  toggles[toggleKey]:OnChanged(function(value)
    if value then
      refreshCategoryESP(category)
    else
      removeCategoryESP(category)
    end
  end)

  options[colorKey]:OnChanged(function(value)
    for _, object in ipairs(ESPCategories[category]) do
      local target = GetESPTarget(object, category)

      if loader.ColorTable and loader.ColorTable[target] then
        loader:UpdateObjectColor(target, value)
      end
    end
  end)
end


local playerCharacters = {}

local function refreshPlayersESP()
  for _, character2 in ipairs(playerCharacters) do
    loader:RemoveESP(character2)
    local cleanup = ESPCleanup[character2]

    if cleanup then
      cleanup:Disconnect()
      ESPCleanup[character2] = nil
    end
  end

  for i = #playerCharacters, 1, -1 do
    playerCharacters[i] = nil
  end

  if not toggles.PlayersESP.Value then
    return
  end

  for _, player in players:GetPlayers() do
    if player ~= localPlayer then
      local character2 = player.Character

      if character2 then
        if character2:FindFirstChild("HumanoidRootPart")
          or character2:FindFirstChildOfClass("BasePart") then
          local humanoid2 = character2:FindFirstChildOfClass("Humanoid")

          loader:AddESP({
            Object = character2, Text = player.Name
              .. (humanoid2 and " [" .. math.floor(humanoid2.Health) .. " HP]" or ""), Color = options.PlayersESPColor.Value, })

          ESPCleanup[character2] = character2.Destroying:Once(function()
            loader:RemoveESP(character2)
            ESPCleanup[character2] = nil
          end)

          table.insert(playerCharacters, character2)
        end
      end
    end
  end
end

local function watchPlayerCharacter(player)
  if player == localPlayer then
    return
  end

  local connection = player.CharacterAdded:Connect(function(character2)
    task.wait(0.5)

    if toggles.PlayersESP and toggles.PlayersESP.Value and character2 then
      if character2:FindFirstChild("HumanoidRootPart")
        or character2:FindFirstChildOfClass("BasePart") then
        local humanoid2 = character2:FindFirstChildOfClass("Humanoid")

        loader:AddESP({
          Object = character2, Text = player.Name
            .. (humanoid2 and " [" .. math.floor(humanoid2.Health) .. " HP]" or ""), Color = options.PlayersESPColor.Value, })

        ESPCleanup[character2] = character2.Destroying:Once(function()
          loader:RemoveESP(character2)
          ESPCleanup[character2] = nil
        end)

        table.insert(playerCharacters, character2)
      end
    end
  end)
end

function Handlers.PlayersESPChanged(value)
  if value then
    refreshPlayersESP()
  else
    refreshPlayersESP()
  end
end


function Handlers.PlayersESPColorChanged(value)
  for _, character2 in ipairs(playerCharacters) do
    loader:UpdateObjectColor(character2, value)
  end
end


players.PlayerAdded:Connect(watchPlayerCharacter)

for _, player in players:GetPlayers() do
  if player ~= localPlayer then
    watchPlayerCharacter(player)
  end
end


local lobbyState = { MainTab = nil, MainButton = nil, NoclipConn = nil }

LobbyFlyState = {
  Flying = false, FlyKeyDown = nil, FlyKeyUp = nil, BodyGyro = nil, BodyVelocity = nil, Control = nil, LastControl = nil, Speed = 0, SpeedCoeff = 1, }

local function stopLobbyFly()
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

  local humanoid2 = character and character:FindFirstChildOfClass("Humanoid")

  if humanoid2 then
    humanoid2.PlatformStand = false
  end

  pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
end

local function startLobbyFly()
  if LobbyFlyState.Flying then
    return
  end

  if not character then
    return
  end

  local humanoid2 = character:FindFirstChildOfClass("Humanoid")

  if not humanoid2 then
    return
  end

  local rootPart = humanoid2.RootPart or character:FindFirstChild("HumanoidRootPart")
    or character:FindFirstChildOfClass("Part")

  if not rootPart then
    return
  end

  stopLobbyFly()

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

  lobbyFlyState.FlyKeyDown = userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
      return
    end

    local control = lobbyFlyState.Control
    local speedCoeff = lobbyFlyState.SpeedCoeff

    if input.KeyCode == Enum.KeyCode.W then
      control.F = speedCoeff
    elseif input.KeyCode == Enum.KeyCode.S then
      control.B = -speedCoeff
    elseif input.KeyCode == Enum.KeyCode.A then
      control.L = -speedCoeff
    elseif input.KeyCode == Enum.KeyCode.D then
      control.R = speedCoeff
    elseif input.KeyCode == Enum.KeyCode.E then
      control.Q = speedCoeff * 2
    elseif input.KeyCode == Enum.KeyCode.Q then
      control.E = -speedCoeff * 2
    end

    pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Track end)
  end)

  lobbyFlyState.FlyKeyUp = userInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then
      return
    end

    local control = lobbyFlyState.Control

    if input.KeyCode == Enum.KeyCode.W then
      control.F = 0
    elseif input.KeyCode == Enum.KeyCode.S then
      control.B = 0
    elseif input.KeyCode == Enum.KeyCode.A then
      control.L = 0
    elseif input.KeyCode == Enum.KeyCode.D then
      control.R = 0
    elseif input.KeyCode == Enum.KeyCode.E then
      control.Q = 0
    elseif input.KeyCode == Enum.KeyCode.Q then
      control.E = 0
    end
  end)

  task.spawn(function()
    repeat
      task.wait()

      if not lobbyFlyState.Flying then
        break
      end

      local currentCamera2 = workspace.CurrentCamera
      humanoid2.PlatformStand = true
      local control = lobbyFlyState.Control
      local lastControl = lobbyFlyState.LastControl
      local speed = lobbyFlyState.Speed

      if control.L + control.R ~= 0 or control.F + control.B ~= 0
        or control.Q + control.E ~= 0 then
        speed = 50
      elseif not (control.L + control.R ~= 0 or control.F + control.B ~= 0
          or control.Q + control.E ~= 0)
        and speed ~= 0 then
        speed = 0
      end

      if control.L + control.R ~= 0 or control.F + control.B ~= 0
        or control.Q + control.E ~= 0 then
        pcall(function()
          bodyVelocity.Velocity = (currentCamera2.CFrame.LookVector * (control.F + control.B) + (currentCamera2.CFrame * CFrame.new(
            control.L + control.R, (control.F + control.B + control.Q + control.E) * 0.2, 0
          ).Position - currentCamera2.CFrame.Position)) * speed
        end)

        lastControl.F, lastControl.B, lastControl.L, lastControl.R = control.F, control.B, control.L, control.R
      elseif control.L + control.R == 0 and control.F + control.B == 0
        and control.Q + control.E == 0 and speed ~= 0 then
        pcall(function()
          bodyVelocity.Velocity = (currentCamera2.CFrame.LookVector * (lastControl.F + lastControl.B) + (currentCamera2.CFrame * CFrame.new(
            lastControl.L + lastControl.R, (lastControl.F + lastControl.B + control.Q + control.E) * 0.2, 0
          ).Position - currentCamera2.CFrame.Position)) * speed
        end)
      else
        pcall(function() bodyVelocity.Velocity = Vector3.new(0, 0, 0) end)
      end

      pcall(function() bodyGyro.CFrame = currentCamera2.CFrame end)
      lobbyFlyState.Speed = speed
    until not lobbyFlyState.Flying

    stopLobbyFly()
  end)
end

function lobbyState.MainTab()
  if type(lobbyState.MainTab) ~= "function" then
    return
  end

  local addTab = moroWindow:AddTab("LobbyMain", "house")

  lobbyState.MainTab = addTab
  lobbyState.MainButton = getTabButton(addTab)

  local label = getTabLabel(addTab)

  if label then
    label.Text = "Main"
  end

  if lobbyState.MainButton then
    lobbyState.MainButton.Visible = false
  end

  local stuff = addTab:AddLeftGroupbox("Stuff")

  stuff:AddButton({
    Text = "Free Rooms", Callback = function()
      local createElevator = remotesFolder and remotesFolder:FindFirstChild("CreateElevator")

      if createElevator then
        createElevator:FireServer({
          Mods = { "AdminPanel" }, Settings = {}, Destination = "Rooms", FriendsOnly = false, MaxPlayers = "1", })
      end
    end, })

  stuff:AddButton({
    Text = "Free Outdoors", Callback = function()
      local createElevator = remotesFolder and remotesFolder:FindFirstChild("CreateElevator")

      if createElevator then
        createElevator:FireServer({
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
      if featureState.RedeemingCodes then
        return
      end

      library:Notify({ Title = "Redeeming " .. #featureState.CodesList .. " codes.", Time = 5 })
      featureState.RedeemingCodes = true

      for _, codes in ipairs(featureState.CodesList) do
        local shopCode = remotesFolder and remotesFolder:FindFirstChild("ShopCode")

        if shopCode then
          shopCode:FireServer(codes)
        end

        task.wait(5.1)
      end

      featureState.RedeemingCodes = false
    end, })

  local otherStuff = addTab:AddRightGroupbox("Other stuff")
  otherStuff:AddToggle("LobbyNoclip", { Text = "Noclip", Default = false })

  toggles.LobbyNoclip:OnChanged(function(value)
    if lobbyState.NoclipConn then
      lobbyState.NoclipConn:Disconnect()
    end

    if value and character then
      for _, descendant in character:GetDescendants() do
        if descendant:IsA("BasePart") then
          descendant.CanCollide = false
        end
      end

      lobbyState.NoclipConn = character.ChildAdded:Connect(function(child)
        task.wait()

        if child:IsA("BasePart") then
          child.CanCollide = false
        end
      end)
    end
  end)

  otherStuff:AddToggle("LobbyFly", { Text = "Fly", Default = false })

  toggles.LobbyFly:OnChanged(function(value)
    if value then
      startLobbyFly()
    else
      stopLobbyFly()
    end
  end)

  otherStuff:AddSlider("LobbyFlySpeed", {
    Text = "Fly Speed", Min = 25, Max = 150, Default = 35, Rounding = 0, Compact = true, })

  options.LobbyFlySpeed:OnChanged(function()
    LobbyFlyState.SpeedCoeff = (options.LobbyFlySpeed and options.LobbyFlySpeed.Value or 35)
      / 50
  end)
end

local lobbyTabs = { "Main", "Visuals", "Exploits", "Miscellaneous", "Mines", "Archives", "Settings" }

local function updateFloor()
  local floorName = detectFloor()

  if floorName == CurrentFloor then
    return
  end

  CurrentFloor = floorName
  local isLobby = floorName == "" or floorName == "Lobby"
  local isHotel = floorName == "Hotel" or floorName == "OldHotel"
  local isMines = floorName == "Mines"
  local isGarden = floorName == "Garden"
  local isFools = floorName == "Fools"
  local isOldHotel = floorName == "OldHotel"
  local isRooms = floorName == "Rooms"
  local isArchives = floorName == "Archives"
  local isStairwell = floorName == "Stairwell"

  if isLobby then
    featureState.InLobby = true
    lobbyState.MainTab()

    if tabs.Home then
      tabs.Home:SetVisible(true)
    end

    for _, tabName in ipairs(lobbyTabs) do
      local tab = tabs[tabName]

      if tab then
        tab:SetVisible(false)
      end
    end

    if lobbyState.MainButton then
      lobbyState.MainButton.Visible = true
    end

    if not isTabActive(tabs.Home) and not isTabActive(lobbyState.MainTab) then
      tabs.Home:Show()
    end

    for _, flag in ipairs({
      "Godmode", "ThirdPerson", "Noclip", "FlyToggle", "Phase", "AnticheatManipulation", "AutoInteract", "ArchiveChairFly", "StairwellChairFly", "AntiElectricPuddle", "AntiRansom", "AntiScribbles", "NoAlmaDamage", "AntiDrone", "DisableDroneStampede", "RoomsAutoWalk", "RoomsAutoWalkIgnoreA60", "RoomsAutoWalkShowPathToggle", "RoomsAutoWalkSpoofFootsteps", "RoomsPickupStardust", "RoomsPickupGold", "NoSurgeDamage", "RemoveSurge", "RemoveMandrake", "BypassKillbricks", "BypassSeekingWall", "BypassBanana", "BypassJeff", "BypassGiggle", "BypassDupe", "BypassEyes", "BypassLookman", "BypassGloombatEggs", "BypassSeekObstructions", "BypassVacuum", "BypassSnare", "RemoveSeekTrigger", "RemoveFigure", "RemoveFigureMines", "RemoveA90", "RemoveDread", "AutoRevive", "FigureGodmode", "AutoSteerMinecart", "AutoSolveAnchors", "MinecartTeleport", "AutoMinecart", "AutoHeartbeatMinigame", "AutoBreakerBox", "AutoLibraryBruteForce", "InfiniteItemsToggle", "InfiniteCrucifix", "ShowSeekPathToggle", }) do
      local toggle = toggles[flag]

      if toggle and toggle.Value then
        toggle:SetValue(false)
      end
    end

    if not featureState.LobbyGuardConnection then
      featureState.LobbyGuardConnection = runService.Heartbeat:Connect(function()
        if _Unloading then
          return
        end

        if not featureState.InLobby then
          return
        end

        for _, flag in ipairs({
          "Godmode", "ThirdPerson", "Noclip", "FlyToggle", "Phase", "AnticheatManipulation", "AutoInteract", }) do
          local toggle = toggles[flag]

          if toggle and toggle.Value then
            toggle:SetValue(false)
          end
        end

        if toggles.AutoJoinElevator and toggles.AutoJoinElevator.Value then
          local character2

          if typeof(options.AutoJoinElevatorTarget.Value) == "Instance" then
            character2 = options.AutoJoinElevatorTarget.Value.Character
          elseif typeof(options.AutoJoinElevatorTarget.Value) == "string" then
            character2 = players:FindFirstChild(options.AutoJoinElevatorTarget.Value).Character
          end

          local elevatorFound = false

          local lobbyElevators = workspace:FindFirstChild("Lobby")
            and workspace.Lobby:FindFirstChild("LobbyElevators")

          if lobbyElevators then
            for _, child in lobbyElevators:GetChildren() do
              if character2 and child and character2:GetAttribute("InGameElevator")
                and child:GetAttribute("ID")
                and child:GetAttribute("ID") == character2:GetAttribute("InGameElevator") then
                elevatorFound = true

                if remotesFolder and remotesFolder:FindFirstChild("ElevatorJoin") then
                  remotesFolder.ElevatorJoin:FireServer(child)
                end
              end
            end
          end

          if not elevatorFound and remotesFolder and remotesFolder:FindFirstChild("ElevatorExit") then
            remotesFolder.ElevatorExit:FireServer()
          end
        end
      end)
    end

    if tabs.FoolsHotel then
      tabs.FoolsHotel:SetVisible(false)
    end

    if tabs.Rooms then
      tabs.Rooms:SetVisible(false)
    end

    if tabs.Stairwell then
      tabs.Stairwell:SetVisible(false)
    end

    return
  end

  featureState.InLobby = false

  if featureState.LobbyGuardConnection then
    featureState.LobbyGuardConnection:Disconnect()
    featureState.LobbyGuardConnection = nil
  end

  if lobbyState.MainTab then
    if lobbyState.MainButton then
      lobbyState.MainButton.Visible = false
    end

    if toggles.LobbyNoclip then
      toggles.LobbyNoclip:SetValue(false)
    end

    if toggles.LobbyFly then
      toggles.LobbyFly:SetValue(false)
    end

    if isTabActive(lobbyState.MainTab) then
      tabs.Home:Show()
    end
  end

  if CurrentFloor and CurrentFloor ~= "Lobby" then
    TableClear(ESPCleanup)
    TableClear(ESPBlacklist)

    for _, ESPCategory in pairs(ESPCategories) do
      TableClear(ESPCategory)
    end

    for _, entity in ipairs(worldObjects.Entities) do
      if entity.Name == "FakeDoor" or entity.Name == "DoorFake" then
        local hidden = entity:FindFirstChild("Hidden")

        if hidden then
          hidden.CanTouch = true
        end

        local lock = entity:FindFirstChild("Lock")

        if lock and lock:FindFirstChild("UnlockPrompt") then
          lock.UnlockPrompt.Enabled = true
        end
      end

      if entity.Name == "SideroomSpace" then
        local collision2 = entity:FindFirstChild("Collision")

        if collision2 then
          collision2.CanCollide = false
          collision2.CanTouch = true
        end
      end
    end

    for _, _ in ipairs(worldObjects.Entities) do
    end

    TableClear(worldObjects.Entities)
    TableClear(worldObjects.HidingSpots)
    TableClear(worldObjects.Obstructions)
    TableClear(worldObjects.SeekObstructions)
    TableClear(worldObjects.SeekBridges)
    TableClear(worldObjects.SeekNodes)
    TableClear(worldObjects.SeekDuckBoards)
    TableClear(worldObjects.SeekHighlights)
    TableClear(worldObjects.EyestalkHighlights)
    TableClear(worldObjects.PathLights)
    TableClear(worldObjects.EventTriggers)
  end

  local isNotHotelOrMines = not (isHotel or isMines)

  if options.SpamBuyCount then
    pcall(function() options.SpamBuyCount:SetDisabled(isNotHotelOrMines) end)
  end

  if options.SpamBuyItems then
    pcall(function() options.SpamBuyItems:SetDisabled(isNotHotelOrMines) end)
  end

  if toggles.AutoBuyLockpicks then
    pcall(function() toggles.AutoBuyLockpicks:SetDisabled(isNotHotelOrMines) end)
  end

  if isHotel and options.SpamBuyItems then
    local essentialItems = { "Lockpick", "Lighter", "Flashlight", "Vitamins" }

    if isOldHotel then
      table.insert(essentialItems, "Crucifix")
      table.insert(essentialItems, "Skeleton Key")
    end

    pcall(options.SpamBuyItems.SetValues, options.SpamBuyItems, essentialItems)
  elseif isMines and options.SpamBuyItems then
    pcall(options.SpamBuyItems.SetValues, options.SpamBuyItems, {
      "Straplight", "Bulklight", "BandagePack", "Lockpick", })
  end

  if toggles.ShowCrucifix then
    pcall(function() toggles.ShowCrucifix:SetDisabled(not isOldHotel) end)
  end

  if toggles.ShowSkeletonKey then
    pcall(function() toggles.ShowSkeletonKey:SetDisabled(not isOldHotel) end)
  end

  local showPadlockOption = not (isHotel or type(floorName) == "string" and floorName:find("Fools"))

  if toggles.AutoUnlockPadlockToggle then
    pcall(function() toggles.AutoUnlockPadlockToggle:SetDisabled(showPadlockOption) end)
  end

  if toggles.AutoBreakerBox then
    pcall(function() toggles.AutoBreakerBox:SetDisabled(showPadlockOption) end)
  end

  if toggles.AutoLibraryBruteForce then
    pcall(function() toggles.AutoLibraryBruteForce:SetDisabled(showPadlockOption) end)
  end

  if toggles.OrbitItems then
    pcall(function() toggles.OrbitItems:SetDisabled(isFools) end)
  end

  if tabs.Mines then
    tabs.Mines:SetVisible(isMines)
  end

  for _, tabName in ipairs(lobbyTabs) do
    if tabName ~= "Mines" and tabName ~= "Archives" then
      local tab = tabs[tabName]

      if tab then
        tab:SetVisible(true)
      end
    end
  end

  if tabs.Mines and not isMines and isTabActive(tabs.Mines) then
    tabs.Home:Show()
  end

  if tabs.FoolsHotel then
    if isFools or isOldHotel then
      tabs.FoolsHotel:SetVisible(true)

      if tabs.FoolsHotel.TabLabelRef then
        tabs.FoolsHotel.TabLabelRef.Text = isFools and "Fools" or "Hotel-/Fools"
      end

      for index, element in ipairs(Groupboxes.SubfloorsFools.Elements) do
        if index <= 5 then
          element.Holder.Visible = isFools
        end
      end
    else
      if isTabActive(tabs.FoolsHotel) then
        tabs.Home:Show()
      end

      tabs.FoolsHotel:SetVisible(false)
    end
  end

  if tabs.Garden then
    if isGarden then
      tabs.Garden:SetVisible(true)
    else
      if isTabActive(tabs.Garden) then
        tabs.Home:Show()
      end

      tabs.Garden:SetVisible(false)
    end
  end

  if tabs.Rooms then
    if isRooms then
      tabs.Rooms:SetVisible(true)
    else
      if isTabActive(tabs.Rooms) then
        tabs.Home:Show()
      end

      tabs.Rooms:SetVisible(false)
    end
  end

  if tabs.Archives then
    if isArchives then
      tabs.Archives:SetVisible(true)
    else
      if isTabActive(tabs.Archives) then
        tabs.Home:Show()
      end

      tabs.Archives:SetVisible(false)
    end
  end

  if tabs.Stairwell then
    if isStairwell then
      tabs.Stairwell:SetVisible(true)
    else
      if isTabActive(tabs.Stairwell) then
        tabs.Home:Show()
      end

      tabs.Stairwell:SetVisible(false)
    end
  end

  if toggles.LaddersESP and toggles.LaddersESP.Value then
    for _, ladder in ipairs(ESPCategories.Ladders) do
      if isMines then
        addCategoryESP(ladder, "Ladders", "Ladder")
      else
        Functions.RemoveESP(ladder)
      end
    end
  end
end

local function findClockRoom()
  local bestRoom, bestRoomNumber = nil, -1
  local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

  if not currentRooms2 then
    return nil
  end

  for _, child in ipairs(currentRooms2:GetChildren()) do
    local number = tonumber(child.Name)

    if number and number >= bestRoomNumber then
      local assets = child:FindFirstChild("Assets")
      local archivesClock = assets and assets:FindFirstChild("ArchivesClock")

      if archivesClock then
        bestRoom, bestRoomNumber = archivesClock, number
      end
    end
  end

  return bestRoom
end

local function formatClockTime(totalMinutes)
  local floorVal = math.floor(totalMinutes / 60)
  local minutes = totalMinutes % 60
  local period = floorVal >= 12 and "PM" or "AM"
  local hour = floorVal % 12

  if hour == 0 then
    hour = 12
  end

  return string.format("%d:%02d %s", hour, minutes, period)
end


local DroneConnection = nil
local DroneWalkedIntoParents = {}
function Handlers.BypassDronesChanged(Value)
  local function ProcessDrones(drones)
    local WalkedInto = drones:FindFirstChild("WalkedInto") or drones:WaitForChild("WalkedInto", 3)
    if WalkedInto and not DroneWalkedIntoParents[WalkedInto] then
      DroneWalkedIntoParents[WalkedInto] = drones
      WalkedInto.Parent = replicatedStorage
    end
  end

  if Value then
    for _, child in ipairs(workspace:GetChildren()) do
      if child.Name == "Drones" then
        ProcessDrones(child)
      end
    end

    if DroneConnection then
      DroneConnection:Disconnect()
    end
    DroneConnection = workspace.ChildAdded:Connect(function(child)
      if child.Name == "Drones" then
        ProcessDrones(child)
      end
    end)
    table.insert(Connections, DroneConnection)
  else
    for WalkedInto, originalParent in pairs(DroneWalkedIntoParents) do
      if WalkedInto and WalkedInto.Parent and originalParent and originalParent.Parent then
        WalkedInto.Parent = originalParent
      end
    end
    table.clear(DroneWalkedIntoParents)

    if DroneConnection then
      DroneConnection:Disconnect()
      DroneConnection = nil
    end
  end
end


local BypassDronesStampedeConnection = nil
function Handlers.BypassDronesStampedeChanged(Value)
  if BypassDronesStampedeConnection then
    task.cancel(BypassDronesStampedeConnection)
    BypassDronesStampedeConnection = nil
  end

  if not Value then return end

  BypassDronesStampedeConnection = task.spawn(function()
    while toggles.BypassDronesStampede and toggles.BypassDronesStampede.Value do
      local clock = findClockRoom()
      local lookedAtRemote = clock and clock:FindFirstChild("LookedAtRemote", true)

      if lookedAtRemote and lookedAtRemote:IsA("RemoteEvent") then
        pcall(function() lookedAtRemote:FireServer() end)
        task.wait(0.5)
      else
        task.wait(0.25)
      end
    end
  end)
end


function Handlers.DisableDroneStampedeChanged(value)
  if value and not featureState.DisableDroneStampedeRunning then
    featureState.DisableDroneStampedeRunning = true

    task.spawn(function()
      while toggles.DisableDroneStampede.Value do
        local clockRoom = findClockRoom()
        local lookedAtRemote = clockRoom and clockRoom:FindFirstChild("LookedAtRemote")

        if lookedAtRemote then
          pcall(function() lookedAtRemote:FireServer() end)
        end

        task.wait(0.5)
      end

      featureState.DisableDroneStampedeRunning = false
    end)
  end
end


local TimeShowerGui = nil
local TimeShowerLabel = nil
local TimeShowerConnection = nil
local TimeShowerToken = 0

local function GetTimeShowerLabel()
  if TimeShowerLabel and TimeShowerLabel.Parent then
    return TimeShowerLabel
  end
  local parentGui = (gethui and gethui()) or coreGui or localPlayer:FindFirstChildOfClass("PlayerGui")
  TimeShowerGui = Instance.new("ScreenGui")
  TimeShowerGui.Name = "TimeShowerGui"
  TimeShowerGui.ResetOnSpawn = false
  TimeShowerGui.DisplayOrder = 32767
  TimeShowerGui.Parent = parentGui

  TimeShowerLabel = Instance.new("TextLabel")
  TimeShowerLabel.Name = "TimeShower"
  TimeShowerLabel.AnchorPoint = Vector2.new(0, 1)
  TimeShowerLabel.Position = UDim2.new(0, 12, 1, -12)
  TimeShowerLabel.Size = UDim2.new(0, 180, 0, 32)
  TimeShowerLabel.BackgroundTransparency = 1
  TimeShowerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  TimeShowerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
  TimeShowerLabel.TextStrokeTransparency = 0.35
  TimeShowerLabel.Font = Enum.Font.GothamBold
  TimeShowerLabel.TextSize = 18
  TimeShowerLabel.TextXAlignment = Enum.TextXAlignment.Left
  TimeShowerLabel.Text = "Time: " .. string.char(45, 45, 58, 45, 45)
  TimeShowerLabel.Visible = false
  TimeShowerLabel.Parent = TimeShowerGui
  return TimeShowerLabel
end

local function StopTimeShower()
  TimeShowerToken = TimeShowerToken + 1
  if TimeShowerConnection then
    TimeShowerConnection:Disconnect()
    TimeShowerConnection = nil
  end
  if TimeShowerLabel then
    TimeShowerLabel.Visible = false
    TimeShowerLabel.Text = "Time: " .. string.char(45, 45, 58, 45, 45)
  end
end

function Handlers.TimeShowerChanged(Value)
  StopTimeShower()
  if not Value then return end

  local lbl = GetTimeShowerLabel()
  local Token = TimeShowerToken
  lbl.Visible = true

  TimeShowerConnection = runService.Heartbeat:Connect(function()
    if Token ~= TimeShowerToken then return end
    local clock = findClockRoom()
    local timeModel = clock and clock:FindFirstChild("Time")
    local txtLabel = timeModel and timeModel:FindFirstChild("TextLabel")
    if txtLabel and txtLabel.Text and txtLabel.Text ~= "" then
      lbl.Text = "Time: " .. txtLabel.Text
    else
      lbl.Text = "Time: " .. string.char(45, 45, 58, 45, 45)
    end
  end)
  table.insert(Connections, TimeShowerConnection)
end


function Handlers.DroneTimerChanged(value)
  if value and not featureState.DroneTimerRunning then
    featureState.DroneTimerRunning = true

    task.spawn(function()
      local seen = {}

      while toggles.DroneTimer.Value do
        local clockRoom = findClockRoom()
        local time = clockRoom and clockRoom:FindFirstChild("Time")
        local textLabel = time and time:FindFirstChild("TextLabel")
        local text = textLabel and textLabel.Text

        if text then
          local clockHours, clockMinutes = text:match("(%d+):(%d+)")

          if clockHours and clockMinutes then
            local number = tonumber(clockHours) * 60 + tonumber(clockMinutes)

            for _, targetMinutes in ipairs({ 300, 540 }) do
              local minutesLeft = (targetMinutes - number) % 1440

              if minutesLeft > 90 then
                seen["h_" .. targetMinutes] = nil
                seen["m_" .. targetMinutes] = nil
              else
                if minutesLeft <= 60 and minutesLeft > 0 and not seen["h_" .. targetMinutes] then
                  seen["h_" .. targetMinutes] = true

                  library:Notify({
                    Title = "Drones", Description = string.format("Drone stampede in 1 hour (%s)", formatClockTime(targetMinutes)), Time = 5, })
                end

                if minutesLeft <= 30 and minutesLeft > 0 and not seen["m_" .. targetMinutes] then
                  seen["m_" .. targetMinutes] = true

                  library:Notify({
                    Title = "Drones", Description = string.format(
                      "Drone stampede in 30 minutes (%s)", formatClockTime(targetMinutes)
                    ), Time = 5, })
                end
              end
            end
          end
        end

        task.wait(1)
      end

      featureState.DroneTimerRunning = false
    end)
  end
end


local WaterBypassConnection = nil
local WaterParts = {}
function Handlers.BypassWaterChanged(Value)
  if WaterBypassConnection then
    WaterBypassConnection:Disconnect()
    WaterBypassConnection = nil
  end

  if Value then
    library:Notify({ Title = "Archives", Description = "PositionSpoof Will Break This!.", Time = 4 })

    local function ProcessWaterBypassRoom(WaterBypassRoom)
      if not tonumber(WaterBypassRoom.Name) then return end
      task.wait(3)

      local WaterBypassWater = WaterBypassRoom:FindFirstChild("Water")
      if not WaterBypassWater or WaterParts[WaterBypassWater] then return end

      local WaterBypassPart = Instance.new("Part")
      WaterBypassPart.Name = "WaterBypass"
      WaterBypassPart.Anchored = true
      WaterBypassPart.CanCollide = true
      WaterBypassPart.CanTouch = false
      WaterBypassPart.CanQuery = false
      WaterBypassPart.Transparency = 0.25
      WaterBypassPart.Color = Color3.fromRGB(0, 150, 255)
      WaterBypassPart.Material = Enum.Material.ForceField

      if WaterBypassWater:IsA("BasePart") then
        WaterBypassPart.Size = WaterBypassWater.Size + Vector3.new(0, 0.5, 0)
        WaterBypassPart.CFrame = WaterBypassWater.CFrame * CFrame.new(0, 0.25, 0)
      elseif WaterBypassWater:IsA("Model") then
        local WaterBypassCFrame, WaterBypassSize = WaterBypassWater:GetBoundingBox()
        WaterBypassPart.Size = WaterBypassSize + Vector3.new(0, 0.5, 0)
        WaterBypassPart.CFrame = WaterBypassCFrame * CFrame.new(0, 0.25, 0)
      else
        WaterBypassPart.Size = Vector3.new(10, 1.5, 10)
        WaterBypassPart.CFrame = WaterBypassWater:GetPivot() * CFrame.new(0, 0.25, 0)
      end

      if WaterBypassPart.Size.Y > 3 then
        WaterBypassPart:Destroy()
        library:Notify({ Title = "Archives", Description = "Water Bypass removed: Softlock.", Time = 4 })
        return
      end

      WaterBypassPart.Parent = WaterBypassRoom
      WaterParts[WaterBypassWater] = WaterBypassPart
    end

    local currentRooms = workspace:FindFirstChild("CurrentRooms")
    if currentRooms then
      local latestRoomVal = replicatedStorage:FindFirstChild("GameData") and replicatedStorage.GameData:FindFirstChild("LatestRoom")
      local WaterBypassLatestRoomNumber = latestRoomVal and tonumber(latestRoomVal.Value) or tonumber(localPlayer:GetAttribute("CurrentRoom")) or 0

      for WaterBypassRoomNumber = math.max(0, WaterBypassLatestRoomNumber - 4), WaterBypassLatestRoomNumber do
        local WaterBypassRoom = currentRooms:FindFirstChild(tostring(WaterBypassRoomNumber))
        if WaterBypassRoom then
          task.spawn(ProcessWaterBypassRoom, WaterBypassRoom)
        end
      end

      WaterBypassConnection = currentRooms.ChildAdded:Connect(function(WaterBypassRoom)
        task.spawn(ProcessWaterBypassRoom, WaterBypassRoom)
      end)
      table.insert(Connections, WaterBypassConnection)
    end
  else
    for _, WaterBypassPart in pairs(WaterParts) do
      if WaterBypassPart then
        pcall(function() WaterBypassPart:Destroy() end)
      end
    end
    table.clear(WaterParts)
  end
end


function Handlers.AntiElectricPuddleChanged(value)
  if value then
    featureState.DefaultHipHeight = featureState.DefaultHipHeight or humanoid and humanoid.HipHeight or 2.396

    Connections.AntiElectricPuddle = runService.Heartbeat:Connect(function()
      if threatState and threatState.Sunk then
        return
      end

      if humanoid and humanoid.FloorMaterial == Enum.Material.Glass then
        if humanoid.HipHeight ~= 3 then
          humanoid.HipHeight = 3
        end
      elseif humanoid and featureState.DefaultHipHeight then
        if humanoid.HipHeight ~= featureState.DefaultHipHeight then
          humanoid.HipHeight = featureState.DefaultHipHeight
        end
      end
    end)
  else
    if Connections.AntiElectricPuddle then
      Connections.AntiElectricPuddle:Disconnect()
      Connections.AntiElectricPuddle = nil
    end

    if humanoid and featureState.DefaultHipHeight then
      humanoid.HipHeight = featureState.DefaultHipHeight
    end
  end
end


local AlmaConnection = nil
function Handlers.BypassAlmaChanged(Value)
  if AlmaConnection then
    AlmaConnection:Disconnect()
    AlmaConnection = nil
  end

  if Value then
    for _, child in ipairs(workspace:GetChildren()) do
      if child.Name == "Alma" then
        pcall(function() child:Destroy() end)
      end
    end

    AlmaConnection = workspace.ChildAdded:Connect(function(child)
      if child.Name == "Alma" then
        pcall(function() child:Destroy() end)
      end
    end)
    table.insert(Connections, AlmaConnection)
  end
end


function Handlers.NoAlmaDamageChanged(value)
  if value and not featureState.NoAlmaDamageRunning then
    featureState.NoAlmaDamageRunning = true

    local function applyAlmaConfig(parent)
      local waitForChild = parent:WaitForChild("Config", 5)

      if not waitForChild then
        return
      end

      for key, configValue in pairs({
        idle_angerGain = 0, idle_angerIndirectGain = 0, idle_angerDecay = 100, aggro_initialWindup = 9999, aggro_subsequentWindups = 9999, attack_slashCount = 0, attack_dashSpeed = 0, attack_hitDistance = 0, attack_minigameLength = 9999, }) do
        local groupName, fieldName = key:match("^([^_]+)_(.+)$")
        local findFirstChild = waitForChild:FindFirstChild(groupName)
        local findFirstChild2 = findFirstChild and findFirstChild:FindFirstChild(fieldName)

        if findFirstChild2 and findFirstChild2:IsA("ValueBase") then
          findFirstChild2.Changed:Connect(function()
            if findFirstChild2.Value ~= configValue then
              findFirstChild2.Value = configValue
            end
          end)

          findFirstChild2.Value = configValue
        end
      end
    end

    local function watchAlmaRemote(descendant)
      if descendant:IsA("RemoteEvent") and descendant.Name == "AlmaChangeState" then
        local parent = descendant.Parent

        if parent then
          applyAlmaConfig(parent)
        end
      end
    end

    Connections.NoAlmaDamage = workspace.DescendantAdded:Connect(watchAlmaRemote)

    for _, descendant in ipairs(workspace:GetDescendants()) do
      watchAlmaRemote(descendant)
    end
  elseif not value then
    featureState.NoAlmaDamageRunning = false

    if Connections.NoAlmaDamage then
      Connections.NoAlmaDamage:Disconnect()
      Connections.NoAlmaDamage = nil
    end
  end
end


local AntiClosetTrash_Connection = nil
function Handlers.AntiClosetTrashChanged(Value)
  if AntiClosetTrash_Connection then
    AntiClosetTrash_Connection:Disconnect()
    AntiClosetTrash_Connection = nil
  end

  if not Value then return end

  local function checkTrash(Child)
    if not (toggles.AntiClosetTrash and toggles.AntiClosetTrash.Value) then return end
    local Name = Child.Name
    if Name:sub(1, 6) == "Binder" or Name:sub(1, 4) == "Shoe" or Name:sub(1, 5) == "Shelf" then
      pcall(function() Child:Destroy() end)
    end
  end

  for _, child in ipairs(workspace:GetChildren()) do
    checkTrash(child)
  end

  AntiClosetTrash_Connection = workspace.ChildAdded:Connect(checkTrash)
  table.insert(Connections, AntiClosetTrash_Connection)
end


local ForgetMeNotConnection = nil
local ForgetMeNotRunning = false
local ForgetMeNotProcessing = {}
local ForgetMeNotNotified = {}

function Handlers.ForgetMeNotSolverChanged(Value)
  if ForgetMeNotConnection then
    ForgetMeNotConnection:Disconnect()
    ForgetMeNotConnection = nil
  end

  ForgetMeNotRunning = false
  ForgetMeNotProcessing = {}
  ForgetMeNotNotified = {}

  if not Value then return end

  ForgetMeNotRunning = true

  local function GetCharacter()
    return localPlayer.Character or localPlayer.CharacterAdded:Wait()
  end

  local function GetNextRoom(Number)
    while ForgetMeNotRunning do
      for RoomNumber = Number + 1, Number + 5 do
        local NextRoom = workspace.CurrentRooms:FindFirstChild(tostring(RoomNumber))
        if NextRoom then
          return NextRoom
        end
      end
      task.wait(0.1)
    end
    return nil
  end

  local function FireLookAts(Room)
    for i = 1, 6 do
      local Obj = Room:FindFirstChild(tostring(i))
      if Obj then
        local LookAt = Obj:FindFirstChild("LookAt")
        if LookAt then
          pcall(function()
            LookAt:FireServer()
          end)
        end
      end
    end
  end

  local function Run(Room)
    if not ForgetMeNotRunning or ForgetMeNotProcessing[Room] then
      return
    end

    ForgetMeNotProcessing[Room] = true

    task.wait(2)

    if not ForgetMeNotRunning or not Room.Parent then
      ForgetMeNotProcessing[Room] = nil
      return
    end

    if not Room:FindFirstChild("ForgetMeNotVineDoors", true) then
      ForgetMeNotProcessing[Room] = nil
      return
    end

    FireLookAts(Room)

    local NextRoom = GetNextRoom(tonumber(Room.Name))
    if not NextRoom then
      ForgetMeNotProcessing[Room] = nil
      return
    end

    local Door = NextRoom:FindFirstChild("Door")
    if not Door then
      ForgetMeNotProcessing[Room] = nil
      return
    end

    if Door:GetAttribute("Opened") == true then
      ForgetMeNotProcessing[Room] = nil
      return
    end

    if not Room:FindFirstChild(localPlayer.Name, true) then
      if not ForgetMeNotNotified[Room] then
        ForgetMeNotNotified[Room] = true
        library:Notify({ Title = "Archives", Description = "Please Enter The First ForgetMeNot Door", Time = 5 })
      end

      repeat
        task.wait()
      until Room:FindFirstChild(localPlayer.Name, true)
        or not ForgetMeNotRunning
        or not Room.Parent

      if not ForgetMeNotRunning or not Room.Parent then
        ForgetMeNotProcessing[Room] = nil
        return
      end
    end

    if not ForgetMeNotRunning or Door:GetAttribute("Opened") == true then
      ForgetMeNotProcessing[Room] = nil
      return
    end

    local Hidden = Door:WaitForChild("Hidden", 10)
    if not Hidden or not ForgetMeNotRunning or Door:GetAttribute("Opened") == true then
      ForgetMeNotProcessing[Room] = nil
      return
    end

    task.wait(3)

    if not ForgetMeNotRunning or not NextRoom.Parent or Door:GetAttribute("Opened") == true then
      ForgetMeNotProcessing[Room] = nil
      return
    end

    while ForgetMeNotRunning and NextRoom.Parent and Door:GetAttribute("Opened") ~= true do
      local Character = GetCharacter()
      if Character then
        if Hidden:IsA("BasePart") then
          Character:PivotTo(Hidden.CFrame)
        elseif Hidden:IsA("Model") then
          Character:PivotTo(Hidden:GetPivot())
        end
      end

      local clientOpen = Door:FindFirstChild("ClientOpen")
      if clientOpen then
        pcall(function() clientOpen:Fire() end)
        pcall(function() clientOpen:FireServer() end)
      end

      task.wait()
    end

    if ForgetMeNotRunning and Door:GetAttribute("Opened") == true then
      local Character = GetCharacter()
      if Character then
        Character:PivotTo(CFrame.new(0, -120, 0))
        Character:PivotTo(CFrame.new(0, -120, 0))
        Character:PivotTo(CFrame.new(0, -120, 0))
        Character:PivotTo(CFrame.new(0, -120, 0))
        library:Notify({ Title = "Archives", Description = "Spam Void In Debug If Stuck In ForgetMeNot", Time = 5 })
      end
      ForgetMeNotNotified[Room] = nil
    end

    ForgetMeNotProcessing[Room] = nil
  end

  local function CheckRooms()
    local latestRoomVal = replicatedStorage:FindFirstChild("GameData") and replicatedStorage.GameData:FindFirstChild("LatestRoom")
    local LatestRoomNumber = latestRoomVal and tonumber(latestRoomVal.Value) or tonumber(localPlayer:GetAttribute("CurrentRoom")) or 0
    local FirstRoomNumber = math.max(0, LatestRoomNumber - 4)
    for RoomNumber = FirstRoomNumber, LatestRoomNumber do
      if not ForgetMeNotRunning then
        return
      end

      local Room = workspace.CurrentRooms:FindFirstChild(tostring(RoomNumber))
      if Room and not ForgetMeNotProcessing[Room] then
        task.spawn(Run, Room)
      end
    end
  end

  local currentRooms = workspace:FindFirstChild("CurrentRooms")
  if currentRooms then
    ForgetMeNotConnection = currentRooms.ChildAdded:Connect(function(Room)
      if not tonumber(Room.Name) then
        return
      end

      task.spawn(function()
        task.wait(2)
        if ForgetMeNotRunning and Room.Parent then
          task.spawn(Run, Room)
        end
      end)
    end)
    table.insert(Connections, ForgetMeNotConnection)
  end

  task.spawn(function()
    while ForgetMeNotRunning do
      CheckRooms()
      task.wait(2)
    end
  end)
end


local HonchoCorrectBoxConnection = nil
local HonchoESPObjects = {}
local HonchoProcessedRooms = {}

function Handlers.HonchoCorrectBoxESPChanged(Value)
  if HonchoCorrectBoxConnection then
    HonchoCorrectBoxConnection:Disconnect()
    HonchoCorrectBoxConnection = nil
  end

  for _, Object in pairs(HonchoESPObjects) do
    if Object and Object.Parent then
      Functions.RemoveESP(Object)
    end
  end
  table.clear(HonchoESPObjects)
  table.clear(HonchoProcessedRooms)

  if not Value then return end

  local function ProcessHonchoRoom(Room)
    if not tonumber(Room.Name) then return end
    if HonchoProcessedRooms[Room] then return end
    HonchoProcessedRooms[Room] = true

    task.wait(3)

    if not (toggles.HonchoCorrectBoxESP and toggles.HonchoCorrectBoxESP.Value) or not Room.Parent then
      HonchoProcessedRooms[Room] = nil
      return
    end

    local HonchoRoom = Room:FindFirstChild("ArchivesHonchoRoom", true)
    if not HonchoRoom then
      HonchoProcessedRooms[Room] = nil
      return
    end

    local BoxIDs = {}
    for _, Desc in ipairs(Room:GetDescendants()) do
      if Desc.Name == "ArchivesPackageDeposit" then
        local BoxID = Desc:GetAttribute("BoxID")
        if BoxID ~= nil then
          BoxIDs[BoxID] = true
        end
      end
    end

    if next(BoxIDs) == nil then
      HonchoProcessedRooms[Room] = nil
      return
    end

    local RoomNumber = tonumber(Room.Name)
    for _, Child in ipairs(HonchoRoom:GetDescendants()) do
      if Child.Name == "ArchivesStorageBox" then
        local ToolBoxID = Child:GetAttribute("Tool_BoxID")
        if ToolBoxID ~= nil and BoxIDs[ToolBoxID] then
          if toggles.HonchoCorrectBoxESP.Value then
            if not Child:GetAttribute("ParentRoom") then
              Child:SetAttribute("ParentRoom", RoomNumber)
            end

            local Color = (options.ObjectiveESPColor and options.ObjectiveESPColor.Value) or Color3.fromRGB(0, 255, 0)
            Functions.AddESP({
              Object = Child,
              Text = "Correct Box",
              Color = Color
            }, true)

            table.insert(HonchoESPObjects, Child)

            Child.Destroying:Once(function()
              Functions.RemoveESP(Child)
              local pos = table.find(HonchoESPObjects, Child)
              if pos then
                table.remove(HonchoESPObjects, pos)
              end
            end)
          end
        end
      end
    end
  end

  local currentRooms = workspace:FindFirstChild("CurrentRooms")
  if currentRooms then
    for _, Room in ipairs(currentRooms:GetChildren()) do
      task.spawn(ProcessHonchoRoom, Room)
    end

    HonchoCorrectBoxConnection = currentRooms.ChildAdded:Connect(function(Room)
      task.spawn(ProcessHonchoRoom, Room)
    end)
    table.insert(Connections, HonchoCorrectBoxConnection)
  end
end


local AntiRansom_Connection = nil
function Handlers.AntiRansomChanged(Value)
  if AntiRansom_Connection then
    AntiRansom_Connection:Disconnect()
    AntiRansom_Connection = nil
  end

  if not Value then return end

  for _, child in ipairs(workspace:GetChildren()) do
    if child.Name == "Ransom" then
      pcall(function() child:Destroy() end)
    end
  end

  AntiRansom_Connection = workspace.ChildAdded:Connect(function(Child)
    if Child.Name == "Ransom" and toggles.AntiRansom and toggles.AntiRansom.Value then
      pcall(function() Child:Destroy() end)
    end
  end)
  table.insert(Connections, AntiRansom_Connection)
end


local AntiScribbles_Connection = nil
function Handlers.AntiScribblesChanged(Value)
  if AntiScribbles_Connection then
    AntiScribbles_Connection:Disconnect()
    AntiScribbles_Connection = nil
  end

  if not Value then return end

  for _, child in ipairs(workspace:GetChildren()) do
    if child.Name == "Scribbles" then
      local warning = child:FindFirstChild("IfYoureExploitingDeleteThis")
      if warning then
        pcall(function() warning:Destroy() end)
      end
    end
  end

  AntiScribbles_Connection = workspace.ChildAdded:Connect(function(Child)
    if Child.Name == "Scribbles" and toggles.AntiScribbles and toggles.AntiScribbles.Value then
      local warning = Child:FindFirstChild("IfYoureExploitingDeleteThis")
      if warning then
        pcall(function() warning:Destroy() end)
      end
    end
  end)
  table.insert(Connections, AntiScribbles_Connection)
end


function Handlers.StartBypass()
  if not toggles.ArchiveChairFly.Value then
    toggles.ArchiveChairFly:SetValue(true)
  else
    toggleChairBypass()
  end
end


function Handlers.ArchiveChairFlyChanged()
  if toggles.ArchiveChairFly.Value then
    toggleChairBypass()
  else
    releaseChair()
  end
end


-- ========================================================
-- Archives Addons (Right Groupbox)
-- ========================================================


-- 1. Archives Locker Autoloot
do
  local lockerRunning = false
  local lockerList = {}
  local lockerDelay = 0.8

  local function validLocker(obj)
    return obj:IsA("Model") and obj.Name:match("^HidingSpot%d+$") ~= nil
  end

  local function watchLocker(obj)
    if validLocker(obj) then
      lockerList[obj] = 0
    end
  end

  for _, obj in workspace:GetDescendants() do
    watchLocker(obj)
  end
  workspace.DescendantAdded:Connect(watchLocker)
  workspace.DescendantRemoving:Connect(function(obj)
    lockerList[obj] = nil
  end)

  local function tryLootLocker(obj, hrp, now)
    if not obj.Parent then
      lockerList[obj] = nil
      return
    end

    local prompt = obj:FindFirstChild("InteractPrompt", true)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    if prompt.ActionText ~= "Loot" or not prompt.Enabled then
      lockerList[obj] = 0
      return
    end

    local dist = (hrp.Position - obj:GetPivot().Position).Magnitude
    if dist > prompt.MaxActivationDistance then
      lockerList[obj] = 0
      return
    end

    if now - (lockerList[obj] or 0) < lockerDelay then return end

    lockerList[obj] = now
    if fireproximityprompt then
      fireproximityprompt(prompt)
    end
  end

  local function updateLockers()
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local now = os.clock()
    for obj in pairs(lockerList) do
      tryLootLocker(obj, hrp, now)
    end
  end

  

    function Handlers.ArchivesLockerChanged(val)
    if val then
      if lockerRunning then return end
      lockerRunning = true
      task.spawn(function()
        while lockerRunning and toggles.ArchivesLocker.Value do
          updateLockers()
          task.wait(0.05)
        end
        lockerRunning = false
      end)
    else
      lockerRunning = false
      for obj in pairs(lockerList) do
        lockerList[obj] = 0
      end
    end
  end


  
  -- menu of this block: built later, from the MENU section at the end of the file
  Menus.ArchivesLocker = function()
    Groupboxes.ArchivesAddons:AddToggle("ArchivesLocker", {
      Text = "Archives Locker Autoloot",
      Tooltip = "Automatically loots nearby Archives lockers.",
      Default = false,
    })

    toggles.ArchivesLocker:OnChanged(Handlers.ArchivesLockerChanged)

    Groupboxes.ArchivesAddons:AddSlider("ArchivesLockerCooldown", {
      Text = "Loot Attempt Cooldown",
      Tooltip = "Delay between loot attempts.",
      Min = 0.01,
      Max = 5,
      Default = 0.8,
      Rounding = 2,
      Callback = function(value)
        lockerDelay = value
      end,
    })
  end

end

-- 2. Archives Water Cooler
do
  local coolerCooldown = 0.5
  local coolerStepDelay = 0.15
  local coolerCupTimeout = 1
  local coolerDrinkTimeout = 5
  local coolerBusy = false

  local function promptOf(parent)
    local p = parent and parent:FindFirstChild("InteractPrompt", true)
    if p and p:IsA("ProximityPrompt") then return p end
  end

  local function promptPos(p)
    local x = p and p.Parent
    if not x then return end
    if x:IsA("Attachment") then return x.WorldPosition
    elseif x:IsA("BasePart") then return x.Position
    elseif x:IsA("Model") then return x:GetPivot().Position end
    local part = p:FindFirstAncestorWhichIsA("BasePart")
    return part and part.Position
  end

  local function nearbyPrompt(p)
    local char = localPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local pos = promptPos(p)
    return p and p.Parent and p.Enabled and hrp and pos and (hrp.Position - pos).Magnitude <= p.MaxActivationDistance
  end

  local function findCoolers()
    local result = {}
    for _, obj in workspace:GetDescendants() do
      if obj.Name == "ArchivesWaterCooler" then
        local cups = obj:FindFirstChild("Cups", true)
        local cold = obj:FindFirstChild("Cold", true)
        local hot = obj:FindFirstChild("Hot", true)
        local cp = promptOf(cups)
        local fp = promptOf(cold)
        local hp = promptOf(hot)
        if cp and fp and hp and nearbyPrompt(cp) then
          table.insert(result, {
            model = obj,
            cups = cp,
            cold = fp,
            hot = hp,
          })
        end
      end
    end
    return result
  end

  local function getWaterCup()
    local char = localPlayer.Character
    local cup = char and char:FindFirstChild("WaterCup")
    if cup and cup:IsA("Tool") then return cup end
    local bag = localPlayer:FindFirstChildOfClass("Backpack")
    local stored = bag and bag:FindFirstChild("WaterCup")
    if stored and stored:IsA("Tool") then
      local hum = char and char:FindFirstChildOfClass("Humanoid")
      if hum then hum:EquipTool(stored) end
      return stored
    end
  end

  local function waitWaterCup()
    local t = os.clock()
    repeat
      local cup = getWaterCup()
      if cup then return cup end
      task.wait(0.05)
    until os.clock() - t >= coolerCupTimeout
  end

  local function usePrompt(p)
    if not nearbyPrompt(p) then return false end
    if fireproximityprompt then
      fireproximityprompt(p)
    end
    return true
  end

  local function cupGone(cup)
    local t = os.clock()
    while cup.Parent and os.clock() - t < coolerDrinkTimeout do
      task.wait(0.05)
    end
    return cup.Parent == nil
  end

  local function drinkCooler(cooler)
    if not usePrompt(cooler.cups) then return false end
    local cup = waitWaterCup()
    if not cup then return false end

    task.wait(coolerStepDelay)
    cup = getWaterCup()
    if not cup or not usePrompt(cooler.cold) then return false end

    task.wait(coolerStepDelay)
    cup = getWaterCup()
    if not cup or not usePrompt(cooler.hot) then return false end

    task.wait(coolerStepDelay)
    cup = getWaterCup()
    local remote = cup and cup:FindFirstChild("Remote")
    if not remote or not remote:IsA("RemoteEvent") then return false end
    remote:FireServer()

    return cupGone(cup)
  end

    function Handlers.DrinkFromWaterCooler()
    if coolerBusy then return end
    coolerBusy = true
    task.spawn(function()
      while true do
        local list = findCoolers()
        if #list == 0 then break end
        local ok = false
        for _, cooler in ipairs(list) do
          if drinkCooler(cooler) then
            ok = true
            break
          end
        end
        if not ok then break end
        task.wait(coolerCooldown)
      end
      coolerBusy = false
    end)
  end


  
  -- menu of this block: built later, from the MENU section at the end of the file
  Menus.ArchivesWaterCooler = function()
    Groupboxes.ArchivesAddons:AddButton({
      Text = "Drink From Water Cooler",
      Tooltip = "Automatically takes cup, fills cold & hot water, and drinks it.",
      Callback = Handlers.DrinkFromWaterCooler,
    })

    Groupboxes.ArchivesAddons:AddSlider("ArchivesWaterCoolerCooldown", {
      Text = "Water Cooler Cooldown",
      Tooltip = "Delay between drinks.",
      Min = 0.01,
      Max = 5,
      Default = 0.5,
      Rounding = 2,
      Callback = function(v)
        coolerCooldown = v
      end,
    })
  end

end


function Handlers.StartBypass2()
  if not toggles.StairwellChairFly.Value then
    toggles.StairwellChairFly:SetValue(true)
  else
    toggleChairBypass()
  end
end


function Handlers.StairwellChairFlyChanged()
  if toggles.StairwellChairFly.Value then
    toggleChairBypass()
  else
    releaseChair()
  end
end


local function BringDroppedItems()
  local workspaceDropsFolder = workspace:FindFirstChild("Drops")
  local character = localPlayer.Character
  local playerHumanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
  if playerHumanoidRootPart and workspaceDropsFolder then
    for _, itemToBring in ipairs(workspaceDropsFolder:GetChildren()) do
      if itemToBring:IsA("Model") then
        pcall(function() itemToBring:PivotTo(playerHumanoidRootPart.CFrame) end)
      elseif itemToBring:IsA("BasePart") then
        pcall(function() itemToBring.CFrame = playerHumanoidRootPart.CFrame end)
      end
    end
  end
end


local droppedItemsIntervalRunning = false
function Handlers.EnableDroppedItemsIntervalChanged(enabled)
  if enabled then
    if droppedItemsIntervalRunning then return end
    droppedItemsIntervalRunning = true
    task.spawn(function()
      while toggles.EnableDroppedItemsInterval and toggles.EnableDroppedItemsInterval.Value do
        BringDroppedItems()
        local interval = (options.DroppedItemsInterval and options.DroppedItemsInterval.Value) or 1
        if interval <= 0 then
          task.wait()
        else
          task.wait(interval)
        end
      end
      droppedItemsIntervalRunning = false
    end)
  end
end


local antiNoiseConn = nil
function Handlers.AntiNoiseChanged(value)
  if antiNoiseConn then
    antiNoiseConn:Disconnect()
    antiNoiseConn = nil
  end

  if not value then return end

  antiNoiseConn = runService.PreSimulation:Connect(function(dt)
    if not (toggles.AntiNoise and toggles.AntiNoise.Value) then return end
    if not localPlayer:GetAttribute("Alive") then return end

    local character = localPlayer.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local camera = workspace.CurrentCamera

    if not rootPart or not humanoid or not camera then return end
    if humanoid.Health <= 0 then return end
    if rootPart.Anchored then return end

    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Dead
      or state == Enum.HumanoidStateType.Ragdoll
      or state == Enum.HumanoidStateType.Climbing
      or state == Enum.HumanoidStateType.Swimming
    then
      return
    end

    humanoid.AutoRotate = false
    humanoid:Move(Vector3.zero, false)

    local controls = nil
    pcall(function()
      controls = require(localPlayer.PlayerScripts.PlayerModule):GetControls()
    end)
    local inputVector = controls and controls:GetMoveVector() or Vector3.zero
    local inputMagnitude = inputVector.Magnitude

    if inputMagnitude <= 0 then
      rootPart.AssemblyLinearVelocity = Vector3.zero
      return
    end

    local cameraCFrame = camera.CFrame
    local cameraForward = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)
    local cameraRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)

    if cameraForward.Magnitude < 0.001 or cameraRight.Magnitude < 0.001 then return end

    cameraForward = cameraForward.Unit
    cameraRight = cameraRight.Unit

    local worldDirection = (cameraRight * inputVector.X) + (cameraForward * -inputVector.Z)
    if worldDirection.Magnitude <= 0 then return end
    worldDirection = worldDirection.Unit

    local finalSpeed = humanoid.WalkSpeed * math.clamp(inputMagnitude, 0, 1)
    local clampedDt = math.clamp(dt, 0, 1/30)

    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.CFrame = rootPart.CFrame + (worldDirection * finalSpeed * clampedDt)
    rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + worldDirection)
  end)
  table.insert(Connections, antiNoiseConn)
end


local bypassNoiseMiscChildAddedConnection = nil
function Handlers.BypassNoiseChanged(value)
  if bypassNoiseMiscChildAddedConnection then
    bypassNoiseMiscChildAddedConnection:Disconnect()
    bypassNoiseMiscChildAddedConnection = nil
  end

  if not value then return end

  local bypassNoiseLocalPlayerUserId = localPlayer and localPlayer.UserId
  local function checkBypassNoiseTvStand(targetTvStand)
    if not targetTvStand:IsA("Model") then return end
    if targetTvStand.Name ~= "TV_Stand" then return end
    if targetTvStand:GetAttribute("LastPusherId") ~= bypassNoiseLocalPlayerUserId then return end
    local tvStandCurrentCFrame = targetTvStand:GetPivot()
    if tvStandCurrentCFrame.Position.Y > -119 then
      targetTvStand:PivotTo(CFrame.new(tvStandCurrentCFrame.Position.X, -120, tvStandCurrentCFrame.Position.Z))
      library:Notify({ Title = "Stairwell", Description = "Unequip the tv.", Time = 5 })
    end
  end

  local function checkBypassNoiseAllTvStands()
    local bypassNoiseMiscFolder = workspace:FindFirstChild("Misc")
    if not bypassNoiseMiscFolder then return end
    for _, bypassNoiseMiscChild in ipairs(bypassNoiseMiscFolder:GetChildren()) do
      checkBypassNoiseTvStand(bypassNoiseMiscChild)
    end
  end

  local bypassNoiseMiscFolder = workspace:FindFirstChild("Misc")
  if bypassNoiseMiscFolder then
    bypassNoiseMiscChildAddedConnection = bypassNoiseMiscFolder.ChildAdded:Connect(function(bypassNoiseNewChild)
      task.wait(0.1)
      checkBypassNoiseTvStand(bypassNoiseNewChild)
    end)
    table.insert(Connections, bypassNoiseMiscChildAddedConnection)
  end

  task.spawn(function()
    while toggles.BypassNoise and toggles.BypassNoise.Value do
      checkBypassNoiseAllTvStands()
      task.wait(1)
    end
  end)
end


function Handlers.NoSurgeDamageChanged(value)
  if not remotesFolder then
    return
  end

  if value then
    if FakeEvents.Surge_Real and FakeEvents.Surge_Real.Parent then
      FakeEvents.Surge.Parent = remotesFolder
      FakeEvents.Surge_Real.Parent = nil
    end
  elseif FakeEvents.Surge_Real then
    FakeEvents.Surge_Real.Parent = remotesFolder
    FakeEvents.Surge.Parent = nil
  end
end


function Handlers.RemoveSurgeChanged(value)
  if featureState.SurgeFrame then
    featureState.SurgeFrame.Name = value and "SurgeVignette_Disabled" or "SurgeVignette"
  end
end


function Handlers.RemoveMandrakeChanged(value)
  for _, entity in worldObjects.Entities do
    if entity.Name == "Root" and entity:IsA("BasePart") then
      local antiMandrakeForce = entity:FindFirstChild("AntiMandrakeForce")

      if value then
        if not antiMandrakeForce then
          antiMandrakeForce = Instance.new("BodyForce")
          antiMandrakeForce.Name = "AntiMandrakeForce"
          antiMandrakeForce.Parent = entity
        end

        antiMandrakeForce.Force = Vector3.new(100000, -99999999, 100000)
      elseif antiMandrakeForce then
        antiMandrakeForce:Destroy()
      end
    end
  end
end


local setPathTransparency


local setPathColor


featureState.RoomsNodesFolder = Instance.new("Folder")
featureState.RoomsNodesFolder.Name = "RoomsPathNodes"
featureState.RoomsNodesFolder.Parent = workspace
featureState.SeekNodesFolder = Instance.new("Folder")
featureState.SeekNodesFolder.Name = "SeekPathNodes"
featureState.SeekNodesFolder.Parent = workspace

function Handlers.BypassKillbricksChanged(value)
  for _, descendant in workspace:GetDescendants() do
    if descendant.Name == "Lava" and descendant:IsA("BasePart") then
      descendant.CanTouch = not value
    end
  end
end


function Handlers.BypassSeekingWallChanged(value)
  for _, descendant in workspace:GetDescendants() do
    if descendant.Name == "ScaryWall" then
      for _, descendant2 in descendant:GetDescendants() do
        if descendant2:IsA("BasePart") then
          descendant2.CanTouch = not value
          descendant2.CanCollide = not value
        end
      end
    end
  end
end


function Handlers.BypassBananaChanged(value)
  for _, descendant in workspace:GetDescendants() do
    if descendant.Name == "BananaPeel" and descendant:IsA("BasePart") then
      descendant.CanTouch = not value
    end
  end
end


function Handlers.BypassJeffChanged(value)
  for _, descendant in workspace:GetDescendants() do
    if descendant.Name == "JeffTheKiller" then
      for _, descendant2 in descendant:GetDescendants() do
        if descendant2:IsA("BasePart") then
          descendant2.CanCollide = not value
          descendant2.CanTouch = not value
        end
      end

      local humanoid2 = descendant:FindFirstChildOfClass("Humanoid")

      if humanoid2 then
        humanoid2.Health = 0
      end
    end
  end
end


function Handlers.RemoveSeekTriggerChanged(value)
  if value and Executor.firetouchinterest then
    for _, entity in ipairs(worldObjects.Entities) do
      if entity.Name == "TriggerEventCollision" then
        for _, child in entity:GetChildren() do
          if child:IsA("BasePart") and humanoidRootPart then
            Executor.firetouchinterest(humanoidRootPart, child, 0)
            task.wait()
            Executor.firetouchinterest(humanoidRootPart, child, 1)
          end
        end
      end
    end

    task.spawn(function()
      while toggles.RemoveSeekTrigger.Value do
        for _, entity in ipairs(worldObjects.Entities) do
          if entity.Name == "TriggerEventCollision" and humanoidRootPart then
            for _, child in entity:GetChildren() do
              if child:IsA("BasePart") then
                Executor.firetouchinterest(humanoidRootPart, child, 0)
                task.wait()
                Executor.firetouchinterest(humanoidRootPart, child, 1)
              end
            end
          end
        end

        task.wait(0.5)
      end
    end)
  end

  for _, descendant in workspace:GetDescendants() do
    if descendant.Name == "Seeking" or descendant.Name == "SeekTrigger" or descendant.Name == "ChaseStartTrigger" then
      for _, descendant2 in descendant:GetDescendants() do
        if descendant2:IsA("BasePart") then
          descendant2.CanTouch = not value
        end
      end
    end
  end
end


function Handlers.AutoRoomSkipChanged(value)
  if value then
    task.spawn(function()
      pcall(function()
        local timer = 0
        local counter = 0
        local finished = false

        repeat
          local bestRoom = nil
          local bestNumber = 0

          for _, child in workspace.CurrentRooms:GetChildren() do
            local number = tonumber(child.Name)

            if number and number > bestNumber then
              local door = child:FindFirstChild("Door")

              if door then
                bestRoom = door
                bestNumber = number
              end
            end
          end

          if bestRoom then
            if bestNumber > timer then
              timer = bestNumber
              counter = 0

              if finished then
                toggles.Noclip:SetValue(false)
                finished = false
              end
            end

            local basePart = bestRoom:IsA("BasePart") and bestRoom
              or bestRoom:FindFirstChildWhichIsA("BasePart")

            if basePart then
              game.Players.LocalPlayer.Character:PivotTo(CFrame.new(basePart.Position))
            end
          else
            counter = counter + 0.25

            if counter >= 5 then
              if not toggles.Noclip.Value then
                toggles.Noclip:SetValue(true)
              end

              finished = true
              local character2 = game.Players.LocalPlayer.Character

              if character2 and character2:FindFirstChild("HumanoidRootPart") then
                character2.HumanoidRootPart.CFrame = character2.HumanoidRootPart.CFrame
                  * CFrame.new(0, 0, 10)
              end

              counter = 0
            end
          end

          task.wait(0.25)
        until not toggles.AutoRoomSkip.Value

        if finished then
          toggles.Noclip:SetValue(false)
        end
      end)
    end)
  end
end


function Handlers.RemoveFigureChanged(value)
  if value and Executor.isnetworkowner and workspace:FindFirstChild("Figure") then
    local floorName = detectFloor()

    for _, entity in ipairs(worldObjects.Entities) do
      if entity.Name == "Figure" or entity.Name == "FigureRig"
        or entity.Name == "FigureRagdoll" then
        if floorName == "Mines" then
          for _, descendant in entity:GetDescendants() do
            local part = descendant

            if descendant:IsA("BasePart")
              and pcall(function() return Executor.isnetworkowner(part) end) then
              part.Position = Vector3.new(-49999, -49999, -49999)
            end
          end
        elseif floorName == "OldHotel" or floorName == "Fools" then
          for _, descendant in entity:GetDescendants() do
            local part = descendant

            if descendant:IsA("BasePart") then
              descendant.CanCollide = false

              if pcall(function() return Executor.isnetworkowner(part) end) then
                part.Position = Vector3.new(
                  math.random(-29999, 29999), math.random(-29999, 29999), math.random(-29999, 29999)
                )
              end
            end
          end
        end
      end
    end
  end

  if value then
    local figure = workspace:FindFirstChild("Figure")

    if figure then
      for _, descendant in figure:GetDescendants() do
        if descendant:IsA("BasePart") then
          descendant.CanCollide = false
        end
      end
    end
  end
end


Connections.AutoReviveHandler = localPlayer:GetAttributeChangedSignal("Alive"):Connect(function()
  if localPlayer:GetAttribute("Alive") == false and toggles.AutoRevive.Value then
    local floorName = detectFloor()

    if floorName == "Fools" or floorName == "OldHotel" then
      while localPlayer:GetAttribute("Alive") ~= true do
        local remotesFolder2 = replicatedStorage:FindFirstChild("RemotesFolder")

        if remotesFolder2 and remotesFolder2:FindFirstChild("Revive") then
          remotesFolder2.Revive:FireServer()
        end

        task.wait(0.5)
      end
    end
  end
end)


ObstructionNames = {
  ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor", }


Connections.DescendantAddedObstructions = workspace.DescendantAdded:Connect(function(descendant)
  if descendant:IsA("Model")
    and (descendant.Name == "ThingToOpen" or descendant.Name == "MovingDoor"
      or descendant.Name == "Wax_Door") then
    local removalToggles = {
      ThingToOpen = "RemoveBasementGate", MovingDoor = "RemovePaintingsDoor", Wax_Door = "RemoveSkeletonDoor", }

    local success, result = pcall(function()
      return httpService:JSONEncode({ descendant:GetPivot():GetComponents() })
    end)

    if success and result then
      descendant:SetAttribute("OriginalPosition", result)
    end

    if toggles[removalToggles[descendant.Name]] and toggles[removalToggles[descendant.Name]].Value then
      descendant:PivotTo(CFrame.new(-10000, -10000, -10000))
    end
  end
end)

function Handlers.RoomsAutoWalkShowPathToggleChanged(value)
  for _, child in featureState.RoomsNodesFolder:GetChildren() do
    if child.Name == "PathNode" then
      child.Transparency = value and 0.5 or 1
    end
  end
end


function Handlers.RoomsAutoWalkShowPathColorChanged(color)
  for _, child in featureState.RoomsNodesFolder:GetChildren() do
    if child.Name == "PathNode" then
      child.Color = color
    end
  end
end


RoomsEntityList = {
  "RushMoving", "AmbushMoving", "BackdoorRush", "A60", "A120", "CustomEntity", "GlitchRush", "GlitchAmbush", }

Functions.RoomsAutoWalk = {}

function Functions.RoomsAutoWalk.GetNearestHidingSpot()
  local nearest = { Distance = math.huge, Object = nil }

  for _, hidingSpot in ipairs(worldObjects.HidingSpots) do
    if hidingSpot.PrimaryPart and hidingSpot:FindFirstChild("HidePrompt") then
      local distanceFromCharacter = localPlayer:DistanceFromCharacter(hidingSpot.PrimaryPart.Position)

      if distanceFromCharacter < nearest.Distance and hidingSpot.PrimaryPart.Position.Y > -10 then
        local findFirstChild = hidingSpot:FindFirstChild("HiddenPlayer", true)

        if findFirstChild and not findFirstChild.Value then
          nearest.Distance = distanceFromCharacter
          nearest.Object = hidingSpot
        end
      end
    end
  end

  return nearest.Object
end

local waypointIndex = 0
local pathTarget = nil

function Functions.RoomsAutoWalk.GetPathfindTarget()
  if not latestRoomValue or not currentRooms then
    return
  end

  local text = currentRooms[tostring(latestRoomValue.Value)]

  if not text then
    return
  end

  for _, child in workspace:GetChildren() do
    if TableFind(RoomsEntityList, child.Name) and child.PrimaryPart then
      local y = child.PrimaryPart.Position.Y

      if y > -10 and y < 150 then
        if child.Name == "A60" and not toggles.RoomsAutoWalkIgnoreA60.Value or child.Name ~= "A60" then
          return Functions.RoomsAutoWalk.GetNearestHidingSpot()
            or text:FindFirstChild("RoomExit")
        end
      end
    end
  end

  if toggles.RoomsAutoWalkIgnoreA60.Value and Functions.GetNearestEntity() then
    return text:FindFirstChild("RoomExit")
  end

  if (toggles.RoomsPickupStardust.Value or toggles.RoomsPickupGold.Value)
    and pathTarget ~= latestRoomValue.Value then
    local nearest = { Distance = math.huge, Object = nil }

    for _, descendant in text:GetDescendants() do
      if descendant.Name == "GoldPile" and descendant:GetAttribute("GoldValue")
        and toggles.RoomsPickupGold.Value then
        local distanceFromCharacter = localPlayer:DistanceFromCharacter(descendant:GetPivot().Position)

        if distanceFromCharacter < nearest.Distance then
          nearest.Distance = distanceFromCharacter
          nearest.Object = descendant
        end
      elseif descendant.Name == "StardustPickup" and toggles.RoomsPickupStardust.Value then
        local distanceFromCharacter = localPlayer:DistanceFromCharacter(descendant:GetPivot().Position)

        if distanceFromCharacter < nearest.Distance then
          nearest.Distance = distanceFromCharacter
          nearest.Object = descendant
        end
      end
    end

    if nearest.Object then
      return nearest.Object
    end
  end

  return text:FindFirstChild("RoomExit")
end

function Handlers.RoomsAutoWalkChanged(value)
  for _, child in featureState.RoomsNodesFolder:GetChildren() do
    if child.Name == "PathNode" then
      child:Destroy()
    end
  end

  if value and not toggles.NoA90Damage.Value then
    toggles.NoA90Damage:SetValue(true)
  end
end


Connections.RoomsAutoWalkHandler = runService.Heartbeat:Connect(function()
  if _Unloading then
    return
  end

  if not toggles.RoomsAutoWalk.Value or CurrentFloor ~= "Rooms" or featureState.RoomsAutoWalkActive
    or not collisionPart then
    return
  end

  local success, result = pcall(function() return latestRoomValue and latestRoomValue.Value end)

  if not success or not result or result >= 1000 then
    return
  end

  featureState.RoomsAutoWalkActive = true

  local path = pathfindingService:CreatePath({
    AgentCanJump = true, AgentCanClimb = false, WaypointSpacing = 4, AgentRadius = 1.5, AgentHeight = 1.5, Costs = { StuckPart = 8 }, })

  if toggles.RoomsAutoWalkIgnoreA60.Value and not toggles.Godmode.Value then
    toggles.Godmode:SetValue(true)
  end

  local target = Functions.RoomsAutoWalk.GetPathfindTarget()

  if not target then
    featureState.RoomsAutoWalkActive = false
    return
  end

  local position

  if target.Name == "RoomExit" then
    position = target.Position
  elseif target:FindFirstChild("HidePrompt") then
    for _, descendant in target:GetDescendants() do
      if descendant:IsA("BasePart") then
        descendant.CanCollide = false
      end
    end

    position = target.PrimaryPart.Position
  elseif target.Name == "GoldPile" or target.Name == "StardustPickup" then
    position = target:GetPivot().Position

    if waypointIndex == 0 then
      waypointIndex = tick()
    end
  end

  if target.Name ~= "GoldPile" and target.Name ~= "StardustPickup" then
    waypointIndex = 0
  end

  if collisionPart.Anchored and not target:FindFirstChild("HidePrompt") then
    character:SetAttribute("Hiding", true)
    remotesFolder.CamLock:FireServer()
    character:SetAttribute("Hiding", false)
  end

  if not latestRoomValue or not currentRooms then
    featureState.RoomsAutoWalkActive = false
    return
  end

  local text = currentRooms[tostring(latestRoomValue.Value)]

  if not text then
    featureState.RoomsAutoWalkActive = false
    return
  end

  if text:FindFirstChild("Door") then
    text.Door.Door.CanCollide = false
  end

  if not position or localPlayer:DistanceFromCharacter(position) >= 750 then
    featureState.RoomsAutoWalkActive = false
    return
  end

  local success2, result3 = pcall(path.ComputeAsync, path, collisionPart.Position, position)

  if result3 then
    featureState.RoomsAutoWalkActive = false
    return
  end

  local getWaypoints = path:GetWaypoints()

  if #getWaypoints == 0 then
    local roomExit = text:FindFirstChild("RoomExit")

    if roomExit then
      humanoid:MoveTo(roomExit.Position)
    end

    featureState.RoomsAutoWalkActive = false
    return
  end

  for _, child in featureState.RoomsNodesFolder:GetChildren() do
    if child.Name == "PathNode" then
      child:Destroy()
    end
  end

  for _, getWaypoint in ipairs(getWaypoints) do
    local pathNode = Instance.new("Part", featureState.RoomsNodesFolder)
    pathNode.Transparency = toggles.RoomsAutoWalkShowPathToggle.Value and 0.5 or 1
    pathNode.Size = Vector3.one
    pathNode.Position = getWaypoint.Position
    pathNode.Shape = Enum.PartType.Ball
    pathNode.CanCollide = false
    pathNode.Anchored = true
    pathNode.Name = "PathNode"
    pathNode.Color = options.RoomsAutoWalkShowPathColor.Value
    pathNode.Material = Enum.Material.Neon
  end

  local reached = false

  for _, getWaypoint in ipairs(getWaypoints) do
    if reached or not toggles.RoomsAutoWalk.Value then
      break
    end

    local arrived = false
    local startTime = tick()
    local waypoint = getWaypoint

    local connection = runService.RenderStepped:Connect(function()
      if _Unloading then
        return
      end

      if reached or not toggles.RoomsAutoWalk.Value then
        arrived = true
        return
      end

      local nextTarget = Functions.RoomsAutoWalk.GetPathfindTarget()

      if nextTarget and nextTarget:FindFirstChild("HidePrompt") and not target:FindFirstChild("HidePrompt") then
        arrived = true
        return
      end

      if target.Name == "GoldPile" and (not target.Parent or not target:GetAttribute("GoldValue"))
        or target.Name == "StardustPickup" and not target.Parent then
        arrived = true
        return
      end

      if target:FindFirstChild("HidePrompt") then
        local hidePrompt = target:FindFirstChild("HidePrompt")

        if localPlayer:DistanceFromCharacter(position) < hidePrompt.MaxActivationDistance
          and character:GetAttribute("Hiding") ~= true then
          Functions.ForceFirePrompt(hidePrompt)
        end
      elseif target.Name == "GoldPile" or target.Name == "StardustPickup" then
        local lootPrompt = target:FindFirstChild("LootPrompt")

        if lootPrompt
          and localPlayer:DistanceFromCharacter(position) < lootPrompt.MaxActivationDistance then
          Functions.ForceFirePrompt(lootPrompt)
        end
      end

      if localPlayer:DistanceFromCharacter((Vector3.new(
        waypoint.Position.X, humanoidRootPart.Position.Y, waypoint.Position.Z
      ))) < 5 then
        arrived = true
      end

      humanoid:MoveTo(waypoint.Position)
    end)

    while not arrived do
      if tick() - startTime > options.RoomsAutoWalkPathfindTimeout.Value then
        local stuckPart = Instance.new("Part", featureState.RoomsNodesFolder)
        stuckPart.Transparency = 1
        stuckPart.Size = Vector3.one
        stuckPart.CFrame = collision.CFrame
        stuckPart.Shape = Enum.PartType.Ball
        stuckPart.CanCollide = false
        stuckPart.Anchored = true
        stuckPart.Name = "StuckPart"

        local instance = Instance.new("PathfindingModifier", stuckPart)
        instance.Label = "StuckPart"

        reached = true
        break
      end

      if waypointIndex > 0 and tick() - waypointIndex > 5 then
        pathTarget = latestRoomValue.Value
        waypointIndex = 0
        reached = true
        break
      end

      task.wait()
    end

    connection:Disconnect()
    humanoid:MoveTo(humanoidRootPart.Position)
  end

  featureState.RoomsAutoWalkActive = false
end)

if currentRooms then
  Connections.RoomsHandler = currentRooms.ChildAdded:Connect(function(child)
    for _, child2 in featureState.RoomsNodesFolder:GetChildren() do
      if child2.Name == "StuckPart" then
        child2:Destroy()
      end
    end

    if child:GetAttribute("RawName")
      and string.find(child:GetAttribute("RawName"), "Eyestalk") then
      local previousPart

      local function createPart(position)
        local seekLightNode = Instance.new("Part")
        seekLightNode.Size = Vector3.one
        seekLightNode.Transparency = 1
        seekLightNode.Parent = featureState.SeekNodesFolder
        seekLightNode.Anchored = true
        seekLightNode.Position = position
        seekLightNode.CanCollide = false
        seekLightNode.Name = "SeekLightNode"

        local lastPart = previousPart or seekLightNode
        previousPart = seekLightNode
        local beam = Instance.new("Beam")

        local value = rawget(toggles, "ShowEyestalkPathColor")
            and options.ShowEyestalkPathColor.Value
          or Color3.fromRGB(0, 255, 0)

        beam.Color = ColorSequence.new({
          ColorSequenceKeypoint.new(0, value), ColorSequenceKeypoint.new(1, value), })

        beam.FaceCamera = true
        beam.Width0 = 0.2
        beam.Width1 = 0.2
        beam.Brightness = 10
        beam.LightInfluence = 0
        beam.LightEmission = 0
        beam.Enabled = true

        local pathToggle = rawget(toggles, "ShowEyestalkPathToggle")
            and toggles.ShowEyestalkPathToggle.Value and 0
          or 1

        beam.Transparency = NumberSequence.new({
          NumberSequenceKeypoint.new(0, pathToggle), NumberSequenceKeypoint.new(1, pathToggle), })

        beam.Parent = featureState.SeekNodesFolder

        local instance = Instance.new("Attachment", seekLightNode)
        local instance2 = Instance.new("Attachment", lastPart)

        beam.Attachment0 = instance
        beam.Attachment1 = instance2

        table.insert(worldObjects.EyestalkHighlights, beam)
      end

      child:WaitForChild("RoomEntrance", 9000000000)
      child:WaitForChild("RoomExit", 9000000000)

      while not child:GetAttribute("PathFound") do
        if rawget(toggles, "ShowEyestalkPathToggle") and toggles.ShowEyestalkPathToggle.Value then
          local path = pathfindingService:CreatePath({
            AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 2, AgentRadius = 1, AgentHeight = 1, })

          local success, result = pcall(
            path.ComputeAsync, path, humanoidRootPart.Position, child.RoomExit.Position
          )

          if result then
            break
          end

          if path.Status == Enum.PathStatus.Success then
            child:SetAttribute("PathFound", true)

            for _, waypoint in path:GetWaypoints() do
              createPart(waypoint.Position)
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

local function watchFloorValue()
  local gameData2 = replicatedStorage:FindFirstChild("GameData")

  if gameData2 then
    local floor = gameData2:FindFirstChild("Floor")

    if floor then
      _FloorConnection = floor:GetPropertyChangedSignal("Value"):Connect(updateFloor)
      updateFloor()
      return
    end

    local connection = gameData2.ChildAdded:Connect(function(child)
      if child.Name == "Floor" then
        if connect23 then
          connect23:Disconnect()
        end

        watchFloorValue()
      end
    end)

    updateFloor()
    return
  end

  local connection = replicatedStorage.ChildAdded:Connect(function(child)
    if child.Name == "GameData" then
      if connect24 then
        connect24:Disconnect()
      end

      watchFloorValue()
    end
  end)

  updateFloor()
end


function Handlers.LaddersTracersChanged(value)
  if value and not toggles.LaddersESP.Value then
    toggles.LaddersTracers:SetValue(false)
    return
  end

  for _, ladder in ipairs(ESPCategories.Ladders) do
    local target = GetESPTarget(ladder, "Ladders")

    if target then
      loader:SetTracersEnabled(target, value)
    end
  end
end


function Handlers.LaddersESPChanged(value)
  if value then
    for _, ladder in ipairs(ESPCategories.Ladders) do
      addCategoryESP(ladder, "Ladders", "Ladder")
    end
  else
    removeCategoryESP("Ladders")
  end
end


function Handlers.LaddersESPColorChanged(value)
  for _, ladder in ipairs(ESPCategories.Ladders) do
    loader:UpdateObjectColor(GetESPTarget(ladder, "Ladders"), value)
  end
end


function Handlers.DisableAnticheatChanged(value)
  if featureState.AnticheatDisabled == true and not value then
    remotesFolder.ClimbLadder:FireServer()
    featureState.AnticheatDisabled = false
  end
end


function Handlers.RemoveFigureMinesChanged(value)
  if value and Executor.isnetworkowner and workspace:FindFirstChild("Figure") then
    local floorName = detectFloor()

    for _, entity in ipairs(worldObjects.Entities) do
      if entity.Name == "Figure" or entity.Name == "FigureRig"
        or entity.Name == "FigureRagdoll" then
        if floorName == "Mines" then
          for _, descendant in entity:GetDescendants() do
            local part = descendant

            if descendant:IsA("BasePart")
              and pcall(function() return Executor.isnetworkowner(part) end) then
              part.Position = Vector3.new(-49999, -49999, -49999)
            end
          end
        elseif floorName == "OldHotel" or floorName == "Fools" then
          for _, descendant in entity:GetDescendants() do
            local part = descendant

            if descendant:IsA("BasePart") then
              descendant.CanCollide = false

              if pcall(function() return Executor.isnetworkowner(part) end) then
                part.Position = Vector3.new(
                  math.random(-29999, 29999), math.random(-29999, 29999), math.random(-29999, 29999)
                )
              end
            end
          end
        end
      end
    end
  end

  if value then
    local figure = workspace:FindFirstChild("Figure")

    if figure then
      for _, descendant in figure:GetDescendants() do
        if descendant:IsA("BasePart") then
          descendant.CanCollide = false
        end
      end
    end
  end
end


function setPathTransparency(beams, _, visible)
  local transparency = visible and 0 or 1

  local numberSequence = NumberSequence.new({
    NumberSequenceKeypoint.new(0, transparency), NumberSequenceKeypoint.new(1, transparency), })

  for _, beam in ipairs(beams) do
    beam.Transparency = numberSequence
  end
end

function setPathColor(beams, color)
  local colorSequence = ColorSequence.new({
    ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(1, color), })

  for _, beam in ipairs(beams) do
    beam.Color = colorSequence
  end
end


function Handlers.MinecartTeleportChanged(value)
  if not MainHook then
    return
  end

  if value then
    local findFirstChild = game:FindFirstChild("MinecartPos", true)

    if not findFirstChild then
      library:Notify({
        Title = "Minecart Teleport", Description = "Minecart chase is not active yet.", Time = 3, })

      return
    end

    local restorefunction = restorefunction or restore_function

    local minecartState = {
      DecodeHook = nil, Decode = nil, MinecartPos = findFirstChild, LatestRoom = tonumber(tostring(latestRoomValue.Value)) or 0, LatestRoomConn = nil, GetDoor = nil, RestoreDecode = restorefunction, }

    pcall(function() minecartState.Decode = require(replicatedStorage.NodeObject.MinecartNodes).Decode end)

    function minecartState.GetDoor()
      local findFirstChild2 = currentRooms
        and currentRooms:FindFirstChild(tostring(minecartState.LatestRoom))

      return findFirstChild2 and findFirstChild2:FindFirstChild("Door")
    end

    minecartState.LatestRoomConn = latestRoomValue:GetPropertyChangedSignal("Value"):Connect(function()
      task.wait()
      minecartState.LatestRoom = tonumber(tostring(latestRoomValue.Value)) or 0
    end)

    featureState.MinecartTeleportState = minecartState
  else
    local minecartTeleportState = featureState.MinecartTeleportState

    if minecartTeleportState then
      if minecartTeleportState.LatestRoomConn then
        pcall(function() minecartTeleportState.LatestRoomConn:Disconnect() end)
      end

      if minecartTeleportState.DecodeHook and minecartTeleportState.RestoreDecode then
        pcall(function() minecartTeleportState.RestoreDecode(minecartTeleportState.Decode) end)
      end

      featureState.MinecartTeleportState = nil
    end
  end
end


function Handlers.CompleteDoor200()
  if not character then
    library:Notify({ Title = "Error", Description = "Character not found", Time = 3 })
    return
  end

  library:Notify({
    Title = "Door 200", Description = "Starting water pump automation...", Time = 3, })

  local cutsceneActive = false

  local connection = remotesFolder and remotesFolder:FindFirstChild("Cutscene") and remotesFolder.Cutscene.OnClientEvent:Connect(function()
    cutsceneActive = true
    task.wait(7)
    cutsceneActive = false
  end)

  local function findLowestWaterPump()
    local lowest = { Height = -69420, Object = nil }
    local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

    if not currentRooms2 then
      return nil
    end

    for _, child in currentRooms2:GetChildren() do
      local waterPump = child:FindFirstChild("WaterPump")

      if waterPump and waterPump:GetAttribute("CH_Completed") ~= true then
        local basePart = waterPump:FindFirstChildWhichIsA("BasePart")

        if basePart and basePart.Position.Y > lowest.Height then
          lowest.Object = waterPump
          lowest.Height = basePart.Position.Y
        end
      end
    end

    return lowest.Object
  end

  local function waitLoop2(limit)
    local count = 0

    while task.wait(0.1) do
      count = count + 1

      if count > 600 then
        break
      end

      if not cutsceneActive then
        if character then
          character:PivotTo(limit:GetPivot())
        end

        local findFirstChild = limit:FindFirstChild("ValvePrompt", true)

        if findFirstChild then
          Functions.ForceFirePrompt(findFirstChild)
        end

        if limit:GetAttribute("CH_Completed") then
          break
        end
      end
    end
  end

  while task.wait(0.1) do
    local waterPump = findLowestWaterPump()

    if waterPump then
      waitLoop2(waterPump)
    else
      break
    end
  end

  if connection then
    connection:Disconnect()
  end

  library:Notify({
    Title = "Door 200", Description = "Finished water pump automation", Time = 4, })
end


function Handlers.AutoSolveAnchorsChanged()
  if AutoSolveAnchorsConnection then
    AutoSolveAnchorsConnection:Disconnect()
    AutoSolveAnchorsConnection = nil
  end

  if not toggles.AutoSolveAnchors.Value then
    return
  end

  local timer = 0

  AutoSolveAnchorsConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not toggles.AutoSolveAnchors.Value or CurrentFloor ~= "Mines" then
      return
    end

    local now = os.clock()

    if now - timer < 0.1 then
      return
    end

    timer = now
    local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")

    if not playerGui2 then
      return
    end

    local findFirstChild = playerGui2:FindFirstChild("AnchorHintFrame", true)

    if not findFirstChild then
      return
    end

    local anchorCode = findFirstChild:FindFirstChild("AnchorCode")
    local code = findFirstChild:FindFirstChild("Code")

    if not anchorCode or not code then
      return
    end

    local text = tostring(anchorCode.Text or "")

    if text == "" then
      return
    end

    local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

    if not currentRooms2 then
      return
    end

    for _, descendant in currentRooms2:GetDescendants() do
      if descendant.Name ~= "MinesAnchor" or not descendant:IsA("Model") then
        continue
      end

      if descendant:GetAttribute("Activated") then
        continue
      end

      local sign = descendant:FindFirstChild("Sign")

      if not sign then
        continue
      end

      local textLabel = sign:FindFirstChildOfClass("TextLabel")

      if not textLabel or textLabel.Text ~= text then
        continue
      end

      local primaryPart = descendant.PrimaryPart

      if not primaryPart then
        continue
      end

      local maxActivationDistance = descendant:FindFirstChild("ActivateEventPrompt")
          and descendant.ActivateEventPrompt.MaxActivationDistance
        or 20

      if humanoidRootPart
        and humanoidRootPart.Position
        and (humanoidRootPart.Position - primaryPart.Position).Magnitude
          <= maxActivationDistance then
        local anchorRemote = descendant:FindFirstChild("AnchorRemote")

        if anchorRemote then
          anchorRemote:InvokeServer(code.Text)
        end

        break
      end
    end
  end)
end


function Handlers.AutoSteerMinecartChanged()
  if AutoMinecartConnection then
    AutoMinecartConnection:Disconnect()
    AutoMinecartConnection = nil
  end

  if featureState.OriginalGetMoveVector then
    pcall(function()
      local getControls = require(localPlayer.PlayerScripts.PlayerModule):GetControls()
      getControls.GetMoveVector = featureState.OriginalGetMoveVector
    end)

    featureState.OriginalGetMoveVector = nil
  end

  if not toggles.AutoSteerMinecart.Value then
    return
  end

  local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")
  local mainUI = playerGui2 and playerGui2:FindFirstChild("MainUI")
  local initiator = mainUI and mainUI:FindFirstChild("Initiator")
  local mainGame = initiator and initiator:FindFirstChild("Main_Game")

  if not mainGame then
    return
  end

  local success, result3 = pcall(require, mainGame)

  if not success or not result3 then
    return
  end

  local success2, result4 = pcall(function()
    return require(localPlayer.PlayerScripts.PlayerModule):GetControls()
  end)

  local result

  if success2 and result4 then
    result = result4
  else
    return
  end

  local getMoveVector = result.GetMoveVector
  featureState.OriginalGetMoveVector = getMoveVector

  function result.GetMoveVector(...)
    if toggles.AutoSteerMinecart.Value and CurrentFloor == "Mines" then
      local nearestTurnNode = featureState.NearestTurnNode

      if nearestTurnNode and Functions.GetMinecart() then
        local turn = nearestTurnNode:GetAttribute("Turn")

        return turn == "Left" and Vector3.new(-1, 0, 0)
          or turn == "Right" and Vector3.new(1, 0, 0) or Vector3.zero
      end
    end

    return getMoveVector(...)
  end

  featureState.AutoMinecartDucked = false
  featureState.LastDuck = tick()

  AutoMinecartConnection = runService.Heartbeat:Connect(function()
    if _Unloading then
      return
    end

    if not toggles.AutoSteerMinecart.Value or not Functions.GetMinecart()
      or tick() - featureState.LastDuck < 0.1 then
      return
    end

    featureState.NearestTurnNode = Functions.GetNearestTurnNode()

    if not featureState.AutoMinecartDucked and Functions.GetNearestDuckBoard() then
      result3.crouch(true)
      featureState.AutoMinecartDucked = true
    elseif not Functions.GetNearestDuckBoard() and featureState.AutoMinecartDucked then
      result3.crouch(false)
      featureState.AutoMinecartDucked = false
    end

    if result3 then
      result3.fovtarget = options.FieldOfView.Value
    else
      currentCamera.FieldOfView = options.FieldOfView.Value
    end

    featureState.LastDuck = tick()
  end)
end


local function enableFullbright()
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

local function disableFullbright()
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

function Handlers.FullbrightChanged(value)
  if _FullbrightConnection then
    _FullbrightConnection:Disconnect()
    _FullbrightConnection = nil
  end

  if _FullbrightRoomConn then
    _FullbrightRoomConn:Disconnect()
    _FullbrightRoomConn = nil
  end

  if value then
    fbDefaults = {
      Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient, GlobalShadows = Lighting.GlobalShadows, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogColor = Lighting.FogColor, FogEnd = Lighting.FogEnd, ColorShift_Top = Lighting.ColorShift_Top, ColorShift_Bottom = Lighting.ColorShift_Bottom, ExposureCompensation = Lighting.ExposureCompensation, }

    fbAtmos = Lighting:FindFirstChildOfClass("Atmosphere")

    if fbAtmos then
      fbAtmosDefaults = {
        Haze = fbAtmos.Haze, Density = fbAtmos.Density, Offset = fbAtmos.Offset, Color = fbAtmos.Color, Decay = fbAtmos.Decay, Glare = fbAtmos.Glare, }
    end

    enableFullbright()
    local timer = 0

    _FullbrightConnection = runService.Heartbeat:Connect(function()
      if _Unloading then
        return
      end

      local now = tick()

      if now - timer < 0.3 then
        return
      end

      timer = now
      enableFullbright()
    end)

    local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

    if currentRooms2 then
      _FullbrightRoomConn = currentRooms2.ChildAdded:Connect(function() enableFullbright() end)
    end
  else
    disableFullbright()
    fbDefaults = nil
    fbAtmosDefaults = nil
  end
end


function Handlers.AmbientToggleChanged(value)
  local findFirstChild = currentRooms
    and currentRooms:FindFirstChild(tostring(localPlayer:GetAttribute("CurrentRoom")))

  local ambient = findFirstChild and findFirstChild:GetAttribute("Ambient")

  TweenService:Create(Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
    Ambient = value and options.AmbientColor.Value or ambient or Color3.fromRGB(255, 255, 255), }):Play()
end


function Handlers.AmbientColorChanged()
  if toggles.AmbientToggle and toggles.AmbientToggle.Value then
    TweenService:Create(Lighting, TweenInfo.new(0.2, Enum.EasingStyle.Exponential), {
      Ambient = options.AmbientColor.Value, }):Play()
  end
end


FreecamConnection = nil

local function stopFreecam()
  local freecamPart = workspace:FindFirstChild("FreecamPart")

  if freecamPart then
    freecamPart:Destroy()
  end

  local humanoidRootPart2 = localPlayer.Character
    and localPlayer.Character:FindFirstChild("HumanoidRootPart")

  if humanoidRootPart2 then
    humanoidRootPart2.Anchored = false
  end

  if localPlayer:GetAttribute("fc_om") then
    localPlayer.CameraMinZoomDistance = localPlayer:GetAttribute("fc_om")
  end

  if localPlayer:GetAttribute("fc_ox") then
    localPlayer.CameraMaxZoomDistance = localPlayer:GetAttribute("fc_ox")
  end
end

function Handlers.FreecamToggleChanged(value)
  if FreecamConnection then
    FreecamConnection:Disconnect()
  end

  if not value then
    stopFreecam()
  else
    FreecamConnection = runService.RenderStepped:Connect(function(delta)
      if _Unloading then
        return
      end

      if not toggles.FreecamToggle.Value then
        return
      end

      local character2 = localPlayer.Character
      local humanoid2 = character2 and character2:FindFirstChildOfClass("Humanoid")
      local humanoidRootPart2 = character2 and character2:FindFirstChild("HumanoidRootPart")

      if humanoidRootPart2 and not humanoidRootPart2.Anchored then
        humanoidRootPart2.Anchored = true
      end

      if not workspace:FindFirstChild("FreecamPart") then
        local freecamPart = Instance.new("Part")
        freecamPart.Name = "FreecamPart"
        freecamPart.Size = Vector3.new(0.01, 0.01, 0.01)
        freecamPart.Transparency = 1
        freecamPart.CanCollide = false
        freecamPart.Anchored = true
        freecamPart.CFrame = currentCamera.CFrame
        freecamPart.Parent = workspace

        localPlayer:SetAttribute("fc_om", localPlayer.CameraMinZoomDistance)
        localPlayer:SetAttribute("fc_ox", localPlayer.CameraMaxZoomDistance)
        localPlayer.CameraMinZoomDistance = 0
        localPlayer.CameraMaxZoomDistance = 0

        local pitch, yaw, _ = currentCamera.CFrame:ToOrientation()

        localPlayer:SetAttribute("fc_p", math.deg(pitch))
        localPlayer:SetAttribute("fc_y", math.deg(yaw))
      end

      local freecamPart = workspace:FindFirstChild("FreecamPart")
      local currentCamera2 = currentCamera

      if freecamPart and currentCamera2 then
        local getMouseDelta = userInputService:GetMouseDelta()
        local keyboardEnabled = userInputService.KeyboardEnabled and 0.3 or 0.6

        local pitch = (localPlayer:GetAttribute("fc_p") or 0)
          - getMouseDelta.Y * keyboardEnabled

        local yaw = (localPlayer:GetAttribute("fc_y") or 0)
          - getMouseDelta.X * keyboardEnabled

        pitch = math.max(-80, math.min(80, pitch))

        localPlayer:SetAttribute("fc_p", pitch)
        localPlayer:SetAttribute("fc_y", yaw)

        freecamPart.CFrame = CFrame.new(freecamPart.Position)
          * CFrame.fromOrientation(math.rad(pitch), math.rad(yaw), 0)

        currentCamera2.CFrame = freecamPart.CFrame
        currentCamera2.Focus = currentCamera2.CFrame * CFrame.new(0, 0, -10)

        if humanoid2 and humanoid2.MoveDirection.Magnitude > 0 then
          local freecamSpeed = options.FreecamSpeed and options.FreecamSpeed.Value or 75
          local vectorToObjectSpace = currentCamera2.CFrame:VectorToObjectSpace(humanoid2.MoveDirection)

          local moveVector = currentCamera2.CFrame.RightVector * vectorToObjectSpace.X
            + currentCamera2.CFrame.LookVector * -vectorToObjectSpace.Z

          freecamPart.Position = freecamPart.Position + moveVector * freecamSpeed * delta
        end
      end
    end)
  end
end


CutsceneNames = {
  "Figure", "FigureEnd", "FigureHotelEnd", "FigureHotelFire", "SeekIntroFools", "SeekIntroHotel", "SeekIntroMines", "SeekIntroMines2", "SerewSeekDrain", "SewerSeekLower", "GrumbleNestEnd", "EyestalkIntro", }


function Handlers.RemoveCutscenesChanged(value)
  local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")
  local mainUI = playerGui2 and playerGui2:FindFirstChild("MainUI")
  local initiator = mainUI and mainUI:FindFirstChild("Initiator")
  local mainGame = initiator and initiator:FindFirstChild("Main_Game")
  local remoteListener = mainGame and mainGame:FindFirstChild("RemoteListener")

  if not remoteListener then
    return
  end

  local cutscenes = remoteListener:FindFirstChild("Cutscenes")

  if cutscenes then
    for _, child in pairs(cutscenes:GetChildren()) do
      if TableFind(CutsceneNames, child.Name) and child:IsA("ModuleScript")
        or TableFind(CutsceneNames, child:GetAttribute("OriginalName"))
          and child:IsA("ModuleScript") then
        child.Name = value and child.Name .. "_Disabled"
          or child:GetAttribute("OriginalName") or child.Name
      end
    end
  end

  local floorReplicated = replicatedStorage:FindFirstChild("FloorReplicated")

  if floorReplicated then
    for _, child in pairs(floorReplicated:GetChildren()) do
      if TableFind(CutsceneNames, child.Name) and child:IsA("ModuleScript")
        or TableFind(CutsceneNames, child:GetAttribute("OriginalName"))
          and child:IsA("ModuleScript") then
        child.Name = value and child.Name .. "_Disabled"
          or child:GetAttribute("OriginalName") or child.Name
      end
    end
  end
end


TracerCategories = { "Entities", "Doors", "Keys", "Objectives", "Items", "Gold", "Chests", "HidingSpots" }

local TracerCatToDisplayName = {
  ["Entities"] = "Entities",
  ["Doors"] = "Doors",
  ["Keys"] = "Keys",
  ["Objectives"] = "Objectives",
  ["Items"] = "Items",
  ["Gold"] = "Coins",
  ["Chests"] = "Chests",
  ["HidingSpots"] = "Hiding Spots",
}


local function syncTracers()
  local master = toggles.TracersMaster and toggles.TracersMaster.Value
  local selected = options.TracersList and options.TracersList.Value or {}
  for _, cat in ipairs(TracerCategories) do
    local disp = TracerCatToDisplayName[cat] or cat
    local isEnabled = master and (selected[disp] == true)
    local text = cat .. "Tracers"
    if toggles[text] then
      toggles[text]:SetValue(isEnabled)
    end
  end
end


-- ---------------------------------------------------------------------
--  MoroESP look: boxes / chams / labels / presets (default = "Full Info")
-- ---------------------------------------------------------------------
do
local ESP_FLAGS = {
  ESPBoxStyle = { key = "box", kind = "option" },
  ESPBoxThickness = { key = "boxThick", kind = "option" },
  ESPChamsStyle = { key = "chams", kind = "option" },
  ESPNameStyle = { key = "nameStyle", kind = "option" },
  ESPHpBar = { key = "hpBar", kind = "toggle" },
  ESPHpText = { key = "hpText", kind = "toggle" },
  ESPSkeleton = { key = "skeleton", kind = "toggle" },
  ESPHeadDot = { key = "headDot", kind = "toggle" },
  ESPLookLine = { key = "lookLine", kind = "toggle" },
  ESPDistFade = { key = "distFade", kind = "toggle" },
}

local ESP_BASE = {
  ESPBoxStyle = "Rounded Glow", ESPBoxThickness = 1.6, ESPChamsStyle = "Flat", ESPNameStyle = "Pill",
  ESPHpBar = true, ESPHpText = true, ESPSkeleton = true, ESPHeadDot = true, ESPLookLine = true, ESPDistFade = true,
}

local ESP_PRESETS = {
  ["Full Info"] = {},
  ["Elegant"] = { ESPBoxStyle = "Corners", ESPChamsStyle = "Glow", ESPHpText = false, ESPSkeleton = false, ESPHeadDot = false, ESPLookLine = false },
  ["Minimal"] = { ESPBoxStyle = "Corners", ESPChamsStyle = "Off", ESPHpBar = false, ESPHpText = false, ESPSkeleton = false, ESPHeadDot = false, ESPLookLine = false },
  ["Clean Outline"] = { ESPBoxStyle = "Off", ESPChamsStyle = "Outline", ESPNameStyle = "Plain", ESPHpBar = false, ESPHpText = false, ESPSkeleton = false, ESPHeadDot = false, ESPLookLine = false },
  ["Chams Only"] = { ESPBoxStyle = "Off", ESPChamsStyle = "Glow", ESPHpBar = false, ESPHpText = false, ESPSkeleton = false, ESPHeadDot = false, ESPLookLine = false },
  ["Neon 3D"] = { ESPBoxStyle = "3D Box", ESPChamsStyle = "Rainbow", ESPHpText = false, ESPSkeleton = false, ESPHeadDot = false, ESPLookLine = false },
}

local function applyESPPreset(name)
  local preset = ESP_PRESETS[name]
  if not preset then return end

  for flag, spec in pairs(ESP_FLAGS) do
    local value = preset[flag]
    if value == nil then value = ESP_BASE[flag] end

    loader:SetSetting(spec.key, value)

    local control = spec.kind == "toggle" and toggles[flag] or options[flag]
    pcall(function() control:SetValue(value) end)
  end

  library:Notify({ Title = "ESP", Description = "Preset: " .. name, Time = 2 })
end


-- menu of this block: built later, from the MENU section at the end of the file
Menus.ESPLook = function()
  Groupboxes.Visuals_Preset:AddDropdown("ESPPreset", {
    Text = "Preset", Values = { "Full Info", "Elegant", "Minimal", "Clean Outline", "Chams Only", "Neon 3D" }, Default = "Full Info",
    Tooltip = "Ready-made ESP looks. Health, skeleton, head dot and look line only apply to players",
    Callback = function(value) if value then applyESPPreset(value) end end,
  })

  Groupboxes.Visuals_Preset:AddLabel("Full Info: rounded glow box, skeleton, head dot, look line, health, tracers, arrows and chams.")

  Groupboxes.Visuals_Style:AddDropdown("ESPBoxStyle", {
    Text = "Box Style", Values = { "Off", "Corners", "Full", "Rounded Glow", "3D Box" }, Default = "Rounded Glow",
    Callback = function(v) loader:SetSetting("box", v or "Off") end,
  })

  Groupboxes.Visuals_Style:AddSlider("ESPBoxThickness", {
    Text = "Box Thickness", Min = 0.5, Max = 4, Default = 1.6, Rounding = 1,
    Callback = function(v) loader:SetSetting("boxThick", v) end,
  })

  Groupboxes.Visuals_Style:AddSlider("ESPBoxFill", {
    Text = "Box Fill Transparency", Min = 0.5, Max = 1, Default = 0.88, Rounding = 2,
    Callback = function(v) loader:SetSetting("boxFill", v) end,
  })

  Groupboxes.Visuals_Style:AddDropdown("ESPChamsStyle", {
    Text = "Chams Style", Values = { "Off", "Flat", "Glow", "Pulse", "Rainbow", "Outline", "Visible Only" }, Default = "Flat",
    Tooltip = "Highlight on the object itself (Outline = no fill, Visible Only = hidden behind walls)",
    Callback = function(v) loader:SetSetting("chams", v or "Off") end,
  })

  Groupboxes.Visuals_Style:AddToggle("ESPDistFade", {
    Text = "Distance Fade", Default = true, Tooltip = "Far objects get more transparent",
    Callback = function(v) loader:SetSetting("distFade", v) end,
  })

  Groupboxes.Visuals_Labels:AddDropdown("ESPNameStyle", {
    Text = "Name Style", Values = { "Pill", "Plain" }, Default = "Pill",
    Callback = function(v) loader:SetSetting("nameStyle", v or "Pill") end,
  })

  Groupboxes.Visuals_Labels:AddToggle("ESPHpBar", {
    Text = "Health Bar", Default = true, Tooltip = "Players only",
    Callback = function(v) loader:SetSetting("hpBar", v) end,
  })

  Groupboxes.Visuals_Labels:AddToggle("ESPHpText", {
    Text = "Health Text", Default = true, Tooltip = "Players only",
    Callback = function(v) loader:SetSetting("hpText", v) end,
  })

  Groupboxes.Visuals_Labels:AddToggle("ESPSkeleton", {
    Text = "Skeleton", Default = true, Tooltip = "Players only",
    Callback = function(v) loader:SetSetting("skeleton", v) end,
  })

  Groupboxes.Visuals_Labels:AddToggle("ESPHeadDot", {
    Text = "Head Dot", Default = true, Tooltip = "Players only",
    Callback = function(v) loader:SetSetting("headDot", v) end,
  })

  Groupboxes.Visuals_Labels:AddToggle("ESPLookLine", {
    Text = "Look Line", Default = true, Tooltip = "Shows where a player is looking",
    Callback = function(v) loader:SetSetting("lookLine", v) end,
  })
end

end


function Handlers.ESPFadeTimeChanged(value)
  if toggles.ESPFade.Value then
    loader:SetFadeTime(value)
  end
end


loader.ShowESPText = true

loader.MaxDistance = 250


local floorReplicated = replicatedStorage:FindFirstChild("FloorReplicated")

if not floorReplicated then
  floorReplicated = Instance.new("Folder")
end

local mainGameModule

local function getMainGameModule()
  if mainGameModule then
    return mainGameModule
  end

  local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")
  local mainUI = playerGui2 and playerGui2:FindFirstChild("MainUI")
  local initiator = mainUI and mainUI:FindFirstChild("Initiator")
  local mainGame = initiator and initiator:FindFirstChild("Main_Game")

  if mainGame then
    local success, result = pcall(require, mainGame)

    if success and result then
      mainGameModule = result
      return mainGameModule
    end
  end

  return nil
end

function Handlers.RemoveCameraBobbingChanged(value)
  local module = getMainGameModule()

  if module and module.spring then
    module.spring.Speed = value and 9000000000 or 8
  end
end


function Handlers.RemoveCameraFogChanged(value)
  Lighting.FogEnd = value and 10000000 or featureState.OldFog or Lighting.FogEnd

  for _, fogInstance in ipairs(featureState.FogInstances) do
    fogInstance.Density = value and 0 or fogInstance:GetAttribute("Density_Old")
  end
end


function Handlers.DisableFiredampEffectChanged(value)
  local currentRooms2 = workspace:FindFirstChild("CurrentRooms")

  if currentRooms2 then
    for _, child in currentRooms2:GetChildren() do
      if value then
        child:SetAttribute("Firedamp", false)

        for _, child2 in currentCamera:GetChildren() do
          if child2.Name == "LiveFiredamp" then
            child2:Destroy()
          end
        end
      else
        child:SetAttribute("Firedamp", child:GetAttribute("Firedamp_Old"))
      end
    end
  end

  local currentRoom = localPlayer:GetAttribute("CurrentRoom")
  localPlayer:SetAttribute("CurrentRoom", 0)
  task.wait()
  localPlayer:SetAttribute("CurrentRoom", currentRoom)
end


local function updateHidingSpotTransparency(enabled, opacity)
  for _, hidingSpot in ipairs(ESPCategories.HidingSpots) do
    local isHiding = false

    for _, descendant in hidingSpot:GetDescendants() do
      if descendant.Name == "HiddenPlayer" and descendant.Value == character then
        isHiding = true
        break
      end
    end

    for _, descendant in hidingSpot:GetDescendants() do
      if descendant:IsA("BasePart") and descendant:GetAttribute("Transparency_Old") then
        TweenService:Create(descendant, TweenInfo.new(0.25, Enum.EasingStyle.Linear), {
          Transparency = enabled and isHiding and opacity or descendant:GetAttribute("Transparency_Old"), }):Play()
      end
    end
  end
end


local function setupMainGameHooks(enabled)
  local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")
  local mainUI = playerGui2 and playerGui2:FindFirstChild("MainUI")
  local initiator = mainUI and mainUI:FindFirstChild("Initiator")
  local mainGame = initiator and initiator:FindFirstChild("Main_Game")
  local remoteListener = mainGame and mainGame:FindFirstChild("RemoteListener")
  local value = options.JumpscaresList.Value or {}

  pcall(function()
    local jumpscares = remoteListener
      and (remoteListener:FindFirstChild("Jumpscares")
        or remoteListener:FindFirstChild("Jumpscares_Disabled"))

    if jumpscares then
      jumpscares.Name = enabled and "Jumpscares_Disabled" or "Jumpscares"

      for _, descendant in jumpscares:GetDescendants() do
        if descendant:IsA("ModuleScript") then
          local chOriginalName = descendant:GetAttribute("CHOriginalName")
            or descendant.Name:gsub("_Disabled", "")

          descendant:SetAttribute("CHOriginalName", chOriginalName)

          for key, _ in pairs(value) do
            if chOriginalName:lower():find(tostring(key):lower(), 1, true) then
              descendant.Name = enabled and chOriginalName .. "_Disabled" or chOriginalName
              break
            end
          end
        end
      end
    end
  end)
end


function Handlers.JumpscaresListChanged()
  if toggles.DisableJumpscares.Value then
    setupMainGameHooks(true)
  end
end


do
  local connection = runService.RenderStepped:Connect(function()
    if _Unloading then
      if connect26 then
        connect26:Disconnect()
      end

      return
    end

    local module = getMainGameModule()

    if module then
      if toggles.RemoveCameraShake.Value then
        module.csgo = CFrame.new()
      end

      if toggles.ViewmodelOffsetToggle.Value then
        module.tooloffset = Vector3.new(
          options.ViewmodelOffsetX.Value, options.ViewmodelOffsetY.Value, options.ViewmodelOffsetZ.Value
        )
      else
        module.tooloffset = Vector3.zero
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

local function getEntityMessage(entityData)
  if entityData.Text then
    return entityData.Text
  end

  if entityData.GodmodeText then
    return entityData.GodmodeText
  end

  if entityData.Danger then
    return entityData.Alias .. " is coming, hide!"
  end

  return "Entity detected!"
end

notifier.SoundAssets = {
  Achievement = "rbxassetid://10469938989", Tone = nil, Alert = nil, ["Windows XP"] = nil, ["GTA Cell"] = nil, }

pcall(function()
  if isfolder then
    if not isfolder("moro/Notification Sounds") then
      makefolder("moro/Notification Sounds")
    end

    local function fetchData(soundName, url)
      local text = "moro/Notification Sounds" .. "/" .. soundName .. "."
        .. (url:match("%.([a-zA-Z0-9]+)$") or "mp3")

      if not isfile(text) then
        writefile(text, game:HttpGet(url))
      end

      return getcustomasset(text)
    end

    notifier.SoundAssets.Tone = fetchData(
      "tone", "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/tone%20notification.mp3"
    )

    notifier.SoundAssets.Alert = fetchData(
      "alert", "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/alert%20notification.mp3"
    )

    notifier.SoundAssets["Windows XP"] = fetchData(
      "xp", "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/windows%20xp%20exclamation.ogg"
    )

    notifier.SoundAssets["GTA Cell"] = fetchData(
      "gta", "https://raw.githubusercontent.com/doram44/cheesy/main/notif%20sounds/gta%20notification.ogg"
    )
  end
end)

notifier.SoundInstance = Instance.new("Sound")
notifier.SoundInstance.Name = "morohubnotifsound"
notifier.SoundInstance.Volume = 0.65

pcall(function() notifier.SoundInstance.Parent = SoundService end)

function notifier.PlaySound(soundName)
  soundName = soundName or "NotifySound"

  pcall(function()
    local achievement = notifier.SoundAssets[options[soundName].Value] or notifier.SoundAssets.Achievement

    notifier.SoundInstance.SoundId = achievement
    notifier.SoundInstance.TimePosition = 0
    notifier.SoundInstance:Play()
  end)
end

notifier.ActiveAchievement = {}

local function shiftAchievements(startIndex)
  for i = startIndex, #notifier.ActiveAchievement do
    local targetY = 72 + (i - 1) * 150

    TweenService:Create(
      notifier.ActiveAchievement[i], TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(1, -22, 0, targetY) }
    ):Play()
  end
end

function notifier.CustomAchievement(title, description, extra)
  local morohubentitynotif = Instance.new("ScreenGui")
  morohubentitynotif.Name = "morohubentitynotif"
  morohubentitynotif.ResetOnSpawn = false
  morohubentitynotif.IgnoreGuiInset = true
  morohubentitynotif.Parent = CoreGui

  local height = extra and 110 or 90

  local frame = Instance.new("Frame")
  frame.Size = UDim2.new(0, 350, 0, height)
  frame.AnchorPoint = Vector2.new(1, 0)
  frame.BackgroundTransparency = 1
  frame.Parent = morohubentitynotif

  local targetY = 72 + (#notifier.ActiveAchievement + 1 - 1) * 150
  frame.Position = UDim2.new(1, 370, 0, targetY)
  table.insert(notifier.ActiveAchievement, frame)

  local textLabel = Instance.new("TextLabel")
  textLabel.BackgroundTransparency = 1
  textLabel.Position = UDim2.new(0, 0, 0, -30)
  textLabel.Size = UDim2.new(1, 0, 0, 28)
  textLabel.Font = Enum.Font.GothamBlack
  textLabel.Text = "Entity detected"
  textLabel.TextColor3 = Color3.fromRGB(255, 238, 216)
  textLabel.TextStrokeTransparency = 0.75
  textLabel.TextSize = 20
  textLabel.TextXAlignment = Enum.TextXAlignment.Left
  textLabel.Parent = frame

  local frame2 = Instance.new("Frame")
  frame2.Name = "Frame"
  frame2.Size = UDim2.new(1, 0, 1, 0)
  frame2.BackgroundColor3 = Color3.fromRGB(35, 22, 18)
  frame2.BorderSizePixel = 0
  frame2.Parent = frame

  Instance.new("UICorner", frame2).CornerRadius = UDim.new(0, 9)

  local instance = Instance.new("UIStroke", frame2)
  instance.Color = Color3.fromRGB(255, 236, 214)
  instance.Thickness = 3

  local imageLabel = Instance.new("ImageLabel")
  imageLabel.Name = "ImageLabel"
  imageLabel.BackgroundTransparency = 1
  imageLabel.Image = "rbxassetid://106990021902592"
  imageLabel.Size = UDim2.new(0, 76, 0, 76)
  imageLabel.Position = UDim2.new(0, 10, 0, 10)
  imageLabel.ScaleType = Enum.ScaleType.Fit
  imageLabel.Parent = frame2

  local details = Instance.new("Frame")
  details.Name = "Details"
  details.BackgroundTransparency = 1
  details.Position = UDim2.new(0, 96, 0, 10)
  details.Size = UDim2.new(1, -106, 1, -20)
  details.Parent = frame2

  local function createTextLabel(name, text, offsetY, textSize, font)
    local textLabel2 = Instance.new("TextLabel")
    textLabel2.Name = name
    textLabel2.BackgroundTransparency = 1
    textLabel2.Position = UDim2.new(0, 0, 0, offsetY)
    textLabel2.Size = UDim2.new(1, 0, 0, textSize + 12)
    textLabel2.Font = font
    textLabel2.Text = text
    textLabel2.TextScaled = true
    textLabel2.TextSize = textSize
    textLabel2.TextWrapped = true
    textLabel2.TextXAlignment = Enum.TextXAlignment.Left
    textLabel2.TextYAlignment = Enum.TextYAlignment.Top
    textLabel2.TextColor3 = Color3.fromRGB(255, 238, 216)
    textLabel2.TextStrokeTransparency = 0.8
    textLabel2.Parent = details
  end

  createTextLabel("Title", title, 0, 18, Enum.Font.GothamBold)
  createTextLabel("Desc", description, 34, 14, Enum.Font.Gotham)

  if extra then
    createTextLabel("Reason", extra, 64, 14, Enum.Font.Gotham)
  end

  task.spawn(function()
    TweenService:Create(
      frame, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(1, -22, 0, targetY) }
    ):Play()

    task.wait(5.5)

    TweenService:Create(
      frame, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, 370, 0, targetY) }
    ):Play()

    task.wait(0.5)

    for index, activeAchievementEntry in ipairs(notifier.ActiveAchievement) do
      if activeAchievementEntry == frame then
        table.remove(notifier.ActiveAchievement, index)
        shiftAchievements(index)
        break
      end
    end

    morohubentitynotif:Destroy()
  end)
end

function notifier.ShowAchievement(title, description, extra, options2)
  if not localPlayer then
    notifier.CustomAchievement(title, description, extra)
    return
  end

  local playerGui2 = localPlayer:FindFirstChild("PlayerGui")

  local globalUI = playerGui2
    and (playerGui2:FindFirstChild("GlobalUI") or playerGui2:FindFirstChild("MainUI"))

  local achievementsHolder = globalUI and globalUI:FindFirstChild("AchievementsHolder")
  local achievement = achievementsHolder and achievementsHolder:FindFirstChild("Achievement")

  if not (globalUI and achievementsHolder and achievement) then
    notifier.CustomAchievement(title, description, extra)
    return
  end

  local function createSound(parent, soundId, volume)
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = volume or 1
    sound.Parent = parent

    task.spawn(function()
      task.wait(0.1)

      sound:Play()
      sound.Ended:Wait()
      sound:Destroy()
    end)
  end

  local liveAchievement = achievement:Clone()
  liveAchievement.Size = UDim2.new(0, 0, 0, 0)
  liveAchievement.Frame.Position = UDim2.new(1.1, 0, 0, 0)
  liveAchievement.Name = "LiveAchievement"
  liveAchievement.Visible = true
  liveAchievement.Frame.TextLabel.Text = title or "NOTIFICATION"
  liveAchievement.Frame.Details.Title.Text = options2 or title or ""
  liveAchievement.Frame.Details.Desc.Text = description or ""
  liveAchievement.Frame.Details.Reason.Text = extra or ""
  liveAchievement.Frame.TextLabel.TextWrapped = true
  liveAchievement.Frame.Details.Title.TextWrapped = true
  liveAchievement.Frame.Details.Desc.TextWrapped = true
  liveAchievement.Frame.Details.Reason.TextWrapped = true
  liveAchievement.Frame.ImageLabel.Image = "rbxassetid://106990021902592"

  local color = Color3.new(1, 1, 1)

  liveAchievement.Frame.TextLabel.TextColor3 = color
  liveAchievement.Frame.UIStroke.Color = color
  liveAchievement.Frame.Glow.ImageColor3 = color
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

notifier.ActiveEntity = 0

function notifyEntitySpawn(object)
  if not espEntityNames[object.Name] then
    return
  end

  local entityData = EntityNotifyData[object.Name]

  if not entityData then
    return
  end

  if entityData.NoNotify then
    return
  end

  if not toggles.NotifyEntities.Value then
    return
  end

  local value = options.EntityList.Value

  if value and next(value) ~= nil and not value[entityData.Alias] then
    return
  end

  if notifier.ActiveEntity >= 6 then
    return
  end

  notifier.ActiveEntity = notifier.ActiveEntity + 1
  notifier.PlaySound()

  local message = getEntityMessage(entityData)

  local dangerousEntities = {
    RushMoving = true, AmbushMoving = true, A60 = true, BackdoorRush = true, ["RNIUSHCG=="] = true, AR0xMBUSH = true, BashMoving = true, }

  if toggles.Godmode.Value and dangerousEntities[object.Name] then
    message = entityData.Alias .. " is coming, but you have godmode enabled so don't worry!"
  end

  if options.NotifyStyle.Value == "Obsidian" then
    library:Notify({ Title = "Entity detected", Description = message, Time = 5 })
  else
    task.spawn(function()
      notifier.ShowAchievement(
        "Entity detected", message, nil, "Entity '" .. (entityData.Alias or "") .. "' has spawned"
      )
    end)
  end

  if toggles.EntityChatToggle.Value then
    Functions.SendChat(entityData.Alias .. " " .. options.EntityChatMessage.Value)
  end

  task.delay(6, function() notifier.ActiveEntity = math.max(0, notifier.ActiveEntity - 1) end)
end

for _, descendant in workspace:GetDescendants() do
  task.spawn(handleESPObject, descendant)
  task.spawn(registerPrompt, descendant)
  task.spawn(handleRoomObject, descendant)
end

featureState.OldFog = Lighting.FogEnd

for _, child in Lighting:GetChildren() do
  if child:IsA("Atmosphere") then
    local descendant = child
    descendant:SetAttribute("Density_Old", descendant.Density)

    local connection = descendant:GetPropertyChangedSignal("Density"):Connect(function()
      if descendant.Density ~= 0 then
        descendant:SetAttribute("Density_Old", descendant.Density)
      end

      if toggles.RemoveCameraFog.Value then
        descendant.Density = 0
      end
    end)

    child.Destroying:Once(function() connection:Disconnect() end)

    table.insert(Connections, connection)
    table.insert(featureState.FogInstances, child)
  end
end

workspace.DescendantAdded:Connect(handleESPObject)
workspace.DescendantAdded:Connect(registerPrompt)
workspace.DescendantAdded:Connect(handleRoomObject)

for _, descendant in workspace:GetDescendants() do
  if descendant:IsA("ProximityPrompt") and not descendant:GetAttribute("FakePrompt") then
    task.spawn(registerPrompt, descendant)
  end
end

local now2 = tick()

runService.Heartbeat:Connect(function()
  if _Unloading then
    return
  end

  if tick() - now2 <= 0.5 then
    return
  end

  now2 = tick()

  for _, _TrackedPrompt in ipairs(_TrackedPrompts) do
    if _TrackedPrompt and _TrackedPrompt.Parent then
      if _TrackedPrompt:HasTag("DisableWhenEnabledOnClient") then
        _TrackedPrompt:RemoveTag("DisableWhenEnabledOnClient")
      end

      if toggles and toggles.InstantInteract and toggles.InstantInteract.Value
        and _TrackedPrompt.HoldDuration ~= 0 then
        _TrackedPrompt.HoldDuration = 0
      end

      if toggles and toggles.PromptClip and toggles.PromptClip.Value
        and _TrackedPrompt.RequiresLineOfSight ~= false then
        _TrackedPrompt.RequiresLineOfSight = false
      end

      if toggles and toggles.PromptReach and toggles.PromptReach.Value then
        local maxActivationDistanceOld = _TrackedPrompt:GetAttribute("MaxActivationDistance_Old")

        if maxActivationDistanceOld then
          local promptRange = options and options.PromptRange
            and maxActivationDistanceOld * options.PromptRange.Value

          if promptRange and _TrackedPrompt.MaxActivationDistance ~= promptRange then
            _TrackedPrompt.MaxActivationDistance = promptRange
          end
        end
      end
    end
  end

  if toggles and toggles.NotifyVulnerable and toggles.NotifyVulnerable.Value
    and humanoidRootPart then
    local y = humanoidRootPart.Position.Y

    if VulnerableLastY then
      if y - VulnerableLastY >= 3 and tick() - VulnerableNotifCooldown >= 3 then
        library:Notify({
          Title = "Vulnerable", Description = "You've moved 3+ studs upward!", Time = 3, })

        VulnerableNotifCooldown = tick()
      end
    end

    VulnerableLastY = y
  end
end)

AutoHide = { Last = tick(), ThreatConns = {} }
function Handlers.AutoClosetToggleChanged(value)
  if _AutoHideConnection then
    _AutoHideConnection:Disconnect()
    _AutoHideConnection = nil
  end

  if value then
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
        local functions = Functions.GetNearestHidingSpot()

        if character:GetAttribute("Hiding") ~= true and functions then
          Functions.ForceFirePrompt(functions.HidePrompt)
        end
      elseif character:GetAttribute("Hiding") == true then
        remotesFolder.CamLock:FireServer()
      end

      if toggles.RemoveClosetDelay.Value and humanoid.MoveDirection ~= Vector3.zero
        and (collisionPart.Anchored or humanoidRootPart.Anchored)
        and character:GetAttribute("AnimatingClient") ~= true
        and character:GetAttribute("Hiding") == true then
        remotesFolder.CamLock:FireServer()
      end

      AutoHide.Last = tick()
    end)
  end
end


local function watchOxygen()
  if character then
    local lastOxygen = -1
    local warningLevels = { 80, 60, 40, 20 }

    character:GetAttributeChangedSignal("Oxygen"):Connect(function()
      local oxygen = character:GetAttribute("Oxygen")

      if toggles.NotifyOxygen and toggles.NotifyOxygen.Value then
        local floorVal = math.floor(oxygen + 0.5)

        if floorVal ~= lastOxygen and TableFind(warningLevels, floorVal) then
          library:Notify({
            Title = "Oxygen decreasing", Description = "Your oxygen is at " .. tostring(floorVal) .. "%", Time = 3, })

          lastOxygen = floorVal
        end
      end
    end)
  end

  if floorReplicated:FindFirstChild("DigitalTimer") then
    local lastSecond = -1

    floorReplicated.DigitalTimer:GetPropertyChangedSignal("Value"):Connect(function()
      if toggles.NotifyHasteTime and toggles.NotifyHasteTime.Value then
        local value = floorReplicated.DigitalTimer.Value

        if TableFind({ 90, 60, 30, 15 }, value) and value ~= lastSecond then
          lastSecond = value

          library:Notify({
            Title = "Haste notification", Description = "Haste is coming in " .. value .. " seconds!", Time = 3, })
        end
      end
    end)
  end
end

watchOxygen()

localPlayer.CharacterAdded:Connect(function()
  task.wait(1)
  watchOxygen()
end)

Connections.FogHandler = Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
  if Lighting.FogEnd ~= 10000000 then
    featureState.OldFog = Lighting.FogEnd
  end

  if toggles.RemoveCameraFog.Value then
    Lighting.FogEnd = 10000000
  end
end)

Connections.FogHandler2 = Lighting.DescendantAdded:Connect(function(descendant)
  if not descendant:IsA("Atmosphere") then
    return
  end

  descendant:SetAttribute("Density_Old", descendant.Density)

  if toggles.RemoveCameraFog.Value then
    descendant.Density = 0
  end

  local connection = descendant:GetPropertyChangedSignal("Density"):Connect(function()
    if descendant.Density ~= 0 then
      descendant:SetAttribute("Density_Old", descendant.Density)
    end

    if toggles.RemoveCameraFog.Value then
      descendant.Density = 0
    end
  end)

  descendant.Destroying:Once(function() connection:Disconnect() end)

  table.insert(Connections, connection)
  table.insert(featureState.FogInstances, descendant)
end)

localPlayer.CharacterAppearanceLoaded:Connect(function()
  task.wait(1)
  local module = getMainGameModule()

  if toggles.RemoveCameraBobbing.Value and module and module.spring then
    module.spring.Speed = 9000000000
  end
end)

localPlayer.CharacterAdded:Connect(function()
  task.wait(1)
  mainGameModule = nil
  local module = getMainGameModule()

  if toggles.RemoveCameraBobbing.Value and module and module.spring then
    module.spring.Speed = 9000000000
  end

  if toggles.DisableJumpscares.Value then
    setupMainGameHooks(true)
  end
end)

-- =====================================================================
--                   AUTONOMOUS KNOB FARM ENGINE
--               (Hotel AutoWalk - As seen in Video)
-- =====================================================================

do (function()

KnobFarm = KnobFarm or {}
getgenv().KnobFarm = KnobFarm
getgenv().Toggles = toggles
getgenv().Options = options
KnobFarm.Active = false
KnobFarm.Thread = nil
KnobFarm.CurrentRoomNum = 0
KnobFarm.DisableGodmodeForBoss = false
KnobFarm.PassedFirstDoor = false
KnobFarm.LootedObjects = setmetatable({}, { __mode = "k" })
KnobFarm.OpenedDoors = setmetatable({}, { __mode = "k" })
KnobFarm.PreviousWalkSpeed = nil
KnobFarm.LastPosition = nil
KnobFarm.LastMoveTime = 0
KnobFarm.LastRoomNum = nil
KnobFarm.RoomEntryTime = 0
KnobFarm.StartKnobs = nil
KnobFarm.StartKnobsBeforeShop = false
KnobFarm.LockpickBoughtThisRun = false
KnobFarm.StatsRecordedThisRun = false
KnobFarm.RunGold = 0
KnobFarm.Teleporting = false
KnobFarm.InLobby = false
KnobFarm.SeekMode = false
KnobFarm.IgnoredDoors = setmetatable({}, { __mode = "k" })
KnobFarm.GatesHandled = setmetatable({}, { __mode = "k" })

local STATS_FILE = "Doors_Farm_Stats.json"

-- Номера комнат и таймауты в одном месте (раньше были разбросаны числами по условиям)
local ROOMS = {
  LAST_NORMAL = 49,        -- дальше 49-й «быстрый цикл» заканчивается (если Farm to Door 100 выключен)
  FIGURE = 50,             -- библиотека с Фигурой
  SHOP_FROM = 54,          -- магазин Джеффа: 54-59, ничего не покупаем
  SHOP_TO = 59,
  SECOND_SEEK = 60,        -- с 60-й комнаты вторая погоня Seek; саму 60-ю игнорируем
  IGNORE_FROM = 89,        -- 89-99: ничего не лутаем и не ждём, летим к двери
  IGNORE_TO = 99,
  ELEVATOR = 100,          -- щитовая и лифт
  SEEK_DOORS_FIRST = 7,    -- дверей в первой погоне
  SEEK_DOORS_SECOND = 10,  -- и во второй
  SKIP_DOOR_AFTER = 90,    -- секунд в одной комнате до принудительного скипа двери
  PLAY_AGAIN_AFTER = 600,  -- секунд в одной комнате до Play Again
}

-- Что фарм меняет в других функциях (Godmode, Instant Interact и т.д.) идёт через SetFeature:
-- первое изменение запоминает исходное значение, Stop() возвращает всё обратно (если пользователь
-- сам не поменял тумблер после фарма).
local featureBackup = {}
local function SetFeature(name, value, isOption)
  local control = isOption and options and options[name] or (not isOption and toggles and toggles[name])
  if not control then return end
  local current = control.Value
  if current == value then return end
  local record = featureBackup[name]
  if not record then
    record = { original = current, control = control }
    featureBackup[name] = record
  end
  record.set = value
  pcall(function() control:SetValue(value) end)
end

local function RestoreFeatures()
  for name, record in pairs(featureBackup) do
    pcall(function()
      if record.control.Value == record.set then record.control:SetValue(record.original) end
    end)
    featureBackup[name] = nil
  end
end

local function GetPlayerKnobs()
  local val = nil
  if localPlayer then
    val = localPlayer:GetAttribute("Knobs") or localPlayer:GetAttribute("Knob")
    if typeof(val) == "number" then return val end

    local leaderstats = localPlayer:FindFirstChild("leaderstats")
    if leaderstats then
      local k = leaderstats:FindFirstChild("Knobs") or leaderstats:FindFirstChild("Knob")
      if k and typeof(k.Value) == "number" then return k.Value end
    end
  end

  local gameData = replicatedStorage and replicatedStorage:FindFirstChild("GameData")
  if gameData then
    local k = gameData:FindFirstChild("Knobs") or gameData:FindFirstChild("Knob")
    if k and typeof(k.Value) == "number" then return k.Value end
  end

  pcall(function()
    local mainUI = localPlayer and localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("MainUI")
    if mainUI then
      local itemShop = mainUI:FindFirstChild("ItemShop")
      if itemShop then
        for _, desc in ipairs(itemShop:GetDescendants()) do
          if desc:IsA("TextLabel") and desc.Text:match("^%d+$") and desc.Name:lower():find("knob") then
            local n = tonumber(desc.Text)
            if n then val = n break end
          end
        end
      end
    end
  end)
  if typeof(val) == "number" then return val end

  return nil
end

local function LoadStats()
  local stats = {
    TotalEarned = 0,
    TotalSpent = 0,
    NetProfit = 0,
    RunsCompleted = 0,
  }

  if isfile and isfile(STATS_FILE) then
    local success, result = pcall(readfile, STATS_FILE)
    if success and result and #result > 0 then
      local success2, result3 = pcall(function()
        return httpService:JSONDecode(result)
      end)
      if success2 and typeof(result3) == "table" then
        stats.TotalEarned = tonumber(result3.TotalEarned) or 0
        stats.TotalSpent = tonumber(result3.TotalSpent) or 0
        stats.NetProfit = tonumber(result3.NetProfit) or 0
        stats.RunsCompleted = tonumber(result3.RunsCompleted) or 0
      end
    end
  end

  return stats
end

local function SaveStats(stats)
  if writefile then
    pcall(function()
      local json = httpService:JSONEncode(stats)
      writefile(STATS_FILE, json)
    end)
  end
end

local function UpdateStatsGUI(stats, lastNet)
  if not stats then stats = LoadStats() end
  pcall(function()
    if Groupboxes and Groupboxes.AutoFarm_StatsNet then
      local sign = stats.NetProfit >= 0 and "+" or ""
      local lastTxt = lastNet and (" (Last: " .. (lastNet >= 0 and "+" or "") .. tostring(lastNet) .. ")") or ""
      Groupboxes.AutoFarm_StatsNet:SetText("Net Profit: " .. sign .. tostring(stats.NetProfit) .. " Knobs" .. lastTxt)
    end
    if Groupboxes and Groupboxes.AutoFarm_StatsEarned then
      Groupboxes.AutoFarm_StatsEarned:SetText("Total Earned: " .. tostring(stats.TotalEarned) .. " Knobs")
    end
    if Groupboxes and Groupboxes.AutoFarm_StatsRuns then
      Groupboxes.AutoFarm_StatsRuns:SetText("Runs: " .. tostring(stats.RunsCompleted) .. " (Spent: " .. tostring(stats.TotalSpent) .. ")")
    end
  end)
end

local function RecordRunStats()
  if KnobFarm.StatsRecordedThisRun then return end
  KnobFarm.StatsRecordedThisRun = true

  local currentKnobs = GetPlayerKnobs()
  local startKnobs = KnobFarm.StartKnobs
  local lockpickBought = KnobFarm.LockpickBoughtThisRun or false
  local spent = lockpickBought and 50 or 0
  local earned = 0
  local net = 0

  if currentKnobs and startKnobs then
    local diff = currentKnobs - startKnobs
    if KnobFarm.StartKnobsBeforeShop then
      net = diff
      earned = net + spent
    else
      earned = math.max(0, diff)
      net = earned - spent
    end
  else
    local gold = KnobFarm.RunGold or 0
    earned = math.floor(gold / 20)
    net = earned - spent
  end

  local stats = LoadStats()
  stats.TotalEarned = (stats.TotalEarned or 0) + math.max(0, earned)
  stats.TotalSpent = (stats.TotalSpent or 0) + spent
  stats.NetProfit = (stats.NetProfit or 0) + net
  stats.RunsCompleted = (stats.RunsCompleted or 0) + 1

  SaveStats(stats)
  UpdateStatsGUI(stats, net)
end

task.spawn(function()
  task.wait(1.0)
  UpdateStatsGUI()
end)

if not featureState.HotelNodesFolder then
  featureState.HotelNodesFolder = Instance.new("Folder")
  featureState.HotelNodesFolder.Name = "HotelPathNodes"
  featureState.HotelNodesFolder.Parent = workspace
end

local lastStatusText = nil

function KnobFarm.SetStatus(txt)
  txt = tostring(txt)
  if txt == lastStatusText then return end -- не дёргаем GUI 25 раз в секунду одним и тем же текстом
  lastStatusText = txt
  pcall(function()
    if Groupboxes and Groupboxes.AutoFarm_Status then
      Groupboxes.AutoFarm_Status:SetText("Status: " .. tostring(txt))
    end
  end)
end

local currentNodes = {}

local function ClearPathNodes()
  for i, node in pairs(currentNodes) do
    if node and node.Parent then
      pcall(function() node:Destroy() end)
    end
  end
  table.clear(currentNodes)

  if featureState.HotelNodesFolder then
    for _, child in ipairs(featureState.HotelNodesFolder:GetChildren()) do
      if child.Name == "PathNode" then
        pcall(function() child:Destroy() end)
      end
    end
  end
end

local function ResetFarmState()
  ClearPathNodes()
  KnobFarm.PassedFirstDoor = false
  KnobFarm.CurrentRoomNum = nil
  KnobFarm.LastRoomNum = nil
  KnobFarm.RoomEntryTime = nil
  KnobFarm.LootedObjects = setmetatable({}, { __mode = "k" })
  KnobFarm.OpenedDoors = setmetatable({}, { __mode = "k" })
  KnobFarm.IgnoredDoors = setmetatable({}, { __mode = "k" })
  KnobFarm.StartKnobs = nil
  KnobFarm.StartKnobsBeforeShop = false
  KnobFarm.LockpickBoughtThisRun = false
  KnobFarm.StatsRecordedThisRun = false
  KnobFarm.RunGold = 0
  KnobFarm.FirstChaseDone = false
  KnobFarm.SecondChaseDone = false
  KnobFarm.InSeekChase = false
  KnobFarm.InRoom50Skip = false
  KnobFarm.SeekDoorsSkipped = 0
  KnobFarm.LastSkippedRoom = nil
  KnobFarm.SeekChaseStartRoom = nil
  -- Эти флаги раньше НЕ сбрасывались: после смерти посреди Seek/босса они оставались включёнными.
  KnobFarm.Teleporting = false
  KnobFarm.SeekMode = false
  KnobFarm.DisabledNoclipForSeek = false
  KnobFarm.NoclipBeforeSeek = false
  KnobFarm.LibraryPadlockSeen = false
  KnobFarm.DisableGodmodeForBoss = false
  KnobFarm.AvoidFigure = false
  KnobFarm.GatesHandled = setmetatable({}, { __mode = "k" })
  pcall(function()
    if toggles.Phase and toggles.Phase.Value then
      toggles.Phase:SetValue(false)
    end
    Phase.TargetPosition = nil
    Phase.Speed = nil
  end)
end

local function RenderPathNodes(waypoints)
  ClearPathNodes()
  if not featureState.HotelNodesFolder then return end

  local showPath = true
  if toggles and toggles.AutoFarmShowPath then
    showPath = toggles.AutoFarmShowPath.Value
  end
  if not showPath then return end

  for i, wp in ipairs(waypoints) do
    local pos = (typeof(wp) == "Vector3" and wp) or (wp and wp.Position)
    if pos then
      local node = Instance.new("Part")
      node.Transparency = 0.35
      node.Size = Vector3.new(0.85, 0.85, 0.85)
      node.Position = pos
      node.Shape = Enum.PartType.Ball
      node.CanCollide = false
      node.Anchored = true
      node.Name = "PathNode"
      node.Color = Color3.fromRGB(0, 255, 0)
      node.Material = Enum.Material.Neon
      node.Parent = featureState.HotelNodesFolder
      currentNodes[i] = node
    end
  end
end

local function GetMainGameModule()
  local pGui = localPlayer and localPlayer:FindFirstChildOfClass("PlayerGui")
  local mUI = pGui and pGui:FindFirstChild("MainUI")
  local init = mUI and mUI:FindFirstChild("Initiator")
  local mg = init and init:FindFirstChild("Main_Game")
  if mg and mg:IsA("ModuleScript") then
    local success, result = pcall(require, mg)
    if success and type(result) == "table" then
      return result
    end
  end
  return nil
end

local LastCrouchCall = 0
local CurrentCrouchState = nil

local function SetCrouched(state)
  if CurrentCrouchState == state and (tick() - LastCrouchCall < 1.0) then
    return
  end
  CurrentCrouchState = state
  LastCrouchCall = tick()

  pcall(function()
    local char = localPlayer and localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
      if state then
        hum.JumpPower = 0
        hum.JumpHeight = 0
        hum.UseJumpPower = true
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
      else
        hum.JumpPower = 50
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
      end
    end
  end)

  pcall(function()
    local mg = GetMainGameModule()
    if mg and mg.crouch then
      mg.crouch(state)
    end
  end)

  pcall(function()
    local char = localPlayer and localPlayer.Character
    if char then
      char:SetAttribute("Crouching", state)
    end
    if remotesFolder and remotesFolder:FindFirstChild("Crouch") then
      remotesFolder.Crouch:FireServer(state, true)
    end
    if collisionPart then
      collisionPart.CollisionGroup = state and "PlayerCrouching" or "Player"
    end
  end)
end

local function GetInstancePosition(inst)
  if not inst then return nil end
  if inst:IsA("BasePart") then
    return inst.Position
  elseif inst:IsA("Attachment") then
    return inst.WorldPosition
  elseif inst:IsA("ProximityPrompt") then
    local p = inst.Parent
    if p then
      if p:IsA("BasePart") then return p.Position end
      if p:IsA("Attachment") then return p.WorldPosition end
      if p:IsA("Model") then
        local prim = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart", true)
        if prim then return prim.Position end
      end
    end
  elseif inst:IsA("Model") then
    local prim = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    if prim then return prim.Position end
  end
  local success, result = pcall(function() return inst:GetPivot().Position end)
  if success and result then return result end
  return nil
end

-- Один RaycastParams на весь фарм: раньше он создавался заново на каждый рейкаст (десятки раз в секунду)
local sharedRayParams = RaycastParams.new()
sharedRayParams.FilterType = Enum.RaycastFilterType.Exclude
local rayChar, rayNodes
local function GetRayParams()
  local char = localPlayer and localPlayer.Character
  local nodes = featureState and featureState.HotelNodesFolder
  if char ~= rayChar or nodes ~= rayNodes then
    rayChar, rayNodes = char, nodes
    local filter = {}
    if char then table.insert(filter, char) end
    if nodes then table.insert(filter, nodes) end
    sharedRayParams.FilterDescendantsInstances = filter
  end
  return sharedRayParams
end

local function HasFloorUnder(pos, maxDist)
  if not pos then return false, nil end
  local hit = workspace:Raycast(pos + Vector3.new(0, 2.5, 0), Vector3.new(0, -(maxDist or 30), 0), GetRayParams())
  if hit and hit.Instance then
    return true, hit.Position, hit.Instance
  end
  return false, nil, nil
end

local function GetFloorPosition(pos)
  if not pos then return nil end
  local hasFloor, floorPos = HasFloorUnder(pos, 30)
  if hasFloor and floorPos then
    return floorPos
  end
  return nil
end

-- Безопасная точка внутри комнаты (вход/выход или над полом); общая для void- и roof-восстановления
local function FindSafePosition(room)
  local roomsFolder = workspace:FindFirstChild("CurrentRooms")
  local curRoom = room
  if not curRoom and roomsFolder then
    if KnobFarm.CurrentRoomNum then
      curRoom = roomsFolder:FindFirstChild(tostring(KnobFarm.CurrentRoomNum))
    end
    if not curRoom then
      local maxNum = -1
      for _, r in ipairs(roomsFolder:GetChildren()) do
        local n = tonumber(r.Name)
        if n and n > maxNum then
          maxNum = n
          curRoom = r
        end
      end
    end
  end

  local safePart = curRoom and (curRoom:FindFirstChild("RoomEntrance") or curRoom:FindFirstChild("RoomExit"))
  if safePart and safePart:IsA("BasePart") then
    return safePart.Position + Vector3.new(0, 3, 0)
  end
  if curRoom then
    local floor = curRoom:FindFirstChild("Floor", true) or curRoom:FindFirstChild("Parts", true)
    if floor and floor:IsA("BasePart") then
      return floor.Position + Vector3.new(0, 4, 0)
    end
  end
  return nil
end

local isRecoveringFromVoid = false
local function RecoverFromVoid(room)
  if isRecoveringFromVoid then return end
  isRecoveringFromVoid = true

  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not root then
    isRecoveringFromVoid = false
    return
  end

  KnobFarm.SetStatus("Fell into void! Returning to the room...")

  local safePos = FindSafePosition(room)
  if safePos then
    KnobFarm.Teleporting = true   -- иначе откат Phantom Noclip вернёт персонажа обратно в пустоту
    root.CFrame = CFrame.new(safePos)
    root.AssemblyLinearVelocity = Vector3.zero
  end

  task.wait(0.5)

  if safePos then
    root.AssemblyLinearVelocity = Vector3.zero
  end
  KnobFarm.Teleporting = false

  KnobFarm.SetStatus("Back in the room. Resuming...")
  isRecoveringFromVoid = false
end

KnobFarm.RecoverFromVoid = RecoverFromVoid

-- ═══════════════════════════════════════════════════════════════════
-- ОБЩИЕ ПОМОЩНИКИ
-- (раньше эти куски были скопированы по 15–20 раз по всему автофарму)
-- ═══════════════════════════════════════════════════════════════════

-- Единственное RenderStepped-соединение FollowPath. Хранится здесь, чтобы Stop() мог его
-- отключить: раньше при выключении посреди пути соединение оставалось жить и «призрак»
-- снова начинал рулить персонажем после повторного включения фарма.
local activeMoveConn = nil

local function GetRoot()
  local char = localPlayer and localPlayer.Character
  return char and char:FindFirstChild("HumanoidRootPart")
end

-- Предмет по имени: сначала в руках, потом в рюкзаке (раньше этот поиск был скопирован ~6 раз)
local function FindTool(...)
  local char = localPlayer and localPlayer.Character
  local backpack = localPlayer and localPlayer:FindFirstChildOfClass("Backpack")
  for i = 1, select("#", ...) do
    local name = select(i, ...)
    local tool = (char and char:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
    if tool then return tool end
  end
  return nil
end

-- Игрок жив: циклы комнат 50 и 100 раньше проверяли только Active и продолжали «проходить» комнату мёртвым персонажем
local function PlayerAlive()
  local char = localPlayer and localPlayer.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  return hum ~= nil and hum.Health > 0
end

local function GetFarmSpeed()
  local opt = options and options.AutoFarmSpeed
  return (opt and opt.Value) or 35
end

-- Единая точка управления скоростью (раньше — 6 копий с разными дефолтами 22/35)
local function ApplyFarmSpeed(hum)
  local speed = GetFarmSpeed()
  SetFeature("EnableWalkspeed", true)
  SetFeature("PhantomNoclip", not (KnobFarm.InSeekChase or KnobFarm.SeekMode))   -- фарм ходит с Phantom Noclip
  SetFeature("Noclip", false)
  if options and options.Walkspeed and options.Walkspeed.Value ~= speed then
    options.Walkspeed:SetValue(speed)
  end
  if hum and hum.WalkSpeed ~= speed then
    hum.WalkSpeed = speed
  end
  return speed
end

-- Единый способ «нажать» ProximityPrompt.
--   withHold  — дополнительно имитировать удержание (для ящиков/замков)
--   withForce — дополнительно вызвать Functions.ForceFirePrompt (для дверей/рычагов/ключей)
local function FirePrompt(prompt, withHold, withForce)
  if not prompt or not prompt:IsA("ProximityPrompt") then return end
  pcall(function()
    prompt.HoldDuration = 0
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 30
    prompt.Enabled = true
  end)
  if fireproximityprompt then
    pcall(fireproximityprompt, prompt, 0, true)
    pcall(fireproximityprompt, prompt)
  end
  if withHold then
    pcall(function()
      prompt:InputHoldBegin()
      task.wait(0.04)
      prompt:InputHoldEnd()
    end)
  end
  if withForce and Functions and Functions.ForceFirePrompt then
    pcall(Functions.ForceFirePrompt, prompt)
  end
end

local function GetGameData()
  return replicatedStorage and replicatedStorage:FindFirstChild("GameData")
end

local function GetLatestRoomNum()
  local gameData = GetGameData()
  local v = gameData and gameData:FindFirstChild("LatestRoom")
  return v and tonumber(v.Value) or nil
end

-- Игра подняла флаг погони Seek, а фарм ещё идёт по своему пути/лутает: путь нужно оборвать, чтобы главный
-- цикл успел включить режим погони (телепорт по дверям). Раньше бот дорабатывал путь и не успевал.
local function ChasePending()
  if KnobFarm.InSeekChase then return false end
  local num = KnobFarm.CurrentRoomNum or 0
  if num < ROOMS.SECOND_SEEK and KnobFarm.FirstChaseDone then return false end
  if num >= ROOMS.SECOND_SEEK and KnobFarm.SecondChaseDone then return false end
  local gameData = GetGameData()
  local flag = gameData and gameData:FindFirstChild("ChaseInSession")
  return flag ~= nil and flag.Value == true
end

-- Play Again (раньше — 4 копии поиска ремоута). Уважает тумблер AutoFarmPlayAgain.
local function RequestPlayAgain()
  if toggles and toggles.AutoFarmPlayAgain and not toggles.AutoFarmPlayAgain.Value then
    return false
  end
  local remote = (remotesFolder and remotesFolder:FindFirstChild("PlayAgain"))
    or (replicatedStorage and replicatedStorage:FindFirstChild("RemotesFolder")
      and replicatedStorage.RemotesFolder:FindFirstChild("PlayAgain"))
  if remote then
    pcall(function() remote:FireServer() end)
    return true
  end
  return false
end

-- Закрыть пред-ранный магазин, если он открыт (раньше — 2 копии)
local function ConfirmShopIfOpen()
  pcall(function()
    if Functions and Functions.ConfirmPreRunShop then
      local pGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
      local mainUI = pGui and pGui:FindFirstChild("MainUI")
      local itemShop = mainUI and mainUI:FindFirstChild("ItemShop")
      if itemShop and itemShop.Visible then
        Functions.ConfirmPreRunShop()
      end
    end
  end)
end

-- Запомнить баланс Knobs в начале забега (для статистики)
local function CaptureStartKnobs(beforeShop)
  if KnobFarm.StartKnobs then return end
  local k = GetPlayerKnobs()
  if k then
    KnobFarm.StartKnobs = k
    KnobFarm.StartKnobsBeforeShop = (beforeShop and not KnobFarm.LockpickBoughtThisRun) or false
  end
end

local function IsStairPart(part)
  if not part then return false end
  local pName = part.Name:lower()
  local parName = (part.Parent and part.Parent.Name:lower()) or ""
  return (pName:find("stair", 1, true) or pName:find("step", 1, true)
    or parName:find("stair", 1, true) or parName:find("step", 1, true)) ~= nil
end

local function HasCeilingAbove(pos, maxDist)
  if not pos then return false, nil, nil end
  local rayParams = RaycastParams.new()
  rayParams.FilterType = Enum.RaycastFilterType.Exclude
  local char = localPlayer and localPlayer.Character
  local filter = {}
  if char then table.insert(filter, char) end
  if featureState and featureState.HotelNodesFolder then table.insert(filter, featureState.HotelNodesFolder) end
  rayParams.FilterDescendantsInstances = filter

  local rayOrigin = pos + Vector3.new(0, 1.5, 0)
  local rayDir = Vector3.new(0, maxDist or 35, 0)
  local hit = workspace:Raycast(rayOrigin, rayDir, rayParams)
  if hit and hit.Instance then
    return true, hit.Position, hit.Instance
  end
  return false, nil, nil
end

local function IsOnRoof(room)
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not root then return false end

  -- Если прямо над головой есть потолок/люстра/балка, бот внутри комнаты
  local hasCeil = HasCeilingAbove(root.Position, 35)
  if hasCeil then
    return false
  end

  -- Потолка нет — определяем текущую комнату
  local curR = room
  if not curR then
    local roomsFolder = workspace:FindFirstChild("CurrentRooms")
    if KnobFarm and KnobFarm.CurrentRoomNum and roomsFolder then
      curR = roomsFolder:FindFirstChild(tostring(KnobFarm.CurrentRoomNum))
    end
    if not curR and roomsFolder then
      local maxNum = -1
      for _, r in ipairs(roomsFolder:GetChildren()) do
        local n = tonumber(r.Name)
        if n and n > maxNum then
          maxNum = n
          curR = r
        end
      end
    end
  end

  local entrance = curR and (curR:FindFirstChild("RoomEntrance") or curR:FindFirstChild("RoomExit"))
  local baseY = entrance and entrance.Position.Y
  if not baseY and curR then
    local floor = curR:FindFirstChild("Floor", true) or curR:FindFirstChild("Parts", true)
    if floor and floor:IsA("BasePart") then baseY = floor.Position.Y end
  end

  -- Исключение: Courtyard (двор / сад с фонтаном на открытом воздухе на уровне земли)
  local isCourtyard = curR and (curR:FindFirstChild("Fountain", true) or (curR:FindFirstChild("Assets") and curR.Assets:FindFirstChild("Fountain")))
  if isCourtyard and baseY and math.abs(root.Position.Y - baseY) < 5 then
    return false
  end

  -- 1. Проверяем пол под ногами: содержит ли имя детали/родителя "roof", "ceiling", "top"
  local hasF, floorPos, floorInst = HasFloorUnder(root.Position, 25)
  if hasF and floorInst then
    local fn = floorInst.Name:lower()
    local fp = (floorInst.Parent and floorInst.Parent.Name:lower()) or ""
    if fn:find("roof") or fn:find("ceiling") or fp:find("roof") or fp:find("ceiling") then
      return true
    end
  end

  -- 2. Проверяем высоту относительно пола: если бот выше пола комнаты на 13+ стадов и потолка нет
  if baseY and (root.Position.Y - baseY) > 13 then
    return true
  end

  -- Если бот стоит на высоте пола комнаты — это точно не крыша (потолок мог просто не попасть под рейкаст)
  if baseY and (root.Position.Y - baseY) < 8 then
    return false
  end

  -- 3. Если это обычная комната отеля (не двор) и над головой нет потолка — это крыша
  if not isCourtyard then
    return true
  end

  return false
end

local isRecoveringFromRoof = false
local function RecoverFromRoof(room)
  if isRecoveringFromRoof then return end
  isRecoveringFromRoof = true

  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not root then
    isRecoveringFromRoof = false
    return
  end

  KnobFarm.SetStatus("Landed on roof! Returning inside room...")

  local safePos = FindSafePosition(room)
  if safePos then
    KnobFarm.Teleporting = true   -- иначе откат Phantom Noclip вернёт персонажа обратно на крышу
    root.CFrame = CFrame.new(safePos)
    root.AssemblyLinearVelocity = Vector3.zero
  end

  task.wait(0.4)

  if safePos then
    root.AssemblyLinearVelocity = Vector3.zero
  end
  KnobFarm.Teleporting = false

  KnobFarm.SetStatus("Returned inside from roof! Resuming...")
  isRecoveringFromRoof = false
end

KnobFarm.HasCeilingAbove = HasCeilingAbove
KnobFarm.IsOnRoof = IsOnRoof
KnobFarm.RecoverFromRoof = RecoverFromRoof

-- «Крыша» подтверждается только если условие держится ≥0.5с, проверка не чаще 5 раз/сек.
-- Раньше IsOnRoof (несколько рейкастов) вызывался каждые 0.04с в двух местах, а ОДНО ложное
-- срабатывание телепортировало бота на вход комнаты.
local roofSince = nil
local lastRoofCheckAt = 0
local lastRoofResult = false

local function HandleRoof(room)
  local now = tick()
  if now - lastRoofCheckAt >= 0.2 then
    lastRoofCheckAt = now
    if IsOnRoof(room) then
      roofSince = roofSince or now
      lastRoofResult = (now - roofSince) >= 0.5
    else
      roofSince = nil
      lastRoofResult = false
    end
  end
  if lastRoofResult then
    RecoverFromRoof(room)
    roofSince = nil
    lastRoofResult = false
    return true
  end
  return false
end

-- Флаги «идёт восстановление» — локальные, а Stop() делает task.cancel потока. Если отмена
-- прилетала посреди RecoverFromVoid/Roof, флаг оставался true навсегда и восстановление
-- больше никогда не срабатывало.
local function ResetRecoveryState()
  isRecoveringFromVoid = false
  isRecoveringFromRoof = false
  roofSince = nil
  lastRoofResult = false
end

local function HasLockpick()
  if Functions and Functions.HasItem then
    local lp = Functions.HasItem("Lockpick") or Functions.HasItem("Lockpicks")
    if lp then return true, lp end
  end
  local char = localPlayer and localPlayer.Character
  local bp = localPlayer and localPlayer:FindFirstChildOfClass("Backpack")
  if char then
    for _, it in ipairs(char:GetChildren()) do
      if it:IsA("Tool") and it.Name:lower():find("lockpick", 1, true) then
        return true, it
      end
    end
  end
  if bp then
    for _, it in ipairs(bp:GetChildren()) do
      if it:IsA("Tool") and it.Name:lower():find("lockpick", 1, true) then
        return true, it
      end
    end
  end
  return false, nil
end

-- Ключ подходит к двери, если у него тот же LockID (RoomID двери). Раньше бот держал ключ от старой двери,
-- считал, что ключ есть, и вечно стоял у новой запертой двери, не идя за её ключом.
local function KeyFitsLock(tool, lockId)
  if not lockId then return true end
  local id = tool:GetAttribute("LockID")
  return id == nil or id == lockId
end

local function HasKeyTool(lockId)
  if Functions and Functions.HasItem then
    local k = Functions.HasItem("Key") or Functions.HasItem("KeyObtain") or Functions.HasItem("KeyElectrical") or Functions.HasItem("KeyIron")
    if k and (typeof(k) ~= "Instance" or KeyFitsLock(k, lockId)) then return true, k end
  end
  local char = localPlayer and localPlayer.Character
  local bp = localPlayer and localPlayer:FindFirstChildOfClass("Backpack")
  for _, container in ipairs({ char, bp }) do
    if container then
      for _, it in ipairs(container:GetChildren()) do
        if it:IsA("Tool") then
          local n = it.Name:lower()
          if (n == "key" or n:find("key", 1, true)) and not n:find("skeleton", 1, true) and KeyFitsLock(it, lockId) then
            return true, it
          end
        end
      end
    end
  end
  return false, nil
end

local function EquipUnlockTool(preferLockpick, lockId)
  local char = localPlayer and localPlayer.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if not hum or not char then return end

  if preferLockpick then
    local hasLp, lpTool = HasLockpick()
    if hasLp and lpTool then
      if lpTool.Parent ~= char then
        pcall(function()
          hum:UnequipTools()
          hum:EquipTool(lpTool)
        end)
      end
      return
    end
  end

  -- При открытии дверей: если есть ключ, ВСЕГДА берем именно ключ (прячем отмычки, если они в руке)
  local hasKey, keyTool = HasKeyTool(lockId)
  if hasKey and keyTool then
    if keyTool.Parent ~= char then
      pcall(function()
        hum:UnequipTools()
        hum:EquipTool(keyTool)
      end)
    end
    return
  end

  local hasLp, lpTool = HasLockpick()
  if hasLp and lpTool then
    if lpTool.Parent ~= char then
      pcall(function()
        hum:UnequipTools()
        hum:EquipTool(lpTool)
      end)
    end
    return
  end
end

-- Убедиться, что подходящий ключ именно в руках (а не в рюкзаке): до 2 секунд пробуем взять его.
local function EnsureKeyInHand(lockId)
  local deadline = tick() + 2.0
  repeat
    local char = localPlayer and localPlayer.Character
    local has, tool = HasKeyTool(lockId)
    if has and tool and char and tool.Parent == char then return true end
    if has and tool then
      EquipUnlockTool(false, lockId)
    end
    task.wait(0.1)
  until tick() > deadline or not KnobFarm.Active or _Unloading
  local char = localPlayer and localPlayer.Character
  local has, tool = HasKeyTool(lockId)
  return has and tool ~= nil and char ~= nil and tool.Parent == char
end

local function FindRoomKey(room)
  local function isKeyCandidate(inst)
    if not inst then return false end
    local n = inst.Name:lower()
    if n == "door" or n == "lock" or n == "unlockprompt" or n:find("door", 1, true) then
      return false
    end
    if inst:FindFirstAncestor("Door") or inst:FindFirstAncestor("Lock") then
      return false
    end
    if n:find("fake", 1, true) then
      return false
    end
    return true
  end

  local function searchIn(container)
    if not container then return nil, nil end

    -- 1. Direct search by model / part name
    for _, keyName in ipairs({ "KeyObtain", "Key", "KeyElectrical", "ElectricalKeyObtain", "KeyIron", "IronKey" }) do
      for _, inst in ipairs(container:GetDescendants()) do
        if inst.Name == keyName and isKeyCandidate(inst) then
          local pos = GetInstancePosition(inst)
          if pos then return inst, pos end
        end
      end
    end

    -- 2. Search through ProximityPrompts
    for _, desc in ipairs(container:GetDescendants()) do
      if desc:IsA("ProximityPrompt") and desc.Enabled and isKeyCandidate(desc) then
        local p = desc.Parent
        if p and isKeyCandidate(p) then
          local pName = p.Name:lower()
          local objText = (desc.ObjectText or ""):lower()
          local dName = desc.Name:lower()

          if pName == "keyobtain" or pName == "key" or pName:find("key", 1, true)
            or objText == "key" or objText:find("key", 1, true)
            or dName:find("key", 1, true) then
            local pos = GetInstancePosition(p) or GetInstancePosition(desc)
            if pos then return p, pos end
          end
        end
      end
    end

    return nil, nil
  end

  if room then
    local kObj, kPos = searchIn(room)
    if kObj and kPos then return kObj, kPos end
  end

  local curRooms = workspace:FindFirstChild("CurrentRooms")
  if curRooms then
    for _, r in ipairs(curRooms:GetChildren()) do
      if r ~= room then
        local kObj, kPos = searchIn(r)
        if kObj and kPos then return kObj, kPos end
      end
    end
  end

  return nil, nil
end

local function IsDoorLocked(door)
  if not door or not door.Parent then return false, nil end
  if KnobFarm.OpenedDoors[door] then return false, nil end
  if door:GetAttribute("Opened") == true or door:GetAttribute("Open") == true then
    return false, nil
  end

  -- Замок считается закрытым, пока у него есть промпт «Unlock». После отпирания модель замка остаётся висеть,
  -- но промпт исчезает: раньше бот принимал такую дверь за запертую и крутился перед ней вечно.
  local lock = door:FindFirstChild("Lock") or door:FindFirstChild("Lock", true)
  if lock and lock.Parent then
    local unPr = lock:FindFirstChild("UnlockPrompt")
      or lock:FindFirstChildWhichIsA("ProximityPrompt", true)
    if unPr then
      return true, unPr
    end
  end

  local unlockPrompt = door:FindFirstChild("UnlockPrompt", true)
  if unlockPrompt and unlockPrompt.Enabled then
    return true, unlockPrompt
  end

  return false, nil
end

local function GetDoorCenter(door)
  if not door then return nil end

  local sign = door:FindFirstChild("Sign")
  local hidden = door:FindFirstChild("Hidden")
  if hidden and hidden:IsA("BasePart") then
    return hidden.Position
  end

  local room = door.Parent
  local roomExit = room and room:FindFirstChild("RoomExit")
  if roomExit and roomExit:IsA("BasePart") then
    return roomExit.Position
  end

  local col = door:FindFirstChild("Collision")
  if col and col:IsA("BasePart") then
    return col.Position
  end

  local signPos = nil
  if sign then
    if sign:IsA("BasePart") then
      signPos = sign.Position
    elseif sign:IsA("Model") then
      local sPart = sign.PrimaryPart or sign:FindFirstChildWhichIsA("BasePart", true)
      if sPart then signPos = sPart.Position end
    end
  end

  local doorLeaf = nil
  for _, ch in ipairs(door:GetChildren()) do
    if ch.Name == "Door" and ch:IsA("BasePart") then
      doorLeaf = ch
      break
    end
  end
  if not doorLeaf then
    local d = door:FindFirstChild("Door")
    if d and d:IsA("BasePart") then
      doorLeaf = d
    end
  end

  local bboxCenter = nil
  if door:IsA("Model") then
    local success, result = pcall(function() return door:GetBoundingBox() end)
    if success and result then
      bboxCenter = result.Position
    end
  end

  if signPos then
    local y = (doorLeaf and doorLeaf.Position.Y) or (bboxCenter and bboxCenter.Y) or (signPos.Y - 2.5)
    return Vector3.new(signPos.X, y, signPos.Z)
  elseif doorLeaf then
    return doorLeaf.Position
  elseif bboxCenter then
    return bboxCenter
  end

  for _, p in ipairs(door:GetDescendants()) do
    if p:IsA("BasePart") and p.Name ~= "Hinge" then
      return p.Position
    end
  end
  return GetInstancePosition(door)
end

local function GetPlayerCurrentRoom()
  local roomsFolder = workspace:FindFirstChild("CurrentRooms")
  if not roomsFolder then return nil, 0 end

  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not root then return nil, 0 end

  -- 1. Raycast downward
  local hit = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -35, 0), GetRayParams())
  if hit and hit.Instance then
    local p = hit.Instance
    while p and p.Parent and p.Parent ~= roomsFolder do
      p = p.Parent
    end
    if p and p.Parent == roomsFolder and tonumber(p.Name) then
      return p, tonumber(p.Name)
    end
  end

  -- 2. Fallback: Find closest room
  local bestRoom = nil
  local bestDist = math.huge
  local bestNum = 0

  for _, r in ipairs(roomsFolder:GetChildren()) do
    local n = tonumber(r.Name)
    if n then
      local rPos = nil
      local door = r:FindFirstChild("Door")
      if door then
        rPos = GetDoorCenter(door)
      end
      if not rPos then
        local prim = r.PrimaryPart or r:FindFirstChildWhichIsA("BasePart", true)
        if prim then rPos = prim.Position end
      end
      if rPos then
        local dist = (root.Position - rPos).Magnitude
        if dist < bestDist then
          bestDist = dist
          bestRoom = r
          bestNum = n
        end
      end
    end
  end

  return bestRoom, bestNum
end

local function IsGateRoomWithThingToOpen(room)
  if not room then return false end
  local assets = room:FindFirstChild("Assets")
  local gate = assets and assets:FindFirstChild("Gate")
  if gate and gate:FindFirstChild("ThingToOpen") then
    return true
  end
  local thing = room:FindFirstChild("ThingToOpen", true)
  if thing and thing.Parent and thing.Parent.Name == "Gate" then
    return true
  end
  return false
end

local function HasRoomGate(room)
  if not room then return false, nil, nil end
  if IsGateRoomWithThingToOpen(room) then return false, nil, nil end
  local gate = room:FindFirstChild("Gate", true) or room:FindFirstChild("ThingToOpen", true)
  if not gate then return false, nil, nil end
  local lever = room:FindFirstChild("LeverForGate", true) or room:FindFirstChild("Lever", true)
  return true, gate, lever
end

local obstacleListener = nil

-- Список объектов, у которых отключаем коллизию (раньше он был скопирован в двух функциях)
local OBSTACLE_TERMS = {
  "plant", "pot", "flowerpot", "pot_", "_pot",
  "bush", "flower", "fern", "leaf", "leaves", "foliage",
  "vase", "bonsai", "hedge", "cactus", "shrub", "vine",
  "tree", "planter", "chair", "table", "lamp", "stool",
  "bench", "debris", "barrel", "crate", "box", "carpet",
  "curtain", "candle", "cushion", "pillow", "rug",
  "luggage", "cart", "dresser", "stand", "clock", "hanger",
  "pillar", "rafter", "shelf", "bookcase"
}

-- Эти детали нельзя «отключать» никогда: подстрочное совпадение (например "pot" внутри
-- "spotlight") по имени родителя иногда задевало ПОЛ — отсюда проваливания в пустоту,
-- на которые потом пришлось навешивать RecoverFromVoid/RecoverFromRoof.
local STRUCTURAL_NAMES = { floor = true, ground = true, roof = true, ceiling = true }

local function ShouldDisableCollision(desc)
  if not desc:IsA("BasePart") or not desc.CanCollide then return false end

  local partName = desc.Name:lower()
  if STRUCTURAL_NAMES[partName] then return false end

  local parent = desc.Parent
  local parentName = parent and parent.Name:lower() or ""
  local grandParent = parent and parent.Parent
  local grandName = grandParent and grandParent.Name:lower() or ""

  local isInsideAssets = (parentName == "assets" or grandName == "assets")
  if isInsideAssets and (partName == "collision" or partName == "hitbox") then
    return true
  end

  local s = partName .. " " .. parentName .. " " .. grandName
  for _, t in ipairs(OBSTACLE_TERMS) do
    if s:find(t, 1, true) then
      return true
    end
  end
  return false
end

local function DisableObstacleCollision(room)
  local function disableIn(container)
    if not container then return end
    pcall(function()
      for _, desc in ipairs(container:GetDescendants()) do
        if ShouldDisableCollision(desc) then
          desc.CanCollide = false
        end
      end
    end)
  end

  if room then
    disableIn(room)
  else
    local roomsFolder = workspace:FindFirstChild("CurrentRooms")
    if roomsFolder then
      for _, r in ipairs(roomsFolder:GetChildren()) do
        disableIn(r)
      end
    end
  end
end

local function SetupObstacleListener()
  if obstacleListener then
    pcall(function() obstacleListener:Disconnect() end)
    obstacleListener = nil
  end
  local roomsFolder = workspace:FindFirstChild("CurrentRooms")
  if roomsFolder then
    obstacleListener = roomsFolder.DescendantAdded:Connect(function(desc)
      task.defer(function()
        pcall(function()
          if ShouldDisableCollision(desc) then
            desc.CanCollide = false
          end
        end)
      end)
    end)
  end
end


local MOVE_KEYS = {
  Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
  Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
}

local function IsUserMovingManually()
  if not userInputService then return false end
  for _, k in ipairs(MOVE_KEYS) do
    if userInputService:IsKeyDown(k) then return true end
  end
  return false
end

-- Магазин Джеффа: в комнатах 54–59 ничего не покупаем (раньше бот тратил там все деньги,
-- потому что промпты товаров попадали под «подбираемые предметы»)
local function IsJeffShopPrompt(prompt)
  local n = KnobFarm.CurrentRoomNum or 0
  if n < ROOMS.SHOP_FROM or n > ROOMS.SHOP_TO then return false end
  local act = (prompt.ActionText or ""):lower()
  local obj = (prompt.ObjectText or ""):lower()
  if act:find("purchase", 1, true) or act:find("buy", 1, true)
    or obj:find("purchase", 1, true) or obj:find("buy", 1, true) then
    return true
  end
  local node = prompt.Parent
  if node and (node:GetAttribute("Price") or node:GetAttribute("Cost")
    or node:FindFirstChild("Price") or node:FindFirstChild("Cost")) then
    return true
  end
  while node and node ~= workspace do
    local nm = node.Name:lower()
    if nm:find("shop", 1, true) or nm:find("jeff", 1, true) or nm:find("store", 1, true) then
      return true
    end
    node = node.Parent
  end
  return false
end

local function IsLootablePrompt(prompt)
  if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return false end
  -- В комнате 50 (библиотека) тумбочки/ящики не лутаем — шум привлекает Фигуру
  if KnobFarm and (KnobFarm.CurrentRoomNum == 50) then
    local pp = prompt.Parent
    local ppName = pp and pp.Name:lower() or ""
    local obj = (prompt.ObjectText or ""):lower()
    local act = (prompt.ActionText or ""):lower()
    if ppName:find("drawer", 1, true) or ppName:find("nightstand", 1, true)
      or ppName:find("dresser", 1, true) or ppName:find("chest", 1, true)
      or obj:find("drawer", 1, true) or obj:find("nightstand", 1, true)
      or obj:find("chest", 1, true)
      or act == "open" or act == "search" or act == "loot" then
      return false
    end
  end
  local parent = prompt.Parent
  if not parent then return false end
  local pName = parent.Name
  local pNameLower = pName:lower()
  local objText = (prompt.ObjectText or ""):lower()
  local actionText = (prompt.ActionText or ""):lower()

  -- Exclude doors, door locks, gate levers, figure triggers, hint papers/books, fuse boxes, closets, fireplaces
  if pName == "Door" or (pName == "Padlock" and parent:FindFirstAncestor("Door"))
    or (pName == "Lock" and parent:FindFirstAncestor("Door"))
    or parent:FindFirstAncestor("Door") or pName == "DoorFake" or pName == "FakeDoor"
    or pName:find("Gate", 1, true) or pName:find("Lever", 1, true)
    or pName == "LiveHintBook" or pName == "LibraryHintPaper"
    or pName == "FusePickup" or pName == "FuseObtain"
    or pNameLower:find("closet", 1, true) or pNameLower:find("wardrobe", 1, true)
    or pNameLower:find("fireplace", 1, true) or pNameLower:find("hearth", 1, true) or pNameLower:find("chimney", 1, true)
    or parent:FindFirstAncestor("Fireplace") or parent:FindFirstAncestor("FirePlace")
    or objText:find("fireplace", 1, true) or objText:find("hearth", 1, true) or objText:find("chimney", 1, true)
    or actionText:find("light", 1, true) or actionText:find("ignite", 1, true) or actionText:find("burn", 1, true) then
    return false
  end

  local checkAnc = parent
  while checkAnc and checkAnc ~= workspace do
    local ancName = checkAnc.Name:lower()
    if ancName:find("fireplace", 1, true) or ancName:find("hearth", 1, true) or ancName:find("chimney", 1, true) then
      return false
    end
    checkAnc = checkAnc.Parent
  end

  -- Don't close drawers
  if actionText == "close" then return false end

  -- Не покупать в магазине Джеффа
  if IsJeffShopPrompt(prompt) then return false end

  -- 1. Gold & Stardust
  if pName == "GoldPile" or pName == "TinyGold" or pName == "Gold"
    or pName == "StardustPickup" or pName == "Stardust"
    or parent:GetAttribute("GoldValue")
    or objText:find("gold", 1, true) or objText:find("stardust", 1, true) then
    return true
  end

  -- 2. Drawers, Chests, Toolboxes, Containers, Chest Locks
  if pName:find("Drawer", 1, true) or pName:find("Chest", 1, true)
    or pName:find("Toolbox", 1, true) or pName:find("Toolshed", 1, true)
    or pName:find("Box", 1, true) or pName == "Lock" or pName == "Padlock"
    or objText:find("drawer", 1, true) or objText:find("chest", 1, true)
    or objText:find("box", 1, true) or objText:find("lock", 1, true)
    or actionText == "open" or actionText == "search" or actionText == "loot" or actionText == "unlock" then
    return true
  end

  -- 3. Pickable items (Bandages, Batteries, Lighters, Vitamins, Lockpicks, Flashlights, etc.)
  if actionText == "take" or actionText == "grab" or actionText == "pick up" or actionText == "steal"
    or pNameLower:find("pickup", 1, true) or pNameLower:find("obtain", 1, true)
    or pNameLower:find("bandage", 1, true) or pNameLower:find("battery", 1, true)
    or pNameLower:find("lighter", 1, true) or pNameLower:find("vitamins", 1, true)
    or pNameLower:find("flashlight", 1, true) or pNameLower:find("crucifix", 1, true)
    or pNameLower:find("lockpick", 1, true) or pNameLower:find("key", 1, true) then
    return true
  end

  return false
end

local NavigateTo
local FollowPath
local PassDoorStraight

-- ───────────────────────────── ЛУТ ─────────────────────────────
-- Раньше «выстрел по промпту» (экипировать отмычку → выставить свойства → fire ×2 → hold)
-- был скопирован 3 раза, а комната пересканировалась GetDescendants() по 3–4 раза на цель.

local function IsLockedPrompt(prompt)
  local p = prompt.Parent
  return prompt.Name == "UnlockPrompt" or prompt.Name == "LockPrompt"
    or (p ~= nil and (p.Name:lower():find("lock", 1, true) ~= nil or p:GetAttribute("Locked") == true))
end

-- Камины отключаем и помечаем, чтобы бот никогда к ним не бегал
local function DisableFireplaces(room)
  for _, desc in ipairs(room:GetDescendants()) do
    if desc:IsA("ProximityPrompt") then
      local p = desc.Parent
      local pName = p and p.Name:lower() or ""
      local obj = (desc.ObjectText or ""):lower()
      local act = (desc.ActionText or ""):lower()
      if pName:find("fireplace", 1, true) or pName:find("hearth", 1, true) or pName:find("chimney", 1, true)
        or obj:find("fireplace", 1, true) or obj:find("hearth", 1, true) or obj:find("chimney", 1, true)
        or act:find("light", 1, true) or act:find("ignite", 1, true) or act:find("burn", 1, true)
        or desc:FindFirstAncestor("Fireplace") or desc:FindFirstAncestor("FirePlace") then
        pcall(function() desc.Enabled = false end)
        KnobFarm.LootedObjects[desc] = true
      end
    end
  end
end

-- Один проход по комнате: все доступные для лута промпты (с полом под ногами, не пустота за картой)
local function ScanLootables(room)
  local list = {}
  for _, desc in ipairs(room:GetDescendants()) do
    if desc:IsA("ProximityPrompt") and desc.Enabled and not KnobFarm.LootedObjects[desc]
      and IsLootablePrompt(desc) then
      local pos = GetInstancePosition(desc.Parent) or GetInstancePosition(desc)
      if pos and HasFloorUnder(pos) then
        list[#list + 1] = { prompt = desc, pos = pos, parent = desc.Parent }
      end
    end
  end
  return list
end

local function NearestLootable(list, fromPos)
  if not fromPos then return nil end
  local best, bestDist = nil, math.huge
  for _, item in ipairs(list) do
    local d = (item.pos - fromPos).Magnitude
    if d < bestDist then
      best, bestDist = item, d
    end
  end
  if best then best.dist = bestDist end
  return best
end

-- Открыть/забрать один промпт и учесть золото
local function LootPrompt(prompt, parent)
  if not prompt or not prompt.Enabled or KnobFarm.LootedObjects[prompt] then return end
  if IsLockedPrompt(prompt) then
    EquipUnlockTool(true)
    task.wait(0.05)
  end
  FirePrompt(prompt, true)
  KnobFarm.LootedObjects[prompt] = true

  local p = parent or prompt.Parent
  if p and (p.Name == "GoldPile" or p.Name == "TinyGold" or p.Name == "Gold" or p:GetAttribute("GoldValue")) then
    KnobFarm.LootedObjects[p] = true
    KnobFarm.RunGold = (KnobFarm.RunGold or 0) + (p:GetAttribute("GoldValue") or 10)
  end
end

-- Забрать всё в радиусе вокруг персонажа (все ящики одной тумбочки + выпавшее золото)
local function LootAround(room, radius, list)
  local root = GetRoot()
  if not root then return 0 end
  list = list or ScanLootables(room)
  local count = 0
  for _, item in ipairs(list) do
    if not KnobFarm.Active or _Unloading then break end
    if not KnobFarm.LootedObjects[item.prompt] and (item.pos - root.Position).Magnitude <= radius then
      LootPrompt(item.prompt, item.parent)
      count = count + 1
    end
  end
  return count
end

local function LootAllInRoom(room)
  if not room or not KnobFarm.Active or _Unloading then return end
  if not GetRoot() then return end

  DisableFireplaces(room)

  -- Сначала всё, что лежит прямо у входа в комнату
  if LootAround(room, 8.0) > 0 then
    task.wait(0.2)
    LootAround(room, 8.0)
  end

  local attempts = 0
  while attempts < 35 and KnobFarm.Active and not _Unloading do
    attempts = attempts + 1
    if ChasePending() then break end

    local root = GetRoot()
    if root and not HasFloorUnder(root.Position, 25) then
      RecoverFromVoid(room)
      break
    end

    -- Жадно берём СТРОГО ближайшую цель от ТЕКУЩЕЙ позиции
    local list = ScanLootables(room)
    local target = NearestLootable(list, root and root.Position)
    if not target then
      break -- всё доступное в комнате собрано
    end

    local label = (target.parent and target.parent.Name) or "Item"
    local reached = target.dist <= 7.0
    if not reached then
      KnobFarm.SetStatus("Looting nearest: " .. label)
      NavigateTo(target.pos, target.parent, label, 4.0, "Loot")
      local r = GetRoot()
      reached = (r ~= nil) and (r.Position - target.pos).Magnitude <= 9.0
    end

    if reached then
      LootPrompt(target.prompt, target.parent)
      LootAround(room, 8.0, list)   -- остальные ящики этой же тумбочки
      task.wait(0.22)               -- анимация открытия и спавн золота внутри
      LootAround(room, 8.0)         -- свежий скан: то, что выпало из ящиков
    else
      -- не дошли (заблокировано мебелью) — помечаем, чтобы не зациклиться
      KnobFarm.LootedObjects[target.prompt] = true
    end

    task.wait(0.04)
  end
end

local THREAT_NAMES = {
  RushMoving = true, Rush = true,
  AmbushMoving = true, Ambush = true,
  BlitzMoving = true, Blitz = true,
  ["RNIUSHCG=="] = true, AR0xMBUSH = true,
  GlitchRush = true, GlitchAmbush = true, FrozenAmbush = true,
}

-- ───────────────────────────── ЗАЩИТА ОТ УГРОЗ / SEEK ─────────────────────────────
-- ВАЖНО: раньше isAtSeek() была «вопросом» с побочными эффектами (меняла InSeekChase,
-- SeekDoorsSkipped, FirstChaseDone) и вызывалась по 4–5 раз за тик из разных мест.
-- Теперь состояние погони меняется ТОЛЬКО в UpdateSeekState(), которую главный цикл
-- вызывает один раз за тик; все остальные читают KnobFarm.InSeekChase.

local function HasEntityThreat()
  if threatState and threatState.ActiveThreats then
    for threat, active in pairs(threatState.ActiveThreats) do
      if active and threat and threat.Parent and THREAT_NAMES[threat.Name] then return true end
    end
  end
  for name in pairs(THREAT_NAMES) do
    if workspace:FindFirstChild(name) then return true end
  end
  return false
end

local SEEK_TRIGGER_NAMES = {
  "TriggerEventCollision", "ChaseStartTrigger", "SeekTrigger",
  "Seeking", "Seek_Arm", "SeekMoving", "SeekMovingNewClone", "SeekRig",
}

-- Рекурсивные FindFirstChild по комнате дорогие, а вызывались каждые 0.04с — кэшируем на 0.5с
local roomCheckCache = setmetatable({}, { __mode = "k" })
local function CachedRoomCheck(room, key, fn)
  if not room then return false end
  local entry = roomCheckCache[room]
  if not entry then
    entry = {}
    roomCheckCache[room] = entry
  end
  local now = tick()
  local e = entry[key]
  if e and now - e.t < 0.5 then return e.v end
  local v = fn(room) and true or false
  entry[key] = { t = now, v = v }
  return v
end

local function RoomHasSeekTrigger(room)
  return CachedRoomCheck(room, "trigger", function(r)
    for _, name in ipairs(SEEK_TRIGGER_NAMES) do
      if r:FindFirstChild(name, true) then return true end
    end
    return false
  end)
end

local function HasSeekEyes(room)
  return CachedRoomCheck(room, "eyes", function(r)
    for _, child in ipairs(r:GetChildren()) do
      if child.Name == "Eye" or child:FindFirstChild("Eye") then return true end
    end
    return r:FindFirstChild("Eye", true) ~= nil
  end)
end

local function MaxSeekDoors(roomNum)
  return ((roomNum or 0) < ROOMS.SECOND_SEEK) and ROOMS.SEEK_DOORS_FIRST or ROOMS.SEEK_DOORS_SECOND
end

local function MarkSeekDone(roomNum)
  if (roomNum or 0) < ROOMS.SECOND_SEEK then
    KnobFarm.FirstChaseDone = true
  else
    KnobFarm.SecondChaseDone = true
  end
  KnobFarm.InSeekChase = false
  KnobFarm.SeekChaseStartRoom = nil
end

-- Единственное место, где живёт машина состояний погони Seek.
-- Возвращает true, пока погоня идёт и нужно пропускать двери.
-- Живой Seek в мире (SeekMovingNewClone на дне карты — это заготовка, а не погоня)
local function SeekEntityNearby()
  local root = GetRoot()
  if not root then return false end
  for _, name in ipairs({ "SeekMoving", "SeekMovingNewClone" }) do
    local seek = workspace:FindFirstChild(name)
    if seek then
      local ok, pivot = pcall(function() return seek:GetPivot().Position end)
      if ok and math.abs(pivot.Y - root.Position.Y) < 60 and (pivot - root.Position).Magnitude < 400 then
        return true
      end
    end
  end
  return false
end

local function UpdateSeekState(room, roomNum)
  local curNum = tonumber(roomNum) or GetLatestRoomNum() or 0
  local curRooms = workspace:FindFirstChild("CurrentRooms")
  local targetRoom = (curRooms and curRooms:FindFirstChild(tostring(curNum))) or room

  -- Погоня каждого типа бывает один раз за забег
  if curNum < ROOMS.SECOND_SEEK and KnobFarm.FirstChaseDone then return false end
  if curNum >= ROOMS.SECOND_SEEK and KnobFarm.SecondChaseDone then return false end

  -- Погоня уже идёт: пропускаем ровно MaxSeekDoors дверей, без досрочного выхода
  if KnobFarm.InSeekChase then
    if (KnobFarm.SeekDoorsSkipped or 0) >= MaxSeekDoors(curNum) then
      MarkSeekDone(curNum)
      return false
    end
    return true
  end

  -- Начало погони: флаг игры или триггеры Seek в комнате
  local gameData = GetGameData()
  local chaseVal = gameData and gameData:FindFirstChild("ChaseInSession")
  -- Погоня началась, когда игра подняла флаг ChaseInSession или Seek реально появился рядом.
  -- Одного триггера в комнате мало: бот входил в режим погони заранее («Skipped 0/7» навсегда) и телепортировался
  -- на уже открытую дверь, пока Seek не появится. Сам триггер бот просто проходит пешком.
  local inChase = (chaseVal ~= nil and chaseVal.Value == true) or SeekEntityNearby()
  if inChase and curNum > 0 then
    KnobFarm.InSeekChase = true
    KnobFarm.SeekDoorsSkipped = 0
    KnobFarm.LastSkippedRoom = curNum
    KnobFarm.SeekChaseStartRoom = curNum
    return true
  end

  return false
end

-- Чистое чтение (без побочных эффектов): рядом Seek? Нужно, чтобы не стоять на месте перед ним
local function IsSeekThreatZone(currentRoom, currentRoomNum)
  if KnobFarm.InSeekChase then return true end
  if HasSeekEyes(currentRoom) or RoomHasSeekTrigger(currentRoom) then return true end
  local curRooms = workspace:FindFirstChild("CurrentRooms")
  local nextRoom = curRooms and currentRoomNum and curRooms:FindFirstChild(tostring(currentRoomNum + 1))
  return nextRoom ~= nil and nextRoom ~= false and (HasSeekEyes(nextRoom) or RoomHasSeekTrigger(nextRoom))
end

local function FindRealSeekDoor(room, roomNum)
  if not room then return nil end
  local targetNum = (roomNum or 0) + 1
  local candidateDoors = {}
  for _, desc in ipairs(room:GetChildren()) do
    if desc.Name == "Door" and desc:IsA("Model") then
      table.insert(candidateDoors, desc)
    end
  end
  if #candidateDoors == 0 then
    for _, desc in ipairs(room:GetDescendants()) do
      if desc.Name == "Door" and desc:IsA("Model") and not desc.Name:lower():find("fake") then
        table.insert(candidateDoors, desc)
      end
    end
  end
  if #candidateDoors == 1 then
    return candidateDoors[1]
  end
  -- При разветвлениях (3 двери Сика) выбираем настоящую по табличке с номером комнаты
  for _, d in ipairs(candidateDoors) do
    local sign = d:FindFirstChild("Sign")
    local txt = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
    if txt and txt.Text == tostring(targetNum) then
      return d
    end
  end
  for _, d in ipairs(candidateDoors) do
    if not d:FindFirstChild("Board") and not d:FindFirstChild("Plank") and not d:FindFirstChild("Barricade") then
      return d
    end
  end
  return candidateDoors[1] or room:FindFirstChild("Door") or room:FindFirstChild("Door", true)
end

local function WaitForThreats(roomNum, room)
  -- Во время Сика или внутри комнат 50/100 (Фигура) никогда не стоим на месте
  if KnobFarm.InSeekChase then return end
  local currentLatest = GetLatestRoomNum() or (roomNum or 0)
  if roomNum == ROOMS.FIGURE or roomNum >= ROOMS.ELEVATOR or currentLatest == ROOMS.FIGURE or currentLatest >= ROOMS.ELEVATOR then return end

  local isThreatZone = IsSeekThreatZone(room, roomNum) or roomNum == ROOMS.LAST_NORMAL or roomNum == ROOMS.IGNORE_TO
  if not isThreatZone then return end

  if HasEntityThreat() and threatState.IsClose(1) then
    KnobFarm.SetStatus("Threat detected (Room " .. tostring(roomNum) .. ")! Waiting...")
    local char = localPlayer and localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum:Move(Vector3.zero, false) end
    while HasEntityThreat() and threatState.IsClose(1.2) and KnobFarm.Active and not _Unloading do
      if hum then hum:Move(Vector3.zero, false) end
      task.wait(0.3)
    end
    task.wait(0.5)
    KnobFarm.SetStatus("Threat gone. Resuming...")
  end
end

local function IsStuck()
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not root then return false end

  if IsUserMovingManually() then
    KnobFarm.LastPosition = root.Position
    KnobFarm.LastMoveTime = tick()
    return false
  end

  local pos = root.Position
  if KnobFarm.LastPosition then
    local moved = (pos - KnobFarm.LastPosition).Magnitude
    if moved < 1.5 then
      if tick() - KnobFarm.LastMoveTime > 3.0 then
        return true
      end
    else
      KnobFarm.LastPosition = pos
      KnobFarm.LastMoveTime = tick()
    end
  else
    KnobFarm.LastPosition = pos
    KnobFarm.LastMoveTime = tick()
  end
  return false
end

local function GetDoorVectors(door, fromPos)
  if not door then return nil, nil, nil, nil end

  local doorCenter = GetDoorCenter(door)
  if not doorCenter then return nil, nil, nil, nil end

  local passDir = nil
  local hidden = door:FindFirstChild("Hidden")
  local room = door.Parent
  local roomExit = room and room:FindFirstChild("RoomExit")

  -- 1. Используем статический LookVector двери DOORS (Hidden или RoomExit)
  if hidden and hidden:IsA("BasePart") then
    local lv = hidden.CFrame.LookVector
    local flat = Vector3.new(lv.X, 0, lv.Z)
    if flat.Magnitude > 0.01 then
      passDir = flat.Unit
    end
  elseif roomExit and roomExit:IsA("BasePart") then
    local lv = roomExit.CFrame.LookVector
    local flat = Vector3.new(lv.X, 0, lv.Z)
    if flat.Magnitude > 0.01 then
      passDir = flat.Unit
    end
  end

  -- 2. Фолбэк: часть Collision
  if not passDir then
    local col = door:FindFirstChild("Collision")
    if col and col:IsA("BasePart") then
      local lv = col.CFrame.LookVector
      local flat = Vector3.new(lv.X, 0, lv.Z)
      if flat.Magnitude > 0.01 then
        passDir = flat.Unit
      end
    end
  end

  -- 3. Фолбэк: вектор движения к двери
  if not passDir then
    local char = localPlayer and localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local pPos = fromPos or (root and root.Position) or doorCenter
    local toDoor = doorCenter - pPos
    if math.abs(toDoor.X) > math.abs(toDoor.Z) then
      passDir = Vector3.new(toDoor.X >= 0 and 1 or -1, 0, 0)
    else
      passDir = Vector3.new(0, 0, toDoor.Z >= 0 and 1 or -1)
    end
  end

  local approachDir = -passDir
  local normal = passDir

  return normal, doorCenter, approachDir, passDir
end

local function GetDoorApproachPosition(doorCenter, door, fromPos)
  if not doorCenter then return doorCenter end
  local _, center, approachDir = GetDoorVectors(door, fromPos)
  if center and approachDir then
    return center + (approachDir * 2.5)
  end
  return doorCenter
end

local function GetDoorThroughPosition(doorCenter, door, fromPos)
  if not doorCenter then return doorCenter end
  local _, center, _, passDir = GetDoorVectors(door, fromPos)
  if center and passDir then
    return center + (passDir * 4.5)
  end
  return doorCenter
end

local function OpenDoor(door)
  if not door then return end
  if door:FindFirstChild("ClientOpen") then
    pcall(function() door.ClientOpen:FireServer() end)
  end
  for _, desc in ipairs(door:GetDescendants()) do
    if desc:IsA("ProximityPrompt") and desc.Enabled then
      FirePrompt(desc, false, true)
    end
  end
end

-- Сходить за ключом комнаты и подобрать его. Раньше этот блок был скопирован
-- в PassDoorStraight и в главный цикл.  waitForSpawn — подождать до 1с, пока ключ появится.
local function FetchRoomKey(room, waitForSpawn)
  local keyObj, keyPos = FindRoomKey(room)
  if not keyObj and waitForSpawn then
    local waitStart = tick()
    while not keyObj and tick() - waitStart < 1.0 and KnobFarm.Active and not _Unloading do
      task.wait(0.2)
      keyObj, keyPos = FindRoomKey(room)
    end
  end
  if not (keyObj and keyPos) then return false end
  local lockId = nil
  do
    local node = keyObj
    while node and node ~= room and not lockId do
      lockId = node:GetAttribute("LockID")
      node = node.Parent
    end
  end

  -- Промпт ключа срабатывает с большого расстояния (FirePrompt расширяет радиус): если ключ рядом, берём его
  -- сразу, не идя через комнату. Иначе бот «бегал» на месте у препятствия и ключ так и не брал.
  local prompt = keyObj:FindFirstChildWhichIsA("ProximityPrompt", true)
  local fromRoot = GetRoot()
  if prompt and fromRoot and (fromRoot.Position - keyPos).Magnitude <= 26 then
    local quick = tick()
    while not HasKeyTool(lockId) and tick() - quick < 1.0 and KnobFarm.Active and not _Unloading do
      if prompt.Enabled then FirePrompt(prompt, false, true) end
      task.wait(0.1)
    end
    if HasKeyTool(lockId) then return true end
  end

  NavigateTo(keyPos, keyObj, "Key", 6.0, "Key")
  local pickStart = tick()
  while not HasKeyTool(lockId) and tick() - pickStart < 2.0 and KnobFarm.Active and not _Unloading do
    if prompt and prompt.Enabled then
      FirePrompt(prompt, false, true)
    end
    task.wait(0.05)
  end

  -- Пешком до ключа не дойти (стена/откат позиции): один раз телепортируемся к нему, берём и возвращаемся к двери.
  -- Без этого бот бесконечно бегал «за ключом» и не мог выйти из комнаты 0.
  if not HasKeyTool(lockId) and KnobFarm.Active and not _Unloading then
    local curRoot = GetRoot()
    if curRoot then
      KnobFarm.SetStatus("Key unreachable on foot - teleporting to it")
      local backCFrame = curRoot.CFrame
      KnobFarm.Teleporting = true
      curRoot.CFrame = CFrame.new((GetFloorPosition(keyPos) or keyPos) + Vector3.new(0, 3, 0))
      curRoot.AssemblyLinearVelocity = Vector3.zero
      task.wait(0.25)
      local grabStart = tick()
      while not HasKeyTool(lockId) and tick() - grabStart < 2.0 and KnobFarm.Active and not _Unloading do
        if prompt and prompt.Enabled then FirePrompt(prompt, false, true) end
        task.wait(0.1)
      end
      curRoot.CFrame = backCFrame
      curRoot.AssemblyLinearVelocity = Vector3.zero
      task.wait(0.15)
      KnobFarm.Teleporting = false
    end
  end
  if HasKeyTool(lockId) then EnsureKeyInHand(lockId) end
  return HasKeyTool(lockId)
end

PassDoorStraight = function(door, root, hum)
  if not door or not root or not hum or hum.Health <= 0 then return end
  if not KnobFarm.Active or _Unloading then return end

  local _, center, _, passDir = GetDoorVectors(door, root.Position)
  if not center or not passDir then return end

  ApplyFarmSpeed(hum)

  if KnobFarm.IgnoredDoors and KnobFarm.IgnoredDoors[door] then return end

  -- 1. Быстрое отпирание ключом/отмычкой, если дверь заперта
  if IsDoorLocked(door) then
    local lockId = door:GetAttribute("RoomID")
    if not HasLockpick() and not HasKeyTool(lockId) then
      KnobFarm.SetStatus("No lockpicks! Picking up key...")
      FetchRoomKey(door.Parent, false)
    end

    KnobFarm.SetStatus(HasKeyTool(lockId) and "Unlocking door with key..." or "Unlocking door with lockpick...")
    EquipUnlockTool(false, lockId)
    local unStart = tick()
    while IsDoorLocked(door) and tick() - unStart < 3.0 and KnobFarm.Active and not _Unloading do
      EquipUnlockTool(false, lockId)
      local _, curPrompt = IsDoorLocked(door)
      if curPrompt and curPrompt.Enabled then
        FirePrompt(curPrompt, true)
      end
      task.wait(0.06)
    end
  end

  -- 2. Открытие створки и нажатие промпта
  OpenDoor(door)
  -- Дверь считаем открытой только если замок реально исчез. Раньше она помечалась открытой всегда:
  -- запертая дверь без ключа/отмычки больше не проверялась на замок, и бот вставал перед ней навсегда.
  local function lockPromptLeft()
    local lock = door:FindFirstChild("Lock")
    return lock ~= nil and lock:FindFirstChildWhichIsA("ProximityPrompt", true) ~= nil and door:GetAttribute("Opened") ~= true
  end
  local stillLocked = lockPromptLeft()
  if stillLocked then
    task.wait(0.15)
    stillLocked = lockPromptLeft()
  end
  if stillLocked then
    KnobFarm.SetStatus("Door is locked - need a key")
    return
  end
  KnobFarm.OpenedDoors[door] = true

  -- 3. Быстрый сквозной импульс вперёд через проём
  local passStart = tick()
  while tick() - passStart < 0.4 and KnobFarm.Active and not _Unloading do
    if (root.Position - center):Dot(passDir) >= 2.5 then
      break
    end
    ApplyFarmSpeed(hum)
    hum:Move(passDir, false)
    task.wait(0.02)
  end

  KnobFarm.PassedFirstDoor = true
end

local function GetRoomTarget(room)
  if not room then return nil, nil, nil end

  local exitDoor = room:FindFirstChild("Door") or room:FindFirstChild("Door", true)
  if not exitDoor then return nil, nil, nil end

  if KnobFarm and KnobFarm.IgnoredDoors and KnobFarm.IgnoredDoors[exitDoor] then
    local otherDoor = nil
    for _, d in ipairs(room:GetChildren()) do
      if d.Name == "Door" and d:IsA("Model") and not KnobFarm.IgnoredDoors[d] then
        otherDoor = d
        break
      end
    end
    if otherDoor then
      exitDoor = otherDoor
    else
      return nil, nil, nil
    end
  end

  local doorCenter = GetDoorCenter(exitDoor)
  if not doorCenter then return nil, nil, nil end

  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  local rootPos = root and root.Position

  local isLocked = IsDoorLocked(exitDoor)
  if isLocked then
    local approachPos = GetDoorApproachPosition(doorCenter, exitDoor, rootPos)
    return exitDoor, GetFloorPosition(approachPos) or approachPos, "Door"
  else
    local throughPos = GetDoorThroughPosition(doorCenter, exitDoor, rootPos)
    return exitDoor, GetFloorPosition(throughPos) or throughPos, "Door"
  end
end

-- Проверка проходимости прямого отрезка между двумя точками с учетом объема персонажа
local function IsDirectPathClear(startPos, endPos, char)
  local rayParams = RaycastParams.new()
  rayParams.FilterType = Enum.RaycastFilterType.Exclude
  rayParams.FilterDescendantsInstances = { char, featureState.HotelNodesFolder }
  local dir = endPos - startPos
  local dist = dir.Magnitude
  if dist < 0.2 then return true end

  local hit = workspace:Blockcast(CFrame.new(startPos + Vector3.new(0, 1.2, 0)), Vector3.new(1.8, 2.0, 1.8), dir, rayParams)
  if hit and hit.Instance and hit.Instance.CanCollide and hit.Instance.Transparency < 0.9 then
    local hitName = hit.Instance.Name:lower()
    local pName = hit.Instance.Parent and hit.Instance.Parent.Name:lower() or ""
    if hitName == "door" or hitName == "collision" or hitName:find("door", 1, true) or pName == "door" then
      return true
    end
    return false
  end
  return true
end
-- Построение пути исключительно перпендикулярными прямыми (вдоль осей X и Z) по середине комнат
local function OrthogonalizeWaypoints(rawPoints, char)
  if not rawPoints or #rawPoints < 2 then return rawPoints end

  local points = {}
  for _, p in ipairs(rawPoints) do
    local pos = (typeof(p) == "Vector3" and p) or (p and p.Position)
    if pos then
      table.insert(points, pos)
    end
  end

  if #points < 2 then return rawPoints end

  local ortho = { points[1] }
  local lastAxis = nil

  for i = 2, #points do
    local pPrev = ortho[#ortho]
    local pCurr = points[i]

    local dx = pCurr.X - pPrev.X
    local dz = pCurr.Z - pPrev.Z
    local absDx = math.abs(dx)
    local absDz = math.abs(dz)

    -- Если точки уже строго на одной оси (погрешность < 0.6 стада)
    if absDx < 0.6 then
      local pt = Vector3.new(pPrev.X, pCurr.Y, pCurr.Z)
      local fPt = GetFloorPosition(pt)
      table.insert(ortho, fPt or pCurr)
      lastAxis = "Z"
    elseif absDz < 0.6 then
      local pt = Vector3.new(pCurr.X, pCurr.Y, pPrev.Z)
      local fPt = GetFloorPosition(pt)
      table.insert(ortho, fPt or pCurr)
      lastAxis = "X"
    else
      -- Диагональ: разбиваем на два строго перпендикулярных отрезка через угол C
      local c1Raw = Vector3.new(pPrev.X, pCurr.Y, pCurr.Z)
      local c2Raw = Vector3.new(pCurr.X, pCurr.Y, pPrev.Z)
      local c1 = GetFloorPosition(c1Raw)
      local c2 = GetFloorPosition(c2Raw)

      local c1Valid = (c1 ~= nil) and IsDirectPathClear(pPrev, c1, char) and IsDirectPathClear(c1, pCurr, char)
      local c2Valid = (c2 ~= nil) and IsDirectPathClear(pPrev, c2, char) and IsDirectPathClear(c2, pCurr, char)

      local chosenCorner = nil
      if c1Valid and not c2Valid then
        chosenCorner = c1
      elseif c2Valid and not c1Valid then
        chosenCorner = c2
      elseif c1Valid and c2Valid then
        if lastAxis == "X" then
          chosenCorner = c2
        else
          chosenCorner = c1
        end
      end

      if chosenCorner then
        table.insert(ortho, chosenCorner)
        table.insert(ortho, Vector3.new(pCurr.X, chosenCorner.Y, pCurr.Z))
        lastAxis = (chosenCorner == c1) and "X" or "Z"
      else
        local fCurr = GetFloorPosition(pCurr)
        table.insert(ortho, fCurr or pCurr)
      end
    end
  end

  -- Слияние последовательных коллинеарных отрезков
  local merged = { ortho[1] }
  for i = 2, #ortho do
    local curr = ortho[i]
    if #merged >= 2 then
      local prev = merged[#merged]
      local prev2 = merged[#merged - 1]

      local sameX = math.abs(prev2.X - prev.X) < 0.2 and math.abs(prev.X - curr.X) < 0.2
      local sameZ = math.abs(prev2.Z - prev.Z) < 0.2 and math.abs(prev.Z - curr.Z) < 0.2

      if sameX or sameZ then
        merged[#merged] = curr
      else
        table.insert(merged, curr)
      end
    else
      table.insert(merged, curr)
    end
  end

  -- Отрезки с промежуточными точками каждые 3.5 стада для равномерного движения без срезания углов
  local dense = {}
  for i = 1, #merged - 1 do
    local pA = merged[i]
    local pB = merged[i + 1]
    table.insert(dense, PathWaypoint.new(pA, Enum.PathWaypointAction.Custom))

    local segDist = (pB - pA).Magnitude
    local stepSize = 3.5
    local steps = math.floor(segDist / stepSize)
    if steps > 1 then
      local stepVec = (pB - pA) / (steps + 1)
      for s = 1, steps do
        local midP = pA + stepVec * s
        table.insert(dense, PathWaypoint.new(midP, Enum.PathWaypointAction.Custom))
      end
    end
  end
  table.insert(dense, PathWaypoint.new(merged[#merged], Enum.PathWaypointAction.Custom))

  local safeDense = {}
  for _, wp in ipairs(dense) do
    if HasFloorUnder(wp.Position, 25) then
      table.insert(safeDense, wp)
    end
  end
  if #safeDense >= 2 then
    return safeDense
  end

  return dense
end

-- Выбор и обработка пути в зависимости от выбранного режима (Straight / Orthogonal)
local function ProcessWaypoints(rawPoints, char)
  if not rawPoints or #rawPoints == 0 then return rawPoints end

  local isOrthogonal = (options and options.AutoFarmMovementMode and options.AutoFarmMovementMode.Value == "Orthogonal")
  if isOrthogonal then
    return OrthogonalizeWaypoints(rawPoints, char)
  end

  -- Прямой способ передвижения (Straight):
  local points = {}
  for _, p in ipairs(rawPoints) do
    local pos = (typeof(p) == "Vector3" and p) or (p and p.Position)
    if pos then
      table.insert(points, pos)
    end
  end

  if #points < 2 then return rawPoints end

  -- Сглаживание пути: соединяем дальние видимые точки по прямой (Raycast shortcut)
  local smoothed = { points[1] }
  local currIdx = 1
  while currIdx < #points do
    local nextIdx = #points
    local found = false
    while nextIdx > currIdx + 1 do
      local pStart = points[currIdx]
      local pEnd = points[nextIdx]
      if IsDirectPathClear(pStart, pEnd, char) and HasFloorUnder(pEnd, 25) then
        found = true
        break
      end
      nextIdx = nextIdx - 1
    end
    if found then
      table.insert(smoothed, points[nextIdx])
      currIdx = nextIdx
    else
      table.insert(smoothed, points[currIdx + 1])
      currIdx = currIdx + 1
    end
  end

  -- Создаем равномерные промежуточные узлы вдоль прямой линии (шаг 4 стада)
  local dense = {}
  for i = 1, #smoothed - 1 do
    local pA = smoothed[i]
    local pB = smoothed[i + 1]
    table.insert(dense, PathWaypoint.new(pA, Enum.PathWaypointAction.Custom))

    local segDist = (pB - pA).Magnitude
    local stepSize = 4.0
    local steps = math.floor(segDist / stepSize)
    if steps > 1 then
      local stepVec = (pB - pA) / (steps + 1)
      for s = 1, steps do
        local midP = pA + stepVec * s
        local fMid = GetFloorPosition(midP) or midP
        if HasFloorUnder(fMid, 25) then
          table.insert(dense, PathWaypoint.new(fMid, Enum.PathWaypointAction.Custom))
        end
      end
    end
  end
  table.insert(dense, PathWaypoint.new(smoothed[#smoothed], Enum.PathWaypointAction.Custom))

  local safeDense = {}
  for _, wp in ipairs(dense) do
    if HasFloorUnder(wp.Position, 25) then
      table.insert(safeDense, wp)
    end
  end
  if #safeDense >= 2 then
    return safeDense
  end

  return dense
end

-- Получение узлов PathfindNodes из комнаты (официальные центральные узлы разработчиков DOORS)
local function GetRoomPathfindNodes(room, rootPos, exitPos)
  if not room then return nil end
  local pfn = room:FindFirstChild("PathfindNodes")
  if not pfn then return nil end
  local children = pfn:GetChildren()
  if #children == 0 then return nil end

  local sorted = {}
  for _, n in ipairs(children) do
    local num = tonumber(n.Name)
    local pos = n:IsA("BasePart") and n.Position or (n:IsA("Model") and n:GetPivot().Position)
    if num and pos then
      table.insert(sorted, { num = num, pos = pos })
    end
  end
  if #sorted == 0 then return nil end
  table.sort(sorted, function(a, b) return a.num < b.num end)

  -- Находим ближайший узел перед игроком
  local bestIdx = 1
  local bestDist = math.huge
  for i, item in ipairs(sorted) do
    local d = (item.pos - rootPos).Magnitude
    if d < bestDist then
      bestDist = d
      bestIdx = i
    end
  end

  local points = { rootPos }
  for i = bestIdx, #sorted do
    table.insert(points, sorted[i].pos)
  end
  if exitPos then
    table.insert(points, exitPos)
  end

  return points
end

-- ───────────────────────────── ИЗБЕГАНИЕ ФИГУРЫ (комнаты 50 и 100) ─────────────────────────────
local FIGURE_HOLD_DIST = 32      -- ближе этого расстояния до Фигуры бот замирает (приседание уже включено)
local FIGURE_RETREAT_DIST = 22   -- ближе этого — активно отходит от неё
local figureInst = nil
local figureSearchAt = 0

local function GetFigurePosition()
  if not (figureInst and figureInst.Parent) then
    figureInst = nil
    local now = tick()
    if now - figureSearchAt < 0.5 then return nil end
    figureSearchAt = now
    figureInst = workspace:FindFirstChild("Figure") or workspace:FindFirstChild("FigureRig")
    if not figureInst then
      local curRooms = workspace:FindFirstChild("CurrentRooms")
      figureInst = curRooms and (curRooms:FindFirstChild("FigureRig", true) or curRooms:FindFirstChild("Figure", true))
    end
  end
  if not figureInst then return nil end
  local part = figureInst:FindFirstChild("HumanoidRootPart") or figureInst:FindFirstChild("Torso")
    or figureInst.PrimaryPart or figureInst:FindFirstChildWhichIsA("BasePart", true)
  return part and part.Position or nil
end

local function FlatDist(a, b)
  local dx, dz = a.X - b.X, a.Z - b.Z
  return math.sqrt(dx * dx + dz * dz)
end

-- Ждать, пока Фигура не отойдёт от точки pos (куда мы собираемся идти/телепортироваться).
-- Если она слишком близко к самому боту — отступаем от неё.
local function WaitFigureClear(pos, timeout)
  local started = tick()
  while KnobFarm.Active and not _Unloading and tick() - started < (timeout or 20) do
    local fp = GetFigurePosition()
    if not fp or not pos or FlatDist(fp, pos) >= FIGURE_HOLD_DIST then return true end

    KnobFarm.SetStatus("Figure near target — waiting...")
    local char = localPlayer and localPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = GetRoot()
    if hum and root then
      local d = FlatDist(fp, root.Position)
      if d < FIGURE_RETREAT_DIST and d > 0.1 then
        ApplyFarmSpeed(hum)   -- отходим на полной скорости, а не стоим
        hum:Move(Vector3.new((root.Position.X - fp.X) / d, 0, (root.Position.Z - fp.Z) / d), false)
      else
        hum:Move(Vector3.zero, false)
      end
    end
    task.wait(0.15)
  end
  return false
end

-- Путь до точки: PathfindingService → иначе прямая. (Раньше параметры агента были
-- скопированы в NavigateTo и в главный цикл.)
local function BuildPathTo(char, startPos, goalPos)
  local waypoints = nil
  local path = pathfindingService:CreatePath({
    AgentCanJump = false,
    AgentCanClimb = false,
    WaypointSpacing = 4,
    AgentRadius = 1.8,
    AgentHeight = 2.0,
    Costs = { StuckPart = 8 },
  })
  local ok = pcall(function()
    path:ComputeAsync(startPos, goalPos)
  end)
  if ok and path.Status == Enum.PathStatus.Success then
    waypoints = ProcessWaypoints(path:GetWaypoints(), char)
  end
  if not waypoints or #waypoints == 0 then
    waypoints = ProcessWaypoints({ startPos, goalPos }, char)
  end
  return waypoints
end

local function WaypointPosition(wp)
  return (typeof(wp) == "Vector3" and wp) or (wp and wp.Position)
end

FollowPath = function(waypoints, target, targetPos, targetType, room, roomNum)
  if not waypoints or #waypoints == 0 then return false end

  -- Одно соединение на весь фарм: «осиротевшее» от прерванного пути отключаем
  if activeMoveConn then
    pcall(function() activeMoveConn:Disconnect() end)
    activeMoveConn = nil
  end

  RenderPathNodes(waypoints)

  local wpIndex = (#waypoints < 2) and 1 or 2
  local finished = false          -- цикл ожидания пора завершать
  local reached = false           -- цель реально достигнута
  local startTime = tick()
  local lastProgressTime = startTime
  local lastNudgeTime = 0
  local lastRootPos = nil
  local currentTargetPoint = targetPos
  local figureHoldAt = 0          -- когда последний раз стояли из-за Фигуры
  local figureHoldTotal = 0

  local startChar = localPlayer and localPlayer.Character
  ApplyFarmSpeed(startChar and startChar:FindFirstChildOfClass("Humanoid"))

  local isOrtho = (options and options.AutoFarmMovementMode and options.AutoFarmMovementMode.Value == "Orthogonal")
  local reachDist = isOrtho and 2.2 or 3.0
  local lookaheadDist = isOrtho and 3.5 or 5.0

  local function dropNode(i)
    local node = currentNodes[i]
    if node and node.Parent then
      pcall(function() node:Destroy() end)
    end
    currentNodes[i] = nil
  end

  -- Рейкасты (лестница, пол впереди) делаем раз в 3 кадра: за 50 мс результат не успевает измениться
  local frameCount, onStairs, groundAhead = 0, false, true

  -- Непрерывное рулевое управление каждый кадр (плавно, без рывков MoveTo)
  local moveConn
  moveConn = runService.RenderStepped:Connect(function()
    if not KnobFarm.Active or _Unloading or IsUserMovingManually() then
      finished = true
      return
    end

    local c = localPlayer and localPlayer.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not c or not root or not h or h.Health <= 0 then
      finished = true
      return
    end

    local rootPos = root.Position

    -- Годмод топит персонажа в пол: подъём/спуск по лестнице в таком состоянии заканчивается падением.
    -- Пока угроза активна, а следующий участок пути идёт по уклону, стоим и ждём, пока она пройдёт.
    if HasActiveThreat() then
      local nextPoint = WaypointPosition(waypoints[wpIndex])
      local prevPoint = WaypointPosition(waypoints[math.max(wpIndex - 1, 1)])
      if nextPoint and prevPoint and math.abs(nextPoint.Y - prevPoint.Y) > 1.0 then
        if not threatState.IsClose(2) then
          -- Угроза далеко (дальше 200 сзади / 100 спереди): поднимаемся без утопления, пока она не приблизилась
          KnobFarm.StairsPass = tick()
        elseif isGodmodeActive() then
          figureHoldAt = tick()
          KnobFarm.SetStatus("Entity active - waiting before the stairs")
          h:Move(Vector3.zero, false)
          return
        end
      end
    end

    -- Фигура рядом: слишком близко — отходим; в зоне осторожности замираем, но только если путь
    -- ведёт К ней. Если маршрут уходит в сторону или от Фигуры, идём дальше (приседание уже включено).
    -- Раньше бот стоял без статуса, пока Фигура бродила в 22–32 студах, даже когда идти нужно было прочь от неё.
    if KnobFarm.AvoidFigure then
      local fp = GetFigurePosition()
      if fp then
        local fd = FlatDist(rootPos, fp)
        if fd < FIGURE_HOLD_DIST then
          if fd < FIGURE_RETREAT_DIST and fd > 0.1 then
            figureHoldAt = tick()
            h:Move(Vector3.new((rootPos.X - fp.X) / fd, 0, (rootPos.Z - fp.Z) / fd), false)
            return
          end
          local heading = WaypointPosition(waypoints[wpIndex]) or targetPos
          local hx, hz = heading.X - rootPos.X, heading.Z - rootPos.Z
          local towardFigure = (hx * (fp.X - rootPos.X) + hz * (fp.Z - rootPos.Z)) > 0
          if towardFigure then
            figureHoldAt = tick()
            KnobFarm.SetStatus("Figure " .. tostring(math.floor(fd / 5) * 5) .. "m away - holding still until it leaves")
            h:Move(Vector3.zero, false)
            return
          end
        end
      end
    end

    -- Продвигаем индекс точки пути (строго по прямым, без срезания углов)
    while wpIndex < #waypoints do
      local curPos = WaypointPosition(waypoints[wpIndex])
      if not curPos then break end
      local dx = curPos.X - rootPos.X
      local dz = curPos.Z - rootPos.Z
      local flatDist = math.sqrt(dx * dx + dz * dz)

      if flatDist < reachDist then
        dropNode(wpIndex)
        wpIndex = wpIndex + 1
      else
        local nextPos = (flatDist < lookaheadDist) and WaypointPosition(waypoints[wpIndex + 1])
        if nextPos and ((rootPos.X - curPos.X) * (nextPos.X - curPos.X)
          + (rootPos.Z - curPos.Z) * (nextPos.Z - curPos.Z)) > 0 then
          dropNode(wpIndex)
          wpIndex = wpIndex + 1
        else
          break
        end
      end
    end

    local curWp = waypoints[wpIndex]
    local targetPoint = WaypointPosition(curWp) or targetPos
    currentTargetPoint = targetPoint

    -- Лестница: гасим физический подброс от ступенек, не прыгаем
    frameCount = frameCount + 1
    local sampleNow = frameCount % 3 == 1
    if sampleNow then
      local _, _, floorPart = HasFloorUnder(rootPos, 4)
      onStairs = IsStairPart(floorPart)
    end
    if onStairs then
      local vel = root.AssemblyLinearVelocity
      if vel.Y > 0.1 then
        root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
      end
    end

    ApplyFarmSpeed(h)

    local steerX = targetPoint.X - rootPos.X
    local steerZ = targetPoint.Z - rootPos.Z
    local steerDist = math.sqrt(steerX * steerX + steerZ * steerZ)

    if steerDist > 0.1 then
      local moveDir = Vector3.new(steerX / steerDist, 0, steerZ / steerDist)
      -- Защита от шага в пустоту
      if sampleNow then groundAhead = HasFloorUnder(rootPos + (moveDir * 2.0), 25) end
      if groundAhead then
        h:Move(moveDir, false)
      else
        h:Move(Vector3.zero, false)
        finished = true
      end
    else
      h:Move(Vector3.zero, false)
    end

    if curWp and typeof(curWp) ~= "Vector3" and curWp.Action == Enum.PathWaypointAction.Jump and not onStairs then
      h.Jump = true
    end

    -- Цель достигнута. Расстояние берём ПЛОСКОЕ: раньше сравнивалось 3D-расстояние от центра
    -- персонажа (~3 стада над полом) до точки НА полу с порогом 2.5 — условие не срабатывало никогда.
    local gx = targetPos.X - rootPos.X
    local gz = targetPos.Z - rootPos.Z
    if math.sqrt(gx * gx + gz * gz) < 2.5 or (wpIndex >= #waypoints and steerDist < 2.0) then
      reached = true
      finished = true
    end
  end)
  activeMoveConn = moveConn

  -- Цикл ожидания: застревание, пустота, крыша, заранее открываем дверь
  local doorAttempts = 0
  local lastDoorTry = 0

  while not finished and KnobFarm.Active and not _Unloading do
    task.wait(0.04)

    if IsUserMovingManually() then
      finished = true
      break
    end

    local c = localPlayer and localPlayer.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local h = c and c:FindFirstChildOfClass("Humanoid")
    if not root or not h or h.Health <= 0 then break end

    local now = tick()

    if ChasePending() then break end

    -- Пока стоим из-за Фигуры — не считаем это застреванием и не тратим таймаут пути
    if now - figureHoldAt < 0.3 then
      figureHoldTotal = figureHoldTotal + 0.05
      lastProgressTime = now
      startTime = startTime + 0.05
      if figureHoldTotal > 45 then break end
    end

    -- Вывалились за карту
    if not HasFloorUnder(root.Position, 25) then
      RecoverFromVoid(room)
      break
    end

    -- Вылетели на крышу (с дебаунсом)
    if HandleRoof(room) then
      break
    end

    -- Застревание. Раньше таймер прогресса сбрасывался при КАЖДОМ срабатывании на 1.8с,
    -- поэтому порог «сдаться через 4.5с» не достигался никогда — бот ждал общие 12с.
    if not lastRootPos or (root.Position - lastRootPos).Magnitude > 1.2 then
      lastRootPos = root.Position
      lastProgressTime = now
    else
      local stalled = now - lastProgressTime
      if stalled > 1.8 and now - lastNudgeTime > 1.0 then
        lastNudgeTime = now
        local _, _, fp = HasFloorUnder(root.Position, 4)
        if not IsStairPart(fp) then
          h.Jump = true
        end
      end
      if stalled > ((targetType == "Loot") and 3.0 or 4.5) then
        if targetType ~= "Loot" then
          KnobFarm.StuckBreaks = (KnobFarm.StuckBreaks or 0) + 1   -- застряли на пути к двери/цели
        end
        break
      end
    end

    -- Общий таймаут пути. Он тоже считается застреванием: бот, который «дёргается» на месте у препятствия,
    -- не попадает под проверку смещения, и раньше этот случай не копил StuckBreaks вообще.
    if now - startTime > 12.0 then
      if targetType ~= "Loot" then
        KnobFarm.StuckBreaks = (KnobFarm.StuckBreaks or 0) + 1
      end
      break
    end

    -- Подходим к двери — заранее открываем/готовим инструмент.
    -- Раньше это выполнялось КАЖДЫЕ 0.04с (≈25 раз/сек: ремоут ClientOpen + все промпты).
    if targetType == "Door" and target and doorAttempts < 3 and now - lastDoorTry > 0.5
      and (targetPos - root.Position).Magnitude < 14.0 then
      lastDoorTry = now
      if IsDoorLocked(target) then
        EquipUnlockTool(false, target:GetAttribute("RoomID"))
      else
        doorAttempts = doorAttempts + 1
        OpenDoor(target)
      end
    end
  end

  pcall(function() moveConn:Disconnect() end)
  if activeMoveConn == moveConn then
    activeMoveConn = nil
  end

  local c = localPlayer and localPlayer.Character
  local h = c and c:FindFirstChildOfClass("Humanoid")
  local root = c and c:FindFirstChild("HumanoidRootPart")

  ClearPathNodes()
  if reached and targetType ~= "Loot" then
    KnobFarm.StuckBreaks = 0
  end

  -- Для двери НИКОГДА не останавливаемся — проходим сквозь проём
  if targetType == "Door" then
    PassDoorStraight(target, root, h)
  elseif h then
    h:Move(Vector3.zero, false)
  end

  return reached and not IsUserMovingManually()
end

-- Возвращает true, только если до цели реально дошли (раньше всегда возвращала true,
-- поэтому «не смогли дойти — пропускаем» в луте не срабатывало никогда)
NavigateTo = function(targetPos, targetInstance, label, maxWaitTime, targetType)
  if not targetPos or not KnobFarm.Active or _Unloading then return false end
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if not root or not hum or hum.Health <= 0 then return false end

  local floorPos = GetFloorPosition(targetPos)
  if not floorPos then
    if not HasFloorUnder(targetPos, 25) then
      KnobFarm.SetStatus("Skipping target: no floor (void)!")
      return false
    end
    floorPos = targetPos
  end
  KnobFarm.SetStatus("Running to " .. (label or "target") .. "...")

  local navWaypoints = BuildPathTo(char, root.Position, floorPos)
  if navWaypoints and #navWaypoints > 1 then
    return FollowPath(navWaypoints, targetInstance, floorPos, targetType or label or "Target", nil, KnobFarm.CurrentRoomNum)
  end

  -- Фолбэк: простой MoveTo
  hum:MoveTo(floorPos)
  local t = tick()
  local timeout = maxWaitTime or 4.0
  while (root.Position - floorPos).Magnitude > 6 and tick() - t < timeout and hum.Health > 0 and KnobFarm.Active and not _Unloading do
    if not HasFloorUnder(root.Position, 25) then
      RecoverFromVoid(nil)
      break
    end
    task.wait(0.1)
  end
  return (root.Position - floorPos).Magnitude <= 6
end

-- Полёт для комнаты 100 (лестницы, на которых ходьба проваливается под карту).
-- Летим по прямой к цели на высоте FLY_CRUISE_HEIGHT над полом ПОД СОБОЙ (на лестнице высота
-- сама следует за ступенями) и снижаемся только в последние FLY_LAND_DIST метров.
-- Это отдельный BodyVelocity, а не тумблер FlyToggle (тот управляется камерой и клавишами).
-- Всё хранится в полях KnobFarm: лимит в 200 локалей на функцию уже почти исчерпан.
local FLY_CRUISE_HEIGHT = 5
local FLY_LAND_DIST = 8

function KnobFarm.StopFly()
  if KnobFarm.FlyConn then
    pcall(function() KnobFarm.FlyConn:Disconnect() end)
    KnobFarm.FlyConn = nil
  end
  if KnobFarm.FlyBody then
    pcall(function() KnobFarm.FlyBody:Destroy() end)
    KnobFarm.FlyBody = nil
  end
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if hum then hum.PlatformStand = false end
  if root then
    root.CanCollide = true   -- полёт отключал коллизию корня, возвращаем
    root.AssemblyLinearVelocity = Vector3.zero
  end
end

-- Возвращает true, если долетели (до 6 студов по плоскости от цели).
function KnobFarm.FlyTo(targetPos, label, timeout)
  if not targetPos or not KnobFarm.Active or _Unloading then return false end
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if not root or not hum or hum.Health <= 0 then return false end

  KnobFarm.StopFly()

  local targetFloor = GetFloorPosition(targetPos)
  local landY = (targetFloor and targetFloor.Y or (targetPos.Y - 2)) + 3   -- центр HRP стоящего персонажа
  local speed = GetFarmSpeed()
  KnobFarm.SetStatus("Flying to " .. (label or "target") .. "...")

  local body = Instance.new("BodyVelocity")
  body.MaxForce = Vector3.new(9e9, 9e9, 9e9)
  body.P = 1e5
  body.Velocity = Vector3.zero
  body.Parent = root
  KnobFarm.FlyBody = body
  hum.PlatformStand = true
  KnobFarm.FlyConn = runService.Stepped:Connect(function()
    root.CanCollide = false
  end)

  local started = tick()
  local arrived = false
  local flat = math.huge
  while tick() - started < (timeout or 30) and KnobFarm.Active and not _Unloading
    and hum.Health > 0 and body.Parent and root.Parent do
    local pos = root.Position
    local dx, dz = targetPos.X - pos.X, targetPos.Z - pos.Z
    flat = math.sqrt(dx * dx + dz * dz)

    local desiredY
    if flat < FLY_LAND_DIST then
      desiredY = landY
    else
      local hasFloor, floorHit = HasFloorUnder(pos, 40)
      desiredY = ((hasFloor and floorHit) and floorHit.Y or (pos.Y - 3)) + FLY_CRUISE_HEIGHT
    end

    if flat <= 2.5 and math.abs(pos.Y - landY) <= 3 then
      arrived = true
      break
    end

    local vy = math.clamp((desiredY - pos.Y) * 5, -speed, speed)
    local hs = math.min(speed, flat * 4 + 2)
    local hx, hz = 0, 0
    if flat > 0.1 then hx, hz = dx / flat * hs, dz / flat * hs end
    body.Velocity = Vector3.new(hx, vy, hz)
    task.wait()
  end

  KnobFarm.StopFly()
  return arrived or flat <= 6
end

-- ═══════════════════════════════════════════════════════════════════
-- BOSS ROOM SOLVERS (Room 50 and Room 100)
-- ═══════════════════════════════════════════════════════════════════

-- Надёжно забрать предмет (книгу/листок): персонаж «дрейфует» и одного
-- нажатия мало. Подходим вплотную, жмём промпт каждые 0.15с и проверяем, что предмет взят.
local function CollectBossItem(item, isDone)
  local pos = (item:IsA("BasePart") and item.Position) or (item:IsA("Model") and item:GetPivot().Position)
  if not pos then return false end
  local started = tick()
  while tick() - started < 5.0 and KnobFarm.Active and not _Unloading do
    if isDone and isDone() then return true end
    local pr = (item:IsA("ProximityPrompt") and item) or item:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not item.Parent or not pr or not pr.Parent or not pr.Enabled then return true end   -- предмет взят

    local fp = GetFigurePosition()
    if fp and FlatDist(fp, pos) < FIGURE_HOLD_DIST then WaitFigureClear(pos, 10) end

    local c = localPlayer and localPlayer.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if h and root then
      local d = FlatDist(root.Position, pos)
      if d > 2.5 then
        h:Move(Vector3.new((pos.X - root.Position.X) / d, 0, (pos.Z - root.Position.Z) / d), false)
      else
        h:Move(Vector3.zero, false)
      end
    end
    FirePrompt(pr, false, true)
    task.wait(0.15)
  end
  local c = localPlayer and localPlayer.Character
  local h = c and c:FindFirstChildOfClass("Humanoid")
  if h then h:Move(Vector3.zero, false) end
  return (isDone ~= nil and isDone()) or false
end

local function handleRoom(room, door)
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if not root or not hum or hum.Health <= 0 then return end

  local curRooms = workspace:FindFirstChild("CurrentRooms")
  local targetRoom = (room and (room.Name == "50" or room:FindFirstChild("LiveHintBook", true)) and room)
    or (curRooms and curRooms:FindFirstChild("50"))
    or room

  -- Вспомогательная функция: есть ли лист у игрока (в руках или в рюкзаке)
  local function hasSheet()
    local c = localPlayer and localPlayer.Character
    local bp = localPlayer and localPlayer:FindFirstChildOfClass("Backpack")
    return (c and (c:FindFirstChild("LibraryHintPaper") or c:FindFirstChild("LibraryHintPaperHard")))
      or (bp and (bp:FindFirstChild("LibraryHintPaper") or bp:FindFirstChild("LibraryHintPaperHard")))
  end

  local sheetWasPresent = hasSheet()

  -- Находим замок библиотеки (если он есть)
  local padlock = (targetRoom and targetRoom:FindFirstChild("Padlock", true))
    or (curRooms and curRooms:FindFirstChild("Padlock", true))
    or (door and door:FindFirstChild("Padlock", true))

  -- Находим дверь 51 (выход из библиотеки в коридор 51)
  local door2 = nil
  if padlock then
    door2 = padlock:FindFirstAncestor("Door")
  end
  if not door2 and targetRoom then
    for _, d in ipairs(targetRoom:GetDescendants()) do
      if d.Name == "Door" and d:IsA("Model") then
        local sign = d:FindFirstChild("Sign")
        local txt = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
        if txt and txt.Text == "51" then
          door2 = d
          break
        end
      end
    end
  end
  if not door2 then
    door2 = targetRoom and targetRoom:FindFirstChild("Door")
  end
  if not door2 then
    door2 = door
  end

  -- Вспомогательная функция: найти дверь 52
  local function findDoor()
    local curR = workspace:FindFirstChild("CurrentRooms")
    if not curR then return nil end
    -- 1. Табличка с цифрой 52
    for _, r in ipairs(curR:GetChildren()) do
      for _, d in ipairs(r:GetDescendants()) do
        if d.Name == "Door" and d:IsA("Model") then
          local sign = d:FindFirstChild("Sign")
          local txt = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
          if txt and txt.Text == "52" then return d end
        end
      end
    end
    -- 2. Выходная дверь комнаты 51
    local r51 = curR:FindFirstChild("51")
    if r51 then
      local d51Exit = r51:FindFirstChild("Door")
      if d51Exit and d51Exit ~= door2 then return d51Exit end
      for _, d in ipairs(r51:GetDescendants()) do
        if d.Name == "Door" and d:IsA("Model") and d ~= door2 then return d end
      end
    end
    -- 3. Комната 52
    local r52 = curR:FindFirstChild("52")
    if r52 then
      local d52Door = r52:FindFirstChild("Door")
      if d52Door then return d52Door end
    end
    return nil
  end

  -- Если замок уже открыт/исчез — НЕ ищем книги и не идем за листом назад, сразу к выходу!
  local isAlreadyOpened = (not padlock or not padlock.Parent)

  if not isAlreadyOpened then
    -- 1. Настройки для комнаты 50
    KnobFarm.DisableGodmodeForBoss = true
    pcall(function()
      if toggles and toggles.Godmode and toggles.Godmode.Value then
        toggles.Godmode:SetValue(false)
      end
    end)
    SetCrouched(true)
    KnobFarm.Teleporting = false
    KnobFarm.AvoidFigure = true

    -- Хелпер поиска Фигуры
    local function getFigurePos()
      return GetFigurePosition()
    end

    -- 2. Находим книги (LiveHintBook) и идем к каждой по полу
    KnobFarm.SetStatus("Room 50: Finding Books...")
    local books = {}
    if targetRoom then
      for _, desc in ipairs(targetRoom:GetDescendants()) do
        if desc.Name == "LiveHintBook" then
          table.insert(books, desc)
        end
      end
    end
    if #books == 0 and curRooms then
      for _, desc in ipairs(curRooms:GetDescendants()) do
        if desc.Name == "LiveHintBook" then
          table.insert(books, desc)
        end
      end
    end

    while KnobFarm.Active and not _Unloading and PlayerAlive() do
      -- Если замок открылся или лист пропал во время сбора книг — немедленно выходим к двери
      if (sheetWasPresent and not hasSheet()) or (padlock and not padlock.Parent) then
        break
      end

      local unlooted = {}
      for _, b in ipairs(books) do
        if not KnobFarm.LootedObjects[b] and b.Parent then
          table.insert(unlooted, b)
        end
      end
      if #unlooted == 0 then break end

      local figPos = getFigurePos()
      table.sort(unlooted, function(a, b)
        local posA = (a:IsA("BasePart") and a.Position) or (a:IsA("Model") and a:GetPivot().Position) or Vector3.zero
        local posB = (b:IsA("BasePart") and b.Position) or (b:IsA("Model") and b:GetPivot().Position) or Vector3.zero
        local distA = figPos and (posA - figPos).Magnitude or 100
        local distB = figPos and (posB - figPos).Magnitude or 100
        return distA > distB
      end)

      local targetBook = unlooted[1]
      local bPos = (targetBook:IsA("BasePart") and targetBook.Position)
        or (targetBook:IsA("Model") and targetBook:GetPivot().Position)
      if not bPos then
        KnobFarm.LootedObjects[targetBook] = true
      else
        WaitFigureClear(bPos, 15)

        KnobFarm.SetStatus("Room 50: Walking to Book (avoiding Figure)...")
        local floorPos = GetFloorPosition(bPos) or bPos
        if NavigateTo then
          NavigateTo(floorPos, targetBook, "LiveHintBook", 8.0, "Loot")
        end

        local curChar = localPlayer and localPlayer.Character
        local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")
        local dist = curRoot and (curRoot.Position - bPos).Magnitude or 999

        if dist <= 14.0 then
          CollectBossItem(targetBook)
          KnobFarm.LootedObjects[targetBook] = true
          KnobFarm.SetStatus("Room 50: Book collected! Waiting 0.65s...")
          task.wait(0.65)
        else
          KnobFarm.LootedObjects[targetBook] = true
        end
      end
    end

    -- 3. Идет за листочком по полу (только если лист еще не у игрока и замок закрыт)
    local needPaper = not hasSheet() and (padlock and padlock.Parent)
    if needPaper then
      KnobFarm.SetStatus("Room 50: Walking to Hint Paper...")
      local paper = (targetRoom and targetRoom:FindFirstChild("LibraryHintPaper", true))
        or (curRooms and curRooms:FindFirstChild("LibraryHintPaper", true))
        or (targetRoom and targetRoom:FindFirstChild("PickupItem", true))
      if not paper and targetRoom then
        for _, pr in ipairs(targetRoom:GetDescendants()) do
          if pr:IsA("ProximityPrompt") and pr.ObjectText:lower():find("paper", 1, true) then
            paper = pr.Parent
            break
          end
        end
      end

      if paper then
        local pPos = (paper:IsA("BasePart") and paper.Position) or (paper:IsA("Model") and paper:GetPivot().Position)
        if pPos then
          local floorPos = GetFloorPosition(pPos) or pPos
          WaitFigureClear(pPos, 15)
          if NavigateTo then
            NavigateTo(floorPos, paper, "Hint Paper", 8.0, "Loot")
          end

          local curChar = localPlayer and localPlayer.Character
          local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")
          local dist = curRoot and (curRoot.Position - pPos).Magnitude or 999

          if dist <= 14.0 then
            CollectBossItem(paper, function() return hasSheet() end)
            KnobFarm.LootedObjects[paper] = true
            task.wait(0.3)

            -- Берет листочек в руки (EquipTool)
            local bp = localPlayer:FindFirstChildOfClass("Backpack")
            local paperTool = (curChar and (curChar:FindFirstChild("LibraryHintPaper") or curChar:FindFirstChild("LibraryHintPaperHard")))
              or (bp and (bp:FindFirstChild("LibraryHintPaper") or bp:FindFirstChild("LibraryHintPaperHard")))
            if paperTool and hum and paperTool.Parent ~= curChar then
              pcall(function() hum:EquipTool(paperTool) end)
              task.wait(0.3)
            end
          end
        end
      end
    end

    if hasSheet() then
      sheetWasPresent = true
    end

    -- 4. Идет к двери / замку по полу
    local padPart = (padlock and padlock:IsA("BasePart") and padlock)
      or (padlock and padlock:FindFirstChildWhichIsA("BasePart", true))
      or (door2 and door2:FindFirstChild("Door"))
      or (door2 and door2.PrimaryPart)

    if padPart and padlock and padlock.Parent then
      KnobFarm.SetStatus("Room 50: Walking to Door / Padlock...")
      local padPos = (padPart:IsA("BasePart") and padPart.Position) or padPart:GetPivot().Position
      local floorPos = GetFloorPosition(padPos) or padPos
      WaitFigureClear(padPos, 20)
      if NavigateTo then
        NavigateTo(floorPos, padPart, "Door Padlock", 10.0, "Door")
      end
      task.wait(0.3)
    end

    -- 5. Решение кодового замка
    if padlock and padlock.Parent then
      local code = Functions and Functions.GetLibraryCode and Functions.GetLibraryCode()
      if code and remotesFolder and remotesFolder:FindFirstChild("PL") then
        if not string.find(code, "_") and code ~= "_____" then
          remotesFolder.PL:FireServer(code)
        else
          task.spawn(function()
            local function brute(s)
              local idx = string.find(s, "_")
              if not idx then
                pcall(function() remotesFolder.PL:FireServer(s) end)
                task.wait(0.02)
                return
              end
              for d = 0, 9 do
                local newS = string.sub(s, 1, idx - 1) .. tostring(d) .. string.sub(s, idx + 1)
                brute(newS)
              end
            end
            brute(code)
          end)
        end
      end

      -- Ждем пока замок откроется ИЛИ пока лист пропадет из инвентаря
      local t = tick()
      while KnobFarm.Active and not _Unloading and (tick() - t < 12) do
        if sheetWasPresent and not hasSheet() then
          KnobFarm.SetStatus("Room 50: Sheet consumed! Lock opened.")
          break
        end
        if not padlock or not padlock.Parent then
          KnobFarm.SetStatus("Room 50: Padlock opened/removed!")
          break
        end
        task.wait(0.15)
      end
    end
  end

  -- 6. Открытие 51 двери и проход сквозь неё строго ВПЕРЕД в комнату 51
  KnobFarm.SetStatus("Room 50: Opening Door 51...")
  if door2 then
    if OpenDoor then
      pcall(function() OpenDoor(door2) end)
    else
      local co = door2:FindFirstChild("ClientOpen")
      if co then pcall(function() co:FireServer() end) end
      local pr = door2:FindFirstChildWhichIsA("ProximityPrompt", true)
      if pr then pcall(safeFirePrompt, pr) end
    end
    pcall(function()
      for _, dp in ipairs(door2:GetDescendants()) do
        if dp:IsA("BasePart") then dp.CanCollide = false end
      end
    end)
  end

  -- В коридоре перед магазином Джеффа (51–55) выключаем Phantom Noclip,
  -- чтобы бот не застревал в одной точке
  pcall(function()
    if toggles and toggles.Godmode and not toggles.Godmode.Value then
      toggles.Godmode:SetValue(true)
    end
    if toggles and toggles.PhantomNoclip and toggles.PhantomNoclip.Value then
      KnobFarm.NoclipBeforeJeff = true
      toggles.PhantomNoclip:SetValue(false)
    else
      KnobFarm.NoclipBeforeJeff = true
    end
  end)

  -- Проходим сквозь дверной проем 51 строго вперед (к коридору 51, никогда не назад!)
  local curChar = localPlayer and localPlayer.Character
  local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")
  local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
  if curRoot and curHum then
    local d51Center = GetDoorCenter(door2)
    local passDir = nil
    local hidden = door2 and door2:FindFirstChild("Hidden")
    local flatToDoor = d51Center and Vector3.new(d51Center.X - curRoot.Position.X, 0, d51Center.Z - curRoot.Position.Z)
    local approachDir = (flatToDoor and flatToDoor.Magnitude > 0.5) and flatToDoor.Unit or nil

    if hidden and hidden:IsA("BasePart") then
      local lv = hidden.CFrame.LookVector
      local flatLv = Vector3.new(lv.X, 0, lv.Z).Unit
      if approachDir and flatLv:Dot(approachDir) < 0 then
        passDir = -flatLv
      else
        passDir = flatLv
      end
    end
    if not passDir then
      passDir = approachDir or Vector3.new(0, 0, -1)
    end

    KnobFarm.SetStatus("Room 50: Passing Door 51 into Room 51...")
    local passStart = tick()
    while tick() - passStart < 2.5 and KnobFarm.Active and not _Unloading do
      local passedDot = d51Center and ((curRoot.Position - d51Center):Dot(passDir)) or 5
      if passedDot >= 4.0 then break end
      ApplyFarmSpeed(curHum)
      curHum:Move(passDir, false)
      pcall(function()
        local cam = workspace.CurrentCamera
        if cam then
          cam.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + passDir)
        end
      end)
      task.wait(0.04)
    end
    if curHum then curHum:Move(Vector3.zero, false) end
  end

  -- 7. Идем к двери 52 через NavigateTo (обычный фарм пешком)
  local door3 = nil
  local findStart = tick()
  while tick() - findStart < 3.0 and not door3 and KnobFarm.Active and not _Unloading do
    door3 = findDoor()
    if door3 then break end
    task.wait(0.15)
  end

  if door3 then
    local d52Part = door3:FindFirstChild("Door") or door3.PrimaryPart
      or door3:FindFirstChildWhichIsA("BasePart", true)
    if d52Part and NavigateTo then
      KnobFarm.SetStatus("Walking to Door 52...")
      local d52Pos = d52Part.Position
      local floorPos = GetFloorPosition(d52Pos) or d52Pos
      NavigateTo(floorPos, d52Part, "Door 52", 10.0, "Door")

      -- Открываем дверь 52
      if OpenDoor then
        pcall(function() OpenDoor(door3) end)
      else
        local proximityPrompt = door3:FindFirstChildWhichIsA("ProximityPrompt", true)
        if proximityPrompt then pcall(safeFirePrompt, proximityPrompt) end
        local clientOpen = door3:FindFirstChild("ClientOpen")
        if clientOpen then pcall(function() clientOpen:FireServer() end) end
      end
      pcall(function()
        for _, dp in ipairs(door3:GetDescendants()) do
          if dp:IsA("BasePart") then dp.CanCollide = false end
        end
      end)
      KnobFarm.OpenedDoors[door3] = true
    end
  end

  -- УДАЛЯЕМ ИЗ ПАМЯТИ 51-УЮ ДВЕРЬ
  KnobFarm.IgnoredDoors = KnobFarm.IgnoredDoors or setmetatable({}, { __mode = "k" })
  if door2 then
    KnobFarm.OpenedDoors[door2] = true
    KnobFarm.IgnoredDoors[door2] = true
  end

  -- Запоминаем текущую комнату как минимум 51/52, чтобы бот никогда не шел назад в 50
  if door3 and KnobFarm.OpenedDoors and KnobFarm.OpenedDoors[door3] then
    KnobFarm.CurrentRoomNum = 52
    KnobFarm.LastRoomNum = 52
  else
    KnobFarm.CurrentRoomNum = 51
    KnobFarm.LastRoomNum = 51
  end
  KnobFarm.PassedFirstDoor = true
  SetCrouched(false)
  KnobFarm.DisableGodmodeForBoss = false
  KnobFarm.AvoidFigure = false
  KnobFarm.Teleporting = false

  -- В коридоре перед магазином Джеффа (51–55) выключаем Phantom Noclip,
  -- чтобы бот не застревал в одной точке
  pcall(function()
    if toggles and toggles.Godmode and not toggles.Godmode.Value then
      toggles.Godmode:SetValue(true)
    end
    if toggles and toggles.PhantomNoclip and toggles.PhantomNoclip.Value then
      KnobFarm.NoclipBeforeJeff = true
      toggles.PhantomNoclip:SetValue(false)
    else
      KnobFarm.NoclipBeforeJeff = true
    end
  end)
  KnobFarm.SetStatus("Room 50 completed! Resuming Knob Farm...")
  task.wait(0.5)
end

-- Комната 100: щитовая, лифт и конец забега
local function SolveRoom100(room)
  local char = localPlayer and localPlayer.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if not root or not hum or hum.Health <= 0 then return end

  local curRooms = workspace:FindFirstChild("CurrentRooms")
  local targetRoom = (room and (room.Name == "100" or room:FindFirstChild("ElevatorBreaker", true)) and room)
    or (curRooms and curRooms:FindFirstChild("100"))
    or room

  -- 0. Ожидание угроз перед входом
  if HasEntityThreat() and threatState.IsClose(1) then
    KnobFarm.SetStatus("Room 100: Threat detected! Waiting...")
    while HasEntityThreat() and threatState.IsClose(1.2) and hum and hum.Health > 0 and KnobFarm.Active and not _Unloading and PlayerAlive() do
      task.wait(0.3)
    end
    task.wait(0.5)
  end

  -- Подготовка: отключаем годмод для босса
  KnobFarm.DisableGodmodeForBoss = true
  SetFeature("Godmode", false)

  SetCrouched(true)
  KnobFarm.Teleporting = false
  KnobFarm.AvoidFigure = true

  -- Ожидание загрузки объектов комнаты 100 (до 3 сек)
  local loadStart = tick()
  while tick() - loadStart < 3.0 and KnobFarm.Active and not _Unloading and PlayerAlive() do
    local f = targetRoom and (targetRoom:FindFirstChild("FusePickup", true) or targetRoom:FindFirstChild("ElevatorBreaker", true))
    if f then break end
    task.wait(0.2)
  end

  -- 1. Сбор всех предохранителей / рубильников (fuses / breaker switches) пешком в ноуклипе
  KnobFarm.SetStatus("Room 100: Finding Breaker Switches & Fuses...")

  local function getFuses()
    local items = {}
    local seen = {}
    local searchContainers = { targetRoom, curRooms and curRooms:FindFirstChild("100") }
    for _, container in ipairs(searchContainers) do
      if container then
        for _, desc in ipairs(container:GetDescendants()) do
          local isFuse = desc.Name == "FusePickup" or desc.Name == "FuseObtain" or desc.Name == "Fuse"
            or desc.Name == "LiveBreakerPolePickup" or desc.Name == "Breaker Switch" or desc.Name == "BreakerSwitch"
          if not isFuse and desc:IsA("ProximityPrompt") then
            local ot = (desc.ObjectText or ""):lower()
            local at = (desc.ActionText or ""):lower()
            if ot:find("fuse", 1, true) or at:find("fuse", 1, true) or ot:find("breaker", 1, true) or at:find("switch", 1, true) then
              isFuse = true
            end
          end
          if isFuse then
            local inst = desc:IsA("ProximityPrompt") and desc.Parent or desc
            if inst and not seen[inst] and not KnobFarm.LootedObjects[inst] and inst.Parent then
              seen[inst] = true
              table.insert(items, inst)
            end
          end
        end
      end
    end
    return items
  end

  -- Объекты комнаты могут подгружаться не сразу: пока предохранителей нет — ждём (до 8 секунд)
  local searchStart = tick()
  while #getFuses() == 0 and tick() - searchStart < 8.0 and KnobFarm.Active and not _Unloading and PlayerAlive() do
    KnobFarm.SetStatus("Room 100: Waiting for fuses to load...")
    task.wait(0.5)
  end
  if #getFuses() == 0 then
    KnobFarm.SetStatus("Room 100: No fuses found, continuing...")
  end

  local fuseStart = tick()
  while KnobFarm.Active and not _Unloading and PlayerAlive() and (tick() - fuseStart < 90) do
    local unlooted = getFuses()
    if #unlooted == 0 then break end

    local figPos = GetFigurePosition()
    table.sort(unlooted, function(a, b)
      local posA = (a:IsA("BasePart") and a.Position) or (a:IsA("Model") and a:GetPivot().Position) or Vector3.zero
      local posB = (b:IsA("BasePart") and b.Position) or (b:IsA("Model") and b:GetPivot().Position) or Vector3.zero
      local distA = figPos and FlatDist(posA, figPos) or 100
      local distB = figPos and FlatDist(posB, figPos) or 100
      return distA > distB
    end)

    local targetFuse = unlooted[1]
    local fPos = (targetFuse:IsA("BasePart") and targetFuse.Position)
      or (targetFuse:IsA("Model") and targetFuse:GetPivot().Position)
    if not fPos then
      KnobFarm.LootedObjects[targetFuse] = true
    else
      WaitFigureClear(fPos, 15)
      KnobFarm.SetStatus("Room 100: Walking to Fuse/Switch (avoiding Figure)...")
      local floorPos = GetFloorPosition(fPos) or fPos
      KnobFarm.FlyTo(floorPos, "Fuse")

      local curChar = localPlayer and localPlayer.Character
      local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")
      local dist = curRoot and (curRoot.Position - fPos).Magnitude or 999
      if dist <= 14.0 then
        CollectBossItem(targetFuse)
        task.wait(0.2)
        KnobFarm.LootedObjects[targetFuse] = true
      end
      -- Если бот не дошёл до предохранителя (dist > 14), НЕ помечаем его как собранный:
      -- следующая итерация while-цикла снова попытается подойти к нему
    end
  end

  -- 2. Сначала собираем ВСЁ нужное: после предохранителей — ключ от щитовой (вверх по лестнице), избегая Фигуру
  local elecKey = (targetRoom and (targetRoom:FindFirstChild("ElectricalKeyObtain", true) or targetRoom:FindFirstChild("KeyElectrical", true)
    or targetRoom:FindFirstChild("Electrical Key", true) or targetRoom:FindFirstChild("ElectricalRoomKey", true)))
    or (curRooms and (curRooms:FindFirstChild("ElectricalKeyObtain", true) or curRooms:FindFirstChild("KeyElectrical", true)))

  if elecKey then
    KnobFarm.SetStatus("Room 100: Walking up stairs to Electrical Key...")
    local kPos = (elecKey:IsA("BasePart") and elecKey.Position) or (elecKey:IsA("Model") and elecKey:GetPivot().Position)
    if kPos then
      WaitFigureClear(kPos, 20)
      local floorPos = GetFloorPosition(kPos) or kPos
      KnobFarm.FlyTo(floorPos, "Electrical Key")

      local curChar = localPlayer and localPlayer.Character
      local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")
      local dist = curRoot and (curRoot.Position - kPos).Magnitude or 999
      if dist <= 14.0 then
        CollectBossItem(elecKey)
        task.wait(0.2)
      end

      -- Берем ключ в руки
      local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
      local keyTool = FindTool("KeyElectrical", "ElectricalKeyObtain")
      if keyTool and curHum and keyTool.Parent ~= curChar then
        pcall(function() curHum:EquipTool(keyTool) end)
        task.wait(0.2)
      end
    end
  end

  -- 3. Только теперь, когда всё собрано, идём к воротам и дёргаем рычаг (Gate Lever)
  local lever = (targetRoom and (targetRoom:FindFirstChild("LeverForGate", true) or targetRoom:FindFirstChild("Lever", true)))
    or (curRooms and (curRooms:FindFirstChild("LeverForGate", true) or curRooms:FindFirstChild("Lever", true)))
  if lever then
    KnobFarm.SetStatus("Room 100: Walking to Gate Lever...")
    local lPos = (lever:IsA("BasePart") and lever.Position) or (lever:IsA("Model") and lever:GetPivot().Position)
    if lPos then
      WaitFigureClear(lPos, 15)
      local floorPos = GetFloorPosition(lPos) or lPos
      KnobFarm.FlyTo(floorPos, "Gate Lever")
      WaitFigureClear(lPos, 15)   -- Фигура подошла, пока шли — ждём, пока отойдёт
      local lPr = (lever:IsA("ProximityPrompt") and lever) or lever:FindFirstChildWhichIsA("ProximityPrompt", true)
      if lPr then
        FirePrompt(lPr, false, true)
      end
      task.wait(0.4)
    end
  end

  -- Перед щитовой убеждаемся, что ключ в руках (после рычага он мог остаться в рюкзаке)
  do
    local character2 = localPlayer and localPlayer.Character
    local humanoid2 = character2 and character2:FindFirstChildOfClass("Humanoid")
    local keyElectrical = FindTool("KeyElectrical", "ElectricalKeyObtain")
    if keyElectrical and humanoid2 and keyElectrical.Parent ~= character2 then
      pcall(function() humanoid2:EquipTool(keyElectrical) end)
      task.wait(0.2)
    end
  end

  -- 4. С ключом идет к двери щитовой (Electrical Door), отпирает её и идет к Breaker Box
  local elecLock = (targetRoom and (targetRoom:FindFirstChild("KeyElectrical", true) or targetRoom:FindFirstChild("ElectricalLock", true)))
    or (curRooms and (curRooms:FindFirstChild("KeyElectrical", true) or curRooms:FindFirstChild("ElectricalLock", true)))
  local elecDoor = (targetRoom and targetRoom:FindFirstChild("ElectricalDoor", true))
    or (elecLock and elecLock:FindFirstAncestorWhichIsA("Model"))

  if elecLock or elecDoor then
    local lockPart = (elecLock and elecLock:IsA("BasePart") and elecLock)
      or (elecLock and elecLock:FindFirstChildWhichIsA("BasePart", true))
      or (elecDoor and elecDoor:FindFirstChildWhichIsA("BasePart", true))
    if lockPart then
      KnobFarm.SetStatus("Room 100: Walking to Electrical Door...")
      local lPos = lockPart.Position
      WaitFigureClear(lPos, 20)
      local floorPos = GetFloorPosition(lPos) or lPos
      KnobFarm.FlyTo(floorPos, "Electrical Door")
      WaitFigureClear(lPos, 15)
      local lockPrompt = (elecLock and elecLock:FindFirstChildWhichIsA("ProximityPrompt", true))
        or (elecDoor and elecDoor:FindFirstChildWhichIsA("ProximityPrompt", true))
      if lockPrompt and lockPrompt.Enabled then
        FirePrompt(lockPrompt, false, true)
      end
      task.wait(0.4)
    end
  end

  local breaker = (targetRoom and targetRoom:FindFirstChild("ElevatorBreaker", true))
    or (curRooms and curRooms:FindFirstChild("ElevatorBreaker", true))
    or workspace:FindFirstChild("ElevatorBreaker")

  if breaker then
    KnobFarm.SetStatus("Room 100: Walking to Breaker Panel...")
    local bPos = (breaker:IsA("BasePart") and breaker.Position) or (breaker:IsA("Model") and breaker:GetPivot().Position)
    if bPos then
      WaitFigureClear(bPos, 20)
      local floorPos = GetFloorPosition(bPos) or bPos
      KnobFarm.FlyTo(floorPos, "Breaker Panel")

      WaitFigureClear(bPos, 15)
      -- Вставляем собранные предохранители в щиток
      local insertStart = tick()
      while tick() - insertStart < 3.0 and KnobFarm.Active and not _Unloading and PlayerAlive() do
        local hadPrompt = false
        for _, bPr in ipairs(breaker:GetDescendants()) do
          if bPr:IsA("ProximityPrompt") and bPr.Enabled then
            hadPrompt = true
            FirePrompt(bPr, false, false)
          end
        end
        if not hadPrompt then break end
        task.wait(0.2)
      end
      task.wait(0.3)
    end
  end

  -- 5. Мгновенно проходит щиток с помощью эксплоита
  KnobFarm.SetStatus("Room 100: Solving Breaker Box with exploit...")
  SetFeature("AutoBreakerBox", true)
  SetFeature("BreakerBoxMethod", "Instant", true)

  -- Щиток считается решённым, когда у лифта появляется TouchInterest (так же это ловит сам эксплоит).
  -- Раньше бот стрелял EBF 3,5 секунды и уходил в лифт, даже если на панели было «06» — то есть не дождавшись решения.
  local function findElevator()
    return (targetRoom and (targetRoom:FindFirstChild("ElevatorCar", true) or targetRoom:FindFirstChild("Elevator", true)))
      or (curRooms and (curRooms:FindFirstChild("ElevatorCar", true) or curRooms:FindFirstChild("Elevator", true)))
      or workspace:FindFirstChild("ElevatorCar")
  end
  local function breakerSolved()
    local car = findElevator()
    return car ~= nil and car:FindFirstChild("TouchInterest", true) ~= nil
  end

  local solveWait = tick()
  while tick() - solveWait < 45 and KnobFarm.Active and not _Unloading and PlayerAlive() and not breakerSolved() do
    -- встроенный Instant-режим (реагирует на смену кода на панели) + прямой EBF на случай, если код не менялся
    if featureState.RunBreakerFunc then pcall(featureState.RunBreakerFunc) end
    if remotesFolder and remotesFolder:FindFirstChild("EBF") then
      pcall(function() remotesFolder.EBF:FireServer() end)
    end
    task.wait(0.5)
  end
  if breakerSolved() then
    KnobFarm.SetStatus("Room 100: Breaker box solved")
  else
    KnobFarm.SetStatus("Room 100: Breaker box not confirmed, continuing")
  end

  -- 6. Телепортируется в лифт (ElevatorCar)
  local elevator = (targetRoom and (targetRoom:FindFirstChild("ElevatorCar", true) or targetRoom:FindFirstChild("Elevator", true)))
    or (curRooms and (curRooms:FindFirstChild("ElevatorCar", true) or curRooms:FindFirstChild("Elevator", true)))
    or workspace:FindFirstChild("ElevatorCar")

  if elevator then
    KnobFarm.SetStatus("Room 100: Teleporting into Elevator...")
    KnobFarm.Teleporting = true
    SetCrouched(false)
    local ePos = elevator:GetPivot().Position
    local curChar = localPlayer and localPlayer.Character
    local curRoot = curChar and curChar:FindFirstChild("HumanoidRootPart")
    if curRoot then
      curRoot.CFrame = CFrame.new(ePos + Vector3.new(0, 2.0, 0))
      curRoot.AssemblyLinearVelocity = Vector3.zero
    end
    local ePr = elevator:FindFirstChildWhichIsA("ProximityPrompt", true)
    if ePr then
      FirePrompt(ePr, false, false)
    end
  end

  if not PlayerAlive() then return end

  -- 7. Завершение игры: ждем результатов и нажимаем Play Again
  KnobFarm.SetStatus("Game Completed! Waiting for results...")
  task.wait(6.0)
  RecordRunStats()
  KnobFarm.SetStatus("Game Completed! Waiting for Play Again...")
  task.wait(4.0)
  RequestPlayAgain()
end

-- ═══════════════════════════════════════════════════════════════════
-- ГЛАВНЫЙ ЦИКЛ
-- Раньше это была одна ~450-строчная функция внутри одного pcall: любая ошибка (nil-индекс
-- на редкой комнате) навсегда убивала поток, а тумблер продолжал показывать «включено».
-- Теперь: небольшие шаги, каждый возвращает true, если «забрал» тик, а pcall стоит
-- на КАЖДОМ тике — ошибка логируется, и фарм продолжает работать (важно для ночного AFK).
-- ═══════════════════════════════════════════════════════════════════

local lastDeathHumanoid = nil
local lastPlayAgainAt = 0

-- 1. Смерть. Обрабатываем РОВНО ОДИН РАЗ на персонажа: раньше после ResetFarmState флаг
-- «статистика записана» сбрасывался, а мёртвый персонаж ещё держался до телепорта —
-- и цикл записывал ещё один «забег» (раздувал счётчик Runs) и снова ждал 10 секунд.
local function StepDeath(hum)
  if hum.Health > 0 then return false end

  if lastDeathHumanoid ~= hum then
    lastDeathHumanoid = hum
    KnobFarm.SetStatus("Dead. Waiting for results...")
    task.wait(6.0)
    RecordRunStats()
    KnobFarm.SetStatus("Dead. Waiting for Play Again...")
    task.wait(4.0)
    if RequestPlayAgain() then lastPlayAgainAt = tick() end
    ResetFarmState()
  elseif tick() - lastPlayAgainAt > 15 then
    -- первый Play Again не сработал — повторяем
    if RequestPlayAgain() then lastPlayAgainAt = tick() end
  end

  task.wait(1.0)
  return true
end

-- 2. Лобби / ожидание комнат.
-- Раньше тут КАЖДУЮ секунду вызывался ResetFarmState(), который сразу стирал только что
-- запомненный StartKnobs и флаг LockpickBoughtThisRun (его выставляет покупка в пред-ранном
-- магазине) — из-за этого статистика всегда считалась неверно.
local function StepLobby()
  local roomsFolder = workspace:FindFirstChild("CurrentRooms")
  if roomsFolder and #roomsFolder:GetChildren() > 0 then
    KnobFarm.InLobby = false
    return false
  end

  KnobFarm.SetStatus("Waiting for rooms...")
  if not KnobFarm.InLobby then
    KnobFarm.InLobby = true
    ResetFarmState()          -- один раз при входе в лобби
  end
  ConfirmShopIfOpen()
  CaptureStartKnobs(true)     -- баланс ДО покупок в магазине
  task.wait(1.0)
  return true
end

-- Общее восстановление после завершения Seek (раньше этот блок был скопирован дважды)
local function EndSeek(curRoomNum)
  MarkSeekDone(curRoomNum)
  KnobFarm.DisabledNoclipForSeek = false
  KnobFarm.Teleporting = false
  pcall(function()
    if toggles and toggles.AutoDoorSkip and toggles.AutoDoorSkip.Value then
      toggles.AutoDoorSkip:SetValue(false)
    end
    if toggles and toggles.PhantomNoclip then
      toggles.PhantomNoclip:SetValue(false)
      task.wait(0.05)
      toggles.PhantomNoclip:SetValue(true)
    end
    -- Обычный Noclip возвращаем ТОЛЬКО если он был включён до погони (раньше включался всегда)
    if KnobFarm.NoclipBeforeSeek and toggles and toggles.Noclip and not toggles.Noclip.Value then
      toggles.Noclip:SetValue(true)
    end
    KnobFarm.NoclipBeforeSeek = false
    local curChar = localPlayer and localPlayer.Character
    if curChar then
      for _, p in ipairs(curChar:GetDescendants()) do
        if p:IsA("BasePart") then
          p.CanCollide = false
        end
      end
    end
  end)
  KnobFarm.SetStatus("Seek passed! Knob Farm resumed.")
  task.wait(0.2)
end

-- 3. Погоня Seek: отключаем ноуклип и просто телепортируемся на дверь за дверью
local function StepSeek(char, hum, root, room, roomNum)
  local curRoomNum = GetLatestRoomNum() or roomNum
  local curRooms = workspace:FindFirstChild("CurrentRooms")
  local seekRoom = (curRooms and curRooms:FindFirstChild(tostring(curRoomNum))) or room

  local inSeek = UpdateSeekState(room, roomNum) or UpdateSeekState(seekRoom, curRoomNum)

  if not inSeek then
    if KnobFarm.DisabledNoclipForSeek then
      EndSeek(curRoomNum)
      return true
    end
    return false
  end

  -- Запоминаем, был ли включён обычный Noclip, ДО погони (один раз), чтобы вернуть ровно его
  if not KnobFarm.DisabledNoclipForSeek then
    KnobFarm.NoclipBeforeSeek = (toggles and toggles.Noclip and toggles.Noclip.Value) or false
  end

  -- Ноуклип выкл, коллизии вкл
  pcall(function()
    if toggles and toggles.PhantomNoclip and toggles.PhantomNoclip.Value then
      toggles.PhantomNoclip:SetValue(false)
    end
    if toggles and toggles.Noclip and toggles.Noclip.Value then
      toggles.Noclip:SetValue(false)
    end
    for _, p in ipairs(char:GetDescendants()) do
      if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
        p.CanCollide = true
      end
    end
  end)
  KnobFarm.DisabledNoclipForSeek = true
  KnobFarm.InSeekChase = true
  KnobFarm.Teleporting = true   -- иначе античит-«страж» PhantomNoclip откатит наш телепорт
  root.AssemblyLinearVelocity = Vector3.zero
  hum:Move(Vector3.zero, false)

  local maxDoors = MaxSeekDoors(curRoomNum)
  KnobFarm.SetStatus("Seek Chase: Skipped " .. tostring(KnobFarm.SeekDoorsSkipped or 0) .. "/" .. tostring(maxDoors) .. " Doors")

  local targetRoom = (curRooms and curRooms:FindFirstChild(tostring(GetLatestRoomNum() or curRoomNum))) or room
  local door = FindRealSeekDoor(targetRoom, curRoomNum) or (targetRoom and targetRoom:FindFirstChild("Door"))
  if not door and targetRoom then
    door = targetRoom:FindFirstChildWhichIsA("Model", true)
    if door and not (door.Name == "Door" or door:FindFirstChild("Door") or door:FindFirstChildWhichIsA("ProximityPrompt", true)) then
      door = nil
    end
  end

  if door then
    local doorPart = door:FindFirstChild("Door") or door:FindFirstChild("Hidden") or door.PrimaryPart
    if doorPart then
      root.CFrame = doorPart.CFrame * CFrame.new(0, 0, 3)
      root.AssemblyLinearVelocity = Vector3.zero
    end
    FirePrompt(door:FindFirstChildWhichIsA("ProximityPrompt", true), false, true)
    if door:FindFirstChild("ClientOpen") then
      pcall(function() door.ClientOpen:FireServer() end)
    end

    -- Фиксируем пропуск двери (считаем каждую новую комнату один раз)
    local currentTargetNum = GetLatestRoomNum() or curRoomNum
    if currentTargetNum ~= KnobFarm.LastSkippedRoom then
      KnobFarm.LastSkippedRoom = currentTargetNum
      KnobFarm.SeekDoorsSkipped = (KnobFarm.SeekDoorsSkipped or 0) + 1
    end
  end

  task.wait(0.1)
  return true
end

-- 4. Застревание / пустота / крыша
local function StepRecovery(hum, root, room)
  if IsStuck() then
    KnobFarm.SetStatus("Stuck detected! Recovering...")
    local _, _, floorPart = HasFloorUnder(root.Position, 4)
    if not IsStairPart(floorPart) then
      hum.Jump = true
    end
    KnobFarm.LastPosition = root.Position
    KnobFarm.LastMoveTime = tick()
    return true
  end

  if not HasFloorUnder(root.Position, 25) then
    RecoverFromVoid(room)
    return true
  end

  if HandleRoof(room) then
    return true
  end

  return false
end

-- Рычаг ворот: идём к нему и тянем (раньше бот только подходил, промпт не нажимался;
-- а HasRoomGate с рекурсивным поиском выполнялся каждый тик). Один раз на комнату.
local function PullGateLever(room)
  if KnobFarm.GatesHandled[room] then return end
  KnobFarm.GatesHandled[room] = true

  local hasGate, _, lever = HasRoomGate(room)
  if not (hasGate and lever) then return end
  local leverPos = GetInstancePosition(lever)
  if not leverPos then return end

  KnobFarm.SetStatus("Pulling Gate Lever...")
  NavigateTo(leverPos, lever, "Gate Lever", 5.0, "Lever")
  local prompt = lever:IsA("ProximityPrompt") and lever or lever:FindFirstChildWhichIsA("ProximityPrompt", true)
  FirePrompt(prompt, false, true)
  task.wait(0.2)
end

-- Комната 49: самоубийство ради быстрого Play Again (быстрый цикл 1-49)
local function ResetAtRoom49(char, hum)
  KnobFarm.SetStatus("Room 49 reached! Resetting character for Play Again...")
  SetFeature("Godmode", false)
  pcall(function()
    char = char or (localPlayer and localPlayer.Character)
    hum = hum or (char and char:FindFirstChildOfClass("Humanoid"))
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if hum then hum.Health = 0 end
    if char then char:BreakJoints() end
    local underwater = (remotesFolder and remotesFolder:FindFirstChild("Underwater"))
      or (replicatedStorage and replicatedStorage:FindFirstChild("RemotesFolder")
        and replicatedStorage.RemotesFolder:FindFirstChild("Underwater"))
    if underwater then
      underwater:FireServer(true)
    end
    if root then
      KnobFarm.Teleporting = true
      root.CFrame = CFrame.new(root.Position.X, -500, root.Position.Z)
    end
  end)
  task.wait(1.0)
end

-- Скип двери: телепорт к двери текущей комнаты со стороны подхода + обычное открытие/проход.
-- Используется, когда бот слишком долго торчит в одной комнате или упёрся в угол.
local function SkipCurrentDoor(room, roomNum, reason)
  local char = localPlayer and localPlayer.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not (hum and root and room) then return false end

  local door = GetRoomTarget(room)
  if not door then return false end
  local _, center, _, passDir = GetDoorVectors(door, root.Position)
  if not center or not passDir then return false end

  KnobFarm.SetStatus("Door skip (" .. tostring(reason) .. ") — Room " .. tostring(roomNum))
  local approach = center - passDir * 3
  local floorPos = GetFloorPosition(approach) or approach

  KnobFarm.Teleporting = true   -- фарм сам перемещает персонажа
  root.CFrame = CFrame.new(floorPos + Vector3.new(0, 3, 0))
  root.AssemblyLinearVelocity = Vector3.zero
  task.wait(0.15)
  KnobFarm.Teleporting = false

  PassDoorStraight(door, root, hum)   -- отпирание (ключ/отмычка), открытие, проход
  KnobFarm.StuckBreaks = 0
  return true
end

-- 10. Главная цель: дверь выхода (или ключ, если заперто и нет отмычек)
local function StepGoToExit(char, root, room, roomNum)
  local target, targetPos, targetType = GetRoomTarget(room)
  if not target or not targetPos then
    KnobFarm.SetStatus("Searching Door (Room " .. tostring(roomNum) .. ")...")
    task.wait(0.3)
    return
  end

  local exitLockId = target:GetAttribute("RoomID")
  if IsDoorLocked(target) and not HasLockpick() and not HasKeyTool(exitLockId) then
    KnobFarm.SetStatus("No lockpicks! Walking to key (Room " .. tostring(roomNum) .. ")...")
    if not FetchRoomKey(room, true) then
      KnobFarm.SetStatus("Door locked & no key found in Room " .. tostring(roomNum))
    end
  end

  -- Ключ найден — идём к двери только с ключом в руках
  if IsDoorLocked(target) and HasKeyTool(exitLockId) then
    KnobFarm.SetStatus("Taking the key in hand (Room " .. tostring(roomNum) .. ")...")
    if not EnsureKeyInHand(exitLockId) and not HasLockpick() then
      KnobFarm.SetStatus("Key is not in hand yet (Room " .. tostring(roomNum) .. ")...")
      task.wait(0.2)
      return
    end
  end

  -- Упёрлись в угол несколько раз подряд: сначала пробуем прямой маршрут без PathfindNodes,
  -- а если и это не помогло — скипаем дверь
  local stuckBreaks = KnobFarm.StuckBreaks or 0
  if stuckBreaks >= 4 and roomNum ~= ROOMS.FIGURE and roomNum ~= ROOMS.ELEVATOR then
    if SkipCurrentDoor(room, roomNum, "stuck") then return end
  end

  KnobFarm.SetStatus("Running to Door (Room " .. tostring(roomNum) .. ")")

  -- 1. Официальные PathfindNodes комнаты (центр коридоров от разработчиков DOORS)
  local waypoints = nil
  local roomNodes = (stuckBreaks < 2) and GetRoomPathfindNodes(room, root.Position, targetPos) or nil
  if roomNodes and #roomNodes >= 2 then
    waypoints = ProcessWaypoints(roomNodes, char)
  end
  -- 2. Иначе PathfindingService, иначе прямая
  if not waypoints or #waypoints == 0 then
    if stuckBreaks >= 2 then
      waypoints = ProcessWaypoints({ root.Position, targetPos }, char)   -- прямая, в обход «умных» путей
    else
      waypoints = BuildPathTo(char, root.Position, targetPos)
    end
  end

  if waypoints and #waypoints > 0 then
    FollowPath(waypoints, target, targetPos, targetType, room, roomNum)
  else
    KnobFarm.SetStatus("Path obstructed (Room " .. tostring(roomNum) .. "), calculating...")
    task.wait(0.2)
  end
end

-- Один тик фарма
local function Tick()
  local char = localPlayer and localPlayer.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if not char or not hum then
    task.wait(0.5)
    return
  end

  -- Смерть обрабатываем до проверки корня: у мёртвого персонажа HumanoidRootPart исчезает, и раньше
  -- тик выходил раньше, чем доходил до «Play Again» — фарм вставал навсегда на экране смерти.
  if hum.Health <= 0 and StepDeath(hum) then return end

  if not root then
    task.wait(0.5)
    return
  end

  -- Phantom Noclip в фарме включён на весь забег (бот проходит сквозь мебель и препятствия), обычный Noclip выключен.
  -- Конфиг может поменять их позже запуска фарма, поэтому следим каждый тик.
  -- (на время погони Seek Phantom выключается: с ним двери в коридоре погони не открываются и бот не успевает)
  SetFeature("PhantomNoclip", not (KnobFarm.InSeekChase or KnobFarm.SeekMode))
  SetFeature("Noclip", false)
  if KnobFarm.PassedFirstDoor and not KnobFarm.DisableGodmodeForBoss then
    SetFeature("Godmode", true)
    SetFeature("GodmodeMethod", "On entity spawn", true)
  end

  if StepDeath(hum) then return end
  if StepLobby() then return end

  local room, roomNum = GetPlayerCurrentRoom()
  if not room then
    task.wait(0.2)
    return
  end

  -- Никогда не идём назад: если уже были в комнате выше — остаёмся в ней
  if KnobFarm.CurrentRoomNum and roomNum < KnobFarm.CurrentRoomNum then
    local roomsFolder = workspace:FindFirstChild("CurrentRooms")
    local expectedRoom = roomsFolder and roomsFolder:FindFirstChild(tostring(KnobFarm.CurrentRoomNum))
    if expectedRoom then
      room = expectedRoom
      roomNum = KnobFarm.CurrentRoomNum
    end
  else
    KnobFarm.CurrentRoomNum = roomNum
  end

  if KnobFarm.LastRoomNum ~= roomNum then
    KnobFarm.LastRoomNum = roomNum
    KnobFarm.RoomEntryTime = tick()
    KnobFarm.StuckBreaks = 0
    DisableObstacleCollision(nil)   -- все комнаты, включая текущую (отдельный вызов для room был лишним)
  end

  -- 10 минут в одной комнате → Play Again. Раньше таймер не сбрасывался, и ремоут
  -- долбился каждые 5 секунд; теперь повтор — раз в 30 секунд.
  if KnobFarm.RoomEntryTime and (tick() - KnobFarm.RoomEntryTime >= ROOMS.PLAY_AGAIN_AFTER) then
    KnobFarm.SetStatus("10m timeout in Room " .. tostring(roomNum) .. "! Triggering Play Again...")
    RequestPlayAgain()
    KnobFarm.RoomEntryTime = tick() - (ROOMS.PLAY_AGAIN_AFTER - 30)
    task.wait(5.0)
    return
  end

  -- Seek
  if StepSeek(char, hum, root, room, roomNum) then return end

  -- Застревание / пустота / крыша
  if StepRecovery(hum, root, room) then return end

  -- Больше 1.5 минут в одной комнате (кроме 50 и 100) — скипаем дверь.
  -- Если скип не удался, повторяем через 30 секунд.
  if roomNum ~= ROOMS.FIGURE and roomNum ~= ROOMS.ELEVATOR and (GetLatestRoomNum() or 0) ~= ROOMS.FIGURE
    and KnobFarm.RoomEntryTime and (tick() - KnobFarm.RoomEntryTime >= ROOMS.SKIP_DOOR_AFTER) then
    KnobFarm.RoomEntryTime = tick() - (ROOMS.SKIP_DOOR_AFTER - 30)
    if SkipCurrentDoor(room, roomNum, "90s in room") then return end
  end

  -- Баланс Knobs на старте (если скрипт запущен посреди забега — тоже запомним)
  CaptureStartKnobs(false)

  -- Комнаты 0/1: Godmode должен быть включён
  if roomNum <= 1 or not KnobFarm.PassedFirstDoor then
    ConfirmShopIfOpen()
    SetFeature("Godmode", true)
    SetFeature("GodmodeMethod", "On entity spawn", true)
  end

  -- Комнаты 60 и 89–99: полный игнор — ничего не лутаем, ничего не ждём, не тянем рычаги,
  -- просто летим к двери следующей комнаты
  local isIgnoredRoom = (roomNum == ROOMS.SECOND_SEEK) or (roomNum >= ROOMS.IGNORE_FROM and roomNum <= ROOMS.IGNORE_TO)

  -- Ворота с рычагом
  local isGateRoom = IsGateRoomWithThingToOpen(room)
  if isGateRoom then
    KnobFarm.SetStatus("Gate room detected — ignoring obstacles, heading straight to Door...")
  elseif not isIgnoredRoom then
    PullGateLever(room)
  end

  local currentLatest = GetLatestRoomNum() or 0
  local curRooms = workspace:FindFirstChild("CurrentRooms")
  local runTo = not (toggles and toggles.AutoFarmRunTo100 and not toggles.AutoFarmRunTo100.Value)

  -- Комната 49: самоубийство ради быстрого Play Again (только если «Farm to Door 100» явно выключен)
  if not runTo and ((roomNum and roomNum >= ROOMS.LAST_NORMAL) or currentLatest >= ROOMS.LAST_NORMAL) then
    ResetAtRoom49(char, hum)
    return
  end

  -- Комната 50 (Фигура + библиотека)
  if roomNum == ROOMS.FIGURE or currentLatest == ROOMS.FIGURE then
    local room2 = (curRooms and curRooms:FindFirstChild(tostring(ROOMS.FIGURE))) or room
    handleRoom(room2, room2 and room2:FindFirstChild("Door"))
    return
  end

  -- Ждём пролёта Rush/Ambush (только вне зоны Seek и вне 50)
  if not isIgnoredRoom then
    WaitForThreats(roomNum, room)
  end

  -- Комната 100 (электрощит, лифт)
  -- Только когда бот реально В комнате 100. Раньше хватало LatestRoom >= 100: бот ещё стоял в 99-й,
  -- объекты 100-й не успевали загрузиться, список предохранителей был пуст, и он сразу шёл к рычагу.
  if roomNum and roomNum >= ROOMS.ELEVATOR then
    local room2 = (curRooms and curRooms:FindFirstChild(tostring(ROOMS.ELEVATOR))) or room
    SolveRoom100(room2)
    return
  end

  -- Лут. В 49-й не тратим время — бежим сразу к двери 50.
  local lootOn = not (toggles and toggles.AutoFarmLootDrawers) or toggles.AutoFarmLootDrawers.Value
  if lootOn and not isIgnoredRoom and (roomNum or 0) > 0 and roomNum ~= ROOMS.LAST_NORMAL and KnobFarm.PassedFirstDoor and not isGateRoom then
    LootAllInRoom(room)
  end

  StepGoToExit(char, root, room, roomNum)
end

function KnobFarm.RunLoop()
  KnobFarm.SetStatus("Knob Farm Active")
  local consecutiveErrors = 0

  while KnobFarm.Active and not _Unloading do
    task.wait(0.04)

    local success, result = pcall(Tick)
    if success then
      consecutiveErrors = 0
    else
      consecutiveErrors = consecutiveErrors + 1
      warn("[KnobFarm Error]:", result)
      KnobFarm.SetStatus("Error (retrying): " .. string.sub(tostring(result), 1, 60))
      task.wait(math.min(0.5 * consecutiveErrors, 5))
    end
  end

  KnobFarm.SetStatus("Idle")
  ClearPathNodes()
  SetCrouched(false)
end

function KnobFarm.Start()
  if KnobFarm.Active then return end
  KnobFarm.Active = true
  KnobFarm.PassedFirstDoor = false
  KnobFarm.LootedObjects = setmetatable({}, { __mode = "k" })
  KnobFarm.OpenedDoors = setmetatable({}, { __mode = "k" })
  KnobFarm.DisableGodmodeForBoss = false
  KnobFarm.LastPosition = nil
  KnobFarm.LastMoveTime = tick()
  KnobFarm.Teleporting = false
  KnobFarm.InLobby = false
  KnobFarm.SeekMode = false
  KnobFarm.IgnoredDoors = setmetatable({}, { __mode = "k" })
  KnobFarm.GatesHandled = setmetatable({}, { __mode = "k" })
  lastDeathHumanoid = nil
  ResetRecoveryState()

  -- Запоминаем скорость ВСЕГДА (раньше — только если стартовали уже в комнате ≥1,
  -- поэтому Stop() не возвращал скорость, если фарм включали в начале забега)
  pcall(function()
    if options and options.Walkspeed then
      KnobFarm.PreviousWalkSpeed = options.Walkspeed.Value
    end
  end)

  DisableObstacleCollision(nil)
  SetupObstacleListener()

  local char = localPlayer and localPlayer.Character
  local col = char and char:FindFirstChild("Collision")
  if col and col:IsA("BasePart") and col.Size.X > 2.2 then
    col.Size = Vector3.new(2.0, 3.0, 2.0)
  end

  SetFeature("AutoBuyLockpicks", false)
  SetFeature("InfiniteItemsToggle", true)

  local _, curRoomNum = GetPlayerCurrentRoom()
  KnobFarm.CurrentRoomNum = curRoomNum or 0
  KnobFarm.LastRoomNum = curRoomNum
  KnobFarm.RoomEntryTime = tick()
  if (curRoomNum or 0) >= 1 then
    KnobFarm.PassedFirstDoor = true
    pcall(function()
      if options and options.Walkspeed then
        KnobFarm.PreviousWalkSpeed = options.Walkspeed.Value
        local desiredSpeed = (options.AutoFarmSpeed and options.AutoFarmSpeed.Value)
          or (options.AutoFarmWalkSpeed and options.AutoFarmWalkSpeed.Value) or 22
        if options.Walkspeed.Value < desiredSpeed then
          options.Walkspeed:SetValue(desiredSpeed)
        end
      end
    end)
    SetFeature("Godmode", true)
    SetFeature("GodmodeMethod", "On entity spawn", true)
  end

  KnobFarm.SetStatus("Started (Room " .. tostring(KnobFarm.CurrentRoomNum) .. ")")

  SetFeature("InstantInteract", true)

  KnobFarm.Thread = task.spawn(KnobFarm.RunLoop)
end

function KnobFarm.Stop()
  KnobFarm.Active = false
  KnobFarm.DisableGodmodeForBoss = false
  KnobFarm.PassedFirstDoor = false
  KnobFarm.LastRoomNum = nil
  KnobFarm.RoomEntryTime = 0
  KnobFarm.LootedObjects = setmetatable({}, { __mode = "k" })
  KnobFarm.OpenedDoors = setmetatable({}, { __mode = "k" })
  if obstacleListener then
    pcall(function() obstacleListener:Disconnect() end)
    obstacleListener = nil
  end
  if KnobFarm.Thread then
    pcall(task.cancel, KnobFarm.Thread)
    KnobFarm.Thread = nil
  end
  -- task.cancel не отключает RenderStepped-соединение FollowPath и не снимает флаги восстановления
  if activeMoveConn then
    pcall(function() activeMoveConn:Disconnect() end)
    activeMoveConn = nil
  end
  ResetRecoveryState()
  ResetFarmState()
  KnobFarm.StopFly()   -- task.cancel не снимает BodyVelocity полёта
  RestoreFeatures()    -- вернуть Godmode / Instant Interact и т.д. в состояние до фарма

  pcall(function()
    if options and options.Walkspeed and KnobFarm.PreviousWalkSpeed then
      options.Walkspeed:SetValue(KnobFarm.PreviousWalkSpeed)
      KnobFarm.PreviousWalkSpeed = nil
    end
  end)

  local char = localPlayer and localPlayer.Character
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if hum then hum:Move(Vector3.zero, false) end
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if root then
    root.AssemblyLinearVelocity = Vector3.zero
  end
  KnobFarm.SetStatus("Disabled")
end

KnobFarm.SetCrouched = SetCrouched

-- Connect UI toggle & slider


-- menu of this block: built later, from the MENU section at the end of the file
Menus.KnobFarm = function()
  if toggles and toggles.AutoFarmEnabled then
    toggles.AutoFarmEnabled:OnChanged(function(enabled)
      if enabled then
        KnobFarm.Start()
      else
        KnobFarm.Stop()
      end
    end)

    if toggles.AutoFarmEnabled.Value then
      KnobFarm.Start()
    end
  end

  local farmSpeedOpt = (options and options.AutoFarmSpeed) or (options and options.AutoFarmWalkSpeed)

  if farmSpeedOpt then
    farmSpeedOpt:OnChanged(function(val)
      if KnobFarm.Active and options.Walkspeed then
        options.Walkspeed:SetValue(val)
      end
    end)
  end
end


end)() end

-- =====================================================================
--  MODEL SWAP + ROOM COUNTER
--  Client-side only: replaces how players and entities look with a 3D model or a PNG sprite,
--  and draws the current room number at the top center of the screen.
-- =====================================================================
do (function()
  -- ------------------------------------------------------------------ categories
  local CATEGORIES = {
    { key = "Players", title = "Players", players = true, height = 5.6 },
    { key = "Figure", title = "Figure", names = { "Figure", "FigureRig", "FigureRagdoll" }, height = 9 },
    { key = "Seek", title = "Seek", names = { "SeekMoving", "SeekMovingNewClone", "SeekRig" }, height = 9 },
    { key = "Rush", title = "Rush and clones", names = { "RushMoving", "BackdoorRush", "GlitchRush" }, height = 6 },
    { key = "Ambush", title = "Ambush and clones", names = { "AmbushMoving", "FrozenAmbush", "GlitchAmbush" }, height = 6 },
    { key = "A60", title = "A-60 / A-120", names = { "A60", "A120" }, height = 6 },
    { key = "Eyes", title = "Eyes / Lookman", names = { "Eyes", "Lookman", "BackdoorLookman" }, height = 6 },
    { key = "Companion", title = "Companion", names = { "MoroCompanion" }, height = 3 },
    { key = "Custom", title = "Custom entity", names = {}, height = 6 },
  }

  local PRESETS = {
    { "Chubby Dog", 22202531681153, true },
    { "Alya", { 239, 57285014083965, 131346580241689, 126528728730337, 96994061769130 }, true },
    { "Shark", 1105996, true },
    { "TUNG Sahur", 164815366314625, true },
    { "Withered Golden Freddy", 103872628924571, true },
  }
  local presetNames, presetByName = {}, {}
  for _, p in ipairs(PRESETS) do
    presetNames[#presetNames + 1] = p[1]
    presetByName[p[1]] = p
  end

  local swapFolder = Instance.new("Folder")
  swapFolder.Name = "MoroModelSwap"
  swapFolder.Parent = workspace

  local alive = true
  local settings = {}     -- [categoryKey] = { mode, height, yaw, yoff, anim, bubble, scope, customNames }
  local templates = {}    -- [categoryKey] = { model, id }
  local spriteImages = {} -- [categoryKey] = resolved image string
  local spriteTexts = {}  -- [categoryKey] = text typed by the user
  local records = {}      -- [instance] = record
  local generation = 0
  local statusLabel
  local options2 = { hideEffects = true }
  local companionPart

  for _, cat in ipairs(CATEGORIES) do
    settings[cat.key] = { mode = "Off", height = cat.height, yaw = 0, yoff = 0, anim = "None", bubble = "", scope = "Everyone", customNames = "" }
  end
  settings.Companion.anim = "Bob"

  local function say(title, text, kind)
    pcall(function() library:Notify({ Title = title, Description = text, Time = kind == "error" and 5 or 3 }) end)
  end
  local function setStatus(text)
    if statusLabel then pcall(function() statusLabel:SetText(text) end) end
  end

  -- ------------------------------------------------------------------ asset loading (model library)
  local function sanitizeTemplate(objects, isRig)
    local model = Instance.new("Model")
    model.Name = "MoroSwapTemplate"
    for _, object in ipairs(objects) do
      if isRig and object:IsA("Model") then
        for _, child in ipairs(object:GetChildren()) do child.Parent = model end
        object:Destroy()
      else
        object.Parent = model
      end
    end
    if isRig then
      model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
      model:SetAttribute("Rig", true)
    end
    local count = 0
    for _, descendant in ipairs(model:GetDescendants()) do
      count = count + 1
      if count % 200 == 0 then task.wait() end
      if descendant:IsA("Tool") then
        for _, child in ipairs(descendant:GetChildren()) do
          if child:IsA("BasePart") or child:IsA("Model") then child.Parent = model end
        end
        descendant:Destroy()
      elseif descendant:IsA("LuaSourceContainer") or descendant:IsA("Sound") or (descendant:IsA("Humanoid") and not isRig)
        or descendant:IsA("Animator") or (descendant:IsA("JointInstance") and not isRig) or descendant:IsA("WeldConstraint")
        or descendant:IsA("ProximityPrompt") or descendant:IsA("ClickDetector") or descendant:IsA("BodyMover")
        or descendant:IsA("ForceField") or descendant:IsA("Seat") or descendant:IsA("VehicleSeat") then
        pcall(function() descendant:Destroy() end)
      end
    end
    -- a rig keeps its Humanoid only so that Shirt / Pants textures are drawn
    local humanoid = isRig and model:FindFirstChildOfClass("Humanoid")
    if humanoid then
      humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
      humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
      humanoid.AutoRotate = false
      pcall(function() humanoid.EvaluateStateMachine = false end)
      pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
    end
    for _, descendant in ipairs(model:GetDescendants()) do
      if descendant:IsA("BasePart") then
        descendant.Anchored, descendant.CanCollide, descendant.CanQuery, descendant.CanTouch, descendant.Massless = true, false, false, false, true
      end
    end
    return model
  end

  -- marketplace items: a bundle or a catalog item is dressed onto an R15 rig through a HumanoidDescription
  local ITEM_FIELDS = {
    [17] = "Head", [18] = "Face", [27] = "Torso", [28] = "RightArm", [29] = "LeftArm", [30] = "LeftLeg", [31] = "RightLeg",
    [2] = "GraphicTShirt", [11] = "Shirt", [12] = "Pants", [79] = "Head",
  }
  local ITEM_ACCESSORY = {
    [8] = Enum.AccessoryType.Hat, [41] = Enum.AccessoryType.Hair, [42] = Enum.AccessoryType.Face, [43] = Enum.AccessoryType.Neck,
    [44] = Enum.AccessoryType.Shoulder, [45] = Enum.AccessoryType.Front, [46] = Enum.AccessoryType.Back, [47] = Enum.AccessoryType.Waist,
    [64] = Enum.AccessoryType.TShirt, [65] = Enum.AccessoryType.Shirt, [66] = Enum.AccessoryType.Pants, [67] = Enum.AccessoryType.Jacket,
    [68] = Enum.AccessoryType.Sweater, [69] = Enum.AccessoryType.Shorts, [70] = Enum.AccessoryType.LeftShoe, [71] = Enum.AccessoryType.RightShoe,
    [72] = Enum.AccessoryType.DressSkirt,
  }

  local function parseItemId(text)
    text = tostring(text or "")
    if text:find("share%?code") or text:find("share%-links") then return nil, "share links need a login: paste the /bundles/... or /catalog/... address instead" end
    if text:find("/looks/") then return nil, "a look is a set of items: paste its item links one by one" end
    local id = text:match("/bundles/(%d+)") or text:match("/catalog/(%d+)") or text:match("/library/(%d+)") or text:match("(%d%d%d+)")
    return tonumber(id), true
  end

  local function marketModel(id)
    local function get(url) return httpService:JSONDecode(game:HttpGet(url)) end
    local ids = type(id) == "table" and id or { id }
    local description
    local accessories = {}
    local function put(assetId, assetType, explicit)
      if ITEM_FIELDS[assetType] then
        description[ITEM_FIELDS[assetType]] = assetId
      elseif ITEM_ACCESSORY[assetType] then
        if explicit then
          for i = #accessories, 1, -1 do
            if accessories[i].AccessoryType == ITEM_ACCESSORY[assetType] then table.remove(accessories, i) end
          end
        end
        accessories[#accessories + 1] = { AssetId = assetId, AccessoryType = ITEM_ACCESSORY[assetType], Order = #accessories + 1 }
      end
    end
    -- a single bundle that ships with an outfit is used as the outfit (keeps its body scale)
    if #ids == 1 then
      local okBundle, bundle = pcall(get, "https://catalog.roblox.com/v1/bundles/" .. ids[1] .. "/details")
      if okBundle and type(bundle) == "table" and bundle.id then
        for _, item in ipairs(bundle.items or {}) do
          if item.type == "UserOutfit" then description = players:GetHumanoidDescriptionFromOutfitId(item.id) break end
        end
      end
    end
    if not description then
      description = Instance.new("HumanoidDescription")
      local skin = Color3.fromRGB(255, 224, 204)
      description.HeadColor, description.TorsoColor, description.LeftArmColor = skin, skin, skin
      description.RightArmColor, description.LeftLegColor, description.RightLegColor = skin, skin, skin
      for _, one in ipairs(ids) do
        local okBundle, bundle = pcall(get, "https://catalog.roblox.com/v1/bundles/" .. one .. "/details")
        if okBundle and type(bundle) == "table" and bundle.id then
          for _, item in ipairs(bundle.items or {}) do
            if item.type == "Asset" then put(item.id, item.assetType) end
          end
        else
          local okDetails, details = pcall(get, "https://economy.roblox.com/v2/assets/" .. one .. "/details")
          if not (okDetails and type(details) == "table" and details.AssetTypeId) then return nil, "item " .. one .. " not found in the catalog" end
          if not (ITEM_FIELDS[details.AssetTypeId] or ITEM_ACCESSORY[details.AssetTypeId]) then
            return nil, "asset type " .. tostring(details.AssetTypeId) .. " is not an avatar item, use Asset ID"
          end
          put(one, details.AssetTypeId, true)
        end
      end
      if #accessories > 0 then description:SetAccessories(accessories, true) end
    end
    local rig = players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
    local root = rig:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = true end
    rig.Parent = workspace.Terrain   -- a rig only assembles itself once it is in the world
    task.wait(0.4)
    return { rig }
  end

  local loading = false
  local function dropRecords()
    for instance, record in pairs(records) do
      if record.destroy then pcall(record.destroy) end
      records[instance] = nil
    end
  end

  local function loadTemplate(catKey, id, isMarket)
    if loading then return say("Model Swap", "Already loading, wait a moment") end
    loading = true
    local label = type(id) == "table" and "look" or tostring(id)
    setStatus("Loading " .. label .. "...")
    task.spawn(function()
      local finished, objects, err = false, nil, nil
      task.spawn(function()
        local ok, result, why
        if isMarket then
          ok, result, why = pcall(marketModel, id)
          if ok and not result then ok, result = false, why end
        else
          ok, result = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
        end
        if ok then objects = result else err = result end
        finished = true
      end)
      local started = os.clock()
      while not finished and os.clock() - started < 40 do task.wait(0.1) end
      if not objects or #objects == 0 then
        loading = false
        setStatus("Error: " .. (finished and tostring(err or "empty asset") or "timed out"))
        return say("Model Swap", "Load failed: " .. (finished and tostring(err or "empty asset") or "timed out"), "error")
      end
      local ok, template = pcall(sanitizeTemplate, objects, isMarket)
      loading = false
      if not ok then
        setStatus("Error: " .. tostring(template))
        return say("Model Swap", tostring(template), "error")
      end
      local _, size = template:GetBoundingBox()
      if size.Magnitude < 0.1 then
        setStatus("Error: asset has no visible parts")
        return say("Model Swap", "Asset has no visible parts", "error")
      end
      if templates[catKey] and templates[catKey].model then templates[catKey].model:Destroy() end
      templates[catKey] = { model = template, id = id }
      generation = generation + 1
      dropRecords()
      setStatus("Ready: " .. catKey .. " <- " .. label)
      say("Model Swap", catKey .. ": model ready")
      -- loading a model for a category is a request to use it
      if settings[catKey].mode == "Off" then
        settings[catKey].mode = "Model"
        pcall(function() options["MS_" .. catKey .. "_Mode"]:SetValue("Model") end)
      end
    end)
  end

  local function searchToolbox(keyword, callback)
    task.spawn(function()
      local ok, result = pcall(function()
        local found = httpService:JSONDecode(game:HttpGet("https://apis.roblox.com/toolbox-service/v1/marketplace/10?keyword=" .. httpService:UrlEncode(keyword) .. "&num=20&sortType=1"))
        local ids = {}
        for _, entry in ipairs(found.data or {}) do ids[#ids + 1] = entry.id end
        if #ids == 0 then return {} end
        local details = httpService:JSONDecode(game:HttpGet("https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=" .. table.concat(ids, ",")))
        local list = {}
        for _, item in ipairs(details.data or {}) do
          if item.asset then list[#list + 1] = { id = item.asset.id, name = item.asset.name or "?", by = item.creator and item.creator.name or "?" } end
        end
        return list
      end)
      callback(ok and result or nil, result)
    end)
  end

  -- ------------------------------------------------------------------ sprites (PNG)
  -- accepts an asset id, an rbxassetid:// link, or an http(s) link to a PNG (downloaded through the executor)
  local function resolveImage(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    if text:match("^%d+$") then return "rbxassetid://" .. text end
    if text:match("^rbxasset") then return text end
    if text:match("^https?://") then
      local write, custom = writefile, getcustomasset or getsynasset
      if not (write and custom) then return nil, "this executor has no writefile/getcustomasset, use an asset id" end
      local ok, data = pcall(function() return game:HttpGet(text) end)
      if not ok or type(data) ~= "string" or #data < 16 then return nil, "could not download the image" end
      pcall(function() if makefolder and isfolder and not isfolder("moro") then makefolder("moro") end end)
      pcall(function() if makefolder and isfolder and not isfolder("moro/Sprites") then makefolder("moro/Sprites") end end)
      local path = "moro/Sprites/" .. text:gsub("[^%w]", "_"):sub(-40) .. ".png"
      local okWrite = pcall(write, path, data)
      if not okWrite then return nil, "could not save the image" end
      local okAsset, asset = pcall(custom, path)
      if not okAsset or not asset then return nil, "could not load the saved image" end
      return asset
    end
    return nil, "type an asset id or a link to a PNG"
  end

  -- ------------------------------------------------------------------ target bookkeeping
  local function nameLookup()
    local lookup = {}
    for _, cat in ipairs(CATEGORIES) do
      if cat.names then
        for _, name in ipairs(cat.names) do lookup[name] = cat.key end
      end
    end
    for rawName in string.gmatch(settings.Custom.customNames or "", "[^,;]+") do
      local name = rawName:gsub("^%s+", ""):gsub("%s+$", "")
      if name ~= "" then lookup[name] = "Custom" end
    end
    return lookup
  end

  local function boundsOf(instance)
    if instance:IsA("Model") then
      local ok, cf, size = pcall(instance.GetBoundingBox, instance)
      if ok then return cf, size end
    elseif instance:IsA("BasePart") then
      return instance.CFrame, instance.Size
    end
    return nil
  end

  -- hides the original look of an entity on this client only (everything is restored on removal)
  local function hideOriginal(instance, record)
    for _, descendant in ipairs(instance:GetDescendants()) do
      if not record.touched[descendant] then
        if descendant:IsA("BasePart") then
          record.touched[descendant] = true
          descendant.LocalTransparencyModifier = 1
        elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
          record.touched[descendant] = descendant.Transparency
          descendant.Transparency = 1
        elseif descendant:IsA("SurfaceGui") or descendant:IsA("BillboardGui") then
          record.touched[descendant] = descendant.Enabled
          descendant.Enabled = false
        elseif options2.hideEffects and (descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam")) then
          record.touched[descendant] = descendant.Enabled
          descendant.Enabled = false
        end
      end
    end
    if instance:IsA("BasePart") and not record.touched[instance] then
      record.touched[instance] = true
      instance.LocalTransparencyModifier = 1
    end
  end

  local function restoreOriginal(record)
    for object, original in pairs(record.touched) do
      pcall(function()
        if object:IsA("BasePart") then object.LocalTransparencyModifier = 0
        elseif object:IsA("Decal") or object:IsA("Texture") then object.Transparency = original
        else object.Enabled = original end
      end)
    end
    record.touched = {}
  end

  -- speech bubble above the replacement: phrases separated with ';' rotate every few seconds
  local function makeBubble(anchor)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Bubble"
    gui.Adornee = anchor
    gui.AlwaysOnTop = true
    gui.LightInfluence = 0
    gui.Size = UDim2.fromOffset(220, 34)
    gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
    gui.Enabled = false
    gui.Parent = anchor
    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromScale(1, 1)
    pill.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    pill.BackgroundTransparency = 0.15
    pill.BorderSizePixel = 0
    pill.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = pill
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 150, 200)
    stroke.Thickness = 1.5
    stroke.Parent = pill
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 15
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Text = ""
    label.Parent = pill
    return gui, label
  end

  -- ------------------------------------------------------------------ records
  local function makeEntityRecord(instance, cat)
    local conf = settings[cat.key]
    local template = templates[cat.key]
    local record = { cat = cat, mode = conf.mode, gen = generation, height = conf.height, touched = {}, phase = math.random() * 6 }

    local cf, size = boundsOf(instance)
    if not cf then return nil end
    record.anchor = Instance.new("Part")
    record.anchor.Anchored, record.anchor.CanCollide, record.anchor.CanQuery, record.anchor.CanTouch = true, false, false, false
    record.anchor.Transparency = 1
    record.anchor.Size = Vector3.new(0.2, 0.2, 0.2)
    record.anchor.Parent = swapFolder

    if conf.mode == "Model" then
      if not (template and template.model) then record.anchor:Destroy() return nil end
      record.model = template.model:Clone()
      local _, bbSize = record.model:GetBoundingBox()
      record.model:ScaleTo(conf.height / math.max(bbSize.Y, 0.1))
      local bbCF = record.model:GetBoundingBox()
      record.offset = record.model:GetPivot():ToObjectSpace(bbCF)
      record.model.Parent = swapFolder
    else
      local gui = Instance.new("BillboardGui")
      gui.Name = "Sprite"
      gui.Adornee = record.anchor
      gui.AlwaysOnTop = false
      gui.LightInfluence = 0
      gui.Size = UDim2.fromScale(conf.height, conf.height)
      gui.Parent = record.anchor
      local image = Instance.new("ImageLabel")
      image.BackgroundTransparency = 1
      image.Size = UDim2.fromScale(1, 1)
      image.ScaleType = Enum.ScaleType.Fit
      image.Image = spriteImages[cat.key] or ""
      image.Parent = gui
      if image.Image == "" then
        -- nothing loaded yet: a placeholder keeps the replacement visible
        local face = Instance.new("TextLabel")
        face.BackgroundTransparency = 1
        face.Size = UDim2.fromScale(1, 1)
        face.TextScaled = true
        face.Text = "(=^.^=)"
        face.TextColor3 = Color3.fromRGB(255, 190, 220)
        face.Font = Enum.Font.GothamBold
        face.Parent = gui
      end
      record.gui, record.image = gui, image
      record.face = image.Image == "" and gui:FindFirstChildOfClass("TextLabel") or nil
      record.spriteId = spriteImages[cat.key]
    end

    record.bubble, record.bubbleLabel = makeBubble(record.anchor)
    record.destroy = function()
      restoreOriginal(record)
      pcall(function() if record.model then record.model:Destroy() end end)
      pcall(function() record.anchor:Destroy() end)
    end
    record.step = function(now)
      local currentCF, currentSize = boundsOf(instance)
      if not currentCF then return end
      local height = conf.height
      local centerY = currentCF.Position.Y - currentSize.Y / 2 + height / 2 + conf.yoff
      local center = Vector3.new(currentCF.Position.X, centerY, currentCF.Position.Z)
      local look = currentCF.LookVector
      local yaw = math.atan2(-look.X, -look.Z) + math.rad(conf.yaw)
      local roll = 0
      if conf.anim == "Bob" then center = center + Vector3.new(0, math.sin(now * 3 + record.phase) * 0.4, 0)
      elseif conf.anim == "Spin" then yaw = yaw + now * 2
      elseif conf.anim == "Wobble" then roll = math.sin(now * 6 + record.phase) * 0.15 end
      record.anchor.CFrame = CFrame.new(center)
      if record.model then
        record.model:PivotTo(CFrame.new(center) * CFrame.Angles(0, yaw, roll) * record.offset:Inverse())
      elseif record.image then
        record.image.Rotation = math.deg(roll) * 2
        record.gui.Size = UDim2.fromScale(conf.height, conf.height)
        if record.spriteId ~= spriteImages[cat.key] then
          record.spriteId = spriteImages[cat.key]
          record.image.Image = record.spriteId or ""
          if record.face and record.spriteId then
            record.face:Destroy()
            record.face = nil
          end
        end
      end
      -- speech bubble
      local phrases = conf.bubble
      if phrases ~= "" then
        local list = {}
        for phrase in string.gmatch(phrases, "[^;]+") do list[#list + 1] = phrase end
        local text = list[(math.floor(now / 3) + math.floor(record.phase * 10)) % #list + 1] or ""
        record.bubbleLabel.Text = text
        record.bubble.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 1.5, 0)
        record.bubble.Enabled = text ~= ""
      else
        record.bubble.Enabled = false
      end
    end
    hideOriginal(instance, record)
    record.refresh = function() hideOriginal(instance, record) end
    return record
  end

  -- player models follow the real skeleton (forward kinematics on the model's own joints)
  local function makePlayerRecord(character, isSelf)
    local conf = settings.Players
    local template = templates.Players
    if not (template and template.model) then return nil end
    local instance = template.model:Clone()
    local _, bbSize = instance:GetBoundingBox()
    instance:ScaleTo(conf.height / math.max(bbSize.Y, 0.1))
    local bbCF, size = instance:GetBoundingBox()
    local offset = instance:GetPivot():ToObjectSpace(bbCF)
    instance.Parent = swapFolder
    local record = { model = instance, offset = offset, size = size, phase = math.random() * 6, gen = generation, height = conf.height, isSelf = isSelf, touched = {}, hiddenParts = {} }
    if instance:GetAttribute("Rig") and instance.PrimaryPart then
      record.rig = true
      local root = instance.PrimaryPart
      record.root = root
      record.drop = root.Position.Y - (bbCF.Position.Y - size.Y / 2)
      local realRoot = character:FindFirstChild("HumanoidRootPart")
      local humanoid = character:FindFirstChildOfClass("Humanoid")
      record.k = record.drop / math.max((humanoid and humanoid.HipHeight or 2) + (realRoot and realRoot.Size.Y / 2 or 1), 0.1)
      local function driven(d)
        if d:IsA("Motor6D") then return d.Part1 end
        if d:IsA("AnimationConstraint") then return d.Attachment1 and d.Attachment1.Parent end
      end
      local real = {}
      for _, d in ipairs(character:GetDescendants()) do
        local part = driven(d)
        if part then real[d.Name .. ":" .. part.Name] = d end
      end
      local entries, byChild = {}, {}
      local function addEntry(parent, child, cf0, cf1, source)
        if parent and child and not byChild[child] then
          local entry = { parent = parent, child = child, cf0 = cf0, cf1 = cf1:Inverse(), src = source }
          byChild[child] = entry
          entries[#entries + 1] = entry
        end
      end
      for _, d in ipairs(instance:GetDescendants()) do
        if d:IsA("Motor6D") then
          addEntry(d.Part0, d.Part1, d.C0, d.C1, real[d.Name .. ":" .. (d.Part1 and d.Part1.Name or "")])
        elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
          addEntry(d.Attachment0.Parent, d.Attachment1.Parent, d.Attachment0.CFrame, d.Attachment1.CFrame, real[d.Name .. ":" .. d.Attachment1.Parent.Name])
        end
      end
      for _, d in ipairs(instance:GetDescendants()) do
        if d:IsA("Weld") and d.Part0 and d.Part1 then
          addEntry(d.Part0, d.Part1, d.C0, d.C1)
        elseif d:IsA("RigidConstraint") and d.Attachment0 and d.Attachment1 then
          local partA, partB = d.Attachment0.Parent, d.Attachment1.Parent
          if partA and partB then
            if partB:FindFirstChildWhichIsA("Attachment") and (partB.Name == "Handle" or partB:FindFirstAncestorOfClass("Accessory")) then
              addEntry(partA, partB, d.Attachment0.CFrame, d.Attachment1.CFrame)
            else
              addEntry(partB, partA, d.Attachment1.CFrame, d.Attachment0.CFrame)
            end
          end
        end
      end
      -- parents before children
      local order, placed = {}, { [root] = true }
      local left = #entries
      while left > 0 do
        local progressed = false
        for _, entry in ipairs(entries) do
          if not entry.done and placed[entry.parent] then
            entry.done, placed[entry.child] = true, true
            order[#order + 1] = entry
            left = left - 1
            progressed = true
          end
        end
        if not progressed then break end
      end
      record.order = order
      record.parts = {}
      for _, d in ipairs(instance:GetDescendants()) do
        if d:IsA("BasePart") then record.parts[#record.parts + 1] = d end
      end
    end
    record.destroy = function()
      pcall(function() instance:Destroy() end)
      for _, part in ipairs(record.hiddenParts) do
        if part.Parent then part.LocalTransparencyModifier = 0 end
      end
    end
    record.refresh = function()
      local list = {}
      for _, d in ipairs(character:GetDescendants()) do
        if d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Tool") then list[#list + 1] = d end
      end
      record.hiddenParts = list
    end
    record.refresh()
    record.step = function(now)
      local root = character.Parent and character:FindFirstChild("HumanoidRootPart")
      if not root then return end
      local humanoid = character:FindFirstChildOfClass("Humanoid")
      local velocity = root.AssemblyLinearVelocity
      local speed = math.clamp(Vector3.new(velocity.X, 0, velocity.Z).Magnitude / 16, 0, 1.5)
      local look = root.CFrame.LookVector
      local yaw = math.atan2(-look.X, -look.Z)
      local feetY = root.Position.Y - ((humanoid and humanoid.HipHeight or 2) + root.Size.Y / 2)
      if record.rig then
        local rootCF = CFrame.new(root.Position.X, feetY + record.drop + conf.yoff, root.Position.Z)
          * (root.CFrame - root.CFrame.Position) * CFrame.Angles(0, math.rad(conf.yaw), 0)
        local cframes = { [record.root] = rootCF }
        local parts, frames = { record.root }, { rootCF }
        for _, entry in ipairs(record.order) do
          local parentCF = cframes[entry.parent]
          if parentCF then
            local transform = CFrame.identity
            if entry.src then
              local s = entry.src.Transform
              transform = CFrame.new(s.Position * record.k) * (s - s.Position)
            end
            local childCF = parentCF * entry.cf0 * transform * entry.cf1
            cframes[entry.child] = childCF
            parts[#parts + 1], frames[#frames + 1] = entry.child, childCF
          end
        end
        for _, part in ipairs(record.parts) do part.CanCollide, part.CanTouch, part.CanQuery = false, false, false end
        workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
      else
        local bob = math.abs(math.sin(now * 9 + record.phase)) * 0.45 * speed
        local target = CFrame.new(root.Position.X, feetY + record.size.Y / 2 + bob + conf.yoff, root.Position.Z)
          * CFrame.Angles(0, yaw + math.rad(conf.yaw), 0)
          * CFrame.Angles(math.rad(-10) * speed, 0, math.sin(now * 9 + record.phase) * math.rad(7) * speed)
        record.model:PivotTo(target * record.offset:Inverse())
      end
      for _, part in ipairs(record.hiddenParts) do
        if part.Parent then part.LocalTransparencyModifier = 1 end
      end
      if record.isSelf then
        local camera = workspace.CurrentCamera
        local near = camera and (camera.CFrame.Position - root.Position).Magnitude < 2
        if near ~= record.nearHidden then
          record.nearHidden = near
          for _, d in ipairs(record.model:GetDescendants()) do
            if d:IsA("BasePart") then d.LocalTransparencyModifier = near and 1 or 0 end
          end
        end
      end
    end
    return record
  end

  -- ------------------------------------------------------------------ sync + render loops
  local function wantsPlayer(player)
    local conf = settings.Players
    if conf.mode ~= "Model" or not (templates.Players and templates.Players.model) then return false end
    if conf.scope == "Me only" then return player == localPlayer end
    if conf.scope == "Others only" then return player ~= localPlayer end
    return true
  end

  local function syncRecords()
    local keep = {}
    -- players
    for _, player in ipairs(players:GetPlayers()) do
      local character = player.Character
      local humanoid = character and character:FindFirstChildOfClass("Humanoid")
      if character and humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") and wantsPlayer(player) then
        keep[character] = true
        local record = records[character]
        if record and (record.gen ~= generation or math.abs(record.height - settings.Players.height) > 0.01) then
          record.destroy()
          records[character] = nil
          record = nil
        end
        if not record then
          record = makePlayerRecord(character, player == localPlayer)
          records[character] = record
        end
        if record then record.refresh() end
      end
    end
    -- entities: the script's own registry plus everything directly in workspace
    local lookup = nameLookup()
    local candidates = {}
    for _, entity in ipairs(ESPCategories.Entities or {}) do candidates[#candidates + 1] = entity end
    for _, child in ipairs(workspace:GetChildren()) do
      if lookup[child.Name] then candidates[#candidates + 1] = child end
    end
    if settings.Companion.mode ~= "Off" and companionPart and companionPart.Parent then
      candidates[#candidates + 1] = companionPart
    end
    for _, instance in ipairs(candidates) do
      local key = instance.Parent and lookup[instance.Name]
      local cat
      if key then
        for _, c in ipairs(CATEGORIES) do if c.key == key then cat = c end end
      end
      if cat and not keep[instance] then
        local conf = settings[cat.key]
        local ready = conf.mode == "Sprite" or (conf.mode == "Model" and templates[cat.key] and templates[cat.key].model)
        if ready then
          keep[instance] = true
          local record = records[instance]
          if record and (record.mode ~= conf.mode
            or (record.mode == "Model" and (record.gen ~= generation or math.abs(record.height - conf.height) > 0.01))) then
            record.destroy()
            records[instance] = nil
            record = nil
          end
          if not record then
            record = makeEntityRecord(instance, cat)
            records[instance] = record
          end
          if record and record.refresh then record.refresh() end
        end
      end
    end
    for instance, record in pairs(records) do
      if not keep[instance] or not instance.Parent then
        pcall(record.destroy)
        records[instance] = nil
      end
    end
  end

  task.spawn(function()
    while alive do
      pcall(syncRecords)
      task.wait(0.4)
    end
  end)

  -- the companion is an invisible part that glides next to you; the normal replacement pipeline dresses it
  local function updateCompanion()
    if settings.Companion.mode == "Off" then
      if companionPart then
        companionPart:Destroy()
        companionPart = nil
      end
      return
    end
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if not (companionPart and companionPart.Parent) then
      companionPart = Instance.new("Part")
      companionPart.Name = "MoroCompanion"
      companionPart.Anchored, companionPart.CanCollide, companionPart.CanQuery, companionPart.CanTouch = true, false, false, false
      companionPart.Transparency = 1
      companionPart.Size = Vector3.new(1, 1, 1)
      companionPart.CFrame = root.CFrame * CFrame.new(3.2, -2.5, 1.5)
      companionPart.Parent = swapFolder
    end
    local goal = root.CFrame * CFrame.new(3.2, -2.5, 1.5)
    companionPart.CFrame = companionPart.CFrame:Lerp(goal, 0.15)
  end

  local renderConnection = runService.RenderStepped:Connect(function()
    local now = os.clock()
    pcall(updateCompanion)
    for _, record in pairs(records) do
      if record.step then pcall(record.step, now) end
    end
  end)

  -- ------------------------------------------------------------------ room counter (top center)
  local hud = { on = false, showFloor = true, size = 24, color = Color3.fromRGB(255, 150, 90) }
  local hudGui = Instance.new("ScreenGui")
  hudGui.Name = "MoroRoomHud"
  hudGui.ResetOnSpawn = false
  hudGui.IgnoreGuiInset = true
  hudGui.DisplayOrder = 30
  pcall(function() if syn and syn.protect_gui then syn.protect_gui(hudGui) end end)
  hudGui.Parent = (gethui and gethui()) or coreGui

  local hudPill = Instance.new("Frame")
  hudPill.AnchorPoint = Vector2.new(0.5, 0)
  hudPill.Position = UDim2.new(0.5, 0, 0, 16)
  hudPill.Size = UDim2.fromOffset(160, 40)
  hudPill.AutomaticSize = Enum.AutomaticSize.X
  hudPill.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
  hudPill.BackgroundTransparency = 0.2
  hudPill.BorderSizePixel = 0
  hudPill.Visible = false
  hudPill.Parent = hudGui
  local hudCorner = Instance.new("UICorner")
  hudCorner.CornerRadius = UDim.new(0, 12)
  hudCorner.Parent = hudPill
  local hudStroke = Instance.new("UIStroke")
  hudStroke.Thickness = 1.6
  hudStroke.Color = hud.color
  hudStroke.Parent = hudPill
  local hudPadding = Instance.new("UIPadding")
  hudPadding.PaddingLeft, hudPadding.PaddingRight = UDim.new(0, 18), UDim.new(0, 18)
  hudPadding.Parent = hudPill
  local hudText = Instance.new("TextLabel")
  hudText.BackgroundTransparency = 1
  hudText.AutomaticSize = Enum.AutomaticSize.X
  hudText.Size = UDim2.fromOffset(0, 40)
  hudText.Font = Enum.Font.GothamBold
  hudText.RichText = true
  hudText.TextColor3 = Color3.new(1, 1, 1)
  hudText.TextSize = hud.size
  hudText.Parent = hudPill

  local function currentRoomNumber()
    local value = tonumber(localPlayer:GetAttribute("CurrentRoom"))
    if not value then
      local gameData = replicatedStorage:FindFirstChild("GameData")
      local latest = gameData and gameData:FindFirstChild("LatestRoom")
      value = latest and tonumber(latest.Value)
    end
    return value
  end

  local function refreshRoomHud()
    if not hud.on then
      hudPill.Visible = false
      return
    end
    local room = currentRoomNumber()
    local floorName = detectFloor()
    if not room or floorName == "Lobby" or floorName == "" then
      hudPill.Visible = false
      return
    end
    -- the script labels doors with floor offsets (Mines continue after 100, Backdoor counts down from 50)
    if floorName == "Mines" then room = room + 100 elseif floorName == "Backdoor" then room = room - 50 end
    local color = string.format("#%02x%02x%02x", math.floor(hud.color.R * 255 + 0.5), math.floor(hud.color.G * 255 + 0.5), math.floor(hud.color.B * 255 + 0.5))
    local text = 'ROOM  <font color="' .. color .. '">' .. tostring(room) .. "</font>"
    if hud.showFloor then text = '<font color="#9aa0b4">' .. tostring(floorName) .. "</font>   " .. text end
    local signature = text .. "|" .. hud.size .. "|" .. color
    if signature ~= hud.lastSignature then
      hud.lastSignature = signature
      hudText.Text = text
      hudText.TextSize = hud.size
      hudStroke.Color = hud.color
      hudPill.Size = UDim2.fromOffset(0, hud.size + 16)
      hudText.Size = UDim2.fromOffset(0, hud.size + 16)
    end
    hudPill.Visible = true
  end

  local hudConnection = runService.Heartbeat:Connect(function()
    if hud.on then pcall(refreshRoomHud) end
  end)

  library:OnUnload(function()
    alive = false
    pcall(function() renderConnection:Disconnect() end)
    pcall(function() hudConnection:Disconnect() end)
    dropRecords()
    pcall(function() swapFolder:Destroy() end)
    pcall(function() hudGui:Destroy() end)
  end)

  -- ------------------------------------------------------------------ menu (built later from MENU)
  Menus.ModelSwap = function()
    -- HUD
    Groupboxes.Hud = tabs.Visuals:AddLeftGroupbox("HUD")
    Groupboxes.Hud:AddToggle("RoomCounter", {
      Text = "Room Counter", Default = false, Tooltip = "Shows the current room at the top center of the screen",
      Callback = function(value)
        hud.on = value
        if not value then hudPill.Visible = false end
      end,
    })
    toggles.RoomCounter:AddColorPicker("RoomCounterColor", {
      Default = hud.color, Callback = function(color) hud.color = color end,
    })
    Groupboxes.Hud:AddToggle("RoomCounterFloor", {
      Text = "Show Floor Name", Default = true, Callback = function(value) hud.showFloor = value end,
    })
    Groupboxes.Hud:AddSlider("RoomCounterSize", {
      Text = "Text Size", Min = 14, Max = 40, Default = hud.size, Rounding = 0, Callback = function(value) hud.size = value end,
    })

    -- model library
    local library2 = tabs.Visuals:AddLeftGroupbox("Model Library")
    local categoryNames = {}
    for _, cat in ipairs(CATEGORIES) do categoryNames[#categoryNames + 1] = cat.key end
    local libraryTarget, libraryPreset, libraryId, libraryItem = "Players", presetNames[1], "", ""
    local statusRow = library2:AddLabel("Status: nothing loaded. Everything here only changes YOUR screen.")
    statusLabel = statusRow
    library2:AddDropdown("MS_LibraryTarget", {
      Text = "Load Into", Values = categoryNames, Default = "Players", Tooltip = "Which target gets the model you load below",
      Callback = function(value) libraryTarget = value or libraryTarget end,
    })
    library2:AddDropdown("MS_LibraryPreset", {
      Text = "Preset", Values = presetNames, Default = presetNames[1],
      Callback = function(value) libraryPreset = value or libraryPreset end,
    })
    library2:AddButton({ Text = "Load Preset", Callback = function()
      local preset = presetByName[libraryPreset]
      if preset then loadTemplate(libraryTarget, preset[2], preset[3]) end
    end })
    library2:AddInput("MS_LibraryId", {
      Text = "Asset ID", Default = "", Placeholder = "e.g. 138151705692565", Numeric = true,
      Callback = function(text) libraryId = text end,
    })
    library2:AddButton({ Text = "Load Asset ID", Callback = function()
      local id = tonumber(libraryId)
      if id then loadTemplate(libraryTarget, id, false) else say("Model Swap", "Enter a numeric asset id") end
    end })
    library2:AddInput("MS_LibraryItem", {
      Text = "Marketplace Item", Default = "", Placeholder = "bundle / item link or id",
      Callback = function(text) libraryItem = text end,
    })
    library2:AddButton({ Text = "Load Marketplace Item", Callback = function()
      local id, kind = parseItemId(libraryItem)
      if id then loadTemplate(libraryTarget, id, true) else say("Model Swap", kind or "Paste a /bundles/ or /catalog/ link") end
    end })

    local search = tabs.Visuals:AddRightGroupbox("Model Search")
    local keyword, results, chosen = "tung tung sahur", {}, nil
    search:AddLabel("Searches the Roblox toolbox. Scripts and sounds are stripped.")
    search:AddInput("MS_SearchKeyword", {
      Text = "Keyword", Default = keyword, Placeholder = "keyword", Callback = function(text) keyword = text end,
    })
    search:AddDropdown("MS_SearchResults", {
      Text = "Results", Values = { "-" }, Default = "-", Callback = function(value) chosen = value end,
    })
    search:AddButton({ Text = "Search", Callback = function()
      say("Model Swap", "Searching...")
      searchToolbox(keyword, function(list, err)
        if not list then return say("Model Swap", "Search failed: " .. tostring(err), "error") end
        results = {}
        local names = {}
        for _, item in ipairs(list) do
          local label = string.format("%s - %s", item.name:sub(1, 38), item.by)
          local n = 1
          while results[label] do
            n = n + 1
            label = string.format("%s - %s #%d", item.name:sub(1, 34), item.by, n)
          end
          results[label] = item.id
          names[#names + 1] = label
        end
        pcall(function() options.MS_SearchResults._raw.Refresh(names) end)
        say("Model Swap", #names .. " results")
      end)
    end })
    search:AddButton({ Text = "Load Result", Callback = function()
      local id = chosen and results[chosen]
      if id then loadTemplate(libraryTarget, id, false) else say("Model Swap", "Pick a result first") end
    end })

    -- global options
    local globalBox = tabs.Visuals:AddRightGroupbox("Swap Options")
    globalBox:AddToggle("MS_HideEffects", {
      Text = "Hide Original Particles", Default = true, Tooltip = "Also hides smoke / trails of the replaced entity",
      Callback = function(value) options2.hideEffects = value end,
    })
    globalBox:AddButton({ Text = "Remove All Replacements", Callback = function()
      for _, cat in ipairs(CATEGORIES) do
        settings[cat.key].mode = "Off"
        pcall(function() options["MS_" .. cat.key .. "_Mode"]:SetValue("Off") end)
        if templates[cat.key] and templates[cat.key].model then templates[cat.key].model:Destroy() end
        templates[cat.key] = nil
      end
      dropRecords()
      setStatus("Status: cleared")
    end })

    -- one section per target
    for index, cat in ipairs(CATEGORIES) do
      local conf = settings[cat.key]
      local box = (index % 2 == 1) and tabs.Visuals:AddLeftGroupbox("Swap: " .. cat.title) or tabs.Visuals:AddRightGroupbox("Swap: " .. cat.title)
      local flag = "MS_" .. cat.key
      box:AddDropdown(flag .. "_Mode", {
        Text = "Replace With", Values = cat.players and { "Off", "Model" } or { "Off", "Model", "Sprite" }, Default = "Off",
        Tooltip = "Model = the 3D model loaded for this target. Sprite = a flat PNG that always faces you",
        Callback = function(value) conf.mode = value or "Off" end,
      })
      if cat.players then
        box:AddDropdown(flag .. "_Scope", {
          Text = "Who", Values = { "Everyone", "Me only", "Others only" }, Default = "Everyone",
          Callback = function(value) conf.scope = value or "Everyone"; dropRecords() end,
        })
      end
      if cat.key == "Custom" then
        box:AddInput(flag .. "_Names", {
          Text = "Entity Names", Default = "", Placeholder = "model names in workspace, separated by commas",
          Callback = function(text) conf.customNames = text end,
        })
      end
      box:AddSlider(flag .. "_Height", {
        Text = "Height", Min = 1, Max = 30, Default = conf.height, Rounding = 1, Suffix = " st",
        Callback = function(value) conf.height = value end,
      })
      box:AddSlider(flag .. "_Yaw", {
        Text = "Rotation", Min = 0, Max = 360, Default = 0, Rounding = 0, Suffix = " deg",
        Callback = function(value) conf.yaw = value end,
      })
      box:AddSlider(flag .. "_YOff", {
        Text = "Vertical Offset", Min = -5, Max = 5, Default = 0, Rounding = 1,
        Callback = function(value) conf.yoff = value end,
      })
      -- animation, speech bubble and sprites exist for entities only (player models follow the real skeleton)
      if not cat.players then
        box:AddDropdown(flag .. "_Anim", {
          Text = "Animation", Values = { "None", "Bob", "Spin", "Wobble" }, Default = conf.anim,
          Tooltip = "Extra movement on top of the target (Spin is for models, sprites always face you)",
          Callback = function(value) conf.anim = value or "None" end,
        })
        box:AddInput(flag .. "_Bubble", {
          Text = "Speech Bubble", Default = "", Placeholder = "phrases separated with ;",
          Callback = function(text) conf.bubble = text or "" end,
        })
        box:AddInput(flag .. "_Image", {
          Text = "Sprite Image", Default = "", Placeholder = "asset id or link to a PNG",
          Callback = function(text) spriteTexts[cat.key] = text end,
        })
        box:AddButton({ Text = "Load Sprite", Callback = function()
          local image, why = resolveImage(spriteTexts[cat.key])
          if image then
            spriteImages[cat.key] = image
            if conf.mode == "Off" then
              conf.mode = "Sprite"
              pcall(function() options[flag .. "_Mode"]:SetValue("Sprite") end)
            end
            say("Model Swap", cat.title .. ": sprite ready")
          else
            say("Model Swap", why or "Type an asset id or a link to a PNG", "error")
          end
        end })
      end
    end
  end
end)() end

-- =====================================================================
--  FUN: screen filters, character aura, entity disco and entity size
--  Everything here is client-side only and is undone when the toggle goes off or the script unloads.
-- =====================================================================
do (function()
  local alive = true

  -- ------------------------------------------------------------------ screen filter
  local FILTERS = {
    Vaporwave = { tint = Color3.fromRGB(255, 190, 255), saturation = 0.45, contrast = 0.15, brightness = 0.02, bloom = 0.9 },
    Noir = { tint = Color3.new(1, 1, 1), saturation = -1, contrast = 0.35, brightness = -0.03, bloom = 0.1 },
    Sepia = { tint = Color3.fromRGB(255, 226, 180), saturation = -0.3, contrast = 0.1, brightness = 0, bloom = 0.2 },
    Nightmare = { tint = Color3.fromRGB(255, 160, 160), saturation = -0.25, contrast = 0.45, brightness = -0.08, bloom = 0.4 },
    Neon = { tint = Color3.fromRGB(190, 255, 255), saturation = 0.9, contrast = 0.25, brightness = 0, bloom = 1.3 },
  }
  local filter = { preset = "Off", strength = 70 }

  local function removeFilter()
    for _, name in ipairs({ "MoroFilterColor", "MoroFilterBloom" }) do
      local effect = lighting:FindFirstChild(name)
      if effect then effect:Destroy() end
    end
  end

  local function applyFilter()
    local preset = FILTERS[filter.preset]
    if not preset then
      removeFilter()
      return
    end
    local color = lighting:FindFirstChild("MoroFilterColor")
    if not color then
      color = Instance.new("ColorCorrectionEffect")
      color.Name = "MoroFilterColor"
      color.Parent = lighting
    end
    local bloom = lighting:FindFirstChild("MoroFilterBloom")
    if not bloom then
      bloom = Instance.new("BloomEffect")
      bloom.Name = "MoroFilterBloom"
      bloom.Size = 24
      bloom.Threshold = 0.9
      bloom.Parent = lighting
    end
    local k = filter.strength / 100
    color.TintColor = Color3.new(1, 1, 1):Lerp(preset.tint, k)
    color.Saturation = preset.saturation * k
    color.Contrast = preset.contrast * k
    color.Brightness = preset.brightness * k
    bloom.Intensity = preset.bloom * k
  end

  -- ------------------------------------------------------------------ aura on your character
  local AURAS = {
    Sparkles = { texture = "rbxasset://textures/particles/sparkles_main.dds", from = Color3.fromRGB(255, 240, 160), to = Color3.fromRGB(255, 170, 255), rate = 18, speed = 1.5, life = 1.8, size = 0.7, accel = Vector3.new(0, 1, 0), light = 1 },
    Embers = { texture = "rbxasset://textures/particles/fire_main.dds", from = Color3.fromRGB(255, 190, 70), to = Color3.fromRGB(255, 70, 30), rate = 22, speed = 2, life = 1.4, size = 0.6, accel = Vector3.new(0, 3, 0), light = 0.8 },
    Smoke = { texture = "rbxasset://textures/particles/smoke_main.dds", from = Color3.fromRGB(120, 120, 130), to = Color3.fromRGB(40, 40, 50), rate = 12, speed = 1, life = 2.2, size = 2, accel = Vector3.new(0, 1.5, 0), light = 0 },
    Hearts = { texture = "rbxasset://textures/particles/sparkles_main.dds", from = Color3.fromRGB(255, 120, 170), to = Color3.fromRGB(255, 60, 120), rate = 14, speed = 2, life = 2, size = 0.9, accel = Vector3.new(0, 2, 0), light = 1 },
  }
  local aura = { preset = "Off" }
  local auraEmitter, auraRoot

  local function clearAura()
    if auraEmitter then
      pcall(function() auraEmitter:Destroy() end)
      auraEmitter, auraRoot = nil, nil
    end
  end

  local function ensureAura()
    local preset = AURAS[aura.preset]
    if not preset then
      clearAura()
      return
    end
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if auraEmitter and auraRoot == root and auraEmitter.Parent == root and auraEmitter:GetAttribute("Preset") == aura.preset then return end
    clearAura()
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name = "MoroAura"
    emitter:SetAttribute("Preset", aura.preset)
    emitter.Texture = preset.texture
    emitter.Color = ColorSequence.new(preset.from, preset.to)
    emitter.Rate = preset.rate
    emitter.Lifetime = NumberRange.new(preset.life * 0.7, preset.life)
    emitter.Speed = NumberRange.new(preset.speed * 0.5, preset.speed)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, preset.size), NumberSequenceKeypoint.new(1, 0) })
    emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
    emitter.LightEmission = preset.light
    emitter.Acceleration = preset.accel
    emitter.Parent = root
    auraEmitter, auraRoot = emitter, root
  end

  -- ------------------------------------------------------------------ entity disco + size
  local disco = { on = false, speed = 1 }
  local size = { percent = 100 }
  local savedLook = setmetatable({}, { __mode = "k" })    -- part -> { Color, Material }
  local savedScale = setmetatable({}, { __mode = "k" })   -- model -> { base, applied }

  local function restoreDisco()
    for part, look in pairs(savedLook) do
      pcall(function()
        part.Color = look.Color
        part.Material = look.Material
      end)
      savedLook[part] = nil
    end
  end

  local function restoreSizes()
    for model, scale in pairs(savedScale) do
      pcall(function() model:ScaleTo(scale.base) end)
      savedScale[model] = nil
    end
  end

  local lastFunStep = 0
  local funConnection = runService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastFunStep < 0.1 then return end
    lastFunStep = now
    local entities = ESPCategories.Entities or {}

    if disco.on then
      for index, entity in ipairs(entities) do
        if entity.Parent then
          local hue = (now * disco.speed * 0.2 + index * 0.07) % 1
          local counted = 0
          for _, part in ipairs(entity:GetDescendants()) do
            if part:IsA("BasePart") then
              counted = counted + 1
              if counted > 80 then break end
              if not savedLook[part] then savedLook[part] = { Color = part.Color, Material = part.Material } end
              part.Color = Color3.fromHSV(hue, 0.9, 1)
              part.Material = Enum.Material.Neon
            end
          end
        end
      end
    end

    local factor = size.percent / 100
    for _, entity in ipairs(entities) do
      if entity.Parent and entity:IsA("Model") then
        local record = savedScale[entity]
        if factor ~= 1 or record then
          if not record then
            record = { base = entity:GetScale(), applied = 1 }
            savedScale[entity] = record
          end
          if record.applied ~= factor then
            record.applied = factor
            pcall(function() entity:ScaleTo(record.base * factor) end)
          end
        end
      end
    end
  end)

  local auraConnection = runService.Heartbeat:Connect(function()
    if aura.preset ~= "Off" and alive then pcall(ensureAura) end
  end)

  library:OnUnload(function()
    alive = false
    pcall(function() funConnection:Disconnect() end)
    pcall(function() auraConnection:Disconnect() end)
    removeFilter()
    clearAura()
    restoreDisco()
    restoreSizes()
  end)

  -- ------------------------------------------------------------------ menu (built later from MENU)
  Menus.Fun = function()
    Groupboxes.FunFilter = tabs.Visuals:AddLeftGroupbox("Screen Filter")
    Groupboxes.FunFilter:AddDropdown("FunFilterPreset", {
      Text = "Filter", Values = { "Off", "Vaporwave", "Noir", "Sepia", "Nightmare", "Neon" }, Default = "Off",
      Tooltip = "Color grading over the whole screen",
      Callback = function(value)
        filter.preset = value or "Off"
        applyFilter()
      end,
    })
    Groupboxes.FunFilter:AddSlider("FunFilterStrength", {
      Text = "Strength", Min = 10, Max = 100, Default = filter.strength, Rounding = 0, Suffix = " %",
      Callback = function(value)
        filter.strength = value
        applyFilter()
      end,
    })

    Groupboxes.FunAura = tabs.Visuals:AddRightGroupbox("Aura")
    Groupboxes.FunAura:AddDropdown("FunAuraPreset", {
      Text = "Aura", Values = { "Off", "Sparkles", "Embers", "Smoke", "Hearts" }, Default = "Off",
      Tooltip = "Particles around your character (only you see them)",
      Callback = function(value)
        aura.preset = value or "Off"
        if aura.preset == "Off" then clearAura() else pcall(ensureAura) end
      end,
    })

    Groupboxes.FunEntities = tabs.Visuals:AddLeftGroupbox("Entity Fun")
    Groupboxes.FunEntities:AddToggle("FunDisco", {
      Text = "Entity Disco", Default = false, Tooltip = "Entities cycle through neon colors",
      Callback = function(value)
        disco.on = value
        if not value then restoreDisco() end
      end,
    })
    Groupboxes.FunEntities:AddSlider("FunDiscoSpeed", {
      Text = "Disco Speed", Min = 1, Max = 10, Default = 1, Rounding = 1, Callback = function(value) disco.speed = value end,
    })
    Groupboxes.FunEntities:AddSlider("FunEntitySize", {
      Text = "Entity Size", Min = 20, Max = 300, Default = 100, Rounding = 0, Suffix = " %",
      Tooltip = "Visual size of every entity (the real hitbox does not change). 100% = untouched",
      Callback = function(value) size.percent = value end,
    })
  end
end)() end

-- =====================================================================
--  POST FX (ported from the MM2 script): presets, color grading, bloom / rays / blur,
--  depth of field and fog, weather and a vignette. Client-side only.
-- =====================================================================
do (function()
  local PF = { on = false, fx = {}, backup = nil, ui = {} }
  local PF_DEFAULT = {
    b = 0, c = 0, s = 0, tint = Color3.new(1, 1, 1),
    bi = 0, bs = 24, bt = 2, ri = 0, rs = 0.5,
    dof = false, df = 50, dr = 30, dfar = 0, dnear = 0, blur = 0,
    ad = 0.3, ao = 0, ac = Color3.fromRGB(199, 199, 199), adc = Color3.fromRGB(106, 112, 125), ag = 0, ah = 0,
    clock = nil, amb = nil, expo = 0,
  }
  PF.v = {}
  for key, value in pairs(PF_DEFAULT) do PF.v[key] = value end

  local PF_PRESETS = {
    ["Cinematic"] = { b = 0.02, c = 0.22, s = 0.08, tint = Color3.fromRGB(255, 243, 228), bi = 0.7, bs = 32, bt = 0.95, ri = 0.12, rs = 0.7, dof = true, df = 38, dr = 14, dfar = 0.12,
      ad = 0.3, ac = Color3.fromRGB(200, 205, 215), adc = Color3.fromRGB(120, 100, 90), ah = 1, clock = 17.2 },
    ["Neon Night"] = { c = 0.35, s = 0.55, tint = Color3.fromRGB(200, 170, 255), bi = 1.6, bs = 42, bt = 0.75, ad = 0.35, ac = Color3.fromRGB(60, 40, 110), adc = Color3.fromRGB(180, 60, 255), ah = 2,
      clock = 0, amb = Color3.fromRGB(70, 50, 120), expo = 0.1 },
    ["Halloween"] = { c = 0.25, s = 0.35, tint = Color3.fromRGB(255, 170, 90), bi = 0.9, bs = 36, bt = 0.85, ad = 0.5, ac = Color3.fromRGB(255, 120, 40), adc = Color3.fromRGB(120, 30, 150), ah = 2.4,
      clock = 0, amb = Color3.fromRGB(90, 40, 20), expo = 0.15 },
    ["Blood Moon"] = { c = 0.3, s = 0.2, tint = Color3.fromRGB(255, 120, 120), bi = 1.0, bs = 40, bt = 0.8, ad = 0.45, ac = Color3.fromRGB(170, 20, 20), adc = Color3.fromRGB(60, 0, 0), ah = 2,
      clock = 0, amb = Color3.fromRGB(80, 15, 15) },
    ["Vaporwave"] = { c = 0.25, s = 0.6, tint = Color3.fromRGB(255, 190, 245), bi = 1.2, bs = 38, bt = 0.8, ad = 0.3, ac = Color3.fromRGB(255, 130, 220), adc = Color3.fromRGB(90, 200, 255), ah = 1.2,
      clock = 18.2, amb = Color3.fromRGB(120, 80, 150) },
    ["Noir"] = { b = -0.03, c = 0.45, s = -1, tint = Color3.fromRGB(235, 235, 235), bi = 0.3, ad = 0.25, ac = Color3.fromRGB(120, 120, 120), adc = Color3.fromRGB(60, 60, 60), ah = 1.5 },
    ["Frozen"] = { b = 0.04, c = 0.15, s = -0.1, tint = Color3.fromRGB(190, 225, 255), bi = 0.8, bs = 34, bt = 0.9, ri = 0.1, ad = 0.38, ac = Color3.fromRGB(215, 235, 255), adc = Color3.fromRGB(170, 205, 235), ah = 1.4,
      clock = 12 },
    ["Matrix"] = { c = 0.3, s = -0.2, tint = Color3.fromRGB(150, 255, 170), bi = 0.9, bs = 30, bt = 0.85, ad = 0.34, ac = Color3.fromRGB(20, 90, 40), adc = Color3.fromRGB(0, 70, 20), ah = 1.8,
      clock = 0, amb = Color3.fromRGB(10, 70, 25) },
    ["Golden Hour"] = { b = 0.02, c = 0.2, s = 0.2, tint = Color3.fromRGB(255, 220, 170), bi = 0.8, bs = 36, bt = 0.9, ri = 0.3, rs = 0.9, ad = 0.32, ac = Color3.fromRGB(255, 200, 150), adc = Color3.fromRGB(255, 140, 80), ah = 1.2,
      clock = 17.6 },
    ["Dreamy"] = { b = 0.05, c = -0.05, s = 0.25, tint = Color3.fromRGB(255, 235, 250), bi = 1.4, bs = 52, bt = 0.7, dof = true, df = 30, dr = 10, dfar = 0.35, dnear = 0.1, ad = 0.3,
      ac = Color3.fromRGB(240, 220, 255), adc = Color3.fromRGB(255, 200, 230), ah = 1 },
    ["Toxic"] = { c = 0.3, s = 0.5, tint = Color3.fromRGB(190, 255, 120), bi = 1.1, bs = 36, bt = 0.8, ad = 0.45, ac = Color3.fromRGB(110, 190, 20), adc = Color3.fromRGB(40, 90, 0), ah = 2.2,
      clock = 0, amb = Color3.fromRGB(40, 90, 15) },
  }
  local PF_NAMES = { "Cinematic", "Neon Night", "Halloween", "Blood Moon", "Vaporwave", "Noir", "Frozen", "Matrix", "Golden Hour", "Dreamy", "Toxic" }

  local function tween(instance, seconds, props, style)
    local playing = tweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    playing:Play()
    return playing
  end

  local function pfEnsure()
    if PF.fx.cc then return end
    local function make(class, name)
      local effect = Instance.new(class)
      effect.Name = "Moro_" .. name
      effect.Parent = lighting
      return effect
    end
    PF.fx.cc = make("ColorCorrectionEffect", "CC")
    PF.fx.bloom = make("BloomEffect", "Bloom")
    PF.fx.rays = make("SunRaysEffect", "Rays")
    PF.fx.dof = make("DepthOfFieldEffect", "DOF")
    PF.fx.blur = make("BlurEffect", "Blur")
    local existing = lighting:FindFirstChildOfClass("Atmosphere")
    if existing then
      PF.fx.atmo = existing
      PF.atmoBackup = { Density = existing.Density, Offset = existing.Offset, Color = existing.Color, Decay = existing.Decay, Glare = existing.Glare, Haze = existing.Haze }
    else
      PF.fx.atmo = make("Atmosphere", "Atmo")
      PF.atmoOwn = true
    end
    PF.backup = { ClockTime = lighting.ClockTime, Ambient = lighting.Ambient, OutdoorAmbient = lighting.OutdoorAmbient, ExposureCompensation = lighting.ExposureCompensation }
  end

  local function pfApply(smooth)
    if not PF.on then return end
    pfEnsure()
    local v, fx = PF.v, PF.fx
    local seconds = smooth and 1.2 or 0.05
    local function to(instance, props) tween(instance, seconds, props, Enum.EasingStyle.Sine) end
    to(fx.cc, { Brightness = v.b, Contrast = v.c, Saturation = v.s, TintColor = v.tint })
    to(fx.bloom, { Intensity = v.bi, Size = v.bs, Threshold = v.bt })
    to(fx.rays, { Intensity = v.ri, Spread = v.rs })
    fx.dof.Enabled = v.dof
    to(fx.dof, { FocusDistance = v.df, InFocusRadius = v.dr, FarIntensity = v.dfar, NearIntensity = v.dnear })
    to(fx.blur, { Size = v.blur })
    to(fx.atmo, { Density = v.ad, Offset = v.ao, Color = v.ac, Decay = v.adc, Glare = v.ag, Haze = v.ah })
    if v.clock then lighting.ClockTime = v.clock end
    if v.amb then
      lighting.Ambient = v.amb
      lighting.OutdoorAmbient = v.amb
    end
    lighting.ExposureCompensation = v.expo
  end

  local function pfEnable(on)
    PF.on = on
    if on then
      pfEnsure()
      pfApply(true)
    else
      for key, effect in pairs(PF.fx) do
        if key == "atmo" and not PF.atmoOwn then
          for prop, value in pairs(PF.atmoBackup or {}) do pcall(function() effect[prop] = value end) end
        else
          pcall(function() effect:Destroy() end)
        end
      end
      if PF.backup then
        for key, value in pairs(PF.backup) do pcall(function() lighting[key] = value end) end
      end
      PF.fx, PF.backup, PF.atmoBackup, PF.atmoOwn = {}, nil, nil, nil
    end
  end

  local function syncSliders()
    for key, slider in pairs(PF.ui) do
      local value = PF.v[key]
      if typeof(value) == "number" then pcall(function() slider:SetValue(value) end) end
    end
  end

  local function pfPreset(name)
    local preset = PF_PRESETS[name]
    if not preset then return end
    for key, value in pairs(PF_DEFAULT) do PF.v[key] = value end
    for key, value in pairs(preset) do PF.v[key] = value end
    PF.v.clock = preset.clock
    PF.v.amb = preset.amb
    if not PF.on then
      pcall(function() toggles.PostFxEnabled:SetValue(true) end)
      if not PF.on then pfEnable(true) end   -- the control may not call back when set from code
    else
      pfApply(true)
    end
    syncSliders()
  end

  -- ------------------------------------------------------------------ weather
  local WEATHER_KINDS = { "Off", "Snow", "Rain", "Embers", "Fireflies", "Spooky Wisps", "Autumn Leaves", "Confetti" }
  local weather = { part = nil, kind = "Off", height = 0 }
  local postFolder = Instance.new("Folder")
  postFolder.Name = "MoroPostFx"
  postFolder.Parent = workspace

  local function makeEmitter(parent, cfg)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = cfg.tex or "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(cfg.c0, cfg.c1 or cfg.c0)
    emitter.LightEmission = cfg.le or 1
    emitter.Rate = cfg.rate or 30
    emitter.Lifetime = NumberRange.new(cfg.l0 or 0.6, cfg.l1 or 1.3)
    emitter.Speed = NumberRange.new(cfg.s0 or 1, cfg.s1 or 3)
    emitter.SpreadAngle = cfg.spread or Vector2.new(25, 25)
    if cfg.keep then
      emitter.Size = NumberSequence.new(cfg.size or 0.6)
    else
      emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, cfg.size or 0.6), NumberSequenceKeypoint.new(1, 0) })
    end
    emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, cfg.t0 or 0.1), NumberSequenceKeypoint.new(0.8, cfg.t0 or 0.1), NumberSequenceKeypoint.new(1, 1) })
    emitter.Acceleration = cfg.acc or Vector3.zero
    emitter.RotSpeed = NumberRange.new(-120, 120)
    emitter.EmissionDirection = cfg.dir or Enum.NormalId.Top
    if cfg.shape then emitter.Shape = cfg.shape end
    emitter.Parent = parent
    return emitter
  end

  local function setWeather(kind)
    if weather.part then
      weather.part:Destroy()
      weather.part = nil
    end
    weather.kind = kind
    if kind == "Off" then return end
    local part = Instance.new("Part")
    part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
    part.Transparency = 1
    part.Size = Vector3.new(70, 1, 70)
    part.Parent = postFolder
    local box = Enum.ParticleEmitterShape.Box
    if kind == "Snow" then
      makeEmitter(part, { c0 = Color3.new(1, 1, 1), le = 0.3, t0 = 0.05, rate = 380, s0 = 6, s1 = 10, size = 0.55, keep = true, l0 = 3, l1 = 4, spread = Vector2.new(20, 20), dir = Enum.NormalId.Bottom, shape = box })
      weather.height = 16
    elseif kind == "Rain" then
      local emitter = makeEmitter(part, { c0 = Color3.fromRGB(170, 200, 255), le = 0.3, t0 = 0.35, rate = 700, s0 = 70, s1 = 90, size = 0.9, keep = true, l0 = 0.5, l1 = 0.6, spread = Vector2.new(2, 2), dir = Enum.NormalId.Bottom, shape = box })
      emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
      emitter.Squash = NumberSequence.new(-3)
      weather.height = 25
    elseif kind == "Embers" then
      makeEmitter(part, { c0 = Color3.fromRGB(255, 190, 70), c1 = Color3.fromRGB(255, 60, 20), rate = 70, s0 = 3, s1 = 8, size = 0.28, l0 = 3, l1 = 5, spread = Vector2.new(35, 35), acc = Vector3.new(0, 2, 0), shape = box })
      weather.height = -6
    elseif kind == "Fireflies" then
      part.Size = Vector3.new(50, 12, 50)
      local emitter = makeEmitter(part, { c0 = Color3.fromRGB(220, 255, 120), rate = 28, s0 = 0.4, s1 = 1.4, size = 0.32, l0 = 4, l1 = 6, spread = Vector2.new(180, 180), shape = box })
      emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.1), NumberSequenceKeypoint.new(0.5, 0.7), NumberSequenceKeypoint.new(0.75, 0.1), NumberSequenceKeypoint.new(1, 1) })
      emitter.Size = NumberSequence.new(0.32)
      weather.height = 3
    elseif kind == "Spooky Wisps" then
      part.Size = Vector3.new(50, 8, 50)
      makeEmitter(part, { c0 = Color3.fromRGB(170, 90, 255), c1 = Color3.fromRGB(255, 130, 30), rate = 40, s0 = 1, s1 = 3, size = 0.8, l0 = 4, l1 = 6, spread = Vector2.new(60, 60), acc = Vector3.new(0, 1.6, 0), shape = box })
      weather.height = 1
    elseif kind == "Autumn Leaves" then
      makeEmitter(part, { c0 = Color3.fromRGB(255, 150, 40), c1 = Color3.fromRGB(150, 60, 20), le = 0, t0 = 0, rate = 70, s0 = 3, s1 = 5, size = 1.2, keep = true, l0 = 4, l1 = 5, spread = Vector2.new(30, 30), dir = Enum.NormalId.Bottom, shape = box })
      weather.height = 16
    elseif kind == "Confetti" then
      local emitter = makeEmitter(part, { c0 = Color3.fromRGB(255, 80, 120), rate = 200, s0 = 5, s1 = 9, size = 0.9, keep = true, l0 = 3, l1 = 4, spread = Vector2.new(25, 25), dir = Enum.NormalId.Bottom, shape = box })
      emitter.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 110)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
        ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
      })
      emitter.LightEmission = 0.2
      weather.height = 16
    end
    weather.part = part
  end

  local weatherConnection = runService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    if weather.part and camera then
      weather.part.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, weather.height or 30, 0))
    end
  end)

  -- ------------------------------------------------------------------ vignette
  local vignette = { frames = {}, strength = 0, color = Color3.new(0, 0, 0) }
  local vignetteGui = Instance.new("ScreenGui")
  vignetteGui.Name = "MoroVignette"
  vignetteGui.ResetOnSpawn = false
  vignetteGui.IgnoreGuiInset = true
  vignetteGui.DisplayOrder = -5
  pcall(function() if syn and syn.protect_gui then syn.protect_gui(vignetteGui) end end)
  vignetteGui.Parent = (gethui and gethui()) or coreGui
  do
    local edges = {
      { Vector2.new(0, 0), UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0, 0), 90 },
      { Vector2.new(0, 1), UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 1, 0), 270 },
      { Vector2.new(0, 0), UDim2.new(0.3, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
      { Vector2.new(1, 0), UDim2.new(0.3, 0, 1, 0), UDim2.new(1, 0, 0, 0), 180 },
    }
    for _, edge in ipairs(edges) do
      local frame = Instance.new("Frame")
      frame.AnchorPoint, frame.Size, frame.Position = edge[1], edge[2], edge[3]
      frame.BackgroundColor3 = Color3.new(0, 0, 0)
      frame.BorderSizePixel = 0
      frame.Visible = false
      local gradient = Instance.new("UIGradient")
      gradient.Rotation = edge[4]
      gradient.Parent = frame
      frame.Parent = vignetteGui
      vignette.frames[#vignette.frames + 1] = { frame = frame, gradient = gradient }
    end
  end

  local function setVignette(strength, color)
    vignette.strength, vignette.color = strength, color or vignette.color
    for _, entry in ipairs(vignette.frames) do
      entry.frame.Visible = strength > 0.01
      entry.frame.BackgroundColor3 = vignette.color
      entry.gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - strength), NumberSequenceKeypoint.new(1, 1) })
    end
  end

  library:OnUnload(function()
    pfEnable(false)
    setWeather("Off")
    setVignette(0)
    pcall(function() weatherConnection:Disconnect() end)
    pcall(function() postFolder:Destroy() end)
    pcall(function() vignetteGui:Destroy() end)
  end)

  -- ------------------------------------------------------------------ menu (built later from MENU)
  Menus.PostFx = function()
    Groupboxes.PostPresets = tabs.Visuals:AddLeftGroupbox("Post FX Presets")
    Groupboxes.PostPresets:AddToggle("PostFxEnabled", {
      Text = "Post Processing", Default = false, Tooltip = "Color grading, bloom, depth of field and fog over the whole game",
      Callback = function(value) pfEnable(value) end,
    })
    Groupboxes.PostPresets:AddDropdown("PostFxPreset", {
      Text = "Preset", Values = PF_NAMES, Default = PF_NAMES[1],
      Callback = function(value) if value then pfPreset(value) end end,
    })
    Groupboxes.PostPresets:AddButton({ Text = "Reset Values", Callback = function()
      for key, value in pairs(PF_DEFAULT) do PF.v[key] = value end
      pfApply(true)
      syncSliders()
    end })

    local function slider(box, key, name, min, max, decimals, suffix)
      box:AddSlider("PostFx_" .. key, {
        Text = name, Min = min, Max = max, Default = PF.v[key] or min, Rounding = decimals, Suffix = suffix or "",
        Callback = function(value)
          PF.v[key] = value
          pfApply(false)
        end,
      })
      PF.ui[key] = options["PostFx_" .. key]
    end

    Groupboxes.PostGrading = tabs.Visuals:AddLeftGroupbox("Color Grading")
    slider(Groupboxes.PostGrading, "b", "Brightness", -0.5, 0.5, 2)
    slider(Groupboxes.PostGrading, "c", "Contrast", -1, 1, 2)
    slider(Groupboxes.PostGrading, "s", "Saturation", -1, 1.5, 2)
    Groupboxes.PostGrading._raw:AddColorPicker({
      Name = "Tint", Default = Color3.new(1, 1, 1),
      Callback = function(color)
        PF.v.tint = color
        pfApply(false)
      end,
    })
    slider(Groupboxes.PostGrading, "expo", "Exposure", -1.5, 1.5, 2)
    slider(Groupboxes.PostGrading, "clock", "Time of Day", 0, 24, 1, " h")

    Groupboxes.PostBloom = tabs.Visuals:AddRightGroupbox("Bloom / Rays / Blur")
    slider(Groupboxes.PostBloom, "bi", "Bloom Intensity", 0, 3, 2)
    slider(Groupboxes.PostBloom, "bs", "Bloom Size", 0, 56, 0)
    slider(Groupboxes.PostBloom, "bt", "Bloom Threshold", 0, 2, 2)
    slider(Groupboxes.PostBloom, "ri", "Sun Rays", 0, 1, 2)
    slider(Groupboxes.PostBloom, "blur", "Blur", 0, 24, 0)

    Groupboxes.PostDof = tabs.Visuals:AddRightGroupbox("Depth of Field / Fog")
    Groupboxes.PostDof:AddToggle("PostFxDof", {
      Text = "Depth of Field", Default = false,
      Callback = function(value)
        PF.v.dof = value
        pfApply(false)
      end,
    })
    slider(Groupboxes.PostDof, "df", "Focus Distance", 5, 200, 0, " st")
    slider(Groupboxes.PostDof, "dr", "Focus Radius", 2, 100, 0)
    slider(Groupboxes.PostDof, "dfar", "Far Blur", 0, 1, 2)
    slider(Groupboxes.PostDof, "ad", "Fog Density", 0, 0.8, 2)
    slider(Groupboxes.PostDof, "ah", "Haze", 0, 6, 1)

    Groupboxes.PostWeather = tabs.Visuals:AddLeftGroupbox("Weather")
    Groupboxes.PostWeather:AddDropdown("PostFxWeather", {
      Text = "Type", Values = WEATHER_KINDS, Default = "Off",
      Callback = function(value) setWeather(value or "Off") end,
    })

    Groupboxes.PostVignette = tabs.Visuals:AddLeftGroupbox("Vignette")
    Groupboxes.PostVignette:AddSlider("PostFxVignette", {
      Text = "Strength", Min = 0, Max = 100, Default = 0, Rounding = 0, Suffix = " %",
      Callback = function(value) setVignette(value / 100) end,
    })
    Groupboxes.PostVignette._raw:AddColorPicker({
      Name = "Color", Default = Color3.new(0, 0, 0),
      Callback = function(color) setVignette(vignette.strength, color) end,
    })
  end
end)() end

-- =====================================================================
--  MENU
--  Everything above only defines logic and handlers. All tabs, sections,
--  toggles, sliders and buttons are created here, in the order they appear.
-- =====================================================================

Groupboxes.SubfloorsFools = tabs.FoolsHotel:AddLeftGroupbox("Fools")

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
  Text = "Skip Current Room", Tooltip = "Teleports you to the current room's door", Func = Handlers.SkipCurrentRoom, })

Groupboxes.HomeFunctions = tabs.Home:AddLeftGroupbox("Functions & Features")

Groupboxes.Misc = tabs.Miscellaneous:AddLeftGroupbox("Miscellaneous")

Groupboxes.Misc:AddButton({
  Text = "Play Again", Callback = Handlers.PlayAgain, })

Groupboxes.Misc:AddButton({
  Text = "Return to Lobby", Callback = Handlers.ReturnToLobby, })

Groupboxes.Misc:AddButton({
  Text = "Reset Character", Callback = Handlers.ResetCharacter, })

Groupboxes.Misc:AddButton({
  Text = "Give Star Jug", Tooltip = "Gives a star jug", Callback = Handlers.GiveStarJug, })

Groupboxes.Misc:AddDivider()

Groupboxes.Misc:AddToggle("ShowKeybinds", {
  Text = "Show Keybinds", Default = false, Tooltip = "Shows all registered keybinds", })

toggles.ShowKeybinds:OnChanged(function(visible) library.KeybindFrame.Visible = visible end)

Groupboxes.Misc:AddToggle("AntiLag", {
  Text = "Anti-Lag", Default = false, Tooltip = "Reduces lag by setting all parts in the current rooms to Plastic material", })

toggles.AntiLag:OnChanged(Handlers.AntiLagChanged)

Groupboxes.Misc:AddDivider()

Groupboxes.Misc:AddToggle("DisableIdleKick", {
  Text = "Disable Idle Kick", Default = false, Tooltip = "Disables the kick from being afk for 20 minutes", })

toggles.DisableIdleKick:OnChanged(Handlers.DisableIdleKickChanged)

Groupboxes.Misc:AddToggle("DisplayInfo", {
  Text = "Display Info", Default = false, Tooltip = "Shows an overlay with FPS, ping, executor, and username", })

toggles.DisplayInfo:OnChanged(Handlers.DisplayInfoChanged)

Groupboxes.MiscFun = tabs.Miscellaneous:AddRightGroupbox("Fun")

Groupboxes.MiscFun:AddToggle("Uhhhh", {
  Text = "uhhhh", Default = false, Tooltip = "content (this makes a lot of lag btw)", })

toggles.Uhhhh:OnChanged(Handlers.UhhhhChanged)

Groupboxes.MiscFun:AddButton({
  Text = "uhhhh val", Tooltip = "content", Callback = Handlers.UhhhhVal, })

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

toggles.OrbitItems:OnChanged(Handlers.OrbitItemsChanged)

Groupboxes.MiscFun:AddToggle("BringItems", {
  Text = "Bring Items", Default = false, Tooltip = "Floats all dropped items in front of your mouse", })

toggles.BringItems:OnChanged(SetupBringItems)

Groupboxes.MiscFun:AddToggle("TwerkDance", {
  Text = "Twerk", Default = false, Tooltip = "Plays the mspaint twerking animation (i think)", })

toggles.TwerkDance:OnChanged(Handlers.TwerkDanceChanged)

Groupboxes.Character = tabs.Main:AddLeftGroupbox("Character")

Groupboxes.Other = tabs.Main:AddRightGroupbox("Other")

Groupboxes.AutoFarm = tabs.AutoFarm:AddLeftGroupbox("Knob Farm")

Groupboxes.AutoFarm_Settings = tabs.AutoFarm:AddRightGroupbox("Settings")

Groupboxes.AutoFarm:AddToggle("AutoFarmEnabled", {
  Text = "Enable Knob Farm",
  Default = false,
  Tooltip = "Automates traversing rooms, looting gold, solving obstacles, and farming knobs",
})

Groupboxes.AutoFarm_Status = Groupboxes.AutoFarm:AddLabel("Status: Idle")

Groupboxes.AutoFarm:AddDivider()

Groupboxes.AutoFarm_StatsNet = Groupboxes.AutoFarm:AddLabel("Net Profit: +0 Knobs")

Groupboxes.AutoFarm_StatsEarned = Groupboxes.AutoFarm:AddLabel("Total Earned: 0 Knobs")

Groupboxes.AutoFarm_StatsRuns = Groupboxes.AutoFarm:AddLabel("Runs: 0 (Spent: 0)")

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmShowPath", {
  Text = "Show Path (Neon Nodes)",
  Default = true,
  Tooltip = "Renders green neon pathfinding nodes along the walking path (like in the video)",
})

Groupboxes.AutoFarm_Settings:AddDropdown("AutoFarmMovementMode", {
  Text = "Movement Mode",
  Values = { "Straight", "Orthogonal" },
  Default = "Straight",
  Tooltip = "Straight: прямое плавное движение к цели. Orthogonal: движение строго под 90° вдоль осей X и Z.",
})

Groupboxes.AutoFarm_Settings:AddSlider("AutoFarmSpeed", {
  Text = "Farm Speed",
  Min = 16,
  Max = 80,
  Default = 35,
  Rounding = 0,
  Compact = true,
  Tooltip = "Movement speed for navigating paths between rooms and loot (default: 35)",
})

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmLootDrawers", {
  Text = "Loot Drawers & Tables",
  Default = true,
  Tooltip = "Visits nearby drawers, chests, and tables to collect gold",
})

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmRunTo100", {
  Text = "Farm to Door 100",
  Default = true,
  Tooltip = "OFF: фарм до комнаты 49, затем смерть и Play Again (быстрые заходы, для ночного AFK). ON: проходит Библиотеку (50) и доходит до лифта (100).",
})

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmPlayAgain", {
  Text = "Auto Play Again (7s)",
  Default = true,
  Tooltip = "Automatically clicks Play Again 7 seconds after dying or beating the game",
})

Groupboxes.AutoFarm_Settings:AddDivider()

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmMinesMode", {
  Text = "Mines Mode (Ladder Bypass)",
  Default = false,
  Tooltip = "Phase 1: walk to nearest ladder to trigger AC bypass. Phase 2: fly+noclip through all rooms looting everything.",
})

Groupboxes.AutoFarm_Settings:AddToggle("AutoFarmMinesAutoProtect", {
  Text = "Auto-enable Mines Protections",
  Default = true,
  Tooltip = "Automatically enables Vacuum/Snare/Giggle/Gloombat bypass and DisableAnticheat on start",
})

Groupboxes.AutoFarm_Settings:AddSlider("AutoFarmMinesFlySpeed", {
  Text = "Fly Loot Speed",
  Min = 20,
  Max = 80,
  Default = 35,
  Rounding = 0,
  Compact = true,
  Tooltip = "Speed of flight during Phase 2 loot sweep",
})

Groupboxes.AutoDoorSkip = tabs.AutoFarm:AddLeftGroupbox("Auto Door Skip")

Menus.AutoDoorSkip()

Groupboxes.SpamBuy = tabs.Exploits:AddLeftGroupbox("Pre-Run")

Groupboxes.SpamBuy:AddButton({
  Text = "Buy Items", DisabledTooltip = "This feature doesn't work in this floor", Callback = Handlers.BuyItems, })

Groupboxes.SpamBuy:AddSlider("SpamBuyCount", {
  Text = "Purchase Count", Min = 1, Max = 6, Default = 3, Rounding = 0, Compact = true, DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.SpamBuy:AddDropdown("SpamBuyItems", {
  Text = "Items to Buy", Values = { "Lockpick", "Lighter", "Flashlight", "Vitamins", "Crucifix", "Skeleton Key" }, Multi = true, AllowNull = true, DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.SpamBuy:AddToggle("ShowCrucifix", {
  Text = "Show Crucifix", Default = false, Tooltip = "Shows/hides the crucifix in the item shop", DisabledTooltip = "This feature doesn't work in this floor", })

toggles.ShowCrucifix:OnChanged(Handlers.ShowCrucifixChanged)

Groupboxes.SpamBuy:AddToggle("ShowSkeletonKey", {
  Text = "Show Skeleton Key", Default = false, Tooltip = "Shows/hides the skeleton key in the item shop", DisabledTooltip = "This feature doesn't work in this floor", })

toggles.ShowSkeletonKey:OnChanged(Handlers.ShowSkeletonKeyChanged)

Groupboxes.SpamBuy:AddToggle("AutoBuyLockpicks", {
  Text = "Auto Buy Lockpicks (1x)",
  Default = false,
  Tooltip = "Automatically purchases 1 lockpick in pre-run shop",
  DisabledTooltip = "This feature doesn't work in this floor",
})

Groupboxes.SpamBuy:AddToggle("AutoClosePreRunShop", {
  Text = "Auto Close Shop (Confirm)",
  Default = true,
  Tooltip = "Automatically clicks Confirm and closes the pre-run shop",
  DisabledTooltip = "This feature doesn't work in this floor",
})

Groupboxes.SpamBuy:AddButton({
  Text = "Confirm Shop",
  Tooltip = "Clicks Confirm and closes the pre-run shop",
  Callback = Handlers.ConfirmShop,
})

toggles.AutoBuyLockpicks:OnChanged(Handlers.AutoBuyLockpicksChanged)

Groupboxes.Prompts = tabs.Exploits:AddLeftGroupbox("Prompts")

Groupboxes.Prompts:AddToggle("InstantInteract", {
  Text = "Instant Interact", Default = false, Tooltip = "Removes the wait time for interactions e.g. locks", })

Groupboxes.Prompts:AddToggle("PromptClip", {
  Text = "Prompt Clip", Default = false, Tooltip = "Allows you to interact through walls", })

Groupboxes.Prompts:AddToggle("PromptReach", {
  Text = "Prompt Reach", Default = false, Tooltip = "Increases the range of all proximity prompts", })

Groupboxes.Prompts:AddSlider("PromptRange", {
  Text = "Prompt Range", Min = 1, Max = 2, Default = 1, Rounding = 1, Compact = true, })

options.PromptRange:OnChanged(Handlers.PromptRangeChanged)

Groupboxes.Exploits = tabs.Exploits:AddLeftGroupbox("Exploits")

Groupboxes.Exploits:AddToggle("InfiniteItemsToggle", {
  Text = "Infinite Items", Default = false, Tooltip = "Allows you to use lockpicks, shears, skeleton keys, and multitools without draining the usage", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.Exploits:AddToggle("InfiniteCrucifix", {
  Text = "Infinite Crucifix", Default = false, Tooltip = "Performs a glitch that doesn't use up your crucifix when used on a rushlike entity (rush, ambush, a60, a120, blitz), however, this is inconsistent", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.Exploits:AddToggle("AutoHeartbeatMinigame", {
  Text = "Win Heartbeat Minigame", Default = false, Tooltip = "Automatically passes the heartbeat minigame when it starts", DisabledTooltip = "Your executor doesn't support this feature :(", })

Groupboxes.Exploits:AddButton({
  Text = "Fake Revive", Tooltip = "This doesnt always work, and interacting with a bandage will disable it, and will not be able to enable it back. Sometimes you will not be able to fully finish the run, but you can still go through doors/finish", DisabledTooltip = "Your executor doesn't support this feature :(", Callback = Handlers.FakeRevive, })

Groupboxes.CrucifixEverything = tabs.Exploits:AddLeftGroupbox("Crucifix Everything")

Menus.CrucifixEverything()

toggles.InstantInteract:OnChanged(Handlers.InstantInteractChanged)

toggles.PromptClip:OnChanged(Handlers.PromptClipChanged)

toggles.PromptReach:OnChanged(Handlers.PromptReachChanged)

options.PromptRange:OnChanged(Handlers.PromptRangeChanged2)

Groupboxes.Exploits_BypassBox = tabs.Exploits:AddRightTabbox("Bypasses")

Groupboxes.Exploits_Bypasses = Groupboxes.Exploits_BypassBox:AddTab("Bypasses")

Groupboxes.Exploits_Removals = Groupboxes.Exploits_BypassBox:AddTab("Removals")

Groupboxes.Exploits_Damage = Groupboxes.Exploits_BypassBox:AddTab("Damage")

Groupboxes.Exploits_Bypasses:AddToggle("AntiEntityMaster", {
  Text = "Anti-Entity",
  Default = false,
  Tooltip = "Master toggle to protect against selected entities",
})

Groupboxes.Exploits_Bypasses:AddDropdown("AntiEntityList", {
  Text = "Entities Selection",
  Values = { "Giggle", "Dupe", "Eyes", "Lookman", "Gloombat Eggs", "Seek Obstructions", "Vacuum", "Snare" },
  Default = { "Giggle", "Dupe", "Eyes", "Lookman", "Gloombat Eggs", "Seek Obstructions", "Vacuum", "Snare" },
  Multi = true,
  AllowNull = true,
  Tooltip = "Select which entities to protect against",
})

for _, flag in pairs(AntiEntityMapping) do
  createProxyToggle(flag)
end

toggles.AntiEntityMaster:OnChanged(syncAntiEntity)

options.AntiEntityList:OnChanged(syncAntiEntity)

toggles.BypassGiggle:OnChanged(Handlers.BypassGiggleChanged)

toggles.BypassDupe:OnChanged(Handlers.BypassDupeChanged)

toggles.BypassEyes:OnChanged(Handlers.BypassEyesChanged)

toggles.BypassLookman:OnChanged(Handlers.BypassLookmanChanged)

toggles.BypassGloombatEggs:OnChanged(Handlers.BypassGloombatEggsChanged)

toggles.BypassSeekObstructions:OnChanged(Handlers.BypassSeekObstructionsChanged)

toggles.BypassVacuum:OnChanged(Handlers.BypassVacuumChanged)

toggles.BypassSnare:OnChanged(Handlers.BypassSnareChanged)

Groupboxes.Exploits_Removals:AddToggle("RemoveScreech", {
  Text = "Remove Screech",
  Default = false,
  Tooltip = "Prevents 'Screech' from spawning and destroys active Screech.",
})

Groupboxes.Exploits_Removals:AddToggle("RemoveHalt", {
  Text = "Remove Halt",
  Default = false,
  Tooltip = "Prevents 'Halt' from spawning.",
})

Groupboxes.Exploits_Removals:AddDivider()

Groupboxes.Exploits_Removals:AddToggle("RemoveMaster", {
  Text = "Remove Features",
  Default = false,
  Tooltip = "Master toggle to remove selected features/sounds/delays",
})

Groupboxes.Exploits_Removals:AddDropdown("RemoveList", {
  Text = "Removals Selection",
  Values = { "A-90", "Dread", "Footstep Sounds", "Jammin Music", "Interacting Sounds", "Haste Sound", "Closet Delay" },
  Default = { "A-90", "Dread", "Footstep Sounds", "Jammin Music", "Interacting Sounds", "Haste Sound", "Closet Delay" },
  Multi = true,
  AllowNull = true,
  Tooltip = "Select which features/sounds to remove",
})

for _, flag in pairs(RemoveMapping) do
  createProxyToggle(flag)
end

toggles.RemoveMaster:OnChanged(syncRemove)

options.RemoveList:OnChanged(syncRemove)

toggles.RemoveScreech:OnChanged(Handlers.RemoveScreechChanged)

toggles.RemoveHalt:OnChanged(Handlers.RemoveHaltChanged)

toggles.RemoveA90:OnChanged(Handlers.RemoveA90Changed)

toggles.RemoveDread:OnChanged(Handlers.RemoveDreadChanged)

toggles.RemoveFootstepSounds:OnChanged(Handlers.RemoveFootstepSoundsChanged)

toggles.RemoveJamminMusic:OnChanged(Handlers.RemoveJamminMusicChanged)

toggles.RemoveInteractingSounds:OnChanged(Handlers.RemoveInteractingSoundsChanged)

Groupboxes.Exploits_Damage:AddToggle("NoDamageMaster", {
  Text = "No Damage",
  Default = false,
  Tooltip = "Master toggle to prevent damage from selected entities",
})

Groupboxes.Exploits_Damage:AddDropdown("NoDamageList", {
  Text = "No Damage Selection",
  Values = { "Screech", "A-90", "Halt" },
  Default = { "Screech", "A-90", "Halt" },
  Multi = true,
  AllowNull = true,
  Tooltip = "Select entities that should not damage you",
})

for _, flag in pairs(NoDamageMapping) do
  createProxyToggle(flag)
end

toggles.NoDamageMaster:OnChanged(syncNoDamage)

options.NoDamageList:OnChanged(syncNoDamage)

toggles.NoScreechDamage:OnChanged(Handlers.NoScreechDamageChanged)

toggles.NoHaltDamage:OnChanged(Handlers.NoHaltDamageChanged)

toggles.NoA90Damage:OnChanged(Handlers.NoA90DamageChanged)

Groupboxes.Exploits_Automation = tabs.Exploits:AddRightGroupbox("Automation")

Groupboxes.Exploits_Automation:AddToggle("AutoUnlockPadlockToggle", {
  Text = "Auto Unlock Padlock", Default = false, Tooltip = "Instantly unlocks the room 50 padlock when you get close, but you need the books required", DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.Exploits_Automation:AddButton({
  Text = "Show Library Code", Tooltip = "Displays the current library code in a notification", DisabledTooltip = "This feature doesn't work in this floor", Callback = Handlers.ShowLibraryCode, })

Groupboxes.Exploits_Automation:AddToggle("AutoBreakerBox", {
  Text = "Auto Breaker Box", Default = false, Tooltip = "Automatically solves the breaker box.", DisabledTooltip = "This feature doesn't work in this floor", })

Groupboxes.Exploits_Automation:AddDropdown("BreakerBoxMethod", {
  Text = "Breaker Box Method", Values = { "Instant", "Legit" }, Default = 1, Multi = false, })

Groupboxes.Exploits_Automation:AddToggle("AutoLibraryBruteForce", {
  Text = "Auto Brute-Force Padlock", Default = false, Tooltip = "Automatically brute-forces codes in the library code when near the padlock until it finds the correct code", DisabledTooltip = "This feature doesn't work in this floor", })

toggles.InfiniteCrucifix:OnChanged(Handlers.InfiniteCrucifixChanged)

toggles.AutoBreakerBox:OnChanged(Handlers.AutoBreakerBoxChanged)

Groupboxes.Character:AddToggle("EnableWalkspeed", {
  Text = "Enable Walkspeed", Default = false, Tooltip = "Enables custom walkspeed modification", })

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

toggles.Godmode:OnChanged(Handlers.GodmodeChanged)

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

Groupboxes.PhantomNoclip = tabs.Main:AddRightGroupbox("Phantom Noclip")

Menus.PhantomNoclip()

toggles.EnableWalkspeed:OnChanged(refreshWalkspeed)

options.Walkspeed:OnChanged(refreshWalkspeed)

options.SpeedBypassMode:OnChanged(refreshWalkspeed)

toggles.FlyToggle:OnChanged(Handlers.FlyToggleChanged)

toggles.RemoveAcceleration:OnChanged(Handlers.RemoveAccelerationChanged)

toggles.EnableCharacterJump:OnChanged(Handlers.EnableCharacterJumpChanged)

toggles.EnableCharacterSlide:OnChanged(Handlers.EnableCharacterSlideChanged)

toggles.Noclip:OnChanged(refreshNoclip)

toggles.Phase:OnChanged(refreshPhase)

toggles.AnticheatManipulation:OnChanged(Handlers.AnticheatManipulationChanged)

toggles.AutoInteract:OnChanged(Handlers.AutoInteractChanged)

toggles.InfiniteJumps:OnChanged(refreshInfiniteJump)

Groupboxes.Visuals_ESP = tabs.Visuals:AddLeftGroupbox("Targets")

Groupboxes.Visuals_Preset = tabs.Visuals:AddRightGroupbox("ESP Preset")

Groupboxes.Visuals_Style = tabs.Visuals:AddLeftGroupbox("Chams & Boxes")

Groupboxes.Visuals_Labels = tabs.Visuals:AddLeftGroupbox("Labels")

Groupboxes.Visuals_Tracers = tabs.Visuals:AddRightGroupbox("Tracers & Arrows")

Groupboxes.Visuals_Settings = tabs.Visuals:AddRightGroupbox("Colors")

addESPCategoryControls("Entities", "Entities")

Groupboxes.Visuals_ESP:AddDropdown("EntitiesESPAllowed", {
  Text = "Allowed Entities", Values = {
    "Rush", "Ambush", "A-60", "A-120", "Eyes", "Lookman", "Figure", "Backdoor Rush", "Backdoor Lookman", "Groundskeeper", "Gloombat Swarm", "Glitch Rush", "Glitch Ambush", "Frozen Ambush", "Monument", "Jeff the Killer", "Sally", "Dupe", "Giggle", "Snare", "Gloombat Eggs", "Grumble", "Bash", "Drones", "Electric Puddle", "Teller", "Scribbles", "Noise", "Creak", }, Multi = true, AllowNull = true, Tooltip = "Only show ESP for selected entities (leave empty to show all)", })

addESPCategoryControls("Doors", "Doors")

addESPCategoryControls("Keys", "Keys")

addESPCategoryControls("Objectives", "Objectives")

addESPCategoryControls("Items", "Items")

addESPCategoryControls("Gold", "Coins")

addESPCategoryControls("Chests", "Chests")

addESPCategoryControls("HidingSpots", "Hiding Spots")

Groupboxes.Visuals_ESP:AddToggle("PlayersESP", { Text = "Players", Default = false })

toggles.PlayersESP:AddColorPicker("PlayersESPColor", {
  Text = "Players", Default = Color3.fromRGB(255, 255, 255), })

toggles.PlayersESP:OnChanged(Handlers.PlayersESPChanged)

options.PlayersESPColor:OnChanged(Handlers.PlayersESPColorChanged)

refreshPlayersESP()

Groupboxes.Visuals_Style:AddToggle("ESPFade", {
  Text = "ESP Fade", Default = false, Tooltip = "Enables smooth fading effect on ESP highlights", })

Groupboxes.Visuals_Style:AddSlider("ESPFadeTime", {
  Text = "Fade Time", Min = 0, Max = 1, Default = 0.25, Rounding = 2, Compact = true, Suffix = "s", })

Groupboxes.Visuals_Tracers:AddToggle("ESPArrowsToggle", {
  Text = "Enable Arrows", Default = true, Tooltip = "Shows arrows that point to off-screen objects", })

Groupboxes.Visuals_Tracers:AddSlider("ESPArrowsRadius", {
  Text = "Arrow Radius", Min = 100, Max = 500, Default = 250, Rounding = 0, Compact = true, Suffix = " px", })

Groupboxes.ArchivesMain = tabs.Archives:AddLeftGroupbox("Archives")

Groupboxes.ArchivesMain:AddToggle("BypassDrones", {
  Text = "Bypass Drones",
  Default = false,
  Tooltip = "Prevents 'Drones' from attacking you by disabling walk triggers.",
})

Groupboxes.ArchivesMain:AddToggle("AntiDrone", {
  Text = "Anti Drone",
  Default = false,
  Tooltip = "Prevents you from bumping/falling over when walking into (singular) drones",
})

Groupboxes.ArchivesMain:AddToggle("BypassDronesStampede", {
  Text = "Stop Time/Anti Stampede",
  Default = false,
  Tooltip = "Prevents 'The Drones Stampede' from attacking you by looking at the clock.",
})

Groupboxes.ArchivesMain:AddToggle("DisableDroneStampede", {
  Text = "Disable Drone Stampede (FE)",
  Default = false,
  Tooltip = "Disables the drone stampede from spawning FE",
})

Groupboxes.ArchivesMain:AddToggle("TimeShower", {
  Text = "Time Shower",
  Default = false,
  Tooltip = "Shows the Archives clock time on your screen.",
})

Groupboxes.ArchivesMain:AddToggle("DroneTimer", {
  Text = "Drone Stampede Timer",
  Default = false,
  Tooltip = "Notifies you 60s and 30s before the 05:00 and 09:00 drone stampede",
})

Groupboxes.ArchivesMain:AddDivider()

Groupboxes.ArchivesMain:AddToggle("BypassWater", {
  Text = "Bypass Electric Water",
  Default = false,
  Tooltip = "Creates a safe collision platform above electric water to walk freely.",
})

Groupboxes.ArchivesMain:AddToggle("AntiElectricPuddle", {
  Text = "Anti Electric Puddle",
  Default = false,
  Tooltip = "Moves your character above to not step on electric puddles",
})

Groupboxes.ArchivesMain:AddToggle("BypassAlma", {
  Text = "Bypass Alma",
  Default = false,
  Tooltip = "Prevents 'Alma' from spawning by destroying it.",
})

Groupboxes.ArchivesMain:AddToggle("NoAlmaDamage", {
  Text = "Anti Alma",
  Default = false,
  Tooltip = "Prevents alma from ever interacting with you/you can look at her freely",
})

Groupboxes.ArchivesMain:AddDivider()

Groupboxes.ArchivesMain:AddToggle("AntiClosetTrash", {
  Text = "Anti Closet Trash",
  Default = false,
  Tooltip = "Prevents closet trash (binders, shoes, shelves) from spawning.",
})

Groupboxes.ArchivesMain:AddToggle("ForgetMeNotSolver", {
  Text = "Forget Me Not Skipper",
  Default = false,
  Tooltip = "Automatically solves and skips Forget Me Not doors.",
})

Groupboxes.ArchivesMain:AddToggle("HonchoCorrectBoxESP", {
  Text = "Honcho Correct Box ESP",
  Default = false,
  Tooltip = "ESPs the Archives Correct Boxes for Honcho minigame.",
})

Groupboxes.ArchivesMain:AddToggle("AntiRansom", {
  Text = "Anti Ransom",
  Default = false,
  Tooltip = "Prevents 'Ransom' from attacking you.",
})

Groupboxes.ArchivesMain:AddToggle("AntiScribbles", {
  Text = "Bypass Scribbles",
  Default = false,
  Tooltip = "Prevents 'Scribbles' from attacking you.",
})

toggles.BypassDrones:OnChanged(Handlers.BypassDronesChanged)

toggles.BypassDronesStampede:OnChanged(Handlers.BypassDronesStampedeChanged)

toggles.DisableDroneStampede:OnChanged(Handlers.DisableDroneStampedeChanged)

toggles.TimeShower:OnChanged(Handlers.TimeShowerChanged)

toggles.DroneTimer:OnChanged(Handlers.DroneTimerChanged)

toggles.BypassWater:OnChanged(Handlers.BypassWaterChanged)

toggles.AntiElectricPuddle:OnChanged(Handlers.AntiElectricPuddleChanged)

toggles.BypassAlma:OnChanged(Handlers.BypassAlmaChanged)

toggles.NoAlmaDamage:OnChanged(Handlers.NoAlmaDamageChanged)

toggles.AntiClosetTrash:OnChanged(Handlers.AntiClosetTrashChanged)

toggles.ForgetMeNotSolver:OnChanged(Handlers.ForgetMeNotSolverChanged)

toggles.HonchoCorrectBoxESP:OnChanged(Handlers.HonchoCorrectBoxESPChanged)

toggles.AntiRansom:OnChanged(Handlers.AntiRansomChanged)

toggles.AntiScribbles:OnChanged(Handlers.AntiScribblesChanged)

Groupboxes.ArchivesBypass = tabs.Archives:AddRightGroupbox("Anticheat Bypass")

Groupboxes.ArchivesBypass:AddToggle("ArchiveChairFly", {
  Text = "Chair Anticheat Bypass", Default = false, Tooltip = "Allows you to bypass the anticheat by flying on a chair, allowing you to noclip and fly freely, drag an office chair, then sit in it and press the 'Start Bypass' button", })

Groupboxes.ArchivesBypass:AddSlider("ArchiveChairFlySpeed", {
  Text = "Chair Speed", Min = 15, Max = 150, Default = 55, Rounding = 0, })

Groupboxes.ArchivesBypass:AddButton({
  Text = "Start Bypass", Tooltip = "Press this AFTER you have dragged the chair and sat in it, shift to go down and ctrl and then space to exit (or just turn off the toggle)", Callback = Handlers.StartBypass, })

toggles.ArchiveChairFly:OnChanged(Handlers.ArchiveChairFlyChanged)

Groupboxes.ArchivesAddons = tabs.Archives:AddRightGroupbox("Archives Addons")

Menus.ArchivesLocker()

Menus.ArchivesWaterCooler()

Groupboxes.StairwellMain = tabs.Stairwell:AddLeftGroupbox("Stairwell")

Groupboxes.StairwellMain:AddToggle("StairwellChairFly", {
  Text = "Chair Anticheat Bypass", Default = false, Tooltip = "Allows you to bypass the anticheat by flying on a chair, allowing you to noclip and fly freely, drag an office chair, then sit in it and press the 'Start Bypass' button", })

Groupboxes.StairwellMain:AddSlider("StairwellChairFlySpeed", {
  Text = "Chair Speed", Min = 15, Max = 150, Default = 55, Rounding = 0, })

Groupboxes.StairwellMain:AddButton({
  Text = "Start Bypass", Tooltip = "Press this AFTER you have dragged the chair and sat in it, shift to go down and ctrl and then space to exit (or just turn off the toggle)", Callback = Handlers.StartBypass2, })

toggles.StairwellChairFly:OnChanged(Handlers.StairwellChairFlyChanged)

Groupboxes.StairwellExperimental = tabs.Stairwell:AddRightGroupbox("Experimental")

Groupboxes.StairwellExperimental:AddButton({
  Text = "Bring Dropped Items",
  Func = function() BringDroppedItems() end,
  DoubleClick = false,
  Tooltip = "Brings all dropped items to your character.",
})

Groupboxes.StairwellExperimental:AddToggle("EnableDroppedItemsInterval", {
  Text = "Enable Interval",
  Default = false,
  Tooltip = "Automatically brings dropped items at the selected interval.",
})

Groupboxes.StairwellExperimental:AddSlider("DroppedItemsInterval", {
  Text = "Interval",
  Default = 1,
  Min = 0,
  Max = 60,
  Rounding = 1,
  Compact = false,
  Tooltip = "How often dropped items are brought (seconds).",
})

toggles.EnableDroppedItemsInterval:OnChanged(Handlers.EnableDroppedItemsIntervalChanged)

Groupboxes.StairwellExperimental:AddDivider()

Groupboxes.StairwellExperimental:AddToggle("AntiNoise", {
  Text = "Anti Noise",
  Default = false,
  Tooltip = "Prevents the game from making noise when moving.",
})

Groupboxes.StairwellExperimental:AddToggle("BypassNoise", {
  Text = "Noise Tv Breaker",
  Default = false,
  Tooltip = "Breaks the tv of noise while holding it.",
})

toggles.AntiNoise:OnChanged(Handlers.AntiNoiseChanged)

toggles.BypassNoise:OnChanged(Handlers.BypassNoiseChanged)

Groupboxes.SubfloorsRooms = tabs.Rooms:AddLeftGroupbox("Rooms")

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

Groupboxes.SubfloorsOutdoors = tabs.Garden:AddLeftGroupbox("Outdoors")

Groupboxes.SubfloorsOutdoors:AddToggle("NoSurgeDamage", {
  Text = "No Surge Damage", Default = false, Tooltip = "Prevents Surge from hurting you", })

toggles.NoSurgeDamage:OnChanged(Handlers.NoSurgeDamageChanged)

Groupboxes.SubfloorsOutdoors:AddToggle("RemoveSurge", {
  Text = "Remove Surge", Default = false, Tooltip = "Prevents Surge from spawning", })

toggles.RemoveSurge:OnChanged(Handlers.RemoveSurgeChanged)

Groupboxes.SubfloorsOutdoors:AddToggle("RemoveMandrake", {
  Text = "Disable Mandrake (FE)", Default = false, Tooltip = "Prevents mandrakes from attacking you, but this is inconsistent", })

toggles.RemoveMandrake:OnChanged(Handlers.RemoveMandrakeChanged)

Groupboxes.SubfloorsOutdoors:AddToggle("ShowEyestalkPathToggle", {
  Text = "Show Eyestalk Path", Default = false, Tooltip = "Shows you the correct path in the eyestalk chase", })

toggles.ShowEyestalkPathToggle:AddColorPicker("ShowEyestalkPathColor", {
  Text = "Eyestalk Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0, })

toggles.ShowEyestalkPathToggle:OnChanged(function(value)
  setPathTransparency(worldObjects.EyestalkHighlights, "ShowEyestalkPathColor", value)
end)

options.ShowEyestalkPathColor:OnChanged(function(value) setPathColor(worldObjects.EyestalkHighlights, value) end)

tabs.Garden:SetVisible(false)

toggles.BypassKillbricks:OnChanged(Handlers.BypassKillbricksChanged)

toggles.BypassSeekingWall:OnChanged(Handlers.BypassSeekingWallChanged)

toggles.BypassBanana:OnChanged(Handlers.BypassBananaChanged)

toggles.BypassJeff:OnChanged(Handlers.BypassJeffChanged)

toggles.RemoveSeekTrigger:OnChanged(Handlers.RemoveSeekTriggerChanged)

toggles.AutoRoomSkip:OnChanged(Handlers.AutoRoomSkipChanged)

toggles.RemoveFigure:OnChanged(Handlers.RemoveFigureChanged)

toggles.FigureGodmode:OnChanged(function(_) end)

for key, ObstructionName in pairs(ObstructionNames) do
  local flag = key

  toggles[ObstructionName]:OnChanged(function(value)
    for _, descendant in workspace:GetDescendants() do
      if descendant.Name == flag and descendant:IsA("Model") then
        if value then
          descendant:PivotTo(CFrame.new(-10000, -10000, -10000))
        else
          local originalPosition = descendant:GetAttribute("OriginalPosition")

          if originalPosition then
            if typeof(originalPosition) == "string" then
              local success, result = pcall(function()
                return httpService:JSONDecode(originalPosition)
              end)

              if success and typeof(result) == "table" then
                descendant:PivotTo(CFrame.new(unpack(result)))
              end
            elseif typeof(originalPosition) == "table" and #originalPosition >= 12 then
              descendant:PivotTo(CFrame.new(unpack(originalPosition)))
            end
          end
        end
      end
    end
  end)
end

toggles.RoomsAutoWalkShowPathToggle:OnChanged(Handlers.RoomsAutoWalkShowPathToggleChanged)

options.RoomsAutoWalkShowPathColor:OnChanged(Handlers.RoomsAutoWalkShowPathColorChanged)

toggles.RoomsAutoWalk:OnChanged(Handlers.RoomsAutoWalkChanged)

watchFloorValue()

Groupboxes.MinesLadder = tabs.Mines:AddLeftGroupbox("Ladders")

Groupboxes.MinesLadder:AddToggle("LaddersESP", { Text = "Ladders", Default = false })

toggles.LaddersESP:AddColorPicker("LaddersESPColor", {
  Text = "Ladders", Default = Color3.fromRGB(255, 255, 0), })

Groupboxes.MinesLadder:AddToggle("LaddersTracers", { Text = "Ladders Tracers", Default = false })

toggles.LaddersTracers:OnChanged(Handlers.LaddersTracersChanged)

toggles.LaddersESP:OnChanged(Handlers.LaddersESPChanged)

options.LaddersESPColor:OnChanged(Handlers.LaddersESPColorChanged)

Groupboxes.MinesAnticheat = tabs.Mines:AddLeftGroupbox("Anticheat")

Groupboxes.MinesAnticheat:AddToggle("DisableAnticheat", {
  Text = "Anticheat Bypass", Default = false, Tooltip = "Completely disables the anticheat, after interacting with a ladder.", })

toggles.DisableAnticheat:OnChanged(Handlers.DisableAnticheatChanged)

Groupboxes.MinesAnticheat:AddDivider()

Groupboxes.MinesAnticheat:AddToggle("RemoveFigureMines", {
  Text = "Delete Figure", Default = false, Tooltip = "Removes Figure, however this is inconsistent", DisabledTooltip = "Your executor doesn't support this feature :(", })

toggles.RemoveFigureMines:OnChanged(Handlers.RemoveFigureMinesChanged)

Groupboxes.MinesAutomation = tabs.Mines:AddRightGroupbox("Automation")

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

toggles.MinecartTeleport:OnChanged(Handlers.MinecartTeleportChanged)

Groupboxes.MinesAutomation:AddButton({
  Text = "Complete Door 200", Tooltip = "Automatically teleports to and interacts with each water pump to complete the Dam Seek", Callback = Handlers.CompleteDoor200, })

toggles.AutoSolveAnchors:OnChanged(Handlers.AutoSolveAnchorsChanged)

Groupboxes.MinesVisuals = tabs.Mines:AddRightGroupbox("Visuals")

Groupboxes.MinesVisuals:AddToggle("ShowSeekPathToggle", {
  Text = "Show Seek Path", Default = false, Tooltip = "Shows you the correct path in the seek chase", })

toggles.ShowSeekPathToggle:AddColorPicker("ShowSeekPathColor", {
  Text = "Seek Path", Default = Color3.fromRGB(0, 255, 0), Transparency = 0, })

toggles.ShowSeekPathToggle:OnChanged(function(value)
  setPathTransparency(worldObjects.SeekHighlights, "ShowSeekPathColor", value)
end)

options.ShowSeekPathColor:OnChanged(function(value) setPathColor(worldObjects.SeekHighlights, value) end)

toggles.AutoSteerMinecart:OnChanged(Handlers.AutoSteerMinecartChanged)

Groupboxes.Visuals_Camera = tabs.Visuals:AddRightGroupbox("Camera")

Groupboxes.Visuals_Camera:AddToggle("Fullbright", {
  Text = "Fullbright", Default = false, Tooltip = "Makes your game very bright, and removes shadows", })

Groupboxes.Visuals_Camera:AddSlider("FullbrightBrightness", {
  Text = "Brightness Level", Default = 3, Min = 1, Max = 10, Rounding = 1, Compact = true, })

toggles.Fullbright:OnChanged(Handlers.FullbrightChanged)

Groupboxes.Visuals_Camera:AddToggle("AmbientToggle", {
  Text = "Ambient", Default = false, Tooltip = "Changes the lighting color to the specified value", })

toggles.AmbientToggle:AddColorPicker("AmbientColor", {
  Text = "Ambient", Default = Color3.fromRGB(255, 255, 255), Transparency = 0, })

toggles.AmbientToggle:OnChanged(Handlers.AmbientToggleChanged)

options.AmbientColor:OnChanged(Handlers.AmbientColorChanged)

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

toggles.ThirdPerson:OnChanged(refreshThirdPerson)

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

toggles.FreecamToggle:OnChanged(Handlers.FreecamToggleChanged)

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

Groupboxes.Visuals_Camera:AddToggle("RemoveCutscenes", {
  Text = "Remove Cutscenes", Default = false, Tooltip = "Removes cutscenes that aren't needed for progression", })

toggles.RemoveCutscenes:OnChanged(Handlers.RemoveCutscenesChanged)

Groupboxes.Visuals_Style:AddToggle("ESPRainbow", { Text = "Rainbow ESP", Default = false })

Groupboxes.Visuals_Settings:AddDivider()

Groupboxes.Visuals_Tracers:AddToggle("TracersMaster", {
  Text = "Tracers",
  Default = true,
  Tooltip = "Master toggle for tracers",
})

Groupboxes.Visuals_Tracers:AddDropdown("TracersList", {
  Text = "Tracers Selection",
  Values = { "Entities", "Doors", "Keys", "Objectives", "Items", "Coins", "Chests", "Hiding Spots" },
  Default = { "Entities", "Doors", "Keys", "Objectives" },
  Multi = true,
  AllowNull = true,
  Tooltip = "Select which categories to show tracers for",
})

for _, TracerCategory in ipairs(TracerCategories) do
  local category = TracerCategory
  local text = category .. "Tracers"
  local _ = ESPToggleKeys[category]
  createProxyToggle(text)

  toggles[text]:OnChanged(function(value)
    for _, object in ipairs(ESPCategories[category]) do
      local target = GetESPTarget(object, category)

      if target then
        loader:SetTracersEnabled(target, value)
      end
    end
  end)
end

toggles.TracersMaster:OnChanged(syncTracers)

options.TracersList:OnChanged(syncTracers)

syncTracers()

Groupboxes.Visuals_Tracers:AddDropdown("ESPTracerOrigin", {
  Text = "Tracer Origin", Values = { "Top", "Middle", "Bottom" }, Default = 3, })

Groupboxes.Visuals_Labels:AddToggle("ESPShowText", { Text = "Show ESP Text", Default = true })

Groupboxes.Visuals_Labels:AddToggle("ESPShowDistance", {
  Text = "Show Distance", Default = true, })

Groupboxes.Visuals_Labels:AddSlider("ESPTextSize", {
  Text = "Text Size", Min = 8, Max = 24, Default = 14, Rounding = 0, Compact = true, })

Groupboxes.Visuals_Labels:AddDropdown("ESPTextFont", {
  Text = "Text Font", Values = {
    "Legacy", "Arial", "ArialBold", "SourceSans", "SourceSansBold", "SourceSansLight", "SourceSansItalic", "Bodoni", "Garamond", "Cartoon", "Code", "Highway", "SciFi", "Arcade", "Fantasy", "Antique", "SourceSansSemibold", "Gotham", "GothamMedium", "GothamBold", "GothamBlack", "AmaticSC", "Bangers", "Creepster", "DenkOne", "Fondamento", "FredokaOne", "GrenzeGotisch", "IndieFlower", "JosefinSans", "Jura", "Kalam", "LuckiestGuy", "Merriweather", "Michroma", "Nunito", "Oswald", "PatrickHand", "PermanentMarker", "Roboto", "RobotoCondensed", "RobotoMono", "Sarpanch", "SpecialElite", "TitilliumWeb", "Ubuntu", }, Default = 20, })

Groupboxes.Visuals_Style:AddSlider("ESPRenderLimit", {
  Text = "Chams Limit", Min = 5, Max = 31, Default = 31, Tooltip = "Roblox draws at most ~31 highlights: only the nearest objects get chams, the rest keep boxes and labels", Rounding = 0, Compact = true, })

Groupboxes.Visuals_Style:AddSlider("ESPMaxDistance", {
  Text = "ESP Distance", Min = 50, Max = 500, Default = 250, Rounding = 0, Compact = true, Suffix = " studs", })

Groupboxes.Visuals_Settings:AddDivider()

Groupboxes.Visuals_Settings:AddToggle("UseESPOutlineColour", {
  Text = "Match Outline To ESP Colour", Default = true, Tooltip = "Makes the outline of all ESP the same colour as the ESP itself", })

toggles.UseESPOutlineColour:AddColorPicker("ESPOutline", {
  Text = "ESP Outline", Default = Color3.fromRGB(255, 255, 255), })

Groupboxes.Visuals_Settings:AddSlider("ESPFillTransparency", {
  Text = "Fill Transparency", Min = 0, Max = 1, Default = 0.6, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPOutlineTransparency", {
  Text = "Outline Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPTextTransparency", {
  Text = "Text Transparency", Min = 0, Max = 1, Default = 0, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Settings:AddSlider("ESPTextOutlineTransparency", {
  Text = "Text Outline Transparency", Min = 0, Max = 1, Default = 0.4, Rounding = 2, Compact = true, })

Groupboxes.Visuals_Tracers:AddSlider("ESPTracerThickness", {
  Text = "Tracer Thickness", Min = 0.5, Max = 2, Default = 0.75, Rounding = 2, Compact = true, })

Menus.ESPLook()
Menus.ModelSwap()
Menus.Fun()
Menus.PostFx()

Groupboxes.Visuals_Notifs = tabs.Visuals:AddLeftGroupbox("Entity Notifications")

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

Groupboxes.Visuals_ItemNotifs = tabs.Visuals:AddLeftGroupbox("Item Notifications")

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

toggles.ESPRainbow:OnChanged(function(value) loader:SetRainbow(value) end)

options.ESPTracerOrigin:OnChanged(function(value)
  local originMap = { Top = "Top", Middle = "Center", Bottom = "Bottom" }
  loader:SetTracerOrigin(originMap[value] or "Bottom")
end)

toggles.ESPShowText:OnChanged(function(showESPText) loader.ShowESPText = showESPText end)

toggles.ESPShowDistance:OnChanged(function(value) loader:SetShowDistance(value) end)

options.ESPTextSize:OnChanged(function(value) loader:SetTextSize(value) end)

options.ESPTextFont:OnChanged(function(value) loader:SetFont(Enum.Font[value]) end)

options.ESPRenderLimit:OnChanged(function(value) loader:SetRenderLimit(value) end)

options.ESPMaxDistance:OnChanged(function(maxDistance) loader.MaxDistance = maxDistance end)

options.ESPFillTransparency:OnChanged(function(value) loader:SetFillTransparency(value) end)

options.ESPOutlineTransparency:OnChanged(function(value) loader:SetOutlineTransparency(value) end)

options.ESPTextTransparency:OnChanged(function(value) loader:SetTextTransparency(value) end)

options.ESPTextOutlineTransparency:OnChanged(function(value)
  loader:SetTextOutlineTransparency(value)
end)

options.ESPFadeTime:OnChanged(Handlers.ESPFadeTimeChanged)

toggles.ESPFade:OnChanged(function(value)
  loader:SetFadeTime(value and options.ESPFadeTime.Value or 0)
end)

toggles.ESPArrowsToggle:OnChanged(function(value) loader:SetArrows(value) end)

options.ESPArrowsRadius:OnChanged(function(value) loader:SetArrowRadius(value) end)

options.ESPTracerThickness:OnChanged(function(value) loader:SetTracerSize(value) end)

toggles.UseESPOutlineColour:OnChanged(function(value) loader:SetMatchColors(value) end)

options.ESPOutline:OnChanged(function(value) loader:SetOutlineColor(value) end)

loader:SetMatchColors(toggles.UseESPOutlineColour.Value)

loader:SetOutlineColor(options.ESPOutline.Value)

loader:SetShowDistance(true)

loader:SetFont(Enum.Font.GothamBold)

loader:SetTextSize(14)

loader:SetRenderLimit(31)

loader:SetFillTransparency(0.6)

loader:SetOutlineTransparency(0)

loader:SetTextTransparency(0)

loader:SetTextOutlineTransparency(0.4)

loader:SetFadeTime(toggles.ESPFade and toggles.ESPFade.Value and options.ESPFadeTime.Value or 0)

loader:SetArrows(true)

loader:SetArrowRadius(250)

loader:SetTracerSize(0.75)

toggles.RemoveCameraBobbing:OnChanged(Handlers.RemoveCameraBobbingChanged)

toggles.RemoveCameraFog:OnChanged(Handlers.RemoveCameraFogChanged)

toggles.DisableFiredampEffect:OnChanged(Handlers.DisableFiredampEffectChanged)

toggles.TransparentHidingSpotsToggle:OnChanged(function(value)
  updateHidingSpotTransparency(value, options.TransparentHidingSpotsSlider.Value)
end)

options.TransparentHidingSpotsSlider:OnChanged(function(value)
  updateHidingSpotTransparency(toggles.TransparentHidingSpotsToggle.Value, value)
end)

toggles.DisableJumpscares:OnChanged(setupMainGameHooks)

options.JumpscaresList:OnChanged(Handlers.JumpscaresListChanged)

toggles.AutoClosetToggle:OnChanged(Handlers.AutoClosetToggleChanged)

Menus.KnobFarm()

tabs.FoolsHotel:SetVisible(false)

-- end of MENU

if CurrentFloor == "Lobby" then
  for _, flag in ipairs({
    "Godmode", "ThirdPerson", "Noclip", "FlyToggle", "Phase", "AnticheatManipulation", "AutoInteract", "ArchiveChairFly", "StairwellChairFly", "AntiElectricPuddle", "AntiRansom", "AntiScribbles", "NoAlmaDamage", "AntiDrone", "DisableDroneStampede", "RoomsAutoWalk", "RoomsAutoWalkIgnoreA60", "RoomsAutoWalkShowPathToggle", "RoomsAutoWalkSpoofFootsteps", "RoomsPickupStardust", "RoomsPickupGold", "NoSurgeDamage", "RemoveSurge", "RemoveMandrake", "BypassKillbricks", "BypassSeekingWall", "BypassBanana", "BypassJeff", "BypassGiggle", "BypassDupe", "BypassEyes", "BypassLookman", "BypassGloombatEggs", "BypassSeekObstructions", "BypassVacuum", "BypassSnare", "RemoveSeekTrigger", "RemoveFigure", "RemoveFigureMines", "RemoveA90", "RemoveDread", "AutoRevive", "FigureGodmode", "AutoSteerMinecart", "AutoSolveAnchors", "MinecartTeleport", "AutoMinecart", "AutoHeartbeatMinigame", "AutoBreakerBox", "AutoLibraryBruteForce", "InfiniteItemsToggle", "InfiniteCrucifix", "ShowSeekPathToggle", }) do
    local toggle = toggles[flag]

    if toggle and toggle.Value then
      toggle:SetValue(false)
    end
  end
end

local messageConnection

local function unloadScript()
  _Unloading = true

  if KnobFarm and KnobFarm.Stop then
    pcall(KnobFarm.Stop)
  end
  if KnobFarm and KnobFarm.Thread then
    pcall(task.cancel, KnobFarm.Thread)
  end

  pcall(stopFly)
  pcall(stopSpeedLoop)
  pcall(stopSpeedBypass)
  pcall(releaseChair)

  if FreecamConnection then
    FreecamConnection:Disconnect()
    FreecamConnection = nil
  end

  local freecamPart = workspace:FindFirstChild("FreecamPart")

  if freecamPart then
    freecamPart:Destroy()

    local humanoidRootPart2 = localPlayer.Character
      and localPlayer.Character:FindFirstChild("HumanoidRootPart")

    if humanoidRootPart2 then
      humanoidRootPart2.Anchored = false
    end

    localPlayer.CameraMinZoomDistance = localPlayer:GetAttribute("fc_om") or 0.5
    localPlayer.CameraMaxZoomDistance = localPlayer:GetAttribute("fc_ox") or 128
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
    pcall(setNoclipCollision, true)
  end

  if connection2 then
    connection2:Disconnect()
    connection2 = nil
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

  pcall(stopBringItems)

  if messageConnection then
    messageConnection:Disconnect()
    messageConnection = nil
  end

  if _FloorConnection then
    _FloorConnection:Disconnect()
    _FloorConnection = nil
  end

  if featureState and featureState.LobbyGuardConnection then
    featureState.LobbyGuardConnection:Disconnect()
    featureState.LobbyGuardConnection = nil
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

  stopLobbyFly()

  if lobbyState and lobbyState.NoclipConn then
    lobbyState.NoclipConn:Disconnect()
    lobbyState.NoclipConn = nil
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

  pcall(disableFullbright)

  if promptContainer then
    promptContainer:Destroy()
  end

  pcall(function()
    for key, FakePrompt in pairs(FakePrompts or {}) do
      pcall(function()
        FakePrompt.Parent = key.Parent
        key:Destroy()

        if FakePrompt.Parent then
          FakePrompt.HoldDuration = FakePrompt:GetAttribute("HoldDuration_Old")
            or FakePrompt.HoldDuration

          FakePrompt.RequiresLineOfSight = FakePrompt:GetAttribute("RequiresLineOfSight_Old")
            or FakePrompt.RequiresLineOfSight

          FakePrompt.MaxActivationDistance = FakePrompt:GetAttribute("MaxActivationDistance_Old")
            or FakePrompt.MaxActivationDistance
        end
      end)
    end
  end)

  if _TrackedPrompts then
    for _, _TrackedPrompt in ipairs(_TrackedPrompts) do
      pcall(function()
        if _TrackedPrompt.Parent then
          _TrackedPrompt.HoldDuration = _TrackedPrompt:GetAttribute("HoldDuration_Old")
            or _TrackedPrompt.HoldDuration

          _TrackedPrompt.RequiresLineOfSight = _TrackedPrompt:GetAttribute("RequiresLineOfSight_Old")
            or _TrackedPrompt.RequiresLineOfSight

          _TrackedPrompt.MaxActivationDistance = _TrackedPrompt:GetAttribute("MaxActivationDistance_Old")
            or _TrackedPrompt.MaxActivationDistance
        end
      end)
    end
  end

  for _, _ in workspace:GetDescendants() do
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
    local module = getMainGameModule()

    if module then
      module.tooloffset = Vector3.zero
      module.spring.Speed = 8
      module.fovtarget = 70
      module.csgo = CFrame.new()
    end
  end)

  pcall(function() workspace.CurrentCamera.FieldOfView = 70 end)
  pcall(function() workspace.Gravity = 196.2 end)
  pcall(function() Lighting.FogEnd = featureState and featureState.OldFog or Lighting.FogEnd end)

  pcall(function()
    for _, fogInstance in ipairs(featureState.FogInstances or {}) do
      local densityOld = fogInstance:GetAttribute("Density_Old")

      if densityOld then
        fogInstance.Density = densityOld
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
    local playerGui2 = localPlayer:FindFirstChildOfClass("PlayerGui")

    if playerGui2 then
      local findFirstChild = playerGui2:FindFirstChild("DisplayInfoLabel", true)

      if findFirstChild then
        findFirstChild:Destroy()
      end
    end
  end)

  if featureState then
    if featureState.SeekNodesFolder then
      featureState.SeekNodesFolder:Destroy()
    end

    if featureState.RoomsNodesFolder then
      featureState.RoomsNodesFolder:Destroy()
    end

    if featureState.OriginalGetMoveVector then
      pcall(function()
        local getControls = require(localPlayer.PlayerScripts.PlayerModule):GetControls()
        getControls.GetMoveVector = featureState.OriginalGetMoveVector
      end)

      featureState.OriginalGetMoveVector = nil
    end

    featureState.AnticheatDisabled = false
    featureState.RoomsAutoWalkActive = false
  end

  pcall(function()
    if featureState.ClearAddonGroupboxes then
      featureState.ClearAddonGroupboxes()
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

  for _, list in pairs(worldObjects or {}) do
    if type(list) == "table" then
      for _, _ in ipairs(list) do
      end

      TableClear(list)
    end
  end

  for _, PartProperty in pairs(PartProperties or {}) do
    pcall(function() PartProperty.CustomPhysicalProperties = PartProperties[PartProperty] end)
  end

  pcall(function()
    local remoteModules = getRemoteModules()

    if remoteModules then
      for _, name in ipairs({
        "Screech", "GlitchScreech", "A90", "Dread", "SurgeVignette", "Shade", }) do
        local findFirstChild = remoteModules:FindFirstChild(name .. "_Disabled")

        if findFirstChild then
          findFirstChild.Name = name
        end
      end
    end

    local clientModules = replicatedStorage:FindFirstChild("ModulesClient") or replicatedStorage:FindFirstChild("ClientModules")
    local entityModules = clientModules and clientModules:FindFirstChild("EntityModules")
    if entityModules then
      local shade = entityModules:FindFirstChild("Shade_Disabled")
      if shade then
        shade.Name = "Shade"
      end
      local screechM = entityModules:FindFirstChild("Screech_Disabled")
      if screechM then
        screechM.Name = "Screech"
      end
    end
  end)

  if FakeEvents then
    if FakeEvents.Screech_Real then
      FakeEvents.Screech_Real.Parent = remotesFolder
      pcall(function()
        local getconns = Executor.getconnections or RootEnv.getconnections
        if getconns then
          for _, conn in ipairs(getconns(FakeEvents.Screech_Real.OnClientEvent)) do
            pcall(function() conn:Enable() end)
          end
        end
      end)
    end

    if FakeEvents.Shade_Real then
      FakeEvents.Shade_Real.Parent = remotesFolder
    end

    if FakeEvents.A90_Real then
      FakeEvents.A90_Real.Parent = remotesFolder
    end

    if FakeEvents.Surge_Real then
      FakeEvents.Surge_Real.Parent = remotesFolder
    end

    for _, fakeName in ipairs({"Screech", "Shade", "A90", "Surge"}) do
      local fake = FakeEvents[fakeName]
      if typeof(fake) == "Instance" and fake:IsA("RemoteEvent") then
        pcall(fake.Destroy, fake)
      end
    end
  end

  if character then
    local collisionClone = character:FindFirstChild("CollisionClone")

    if collisionClone then
      collisionClone:Destroy()
    end

    local collisionPartClone = character:FindFirstChild("CollisionPartClone")

    if collisionPartClone then
      collisionPartClone:Destroy()
    end
  end

  if localPlayer then
    localPlayer.CameraMinZoomDistance = 0.5
    localPlayer.CameraMaxZoomDistance = 128
    localPlayer:SetAttribute("fc_om", nil)
    localPlayer:SetAttribute("fc_ox", nil)
    localPlayer:SetAttribute("fc_p", nil)
    localPlayer:SetAttribute("fc_y", nil)
  end

  if tabs.Stairwell then
    tabs.Stairwell:SetVisible(false)
  end

  if tabs.FoolsHotel then
    tabs.FoolsHotel:SetVisible(false)
  end

  if tabs.Rooms then
    tabs.Rooms:SetVisible(false)
  end

end

getgenv().MoroUnload = unloadScript
getgenv().CheesyUnload = unloadScript

library:OnUnload(function()
  _Unloading = true
  unloadScript()
  getgenv().MoroUnload = nil
  getgenv().CheesyUnload = nil
end)

if library.ScreenGui then
  library.ScreenGui.Destroying:Once(function()
    _Unloading = true
    unloadScript()
  end)
end
do
  local connection = logService.MessageOut:Connect(function(message)
    if message == "client teleporting" then
      if featureState.AnticheatDisabled then
        featureState.AnticheatDisabled = false

        library:Notify({
          Title = "Anticheat re-enabled", Description = "Interact with a ladder for re-disabling", Time = 5, })
      end

      connect29:Disconnect()
    end
  end)
end


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
  local text = string.lower(tostring(execName))

  if text:find("xeno", 1, true) or text:find("solara", 1, true) then
    library:Notify({
      Title = "Executor not supported", Description = "Xeno and Solara are both very unstable and may/most likely will not work with the script, I advise using a better executor", Time = 10, })
  end
end)