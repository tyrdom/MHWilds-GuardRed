-- reframework/autorun/guard_red.lua
-- 霸体 / 相杀期间受伤 → 只记为可回复红血（不产生永久掉血）。
-- 依赖：REFramework nightly。零第三方库。
--
-- 用法：把本文件放到 <游戏目录>/reframework/autorun/ 下，启动游戏后在
-- REFramework 菜单里打开 / 关闭。字段名确认前脚本会保持空转（只打日志）。

local CONFIG = {
    -- ===== 待确认：先用 tools/probe.lua 找到真实字段名 =====
    hp = "HP",
    max_hp = "MaxHP",
    red = "RedHP",          -- 红血 / 可回复量字段

    -- ===== 待确认：霸体 / 相杀对应的 STATUS_FLAG 值（可以填多个） =====
    guard_flags = {},
    -- 例：guard_flags = { 12, 13 },

    mode = "lock",          -- "lock" = 红池只增不减；"add" = 按本帧掉血量补进红池
    clamp_on_exit = true,   -- 离开状态时把残留红血修回 max-hp，避免白送回复
    debug = false,
}

local enabled = true
local last_red = nil
local last_hp = nil
local warned = false
local was_in_state = false

local function log_once(msg)
    if warned then return end
    warned = true
    log.info("[guard_red] " .. msg)
end

local function get_hunter()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    local p = pm and pm:call("getMasterPlayer")
    return p and p:call("get_Character")
end

local function in_guard_state(h)
    if #CONFIG.guard_flags == 0 then return false end
    local flags = h:call("get_HunterStatus"):get_field("_HunterStatusFlag")
    if not flags then return false end
    for _, v in ipairs(CONFIG.guard_flags) do
        if flags:call("check(System.UInt32)", v) then return true end
    end
    return false
end

local function read_num(h, name)
    local v = h:get_field(name)
    if type(v) == "number" then return v end
    return nil
end

re.on_frame(function()
    if not enabled then return end
    if #CONFIG.guard_flags == 0 then
        log_once("未配置 guard_flags，先用 tools/probe.lua 确认状态标志")
        return
    end

    local ok, err = pcall(function()
        local h = get_hunter()
        if not h then return end

        local hp = read_num(h, CONFIG.hp)
        local max_hp = read_num(h, CONFIG.max_hp)
        local red = read_num(h, CONFIG.red)
        if hp == nil or max_hp == nil or red == nil then
            log_once("字段读取失败，检查 CONFIG.hp / max_hp / red")
            return
        end

        local active = in_guard_state(h)

        if active then
            if CONFIG.mode == "lock" then
                -- 红池只增不减：抵消“被伤害吃掉的红血”，回复不再消耗，于是持续回血
                if last_red and red < last_red then
                    h:set_field(CONFIG.red, last_red)
                    red = last_red
                end
            else
                -- 按本帧掉血量补进红池：缺失的血全部变成可回复
                if last_hp and hp < last_hp then
                    local delta = last_hp - hp
                    local target = math.min(max_hp - hp, red + delta)
                    if target > red then
                        h:set_field(CONFIG.red, target)
                        red = target
                    end
                end
            end
        elseif was_in_state and CONFIG.clamp_on_exit then
            -- 收尾：红血最多等于已缺失的血量
            local cap = max_hp - hp
            if red > cap then h:set_field(CONFIG.red, cap) end
        end

        last_red = red
        last_hp = hp
        was_in_state = active

        if CONFIG.debug then
            log.info(string.format("[guard_red] state=%s hp=%.1f max=%.1f red=%.1f",
                tostring(active), hp, max_hp, red))
        end
    end)
    if not ok then
        log_once("frame error: " .. tostring(err))
    end
end)

re.on_draw_ui(function()
    if not imgui.tree_node("GuardRed") then return end
    local changed
    changed, enabled = imgui.checkbox("启用", enabled)
    imgui.text("模式: " .. CONFIG.mode)
    imgui.text(string.format("状态标志数: %d", #CONFIG.guard_flags))
    imgui.tree_pop()
end)

log.info("[guard_red] loaded")
