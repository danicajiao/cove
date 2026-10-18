package handler

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
)

// ── mockStore ─────────────────────────────────────────────────────────────────

// mockStore is a test double for Store. Set function fields to inject
// exactly the behavior each test case needs.
type mockStore struct {
	queryRowFn func(ctx context.Context, sql string, args ...any) Row
	queryFn    func(ctx context.Context, sql string, args ...any) (Rows, error)
	execFn     func(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	beginFn    func(ctx context.Context) (pgx.Tx, error)
}

func (m *mockStore) QueryRow(ctx context.Context, sql string, args ...any) Row {
	if m.queryRowFn != nil {
		return m.queryRowFn(ctx, sql, args...)
	}
	return &errRow{err: pgx.ErrNoRows}
}

func (m *mockStore) Query(ctx context.Context, sql string, args ...any) (Rows, error) {
	if m.queryFn != nil {
		return m.queryFn(ctx, sql, args...)
	}
	return &emptyRows{}, nil
}

func (m *mockStore) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	if m.execFn != nil {
		return m.execFn(ctx, sql, args...)
	}
	return pgconn.NewCommandTag("DELETE 1"), nil
}

func (m *mockStore) Begin(ctx context.Context) (pgx.Tx, error) {
	if m.beginFn != nil {
		return m.beginFn(ctx)
	}
	return &mockTx{}, nil
}

// ── errRow ────────────────────────────────────────────────────────────────────

// errRow is a Row that always returns a fixed error from Scan.
type errRow struct{ err error }

func (r *errRow) Scan(dest ...any) error { return r.err }

// ── uuidRow ───────────────────────────────────────────────────────────────────

// uuidRow scans a single pgtype.UUID. Used by lookupUserID.
type uuidRow struct{ val pgtype.UUID }

func (r *uuidRow) Scan(dest ...any) error {
	if len(dest) != 1 {
		return fmt.Errorf("uuidRow: expected 1 dest, got %d", len(dest))
	}
	if p, ok := dest[0].(*pgtype.UUID); ok {
		*p = r.val
		return nil
	}
	return fmt.Errorf("uuidRow: cannot scan into %T", dest[0])
}

// ── intRow ────────────────────────────────────────────────────────────────────

// intRow scans a single int value. Used for COUNT(*) queries.
type intRow struct{ val int }

func (r *intRow) Scan(dest ...any) error {
	if len(dest) != 1 {
		return fmt.Errorf("intRow: expected 1 dest, got %d", len(dest))
	}
	if p, ok := dest[0].(*int); ok {
		*p = r.val
		return nil
	}
	return fmt.Errorf("intRow: cannot scan into %T", dest[0])
}

// ── profileRow ────────────────────────────────────────────────────────────────

// profileRow scans the user profile columns.
// GetMeHandler scans 4 columns (uid, username, created_at, interests_onboarded via EXISTS).
// CreateUserHandler scans 3 (uid, username, created_at — new users always have no flags).
type profileRow struct {
	uid, username      string
	createdAt          time.Time
	interestsOnboarded bool
}

func (r *profileRow) Scan(dest ...any) error {
	if len(dest) != 3 && len(dest) != 4 {
		return fmt.Errorf("profileRow: expected 3 or 4 dest, got %d", len(dest))
	}
	for i, d := range dest[:2] {
		p, ok := d.(*string)
		if !ok {
			return fmt.Errorf("profileRow: dest[%d] is %T, want *string", i, d)
		}
		if i == 0 {
			*p = r.uid
		} else {
			*p = r.username
		}
	}
	pt, ok := dest[2].(*time.Time)
	if !ok {
		return fmt.Errorf("profileRow: dest[2] is %T, want *time.Time", dest[2])
	}
	*pt = r.createdAt
	if len(dest) == 4 {
		pb, ok := dest[3].(*bool)
		if !ok {
			return fmt.Errorf("profileRow: dest[3] is %T, want *bool", dest[3])
		}
		*pb = r.interestsOnboarded
	}
	return nil
}

// ── emptyRows ─────────────────────────────────────────────────────────────────

// emptyRows is a Rows that returns no rows.
type emptyRows struct{}

func (r *emptyRows) Next() bool        { return false }
func (r *emptyRows) Scan(...any) error { return nil }
func (r *emptyRows) Close()            {}
func (r *emptyRows) Err() error        { return nil }

// ── categoryRows ─────────────────────────────────────────────────────────────

// categoryRow holds one row of (id, name, path, image_key) for recommendations.
type categoryRow struct {
	id       pgtype.UUID
	name     string
	path     string
	imageKey *string
}

// categoryRows is a multi-row Rows for recommendations queries.
type categoryRows struct {
	rows    []categoryRow
	pos     int
	current categoryRow
}

func (r *categoryRows) Next() bool {
	if r.pos >= len(r.rows) {
		return false
	}
	r.current = r.rows[r.pos]
	r.pos++
	return true
}

func (r *categoryRows) Scan(dest ...any) error {
	// Scans: *pgtype.UUID, *string, *string, **string
	if len(dest) != 4 {
		return fmt.Errorf("categoryRows: expected 4 dest, got %d", len(dest))
	}
	if p, ok := dest[0].(*pgtype.UUID); ok {
		*p = r.current.id
	} else {
		return fmt.Errorf("categoryRows: dest[0] is %T, want *pgtype.UUID", dest[0])
	}
	if p, ok := dest[1].(*string); ok {
		*p = r.current.name
	} else {
		return fmt.Errorf("categoryRows: dest[1] is %T, want *string", dest[1])
	}
	if p, ok := dest[2].(*string); ok {
		*p = r.current.path
	} else {
		return fmt.Errorf("categoryRows: dest[2] is %T, want *string", dest[2])
	}
	if p, ok := dest[3].(**string); ok {
		*p = r.current.imageKey
	} else {
		return fmt.Errorf("categoryRows: dest[3] is %T, want **string", dest[3])
	}
	return nil
}

func (r *categoryRows) Close()     {}
func (r *categoryRows) Err() error { return nil }

// newCategoryUUID builds a valid pgtype.UUID from a 32-hex-char string.
func newCategoryUUID(hex32 string) pgtype.UUID {
	var u pgtype.UUID
	b := []byte(hex32)
	for i, j := 0, 0; i < 16; i++ {
		hi := hexVal(b[j])
		lo := hexVal(b[j+1])
		u.Bytes[i] = hi<<4 | lo
		j += 2
	}
	u.Valid = true
	return u
}

func hexVal(c byte) byte {
	switch {
	case c >= '0' && c <= '9':
		return c - '0'
	case c >= 'a' && c <= 'f':
		return c - 'a' + 10
	case c >= 'A' && c <= 'F':
		return c - 'A' + 10
	}
	return 0
}

// ── mockTx ────────────────────────────────────────────────────────────────────

// mockTx implements pgx.Tx with no-ops for everything except Exec, Commit,
// and Rollback, which are the only methods used by ReplaceInterestsHandler.
type mockTx struct {
	execFn      func(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	commitErr   error
	rollbackErr error
}

func (t *mockTx) Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	if t.execFn != nil {
		return t.execFn(ctx, sql, args...)
	}
	return pgconn.NewCommandTag("OK"), nil
}

func (t *mockTx) Commit(ctx context.Context) error   { return t.commitErr }
func (t *mockTx) Rollback(ctx context.Context) error { return t.rollbackErr }

// pgx.Tx requires these additional methods — all no-ops for testing.
func (t *mockTx) Begin(ctx context.Context) (pgx.Tx, error) { return &mockTx{}, nil }
func (t *mockTx) Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error) {
	return nil, nil
}
func (t *mockTx) QueryRow(ctx context.Context, sql string, args ...any) pgx.Row {
	return &errRow{err: pgx.ErrNoRows}
}
func (t *mockTx) SendBatch(ctx context.Context, b *pgx.Batch) pgx.BatchResults { return nil }
func (t *mockTx) LargeObjects() pgx.LargeObjects                               { return pgx.LargeObjects{} }
func (t *mockTx) Prepare(ctx context.Context, name, sql string) (*pgconn.StatementDescription, error) {
	return nil, nil
}
func (t *mockTx) CopyFrom(ctx context.Context, tableName pgx.Identifier, columnNames []string, rowSrc pgx.CopyFromSource) (int64, error) {
	return 0, nil
}
func (t *mockTx) Conn() *pgx.Conn { return nil }
