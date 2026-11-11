package cleanup

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

type fakeExecer struct {
	sql  string
	args []any
	tag  pgconn.CommandTag
	err  error
}

func (f *fakeExecer) Exec(_ context.Context, sql string, args ...any) (pgconn.CommandTag, error) {
	f.sql, f.args = sql, args
	return f.tag, f.err
}

func TestDeleteIdleGuests_QueryOnlyTargetsIdleGuests(t *testing.T) {
	db := &fakeExecer{tag: pgconn.NewCommandTag("DELETE 3")}

	n, err := DeleteIdleGuests(context.Background(), db, GuestIdleDays)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if n != 3 {
		t.Errorf("deleted = %d, want 3", n)
	}
	for _, want := range []string{"DELETE FROM profile.users", "is_guest", "username IS NULL", "last_seen_at < now() - make_interval(days => $1)"} {
		if !strings.Contains(db.sql, want) {
			t.Errorf("query is missing %q:\n%s", want, db.sql)
		}
	}
	if len(db.args) != 1 || db.args[0] != 30 {
		t.Errorf("args = %v, want [30]", db.args)
	}
}

func TestDeleteIdleGuests_WrapsDBError(t *testing.T) {
	dbErr := errors.New("connection reset")
	_, err := DeleteIdleGuests(context.Background(), &fakeExecer{err: dbErr}, GuestIdleDays)
	if !errors.Is(err, dbErr) {
		t.Fatalf("err = %v, want it to wrap %v", err, dbErr)
	}
}

func TestDeleteIdleGuests_RejectsNonPositiveDays(t *testing.T) {
	for _, days := range []int{0, -1} {
		db := &fakeExecer{}
		if _, err := DeleteIdleGuests(context.Background(), db, days); err == nil {
			t.Errorf("idleDays=%d: expected an error", days)
		}
		if db.sql != "" {
			t.Errorf("idleDays=%d: query ran anyway", days)
		}
	}
}
