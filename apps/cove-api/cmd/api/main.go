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
	r := chi.NewRouter()

	// /health is unauthenticated and registered first, before any Firebase
	// initialisation, so it is always reachable — including during local
	// development without credentials and by Kubernetes probes during startup.
	r.Get("/health", healthHandler)

	// Initialise Firebase and wire protected routes only when credentials are
	// provided.  Without FIREBASE_CREDENTIALS_PATH the server still starts and
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

		// All routes except /health are protected by Firebase ID-token validation.
		r.Group(func(r chi.Router) {
			r.Use(covauth.Middleware(authClient))
			// Authenticated routes are added here in later sub-issues.
		})

		log.Println("Firebase Auth initialised — protected routes active")
	} else {
		log.Println("FIREBASE_CREDENTIALS_PATH not set — protected routes disabled (local dev mode)")
	}

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
