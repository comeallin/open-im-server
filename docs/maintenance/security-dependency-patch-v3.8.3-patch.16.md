# v3.8.3-patch.16 托管安全依赖补丁

## 目的和范围

本记录约束 ComeAllIn Fork 在官方
[`v3.8.3-patch.16`](https://github.com/openimsdk/open-im-server/tree/v3.8.3-patch.16)
基础上的依赖安全修复。补丁只更新 Go 模块图，不修改 OpenIM 业务源码、协议、配置、Go
工具链或 `managed-group-v5` 契约。

当前长期维护基线是
[`managed/main`](https://github.com/comeallin/open-im-server/tree/managed/main)，其起点提交
`b7911efc7462c5cde012508a7e3332a8ef109909` 已包含该官方 tag。当前批准的正式 release
仍以 [`openim-release.env`](https://github.com/comeallin/be-message/blob/main/deploy/openim-release.env)
为唯一事实源；在新的服务镜像 digest、回归和发布记录完成前，不得修改其中的
`OPENIM_RELEASE`、`OPENIM_SOURCE_REVISION` 或 `OPENIM_CONTRACT`。

## 漏洞修复版本

下表中的版本是 2026-09-19 本地镜像扫描所见 Critical/High 漏洞的修复下限，以及由
Go 最小版本选择（MVS）引入的必要兼容版本。`grpc v1.83.2` 要求 `x/net v0.58.0`、
`x/oauth2 v0.36.0`；`x/image v0.45.0` 要求 `x/text v0.41.0`，因此不能把后四者降到
扫描报告中较早的最低修复版本。

| 模块 | 修复前 | 修复后 | 覆盖的漏洞 |
| --- | --- | --- | --- |
| `google.golang.org/grpc` | `v1.71.0` | `v1.83.2` | `CVE-2026-33186`、`CVE-2026-84304`、`CVE-2026-84445`、`GHSA-hrxh-6v49-42gf` |
| `golang.org/x/crypto` | `v0.32.0` | `v0.55.0` | `CVE-2025-22869`、`CVE-2025-47913`、`CVE-2026-39828`、`CVE-2026-39829`、`CVE-2026-39830`、`CVE-2026-39831`、`CVE-2026-39832`、`CVE-2026-39835`、`CVE-2026-42508`、`CVE-2026-46595`、`CVE-2026-46597`、`CVE-2026-56854` |
| `golang.org/x/net` | `v0.34.0` | `v0.58.0` | `CVE-2026-25681`、`CVE-2026-27136`、`CVE-2026-33814`、`CVE-2026-39821`、`CVE-2026-46600` |
| `golang.org/x/oauth2` | `v0.25.0` | `v0.36.0` | `CVE-2025-22868` |
| `golang.org/x/image` | `v0.15.0` | `v0.45.0` | `CVE-2026-46602`、`CVE-2026-46603` |
| `golang.org/x/text` | `v0.21.0` | `v0.41.0` | `CVE-2026-56852` |
| `github.com/golang-jwt/jwt/v4` | `v4.5.1` | `v4.5.2` | `CVE-2025-30204` |

`grpc v1.83.2` 的已发布模块图还要求更新 Cloud/Auth、xDS、OpenTelemetry、Protobuf 等
传递模块。这些更新由 `go.mod` 和 `go.sum` 锁定；它们不是单独引入的功能需求，不能在
未重新解析、编译和扫描模块图的情况下手工回退。

## 验证和发布限制

补丁至少执行以下验证：

```sh
GOWORK=off go mod verify
GOWORK=off go build ./cmd/...
GOWORK=off go test ./internal/msggateway ./internal/rpc/msg \
  ./pkg/common/discoveryregister ./pkg/common/prommetrics ./pkg/common/webhook
```

### 2026-09-19 本地验证结果

上述模块校验、命令入口编译和指定的 gRPC/Webhook 回归测试均已通过。使用原始
`Dockerfile.service`、`linux/amd64` 和独立
`v3.8.3-patch.16-managed.5-security-local` 标签重新构建全部 12 个服务镜像后，逐个确认
非 root 身份、空的外置配置目录、OCI 标签和只读根文件系统下的帮助命令均可用。

Trivy `0.69.3` 对 12 个候选镜像执行 OS 与 Go 二进制依赖扫描，结果均为
`CRITICAL=0`、`HIGH=0`，且扫描器未报告任何其他严重级别漏洞。扫描器、数据库缓存和
临时报告只用于本地验证，不随提交保留。

随后按 OpenIM 本地服务镜像验证计划构建 12 个 `linux/amd64` 服务镜像，复核非 root、
外置只读配置、服务注册、鉴权 WebSocket、消息 Webhook fail-closed 和重启恢复，并对每个
候选镜像重新执行漏洞扫描。候选镜像必须使用与正式 release 不同的本地 tag，不能推送或
写入环境部署清单。

仓库现有全量测试包含与本补丁无关的基线失败：过期的服务发现/Redis 测试、默认配置期望
差异、不可达的 MongoDB 地址，以及 YAML fixture 期望差异。合并或发布前应单独修复这些
问题；不得将它们归因为本依赖补丁，也不得通过删除测试掩盖。

## 后续合并上游版本

1. 从 `managed/main` 创建升级分支，并合并经过评审的明确官方 tag；不要直接合并浮动的
   `upstream/main`。
2. 对比上游 tag 的
   [`go.mod`](https://github.com/openimsdk/open-im-server/blob/v3.8.3-patch.16/go.mod)
   与本补丁的模块版本。上游版本达到或超过本记录的“修复后”版本时，优先采用上游版本。
3. 上游版本低于安全下限时，保留相应模块约束，执行 `GOWORK=off go mod tidy`，并检查
   `go.mod`、`go.sum` 和模块图；禁止添加 `replace` 绕过上游依赖管理。
4. 重跑本记录的编译/测试、12 服务镜像验证和漏洞扫描。只有全部通过后，才从
   `managed/main` 创建新的托管 release、生成不可变镜像 digest，并更新部署仓库的发布身份。

这样，未来的上游功能合并保留清晰的官方基线、Fork 安全补丁及其撤销条件，而不会把本地
候选镜像误当作正式发布版本。
