package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRecommendedCategoriesHandler_WithInterests(t *testing.T) {
	// QueryRow: user lookup returns a UUID.
	// Query (1st call): interest-based returns two categories that exactly fill
	// limit=2 → no fallback top-up needed.
	catID1 := newCategoryUUID("11111111111111111111111111111111")
	catID2 := newCategoryUUID("22222222222222222222222222222222")

	queryCalls := 0
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow() // lookupUserID succeeds
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				queryCalls++
				if queryCalls == 1 {
					return &categoryRows{rows: []categoryRow{
						{id: catID1, name: "Coffee", path: "food.coffee"},
						{id: catID2, name: "Tea", path: "food.tea"},
					}}, nil
				}
				// Second query should not be called when interests fill the limit.
				return &emptyRows{}, nil
			},
		},
		CommitSHA: "test",
	}

	// limit=2 so the two interest categories exactly fill the limit → no top-up.
	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories?limit=2", nil)
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.RecommendedCategoriesHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}

	var body recommendedCategoriesResponse
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(body.Categories) != 2 {
		t.Errorf("expected 2 categories, got %d", len(body.Categories))
	}
	if body.Categories[0].Name != "Coffee" {
		t.Errorf("first category name: got %q, want %q", body.Categories[0].Name, "Coffee")
	}
	if body.Categories[0].Path != "food.coffee" {
		t.Errorf("first category path: got %q, want %q", body.Categories[0].Path, "food.coffee")
	}
	if queryCalls != 1 {
		t.Errorf("expected only the interest query to run, got %d query calls", queryCalls)
	}
}

func TestRecommendedCategoriesHandler_FallbackNoInterests(t *testing.T) {
	// QueryRow: user exists. Query (1st): no interests. Query (2nd): fallback categories.
	catID := newCategoryUUID("33333333333333333333333333333333")

	queryCalls := 0
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow() // user has a profile but no interests
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				queryCalls++
				if queryCalls == 1 {
					// No interests.
					return &emptyRows{}, nil
				}
				// Fallback global categories.
				return &categoryRows{rows: []categoryRow{
					{id: catID, name: "Pottery", path: "crafts.pottery"},
				}}, nil
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories", nil)
	req.Header.Set("X-Cove-Uid", "uid-no-interests")
	rr := httptest.NewRecorder()

	deps.RecommendedCategoriesHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}

	var body recommendedCategoriesResponse
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(body.Categories) != 1 {
		t.Errorf("expected 1 fallback category, got %d", len(body.Categories))
	}
	if body.Categories[0].Name != "Pottery" {
		t.Errorf("category name: got %q, want %q", body.Categories[0].Name, "Pottery")
	}
	if queryCalls != 2 {
		t.Errorf("expected 2 query calls (interest + fallback), got %d", queryCalls)
	}
}

func TestRecommendedCategoriesHandler_NoProfile(t *testing.T) {
	// QueryRow: user has no profile (ErrNoRows) → skip interest query, go to fallback.
	catID := newCategoryUUID("44444444444444444444444444444444")

	queryCalls := 0
	deps := &Deps{
		DB: &mockStore{
			// No queryRowFn — default returns errRow{pgx.ErrNoRows} → no profile.
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				queryCalls++
				return &categoryRows{rows: []categoryRow{
					{id: catID, name: "Accessories", path: "accessories"},
				}}, nil
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories", nil)
	req.Header.Set("X-Cove-Uid", "uid-new-user")
	rr := httptest.NewRecorder()

	deps.RecommendedCategoriesHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}

	var body recommendedCategoriesResponse
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(body.Categories) != 1 {
		t.Errorf("expected 1 fallback category, got %d", len(body.Categories))
	}
	// Only the fallback query should run — interest query is skipped.
	if queryCalls != 1 {
		t.Errorf("expected 1 query call (fallback only), got %d", queryCalls)
	}
}

func TestRecommendedCategoriesHandler_BothQueriesEmpty(t *testing.T) {
	// Both queries return empty — response should be 200 with empty categories list.
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				return &emptyRows{}, nil
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories", nil)
	req.Header.Set("X-Cove-Uid", "uid-empty")
	rr := httptest.NewRecorder()

	deps.RecommendedCategoriesHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}

	var body recommendedCategoriesResponse
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(body.Categories) != 0 {
		t.Errorf("expected 0 categories, got %d", len(body.Categories))
	}
}

func TestRecommendedCategoriesHandler_TopUpWithFallback(t *testing.T) {
	// User has 1 interest but requests limit=5 → interest query returns 1 category,
	// fallback top-up is called for the remaining 4, total response is 5.
	interestCatID := newCategoryUUID("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
	fallbackCatID1 := newCategoryUUID("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
	fallbackCatID2 := newCategoryUUID("cccccccccccccccccccccccccccccccc")
	fallbackCatID3 := newCategoryUUID("dddddddddddddddddddddddddddddddd")
	fallbackCatID4 := newCategoryUUID("eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")

	queryCalls := 0
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				queryCalls++
				if queryCalls == 1 {
					// Interest query: returns 1 category (less than limit=5).
					return &categoryRows{rows: []categoryRow{
						{id: interestCatID, name: "Coffee", path: "food.coffee"},
					}}, nil
				}
				// Fallback top-up: should be called with remaining=4, excludeIDs=[coffee-id].
				return &categoryRows{rows: []categoryRow{
					{id: fallbackCatID1, name: "Vinyl", path: "music.vinyl"},
					{id: fallbackCatID2, name: "Pottery", path: "crafts.pottery"},
					{id: fallbackCatID3, name: "Plants", path: "plants"},
					{id: fallbackCatID4, name: "Art", path: "art"},
				}}, nil
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories?limit=5", nil)
	req.Header.Set("X-Cove-Uid", "uid-topup")
	rr := httptest.NewRecorder()

	deps.RecommendedCategoriesHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}

	var body recommendedCategoriesResponse
	if err := json.NewDecoder(rr.Body).Decode(&body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	if len(body.Categories) != 5 {
		t.Errorf("expected 5 categories (1 interest + 4 fallback), got %d", len(body.Categories))
	}
	if body.Categories[0].Name != "Coffee" {
		t.Errorf("first category should be the interest category, got %q", body.Categories[0].Name)
	}
	if body.Categories[1].Name != "Vinyl" {
		t.Errorf("second category should be first fallback, got %q", body.Categories[1].Name)
	}
	if queryCalls != 2 {
		t.Errorf("expected 2 query calls (interest + fallback top-up), got %d", queryCalls)
	}
}

func TestRecommendedCategoriesHandler_LimitForwarded(t *testing.T) {
	// ?limit=5 should be parsed and passed as the LIMIT bind argument to the interest query.
	var interestLimit any
	queryCalls := 0
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				queryCalls++
				if queryCalls == 1 {
					// Interest query: args = [userID, limit].
					interestLimit = args[1]
				}
				return &emptyRows{}, nil
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories?limit=5", nil)
	req.Header.Set("X-Cove-Uid", "uid-limit")
	rr := httptest.NewRecorder()

	deps.RecommendedCategoriesHandler(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", rr.Code)
	}
	if interestLimit != 5 {
		t.Errorf("expected limit 5 forwarded to query, got %v", interestLimit)
	}
}

func TestRecommendedCategoriesHandler_InvalidLimitFallsBackToDefault(t *testing.T) {
	// A non-numeric / out-of-range limit is ignored in favor of the default.
	var interestLimit any
	queryCalls := 0
	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				queryCalls++
				if queryCalls == 1 {
					interestLimit = args[1]
				}
				return &emptyRows{}, nil
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories?limit=banana", nil)
	req.Header.Set("X-Cove-Uid", "uid-bad-limit")
	rr := httptest.NewRecorder()

	deps.RecommendedCategoriesHandler(rr, req)

	if interestLimit != defaultCategoryLimit {
		t.Errorf("expected default limit %d, got %v", defaultCategoryLimit, interestLimit)
	}
}

func TestRecommendedCategoriesHandler_ImageKey(t *testing.T) {
	// image_key is passed through when set and omitted from the JSON when NULL.
	catID1 := newCategoryUUID("11111111111111111111111111111111")
	catID2 := newCategoryUUID("22222222222222222222222222222222")
	key := "images/categories/food-baked_goods.jpg"

	deps := &Deps{
		DB: &mockStore{
			queryRowFn: func(ctx context.Context, sql string, args ...any) Row {
				return userUUIDRow()
			},
			queryFn: func(ctx context.Context, sql string, args ...any) (Rows, error) {
				return &categoryRows{rows: []categoryRow{
					{id: catID1, name: "Baked Goods", path: "food.baked_goods", imageKey: &key},
					{id: catID2, name: "Tea", path: "food.tea"},
				}}, nil
			},
		},
		CommitSHA: "test",
	}

	req := httptest.NewRequest(http.MethodGet, "/recommendations/categories?limit=2", nil)
	req.Header.Set("X-Cove-Uid", "uid-123")
	rr := httptest.NewRecorder()

	deps.RecommendedCategoriesHandler(rr, req)

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
