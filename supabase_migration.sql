-- supabase/migrations/001_calendar_integration.sql
-- Run this once in your Supabase SQL editor.
-- Enables RLS so users can only read/write their own data.

-- ── calendar_tokens ────────────────────────────────────────────────────────
-- Stores one Google OAuth refresh_token per user.
-- Only the Vercel service-role key may write here (never the Flutter client).

create table if not exists public.calendar_tokens (
  user_id     uuid        primary key references auth.users on delete cascade,
  refresh_token text      not null,
  updated_at  timestamptz not null default now()
);

alter table public.calendar_tokens enable row level security;

-- Users can only read their own token row (for diagnostics).
-- Vercel uses the service_role key and bypasses RLS entirely.
create policy "Users read own token"
  on public.calendar_tokens for select
  using (auth.uid() = user_id);

-- ── calendar_events_cache ──────────────────────────────────────────────────
-- Cached Google Calendar events. TTL is enforced in the Vercel function.
-- Flutter reads directly from here between Vercel refreshes.

create table if not exists public.calendar_events_cache (
  id           text        not null,
  user_id      uuid        not null references auth.users on delete cascade,
  title        text        not null,
  source       text        not null default 'google_calendar',
  event_date   date        not null,
  start_time   text        not null,
  end_time     text        not null,
  location     text        not null default '',
  course_code  text        not null default '',
  description  text        not null default '',
  is_all_day   boolean     not null default false,
  cached_at    timestamptz not null default now(),

  primary key (id, user_id)
);

alter table public.calendar_events_cache enable row level security;

create policy "Users read own events"
  on public.calendar_events_cache for select
  using (auth.uid() = user_id);

-- Index for fast date-range lookups
create index if not exists idx_calendar_events_user_date
  on public.calendar_events_cache (user_id, event_date);

-- Index so the cache TTL check is fast
create index if not exists idx_calendar_events_cached_at
  on public.calendar_events_cache (user_id, cached_at);

-- ── users ────────────────────────────────────────────────────────────────
-- Public profile table extending auth.users

create table if not exists public.users (
  id          uuid        primary key references auth.users on delete cascade,
  name        text,
  email       text,
  avatar_url  text,
  created_at  timestamptz not null default now()
);

alter table public.users enable row level security;
create policy "Users can read own profile" on public.users for select using (auth.uid() = id);
create policy "Users can update own profile" on public.users for update using (auth.uid() = id);

-- ── classes ─────────────────────────────────────────────────────────────

create table if not exists public.classes (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references auth.users on delete cascade,
  course_name   text        not null,
  course_code   text        not null,
  start_time    text        not null,
  end_time      text        not null,
  location      text        not null default '',
  color         text        not null default 'primary',
  instructor    text        not null default '',
  created_at    timestamptz not null default now()
);

alter table public.classes enable row level security;
create policy "Users read own classes" on public.classes for select using (auth.uid() = user_id);
create policy "Users insert own classes" on public.classes for insert with check (auth.uid() = user_id);
create policy "Users update own classes" on public.classes for update using (auth.uid() = user_id);
create policy "Users delete own classes" on public.classes for delete using (auth.uid() = user_id);

-- ── assignments ──────────────────────────────────────────────────────────

create table if not exists public.assignments (
  id            text        not null, -- Canvas assignment ID or generated UUID
  user_id       uuid        not null references auth.users on delete cascade,
  title         text        not null,
  course_name   text        not null,
  course_code   text        not null default '',
  course_color  text        not null default 'primary',
  due_date      text        not null,
  status        text        not null default 'pending',
  points        integer     not null default 0,
  created_at    timestamptz not null default now(),
  primary key (id, user_id)
);

alter table public.assignments enable row level security;
create policy "Users read own assignments" on public.assignments for select using (auth.uid() = user_id);
create policy "Users insert own assignments" on public.assignments for insert with check (auth.uid() = user_id);
create policy "Users update own assignments" on public.assignments for update using (auth.uid() = user_id);
create policy "Users delete own assignments" on public.assignments for delete using (auth.uid() = user_id);

-- ── tasks ───────────────────────────────────────────────────────────────

create table if not exists public.tasks (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users on delete cascade,
  title       text        not null,
  due_date    text        not null,
  priority    text        not null default 'medium',
  completed   boolean     not null default false,
  source      text        not null default 'personal',
  created_at  timestamptz not null default now()
);

alter table public.tasks enable row level security;
create policy "Users read own tasks" on public.tasks for select using (auth.uid() = user_id);
create policy "Users insert own tasks" on public.tasks for insert with check (auth.uid() = user_id);
create policy "Users update own tasks" on public.tasks for update using (auth.uid() = user_id);
create policy "Users delete own tasks" on public.tasks for delete using (auth.uid() = user_id);

-- ── user_settings ───────────────────────────────────────────────────────
-- Store Canvas token. Vercel backend reads this.

create table if not exists public.user_settings (
  user_id       uuid        primary key references auth.users on delete cascade,
  canvas_token  text,
  canvas_domain text,
  updated_at    timestamptz not null default now()
);

alter table public.user_settings enable row level security;
create policy "Users read own settings" on public.user_settings for select using (auth.uid() = user_id);
create policy "Users update own settings" on public.user_settings for update using (auth.uid() = user_id);
create policy "Users insert own settings" on public.user_settings for insert with check (auth.uid() = user_id);

