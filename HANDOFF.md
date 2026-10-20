# HANDOFF — 新会话先读这个

## 目标

《怪物猎人：荒野》mod：**霸体 / 相杀状态期间受到的伤害（减伤之后）100% 记为可回复红血**，
不产生永久掉血，靠自然回复把绿血补回来。效果上等于「一直霸体相杀，血永远是红的、会自己回满」。

## 当前状态

- 游戏已装好并运行过：Steam build `24705561`
- REFramework nightly-01432 已安装：`dinput8.dll` 在游戏根目录，sha256 `27376e1da177ddcde9c46b3541bdc6fa1ad54a11d0cab9f7782eff0481455e94`
- 本仓库是 mod 源码；`reframework/autorun/guard_red.lua` 已同步到游戏目录
- 脚本目前是「空转」：`CONFIG.guard_flags` 为空，只打一行日志，不改任何数值
- **还没做的**：确认 HP / MaxHP / 红血字段名，确认霸体/相杀对应的 STATUS_FLAG

## 目录

```
reframework/autorun/guard_red.lua   主逻辑（帧循环 + imgui 开关 + 两种模式）
tools/probe.lua                      探针：导出字段/枚举，并打印变化的 float 字段
tools/deploy.ps1                     一键把脚本同步到游戏目录
docs/NOTES.md                        设计笔记、待确认清单
```

## 下一步（按顺序）

1. 让用户启动游戏，`Insert` 确认 REF 菜单有 `GuardRed`。
2. ScriptRunner → Run Script → `tools/probe.lua`，打怪、吃伤害、做相杀/霸体。
3. 读游戏目录的 `re2_framework_log.txt`：
   - 找 `app.HunterDef.STATUS_FLAG` 里霸体/相杀的值
   - 找 `[watch]` 里掉血时下降、红血时上升的 float 字段名
4. 填进 `guard_red.lua` 顶部 `CONFIG`（`hp` / `max_hp` / `red` / `guard_flags`）。
5. `pwsh -File tools/deploy.ps1` 同步，游戏里 `ScriptRunner → Reset Scripts` 重载，实测。

## 已知 API（社区逆向，非官方）

```lua
local pm = sdk.get_managed_singleton("app.PlayerManager")
local player = pm:call("getMasterPlayer")      -- cPlayerManageInfo
local hunter = player:call("get_Character")    -- app.HunterCharacter

local flags = hunter:call("get_HunterStatus"):get_field("_HunterStatusFlag")
-- flags:call("check(System.UInt32)", v) / on / off；枚举 app.HunterDef.STATUS_FLAG

hunter:call("get_BaseActionController"):call("get_CurrentActionID")  -- _Category / _Index
-- 受击事件名：evHit_DamagePreProcess（结算前）/ evHit_Damage（结算后）
```

## 两种实现模式（脚本已内置）

- `mode = "lock"`：红池只增不减 → 自然回复不消耗红 → 持续回血。简单，但可能红条卡住、脱离状态有残留（已加 `clamp_on_exit` 收尾）。
- `mode = "add"`：检测本帧 HP 下降量 Δ，`RED = min(MAX - HP, RED + Δ)`。更接近「伤害转红」，需要字段和时机都准确。

## 本机注意事项

- `github.com` 直连 TLS 握手失败，下载走 `https://gh-proxy.com/<原始 GitHub 链接>`；Clash 代理 `127.0.0.1:7897`
- 游戏目录在 `C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds`，**在工作区外**，写入需要授权
- 崩溃日志：游戏目录 `re2_framework_log.txt`、`reframework_crash.dmp`
- 改数值有坏档风险，动之前先备份 `steamapps/../userdata/<id>/2246340/remote`
- 脚本报错会崩游戏：所有回调都用 `pcall` 包着，别去掉
