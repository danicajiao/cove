package handler

import (
	"encoding/json"
	"strings"
	"testing"
)

func strPtr(s string) *string { return &s }

func TestBuildCategoryTree_ImageKeys(t *testing.T) {
	cats := []catFlat{
		{id: "1", name: "Food", path: "food",
			imageKey:     strPtr("images/categories/card/food.jpg"),
			wideImageKey: strPtr("images/categories/wide/food.jpg")},
		{id: "2", name: "Baked Goods", path: "food.baked_goods",
			imageKey: strPtr("images/categories/card/food-baked_goods.jpg")},
		{id: "3", name: "Bread", path: "food.baked_goods.bread"},
	}

	roots := buildCategoryTree(cats)
	if len(roots) != 1 {
		t.Fatalf("expected 1 root, got %d", len(roots))
	}
	food := roots[0]
	if food.WideImageKey == nil || *food.WideImageKey != "images/categories/wide/food.jpg" {
		t.Errorf("food wide_image_key = %v, want wide key", food.WideImageKey)
	}
	if food.ImageKey == nil || *food.ImageKey != "images/categories/card/food.jpg" {
		t.Errorf("food image_key = %v, want card key", food.ImageKey)
	}
	if len(food.Children) != 1 || len(food.Children[0].Children) != 1 {
		t.Fatalf("expected food > baked_goods > bread, got %+v", food)
	}

	body, err := json.Marshal(roots)
	if err != nil {
		t.Fatal(err)
	}
	// wide_image_key appears once (level 1 only); NULL keys are omitted.
	if got := strings.Count(string(body), `"wide_image_key"`); got != 1 {
		t.Errorf("wide_image_key appears %d times, want 1: %s", got, body)
	}
	if got := strings.Count(string(body), `"image_key"`); got != 2 {
		t.Errorf("image_key appears %d times, want 2: %s", got, body)
	}
}
