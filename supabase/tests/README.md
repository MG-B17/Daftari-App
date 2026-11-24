# Supabase Cloud Backup Migration Tests

Runs the unmodified `supabase/migrations/20261124000000_phase_12_cloud_backup.sql`
against a disposable local PostgreSQL server (`embedded-postgres`) with
multi-connection concurrency checks.

## Run from a clean checkout

```bash
npm --prefix supabase/tests ci
npm --prefix supabase/tests test
```
