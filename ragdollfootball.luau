if getgenv().CrystalHub then
    if CrystalHub.ConnectionController and CrystalHub.ConnectionController.Connections then
        for i, v in next, CrystalHub.ConnectionController.Connections do
            pcall(function() v:Disconnect() end)
            CrystalHub.ConnectionController.Connections[i] = nil
        end
    end
    if CrystalHub.TasksController and CrystalHub.TasksController.Tasks then
        for i, v in next, CrystalHub.TasksController.Tasks do
            pcall(function() task.cancel(v) end)
            CrystalHub.TasksController.Tasks[i] = nil
        end
    end
    pcall(function()
        for _, sg in ipairs(cloneref(game:GetService("CoreGui")):GetChildren()) do
            if sg.Name == "Blossom" then sg:Destroy() end
        end
    end)
    getgenv().CrystalHub = nil
    task.wait(0.2)
end

local CURRENT_VERSION = "v1.1.7"

local Services = setmetatable({}, {
    __index = function(self, Index)
        local service = cloneref(game:GetService(Index))
        rawset(self, Index, service)
        return service
    end
})

local Players = Services.Players
local RunService = Services.RunService
local LocalPlayer = Players.LocalPlayer

getgenv().CrystalHub = {
    Meta = {
        Version = CURRENT_VERSION,
        ServerName = "CrystalHub",
    },

    PlayerController = {
        Player = LocalPlayer,
        PlayerGui = LocalPlayer.PlayerGui,
    },

    UIController = {
        Window = nil,
        Tabs = {},
    },

    ConnectionController = {
        Connections = {},
    },

    TasksController = {
        Tasks = {},
    },

    Functions = {},
}

function CrystalHub.ConnectionController.Insert(Connection)
    table.insert(CrystalHub.ConnectionController.Connections, Connection)
end

function CrystalHub.TasksController.Insert(Task)
    table.insert(CrystalHub.TasksController.Tasks, Task)
end

getgenv().CrystalSilentAim = getgenv().CrystalSilentAim or { Enabled = false, Hooked = false }
getgenv().CrystalMaxPower = getgenv().CrystalMaxPower or { Enabled = false, Hooked = false }
local SilentAimState = getgenv().CrystalSilentAim
if SilentAimState.OnlyGoalShots == nil then SilentAimState.OnlyGoalShots = true end

function CrystalHub.Functions.InstallMaxPower()
    local MP = getgenv().CrystalMaxPower
    if MP.Hooked then return true end
    local ok, Rules = pcall(function()
        return require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Kick")).Rules
    end)
    if not ok or type(Rules) ~= "table" or type(Rules.charge) ~= "function" then return false end
    local orig
    local function wrapper(value)
        local state = getgenv().CrystalMaxPower
        if state and state.Enabled then return 1 end
        return orig(value)
    end
    if hookfunction then
        orig = hookfunction(Rules.charge, wrapper)
        MP.Hooked = true
    elseif setreadonly then
        orig = Rules.charge
        setreadonly(Rules, false)
        Rules.charge = wrapper
        setreadonly(Rules, true)
        MP.Hooked = true
    end
    return MP.Hooked == true
end

getgenv().CrystalReach = getgenv().CrystalReach or { Enabled = false, Add = 3 }
getgenv().CrystalReach.Enabled = false
getgenv().CrystalAntiRagdoll = getgenv().CrystalAntiRagdoll or {}
getgenv().CrystalAntiRagdoll.Enabled = false
getgenv().CrystalAntiRagdoll.Tackle = false
getgenv().CrystalAntiRagdoll.GetUp = false
getgenv().CrystalAntiRagdoll.Running = false

function CrystalHub.Functions.InstallAntiRagdoll()
    local AR = getgenv().CrystalAntiRagdoll
    if AR.Hooked2 then return true end
    local mod = CrystalHub.Functions.MannequinClientModule()
    if not mod then return false end
    local okT, Tuning = pcall(function()
        return require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MannequinAnimation"):WaitForChild("Tuning"))
    end)
    if okT and type(Tuning) == "table" and type(Tuning.Slide) == "table" then
        AR.Tuning = Tuning
        AR.SitDefault = AR.SitDefault or Tuning.Slide.SitTime
    end
    AR.Hooked = true
    AR.Hooked2 = true
    return true
end

function CrystalHub.Functions.RecoveredRemote()
    local AR = getgenv().CrystalAntiRagdoll
    if AR.Remote then return AR.Remote end
    local ok, remote = pcall(function()
        local Net = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
        return Net:RemoteEvent("MannequinRecovered")
    end)
    if ok and remote then
        AR.Remote = remote
        return remote
    end
    return nil
end

function CrystalHub.Functions.InstantRecover(body)
    local AR = getgenv().CrystalAntiRagdoll
    local remote = CrystalHub.Functions.RecoveredRemote()
    if not body.mrWrapped then
        body.mrWrapped = true
        body.mrOrig = body.onRecovered
        body.onRecovered = function()
            if not remote then return end
            local wait = 0.65 - (os.clock() - (body.physicalAt or 0))
            if wait <= 0 then
                pcall(function() remote:FireServer() end)
            else
                task.delay(wait, function()
                    if not body.active then
                        pcall(function() remote:FireServer() end)
                    end
                end)
            end
        end
    end
    local mode = body.mode
    if mode == "Fall" or mode == "KickFall" or mode == "FrontFall" or mode == "Slide" then
        body.yaw = AR.Yaw or body.yaw or 0
    end
    body.pending = nil
    body.launch = nil
    body.fromKick = nil
    body.fromFront = nil
    body.seatPending = false
    body.driveOff = nil
    body.reseatPending = true
    local ok = pcall(body.reseat, body)
    if not ok then
        pcall(body.standNow, body)
    end
    if body.active then
        pcall(body.standNow, body)
    end
end

function CrystalHub.Functions.StopBallKeep()
    pcall(function() RunService:UnbindFromRenderStep("CrystalBallKeep") end)
end

function CrystalHub.Functions.StartBallKeep()
    CrystalHub.Functions.StopBallKeep()
    local AR = getgenv().CrystalAntiRagdoll
    local st = { Had = 0 }
    RunService:BindToRenderStep("CrystalBallKeep", Enum.RenderPriority.Input.Value + 9, function()
        if not AR.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local id = char:GetAttribute("DribbleId")
        if type(id) ~= "number" or id == 0 then return end
        local ball = CrystalHub.Functions.GetBall()
        if not ball then return end
        local now = os.clock()
        if ball:GetAttribute("Possessor") == id then
            st.Had = now
            return
        end
        if now - st.Had > 1.5 then return end
        if CrystalHub.TrickActive or now < (CrystalHub.ShotNext or 0) then return end
        local vel = ball.AssemblyLinearVelocity
        if Vector3.new(vel.X, 0, vel.Z).Magnitude > 40 then
            st.Had = 0
            return
        end
        local bodyState = char:GetAttribute("BodyState")
        if bodyState ~= nil and bodyState ~= "Animated" then return end
        local root = char:FindFirstChild("Root")
        local cm = char:FindFirstChildOfClass("ControllerManager")
        if not (root and cm) then return end
        local dx = ball.Position.X + vel.X * 0.12 - root.Position.X
        local dz = ball.Position.Z + vel.Z * 0.12 - root.Position.Z
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance > 45 or distance < 1.2 then return end
        local direction = Vector3.new(dx / distance, 0, dz / distance)
        cm.MovingDirection = direction
        cm.BaseMoveSpeed = math.max(cm.BaseMoveSpeed, 31)
        cm.FacingDirection = direction
    end)
end

function CrystalHub.Functions.StopAntiRagdoll()
    pcall(function() RunService:UnbindFromRenderStep("CrystalAntiRagdoll") end)
    CrystalHub.Functions.StopBallKeep()
    getgenv().CrystalAntiRagdoll.Running = false
    pcall(function()
        local mod = CrystalHub.MannequinClientRef
        local char = LocalPlayer.Character
        local animator = mod and char and mod.getAnimator(char)
        local body = animator and animator.body
        if body then
            if body.mrWrapped then
                body.onRecovered = body.mrOrig
                body.mrWrapped = nil
                body.mrOrig = nil
            end
            if body.mrTackleFn and body.onTackle == body.mrTackleFn then
                body.onTackle = body.mrTackleOrig
            end
            body.mrTackleFn = nil
            body.mrTackleOrig = nil
            body.mrHit = nil
            body.mrHitAt = nil
        end
    end)
end

function CrystalHub.Functions.StartAntiRagdoll()
    local F = CrystalHub.Functions
    F.StopAntiRagdoll()
    local mod = F.MannequinClientModule()
    if not mod then return false end
    local AR = getgenv().CrystalAntiRagdoll
    F.StartBallKeep()
    local cachedChar, cachedAnimator
    RunService:BindToRenderStep("CrystalAntiRagdoll", Enum.RenderPriority.Input.Value + 6, function()
        if not AR.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local animator = cachedAnimator
        if char ~= cachedChar or not animator or not animator.body then
            local ok, result = pcall(mod.getAnimator, char)
            if not ok or not result then return end
            cachedChar, cachedAnimator = char, result
            animator = result
        end
        local body = animator.body
        if not body then return end
        if not body.active then
            local root = char:FindFirstChild("Root")
            if root then
                local look = root.CFrame.LookVector
                if look.X * look.X + look.Z * look.Z > 0.000001 then
                    AR.Yaw = math.atan2(-look.X, -look.Z)
                end
            end
            return
        end
        local mode = body.mode
        local now = os.clock()
        if mode == "Slide" or mode == "Dive" or mode == "Block" or mode == "KeyDive" then
            AR.OwnAt = now
            if mode ~= "Slide" or not AR.GetUp then return end
            local t = body.t or 0
            local hit = body.tackled ~= nil and next(body.tackled) ~= nil
            if t < 0.2 then return end
            if not (hit or body.slideEnd ~= nil or t >= 0.3) then return end
            F.InstantRecover(body)
            return
        end
        if not AR.Tackle then return end
        if now - (AR.OwnAt or -math.huge) < 0.6 then return end
        F.InstantRecover(body)
    end)
    CrystalHub.ConnectionController.Insert({ Disconnect = function()
        CrystalHub.Functions.StopAntiRagdoll()
    end })
    AR.Running = true
    return true
end

function CrystalHub.Functions.RefreshAntiRagdoll()
    local F = CrystalHub.Functions
    local AR = getgenv().CrystalAntiRagdoll
    AR.Enabled = AR.Tackle == true or AR.GetUp == true
    local T = AR.Tuning
    if T and T.Slide and AR.SitDefault then
        T.Slide.SitTime = AR.GetUp and 0.02 or AR.SitDefault
    end
    if AR.Enabled then
        if not AR.Running then
            F.StartAntiRagdoll()
        end
    elseif AR.Running then
        F.StopAntiRagdoll()
    end
end

function CrystalHub.Functions.SetAntiTackle(state)
    getgenv().CrystalAntiRagdoll.Tackle = state == true
    CrystalHub.Functions.RefreshAntiRagdoll()
end

function CrystalHub.Functions.SetInstantGetUp(state)
    getgenv().CrystalAntiRagdoll.GetUp = state == true
    CrystalHub.Functions.RefreshAntiRagdoll()
end

getgenv().CrystalNoCooldown = getgenv().CrystalNoCooldown or { Enabled = false }

function CrystalHub.Functions.StopNoCooldown()
    local NC = getgenv().CrystalNoCooldown
    if NC.Conns then
        for _, c in ipairs(NC.Conns) do
            pcall(function() c:Disconnect() end)
        end
        NC.Conns = nil
    end
    if NC.Tuning and NC.SlideDefault then
        NC.Tuning.Slide.Cooldown = NC.SlideDefault
    end
end

function CrystalHub.Functions.StartNoCooldown()
    CrystalHub.Functions.StopNoCooldown()
    local NC = getgenv().CrystalNoCooldown
    local ok, tuning = pcall(function()
        return require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MannequinAnimation"):WaitForChild("Tuning"))
    end)
    if ok and type(tuning) == "table" and type(tuning.Slide) == "table" then
        NC.Tuning = tuning
        NC.SlideDefault = NC.SlideDefault or tuning.Slide.Cooldown
        tuning.Slide.Cooldown = 0
    end
    local conns = {}
    NC.Conns = conns
    for _, name in ipairs({ "SlideReadyAt", "SlideCooldown", "PokeReadyAt" }) do
        local function clear()
            if not NC.Enabled then return end
            local v = LocalPlayer:GetAttribute(name)
            if v ~= nil and v ~= 0 then
                LocalPlayer:SetAttribute(name, 0)
            end
        end
        conns[#conns + 1] = LocalPlayer:GetAttributeChangedSignal(name):Connect(clear)
        clear()
    end
    CrystalHub.ConnectionController.Insert({ Disconnect = function()
        CrystalHub.Functions.StopNoCooldown()
    end })
    return true
end

getgenv().CrystalAutoPoke = getgenv().CrystalAutoPoke or { Enabled = false, Range = 6 }

function CrystalHub.Functions.GetPokeAction()
    local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local context = scripts and scripts:FindFirstChild("Poke")
    local action = context and context:FindFirstChild("Poke")
    if action and action:IsA("InputAction") then
        return action
    end
    return nil
end

function CrystalHub.Functions.FirePoke()
    local action = CrystalHub.Functions.GetPokeAction()
    if not action then return false end
    local binding = CrystalHub.PokeBinding
    if not (binding and binding.Parent == action) then
        if binding then
            pcall(function() binding:Destroy() end)
        end
        binding = Instance.new("InputBinding")
        binding.Name = "CrystalPoke"
        binding.Type = Enum.InputBindingType.Scriptable
        binding.Parent = action
        CrystalHub.PokeBinding = binding
        CrystalHub.ConnectionController.Insert({ Disconnect = function()
            pcall(function() binding:Destroy() end)
            CrystalHub.PokeBinding = nil
        end })
    end
    binding:Fire(true)
    task.delay(0.05, function()
        pcall(function() binding:Fire(false) end)
    end)
    return true
end

function CrystalHub.Functions.FindPokeTarget()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("Root")
    if not root then return nil end
    local ball = CrystalHub.Functions.GetBall()
    if not ball then return nil end
    local possessor = ball:GetAttribute("Possessor")
    local ownId = char:GetAttribute("DribbleId")
    if type(possessor) ~= "number" or possessor == 0 or possessor == ownId then return nil end
    local myTeam = char:GetAttribute("Team")
    for _, model in ipairs(Services.CollectionService:GetTagged("MannequinCharacter")) do
        if model ~= char and model:IsA("Model") and model:GetAttribute("DribbleId") == possessor then
            local team = model:GetAttribute("Team")
            if myTeam ~= nil and team == myTeam then return nil end
            local otherRoot = model:FindFirstChild("Root")
            if not (otherRoot and otherRoot:IsA("BasePart")) then return nil end
            local bodyState = model:GetAttribute("BodyState")
            if bodyState ~= nil and bodyState ~= "Animated" then return nil end
            local diff = otherRoot.Position - root.Position
            return model, Vector3.new(diff.X, 0, diff.Z).Magnitude
        end
    end
    return nil
end

function CrystalHub.Functions.IsTouch()
    local UIS = Services.UserInputService
    return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

function CrystalHub.Functions.ReleaseAllBindings()
    local B = CrystalHub.Bindings
    if B then
        for _, b in pairs(B) do
            pcall(function() b:Fire(false) end)
        end
    end
    local AS = CrystalHub.AutoShoot
    if AS and AS.Binding then
        pcall(function() AS.Binding:Fire(false) end)
    end
    local AP = CrystalHub.AutoPoke
    if AP and AP.Binding then
        pcall(function() AP.Binding:Fire(false) end)
    end
    CrystalHub.TrickActive = false
    CrystalHub.ShotNext = 0
    local V = CrystalHub.TrickView
    if V then V.Active = false end
    local F = CrystalHub.Force
    if F then F.Until = 0 end
end

function CrystalHub.Functions.PokeOpportunity(target, range)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("Root")
    local cm = char and char:FindFirstChildOfClass("ControllerManager")
    if not (root and cm and target) then return false end
    local gc = cm:FindFirstChild("GroundController")
    if not gc or cm.ActiveController ~= gc then return false end
    local ball = CrystalHub.Functions.GetBall()
    if not ball or ball:GetAttribute("Possessor") ~= target:GetAttribute("DribbleId") then return false end
    local bp, bv = ball.Position, ball.AssemblyLinearVelocity
    local view = CrystalHub.Functions.ClientModule("BallView")
    if view and type(view.freeState) == "function" then
        local ok, pos, vel = pcall(view.freeState)
        if ok and typeof(pos) == "Vector3" and typeof(vel) == "Vector3" then
            bp, bv = pos, vel
        end
    end
    local aim = bp + Vector3.new(bv.X, 0, bv.Z) * 0.14 - root.Position
    local flat = Vector3.new(aim.X, 0, aim.Z)
    local dist = flat.Magnitude
    if dist < 0.8 or dist > math.min(range, 7.2) then return false end
    local look = root.CFrame.LookVector
    local face = Vector3.new(look.X, 0, look.Z)
    if face.Magnitude < 0.01 or face.Unit:Dot(flat.Unit) < -0.05 then return false end
    if math.abs(bp.Y - root.Position.Y) > 5 then return false end
    return true
end

function CrystalHub.Functions.StopAutoPoke()
    local state = CrystalHub.AutoPoke
    CrystalHub.AutoPoke = nil
    if state then
        if state.Conn then
            pcall(function() state.Conn:Disconnect() end)
        end
        if state.Binding then
            pcall(function() state.Binding:Fire(false) end)
            pcall(function() state.Binding:Destroy() end)
        end
    end
end

function CrystalHub.Functions.StartAutoPoke()
    local F = CrystalHub.Functions
    F.StopAutoPoke()
    local st = { Acc = 0, Next = 0, Target = nil, Seen = 0 }
    CrystalHub.AutoPoke = st
    st.Conn = RunService.Heartbeat:Connect(function(dt)
        st.Acc += dt
        if st.Acc < 0.075 then return end
        st.Acc = 0
        local cfg = getgenv().CrystalAutoPoke
        if not cfg.Enabled then return end
        local now = os.clock()
        if now < st.Next then return end
        local char = LocalPlayer.Character
        if not char or F.MatchPaused(char) then return end
        local bodyState = char:GetAttribute("BodyState")
        if bodyState ~= nil and bodyState ~= "Animated" then return end
        if CrystalHub.TrickActive or now < (CrystalHub.ShotNext or 0) then return end
        local readyAt = LocalPlayer:GetAttribute("PokeReadyAt")
        if type(readyAt) == "number" and readyAt > workspace:GetServerTimeNow() + 0.03 then return end
        local target, distance = F.FindPokeTarget()
        if not target or not distance or distance > math.min(cfg.Range + 1, 9) then
            st.Target, st.Seen = nil, 0
            return
        end
        if st.Target ~= target then
            st.Target, st.Seen = target, now
            return
        end
        if now - st.Seen < 0.09 or not F.PokeOpportunity(target, cfg.Range) then return end
        local ok, fired = pcall(F.FirePoke)
        st.Next = now + ((ok and fired) and 0.75 or 0.25)
        if ok and fired then st.Seen = now + 0.3 end
    end)
    CrystalHub.ConnectionController.Insert(st.Conn)
    return true
end

getgenv().CrystalSprint = getgenv().CrystalSprint or { Infinite = false, Auto = false }

function CrystalHub.Functions.MannequinClientModule()
    local cached = CrystalHub.MannequinClientRef
    if cached then return cached end
    local ok, mod = pcall(function()
        return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Game"):WaitForChild("MannequinClient"))
    end)
    if ok and type(mod) == "table" then
        CrystalHub.MannequinClientRef = mod
        return mod
    end
    return nil
end

function CrystalHub.Functions.StopAutoSprint()
    local state = CrystalHub.AutoSprint
    CrystalHub.AutoSprint = nil
    if state and state.Restore then
        state.Restore()
    end
end

function CrystalHub.Functions.StartAutoSprint()
    CrystalHub.Functions.StopAutoSprint()
    local mod = CrystalHub.Functions.MannequinClientModule()
    if not mod then return false end
    local state = { Original = mod.keepSprint, Move = nil, Cached = true, At = 0 }

    local function moving()
        local now = os.clock()
        if now - state.At < 0.05 then return state.Cached end
        state.At = now
        if not (state.Move and state.Move.Parent) then
            local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
            local ctx = scripts and scripts:FindFirstChild("Mannequin")
            state.Move = ctx and ctx:FindFirstChild("Move")
        end
        if not state.Move then
            state.Cached = true
            return true
        end
        local ok, s = pcall(state.Move.GetState, state.Move)
        state.Cached = ok and typeof(s) == "Vector2" and s.Magnitude > 0.1
        return state.Cached
    end

    local function wrapper(...)
        if getgenv().CrystalSprint.Auto and moving() then
            return true
        end
        local original = state.Original
        if original then
            return original(...)
        end
        return false
    end

    local function restore()
        if state.Conn then
            pcall(function() state.Conn:Disconnect() end)
            state.Conn = nil
        end
        if mod.keepSprint == wrapper then
            mod.keepSprint = state.Original
        end
    end

    state.Restore = restore
    mod.keepSprint = wrapper
    local acc = 0
    state.Conn = RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.5 then return end
        acc = 0
        if mod.keepSprint ~= wrapper then
            state.Original = mod.keepSprint
            mod.keepSprint = wrapper
        end
    end)
    CrystalHub.AutoSprint = state
    CrystalHub.ConnectionController.Insert(state.Conn)
    CrystalHub.ConnectionController.Insert({ Disconnect = restore })
    return true
end

function CrystalHub.Functions.StopInfiniteSprint()
    CrystalHub.RunSpeedBound = nil
    pcall(function() RunService:UnbindFromRenderStep("CrystalRunSpeed") end)
end

function CrystalHub.Functions.StartInfiniteSprint()
    local F = CrystalHub.Functions
    F.StopInfiniteSprint()
    CrystalHub.RunSpeedBound = true
    local speed = F.SprintBase()
    local cfg = getgenv().CrystalSprint
    local char, cm
    RunService:BindToRenderStep("CrystalRunSpeed", Enum.RenderPriority.Input.Value + 5, function()
        local boost = cfg.Boost or 1
        if not (cfg.Infinite or boost > 1) then return end
        local current = LocalPlayer.Character
        if current ~= char or not (cm and cm.Parent) then
            char = current
            cm = char and char:FindFirstChildOfClass("ControllerManager")
        end
        if not cm then return end
        local bodyState = char:GetAttribute("BodyState")
        if bodyState ~= nil and bodyState ~= "Animated" then return end
        local dir = cm.MovingDirection
        if dir.X * dir.X + dir.Y * dir.Y + dir.Z * dir.Z < 0.0025 then return end
        local currentSpeed = cm.BaseMoveSpeed
        local base = currentSpeed
        if cfg.Infinite and base < speed then
            base = speed
        end
        if boost > 1 and base >= speed * 0.85 then
            local target = speed * boost
            if base < target then base = target end
        end
        if base ~= currentSpeed then
            cm.BaseMoveSpeed = base
        end
    end)
    CrystalHub.ConnectionController.Insert({ Disconnect = function()
        CrystalHub.Functions.StopInfiniteSprint()
    end })
end

function CrystalHub.Functions.RefreshRunSpeed()
    local cfg = getgenv().CrystalSprint
    if cfg.Infinite or (cfg.Boost or 1) > 1 then
        if not CrystalHub.RunSpeedBound then
            CrystalHub.Functions.StartInfiniteSprint()
        end
    else
        CrystalHub.Functions.StopInfiniteSprint()
    end
end

function CrystalHub.Functions.SilentAimModules()
    local SA = getgenv().CrystalSilentAim
    if SA.BallView and SA.Flight and SA.Families then return true end
    pcall(function()
        local gameFolder = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Game")
        SA.BallView = require(gameFolder:WaitForChild("BallView"))
    end)
    pcall(function()
        local sharedGame = Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
        local Kick = require(sharedGame:WaitForChild("Kick"))
        SA.Flight = Kick.Flight
        SA.Families = Kick.Families
        SA.KeeperRules = require(sharedGame:WaitForChild("KeeperRules"))
    end)
    return SA.BallView ~= nil and SA.Flight ~= nil and SA.Families ~= nil
end

function CrystalHub.Functions.SilentAimGoalCompute()
    local SA = getgenv().CrystalSilentAim
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("Root")
    local goals = {}
    for _, part in ipairs(Services.CollectionService:GetTagged("SoccerGoalFrame")) do
        if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
            table.insert(goals, part)
        end
    end
    if #goals < 2 then return nil end
    table.sort(goals, function(a, b) return a.Position.X < b.Position.X end)
    local team = char and char:GetAttribute("Team")
    local hasTeam = team == "Blue" or team == "Red"
    local chosen
    if hasTeam and SA.KeeperRules then
        local ok, side, area = pcall(function()
            return SA.KeeperRules.ownSide(team), SA.KeeperRules.area(team)
        end)
        if ok and side and area then
            for _, part in ipairs(goals) do
                if (part.Position.X - area.centre.X) * -side > 0 then
                    chosen = part
                    break
                end
            end
        end
    end
    if not chosen and hasTeam then
        local blueSide = workspace:GetAttribute("BlueSide") == 1 and 1 or -1
        local out = team == "Blue" and -blueSide or blueSide
        chosen = out == -1 and goals[1] or goals[#goals]
    end
    if not chosen and root then
        local look = root.CFrame.LookVector
        local bestDot = -math.huge
        for _, part in ipairs(goals) do
            local d = (part.Position.X - root.Position.X) * look.X
            if d > bestDot then
                bestDot = d
                chosen = part
            end
        end
    end
    if not chosen then return nil end
    local b = chosen.Position.X < (goals[1].Position.X + goals[#goals].Position.X) / 2 and -1 or 1
    local q = chosen.Size.Y / 9.142857142857142
    local ground = chosen.Position.Y - chosen.Size.Y / 2
    return {
        x = chosen.Position.X - b * chosen.Size.X / 2 + b * 0.21428571428571425 * q,
        z = chosen.Position.Z,
        ground = ground,
        top = ground + 8.714285714285714 * q,
        half = 13.071428571428571 * q,
        out = b,
        team = hasTeam and team or nil,
        char = char,
    }
end

function CrystalHub.Functions.Budget(seconds)
    local touch = CrystalHub.IsTouchCached
    if touch == nil then
        touch = CrystalHub.Functions.IsTouch()
        CrystalHub.IsTouchCached = touch
    end
    return touch and seconds * 0.5 or seconds
end

function CrystalHub.Functions.MannequinSnapshot()
    local snap = CrystalHub.MannequinSnap
    local now = os.clock()
    if snap and now - snap.At < 0.15 then
        return snap.List
    end
    local list = {}
    local n = 0
    for _, model in ipairs(Services.CollectionService:GetTagged("MannequinCharacter")) do
        local root = model:FindFirstChild("Root")
        if root and model:IsA("Model") and root:IsA("BasePart") then
            n += 1
            list[n] = {
                model = model,
                team = model:GetAttribute("Team"),
                keeper = model:GetAttribute("AIGoalie") ~= nil or model:GetAttribute("Role") == "Goalkeeper",
                pos = root.Position,
            }
        end
    end
    CrystalHub.MannequinSnap = { At = now, List = list }
    return list
end

function CrystalHub.Functions.SilentAimGoal()
    local cache = CrystalHub.GoalCache
    if not cache then
        cache = { At = 0, Valid = false }
        CrystalHub.GoalCache = cache
    end
    local char = LocalPlayer.Character
    local team = char and char:GetAttribute("Team")
    local now = os.clock()
    if cache.Valid and cache.Char == char and cache.Team == team and now - cache.At < 0.5 then
        return cache.Value
    end
    cache.Value = CrystalHub.Functions.SilentAimGoalCompute()
    cache.Char = char
    cache.Team = team
    cache.At = now
    cache.Valid = true
    return cache.Value
end

function CrystalHub.Functions.SetQuickInteract(state)
    local backup = CrystalHub.PromptBackup
    if not backup then
        backup = setmetatable({}, { __mode = "k" })
        CrystalHub.PromptBackup = backup
    end
    if CrystalHub.QuickInteractConn then
        CrystalHub.QuickInteractConn:Disconnect()
        CrystalHub.QuickInteractConn = nil
    end
    if state then
        CrystalHub.QuickInteractConn = Services.ProximityPromptService.PromptShown:Connect(function(prompt)
            if not backup[prompt] then
                backup[prompt] = { hold = prompt.HoldDuration, line = prompt.RequiresLineOfSight }
            end
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
        end)
    else
        for prompt, orig in pairs(backup) do
            pcall(function()
                prompt.HoldDuration = orig.hold
                prompt.RequiresLineOfSight = orig.line
            end)
        end
        table.clear(backup)
    end
end

getgenv().CrystalAutoShoot  = getgenv().CrystalAutoShoot  or { Enabled = false, Range = 60 }
getgenv().CrystalAutoPickup = getgenv().CrystalAutoPickup or { Enabled = false, Range = 25 }

function CrystalHub.Functions.GetBall()
    local ball = CrystalHub.BallRef
    if ball and ball.Parent then return ball end
    ball = Services.CollectionService:GetTagged("SoccerBall")[1]
    CrystalHub.BallRef = ball
    return ball
end

function CrystalHub.Functions.GetKickAction(name)
    local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local context = scripts and scripts:FindFirstChild("Kick")
    local action = context and context:FindFirstChild(name or "KickStrike")
    if action and action:IsA("InputAction") then
        return action
    end
    return nil
end

function CrystalHub.Functions.StopAutoShoot()
    if not getgenv().CrystalAutoTricks.Enabled then
        CrystalHub.Functions.AutoEngineStop()
    end
end

function CrystalHub.Functions.StartAutoShoot()
    CrystalHub.Functions.AutoEngineStart()
end

function CrystalHub.Functions.StopAutoPickup()
    local st = CrystalHub.AutoPickup
    CrystalHub.AutoPickup = nil
    if st and st.Gate then
        pcall(function() st.Gate:Disconnect() end)
    end
    pcall(function() RunService:UnbindFromRenderStep("CrystalAutoPickup") end)
end

function CrystalHub.Functions.StartAutoPickup()
    CrystalHub.Functions.StopAutoPickup()
    local cfg = getgenv().CrystalAutoPickup
    local st = { Acc = 0, Active = false }
    CrystalHub.AutoPickup = st
    st.Gate = RunService.Heartbeat:Connect(function(dt)
        st.Acc += dt
        if st.Acc < 0.08 then return end
        st.Acc = 0
        st.Active = false
        if not cfg.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local team = char:GetAttribute("Team")
        if team ~= "Blue" and team ~= "Red" then return end
        local bodyState = char:GetAttribute("BodyState")
        if bodyState ~= nil and bodyState ~= "Animated" then return end
        local now = workspace:GetServerTimeNow()
        local hold = LocalPlayer:GetAttribute("KickoffHold")
        if type(hold) == "number" and hold > now then return end
        if CrystalHub.TrickActive or os.clock() < (CrystalHub.ShotNext or 0) then return end
        local ball = CrystalHub.Functions.GetBall()
        if not ball then return end
        local possessor = ball:GetAttribute("Possessor")
        if type(possessor) == "number" and possessor ~= 0 then return end
        local id = char:GetAttribute("DribbleId")
        if ball:GetAttribute("ReleasedBy") == id then
            local releasedAt = ball:GetAttribute("ReleasedAt")
            if type(releasedAt) == "number" and now - releasedAt < 1.2 then return end
        end
        local root = char:FindFirstChild("Root")
        local cm = char:FindFirstChildOfClass("ControllerManager")
        if not (root and cm) then return end
        st.Root, st.Cm, st.Ball = root, cm, ball
        st.Active = true
    end)
    RunService:BindToRenderStep("CrystalAutoPickup", Enum.RenderPriority.Input.Value + 8, function()
        if not st.Active then return end
        local root, cm, ball = st.Root, st.Cm, st.Ball
        if not (root.Parent and cm.Parent and ball.Parent) then
            st.Active = false
            return
        end
        local possessor = ball:GetAttribute("Possessor")
        if type(possessor) == "number" and possessor ~= 0 then
            st.Active = false
            return
        end
        local ballPos = ball.Position
        local rootPos = root.Position
        if ballPos.Y > rootPos.Y - 2.4 then return end
        local vel = ball.AssemblyLinearVelocity
        if math.abs(vel.Y) > 8 then return end
        local vx, vz = vel.X, vel.Z
        if vx * vx + vz * vz > 900 then return end
        local dx = ballPos.X + vx * 0.12 - rootPos.X
        local dz = ballPos.Z + vz * 0.12 - rootPos.Z
        local distance = math.sqrt(dx * dx + dz * dz)
        if distance > cfg.Range or distance < 1.4 then return end
        local direction = Vector3.new(dx / distance, 0, dz / distance)
        cm.MovingDirection = direction
        cm.BaseMoveSpeed = math.max(cm.BaseMoveSpeed, 20)
        cm.FacingDirection = direction
    end)
    CrystalHub.ConnectionController.Insert({ Disconnect = function() CrystalHub.Functions.StopAutoPickup() end })
end

getgenv().CrystalGuard = getgenv().CrystalGuard or { Enabled = false, Distance = 8, Predict = 0.35 }
getgenv().CrystalGuard.IgnoreTeammates = true

function CrystalHub.Functions.GuardOwnGoal()
    local G = CrystalHub.GuardGoal
    local now = os.clock()
    if G and now - G.At < 1 then
        return G.Value
    end
    local stale = G and now - G.At < 10 and G.Value or nil
    local attacked = CrystalHub.Functions.SilentAimGoal()
    if not attacked then return stale end
    local far, farPart = -1, nil
    for _, part in ipairs(Services.CollectionService:GetTagged("SoccerGoalFrame")) do
        if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
            local d = math.abs(part.Position.X - attacked.x)
            if d > far then
                far = d
                farPart = part
            end
        end
    end
    if not farPart then return stale end
    local value = Vector3.new(farPart.Position.X, 0, farPart.Position.Z)
    CrystalHub.GuardGoal = { At = now, Value = value }
    return value
end

function CrystalHub.Functions.StopGuard()
    pcall(function() RunService:UnbindFromRenderStep("CrystalGuard") end)
    local st = CrystalHub.GuardState
    CrystalHub.GuardState = nil
    if st then
        if st.Gate then
            pcall(function() st.Gate:Disconnect() end)
        end
        if st.Controlling and st.Cm and st.Cm.Parent then
            pcall(function() st.Cm.MovingDirection = Vector3.zero end)
        end
    end
end

function CrystalHub.Functions.ClientModule(name)
    local H = CrystalHub
    local cache = H.ClientModules
    if not cache then
        cache = {}
        H.ClientModules = cache
    end
    local cached = cache[name]
    if cached ~= nil then return cached or nil end
    local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local client = scripts and scripts:FindFirstChild("Client")
    local folder = client and client:FindFirstChild("Game")
    local inst = folder and folder:FindFirstChild(name)
    if not (inst and inst:IsA("ModuleScript")) then return nil end
    local ok, mod = pcall(require, inst)
    cache[name] = (ok and type(mod) == "table") and mod or false
    return cache[name] or nil
end

function CrystalHub.Functions.StopBallReach()
    pcall(function() RunService:UnbindFromRenderStep("CrystalBallReach") end)
    local st = CrystalHub.BallReachState
    CrystalHub.BallReachState = nil
    if st and st.Gate then
        pcall(function() st.Gate:Disconnect() end)
    end
end

function CrystalHub.Functions.StartBallReach()
    local F = CrystalHub.Functions
    F.StopBallReach()
    local cfg = getgenv().CrystalReach
    local st = { Acc = 0, Active = false }
    CrystalHub.BallReachState = st
    st.Gate = RunService.Heartbeat:Connect(function(dt)
        st.Acc += dt
        if st.Acc < 0.08 then return end
        st.Acc = 0
        st.Active = false
        if not cfg.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        if F.MatchPaused(char) then return end
        local bodyState = char:GetAttribute("BodyState")
        if bodyState ~= nil and bodyState ~= "Animated" then return end
        if CrystalHub.TrickActive or os.clock() < (CrystalHub.ShotNext or 0) then return end
        local ball = F.GetBall()
        if not ball then return end
        local possessor = ball:GetAttribute("Possessor")
        if type(possessor) == "number" and possessor ~= 0 then return end
        local id = char:GetAttribute("DribbleId")
        if ball:GetAttribute("ReleasedBy") == id then
            local releasedAt = ball:GetAttribute("ReleasedAt")
            if type(releasedAt) == "number" and workspace:GetServerTimeNow() - releasedAt < 1.2 then return end
        end
        local root = char:FindFirstChild("Root")
        local cm = char:FindFirstChildOfClass("ControllerManager")
        if not (root and cm) then return end
        local mod = F.MannequinClientModule()
        if mod then
            local ok, anim = pcall(mod.getAnimator, char)
            if ok and anim then
                if anim.kick then return end
                local kickS, headS, pokeS = anim.kickS, anim.headS, anim.pokeS
                if kickS and not kickS.done then return end
                if headS and not headS.done then return end
                if pokeS and not pokeS.done then return end
            end
        end
        st.Root, st.Cm, st.Ball = root, cm, ball
        st.Active = true
    end)
    RunService:BindToRenderStep("CrystalBallReach", Enum.RenderPriority.Input.Value + 11, function()
        if not st.Active then return end
        local root, cm, ball = st.Root, st.Cm, st.Ball
        if not (root.Parent and cm.Parent and ball.Parent) then
            st.Active = false
            return
        end
        local possessor = ball:GetAttribute("Possessor")
        if type(possessor) == "number" and possessor ~= 0 then
            st.Active = false
            return
        end
        local bp, rp = ball.Position, root.Position
        if bp.Y > rp.Y - 2.4 then return end
        local vel = ball.AssemblyLinearVelocity
        if vel.X * vel.X + vel.Z * vel.Z > 1444 or math.abs(vel.Y) > 8 then return end
        local dx = bp.X + vel.X * 0.1 - rp.X
        local dz = bp.Z + vel.Z * 0.1 - rp.Z
        local d = math.sqrt(dx * dx + dz * dz)
        if d > 6 + cfg.Add or d < 1.6 then return end
        local ux, uz = dx / d, dz / d
        local md = cm.MovingDirection
        if md.X * ux + md.Z * uz < -0.2 then return end
        local direction = Vector3.new(ux, 0, uz)
        cm.FacingDirection = direction
        cm.MovingDirection = direction
        cm.BaseMoveSpeed = math.max(cm.BaseMoveSpeed, 24)
    end)
    CrystalHub.ConnectionController.Insert({ Disconnect = function() CrystalHub.Functions.StopBallReach() end })
    return true
end

function CrystalHub.Functions.ApplyBallReach()
    local F = CrystalHub.Functions
    if getgenv().CrystalReach.Enabled then
        return F.StartBallReach()
    end
    F.StopBallReach()
    return true
end

getgenv().CrystalAutoDribble = getgenv().CrystalAutoDribble or { Enabled = false, Range = 12 }

function CrystalHub.Functions.StopAutoDribble()
    local st = CrystalHub.AutoDribble
    CrystalHub.AutoDribble = nil
    pcall(function() RunService:UnbindFromRenderStep("CrystalDribbleEvade") end)
    if st and st.Conn then
        pcall(function() st.Conn:Disconnect() end)
    end
end

function CrystalHub.Functions.AutoDribbleTick(st, now)
    local F = CrystalHub.Functions
    local cfg = getgenv().CrystalAutoDribble
    st.Threats = nil
    local char = LocalPlayer.Character
    if not char or F.MatchPaused(char) then return end
    local ball = F.GetBall()
    local id = char:GetAttribute("DribbleId")
    if not ball or type(id) ~= "number" or ball:GetAttribute("Possessor") ~= id then return end
    local bodyState = char:GetAttribute("BodyState")
    if bodyState ~= nil and bodyState ~= "Animated" then return end
    if CrystalHub.TrickActive or now < (CrystalHub.ShotNext or 0) then return end
    local root = char:FindFirstChild("Root")
    if not root then return end
    local rp = root.Position
    local shoot = getgenv().CrystalAutoShoot
    if shoot.Enabled then
        local goal = F.SilentAimGoal()
        if goal then
            local limit = math.min(shoot.Range, 26)
            local gx, gz = goal.x - rp.X, goal.z - rp.Z
            if gx * gx + gz * gz <= limit * limit then return end
        end
    end
    local v = root.AssemblyLinearVelocity
    local myVel = Vector3.new(v.X, 0, v.Z)
    local speed = myVel.Magnitude
    local facing = speed > 4 and myVel / speed or root.CFrame.LookVector
    local f = Vector3.new(facing.X, 0, facing.Z)
    if f.Magnitude < 0.01 then return end
    f = f.Unit
    local threats = F.DribbleThreats(char, rp, f, myVel, cfg.Range + 4)
    st.Threats = threats
    st.ThreatAt = os.clock()
    st.Char = char
    if now - (st.SkillAt or 0) > 2 then st.Combo = 0 end
    local p = threats[1]
    if not p then return end
    if now < st.Next then return end
    local urgent = p.ttc <= 0.6 or p.d <= 7
    if not urgent then return end
    if not p.ready and p.d > 3.5 then return end
    if p.ahead < -0.15 and p.d > 5 then return end
    local crowd = 0
    for _, t in ipairs(threats) do
        if t.d <= 14 then crowd += 1 end
    end
    local gesture = F.DribblePick(speed, p, threats, crowd, st.Last)
    local rainbow = gesture and gesture.kind == "Rainbow"
    local success = F.TrySkill(st, gesture, speed, now, rainbow and 1.1 or 0.7)
    if success then
        st.Combo = math.min((st.Combo or 0) + 1, 3)
        st.SkillAt = now
        st.Next = now + (rainbow and 1.2 or (0.6 + 0.08 * st.Combo))
    else
        st.Next = now + 0.12
    end
end

function CrystalHub.Functions.StartAutoDribble()
    local F = CrystalHub.Functions
    F.StopAutoDribble()
    local cfg = getgenv().CrystalAutoDribble
    if cfg.Evade == nil then cfg.Evade = true end
    if cfg.EvadeStrength == nil then cfg.EvadeStrength = 0.8 end
    local st = { Acc = 0, Next = 0, Combo = 0 }
    CrystalHub.AutoDribble = st
    st.Conn = RunService.Heartbeat:Connect(function(dt)
        st.Acc += dt
        if st.Acc < 0.05 then return end
        st.Acc = 0
        if not getgenv().CrystalAutoDribble.Enabled then
            st.Threats = nil
            return
        end
        local now = os.clock()
        local ok = pcall(F.AutoDribbleTick, st, now)
        if not ok then
            st.Threats = nil
            st.Next = now + 0.5
        end
    end)
    RunService:BindToRenderStep("CrystalDribbleEvade", Enum.RenderPriority.Input.Value + 7, function()
        local c = getgenv().CrystalAutoDribble
        if not (c.Enabled and c.Evade) then return end
        local threats = st.Threats
        local now = os.clock()
        if not threats or #threats == 0 or now - (st.ThreatAt or 0) > 0.25 then return end
        local char = LocalPlayer.Character
        if not char or char ~= st.Char then return end
        if CrystalHub.TrickActive or now < (CrystalHub.SkillUntil or 0) or now < (CrystalHub.ShotNext or 0) then return end
        local cm = char:FindFirstChildOfClass("ControllerManager")
        if not cm then return end
        local md = cm.MovingDirection
        local flat = Vector3.new(md.X, 0, md.Z)
        local mag = flat.Magnitude
        if mag < 0.1 then return end
        local desired = flat / mag
        local left = Vector3.new(desired.Z, 0, -desired.X)
        local range = c.Range + 2
        local vote, strongest = 0, 0
        for i = 1, math.min(#threats, 3) do
            local t = threats[i]
            if t.ahead > 0.1 and t.d < range then
                local w = 1 - t.d / range
                if not t.ready then w *= 0.5 end
                local s = desired.X * t.dir.Z - desired.Z * t.dir.X
                vote += (s >= 0 and 1 or -1) * w
                strongest = math.max(strongest, w * t.ahead)
            end
        end
        if strongest <= 0 then return end
        local want = vote >= 0 and 1 or -1
        local sign = want
        if st.LatSign and want ~= st.LatSign and now - (st.LatAt or 0) < 0.5 then
            sign = st.LatSign
        else
            st.LatSign = want
            st.LatAt = now
        end
        local strength = math.clamp(strongest * 1.6 * (c.EvadeStrength or 0.8), 0, 1.2)
        local out = desired + left * sign * strength
        if out.Magnitude < 0.001 then return end
        cm.MovingDirection = out.Unit * mag
    end)
    CrystalHub.ConnectionController.Insert(st.Conn)
    CrystalHub.ConnectionController.Insert({ Disconnect = function()
        CrystalHub.Functions.StopAutoDribble()
    end })
    return true
end

function CrystalHub.Functions.BallPastLine(ball)
    local H = CrystalHub
    local now = os.clock()
    local cache = H.GoalLineCache
    if not cache or now - cache.At > (cache.Lines and 3 or 1) then
        if not H.DribbleContacts then
            local shared = Services.ReplicatedStorage:FindFirstChild("Shared")
            local gameFolder = shared and shared:FindFirstChild("Game")
            local dribble = gameFolder and gameFolder:FindFirstChild("Dribble")
            if dribble then
                local ok, mod = pcall(require, dribble)
                if ok and type(mod) == "table" then
                    H.DribbleContacts = mod.Contacts
                end
            end
        end
        local contacts = H.DribbleContacts
        cache = { At = now, Lines = contacts and contacts.goalLines() or nil }
        H.GoalLineCache = cache
    end
    local lines = cache.Lines
    if not lines then return false end
    local x = ball.Position.X
    return x < lines[1] or x > lines[2]
end

function CrystalHub.Functions.MatchPausedRaw(char)
    local F = CrystalHub.Functions
    local team = char:GetAttribute("Team")
    if team ~= "Blue" and team ~= "Red" then return true end
    if LocalPlayer:GetAttribute("InTutorial") == true then return true end
    local hold = LocalPlayer:GetAttribute("KickoffHold")
    if type(hold) == "number" and hold > workspace:GetServerTimeNow() then return true end
    local ball = F.GetBall()
    if ball and F.BallPastLine(ball) then return true end
    local celebration = F.ClientModule("GoalCelebration")
    if celebration and type(celebration.current) == "function" then
        local ok, current = pcall(celebration.current)
        if ok and current ~= nil then return true end
    end
    local replay = F.ClientModule("InstantReplay")
    if replay and type(replay.playing) == "function" then
        local ok, playing = pcall(replay.playing)
        if ok and playing == true then return true end
    end
    local lobby = F.ClientModule("Lobby")
    if lobby and type(lobby.benched) == "function" then
        local ok, benched = pcall(lobby.benched)
        if ok and benched == true then return true end
    end
    local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ui = gui and gui:FindFirstChild("GameUI")
    local popup = ui and ui:FindFirstChild("GoalPopup")
    if popup and popup:IsA("GuiObject") and popup.Visible then return true end
    return false
end

function CrystalHub.Functions.MatchPaused(char)
    local H = CrystalHub
    local now = os.clock()
    if H.PausedChar == char and now - (H.PausedAt or 0) < 0.08 then
        return H.PausedValue
    end
    local paused = H.Functions.MatchPausedRaw(char)
    H.PausedChar, H.PausedAt, H.PausedValue = char, now, paused
    return paused
end

function CrystalHub.Functions.SprintBase()
    local cached = CrystalHub.SprintBaseVal
    if cached then return cached end
    local speed = 36
    pcall(function()
        local tuning = require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("MannequinAnimation"):WaitForChild("Tuning"))
        speed = tuning.Speed.Sprint
    end)
    CrystalHub.SprintBaseVal = speed
    return speed
end

function CrystalHub.Functions.StartGuard()
    local F = CrystalHub.Functions
    F.StopGuard()
    local cfg = getgenv().CrystalGuard
    cfg.Engage = cfg.Engage or 22
    local st = { Acc = 0, Active = false, Engaged = false, Controlling = false, ResumeAt = 0 }
    CrystalHub.GuardState = st

    local function finite(v)
        return v.X == v.X and v.Y == v.Y and v.Z == v.Z
            and math.abs(v.X) < 100000 and math.abs(v.Y) < 100000 and math.abs(v.Z) < 100000
    end

    local function downed(char)
        local bodyState = char:GetAttribute("BodyState")
        if bodyState ~= nil and bodyState ~= "Animated" then return true end
        local mod = F.MannequinClientModule()
        if mod then
            local ok, anim = pcall(mod.getAnimator, char)
            if ok and anim and anim.body and anim.body.active then return true end
        end
        return false
    end

    local function release()
        if st.Controlling then
            local cm = st.Cm
            if cm and cm.Parent then
                cm.MovingDirection = Vector3.zero
            end
        end
        st.Controlling = false
        st.Active = false
        st.Face = nil
        st.StuckAt = nil
    end

    local function pause(seconds)
        st.ResumeAt = os.clock() + seconds
        st.Engaged = false
        release()
    end

    local function clearCarrier()
        st.CarrierId, st.CarrierPart, st.CarrierModel = nil, nil, nil
    end

    local function evaluate()
        local char = LocalPlayer.Character
        if not char then return false end
        if downed(char) then
            pause(0.5)
            return false
        end
        if os.clock() < st.ResumeAt then return false end
        if F.MatchPaused(char) then
            st.Engaged = false
            return false
        end
        local root = char:FindFirstChild("Root")
        local cm = char:FindFirstChildOfClass("ControllerManager")
        if not (root and cm) then return false end
        if not finite(root.Position) then return false end
        local ball = F.GetBall()
        if not ball or not finite(ball.Position) then return false end
        local goal = F.GuardOwnGoal()
        if not goal then return false end
        local id = char:GetAttribute("DribbleId")
        local possessor = ball:GetAttribute("Possessor")
        local held = type(possessor) == "number" and possessor ~= 0
        local mate = false
        local carrier
        if held then
            if possessor == id then
                clearCarrier()
                st.Engaged = false
                return false
            end
            if st.CarrierId ~= possessor or not (st.CarrierPart and st.CarrierPart.Parent) then
                clearCarrier()
                st.CarrierId = possessor
                for _, model in ipairs(Services.CollectionService:GetTagged("MannequinCharacter")) do
                    if model ~= char and model:IsA("Model") and model:GetAttribute("DribbleId") == possessor then
                        local r = model:FindFirstChild("Root")
                        if r and r:IsA("BasePart") then
                            st.CarrierPart = r
                            st.CarrierModel = model
                        end
                        break
                    end
                end
            end
            carrier = st.CarrierPart
            local model = st.CarrierModel
            if model then
                local theirTeam = model:GetAttribute("Team")
                if theirTeam ~= nil and theirTeam == char:GetAttribute("Team") then
                    if cfg.IgnoreTeammates then
                        st.Engaged = false
                        return false
                    end
                    mate = true
                    carrier = nil
                end
            end
        else
            clearCarrier()
            if ball:GetAttribute("ReleasedBy") == id then
                local releasedAt = ball:GetAttribute("ReleasedAt")
                if type(releasedAt) == "number" and workspace:GetServerTimeNow() - releasedAt < 1.2 then
                    st.Engaged = false
                    return false
                end
            end
        end
        local rp = root.Position
        local subject = carrier or ball
        local sp = subject.Position
        if not finite(sp) then return false end
        local dx, dz = sp.X - rp.X, sp.Z - rp.Z
        local d = math.sqrt(dx * dx + dz * dz)
        local engaged = d <= (st.Engaged and cfg.Engage * 1.3 or cfg.Engage)
        if engaged and not carrier and ball.Position.Y > rp.Y - 2.4 then
            engaged = false
        end
        if mate then engaged = false end
        st.Engaged = engaged
        if engaged and carrier then
            local readyAt = LocalPlayer:GetAttribute("PokeReadyAt")
            if not (type(readyAt) == "number" and readyAt > workspace:GetServerTimeNow()) then
                local target, distance = F.FindPokeTarget()
                if target and distance <= 6.5 then
                    F.FirePoke()
                end
            end
        end
        st.Char = char
        st.MyId = id
        st.Speed = F.SprintBase() * math.max(getgenv().CrystalSprint.Boost or 1, 1)
        st.Root, st.Cm, st.Ball, st.Carrier, st.Goal = root, cm, ball, carrier, goal
        st.Active = true
        return true
    end

    st.Gate = RunService.Heartbeat:Connect(function(dt)
        st.Acc += dt
        if st.Acc < 0.1 then return end
        st.Acc = 0
        if not cfg.Enabled then
            release()
            return
        end
        local ok, ready = pcall(evaluate)
        if not (ok and ready) then
            release()
        end
    end)

    local function steer(target, dt)
        if not finite(target) or target.Magnitude < 0.001 then
            return st.Face
        end
        target = target.Unit
        local cur = st.Face
        if not cur or not finite(cur) or cur.Magnitude < 0.001 then
            local look = st.Root.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            cur = flat.Magnitude > 0.001 and flat.Unit or target
        else
            cur = cur.Unit
        end
        local angle = math.acos(math.clamp(cur:Dot(target), -1, 1))
        local step = 9 * dt
        if angle ~= angle or angle <= step then
            st.Face = target
            return target
        end
        local rotated = CFrame.Angles(0, cur:Cross(target).Y >= 0 and step or -step, 0) * cur
        rotated = Vector3.new(rotated.X, 0, rotated.Z)
        if rotated.Magnitude < 0.001 or not finite(rotated) then
            st.Face = target
            return target
        end
        st.Face = rotated.Unit
        return st.Face
    end

    local function drive(dt)
        local root, cm, ball, carrier, goal, char = st.Root, st.Cm, st.Ball, st.Carrier, st.Goal, st.Char
        if not (root.Parent and cm.Parent and ball.Parent and char and char.Parent) then
            release()
            return
        end
        if downed(char) then
            pause(0.5)
            return
        end
        if os.clock() < st.ResumeAt then
            release()
            return
        end
        local active = cm.ActiveController
        if active == nil or active.Name == "BodyIdleController" then
            local gc = cm:FindFirstChild("GroundController")
            if gc then cm.ActiveController = gc end
        end
        local possessor = ball:GetAttribute("Possessor")
        if possessor ~= nil and possessor ~= 0 and possessor == st.MyId then
            release()
            return
        end
        local subject = carrier or ball
        if not subject.Parent then
            release()
            return
        end
        local pos = subject.Position
        local vel = subject.AssemblyLinearVelocity
        local rp = root.Position
        if not (finite(pos) and finite(vel) and finite(rp)) then
            release()
            return
        end
        if vel.Magnitude > 120 then
            vel = vel.Unit * 120
        end
        local move, face
        if st.Engaged then
            local lead = carrier and 0.18 or 0.12
            local mx, mz = pos.X + vel.X * lead - rp.X, pos.Z + vel.Z * lead - rp.Z
            local dist = math.sqrt(mx * mx + mz * mz)
            if dist > 0.8 then
                local dir = Vector3.new(mx / dist, 0, mz / dist)
                move = dir * math.clamp(dist / 5, 0, 1)
                if dist > 2.5 then
                    face = dir
                end
            end
        else
            local px = pos.X + vel.X * getgenv().CrystalGuard.Predict
            local pz = pos.Z + vel.Z * getgenv().CrystalGuard.Predict
            local gx, gz = goal.X - px, goal.Z - pz
            local gd = math.sqrt(gx * gx + gz * gz)
            if gd < 1 then
                release()
                return
            end
            local ux, uz = gx / gd, gz / gd
            local stand = math.min(cfg.Distance, gd * 0.5)
            local mx, mz = px + ux * stand - rp.X, pz + uz * stand - rp.Z
            local dist = math.sqrt(mx * mx + mz * mz)
            if dist > 0.8 then
                move = Vector3.new(mx / dist, 0, mz / dist) * math.clamp(dist / 4, 0, 1)
            end
            local fx, fz = px - rp.X, pz - rp.Z
            local fd = math.sqrt(fx * fx + fz * fz)
            if fd > 4 then
                face = Vector3.new(fx / fd, 0, fz / fd)
            end
        end
        if move then
            cm.MovingDirection = move
            cm.BaseMoveSpeed = math.max(cm.BaseMoveSpeed, st.Speed)
        else
            cm.MovingDirection = Vector3.zero
        end
        if face then
            local facing = steer(face, dt)
            if facing then
                cm.FacingDirection = facing
            end
        end
        st.Controlling = true
        local rv = root.AssemblyLinearVelocity
        if move and move.Magnitude > 0.5 and rv.X * rv.X + rv.Z * rv.Z < 1 then
            st.StuckAt = st.StuckAt or os.clock()
            if os.clock() - st.StuckAt > 1.5 then
                pause(0.6)
            end
        else
            st.StuckAt = nil
        end
    end

    RunService:BindToRenderStep("CrystalGuard", Enum.RenderPriority.Input.Value + 10, function(dt)
        if not st.Active then
            if st.Controlling then release() end
            return
        end
        if not pcall(drive, dt) then
            release()
        end
    end)
    CrystalHub.ConnectionController.Insert({ Disconnect = function() CrystalHub.Functions.StopGuard() end })
end

getgenv().CrystalKeeper = getgenv().CrystalKeeper or {}
for k, v in pairs({ Enabled = false, Depth = 4.5, DiveRange = 22, Poke = true, Dive = true, Gather = true, Rush = true, RushRange = 34, DiveLead = 0.0, DiveBias = 0.0, CommitRange = 45, StandReach = 2 }) do
    if getgenv().CrystalKeeper[k] == nil then
        getgenv().CrystalKeeper[k] = v
    end
end
getgenv().CrystalKeeper.Enabled = false

function CrystalHub.Functions.KeeperGoal()
    local F = CrystalHub.Functions
    local char = LocalPlayer.Character
    local now = os.clock()
    local cache = CrystalHub.KeeperGoalCache
    if cache and cache.Char == char and now - cache.At < 0.5 then
        return cache.Value
    end
    local attacked = F.SilentAimGoal()
    if not attacked then return nil end
    local parts = {}
    local mid = 0
    for _, part in ipairs(Services.CollectionService:GetTagged("SoccerGoalFrame")) do
        if part:IsA("BasePart") and part:IsDescendantOf(workspace) then
            parts[#parts + 1] = part
            mid += part.Position.X
        end
    end
    if #parts < 2 then return nil end
    mid /= #parts
    local own, far = nil, -1
    for _, part in ipairs(parts) do
        local d = math.abs(part.Position.X - attacked.x)
        if d > far then
            far = d
            own = part
        end
    end
    local side = own.Position.X < mid and -1 or 1
    local q = own.Size.Y / 9.142857142857142
    local ground = own.Position.Y - own.Size.Y / 2
    local value = {
        x = own.Position.X - side * own.Size.X / 2 + side * 0.21428571428571425 * q,
        z = own.Position.Z,
        half = 13.071428571428571 * q,
        top = ground + 8.714285714285714 * q,
        ground = ground,
        side = side,
        inward = Vector3.new(-side, 0, 0),
    }
    CrystalHub.KeeperGoalCache = { Char = char, At = now, Value = value }
    return value
end

function CrystalHub.Functions.KeeperActions()
    local H = CrystalHub
    local cached = H.KeeperActionCache
    if cached and os.clock() - cached.At < 5 and (not cached.Dive or cached.Dive.Parent) and (not cached.Slide or cached.Slide.Parent) then
        return cached
    end
    local found = { At = os.clock() }
    local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if scripts then
        for _, inst in ipairs(scripts:GetDescendants()) do
            if inst:IsA("InputAction") then
                local name = inst.Name:lower()
                if not found.Dive and (name:find("dive") or name == "block") then
                    local ok, kind = pcall(function() return inst.Type end)
                    if ok and kind == Enum.InputActionType.Bool then
                        found.Dive = inst
                    end
                elseif not found.Slide and inst.Name == "Slide" then
                    found.Slide = inst
                end
            end
        end
    end
    H.KeeperActionCache = found
    return found
end

function CrystalHub.Functions.KeeperReady(action)
    if not (action and action.Parent) then return false end
    local ok, enabled = pcall(function()
        local parent = action.Parent
        return action.Enabled and not (parent:IsA("InputContext") and not parent.Enabled)
    end)
    return ok and enabled == true
end

function CrystalHub.Functions.KeeperFire(action)
    local H = CrystalHub
    local bindings = H.KeeperBindings
    if not bindings then
        bindings = {}
        H.KeeperBindings = bindings
        H.ConnectionController.Insert({ Disconnect = function()
            for _, b in pairs(bindings) do
                pcall(function() b:Destroy() end)
            end
            H.KeeperBindings = nil
        end })
    end
    local binding = bindings[action]
    if not (binding and binding.Parent == action) then
        if binding then
            pcall(function() binding:Destroy() end)
        end
        binding = Instance.new("InputBinding")
        binding.Name = "CrystalKeeper"
        binding.Type = Enum.InputBindingType.Scriptable
        binding.Parent = action
        bindings[action] = binding
    end
    binding:Fire(true)
    task.delay(0.06, function()
        pcall(function() binding:Fire(false) end)
    end)
    return true
end

function CrystalHub.Functions.KeeperCarrier(possessor)
    for _, model in ipairs(Services.CollectionService:GetTagged("MannequinCharacter")) do
        if model:IsA("Model") and model:GetAttribute("DribbleId") == possessor then
            local root = model:FindFirstChild("Root")
            if root and root:IsA("BasePart") then
                return model, root
            end
        end
    end
    return nil, nil
end

function CrystalHub.Functions.KeeperDiveEnv()
    local H = CrystalHub
    if H.KeeperDiveData then return H.KeeperDiveData end
    if H.KeeperDiveFail and os.clock() - H.KeeperDiveFail < 3 then return nil end
    local ok, data = pcall(function()
        local shared = Services.ReplicatedStorage:FindFirstChild("Shared")
        local gameFolder = shared and shared:FindFirstChild("Game")
        local netModule = shared and shared:FindFirstChild("Net")
        local divesModule = gameFolder and gameFolder:FindFirstChild("KeeperDives")
        if not (netModule and divesModule) then return nil end
        local Net = require(netModule)
        return { Dives = require(divesModule), Remote = Net:RemoteEvent("MannequinDev") }
    end)
    if ok and type(data) == "table" and data.Remote then
        H.KeeperDiveData = data
        return data
    end
    H.KeeperDiveFail = os.clock()
    return nil
end

task.spawn(CrystalHub.Functions.KeeperDiveEnv)

function CrystalHub.Functions.KeeperIntercept(plan, x)
    local path = plan.path
    if not path then return nil end
    local side = plan.side
    local prev, prevT = plan.from, 0
    for _, e in ipairs(path) do
        local p = e.pos
        if (prev.X - x) * side < 0 and (p.X - x) * side >= 0 then
            local a = (x - prev.X) / (p.X - prev.X)
            return { t = prevT + (e.t - prevT) * a, pos = prev:Lerp(p, a) }
        end
        prev, prevT = p, e.t
    end
    return nil
end

function CrystalHub.Functions.StopKeeper()
    pcall(function() RunService:UnbindFromRenderStep("CrystalKeeper") end)
    local st = CrystalHub.KeeperState
    CrystalHub.KeeperState = nil
    if st and st.Controlling and st.Cm and st.Cm.Parent then
        pcall(function() st.Cm.MovingDirection = Vector3.zero end)
    end
end

for k, v in pairs({ Lead = 0.03, ArmReach = 3.4, MinShotSpeed = 20 }) do
    if getgenv().CrystalKeeper[k] == nil then
        getgenv().CrystalKeeper[k] = v
    end
end

function CrystalHub.Functions.KeeperDiveDirect(char, kind, lateral)
    local F = CrystalHub.Functions
    if kind == "Jump" then return false end
    local env = F.KeeperDiveEnv()
    local mod = F.MannequinClientModule()
    local goal = F.KeeperGoal()
    if not (env and mod and goal) then return false end
    local okA, anim = pcall(mod.getAnimator, char)
    if not okA or not anim then return false end
    local body = anim.body or (anim.getBody and anim:getBody())
    if not body or body.active then return false end
    local dir = Vector3.new(0, 0, lateral.Z >= 0 and 1 or -1)
    local ok, started = pcall(body.keyDive, body, kind, dir, goal.inward)
    if not (ok and started) then return false end
    local kdive = body.kdive
    local payload = nil
    if kdive and kdive.animated then
        local eok, encoded = pcall(env.Dives.encode, kdive.move)
        if eok then payload = encoded end
    end
    env.Remote:FireServer("Dive" .. kind, dir, payload)
    return true
end

function CrystalHub.Functions.KeeperDive(char, kind, lateral)
    local F = CrystalHub.Functions
    local mod = F.MannequinClientModule()
    if not mod then return false end
    if char:GetAttribute("BodyState") ~= "Animated" then return false end
    if mod.keeperReady and not mod.keeperReady() then return false end
    if kind == "Jump" then
        if not mod.keeperJump then return false end
        return pcall(mod.keeperJump)
    end
    local ok, res = pcall(F.KeeperDiveDirect, char, kind, lateral)
    return ok and res == true
end

function CrystalHub.Functions.KeeperDiveProfile(kind)
    local H = CrystalHub
    local cache = H.KeeperProfiles
    if not cache then
        cache = {}
        H.KeeperProfiles = cache
    end
    if cache[kind] ~= nil then return cache[kind] or nil end
    local mod = H.Functions.KeeperDivesModule()
    if not (mod and type(mod.track) == "function" and type(mod.hips) == "function") then return nil end
    local ok, tr = pcall(mod.track, kind)
    if not ok or type(tr) ~= "table" or not tr.right then
        cache[kind] = false
        return nil
    end
    local limit = tr.ragAt or tr.touch or tr.duration
    local step = 0.02
    local n = math.max(math.floor(math.min(limit, tr.duration) / step), 2)
    local okB, base = pcall(mod.hips, tr.right, 0)
    if not okB then
        cache[kind] = false
        return nil
    end
    local D = {}
    for i = 0, n do
        local okP, p = pcall(mod.hips, tr.right, i * step)
        if not okP then
            cache[kind] = false
            return nil
        end
        D[i + 1] = math.abs(p.X - base.X)
    end
    local prof = { step = step, D = D, tmax = n * step, takeoff = tr.takeoff, touch = tr.touch }
    cache[kind] = prof
    return prof
end

function CrystalHub.Functions.KeeperDiveTime(prof, alat, carry)
    local arm = getgenv().CrystalKeeper.ArmReach
    local ct = math.max(prof.takeoff or 0.15, 0.15)
    for i = 1, #prof.D do
        local t = (i - 1) * prof.step
        local c = math.min(t, ct)
        local disp = prof.D[i] + carry * (c - c * c / (2 * ct)) + arm
        if disp >= alat then return t end
    end
    return nil
end

function CrystalHub.Functions.KeeperDecide(plan, root, now)
    local F = CrystalHub.Functions
    local cfg = getgenv().CrystalKeeper
    local rp = root.Position
    local hit = F.KeeperIntercept(plan, rp.X)
    if not hit then return nil end
    local rem = plan.at + hit.t - now
    if rem < -0.06 or (plan.speed or 0) < cfg.MinShotSpeed then return nil end
    local lat = hit.pos.Z - rp.Z
    local alat = math.abs(lat)
    local hy = hit.pos.Y - plan.goal.ground
    local runSpeed = F.SprintBase() * math.max(getgenv().CrystalSprint.Boost or 1, 1)
    local reach = 3.2 + runSpeed * 0.8 * math.max(rem - 0.12, 0)
    if hy >= 5.8 and alat <= 3.6 then
        return "Jump", rem, 0.35 + cfg.Lead, lat
    end
    if alat <= reach then return nil end
    if alat > cfg.DiveRange * 1.1 then return nil end
    local order
    if hy >= 4.9 then
        order = { "High", "Mid", "Low" }
    elseif hy <= 3.2 then
        order = { "Low", "Mid", "High" }
    else
        order = { "Mid", "High", "Low" }
    end
    local sign = lat >= 0 and 1 or -1
    local carry = math.clamp(root.AssemblyLinearVelocity.Z * sign, -24, 24)
    local chosen, tau
    for _, kind in ipairs(order) do
        local prof = F.KeeperDiveProfile(kind)
        if prof then
            local t = F.KeeperDiveTime(prof, alat, carry)
            if t then
                chosen, tau = kind, t
                break
            end
        end
    end
    if not chosen then
        chosen = order[1]
        local prof = F.KeeperDiveProfile(chosen)
        tau = prof and prof.tmax or F.KeeperDiveTouch(chosen)
    end
    local lag = math.clamp(plan.lag or 0, 0, 0.25)
    return chosen, rem, tau + cfg.Lead + lag * 0.4, lat
end

function CrystalHub.Functions.KeeperPlan(char, root, ball, goal)
    local F = CrystalHub.Functions
    local cfg = getgenv().CrystalKeeper
    local st = CrystalHub.KeeperState
    local id = char:GetAttribute("DribbleId")
    local myTeam = char:GetAttribute("Team")
    local possessor = ball:GetAttribute("Possessor")
    local rp = root.Position
    local bp = ball.Position
    local gz = goal.z
    local inward = goal.inward
    local near = cfg.Depth
    local limit = goal.half - 2.5
    local now = os.clock()

    local function spotFor(point)
        local dx, dz = point.X - goal.x, point.Z - gz
        local dist = math.sqrt(dx * dx + dz * dz)
        local ux, uz = inward.X, 0
        if dist > 1 then
            ux, uz = dx / dist, dz / dist
        end
        local along = ux * inward.X
        if along < 0.35 then
            uz = (uz >= 0 and 1 or -1) * 0.9367496997597597
            along = 0.35
        end
        local t = math.clamp((dist - 14) / 90, 0, 1)
        local depth = near + near * 1.2 * t
        local z = math.clamp(uz * depth / along, -limit, limit)
        return Vector3.new(goal.x + inward.X * depth, rp.Y, gz + z)
    end

    if type(possessor) == "number" and possessor ~= 0 then
        if possessor == id then return nil end
        local model, croot = F.KeeperCarrier(possessor)
        if not croot then
            return { kind = "hold", target = spotFor(bp), look = bp }
        end
        local cp = croot.Position
        local cv = croot.AssemblyLinearVelocity
        local ahead = Vector3.new(cp.X + cv.X * 0.25, cp.Y, cp.Z + cv.Z * 0.25)
        local plan = { kind = "hold", target = spotFor(ahead), look = cp }
        if model:GetAttribute("Team") == myTeam then
            return plan
        end
        local gx, gdz = cp.X - goal.x, cp.Z - gz
        local toGoal = math.sqrt(gx * gx + gdz * gdz)
        local mx, mz = cp.X - rp.X, cp.Z - rp.Z
        local toMe = math.sqrt(mx * mx + mz * mz)
        plan.carrier = croot
        local inFront = inward.X * gx > 0
        local central = math.abs(gdz) <= goal.half * 1.25
        local towards = -(cv.X * inward.X)
        local holding = st and st.RushUntil and now < st.RushUntil
        local want = cfg.Rush and inFront and central and toGoal <= cfg.RushRange and toGoal >= 9 and toMe <= 26 and towards > -2
        if want or (holding and inFront and toGoal >= 7 and toMe <= 30) then
            if want and st then st.RushUntil = now + 0.5 end
            local lead = math.min(toMe / math.max(F.SprintBase(), 1), 0.4)
            plan.kind = "rush"
            plan.target = Vector3.new(cp.X + cv.X * lead, rp.Y, cp.Z + cv.Z * lead)
        end
        return plan
    end

    if not F.SilentAimModules() then return nil end
    local SA = getgenv().CrystalSilentAim
    local BV = SA.BallView
    local rel = ball:GetAttribute("ReleasedBy")
    local relAt = ball:GetAttribute("ReleasedAt")
    local selfRecent = rel == id and type(relAt) == "number" and workspace:GetServerTimeNow() - relAt < 1.2
    local state = BV.freeSim()
    local pos, vel, spin
    if state then
        pos, vel, spin = state.pos, state.vel, state.spin
    else
        pos = BV.getPosition() or bp
        vel = ball.AssemblyLinearVelocity
        spin = Vector3.zero
    end

    if vel.Magnitude > 12 then
        local params = SA.Flight.params(ball)
        local gy = BV.groundBallY(pos)
        local list = F.ShotPredict(params, pos, vel, spin or Vector3.zero, gy, 2.2, 1 / 40)
        local side, lineX = goal.side, goal.x
        local prev, prevT = pos, 0
        local cross
        for _, e in ipairs(list) do
            local p = e.pos
            if (prev.X - lineX) * side < 0 and (p.X - lineX) * side >= 0 then
                local a = (lineX - prev.X) / (p.X - prev.X)
                cross = { t = prevT + (e.t - prevT) * a, pos = prev:Lerp(p, a) }
                break
            end
            prev, prevT = p, e.t
        end
        if cross then
            local lat = math.abs(cross.pos.Z - gz)
            local hy = cross.pos.Y - goal.ground
            if lat <= goal.half + 1.0 and hy <= (goal.top - goal.ground) + 1.0 and hy >= -0.5 then
                local lag = 0
                pcall(function() lag = LocalPlayer:GetNetworkPing() end)
                lag = math.clamp(lag, 0, 0.25)
                local plan = {
                    kind = "save",
                    look = pos,
                    path = list,
                    from = pos,
                    at = now,
                    side = side,
                    lag = lag,
                    cross = cross,
                    goal = goal,
                    speed = vel.Magnitude,
                }
                local depth = math.clamp((rp.X - goal.x) * inward.X, 2, 6)
                local tx = goal.x + inward.X * depth
                local hit = F.KeeperIntercept(plan, tx) or cross
                local tz = math.clamp(hit.pos.Z, gz - (goal.half - 1), gz + (goal.half - 1))
                plan.target = Vector3.new(tx, rp.Y, tz)
                return plan
            end
        end
        local sample = list[math.min(#list, 22)]
        local focus = sample and sample.pos or pos
        return { kind = "hold", target = spotFor(focus), look = pos }
    end

    local depthIn = (goal.x - pos.X) * goal.side
    local inArea = depthIn >= 0 and depthIn <= 23 and math.abs(pos.Z - gz) <= 34
    if cfg.Gather and not selfRecent and inArea and pos.Y - BV.groundBallY(pos) <= 4 then
        local sprint = F.SprintBase()
        local mdx, mdz = pos.X - rp.X, pos.Z - rp.Z
        local mine = math.max(math.sqrt(mdx * mdx + mdz * mdz) - 2.6, 0) / sprint
        local rival = math.huge
        for _, model in ipairs(Services.CollectionService:GetTagged("MannequinCharacter")) do
            if model ~= char and model:IsA("Model") then
                local team = model:GetAttribute("Team")
                local r = model:FindFirstChild("Root")
                if type(team) == "string" and team ~= myTeam and r and r:IsA("BasePart") then
                    local rdx, rdz = pos.X - r.Position.X, pos.Z - r.Position.Z
                    local t = math.max(math.sqrt(rdx * rdx + rdz * rdz) - 3, 0) / 31
                    if t < rival then rival = t end
                end
            end
        end
        if mine + 0.15 < rival then
            return {
                kind = "gather",
                target = Vector3.new(pos.X + vel.X * 0.12, rp.Y, pos.Z + vel.Z * 0.12),
                look = pos,
            }
        end
    end
    return { kind = "hold", target = spotFor(pos), look = pos }
end

function CrystalHub.Functions.StartKeeper()
    local F = CrystalHub.Functions
    F.StopKeeper()
    if not F.SilentAimModules() then return false end
    F.KeeperDiveEnv()
    F.KeeperDivesModule()
    local cfg = getgenv().CrystalKeeper
    local st = {
        Acc = 1,
        Plan = nil,
        Controlling = false,
        DiveNext = 0,
        PokeNext = 0,
        SlideNext = 0,
        Moving = false,
        Dir = Vector3.zero,
        RushUntil = 0,
        Fast = false,
    }
    CrystalHub.KeeperState = st

    local function downed(char)
        local bodyState = char:GetAttribute("BodyState")
        if bodyState ~= nil and bodyState ~= "Animated" then return true end
        local mod = F.MannequinClientModule()
        if mod then
            local ok, anim = pcall(mod.getAnimator, char)
            if ok and anim and anim.body and anim.body.active then return true end
        end
        return false
    end

    local function release()
        if st.Controlling and st.Cm and st.Cm.Parent then
            st.Cm.MovingDirection = Vector3.zero
        end
        st.Controlling = false
        st.Plan = nil
        st.Tgt = nil
        st.Moving = false
        st.Dir = Vector3.zero
        st.Face = nil
    end

    local function refresh()
        local char = LocalPlayer.Character
        if not char then return false end
        local team = char:GetAttribute("Team")
        if team ~= "Blue" and team ~= "Red" then return false end
        if downed(char) or F.MatchPaused(char) then return false end
        local root = char:FindFirstChild("Root")
        local cm = char:FindFirstChildOfClass("ControllerManager")
        local ball = F.GetBall()
        local goal = F.KeeperGoal()
        if not (root and cm and ball and goal) then return false end
        local plan = F.KeeperPlan(char, root, ball, goal)
        if not plan then return false end
        st.Char, st.Root, st.Cm, st.Ball, st.Plan = char, root, cm, ball, plan
        st.Fast = plan.kind == "save" or plan.kind == "rush"
        return true
    end

    local function steer(target, dt)
        local cur = st.Face
        if not cur or cur.Magnitude < 0.001 then
            local look = st.Root.CFrame.LookVector
            cur = Vector3.new(look.X, 0, look.Z)
            if cur.Magnitude < 0.001 then
                st.Face = target
                return target
            end
        end
        cur = cur.Unit
        local angle = math.acos(math.clamp(cur:Dot(target), -1, 1))
        local step = 12 * dt
        if angle ~= angle or angle <= step then
            st.Face = target
            return target
        end
        local rotated = CFrame.Angles(0, cur:Cross(target).Y >= 0 and step or -step, 0) * cur
        rotated = Vector3.new(rotated.X, 0, rotated.Z)
        if rotated.Magnitude < 0.001 then
            st.Face = target
            return target
        end
        st.Face = rotated.Unit
        return st.Face
    end

    local function drive(dt)
        local plan, root, cm, char = st.Plan, st.Root, st.Cm, st.Char
        if not (root.Parent and cm.Parent and char.Parent and LocalPlayer.Character == char) or downed(char) then
            release()
            return
        end
        local now = os.clock()
        local rp = root.Position
        local kind = plan.kind
        local speed = F.SprintBase() * math.max(getgenv().CrystalSprint.Boost or 1, 1)
        local active = cm.ActiveController
        if active == nil or active.Name == "BodyIdleController" then
            local gc = cm:FindFirstChild("GroundController")
            if gc then cm.ActiveController = gc end
        end
        local goalT = plan.target
        local tau = kind == "save" and 0.04 or (kind == "rush" and 0.07 or 0.12)
        if not st.Tgt or (st.Tgt - goalT).Magnitude > 25 then
            st.Tgt = goalT
        else
            st.Tgt = st.Tgt:Lerp(goalT, 1 - math.exp(-dt / tau))
        end
        local tgt = st.Tgt
        local dx, dz = tgt.X - rp.X, tgt.Z - rp.Z
        local dist = math.sqrt(dx * dx + dz * dz)
        if st.Moving then
            if dist < 0.25 then st.Moving = false end
        elseif dist > 0.6 then
            st.Moving = true
        end
        if st.Moving and dist > 0.001 then
            local mag = kind == "hold" and math.clamp(dist / (speed * 0.2), 0.15, 1) or 1
            local want = Vector3.new(dx / dist, 0, dz / dist) * mag
            st.Dir = st.Dir:Lerp(want, 1 - math.exp(-dt / 0.04))
            cm.MovingDirection = st.Dir
            cm.BaseMoveSpeed = math.max(cm.BaseMoveSpeed, speed)
        else
            st.Dir = Vector3.zero
            cm.MovingDirection = Vector3.zero
        end
        local look = plan.look
        if look then
            local fx, fz = look.X - rp.X, look.Z - rp.Z
            local fm = math.sqrt(fx * fx + fz * fz)
            if fm > 1 then
                cm.FacingDirection = steer(Vector3.new(fx / fm, 0, fz / fm), dt)
            end
        end
        st.Controlling = true

        local serverNow = workspace:GetServerTimeNow()

        if cfg.Poke and now >= st.PokeNext then
            local readyAt = LocalPlayer:GetAttribute("PokeReadyAt")
            if not (type(readyAt) == "number" and readyAt > serverNow) then
                local model, distance = F.FindPokeTarget()
                if model and distance <= 6.2 then
                    F.FirePoke()
                    st.PokeNext = now + 0.25
                end
            end
        end

        if cfg.Dive and kind == "save" and now >= st.DiveNext and char:GetAttribute("Role") == "Goalkeeper" then
            local ballFlat = Vector3.new(plan.from.X - rp.X, 0, plan.from.Z - rp.Z).Magnitude
            if ballFlat <= (cfg.CommitRange or 45) then
                local diveKind, rem, fireAt, lat = F.KeeperDecide(plan, root, now)
                if diveKind and rem <= fireAt and rem >= -0.06 then
                    local lateral = Vector3.new(0, 0, lat >= 0 and 1 or -1)
                    if F.KeeperDive(char, diveKind, lateral) then
                        st.DiveNext = now + (diveKind == "Jump" and 0.8 or 1.5)
                    else
                        st.DiveNext = now + 0.05
                    end
                end
            end
        end

        if cfg.Dive and kind == "rush" and plan.carrier and plan.carrier.Parent and now >= st.SlideNext then
            local cp = plan.carrier.Position
            local sx, sz = cp.X - rp.X, cp.Z - rp.Z
            local acts = F.KeeperActions()
            if math.sqrt(sx * sx + sz * sz) <= 7.5 and F.KeeperReady(acts.Slide) then
                local readyAt = LocalPlayer:GetAttribute("SlideReadyAt")
                if not (type(readyAt) == "number" and readyAt > serverNow) then
                    F.KeeperFire(acts.Slide)
                    st.SlideNext = now + 2.2
                end
            end
        end
    end

    RunService:BindToRenderStep("CrystalKeeper", Enum.RenderPriority.Input.Value + 12, function(dt)
        if not cfg.Enabled then
            release()
            return
        end
        st.Acc += dt
        if st.Acc >= (st.Fast and 0.04 or 0.08) then
            st.Acc = 0
            local ok, ready = pcall(refresh)
            if not ok or not ready then
                release()
                return
            end
        end
        if st.Plan then
            if not pcall(drive, dt) then
                release()
            end
        end
    end)
    CrystalHub.ConnectionController.Insert({ Disconnect = function() CrystalHub.Functions.StopKeeper() end })
    return true
end

getgenv().CrystalAutoTricks = getgenv().CrystalAutoTricks or { Enabled = false, Range = 70 }
getgenv().CrystalAutoTricks.Auto = true
getgenv().CrystalAutoTricks.AirFamilies = {}
getgenv().CrystalAutoTricks.Skills = {}
getgenv().CrystalAutoTricks.Lob = false
getgenv().CrystalTrickFilter = getgenv().CrystalTrickFilter or { Hooked = false }

CrystalHub.TrickOptions = {
    "Auto",
    "Bicycle Kick",
    "Volley",
    "Side Volley",
    "Header",
    "Jump Header",
    "Running Header",
    "Diving Header",
    "Lob",
    "Ronaldo Chop",
    "Cruyff Turn",
    "Knock-On",
    "Elastico",
    "Rainbow Flick",
    "Roulette",
    "Step Over",
    "Croqueta",
}

CrystalHub.TrickCatalog = {
    ["Bicycle Kick"] = { air = "Bicycle" },
    ["Volley"] = { air = "Volley" },
    ["Side Volley"] = { air = "SideVolley" },
    ["Header"] = { air = "Header" },
    ["Jump Header"] = { air = "JumpHeader" },
    ["Running Header"] = { air = "RunningHeader" },
    ["Diving Header"] = { air = "DivingHeader" },
    ["Lob"] = { lob = true },
    ["Ronaldo Chop"] = { skill = { kind = "Flick", dir = "Away" } },
    ["Cruyff Turn"] = { skill = { kind = "Flick", dir = "Down" } },
    ["Knock-On"] = { skill = { kind = "Flick", dir = "Up" } },
    ["Elastico"] = { skill = { kind = "Elastico", dir = "Away" } },
    ["Rainbow Flick"] = { skill = { kind = "Rainbow", dir = "Up" } },
    ["Roulette"] = { skill = { kind = "Roll", dir = "Away", half = "Bottom" } },
    ["Step Over"] = { skill = { kind = "Roll", dir = "Away", half = "Top" } },
    ["Croqueta"] = { skill = { kind = "Hold", dir = "Away" } },
}

function CrystalHub.Functions.ForceFor(seconds)
    local F = CrystalHub.Force
    if not F then
        F = { Active = false, Until = 0 }
        CrystalHub.Force = F
    end
    F.Until = math.max(F.Until, os.clock() + seconds)
    if F.Active then return end
    local SA = getgenv().CrystalSilentAim
    local MP = getgenv().CrystalMaxPower
    F.Active = true
    SA.Enabled = true
    MP.Enabled = true
    task.spawn(function()
        while os.clock() < F.Until do
            task.wait(0.1)
        end
        SA.Enabled = SA.User == true
        MP.Enabled = MP.User == true
        F.Active = false
    end)
end

CrystalHub.ShotSpots = {
    ["Top Right Corner"] = { 0.97, 0.95 },
    ["Bottom Right Corner"] = { 0.97, 0.04 },
    ["Top Left Corner"] = { -0.97, 0.95 },
    ["Bottom Left Corner"] = { -0.97, 0.04 },
    ["Top Center"] = { 0, 0.95 },
    ["Bottom Center"] = { 0, 0.04 },
    ["Upper Right"] = { 0.62, 0.82 },
    ["Upper Left"] = { -0.62, 0.82 },
    ["Lower Right"] = { 0.62, 0.16 },
    ["Lower Left"] = { -0.62, 0.16 },
    ["Right Post"] = { 0.97, 0.5 },
    ["Left Post"] = { -0.97, 0.5 },
    ["Middle"] = { 0, 0.4 },
}

function CrystalHub.Functions.SegGap(p, a, b)
    local d = b - a
    local dd = d:Dot(d)
    local t = dd > 1e-9 and math.clamp((p - a):Dot(d) / dd, 0, 1) or 0
    return (p - (a + d * t)).Magnitude
end

function CrystalHub.Functions.KeeperKit()
    local H = CrystalHub
    if H.KeeperKitData then return H.KeeperKitData end
    if H.KeeperKitFail and os.clock() - H.KeeperKitFail < 5 then return nil end
    local ok, kit = pcall(function()
        local folder = Services.ReplicatedStorage:FindFirstChild("BotMatchKeeper")
        local reachModule = folder and folder:FindFirstChild("Reach")
        local configModule = folder and folder:FindFirstChild("Config")
        if not (reachModule and configModule) then return nil end
        local Reach = require(reachModule)
        local Config = require(configModule)
        local jumpLift = math.huge
        pcall(function()
            local sharedGame = Services.ReplicatedStorage.Shared.Game
            local animation = sharedGame:FindFirstChild("MannequinAnimation")
            local tuning = animation and animation:FindFirstChild("Tuning")
            if tuning then
                jumpLift = require(tuning).Dive.Jumping.Lift
            end
        end)
        local dives, reachX = {}, {}
        for _, dive in ipairs(Reach.dives) do
            if dive.block or not (dive.lift > jumpLift + 0.001) then
                local rows = {}
                for key, v in ipairs(dive.at) do
                    local body = Vector3.new(v[7], v[8], 0)
                    local legs
                    if dive.block then
                        legs = Vector3.new(body.X, math.max(body.Y - 4, 0.3), 0)
                    else
                        legs = Vector3.new(body.X - math.min(math.max(body.X, 0) * 0.6, 4.2), math.max(body.Y - 3.8, 0.3), 0)
                    end
                    rows[key] = { Vector3.new(v[1], v[2], 0), Vector3.new(v[3], v[4], 0), Vector3.new(v[5], v[6], 0), body, legs }
                    reachX[key] = math.max(reachX[key] or 0, v[1], v[3], v[5])
                end
                dives[#dives + 1] = { rows = rows, power = dive.power, lift = dive.lift, block = dive.block }
            end
        end
        if #dives == 0 then return nil end
        for i = 2, #reachX do
            reachX[i] = math.max(reachX[i], reachX[i - 1])
        end
        return {
            dives = dives,
            reachX = reachX,
            step = Reach.STEP,
            hand = Config.HandReach,
            arm = Config.ArmReach,
            body = Config.BodyReach,
            leg = Config.LegReach,
            shSpeed = Config.ShuffleSpeed,
            shAccel = Config.ShuffleAccel,
            react = Config.Reaction[1],
            cfg = Config,
        }
    end)
    if ok and type(kit) == "table" then
        H.KeeperKitData = kit
        return kit
    end
    H.KeeperKitFail = os.clock()
    return nil
end

task.spawn(CrystalHub.Functions.KeeperKit)

function CrystalHub.Functions.KeeperSave(lat, y, T, dist)
    local F = CrystalHub.Functions
    local kit = F.KeeperKit()
    T = math.max(T, 0)
    lat = math.abs(lat)
    if not kit then
        local gap = lat - (4.8 + 15 * T) - math.max(y - 6.5, 0) * 0.5
        return gap, gap <= 0 and 0.6 or 0
    end
    local cfg = kit.cfg
    local accel, speed = kit.shAccel, kit.shSpeed
    local q = speed / accel
    local segGap = F.SegGap
    local best = math.huge
    local bestCost = 1
    local need = math.huge
    local p1 = 0
    while p1 <= T + 1e-6 do
        local moved = p1 <= q and 0.5 * accel * p1 * p1 or 0.5 * accel * q * q + speed * (p1 - q)
        local pt = Vector3.new(math.max(lat - moved, 0), y, 0)
        local tm = T - p1
        for _, dive in ipairs(kit.dives) do
            local rows = dive.rows
            local n = #rows
            local t = math.clamp(tm / kit.step, 0, n - 1)
            local i = math.floor(t)
            local a = t - i
            local r1, r2 = rows[i + 1], rows[math.min(i + 2, n)]
            local h1, h2 = r1[1]:Lerp(r2[1], a), r1[2]:Lerp(r2[2], a)
            local e = r1[3]:Lerp(r2[3], a)
            local b1, b2 = r1[4]:Lerp(r2[4], a), r1[5]:Lerp(r2[5], a)
            local g = math.min((pt - h1).Magnitude, (pt - h2).Magnitude) - kit.hand
            g = math.min(g, segGap(pt, h1, e) - kit.arm, segGap(pt, h2, e) - kit.arm, segGap(pt, e, b1) - kit.body, segGap(pt, b1, b2) - kit.leg)
            local cost = dive.power + cfg.HighCost * dive.lift
            if g < best then
                best = g
                bestCost = cost
            end
            if p1 == 0 and g <= 0 and not dive.block and cost < need then
                need = cost
            end
        end
        p1 += 0.08
    end
    local save = 0
    if best <= 0 then
        if need == math.huge then need = bestCost end
        local t = math.clamp((dist - cfg.NearShot) / (cfg.FarShot - cfg.NearShot), 0, 1)
        save = cfg.SaveEasy - (cfg.SaveEasy - cfg.SaveHard) * math.clamp(need, 0, 1) ^ cfg.HardCurve + cfg.DistantBonus * t
        save = math.clamp(save, 0, 1)
        if dist >= cfg.SureFrom then save = 1 end
    end
    return best, save
end

function CrystalHub.Functions.KeeperAt(goal, from, keeper, kit)
    local cfg = kit and kit.cfg
    if not cfg then return keeper end
    local oX = -goal.out
    local dx, dz = from.X - goal.x, from.Z - goal.z
    local dist = math.sqrt(dx * dx + dz * dz)
    local ux, uz = oX, 0
    if dist > 1 then ux, uz = dx / dist, dz / dist end
    if ux * oX < 0.35 then
        local sign = uz >= 0 and 1 or -1
        if math.abs(uz) < 0.001 then sign = 0 end
        ux, uz = oX * 0.35, sign * 0.9367496997597597
    end
    local along = ux * oX
    local t = math.clamp((dist - cfg.NearBall) / (cfg.FarBall - cfg.NearBall), 0, 1)
    local depth = cfg.DepthNear + (cfg.DepthFar - cfg.DepthNear) * t
    local zMax = goal.half - cfg.PostInset
    local zOff = math.clamp(uz * depth / along, -zMax, zMax)
    local ballDepth = (goal.x - from.X) * goal.out
    local absZ = math.abs(from.Z - goal.z)
    if ballDepth <= 0.5 then
        depth = cfg.DepthTight
    elseif absZ > 0.001 then
        depth = math.clamp(math.abs(zOff) * ballDepth / absZ, cfg.DepthTight, depth)
    end
    local sx, sz = goal.x - goal.out * depth, goal.z + zOff
    local mx, mz = sx - keeper.X, sz - keeper.Z
    local md = math.sqrt(mx * mx + mz * mz)
    local travel = cfg.MoveSpeed * (cfg.Reaction[1] + cfg.Reaction[2]) * 0.5
    if md > travel then
        local f = travel / md
        mx, mz = mx * f, mz * f
    end
    return Vector3.new(keeper.X + mx, keeper.Y, keeper.Z + mz)
end

function CrystalHub.Functions.ShotTargets(goal, lob, radius)
    local F = CrystalHub.Functions
    local targets = SilentAimState.Targets
    if targets and #targets > 0 then
        local list = {}
        for _, name in ipairs(targets) do
            local p = F.ShotPoint(goal, name, radius)
            if p then list[#list + 1] = p end
        end
        if #list > 0 then return list, true end
    end
    return F.ShotAutoList(goal, lob, radius), false
end

function CrystalHub.Functions.PitchSolve(env, gy, from, point, speed, minA, maxA, lob, dt, bx, bz, bn, deadline, center)
    local F = CrystalHub.Functions
    local dx, dz = point.X - from.X, point.Z - from.Z
    local d = math.sqrt(dx * dx + dz * dz)
    if d < 1 then return nil end
    local ux, uz = dx / d, dz / d
    local spin = Vector3.new(0, 0, 0)
    local limitT = math.clamp(d / math.max(speed * 0.45, 6) + 0.8, 1, lob and 8 or 4.5)
    local lo, hi, iters = minA, maxA, 11
    if center then
        lo, hi, iters = math.max(minA, center - 0.05), math.min(maxA, center + 0.05), 8
    end
    local best
    for _ = 1, iters do
        if deadline and best and os.clock() > deadline then break end
        local th = (lo + hi) / 2
        local ct = math.cos(th)
        local vel = Vector3.new(ux * ct * speed, math.sin(th) * speed, uz * ct * speed)
        local c, ft, blocked = F.ShotFly(env, gy, from, vel, spin, limitT, bx, bz, bn, dt)
        if not c then
            if th > 0.6 then hi = th else lo = th end
        else
            local err = c.Y - point.Y
            local miss = math.abs(err)
            if not best or miss < best.miss then
                best = { vel = vel, miss = miss, ft = ft, blocked = blocked, c = c, th = th }
            end
            if miss < 0.04 then break end
            if err > 0 then hi = th else lo = th end
        end
    end
    if not best then return nil end
    return best.vel, spin, best.miss, best.ft, best.blocked, best.c, best.th
end

function CrystalHub.Functions.ShotBounds(env)
    local goal = env.Goal
    local clear = env.Radius + 0.1
    return goal.half - clear - 1.0, goal.ground + 0.3, goal.top - clear - 0.9
end

function CrystalHub.Functions.CrystalAimKeeper(goal)
    local keeper
    local best = math.huge
    for _, entry in ipairs(CrystalHub.Functions.MannequinSnapshot()) do
        if entry.keeper and entry.model ~= goal.char and type(entry.team) == "string" and entry.team ~= goal.team then
            local d = math.abs(entry.pos.X - goal.x)
            if d < best then
                best = d
                keeper = entry.pos
            end
        end
    end
    return keeper
end

function CrystalHub.Functions.TrickBinding(key)
    local bindings = CrystalHub.Bindings
    if not bindings then
        bindings = {}
        CrystalHub.Bindings = bindings
        CrystalHub.ConnectionController.Insert({ Disconnect = function()
            for _, b in pairs(bindings) do
                pcall(function() b:Destroy() end)
            end
        end })
    end
    local action = CrystalHub.Functions.GetKickAction(key)
    if not action then return nil end
    local binding = bindings[key]
    if not (binding and binding.Parent == action) then
        if binding then
            pcall(function() binding:Destroy() end)
        end
        binding = Instance.new("InputBinding")
        binding.Name = "CrystalTrick" .. key
        binding.Type = Enum.InputBindingType.Scriptable
        binding.Parent = action
        bindings[key] = binding
    end
    return binding
end

function CrystalHub.Functions.TrickViewApply()
    local V = CrystalHub.TrickView
    local cam = workspace.CurrentCamera
    if not (V and V.Active and cam) then return end
    local cf = cam.CFrame
    if not V.Saved then V.Saved = cf end
    local pos = cf.Position
    local target
    if V.Mode == "away" then
        target = pos + (V.Dir or Vector3.new(0, 0, -1)) * 20 + Vector3.new(0, 2, 0)
    else
        target = V.Point
    end
    if not target or (target - pos).Magnitude < 0.5 then return end
    cam.CFrame = CFrame.lookAt(pos, target)
end

function CrystalHub.Functions.InstallTrickView()
    if CrystalHub.TrickView then return end
    local V = { Active = false, Mode = "goal", Until = 0 }
    CrystalHub.TrickView = V
    local names = { "CrystalViewEarly", "CrystalViewBegin", "CrystalViewEnd" }

    local function restore()
        local cam = workspace.CurrentCamera
        if V.Saved and cam then
            cam.CFrame = V.Saved
        end
        V.Saved = nil
    end

    for _, name in ipairs(names) do
        pcall(function() RunService:UnbindFromRenderStep(name) end)
    end
    RunService:BindToRenderStep("CrystalViewEarly", Enum.RenderPriority.First.Value, restore)
    RunService:BindToRenderStep("CrystalViewBegin", Enum.RenderPriority.Input.Value + 2, function()
        if V.Active and os.clock() > V.Until then
            V.Active = false
        end
        if V.Active then
            CrystalHub.Functions.TrickViewApply()
        end
    end)
    RunService:BindToRenderStep("CrystalViewEnd", Enum.RenderPriority.Input.Value + 9, restore)
    CrystalHub.ConnectionController.Insert({ Disconnect = function()
        for _, name in ipairs(names) do
            pcall(function() RunService:UnbindFromRenderStep(name) end)
        end
        restore()
        V.Active = false
        CrystalHub.TrickView = nil
    end })
end

function CrystalHub.Functions.TrickViewSet(mode, value, seconds)
    local F = CrystalHub.Functions
    F.InstallTrickView()
    local V = CrystalHub.TrickView
    V.Mode = mode
    if mode == "away" then
        V.Dir = value
    else
        V.Point = value
    end
    V.Active = true
    V.Until = os.clock() + seconds
    F.TrickViewApply()
end

function CrystalHub.Functions.TrickViewPush(st)
    local F = CrystalHub.Functions
    if st.Mode == "away" and st.Goal then
        F.TrickViewSet("away", Vector3.new(-st.Goal.out, 0, 0), 0.3)
    elseif st.Point then
        F.TrickViewSet("goal", st.Point, 0.3)
    end
end

function CrystalHub.Functions.TrickFire(key, point, hold)
    local F = CrystalHub.Functions
    local binding = F.TrickBinding(key)
    if not binding then
        F.Debug("kick action not found")
        return false
    end
    F.ForceFor(2.5)
    CrystalHub.TrickActive = true
    CrystalHub.TrickKey = key
    F.TrickViewSet("goal", point, hold + 0.8)
    binding:Fire(true)
    task.delay(hold, function()
        F.TrickViewSet("goal", point, 0.8)
        pcall(function() binding:Fire(false) end)
        task.delay(0.9, function()
            CrystalHub.TrickActive = false
            CrystalHub.TrickKey = nil
        end)
    end)
    F.Debug("fired " .. key)
    return true
end

function CrystalHub.Functions.TrickReady()
    local char = LocalPlayer.Character
    if not char then return nil end
    local team = char:GetAttribute("Team")
    if team ~= "Blue" and team ~= "Red" then return nil end
    if char:GetAttribute("Role") == "Goalkeeper" then return nil end
    local bodyState = char:GetAttribute("BodyState")
    if bodyState ~= nil and bodyState ~= "Animated" then return nil end
    local hold = LocalPlayer:GetAttribute("KickoffHold")
    if type(hold) == "number" and hold > workspace:GetServerTimeNow() then return nil end
    local root = char:FindFirstChild("Root")
    local ball = CrystalHub.Functions.GetBall()
    if not (root and ball) then return nil end
    local goal = CrystalHub.Functions.SilentAimGoal()
    if not goal then return nil end
    return char, root, ball, goal
end

function CrystalHub.Functions.AutoPossessed(st, S, T, goal, goalDist, now)
    local F = CrystalHub.Functions
    local SA = getgenv().CrystalSilentAim
    local forced = T.Enabled and T.Auto == false
    local lobForced = forced and T.Lob == true
    if not (S.Enabled or lobForced) or goalDist > S.Range or goalDist < 3 then
        st.Next = now + 0.3
        return
    end
    local from = SA.BallView.getPosition()
    if not from then return end
    local budget = F.Budget(0.003)
    local shot
    if not lobForced then
        shot = F.ShotBest(from, "Laced", false, budget)
        if shot and shot.fallback then shot = nil end
    end
    local lob
    local gap = 0
    if lobForced then
        lob = F.ShotBest(from, "Lofted", true, budget)
        if lob and lob.fallback then lob = nil end
    elseif T.Enabled and not forced and goalDist > 14 then
        local keeper = F.CrystalAimKeeper(goal)
        gap = keeper and math.abs(keeper.X - goal.x) or 0
        if gap > 8 or not shot then
            lob = F.ShotBest(from, "Lofted", true, budget)
            if lob and lob.fallback then lob = nil end
        end
    end
    local useLob = lob ~= nil and (lobForced or shot == nil or gap > 8)
    local result = useLob and lob or shot
    if not result then
        F.Debug("no clear shot from here")
        st.Next = now + 0.35
        return
    end
    CrystalHub.ShotLast = result
    st.Next = now + 1.6
    CrystalHub.ShotNext = now + 1.6
    F.TrickFire(useLob and "KickLob" or "KickStrike", result.point, getgenv().CrystalMaxPower.Hooked and 0.06 or 0.46)
end

function CrystalHub.Functions.AutoAir(st, T, char, root, ball, goal, goalDist, now)
    local F = CrystalHub.Functions
    local SA = getgenv().CrystalSilentAim
    if goalDist > T.Range then return end
    local bp, rp = ball.Position, root.Position
    local delta = Vector3.new(bp.X - rp.X, 0, bp.Z - rp.Z)
    if delta.Magnitude > 90 then return end
    local id = char:GetAttribute("DribbleId")
    if ball:GetAttribute("ReleasedBy") == id then
        local at = ball:GetAttribute("ReleasedAt")
        if type(at) == "number" and workspace:GetServerTimeNow() - at < 0.8 then return end
    end
    local pos, vel = SA.BallView.freeState()
    if typeof(pos) ~= "Vector3" or typeof(vel) ~= "Vector3" then return end
    local gy = SA.BallView.groundBallY(pos)
    if pos.Y - gy < 0.9 and math.abs(vel.Y) < 3 then return end
    local best, bike, groundY, sampleNow, cands = F.TrickScanAir(st, root, goal)
    if not best then return end
    local cand, mode, family = F.TrickChoose(st, char, root, goal, best, bike, cands, groundY, sampleNow)
    if not cand or not family then return end
    local result = F.ShotBest(cand.pos, family, false, F.Budget(0.006), -0.95)
    if not result or result.fallback then
        st.Fail = st.Fail or {}
        st.Fail[family] = now + 0.6
        st.Next = now + 0.08
        return
    end
    local binding = F.TrickBinding("KickStrike")
    if not binding then
        st.Next = now + 0.5
        return
    end
    st.Point = result.point
    st.Phase = "air"
    st.Start = now
    st.Mode = mode
    st.LockFamily = family
    st.Binding = binding
    st.Goal = goal
    st.Cand = { t = cand.t, at = now }
    st.ScanAt = now + 0.08
    st.Lost = 0
    st.Seen = false
    st.LastAir = family
    CrystalHub.TrickActive = true
    CrystalHub.ShotNext = now + 0.9
    CrystalHub.TrickLock = { Name = family, Until = now + 1.6 }
    F.ForceFor(2.2)
    F.TrickViewPush(st)
    binding:Fire(true)
    F.Debug("holding for " .. family)
end

function CrystalHub.Functions.AutoStep(st, now)
    local F = CrystalHub.Functions
    if st.Phase == "tail" then
        F.TrickViewPush(st)
        local started = F.TrickStarted()
        if started then
            st.Seen = true
            CrystalHub.TrickLock = nil
        end
        local over
        if st.Seen then
            over = (not started and now - st.ReleaseAt > 0.3) or now >= st.ReleaseAt + 2.2
        else
            over = now >= st.TailUntil
        end
        if over then
            if not st.Seen then
                st.Fail = st.Fail or {}
                if st.LockFamily then st.Fail[st.LockFamily] = now + 0.9 end
                CrystalHub.ShotNext = now
            end
            st.Phase = nil
            st.LockFamily = nil
            CrystalHub.TrickLock = nil
            CrystalHub.TrickActive = false
            st.Next = now + (st.Seen and 0.5 or 0.12)
        end
        return
    end
    local leads = {
        Bicycle = 1.0,
        DivingHeader = 0.95,
        JumpHeader = 0.95,
        RunningHeader = 0.85,
        Header = 0.65,
        Volley = 0.6,
        SideVolley = 0.65,
    }
    local family = st.LockFamily
    local release = false
    local char, root, ball, goal = F.TrickReady()
    if char then
        st.Goal = goal
        local possessor = ball:GetAttribute("Possessor")
        if type(possessor) == "number" and possessor ~= 0 then
            release = true
        elseif now >= st.ScanAt then
            st.ScanAt = now + 0.08
            local best, bike, groundY, sampleNow, cands = F.TrickScanAir(st, root, goal)
            local cand
            if best then
                cand = F.TrickChoose(st, char, root, goal, best, bike, cands, groundY, sampleNow)
            end
            if cand then
                st.Lost = 0
                st.Cand = { t = cand.t, at = now }
            else
                st.Lost += 1
                if st.Lost >= 5 then release = true end
            end
        end
        local elapsed = now - st.Start
        local remaining = st.Cand.t - (now - st.Cand.at)
        local minHold = getgenv().CrystalMaxPower.Hooked and 0.08 or 0.3
        if elapsed >= minHold and remaining <= (leads[family] or 0.7) then release = true end
        if elapsed >= 1.3 then release = true end
    else
        release = true
    end
    F.TrickViewPush(st)
    if release then
        pcall(function() st.Binding:Fire(false) end)
        st.Phase = "tail"
        st.ReleaseAt = now
        st.TailUntil = now + 1.25
        st.Seen = false
        CrystalHub.ShotNext = now + 0.8
        if CrystalHub.TrickLock then
            CrystalHub.TrickLock.Until = now + 1.2
        end
    end
end

function CrystalHub.Functions.AutoTick(st)
    local F = CrystalHub.Functions
    local now = os.clock()
    if st.Phase then
        F.AutoStep(st, now)
        return
    end
    local S = getgenv().CrystalAutoShoot
    local T = getgenv().CrystalAutoTricks
    if not (S.Enabled or T.Enabled) then return end
    if now < st.Next or now < (CrystalHub.ShotNext or 0) then return end
    local char, root, ball, goal = F.TrickReady()
    if not char then
        F.Debug("not ready: no match body, ball or goal")
        return
    end
    if not F.SilentAimModules() then
        F.Debug("kick modules missing")
        return
    end
    local goalDist = Vector3.new(goal.x - root.Position.X, 0, goal.z - root.Position.Z).Magnitude
    local id = char:GetAttribute("DribbleId")
    local possessor = ball:GetAttribute("Possessor")
    if type(possessor) == "number" and possessor ~= 0 then
        if possessor ~= id then return end
        if T.Enabled and F.AutoSkill(st, char, root, goalDist, now) then return end
        F.AutoPossessed(st, S, T, goal, goalDist, now)
    elseif T.Enabled then
        if now < st.ScanAt then return end
        st.ScanAt = now + 0.1
        F.AutoAir(st, T, char, root, ball, goal, goalDist, now)
    end
end

function CrystalHub.Functions.SkillModule()
    local cached = CrystalHub.SkillRef
    if cached then return cached end
    local ok, mod = pcall(function()
        local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
        local client = scripts and scripts:FindFirstChild("Client")
        local gameFolder = client and client:FindFirstChild("Game")
        local skill = gameFolder and gameFolder:FindFirstChild("SkillMoves")
        local playback = skill and skill:FindFirstChild("Playback")
        return playback and require(playback)
    end)
    if ok and type(mod) == "table" and type(mod.request) == "function" then
        CrystalHub.SkillRef = mod
        return mod
    end
    return nil
end

function CrystalHub.Functions.SkillThreat(char, root, range)
    local team = char:GetAttribute("Team")
    if type(team) ~= "string" then return nil end
    local rp = root.Position
    local vel = root.AssemblyLinearVelocity
    local fx, fz = vel.X, vel.Z
    local sp = math.sqrt(fx * fx + fz * fz)
    if sp < 3 then
        local look = root.CFrame.LookVector
        fx, fz = look.X, look.Z
        sp = math.sqrt(fx * fx + fz * fz)
        if sp < 0.001 then return nil end
    end
    local ux, uz = fx / sp, fz / sp
    local best
    for _, e in ipairs(CrystalHub.Functions.MannequinSnapshot()) do
        if e.model ~= char and type(e.team) == "string" and e.team ~= team then
            local dx, dz = e.pos.X - rp.X, e.pos.Z - rp.Z
            local d = math.sqrt(dx * dx + dz * dz)
            if d > 0.5 and d <= range then
                local ahead = (dx * ux + dz * uz) / d
                if ahead > -0.15 and (not best or d < best.d) then
                    best = { d = d, ahead = ahead, side = ux * dz - uz * dx }
                end
            end
        end
    end
    return best
end

function CrystalHub.Functions.SkillPick(speed, d, ahead, side, last)
    local away = side > 0 and "Left" or "Right"
    local list = {}
    local function add(kind, dir, half, weight)
        local key = kind .. dir .. (half or "")
        if key == last then weight *= 0.18 end
        if weight > 0 then
            list[#list + 1] = { kind = kind, dir = dir, half = half, weight = weight }
        end
    end
    if speed < 9 then
        add("Flick", away, nil, 5)
        add("Elastico", away, nil, 2)
        if ahead > 0.45 then add("Hold", away, nil, 3) end
    else
        add("Elastico", away, nil, ahead > 0.5 and 6 or 4)
        add("Roll", away, "Bottom", 5)
        add("Roll", away, "Top", 4)
        add("Flick", away, nil, ahead < 0.5 and 6 or 3)
        if d < 7.5 and d > 3.2 and ahead > 0.62 and speed >= 14 and speed <= 36 then
            add("Rainbow", "Up", nil, 7)
        end
        if speed < 22 and d < 6 then add("Flick", "Down", nil, 2) end
    end
    local sum = 0
    for _, entry in ipairs(list) do sum += entry.weight end
    if sum <= 0 then return nil end
    local roll = math.random() * sum
    for _, entry in ipairs(list) do
        roll -= entry.weight
        if roll <= 0 then return { kind = entry.kind, dir = entry.dir, half = entry.half } end
    end
    local e = list[#list]
    return { kind = e.kind, dir = e.dir, half = e.half }
end

function CrystalHub.Functions.TrySkill(st, gesture, speed, now, cooldown)
    if not gesture or now < (CrystalHub.SkillUntil or 0) then return false end
    local play = CrystalHub.Functions.SkillModule()
    if not play then return false end
    if type(play.busy) == "function" then
        local ok, busy = pcall(play.busy)
        if not ok or busy then return false end
    end
    local ok, label = pcall(play.request, gesture, speed)
    if not ok or not label then return false end
    CrystalHub.SkillUntil = now + (cooldown or 0.75)
    st.Last = gesture.kind .. gesture.dir .. (gesture.half or "")
    CrystalHub.Functions.Debug("skill " .. tostring(label))
    return true
end

function CrystalHub.Functions.AutoSkill(st, char, root, goalDist, now)
    local F = CrystalHub.Functions
    local T = getgenv().CrystalAutoTricks
    local forced = T.Auto == false
    if forced and #(T.Skills or {}) == 0 then return false end
    if now < (st.SkillNext or 0) or goalDist < 18 then return false end
    if CrystalHub.AutoDribble and getgenv().CrystalAutoDribble.Enabled then return false end
    local vel = root.AssemblyLinearVelocity
    local myVel = Vector3.new(vel.X, 0, vel.Z)
    local speed = myVel.Magnitude
    local look = root.CFrame.LookVector
    local facing = speed > 4 and myVel / speed or Vector3.new(look.X, 0, look.Z)
    if facing.Magnitude < 0.01 then return false end
    local f = facing.Unit
    local threats = F.DribbleThreats(char, root.Position, f, myVel, (T.Defender or 14) + 2)
    local p = threats[1]
    if not p then return false end
    if p.ahead < -0.15 and p.d > 5 then return false end
    if not (p.ttc <= 0.7 or p.d <= 8) then return false end
    local gesture
    if forced then
        gesture = F.SkillForced(p.side)
    else
        local crowd = 0
        for _, t in ipairs(threats) do
            if t.d <= 14 then crowd += 1 end
        end
        gesture = F.DribblePick(speed, p, threats, crowd, st.Last, 2.8)
    end
    local rainbow = gesture and gesture.kind == "Rainbow"
    local success = F.TrySkill(st, gesture, speed, now, rainbow and 1.1 or 0.8)
    st.SkillNext = now + (success and (rainbow and 1.4 or 0.95) or 0.25)
    if success then
        st.Next = now + 0.5
        return true
    end
    return false
end

function CrystalHub.Functions.AutoEngineStart()
    local F = CrystalHub.Functions
    if CrystalHub.Auto then return true end
    if not CrystalHub.TrickMods then
        pcall(function()
            local sharedGame = Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
            local Kick = require(sharedGame:WaitForChild("Kick"))
            local Dribble = require(sharedGame:WaitForChild("Dribble"))
            local gameFolder = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Game")
            CrystalHub.TrickMods = {
                Bicycle = Kick.Bicycle,
                Families = Kick.Families,
                Rules = Dribble.Rules,
                Radius = Dribble.Rules.BALL_RADIUS,
                GameCamera = require(gameFolder:WaitForChild("GameCamera")),
                BallView = require(gameFolder:WaitForChild("BallView")),
            }
        end)
    end
    local st = { Acc = 0, Next = 0, ScanAt = 0, Mods = CrystalHub.TrickMods }
    CrystalHub.Auto = st
    F.InstallTrickView()
    st.Conn = RunService.Heartbeat:Connect(function(dt)
        st.Acc += dt
        local slow = F.Budget(1) < 1 and 1.5 or 1
        if st.Acc < (st.Phase and 0.04 or 0.12) * slow then return end
        st.Acc = 0
        local S, T = getgenv().CrystalAutoShoot, getgenv().CrystalAutoTricks
        if not st.Phase and not (S.Enabled or T.Enabled) then return end
        local ok, err = pcall(F.AutoTick, st)
        if not ok then
            F.Debug("error: " .. tostring(err))
            if st.Phase == "air" then
                pcall(function() st.Binding:Fire(false) end)
                st.Phase = nil
                CrystalHub.TrickActive = false
                st.Next = os.clock() + 1
            end
        end
    end)
    CrystalHub.ConnectionController.Insert(st.Conn)
    CrystalHub.ConnectionController.Insert({ Disconnect = function()
        CrystalHub.Functions.AutoEngineStop()
    end })
    return true
end

function CrystalHub.Functions.AutoEngineStop()
    local st = CrystalHub.Auto
    CrystalHub.Auto = nil
    if st then
        if st.Conn then
            pcall(function() st.Conn:Disconnect() end)
        end
        if st.Binding and st.Phase == "air" then
            pcall(function() st.Binding:Fire(false) end)
        end
    end
    CrystalHub.Functions.ReleaseAllBindings()
end

function CrystalHub.Functions.TrickScanAir(st, root, goal)
    local F = CrystalHub.Functions
    local SA = getgenv().CrystalSilentAim
    local BV = SA.BallView
    local state, shift = BV.freeSim()
    if not state then return nil end
    local ball = BV.getBall()
    if not ball then return nil end
    local params = SA.Flight.params(ball)
    local groundY = BV.groundBallY(state.pos)
    local list = F.ShotPredict(params, state.pos, state.vel, state.spin, groundY, 1.5, 1 / 30)
    local rp = root.Position
    local rvel = root.AssemblyLinearVelocity
    local rv = Vector3.new(rvel.X, 0, rvel.Z)
    local mouth = { x = goal.x, z = goal.z, halfWidth = goal.half, top = goal.top, ground = goal.ground, out = goal.out }
    local best, bike
    local cands = {}
    for _, e in ipairs(list) do
        local p = e.pos
        if (goal.x - p.X) * goal.out < 0 then break end
        local h = p.Y - groundY
        if e.t >= 0.2 and h >= 0.9 and h <= 14.2 then
            local reach = rp + rv * math.min(e.t, 0.6)
            local dx, dz = p.X - reach.X, p.Z - reach.Z
            local r = math.min(5 + 14 * e.t, 13)
            if dx * dx + dz * dz <= r * r then
                local cand = { t = e.t, pos = p, h = h }
                cands[#cands + 1] = cand
                best = best or cand
                if not bike and h >= 8.2 and h <= 11.3 and st.Mods and st.Mods.Bicycle.inZone(Vector3.new(p.X, 0, p.Z), { mouth }, 1.5) then
                    bike = cand
                end
            end
        end
    end
    if not best then return nil end
    return best, bike, groundY, workspace:GetServerTimeNow() - shift, cands
end

function CrystalHub.Functions.TrickBicycleOk(st, char, root, goal, sampleNow, groundY)
    local M = st.Mods
    if not M then return true end
    local ok, result = pcall(function()
        local cm = char:FindFirstChild("ControllerManager")
        local gc = cm and cm:FindFirstChild("GroundController")
        if not (cm and gc) then return true end
        local look = root.CFrame.LookVector
        local pos = root.Position
        local vel = root.AssemblyLinearVelocity
        local mouth = { x = goal.x, z = goal.z, halfWidth = goal.half, top = goal.top, ground = goal.ground, out = goal.out }
        local aim = M.Bicycle.aimFor(pos, Vector3.new(-goal.out, 0, 0), mouth)
        local locked = M.GameCamera.isLocked()
        local data = {
            now = sampleNow,
            pos = Vector3.new(pos.X, 0, pos.Z),
            vel = Vector3.new(vel.X, 0, vel.Z),
            facing = Vector3.new(look.X, 0, look.Z),
            leg = 2,
            maxLead = 1.45,
            canTurn = not locked,
            target = cm.MovingDirection * cm.BaseMoveSpeed,
            topSpeed = cm.BaseMoveSpeed,
            accelTime = gc.AccelerationTime,
            decelTime = gc.DecelerationTime,
            turn = (not locked) and M.Rules.Turn or nil,
            ballAt = function(t)
                local p, v = M.BallView.freeSample(t)
                return p, v
            end,
            pitchY = groundY - M.Radius,
            aimDir = aim.dir,
            aimPoint = aim.point,
            family = M.Families.Bicycle,
            zone = function(a)
                return M.Bicycle.inZone(a, { mouth })
            end,
        }
        return M.Bicycle.find(data) ~= nil
    end)
    return ok and result == true
end

function CrystalHub.Functions.StartAutoTricks()
    pcall(CrystalHub.Functions.InstallTrickFilter)
    return CrystalHub.Functions.AutoEngineStart()
end

function CrystalHub.Functions.StopAutoTricks()
    CrystalHub.TrickLock = nil
    if not getgenv().CrystalAutoShoot.Enabled then
        CrystalHub.Functions.AutoEngineStop()
    end
end

getgenv().CrystalSilentAim.Targets = {}
getgenv().CrystalSilentAim.TargetKey = "Auto"
getgenv().CrystalSilentAim.Range = 300
CrystalHub.ShotIgnore = { SideFoot = true, PushPass = true, VolleyPass = true, VolleyPush = true }
CrystalHub.ShotLobs = { Lofted = true, Chip = true }
CrystalHub.ShotSeeds = {}
CrystalHub.ShotCache = {}
CrystalHub.ShotCursor = {}
CrystalHub.ShotFamily = nil
CrystalHub.ShotFamilyAt = 0
CrystalHub.PreviewCache = nil
CrystalHub.ShotHint = nil
CrystalHub.DebugOn = false

function CrystalHub.Functions.SetSilentTargets(value)
    local SA = getgenv().CrystalSilentAim
    local list = {}
    local auto = false
    if type(value) == "table" then
        for k, v in pairs(value) do
            local name = type(v) == "string" and v or (type(k) == "string" and v == true and k) or nil
            if name then
                if name == "Auto" then auto = true end
                list[#list + 1] = name
            end
        end
    elseif type(value) == "string" then
        if value == "Auto" then auto = true end
        list[1] = value
    end
    if auto or #list == 0 then
        SA.Targets = {}
        SA.TargetKey = "Auto"
    else
        table.sort(list)
        SA.Targets = list
        SA.TargetKey = table.concat(list, ",")
    end
    table.clear(CrystalHub.ShotCache)
end

function CrystalHub.Functions.Debug(message)
    if not CrystalHub.DebugOn then return end
    local now = os.clock()
    if now - (CrystalHub.DebugAt or 0) < 1.2 then return end
    CrystalHub.DebugAt = now
    warn("[CrystalHub] " .. tostring(message))
end

function CrystalHub.Functions.ShotEnv()
    local F = CrystalHub.Functions
    local SA = getgenv().CrystalSilentAim
    if not F.SilentAimModules() then return nil end
    local ball = SA.BallView.getBall()
    if not ball then return nil end
    local goal = F.SilentAimGoal()
    if not goal then return nil end
    if not SA.Radius then
        local ok, r = pcall(function()
            return require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Dribble")).Rules.BALL_RADIUS
        end)
        SA.Radius = (ok and type(r) == "number") and math.clamp(r, 0.5, 2) or 1.1
    end
    local env = CrystalHub.ShotEnvCache
    local now = os.clock()
    if not env or env.Ball ~= ball or now - env.At > 0.5 then
        env = { Ball = ball, Params = SA.Flight.params(ball), At = now }
        CrystalHub.ShotEnvCache = env
    end
    env.Goal = goal
    env.Radius = SA.Radius
    return env
end

function CrystalHub.Functions.ShotBodies(goal, lob)
    local bx, bz, n = {}, {}, 0
    if lob then return bx, bz, 0 end
    for _, entry in ipairs(CrystalHub.Functions.MannequinSnapshot()) do
        if entry.model ~= goal.char and not entry.keeper then
            n += 1
            bx[n] = entry.pos.X
            bz[n] = entry.pos.Z
        end
    end
    return bx, bz, n
end

function CrystalHub.Functions.ShotSolve(env, gy, from, point, speed, curve, minA, maxA, key, bx, bz, bn, lob, stepDt, iters, deadline)
    local F = CrystalHub.Functions
    local fx, fz = point.X - from.X, point.Z - from.Z
    local d = math.sqrt(fx * fx + fz * fz)
    if d < 2 then return nil end
    local dx, dz = fx / d, fz / d
    local side = Vector3.new(-dz, 0, dx)
    local spin = Vector3.new(0, curve, 0)
    local limitT = math.clamp(d / math.max(speed * 0.45, 6) + 0.8, 1, lob and 8 or 4.5)
    local dt = stepDt or (lob and 1 / 45 or 1 / 60)
    local gravity = env.Params.gravity
    local pY = point.Y
    local pL = point.X * side.X + point.Z * side.Z
    local seeds = CrystalHub.ShotSeeds
    local seed = seeds[key]
    if seed and ((seed[3] - from).Magnitude > 8 or math.abs(seed[4] - speed) > 2 or math.abs(seed[5] - curve) > 2) then
        seed = nil
    end
    if not seed then
        local hint = CrystalHub.ShotHint
        if hint
            and hint[12] == lob
            and (hint[3] - from).Magnitude < 8
            and math.abs(hint[4] - speed) < 2
            and math.abs(hint[5] - curve) < 2
            and hint[10] * dx + hint[11] * dz > 0.7 then
            seed = hint
        end
    end
    local th, ps, a11, a12, a21, a22
    if seed then
        th, ps, a11, a12, a21, a22 = seed[1], seed[2], seed[6], seed[7], seed[8], seed[9]
    else
        local q = d / speed * 1.12
        th = math.atan2(pY - from.Y + gravity * 0.5 * q * q, math.max(d, 1))
        ps = 0
        if curve ~= 0 then
            local mag = math.min(0.5164 * math.abs(curve) / speed, 0.3) * 0.0541 * 0.213 * speed * speed * (env.Params.curve or 1)
            local tf = d / (speed * 0.8)
            ps = -(curve > 0 and 1 or -1) * math.clamp(0.5 * mag * tf * tf / d, 0, 0.45)
        end
        a11, a12, a21, a22 = d * 1.05, 0, 0, -d
    end
    local maxIter = iters or 8
    local bestMiss = math.huge
    local bestVel, bestT, bestB, bestC, bestTh, bestPs
    local pu1, pu2, pg1, pg2
    local nils = 0
    for i = 1, maxIter do
        if deadline and i > 1 and os.clock() > deadline then break end
        th = math.clamp(th, minA, maxA)
        local cs, sn = math.cos(ps), math.sin(ps)
        local fdx, fdz = dx * cs + dz * sn, -dx * sn + dz * cs
        local ct = math.cos(th)
        local vel = Vector3.new(fdx * ct * speed, math.sin(th) * speed, fdz * ct * speed)
        local c, ft, blocked = F.ShotFly(env, gy, from, vel, spin, limitT, bx, bz, bn, dt)
        if not c then
            nils += 1
            pu1 = nil
            th += (nils % 2 == 1) and 0.12 or -0.26
        else
            local g1 = c.Y
            local g2 = c.X * side.X + c.Z * side.Z
            local r1, r2 = g1 - pY, g2 - pL
            local miss = math.sqrt(r1 * r1 + r2 * r2)
            if miss < bestMiss then
                bestMiss, bestVel, bestT, bestB, bestC, bestTh, bestPs = miss, vel, ft, blocked, c, th, ps
            end
            if miss < 0.08 then break end
            if pu1 then
                local du1, du2 = th - pu1, ps - pu2
                local dd = du1 * du1 + du2 * du2
                if dd > 1e-8 then
                    local e1 = (g1 - pg1) - (a11 * du1 + a12 * du2)
                    local e2 = (g2 - pg2) - (a21 * du1 + a22 * du2)
                    a11 += e1 * du1 / dd
                    a12 += e1 * du2 / dd
                    a21 += e2 * du1 / dd
                    a22 += e2 * du2 / dd
                end
            end
            pu1, pu2, pg1, pg2 = th, ps, g1, g2
            local det = a11 * a22 - a12 * a21
            if det > -d * d * 0.05 then
                a11, a12, a21, a22 = d * 1.05, 0, 0, -d
                det = a11 * a22
            end
            local s1 = -(a22 * r1 - a12 * r2) / det
            local s2 = -(-a21 * r1 + a11 * r2) / det
            local m = math.max(math.abs(s1), math.abs(s2))
            if m > 0.25 then
                s1, s2 = s1 * 0.25 / m, s2 * 0.25 / m
            end
            th += s1
            ps = math.clamp(ps + s2, -0.7, 0.7)
        end
    end
    if not bestVel then return nil end
    seeds[key] = { bestTh, bestPs, from, speed, curve, a11, a12, a21, a22 }
    CrystalHub.ShotHint = { bestTh, bestPs, from, speed, curve, a11, a12, a21, a22, dx, dz, lob }
    return bestVel, spin, bestMiss, bestT, bestB, bestC
end

function CrystalHub.Functions.DribbleThreats(char, rp, f, myVel, range)
    local team = char:GetAttribute("Team")
    local serverNow = workspace:GetServerTimeNow()
    local list = {}
    for _, model in ipairs(Services.CollectionService:GetTagged("MannequinCharacter")) do
        if model ~= char and model:IsA("Model") and model:GetAttribute("Team") ~= team and model:GetAttribute("AIGoalie") == nil then
            local state = model:GetAttribute("BodyState")
            local r = model:FindFirstChild("Root")
            if r and r:IsA("BasePart") and (state == nil or state == "Animated") then
                local rel = r.Position - rp
                local flat = Vector3.new(rel.X, 0, rel.Z)
                local d = flat.Magnitude
                if d > 1 and d <= range then
                    local dir = flat / d
                    local ahead = f:Dot(dir)
                    if ahead > -0.15 or d <= 6.5 then
                        local ov = r.AssemblyLinearVelocity
                        local vel = Vector3.new(ov.X, 0, ov.Z)
                        local closing = (myVel - vel):Dot(dir)
                        local ttc = closing > 1 and math.max(d - 2.8, 0) / closing or math.huge
                        local ready = true
                        local plr = Players:GetPlayerFromCharacter(model)
                        if plr then
                            local ra = plr:GetAttribute("PokeReadyAt")
                            if type(ra) == "number" and ra > serverNow + 0.2 then ready = false end
                        end
                        list[#list + 1] = {
                            model = model,
                            d = d,
                            dir = dir,
                            ahead = ahead,
                            side = f.X * dir.Z - f.Z * dir.X,
                            closing = closing,
                            ttc = ttc,
                            ready = ready,
                            eff = d - math.max(closing, 0) * 0.25,
                        }
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.eff < b.eff end)
    return list
end

function CrystalHub.Functions.TrickStarted()
    local F = CrystalHub.Functions
    local mod = F.MannequinClientModule()
    local char = LocalPlayer.Character
    if not (mod and char) then return false end
    local ok, anim = pcall(mod.getAnimator, char)
    if not (ok and anim) then return false end
    for _, key in ipairs({ "kickS", "headS", "bikeS", "diveS" }) do
        local s = anim[key]
        if s and not s.done then return true end
    end
    return false
end

function CrystalHub.Functions.DribblePick(speed, p, threats, crowd, last, rare)
    rare = rare or 1
    local sideSum = 0
    for _, t in ipairs(threats) do
        if t.d <= 14 and t.ahead > -0.3 then
            sideSum += (t.side >= 0 and 1 or -1) / math.max(t.d, 1)
        end
    end
    if sideSum == 0 then sideSum = p.side end
    local away = sideSum > 0 and "Left" or "Right"
    local d, ahead = p.d, p.ahead
    local list = {}
    local function add(kind, dir, half, weight)
        local key = kind .. dir .. (half or "")
        if key == last then weight *= 0.18 end
        if weight > 0 then
            list[#list + 1] = { kind = kind, dir = dir, half = half, weight = weight }
        end
    end
    if ahead < -0.15 then
        add("Hold", away, nil, 6)
        add("Roll", away, "Bottom", 5)
        add("Flick", away, nil, 3)
    elseif speed < 8 then
        add("Flick", away, nil, 5)
        add("Elastico", away, nil, 3)
        if ahead > 0.45 then add("Hold", away, nil, 4) end
        if d < 5 then add("Flick", "Down", nil, 2) end
    else
        if d <= 4.2 then
            add("Roll", away, "Bottom", 6)
            add("Elastico", away, nil, 5)
            add("Flick", away, nil, 4)
            if speed < 22 then add("Flick", "Down", nil, 3) end
        else
            add("Elastico", away, nil, ahead > 0.5 and 6 or 4)
            add("Roll", away, "Bottom", 5)
            add("Roll", away, "Top", 4)
            add("Flick", away, nil, ahead < 0.5 and 6 or 3)
        end
        local wide = rare > 1
        if d < (wide and 9 or 7.5) and d > (wide and 3 or 3.2) and ahead > (wide and 0.5 or 0.62) and speed >= (wide and 12 or 14) and speed <= (wide and 38 or 36) then
            add("Rainbow", "Up", nil, (crowd >= 2 and 9 or 7) * rare)
        end
        if crowd >= 2 and d < 8 then
            add("Hold", away, nil, 3)
        end
        if math.abs(p.side) > 0.7 then
            add("Roll", away, "Top", 4)
        end
    end
    local sum = 0
    for _, e in ipairs(list) do sum += e.weight end
    if sum <= 0 then return nil end
    local roll = math.random() * sum
    for _, e in ipairs(list) do
        roll -= e.weight
        if roll <= 0 then return { kind = e.kind, dir = e.dir, half = e.half } end
    end
    local e = list[#list]
    return { kind = e.kind, dir = e.dir, half = e.half }
end

function CrystalHub.Functions.ShotGate(from)
    local goal = CrystalHub.Functions.SilentAimGoal()
    if not goal then return nil end
    if (from.X - goal.x) * goal.out >= 0 then return nil end
    local dx, dz = goal.x - from.X, goal.z - from.Z
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist < 1.5 then return nil end
    local range = SilentAimState.Range or 300
    if range < 300 and dist > range then return nil end
    return goal
end

function CrystalHub.Functions.ShotPoint(goal, mode, radius)
    local spot = CrystalHub.ShotSpots[mode]
    if not spot then return nil end
    radius = radius or 0.84
    local zl = goal.half - radius - 1.5
    local y0 = goal.ground + radius + 0.15
    local y1 = goal.top - radius - 1.3
    return Vector3.new(goal.x, y0 + (y1 - y0) * spot[2], goal.z + goal.out * zl * spot[1])
end

function CrystalHub.Functions.ShotAutoList(goal, lob, radius)
    radius = radius or 0.84
    local cache = goal.Lists
    if not cache then
        cache = {}
        goal.Lists = cache
    end
    local slot = lob and 1 or 2
    local hit = cache[slot]
    if hit and hit.radius == radius then return hit.list end
    local zl = goal.half - radius - 1.5
    local y0 = goal.ground + radius + 0.15
    local y1 = goal.top - radius - 1.3
    local zs = { -0.97, -0.88, -0.76, -0.62, -0.46, -0.3, -0.12, 0.12, 0.3, 0.46, 0.62, 0.76, 0.88, 0.97 }
    local ys = lob and { 0.55, 0.7, 0.84, 0.95 } or { 0.04, 0.16, 0.3, 0.48, 0.66, 0.82, 0.95 }
    local list = {}
    for _, zf in ipairs(zs) do
        for _, yf in ipairs(ys) do
            list[#list + 1] = Vector3.new(goal.x, y0 + (y1 - y0) * yf, goal.z + zl * zf)
        end
    end
    cache[slot] = { radius = radius, list = list }
    return list
end

function CrystalHub.Functions.ShotFly(env, gy, from, vel, spin, limitT, bx, bz, bn, stepDt, kp)
    local Flight = SilentAimState.Flight
    local params = env.Params
    local goal = env.Goal
    local gx, gz, out = goal.x, goal.z, goal.out
    local radius = env.Radius
    local q = (goal.top - goal.ground) / 8.714285714285714
    local pr = 0.2143 * q
    local postZ = goal.half + pr
    local barY = goal.top + pr
    local reachR = radius + pr + 0.05
    local airStep, rollStep = Flight.airStep, Flight.rollStep
    local bounce, toGround, bounceMin = Flight.bounce, Flight.toGround, Flight.BOUNCE_MIN
    local pos, v, s = from, vel, spin
    local rolling = false
    if pos.Y <= gy + 0.05 and v.Y <= bounceMin then
        rolling = true
        pos = Vector3.new(pos.X, gy, pos.Z)
        v, s = toGround(v, s)
    end
    local dt = stepDt or 1 / 60
    local t = 0
    local blocked = false
    local framed = false
    local fx, fz = from.X, from.Z
    local step = 0
    while t < limitT do
        local np, nv, ns
        if rolling then
            np, nv, ns = rollStep(pos, v, s, dt, params)
            if nv.X * nv.X + nv.Z * nv.Z < 0.04 then
                return nil, t, blocked, framed
            end
        else
            np, nv, ns = airStep(pos, v, s, dt, params)
            if np.Y < gy and nv.Y < 0 then
                local k = math.clamp((pos.Y - gy) / math.max(pos.Y - np.Y, 1e-6), 0, 1)
                local hp, hv, hs = airStep(pos, v, s, dt * k, params)
                hp = Vector3.new(hp.X, gy, hp.Z)
                local bv, bs = bounce(hv, hs, params)
                if bv.Y < bounceMin then
                    bv, bs = toGround(bv, bs)
                    rolling = true
                    np, nv, ns = rollStep(hp, bv, bs, dt * (1 - k), params)
                else
                    np, nv, ns = airStep(hp, bv, bs, dt * (1 - k), params)
                end
            end
        end
        if kp and not kp.t then
            local d1 = (pos.X - kp.x) * kp.fx + (pos.Z - kp.z) * kp.fz - kp.ahead
            local d2 = (np.X - kp.x) * kp.fx + (np.Z - kp.z) * kp.fz - kp.ahead
            if d1 > 0 and d2 <= 0 then
                local a = d1 / (d1 - d2)
                kp.t = t + dt * a
                kp.pos = pos:Lerp(np, a)
            end
        end
        if (np.X - gx) * out >= 0 then
            local dxs = np.X - pos.X
            local a = dxs ~= 0 and math.clamp((gx - pos.X) / dxs, 0, 1) or 1
            local cp = pos:Lerp(np, a)
            local hx, hy, hz = np.X - pos.X, np.Y - pos.Y, np.Z - pos.Z
            local hm = math.sqrt(hx * hx + hz * hz)
            local ez = cp.Z - gz
            if hm > 1e-6 and cp.Y <= barY + radius + 0.5 then
                local uz = hz / hm
                local ax = math.abs(hx / hm)
                local d1 = postZ - ez
                local d2 = -postZ - ez
                local e1 = (d1 * uz < 0) and math.abs(d1) * ax or math.abs(d1)
                local e2 = (d2 * uz < 0) and math.abs(d2) * ax or math.abs(d2)
                if e1 < reachR or e2 < reachR then framed = true end
            end
            local hn = math.sqrt(hx * hx + hy * hy)
            if hn > 1e-6 and math.abs(ez) <= postZ then
                local dy = barY - cp.Y
                local uyn = hy / hn
                local uxn = math.abs(hx) / hn
                local eb = (dy * uyn < 0) and math.abs(dy) * uxn or math.abs(dy)
                if eb < reachR then framed = true end
            end
            return cp, t + dt * a, blocked, framed
        end
        if bn > 0 and not blocked and np.Y - gy < 7 then
            step += 1
            if step % 2 == 0 then
                local ox, oz = np.X - fx, np.Z - fz
                if ox * ox + oz * oz > 16 then
                    for i = 1, bn do
                        local ex, ez = bx[i] - np.X, bz[i] - np.Z
                        if ex * ex + ez * ez < 5.8 then
                            blocked = true
                            break
                        end
                    end
                end
            end
        end
        pos, v, s = np, nv, ns
        t += dt
    end
    return nil, t, blocked, framed
end

function CrystalHub.Functions.ShotBest(from, family, lob, budget, minAngle, mode)
    local F = CrystalHub.Functions
    local SA = SilentAimState
    local env = F.ShotEnv()
    if not env then return nil end
    mode = mode or "warm"
    local goal = env.Goal
    local params = env.Params
    local radius = env.Radius
    local gy = SA.BallView.groundBallY(from)
    local pitchY = gy - radius
    local fam = SA.Families[family]
    local cap = 125
    if fam and fam.speed then
        local top = math.max(fam.speed[2], fam.shotSpeed and fam.shotSpeed[2] or 0)
        cap = top * (fam.header and 1 or 1.05) * 0.97
    end
    local dxg, dzg = goal.x - from.X, goal.z - from.Z
    local flatD = math.sqrt(dxg * dxg + dzg * dzg)
    local speed = cap
    if lob then
        local factor = 1.2 + 0.35 * math.clamp(flatD / 90, 0, 1)
        speed = math.clamp(math.sqrt(params.gravity * math.max(flatD, 12)) * factor, 22, cap)
    end
    local minA = minAngle or (lob and 0.35 or -0.9)
    local maxA = lob and 1.3 or 0.8
    local kit = F.KeeperKit()
    local keeperNow = F.CrystalAimKeeper(goal)
    local kpos = keeperNow and F.KeeperAt(goal, from, keeperNow, kit) or nil
    local kx = kpos and kpos.X or goal.x - goal.out * 6
    local kz = kpos and kpos.Z or goal.z
    local oX = -goal.out
    local bx, bz, bn = F.ShotBodies(goal, lob)
    local curveOn = SA.AutoCurve == true and not lob and flatD >= 8 and not (fam and fam.header)
    local k = math.min(math.clamp(30 + flatD * 0.5, 40, 70) * (SA.CurveAmount or 1), 72)
    local zLim, yMin, yMax = F.ShotBounds(env)
    local react = kit and math.max(kit.cfg.Reaction[1] - 0.03, 0.1) or 0.2
    local now = os.clock()
    local deadline = budget and (now + budget) or nil
    local points, targeted = F.ShotTargets(goal, lob, radius)
    local cache = CrystalHub.ShotCache
    local light = mode ~= "strike"
    local simDt = lob and 1 / 45 or 1 / 60
    if light then
        simDt = lob and 1 / 30 or 1 / 40
    end
    local candIters = light and 6 or 10
    local tol = 0.45
    local best, fallback, loose

    local function faceFor(vel)
        local m = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
        local fx, fz = oX, 0
        if m > 5 and (vel.X / m) * oX < -0.2 then
            fx, fz = -vel.X / m, -vel.Z / m
        end
        local d = fx * oX
        if d < 0.3 then
            fx = fx + oX * (0.3 - d)
            local l = math.sqrt(fx * fx + fz * fz)
            fx, fz = fx / l, fz / l
        end
        return fx, fz
    end

    local function evaluate(p, curve, dl)
        local vel, spin, miss, ft, blocked, c, extra
        local key
        if curve == 0 then
            vel, spin, miss, ft, blocked, c, extra = F.PitchSolve(env, gy, from, p, speed, minA, maxA, lob, simDt, bx, bz, bn, dl)
        else
            local sign = curve > 0 and 1 or -1
            key = ((((math.floor(p.Z * 2) + 2000) * 4096 + (math.floor(p.Y * 2) + 2000)) * 8 + (sign + 1) * 2 + (lob and 1 or 0)) * 2 + (goal.out > 0 and 1 or 0))
            vel, spin, miss, ft, blocked, c = F.ShotSolve(env, gy, from, p, speed, curve, minA, maxA, key, bx, bz, bn, lob, simDt, candIters, dl)
        end
        if not vel then return nil end
        local dz = math.abs(c.Z - goal.z)
        if dz > goal.half - 0.8 or c.Y < yMin or c.Y > goal.top - 0.4 then return nil end
        local fx, fz = faceFor(vel)
        local kp = { x = kx, z = kz, fx = fx, fz = fz, ahead = 0.8 }
        local _, _, _, framed = F.ShotFly(env, gy, from, vel, spin, ft + 0.5, bx, bz, 0, simDt, kp)
        local mp, mt = kp.pos or c, kp.t or ft
        local lat = (mp.X - kx) * -fz + (mp.Z - kz) * fx
        local gap, save = F.KeeperSave(lat, mp.Y - pitchY, mt - react, flatD)
        local pg
        if gap >= 1.2 then
            pg = 1
        elseif gap <= 0 then
            pg = 1 - save
        else
            pg = (1 - save) + save * gap / 1.2
        end
        local edge = math.min(zLim - dz, yMax - c.Y)
        local penalty = 1
        if blocked then penalty *= 0.1 end
        if framed then penalty *= 0.05 end
        local score = pg * penalty * 100 + math.min(gap, 3) * 1.5 + math.min(edge, 1.5) * 2 - ft - miss * 8
        return {
            vel = vel,
            spin = spin,
            point = p,
            curve = curve,
            miss = miss,
            time = ft,
            blocked = blocked,
            framed = framed,
            cross = c,
            key = key,
            th = extra,
            gap = gap,
            pg = pg,
            edge = edge,
            score = score,
            strict = edge >= 0 and miss <= tol and not framed,
        }
    end

    local function take(e)
        if not e then return end
        if e.strict and not e.blocked then
            if not best or e.score > best.score then best = e end
        elseif e.strict or e.framed then
            e.fallback = true
            if not fallback or e.score > fallback.score then fallback = e end
        elseif targeted or e.miss <= 2.5 then
            e.fallback = true
            e.score = -e.miss
            if not loose or e.score > loose.score then loose = e end
        end
    end

    local function inward(p)
        return Vector3.new(p.X, goal.ground + (p.Y - goal.ground) * 0.82, goal.z + (p.Z - goal.z) * 0.6)
    end

    local function coarse(p)
        local dx = p.X - from.X
        local f = math.abs(dx) > 1 and math.clamp((kx - goal.out * 0.8 - from.X) / dx, 0, 1) or 1
        local mz = from.Z + (p.Z - from.Z) * f
        local my = from.Y + (p.Y - from.Y) * f
        local ddz = p.Z - from.Z
        local d = math.sqrt(dx * dx + ddz * ddz)
        local tf = d / (speed * (lob and 0.6 or 0.85)) * f
        local avail = math.max(tf - react, 0)
        local reach
        if kit then
            local q = kit.shSpeed / kit.shAccel
            local moved = avail <= q and 0.5 * kit.shAccel * avail * avail or 0.5 * kit.shAccel * q * q + kit.shSpeed * (avail - q)
            local idx = math.clamp(math.floor(avail / kit.step) + 2, 1, #kit.reachX)
            reach = moved + kit.reachX[idx] + kit.hand
        else
            reach = 4.8 + 15 * avail
        end
        return math.abs(mz - kz) - reach + math.max(math.abs(my - pitchY - 3.2) - 1.8, 0) * 0.6
    end

    local key = string.format("%s|%s|%d|%s|%s|%d", tostring(family), tostring(lob), math.floor(goal.x), tostring(curveOn), SA.TargetKey or "Auto", math.floor(minA * 100))
    local plan = cache[key]
    if plan and (now - plan.at > 2 or (plan.from - from).Magnitude > 30) then
        plan = nil
        cache[key] = nil
    end
    local settled = false
    if plan then
        local entry = evaluate(plan.point, plan.curve, nil)
        if entry and entry.strict and not entry.blocked then
            entry.score += 1
            take(entry)
            settled = entry.pg >= 0.95 and entry.edge >= 0.4
        else
            cache[key] = nil
        end
    end

    if not settled then
        local ranked = {}
        for i, p in ipairs(points) do
            ranked[i] = { point = p, score = coarse(p), i = i }
        end
        table.sort(ranked, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return a.i < b.i
        end)
        local M = math.min(#ranked, targeted and #ranked or 14)
        if M > 0 then
            local cursors = CrystalHub.ShotCursor
            local count = mode == "strike" and M or (mode == "preview" and 1 or math.min(M, 3))
            local first = mode == "strike" and 1 or (cursors[key] or 1)
            local tried = 0
            for j = 0, count - 1 do
                local item = ranked[(first - 1 + j) % M + 1]
                local dl = (mode ~= "strike" or best or fallback or loose) and deadline or nil
                local e = evaluate(item.point, 0, dl)
                take(e)
                if e and e.framed then
                    take(evaluate(inward(item.point), 0, dl))
                end
                if curveOn then
                    local weak = (not e) or (not e.strict) or e.gap < 1.5 or e.blocked
                    if j < 3 or (weak and j < 8) then
                        take(evaluate(item.point, k, dl))
                        take(evaluate(item.point, -k, dl))
                        if weak then
                            take(evaluate(item.point, k * 0.5, dl))
                            take(evaluate(item.point, -k * 0.5, dl))
                        end
                    end
                end
                tried += 1
                if not targeted and best and best.pg >= 0.97 and best.edge >= 0.8 then break end
                if deadline and os.clock() > deadline and (best or fallback or loose or mode ~= "strike") then break end
            end
            if mode ~= "strike" then
                cursors[key] = (first - 1 + tried) % M + 1
            end
        end
    end

    local result = best or fallback or loose
    if not result then
        cache[key] = nil
        return nil
    end
    if result.strict and not result.blocked then
        cache[key] = { point = result.point, curve = result.curve, from = from, at = now }
    end

    if mode == "strike" then
        local vel, spin, miss, ft, blocked, c
        if result.curve == 0 then
            vel, spin, miss, ft, blocked, c = F.PitchSolve(env, gy, from, result.point, speed, minA, maxA, lob, 1 / 120, bx, bz, bn, nil, result.th)
        elseif result.key then
            vel, spin, miss, ft, blocked, c = F.ShotSolve(env, gy, from, result.point, speed, result.curve, minA, maxA, result.key, bx, bz, bn, lob, lob and 1 / 90 or 1 / 120, 8, nil)
        end
        if vel and c then
            local dz = math.abs(c.Z - goal.z)
            if dz <= goal.half - 0.8 and c.Y >= yMin and c.Y <= goal.top - 0.4 and miss <= math.max(result.miss + 0.3, 0.6) then
                result.vel = vel
                result.spin = spin
                result.miss = miss
                result.time = ft
                result.blocked = blocked
                result.cross = c
            end
        end
    end

    result.from = from
    result.lob = lob
    result.goalX = goal.x
    result.at = now
    result.born = now
    CrystalHub.ShotLast = result
    return result
end

function CrystalHub.Functions.ShotFallback(from, family, lob)
    local F = CrystalHub.Functions
    local SA = SilentAimState
    local goal = F.SilentAimGoal()
    if not goal then return nil end
    local env = F.ShotEnv()
    local fam = SA.Families and SA.Families[family]
    local cap = 125
    if fam and fam.speed then
        local top = math.max(fam.speed[2], fam.shotSpeed and fam.shotSpeed[2] or 0)
        cap = top * (fam.header and 1 or 1.05) * 0.97
    end
    local dx, dz = goal.x - from.X, goal.z - from.Z
    local flatD = math.sqrt(dx * dx + dz * dz)
    if flatD < 1 then return nil end
    local gravity = env and env.Params.gravity or 46
    local speed = cap
    if lob then
        local factor = 1.2 + 0.35 * math.clamp(flatD / 90, 0, 1)
        speed = math.clamp(math.sqrt(gravity * math.max(flatD, 12)) * factor, 22, cap)
    end
    local minA = lob and 0.35 or -0.9
    local maxA = lob and 1.3 or 0.8
    local radius = env and env.Radius or 0.84
    local points, targeted = F.ShotTargets(goal, lob, radius)
    local keeper = F.CrystalAimKeeper(goal)
    local kz = keeper and keeper.Z or goal.z
    local ordered = {}
    for i, p in ipairs(points) do
        ordered[i] = { p = p, d = targeted and 0 or math.abs(p.Z - kz), i = i }
    end
    table.sort(ordered, function(a, b)
        if a.d ~= b.d then return a.d > b.d end
        return a.i < b.i
    end)
    if env and SA.BallView then
        local gy = SA.BallView.groundBallY(from)
        local deadline = os.clock() + F.Budget(0.012)
        local bestVel, bestSpin, bestMiss
        bestMiss = math.huge
        for _, item in ipairs(ordered) do
            local vel, spin, miss = F.PitchSolve(env, gy, from, item.p, speed, minA, maxA, lob, 1 / 45, {}, {}, 0, nil)
            if vel and miss < bestMiss then
                bestVel, bestSpin, bestMiss = vel, spin, miss
            end
            if bestMiss < 0.5 or (bestVel and os.clock() > deadline) then break end
        end
        if bestVel then
            return { vel = bestVel, spin = bestSpin }
        end
    end
    local p = ordered[1].p
    local px, pz = p.X - from.X, p.Z - from.Z
    local pd = math.sqrt(px * px + pz * pz)
    if pd < 1 then return nil end
    local t = pd / (speed * 0.7)
    local ang = math.clamp(math.atan2(p.Y - from.Y + gravity * 0.5 * t * t, math.max(pd, 1)), minA, maxA)
    local vel = Vector3.new(px / pd * math.cos(ang) * speed, math.sin(ang) * speed, pz / pd * math.cos(ang) * speed)
    return { vel = vel, spin = Vector3.new(0, 0, 0) }
end

function CrystalHub.Functions.IsOriginalGoalShot(from, vel, spin)
    local F = CrystalHub.Functions
    if typeof(from) ~= "Vector3" or typeof(vel) ~= "Vector3" then return false end
    if typeof(spin) ~= "Vector3" then spin = Vector3.zero end
    local goal = F.ShotGate(from)
    if not goal then return false end
    if vel.X * goal.out <= 0.05 then return false end
    local lateral
    local topLimit = goal.top + 12
    local okEnv, env = pcall(F.ShotEnv)
    if okEnv and env and env.Params and SilentAimState.BallView then
        local okGy, gy = pcall(SilentAimState.BallView.groundBallY, from)
        if not okGy or type(gy) ~= "number" then
            gy = goal.ground + (env.Radius or 1)
        end
        local seconds = math.clamp(math.abs(goal.x - from.X) / math.max(math.abs(vel.X) * 0.55, 8) + 0.8, 0.8, 6)
        local okFly, hit = pcall(F.ShotFly, env, gy, from, vel, spin, seconds, {}, {}, 0, 1 / 60)
        if okFly and hit then
            if hit.Y > topLimit then return false end
            lateral = math.abs(hit.Z - goal.z)
        end
    end
    if not lateral then
        local t = (goal.x - from.X) / vel.X
        if t <= 0 then return false end
        lateral = math.abs(from.Z + vel.Z * t - goal.z)
    end
    return lateral <= goal.half + 8
end

function CrystalHub.Functions.CrystalAimRedirect(from, vel, spin, family)
    local F = CrystalHub.Functions
    local SA = SilentAimState
    local stats = SA.Stats
    if not stats then
        stats = { calls = 0, redirected = 0, last = "" }
        SA.Stats = stats
    end
    stats.calls += 1
    if type(family) ~= "string" or CrystalHub.ShotIgnore[family] then
        stats.last = "ignored family " .. tostring(family)
        return nil
    end
    if not F.ShotGate(from) then
        stats.last = "gate"
        return nil
    end
    if SA.OnlyGoalShots == true then
        local ok, valid = pcall(F.IsOriginalGoalShot, from, vel, spin)
        if not ok or valid ~= true then
            stats.last = "not goal-bound"
            stats.skipped = (stats.skipped or 0) + 1
            SA.Pending = nil
            return nil
        end
    end
    local now = os.clock()
    local last = SA.StrikeCache
    if last and last.family == family and now - last.at < 0.35 and (last.from - from).Magnitude < 0.5 then
        stats.redirected += 1
        stats.last = "cached"
        return last.vel, last.spin
    end
    local pend = SA.Pending
    if pend and pend.family == family and now - pend.at < 1.2 and (pend.from - from).Magnitude < 0.8 then
        SA.Pending = nil
        SA.StrikeCache = { from = from, family = family, vel = pend.vel, spin = pend.spin, at = now }
        stats.redirected += 1
        stats.last = "plan"
        return pend.vel, pend.spin
    end
    local nv, ns = F.CrystalAimSolve(from, family)
    if nv then
        SA.StrikeCache = { from = from, family = family, vel = nv, spin = ns, at = now }
        stats.redirected += 1
        stats.last = "ok"
        return nv, ns
    end
    stats.last = "no solution"
    return nil
end

function CrystalHub.Functions.CrystalAimSolve(from, family)
    local F = CrystalHub.Functions
    local SA = SilentAimState
    local lob = CrystalHub.ShotLobs[family] == true
    local ok, result = pcall(F.ShotBest, from, family, lob, F.Budget(0.012), nil, "strike")
    if not ok then
        SA.LastError = tostring(result)
        result = nil
    end
    if not (result and result.vel) then
        local ok2, fb = pcall(F.ShotFallback, from, family, lob)
        if ok2 then
            result = fb
        else
            SA.LastError = tostring(fb)
            result = nil
        end
    end
    if result and result.vel then
        return result.vel, result.spin
    end
    return nil
end

function CrystalHub.Functions.CrystalAimPlan(plan)
    local F = CrystalHub.Functions
    local SA = SilentAimState
    local family = plan.family
    if type(family) ~= "string" or CrystalHub.ShotIgnore[family] then return nil end
    local from = plan.ball
    if typeof(from) ~= "Vector3" or not F.ShotGate(from) then return nil end
    if SA.OnlyGoalShots == true then
        local checkVel = plan.vel
        if typeof(checkVel) ~= "Vector3" then
            if typeof(plan.dir) ~= "Vector3" then return nil end
            checkVel = Vector3.new(plan.dir.X, plan.dir.Y, plan.dir.Z) * 60
        end
        local ok, valid = pcall(F.IsOriginalGoalShot, from, checkVel, plan.spin)
        if not ok or valid ~= true then return nil end
    end
    local vel, spin = F.CrystalAimSolve(from, family)
    if not vel then return nil end
    SA.Pending = { from = from, family = family, vel = vel, spin = spin, at = os.clock() }
    return vel, spin
end

function CrystalHub.Functions.InstallPlanSync()
    local SA = getgenv().CrystalSilentAim
    if SA.PlanHooked then return true end
    if not (hookmetamethod and getnamecallmethod and setnamecallmethod and newcclosure) then return false end
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local state = getgenv().CrystalSilentAim
        if state.Enabled and state.PlanSync ~= false and getnamecallmethod() == "FireServer" then
            local plan = ...
            if type(plan) == "table"
                and plan.hold ~= true
                and typeof(plan.ball) == "Vector3"
                and type(plan.family) == "string"
                and plan.power ~= nil
                and plan.leg ~= nil
                and typeof(plan.dir) == "Vector3" then
                local H = getgenv().CrystalHub
                local F = H and H.Functions
                if F then
                    local ok, vel, spin = pcall(F.CrystalAimPlan, plan)
                    setnamecallmethod("FireServer")
                    if ok and vel then
                        local copy = table.clone(plan)
                        local m = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
                        if m > 0.001 then
                            copy.dir = Vector3.new(vel.X / m, 0, vel.Z / m)
                        end
                        if typeof(plan.vel) == "Vector3" then
                            copy.vel = vel
                        end
                        if typeof(plan.spin) == "Vector3" and spin then
                            copy.spin = spin
                        end
                        return old(self, copy, select(2, ...))
                    end
                end
            end
        end
        return old(self, ...)
    end))
    SA.PlanHooked = true
    return true
end

function CrystalHub.Functions.CurrentFamily()
    local name = CrystalHub.ShotFamily
    if name and os.clock() - (CrystalHub.ShotFamilyAt or 0) < 0.6 then
        return name
    end
    return nil
end

function CrystalHub.Functions.PreviewAim(from, vel, spin)
    local F = CrystalHub.Functions
    local SA = getgenv().CrystalSilentAim
    if not F.SilentAimModules() then return nil end
    if SA.OnlyGoalShots == true and not F.IsOriginalGoalShot(from, vel, spin) then return nil end
    local goal = F.ShotGate(from, vel)
    if not goal then return nil end
    local flat = Vector3.new(vel.X, 0, vel.Z)
    local fm = flat.Magnitude
    local family, lob, minAngle
    lob = false
    local auto = CrystalHub.Auto
    if auto and auto.Phase == "air" then
        local gy = SA.BallView.groundBallY(from)
        family = auto.Mode == "away" and "Bicycle" or (from.Y - gy <= 2.4 and "Volley" or "RunningHeader")
        minAngle = -0.95
    elseif CrystalHub.TrickActive then
        family = CrystalHub.TrickKey == "KickLob" and "Lofted" or "Laced"
        lob = family == "Lofted"
    else
        family = F.CurrentFamily()
        if family then
            if CrystalHub.ShotIgnore[family] then return nil end
            lob = CrystalHub.ShotLobs[family] == true
        elseif fm > 1 and vel.Y / fm > 0.62 then
            family, lob = "Lofted", true
        else
            family = "Laced"
        end
    end
    local now = os.clock()
    CrystalHub.PreviewWant = { family = family, lob = lob, minAngle = minAngle, at = now }
    local cache = CrystalHub.PreviewCache
    local c = cache and cache[family .. (minAngle and "|a" or "")]
    if c and c.goalX == goal.x and now - c.at < 0.6 and (c.from - from).Magnitude < 8 then
        return c.vel, c.spin
    end
    return nil
end

function CrystalHub.Functions.StartShotTick()
    local F = CrystalHub.Functions
    F.InstallPreviewSpoof()
    if CrystalHub.ShotTickConn then return end
    local acc = 0
    local pause = 0.1
    CrystalHub.ShotTickConn = RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < pause then return end
        acc = 0
        pause = 0.1
        local SA = SilentAimState
        if not SA.Enabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local id = char:GetAttribute("DribbleId")
        local ball = F.GetBall()
        if not ball or type(id) ~= "number" or ball:GetAttribute("Possessor") ~= id then return end
        if not F.SilentAimModules() then return end
        local pos = SA.BallView.getPosition()
        if not pos or not F.ShotGate(pos) then return end
        local want = CrystalHub.PreviewWant
        local family, lob, minAngle
        if want and os.clock() - want.at < 0.5 then
            family, lob, minAngle = want.family, want.lob, want.minAngle
        else
            family = F.CurrentFamily() or "Laced"
            if CrystalHub.ShotIgnore[family] then family = "Laced" end
            lob = CrystalHub.ShotLobs[family] == true
        end
        local t0 = os.clock()
        local ok, result = pcall(F.ShotBest, pos, family, lob, F.Budget(0.004), minAngle, "preview")
        local cache = CrystalHub.PreviewCache
        if not cache then
            cache = {}
            CrystalHub.PreviewCache = cache
        end
        local pkey = family .. (minAngle and "|a" or "")
        if ok and result then
            cache[pkey] = {
                at = os.clock(),
                from = pos,
                goalX = result.goalX,
                vel = result.vel,
                spin = result.spin,
            }
        else
            cache[pkey] = nil
        end
        pause = math.clamp((os.clock() - t0) * 6, 0.1, 0.5)
    end)
    CrystalHub.ConnectionController.Insert(CrystalHub.ShotTickConn)
end

function CrystalHub.Functions.InstallPickTrack()
    local SA = getgenv().CrystalSilentAim
    if SA.PickHooked then return end
    local ok, Select = pcall(function()
        return require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Kick")).Select
    end)
    if not ok or type(Select) ~= "table" or type(Select.pick) ~= "function" or not hookfunction then return end
    local orig
    local function wrapper(self, forced)
        local H = getgenv().CrystalHub
        local state = getgenv().CrystalSilentAim
        local input = self
        if H and type(self) == "table" then
            H.KickIntent = self.intent
            H.KickIntentAt = os.clock()
            if state.Enabled and state.OnlyGoalShots ~= true and (self.intent == "Shoot" or self.intent == "Lob") then
                pcall(function()
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("Root")
                    if not root then return end
                    local p = root.Position
                    local dir = H.Functions.KickGoalDir(p.X, p.Z)
                    if dir then
                        local copy = table.clone(self)
                        copy.aimDir = dir
                        copy.travel = dir
                        copy.facing = dir
                        copy.sideStepping = false
                        input = copy
                    end
                end)
            end
        end
        local result, second = orig(input, forced)
        if type(result) == "table" and type(result.family) == "table" and type(result.family.name) == "string" and H then
            H.ShotFamily = result.family.name
            H.ShotFamilyAt = os.clock()
        end
        return result, second
    end
    local hok, res = pcall(hookfunction, Select.pick, wrapper)
    if hok and res then
        orig = res
        SA.PickHooked = true
    end
end

function CrystalHub.Functions.InstallSilentAim()
    local F = CrystalHub.Functions
    local SA = getgenv().CrystalSilentAim
    SA.Redirect = F.CrystalAimRedirect
    local ok, DribbleClient = pcall(function()
        return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Game"):WaitForChild("DribbleClient"))
    end)
    if not (ok and type(DribbleClient) == "table") then
        return false
    end
    if SA.HookedModule ~= DribbleClient then
        SA.Hooked = false
        SA.HookedModule = nil
        SA.PickHooked = nil
        SA.PlanAimHooked = nil
        SA.PreviewShowHooked = nil
        SA.PreviewShowHooking = nil
        SA.BallView = nil
        SA.Flight = nil
        SA.Families = nil
        SA.KeeperRules = nil
        SA.Radius = nil
        CrystalHub.ShotEnvCache = nil
        CrystalHub.GoalCache = nil
    end
    F.SilentAimModules()
    F.InstallPickTrack()
    pcall(F.InstallPlanAim)
    if not SA.Hooked then
        local installed = 0
        for _, name in ipairs({ "strike", "strikeFree" }) do
            local fn = DribbleClient[name]
            if type(fn) == "function" then
                local orig
                local function wrapper(from, vel, spin, family, t)
                    if SA.Enabled and SA.Redirect and type(family) == "string" and typeof(from) == "Vector3" and typeof(vel) == "Vector3" then
                        local rok, newVel, newSpin = pcall(SA.Redirect, from, vel, spin, family)
                        if rok then
                            if newVel then
                                SA.LastVel = newVel
                                SA.LastAt = os.clock()
                                vel = newVel
                                spin = newSpin or spin
                                local H = getgenv().CrystalHub
                                if H then H.ShotLast = nil end
                            end
                        else
                            SA.LastError = tostring(newVel)
                        end
                    end
                    return orig(from, vel, spin, family, t)
                end
                if hookfunction then
                    local hok, result = pcall(hookfunction, fn, wrapper)
                    if hok and result then
                        orig = result
                        installed += 1
                    end
                else
                    orig = fn
                    if pcall(function() DribbleClient[name] = wrapper end) then
                        installed += 1
                    end
                end
            end
        end
        SA.Hooked = installed > 0
        SA.HookedModule = SA.Hooked and DribbleClient or nil
    end
    pcall(F.InstallPlanSync)
    F.StartShotTick()
    return SA.Hooked == true
end

function CrystalHub.Functions.KickGoalDir(x, z)
    local F = CrystalHub.Functions
    local goal = F.SilentAimGoal()
    if not goal then return nil end
    if (x - goal.x) * goal.out >= 0 then return nil end
    local dx, dz = goal.x - x, goal.z - z
    local m = math.sqrt(dx * dx + dz * dz)
    if m < 1.5 then return nil end
    local range = SilentAimState.Range or 300
    if range < 300 and m > range then return nil end
    return Vector3.new(dx / m, 0, dz / m)
end

function CrystalHub.Functions.InstallPlanAim()
    local SA = getgenv().CrystalSilentAim
    if SA.PlanAimHooked or not hookfunction then return end
    local ok, Plan = pcall(function()
        return require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Kick")).Plan
    end)
    if not ok or type(Plan) ~= "table" or type(Plan.find) ~= "function" then return end
    local orig
    local function wrapper(self, ...)
        local H = getgenv().CrystalHub
        local state = getgenv().CrystalSilentAim
        if H and state.Enabled and state.OnlyGoalShots ~= true and type(self) == "table" and typeof(self.pos) == "Vector3" then
            local intent = H.KickIntent
            if (intent == "Shoot" or intent == "Lob") and os.clock() - (H.KickIntentAt or 0) < 0.15 then
                local ball = self.pos
                if type(self.ballAt) == "function" and self.now then
                    local bok, bp = pcall(self.ballAt, self.now)
                    if bok and typeof(bp) == "Vector3" then ball = bp end
                end
                local dir = H.Functions.KickGoalDir(ball.X, ball.Z)
                if dir then
                    self.aimDir = dir
                end
            end
        end
        return orig(self, ...)
    end
    local hok, res = pcall(hookfunction, Plan.find, wrapper)
    if hok and res then
        orig = res
        SA.PlanAimHooked = true
    end
end

function CrystalHub.Functions.InstallPreviewSpoof()
    local SA = getgenv().CrystalSilentAim
    if SA.PreviewShowHooked or SA.PreviewShowHooking then return end
    SA.PreviewShowHooking = true
    task.spawn(function()
        local ok, KP = pcall(function()
            local game_ = LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Game")
            return require(game_:WaitForChild("KickPreview", 10))
        end)
        if not (ok and type(KP) == "table" and type(KP.show) == "function") then
            SA.PreviewShowHooking = false
            return
        end
        local orig = KP.show
        local function wrapper(strike, ...)
            local state = getgenv().CrystalSilentAim
            if state.Enabled and state.Spoof ~= false and type(strike) == "table" and typeof(strike.from) == "Vector3" and typeof(strike.vel) == "Vector3" then
                local view = CrystalHub.TrickView
                local locked = view ~= nil and view.Active == true
                local rok, nv, ns = pcall(CrystalHub.Functions.PreviewAim, strike.from, strike.vel, strike.spin)
                if rok and nv then
                    local copy = table.clone(strike)
                    copy.vel = nv
                    copy.spin = ns or strike.spin
                    if locked then copy.turn = false end
                    state.PreviewLastVel = nv
                    return orig(copy, ...)
                end
                if locked then
                    local copy = table.clone(strike)
                    copy.turn = false
                    return orig(copy, ...)
                end
            end
            return orig(strike, ...)
        end
        KP.show = wrapper
        SA.PreviewShowHooked = true
        SA.PreviewShowHooking = false
        CrystalHub.ConnectionController.Insert({ Disconnect = function()
            if KP.show == wrapper then
                KP.show = orig
            end
            SA.PreviewShowHooked = false
        end })
    end)
end

function CrystalHub.Functions.ShotPredict(params, pos, vel, spin, gy, horizon, dt)
    local Flight = getgenv().CrystalSilentAim.Flight
    local list = {}
    local v, s = vel, spin
    local rolling = false
    local t = 0
    local n = 0
    while t < horizon do
        local np, nv, ns
        if rolling then
            np, nv, ns = Flight.rollStep(pos, v, s, dt, params)
        else
            np, nv, ns = Flight.airStep(pos, v, s, dt, params)
            if np.Y < gy and nv.Y < 0 then
                np = Vector3.new(np.X, gy, np.Z)
                local bv, bs = Flight.bounce(nv, ns, params)
                if bv.Y < Flight.BOUNCE_MIN then
                    bv, bs = Flight.toGround(bv, bs)
                    rolling = true
                end
                nv, ns = bv, bs
            end
        end
        pos, v, s = np, nv, ns
        t += dt
        n += 1
        list[n] = { t = t, pos = pos }
    end
    return list
end

getgenv().CrystalTracker = getgenv().CrystalTracker or { Enabled = false, Rate = 0.25, Color = Color3.fromRGB(43, 255, 172) }

function CrystalHub.Functions.TrackerModules()
    local T = getgenv().CrystalTracker
    if T.BallSim and T.World then return true end
    pcall(function()
        local g = Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game")
        local bs = g:WaitForChild("BallSim")
        T.BallSim = require(bs)
        T.World = require(bs:WaitForChild("World"))
    end)
    return T.BallSim ~= nil and T.World ~= nil
end

function CrystalHub.Functions.TrackerTrace(ev)
    local F = CrystalHub.Functions
    local T = getgenv().CrystalTracker
    local BallSim, World = T.BallSim, T.World
    local data = World.get()
    if T.FrameSrc ~= data.frames then
        local copy = {}
        for key, frame in pairs(data.frames) do
            copy[key] = frame.touched and setmetatable({ touched = false }, { __index = frame }) or frame
        end
        T.FrameSrc = data.frames
        T.FrameCopy = copy
    end
    local world = { groundY = data.groundY, frames = T.FrameCopy, bodies = {} }
    local params = World.params()
    local flight = World.FLIGHT
    local step = BallSim.STEP * 2
    local gy = data.groundY
    local goal = F.SilentAimGoal()
    local event = BallSim.fromEvent(flight, ev, gy)
    local pts = { { p = event.pos, t = event.t } }
    local last = event.pos
    local airborne = event.pos.Y - gy > 1.2
    local landing
    for _ = 1, 260 do
        if BallSim.resting(event, flight) then break end
        event = BallSim.step(flight, event, step, params, world, false, 0, nil)
        local p = event.pos
        if p.Y - gy > 1.2 then airborne = true end
        local crossed = goal ~= nil and (p.X - goal.x) * goal.out >= 0
        local touched = airborne and (p.Y - gy <= 0.06 or event.rolling)
        if (crossed or touched or (p - last).Magnitude >= 1.8) and (p - last).Magnitude > 0.05 then
            pts[#pts + 1] = { p = p, t = event.t }
            last = p
        end
        if touched then
            landing = Vector3.new(p.X, gy - params.radius + 0.1, p.Z)
            break
        end
        if crossed or #pts > 56 then break end
    end
    return pts, landing
end

function CrystalHub.Functions.StopBallTracker()
    pcall(function() RunService:UnbindFromRenderStep("CrystalBallTracker") end)
    local T = getgenv().CrystalTracker
    if T.Base then
        pcall(function() T.Base:Destroy() end)
        T.Base = nil
    end
end

function CrystalHub.Functions.StartBallTracker()
    local F = CrystalHub.Functions
    F.StopBallTracker()
    if not F.SilentAimModules() or not F.TrackerModules() then return false end
    local T = getgenv().CrystalTracker
    local SA = getgenv().CrystalSilentAim
    local BV = SA.BallView
    local COUNT = 56
    local base = Instance.new("Part")
    base.Name = "CrystalTracker"
    base.Anchored = true
    base.CanCollide = false
    base.CanQuery = false
    base.CanTouch = false
    base.CastShadow = false
    base.Transparency = 1
    base.Size = Vector3.new(0.1, 0.1, 0.1)
    base.CFrame = CFrame.identity
    base.Parent = workspace
    T.Base = base

    local function adorn(className)
        local a = Instance.new(className)
        a.Adornee = base
        a.AlwaysOnTop = true
        a.Color3 = T.Color
        a.Visible = false
        pcall(function() a.AdornCullingMode = Enum.AdornCullingMode.Never end)
        a.Parent = base
        return a
    end

    local segs = {}
    for i = 1, COUNT do
        local s = adorn("LineHandleAdornment")
        s.ZIndex = 2
        s.Thickness = 4
        s.Transparency = 0.05
        segs[i] = s
    end
    local marker = adorn("CylinderHandleAdornment")
    marker.ZIndex = 2
    marker.Height = 0.08
    marker.Radius = 1.1
    marker.InnerRadius = 0
    marker.Transparency = 0.15
    local ring = adorn("CylinderHandleAdornment")
    ring.ZIndex = 1
    ring.Height = 0.06
    ring.Radius = 2.2
    ring.InnerRadius = 1.6
    ring.Transparency = 0.35

    local flat = CFrame.Angles(math.pi / 2, 0, 0)
    local applied = T.Color
    local lastSolve = 0
    local path, hidden, baseMoved = nil, true, false
    local shownFrom = 1

    local function hideAll()
        path = nil
        if hidden then return end
        hidden = true
        for i = 1, COUNT do
            segs[i].Visible = false
        end
        marker.Visible = false
        ring.Visible = false
    end

    local function draw(p)
        local pts = p.pts
        local n = math.min(#pts - 1, COUNT)
        p.n = n
        for i = 1, n do
            local a, b = pts[i].p, pts[i + 1].p
            local s = segs[i]
            s.Length = (b - a).Magnitude
            s.CFrame = CFrame.lookAt(a, b)
            s.Visible = true
        end
        for i = n + 1, COUNT do
            segs[i].Visible = false
        end
        shownFrom = 1
        if p.landing then
            local cf = CFrame.new(p.landing) * flat
            marker.CFrame = cf
            ring.CFrame = cf
            marker.Visible = true
            ring.Visible = true
        else
            marker.Visible = false
            ring.Visible = false
        end
        hidden = false
    end

    local function trim(p, now)
        local pts = p.pts
        local first = 1
        while first < p.n and pts[first + 1].t <= now do
            first += 1
        end
        if first ~= shownFrom then
            local lo, hi = math.min(first, shownFrom), math.min(math.max(first, shownFrom), p.n)
            for i = lo, hi do
                segs[i].Visible = i >= first
            end
            shownFrom = first
        end
    end

    RunService:BindToRenderStep("CrystalBallTracker", Enum.RenderPriority.Camera.Value + 40, function()
        if not T.Enabled then
            hideAll()
            return
        end
        if T.Color ~= applied then
            applied = T.Color
            for i = 1, COUNT do
                segs[i].Color3 = applied
            end
            marker.Color3 = applied
            ring.Color3 = applied
        end
        local ball = BV.getBall()
        local pos = BV.getPosition()
        if not (ball and pos) then
            hideAll()
            return
        end
        local now = os.clock()
        local state, _, ev, cp = BV.freeSim()
        if state and ev and cp and state.vel.Magnitude > 3 then
            local key = tostring(ev.seq) .. ":" .. tostring(ev.t)
            if not path or path.mode ~= "free" or path.key ~= key or now - path.at > 1 then
                local ok, pts, landing = pcall(F.TrackerTrace, cp)
                if ok and pts then
                    path = { mode = "free", key = key, at = now, pts = pts, landing = landing }
                    draw(path)
                end
            end
            if path and path.mode == "free" then
                if baseMoved then
                    base.CFrame = CFrame.identity
                    baseMoved = false
                end
                trim(path, state.t)
            else
                hideAll()
            end
            return
        end
        if path and path.mode ~= "solve" then
            hideAll()
        end
        if now - lastSolve >= math.max(T.Rate, 0.15) or not path then
            lastSolve = now
            local ok, result = pcall(F.ShotBest, pos, "Laced", false, F.Budget(0.004), nil, "warm")
            if ok and result and result.vel
                and (not path or (path.vel - result.vel).Magnitude > 0.5 or (path.from - pos).Magnitude > 6) then
                local evt = {
                    seq = 0,
                    t = 0,
                    pos = pos,
                    vel = result.vel,
                    spin = result.spin,
                    kind = "kick",
                    by = 0,
                    pid = 0,
                    n = 0
                }
                local ok2, pts, landing = pcall(F.TrackerTrace, evt)
                if ok2 and pts then
                    path = { mode = "solve", pts = pts, landing = landing, from = pos, vel = result.vel }
                    draw(path)
                end
            end
        end
        if path and path.mode == "solve" then
            if (pos - path.from).Magnitude > 40 then
                hideAll()
            else
                base.CFrame = CFrame.new(pos - path.from)
                baseMoved = true
            end
        else
            hideAll()
        end
    end)
    CrystalHub.ConnectionController.Insert({ Disconnect = function()
        CrystalHub.Functions.StopBallTracker()
    end })
    return true
end

function CrystalHub.Functions.KeeperDivesModule()
    local H = CrystalHub
    if H.KeeperDivesRef then return H.KeeperDivesRef end
    local ok, mod = pcall(function()
        local shared = Services.ReplicatedStorage:WaitForChild("Shared", 5)
        local gameFolder = shared and shared:WaitForChild("Game", 5)
        local inst = gameFolder and gameFolder:WaitForChild("KeeperDives", 5)
        return inst and require(inst)
    end)
    if ok and type(mod) == "table" then
        H.KeeperDivesRef = mod
        return mod
    end
    return nil
end

function CrystalHub.Functions.KeeperDiveTouch(kind)
    local H = CrystalHub
    local cache = H.KeeperTouchCache
    if not cache then
        cache = {}
        H.KeeperTouchCache = cache
    end
    if cache[kind] then return cache[kind] end
    local mod = H.Functions.KeeperDivesModule()
    local touch
    if mod and type(mod.track) == "function" then
        local ok, track = pcall(mod.track, kind)
        if ok and type(track) == "table" and type(track.touch) == "number" then
            touch = track.touch
            cache[kind] = touch
        end
    end
    return touch or 0.35
end

function CrystalHub.Functions.InstallTrickFilter()
    local TF = getgenv().CrystalTrickFilter
    if TF.V2 then return true end
    if not hookfunction then return false end
    local ok, Kick = pcall(function()
        return require(Services.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Kick"))
    end)
    if not ok or type(Kick) ~= "table" then return false end
    local installed = 0
    for _, modName in ipairs({ "Plan", "Header", "Bicycle", "Dive" }) do
        local module = Kick[modName]
        local fn = module and module.find
        if type(fn) == "function" then
            local orig
            local function wrapper(self, ...)
                local H = getgenv().CrystalHub
                if H and type(self) == "table" and type(self.family) == "table" then
                    local fname = self.family.name
                    local lock = H.TrickLock
                    if lock and os.clock() < lock.Until and fname ~= lock.Name then
                        return nil
                    end
                    local T = getgenv().CrystalAutoTricks
                    local auto = H.Auto
                    if T
                        and T.Enabled
                        and T.Auto == false
                        and auto
                        and auto.Phase == "air"
                        and not (T.AirFamilies and T.AirFamilies[fname]) then
                        return nil
                    end
                end
                return orig(self, ...)
            end
            local hok, res = pcall(hookfunction, fn, wrapper)
            if hok and res then
                orig = res
                installed += 1
            end
        end
    end
    TF.V2 = installed > 0
    return TF.V2 == true
end

function CrystalHub.Functions.SetTrickSelection(value)
    local T = getgenv().CrystalAutoTricks
    local catalog = CrystalHub.TrickCatalog
    local picked = {}

    local function take(name)
        if catalog[name] then
            picked[name] = true
        end
    end

    if type(value) == "table" then
        for k, v in pairs(value) do
            if type(v) == "string" then
                take(v)
            elseif v == true and type(k) == "string" then
                take(k)
            end
        end
    elseif type(value) == "string" then
        take(value)
    end

    if next(picked) == nil then
        T.Auto = true
        T.AirFamilies = {}
        T.Skills = {}
        T.Lob = false
        return true
    end

    local air, skills = {}, {}
    local lob = false
    for name in pairs(picked) do
        local entry = catalog[name]
        if entry.air then air[entry.air] = true end
        if entry.lob then lob = true end
        if entry.skill then skills[#skills + 1] = entry.skill end
    end
    T.Auto = false
    T.AirFamilies = air
    T.Skills = skills
    T.Lob = lob

    local hooked = CrystalHub.Functions.InstallTrickFilter()
    if next(air) ~= nil and not hooked then
        warn("[CrystalHub] trick filter could not be installed, air tricks are not forced")
    end
    return hooked
end

function CrystalHub.Functions.TrickChoose(st, char, root, goal, best, bike, cands, groundY, sampleNow)
    local F = CrystalHub.Functions
    local T = getgenv().CrystalAutoTricks
    local families = getgenv().CrystalSilentAim.Families
    if not families then return nil end
    local weights = {
        Bicycle = 70,
        SideVolley = 26,
        Volley = 22,
        DivingHeader = 12,
        JumpHeader = 6,
        RunningHeader = 4,
        Header = 2,
    }
    local minT = {
        DivingHeader = 0.5,
        JumpHeader = 0.55,
        RunningHeader = 0.45,
        Header = 0.3,
        Volley = 0.25,
        SideVolley = 0.3,
    }
    local clock = os.clock()
    local fail = st.Fail or {}
    local locked = st.Phase == "air" and st.LockFamily or nil
    local allowed = T.Auto == false and T.AirFamilies or nil
    local options = {}
    local bikeChecked, bikeValid = false, false
    local function viableBicycle()
        if not bikeChecked then
            bikeChecked = true
            bikeValid = bike ~= nil and st.Mods ~= nil and F.TrickBicycleOk(st, char, root, goal, sampleNow, groundY)
        end
        return bikeValid
    end
    for family, weight in pairs(weights) do
        local usable = (not allowed or allowed[family])
            and (not locked or family == locked)
            and (locked ~= nil or (fail[family] or 0) <= clock)
        if usable then
            local candidate
            if family == "Bicycle" then
                if bike and bike.h >= 8.2 and bike.h <= 11.3 and viableBicycle() then
                    candidate = bike
                end
            else
                local def = families[family]
                local h = def and def.ballHeight
                if h then
                    local preferred = (h[1] + h[2]) * 0.5
                    local floorT = locked and 0.12 or (minT[family] or 0.3)
                    local bestScore = math.huge
                    for _, c in ipairs(cands or {}) do
                        if c.t >= floorT and c.h >= h[1] + 0.08 and c.h <= h[2] - 0.08 then
                            local score = c.t * 0.75 + math.abs(c.h - preferred) * 0.08
                            if score < bestScore then
                                candidate, bestScore = c, score
                            end
                        end
                    end
                end
            end
            if candidate then
                if family == st.LastAir then weight *= 0.3 end
                options[#options + 1] = { family = family, cand = candidate, weight = weight }
            end
        end
    end
    if #options == 0 then return nil end
    local total = 0
    for _, item in ipairs(options) do total += item.weight end
    local roll = math.random() * total
    for _, item in ipairs(options) do
        roll -= item.weight
        if roll <= 0 then
            return item.cand, item.family == "Bicycle" and "away" or "goal", item.family
        end
    end
    local item = options[#options]
    return item.cand, item.family == "Bicycle" and "away" or "goal", item.family
end

function CrystalHub.Functions.SkillForced(side)
    local skills = getgenv().CrystalAutoTricks.Skills
    if not skills or #skills == 0 then return nil end
    local spec = skills[math.random(#skills)]
    local away = side > 0 and "Left" or "Right"
    return { kind = spec.kind, dir = spec.dir == "Away" and away or spec.dir, half = spec.half }
end

local CrystalUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/CrystalHub001/scripts/main/CrystalUI.luau"))()

local Window = CrystalUI:CreateWindow({
    Title = "Crystal Hub",
    Author = "By CrystalHub",
    Icon = "129839496275500",
    Tag = "Football Ragdoll",
    Folder = "CrystalHub",
    Size = UDim2.fromOffset(540, 320),
    Theme = "Purple",
    Columns = 2,
})

CrystalHub.UIController.Window = Window

Window:Category("Main")
local MainTab = Window:Tab({ Title = "Combat & Ball", Icon = "crosshair" })
local DefenseTab = Window:Tab({ Title = "Defense & GK", Icon = "shield" })

Window:Category("Player")
local PlayerTab = Window:Tab({ Title = "Movement", Icon = "user" })

Window:Category("Misc")
Window:AddSettingsTab("Settings")

CrystalHub.UIController.Tabs.Main = MainTab
CrystalHub.UIController.Tabs.Defense = DefenseTab
CrystalHub.UIController.Tabs.Player = PlayerTab

-- MainTab: Shooting & Tricks (Left) / Aim & Dribble (Right)
MainTab:Section({ Title = "Shooting", Side = "Left" })
MainTab:Toggle({
    Title = "Auto Shoot",
    Desc = "ยิงอัตโนมัติเมื่อมีโอกาสทำประตู",
    Flag = "AutoShoot",
    Default = false,
    Callback = function(state)
        local AS = getgenv().CrystalAutoShoot
        if state then
            if not CrystalHub.Functions.InstallSilentAim() then
                AS.Enabled = false
                return
            end
            pcall(CrystalHub.Functions.InstallMaxPower)
            AS.Enabled = true
            CrystalHub.Functions.StartAutoShoot()
        else
            AS.Enabled = false
            CrystalHub.Functions.StopAutoShoot()
        end
    end,
})
MainTab:Slider({
    Title = "Shoot Distance",
    Flag = "ShootRange",
    Value = { Min = 10, Max = 150, Default = 60 },
    Callback = function(value)
        getgenv().CrystalAutoShoot.Range = value
    end,
})
MainTab:Toggle({
    Title = "Auto Max Power",
    Desc = "ชาร์จพลังยิงเต็มอัตโนมัติ",
    Flag = "AutoMaxPower",
    Default = false,
    Callback = function(state)
        local MP = getgenv().CrystalMaxPower
        local forced = CrystalHub.Force ~= nil and CrystalHub.Force.Active == true
        if state then
            if not CrystalHub.Functions.InstallMaxPower() then
                MP.User = false
                MP.Enabled = forced
                return
            end
            MP.User = true
            MP.Enabled = true
        else
            MP.User = false
            MP.Enabled = forced
        end
    end,
})
MainTab:Toggle({
    Title = "Auto Curve",
    Desc = "ปั่นโค้งบอลอัตโนมัติ",
    Flag = "AutoCurve",
    Default = false,
    Callback = function(state)
        getgenv().CrystalSilentAim.AutoCurve = state
    end,
})
MainTab:Slider({
    Title = "Curve Strength (%)",
    Flag = "CurveStrength",
    Value = { Min = 50, Max = 100, Default = 100 },
    Callback = function(value)
        getgenv().CrystalSilentAim.CurveAmount = value / 100
    end,
})
MainTab:Toggle({
    Title = "Ball Tracker",
    Desc = "แสดงวิถีบอลและจุดตก",
    Flag = "BallTracker",
    Default = false,
    Callback = function(state)
        local T = getgenv().CrystalTracker
        T.Enabled = state
        if state then
            if not CrystalHub.Functions.StartBallTracker() then
                T.Enabled = false
            end
        else
            CrystalHub.Functions.StopBallTracker()
        end
    end,
})
MainTab:Colorpicker({
    Title = "Tracker Color",
    Flag = "TrackerColor",
    Default = Color3.fromRGB(43, 255, 172),
    Callback = function(c)
        getgenv().CrystalTracker.Color = c
    end,
})

MainTab:Section({ Title = "Silent Aim & Tricks", Side = "Right" })
MainTab:Toggle({
    Title = "Silent Aim",
    Desc = "บังคับทิศทางลูกยิงเข้ากรอบประตู",
    Flag = "SilentAim",
    Default = false,
    Callback = function(state)
        local SA = getgenv().CrystalSilentAim
        local forced = CrystalHub.Force ~= nil and CrystalHub.Force.Active == true
        if state then
            local ok = CrystalHub.Functions.InstallSilentAim()
            if not ok then
                SA.User = false
                SA.Enabled = forced
                return
            end
            SA.User = true
            SA.Enabled = true
        else
            SA.User = false
            SA.Enabled = forced
        end
    end,
})
MainTab:Toggle({
    Title = "Only Goal Shots",
    Desc = "ทำงานเฉพาะลูกที่ตั้งใจยิงเข้าประตู",
    Flag = "OnlyGoalShots",
    Default = SilentAimState.OnlyGoalShots,
    Callback = function(state)
        local SA = getgenv().CrystalSilentAim
        SA.OnlyGoalShots = state == true
        SA.Pending = nil
        SA.StrikeCache = nil
    end,
})
MainTab:Dropdown({
    Title = "Silent Aim Target",
    Flag = "SilentAimTarget",
    Values = { "Auto", "Top Right Corner", "Bottom Right Corner", "Top Left Corner", "Bottom Left Corner", "Top Center", "Bottom Center", "Upper Right", "Upper Left", "Lower Right", "Lower Left", "Right Post", "Left Post", "Middle" },
    Value = "Auto",
    Callback = function(value)
        CrystalHub.Functions.SetSilentTargets(value)
    end,
})
MainTab:Slider({
    Title = "Silent Aim Range",
    Flag = "SilentAimRange",
    Value = { Min = 20, Max = 300, Default = 300 },
    Callback = function(value)
        getgenv().CrystalSilentAim.Range = value
    end,
})
MainTab:Dropdown({
    Title = "Trick Select",
    Flag = "TrickSelect",
    Values = CrystalHub.TrickOptions,
    Value = "Auto",
    Callback = function(value)
        CrystalHub.Functions.SetTrickSelection(value)
    end,
})
MainTab:Toggle({
    Title = "Auto Tricks",
    Desc = "ใช้ท่าทริคและลูกกลางอากาศอัตโนมัติ",
    Flag = "AutoTricks",
    Default = false,
    Callback = function(state)
        local AT = getgenv().CrystalAutoTricks
        if state then
            if not CrystalHub.Functions.InstallSilentAim() then
                AT.Enabled = false
                return
            end
            pcall(CrystalHub.Functions.InstallMaxPower)
            if not CrystalHub.Functions.StartAutoTricks() then
                AT.Enabled = false
                return
            end
            AT.Enabled = true
        else
            AT.Enabled = false
            CrystalHub.Functions.StopAutoTricks()
        end
    end,
})
MainTab:Slider({
    Title = "Tricks Range",
    Flag = "TricksRange",
    Value = { Min = 20, Max = 120, Default = 70 },
    Callback = function(value)
        getgenv().CrystalAutoTricks.Range = value
    end,
})
MainTab:Slider({
    Title = "Defender Distance",
    Flag = "DefenderDistance",
    Value = { Min = 6, Max = 30, Default = 14 },
    Callback = function(value)
        getgenv().CrystalAutoTricks.Defender = value
    end,
})
MainTab:Toggle({
    Title = "Auto Dribble",
    Desc = "เลี้ยงบอลหลบคู่ต่อสู้ด้วยสกิล",
    Flag = "AutoDribble",
    Default = false,
    Callback = function(state)
        local AD = getgenv().CrystalAutoDribble
        if state then
            if not CrystalHub.Functions.SkillModule() then
                AD.Enabled = false
                return
            end
            AD.Enabled = true
            CrystalHub.Functions.StartAutoDribble()
        else
            AD.Enabled = false
            CrystalHub.Functions.StopAutoDribble()
        end
    end,
})
MainTab:Slider({
    Title = "Dribble Range",
    Flag = "DribbleRange",
    Value = { Min = 6, Max = 20, Default = 12 },
    Callback = function(value)
        getgenv().CrystalAutoDribble.Range = value
    end,
})
MainTab:Toggle({
    Title = "Dribble Evade",
    Desc = "หลบทิศทางผู้เล่นฝ่ายตรงข้ามขณะเลี้ยง",
    Flag = "DribbleEvade",
    Default = true,
    Callback = function(state)
        getgenv().CrystalAutoDribble.Evade = state
    end,
})
MainTab:Slider({
    Title = "Evade Strength (%)",
    Flag = "EvadeStrength",
    Value = { Min = 30, Max = 100, Default = 80 },
    Callback = function(value)
        getgenv().CrystalAutoDribble.EvadeStrength = value / 100
    end,
})

-- DefenseTab: Guard & Pickup (Left) / Goalkeeper (Right)
DefenseTab:Section({ Title = "Guard & Ball Pickup", Side = "Left" })
DefenseTab:Toggle({
    Title = "Auto Guard",
    Desc = "คุมพื้นที่และเข้าแย่งบอลอัตโนมัติ",
    Flag = "AutoGuard",
    Default = false,
    Callback = function(state)
        local GD = getgenv().CrystalGuard
        GD.Enabled = state
        if state then
            CrystalHub.Functions.StartGuard()
        else
            CrystalHub.Functions.StopGuard()
        end
    end,
})
DefenseTab:Slider({
    Title = "Guard Distance",
    Flag = "GuardDistance",
    Value = { Min = 2, Max = 20, Default = 8 },
    Callback = function(value)
        getgenv().CrystalGuard.Distance = value
    end,
})
DefenseTab:Slider({
    Title = "Guard Engage Range",
    Flag = "GuardEngageRange",
    Value = { Min = 8, Max = 45, Default = 22 },
    Callback = function(value)
        getgenv().CrystalGuard.Engage = value
    end,
})
DefenseTab:Toggle({
    Title = "Ignore Teammates",
    Flag = "IgnoreTeammates",
    Default = true,
    Callback = function(state)
        getgenv().CrystalGuard.IgnoreTeammates = state
    end,
})
DefenseTab:Toggle({
    Title = "Extended Ball Reach",
    Desc = "ขยายระยะเก็บ/เข้าถึงบอล",
    Flag = "ExtendedBallReach",
    Default = false,
    Callback = function(state)
        local R = getgenv().CrystalReach
        R.Enabled = state
        if not CrystalHub.Functions.ApplyBallReach() then
            R.Enabled = false
        end
    end,
})
DefenseTab:Slider({
    Title = "Reach Added",
    Flag = "ReachAdded",
    Value = { Min = 1, Max = 8, Default = 3 },
    Callback = function(value)
        getgenv().CrystalReach.Add = value
    end,
})
DefenseTab:Toggle({
    Title = "Auto Pickup",
    Desc = "วิ่งเข้าเก็บบอลที่ไม่มีผู้ครอบครอง",
    Flag = "AutoPickup",
    Default = false,
    Callback = function(state)
        local AP = getgenv().CrystalAutoPickup
        AP.Enabled = state
        if state then
            CrystalHub.Functions.StartAutoPickup()
        else
            CrystalHub.Functions.StopAutoPickup()
        end
    end,
})
DefenseTab:Slider({
    Title = "Pickup Range",
    Flag = "PickupRange",
    Value = { Min = 5, Max = 60, Default = 25 },
    Callback = function(value)
        getgenv().CrystalAutoPickup.Range = value
    end,
})

DefenseTab:Section({ Title = "Auto Goalkeeper", Side = "Right" })
DefenseTab:Toggle({
    Title = "Auto Goalkeeper",
    Desc = "เฝ้าประตู เซฟ และพุ่งรับบอลอัตโนมัติ",
    Flag = "AutoGoalkeeper",
    Default = false,
    Callback = function(state)
        local GK = getgenv().CrystalKeeper
        GK.Enabled = state
        if state then
            if not CrystalHub.Functions.StartKeeper() then
                GK.Enabled = false
            end
        else
            CrystalHub.Functions.StopKeeper()
        end
    end,
})
DefenseTab:Toggle({
    Title = "Keeper Dive / Slide",
    Flag = "KeeperDive",
    Default = true,
    Callback = function(state)
        getgenv().CrystalKeeper.Dive = state
    end,
})
DefenseTab:Toggle({
    Title = "Keeper Rush Out",
    Flag = "KeeperRush",
    Default = true,
    Callback = function(state)
        getgenv().CrystalKeeper.Rush = state
    end,
})
DefenseTab:Toggle({
    Title = "Keeper Gather Loose Balls",
    Flag = "KeeperGather",
    Default = true,
    Callback = function(state)
        getgenv().CrystalKeeper.Gather = state
    end,
})
DefenseTab:Toggle({
    Title = "Keeper Poke",
    Flag = "KeeperPoke",
    Default = true,
    Callback = function(state)
        getgenv().CrystalKeeper.Poke = state
    end,
})
DefenseTab:Slider({
    Title = "Keeper Depth",
    Flag = "KeeperDepth",
    Value = { Min = 2, Max = 12, Default = 5 },
    Callback = function(value)
        getgenv().CrystalKeeper.Depth = value
    end,
})
DefenseTab:Slider({
    Title = "Keeper Dive Range",
    Flag = "KeeperDiveRange",
    Value = { Min = 6, Max = 22, Default = 22 },
    Callback = function(value)
        getgenv().CrystalKeeper.DiveRange = value
    end,
})
DefenseTab:Slider({
    Title = "Keeper Rush Range",
    Flag = "KeeperRushRange",
    Value = { Min = 15, Max = 60, Default = 34 },
    Callback = function(value)
        getgenv().CrystalKeeper.RushRange = value
    end,
})

-- PlayerTab: Sprint & Speed (Left) / Ragdoll & Poke (Right)
PlayerTab:Section({ Title = "Sprint & Speed", Side = "Left" })
PlayerTab:Toggle({
    Title = "Infinite Sprint",
    Desc = "วิ่งต่อเนื่องไม่หมดแรง",
    Flag = "InfiniteSprint",
    Default = false,
    Callback = function(state)
        getgenv().CrystalSprint.Infinite = state
        CrystalHub.Functions.RefreshRunSpeed()
    end,
})
PlayerTab:Toggle({
    Title = "Auto Sprint",
    Desc = "วิ่งเร็วอัตโนมัติเมื่อขยับตัว",
    Flag = "AutoSprint",
    Default = false,
    Callback = function(state)
        getgenv().CrystalSprint.Auto = state
        if state then
            CrystalHub.Functions.StartAutoSprint()
        else
            CrystalHub.Functions.StopAutoSprint()
        end
    end,
})
PlayerTab:Slider({
    Title = "Sprint Speed (%)",
    Flag = "SprintSpeed",
    Value = { Min = 100, Max = 160, Default = 100 },
    Callback = function(value)
        getgenv().CrystalSprint.Boost = value / 100
        CrystalHub.Functions.RefreshRunSpeed()
    end,
})

PlayerTab:Section({ Title = "Ragdoll, Poke & Cooldown", Side = "Right" })
PlayerTab:Toggle({
    Title = "Anti-Tackle",
    Desc = "ลดอาการเสียหลักจากการโดนสไลด์/ปะทะ",
    Flag = "AntiTackle",
    Default = false,
    Callback = function(state)
        if state and not CrystalHub.Functions.InstallAntiRagdoll() then
            CrystalHub.Functions.SetAntiTackle(false)
            return
        end
        CrystalHub.Functions.SetAntiTackle(state)
    end,
})
PlayerTab:Toggle({
    Title = "Instant Get Up",
    Desc = "ลุกขึ้นทันทีหลังสไลด์หรือล้ม",
    Flag = "InstantGetUp",
    Default = false,
    Callback = function(state)
        if state and not CrystalHub.Functions.InstallAntiRagdoll() then
            CrystalHub.Functions.SetInstantGetUp(false)
            return
        end
        CrystalHub.Functions.SetInstantGetUp(state)
    end,
})
PlayerTab:Toggle({
    Title = "Auto Poke",
    Desc = "จิ้มแย่งบอลอัตโนมัติเมื่ออยู่ในระยะ",
    Flag = "AutoPoke",
    Default = false,
    Callback = function(state)
        local AP = getgenv().CrystalAutoPoke
        AP.Enabled = state
        if state then
            CrystalHub.Functions.StartAutoPoke()
        else
            CrystalHub.Functions.StopAutoPoke()
        end
    end,
})
PlayerTab:Slider({
    Title = "Poke Range",
    Flag = "PokeRange",
    Value = { Min = 3, Max = 12, Default = 6 },
    Callback = function(value)
        getgenv().CrystalAutoPoke.Range = value
    end,
})
PlayerTab:Toggle({
    Title = "No Tackle / Poke Cooldown",
    Desc = "ลดคูลดาวน์สไลด์และจิ้มบอล",
    Flag = "NoCooldown",
    Default = false,
    Callback = function(state)
        local NC = getgenv().CrystalNoCooldown
        NC.Enabled = state
        if state then
            CrystalHub.Functions.StartNoCooldown()
        else
            CrystalHub.Functions.StopNoCooldown()
        end
    end,
})

Window:SelectTab(1)

CrystalUI:Notify({
    Title = "Crystal Hub",
    Content = "โหลดสคริปต์สำเร็จ (" .. CURRENT_VERSION .. ")",
    Duration = 4,
    Type = "success",
})
