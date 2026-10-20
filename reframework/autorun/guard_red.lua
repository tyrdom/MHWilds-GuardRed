-- reframework/autorun/guard_red.lua
--
-- 霸体 / 相杀期间受到的伤害 100% 记为可回复红血（不产生永久掉血）。
-- 适用于《怪物猎人：荒野》+ REFramework。
--
-- ================== 实测结论（2026-10-20，游戏 build 24705561） ==================
--
-- 对象路径：
--   hunter.get_HunterStatus()            -> app.cHunterStatus
--     ._Health                           -> app.cHunterHealth
--          get_RedHealth() / setRedHealth(v)   「红血上限」，绝对 HP 值
--     ._Health.get_HealthMgr()           -> app.cHealthManager
--          get_Health() / get_MaxHealth()      当前 HP / 上限
--     ._HunterStatusFlag                 -> ace.cSafeContinueFlagGroup
--          check(System.UInt32, n)             状态位 n 是否开启
--
-- 血量规则（普通受击 D）：
--   HP 掉 D，红血上限 = 新HP + 0.5*D      ← 引擎只给一半可回
--   恢复：每 1.5 秒 +1 HP，HP 涨到红血上限就停
--   中毒：只扣 HP、不动红血上限          ← 所以「HP < 红血上限」是合法状态
--
-- 实现要点（踩过的坑）：
--   * 必须直接写字段 _RedHealth；调用方法 setRedHealth() 会让引擎把差额
--     算进下一击伤害（实测一次 21 点的攻击变成 185，直接秒杀）。
--   * 目标值要取 max(受伤前红血上限, 受伤前 HP)，否则身上已有红血时会被拉低。
--   * 不要在 on_frame 里注册 hook 打日志 —— 会让游戏闪退。
--
-- 状态位（app.HunterDef.STATUS_FLAG，按枚举顺序编号）：
--   7 = SUPER_ARMOR   动作自带霸体（蓄力、上捞斩起手就有）—— 不用
--   8 = HYPER_ARMOR   铁壁级霸体（相杀命中、肩撞、全解等会挂）—— 只认这个
--
-- ================================ 配置 ================================
local CONFIG = {
    enabled = true,
    armor_only = true,        -- true = 只在铁壁/相杀状态生效
    armor_flags = { 8 },      -- 只认 HYPER_ARMOR；要连起手霸体一起算就改成 { 7, 8 }
    mode = "red",             -- "red" = 还原红血上限（默认）；"heal" = 直接补绿血（备选）
    debug = false,            -- true = 每次写值都打一行日志
}

local last = nil
local warned = {}
local ui = {}

local flag_state = nil        -- nil=未探测；false=引擎拒绝该编号(停用)；true=可用
local armor_now = false

local function log_once(key, msg)
    if warned[key] then return end
    warned[key] = true
    log.info("[guard_red] " .. msg)
end

local function get_hunter()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    if not pm then return nil end
    local p = pm:call("getMasterPlayer")
    return p and p:call("get_Character")
end

-- 读霸体状态；引擎不接受某个编号时永久停用，避免反复抛异常刷日志
local function probe_armor(st)
    if flag_state == false then return nil end
    local flags = st:get_field("_HunterStatusFlag")
    if not flags then return nil end
    local list = CONFIG.armor_flags
    local on = false
    for _, v in ipairs(list) do
        local ok, r = pcall(function() return flags:call("check(System.UInt32)", v) end)
        if not ok or r == nil then
            flag_state = false
            log_once("flag", "状态位探测失败，已停用（编号 " .. tostring(v) .. " 不被引擎接受）")
            return nil
        end
        if r then on = true end
    end
    flag_state = true
    return on
end

re.on_frame(function()
    if not CONFIG.enabled then return end

    local ok, err = pcall(function()
        local h = get_hunter()
        if not h then return end

        local st = h:call("get_HunterStatus")
        local health = st and st:get_field("_Health")
        if not health then return end
        local hm = health:call("get_HealthMgr")
        if not hm then return end

        local hp = hm:call("get_Health")
        local max_hp = hm:call("get_MaxHealth")
        local red = health:call("get_RedHealth")
        if type(hp) ~= "number" or type(red) ~= "number" or type(max_hp) ~= "number" then
            log_once("fields", "字段读取失败")
            return
        end

        local armor = probe_armor(st)
        if armor ~= nil then armor_now = armor end
        local allowed = (not CONFIG.armor_only) or armor_now

        if last and allowed and hp > 0.01 and hp < last.hp - 1e-4 then
            local d = last.hp - hp

            if CONFIG.mode == "red" then
                local target = math.min(max_hp, math.max(last.red or 0, last.hp))
                if target > red + 1e-4 then
                    health:set_field("_RedHealth", target)
                    local after = health:call("get_RedHealth")
                    if CONFIG.debug then
                        log.info(string.format(
                            "[guard_red] d=%.2f hp %.2f->%.2f red %.2f->%.2f (readback %.2f)",
                            d, last.hp, hp, red, target, after or -1))
                    end
                    red = after or target
                end
            elseif CONFIG.mode == "heal" then
                hm:call("addHealth", d)
            end
        end

        last = { hp = hp, red = red }
        ui.hp, ui.max, ui.red = hp, max_hp, red
    end)

    if not ok then
        log_once("frame", "frame error: " .. tostring(err))
    end
end)

re.on_draw_ui(function()
    if not imgui.tree_node("GuardRed") then return end

    local c1, v1 = imgui.checkbox("启用", CONFIG.enabled)
    if v1 ~= nil then CONFIG.enabled = v1 else CONFIG.enabled = c1 end
    local c2, v2 = imgui.checkbox("仅铁壁/相杀时生效", CONFIG.armor_only)
    if v2 ~= nil then CONFIG.armor_only = v2 else CONFIG.armor_only = c2 end
    local c3, v3 = imgui.checkbox("红血方案(关闭=补绿血)", CONFIG.mode == "red")
    if v3 ~= nil then CONFIG.mode = v3 and "red" or "heal" end
    local c4, v4 = imgui.checkbox("调试日志", CONFIG.debug)
    if v4 ~= nil then CONFIG.debug = v4 else CONFIG.debug = c4 end

    if ui.hp then
        imgui.text(string.format("HP %.1f / %.1f   红血上限 %.1f   可回 %.1f",
            ui.hp, ui.max, ui.red, math.max(0, ui.red - ui.hp)))
        imgui.text(string.format("铁壁: %s   状态位: %s",
            armor_now and "是" or "否",
            flag_state == false and "不可用" or tostring(flag_state)))
    else
        imgui.text("等待进入任务…")
    end
    imgui.tree_pop()
end)

log.info("[guard_red] loaded")
