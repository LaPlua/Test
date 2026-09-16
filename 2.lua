local Library = {}
Library.__index = Library
Library.Name = "VerticalDualColumnUI"
Library.Version = "1.0.0"

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local DEFAULT_THEME = {
	Name = "Midnight",
	Background = Color3.fromRGB(8, 11, 27),
	Window = Color3.fromRGB(13, 17, 38),
	Panel = Color3.fromRGB(17, 22, 49),
	PanelAlt = Color3.fromRGB(22, 27, 61),
	Stroke = Color3.fromRGB(56, 64, 115),
	Accent = Color3.fromRGB(124, 92, 255),
	Accent2 = Color3.fromRGB(37, 173, 255),
	Text = Color3.fromRGB(238, 241, 255),
	Muted = Color3.fromRGB(150, 157, 192),
	Success = Color3.fromRGB(72, 221, 146),
	Warning = Color3.fromRGB(255, 190, 92),
	Error = Color3.fromRGB(255, 94, 124),
	Shadow = Color3.fromRGB(0, 0, 0),
}

local FLAGS: { [string]: any } = {}
local CONFIG_BINDINGS: { [string]: { any } } = {}
local ELEMENTS: { any } = {}
local WINDOWS: { any } = {}
local TRANSPARENCY_CACHE = setmetatable({}, { __mode = "k" })
local ACTIVE_THEME = table.clone(DEFAULT_THEME)
local VANTA_FONT = Font.new("rbxassetid://12187371840")
local DESKTOP_TEXT_SIZE = 15

local function isTextObject(object: Instance)
	return object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")
end

local function useDesktopTextSize()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return not (UserInputService.TouchEnabled and size.X < 900)
end

local function platformTextSize(size: number)
	return useDesktopTextSize() and DESKTOP_TEXT_SIZE or size
end

local function tween(instance: Instance, info: TweenInfo, props: { [string]: any })
	local t = TweenService:Create(instance, info, props)
	t:Play()
	return t
end

local function make(className: string, props: { [string]: any }?, children: { Instance }?)
	local object = Instance.new(className)
	if props then
		for key, value in pairs(props) do
			(object :: any)[key] = value
		end
	end
	if not useDesktopTextSize() and isTextObject(object) then
		(object :: any).FontFace = VANTA_FONT
		local s1 = Instance.new("UIStroke")
		s1.Thickness = 0.8
		s1.Color = Color3.new(0, 0, 0)
		s1.Parent = object
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = object
		end
	end
	return object
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color: Color3, transparency: number?, thickness: number?)
	return make("UIStroke", {
		Color = color,
		Transparency = transparency or 0,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(all: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
	})
end

local function paddingXY(x: number, y: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
	})
end

local function label(text: string, size: number, color: Color3, weight: Enum.Font?)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextSize = size,
		Font = weight or Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function buttonBase(text: string)
	return make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		Text = text,
		TextColor3 = ACTIVE_THEME.Text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

local function bindTheme(object: Instance, prop: string, key: string, alpha: number?)
	local item = {
		Object = object,
		Property = prop,
		Key = key,
		Alpha = alpha,
		Apply = function(self: any)
			if self.Object and self.Object.Parent then
				(self.Object :: any)[self.Property] = ACTIVE_THEME[self.Key]
				if self.Object:IsA("UIStroke") and self.Alpha then
					self.Object.Transparency = self.Alpha
				end
			end
		end,
	}
	table.insert(ELEMENTS, item)
	item:Apply()
	return item
end

local function applyTheme()
	for _, item in ipairs(ELEMENTS) do
		item:Apply()
	end
	for _, window in ipairs(WINDOWS) do
		if window.ActiveTab then
			window:_refreshTabButtons()
		end
	end
end

local function mergeTheme(theme: { [string]: any })
	local nextTheme = table.clone(DEFAULT_THEME)
	for key, value in pairs(ACTIVE_THEME) do
		nextTheme[key] = value
	end
	for key, value in pairs(theme) do
		nextTheme[key] = value
	end
	ACTIVE_THEME = nextTheme
	Library.Theme = ACTIVE_THEME
	applyTheme()
end

local function viewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function isMobile()
	local size = viewportSize()
	return UserInputService.TouchEnabled and size.X < 900
end

local function setFlag(flag: string?, value: any)
	if not flag then
		return
	end
	FLAGS[flag] = value
end

local function safeCall(callback: ((any) -> ())?, value: any)
	if callback then
		task.spawn(callback, value)
	end
end

local function safeCallArgs(callback: any, ...: any)
	if callback then
		task.spawn(callback, ...)
	end
end

local function shouldFireInitialCallback(options: { [string]: any })
	return options.Default ~= nil and options.Callback ~= nil and options.InitCallback ~= false
end

local function normalizeBindMode(value: any)
	return string.lower(tostring(value or "Toggle")) == "hold" and "Hold" or "Toggle"
end

local function normalizeBind(value: any, fallback: any?)
	if typeof(value) == "EnumItem" then
		if value == Enum.KeyCode.Escape then
			return nil
		end
		return value
	end
	if typeof(value) == "string" then
		local lower = string.lower(value)
		if lower == "none" or lower == "nil" or lower == "escape" or lower == "esc" then
			return nil
		end

		local keyCode = (Enum.KeyCode :: any)[value]
		if keyCode then
			if keyCode == Enum.KeyCode.Escape then
				return nil
			end
			return keyCode
		end

		local userInputType = (Enum.UserInputType :: any)[value]
		if userInputType == Enum.UserInputType.MouseButton1 or userInputType == Enum.UserInputType.MouseButton2 then
			return userInputType
		end

		if lower == "mouse1" or lower == "m1" or lower == "leftmouse" or lower == "leftclick" then
			return Enum.UserInputType.MouseButton1
		elseif lower == "mouse2" or lower == "m2" or lower == "rightmouse" or lower == "rightclick" then
			return Enum.UserInputType.MouseButton2
		end
	end
	return fallback or Enum.KeyCode.F
end

local function bindDisplay(value: any)
	if value == nil then
		return "None"
	end
	if value == Enum.UserInputType.MouseButton1 then
		return "Mouse1"
	elseif value == Enum.UserInputType.MouseButton2 then
		return "Mouse2"
	elseif typeof(value) == "EnumItem" then
		return value.Name
	end
	return tostring(value)
end

local function bindDisplayWithMode(value: any, mode: any)
	return bindDisplay(value)
end

local function bindFlagValue(value: any)
	if value == nil then
		return "None"
	end
	if typeof(value) == "EnumItem" then
		return value.Name
	end
	return tostring(value)
end

local function bindFromInput(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Escape then
		return nil, true
	end
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.MouseButton2
	then
		return input.UserInputType
	end
	if input.KeyCode ~= Enum.KeyCode.Unknown then
		return input.KeyCode
	end
	return nil
end

local function inputMatchesBind(input: InputObject, bind: any)
	if bind == nil then
		return false
	end
	if bind == Enum.UserInputType.MouseButton1 or bind == Enum.UserInputType.MouseButton2 then
		return input.UserInputType == bind
	end
	return input.KeyCode == bind
end

local function envFunction(name: string)
	local env = getfenv() :: any
	return env[name]
end

local function getGuiParent()
	local gethui = envFunction("gethui")
	if typeof(gethui) == "function" then
		local ok, result = pcall(gethui)
		if ok and typeof(result) == "Instance" then
			return result
		end
	end

	local get_hidden_gui = envFunction("get_hidden_gui")
	if typeof(get_hidden_gui) == "function" then
		local ok, result = pcall(get_hidden_gui)
		if ok and typeof(result) == "Instance" then
			return result
		end
	end

	return CoreGui or PlayerGui
end

local function canUseFiles()
	return typeof(envFunction("writefile")) == "function" and typeof(envFunction("readfile")) == "function"
end

local function sanitizeConfigName(name: string)
	return (name:gsub("[^%w_%-]", "_"))
end

local function configPath(name: string)
	local safeName = sanitizeConfigName(name)
	local isfolder = envFunction("isfolder")
	local makefolder = envFunction("makefolder")
	if typeof(isfolder) == "function" and typeof(makefolder) == "function" then
		return "VerticalDualColumnUI/" .. safeName .. ".json"
	end
	return "VerticalDualColumnUI_" .. safeName .. ".json"
end

local function encodeValue(value: any)
	if typeof(value) == "Color3" then
		return {
			__type = "Color3",
			r = value.R,
			g = value.G,
			b = value.B,
		}
	elseif typeof(value) == "EnumItem" then
		return {
			__type = "EnumItem",
			enum = tostring(value.EnumType),
			name = value.Name,
		}
	elseif typeof(value) == "table" then
		local encoded = {}
		for key, child in pairs(value) do
			encoded[key] = encodeValue(child)
		end
		return encoded
	end
	return value
end

local function decodeValue(value: any)
	if typeof(value) == "table" then
		if value.__type == "Color3" then
			return Color3.new(value.r or 0, value.g or 0, value.b or 0)
		elseif value.__type == "EnumItem" then
			local enumName = tostring(value.enum or ""):gsub("^Enum%.", "")
			local enumType = (Enum :: any)[enumName]
			if enumType and enumType[value.name] then
				return enumType[value.name]
			end
			return value.name
		end

		local decoded = {}
		for key, child in pairs(value) do
			decoded[key] = decodeValue(child)
		end
		return decoded
	end
	return value
end

local function registerConfigBinding(flag: string?, control: any)
	if not flag then
		return
	end
	CONFIG_BINDINGS[flag] = CONFIG_BINDINGS[flag] or {}
	table.insert(CONFIG_BINDINGS[flag], control)
end

local function syncBoundControls(silent: boolean?)
	for flag, controls in pairs(CONFIG_BINDINGS) do
		local value = FLAGS[flag]
		for _, control in ipairs(controls) do
			if control and control.Set then
				control:Set(value, silent == true)
			end
			if control and control.SyncConfig then
				control:SyncConfig(silent == true)
			end
		end
	end
end

local function ensureConfigFolder()
	local isfolder = envFunction("isfolder")
	local makefolder = envFunction("makefolder")
	if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder("VerticalDualColumnUI") then
		makefolder("VerticalDualColumnUI")
	end
end

local function configExists(path: string)
	local isfile = envFunction("isfile")
	if typeof(isfile) == "function" then
		return isfile(path)
	end

	local readfile = envFunction("readfile")
	if typeof(readfile) == "function" then
		local ok = pcall(function()
			readfile(path)
		end)
		return ok
	end
	return false
end

local function deleteConfig(name: string)
	local delfile = envFunction("delfile") or envFunction("deletefile")
	if typeof(delfile) ~= "function" then
		return false, "Delete unavailable"
	end

	local path = configPath(name)
	if not configExists(path) then
		return false, "Config not found"
	end

	local ok = pcall(function()
		delfile(path)
	end)
	if ok then
		return true, ""
	end
	return false, "Delete failed"
end

local function listConfigNames()
	local names = {}
	local seen = {}
	local listfiles = envFunction("listfiles")
	if typeof(listfiles) == "function" then
		local ok, files = pcall(listfiles, "VerticalDualColumnUI")
		if ok and typeof(files) == "table" then
			for _, path in ipairs(files) do
				local text = tostring(path)
				local name = text:match("([^/\\]+)%.json$")
				if name and not seen[name] then
					seen[name] = true
					table.insert(names, name)
				end
			end
		end
	end
	table.sort(names)
	return names
end

local function readPingMs()
	local okString, valueString = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
	end)
	if okString and typeof(valueString) == "string" then
		local numberText = string.match(valueString, "%d+%.?%d*")
		if numberText then
			return math.floor((tonumber(numberText) or 0) + 0.5)
		end
	end

	local okValue, value = pcall(function()
		return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if okValue and typeof(value) == "number" then
		return math.floor(value + 0.5)
	end

	return 0
end

local function currentClockText()
	local ok, result = pcall(os.date, "%H:%M")
	if ok and typeof(result) == "string" then
		return result
	end
	return "00:00"
end

local function formatFpsText(fps: number)
	return string.format("%d FPS", math.clamp(fps, 0, 999))
end

local function formatPingText(ping: number)
	return string.format("%d ms", math.clamp(ping, 0, 999))
end

local function makeCard(parent: Instance, title: string, height: number?)
	local card = make("Frame", {
		BackgroundColor3 = ACTIVE_THEME.Panel,
		Size = UDim2.new(1, 0, 0, height or 58),
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		corner(10),
		stroke(ACTIVE_THEME.Stroke, 0.45),
		padding(12),
	})
	bindTheme(card, "BackgroundColor3", "Panel")
	bindTheme(card:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.45)

	local titleLabel = label(title, 13, ACTIVE_THEME.Text, Enum.Font.GothamSemibold)
	titleLabel.Size = UDim2.new(1, 0, 0, 18)
	titleLabel.Parent = card
	bindTheme(titleLabel, "TextColor3", "Text")

	return card, titleLabel
end

local function attachListSizing(scroll: ScrollingFrame)
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if not layout then
		return
	end
	local function update()
		scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 14)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	task.defer(update)
end

local function attachHorizontalListSizing(scroll: ScrollingFrame)
	local layout = scroll:FindFirstChildOfClass("UIListLayout")
	if not layout then
		return
	end
	local function update()
		scroll.CanvasSize = UDim2.new(0, layout.AbsoluteContentSize.X + 14, 0, 0)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update)
	task.defer(update)
end

local function setGroupTransparency(root: Instance, transparency: number)
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			item.TextTransparency = transparency
		end
		if item:IsA("ImageLabel") or item:IsA("ImageButton") then
			item.ImageTransparency = transparency
		end
	end
end

local function tweenGroupTransparency(root: Instance, transparency: number, duration: number)
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			tween(item, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = transparency,
			})
		elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
			tween(item, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				ImageTransparency = transparency,
			})
		end
	end
end

local function cacheTransparency(item: Instance, property: string)
	local map = TRANSPARENCY_CACHE[item]
	if not map then
		map = {}
		TRANSPARENCY_CACHE[item] = map
	end
	if map[property] == nil then
		map[property] = (item :: any)[property]
	end
end

local function cachedTransparency(item: Instance, property: string, fallback: number)
	local map = TRANSPARENCY_CACHE[item]
	if not map or map[property] == nil then
		return fallback
	end
	return map[property]
end

local function cacheGuiContentTransparency(root: Instance)
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("GuiObject") and item ~= root then
			cacheTransparency(item, "BackgroundTransparency")
		end
		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			cacheTransparency(item, "TextTransparency")
		end
		if item:IsA("ImageLabel") or item:IsA("ImageButton") then
			cacheTransparency(item, "ImageTransparency")
		end
		if item:IsA("ScrollingFrame") then
			cacheTransparency(item, "ScrollBarImageTransparency")
		end
		if item:IsA("UIStroke") then
			cacheTransparency(item, "Transparency")
		end
	end
end

local function tweenGuiContentTransparency(root: Instance, transparency: number, duration: number, restore: boolean?)
	for _, item in ipairs(root:GetDescendants()) do
		local props = {}
		if item:IsA("GuiObject") and item ~= root then
			cacheTransparency(item, "BackgroundTransparency")
			props.BackgroundTransparency = restore and cachedTransparency(item, "BackgroundTransparency", 1)
				or transparency
		end
		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			cacheTransparency(item, "TextTransparency")
			props.TextTransparency = restore and math.min(cachedTransparency(item, "TextTransparency", 0), 0.98)
				or transparency
		end
		if item:IsA("ImageLabel") or item:IsA("ImageButton") then
			cacheTransparency(item, "ImageTransparency")
			props.ImageTransparency = restore and cachedTransparency(item, "ImageTransparency", 0) or transparency
		end
		if item:IsA("ScrollingFrame") then
			cacheTransparency(item, "ScrollBarImageTransparency")
			props.ScrollBarImageTransparency = restore and cachedTransparency(item, "ScrollBarImageTransparency", 0)
				or transparency
		end
		if next(props) then
			tween(item, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		end
		if item:IsA("UIStroke") then
			cacheTransparency(item, "Transparency")
			tween(item, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = restore and cachedTransparency(item, "Transparency", 0) or transparency,
			})
		end
	end
end

local function animateColumn(column: ScrollingFrame, direction: number)
	local finalPosition = column.Position
	column.Position = UDim2.new(
		finalPosition.X.Scale,
		finalPosition.X.Offset + (direction * 14),
		finalPosition.Y.Scale,
		finalPosition.Y.Offset
	)
	column.CanvasPosition = Vector2.zero
	setGroupTransparency(column, 1)
	tween(column, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = finalPosition })
	task.delay(0.03, function()
		if column.Parent then
			for _, item in ipairs(column:GetDescendants()) do
				if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
					tween(
						item,
						TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ TextTransparency = 0 }
					)
				elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
					tween(
						item,
						TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ ImageTransparency = 0 }
					)
				end
			end
		end
	end)
end

local function makeDraggable(handle: GuiObject, target: GuiObject, canDrag: () -> boolean)
	local dragging = false
	local dragStart = Vector2.zero
	local startPosition = UDim2.new()
	local positionTween: Tween? = nil

	local function moveTo(position: UDim2)
		if positionTween then
			positionTween:Cancel()
		end
		positionTween = tween(target, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = position,
		})
	end

	handle.InputBegan:Connect(function(input)
		if not canDrag() then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPosition = target.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and canDrag()
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			local delta = position - dragStart
			moveTo(
				UDim2.new(
					startPosition.X.Scale,
					startPosition.X.Offset + delta.X,
					startPosition.Y.Scale,
					startPosition.Y.Offset + delta.Y
				)
			)
		end
	end)
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

function Library:SetTheme(theme: { [string]: any })
	mergeTheme(theme)
	return self
end

function Library:GetTheme()
	return table.clone(ACTIVE_THEME)
end

function Library:GetFlags()
	return FLAGS
end

function Library:Notify(options: { [string]: any })
	local target = WINDOWS[#WINDOWS]
	if target then
		return target:Notify(options)
	end
end

function Library:SaveConfig(name: string)
	local encodedFlags = {}
	for key, value in pairs(FLAGS) do
		encodedFlags[key] = encodeValue(value)
	end

	local data = HttpService:JSONEncode({
		Flags = encodedFlags,
		Theme = {
			Name = ACTIVE_THEME.Name,
			Background = { ACTIVE_THEME.Background.R, ACTIVE_THEME.Background.G, ACTIVE_THEME.Background.B },
			Window = { ACTIVE_THEME.Window.R, ACTIVE_THEME.Window.G, ACTIVE_THEME.Window.B },
			Panel = { ACTIVE_THEME.Panel.R, ACTIVE_THEME.Panel.G, ACTIVE_THEME.Panel.B },
			PanelAlt = { ACTIVE_THEME.PanelAlt.R, ACTIVE_THEME.PanelAlt.G, ACTIVE_THEME.PanelAlt.B },
			Stroke = { ACTIVE_THEME.Stroke.R, ACTIVE_THEME.Stroke.G, ACTIVE_THEME.Stroke.B },
			Accent = { ACTIVE_THEME.Accent.R, ACTIVE_THEME.Accent.G, ACTIVE_THEME.Accent.B },
			Accent2 = { ACTIVE_THEME.Accent2.R, ACTIVE_THEME.Accent2.G, ACTIVE_THEME.Accent2.B },
			Text = { ACTIVE_THEME.Text.R, ACTIVE_THEME.Text.G, ACTIVE_THEME.Text.B },
			Muted = { ACTIVE_THEME.Muted.R, ACTIVE_THEME.Muted.G, ACTIVE_THEME.Muted.B },
		},
	})

	if canUseFiles() then
		local env = getfenv() :: any
		ensureConfigFolder()
		env.writefile(configPath(name), data)
	end

	return data
end

function Library:LoadConfig(nameOrData: string, silent: boolean?)
	local data = nameOrData
	if canUseFiles() then
		local env = getfenv() :: any
		local path = configPath(nameOrData)
		if configExists(path) then
			data = env.readfile(path)
		end
	end

	local decoded = HttpService:JSONDecode(data)
	if decoded.Flags then
		for key, value in pairs(decoded.Flags) do
			FLAGS[key] = decodeValue(value)
		end
	end

	if decoded.Theme then
		local theme = {}
		for key, value in pairs(decoded.Theme) do
			if typeof(value) == "table" and #value == 3 then
				theme[key] = Color3.new(value[1], value[2], value[3])
			else
				theme[key] = value
			end
		end
		mergeTheme(theme)
	end

	syncBoundControls(silent == true)

	return decoded
end

function Library:Window(options: { [string]: any })
	options = options or {}
	local self = setmetatable({}, Window)
	self.Tabs = {}
	self.ActiveTab = nil
	self.Title = options.Title or options.Name or "Window"
	self.Subtitle = options.Subtitle or options.Description or "Vertical dual-column interface"
	self.ToggleKey = options.Keybind or Enum.KeyCode.RightShift
	self.Destroyed = false
	self._mainVisible = true
	self._visibilityToken = 0
	self._editMode = false

	local gui = make("ScreenGui", {
		Name = options.GuiName or "VerticalDualColumnUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = getGuiParent(),
	})
	self.Gui = gui

	local shade = make("Frame", {
		BackgroundColor3 = ACTIVE_THEME.Background,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		Parent = gui,
	})
	self.Shade = shade
	bindTheme(shade, "BackgroundColor3", "Background")

	local blur = make("BlurEffect", {
		Name = (options.GuiName or "VerticalDualColumnUI") .. "_Blur",
		Enabled = false,
		Size = 0,
		Parent = Lighting,
	})
	self.Blur = blur
	self._blurSize = options.BlurSize or 16

	local root = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(720, 500),
		BackgroundColor3 = ACTIVE_THEME.Window,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		corner(16),
		stroke(ACTIVE_THEME.Stroke, 0.25, 1),
		padding(12),
	})
	self.Root = root
	self._rootBaseSize = root.Size
	bindTheme(root, "BackgroundColor3", "Window")
	bindTheme(root:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.25)

	local header = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = root,
	})
	self.Header = header

	local title = label(self.Title, 19, ACTIVE_THEME.Text, Enum.Font.GothamBold)
	title.Size = UDim2.new(1, -96, 0, 25)
	title.Position = UDim2.fromOffset(2, 2)
	title.Parent = header
	bindTheme(title, "TextColor3", "Text")

	local subtitle = label(self.Subtitle, 12, ACTIVE_THEME.Muted, Enum.Font.GothamMedium)
	subtitle.Size = UDim2.new(1, -96, 0, 18)
	subtitle.Position = UDim2.fromOffset(2, 28)
	subtitle.Parent = header
	bindTheme(subtitle, "TextColor3", "Muted")

	local editButton = buttonBase("Edit UI")
	editButton.AnchorPoint = Vector2.new(1, 0)
	editButton.Position = UDim2.new(1, -2, 0, 4)
	editButton.Size = UDim2.fromOffset(84, 32)
	editButton.Parent = header
	editButton.TextSize = 12
	corner(9).Parent = editButton
	bindTheme(editButton, "BackgroundColor3", "PanelAlt")
	bindTheme(editButton, "TextColor3", "Text")
	self.EditButton = editButton

	local body = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58),
		Parent = root,
	})
	self.Body = body

	local tabBar = make("Frame", {
		BackgroundColor3 = ACTIVE_THEME.Panel,
		Size = UDim2.new(1, 0, 0, 44),
		BorderSizePixel = 0,
		Parent = body,
	}, {
		corner(12),
		stroke(ACTIVE_THEME.Stroke, 0.5),
		paddingXY(6, 5),
	})
	self.Sidebar = tabBar
	self.TabBar = tabBar
	bindTheme(tabBar, "BackgroundColor3", "Panel")
	bindTheme(tabBar:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.5)

	local tabList = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = ACTIVE_THEME.Accent,
		ScrollBarImageTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = tabBar,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, 7),
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
		}),
	})
	self.TabList = tabList
	bindTheme(tabList, "ScrollBarImageColor3", "Accent")
	attachHorizontalListSizing(tabList)

	local content = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		Parent = body,
	})
	self.Content = content

	local toastHolder = make("Frame", {
		Active = false,
		BackgroundColor3 = ACTIVE_THEME.Panel,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 18),
		Size = UDim2.fromOffset(230, 360),
		Parent = gui,
	}, {
		corner(12),
		stroke(ACTIVE_THEME.Accent, 1),
		make("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	})
	self.ToastHolder = toastHolder
	local toastHolderStroke = toastHolder:FindFirstChildOfClass("UIStroke") :: UIStroke
	self.ToastHolderStroke = toastHolderStroke
	bindTheme(toastHolder, "BackgroundColor3", "Panel")
	bindTheme(toastHolderStroke, "Color", "Accent")

	local notifyEditHandle = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = ACTIVE_THEME.Panel,
		BackgroundTransparency = 0,
		Size = UDim2.new(1, 0, 0, 34),
		Text = "Notify",
		TextColor3 = ACTIVE_THEME.Text,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		Visible = false,
		BorderSizePixel = 0,
		LayoutOrder = -999,
		Parent = toastHolder,
	}, {
		corner(10),
		stroke(ACTIVE_THEME.Accent, 0.2),
	})
	self.NotifyEditHandle = notifyEditHandle
	bindTheme(notifyEditHandle, "BackgroundColor3", "Panel")
	bindTheme(notifyEditHandle, "TextColor3", "Text")
	bindTheme(notifyEditHandle:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Accent", 0.2)

	local watermark = make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = ACTIVE_THEME.Panel,
		BackgroundTransparency = 0.03,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(260, 36),
		Text = "",
		Visible = options.Watermark ~= false,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		corner(18),
		stroke(ACTIVE_THEME.Stroke, 0.35),
		padding(8),
	})
	self.WatermarkFrame = watermark
	bindTheme(watermark, "BackgroundColor3", "Panel")
	bindTheme(watermark:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.35)
	watermark.MouseButton1Click:Connect(function()
		if self._editMode then
			return
		end
		self:_setMainVisible(not self._mainVisible)
	end)

	local fpsText = label("0 FPS", 11, Color3.fromRGB(255, 255, 255), Enum.Font.GothamSemibold)
	fpsText.Size = UDim2.fromOffset(72, 20)
	fpsText.Position = UDim2.new(0, 0, 0.5, -10)
	fpsText.TextXAlignment = Enum.TextXAlignment.Left
	fpsText.Parent = watermark
	self.WatermarkFpsText = fpsText

	local islandText = label(currentClockText(), 13, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	islandText.AnchorPoint = Vector2.new(0.5, 0.5)
	islandText.Position = UDim2.fromScale(0.5, 0.5)
	islandText.Size = UDim2.new(1, -150, 1, 0)
	islandText.TextXAlignment = Enum.TextXAlignment.Center
	islandText.Parent = watermark
	self.IslandText = islandText
	self.WatermarkText = islandText

	local pingText = label("0 ms", 11, Color3.fromRGB(255, 255, 255), Enum.Font.GothamSemibold)
	pingText.AnchorPoint = Vector2.new(1, 0.5)
	pingText.Position = UDim2.new(1, 0, 0.5, 0)
	pingText.Size = UDim2.fromOffset(62, 20)
	pingText.TextXAlignment = Enum.TextXAlignment.Right
	pingText.Parent = watermark
	self.WatermarkPingText = pingText

	local cursorDot = make("Frame", {
		Active = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(7, 7),
		Visible = false,
		ZIndex = 1000,
		Parent = gui,
	}, {
		corner(12),
		stroke(Color3.fromRGB(255, 255, 255), 0.55),
	})
	self.CursorDot = cursorDot
	self._cursorDotPosition = UserInputService:GetMouseLocation()
	self._cursorDotConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not cursorDot.Parent then
			return
		end
		if not self._mainVisible then
			cursorDot.Visible = false
			return
		end
		local target = UserInputService:GetMouseLocation()
		local alpha = 1 - math.exp(-math.clamp(deltaTime, 0, 0.1) * 24)
		self._cursorDotPosition = self._cursorDotPosition:Lerp(target, alpha)
		cursorDot.Position = UDim2.fromOffset(self._cursorDotPosition.X, self._cursorDotPosition.Y)
		cursorDot.Visible = true
	end)

	makeDraggable(watermark, watermark, function()
		return self._editMode == true
	end)

	local hotkeyHolder = make("Frame", {
		Active = false,
		BackgroundColor3 = ACTIVE_THEME.Panel,
		BackgroundTransparency = 0.04,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 18, 0.5, -90),
		Size = UDim2.fromOffset(190, 34),
		Visible = false,
		BorderSizePixel = 0,
		Parent = gui,
	}, {
		corner(12),
		stroke(ACTIVE_THEME.Stroke, 0.35),
		paddingXY(8, 7),
		make("UIListLayout", {
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
	})
	self.HotkeyHolder = hotkeyHolder
	self._hotkeys = {}
	self._hotkeyOrder = 0
	self._hotkeyVisibleToken = 0
	bindTheme(hotkeyHolder, "BackgroundColor3", "Panel")
	bindTheme(hotkeyHolder:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.35)

	local hotkeyTitle =
		label(options.HotkeysTitle or options.HotkeyTitle or "Hotkeys", 12, ACTIVE_THEME.Text, Enum.Font.GothamBold)
	hotkeyTitle.Size = UDim2.new(1, 0, 0, 16)
	hotkeyTitle.TextXAlignment = Enum.TextXAlignment.Left
	hotkeyTitle.LayoutOrder = -1000
	hotkeyTitle.Parent = hotkeyHolder
	self.HotkeyTitle = hotkeyTitle
	bindTheme(hotkeyTitle, "TextColor3", "Text")

	makeDraggable(hotkeyHolder, hotkeyHolder, function()
		return self._editMode == true
	end)
	makeDraggable(notifyEditHandle, toastHolder, function()
		return self._editMode == true
	end)

	self._fps = 0
	self._ping = 0
	self._frameCount = 0
	self._frameClock = os.clock()
	self._islandText = currentClockText()
	self._islandToken = 0
	self._watermarkConnection = RunService.RenderStepped:Connect(function()
		self._frameCount += 1
		local now = os.clock()
		if now - self._frameClock >= 0.5 then
			self._fps = math.floor(self._frameCount / (now - self._frameClock) + 0.5)
			self._ping = readPingMs()
			self._frameCount = 0
			self._frameClock = now
			if fpsText.Parent then
				fpsText.Text = formatFpsText(self._fps)
			end
			if pingText.Parent then
				pingText.Text = formatPingText(self._ping)
			end
			if islandText.Parent and not self._islandOverride then
				self._islandText = currentClockText()
				islandText.Text = self._islandText
			end
		end
	end)

	local function updateResponsive()
		local v = viewportSize()
		local mobile = isMobile()
		local width = math.clamp(v.X * (mobile and 0.9 or 0.52), mobile and 260 or 560, mobile and 460 or 660)
		local height = math.clamp(v.Y * (mobile and 0.6 or 0.72), mobile and 300 or 460, mobile and 420 or 560)
		local tabBarHeight = mobile and 32 or 38
		local contentTop = tabBarHeight + (mobile and 6 or 9)
		local columnGap = mobile and 3 or 5
		local targetSize = UDim2.fromOffset(width, height)
		self._rootBaseSize = targetSize
		if root.Visible then
			root.Size = targetSize
		end
		tabBar.Size = UDim2.new(1, 0, 0, tabBarHeight)
		content.Position = UDim2.fromOffset(0, contentTop)
		content.Size = UDim2.new(1, 0, 1, -contentTop)
		toastHolder.Size = UDim2.fromOffset(mobile and 170 or 230, mobile and 300 or 360)
		if not self._islandOverride then
			watermark.Size = UDim2.fromOffset(mobile and 230 or 260, 36)
		end

		for _, tab in ipairs(self.Tabs) do
			if tab.Columns then
				tab.Columns[1].Size = UDim2.new(0.5, -columnGap, 1, 0)
				tab.Columns[2].Position = UDim2.new(0.5, columnGap, 0, 0)
				tab.Columns[2].Size = UDim2.new(0.5, -columnGap, 1, 0)
			end
			if tab.NavButton then
				local textWidth = math.clamp(
					#tab.NavButton.Text * (mobile and 6 or 8) + (mobile and 18 or 28),
					mobile and 68 or 104,
					mobile and 104 or 170
				)
				tab.NavButton.Size = UDim2.fromOffset(textWidth, mobile and 22 or 26)
				tab.NavButton.TextSize = mobile and 10 or 13
				tab.NavButton.TextTruncate = Enum.TextTruncate.AtEnd
			end
			if tab.NavPadding then
				tab.NavPadding.PaddingLeft = UDim.new(0, mobile and 6 or 8)
				tab.NavPadding.PaddingRight = UDim.new(0, mobile and 6 or 8)
			end
		end
	end
	self._responsive = updateResponsive
	updateResponsive()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsive)
	end

	local dragging = false
	local dragStart = Vector2.zero
	local rootStart = UDim2.new()
	local rootPositionTween: Tween? = nil
	local function moveRootTo(position: UDim2)
		if rootPositionTween then
			rootPositionTween:Cancel()
		end
		rootPositionTween = tween(root, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = position,
		})
	end
	header.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			rootStart = root.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local position = Vector2.new(input.Position.X, input.Position.Y)
			local delta = position - dragStart
			moveRootTo(
				UDim2.new(
					rootStart.X.Scale,
					rootStart.X.Offset + delta.X,
					rootStart.Y.Scale,
					rootStart.Y.Offset + delta.Y
				)
			)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == self.ToggleKey then
			self:_setMainVisible(not self._mainVisible)
		end
	end)

	editButton.MouseButton1Click:Connect(function()
		self:SetEditMode(not self._editMode)
	end)

	table.insert(WINDOWS, self)
	task.defer(function()
		self:_setMainVisible(true, true)
	end)
	return self
end

function Window:Destroy()
	self.Destroyed = true
	if self._watermarkConnection then
		self._watermarkConnection:Disconnect()
		self._watermarkConnection = nil
	end
	if self._cursorDotConnection then
		self._cursorDotConnection:Disconnect()
		self._cursorDotConnection = nil
	end
	if self._playerListConnections then
		for _, connection in ipairs(self._playerListConnections) do
			connection:Disconnect()
		end
		self._playerListConnections = nil
	end
	if self.Blur then
		self.Blur:Destroy()
		self.Blur = nil
	end
	if self.Gui then
		self.Gui:Destroy()
	end
	self.HotkeyHolder = nil
	self._hotkeys = nil
end

function Window:_setMainVisible(visible: boolean, immediate: boolean?)
	self._mainVisible = visible
	self._visibilityToken += 1
	local token = self._visibilityToken
	local baseSize = self._rootBaseSize or (self.Root and self.Root.Size) or UDim2.fromOffset(720, 500)
	local smallSize = UDim2.new(
		baseSize.X.Scale,
		math.floor(baseSize.X.Offset * 0.96),
		baseSize.Y.Scale,
		math.floor(baseSize.Y.Offset * 0.96)
	)
	if self.CursorDot then
		if visible then
			self._cursorDotPosition = UserInputService:GetMouseLocation()
			self.CursorDot.Position = UDim2.fromOffset(self._cursorDotPosition.X, self._cursorDotPosition.Y)
			self.CursorDot.Visible = true
			self.CursorDot.BackgroundTransparency = 1
			tween(self.CursorDot, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0.08,
			})
		else
			tween(self.CursorDot, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			})
			task.delay(0.11, function()
				if self.CursorDot and self._visibilityToken == token and not self._mainVisible then
					self.CursorDot.Visible = false
				end
			end)
		end
	end
	if self.Root then
		if visible then
			self.Root.Visible = true
			self.Root.Size = smallSize
			self.Root.BackgroundTransparency = 1
			cacheGuiContentTransparency(self.Root)
			setGroupTransparency(self.Root, 1)
			tweenGuiContentTransparency(self.Root, 0, 0, true)
			tween(self.Root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = baseSize,
				BackgroundTransparency = 0,
			})
			task.delay(0.03, function()
				if self.Root and self.Root.Parent then
					tweenGuiContentTransparency(self.Root, 0, 0.16, true)
				end
			end)
		else
			tweenGuiContentTransparency(self.Root, 1, 0.1, false)
			task.delay(0.11, function()
				if self.Root and self._visibilityToken == token and not self._mainVisible then
					tween(self.Root, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Size = smallSize,
						BackgroundTransparency = 1,
					})
				end
			end)
			task.delay(0.3, function()
				if self.Root and self._visibilityToken == token and not self._mainVisible then
					self.Root.Visible = false
					self.Root.Size = baseSize
				end
			end)
		end
	end
	if self.Shade then
		if visible then
			self.Shade.Visible = true
			self.Shade.BackgroundTransparency = 1
			tween(
				self.Shade,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 0.42 }
			)
		else
			tween(
				self.Shade,
				TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ BackgroundTransparency = 1 }
			)
			task.delay(0.19, function()
				if self.Shade and self._visibilityToken == token and not self._mainVisible then
					self.Shade.Visible = false
				end
			end)
		end
	end
	if self.Blur then
		if visible then
			self.Blur.Enabled = true
			self.Blur.Size = 0
			tween(self.Blur, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = self._blurSize or 16,
			})
		else
			tween(self.Blur, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = 0,
			})
			task.delay(0.19, function()
				if self.Blur and self._visibilityToken == token and not self._mainVisible then
					self.Blur.Enabled = false
				end
			end)
		end
	end
	if self.Gui then
		self.Gui.Enabled = true
	end
end

function Window:SetVisible(visible: boolean)
	self:_setMainVisible(visible)
end

function Window:SetEditMode(enabled: boolean)
	self._editMode = enabled
	if self.EditButton then
		self.EditButton.Text = enabled and "Done Edit" or "Edit UI"
		tween(self.EditButton, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = enabled and ACTIVE_THEME.Accent or ACTIVE_THEME.PanelAlt,
		})
	end
	if self.WatermarkFrame then
		tween(self.WatermarkFrame, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = enabled and 0 or 0.03,
		})
	end
	if self.ToastHolder then
		self.ToastHolder.Active = enabled
		self.ToastHolder.BackgroundTransparency = 1
	end
	if self.ToastHolderStroke then
		self.ToastHolderStroke.Transparency = 1
	end
	if self.NotifyEditHandle then
		self.NotifyEditHandle.Visible = enabled
	end
	if self.HotkeyHolder then
		self.HotkeyHolder.Active = enabled
		self:_refreshHotkeys()
	end
	return self
end

function Window:_refreshHotkeys()
	local holder = self.HotkeyHolder
	if not holder then
		return
	end
	self._hotkeyVisibleToken = (self._hotkeyVisibleToken or 0) + 1
	local token = self._hotkeyVisibleToken
	local count = 0
	local maxText = 110
	for _, item in pairs(self._hotkeys or {}) do
		if item.Active and item.Row and item.Row.Parent then
			count += 1
			item.Row.Visible = true
			item.Row.LayoutOrder = item.Order or count
			item.Row.BackgroundTransparency = 1
			if item.Name then
				tween(item.Name, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				})
			end
			if item.Key then
				tween(item.Key, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				})
			end
			maxText = math.max(
				maxText,
				math.clamp(#tostring(item.Text or "") * 7 + #tostring(item.KeyText or "") * 7 + 42, 110, 260)
			)
		end
	end
	local visible = count > 0 or self._editMode == true
	if visible then
		holder.Visible = true
	end
	local height = 28 + (count * 23)
	tween(holder, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(maxText, math.max(34, height)),
		BackgroundTransparency = visible and (self._editMode and 0 or 0.04) or 1,
	})
	if not visible then
		task.delay(0.15, function()
			if self.HotkeyHolder == holder and self._hotkeyVisibleToken == token then
				holder.Visible = false
			end
		end)
	end
end

function Window:_setHotkeyActive(id: string, text: string, keyText: string, active: boolean, highlighted: boolean?)
	if not self.HotkeyHolder then
		return
	end
	self._hotkeys = self._hotkeys or {}
	local item = self._hotkeys[id]
	if not item then
		local row = make("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Visible = false,
			Parent = self.HotkeyHolder,
		})
		local name = label(text, 11, ACTIVE_THEME.Muted, Enum.Font.GothamMedium)
		name.Size = UDim2.new(1, -62, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTransparency = 1
		name.Parent = row
		bindTheme(name, "TextColor3", "Muted")

		local key = label(keyText, 11, ACTIVE_THEME.Text, Enum.Font.GothamSemibold)
		key.AnchorPoint = Vector2.new(1, 0.5)
		key.Position = UDim2.new(1, 0, 0.5, -1)
		key.Size = UDim2.fromOffset(48, 20)
		key.BackgroundColor3 = ACTIVE_THEME.Accent
		key.BackgroundTransparency = 1
		key.TextXAlignment = Enum.TextXAlignment.Center
		key.TextTransparency = 1
		key.Parent = row
		corner(8).Parent = key
		local keyStroke = stroke(ACTIVE_THEME.Accent, 1, 1)
		keyStroke.LineJoinMode = Enum.LineJoinMode.Round
		keyStroke.Parent = key
		bindTheme(key, "BackgroundColor3", "Accent")
		bindTheme(key, "TextColor3", "Text")
		bindTheme(keyStroke, "Color", "Accent")

		item = {
			Row = row,
			Name = name,
			Key = key,
			KeyStroke = keyStroke,
			Text = text,
			KeyText = keyText,
			Active = false,
			Highlighted = false,
			Order = 0,
			Token = 0,
		}
		self._hotkeys[id] = item
	end
	item.Text = text
	item.KeyText = keyText
	item.Name.Text = text
	item.Key.Text = keyText
	local keyWidth = math.clamp(#keyText * 7 + 18, 42, 82)
	item.Key.Size = UDim2.fromOffset(keyWidth, 20)
	item.Name.Size = UDim2.new(1, -(keyWidth + 14), 1, 0)
	if active and not item.Active then
		self._hotkeyOrder = (self._hotkeyOrder or 0) + 1
		item.Order = self._hotkeyOrder
	end
	if not active and item.Active and item.Row and item.Row.Parent then
		item.Token = (item.Token or 0) + 1
		local token = item.Token
		if item.Name then
			tween(item.Name, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
			})
		end
		if item.Key then
			tween(item.Key, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			})
		end
		if item.KeyStroke then
			tween(item.KeyStroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			})
		end
		task.delay(0.13, function()
			if item.Row and item.Row.Parent and item.Token == token and not item.Active then
				item.Row.Visible = false
			end
		end)
	elseif active then
		item.Token = (item.Token or 0) + 1
	end
	item.Active = active
	local shouldHighlight = active and highlighted == true
	if shouldHighlight ~= item.Highlighted then
		item.Highlighted = shouldHighlight
		local info = TweenInfo.new(0.14, Enum.EasingStyle.Quad, shouldHighlight and Enum.EasingDirection.Out or Enum.EasingDirection.In)
		if item.Key then
			tween(item.Key, info, {
				BackgroundTransparency = shouldHighlight and 0.18 or 1,
			})
		end
		if item.KeyStroke then
			tween(item.KeyStroke, info, {
				Transparency = shouldHighlight and 0.15 or 1,
			})
		end
	end
	self:_refreshHotkeys()
end

function Window:_setTabButtonState(tab: any, selected: boolean, animated: boolean?)
	if not tab or not tab.NavButton then
		return
	end
	local button = tab.NavButton
	local props = {
		TextColor3 = selected and ACTIVE_THEME.Text or ACTIVE_THEME.Muted,
		BackgroundColor3 = selected and ACTIVE_THEME.Accent or ACTIVE_THEME.PanelAlt,
	}
	if animated then
		tween(button, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	else
		button.TextColor3 = props.TextColor3
		button.BackgroundColor3 = props.BackgroundColor3
	end
end

function Window:_refreshTabButtons(animated: boolean?, previousTab: any?)
	local activeTab = self.ActiveTab
	for _, other in ipairs(self.Tabs) do
		if animated and previousTab and previousTab ~= activeTab then
			if other == previousTab then
				self:_setTabButtonState(other, false, true)
			elseif other ~= activeTab then
				self:_setTabButtonState(other, false, false)
			end
		else
			self:_setTabButtonState(other, other == activeTab, animated)
		end
	end
	if animated and previousTab and previousTab ~= activeTab and activeTab then
		task.delay(0.06, function()
			if self.ActiveTab == activeTab then
				self:_setTabButtonState(activeTab, true, true)
			end
		end)
	end
end

function Window:Watermark(options: any)
	if typeof(options) == "boolean" then
		self.WatermarkFrame.Visible = options
	elseif typeof(options) == "string" then
		self:Island(options, 2)
		self.WatermarkFrame.Visible = true
	elseif typeof(options) == "table" then
		if options.Text or options.Name then
			self:Island(options.Text or options.Name, options.Duration or 2)
		end
		if options.Visible ~= nil then
			self.WatermarkFrame.Visible = options.Visible
		else
			self.WatermarkFrame.Visible = true
		end
	end
	return self
end

function Window:Island(text: string, duration: number?)
	if not self.WatermarkFrame or not self.IslandText then
		return self
	end
	self._islandToken += 1
	local token = self._islandToken
	local displayText = tostring(text or "")
	local holdTime = duration or 2
	self._islandOverride = true
	self.WatermarkFrame.Visible = true
	local targetWidth = math.clamp(180 + (#displayText * 6), 260, 420)
	tween(self.WatermarkFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(targetWidth, 40),
	})
	tween(self.IslandText, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
	})
	task.delay(0.08, function()
		if self.IslandText and self._islandToken == token then
			self.IslandText.Text = displayText
			tween(self.IslandText, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextTransparency = 0,
			})
		end
	end)
	task.delay(holdTime, function()
		if self._islandToken ~= token then
			return
		end
		self._islandOverride = false
		local clock = currentClockText()
		tween(self.WatermarkFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(isMobile() and 230 or 260, 36),
		})
		tween(self.IslandText, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
		})
		task.delay(0.08, function()
			if self.IslandText and self._islandToken == token then
				self.IslandText.Text = clock
				tween(self.IslandText, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					TextTransparency = 0,
				})
			end
		end)
	end)
	return self
end

function Window:Notify(options: { [string]: any })
	options = options or {}
	local titleText = options.Title or "Notification"
	local contentText = options.Content or options.Text or ""
	local duration = options.Duration or 3
	local mobileNotify = isMobile()

	local toast = make("Frame", {
		BackgroundColor3 = ACTIVE_THEME.Panel,
		BackgroundTransparency = 0.04,
		Size = UDim2.new(1, 0, 0, mobileNotify and 50 or 60),
		BorderSizePixel = 0,
		Parent = self.ToastHolder,
	}, {
		corner(10),
		stroke(options.Color or ACTIVE_THEME.Accent, 0.2),
		padding(mobileNotify and 7 or 9),
	})
	bindTheme(toast, "BackgroundColor3", "Panel")

	local top = label(titleText, mobileNotify and 10 or 12, ACTIVE_THEME.Text, Enum.Font.GothamBold)
	top.Size = UDim2.new(1, 0, 0, mobileNotify and 13 or 15)
	top.Parent = toast
	bindTheme(top, "TextColor3", "Text")

	local body = label(contentText, mobileNotify and 9 or 11, ACTIVE_THEME.Muted, Enum.Font.GothamMedium)
	body.Position = UDim2.fromOffset(0, mobileNotify and 15 or 18)
	body.Size = UDim2.new(1, 0, 0, mobileNotify and 20 or 24)
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Parent = toast
	bindTheme(body, "TextColor3", "Muted")

	toast.Position = UDim2.fromOffset(24, 0)
	toast.BackgroundTransparency = 1
	tween(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 0.04,
	})

	task.delay(duration, function()
		if toast.Parent then
			tween(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
				Position = UDim2.fromOffset(24, 0),
				BackgroundTransparency = 1,
			})
			task.wait(0.22)
			if toast.Parent then
				toast:Destroy()
			end
		end
	end)
	return toast
end

function Window:CreateTab(options: { [string]: any })
	return self:Tab(options)
end

function Window:PlayerList(options: { [string]: any }?)
	options = options or {}
	local tab = self:Tab({ Title = options.Title or "Player List", Icon = options.Icon or "" })
	for _, column in ipairs(tab.Columns) do
		column.Visible = false
	end

	local searchBox = make("TextBox", {
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, 30),
		Text = "",
		PlaceholderText = options.SearchPlaceholder or "Search player...",
		TextColor3 = ACTIVE_THEME.Text,
		PlaceholderColor3 = ACTIVE_THEME.Muted,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		Parent = tab.Page,
	}, {
		corner(9),
		padding(8),
		stroke(ACTIVE_THEME.Stroke, 0.45),
	})
	bindTheme(searchBox, "BackgroundColor3", "PanelAlt")
	bindTheme(searchBox, "TextColor3", "Text")
	bindTheme(searchBox, "PlaceholderColor3", "Muted")
	bindTheme(searchBox:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.45)

	local list = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -38),
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = ACTIVE_THEME.Accent,
		ScrollBarImageTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Parent = tab.Page,
	}, {
		paddingXY(2, 2),
		make("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	attachListSizing(list)

	local rows = {}
	local states = {}
	local thumbnailCache = {}
	local watching: Player? = nil
	local watchButton: TextButton? = nil
	local bringing: Player? = nil
	local bringButton: TextButton? = nil
	local searchText = ""
	self._playerListConnections = self._playerListConnections or {}

	local function setButtonSelected(button: TextButton, selected: boolean)
		tween(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = selected and ACTIVE_THEME.Accent or ACTIVE_THEME.PanelAlt,
			TextColor3 = selected and ACTIVE_THEME.Text or ACTIVE_THEME.Muted,
		})
	end

	local function stopWatching()
		if watchButton then
			setButtonSelected(watchButton, false)
		end
		watchButton = nil
		watching = nil
		local camera = workspace.CurrentCamera
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if camera and humanoid then
			camera.CameraSubject = humanoid
		end
	end

	local function observePlayer(player: Player, button: TextButton)
		if watching == player then
			stopWatching()
			safeCall(options.ObserveChanged, nil)
			return
		end
		if watchButton then
			setButtonSelected(watchButton, false)
		end
		watching = player
		watchButton = button
		setButtonSelected(button, true)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if camera and humanoid then
			camera.CameraSubject = humanoid
		end
		safeCall(options.ObserveChanged, player)
	end

	local function stopBringing()
		if bringButton then
			setButtonSelected(bringButton, false)
		end
		bringButton = nil
		bringing = nil
	end

	local function bringPlayer(player: Player, button: TextButton)
		if bringing == player then
			stopBringing()
			safeCall(options.BringChanged, nil)
			safeCall(options.CarryChanged, nil)
			return
		end
		if bringButton then
			setButtonSelected(bringButton, false)
		end
		bringing = player
		bringButton = button
		setButtonSelected(button, true)
		safeCall(options.BringChanged, player)
		safeCall(options.CarryChanged, player)
	end

	local function teleportToPlayer(player: Player)
		local localCharacter = LocalPlayer.Character
		local targetCharacter = player.Character
		local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
		local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
		if localRoot and targetRoot and localRoot:IsA("BasePart") and targetRoot:IsA("BasePart") then
			localRoot.CFrame = targetRoot.CFrame
			safeCall(options.Teleported, player)
		end
	end

	local function makeActionButton(text: string, xOffset: number)
		local mobileList = isMobile()
		local button = buttonBase(text)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, xOffset, 0.5, 0)
		button.Size = UDim2.fromOffset(mobileList and 44 or 58, mobileList and 22 or 26)
		button.TextSize = mobileList and 9 or 11
		button.Parent = nil
		corner(mobileList and 7 or 8).Parent = button
		bindTheme(button, "BackgroundColor3", "PanelAlt")
		bindTheme(button, "TextColor3", "Muted")
		return button
	end

	local function refreshRowState(player: Player)
		local rowData = rows[player]
		if not rowData then
			return
		end
		local state = states[player.UserId]
		setButtonSelected(rowData.WhiteButton, state == "Whitelist")
		setButtonSelected(rowData.BlackButton, state == "Blacklist")
		setButtonSelected(rowData.ObserveButton, watching == player)
		setButtonSelected(rowData.BringButton, bringing == player)
	end

	local function isCurrentPlayer(player: Player?)
		return player ~= nil and player.Parent == Players
	end

	local function getListState(player: Player?)
		if not isCurrentPlayer(player) then
			return nil
		end
		return states[player.UserId]
	end

	local function hasBlacklistState()
		for _, player in ipairs(Players:GetPlayers()) do
			if states[player.UserId] == "Blacklist" then
				return true
			end
		end
		return false
	end

	local function setListState(player: Player, nextState: string)
		local current = states[player.UserId]
		if current == nextState then
			states[player.UserId] = nil
		else
			states[player.UserId] = nextState
		end
		refreshRowState(player)
		safeCall(options.StateChanged, {
			Player = player,
			State = states[player.UserId],
		})
	end

	local function playerSortKey(player: Player)
		return string.lower((player.DisplayName ~= "" and player.DisplayName or player.Name) .. "@" .. player.Name)
	end

	local function playerDisplayText(player: Player)
		if player.DisplayName == "" or player.DisplayName == player.Name then
			return player.Name
		end
		return player.DisplayName .. " (@" .. player.Name .. ")"
	end

	local function matchesPlayerSearch(player: Player)
		if searchText == "" then
			return true
		end
		local haystack = string.lower(player.DisplayName .. " " .. player.Name)
		return string.find(haystack, searchText, 1, true) ~= nil
	end

	local function loadAvatarAsync(player: Player, avatar: ImageLabel)
		local cached = thumbnailCache[player.UserId]
		if cached then
			avatar.Image = cached
			return
		end
		task.spawn(function()
			for _ = 1, 6 do
				if not avatar.Parent then
					return
				end
				local ok, image, ready = pcall(function()
					return Players:GetUserThumbnailAsync(
						player.UserId,
						Enum.ThumbnailType.HeadShot,
						Enum.ThumbnailSize.Size100x100
					)
				end)
				if ok and typeof(image) == "string" and image ~= "" then
					thumbnailCache[player.UserId] = image
					avatar.Image = image
					if ready == true then
						return
					end
				end
				task.wait(0.5)
			end
		end)
	end

	local function refreshPlayerOrder()
		local sorted = {}
		for player in pairs(rows) do
			table.insert(sorted, player)
		end
		table.sort(sorted, function(a, b)
			return playerSortKey(a) < playerSortKey(b)
		end)
		for index, player in ipairs(sorted) do
			local row = rows[player].Row
			row.LayoutOrder = index
			row.Visible = matchesPlayerSearch(player)
		end
	end

	local function addPlayer(player: Player)
		if rows[player] then
			return
		end
		local mobileList = isMobile()
		local rowHeight = mobileList and 40 or 54
		local avatarSize = mobileList and 28 or 40
		local avatarOffset = mobileList and 6 or 8
		local avatarY = math.floor((rowHeight - avatarSize) / 2)
		local buttonStep = mobileList and 48 or 64
		local nameX = mobileList and 40 or 58
		local nameRight = mobileList and 260 or 382
		local row = make("Frame", {
			BackgroundColor3 = ACTIVE_THEME.Panel,
			Size = UDim2.new(1, 0, 0, rowHeight),
			BorderSizePixel = 0,
			Parent = list,
		}, {
			corner(mobileList and 8 or 10),
			stroke(ACTIVE_THEME.Stroke, 0.45),
		})
		bindTheme(row, "BackgroundColor3", "Panel")
		bindTheme(row:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.45)

		local avatar = make("ImageLabel", {
			BackgroundColor3 = ACTIVE_THEME.PanelAlt,
			Position = UDim2.fromOffset(avatarOffset, avatarY),
			Size = UDim2.fromOffset(avatarSize, avatarSize),
			BorderSizePixel = 0,
			Image = "",
			Parent = row,
		}, {
			corner(mobileList and 9 or 12),
		})
		bindTheme(avatar, "BackgroundColor3", "PanelAlt")
		loadAvatarAsync(player, avatar)

		local nameText =
			label(playerDisplayText(player), mobileList and 10 or 13, ACTIVE_THEME.Text, Enum.Font.GothamSemibold)
		nameText.Position = UDim2.fromOffset(nameX, mobileList and 4 or 8)
		nameText.Size = UDim2.new(1, -nameRight, 0, mobileList and 32 or 38)
		nameText.TextXAlignment = Enum.TextXAlignment.Left
		nameText.TextTruncate = Enum.TextTruncate.AtEnd
		nameText.Parent = row
		bindTheme(nameText, "TextColor3", "Text")

		local teleport = makeActionButton(options.TeleportText or "Teleport", -8)
		teleport.Parent = row
		local bring = makeActionButton(options.BringText or options.CarryText or "Bring", -(8 + buttonStep))
		bring.Parent = row
		local observe = makeActionButton(options.ObserveText or "Observe", -(8 + buttonStep * 2))
		observe.Parent = row
		local blacklist = makeActionButton(options.BlacklistText or "Blacklist", -(8 + buttonStep * 3))
		blacklist.Parent = row
		local whitelist = makeActionButton(options.WhitelistText or "Whitelist", -(8 + buttonStep * 4))
		whitelist.Parent = row

		rows[player] = {
			Row = row,
			WhiteButton = whitelist,
			BlackButton = blacklist,
			ObserveButton = observe,
			BringButton = bring,
			CarryButton = bring,
			TeleportButton = teleport,
		}
		whitelist.MouseButton1Click:Connect(function()
			setListState(player, "Whitelist")
		end)
		blacklist.MouseButton1Click:Connect(function()
			setListState(player, "Blacklist")
		end)
		observe.MouseButton1Click:Connect(function()
			observePlayer(player, observe)
		end)
		bring.MouseButton1Click:Connect(function()
			bringPlayer(player, bring)
		end)
		teleport.MouseButton1Click:Connect(function()
			teleportToPlayer(player)
		end)
		player.CharacterAdded:Connect(function(character)
			if watching == player then
				local humanoid = character:WaitForChild("Humanoid", 5)
				if humanoid and workspace.CurrentCamera then
					workspace.CurrentCamera.CameraSubject = humanoid
				end
			end
		end)
		refreshRowState(player)
		refreshPlayerOrder()
	end

	local function removePlayer(player: Player)
		local rowData = rows[player]
		if not rowData then
			return
		end
		if watching == player then
			stopWatching()
			safeCall(options.ObserveChanged, nil)
		end
		if bringing == player then
			stopBringing()
			safeCall(options.BringChanged, nil)
			safeCall(options.CarryChanged, nil)
		end
		rowData.Row:Destroy()
		rows[player] = nil
		states[player.UserId] = nil
		refreshPlayerOrder()
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if options.IncludeLocalPlayer == true or player ~= LocalPlayer then
			addPlayer(player)
		end
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = string.lower(searchBox.Text)
		refreshPlayerOrder()
	end)
	table.insert(
		self._playerListConnections,
		Players.PlayerAdded:Connect(function(player)
			if options.IncludeLocalPlayer == true or player ~= LocalPlayer then
				addPlayer(player)
			end
		end)
	)
	table.insert(self._playerListConnections, Players.PlayerRemoving:Connect(removePlayer))
	table.insert(
		self._playerListConnections,
		RunService.RenderStepped:Connect(function()
			if not bringing or not bringing.Character then
				return
			end
			local localCharacter = LocalPlayer.Character
			local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
			local targetRoot = bringing.Character:FindFirstChild("HumanoidRootPart")
			if localRoot and targetRoot and localRoot:IsA("BasePart") and targetRoot:IsA("BasePart") then
				targetRoot.CFrame = localRoot.CFrame * CFrame.new(0, 0, -4)
			end
		end)
	)

	local control = {
		Tab = tab,
		Instance = list,
		GetState = function(_, player: Player)
			return getListState(player), hasBlacklistState()
		end,
		HasBlacklist = hasBlacklistState,
		SetState = function(_, player: Player, state: string?)
			if not isCurrentPlayer(player) then
				if player then
					states[player.UserId] = nil
				end
				return
			end
			if state == "Whitelist" or state == "Blacklist" then
				states[player.UserId] = state
			else
				states[player.UserId] = nil
			end
			refreshRowState(player)
		end,
		GetObserved = function()
			return watching
		end,
		ClearObserved = function()
			stopWatching()
		end,
		GetBrought = function()
			return bringing
		end,
		ClearBrought = function()
			stopBringing()
		end,
		GetCarried = function()
			return bringing
		end,
		ClearCarried = function()
			stopBringing()
		end,
	}
	return control
end

function Window:Tab(options: { [string]: any })
	options = options or {}
	local tab = setmetatable({}, Tab)
	tab.Window = self
	tab.Title = options.Title or options.Name or ("Tab " .. tostring(#self.Tabs + 1))
	tab.Icon = options.Icon or ""
	tab._nextColumn = 1

	local button = buttonBase((tab.Icon ~= "" and (tab.Icon .. "  ") or "") .. tab.Title)
	button.Size = UDim2.fromOffset(math.clamp(#button.Text * 8 + 28, 104, 170), isMobile() and 22 or 26)
	button.TextSize = isMobile() and 10 or 13
	button.BackgroundColor3 = ACTIVE_THEME.PanelAlt
	button.TextColor3 = ACTIVE_THEME.Muted
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.Parent = self.TabList
	corner(9).Parent = button
	local buttonPad = make("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	buttonPad.Parent = button
	bindTheme(button, "BackgroundColor3", "PanelAlt")
	bindTheme(button, "TextColor3", "Muted")
	tab.NavButton = button
	tab.NavPadding = buttonPad

	local page = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = self.Content,
	})
	tab.Page = page

	local left = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -5, 1, 0),
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = ACTIVE_THEME.Accent,
		ScrollBarImageTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Parent = page,
	}, {
		paddingXY(2, 2),
		make("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local right = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 5, 0, 0),
		Size = UDim2.new(0.5, -5, 1, 0),
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = ACTIVE_THEME.Accent,
		ScrollBarImageTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Parent = page,
	}, {
		paddingXY(2, 2),
		make("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	attachListSizing(left)
	attachListSizing(right)
	tab.Columns = { left, right }
	table.insert(self.Tabs, tab)
	if self._responsive then
		self._responsive()
	end

	local function selectTab()
		if self.ActiveTab == tab and page.Visible then
			return
		end
		local previousTab = self.ActiveTab
		for _, other in ipairs(self.Tabs) do
			other.Page.Visible = false
		end
		page.Visible = true
		self.ActiveTab = tab
		self:_refreshTabButtons(previousTab ~= nil, previousTab)
		animateColumn(left, -1)
		animateColumn(right, 1)
	end
	button.MouseButton1Click:Connect(selectTab)

	if #self.Tabs == 1 then
		selectTab()
	end
	return tab
end

function Tab:_parent(options: { [string]: any }?)
	options = options or {}
	if options.Side == "Left" then
		return self.Columns[1]
	elseif options.Side == "Right" then
		return self.Columns[2]
	end
	local column = self.Columns[self._nextColumn]
	self._nextColumn = self._nextColumn == 1 and 2 or 1
	return column
end

function Tab:Label(options: any)
	if typeof(options) == "string" then
		options = { Text = options }
	end
	options = options or {}
	local parent = self:_parent(options)
	local card = makeCard(parent, options.Title or options.Text or "Label", options.Height or 48)
	local text = card:FindFirstChildOfClass("TextLabel") :: TextLabel
	text.Text = options.Text or options.Title or "Label"
	return {
		Instance = card,
		Set = function(_, value: string)
			text.Text = value
		end,
	}
end

function Tab:Button(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local text = options.ButtonText or options.Title or options.Text or "Button"
	local button = buttonBase(text)
	button.Size = UDim2.new(1, 0, 0, options.Height or 36)
	button.BackgroundColor3 = ACTIVE_THEME.Accent
	button.TextXAlignment = Enum.TextXAlignment.Center
	button.TextSize = options.TextSize or 12
	button.Parent = parent
	corner(8).Parent = button
	local buttonStroke = stroke(ACTIVE_THEME.Stroke, 0.35)
	buttonStroke.Parent = button
	bindTheme(button, "BackgroundColor3", "Accent")
	bindTheme(button, "TextColor3", "Text")
	bindTheme(buttonStroke, "Color", "Stroke", 0.35)
	table.insert(ELEMENTS, {
		Apply = function()
			if button.Parent then
				button.BackgroundColor3 = ACTIVE_THEME.Accent
			end
		end,
	})
	button.MouseEnter:Connect(function()
		tween(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { BackgroundColor3 = ACTIVE_THEME.Accent2 })
	end)
	button.MouseLeave:Connect(function()
		tween(button, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { BackgroundColor3 = ACTIVE_THEME.Accent })
	end)
	button.MouseButton1Click:Connect(function()
		safeCall(options.Callback, true)
	end)
	return { Instance = button, Button = button }
end

function Tab:Input(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local card = makeCard(parent, options.Title or "Input", 76)
	local box = make("TextBox", {
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		Position = UDim2.fromOffset(4, 24),
		Size = UDim2.new(1, -8, 0, 30),
		Text = tostring(options.Default or ""),
		PlaceholderText = options.Placeholder or "Type...",
		TextColor3 = ACTIVE_THEME.Text,
		PlaceholderColor3 = ACTIVE_THEME.Muted,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		corner(9),
		padding(8),
	})
	bindTheme(box, "BackgroundColor3", "PanelAlt")
	bindTheme(box, "TextColor3", "Text")
	bindTheme(box, "PlaceholderColor3", "Muted")
	setFlag(options.Flag, box.Text)
	box.FocusLost:Connect(function()
		setFlag(options.Flag, box.Text)
		safeCall(options.Callback, box.Text)
	end)
	local control = {
		Instance = card,
		Input = box,
		Set = function(_, value: any, silent: boolean?)
			local textValue = tostring(value or "")
			box.Text = textValue
			setFlag(options.Flag, textValue)
			if not silent then
				safeCall(options.Callback, textValue)
			end
		end,
	}
	if shouldFireInitialCallback(options) then
		safeCall(options.Callback, box.Text)
	end
	registerConfigBinding(options.Flag, control)
	return control
end

function Tab:Dropdown(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local values = options.Values or options.Options or {}
	local multi = options.Multi == true or options.Multiple == true
	local current = multi and (options.Default or {}) or (options.Default or values[1] or "None")
	local selectedSet = {}
	local optionButtons = {}
	local searchText = ""
	if multi then
		if typeof(current) ~= "table" then
			current = { current }
		end
		for _, value in ipairs(current) do
			selectedSet[tostring(value)] = true
		end
		current = {}
	end
	local open = false
	local card = makeCard(parent, options.Title or "Dropdown", 72)
	local pick = buttonBase("")
	pick.Position = UDim2.fromOffset(4, 20)
	pick.Size = UDim2.new(1, -8, 0, 30)
	pick.TextXAlignment = Enum.TextXAlignment.Left
	pick.Parent = card
	corner(9).Parent = pick
	padding(8).Parent = pick
	bindTheme(pick, "BackgroundColor3", "PanelAlt")
	bindTheme(pick, "TextColor3", "Text")
	setFlag(options.Flag, current)

	local dropdownPanel = make("Frame", {
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		Position = UDim2.fromOffset(4, 54),
		Size = UDim2.new(1, -8, 0, 0),
		ClipsDescendants = true,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
		Parent = card,
	}, {
		corner(9),
	})
	bindTheme(dropdownPanel, "BackgroundColor3", "PanelAlt")

	local searchBox = make("TextBox", {
		BackgroundColor3 = ACTIVE_THEME.Panel,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0, 26),
		Text = "",
		PlaceholderText = options.SearchPlaceholder or "Search...",
		TextColor3 = ACTIVE_THEME.Text,
		PlaceholderColor3 = ACTIVE_THEME.Muted,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		Parent = dropdownPanel,
	}, {
		corner(7),
		padding(8),
	})
	bindTheme(searchBox, "BackgroundColor3", "Panel")
	bindTheme(searchBox, "TextColor3", "Text")
	bindTheme(searchBox, "PlaceholderColor3", "Muted")

	local list = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 34),
		Size = UDim2.new(1, -8, 0, 0),
		ClipsDescendants = true,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = ACTIVE_THEME.Accent,
		ScrollBarImageTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = dropdownPanel,
	}, {
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local function matchesSearch(value: any)
		if searchText == "" then
			return true
		end
		return string.find(string.lower(tostring(value)), searchText, 1, true) ~= nil
	end

	local function getVisibleCount()
		local count = 0
		for _, value in ipairs(values) do
			if matchesSearch(value) then
				count += 1
			end
		end
		return count
	end

	local function resize()
		local listHeight = open and (math.min(getVisibleCount(), 4) * 28) or 0
		local panelHeight = open and (38 + listHeight) or 0
		if open then
			dropdownPanel.Visible = true
		end
		tween(
			card,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad),
			{ Size = UDim2.new(1, 0, 0, open and (70 + panelHeight) or 66) }
		)
		tween(dropdownPanel, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Size = UDim2.new(1, -8, 0, panelHeight) })
		tween(list, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Size = UDim2.new(1, -8, 0, listHeight) })
		if not open then
			task.delay(0.17, function()
				if not open and dropdownPanel.Parent then
					dropdownPanel.Visible = false
				end
			end)
		end
	end

	local function getSelectedList()
		local selected = {}
		for _, value in ipairs(values) do
			if selectedSet[tostring(value)] then
				table.insert(selected, value)
			end
		end
		return selected
	end

	local function updatePickText()
		if multi then
			local selected = getSelectedList()
			if #selected == 0 then
				pick.Text = options.Placeholder or "Select..."
			elseif #selected <= 2 then
				local names = {}
				for _, value in ipairs(selected) do
					table.insert(names, tostring(value))
				end
				pick.Text = table.concat(names, ", ")
			else
				pick.Text = tostring(#selected) .. " selected"
			end
		else
			pick.Text = tostring(current)
		end
	end

	local function refreshOptions()
		for valueKey, optionButton in pairs(optionButtons) do
			local selected = multi and selectedSet[valueKey] == true or tostring(current) == valueKey
			optionButton.Visible = matchesSearch(optionButton.Text)
			optionButton.BackgroundTransparency = selected and 0 or 1
			optionButton.BackgroundColor3 = selected and ACTIVE_THEME.Accent or ACTIVE_THEME.PanelAlt
			optionButton.TextColor3 = selected and ACTIVE_THEME.Text or ACTIVE_THEME.Muted
		end
		updatePickText()
		resize()
	end

	local function rebuildOptions()
		for _, optionButton in pairs(optionButtons) do
			optionButton:Destroy()
		end
		optionButtons = {}
		for _, value in ipairs(values) do
			local valueKey = tostring(value)
			local optionButton = buttonBase(tostring(value))
			optionButton.Position = UDim2.fromOffset(4, 0)
			optionButton.Size = UDim2.new(1, -8, 0, 28)
			optionButton.BackgroundTransparency = 1
			optionButton.TextXAlignment = Enum.TextXAlignment.Left
			optionButton.Parent = list
			corner(7).Parent = optionButton
			padding(8).Parent = optionButton
			optionButtons[valueKey] = optionButton
			optionButton.MouseButton1Click:Connect(function()
				if multi then
					selectedSet[valueKey] = not selectedSet[valueKey]
					current = getSelectedList()
					setFlag(options.Flag, current)
					refreshOptions()
					safeCall(options.Callback, current)
				else
					current = value
					setFlag(options.Flag, value)
					refreshOptions()
					open = false
					resize()
					safeCall(options.Callback, value)
				end
			end)
		end
	end
	rebuildOptions()
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = string.lower(searchBox.Text)
		refreshOptions()
	end)
	attachListSizing(list)
	if multi then
		current = getSelectedList()
		setFlag(options.Flag, current)
	end
	refreshOptions()
	table.insert(ELEMENTS, {
		Apply = function()
			if card.Parent then
				refreshOptions()
			end
		end,
	})

	pick.MouseButton1Click:Connect(function()
		open = not open
		resize()
	end)

	local control = {
		Instance = card,
		Set = function(_, value: any, silent: boolean?)
			current = value
			if multi then
				selectedSet = {}
				if typeof(value) == "table" then
					for _, selectedValue in ipairs(value) do
						selectedSet[tostring(selectedValue)] = true
					end
				end
				current = getSelectedList()
			end
			setFlag(options.Flag, current)
			refreshOptions()
			if not silent then
				safeCall(options.Callback, current)
			end
		end,
		Get = function()
			return current
		end,
		Refresh = function(_, nextValues: { any }?, silent: boolean?)
			if nextValues then
				values = nextValues
			end
			if multi then
				local nextSelectedSet = {}
				for _, value in ipairs(values) do
					local valueKey = tostring(value)
					if selectedSet[valueKey] then
						nextSelectedSet[valueKey] = true
					end
				end
				selectedSet = nextSelectedSet
				current = getSelectedList()
			else
				local found = false
				for _, value in ipairs(values) do
					if tostring(value) == tostring(current) then
						current = value
						found = true
						break
					end
				end
				if not found then
					current = values[1] or "None"
				end
			end
			rebuildOptions()
			setFlag(options.Flag, current)
			refreshOptions()
			if not silent then
				safeCall(options.Callback, current)
			end
		end,
		SetValues = function(selfControl, nextValues: { any }?, silent: boolean?)
			selfControl:Refresh(nextValues, silent)
		end,
	}
	if shouldFireInitialCallback(options) then
		safeCall(options.Callback, current)
	end
	registerConfigBinding(options.Flag, control)
	return control
end

function Tab:Slider(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local min = options.Min or 0
	local max = options.Max or 100
	local decimals = options.Decimals or 0
	local value = math.clamp(options.Default or min, min, max)
	local card = makeCard(parent, options.Title or "Slider", 68)
	local titleLabel = card:FindFirstChildOfClass("TextLabel") :: TextLabel
	titleLabel.Size = UDim2.new(1, 0, 0, 18)
	local valueBox = make("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0, 34),
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		Text = tostring(value),
		TextColor3 = ACTIVE_THEME.Text,
		PlaceholderColor3 = ACTIVE_THEME.Muted,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		corner(7),
		stroke(ACTIVE_THEME.Stroke, 0.45),
	})
	bindTheme(valueBox, "BackgroundColor3", "PanelAlt")
	bindTheme(valueBox, "TextColor3", "Text")
	bindTheme(valueBox:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.45)

	local track = make("Frame", {
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, -54, 0, 6),
		BorderSizePixel = 0,
		Parent = card,
	}, { corner(8) })
	bindTheme(track, "BackgroundColor3", "PanelAlt")

	local trackHitbox = make("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, -54, 0, 28),
		Text = "",
		BorderSizePixel = 0,
		Parent = card,
	})

	local fill = make("Frame", {
		BackgroundColor3 = ACTIVE_THEME.Accent,
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		Parent = track,
	}, { corner(8) })
	bindTheme(fill, "BackgroundColor3", "Accent")

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = ACTIVE_THEME.Text,
		BorderSizePixel = 0,
		Parent = track,
	}, {
		corner(18),
		stroke(ACTIVE_THEME.Accent, 0.15, 2),
	})
	bindTheme(knob, "BackgroundColor3", "Text")
	bindTheme(knob:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Accent", 0.15)
	trackHitbox.ZIndex = math.max(track.ZIndex, knob.ZIndex) + 1

	local dragging = false
	local function format(n: number)
		local factor = 10 ^ decimals
		return math.floor(n * factor + 0.5) / factor
	end
	local function updateFromRatio(ratio: number, fire: boolean, animated: boolean?)
		ratio = math.clamp(ratio, 0, 1)
		value = format(min + (max - min) * ratio)
		local fillSize = UDim2.fromScale(ratio, 1)
		local knobPosition = UDim2.fromScale(ratio, 0.5)
		if animated then
			tween(fill, TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = fillSize })
			tween(
				knob,
				TweenInfo.new(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = knobPosition }
			)
		else
			fill.Size = fillSize
			knob.Position = knobPosition
		end
		valueBox.Text = tostring(value)
		setFlag(options.Flag, value)
		if fire then
			safeCall(options.Callback, value)
		end
	end
	local function setFixedValue(nextValue: any, fire: boolean)
		local numberValue = tonumber(nextValue)
		if not numberValue then
			valueBox.Text = tostring(value)
			return
		end
		numberValue = math.clamp(numberValue, min, max)
		updateFromRatio((numberValue - min) / math.max(max - min, 1), fire, true)
	end
	local function setFromInput(x: number)
		local ratio = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		updateFromRatio(ratio, true, true)
	end
	updateFromRatio((value - min) / math.max(max - min, 1), false, false)
	trackHitbox.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFromInput(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setFromInput(input.Position.X)
		end
	end)
	valueBox.FocusLost:Connect(function()
		setFixedValue(valueBox.Text, true)
	end)
	local control = {
		Instance = card,
		Set = function(_, nextValue: number, silent: boolean?)
			setFixedValue(nextValue, not silent)
		end,
		Get = function()
			return value
		end,
	}
	if shouldFireInitialCallback(options) then
		safeCall(options.Callback, value)
	end
	registerConfigBinding(options.Flag, control)
	return control
end

function Tab:Toggle(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local state = options.Default == true
	local keybindDisabled = isMobile()
	local hasKeybind = not keybindDisabled and options.Keybind ~= nil and options.Keybind ~= false
	local keyFlag = options.Flag and (options.Flag .. "_Keybind") or nil
	local modeFlag = options.Flag and (options.Flag .. "_KeybindMode") or nil
	local currentKey = nil
	if options.Keybind == true then
		currentKey = nil
	elseif hasKeybind then
		currentKey = normalizeBind(options.Keybind)
	end
	local keyMode = normalizeBindMode(options.Mode or options.KeybindMode)
	local listening = false
	local holding = false
	local suppressModeClick = false
	local hotkeyId = "Toggle_" .. HttpService:GenerateGUID(false)
	local hotkeyText = tostring(options.Title or options.Text or options.HotkeyText or "Toggle")
	local card = makeCard(parent, options.Title or options.Text or "Toggle", 50)
	local titleLabel = card:FindFirstChildOfClass("TextLabel") :: TextLabel
	titleLabel.Size = UDim2.new(1, hasKeybind and -138 or -58, 1, 0)

	local bind: TextButton? = nil
	if hasKeybind then
		bind = buttonBase(bindDisplayWithMode(currentKey, keyMode))
		bind.AnchorPoint = Vector2.new(1, 0.5)
		bind.Position = UDim2.new(1, -54, 0.5, 0)
		bind.Size = UDim2.fromOffset(72, 28)
		bind.Parent = card
		corner(8).Parent = bind
		bindTheme(bind, "BackgroundColor3", "PanelAlt")
		bindTheme(bind, "TextColor3", "Text")
	end

	local switch = make("TextButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		Text = "",
		BorderSizePixel = 0,
		Parent = card,
	}, {
		corner(24),
		stroke(ACTIVE_THEME.Stroke, 0.35),
	})
	bindTheme(switch:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.35)

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = ACTIVE_THEME.Muted,
		BorderSizePixel = 0,
		Parent = switch,
	}, { corner(18) })
	local toggleThemeBinding = {
		Apply = function()
			if switch.Parent and knob.Parent then
				switch.BackgroundColor3 = state and ACTIVE_THEME.Accent or ACTIVE_THEME.PanelAlt
				knob.BackgroundColor3 = state and ACTIVE_THEME.Text or ACTIVE_THEME.Muted
			end
		end,
	}
	table.insert(ELEMENTS, toggleThemeBinding)

	local function apply(nextState: boolean, fire: boolean)
		state = nextState
		setFlag(options.Flag, state)
		if hasKeybind then
			self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(currentKey), currentKey ~= nil, state and currentKey ~= nil)
		end
		tween(switch, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
			BackgroundColor3 = state and ACTIVE_THEME.Accent or ACTIVE_THEME.PanelAlt,
		})
		tween(knob, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
			Position = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = state and ACTIVE_THEME.Text or ACTIVE_THEME.Muted,
		})
		if fire then
			safeCall(options.Callback, state)
		end
	end

	local function saveKeybindConfig()
		if hasKeybind then
			setFlag(keyFlag, bindFlagValue(currentKey))
			setFlag(modeFlag, keyMode)
		end
	end

	if bind then
		bind.MouseButton1Click:Connect(function()
			listening = true
			bind.Text = "..."
		end)
		bind.MouseButton2Click:Connect(function()
			if listening or suppressModeClick then
				return
			end
			keyMode = keyMode == "Hold" and "Toggle" or "Hold"
			bind.Text = keyMode
			saveKeybindConfig()
			task.delay(2, function()
				if bind and bind.Parent and not listening then
					bind.Text = bindDisplayWithMode(currentKey, keyMode)
				end
			end)
			safeCallArgs(options.ModeChanged, keyMode, currentKey)
		end)
	end
	switch.MouseButton1Click:Connect(function()
		apply(not state, true)
	end)
	if not keybindDisabled then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if listening then
				local nextKey, isClear = bindFromInput(input)
				if nextKey ~= nil or isClear then
					currentKey = nextKey
					if bind then
						bind.Text = bindDisplayWithMode(currentKey, keyMode)
					end
					self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(currentKey), currentKey ~= nil, state and currentKey ~= nil)
					listening = false
					suppressModeClick = input.UserInputType == Enum.UserInputType.MouseButton2
					saveKeybindConfig()
					if suppressModeClick then
						task.delay(0.12, function()
							suppressModeClick = false
						end)
					end
					safeCall(options.KeyChanged, currentKey)
				end
				return
			end
			if not gameProcessed and inputMatchesBind(input, currentKey) then
				if keyMode == "Hold" then
					holding = true
					apply(true, true)
				else
					apply(not state, true)
				end
			end
		end)
		UserInputService.InputEnded:Connect(function(input, gameProcessed)
			if not gameProcessed and keyMode == "Hold" and holding and inputMatchesBind(input, currentKey) then
				holding = false
				apply(false, true)
			end
		end)
	end

	apply(state, false)
	saveKeybindConfig()
	local control = {
		Instance = card,
		Set = function(_, value: any, silent: boolean?)
			apply(value == true, not silent)
		end,
		Get = function()
			return state
		end,
		SetKey = function(_, key: any)
			if keybindDisabled then
				return
			end
			hasKeybind = true
			currentKey = key == nil and nil or normalizeBind(key, currentKey)
			if bind then
				bind.Text = bindDisplayWithMode(currentKey, keyMode)
			end
			saveKeybindConfig()
			self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(currentKey), currentKey ~= nil, state and currentKey ~= nil)
		end,
		GetKey = function()
			return currentKey
		end,
		SetMode = function(_, mode: any)
			if keybindDisabled then
				return
			end
			keyMode = normalizeBindMode(mode)
			if bind then
				bind.Text = bindDisplayWithMode(currentKey, keyMode)
			end
			saveKeybindConfig()
			if hasKeybind then
				self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(currentKey), currentKey ~= nil, state and currentKey ~= nil)
			end
			safeCallArgs(options.ModeChanged, keyMode, currentKey)
		end,
		GetMode = function()
			return keyMode
		end,
		SyncConfig = function(_, silent: boolean?)
			if keybindDisabled or not hasKeybind then
				return
			end
			local oldKey = currentKey
			local oldMode = keyMode
			if keyFlag and FLAGS[keyFlag] ~= nil then
				currentKey = normalizeBind(FLAGS[keyFlag], currentKey)
			end
			if modeFlag and FLAGS[modeFlag] ~= nil then
				keyMode = normalizeBindMode(FLAGS[modeFlag])
			end
			if bind then
				bind.Text = bindDisplayWithMode(currentKey, keyMode)
			end
			self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(currentKey), currentKey ~= nil, state and currentKey ~= nil)
			saveKeybindConfig()
			if not silent then
				if oldKey ~= currentKey then
					safeCall(options.KeyChanged, currentKey)
				end
				if oldMode ~= keyMode then
					safeCallArgs(options.ModeChanged, keyMode, currentKey)
				end
			end
		end,
	}
	if shouldFireInitialCallback(options) then
		safeCall(options.Callback, state)
	end
	registerConfigBinding(options.Flag, control)
	return control
end

function Tab:Keybind(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local current = normalizeBind(options.Default or options.Key or Enum.KeyCode.F)
	local keyMode = normalizeBindMode(options.Mode)
	local listening = false
	local holding = false
	local suppressModeClick = false
	local activeToken = 0
	local hotkeyId = "Keybind_" .. HttpService:GenerateGUID(false)
	local hotkeyText = tostring(options.HotkeyText or options.Title or "Keybind")
	local card = makeCard(parent, options.Title or "Keybind", 64)
	local bind = buttonBase(bindDisplayWithMode(current, keyMode))
	bind.AnchorPoint = Vector2.new(1, 0)
	bind.Position = UDim2.new(1, -4, 0, 2)
	bind.Size = UDim2.fromOffset(84, 32)
	bind.Parent = card
	corner(9).Parent = bind
	bindTheme(bind, "BackgroundColor3", "PanelAlt")
	bindTheme(bind, "TextColor3", "Text")
	setFlag(options.Flag, bindFlagValue(current))
	bind.MouseButton1Click:Connect(function()
		listening = true
		bind.Text = "..."
	end)
	bind.MouseButton2Click:Connect(function()
		if listening or suppressModeClick then
			return
		end
		keyMode = keyMode == "Hold" and "Toggle" or "Hold"
		bind.Text = keyMode
		task.delay(2, function()
			if bind.Parent and not listening then
				bind.Text = bindDisplayWithMode(current, keyMode)
			end
		end)
		safeCallArgs(options.ModeChanged, keyMode, current)
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if listening then
			local nextKey, isClear = bindFromInput(input)
			if nextKey ~= nil or isClear then
				current = nextKey
				bind.Text = bindDisplayWithMode(current, keyMode)
				setFlag(options.Flag, bindFlagValue(current))
				self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(current), false)
				listening = false
				suppressModeClick = input.UserInputType == Enum.UserInputType.MouseButton2
				if suppressModeClick then
					task.delay(0.12, function()
						suppressModeClick = false
					end)
				end
				safeCall(options.Changed, current)
			end
			return
		end
		if not gameProcessed and inputMatchesBind(input, current) then
			if keyMode == "Hold" then
				holding = true
				self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(current), true)
				safeCallArgs(options.Callback, current, true)
			else
				activeToken += 1
				local token = activeToken
				self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(current), true)
				task.delay(options.HotkeyDuration or 0.65, function()
					if activeToken == token then
						self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(current), false)
					end
				end)
				safeCall(options.Callback, current)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if not gameProcessed and keyMode == "Hold" and holding and inputMatchesBind(input, current) then
			holding = false
			self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(current), false)
			safeCallArgs(options.Callback, current, false)
		end
	end)
	local control = {
		Instance = card,
		Set = function(_, key: any, silent: boolean?)
			current = normalizeBind(key, current)
			bind.Text = bindDisplayWithMode(current, keyMode)
			setFlag(options.Flag, bindFlagValue(current))
			self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(current), holding and current ~= nil)
			if not silent then
				safeCall(options.Changed, current)
			end
		end,
		Get = function()
			return current
		end,
		SetMode = function(_, mode: any)
			keyMode = normalizeBindMode(mode)
			bind.Text = bindDisplayWithMode(current, keyMode)
			self.Window:_setHotkeyActive(hotkeyId, hotkeyText, bindDisplay(current), holding and current ~= nil)
			safeCallArgs(options.ModeChanged, keyMode, current)
		end,
		GetMode = function()
			return keyMode
		end,
	}
	registerConfigBinding(options.Flag, control)
	return control
end

function Tab:Colorpicker(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local current = options.Default or ACTIVE_THEME.Accent
	local card = makeCard(parent, options.Title or "Colorpicker", 92)
	local swatch = make("TextButton", {
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(34, 28),
		BackgroundColor3 = current,
		Text = "",
		BorderSizePixel = 0,
		Parent = card,
	}, {
		corner(8),
		stroke(ACTIVE_THEME.Stroke, 0.25),
	})
	bindTheme(swatch:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.25)

	local sliders = {}
	local values = {
		R = math.floor(current.R * 255),
		G = math.floor(current.G * 255),
		B = math.floor(current.B * 255),
	}

	local function currentRgbColor()
		return Color3.fromRGB(math.clamp(values.R, 0, 255), math.clamp(values.G, 0, 255), math.clamp(values.B, 0, 255))
	end

	local function apply(fire: boolean)
		current = currentRgbColor()
		swatch.BackgroundColor3 = current
		setFlag(options.Flag, current)
		if options.ThemeKey then
			local theme = {}
			theme[options.ThemeKey] = current
			mergeTheme(theme)
		end
		if fire then
			safeCall(options.Callback, current)
		end
	end

	for index, channel in ipairs({ "R", "G", "B" }) do
		local row = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 28 + (index - 1) * 18),
			Size = UDim2.new(1, -44, 0, 14),
			Parent = card,
		})
		local track = make("Frame", {
			BackgroundColor3 = ACTIVE_THEME.PanelAlt,
			Position = UDim2.new(0, 18, 0.5, -3),
			Size = UDim2.new(1, -18, 0, 6),
			BorderSizePixel = 0,
			Parent = row,
		}, { corner(6) })
		bindTheme(track, "BackgroundColor3", "PanelAlt")
		local fill = make("Frame", {
			BackgroundColor3 = channel == "R" and Color3.fromRGB(255, 96, 126)
				or channel == "G" and Color3.fromRGB(72, 221, 146)
				or Color3.fromRGB(37, 173, 255),
			Size = UDim2.fromScale(values[channel] / 255, 1),
			BorderSizePixel = 0,
			Parent = track,
		}, { corner(6) })
		local tag = label(channel, 10, ACTIVE_THEME.Muted, Enum.Font.GothamBold)
		tag.Size = UDim2.fromOffset(16, 14)
		tag.Parent = row
		bindTheme(tag, "TextColor3", "Muted")
		sliders[channel] = { Track = track, Fill = fill }
	end

	local draggingChannel: string? = nil
	local function setChannel(channel: string, x: number)
		local data = sliders[channel]
		local ratio = math.clamp((x - data.Track.AbsolutePosition.X) / math.max(data.Track.AbsoluteSize.X, 1), 0, 1)
		values[channel] = math.floor(ratio * 255 + 0.5)
		data.Fill.Size = UDim2.fromScale(ratio, 1)
		apply(true)
	end
	for channel, data in pairs(sliders) do
		data.Track.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				draggingChannel = channel
				setChannel(channel, input.Position.X)
			end
		end)
	end
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			draggingChannel = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			draggingChannel
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			setChannel(draggingChannel, input.Position.X)
		end
	end)
	swatch.MouseButton1Click:Connect(function()
		current = currentRgbColor()
		if options.ThemeKey then
			local theme = {}
			theme[options.ThemeKey] = current
			mergeTheme(theme)
		end
		safeCall(options.Callback, current)
	end)
	apply(false)
	local control = {
		Instance = card,
		Set = function(_, color: Color3, silent: boolean?)
			current = color
			values.R = math.floor(color.R * 255)
			values.G = math.floor(color.G * 255)
			values.B = math.floor(color.B * 255)
			for channel, data in pairs(sliders) do
				data.Fill.Size = UDim2.fromScale(values[channel] / 255, 1)
			end
			apply(not silent)
		end,
		Get = function()
			return currentRgbColor()
		end,
	}
	if shouldFireInitialCallback(options) then
		safeCall(options.Callback, currentRgbColor())
	end
	registerConfigBinding(options.Flag, control)
	return control
end

function Tab:Config(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local currentName = tostring(options.Name or options.Default or "Default")
	local card = makeCard(parent, options.Title or "Config", 136)
	local leftWidth = 0.42
	local gap = 8

	local input = make("TextBox", {
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		Position = UDim2.new(leftWidth, gap, 0, 26),
		Size = UDim2.new(1 - leftWidth, -(gap + 4), 0, 28),
		Text = currentName,
		PlaceholderText = options.Placeholder or "Config name",
		TextColor3 = ACTIVE_THEME.Text,
		PlaceholderColor3 = ACTIVE_THEME.Muted,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
		Parent = card,
	}, {
		corner(8),
		padding(8),
		stroke(ACTIVE_THEME.Stroke, 0.45),
	})
	bindTheme(input, "BackgroundColor3", "PanelAlt")
	bindTheme(input, "TextColor3", "Text")
	bindTheme(input, "PlaceholderColor3", "Muted")
	bindTheme(input:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.45)

	local dropdownButton = buttonBase("No configs")
	dropdownButton.Position = UDim2.fromOffset(4, 26)
	dropdownButton.Size = UDim2.new(leftWidth, -4, 0, 28)
	dropdownButton.TextXAlignment = Enum.TextXAlignment.Left
	dropdownButton.Parent = card
	corner(8).Parent = dropdownButton
	padding(8).Parent = dropdownButton
	bindTheme(dropdownButton, "BackgroundColor3", "PanelAlt")
	bindTheme(dropdownButton, "TextColor3", "Text")

	local dropdownPanel = make("Frame", {
		BackgroundColor3 = ACTIVE_THEME.PanelAlt,
		Position = UDim2.fromOffset(4, 58),
		Size = UDim2.new(leftWidth, -4, 0, 0),
		ClipsDescendants = true,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
		Parent = card,
	}, {
		corner(8),
		stroke(ACTIVE_THEME.Stroke, 0.45),
	})
	bindTheme(dropdownPanel, "BackgroundColor3", "PanelAlt")
	bindTheme(dropdownPanel:FindFirstChildOfClass("UIStroke") :: Instance, "Color", "Stroke", 0.45)

	local dropdownList = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = ACTIVE_THEME.Accent,
		ScrollBarImageTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = dropdownPanel,
	}, {
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	attachListSizing(dropdownList)

	local save = buttonBase("Save")
	save.Position = UDim2.new(leftWidth, gap, 0, 60)
	save.Size = UDim2.new((1 - leftWidth) / 2, -7, 0, 28)
	save.Parent = card
	corner(8).Parent = save
	bindTheme(save, "BackgroundColor3", "PanelAlt")
	bindTheme(save, "TextColor3", "Text")

	local load = buttonBase("Load")
	load.Position = UDim2.new(leftWidth + ((1 - leftWidth) / 2), gap + 3, 0, 60)
	load.Size = UDim2.new((1 - leftWidth) / 2, -7, 0, 28)
	load.Parent = card
	corner(8).Parent = load
	bindTheme(load, "BackgroundColor3", "PanelAlt")
	bindTheme(load, "TextColor3", "Text")

	local refresh = buttonBase("Refresh")
	refresh.Position = UDim2.new(leftWidth, gap, 0, 94)
	refresh.Size = UDim2.new((1 - leftWidth) / 2, -7, 0, 28)
	refresh.Parent = card
	corner(8).Parent = refresh
	bindTheme(refresh, "BackgroundColor3", "PanelAlt")
	bindTheme(refresh, "TextColor3", "Text")

	local deleteButton = buttonBase("Delete")
	deleteButton.Position = UDim2.new(leftWidth + ((1 - leftWidth) / 2), gap + 3, 0, 94)
	deleteButton.Size = UDim2.new((1 - leftWidth) / 2, -7, 0, 28)
	deleteButton.Parent = card
	corner(8).Parent = deleteButton
	bindTheme(deleteButton, "BackgroundColor3", "PanelAlt")
	bindTheme(deleteButton, "TextColor3", "Text")

	local open = false
	local cachedData = ""
	local configNames = {}
	local optionButtons = {}

	local function setDropdownOpen(nextOpen: boolean)
		open = nextOpen
		dropdownPanel.Visible = true
		local height = open and math.min(#configNames, 4) * 28 or 0
		tween(dropdownPanel, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(leftWidth, -4, 0, height),
		})
		task.delay(0.17, function()
			if not open and dropdownPanel.Parent then
				dropdownPanel.Visible = false
			end
		end)
	end

	local function refreshList()
		for _, button in ipairs(optionButtons) do
			button:Destroy()
		end
		table.clear(optionButtons)
		configNames = listConfigNames()
		if #configNames == 0 and currentName ~= "" then
			table.insert(configNames, sanitizeConfigName(currentName))
		end
		dropdownButton.Text = #configNames > 0 and currentName or "No configs"
		for _, configName in ipairs(configNames) do
			local optionButton = buttonBase(configName)
			optionButton.Size = UDim2.new(1, 0, 0, 28)
			optionButton.BackgroundTransparency = configName == currentName and 0 or 1
			optionButton.BackgroundColor3 = configName == currentName and ACTIVE_THEME.Accent or ACTIVE_THEME.PanelAlt
			optionButton.TextColor3 = configName == currentName and ACTIVE_THEME.Text or ACTIVE_THEME.Muted
			optionButton.TextXAlignment = Enum.TextXAlignment.Left
			optionButton.ZIndex = 22
			optionButton.Parent = dropdownList
			corner(7).Parent = optionButton
			padding(8).Parent = optionButton
			table.insert(optionButtons, optionButton)
			optionButton.MouseButton1Click:Connect(function()
				currentName = configName
				input.Text = configName
				dropdownButton.Text = configName
				setDropdownOpen(false)
				safeCall(options.Callback, configName)
			end)
		end
		setDropdownOpen(false)
	end

	input.FocusLost:Connect(function()
		currentName = sanitizeConfigName(input.Text ~= "" and input.Text or "Default")
		input.Text = currentName
	end)
	dropdownButton.MouseButton1Click:Connect(function()
		if #configNames > 0 then
			setDropdownOpen(not open)
		end
	end)
	save.MouseButton1Click:Connect(function()
		currentName = sanitizeConfigName(input.Text ~= "" and input.Text or "Default")
		input.Text = currentName
		local existed = configExists(configPath(currentName))
		cachedData = Library:SaveConfig(currentName)
		refreshList()
		self.Window:Notify({ Title = "Config", Content = "Saved " .. currentName })
		if not existed then
			safeCall(options.Created, currentName)
		end
		safeCall(options.Saved, currentName)
	end)
	load.MouseButton1Click:Connect(function()
		if canUseFiles() then
			Library:LoadConfig(currentName)
			self.Window:Notify({ Title = "Config", Content = "Loaded " .. currentName })
			safeCall(options.Loaded, currentName)
		elseif cachedData ~= "" then
			Library:LoadConfig(cachedData)
			self.Window:Notify({ Title = "Config", Content = "Loaded memory config" })
			safeCall(options.Loaded, currentName)
		else
			self.Window:Notify({ Title = "Config", Content = "No config saved" })
		end
	end)
	refresh.MouseButton1Click:Connect(function()
		refreshList()
		self.Window:Notify({ Title = "Config", Content = "Config list refreshed" })
		safeCall(options.Refreshed, configNames)
	end)
	deleteButton.MouseButton1Click:Connect(function()
		currentName = sanitizeConfigName(input.Text ~= "" and input.Text or "Default")
		input.Text = currentName
		local ok, message = deleteConfig(currentName)
		if ok then
			cachedData = ""
			self.Window:Notify({ Title = "Config", Content = "Deleted " .. currentName })
			safeCall(options.Deleted, currentName)
			refreshList()
		else
			self.Window:Notify({ Title = "Config", Content = message })
		end
	end)
	refreshList()

	return {
		Instance = card,
		Input = input,
		Dropdown = dropdownButton,
		Refresh = refreshList,
		Get = function()
			return currentName
		end,
		Set = function(_, nextName: string, silent: boolean?)
			currentName = sanitizeConfigName(tostring(nextName))
			input.Text = currentName
			dropdownButton.Text = currentName
			if not silent then
				safeCall(options.Callback, currentName)
			end
		end,
		Load = function()
			if canUseFiles() then
				Library:LoadConfig(currentName)
			elseif cachedData ~= "" then
				Library:LoadConfig(cachedData)
			end
		end,
		Delete = function()
			return deleteConfig(currentName)
		end,
	}
end

function Tab:Theme(options: { [string]: any })
	options = options or {}
	local parent = self:_parent(options)
	local card = makeCard(parent, options.Title or "Theme", 122)
	local presets = options.Presets
		or {
			{
				Name = "Midnight",
				Accent = Color3.fromRGB(124, 92, 255),
				Accent2 = Color3.fromRGB(37, 173, 255),
				Window = Color3.fromRGB(13, 17, 38),
				Panel = Color3.fromRGB(17, 22, 49),
				PanelAlt = Color3.fromRGB(22, 27, 61),
			},
			{
				Name = "Abyss",
				Accent = Color3.fromRGB(80, 140, 255),
				Accent2 = Color3.fromRGB(184, 95, 255),
				Window = Color3.fromRGB(7, 14, 30),
				Panel = Color3.fromRGB(12, 25, 48),
				PanelAlt = Color3.fromRGB(18, 34, 64),
			},
			{
				Name = "Neon",
				Accent = Color3.fromRGB(163, 104, 255),
				Accent2 = Color3.fromRGB(53, 231, 255),
				Window = Color3.fromRGB(14, 10, 34),
				Panel = Color3.fromRGB(23, 17, 51),
				PanelAlt = Color3.fromRGB(32, 24, 68),
			},
		}
	for index, preset in ipairs(presets) do
		local y = 22 + (index - 1) * 27
		local b = buttonBase(preset.Name)
		b.Position = UDim2.fromOffset(4, y)
		b.Size = UDim2.new(1, -8, 0, 24)
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Parent = card
		corner(8).Parent = b
		padding(8).Parent = b
		bindTheme(b, "BackgroundColor3", "PanelAlt")
		bindTheme(b, "TextColor3", "Text")
		b.MouseButton1Click:Connect(function()
			mergeTheme(preset)
			self.Window:Notify({ Title = "Theme", Content = "Applied " .. preset.Name })
		end)
	end
	return { Instance = card }
end

function Tab:Notify(options: { [string]: any })
	return self.Window:Notify(options)
end

Library.Theme = ACTIVE_THEME
Library.Flags = FLAGS

return setmetatable(Library, {
	__call = function(_, ...)
		return Library:Window(...)
	end,
})
