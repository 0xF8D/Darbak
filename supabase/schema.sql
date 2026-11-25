-- دربك: مجموعات الشلة
-- شغّل هذا الملف مرة وحدة في Supabase: SQL Editor ← New query ← الصق ← Run
--
-- الجداول مقفلة بالكامل (ما أحد يقدر يقرأها أو يعدلها مباشرة).
-- التطبيق يتعامل فقط مع الدوال تحت، وكل دالة تتأكد من «السر» حق الجهاز.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.darbak_profiles (
  id          uuid primary key,
  secret_hash text not null,
  name        text not null check (char_length(name) between 1 and 24),
  emoji       text not null default '🦁',
  level       int  not null default 1,
  week_start  date,
  days        int[] not null default array[0,0,0,0,0,0,0],
  updated_at  timestamptz not null default now()
);

create table if not exists public.darbak_groups (
  code       text primary key,
  name       text not null check (char_length(name) between 1 and 30),
  owner_id   uuid not null references public.darbak_profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.darbak_members (
  group_code text not null references public.darbak_groups(code) on delete cascade,
  member_id  uuid not null references public.darbak_profiles(id) on delete cascade,
  joined_at  timestamptz not null default now(),
  primary key (group_code, member_id)
);

create table if not exists public.darbak_bans (
  group_code text not null references public.darbak_groups(code) on delete cascade,
  member_id  uuid not null,
  primary key (group_code, member_id)
);

alter table public.darbak_profiles enable row level security;
alter table public.darbak_groups   enable row level security;
alter table public.darbak_members  enable row level security;
alter table public.darbak_bans     enable row level security;
revoke all on public.darbak_profiles, public.darbak_groups, public.darbak_members, public.darbak_bans
  from anon, authenticated;

-- يتأكد إن الجهاز هو صاحب الحساب
create or replace function public.darbak_check(p_id uuid, p_secret text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  if not exists (
    select 1 from darbak_profiles
    where id = p_id and secret_hash = encode(digest(coalesce(p_secret, ''), 'sha256'), 'hex')
  ) then
    raise exception 'forbidden';
  end if;
end $$;
revoke execute on function public.darbak_check(uuid, text) from public, anon, authenticated;

-- يحفظ اسمك ورمزك وخطوات أسبوعك (أول مرة ينشئ الحساب)
create or replace function public.darbak_save_profile(
  p_id uuid, p_secret text, p_name text, p_emoji text,
  p_level int, p_week_start date, p_days int[]
) returns void language plpgsql security definer set search_path = public, extensions as $$
declare
  h text;
  clean int[];
begin
  if char_length(coalesce(p_secret, '')) < 16 then raise exception 'forbidden'; end if;
  h := encode(digest(p_secret, 'sha256'), 'hex');
  p_name := left(btrim(coalesce(p_name, '')), 24);
  if p_name = '' then raise exception 'name_required'; end if;
  if coalesce(array_length(p_days, 1), 0) <> 7 then raise exception 'bad_days'; end if;
  select array_agg(greatest(0, least(coalesce(x, 0), 150000)) order by i)
    into clean from unnest(p_days) with ordinality as t(x, i);

  insert into darbak_profiles (id, secret_hash, name, emoji, level, week_start, days, updated_at)
  values (p_id, h, p_name, left(coalesce(nullif(p_emoji, ''), '🦁'), 8),
          greatest(1, least(coalesce(p_level, 1), 999)), p_week_start, clean, now())
  on conflict (id) do update
    set name = excluded.name, emoji = excluded.emoji, level = excluded.level,
        week_start = excluded.week_start, days = excluded.days, updated_at = now()
    where darbak_profiles.secret_hash = h;
  if not found then raise exception 'forbidden'; end if;
end $$;

-- ينشئ مجموعة بكود عشوائي من ٨ خانات
create or replace function public.darbak_create_group(p_id uuid, p_secret text, p_name text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text;
  b bytea;
  i int;
begin
  perform darbak_check(p_id, p_secret);
  if (select count(*) from darbak_groups where owner_id = p_id) >= 10 then
    raise exception 'too_many';
  end if;
  p_name := left(btrim(coalesce(p_name, '')), 30);
  if p_name = '' then p_name := 'الشلة'; end if;
  loop
    b := gen_random_bytes(8);
    c := '';
    for i in 0..7 loop
      c := c || substr(alphabet, 1 + (get_byte(b, i) % 32), 1);
    end loop;
    exit when not exists (select 1 from darbak_groups where code = c);
  end loop;
  insert into darbak_groups (code, name, owner_id) values (c, p_name, p_id);
  insert into darbak_members (group_code, member_id) values (c, p_id);
  return c;
end $$;

-- يدخلك مجموعة بالكود
create or replace function public.darbak_join_group(p_id uuid, p_secret text, p_code text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare
  g darbak_groups;
begin
  perform darbak_check(p_id, p_secret);
  select * into g from darbak_groups where code = upper(btrim(coalesce(p_code, '')));
  if not found then raise exception 'not_found'; end if;
  if exists (select 1 from darbak_bans where group_code = g.code and member_id = p_id) then
    raise exception 'banned';
  end if;
  if not exists (select 1 from darbak_members where group_code = g.code and member_id = p_id)
     and (select count(*) from darbak_members where group_code = g.code) >= 50 then
    raise exception 'full';
  end if;
  insert into darbak_members (group_code, member_id) values (g.code, p_id) on conflict do nothing;
  return g.name;
end $$;

-- تطلع من مجموعة (لو أنت صاحبها تنحذف المجموعة كلها)
create or replace function public.darbak_leave_group(p_id uuid, p_secret text, p_code text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_check(p_id, p_secret);
  if exists (select 1 from darbak_groups where code = p_code and owner_id = p_id) then
    delete from darbak_groups where code = p_code;
  else
    delete from darbak_members where group_code = p_code and member_id = p_id;
  end if;
end $$;

-- صاحب المجموعة بس: يطلع شخص (وما يقدر يرجع بنفس الكود)
create or replace function public.darbak_kick(p_id uuid, p_secret text, p_code text, p_member uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_check(p_id, p_secret);
  if not exists (select 1 from darbak_groups where code = p_code and owner_id = p_id) then
    raise exception 'not_owner';
  end if;
  if p_member = p_id then raise exception 'forbidden'; end if;
  delete from darbak_members where group_code = p_code and member_id = p_member;
  insert into darbak_bans (group_code, member_id) values (p_code, p_member) on conflict do nothing;
end $$;

-- كل مجموعاتك وأعضاؤها وخطواتهم
create or replace function public.darbak_my_groups(p_id uuid, p_secret text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_check(p_id, p_secret);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'code', g.code,
      'name', g.name,
      'owner', g.owner_id,
      'members', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'emoji', p.emoji,
          'level', p.level,
          'week', to_char(p.week_start, 'YYYY-MM-DD'),
          'days', to_jsonb(p.days),
          'updated', extract(epoch from p.updated_at)::bigint
        ) order by m.joined_at), '[]'::jsonb)
        from darbak_members m join darbak_profiles p on p.id = m.member_id
        where m.group_code = g.code
      )
    ) order by me.joined_at)
    from darbak_groups g
    join darbak_members me on me.group_code = g.code and me.member_id = p_id
  ), '[]'::jsonb);
end $$;
