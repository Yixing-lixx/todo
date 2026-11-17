-- 日程任务本：在 Supabase 后台 SQL Editor 里整段粘贴，点 Run 运行一次即可（重复运行也安全）

create table if not exists public.items (
  user_id    uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  kind       text        not null check (kind in ('task','sum','cfg')),
  id         text        not null,
  data       jsonb,
  deleted    boolean     not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, id)
);
create index if not exists items_user_updated on public.items (user_id, updated_at);

-- 每次写入都用服务器时间，方便增量同步
create or replace function public.items_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists items_touch on public.items;
create trigger items_touch before insert or update on public.items
for each row execute function public.items_touch();

-- 行级安全：每个人只能读写自己的数据
alter table public.items enable row level security;
drop policy if exists "items_select_own" on public.items;
drop policy if exists "items_insert_own" on public.items;
drop policy if exists "items_update_own" on public.items;
drop policy if exists "items_delete_own" on public.items;
create policy "items_select_own" on public.items for select to authenticated using (auth.uid() = user_id);
create policy "items_insert_own" on public.items for insert to authenticated with check (auth.uid() = user_id);
create policy "items_update_own" on public.items for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "items_delete_own" on public.items for delete to authenticated using (auth.uid() = user_id);

grant select, insert, update, delete on public.items to authenticated;
revoke all on public.items from anon;
