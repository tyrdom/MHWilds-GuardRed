# 开发笔记

## 目标

霸体 / 相杀状态期间受到的伤害 100% 记为可回复红血，不产生永久掉血；
红血按游戏原本节奏回满绿血。**已实现并实测通过**（2026-10-20）。

## 实测数据（训练所木人，Steam build 24705561）

### 血量模型

```
普通受击 D=21.51：
  HP        150.00 -> 128.49
  红血上限   150.00 -> 139.25     = 新HP + 0.5 × D
再受击 D=21.51（HP 已回到 136.58）：
  HP        136.58 -> 117.17
  红血上限   139.25 -> 128.49     = 新HP + 0.5 × D   ← 旧的残留被覆盖，不是累加
恢复：
  每 1.5 秒 HP +1，红血上限不变；HP 涨到上限就停
```

- 红血上限 `_RedHealth` 是**绝对 HP 值**，不是“红血条长度”
- 满血时 `_RedHealth == MaxHP`（不是 0），所以面板里“可回 = 上限 − HP”
- 中毒只扣 HP、不动上限 ⇒ **HP < 红血上限是引擎允许的状态**，这一点是方案成立的前提

### 状态位（`app.HunterDef.STATUS_FLAG`，编号 = 枚举顺序，从 0 开始）

```
 2 GUARD                 16 NO_DAMAGE_REACTION
 6 GUARD_POINT           18 NO_SMALL_DAMAGE_REACTION
 7 SUPER_ARMOR           85 WP_05_SUPER_ARMOR
 8 HYPER_ARMOR
```

实测到的组合：

| 动作 | 状态位 |
|---|---|
| 蓄力（空挥） | `SUPER_ARMOR` |
| 反击上捞斩 起手（空挥） | `SUPER_ARMOR` |
| 反击上捞斩 命中/相杀 | `SUPER_ARMOR` + `HYPER_ARMOR`（+ 一闪而过的 `NO_DAMAGE`） |
| 肩撞 | `SUPER_ARMOR` + `HYPER_ARMOR` |
| 全解 | **只有** `HYPER_ARMOR` |

⇒ 最终只用 8（`HYPER_ARMOR`）当门槛：相杀命中、肩撞、全解都覆盖；
蓄力那种只有 `SUPER_ARMOR` 的起手霸体不算。想放宽就改成 `{7, 8}`。

`HYPER_ARMOR` 不等于“相杀成功”，它只是铁壁级霸体；相杀判定在 `cHunterDamageInfo`
的结算里（`_GuardReaction` / `_IsCounterable` 等），状态位层面看不到。

## 实现

```lua
-- 霸体/相杀时，本帧掉血 D：
target = min(MaxHP, max(上一帧红血上限, 上一帧HP))
if target > 当前红血上限 then
    health:set_field("_RedHealth", target)   -- 必须是字段，不能调方法
end
```

### 踩过的坑（重要）

1. **不能调用 `setRedHealth(v)` 方法**：写完之后引擎会把差额算进下一次伤害，
   实测同一招从 21 点变成 **185 点**，直接秒杀。直接写 `_RedHealth` 字段没有这个问题。
2. **不能只还原到“受伤前的 HP”**：如果身上本来就有红血（上限高于 HP），
   会被拉低。要用 `max(上一帧上限, 上一帧HP)`。
3. **不要在 `on_frame` 回调里 `sdk.hook` + 打日志**：实测直接闪退（栈在
   `ace.minicomponent.update` 一带）。所有 hook 方案已放弃。
4. **不要用 `check()` 遍历未知编号**：非法值会抛 C++ 异常，REF 每次打一整段堆栈，
   35 分钟日志涨到 1.6GB。只探测已知编号，失败就永久停用。
5. `set_field("_RedHealth", v)` 写入后 `get_RedHealth()` 能立刻读回，说明写入生效。

## 接口清单（`app.cHunterHealth`）

```
F _RedHealth                     Single     红血上限（绝对 HP 值）
F _RequestedTotalDamage          Single     本帧排队要扣的血
F _RequestedTotalRedHealth       Single     本帧排队要加的红血
F _RequestedTotalRedDamage       Single     本帧排队要扣的红血
F _RequestResetRedHealth         Boolean
F _DisableUpdateRedHealth        Boolean
M get_RedHealth() / setRedHealth(Single)    ← setRedHealth 有副作用，别用
M requestDamage(HunterCharacter, Single, Single, Boolean×6)
M requestRedDamage(Single)
M requestHeal(Single, Boolean)
M setHealth(Single, Boolean)
M setHP1WithRedHealthFull()
M update(Single, Boolean)                    ← 每帧结算
```

`app.cHealthManager`：`get_Health()` / `get_MaxHealth()` / `addHealth(Single)` / `set_Health(Single)`。

我们的 `on_frame` 回调在引擎已经扣完红血之后才跑（写值时 `_RequestedTotalRedDamage`
已经是 0），所以是“事后补写”，不是“提前拦截”。

## 还有哪些红血相关的东西（没走通/没用到）

- `getSkillRedHealthRate` / `getSkillRedHealthAdd` / `getSkillRedHealthSpeedRate`：
  技能参数，`app.cHunterSkill` 里没有任何红血字段（dump 为空），拿不到可设置的倍率
- `STATUS_FLAG.DISABLE_RED_HEALTH`(12)、`RED_HEAL_SPPED_UP`(51)：状态位，不是倍率
- `OverwriteHyperArmorDamageReduceRate` / `ParryDamageReduceRate`：减伤率，不是红血比例

## 后续可做

- [ ] 一击致死兜底：霸体期间把 HP 钳在 1（`_RequestedTotalDamageNoDie` 可能是引擎自带机制）
- [ ] 反应等级联动：被“强（无法格挡）”打飞时是否还要转红
- [ ] 通用化：`armor_flags` 可按武器扩展（如 85 `WP_05_SUPER_ARMOR`）

## 参考

- REFramework 文档：https://cursey.github.io/reframework-book/
- 夜间构建：https://github.com/praydog/REFramework-nightly/releases
