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

-- 2) ORDERS -----------------------------------------------------------------
create table if not exists public.orders (
  id             uuid primary key default gen_random_uuid(),
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

alter table public.orders enable row level security;

-- Visitors may place (insert) orders, but cannot read anyone's orders.
drop policy if exists "Public can place orders" on public.orders;
create policy "Public can place orders"
  on public.orders for insert
  to anon, authenticated
  with check (jsonb_typeof(items) = 'array' and status = 'pending');

-- 3) SEED PRODUCTS ----------------------------------------------------------
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
