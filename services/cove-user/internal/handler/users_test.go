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

// testUserUUID is a stable UUID used as the internal user_id in all tests.
var testUserUUID = newCategoryUUID("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1")

// userUUIDRow returns a uuidRow pre-populated with testUserUUID.
// Used to mock a successful lookupUserID call.
func userUUIDRow() Row { return &uuidRow{val: testUserUUID} }

// ── GetMeHandler ──────────────────────────────────────────────────────────────

func TestGetMeHandler_UserNotFound(t *testing.T) {
	// QueryRow returns ErrNoRows → 404.
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &errRow{err: pgx.ErrNoRows}
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
	req.Header.Set("X-Cove-Uid", "uid-unknown")
	rr := httptest.NewRecorder()

	deps.GetMeHandler(rr, req)

	if rr.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rr.Code)
	}
	var body map[string]string
	_ = json.NewDecoder(rr.Body).Decode(&body)
	if body["error"] != "user profile not found" {
		t.Errorf("unexpected error: %q", body["error"])
	}
}

func TestGetMeHandler_UserFound(t *testing.T) {
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &profileRow{
					uid:                "uid-123",
					username:           "testuser",
					createdAt:          time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
					interestsOnboarded: false,
				}
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.GetMeHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
	var body map[string]any
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["uid"] != "uid-123" {
		t.Errorf("uid: got %q", body["uid"])
	}
	if body["username"] != "testuser" {
		t.Errorf("username: got %q", body["username"])
	}
	if _, hasEmail := body["email"]; hasEmail {
		t.Error("email should not be present in response")
	}
}

// ── CreateUserHandler ─────────────────────────────────────────────────────────

func TestCreateUserHandler_MissingUsername(t *testing.T) {
	deps := &Deps{DB: &mockStore{}, CommitSHA: "test"}

	req := httptest.NewRequest(http.MethodPost, "/users/me", strings.NewReader(`{"username":""}`))
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.CreateUserHandler(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rr.Code)
	}
}

func TestCreateUserHandler_Success(t *testing.T) {
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &profileRow{uid: "uid-123", username: "johndoe", createdAt: time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC), interestsOnboarded: false}
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodPost, "/users/me", strings.NewReader(`{"username":"johndoe"}`))
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.CreateUserHandler(rr, req)

	if rr.Code != http.StatusCreated {
		t.Errorf("expected 201, got %d", rr.Code)
	}
	var body map[string]any
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if body["username"] != "johndoe" {
		t.Errorf("username: got %q", body["username"])
	}
}

func TestCreateUserHandler_DuplicateUID(t *testing.T) {
	// Same Firebase user posts twice — auth_uid constraint fires → "user already exists".
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &errRow{err: &pgconn.PgError{Code: "23505", ConstraintName: "users_auth_uid_key"}}
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodPost, "/users/me", strings.NewReader(`{"username":"johndoe"}`))
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.CreateUserHandler(rr, req)

	if rr.Code != http.StatusConflict {
		t.Errorf("expected 409, got %d", rr.Code)
	}
	var body map[string]string
	_ = json.NewDecoder(rr.Body).Decode(&body)
	if body["error"] != "user already exists" {
		t.Errorf("unexpected error message: %q", body["error"])
	}
}

func TestCreateUserHandler_UsernameTaken(t *testing.T) {
	// Different user picks an already-claimed username — username constraint fires.
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &errRow{err: &pgconn.PgError{Code: "23505", ConstraintName: "users_username_key"}}
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodPost, "/users/me", strings.NewReader(`{"username":"johndoe"}`))
	req.Header.Set("X-Cove-Uid", "uid-456")
	rr := httptest.NewRecorder()

	deps.CreateUserHandler(rr, req)

	if rr.Code != http.StatusConflict {
		t.Errorf("expected 409, got %d", rr.Code)
	}
	var body map[string]string
	_ = json.NewDecoder(rr.Body).Decode(&body)
	if body["error"] != "username already taken" {
		t.Errorf("unexpected error message: %q", body["error"])
	}
}

// ── IngestActivityHandler ────────────────────────────────────────────────────────

func TestIngestActivityHandler_UserNotFound(t *testing.T) {
	// lookupUserID QueryRow returns ErrNoRows → 404.
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &errRow{err: pgx.ErrNoRows}
			},
		},
		CommitSHA: "test",
	}

	body := `{"activity_type":"item_view"}`
	req := httptest.NewRequest(http.MethodPost, "/users/me/activity", strings.NewReader(body))
	req.Header.Set("X-Cove-Uid", "uid-unknown")
	rr := httptest.NewRecorder()

	deps.IngestActivityHandler(rr, req)

	if rr.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rr.Code)
	}
}

func TestIngestActivityHandler_InvalidActivityType(t *testing.T) {
	// lookupUserID succeeds, then activity_type validation fires before any DB write.
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
		},
		CommitSHA: "test",
	}

	body := `{"activity_type":"click"}`
	req := httptest.NewRequest(http.MethodPost, "/users/me/activity", strings.NewReader(body))
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.IngestActivityHandler(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rr.Code)
	}
}

func TestIngestActivityHandler_ValidRequest(t *testing.T) {
	execCalled := false
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			execFn: func(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
				execCalled = true
				return pgconn.NewCommandTag("INSERT 1"), nil
			},
		},
		CommitSHA: "test",
	}

	body := `{"activity_type":"category_tap","category_id":"11111111-1111-1111-1111-111111111111"}`
	req := httptest.NewRequest(http.MethodPost, "/users/me/activity", strings.NewReader(body))
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.IngestActivityHandler(rr, req)

	if rr.Code != http.StatusNoContent {
		t.Errorf("expected 204, got %d", rr.Code)
	}
	if !execCalled {
		t.Error("expected Exec to be called for INSERT")
	}
}

// ── ReplaceInterestsHandler ───────────────────────────────────────────────────

func TestReplaceInterestsHandler_MalformedJSON(t *testing.T) {
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodPut, "/users/me/interests", strings.NewReader("{not json"))
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.ReplaceInterestsHandler(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rr.Code)
	}
}

func TestReplaceInterestsHandler_UserNotFound(t *testing.T) {
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &errRow{err: pgx.ErrNoRows}
			},
		},
		CommitSHA: "test",
	}

	body := `{"category_ids":["11111111-1111-1111-1111-111111111111"]}`
	req := httptest.NewRequest(http.MethodPut, "/users/me/interests", strings.NewReader(body))
	req.Header.Set("X-Cove-Uid", "uid-unknown")
	rr := httptest.NewRecorder()

	deps.ReplaceInterestsHandler(rr, req)

	if rr.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rr.Code)
	}
}

func TestReplaceInterestsHandler_EmptyCategoryIDs(t *testing.T) {
	// Empty slice (not nil) — should replace with empty set → 204.
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			beginFn: func(ctx context.Context) (pgx.Tx, error) {
				return &mockTx{}, nil
			},
		},
		CommitSHA: "test",
	}

	body := `{"category_ids":[]}`
	req := httptest.NewRequest(http.MethodPut, "/users/me/interests", strings.NewReader(body))
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.ReplaceInterestsHandler(rr, req)

	if rr.Code != http.StatusNoContent {
		t.Errorf("expected 204, got %d", rr.Code)
	}
}

func TestReplaceInterestsHandler_ValidRequest(t *testing.T) {
	execCount := 0
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			beginFn: func(ctx context.Context) (pgx.Tx, error) {
				return &mockTx{
					execFn: func(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
						execCount++
						return pgconn.NewCommandTag("OK"), nil
					},
				}, nil
			},
		},
		CommitSHA: "test",
	}

	body := `{"category_ids":["11111111-1111-1111-1111-111111111111","22222222-2222-2222-2222-222222222222"]}`
	req := httptest.NewRequest(http.MethodPut, "/users/me/interests", strings.NewReader(body))
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.ReplaceInterestsHandler(rr, req)

	if rr.Code != http.StatusNoContent {
		t.Errorf("expected 204, got %d", rr.Code)
	}
	// 1 DELETE + 2 INSERTs + 1 UPDATE (interests_onboarded) = 4 Exec calls.
	if execCount != 4 {
		t.Errorf("expected 4 Exec calls (1 DELETE + 2 INSERT + 1 UPDATE), got %d", execCount)
	}
}
