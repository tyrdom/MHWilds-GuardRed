# MHWilds Guard-Red

把《怪物猎人：荒野》里**霸体 / 相杀状态下受到的伤害**变成可自然回复的红血（不产生永久掉血）。

> 状态：脚手架阶段。脚本逻辑已就位，但**红血字段名和霸体/相杀的状态标志还需要进游戏用探针确认**。

## 依赖

- REFramework（nightly，单体 `dinput8.dll`，放到游戏根目录）
- 游戏版本：Steam build `24705561`（2026-10 时点）

## 安装

1. 安装 REFramework：把 `dinput8.dll` 放到 `MonsterHunterWilds.exe` 同级目录。
2. 把本仓库的 `reframework` 文件夹整个复制到游戏根目录，覆盖合并。
3. 启动游戏，按 `Insert` 呼出 REFramework 菜单，确认 `GuardRed` 面板出现。

## 开发流程

1. 先跑探针 `tools/probe.lua`（手动 Run Script，或临时放进 `reframework/autorun/`）。
2. 在游戏里被打 / 相杀，观察 `re2_framework_log.txt` 里哪个 float 字段跟着掉血、哪个跟着涨红。
3. 把字段名填进 `reframework/autorun/guard_red.lua` 顶部的 `CONFIG`。
4. 把 `app.HunterDef.STATUS_FLAG` 里霸体/相杀对应的 flag 填进 `CONFIG.guard_flags`。
5. 重新加载脚本（ScriptRunner → Reset Scripts），实测。

## 目录结构

```
reframework/autorun/guard_red.lua   主逻辑（帧循环 + imgui 开关）
tools/probe.lua                      字段/枚举探针（不进 autorun）
docs/NOTES.md                        已知 API、待确认项
```

## 已知 API（来自社区开源项目，非官方）

```lua
local pm = sdk.get_managed_singleton("app.PlayerManager")
local player = pm:call("getMasterPlayer")      -- cPlayerManageInfo
local hunter = player:call("get_Character")    -- app.HunterCharacter

hunter:call("get_HunterStatus"):get_field("_HunterStatusFlag")  -- ace.cSafeContinueFlagGroup
-- flags:call("check(System.UInt32)", value) / on / off
-- 枚举：app.HunterDef.STATUS_FLAG

hunter:call("get_BaseActionController"):call("get_CurrentActionID")  -- _Category / _Index
-- 受击事件：evHit_DamagePreProcess（结算前）/ evHit_Damage（结算后）
```

## 免责

个人使用。修改运行时数值有崩溃风险，先备份存档。联机时只影响自己。
