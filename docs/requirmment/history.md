# 提交需求历史

## 2026-09-11 14:01 · 修复 macOS 数据库初始化并支持 tag 自动构建

- **提交范围**：将订阅数据库改到系统应用数据目录；新增 GitHub Build workflow（tag 触发构建并发布 Release）；版本升级到 `0.2.12`。
- **用户需求**：
  - 修复 macOS 启动“初始化失败 / SQLite code 14 unable to open database file”。
  - 增加 GitHub 自动构建。
  - 可以通过 tag 触发构建。
  - 升级版本、提交、打 tag、推送。
- **需求修正/撤销**：无。tag 触发从仅 `v*` 调整为任意 tag，并避免与 `paths` 过滤冲突。
- **验收结果**：`cargo test --lib subscription::storage` 通过（8 passed）。macOS 启动路径与 GitHub Actions 实际跑通情况待用户在推送后确认。
- **关联图片**：![macOS 初始化失败](assets/20260911-140100-macos-db-and-ci/macos-init-db-cantopen.png)
- **代码提交**：待提交
