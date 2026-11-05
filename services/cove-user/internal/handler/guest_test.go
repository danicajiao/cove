package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// guestRequest builds a request carrying the headers cove-api sets for an
// anonymous (guest) or signed-up caller.
func guestRequest(method, target, body string, guest bool) *http.Request {
	var req *http.Request
	if body == "" {
		req = httptest.NewRequest(method, target, nil)
	} else {
		req = httptest.NewRequest(method, target, strings.NewReader(body))
	}
	req.Header.Set("X-Cove-Uid", "uid-guest")
	if guest {
		req.Header.Set("X-Cove-Guest", "true")
	} else {
		req.Header.Set("X-Cove-Guest", "false")
	}
	return req
}

// ── AccountRequiredMiddleware ─────────────────────────────────────────────────

func TestAccountRequiredMiddleware(t *testing.T) {
	tests := []struct {
		name       string
		header     string // "" means the header is absent
		wantStatus int
		wantCalled bool
	}{
		{"guest is rejected", "true", http.StatusForbidden, false},
		{"signed-up user passes", "false", http.StatusOK, true},
		{"missing header passes", "", http.StatusOK, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			called := false
			mw := AccountRequiredMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				called = true
				w.WriteHeader(http.StatusOK)
			}))

			req := httptest.NewRequest(http.MethodGet, "/users/me/favorites", nil)
			req.Header.Set("X-Cove-Uid", "uid-123")
			if tt.header != "" {
				req.Header.Set("X-Cove-Guest", tt.header)
			}
			rr := httptest.NewRecorder()
			mw.ServeHTTP(rr, req)

			if rr.Code != tt.wantStatus {
				t.Errorf("status: got %d, want %d", rr.Code, tt.wantStatus)
			}
			if called != tt.wantCalled {
				t.Errorf("next handler called: got %v, want %v", called, tt.wantCalled)
			}
			if tt.wantStatus == http.StatusForbidden {
				var body map[string]string
				_ = json.NewDecoder(rr.Body).Decode(&body)
				if body["error"] != "account_required" {
					t.Errorf("error: got %q, want account_required", body["error"])
				}
			}
		})
	}
}

// ── CreateUserHandler: guests ─────────────────────────────────────────────────

func TestCreateUserHandler_GuestWithoutUsername(t *testing.T) {
	for _, body := range []string{"", `{}`, `{"username":"  "}`} {
		t.Run("body="+body, func(t *testing.T) {
			var gotUsername any = "unset"
			var gotGuest any
			deps := &Deps{
				DB: &mockStore{
					queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
						gotUsername, gotGuest = args[1], args[2]
						return &profileRow{uid: "uid-guest", createdAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), isGuest: true}
					},
				},
				CommitSHA: "test",
			}

			rr := httptest.NewRecorder()
			deps.CreateUserHandler(rr, guestRequest(http.MethodPost, "/users/me", body, true))

			if rr.Code != http.StatusCreated {
				t.Fatalf("expected 201, got %d", rr.Code)
			}
			if p, ok := gotUsername.(*string); !ok || p != nil {
				t.Errorf("username arg: got %v, want a nil *string", gotUsername)
			}
			if gotGuest != true {
				t.Errorf("is_guest arg: got %v, want true", gotGuest)
			}
			var resp map[string]any
			if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
				t.Fatalf("decode body: %v", err)
			}
			if v, present := resp["username"]; !present || v != nil {
				t.Errorf("username: got %v (present=%v), want null", v, present)
			}
			if resp["is_guest"] != true {
				t.Errorf("is_guest: got %v, want true", resp["is_guest"])
			}
		})
	}
}

func TestCreateUserHandler_NonGuestStillNeedsUsername(t *testing.T) {
	for _, body := range []string{"", `{}`} {
		t.Run("body="+body, func(t *testing.T) {
			deps := &Deps{DB: &mockStore{}, CommitSHA: "test"}

			rr := httptest.NewRecorder()
			deps.CreateUserHandler(rr, guestRequest(http.MethodPost, "/users/me", body, false))

			if rr.Code != http.StatusBadRequest {
				t.Errorf("expected 400, got %d", rr.Code)
			}
		})
	}
}

func TestCreateUserHandler_GuestMalformedJSON(t *testing.T) {
	deps := &Deps{DB: &mockStore{}, CommitSHA: "test"}

	rr := httptest.NewRecorder()
	deps.CreateUserHandler(rr, guestRequest(http.MethodPost, "/users/me", `{not json`, true))

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rr.Code)
	}
}

// ── UpdateUserHandler ─────────────────────────────────────────────────────────

func TestUpdateUserHandler_Success(t *testing.T) {
	var gotUsername, gotGuest any
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				gotUsername, gotGuest = args[1], args[2]
				return &profileRow{
					uid:                "uid-guest",
					username:           "newname",
					createdAt:          time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
					interestsOnboarded: true,
				}
			},
		},
		CommitSHA: "test",
	}

	rr := httptest.NewRecorder()
	deps.UpdateUserHandler(rr, guestRequest(http.MethodPatch, "/users/me", `{"username":" newname "}`, false))

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	if gotUsername != "newname" {
		t.Errorf("username arg: got %v, want trimmed newname", gotUsername)
	}
	if gotGuest != false {
		t.Errorf("is_guest arg: got %v, want false", gotGuest)
	}
	var resp map[string]any
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if resp["username"] != "newname" || resp["is_guest"] != false || resp["interests_onboarded"] != true {
		t.Errorf("unexpected body: %v", resp)
	}
}

func TestUpdateUserHandler_Errors(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		dbErr      error
		wantStatus int
		wantError  string
	}{
		{"blank username", `{"username":"  "}`, nil, http.StatusBadRequest, "username is required"},
		{"missing body", "", nil, http.StatusBadRequest, "username is required"},
		{"no profile", `{"username":"x"}`, pgx.ErrNoRows, http.StatusNotFound, "user profile not found"},
		{"username taken", `{"username":"x"}`, &pgconn.PgError{Code: "23505", ConstraintName: "users_username_key"}, http.StatusConflict, "username already taken"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			deps := &Deps{
				DB: &mockStore{
					queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
						return &errRow{err: tt.dbErr}
					},
				},
				CommitSHA: "test",
			}

			rr := httptest.NewRecorder()
			deps.UpdateUserHandler(rr, guestRequest(http.MethodPatch, "/users/me", tt.body, false))

			if rr.Code != tt.wantStatus {
				t.Errorf("status: got %d, want %d", rr.Code, tt.wantStatus)
			}
			var body map[string]string
			_ = json.NewDecoder(rr.Body).Decode(&body)
			if body["error"] != tt.wantError {
				t.Errorf("error: got %q, want %q", body["error"], tt.wantError)
			}
		})
	}
}

// ── is_guest sync after linking ───────────────────────────────────────────────

func TestLookupUserID_MarksLinkedGuest(t *testing.T) {
	tests := []struct {
		name        string
		storedGuest bool
		headerGuest bool
		wantUpdate  bool
	}{
		{"stored guest, request no longer a guest", true, false, true},
		{"stored guest, still a guest", true, true, false},
		{"signed-up user", false, false, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			updated := false
			deps := &Deps{
				DB: &mockStore{
					queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
						return &uuidRow{val: testUserUUID, guest: tt.storedGuest}
					},
					execFn: func(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
						if strings.Contains(sql, "SET is_guest = false") {
							updated = true
						}
						return pgconn.NewCommandTag("UPDATE 1"), nil
					},
				},
				CommitSHA: "test",
			}

			rr := httptest.NewRecorder()
			id, ok := deps.lookupUserID(guestRequest(http.MethodGet, "/users/me/interests", "", tt.headerGuest), rr, "uid-guest")

			if !ok || id == "" {
				t.Fatalf("lookupUserID failed: ok=%v id=%q status=%d", ok, id, rr.Code)
			}
			if updated != tt.wantUpdate {
				t.Errorf("is_guest update: got %v, want %v", updated, tt.wantUpdate)
			}
		})
	}
}

func TestGetMeHandler_LinkedGuestReportsNotGuest(t *testing.T) {
	updated := false
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &profileRow{uid: "uid-guest", createdAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), isGuest: true, interestsOnboarded: true}
			},
			execFn: func(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
				updated = true
				return pgconn.NewCommandTag("UPDATE 1"), nil
			},
		},
		CommitSHA: "test",
	}

	rr := httptest.NewRecorder()
	deps.GetMeHandler(rr, guestRequest(http.MethodGet, "/users/me", "", false))

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	if !updated {
		t.Error("expected is_guest to be cleared")
	}
	var resp map[string]any
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if resp["is_guest"] != false {
		t.Errorf("is_guest: got %v, want false", resp["is_guest"])
	}
	if v, present := resp["username"]; !present || v != nil {
		t.Errorf("username: got %v, want null until PATCH /users/me", v)
	}
}
