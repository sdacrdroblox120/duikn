--[[
================================================================================
  EGG  ·  防御 + 在线音乐  —  Obsidian 版 (第十九轮 · UI 重构)
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
    -- ★最后一人音乐 (队伍仅剩自己一人时播放 funk/phonk)
    Music_Enabled       = true,     -- ★音乐总开关 (关=任何情况都不放音乐)
    Music_LastMan       = true,     -- 最后一人音乐自动触发开关
    Music_Volume        = 0.5,      -- 音乐音量(0~1)
    Music_Speed         = 1.0,      -- 音乐倍速(0.5~2.0)
    Music_CustomList    = {},       -- ★自定义歌单 (为空则随机播默认曲风)
    -- ★踢人通知 (Obsidian 通知卡片 + 提示音)
    Kick_Notify          = true,    -- 通知总开关
    Kick_Notify_Sound    = true,    -- 提示音开关
    Kick_SoundId         = "rbxassetid://112972396921894",
    Kick_SoundVolume     = 0.25,    -- 音量(0~1), 刻意调低不打扰
    UI_ClickSound        = true,     -- ★UI 点击音效 (开关/按钮/滑块等交互反馈)
    Startup_Sound        = true,     -- ★开启动画音效开关 (脚本加载完成时播放)
    Startup_SoundId      = "rbxassetid://100102530391513",
    Startup_SoundVolume  = 0.5,      -- 开机音效音量(0~1)

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
}

--//===================================================== 配置持久化 (仅白名单动态数据)
local function hasFs()
    return type(writefile) == "function" and type(readfile) == "function"
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
        Library:Notify(tostring(title or "") .. ": " .. tostring(text or ""), duration)
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
        notify("好友列表", string.format("已加载 -- %d 人", count), 3, "success")
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

--- ★UI 点击音效 (开关/按钮/滑块/下拉/键绑交互反馈; 复用提示音同一音源, 略调高音量+音高)
local function playClickSound()
    if not CONFIG.UI_ClickSound then return end
    local now = os.clock()
    if STATE.lastClick and (now - STATE.lastClick) < 0.09 then return end  -- 节流, 防滑块拖动连发
    STATE.lastClick = now
    playSound("Click", CONFIG.Kick_SoundId, math.min(1, (CONFIG.Kick_SoundVolume or 0.25) * 1.6), 1.25)
end

--- ★开启动画音效 (脚本加载完成 / 面板首次弹出时播放)
local function playStartupSound()
    if not CONFIG.Startup_Sound then return end
    pcall(function()
        local snd = Instance.new("Sound")
        snd.Name = "EGG_StartupSound"
        snd.SoundId = CONFIG.Startup_SoundId
        snd.Volume = CONFIG.Startup_SoundVolume or 0.5
        snd.Looped = false
        snd.Parent = SoundService
        snd:Play()
        -- 播放完毕自动清理
        local conn
        conn = snd.Ended:Connect(function()
            pcall(function() if conn then conn:Disconnect() end end)
            pcall(function() snd:Destroy() end)
        end)
        -- 万一 Ended 不触发(死链), 15 秒后兜底清理
        task.delay(15, function()
            pcall(function() if snd.Parent then snd:Destroy() end end)
        end)
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
local ADMIN_MARKERS = {"Admin", "IsAdmin", "VIP", "AdminTag", "Rank"}
local function isAdminPlayer(plr)
    if not plr or plr == LocalPlayer then return false end
    -- 1) 群组 rank 判定
    if CONFIG.Admin_GroupId and CONFIG.Admin_GroupId > 0 then
        local ok, rank = pcall(function() return plr:GetRoleInGroup(CONFIG.Admin_GroupId) end)
        if ok and rank and rank >= (CONFIG.Admin_MinRank or 100) then return true end
    end
    -- 2) 名字名单 (精确匹配)
    if CONFIG.Admin_Names then
        for _, n in ipairs(CONFIG.Admin_Names) do
            if n == plr.Name then return true end
        end
    end
    -- 3) 角色内标记 (常见于私服/自写管理脚本给玩家挂的标识)
    local char = pcall(function() return plr.Character end) and plr.Character or nil
    for _, m in ipairs(ADMIN_MARKERS) do
        if pcall(function() return plr:FindFirstChild(m) end) then return true end
        if char and pcall(function() return char:FindFirstChild(m) end) then return true end
    end
    return false
end

--- 启动管理员监控 (每 0.1 秒扫描全服; 仅当开关开启时才真正运行)
local function startAdminWatch()
    if STATE.adminWatch then return end
    STATE.adminWatch = task.spawn(function()
        while CONFIG.Admin_AutoLeave and not STATE.destroyed do
            for _, plr in ipairs(Players:GetPlayers()) do
                if isAdminPlayer(plr) then
                    pcall(function()
                        notify("管理员检测", "检测到管理员 -- " .. tostring(plr.Name) .. " | 自动退出", 6, "error")
                        LocalPlayer:Kick("EGG: 检测到管理员 " .. tostring(plr.Name) .. ", 已自动退出以保护账号")
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

--//===================================================== ★ 音乐引擎 (网易云 · NeteaseCloudMusic 接口)
-- 说明: 最后一人音乐的音源, 由「在线曲库接口」实时驱动, 不再使用硬编码音频 ID。
--   支持登录自己的网易云账号 (cookie), 登录后按账号权限取曲 (含 VIP)。
--   ★ 接口地址为第三方 Cloudflare Worker, 若失效可在 音乐页 → 接口设置 里替换。

--- ★前向声明: stopLastManMusic / getPreferredSong 定义在本段之后, 但 playNeteaseSong 需要先引用
---   (Lua 5.1 中若不做前向声明, 函数体会把它编译成全局 _G.xxx = nil, 运行时直接崩)
local stopLastManMusic
local getPreferredSong

--//----------------------------- 配置
CONFIG.Music_Api = CONFIG.Music_Api or "https://ncm-api.meisdad321.workers.dev"
CONFIG.Music_Cookie = CONFIG.Music_Cookie or ""      -- 账号 cookie (登录后自动写入)
CONFIG.Music_Quality = CONFIG.Music_Quality or "exhigh"  -- 音质: standard/higher/exhigh/lossless

-- ★ 可变接口地址: 统一走 CONFIG.Music_Api 读取, 保证 UI 里改了立刻生效
--   (不用 local 缓存, 否则 UI 回调里赋值只会改到全局, 不生效)
local CookieFile = "EGG_MusicCookie.json"

--- 默认曲风关键词池 (没自定义歌单时, 从中随机取一个词去搜)
local MUSIC_DEFAULT_KEYWORDS = {
    "无敌少侠", "高燃FUNK", "phonk", "funk", "brazilian funk",
    "中文DJ", "dj舞曲", "车载dj", "dj慢摇", "phonk drift",
}
--- 默认曲风搜索结果缓存 (关键词 -> 歌曲数组)
local MUSIC_DEFAULT_CACHE = {}

--//----------------------------- 基础工具
--- URL 编码
local function musicUrlEncode(s)
    return (tostring(s or ""):gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

--- 原始 HTTP 请求 (优先执行器 request, 退回 game:HttpGet)
--- 返回 res 表 {Body=..., StatusCode=...} 或 nil
local function musicRaw(path, noCookie)
    local url = (CONFIG.Music_Api or "") .. path
    if not noCookie and CONFIG.Music_Cookie and CONFIG.Music_Cookie ~= "" then
        local sep = path:find("?", 1, true) and "&" or "?"
        url = url .. sep .. "cookie=" .. musicUrlEncode(CONFIG.Music_Cookie)
    end
    local req = (type(_G.syn) == "table" and _G.syn.request)
             or _G.request or _G.http_request or _G.httprequest
    if req then
        local ok, res = pcall(function()
            return req({ Url = url, Method = "GET" })
        end)
        if ok and type(res) == "table" and type(res.Body) == "string" and res.Body ~= "" then
            return res
        end
    end
    local ok2, body = pcall(function() return game:HttpGet(url, true) end)
    if ok2 and type(body) == "string" and body ~= "" then
        return { Body = body, StatusCode = 200 }
    end
    return nil
end

--- 取接口并解析 JSON
local function musicApiGet(path)
    local res = musicRaw(path)
    if not res then return nil end
    local ok, d = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if ok and type(d) == "table" then return d end
    return nil
end

--- 判断响应体是否为错误页 (非音频)
local function musicIsErrBody(b)
    if type(b) ~= "string" then return true end
    local h = b:sub(1, 1)
    if h == "{" or h == "<" then return true end
    if #b < 1024 then return true end
    return false
end

--//----------------------------- Cookie 持久化
local function musicSaveCookie()
    if not hasFs() then return end
    pcall(function()
        writefile(CookieFile, HttpService:JSONEncode({ v = 1, cookie = CONFIG.Music_Cookie }))
    end)
end

local function musicLoadCookie()
    if not hasFs() then return end
    local ok, raw = pcall(readfile, CookieFile)
    if not ok or not raw then return end
    local ok2, d = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok2 and type(d) == "table" and type(d.cookie) == "string" and d.cookie ~= "" then
        CONFIG.Music_Cookie = d.cookie
    end
end

--//----------------------------- 业务接口
--- 搜索歌曲: 返回 { {id,name,artist,dur,fee,artistId}, ... }
local function musicSearch(keyword, limit)
    if not keyword or keyword == "" then return {} end
    local d = musicApiGet("/search?keywords=" .. musicUrlEncode(keyword) .. "&limit=" .. tostring(limit or 30))
    if not d or not d.result or not d.result.songs then return {} end
    local out = {}
    for _, s in ipairs(d.result.songs) do
        local names = {}
        local firstArtistId = ""
        local ars = s.artists or s.ar or {}
        if type(ars) == "table" then
            for i, a in ipairs(ars) do
                if type(a) == "table" and a.name then
                    table.insert(names, tostring(a.name))
                    if i == 1 and a.id then firstArtistId = tostring(a.id) end
                end
            end
        end
        table.insert(out, {
            id = tostring(s.id),
            name = tostring(s.name or "未知"),
            artist = (#names > 0) and table.concat(names, " / ") or "未知",
            dur = math.floor(tonumber(s.duration or s.dt or 0) / 1000),
            fee = tonumber(s.fee or 0),
            artistId = firstArtistId,
        })
    end
    return out
end

--- 取播放直链 (返回 url 字符串 或 nil,err)
local function musicGetUrl(id)
    local d = musicApiGet("/song/url/v1?id=" .. tostring(id) .. "&level=" .. tostring(CONFIG.Music_Quality or "exhigh"))
    if d and d.data and d.data[1] and d.data[1].url then return d.data[1].url end
    return nil, "无播放地址 (VIP/下架/需登录)"
end

--- 取歌词 (LRC 原文)
local function musicGetLyric(id)
    local d = musicApiGet("/lyric?id=" .. tostring(id))
    if d and d.lrc and d.lrc.lyric then return d.lrc.lyric end
    return ""
end

--- 查账号状态 (登录态/是否VIP/昵称)
local function musicQueryVip()
    local d = musicApiGet("/vip")
    if d and d.ok then
        return { ok = true, isVip = (d.isVip == true),
                 nickname = tostring(d.nickname or ""), vipName = tostring(d.vipName or "VIP") }
    end
    return { ok = false }
end

--- 发送短信验证码
local function musicSendSms(phone)
    return musicApiGet("/login/sms?phone=" .. musicUrlEncode(phone))
end

--- 校验验证码并完成登录 (成功后写入 cookie)
local function musicVerifySms(phone, code)
    local d = musicApiGet("/login/verify?phone=" .. musicUrlEncode(phone) .. "&code=" .. musicUrlEncode(code))
    if d and (d.cookie or (d.data and d.data.cookie)) then
        local ck = d.cookie or d.data.cookie
        CONFIG.Music_Cookie = tostring(ck)
        musicSaveCookie()
        return true, ck
    end
    return false, (d and (d.message or d.msg)) or "验证失败"
end

--- 挑一首「默认曲风」的歌 (带缓存; 排除最近播过的)
local function pickDefaultGenreSong()
    local hist = {}
    for _, id in ipairs(STATE.musicHistory or {}) do hist[tostring(id)] = true end
    local kw = MUSIC_DEFAULT_KEYWORDS[math.random(1, #MUSIC_DEFAULT_KEYWORDS)]
    local list = MUSIC_DEFAULT_CACHE[kw]
    if not list then
        list = musicSearch(kw, 30)
        MUSIC_DEFAULT_CACHE[kw] = list
    end
    if #list == 0 then
        -- 缓存空(可能网络抖动), 清掉再试一个别的关键词
        MUSIC_DEFAULT_CACHE[kw] = nil
        for _, other in ipairs(MUSIC_DEFAULT_KEYWORDS) do
            if other ~= kw then
                local l2 = MUSIC_DEFAULT_CACHE[other] or musicSearch(other, 30)
                MUSIC_DEFAULT_CACHE[other] = l2
                if #l2 > 0 then list = l2; break end
            end
        end
    end
    if #list == 0 then return nil end
    local pool = {}
    for _, s in ipairs(list) do
        if not hist[tostring(s.id)] then table.insert(pool, s) end
    end
    if #pool == 0 then pool = list end
    return pool[math.random(1, #pool)]
end

--- 下载音频到本地并返回可播放 asset 路径
--- ★ 关键: 先走 Worker 的 /dl (带 cookie, 可拿 VIP 曲), 失败再退回直链
local function musicDownloadToAsset(song)
    if not song then return nil, "无歌曲" end
    local getAsset  = _G.getcustomasset or _G.getsynasset
    local writeFile = _G.writefile
    local isFile    = _G.isfile
    local makeFolder= _G.makefolder
    if not (getAsset and writeFile) then return nil, "注入器缺少 getcustomasset/writefile" end

    local dir = "EGG_MusicCache"
    pcall(function() if makeFolder and not (_G.isfolder and _G.isfolder(dir)) then makeFolder(dir) end end)
    local path = dir .. "/" .. tostring(song.id) .. ".mp3"

    local exists = false
    pcall(function() exists = isFile and isFile(path) end)

    if not exists then
        local body
        -- ① 优先: Worker 侧带 cookie 下载 (VIP 曲也能拿)
        local res = musicRaw("/dl?id=" .. tostring(song.id))
        if res and type(res.Body) == "string" and not musicIsErrBody(res.Body) then
            body = res.Body
        end
        -- ② 退回: 取直链自行下载
        if not body then
            local link = musicGetUrl(song.id)
            if link then
                local req = (type(_G.syn) == "table" and _G.syn.request)
                         or _G.request or _G.http_request or _G.httprequest
                if req then
                    local ok, r2 = pcall(function()
                        return req({ Url = link, Method = "GET",
                            Headers = { ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                                        ["Referer"] = "https://music.163.com/",
                                        ["Accept"] = "*/*" } })
                    end)
                    if ok and r2 and type(r2.Body) == "string" and not musicIsErrBody(r2.Body) then
                        body = r2.Body
                    end
                end
                if not body then
                    local ok3, r3 = pcall(function() return game:HttpGet(link, true) end)
                    if ok3 and type(r3) == "string" and not musicIsErrBody(r3) then body = r3 end
                end
            end
        end
        if not body then return nil, "下载失败 (可能 VIP 未登录/下架)" end
        local okw = pcall(writeFile, path, body)
        if not okw then
            local p2 = path:gsub("/", "\\")
            if not pcall(writeFile, p2, body) then return nil, "写入文件失败" end
            path = p2
        end
    end

    local okA, asset = pcall(getAsset, path)
    if okA and asset then return asset end
    return nil, "getcustomasset 失败"
end

musicLoadCookie()
--- 播放一首歌 (异步: 搜索/下载在后台, 不卡主线程)
--- onDone(ok, errOrName) 回调可选
local function playNeteaseSong(song, onDone)
    if not song then if onDone then onDone(false, "无歌曲") end return end
    if not CONFIG.Music_Enabled then if onDone then onDone(false, "音乐总开关已关") end return end
    stopLastManMusic()
    STATE.musicPlaying = true
    STATE.musicTrack = { id = song.id, name = song.name .. " - " .. song.artist, genre = "netease" }
    if onDone then onDone(true, STATE.musicTrack.name) end
    task.spawn(function()
        local asset, err = musicDownloadToAsset(song)
        if STATE.destroyed or not STATE.musicPlaying then return end
        if not asset then
            notify("音乐", "播放失败 -- " .. tostring(err), 3, "error")
            return
        end
        -- 记录历史(排除最近 2 首)
        STATE.musicHistory = STATE.musicHistory or {}
        table.insert(STATE.musicHistory, 1, tostring(song.id))
        while #STATE.musicHistory > 2 do table.remove(STATE.musicHistory) end
        stopLastManMusic()
        STATE.musicPlaying = true
        STATE.musicTrack = { id = song.id, name = song.name .. " - " .. song.artist, genre = "netease" }
        pcall(function()
            local s = Instance.new("Sound")
            s.Name = "EGG_LastManMusic"
            s.SoundId = asset
            s.Volume = CONFIG.Music_Volume or 0.5
            s.PlaybackSpeed = CONFIG.Music_Speed or 1
            s.Looped = false
            s.Parent = SoundService
            STATE.musicSound = s
            local conn
            conn = s.Ended:Connect(function()
                pcall(function() if conn then conn:Disconnect() end end)
                if STATE.musicPlaying and not STATE.destroyed and CONFIG.Music_Enabled then
                    local nxt = getPreferredSong()
                    if nxt then playNeteaseSong(nxt) end
                else
                    if STATE.musicSound == s then STATE.musicSound = nil end
                end
            end)
            s:Play()
            -- 歌词 (可选, 打印到控制台)
            task.spawn(function()
                local lrc = musicGetLyric(song.id)
                if lrc and lrc ~= "" then
                    STATE.musicLyric = lrc
                    print("[EGG音乐] 歌词已获取: " .. song.name)
                end
            end)
        end)
    end)
end

--- 取一首「优先歌曲」: 有自定义歌单就播歌单, 否则播默认曲风
getPreferredSong = function()
    local list = CONFIG.Music_CustomList or {}
    if #list > 0 then
        return list[math.random(1, #list)]
    end
    return pickDefaultGenreSong()
end

--- 最后一人音乐历史 (最近播放完的 2 首 ID, 用于「接下来 2 首不重复」)
STATE.musicHistory = STATE.musicHistory or {}

--- 停止音乐 (总停止)
stopLastManMusic = function()
    STATE.musicPlaying = false
    if STATE.musicSound and STATE.musicSound.Parent then
        pcall(function() STATE.musicSound:Stop() end)
        pcall(function() STATE.musicSound:Destroy() end)
    end
    STATE.musicSound = nil
    STATE.musicTrack = nil
end

--- 手动随机播放一首 (试听; 受总开关约束)
local function playRandomMusic()
    if not CONFIG.Music_Enabled then
        notify("音乐", "音乐总开关已关, 先开启再试听", 2.5, "warn")
        return
    end
    local song = getPreferredSong()
    if not song then
        notify("音乐", "没搜到歌 (可能网络波动), 稍后再试", 3, "warn")
        return
    end
    notify("音乐", "加载中 -- " .. song.name, 2.5, "info")
    playNeteaseSong(song)
end

--- 触发最后一人音乐 + 双通知
local function triggerLastManMusic()
    if not CONFIG.Music_Enabled then return end
    STATE.musicPlaying = true
    local song = getPreferredSong()
    if song then
        playNeteaseSong(song)
    else
        notify("音乐", "拉取歌曲失败 (网络波动), 稍后自动重试", 3, "warn")
    end
    notify("最后一人", "蜀道艰险，粮草如何运送？北伐空耗国力，不如效仿东吴。五虎仅剩一人，谁敢当北伐先锋？", 9, "info")
    task.wait(0.45)
    notify("最后一人", "既承先帝遗志，怎能困守不前！！！若贼寇将十万之众！吾当为脚本尽歼！！纵敌军举天下进犯！延亦可勠力拒退！！", 9, "info")
end

--- 监控: 队伍仅剩自己一人(且自己活着)时播放; ★玩家死亡立即停 (队友加入不停, 本游戏一局不复活)
local function startLastManWatch()
    if STATE.lastManWatch then return end
    STATE.lastManWatch = task.spawn(function()
        local wasLastMan = false
        while task.wait(0.3) and not STATE.destroyed do
            local myTeam = LocalPlayer.Team
            local alive = 0
            if myTeam then
                for _, plr in ipairs(myTeam:GetPlayers()) do
                    local char = plr.Character
                    local hum  = char and char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then alive = alive + 1 end
                end
            end
            local myChar = LocalPlayer.Character
            local myHum  = myChar and myChar:FindFirstChildOfClass("Humanoid")
            local selfAlive = myHum and myHum.Health > 0
            local isLastMan = CONFIG.Music_LastMan and CONFIG.Music_Enabled
                             and myTeam and alive == 1 and selfAlive
            -- ★玩家死亡: 立即停 (否则就给别人放音乐了)
            if STATE.musicPlaying and not selfAlive then
                stopLastManMusic()
                notify("最后一人", "你已阵亡 -- 音乐停止", 3, "info")
            elseif isLastMan and not wasLastMan and not STATE.musicPlaying then
                triggerLastManMusic()
            end
            wasLastMan = isLastMan
        end
        STATE.lastManWatch = nil
    end)
end


--//===================================================== 加载 Obsidian (UI 库)
local function loadObsidian()
    local urls = {
        "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua",
    }
    for _, url in ipairs(urls) do
        local ok, lib = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if ok and lib then return lib end
    end
    return nil
end

loadConfig()          -- ★先读白名单, 让白名单下拉初始选项正确
Library = loadObsidian()
if not Library then
    warn("[EGG] Obsidian 加载失败, UI 无法显示 (后台逻辑仍运行)")
    print("[EGG] 请检查执行器网络或手动替换 Obsidian 源")
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

local Window, PlayerTab, MusicTab, SettingsTab, BranchTab
local KickToggle, KickIntSlider
local KickNotifyToggle, KickSoundToggle, WarnToggle, WLBox, WLListDropdown
local AdminLeaveToggle, AdminGroupBox, AdminNamesBox
local MusicLastManToggle, MusicVolSlider, MusicEnabledToggle, MusicSpeedSlider
local StartupSoundToggle
local NMSearchBox, NMResultDropdown, NMPlayBtn, NMCustomBox, NMCustomDropdown
local ExtUrlBox, ExtListDropdown, ExtRunBtn
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

    local req = (type(_G.syn) == "table" and _G.syn.request)
             or _G.request or _G.http_request or _G.httprequest
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

if Library then
    local repoObsidian = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
    local ThemeManager = loadstring(game:HttpGet(repoObsidian .. "addons/ThemeManager.lua"))()
    local SaveManager  = loadstring(game:HttpGet(repoObsidian .. "addons/SaveManager.lua"))()
    local Options = Library.Options
    local Toggles = Library.Toggles

    Library.ForceCheckbox = false
    Library.ShowToggleFrameInKeybinds = true

    local Window = Library:CreateWindow({
        Title = "EGG",
        Footer = "防御 + 音乐",
        Icon = 95816097006870,
        NotifySide = "Right",
        ShowCustomCursor = true,
    })
    SaveManager:SetLibrary(Library)
    SaveManager:SetFolder("EGG")

    local Tabs = {
        ["防御"]     = Window:AddTab("防御", "shield"),
        ["音乐"]     = Window:AddTab("音乐", "music"),
        ["脚本分支"] = Window:AddTab("脚本分支", "package"),
        ["配置"]     = Window:AddTab("配置", "settings"),
    }

    --//===================== 防御页
    local GB_Kick = Tabs["防御"]:AddLeftGroupbox("🛡 踢人")
    KickToggle = GB_Kick:AddToggle("Kick", {
        Text = "🛡 ★ 踢人 (自动循环)",
        Default = CONFIG.AntiKick_AutoKick,
        Callback = function(v)
            playClickSound(); CONFIG.AntiKick_AutoKick = v; CONFIG.AntiKick_Enabled = v
            if v then startAutoKick(); notify("踢人", string.format("已开启 -- 每 %.1f 秒自动投票", CONFIG.AntiKick_KickInterval), 3, "success")
            else stopAutoKick(); notify("踢人", "已关闭", 2.5, "info") end
        end,
    })
    KickIntSlider = GB_Kick:AddSlider("KickInterval", {
        Text = "⏱ 踢人间隔", Default = CONFIG.AntiKick_KickInterval, Min = 0.1, Max = 10, Rounding = 1,
        Callback = function(v) playClickSound(); CONFIG.AntiKick_KickInterval = v end,
    })

    local GB_Shield = Tabs["防御"]:AddLeftGroupbox("🛡 反踢护盾")
    GB_Shield:AddToggle("AntiKickShield", {
        Text = "🛡 ★ 反踢护盾 (拦截踢人远程 + 反作弊调用)",
        Default = CONFIG.AntiKick_Shield,
        Callback = function(v)
            playClickSound(); CONFIG.AntiKick_Shield = v
            if v then AntiKickShield.enable() else AntiKickShield.disable() end
        end,
    })
    GB_Shield:AddParagraph("🛡 反踢护盾说明",
        "纯防御: 拦下 RequestPlayerKick 等踢人远程, 并阻断 LocalClean / CharacterControl 的本地调用, 循环禁用本机 CharacterControl。 "
        .. "不修改任何游戏状态、不提供玩法优势。开启后控制台输入 EGG_AntiKickShield.stats() 查看拦截计数。")

    local GB_Notify = Tabs["防御"]:AddLeftGroupbox("🔔 通知")
    KickNotifyToggle = GB_Notify:AddToggle("KickNotify", {
        Text = "🔔 ★ 踢人通知", Default = CONFIG.Kick_Notify,
        Callback = function(v) playClickSound(); CONFIG.Kick_Notify = v; notify("踢人通知", v and "已开启" or "已关闭", 2.5, v and "success" or "info") end,
    })
    KickSoundToggle = GB_Notify:AddToggle("KickSound", {
        Text = "🔊 提示音", Default = CONFIG.Kick_Notify_Sound,
        Callback = function(v) playClickSound(); CONFIG.Kick_Notify_Sound = v; if v then playKickSound() end; notify("提示音", v and "已开启" or "已静音", 2.5, v and "success" or "info") end,
    })
    WarnToggle = GB_Notify:AddToggle("WarnVoted", {
        Text = "🗳 ★ 被投票时提醒我", Default = CONFIG.Warn_OnVoted,
        Callback = function(v) playClickSound(); CONFIG.Warn_OnVoted = v; notify("被投提醒", v and "已开启 -- 有人投你会立即提醒" or "已关闭", 2.5, v and "success" or "info") end,
    })

    local GB_Admin = Tabs["防御"]:AddLeftGroupbox("🛡 管理员防护")
    AdminLeaveToggle = GB_Admin:AddToggle("AdminAutoLeave", {
        Text = "🛡 ★ 检测到管理员自动退出", Default = CONFIG.Admin_AutoLeave,
        Callback = function(v) playClickSound(); CONFIG.Admin_AutoLeave = v; if v then startAdminWatch() end; notify("管理员检测", v and "已开启 -- 检测到管理员将自动退出" or "已关闭", 2.5, v and "success" or "info") end,
    })
    AdminGroupBox = GB_Admin:AddInput("AdminGroupId", {
        Text = "🆔 管理员群组 ID (留空=不按群组判定)", Default = (CONFIG.Admin_GroupId and CONFIG.Admin_GroupId ~= 0) and tostring(CONFIG.Admin_GroupId) or "",
        Placeholder = "如 123456", Numeric = true,
        Callback = function(v)
            playClickSound(); local n = tonumber((v or ""):match("%d+")) or 0; CONFIG.Admin_GroupId = n
            notify("管理员检测", n > 0 and ("已设置群组 ID -- " .. n) or "已关闭群组判定", 2.5, n > 0 and "success" or "info")
        end,
    })
    AdminNamesBox = GB_Admin:AddInput("AdminNames", {
        Text = "📛 管理员名字名单 (逗号分隔, 精确匹配)", Default = table.concat(CONFIG.Admin_Names or {}, ","),
        Placeholder = "如 aaa,bbb",
        Callback = function(v)
            playClickSound(); local list = {}
            for name in string.gmatch(v or "", "[^,]+") do name = name:match("^%s*(.-)%s*$"); if name ~= "" then table.insert(list, name) end end
            CONFIG.Admin_Names = list; notify("管理员检测", "已更新名单 -- " .. #list .. " 人", 2.5, "info")
        end,
    })
    GB_Admin:AddParagraph("🛡 管理员检测说明",
        "开启后每 0.1 秒扫描全服: 命中『群组 rank ≥ 设定值 / 名字在名单 / 角色带 Admin 标记』任一即自动踢出自己。 "
        .. "需补充本服判定依据 (群组 ID 或名字名单) 才能稳定识别, 详见聊天说明。")
    GB_Admin:AddToggle("AdminDiagnose", {
        Text = "🩺 诊断模式 (打印管理标志到控制台)", Default = CONFIG.Admin_Diagnose,
        Callback = function(v)
            playClickSound(); CONFIG.Admin_Diagnose = v
            if v then for _, p in ipairs(Players:GetPlayers()) do task.spawn(function() diagnosePlayer(p) end) end
                notify("管理员诊断", "已开启 -- 新进玩家信号将打印到控制台(F9)", 3, "info")
            else notify("管理员诊断", "已关闭", 2.5, "info") end
        end,
    })

    --//===================== 音乐页
    local GB_MusicMain = Tabs["音乐"]:AddLeftGroupbox("🎚 音乐总开关")
    MusicEnabledToggle = GB_MusicMain:AddToggle("MusicEnabled", {
        Text = "🎚 ★ 音乐开关 (总开关)", Default = CONFIG.Music_Enabled,
        Callback = function(v) playClickSound(); CONFIG.Music_Enabled = v
            if not v then stopLastManMusic(); notify("音乐", "已关闭 -- 所有音乐停止", 2.5, "info") else notify("音乐", "已开启", 2.5, "success") end end,
    })

    local GB_LastMan = Tabs["音乐"]:AddLeftGroupbox("🎯 最后一人音乐")
    MusicLastManToggle = GB_LastMan:AddToggle("MusicLastMan", {
        Text = "🎯 ★ 最后一人音乐 (队伍仅剩你时播放)", Default = CONFIG.Music_LastMan,
        Callback = function(v) playClickSound(); CONFIG.Music_LastMan = v
            if not v then stopLastManMusic(); notify("音乐", "已关闭 -- 最后一人音乐", 2.5, "info") else notify("音乐", "已开启 -- 队伍仅剩你一人时放音乐", 2.5, "success") end end,
    })
    MusicVolSlider = GB_LastMan:AddSlider("MusicVolume", {
        Text = "🔉 音乐音量", Default = CONFIG.Music_Volume, Min = 0, Max = 1, Rounding = 2,
        Callback = function(v) playClickSound(); CONFIG.Music_Volume = v; if STATE.musicSound and STATE.musicSound.Parent then pcall(function() STATE.musicSound.Volume = v end) end end,
    })
    MusicSpeedSlider = GB_LastMan:AddSlider("MusicSpeed", {
        Text = "⏩ 音乐倍速", Default = CONFIG.Music_Speed, Min = 0.5, Max = 2, Rounding = 2,
        Callback = function(v) playClickSound(); CONFIG.Music_Speed = v; if STATE.musicSound and STATE.musicSound.Parent then pcall(function() STATE.musicSound.PlaybackSpeed = v end) end end,
    })
    GB_LastMan:AddButton({ Text = "🎲 试听一首 (随机点歌)", Callback = function() playClickSound(); playRandomMusic() end })
    GB_LastMan:AddButton({ Text = "⏹ 停止音乐", Callback = function() playClickSound(); stopLastManMusic(); notify("音乐", "已停止", 2, "info") end })
    GB_LastMan:AddParagraph("🎯 最后一人音乐说明",
        "『音乐开关』为总开关: 关掉则任何情况都不放音乐。开『最后一人音乐』后, 当队伍里"
        .. "『只剩你一个活人』时, 自动从『在线曲库』随机点歌并弹双通知; 一首放完自动连播下一首。本游戏一局不复活, "
        .. "故队友加入不会关音乐, 但你阵亡会立刻停止 (绝不给别人放音乐)。")

    local GB_Lib = Tabs["音乐"]:AddLeftGroupbox("🎧 在线曲库 (搜索/播放)")
    NMSearchBox = GB_Lib:AddInput("NMSearch", {
        Text = "🔍 搜索歌曲 (输入后按回车)", Default = "", Placeholder = "如 周杰伦 / phonk / 中文dj",
        Callback = function(v)
            playClickSound(); if not v or v == "" then return end
            local list = musicSearch(v, 30)
            if #list == 0 then notify("音乐", "没搜到结果 (换个词或检查网络)", 3, "warn"); return end
            STATE.nmResults = list; local names = {}
            for _, s in ipairs(list) do table.insert(names, s.name .. " - " .. s.artist) end
            pcall(function() NMResultDropdown:Refresh(names) end)
            notify("音乐", "搜到 " .. #list .. " 首, 下拉选择即可播放", 3, "success")
        end,
    })
    NMResultDropdown = GB_Lib:AddDropdown("NMResult", {
        Text = "📋 搜索结果 (选一首播放)", Values = { "（先在上方搜索）" }, Default = 1,
        Callback = function(opt)
            playClickSound(); if not opt or opt == "（先在上方搜索）" then return end
            local list = STATE.nmResults or {}
            for i, s in ipairs(list) do if (s.name .. " - " .. s.artist) == opt then notify("音乐", "加载中 -- " .. s.name, 2.5, "info"); playNeteaseSong(s); return end end
        end,
    })
    GB_Lib:AddButton({ Text = "▶ 播放 / 试听 (随机默认曲风)", Callback = function() playClickSound(); playRandomMusic() end })
    GB_Lib:AddButton({ Text = "⏹ 停止播放", Callback = function() playClickSound(); stopLastManMusic(); notify("音乐", "已停止", 2, "info") end })

    local GB_Playlist = Tabs["音乐"]:AddLeftGroupbox("📀 自定义歌单 (优先播放)")
    NMCustomBox = GB_Playlist:AddInput("NMCustomAdd", {
        Text = "➕ 添加歌曲到歌单 (输入歌名回车)", Default = "", Placeholder = "如 红色高跟鞋DJ版",
        Callback = function(v)
            playClickSound(); if not v or v == "" then return end
            local list = musicSearch(v, 1)
            if #list == 0 then notify("歌单", "没搜到这首歌, 换个关键词", 3, "warn"); return end
            local song = list[1]; CONFIG.Music_CustomList = CONFIG.Music_CustomList or {}; table.insert(CONFIG.Music_CustomList, song)
            local names = {}; for _, s in ipairs(CONFIG.Music_CustomList) do table.insert(names, s.name .. " - " .. s.artist) end
            pcall(function() NMCustomDropdown:Refresh(names) end)
            notify("歌单", "已加入: " .. song.name .. " (共 " .. #CONFIG.Music_CustomList .. " 首)", 3, "success")
            pcall(function() NMCustomDropdown:Refresh(names, true) end)
        end,
    })
    NMCustomDropdown = GB_Playlist:AddDropdown("NMCustom", {
        Text = "📀 我的歌单 (选一首播放)", Values = { "（歌单为空 · 将随机播默认曲风）" }, Default = 1,
        Callback = function(opt)
            playClickSound(); if not opt or opt:find("歌单为空") then return end
            for _, s in ipairs(CONFIG.Music_CustomList or {}) do if (s.name .. " - " .. s.artist) == opt then notify("音乐", "加载中 -- " .. s.name, 2.5, "info"); playNeteaseSong(s); return end end
        end,
    })
    GB_Playlist:AddButton({ Text = "🗑 清空我的歌单", Callback = function() playClickSound(); CONFIG.Music_CustomList = {}; pcall(function() NMCustomDropdown:Refresh({ "（歌单为空 · 将随机播默认曲风）" }, true) end); notify("歌单", "已清空 -- 之后随机播默认曲风", 3, "warn") end })
    GB_Playlist:AddParagraph("🎵 音乐引擎说明",
        "最后一人音乐由『网易云在线曲库』实时驱动, 不再使用硬编码音频 ID。"
        .. "没添加自定义歌单时, 自动随机搜播『无敌少侠 / 高燃FUNK / phonk / 中文DJ』; 在『添加歌曲到歌单』里输入歌名(回车)即可存入自己的歌单, 有歌单时优先播你的歌。"
        .. "注意: 播放需要注入器支持 writefile / getcustomasset (下载后本地播放)。")

    local GB_Account = Tabs["音乐"]:AddLeftGroupbox("🔑 账号登录 (听完整版/VIP)")
    NMAccountPara = GB_Account:AddParagraph("当前状态: 未登录",
        "登录后可播放你账号权限内的歌曲 (含 VIP 完整版)。⭐ 建议使用小号 —— cookie 会发往第三方接口服务, 请自行评估账号风险。登录信息只保存在本机配置里。")
    NMPhoneBox = GB_Account:AddInput("NMPhone", { Text = "① 手机号", Default = "", Placeholder = "输入网易云绑定手机号", Callback = function() playClickSound() end })
    GB_Account:AddButton({ Text = "📨 ② 发送验证码", Callback = function()
        playClickSound(); local phone = ""; pcall(function() phone = tostring(NMPhoneBox.Value or "") end)
        if phone == "" then notify("登录", "请先填手机号", 2.5, "warn"); return end
        notify("登录", "正在发送验证码...", 2, "info"); task.spawn(function()
            local d = musicSendSms(phone)
            if d and not d.code then notify("登录", "验证码已发送, 请查收短信 ✅", 4, "success")
            else notify("登录", "发送失败: " .. tostring((d and (d.message or d.msg)) or "接口无响应"), 5, "error") end
        end)
    end })
    NMCodeBox = GB_Account:AddInput("NMCode", { Text = "③ 验证码", Default = "", Placeholder = "输入短信收到的验证码", Callback = function() playClickSound() end })
    GB_Account:AddButton({ Text = "✅ ④ 登录", Callback = function()
        playClickSound(); local phone, code = "", ""
        pcall(function() phone = tostring(NMPhoneBox.Value or "") end); pcall(function() code = tostring(NMCodeBox.Value or "") end)
        if phone == "" or code == "" then notify("登录", "手机号和验证码都要填", 2.5, "warn"); return end
        notify("登录", "正在验证...", 2, "info"); task.spawn(function()
            local ok, info = musicVerifySms(phone, code)
            if ok then notify("登录", "登录成功 🎉 正在读取账号信息", 3, "success"); local v = musicQueryVip()
                local who = (v and v.ok and v.nickname ~= "") and v.nickname or "已登录"
                local tag = (v and v.ok and v.isVip) and (" ・ " .. tostring(v.vipName or "VIP")) or ""
                pcall(function() NMAccountPara:Set({ Title = "当前状态: " .. who .. tag, Content = "已登录, 可播放你账号权限内的歌曲。想换号点下方『退出登录』。" }) end)
            else notify("登录", "登录失败: " .. tostring(info), 5, "error") end
        end)
    end })
    GB_Account:AddButton({ Text = "🚪 退出登录 (清除 cookie)", Callback = function()
        playClickSound(); CONFIG.Music_Cookie = ""; musicSaveCookie()
        pcall(function() NMAccountPara:Set({ Title = "当前状态: 未登录", Content = "已清除本机保存的登录信息。" }) end)
        notify("登录", "已退出登录", 2.5, "info")
    end })
    GB_Account:AddButton({ Text = "🔄 刷新账号状态", Callback = function()
        playClickSound(); if CONFIG.Music_Cookie == "" then notify("登录", "当前未登录", 2.5, "warn"); return end
        task.spawn(function() local v = musicQueryVip()
            if v and v.ok then local who = (v.nickname ~= "") and v.nickname or "已登录"; local tag = v.isVip and (" ・ " .. tostring(v.vipName or "VIP")) or ""
                pcall(function() NMAccountPara:Set({ Title = "当前状态: " .. who .. tag, Content = "账号状态正常。" }) end)
                notify("登录", "状态: " .. who .. tag, 3, "success")
            else notify("登录", "账号状态查询失败 (cookie 可能已过期)", 4, "error") end
        end)
    end })

    local GB_Api = Tabs["音乐"]:AddLeftGroupbox("⚙ 接口设置")
    NMApiBox = GB_Api:AddInput("NMApi", {
        Text = "🌐 接口地址 (Cloudflare Worker)", Default = CONFIG.Music_Api, Placeholder = "https://your-worker.workers.dev",
        Callback = function(v) playClickSound(); if v and v ~= "" then CONFIG.Music_Api = v; notify("接口设置", "已更新接口地址", 2.5, "success") end end,
    })
    NMQualityDropdown = GB_Api:AddDropdown("NMQuality", {
        Text = "🎼 音质", Values = { "standard", "higher", "exhigh", "lossless" }, Default = (function() for i,v in ipairs({"standard","higher","exhigh","lossless"}) do if v == (CONFIG.Music_Quality or "exhigh") then return i end end return 3 end)(),
        Callback = function(opt) playClickSound(); CONFIG.Music_Quality = opt; notify("接口设置", "音质: " .. tostring(opt), 2, "info") end,
    })
    GB_Api:AddButton({ Text = "🔍 测试接口连通性", Callback = function() playClickSound(); notify("接口设置", "正在测试...", 2, "info"); task.spawn(function()
        local list = musicSearch("test", 1)
        if #list > 0 then notify("接口设置", "接口正常 ✅ 搜到: " .. list[1].name, 4, "success") else notify("接口设置", "接口无响应 ❌ 可能已失效, 请更换地址", 5, "error") end
    end) end })
    GB_Api:AddParagraph("🌐 接口说明",
        "本音乐引擎依赖第三方 Cloudflare Worker 接口。若某天搜不到歌, 说明该接口已失效, 在上方『接口地址』里换成你自建或可用的地址即可。登录 cookie 会一并发送给该接口用于取 VIP 曲。")

    --//===================== 配置页
    local GB_WL = Tabs["配置"]:AddLeftGroupbox("📝 白名单 (只保护本服玩家)")
    WLBox = GB_WL:AddInput("WLInput", {
        Text = "➕ 加入白名单 (输入本服玩家名)", Default = "", Placeholder = "如 a",
        Callback = function(v)
            playClickSound(); if not v or v == "" then return end
            local ok, msg = addWhitelist(v)
            if ok then pcall(function() WLListDropdown:Refresh(CONFIG.Whitelist) end); notify("白名单", msg, 3, "success")
            else notify("白名单", msg, 3, "warn") end
        end,
    })
    WLListDropdown = GB_WL:AddDropdown("WLList", {
        Text = "📝 白名单列表 (点选后移除)", Values = CONFIG.Whitelist, Default = 1,
        Callback = function() playClickSound() end,
    })
    GB_WL:AddButton({ Text = "➖ 移除所选白名单", Callback = function()
        playClickSound(); local opt = WLListDropdown and WLListDropdown.Value
        if not opt then notify("白名单", "未选择要移除的人", 2.5, "warn"); return end
        for i, n in ipairs(CONFIG.Whitelist) do if n == opt then removeWhitelist(i); pcall(function() WLListDropdown:Refresh(CONFIG.Whitelist) end); notify("白名单", "已移除 -- " .. n, 2.5, "info"); return end end
        notify("白名单", "未找到 -- " .. tostring(opt), 2.5, "warn")
    end })
    GB_WL:AddButton({ Text = "💾 立即保存白名单", Callback = function()
        playClickSound(); if not hasFs() then notify("配置", "当前执行器不支持文件读写, 关游戏后会重置", 4, "error"); return end
        if saveConfig() then notify("白名单", "已保存 -- " .. #CONFIG.Whitelist .. " 人", 3, "success") else notify("白名单", "保存失败", 3, "error") end
    end })

    local GB_Conf = Tabs["配置"]:AddLeftGroupbox("⚙ 配置")
    GB_Conf:AddButton({ Text = "↩ 重置所有设置为默认", Callback = function()
        playClickSound()
        pcall(function() KickToggle:SetValue(false) end)
        pcall(function() KickIntSlider:SetValue(2.0) end)
        pcall(function() KickNotifyToggle:SetValue(true) end)
        pcall(function() KickSoundToggle:SetValue(true) end)
        pcall(function() WarnToggle:SetValue(true) end)
        pcall(function() if MusicEnabledToggle and MusicEnabledToggle.SetValue then MusicEnabledToggle:SetValue(true) end end)
        pcall(function() if MusicLastManToggle and MusicLastManToggle.SetValue then MusicLastManToggle:SetValue(true) end end)
        pcall(function() if MusicVolSlider and MusicVolSlider.SetValue then MusicVolSlider:SetValue(0.5) end end)
        pcall(function() if MusicSpeedSlider and MusicSpeedSlider.SetValue then MusicSpeedSlider:SetValue(1.0) end end)
        pcall(function() if StartupSoundToggle and StartupSoundToggle.SetValue then StartupSoundToggle:SetValue(true) end end)
        CONFIG.AntiKick_AutoKick = false; CONFIG.AntiKick_Enabled = false; CONFIG.AntiKick_KickInterval = 2.0
        CONFIG.Kick_Notify = true; CONFIG.Kick_Notify_Sound = true; CONFIG.Warn_OnVoted = true
        CONFIG.Music_Enabled = true; CONFIG.Music_LastMan = true; CONFIG.Music_Speed = 1.0; CONFIG.Startup_Sound = true
        CONFIG.Whitelist = {}; CONFIG.Admin_AutoLeave = false; CONFIG.Admin_GroupId = 0; CONFIG.Admin_Names = {}
        pcall(function() AdminLeaveToggle:SetValue(false) end)
        pcall(function() if AdminGroupBox and AdminGroupBox.SetValue then AdminGroupBox:SetValue("") end end)
        pcall(function() if AdminNamesBox and AdminNamesBox.SetValue then AdminNamesBox:SetValue("") end end)
        stopAutoKick(); pcall(function() WLListDropdown:Refresh({}) end)
        notify("配置", "已重置为默认", 3, "warn")
    end })
    GB_Conf:AddParagraph("⚙ 配置说明",
        "开关/滑块/下拉/键绑由 Obsidian 自动保存 (下次进游戏自动恢复); 白名单列表为动态数据, 走本地文件单独持久化。")

    local GB_Startup = Tabs["配置"]:AddLeftGroupbox("🎬 开启动画音效")
    StartupSoundToggle = GB_Startup:AddToggle("StartupSound", {
        Text = "🎬 ★ 开启动画音效 (脚本加载完成时播放)", Default = CONFIG.Startup_Sound,
        Callback = function(v) playClickSound(); CONFIG.Startup_Sound = v
            if v then playStartupSound(); notify("开启动画", "已开启 -- 下次加载时播放", 2.5, "success") else notify("开启动画", "已关闭", 2.5, "info") end
        end,
    })
    GB_Startup:AddButton({ Text = "🎵 试听开启动画音效", Callback = function() playClickSound(); local keep = CONFIG.Startup_Sound; CONFIG.Startup_Sound = true; playStartupSound(); CONFIG.Startup_Sound = keep; notify("开启动画", "试听中...", 2, "info") end })
    GB_Startup:AddParagraph("🎬 开启动画音效说明", "脚本加载完成、面板首次弹出时播放的开场音效。")

    local uiKeyLabel = Tabs["配置"]:AddLabel("⌨ 显示/隐藏面板键")
    uiKeyLabel:AddKeyPicker("UIToggleKey", { Text = "切换面板", Default = CONFIG.HOTKEY or "T", Mode = "Toggle" })
    Toggles.UIToggleKey:OnClick(function()
        pcall(function() if Library.ScreenGui then Library.ScreenGui.Enabled = not Library.ScreenGui.Enabled end end)
    end)

    --//===================== 脚本分支页
    local GB_Builtin = Tabs["脚本分支"]:AddLeftGroupbox("📦 内置分支")
    GB_Builtin:AddParagraph("说明", "这里可以加载独立的子脚本, 不占用主脚本代码。已加载过的脚本会自动去重, 不会重复执行。")
    GB_Builtin:AddButton({ Text = "🎵 音乐功能位置提示", Callback = function() playClickSound(); notify("音乐", "音乐功能已内置到「音乐」页 🎵 直接切到音乐页使用即可", 4, "info") end })
    GB_Builtin:AddButton({ Text = "🔫 加载无限子弹脚本 (塔菲)", Callback = function() playClickSound(); task.spawn(function() runRemoteScript("https://raw.githubusercontent.com/sdacrdroblox120/duikn/refs/heads/main/%E5%A1%94%E8%8F%B2%E8%84%9A%E6%9C%AC.txt", "无限子弹 (塔菲)", false) end) end })
    GB_Builtin:AddButton({ Text = "🗑 重置加载记录 (允许再次加载)", Callback = function() playClickSound(); STATE.loadedScripts = {}; notify("脚本分支", "已清空加载记录, 所有脚本可重新加载", 3, "info") end })

    local GB_Custom = Tabs["脚本分支"]:AddLeftGroupbox("🔗 加载自定义脚本")
    ExtUrlBox = GB_Custom:AddInput("ExtScriptUrl", { Text = "🔗 脚本地址 (raw 链接, 需以 .lua/.txt 结尾)", Placeholder = "https://raw.githubusercontent.com/用户/仓库/main/脚本.lua", Callback = function(v) CONFIG.ExtScripts_LastUrl = v end })
    GB_Custom:AddButton({ Text = "▶ 加载并运行该脚本", Callback = function() playClickSound(); local url = ""; pcall(function() url = ExtUrlBox.Value end)
        if type(url) ~= "string" or url == "" then notify("脚本分支", "请先填写脚本地址", 3, "error"); return end
        task.spawn(function() runRemoteScript(url, "自定义脚本", false) end)
    end })
    local GB_List = Tabs["脚本分支"]:AddLeftGroupbox("📋 脚本列表")
    ExtListDropdown = GB_List:AddDropdown("ExtScriptPick", {
        Text = "📦 已保存的脚本 (点选即加载)", Values = (function() local o = {}; for _, it in ipairs(CONFIG.ExtScripts or {}) do table.insert(o, it.name) end; return (#o > 0 and o) or {"(暂无, 用上方地址框添加)"} end)(), Default = 1,
        Callback = function(opt) playClickSound(); for _, item in ipairs(CONFIG.ExtScripts or {}) do if item.name == opt then task.spawn(function() runRemoteScript(item.url, item.name, false) end); return end end
    end })
    GB_List:AddButton({ Text = "＋ 把当前地址保存到列表", Callback = function() playClickSound(); local url = ""; pcall(function() url = ExtUrlBox.Value end)
        if type(url) ~= "string" or url == "" then notify("脚本分支", "请先填写脚本地址", 3, "error"); return end
        CONFIG.ExtScripts = CONFIG.ExtScripts or {}; local shortName = string.match(url, "([^/]+)$") or ("脚本" .. (#CONFIG.ExtScripts + 1))
        for _, item in ipairs(CONFIG.ExtScripts) do if item.url == url then notify("脚本分支", "该地址已在列表中", 3, "info"); return end end
        table.insert(CONFIG.ExtScripts, { name = shortName, url = url }); local opts = {}; for _, item in ipairs(CONFIG.ExtScripts) do table.insert(opts, item.name) end
        pcall(function() ExtListDropdown:Refresh(opts) end); saveConfig(); notify("脚本分支", string.format("已保存: %s", shortName), 3, "success")
    end })
    GB_List:AddButton({ Text = "🗑 删除列表中的选中项", Callback = function() playClickSound(); local cur = nil; pcall(function() cur = ExtListDropdown.Value end)
        if not cur then notify("脚本分支", "请先在下拉框选中一项", 3, "error"); return end
        local newList = {}; for _, item in ipairs(CONFIG.ExtScripts or {}) do if item.name ~= cur then table.insert(newList, item) end end
        CONFIG.ExtScripts = newList; local opts = {}; for _, item in ipairs(newList) do table.insert(opts, item.name) end
        if #opts == 0 then opts = {"(暂无, 用上方地址框添加)"} end
        pcall(function() ExtListDropdown:Refresh(opts) end); saveConfig(); notify("脚本分支", "已删除", 3, "info")
    end })
    GB_List:AddParagraph("⚙ 高级", "若加载失败, 多半是执行器不支持 loadstring 或网络受限。可改用 execute 类执行器, 或把脚本下载后手动执行。音乐功能已内置到「音乐」页, 不需要再通过这里加载播放器。")

    pcall(function() SaveManager:LoadAutoloadConfig() end)
end

--//===================================================== 初始化
loadFriends()
startVoteListener()   -- 监听服务端投票事件
startLastManWatch()   -- 监控队伍是否仅剩自己一人, 触发最后一人音乐

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
local function applySavedToEngine()
    if not Library then return end
    CONFIG.AntiKick_KickInterval = KickIntSlider.Value
    CONFIG.Kick_Notify           = KickNotifyToggle.Value
    CONFIG.Kick_Notify_Sound     = KickSoundToggle.Value
    CONFIG.Warn_OnVoted          = WarnToggle.Value
    CONFIG.Music_Enabled         = MusicEnabledToggle.Value
    CONFIG.Music_LastMan         = MusicLastManToggle.Value
    CONFIG.Music_Volume          = MusicVolSlider.Value
    CONFIG.Music_Speed           = MusicSpeedSlider.Value
    CONFIG.Startup_Sound         = StartupSoundToggle.Value
    CONFIG.Admin_AutoLeave       = AdminLeaveToggle.Value

    -- ★脚本分支: 恢复上次填写的地址与脚本列表
    pcall(function() CONFIG.ExtScripts_LastUrl = ExtUrlBox.Value end)

    -- ★安全优先: 踢人开关不自动恢复 (每次进游戏都从关开始)
    pcall(function() KickToggle:SetValue(false) end)
    CONFIG.AntiKick_AutoKick = false
    CONFIG.AntiKick_Enabled  = false

    -- ★管理员检测: 若上次开着, 重新启动监控
    if CONFIG.Admin_AutoLeave then startAdminWatch() end
end

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
