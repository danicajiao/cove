# Stage 1 — Build
# govips requires CGo (libvips C bindings), so we use a Debian-based Go image
# and install the libvips development headers.
#
# The build context is the repo root (set in CI) so the shared packages/imgproxy
# module — referenced via a replace directive in go.mod — is available to copy
# in before the build runs.
FROM golang:1.25-bookworm AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends libvips-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Shared module first. The replace directive in services/cove-media/go.mod
# points at ../../packages/imgproxy, so it must exist on disk before `go build`
# resolves it. The container layout mirrors the repo so the relative path lines up.
COPY packages/imgproxy/ ./packages/imgproxy/

# Service module files next, so the dependency-download layer caches
# independently of service source changes.
COPY services/cove-media/go.mod services/cove-media/go.sum ./services/cove-media/
WORKDIR /build/services/cove-media
RUN go mod download

# Service source.
COPY services/cove-media/ ./

# COMMIT_SHA is injected by CI via --build-arg so /health reports the running commit.
ARG COMMIT_SHA=dev

# CGO_ENABLED=1 is required — govips links against the libvips C library.
RUN CGO_ENABLED=1 GOOS=linux go build \
    -ldflags "-X main.commitSHA=${COMMIT_SHA}" \
    -o /build/cove-media \
    ./cmd/media/

# Stage 2 — Run
# debian:bookworm-slim + libvips42 (runtime only, no dev headers or compiler).
# The binary links against libvips at runtime so we must include the shared
# library — gcr.io/distroless/static is not suitable for CGo binaries.
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends libvips42 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/cove-media /cove-media

EXPOSE 8080

ENTRYPOINT ["/cove-media"]
