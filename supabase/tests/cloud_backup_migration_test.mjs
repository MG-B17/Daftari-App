import assert from 'node:assert/strict';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';

const { Client } = pg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationPath = path.resolve(
  __dirname,
  '../migrations/20261124000000_phase_12_cloud_backup.sql',
);
const migrationSql = fs.readFileSync(migrationPath, 'utf8');

const USER_A = '11111111-1111-4111-8111-111111111111';
const USER_B = '22222222-2222-4222-8222-222222222222';
const USER_C = '33333333-3333-4333-8333-333333333333';
const USER_D = '55555555-5555-4555-8555-555555555555';
const USER_UNVERIFIED = '44444444-4444-4444-8444-444444444444';

const DEVICE_A1 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
const DEVICE_A2 = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
const DEVICE_B1 = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
const DEVICE_C1 = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc1';
const DEVICE_C2 = 'cccccccc-cccc-4ccc-8ccc-ccccccccccc2';
const DEVICE_D1 = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd1';
const DEVICE_D2 = 'dddddddd-dddd-4ddd-8ddd-ddddddddddd2';

const SECRET_A1 = 'a1'.repeat(32);
const SECRET_A2 = 'a2'.repeat(32);
const SECRET_B1 = 'b1'.repeat(32);
const SECRET_C1 = 'c1'.repeat(32);
const SECRET_C2 = 'c2'.repeat(32);
const SECRET_D1 = 'd1'.repeat(32);
const SECRET_D2 = 'd2'.repeat(32);

const BATCH_A1 = '10000000-0000-4000-8000-000000000001';
const BATCH_A2 = '10000000-0000-4000-8000-000000000002';
const BATCH_A3 = '10000000-0000-4000-8000-000000000003';
const BATCH_A_INVALID = '10000000-0000-4000-8000-000000000004';
const BATCH_A_IMPERSONATE = '10000000-0000-4000-8000-000000000005';
const BATCH_B1 = '20000000-0000-4000-8000-000000000001';
const BATCH_B_CROSS = '20000000-0000-4000-8000-000000000002';
const BATCH_C1 = '30000000-0000-4000-8000-000000000001';
const BATCH_C2 = '30000000-0000-4000-8000-000000000002';
const BATCH_D1 = '40000000-0000-4000-8000-000000000001';
const BATCH_D2 = '40000000-0000-4000-8000-000000000002';

const CUST_A1 = '01000000-0000-4000-8000-000000000001';
const CUST_B1 = '02000000-0000-4000-8000-000000000001';
const CUST_C1 = '03000000-0000-4000-8000-000000000001';
const CUST_C2 = '03000000-0000-4000-8000-000000000002';
const CUST_D1 = '04000000-0000-4000-8000-000000000001';
const CUST_D2 = '04000000-0000-4000-8000-000000000002';
const CUST_MISSING = '09000000-0000-4000-8000-000000000099';

const TX_A1 = '01100000-0000-4000-8000-000000000001';
const TX_A_BAD = '01100000-0000-4000-8000-000000000099';
const TX_B1 = '02100000-0000-4000-8000-000000000001';
const TX_B_CROSS = '02100000-0000-4000-8000-000000000099';

const AUDIT_A1 = '01200000-0000-4000-8000-000000000001';
const AUDIT_A2 = '01200000-0000-4000-8000-000000000002';

function findFreePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
    server.on('error', reject);
  });
}

async function createClient(port) {
  const client = new Client({
    host: '127.0.0.1',
    port,
    user: 'postgres',
    password: 'password',
    database: 'postgres',
  });
  await client.connect();
  return client;
}

async function asRole(client, { role, userId }, fn) {
  await client.query('begin');
  try {
    await client.query(`set local role ${role}`);
    await client.query(
      `select pg_catalog.set_config('request.jwt.claim.sub', $1, true)`,
      [userId ?? ''],
    );
    const result = await fn(client);
    await client.query('commit');
    return result;
  } catch (err) {
    await client.query('rollback');
    throw err;
  }
}

async function expectSqlState(promise, expectedCode, label) {
  let caught = null;
  try {
    await promise;
  } catch (err) {
    caught = err;
  }
  assert.ok(caught, `${label}: expected SQLSTATE ${expectedCode} but succeeded`);
  assert.equal(
    caught.code,
    expectedCode,
    `${label}: expected SQLSTATE ${expectedCode}, got ${caught.code} (${caught.message})`,
  );
}

async function waitForBackendLock(adminClient, pid, timeoutMs = 5000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const res = await adminClient.query(
      `select wait_event_type, wait_event, state
         from pg_stat_activity
        where pid = $1`,
      [pid],
    );
    if (res.rows.length === 1 && res.rows[0].wait_event_type === 'Lock') {
      return res.rows[0];
    }
    await new Promise((r) => setTimeout(r, 25));
  }
  throw new Error(
    `Timed out waiting for PostgreSQL backend pid ${pid} to enter Lock wait`,
  );
}

async function run() {
  const dataDir = fs.mkdtempSync(
    path.join(os.tmpdir(), 'daftari-pg-backup-test-'),
  );
  const port = await findFreePort();
  const pgServer = new EmbeddedPostgres({
    databaseDir: dataDir,
    user: 'postgres',
    password: 'password',
    port,
    persistent: false,
    onLog: () => {},
    onError: () => {},
  });

  let admin = null;
  let conn1 = null;
  let conn2 = null;

  try {
    await pgServer.initialise();
    await pgServer.start();

    admin = await createClient(port);
    conn1 = await createClient(port);
    conn2 = await createClient(port);

    // 1. Minimal Supabase auth + role fixture.
    await admin.query(`
      create role anon nologin;
      create role authenticated nologin;
      create schema auth;
      create table auth.users (
        id uuid primary key,
        email_confirmed_at timestamptz null
      );
      create or replace function auth.uid()
      returns uuid
      language sql
      stable
      as $$
        select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
      $$;
      grant usage on schema public to anon, authenticated;
      grant usage on schema auth to anon, authenticated;
      grant execute on function auth.uid() to anon, authenticated;
    `);

    await admin.query(
      `insert into auth.users (id, email_confirmed_at) values
        ($1, '2026-11-20T00:00:00Z'),
        ($2, '2026-11-20T00:00:00Z'),
        ($3, '2026-11-20T00:00:00Z'),
        ($4, '2026-11-20T00:00:00Z'),
        ($5, null)`,
      [USER_A, USER_B, USER_C, USER_D, USER_UNVERIFIED],
    );

    // 2. Apply exact unmodified migration.
    await admin.query(migrationSql);

    const capturedAt = '2026-11-24T10:00:00.000Z';
    const customerA1 = {
      id: CUST_A1,
      name: 'Ahmed',
      phone: '01001112222',
      notes: 'regular',
      created_at: '2026-11-20T08:00:00.000Z',
      updated_at: '2026-11-20T08:00:00.000Z',
      deleted_at: null,
      local_revision: 1,
    };
    const txA1Rev1 = {
      id: TX_A1,
      customer_id: CUST_A1,
      type: 'credit',
      amount_piasters: 10000,
      note: 'initial',
      transaction_date: '2026-11-20T09:00:00.000Z',
      created_at: '2026-11-20T09:00:00.000Z',
      updated_at: '2026-11-20T09:00:00.000Z',
      deleted_at: null,
      local_revision: 1,
    };
    const auditA1 = {
      id: AUDIT_A1,
      transaction_id: TX_A1,
      action: 'edit',
      previous_type: 'credit',
      previous_amount_piasters: 5000,
      previous_note: 'before edit',
      previous_transaction_date: '2026-11-20T09:00:00.000Z',
      created_at: '2026-11-20T09:05:00.000Z',
      local_revision: 1,
    };

    // 3. P12-09: Valid first publication commits customer, transaction, audit, batch and account timestamp.
    const firstPublish = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        const res = await tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::jsonb) as result`,
          [
            BATCH_A1,
            DEVICE_A1,
            SECRET_A1,
            capturedAt,
            JSON.stringify([customerA1]),
            JSON.stringify([txA1Rev1]),
            JSON.stringify([auditA1]),
          ],
        );
        return res.rows[0].result;
      },
    );
    assert.equal(firstPublish.status, 'confirmed');
    assert.equal(firstPublish.batch_id, BATCH_A1);
    assert.ok(firstPublish.confirmed_at);

    const accountRows = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      (tx) => tx.query('select * from public.backup_accounts'),
    );
    assert.equal(accountRows.rows.length, 1);
    assert.equal(accountRows.rows[0].active_device_id, DEVICE_A1);
    assert.equal(
      new Date(accountRows.rows[0].last_confirmed_at).getTime(),
      new Date(firstPublish.confirmed_at).getTime(),
    );

    const customerRows = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      (tx) => tx.query('select * from public.backup_customers'),
    );
    assert.equal(customerRows.rows.length, 1);
    assert.equal(customerRows.rows[0].id, CUST_A1);

    const txRows = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      (tx) => tx.query('select * from public.backup_transactions'),
    );
    assert.equal(txRows.rows.length, 1);
    assert.equal(Number(txRows.rows[0].amount_piasters), 10000);

    const auditRows = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      (tx) => tx.query('select * from public.backup_transaction_audit_logs'),
    );
    assert.equal(auditRows.rows.length, 1);
    assert.equal(auditRows.rows[0].id, AUDIT_A1);

    // 4. Confirmation lookup and idempotent replay return exact original confirmed_at.
    const lookupA1 = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        const res = await tx.query(
          `select public.find_backup_batch_confirmation($1, $2, $3) as result`,
          [BATCH_A1, DEVICE_A1, SECRET_A1],
        );
        return res.rows[0].result;
      },
    );
    assert.deepEqual(lookupA1, firstPublish);

    const replayA1 = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        const res = await tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::jsonb) as result`,
          [
            BATCH_A1,
            DEVICE_A1,
            SECRET_A1,
            capturedAt,
            JSON.stringify([customerA1]),
            JSON.stringify([txA1Rev1]),
            JSON.stringify([auditA1]),
          ],
        );
        return res.rows[0].result;
      },
    );
    assert.deepEqual(replayA1, firstPublish);

    // 5. Second publication updates transaction revision + tombstone + append-only delete audit;
    //    stale revision cannot overwrite newer revision.
    const txA1Rev2 = {
      ...txA1Rev1,
      amount_piasters: 15000,
      deleted_at: '2026-11-24T10:05:00.000Z',
      updated_at: '2026-11-24T10:05:00.000Z',
      local_revision: 2,
    };
    const auditA2 = {
      id: AUDIT_A2,
      transaction_id: TX_A1,
      action: 'delete',
      previous_type: 'credit',
      previous_amount_piasters: 10000,
      previous_note: 'initial',
      previous_transaction_date: '2026-11-20T09:00:00.000Z',
      created_at: '2026-11-24T10:05:00.000Z',
      local_revision: 1,
    };

    const secondPublish = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        const res = await tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::jsonb) as result`,
          [
            BATCH_A2,
            DEVICE_A1,
            SECRET_A1,
            '2026-11-24T10:06:00.000Z',
            JSON.stringify([]),
            JSON.stringify([txA1Rev2]),
            JSON.stringify([auditA2]),
          ],
        );
        return res.rows[0].result;
      },
    );
    assert.equal(secondPublish.status, 'confirmed');

    await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        await tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::jsonb)`,
          [
            BATCH_A3,
            DEVICE_A1,
            SECRET_A1,
            '2026-11-24T10:07:00.000Z',
            JSON.stringify([]),
            JSON.stringify([txA1Rev1]),
            JSON.stringify([auditA1]),
          ],
        );
      },
    );
    const txAfterStale = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      (tx) =>
        tx.query(
          'select amount_piasters, local_revision, deleted_at from public.backup_transactions',
        ),
    );
    assert.equal(Number(txAfterStale.rows[0].amount_piasters), 15000);
    assert.equal(txAfterStale.rows[0].local_revision, 2);
    assert.ok(txAfterStale.rows[0].deleted_at);

    const auditsAfterAll = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      (tx) =>
        tx.query(
          'select id from public.backup_transaction_audit_logs order by id',
        ),
    );
    assert.deepEqual(
      auditsAfterAll.rows.map((r) => r.id),
      [AUDIT_A1, AUDIT_A2],
    );

    // 6. Atomic rollback on invalid FK data preserves previous confirmed rows and batch count.
    await expectSqlState(
      asRole(conn1, { role: 'authenticated', userId: USER_A }, (tx) =>
        tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, $6::jsonb, $7::jsonb)`,
          [
            BATCH_A_INVALID,
            DEVICE_A1,
            SECRET_A1,
            '2026-11-24T10:08:00.000Z',
            JSON.stringify([]),
            JSON.stringify([
              { ...txA1Rev1, id: TX_A_BAD, customer_id: CUST_MISSING },
            ]),
            JSON.stringify([]),
          ],
        ),
      ),
      '23503',
      'invalid customer FK must fail and roll back',
    );
    const batchesAfterRollback = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      (tx) => tx.query('select batch_id from public.backup_batches'),
    );
    assert.equal(batchesAfterRollback.rows.length, 3);

    await expectSqlState(
      asRole(conn1, { role: 'authenticated', userId: USER_A }, (tx) =>
        tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, '[]'::jsonb, '[]'::jsonb, '[]'::jsonb)`,
          [BATCH_A_INVALID, DEVICE_A1, SECRET_A1, capturedAt],
        ),
      ),
      '22023',
      'empty batch must fail',
    );
    await expectSqlState(
      asRole(conn1, { role: 'authenticated', userId: USER_UNVERIFIED }, (tx) =>
        tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, '[]'::jsonb, '[]'::jsonb)`,
          [
            BATCH_A_INVALID,
            DEVICE_A1,
            SECRET_A1,
            capturedAt,
            JSON.stringify([customerA1]),
          ],
        ),
      ),
      '42501',
      'unverified email must fail',
    );
    await expectSqlState(
      asRole(conn1, { role: 'anon', userId: null }, (tx) =>
        tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, '[]'::jsonb, '[]'::jsonb)`,
          [
            BATCH_A_INVALID,
            DEVICE_A1,
            SECRET_A1,
            capturedAt,
            JSON.stringify([customerA1]),
          ],
        ),
      ),
      '42501',
      'anon role must be denied RPC execute',
    );

    // 7. P12-10: Second installation for Account A reads permitted backup data,
    //    cannot read credentials or mutate tables, and cannot impersonate writer.
    const stolenActiveDeviceId = await asRole(
      conn2,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        const acc = await tx.query(
          'select active_device_id from public.backup_accounts',
        );
        const custs = await tx.query('select id from public.backup_customers');
        assert.equal(custs.rows.length, 1);
        return acc.rows[0].active_device_id;
      },
    );
    assert.equal(stolenActiveDeviceId, DEVICE_A1);

    await expectSqlState(
      asRole(conn2, { role: 'authenticated', userId: USER_A }, (tx) =>
        tx.query('select * from public.backup_device_credentials'),
      ),
      '42501',
      'authenticated client must never read backup_device_credentials',
    );
    await expectSqlState(
      asRole(conn2, { role: 'authenticated', userId: USER_A }, (tx) =>
        tx.query(
          'update public.backup_accounts set active_device_id = $1 where user_id = $2',
          [DEVICE_A2, USER_A],
        ),
      ),
      '42501',
      'authenticated client must never update backup_accounts directly',
    );

    const secondDevicePublish = await asRole(
      conn2,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        const res = await tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, '[]'::jsonb, '[]'::jsonb) as result`,
          [
            BATCH_A_IMPERSONATE,
            DEVICE_A2,
            SECRET_A2,
            '2026-11-24T10:09:00.000Z',
            JSON.stringify([
              { ...customerA1, name: 'Hijacked', local_revision: 99 },
            ]),
          ],
        );
        return res.rows[0].result;
      },
    );
    assert.deepEqual(secondDevicePublish, { status: 'inactive_device' });

    const impersonatePublish = await asRole(
      conn2,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        const res = await tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, '[]'::jsonb, '[]'::jsonb) as result`,
          [
            BATCH_A_IMPERSONATE,
            stolenActiveDeviceId,
            SECRET_A2,
            '2026-11-24T10:10:00.000Z',
            JSON.stringify([
              { ...customerA1, name: 'Impersonated', local_revision: 99 },
            ]),
          ],
        );
        return res.rows[0].result;
      },
    );
    assert.deepEqual(impersonatePublish, { status: 'inactive_device' });

    const impersonateLookup = await asRole(
      conn2,
      { role: 'authenticated', userId: USER_A },
      async (tx) => {
        const res = await tx.query(
          `select public.find_backup_batch_confirmation($1, $2, $3) as result`,
          [BATCH_A1, stolenActiveDeviceId, SECRET_A2],
        );
        return res.rows[0].result;
      },
    );
    assert.deepEqual(impersonateLookup, { status: 'inactive_device' });

    const customerAfterImpersonation = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_A },
      (tx) =>
        tx.query('select name, local_revision from public.backup_customers'),
    );
    assert.equal(customerAfterImpersonation.rows[0].name, 'Ahmed');
    assert.equal(customerAfterImpersonation.rows[0].local_revision, 1);

    // 8A. P12-14: Two-connection OVERLAPPING first claims on fresh Account C
    //     where conn1 holds PostgreSQL's lock while conn2 blocks, then conn1 commits.
    const conn2Pid = (await conn2.query('select pg_backend_pid() as pid'))
      .rows[0].pid;

    await conn1.query('begin');
    await conn1.query('set local role authenticated');
    await conn1.query(
      `select pg_catalog.set_config('request.jwt.claim.sub', $1, true)`,
      [USER_C],
    );
    const claimC1Res = await conn1.query(
      `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, '[]'::jsonb, '[]'::jsonb) as result`,
      [
        BATCH_C1,
        DEVICE_C1,
        SECRET_C1,
        capturedAt,
        JSON.stringify([{ ...customerA1, id: CUST_C1, name: 'Winner C1' }]),
      ],
    );
    assert.equal(claimC1Res.rows[0].result.status, 'confirmed');

    // Start overlapping competing claim on conn2 BEFORE conn1 commits.
    await conn2.query('begin');
    await conn2.query('set local role authenticated');
    await conn2.query(
      `select pg_catalog.set_config('request.jwt.claim.sub', $1, true)`,
      [USER_C],
    );
    const claimC2Promise = conn2.query(
      `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, '[]'::jsonb, '[]'::jsonb) as result`,
      [
        BATCH_C2,
        DEVICE_C2,
        SECRET_C2,
        capturedAt,
        JSON.stringify([{ ...customerA1, id: CUST_C2, name: 'Loser C2' }]),
      ],
    );

    // Confirm conn2 is genuinely blocked on a PostgreSQL Lock held by conn1.
    await waitForBackendLock(admin, conn2Pid);

    await conn1.query('commit');
    const claimC2Res = await claimC2Promise;
    await conn2.query('commit');

    assert.deepEqual(claimC2Res.rows[0].result, { status: 'inactive_device' });

    const cAccount = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_C },
      (tx) => tx.query('select active_device_id from public.backup_accounts'),
    );
    assert.equal(cAccount.rows[0].active_device_id, DEVICE_C1);
    const cCustomers = await asRole(
      conn1,
      { role: 'authenticated', userId: USER_C },
      (tx) => tx.query('select id from public.backup_customers'),
    );
    assert.deepEqual(
      cCustomers.rows.map((r) => r.id),
      [CUST_C1],
    );

    // 8B. Two-connection OVERLAPPING first claims on fresh Account D where conn1
    //     rolls back while conn2 is blocked -> conn2 loops and cleanly claims!
    await conn1.query('begin');
    await conn1.query('set local role authenticated');
    await conn1.query(
      `select pg_catalog.set_config('request.jwt.claim.sub', $1, true)`,
      [USER_D],
    );
    await conn1.query(
      `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, '[]'::jsonb, '[]'::jsonb)`,
      [
        BATCH_D1,
        DEVICE_D1,
        SECRET_D1,
        capturedAt,
        JSON.stringify([{ ...customerA1, id: CUST_D1, name: 'Rolled Back D1' }]),
      ],
    );

    await conn2.query('begin');
    await conn2.query('set local role authenticated');
    await conn2.query(
      `select pg_catalog.set_config('request.jwt.claim.sub', $1, true)`,
      [USER_D],
    );
    const claimD2Promise = conn2.query(
      `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, '[]'::jsonb, '[]'::jsonb) as result`,
      [
        BATCH_D2,
        DEVICE_D2,
        SECRET_D2,
        capturedAt,
        JSON.stringify([{ ...customerA1, id: CUST_D2, name: 'Winner D2' }]),
      ],
    );

    await waitForBackendLock(admin, conn2Pid);

    await conn1.query('rollback');
    const claimD2Res = await claimD2Promise;
    await conn2.query('commit');

    assert.equal(claimD2Res.rows[0].result.status, 'confirmed');
    assert.equal(claimD2Res.rows[0].result.batch_id, BATCH_D2);

    const dAccount = await asRole(
      conn2,
      { role: 'authenticated', userId: USER_D },
      (tx) => tx.query('select active_device_id from public.backup_accounts'),
    );
    assert.equal(dAccount.rows[0].active_device_id, DEVICE_D2);
    const dCustomers = await asRole(
      conn2,
      { role: 'authenticated', userId: USER_D },
      (tx) => tx.query('select id from public.backup_customers'),
    );
    assert.deepEqual(
      dCustomers.rows.map((r) => r.id),
      [CUST_D2],
    );

    // 9. Cross-account isolation: Account B sees zero Account A rows, cannot link
    //    to Account A's customer, and publishes its own independent ledger cleanly.
    const bVisibleBefore = await asRole(
      conn2,
      { role: 'authenticated', userId: USER_B },
      async (tx) => {
        const res = await tx.query(`
          select
            (select count(*)::int from public.backup_accounts) as acc,
            (select count(*)::int from public.backup_batches) as bat,
            (select count(*)::int from public.backup_customers) as cust,
            (select count(*)::int from public.backup_transactions) as tr,
            (select count(*)::int from public.backup_transaction_audit_logs) as aud
        `);
        const row = res.rows[0];
        return [row.acc, row.bat, row.cust, row.tr, row.aud];
      },
    );
    assert.deepEqual(bVisibleBefore, [0, 0, 0, 0, 0]);

    await expectSqlState(
      asRole(conn2, { role: 'authenticated', userId: USER_B }, (tx) =>
        tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, '[]'::jsonb, $5::jsonb, '[]'::jsonb)`,
          [
            BATCH_B_CROSS,
            DEVICE_B1,
            SECRET_B1,
            capturedAt,
            JSON.stringify([
              { ...txA1Rev1, id: TX_B_CROSS, customer_id: CUST_A1 },
            ]),
          ],
        ),
      ),
      '23503',
      'cross-account customer FK must fail and roll back',
    );

    const publishB1 = await asRole(
      conn2,
      { role: 'authenticated', userId: USER_B },
      async (tx) => {
        const res = await tx.query(
          `select public.publish_backup_batch($1, $2, $3, $4, $5::jsonb, $6::jsonb, '[]'::jsonb) as result`,
          [
            BATCH_B1,
            DEVICE_B1,
            SECRET_B1,
            capturedAt,
            JSON.stringify([
              { ...customerA1, id: CUST_B1, name: 'Account B Customer' },
            ]),
            JSON.stringify([
              { ...txA1Rev1, id: TX_B1, customer_id: CUST_B1 },
            ]),
          ],
        );
        return res.rows[0].result;
      },
    );
    assert.equal(publishB1.status, 'confirmed');

    console.log('ALL_POSTGRES_BACKUP_MIGRATION_TESTS_PASSED');
  } finally {
    if (conn1) await conn1.end().catch(() => {});
    if (conn2) await conn2.end().catch(() => {});
    if (admin) await admin.end().catch(() => {});
    await pgServer.stop().catch(() => {});
    try {
      fs.rmSync(dataDir, {
        recursive: true,
        force: true,
        maxRetries: 10,
        retryDelay: 100,
      });
    } catch (_) {
      // Best-effort cleanup if Windows delays releasing stopped postgres handles.
    }
  }
}

run().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
