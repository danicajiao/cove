package auth_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	firebaseauth "firebase.google.com/go/v4/auth"

	"github.com/danicajiao/cove/services/cove-api/internal/auth"
)

// tokenFor returns a verified token for uid signed in with provider.
func tokenFor(uid, provider string) *firebaseauth.Token {
	return &firebaseauth.Token{
		UID:      uid,
		Firebase: firebaseauth.FirebaseInfo{SignInProvider: provider},
	}
}

func TestMiddleware_GuestStatusFromSignInProvider(t *testing.T) {
	tests := []struct {
		provider  string
		wantGuest bool
	}{
		{"anonymous", true},
		{"password", false},
		{"google.com", false},
		{"facebook.com", false},
		{"", false},
	}
	for _, tt := range tests {
		t.Run("provider="+tt.provider, func(t *testing.T) {
			var gotGuest bool
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				gotGuest = auth.IsGuestFromContext(r.Context())
			})
			handler := auth.Middleware(&mockVerifier{token: tokenFor("uid-1", tt.provider)})(next)

			req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
			req.Header.Set("Authorization", "Bearer token")
			handler.ServeHTTP(httptest.NewRecorder(), req)

			if gotGuest != tt.wantGuest {
				t.Errorf("IsGuestFromContext: got %v, want %v", gotGuest, tt.wantGuest)
			}
		})
	}
}

func TestIsGuestFromContext_Unauthenticated(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	if auth.IsGuestFromContext(req.Context()) {
		t.Error("expected false for a request that never passed Middleware")
	}
}

func TestSetIdentityHeaders(t *testing.T) {
	tests := []struct {
		name       string
		provider   string
		spoofUID   string
		spoofGuest string
		wantUID    string
		wantGuest  string
	}{
		{"anonymous token", "anonymous", "", "", "uid-1", "true"},
		{"signed-up token", "password", "", "", "uid-1", "false"},
		{"guest spoofs not-guest", "anonymous", "", "false", "uid-1", "true"},
		{"user spoofs guest", "google.com", "", "true", "uid-1", "false"},
		{"spoofed uid", "password", "someone-else", "", "uid-1", "false"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got http.Header
			next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				auth.SetIdentityHeaders(r)
				got = r.Header.Clone()
			})
			handler := auth.Middleware(&mockVerifier{token: tokenFor("uid-1", tt.provider)})(next)

			req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
			req.Header.Set("Authorization", "Bearer token")
			if tt.spoofUID != "" {
				req.Header.Set(auth.HeaderUID, tt.spoofUID)
			}
			if tt.spoofGuest != "" {
				req.Header.Set(auth.HeaderGuest, tt.spoofGuest)
			}
			handler.ServeHTTP(httptest.NewRecorder(), req)

			if v := got.Values(auth.HeaderUID); len(v) != 1 || v[0] != tt.wantUID {
				t.Errorf("%s: got %v, want [%s]", auth.HeaderUID, v, tt.wantUID)
			}
			if v := got.Values(auth.HeaderGuest); len(v) != 1 || v[0] != tt.wantGuest {
				t.Errorf("%s: got %v, want [%s]", auth.HeaderGuest, v, tt.wantGuest)
			}
		})
	}
}

func TestSetIdentityHeaders_UnauthenticatedStripsClientHeaders(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set(auth.HeaderUID, "someone-else")
	req.Header.Set(auth.HeaderGuest, "false")

	auth.SetIdentityHeaders(req)

	if v := req.Header.Get(auth.HeaderUID); v != "" {
		t.Errorf("%s: got %q, want it removed", auth.HeaderUID, v)
	}
	if v := req.Header.Get(auth.HeaderGuest); v != "" {
		t.Errorf("%s: got %q, want it removed", auth.HeaderGuest, v)
	}
}
