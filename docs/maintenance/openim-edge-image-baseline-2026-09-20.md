# OpenIM Edge 镜像基线（2026-09-20）

## 批准的运行镜像

| 项目 | 值 |
| --- | --- |
| 上游发行方 | NGINX Inc. `nginxinc/nginx-unprivileged` |
| 上游标签 | `1.31.6-alpine3.24` |
| 上游 index digest | `sha256:b54ac358b83fc6c965793fd271839b4ea4cdb6e99895bb19618cbc2ca152d972` |
| 核对平台 | `linux/amd64` |
| 上游平台 manifest | `sha256:e540d4ae1ecde86661086867083733ad1b5a408a4ba9e0b1ec5c55e93c99da78` |
| ECR Repository | `343575638603.dkr.ecr.us-west-2.amazonaws.com/openim-edge` |
| ECR 运行 digest | `sha256:9bb88ccbc19c816e7df3d1b6a39e44f180df1359c46df8e15874add103857151` |
| 不可变标签 | `nginx-unprivileged-1.31.6-alpine3.24-amd64` |
| ECR Basic 扫描 | `COMPLETE`，Critical / High / Medium / Low 均为 `0` |

该镜像仅提供非特权 Nginx 运行时。`openim-edge` 以 UID/GID `101`、只读根文件系统、`RuntimeDefault` seccomp 和临时 `/tmp` 运行；它不包含 OpenIM 管理密钥、业务 Token 或持久化数据。

## 拒绝候选与原因

`nginx-unprivileged-1.29.8-amd64@sha256:3f9a465ff4ca0d25db1a415f384576b1b0832ca681fbf03e2b575f24859b3ef0` 是首次镜像到 ECR 的候选。ECR Basic 扫描完成后报告 `13 Critical / 45 High / 32 Medium / 2 Low`，因此未写入任何 Kubernetes 工作负载，不能进入开发验证或后续发布。

该 manifest 和标签已于 `2026-09-21` 从 ECR 删除，避免未通过镜像误入后续基线；同一失败镜像在本机 Docker 的 ECR 标签和上游标签也已删除。本文和 AWS 部署历史仅保留扫描结论与删除决策；实际回退只能使用未来通过同等平台、启动和扫描门禁的 ECR digest。
