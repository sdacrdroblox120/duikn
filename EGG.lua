--[[
================================================================================
  EGG  ·  防踢 + 传送  (好友保护版)
================================================================================
  ★ 本脚本现名 EGG (界面标题 / GUI 名 / 配置文件 / 控制台横幅 统一为 EGG)
================================================================================
  本版相对于 v1 的改动:
    1. 删除"被投票时自动反制" —— 该功能不成立(被别人投票时无法改变结果)
    2. 防踢改为「全自动踢人」: 脚本自己循环随机踢人, 无需手动选
    3. 保护对象: 只保护好友 (GetFriendsAsync + IsFriendsWith 双保险), 默认常开不可关闭
    4. 传送: 持续贴背跟随, 恒定开启不可关闭
    5. 踢人 = 单个"★ 踢人 (自动循环)"开关: 开即启用踢人 + 启动自动循环 (已合并原"踢人功能"与"自动踢人")
    6. 去重: 交给服务端投票冷却 (命中冷却自动丢弃) + 临时排除表, 不再提供"去重冷却"滑块
    7. 目标死亡自动换人: 默认随机模式(防规律), 可选最近模式
    7. 跟随失败保护: 默认开启, 跑远/掉地图/被拉回时自动重贴
    8. 踢人通知: 屏幕上方小字 + 提示音(可关), 三条文案随机
    9. 面板分区: 顶部标签页 [战斗] [玩家]
   10. 右上角 [—] 收进悬浮球 / [✕] 彻底销毁
================================================================================
]]

--//===================================================== 服务
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local SoundService     = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--//===================================================== 配置
local CONFIG = {
    -- 踢人
    AntiKick_Enabled     = false,   -- ★默认关闭
    AntiKick_ProtectFriend = true,  -- ★不踢好友
    AntiKick_AutoKick    = false,   -- ★自动循环踢人
    AntiKick_KickInterval= 2.0,     -- ★自动踢人间隔(秒), 可调
    -- ★踢人通知 (屏幕上方小字 + 提示音)
    Kick_Notify          = true,    -- 通知总开关
    Kick_Notify_Sound    = true,    -- 提示音开关
    Kick_SoundId         = "rbxassetid://112972396921894",
    Kick_SoundVolume     = 0.25,    -- 音量(0~1), 刻意调低不打扰

    -- 传送
    Teleport_Enabled     = false,   -- ★默认关闭; 开启后自动循环
    Teleport_Interval    = 1.0,     -- 切换目标的间隔(秒)
    Teleport_SafeCheck   = true,    -- 落点安全检测
    Teleport_MaxDistance = 1000,    -- 最大传送距离
    Teleport_SafeY       = -100,    -- 安全高度下限

    -- ★背后跟随
    Follow_Distance      = 4.0,     -- 距离(studs), 默认开启不可关闭
    Follow_Height        = 2.0,     -- 高度(studs)
    Follow_Interval      = 0.05,    -- 跟随更新间隔(秒)
    Follow_SafeCheck     = true,    -- 跟随时的安全检查
    -- ★跟随失败保护 (默认开启)
    Follow_FailGuard     = true,    -- 总开关
    Follow_FailDist      = 120,     -- 离目标超过这个距离(studs)就判定失败并重贴
    Follow_FailDelay     = 0.8,     -- 连续失败多久(秒)才触发重贴, 防误判
    Follow_RetryWait     = 0.6,     -- 重贴前的等待(秒)
    Follow_KeepOnDeath   = true,    -- ★目标死亡后自动换人 (开启)
    -- ★换人模式: "nearest" = 换距离最近的 (默认)
    --             "random"  = 随机换 (不易被摸规律, 手动切换)
    Follow_SwitchMode    = "nearest",
    -- ★防规律: 换人时随机等待 0~N 秒再动 (仅 random 模式生效)
    Follow_SwitchJitter  = 0.6,

    -- ★有人投票踢我时的提醒 (屏幕上方小字, 不挡视野)
    Warn_OnVoted         = true,

    -- ★白名单 (手动保护名单, 比好友列表可靠)
    Whitelist            = {},       -- 从配置读取, 面板可增删

    -- ★UI 外观
    UI_Transparency      = 0.05,     -- 面板透明度 (0=不透明, 1=全透明)
    UI_Scale             = 1.0,      -- 面板缩放 (0.7~1.4)
    FrameOuter_Alpha     = 0,        -- 渐变外框透明度 (0=不透明, 1=全透明)
    -- ★显示/隐藏快捷键 (固定 T 键, 面板里不提供改绑)
    HOTKEY               = "T",

    -- ★UI 点击音效 (任何控件被点都响一声)
    UI_Sound             = true,     -- 总开关
    UI_SoundId           = "rbxassetid://6895079853",  -- 干净"咔"
    UI_SoundVolume       = 0.4,      -- 点击音音量 (用户指定默认 0.4)
    UI_SoundPitch        = 1.0,      -- 音调 (1=原声)

    -- ★启动动画
    Startup_Anim         = true,     -- 是否播放开场动画
    Startup_SoundId      = "rbxassetid://96236966661980",  -- sonic-exe 笑声
    Startup_SoundVolume  = 0.9,      -- 启动音音量 (用户指定默认 0.9)
}

-- ★配置文件路径 (持久化到执行器目录)
local CONFIG_FILE = "EGG_config.json"

--//===================================================== 状态
local STATE = {
    friendSet      = {},        -- 好友名字集合(小写)
    friendLoaded   = false,     -- 好友列表是否已加载
    friendCount    = 0,         -- ★好友真实人数 (1 人 = 1, 不重复计数)
    teleportLoop   = nil,       -- 循环传送线程
    pickerFrame    = nil,       -- 选择传送面板
    pickerActive   = false,     -- 选择传送是否已开启
    followConn     = nil,       -- ★背后跟随的连接
    followTarget   = nil,       -- ★当前锁定的跟随目标
    kickEnabled    = false,     -- 踢人开关状态

    voteStatus     = {},        -- {[playerName] = {votes=n, need=n}} 从服务端事件同步
    kickExclude    = {},        -- ★"即将离开"排除表: 票数到阈值的人临时排除, 避免白投票 (非用户去重冷却)

    -- ★自动换人
    switching      = false,     -- 是否正在换人(防止重复触发)
    manualLock     = false,     -- 是否由"选择敌人传送"手动锁定 (不自动换人)

    -- ★跟随失败保护
    failSince      = nil,       -- 连续失败开始的时间戳
    retrying       = false,     -- 是否正在重贴

    -- ★UI 状态
    hudLabel       = nil,       -- 屏幕上方小字
    hudSeq         = 0,         -- 小字序号(用于定时清除)
    soundObj       = nil,       -- 提示音实例
    sounds         = {},        -- ★音效实例缓存 {click=Sound, startup=Sound}
    startupGui     = nil,       -- ★启动动画 GUI
    tab            = "combat",  -- 当前标签页
    panel          = nil,       -- 主面板
    ball           = nil,       -- 悬浮球
    collapsed      = false,     -- 是否已收进悬浮球
    destroyed      = false,     -- 是否已彻底销毁
}

--//===================== UI =====================

local THEME = {
    -- ★底色层 (深空紫青: 偏紫的深色底, 与紫青渐变同色系)
    bg      = Color3.fromRGB(13, 13, 18),      -- 面板底
    panel   = Color3.fromRGB(23, 23, 31),      -- 控件块
    panelHi = Color3.fromRGB(36, 36, 46),      -- 控件悬停/高亮
    stroke  = Color3.fromRGB(45, 42, 60),      -- 分隔线 (带一点紫调)
    dim     = Color3.fromRGB(110, 110, 130),

    -- ★强调色 (取三色渐变里的紫色端, 用于单色场景)
    accent  = Color3.fromRGB(168, 85, 247),    -- 紫 #A855F7
    accent2 = Color3.fromRGB(34, 211, 238),    -- 青 #22D3EE
    accentDim = Color3.fromRGB(70, 36, 110),   -- 强调色的暗态

    -- ★三色渐变主色 (★恢复: 紫 → 靛 → 青)
    g1      = Color3.fromRGB(168, 85, 247),    -- 紫 #A855F7
    g2      = Color3.fromRGB(99, 102, 241),    -- 靛 #6366F1
    g3      = Color3.fromRGB(34, 211, 238),    -- 青 #22D3EE

    -- ★状态色
    on      = Color3.fromRGB(52, 211, 153),    -- 成功绿 #34D399
    danger  = Color3.fromRGB(248, 113, 113),   -- 危险红 #F87171
    warn    = Color3.fromRGB(251, 191, 36),    -- 警告黄 #FBBF24
    friend  = Color3.fromRGB(120, 170, 255),   -- 好友

    -- ★文字
    text    = Color3.fromRGB(236, 236, 242),
    subtext = Color3.fromRGB(150, 150, 168),

    -- ★WindUI 保留下来的"轨道/次级面"色 (控件细节沿用)
    track   = Color3.fromRGB(45, 42, 60),      -- 开关关闭 / 滑块未填充
    knob    = Color3.fromRGB(255, 255, 255),   -- 开关圆点纯白
}

--//===================== ★ 渐变工具 =====================
--
-- 【关键】Roblox 的 UIGradient 与父对象 BackgroundColor3 **相乘**。
-- 如果底色是深色, 渐变会被压得几乎看不见。所以工厂函数强制把底色刷白,
-- 让渐变色原样显示。
--
-- 【WindUI 风改造】WindUI 是"单一强调色 + 扁平实心", 基本不用渐变。
-- 这里的色序全部退化为**同色**(视觉上等于纯色), 保留 applyGradient 调用
-- 是为了不改动 19 处调用点; 想恢复渐变只要往色序里加回不同的颜色即可。
--
-- 另外: ScrollingFrame 和 TextBox **不支持** UIGradient, 这两处不要用。

--- 常用色序 (★三色渐变: 紫 → 靛 → 青)
local GRAD = {
    -- 主渐变: 对角 135° 用, 三个关键点保证中间过渡不跳色
    purpleCyan = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    THEME.g1),   -- 紫
        ColorSequenceKeypoint.new(0.5,  THEME.g2),   -- 靛
        ColorSequenceKeypoint.new(1,    THEME.g3),   -- 青
    }),
    -- 亮一档的主渐变 (给需要强调的元素)
    purpleCyanBright = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(192, 132, 252)),  -- 亮紫
        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(129, 140, 248)),  -- 亮靛
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(103, 232, 249)),  -- 亮青
    }),
    -- 开关打开态: 绿 → 青 (冷暖过渡, 和主渐变区分开)
    greenCyan = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(52, 211, 153)),   -- 绿
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(34, 211, 238)),   -- 青
    }),
    -- 单色短序列 (给纯色元素叠渐变用)
    solid = function(c)
        return ColorSequence.new(c, c)
    end,
}

--- 给对象加渐变 (自动把底色刷白, 避免相乘变暗)
--- 用 pcall 包裹: 部分执行器可能不支持 UIGradient, 失败时保持纯色不崩
--- @param obj GuiObject
--- @param colors ColorSequence
--- @param rotation number|nil 默认 0 (左→右)
--- @param transparency NumberSequence|nil
--- @return UIGradient|nil
local function applyGradient(obj, colors, rotation, transparency)
    if not obj then return nil end
    obj.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

    local ok, g = pcall(function()
        local inst = Instance.new("UIGradient")
        inst.Color    = colors
        inst.Rotation = rotation or 0
        if transparency then inst.Transparency = transparency end
        inst.Parent   = obj
        return inst
    end)
    if ok then return g end

    -- 回退: 用纯色近似 (不崩, 只是没有渐变)
    pcall(function()
        local cs = colors.Keypoints
        obj.BackgroundColor3 = cs[1].Value
    end)
    return nil
end

--- 加外发光 (两层 UIStroke, 外粗内细)
--- @param obj GuiObject
--- @param color Color3
--- @return table {gradientStroke, glowStroke}
local function applyGlow(obj, color)
    color = color or THEME.g1

    local glow = Instance.new("UIStroke")
    glow.Color            = color
    glow.Thickness        = 5
    glow.Transparency     = 0.82
    glow.ApplyStrokeMode  = Enum.ApplyStrokeMode.Border
    glow.Parent           = obj
    local gc = Instance.new("UICorner")
    gc.CornerRadius = UDim.new(1, 0)
    gc.Parent = glow

    local core = Instance.new("UIStroke")
    core.Color           = color
    core.Thickness       = 1.5
    core.Transparency    = 0.25
    core.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    core.Parent          = obj
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(1, 0)
    cc.Parent = core

    return core, glow
end

--//===================== UI =====================

--//===================================================== 工具

--//===================== ★ 自定义通知系统 (不用 Roblox 系统通知) =====================
--
-- 原生通知样式固定、做不到高级感, 而且在部分执行器里被禁用。
-- 这里自己做一套: 右上角滑入卡片, 紫青渐变描边, 状态色左边条, 可堆叠。
--
-- 卡片结构:
--   ScreenGui
--    └ 右上角锚点容器 (AnchorPoint 1,0)
--       └ UIListLayout (Vertical, 底部对齐)
--          └ 卡片 Frame
--             ├ 左侧 3px 状态色竖条
--             ├ 图标圆 (实心状态色 + 内嵌符号)
--             ├ 标题 TextLabel
--             ├ 正文 TextLabel (自动换行)
--             └ UIGradient 描边

--- 通知类型 → 颜色
local NOTIFY_KIND = {
    info    = Color3.fromRGB(168, 85, 247),    -- 紫
    success = Color3.fromRGB(52, 211, 153),    -- 绿
    warn    = Color3.fromRGB(251, 191, 36),    -- 黄
    error   = Color3.fromRGB(248, 113, 113),   -- 红
    kick    = Color3.fromRGB(248, 113, 113),   -- 红 (踢人专用)
}

--- 通知类型 → 图标文字 (用 ASCII, 避免字体缺字变方框)
local NOTIFY_ICON = {
    info    = "i",
    success = "v",   -- 完成
    warn    = "!",
    error   = "x",
    kick    = "x",
}

local NOTIFY_MAX      = 4      -- 同时最多显示几张
local NOTIFY_CARD_W   = 300    -- 卡片宽
local NOTIFY_GAP      = 8      -- 卡片间距

--- 初始化通知 GUI (懒加载, 第一次调用时才建)
local function ensureNotifyGui()
    local gui = STATE.notifyGui
    if gui and gui.Parent then return gui end

    gui = Instance.new("ScreenGui")
    gui.Name = "EGG_Notify"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    pcall(function()
        gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if not gui.Parent then
        pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
    end

    -- 锚点容器: 右上角
    local holder = Instance.new("Frame")
    holder.Name = "Holder"
    holder.BackgroundTransparency = 1
    holder.AnchorPoint = Vector2.new(1, 0)
    holder.Position = UDim2.new(1, -12, 0, 12)
    holder.Size = UDim2.new(0, NOTIFY_CARD_W, 0, 10)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.Parent = gui

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, NOTIFY_GAP)
    layout.Parent = holder

    STATE.notifyGui    = gui
    STATE.notifyHolder = holder
    STATE.notifyCards  = {}
    STATE.notifySeq    = 0
    return gui
end

--- 把最老的一张卡片顶出去 (超出堆叠上限时)
local function evictOldestCard()
    local cards = STATE.notifyCards
    if not cards or #cards == 0 then return end
    local oldest, oldestOrder = nil, math.huge
    for _, c in ipairs(cards) do
        if c.Parent and (c.LayoutOrder or 0) < oldestOrder then
            oldest, oldestOrder = c, c.LayoutOrder or 0
        end
    end
    if oldest and oldest:GetAttribute("Dismissing") ~= true then
        oldest:SetAttribute("Dismissing", true)
        task.spawn(function()
            local tw = TweenService:Create(oldest, TweenInfo.new(0.18, Enum.EasingStyle.Quad,
                Enum.EasingDirection.In), {
                Position = UDim2.new(1, NOTIFY_CARD_W + 40, 0, 0),
                BackgroundTransparency = 1,
            })
            tw:Play(); tw.Completed:Wait()
            oldest:Destroy()
        end)
    end
end

--- 移除一张卡片 + 从列表摘掉
local function dismissCard(card)
    if not card or not card.Parent then return end
    if card:GetAttribute("Dismissing") then return end
    card:SetAttribute("Dismissing", true)

    local cards = STATE.notifyCards or {}
    for i, c in ipairs(cards) do
        if c == card then table.remove(cards, i); break end
    end

    local tw = TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Quad,
        Enum.EasingDirection.In), {
        Position = UDim2.new(1, NOTIFY_CARD_W + 40, 0, 0),
        BackgroundTransparency = 1,
    })
    tw:Play()
    tw.Completed:Connect(function() if card.Parent then card:Destroy() end end)
end

--- 创建一张通知卡片
--- @param title string
--- @param text string
--- @param duration number|nil
--- @param kind string|nil  info/success/warn/error/kick
local function notify(title, text, duration, kind)
    -- 失败不影响主流程: 整个通知系统用 pcall 包住
    pcall(function()
        local gui = ensureNotifyGui()
        if not gui then return end

        duration = duration or 3
        kind = kind or "info"
        local color = NOTIFY_KIND[kind] or NOTIFY_KIND.info

        -- ★同标题节流: 1 秒内不重复弹 (防止循环里刷屏)
        STATE.notifyThrottle = STATE.notifyThrottle or {}
        local key = tostring(title)
        local last = STATE.notifyThrottle[key]
        if last and (os.clock() - last) < 1.0 then return end
        STATE.notifyThrottle[key] = os.clock()

        -- 超出上限先把最老的顶走
        if #(STATE.notifyCards or {}) >= NOTIFY_MAX then
            evictOldestCard()
        end

        STATE.notifySeq = (STATE.notifySeq or 0) + 1
        local order = STATE.notifySeq

        -- 卡片本体
        local card = Instance.new("Frame")
        card.Name = "NotifyCard"
        card.Size = UDim2.new(0, NOTIFY_CARD_W, 0, 54)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Color3.fromRGB(18, 18, 25)
        card.BackgroundTransparency = 0.06
        card.BorderSizePixel = 0
        card.LayoutOrder = order
        -- 初始位置: 屏幕外右侧 (滑入起点)
        card.Position = UDim2.new(1, NOTIFY_CARD_W + 40, 0, 0)
        card.Parent = STATE.notifyHolder

        local cc = Instance.new("UICorner")
        cc.CornerRadius = UDim.new(0, 10)
        cc.Parent = card

        -- 描边 (WindUI 风: 一条极淡的中性细线, 不做彩色渐变)
        local stroke = Instance.new("UIStroke")
        stroke.Color = THEME.stroke
        stroke.Thickness = 1
        stroke.Transparency = 0.3
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = card

        -- 内边距容器 (给左侧色条和图标让位)
        local pad = Instance.new("Frame")
        pad.BackgroundTransparency = 1
        pad.Position = UDim2.new(0, 38, 0, 8)
        pad.Size = UDim2.new(1, -50, 0, 20)
        pad.Parent = card

        local padLayout = Instance.new("UIListLayout")
        padLayout.FillDirection = Enum.FillDirection.Vertical
        padLayout.SortOrder = Enum.SortOrder.LayoutOrder
        padLayout.Padding = UDim.new(0, 2)
        padLayout.Parent = pad

        -- ★左侧状态色竖条 (呼吸效果)
        local bar = Instance.new("Frame")
        bar.Name = "AccentBar"
        bar.Size = UDim2.new(0, 3, 1, -16)
        bar.Position = UDim2.new(0, 0, 0, 8)
        bar.BackgroundColor3 = color
        bar.BorderSizePixel = 0
        bar.Parent = card
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(1, 0)
        bc.Parent = bar
        -- 呼吸: 透明度来回
        task.spawn(function()
            while bar.Parent and not card:GetAttribute("Dismissing") do
                local t1 = TweenService:Create(bar, TweenInfo.new(0.7), {BackgroundTransparency = 0.5})
                t1:Play(); t1.Completed:Wait()
                -- ★卡片已被销毁 (超时/被顶走) → 立刻收尾, 不再等下一次 Completed
                if not bar.Parent or not card.Parent then break end
                local t2 = TweenService:Create(bar, TweenInfo.new(0.7), {BackgroundTransparency = 0.05})
                t2:Play(); t2.Completed:Wait()
            end
        end)

        -- ★图标圆
        local iconBg = Instance.new("Frame")
        iconBg.Size = UDim2.new(0, 22, 0, 22)
        iconBg.Position = UDim2.new(0, 11, 0, 12)
        iconBg.BackgroundColor3 = color
        iconBg.BorderSizePixel = 0
        iconBg.Parent = card
        local icc = Instance.new("UICorner")
        icc.CornerRadius = UDim.new(1, 0)
        icc.Parent = iconBg

        local iconTxt = Instance.new("TextLabel")
        iconTxt.Size = UDim2.new(1, 0, 1, 0)
        iconTxt.BackgroundTransparency = 1
        iconTxt.Text = NOTIFY_ICON[kind] or "i"
        iconTxt.TextColor3 = Color3.fromRGB(15, 15, 20)
        iconTxt.TextSize = 12
        iconTxt.Font = Enum.Font.GothamBold
        iconTxt.Parent = iconBg

        -- 标题
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, 0, 0, 15)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = tostring(title)
        titleLbl.TextColor3 = THEME.text
        titleLbl.TextSize = 13
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.LayoutOrder = 1
        titleLbl.Parent = pad

        -- 正文 (自动换行, 高度自适应)
        local bodyLbl = Instance.new("TextLabel")
        bodyLbl.Size = UDim2.new(1, 0, 0, 0)
        bodyLbl.AutomaticSize = Enum.AutomaticSize.Y
        bodyLbl.BackgroundTransparency = 1
        bodyLbl.Text = tostring(text)
        bodyLbl.TextColor3 = THEME.subtext
        bodyLbl.TextSize = 11
        bodyLbl.Font = Enum.Font.Gotham
        bodyLbl.TextXAlignment = Enum.TextXAlignment.Left
        bodyLbl.TextYAlignment = Enum.TextYAlignment.Top
        bodyLbl.TextWrapped = true
        bodyLbl.LayoutOrder = 2
        bodyLbl.Parent = pad

        table.insert(STATE.notifyCards, card)

        -- ① 滑入 (带一点回正)
        card.Rotation = 2
        local slideIn = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0),
            Rotation = 0,
        })
        slideIn:Play()

        -- ② 停留 duration 秒
        task.delay(duration, function()
            dismissCard(card)
        end)
    end)
end

--- 仅通知, 不带音效 (音效由调用点自己控制)
local function notifySimple(title, text, kind)
    notify(title, text, 3, kind)
end

--//===================== ★ 踢人通知 (屏幕上方小字 + 提示音) =====================

-- 三条文案随机切换 (-- 是分隔符, 后面接真实用户名)
local KICK_NOTIFY_TEMPLATES = {
    "已投票 -- %s",
    "防踢护盾已成功防卫 -- %s",
    "已投票 -- %s",
}

--- 在屏幕上方刷一小行字 (几秒后自动消失, 不显示在面板里)
--- @param text string
--- @param color Color3|nil 自定义颜色 (默认白色)
local function showHud(text, color)
    STATE.hudSeq = STATE.hudSeq + 1
    local mySeq = STATE.hudSeq

    -- 复用已有 Label, 没有就创建
    local lbl = STATE.hudLabel
    if not lbl or not lbl.Parent then
        local gui = Instance.new("ScreenGui")
        gui.Name = "EGG_HUD"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999
        gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

        lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0, 460, 0, 26)
        lbl.Position = UDim2.new(0.5, -230, 0, 14)   -- 屏幕上方
        lbl.BackgroundTransparency = 1
        lbl.Text = ""
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeTransparency = 0.35
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.TextSize = 16
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.Visible = false
        lbl.Parent = gui

        STATE.hudLabel = lbl
        STATE.hudGui   = gui
    end

    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    lbl.TextTransparency = 0
    lbl.Visible = true

    -- 2.5 秒后淡出
    task.delay(2.5, function()
        if STATE.hudSeq ~= mySeq then return end   -- 已被新消息顶掉
        if not lbl or not lbl.Parent then return end

        for i = 0, 10 do
            lbl.TextTransparency = i / 10
            if STATE.hudSeq ~= mySeq then return end
            task.wait(0.03)
        end
        lbl.Visible = false
    end)
end

--- 播放提示音 (音量刻意调低)
local function playKickSound()
    if not CONFIG.Kick_Notify or not CONFIG.Kick_Notify_Sound then return end

    pcall(function()
        if not STATE.soundObj or not STATE.soundObj.Parent then
            local snd = Instance.new("Sound")
            snd.Name = "AntiKickBeep"
            snd.SoundId = CONFIG.Kick_SoundId
            snd.Volume = CONFIG.Kick_SoundVolume
            snd.Parent = SoundService
            STATE.soundObj = snd
        end
        local snd = STATE.soundObj
        snd.SoundId = CONFIG.Kick_SoundId
        snd.Volume = CONFIG.Kick_SoundVolume
        snd:Play()
    end)
end

--- ★通用音效播放 (UI 点击 / 启动动画 共用)
--- 每个音效独立实例, 避免互相打断
--- @param key string 实例缓存键
--- @param soundId string
--- @param volume number
--- @param pitch number|nil
local function playSound(key, soundId, volume, pitch)
    if not soundId or soundId == "" then return end
    pcall(function()
        local cache = STATE.sounds
        local snd = cache[key]
        if not snd or not snd.Parent then
            snd = Instance.new("Sound")
            snd.Name = "EGG_" .. key
            snd.Parent = SoundService
            snd.Looped = false
            cache[key] = snd
        end
        snd.SoundId = soundId
        snd.Volume  = volume or 0.5
        snd.PlaybackSpeed = pitch or 1
        if snd.IsPlaying then snd:Stop() end
        snd:Play()
    end)
end

--- ★UI 点击音效 (挂到所有可点控件上)
--   pitchOverride: 可选, 直接指定 PlaybackSpeed (滑块随位置变速时用)
local function playClickSound(pitchOverride)
    if not CONFIG.UI_Sound then return end
    playSound("click", CONFIG.UI_SoundId, CONFIG.UI_SoundVolume, pitchOverride or CONFIG.UI_SoundPitch)
end

--- ★启动动画音效
local function playStartupSound()
    if not CONFIG.Startup_Anim then return end
    playSound("startup", CONFIG.Startup_SoundId, CONFIG.Startup_SoundVolume, 1)
end

--- ★有人投票踢我时的警告 (屏幕上方红色小字 + 右上角通知卡片)
local function showVoteWarning(initiatorName, votes, need)
    if not CONFIG.Warn_OnVoted then return end

    local who = initiatorName or "有人"
    local detail, text
    if votes and need and need > 0 then
        detail = string.format("%d / %d 票", votes, need)
        text = string.format("!! %s 正在投票踢你  (%d/%d)", who, votes, need)
    else
        detail = "票数统计中"
        text = string.format("!! %s 正在投票踢你", who)
    end
    showHud(text, Color3.fromRGB(255, 95, 95))
    notify("被投票警告", string.format("%s 正在投票踢你 -- %s", who, detail), 4, "error")
end

--- 踢人成功后的统一通知 (小字 + 随机文案 + 音效)
--- @param targetName string
local function notifyKickDone(targetName)
    if not CONFIG.Kick_Notify then return end

    -- ★节流: 同一目标 1 秒内只播一次字和音, 防止循环投票时音效叠放/刷屏
    local key = string.lower(tostring(targetName))
    local last = STATE.lastKickNotify and STATE.lastKickNotify[key]
    if last and (os.clock() - last) < 1.0 then return end
    STATE.lastKickNotify = STATE.lastKickNotify or {}
    STATE.lastKickNotify[key] = os.clock()

    local tpl = KICK_NOTIFY_TEMPLATES[math.random(1, #KICK_NOTIFY_TEMPLATES)]
    showHud(string.format(tpl, targetName))
    -- ★右上角通知卡片 (与服务端确认过的成功投票一一对应)
    notify("投票已提交", "已投票 -- " .. tostring(targetName), 2.5, "kick")
    playKickSound()
end

--//===================== ★ 平台识别 (移动端适配) =====================

--- 判断是否触摸/移动端
local function isTouchDevice()
    local ok, res = pcall(function()
        return UserInputService.TouchEnabled
            and not UserInputService.KeyboardEnabled
            and not UserInputService.MouseEnabled
    end)
    return ok and res or false
end

local IS_MOBILE = isTouchDevice()

--- 平台相关的尺寸参数
local UI_METRICS = IS_MOBILE and {
    panelW      = 290,   -- 面板宽
    rowH        = 40,    -- 行高(开关/按钮)
    sliderH     = 54,    -- 滑块块高
    trackH      = 10,    -- 滑轨粗细
    knobSize    = 20,    -- 滑块圆点
    switchW     = 42,    -- 开关宽
    switchH     = 22,    -- 开关高
    fontSize    = 14,    -- 正文
    titleSize   = 17,    -- 标题
    tabH        = 36,    -- 标签栏高
    ballSize    = 58,    -- 悬浮球直径
    headerH     = 44,    -- 头部高
    spacing     = 8,     -- 控件间距
} or {
    panelW      = 230,
    rowH        = 30,
    sliderH     = 44,
    trackH      = 6,
    knobSize    = 14,
    switchW     = 32,
    switchH     = 16,
    fontSize    = 12,
    titleSize   = 15,
    tabH        = 28,
    ballSize    = 46,
    headerH     = 34,
    spacing     = 6,
}

--//===================== ★ 配置持久化 =====================

-- 需要持久化的字段
local PERSIST_KEYS = {
    "AntiKick_Enabled", "AntiKick_ProtectFriend", "AntiKick_AutoKick",
    "AntiKick_KickInterval",
    "Kick_Notify", "Kick_Notify_Sound", "Warn_OnVoted",
    "Teleport_Enabled", "Teleport_SafeCheck",
    "Follow_Distance", "Follow_Height", "Follow_KeepOnDeath",
    "Follow_SwitchMode", "Follow_FailGuard", "Follow_SafeCheck",
    "UI_Transparency", "UI_Scale", "FrameOuter_Alpha",
    "UI_Sound", "UI_SoundVolume", "UI_SoundPitch",
    "Startup_Anim", "Startup_SoundVolume",
}

local function hasFs()
    return type(writefile) == "function" and type(readfile) == "function"
end

--- 加载配置
local function loadConfig()
    if not hasFs() then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw then return end

    local ok2, data = pcall(function()
        return game:GetService("HttpService"):JSONDecode(raw)
    end)
    if not ok2 or type(data) ~= "table" then return end

    for _, k in ipairs(PERSIST_KEYS) do
        if data[k] ~= nil then
            CONFIG[k] = data[k]
        end
    end

    -- 白名单单独处理
    if type(data.Whitelist) == "table" then
        CONFIG.Whitelist = {}
        for _, n in ipairs(data.Whitelist) do
            if type(n) == "string" then
                table.insert(CONFIG.Whitelist, n)
            end
        end
    end
end

--- 保存配置
local function saveConfig()
    if not hasFs() then return false end

    local data = {}
    for _, k in ipairs(PERSIST_KEYS) do
        data[k] = CONFIG[k]
    end
    data.Whitelist = CONFIG.Whitelist or {}

    local ok, json = pcall(function()
        return game:GetService("HttpService"):JSONEncode(data)
    end)
    if not ok then return false end

    local ok2 = pcall(writefile, CONFIG_FILE, json)
    return ok2
end

--//===================== ★ 白名单 =====================

--- 判断是否在白名单里 (大小写不敏感)
local function isWhitelisted(player)
    if not player then return false end
    local name = string.lower(player.Name)
    local disp = string.lower(player.DisplayName or "")
    for _, n in ipairs(CONFIG.Whitelist or {}) do
        local ln = string.lower(n)
        if ln == name or (disp ~= "" and ln == disp) then
            return true
        end
    end
    return false
end

--- ★在当前服务器里按关键词找人 (前缀匹配优先, 再退化到包含匹配)
--- @param kw string 输入的关键词
--- @return table 匹配到的玩家列表
local function searchServerPlayers(kw)
    if type(kw) ~= "string" then return {} end
    kw = string.lower(string.gsub(kw, "^%s*(.-)%s*$", "%1"))
    if kw == "" then return {} end

    local prefix, contain = {}, {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local n = string.lower(plr.Name)
            local d = string.lower(plr.DisplayName or "")
            if string.sub(n, 1, #kw) == kw or string.sub(d, 1, #kw) == kw then
                table.insert(prefix, plr)
            elseif string.find(n, kw, 1, true) or string.find(d, kw, 1, true) then
                table.insert(contain, plr)
            end
        end
    end

    local out = {}
    for _, p in ipairs(prefix) do table.insert(out, p) end
    for _, p in ipairs(contain) do table.insert(out, p) end
    return out
end

--- ★校验一个名字是否真的是本服务器里的玩家
--- 返回: ok(boolean), realName(string|nil), reason(string)
--- 支持三种匹配: 精确用户名 / 精确显示名 / 唯一前缀
local function validateServerPlayer(input)
    if type(input) ~= "string" then return false, nil, "输入无效" end
    local kw = string.gsub(input, "^%s*(.-)%s*$", "%1")
    if kw == "" then return false, nil, "不能为空" end

    local klow = string.lower(kw)

    -- 1) 精确匹配用户名
    for _, plr in ipairs(Players:GetPlayers()) do
        if string.lower(plr.Name) == klow then
            if plr == LocalPlayer then return false, nil, "不能加自己" end
            return true, plr.Name, ""
        end
    end
    -- 2) 精确匹配显示名
    for _, plr in ipairs(Players:GetPlayers()) do
        if (plr.DisplayName or "") ~= "" and string.lower(plr.DisplayName) == klow then
            if plr == LocalPlayer then return false, nil, "不能加自己" end
            return true, plr.Name, ""
        end
    end
    -- 3) 前缀匹配: 唯一才接受, 多个就让人挑
    local hits = searchServerPlayers(kw)
    if #hits == 1 then
        return true, hits[1].Name, ""
    elseif #hits > 1 then
        return false, nil, string.format("有 %d 个人匹配, 请输入更完整名字", #hits)
    end
    return false, nil, "本服务器里没有这个人"
end

--- ★添加白名单 (会校验是不是本服玩家)
--- @param rawName string 用户输入
--- @return boolean ok, string message
local function addWhitelist(rawName)
    local ok, realName, reason = validateServerPlayer(rawName)
    if not ok then
        return false, reason
    end

    local low = string.lower(realName)
    for _, n in ipairs(CONFIG.Whitelist or {}) do
        if string.lower(n) == low then
            return false, realName .. " 已在白名单里"
        end
    end

    table.insert(CONFIG.Whitelist, realName)
    saveConfig()
    return true, "已保护 " .. realName
end

--- 移除白名单 (按下标)
local function removeWhitelist(index)
    if not CONFIG.Whitelist[index] then return false end
    table.remove(CONFIG.Whitelist, index)
    saveConfig()
    return true
end

--//===================== ★好友列表 =====================

--- 加载好友列表 (异步)
--- 使用 LocalPlayer:GetFriendsAsync() 拉取
local function loadFriends()
    STATE.friendSet = {}
    STATE.friendLoaded = false

    task.spawn(function()
        local ok, pages = pcall(function()
            return Players:GetFriendsAsync(LocalPlayer.UserId)
        end)

        if not ok or not pages then
            -- 备用方案: 尝试用 GetFriendsAsync 的另一种调用
            ok, pages = pcall(function()
                return game.Players:GetFriendsAsync(LocalPlayer.UserId)
            end)
        end

        if not ok or not pages then
            notify("好友列表", "加载失败, 将不保护好友", 4, "error")
            STATE.friendLoaded = true
            return
        end

        local count = 0
        while true do
            local items = pages:GetCurrentPage()
            for _, item in ipairs(items) do
                -- ★注意: 这里同时写入 Username 和 DisplayName 两个 key 用于匹配,
                -- 但 count 只对"一个人"加一次, 否则 1 个好友会被数成 2 个。
                if item.Username then
                    STATE.friendSet[string.lower(item.Username)] = true
                    count = count + 1
                end
                if item.DisplayName then
                    STATE.friendSet[string.lower(item.DisplayName)] = true
                end
            end

            if pages.IsFinished then break end

            local advOk = pcall(function() pages:AdvanceToNextPageAsync() end)
            if not advOk then break end
        end

        STATE.friendCount = count          -- ★真实好友人数 (1 人 = 1)
        STATE.friendLoaded = true
        notify("好友列表", string.format("已加载 -- %d 人", count), 3, "success")
    end)
end

--- 判断是否为好友
---@param player Instance
---@return boolean
local function isFriend(player)
    if not player then return false end
    if player == LocalPlayer then return true end

    local name = string.lower(player.Name)
    local disp = string.lower(player.DisplayName or "")

    if STATE.friendSet[name] or (disp ~= "" and STATE.friendSet[disp]) then
        return true
    end

    -- 未加载完时, 保守起见: 如果是好友关系可以额外用 IsFriendsWith 检查
    if not STATE.friendLoaded then
        local ok, res = pcall(function()
            return LocalPlayer:IsFriendsWith(player.UserId)
        end)
        if ok and res then
            return true
        end
    end

    return false
end

--- 判断是否可以动手 (不是好友、不在白名单才可以)
local function canTarget(player)
    if not player or player == LocalPlayer then return false end
    if CONFIG.AntiKick_ProtectFriend and isFriend(player) then
        return false
    end
    -- ★白名单: 无论如何都保护
    if isWhitelisted(player) then
        return false
    end
    return true
end

--- 获取可动手的目标列表
---@param requireAlive boolean
local function getTargets(requireAlive)
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if canTarget(plr) then
            if requireAlive then
                local char = plr.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    table.insert(list, plr)
                end
            else
                table.insert(list, plr)
            end
        end
    end
    return list
end

--//===================== 投票踢人 (真实接口) =====================
-- 以下是抓包确认真实的接口:
--   RemoteFunction: ReplicatedStorage.Requests.RequestVoteKick
--                   调用: Event:InvokeServer("玩家名")
--   RemoteEvent   : ReplicatedStorage.SelectiveReplication.VoteKick
--                   结构: ("Call", 发起者, 目标, 票数, 阈值)

local VOTEKICK_CONFIG = {
    InvokePath  = {"Requests", "RequestVoteKick"},           -- RemoteFunction
    SignalPath  = {"SelectiveReplication", "VoteKick"},      -- RemoteEvent
}

--- 定位投票 RemoteFunction
local function getVoteFunc()
    local ok, svc = pcall(function()
        return game:GetService("ReplicatedStorage")
    end)
    if not ok or not svc then return nil end

    local cur = svc
    for _, seg in ipairs(VOTEKICK_CONFIG.InvokePath) do
        cur = cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end

--- 定位投票 RemoteEvent
local function getVoteEvent()
    local ok, svc = pcall(function()
        return game:GetService("ReplicatedStorage")
    end)
    if not ok or not svc then return nil end

    local cur = svc
    for _, seg in ipairs(VOTEKICK_CONFIG.SignalPath) do
        cur = cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end

--//===================== ★ 投票结果判定 / 冷却 =====================
--
-- 【为什么需要这一套】
-- Roblox 的投票踢人对"同一个人"有服务端冷却: 冷却期内再发起, 服务端直接丢弃,
-- 不会真的投票。但 InvokeServer 只要网络没报错就 pcall 成功 —— 以前脚本把这个
-- 当成"投票成功", 于是冷却中还在弹字、还在循环播音效, 实际一次都没投出去。
--
-- 现在: 先本地预检冷却 → 再解析服务端返回值 → 只有确认受理才报成功。

--- 本地冷却表: [名字小写] = 上次成功投票的时间
STATE.voteCooldown = STATE.voteCooldown or {}
--- 服务端广播里已知的票数: [名字小写] = {votes, threshold}
STATE.voteBoard = STATE.voteBoard or {}
--- 通过 RemoteEvent 发出、等待广播回执的投票
STATE.pendingVote = nil

--- 本地冷却时长 (与服务端大致对齐, 略短一点避免误杀)
local VOTE_COOLDOWN = 30

--- 现在能不能对这个人发起投票?
---@return boolean ok, string reason
local function canVoteNow(target)
    if not target then return false, "目标无效" end
    local key = string.lower(target.Name)

    -- 1) 本地冷却
    local last = STATE.voteCooldown[key]
    if last then
        local left = VOTE_COOLDOWN - (os.clock() - last)
        if left > 0 then
            return false, string.format("冷却中 (还需 %.0f 秒)", left)
        end
    end

    -- 2) 广播已知票数已到阈值 → 他马上被踢, 再投是浪费
    local board = STATE.voteBoard[key]
    if board and board.threshold and board.threshold > 0
       and board.votes and board.votes >= board.threshold then
        return false, "票数已满, 正在踢出"
    end

    return true, ""
end

--- 记录一次成功投票 (写冷却 + 清待确认)
local function recordVote(target)
    if not target then return end
    STATE.voteCooldown[string.lower(target.Name)] = os.clock()
    STATE.pendingVote = nil
end

--- 解析 RemoteFunction 的返回值, 判断服务端是否真的受理了
--- 兼容多种返回形态: 布尔 / 字符串状态 / 表 / nil
---@return boolean accepted, string reason
local function interpretVoteResult(res, target)
    -- 没有返回值: 无法判断, 保守当作受理 (多数游戏的 RequestVoteKick 不返回)
    if res == nil then return true, "" end

    -- 布尔
    if type(res) == "boolean" then
        return res, res and "" or "服务端拒绝"
    end

    -- 字符串 / 数字: 当作状态码或错误信息
    if type(res) == "string" then
        local low = string.lower(res)
        local bad = string.find(low, "cooldown", 1, true)
                 or string.find(low, "cool", 1, true)
                 or string.find(low, "冷却", 1, true)
                 or string.find(low, "wait", 1, true)
                 or string.find(low, "fail", 1, true)
                 or string.find(low, "error", 1, true)
                 or string.find(low, "denied", 1, true)
                 or string.find(low, "invalid", 1, true)
                 or string.find(low, "already", 1, true)
                 or string.find(low, "不能", 1, true)
                 or string.find(low, "失败", 1, true)
        if bad then return false, res end
        -- 空串或 affirm 类词 → 受理
        if res == "" or low == "ok" or low == "success" or low == "true" then
            return true, ""
        end
        return true, ""   -- 其他未知字符串, 当作受理
    end

    -- 表: 找 success / ok / accepted / error 字段
    if type(res) == "table" then
        if res.success ~= nil then return res.success == true, tostring(res.message or res.error or "") end
        if res.ok ~= nil then return res.ok == true, tostring(res.error or "") end
        if res.accepted ~= nil then return res.accepted == true, tostring(res.reason or "") end
        if res.error ~= nil then return false, tostring(res.error) end
        -- 空表或结构未知 → 受理
        return true, ""
    end

    return true, ""
end

--- 对指定玩家发起投票踢出
---@param target Instance
---@return boolean 真正被服务端接受才返回 true
local function voteKick(target)
    if not target or target == LocalPlayer then return false end

    -- ★好友保护: 二次确认
    if CONFIG.AntiKick_ProtectFriend and isFriend(target) then
        notify("踢人被阻止", target.Name .. " 是你的好友", 3, "warn")
        return false
    end

    -- ★白名单: 二次确认
    if isWhitelisted(target) then
        notify("踢人被阻止", target.Name .. " 在白名单里", 3, "warn")
        return false
    end

    -- ★本地冷却预检: 服务端对同一目标有投票冷却, 冷却期内发起必被丢弃。
    -- 以前不做这个检查, 所以冷却中还会弹"已投票成功"并循环播音效。
    local ok, reason = canVoteNow(target)
    if not ok then
        return false, reason
    end

    -- 主接口: RemoteFunction 传玩家名
    -- ★关键: 以前只看 pcall 有没有报错, 服务端返回"冷却中/已被踢"也被当成成功。
    -- 现在解析返回值, 只有服务端明确接受才算成功。
    local voteFunc = getVoteFunc()
    if voteFunc and voteFunc:IsA("RemoteFunction") then
        local callOk, res = pcall(function()
            return voteFunc:InvokeServer(target.Name)
        end)
        if callOk then
            local accepted, why = interpretVoteResult(res, target)
            if accepted then
                notifyKickDone(target.Name)     -- 屏幕上方小字 + 提示音
                recordVote(target)              -- ★记冷却 + 记已投
                return true
            else
                -- 服务端拒绝了 —— 不再报成功, 也不播音效, 更不弹通知 (用户要求: 投票未通过不要提醒)
                return false, why
            end
        end
    end

    -- 备用接口: RemoteEvent 没有返回值, 只能靠广播回执判定。
    -- 发出去先记"待确认", 若 1.5 秒内没收到自己的 Call 广播就当作失败。
    local voteEvent = getVoteEvent()
    if voteEvent and voteEvent:IsA("RemoteEvent") then
        local sendOk = pcall(function()
            voteEvent:FireServer(target.Name)
        end)
        if sendOk then
            STATE.pendingVote = { name = target.Name, at = os.clock() }
            -- 等广播确认 (confirmVoteBroadcast 在收到 Call 时会清掉 pending)
            local waited = 0
            while waited < 1.5 do
                task.wait(0.1)
                waited = waited + 0.1
                if not STATE.pendingVote then
                    notifyKickDone(target.Name)
                    recordVote(target)
                    return true
                end
            end
            -- 超时没确认 → 当作被服务端丢弃 (不再弹通知, 避免冷却期反复刷屏)
            STATE.pendingVote = nil
            return false, "no-confirm"
        end
    end

    notify("投票接口异常", "未找到投票接口, 请确认游戏版本", 4, "error")
    return false, "no-interface"
end

--- 读取当前投票状态 (用于显示)
---@return table|nil
local function getVoteStatus()
    local voteEvent = getVoteEvent()
    if not voteEvent then return nil end

    local status = {active = false, target = nil, votes = 0, need = 0}

    local conn
    conn = voteEvent.OnClientEvent:Connect(function(action, initiator, target, votes, threshold)
        if action == "Call" or action == "Start" then
            status.active   = true
            status.target   = target and target.Name or nil
            status.votes    = votes or 0
            status.need     = threshold or 0
        elseif action == "End" or action == "Cancel" then
            status.active = false
        end
    end)

    return status, conn
end

--//===================== 传送 =====================

--- 落点安全检测
local function isSafeLanding(pos)
    if not CONFIG.Teleport_SafeCheck then return true, "" end

    local char = LocalPlayer.Character
    if not char then return false, "角色不存在" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "缺少 HumanoidRootPart" end

    local dist = (pos - hrp.Position).Magnitude
    if dist > CONFIG.Teleport_MaxDistance then
        return false, string.format("距离过远(%.0f)", dist)
    end

    if pos.Y < CONFIG.Teleport_SafeY then
        return false, "目标在安全高度以下"
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {char}

    local rayResult = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
    if not rayResult then
        return false, "目标点下方没有地面"
    end

    return true, ""
end

--- 执行传送
local function doTeleport(pos, silent)
    local char = LocalPlayer.Character
    if not char then
        if not silent then notify("传送失败", "角色不存在", 3, "error") end
        return false
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if not silent then notify("传送失败", "缺少 HumanoidRootPart", 3, "error") end
        return false
    end

    local safe, reason = isSafeLanding(pos)
    if not safe then
        if not silent then notify("传送被阻止", reason, 3, "warn") end
        return false
    end

    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    return true
end

--- 传送到指定玩家 (普通模式, 传一次)
local function teleportToPlayer(target, silent)
    if not target or target == LocalPlayer then return end

    local char = target.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        if not silent then notify("传送失败", target.Name .. " 不在场", 3, "warn") end
        return
    end

    if doTeleport(hrp.Position, silent) and not silent then
        notify("传送成功", "已传送 -- " .. target.Name, 2, "success")
    end
end

--//===================== ★ 背后跟随 (核心新功能) =====================

--- 计算"目标背后"的位置
--- @param targetHRP BasePart 目标的 HumanoidRootPart
--- @param distance number 背后距离 (studs)
--- @param height number 抬高高度 (studs)
--- @return Vector3 背后位置
local function getBehindPosition(targetHRP, distance, height)
    -- LookVector 是目标"面朝"的方向
    -- 取负号 → 背后方向
    -- 再乘以距离 → 背后多少 studs
    local look = targetHRP.CFrame.LookVector
    local behind = targetHRP.Position - look * distance
    return behind + Vector3.new(0, height, 0)
end

--- 计算贴背时应该面朝的角度 (让自己看向目标, 而不是背对)
--- @param targetHRP BasePart
--- @return CFrame
local function getBehindCFrame(targetHRP, distance, height)
    local look = targetHRP.CFrame.LookVector
    local behind = targetHRP.Position - look * distance + Vector3.new(0, height, 0)
    -- 让自己面朝目标 (看着他的后背)
    return CFrame.new(behind, targetHRP.Position)
end

--- 启动背后跟随
--- @param target Instance 锁定的目标
--- @param manual boolean 是否手动锁定(手动锁定的不自动换人)
local startBehindFollow

--- ★自动换人: 当前目标死了/没了, 随机(或按模式)换下一个
--- @param deadName string|nil 刚死掉的目标名, 用于排除
--- @return boolean 是否成功换人
local function autoSwitchTarget(deadName)
    if STATE.switching then return false end
    STATE.switching = true

    local nextTarget = pickNextFollowTarget(deadName)

    if not nextTarget then
        STATE.switching = false
        notify("跟随失败", "场上没有可用目标了", 3, "warn")
        return false
    end

    -- ★防规律: 随机延迟一点再切, 避免"敌人一死我立刻贴下一个"的死板节奏
    local jitter = 0
    if CONFIG.Follow_SwitchMode ~= "nearest" then
        jitter = math.random() * (CONFIG.Follow_SwitchJitter or 0)
    end
    if jitter > 0 then task.wait(jitter) end

    -- 重新校验一次 (等待期间目标可能也死了)
    if not nextTarget.Parent or not nextTarget.Character then
        STATE.switching = false
        return false
    end

    STATE.switching = false
    startBehindFollow(nextTarget, false)
    -- ★通知: 目标阵亡自动换人
    notify("自动换人", string.format("%s 已阵亡, 接手 -- %s",
        tostring(deadName or "目标"), nextTarget.Name), 3, "warn")
    return true
end

--- ★跟随失败保护
--- 判断"我是否真的贴上了"; 连续失败超过阈值就自动重贴
--- @param t Instance 目标玩家
--- @param tHRP BasePart 目标的 HumanoidRootPart
--- @param myHRP BasePart 我的 HumanoidRootPart
local function checkFollowFailure(t, tHRP, myHRP)
    if not CONFIG.Follow_FailGuard then return end

    local now = tick()
    local distToTarget = (myHRP.Position - tHRP.Position).Magnitude

    -- 判定标准: 离目标太远 = 没贴上 (被拉回 / 卡住 / 掉地图)
    local failed = distToTarget > CONFIG.Follow_FailDist

    -- 掉出地图也算失败
    if not failed and myHRP.Position.Y < CONFIG.Teleport_SafeY then
        failed = true
    end

    if not failed then
        -- 状态正常, 清空失败计时
        STATE.failSince = nil
        return
    end

    -- 记录第一次失败的时间
    if not STATE.failSince then
        STATE.failSince = now
        return
    end

    -- 连续失败超过阈值 → 重贴
    if (now - STATE.failSince) < CONFIG.Follow_FailDelay then return end
    if STATE.retrying then return end

    STATE.retrying  = true
    STATE.failSince = nil

    task.spawn(function()
        task.wait(CONFIG.Follow_RetryWait)

        local cur = STATE.followTarget
        if cur == t then
            -- 直接重新贴过去 (瞬间拉回目标背后)
            local c  = t.Character
            local h  = c and c:FindFirstChild("HumanoidRootPart")
            local mc = LocalPlayer.Character
            local mh = mc and mc:FindFirstChild("HumanoidRootPart")
            if h and mh then
                mh.CFrame = getBehindCFrame(h, CONFIG.Follow_Distance, CONFIG.Follow_Height)
                notify("跟随保护", "贴背失败, 已重新贴回 -- " .. t.Name, 2.5, "warn")
            end
        end

        STATE.retrying = false
    end)
end

local function startBehindFollow(target, manual)
    if not target or target == LocalPlayer then return end

    -- 好友保护: 不允许贴好友
    if CONFIG.AntiKick_ProtectFriend and isFriend(target) then
        notify("跟随即停", target.Name .. " 是好友, 已拒绝", 3, "warn")
        return
    end

    -- ★白名单: 不允许贴
    if isWhitelisted(target) then
        notify("跟随即停", target.Name .. " 在白名单里, 已拒绝", 3, "warn")
        return
    end

    -- 停掉旧的跟随
    if STATE.followConn then
        pcall(function() STATE.followConn:Disconnect() end)
        STATE.followConn = nil
    end

    STATE.followTarget = target
    STATE.manualLock   = manual and true or false
    STATE.switching    = false

    local lastUpdate = 0
    STATE.followConn = RunService.RenderStepped:Connect(function()
        -- 目标有效性检查
        local t = STATE.followTarget
        if not t or not t.Parent then
            -- ★自动找下一个 (若开启了换人)
            if CONFIG.Follow_KeepOnDeath and not STATE.manualLock then
                if autoSwitchTarget(nil) then return end
            end
            if STATE.followConn then STATE.followConn:Disconnect() end
            STATE.followConn = nil
            STATE.followTarget = nil
            notify("跟随停止", "目标已离开", 3, "warn")
            return
        end

        -- 节流: 按设定的频率更新 (默认每帧, 可调)
        local now = tick()
        if now - lastUpdate < CONFIG.Follow_Interval then return end
        lastUpdate = now

        -- 获取目标位置
        local tChar = t.Character
        local tHRP  = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end

        -- ★死了 → 自动换人
        local tHum = tChar:FindFirstChildOfClass("Humanoid")
        if tHum and tHum.Health <= 0 then
            if CONFIG.Follow_KeepOnDeath and not STATE.manualLock then
                if autoSwitchTarget(t.Name) then return end
            end
            if not CONFIG.Follow_KeepOnDeath then
                if STATE.followConn then STATE.followConn:Disconnect() end
                STATE.followConn = nil
                STATE.followTarget = nil
                return
            end
        end

        -- 获取自己的角色
        local myChar = LocalPlayer.Character
        local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end

        -- 算背后位置
        local behindPos = getBehindPosition(tHRP, CONFIG.Follow_Distance, CONFIG.Follow_Height)

        -- 安全检查 (可关)
        if CONFIG.Follow_SafeCheck then
            local dist = (behindPos - myHRP.Position).Magnitude
            if dist > CONFIG.Teleport_MaxDistance then return end
            if behindPos.Y < CONFIG.Teleport_SafeY then return end
        end

        -- ★跟随失败保护: 检查我是否真的贴在目标背后
        if CONFIG.Follow_FailGuard then
            checkFollowFailure(t, tHRP, myHRP)
        end

        -- 贴过去 (用 CFrame 让它面朝目标, 避免背对)
        myHRP.CFrame = getBehindCFrame(tHRP, CONFIG.Follow_Distance, CONFIG.Follow_Height)
    end)

    notify("开始跟随", string.format("%s -- 距离 %.0f studs", target.Name, CONFIG.Follow_Distance), 3, "info")
end

--- 停止背后跟随
local function stopBehindFollow()
    if STATE.followConn then
        pcall(function() STATE.followConn:Disconnect() end)
        STATE.followConn = nil
    end
    STATE.followTarget = nil
end

--//===================== ★ 投票状态监听 (情报收集) =====================
-- 服务端会推送: ("Call", 发起者, 目标, 当前票数, 阈值)
-- 用它来判断: 谁已经在被投了 / 谁快被投出去了 / 谁刚被踢走

local voteListenerConn = nil

local function startVoteListener()
    if voteListenerConn then return end

    local voteEvent = getVoteEvent()
    if not voteEvent or not voteEvent:IsA("RemoteEvent") then
        -- 接口还没就绪, 稍后重试
        task.delay(2, function()
            if not voteListenerConn then startVoteListener() end
        end)
        return
    end

    voteListenerConn = voteEvent.OnClientEvent:Connect(function(action, initiator, target, votes, threshold)
        if not action then return end

        if action == "Call" or action == "Start" then
            if not target then return end
            local name = target.Name
            STATE.voteStatus[name] = {votes = votes or 0, need = threshold or 0}
            -- ★同步到投票看板, 供 canVoteNow 判断"票是否已满"
            STATE.voteBoard[string.lower(name)] = {votes = votes or 0, threshold = threshold or 0}

            -- ★如果这是我刚发出的、还在等回执的投票 → 广播到了 = 服务端确认受理
            if STATE.pendingVote
               and string.lower(STATE.pendingVote.name) == string.lower(name) then
                STATE.pendingVote = nil
            end

            -- ★被投的是我自己 → 屏幕上方警告 (不挡视野)
            if target == LocalPlayer then
                local initName = initiator and initiator.Name or "有人"
                showVoteWarning(initName, votes, threshold)
            end

            -- 票数已经到阈值了 → 这人马上就走, 别浪费票
            if threshold and votes and votes >= threshold then
                STATE.kickExclude[name] = tick() + 9999  -- 临时排除(他会被踢走), 避免白投票
            end

        elseif action == "End" or action == "Cancel" or action == "Finish" then
            local n = target and target.Name or nil
            if n then
                STATE.voteStatus[n] = nil
                STATE.voteBoard[string.lower(n)] = nil
                -- 投票结束了但人还在 → 解除永久排除, 但给个短冷却避免立刻又被选中
                if STATE.kickExclude[n] and STATE.kickExclude[n] > tick() + 9000 then
                    STATE.kickExclude[n] = tick() + 8   -- ★固定 8 秒 (不再用已删除的去重冷却配置)
                end
            end
        end
    end)
end

--//===================== ★ 自动踢人目标选择 =====================
--   去重交给服务端投票冷却 (STATE.voteCooldown): 同一目标冷却期内投票会被服务端丢弃,
--   这里挑目标时优先避开仍在服务端冷却里的人, 既避免白投, 又保留"循环换人"的效果。

--- 从候选列表里随机挑一个目标
--- 优先挑不在服务端投票冷却里的人; 全在冷却就退化为全量随机
--- @param requireAlive boolean
--- @return Instance|nil
local function pickKickTarget(requireAlive)
    local all = getTargets(requireAlive)
    if #all == 0 then return nil end

    local fresh = {}
    for _, plr in ipairs(all) do
        local key = string.lower(plr.Name)
        if not (STATE.voteCooldown and STATE.voteCooldown[key])
           and not (STATE.kickExclude and STATE.kickExclude[key]) then
            table.insert(fresh, plr)
        end
    end

    local pool = (#fresh > 0) and fresh or all
    return pool[math.random(1, #pool)]
end

--//===================== ★ 自动换人 (目标死亡/失效) =====================

--- 按设定模式挑下一个目标
--- @param excludeName string|nil 排除的人(通常是刚死的那个, 避免又选到同一个)
--- @return Instance|nil
local function pickNextFollowTarget(excludeName)
    local all = getTargets(true)   -- 只要活人
    if #all == 0 then return nil end

    -- 把刚死的那个剔除
    local pool = {}
    for _, plr in ipairs(all) do
        if plr.Name ~= excludeName then
            table.insert(pool, plr)
        end
    end
    if #pool == 0 then pool = all end   -- 只有他一个活的, 那就还得是他

    local mode = CONFIG.Follow_SwitchMode or "nearest"

    if mode == "nearest" then
        -- 距离最近
        local myChar = LocalPlayer.Character
        local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHRP then
            return pool[math.random(1, #pool)]
        end

        local best, bestDist = nil, math.huge
        for _, plr in ipairs(pool) do
            local c = plr.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h then
                local d = (h.Position - myHRP.Position).Magnitude
                if d < bestDist then best, bestDist = plr, d end
            end
        end
        return best or pool[math.random(1, #pool)]
    else
        -- ★随机 (默认): 不找最近的, 防止被对面摸出规律
        return pool[math.random(1, #pool)]
    end
end

--//===================== ★ 自动循环踢人 =====================

--- 启动自动踢人循环
--- 去重交给服务端投票冷却 + 临时排除表 (kickExclude), 命中冷却/即将离开的人自动跳过
local function startAutoKick()
    if STATE.autoKickLoop then return end

    STATE.autoKickLoop = task.spawn(function()
        while CONFIG.AntiKick_AutoKick do
            if CONFIG.AntiKick_Enabled then
                local t = pickKickTarget(false)
                if t then
                    voteKick(t)   -- 受理与否由服务端冷却决定, 命中冷却会自动丢弃
                end
            end
            task.wait(CONFIG.AntiKick_KickInterval)
        end
        STATE.autoKickLoop = nil
    end)
end

--- 停止自动踢人循环
local function stopAutoKick()
    CONFIG.AntiKick_AutoKick = false
    -- 线程靠 while 条件自然退出
end

--- 启动自动循环传送 (改为: 自动锁定随机敌人并持续贴背)
local function startTeleportLoop()
    if STATE.teleportLoop then return end

    STATE.teleportLoop = task.spawn(function()
        while CONFIG.Teleport_Enabled do
            local targets = getTargets(true)
            if #targets > 0 then
                local t = targets[math.random(1, #targets)]
                -- 持续贴背跟随 (始终开启, 不可关闭)
                -- 已经跟着活人就不打断, 等目标死了由 autoSwitchTarget 自动换
                if STATE.followTarget and STATE.followTarget.Parent then
                    -- 检查当前目标是否还活着, 活着就不换
                    local c = STATE.followTarget.Character
                    local h = c and c:FindFirstChildOfClass("Humanoid")
                    if h and h.Health > 0 then
                        -- 保持当前目标, 什么都不做
                    else
                        startBehindFollow(t)
                    end
                else
                    startBehindFollow(t)
                end
            end
            task.wait(CONFIG.Teleport_Interval)
        end
        STATE.teleportLoop = nil
    end)
end

--- 停止循环
local function stopTeleportLoop()
    CONFIG.Teleport_Enabled = false
    -- 线程靠 while 条件自然退出
end


local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiKickTeleportUI_v2"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not screenGui.Parent then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local panelH = IS_MOBILE and 420 or 340   -- ★面板高度 (移动端更高)
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, UI_METRICS.panelW, 0, panelH)
main.Position = UDim2.new(0, 20, 0, 80)
main.BackgroundColor3 = THEME.bg
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.ClipsDescendants = true   -- ★裁剪子级到圆角内: 顶栏渐变条不再戳出圆角外
main.Parent = screenGui

-- ★面板缩放: 用 UIScale 整体等比缩放, 内部所有控件(含文字/滑块/间距)一起变,
-- 不再像以前那样「只有容器变大、内容不变、底下留一大块空白」。
local panelScale = Instance.new("UIScale")
panelScale.Name = "PanelScale"
panelScale.Scale = CONFIG.UI_Scale or 1.0
panelScale.Parent = main

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)   -- ★WindUI 风: 中等圆角, 不夸张
mainCorner.Parent = main

-- ★面板描边: 保持 WindUI 的「极细中性线」, 只把色相调紫一点呼应三色主题
-- (UIStroke 不支持 UIGradient, 所以这里不做渐变描边, 避免又回到"套一层 Frame"的旧写法)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = THEME.stroke
mainStroke.Thickness = 1
mainStroke.Transparency = 0.25
mainStroke.Parent = main

-- ★外框: 渐变边框效果 (UIStroke 不支持 UIGradient, 所以用"外层渐变 Frame 垫底 + main 内缩"做出一圈渐变描边)
--   frameOuter 比 main 大 6px (每边 3px) 且叠在 main 后面, main 盖住中间, 露出一圈紫→靛→青渐变环
local frameOuter = Instance.new("Frame")
frameOuter.Name = "FrameOuter"
frameOuter.Size = UDim2.new(0, UI_METRICS.panelW + 6, 0, panelH + 6)
frameOuter.Position = UDim2.new(0, 17, 0, 77)   -- 比 main(20,80) 各内缩 3px
frameOuter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)   -- 刷白给渐变垫底
frameOuter.BorderSizePixel = 0
frameOuter.ZIndex = 0   -- ★垫在 main(ZIndex 默认 1) 后面
frameOuter.Parent = screenGui
STATE.frameOuter = frameOuter   -- ★供设置页"外框透明度"滑块直接改透明度
local foCorner = Instance.new("UICorner")
foCorner.CornerRadius = UDim.new(0, 15)
foCorner.Parent = frameOuter
applyGradient(frameOuter, GRAD.purpleCyan, 0)   -- 0° = 左 → 右

-- ★让渐变外框永远跟着主面板: 主面板可拖拽、又带 UIScale 缩放,
--   写死坐标的 frameOuter 会"掉队"。改用 AbsolutePosition/AbsoluteSize 实时同步,
--   无论拖到哪、缩放到多大, 外框都严丝合缝裹住主面板。
local function syncFrameOuter()
    if not main.Visible then return end   -- 收起/隐藏期间不更新, 避免跳到 (0,0)
    frameOuter.Position = UDim2.new(0, main.AbsolutePosition.X - 3, 0, main.AbsolutePosition.Y - 3)
    frameOuter.Size     = UDim2.new(0, main.AbsoluteSize.X + 6, 0, main.AbsoluteSize.Y + 6)
end
main:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncFrameOuter)
main:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncFrameOuter)
syncFrameOuter()

-- (已移除顶部渐变条: 用户要求删除)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, UI_METRICS.headerH)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "EGG"
title.TextColor3 = THEME.text
title.TextSize = UI_METRICS.titleSize
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

-- ★[—] 收进悬浮球 (用 "―" 不够稳, 直接画一条实心横杠, 任何字体都能显示)
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, IS_MOBILE and 32 or 24, 0, IS_MOBILE and 32 or 24)
minBtn.Position = UDim2.new(1, IS_MOBILE and -78 or -60, 0, IS_MOBILE and 6 or 9)
minBtn.BackgroundColor3 = THEME.panel
minBtn.Text = ""
minBtn.BorderSizePixel = 0
minBtn.AutoButtonColor = false
minBtn.Parent = main
local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 8)
minCorner.Parent = minBtn

-- 横杠用 Frame 画, 不用字符 —— 保证任何字体/语言下都能正确显示
local minBar = Instance.new("Frame")
minBar.Size = UDim2.new(0, 11, 0, 2)
minBar.Position = UDim2.new(0.5, -5.5, 0.5, -1)
minBar.BackgroundColor3 = THEME.subtext
minBar.BorderSizePixel = 0
minBar.Parent = minBtn

-- ★[✕] 彻底销毁 UI (同样用 Frame 画叉, 避免 "✕" 在游戏字体里变方框)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, IS_MOBILE and 32 or 24, 0, IS_MOBILE and 32 or 24)
closeBtn.Position = UDim2.new(1, IS_MOBILE and -42 or -32, 0, IS_MOBILE and 6 or 9)
closeBtn.BackgroundColor3 = Color3.fromRGB(48, 26, 26)
closeBtn.Text = ""
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Parent = main
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeBtn

-- 两条 45° 旋转的横杠拼成一个叉
local closeSlash1 = Instance.new("Frame")
closeSlash1.Size = UDim2.new(0, 11, 0, 2)
closeSlash1.AnchorPoint = Vector2.new(0.5, 0.5)
closeSlash1.Position = UDim2.new(0.5, 0, 0.5, 0)
closeSlash1.Rotation = 45
closeSlash1.BackgroundColor3 = THEME.danger
closeSlash1.BorderSizePixel = 0
closeSlash1.Parent = closeBtn

local closeSlash2 = Instance.new("Frame")
closeSlash2.Size = UDim2.new(0, 11, 0, 2)
closeSlash2.AnchorPoint = Vector2.new(0.5, 0.5)
closeSlash2.Position = UDim2.new(0.5, 0, 0.5, 0)
closeSlash2.Rotation = -45
closeSlash2.BackgroundColor3 = THEME.danger
closeSlash2.BorderSizePixel = 0
closeSlash2.Parent = closeBtn

-- 好友状态条 (★放到面板最底部)
local friendBar = Instance.new("TextLabel")
friendBar.Size = UDim2.new(1, -20, 0, IS_MOBILE and 30 or 24)
friendBar.Position = UDim2.new(0, 10, 1, IS_MOBILE and -38 or -32)
friendBar.BackgroundColor3 = THEME.panel
friendBar.BorderSizePixel = 0
friendBar.Text = "好友列表: 加载中..."
friendBar.TextColor3 = THEME.friend
friendBar.TextSize = IS_MOBILE and 13 or 11
friendBar.Font = Enum.Font.Gotham
friendBar.ZIndex = 3
friendBar.Parent = main
local fbCorner = Instance.new("UICorner")
fbCorner.CornerRadius = UDim.new(0, 5)
fbCorner.Parent = friendBar

-- ★面板高度自适应: 每次切页后按实际内容高度收缩面板, 消除底部空白
-- 头部(headH) + 内容高 + 底部好友条 + 底部留白
--
-- 【重要】这里全部用「未缩放的自然尺寸」计算, 缩放交给挂在 main 上的 UIScale 实例。
-- 之前是 main.Size 乘 sc、但 header/footer/内容都是固定像素, 结果调大面板时
-- 只有容器变大、内容不变, 空出来的地方就是「越调越大」的空白。
local function fitPanelToContent()
    if not (scroll and main) then return end
    task.defer(function()
        local layout = scroll:FindFirstChildOfClass("UIListLayout")
        local contentH = layout and layout.AbsoluteContentSize.Y or scroll.AbsoluteCanvasSize.Y
        if not contentH or contentH <= 0 then return end

        local headH = IS_MOBILE and 98 or 78   -- 标题 + 标签栏
        local footH = IS_MOBILE and 52 or 42   -- 好友条 + 下边距
        local maxH  = IS_MOBILE and 560 or 460 -- 自然尺寸上限, 超出则内部滚动

        local targetH = headH + contentH + footH
        if targetH > maxH then targetH = maxH end

        -- 只在自然尺寸上有变化时才改 (UIScale 会负责视觉缩放)
        if math.abs(main.Size.Y.Offset - targetH) > 2 then
            main.Size  = UDim2.new(0, UI_METRICS.panelW, 0, targetH)
            scroll.Size = UDim2.new(1, -20, 0, targetH - headH - footH)
        end
    end)
end

--- ★应用面板缩放 (整体等比缩放, 内容跟着一起变, 不留空白)
---@param sc number
local function applyPanelScale(sc)
    sc = math.clamp(sc or 1.0, 0.7, 1.4)
    if panelScale then
        panelScale.Scale = sc
    end
    -- 悬浮球也一起缩放, 保持视觉一致
    if STATE.ballScale then
        STATE.ballScale.Scale = sc
    end
    -- ★渐变外框跟着面板缩放一起变大小 (panelScale 改变 main 的 AbsoluteSize, 这里主动同步一次, 更稳)
    if syncFrameOuter then syncFrameOuter() end
end

-- ★标签栏 (战斗 / 玩家 / 设置)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -20, 0, UI_METRICS.tabH)
tabBar.Position = UDim2.new(0, 10, 0, IS_MOBILE and 54 or 42)
tabBar.BackgroundTransparency = 1
tabBar.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local tabButtons = {}

--- 创建标签按钮 (★用比例宽度, 3 个标签平分, 不会溢出面板)
--- WindUI 风: 选中态是"实心强调色块", 没有渐变, 也没有底部指示条
local function makeTab(key, text, order)
    local btn = Instance.new("TextButton")
    -- 面板内容宽 = 面板宽 - 20(左右各10), 用 0.32 比例 + 间距补偿
    btn.Size = UDim2.new(0.32, 0, 1, 0)
    btn.BackgroundColor3 = THEME.panel
    btn.Text = text
    btn.TextColor3 = THEME.subtext
    btn.TextSize = IS_MOBILE and 13 or 11
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.Parent = tabBar
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = btn

    -- 选中态由 setActive 直接改 BackgroundColor3 / TextColor3 (WindUI 就是实心填色)
    tabButtons[key] = btn
    return btn
end

local scroll = Instance.new("ScrollingFrame")
-- ★用 1,-N 的相对高度撑满可用空间, 面板多高它就多高, 不会留空白
scroll.Size = UDim2.new(1, -20, 0, IS_MOBILE and 286 or 218)
scroll.Position = UDim2.new(0, 10, 0, IS_MOBILE and 98 or 78)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = main

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, UI_METRICS.spacing)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

-- 控件工厂
-- ★当前活动容器: 标签页切换时改这个, 工厂函数就自动写到对应页
local activeContainer = nil
local function setContainer(c) activeContainer = c end
local function target()
    return activeContainer or scroll
end

local function makeToggle(text, default, callback)
    local holder = Instance.new("TextButton")
    holder.Size = UDim2.new(1, 0, 0, UI_METRICS.rowH)
    holder.BackgroundColor3 = THEME.panel
    holder.Text = ""
    holder.BorderSizePixel = 0
    holder.AutoButtonColor = false
    holder.Parent = target()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = holder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -(UI_METRICS.switchW + 24), 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = THEME.text
    label.TextSize = UI_METRICS.fontSize
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    -- 轨道 (★开启 = 绿青渐变; 关闭 = 中性色。WindUI 的大圆点细节保留)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, UI_METRICS.switchW, 0, UI_METRICS.switchH)
    track.Position = UDim2.new(1, -(UI_METRICS.switchW + 8), 0.5, -UI_METRICS.switchH / 2)
    track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)   -- 刷白给渐变垫底
    track.BorderSizePixel = 0
    track.Parent = holder
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = track

    -- WindUI 的圆点很大, 几乎贴着轨道内壁
    local knSz = UI_METRICS.switchH - 4
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, knSz, 0, knSz)
    knob.Position = UDim2.new(0, 2, 0.5, -knSz / 2)
    knob.BackgroundColor3 = THEME.knob            -- ★纯白
    knob.BorderSizePixel = 0
    knob.Parent = track
    local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob

    local onX = UI_METRICS.switchW - knSz - 2
    local state = default
    local trackTween = nil   -- ★记录轨道底色补间, 快速切换时先取消, 否则渐变会乘到"半途中的深色底"上变墨绿
    local function render()
        if state then
            -- ★开启: 绿青渐变填充 (底色必须纯白, 否则渐变相乘会变暗/变墨绿)
            if trackTween then trackTween:Cancel() end   -- ★取消"关闭"补间(底色正往深色补), 否则渐变乘上去就是墨绿
            track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            local g = track:FindFirstChildOfClass("UIGradient")
            if not g then
                applyGradient(track, GRAD.greenCyan, 0)
            else
                g.Color = GRAD.greenCyan
                g.Enabled = true
            end
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, onX, 0.5, -knSz / 2),
                BackgroundColor3 = THEME.knob}):Play()
        else
            -- ★关闭: 去掉渐变, 回到中性轨道
            local g = track:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
            trackTween = TweenService:Create(track, TweenInfo.new(0.18), {BackgroundColor3 = THEME.track})
            trackTween:Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 2, 0.5, -knSz / 2),
                BackgroundColor3 = Color3.fromRGB(200, 200, 210)}):Play()
        end
    end
    render()

    holder.MouseButton1Click:Connect(function()
        playClickSound()          -- ★点击音效
        state = not state
        render()
        if callback then callback(state) end
    end)

    return holder
end

local function makeButton(text, callback, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, UI_METRICS.rowH)
    btn.BackgroundColor3 = THEME.panel
    btn.Text = text
    btn.TextColor3 = color or THEME.text
    btn.TextSize = UI_METRICS.fontSize
    btn.Font = Enum.Font.Gotham    -- (GothamMedium 不是合法枚举, 用 Gotham)
    btn.BorderSizePixel = 0
    btn.Parent = target()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = btn

    -- ★悬停提亮 + 按下缩放 (WindUI 的按钮反馈就是"变亮 + 轻微缩放", 不加描边)
    btn.MouseEnter:Connect(function()
        if btn.BackgroundTransparency < 1 then
            TweenService:Create(btn, TweenInfo.new(0.14), {BackgroundColor3 = THEME.panelHi}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if btn.BackgroundTransparency < 1 then
            TweenService:Create(btn, TweenInfo.new(0.14), {BackgroundColor3 = THEME.panel}):Play()
        end
    end)

    btn.MouseButton1Click:Connect(function()
        playClickSound()          -- ★点击音效
        -- 按下缩放反馈
        TweenService:Create(btn, TweenInfo.new(0.07), {Size = UDim2.new(0.97, 0, 0, UI_METRICS.rowH)}):Play()
        task.delay(0.09, function()
            if btn.Parent then
                TweenService:Create(btn, TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1, 0, 0, UI_METRICS.rowH)}):Play()
            end
        end)
        if callback then callback() end
    end)
    return btn
end

--- 分区标题: 左侧短竖条 + 文字 (WindUI 风: 竖条用实心强调色, 文字再淡一档)
local function makeSection(text)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, IS_MOBILE and 28 or 24)
    holder.BackgroundTransparency = 1
    holder.Parent = target()

    -- 竖条 (★三色渐变: 竖直方向, 紫→青)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0, IS_MOBILE and 14 or 12)
    bar.Position = UDim2.new(0, 2, 0.5, IS_MOBILE and -7 or -6)
    bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)   -- 刷白给渐变垫底
    bar.BorderSizePixel = 0
    bar.Parent = holder
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(1, 0); bc.Parent = bar
    applyGradient(bar, GRAD.purpleCyan, 90)                -- 90° = 上 → 下

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -14, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = THEME.dim
    lbl.TextSize = IS_MOBILE and 12 or 10
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder
    return holder
end

--- 创建滑块 (用于调距离/高度/间隔)
local function makeSlider(text, min, max, default, suffix, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, UI_METRICS.sliderH)
    holder.BackgroundColor3 = THEME.panel
    holder.BorderSizePixel = 0
    holder.Parent = target()
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = holder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 0, IS_MOBILE and 24 or 20)
    label.Position = UDim2.new(0, 10, 0, IS_MOBILE and 4 or 2)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = THEME.text
    label.TextSize = UI_METRICS.fontSize
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.3, 0, 0, IS_MOBILE and 24 or 20)
    valLabel.Position = UDim2.new(0.65, 0, 0, IS_MOBILE and 4 or 2)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(default) .. (suffix or "")
    valLabel.TextColor3 = THEME.accent2
    valLabel.TextSize = UI_METRICS.fontSize
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = holder

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, UI_METRICS.trackH)
    track.Position = UDim2.new(0, 10, 0, IS_MOBILE and 40 or 30)
    track.BackgroundColor3 = THEME.track          -- WindUI: 未填充 = 中性灰轨
    track.BorderSizePixel = 0
    track.Parent = holder
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = track

    -- ★已填充部分: 三色渐变 (紫→靛→青)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)   -- 刷白给渐变垫底
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill
    applyGradient(fill, GRAD.purpleCyan, 0)

    -- ★圆点: 纯白实心, 无发光 (WindUI 就是一块干净的白点)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, UI_METRICS.knobSize, 0, UI_METRICS.knobSize)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = THEME.knob
    knob.BorderSizePixel = 0
    knob.Parent = track
    local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob

    local value = default
    local function render()
        local pct = (value - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, 0, 0.5, 0)
        valLabel.Text = tostring(math.floor(value * 10) / 10) .. (suffix or "")
    end
    render()

    local dragging = false
    local lastStep = -1   -- ★滑动音效节流: 按量化档位播, 避免每帧刷屏
    local function updateFromInput(input)
        local relX = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
        relX = math.clamp(relX, 0, 1)
        value = min + (max - min) * relX
        render()
        -- ★滑动音效: 随位置变速 (右=快/高音, 左=慢/低音) —— 复用点击音效, 按档位节流
        local step = math.floor(relX * 40)
        if step ~= lastStep then
            lastStep = step
            playClickSound(0.55 + relX * 1.45)   -- 左 0.55 → 右 2.0
        end
        if callback then callback(value) end
    end

    -- ★移动端: 点整个滑块块都能调 (不用精准点细轨道)
    local hitArea = track
    if IS_MOBILE then
        hitArea = holder
        hitArea.Active = true
    end

    hitArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            playClickSound()      -- ★拖动开始时响一次 (不按帧响, 否则会刷屏)
            updateFromInput(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return holder, render
end

--//--------------------- 前向声明 (按钮回调需要引用选择器)
local openTargetPicker
local buildCombatPage
local buildPlayerPage
local buildSettingsPage

--//--------------------- 构建界面 (★两个标签页)

-- 切换标签页
local function switchTab(key)
    STATE.tab = key
    setContainer(scroll)

    -- 高亮当前标签 (★WindUI 控件细节保留: 选中 = 实心块 + 深色文字; 只是把填充换成三色渐变)
    for k, btn in pairs(tabButtons) do
        local on = (k == key)
        if on then
            btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)  -- 刷白给渐变垫底
            applyGradient(btn, GRAD.purpleCyan, 0)                -- ★三色渐变填充
            btn.TextColor3 = Color3.fromRGB(12, 12, 14)           -- 深字压亮底, 对比最强
        else
            -- 未选中: 去掉渐变, 回到中性色块
            local g = btn:FindFirstChildOfClass("UIGradient")
            if g then g:Destroy() end
            TweenService:Create(btn, TweenInfo.new(0.18), {
                BackgroundColor3 = THEME.panel,
            }):Play()
            btn.TextColor3 = THEME.subtext
        end
    end

    -- 清空滚动区, 重画当前页
    for _, ch in ipairs(scroll:GetChildren()) do
        if not ch:IsA("UIListLayout") then
            ch:Destroy()
        end
    end
    scroll.CanvasPosition = Vector2.new(0, 0)

    if key == "combat" then
        buildCombatPage()
    elseif key == "player" then
        buildPlayerPage()
    else
        buildSettingsPage()
    end

    -- ★按本页内容高度收缩面板, 消除底部空白
    fitPanelToContent()
end

-- 前向声明
buildCombatPage = nil
buildPlayerPage = nil

--- 战斗页: 踢人 + 传送
buildCombatPage = function()
    makeSection("踢人")

    -- ★合并"踢人功能"与"自动踢人"为单个开关: 开即启用踢人 + 启动自动循环
    CONFIG.AntiKick_Enabled = CONFIG.AntiKick_AutoKick   -- 两者同步, 避免旧配置不一致
    makeToggle("★ 踢人 (自动循环)", CONFIG.AntiKick_AutoKick, function(v)
        CONFIG.AntiKick_AutoKick = v
        CONFIG.AntiKick_Enabled  = v   -- 合并: 开自动即开踢人功能
        if v then
            startAutoKick()
            notify("踢人", string.format("已开启 -- 每 %.1f 秒自动投票", CONFIG.AntiKick_KickInterval), 3, "success")
        else
            stopAutoKick()
            notify("踢人", "已关闭", 2.5, "info")
        end
    end)

    makeSlider("踢人间隔", 0.5, 10, CONFIG.AntiKick_KickInterval, " 秒", function(v)
        CONFIG.AntiKick_KickInterval = v
    end)

    -- ★不踢好友: 始终开启 (CONFIG.AntiKick_ProtectFriend 默认 true, canTarget 已排除好友/白名单),
    --   故不再提供关闭开关, 避免误伤好友。

    makeSlider("跟随距离", 1, 20, CONFIG.Follow_Distance, " studs", function(v)
        CONFIG.Follow_Distance = v
    end)

    makeSlider("跟随高度", 0, 10, CONFIG.Follow_Height, " studs", function(v)
        CONFIG.Follow_Height = v
    end)

    makeButton("选择敌人传送", function()
        openTargetPicker("teleport")
    end)

    makeButton("停止跟随", function()
        stopBehindFollow()
        notify("背后跟随", "已停止", 2.5, "info")
    end, THEME.danger)
end

--- 玩家页: 保护 / 跟随 / 通知
buildPlayerPage = function()
    makeSection("跟随")

    makeToggle("自动随机传送", CONFIG.Teleport_Enabled, function(v)
        CONFIG.Teleport_Enabled = v
        if v then
            startTeleportLoop()
            notify("自动传送", "已开启 -- 持续贴背跟随", 3, "success")
        else
            notify("自动传送", "已关闭", 2.5, "info")
        end
    end)

    makeToggle("★ 跟随失败保护", CONFIG.Follow_FailGuard, function(v)
        CONFIG.Follow_FailGuard = v
    end)

    makeToggle("★ 目标死亡自动换人", CONFIG.Follow_KeepOnDeath, function(v)
        CONFIG.Follow_KeepOnDeath = v
        notify("死亡换人", v and "已开启 -- 目标阵亡自动接手" or "已关闭", 2.5, v and "success" or "info")
    end)

    makeToggle("★ 换成最近的人 (关=随机)", CONFIG.Follow_SwitchMode == "nearest", function(v)
        CONFIG.Follow_SwitchMode = v and "nearest" or "random"
        notify("换人模式", v and "最近距离" or "随机 (防规律)", 2.5, "info")
    end)

    makeToggle("★ 落点安全检测", CONFIG.Teleport_SafeCheck, function(v)
        CONFIG.Teleport_SafeCheck = v
        notify("落点检测", v and "已开启 -- 危险落点将拦截" or "已关闭!", 2.5, v and "success" or "warn")
    end)

    makeSection("通知")

    makeToggle("★ 踢人通知", CONFIG.Kick_Notify, function(v)
        CONFIG.Kick_Notify = v
        notify("踢人通知", v and "已开启" or "已关闭", 2.5, v and "success" or "info")
    end)

    makeToggle("提示音", CONFIG.Kick_Notify_Sound, function(v)
        CONFIG.Kick_Notify_Sound = v
        if v then playKickSound() end   -- 开着就试听一下
        notify("提示音", v and "已开启" or "已静音", 2.5, v and "success" or "info")
    end)

    makeToggle("★ 被投票时提醒我", CONFIG.Warn_OnVoted, function(v)
        CONFIG.Warn_OnVoted = v
        notify("被投提醒", v and "已开启 -- 有人投你会立即提醒" or "已关闭", 2.5, v and "success" or "info")
    end)
end

--- 设置页: 白名单 + 外观 + 音效 + 配置持久化
buildSettingsPage = function()
    -- 前向声明 (tryAdd 要引用它)
    local refreshWhitelist

    makeSection("白名单")

    -- ★搜索框: 输入即联想本服务器玩家
    local inputRow = Instance.new("Frame")
    inputRow.Size = UDim2.new(1, 0, 0, UI_METRICS.rowH)
    inputRow.BackgroundColor3 = THEME.panel
    inputRow.BorderSizePixel = 0
    inputRow.Parent = scroll
    local irc = Instance.new("UICorner"); irc.CornerRadius = UDim.new(0, 7); irc.Parent = inputRow

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -16, 1, -8)
    box.Position = UDim2.new(0, 8, 0, 4)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = "搜索本服玩家 (如 a)"
    box.PlaceholderColor3 = THEME.subtext
    box.TextColor3 = THEME.text
    box.TextSize = IS_MOBILE and 13 or 11
    box.Font = Enum.Font.Gotham
    box.ClearTextOnFocus = false
    box.Parent = inputRow
    local bc2 = Instance.new("UICorner"); bc2.CornerRadius = UDim.new(0, 6); bc2.Parent = box

    -- ★联想结果容器 (输入时出现)
    local sugHolder = Instance.new("Frame")
    sugHolder.Size = UDim2.new(1, 0, 0, 0)
    sugHolder.AutomaticSize = Enum.AutomaticSize.Y
    sugHolder.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    sugHolder.BorderSizePixel = 0
    sugHolder.Visible = false
    sugHolder.Parent = scroll
    local sgc = Instance.new("UICorner"); sgc.CornerRadius = UDim.new(0, 7); sgc.Parent = sugHolder
    local sgs = Instance.new("UIStroke")
    sgs.Color = THEME.accent2; sgs.Thickness = 1; sgs.Transparency = 0.4; sgs.Parent = sugHolder

    local sugPad = Instance.new("UIPadding")
    sugPad.PaddingTop = UDim.new(0, 5); sugPad.PaddingBottom = UDim.new(0, 5)
    sugPad.PaddingLeft = UDim.new(0, 5); sugPad.PaddingRight = UDim.new(0, 5)
    sugPad.Parent = sugHolder

    local sugLayout = Instance.new("UIListLayout")
    sugLayout.Padding = UDim.new(0, 3)
    sugLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sugLayout.Parent = sugHolder

    -- 白名单列表容器
    local wlHolder = Instance.new("Frame")
    wlHolder.Size = UDim2.new(1, 0, 0, 0)
    wlHolder.AutomaticSize = Enum.AutomaticSize.Y
    wlHolder.BackgroundTransparency = 1
    wlHolder.Parent = scroll

    local wlLayout = Instance.new("UIListLayout")
    wlLayout.Padding = UDim.new(0, 4)
    wlLayout.SortOrder = Enum.SortOrder.LayoutOrder
    wlLayout.Parent = wlHolder

    --- 把某人加进白名单 (统一入口)
    local function tryAdd(name, fromSearch)
        local ok, msg = addWhitelist(name)
        if ok then
            notify("白名单", msg, 3, "warn")
            refreshWhitelist()
            box.Text = ""
            sugHolder.Visible = false
        else
            notify("白名单", msg, 3, "warn")
        end
    end

    --- 重建联想列表
    local function refreshSuggest()
        for _, ch in ipairs(sugHolder:GetChildren()) do
            if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
        end

        local kw = box.Text or ""
        kw = string.gsub(kw, "^%s*(.-)%s*$", "%1")
        if kw == "" then
            sugHolder.Visible = false
            fitPanelToContent()
            return
        end

        local hits = searchServerPlayers(kw)

        if #hits == 0 then
            -- 明确告诉用户: 本服没这个人, 不能瞎加
            local no = Instance.new("TextLabel")
            no.Size = UDim2.new(1, 0, 0, 26)
            no.BackgroundTransparency = 1
            no.Text = "本服务器没有匹配的人 —— 只能保护本服玩家"
            no.TextColor3 = THEME.danger
            no.TextSize = IS_MOBILE and 11 or 9
            no.Font = Enum.Font.Gotham
            no.Parent = sugHolder
            sugHolder.Visible = true
            fitPanelToContent()
            return
        end

        local maxShow = 6
        for i = 1, math.min(#hits, maxShow) do
            local plr = hits[i]
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, 0, 0, IS_MOBILE and 32 or 26)
            row.BackgroundColor3 = Color3.fromRGB(38, 46, 40)
            row.BorderSizePixel = 0
            row.LayoutOrder = i
            row.AutoButtonColor = false
            row.Parent = sugHolder
            local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row

            local disp = plr.DisplayName
            local txt = plr.Name
            if disp and disp ~= "" and disp ~= plr.Name then
                txt = plr.Name .. "  (" .. disp .. ")"
            end

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -34, 1, 0)
            lbl.Position = UDim2.new(0, 9, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = txt
            lbl.TextColor3 = THEME.accent2
            lbl.TextSize = IS_MOBILE and 12 or 10
            lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextTruncate = Enum.TextTruncate.AtEnd
            lbl.Parent = row

            local plus = Instance.new("TextLabel")
            plus.Size = UDim2.new(0, 24, 1, 0)
            plus.Position = UDim2.new(1, -28, 0, 0)
            plus.BackgroundTransparency = 1
            plus.Text = "+"
            plus.TextColor3 = THEME.on
            plus.TextSize = IS_MOBILE and 17 or 15
            plus.Font = Enum.Font.GothamBold
            plus.Parent = row

            row.MouseButton1Click:Connect(function()
                playClickSound()
                tryAdd(plr.Name, true)
            end)
        end

        if #hits > maxShow then
            local more = Instance.new("TextLabel")
            more.Size = UDim2.new(1, 0, 0, 20)
            more.BackgroundTransparency = 1
            more.Text = string.format("还有 %d 个, 继续输入缩小范围", #hits - maxShow)
            more.TextColor3 = THEME.subtext
            more.TextSize = IS_MOBILE and 11 or 9
            more.Font = Enum.Font.Gotham
            more.LayoutOrder = maxShow + 1
            more.Parent = sugHolder
        end

        sugHolder.Visible = true
        fitPanelToContent()
    end

    box:GetPropertyChangedSignal("Text"):Connect(refreshSuggest)

    function refreshWhitelist()
        for _, ch in ipairs(wlHolder:GetChildren()) do
            if not ch:IsA("UIListLayout") then ch:Destroy() end
        end

        local list = CONFIG.Whitelist or {}
        if #list == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 24)
            empty.BackgroundTransparency = 1
            empty.Text = "（空）—— 白名单里的人永远不会被踢"
            empty.TextColor3 = THEME.subtext
            empty.TextSize = IS_MOBILE and 11 or 9
            empty.Font = Enum.Font.Gotham
            empty.Parent = wlHolder
            return
        end

        for i, name in ipairs(list) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, IS_MOBILE and 30 or 24)
            row.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
            row.BorderSizePixel = 0
            row.LayoutOrder = i
            row.Parent = wlHolder
            local rc2 = Instance.new("UICorner"); rc2.CornerRadius = UDim.new(0, 5); rc2.Parent = row

            local nm = Instance.new("TextLabel")
            nm.Size = UDim2.new(1, -40, 1, 0)
            nm.Position = UDim2.new(0, 8, 0, 0)
            nm.BackgroundTransparency = 1
            nm.Text = name
            nm.TextColor3 = THEME.friend
            nm.TextSize = IS_MOBILE and 12 or 10
            nm.Font = Enum.Font.Gotham
            nm.TextXAlignment = Enum.TextXAlignment.Left
            nm.Parent = row

            local del = Instance.new("TextButton")
            local delSz = IS_MOBILE and 26 or 20
            del.Size = UDim2.new(0, delSz, 0, delSz)
            del.Position = UDim2.new(1, -(delSz + 6), 0.5, -delSz / 2)
            del.BackgroundColor3 = Color3.fromRGB(60, 32, 32)
            del.Text = ""                 -- ★不用字符, 用两条旋转横杠画叉
            del.BorderSizePixel = 0
            del.AutoButtonColor = false
            del.Parent = row
            local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0, 5); dc.Parent = del

            local armLen = IS_MOBILE and 11 or 9
            local s1 = Instance.new("Frame")
            s1.Size = UDim2.new(0, armLen, 0, 2); s1.AnchorPoint = Vector2.new(0.5, 0.5)
            s1.Position = UDim2.new(0.5, 0, 0.5, 0); s1.Rotation = 45
            s1.BackgroundColor3 = THEME.danger; s1.BorderSizePixel = 0; s1.Parent = del

            local s2 = Instance.new("Frame")
            s2.Size = UDim2.new(0, armLen, 0, 2); s2.AnchorPoint = Vector2.new(0.5, 0.5)
            s2.Position = UDim2.new(0.5, 0, 0.5, 0); s2.Rotation = -45
            s2.BackgroundColor3 = THEME.danger; s2.BorderSizePixel = 0; s2.Parent = del

            del.MouseButton1Click:Connect(function()
                playClickSound()          -- ★点击音效
                removeWhitelist(i)
                refreshWhitelist()
                notify("白名单", "已移除 -- " .. name, 2.5, "info")
            end)
        end
    end

    -- ★回车直接提交 (走同一个校验入口); 失焦后收起联想
    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            playClickSound()
            local nm = box.Text
            if nm and nm ~= "" then
                tryAdd(nm)
                return
            end
        end
        task.wait(0.15)
        sugHolder.Visible = false
        fitPanelToContent()
    end)

    refreshWhitelist()

    makeSection("外观")

    makeSlider("透明度", 0, 0.6, CONFIG.UI_Transparency, "", function(v)
        CONFIG.UI_Transparency = v
        main.BackgroundTransparency = v
        friendBar.BackgroundTransparency = v
    end)

    makeSlider("面板大小", 0.7, 1.4, CONFIG.UI_Scale, "x", function(v)
        CONFIG.UI_Scale = v
        applyPanelScale(v)   -- ★整体等比缩放 (以前只改容器大小, 所以越调空白越大)
        fitPanelToContent()  -- 缩放后重新贴合内容
    end)

    -- ★渐变外框透明度: 0 = 不透明(默认), 1 = 完全透明(只剩主面板)
    makeSlider("外框透明度", 0, 1, CONFIG.FrameOuter_Alpha or 0, "", function(v)
        CONFIG.FrameOuter_Alpha = v
        if STATE.frameOuter then STATE.frameOuter.BackgroundTransparency = v end
    end)

    makeSection("音效")

    makeSlider("点击音量", 0, 0.4, CONFIG.UI_SoundVolume, "", function(v)
        CONFIG.UI_SoundVolume = v
    end)

    makeSlider("点击音调", 0.6, 1.6, CONFIG.UI_SoundPitch, "x", function(v)
        CONFIG.UI_SoundPitch = v
        playClickSound()                   -- 拖动时能听到变化
    end)

    makeSlider("启动音量", 0, 1.0, CONFIG.Startup_SoundVolume, "", function(v)
        CONFIG.Startup_SoundVolume = v
    end)

    makeSection("配置")

    local saveBtn = makeButton("★ 保存配置 (下次自动加载)", function()
        if not hasFs() then
            notify("配置", "当前执行器不支持文件读写, 关游戏后会重置", 4, "error")
            return
        end
        if saveConfig() then
            notify("配置", "已保存 -- " .. CONFIG_FILE, 3, "success")
        else
            notify("配置", "保存失败", 3, "error")
        end
    end, THEME.on)

    makeButton("重置为默认", function()
        CONFIG.UI_Transparency = 0.05
        CONFIG.UI_Scale        = 1.0
        CONFIG.Whitelist       = {}
        main.BackgroundTransparency = 0.05
        main.Size = UDim2.new(0, UI_METRICS.panelW, 0, IS_MOBILE and 420 or 340)
        saveConfig()
        switchTab("settings")
        notify("配置", "已重置为默认配置", 3, "warn")
    end, THEME.danger)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, 0, 0, IS_MOBILE and 46 or 38)
    info.BackgroundTransparency = 1
    info.Text = hasFs() and "支持持久化: 设置会存到执行器目录"
        or "不支持持久化: 重启后设置会丢失"
    info.TextColor3 = hasFs() and THEME.subtext or THEME.danger
    info.TextSize = IS_MOBILE and 11 or 9
    info.Font = Enum.Font.Gotham
    info.TextWrapped = true
    info.Parent = scroll
end

--//===================================================== 选择器 (踢人/传送共用)

local pickerRef = nil

openTargetPicker = function(mode)
    -- 若已有面板, 先销毁
    if pickerRef then
        pcall(function() pickerRef:Destroy() end)
        pickerRef = nil
    end

    -- 传送模式: 一旦打开就锁定(无法关闭), 直到用关闭键
    STATE.pickerActive = true

    local targets = getTargets(false)

    local holder = Instance.new("Frame")
    local pkW = IS_MOBILE and 240 or 190
    local pkRowH = IS_MOBILE and 34 or 26
    holder.Size = UDim2.new(0, pkW, 0, math.min(56 + math.max(#targets,1) * pkRowH, IS_MOBILE and 420 or 340))
    holder.Position = UDim2.new(0.5, -pkW/2, 0.5, -120)
    holder.BackgroundColor3 = THEME.bg
    holder.BorderSizePixel = 0
    holder.ZIndex = 20
    holder.Active = true
    holder.Draggable = true
    holder.Parent = screenGui
    pickerRef = holder

    local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0, 8); hc.Parent = holder
    local hs = Instance.new("UIStroke")
    hs.Color = THEME.accent2
    hs.Thickness = 1
    hs.Parent = holder

    local ht = Instance.new("TextLabel")
    ht.Size = UDim2.new(1, -70, 0, 26)
    ht.Position = UDim2.new(0, 10, 0, 6)
    ht.BackgroundTransparency = 1
    ht.Text = "选择传送目标(不含好友)"
    ht.TextColor3 = THEME.text
    ht.TextSize = 11
    ht.Font = Enum.Font.GothamBold
    ht.TextXAlignment = Enum.TextXAlignment.Left
    ht.ZIndex = 21
    ht.Parent = holder

    -- ★关闭键 (选择传送开启后唯一的关闭方式) —— 用 Frame 画叉, 不用字符
    local closePicker = Instance.new("TextButton")
    closePicker.Size = UDim2.new(0, 22, 0, 22)
    closePicker.Position = UDim2.new(1, -28, 0, 7)
    closePicker.BackgroundColor3 = Color3.fromRGB(48, 26, 26)
    closePicker.Text = ""
    closePicker.BorderSizePixel = 0
    closePicker.AutoButtonColor = false
    closePicker.ZIndex = 22
    closePicker.Parent = holder
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 6); cc.Parent = closePicker

    local pkS1 = Instance.new("Frame")
    pkS1.Size = UDim2.new(0, 10, 0, 2); pkS1.AnchorPoint = Vector2.new(0.5, 0.5)
    pkS1.Position = UDim2.new(0.5, 0, 0.5, 0); pkS1.Rotation = 45
    pkS1.BackgroundColor3 = THEME.danger; pkS1.BorderSizePixel = 0
    pkS1.ZIndex = 23; pkS1.Parent = closePicker

    local pkS2 = Instance.new("Frame")
    pkS2.Size = UDim2.new(0, 10, 0, 2); pkS2.AnchorPoint = Vector2.new(0.5, 0.5)
    pkS2.Position = UDim2.new(0.5, 0, 0.5, 0); pkS2.Rotation = -45
    pkS2.BackgroundColor3 = THEME.danger; pkS2.BorderSizePixel = 0
    pkS2.ZIndex = 23; pkS2.Parent = closePicker

    closePicker.MouseButton1Click:Connect(function()
        playClickSound()          -- ★点击音效
        holder:Destroy()
        pickerRef = nil
        STATE.pickerActive = false
    end)

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, -20, 1, -40)
    list.Position = UDim2.new(0, 10, 0, 34)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 3
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 21
    list.Parent = holder

    local ll = Instance.new("UIListLayout")
    ll.Padding = UDim.new(0, 4)
    ll.Parent = list

    if #targets == 0 then
        local em = Instance.new("TextLabel")
        em.Size = UDim2.new(1, 0, 0, 26)
        em.BackgroundTransparency = 1
        em.Text = "没有可操作的目标"
        em.TextColor3 = THEME.subtext
        em.TextSize = 11
        em.Font = Enum.Font.Gotham
        em.ZIndex = 22
        em.Parent = list
    end

    for _, plr in ipairs(targets) do
        local eb = Instance.new("TextButton")
        eb.Size = UDim2.new(1, IS_MOBILE and -60 or -52, 0, pkRowH - 2)
        eb.BackgroundColor3 = THEME.panel
        eb.Text = plr.Name
        eb.TextColor3 = THEME.accent      -- ★换回红色名字
        eb.TextSize = IS_MOBILE and 12 or 11
        eb.Font = Enum.Font.Gotham
        eb.BorderSizePixel = 0
        eb.ZIndex = 22
        eb.Parent = list
        local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0, 5); ec.Parent = eb

        -- ★P3: 一键加白名单 (不用退出面板抄名字)
        local alreadyWl = isWhitelisted(plr)
        local wlBtn = Instance.new("TextButton")
        wlBtn.Size = UDim2.new(0, IS_MOBILE and 50 or 44, 0, pkRowH - 2)
        wlBtn.Position = UDim2.new(1, IS_MOBILE and -54 or -48, 0, 0)
        wlBtn.BackgroundColor3 = alreadyWl and Color3.fromRGB(45, 70, 55)
                                                or Color3.fromRGB(40, 56, 48)
        wlBtn.Text = alreadyWl and "已护" or "+护"
        wlBtn.TextColor3 = alreadyWl and THEME.on or Color3.fromRGB(120, 190, 140)
        wlBtn.TextSize = IS_MOBILE and 11 or 10
        wlBtn.Font = Enum.Font.GothamBold
        wlBtn.BorderSizePixel = 0
        wlBtn.ZIndex = 22
        wlBtn.Parent = list
        local wc = Instance.new("UICorner"); wc.CornerRadius = UDim.new(0, 5); wc.Parent = wlBtn

        eb.MouseButton1Click:Connect(function()
            playClickSound()      -- ★点击音效
            -- ★点谁传谁; 持续贴背跟随 (始终开启)
            startBehindFollow(plr, true)   -- ★手动锁定, 不自动换人
            holder:Destroy()
            pickerRef = nil
        end)

        wlBtn.MouseButton1Click:Connect(function()
            playClickSound()
            if isWhitelisted(plr) then
                notify("白名单", plr.Name .. " 已在白名单里", 2.5, "info")
                return
            end
            local ok, msg = addWhitelist(plr.Name)
            if ok then
                wlBtn.Text = "已护"
                wlBtn.TextColor3 = THEME.on
                wlBtn.BackgroundColor3 = Color3.fromRGB(45, 70, 55)
                notify("白名单", "已保护 -- " .. msg, 3, "success")
            else
                notify("白名单", msg, 3, "warn")
            end
        end)
    end
end

--//===================================================== 刷新显示

local function refreshFriendBar()
    if STATE.friendLoaded then
        local n = STATE.friendCount or 0
        friendBar.Text = string.format("好友: %d 人", n)
        friendBar.TextColor3 = THEME.friend
    else
        friendBar.Text = "好友: 加载中..."
        friendBar.TextColor3 = THEME.subtext
    end
end

task.spawn(function()
    while task.wait(1) do
        if not screenGui.Parent then break end
        refreshFriendBar()
    end
end)

--//===================================================== 防挂机
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
end)

--//===================================================== ★ 悬浮球 / 收放 / 销毁

--- 创建悬浮球 (收起面板后显示)
local function showBall()
    if STATE.ball and STATE.ball.Parent then
        STATE.ball.Visible = true
        return
    end

    -- ★红圈用「大圆 + 内部深色小圆」叠出来, 不用 UIStroke
    -- UIStroke 在按钮上会贴着文字边框画, 看起来像"套住文字"而不是"裹住圆球"
    local ballSz = UI_METRICS.ballSize
    local ringW  = 3                                  -- 红圈粗细

    local ball = Instance.new("ImageButton")
    ball.Name = "FloatingBall"
    ball.AutoButtonColor = false   -- ★关掉悬停染色
    ball.Size = UDim2.new(0, ballSz, 0, ballSz)
    ball.Position = UDim2.new(0, 20, 0, 80)
    ball.BorderSizePixel = 0
    ball.Active = true
    ball.Draggable = true
    ball.BackgroundColor3 = Color3.fromRGB(255, 255, 255)  -- 刷白给渐变垫底
    applyGradient(ball, GRAD.purpleCyanBright, 135)         -- ★三色渐变底(兜底, 永远可见)
    ball.BackgroundTransparency = 0
    ball.ClipsDescendants = true   -- ★裁切图片层到圆内, 不溢出方角
    ball.Parent = screenGui

    -- ⚠ Roblox 的 Image 只认 rbxassetid:// 数字ID, 本地 jpg 无法直接加载。
    --   把图上传到 Roblox (Studio → 资源管理器 → 图片 → 得到 Image ID) 后,
    --   把下面这个 "0" 换成你的 ID 即可, 例如 "BALL_IMAGE_ID = \"123456789\""
    local BALL_IMAGE_ID = "120986523308359"   -- ★用户提供的紫蛋贴图 ID
    local hasBallImg = (BALL_IMAGE_ID ~= "0" and BALL_IMAGE_ID ~= "")

    -- ★图片层: 单独一个 ImageLabel 盖在渐变底之上, 且【不挂 UIGradient】,
    --   这样紫蛋会按【原色】显示(不会被渐变染色) —— 之前 UIGradient 直接挂在 ball 上,
    --   会把 Image 也乘成紫→青, 看着就像"没用你给的图"。
    --   Active=false 让点击/拖拽穿透到 ball 处理; 图片加载失败则露出底下渐变底, 球仍可见。
    local ballImg = Instance.new("ImageLabel")
    ballImg.Name = "BallImg"
    ballImg.Size = UDim2.new(1, 0, 1, 0)
    ballImg.BackgroundTransparency = 1
    ballImg.ScaleType = Enum.ScaleType.Fit   -- ★图片等比缩放, 填满球不留变形
    ballImg.Active = false                    -- ★纯视觉层, 输入交给 ball (拖拽+点击)
    ballImg.ZIndex = 2
    if hasBallImg then
        ballImg.Image = "rbxassetid://" .. BALL_IMAGE_ID
        ballImg.ImageTransparency = 0
    end
    ballImg.Parent = ball
    local imgCorner = Instance.new("UICorner")
    imgCorner.CornerRadius = UDim.new(1, 0)
    imgCorner.Parent = ballImg

    -- ★悬浮球跟着面板缩放一起变 (不然面板调到 1.4x, 球还是原来大小, 不协调)
    local ballScale = Instance.new("UIScale")
    ballScale.Name = "BallScale"
    ballScale.Scale = CONFIG.UI_Scale or 1.0
    ballScale.Parent = ball
    STATE.ballScale = ballScale
    STATE.ball = ball

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)          -- 1,0 = 正圆
    ringCorner.Parent = ball

    -- 内部深色圆 + "防" 字: 仅在没有图片时显示(有图片就显示图片, 不需要字)
    local inner = Instance.new("Frame")
    inner.Name = "Inner"
    inner.Size = UDim2.new(0, ballSz - ringW * 2, 0, ballSz - ringW * 2)
    inner.Position = UDim2.new(0, ringW, 0, ringW)
    inner.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    inner.BorderSizePixel = 0
    inner.Visible = not hasBallImg   -- ★有图则隐藏, 无图则显示防字
    inner.ZIndex = 3
    inner.Parent = ball
    local innerCorner = Instance.new("UICorner")
    innerCorner.CornerRadius = UDim.new(1, 0)
    innerCorner.Parent = inner

    -- "防" 字 (渐变高亮色)
    local ballText = Instance.new("TextLabel")
    ballText.Size = UDim2.new(1, 0, 1, 0)
    ballText.BackgroundTransparency = 1
    ballText.Text = "蛋"
    ballText.TextColor3 = THEME.text
    ballText.TextSize = IS_MOBILE and 22 or 18
    ballText.Font = Enum.Font.GothamBold
    ballText.ZIndex = 4
    ballText.Parent = inner

    -- 拖动判定: 按下到松开间隔很短才算"点击", 避免拖完误触
    local pressAt = 0

    -- ★ball 直接做成 ImageButton: 既能 Draggable 移动整颗球, 又能接 MouseButton1Click,
    --   还预留 Image 属性。之前盖一层 TextButton(hit) 反而把拖拽抢走了 —— 球整体拖不动。
    ball.MouseButton1Down:Connect(function() pressAt = tick() end)

    ball.MouseButton1Click:Connect(function()
        if tick() - pressAt > 0.25 then return end   -- 是拖动, 不展开
        playClickSound()                             -- ★点击音效
        STATE.collapsed = false
        ball.Visible = false
        main.Visible = true
        frameOuter.Visible = true
        if friendBar then friendBar.Visible = true end
    end)
end

--- [—] 收起面板, 变成悬浮球
local function collapseToBall()
    STATE.collapsed = true
    main.Visible = false
    frameOuter.Visible = false
    if friendBar then friendBar.Visible = false end
    if pickerRef then
        pcall(function() pickerRef:Destroy() end)
        pickerRef = nil
    end
    showBall()
    -- 球放在面板原来的位置
    if STATE.ball then
        STATE.ball.Position = UDim2.new(0, main.AbsolutePosition.X, 0, main.AbsolutePosition.Y)
    end
end

--- [✕] 彻底销毁 UI (脚本逻辑继续运行)
local function destroyUI()
    STATE.destroyed = true

    -- 停掉跟随连接
    if STATE.followConn then
        pcall(function() STATE.followConn:Disconnect() end)
        STATE.followConn = nil
    end

    -- 销毁各类界面
    pcall(function() if pickerRef then pickerRef:Destroy() end end)
    pickerRef = nil
    pcall(function() if STATE.ball then STATE.ball:Destroy() end end)
    STATE.ball = nil
    pcall(function() if STATE.hudGui then STATE.hudGui:Destroy() end end)
    STATE.hudGui, STATE.hudLabel = nil, nil
    pcall(function() if main then main:Destroy() end end)
    pcall(function() if screenGui then screenGui:Destroy() end end)

    notify("EGG", "UI 已销毁 (脚本仍在运行, 重开需重新执行)", 4, "warn")
    print("[EGG] UI 已销毁, 后台逻辑继续运行")
end

minBtn.MouseButton1Click:Connect(function() playClickSound(); collapseToBall() end)
closeBtn.MouseButton1Click:Connect(function() playClickSound(); destroyUI() end)

--//===================== ★ 启动动画 (华丽版: 环形扫描 + 打字机 + 检查行 + 进度条) =====================
--
-- 5 个阶段, 总长约 4.5 秒:
--   ① 环形扫描 1.0s  双环反向旋转 + Logo「防」缩放淡入
--   ② 标题     0.8s  标题打字机 + 下方渐变分隔线展开
--   ③ 检查行   1.6s  4 行右滑入 + 右侧状态值
--   ④ 进度条   0.8s  渐变进度条冲刺 + 数字滚动
--   ⑤ 淡出     0.3s  整体缩放 + 透明度消失
--
-- 仍然是阻塞式: 播完才出主界面 (之前是动画没完主界面就冒出来了)

--- 播放开场动画
local function playStartupAnimation()
    if CONFIG.Startup_Anim == false then return end

    local ok = pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "EGG_Startup"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 999
        pcall(function()
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        end)
        if not gui.Parent then gui.Parent = game:GetService("CoreGui") end
        STATE.startupGui = gui

        local W, H = IS_MOBILE and 320 or 330, IS_MOBILE and 300 or 280

        -- 整块容器 (用来做最后的整体缩放/淡出)
        local root = Instance.new("Frame")
        root.Name = "Root"
        root.Size = UDim2.new(0, W, 0, H)
        root.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
        root.BackgroundColor3 = Color3.fromRGB(11, 11, 16)
        root.BackgroundTransparency = 0.04
        root.BorderSizePixel = 0
        root.ClipsDescendants = true
        root.Parent = gui
        local rootCorner = Instance.new("UICorner"); rootCorner.CornerRadius = UDim.new(0, 14); rootCorner.Parent = root
        local rootScale = Instance.new("UIScale"); rootScale.Scale = 1; rootScale.Parent = root

        -- 面板描边 (WindUI 风: 淡中性细线)
        local rootStroke = Instance.new("UIStroke")
        rootStroke.Color = THEME.g1                     -- ★紫端 (UIStroke 不支持渐变)
        rootStroke.Thickness = 1.4
        rootStroke.Transparency = 0.45
        rootStroke.Parent = root

        -- 顶部扫描光带 (WindUI 风: 用强调色的低透明实心, 不做彩色渐变)
        local sweep = Instance.new("Frame")
        sweep.Size = UDim2.new(1, 0, 0, 60)
        sweep.Position = UDim2.new(0, 0, 0, -60)
        sweep.BackgroundColor3 = Color3.fromRGB(255, 255, 255)    -- 刷白给渐变垫底
        applyGradient(sweep, GRAD.purpleCyan, 0)                 -- ★三色渐变
        sweep.BackgroundTransparency = 0.94
        sweep.BorderSizePixel = 0
        sweep.Parent = root
        task.spawn(function()
            task.wait(0.1)
            TweenService:Create(sweep, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {
                Position = UDim2.new(0, 0, 0, H),
            }):Play()
        end)

        --//=========== ① 环形扫描 + Logo ============
        local ringHolder = Instance.new("Frame")
        ringHolder.Size = UDim2.new(0, 66, 0, 66)
        ringHolder.Position = UDim2.new(0.5, -33, 0, 26)
        ringHolder.BackgroundTransparency = 1
        ringHolder.Parent = root

        -- 外环 (顺时针)
        local ringA = Instance.new("Frame")
        ringA.Size = UDim2.new(1, 0, 1, 0)
        ringA.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ringA.BackgroundTransparency = 1
        ringA.BorderSizePixel = 0
        ringA.Parent = ringHolder
        local raC = Instance.new("UICorner"); raC.CornerRadius = UDim.new(1, 0); raC.Parent = ringA
        local raS = Instance.new("UIStroke")
        raS.Color = THEME.g1; raS.Thickness = 2.5; raS.Transparency = 0   -- ★紫端
        raS.Parent = ringA

        -- 内环 (逆时针, 细一点)
        local ringB = Instance.new("Frame")
        ringB.Size = UDim2.new(0, 52, 0, 52)
        ringB.Position = UDim2.new(0.5, -26, 0.5, -26)
        ringB.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ringB.BackgroundTransparency = 1
        ringB.BorderSizePixel = 0
        ringB.Parent = ringHolder
        local rbC = Instance.new("UICorner"); rbC.CornerRadius = UDim.new(1, 0); rbC.Parent = ringB
        local rbS = Instance.new("UIStroke")
        rbS.Color = THEME.g3; rbS.Thickness = 1.2; rbS.Transparency = 0.45  -- ★青端 (双环异色)
        rbS.Parent = ringB

        -- Logo 圆底 (WindUI 风: 实心强调色)
        local logoBg = Instance.new("Frame")
        logoBg.Size = UDim2.new(0, 40, 0, 40)
        logoBg.Position = UDim2.new(0.5, -20, 0.5, -20)
        logoBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)   -- 刷白给渐变垫底
        applyGradient(logoBg, GRAD.purpleCyanBright, 135)        -- ★对角三色渐变
        logoBg.BorderSizePixel = 0
        logoBg.Parent = ringHolder
        local lbC = Instance.new("UICorner"); lbC.CornerRadius = UDim.new(1, 0); lbC.Parent = logoBg

        local logo = Instance.new("TextLabel")
        logo.Size = UDim2.new(1, 0, 1, 0)
        logo.BackgroundTransparency = 1
        logo.Text = "蛋"
        logo.TextColor3 = Color3.fromRGB(12, 12, 14)   -- 深字压亮底
        logo.TextSize = 20
        logo.Font = Enum.Font.GothamBold
        logo.TextTransparency = 1
        logo.Parent = logoBg

        -- 双环反向旋转
        task.spawn(function()
            local t1 = TweenService:Create(ringA, TweenInfo.new(1.6, Enum.EasingStyle.Linear), {Rotation = 360})
            t1:Play()
            local t2 = TweenService:Create(ringB, TweenInfo.new(2.2, Enum.EasingStyle.Linear), {Rotation = -360})
            t2:Play()
        end)

        -- Logo 缩放淡入 (从很小弹出来)
        logoBg.Size = UDim2.new(0, 0, 0, 0)
        logoBg.Position = UDim2.new(0.5, 0, 0.5, 0)
        TweenService:Create(logoBg, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 40, 0, 40),
            Position = UDim2.new(0.5, -20, 0.5, -20),
        }):Play()
        TweenService:Create(logo, TweenInfo.new(0.45), {TextTransparency = 0}):Play()

        --//=========== ② 标题打字机 ============
        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(1, -32, 0, 22)
        titleLbl.Position = UDim2.new(0, 16, 0, 98)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = ""
        titleLbl.TextColor3 = THEME.text
        titleLbl.TextSize = IS_MOBILE and 15 or 14
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = root

        -- 标题下方的分隔线 (WindUI 风: 实心强调色细线)
        local divLine = Instance.new("Frame")
        divLine.Size = UDim2.new(0, 0, 0, 2)
        divLine.Position = UDim2.new(0, 16, 0, 122)
        divLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)  -- 刷白给渐变垫底
        applyGradient(divLine, GRAD.purpleCyanBright, 0)         -- ★三色渐变
        divLine.BorderSizePixel = 0
        divLine.Parent = root
        local dlC = Instance.new("UICorner"); dlC.CornerRadius = UDim.new(1, 0); dlC.Parent = divLine

        --//=========== ③ 检查行 ============
        local CHECKS = {
            { text = "好友列表已加载",   value = nil },          -- value nil = 运行时填
            { text = "白名单保护已启用", value = nil },
            { text = "投票接口已就绪",   value = "" },
            { text = "护盾运行中",       value = "" },
        }

        local rowHolders = {}
        for i, ck in ipairs(CHECKS) do
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -32, 0, 20)
            row.Position = UDim2.new(0, 48, 0, 138 + (i - 1) * 21)   -- 初始右偏
            row.BackgroundTransparency = 1
            row.Parent = root

            -- 左侧小圆点 (状态色)
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, 6, 0, 6)
            dot.Position = UDim2.new(0, -18, 0.5, -3)
            dot.BackgroundColor3 = THEME.on
            dot.BorderSizePixel = 0
            dot.BackgroundTransparency = 1
            dot.Parent = row
            local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, -70, 1, 0)
            txt.BackgroundTransparency = 1
            txt.Text = ck.text
            txt.TextColor3 = THEME.subtext
            txt.TextSize = IS_MOBILE and 12 or 11
            txt.Font = Enum.Font.Gotham
            txt.TextXAlignment = Enum.TextXAlignment.Left
            txt.TextTransparency = 1
            txt.Parent = row

            local val = Instance.new("TextLabel")
            val.Size = UDim2.new(0, 70, 1, 0)
            val.Position = UDim2.new(1, -70, 0, 0)
            val.BackgroundTransparency = 1
            val.Text = ""
            val.TextColor3 = THEME.on
            val.TextSize = IS_MOBILE and 12 or 11
            val.Font = Enum.Font.GothamBold
            val.TextXAlignment = Enum.TextXAlignment.Right
            val.TextTransparency = 1
            val.Parent = row

            rowHolders[i] = { row = row, dot = dot, txt = txt, val = val }
        end

        --//=========== ④ 进度条 ============
        local pbTrack = Instance.new("Frame")
        pbTrack.Size = UDim2.new(1, -32, 0, 6)
        pbTrack.Position = UDim2.new(0, 16, 1, -36)
        pbTrack.BackgroundColor3 = Color3.fromRGB(38, 38, 52)
        pbTrack.BorderSizePixel = 0
        pbTrack.Parent = root
        local pbC = Instance.new("UICorner"); pbC.CornerRadius = UDim.new(1, 0); pbC.Parent = pbTrack

        local pbFill = Instance.new("Frame")
        pbFill.Size = UDim2.new(0, 0, 1, 0)
        pbFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)   -- 刷白给渐变垫底
        applyGradient(pbFill, GRAD.purpleCyanBright, 0)          -- ★三色渐变
        pbFill.BorderSizePixel = 0
        pbFill.Parent = pbTrack
        local pfC = Instance.new("UICorner"); pfC.CornerRadius = UDim.new(1, 0); pfC.Parent = pbFill

        local pctLbl = Instance.new("TextLabel")
        pctLbl.Size = UDim2.new(0, 60, 0, 16)
        pctLbl.Position = UDim2.new(1, -60, 1, -28)   -- ★移到进度条下方, 避免被进度条挡住
        pctLbl.BackgroundTransparency = 1
        pctLbl.Text = "0%"
        pctLbl.TextColor3 = THEME.accent2
        pctLbl.TextSize = IS_MOBILE and 12 or 11
        pctLbl.Font = Enum.Font.GothamBold
        pctLbl.TextXAlignment = Enum.TextXAlignment.Right
        pctLbl.TextTransparency = 1
        pctLbl.Parent = root

        -- 状态文字 (进度条上方左侧)
        local stageLbl = Instance.new("TextLabel")
        stageLbl.Size = UDim2.new(1, -100, 0, 16)
        stageLbl.Position = UDim2.new(0, 16, 1, -56)
        stageLbl.BackgroundTransparency = 1
        stageLbl.Text = ""
        stageLbl.TextColor3 = THEME.dim
        stageLbl.TextSize = IS_MOBILE and 11 or 10
        stageLbl.Font = Enum.Font.Gotham
        stageLbl.TextXAlignment = Enum.TextXAlignment.Left
        stageLbl.TextTransparency = 1
        stageLbl.Parent = root

        --//=========== 当前阶段 (给外部调试/测试读取) ============
        local stageOrder = {}
        local function markStage(name)
            table.insert(stageOrder, name)
            STATE.startupStages = stageOrder
        end

        --//=========== 主流程 ============
        local finished = false
        task.spawn(function()
            -- ★整段动画用 pcall 包住: 任何一步出错都要保证 finished=true + 清理 GUI,
            --   否则外层会死等满 6 秒兜底, 期间屏幕上只剩一个不动的黑底 root.
            local animOk, animErr = pcall(function()
                playStartupSound()          -- ★你指定的 sonic

            -- ★跳过检查: 按 T 可立即结束动画 (STATE.skipStartup 由按键置位)
            local function skipped()
                return STATE.skipStartup == true
            end

            -- ① 环形扫描 (1.0s)
            markStage("rings")
            local acc = 0
            while acc < 1.0 and not skipped() do
                task.wait(0.05); acc = acc + 0.05
            end

            -- ② 标题打字机 (0.8s)
            markStage("title")
            stageLbl.TextTransparency = 0
            stageLbl.Text = "初始化中..."
            pctLbl.TextTransparency = 0

            local fullTitle = "EGG"
            for n = 1, #fullTitle do
                if skipped() then titleLbl.Text = fullTitle; break end
                titleLbl.Text = string.sub(fullTitle, 1, n)
                task.wait(0.032)
            end
            -- 下面补一行中文副标题
            local subLbl = Instance.new("TextLabel")
            subLbl.Size = UDim2.new(1, -32, 0, 16)
            subLbl.Position = UDim2.new(0, 16, 0, 118)
            subLbl.BackgroundTransparency = 1
            subLbl.Text = "防踢护盾+传送"
            subLbl.TextColor3 = THEME.accent2
            subLbl.TextSize = IS_MOBILE and 12 or 11
            subLbl.Font = Enum.Font.Gotham
            subLbl.TextXAlignment = Enum.TextXAlignment.Left
            subLbl.TextTransparency = 1
            subLbl.Parent = root
            TweenService:Create(subLbl, TweenInfo.new(0.25), {TextTransparency = 0}):Play()

            -- 分隔线展开
            local divTw = TweenService:Create(divLine, TweenInfo.new(0.4, Enum.EasingStyle.Quint,
                Enum.EasingDirection.Out), {Size = UDim2.new(1, -32, 0, 2)})
            divTw:Play()

            -- 填真实的检查值
            local fn = STATE.friendCount or 0
            CHECKS[1].value = (fn > 0) and (fn .. " 人") or "无"
            CHECKS[2].value = (#(CONFIG.Whitelist or {}) .. " 人")
            CHECKS[3].value = "OK"
            CHECKS[4].value = "ON"

            task.wait(0.35)

            -- ③ 检查行逐行滑入 (1.6s)
            markStage("checks")
            for i, ck in ipairs(CHECKS) do
                local h = rowHolders[i]
                if h then
                    local fast = skipped()
                    -- 从小幅右偏滑入
                    TweenService:Create(h.row, TweenInfo.new(fast and 0.12 or 0.3, Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, 16, 0, 138 + (i - 1) * 21),
                    }):Play()
                    TweenService:Create(h.txt, TweenInfo.new(fast and 0.1 or 0.25), {TextTransparency = 0}):Play()
                    TweenService:Create(h.dot, TweenInfo.new(fast and 0.1 or 0.25), {BackgroundTransparency = 0}):Play()
                    h.val.Text = ck.value or ""
                    TweenService:Create(h.val, TweenInfo.new(fast and 0.1 or 0.25), {TextTransparency = 0}):Play()

                    -- 每行一声轻"咔" (音高递升)
                    if not fast then
                        playSound("startup" .. i, "rbxassetid://6895079853",
                            (CONFIG.UI_SoundVolume or 0.12) * 0.9, 1.0 + (i - 1) * 0.07)
                    end

                    stageLbl.Text = ck.text .. "..."
                    task.wait(fast and 0.06 or 0.34)
                end
            end

            -- ④ 进度条冲刺 (0.8s)
            markStage("progress")
            stageLbl.Text = "护盾已就绪"
            local steps = skipped() and 6 or 40
            for k = 0, steps do
                local p = k / steps
                -- 缓动: 先快后慢再冲
                local eased = 1 - (1 - p) ^ 2
                if k < steps * 0.7 then eased = eased * 0.75 end
                pbFill.Size = UDim2.new(eased, 0, 1, 0)
                pctLbl.Text = string.format("%d%%", math.floor(eased * 100))
                task.wait(0.02)
            end
            pbFill.Size = UDim2.new(1, 0, 1, 0)
            pctLbl.Text = "100%"
            stageLbl.Text = "启动完成"

            -- 完成闪光: 整条亮度脉冲
            local flash = Instance.new("Frame")
            flash.Size = UDim2.new(1, 0, 1, 0)
            flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            flash.BackgroundTransparency = 1
            flash.BorderSizePixel = 0
            flash.ZIndex = 10
            flash.Parent = root
            local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 14); fc.Parent = flash
            TweenService:Create(flash, TweenInfo.new(0.12), {BackgroundTransparency = 0.88}):Play()
            task.delay(0.14, function()
                TweenService:Create(flash, TweenInfo.new(0.28), {BackgroundTransparency = 1}):Play()
            end)
            playSound("startupDone", "rbxassetid://6895079853", (CONFIG.UI_SoundVolume or 0.12), 1.5)

            task.wait(0.22)

            -- ⑤ 整体缩放淡出 (0.3s)
            markStage("fade")
            TweenService:Create(rootScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad,
                Enum.EasingDirection.In), {Scale = 1.06}):Play()
            local fadeTw = TweenService:Create(root, TweenInfo.new(0.3), {BackgroundTransparency = 1})
            fadeTw:Play()
            rootStroke.Transparency = 1

            -- 所有子元素一起淡出 (直接淡出, root 只负责底色)
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextLabel") then
                    -- ★直接置 1, 不要 Tween: 否则会和 root 的淡出 tween 抢同一属性, 导致闪回
                    d.TextTransparency = 1
                elseif d:IsA("TextButton") or d:IsA("Frame") then
                    d.BackgroundTransparency = 1
                elseif d:IsA("UIStroke") then
                    d.Transparency = 1
                end
            end

            task.wait(0.32)
            end)   -- ★动画 pcall 结束

            -- ★不管动画是否出错, 这里统一收尾: 销毁 GUI + 放行外层等待
            if not animOk then
                warn("[EGG] 启动动画中断: " .. tostring(animErr))
            end
            if gui and gui.Parent then pcall(function() gui:Destroy() end) end
            STATE.startupGui = nil
            finished = true
        end)

        -- ★等待动画结束 (6 秒兜底)。
        --   面板不依赖这个返回值, 所以即使动画卡住, 界面也照常可用。
        local waited = 0
        while not finished and waited < 6 do
            task.wait(0.05)
            waited = waited + 0.05
        end

        -- ★超时了也要把浮层收掉, 不能留在屏幕上
        if not finished then
            warn("[EGG] 启动动画超时, 已强制收尾")
            if gui and gui.Parent then pcall(function() gui:Destroy() end) end
            STATE.startupGui = nil
        end
    end)

    -- ★动画内部出错也不能把界面留在"隐藏"状态 (否则用户看到的就是空面板)
    if not ok then
        warn("[EGG] 启动动画出错, 已跳过并直接显示面板")
        if STATE.startupGui then
            pcall(function() STATE.startupGui:Destroy() end)
        end
        STATE.startupGui = nil
    end
end

--//===================================================== 初始化
loadConfig()          -- ★先读持久化配置 (会覆盖上面的默认值)
loadFriends()
refreshFriendBar()
startVoteListener()   -- ★监听服务端投票事件(去重情报来源)

-- ★画初始页面
makeTab("combat",   "战斗", 1)
makeTab("player",   "玩家", 2)
makeTab("settings", "设置", 3)
tabButtons.combat.MouseButton1Click:Connect(function() playClickSound(); switchTab("combat") end)
tabButtons.player.MouseButton1Click:Connect(function() playClickSound(); switchTab("player") end)
tabButtons.settings.MouseButton1Click:Connect(function() playClickSound(); switchTab("settings") end)
switchTab("combat")

-- ★应用持久化外观
main.BackgroundTransparency = CONFIG.UI_Transparency or 0.05
friendBar.BackgroundTransparency = CONFIG.UI_Transparency or 0.05
applyPanelScale(CONFIG.UI_Scale or 1.0)   -- ★整体等比缩放, 不是只改容器
fitPanelToContent()                       -- ★贴合内容, 去掉底部空白

-- ★自动保存 (面板关闭/销毁前存一次)
task.spawn(function()
    while task.wait(30) do
        if STATE.destroyed then break end
        saveConfig()
    end
end)

notify("EGG", "已加载 | 好友保护已启用", 4, "success")

-- ★启动动画: 动画期间先藏主界面, 只播动画; 播完/失败/跳过后再显示。
--
-- 【为什么这样做】用户希望开场只看到动画、而不是"面板先加载出来 + 动画盖在上面"。
-- 之前(Turn-3)为了不卡死改成"面板全程可见", 现在要回到"先藏后显",
-- 但必须保证不会再出现 Turn-3 那种「动画一抛错 → 面板永远不出来」的死局:
--   · 动画函数本身有内部 pcall + 6 秒兜底定时器, 最差也只是动画糊一下
--   · 外层再包一层 pcall, 且「显示面板」这句写在失败路径之外, 无论动画成不成都必执行
if CONFIG.Startup_Anim then
    -- ★动画前先藏: 主界面 + 好友条一起藏, 只留动画浮层
    main.Visible = false
    frameOuter.Visible = false
    if friendBar then friendBar.Visible = false end
    task.spawn(function()
        STATE.skipStartup = false       -- 重置跳过标志
        pcall(function() playStartupAnimation() end)   -- 内部已自带 pcall + 6s 兜底, 双保险
        -- ★注意: 这里不提前把 skipStartup 置 nil —— 动画是 task.spawn 异步跑的,
        --   若紧跟 pcall 后立刻置 nil, 动画播放期间 skipStartup 变 nil,
        --   而 T 键判断已用 ~= true (nil ~= true 成立) 所以仍能触发跳过;
        --   若用 == false 判断就会失效。统一在动画收尾后再复位。
        -- 动画结束/失败后, 强制清掉可能残留的动画浮层
        pcall(function()
            if STATE.startupGui then
                STATE.startupGui:Destroy()
                STATE.startupGui = nil
            end
        end)
        -- ★这一句在失败路径之外: 无论动画成不成、卡不卡, 主界面必定恢复
        main.Visible = true
        frameOuter.Visible = true
        if friendBar then friendBar.Visible = true end
        STATE.skipStartup = nil          -- ★动画彻底收尾后再复位, 不挡 T 键跳过
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if STATE.destroyed then return end
    -- ★固定 T 键 (面板里不再提供改绑)
    local hotkey = Enum.KeyCode[CONFIG.HOTKEY or "T"]
    if hotkey and input.KeyCode == hotkey then
        -- ★启动动画还在播 → 按 T = 跳过动画 (优先于显隐面板)
        if STATE.startupGui and STATE.skipStartup ~= true then
            STATE.skipStartup = true
            return
        end

        if STATE.collapsed then
            -- 收起状态下按快捷键 → 展开
            STATE.collapsed = false
            if STATE.ball then STATE.ball.Visible = false end
            main.Visible = true
            frameOuter.Visible = true
            if friendBar then friendBar.Visible = true end
        else
            main.Visible = not main.Visible
            if friendBar then friendBar.Visible = main.Visible end
        end
    end
end)

print("[EGG] 已加载")
print(string.format("[EGG] 平台: %s", IS_MOBILE and "移动端(触摸优化)" or "PC端"))
print(string.format("[EGG] 保护对象: 好友列表 + 白名单(%d 人)", #(CONFIG.Whitelist or {})))
print(string.format("[EGG] 快捷键: %s | 配置持久化: %s",
    CONFIG.HOTKEY or "T", hasFs() and "支持" or "不支持"))
print(string.format("[EGG] 音效: 点击%s(%.2f) | 启动%s(%.2f)",
    CONFIG.UI_Sound and "开" or "关", CONFIG.UI_SoundVolume or 0,
    CONFIG.Startup_Anim and "开" or "关", CONFIG.Startup_SoundVolume or 0))
