# v3.8.3-patch.16 群邀请 `maxSeq` 修复记录

## 目的和基线

本补丁修复 OpenIM 群消息被撤回后邀请成员时，
`/group/invite_user_to_group` 返回 `ArgsError: maxSeq is invalid` 的问题。

补丁建立在官方
[`v3.8.3-patch.16`](https://github.com/openimsdk/open-im-server/tree/v3.8.3-patch.16)
及本 Fork 的安全依赖提交 `6dad469a8fb162c45dcd06929d4dab12288c32c8`
之上。它不修改 OpenIM 服务业务代码、配置、镜像运行层、正式发布身份或
`managed-group-v5` 契约。

正式 release 仍由
[`openim-release.env`](https://github.com/comeallin/be-message/blob/main/deploy/openim-release.env)
定义；本记录中的镜像仅用于本地候选验证，不能推送或作为环境部署版本。

## 上游根因和最小修复

OpenIM 官方 [Issue #3750](https://github.com/openimsdk/open-im-server/issues/3750)
报告了相同接口、相同 `maxSeq is invalid` 错误，并由官方
[PR #3762](https://github.com/openimsdk/open-im-server/pull/3762) 关联修复。

根因位于 `github.com/openimsdk/protocol` 的请求校验：群组服务在新成员加入时
调用 `SetConversationMaxSeq(..., 0)`，但旧版协议把 `0` 错误地当作非法值。官方
[protocol 提交 91e8d26](https://github.com/openimsdk/protocol/commit/91e8d26ed5b8ebd2711483bb558e797fa40f4612)
将校验从 `MaxSeq <= 0` 改为 `MaxSeq < 0`，该修复首次包含于
`v0.0.73-alpha.18`。

因此本补丁仅执行下列最小依赖更新：

| 模块 | 修复前 | 修复后 | 原因 |
| --- | --- | --- | --- |
| `github.com/openimsdk/protocol` | `v0.0.73-alpha.12` | `v0.0.73-alpha.18` | 包含 `maxSeq=0` 合法性修复 |

没有采用上游 PR 中额外的 `.19` 功能变更；`.18` 是含该修复的最小版本。未来合并
上游 `3.8.3-patch` 或更高正式 tag 时，应对比其协议版本：版本达到或高于 `.18`
时可用上游版本替换此约束，低于 `.18` 时必须保留该下限。

## 回归保护和本地验证

新增 `internal/rpc/conversation/max_seq_protocol_test.go`，验证 OpenIM 依赖协议的
公共契约：`maxSeq=0` 必须合法，负数仍必须被拒绝。这防止后续整理模块图时回退到
包含旧校验的协议版本。

2026-09-19 已实际通过：

```sh
GOWORK=off go mod verify
GOWORK=off go test ./internal/rpc/conversation ./internal/rpc/group ./internal/rpc/msg
sh scripts/test-openim-service-image.sh
```

全部 12 个服务均由更新后的模块图重新编译为本地候选镜像：

```text
openim-security/openim-<service>:v3.8.3-patch.16-managed.6-groupmaxseq.1-local
```

每个候选镜像均已在 `UID:GID 65532:65532`、只读根文件系统、`/tmp` tmpfs、移除全部
Linux capabilities 以及 `no-new-privileges` 条件下通过 `-h` 启动检查。由于上一轮完整
隔离编排已按计划清理，本记录不把该静态与包级验证表述为完整端到端验收；后续必须重建
隔离依赖并重跑“群消息发送 → 作者撤回 → 邀请新成员”的真实 REST 用例。

## 发布限制

1. 本补丁不改变 `OPENIM_RELEASE`、`OPENIM_SOURCE_REVISION` 或
   `OPENIM_CONTRACT`。
2. `managed.6-groupmaxseq.1-local` 是明确的本地候选标签，不是 OpenIM 正式标签。
3. 只有真实 REST 回归、全量服务联动和安全扫描完成后，才能为新的托管 release
   生成不可变镜像摘要并更新部署仓库。
