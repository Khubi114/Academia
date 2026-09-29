-- supabase_migration_002_sync.sql
-- Run AFTER supabase_migration.sql, in the Supabase SQL editor. Idempotent.
-- Adds what incremental Google Calendar sync and Canvas change detection need.

-- ── calendar: sync bookkeeping ───────────────────────────────────────────
alter table public.calendar_tokens add column if not exists scope text;

create table if not exists public.calendar_sync_state (
  user_id     uuid        primary key references auth.users on delete cascade,
  sync_token  text,
  synced_at   timestamptz not null default now()
);
alter table public.calendar_sync_state enable row level security;
-- No client policies: only the service-role key (Vercel) reads/writes this.

-- ── assignments: fields for change detection + calendar mirroring ────────
alter table public.assignments add column if not exists course_id         text;
alter table public.assignments add column if not exists due_at            timestamptz;
alter table public.assignments add column if not exists submitted         boolean not null default false;
alter table public.assignments add column if not exists score             numeric;
alter table public.assignments add column if not exists description       text not null default '';
alter table public.assignments add column if not exists html_url          text not null default '';
alter table public.assignments add column if not exists content_hash      text;
alter table public.assignments add column if not exists calendar_event_id text;
alter table public.assignments add column if not exists updated_at        timestamptz not null default now();

-- due_date is a display string; allow it to be empty for undated work.
alter table public.assignments alter column due_date set default 'No due date';

create index if not exists idx_assignments_user_due on public.assignments (user_id, due_at);

-- ── canvas_courses ("subjects") ──────────────────────────────────────────
create table if not exists public.canvas_courses (
  id           text        not null,
  user_id      uuid        not null references auth.users on delete cascade,
  name         text        not null,
  course_code  text        not null default '',
  term         text        not null default '',
  updated_at   timestamptz not null default now(),
  primary key (id, user_id)
);
alter table public.canvas_courses enable row level security;
create policy "Users read own courses" on public.canvas_courses
  for select using (auth.uid() = user_id);

-- ── canvas_modules ───────────────────────────────────────────────────────
create table if not exists public.canvas_modules (
  id            text        not null,
  user_id       uuid        not null references auth.users on delete cascade,
  course_id     text        not null,
  name          text        not null,
  position      integer     not null default 0,
  state         text        not null default '',
  items_count   integer     not null default 0,
  unlock_at     timestamptz,
  content_hash  text,
  primary key (id, user_id)
);
alter table public.canvas_modules enable row level security;
create policy "Users read own modules" on public.canvas_modules
  for select using (auth.uid() = user_id);

-- ── user_settings ────────────────────────────────────────────────────────
-- Opt-in: mirror Canvas due dates into Google Calendar.
alter table public.user_settings
  add column if not exists canvas_calendar_sync boolean not null default false;
