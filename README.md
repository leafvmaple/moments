# moments · 叶枫影

生活的片段。照片、音乐、随笔 —— 与技术博客 [leafvmaple.com](https://leafvmaple.com) 互为补集。

**访问地址**：[moments.leafvmaple.com](https://moments.leafvmaple.com)

## 怎么写

- 文章：在 `src/content/posts/` 新增 `.md` 文件，frontmatter 需要 `title` / `date` / `tags` / `excerpt`（可选 `cover`）
- 相册：编辑 `src/data/album.json`，加一条 `{ src, title, caption }`
- 推到 `main`，`deploy.yml` 自动发布

## 本地开发

```bash
npm install
npm run dev      # http://localhost:4321
npm run build    # 输出到 dist/
```

## 设计

复刻了 Typecho **handsome** 主题的色彩与排版：

- 主色 `#23b7e5`
- 字体 Source Sans 3 + 微软雅黑
- 卡片 6px 圆角 + 微阴影
- 跟随系统 / 手动切换的浅深双色

## 部署

`.github/workflows/deploy.yml` 在以下时机重建站点：

- push 到 `main`
- 手动 `workflow_dispatch`

产物经 [`peaceiris/actions-gh-pages`](https://github.com/peaceiris/actions-gh-pages) 推到 `gh-pages` 分支，由 GitHub Pages 托管。自定义域名通过 `public/CNAME` 配置。
