## ComeAllIn 托管版本维护规则

本仓库是 [OpenIM Server 官方仓库](https://github.com/openimsdk/open-im-server)的 ComeAllIn Fork。`managed/main` 是 ComeAllIn 定制版本唯一的长期演进基线；生产镜像只能从该基线上的不可变 `v<upstream>-managed.<revision>` 标签构建，不能从官方 `main`、功能分支或浮动标签构建。

### 当前基线

`managed/main` 是 ComeAllIn 长期基线。当前批准的官方版本、托管 release、源码提交、镜像契约、构建基础镜像和 Registry digest 只在 [`be-message/deploy/openim-release.env`](https://github.com/comeallin/be-message/blob/main/deploy/openim-release.env)维护；本 README 不复制当前值，避免两个仓库的文档独立漂移。

官方基线之上的定制提交按依赖顺序维护：

1. `f6935f5`：受控群生命周期与空群保留；
2. `1600f44`：关闭群后所有普通角色统一禁写；
3. `b154f05`：历史访问身份、读位点单调性及作者 120 秒撤回；
4. `ea97ac8`：物理消息删除仅允许 App Manager；
5. `b5f117f`：发送、已读和撤回 Webhook 业务闭环。

### 远端与分支职责

本地维护仓库必须配置两个远端：

```text
origin   git@github.com:comeallin/open-im-server.git
upstream https://github.com/openimsdk/open-im-server.git
```

| 分支或标签 | 职责 |
| --- | --- |
| `upstream/main` 和官方 tags | 只读的官方源码与发布依据 |
| Fork 的 `main` | 保留官方同步关系，不接收 ComeAllIn 定制提交 |
| `managed/main` | 官方修复与 ComeAllIn 修改最终汇合的长期基线，禁止强制推送 |
| `codex/*`、`fix/*`、`feat/*` | 从 `managed/main` 创建的短期修改分支，通过 PR 回到 `managed/main` |
| `upgrade/*` | 合并指定官方 tag 的临时升级分支，通过完整验证后回到 `managed/main` |
| `release/<line>-managed` | 仅在需要并行维护多个版本线时创建，不为每次发布创建分支 |
| `v<upstream>-managed.<revision>` | 不可变发布标签，是镜像构建和回滚的唯一源码身份 |

### 日常修改

所有 ComeAllIn 修改都从最新 `managed/main` 开始：

```bash
git fetch origin
git switch managed/main
git pull --ff-only origin managed/main
git switch -c <type>/<change-name>
```

修改完成后通过 PR 合并回 `managed/main`。不得直接向 `managed/main` 强制推送，不得把定制提交写入 Fork 的 `main`，也不得在版本化发布分支上继续日常开发。

### 合并官方修复

普通升级固定到明确的官方 tag，不直接合并浮动的 `upstream/main`。以下命令中的 `<upstream-tag>` 必须替换为经过评审的明确 tag：

```bash
git fetch upstream --tags
git switch managed/main
git pull --ff-only origin managed/main
git switch -c upgrade/<upstream-tag>
git merge --no-ff <upstream-tag>
```

解决冲突后必须保留 merge commit，使 Git 历史同时记录旧托管基线和新官方基线。只有单个、边界明确且不能等待版本升级的官方安全或缺陷修复，才允许在升级分支 `cherry-pick <upstream-commit>`；仍须通过 PR 合并到 `managed/main` 并记录官方提交 SHA。

升级不能只以“能够编译”为完成标准。任何涉及以下文件的官方变化都必须逐条复核对应业务契约：

- `internal/rpc/group/group.go`：受控群变更、退出和空群保留；
- `internal/rpc/msg/verify.go`：关闭群统一禁写；
- `internal/rpc/msg/as_read.go`：请求身份和读位点单调性；
- `internal/rpc/msg/sync_msg.go`：历史读取身份；
- `internal/rpc/msg/revoke.go`：仅作者且 120 秒内撤回；
- `internal/rpc/msg/delete.go`：物理删除仅 App Manager；
- `internal/api/msg.go`：全局检索仅 App Manager；
- `config/webhooks.yml`、`deployments/deploy/openim-config.yml`：`be-message` 回调地址、事件开关及发送前 fail-closed。

### 验证与发布

合并到 `managed/main` 前至少完成：

1. OpenIM 官方单元测试与相关 E2E；
2. 读位点、撤回和 Webhook 配置回归测试；
3. 使用普通用户 Token 直接访问 HTTP/WSS 的旁路测试，确认不能绕过群管理、历史、撤回、搜索和删除规则；
4. 与 `be-message` 的真实发送前、发送后、已读和撤回回调闭环；
5. 镜像架构、版本标签及当前契约标签检查。

默认 `go test ./...` 只运行可独立执行的单元测试。仓库中连接固定外部地址、执行清理或持续写入的历史手工用例使用 `openim_manual` 构建标签隔离；这些用例仍需在受控环境单独验收，不能以默认单测结果代替上述 E2E 和真实回调验证。

验证通过后从 `managed/main` 的明确提交创建带注释标签：

```bash
git switch managed/main
git pull --ff-only origin managed/main
git tag -a <managed-release> -m 'OpenIM ComeAllIn managed contract'
git push origin <managed-release>
```

CI 应以该标签从 `Dockerfile.service` 分别构建服务镜像并记录每个不可变 digest。`scripts/openim-service-image.sh` 是服务白名单和本地构建入口，发布版本、提交、契约、平台与基础镜像从上述唯一事实源读取；镜像不包含源码默认配置，以固定非 root 身份运行。开发和生产同步同一组镜像 manifest；回滚使用上一组已验证的托管标签和 digest，不重写旧标签，也不从旧版本化发布分支重新构建。根目录 `Dockerfile` 生成的全量镜像仅用于本地 Compose 联调，不得推送为 EKS 发布产物。

---

<p align="center">
    <a href="https://openim.io">
        <img src="./assets/logo-gif/openim-logo.gif" width="60%" height="30%"/>
    </a>
</p>

<div align="center">

[![Stars](https://img.shields.io/github/stars/openimsdk/open-im-server?style=for-the-badge&logo=github&colorB=ff69b4)](https://github.com/openimsdk/open-im-server/stargazers)
[![Forks](https://img.shields.io/github/forks/openimsdk/open-im-server?style=for-the-badge&logo=github&colorB=blue)](https://github.com/openimsdk/open-im-server/network/members)
[![Codecov](https://img.shields.io/codecov/c/github/openimsdk/open-im-server?style=for-the-badge&logo=codecov&colorB=orange)](https://app.codecov.io/gh/openimsdk/open-im-server)
[![Go Report Card](https://goreportcard.com/badge/github.com/openimsdk/open-im-server?style=for-the-badge)](https://goreportcard.com/report/github.com/openimsdk/open-im-server)
[![Go Reference](https://img.shields.io/badge/Go%20Reference-blue.svg?style=for-the-badge&logo=go&logoColor=white)](https://pkg.go.dev/github.com/openimsdk/open-im-server/v3)
[![License](https://img.shields.io/badge/license-Apache--2.0-green?style=for-the-badge)](https://github.com/openimsdk/open-im-server/blob/main/LICENSE)
[![Slack](https://img.shields.io/badge/Slack-500%2B-blueviolet?style=for-the-badge&logo=slack&logoColor=white)](https://join.slack.com/t/openimsdk/shared_invite/zt-22720d66b-o_FvKxMTGXtcnnnHiMqe9Q)
[![Best Practices](https://img.shields.io/badge/Best%20Practices-purple?style=for-the-badge)](https://www.bestpractices.dev/projects/8045)
[![Good First Issues](https://img.shields.io/github/issues/openimsdk/open-im-server/good%20first%20issue?style=for-the-badge&logo=github)](https://github.com/openimsdk/open-im-server/issues?q=is%3Aissue+is%3Aopen+sort%3Aupdated-desc+label%3A%22good+first+issue%22)
[![Language](https://img.shields.io/badge/Language-Go-blue.svg?style=for-the-badge&logo=go&logoColor=white)](https://golang.org/)

     
<p align="center">
  <a href="./README.md">English</a> · 
  <a href="./README_zh_CN.md">中文</a> · 
  <a href="./docs/readme/README_uk.md">Українська</a> · 
  <a href="./docs/readme/README_cs.md">Česky</a> · 
  <a href="./docs/readme/README_hu.md">Magyar</a> · 
  <a href="./docs/readme/README_es.md">Español</a> · 
  <a href="./docs/readme/README_fa.md">فارسی</a> · 
  <a href="./docs/readme/README_fr.md">Français</a> · 
  <a href="./docs/readme/README_de.md">Deutsch</a> · 
  <a href="./docs/readme/README_pl.md">Polski</a> · 
  <a href="./docs/readme/README_id.md">Indonesian</a> · 
  <a href="./docs/readme/README_fi.md">Suomi</a> · 
  <a href="./docs/readme/README_ml.md">മലയാളം</a> · 
  <a href="./docs/readme/README_ja.md">日本語</a> · 
  <a href="./docs/readme/README_nl.md">Nederlands</a> · 
  <a href="./docs/readme/README_it.md">Italiano</a> · 
  <a href="./docs/readme/README_ru.md">Русский</a> · 
  <a href="./docs/readme/README_pt_BR.md">Português (Brasil)</a> · 
  <a href="./docs/readme/README_eo.md">Esperanto</a> · 
  <a href="./docs/readme/README_ko.md">한국어</a> · 
  <a href="./docs/readme/README_ar.md">العربي</a> · 
  <a href="./docs/readme/README_vi.md">Tiếng Việt</a> · 
  <a href="./docs/readme/README_da.md">Dansk</a> · 
  <a href="./docs/readme/README_el.md">Ελληνικά</a> · 
  <a href="./docs/readme/README_tr.md">Türkçe</a>
</p>


</div>

</p>

## :busts_in_silhouette: Join Our Community

+ 💬 [Follow us on Twitter](https://twitter.com/founder_im63606)
+ 🚀 [Join our Slack](https://join.slack.com/t/openimsdk/shared_invite/zt-2ijy1ys1f-O0aEDCr7ExRZ7mwsHAVg9A)
+ :eyes: [Join our WeChat Group](https://openim-1253691595.cos.ap-nanjing.myqcloud.com/WechatIMG20.jpeg)

## Ⓜ️ About OpenIM

Unlike standalone chat applications such as Telegram, Signal, and Rocket.Chat, OpenIM offers an open-source instant messaging solution designed specifically for developers rather than as a directly installable standalone chat app. Comprising OpenIM SDK and OpenIM Server, it provides developers with a complete set of tools and services to integrate instant messaging functions into their applications, including message sending and receiving, user management, and group management. Overall, OpenIM aims to provide developers with the necessary tools and framework to implement efficient instant messaging solutions in their applications.

![App-OpenIM Relationship](./docs/images/oepnim-design.png)

## 🚀 Introduction to OpenIMSDK

**OpenIMSDK**, designed for **OpenIMServer**, is an IM SDK created specifically for integration into client applications. It supports various functionalities and modules:

+ 🌟 Main Features:
  - 📦 Local Storage
  - 🔔 Listener Callbacks
  - 🛡️ API Wrapping
  - 🌐 Connection Management

+ 📚 Main Modules:
  1. 🚀 Initialization and Login
  2. 👤 User Management
  3. 👫 Friends Management
  4. 🤖 Group Functions
  5. 💬 Session Handling

Built with Golang and supports cross-platform deployment to ensure a consistent integration experience across all platforms.

👉 **[Explore the GO SDK](https://github.com/openimsdk/openim-sdk-core)**

## 🌐 Introduction to OpenIMServer 

+ **OpenIMServer** features include:
  - 🌐 Microservices Architecture: Supports cluster mode, including a gateway and multiple rpc services.
  - 🚀 Diverse Deployment Options: Supports source code, Kubernetes, or Docker deployment.
  - Massive User Support: Supports large-scale groups with hundreds of thousands, millions of users, and billions of messages.

### Enhanced Business Functions:

+ **REST API**: Provides a REST API for business systems to enhance functionality, such as group creation and message pushing through backend interfaces.

+ **Webhooks**: Expands business forms through callbacks, sending requests to business servers before or after certain events.

  ![Overall Architecture](./docs/images/architecture-layers.png)

## :rocket: Quick Start

Experience online for iOS/Android/H5/PC/Web:

👉 **[OpenIM Online Demo](https://www.openim.io/en/commercial)**

To facilitate user experience, we offer various deployment solutions. You can choose your preferred deployment method from the list below:

+ **[Source Code Deployment Guide](https://docs.openim.io/guides/gettingStarted/imSourceCodeDeployment)**
+ **[Docker Deployment Guide](https://docs.openim.io/guides/gettingStarted/dockerCompose)**

## System Support

Supports Linux, Windows, Mac systems, and ARM and AMD CPU architectures.

## :link: Links

  + **[Developer Manual](https://docs.openim.io/)**
  + **[Changelog](https://github.com/openimsdk/open-im-server/blob/main/CHANGELOG.md)**

## :writing_hand: How to Contribute

We welcome contributions of any kind! Please make sure to read our [Contributor Documentation](https://github.com/openimsdk/open-im-server/blob/main/CONTRIBUTING.md) before submitting a Pull Request.

  + **[Report a Bug](https://github.com/openimsdk/open-im-server/issues/new?assignees=&labels=bug&template=bug_report.md&title=)**
  + **[Suggest a Feature](https://github.com/openimsdk/open-im-server/issues/new?assignees=&labels=enhancement&template=feature_request.md&title=)**
  + **[Submit a Pull Request](https://github.com/openimsdk/open-im-server/pulls)**

Thank you for contributing to building a powerful instant messaging solution!

## :closed_book: License

OpenIMSDK is available under the Apache License 2.0. See the [LICENSE file](https://github.com/openimsdk/open-im-server/blob/main/LICENSE) for more information. 



## 🔮 Thanks to our contributors!

<a href="https://github.com/openimsdk/open-im-server/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=openimsdk/open-im-server" />
</a>
