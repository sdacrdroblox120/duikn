local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "EggFlyR6"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local introFrame = Instance.new("Frame")
introFrame.Size = UDim2.new(1, 0, 1, 0)
introFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
introFrame.Parent = gui
local introText = Instance.new("TextLabel")
introText.Size = UDim2.new(1, 0, 1, 0)
introText.Text = "EGG"
introText.TextColor3 = Color3.fromRGB(255, 215, 0)
introText.BackgroundTransparency = 1
introText.TextScaled = true
introText.Font = Enum.Font.SourceSansBold
introText.Parent = introFrame
local tweenText = TweenService:Create(introText, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { TextTransparency = 1 })
local tweenBg = TweenService:Create(introFrame, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { BackgroundTransparency = 1 })
tweenText:Play()
tweenBg:Play()
tweenBg.Completed:Connect(function()
introFrame:Destroy()
local GOLD = Color3.fromRGB(255, 215, 0)
local DARK = Color3.fromRGB(30, 30, 30)
local FULL_W, FULL_H = 185, 116
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, FULL_W, 0, FULL_H)
frame.Position = UDim2.new(0.5, -FULL_W / 2, 0.85, -FULL_H)
frame.BackgroundColor3 = DARK
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 2
frame.BorderColor3 = GOLD
frame.Active = true
frame.Draggable = false
frame.Name = "EggFlyFrame"
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
local hovering = false
local viewLock = false
local bv, bg
local speed = 40
local humanoid, root, cam
local flyDir = Vector3.new(0, 0, -1)
local lockCamCF
local ANIM_FLY = "rbxassetid://90872539"
local flyTrack
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 22)
titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = frame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)
local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -56, 1, 0)
titleText.Position = UDim2.new(0, 6, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "蛋飞行 · EGG"
titleText.TextColor3 = GOLD
titleText.Font = Enum.Font.GothamMedium
titleText.TextSize = 12
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar
local function smallBtn(txt, x)
local b = Instance.new("TextButton")
b.Size = UDim2.new(0, 20, 0, 20)
b.Position = UDim2.new(1, x, 0, 1)
b.Text = txt
b.BackgroundColor3 = DARK
b.TextColor3 = Color3.new(1, 1, 1)
b.BorderSizePixel = 1
b.BorderColor3 = GOLD
b.Font = Enum.Font.Gotham
b.TextSize = 13
b.Parent = titleBar
Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
return b
end
local collapseBtn = smallBtn("—", -44)
local closeBtn = smallBtn("X", -22)
closeBtn.TextColor3 = Color3.new(1, 0.3, 0.3)
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -22)
body.Position = UDim2.new(0, 0, 0, 22)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.Parent = frame
local function bodyBtn(txt, w, h, x, y)
local b = Instance.new("TextButton")
b.Size = UDim2.new(0, w, 0, h)
b.Position = UDim2.new(0, x, 0, y)
b.Text = txt
b.BackgroundColor3 = DARK
b.TextColor3 = Color3.new(1, 1, 1)
b.BorderSizePixel = 2
b.BorderColor3 = GOLD
b.Font = Enum.Font.Gotham
b.TextSize = 12
b.Parent = body
Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
return b
end
local flyBtn = bodyBtn("蛋飞行", 165, 26, 10, 6)
local lockBtn = bodyBtn("锁定正前视角: 关", 165, 22, 10, 36)
local function refreshModeBtns()
lockBtn.Text = "锁定正前视角: " .. (viewLock and "开" or "关")
end
lockBtn.MouseButton1Click:Connect(function()
viewLock = not viewLock
if viewLock and cam then
lockCamCF = cam.CFrame
local look = cam.CFrame.LookVector
local f = Vector3.new(look.X, 0, look.Z)
flyDir = (f.Magnitude > 1e-4) and f.Unit or Vector3.new(0, 0, -1)
end
refreshModeBtns()
end)
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0, 40, 0, 24)
speedLabel.Position = UDim2.new(0, 10, 0, 64)
speedLabel.Text = "速度:"
speedLabel.BackgroundColor3 = DARK
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.BorderSizePixel = 2
speedLabel.BorderColor3 = GOLD
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 12
speedLabel.Parent = body
Instance.new("UICorner", speedLabel).CornerRadius = UDim.new(0, 6)
local speedBox = Instance.new("TextBox")
speedBox.Size = UDim2.new(0, 125, 0, 24)
speedBox.Position = UDim2.new(0, 50, 0, 64)
speedBox.Text = "40"
speedBox.PlaceholderText = "输入速度 (≤1000)"
speedBox.ClearTextOnFocus = false
speedBox.BackgroundColor3 = DARK
speedBox.TextColor3 = Color3.new(1, 1, 1)
speedBox.BorderSizePixel = 2
speedBox.BorderColor3 = GOLD
speedBox.Font = Enum.Font.Gotham
speedBox.TextSize = 12
speedBox.Parent = body
Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 6)
speedBox.FocusLost:Connect(function()
local n = tonumber(string.match(speedBox.Text, "%d+"))
if n then speed = math.clamp(math.floor(n), 1, 1000); speedBox.Text = tostring(speed) end
end)
local function safeLoad(id)
if not humanoid then return nil end
local ok, tr = pcall(function()
local a = Instance.new("Animation")
a.AnimationId = id
local t = humanoid:LoadAnimation(a)
if t then
pcall(function() t.Priority = Enum.AnimationPriority.Action4 end)
pcall(function() t.Looped = true end)
end
return t
end)
return ok and tr or nil
end
local function preloadTrack()
flyTrack = safeLoad(ANIM_FLY)
end
local function stopFlyAnim()
if flyTrack then pcall(function() flyTrack:Stop() end) end
end
local function playFlyAnim()
if not flyTrack then flyTrack = safeLoad(ANIM_FLY) end
stopFlyAnim()
if flyTrack then pcall(function() flyTrack:Play() end) end
end
local function stopFly()
hovering = false
stopFlyAnim()
if bv then
pcall(function() bv.Velocity = Vector3.zero; bv.MaxForce = Vector3.zero end)
end
if bg then
pcall(function() bg.CFrame = root and root.CFrame or bg.CFrame; bg.MaxTorque = Vector3.zero end)
end
if humanoid then
pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
end
if root then
local rootRef = root
task.defer(function()
if bv then pcall(function() bv:Destroy() end); bv = nil end
if bg then pcall(function() bg:Destroy() end); bg = nil end
if humanoid then
pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
end
if rootRef and rootRef.Parent then
pcall(function() rootRef.AssemblyLinearVelocity = Vector3.zero end)
pcall(function() rootRef.AssemblyAngularVelocity = Vector3.zero end)
end
end)
end
flyBtn.Text = "蛋飞行"
refreshModeBtns()
end
local function startFly()
if not (humanoid and root) then return end
hovering = true
flyBtn.Text = "停止飞行"
pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Physics) end)
playFlyAnim()
bv = Instance.new("BodyVelocity")
bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
bv.Parent = root
bg = Instance.new("BodyGyro")
bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
bg.CFrame = root.CFrame * CFrame.Angles(math.rad(-90), 0, 0)
bg.Parent = root
if cam then
local look = cam.CFrame.LookVector
local f = Vector3.new(look.X, 0, look.Z)
flyDir = (f.Magnitude > 1e-4) and f.Unit or Vector3.new(0, 0, -1)
end
end
local function setupFly(char)
humanoid = char:WaitForChild("Humanoid")
root = char:WaitForChild("HumanoidRootPart")
cam = workspace.CurrentCamera
preloadTrack()
stopFly()
end
flyBtn.MouseButton1Click:Connect(function()
if hovering then stopFly() else startFly() end
end)
player.CharacterAdded:Connect(setupFly)
if player.Character then setupFly(player.Character) end
task.spawn(function()
while gui.Parent do
task.wait(0.5)
if hovering and flyTrack then
local ok, playing = pcall(function() return flyTrack.IsPlaying end)
if ok and not playing then
pcall(function() flyTrack:Play(0, 1, 1) end)
end
end
end
end)
RunService.Heartbeat:Connect(function()
if hovering and bv and root and cam and humanoid then
if viewLock then
local md = humanoid.MoveDirection
if md and md.Magnitude > 0.05 then
flyDir = Vector3.new(md.X, 0, md.Z).Unit
end
bv.Velocity = flyDir * speed
bg.CFrame = CFrame.new(root.Position, root.Position + flyDir) * CFrame.Angles(math.rad(-90), 0, 0)
else
bv.Velocity = cam.CFrame.LookVector * speed
bg.CFrame = cam.CFrame * CFrame.Angles(math.rad(-90), 0, 0)
end
end
end)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
local collapsed = false
collapseBtn.MouseButton1Click:Connect(function()
collapsed = not collapsed
body.Visible = not collapsed
if collapsed then
frame.Size = UDim2.new(0, frame.AbsoluteSize.X, 0, 30)
collapseBtn.Text = "+"
else
frame.Size = UDim2.new(0, frame.AbsoluteSize.X, 0, FULL_H)
collapseBtn.Text = "—"
end
end)
local function inRect(pos, size, p)
return p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
end
local function isPress(i)
return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end
local function clampToScreen(x, y)
local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1024, 768)
x = math.clamp(x, 0, math.max(0, vp.X - 40))
y = math.clamp(y, 0, math.max(0, vp.Y - 30))
return x, y
end
local dragging, dragStartInput, dragStartPos
UIS.InputBegan:Connect(function(i)
if not isPress(i) then return end
local p = i.Position
if inRect(titleBar.AbsolutePosition, titleBar.AbsoluteSize, p)
and not inRect(collapseBtn.AbsolutePosition, collapseBtn.AbsoluteSize, p)
and not inRect(closeBtn.AbsolutePosition, closeBtn.AbsoluteSize, p) then
dragging = true
dragStartInput = p
dragStartPos = frame.AbsolutePosition
end
end)
UIS.InputChanged:Connect(function(i)
if not (dragging and isMove(i)) then return end
local nx, ny = clampToScreen(dragStartPos.X + (i.Position.X - dragStartInput.X),
dragStartPos.Y + (i.Position.Y - dragStartInput.Y))
frame.Position = UDim2.new(0, nx, 0, ny)
end)
UIS.InputEnded:Connect(function(i)
if isPress(i) then dragging = false end
end)
end)
