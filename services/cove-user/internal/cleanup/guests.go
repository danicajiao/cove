// Package cleanup deletes data nobody will come back for. It runs as a
// subcommand of the cove-user binary (cove-user cleanup-guests), scheduled
// daily by a Kubernetes CronJob.
package cleanup

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
)

// GuestIdleDays is how long a guest profile can go unused before it is deleted.
const GuestIdleDays = 30

// Execer is the part of *pgxpool.Pool that cleanup needs.
type Execer interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

// deleteIdleGuestsSQL deletes guests that haven't made a request in idleDays.
// Their flags, interests and activity go with them through ON DELETE CASCADE
// (guests can't have favorites or follows). A signed-up user is never deleted:
// is_guest is false once a login is linked, and username IS NULL guards the
// same thing a second way, since only guests lack a username for long.
const deleteIdleGuestsSQL = `
DELETE FROM profile.users
WHERE is_guest
  AND username IS NULL
  AND last_seen_at < now() - make_interval(days => $1)`

// DeleteIdleGuests deletes guest profiles idle for more than idleDays and
// returns how many were deleted.
func DeleteIdleGuests(ctx context.Context, db Execer, idleDays int) (int64, error) {
	if idleDays < 1 {
		return 0, fmt.Errorf("idleDays must be at least 1, got %d", idleDays)
	}
	tag, err := db.Exec(ctx, deleteIdleGuestsSQL, idleDays)
	if err != nil {
		return 0, fmt.Errorf("delete idle guests: %w", err)
	}
	return tag.RowsAffected(), nil
}
