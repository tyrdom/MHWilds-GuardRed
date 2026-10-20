# HANDOFF — 新会话先读这个

## 状态：已完工可用（2026-10-20）

《怪物猎人：荒野》mod：**霸体/相杀期间受到的伤害 100% 记为可回复红血**，不产生永久掉血。
已实测通过：普通挨打照常 50% 红血，霸体/相杀时挨打 100% 红血并慢慢回满。

- 游戏：Steam build `24705561`，`C:\Program Files (x86)\Steam\steamapps\common\MonsterHunterWilds`
- REFramework：nightly-01432（`dinput8.dll`，sha256 `27376e1d…5e94`）
- 正式脚本：`reframework/autorun/guard_red.lua`，已同步到游戏目录
- 游戏目录里可能还留着开发期探针 `reframework/autorun/zz_guardred_scan.lua`，
  确认不需要后跑 `tools/deploy.ps1 -CleanScan` 删掉（它会持续往日志写 HP/红血/状态位）

## 核心结论（完整版见 docs/NOTES.md）

1. 红血上限 `cHunterHealth._RedHealth` 是**绝对 HP 值**，满血时等于 MaxHP。
   受击后引擎算 `红血上限 = 新HP + 0.5×伤害`，所以只有一半可回。
2. 想要 100%：霸体/相杀时把 `_RedHealth` 写回 `max(受伤前上限, 受伤前HP)`。
   **必须直接写字段**；调用 `setRedHealth()` 会让下一次伤害变成 185（实测秒杀）。
3. 霸体判定用 `cHunterStatus._HunterStatusFlag:check(n)`：
   `7 = SUPER_ARMOR`（起手霸体，不用），`8 = HYPER_ARMOR`（铁壁，**只用这个**）。
   全解只挂 8，只用 7 会漏。
4. HP 在霸体期间照样会掉（红血只保证能回），一击打到 0 仍然猫车。

## 禁止事项（都踩过）

- 不要调用 `setRedHealth()`（副作用：下一击伤害暴涨）
- 不要在 `on_frame` 里装 `sdk.hook` 并打日志（闪退）
- 不要用 `check()` 遍历未知编号（抛异常 + 日志爆炸，35 分钟 1.6GB）
- 不要只还原到“受伤前 HP”（会把已有红血拉低）

## 目录

```
reframework/autorun/guard_red.lua   正式脚本（唯一需要装的文件）
tools/scan.lua                      开发期只读探针（状态位名字/HP/红血/动作 ID）
tools/deploy.ps1                    同步到游戏目录（-WithScan / -CleanScan）
tools/strings_scan.py               exe 字符串扫描（离线找 API 名）
tools/strings_scan2.py              同上，按类型/关键词分类
tools/strings_context.py            看字段名在 exe 里的上下文
docs/INGAME.md                      游戏内测试清单
docs/NOTES.md                       实测数据、接口清单、踩坑记录
build/                              离线扫描产物（git 忽略）
```

## 本机注意事项

- 这台机器**没有 `pwsh`**，只有 Windows PowerShell 5.1；`.ps1` 必须保持纯 ASCII
  （UTF-8 无 BOM 会被 5.1 解析错）
- 工作区外写入（游戏目录）需要授权
- 工作区的 `.git` 在 sandbox 下不可写，提交需要提权
- 游戏日志 `re2_framework_log.txt` 在游戏目录，REF 每次启动会重建
