# ComeAI 开发环境 OpenIM 补齐清单

本目录记录 `comeai-dev` EKS 集群、`open-im` Namespace 中缺失的 Group RPC、Push 工作负载和 Message Webhook 精确出站规则，并记录为容纳它们所需的 Namespace CPU ResourceQuota。它不接管已经运行的 OpenIM 服务、ConfigMap 或 Secret。当前命名空间以集群实际状态为准；旧部署文档中的 `openim-system` 不是本次发布目标。

镜像使用 `be-message` 的 [OpenIM 发布身份](https://github.com/comeallin/be-message/blob/main/deploy/openim-release.env)与 [服务镜像摘要锁定文件](https://github.com/comeallin/be-message/blob/main/deploy/openim-images.lock)登记的 ComeAllIn release。清单固定不可变 digest；更新 release 时须一起核对镜像的 `org.opencontainers.image.revision`、`org.opencontainers.image.version`、`com.comeallin.openim.contract` 标签。

## 依赖与顺序

- 现有 `openim-runtime` ServiceAccount、`openim-runtime-config` 和 `openim-runtime-renderer` ConfigMap、`openim-runtime-local` Secret、`openim-shared-data-credentials` SecretProviderClass 必须存在。清单只引用它们，不保存密钥值。
- `runtime-overrides.patch.json` 只更新现有 ConfigMap 中 Group RPC 与 Push 的配置项，将 `autoSetPorts` 设为 `false`。固定端口分别为 `10260` 和 `10170`，与 TCP 探针相符。Push 的第三方离线通知提供方设为 `dummy`：开发环境未配置个推凭据，而 Web 端离线历史补拉不依赖第三方移动通知。现有其他服务配置不变。配置来源于 2026-09-23 的开发集群，后续升级时应核对上游配置差异。
- Group RPC 先就绪；Push 启动时会连接 User、Group、Msg 与 Conversation RPC，并消费 Kafka `toPush` 队列。`MsgGateway` 负责最终的 WebSocket 下发。
- 单副本适用于当前开发环境，不宣称高可用。两个服务沿用现有 Pod 的 `workload=open-im` 节点选择条件与 `NoSchedule` 污点容忍、渲染器、CSI 挂载、非 root 身份、只读根文件系统及 TCP 探针。该节点可访问内部 MongoDB；调度到其他节点会连接超时。
- 原配额 `limits.cpu: 3` 已用 `2900m`，不足以创建两个各 `350m` 的 Pod。开发环境提高到 `3600m`，其余配额保持原值；所在节点原有 CPU requests 为 `1180m/1930m`，新增 requests 共 `200m`。这是 CPU 上限超配，发布后仍需观察节流与延迟。

## 部署与验证

在本仓库根目录执行，写入范围限定为一个现有 ResourceQuota、现有 ConfigMap 的两个键和两个新增 Deployment：

```bash
test "$(kubectl config current-context)" = comeai-dev
kubectl -n open-im get serviceaccount openim-runtime
kubectl -n open-im get configmap openim-runtime-config openim-runtime-renderer
kubectl -n open-im get secret openim-runtime-local
kubectl -n open-im get secretproviderclass openim-shared-data-credentials

kubectl kustomize deployments/comeai/dev >/tmp/comeai-openim-dev.yaml
kubectl apply --dry-run=server -f /tmp/comeai-openim-dev.yaml
kubectl -n open-im patch configmap openim-runtime-config --type=merge --patch-file deployments/comeai/dev/runtime-overrides.patch.json --dry-run=server -o name

kubectl -n open-im apply -f deployments/comeai/dev/resourcequota.yaml
kubectl -n open-im patch configmap openim-runtime-config --type=merge --patch-file deployments/comeai/dev/runtime-overrides.patch.json
kubectl -n open-im apply -f deployments/comeai/dev/openim-rpc-group.yaml
kubectl -n open-im rollout status deployment/openim-rpc-group --timeout=5m
kubectl -n open-im apply -f deployments/comeai/dev/openim-push.yaml
kubectl -n open-im rollout status deployment/openim-push --timeout=5m

kubectl -n open-im get deployment openim-rpc-group openim-push
kubectl -n open-im get pods -l app.kubernetes.io/name=openim-push
```

部署后使用两个独立浏览器会话登录账号 A、B，确认双方 WebSocket 已连接；A 发送唯一文本，B 不刷新页面即看到消息。再测 B→A、刷新后历史各一份、未读数收敛，并检查 `get_incremental_join_groups` 是否不再取消。仅有 Pod Ready 不代表消息链路通过。

若新增服务异常，先保存脱敏的 Pod 事件和日志，再停止新 Push 消费者或删除本目录新增的 Deployment；不要回滚现有 OpenIM 服务和共享配置。若确实删除了这两个 Deployment，可单独将 ConfigMap 中这两个 `autoSetPorts` 值恢复为原来的 `true`，将 Push 的 `enable` 恢复为原来的 `geTui`。已经发送的消息以历史存储为准，避免重发相同测试消息造成重复。

## 实际部署记录（2026-09-23，comeai-dev）

| 对象 | 结果 |
| --- | --- |
| `open-im/open-im-single-node-budget` ResourceQuota | `limits.cpu` 从 `3` 提高到 `3600m`；部署后 `used=3600m/3600m`，其余配额未改。后续若扩容，需先重新核算配额及节点容量。 |
| `open-im/openim-runtime-config` ConfigMap | 将 `openim-rpc-group.yml`、`openim-push.yml` 的 `autoSetPorts` 改为 `false`；对应固定监听端口为 `10260`、`10170`。Push 的第三方离线通知提供方设为 `dummy`。 |
| `open-im/openim-rpc-group` Deployment | 镜像 `sha256:34d7fe99a6c5b8f0e470617da753f063a3e177b1023165bca2645853918f03a9`；`1/1 Ready`，重启 0 次。 |
| `open-im/openim-push` Deployment | 镜像 `sha256:88eb049097339108b5b18af0e843e13017c21f3e928666910de0ff71eee5eabe`；`1/1 Ready`，重启 0 次。 |

首次发布时遗漏现有服务的节点选择条件与污点容忍，Pod 在普通节点连接 MongoDB 超时；补齐后又发现原 ConfigMap 启用了自动端口，与固定端口探针不符。最终清单已包含这两处修正。两个服务均运行在带 `workload=open-im` 标签的专用节点。

SIT 双账号 A、B 保持页面在线时，A→B 和 B→A 的消息都在接收方**未刷新**时出现；双方刷新后历史各保留一份。两侧 `get_incremental_join_groups` POST 均返回 HTTP 200，原先观察到的 499 本次未复现。测试消息前缀为 `[IM-PUSH-TEST]`，账号密码保存在前端本地忽略文档，不进入本目录。

将 Push 的第三方离线通知提供方从无凭据的 `geTui` 改为 `dummy` 并重启后，又发送 `[IM-PUSH-TEST] post-config A-to-B`。B 仍在未刷新时收到；Push 日志只有首次使用 `dummy` 的提示，没有 `appid is invalid` 或 `offlinePushMsg failed`。这项配置仅关闭未配置的第三方移动通知，Web 离线消息仍通过历史同步补拉。

## Message 附件 Webhook 实际部署（2026-09-24，comeai-dev）

| 对象 | 配置与结果 |
| --- | --- |
| `open-im/openim-runtime-config` | `webhooks.yml` 使用 `http://message-api.comeai.svc.cluster.local:8080/internal/v1/openim`；单聊/群聊的发送前和发送后类型均含 `101,102,105,110`。发送前失败继续为 `false`。开发环境完整域名由 AWS 基础设施仓库的 `generate-runtime-config.sh` 在锁定源码配置的临时副本上替换。 |
| `open-im/openim-runtime-renderer` | 移除将 `webhooks.yml` 重写为 `http://127.0.0.1/disabled` 的旧逻辑；保留锁定源码的回调开关。实际 Pod 内配置经过核对。 |
| `open-im/openim-rpc-msg-to-message-api` | 本目录 NetworkPolicy 仅允许 `openim-rpc-msg` 出站访问 `comeai` 中 `app=message-api` 的 TCP 8080；开发集群已应用。 |
| `open-im/openim-rpc-msg` | 只滚动该 Deployment，镜像仍为 `sha256:00090370e488ae1ab3f6ed984567a2208c1242d03a857f0f37de3eb8fa696dc6`；`1/1 Ready`。没有修改 OpenIM Go 源码。 |

用真实 WASM SDK 验证：未准备的 `CustomElem` 和原生 `FileElem` 均被发送前回调以 `16030012` 拒绝；经 File Service 上传、Message 准备的原生文件和图片使用 `sendMessageNotOss` 发送后，Message 绑定转为 `attached`，接收方可取得短期签名链接。`sendMessage` 会进入 OpenIM 自有上传流程，在本场景发送前返回 SDK `10005`，因此不能用于已由 File Service 上传的附件。
