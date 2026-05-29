# TODO

## V3 — 装饰与互动迭代

骨架已经成型（V1 骨架 + V2 复刻 handsome 视感），V3 让站点更"活"起来。按之前定的"装饰品 tier"分块：

### 顶栏

- [x] **搜索框启用**（`Ctrl+K`）
  - 客户端搜 posts 的 title / excerpt / tags（暴露在 `/search-index.json`）
  - 命令面板模态，`Esc` 关闭，`↑/↓` 选中，`Enter` 跳转
- [x] **音乐播放器装饰位** —— 顶栏中部
  - HTML5 `<audio>` + 自定义控制条（封面/曲名/上一首/播放/下一首）
  - `src/data/playlist.json` 驱动
  - 用 localStorage 记住曲目和播放位置（粗粒度续播）
  - ⚠️ 跨页面真正无缝持续仍需要 view transitions 或常驻 shell，留作后续
- [x] **时钟下拉** —— 顶栏左侧 🕐，下拉显示近期发布 + 跳归档入口

### 右侧栏

- [x] **quick-tabs 真正可切换**
  - ♥ 推荐：按标签数排（待有阅读量/点赞数后替换）
  - 💬 最近：按日期排（保留旧默认行为）
  - 🎁 随机：客户端洗牌后选 3 篇

### 内容 / 路由

- [ ] **giscus 评论** —— 占位完成，等你提供 repo 信息
  - 已加 `src/data/giscus.json` + `Comments.astro`，挂在文章底部
  - 启用步骤：开 Discussions → 建 Comments 分类 → 在 giscus.app 拿 id → 填配置 + `enabled: true`
- [x] **`/links` 友链页** —— `src/data/links.json` 驱动
- [x] **`/about` 关于页** —— 占位文案，待你润色
- [x] **`/tags/[tag]` 标签过滤页** —— 标签云 / PostCard / 详情页的标签都已接上
- [x] **`/archive` 归档页** —— 按年分组
- [x] **`404.astro`**
- [ ] **真实相册** —— 等你的图片，目前继续用 picsum

### 工程

- [x] **`@astrojs/rss`** —— `/rss.xml`，LeftAside 链接不再 404
- [x] **`@astrojs/sitemap`** —— `/sitemap-index.xml`
- [x] **OG / Twitter Card meta** —— BaseLayout 接 `ogImage` / `ogType`，文章用 cover 当 OG 图
- [x] **Shiki 代码高亮主题配置** —— github-dark-dimmed
- [ ] **`astro:assets` 处理本地图片** —— 等开始用本地图再启用

## 已知小问题

- [x] 移动端 `<900px` 左侧栏塌成顶部条 —— 改成 52px 紧凑顶栏，水平滚动 nav
- [x] 暗色模式下卡片阴影几乎不可见 —— 改成 shadow + 1px ring 组合
- [x] 标签云点击无跳转 —— `/tags/[tag]` 已实现
- [x] 文章详情页右侧栏会包括自己 —— Sidebar 接受 `excludeSlug`

## 远期 / 可选

- 旧 Typecho 站 `D:\Code\com.leafvmaple\article` 里的文章基本是技术文，应该归 `leafvmaple/blog`，不属于 moments。
- 旧站的 douban / github 卡片 widget —— 取舍看心情。
- 阅读时长估算、TOC、目录粘性侧边 —— 文章变多了再说。
- 音乐播放器跨页面真正持续（view transitions / 持久 shell）。
- quick-tabs 的"推荐"换成真实指标（阅读量 / 点赞数 / 评论数），需要先接上后端或者埋点。

## 待补全坐标 (Trail Map)

> 自动生成区域：跑 `extract-photo-meta.mjs` 时会刷新下面这段（保留勾过的 `[x]` 和其他 slug 的条目）。
>
> - 资料够认出地标 → 把 `src/data/photo-meta/<slug>.json` 对应条目的 lat/lng 改对、加 `"manual": true` —— 下次跑就从这里消失
> - 借用的坐标已经足够近、可以接受 → 把 `[ ]` 改成 `[x]` —— 下次跑保留 `[x]` 标记

<!-- GPS_TODO:START -->
- [ ] kyoto-winter/20200129_115705.jpg — borrowed:20200129_115131.jpg (±5.6min)
- [ ] kyoto-winter/20200129_120147.jpg — borrowed:20200129_120814.jpg (±6.5min)
- [ ] kyoto-winter/20200129_133030.jpg — borrowed:20200129_132659.jpg (±3.5min)
- [ ] kyoto-winter/20200129_133118.jpg — borrowed:20200129_132659.jpg (±4.3min)
- [ ] kyoto-winter/20200129_145240.jpg — borrowed:20200129_145110.jpg (±1.5min)
- [ ] kyoto-winter/20200129_145428.jpg — borrowed:20200129_145110.jpg (±3.3min)
- [ ] kyoto-winter/20200129_152834.jpg — borrowed:20200129_153238.jpg (±4.1min)
- [ ] osaka-winter/20200128_110029.jpg — borrowed:20200128_105946.jpg (±0.7min)
- [ ] osaka-winter/20200128_114211.jpg — borrowed:20200128_113443.jpg (±7.5min)
- [ ] osaka-winter/20200128_121347.jpg — borrowed:20200128_122045.jpg (±7.0min)
- [ ] osaka-winter/20200128_122208.jpg — borrowed:20200128_122045.jpg (±1.4min)
<!-- GPS_TODO:END -->
