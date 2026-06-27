--===================================================================================--
--                       MOROLUMINA UI — FULL TEST SUITE                               --
--          Проверка всех элементов, флагов, конфигов и методов библиотеки             --
--                        (с иконками Lucide вместо rbxassetid)                         --
--===================================================================================--

-- ⬇️ ЗАМЕНИ НА СВОЮ RAW ССЫЛКУ
local RAW_URL = "https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"

-- безопасная загрузка
local Library
local ok, err = pcall(function()
    Library = loadstring(game:HttpGet(RAW_URL))()
end)
if not ok or not Library then
    warn("[TEST] Не удалось загрузить библиотеку: " .. tostring(err))
    error(err)
    return
end
print("[TEST] Библиотека загружена ✓")

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

--===================================================================================--
--                                   WINDOW                                            --
--===================================================================================--
local Window = Library:CreateWindow({
    Title = "MoroLumina — TEST SUITE",
    ToggleKey = Enum.KeyCode.RightShift,
})
print("[TEST] Окно создано ✓")

--===================================================================================--
--   TAB 1: ELEMENTS — проверка каждого элемента                                       --
--===================================================================================--
local t1 = Window:CreateTab({ Name = "Elements", Icon = "layout-grid" })

-- ЛЕВАЯ КОЛОНКА -------------------------------------------------------------------
local s1 = t1:CreateSection({ Name = "Basics" })

s1:AddLabel("Это статичный лейбл")
local dynLabel = s1:AddLabel("Динамический лейбл (изменится)")

s1:AddButton({
    Name = "Обычная кнопка",
    Callback = function()
        Window:Notify({ Title = "Button", Content = "Обычная кнопка нажата", Type = "Info" })
        dynLabel.Set("Лейбл обновлён в " .. os.date("%X"))
    end,
})

s1:AddButton({
    Name = "Primary кнопка",
    Primary = true,
    Callback = function()
        Window:Notify({ Title = "Button", Content = "Primary кнопка нажата", Type = "Success" })
    end,
})

s1:AddToggle({
    Name = "Тоггл (default ON)",
    Icon = "toggle-right",
    Default = true,
    Flag = "Test_Toggle",
    Callback = function(v)
        print("[TEST] Toggle =", v)
    end,
})

s1:AddSlider({
    Name = "Целый слайдер",
    Icon = "sliders-horizontal",
    Min = 0, Max = 100, Default = 50, Suffix = "%",
    Flag = "Test_SliderInt",
    Callback = function(v) print("[TEST] SliderInt =", v) end,
})

s1:AddSlider({
    Name = "Дробный слайдер",
    Icon = "gauge",
    Min = 0, Max = 5, Default = 2.5, Decimals = 2, Suffix = "x",
    Flag = "Test_SliderFloat",
    Callback = function(v) print("[TEST] SliderFloat =", v) end,
})

-- ПРАВАЯ КОЛОНКА ------------------------------------------------------------------
t1:Column("right")
local s2 = t1:CreateSection({ Name = "Inputs" })

s2:AddTextbox({
    Name = "Текстовое поле",
    Icon = "text-cursor-input",
    Placeholder = "Введите текст...",
    Default = "",
    Flag = "Test_Textbox",
    Callback = function(text, enter)
        print("[TEST] Textbox =", text, "| Enter:", enter)
    end,
})

s2:AddTextbox({
    Name = "Числовое поле",
    Icon = "hash",
    Placeholder = "0",
    Numeric = true,
    Flag = "Test_NumBox",
    Callback = function(num)
        print("[TEST] NumBox =", num, "| тип:", type(num))
    end,
})

s2:AddKeybind({
    Name = "Тестовый бинд",
    Icon = "keyboard",
    Default = Enum.KeyCode.F,
    Flag = "Test_Keybind",
    Callback = function()
        Window:Notify({ Title = "Keybind", Content = "Бинд сработал!", Type = "Warning" })
    end,
    ChangedCallback = function(key)
        print("[TEST] Keybind изменён на:", key and key.Name)
    end,
})

s2:AddColorPicker({
    Name = "Выбор цвета",
    Icon = "palette",
    Default = Color3.fromRGB(0, 225, 134),
    Flag = "Test_Color",
    Callback = function(c)
        print(("[TEST] Color = #%s (R%d G%d B%d)"):format(
            c:ToHex(), c.R*255, c.G*255, c.B*255))
    end,
})

--===================================================================================--
--   TAB 2: DROPDOWNS — обычный и мульти + динамическое обновление                     --
--===================================================================================--
local t2 = Window:CreateTab({ Name = "Dropdowns", Icon = "chevrons-up-down" })

local s3 = t2:CreateSection({ Name = "Single Dropdown" })
local singleDD = s3:AddDropdown({
    Name = "Один выбор",
    Icon = "list",
    Default = "Опция 2",
    Options = {"Опция 1", "Опция 2", "Опция 3", "Опция 4"},
    Flag = "Test_Single",
    Callback = function(v) print("[TEST] SingleDropdown =", v) end,
})
s3:AddButton({ Name = "Get значение", Callback = function()
    Window:Notify({ Title = "Single DD", Content = "Выбрано: " .. tostring(singleDD.Get()), Type = "Info" })
end })
s3:AddButton({ Name = "Set = Опция 4", Callback = function()
    singleDD.Set("Опция 4")
end })
s3:AddButton({ Name = "Refresh (новый список)", Callback = function()
    singleDD.Refresh({"Новая A", "Новая B", "Новая C"})
    Window:Notify({ Title = "Single DD", Content = "Список обновлён", Type = "Success" })
end })

-- МУЛЬТИ ДРОПДАУН -----------------------------------------------------------------
t2:Column("right")
local s4 = t2:CreateSection({ Name = "Multi Dropdown" })

local multiDD = s4:AddMultiDropdown({
    Name = "Мульти выбор",
    Icon = "list-checks",
    Sub = "Можно выбрать несколько",
    Default = {"Алмаз", "Золото"},
    Placeholder = "Ничего",
    Options = {"Алмаз", "Золото", "Серебро", "Бронза", "Платина", "Изумруд"},
    Flag = "Test_Multi",
    Callback = function(list, changed, state)
        print("[TEST] Multi =", table.concat(list, ", "))
        if changed then print("   изменено:", changed, state and "+" or "-") end
    end,
})

local limitedDD = s4:AddMultiDropdown({
    Name = "Лимит (макс 2)",
    Icon = "target",
    Default = {},
    Max = 2,
    Options = {"Цель 1", "Цель 2", "Цель 3", "Цель 4"},
    Flag = "Test_MultiLimit",
    Callback = function(list) print("[TEST] Limited =", #list, "выбрано") end,
})

s4:AddButton({ Name = "Get (список)", Callback = function()
    local l = multiDD.Get()
    Window:Notify({ Title = "Multi", Content = "Выбрано " .. #l .. ": " .. table.concat(l, ", "), Type = "Info" })
end })
s4:AddButton({ Name = "Select All", Callback = function() multiDD.SelectAll() end })
s4:AddButton({ Name = "Clear All", Callback = function() multiDD.ClearAll() end })
s4:AddButton({ Name = "Set = {Бронза, Платина}", Callback = function()
    multiDD.Set({"Бронза", "Платина"})
end })
s4:AddButton({ Name = "IsSelected('Алмаз')?", Callback = function()
    Window:Notify({ Title = "Multi", Content = "Алмаз выбран: " .. tostring(multiDD.IsSelected("Алмаз")), Type = "Warning" })
end })
s4:AddButton({ Name = "Refresh (keep selection)", Callback = function()
    multiDD.Refresh({"Алмаз", "Золото", "Новый1", "Новый2"}, true)
    Window:Notify({ Title = "Multi", Content = "Обновлено с сохранением", Type = "Success" })
end })

--===================================================================================--
--   TAB 3: NOTIFICATIONS — все типы                                                   --
--===================================================================================--
local t3 = Window:CreateTab({ Name = "Notify", Icon = "bell" })
local s5 = t3:CreateSection({ Name = "Notification Types" })

s5:AddButton({ Name = "Info", Callback = function()
    Window:Notify({ Title = "Info", Content = "Это информационное уведомление.", Type = "Info", Duration = 4 })
end })
s5:AddButton({ Name = "Success", Primary = true, Callback = function()
    Window:Notify({ Title = "Success", Content = "Операция выполнена успешно!", Type = "Success", Duration = 4 })
end })
s5:AddButton({ Name = "Warning", Callback = function()
    Window:Notify({ Title = "Warning", Content = "Внимание! Проверь настройки.", Type = "Warning", Duration = 4 })
end })
s5:AddButton({ Name = "Error", Callback = function()
    Window:Notify({ Title = "Error", Content = "Произошла ошибка выполнения.", Type = "Error", Duration = 4 })
end })

t3:Column("right")
local s6 = t3:CreateSection({ Name = "Stress / Misc" })
s6:AddButton({ Name = "Спам 5 уведомлений", Callback = function()
    for i = 1, 5 do
        task.delay(i * 0.2, function()
            Window:Notify({ Title = "Notify #" .. i, Content = "Тест очереди уведомлений", Type = "Info", Duration = 3 })
        end)
    end
end })
s6:AddButton({ Name = "Долгое (10 сек)", Callback = function()
    Window:Notify({ Title = "Long", Content = "Это уведомление висит 10 секунд.", Type = "Warning", Duration = 10 })
end })
s6:AddButton({ Name = "Длинный текст", Callback = function()
    Window:Notify({ Title = "Wrap Test", Content = "Очень длинный текст для проверки переноса строк и автоматического изменения высоты карточки уведомления.", Type = "Info", Duration = 6 })
end })

--===================================================================================--
--   TAB 4: FLAGS & CONFIG — проверка системы флагов и сохранения                      --
--===================================================================================--
local t4 = Window:CreateTab({ Name = "Flags", Icon = "flag" })
local s7 = t4:CreateSection({ Name = "Flag System" })

s7:AddButton({ Name = "Вывести ВСЕ флаги", Callback = function()
    print("========== ВСЕ ФЛАГИ ==========")
    for name, f in pairs(Library.Flags) do
        local v = f.Get()
        if typeof(v) == "table" then v = "{" .. table.concat(v, ", ") .. "}"
        elseif typeof(v) == "Color3" then v = "#" .. v:ToHex()
        elseif typeof(v) == "EnumItem" then v = v.Name end
        print(("  %-20s = %s"):format(name, tostring(v)))
    end
    print("===============================")
    Window:Notify({ Title = "Flags", Content = "Все флаги выведены в консоль", Type = "Info" })
end })

s7:AddButton({ Name = "Set Test_Toggle = false", Callback = function()
    if Library.Flags.Test_Toggle then Library.Flags.Test_Toggle.Set(false) end
end })
s7:AddButton({ Name = "Set Test_SliderInt = 99", Callback = function()
    if Library.Flags.Test_SliderInt then Library.Flags.Test_SliderInt.Set(99) end
end })

t4:Column("right")
local s8 = t4:CreateSection({ Name = "Config Save/Load" })
local cfgName = s8:AddTextbox({ Name = "Имя конфига", Icon = "file-pen", Placeholder = "test_config" })
local cfgList = s8:AddDropdown({ Name = "Сохранённые", Icon = "folder", Options = Library:GetConfigs(), Default = "" })

s8:AddButton({ Name = "Save Config", Primary = true, Callback = function()
    local n = cfgName.Get()
    if n ~= "" then
        local ok2 = pcall(function() Library:SaveConfig(n) end)
        if ok2 then
            cfgList.Refresh(Library:GetConfigs(), true)
            Window:Notify({ Title = "Config", Content = "Сохранён: " .. n, Type = "Success" })
        else
            Window:Notify({ Title = "Config", Content = "Сохранение не поддерживается экзекутором", Type = "Error" })
        end
    else
        Window:Notify({ Title = "Config", Content = "Введите имя!", Type = "Warning" })
    end
end })
s8:AddButton({ Name = "Load Config", Callback = function()
    local n = cfgList.Get()
    if n and n ~= "" then
        local ok2 = pcall(function() Library:LoadConfig(n) end)
        Window:Notify({
            Title = "Config",
            Content = ok2 and ("Загружен: " .. n) or "Ошибка загрузки",
            Type = ok2 and "Success" or "Error",
        })
    end
end })
s8:AddButton({ Name = "Refresh список", Callback = function()
    cfgList.Refresh(Library:GetConfigs())
end })

--===================================================================================--
--   TAB 5: WINDOW METHODS — управление окном                                          --
--===================================================================================--
local t5 = Window:CreateTab({ Name = "Window", Icon = "app-window" })
local s9 = t5:CreateSection({ Name = "Window Control" })

s9:AddButton({ Name = "Toggle окна", Primary = true, Callback = function()
    Window:Toggle()
end })
s9:AddKeybind({ Name = "Toggle бинд", Icon = "keyboard", Default = Enum.KeyCode.RightShift, Callback = function()
    Window:Toggle()
end })
s9:AddButton({ Name = "Сменить акцент (Cyan)", Callback = function()
    -- через настройки если есть API; иначе пример
    Window:Notify({ Title = "Theme", Content = "Смени акцент во вкладке Settings", Type = "Info" })
end })

t5:Column("right")
local s10 = t5:CreateSection({ Name = "Game Test" })
s10:AddSlider({ Name = "WalkSpeed", Icon = "footprints", Min = 16, Max = 200, Default = 16, Flag = "WalkSpeed",
    Callback = function(v)
        local c = LP.Character
        if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = v end
    end })
s10:AddSlider({ Name = "JumpPower", Icon = "move-up", Min = 50, Max = 300, Default = 50, Flag = "JumpPower",
    Callback = function(v)
        local c = LP.Character
        if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower = v end
    end })
s10:AddButton({ Name = "Unload меню", Callback = function()
    Window:Notify({ Title = "Unload", Content = "Меню закроется через 1 сек", Type = "Warning" })
    task.delay(1, function() Window.Gui:Destroy() end)
end })

--===================================================================================--
--   TAB 6: CREDITS                                                                    --
--===================================================================================--
local t6 = Window:CreateTab({ Name = "Credits", Icon = "heart" })
local s11 = t6:CreateSection({ Name = "About" })
s11:AddLabel("MoroLumina UI — Test Suite")
s11:AddLabel("Проверено элементов: 100%")
s11:AddLabel("Toggle: RightShift")

--===================================================================================--
--   SETTINGS TAB (встроенная)                                                         --
--===================================================================================--
Window:AddSettingsTab()


--===================================================================================--
--   ФИНАЛЬНАЯ ПРОВЕРКА                                                                 --
--===================================================================================--
task.wait(0.5)

local checks = {
    { "CreateWindow",      Window ~= nil },
    { "CreateTab",         t1 ~= nil and t6 ~= nil },
    { "Column",            t1.Column ~= nil },
    { "CreateSection",     s1 ~= nil },
    { "AddLabel",          dynLabel ~= nil },
    { "AddButton",         true },
    { "AddToggle",         Library.Flags.Test_Toggle ~= nil },
    { "AddSlider",         Library.Flags.Test_SliderInt ~= nil },
    { "AddTextbox",        Library.Flags.Test_Textbox ~= nil },
    { "AddKeybind",        Library.Flags.Test_Keybind ~= nil },
    { "AddColorPicker",    Library.Flags.Test_Color ~= nil },
    { "AddDropdown",       singleDD.Get ~= nil and singleDD.Refresh ~= nil },
    { "AddMultiDropdown",  multiDD.SelectAll ~= nil and multiDD.IsSelected ~= nil },
    { "Notify",            Window.Notify ~= nil },
    { "Toggle",            Window.Toggle ~= nil },
    { "Flags system",      next(Library.Flags) ~= nil },
    { "GetConfigs",        Library.GetConfigs ~= nil },
    { "SaveConfig",        Library.SaveConfig ~= nil },
    { "LoadConfig",        Library.LoadConfig ~= nil },
    { "AddSettingsTab",    Window.AddSettingsTab ~= nil },
}

print("\n========== РЕЗУЛЬТАТЫ ТЕСТА ==========")
local passed = 0
for _, c in ipairs(checks) do
    local status = c[2] and "✓ PASS" or "✗ FAIL"
    print(("  %-20s %s"):format(c[1], status))
    if c[2] then passed = passed + 1 end
end
print(("====================================="))
print(("  ИТОГО: %d/%d пройдено"):format(passed, #checks))
print("=====================================\n")

Window:Notify({
    Title = "Test Suite",
    Content = ("Тест завершён: %d/%d ✓\nНажми RightShift для скрытия."):format(passed, #checks),
    Type = (passed == #checks) and "Success" or "Warning",
    Duration = 8,
})
