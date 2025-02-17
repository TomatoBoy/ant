local imgui     = require "imgui"
local uiconfig  = require "widget.config"
local utils     = require "common.utils"
local cthread   = require "bee.thread"
local log_widget = require "widget.log"
local m = {}
local log_item_height = 22
local console_sender
function m.init_console_sender()
    if not console_sender then
        console_sender = cthread.channel "console_channel"
    end
end

local command_queue = {}
local history_pos = -1
local console = {
    text = "",
    flags = imgui.flags.InputText{"EnterReturnsTrue", "CallbackCompletion", "CallbackHistory"},
    up = function()
            if #command_queue < 1 then return "" end

            local prev_history_pos = history_pos
            if history_pos == -1 then
                history_pos = #command_queue - 1
            elseif history_pos > 0 then
                history_pos = history_pos - 1
            end
            if prev_history_pos ~= history_pos then
                return (history_pos >= 0) and command_queue[history_pos + 1] or ""
            else
                return nil
            end
        end,
    down = function()
            if #command_queue < 1 then return "" end

            local prev_history_pos = history_pos
            if history_pos ~= -1 then
                history_pos = history_pos + 1
                if history_pos >= #command_queue then
                    history_pos = -1
                end
            end
            if prev_history_pos ~= history_pos then
                return (history_pos >= 0) and command_queue[history_pos + 1] or ""
            else
                return nil
            end
        end
}

local function exec_command(command)
    history_pos = -1
    local exist_idx = 0
    for i, v in ipairs(command_queue) do
        if v == command then
            exist_idx = i
            break
        end
    end
    if exist_idx ~= 0 then
        table.remove(command_queue, exist_idx)
    end
    table.insert(command_queue, command)
    log_widget.info({
        tag = "Console",
        message = "[" .. utils.time2str(os.time()) .. "][INFO][Console]" .. command,
        height = log_item_height,
        line_count = 1
    })
    if console_sender then
        console_sender:push(command)
    end
end

local faicons   = require "common.fa_icons"
local function show_input()
    imgui.widget.Text(faicons.ICON_FA_TERMINAL)
    imgui.cursor.SameLine()
    local reclaim_focus = false
    imgui.cursor.PushItemWidth(-1)
    if imgui.widget.InputText("##SingleLineInput", console) then
        local command = tostring(console.text)
        if command ~= "" then
            exec_command(command)
            console.text = ""
        end
        reclaim_focus = true
    end
    imgui.cursor.PopItemWidth()
    imgui.util.SetItemDefaultFocus()
    if reclaim_focus then
        imgui.util.SetKeyboardFocusHere(-1)
    end
    imgui.cursor.Separator()
end

function m.get_title()
    return "Console"
end

function m.show()
    local viewport = imgui.GetMainViewport()
    imgui.windows.SetNextWindowPos(viewport.WorkPos[1], viewport.WorkPos[2] + viewport.WorkSize[2] - uiconfig.BottomWidgetHeight, 'F')
    imgui.windows.SetNextWindowSize(viewport.WorkSize[1], uiconfig.BottomWidgetHeight, 'F')
    if imgui.windows.Begin("Console", imgui.flags.Window { "NoCollapse", "NoScrollbar", "NoClosed" }) then
        show_input()
        log_widget.showConsole()
    end
    imgui.windows.End()
end

return m