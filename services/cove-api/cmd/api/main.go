package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"

	firebase "firebase.google.com/go/v4"
	"github.com/go-chi/chi/v5"
	"google.golang.org/api/option"

	covauth "github.com/danicajiao/cove/services/cove-api/internal/auth"
)

// commitSHA is set at build time via ldflags:
//
//	go build -ldflags "-X main.commitSHA=$(git rev-parse --short HEAD)" ./cmd/api/
//
// It defaults to "dev" for local builds where the flag is not supplied.
var commitSHA = "dev"

func main() {
	r := chi.NewRouter()

	// /health is unauthenticated and registered first, before any Firebase
	// initialisation, so it is always reachable — including during local
	// development without credentials and by Kubernetes probes during startup.
	r.Get("/health", healthHandler)

	// /i/* proxies to imgproxy unauthenticated — imgproxy validates its own
	// HMAC-SHA256 URL signature, so a Firebase token is not required here.
	// This allows Cloudflare to cache image responses without needing a token.
	imgproxyURL := envOr("IMGPROXY_URL", "http://imgproxy:8080")
	r.Handle("/i/*", imgproxyHandler(imgproxyURL))

	// Initialise Firebase and wire protected routes only when credentials are
	// provided. Without FIREBASE_CREDENTIALS_PATH the server still starts and
	// /health works; all other routes return 401.
	credPath := os.Getenv("FIREBASE_CREDENTIALS_PATH")
	if credPath != "" {
		ctx := context.Background()

		app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credPath))
		if err != nil {
			log.Fatalf("failed to initialise Firebase app: %v", err)
		}

		authClient, err := app.Auth(ctx)
		if err != nil {
			log.Fatalf("failed to initialise Firebase Auth client: %v", err)
		}

		// Internal service URLs — default to the in-cluster Service names,
		// which resolve within the same Kubernetes namespace without a full
		// DNS path (e.g. http://cove-catalog:8080 resolves to
		// cove-catalog.cove-staging.svc.cluster.local in staging).
		coveMediaURL := envOr("COVE_MEDIA_URL", "http://cove-media:8080")
		coveCatalogURL := envOr("COVE_CATALOG_URL", "http://cove-catalog:8080")
		coveDirectoryURL := envOr("COVE_DIRECTORY_URL", "http://cove-directory:8080")
		coveUserURL := envOr("COVE_USER_URL", "http://cove-user:8080")

		// All routes except /health and /i/* are protected by Firebase
		// ID-token validation. The verified UID is injected as X-Cove-Uid so
		// downstream services can trust the identity without re-validating
		// the token themselves.
		r.Group(func(r chi.Router) {
			r.Use(covauth.Middleware(authClient))

			// cove-media: image uploads and signed imgproxy URL generation.
			mediaHandler := uidProxy("cove-media", coveMediaURL)
			r.Handle("/images", mediaHandler)
			r.Handle("/images/*", mediaHandler)

			// cove-catalog: discovery, category tree, item detail.
			catalogHandler := uidProxy("cove-catalog", coveCatalogURL)
			r.Handle("/discovery", catalogHandler)
			r.Handle("/categories", catalogHandler)
			r.Handle("/items/*", catalogHandler)

			// cove-directory: producer and place detail.
			directoryHandler := uidProxy("cove-directory", coveDirectoryURL)
			r.Handle("/producers/*", directoryHandler)
			r.Handle("/places/*", directoryHandler)

			// cove-user: profile, favorites, follows, interests, activity,
			// and personalized category recommendations.
			userHandler := uidProxy("cove-user", coveUserURL)
			r.Handle("/users/*", userHandler)
			r.Handle("/recommendations/*", userHandler)
		})

		log.Println("Firebase Auth initialised — protected routes active")
	} else {
		log.Println("FIREBASE_CREDENTIALS_PATH not set — protected routes disabled (local dev mode)")
	}

	port := envOr("PORT", "8080")

	log.Printf("cove-api listening on :%s", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// envOr returns the value of the named environment variable, or def if it
// is unset or empty.
func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// uidProxy returns an http.Handler that reverse-proxies all requests to the
// given upstream URL, injecting the verified Firebase UID as X-Cove-Uid so
// the upstream service can trust the identity without re-validating the token.
func uidProxy(name, targetURL string) http.Handler {
	target, err := url.Parse(targetURL)
	if err != nil {
		log.Fatalf("invalid upstream URL for %s %q: %v", name, targetURL, err)
	}
	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("ERROR: %s proxy: %v", name, err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadGateway)
		_, _ = w.Write([]byte(`{"error":"upstream service unavailable"}`))
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if uid, ok := covauth.UIDFromContext(r.Context()); ok {
			r.Header.Set("X-Cove-Uid", uid)
		}
		proxy.ServeHTTP(w, r)
	})
}

// imgproxyHandler returns a reverse proxy handler for imgproxy.
//
// The /i prefix is stripped before forwarding so imgproxy receives the path
// in its expected form: /<signature>/<processing_options>/plain/<source>.
// imgproxy validates its own HMAC-SHA256 URL signature — no Firebase token
// is required at this layer.
func imgproxyHandler(targetURL string) http.Handler {
	target, err := url.Parse(targetURL)
	if err != nil {
		log.Fatalf("invalid IMGPROXY_URL %q: %v", targetURL, err)
	}
	proxy := httputil.NewSingleHostReverseProxy(target)
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("ERROR: imgproxy proxy: %v", err)
		w.WriteHeader(http.StatusBadGateway)
	}
	// Strip /i so imgproxy sees /<sig>/... rather than /i/<sig>/...
	return http.StripPrefix("/i", proxy)
}

// healthHandler returns 200 with a JSON body identifying the service and the
// Git commit SHA of the running build. It is intentionally unauthenticated
// so Kubernetes liveness/readiness probes and the iOS smoke test can reach it
// without a token.
func healthHandler(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]string{
		"service": "cove-api",
		"status":  "ok",
		"commit":  commitSHA,
	})
}
