# ComeAllIn 构建脚本

## 服务镜像

`openim-service-image.sh` 是 EKS 服务镜像的统一构建入口。它只接受内置白名单中的 OpenIM 长期服务，每个镜像只编译并携带一个服务二进制；默认配置、源码、构建工具和其他服务不会进入运行镜像。

当前发布身份不在本仓库重复维护。脚本默认读取同级工作区的 `../be-message/deploy/openim-release.env`；CI 在独立检出时必须通过 `OPENIM_RELEASE_FILE` 指向该文件的受控副本或检出路径。

```bash
./scripts/openim-service-image.sh list
./scripts/openim-service-image.sh build openim-api local/openim-api:candidate
./scripts/openim-service-image.sh build-all <ecr-registry>
```

`build-all` 只负责本地构建和打标签，不执行 Registry 登录或推送。推送前必须逐个验证镜像的服务标签、非 root 身份、配置挂载、启动探针和安全扫描。

运行契约测试：

```bash
./scripts/test-openim-service-image.sh
```
