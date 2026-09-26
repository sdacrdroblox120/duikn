-- ==================== 自动拆建筑 · 多兵种版 ====================
-- 支持自动识别近战武器拆建筑：SapperAxe(工兵斧)/Musket(刺刀)/Sabre(宝剑)
-- 说明：玩家判定检测极苛刻，隔空打不到玩家 → 本脚本【只拆建筑，不做打玩家】
-- 改进点汇总：
--   距离可开关(0=全图) · 黑名单过滤门/玻璃 · 阵营检测 · 门玻璃开关 ·
--   列出建筑 · 同时拆多目标+连击 · 多近战武器自动识别 · 目标高亮 · 销毁

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer

-- ==================== 配置 ====================
local CFG = {
    teamFilter     = true,     -- 阵营检测：true=只拆敌方(跳过自家)；探测不到归属时仍拆
    allowDoorGlass = false,    -- 是否拆门/玻璃：false=不拆(默认), true=也拆
    range          = 0,        -- 距离限制：<=0 表示全图隔空拆；>0 表示只拆 range 米内
    interval       = 0.6,      -- 攻击节奏(秒)。太快可能触发反作弊 flood，拆不动就调大
    hitsPerTick    = 2,        -- 每个目标每轮连击次数(加速单座拆除)；调大更快但有 flood 风险
    whiteMode      = false,    -- 白名单模式：true=只拆 whitelist 命中的；false=黑名单之外都拆
    -- 门/玻璃类关键词：allowDoorGlass=false 时命中即跳过(你已实测这些名无误)
    doorGlassWords = { "door", "gate", "glass", "window", "pane", "portcullis",
                       "shutter", "barrier_door", "glasspane", "windoor" },
    blacklist      = {},       -- 其它永久黑名单：命中即跳过(暂无，按需增补)
    -- 白名单(whiteMode=true 时生效)：真正的军事防御建筑，按你实测名字增补
    whitelist  = { "barricade", "sandbag", "sand", "wall", "palisade", "abatis",
                   "fort", "rampart", "redoubt", "bunker", "blockade", "che",
                   "parapet", "emplacement", "trench", "keep", "shield",
                   "spike", "stake", "cover", "platform" },
    highlight  = true,         -- 高亮当前最近目标(SelectionBox)
}

-- 支持的近战武器(拆建筑用)：名字 -> 命中盒路径
--   SapperAxe 工兵斧  : Character.SapperAxe.MeleeHitBox.HitConstruct
--   Musket   刺刀    : Character.Musket.BayonetHitBox.HitFlesh
--   Sabre    宝剑    : Character.Sabre.MeleeHitBox.HitFlesh
local WEAPONS = {
    SapperAxe = { hitbox = "MeleeHitBox",   hit = "HitConstruct" },
    Musket    = { hitbox = "BayonetHitBox", hit = "HitFlesh" },
    Sabre     = { hitbox = "MeleeHitBox",   hit = "HitFlesh" },
}
-- 各武器攻击动画(仅视觉，找不到就不播，不影响伤害)
local ANIM = {
    SapperAxe = { "IdleToLeftReady", "LeftReadyToLeftAttack", "LeftAttackToLeftEnd", "LeftEndToIdle" },
    Musket    = { "ShoulderToBayonet", "BayonetToBayonetReady", "BayonetReadyToBayonetThrustOut",
                  "BayonetThrustOutToBayonetThrustIn", "BayonetThrustInToBayonet" },
    Sabre     = { "Sabre" },   -- 宝剑只抓到单次 "Sabre"，游戏有更多帧可在此补
}

local ENABLED = false

-- ==================== 拿远程通道 ====================
local RequestDamage, ReplicateAnimation
pcall(function() RequestDamage     = ReplicatedStorage.Requests.RequestDamage end)
pcall(function() ReplicateAnimation = ReplicatedStorage.SelectiveReplication.ReplicateAnimation end)
if not RequestDamage then
    warn("[拆] RequestDamage 未找到，请确认游戏是否改了路径")
    return
end
if not ReplicateAnimation then
    warn("[拆] ReplicateAnimation 未找到（仅影响视觉动画，不阻断拆）")
end

-- ==================== 工具函数 ====================
local function nameHas(name, tbl)
    name = string.lower(name or "")
    for _, k in ipairs(tbl) do
        if string.find(name, string.lower(k), 1, true) then return true end
    end
    return false
end

-- 探测建筑归属：返回 "own" / "enemy" / "neutral" / "unknown"
local function getTeam(model)
    local ok, res = pcall(function()
        local tv = model:FindFirstChild("Team") or model:FindFirstChild("OwningTeam")
                or model:FindFirstChild("OwnerTeam") or model:FindFirstChild("TeamValue")
        if tv and tv.Value ~= nil then return tv.Value end
        return model:GetAttribute("Team") or model:GetAttribute("OwningTeam")
             or model:GetAttribute("Owner")
    end)
    if not ok or res == nil then return "unknown" end
    local myTeam = lp.Team
    if type(res) == "string" then
        if myTeam and myTeam.Name == res then return "own" end
        if res == "" or string.find(string.lower(res), "neutral") then return "neutral" end
        return "enemy"
    end
    if typeof(res) == "Instance" then
        if myTeam and (res == myTeam or res.Name == myTeam.Name) then return "own" end
        return "enemy"
    end
    return "unknown"
end

-- 目标合法性：返回 ok, 跳过原因, model, 名字
local function checkTarget(centre, myPos)
    local model = centre:FindFirstAncestorOfClass("Model") or centre
    local name  = model.Name
    local reason = nil

    if not CFG.allowDoorGlass and nameHas(name, CFG.doorGlassWords) then
        reason = "门/玻璃(已禁用)"
    end
    if nameHas(name, CFG.blacklist) then
        reason = "黑名单"
    end
    if not reason and CFG.whiteMode and not nameHas(name, CFG.whitelist) then
        reason = "非白名单"
    end
    if not reason and CFG.teamFilter then
        local t = getTeam(model)
        if t == "own" then reason = "自家" end
        -- 中立建筑默认当可拆；如不想拆中立，把下一行注释打开：
        -- if t == "neutral" then reason = "中立" end
    end
    if not reason and CFG.range > 0 then
        if (centre.Position - myPos).Magnitude > CFG.range then reason = "超距" end
    end
    return reason == nil, reason, model, name
end

-- ==================== 缓存 ConstructCentre ====================
local centres = {}
local function rebuild()
    centres = {}
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "ConstructCentre" and v:IsA("BasePart") then
            centres[#centres + 1] = v
        end
    end
end
rebuild()
workspace.DescendantAdded:Connect(function(v)
    if v.Name == "ConstructCentre" and v:IsA("BasePart") then
        centres[#centres + 1] = v
    end
end)
workspace.DescendantRemoving:Connect(function(v)
    for i = #centres, 1, -1 do
        if centres[i] == v then table.remove(centres, i) break end
    end
end)

-- ==================== 找合法建筑 ====================
local function findBuildings()
    local list = {}
    local char = lp.Character
    if not char then return list end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return list end
    local myPos = hrp.Position
    for _, v in ipairs(centres) do
        if v and v.Parent then
            local ok, reason, model, name = checkTarget(v, myPos)
            if ok then
                list[#list + 1] = {
                    centre = v, pos = v.Position,
                    dist = (v.Position - myPos).Magnitude,
                    name = name, model = model,
                }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- ==================== 武器识别(多兵种) ====================
-- 返回 武器实例, 武器名, 命中盒部件。找不到返回 nil
-- 骑兵特有：武器/命中盒可能挂在战马模型上(不在 Character 下), 故额外扫描战马

-- 找本玩家的战马(节流缓存, 每2秒重扫一次, 避免每次全图 GetDescendants 卡顿)
local cachedHorse, horseScanT = nil, 0
local function findHorse()
    local now = tick()
    if cachedHorse and cachedHorse.Parent then return cachedHorse end
    if now - horseScanT < 2 then return cachedHorse end
    horseScanT = now
    local ws = game:GetService("Workspace")
    local char = lp.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    local near, nearD = nil, math.huge
    for _, m in ipairs(ws:GetDescendants()) do
        if m:IsA("Model") and m.Name:lower():find("horse") then
            local owner = m:GetAttribute("Owner") or m:GetAttribute("Player")
            if owner == lp then cachedHorse = m; return m end
            if myHRP then
                local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                if hrp then
                    local d = (hrp.Position - myHRP.Position).Magnitude
                    if d < nearD then nearD, near = d, m end
                end
            end
        end
    end
    cachedHorse = (nearD < 14) and near or nil   -- 只认 14 米内的战马
    return cachedHorse
end

local function scanForHit(w)
    local best
    for _, p in ipairs(w:GetDescendants()) do
        if p:IsA("BasePart") then
            local n = p.Name:lower()
            if n:find("hit") then
                if n:find("construct") or n:find("flesh") then
                    return p   -- 优先 HitConstruct/HitFlesh, 直接返回最稳
                end
                best = best or p
            end
        end
    end
    return best
end

local function getWeapon()
    local char = lp.Character
    if not char then return nil end
    -- 1. 优先匹配已知武器表(同时拿对应命中盒)
    for wname, info in pairs(WEAPONS) do
        local w = char:FindFirstChild(wname)
        if w then
            local hb = w:FindFirstChild(info.hitbox)
            local hf = hb and hb:FindFirstChild(info.hit)
            if hf then return w, wname, hf end
        end
    end
    -- 2. 兜底(核心)：扫描 角色 + 战马 下【任意】近战武器的命中盒, 不看固定盒名
    --    实测: 任何近战武器都能拆建筑, 所以只要找到了带 "Hit" 的命中 Part 就当作武器
    local containers = {}
    for _, w in ipairs(char:GetChildren()) do
        if (w:IsA("Tool") or w:IsA("Model")) and w.Name ~= "Humanoid" then
            containers[#containers + 1] = w
        end
    end
    local horse = findHorse()
    if horse then containers[#containers + 1] = horse end
    for _, w in ipairs(containers) do
        local hf = scanForHit(w)
        if hf then return w, w.Name, hf end
    end
    return nil
end

-- ==================== 动画(视觉，按武器名) ====================
local function fireAnim(state, wname)
    if not ReplicateAnimation then return end
    pcall(function()
        ReplicateAnimation:FireServer("Tool", wname or "SapperAxe", state)
    end)
end

local function playSwing(wname)
    local seq = ANIM[wname]
    if not seq then return end
    for _, s in ipairs(seq) do
        fireAnim(s, wname)
        task.wait(0.05)
    end
end

-- ==================== 列出建筑(核对名称用) ====================
local function listBuildings()
    local char = lp.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local myPos = hrp.Position
    local n = 0
    print("===== 建筑列表(ConstructCentre) =====")
    for _, v in ipairs(centres) do
        if v and v.Parent then
            local model = v:FindFirstAncestorOfClass("Model") or v
            local d = (v.Position - myPos).Magnitude
            local blocked = (not CFG.allowDoorGlass and nameHas(model.Name, CFG.doorGlassWords))
                and " [门/玻璃-跳过]" or (nameHas(model.Name, CFG.blacklist) and " [黑名单-跳过]" or "")
            local team = getTeam(model)
            print(("[%.0fm] %s | Team=%s%s"):format(d, model.Name, team, blocked))
            n = n + 1
        end
    end
    print(("===== 共 %d 个 ConstructCentre ====="):format(n))
    print("提示：门/玻璃真名若不在黑名单里，请加到脚本顶部 CFG.doorGlassWords")
end

-- ==================== UI ====================
local sg = Instance.new("ScreenGui")
sg.Name = "EGG_RemoteBreak"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999
sg.Parent = lp:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 250)
frame.Position = UDim2.new(1, -210, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = sg
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(255, 80, 80)
stroke.Thickness = 1.5
stroke.Transparency = 0.3

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 22)
title.Position = UDim2.new(0, 0, 0, 4)
title.BackgroundTransparency = 1
title.Text = "自动拆建筑·多兵种"
title.TextColor3 = Color3.fromRGB(255, 100, 100)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 30)
status.Position = UDim2.new(0, 6, 0, 26)
status.BackgroundTransparency = 1
status.Text = "未开启"
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.TextSize = 12
status.Font = Enum.Font.Gotham
status.TextWrapped = true
status.Parent = frame

local function mkBtn(text, y, w)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w or 184, 0, 30)
    b.Position = UDim2.new(0.5, -(w or 184) / 2, 0, y)
    b.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.TextSize = 13
    b.Text = text or "按钮"
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Active = true
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end

local toggleBtn = mkBtn("已关闭", 60)
local teamBtn   = mkBtn("阵营检测: 开", 96)
local doorGlassBtn = mkBtn("拆门玻璃: 关", 132)
local rangeBox  = Instance.new("TextBox")
rangeBox.Size = UDim2.new(0, 184, 0, 28)
rangeBox.Position = UDim2.new(0.5, -92, 0, 168)
rangeBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
rangeBox.Text = tostring(CFG.range)
rangeBox.PlaceholderText = "距离(0=全图)"
rangeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
rangeBox.TextSize = 13
rangeBox.Font = Enum.Font.Gotham
rangeBox.ClearTextOnFocus = false
rangeBox.Parent = frame
Instance.new("UICorner", rangeBox).CornerRadius = UDim.new(0, 6)

local listBtn    = mkBtn("列出建筑", 200, 90)
local destroyBtn = mkBtn("销毁", 200, 90)
listBtn.Position = UDim2.new(0, 8, 0, 200)
destroyBtn.Position = UDim2.new(1, -98, 0, 200)
destroyBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 40)

local function setStatus(t) status.Text = t end

-- ==================== 按钮逻辑 ====================
toggleBtn.Activated:Connect(function()
    ENABLED = not ENABLED
    if ENABLED then
        toggleBtn.Text = "已开启"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        setStatus("运行中…")
        rebuild()
    else
        toggleBtn.Text = "已关闭"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        setStatus("已关闭")
    end
end)

teamBtn.Activated:Connect(function()
    CFG.teamFilter = not CFG.teamFilter
    teamBtn.Text = "阵营检测: " .. (CFG.teamFilter and "开" or "关")
end)

doorGlassBtn.Activated:Connect(function()
    CFG.allowDoorGlass = not CFG.allowDoorGlass
    doorGlassBtn.Text = "拆门玻璃: " .. (CFG.allowDoorGlass and "开" or "关")
end)

rangeBox.FocusLost:Connect(function()
    local v = tonumber(rangeBox.Text)
    CFG.range = (v and v >= 0) and v or 0
    rangeBox.Text = tostring(CFG.range)
    setStatus(CFG.range > 0 and ("距离限制: " .. CFG.range .. "m") or "距离: 全图")
end)

listBtn.Activated:Connect(function()
    listBuildings()
    setStatus("已在输出栏列出建筑")
end)

destroyBtn.Activated:Connect(function()
    ENABLED = false
    if hlBox then pcall(function() hlBox:Destroy() end); hlBox = nil end
    pcall(function() sg:Destroy() end)
end)

-- ==================== 高亮 ====================
local hlBox = nil
local function setHighlight(target)
    if hlBox then pcall(function() hlBox:Destroy() end); hlBox = nil end
    if CFG.highlight and target and target.centre and target.centre.Parent then
        local sb = Instance.new("SelectionBox")
        sb.Adornee = target.centre
        sb.Color3 = Color3.fromRGB(255, 60, 60)
        sb.LineThickness = 0.05
        sb.Parent = target.centre
        hlBox = sb
    end
end

-- ==================== 主循环 ====================
local lastTime = 0
RunService.Heartbeat:Connect(function()
    if not ENABLED then return end
    local now = os.clock()
    if now - lastTime < CFG.interval then return end
    lastTime = now

    local char = lp.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        setStatus("角色未就绪"); return
    end

    -- 自动识别当前装备的近战武器
    local w, wname, hf = getWeapon()
    if not w then
        setStatus("未装备近战武器(斧/刺刀/宝剑)")
        return
    end

    local list = findBuildings()
    if #list == 0 then
        setStatus("无合法目标(过滤后)" .. " | 武器:" .. wname)
        setHighlight(nil)
        return
    end

    -- 对所有合法目标同时发伤害(隔空)；hitsPerTick 控制单座连击加速
    for i = 1, #list do
        local t = list[i]
        if t.centre and t.centre.Parent then
            for _ = 1, CFG.hitsPerTick do
                pcall(function()
                    RequestDamage:FireServer(t.centre, t.pos, w, "Melee", nil, hf)
                end)
            end
        end
    end
    local nearest = list[1]
    setHighlight(nearest)
    setStatus(("拆(%s): %d 个 | 最近 %s (%.0fm)"):format(wname, #list, nearest.name, nearest.dist))
    task.spawn(function() pcall(playSwing, wname) end)  -- 视觉动画异步播
end)

setStatus("就绪 · 点『已关闭』开启")
print("[拆] 多兵种版已加载。支持 斧/刺刀/宝剑 自动识别拆建筑。先点『列出建筑』核对门/玻璃名。")
