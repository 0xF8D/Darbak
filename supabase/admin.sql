-- دربك: لوحة الأدمن + التحديث الإجباري + رسالة للكل
-- شغّل هذا الملف مرة وحدة في Supabase (SQL Editor ← New query ← الصق ← Run)
-- بعد ما تشغّل schema.sql. تقدر تعيد تشغيله بدون مشاكل.
--
-- بعدها خل نفسك أدمن بسطر واحد (حط رقمك من الإعدادات في دربك):
--   insert into public.darbak_admins (member_id) values ('رقمك-هنا') on conflict do nothing;

-- ─── الجداول ───

create table if not exists public.darbak_admins (
  member_id uuid primary key
);

create table if not exists public.darbak_config (
  id                  int primary key default 1 check (id = 1),
  min_version         text,
  update_message      text,
  announcement_id     int not null default 0,
  announcement_title  text,
  announcement_body   text,
  announcement_active boolean not null default false,
  updated_at          timestamptz not null default now()
);
insert into public.darbak_config (id) values (1) on conflict do nothing;

alter table public.darbak_profiles add column if not exists app_version text;
alter table public.darbak_profiles add column if not exists created_at timestamptz not null default now();

alter table public.darbak_admins enable row level security;
alter table public.darbak_config enable row level security;
revoke all on public.darbak_admins, public.darbak_config from anon, authenticated;

-- ─── حفظ البروفايل (نفسه + رقم نسخة التطبيق) ───

drop function if exists public.darbak_save_profile(uuid, text, text, text, int, date, int[]);

create or replace function public.darbak_save_profile(
  p_id uuid, p_secret text, p_name text, p_emoji text,
  p_level int, p_week_start date, p_days int[], p_version text default null
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

  insert into darbak_profiles (id, secret_hash, name, emoji, level, week_start, days, app_version, updated_at)
  values (p_id, h, p_name, left(coalesce(nullif(p_emoji, ''), '🦁'), 8),
          greatest(1, least(coalesce(p_level, 1), 999)), p_week_start, clean, left(p_version, 16), now())
  on conflict (id) do update
    set name = excluded.name, emoji = excluded.emoji, level = excluded.level,
        week_start = excluded.week_start, days = excluded.days,
        app_version = coalesce(excluded.app_version, darbak_profiles.app_version),
        updated_at = now()
    where darbak_profiles.secret_hash = h;
  if not found then raise exception 'forbidden'; end if;
end $$;

-- ─── إعدادات عامة (كل التطبيقات تقرأها، بدون حساب) ───

create or replace function public.darbak_config_public()
returns jsonb language sql security definer set search_path = public, extensions as $$
  select jsonb_build_object(
    'minVersion', c.min_version,
    'updateMessage', c.update_message,
    'announcement', case when c.announcement_active and coalesce(c.announcement_title, '') <> '' then
      jsonb_build_object('id', c.announcement_id, 'title', c.announcement_title, 'body', coalesce(c.announcement_body, ''))
    end
  ) from darbak_config c where c.id = 1;
$$;

-- ─── الأدمن ───

create or replace function public.darbak_admin_check(p_id uuid, p_secret text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_check(p_id, p_secret);
  if not exists (select 1 from darbak_admins where member_id = p_id) then
    raise exception 'not_admin';
  end if;
end $$;
revoke execute on function public.darbak_admin_check(uuid, text) from public, anon, authenticated;

-- هل أنا أدمن؟ (يرجع false لأي أحد ثاني، بدون أخطاء)
create or replace function public.darbak_is_admin(p_id uuid, p_secret text)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
begin
  return exists (
    select 1 from darbak_admins a join darbak_profiles p on p.id = a.member_id
    where a.member_id = p_id
      and p.secret_hash = encode(digest(coalesce(p_secret, ''), 'sha256'), 'hex')
  );
end $$;

-- كل الأرقام للوحة
create or replace function public.darbak_admin_stats(p_id uuid, p_secret text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare
  wk date := (date_trunc('week', now() + interval '1 day') - interval '1 day')::date;  -- الأحد
begin
  perform darbak_admin_check(p_id, p_secret);
  return jsonb_build_object(
    'users',        (select count(*) from darbak_profiles),
    'activeDay',    (select count(*) from darbak_profiles where updated_at > now() - interval '24 hours'),
    'activeWeek',   (select count(*) from darbak_profiles where updated_at > now() - interval '7 days'),
    'newWeek',      (select count(*) from darbak_profiles where created_at > now() - interval '7 days'),
    'groups',       (select count(*) from darbak_groups),
    'memberships',  (select count(*) from darbak_members),
    'weekSteps',    (select coalesce(sum(x), 0) from darbak_profiles p, unnest(p.days) x where p.week_start = wk),
    'versions', coalesce((
      select jsonb_agg(jsonb_build_object('version', v, 'count', n) order by n desc)
      from (select coalesce(app_version, 'قديمة') v, count(*) n from darbak_profiles group by 1) t
    ), '[]'::jsonb),
    'users_list', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.name, 'emoji', p.emoji, 'level', p.level,
        'version', coalesce(p.app_version, '—'),
        'updated', extract(epoch from p.updated_at)::bigint,
        'groups', (select count(*) from darbak_members m where m.member_id = p.id),
        'weekSteps', case when p.week_start = wk then (select coalesce(sum(x), 0) from unnest(p.days) x) else 0 end,
        'admin', exists (select 1 from darbak_admins a where a.member_id = p.id)
      ) order by p.updated_at desc)
      from (select * from darbak_profiles order by updated_at desc limit 300) p
    ), '[]'::jsonb),
    'groups_list', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', g.code, 'name', g.name,
        'owner', coalesce((select name from darbak_profiles where id = g.owner_id), '—'),
        'members', (select count(*) from darbak_members m where m.group_code = g.code),
        'created', extract(epoch from g.created_at)::bigint
      ) order by g.created_at desc)
      from darbak_groups g
    ), '[]'::jsonb),
    'config', (
      select jsonb_build_object(
        'minVersion', min_version, 'updateMessage', update_message,
        'title', announcement_title, 'body', announcement_body, 'active', announcement_active,
        'announcementId', announcement_id)
      from darbak_config where id = 1)
  );
end $$;

-- تحديث إجباري (p_min_version فاضي = بدون إجبار)
create or replace function public.darbak_admin_set_update(p_id uuid, p_secret text, p_min_version text, p_message text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_admin_check(p_id, p_secret);
  update darbak_config
     set min_version = nullif(btrim(coalesce(p_min_version, '')), ''),
         update_message = nullif(btrim(coalesce(p_message, '')), ''),
         updated_at = now()
   where id = 1;
end $$;

-- رسالة لكل المستخدمين (تطلع لهم مرة وحدة لين يقفلونها)
create or replace function public.darbak_admin_set_announcement(
  p_id uuid, p_secret text, p_title text, p_body text, p_active boolean
) returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_admin_check(p_id, p_secret);
  update darbak_config
     set announcement_id = case
           when p_active and (coalesce(announcement_title, '') <> coalesce(p_title, '')
                              or coalesce(announcement_body, '') <> coalesce(p_body, '')
                              or not announcement_active)
           then announcement_id + 1 else announcement_id end,
         announcement_title = left(nullif(btrim(coalesce(p_title, '')), ''), 80),
         announcement_body = left(nullif(btrim(coalesce(p_body, '')), ''), 500),
         announcement_active = coalesce(p_active, false),
         updated_at = now()
   where id = 1;
end $$;

-- يحذف مجموعة (لأي سبب)
create or replace function public.darbak_admin_delete_group(p_id uuid, p_secret text, p_code text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_admin_check(p_id, p_secret);
  delete from darbak_groups where code = p_code;
end $$;

-- يحذف مستخدم (يطلع من كل المجموعات، ومجموعاته تنحذف)
create or replace function public.darbak_admin_delete_user(p_id uuid, p_secret text, p_member uuid)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_admin_check(p_id, p_secret);
  if p_member = p_id then raise exception 'forbidden'; end if;
  delete from darbak_profiles where id = p_member;
end $$;
