--------------------------------------------------------------------------------------------------------
--- log to file
FocusMouseLogFile = assert(io.open('logs/focus.mouse.log', 'a'))
FocusMouseLogFile:setvbuf("line")

local old_print, tostring = print, tostring
local tconcat, pack = table.concat, table.pack
print = function(...)
    local vals = pack(...)

    for k = 1, vals.n do
        vals[k] = tostring(vals[k])
    end

    local l = tconcat(vals, "\t")
    FocusMouseLogFile:write(l, '\n')
    return old_print(l)
end
--------------------------------------------------------------------------------------------------------

local Mouse = hs.mouse
local Window = hs.window
local Timer = hs.timer
local SpacesWatcher = hs.spaces.watcher
local Geometry = hs.geometry
local Logger = hs.logger.new("mouse", "verbose")


-----------------------------------------------------------------------------------------------------------
-- 鼠标移动到不同显示器时，更改焦点

-- 上一个时间点鼠标的位置
local PrevMouseAbPosX = -1
local PrevMouseAbPosY = -1

-- 上次触发焦点窗口ID
local PrevFocusWindowId = -1


--local MouseScreenId = -1
--local windowId = -1
--local focusWindowId = -1

-- 监听鼠标事件
function watcherMouse()
    local mouseAbPos = Mouse.absolutePosition()
    if PrevMouseAbPosX == mouseAbPos["x"] and PrevMouseAbPosY == mouseAbPos["y"] then
        return
    end

    PrevMouseAbPosX = mouseAbPos["x"]
    PrevMouseAbPosY = mouseAbPos["y"]

    focusWithMouse()
end


-- 实时监听鼠标位置，每100ms查看一次
-- NOTE:分配给局部变量可能自动停止
MouseWatcherId = Timer.doEvery(0.3, watcherMouse)

--------------------------------------------------------------------------------------------------------
-- 左右切换space时，更新鼠标焦点

function spacesWatcherHandler(spaceId)
    Logger.f("space switch " .. tostring(spaceId))
    MouseScreenId = -1
    focusWithMouse(cts)
end

spacesWatcherId = SpacesWatcher.new(spacesWatcherHandler)
spacesWatcherId:start()

--------------------------------------------------------------------------------------------------------

-- 触发焦点
function focusWithMouse()
    local start = os.time()

    -- 鼠标所在显示器
    local mouseScreen = Mouse.getCurrentScreen()
    if mouseScreen == nil then
        Logger.wf("mouse screen is nil")
        return
    end

    local mouseScreenId = mouseScreen:id()
    local mouseScreenUUID = mouseScreen:getUUID()

    Logger.f("mouse screen id %s", mouseScreenId)

    -- 显示器没有变化时，鼠标所在显示器没有变化时，不做处理
    --if currentMouseScreenId == MouseScreenId then
    --    return
    --end
    --Logger.vf("currentMouseScreenUUID %s ",  os.time() - start)

    -- 鼠标所在显示器 TODO
    --MouseScreenId = mouseScreenId

    --local activeSpaces = hs.spaces.activeSpaces()
    --local currentActiveScreenSpaceId = activeSpaces[currentMouseScreenUUID]
    --local windowIdsInSpace = hs.spaces.windowsForSpace(currentActiveScreenSpaceId)
    --Logger.f("activeSpaces %s %s", currentMouseScreenUUID, windowIdsInSpace)

    --------------------------------------------------------------------------------------------------------

    -- 获取全部可显示的窗口
    local visibleWindows = Window.visibleWindows()
    if visibleWindows == nil then
        Logger.wf("visible windows is nil")
        return
    end

    --Logger.f("visible Windows %s ", os.time() - start)

    for idx, win in ipairs(visibleWindows) do
        local windowId = win:id()
        local windowScreen = win:screen()
        local windowScreenId = windowScreen:id()
        local windowApplication = win:application()
        local windowFrame = win:frame()
        local windowIsFullScreen = win:isFullScreen()
        local windowIsVisible = win:isVisible()
        local windowTitle = win:title()

        ------------------------------------------------------------
        --local activeSpaces = hs.spaces.activeSpaces()
        --Logger.f("activeSpaces %s %s %s", currentMouseScreenUUID, currentWindowId, activeSpaces)
        --for k, v in ipairs(activeSpaces) do
        --    Logger.f("activeSpaces " .. k .. " = " .. v)
        --end
        ------------------------------------------------------------

        -- 窗口与鼠标不再同一个显示器
        if windowScreenId ~= mouseScreenId then
            Logger.vf("window is not same mouseScreenId")
            goto continue
        end

        --x, y, w, h
        Logger.vf("screenId:%5s, windowId:%5s, full: %5s, visible: %5s, title: %s",
                windowScreenId,
                windowId,
                windowIsFullScreen,
                windowIsVisible,
                string.sub(windowTitle, 1, 8)
        )

        -- 窗口不显示
        if not windowIsVisible then
            Logger.vf("window is not visible")
            goto continue
        end

        -- 窗口不是全屏显示
        if not windowIsFullScreen then
            Logger.vf("window is not full screen")
            goto continue
        end

        -- 鼠标在窗口区域范围内
        local isInsideWindow = Geometry.point(PrevMouseAbPosX, PrevMouseAbPosY):inside(windowFrame)
        if not isInsideWindow then
            Logger.vf("window is not inside window")
            goto continue
        end

        -- TODO 超时处理
        local now = os.time()
        local runDur = now - start
        if runDur >= 1 then
            Logger.wf("超时 %s ", runDur)
        end

        if PrevFocusWindowId == windowId then
            Logger.vf("window id same PrevFocusWindowId")
            goto continue
        end

        PrevFocusWindowId = windowId

        -- TODO 同一个窗口多个应用时的焦点选择方案
        -- TODO 非全屏时焦点选择方案
        win:focus()
        Logger.f("[" .. windowTitle .. "] focus")
        break

        :: continue ::
    end

    Logger.f("\n\n")
end
