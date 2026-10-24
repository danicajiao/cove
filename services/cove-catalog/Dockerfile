# Stage 1 — Build
# Pure Go service (no CGo). The build context is the repo root (set in CI) so
# the shared packages/imgproxy module — referenced via a replace directive in
# go.mod — is available to copy in before the build runs.
FROM golang:1.25-bookworm AS builder

WORKDIR /build

# Shared module first. The replace directive in services/cove-catalog/go.mod points
# at ../../packages/imgproxy, so it must exist on disk before `go build` resolves
# it. The container layout mirrors the repo so the relative path lines up.
COPY packages/imgproxy/ ./packages/imgproxy/

# Service module files next, so the dependency-download layer caches
# independently of service source changes.
COPY services/cove-catalog/go.mod services/cove-catalog/go.sum ./services/cove-catalog/
WORKDIR /build/services/cove-catalog
RUN go mod download

# Service source.
COPY services/cove-catalog/ ./

# COMMIT_SHA is injected by CI via --build-arg so /health reports the running commit.
ARG COMMIT_SHA=dev

# CGO_ENABLED=0 — pure Go, no C dependencies.
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags "-X main.commitSHA=${COMMIT_SHA}" \
    -o /build/cove-catalog \
    ./cmd/catalog/

# Stage 2 — Run
# gcr.io/distroless/static is suitable for pure Go binaries with no CGo.
# Smaller and lower attack surface than debian-slim.
FROM gcr.io/distroless/static-debian12

COPY --from=builder /build/cove-catalog /cove-catalog

EXPOSE 8080

ENTRYPOINT ["/cove-catalog"]
