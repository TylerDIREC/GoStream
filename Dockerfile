FROM golang:1.24-bookworm AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential pkg-config libfuse3-dev ca-certificates git \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone https://github.com/MrRobotoGit/gostream.git .
ARG TARGETARCH
RUN CGO_ENABLED=1 GOOS=linux GOARCH=$TARGETARCH go build -pgo=auto -o /out/gostream .

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates fuse3 iptables tini python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out/gostream /usr/local/bin/gostream
COPY --from=build /src/scripts /app/scripts
COPY --from=build /src/requirements.txt /app/requirements.txt
RUN pip3 install --break-system-packages -r /app/requirements.txt
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENV MKV_PROXY_CONFIG_PATH=/config.json
ENV GOSTREAM_SOURCE_PATH=/mnt/gostream-mkv-real
ENV GOSTREAM_MOUNT_PATH=/mnt/gostream-mkv-virtual
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
