#!/bin/sh
set -eu

root_dir="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
release_file="${OPENIM_RELEASE_FILE:-$root_dir/../be-message/deploy/openim-release.env}"

services='openim-api
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

list_services() {
	printf '%s\n' "$services"
}

require_service() {
	service="$1"
	if ! list_services | grep -Fx "$service" >/dev/null; then
		echo "不支持的 OpenIM 服务: $service" >&2
		exit 2
	fi
}

load_release() {
	if [ ! -f "$release_file" ]; then
		echo "缺少 OpenIM 发布身份文件: $release_file" >&2
		exit 2
	fi
	# 发布版本、提交和契约只从部署仓库的唯一事实源读取。
	# shellcheck disable=SC1090
	. "$release_file"
	: "${OPENIM_RELEASE:?}"
	: "${OPENIM_SOURCE_REVISION:?}"
	: "${OPENIM_CONTRACT:?}"
}

build_service() {
	service="$1"
	image="$2"
	require_service "$service"
	load_release

	docker build \
		--file "$root_dir/Dockerfile.service" \
		--platform "${OPENIM_PLATFORM:-linux/amd64}" \
		--build-arg "GO_IMAGE=$OPENIM_GO_IMAGE" \
		--build-arg "RUNTIME_IMAGE=$OPENIM_RUNTIME_IMAGE" \
		--build-arg HTTP_PROXY \
		--build-arg HTTPS_PROXY \
		--build-arg ALL_PROXY \
		--build-arg NO_PROXY \
		--build-arg "OPENIM_SERVICE=$service" \
		--build-arg "OPENIM_VERSION=$OPENIM_RELEASE" \
		--build-arg "OPENIM_REVISION=$OPENIM_SOURCE_REVISION" \
		--build-arg "OPENIM_CONTRACT=$OPENIM_CONTRACT" \
		--tag "$image" \
		"$root_dir"
}

command="${1:-}"
case "$command" in
	list)
		list_services
		;;
	build)
		[ "$#" -eq 3 ] || {
			echo "用法: $0 build <service> <image>" >&2
			exit 2
		}
		build_service "$2" "$3"
		;;
	build-all)
		[ "$#" -eq 2 ] || {
			echo "用法: $0 build-all <registry-prefix>" >&2
			exit 2
		}
		load_release
		for service in $services; do
			build_service "$service" "$2/$service:$OPENIM_RELEASE"
		done
		;;
	*)
		echo "用法: $0 list|build|build-all" >&2
		exit 2
		;;
esac
