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
