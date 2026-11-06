package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	firebaseauth "firebase.google.com/go/v4/auth"

	covauth "github.com/danicajiao/cove/services/cove-api/internal/auth"
)

type stubVerifier struct{ provider string }

func (s stubVerifier) VerifyIDToken(_ context.Context, _ string) (*firebaseauth.Token, error) {
	return &firebaseauth.Token{UID: "uid-1", Firebase: firebaseauth.FirebaseInfo{SignInProvider: s.provider}}, nil
}

// TestUIDProxy_ForwardsIdentityHeaders sends requests through the auth
// middleware and uidProxy to a real upstream, and checks the identity headers
// the upstream receives.
func TestUIDProxy_ForwardsIdentityHeaders(t *testing.T) {
	tests := []struct {
		name       string
		provider   string
		spoofGuest string
		wantGuest  string
	}{
		{"anonymous", "anonymous", "", "true"},
		{"signed up", "password", "", "false"},
		{"guest spoofs false", "anonymous", "false", "true"},
		{"user spoofs true", "google.com", "true", "false"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got http.Header
			upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				got = r.Header.Clone()
				w.WriteHeader(http.StatusOK)
			}))
			defer upstream.Close()

			handler := covauth.Middleware(stubVerifier{provider: tt.provider})(uidProxy("test", upstream.URL))

			req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
			req.Header.Set("Authorization", "Bearer token")
			req.Header.Set("X-Cove-Uid", "someone-else")
			if tt.spoofGuest != "" {
				req.Header.Set("X-Cove-Guest", tt.spoofGuest)
			}
			rr := httptest.NewRecorder()
			handler.ServeHTTP(rr, req)

			if rr.Code != http.StatusOK {
				t.Fatalf("status: got %d, want 200", rr.Code)
			}
			if v := got.Values("X-Cove-Uid"); len(v) != 1 || v[0] != "uid-1" {
				t.Errorf("X-Cove-Uid upstream: got %v, want [uid-1]", v)
			}
			if v := got.Values("X-Cove-Guest"); len(v) != 1 || v[0] != tt.wantGuest {
				t.Errorf("X-Cove-Guest upstream: got %v, want [%s]", v, tt.wantGuest)
			}
		})
	}
}
