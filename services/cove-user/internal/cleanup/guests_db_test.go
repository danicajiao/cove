package cleanup

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/jackc/pgx/v5"
)

// TestDeleteIdleGuests_Postgres runs the profile migrations up, checks the
// delete against real rows and cascades, then runs the migrations down.
//
// It needs a disposable Postgres database and is skipped unless
// COVE_USER_TEST_DATABASE_URL is set. It creates and drops the profile,
// catalog and directory schemas, so never point it at a real database.
func TestDeleteIdleGuests_Postgres(t *testing.T) {
	url := os.Getenv("COVE_USER_TEST_DATABASE_URL")
	if url == "" {
		t.Skip("COVE_USER_TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	conn, err := pgx.Connect(ctx, url)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	defer conn.Close(ctx)

	exec := func(sql string, args ...any) {
		t.Helper()
		if _, err := conn.Exec(ctx, sql, args...); err != nil {
			t.Fatalf("%v\n%s", err, sql)
		}
	}
	migrate := func(name string) {
		t.Helper()
		b, err := os.ReadFile(filepath.Join("..", "..", "migrations", name))
		if err != nil {
			t.Fatal(err)
		}
		exec(string(b))
	}
	count := func(sql string, args ...any) int {
		t.Helper()
		var n int
		if err := conn.QueryRow(ctx, sql, args...).Scan(&n); err != nil {
			t.Fatalf("%v\n%s", err, sql)
		}
		return n
	}

	// The tables the profile schema references, owned by other services.
	exec(`DO $$ BEGIN CREATE ROLE cove_user; EXCEPTION WHEN duplicate_object THEN NULL; END $$`)
	exec(`DROP SCHEMA IF EXISTS profile, catalog, directory CASCADE`)
	exec(`CREATE SCHEMA catalog; CREATE SCHEMA directory;
	      CREATE TABLE catalog.categories (id uuid PRIMARY KEY DEFAULT gen_random_uuid());
	      CREATE TABLE catalog.items      (id uuid PRIMARY KEY DEFAULT gen_random_uuid());
	      CREATE TABLE directory.producers (id uuid PRIMARY KEY DEFAULT gen_random_uuid());
	      CREATE TABLE directory.places    (id uuid PRIMARY KEY DEFAULT gen_random_uuid());`)
	t.Cleanup(func() { _, _ = conn.Exec(ctx, `DROP SCHEMA IF EXISTS profile, catalog, directory CASCADE`) })

	for _, m := range []string{"000001_profile_schema.up.sql", "000002_guest_profiles.up.sql", "000003_guest_last_seen.up.sql"} {
		migrate(m)
	}

	// New rows start with last_seen_at = now().
	exec(`INSERT INTO profile.users (auth_uid, is_guest) VALUES ('fresh-guest', true)`)
	if n := count(`SELECT count(*) FROM profile.users WHERE auth_uid = 'fresh-guest' AND last_seen_at > now() - interval '1 minute'`); n != 1 {
		t.Fatalf("new row's last_seen_at isn't now()")
	}

	exec(`INSERT INTO catalog.categories DEFAULT VALUES`)
	exec(`INSERT INTO profile.users (auth_uid, username, is_guest, last_seen_at) VALUES
	        ('idle-guest',     NULL,   true,  now() - interval '31 days'),
	        ('recent-guest',   NULL,   true,  now() - interval '29 days'),
	        ('idle-member',    'ana',  false, now() - interval '400 days'),
	        ('linked-no-name', NULL,   false, now() - interval '400 days')`)
	exec(`INSERT INTO profile.interests (user_id, category_id)
	      SELECT u.id, c.id FROM profile.users u, catalog.categories c`)
	exec(`INSERT INTO profile.activity (user_id, activity_type)
	      SELECT id, 'category_tap' FROM profile.users`)
	exec(`INSERT INTO profile.user_flags (user_id, flag)
	      SELECT id, 'interests_onboarded' FROM profile.users`)
	idleID := ""
	if err := conn.QueryRow(ctx, `SELECT id::text FROM profile.users WHERE auth_uid = 'idle-guest'`).Scan(&idleID); err != nil {
		t.Fatal(err)
	}

	n, err := DeleteIdleGuests(ctx, conn, GuestIdleDays)
	if err != nil {
		t.Fatalf("DeleteIdleGuests: %v", err)
	}
	if n != 1 {
		t.Errorf("deleted %d rows, want 1", n)
	}
	var left []string
	rows, _ := conn.Query(ctx, `SELECT auth_uid FROM profile.users ORDER BY auth_uid`)
	for rows.Next() {
		var s string
		_ = rows.Scan(&s)
		left = append(left, s)
	}
	if err := rows.Err(); err != nil {
		t.Fatal(err)
	}
	want := []string{"fresh-guest", "idle-member", "linked-no-name", "recent-guest"}
	if len(left) != len(want) {
		t.Fatalf("remaining users = %v, want %v", left, want)
	}
	for i := range want {
		if left[i] != want[i] {
			t.Fatalf("remaining users = %v, want %v", left, want)
		}
	}
	for _, table := range []string{"profile.interests", "profile.activity", "profile.user_flags"} {
		if c := count(`SELECT count(*) FROM `+table+` WHERE user_id = $1::uuid`, idleID); c != 0 {
			t.Errorf("%s still has %d rows for the deleted guest", table, c)
		}
		if c := count(`SELECT count(*) FROM ` + table); c != 4 {
			t.Errorf("%s has %d rows, want 4 (the remaining users')", table, c)
		}
	}

	// The 000003 down migration drops the column and index cleanly; the earlier
	// down migrations still apply after it.
	for _, m := range []string{"000003_guest_last_seen.down.sql", "000002_guest_profiles.down.sql", "000001_profile_schema.down.sql"} {
		migrate(m)
	}
	if c := count(`SELECT count(*) FROM information_schema.schemata WHERE schema_name = 'profile'`); c != 0 {
		t.Errorf("profile schema still exists after the down migrations")
	}
}
