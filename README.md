# MHWilds Guard-Red

把《怪物猎人：荒野》里**霸体 / 相杀状态下受到的伤害变成 100% 可回复红血**——不产生永久掉血，
红血按游戏原本的节奏（每 1.5 秒 +1 HP）慢慢补回绿血。

> 状态：**已实测可用**（2026-10-20，Steam build 24705561 + REFramework nightly-01432）。

## 效果

| 场景 | 原版 | 装了这个 mod |
|---|---|---|
| 普通挨打（掉 21 点） | HP 掉 21，红血上限只补 10.5，永久损失约 10.5 | 不变（只在你霸体/相杀时生效） |
| **霸体/相杀时挨打** | 同上，仍会永久掉血 | HP 掉 21，**红血上限不降**，可回 21，随后慢慢回满 |

它不是无敌：HP 照样会掉，只是掉下去的都能回；爆发伤害仍然可能打死你。

## 依赖

- REFramework（nightly，单文件 `dinput8.dll`）
- 游戏版本：Steam build `24705561`（2026-10 时点）

## 安装

1. 把 REFramework 的 `dinput8.dll` 放到 `MonsterHunterWilds.exe` 同级目录。
2. 把本仓库的 `reframework` 文件夹整个复制到游戏根目录（覆盖合并）。
3. 启动游戏，按 `Insert` 呼出菜单，在 `Script Generated UI` → `GuardRed` 里能看到面板。

`reframework/autorun/guard_red.lua` 是唯一需要的文件；`tools/` 里的东西都是开发用的，不装也能用。

## 面板

- **启用**：总开关
- **仅霸体/相杀时生效**：默认开。关掉就是所有伤害都 100% 红
- **红血方案（关闭=补绿血）**：默认开。关掉会退化成“受伤后直接把 HP 补回来”（等于该状态下无敌，只在红血方案出问题时当备选）
- 调试日志：打开后每次写值都会往 `re2_framework_log.txt` 打一行

## 原理（一句话版）

游戏里红血上限 `_RedHealth` 是个**绝对 HP 值**：受击后 `红血上限 = 新HP + 0.5×伤害`，所以只有一半能回。
mod 在 `HYPER_ARMOR`（铁壁，8 号）状态位开启时，把 `_RedHealth` 直接写回 `max(受伤前红血上限, 受伤前HP)`，
这一击就变成 100% 可回。

细节和踩过的坑（**不能调 `setRedHealth()` 方法**，否则下一击会被算成 185 伤害）见 `docs/NOTES.md`。

## 目录

```
reframework/autorun/guard_red.lua   正式脚本（唯一需要装的文件）
tools/scan.lua                      开发期只读探针（记录状态位/HP/红血/动作 ID）
tools/deploy.ps1                    同步脚本到游戏目录（-WithScan 附带探针，-CleanScan 删除）
tools/strings_scan.py               扫游戏 exe 字符串，找 API 名字（离线）
tools/strings_scan2.py              同上，按类型名/关键词分类
tools/strings_context.py            看某个字段名在 exe 里的上下文
docs/INGAME.md                      游戏内测试清单
docs/NOTES.md                       设计笔记 + 完整实测结论
HANDOFF.md                          交接说明（新会话先读）
```

## 开发

```powershell
# 只同步正式脚本
powershell -File tools\deploy.ps1

# 同步正式脚本 + 探针（探针会往日志里写东西，测完记得删）
powershell -File tools\deploy.ps1 -WithScan

# 删掉探针
powershell -File tools\deploy.ps1 -CleanScan
```

改完脚本后，游戏内 `ScriptRunner → Reset Scripts` 重载。

## 已知限制

- `HYPER_ARMOR` 不是“相杀成功”的专属标记，只是铁壁级霸体；真正的相杀判定在伤害结算里，状态位看不到
- 反应等级（弱/中/强攻击）仍然照常生效：强攻击照样能把你打飞，只是伤害转成了红血
- 一击把 HP 打到 0 仍然会猫车（红血只影响“可回上限”，不防死）

## 免责

个人使用。修改运行时数值有风险，先备份存档：
`C:\Program Files (x86)\Steam\userdata\<你的ID>\2246340\remote\`

## 许可

[MIT](LICENSE)。随意使用、修改、再分发，保留版权声明即可。

