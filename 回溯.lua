local player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")

-- 核心变量
local savedPoint = nil

-- 创建UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TimeRewindUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ===== 主面板 =====
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 160)
mainFrame.Position = UDim2.new(0.5, -110, 0.5, -80)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(100, 150, 255)
stroke.Thickness = 1.5
stroke.Transparency = 0.4
stroke.Parent = mainFrame

-- 标题
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 30)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "⏱️ 时间回溯器"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

-- 关闭按钮
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 20, 0, 20)
closeBtn.Position = UDim2.new(1, -25, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = mainFrame
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeBtn

-- 折叠按钮
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 20, 0, 20)
minBtn.Position = UDim2.new(1, -50, 0, 5)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.TextScaled = true
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = mainFrame
local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 4)
minCorner.Parent = minBtn

-- 状态提示
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 35)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "当前状态: 未记录回溯点"
statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- 设置回溯点按钮（缩小版）
local setBtn = Instance.new("TextButton")
setBtn.Size = UDim2.new(0.4, 0, 0, 35) -- 宽度改成 40%
setBtn.Position = UDim2.new(0.05, 0, 0, 75) -- 放在左边
setBtn.BackgroundColor3 = Color3.fromRGB(70, 75, 85) -- 颜色改低调一点
setBtn.Text = "📍 记录点"
setBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
setBtn.TextScaled = true
setBtn.Font = Enum.Font.GothamBold
setBtn.Parent = mainFrame
local btnCorner1 = Instance.new("UICorner")
btnCorner1.CornerRadius = UDim.new(0, 6)
btnCorner1.Parent = setBtn

-- 执行回溯按钮（放大版，醒目）
local rewindBtn = Instance.new("TextButton")
rewindBtn.Size = UDim2.new(0.45, 0, 0, 35) -- 宽度稍大
rewindBtn.Position = UDim2.new(0.5, 0, 0, 75) -- 放在右边
rewindBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60) -- 醒目的红色
rewindBtn.Text = "🔄 回溯"
rewindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rewindBtn.TextScaled = true
rewindBtn.Font = Enum.Font.GothamBold
rewindBtn.Parent = mainFrame
local btnCorner2 = Instance.new("UICorner")
btnCorner2.CornerRadius = UDim.new(0, 6)
btnCorner2.Parent = rewindBtn

-- ===== 悬浮小圆球 =====
local floatingBall = Instance.new("TextButton")
floatingBall.Size = UDim2.new(0, 45, 0, 45)
floatingBall.Position = UDim2.new(0.5, -22, 0.5, -22)
floatingBall.BackgroundColor3 = Color3.fromRGB(25, 28, 35)
floatingBall.Text = "⏱️"
floatingBall.TextColor3 = Color3.fromRGB(100, 150, 255)
floatingBall.TextScaled = true
floatingBall.Font = Enum.Font.GothamBold
floatingBall.Visible = false
floatingBall.Parent = screenGui

local ballCorner = Instance.new("UICorner")
ballCorner.CornerRadius = UDim.new(1, 0)
ballCorner.Parent = floatingBall

local ballStroke = Instance.new("UIStroke")
ballStroke.Color = Color3.fromRGB(100, 150, 255)
ballStroke.Thickness = 2
ballStroke.Transparency = 0.4
ballStroke.Parent = floatingBall

-- 小圆球拖动逻辑
local ballDragging = false
local ballDragStart = nil
local ballStartPos = nil

floatingBall.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        ballDragging = true
        ballDragStart = input.Position
        ballStartPos = floatingBall.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                ballDragging = false
            end
        end)
    end
end)

floatingBall.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if ballDragging then
            local delta = input.Position - ballDragStart
            floatingBall.Position = UDim2.new(
                ballStartPos.X.Scale, ballStartPos.X.Offset + delta.X,
                ballStartPos.Y.Scale, ballStartPos.Y.Offset + delta.Y
            )
        end
    end
end)

-- ===== 逻辑部分 =====

-- 设置回溯点
setBtn.MouseButton1Click:Connect(function()
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        savedPoint = char.HumanoidRootPart.CFrame
        statusLabel.Text = "✅ 已记录位置!"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        
        setBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
        task.wait(0.2)
        setBtn.BackgroundColor3 = Color3.fromRGB(70, 75, 85)
    else
        statusLabel.Text = "❌ 角色未加载"
        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end)

-- 执行回溯
rewindBtn.MouseButton1Click:Connect(function()
    if not savedPoint then
        statusLabel.Text = "⚠️ 请先设置回溯点!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        
        -- 清空速度防摔死
        hrp.Velocity = Vector3.new(0, 0, 0)
        -- 传送回去
        hrp.CFrame = savedPoint
        
        statusLabel.Text = "🔄 回溯成功!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    else
        statusLabel.Text = "❌ 角色未加载，无法回溯"
        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end)

-- 最小化与恢复逻辑
minBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    floatingBall.Visible = true
end)

floatingBall.MouseButton1Click:Connect(function()
    if not ballDragging then
        mainFrame.Visible = true
        floatingBall.Visible = false
    end
end)

-- 关闭UI
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)