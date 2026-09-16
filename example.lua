--[[
    WindUI [ MoonUI Mod ] 示例
    ----------------------------------------
    本 Mod 改动:
    1. 最小化悬浮窗全平台显示（原版 PC 端不显示）
    2. 悬浮窗替换为流光渐变药丸：标题 · FPS · Ping，可拖拽
    3. 内置 14 套流光主题，可在面板切换或用 API 直接调用
    4. 悬浮窗 ⇆ 主窗口 开合动画已适配

    API:
      WindUI.FloatThemeOrder          -> 主题名有序列表 (table)
      WindUI.FloatThemes              -> 主题名 -> 颜色表 (table)
      WindUI:SetFloatTheme(name)      -> 全局切换悬浮窗主题
      Window:SetFloatTheme(name)      -> 切换悬浮窗主题
      Window:GetFloatTheme()          -> 当前悬浮窗主题名
      Window:SetFloatVisible(bool)    -> 显示/隐藏悬浮窗
      Window:EditOpenButton{...}      -> 支持 Theme / Position / Draggable / Title / Color(ColorSequence)
]]

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/LaPlua/Test/main/WindUI.lua"))()

local Window = WindUI:CreateWindow({
    Title = "WOW",
    Icon = "moon",
    Author = "MoonUI Mod",
    Folder = "MoonUIMod",
    Size = UDim2.new(0, 580, 0, 460),
    Transparent = true,
    ToggleKey = Enum.KeyCode.RightShift, -- 按 RightShift 在 窗口 ⇆ 悬浮窗 之间切换
    OpenButton = {
        Theme = "极光紫", -- 悬浮窗初始主题，可换成 14 套主题里任意一个
    },
})

--------------------------------------------------
-- 演示标签页
--------------------------------------------------
local DemoTab = Window:Tab({
    Title = "功能演示",
    Icon = "sparkles",
})

DemoTab:Section({ Title = "基础元素" })

DemoTab:Button({
    Title = "按钮",
    Desc = "点击试试",
    Callback = function()
        WindUI:Notify({
            Title = "WOW",
            Content = "按钮被点击了",
            Duration = 3,
        })
    end,
})

DemoTab:Toggle({
    Title = "开关",
    Value = true,
    Callback = function(state)
        print("开关状态:", state)
    end,
})

DemoTab:Slider({
    Title = "滑块",
    Value = { Default = 50, Min = 0, Max = 100 },
    Callback = function(value)
        print("滑块值:", value)
    end,
})

--------------------------------------------------
-- 悬浮窗设置标签页
--------------------------------------------------
local FloatTab = Window:Tab({
    Title = "悬浮窗",
    Icon = "palette",
})

FloatTab:Section({ Title = "流光主题（14 套）" })

-- 面板中切换主题：下拉框直接列出全部主题
FloatTab:Dropdown({
    Title = "悬浮窗主题",
    Desc = "切换最小化悬浮窗的流光配色",
    Values = WindUI.FloatThemeOrder, -- { "极光紫", "星河银", ..., "彩虹" }
    Value = "极光紫",
    Callback = function(themeName)
        Window:SetFloatTheme(themeName)
    end,
})

FloatTab:Button({
    Title = "随机主题",
    Desc = "随机换一套流光配色",
    Callback = function()
        local list = WindUI.FloatThemeOrder
        local pick = list[math.random(1, #list)]
        WindUI:SetFloatTheme(pick) -- 也可以直接用全局 API
        WindUI:Notify({
            Title = "悬浮窗主题",
            Content = "已切换为: " .. pick,
            Duration = 2,
        })
    end,
})

FloatTab:Section({ Title = "悬浮窗行为" })

FloatTab:Toggle({
    Title = "最小化时显示悬浮窗",
    Desc = "关闭后主窗口最小化为流光药丸（PC / 手机都生效）",
    Value = true,
    Callback = function(state)
        -- 只是演示: 隐藏后仍可用 ToggleKey(RightShift) 重新打开
        Window.IsOpenButtonEnabled = state
    end,
})

FloatTab:Button({
    Title = "关闭窗口查看悬浮窗",
    Desc = "点击后主窗口收起，顶部出现流光药丸，点药丸可重新打开",
    Callback = function()
        Window:Close()
    end,
})
