package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/davidbyttow/govips/v2/vips"
	"github.com/go-chi/chi/v5"

	"github.com/danicajiao/cove/packages/imgproxy"
	"github.com/danicajiao/cove/services/cove-media/internal/normalize"
	"github.com/danicajiao/cove/services/cove-media/internal/storage"
)

// commitSHA is set at build time via ldflags:
//
//	go build -ldflags "-X main.commitSHA=$(git rev-parse --short HEAD)" ./cmd/media/
//
// It defaults to "dev" for local builds where the flag is not supplied.
var commitSHA = "dev"

// defaultMaxUploadBytes is 10 MiB.
const defaultMaxUploadBytes = 10 * 1024 * 1024

// maxDimension caps the w/h query params on the image URL endpoint to prevent
// clients from requesting unreasonably large transforms.
const maxDimension = 4096

// allowedContentTypes is the set of MIME types accepted by the upload endpoint.
// HEIC is intentionally omitted — it requires libheif which is a heavier
// dependency. iOS vendors can export JPEG via UIImageWriteToSavedPhotosAlbum
// or AVAssetExportSession before uploading.
var allowedContentTypes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/webp": true,
}

func main() {
	// Initialise libvips once for the lifetime of the process. govips is
	// goroutine-safe after Startup; all HTTP handlers can call normalize.Image
	// concurrently without additional locking.
	vips.Startup(nil)
	defer vips.Shutdown()

	ctx := context.Background()

	garage, err := storage.NewGarageClient(ctx)
	if err != nil {
		log.Fatalf("failed to initialise Garage client: %v", err)
	}

	maxBytes := int64(defaultMaxUploadBytes)
	if v := os.Getenv("MAX_UPLOAD_BYTES"); v != "" {
		parsed, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			log.Fatalf("invalid MAX_UPLOAD_BYTES %q: %v", v, err)
		}
		maxBytes = parsed
	}

	// imgproxy signing — required for GET /images/{filename}/url.
	// IMGPROXY_KEY and IMGPROXY_SALT are injected by the ExternalSecret in
	// the homelab manifests. IMGPROXY_BASE_URL is the public-facing URL prefix
	// that clients use to reach imgproxy (via the cove-api /i/* proxy, e.g.
	// "https://api.coveapp.dev/i" or "https://staging-api.coveapp.dev/i").
	imgproxyKey := os.Getenv("IMGPROXY_KEY")
	imgproxySalt := os.Getenv("IMGPROXY_SALT")
	imgproxyBaseURL := os.Getenv("IMGPROXY_BASE_URL")
	if imgproxyKey == "" || imgproxySalt == "" || imgproxyBaseURL == "" {
		log.Fatal("IMGPROXY_KEY, IMGPROXY_SALT, and IMGPROXY_BASE_URL must all be set")
	}

	imgproxyBucket := os.Getenv("IMGPROXY_BUCKET")
	if imgproxyBucket == "" {
		imgproxyBucket = "cove-media"
	}

	imgproxyTTL := time.Hour
	if v := os.Getenv("IMGPROXY_URL_TTL"); v != "" {
		secs, err := strconv.ParseInt(v, 10, 64)
		if err != nil || secs <= 0 {
			log.Fatalf("invalid IMGPROXY_URL_TTL %q: must be a positive integer (seconds)", v)
		}
		imgproxyTTL = time.Duration(secs) * time.Second
	}

	signer, err := imgproxy.NewSigner(imgproxyKey, imgproxySalt, imgproxyBaseURL, imgproxyBucket, imgproxyTTL)
	if err != nil {
		log.Fatalf("failed to initialise imgproxy signer: %v", err)
	}

	r := chi.NewRouter()

	// /health is unauthenticated — used by Kubernetes probes.
	r.Get("/health", healthHandler)

	// All other routes require X-Cove-Uid (injected by cove-api upstream).
	r.Group(func(r chi.Router) {
		r.Use(uidMiddleware)
		r.Post("/images", uploadHandler(garage, maxBytes))
		r.Get("/images/{filename}/url", imageURLHandler(signer))
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("cove-media listening on :%s", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// uidMiddleware rejects requests that do not carry a non-empty X-Cove-Uid
// header with 401 Unauthorized.  cove-media does NOT validate Firebase tokens
// itself — it trusts the UID injected by the upstream cove-api gateway.
func uidMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		uid := r.Header.Get("X-Cove-Uid")
		if uid == "" {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
			return
		}
		next.ServeHTTP(w, r)
	})
}

// uploadResponse is the JSON body returned on a successful upload.
// Width and Height are the source image dimensions after normalization and
// auto-rotation — callers should store these alongside the key for use as
// layout hints (e.g. in product.media rows) to avoid a decode round-trip.
type uploadResponse struct {
	Key    string `json:"key"`
	Width  int    `json:"width"`
	Height int    `json:"height"`
}

// uploadHandler returns an http.HandlerFunc that:
//  1. Parses the multipart/form-data body
//  2. Validates content type (jpeg, png, webp) and size
//  3. Runs the normalization pipeline (auto-rotate, strip EXIF, re-encode as WebP)
//  4. Derives a content-addressed key from the SHA-256 of the normalized bytes
//  5. Writes the normalized WebP to Garage
//  6. Returns 201 with {key, width, height}
func uploadHandler(garage *storage.GarageClient, maxBytes int64) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Limit total body size before parsing the multipart form.
		r.Body = http.MaxBytesReader(w, r.Body, maxBytes+1024) // +1 KiB for field overhead

		if err := r.ParseMultipartForm(maxBytes); err != nil {
			writeJSON(w, http.StatusRequestEntityTooLarge, map[string]string{
				"error": fmt.Sprintf("request body too large or malformed: %v", err),
			})
			return
		}

		file, header, err := r.FormFile("file")
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing or invalid 'file' field"})
			return
		}
		defer file.Close()

		// Read entire file into memory so we can detect content type, normalize
		// it, and know its exact size. maxBytes is enforced by MaxBytesReader
		// above, so this is bounded.
		data, err := io.ReadAll(file)
		if err != nil {
			writeJSON(w, http.StatusRequestEntityTooLarge, map[string]string{"error": "file exceeds maximum allowed size"})
			return
		}

		if int64(len(data)) > maxBytes {
			writeJSON(w, http.StatusRequestEntityTooLarge, map[string]string{
				"error": fmt.Sprintf("file size %d exceeds limit of %d bytes", len(data), maxBytes),
			})
			return
		}

		// Determine content type: prefer the part's Content-Type header, fall
		// back to sniffing the first 512 bytes of the file data.
		contentType := header.Header.Get("Content-Type")
		if contentType == "" {
			probe := data
			if len(probe) > 512 {
				probe = probe[:512]
			}
			contentType = http.DetectContentType(probe)
		}

		if !allowedContentTypes[contentType] {
			writeJSON(w, http.StatusUnsupportedMediaType, map[string]string{
				"error": fmt.Sprintf("unsupported content type %q; accepted: image/jpeg, image/png, image/webp", contentType),
			})
			return
		}

		// Normalize: auto-rotate from EXIF, strip metadata (GPS, camera info),
		// re-encode as WebP quality 90, derive a content-addressed key.
		result, err := normalize.Image(data)
		if err != nil {
			log.Printf("ERROR: normalize key=%q: %v", contentType, err)
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": fmt.Sprintf("could not process image: %v", err),
			})
			return
		}

		if err := garage.PutObject(r.Context(), result.Key, "image/webp", bytes.NewReader(result.Data), int64(len(result.Data))); err != nil {
			log.Printf("ERROR: PutObject key=%q: %v", result.Key, err)
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to store image"})
			return
		}

		writeJSON(w, http.StatusCreated, uploadResponse{
			Key:    result.Key,
			Width:  result.Width,
			Height: result.Height,
		})
	}
}

// imageURLResponse is the JSON body returned by GET /images/{filename}/url.
type imageURLResponse struct {
	URL       string `json:"url"`
	ExpiresAt string `json:"expires_at"` // RFC 3339
}

// imageURLHandler returns a signed imgproxy URL for the requested image and
// resize parameters. The client follows the URL directly — cove-media is not
// in the image bytes' hot path.
//
// Route: GET /images/{filename}/url
//
// Query params:
//   - w   (required) — output width in pixels (1–4096)
//   - h   (required) — output height in pixels (1–4096)
//   - fit (optional, default "cover") — "cover" (fill+crop) or "contain" (fit+letterbox)
//
// The signed URL embeds an exp: processing option so imgproxy rejects requests
// after ExpiresAt. The default TTL is 1 hour (configurable via IMGPROXY_URL_TTL).
func imageURLHandler(signer *imgproxy.Signer) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		filename := chi.URLParam(r, "filename")
		if filename == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing image filename"})
			return
		}
		// Reconstruct the full object key from the route segment. The upload
		// endpoint stores objects under the "images/" prefix, so the key is
		// always "images/<filename>".
		objectKey := "images/" + filename

		q := r.URL.Query()
		wStr := q.Get("w")
		hStr := q.Get("h")
		if wStr == "" || hStr == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "w and h query params are required"})
			return
		}

		width, err := strconv.Atoi(wStr)
		if err != nil || width <= 0 || width > maxDimension {
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": fmt.Sprintf("w must be an integer between 1 and %d", maxDimension),
			})
			return
		}
		height, err := strconv.Atoi(hStr)
		if err != nil || height <= 0 || height > maxDimension {
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": fmt.Sprintf("h must be an integer between 1 and %d", maxDimension),
			})
			return
		}

		fit := imgproxy.ParseFit(q.Get("fit"))
		result := signer.Sign(objectKey, width, height, fit)

		writeJSON(w, http.StatusOK, imageURLResponse{
			URL:       result.URL,
			ExpiresAt: result.ExpiresAt.UTC().Format(time.RFC3339),
		})
	}
}

// healthHandler returns 200 with a JSON body identifying the service and Git commit SHA.
func healthHandler(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"service": "cove-media",
		"status":  "ok",
		"commit":  commitSHA,
	})
}

// writeJSON writes a JSON-encoded body with the given HTTP status code.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
