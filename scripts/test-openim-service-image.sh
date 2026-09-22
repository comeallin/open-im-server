#!/bin/sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
builder="$root_dir/scripts/openim-service-image.sh"
dockerfile="$root_dir/Dockerfile.service"

test -x "$builder"
test -f "$dockerfile"

expected_services='openim-api
openim-crontask
openim-msggateway
openim-msgtransfer
openim-push
openim-rpc-auth
openim-rpc-conversation
openim-rpc-friend
openim-rpc-group
openim-rpc-msg
openim-rpc-third
openim-rpc-user'

actual_services="$($builder list)"
test "$actual_services" = "$expected_services"

# 未知服务必须在调用 Docker 前失败，避免构建参数被当作任意路径使用。
if "$builder" build invalid-service invalid:test >/dev/null 2>&1; then
	echo "未知 OpenIM 服务不应通过构建入口" >&2
	exit 1
fi

# 运行镜像不得包含源码配置或以 root 身份运行。
grep -F 'USER 65532:65532' "$dockerfile" >/dev/null
grep -F 'COPY --from=builder /out/openim-service /usr/local/bin/openim-service' "$dockerfile" >/dev/null
grep -F 'COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt' "$dockerfile" >/dev/null
grep -F 'COPY --from=builder /usr/local/go/lib/time/zoneinfo.zip /usr/local/share/zoneinfo.zip' "$dockerfile" >/dev/null
grep -F 'ENV ZONEINFO=/usr/local/share/zoneinfo.zip' "$dockerfile" >/dev/null
if grep -E 'RUN .*apk add' "$dockerfile" >/dev/null; then
	echo "服务运行阶段不得联网安装系统包" >&2
	exit 1
fi
if grep -E 'COPY .*config|COPY .*_output' "$dockerfile" >/dev/null; then
	echo "服务镜像不应复制默认配置或全量构建产物" >&2
	exit 1
fi
