#!/bin/sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
dockerfile="$root_dir/Dockerfile"

# 本机 Compose 镜像的构建与启动器必须由仓库内已锁定的 Go 依赖提供，不能临时联网安装 Mage。
grep -F 'go build -o /usr/local/bin/openim-release-runner ./build/openim-release-runner' "$dockerfile" >/dev/null
grep -F 'RELEASE=true /usr/local/bin/openim-release-runner build' "$dockerfile" >/dev/null
grep -F 'openim-release-runner start' "$dockerfile" >/dev/null
grep -F 'COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt' "$dockerfile" >/dev/null
grep -F 'COPY --from=builder /usr/local/go/lib/time/zoneinfo.zip /usr/local/share/zoneinfo.zip' "$dockerfile" >/dev/null
if grep -E 'go install github\.com/magefile/mage|mage build|mage -compile|RUN .*apk add' "$dockerfile" >/dev/null; then
	echo "运行镜像构建不得依赖网络安装构建或系统包" >&2
	exit 1
fi
