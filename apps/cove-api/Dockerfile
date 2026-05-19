# Stage 1 — Build
# Compiles the Go binary inside a full Go toolchain image.
# Nothing from this stage ships in the final image.
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Download dependencies first so this layer is cached between builds
# that only change source files.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# COMMIT_SHA is injected by CI via --build-arg so the /health endpoint
# can report the exact Git commit that is running.
ARG COMMIT_SHA=dev

RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags "-X main.commitSHA=${COMMIT_SHA}" \
    -o cove-api \
    ./cmd/api/

# Stage 2 — Run
# Distroless has no shell, no package manager, and no OS tools —
# only the binary and the C library it needs. Attack surface is minimal.
FROM gcr.io/distroless/static-debian12

COPY --from=builder /build/cove-api /cove-api

EXPOSE 8080

ENTRYPOINT ["/cove-api"]
