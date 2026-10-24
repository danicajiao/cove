package storage

import (
	"crypto/sha256"
	"fmt"
	"strings"
	"testing"
)

// ---------------------------------------------------------------------------
// Key derivation helpers — tested without any S3 connection.
// ---------------------------------------------------------------------------

// contentAddressedKey builds the object key used by the upload handler:
//
//	images/{sha256hex}.{ext}
//
// It is reproduced here so we can unit-test the derivation logic in isolation.
func contentAddressedKey(sha256hex, ext string) string {
	return fmt.Sprintf("images/%s.%s", sha256hex, ext)
}

// extForContentType returns the canonical file extension for a MIME type.
// Returns ("", false) for unsupported types.
func extForContentType(ct string) (string, bool) {
	switch ct {
	case "image/jpeg":
		return "jpg", true
	case "image/png":
		return "png", true
	case "image/webp":
		return "webp", true
	default:
		return "", false
	}
}

func TestContentAddressedKey(t *testing.T) {
	t.Parallel()

	data := []byte("hello world")
	sum := sha256.Sum256(data)
	hex := fmt.Sprintf("%x", sum)

	key := contentAddressedKey(hex, "jpg")

	if !strings.HasPrefix(key, "images/") {
		t.Errorf("key %q should start with images/", key)
	}
	if !strings.HasSuffix(key, ".jpg") {
		t.Errorf("key %q should end with .jpg", key)
	}
	if !strings.Contains(key, hex) {
		t.Errorf("key %q should contain the sha256 hex %q", key, hex)
	}
}

func TestContentAddressedKeyIdempotent(t *testing.T) {
	t.Parallel()

	data := []byte("same bytes")
	sum := sha256.Sum256(data)
	hex := fmt.Sprintf("%x", sum)

	key1 := contentAddressedKey(hex, "png")
	key2 := contentAddressedKey(hex, "png")

	if key1 != key2 {
		t.Errorf("key derivation is not idempotent: %q != %q", key1, key2)
	}
}

func TestExtForContentType(t *testing.T) {
	t.Parallel()

	cases := []struct {
		ct      string
		wantExt string
		wantOK  bool
	}{
		{"image/jpeg", "jpg", true},
		{"image/png", "png", true},
		{"image/webp", "webp", true},
		{"image/gif", "", false},
		{"application/octet-stream", "", false},
		{"text/plain", "", false},
		{"", "", false},
	}

	for _, tc := range cases {
		tc := tc
		t.Run(tc.ct, func(t *testing.T) {
			t.Parallel()
			ext, ok := extForContentType(tc.ct)
			if ok != tc.wantOK {
				t.Errorf("extForContentType(%q) ok = %v, want %v", tc.ct, ok, tc.wantOK)
			}
			if ext != tc.wantExt {
				t.Errorf("extForContentType(%q) ext = %q, want %q", tc.ct, ext, tc.wantExt)
			}
		})
	}
}

// TestIntegration_PutObject is a placeholder for an integration test that
// exercises PutObject against a real (or local) Garage instance.
//
// TODO: wire against local S3 container (e.g. via docker-compose or testcontainers-go)
// to run a full round-trip without mocking the AWS SDK.
func TestIntegration_PutObject(t *testing.T) {
	t.Skip("integration test requires a running Garage instance — see TODO above")
}
