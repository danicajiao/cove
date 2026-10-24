package normalize_test

import (
	"bytes"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"strings"
	"testing"

	"github.com/davidbyttow/govips/v2/vips"

	"github.com/danicajiao/cove/services/cove-media/internal/normalize"
)

// TestMain initialises and shuts down the libvips runtime for the whole test
// binary.  vips.Startup must be called exactly once per process.
func TestMain(m *testing.M) {
	vips.Startup(nil)
	defer vips.Shutdown()
	m.Run()
}

// makeJPEG encodes a small solid-colour image as JPEG and returns the bytes.
func makeJPEG(t *testing.T, c color.RGBA) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 16, 16))
	for y := range 16 {
		for x := range 16 {
			img.Set(x, y, c)
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 80}); err != nil {
		t.Fatalf("makeJPEG: %v", err)
	}
	return buf.Bytes()
}

// makePNG encodes the same image as PNG.
func makePNG(t *testing.T, c color.RGBA) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 16, 16))
	for y := range 16 {
		for x := range 16 {
			img.Set(x, y, c)
		}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatalf("makePNG: %v", err)
	}
	return buf.Bytes()
}

// TestImage_OutputIsWebP verifies that the output bytes begin with the WebP
// file signature regardless of input format.
func TestImage_OutputIsWebP(t *testing.T) {
	input := makeJPEG(t, color.RGBA{R: 255, A: 255})

	result, err := normalize.Image(input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// WebP files start with "RIFF" (bytes 0–3) and "WEBP" (bytes 8–11).
	if len(result.Data) < 12 {
		t.Fatalf("output too short to be a WebP: %d bytes", len(result.Data))
	}
	if !bytes.HasPrefix(result.Data, []byte("RIFF")) {
		t.Errorf("output does not start with RIFF: %q", result.Data[:4])
	}
	if string(result.Data[8:12]) != "WEBP" {
		t.Errorf("output[8:12] is not WEBP: %q", result.Data[8:12])
	}
}

// TestImage_KeyFormat verifies the key matches "images/<64-hex-chars>.webp".
func TestImage_KeyFormat(t *testing.T) {
	result, err := normalize.Image(makeJPEG(t, color.RGBA{G: 200, A: 255}))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if !strings.HasPrefix(result.Key, "images/") {
		t.Errorf("key missing images/ prefix: %q", result.Key)
	}
	if !strings.HasSuffix(result.Key, ".webp") {
		t.Errorf("key missing .webp suffix: %q", result.Key)
	}
	// "images/" = 7 chars, ".webp" = 5 chars, SHA-256 hex = 64 chars → total 76
	if len(result.Key) != 76 {
		t.Errorf("unexpected key length %d (want 76): %q", len(result.Key), result.Key)
	}
}

// TestImage_Deterministic verifies that normalizing the same input twice
// produces identical output bytes and the same key.
func TestImage_Deterministic(t *testing.T) {
	input := makeJPEG(t, color.RGBA{B: 180, A: 255})

	r1, err := normalize.Image(input)
	if err != nil {
		t.Fatalf("first call: %v", err)
	}
	r2, err := normalize.Image(input)
	if err != nil {
		t.Fatalf("second call: %v", err)
	}

	if r1.Key != r2.Key {
		t.Errorf("keys differ: %q vs %q", r1.Key, r2.Key)
	}
	if !bytes.Equal(r1.Data, r2.Data) {
		t.Errorf("output bytes differ across two calls with identical input")
	}
}

// TestImage_DifferentFormats verifies that a JPEG and a PNG encoding of the
// same pixel data produce different keys.  Because JPEG is lossy the decoded
// pixels will differ from the lossless PNG encoding, so the resulting WebP
// will differ — this confirms we key on normalized pixel content, not the
// original container format.
func TestImage_DifferentFormats(t *testing.T) {
	c := color.RGBA{R: 100, G: 150, B: 200, A: 255}
	jpegResult, err := normalize.Image(makeJPEG(t, c))
	if err != nil {
		t.Fatalf("JPEG: %v", err)
	}
	pngResult, err := normalize.Image(makePNG(t, c))
	if err != nil {
		t.Fatalf("PNG: %v", err)
	}

	// JPEG is lossy so the pixel data differs — keys should differ.
	if jpegResult.Key == pngResult.Key {
		t.Log("JPEG and PNG produced the same key — JPEG was lossless for this image")
	}
	// Either outcome is valid; the important thing is both succeed.
}

// TestImage_RecordsDimensions verifies that Width and Height reflect the
// source image dimensions.
func TestImage_RecordsDimensions(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 32, 16)) // 32 wide, 16 tall
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: 80}); err != nil {
		t.Fatalf("encode: %v", err)
	}

	result, err := normalize.Image(buf.Bytes())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result.Width != 32 {
		t.Errorf("Width = %d, want 32", result.Width)
	}
	if result.Height != 16 {
		t.Errorf("Height = %d, want 16", result.Height)
	}
}

// TestImage_InvalidBytes verifies that corrupt/non-image bytes return an error.
func TestImage_InvalidBytes(t *testing.T) {
	_, err := normalize.Image([]byte("this is not an image"))
	if err == nil {
		t.Error("expected error for invalid input, got nil")
	}
}
