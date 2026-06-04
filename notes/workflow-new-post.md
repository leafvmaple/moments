# 写一篇新游记的 checklist

每次写新帖照这个走，少漏。

---

## 0. 先看 memory（一次性）

新会话开始前确认 memory 里几个关键工具沉淀：

- `tooling-powershell-exiftool` —— EXIF 写入坑
- `tooling-heic-pillow` —— iPhone HEIC → JPG
- `tooling-ffmpeg-livephoto` —— Live Photo MOV → WebP
- `tooling-read-images-directly` —— Read 工具能直接看 JPG/PNG
- `writing-voice` / `writing-place-name-first-mention` —— 文风铁律

---

## 1. 照片处理（`photos/<trip-folder>/`）

源目录通常名字里有中文（如 `2023伶仃岛`）—— 后续所有命令用 `Push-Location` 走相对路径、不要绝对路径直传 exe。

### 1a. HEIC → JPG

```pwsh
python notes/_heic_full.py IMG_xxxx IMG_yyyy
```

输出 `_full_*.jpg`、全分辨率 q92。

⚠️ pillow-heif **不带 EXIF** —— 后面要 exiftool 单独转印。

### 1b. Live Photo MOV → WebP

```pwsh
python notes/_mov_to_webp.py file.MOV
```

自动检测 loop 点 + 切第一周期 + 1280×24fps WebP。也支持 `--with-mp4` / `--no-loop-detect`。

### 1c. JPG 缺 EXIF 时间 / GPS（pillow-heif 转出来或 iPhone 后期导出）

从同场景 HEIC 静图借（GPS 完全吻合就是配对）：

```pwsh
$exif = "C:\Users\Administrator\AppData\Local\Programs\ExifTool\ExifTool.exe"
Push-Location "<含中文的源目录>"
& $exif -TagsFromFile "<sibling.HEIC>" `
  -DateTimeOriginal -CreateDate -ModifyDate `
  -GPSLatitude -GPSLatitudeRef -GPSLongitude -GPSLongitudeRef `
  -overwrite_original "<target.jpg>"
Pop-Location
```

### 1d. 合图（hero + 多张细节）

```pwsh
$mg = "C:\Program Files\ImageMagick-7.1.2-Q16-HDRI\magick.exe"
& $mg "hero.jpg" -resize 2400x "_hero.jpg"
& $mg "d1.jpg" -resize 800x "_d1.jpg"
& $mg "d2.jpg" -resize 800x "_d2.jpg"
& $mg "d3.jpg" -resize 800x "_d3.jpg"
& $mg montage "_d1.jpg" "_d2.jpg" "_d3.jpg" -tile 3x1 -geometry "+0+0" -background white "_dishes.jpg"
& $mg -size 2400x12 xc:white "_spacer.jpg"
& $mg "_hero.jpg" "_spacer.jpg" "_dishes.jpg" -gravity center -background white -append "_lunch.jpg"
```

布局：顶部 hero 全宽、底部 N 张细节横排。

---

## 2. 入库 `public/images/<slug>/`

### 2a. mass copy + rename

PowerShell 走 `[ordered]@{}` 映射表 + `Copy-Item -LiteralPath`，重命名成 `YYYYMMDD_HHMMSS.jpg`（HHMMSS 是 EXIF 时间）。

模板：

```pwsh
$src = "d:\Code\moments\photos\<trip>"
$dst = "d:\Code\moments\public\images\<slug>"
New-Item -ItemType Directory -Force -Path $dst | Out-Null

$map = [ordered]@{
  "_full_IMG_xxxx.jpg" = "YYYYMMDD_HHMMSS.jpg"
  ...
}
foreach ($k in $map.Keys) {
  Copy-Item -LiteralPath (Join-Path $src $k) -Destination (Join-Path $dst $map[$k]) -Force
}
```

### 2b. 时间撞 → 文件名 + 1 秒

如果两张 EXIF 时间相同（合图 + 单图各占一份、或两张 JPG 时间一样）—— 偏移一个的 EXIF 几秒、文件名跟着改。

### 2c. 转印 EXIF 到入库后的图

如果用 pillow-heif 转的 HEIC、入库后用 exiftool 从原 HEIC 把 time + GPS 拷过来（同样 `Push-Location` 走相对路径）。

---

## 3. photo-meta JSON

```pwsh
$exif = "C:\Users\Administrator\AppData\Local\Programs\ExifTool\ExifTool.exe"
& $exif -c "%+.6f" -j -DateTimeOriginal -GPSLatitude -GPSLongitude -FileName -q `
  "<dst>\*" | Out-File -Encoding utf8 "notes/_meta.json"
```

Decimal 度数、6 位小数。然后手写成 `src/data/photo-meta/<slug>.json`，每条 entry：

```json
{
  "file": "20XX0101_HHMMSS.jpg",
  "src": "/images/<slug>/20XX0101_HHMMSS.jpg",
  "time": "20XX-01-01T HH:MM:SS",
  "lat": 22.103456,
  "lng": 114.025789
}
```

按时间升序排。

---

## 4. trip 定义（如果是新行程）

`src/content/trips/<slug>.md`：

```yaml
---
name: 2023 三月 · 再访外伶仃
startDate: 2023-03-04
endDate: 2023-03-05
country: 中国
excerpt: 一句话 ~70 字、不要长（移动端 card 会拉高）
cover: /images/<slug>/<hero>.jpg
---

(可选两段 body)
```

⚠️ **excerpt 控制在 ~70 字内**（参照 japan-2020-01 那种）—— 否则 card 在移动端被拉高。

---

## 5. places 检查 + 新建

打开 `src/content/places/` 看看：

- 这次去过的所有地点（市、岛、城、温泉乡）有没有 place 文件
- 没有 → 新建 `src/content/places/<id>.md`：

```yaml
---
name: 某地
parent: <上级 place id>  # 可选、顶层不写
excerpt: 一句话定位（地理 + 历史）
cover: /images/.../xxx.jpg  # 可选
---

(可选 body)
```

层级现状：
- `china > guangdong > zhuhai > lingding`
- `japan > tokyo / kyoto / osaka / kobe`
- `japan > hokkaido > sapporo / jozankei / otaru`

---

## 6. post 帖

`src/content/posts/<slug>.md`：

```yaml
---
title: 甲午年腊月，X 到 Y
date: 20XX-XX-XX
trip: <trip-id>           # 可选
places:                   # ⚠️ 必加
  - place-id-1
  - place-id-2
tags:
  - 旅行
  - 城市名               # 跟 places 重复了、暂留、未来可清
  - 国名
excerpt: 短句版的内容简介。
cover: /images/<slug>/<hero>.jpg
---

正文…
```

⚠️ **不要忘 `places` 字段** —— 现在加了地点系统、漏了会导致 `/places/<id>` 页面少这一篇。

### 写作 rules（每帖都过一遍）

- 克制白描 + 短句 + 爱破折号 + 不煽情
- **中文（日文）** 铁律 —— 永远不要反 `日文（中文）`
- **简繁 + 假名规则**：
  - 简繁同字（橋→桥、銀→银、戸→户、灯→灯）→ 直接用简、不加括号
  - 含假名（ぁ-んァ-ヶ）→ 中文（日文）
  - XX通 / 通り / 横丁 → 必须翻译成大道 / 街 / 巷
- 每节 50-95 字 + 物理 anchor + （可选）history anchor 用 **bold**
- 地名首次出现带嵌入式 context（半句、破折号）
- 链接：链回相关 trip / 别的 post（用 `[文字](/posts/<slug>)`，anchor 锚点不保证准、保险就不带 anchor）
- 不要在正文里写 meta 评论（如「iPhone 把视频 padding 成 10 秒」之类的技术细节）

### 余韵 / 后日谈（可选）

跨年代帖（≥ 4 年回看）才适合加：

```html
<details class="postscript">
<summary>余韵 · YYYY 年 M 月，珠海</summary>

(1-3 段反思 + 可选小图)

</details>
```

`<details>` lint 会报 `MD033/no-inline-html`、忽略（hokkaido-2015-day2 等其它帖也是这样）。

---

## 7. build + verify

```pwsh
npm run build
```

- 应该 +2 页（新增 post 详情 + 新增 trip 详情、如果是新 trip）
- 或 +1 页（如果 trip 已存在、只新增 post）

检查：
- `tail -3` 的 build 输出有 `✓ Completed` 没 error
- `/places/<id>` 页面能看到新帖（你新加的 place 文件 + post.places 都对了的话）
- post 顶部 breadcrumb：`属于行程 ·` + `地点 ·` 两行都对

---

## 8. commit + push

```pwsh
git add public/images/<slug>/ src/content/posts/<slug>.md src/content/trips/<slug>.md src/data/photo-meta/<slug>.json src/content/places/<...>.md
git commit -m "feat(posts): <slug> — 一句话描述"
git push origin main
```

新 places 文件别忘加。

---

## 9. 小红书改写版（可选、推流量）

```pwsh
notes/xiaohongshu/<slug>.md
```

格式参照 `notes/xiaohongshu/lingding-2022.md`：
- 标题 20 字内、含「地名 + 攻略」搜索关键词
- 正文 ~380 字、emoji + bullet + 日间分段
- 9 宫格选图（最强吸引力的 3 张放前面）
- 末尾 hashtag 7 个左右 + 导流回听枫阁

---

## 容易漏的清单（来自前几次经验）

1. **photo-meta 一定要 dump exiftool 拿 decimal GPS** —— 手写经纬度会算错
2. **pillow-heif 不带 EXIF** —— 转 JPG 后必跑 exiftool 转印
3. **PowerShell 中文路径要 Push-Location** —— 否则 exe 收到的是乱码
4. **EXIF 时间撞了要文件名偏移**（合图代表的时间 + 同时间的另一图）
5. **中文（日文）方向不要反** —— 自己 grep 过一遍 `（` 检查
6. **简繁同字不要加括号** —— 平安神宫不是平安神宫（平安神宮）
7. **places 字段不要漏** —— 否则 `/places/<id>` 页面少篇
8. **trip excerpt 不要超 70 字** —— 移动端 card 会拉高
9. **`<details>` 余韵段** lint 会警告、是预期的、忽略
10. **链接锚点不准就不带** —— github-slugger 对中文标题的 slug 不可预测
