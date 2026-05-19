package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"

	firebase "firebase.google.com/go/v4"
	"github.com/go-chi/chi/v5"
	"google.golang.org/api/option"

	covauth "github.com/danicajiao/cove/apps/cove-api/internal/auth"
)

// commitSHA is set at build time via ldflags:
//
//	go build -ldflags "-X main.commitSHA=$(git rev-parse --short HEAD)" ./cmd/api/
//
// It defaults to "dev" for local builds where the flag is not supplied.
var commitSHA = "dev"

func main() {
	credPath := os.Getenv("FIREBASE_CREDENTIALS_PATH")
	if credPath == "" {
		log.Fatal("FIREBASE_CREDENTIALS_PATH environment variable is required")
	}

	ctx := context.Background()

	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credPath))
	if err != nil {
		log.Fatalf("failed to initialise Firebase app: %v", err)
	}

	authClient, err := app.Auth(ctx)
	if err != nil {
		log.Fatalf("failed to initialise Firebase Auth client: %v", err)
	}

	r := chi.NewRouter()

	// /health is unauthenticated — registered before the auth middleware group
	// so Kubernetes liveness/readiness probes and the iOS smoke test (#236) can
	// reach it without a token.
	r.Get("/health", healthHandler)

	// All other routes are protected by Firebase ID-token validation.
	r.Group(func(r chi.Router) {
		r.Use(covauth.Middleware(authClient))
		// Authenticated routes are added here in later sub-issues.
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("cove-api listening on :%s", port)
	if err := http.ListenAndServe(":"+port, r); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// healthHandler returns 200 with a JSON body identifying the service and the
// Git commit SHA of the running build.  It is intentionally unauthenticated
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
