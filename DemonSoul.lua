--[[
    Demon Soul Simulator - Lumina UI Edition
    Fully ported to MoroLumina UI Framework v2.0 (Emerald Edition)
--]]

local function SafeLoad()
    local path = "MoroLumina.lua"
    local path2 = "Lumina.lua"

    if isfile and isfile(path2) then 
        local ok, res = pcall(function()
            local src = readfile(path2)
            local fn, err = loadstring(src)
            if not fn then error(err or "loadstring error") end
            return fn()
        end)
        if ok and res then return res end
    end

    if isfile and isfile(path) then 
        local ok, res = pcall(function()
            local src = readfile(path)
            local fn, err = loadstring(src)
            if not fn then error(err or "loadstring error") end
            return fn()
        end)
        if ok and res then return res end
    end
    
    local url = "https://raw.githubusercontent.com/Morozhka144/GUI2222/refs/heads/main/Lumina.lua"
    local ok, content = pcall(function() return game:HttpGet(url) end)
    if ok and content and #content > 0 then
        local func, err = loadstring(content)
        if func then
            local success, lib = pcall(func)
            if success and lib then
                if writefile then pcall(function() writefile(path, content) end) end
                return lib
            else
                warn("[Moro Soul] Ошибка инициализации Lumina: " .. tostring(lib))
            end
        else
            warn("[Moro Soul] Ошибка компиляции Lumina: " .. tostring(err))
        end
    else
        warn("[Moro Soul] Ошибка загрузки Lumina с GitHub: " .. tostring(content))
    end
    
    warn("[Moro Soul] Не удалось загрузить библиотеку Lumina!")
    return nil
end

local Library = SafeLoad()

if Library then
    -- Cleanup previous session if script is re-executed
    if _G.__MoroSoulCleanup then
        pcall(_G.__MoroSoulCleanup)
    end
    pcall(function()
        local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
        for _, c in ipairs(parentGui:GetChildren()) do
            if c.Name == "MoroLumina" then
                pcall(function() c:Destroy() end)
            end
        end
    end)
    local scriptActive = true
    local cleanupHandlers = {}
    _G.__MoroSoulCleanup = function()
        scriptActive = false
        for _, fn in ipairs(cleanupHandlers) do
            pcall(fn)
        end
    end

    local rs = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")
    local player = players.LocalPlayer
    local runService = game:GetService("RunService")
    local lighting = game:GetService("Lighting")
    local tweenService = game:GetService("TweenService")
    local vim = game:GetService("VirtualInputManager")
    local teleportService = game:GetService("TeleportService")
    local guiService = game:GetService("GuiService")
    local uis = game:GetService("UserInputService")
    
    local remoteFolder = rs:WaitForChild("RemoteEvents", 10) or rs:FindFirstChild("RemoteEvents")
    local attackRemote = remoteFolder and (remoteFolder:FindFirstChild("GeneralAttack") or remoteFolder:WaitForChild("GeneralAttack", 5))
    local skillRemote = remoteFolder and (remoteFolder:FindFirstChild("SkillAttack") or remoteFolder:WaitForChild("SkillAttack", 5))
    
    local EventBus = nil
    pcall(function()
        EventBus = require(rs:WaitForChild("Packages"):WaitForChild("EventBus"))
    end)
    
    local AttackHelper = nil
    pcall(function()
        AttackHelper = require(rs:WaitForChild("AttackHelpers"):WaitForChild("AttackHelper"))
    end)

    -- Settings & State
    local states = {attack = false, skill1 = false, skill2 = false, skill3 = false}
    local speeds = {attack = 20} 
    local killAuraActive = false
    local priorityHighHP = false 
    local animCancel = false
    local autoRoulette = false
    local autoMissions = false
    local autoOpenChests = false
    local monsterNearby = false
    local isSpeedHack = false
    local speedPercentValue = 50
    local fakeFriendBonusActive = false
    local infiniteFoodActive = false
    local minHealthLimit = 0
    local tpHeight = 2
    local currentTarget = nil

    -- Heartbeat Movement Safety Guard: Never allow WalkSpeed or JumpPower to explode
    local moveGuardConn = nil
    moveGuardConn = runService.Heartbeat:Connect(function()
        if not scriptActive then
            if moveGuardConn then pcall(function() moveGuardConn:Disconnect() end) end
            return
        end
        pcall(function()
            local char = player.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                if hum.WalkSpeed > 5000 then
                    hum.WalkSpeed = 16
                end
                if hum.UseJumpPower then
                    if hum.JumpPower > 500 then
                        hum.JumpPower = 50
                    end
                else
                    if hum.JumpHeight > 500 then
                        hum.JumpHeight = 7.2
                    end
                end
            end
        end)
    end)
    table.insert(cleanupHandlers, function() if moveGuardConn then pcall(function() moveGuardConn:Disconnect() end) end end)
    
    -- Dynamic Hero Data from RoleConfig
    local heroData = {}
    local heroNames = {}
    local dispatchRoles = {}
    local roleNames = {}
    
    pcall(function()
        local rc = require(rs:WaitForChild("Configs"):WaitForChild("RoleConfig"))
        for id, r in pairs(rc) do
            if r.RoleName and r.RoleIndex then
                heroData[r.RoleName] = r.RoleIndex
                table.insert(heroNames, r.RoleName)
            end
            if r.RoleName and r.RoleId then
                dispatchRoles[r.RoleName] = r.RoleId
                table.insert(roleNames, r.RoleName)
            end
        end
        table.sort(heroNames)
        table.sort(roleNames)
    end)
    
    -- Fallback hero table if RoleConfig is not accessible
    if #heroNames == 0 then
        heroData = {
            ["Akaza"] = "漪窝座",
            ["Daki"] = "堕姬",
            ["Douma"] = "童魔",
            ["Enmu"] = "魇梦",
            ["Genya Shinazugawa"] = "不死川玄弥",
            ["Giyu Tomioka"] = "富冈义勇",
            ["Gyomei Himejima"] = "悲鸣屿行冥",
            ["Gyutaro"] = "妓夫太郎",
            ["Himejima Kyoumei"] = "悲鸣屿行冥",
            ["Hinatsuru"] = "雏鹤",
            ["Iguro Obanai"] = "伊黑小芭内",
            ["Inosuke Hashibira"] = "伊之助",
            ["Inosuke (Entertainment District)"] = "伊之助_游郭篇",
            ["Kaigaku"] = "稻玉狯岳",
            ["Kanao Tsuyuri"] = "栗花落香奈乎",
            ["Kyojuro Rengoku"] = "炼狱杏寿郎",
            ["Mitsuri Kanroji"] = "甘露寺蜜璃",
            ["Muichiro Tokito"] = "时透无一郎",
            ["Murata"] = "村田",
            ["Nezuko Kamado"] = "弥豆子",
            ["Nezuko (Berserk)"] = "弥豆子_鬼化",
            ["Rui"] = "累",
            ["Sakonji Urokodaki"] = "左近次",
            ["Sanemi Shinazugawa"] = "不死川实弥",
            ["Shinobu Kocho"] = "蝴蝶忍",
            ["Susamaru"] = "朱纱丸",
            ["Tanjiro (Entertainment District)"] = "炭治郎_游郭篇",
            ["Tanjiro (Hinokami)"] = "炭治郎_火之神神乐",
            ["Tanjiro (Swordsmith Village)"] = "炭治郎_锻刀村篇",
            ["Tanjiro (Water)"] = "炭治郎_水",
            ["Tengen Uzui"] = "宇髓天元",
            ["Yahaba"] = "矢琵羽",
            ["Yushiro"] = "愈史郎",
            ["Yushiro & Tamayo"] = "愈史郎",
            ["Zenitsu Agatsuma"] = "我妻善逸",
            ["Zenitsu (Entertainment District)"] = "我妻善逸_游郭篇",
            ["Zohakuten"] = "憎珀天"
        }
        for name, _ in pairs(heroData) do table.insert(heroNames, name) end
        table.sort(heroNames)
    end
    
    if #roleNames == 0 then
        local defaultDispatch = {
            ["Nezuko"] = 1, ["Inosuke"] = 2, ["Tanjirou[Water]"] = 3, ["Rui"] = 4,
            ["Zenitsu"] = 5, ["Tanjirou[HinokamiKagura]"] = 6, ["Shinobu"] = 7, ["Giyu"] = 8,
            ["Rengoku"] = 9, ["Akaza"] = 10, ["Susamaru"] = 11, ["Yahaba"] = 12,
            ["Yushirou"] = 13, ["Enmu"] = 14, ["Urokodaki"] = 15, ["Tsuyuri Kanawo"] = 16,
            ["Kanroji Mitsuri"] = 17, ["Kaigaku"] = 18, ["Daki"] = 19, ["Gyuutarou"] = 20,
            ["Uzui Tengen"] = 21, ["Iguro Obanai"] = 22, ["Tokitou Muichirou"] = 23, ["Shinazugawa Sanemi"] = 24,
            ["Himejima Kyoumei"] = 25, ["Douma"] = 26, ["Tanjiro[Yoshiwara]"] = 27, ["Zenitsu[Yoshiwara]"] = 28,
            ["Inosuke[Yoshiwara]"] = 29, ["Nezuko[Demonic]"] = 30, ["Murata"] = 31, ["Shinazugawa Genya"] = 32,
            ["Hinatsuru"] = 33, ["Zohakuten"] = 34, ["Tanjirou[Swordsmith]"] = 35
        }
        for name, id in pairs(defaultDispatch) do
            dispatchRoles[name] = id
            table.insert(roleNames, name)
        end
        table.sort(roleNames)
    end

    -- Window Creation (Lumina API)
    local Win = Library:CreateWindow({
        Title = "Moro Soul",
        ToggleKey = Enum.KeyCode.RightShift,
        LoaderSound = true,
        NotifySound = true
    })

    -- Universal Notification Helper
    local function Notify(title, content, dur, nType)
        task.spawn(function()
            pcall(function()
                if Win and Win.Notify then
                    Win:Notify({
                        Title = title or "Moro Soul",
                        Content = content or "",
                        Duration = dur or 2.5,
                        Type = nType or "Info"
                    })
                end
            end)
        end)
    end
    Library.Notify = function(self, title, content, dur, nType)
        Notify(title, content, dur, nType)
    end

    -- Tabs Creation (Lumina API)
    local MainTab     = Win:CreateTab({ Name = "Attacks", Icon = "swords" })
    local TrainTab    = Win:CreateTab({ Name = "Train", Icon = "train" })
    local FishTab     = Win:CreateTab({ Name = "Fishing & Food", Icon = "fish" })
    local UpgradeTab  = Win:CreateTab({ Name = "Upgrade", Icon = "sparkles" })
    local DispatchTab = Win:CreateTab({ Name = "Dispatch", Icon = "send" })
    local RewardsTab  = Win:CreateTab({ Name = "Rewards", Icon = "gift" })
    local ExploitsTab = Win:CreateTab({ Name = "Exploits", Icon = "shield" })
    local SettingsTab = Win:AddSettingsTab()

    -- Compatibility aliases for Section methods
    local function wrapSection(sec)
        if sec and not sec.AddTextBox then
            sec.AddTextBox = sec.AddTextbox
        end
        return sec
    end

    -- === 1. ULTRA OPTIMIZED TARGET SEARCH (Direct workspace.Monsters check) ===
    task.spawn(function()
        while task.wait(0.15) do
            if killAuraActive or states.attack or states.skill1 or states.skill2 or states.skill3 then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local target = nil
                    local bestValue = priorityHighHP and 0 or math.huge
                    local monstersFolder = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies")

                    if monstersFolder then
                        for _, obj in ipairs(monstersFolder:GetChildren()) do
                            if obj:IsA("Model") then
                                local eHum = obj:FindFirstChildOfClass("Humanoid")
                                local eHrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                                if eHum and eHrp and eHum.Health > 0 and eHum.Health >= minHealthLimit then
                                    local dist = (eHrp.Position - hrp.Position).Magnitude
                                    if priorityHighHP then
                                        if eHum.Health > bestValue then
                                            bestValue = eHum.Health
                                            target = obj
                                        end
                                    else
                                        if dist < bestValue then
                                            bestValue = dist
                                            target = obj
                                        end
                                    end
                                end
                            end
                        end
                    end
                    currentTarget = target
                end
            else
                currentTarget = nil
            end
        end
    end)

    -- === 2. ANIMATION CANCEL (Attacks Only) ===
    task.spawn(function()
        while scriptActive do
            if animCancel then
                pcall(function()
                    local char = player.Character
                    if not char then return end
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local animator = hum:FindFirstChildOfClass("Animator")
                        local tracks = animator and animator:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
                        if tracks then
                            for _, track in ipairs(tracks) do
                                pcall(function()
                                    local name = tostring(track.Name or ""):lower()
                                    if name:find("attack", 1, true) then
                                        track:Stop(0)
                                    end
                                end)
                            end
                        end
                    end
                end)
            end
            task.wait(0.05)
        end
    end)

    -- === 3. FAST ATTACK ===
    task.spawn(function()
        while scriptActive do
            if states.attack then
                if monsterNearby or killAuraActive then
                    pcall(function()
                        if attackRemote then
                            attackRemote:FireServer(4)
                        end
                        if animCancel then
                            local char = player.Character
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if hum and hum.Health > 0 then
                                local animator = hum:FindFirstChildOfClass("Animator")
                                local tracks = animator and animator:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
                                if tracks then
                                    for _, track in ipairs(tracks) do
                                        pcall(function() track:Stop(0) end)
                                    end
                                end
                            end
                        end
                    end)
                    
                    local spd = tonumber(speeds and speeds.attack) or 20
                    if spd <= 0 then spd = 20 end
                    task.wait(1 / spd)
                else
                    task.wait(0.1)
                end
            else
                task.wait(0.5)
            end
        end
    end)

    -- === 4. INSTANT SKILL CAST (NO WINDUP) & FAST SKILLS ===
    local instantSkillCastEnabled = true

    local function initInstantSkillCast()
        local AnimationPlayer = nil
        local SkillController = nil
        pcall(function()
            AnimationPlayer = require(rs:WaitForChild("RoleController"):WaitForChild("AnimationPlayer"))
            SkillController = require(rs:WaitForChild("RoleController"):WaitForChild("SkillController"))
        end)

        local origApPlayAnimation = nil
        local origScPlay = nil
        local canAttackConn = nil

        if AnimationPlayer and not origApPlayAnimation then
            origApPlayAnimation = AnimationPlayer.playAnimation
            AnimationPlayer.playAnimation = function(a1, a2)
                local track = origApPlayAnimation(a1, a2)
                if track and instantSkillCastEnabled then
                    pcall(function()
                        track:AdjustSpeed(3.0)
                    end)
                end
                return track
            end
        end

        if SkillController and not origScPlay then
            origScPlay = SkillController.play
            SkillController.play = function(a1, a2)
                if instantSkillCastEnabled then
                    task.delay(0.15, function()
                        _G.Skilling = false
                        local char = player.Character
                        if char then
                            local ca = char:FindFirstChild("CanAttack")
                            if ca then ca.Value = true end
                            if char.PrimaryPart then
                                local p = char.PrimaryPart:FindFirstChild("SkillAlignPosition")
                                local o = char.PrimaryPart:FindFirstChild("SkillAlignOrientation")
                                if p then p.Enabled = false end
                                if o then o.Enabled = false end
                            end
                        end
                    end)
                end
                return origScPlay(a1, a2)
            end
        end

        local function hookCharCanAttack(char)
            if canAttackConn then
                pcall(function() canAttackConn:Disconnect() end)
                canAttackConn = nil
            end
            local ca = char and char:FindFirstChild("CanAttack")
            if ca then
                canAttackConn = ca.Changed:Connect(function(val)
                    if not val and instantSkillCastEnabled then
                        task.delay(0.18, function()
                            if instantSkillCastEnabled and ca.Parent then
                                ca.Value = true
                            end
                        end)
                    end
                end)
            end
        end

        if player.Character then
            hookCharCanAttack(player.Character)
        end
        player.CharacterAdded:Connect(function(newChar)
            task.wait(0.5)
            hookCharCanAttack(newChar)
        end)

        table.insert(cleanupHandlers, function()
            if origApPlayAnimation and AnimationPlayer then
                AnimationPlayer.playAnimation = origApPlayAnimation
            end
            if origScPlay and SkillController then
                SkillController.play = origScPlay
            end
            if canAttackConn then
                pcall(function() canAttackConn:Disconnect() end)
            end
        end)
    end
    initInstantSkillCast()

    local activeSkillLoops = {}
    local function startSkillLoop(stateKey, skillNum)
        if activeSkillLoops[stateKey] then return end
        activeSkillLoops[stateKey] = true
        task.spawn(function()
            while states[stateKey] and scriptActive do
                if monsterNearby or killAuraActive then
                    pcall(function()
                        -- 1. СБРОС СОСТОЯНИЯ ИГРЫ (Освобождаем персонажа для нового действия)
                        _G.Skilling = false
                        _G.AttackAnim = nil

                        local char = player.Character
                        if char then
                            local ca = char:FindFirstChild("CanAttack")
                            if ca then ca.Value = true end
                            if char.PrimaryPart then
                                local p = char.PrimaryPart:FindFirstChild("SkillAlignPosition")
                                local o = char.PrimaryPart:FindFirstChild("SkillAlignOrientation")
                                if p then p.Enabled = false end
                                if o then o.Enabled = false end
                            end
                        end
                    
                        -- 2. СБРОС АНИМАЦИИ (Прерываем текущий каст на клиенте)
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            local animator = hum:FindFirstChildOfClass("Animator")
                            local tracks = animator and animator:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
                            if tracks then
                                for _, track in ipairs(tracks) do
                                    pcall(function()
                                        local tName = tostring(track.Name or "")
                                        if tName:find("Attack", 1, true) or tName:find("Skill", 1, true) or tName:find("SkillAttack", 1, true) then
                                            track:Stop(0)
                                        end
                                    end)
                                end
                            end
                        end
                    
                        -- 3. ОТПРАВКА СКИЛЛА
                        if skillRemote then
                            skillRemote:FireServer(skillNum)
                        end
                    end)
                
                    -- Пауза между кастами (регулируется через ползунок CPS в настройках)
                    local spd = tonumber(speeds and speeds.attack) or 20
                    if spd <= 0 then spd = 20 end
                    task.wait(1 / spd) 
                else
                    task.wait(0.3)
                end
            end
            activeSkillLoops[stateKey] = nil
        end)
    end

    -- === 5. MONSTER NEARBY CHECK ===
    task.spawn(function()
        while scriptActive do
            if states.attack or states.skill1 or states.skill2 or states.skill3 or killAuraActive then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local found = false
                
                if hrp then
                    local folder = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies") or workspace
                    for _, v in pairs(folder:GetChildren()) do
                        if v:IsA("Model") and v ~= char and v.Name ~= player.Name then
                            local vHum = v:FindFirstChildOfClass("Humanoid") or v:FindFirstChild("Humanoid")
                            local vHrp = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                            if vHum and vHrp and vHum.Health > 0 and (vHrp.Position - hrp.Position).Magnitude < 17 then
                                found = true
                                break 
                            end
                        end
                    end
                end
                monsterNearby = found
                task.wait(0.08)
            else
                monsterNearby = false
                task.wait(0.5) 
            end
        end
    end)

    -- === 6. NETWORK PAUSE FIX ===
    local CoreGui = game:GetService("CoreGui")
    local AntiGameplayPaused = nil
    
    local function destroyNetworkPause()
        pcall(function()
            local robloxGui = CoreGui:FindFirstChild("RobloxGui")
            if robloxGui then
                local netPause = robloxGui:FindFirstChild("CoreScripts/NetworkPause")
                if netPause then
                    netPause:Destroy()
                end
            end
        end)
    end
    
    task.spawn(function()
        destroyNetworkPause()
        if AntiGameplayPaused then
            AntiGameplayPaused:Disconnect()
            AntiGameplayPaused = nil
        end
        AntiGameplayPaused = CoreGui.ChildAdded:Connect(function(child)
            if child.Name == "RobloxGui" then
                task.wait(0.1)
                destroyNetworkPause()
            end
        end)
    end)

    -- === 7. ANTI AFK ===
    local xAFKx = nil
    pcall(function()
        xAFKx = player.Idled:Connect(function()
            local vu = game:GetService("VirtualUser")
            vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end)

    -- === 8. AUTO REJOIN ===
    local currentPlace = game.PlaceId
    local currentServer = game.JobId
    local autoReconnectEnabled = true
    
    local function reconnect()
        if player and autoReconnectEnabled then
            pcall(function()
                teleportService:TeleportToPlaceInstance(currentPlace, currentServer, player)
            end)
            task.wait(10)
            pcall(function()
                teleportService:Teleport(currentPlace, player)
            end)
        end
    end
    
    pcall(function()
        guiService.ErrorMessageChanged:Connect(function()
            local errorMsg = guiService:GetErrorMessage()
            if errorMsg and errorMsg ~= "" and autoReconnectEnabled then
                task.wait(5)
                reconnect()
            end
        end)
    end)

    -- =====================================================================
    --                            ATTACKS TAB
    -- =====================================================================
    MainTab:Column("left")

    local MoveSec = wrapSection(MainTab:CreateSection({ Name = "Movement & Speeds", Collapsible = true }))

    local speedLoopActive = false
    local speedCharConn = nil

    local function applySpeedHack(enable)
        isSpeedHack = enable
        pcall(function()
            local PropertyTribeTreeManager = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribeTreeManager"))
            local PropertyTribe = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribe"))
            local MathManager = require(rs:WaitForChild("Packages"):WaitForChild("MathManager"))
            local const = nil
            local WuKong = nil
            pcall(function()
                const = require(rs.Packages.PropertyTribeTreeManager.const)
                WuKong = require(rs.WuKong)
            end)

            local userTree = PropertyTribeTreeManager.GetUserTree(player.UserId)
            local battleTree = PropertyTribeTreeManager.GetBattleUserTree(player.UserId)

            if enable then
                if userTree and userTree.Friends then
                    userTree.Friends:ResetHandler(function()
                        local baseTribe = nil
                        if fakeFriendBonusActive then
                            for i = 1, 9 do
                                if MathManager.HasConfigPropertyTribe("Friends", i) then
                                    local cfg = MathManager.GetConfigPropertyTribe("Friends", i)
                                    baseTribe = if baseTribe then baseTribe + cfg else cfg:Clone()
                                end
                            end
                        else
                            local count = (WuKong and WuKong:ExecuteQuery("/Lua委托值/同服好友数量?获取缓存值")) or 0
                            if const then
                                for i = 1, count do
                                    if MathManager.HasConfigPropertyTribe(const.Regions.Friends, i) then
                                        local cfg = MathManager.GetConfigPropertyTribe(const.Regions.Friends, i)
                                        baseTribe = if baseTribe then baseTribe + cfg else cfg
                                    end
                                end
                            end
                        end

                        local speedTribe = PropertyTribe.new({
                            MoveSpeedRatio = (speedPercentValue or 50) / 100
                        })
                        return if baseTribe then baseTribe + speedTribe else speedTribe
                    end)
                    userTree.Friends:SetDirty(true)
                    userTree:SetDirty(true)
                end
                if battleTree then battleTree:SetDirty(true) end

                if not speedLoopActive then
                    speedLoopActive = true
                    task.spawn(function()
                        while isSpeedHack and speedLoopActive and scriptActive do
                            pcall(function()
                                local uTree = PropertyTribeTreeManager.GetUserTree(player.UserId)
                                local bTree = PropertyTribeTreeManager.GetBattleUserTree(player.UserId)
                                if uTree and uTree.Friends then
                                    uTree.Friends:SetDirty(true)
                                    uTree:SetDirty(true)
                                end
                                if bTree then bTree:SetDirty(true) end
                            end)
                            task.wait(0.5)
                        end
                    end)
                end
            else
                speedLoopActive = false
                if userTree and userTree.Friends then
                    userTree.Friends:ResetHandler(function()
                        local baseTribe = nil
                        if fakeFriendBonusActive then
                            for i = 1, 9 do
                                if MathManager.HasConfigPropertyTribe("Friends", i) then
                                    local cfg = MathManager.GetConfigPropertyTribe("Friends", i)
                                    baseTribe = if baseTribe then baseTribe + cfg else cfg:Clone()
                                end
                            end
                        else
                            local count = (WuKong and WuKong:ExecuteQuery("/Lua委托值/同服好友数量?获取缓存值")) or 0
                            if const then
                                for i = 1, count do
                                    if MathManager.HasConfigPropertyTribe(const.Regions.Friends, i) then
                                        local cfg = MathManager.GetConfigPropertyTribe(const.Regions.Friends, i)
                                        baseTribe = if baseTribe then baseTribe + cfg else cfg
                                    end
                                end
                            end
                        end
                        return baseTribe
                    end)
                    userTree.Friends:SetDirty(true)
                    userTree:SetDirty(true)
                end
                if battleTree then battleTree:SetDirty(true) end
            end
        end)
    end

    MoveSec:AddToggle({
        Name = "SpeedHack (Overdrive)",
        Default = false,
        Callback = function(state)
            isSpeedHack = state
            applySpeedHack(state)
            if state then
                if not speedCharConn then
                    speedCharConn = player.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if isSpeedHack then applySpeedHack(true) end
                    end)
                end
                Notify("Moro Soul", "SpeedHack Enabled (" .. (speedPercentValue or 50) .. "%)", 2, "Success")
            else
                if speedCharConn then
                    speedCharConn:Disconnect()
                    speedCharConn = nil
                end
                Notify("Moro Soul", "SpeedHack Disabled (Restored)", 2, "Info")
            end
        end
    })

    MoveSec:AddSlider({
        Name = "Speed Boost",
        Min = 0,
        Max = 300,
        Default = speedPercentValue or 50,
        Suffix = "%",
        Decimals = 0,
        Callback = function(val)
            speedPercentValue = tonumber(val) or 50
            if isSpeedHack then
                applySpeedHack(true)
            end
        end
    })

    table.insert(cleanupHandlers, function()
        speedLoopActive = false
        if isSpeedHack then
            applySpeedHack(false)
        end
        if speedCharConn then
            pcall(function() speedCharConn:Disconnect() end)
            speedCharConn = nil
        end
    end)

    MoveSec:AddSlider({
        Name = "CPS Speed",
        Min = 1,
        Max = 50,
        Default = speeds.attack or 20,
        Suffix = " cps",
        Decimals = 0,
        Callback = function(val)
            speeds.attack = tonumber(val) or 20
        end
    })

    MoveSec:AddToggle({
        Name = "Fast General Attack",
        Default = false,
        Callback = function(state)
            states.attack = state
        end
    })

    local SkillsSec = wrapSection(MainTab:CreateSection({ Name = "Fast Skills", Collapsible = true }))

    SkillsSec:AddToggle({
        Name = "Instant Cast (No Windup)",
        Default = true,
        Callback = function(state)
            instantSkillCastEnabled = state
        end
    })

    SkillsSec:AddToggle({
        Name = "Fast Skill 1",
        Default = false,
        Callback = function(state)
            states.skill1 = state
            if state then startSkillLoop("skill1", 1) end
        end
    })

    SkillsSec:AddToggle({
        Name = "Fast Skill 2",
        Default = false,
        Callback = function(state)
            states.skill2 = state
            if state then startSkillLoop("skill2", 2) end
        end
    })

    SkillsSec:AddToggle({
        Name = "Fast Skill 3",
        Default = false,
        Callback = function(state)
            states.skill3 = state
            if state then startSkillLoop("skill3", 3) end
        end
    })

    MainTab:Column("right")

    local AuraSec = wrapSection(MainTab:CreateSection({ Name = "Kill Aura V67 (Ultra)", Collapsible = true }))

    AuraSec:AddToggle({
        Name = "Kill Aura V67 (Ultra)",
        Default = false,
        Callback = function(state)
            killAuraActive = state
            states.attack = state
            
            if killAuraActive then
                task.spawn(function()
                    local target = nil
                    local lastTarget = nil
                    
                    while killAuraActive do
                        local char = player.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        
                        if hrp then
                            local isAlive = target and target.Parent 
                                and target:FindFirstChildOfClass("Humanoid") 
                                and target:FindFirstChildOfClass("Humanoid").Health > 0
                            
                            if not isAlive then
                                target = currentTarget
                                
                                if not target or not target.Parent then
                                    local monsters = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies")
                                    if monsters then
                                        local closestDist = math.huge
                                        for _, m in ipairs(monsters:GetChildren()) do
                                            local mHum = m:FindFirstChildOfClass("Humanoid")
                                            local mHrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                                            if mHum and mHrp and mHum.Health > 0 and mHum.Health >= minHealthLimit then
                                                local d = (mHrp.Position - hrp.Position).Magnitude
                                                if d < closestDist then
                                                    closestDist = d
                                                    target = m
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            
                            if target and target.Parent then
                                local tHrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
                                local tHum = target:FindFirstChildOfClass("Humanoid")
                                
                                if tHrp and tHum and tHum.Health > 0 then
                                    local currentDist = (hrp.Position - tHrp.Position).Magnitude
                                    if target ~= lastTarget or currentDist > 12 then
                                        lastTarget = target
                                        local targetCF = tHrp.CFrame * CFrame.new(0, tpHeight or 2, 2)
                                        hrp.CFrame = CFrame.lookAt(targetCF.Position, tHrp.Position)
                                        hrp.AssemblyLinearVelocity = Vector3.zero
                                        hrp.AssemblyAngularVelocity = Vector3.zero
                                    end
                                    
                                    if char:FindFirstChild("LockedEnermy") and char.LockedEnermy.Value ~= target then
                                        char.LockedEnermy.Value = target
                                    end
                                    
                                    _G.Attacking = false
                                    _G.Skilling = false
                                else
                                    target = nil
                                    lastTarget = nil
                                end
                            else
                                target = nil
                                lastTarget = nil
                            end
                        end
                        task.wait(0.08)
                    end
                    
                    if player.Character and player.Character:FindFirstChild("LockedEnermy") then
                        player.Character.LockedEnermy.Value = nil
                    end
                end)
                Notify("Moro Soul", "Kill Aura Activated!", 2, "Success")
            else
                Notify("Moro Soul", "Kill Aura Disabled", 2, "Info")
            end
        end
    })

    AuraSec:AddToggle({
        Name = "Priority: Max HP First",
        Default = false,
        Callback = function(state)
            priorityHighHP = state
        end
    })

    AuraSec:AddSlider({
        Name = "Kill Aura TP Height",
        Min = -5,
        Max = 15,
        Default = tpHeight or 2,
        Suffix = " studs",
        Decimals = 0,
        Callback = function(val)
            tpHeight = tonumber(val) or 2
        end
    })

    AuraSec:AddTextbox({
        Name = "Min HP Filter",
        Default = tostring(minHealthLimit),
        Placeholder = "0",
        Numeric = true,
        Callback = function(val)
            minHealthLimit = tonumber(val) or 0
        end
    })

    local EventSec = wrapSection(MainTab:CreateSection({ Name = "Event Farms", Collapsible = true }))

    EventSec:AddToggle({
        Name = "Christmas Aura V2",
        Default = false,
        Callback = function(state)
            _G.ChristmasAuraV2 = state
            if not state then
                workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
                end
            end
            Notify("System", state and "Christmas Farm V2 Active!" or "Disabled", 2, state and "Success" or "Info")
        end
    })

    _G.ChristmasAuraV2 = false

    task.spawn(function()
        local camera = workspace.CurrentCamera
        local genAttack = remoteFolder:WaitForChild("GeneralAttack")
        
        local function GetBoss()
            local folder = workspace:FindFirstChild("Monsters") or workspace:FindFirstChild("Enemies")
            if folder then
                for _, e in ipairs(folder:GetChildren()) do
                    if e:IsA("Model") then
                        local hum = e:FindFirstChildOfClass("Humanoid")
                        local hrp = e:FindFirstChild("HumanoidRootPart") or e.PrimaryPart
                        if hum and hrp and hum.Health > 0 and hum.MaxHealth >= 5000000 then
                            return e
                        end
                    end
                end
            end
            return nil
        end

        local camCfg = {
            z1 = {p = Vector3.new(195, 142, -336), l = Vector3.new(195, 0, -336)},
            z2 = {p = Vector3.new(28, 147, -36), l = Vector3.new(28, 0, -36)}
        }

        while true do
            if _G.ChristmasAuraV2 then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                
                if hrp then
                    local function UpdateCam(pos)
                        local d1 = (pos - camCfg.z1.l).Magnitude
                        local d2 = (pos - camCfg.z2.l).Magnitude
                        local current = d1 < d2 and camCfg.z1 or camCfg.z2
                        
                        camera.CameraType = Enum.CameraType.Scriptable
                        camera.CFrame = CFrame.new(current.p, current.l) * CFrame.Angles(0, 0, math.rad(90))
                    end

                    local targetBoss = GetBoss()
                    
                    if targetBoss then
                        local tHrp = targetBoss:FindFirstChild("HumanoidRootPart") or targetBoss.PrimaryPart
                        local tHum = targetBoss:FindFirstChildOfClass("Humanoid")
                        if tHrp and tHum then
                            UpdateCam(tHrp.Position)
                            hrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            
                            while _G.ChristmasAuraV2 and tHum.Health > 0 and targetBoss.Parent do
                                if (hrp.Position - tHrp.Position).Magnitude > 12 then
                                    hrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3)
                                    hrp.AssemblyLinearVelocity = Vector3.zero
                                end
                                genAttack:FireServer(4)
                                task.wait(speeds and 1 / (speeds.attack or 20))
                            end
                        end
                    else
                        local ghostPos = workspace:FindFirstChild("GhostPos")
                        if ghostPos then
                            local zones = {"荒野", "无线列车", "主公宅邸", "紫藤山"}
                            for _, name in ipairs(zones) do
                                local f = ghostPos:FindFirstChild(name)
                                if f then
                                    for _, obj in ipairs(f:GetDescendants()) do
                                        if not _G.ChristmasAuraV2 or GetBoss() then break end
                                        if obj:IsA("BasePart") and obj.Name ~= "对象038" then
                                            UpdateCam(obj.Position) 
                                            hrp.CFrame = obj.CFrame
                                            hrp.AssemblyLinearVelocity = Vector3.zero
                                            for k = 1, 6 do
                                                genAttack:FireServer(4)
                                                task.wait(speeds and 1 / (speeds.attack or 20))
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
    end)

    -- SPRING FARM
    local flySpeed = 250
    local isFlying = false
    local currentTween = nil

    local function patrolFly(targetCFrame)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        isFlying = true
        local distance = (hrp.Position - targetCFrame.Position).Magnitude
        local duration = distance / flySpeed
        
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
        local tween = tweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
        
        tween.Completed:Connect(function()
            task.wait(0.1) 
            isFlying = false 
        end)
        
        tween:Play()
        return tween
    end

    EventSec:AddToggle({
        Name = "Spring farm",
        Default = false,
        Callback = function(state)
            _G.SpringFarm = state
            states.attack = state 
            if state then
                Notify("Moro Soul", "Priority Patrol Started", 2, "Info")
            else
                isFlying = false
                if currentTween then currentTween:Cancel() end
            end
        end
    })

    local farmPoints = {
        Vector3.new(208, 30, -319),
        Vector3.new(6, 30, -52),
        Vector3.new(209, 30, 219),
        Vector3.new(437, 30, 478),
        Vector3.new(386, 30, 740),
        Vector3.new(438, 30, 1014)
    }
    local currentPointIdx = 1

    task.spawn(function()
        local lastFoundTime = tick()

        while task.wait(0.15) do
            if _G.SpringFarm then
                local monsters = workspace:FindFirstChild("Monsters")
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                
                if monsters and hrp then
                    local target = nil
                    
                    if isFlying then
                        lastFoundTime = tick()
                        continue 
                    end

                    for _, monster in ipairs(monsters:GetChildren()) do
                        local tHum = monster:FindFirstChildOfClass("Humanoid")
                        if tHum and tHum.Health > 0 then
                            local hasHat = monster:FindFirstChild("SpringHat")
                            local isBoss = tHum.MaxHealth >= 5000000
                            
                            if hasHat or isBoss then
                                local targetPart = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChild("Head") or monster.PrimaryPart
                                if hasHat and monster.SpringHat:FindFirstChild("Handle") then
                                    targetPart = monster.SpringHat.Handle
                                end
                                
                                if targetPart then
                                    target = {monster = monster, part = targetPart, hum = tHum, type = isBoss and "BOSS" or "EVENT"}
                                    break 
                                end
                            end
                        end
                    end

                    if target then
                        lastFoundTime = tick()
                        local targetCF = target.part.CFrame * CFrame.new(0, tpHeight or 2, 0)
                        hrp.CFrame = targetCF
                        
                        while _G.SpringFarm and target.hum.Health > 0 and target.monster.Parent do
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            local currentTargetCF = target.part.CFrame
                            if (hrp.Position - currentTargetCF.Position).Magnitude > 12 then
                                hrp.CFrame = currentTargetCF * CFrame.new(0, tpHeight or 2, 0)
                            end
                            task.wait(0.1)
                        end
                    else
                        if (tick() - lastFoundTime) > 3 then
                            currentPointIdx = currentPointIdx + 1
                            if currentPointIdx > #farmPoints then 
                                currentPointIdx = 1 
                                hrp.CFrame = CFrame.new(farmPoints[currentPointIdx])
                                Notify("Moro Soul", "Teleported to Start", 1, "Info")
                                lastFoundTime = tick()
                            else
                                currentTween = patrolFly(CFrame.new(farmPoints[currentPointIdx]))
                            end
                        end
                    end
                end
            end
        end
    end)

    -- =====================================================================
    --                             TRAIN TAB
    -- =====================================================================
    do
    local autoTrain = false
    local autoTrainV2 = false
    _G.TrainSkillNumber = 2

    local function AdvanceTrainLevel()
        local it = workspace:FindFirstChild("InfinityTrain")
        if not it or not it.PrimaryPart then return end
        
        local trigger = it.PrimaryPart:FindFirstChild("ContinueTrigger")
        local prompt = trigger and trigger:FindFirstChildWhichIsA("ProximityPrompt")
        
        if prompt and fireproximityprompt then
            fireproximityprompt(prompt)
            return
        end
        
        if AttackHelper and AttackHelper.GoToNextTrain then
            pcall(function()
                AttackHelper.GoToNextTrain(it.PrimaryPart.PlayerSpawnPos.WorldCFrame, it.PrimaryPart.GhostSpawnPos.WorldCFrame)
            end)
            return
        end
        
        local nextDoor = it:FindFirstChild("Portal") and it.Portal:FindFirstChild("Next")
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp and nextDoor then
            hrp.CFrame = nextDoor.CFrame
            task.wait(0.08)
            vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.1)
            vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end

    -- Train Mode V1 (General Attack)
    task.spawn(function()
        while true do
            task.wait(0.15)
            if autoTrain then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local it = workspace:FindFirstChild("InfinityTrain")
                if not hrp or not it then continue end

                local trainPoint = it:FindFirstChild("Train")
                if trainPoint and (hrp.Position - trainPoint.Position).Magnitude > 10 then
                    hrp.CFrame = trainPoint.CFrame * CFrame.new(0, 2, 0)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end

                local monster = nil
                local scanStart = tick()
                while autoTrain and not monster and (tick() - scanStart < 4) do
                    local monsters = workspace:FindFirstChild("Monsters")
                    if monsters and trainPoint then
                        for _, v in ipairs(monsters:GetChildren()) do
                            local hum = v:FindFirstChildOfClass("Humanoid")
                            local part = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                            if hum and part and hum.Health > 0 then
                                if (part.Position - trainPoint.Position).Magnitude < 60 then
                                    monster = v
                                    break
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end

                if monster and autoTrain then
                    local mHrp = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
                    local mHum = monster:FindFirstChildOfClass("Humanoid")
                    
                    if mHrp and hrp then
                        hrp.CFrame = CFrame.lookAt(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                    
                    while autoTrain and mHum and mHum.Health > 0 and monster.Parent do
                        if mHrp and hrp and (hrp.Position - mHrp.Position).Magnitude > 12 then
                            hrp.CFrame = CFrame.lookAt(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                        
                        _G.Attacking = false
                        attackRemote:FireServer(4) 
                        task.wait(1 / (speeds.attack or 20))
                    end
                    task.wait(0.1)
                end

                if autoTrain then
                    AdvanceTrainLevel()
                    task.wait(0.3)
                end
            end
        end
    end)

    -- Train Mode V2 (Attack + Selected Skill)
    task.spawn(function()
        while true do
            task.wait(0.15)
            if autoTrainV2 then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local it = workspace:FindFirstChild("InfinityTrain")
                if not hrp or not it then continue end

                local trainPoint = it:FindFirstChild("Train")
                if trainPoint and (hrp.Position - trainPoint.Position).Magnitude > 10 then
                    hrp.CFrame = trainPoint.CFrame * CFrame.new(0, 2, 0)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end

                local monster = nil
                local scanStart = tick()
                while autoTrainV2 and not monster and (tick() - scanStart < 4) do
                    local monsters = workspace:FindFirstChild("Monsters")
                    if monsters and trainPoint then
                        for _, v in ipairs(monsters:GetChildren()) do
                            local hum = v:FindFirstChildOfClass("Humanoid")
                            local part = v:FindFirstChild("HumanoidRootPart") or v.PrimaryPart
                            if hum and part and hum.Health > 0 then
                                if (part.Position - trainPoint.Position).Magnitude < 60 then
                                    monster = v
                                    break
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end

                if monster and autoTrainV2 then
                    local mHrp = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
                    local mHum = monster:FindFirstChildOfClass("Humanoid")
                    
                    if mHrp and hrp then
                        hrp.CFrame = CFrame.lookAt(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                    
                    while autoTrainV2 and mHum and mHum.Health > 0 and monster.Parent do
                        if mHrp and hrp and (hrp.Position - mHrp.Position).Magnitude > 12 then
                            hrp.CFrame = CFrame.lookAt(mHrp.Position + Vector3.new(0, 0, 3), mHrp.Position)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                        end
                        
                        _G.Attacking = false
                        _G.Skilling = false
                        attackRemote:FireServer(4) 
                        skillRemote:FireServer(_G.TrainSkillNumber)
                        
                        task.wait(1 / (speeds.attack or 20))
                    end
                    task.wait(0.1)
                end

                if autoTrainV2 then
                    AdvanceTrainLevel()
                    task.wait(0.3)
                end
            end
        end
    end)

    TrainTab:Column("left")

    local TrainSec = wrapSection(TrainTab:CreateSection({ Name = "Infinity Train Farming", Collapsible = true }))

    TrainSec:AddToggle({
        Name = "Infinity Train (TP Mode)",
        Default = false,
        Callback = function(state)
            autoTrain = state
            if state then autoTrainV2 = false end
            Notify("Moro Soul", state and "Auto Train Active" or "Disabled", 2, state and "Success" or "Info")
        end
    })

    TrainSec:AddToggle({
        Name = "Infinity Train V2 (Skills)",
        Default = false,
        Callback = function(state)
            autoTrainV2 = state
            if state then autoTrain = false end
            Notify("Moro Soul", state and "Train V2 Active" or "Train V2 Disabled", 2, state and "Success" or "Info")
        end
    })

    TrainSec:AddDropdown({
        Name = "Train V2 Skill",
        Options = {"Skill 1", "Skill 2", "Skill 3"},
        Default = "Skill 2",
        Callback = function(selected)
            if selected == "Skill 1" then
                _G.TrainSkillNumber = 1
            elseif selected == "Skill 2" then
                _G.TrainSkillNumber = 2
            elseif selected == "Skill 3" then
                _G.TrainSkillNumber = 3
            end
            Notify("Moro Soul", "Train V2 using: " .. tostring(selected), 2, "Info")
        end
    })

    TrainTab:Column("right")

    local TrainTpSec = wrapSection(TrainTab:CreateSection({ Name = "Train Teleports", Collapsible = true }))

    TrainTpSec:AddButton({
        Name = "Teleport to Train Entrance 1",
        Primary = false,
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local entrance = workspace:FindFirstChild("PromptTriggers") and workspace.PromptTriggers:FindFirstChild("Train_Entrance_1")
            if hrp and entrance then
                hrp.CFrame = entrance.CFrame + Vector3.new(0, 3, 0)
                Notify("Moro Soul", "Teleported to Train Entrance 1", 2, "Success")
            else
                Notify("Error", "Entrance point not found!", 2, "Error")
            end
        end
    })

    TrainTpSec:AddButton({
        Name = "Teleport to Train Entrance 2",
        Primary = false,
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local entrance = workspace:FindFirstChild("PromptTriggers") and workspace.PromptTriggers:FindFirstChild("Train_Entrance_2")
            if hrp and entrance then
                hrp.CFrame = entrance.CFrame + Vector3.new(0, 3, 0)
                Notify("Moro Soul", "Teleported to Train Entrance 2", 2, "Success")
            else
                Notify("Error", "Entrance 2 not found!", 2, "Error")
            end
        end
    })
    end

    -- =====================================================================
    --                           FISHING & FOOD TAB
    -- =====================================================================
    do
    local autoFishing = false
    local fishingArea = "Area_1"
    
    local fishingAreasList = {"Area_1", "Area_2", "Area_Chris"}
    pcall(function()
        local fRoot = workspace:FindFirstChild("Fishing")
        if fRoot then
            local foundAreas = {}
            for _, c in ipairs(fRoot:GetChildren()) do
                if c:FindFirstChild("FishingPoint") then
                    table.insert(foundAreas, c.Name)
                end
            end
            if #foundAreas > 0 then
                table.sort(foundAreas)
                fishingAreasList = foundAreas
            end
        end
    end)

    task.spawn(function()
        local startRemote = remoteFolder:WaitForChild("StartFishing")
        local pullRemote = remoteFolder:WaitForChild("PullFish")
        local autoFishRemote = remoteFolder:FindFirstChild("AutoFishing")
        
        while true do
            if autoFishing then
                local fishingRoot = workspace:FindFirstChild("Fishing")
                local targetPoint = fishingRoot and fishingRoot:FindFirstChild(fishingArea) and fishingRoot[fishingArea]:FindFirstChild("FishingPoint")
                local prompt = targetPoint and targetPoint:FindFirstChildWhichIsA("ProximityPrompt")
                
                if prompt then
                    if autoFishRemote then
                        autoFishRemote:FireServer(prompt)
                    else
                        startRemote:FireServer(prompt)
                    end
                    
                    task.wait(0.1)
                    
                    for i = 1, 30 do
                        if not autoFishing then break end
                        pullRemote:FireServer()
                        task.wait(0.05)
                    end
                end
            end
            task.wait(0.5)
        end
    end)

    FishTab:Column("left")

    local FishSec = wrapSection(FishTab:CreateSection({ Name = "Auto Fishing", Collapsible = true }))
    
    FishSec:AddToggle({
        Name = "Auto Fishing",
        Default = false,
        Callback = function(state)
            autoFishing = state
            Notify("Moro Soul", state and "Auto Fish Active" or "Disabled", 2, state and "Success" or "Info")
        end
    })
    
    FishSec:AddDropdown({
        Name = "Fishing Area",
        Options = fishingAreasList,
        Default = fishingAreasList[1] or "Area_1",
        Callback = function(val)
            fishingArea = val
            Notify("Moro Soul", "Fishing Area: " .. tostring(val), 2, "Info")
        end
    })
    
    FishSec:AddButton({
        Name = "Teleport to Fishing Point",
        Primary = false,
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local fRoot = workspace:FindFirstChild("Fishing")
            local fPoint = fRoot and fRoot:FindFirstChild(fishingArea) and fRoot[fishingArea]:FindFirstChild("FishingPoint")
            
            if hrp and fPoint then
                hrp.CFrame = fPoint.CFrame + Vector3.new(0, 3, 0)
                Notify("Moro Soul", "Teleported to " .. tostring(fishingArea), 2, "Success")
            else
                Notify("Moro Soul", "Fishing area point not found", 2, "Warning")
            end
        end
    })

    FishSec:AddButton({
        Name = "Cancel Fishing",
        Primary = false,
        Callback = function()
            local cancelRemote = remoteFolder:FindFirstChild("CancelFishing")
            if cancelRemote then
                cancelRemote:FireServer()
                Notify("Moro Soul", "Fishing Cancelled", 2, "Info")
            end
        end
    })

    FishTab:Column("right")

    -- =====================================================================
    --                         FOOD & BUFF SUBSYSTEM
    -- =====================================================================
    local PTTM = nil
    pcall(function() PTTM = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribeTreeManager")) end)

    local MathManager = nil
    pcall(function() MathManager = require(rs:WaitForChild("Packages"):WaitForChild("MathManager")) end)

    local constPT = nil
    pcall(function() constPT = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribeTreeManager"):WaitForChild("const")) end)

    local WuKongDataProvider = nil
    pcall(function() WuKongDataProvider = require(rs:WaitForChild("Packages"):WaitForChild("WuKongDataProvider")) end)

    local FoodVendor = nil
    pcall(function() FoodVendor = require(rs:WaitForChild("UI"):WaitForChild("FoodCook"):WaitForChild("Model"):WaitForChild("Vendor")) end)

    local foodInfoList = {
        { id = "食物22", craftId = "食物合成22", name = "Tuna Sashimi", buff = "+50% Skill Dmg", props = { SkillDamageAddition = 0.5 } },
        { id = "食物20", craftId = "食物合成20", name = "Koi Sashimi", buff = "+50% Crit Rate", props = { CriticalStrikeRate = 0.5 } },
        { id = "食物21", craftId = "食物合成21", name = "Salmon Sashimi", buff = "+50% Double Atk", props = { DoubleAttackPercent = 1 } },
        { id = "食物26", craftId = "食物合成26", name = "Pumpkin Pie", buff = "+30% Triple, +15% Dbl", props = { TripleAttackPercent = 1, DoubleAttackPercent = 1 } },
        { id = "食物15", craftId = "食物合成15", name = "Steamed Tilapia", buff = "+15% Boss Dmg", props = { BossDamageAddition = 0.15 } },
        { id = "食物24", craftId = "食物合成24", name = "Green Salad", buff = "+100% Move Speed", props = { MoveSpeedRatio = 1.0 } },
        { id = "食物27", craftId = nil,            name = "Halloween Candy", buff = "+100% Drops", props = { DropRateAddition = 1.0 } },
        { id = "食物28", craftId = nil,            name = "Gingerbread Man", buff = "+100% Drops", props = { DropRateAddition = 1.0 } },
        { id = "食物16", craftId = "食物合成16", name = "Steamed Snapper", buff = "+60% Atk, +15% Dbl", props = { AttackDamageRatio = 0.6, DoubleAttackPercent = 1 } },
        { id = "食物17", craftId = "食物合成17", name = "Cod Sushi", buff = "+15% Atk, +15% Crit", props = { AttackDamageRatio = 0.15, CriticalStrikeRate = 0.15 } },
        { id = "食物18", craftId = "食物合成18", name = "Sea Bass Sushi", buff = "+15% Atk, +35% Shield", props = { AttackDamageRatio = 0.15, ShieldAddition = 0.35 } },
        { id = "食物19", craftId = "食物合成19", name = "Unagi Sushi", buff = "+15% Atk, +15% Dbl", props = { AttackDamageRatio = 0.15, DoubleAttackPercent = 1 } },
        { id = "食物25", craftId = "食物合成25", name = "Fried Rice", buff = "+15% Atk, +40% Energy", props = { AttackDamageRatio = 0.15, EnergyRecoverySpeedRatio = 0.4 } },
        { id = "食物6",  craftId = "食物合成6",  name = "Roasted Snakehead", buff = "+15% Atk Ratio", props = { AttackDamageRatio = 0.15 } },
        { id = "食物12", craftId = "食物合成12", name = "Black Fish Soup", buff = "+15% Atk Ratio", props = { AttackDamageRatio = 0.15 } },
        { id = "食物11", craftId = "食物合成11", name = "Fugu Soup", buff = "+60% Attack Dmg", props = { AttackDamageRatio = 0.6 } },
        { id = "食物5",  craftId = "食物合成5",  name = "Roasted River Fish", buff = "+60% Attack Dmg", props = { AttackDamageRatio = 0.6 } },
        { id = "食物1",  craftId = "食物合成1",  name = "Roasted Grass Carp", buff = "+15% Skill3", props = { SkillDamageAddition = 0.15 } },
        { id = "食物7",  craftId = "食物合成7",  name = "Katsuobu Soup", buff = "+15% Skill3", props = { SkillDamageAddition = 0.15 } },
        { id = "食物2",  craftId = "食物合成2",  name = "Roasted Basa Fish", buff = "+40% Energy", props = { EnergyRecoverySpeedRatio = 0.4 } },
        { id = "食物8",  craftId = "食物合成8",  name = "Basa Fish Soup", buff = "+40% Energy", props = { EnergyRecoverySpeedRatio = 0.4 } },
        { id = "食物14", craftId = "食物合成14", name = "Steamed Mackerel", buff = "+40% Energy, +15% Skill3", props = { EnergyRecoverySpeedRatio = 0.4, SkillDamageAddition = 0.15 } },
        { id = "食物3",  craftId = "食物合成3",  name = "Roasted Mandarin Fish", buff = "+35% Shield", props = { ShieldAddition = 0.35 } },
        { id = "食物9",  craftId = "食物合成9",  name = "Mandarin Fish Soup", buff = "+35% Shield", props = { ShieldAddition = 0.35 } },
        { id = "食物13", craftId = "食物合成13", name = "Steamed Flounder", buff = "+35% Shield", props = { ShieldAddition = 0.35 } },
        { id = "食物4",  craftId = "食物合成4",  name = "Roast Carp", buff = "+50% Move Speed", props = { MoveSpeedRatio = 0.5 } },
        { id = "食物10", craftId = "食物合成10", name = "Carp Soup", buff = "+50% Move Speed", props = { MoveSpeedRatio = 0.5 } },
        { id = "食物23", craftId = "食物合成23", name = "Jam", buff = "+50% Move Speed", props = { MoveSpeedRatio = 0.5 } }
    }

    local foodDropdownNames = {}
    local foodMap = {}
    for _, item in ipairs(foodInfoList) do
        local label = item.name .. " (" .. item.buff .. ")"
        table.insert(foodDropdownNames, label)
        foodMap[label] = item
    end

    local selectedFoodItem = foodInfoList[1]
    local cookAmount = 10
    local autoEatBestFoods = false

    -- === SECTION 1: FOOD CRAFTING & GRANTING ===
    local FoodCraftSec = wrapSection(FishTab:CreateSection({ Name = "Food Crafting & Granting", Collapsible = true }))

    -- Fast map gatherer
    FoodCraftSec:AddButton({
        Name = "Collect All Ingredients (Fast)",
        Primary = true,
        Callback = function()
            task.spawn(function()
                local container = workspace:FindFirstChild("FoodMaterialContainer")
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

                if not hrp or not container then
                    Notify("Error", "Food container not found", 2, "Error")
                    return
                end

                local prompts = {}
                for _, item in ipairs(container:GetDescendants()) do
                    if item:IsA("ProximityPrompt") and item.Parent and item.Parent:IsA("BasePart") then
                        table.insert(prompts, item)
                    end
                end

                Notify("Moro Soul", "Collecting " .. #prompts .. " food ingredients...", 2, "Info")
                local savedCF = hrp.CFrame

                for _, prompt in ipairs(prompts) do
                    if prompt.Parent and prompt.Parent:IsA("BasePart") then
                        hrp.CFrame = prompt.Parent.CFrame
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        
                        if fireproximityprompt then
                            fireproximityprompt(prompt)
                        else
                            vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            task.wait(0.04)
                            vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        end
                        task.wait(0.05)
                    end
                end

                hrp.CFrame = savedCF
                Notify("Moro Soul", "Collected all map food items!", 2, "Success")
            end)
        end
    })

    FoodCraftSec:AddDropdown({
        Name = "Select Food",
        Options = foodDropdownNames,
        Default = foodDropdownNames[1],
        Callback = function(val)
            if foodMap[val] then
                selectedFoodItem = foodMap[val]
            end
        end
    })

    FoodCraftSec:AddSlider({
        Name = "Cook / Craft Amount",
        Min = 1,
        Max = 100,
        Default = 10,
        Suffix = " pcs",
        Decimals = 0,
        Callback = function(val)
            cookAmount = tonumber(val) or 10
        end
    })

    FoodCraftSec:AddButton({
        Name = "Cook Selected Food",
        Primary = false,
        Callback = function()
            task.spawn(function()
                if not WuKong then
                    pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end)
                end
                if not WuKong then
                    Notify("Moro Soul", "WuKong system unavailable", 2, "Error")
                    return
                end

                local item = selectedFoodItem
                if not item or not item.craftId then
                    Notify("Moro Soul", "Selected food has no recipe", 2, "Warning")
                    return
                end

                local amt = cookAmount or 1
                local actionPath = ("/食物系统/食物合成/%s?多次购买"):format(item.craftId)
                local res = nil
                if amt > 1 then
                    res = WuKong:ExecuteAction(actionPath, amt)
                else
                    res = WuKong:ExecuteAction(("/食物系统/食物合成/%s?购买"):format(item.craftId))
                end

                local curCount = 0
                pcall(function()
                    curCount = WuKong:ExecuteQuery(("/食物系统/食物背包/%s?获取元素数量"):format(item.id)) or 0
                end)

                if res and (not res.HasError or res.Receive) then
                    Notify("Moro Soul", ("Crafted %s! Total: %d"):format(item.name, curCount), 2.5, "Success")
                else
                    Notify("Moro Soul", "Failed to cook. Missing ingredients?", 2.5, "Warning")
                end
            end)
        end
    })

    FoodCraftSec:AddButton({
        Name = "Auto-Cook All Available (1-Click)",
        Primary = false,
        Callback = function()
            task.spawn(function()
                if not WuKong then
                    pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end)
                end
                if not FoodVendor then
                    pcall(function() FoodVendor = require(rs:WaitForChild("UI"):WaitForChild("FoodCook"):WaitForChild("Model"):WaitForChild("Vendor")) end)
                end
                if not WuKong or not FoodVendor then
                    Notify("Moro Soul", "Cooking subsystem unavailable", 2, "Error")
                    return
                end

                Notify("Moro Soul", "Scanning recipes & cooking...", 2, "Info")
                local cookedCount = 0
                local totalItems = 0

                for i = 1, 26 do
                    local craftId = "食物合成" .. i
                    local canCook = FoodVendor:CanCookFood(craftId)
                    if canCook then
                        local maxPossible = 999
                        local ings = FoodVendor:GetIngredientsInfo(craftId)
                        for _, ing in ipairs(ings) do
                            local owned = FoodVendor:GetIngredientCnt(ing.Id) or 0
                            local possible = math.floor(owned / (ing.Count or 1))
                            if possible < maxPossible then maxPossible = possible end
                        end

                        if maxPossible > 0 then
                            local act = nil
                            if maxPossible > 1 then
                                act = WuKong:ExecuteAction(("/食物系统/食物合成/%s?多次购买"):format(craftId), maxPossible)
                            else
                                act = WuKong:ExecuteAction(("/食物系统/食物合成/%s?购买"):format(craftId))
                            end
                            cookedCount = cookedCount + 1
                            totalItems = totalItems + maxPossible
                        end
                    end
                end

                if totalItems > 0 then
                    Notify("Moro Soul", ("Cooked %d items across %d recipes!"):format(totalItems, cookedCount), 3, "Success")
                else
                    Notify("Moro Soul", "No recipes can be cooked. Gather ingredients first!", 3, "Warning")
                end
            end)
        end
    })

    FoodCraftSec:AddButton({
        Name = "Buy Shop Foods (13-16) for Gold",
        Primary = false,
        Callback = function()
            task.spawn(function()
                if not WuKong then
                    pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end)
                end
                if not WuKong then return end

                local buyIds = { "购买食物13", "购买食物14", "购买食物15", "购买食物16" }
                local bought = 0
                for _, bId in ipairs(buyIds) do
                    local res = WuKong:ExecuteAction(("/食物系统/食物购买/%s?购买"):format(bId))
                    if res and not res.HasError then
                        bought = bought + 1
                    end
                    task.wait(0.05)
                end
                Notify("Moro Soul", ("Bought shop foods (%d/4)"):format(bought), 2, "Success")
            end)
        end
    })

    local persistentFoodTribe = nil
    local activeFoodIds = {}
    local origWuKongQuery = nil
    local foodLoopActive = false
    local foodCharConn = nil

    local function applyInfiniteFoodState(enable)
        infiniteFoodActive = enable
        pcall(function()
            local PropertyTribeTreeManager = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribeTreeManager"))
            local PropertyTribe = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribe"))
            if not WuKong then
                pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end)
            end

            local userTree = PropertyTribeTreeManager.GetUserTree(player.UserId)
            local battleTree = PropertyTribeTreeManager.GetBattleUserTree(player.UserId)

            if enable then
                if WuKong and not origWuKongQuery and WuKong.ExecuteQuery then
                    origWuKongQuery = WuKong.ExecuteQuery
                    WuKong.ExecuteQuery = function(self, path, ...)
                        if infiniteFoodActive and typeof(path) == "string" and path:find("食物") then
                            if path:find("激活") or path:find("状态") then
                                for fId in pairs(activeFoodIds) do
                                    if path:find(fId) then return true end
                                end
                            elseif path:find("时间") or path:find("倒计时") or path:find("剩余") then
                                for fId in pairs(activeFoodIds) do
                                    if path:find(fId) then return 999999 end
                                end
                            end
                        end
                        return origWuKongQuery(self, path, ...)
                    end
                end

                if not persistentFoodTribe and userTree and userTree.Foods then
                    pcall(function()
                        local currentSum = userTree.Foods:Sum()
                        if currentSum and next(currentSum:GetAllProperties()) then
                            persistentFoodTribe = currentSum:Clone()
                        end
                    end)
                end

                if not persistentFoodTribe then
                    persistentFoodTribe = PropertyTribe.new({
                        SkillDamageAddition = 0.5,
                        CriticalStrikeRate = 0.5,
                        DoubleAttackPercent = 1,
                        TripleAttackPercent = 1,
                        BossDamageAddition = 0.15,
                        AttackDamageRatio = 0.6,
                        MoveSpeedRatio = 1.0,
                    })
                    activeFoodIds["食物22"] = true
                    activeFoodIds["食物20"] = true
                    activeFoodIds["食物21"] = true
                    activeFoodIds["食物26"] = true
                    activeFoodIds["食物15"] = true
                    activeFoodIds["食物16"] = true
                    activeFoodIds["食物24"] = true
                end

                if userTree and userTree.Foods then
                    userTree.Foods:ResetHandler(function()
                        if infiniteFoodActive and persistentFoodTribe then
                            return persistentFoodTribe
                        end
                    end)
                    userTree.Foods:SetDirty(true)
                    userTree:SetDirty(true)
                end
                if battleTree then battleTree:SetDirty(true) end

                if not foodLoopActive then
                    foodLoopActive = true
                    task.spawn(function()
                        while infiniteFoodActive and foodLoopActive and scriptActive do
                            pcall(function()
                                local uTree = PropertyTribeTreeManager.GetUserTree(player.UserId)
                                local bTree = PropertyTribeTreeManager.GetBattleUserTree(player.UserId)
                                if uTree and uTree.Foods then
                                    uTree.Foods:SetDirty(true)
                                    uTree:SetDirty(true)
                                end
                                if bTree then bTree:SetDirty(true) end
                            end)
                            task.wait(1)
                        end
                    end)
                end
            else
                foodLoopActive = false
                if origWuKongQuery and WuKong then
                    WuKong.ExecuteQuery = origWuKongQuery
                    origWuKongQuery = nil
                end
                if userTree and userTree.Foods then
                    pcall(function()
                        local FoodModule = require(rs.Packages.PropertyTribeTreeManager.User.Food)
                        local freshTree = FoodModule.GetFoodTree({ userId = player.UserId })
                        userTree.Foods = freshTree
                    end)
                    userTree.Foods:SetDirty(true)
                    userTree:SetDirty(true)
                end
                if battleTree then battleTree:SetDirty(true) end
            end
        end)
    end

    local function applyTopFoodBuffsPermanent()
        pcall(function()
            local PropertyTribe = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribe"))
            persistentFoodTribe = PropertyTribe.new({
                SkillDamageAddition = 0.5,
                CriticalStrikeRate = 0.5,
                DoubleAttackPercent = 1,
                TripleAttackPercent = 1,
                BossDamageAddition = 0.15,
                AttackDamageRatio = 0.6,
                MoveSpeedRatio = 1.0,
            })
            activeFoodIds["食物22"] = true
            activeFoodIds["食物20"] = true
            activeFoodIds["食物21"] = true
            activeFoodIds["食物26"] = true
            activeFoodIds["食物15"] = true
            activeFoodIds["食物16"] = true
            activeFoodIds["食物24"] = true
            applyInfiniteFoodState(true)
        end)
    end

    FoodCraftSec:AddButton({
        Name = "Eat Selected Food",
        Primary = false,
        Callback = function()
            task.spawn(function()
                if not WuKong then
                    pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end)
                end
                local item = selectedFoodItem
                if not item or not WuKong then return end

                local cnt = WuKong:ExecuteQuery(("/食物系统/食物背包/%s?获取元素数量"):format(item.id)) or 0
                if cnt <= 0 then
                    Notify("Moro Soul", ("You don't have any %s"):format(item.name), 2, "Warning")
                    return
                end

                local res = WuKong:ExecuteAction(("/食物系统/使用食物/使用%s?购买"):format(item.id))
                if res and not res.HasError then
                    if infiniteFoodActive and item.props then
                        pcall(function()
                            local PropertyTribe = require(rs.Packages.PropertyTribe)
                            local itemTribe = PropertyTribe.new(item.props)
                            persistentFoodTribe = if persistentFoodTribe then persistentFoodTribe + itemTribe else itemTribe
                            activeFoodIds[item.id] = true
                            local PTTM = require(rs.Packages.PropertyTribeTreeManager)
                            local uTree = PTTM.GetUserTree(player.UserId)
                            local bTree = PTTM.GetBattleUserTree(player.UserId)
                            if uTree and uTree.Foods then
                                uTree.Foods:SetDirty(true)
                                uTree:SetDirty(true)
                            end
                            if bTree then bTree:SetDirty(true) end
                        end)
                        Notify("Moro Soul", ("Ate %s! Buff is now INFINITE (Never Expires)."):format(item.name), 2, "Success")
                    else
                        Notify("Moro Soul", ("Ate %s! Buff active."):format(item.name), 2, "Success")
                    end
                else
                    Notify("Moro Soul", "Cannot eat now (Full or error)", 2, "Warning")
                end
            end)
        end
    })

    FoodCraftSec:AddToggle({
        Name = "Infinite Food Buff (Never Expires)",
        Default = false,
        Callback = function(state)
            applyInfiniteFoodState(state)
            if state then
                if not foodCharConn then
                    foodCharConn = player.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if infiniteFoodActive then applyInfiniteFoodState(true) end
                    end)
                end
                Notify("Moro Soul", "Infinite Food Buffs Active (Never Expires)!", 3, "Success")
            else
                if foodCharConn then
                    foodCharConn:Disconnect()
                    foodCharConn = nil
                end
                Notify("Moro Soul", "Infinite Food Buffs Disabled", 2, "Info")
            end
        end
    })

    FoodCraftSec:AddButton({
        Name = "Apply Top Food Buffs (Permanent)",
        Primary = true,
        Callback = function()
            applyTopFoodBuffsPermanent()
            Notify("Moro Soul", "Top Combat Buffs Applied Permanently (+50% Dmg, Crit, Dbl, Spd)!", 3, "Success")
        end
    })

    FoodCraftSec:AddToggle({
        Name = "Auto-Eat Best Combat Foods",
        Default = false,
        Callback = function(state)
            autoEatBestFoods = state
            if state then
                Notify("Moro Soul", "Auto-Eat Top Combat Foods Active", 2, "Success")
            end
        end
    })

    table.insert(cleanupHandlers, function()
        foodLoopActive = false
        if infiniteFoodActive then
            applyInfiniteFoodState(false)
        end
        if foodCharConn then
            pcall(function() foodCharConn:Disconnect() end)
            foodCharConn = nil
        end
    end)

    -- Auto-eat loop for top 3 foods: 食物22 (Tuna), 食物20 (Koi), 食物15 (Tilapia)
    task.spawn(function()
        local bestFoods = { "食物22", "食物20", "食物15" }
        while task.wait(3) do
            if autoEatBestFoods and WuKong then
                for _, fId in ipairs(bestFoods) do
                    local isAct = false
                    pcall(function()
                        isAct = WuKong:ExecuteQuery(("/食物系统/食物背包/%s?查询激活状态"):format(fId))
                    end)
                    if not isAct then
                        local cnt = 0
                        pcall(function()
                            cnt = WuKong:ExecuteQuery(("/食物系统/食物背包/%s?获取元素数量"):format(fId)) or 0
                        end)
                        if cnt > 0 then
                            pcall(function()
                                WuKong:ExecuteAction(("/食物系统/使用食物/使用%s?购买"):format(fId))
                            end)
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
    end)
    end



    -- =====================================================================
    --                            UPGRADE TAB
    -- =====================================================================
    do
    _G.BuyCrystalsAmount = 10
    _G.UseCrystalsAmount = 10
    _G.SelectedCrystalTier = "经验水晶3"
    _G.SelectedHeroPath = heroData["Iguro Obanai"] or "伊黑小芭内"

    local crystalTiers = {
        ["Tier 1 - Small (10k Souls)"] = "经验水晶1",
        ["Tier 2 - Medium (100k Souls)"] = "经验水晶2",
        ["Tier 3 - Large (10M Souls)"] = "经验水晶3"
    }

    -- === WUKONG TALENTS & ATTRIBUTES SUBSYSTEM ===
    local WuKong = nil
    pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end)

    local WuKongHelper = nil
    pcall(function() WuKongHelper = require(rs:WaitForChild("WuKong"):WaitForChild("WuKongHelper")) end)

    local RerollM = nil
    pcall(function() RerollM = require(rs:WaitForChild("UI"):WaitForChild("Role"):WaitForChild("Model"):WaitForChild("Reroll")) end)

    local TalentConfig = nil
    pcall(function() TalentConfig = require(rs:WaitForChild("Configs"):WaitForChild("TalentConfig")) end)

    local heroTalentsMap = {}
    if TalentConfig then
        for _, entry in pairs(TalentConfig) do
            if type(entry) == "table" and entry.Role and entry.Talent then
                local roleId = entry.Role.RoleId
                local tList = {}
                for _, t in ipairs(entry.Talent) do
                    table.insert(tList, {
                        id = t.TalentId,
                        name = t.TalentName or t.TalentId,
                        desc = t.Description or ""
                    })
                end
                heroTalentsMap[roleId] = tList
            end
        end
    end

    local function GetTalentsForHero(roleInternalName)
        if heroTalentsMap[roleInternalName] and #heroTalentsMap[roleInternalName] > 0 then
            return heroTalentsMap[roleInternalName]
        end
        return {
            { id = roleInternalName .. "_1", name = "Talent 1" },
            { id = roleInternalName .. "_2", name = "Talent 2" },
            { id = roleInternalName .. "_3", name = "Talent 3" },
            { id = roleInternalName .. "_4", name = "Talent 4" }
        }
    end

    local attrOptions = {
        "Critical Damage",
        "Critical Chance",
        "Attack",
        "Attack Speed",
        "Boss Damage Boost",
        "Double Attack",
        "Triple Attack",
        "Normal Attack Damage",
        "Skill1 Damage",
        "Skill2 Damage",
        "Skill3 Damage",
        "Shield Damage",
        "Move Speed",
        "Energy Addition",
        "[Leader] Critical Damage",
        "[Leader] Critical Chance",
        "[Leader] Attack",
        "[Leader] Attack Speed",
        "[Leader] Boss Damage Boost",
        "[Leader] Double Attack",
        "[Leader] Triple Attack",
        "[Leader] Normal Attack Damage",
        "[Leader] Skill1 Damage",
        "[Leader] Skill2 Damage",
        "[Leader] Skill3 Damage",
        "[Leader] Shield Damage",
        "[Leader] Move Speed",
        "[Leader] Energy Addition"
    }

    local attrNameToId = {
        ["Critical Chance"] = 1,
        ["Critical Damage"] = 2,
        ["Attack"] = 3,
        ["Attack Speed"] = 4,
        ["Energy Addition"] = 5,
        ["Move Speed"] = 6,
        ["Normal Attack Damage"] = 7,
        ["Skill1 Damage"] = 8,
        ["Skill2 Damage"] = 9,
        ["Skill3 Damage"] = 10,
        ["Double Attack"] = 11,
        ["Triple Attack"] = 12,
        ["Shield Damage"] = 13,
        ["Boss Damage Boost"] = 14,
        ["[Leader] Critical Chance"] = 15,
        ["[Leader] Critical Damage"] = 16,
        ["[Leader] Attack"] = 17,
        ["[Leader] Attack Speed"] = 18,
        ["[Leader] Energy Addition"] = 19,
        ["[Leader] Move Speed"] = 20,
        ["[Leader] Normal Attack Damage"] = 21,
        ["[Leader] Skill1 Damage"] = 22,
        ["[Leader] Skill2 Damage"] = 23,
        ["[Leader] Skill3 Damage"] = 24,
        ["[Leader] Double Attack"] = 25,
        ["[Leader] Triple Attack"] = 26,
        ["[Leader] Shield Damage"] = 27,
        ["[Leader] Boss Damage Boost"] = 28
    }

    local attrIdToName = {}
    for name, id in pairs(attrNameToId) do
        attrIdToName[id] = name
    end

    local rankMinLevel = {
        ["S (81-100)"] = 81,
        ["A+ (61-100)"] = 61,
        ["B+ (41-100)"] = 41,
        ["C+ (21-100)"] = 21,
        ["Any (1-100)"] = 1
    }

    local function GetRankFromLevel(lvl)
        lvl = tonumber(lvl) or 0
        if lvl > 80 then return "S"
        elseif lvl > 60 then return "A"
        elseif lvl > 40 then return "B"
        elseif lvl > 20 then return "C"
        else return "D" end
    end

    -- Hook GetTalentSlotsCount for 3 slots bypass
    local originalGetSlotsCount = nil
    local function ApplySlotCountBypass(enable)
        pcall(function()
            if not RerollM then return end
            local mt = getmetatable(RerollM)
            local ups = debug.getupvalues(mt.__index)
            local classTable = ups and ups[1]
            if not classTable then return end
            if enable then
                if not originalGetSlotsCount then
                    originalGetSlotsCount = classTable.GetTalentSlotsCount
                end
                classTable.GetTalentSlotsCount = function(a1, a2, a3)
                    return 3
                end
            else
                if originalGetSlotsCount then
                    classTable.GetTalentSlotsCount = originalGetSlotsCount
                end
            end
        end)
    end
    ApplySlotCountBypass(true)

    local initialHeroName = "Iguro Obanai"
    if not heroData[initialHeroName] then
        for _, n in ipairs(heroNames) do
            if n:find("Iguro") or n:find("Obanai") then
                initialHeroName = n
                break
            end
        end
        if not heroData[initialHeroName] and heroNames[1] then
            initialHeroName = heroNames[1]
        end
    end
    local initialHeroPath = heroData[initialHeroName] or "伊黑小芭内"
    local initialTalents = GetTalentsForHero(initialHeroPath)
    local initialTalent = initialTalents[1] or { id = initialHeroPath .. "_1", name = "Talent 1" }

    _G.RerollHeroName = initialHeroName
    _G.RerollHeroPath = initialHeroPath
    _G.RerollTalentId = initialTalent.id
    _G.RerollTalentName = initialTalent.name
    _G.TargetBonusStats = {
        ["Shield Damage"] = true,
        ["Skill3 Damage"] = true,
        ["Critical Chance"] = true
    }
    _G.TargetBonusStat = "Shield Damage"
    _G.TargetMinRank = "S (81-100)"
    _G.AutoLockMatching = true
    _G.AutoRerollActive = false
    _G.RerollDelay = 0.25

    _G.InjectSlot1Stat = "Shield Damage"
    _G.InjectSlot1Level = 100
    _G.InjectSlot2Stat = "Skill3 Damage"
    _G.InjectSlot2Level = 100
    _G.InjectSlot3Stat = "Critical Chance"
    _G.InjectSlot3Level = 100
    _G.BypassSlotUnlock = true

    local rerollTalentDrop = nil
    local injectTalentDrop = nil
    local rerollHeroDrop = nil
    local injectHeroDrop = nil
    local injectTargetLabel = nil

    local function GetTalentDisplayList(roleInternal)
        local tList = GetTalentsForHero(roleInternal)
        local displayList = {}
        for _, t in ipairs(tList) do
            table.insert(displayList, t.name)
        end
        return displayList, tList
    end

    local isSyncingHero = false
    local function SyncHeroSelection(heroName, sourceSec)
        if isSyncingHero then return end
        isSyncingHero = true

        _G.RerollHeroName = heroName
        _G.RerollHeroPath = heroData[heroName] or heroName
        local newNames, newTalents = GetTalentDisplayList(_G.RerollHeroPath)
        if newTalents[1] then
            _G.RerollTalentId = newTalents[1].id
            _G.RerollTalentName = newTalents[1].name
        end

        if sourceSec ~= "reroll" and rerollHeroDrop and rerollHeroDrop.Set then
            if rerollHeroDrop.Get and rerollHeroDrop.Get() ~= heroName then
                pcall(function() rerollHeroDrop.Set(heroName, true) end)
            end
        end
        if sourceSec ~= "inject" and injectHeroDrop and injectHeroDrop.Set then
            if injectHeroDrop.Get and injectHeroDrop.Get() ~= heroName then
                pcall(function() injectHeroDrop.Set(heroName, true) end)
            end
        end

        if rerollTalentDrop and rerollTalentDrop.Refresh then
            pcall(function() rerollTalentDrop.Refresh(newNames, true) end)
        end
        if injectTalentDrop and injectTalentDrop.Refresh then
            pcall(function() injectTalentDrop.Refresh(newNames, true) end)
        end
        if injectTargetLabel and injectTargetLabel.Set then
            pcall(function() injectTargetLabel.Set("Target: " .. _G.RerollHeroName .. " -> " .. tostring(_G.RerollTalentName)) end)
        end

        isSyncingHero = false
    end

    local isSyncingTalent = false
    local function SyncTalentSelection(talentName, sourceSec)
        if isSyncingTalent then return end
        isSyncingTalent = true

        local _, talents = GetTalentDisplayList(_G.RerollHeroPath)
        for _, t in ipairs(talents) do
            if t.name == talentName then
                _G.RerollTalentId = t.id
                _G.RerollTalentName = t.name
                break
            end
        end

        if sourceSec ~= "reroll" and rerollTalentDrop and rerollTalentDrop.Set then
            if rerollTalentDrop.Get and rerollTalentDrop.Get() ~= talentName then
                pcall(function() rerollTalentDrop.Set(talentName, true) end)
            end
        end
        if sourceSec ~= "inject" and injectTalentDrop and injectTalentDrop.Set then
            if injectTalentDrop.Get and injectTalentDrop.Get() ~= talentName then
                pcall(function() injectTalentDrop.Set(talentName, true) end)
            end
        end
        if injectTargetLabel and injectTargetLabel.Set then
            pcall(function() injectTargetLabel.Set("Target: " .. _G.RerollHeroName .. " -> " .. tostring(_G.RerollTalentName)) end)
        end

        isSyncingTalent = false
    end

    -- =====================================================================
    --                           COLUMN LEFT
    -- =====================================================================
    UpgradeTab:Column("left")

    local CrystalSec = wrapSection(UpgradeTab:CreateSection({ Name = "Experience Crystals", Collapsible = true }))

    CrystalSec:AddDropdown({
        Name = "Crystal Tier",
        Options = {"Tier 1 - Small (10k Souls)", "Tier 2 - Medium (100k Souls)", "Tier 3 - Large (10M Souls)"},
        Default = "Tier 3 - Large (10M Souls)",
        Callback = function(val)
            _G.SelectedCrystalTier = crystalTiers[val] or "经验水晶3"
            Notify("Moro Soul", "Selected: " .. tostring(val), 2, "Info")
        end
    })

    CrystalSec:AddTextbox({
        Name = "Buy Amount",
        Default = "10",
        Placeholder = "10",
        Numeric = true,
        Callback = function(val)
            local num = tonumber(val)
            if num and num > 0 then _G.BuyCrystalsAmount = num end
        end
    })

    CrystalSec:AddButton({
        Name = "Buy Crystals (One-Time)",
        Primary = false,
        Callback = function()
            local tier = _G.SelectedCrystalTier or "经验水晶3"
            if EventBus and EventBus.FireServer then
                EventBus.FireServer("购买经验水晶", tier, _G.BuyCrystalsAmount)
            else
                local args = {"购买经验水晶", tier, _G.BuyCrystalsAmount}
                pcall(function()
                    rs.Packages.EventBus.EventProvider.default_RemoteEvent:FireServer(unpack(args))
                end)
            end
            Notify("Moro Soul", "Bought " .. _G.BuyCrystalsAmount .. " crystals", 2, "Success")
        end
    })

    CrystalSec:AddToggle({
        Name = "Auto Buy Crystals",
        Default = false,
        Callback = function(state)
            _G.AutoBuyCrystals = state
            if state then
                task.spawn(function()
                    while _G.AutoBuyCrystals do
                        local tier = _G.SelectedCrystalTier or "经验水晶3"
                        if EventBus and EventBus.FireServer then
                            EventBus.FireServer("购买经验水晶", tier, _G.BuyCrystalsAmount)
                        else
                            local args = {"购买经验水晶", tier, _G.BuyCrystalsAmount}
                            pcall(function()
                                rs.Packages.EventBus.EventProvider.default_RemoteEvent:FireServer(unpack(args))
                            end)
                        end
                        task.wait(0.5)
                    end
                end)
            end
        end
    })

    -- TALENT AUTO-REROLL SECTION
    local TalentRerollSec = wrapSection(UpgradeTab:CreateSection({ Name = "Talent Auto-Reroll", Collapsible = true }))

    local initialDisplayList = GetTalentDisplayList(_G.RerollHeroPath)

    rerollHeroDrop = TalentRerollSec:AddDropdown({
        Name = "Select Character",
        Options = heroNames,
        Default = _G.RerollHeroName,
        Callback = function(val)
            if val == _G.RerollHeroName and rerollHeroDrop and rerollHeroDrop.Get and rerollHeroDrop.Get() == val then return end
            SyncHeroSelection(val, "reroll")
            Notify("Moro Soul", "Selected Character: " .. tostring(val), 2, "Info")
        end
    })

    rerollTalentDrop = TalentRerollSec:AddDropdown({
        Name = "Select Talent",
        Options = initialDisplayList,
        Default = initialDisplayList[1] or "Talent 1",
        Callback = function(val)
            if val == _G.RerollTalentName and rerollTalentDrop and rerollTalentDrop.Get and rerollTalentDrop.Get() == val then return end
            SyncTalentSelection(val, "reroll")
            Notify("Moro Soul", "Selected Talent: " .. tostring(val), 2, "Info")
        end
    })

    TalentRerollSec:AddMultiDropdown({
        Name = "Target Bonus Stats",
        Options = {
            "Skill3 Damage",
            "Shield Damage",
            "Critical Damage",
            "Critical Chance",
            "Attack",
            "Attack Speed",
            "Boss Damage Boost",
            "Double Attack",
            "Triple Attack",
            "Normal Attack Damage",
            "Skill1 Damage",
            "Skill2 Damage",
            "Move Speed",
            "Energy Addition",
            "Any Stat (Rank Only)",
            "[Leader] Critical Damage",
            "[Leader] Critical Chance",
            "[Leader] Attack",
            "[Leader] Attack Speed",
            "[Leader] Boss Damage Boost",
            "[Leader] Double Attack",
            "[Leader] Triple Attack",
            "[Leader] Normal Attack Damage",
            "[Leader] Skill1 Damage",
            "[Leader] Skill2 Damage",
            "[Leader] Skill3 Damage",
            "[Leader] Shield Damage",
            "[Leader] Move Speed",
            "[Leader] Energy Addition"
        },
        Default = {"Skill3 Damage", "Shield Damage"},
        Callback = function(orderList, changedOpt, isSelected)
            local newSet = {}
            for _, stat in ipairs(orderList) do
                newSet[stat] = true
            end
            _G.TargetBonusStats = newSet
            _G.TargetBonusStat = orderList[1] or nil
            Notify("Moro Soul", "Target Stats: " .. (#orderList > 0 and table.concat(orderList, ", ") or "None"), 2, "Info")
        end
    })

    TalentRerollSec:AddDropdown({
        Name = "Target Min Rank",
        Options = {"S (81-100)", "A+ (61-100)", "B+ (41-100)", "C+ (21-100)", "Any (1-100)"},
        Default = "S (81-100)",
        Callback = function(val)
            _G.TargetMinRank = val
            Notify("Moro Soul", "Min Rank: " .. tostring(val), 2, "Info")
        end
    })

    TalentRerollSec:AddToggle({
        Name = "Auto-Lock Matched Slots",
        Default = true,
        Callback = function(state)
            _G.AutoLockMatching = state
        end
    })

    TalentRerollSec:AddSlider({
        Name = "Reroll Delay (Sec)",
        Min = 0.1,
        Max = 1.0,
        Default = 0.25,
        Decimals = 2,
        Callback = function(val)
            _G.RerollDelay = val
        end
    })

    local autoRerollToggleRef = nil
    local function DoesSlotMatch(attrData, targetStats, minLevel)
        if not attrData or not attrData.Id or not attrData.Level then
            return false
        end
        if attrData.Level < minLevel then
            return false
        end
        if type(targetStats) == "string" then
            if targetStats == "Any Stat (Rank Only)" then
                return true
            end
            local targetId = attrNameToId[targetStats]
            return targetId and attrData.Id == targetId
        end
        if type(targetStats) == "table" then
            if targetStats["Any Stat (Rank Only)"] then
                return true
            end
            for statName, isSelected in pairs(targetStats) do
                if isSelected and attrNameToId[statName] and attrData.Id == attrNameToId[statName] then
                    return true
                end
            end
        end
        return false
    end

    local function ExecuteRerollStep(heroPath, talentId)
        local totalSlots = 3
        if RerollM and RerollM.GetTalentSlotsCount then
            totalSlots = RerollM:GetTalentSlotsCount(heroPath, talentId)
        end
        if totalSlots <= 0 then totalSlots = 3 end

        local currentAttrs = {}
        if RerollM and RerollM.GetTalentAttr then
            currentAttrs = RerollM:GetTalentAttr(heroPath, talentId) or {}
        end

        local minReqLevel = rankMinLevel[_G.TargetMinRank] or 81
        local lockedSlots = {}
        local matchedCount = 0

        local hasTarget = false
        if type(_G.TargetBonusStats) == "table" then
            for _, v in pairs(_G.TargetBonusStats) do
                if v then hasTarget = true break end
            end
        elseif type(_G.TargetBonusStats) == "string" and _G.TargetBonusStats ~= "" then
            hasTarget = true
        end

        if not hasTarget then
            return false, "No target stats selected!", lockedSlots
        end

        for i = 1, totalSlots do
            local slotKey = "Attr" .. i
            local slotData = currentAttrs[slotKey]
            if slotData and slotData.Id and slotData.Level then
                if DoesSlotMatch(slotData, _G.TargetBonusStats, minReqLevel) then
                    matchedCount = matchedCount + 1
                    if _G.AutoLockMatching then
                        table.insert(lockedSlots, slotKey)
                    end
                end
            end
        end

        if matchedCount >= totalSlots then
            return true, "Target bonuses achieved on all slots!", lockedSlots
        end

        if RerollM and RerollM.CanReroll then
            local can = RerollM:CanReroll(heroPath, talentId, lockedSlots)
            if not can then
                return false, "Not enough talent resources to reroll!", lockedSlots
            end
        end

        local ok = pcall(function()
            if RerollM and RerollM.Rerollattribute then
                RerollM:Rerollattribute(heroPath, talentId, lockedSlots)
            else
                local args = {
                    "/天赋系统/副词条随机/副词条随机商人?购买",
                    ("/天赋系统/天赋持有者/%s/%s"):format(heroPath, talentId),
                    "__null__",
                    (#lockedSlots > 0) and lockedSlots or "__null__"
                }
                rs.WuKong.RemoteActionFunction:InvokeServer(unpack(args))
            end
        end)

        return nil, ok and "Rerolled successfully" or "Error during reroll", lockedSlots
    end

    autoRerollToggleRef = TalentRerollSec:AddToggle({
        Name = "Auto Reroll (Server-Legit)",
        Default = false,
        Callback = function(state)
            _G.AutoRerollActive = state
            if state then
                task.spawn(function()
                    Notify("Moro Soul", "Auto Reroll Started for " .. tostring(_G.RerollHeroName), 2, "Info")
                    while _G.AutoRerollActive do
                        local heroPath = _G.RerollHeroPath or "左近次"
                        local talentId = _G.RerollTalentId or "左近次_1"
                        local isDone, msg, locked = ExecuteRerollStep(heroPath, talentId)
                        if isDone == true then
                            _G.AutoRerollActive = false
                            if autoRerollToggleRef and autoRerollToggleRef.Set then
                                autoRerollToggleRef.Set(false)
                            end
                            Notify("Moro Soul", msg, 4, "Success")
                            break
                        elseif isDone == false then
                            _G.AutoRerollActive = false
                            if autoRerollToggleRef and autoRerollToggleRef.Set then
                                autoRerollToggleRef.Set(false)
                            end
                            Notify("Moro Soul", msg, 4, "Warning")
                            break
                        end
                        task.wait(_G.RerollDelay or 0.25)
                    end
                end)
            end
        end
    })

    TalentRerollSec:AddButton({
        Name = "Reroll Once",
        Primary = false,
        Callback = function()
            local heroPath = _G.RerollHeroPath or "左近次"
            local talentId = _G.RerollTalentId or "左近次_1"
            local isDone, msg = ExecuteRerollStep(heroPath, talentId)
            Notify("Moro Soul", msg or "Rerolled once", 2, isDone and "Success" or "Info")
        end
    })

    -- =====================================================================
    --                           COLUMN RIGHT
    -- =====================================================================
    UpgradeTab:Column("right")

    local HeroSec = wrapSection(UpgradeTab:CreateSection({ Name = "Hero Upgrade", Collapsible = true }))

    HeroSec:AddDropdown({
        Name = "Select Character",
        Options = heroNames,
        Default = heroNames[1] or "Iguro Obanai",
        Callback = function(val)
            _G.SelectedHeroPath = heroData[val]
            Notify("Moro Soul", "Selected Hero: " .. tostring(val), 2, "Info")
        end
    })

    HeroSec:AddTextbox({
        Name = "Upgrade Amount",
        Default = "10",
        Placeholder = "10",
        Numeric = true,
        Callback = function(val)
            local num = tonumber(val)
            if num and num > 0 then _G.UseCrystalsAmount = num end
        end
    })

    HeroSec:AddButton({
        Name = "Upgrade Hero (One-Time)",
        Primary = true,
        Callback = function()
            local tier = _G.SelectedCrystalTier or "经验水晶3"
            local heroPath = _G.SelectedHeroPath or "伊黑小芭内"
            local args = {
                "/卡牌系统/卡牌升级/增加经验?多次购买",
                _G.UseCrystalsAmount,
                "/卡牌系统/卡牌背包/" .. heroPath,
                "/道具/" .. tier
            }
            pcall(function()
                rs.WuKong.RemoteActionFunction:InvokeServer(unpack(args))
            end)
            Notify("Moro Soul", "Hero upgrade executed", 2, "Success")
        end
    })

    HeroSec:AddToggle({
        Name = "Auto Upgrade Hero",
        Default = false,
        Callback = function(state)
            _G.AutoUpgradeHero = state
            if state then
                task.spawn(function()
                    while _G.AutoUpgradeHero do
                        local tier = _G.SelectedCrystalTier or "经验水晶3"
                        local heroPath = _G.SelectedHeroPath or "伊黑小芭内"
                        local args = {
                            "/卡牌系统/卡牌升级/增加经验?多次购买",
                            _G.UseCrystalsAmount,
                            "/卡牌系统/卡牌背包/" .. heroPath,
                            "/道具/" .. tier
                        }
                        pcall(function()
                            rs.WuKong.RemoteActionFunction:InvokeServer(unpack(args))
                        end)
                        task.wait(0.8)
                    end
                end)
            end
        end
    })

    -- TALENT BONUS EDITOR & INJECTION SECTION ("Запись бонусов в игру")
    local TalentInjectSec = wrapSection(UpgradeTab:CreateSection({ Name = "Talent Bonus Injection", Collapsible = true }))

    injectHeroDrop = TalentInjectSec:AddDropdown({
        Name = "Select Character",
        Options = heroNames,
        Default = _G.RerollHeroName,
        Callback = function(val)
            if val == _G.RerollHeroName and injectHeroDrop and injectHeroDrop.Get and injectHeroDrop.Get() == val then return end
            SyncHeroSelection(val, "inject")
            Notify("Moro Soul", "Selected Character: " .. tostring(val), 2, "Info")
        end
    })

    injectTalentDrop = TalentInjectSec:AddDropdown({
        Name = "Select Talent",
        Options = initialDisplayList,
        Default = initialDisplayList[1] or "Talent 1",
        Callback = function(val)
            if val == _G.RerollTalentName and injectTalentDrop and injectTalentDrop.Get and injectTalentDrop.Get() == val then return end
            SyncTalentSelection(val, "inject")
            Notify("Moro Soul", "Selected Talent: " .. tostring(val), 2, "Info")
        end
    })

    injectTargetLabel = TalentInjectSec:AddLabel("Target: " .. _G.RerollHeroName .. " -> " .. tostring(_G.RerollTalentName))

    TalentInjectSec:AddDropdown({
        Name = "Slot 1 Bonus",
        Options = attrOptions,
        Default = "Shield Damage",
        Callback = function(val)
            _G.InjectSlot1Stat = val
        end
    })

    TalentInjectSec:AddSlider({
        Name = "Slot 1 Level (S = 81-100)",
        Min = 1,
        Max = 100,
        Default = 100,
        Callback = function(val)
            _G.InjectSlot1Level = math.floor(val)
        end
    })

    TalentInjectSec:AddDropdown({
        Name = "Slot 2 Bonus",
        Options = attrOptions,
        Default = "Skill3 Damage",
        Callback = function(val)
            _G.InjectSlot2Stat = val
        end
    })

    TalentInjectSec:AddSlider({
        Name = "Slot 2 Level (S = 81-100)",
        Min = 1,
        Max = 100,
        Default = 100,
        Callback = function(val)
            _G.InjectSlot2Level = math.floor(val)
        end
    })

    TalentInjectSec:AddDropdown({
        Name = "Slot 3 Bonus",
        Options = attrOptions,
        Default = "Critical Chance",
        Callback = function(val)
            _G.InjectSlot3Stat = val
        end
    })

    TalentInjectSec:AddSlider({
        Name = "Slot 3 Level (S = 81-100)",
        Min = 1,
        Max = 100,
        Default = 100,
        Callback = function(val)
            _G.InjectSlot3Level = math.floor(val)
        end
    })

    TalentInjectSec:AddToggle({
        Name = "Unlock All 3 Slots (Client Bypass)",
        Default = true,
        Callback = function(state)
            _G.BypassSlotUnlock = state
            ApplySlotCountBypass(state)
            Notify("Moro Soul", "3 Slots Bypass: " .. (state and "Enabled" or "Disabled"), 2, "Info")
        end
    })

    local realTalentBuffsActive = false
    local devCheatActive = false
    local talentStatMultiplier = 1
    local origGetPlayerTalentAttributes = nil
    local origClassGetTalentAttr = nil
    local realBuffToggleRef = nil
    local talentLoopActive = false
    local talentCharConn = nil

    local function applyRealTalentBuffsState(enable)
        realTalentBuffsActive = enable
        pcall(function()
            local PTTM = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribeTreeManager"))
            local PropertyTribe = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribe"))
            local MathManager = require(rs:WaitForChild("Packages"):WaitForChild("MathManager"))
            local TalentHooks = nil
            local battle_attrconfig = nil
            local WuKongHelper = nil
            pcall(function()
                TalentHooks = require(rs:WaitForChild("VendorHooks"):WaitForChild("TalentAtrributeRerollHooks"))
                battle_attrconfig = require(rs:WaitForChild("_genConfigs"):WaitForChild("battle_attrconfig"))
                WuKongHelper = require(rs:WaitForChild("WuKong"):WaitForChild("WuKongHelper"))
            end)

            local userTree = PTTM.GetUserTree(player.UserId)
            local battleTree = PTTM.GetBattleUserTree(player.UserId)
            local tl = battleTree and battleTree.TeamLeader

            local s1Id = attrNameToId[_G.InjectSlot1Stat] or 2
            local s1Lv = _G.InjectSlot1Level or 100
            local s2Id = attrNameToId[_G.InjectSlot2Stat] or 3
            local s2Lv = _G.InjectSlot2Level or 100
            local s3Id = attrNameToId[_G.InjectSlot3Stat] or 14
            local s3Lv = _G.InjectSlot3Level or 100

            if enable then
                -- 1. Hook TalentHooks.GetPlayerTalentAttributes
                if TalentHooks and battle_attrconfig then
                    if not origGetPlayerTalentAttributes then
                        origGetPlayerTalentAttributes = TalentHooks.GetPlayerTalentAttributes
                    end
                    TalentHooks.GetPlayerTalentAttributes = function(userId, roleIndex, talentId)
                        local res = origGetPlayerTalentAttributes(userId, roleIndex, talentId) or {}
                        if realTalentBuffsActive and (userId == player.UserId or not userId) then
                            res[s1Id] = { Level = s1Lv, Config = battle_attrconfig[s1Id] }
                            res[s2Id] = { Level = s2Lv, Config = battle_attrconfig[s2Id] }
                            res[s3Id] = { Level = s3Lv, Config = battle_attrconfig[s3Id] }
                        end
                        return res
                    end
                end

                -- 2. Compute combined PropertyTribe for all 3 injected slots
                local bonusTribe = nil
                local function addAttr(attrId, lvl)
                    if battle_attrconfig and battle_attrconfig[attrId] then
                        local cfg = battle_attrconfig[attrId]
                        if cfg and cfg.Region and cfg.Key then
                            local t = MathManager.GetConfigPropertyTribe(cfg.Region, cfg.Key, nil, nil, nil, {Level = lvl})
                            if t then
                                bonusTribe = if bonusTribe then bonusTribe + t else t:Clone()
                            end
                        end
                    end
                end
                addAttr(s1Id, s1Lv)
                addAttr(s2Id, s2Lv)
                addAttr(s3Id, s3Lv)

                if (talentStatMultiplier or 1) > 1 and bonusTribe then
                    local multiplied = {}
                    for k, v in pairs(bonusTribe:GetAllProperties()) do
                        multiplied[k] = v * (talentStatMultiplier or 1)
                    end
                    bonusTribe = PropertyTribe.new(multiplied)
                end

                -- 3. Connect into TeamLeader.__refCheat & TeamLeader.__refTeamLeaderTalent
                local PropertyTribeTree = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribeTree"))
                if tl then
                    -- 3a. Direct injection into TeamLeader.__refCheat
                    if tl.__refCheat then
                        tl.__refCheat:ResetHandler(function()
                            local res = nil
                            if realTalentBuffsActive and bonusTribe then
                                res = bonusTribe:Clone()
                            end
                            if devCheatActive then
                                local devTribe = MathManager.GetConfigPropertyTribe("Cheat", 1)
                                res = if res then res + devTribe else devTribe:Clone()
                            end
                            return res
                        end)
                        tl.__refCheat:SetDirty(true)
                    end

                    -- 3b. Direct injection into TeamLeader.__refTeamLeaderTalent
                    local injectedTalentTree = PropertyTribeTree.new(function()
                        if realTalentBuffsActive and bonusTribe then
                            return bonusTribe:Clone()
                        end
                        return nil
                    end)
                    tl:SetValue("__refTeamLeaderTalent1", injectedTalentTree)
                    tl:SetValue("__refTeamLeaderTalent2", injectedTalentTree)
                    tl:SetValue("__injectedTalentPT", injectedTalentTree)

                    tl:SetDirty(true)
                end

                if userTree then userTree:SetDirty(true) end
                if battleTree then battleTree:SetDirty(true) end

                -- Apply WalkSpeed from FinalMoveSpeed immediately
                pcall(function()
                    local BIP = require(rs:WaitForChild("Packages"):WaitForChild("BattleInformationProxy"))
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local finalSpd = BIP.GetFinalMoveSpeed(player.UserId)
                        if finalSpd and finalSpd > 0 then
                            hum.WalkSpeed = finalSpd
                        end
                    end
                end)

                -- 4. Hook RerollM.GetTalentAttr via internal classTable so UI and readers see injected bonuses
                if RerollM then
                    pcall(function()
                        local mt = getmetatable(RerollM)
                        local ups = debug.getupvalues(mt.__index)
                        local classTable = ups and ups[1]
                        if classTable then
                            if not origClassGetTalentAttr then
                                origClassGetTalentAttr = classTable.GetTalentAttr
                            end
                            classTable.GetTalentAttr = function(self, role, talent)
                                if realTalentBuffsActive then
                                    local curS1Id = attrNameToId[_G.InjectSlot1Stat] or 2
                                    local curS1Lv = _G.InjectSlot1Level or 100
                                    local curS2Id = attrNameToId[_G.InjectSlot2Stat] or 3
                                    local curS2Lv = _G.InjectSlot2Level or 100
                                    local curS3Id = attrNameToId[_G.InjectSlot3Stat] or 14
                                    local curS3Lv = _G.InjectSlot3Level or 100
                                    return {
                                        Attr1 = { Id = curS1Id, Level = curS1Lv },
                                        Attr2 = { Id = curS2Id, Level = curS2Lv },
                                        Attr3 = { Id = curS3Id, Level = curS3Lv }
                                    }
                                end
                                if origClassGetTalentAttr then
                                    return origClassGetTalentAttr(self, role, talent)
                                end
                                return {}
                            end
                        end
                    end)
                end

                -- 5. Force update the active in-game GUI panel (AttrSlots)
                pcall(function()
                    local roleCtrl = require(rs:WaitForChild("UI"):WaitForChild("Role"))
                    if roleCtrl and roleCtrl.Panel then
                        local curS1Id = attrNameToId[_G.InjectSlot1Stat] or 13
                        local curS1Lv = _G.InjectSlot1Level or 100
                        local curS2Id = attrNameToId[_G.InjectSlot2Stat] or 10
                        local curS2Lv = _G.InjectSlot2Level or 100
                        local curS3Id = attrNameToId[_G.InjectSlot3Stat] or 1
                        local curS3Lv = _G.InjectSlot3Level or 100
                        roleCtrl.Panel.AttrSlots = {
                            Attr1 = { Id = curS1Id, Level = curS1Lv },
                            Attr2 = { Id = curS2Id, Level = curS2Lv },
                            Attr3 = { Id = curS3Id, Level = curS3Lv }
                        }
                    end
                end)

                -- 6. Inject into in-game UI facade and container
                pcall(function()
                    local heroPath = _G.RerollHeroPath or "伊黑小芭内"
                    local targetTalentId = _G.RerollTalentId or "伊黑小芭内_1"
                    local child = nil
                    if WuKongHelper and WuKongHelper.GetFacade then
                        local facade = WuKongHelper.GetFacade(player.UserId)
                        child = facade and facade:GetChild(("/天赋系统/天赋持有者/%s/%s"):format(heroPath, targetTalentId))
                    end
                    if not child and WuKong and WuKong.TryGetChild then
                        local _, c = WuKong:TryGetChild(("/天赋系统/天赋持有者/%s/%s"):format(heroPath, targetTalentId))
                        child = c
                    end
                    if child and WuKongHelper then
                        local curS1Id = attrNameToId[_G.InjectSlot1Stat] or 13
                        local curS1Lv = _G.InjectSlot1Level or 100
                        local curS2Id = attrNameToId[_G.InjectSlot2Stat] or 10
                        local curS2Lv = _G.InjectSlot2Level or 100
                        local curS3Id = attrNameToId[_G.InjectSlot3Stat] or 1
                        local curS3Lv = _G.InjectSlot3Level or 100
                        WuKongHelper.SetPluginValue(child, "Attr1Id", curS1Id)
                        WuKongHelper.SetPluginValue(child, "Attr1Level", curS1Lv)
                        WuKongHelper.SetPluginValue(child, "Attr2Id", curS2Id)
                        WuKongHelper.SetPluginValue(child, "Attr2Level", curS2Lv)
                        WuKongHelper.SetPluginValue(child, "Attr3Id", curS3Id)
                        WuKongHelper.SetPluginValue(child, "Attr3Level", curS3Lv)
                    end
                end)

                -- 7. Heartbeat loop to maintain active dirty state, speed, and UI slots
                if not talentLoopActive then
                    talentLoopActive = true
                    task.spawn(function()
                        while (realTalentBuffsActive or devCheatActive) and talentLoopActive and scriptActive do
                            pcall(function()
                                local bTree = PTTM.GetBattleUserTree(player.UserId)
                                local leader = bTree and bTree.TeamLeader
                                if leader then
                                    if leader.__refCheat then
                                        leader.__refCheat:SetDirty(true)
                                    end
                                    leader:SetDirty(true)
                                    bTree:SetDirty(true)
                                end
                                local BIP = require(rs:WaitForChild("Packages"):WaitForChild("BattleInformationProxy"))
                                local char = player.Character
                                local hum = char and char:FindFirstChildOfClass("Humanoid")
                                if hum and hum.Health > 0 then
                                    local finalSpd = BIP.GetFinalMoveSpeed(player.UserId)
                                    if finalSpd and finalSpd > 0 and math.abs(hum.WalkSpeed - finalSpd) > 1 then
                                        hum.WalkSpeed = finalSpd
                                    end
                                end
                                local roleCtrl = require(rs:WaitForChild("UI"):WaitForChild("Role"))
                                if roleCtrl and roleCtrl.Panel and realTalentBuffsActive then
                                    local curS1Id = attrNameToId[_G.InjectSlot1Stat] or 13
                                    local curS1Lv = _G.InjectSlot1Level or 100
                                    local curS2Id = attrNameToId[_G.InjectSlot2Stat] or 10
                                    local curS2Lv = _G.InjectSlot2Level or 100
                                    local curS3Id = attrNameToId[_G.InjectSlot3Stat] or 1
                                    local curS3Lv = _G.InjectSlot3Level or 100
                                    roleCtrl.Panel.AttrSlots = {
                                        Attr1 = { Id = curS1Id, Level = curS1Lv },
                                        Attr2 = { Id = curS2Id, Level = curS2Lv },
                                        Attr3 = { Id = curS3Id, Level = curS3Lv }
                                    }
                                end
                            end)
                            task.wait(0.5)
                        end
                    end)
                end
            else
                talentLoopActive = false
                if origGetPlayerTalentAttributes and TalentHooks then
                    TalentHooks.GetPlayerTalentAttributes = origGetPlayerTalentAttributes
                end

                if origClassGetTalentAttr and RerollM then
                    pcall(function()
                        local mt = getmetatable(RerollM)
                        local ups = debug.getupvalues(mt.__index)
                        local classTable = ups and ups[1]
                        if classTable and origClassGetTalentAttr then
                            classTable.GetTalentAttr = origClassGetTalentAttr
                        end
                    end)
                end

                pcall(function()
                    local roleCtrl = require(rs:WaitForChild("UI"):WaitForChild("Role"))
                    if roleCtrl and roleCtrl.Panel and RerollM then
                        roleCtrl.Panel.AttrSlots = RerollM:GetTalentAttr(roleCtrl.Panel.Selected, roleCtrl.Panel.SelectedTalent)
                    end
                end)

                if tl then
                    if tl.__refCheat then
                        tl.__refCheat:ResetHandler(function()
                            if devCheatActive then
                                return MathManager.GetConfigPropertyTribe("Cheat", 1)
                            end
                            return nil
                        end)
                        tl.__refCheat:SetDirty(true)
                    end
                    tl:SetValue("__refTeamLeaderTalent1", nil)
                    tl:SetValue("__refTeamLeaderTalent2", nil)
                    tl:SetValue("__injectedTalentPT", nil)
                    tl:SetDirty(true)
                end

                if userTree then userTree:SetDirty(true) end
                if battleTree then battleTree:SetDirty(true) end

                pcall(function()
                    local BIP = require(rs:WaitForChild("Packages"):WaitForChild("BattleInformationProxy"))
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local finalSpd = BIP.GetFinalMoveSpeed(player.UserId)
                        if finalSpd and finalSpd > 0 then
                            hum.WalkSpeed = finalSpd
                        else
                            hum.WalkSpeed = 16
                        end
                    end
                end)
            end
        end)
    end

    realBuffToggleRef = TalentInjectSec:AddToggle({
        Name = "Activate Real Combat Buffs",
        Default = true,
        Callback = function(state)
            applyRealTalentBuffsState(state)
            if state then
                if not talentCharConn then
                    talentCharConn = player.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if realTalentBuffsActive then
                            applyRealTalentBuffsState(true)
                        end
                    end)
                end
                Notify("Moro Soul", "Real Combat Talent Buffs Activated (TeamLeader + Tree)!", 3, "Success")
            else
                if talentCharConn then
                    talentCharConn:Disconnect()
                    talentCharConn = nil
                end
                Notify("Moro Soul", "Combat Talent Buffs Disabled", 2, "Info")
            end
        end
    })

    TalentInjectSec:AddToggle({
        Name = "Dev Battle Overdrive (+500% Spd, Double/Triple Atk)",
        Default = false,
        Callback = function(state)
            devCheatActive = state
            applyRealTalentBuffsState(realTalentBuffsActive or state)
            Notify("Moro Soul", "Dev Battle Overdrive: " .. (state and "ACTIVE" or "Disabled"), 2, state and "Success" or "Info")
        end
    })

    TalentInjectSec:AddSlider({
        Name = "Stat Multiplier",
        Min = 1,
        Max = 10,
        Default = 1,
        Suffix = "x",
        Decimals = 0,
        Callback = function(val)
            talentStatMultiplier = tonumber(val) or 1
            if realTalentBuffsActive then
                applyRealTalentBuffsState(true)
            end
        end
    })

    TalentInjectSec:AddButton({
        Name = "Write / Inject Bonuses to Game",
        Primary = true,
        Callback = function()
            pcall(function()
                local roleCtrl = require(rs:WaitForChild("UI"):WaitForChild("Role"))
                if roleCtrl and roleCtrl.Panel and roleCtrl.Panel.Selected then
                    _G.RerollHeroPath = roleCtrl.Panel.Selected
                    _G.RerollTalentId = roleCtrl.Panel.SelectedTalent or _G.RerollTalentId
                end
            end)

            if _G.BypassSlotUnlock then
                ApplySlotCountBypass(true)
            end

            applyRealTalentBuffsState(true)
            if realBuffToggleRef and realBuffToggleRef.Set then
                pcall(function() realBuffToggleRef.Set(true) end)
            end

            local s1 = _G.InjectSlot1Stat or "Shield Damage"
            local s2 = _G.InjectSlot2Stat or "Skill3 Damage"
            local s3 = _G.InjectSlot3Stat or "Critical Chance"
            local s1Lv = _G.InjectSlot1Level or 100
            Notify("Moro Soul", ("Injected: %s, %s, %s (Lv%d) into UI & Combat!"):format(s1, s2, s3, s1Lv), 4, "Success")
        end
    })

    TalentInjectSec:AddButton({
        Name = "Read Current Bonuses",
        Primary = false,
        Callback = function()
            local heroPath = _G.RerollHeroPath
            local talentId = _G.RerollTalentId
            pcall(function()
                local roleCtrl = require(rs:WaitForChild("UI"):WaitForChild("Role"))
                if roleCtrl and roleCtrl.Panel and roleCtrl.Panel.Selected then
                    heroPath = roleCtrl.Panel.Selected
                    talentId = roleCtrl.Panel.SelectedTalent or talentId
                end
            end)
            heroPath = heroPath or "伊黑小芭内"
            talentId = talentId or "伊黑小芭内_1"

            local currentAttrs = {}
            if RerollM and RerollM.GetTalentAttr then
                currentAttrs = RerollM:GetTalentAttr(heroPath, talentId) or {}
            end

            local lines = {}
            for i = 1, 3 do
                local slotKey = "Attr" .. i
                local d = currentAttrs[slotKey]
                if d and d.Id and d.Level then
                    local name = attrIdToName[d.Id] or ("ID " .. tostring(d.Id))
                    local rank = GetRankFromLevel(d.Level)
                    table.insert(lines, slotKey .. ": " .. name .. " Lv" .. d.Level .. " (" .. rank .. ")")
                else
                    table.insert(lines, slotKey .. ": [Empty]")
                end
            end

            local summary = table.concat(lines, " | ")
            local statusTag = realTalentBuffsActive and "[Injected Active] " or "[Server Live (Not Injected)] "
            Notify("Current Bonuses", statusTag .. summary, 6, realTalentBuffsActive and "Success" or "Info")
        end
    })

    -- Auto-activate on startup for Obanai with Shield Damage, Skill3, Crit Chance
    task.spawn(function()
        task.wait(0.5)
        pcall(function()
            applyRealTalentBuffsState(true)
        end)
    end)

    table.insert(cleanupHandlers, function()
        talentLoopActive = false
        if realTalentBuffsActive then
            applyRealTalentBuffsState(false)
        end
        if talentCharConn then
            pcall(function() talentCharConn:Disconnect() end)
            talentCharConn = nil
        end
    end)
    end

    -- =====================================================================
    --                           EXPLOITS TAB
    -- =====================================================================
    local Camera = workspace.CurrentCamera
    local isGhost = false
    local ghostConn = nil
    local fakeCamPart = nil
    local ghostPlatform = nil
    local ghostBall = nil

    ExploitsTab:Column("left")

    local GhostSec = wrapSection(ExploitsTab:CreateSection({ Name = "Ghost Mode", Collapsible = true }))

    GhostSec:AddToggle({
        Name = "Ghost",
        Default = false,
        Callback = function(state)
            isGhost = state
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            if isGhost and hrp then
                ghostPlatform = Instance.new("Part")
                ghostPlatform.Name = "GhostSafePlatform"
                ghostPlatform.Size = Vector3.new(10, 1, 10)
                ghostPlatform.Anchored = true
                ghostPlatform.CanCollide = true
                ghostPlatform.Transparency = 1 
                ghostPlatform.Parent = workspace

                fakeCamPart = Instance.new("Part")
                fakeCamPart.Name = "GhostCamAnchor"
                fakeCamPart.Transparency = 1
                fakeCamPart.CanCollide = false
                fakeCamPart.Anchored = true
                fakeCamPart.Parent = workspace
                
                Camera.CameraSubject = fakeCamPart

                ghostBall = Instance.new("Part")
                ghostBall.Name = "GhostVisualBall"
                ghostBall.Shape = Enum.PartType.Ball
                ghostBall.Size = Vector3.new(1.2, 1.2, 1.2)
                ghostBall.Color = Color3.fromRGB(0, 255, 255)
                ghostBall.Material = Enum.Material.Neon
                ghostBall.Transparency = 0.3
                ghostBall.CanCollide = false
                ghostBall.Anchored = true
                ghostBall.Parent = workspace

                local light = Instance.new("PointLight")
                light.Color = ghostBall.Color
                light.Range = 10
                light.Brightness = 2
                light.Parent = ghostBall
                
                ghostConn = runService.Heartbeat:Connect(function()
                    if not isGhost or not hrp.Parent then return end
                    
                    local realCF = hrp.CFrame
                    fakeCamPart.CFrame = realCF
                    if ghostBall then
                        ghostBall.CFrame = realCF * CFrame.new(0, 3.5, 0)
                    end

                    local followPos = realCF * CFrame.new(0, -10, 0)
                    hrp.CFrame = followPos
                    ghostPlatform.CFrame = followPos * CFrame.new(0, -3, 0)
                    
                    runService.RenderStepped:Wait()
                    hrp.CFrame = realCF
                end)
            else
                isGhost = false
                if ghostConn then ghostConn:Disconnect() end
                if hum then Camera.CameraSubject = hum end
                if fakeCamPart then fakeCamPart:Destroy() end
                if ghostBall then ghostBall:Destroy() ghostBall = nil end
                if ghostPlatform then ghostPlatform:Destroy() ghostPlatform = nil end
                if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
            end
        end
    })

    local autoCrowdTpConn = false
    local lastWaypoint = Vector3.new(438, 35, 1014)

    local function GetBestCrowdPos()
        local playersList = players:GetPlayers()
        local bestTargetPos = nil
        local maxNearby = -1
        local minDistanceToWaypoint = math.huge

        for _, p in ipairs(playersList) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local currentPos = p.Character.HumanoidRootPart.Position
                local nearbyCount = 0

                for _, otherP in ipairs(playersList) do
                    if otherP.Character and otherP.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (currentPos - otherP.Character.HumanoidRootPart.Position).Magnitude
                        if dist < 20 then
                            nearbyCount = nearbyCount + 1
                        end
                    end
                end

                local distToLastPoint = (currentPos - lastWaypoint).Magnitude
                if nearbyCount > maxNearby or (nearbyCount == maxNearby and distToLastPoint < minDistanceToWaypoint) then
                    maxNearby = nearbyCount
                    minDistanceToWaypoint = distToLastPoint
                    bestTargetPos = p.Character.HumanoidRootPart.CFrame
                end
            end
        end
        return bestTargetPos, maxNearby
    end

    ExploitsTab:Column("right")

    local CrowdSec = wrapSection(ExploitsTab:CreateSection({ Name = "Crowd Teleport", Collapsible = true }))

    CrowdSec:AddToggle({
        Name = "Auto TP to Crowd",
        Default = false,
        Callback = function(state)
            autoCrowdTpConn = state
            if state then
                task.spawn(function()
                    while autoCrowdTpConn do
                        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local bestTargetPos, _ = GetBestCrowdPos()
                            if bestTargetPos then
                                if isGhost and fakeCamPart then
                                    hrp.CFrame = bestTargetPos
                                    fakeCamPart.CFrame = bestTargetPos
                                    if ghostPlatform then
                                        ghostPlatform.CFrame = bestTargetPos * CFrame.new(0, -13, 0)
                                    end
                                else
                                    hrp.CFrame = bestTargetPos
                                end
                            end
                        end
                        task.wait(10)
                    end
                end)
            end
        end
    })

    CrowdSec:AddButton({
        Name = "TP to Crowd (Once)",
        Primary = false,
        Callback = function()
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local bestTargetPos, maxNearby = GetBestCrowdPos()
            if bestTargetPos then
                if isGhost and fakeCamPart then
                    hrp.CFrame = bestTargetPos
                    fakeCamPart.CFrame = bestTargetPos
                    if ghostPlatform then
                        ghostPlatform.CFrame = bestTargetPos * CFrame.new(0, -13, 0)
                    end
                    Notify("Moro Soul", "Ghost TP to Crowd (" .. maxNearby .. " players)", 2, "Success")
                else
                    hrp.CFrame = bestTargetPos
                    Notify("Moro Soul", "TP to Crowd (" .. maxNearby .. " players)", 2, "Success")
                end
            else
                Notify("Moro Soul", "No crowd found", 2, "Warning")
            end
        end
    })

    -- =====================================================================
    --                           DISPATCH TAB
    -- =====================================================================
    local selectedRole1 = nil
    local selectedRole2 = nil
    local selectedRole3 = nil

    DispatchTab:Column("left")

    local RoleSec = wrapSection(DispatchTab:CreateSection({ Name = "Select Roles", Collapsible = true }))

    RoleSec:AddDropdown({
        Name = "Select Role 1",
        Options = roleNames,
        Default = roleNames[1] or "",
        Callback = function(val)
            selectedRole1 = dispatchRoles[val]
        end
    })

    RoleSec:AddDropdown({
        Name = "Select Role 2",
        Options = roleNames,
        Default = roleNames[2] or "",
        Callback = function(val)
            selectedRole2 = dispatchRoles[val]
        end
    })

    RoleSec:AddDropdown({
        Name = "Select Role 3",
        Options = roleNames,
        Default = roleNames[3] or "",
        Callback = function(val)
            selectedRole3 = dispatchRoles[val]
        end
    })

    local ManualDispatchSec = wrapSection(DispatchTab:CreateSection({ Name = "Manual Dispatch Actions", Collapsible = true }))

    ManualDispatchSec:AddButton({
        Name = "Send Selected to Dispatch",
        Primary = true,
        Callback = function()
            local toSend = {}
            if selectedRole1 then table.insert(toSend, selectedRole1) end
            if selectedRole2 then table.insert(toSend, selectedRole2) end
            if selectedRole3 then table.insert(toSend, selectedRole3) end

            if #toSend == 0 then
                Notify("Moro Soul", "Select at least one role!", 2, "Warning")
                return
            end

            task.spawn(function()
                for _, roleId in ipairs(toSend) do
                    remoteFolder.Dispatch:FireServer(roleId)
                    task.wait(0.15) 
                end
                Notify("Moro Soul", "Sent " .. #toSend .. " roles to dispatch!", 2, "Success")
            end)
        end
    })

    ManualDispatchSec:AddButton({
        Name = "Claim Rewards",
        Primary = false,
        Callback = function()
            local idsToClaim = {}
            if selectedRole1 then table.insert(idsToClaim, selectedRole1) end
            if selectedRole2 then table.insert(idsToClaim, selectedRole2) end
            if selectedRole3 then table.insert(idsToClaim, selectedRole3) end

            if #idsToClaim > 0 then
                if EventBus and EventBus.FireServer then
                    EventBus.FireServer("ClaimDispatchReward", idsToClaim)
                else
                    rs.Packages.EventBus.EventProvider.default_RemoteEvent:FireServer("ClaimDispatchReward", idsToClaim)
                end
                Notify("Moro Soul", "Claimed rewards for " .. #idsToClaim .. " roles!", 2, "Success")
            else
                Notify("Moro Soul", "Select roles to claim!", 2, "Warning")
            end
        end
    })

    ManualDispatchSec:AddButton({
        Name = "Cancel Dispatch",
        Primary = false,
        Callback = function()
            local toCancel = {}
            if selectedRole1 then table.insert(toCancel, selectedRole1) end
            if selectedRole2 then table.insert(toCancel, selectedRole2) end
            if selectedRole3 then table.insert(toCancel, selectedRole3) end

            if #toCancel == 0 then
                Notify("Moro Soul", "No roles selected to cancel!", 2, "Warning")
                return
            end

            task.spawn(function()
                for _, roleId in ipairs(toCancel) do
                    remoteFolder.CancelDispatch:FireServer(roleId)
                    task.wait(0.1)
                end
                Notify("Moro Soul", "Cancelled dispatch for selected roles!", 2, "Info")
            end)
        end
    })

    DispatchTab:Column("right")

    local AutoDispatchSec = wrapSection(DispatchTab:CreateSection({ Name = "Automated Dispatch", Collapsible = true }))

    local autoDispatchConn = false

    AutoDispatchSec:AddToggle({
        Name = "Auto Dispatch",
        Default = false,
        Callback = function(state)
            autoDispatchConn = state
            
            if state then
                task.spawn(function()
                    while autoDispatchConn do
                        local roles = {}
                        if selectedRole1 then table.insert(roles, selectedRole1) end
                        if selectedRole2 then table.insert(roles, selectedRole2) end
                        if selectedRole3 then table.insert(roles, selectedRole3) end
                        
                        if #roles == 0 then
                            Notify("Moro Soul", "AutoDispatch: No roles selected!", 2, "Warning")
                            autoDispatchConn = false
                            break
                        end

                        for _, roleId in ipairs(roles) do
                            if not autoDispatchConn then break end
                            remoteFolder.Dispatch:FireServer(roleId)
                            task.wait(0.2)
                        end
                        
                        Notify("Moro Soul", "AutoDispatch: Sent roles. Monitoring timers...", 2, "Info")

                        local dispatchDuration = 1802
                        pcall(function()
                            dispatchDuration = rs.Configs.GlobalConfigs.DispatchTime.Value + 2
                        end)

                        for i = 1, dispatchDuration do
                            if not autoDispatchConn then break end
                            task.wait(1)
                        end

                        if not autoDispatchConn then break end

                        if EventBus and EventBus.FireServer then
                            EventBus.FireServer("ClaimDispatchReward", roles)
                        else
                            rs.Packages.EventBus.EventProvider.default_RemoteEvent:FireServer("ClaimDispatchReward", roles)
                        end
                        
                        Notify("Moro Soul", "AutoDispatch: Rewards claimed! Restarting...", 2, "Success")
                        task.wait(3)
                    end
                end)
            else
                Notify("Moro Soul", "Auto Dispatch Disabled", 2, "Info")
            end
        end
    })

    AutoDispatchSec:AddButton({
        Name = "Claim All Ready Dispatches",
        Primary = false,
        Callback = function()
            local pd = rs:FindFirstChild("PlayerData") and rs.PlayerData:FindFirstChild(player.Name)
            local dInfo = pd and pd:FindFirstChild("DispatchInfo")
            local readyList = {}
            
            local dispatchTime = 1800
            pcall(function()
                dispatchTime = rs.Configs.GlobalConfigs.DispatchTime.Value
            end)
            
            if dInfo then
                for _, child in ipairs(dInfo:GetChildren()) do
                    if child.Value >= dispatchTime then
                        table.insert(readyList, tonumber(child.Name))
                    end
                end
            end
            
            if #readyList > 0 then
                if EventBus and EventBus.FireServer then
                    EventBus.FireServer("ClaimDispatchReward", readyList)
                else
                    rs.Packages.EventBus.EventProvider.default_RemoteEvent:FireServer("ClaimDispatchReward", readyList)
                end
                Notify("Moro Soul", "Claimed " .. #readyList .. " ready dispatches!", 2, "Success")
            else
                Notify("Moro Soul", "No dispatches ready to claim yet", 2, "Info")
            end
        end
    })

    -- =====================================================================
    --                           REWARDS & QUESTS TAB
    -- =====================================================================
    local promoCodes = {
        "demon", "demonsoul", "demonsoul300k", "thanks3000likes", "Welcome",
        "1000likes", "demon150k", "demon100k", "demon50k", "demon20k", "demon10k",
        "10klikes", "5000likes", "2000likes", "3000likes", "100kmembers",
        "200kmembers", "300kmembers", "400kmembers", "500kmembers", "600kmembers",
        "700kmembers", "800kmembers", "1Mmembers", "ADouma", "dakigo", "gyutarogo",
        "tengen", "shinobu", "kamado", "zenitsu", "inosuke", "kyojuro", "akaza",
        "rui", "demon500k", "demon600k", "demon700k", "demon800k", "demon1m"
    }

    RewardsTab:Column("left")

    local PromoSec = wrapSection(RewardsTab:CreateSection({ Name = "Promo Codes", Collapsible = true }))

    PromoSec:AddButton({
        Name = "Redeem All Promo Codes",
        Primary = true,
        Callback = function()
            task.spawn(function()
                Notify("Moro Soul", "Redeeming all codes...", 2, "Info")
                local redeemed = 0
                for _, code in ipairs(promoCodes) do
                    pcall(function()
                        remoteFolder.Code:FireServer(code)
                    end)
                    redeemed = redeemed + 1
                    task.wait(0.35)
                end
                Notify("Moro Soul", "Finished! Sent " .. redeemed .. " codes.", 3, "Success")
            end)
        end
    })

    local customCodeText = ""
    PromoSec:AddTextbox({
        Name = "Custom Code",
        Default = "",
        Placeholder = "Enter promo code...",
        Callback = function(val)
            customCodeText = val
        end
    })

    PromoSec:AddButton({
        Name = "Redeem Custom Code",
        Primary = false,
        Callback = function()
            if customCodeText and #customCodeText > 0 then
                pcall(function()
                    remoteFolder.Code:FireServer(customCodeText)
                end)
                Notify("Moro Soul", "Redeemed code: " .. customCodeText, 2, "Success")
            else
                Notify("Moro Soul", "Enter a code first!", 2, "Warning")
            end
        end
    })

    local RouletteSec = wrapSection(RewardsTab:CreateSection({ Name = "Daily Roulette", Collapsible = true }))

    local function spinRoulette()
        local pd = rs:FindFirstChild("PlayerData") and rs.PlayerData:FindFirstChild(player.Name)
        local lastTime = pd and pd:FindFirstChild("LastRouletteTime") and pd.LastRouletteTime.Value or 0
        local elapsed = os.time() - lastTime
        if elapsed >= 86400 then
            pcall(function()
                remoteFolder.Roulette:FireServer()
            end)
            Notify("Moro Soul", "Daily Roulette Spun!", 3, "Success")
            return true
        else
            local remaining = 86400 - elapsed
            local h = math.floor(remaining / 3600)
            local m = math.floor((remaining % 3600) / 60)
            Notify("Moro Soul", string.format("Roulette CD: %02d h %02d min", h, m), 3, "Info")
            return false
        end
    end

    RouletteSec:AddButton({
        Name = "Spin Daily Roulette",
        Primary = false,
        Callback = function()
            spinRoulette()
        end
    })

    RouletteSec:AddToggle({
        Name = "Auto Daily Roulette",
        Default = false,
        Callback = function(state)
            autoRoulette = state
            if state then
                task.spawn(function()
                    while autoRoulette do
                        spinRoulette()
                        task.wait(60)
                    end
                end)
            end
        end
    })

    RewardsTab:Column("right")

    local ChestsSec = wrapSection(RewardsTab:CreateSection({ Name = "Menu Chests (Server Direct)", Collapsible = true }))

    local autoOpenMenuChests = false
    local chestRarityTarget = "All Rarities (Auto)"
    local chestBatchAmount = 10
    local chestOpenDelay = 0.3
    local chestSkipPopup = true
    local notifyOnEternal = false

    local function safeClick(btn)
        if not btn then return false end
        local clicked = false
        pcall(function()
            if firesignal then
                firesignal(btn.MouseButton1Down)
                firesignal(btn.MouseButton1Click)
                firesignal(btn.MouseButton1Up)
                firesignal(btn.Activated)
                clicked = true
            end
        end)
        pcall(function()
            if getconnections then
                for _, c in ipairs(getconnections(btn.MouseButton1Click)) do
                    c:Fire()
                    clicked = true
                end
                for _, c in ipairs(getconnections(btn.Activated)) do
                    c:Fire()
                    clicked = true
                end
            end
        end)
        pcall(function()
            if vim and btn:IsA("GuiObject") and btn.Visible then
                local absPos = btn.AbsolutePosition + btn.AbsoluteSize / 2
                if absPos.X > 0 and absPos.Y > 0 then
                    vim:SendMouseButtonEvent(absPos.X, absPos.Y, 0, true, game, 1)
                    task.wait(0.04)
                    vim:SendMouseButtonEvent(absPos.X, absPos.Y, 0, false, game, 1)
                    clicked = true
                end
            end
        end)
        return clicked
    end

    local function safeFirePrompt(obj)
        if not obj then return false end
        local pp = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        if pp and pp.Enabled then
            if fireproximityprompt then
                pcall(function() fireproximityprompt(pp) end)
                return true
            else
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and obj:IsA("PVInstance") then
                    hrp.CFrame = obj:GetPivot()
                    task.wait(0.1)
                    vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.2)
                    vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    return true
                end
            end
        end
        return false
    end

    local function closeRewardPopups()
        local pGui = player:FindFirstChild("PlayerGui")
        if not pGui then return end
        for _, gui in ipairs(pGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("GuiButton") and obj.Visible then
                        local n = obj.Name:lower()
                        local t = (obj:IsA("TextButton") and obj.Text or ""):lower()
                        if n:find("confirm", 1, true) or n:find("ok", 1, true) or n:find("receive", 1, true) or n:find("claim", 1, true) or n:find("skip", 1, true) or n:find("close", 1, true)
                           or t:find("ok", 1, true) or t:find("confirm", 1, true) or t:find("receive", 1, true) or t:find("claim", 1, true) or t:find("получить", 1, true) or t:find("пропустить", 1, true) then
                            local parent = obj.Parent
                            local pName = parent and parent.Name:lower() or ""
                            if pName:find("reward", 1, true) or pName:find("popup", 1, true) or pName:find("prompt", 1, true) or pName:find("notice", 1, true) or pName:find("get", 1, true) or pName:find("congrat", 1, true) then
                                safeClick(obj)
                            end
                        end
                    end
                end
            end
        end
    end

    local CHEST_ACTIONS = {
        [1] = "/\229\174\157\231\174\177\231\179\187\231\187\159/\229\188\128\229\174\157\231\174\177/\229\188\128\229\174\157\231\174\1771?\229\164\154\230\172\161\232\180\173\228\185\176", -- Common (⚪ Tier 1)
        [2] = "/\229\174\157\231\174\177\231\179\187\231\187\159/\229\188\128\229\174\157\231\174\177/\229\188\128\229\174\157\231\174\1772?\229\164\154\230\172\161\232\180\173\228\185\176", -- Rare (🔵 Tier 2)
        [3] = "/\229\174\157\231\174\177\231\179\187\231\187\159/\229\188\128\229\174\157\231\174\177/\229\188\128\229\174\157\231\174\1773?\229\164\154\230\172\161\232\180\173\228\185\176", -- Epic (🟣 Tier 3)
        [4] = "/\229\174\157\231\174\177\231\179\187\231\187\159/\229\188\128\229\174\157\231\174\177/\229\188\128\229\174\157\231\174\1774?\229\164\154\230\172\161\232\180\173\228\185\176", -- Legendary (🟡 Tier 4)
        [5] = "/\229\174\157\231\174\177\231\179\187\231\187\159/\229\188\128\229\174\157\231\174\177/\229\188\128\229\174\157\231\174\1775?\229\164\154\230\172\161\232\180\173\228\185\176", -- Mythical (🔴 Tier 5)
    }

    -- Eternal Rarity (Quality 4 - Absolute Highest Rarity in Game)
    local eternalHeroLookup = {
        ["Kanroji Mitsuri"] = true, ["甘露寺蜜璃"] = true, ["Mitsuri Kanroji"] = true,
        ["Gyuutarou"] = true, ["妓夫太郎"] = true, ["Gyutaro"] = true,
        ["Iguro Obanai"] = true, ["伊黑小芭内"] = true,
        ["Tokitou Muichirou"] = true, ["时透无一郎"] = true, ["Muichiro Tokito"] = true,
        ["Shinazugawa Sanemi"] = true, ["不死川实弥"] = true, ["Sanemi Shinazugawa"] = true,
        ["Douma"] = true, ["童魔"] = true,
        ["Zohakuten"] = true, ["憎珀天"] = true,
        ["Tanjirou[Swordsmith]"] = true, ["炭治郎_锻刀村篇"] = true, ["Tanjiro (Swordsmith Village)"] = true,
    }

    local eternalRoleIds = {
        [17] = "Kanroji Mitsuri",
        [20] = "Gyuutarou",
        [22] = "Iguro Obanai",
        [23] = "Tokitou Muichirou",
        [24] = "Shinazugawa Sanemi",
        [26] = "Douma",
        [34] = "Zohakuten",
        [35] = "Tanjirou[Swordsmith]",
    }

    local roleIdToName = {}
    pcall(function()
        local rc = require(rs:WaitForChild("Configs"):WaitForChild("RoleConfig"))
        for id, r in pairs(rc) do
            local q = r.Quality or r.RoleQuality or r.Rarity or r.Grade
            if q == 4 or tostring(q):lower():find("eternal", 1, true) or tostring(q):find("永恒", 1, true) then
                if r.RoleName then
                    eternalHeroLookup[r.RoleName] = true
                    eternalHeroLookup[r.RoleName:lower()] = true
                end
                if r.RoleIndex then
                    eternalHeroLookup[r.RoleIndex] = true
                end
                if r.RoleId then
                    eternalRoleIds[r.RoleId] = r.RoleName or tostring(r.RoleId)
                end
                eternalRoleIds[tonumber(id) or id] = r.RoleName or tostring(id)
            end
            if r.RoleName and r.RoleId then
                roleIdToName[r.RoleId] = r.RoleName
                roleIdToName[tonumber(id) or id] = r.RoleName
            end
        end
    end)

    local function safeInvokeWuKongChest(tier, count)
        local path = CHEST_ACTIONS[tier]
        if not path then return false, "Invalid tier" end
        count = tonumber(count) or 10

        local invoked = false
        local res = nil
        -- 1. Direct InvokeServer via RemoteActionFunction (exact method from dss.lua)
        pcall(function()
            local wk = rs:FindFirstChild("WuKong")
            if not wk then return end
            local raf = wk:FindFirstChild("RemoteActionFunction")
            if not raf then return end
            res = raf:InvokeServer(path, count)
            invoked = true
        end)

        -- 2. Fallback via WuKong module ExecuteAction if available
        if not invoked then
            pcall(function()
                local wkModule = WuKong
                if not wkModule then
                    pcall(function() wkModule = require(rs:WaitForChild("WuKong", 2)) end)
                end
                if wkModule and wkModule.ExecuteAction then
                    res = wkModule:ExecuteAction(path, count)
                    invoked = true
                end
            end)
        end

        -- 3. Update event task progress (from dss.lua)
        pcall(function()
            local pkgs = rs:FindFirstChild("Packages")
            if not pkgs then return end
            local eb = pkgs:FindFirstChild("EventBus")
            if not eb then return end
            local ep = eb:FindFirstChild("EventProvider")
            if not ep then return end
            local remote = ep:FindFirstChild("default_RemoteEvent")
            if not remote then return end
            remote:FireServer("UpdateChristmasTaskProgress_OpenChest", 10)
            task.wait(0.08)
            remote:FireServer("InfiniteCityEventProgress_OpenChest", 10)
        end)

        return invoked, res
    end

    local function detectEternalDrop(tier, serverRes)
        local found = {}

        local function checkMatch(rawStr)
            if type(rawStr) ~= "string" or #rawStr < 2 then return end
            local lower = rawStr:lower()
            -- Match directly against known Eternal heroes
            for heroName, _ in pairs(eternalHeroLookup) do
                if rawStr == heroName or rawStr:find(heroName, 1, true) or lower:find(tostring(heroName):lower(), 1, true) then
                    found[heroName] = true
                end
            end
            -- Match if string explicitly mentions Eternal rarity
            if lower:find("eternal", 1, true) or lower:find("вечный", 1, true) or lower:find("этернал", 1, true) or rawStr:find("永恒", 1, true) then
                for heroName, _ in pairs(eternalHeroLookup) do
                    if rawStr:find(heroName, 1, true) or lower:find(tostring(heroName):lower(), 1, true) then
                        found[heroName] = true
                    end
                end
            end
        end

        local function scanVal(val, depth)
            if not val or depth > 6 then return end
            local vt = type(val)
            if vt == "string" then
                checkMatch(val)
            elseif vt == "number" then
                local rName = eternalRoleIds[val]
                if rName then
                    found[rName] = true
                end
            elseif vt == "table" then
                for k, v in pairs(val) do
                    if type(k) == "string" then checkMatch(k) end
                    scanVal(v, depth + 1)
                end
            end
        end
        scanVal(serverRes, 1)

        -- Scan PlayerGui reward popups / labels
        pcall(function()
            local pGui = player:FindFirstChild("PlayerGui")
            if not pGui then return end
            for _, gui in ipairs(pGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled then
                    for _, obj in ipairs(gui:GetDescendants()) do
                        if obj:IsA("TextLabel") and obj.Visible and #obj.Text > 1 then
                            local t = obj.Text
                            local lower = t:lower()
                            local hasEternal = lower:find("eternal", 1, true) or lower:find("вечный", 1, true) or lower:find("этернал", 1, true) or t:find("永恒", 1, true)
                            for heroName, _ in pairs(eternalHeroLookup) do
                                if t:find(heroName, 1, true) or (hasEternal and lower:find(tostring(heroName):lower(), 1, true)) then
                                    found[heroName] = true
                                end
                            end
                            if hasEternal and next(found) == nil then
                                found[t:sub(1, 30)] = true
                            end
                        end
                    end
                end
            end
        end)

        local list = {}
        for name, _ in pairs(found) do
            table.insert(list, name)
        end
        return list
    end

    local eternalGuiConn = nil
    local lastEternalNotifiedTick = 0
    local function updateEternalListener(state)
        if eternalGuiConn then
            pcall(function() eternalGuiConn:Disconnect() end)
            eternalGuiConn = nil
        end
        if state then
            local pGui = player:FindFirstChild("PlayerGui")
            if pGui then
                eternalGuiConn = pGui.DescendantAdded:Connect(function(desc)
                    if not notifyOnEternal then return end
                    if tick() - lastEternalNotifiedTick < 2.0 then return end
                    if desc:IsA("TextLabel") then
                        task.wait(0.04)
                        pcall(function()
                            local t = desc.Text
                            if not t or #t < 2 then return end
                            local lower = t:lower()
                            local hasEternal = lower:find("eternal", 1, true) or lower:find("вечный", 1, true) or lower:find("этернал", 1, true) or t:find("永恒", 1, true)
                            for heroName, _ in pairs(eternalHeroLookup) do
                                if t:find(heroName, 1, true) or (hasEternal and lower:find(tostring(heroName):lower(), 1, true)) then
                                    lastEternalNotifiedTick = tick()
                                    Notify("Moro Soul", "🌟 ВЫПАЛ ETERNAL: " .. heroName .. "!", 8, "Success")
                                    print("[Moro Soul] 🌟 ETERNAL DROP (GUI): " .. heroName)
                                    return
                                end
                            end
                            if hasEternal then
                                lastEternalNotifiedTick = tick()
                                Notify("Moro Soul", "🌟 ВЫПАЛ ETERNAL ДРОП!", 8, "Success")
                                print("[Moro Soul] 🌟 ETERNAL DROP (GUI): " .. t)
                            end
                        end)
                    end
                end)
            end
        end
    end
    table.insert(cleanupHandlers, function() if eternalGuiConn then pcall(function() eternalGuiConn:Disconnect() end) end end)

    local function getTierFromTarget(targetStr)
        if not targetStr then return nil end
        if targetStr:find("Mythic", 1, true) or targetStr:find("5", 1, true) then
            return 5
        elseif targetStr:find("Legend", 1, true) or targetStr:find("4", 1, true) then
            return 4
        elseif targetStr:find("Epic", 1, true) or targetStr:find("3", 1, true) then
            return 3
        elseif targetStr:find("Rare", 1, true) or targetStr:find("2", 1, true) then
            return 2
        elseif targetStr:find("Common", 1, true) or targetStr:find("1", 1, true) then
            return 1
        end
        return nil
    end

    -- === AUTO OPEN CHESTS LOOP ===
    task.spawn(function()
        while scriptActive do
            if autoOpenMenuChests then
                local selectedTier = getTierFromTarget(chestRarityTarget)
                if selectedTier then
                    local ok, sRes = safeInvokeWuKongChest(selectedTier, chestBatchAmount or 10)
                    if ok and notifyOnEternal then
                        task.wait(0.05)
                        local eternals = detectEternalDrop(selectedTier, sRes)
                        if #eternals > 0 and tick() - lastEternalNotifiedTick >= 2.0 then
                            lastEternalNotifiedTick = tick()
                            local dropStr = table.concat(eternals, ", ")
                            Notify("Moro Soul", "🌟 ВЫПАЛ ETERNAL: " .. dropStr .. "!", 8, "Success")
                            print("[Moro Soul] 🌟 ETERNAL DROP: " .. dropStr)
                        end
                    end
                else
                    -- "All Rarities (Auto)": iterate 5 down to 1
                    for tier = 5, 1, -1 do
                        if not autoOpenMenuChests or not scriptActive then break end
                        local ok, sRes = safeInvokeWuKongChest(tier, chestBatchAmount or 10)
                        if ok and notifyOnEternal then
                            task.wait(0.05)
                            local eternals = detectEternalDrop(tier, sRes)
                            if #eternals > 0 and tick() - lastEternalNotifiedTick >= 2.0 then
                                lastEternalNotifiedTick = tick()
                                local dropStr = table.concat(eternals, ", ")
                                Notify("Moro Soul", "🌟 ВЫПАЛ ETERNAL: " .. dropStr .. "!", 8, "Success")
                                print("[Moro Soul] 🌟 ETERNAL DROP: " .. dropStr)
                            end
                        end
                        task.wait(chestOpenDelay or 0.3)
                    end
                end
                if chestSkipPopup then
                    closeRewardPopups()
                end
                task.wait(chestOpenDelay or 0.3)
            else
                task.wait(0.6)
            end
        end
    end)

    ChestsSec:AddToggle({
        Name = "Auto Open Chests (Loop)",
        Default = false,
        Callback = function(state)
            autoOpenMenuChests = state
            Notify("Moro Soul", state and "Auto Open Chests Active!" or "Auto Open Chests Disabled", 2, state and "Success" or "Info")
        end
    })

    ChestsSec:AddDropdown({
        Name = "Target Chest Rarity",
        Options = {"All Rarities (Auto)", "🔴 Mythical (Tier 5)", "🟡 Legendary (Tier 4)", "🟣 Epic (Tier 3)", "🔵 Rare (Tier 2)", "⚪ Common (Tier 1)"},
        Default = "All Rarities (Auto)",
        Callback = function(val)
            chestRarityTarget = val
            Notify("Moro Soul", "Target Chest: " .. tostring(val), 2, "Info")
        end
    })

    ChestsSec:AddSlider({
        Name = "Chests Per Batch",
        Min = 1,
        Max = 100,
        Default = 10,
        Decimals = 0,
        Callback = function(val)
            chestBatchAmount = math.floor(val)
        end
    })

    ChestsSec:AddSlider({
        Name = "Open Delay (Sec)",
        Min = 0.1,
        Max = 2.0,
        Default = 0.3,
        Decimals = 2,
        Callback = function(val)
            chestOpenDelay = val
        end
    })

    ChestsSec:AddToggle({
        Name = "Auto-Skip Reward Popups",
        Default = true,
        Callback = function(state)
            chestSkipPopup = state
        end
    })

    ChestsSec:AddToggle({
        Name = "Notify on Eternal Drop",
        Default = false,
        Callback = function(state)
            notifyOnEternal = state
            updateEternalListener(state)
            Notify("Moro Soul", state and "Eternal Drop Alert Enabled! (🌟)" or "Eternal Drop Alert Disabled", 2, state and "Success" or "Info")
        end
    })

    ChestsSec:AddButton({
        Name = "Collect ALL Rewards & Chests",
        Primary = true,
        Callback = function()
            task.spawn(function()
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local savedCF = hrp and hrp.CFrame
                local pt = workspace:FindFirstChild("PromptTriggers")
                if not pt then return end
                
                local items = {"TrainChest_1", "TrainChest_2", "MysteryBoxTouch", "GroupRewardTouch"}
                local collected = 0
                for _, name in ipairs(items) do
                    local target = pt:FindFirstChild(name)
                    if target and target:IsA("PVInstance") and hrp then
                        hrp.CFrame = target:GetPivot() + Vector3.new(0, 1, 0)
                        task.wait(0.15)
                        if safeFirePrompt(target) then
                            collected = collected + 1
                        end
                        task.wait(0.2)
                    end
                end
                if savedCF and hrp then
                    hrp.CFrame = savedCF
                end
                Notify("Moro Soul", "Collected " .. collected .. " rewards & returned!", 3, "Success")
            end)
        end
    })

    ChestsSec:AddButton({
        Name = "Collect Train Chests (1 & 2)",
        Primary = false,
        Callback = function()
            local pt = workspace:FindFirstChild("PromptTriggers")
            if pt then
                local c1 = pt:FindFirstChild("TrainChest_1")
                local c2 = pt:FindFirstChild("TrainChest_2")
                local count = 0
                if safeFirePrompt(c1) then count = count + 1 end
                task.wait(0.2)
                if safeFirePrompt(c2) then count = count + 1 end
                Notify("Moro Soul", "Collected " .. count .. " Train Chests", 2, "Success")
            end
        end
    })

    ChestsSec:AddButton({
        Name = "Collect Mystery Box",
        Primary = false,
        Callback = function()
            local pt = workspace:FindFirstChild("PromptTriggers")
            local mb = pt and pt:FindFirstChild("MysteryBoxTouch")
            if safeFirePrompt(mb) then
                Notify("Moro Soul", "Collected Mystery Box!", 2, "Success")
            else
                Notify("Moro Soul", "Mystery Box not found!", 2, "Warning")
            end
        end
    })

    ChestsSec:AddButton({
        Name = "Claim Group Reward",
        Primary = false,
        Callback = function()
            local pt = workspace:FindFirstChild("PromptTriggers")
            local gr = pt and pt:FindFirstChild("GroupRewardTouch")
            if safeFirePrompt(gr) then
                Notify("Moro Soul", "Claimed Group Reward!", 2, "Success")
            else
                Notify("Moro Soul", "Group Reward not found!", 2, "Warning")
            end
        end
    })

    local MissionSec = wrapSection(RewardsTab:CreateSection({ Name = "Missions & Attendance", Collapsible = true }))

    local function claimDailyAttendance()
        local WuKong = nil
        pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end)
        if WuKong then
            local success = pcall(function()
                WuKong:ExecuteAction("/活动/每日登录奖励/领取每日登录奖励?购买", "__null__", "__null__")
            end)
            if success then
                Notify("Moro Soul", "Daily Attendance Claimed!", 3, "Success")
                return true
            end
        end
        return false
    end

    local function claimReadyMissions()
        local WuKong = nil
        pcall(function() WuKong = require(rs:WaitForChild("WuKong")) end)
        if not WuKong then return 0 end
        
        local claimed = 0
        pcall(function()
            local subitems = WuKong:ExecuteQuery("/任务/日常任务分组?已激活子项")
            if subitems then
                for _, group in pairs(subitems) do
                    local children = WuKong:ExecuteQuery(("/任务/日常任务分组/%*?已激活子项"):format(group))
                    if children then
                        for _, id in pairs(children) do
                            local path = ("/任务/日常任务分组/%*/%*"):format(group, id)
                            local config = WuKong:ExecuteQuery(path .. "?获取元素配置")
                            local progress = WuKong:ExecuteQuery(path .. "?获取监听事件计数")
                            if config and config.Tags and progress then
                                local maxProgress = config.Tags[3] - 0
                                if progress >= maxProgress then
                                    local validate = WuKong:ExecuteValidate(path .. "?购买验证", "__null__", "__null__")
                                    if validate and not validate:getHasError() then
                                        pcall(function()
                                            WuKong:ExecuteAction(path .. "?购买")
                                            claimed = claimed + 1
                                        end)
                                        task.wait(0.2)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
        return claimed
    end

    MissionSec:AddButton({
        Name = "Claim Daily Attendance (7-Day)",
        Primary = false,
        Callback = function()
            if not claimDailyAttendance() then
                Notify("Moro Soul", "Attendance already claimed or not ready", 2, "Info")
            end
        end
    })

    MissionSec:AddButton({
        Name = "Claim Ready Daily Missions",
        Primary = false,
        Callback = function()
            task.spawn(function()
                local c = claimReadyMissions()
                if c > 0 then
                    Notify("Moro Soul", "Claimed " .. c .. " daily missions!", 3, "Success")
                else
                    Notify("Moro Soul", "No missions ready to claim", 2, "Info")
                end
            end)
        end
    })

    MissionSec:AddToggle({
        Name = "Auto Claim Missions",
        Default = false,
        Callback = function(state)
            autoMissions = state
            if state then
                task.spawn(function()
                    while autoMissions do
                        claimDailyAttendance()
                        claimReadyMissions()
                        task.wait(30)
                    end
                end)
            end
        end
    })

    -- =====================================================================
    --                           EXPLOITS TAB
    -- =====================================================================
    do
        ExploitsTab:Column("left")

    -- 1. World & Wall Exploits
    local WallSec = wrapSection(ExploitsTab:CreateSection({ Name = "World & Wall Exploits", Collapsible = true }))

    local bypassWallsActive = false
    local wallConn = nil

    local function applyWallBypass()
        local walls = workspace:FindFirstChild("LockedAreaWalls")
        if walls then
            for _, model in ipairs(walls:GetChildren()) do
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        part.Transparency = 0.7
                    end
                end
            end
        end
    end

    WallSec:AddToggle({
        Name = "Bypass Locked Walls",
        Default = false,
        Callback = function(state)
            bypassWallsActive = state
            if state then
                applyWallBypass()
                if wallConn then wallConn:Disconnect() end
                wallConn = runService.Heartbeat:Connect(function()
                    if bypassWallsActive then
                        applyWallBypass()
                    end
                end)
                Notify("Moro Soul", "Locked Walls Bypassed! All Areas Accessible", 2, "Success")
            else
                if wallConn then
                    wallConn:Disconnect()
                    wallConn = nil
                end
                local walls = workspace:FindFirstChild("LockedAreaWalls")
                if walls then
                    for _, model in ipairs(walls:GetChildren()) do
                        for _, part in ipairs(model:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = true
                                part.Transparency = 0
                            end
                        end
                    end
                end
                Notify("Moro Soul", "Locked Walls Restored", 2, "Info")
            end
        end
    })

    local noClipActive = false
    local noClipConn = nil

    WallSec:AddToggle({
        Name = "No-Clip (Ghost Mode)",
        Default = false,
        Callback = function(state)
            noClipActive = state
            if state then
                if noClipConn then noClipConn:Disconnect() end
                noClipConn = runService.Stepped:Connect(function()
                    local char = player.Character
                    if char and noClipActive then
                        for _, part in ipairs(char:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end)
                Notify("Moro Soul", "No-Clip Activated!", 2, "Success")
            else
                if noClipConn then
                    noClipConn:Disconnect()
                    noClipConn = nil
                end
                Notify("Moro Soul", "No-Clip Disabled", 2, "Info")
            end
        end
    })

    local infJumpActive = false
    local infJumpConn = nil

    WallSec:AddToggle({
        Name = "Infinite Jump",
        Default = false,
        Callback = function(state)
            infJumpActive = state
            if state then
                if infJumpConn then infJumpConn:Disconnect() end
                infJumpConn = uis.JumpRequest:Connect(function()
                    local char = player.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and infJumpActive then
                        hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end)
                Notify("Moro Soul", "Infinite Jump Enabled", 2, "Success")
            else
                if infJumpConn then
                    infJumpConn:Disconnect()
                    infJumpConn = nil
                end
                Notify("Moro Soul", "Infinite Jump Disabled", 2, "Info")
            end
        end
    })

    local customJumpPower = 50
    WallSec:AddSlider({
        Name = "Jump Power",
        Min = 50,
        Max = 250,
        Default = 50,
        Suffix = " jp",
        Decimals = 0,
        Callback = function(val)
            customJumpPower = tonumber(val) or 50
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.UseJumpPower = true
                hum.JumpPower = customJumpPower
            end
        end
    })

    -- 2. World Area Teleporter
    local TeleportSec = wrapSection(ExploitsTab:CreateSection({ Name = "World Teleporter (Remote)", Collapsible = true }))

    local areaOptions = {
        "Wilderness",
        "Ubuyashiki Residence",
        "Farmland",
        "Train Station",
        "Wisteria Peak",
        "Wisteria Village"
    }
    local selectedWorldArea = areaOptions[1]

    TeleportSec:AddDropdown({
        Name = "Select World Area",
        Options = areaOptions,
        Default = areaOptions[1],
        Callback = function(val)
            selectedWorldArea = val
        end
    })

    TeleportSec:AddButton({
        Name = "Teleport to World (Instant)",
        Primary = true,
        Callback = function()
            pcall(function()
                if remoteFolder:FindFirstChild("UnlockTeleport") then
                    remoteFolder.UnlockTeleport:FireServer()
                end
                if remoteFolder:FindFirstChild("AreaTeleport") then
                    remoteFolder.AreaTeleport:FireServer(selectedWorldArea)
                    Notify("Moro Soul", "Teleporting to " .. tostring(selectedWorldArea) .. "...", 2, "Success")
                else
                    Notify("Moro Soul", "AreaTeleport remote not found!", 2, "Error")
                end
            end)
        end
    })

    TeleportSec:AddButton({
        Name = "Unlock All World Teleports",
        Primary = false,
        Callback = function()
            local unRemote = remoteFolder:FindFirstChild("UnlockTeleport")
            if unRemote then
                unRemote:FireServer()
                Notify("Moro Soul", "UnlockTeleport request sent to server!", 2, "Success")
            else
                Notify("Moro Soul", "UnlockTeleport not found", 2, "Warning")
            end
        end
    })

    TeleportSec:AddButton({
        Name = "Teleport to Boss Area",
        Primary = false,
        Callback = function()
            if remoteFolder:FindFirstChild("ToBossArea") then
                remoteFolder.ToBossArea:FireServer()
                Notify("Moro Soul", "Teleporting to Boss Area...", 2, "Success")
            end
        end
    })

    TeleportSec:AddButton({
        Name = "Teleport to Mugen Train",
        Primary = false,
        Callback = function()
            if remoteFolder:FindFirstChild("ToMugenTrain") then
                remoteFolder.ToMugenTrain:FireServer()
                Notify("Moro Soul", "Teleporting to Mugen Train...", 2, "Success")
            end
        end
    })

    TeleportSec:AddButton({
        Name = "Teleport to Blood Moon",
        Primary = false,
        Callback = function()
            if remoteFolder:FindFirstChild("ToBloodMoon") then
                remoteFolder.ToBloodMoon:FireServer()
                Notify("Moro Soul", "Teleporting to Blood Moon...", 2, "Success")
            end
        end
    })

    ExploitsTab:Column("right")

    -- 3. GamePass & VIP Exploits
    local PassSec = wrapSection(ExploitsTab:CreateSection({ Name = "GamePass & VIP Perks", Collapsible = true }))

    local autoSpoofPasses = false
    local passSpoofConn = nil

    local function applyGamePassSpoof()
        local pd = rs:FindFirstChild("PlayerData") and rs.PlayerData:FindFirstChild(player.Name)
        if not pd then return end
        
        local passes = {
            "GamePass_Speed",
            "GamePass_FastDrawRole1",
            "GamePass_FastDrawRole2",
            "GamePass_DoubleSoul",
            "GamePass_DoubleExp",
            "GamePass_Magnet",
            "GamePass_Luck1",
            "GamePass_Luck2",
            "GamePass_Luck3",
            "GamePass_AutoAttack",
            "GamePass_Dispatch1",
            "GamePass_Dispatch2",
            "GamePass_Dispatch3",
            "GamePass_UnlockHelper1",
            "GamePass_UnlockHelper2",
            "GamePass_Vip"
        }
        for _, passName in ipairs(passes) do
            local val = pd:FindFirstChild(passName)
            if val and val:IsA("BoolValue") then
                val.Value = true
            end
        end
        
        pcall(function()
            local toolMod = require(rs.Modules.Tool)
            if toolMod and toolMod.SetMoveSpeed then
                toolMod.SetMoveSpeed(player)
            end
        end)
    end

    PassSec:AddButton({
        Name = "Unlock All GamePass Perks (Client)",
        Primary = true,
        Callback = function()
            applyGamePassSpoof()
            Notify("Moro Soul", "All Client GamePasses & VIP Unlocked!", 3, "Success")
        end
    })

    PassSec:AddToggle({
        Name = "Keep GamePasses Active (Persistent)",
        Default = false,
        Callback = function(state)
            autoSpoofPasses = state
            if state then
                applyGamePassSpoof()
                if passSpoofConn then passSpoofConn:Disconnect() end
                passSpoofConn = runService.Heartbeat:Connect(function()
                    if autoSpoofPasses then
                        applyGamePassSpoof()
                    end
                end)
                Notify("Moro Soul", "GamePass Lock Activated", 2, "Success")
            else
                if passSpoofConn then
                    passSpoofConn:Disconnect()
                    passSpoofConn = nil
                end
                Notify("Moro Soul", "GamePass Lock Disabled", 2, "Info")
            end
        end
    })

    -- 3.5. Friend Server Bonus Exploits (Unlock All 9 Buffs without friends)
    local FriendBonusSec = wrapSection(ExploitsTab:CreateSection({ Name = "Friend Server Bonus (9/9)", Collapsible = true }))

    local friendBonusCharConn = nil

    local function applyFriendBonusState(enable)
        pcall(function()
            local PropertyTribeTreeManager = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribeTreeManager"))
            local PropertyTribe = require(rs:WaitForChild("Packages"):WaitForChild("PropertyTribe"))
            local MathManager = require(rs:WaitForChild("Packages"):WaitForChild("MathManager"))
            local userTree = PropertyTribeTreeManager.GetUserTree(player.UserId)
            local battleTree = PropertyTribeTreeManager.GetBattleUserTree(player.UserId)

            if enable then
                -- Calculate combined property tribe of all 9 friend bonus tiers
                local combinedTribe = nil
                for i = 1, 9 do
                    if MathManager.HasConfigPropertyTribe("Friends", i) then
                        local cfg = MathManager.GetConfigPropertyTribe("Friends", i)
                        if not combinedTribe then
                            combinedTribe = cfg:Clone()
                        else
                            combinedTribe = combinedTribe + cfg
                        end
                    end
                end

                if userTree and userTree.Friends then
                    userTree.Friends:ResetHandler(function()
                        local res = combinedTribe
                        if isSpeedHack and (speedPercentValue or 0) > 0 then
                            local speedTribe = PropertyTribe.new({
                                MoveSpeedRatio = (speedPercentValue or 50) / 100
                            })
                            res = if res then res + speedTribe else speedTribe
                        end
                        return res
                    end)
                    userTree.Friends:SetDirty(true)
                    userTree:SetDirty(true)
                end
                if battleTree then
                    battleTree:SetDirty(true)
                end

                -- Update in-game model cache
                pcall(function()
                    local faModel = require(rs.UI.FriendAddition.Model.Friends)
                    faModel.OnlineCount = 9
                end)

                -- Update in-game UI items to Actived
                pcall(function()
                    local scroll = player.PlayerGui.MainUi.FriendsAddition.Content.Content.Middle.AdditionList.ScrollingFrame
                    for _, v in ipairs(scroll:GetChildren()) do
                        if v:IsA("Frame") and tonumber(v.Name) then
                            v.Right.NonActived.Visible = false
                            v.Right.Actived.Visible = true
                        end
                    end
                end)

                -- Hook proxies so any script checking friend count sees 9
                pcall(function()
                    local PropertyProxy = require(rs.Helpers.PropertyProxy)
                    if not PropertyProxy._origGetOnlineFriendsCount then
                        PropertyProxy._origGetOnlineFriendsCount = PropertyProxy.GetOnlineFriendsCount
                    end
                    PropertyProxy.GetOnlineFriendsCount = function(...)
                        if fakeFriendBonusActive then return 9 end
                        return PropertyProxy._origGetOnlineFriendsCount(...)
                    end
                end)

                pcall(function()
                    local fim = require(rs.Packages.FriendsInformationModule)
                    if not fim._origGetFriendsCount then
                        fim._origGetFriendsCount = fim.GetFriendsCount
                    end
                    fim.GetFriendsCount = function(...)
                        if fakeFriendBonusActive then return 9, 9 end
                        return fim._origGetFriendsCount(...)
                    end
                end)
            else
                -- Revert to normal game state
                local const = nil
                local WuKong = nil
                pcall(function()
                    const = require(rs.Packages.PropertyTribeTreeManager.const)
                    WuKong = require(rs.WuKong)
                end)

                if userTree and userTree.Friends then
                    userTree.Friends:ResetHandler(function()
                        local v1 = nil
                        local count = (WuKong and WuKong:ExecuteQuery("/Lua委托值/同服好友数量?获取缓存值")) or 0
                        if const then
                            for i = 1, count do
                                if MathManager.HasConfigPropertyTribe(const.Regions.Friends, i) then
                                    v1 = if v1 then v1 + MathManager.GetConfigPropertyTribe(const.Regions.Friends, i) else MathManager.GetConfigPropertyTribe(const.Regions.Friends, i)
                                end
                            end
                        end
                        if isSpeedHack and (speedPercentValue or 0) > 0 then
                            local speedTribe = PropertyTribe.new({
                                MoveSpeedRatio = (speedPercentValue or 50) / 100
                            })
                            v1 = if v1 then v1 + speedTribe else speedTribe
                        end
                        return v1
                    end)
                    userTree.Friends:SetDirty(true)
                    userTree:SetDirty(true)
                end
                if battleTree then
                    battleTree:SetDirty(true)
                end

                -- Revert UI
                pcall(function()
                    local WuKong = require(rs.WuKong)
                    local realCount = WuKong:ExecuteQuery("/Lua委托值/同服好友数量?获取缓存值") or 0
                    local faModel = require(rs.UI.FriendAddition.Model.Friends)
                    faModel.OnlineCount = realCount

                    local scroll = player.PlayerGui.MainUi.FriendsAddition.Content.Content.Middle.AdditionList.ScrollingFrame
                    for _, v in ipairs(scroll:GetChildren()) do
                        if v:IsA("Frame") and tonumber(v.Name) then
                            local isActive = tonumber(v.Name) <= realCount
                            v.Right.NonActived.Visible = not isActive
                            v.Right.Actived.Visible = isActive
                        end
                    end
                end)
            end
        end)
    end

    FriendBonusSec:AddToggle({
        Name = "Max Friend Bonus (All 9 Buffs)",
        Default = false,
        Callback = function(state)
            fakeFriendBonusActive = state
            applyFriendBonusState(state)
            if state then
                if not friendBonusCharConn then
                    friendBonusCharConn = player.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if fakeFriendBonusActive then
                            applyFriendBonusState(true)
                        end
                    end)
                end
                Notify("Moro Soul", "All 9 Friend Buffs Active (Speed, Souls, Luck, Draw, etc.)!", 3, "Success")
            else
                if friendBonusCharConn then
                    friendBonusCharConn:Disconnect()
                    friendBonusCharConn = nil
                end
                Notify("Moro Soul", "Friend Bonus Buffs Disabled", 2, "Info")
            end
        end
    })

    table.insert(cleanupHandlers, function()
        if fakeFriendBonusActive then
            applyFriendBonusState(false)
        end
        if friendBonusCharConn then
            pcall(function() friendBonusCharConn:Disconnect() end)
            friendBonusCharConn = nil
        end
    end)

    -- 4. Remote Summoner & Season Rewards
    local GachaSec = wrapSection(ExploitsTab:CreateSection({ Name = "Remote Gacha & Rewards", Collapsible = true }))

    GachaSec:AddButton({
        Name = "Summon Character (1x)",
        Primary = false,
        Callback = function()
            local drawRemote = remoteFolder:FindFirstChild("DrawRole")
            if drawRemote then
                drawRemote:FireServer(false)
                Notify("Moro Soul", "Remote Draw Executed!", 2, "Success")
            else
                Notify("Moro Soul", "DrawRole remote not found", 2, "Error")
            end
        end
    })

    local autoGacha = false
    GachaSec:AddToggle({
        Name = "Auto Remote Summon",
        Default = false,
        Callback = function(state)
            autoGacha = state
            if state then
                task.spawn(function()
                    local drawRemote = remoteFolder:FindFirstChild("DrawRole")
                    if not drawRemote then return end
                    while autoGacha do
                        drawRemote:FireServer(true)
                        task.wait(1.5)
                    end
                end)
                Notify("Moro Soul", "Auto Remote Summon Active!", 2, "Success")
            else
                Notify("Moro Soul", "Auto Remote Summon Disabled", 2, "Info")
            end
        end
    })

    GachaSec:AddButton({
        Name = "Claim Season Reward",
        Primary = false,
        Callback = function()
            local sr = remoteFolder:FindFirstChild("ReceiveSeasonReward")
            if sr then
                sr:FireServer()
                Notify("Moro Soul", "Claimed Season Reward!", 2, "Success")
            end
        end
    })

    GachaSec:AddButton({
        Name = "Claim Season Top 3 Reward",
        Primary = false,
        Callback = function()
            local s3 = remoteFolder:FindFirstChild("ReceiveSeasonTop3Reward")
            if s3 then
                s3:FireServer()
                Notify("Moro Soul", "Claimed Season Top 3 Reward!", 2, "Success")
            end
        end
    })

    -- 5. Visual Exploits
    local VisualSec = wrapSection(ExploitsTab:CreateSection({ Name = "Visual Exploits", Collapsible = true }))

    VisualSec:AddButton({
        Name = "Full Bright / Night Vision",
        Primary = false,
        Callback = function()
            lighting.Ambient = Color3.fromRGB(255, 255, 255)
            lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
            lighting.Brightness = 2
            lighting.ClockTime = 14
            lighting.FogEnd = 1e5
            lighting.GlobalShadows = false
            Notify("Moro Soul", "Full Bright Activated!", 2, "Success")
        end
    })
    end

    -- =====================================================================
    --                           SETTINGS TAB (Custom Extras)
    -- =====================================================================
    do
        SettingsTab:Column("right")

        local GameOptSec = wrapSection(SettingsTab:CreateSection({ Name = "Game Optimizations", Collapsible = true }))

        GameOptSec:AddButton({
            Name = "FPS Booster (Ultra)",
            Primary = true,
            Callback = function()
                local terrain = workspace:FindFirstChildOfClass("Terrain")
                if terrain then
                    terrain.WaterWaveSize = 0
                    terrain.WaterWaveSpeed = 0
                    terrain.WaterReflectance = 0
                    terrain.WaterTransparency = 0
                end
                
                lighting.GlobalShadows = false
                lighting.FogEnd = 9e9
                lighting.Brightness = 1
                
                for _, obj in ipairs(lighting:GetChildren()) do
                    if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") 
                    or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
                        obj.Enabled = false
                    end
                end
            
                pcall(function()
                    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                end)
                
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        obj.Material = Enum.Material.Plastic
                        obj.Reflectance = 0
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        obj.Transparency = 1
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                        obj.Enabled = false
                    elseif obj:IsA("Explosion") then
                        obj.Visible = false
                    end
                end
                
                Notify("Moro Soul", "FPS Has Been Boosted!", 2, "Success")
            end
        })

        GameOptSec:AddToggle({
            Name = "Animation Cancel",
            Default = false,
            Callback = function(state)
                animCancel = state
            end
        })

        GameOptSec:AddToggle({
            Name = "Auto Reconnect",
            Default = true,
            Callback = function(state)
                autoReconnectEnabled = state
            end
        })
    end

    Notify("Moro Soul", "Script Loaded Successfully (Lumina UI)!", 3, "Success")
end
