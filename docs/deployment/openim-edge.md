# OpenIM Edge 单域名入口

`openim-edge` 是 ComeAI Fork 新增的无状态 Nginx 反向代理，不属于 OpenIM 的业务进程。它复用一个外部 HTTPS 域名，将官方 SDK 所需的两个地址按路径转发到已有的 OpenIM 服务：

| SDK 参数 | 外部路径 | 集群内目标 |
| --- | --- | --- |
| `apiAddr` | `https://<IM_HOST>/api` | `openim-api:10002` |
| `wsAddr` | `wss://<IM_HOST>/msg_gateway` | `openim-msggateway:10001` |

OpenIM 官方域名部署同样使用 `/api/` 与 `/msg_gateway` 两条路径；因此不需要第二个域名，也不能把 API 或 Message Gateway 的原生端口直接暴露给互联网。

## 清单与职责

- `deployments/deploy/openim-edge-deployment.yml` 是该组件的 Kubernetes 基础清单，包含 ServiceAccount、Nginx ConfigMap、Deployment 和内部 ClusterIP Service，并固定到批准的 ECR digest。
- 环境仓库负责 Namespace、NLB、ACM 证书、NetworkPolicy 和部署记录；环境清单的 ECR digest 必须与本清单保持一致。
- 运行镜像必须先从批准的上游 Nginx 镜像按固定摘要镜像到组织 ECR，并使用 ECR 不可变 digest。不得在运行清单中引用 Docker Hub、GHCR 或浮动标签。

## 当前开发环境镜像基线

- 已部署镜像：`343575638603.dkr.ecr.us-west-2.amazonaws.com/openim-edge@sha256:9bb88ccbc19c816e7df3d1b6a39e44f180df1359c46df8e15874add103857151`。
- 上游来源：`nginxinc/nginx-unprivileged:1.31.6-alpine3.24`，上游 index digest 为 `sha256:b54ac358b83fc6c965793fd271839b4ea4cdb6e99895bb19618cbc2ca152d972`，已核对 `linux/amd64` manifest 为 `sha256:e540d4ae1ecde86661086867083733ad1b5a408a4ba9e0b1ec5c55e93c99da78`。
- ECR Basic 扫描完成且各严重度均为 `0`。此前候选 `nginx-unprivileged-1.29.8-amd64@sha256:3f9a465ff4ca0d25db1a415f384576b1b0832ca681fbf03e2b575f24859b3ef0` 扫描出 `13 Critical / 45 High / 32 Medium / 2 Low`；其 manifest 与标签已于 `2026-09-21` 从 ECR 删除，仅在变更记录中保留漏洞和拒绝决策。

## 反向代理约束

1. 仅 `443` 对外开放。NLB 终止 TLS 后，将 TCP 流量交给 `openim-edge:8080`；`10001` 和 `10002` 始终保持 ClusterIP。
2. `/api/` 代理到 `openim-api:10002/`，尾部斜杠会剥离 `/api` 前缀；代理必须设置 `X-Request-Api: https://$host/api`。
3. `/msg_gateway` 代理到 `openim-msggateway:10001/`，尾部斜杠会把 Gateway 所需的请求路径转换为 `/`，并只在该路径保留 WebSocket Upgrade 头。
4. NLB 已完成 TLS 终止，Nginx 不能使用收到的 `$scheme` 推断外部协议；配置必须显式传递 `X-Forwarded-Proto: https`。
5. 该组件不保存 Token、管理员密钥或消息内容，不挂载 OpenIM 管理 Secret，也不需要 AWS 身份。
6. OpenIM SDK 会在 WebSocket 查询参数中传递短期 JWT；`/msg_gateway` 必须关闭 Nginx access log，避免凭证进入集群日志系统。

## 验收与回退

部署后依次验证 NLB Target Group 健康、`/healthz`、`https://<IM_HOST>/api` 的 OpenIM 响应、`wss://<IM_HOST>/msg_gateway` 握手，以及两名测试用户的 `OnConnectSuccess` 和单聊接收事件。

若需要回退，只删除或缩容 `openim-edge` 和它的 NLB Service；不要改动 `openim-api`、`openim-msggateway`、MongoDB、Kafka 或既有 OpenIM 服务。
