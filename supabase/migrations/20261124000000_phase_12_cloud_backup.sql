-- Phase 12 — Cloud Backup schema, account ownership, authenticated single
-- active backup device, row-level security and atomic idempotent publication
-- RPCs.

create table if not exists public.backup_accounts (
  user_id uuid primary key references auth.users (id) on delete cascade,
  active_device_id uuid not null,
  last_confirmed_at timestamptz null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now()
);

-- Private server-only credential binding the account's active writer to a
-- high-entropy secret held only by the authorized installation. Clients have
-- zero direct read or write access to this table.
create table if not exists public.backup_device_credentials (
  user_id uuid primary key references public.backup_accounts (user_id) on delete cascade,
  active_device_id uuid not null,
  device_secret_hash text not null check (pg_catalog.length(device_secret_hash) = 64),
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now()
);

create table if not exists public.backup_batches (
  user_id uuid not null references public.backup_accounts (user_id) on delete cascade,
  batch_id uuid not null,
  device_id uuid not null,
  captured_at timestamptz not null,
  confirmed_at timestamptz not null default pg_catalog.now(),
  customer_count integer not null check (customer_count >= 0),
  transaction_count integer not null check (transaction_count >= 0),
  audit_log_count integer not null check (audit_log_count >= 0),
  primary key (user_id, batch_id),
  constraint chk_backup_batches_non_empty
    check (customer_count + transaction_count + audit_log_count > 0)
);

create table if not exists public.backup_customers (
  id uuid not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (pg_catalog.length(pg_catalog.btrim(name)) > 0),
  phone text null,
  notes text null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz null,
  local_revision integer not null check (local_revision >= 1),
  last_batch_id uuid not null,
  synced_at timestamptz not null default pg_catalog.now(),
  primary key (id, user_id),
  constraint fk_backup_customers_batch
    foreign key (user_id, last_batch_id)
    references public.backup_batches (user_id, batch_id)
    on delete restrict
);

create index if not exists idx_backup_customers_user_id
  on public.backup_customers (user_id);

create table if not exists public.backup_transactions (
  id uuid not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  customer_id uuid not null,
  type text not null check (type in ('credit', 'payment')),
  amount_piasters bigint not null check (amount_piasters > 0),
  note text null,
  transaction_date timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  deleted_at timestamptz null,
  local_revision integer not null check (local_revision >= 1),
  last_batch_id uuid not null,
  synced_at timestamptz not null default pg_catalog.now(),
  primary key (id, user_id),
  constraint fk_backup_transactions_customer
    foreign key (customer_id, user_id)
    references public.backup_customers (id, user_id)
    on delete restrict,
  constraint fk_backup_transactions_batch
    foreign key (user_id, last_batch_id)
    references public.backup_batches (user_id, batch_id)
    on delete restrict
);

create index if not exists idx_backup_transactions_user_customer
  on public.backup_transactions (user_id, customer_id);

create table if not exists public.backup_transaction_audit_logs (
  id uuid not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  transaction_id uuid not null,
  action text not null check (action in ('edit', 'delete')),
  previous_type text not null check (previous_type in ('credit', 'payment')),
  previous_amount_piasters bigint not null check (previous_amount_piasters > 0),
  previous_note text null,
  previous_transaction_date timestamptz not null,
  created_at timestamptz not null,
  local_revision integer not null check (local_revision >= 1),
  last_batch_id uuid not null,
  synced_at timestamptz not null default pg_catalog.now(),
  primary key (id, user_id),
  constraint fk_backup_audit_logs_transaction
    foreign key (transaction_id, user_id)
    references public.backup_transactions (id, user_id)
    on delete restrict,
  constraint fk_backup_audit_logs_batch
    foreign key (user_id, last_batch_id)
    references public.backup_batches (user_id, batch_id)
    on delete restrict
);

create index if not exists idx_backup_audit_logs_user_transaction
  on public.backup_transaction_audit_logs (user_id, transaction_id);

-- Row-Level Security: only the authenticated owner can read permitted backup
-- data. Credentials are completely inaccessible to clients. All writes go
-- through the controlled RPCs below so installation authentication, active-
-- device authority, atomic batch publication and append-only audit logs cannot
-- be bypassed via direct table mutations.

alter table public.backup_accounts enable row level security;
alter table public.backup_accounts force row level security;

alter table public.backup_device_credentials enable row level security;
alter table public.backup_device_credentials force row level security;

alter table public.backup_batches enable row level security;
alter table public.backup_batches force row level security;

alter table public.backup_customers enable row level security;
alter table public.backup_customers force row level security;

alter table public.backup_transactions enable row level security;
alter table public.backup_transactions force row level security;

alter table public.backup_transaction_audit_logs enable row level security;
alter table public.backup_transaction_audit_logs force row level security;

revoke all on table public.backup_accounts from public, anon, authenticated;
revoke all on table public.backup_device_credentials from public, anon, authenticated;
revoke all on table public.backup_batches from public, anon, authenticated;
revoke all on table public.backup_customers from public, anon, authenticated;
revoke all on table public.backup_transactions from public, anon, authenticated;
revoke all on table public.backup_transaction_audit_logs from public, anon, authenticated;

grant select on table public.backup_accounts to authenticated;
grant select on table public.backup_batches to authenticated;
grant select on table public.backup_customers to authenticated;
grant select on table public.backup_transactions to authenticated;
grant select on table public.backup_transaction_audit_logs to authenticated;

drop policy if exists "backup_accounts_select_own" on public.backup_accounts;
create policy "backup_accounts_select_own"
  on public.backup_accounts
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "backup_batches_select_own" on public.backup_batches;
create policy "backup_batches_select_own"
  on public.backup_batches
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "backup_customers_select_own" on public.backup_customers;
create policy "backup_customers_select_own"
  on public.backup_customers
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "backup_transactions_select_own" on public.backup_transactions;
create policy "backup_transactions_select_own"
  on public.backup_transactions
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "backup_transaction_audit_logs_select_own" on public.backup_transaction_audit_logs;
create policy "backup_transaction_audit_logs_select_own"
  on public.backup_transaction_audit_logs
  for select
  to authenticated
  using (auth.uid() = user_id);

-- Looks up whether a previously captured batch was already committed on the
-- server, verifying both account session and installation credential.
create or replace function public.find_backup_batch_confirmation(
  p_batch_id uuid,
  p_device_id uuid,
  p_device_secret text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
  v_active_device_id uuid;
  v_cred_device_id uuid;
  v_expected_secret_hash text;
  v_secret_hash text;
  v_confirmed_at timestamptz;
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
     or pg_catalog.length(pg_catalog.btrim(p_device_secret)) < 32 then
    raise exception 'batch_id, device_id and device_secret are required' using errcode = '22023';
  end if;

  v_secret_hash := pg_catalog.encode(
    pg_catalog.sha256(pg_catalog.convert_to(p_device_secret, 'UTF8')),
    'hex'
  );

  select a.active_device_id, c.active_device_id, c.device_secret_hash
    into v_active_device_id, v_cred_device_id, v_expected_secret_hash
    from public.backup_accounts a
    left join public.backup_device_credentials c
      on c.user_id = a.user_id
   where a.user_id = v_user_id;

  if found then
    if v_active_device_id <> p_device_id
       or v_cred_device_id is null
       or v_cred_device_id <> p_device_id
       or v_expected_secret_hash is null
       or v_expected_secret_hash <> v_secret_hash then
      return pg_catalog.jsonb_build_object('status', 'inactive_device');
    end if;
  end if;

  select confirmed_at
    into v_confirmed_at
    from public.backup_batches
   where user_id = v_user_id
     and batch_id = p_batch_id
     and device_id = p_device_id;

  if found then
    return pg_catalog.jsonb_build_object(
      'status', 'confirmed',
      'batch_id', p_batch_id,
      'confirmed_at', v_confirmed_at
    );
  end if;

  return pg_catalog.jsonb_build_object('status', 'not_found');
end;
$$;

-- Atomically and idempotently publishes a non-empty backup batch for the
-- authenticated, email-verified user while authenticating the installation
-- credential, enforcing single active backup device ownership, account-scoped
-- foreign keys, monotonic record revisions and append-only audit history.
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

  -- Atomically claim single active backup device on first backup; competing
  -- claims serialize on FOR UPDATE and loop cleanly if a racing first attempt
  -- rolled back on validation/FK error.
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

  -- Idempotency: return the original confirmation if this batch was already committed.
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
         updated_at = v_now
   where user_id = v_user_id;

  return pg_catalog.jsonb_build_object(
    'status', 'confirmed',
    'batch_id', p_batch_id,
    'confirmed_at', v_now
  );
end;
$$;

revoke all on function public.find_backup_batch_confirmation(uuid, uuid, text) from public, anon;
grant execute on function public.find_backup_batch_confirmation(uuid, uuid, text) to authenticated;

revoke all on function public.publish_backup_batch(uuid, uuid, text, timestamptz, jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.publish_backup_batch(uuid, uuid, text, timestamptz, jsonb, jsonb, jsonb) to authenticated;
