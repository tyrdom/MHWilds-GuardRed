-- tools/scan.lua — 只读版 v7（无任何 hook，不会像上一版那样闪退）
-- 只做两件事：
--   1. 启动时把「红血相关」的参数字段 dump 出来（找一个能安全设置的红血比例）
--   2. 每 0.1s 记录 HP / 红血上限的变化

local PREFIX = "[scan]"

local function logf(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    log.info(PREFIX .. " " .. (ok and s or tostring(fmt)))
end

local function safe(fn, fallback, ...)
    local ok, res = pcall(fn, ...)
    if ok then return res end
    return fallback
end

local function is_obj(v) return type(v) == "userdata" end

-- ============================================================
-- 1. 红血相关参数 dump
-- ============================================================
local TYPES = {
    "app.cHunterSkill",
    "app.cHunterDefencePower",
    "app.cHunterItemBuff",
    "app.cHunterMealEffect",
    "app.cHunterStatus",
}

local FIELD_KEY = "[Rr]ed|[Hh]ealth|[Hh]eal"
local METHOD_KEY = "[Rr]ed|[Hh]ealth|[Hh]eal"

for _, name in ipairs(TYPES) do
    safe(function()
        local td = sdk.find_type_definition(name)
        if not td then
            logf("TYPE MISS %s", name)
            return
        end
        logf("==== %s ====", name)
        local fields = safe(function() return td:get_fields() end, nil)
        if fields then
            for _, f in ipairs(fields) do
                local n = safe(function() return f:get_name() end, "")
                if n:find(FIELD_KEY) then
                    logf("  F %-40s %s", n, safe(function() return f:get_type():get_full_name() end, "?"))
                end
            end
        end
        local methods = safe(function() return td:get_methods() end, nil)
        if methods then
            for _, m in ipairs(methods) do
                local n = safe(function() return m:get_name() end, "")
                if n:find(METHOD_KEY) then
                    logf("  M %s -> %s", n,
                        safe(function() return m:get_return_type():get_full_name() end, "?"))
                end
            end
        end
    end)
end

-- ============================================================
-- 2. 数值快照
-- ============================================================
local hunter, status, health, hm
local resolved = false

local function get_hunter()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    if not pm then return nil end
    local p = safe(function() return pm:call("getMasterPlayer") end, nil)
    if not p then return nil end
    return safe(function() return p:call("get_Character") end, nil)
end

local function resolve_all()
    if resolved then return true end
    hunter = get_hunter()
    if not hunter then return false end
    status = safe(function() return hunter:call("get_HunterStatus") end, nil)
    health = status and safe(function() return status:get_field("_Health") end, nil)
    hm = health and safe(function() return health:call("get_HealthMgr") end, nil)
    resolved = (health ~= nil and hm ~= nil)
    if resolved then logf("RESOLVED") end
    return resolved
end

local last = {}
local next_tick = 0
local last_action = nil

-- ============================================================
-- 状态位「按名字」记录：把当前所有 true 的 STATUS_FLAG 打出来
-- ============================================================
local flag_names = {}
do
    local ok = pcall(function()
        local td = sdk.find_type_definition("app.HunterDef.STATUS_FLAG")
        if not td then return end
        for _, f in ipairs(td:get_fields()) do
            local n = f:get_name()
            if n ~= "value__" then flag_names[#flag_names + 1] = n end
        end
    end)
    logf("FLAGNAMES %d %s", #flag_names, tostring(ok))
end

local probe_limit = #flag_names
local last_active = {}

local function scan_flags_named()
    local flags = status and safe(function() return status:get_field("_HunterStatusFlag") end, nil)
    if not is_obj(flags) then return end
    local active = {}
    if probe_limit < 1 then return end
    for i = 0, probe_limit - 1 do
        local r = safe(function() return flags:call("check(System.UInt32)", i) end, nil)
        if r == nil then
            probe_limit = i
            logf("FLAGPROBE stop at %d (engine rejected), limit now %d", i, probe_limit)
            logf("FLAGS t=%.1f +[%s]", os.clock(), table.concat({}, ","))
            return
        end
        if r then active[flag_names[i + 1]] = true end
    end
    local added, removed = {}, {}
    for n in pairs(active) do
        if not last_active[n] then added[#added + 1] = n end
    end
    for n in pairs(last_active) do
        if not active[n] then removed[#removed + 1] = n end
    end
    if #added > 0 or #removed > 0 then
        table.sort(added)
        table.sort(removed)
        logf("FLAGS t=%.1f +[%s] -[%s]", os.clock(), table.concat(added, ","), table.concat(removed, ","))
        last_active = active
    end
end

local function read_action()
    safe(function()
        local bac = hunter and hunter:call("get_BaseActionController")
        if not bac then return end
        local aid = bac:call("get_CurrentActionID")
        if not is_obj(aid) then return end
        local cat = aid:get_field("_Category")
        local idx = aid:get_field("_Index")
        local key = tostring(cat) .. "/" .. tostring(idx)
        if key ~= last_action then
            last_action = key
            logf("ACTION t=%.1f category=%s index=%s", os.clock(), tostring(cat), tostring(idx))
        end
    end)
end

re.on_frame(function()
    safe(resolve_all)
    local now = os.clock()
    if now < next_tick then return end
    next_tick = now + 0.1
    if not resolved then return end

    safe(read_action)
    safe(scan_flags_named)

    safe(function()
        local hp = hm:call("get_Health")
        local max_hp = hm:call("get_MaxHealth")
        local red = health:call("get_RedHealth")
        local req_red = health:get_field("_RequestedTotalRedHealth")
        local req_reddmg = health:get_field("_RequestedTotalRedDamage")
        local t = { hp = hp, max = max_hp, red = red, req_red = req_red, req_reddmg = req_reddmg }
        local changed = {}
        for k, v in pairs(t) do
            if v ~= nil and last[k] ~= nil and v ~= last[k] then
                changed[#changed + 1] = string.format("%s %s->%s", k, tostring(last[k]), tostring(v))
            end
            last[k] = v
        end
        if #changed > 0 then
            logf("VITALS t=%.1f %s", now, table.concat(changed, " | "))
        end
    end)
end)

re.on_draw_ui(function()
    if not imgui.tree_node("GuardRed Scan") then return end
    imgui.text(string.format("HP %s/%s  RED %s", tostring(last.hp), tostring(last.max), tostring(last.red)))
    imgui.tree_pop()
end)

logf("loaded v7 (no hooks)")
