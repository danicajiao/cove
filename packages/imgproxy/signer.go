// Package imgproxy provides URL signing for the imgproxy image processing
// service, shared across Cove backend services.
//
// imgproxy verifies each incoming URL by checking an HMAC-SHA256 signature
// prepended to the processing path. This package implements that signing
// algorithm so any service can produce URLs that imgproxy will accept.
//
// Two consumers exist today:
//   - cove-image signs ad-hoc dimensions (vendor upload-preview flow)
//   - cove-catalog and cove-directory sign the fixed variant catalog (discovery,
//     item, producer and place responses)
//
// Reference: https://docs.imgproxy.net/usage/signing_the_url
package imgproxy

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"time"
)

// FitType controls how imgproxy scales the image to the requested dimensions.
type FitType string

const (
	// FitCover scales and crops the image to exactly fill the requested
	// dimensions (imgproxy resize type "fill").
	FitCover FitType = "fill"

	// FitContain scales the image to fit within the requested dimensions,
	// preserving aspect ratio (imgproxy resize type "fit").
	FitContain FitType = "fit"
)

// ParseFit converts a client-supplied fit string ("cover" | "contain") to the
// corresponding FitType. Returns FitCover for any unrecognised value.
func ParseFit(s string) FitType {
	if s == "contain" {
		return FitContain
	}
	return FitCover
}

// Variant is a named imgproxy resize preset. Services that serve images by
// catalog (rather than arbitrary dimensions) sign these fixed presets.
type Variant struct {
	Name   string
	Width  int
	Height int
}

// Catalog is the canonical set of five image variants for the Cove platform.
// All use FitCover (fill-and-crop to exact square) and @webp output. The sizes
// are documented in docs/MEDIA_ARCHITECTURE.md §Serving variants.
var Catalog = []Variant{
	{"thumb", 200, 200},
	{"sm", 400, 400},
	{"md", 800, 800},
	{"lg", 1600, 1600},
	{"xl", 3200, 3200},
}

// Signer holds the signing credentials and configuration needed to produce
// signed imgproxy URLs.
type Signer struct {
	key     []byte
	salt    []byte
	baseURL string // e.g. "https://api.coveapp.dev/i"
	bucket  string // e.g. "cove-media"
	ttl     time.Duration
}

// NewSigner creates a Signer from hex-encoded key and salt strings.
// Returns an error if either string is not valid hex.
func NewSigner(keyHex, saltHex, baseURL, bucket string, ttl time.Duration) (*Signer, error) {
	key, err := hex.DecodeString(keyHex)
	if err != nil {
		return nil, fmt.Errorf("invalid IMGPROXY_KEY: %w", err)
	}
	salt, err := hex.DecodeString(saltHex)
	if err != nil {
		return nil, fmt.Errorf("invalid IMGPROXY_SALT: %w", err)
	}
	return &Signer{
		key:     key,
		salt:    salt,
		baseURL: baseURL,
		bucket:  bucket,
		ttl:     ttl,
	}, nil
}

// SignResult holds a signed imgproxy URL and its expiry time.
type SignResult struct {
	URL       string
	ExpiresAt time.Time
}

// Sign generates a signed imgproxy URL for objectKey with the given resize params.
// objectKey is the full key in the bucket, e.g. "images/abc123.webp".
// width and height are in pixels; fit controls the resize mode.
// The URL embeds an exp: processing option that makes imgproxy reject requests
// after ExpiresAt, and the expiry is covered by the signature so it cannot be
// tampered with.
func (s *Signer) Sign(objectKey string, width, height int, fit FitType) SignResult {
	expiresAt := time.Now().Add(s.ttl)

	// Build the unsigned processing path.
	// Format: /exp:<unix>/rs:<fit>:<w>:<h>/plain/s3://<bucket>/<key>@webp
	path := fmt.Sprintf("/exp:%d/rs:%s:%d:%d/plain/s3://%s/%s@webp",
		expiresAt.Unix(), fit, width, height, s.bucket, objectKey)

	sig := s.sign(path)
	return SignResult{
		URL:       s.baseURL + "/" + sig + path,
		ExpiresAt: expiresAt,
	}
}

// SignVariants signs the named catalog variants for a given objectKey.
// Returns a map of variant name → signed URL. Names not present in Catalog
// are silently ignored.
func (s *Signer) SignVariants(objectKey string, names ...string) map[string]string {
	out := make(map[string]string, len(names))
	for _, v := range Catalog {
		for _, name := range names {
			if v.Name == name {
				out[v.Name] = s.Sign(objectKey, v.Width, v.Height, FitCover).URL
				break
			}
		}
	}
	return out
}

// sign returns the base64url-encoded (no padding) HMAC-SHA256 of
// (salt || path) keyed with the signing key.
func (s *Signer) sign(path string) string {
	mac := hmac.New(sha256.New, s.key)
	mac.Write(s.salt)
	mac.Write([]byte(path))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
