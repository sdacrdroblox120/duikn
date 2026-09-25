--[[
================================================================================
EGG  ·  防御 + 高级功能 (命中率反作弊识别)  —  Obsidian 版 (第二十轮 · 音乐→检测)
================================================================================
  ★ 本版相对第十八轮的改动 (Rayfield -> Obsidian 换库 + 页面重排):
    1. ★ 换库: 原 Rayfield 红黑主题改为 Obsidian (Linoria 改良版) 界面框架。
       控件 API 由 Rayfield 改为 Obsidian (CreateWindow / AddTab /
       AddLeftGroupbox / AddToggle 等), 回调逻辑 100% 保持不变。
       想换肤用 ThemeManager 内置主题或 ThemeManager:SetTheme(...)。
    2. ★ 页面重排: 「管理员防护」整块(含诊断模式) 由「配置」页搬到「防御」页;
       「开启动画音效」整块由「音乐」页搬到「配置」页。
    3. ★ 文案统一: Tab「防踢」-> 「防御」, 加载屏「防踢护盾」-> 「防御护盾」。
    4. ★ 独立「汽水音乐」播放器脚本已删除, 功能全部并入音乐页 (见第十八轮存档)。
    ⚠ 折叠收纳已移除: 原「🗂 收起/展开」依赖 Rayfield 的 `实例.Name` 反射机制,
      Obsidian 无此机制。账号登录 / 接口设置改为音乐页常显 Groupbox (不再折叠)。
  ★ 音乐引擎依赖: 注入器需支持 writefile / getcustomasset (下载后本地播放)。
  ★ 加载方式 (Obsidian 官方源):
       local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
================================================================================
  ▼ 第十八轮 (最后一人音乐改在线曲库 + 自定义歌单 + 开启动画音效 + 独立播放器):
    1. 音乐来源: 硬编码 Roblox 音频 ID -> 在线曲库实时取歌。
    2. 默认曲风: 中文DJ / dj舞曲 / 车载dj / phonk / funk 等随机关键词搜索。
    3. 自定义歌单: CONFIG.Music_CustomList, 有歌单优先播歌单。
    4. 播放方式: 在线下载 MP3 -> getcustomasset 本地播放。
    5. 开启动画音效: CONFIG.Startup_Sound, 加载完成 0.6s 后播放, 带开关与试听。
    6. 新增独立播放器 EGG_汽水音乐.lua (第十九轮已删除, 功能并入音乐页)。
================================================================================
  ▼ 第十七轮 (音乐引擎重构 + 界面美化):
    1. ★ 音乐引擎换血: 由「通用聚合 API」改为「网易云 NeteaseCloudMusic 接口」,
       接口协议支持登录自己的账号 (cookie), 登录后可按账号权限播放 VIP 完整曲。
       接口地址: CONFIG.Music_Api (默认第三方 Cloudflare Worker, 可在音乐页替换)。
    2. ★ 新增「账号登录」: 手机号 + 短信验证码登录 (无需手抓 cookie),
       登录状态/昵称/VIP 标识实时显示; cookie 本地持久化, 可一键退出登录。
    3. ★ 新增「接口设置」: 可改接口地址、切音质 (standard/higher/exhigh/lossless),
       并带「测试接口连通性」按钮, 接口失效时可自行更换。
    4. ★ 下载策略: 优先走 Worker 的 /dl (带 cookie, 可拿 VIP 曲), 失败再退回直链下载。
    5. ★ 独立「汽水音乐」播放器已下线 (EGG_汽水音乐.lua 已删除), 功能全部并入「音乐」页。
    6. ★ 界面美化: 全部控件/分区/说明加上 emoji 前缀。
    7. 「脚本分支」保留: 可继续用来自行加载第三方脚本 (如无限子弹)。
================================================================================
]]

--//===================================================== 服务
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local SoundService     = game:GetService("SoundService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--//===================================================== 配置
local CONFIG = {
    -- 踢人
    AntiKick_Enabled     = false,   -- ★默认关闭 (不持久化, 每次进游戏都从关开始)
    AntiKick_ProtectFriend = true,  -- ★不踢好友 (常开, 不可关)
    AntiKick_AutoKick    = false,   -- ★自动循环踢人 (不持久化)
    AntiKick_KickInterval= 2.0,     -- ★自动踢人间隔(秒), 可调
    AntiKick_Shield     = false,   -- ★反踢护盾 (拦截踢人远程 + 反作弊本地调用, 默认关, 不持久化)
    -- ★检测 (命中率 / 反作弊识别): 只观测、只标记, 不替你操作、不给战斗优势
    Detection_Enabled    = true,     -- ★检测总开关 (关=不统计、不弹提醒)
    Detection_Threshold  = 80,       -- ★命中率阈值(%): 命中率 ≥ 此值的对手上检测榜
    Detection_MinShots   = 10,       -- ★最少射击次数: 低于此数的对手不参与统计(防偶然高命中)
    Detection_IgnoreTeam = true,     -- ★不检测队友 (同队玩家跳过统计)
    -- ★击中提示 (本地玩家打中敌人的反馈, 右上角)
    HitFeedback_Enabled   = true,    -- ★子弹击中提示 (总开关)
    HitFeedback_Melee     = false,   -- ★近战击中提示 (单独开; 默认关, 不挡视野)
    -- ★踢人通知 (Obsidian 通知卡片 + 提示音)
    Kick_Notify          = true,    -- 通知总开关
    Kick_Notify_Sound    = true,    -- 提示音开关
    Kick_SoundId         = "rbxassetid://112972396921894",
    Kick_SoundVolume     = 0.25,    -- 音量(0~1), 刻意调低不打扰
    -- ★UI 点击音效: 已按用户要求关闭 (当前执行器/UI 环境下无法发声)
    --   如需重新启用: 把 UI_ClickSound 改成 true, 并在 UI_SoundPack 里填可用的 assetid
    Click_SoundId        = "rbxassetid://5888021297",
    Click_SoundVolume    = 0.4,
    UI_ClickSound        = false,    -- 总开关 (默认关)
    UI_SoundPack = {
        ToggleOn  = { id = "", vol = 0.45, pitch = 1.35 },
        ToggleOff = { id = "", vol = 0.40, pitch = 0.85 },
        Button    = { id = "", vol = 0.42, pitch = 1.15 },
        Slider    = { id = "", vol = 0.28, pitch = 1.6  },
    },
    UI_Haptic            = false,    -- 触摸震动 (默认关)
    Startup_Sound        = true,     -- ★开启动画音效开关 (脚本加载完成时播放)
    Startup_SoundId      = "rbxassetid://100102530391513",
    Startup_SoundVolume  = 0.5,      -- 开机音效音量(0~1)

    -- ★界面: 是否允许把 Groupbox 拖出来变成浮动小窗 (Obsidian PopOut 功能)
    --   默认关: 拖动功能区域不会脱离成悬浮窗; 想用拖拽分离再在「配置」页打开此开关
    UI_DragPopout        = false,

    -- ★脚本分支 (在主脚本里加载其它脚本)
    ExtScripts           = {},       -- 自定义脚本列表 { {name=..., url=..., enabled=...}, ... }

    -- ★管理员检测自动退出
    Admin_AutoLeave   = false,   -- 检测到管理员自动把自己踢出 (默认关, 危险操作手动开)
    Admin_GroupId     = 0,       -- 管理员所在群组 GroupId (0=不按群组判定)
    Admin_MinRank     = 100,     -- 群组 rank >= 此值即视为管理员 (255=群主, 通常 >=100)
    Admin_Names       = {},      -- 额外管理员名字名单 (精确匹配)
    Admin_Diagnose    = false,   -- 诊断模式: 打印玩家可识别管理标志到控制台(F9)


    -- ★有人投票踢我时的提醒
    Warn_OnVoted         = true,

    -- ★白名单 (手动保护名单, 比好友列表可靠)
    Whitelist            = {},       -- 从配置读取, 面板可增删

    -- ★显示/隐藏快捷键 (Obsidian 窗口最小化 + 此键切换窗口)
    HOTKEY               = "T",
}

-- ★配置文件路径 (仅持久化白名单动态数据; 其余 UI 状态由 Obsidian 自带保存)
local CONFIG_FILE = "EGG_config.json"

--//===================================================== 状态
local STATE = {
    friendSet      = {},        -- 好友名字集合(小写)
    friendLoaded   = false,     -- 好友列表是否已加载
    friendCount    = 0,         -- ★好友真实人数 (1 人 = 1, 不重复计数)
    pickerFrame    = nil,       -- (保留字段, 不再使用)
    pickerActive   = false,     -- (保留字段, 不再使用)
    kickEnabled    = false,     -- 踢人开关状态

    voteStatus     = {},        -- {[playerName] = {votes=n, need=n}} 从服务端事件同步
    kickExclude    = {},        -- ★"即将离开"排除表: 票数到阈值的人临时排除, 避免白投票


    -- ★UI 状态 (Obsidian 接管)
    tab            = "combat",  -- 当前标签页
    collapsed      = false,     -- 是否已收进标题栏 (Obsidian 窗口最小化)
    destroyed      = false,     -- 是否已彻底销毁
    startupSound   = nil,       -- ★开场音效单例 (复用同一 Sound, 防止试听叠加)
}

--//===================================================== 配置持久化 (仅白名单动态数据)
--- ★★ 执行器函数探测 (关键修复) ★★
--
-- 【问题】之前用 `_G.getcustomasset` 这种"只看 _G 表"的写法去判断函数有没有,
--   结果是**误报**: 多数执行器把 UNC 函数注入到**脚本环境全局**(直接写 getcustomasset
--   就能调), 但它们**不一定挂在 _G 表上**。查 _G 查不到 → 错误地报告"缺少关键函数"。
--
--   铁证就在本脚本里: 第 140 行 hasFs() 用的是裸名字 `type(writefile)` —— 一直工作正常;
--   而自检里写的是 `_G.writefile` —— 同一个函数却报"没有"。错的显然是取法, 不是执行器。
--
-- 【正确做法】按优先级多路径探测, 任一命中即算"有":
--   ① 环境全局 (裸名字) —— 执行器最通用的注入位置, 用 pcall 里直接引用触发
--   ② _G 表
--   ③ 常见执行器专属表 (syn / krnl / 等)
--   用 type(f) == "function" 判定, 拿到的就是可调用引用。
local function probeFunc(...)
    local names = { ... }
    for _, n in ipairs(names) do
        -- ① 环境全局: 在 pcall 里用 getfenv 取, 避免直接写未定义名导致的静态告警
        local ok, f = pcall(function()
            local env = getfenv and getfenv(1) or nil
            if env then return env[n] end
            return nil
        end)
        if ok and type(f) == "function" then return f end

        -- ② _G 表 (部分执行器把函数挂这里)
        local g = (type(_G) == "table") and _G[n] or nil
        if type(g) == "function" then return g end

        -- ③ 执行器专属表
        for _, tname in ipairs({ "syn", "krnl", "Krnl", "secure_call" }) do
            local t = (type(_G) == "table") and _G[tname] or nil
            if type(t) == "table" and type(t[n]) == "function" then return t[n] end
        end
    end
    return nil
end
UI_Refs = UI_Refs or {}
UI_Refs.probeFunc = probeFunc

local function hasFs()
    return type(probeFunc("writefile")) == "function" and type(probeFunc("readfile")) == "function"
end

--- 加载配置 (只恢复白名单列表; 其余 UI 状态由 Obsidian 自带 ConfigurationSaving 恢复)
local function loadConfig()
    if not hasFs() then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return end
    if type(data.Whitelist) == "table" then
        CONFIG.Whitelist = {}
        for _, n in ipairs(data.Whitelist) do
            if type(n) == "string" then table.insert(CONFIG.Whitelist, n) end
        end
    end
end

--- 保存配置 (只写白名单列表)
local function saveConfig()
    if not hasFs() then return false end
    local data = { Whitelist = CONFIG.Whitelist or {} }
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false end
    return pcall(writefile, CONFIG_FILE, json)
end

--//===================================================== ★ 通知封装 (Obsidian:Notify)
--
-- 保留 notify() 包装, 所有引擎/UI 调用点代码不变, 只把通知外观换成 Obsidian 卡片。
-- ★放在本文件前部: loadFriends/notifyKickDone/引擎/UI 都在它之后定义, 才能把它
--   当成局部 upvalue 捕获 (Lua 局部变量作用域: 被调用函数须声明在调用者之前)。
-- Library 在下方加载并赋值; 加载完成前调用会静默跳过 (不报错)。
local Library = nil
KICK_NOTIFY_TEMPLATES = KICK_NOTIFY_TEMPLATES or {
    "已投票 -- %s",
    "防御护盾已成功防卫 -- %s",
    "已投票 -- %s",
}

local function notify(title, text, duration, kind)
    duration = duration or 3
    if not Library then return end
    pcall(function()
        Library:Notify({ Title = tostring(title or ""), Description = tostring(text or ""), Time = duration })
    end)
    print(string.format("[EGG] [%s] %s%s", tostring(kind or "info"),
        (title and (tostring(title) .. ": ")) or "", tostring(text or "")))
end

local function notifySimple(title, text, kind)
    notify(title, text, 3, kind)
end

--//===================================================== ★ 白名单
--- 判断是否在白名单里 (大小写不敏感)
local function isWhitelisted(player)
    if not player then return false end
    local name = string.lower(player.Name)
    local disp = string.lower(player.DisplayName or "")
    for _, n in ipairs(CONFIG.Whitelist or {}) do
        local ln = string.lower(n)
        if ln == name or (disp ~= "" and ln == disp) then return true end
    end
    return false
end

--- ★在当前服务器里按关键词找人 (前缀匹配优先, 再退化到包含匹配)
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
local function validateServerPlayer(input)
    if type(input) ~= "string" then return false, nil, "输入无效" end
    local kw = string.gsub(input, "^%s*(.-)%s*$", "%1")
    if kw == "" then return false, nil, "不能为空" end
    local klow = string.lower(kw)
    for _, plr in ipairs(Players:GetPlayers()) do
        if string.lower(plr.Name) == klow then
            if plr == LocalPlayer then return false, nil, "不能加自己" end
            return true, plr.Name, ""
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if (plr.DisplayName or "") ~= "" and string.lower(plr.DisplayName) == klow then
            if plr == LocalPlayer then return false, nil, "不能加自己" end
            return true, plr.Name, ""
        end
    end
    local hits = searchServerPlayers(kw)
    if #hits == 1 then
        return true, hits[1].Name, ""
    elseif #hits > 1 then
        return false, nil, string.format("有 %d 个人匹配, 请输入更完整名字", #hits)
    end
    return false, nil, "本服务器里没有这个人"
end

--- ★添加白名单 (会校验是不是本服玩家)
local function addWhitelist(rawName)
    local ok, realName, reason = validateServerPlayer(rawName)
    if not ok then return false, reason end
    local low = string.lower(realName)
    for _, n in ipairs(CONFIG.Whitelist or {}) do
        if string.lower(n) == low then return false, realName .. " 已在白名单里" end
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

--//===================================================== ★好友列表
--- 加载好友列表 (异步)
local function loadFriends()
    STATE.friendSet = {}
    STATE.friendLoaded = false
    task.spawn(function()
        local ok, pages = pcall(function() return Players:GetFriendsAsync(LocalPlayer.UserId) end)
        if not ok or not pages then
            ok, pages = pcall(function() return game.Players:GetFriendsAsync(LocalPlayer.UserId) end)
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
        -- ★说明: 这里统计的是"你账号的好友列表"总人数, 与本服里有没有好友无关。
        --   即使进的服务器里一个好友都没有, 也会显示你账号好友的总数 (故可能是 6 人)。
        notify("好友列表", string.format("已加载你账号的 %d 位好友 (与当前服务器无关)", count), 4, "success")
    end)
end

--- 判断是否为好友
local function isFriend(player)
    if not player then return false end
    if player == LocalPlayer then return true end
    local name = string.lower(player.Name)
    local disp = string.lower(player.DisplayName or "")
    if STATE.friendSet[name] or (disp ~= "" and STATE.friendSet[disp]) then return true end
    -- 未加载完时, 保守起见: 如果是好友关系可以额外用 IsFriendsWith 检查
    if not STATE.friendLoaded then
        local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(player.UserId) end)
        if ok and res then return true end
    end
    return false
end

--//===================================================== ★ 音效 (仅保留踢人提示音)
--- ★通用音效播放 (每个音效独立实例, 避免互相打断)
local function playSound(key, soundId, volume, pitch)
    if not soundId or soundId == "" then return end
    pcall(function()
        local cache = STATE.sounds or {}
        STATE.sounds = cache
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

--- ★UI 点击音效 (开关/按钮/滑块等交互反馈)
--- kind: "ToggleOn" / "ToggleOff" / "Button" / "Slider"  (默认 Button)
--- 每个 kind 用独立音高, 让不同操作听起来有区别。
local function playClickSound(kind)
    if not CONFIG.UI_ClickSound then return end
    local now = os.clock()
    -- 滑块连发节流更宽松 (避免拖动时噪音轰炸); 其它操作只需防抖
    local gap = (kind == "Slider") and 0.06 or 0.04
    if STATE.lastClick and (now - STATE.lastClick) < gap then return end
    STATE.lastClick = now

    local pack = CONFIG.UI_SoundPack or {}
    local s = pack[kind] or pack.Button or { id = CONFIG.Click_SoundId, vol = CONFIG.Click_SoundVolume or 0.4, pitch = 1.25 }
    playSound("Click_" .. tostring(kind or "Button"), s.id or CONFIG.Click_SoundId,
        math.min(1, s.vol or CONFIG.Click_SoundVolume or 0.4), s.pitch or 1)

    -- ★触摸震动反馈 (移动端): 轻微震一下, 更有实体按键感
    if CONFIG.UI_Haptic and kind ~= "Slider" then
        -- HapticService:SetMotor 的可震动设备类型只有 Gamepad1~4 与 VibrationMotor,
        -- 桌面/移动端没有马达 -> 会抛 "cannot be used" 之类错误, 所以整段必须 pcall 包住。
        pcall(function()
            local Haptic = game:GetService("HapticService")
            if not Haptic then return end
            local Types = Enum and Enum.HapticEffectType
            Haptic:SetMotor(Enum.UserInputType.Gamepad1, (Types and Types.Custom) or "Custom", 0.35)
            task.delay(0.05, function()
                pcall(function() Haptic:SetMotor(Enum.UserInputType.Gamepad1, (Types and Types.Custom) or "Custom", 0) end)
            end)
        end)
    end
end

--- ★开关专用: 根据新状态(auto 开/关)选择音效
local function playToggleSound(isOn)
    playClickSound(isOn and "ToggleOn" or "ToggleOff")
end

--- ★滑块专用音效 (最轻)
local function playSliderSound()
    playClickSound("Slider")
end

--- ★开启动画音效 (脚本加载完成 / 面板首次弹出时播放)
local function playStartupSound()
    if not CONFIG.Startup_Sound then return end
    pcall(function()
        -- ★单例: 复用同一个 Sound, 播放前先停掉上一个, 避免连点试听时多个音效叠加成噪音
        local snd = STATE.startupSound
        if not snd or not snd.Parent then
            snd = Instance.new("Sound")
            snd.Name = "EGG_StartupSound"
            snd.Looped = false
            snd.Parent = SoundService
            STATE.startupSound = snd
        end
        if snd.IsPlaying then snd:Stop() end   -- ★先停上一条, 再播新的
        snd.SoundId = CONFIG.Startup_SoundId
        snd.Volume = CONFIG.Startup_SoundVolume or 0.5
        snd.TimePosition = 0
        snd:Play()
    end)
end

--- ★有人投票踢我时的警告 (Obsidian 通知卡片)
local function showVoteWarning(initiatorName, votes, need)
    if not CONFIG.Warn_OnVoted then return end
    local who = initiatorName or "有人"
    local text
    if votes and need and need > 0 then
        text = string.format("!! %s 正在投票踢你  (%d/%d)", who, votes, need)
    else
        text = string.format("!! %s 正在投票踢你", who)
    end
    notify("被投票警告", text, 4, "error")
end

--- 踢人成功后的统一通知 (随机文案 + 提示音)
local function notifyKickDone(targetName)
    if not CONFIG.Kick_Notify then return end
    local key = string.lower(tostring(targetName))
    local last = STATE.lastKickNotify and STATE.lastKickNotify[key]
    if last and (os.clock() - last) < 1.0 then return end
    STATE.lastKickNotify = STATE.lastKickNotify or {}
    STATE.lastKickNotify[key] = os.clock()
    local tpl = KICK_NOTIFY_TEMPLATES[math.random(1, #KICK_NOTIFY_TEMPLATES)]
    notify("投票已提交", "已投票 -- " .. tostring(targetName), 2.5, "kick")
    playKickSound()
end

--//===================================================== 引擎逻辑 (原样保留)
--- 判断是否可以动手 (不是好友、不在白名单、不是同队才可以)
local function canTarget(player)
    if not player or player == LocalPlayer then return false end
    if CONFIG.AntiKick_ProtectFriend and isFriend(player) then return false end
    if isWhitelisted(player) then return false end
    return true
end

--- 获取可动手的目标列表
local function getTargets(requireAlive)
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if canTarget(plr) then
            if requireAlive then
                local char = plr.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then table.insert(list, plr) end
            else
                table.insert(list, plr)
            end
        end
    end
    return list
end

--//===================== 投票踢人 (真实接口)
local VOTEKICK_CONFIG = {
    InvokePath  = {"Requests", "RequestVoteKick"},
    SignalPath  = {"SelectiveReplication", "VoteKick"},
}

--- 定位投票 RemoteFunction
local function getVoteFunc()
    local ok, svc = pcall(function() return game:GetService("ReplicatedStorage") end)
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
    local ok, svc = pcall(function() return game:GetService("ReplicatedStorage") end)
    if not ok or not svc then return nil end
    local cur = svc
    for _, seg in ipairs(VOTEKICK_CONFIG.SignalPath) do
        cur = cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end

STATE.voteCooldown = STATE.voteCooldown or {}
STATE.voteBoard = STATE.voteBoard or {}
STATE.pendingVote = nil
local VOTE_COOLDOWN = 30

--- 现在能不能对这个人发起投票?
local function canVoteNow(target)
    if not target then return false, "目标无效" end
    local key = string.lower(target.Name)
    local last = STATE.voteCooldown[key]
    if last then
        local left = VOTE_COOLDOWN - (os.clock() - last)
        if left > 0 then return false, string.format("冷却中 (还需 %.0f 秒)", left) end
    end
    local board = STATE.voteBoard[key]
    if board and board.threshold and board.threshold > 0
       and board.votes and board.votes >= board.threshold then
        return false, "票数已满, 正在踢出"
    end
    return true, ""
end

--- 记录一次成功投票
local function recordVote(target)
    if not target then return end
    STATE.voteCooldown[string.lower(target.Name)] = os.clock()
    STATE.pendingVote = nil
end

--- 解析 RemoteFunction 返回值
local function interpretVoteResult(res, target)
    if res == nil then return true, "" end
    if type(res) == "boolean" then return res, res and "" or "服务端拒绝" end
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
        if res == "" or low == "ok" or low == "success" or low == "true" then return true, "" end
        return true, ""
    end
    if type(res) == "table" then
        if res.success ~= nil then return res.success == true, tostring(res.message or res.error or "") end
        if res.ok ~= nil then return res.ok == true, tostring(res.error or "") end
        if res.accepted ~= nil then return res.accepted == true, tostring(res.reason or "") end
        if res.error ~= nil then return false, tostring(res.error) end
        return true, ""
    end
    return true, ""
end

--- 对指定玩家发起投票踢出
local function voteKick(target)
    if not target or target == LocalPlayer then return false end
    if CONFIG.AntiKick_ProtectFriend and isFriend(target) then
        notify("踢人被阻止", target.Name .. " 是你的好友", 3, "warn")
        return false
    end
    if isWhitelisted(target) then
        notify("踢人被阻止", target.Name .. " 在白名单里", 3, "warn")
        return false
    end
    local ok, reason = canVoteNow(target)
    if not ok then return false, reason end
    local voteFunc = getVoteFunc()
    if voteFunc and voteFunc:IsA("RemoteFunction") then
        local callOk, res = pcall(function() return voteFunc:InvokeServer(target.Name) end)
        if callOk then
            local accepted, why = interpretVoteResult(res, target)
            if accepted then
                notifyKickDone(target.Name)
                recordVote(target)
                return true
            else
                return false, why
            end
        end
    end
    local voteEvent = getVoteEvent()
    if voteEvent and voteEvent:IsA("RemoteEvent") then
        local sendOk = pcall(function() voteEvent:FireServer(target.Name) end)
        if sendOk then
            STATE.pendingVote = { name = target.Name, at = os.clock() }
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
            STATE.pendingVote = nil
            return false, "no-confirm"
        end
    end
    notify("投票接口异常", "未找到投票接口, 请确认游戏版本", 4, "error")
    return false, "no-interface"
end

--- 读取当前投票状态
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

--//===================== ★ 投票状态监听
local voteListenerConn = nil
local function startVoteListener()
    if voteListenerConn then return end
    local voteEvent = getVoteEvent()
    if not voteEvent or not voteEvent:IsA("RemoteEvent") then
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
            STATE.voteBoard[string.lower(name)] = {votes = votes or 0, threshold = threshold or 0}
            if STATE.pendingVote
               and string.lower(STATE.pendingVote.name) == string.lower(name) then
                STATE.pendingVote = nil
            end
            if target == LocalPlayer then
                local initName = initiator and initiator.Name or "有人"
                showVoteWarning(initName, votes, threshold)
            end
            if threshold and votes and votes >= threshold then
                STATE.kickExclude[name] = tick() + 9999
            end
        elseif action == "End" or action == "Cancel" or action == "Finish" then
            local n = target and target.Name or nil
            if n then
                STATE.voteStatus[n] = nil
                STATE.voteBoard[string.lower(n)] = nil
                if STATE.kickExclude[n] and STATE.kickExclude[n] > tick() + 9000 then
                    STATE.kickExclude[n] = tick() + 8
                end
            end
        end
    end)
end

--//===================== ★ 自动踢人目标选择
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

--//===================== ★ 自动循环踢人
local function startAutoKick()
    if STATE.autoKickLoop then return end
    STATE.autoKickLoop = task.spawn(function()
        while CONFIG.AntiKick_AutoKick do
            if CONFIG.AntiKick_Enabled then
                local t = pickKickTarget(false)
                if t then voteKick(t) end
            end
            task.wait(CONFIG.AntiKick_KickInterval)
        end
        STATE.autoKickLoop = nil
    end)
end

local function stopAutoKick()
    CONFIG.AntiKick_AutoKick = false
end

--//===================== ★ 管理员检测自动退出
--- 判定某玩家是否为管理员 (多信号: 群组 rank / 名字名单 / 角色内 Admin 标记)
--- ★注意: FindFirstChild 找不到时返回 nil 但仍算 pcall 成功, 必须取返回值再判空,
---   不能直接 if pcall(...) (那会让所有玩家都被判为管理员 -> 立刻误踢自己)。
local ADMIN_MARKERS = {"Admin", "IsAdmin", "AdminTag", "Administrator"}
local function hasMarker(inst, name)
    if not inst then return false end
    local ok, child = pcall(function() return inst:FindFirstChild(name) end)
    return ok and child ~= nil
end
local function isAdminPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    -- 1) 群组 rank 判定 (仅当填了群组 ID 才启用)
    if CONFIG.Admin_GroupId and CONFIG.Admin_GroupId > 0 then
        local ok, rank = pcall(function() return plr:GetRoleInGroup(CONFIG.Admin_GroupId) end)
        -- GetRoleInGroup 返回的是字符串角色名, 需用 GetRankInGroup 取数字段位
        local ok2, num = pcall(function() return plr:GetRankInGroup(CONFIG.Admin_GroupId) end)
        if ok2 and type(num) == "number" and num >= (CONFIG.Admin_MinRank or 100) then return true end
        if ok and type(rank) == "string" then
            -- 个别执行器/私服返回 "角色名", 无法比较数字, 忽略即可
        end
    end
    -- 2) 名字名单 (精确匹配)
    if CONFIG.Admin_Names then
        for _, n in ipairs(CONFIG.Admin_Names) do
            if n == plr.Name then return true end
        end
    end
    -- 3) 角色内标记 (仅精确匹配少数明确的管理标识; 不用 "Rank"/"VIP" 这类常见名, 避免误判)
    local char = nil
    pcall(function() char = plr.Character end)
    for _, m in ipairs(ADMIN_MARKERS) do
        if hasMarker(plr, m) then return true end
        if hasMarker(char, m) then return true end
    end
    return false
end

--- 启动管理员监控 (每 0.1 秒扫描全服; 仅当开关开启时才真正运行)
local function startAdminWatch()
    if STATE.adminWatch then return end
    STATE.adminWatch = task.spawn(function()
        while CONFIG.Admin_AutoLeave and not STATE.destroyed do
            local hit = nil
            for _, plr in ipairs(Players:GetPlayers()) do
                if isAdminPlayer(plr) then hit = plr; break end
            end
            if hit then
                -- ★二次确认: 先警告 + 3 秒倒计时, 期间管理员离开/开关关闭则取消, 避免误判瞬间踢人
                local name = tostring(hit.Name)
                notify("管理员检测", "⚠ 疑似管理员进入: " .. name .. " -- 3 秒后自动退出 (可立刻关闭本开关取消)", 4, "warn")
                local cancelled = false
                for i = 3, 1, -1 do
                    task.wait(1)
                    if STATE.destroyed or not CONFIG.Admin_AutoLeave then cancelled = true break end
                    if not isAdminPlayer(hit) then cancelled = true break end   -- 对方已离开/标记消失
                end
                if not cancelled and CONFIG.Admin_AutoLeave and not STATE.destroyed and isAdminPlayer(hit) then
                    pcall(function()
                        notify("管理员检测", "确认管理员 -- " .. name .. " | 自动退出", 6, "error")
                        LocalPlayer:Kick("EGG: 检测到管理员 " .. name .. ", 已自动退出以保护账号")
                    end)
                    break
                end
            end
            task.wait(0.1)
        end
        STATE.adminWatch = nil
    end)
end

--- 诊断: 打印某玩家可被客户端识别的管理标志 (帮用户确定用哪种判定依据)
local function diagnosePlayer(plr)
    if not plr then return end
    local lines = {"[EGG诊断] 玩家 " .. tostring(plr.Name)}
    local ok, groups = pcall(function() return plr:GetGroups() end)
    if ok and groups then
        for _, g in ipairs(groups) do
            table.insert(lines, string.format("  群%d | %s | rank=%d", g.Id or 0, tostring(g.Name), g.Rank or 0))
        end
    else
        table.insert(lines, "  群组: 获取失败(" .. tostring(groups) .. ")")
    end
    pcall(function()
        for _, c in ipairs(plr:GetChildren()) do
            table.insert(lines, "  玩家:" .. c.ClassName .. ":" .. c.Name)
        end
    end)
    local char = pcall(function() return plr.Character end) and plr.Character
    if char then
        pcall(function()
            for _, c in ipairs(char:GetChildren()) do
                table.insert(lines, "  角色:" .. c.ClassName .. ":" .. c.Name)
            end
        end)
    end
    local msg = table.concat(lines, "\n")
    print(msg)
    pcall(function() notify("管理员诊断", plr.Name .. " 信号已打印到控制台(F9)", 4, "info") end)
end

--//===================================================== ★ 检测引擎 (命中率 / 反作弊识别)
-- 设计原则: 只读、只标记, 不替你操作、不给任何战斗优势。
--   统计每个对手的『射击次数』与『命中次数』, 命中率 = 命中 / 射击。
--   命中率 ≥ 阈值(默认 80%) 且 射击次数 ≥ 最少射击数(默认 10, 防偶然高命中) 的对手,
--   被列入『检测榜』并弹提醒, 显示其 昵称(Name) 与 显示名(DisplayName)。
-- ★ 不检测队友: 同队玩家(开 Detection_IgnoreTeam)的命中不计入、也不上榜。
-- ★ 数据来源: 由《血与铁》的战斗事件喂入 (见本段底部 ★接入点)。本引擎只统计与展示。

-- ★配置保底 (主 CONFIG 里也要有, 这里再 or 一次防止被清)
CONFIG.Detection_Enabled    = CONFIG.Detection_Enabled    or true
CONFIG.Detection_Threshold  = CONFIG.Detection_Threshold  or 80
CONFIG.Detection_MinShots   = CONFIG.Detection_MinShots   or 10
CONFIG.Detection_IgnoreTeam = CONFIG.Detection_IgnoreTeam or true

local Players     = nil
local LocalPlayer = nil
pcall(function() Players = game:GetService("Players") end)
pcall(function() if Players then LocalPlayer = Players.LocalPlayer end end)

STATE.detection = STATE.detection or {}   -- [userId] = {shots, hits, name, display, team, flagged}
local detectionFlaggedOrder = {}          -- 已上检测榜的 userId 顺序(用于展示与去重)

local function detectionGetEntry(userId)
    if userId == nil then return nil end
    local uid = tostring(userId)
    local e = STATE.detection[uid]
    if not e then e = { shots = 0, hits = 0, name = "?", display = "?", team = nil, flagged = false } STATE.detection[uid] = e end
    return e
end

local function detectionSameTeam(a, b)
    if not (a and b) or a == b then return a == b and a ~= nil end
    local ta, tb = nil, nil
    pcall(function() ta = a.Team end); pcall(function() tb = b.Team end)
    if ta and tb then return ta == tb end
    pcall(function() ta = a.TeamColor end); pcall(function() tb = b.TeamColor end)
    if ta and tb then return ta == tb end
    return false
end

local function detectionRefreshPlayer(plr)
    if not plr then return end
    local e = detectionGetEntry(plr.UserId)
    pcall(function() e.name = plr.Name end)
    pcall(function() e.display = plr.DisplayName end)
    pcall(function() e.team = plr.Team end)
end

-- ★ 队伍过滤核心: 开枪/命中者若是『本地玩家同队(含自己)』则整条丢弃, 只统计敌人(对面)数据
local function detectionIsTeammateOfLocal(userId)
    if not (CONFIG.Detection_IgnoreTeam and Players and LocalPlayer) then return false end
    if not userId then return false end
    local p = nil
    pcall(function() p = Players:GetPlayerByUserId(userId) end)
    if not p then return false end
    return detectionSameTeam(p, LocalPlayer)  -- 含自己(a==b 时返回 true)
end

local function detectionNoteShot(userId)
    if detectionIsTeammateOfLocal(userId) then return end  -- 队友(含自己)开枪不统计
    local e = detectionGetEntry(userId); if e then e.shots = e.shots + 1 end
end

local function detectionNoteHit(attackerId, victimId)
    if not attackerId then return end
    if detectionIsTeammateOfLocal(attackerId) then return end  -- 队友(含自己)命中不统计, 无论打谁
    local e = detectionGetEntry(attackerId); if e then e.hits = e.hits + 1 end
end

local function detectionTick()
    if not CONFIG.Detection_Enabled then return end
    local thr = tonumber(CONFIG.Detection_Threshold) or 80
    local minShots = tonumber(CONFIG.Detection_MinShots) or 10
    for uid, e in pairs(STATE.detection) do
        if e.shots >= minShots then
            local rate = (e.hits / e.shots) * 100
            if rate >= thr and not e.flagged then
                e.flagged = true
                table.insert(detectionFlaggedOrder, uid)
                local who = (e.display and e.display ~= "") and e.display or e.name
                notify("检测", "⚠ 命中率异常: " .. tostring(who) .. " (@" .. tostring(e.name) .. ") — " .. string.format("%.0f", rate) .. "% (" .. e.hits .. "/" .. e.shots .. ")", 6, "error")
            end
        end
    end
end

local function detectionGetList()
    local out = {}
    for _, uid in ipairs(detectionFlaggedOrder) do
        local e = STATE.detection[uid]
        if e and e.flagged then
            local rate = (e.shots > 0) and (e.hits / e.shots) * 100 or 0
            local who = (e.display and e.display ~= "") and e.display or e.name
            table.insert(out, "⚠ " .. tostring(who) .. "  ·  @" .. tostring(e.name) .. "  ·  " .. string.format("%.0f", rate) .. "%  (" .. e.hits .. "/" .. e.shots .. ")")
        end
    end
    return out
end

local function detectionClear()
    STATE.detection = {}
    detectionFlaggedOrder = {}
    notify("检测", "已清空检测榜", 2.5, "info")
end

local function detectionConnect()
    if not Players then return end
    pcall(function() Players.PlayerAdded:Connect(detectionRefreshPlayer) end)
    pcall(function() for _, p in ipairs(Players:GetPlayers()) do detectionRefreshPlayer(p) end end)
    pcall(function() Players.PlayerRemoving:Connect(function(p)
        local e = STATE.detection[tostring(p.UserId)]; if e then e.left = true end
    end) end)
    notify("检测", "已连接玩家名单 — 把战斗事件接到 Detection.noteShot/noteHit 后开始统计 (见脚本 ★接入点)", 4, "info")
end

--[[ ★ 接入点 (把《血与铁》的战斗事件接到这里)
   本引擎只统计, 不读游戏逻辑。要让『命中率』有数据, 你需要找到游戏里的:
     ① 玩家开枪的事件  →  UI_Refs.detectionNoteShot(开枪者UserId)
     ② 命中玩家的事件  →  UI_Refs.detectionNoteHit(攻击者UserId, 受害者UserId)
     ③ 本地玩家造成伤害(右上角反馈) →  UI_Refs.hitFeedbackNote(LocalPlayer.UserId, 受害者UserId, 伤害值, 是否近战)
        --   伤害值可传 nil (游戏事件没给伤害时, 提示里显示『扣血: ?』); 是否近战: 子弹=false / 近战=true
   常见做法 (需按实际游戏事件名调整, 每个游戏不同):
     local RS = game:GetService("ReplicatedStorage")
     -- 例: 服务器向客户端广播『某玩家命中某玩家』
     local dmg = RS:FindFirstChild("Damage") or RS:FindFirstChild("Hit")
     if dmg then dmg.OnClientEvent:Connect(function(atkId, vicId) UI_Refs.detectionNoteHit(atkId, vicId) end) end
     -- 例: 本地玩家开枪 (监听自己的武器 RemoteEvent / 工具激活)
     -- (你的武器开火时) UI_Refs.detectionNoteShot(game.Players.LocalPlayer.UserId)
   找不到事件名时: 开着检测进游戏打两局, 看『检测榜』是否变化; 一直为空 = 还没接上。
   接上后, 命中率 ≥ 阈值的对手会自动上榜并提醒, 显示其 昵称 + 显示名。
--]]

UI_Refs = UI_Refs or {}
UI_Refs.detectionTick           = detectionTick
UI_Refs.detectionGetList        = detectionGetList
UI_Refs.detectionNoteShot       = detectionNoteShot
UI_Refs.detectionNoteHit        = detectionNoteHit
UI_Refs.detectionConnect        = detectionConnect
UI_Refs.detectionClear          = detectionClear
UI_Refs.detectionRefreshPlayer  = detectionRefreshPlayer

pcall(function()
    detectionConnect()
    if type(task) == "table" and type(task.spawn) == "function" then
        task.spawn(function()
            while true do
                pcall(function() task.wait(1) end)
                pcall(function()
                    if CONFIG.Detection_Enabled then
                        detectionTick()
                        local cb = UI_Refs.__detectListLabel
                        if cb and type(cb.SetText) == "function" then
                            local l = detectionGetList()
                            cb:SetText((#l == 0) and "（检测榜为空 — 等待战斗数据）" or table.concat(l, "\n"))
                        end
                    end
                end)
            end
        end)
    end
end)

-- ★ 击中提示 (本地玩家命中反馈, 右上角)
--
-- ★ 用途: 反馈『你打中敌人没有』——这游戏有时不确定子弹有没有打中。
--   只处理『本地玩家(LocalPlayer)打中敌人』, 队友不提示; 子弹用踢人音效, 近战不发声。
-- ★ 接入: 把游戏里『本地玩家造成伤害』的事件接到 UI_Refs.hitFeedbackNote(LocalPlayer.UserId, 受害者UserId, 伤害值, 是否近战)
--   ① 子弹击中: isMelee=false → 文案「子弹已击中对面」, 播放踢人音效
--   ② 近战击中: isMelee=true  → 文案「已打中对面」, 不发声; 提示栏最多同时 1 个, 排队显示
local hfRoot, hfBulletList, hfMeleeSlot = nil, nil, nil
local hfMeleeQueue, hfMeleeBusy = {}, false

local function buildHitFeedbackGui()
    if hfRoot then return end
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
        hfRoot = Instance.new("ScreenGui")
        hfRoot.Name = "EGG_HitFeedback"
        hfRoot.ResetOnSpawn = false
        hfRoot.Enabled = true
        hfRoot.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        hfRoot.Parent = pg

        local root = Instance.new("Frame", hfRoot)
        root.Name = "Root"; root.BackgroundTransparency = 1
        root.Size = UDim2.new(0, 280, 1, 0); root.Position = UDim2.new(1, -12, 0, 12)
        root.AnchorPoint = Vector2.new(1, 0)
        local rl = Instance.new("UIListLayout", root)
        rl.SortOrder = Enum.SortOrder.LayoutOrder; rl.VerticalAlignment = Enum.VerticalAlignment.Top
        rl.HorizontalAlignment = Enum.HorizontalAlignment.Right; rl.Padding = UDim.new(0, 6)

        hfBulletList = Instance.new("Frame", root)
        hfBulletList.Name = "BulletList"; hfBulletList.BackgroundTransparency = 1
        hfBulletList.Size = UDim2.new(1, 0, 0, 0); hfBulletList.AutomaticSize = Enum.AutomaticSize.Y
        hfBulletList.LayoutOrder = 1
        local bl = Instance.new("UIListLayout", hfBulletList)
        bl.SortOrder = Enum.SortOrder.LayoutOrder; bl.VerticalAlignment = Enum.VerticalAlignment.Top
        bl.HorizontalAlignment = Enum.HorizontalAlignment.Right; bl.Padding = UDim.new(0, 6)

        hfMeleeSlot = Instance.new("TextLabel", root)
        hfMeleeSlot.Name = "MeleeSlot"; hfMeleeSlot.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
        hfMeleeSlot.BackgroundTransparency = 0.12; hfMeleeSlot.BorderSizePixel = 0
        hfMeleeSlot.Size = UDim2.new(1, 0, 0, 0); hfMeleeSlot.AutomaticSize = Enum.AutomaticSize.Y
        hfMeleeSlot.TextWrapped = true; hfMeleeSlot.RichText = true
        hfMeleeSlot.TextXAlignment = Enum.TextXAlignment.Right; hfMeleeSlot.TextColor3 = Color3.fromRGB(150, 220, 255)
        hfMeleeSlot.Font = Enum.Font.Gotham; hfMeleeSlot.TextSize = 14
        hfMeleeSlot.LayoutOrder = 2; hfMeleeSlot.Visible = false
        Instance.new("UICorner", hfMeleeSlot).CornerRadius = UDim.new(0, 6)
    end)
end

local function hfMakeToast(parent, text, color)
    local lbl = Instance.new("TextLabel", parent)
    lbl.BackgroundColor3 = Color3.fromRGB(18, 22, 30); lbl.BackgroundTransparency = 0.12
    lbl.BorderSizePixel = 0; lbl.Size = UDim2.new(1, 0, 0, 0); lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.TextWrapped = true; lbl.RichText = true; lbl.TextXAlignment = Enum.TextXAlignment.Right
    lbl.TextColor3 = color; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 14; lbl.Text = text
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 6)
    return lbl
end

local function hfShowBullet(text, color)
    buildHitFeedbackGui(); if not hfBulletList then return end
    local kids = hfBulletList:GetChildren()
    local n = 0
    for _, c in ipairs(kids) do if c:IsA("TextLabel") then n = n + 1 end end
    if n >= 5 then
        for _, c in ipairs(kids) do
            if c:IsA("TextLabel") then pcall(function() c:Destroy() end); break end
        end
    end
    local lbl = hfMakeToast(hfBulletList, text, color)
    pcall(function() game:GetService("Debris"):AddItem(lbl, 1.2) end)
end

local function hfProcessMelee()
    if #hfMeleeQueue == 0 then hfMeleeBusy = false; if hfMeleeSlot then hfMeleeSlot.Visible = false end return end
    hfMeleeBusy = true
    local item = table.remove(hfMeleeQueue, 1)
    if hfMeleeSlot then hfMeleeSlot.Text = item; hfMeleeSlot.Visible = true end
    if type(task) == "table" and type(task.delay) == "function" then
        task.delay(1.2, function()
            if hfMeleeSlot then hfMeleeSlot.Visible = false end
            hfProcessMelee()
        end)
    else
        hfMeleeBusy = false
    end
end

local function hfShowMelee(text, color)
    buildHitFeedbackGui(); if not hfMeleeSlot then return end
    table.insert(hfMeleeQueue, text)
    if not hfMeleeBusy then hfProcessMelee() end
end

-- ★ 主入口: 本地玩家打中敌人时调用 (attackerId 必须是 LocalPlayer.UserId)
--   参数: attackerId(开枪/攻击者UserId), victimId(受害者UserId), damage(扣血, 可空), isMelee(是否近战)
local function hitFeedbackNote(attackerId, victimId, damage, isMelee)
    if not CONFIG.HitFeedback_Enabled and not CONFIG.HitFeedback_Melee then return false end
    if attackerId ~= LocalPlayer.UserId then return false end           -- 只反馈『自己』打的
    if isMelee then
        if not CONFIG.HitFeedback_Melee then return false end           -- 近战开关关 -> 不提示
    else
        if not CONFIG.HitFeedback_Enabled then return false end         -- 子弹总开关关 -> 不提示
    end
    -- 队友不提示 (与检测一致: 只对敌人反馈)
    if CONFIG.Detection_IgnoreTeam then
        local vic = nil
        pcall(function() vic = Players:GetPlayerByUserId(victimId) end)
        if vic and detectionSameTeam(vic, LocalPlayer) then return false end
    end
    local disp, name = "?", "?"
    pcall(function()
        local v = Players:GetPlayerByUserId(victimId)
        if v then disp = v.DisplayName or "?"; name = v.Name or "?" end
    end)
    local dmgTxt = (type(damage) == "number") and tostring(damage) or "?"
    local head = isMelee and "已打中对面" or "子弹已击中对面"
    local color = isMelee and Color3.fromRGB(150, 220, 255) or Color3.fromRGB(255, 220, 120)
    local text = string.format("%s\n名字: %s (@%s)\n扣血: %s", head, tostring(disp), tostring(name), dmgTxt)
    if isMelee then hfShowMelee(text, color) else hfShowBullet(text, color) end
    if not isMelee then playSound("HitFeedback", CONFIG.Kick_SoundId, CONFIG.Kick_SoundVolume, 1) end  -- 子弹用踢人音效; 近战不发声
    return true
end
UI_Refs.hitFeedbackNote = hitFeedbackNote

--//===================================================== 加载 Obsidian (UI 库)
--- 依次尝试多个镜像源 + 多种取网方式, 任一成功即用。
--- 为什么要多源: 部分执行器/网络环境屏蔽 GitHub 直连, 单源会导致整个 UI 建不出来。
local function loadObsidian()
    -- ★多镜像 (依次尝试, 前面的挂了自动换下一个)
    local urls = {
        "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua",
        "https://cdn.jsdelivr.net/gh/deividcomsono/Obsidian@main/Library.lua",
        "https://ghproxy.net/https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua",
        "https://gh-proxy.com/https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua",
        "https://raw.gitmirror.com/deividcomsono/Obsidian/main/Library.lua",
    }

    -- ★多种取网方式 (优先执行器 request, 退回 HttpGet)
    local function httpGet(url, useCache)
        local req = probeFunc("request", "http_request", "httprequest", "syn_request")
        if req then
            local ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
            if ok and type(res) == "table" and type(res.Body) == "string" and res.Body ~= ""
               and (res.StatusCode or 200) < 400 then
                return res.Body
            end
        end
        local ok2, body = pcall(function() return game:HttpGet(url, useCache) end)
        if ok2 and type(body) == "string" and body ~= "" then return body end
        return nil
    end

    for i, url in ipairs(urls) do
        local ok, lib = pcall(function()
            local src = httpGet(url, true)
            if not src or src == "" then error("空响应") end
            return loadstring(src)()
        end)
        if ok and type(lib) == "table" then
            print(string.format("[EGG] Obsidian 已加载 (源 %d/%d)", i, #urls))
            return lib
        else
            print(string.format("[EGG] Obsidian 源 %d 失败: %s", i, tostring(lib)))
        end
    end
    return nil
end

loadConfig()          -- ★先读白名单, 让白名单下拉初始选项正确
Library = loadObsidian()
if not Library then
    warn("[EGG] Obsidian 加载失败, UI 无法显示 (后台逻辑仍运行)")
    print("[EGG] 请检查执行器网络或手动替换 Obsidian 源")
    pcall(function() notify("UI 库加载失败", "所有镜像源都不可达; 请检查执行器网络 (需要 HttpGet/request)", 8, "error") end)
end

--//===================================================== 反踢护盾 (Anti-Kick Shield)
--- 把你贴的那份 __namecall 反踢片段加固后内置为【可开关】模块。
--- 防御性: 仅拦截游戏反作弊/踢人远程对本地的调用, 不改动任何游戏状态, 不提供任何玩法优势。
--- 与原版行为一致:
---   ① 拦下 RequestPlayerKick 等踢人远程的 FireServer / InvokeServer
---   ② 拦下反作弊脚本 (LocalClean / CharacterControl) 发起的一切本地调用
---   ③ 循环禁用本机 CharacterControl (防一部分本地踢人)
--- 加固点 (原版会崩, 这里都修了):
---   - 全部判据加 nil 防御 (原版 getcallingscript().Name 在返回 nil 时直接崩)
---   - 钩子主体 xpcall 包裹, 异常绝不外抛 (否则 __namecall 一抛游戏全崩)
---   - 纯计算不 yield, 不递归 FireServer
---   - 主开关 M.enabled: 关掉即全部放行, 无需重启客户端
local AntiKickShield = (function()
    local M = { installed = false, enabled = false }

    -- 环境自检: 需要 UNC 兼容执行器
    local HAVE_UNC = pcall(function()
        return hookmetamethod and checkcaller and getnamecallmethod and getcallingscript
    end)
    if not HAVE_UNC then
        warn("[EGG-反踢] 当前执行器不支持 hookmetamethod / checkcaller, 反踢护盾不可用")
        function M.enable() notify("反踢护盾", "执行器不支持, 无法启用", 3, "error") end
        function M.disable() end
        function M.stats() return { ["可用"] = "否 (执行器不支持)" } end
        return M
    end

    local CFG = {
        -- 反作弊脚本名 (子串 + 不区分大小写)
        blockedNames   = { "localclean", "charactercontrol" },
        -- 踢人远程名 (子串 + 不区分大小写)
        kickRemotes    = { "requestplayerkick", "requestkick", "playerkick" },
        blockKickRemote       = true,
        disableCharacterControl = true,
        loopInterval   = 0.1,   -- 10Hz (原版每帧 60fps 纯浪费)
        debug          = false,
    }
    local STATS = { namecallHits = 0, namecallBlocked = 0, kickBlocked = 0, newindexBlocked = 0, errors = 0 }
    local BLOCKED_SET = {}      -- [脚本实例] = true (改名也认)
    local oldNameCall, oldNewIndex
    local running = false

    local function safeName(inst)
        if not inst then return nil end
        local ok, nm = pcall(function() return inst.Name end)
        if ok and type(nm) == "string" then return nm end
        return nil
    end
    local function nameMatches(name, list)
        if not name or type(name) ~= "string" then return false end
        name = string.lower(name)
        for _, pat in ipairs(list) do
            if string.find(name, pat, 1, true) then return true end
        end
        return false
    end
    local function registerScript(inst)
        if not inst then return end
        local ok, isScript = pcall(function() return inst:IsA("LuaSourceContainer") end)
        if not ok or not isScript then return end
        if BLOCKED_SET[inst] then return end
        if not nameMatches(safeName(inst), CFG.blockedNames) then return end
        BLOCKED_SET[inst] = true
    end

    local function install()
        if M.installed then return end
        -- 初始扫描反作弊脚本 (PlayerGui / ReplicatedStorage / ReplicatedFirst)
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, d in ipairs(pg:GetDescendants()) do registerScript(d) end
                pg.DescendantAdded:Connect(function(d) task.defer(registerScript, d) end)
            end
            local rs = game:GetService("ReplicatedStorage")
            for _, d in ipairs(rs:GetDescendants()) do registerScript(d) end
            local rf = game:GetService("ReplicatedFirst")
            for _, d in ipairs(rf:GetDescendants()) do registerScript(d) end
        end)

        -- ① ② __namecall 钩子
        oldNameCall = hookmetamethod(game, "__namecall", function(self, ...)
            STATS.namecallHits = STATS.namecallHits + 1
            if not M.enabled then return oldNameCall(self, ...) end   -- 主开关关 -> 全放行
            local args = table.pack(...)
            local argc = args.n
            local ok, result = xpcall(function()
                -- ① 拦踢人远程
                if CFG.blockKickRemote then
                    local method = getnamecallmethod()
                    if method == "FireServer" or method == "InvokeServer" then
                        if nameMatches(safeName(self), CFG.kickRemotes) then
                            STATS.kickBlocked = STATS.kickBlocked + 1
                            return ""   -- 返回空串比 {} 安全
                        end
                    end
                end
                -- ② 拦反作弊脚本的本地调用 (只拦非本执行器的)
                if not checkcaller() then
                    local cs = getcallingscript()
                    if cs and (BLOCKED_SET[cs] or nameMatches(safeName(cs), CFG.blockedNames)) then
                        BLOCKED_SET[cs] = true
                        STATS.namecallBlocked = STATS.namecallBlocked + 1
                        return ""
                    end
                end
                return oldNameCall(self, table.unpack(args, 1, argc))
            end, function(err)
                STATS.errors = STATS.errors + 1
                warn("[EGG-反踢] 钩子异常(已兜住, 不影响游戏): " .. tostring(err))
                local ok2, r = pcall(oldNameCall, self, table.unpack(args, 1, argc))
                return ok2 and r or nil
            end)
            return result
        end)

        -- ③ __newindex 钩子 (不转发 = 拦截写入)
        oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
            local ok, block = xpcall(function()
                if not M.enabled or checkcaller() then return false end
                local cs = getcallingscript()
                if not cs then return false end
                if BLOCKED_SET[cs] or nameMatches(safeName(cs), CFG.blockedNames) then
                    BLOCKED_SET[cs] = true
                    return true
                end
                return false
            end, function(err)
                STATS.errors = STATS.errors + 1
                return false
            end)
            if ok and block then
                STATS.newindexBlocked = STATS.newindexBlocked + 1
                return   -- 直接 return, 不碰 oldNewIndex -> 写入被丢弃
            end
            return oldNewIndex(self, key, value)
        end)

        -- ④ CharacterControl 禁用循环 (10Hz, 只在状态变化时写)
        running = true
        task.spawn(function()
            while running do
                pcall(function()
                    if CFG.disableCharacterControl and M.enabled and LocalPlayer.Character then
                        local cc = LocalPlayer.Character:FindFirstChild("CharacterControl")
                        if cc and cc.Disabled ~= true then cc.Disabled = true end
                    end
                end)
                task.wait(CFG.loopInterval)
            end
        end)

        M.installed = true
        print(string.format("[EGG-反踢] ✅ 已安装 | 钩子: __namecall + __newindex | 开关: EGG_AntiKickShield.enable()/.disable()/.stats()"))
    end

    function M.enable()
        install()
        M.enabled = true
        notify("反踢护盾", "已开启 -- 拦截踢人远程 + 反作弊本地调用", 3, "success")
    end
    function M.disable()
        M.enabled = false
        notify("反踢护盾", "已关闭 -- 钩子放行 (重启客户端才彻底移除)", 2.5, "info")
    end
    function M.toggle() if M.enabled then M.disable() else M.enable() end end
    function M.isEnabled() return M.enabled end
    -- 运行时补名单 (万一自动扫描漏了)
    function M.addKickRemote(name) if type(name) == "string" then table.insert(CFG.kickRemotes, string.lower(name)) end end
    function M.addScriptName(name)
        if type(name) ~= "string" then return end
        table.insert(CFG.blockedNames, string.lower(name))
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then for _, d in ipairs(pg:GetDescendants()) do registerScript(d) end end
            for _, d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do registerScript(d) end
        end)
    end
    function M.stats()
        return {
            ["已启用"]            = M.enabled,
            ["钩子已装"]          = M.installed,
            ["namecall 总调用"]   = STATS.namecallHits,
            ["拦下反作弊调用"]     = STATS.namecallBlocked,
            ["拦下踢人请求"]       = STATS.kickBlocked,
            ["拦下属性写入"]       = STATS.newindexBlocked,
            ["钩子内部异常"]       = STATS.errors,
            ["名单内脚本数"]       = (function() local n = 0 for _ in pairs(BLOCKED_SET) do n = n + 1 end return n end)(),
        }
    end
    return M
end)()
_G.EGG_AntiKickShield = AntiKickShield

local Window, PlayerTab, DetectionTab, SettingsTab, BranchTab
local KickToggle, KickIntSlider
local KickNotifyToggle, KickSoundToggle, WarnToggle, WLBox, WLListDropdown
local AdminLeaveToggle, AdminGroupBox, AdminNamesBox
local DetectionEnabledToggle, DetectionThresholdSlider, DetectionMinShotsSlider, DetectionIgnoreTeamToggle
local StartupSoundToggle
local NMSearchBox, NMResultDropdown, NMPlayBtn, NMCustomBox, NMCustomDropdown
local ExtListDropdown   -- (原 ExtUrlBox / ExtRunBtn 随「加载自定义脚本」分区一起删除)
-- ★账号登录 / 接口设置
local NMPhoneBox, NMCodeBox, NMSendSmsBtn, NMConfirmBtn, NMLogoutBtn
local NMAccountPara, NMApiBox, NMQualityDropdown

--//===================================================== ★ 脚本分支 (通用脚本加载器)
-- 说明: 在主脚本里加载并运行其它脚本, 用于把大体积/低频功能从主脚本里剥离出去。

-- 已加载脚本的记录表 (防重复加载)
STATE.loadedScripts = STATE.loadedScripts or {}

-- 取字符串哈希, 用于给脚本做去重键
local function strHash(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + string.byte(s, i)) % 2147483647
    end
    return h
end

--- 统一取 HTTP 内容 (优先执行器 request, 退回 game:HttpGet)
local function fetchUrl(url)
    if type(url) ~= "string" or url == "" then return nil, "地址为空" end

    local req = probeFunc("request", "http_request", "httprequest", "syn_request")
    if req then
        local ok, res = pcall(function()
            return req({ Url = url, Method = "GET" })
        end)
        if ok and type(res) == "table" and type(res.Body) == "string"
           and res.Body ~= "" and (res.StatusCode or 200) < 400 then
            return res.Body
        end
    end

    local ok2, body = pcall(function() return game:HttpGet(url, true) end)
    if ok2 and type(body) == "string" and body ~= "" then return body end
    return nil, "网络请求失败 (执行器不支持或链接不可达)"
end

--- 加载并执行一个远程脚本
-- @param url     脚本地址
-- @param label   显示名 (仅用于提示)
-- @param silent  是否静默 (不弹通知)
local function runRemoteScript(url, label, silent)
    label = label or "脚本"

    -- 去重: 同一个地址默认只跑一次 (避免重复执行导致界面叠加)
    local key = tostring(strHash(tostring(url)))
    if STATE.loadedScripts[key] then
        if not silent then
            notify("脚本分支", string.format("%s 已加载过, 跳过重复执行", label), 3, "info")
        end
        return false, "已加载过"
    end

    -- 取源码
    if not silent then notify("脚本分支", string.format("正在加载 %s ...", label), 2, "info") end
    local body, err = fetchUrl(url)
    if not body then
        notify("脚本分支", string.format("%s 加载失败: %s", label, tostring(err)), 5, "error")
        return false, err
    end

    -- 体积上限保护 (超过 4MB 基本是拿错链接了)
    if #body > 4 * 1024 * 1024 then
        notify("脚本分支", string.format("%s 体积异常 (%d 字节), 已中止", label, #body), 5, "error")
        return false, "体积异常"
    end

    -- 编译
    local chunk, cerr = loadstring(body)
    if not chunk then
        notify("脚本分支", string.format("%s 编译失败 (地址可能不是 Lua 源码)", label), 6, "error")
        print(string.format("[EGG] %s 编译失败: %s", label, tostring(cerr)))
        return false, cerr
    end

    -- 执行 (独立线程, 不阻塞主脚本)
    local ok, rerr = pcall(chunk)
    if not ok then
        notify("脚本分支", string.format("%s 运行出错: %s", label, tostring(rerr)), 6, "error")
        print(string.format("[EGG] %s 运行出错: %s", label, tostring(rerr)))
        return false, rerr
    end

    STATE.loadedScripts[key] = true
    if not silent then
        notify("脚本分支", string.format("%s 已加载 ✅", label), 4, "success")
    end
    print(string.format("[EGG] 脚本分支: %s 加载成功", label))
    return true
end

--- ★执行"内置源码"脚本 (不联网): 用于把源码直接写进本文件的独立小脚本
--- 去重键用 label, 避免重复执行导致界面/功能叠加
local function runInlineScript(source, label, silent)
    label = label or "内置脚本"
    local key = "inline:" .. tostring(strHash(tostring(label)))
    if STATE.loadedScripts[key] then
        if not silent then notify("脚本分支", string.format("%s 已加载过, 跳过重复执行", label), 3, "info") end
        return false, "已加载过"
    end
    if not silent then notify("脚本分支", string.format("正在执行 %s ...", label), 2, "info") end
    local chunk, cerr = loadstring(source)
    if not chunk then
        notify("脚本分支", string.format("%s 编译失败", label), 5, "error")
        print(string.format("[EGG] %s 编译失败: %s", label, tostring(cerr)))
        return false, cerr
    end
    local ok, rerr = pcall(chunk)
    if not ok then
        notify("脚本分支", string.format("%s 运行出错: %s", label, tostring(rerr)), 6, "error")
        print(string.format("[EGG] %s 运行出错: %s", label, tostring(rerr)))
        return false, rerr
    end
    STATE.loadedScripts[key] = true
    if not silent then notify("脚本分支", string.format("%s 已加载 ✅", label), 4, "success") end
    print(string.format("[EGG] 脚本分支: %s 加载成功", label))
    return true
end

if Library then
    -- ★核心控件引用表: 构建段在 pcall 里, 内部只写 UI_Refs.xxx = 控件,
    --   顶层通过 UI_Refs 安全访问, 不再依赖"构建段里的 global 变量"。
    --   历史 bug: 之前直接写 local X = gb:AddToggle(...) 再在顶层引用, 会因作用域
    --   变成 nil 被 pcall 静默吞掉; 而写 global 又不可靠 (linter/严格模式会报错)。
    --
    -- ★注意: 这里**不能**写成 UI_Refs = {} —— 构建段之前已经往 UI_Refs 里挂了
    --   顶层定义的函数 (如 probeFunc), 直接重置会把它们清掉, 构建段里调用就变 nil。
    --   (实测踩坑: 会引发 "attempt to call a nil value" → 检测页只建出 1 个分区就中止)
    --   ★注意: 构建段在第 176 行之后执行, UI_Refs.probeFunc 已在顶层挂好, 这里必须
    --   用 "or {}" 保留它, 不能写成 UI_Refs = {} (否则清掉 probeFunc → 检测页建到一半崩)。
    UI_Refs = UI_Refs or {}

    --   ★兜底: 万一构建段被单独执行 (例如测试环境 setfenv 到别的环境), 顶层那段没跑到,
    --   就自己补一个最小可用的 probeFunc, 保证音乐页不会因为拿不到它就整体中止。
    if type(UI_Refs.probeFunc) ~= "function" then
        UI_Refs.probeFunc = function(...)
            for _, n in ipairs({ ... }) do
                local ok, f = pcall(function()
                    local env = getfenv and getfenv(1) or nil
                    if env then return env[n] end
                end)
                if ok and type(f) == "function" then return f end
                local g = (type(_G) == "table") and _G[n] or nil
                if type(g) == "function" then return g end
            end
            return nil
        end
    end

    -- ★同样兜底: 检测相关的顶层函数 (构建段里要用来刷榜 / 喂数据)
    --   正常流程下引擎段已挂好; 这里只是防止构建段被单独执行时拿到 nil。
    if type(UI_Refs.detectionTick) ~= "function" then
        UI_Refs.detectionTick = function() end
    end
    if type(UI_Refs.detectionGetList) ~= "function" then
        UI_Refs.detectionGetList = function() return {} end
    end
    if type(UI_Refs.detectionNoteShot) ~= "function" then
        UI_Refs.detectionNoteShot = function() end
    end
    if type(UI_Refs.detectionNoteHit) ~= "function" then
        UI_Refs.detectionNoteHit = function() end
    end
    if type(UI_Refs.detectionClear) ~= "function" then
        UI_Refs.detectionClear = function() end
    end

    local buildOK, buildErr = pcall(function()
    local repoObsidian = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

    -- ★addons 加载容错: ThemeManager / SaveManager 任一失败都不能拖垮整个 UI。
    --   历史教训: 这两行如果直接 loadstring(game:HttpGet(...))() 抛错, 会被外层 pcall
    --   吞掉, 结果是"窗口一个都没建出来"; 用户看到的就是"点进去一片空白"。
    local function loadAddon(path, fallbackName)
        local ok, mod = pcall(function()
            return loadstring(game:HttpGet(repoObsidian .. path))()
        end)
        if ok and type(mod) == "table" then return mod end
        print(string.format("[EGG] %s 加载失败 (%s), 使用空实现兜底", fallbackName, tostring(mod)))
        -- 兜底空实现: 所有方法都是空操作, 保证 UI 仍能正常建出来
        local stub = {}
        setmetatable(stub, { __index = function() return function() end end })
        return stub
    end
    local ThemeManager = loadAddon("addons/ThemeManager.lua", "ThemeManager")
    local SaveManager  = loadAddon("addons/SaveManager.lua", "SaveManager")
    local Options = Library.Options
    local Toggles = Library.Toggles

    Library.ForceCheckbox = false
    Library.ShowToggleFrameInKeybinds = true

    -- ★ Obsidian 无 AddParagraph: 用 AddLabel(文本, 换行=true) 模拟说明段落
    --   返回值: 该 Label 控件 (可后续 SetText 动态更新文字)
    local function PARA(gb, title, content)
        return gb:AddLabel((title or "") .. "\n" .. (content or ""), true)
    end

    Window = Library:CreateWindow({
        Title = "EGG",
        Footer = "Blood And Iron",
        Icon = 95816097006870,
        NotifySide = "Right",
        ShowCustomCursor = true,
    })
    SaveManager:SetLibrary(Library)
    SaveManager:SetFolder("EGG")
    -- ★禁止保存/恢复"拖动分离"开关: 它必须每次启动都从关开始 (安全默认)
    --   注意: SaveManager.Ignore 会同时作用于「保存」与「恢复」两条路径 (见 SaveManager
    --   第 468/479/491 行与第 589 行), 所以 DragPopout 既不会被写进配置, 也不会被读回来。
    pcall(function() SaveManager:SetIgnoreIndexes({ "DragPopout" }) end)
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("EGG")

    -- ★★ 全局兜底 (必须在建任何页/分区之前执行!): 让 Groupbox 永远不可拖出 ★★
    --
    -- 【为什么必须这么做】
    -- 库第 326 行 `local Templates = { ... PopOut = true ... }` 是**文件级 local**, 外部脚本
    -- 根本拿不到(实测 Library.Templates == nil), 所以改不了模板默认值。唯一可靠的办法是
    -- 包住 AddGroupbox 入口: 不管调用方传什么(甚至什么都不传), 都在进库之前把 PopOut 写成 false。
    -- 库第 12139 行 `Info = Library:Validate(Info, Templates.Groupbox)` 之后,
    -- 第 12422 行 `Enabled = Info.PopOut ~= false` 就必然算出 false →
    -- **拖拽监听器从第一帧起就不会被绑定, 彻底没有竞态窗口**。
    --
    -- 【踩坑记录】最初把这段放在 `local Tabs = {...}` 之后, 结果只对"包装之后新建的页"生效:
    -- 已经建好的 4 个页(Tabs 表里那几个)拿到的仍是未包装的 Tab 实例 → 实验 A/B 仍能拖出。
    -- 所以顺序必须是: **先包装 Window:AddTab, 再建页**。
    --   Luau 里 function 不能挂属性(会报 attempt to index function), 所以用外部弱表记录"已包装过的函数"
    local __hardenDone = setmetatable({}, { __mode = "k" })

    -- ★★ 「允许拖动分离成悬浮窗」的总闸 ★★
    --   这是**唯一**决定分区能不能拖出的地方。默认 false (安全默认: 全部固定)。
    --   由「配置」页的开关读写它, 写入前后新建的分区都会按最新值处理。
    --
    --   为什么要用"源头控制"而不是"事后翻转 PopOutEnabled":
    --   库第 12422 行 `Enabled = Info.PopOut ~= false` 只在**建分区的那一瞬间**读取,
    --   然后立刻决定要不要绑定拖拽监听器。监听器一旦没绑, 之后翻 PopOutEnabled 是无效的。
    --   所以必须在这里(进库之前)就把 PopOut 算对。实测这是唯一可靠的做法。
    local PopOutAllowed = false

    -- ★ Configuration 分区是"永远不许拖出"的黑名单: 它是 SaveManager 自动生成的,
    --   用户明确要求它必须固定 (旧版它能被拖成悬浮窗, 是个体验问题)。
    --   「高级功能说明」是纯说明分区, 拖出去没有意义, 一并列入。
    --   「配置存档」自己传了 PopOut = false, 走它自己的硬编码。
    --   判定用分区名, 不区分大小写, 兼容 SaveManager 各版本命名。
    local function isBlacklistedGB(Info)
        local n = Info and Info.Name
        if type(n) ~= "string" then return false end
        if n:find("configuration", 1, true) then return true end
        if n:find("高级功能说明", 1, true) then return true end
        return false
    end

    local function hardenNoPopOut(TabProto)
        if type(TabProto) ~= "table" then return end
        local rawAddGB = TabProto.AddGroupbox
        if type(rawAddGB) ~= "function" or __hardenDone[rawAddGB] then return end

        local wrapped = function(self, Info, ...)
            -- ★每个分区创建时, 现场读一次总闸 (不是建库时定死)
            local allow = PopOutAllowed
            if type(Info) == "string" then
                Info = { Name = Info, PopOut = allow }
            elseif type(Info) == "table" then
                Info = setmetatable({}, { __index = Info })   -- 浅拷贝, 不动调用方的表
                Info.PopOut = allow
            else
                Info = { PopOut = allow }
            end
            -- ★黑名单 (Configuration) 无条件固定, 不受开关影响
            if isBlacklistedGB(Info) then Info.PopOut = false end
            return rawAddGB(self, Info, ...)
        end
        __hardenDone[rawAddGB] = true
        TabProto.AddGroupbox = wrapped

        -- AddLeftGroupbox / AddRightGroupbox 是库内部的快捷别名, 一并接管
        local function aliasWrapped(side, orig)
            return function(self, ...)
                local N = select(1, ...)
                local allow = PopOutAllowed
                local ok, r = pcall(rawAddGB, self, { Side = side, Name = N, PopOut = allow })
                if ok then return r end
                return orig(self, ...)      -- 兜底: 万一签名不同, 退回原实现
            end
        end
        if type(TabProto.AddLeftGroupbox)  == "function" then TabProto.AddLeftGroupbox  = aliasWrapped(1, TabProto.AddLeftGroupbox)  end
        if type(TabProto.AddRightGroupbox) == "function" then TabProto.AddRightGroupbox = aliasWrapped(2, TabProto.AddRightGroupbox) end
    end
    UI_Refs.hardenNoPopOut = hardenNoPopOut

    -- ★把总闸的读写暴露给后面的「配置」页开关使用
    --   flush: 对**已经存在**的分区重新应用当前设置 (开关切换时调用)
    --   Luau 里 function 不能挂属性, 所以用两个函数分别暴露。
    UI_Refs.setPopOutAllowed = function(v) PopOutAllowed = v and true or false end
    UI_Refs.getPopOutAllowed = function() return PopOutAllowed end

    -- ★切换到"开启"时: 已经建好的分区需要补绑拖拽监听器。
    --   做法是**重建**不现实(会丢控件), 所以改用库暴露的 MakeBoxPopOut 直接补绑。
    --   这是库自己用来给分区开启拖出能力的函数, 调用它等价于"这个分区从建库起就允许拖出"。
    UI_Refs.applyPopOutToExisting = function(enabled, gbList)
        if not (Library and Library.MakeBoxPopOut) then return 0 end
        local n = 0
        for _, box in ipairs(gbList or {}) do
            pcall(function()
                -- 黑名单分区 (Configuration / 高级功能说明) 永远固定, 不受开关影响
                local nm = tostring(box.Name or ""):lower()
                local isBlack = nm:find("configuration", 1, true) ~= nil
                             or nm:find("高级功能说明", 1, true) ~= nil
                local want = enabled and not isBlack
                if not want and box.PoppedOut and box.SetPoppedOut then
                    box:SetPoppedOut(false)        -- 先收回悬浮窗, 避免残留
                end
                box.PopOutEnabled = want
                if want then
                    Library:MakeBoxPopOut(box, { Enabled = true })
                end
                n = n + 1
            end)
        end
        return n
    end

    -- 包装 Window:AddTab: 以后每个新建的页, 都会自动被 harden
    pcall(function()
        local rawAddTab = Window.AddTab
        if type(rawAddTab) == "function" and not __hardenDone[rawAddTab] then
            local wrappedAddTab = function(self, ...)
                local Tab = rawAddTab(self, ...)
                pcall(hardenNoPopOut, Tab)
                return Tab
            end
            __hardenDone[rawAddTab] = true
            Window.AddTab = wrappedAddTab
        end
    end)

    -- ★现在才建页 —— 此时包装已就位, 这 4 个页一出生就是"不可拖出"的
    local Tabs = {
        ["防御"]     = Window:AddTab("防御", "shield"),
        ["高级功能"] = Window:AddTab("高级功能", "radar"),
        ["脚本分支"] = Window:AddTab("脚本分支", "package"),
        ["配置"]     = Window:AddTab("配置", "settings"),
    }
    UI_Refs.Tabs = Tabs
    -- 双保险: 再显式 harden 一遍 (防止某些执行器上 Window.AddTab 不是可覆写的表字段)
    for _, _t in pairs(Tabs) do pcall(hardenNoPopOut, _t) end

    -- ★收集所有 Groupbox, 用于统一控制「拖出悬浮窗」(PopOut) 开关
    local GB_All = {}

    --//===================== 防御页
    local GB_Kick = Tabs["防御"]:AddGroupbox({ Side = 1, Name = "🛡 踢人" })
    table.insert(GB_All, GB_Kick)
    KickToggle = GB_Kick:AddToggle("Kick", {
        Text = "🛡 ★ 踢人 (自动循环)",
        Default = CONFIG.AntiKick_AutoKick,
        Callback = function(v)
            playToggleSound(v); CONFIG.AntiKick_AutoKick = v; CONFIG.AntiKick_Enabled = v
            if v then startAutoKick(); notify("踢人", string.format("已开启 -- 每 %.1f 秒自动投票", CONFIG.AntiKick_KickInterval), 3, "success")
            else stopAutoKick(); notify("踢人", "已关闭", 2.5, "info") end
        end,
    })
    UI_Refs.KickToggle = KickToggle
    KickIntSlider = GB_Kick:AddSlider("KickInterval", {
        Text = "⏱ 踢人间隔", Default = CONFIG.AntiKick_KickInterval, Min = 0.1, Max = 10, Rounding = 1,
        Callback = function(v) playSliderSound(); CONFIG.AntiKick_KickInterval = v end,
    })
    UI_Refs.KickIntSlider = KickIntSlider
    PARA(GB_Kick, "💡 好友保护说明 (重要, 防止误解)",
        "本脚本会保护『你账号的好友列表』里的所有人, 不会对他们发起踢人/投票。\n"
        .. "★ 注意: 加载提示里的『好友 N 人』指的是你 Roblox 账号的好友总数, 与你进的这个服务器里有没有好友无关。\n"
        .. "所以即使你进的是一个没有好友的服务器, 也可能提示『已加载 6 位好友』——那 6 人是你账号好友, 不是本服的人, 属正常现象。\n"
        .. "想保护本服里的非好友玩家, 请到「配置」页把它们加进『白名单』。")

    local GB_Shield = Tabs["防御"]:AddGroupbox({ Side = 1, Name = "🛡 反踢护盾" })
    table.insert(GB_All, GB_Shield)
    GB_Shield:AddToggle("AntiKickShield", {
        Text = "🛡 ★ 反踢护盾 (拦截踢人远程 + 反作弊调用)",
        Default = CONFIG.AntiKick_Shield,
        Callback = function(v)
            playToggleSound(v); CONFIG.AntiKick_Shield = v
            if v then AntiKickShield.enable() else AntiKickShield.disable() end
        end,
    })
    PARA(GB_Shield, "🛡 反踢护盾说明",
        "纯防御: 拦下 RequestPlayerKick 等踢人远程, 并阻断 LocalClean / CharacterControl 的本地调用, 循环禁用本机 CharacterControl。 "
        .. "不修改任何游戏状态、不提供玩法优势。开启后控制台输入 EGG_AntiKickShield.stats() 查看拦截计数。")

    local GB_Admin = Tabs["防御"]:AddGroupbox({ Side = 2, Name = "🛡 管理员防护" })
    table.insert(GB_All, GB_Admin)
    AdminLeaveToggle = GB_Admin:AddToggle("AdminAutoLeave", {
        Text = "🛡 ★ 检测到管理员自动退出", Default = CONFIG.Admin_AutoLeave,
        Callback = function(v) playToggleSound(v); CONFIG.Admin_AutoLeave = v; if v then startAdminWatch() end; notify("管理员检测", v and "已开启 -- 检测到管理员将自动退出" or "已关闭", 2.5, v and "success" or "info") end,
    })
    UI_Refs.AdminLeaveToggle = AdminLeaveToggle
    AdminGroupBox = GB_Admin:AddInput("AdminGroupId", {
        Text = "🆔 管理员群组 ID (留空=不按群组判定)", Default = (CONFIG.Admin_GroupId and CONFIG.Admin_GroupId ~= 0) and tostring(CONFIG.Admin_GroupId) or "",
        Placeholder = "如 123456", Numeric = true,
        Callback = function(v)
            playClickSound(); local n = tonumber((v or ""):match("%d+")) or 0; CONFIG.Admin_GroupId = n
            notify("管理员检测", n > 0 and ("已设置群组 ID -- " .. n) or "已关闭群组判定", 2.5, n > 0 and "success" or "info")
        end,
    })
    UI_Refs.AdminGroupBox = AdminGroupBox
    AdminNamesBox = GB_Admin:AddInput("AdminNames", {
        Text = "📛 管理员名字名单 (逗号分隔, 精确匹配)", Default = table.concat(CONFIG.Admin_Names or {}, ","),
        Placeholder = "如 aaa,bbb",
        Callback = function(v)
            playClickSound(); local list = {}
            for name in string.gmatch(v or "", "[^,]+") do name = name:match("^%s*(.-)%s*$"); if name ~= "" then table.insert(list, name) end end
            CONFIG.Admin_Names = list; notify("管理员检测", "已更新名单 -- " .. #list .. " 人", 2.5, "info")
        end,
    })
    UI_Refs.AdminNamesBox = AdminNamesBox
    PARA(GB_Admin, "🛡 管理员高级功能说明",
        "开启后每 0.1 秒扫描全服: 命中『群组 rank ≥ 设定值 / 名字在名单 / 角色带 Admin 标记』任一即自动踢出自己。 "
        .. "需补充本服判定依据 (群组 ID 或名字名单) 才能稳定识别, 详见聊天说明。")
    GB_Admin:AddToggle("AdminDiagnose", {
        Text = "🩺 诊断模式 (打印管理标志到控制台)", Default = CONFIG.Admin_Diagnose,
        Callback = function(v)
            playToggleSound(v); CONFIG.Admin_Diagnose = v
            if v then for _, p in ipairs(Players:GetPlayers()) do task.spawn(function() diagnosePlayer(p) end) end
                notify("管理员诊断", "已开启 -- 新进玩家信号将打印到控制台(F9)", 3, "info")
            else notify("管理员诊断", "已关闭", 2.5, "info") end
        end,
    })

    local GB_Notify = Tabs["防御"]:AddGroupbox({ Side = 2, Name = "🔔 通知" })
    table.insert(GB_All, GB_Notify)
    KickNotifyToggle = GB_Notify:AddToggle("KickNotify", {
        Text = "🔔 ★ 踢人通知", Default = CONFIG.Kick_Notify,
        Callback = function(v) playToggleSound(v); CONFIG.Kick_Notify = v; notify("踢人通知", v and "已开启" or "已关闭", 2.5, v and "success" or "info") end,
    })
    UI_Refs.KickNotifyToggle = KickNotifyToggle
    KickSoundToggle = GB_Notify:AddToggle("KickSound", {
        Text = "🔊 提示音", Default = CONFIG.Kick_Notify_Sound,
        Callback = function(v) playToggleSound(v); CONFIG.Kick_Notify_Sound = v; if v then playKickSound() end; notify("提示音", v and "已开启" or "已静音", 2.5, v and "success" or "info") end,
    })
    UI_Refs.KickSoundToggle = KickSoundToggle
    WarnToggle = GB_Notify:AddToggle("WarnVoted", {
        Text = "🗳 ★ 被投票时提醒我", Default = CONFIG.Warn_OnVoted,
        Callback = function(v) playToggleSound(v); CONFIG.Warn_OnVoted = v; notify("被投提醒", v and "已开启 -- 有人投你会立即提醒" or "已关闭", 2.5, v and "success" or "info") end,
    })
    UI_Refs.WarnToggle = WarnToggle

    --//===================== 检测页 (命中率 / 反作弊识别)
    --
    -- ★ 设计原则: 只读、只标记, 不替你操作、不给任何战斗优势。
    --   统计对手命中率, 超阈值自动上『检测榜』并提醒; 显示其 昵称(Name) 与 显示名(DisplayName)。
    --   ★ 不检测队友 (同队跳过)。数据由游戏战斗事件喂入 (见引擎段 ★接入点)。
    local GB_Info = Tabs["高级功能"]:AddGroupbox({ Side = 1, Name = "📡 高级功能说明" })
    table.insert(GB_All, GB_Info)
    PARA(GB_Info, "📡 检测 (命中率反作弊)",
        "统计对手命中率, 超阈值(默认80%)自动上榜并提醒, 显示 昵称+显示名。\n"
        .. "只观测、只标记, 不锁定/不躲避/不自动开枪。不检测队友。")
    PARA(GB_Info, "🔌 数据来源",
        "需把游戏开枪/命中事件接到脚本 ★接入点 (引擎段注释)。没接时榜单空, 正常。")

    local GB_Main = Tabs["高级功能"]:AddGroupbox({ Side = 1, Name = "📡 高级功能总开关" })
    table.insert(GB_All, GB_Main)
    DetectionEnabledToggle = GB_Main:AddToggle("DetectionEnabled", {
        Text = "📡 ★ 检测开关 (总开关)", Default = CONFIG.Detection_Enabled,
        Callback = function(v) playToggleSound(v); CONFIG.Detection_Enabled = v
            if v then notify("检测", "已开启 — 命中率超阈值的对手会进检测榜", 3, "success") else notify("检测", "已关闭", 2.5, "info") end end,
    })
    UI_Refs.DetectionEnabledToggle = DetectionEnabledToggle
    DetectionThresholdSlider = GB_Main:AddSlider("DetectionThreshold", {
        Text = "🎯 命中率阈值 (%)", Default = CONFIG.Detection_Threshold, Min = 50, Max = 100, Rounding = 0,
        Callback = function(v) playSliderSound(); CONFIG.Detection_Threshold = v; notify("检测", "阈值设为 " .. v .. "%", 2, "info") end,
    })
    UI_Refs.DetectionThresholdSlider = DetectionThresholdSlider
    DetectionMinShotsSlider = GB_Main:AddSlider("DetectionMinShots", {
        Text = "🔫 最少射击数 (防偶然)", Default = CONFIG.Detection_MinShots, Min = 1, Max = 50, Rounding = 0,
        Callback = function(v) playSliderSound(); CONFIG.Detection_MinShots = v end,
    })
    UI_Refs.DetectionMinShotsSlider = DetectionMinShotsSlider
    DetectionIgnoreTeamToggle = GB_Main:AddToggle("DetectionIgnoreTeam", {
        Text = "🤝 不检测队友 (同队跳过)", Default = CONFIG.Detection_IgnoreTeam,
        Callback = function(v) playToggleSound(v); CONFIG.Detection_IgnoreTeam = v end,
    })
    UI_Refs.DetectionIgnoreTeamToggle = DetectionIgnoreTeamToggle
    GB_Main:AddButton({ Text = "🔄 立即扫描 (刷新榜单)", Callback = function() playClickSound()
        pcall(function() UI_Refs.detectionTick() end)
        local l = {}; pcall(function() l = UI_Refs.detectionGetList() end)
        local cb = UI_Refs.__detectListLabel
        if cb and cb.SetText then cb:SetText((#l == 0) and "（检测榜为空 — 等待战斗数据）" or table.concat(l, "\n")) end
        notify("检测", "已扫描 — 当前上榜 " .. #l .. " 人", 2.5, "info") end })
    GB_Main:AddButton({ Text = "🗑 清空检测榜", Callback = function() playClickSound()
        pcall(function() UI_Refs.detectionClear() end)
        local cb = UI_Refs.__detectListLabel
        if cb and cb.SetText then cb:SetText("（检测榜为空 — 等待战斗数据）") end end })

    -- ★ 击中提示 (本地玩家打中敌人的反馈, 右上角)
    local GB_Hit = Tabs["高级功能"]:AddGroupbox({ Side = 1, Name = "🎯 击中提示 (右上角)" })
    table.insert(GB_All, GB_Hit)
    GB_Hit:AddToggle("HitFeedbackEnabled", {
        Text = "🎯 ★ 子弹击中提示", Default = CONFIG.HitFeedback_Enabled,
        Callback = function(v) playToggleSound(v); CONFIG.HitFeedback_Enabled = v
            notify("击中提示", v and "已开启 — 打中敌人右上角提示 + 踢人音效" or "已关闭", 2.5, v and "success" or "info") end,
    })
    GB_Hit:AddToggle("HitFeedbackMelee", {
        Text = "🗡 近战击中提示", Default = CONFIG.HitFeedback_Melee,
        Callback = function(v) playToggleSound(v); CONFIG.HitFeedback_Melee = v
            notify("击中提示", v and "已开启 — 近战『已打中对面』, 不发声, 每次只显示 1 个" or "已关闭", 2.5, v and "success" or "info") end,
    })
    PARA(GB_Hit, "🎯 击中提示说明",
        "子弹:『子弹已击中对面』+ 名字/昵称/扣血, 播踢人音效。\n"
        .. "近战:『已打中对面』, 不发声; 提示栏每次只显示 1 个, 排队不挡视野。\n"
        .. "只提示打中『敌人』, 打队友不提示。需接游戏伤害事件 (★接入点)。")

    local GB_List = Tabs["高级功能"]:AddGroupbox({ Side = 2, Name = "📡 命中率检测榜 (>" .. tostring(CONFIG.Detection_Threshold) .. "%)" })
    table.insert(GB_All, GB_List)
    local detectListLabel = GB_List:AddLabel("（检测榜为空 — 等待战斗数据）", true)
    UI_Refs.__detectListLabel = detectListLabel
    GB_List:AddButton({ Text = "🧪 演示喂数据 (看效果)", Callback = function() playClickSound()
        pcall(function()
            for _=1,20 do UI_Refs.detectionNoteShot(900001) end
            for _=1,19 do UI_Refs.detectionNoteHit(900001, 123) end
            for _=1,10 do UI_Refs.detectionNoteShot(900002) end
            for _=1,6  do UI_Refs.detectionNoteHit(900002, 123) end
            for _=1,3  do UI_Refs.detectionNoteShot(900003) end
            for _=1,3  do UI_Refs.detectionNoteHit(900003, 123) end
            STATE.detection["900001"].name = "CheaterA"; STATE.detection["900001"].display = "锁头怪A"
            STATE.detection["900002"].name = "NormalB";  STATE.detection["900002"].display = "正常人B"
            STATE.detection["900003"].name = "LowShotC"; STATE.detection["900003"].display = "样本少C"
        end)
        pcall(function() UI_Refs.detectionTick() end)
        local l = {}; pcall(function() l = UI_Refs.detectionGetList() end)
        local cb = UI_Refs.__detectListLabel
        if cb and cb.SetText then cb:SetText((#l == 0) and "（检测榜为空）" or table.concat(l, "\n")) end
        notify("检测", "演示完成 — 上榜的应只有 CheaterA(95%); B(60%) 与 C(射击不足) 不上榜", 4, "info") end })
    PARA(GB_List, "📡 检测榜说明",
        "上榜 = 命中率 ≥ 阈值 且 射击数 ≥ 最少射击数 的对手。\n"
        .. "格式: 显示名 · @昵称 · 命中率% (命中/射击)。只标记、不操作。")
    --//===================== 配置页
    local GB_WL = Tabs["配置"]:AddGroupbox({ Side = 1, Name = "📝 白名单 (只保护本服玩家)" })
    table.insert(GB_All, GB_WL)
    WLBox = GB_WL:AddInput("WLInput", {
        Text = "➕ 加入白名单 (输入本服玩家名)", Default = "", Placeholder = "如 a",
        Callback = function(v)
            playClickSound(); if not v or v == "" then return end
            local ok, msg = addWhitelist(v)
            if ok then pcall(function() WLListDropdown:SetValues(CONFIG.Whitelist) end); notify("白名单", msg, 3, "success")
            else notify("白名单", msg, 3, "warn") end
        end,
    })
    UI_Refs.WLBox = WLBox
    WLListDropdown = GB_WL:AddDropdown("WLList", {
        Text = "📝 白名单列表 (点选后移除)", Values = CONFIG.Whitelist, Default = 1,
        Callback = function() playClickSound() end,
    })
    UI_Refs.WLListDropdown = WLListDropdown
    GB_WL:AddButton({ Text = "➖ 移除所选白名单", Callback = function()
        playClickSound(); local opt = WLListDropdown and WLListDropdown.Value
        if not opt then notify("白名单", "未选择要移除的人", 2.5, "warn"); return end
        for i, n in ipairs(CONFIG.Whitelist) do if n == opt then removeWhitelist(i); pcall(function() WLListDropdown:SetValues(CONFIG.Whitelist) end); notify("白名单", "已移除 -- " .. n, 2.5, "info"); return end end
        notify("白名单", "未找到 -- " .. tostring(opt), 2.5, "warn")
    end })
    GB_WL:AddButton({ Text = "💾 立即保存白名单", Callback = function()
        playClickSound(); if not hasFs() then notify("配置", "当前执行器不支持文件读写, 关游戏后会重置", 4, "error"); return end
        if saveConfig() then notify("白名单", "已保存 -- " .. #CONFIG.Whitelist .. " 人", 3, "success") else notify("白名单", "保存失败", 3, "error") end
    end })

    local GB_Conf = Tabs["配置"]:AddGroupbox({ Side = 1, Name = "⚙ 配置" })
    table.insert(GB_All, GB_Conf)

    -- ★★ 分区拖出 (PopOut) 控制 ★★
    --
    -- 【曾经的问题】旧版本在 UI 建完之后才逐个把 box.PopOutEnabled 翻成 false。但库的执行顺序是:
    --   1) Library:MakeBoxPopOut(Groupbox, { Enabled = Info.PopOut ~= false })  ← 读的是模板默认值
    --   2) Templates.Groupbox.PopOut 默认 = true (库第 453 行) → 拖拽监听器 InputBegan 当场被绑定
    --   3) 0.15 秒后才轮到我们翻标志 → 这 0.15 秒里所有分区都能被拖出去
    -- 更糟的是 SaveManager 的原生「Configuration」分区是在我们翻标志**之后**才建的,
    -- 于是它始终带着库默认的 PopOut=true —— 这就是"配置页里那块原生配置还能拖成悬浮窗"。
    --
    -- 【现在的做法】把"事后翻转"改成"源头控制 + 开关驱动":
    --   · 包装 Tab:AddGroupbox, 在**进库之前**按当前总闸状态写 Info.PopOut。
    --     库第 12422 行 Enabled = Info.PopOut ~= false 就会算对, 不存在竞态窗口。
    --   · 总闸 PopOutAllowed 默认 false (安全默认: 分区固定)。
    --   · 下面的开关切换总闸; 切到"开启"时, 对**已建好的**分区调用库的 MakeBoxPopOut 补绑监听器。
    --   · Configuration 分区走黑名单, 无论开关怎样都固定 —— 这是你明确要求的。
    UI_Refs.mkGB = function(tab, side, name)
        return tab:AddGroupbox({ Side = side, Name = name, PopOut = false })
    end

    -- (触摸音效已按你的要求移除; 如需恢复见备份文件)

    -- ★拖动分离悬浮窗开关 (总闸): 控制功能分区能否被拖出成独立悬浮小窗
    --   默认关 —— 每次进游戏都从"固定"开始, 避免误拖出一堆小窗。
    --   注意: 本开关**不会被 SaveManager 保存/恢复** (见上方 SetIgnoreIndexes({ "DragPopout" })),
    --         属"安全默认"项, 必须每次手动开。
    local function applyPopoutSetting(enabled)
        UI_Refs.setPopOutAllowed(enabled)
        local n = UI_Refs.applyPopOutToExisting(enabled, GB_All)
        -- ★Configuration 分区可能比我们晚建 (SaveManager 异步恢复), 这里也补一遍
        pcall(function()
            for _, tab in pairs(Tabs) do
                for _, gb in pairs(tab.Groupboxes or {}) do
                    local nm = tostring(gb.Name or ""):lower()
                    if nm:find("configuration", 1, true) then
                        if gb.PoppedOut and gb.SetPoppedOut then pcall(function() gb:SetPoppedOut(false) end) end
                        gb.PopOutEnabled = false
                    end
                end
            end
        end)
        return n
    end
    UI_Refs.applyPopoutSetting = applyPopoutSetting

    DragPopoutToggle = GB_Conf:AddToggle("DragPopout", {
        Text = "🪟 允许拖动分离成悬浮窗 (默认关)",
        Default = CONFIG.UI_DragPopout,
        Callback = function(v)
            playToggleSound(v); CONFIG.UI_DragPopout = v; applyPopoutSetting(v)
            notify("界面", v and "已开启 -- 可按住分区标题拖出成小窗 (设置/配置存档等分区仍固定)"
                            or "已关闭 -- 功能分区固定, 不可拖出", 3, v and "success" or "info")
        end,
    })
    UI_Refs.DragPopoutToggle = DragPopoutToggle
    PARA(GB_Conf, "🪟 拖动说明",
        "关闭 (默认): 按住功能区域标题拖动不会把它变成悬浮小窗, 分区固定。\n"
        .. "开启后: 可按住分区标题拖出, 变成独立小悬浮窗; 再拖回原位附近会自动吸附归位。\n"
        .. "★ 「高级功能说明」「配置存档」以及原生 Configuration 分区始终固定, 不受本开关影响。\n"
        .. "★ 本开关不随配置保存, 每次进游戏都要手动开启 (安全默认)。")

    GB_Conf:AddButton({ Text = "↩ 重置所有设置为默认", Callback = function()
        playClickSound()
        -- ★统一经 UI_Refs 取控件 (构建段内是 local, 闭包内直接引用在部分执行器会拿到 nil)
        local function setVal(name, v)
            local e = UI_Refs and UI_Refs[name]
            if e and e.SetValue then pcall(function() e:SetValue(v) end) end
        end
        setVal("KickToggle", false)
        setVal("KickIntSlider", 2.0)
        setVal("KickNotifyToggle", true)
        setVal("KickSoundToggle", true)
        setVal("WarnToggle", true)
        setVal("DetectionEnabledToggle", true)
        setVal("DetectionThresholdSlider", 80)
        setVal("DetectionMinShotsSlider", 10)
        setVal("DetectionIgnoreTeamToggle", true)
        setVal("StartupSoundToggle", true)
        CONFIG.AntiKick_AutoKick = false; CONFIG.AntiKick_Enabled = false; CONFIG.AntiKick_KickInterval = 2.0
        CONFIG.Kick_Notify = true; CONFIG.Kick_Notify_Sound = true; CONFIG.Warn_OnVoted = true
        CONFIG.Detection_Enabled = true; CONFIG.Detection_Threshold = 80; CONFIG.Detection_MinShots = 10; CONFIG.Detection_IgnoreTeam = true; CONFIG.Startup_Sound = true
        CONFIG.Whitelist = {}; CONFIG.Admin_AutoLeave = false; CONFIG.Admin_GroupId = 0; CONFIG.Admin_Names = {}
        setVal("AdminLeaveToggle", false)
        setVal("AdminGroupBox", "")
        setVal("AdminNamesBox", "")
        stopAutoKick()
        local wl = UI_Refs and UI_Refs.WLListDropdown
        if wl and wl.SetValues then pcall(function() wl:SetValues({}) end) end
        notify("配置", "已重置为默认", 3, "warn")
    end })
    PARA(GB_Conf, "⚙ 配置说明",
        "开关/滑块/下拉/键绑由 Obsidian 自动保存 (下次进游戏自动恢复); 白名单列表为动态数据, 走本地文件单独持久化。")

    local GB_Startup = Tabs["配置"]:AddGroupbox({ Side = 2, Name = "🎬 开启动画音效" })
    table.insert(GB_All, GB_Startup)
    StartupSoundToggle = GB_Startup:AddToggle("StartupSound", {
        Text = "🎬 ★ 开启动画音效 (脚本加载完成时播放)", Default = CONFIG.Startup_Sound,
        Callback = function(v) playToggleSound(v); CONFIG.Startup_Sound = v
            if v then playStartupSound(); notify("开启动画", "已开启 -- 下次加载时播放", 2.5, "success") else notify("开启动画", "已关闭", 2.5, "info") end
        end,
    })
    UI_Refs.StartupSoundToggle = StartupSoundToggle
    GB_Startup:AddButton({ Text = "🎵 试听开启动画音效", Callback = function() playClickSound(); local keep = CONFIG.Startup_Sound; CONFIG.Startup_Sound = true; playStartupSound(); CONFIG.Startup_Sound = keep; notify("开启动画", "试听中...", 2, "info") end })
    PARA(GB_Startup, "🎬 开启动画音效说明", "脚本加载完成、面板首次弹出时播放的开场音效。")

    -- ★★ 修复分支页空白的关键 bug ★★
    -- 原来这里写的是 Tabs["配置"]:AddLabel(...) —— 但 Obsidian 的 **Tab 对象没有 AddLabel**,
    -- AddLabel 只存在于 Groupbox (库第 6198 行 Funcs:AddLabel, 经 setmetatable(Groupbox, BaseGroupbox)
    -- 挂载)。Tab:AddLabel 会直接报 "missing method 'AddLabel'", 而这个错误正好发生在
    -- 「脚本分支页」构建代码之前 —— 外层 pcall 把异常吞掉后, 分支页一行都没执行 => 点进去全白。
    -- 修法: 用一个普通 Groupbox 来承载这个「显示/隐藏面板键」标签 + 键绑。
    local GB_Hotkey = Tabs["配置"]:AddGroupbox({ Side = 2, Name = "⌨ 显示/隐藏面板键" })
    table.insert(GB_All, GB_Hotkey)
    local uiKeyLabel = GB_Hotkey:AddLabel("⌨ 面板切换键 (点击右侧按钮改键)")
    uiKeyLabel:AddKeyPicker("UIToggleKey", { Text = "切换面板", Default = CONFIG.HOTKEY or "T", Mode = "Toggle" })
    if Toggles.UIToggleKey and Toggles.UIToggleKey.OnClick then
        Toggles.UIToggleKey:OnClick(function()
            pcall(function() if Library.ScreenGui then Library.ScreenGui.Enabled = not Library.ScreenGui.Enabled end end)
        end)
    end

    --//===================== 脚本分支页
    -- ★整页独立保护: 这一页万一出错, 只影响本页, 不会连带后面「配置」页一起空白;
    --   而且错误会打印出来, 不再是"点进去一片空白还查不到原因"。
    --
    -- 【已按你的要求删掉两个分区】
    --  · 「📦 内置分支」 —— 原含"音乐功能位置提示", 音乐功能已删除, 现为「检测」页的命中率识别
    --    和"重置加载记录"两个按钮, 后者的功能在预设脚本库底部有同一个按钮, 属重复。
    --  · 「🔗 加载自定义脚本」 —— 你已经有注入器, 直接执行更省事;
    --    而且「📋 脚本列表」里保存过的脚本依然能一键加载, 不用再手填一遍地址。
    -- 这一页现在只保留「📋 脚本列表」+「📚 预设脚本库」两块。
    local branchOK, branchErr = pcall(function()
    print("[EGG] [分支页] 开始构建...")

    print("[EGG] [分支页] 1/2 准备脚本列表区")
    local GB_List = Tabs["脚本分支"]:AddGroupbox({ Side = 1, Name = "📋 脚本列表" })
    table.insert(GB_All, GB_List)
    ExtListDropdown = GB_List:AddDropdown("ExtScriptPick", {
        Text = "📦 已保存的脚本 (点选即加载)", Values = (function() local o = {}; for _, it in ipairs(CONFIG.ExtScripts or {}) do table.insert(o, it.name) end; return (#o > 0 and o) or {"(暂无, 用右侧预设脚本库加载后会自动收录)"} end)(), Default = 1,
        Callback = function(opt) playClickSound(); for _, item in ipairs(CONFIG.ExtScripts or {}) do if item.name == opt then task.spawn(function() runRemoteScript(item.url, item.name, false) end); return end end end,
    })
    UI_Refs.ExtListDropdown = ExtListDropdown
    GB_List:AddButton({ Text = "🗑 删除列表中的选中项", Callback = function() playClickSound(); local cur = nil; pcall(function() cur = ExtListDropdown.Value end)
        if not cur then notify("脚本分支", "请先在下拉框选中一项", 3, "error"); return end
        local newList = {}; for _, item in ipairs(CONFIG.ExtScripts or {}) do if item.name ~= cur then table.insert(newList, item) end end
        CONFIG.ExtScripts = newList; local opts = {}; for _, item in ipairs(newList) do table.insert(opts, item.name) end
        if #opts == 0 then opts = {"(暂无, 用右侧预设脚本库加载后会自动收录)"} end
        pcall(function() ExtListDropdown:SetValues(opts) end); saveConfig(); notify("脚本分支", "已删除", 3, "info")
    end })
    GB_List:AddButton({ Text = "🗑 清空加载记录 (所有脚本可再次加载)", Callback = function() playClickSound(); STATE.loadedScripts = {}; notify("脚本分支", "已清空加载记录, 所有脚本可重新加载", 3, "info") end })
    PARA(GB_List, "⚙ 高级", "若加载失败, 多半是执行器不支持 loadstring 或网络受限。可改用 execute 类执行器, 或把脚本下载后手动执行。音乐功能已删除 (改为「检测」页的命中率识别)。")

    --//===================== ★ 预设脚本库 (全部点击才加载, 不自动执行)
    print("[EGG] [分支页] 2/2 准备预设脚本库")
    local GB_Preset = Tabs["脚本分支"]:AddGroupbox({ Side = 2, Name = "📚 预设脚本库 (点击加载)" })
    table.insert(GB_All, GB_Preset)
    PARA(GB_Preset, "📚 预设脚本库说明",
        "以下均为第三方独立脚本, 由本脚本代为 loadstring 加载 (与你手动执行等价)。\n"
        .. "★ 全部需要你手动点击才会加载, 不会自动执行; 同一脚本默认只加载一次 (点『重置加载记录』可再次加载)。\n"
        .. "⚠ 这些脚本来自外部作者, 本脚本不对其内容与安全性负责, 请自行评估后再使用。")

    print("[EGG] [分支页] 2 个分区全部创建完成")
    -- 预设清单: { 标题, 类型("url"/"inline"), 内容 }
    local PRESETS = {
        { "🔫 无限子弹 (塔菲)", "url", "https://raw.githubusercontent.com/sdacrdroblox120/duikn/refs/heads/main/%E5%A1%94%E8%8F%B2%E8%84%9A%E6%9C%AC.txt" },
{ "👻 Desync 隐身 (白方块修复版)", "inline", [==[
-- Desync 隐身 (白方块修复版) — 内置源码
--
-- ★ 修复内容: 关闭隐身时不再把角色所有部件透明度统一写 0, 而是还原成
--   开启前记录的原始透明度。原版统一写 0 会把默认全透明的 HumanoidRootPart
--   (2x2x1, 卡在躯干位置) 变成实心方块 —— 这就是"关闭隐身后身上一层白方块"的根因。
--
-- ★ 说明: Desync 位移本身依赖游戏的位移处理实现, 非通用脚本。
--   本脚本所测游戏服务端有位置校验/回拉, "本体留在原地"可能不生效。
--[[
  Desync 隐身 — 白方块修复版
  ============================================================
  【原版问题】
    原版 disableDesync 里写的是 setTrans(c, 0) —— 把角色身上所有 BasePart / Decal
    的 Transparency 一律硬写成 0（完全不透明）。

    但 Roblox 角色身上**本来就有透明部件**，最典型的是:
      · HumanoidRootPart  —— R6/R15 默认 Transparency = 1（完全透明）
      · 部分配饰的 Handle / 一些游戏自定义的隐藏部件
      · Head 上的 face Decal（通常 Transparency = 0，但也有例外）

    于是"关闭隐身"这个动作，把本该隐形的 HumanoidRootPart 变成了一个实心方块。
    HumanoidRootPart 尺寸 2×2×1，正好卡在躯干位置 —— 看起来就是身上多了一层白方块。
    重生后角色重建，Transparency 回到默认值 1，白方块消失。现象完全吻合。

  【修法】
    开启隐身前，先把每个部件的原始 Transparency 记下来；
    关闭时逐件还原成记录值，而不是统一写 0。
    —— 除此之外，其余逻辑与原版保持完全一致（Seat + Weld + 透明度），
       不动配饰、不动衣服、不改质量、不碰网络所有权。

  【保留的行为】
    · 开启时把角色显示为半透明（默认 0.7），便于自己看位置
    · 关闭时完全恢复原来的外观
    · Seat 作为 desync 锚点，关闭时销毁
]]

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local CoreGui = (pcall(function() return game:GetService("CoreGui") end)
                  and game:GetService("CoreGui"))
                 or LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- 配置（与原版一致）
-- ============================================================
local desyncTransparency = 0.7    -- 开启隐身时自己看到的透明度

-- ============================================================
-- 状态
-- ============================================================
local desyncActive = false
local invisSeat    = nil
local invisWeld    = nil

-- ★新增：记录原始透明度，关闭时还原（这是修掉白方块的关键）
--   originals[部件] = 开启隐身前的 Transparency
local originals = {}

local function getRoot(c)
    return c:FindFirstChild("HumanoidRootPart")
        or c:FindFirstChild("Torso")
        or c:FindFirstChild("UpperTorso")
end

local function getTorso(c)
    return c:FindFirstChild("Torso")
        or c:FindFirstChild("UpperTorso")
end

-- 目标部件判定：与原版一致（BasePart 或 Decal）
local function isTarget(p)
    return p:IsA("BasePart") or p:IsA("Decal")
end

-- 开启时：记录原值 + 设为隐身透明度
local function applyInvisible(c, t)
    for _, p in pairs(c:GetDescendants()) do
        if isTarget(p) then
            -- ★记录原值（只记一次，避免重复开启时把"隐身中的值"当成原值）
            if originals[p] == nil then
                local ok, orig = pcall(function() return p.Transparency end)
                originals[p] = ok and orig or 0
            end
            pcall(function() p.Transparency = t end)
        end
    end
end

-- ★关闭时：还原成记录的原值（不再统一写 0）
--   —— 这是修掉"关闭后身上出现白方块"的核心。
--      旧版 setTrans(c, 0) 会把 HumanoidRootPart（默认透明度 1）强行变成不透明，
--      那个 2×2×1 的方块就套在躯干位置，看起来就是一层白方块。
local function restoreVisibility(c)
    -- 逐件还原成开启前记录的原始值
    for p, orig in pairs(originals) do
        pcall(function() p.Transparency = orig end)
    end

    -- 兜底：只处理"没被记录到"的情况（例如开启隐身之后才动态生成的部件）。
    --   注意这里**绝不能**统一写 0 —— 那正是旧版的 bug。
    --   做法：对没记录的部件不做任何改动，只把 HumanoidRootPart 这一个
    --   有明确默认值的部件（Roblox 角色里它恒为全透明）补正。
    if c then
        for _, p in pairs(c:GetDescendants()) do
            if originals[p] == nil and isTarget(p) then
                pcall(function()
                    if p.Name == "HumanoidRootPart" and p.Transparency ~= 1 then
                        p.Transparency = 1
                    end
                end)
            end
        end
    end

    originals = {}
end

-- ============================================================
-- 开启 / 关闭（结构与原版一致）
-- ============================================================
local function enableDesync()
    if desyncActive then return end

    local c = LocalPlayer.Character
    if not c then
        task.wait(0.2)
        c = LocalPlayer.Character
        if not c then return end
    end

    local r = getRoot(c)
    local t = getTorso(c)

    if not r or not t then
        task.wait(0.3)
        c = LocalPlayer.Character
        if c then
            r = getRoot(c)
            t = getTorso(c)
        end
        if not r or not t then return end
    end

    c:MoveTo(r.Position)
    task.wait(0.15)

    if invisSeat then invisSeat:Destroy() end

    invisSeat = Instance.new("Seat", Workspace)
    invisSeat.Anchored     = false
    invisSeat.CanCollide   = false
    invisSeat.Transparency = 1
    invisSeat.Size         = Vector3.new(2, 1, 1)
    invisSeat.Position     = r.Position
    -- ★顺手把 Seat 的面纹理关掉：Seat 默认带 Studs 面，是"白方块"的另一个可能来源
    pcall(function() invisSeat.TopSurface    = Enum.SurfaceType.Smooth end)
    pcall(function() invisSeat.BottomSurface = Enum.SurfaceType.Smooth end)
    pcall(function() invisSeat.CastShadow    = false end)

    invisWeld = Instance.new("Weld", invisSeat)
    invisWeld.Part0 = invisSeat
    invisWeld.Part1 = t

    task.wait(0.1)

    -- ★开启前先清空记录，避免上一轮残留
    originals = {}
    applyInvisible(c, desyncTransparency)

    desyncActive = true
end

local function disableDesync()
    desyncActive = false

    if invisSeat then
        invisSeat:Destroy()
        invisSeat = nil
        invisWeld = nil
    end

    local c = LocalPlayer.Character
    -- ★关键修复：还原原值，而不是 setTrans(c, 0)
    restoreVisibility(c)
end

-- 角色重生时清空记录（新角色是全新的部件，旧记录无意义）
LocalPlayer.CharacterAdded:Connect(function()
    desyncActive = false
    if invisSeat then pcall(function() invisSeat:Destroy() end) end
    invisSeat, invisWeld = nil, nil
    originals = {}
end)

-- ============================================================
-- 对外 API
-- ============================================================
_G.DesyncInvisible = {
    enable  = enableDesync,
    disable = disableDesync,
    toggle  = function()
        if desyncActive then disableDesync() else enableDesync() end
    end,
    status  = function()
        print("[Desync] 状态: " .. (desyncActive and "开启中" or "已关闭"))
        return desyncActive
    end,
}

-- ============================================================
-- UI（与原版风格一致）
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "DesyncStandalone"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 160, 0, 60)
frame.Position = UDim2.new(0, 10, 0.4, 0)
frame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
frame.BorderSizePixel = 0
frame.Draggable = true
frame.Active = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 22)
title.Text = "👻 Desync隐身"
title.TextColor3 = Color3.fromRGB(200, 150, 255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 12

local toggle = Instance.new("TextButton", frame)
toggle.Size = UDim2.new(1, -20, 0, 28)
toggle.Position = UDim2.new(0, 10, 0, 26)
toggle.Text = "开启"
toggle.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 12
toggle.BorderSizePixel = 0
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 5)

toggle.MouseButton1Click:Connect(function()
    if desyncActive then
        disableDesync()
        toggle.Text = "开启"
        toggle.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
    else
        enableDesync()
        if desyncActive then
            toggle.Text = "关闭"
            toggle.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
        end
    end
end)

print("[Desync] 隐身已加载 (白方块已修: 关闭时还原原始透明度, 不再统一写 0)")
]==] },
        { "✈ 飞行 V3", "url", "https://raw.githubusercontent.com/XNEOFF/FlyGuiV3/main/FlyGuiV3.txt" },
        { "🧩 通用脚本 (Loader)", "url", "https://raw.githubusercontent.com/Jilxi/123/refs/heads/main/Loader.lua" },
        { "🌀 甩飞脚本", "url", "https://pastefy.app/xOXIJXr9/raw" },
        { "🕺 R6 动作脚本", "url", "https://raw.githubusercontent.com/sypcerr/FECollection/refs/heads/main/script.lua" },
        { "⚔ 血与铁菜单 (5年前)", "url", "https://pastebin.com/raw/Fk7xMTNX" },
        { "⚔ VAPE V4", "url", "https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua" },
        { "⚔ 血与铁 林默决", "url", "https://raw.githubusercontent.com/sleenndn/Matds/refs/heads/main/bi2.0" },
        { "⚔ 血与铁 序言", "url", "https://raw.githubusercontent.com/Matds78/Script/refs/heads/main/Blood%26Iron" },
    }
    for _, item in ipairs(PRESETS) do
        local title, kind, content = item[1], item[2], item[3]
        GB_Preset:AddButton({ Text = title, Callback = function()
            playClickSound()
            task.spawn(function()
                if kind == "url" then
                    runRemoteScript(content, title, false)
                else
                    runInlineScript(content, title, false)
                end
            end)
        end })
    end
    print("[EGG] [分支页] 预设按钮创建完毕, 共", #PRESETS, "条")
    PRESETS_CHK = PRESETS
    GB_Preset:AddButton({ Text = "🗑 重置加载记录 (全部可再次加载)", Callback = function()
        playClickSound(); STATE.loadedScripts = {}
        notify("预设脚本库", "已清空加载记录, 所有脚本可重新加载", 3, "info")
    end })
    print("[EGG] [分支页] 构建完成")

    end)  -- ★脚本分支页 pcall 结束
    if not branchOK then
        warn("[EGG] ⚠ 脚本分支页构建失败: " .. tostring(branchErr))
        print("[EGG] ⚠ 脚本分支页构建失败: " .. tostring(branchErr))
        pcall(function()
            notify("脚本分支页构建失败", tostring(branchErr):sub(1, 200), 10, "error")
        end)
    end

    --//===================== 配置保存分区 (中文版, 替代 SaveManager 的英文原生分区)
    --
    -- 【为什么不用 SaveManager:BuildConfigSection】
    --   它内部是 `Tab:AddGroupbox({ Side="Right", Name="Configuration", IconName=... })`:
    --     · 名字写死成英文 "Configuration"
    --     · 里面的控件文案也全是英文 (Config name / Create config / Load config / ...)
    --     · 而且**没传 PopOut** → 吃库模板默认值 PopOut=true → 就成了"配置页里那块
    --       还能拖成悬浮窗的原生 UI 配置"
    --   三个问题一次解决: 这里自己建一个中文分区, 显式 PopOut=false,
    --   所有控件文案汉化, 调用的还是 SaveManager 同一套底层接口, 功能完全等价。
    pcall(function()
        local GB_Save = Tabs["配置"]:AddGroupbox({
            Side = 2, Name = "💾 配置存档 (保存/加载界面设置)", IconName = "save", PopOut = false,
        })
        table.insert(GB_All, GB_Save)

        -- 这一块是动态界面: 保存/加载后要刷新下拉列表和自动加载提示
        local cfgNameBox, cfgList, autoloadLabel

        local function refreshList()
            if not cfgList then return end
            pcall(function()
                cfgList:SetValues(SaveManager:RefreshConfigList())
                cfgList:SetValue(nil)
            end)
        end

        local function refreshAutoloadLabel()
            local name = "无"
            pcall(function()
                local nm, ok = SaveManager:GetAutoloadConfig()
                if ok and nm then name = nm end
            end)
            if autoloadLabel and autoloadLabel.SetText then
                pcall(function() autoloadLabel:SetText("⏯ 当前自动加载的配置: " .. tostring(name)) end)
            end
        end

        local function pickName()
            local v = nil
            pcall(function() v = cfgNameBox and cfgNameBox.Value end)
            if type(v) ~= "string" or v == "" then
                notify("配置存档", "请先在下拉框选择一份配置", 3, "warn")
                return nil
            end
            return v
        end

        local function pickNewName()
            local v = nil
            pcall(function() v = cfgNameBox and cfgNameBox.Value end)
            if type(v) ~= "string" or v == "" then
                notify("配置存档", "请先填写配置名称", 3, "warn")
                return nil
            end
            if string.lower(v) == "autoload" then
                notify("配置存档", "「autoload」是保留名, 请换一个", 3, "warn")
                return nil
            end
            return v
        end

        cfgNameBox = GB_Save:AddInput("SaveManager_ConfigName", {
            Text = "📝 配置名称 (新建时填写)",
            Placeholder = "例如: 我的默认设置",
            Default = "",
        })
        UI_Refs.cfgNameBox = cfgNameBox

        GB_Save:AddButton({ Text = "💾 新建/覆盖保存配置", Callback = function()
            playClickSound()
            local name = pickNewName()
            if not name then return end
            local ok, err = SaveManager:Save(name)
            if ok then
                notify("配置存档", string.format("已保存配置「%s」", name), 3, "success")
                refreshList()
            else
                notify("配置存档", "保存失败: " .. tostring(err), 4, "error")
            end
        end })

        GB_Save:AddDivider()

        cfgList = GB_Save:AddDropdown("SaveManager_ConfigList", {
            Text = "📂 已保存的配置 (点选后可操作)",
            Values = (function()
                local ok, list = pcall(function() return SaveManager:RefreshConfigList() end)
                if ok and type(list) == "table" and #list > 0 then return list end
                return { "(暂无配置)" }
            end)(),
            AllowNull = true, Multi = false, Default = 0,
            Callback = function() playClickSound() end,
        })
        UI_Refs.cfgList = cfgList

        GB_Save:AddButton({ Text = "▶ 加载选中的配置", Callback = function()
            playClickSound()
            local name = pickName()
            if not name then return end
            local ok, err = SaveManager:Load(name)
            if ok then
                notify("配置存档", string.format("已加载配置「%s」", name), 3, "success")
                -- 加载后把界面开关同步回引擎侧变量 (applySavedToEngine 定义在构建段之后,
                -- 这里必须经 UI_Refs 回调, 否则在构建段作用域里它是 nil)
                pcall(function()
                    local f = UI_Refs and UI_Refs.applySavedToEngine
                    if f then f() end
                end)
            else
                notify("配置存档", "加载失败: " .. tostring(err), 4, "error")
            end
        end })

        GB_Save:AddButton({ Text = "🗑 删除选中的配置", Callback = function()
            playClickSound()
            local name = pickName()
            if not name then return end
            local ok, err = SaveManager:Delete(name)
            if ok then
                notify("配置存档", string.format("已删除配置「%s」", name), 3, "success")
                refreshList(); refreshAutoloadLabel()
            else
                notify("配置存档", "删除失败: " .. tostring(err), 4, "error")
            end
        end })

        GB_Save:AddButton({ Text = "🔄 刷新配置列表", Callback = function()
            playClickSound(); refreshList(); refreshAutoloadLabel()
            notify("配置存档", "列表已刷新", 2, "info")
        end })

        GB_Save:AddDivider()

        GB_Save:AddButton({ Text = "⏯ 把选中的配置设为「自动加载」", Callback = function()
            playClickSound()
            local name = pickName()
            if not name then return end
            local ok, err = SaveManager:SaveAutoloadConfig(name)
            if ok then
                notify("配置存档", string.format("下次启动将自动加载「%s」", name), 3, "success")
                refreshAutoloadLabel()
            else
                notify("配置存档", "设置失败: " .. tostring(err), 4, "error")
            end
        end })

        GB_Save:AddButton({ Text = "⏹ 取消自动加载", Callback = function()
            playClickSound()
            local ok, err = SaveManager:DeleteAutoLoadConfig()
            if ok then notify("配置存档", "已取消自动加载", 3, "info"); refreshAutoloadLabel()
            else notify("配置存档", "取消失败: " .. tostring(err), 4, "error") end
        end })

        autoloadLabel = GB_Save:AddLabel("⏯ 当前自动加载的配置: 读取中...", true)
        refreshAutoloadLabel()

        PARA(GB_Save, "💾 配置存档说明",
            "这个分区保存的是你在界面上调过的**开关 / 滑块 / 下拉 / 键绑**(例如检测阈值、踢人间隔、各项开关)。\n"
            .. "· 「新建/覆盖保存配置」: 用上面的输入框起个名字, 把当前界面设置存成一份配置。\n"
            .. "· 「设为自动加载」: 之后每次进游戏会自动恢复这份配置, 不用手动点。\n"
            .. "· 白名单是动态数据, 不走这里, 它会在「白名单」分区里单独持久化。")

        -- SaveManager 内部对这几个控件会自动加入忽略保存列表, 我们自建也要同步一下
        pcall(function() SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName" }) end)
        print("[EGG] 已用中文版配置分区替代原生 Configuration")
    end)

    -- 兜底: 万一上面那段失败(例如 SaveManager 加载失败走了空实现), 退回原生分区,
    --       至少保证功能不缺失; 建完之后同样强制固定, 防止它又能拖成悬浮窗。
    pcall(function()
        if Tabs["配置"].Groupboxes["💾 配置存档 (保存/加载界面设置)"] then return end
        if UI_Refs.hardenNoPopOut then UI_Refs.hardenNoPopOut(Tabs["配置"]) end
        SaveManager:BuildConfigSection(Tabs["配置"], "save")
        if UI_Refs.hardenNoPopOut then UI_Refs.hardenNoPopOut(Tabs["配置"]) end
        for name, gb in pairs(Tabs["配置"].Groupboxes or {}) do
            pcall(function()
                if gb.PopOutEnabled ~= false then
                    gb.PopOutEnabled = false
                    print("[EGG] 已固定分区(原生配置): " .. tostring(name))
                end
            end)
        end
    end)


    pcall(function() SaveManager:LoadAutoloadConfig() end)

    -- ★★ 收尾兜底: 只压"永远固定"的黑名单分区, 其余交给总闸 ★★
    --   走到这里时, 下面这些东西都已经建完了:
    --     · 我们自己的全部分区 (创建时按总闸 PopOutAllowed 决定)
    --     · SaveManager 的原生「Configuration」分区 (它内部是 Tab:AddGroupbox({...}) 不带 PopOut,
    --       会吃库默认值 true —— 这正是"配置页里那块原生配置还能拖成悬浮窗"的根源)
    --     · SaveManager 异步恢复配置时可能重建的分区
    --   注意: 这里**不能**无条件把所有分区压成 false, 否则「允许拖动分离成悬浮窗」开关就永远失效了。
    --   只处理黑名单 (Configuration / 高级功能说明), 其余尊重总闸。
    pcall(function()
        for _, Tab in pairs(Tabs) do
            for name, gb in pairs(Tab.Groupboxes or {}) do
                pcall(function()
                    local nm = tostring(gb.Name or ""):lower()
                    local isBlack = nm:find("configuration", 1, true)
                                 or nm:find("高级功能说明", 1, true)
                    if isBlack then
                        if gb.PoppedOut and gb.SetPoppedOut then gb:SetPoppedOut(false) end
                        if gb.PopOutEnabled ~= false then
                            gb.PopOutEnabled = false
                            print("[EGG] 已固定分区(黑名单, 禁止拖出): " .. tostring(name))
                        end
                    end
                end)
            end
        end
    end)

    -- ★再补一道延迟兜底: SaveManager 是用 task.defer 异步重放配置的, 万一在那之后
    --   又冒出新分区 (典型就是它重建 Configuration), 这个延迟任务会再扫一遍。
    --   0.6 秒足够覆盖它的异步流程。同样只处理黑名单, 不动其余分区的拖出能力。
    task.spawn(function()
        task.wait(0.6)
        pcall(function()
            for _, Tab in pairs(Tabs) do
                for _, gb in pairs(Tab.Groupboxes or {}) do
                    pcall(function()
                        local nm = tostring(gb.Name or ""):lower()
                        local isBlack = nm:find("configuration", 1, true)
                                     or nm:find("高级功能说明", 1, true)
                        if isBlack then
                            if gb.PoppedOut and gb.SetPoppedOut then gb:SetPoppedOut(false) end
                            gb.PopOutEnabled = false
                        end
                    end)
                end
            end
        end)
    end)

    end)
    if not buildOK then
        warn("[EGG] ⚠ UI 构建失败: " .. tostring(buildErr))
        print("[EGG] UI 构建失败: " .. tostring(buildErr))
        -- 让用户看到失败发生在哪一步 (截断到 300 字符, 避免刷屏)
        local msg = tostring(buildErr)
        if #msg > 300 then msg = msg:sub(1, 300) .. "..." end
        pcall(function() notify("构建失败", msg, 10, "error") end)
    end

    -- ★构建结果自检: 打印每个页签实际建出的分区数, 便于定位"某页空白"
    pcall(function()
        local names = {}
        for _, gb in ipairs(GB_All) do
            local tn = "?"
            pcall(function() tn = gb.Tab and gb.Tab.Name or "?" end)
            names[tn] = (names[tn] or 0) + 1
        end
        local parts = {}
        for k, v in pairs(names) do table.insert(parts, string.format("%s=%d", tostring(k), v)) end
        table.sort(parts)
        print("[EGG] 界面分区统计: " .. table.concat(parts, " | "))
        print(string.format("[EGG] 预设脚本库条目: %d 条", #PRESETS_CHK))
    end)
end

--//===================================================== 初始化
loadFriends()
startVoteListener()   -- 监听服务端投票事件
    -- (最后一人音乐监控已删除; 检测引擎在加载时已自连玩家名单)

-- ★诊断模式: 监听新进玩家, 打印其可识别管理标志 (pcall 保护, 缺方法的环境不报错)
pcall(function()
    Players.PlayerAdded:Connect(function(plr)
        if not CONFIG.Admin_Diagnose then return end
        task.spawn(function()
            task.wait(1)  -- 等角色/群组信息就绪
            diagnosePlayer(plr)
        end)
    end)
end)

-- ★把 Obsidian 恢复/保存的值同步回 CONFIG, 并重新应用循环状态
--   注意: 所有控件一律经 UI_Refs 取 (构建段内是 local, 顶层直接引用会拿到 nil)
local function applySavedToEngine()
    if not Library then return end
    local R = UI_Refs or {}

    local function val(name, fallback)
        local e = R[name]
        if e == nil then return fallback end
        local ok, v = pcall(function() return e.Value end)
        if ok and v ~= nil then return v end
        return fallback
    end
    local function setVal(name, v)
        local e = R[name]
        if e and e.SetValue then pcall(function() e:SetValue(v) end) end
    end

    if R.KickIntSlider     then CONFIG.AntiKick_KickInterval = val("KickIntSlider", CONFIG.AntiKick_KickInterval) end
    if R.KickNotifyToggle  then CONFIG.Kick_Notify           = val("KickNotifyToggle", CONFIG.Kick_Notify) end
    if R.KickSoundToggle   then CONFIG.Kick_Notify_Sound     = val("KickSoundToggle", CONFIG.Kick_Notify_Sound) end
    if R.WarnToggle        then CONFIG.Warn_OnVoted          = val("WarnToggle", CONFIG.Warn_OnVoted) end
    if R.DetectionEnabledToggle then CONFIG.Detection_Enabled      = val("DetectionEnabledToggle", CONFIG.Detection_Enabled) end
    if R.DetectionThresholdSlider then CONFIG.Detection_Threshold = val("DetectionThresholdSlider", CONFIG.Detection_Threshold) end
    if R.DetectionMinShotsSlider then CONFIG.Detection_MinShots  = val("DetectionMinShotsSlider", CONFIG.Detection_MinShots) end
    if R.DetectionIgnoreTeamToggle then CONFIG.Detection_IgnoreTeam = val("DetectionIgnoreTeamToggle", CONFIG.Detection_IgnoreTeam) end
    if R.StartupSoundToggle then CONFIG.Startup_Sound        = val("StartupSoundToggle", CONFIG.Startup_Sound) end

    -- ★拖动分离开关已整体删除 (所有分区固定), 这里只保留一次保险, 防止旧配置文件把它写回开启
    CONFIG.UI_DragPopout = false

    -- (脚本分支页的「加载自定义脚本」分区已删除, 不再需要恢复地址框内容)

    -- ★安全优先: 踢人开关不自动恢复 (每次进游戏都从关开始)
    setVal("KickToggle", false)
    CONFIG.AntiKick_AutoKick = false
    CONFIG.AntiKick_Enabled  = false

    -- ★安全优先: 管理员自动退出同样不自动恢复 (属危险操作, 每次进游戏需手动开)
    setVal("AdminLeaveToggle", false)
    CONFIG.Admin_AutoLeave = false
end

-- ★登记进 UI_Refs: 构建段里的「加载选中的配置」按钮要回调它,
--   但它是顶层 local, 构建段作用域里看不到, 只能走 UI_Refs 中转。
UI_Refs = UI_Refs or {}
UI_Refs.applySavedToEngine = applySavedToEngine

if Library then applySavedToEngine() end

-- ★自动保存白名单 (每 30 秒; 其余 UI 状态由 Obsidian 自带保存)
task.spawn(function()
    while task.wait(30) do
        if STATE.destroyed then break end
        saveConfig()
    end
end)

notify("EGG", "已加载 | 好友保护已启用", 4, "success")

-- ★开启动画音效: 面板构建完成后延迟一拍播放, 避开 Obsidian 加载屏的淡入
task.delay(0.6, function() playStartupSound() end)

--//===================================================== 防挂机
LocalPlayer.Idled:Connect(function()
    VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
    task.wait(1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
end)

print("[EGG] 已加载")
print(string.format("[EGG] 平台: %s", (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) and "移动端(触摸优化)" or "PC端"))
print(string.format("[EGG] 保护对象: 好友列表 + 白名单(%d 人)", #(CONFIG.Whitelist or {})))
print(string.format("[EGG] UI 库: %s | 配置持久化: %s",
    Library and "Obsidian" or "无", hasFs() and "支持" or "不支持"))
print(string.format("[EGG] 收起方式: Obsidian 窗口最小化 (点标题栏 [—]) | 切换键: %s", CONFIG.HOTKEY or "T"))
