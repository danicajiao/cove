// Package normalize implements the image normalization pipeline for cove-media.
// It accepts raw upload bytes (JPEG, PNG, or WebP) and produces a WebP-encoded
// output with EXIF metadata stripped and the EXIF orientation corrected.
//
// vips.Startup must be called once in main before any function in this package
// is used.
package normalize

import (
	"crypto/sha256"
	"fmt"

	"github.com/davidbyttow/govips/v2/vips"
)

// Result holds the output of a successful normalization.
type Result struct {
	// Data is the normalized image encoded as WebP at quality 90.
	Data []byte
	// Key is the content-addressed Garage object key: "images/<sha256hex>.webp".
	// The SHA-256 is computed over the normalized WebP bytes so that the same
	// source image always produces the same key regardless of upload format.
	Key string
	// Width is the image width in pixels after normalization and auto-rotation.
	Width int
	// Height is the image height in pixels after normalization and auto-rotation.
	Height int
}

// Image normalizes an uploaded image for storage in Garage:
//
//  1. Decodes the source bytes (JPEG, PNG, or WebP).
//  2. Auto-rotates the image based on the EXIF orientation flag so that
//     portrait-mode phone photos are stored upright.
//  3. Strips all EXIF metadata — removing GPS coordinates, camera model,
//     timestamps, and any other embedded metadata for privacy and size.
//  4. Re-encodes as WebP at quality 90 (visually lossless, ~40-60% smaller
//     than an equivalent JPEG).
//  5. Computes SHA-256 of the normalized bytes and returns a content-addressed
//     Garage key: "images/<sha256hex>.webp".
//
// The key is deterministic: uploading the same source image twice — or in
// different formats — always yields the same key if the decoded pixel data is
// identical. This means re-uploads are free and storage is de-duplicated.
//
// Returns an error if the input bytes cannot be decoded (corrupt or unsupported
// format) or if any pipeline step fails.
func Image(data []byte) (*Result, error) {
	img, err := vips.NewImageFromBuffer(data)
	if err != nil {
		return nil, fmt.Errorf("normalize: decode: %w", err)
	}
	defer img.Close()

	// Apply EXIF orientation so the pixel data matches the intended orientation.
	// Phone cameras set an orientation flag rather than rotating the pixels;
	// without this step, portrait shots are stored sideways.
	if err := img.AutoRotate(); err != nil {
		return nil, fmt.Errorf("normalize: auto-rotate: %w", err)
	}

	// Strip all metadata (EXIF, XMP, IPTC) including GPS coordinates.
	// This must happen before export so the metadata is absent from the output.
	img.RemoveMetadata()

	// Capture dimensions after rotation — these reflect the stored image size
	// and are returned to the caller for recording in product.media.
	width := img.Width()
	height := img.Height()

	webpBytes, _, err := img.ExportWebp(&vips.WebpExportParams{
		Quality:  90,
		Lossless: false,
	})
	if err != nil {
		return nil, fmt.Errorf("normalize: export webp: %w", err)
	}

	sum := sha256.Sum256(webpBytes)
	key := fmt.Sprintf("images/%x.webp", sum)

	return &Result{
		Data:   webpBytes,
		Key:    key,
		Width:  width,
		Height: height,
	}, nil
}
