package handler

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// The ranking itself (selected first, rollup to level 1, 30-day window) lives
// in shelfSQL and needs a real Postgres to exercise. These tests cover the
// handler around it: bind arguments, pass-through order and error handling.

// shelfRows returns three level 1 categories in a fixed order.
func shelfRows() *categoryRows {
	return &categoryRows{rows: []categoryRow{
		{id: newCategoryUUID("11111111111111111111111111111111"), name: "Music", path: "music"},
		{id: newCategoryUUID("22222222222222222222222222222222"), name: "Food", path: "food"},
		{id: newCategoryUUID("33333333333333333333333333333333"), name: "Art", path: "art"},
	}}
}

func serveRecommendations(t *testing.T, deps *Deps, query string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories"+query, nil)
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()
	deps.RecommendedCategoriesHandler(rr, req)
	return rr
}

func TestRecommendedCategoriesHandler_WithProfile(t *testing.T) {
	// The user's ID is bound so their interests and engagement rank first, and
	// rows come back in the order the query returns them.
	var gotUserID any
	queryCalls := 0
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				queryCalls++
				gotUserID = args[0]
				return shelfRows(), nil
			},
		},
		CommitSHA: "test",
	}

	rr := serveRecommendations(t, deps, "")
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}

	p, ok := gotUserID.(*string)
	if !ok || p == nil || *p != formatUUID(testUserUUID) {
		t.Errorf("expected user ID %q bound, got %#v", formatUUID(testUserUUID), gotUserID)
	}
	if queryCalls != 1 {
		t.Errorf("expected 1 query call, got %d", queryCalls)
	}

	var body recommendedCategoriesResponse
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	var paths []string
	for _, c := range body.Categories {
		paths = append(paths, c.Path)
	}
	if got := strings.Join(paths, ","); got != "music,food,art" {
		t.Errorf("expected query order music,food,art, got %s", got)
	}
}

func TestRecommendedCategoriesHandler_NoProfile(t *testing.T) {
	// No profile (ErrNoRows) → NULL user ID, so the query falls back to the
	// global order. Still one query, still 200.
	var gotUserID any = "unset"
	deps := &Deps{
		DB: &mockStore{
			// No queryRowFn — default returns errRow{pgx.ErrNoRows} → no profile.
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				gotUserID = args[0]
				return shelfRows(), nil
			},
		},
		CommitSHA: "test",
	}

	rr := serveRecommendations(t, deps, "")
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	if p, ok := gotUserID.(*string); !ok || p != nil {
		t.Errorf("expected nil user ID for a user without a profile, got %#v", gotUserID)
	}

	var body recommendedCategoriesResponse
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(body.Categories) != 3 {
		t.Errorf("expected 3 categories, got %d", len(body.Categories))
	}
}

func TestRecommendedCategoriesHandler_LookupError(t *testing.T) {
	// A user lookup failure other than "not found" is a 500, not a silent fallback.
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return &errRow{err: errors.New("connection reset")}
			},
		},
		CommitSHA: "test",
	}

	if rr := serveRecommendations(t, deps, ""); rr.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", rr.Code)
	}
}

func TestRecommendedCategoriesHandler_QueryError(t *testing.T) {
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				return nil, errors.New("boom")
			},
		},
		CommitSHA: "test",
	}

	if rr := serveRecommendations(t, deps, ""); rr.Code != http.StatusInternalServerError {
		t.Errorf("expected 500, got %d", rr.Code)
	}
}

func TestRecommendedCategoriesHandler_Empty(t *testing.T) {
	// No categories → 200 with an empty list, not null.
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
		},
		CommitSHA: "test",
	}

	rr := serveRecommendations(t, deps, "")
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
	if got := strings.TrimSpace(rr.Body.String()); got != `{"categories":[]}` {
		t.Errorf("expected empty list, got %s", got)
	}
}

func TestRecommendedCategoriesHandler_LevelOneOnly(t *testing.T) {
	// Guard the query's contract: level 1 only, with engagement rolled up to the
	// level 1 ancestor and item activity counted through the item's category.
	var gotSQL string
	deps := &Deps{
		DB: &mockStore{
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				gotSQL = sql
				return &emptyRows{}, nil
			},
		},
		CommitSHA: "test",
	}

	serveRecommendations(t, deps, "")
	for _, want := range []string{
		"nlevel(c.path) = 1",
		"subpath(c.path, 0, 1)",
		"COALESCE(e.category_id, it.category_id)",
		"interval '30 days'",
	} {
		if !strings.Contains(gotSQL, want) {
			t.Errorf("query missing %q", want)
		}
	}
}

func TestRecommendedCategoriesHandler_LimitForwarded(t *testing.T) {
	// ?limit=5 is parsed and bound as the LIMIT argument.
	var gotLimit any
	deps := &Deps{
		DB: &mockStore{
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				gotLimit = args[1]
				return &emptyRows{}, nil
			},
		},
		CommitSHA: "test",
	}

	serveRecommendations(t, deps, "?limit=5")
	if gotLimit != 5 {
		t.Errorf("expected limit 5 forwarded to query, got %v", gotLimit)
	}
}

func TestRecommendedCategoriesHandler_InvalidLimitFallsBackToDefault(t *testing.T) {
	// A non-numeric / out-of-range limit is ignored in favor of the default.
	var gotLimit any
	deps := &Deps{
		DB: &mockStore{
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				gotLimit = args[1]
				return &emptyRows{}, nil
			},
		},
		CommitSHA: "test",
	}

	serveRecommendations(t, deps, "?limit=banana")
	if gotLimit != defaultCategoryLimit {
		t.Errorf("expected default limit %d, got %v", defaultCategoryLimit, gotLimit)
	}
}

func TestRecommendedCategoriesHandler_ImageKey(t *testing.T) {
	// image_key is passed through when set and omitted from the JSON when NULL.
	key := "images/categories/card/food.jpg"
	deps := &Deps{
		DB: &mockStore{
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				return &categoryRows{rows: []categoryRow{
					{id: newCategoryUUID("11111111111111111111111111111111"), name: "Food", path: "food", imageKey: &key},
					{id: newCategoryUUID("22222222222222222222222222222222"), name: "Art", path: "art"},
				}}, nil
			},
		},
		CommitSHA: "test",
	}

	rr := serveRecommendations(t, deps, "")
	var body struct {
		Categories []map[string]any `json:"categories"`
	}
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(body.Categories) != 2 {
		t.Fatalf("expected 2 categories, got %d", len(body.Categories))
	}
	if got := body.Categories[0]["image_key"]; got != key {
		t.Errorf("first category image_key: got %v, want %q", got, key)
	}
	if _, ok := body.Categories[1]["image_key"]; ok {
		t.Errorf("second category: expected image_key to be omitted when NULL")
	}
}
