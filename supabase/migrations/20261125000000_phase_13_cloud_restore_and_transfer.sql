-- Phase 13 — Cloud Restore and Device Transfer: consistent confirmed account
-- ledger version, authenticated cumulative snapshot read, and serialized
-- idempotent backup authority transfer.

alter table public.backup_accounts
  add column if not exists confirmed_version bigint not null default 0
    constraint chk_backup_accounts_confirmed_version_non_negative
    check (confirmed_version >= 0);

-- Backfill confirmed_version for any existing accounts that already have a
-- confirmed backup timestamp from Phase 12.
update public.backup_accounts a
   set confirmed_version = greatest(
         (
           select count(*)::bigint
             from public.backup_batches b
            where b.user_id = a.user_id
         ),
         1
       )
 where a.last_confirmed_at is not null
   and a.confirmed_version = 0;

-- Private server-only ledger of committed backup-authority transfers keyed by
-- (user_id, request_id) so retries after a lost network response recover the
-- exact committed takeover outcome without mistaking the newly installed active
-- device for a competing takeover. Clients have zero direct access to this table.
create table if not exists public.backup_authority_transfers (
  user_id uuid not null references public.backup_accounts (user_id) on delete cascade,
  request_id uuid not null,
  previous_device_id uuid not null,
  target_device_id uuid not null,
  target_secret_hash text not null check (pg_catalog.length(target_secret_hash) = 64),
  confirmed_version text not null check (pg_catalog.length(pg_catalog.btrim(confirmed_version)) > 0),
  confirmed_at timestamptz not null,
  transferred_at timestamptz not null default pg_catalog.now(),
  primary key (user_id, request_id)
);

alter table public.backup_authority_transfers enable row level security;
alter table public.backup_authority_transfers force row level security;

revoke all on table public.backup_authority_transfers from public, anon, authenticated;

-- Advance confirmed_version atomically on each newly committed backup batch
-- while preserving the Phase 12 parameter and response contract.
create or replace function public.publish_backup_batch(
  p_batch_id uuid,
  p_device_id uuid,
  p_device_secret text,
  p_captured_at timestamptz,
  p_customers jsonb,
  p_transactions jsonb,
  p_audit_logs jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_now timestamptz := pg_catalog.now();
  v_active_device_id uuid;
  v_cred_device_id uuid;
  v_expected_secret_hash text;
  v_secret_hash text;
  v_existing_device_id uuid;
  v_existing_confirmed_at timestamptz;
  v_customer_count integer;
  v_transaction_count integer;
  v_audit_log_count integer;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
      from auth.users
     where id = v_user_id
       and email_confirmed_at is not null
  ) then
    raise exception 'Email verification required' using errcode = '42501';
  end if;

  if p_batch_id is null
     or p_device_id is null
     or p_device_secret is null
     or pg_catalog.length(pg_catalog.btrim(p_device_secret)) < 32
     or p_captured_at is null then
    raise exception 'batch_id, device_id, device_secret and captured_at are required' using errcode = '22023';
  end if;

  if p_customers is null or pg_catalog.jsonb_typeof(p_customers) <> 'array'
     or p_transactions is null or pg_catalog.jsonb_typeof(p_transactions) <> 'array'
     or p_audit_logs is null or pg_catalog.jsonb_typeof(p_audit_logs) <> 'array' then
    raise exception 'customers, transactions and audit_logs must be JSON arrays' using errcode = '22023';
  end if;

  v_customer_count := pg_catalog.jsonb_array_length(p_customers);
  v_transaction_count := pg_catalog.jsonb_array_length(p_transactions);
  v_audit_log_count := pg_catalog.jsonb_array_length(p_audit_logs);

  if v_customer_count + v_transaction_count + v_audit_log_count = 0 then
    raise exception 'Empty backup batch cannot be published' using errcode = '22023';
  end if;

  v_secret_hash := pg_catalog.encode(
    pg_catalog.sha256(pg_catalog.convert_to(p_device_secret, 'UTF8')),
    'hex'
  );

  loop
    insert into public.backup_accounts (user_id, active_device_id, created_at, updated_at)
    values (v_user_id, p_device_id, v_now, v_now)
    on conflict (user_id) do nothing;

    select active_device_id
      into v_active_device_id
      from public.backup_accounts
     where user_id = v_user_id
       for update;

    exit when found;
  end loop;

  insert into public.backup_device_credentials (
    user_id,
    active_device_id,
    device_secret_hash,
    created_at,
    updated_at
  )
  values (v_user_id, v_active_device_id, v_secret_hash, v_now, v_now)
  on conflict (user_id) do nothing;

  select active_device_id, device_secret_hash
    into v_cred_device_id, v_expected_secret_hash
    from public.backup_device_credentials
   where user_id = v_user_id
     for update;

  if v_active_device_id <> p_device_id
     or v_cred_device_id <> p_device_id
     or v_expected_secret_hash <> v_secret_hash then
    return pg_catalog.jsonb_build_object('status', 'inactive_device');
  end if;

  select device_id, confirmed_at
    into v_existing_device_id, v_existing_confirmed_at
    from public.backup_batches
   where user_id = v_user_id
     and batch_id = p_batch_id;

  if found then
    if v_existing_device_id <> p_device_id then
      raise exception 'Batch already belongs to another device' using errcode = '22023';
    end if;
    return pg_catalog.jsonb_build_object(
      'status', 'confirmed',
      'batch_id', p_batch_id,
      'confirmed_at', v_existing_confirmed_at
    );
  end if;

  insert into public.backup_batches (
    user_id,
    batch_id,
    device_id,
    captured_at,
    confirmed_at,
    customer_count,
    transaction_count,
    audit_log_count
  )
  values (
    v_user_id,
    p_batch_id,
    p_device_id,
    p_captured_at,
    v_now,
    v_customer_count,
    v_transaction_count,
    v_audit_log_count
  );

  if v_customer_count > 0 then
    insert into public.backup_customers (
      id,
      user_id,
      name,
      phone,
      notes,
      created_at,
      updated_at,
      deleted_at,
      local_revision,
      last_batch_id,
      synced_at
    )
    select
      c.id,
      v_user_id,
      c.name,
      c.phone,
      c.notes,
      c.created_at,
      c.updated_at,
      c.deleted_at,
      c.local_revision,
      p_batch_id,
      v_now
    from pg_catalog.jsonb_to_recordset(p_customers) as c(
      id uuid,
      name text,
      phone text,
      notes text,
      created_at timestamptz,
      updated_at timestamptz,
      deleted_at timestamptz,
      local_revision integer
    )
    on conflict (id, user_id) do update
      set name = excluded.name,
          phone = excluded.phone,
          notes = excluded.notes,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at,
          local_revision = excluded.local_revision,
          last_batch_id = excluded.last_batch_id,
          synced_at = excluded.synced_at
     where public.backup_customers.local_revision < excluded.local_revision;
  end if;

  if v_transaction_count > 0 then
    insert into public.backup_transactions (
      id,
      user_id,
      customer_id,
      type,
      amount_piasters,
      note,
      transaction_date,
      created_at,
      updated_at,
      deleted_at,
      local_revision,
      last_batch_id,
      synced_at
    )
    select
      t.id,
      v_user_id,
      t.customer_id,
      t.type,
      t.amount_piasters,
      t.note,
      t.transaction_date,
      t.created_at,
      t.updated_at,
      t.deleted_at,
      t.local_revision,
      p_batch_id,
      v_now
    from pg_catalog.jsonb_to_recordset(p_transactions) as t(
      id uuid,
      customer_id uuid,
      type text,
      amount_piasters bigint,
      note text,
      transaction_date timestamptz,
      created_at timestamptz,
      updated_at timestamptz,
      deleted_at timestamptz,
      local_revision integer
    )
    on conflict (id, user_id) do update
      set customer_id = excluded.customer_id,
          type = excluded.type,
          amount_piasters = excluded.amount_piasters,
          note = excluded.note,
          transaction_date = excluded.transaction_date,
          created_at = excluded.created_at,
          updated_at = excluded.updated_at,
          deleted_at = excluded.deleted_at,
          local_revision = excluded.local_revision,
          last_batch_id = excluded.last_batch_id,
          synced_at = excluded.synced_at
     where public.backup_transactions.local_revision < excluded.local_revision;
  end if;

  if v_audit_log_count > 0 then
    insert into public.backup_transaction_audit_logs (
      id,
      user_id,
      transaction_id,
      action,
      previous_type,
      previous_amount_piasters,
      previous_note,
      previous_transaction_date,
      created_at,
      local_revision,
      last_batch_id,
      synced_at
    )
    select
      a.id,
      v_user_id,
      a.transaction_id,
      a.action,
      a.previous_type,
      a.previous_amount_piasters,
      a.previous_note,
      a.previous_transaction_date,
      a.created_at,
      a.local_revision,
      p_batch_id,
      v_now
    from pg_catalog.jsonb_to_recordset(p_audit_logs) as a(
      id uuid,
      transaction_id uuid,
      action text,
      previous_type text,
      previous_amount_piasters bigint,
      previous_note text,
      previous_transaction_date timestamptz,
      created_at timestamptz,
      local_revision integer
    )
    on conflict (id, user_id) do nothing;
  end if;

  update public.backup_accounts
     set last_confirmed_at = greatest(
           coalesce(last_confirmed_at, v_now),
           v_now
         ),
         confirmed_version = confirmed_version + 1,
         updated_at = v_now
   where user_id = v_user_id;

  return pg_catalog.jsonb_build_object(
    'status', 'confirmed',
    'batch_id', p_batch_id,
    'confirmed_at', v_now
  );
end;
$$;

-- Reads the authenticated user's full cumulative cloud ledger at one
-- consistent server-confirmed version, serialized against concurrent batch
-- publication and authority transfer via row locking on backup_accounts.
-- Distinguishes a missing backup from a valid confirmed snapshot with zero rows.
create or replace function public.read_confirmed_backup_snapshot(
  p_expected_version text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_active_device_id uuid;
  v_last_confirmed_at timestamptz;
  v_confirmed_version bigint;
  v_version_token text;
  v_customer_count integer;
  v_deleted_customer_count integer;
  v_transaction_count integer;
  v_deleted_transaction_count integer;
  v_audit_log_count integer;
  v_customers jsonb;
  v_transactions jsonb;
  v_audit_logs jsonb;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
      from auth.users
     where id = v_user_id
       and email_confirmed_at is not null
  ) then
    raise exception 'Email verification required' using errcode = '42501';
  end if;

  if p_expected_version is not null
     and pg_catalog.length(pg_catalog.btrim(p_expected_version)) = 0 then
    raise exception 'expected_version cannot be blank' using errcode = '22023';
  end if;

  -- Lock the account header with FOR SHARE so any in-flight publication or
  -- authority transfer completes first and no new write can interleave while
  -- reading the cumulative customer, transaction and audit tables.
  select active_device_id, last_confirmed_at, confirmed_version
    into v_active_device_id, v_last_confirmed_at, v_confirmed_version
    from public.backup_accounts
   where user_id = v_user_id
     for share;

  if not found or v_last_confirmed_at is null or v_confirmed_version < 1 then
    return pg_catalog.jsonb_build_object('status', 'missing_backup');
  end if;

  v_version_token := 'v-' || v_confirmed_version::text;

  select
    count(*) filter (where c.deleted_at is null)::integer,
    count(*) filter (where c.deleted_at is not null)::integer
    into v_customer_count, v_deleted_customer_count
    from public.backup_customers c
   where c.user_id = v_user_id;

  select
    count(*) filter (where t.deleted_at is null)::integer,
    count(*) filter (where t.deleted_at is not null)::integer
    into v_transaction_count, v_deleted_transaction_count
    from public.backup_transactions t
   where t.user_id = v_user_id;

  select count(*)::integer
    into v_audit_log_count
    from public.backup_transaction_audit_logs a
   where a.user_id = v_user_id;

  if p_expected_version is not null and v_version_token <> p_expected_version then
    return pg_catalog.jsonb_build_object(
      'status', 'version_changed',
      'version', v_version_token,
      'active_device_id', v_active_device_id,
      'confirmed_at', v_last_confirmed_at,
      'customer_count', v_customer_count,
      'deleted_customer_count', v_deleted_customer_count,
      'transaction_count', v_transaction_count,
      'deleted_transaction_count', v_deleted_transaction_count,
      'audit_log_count', v_audit_log_count
    );
  end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', c.id,
        'name', c.name,
        'phone', c.phone,
        'notes', c.notes,
        'created_at', c.created_at,
        'updated_at', c.updated_at,
        'deleted_at', c.deleted_at,
        'local_revision', c.local_revision
      )
      order by c.id
    ),
    '[]'::jsonb
  )
    into v_customers
    from public.backup_customers c
   where c.user_id = v_user_id;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', t.id,
        'customer_id', t.customer_id,
        'type', t.type,
        'amount_piasters', t.amount_piasters,
        'note', t.note,
        'transaction_date', t.transaction_date,
        'created_at', t.created_at,
        'updated_at', t.updated_at,
        'deleted_at', t.deleted_at,
        'local_revision', t.local_revision
      )
      order by t.id
    ),
    '[]'::jsonb
  )
    into v_transactions
    from public.backup_transactions t
   where t.user_id = v_user_id;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', a.id,
        'transaction_id', a.transaction_id,
        'action', a.action,
        'previous_type', a.previous_type,
        'previous_amount_piasters', a.previous_amount_piasters,
        'previous_note', a.previous_note,
        'previous_transaction_date', a.previous_transaction_date,
        'created_at', a.created_at,
        'local_revision', a.local_revision
      )
      order by a.id
    ),
    '[]'::jsonb
  )
    into v_audit_logs
    from public.backup_transaction_audit_logs a
   where a.user_id = v_user_id;

  return pg_catalog.jsonb_build_object(
    'status', 'ready',
    'version', v_version_token,
    'active_device_id', v_active_device_id,
    'confirmed_at', v_last_confirmed_at,
    'customer_count', v_customer_count,
    'deleted_customer_count', v_deleted_customer_count,
    'transaction_count', v_transaction_count,
    'deleted_transaction_count', v_deleted_transaction_count,
    'audit_log_count', v_audit_log_count,
    'customers', v_customers,
    'transactions', v_transactions,
    'audit_logs', v_audit_logs
  );
end;
$$;

-- Atomically and idempotently transfers active backup device authority to
-- (p_target_device_id, p_target_device_secret) when the account's confirmed
-- version and active device still match (p_expected_version, p_expected_active_device_id).
-- Serialized with publish_backup_batch via FOR UPDATE on backup_accounts and
-- backup_device_credentials.
create or replace function public.transfer_backup_authority(
  p_request_id uuid,
  p_target_device_id uuid,
  p_target_device_secret text,
  p_expected_version text,
  p_expected_active_device_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_now timestamptz := pg_catalog.now();
  v_active_device_id uuid;
  v_last_confirmed_at timestamptz;
  v_confirmed_version bigint;
  v_current_version text;
  v_secret_hash text;
  v_existing_prev_device uuid;
  v_existing_target_device uuid;
  v_existing_secret_hash text;
  v_existing_version text;
  v_existing_confirmed_at timestamptz;
  v_existing_transferred_at timestamptz;
  v_reason text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
      from auth.users
     where id = v_user_id
       and email_confirmed_at is not null
  ) then
    raise exception 'Email verification required' using errcode = '42501';
  end if;

  if p_request_id is null
     or p_target_device_id is null
     or p_target_device_secret is null
     or pg_catalog.length(pg_catalog.btrim(p_target_device_secret)) < 32
     or p_expected_version is null
     or pg_catalog.length(pg_catalog.btrim(p_expected_version)) = 0
     or p_expected_active_device_id is null then
    raise exception 'request_id, target_device_id, target_device_secret, expected_version and expected_active_device_id are required' using errcode = '22023';
  end if;

  v_secret_hash := pg_catalog.encode(
    pg_catalog.sha256(pg_catalog.convert_to(p_target_device_secret, 'UTF8')),
    'hex'
  );

  select active_device_id, last_confirmed_at, confirmed_version
    into v_active_device_id, v_last_confirmed_at, v_confirmed_version
    from public.backup_accounts
   where user_id = v_user_id
     for update;

  if not found or v_last_confirmed_at is null or v_confirmed_version < 1 then
    return pg_catalog.jsonb_build_object('status', 'missing_backup');
  end if;

  perform 1
     from public.backup_device_credentials
    where user_id = v_user_id
      for update;

  -- Idempotent recovery: if this exact request_id already committed for the
  -- authenticated user, verify the caller owns the target device credential and
  -- return the original committed outcome.
  select
    previous_device_id,
    target_device_id,
    target_secret_hash,
    confirmed_version,
    confirmed_at,
    transferred_at
    into
      v_existing_prev_device,
      v_existing_target_device,
      v_existing_secret_hash,
      v_existing_version,
      v_existing_confirmed_at,
      v_existing_transferred_at
    from public.backup_authority_transfers
   where user_id = v_user_id
     and request_id = p_request_id;

  if found then
    if v_existing_target_device <> p_target_device_id
       or v_existing_secret_hash <> v_secret_hash
       or v_existing_version <> p_expected_version
       or v_existing_prev_device <> p_expected_active_device_id then
      raise exception 'Transfer request_id already belongs to different parameters or device' using errcode = '22023';
    end if;

    return pg_catalog.jsonb_build_object(
      'status', 'transferred',
      'request_id', p_request_id,
      'version', v_existing_version,
      'active_device_id', v_existing_target_device,
      'confirmed_at', v_existing_confirmed_at,
      'transferred_at', v_existing_transferred_at
    );
  end if;

  v_current_version := 'v-' || v_confirmed_version::text;

  if v_current_version <> p_expected_version
     or v_active_device_id <> p_expected_active_device_id then
    if v_current_version <> p_expected_version then
      v_reason := 'version_changed';
    else
      v_reason := 'active_device_changed';
    end if;

    return pg_catalog.jsonb_build_object(
      'status', 'precondition_failed',
      'reason', v_reason,
      'current_version', v_current_version,
      'active_device_id', v_active_device_id,
      'confirmed_at', v_last_confirmed_at
    );
  end if;

  update public.backup_accounts
     set active_device_id = p_target_device_id,
         updated_at = v_now
   where user_id = v_user_id;

  insert into public.backup_device_credentials (
    user_id,
    active_device_id,
    device_secret_hash,
    created_at,
    updated_at
  )
  values (v_user_id, p_target_device_id, v_secret_hash, v_now, v_now)
  on conflict (user_id) do update
    set active_device_id = excluded.active_device_id,
        device_secret_hash = excluded.device_secret_hash,
        updated_at = excluded.updated_at;

  insert into public.backup_authority_transfers (
    user_id,
    request_id,
    previous_device_id,
    target_device_id,
    target_secret_hash,
    confirmed_version,
    confirmed_at,
    transferred_at
  )
  values (
    v_user_id,
    p_request_id,
    v_active_device_id,
    p_target_device_id,
    v_secret_hash,
    v_current_version,
    v_last_confirmed_at,
    v_now
  );

  return pg_catalog.jsonb_build_object(
    'status', 'transferred',
    'request_id', p_request_id,
    'version', v_current_version,
    'active_device_id', p_target_device_id,
    'confirmed_at', v_last_confirmed_at,
    'transferred_at', v_now
  );
end;
$$;

-- Looks up whether a previously persisted authority transfer request_id was
-- already committed on the server for the authenticated account and target
-- installation credential.
create or replace function public.find_backup_authority_transfer(
  p_request_id uuid,
  p_target_device_id uuid,
  p_target_device_secret text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_secret_hash text;
  v_existing_target_device uuid;
  v_existing_secret_hash text;
  v_existing_version text;
  v_existing_confirmed_at timestamptz;
  v_existing_transferred_at timestamptz;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
      from auth.users
     where id = v_user_id
       and email_confirmed_at is not null
  ) then
    raise exception 'Email verification required' using errcode = '42501';
  end if;

  if p_request_id is null
     or p_target_device_id is null
     or p_target_device_secret is null
     or pg_catalog.length(pg_catalog.btrim(p_target_device_secret)) < 32 then
    raise exception 'request_id, target_device_id and target_device_secret are required' using errcode = '22023';
  end if;

  v_secret_hash := pg_catalog.encode(
    pg_catalog.sha256(pg_catalog.convert_to(p_target_device_secret, 'UTF8')),
    'hex'
  );

  select
    target_device_id,
    target_secret_hash,
    confirmed_version,
    confirmed_at,
    transferred_at
    into
      v_existing_target_device,
      v_existing_secret_hash,
      v_existing_version,
      v_existing_confirmed_at,
      v_existing_transferred_at
    from public.backup_authority_transfers
   where user_id = v_user_id
     and request_id = p_request_id;

  if not found then
    return pg_catalog.jsonb_build_object('status', 'not_found');
  end if;

  if v_existing_target_device <> p_target_device_id
     or v_existing_secret_hash <> v_secret_hash then
    raise exception 'Transfer request_id belongs to another device credential' using errcode = '42501';
  end if;

  return pg_catalog.jsonb_build_object(
    'status', 'transferred',
    'request_id', p_request_id,
    'version', v_existing_version,
    'active_device_id', v_existing_target_device,
    'confirmed_at', v_existing_confirmed_at,
    'transferred_at', v_existing_transferred_at
  );
end;
$$;

revoke all on function public.read_confirmed_backup_snapshot(text) from public, anon;
grant execute on function public.read_confirmed_backup_snapshot(text) to authenticated;

revoke all on function public.transfer_backup_authority(uuid, uuid, text, text, uuid) from public, anon;
grant execute on function public.transfer_backup_authority(uuid, uuid, text, text, uuid) to authenticated;

revoke all on function public.find_backup_authority_transfer(uuid, uuid, text) from public, anon;
grant execute on function public.find_backup_authority_transfer(uuid, uuid, text) to authenticated;
