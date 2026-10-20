-- tools/probe.lua
-- 用途：进游戏后跑一次，把候选字段和状态枚举打到日志里。
-- 用法：REFramework 菜单 -> ScriptRunner -> Run Script -> 选这个文件。
-- 日志：游戏目录 re2_framework_log.txt，或 ScriptRunner 的控制台区域。

local DUMP_TYPES = {
    "app.HunterCharacter",
    "app.HunterDef.STATUS_FLAG",
    "app.HunterDef.ACTION_ATTR",
}

local WATCH_FLOATS = true      -- 每 0.25s 打印一次变化的 float 字段
local INTERVAL = 0.25

local function dump_type(name)
    local td = sdk.find_type_definition(name)
    if not td then
        log.info("[probe] 找不到类型: " .. name)
        return
    end
    log.info("======== " .. name .. " fields ========")
    for _, f in ipairs(td:get_fields()) do
        local ok, val = pcall(function() return f:get_data(nil) end)
        log.info(string.format("  %-40s %-28s %s",
            f:get_name(), f:get_type():get_name(), ok and tostring(val) or "?"))
    end
    log.info("======== " .. name .. " methods ========")
    for _, m in ipairs(td:get_methods()) do
        log.info("  " .. m:get_name())
    end
end

for _, t in ipairs(DUMP_TYPES) do
    pcall(dump_type, t)
end

local function get_hunter()
    local pm = sdk.get_managed_singleton("app.PlayerManager")
    local p = pm and pm:call("getMasterPlayer")
    return p and p:call("get_Character")
end

local last = {}
local next_t = 0

re.on_frame(function()
    if not WATCH_FLOATS then return end
    local now = os.clock()
    if now < next_t then return end
    next_t = now + INTERVAL

    local h = get_hunter()
    if not h then return end

    local ok, err = pcall(function()
        for _, f in ipairs(h:get_type_definition():get_fields()) do
            local tn = f:get_type():get_name()
            if tn == "System.Single" or tn == "System.Int32" then
                local name = f:get_name()
                local v = h:get_field(name)
                if v ~= nil and last[name] ~= v then
                    log.info(string.format("[watch] %-36s %s -> %s", name, tostring(last[name]), tostring(v)))
                    last[name] = v
                end
            end
        end
    end)
    if not ok then log.info("[probe] watch error: " .. tostring(err)) end
end)

log.info("[probe] loaded")
