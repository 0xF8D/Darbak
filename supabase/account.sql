-- دربك: حذف الحساب والبيانات (مطلوب من أبل)
-- شغّله مرة وحدة في Supabase (SQL Editor ← New query ← الصق ← Run). تقدر تعيد تشغيله.

create or replace function public.darbak_delete_me(p_id uuid, p_secret text)
returns void language plpgsql security definer set search_path = public, extensions as $$
begin
  perform darbak_check(p_id, p_secret);
  -- يحذف بروفايلك، ويطلعك من كل المجموعات، ويحذف المجموعات اللي أنت صاحبها
  delete from darbak_profiles where id = p_id;
  delete from darbak_bans where member_id = p_id;
end $$;
