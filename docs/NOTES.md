# 开发笔记

## 目标

霸体 / 相杀状态期间受到的伤害（减伤结算之后）**100% 记为可回复量**，
不产生永久掉血；红血自然回复把绿血补回来。

## 血量模型（待实测确认）

```
满血      [███ 绿 HP=MAX ]  红 RED=0
受击      HP 下降 D，RED 上升约 D/2，差额 = 永久损失
回复      HP↑ RED↓，HP+RED 不变，直到 RED=0
```

- `HP` = 绿条，归零猫车
- `RED` = 红色部分（可回复量），上限约 `MAX - HP`
- 写 RED 不影响 HP，是独立字段

## 两种实现

### A. 锁红（简单，先做）

每帧：`RED = max(RED, 上一帧 RED)`，仅在状态期间。
效果：红池只增不减 → 自然回复不再消耗红 → 持续回血。
风险：红条可能卡在满血不清、脱离状态后有残留红。

### B. 伤害转红（精确）

检测 HP 本帧下降量 Δ，`RED = min(MAX - HP, RED + Δ)`。
需要准确的字段和时序，必要时改 hook `evHit_DamagePreProcess`。

## 待确认

- [ ] HP / MaxHP / 红血字段名（探针自动发现）
- [ ] `app.HunterDef.STATUS_FLAG` 里霸体、相杀对应的值
- [ ] 红血是否有上限、上限是不是 `MAX - HP`
- [ ] 相杀成功 / 霸体是否需要区分（大概率不需要，同一套处理）
- [ ] 一击致死如何兜底（状态期间 HP 下限钳 1，或 hook 结算前）

## 已知 API

见 README。补充：

- 动作属性：`app.HunterDef.ACTION_ATTR`（DAMAGE / DAMAGE_DOWN / DODGE ...）
- `hunter:call("isActionAttrCurrentAction(app.HunterDef.ACTION_ATTR)", value)`
- 单帧内读多个值时先取一次 `hunter`，避免对象在帧中途失效

## 参考

- REFramework 文档：https://cursey.github.io/reframework-book/
- 夜间构建：https://github.com/praydog/REFramework-nightly/releases
- 社区 API 用法参考：GGGLHHH/mhwilds-mods（GPL-3.0，仅参考接口，未复制代码）
