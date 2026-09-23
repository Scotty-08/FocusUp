-- FocusUp backend schema for Supabase (Postgres + Row Level Security).
--
-- Run this whole file once in the Supabase dashboard: SQL Editor -> New
-- query -> paste -> Run. It is idempotent (safe to re-run).
--
-- Model:
--   auth.users   Supabase's own accounts table (Sign in with Apple / email).
--   profiles     one public player card per account: handle, avatar, level...
--   friendships  a request between two accounts; 'pending' until accepted.
--   cheers       short encouragement messages between accepted friends.
--   canvas_pending_assignments  hand-off from the desktop/browser
--                extension (FocusUpCanvasWeb) to the app -- see that
--                table's own comment below.
--
-- Security model: the iOS app talks to this database directly with the
-- public "anon" key + the signed-in user's token, so Row Level Security is
-- the ONLY thing protecting the data. profiles is the only table clients
-- read/write directly (own row only for writes). friendships and cheers
-- are reached exclusively through the SECURITY DEFINER functions below,
-- which enforce the rules (no self-friending, only the addressee can
-- accept, cheers only between accepted friends, rate limit).

-- ---------------------------------------------------------------- profiles

create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    username text not null,
    display_name text,
    avatar jsonb,
    level int not null default 1,
    total_xp int not null default 0,
    streak int not null default 0,
    completed_count int not null default 0,
    updated_at timestamptz not null default now(),
    constraint profiles_username_format check (username ~ '^[a-z0-9_]{3,20}$'),
    constraint profiles_stats_sane check (
        level between 1 and 10000
        and total_xp between 0 and 100000000
        and streak between 0 and 100000
        and completed_count between 0 and 10000000
    )
);

create unique index if not exists profiles_username_key on public.profiles (username);

alter table public.profiles enable row level security;

-- Any signed-in user can look profiles up (needed to add friends by
-- handle and to show friends' cards). Nothing sensitive lives here: no
-- email, no date of birth, no app usage data.
drop policy if exists "profiles readable by signed-in users" on public.profiles;
create policy "profiles readable by signed-in users"
    on public.profiles for select to authenticated using (true);

drop policy if exists "insert own profile" on public.profiles;
create policy "insert own profile"
    on public.profiles for insert to authenticated with check (id = auth.uid());

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile"
    on public.profiles for update to authenticated
    using (id = auth.uid()) with check (id = auth.uid());

-- ------------------------------------------------------------- friendships

create table if not exists public.friendships (
    id uuid primary key default gen_random_uuid(),
    requester_id uuid not null references auth.users (id) on delete cascade,
    addressee_id uuid not null references auth.users (id) on delete cascade,
    status text not null default 'pending' check (status in ('pending', 'accepted')),
    created_at timestamptz not null default now(),
    constraint friendships_no_self check (requester_id <> addressee_id)
);

-- One row per unordered pair, regardless of who asked first.
create unique index if not exists friendships_pair_key
    on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

alter table public.friendships enable row level security;

-- Read-only for the two people involved. All writes go through the
-- functions below (no insert/update/delete policies on purpose).
drop policy if exists "friendships visible to participants" on public.friendships;
create policy "friendships visible to participants"
    on public.friendships for select to authenticated
    using (auth.uid() in (requester_id, addressee_id));

-- ------------------------------------------------------------------ cheers

create table if not exists public.cheers (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references auth.users (id) on delete cascade,
    recipient_id uuid not null references auth.users (id) on delete cascade,
    message text not null check (char_length(message) between 1 and 80),
    created_at timestamptz not null default now(),
    seen_at timestamptz
);

create index if not exists cheers_recipient_idx on public.cheers (recipient_id, created_at desc);

-- RLS on with NO policies: clients can't touch the table directly, only
-- through send_cheer / my_cheers / mark_cheers_seen.
alter table public.cheers enable row level security;

-- --------------------------------------------------------------- functions

-- Returns: 'sent' | 'accepted' | 'already_friends' | 'already_sent'
--          | 'not_found' | 'self' | 'no_profile'
-- If the other person already asked YOU, this accepts their request.
create or replace function public.send_friend_request(p_username text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
    target uuid;
    existing public.friendships;
begin
    if me is null then
        raise exception 'not authenticated';
    end if;
    if not exists (select 1 from public.profiles where id = me) then
        return 'no_profile';
    end if;

    select id into target from public.profiles
        where username = lower(trim(both '@' from trim(p_username)));
    if target is null then
        return 'not_found';
    end if;
    if target = me then
        return 'self';
    end if;

    select * into existing from public.friendships
        where least(requester_id, addressee_id) = least(me, target)
          and greatest(requester_id, addressee_id) = greatest(me, target);
    if found then
        if existing.status = 'accepted' then
            return 'already_friends';
        end if;
        if existing.addressee_id = me then
            update public.friendships set status = 'accepted' where id = existing.id;
            return 'accepted';
        end if;
        return 'already_sent';
    end if;

    insert into public.friendships (requester_id, addressee_id) values (me, target);
    return 'sent';
end;
$$;

-- Only the person who was asked can accept.
create or replace function public.accept_friend_request(p_request_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
    update public.friendships
        set status = 'accepted'
        where id = p_request_id
          and addressee_id = auth.uid()
          and status = 'pending';
$$;

-- Decline an incoming request, cancel an outgoing one, or unfriend.
create or replace function public.remove_friendship(p_friendship_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
    delete from public.friendships
        where id = p_friendship_id
          and auth.uid() in (requester_id, addressee_id);
$$;

-- Everyone the caller is connected to (accepted friends AND pending
-- requests in either direction), with their player card.
create or replace function public.list_friends()
returns table (
    friendship_id uuid,
    status text,
    is_incoming boolean,
    id uuid,
    username text,
    display_name text,
    avatar jsonb,
    level int,
    total_xp int,
    streak int,
    completed_count int
)
language sql
stable
security definer
set search_path = public
as $$
    select f.id, f.status, (f.addressee_id = auth.uid()),
           p.id, p.username, p.display_name, p.avatar,
           p.level, p.total_xp, p.streak, p.completed_count
    from public.friendships f
    join public.profiles p
      on p.id = case when f.requester_id = auth.uid() then f.addressee_id else f.requester_id end
    where auth.uid() in (f.requester_id, f.addressee_id)
    order by p.total_xp desc;
$$;

-- Returns: 'sent' | 'not_friends' | 'too_soon' | 'empty'
create or replace function public.send_cheer(p_recipient uuid, p_message text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    me uuid := auth.uid();
begin
    if me is null then
        raise exception 'not authenticated';
    end if;
    if char_length(trim(coalesce(p_message, ''))) = 0 then
        return 'empty';
    end if;
    if not exists (
        select 1 from public.friendships
        where status = 'accepted'
          and least(requester_id, addressee_id) = least(me, p_recipient)
          and greatest(requester_id, addressee_id) = greatest(me, p_recipient)
    ) then
        return 'not_friends';
    end if;
    if exists (
        select 1 from public.cheers
        where sender_id = me and recipient_id = p_recipient
          and created_at > now() - interval '1 minute'
    ) then
        return 'too_soon';
    end if;

    insert into public.cheers (sender_id, recipient_id, message)
        values (me, p_recipient, left(trim(p_message), 80));
    return 'sent';
end;
$$;

-- The caller's 30 most recent received cheers.
create or replace function public.my_cheers()
returns table (
    id uuid,
    sender_id uuid,
    sender_username text,
    sender_display_name text,
    message text,
    created_at timestamptz,
    seen boolean
)
language sql
stable
security definer
set search_path = public
as $$
    select c.id, c.sender_id, p.username, p.display_name, c.message, c.created_at,
           (c.seen_at is not null)
    from public.cheers c
    join public.profiles p on p.id = c.sender_id
    where c.recipient_id = auth.uid()
    order by c.created_at desc
    limit 30;
$$;

create or replace function public.mark_cheers_seen()
returns void
language sql
security definer
set search_path = public
as $$
    update public.cheers
        set seen_at = now()
        where recipient_id = auth.uid() and seen_at is null;
$$;

-- Signed-in users only; anonymous callers get nothing.
revoke all on function public.send_friend_request(text) from public, anon;
revoke all on function public.accept_friend_request(uuid) from public, anon;
revoke all on function public.remove_friendship(uuid) from public, anon;
revoke all on function public.list_friends() from public, anon;
revoke all on function public.send_cheer(uuid, text) from public, anon;
revoke all on function public.my_cheers() from public, anon;
revoke all on function public.mark_cheers_seen() from public, anon;

grant execute on function public.send_friend_request(text) to authenticated;
grant execute on function public.accept_friend_request(uuid) to authenticated;
grant execute on function public.remove_friendship(uuid) to authenticated;
grant execute on function public.list_friends() to authenticated;
grant execute on function public.send_cheer(uuid, text) to authenticated;
grant execute on function public.my_cheers() to authenticated;
grant execute on function public.mark_cheers_seen() to authenticated;

-- ------------------------------------------------ canvas_pending_assignments

-- Hand-off table for the desktop/browser extension (FocusUpCanvasWeb):
-- it reads a signed-in student's upcoming Canvas assignments from
-- whatever browser session is open on that computer, and writes them
-- here. The app pulls its own rows down on refresh (see
-- BackendClient.fetchPendingCanvasAssignments), merges them into the
-- Quest Log, then deletes them (clearPendingCanvasAssignments) so a row
-- is only ever delivered once. This is the network equivalent of what
-- CanvasExtensionStore.swift does locally for the Safari extension on
-- iOS -- same idea, just for a device that isn't the phone.
--
-- id is the Canvas assignment's own id, not a table-wide unique value
-- on its own -- (user_id, id) together are the key, since the same
-- numeric id can exist on a different school's Canvas for a different
-- user.
create table if not exists public.canvas_pending_assignments (
    user_id uuid not null references auth.users (id) on delete cascade,
    id bigint not null,
    name text not null,
    due_at timestamptz,
    html_url text not null,
    created_at timestamptz not null default now(),
    primary key (user_id, id)
);

alter table public.canvas_pending_assignments enable row level security;

-- Own rows only, both ways -- the extension inserts/updates as itself,
-- the app reads and then deletes what it just merged. No cross-user
-- access in either direction, and no function needed (unlike
-- friendships/cheers) since there's no interaction between two users
-- here to arbitrate.
drop policy if exists "read own pending canvas assignments" on public.canvas_pending_assignments;
create policy "read own pending canvas assignments"
    on public.canvas_pending_assignments for select to authenticated
    using (user_id = auth.uid());

drop policy if exists "insert own pending canvas assignments" on public.canvas_pending_assignments;
create policy "insert own pending canvas assignments"
    on public.canvas_pending_assignments for insert to authenticated
    with check (user_id = auth.uid());

drop policy if exists "update own pending canvas assignments" on public.canvas_pending_assignments;
create policy "update own pending canvas assignments"
    on public.canvas_pending_assignments for update to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "delete own pending canvas assignments" on public.canvas_pending_assignments;
create policy "delete own pending canvas assignments"
    on public.canvas_pending_assignments for delete to authenticated
    using (user_id = auth.uid());
