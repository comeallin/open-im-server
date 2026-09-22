ARG GO_IMAGE=scratch
ARG RUNTIME_IMAGE=scratch

# 全量镜像只用于本地 Compose 联调；EKS 发布使用 Dockerfile.service。
FROM ${GO_IMAGE} AS builder

# Define the base directory for the application as an environment variable
ENV SERVER_DIR=/openim-server

# Set the working directory inside the container based on the environment variable
WORKDIR $SERVER_DIR

# Set the Go proxy to improve dependency resolution speed
# ENV GOPROXY=https://goproxy.io,direct

# Copy all files from the current directory into the container
COPY . .

RUN --mount=type=cache,target=/go/pkg/mod go mod download

# 构建和启动器只依赖 go.mod 已锁定的 gomake，避免运行时临时下载 Mage。
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /usr/local/bin/openim-release-runner ./build/openim-release-runner
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    RELEASE=true /usr/local/bin/openim-release-runner build

# 运行阶段只保留 OpenIM 二进制、配置和启动器。
FROM ${RUNTIME_IMAGE}

ARG OPENIM_VERSION
ARG OPENIM_REVISION
ARG OPENIM_CONTRACT
LABEL org.opencontainers.image.source="https://github.com/comeallin/open-im-server" \
      org.opencontainers.image.version="${OPENIM_VERSION}" \
      org.opencontainers.image.revision="${OPENIM_REVISION}" \
      com.comeallin.openim.contract="${OPENIM_CONTRACT}"

# Set the environment and work directory
ENV SERVER_DIR=/openim-server
ENV ZONEINFO=/usr/local/share/zoneinfo.zip
WORKDIR $SERVER_DIR


# 复制发布模式构建的服务、工具及独立启动器。
COPY --from=builder $SERVER_DIR/_output $SERVER_DIR/_output
COPY --from=builder $SERVER_DIR/config $SERVER_DIR/config
COPY --from=builder /usr/local/bin/openim-release-runner /usr/local/bin/openim-release-runner
COPY --from=builder $SERVER_DIR/start-config.yml $SERVER_DIR/
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /usr/local/go/lib/time/zoneinfo.zip /usr/local/share/zoneinfo.zip

# OpenIM 内部依赖通过容器服务名直连，运行期不得继承镜像构建代理。
ENTRYPOINT ["sh", "-c", "unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; openim-release-runner start && tail -f /dev/null"]
