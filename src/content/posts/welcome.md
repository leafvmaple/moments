---
title: 你好，moments
date: 2026-05-27
tags:
  - 起笔
  - 站务
excerpt: 这是 moments 站点的第一篇随笔。技术博客留给代码，这里留给生活的碎片。
---

## 关于这里

[leafvmaple.com](https://leafvmaple.com) 是写代码的地方，**moments** 是写其他的地方。

照片、音乐、读后感、出门看到的某棵树 —— 那些不太适合放在技术博客里、又值得被记下来的东西，都会落在这里。

## 这个站点是怎么搭起来的

- 框架：[Astro](https://astro.build) —— 编译为纯静态 HTML，部署到 GitHub Pages
- 设计：复刻了我多年前用过的 Typecho **handsome** 主题的调色与排版（主色 `#23b7e5`、左导航 + 卡片列表的味道）
- CMS：直接写 Markdown 放进仓库，没有后台

```
src/
├─ content/posts/   ← 在这里加 .md 文件
├─ data/album.json  ← 在这里加相册条目
└─ pages/           ← 路由
```

## 接下来

- [ ] 友链页面 `/links`
- [ ] 音乐播放器（致敬旧站的 `/music`）
- [ ] 把旧 Typecho 上的生活向随笔慢慢迁过来

> 旧的好东西不应该被时代抛下，但也不必把它们原封不动地保留下来。
