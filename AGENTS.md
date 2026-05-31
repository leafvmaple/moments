# AGENTS.md — moments 游记生成指南

> 给未来的 AI agent（或者过几个月已经忘了上下文的我自己）。
> 当用户丢一组旅行照片说「帮我写成一篇游记」时，按这个流程走。

## 触发条件

用户给了**带 EXIF 的一组旅行照片**（zip / 文件夹 / 散图），并要求写成 moments 博客的图文游记。
如果只是一两张照片配一句话，那是「短动态」，不走这个流程。

---

## 流程

### 1. 解包 & 落到工作目录

- 源 zip / 散图统一解压到 `photos/<场景名>/extracted/`，保留原文件名。
- 不要直接处理原图；后续所有处理都基于「从 extracted 复制一份到 public」的方式，
  保证 extracted 始终是干净的回滚源。

### 2. 提取元信息（EXIF）

每张图必须读到：
- **拍摄时间**（精确到秒）—— 决定章节顺序、文件名、行程节奏推断。
- **GPS 坐标** —— 反查地点，判断「这是嵐山的桂川还是天龙寺」这种细节。
- 视觉内容 —— 用图像识别看清楚招牌字、人物、天气、季节、镜头主体。

PowerShell 上读 EXIF 用 `magick identify -format '%[EXIF:*]' file.jpg` 最快，
或者 .NET 的 `System.Drawing.Image.PropertyItems`。

### 3. 还原行程

按时间排序所有照片，生成一张「时间 → 地点 → 内容 → 天气/光线」的表，先和用户对一遍，
**让他补充 AI 看不出来的事**（同行者、心情、为什么去、和谁吃了什么）。
没有这一步，写出来的就是「百度百科 + 看图说话」。

### 4. 文风对话（**必须先给候选**）

不要直接动笔。先给用户 **3–5 种文风样段**，每段用同一张照片同一段事实，让用户挑。
样段必须**短**（80–120 字），让用户能快速 A/B。常用维度：

- 散文白描：句子短，颜色词克制（灰、银、青绿），不下判断。
- 生活随笔：白描 + 当下感想 + 一两句普世思考（仪式感、过年方式、和谁同行的对比……）。
- 古典游记：参考柳宗元/苏轼游记的句式骨架，但避免文言强凑。
- 诗性意象：少叙事，重意象和留白，每段几乎独立。
- 冷峻纪实：只写看到的、做的，不写感想，让画面自己说话。

用户选定后再问字数倾向（300 / 800 / 1500+），再下笔。

### 5. 写正文（融合用户选定的风格）

结构默认按时间推进，**首尾呼应**（用同一个意象在开头和结尾各出现一次 ——
车站招牌、月台椅子、第一眼的灰云等）。每段叙事配 1 张图。

**硬约定**（违反会被退回重写）：

- ❌ **章节标题不要带时间戳**（不要写「## 12:08 走向渡月橋」）。「显得刻意」。
- ❌ **图片文件名不要用序号**（不要 `01-station.jpg`、`02-bridge.jpg`）。
  用 EXIF 时间戳 `YYYYMMDD_HHMMSS.jpg`（例：`20200129_145240.jpg`），将来用户新增照片塞进任意位置都不用改其他文件名。带年份是为了跨多日行程或长期博客积累时仍能在同一目录区分。
- ❌ **正文不要用 H1**（`#`）。Astro 主题把 frontmatter 的 `title` 自动渲染为页面
  H1；正文里再写 H1 会触发 lint + 影响 SEO + 视觉错乱。多段游记用「H2 大块 + H3 章节」
  结构（例：`## 上午 · 嵐山` 下面是 `### 阪急嵐山駅`、`### 中ノ島橋`……）。
- ⚠️ **写作视角一致性**：frontmatter 的 `date` 设了是 "X 时间写的"，正文就不能流露
  那个时间点不该知道的信息。"翻日历才想明白...正月初五"是 OK 的（小范围回顾）；
  "现在回头看，这张照片其实是一道分水岭" 不行 —— 立刻漏出作者其实是几年后写的。
- 💡 **「场景 + 证据」的图文节奏**：当一段叙事有强 punchline（"冬季停运" / "弃猫犯罪
  最高罚 100 万円"），先用一张「场景图」铺氛围，再用一张「证据图」给具体物证 ——
  节奏比单图饱满，读者也更容易被立意击中。例：嵐山铁道段 = 133025（铁道延伸的空）
  ＋ 133116（信号灯熄了）。

### 6. 落文件

```
src/content/posts/<slug>.md           ← Markdown 正文
public/images/<slug>/YYYYMMDD_HHMMSS.jpg  ← 处理后的图，按 EXIF 时间戳命名
photos/<slug>/extracted/IMG_xxx.jpg   ← 原图（不进 git？看用户偏好）
```

frontmatter 字段：

```yaml
---
title: <标题>
date: YYYY-MM-DD          # 用 EXIF 日期，不是写作日期
trip: <trip-slug>         # 可选；归属的行程 slug，详见「行程 (Trip) 体系」
tags: [旅行, <城市>, <国家>]
excerpt: <80-120字钩子，能独立成段>
cover: /images/<slug>/<YYYYMMDD_HHMMSS>.jpg
---
```

### 7. 压缩（**必跑**）

照片原图通常 3–5MB，直接进 git/部署会拖慢加载。跑：

```powershell
./scripts/compress-photos.ps1 -Path public/images/<slug>
```

只做一件事：用 ImageMagick 以 `-quality 88` 重编码每张 JPEG，体积通常砍到 50–70%，
肉眼基本看不出差别。**不做色彩 / 饱和度调整** —— 滤镜由用户在外部工具（Snapseed、
Lightroom 等）里自己处理后，把成品放到 `photos/<slug>/`，脚本只负责出包压缩。

参数细节看 `scripts/compress-photos.ps1` 文件头。

> 历史脚本 `scripts/normalize-photos.ps1` 还在仓库里 —— 它会做自适应 saturation/contrast
> normalize，但默认管线不再用它（用户偏好自己掌控滤镜）。如果某次需要让一组"有的修过、
> 有的没修"的混源照片统一色调，可以临时用它。

### 7.5 天空选择性调整（按需）

`compress-photos.ps1` 不动色彩，所以会原样保留两类问题：

- 相机原片把云天压平 → 天空发灰
- 用户外部滤镜应用得过头 → 天空过蓝

不一刀切 normalize 整组，是为了保留每张的原始意图。但同一组里如果天空饱和度落差太大，
整篇读起来会"跳"。这一步是把异常值往中间拉，**整体差异保留**。

**审计**：测每张图顶部 1/3 的 HSL 饱和度（即"天空区域"代理指标）：

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$dir = "public/images/<slug>"
$rows = @()
foreach ($f in Get-ChildItem $dir -Filter "*.jpg") {
    $skyS = [math]::Round([double](magick "$($f.FullName)" -gravity North -crop "100%x33%+0+0" +repage -colorspace HSL -format "%[fx:mean.g*100]" info:), 1)
    $rows += [PSCustomObject]@{ File = $f.Name; SkyS = $skyS }
}
$rows | Sort-Object SkyS -Descending | Format-Table -AutoSize
```

**SkyS 判读经验值**（顶部 1/3 平均饱和度，0-100）：

| 区间 | 判读 | 处理 |
|------|------|------|
| 70+ | 通常过蓝 | 拉 0.85 一次；如 >75 再叠 0.9 一次直到 ~67 |
| 60–67 | 自然清天蓝带（**目标区间**） | 不动 |
| 40–60 | 阴天 / 部分天 / 多云 | 不动 |
| <40 | 看场景 | 站台屋顶 / 林荫 / 隧道 / 夕阳云压顶是结构性低，**不动**；明显有大片天但 SkyS<40 多半是相机压平，可拉 1.15–1.2 一次 |

> **没有"用户滤镜白名单"**：哪怕文件名带 `-EDIT`（用户外部 P 过）也照样按 SkyS 处理。
> 用户的滤镜意图通过**绝对值**保留 —— 比如他 P 到 SkyS=87，按规则拉 0.85 仍是 74，
> 仍比自然蓝组（60-67）高一截，他的"重彩"意图自动落在最高档。不要根据文件名做特殊豁免。

**拉下来**（过蓝）：

```powershell
magick "$path" -modulate 100,85,100 -quality 88 "$path"   # 温和一档
magick "$path" -modulate 100,90,100 -quality 88 "$path"   # 顽固高值再叠
```

**拉上去**（过淡）：

```powershell
magick "$path" -modulate 100,115,100 -quality 88 "$path"  # 谨慎
magick "$path" -modulate 100,120,100 -quality 88 "$path"  # 1.2x 已是上限
```

**注意**：`-modulate` 是全图饱和度，不只动天 —— 拉上去时，本殿红 / 千本鸟居橙 / 鲜艳和服
这种已饱和的颜色会被推过头。所以上调比下调更克制；超过 1.2x 之前一定先看图。

**做完再测一次**，确认整组 SkyS 分布是一条平顺的下降曲线 —— 中间不要有 20+ 的断层。
最高那张可能依然偏高（如果用户原图就极饱和，拉一两次后仍在 70+ 区间），这是规则正确执行
的结果，不要再额外往下拉去强行追求一致。

> 这一节是**按需**：如果用户对 compress 后的整组观感就已经满意，跳过即可。但如果做了，
> 一定要在 commit message 里写明 "selective sky touch-up" + 调了哪几张，未来回查能复现。

### 7.6 行动轨迹地图（按需）

如果想给这篇游记加一张「实际拍摄位置」的地图（顶部 cover 下、正文之上），
在压缩 + 天空调整都做完之后跑：

```powershell
node scripts/extract-photo-meta.mjs <slug> public/images/<image-dir>
```

`<slug>` 是文章 markdown 文件名（无 `.md`），`<image-dir>` 是图所在的子目录名 ——
两者**不一定相等**（如 `kyoto-winter.md` 配 `public/images/kyoto/`）。脚本读每张
JPEG 的 EXIF GPS + 文件名时间戳，输出 `src/data/photo-meta/<slug>.json`。
`src/pages/posts/[...slug].astro` 已挂 `<TrailMap slug={post.id} />`，有对应 json
就自动渲染，没有就空 —— **新增博文不需要改任何代码**，只要跑一次脚本。

**GPS 三级 fallback**（脚本自动按顺序尝试）：

1. **public 文件自己的 EXIF GPS** —— 多数情况走这条
2. **`photos/extracted/` 里同 HHMMSS 的原始 IMG_** —— 救那些被 Snapseed / 相册软件
   重新保存后 EXIF 被剥掉的（如本地 P 过的 `-EDIT` 版本）
3. **同组最近时间邻居（±60 min）** —— 救完全没 GPS 来源的文件（如 Snapseed 导出），
   借走时间最近的那张的 GPS。对旅行场景一般 1 小时内人不会离开本地段太远

跑完会在 console 标出"GPS from extracted/..." 或 "GPS from borrowed:... (±N min)"，
**借用窗口 >10min 的要扫一眼**确认 borrowed 那张确实在同一片区域（同神社、同街区）。
如果借错了（比如下午在另一区拍），可以手动把那一条从 JSON 里删掉，map 上不显示即可。

**手动覆盖**：如果想给某张图标一个更准的坐标（看图能认出地标），直接编辑
`src/data/photo-meta/<slug>.json` 那一条，把 lat/lng 改对，并加 `"manual": true`：

```json
{
  "file": "20200128_151820.jpg",
  ...
  "lat": 34.67,
  "lng": 135.5012,
  "gpsSource": "manual: UNIQLO 心斎橋店附近",
  "manual": true
}
```

带 `manual: true` 的条目在下次跑脚本时会被原样保留，不会被 EXIF/extracted/borrowed
任何一档覆盖。审计块里会单独列出 "manual (preserved): N"。

**TODO 自动同步**：每次跑脚本都会刷新 `TODO.md` 里 `<!-- GPS_TODO:START -->` 到
`<!-- GPS_TODO:END -->` 之间这段，列出当前 slug 所有走了 `borrowed:` fallback 的图
（manual / extracted / self 的不进 TODO）。其他 slug 的条目和已勾选 `[x]` 的状态都被
保留。解决方式：

- 看图能定位 → 改 JSON `lat/lng` + 加 `"manual": true` → 下次跑自动消失
- 借用坐标可接受 → 在 TODO 里把 `[ ]` 改成 `[x]` → 下次跑保留 `[x]`

- 完全没 GPS 数据的 slug 不需要跑脚本；JSON 不存在地图就不显示
- 多张同坐标的照片会自动合并成一个 marker，弹窗里横向排照片缩略图

### 8. 发布

`.gitignore` 已把 `photos/` 整体忽略 —— 原图 + zip 留本地作备份，仓库只放
`public/images/<slug>/` 的处理后版本。

**Commit 拆分**（按已确立的 conventional commits 风格）：一次新游记上线大概对应：

```text
chore: ...                                  # gitignore / 删旧文件
feat(scripts): ...                          # 如果有新脚本
docs: ...                                   # AGENTS.md 更新
feat(posts): <slug>                         # 博文 + public/images/<slug>/ 一起
feat(album): ...                            # album.json 加新精选
style(...): ...                             # 偶尔的样式微调
```

每个 commit 是一个**独立的逻辑单元** —— 不要一个大 commit 塞所有变化。

**部署**：`push origin main` 触发 `.github/workflows/deploy.yml`，自动 build +
deploy 到 gh-pages 分支，~30s–1min 完成（图多时更久）。不用手动跑 `npm run build`
或手动推 gh-pages。

```bash
# 看 deploy 状态
gh run list --limit 3 --workflow=deploy.yml
```

---

## Album 策略

`src/data/album.json` 驱动 `/album` 页面（masonry 三列瀑布）。当用户**没有**独立的
"博文外摄影流"时（多数情况），album 应该承担"博客视觉摘要 + 索引"功能：

- 每篇游记挑 **1–2 张** 代表作（cover 那张几乎必选 + 一张视觉冲击力强的辅图）
- `caption` 格式：`<地理 · 地点> — 收录于《<博文标题>》` —— 双重信息：拍摄位置 + 反向索引
- 按**色彩冲击力**排序而不是时间，让 3 列瀑布颜色错开
- **不要**把博文所有图都塞进 album（重复、稀释）；**不要**做完全独立（暂时是空的）

未来用户拍到"博文塞不下但单独有故事"的图，再慢慢往 album 里加，让它从"视觉摘要"
长成真正独立的图库。

---

## 行程 (Trip) 体系

一次旅行通常横跨多个城市；每篇 post 写一个城市，多篇 post 通过一个 **trip** 聚合
成一次行程。trip 是和 post 平级的 content collection，住在 `src/content/trips/`。

### Slug 命名公约

**`<国家>-<YYYY-MM>`**，全小写，如 `japan-2020-01`、`taiwan-2024-03`。

- 月份精度足够区分 99% 的情况（同年同月重访同国家极罕见）
- ISO 数字按时间天然排序，目录里一眼能看出先后
- 不用「season」「winter」之类的主观词

**冲突 fallback**（同月两次）：扩到起始日，如 `japan-2020-01-30` / `japan-2020-01-15`。

**URL ≠ 显示名**：slug 是 URL 和引用标识；trip frontmatter 的 `name` 字段是页面/卡片
上看到的人类可读名（如 `2020 一月 · 日本`）。两者解耦，slug 不需要好看。

### Trip frontmatter

```yaml
---
name: <显示名，如「2020 一月 · 日本」>
startDate: YYYY-MM-DD      # 抵达日（用 EXIF 最早一张图的日期，不是最早一篇 post）
endDate: YYYY-MM-DD        # 离开日
country: <国家中文>
excerpt: <80-150字钩子，整次旅行的一句话总结>
cover: /images/<某篇post slug>/<YYYYMMDD_HHMMSS>.jpg  # 通常借一篇 post 的 cover
---

正文：3-6 段。背景（为什么去/和谁去/啥季节）、行程梗概（哪些城市哪些日子）、
一两句立意（为什么这次旅行值得单独成篇）。**不要重复 post 里已经写过的细节**。
```

### Claude 写新 post 时的归属推断流程

每次用户让我写新 post，**我先扫 `src/content/trips/`**：

| 场景 | 做什么 |
| --- | --- |
| post 日期落在某 trip 的 `startDate`/`endDate` 区间内 | 自动加 `trip: <匹配的slug>`，告诉用户："归到 xxx 了，不对告诉我" |
| 日期不匹配任何已有 trip 但看起来是旅行（多日跨地、有交通元素） | 反问："看起来是新行程，叫什么 slug？默认建议 `<国家>-<YYYY-MM>`，要的话我同步建一个 trip 文件" |
| 单篇随笔、不属于任何行程 | 不加 `trip` 字段，让它单独存在 |
| 用户明确说"归到 xxx" 或"不算行程" | 按用户指令 |

**用户不需要在每次写 post 时手动指定 trip slug** —— 那是机械工作，由我据日期匹配。
用户只在两种时刻需要决定：开启新行程（命名 + 创建 trip 文件）、纠正错判。

### 双向同步检查清单 ⚠️

**Trip 是 post 的"封面册"，两者必须互相 awareness。任何一边改动，另一边都要回头看一眼 ——
这是这套系统最容易漏的一步。**

#### A. 改/加 post 时（最高频，最容易漏）

只要 post 有 `trip:` 字段（或这次操作给它加了/去了 `trip:` 字段），**写完正文后必须打开对应 trip
文件**，逐项核对：

1. **trip `startDate` / `endDate`** —— 新 post 的 `date` 是否落在区间内？不在就扩区间。
2. **trip `excerpt`** —— trip 的一句话总结是否还能涵盖新内容？例如原 excerpt 写"大阪+京都两城"，
   加了东京就要改成三城。
3. **trip 正文 markdown** —— 如果正文里手写了"这次去了 A、B"之类的具体清单或叙事，要补上
   新地点；如果只是泛泛而谈则不必改。
4. **trip `cover`**（可选）—— 如果新 post 有视觉冲击更强的 cover，考虑替换。
5. **trip `name`**（极少）—— 如果行程性质实质改变（比如本来只去关西，后来加了关东），
   显示名可能要从「关西冬季」变成「关西关东冬季」。

**如果 post 被删除或迁出 trip**：同步检查 trip 的 `cover` 是否还指向有效路径（被删 post 的
图片可能也被一起删了），以及 `excerpt`/正文有没有提到被删 post 的内容。

#### B. 改/加 trip 时

1. 该 trip 下所有 post 的 `trip:` 字段是否仍指向正确 slug（**改 trip slug 时务必批量改 post**）。
2. trip 的 `startDate` / `endDate` 是否覆盖所有 post 的 `date`。
3. trip 的 `cover` 引用的图片路径仍存在。

#### C. 新建第一篇属于新 trip 的 post（trip 还不存在）

按上面「Claude 写新 post 时的归属推断流程」走 —— 没有匹配的 trip 就问用户要不要建。
确认要建则一并完成：

- 写 trip frontmatter（name / startDate / endDate / country / excerpt / cover）
- 写 trip 正文（3-6 段，不要重复 post 里的细节）
- 该 post 的 `trip:` 字段指向新 trip slug
- 检查仓库里**其他已有 post** 的 `date` 是否也落在这个 trip 的区间内 —— 是的话追加 `trip:` 字段
  把它们也纳入（容易漏：第二次帮某段历史补行程时，往往只想到当前正在写的那篇）

#### D. 不需要手动维护的（自动的）

- `/trips/<slug>` 页面自动列出 `trip:` 匹配的所有 post（按日期升序）
- 行程详情页底部的合并 trail map 自动包含所有子 post 的 photo-meta（不需要单独跑脚本）
- 首页"近期行程"自动按 `startDate` desc 排序，最多 3 张卡
- 归档/标签/PostCard 的 trip chip 自动从 `tripNames` 映射
- 侧边栏「行程数目」自动统计

---

## 几条容易踩的坑

| 坑 | 现象 | 对策 |
| --- | --- | --- |
| 在 LAB-L 加 `sigmoidal-contrast` 想"提对比" | 暗推 a/b 通道，所有图饱和偏目标、极端图出紫青色斑 | 保持管线最简，对比只靠 `-auto-level` |
| 强力 saturation boost 直接做 | 阴云区域 JPEG chroma 噪声被推出紫青斑 | SatMul>1.3 时先在 LAB a/b 做高斯模糊 |
| 调一张图时只 reset 那一张就重跑脚本 | 目录里其他图被**二次处理**，饱和度叠乘 | reset **整个目录**再跑，脚本是全目录 in-place |
| 章节标题加时间戳 | 用户嫌「刻意」 | 时间感通过叙述自然带出 |
| 图片用序号命名 | 加一张新图就要重排所有名字 | 用 EXIF `YYYYMMDD_HHMMSS` |
| 没和用户对行程就动笔 | 写出来像看图说话 | 第 3 步表格必须先确认 |
| 直接给一稿不给选项 | 文风没踩中 | 第 4 步必须先给样段 A/B |
| frontmatter `date` 写成今天 | 列表页时间错乱 | 用 EXIF 日期（或游后几天，制造「即时随笔」感） |
| 精选阶段按「时间跨度大」断定主干、跳过中段图 | 跨度内藏着完整的次要故事被漏掉（例：跳过 13:30→13:50 漏了「沿小火车铁道」段） | 看完**每张**图再分类，不能用「相距 30 分钟所以中间无内容」的启发 |
| 没看完图就脑补行程的呼应/收尾 | 写了「回到 X 站」结果用户其实从 Y 站离开 — 事实错误 | 行程的起止站点必须由 EXIF + 实图确认，不靠想象 |
| 假定"AI 推荐的最有故事的图"就是用户想要的 | 用户精选后舍弃了 AI 推的「松枝下渡月橋」「平交道」「JR 站外观」等"细节有故事"图，保留更地标的版本 | AI 给候选 → **用户精选** → AI 按用户精选写；不要硬塞"自己觉得好"的图 |
| 写"当时游记"却带进事后视角 | "现在回头看这是分水岭"立刻漏出真实写作时间在事件几年后 | 用 "**当下视角**" 写法（"没人说得清它会变成什么"），保留时代质感但不出戏 |
| 正文用 `# H1` 标题 | markdown lint 警告 + 跟 Astro 自动渲染的 title H1 重复 | 正文只用 H2/H3，多段游记用 `## 大块 → ### 章节` |
| markdown 里竖图按宽度撑满 | 一张 3:4 竖图占满整个视口、阅读节奏被打断 | `global.css` 已配 `.markdown-body img { max-height: 75vh; margin: auto }`，写新主题时别忘了这条 |

---

## 参考样本

按此流程产出的两篇游记，风格都是「散文白描 + 生活随笔感想」的融合 —— 可作为新游记的语感锚点：

- [`src/content/posts/kyoto-winter.md`](src/content/posts/kyoto-winter.md)
  约 2500 字，18 张配图。**多段行程模板**：上午嵐山 + 下午伏见，用 `## 大块 + ### 章节`
  结构，结尾「半天灰，半天红」的并置呼应。
- [`src/content/posts/osaka.md`](src/content/posts/osaka.md)
  约 1400 字，9 张配图。**单线行程模板**：从大阪城外围→天守阁→广场→出园→道顿堀→
  松屋牛丼，结尾呼应早上的鸽子。
