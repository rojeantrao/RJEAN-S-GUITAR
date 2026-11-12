-- RJEAN Guitars: Supabase schema
-- Run this whole file in Supabase Dashboard > SQL Editor > New query > Run

-- 1) PRODUCTS ---------------------------------------------------------------
create table if not exists public.products (
  id          bigint primary key,
  name        text not null,
  brand       text not null,
  category    text not null default 'Electric Guitars',
  price       numeric(10,2) not null check (price >= 0),
  rating      numeric(2,1) default 0,
  image       text,
  description text,
  created_at  timestamptz not null default now()
);

alter table public.products enable row level security;

drop policy if exists "Public can read products" on public.products;
create policy "Public can read products"
  on public.products for select
  to anon, authenticated
  using (true);

-- 2) CUSTOMER PROFILES ------------------------------------------------------
-- Admins are regular Supabase Auth users explicitly granted membership here.
-- Never store passwords in this table and never allow public signup to grant admin.
create table if not exists public.admin_users (
  id         uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;
revoke all on table public.admin_users from anon, authenticated;
grant select on table public.admin_users to authenticated;
drop policy if exists "Admins can read own membership" on public.admin_users;
create policy "Admins can read own membership"
  on public.admin_users for select
  to authenticated
  using (auth.uid() = id);

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users
    where id = (select auth.uid())
  );
$$;
revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to authenticated;

create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '',
  last_name  text not null default '',
  phone      text not null default '',
  address    text not null default '',
  email      text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
drop policy if exists "Customers can read own profile" on public.profiles;
create policy "Customers can read own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);
drop policy if exists "Admins can read all customer profiles" on public.profiles;
create policy "Admins can read all customer profiles"
  on public.profiles for select
  to authenticated
  using (public.is_site_admin());
drop policy if exists "Customers can update own profile" on public.profiles;
create policy "Customers can update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id and not public.is_site_admin());

create or replace function public.create_customer_profile()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, first_name, last_name, phone, address, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'address', ''),
    coalesce(new.email, '')
  )
  on conflict (id) do update set
    first_name = excluded.first_name,
    last_name = excluded.last_name,
    phone = excluded.phone,
    address = excluded.address,
    email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute procedure public.create_customer_profile();

insert into public.profiles (id, first_name, last_name, phone, address, email)
select
  id,
  coalesce(raw_user_meta_data ->> 'first_name', ''),
  coalesce(raw_user_meta_data ->> 'last_name', ''),
  coalesce(raw_user_meta_data ->> 'phone', ''),
  coalesce(raw_user_meta_data ->> 'address', ''),
  coalesce(email, '')
from auth.users
on conflict (id) do nothing;

-- 3) ORDERS -----------------------------------------------------------------
create table if not exists public.orders (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid references auth.users(id) on delete set null,
  email          text not null default '',
  first_name     text not null,
  last_name      text not null,
  address        text not null,
  phone          text not null,
  payment_method text not null,
  items          jsonb not null,
  total          numeric(12,2) not null check (total > 0),
  status         text not null default 'pending',
  created_at     timestamptz not null default now()
);

alter table public.orders add column if not exists user_id uuid references auth.users(id) on delete set null;
alter table public.orders add column if not exists email text not null default '';

alter table public.orders enable row level security;

-- Only signed-in customers can create/read their own orders.
drop policy if exists "Public can place orders" on public.orders;
drop policy if exists "Customers can place own orders" on public.orders;
create policy "Customers can place own orders"
  on public.orders for insert
  to authenticated
  with check (auth.uid() = user_id and jsonb_typeof(items) = 'array' and status = 'pending');
drop policy if exists "Customers can read own orders" on public.orders;
create policy "Customers can read own orders"
  on public.orders for select
  to authenticated
  using (auth.uid() = user_id);
drop policy if exists "Admins can read all orders" on public.orders;
create policy "Admins can read all orders"
  on public.orders for select
  to authenticated
  using (public.is_site_admin());

-- ADMIN ACCOUNT SETUP -------------------------------------------------------
-- 1) Create the administrator's Auth user in Supabase Dashboard > Authentication > Users.
-- 2) Add that existing user's UUID to admin_users from the SQL Editor. Replace the email:
-- insert into public.admin_users (id)
-- select id from auth.users where lower(email) = lower('owner@example.com')
-- on conflict (id) do nothing;
-- Do not create public admin signup or accept admin status from browser metadata.

-- 4) SEED PRODUCTS ----------------------------------------------------------
insert into public.products (id, name, brand, category, price, rating, image, description) values
(1, 'Fender Player Stratocaster', 'Fender', 'Electric Guitars', 42500, 4.8, 'Fender Standard Stratocaster.jfif', 'Classic tone and sleek style. Perfect for stage and studio performance.'),
(2, 'Gibson Les Paul Standard', 'Gibson', 'Electric Guitars', 145000, 5.0, 'Gibson Les Paul Standard.jpg', 'Iconic sound and sustain. Craftsmanship at its absolute finest.'),
(3, 'Yamaha Pacifica 112V', 'Yamaha', 'Electric Guitars', 16500, 4.6, 'Yamaha Pacifica 112V.jfif', 'Best-in-class performance for versatile guitar players.'),
(4, 'Ibanez RG Standard', 'Ibanez', 'Electric Guitars', 28000, 4.7, 'Ibanez RG Standard.jfif', 'Built for speed and high-octane modern metal tone.'),
(5, 'Squier Classic Vibe ''60s', 'Squier', 'Electric Guitars', 24900, 4.5, 'Squier Classic Vibe ''60s.jfif', 'A tribute to 1960s Fender innovation with vintage aesthetics.'),
(6, 'Epiphone Les Paul Custom', 'Epiphone', 'Electric Guitars', 41000, 4.7, 'Epiphone Les Paul Custom.jfif', 'Tuxedo-style elegant design combined with rich humbucking tone.'),
(7, 'Fermata ST-1 Pro Stratocaster', 'Fermata', 'Electric Guitars', 10200, 4.9, 'Fermata ST-1 Pro Stratocaster.jfif', 'Roasted maple neck, stainless steel frets, and Alnico 5 pickups with coil-split.'),
(8, 'Fender Standard Stratocaster', 'Fender', 'Electric Guitars', 44000, 4.9, 'Fender Standard Stratocaster.jfif', 'Contoured body with a Modern C neck profile and singing single-coil pickups.'),
(9, 'Fender Standard Telecaster', 'Fender', 'Electric Guitars', 44000, 4.9, 'Fender Standard Telecaster.jfif', 'Crystal-clear, bright twang with a string-through-body bridge for rock-solid sustain.')
on conflict (id) do update set
  name = excluded.name, brand = excluded.brand, category = excluded.category,
  price = excluded.price, rating = excluded.rating, image = excluded.image,
  description = excluded.description;
