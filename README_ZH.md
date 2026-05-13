# TokenIsland

> 一个 macOS 刘海屏面板，实时展示 **Claude Code** 与 **Codex CLI** 的 **AI 编码代理状态**和**今日 token 用量**。通过 GitHub Releases 分发，不上 App Store。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE) ![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)

[English](./README.md) | 简体中文

---

## 这是什么

TokenIsland 驻留在 MacBook 刘海屏区域，实时展示两件事：

1. **AI 编码代理活动状态** — Claude Code / Codex 的会话、工具调用、权限请求、运行/等待/空闲状态
2. **今日 token 用量** — 直接解析本地会话日志，零远程 API 调用，零订阅依赖

设计灵感：[CodeIsland](https://github.com/wxtsky/CodeIsland)（刘海 UI + IPC 架构）+ [TokenUsed](https://github.com/uniStark/token-used)（本地 jsonl 解析）。TokenIsland 是**双 CLI 精简版**：只支持 Claude + Codex，无需 App Store，无需 Apple Developer Program。

## 当前状态

🚧 **Pre-alpha**。骨架完成，jsonl 解析器已在真实数据闭环验证，hook IPC 链路已通。Sparkle 自动更新待接入。详见 [`docs/ROADMAP.md`](./docs/ROADMAP.md)。

## 快速开始（从源码）

```bash
git clone https://github.com/can4hou6joeng4/TokenIsland.git
cd TokenIsland
swift run TokenIsland          # 启动刘海屏面板，无副作用
```

可选子命令：

```bash
swift run TokenIsland install     # 注入 hook 到 ~/.claude/settings.json 和 ~/.codex/hooks.json
swift run TokenIsland uninstall   # 干净回滚所有 tokenisland-managed 条目
swift run TokenIsland doctor      # 打印安装状态和路径
swift run TokenIslandVerify       # 验证 parser 在本机数据上的输出
```

Apple Silicon 机器建议使用项目内置开发运行脚本。它会强制走原生
`arm64` SwiftPM 构建，并以 `.app` bundle 方式启动，避免 Rosetta shell
影响默认构建架构。开发构建不会启动 Sparkle，除非 `SUFeedURL` 已配置为
真实 HTTPS appcast 地址：

```bash
./script/build_and_run.sh          # 构建并启动 dist/TokenIsland.app
./script/build_and_run.sh --verify # 启动后确认进程存在
```

## 首次启动（DMG / Gatekeeper）

TokenIsland 使用 **ad-hoc 签名**，不走 Apple Developer ID 流程（刻意避开 $99/年的 Developer Program）。在干净的 Mac 上从 Finder 双击 `TokenIsland.app` 首次启动时，会弹出*"TokenIsland 无法打开，因为 Apple 无法检查它是否包含恶意软件"*的对话框。

这是 GitHub Releases 分发的 macOS app 通病。任选一种绕过：

```bash
# 方法 A — 终端命令（零 UI 操作）
open /Applications/TokenIsland.app

# 方法 B — Finder 右键技巧
#   右键 TokenIsland.app → 打开 → 在对话框点"打开"。
#   macOS 会记住信任决策，下次双击不再阻拦。

# 方法 C — 抹掉 quarantine 属性，之后双击直接生效
xattr -d com.apple.quarantine /Applications/TokenIsland.app
```

`spctl --assess` 对 ad-hoc 签名返回"rejected"是正常现象，**不影响 `open` 启动**。

## 系统要求

| 组件 | 版本 |
|---|---|
| macOS | 14.0 (Sonoma) 及以上 |
| Swift toolchain | 5.9 及以上 |
| Claude Code 会话 (`~/.claude/projects/**/*.jsonl`) | 可选 |
| Codex CLI 会话 (`~/.codex/sessions/**/*.jsonl`) | 可选 |

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│  Sources/TokenIslandCore   ← 纯数据：解析器 + 模型             │
│    Parsing/ClaudeJsonlParser, CodexJsonlParser                │
│    Models/TokenUsage, SessionModel                            │
│    IPC/HookEvent                                              │
│                                                                │
│  Sources/TokenIsland       ← AppKit/SwiftUI 可执行文件         │
│    NotchPanelView          刘海面板视图                        │
│    PanelWindowController   刘海几何定位                        │
│    AppState                会话状态机                          │
│    HookServer              Unix socket IPC                    │
│    TokenUsageStore         后台采样                            │
│    HookInstaller           settings.json 安全合并              │
│                                                                │
│  Sources/TokenIslandBridge ← 小型 CLI 二进制（hook 转发器）    │
│  Sources/TokenIslandVerify ← 开发工具，打印解析结果            │
└─────────────────────────────────────────────────────────────┘
                       ▼
              /tmp/tokenisland-<uid>.sock
                       ▼
   Claude Code / Codex CLI 的 hook → JSON-line 事件
```

## 安装的 hook 列表

| CLI | 配置文件 | 注入的事件 |
|---|---|---|
| Claude Code | `~/.claude/settings.json` 的 `hooks` 段 | UserPromptSubmit / PreToolUse / PostToolUse / Notification / Stop / SubagentStart / SubagentStop / SessionStart / SessionEnd |
| Codex CLI | `$CODEX_HOME/hooks.json` 的 `hooks` 段 + `config.toml` 追加 `hooks = true` | SessionStart / SessionEnd / UserPromptSubmit / PreToolUse / PostToolUse / PermissionRequest / Stop |

所有由 TokenIsland 写入的条目都带 `_managedBy: "tokenisland-managed"` 标记。`TokenIsland uninstall` 只清理这些标记条目，绝不动你其它的配置。

## 致谢

- [CodeIsland](https://github.com/wxtsky/CodeIsland) — 刘海屏 UI + IPC 架构灵感
- [TokenUsed](https://github.com/uniStark/token-used) — 本地 jsonl 解析参考

## 许可证

MIT — 详见 [LICENSE](./LICENSE)。
