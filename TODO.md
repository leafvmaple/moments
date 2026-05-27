# TODO

## V3 — 装饰与互动迭代

骨架已经成型（V1 骨架 + V2 复刻 handsome 视感），V3 让站点更"活"起来。按之前定的"装饰品 tier"分块：

### 顶栏

- [ ] **搜索框启用**（`Ctrl+K`） —— 当前只是 stub
  - 客户端搜 posts 的 title / excerpt / tags
  - minisearch 或 fuse.js（~10KB），或者直接 `includes` 起步
  - 命令面板弹窗，`Esc` 关闭，`↑/↓` 选中，`Enter` 跳转
- [ ] **音乐播放器装饰位** —— 致敬旧站顶栏中部 APlayer
  - HTML5 `<audio>` + 自定义控制条（封面/曲名/上一首/播放/下一首）
  - `src/data/playlist.json` 驱动
  - 切页时不要重置 —— 需要 hydration 或 view transitions
- [ ] **时钟下拉** —— 旧站顶栏左侧那个 🕐 icon dropdown，可以做成"近期发布时间轴"

### 右侧栏

- [ ] **quick-tabs 真正可切换** —— ♥/💬/🎁 当前只是装饰
  - tab 1：热门文章（按阅读量 / 评论数）
  - tab 2：最近评论（giscus 数据）
  - tab 3：随机文章

### 内容 / 路由

- [ ] **giscus 评论** —— 评论挂 GitHub Discussions
  - 开启 repo 的 Discussions，建 "Comments" category
  - 嵌入到 post detail 页底部
  - 评论数顺便回填右侧栏「评论数目 / 最后活动」
- [ ] **`/links` 友链页**
- [ ] **`/about` 关于页** —— 自我介绍 + 时间线 + 友情指引到 leafvmaple.com
- [ ] **`/tags/[tag]` 标签过滤页** —— 解决"标签云点击没反应"
- [ ] **`/archive` 归档页** —— 按年/月折叠的文章列表
- [ ] **`404.astro`** —— 替换 Astro 默认 404
- [ ] **真实相册** —— 替换 `album.json` 里的 picsum 占位图

### 工程

- [ ] **`@astrojs/rss`** —— 当前 LeftAside 底部链接的 `/rss.xml` 是 404
- [ ] **`@astrojs/sitemap`** —— SEO 基础
- [ ] **OG / Twitter Card meta** —— 文章被分享到社交平台有正确预览图
- [ ] **Shiki 代码高亮主题配置** —— Astro 自带，挑一套深色主题对齐站点调性
- [ ] **`astro:assets` 处理本地图片** —— 替换 cover 用本地图后启用

## 已知小问题

- [ ] 移动端 `<900px` 左侧栏会塌成顶部块，但内部布局没打磨
- [ ] 暗色模式下卡片阴影几乎不可见（可考虑改用边框替代）
- [ ] 标签云点击无跳转（等 `/tags/[tag]` 页实现）
- [ ] 文章详情页右侧栏内容和首页一样（最近文章会包括自己）

## 远期 / 可选

- 旧 Typecho 站 `D:\Code\com.leafvmaple\article` 里的文章基本是技术文，应该归 `leafvmaple/blog`，不属于 moments。
- 旧站的 douban / github 卡片 widget —— 取舍看心情。
- 阅读时长估算、TOC、目录粘性侧边 —— 文章变多了再说。
