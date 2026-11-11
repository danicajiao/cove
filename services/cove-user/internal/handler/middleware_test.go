package handler

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

func TestUIDMiddleware_MissingHeader(t *testing.T) {
	handler := UIDMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
	// No X-Cove-Uid header set.
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rr.Code)
	}
}

func TestUIDMiddleware_EmptyHeader(t *testing.T) {
	handler := UIDMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
	req.Header.Set("X-Cove-Uid", "") // Explicitly empty.
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", rr.Code)
	}
}

func TestUIDMiddleware_ValidHeader(t *testing.T) {
	handlerCalled := false
	mw := UIDMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handlerCalled = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
	req.Header.Set("X-Cove-Uid", "user-uid-123")
	rr := httptest.NewRecorder()
	mw.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
	if !handlerCalled {
		t.Error("expected next handler to be called, but it was not")
	}
}

func TestTouchLastSeen_UpdatesAtMostOnceADay(t *testing.T) {
	var gotSQL string
	var gotArgs []any
	deps := &Deps{DB: &mockStore{execFn: func(_ context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
		gotSQL, gotArgs = sql, args
		return pgconn.NewCommandTag("UPDATE 0"), nil
	}}}
	called := false
	h := deps.TouchLastSeen(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)

	if !called || rr.Code != http.StatusOK {
		t.Fatalf("next handler not reached: called=%v code=%d", called, rr.Code)
	}
	for _, want := range []string{"SET last_seen_at = now()", "auth_uid = $1", "last_seen_at < now() - interval '1 day'"} {
		if !strings.Contains(gotSQL, want) {
			t.Errorf("query is missing %q:\n%s", want, gotSQL)
		}
	}
	if len(gotArgs) != 1 || gotArgs[0] != "uid-123" {
		t.Errorf("args = %v, want [uid-123]", gotArgs)
	}
}

func TestTouchLastSeen_DBErrorDoesNotBlockRequest(t *testing.T) {
	deps := &Deps{DB: &mockStore{execFn: func(context.Context, string, ...any) (pgconn.CommandTag, error) {
		return pgconn.CommandTag{}, errors.New("db down")
	}}}
	h := deps.TouchLastSeen(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/users/me", nil)
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
}
