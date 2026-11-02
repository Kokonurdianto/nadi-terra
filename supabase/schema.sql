-- =====================================================================
--  NADI TERRA SMART FARMING — skema database Supabase
--  Cara pakai: Supabase > SQL Editor > New query > tempel seluruh isi
--  file ini > Run. Aman dijalankan ulang.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ADMIN
--    Daftar akun yang boleh input harga, memoderasi, dan menjawab
--    sebagai pakar. Akun dibuat di Authentication > Users, lalu
--    didaftarkan dengan perintah di bagian paling bawah file ini.
-- ---------------------------------------------------------------------
create table if not exists public.admin (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  nama       text,
  created_at timestamptz not null default now()
);
alter table public.admin enable row level security;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (select 1 from public.admin where user_id = auth.uid());
$$;

drop policy if exists "admin melihat dirinya" on public.admin;
create policy "admin melihat dirinya" on public.admin
  for select using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- 2. HARGA KOMODITAS
--    metode 'admin'    = diinput tim dari pengumuman resmi (mis. TBS Disbun)
--    metode 'otomatis' = ditarik robot terjadwal (PIHPS Bank Indonesia)
-- ---------------------------------------------------------------------
create table if not exists public.harga (
  id            bigint generated always as identity primary key,
  komoditas     text not null check (char_length(komoditas) between 2 and 80),
  kategori      text not null check (kategori in
                  ('Perkebunan','Pangan','Kelautan','Kehutanan','Hortikultura','Peternakan')),
  wilayah       text not null default 'Sumatera Utara',
  satuan        text not null default 'kg',
  harga         numeric(14,2) not null check (harga > 0),
  periode_mulai date not null,
  periode_akhir date,
  tingkat       text not null default 'produsen' check (tingkat in
                  ('produsen','konsumen','pedagang besar','ekspor')),
  sumber        text not null check (char_length(sumber) between 2 and 120),
  sumber_url    text,
  metode        text not null default 'admin' check (metode in ('admin','otomatis')),
  catatan       text,
  created_at    timestamptz not null default now(),
  constraint harga_unik unique (komoditas, wilayah, periode_mulai, sumber)
);
create index if not exists harga_cari on public.harga (komoditas, wilayah, periode_mulai desc);
alter table public.harga enable row level security;

drop policy if exists "harga dibaca publik"  on public.harga;
drop policy if exists "harga ditulis admin"  on public.harga;
drop policy if exists "harga diubah admin"   on public.harga;
drop policy if exists "harga dihapus admin"  on public.harga;
create policy "harga dibaca publik" on public.harga for select using (true);
create policy "harga ditulis admin" on public.harga for insert with check (public.is_admin());
create policy "harga diubah admin"  on public.harga for update using (public.is_admin()) with check (public.is_admin());
create policy "harga dihapus admin" on public.harga for delete using (public.is_admin());

-- Harga terbaru per komoditas + wilayah, beserta harga periode sebelumnya
create or replace view public.harga_terbaru with (security_invoker = true) as
select * from (
  select h.*,
         lag(h.harga) over (partition by h.komoditas, h.wilayah
                            order by h.periode_mulai, h.id) as harga_sebelumnya,
         row_number() over (partition by h.komoditas, h.wilayah
                            order by h.periode_mulai desc, h.id desc) as urutan
  from public.harga h
) t
where urutan = 1;

-- ---------------------------------------------------------------------
-- 3. TERRA MARKET — iklan jual/beli
-- ---------------------------------------------------------------------
create table if not exists public.iklan (
  id         bigint generated always as identity primary key,
  jenis      text not null check (jenis in ('Jual','Beli')),
  barang     text not null check (char_length(barang) between 2 and 80),
  jumlah     text not null check (char_length(jumlah) between 1 and 40),
  harga      text not null check (char_length(harga) between 1 and 20),
  lokasi     text not null check (char_length(lokasi) between 2 and 60),
  nama       text not null check (char_length(nama) between 2 and 40),
  whatsapp   text not null check (whatsapp ~ '^[0-9+ -]{8,20}$'),
  status     text not null default 'tayang' check (status in ('tayang','disembunyikan')),
  created_at timestamptz not null default now()
);
alter table public.iklan enable row level security;

drop policy if exists "iklan dibaca publik"   on public.iklan;
drop policy if exists "iklan dipasang publik" on public.iklan;
drop policy if exists "iklan dimoderasi admin" on public.iklan;
drop policy if exists "iklan dihapus admin"   on public.iklan;
create policy "iklan dibaca publik"    on public.iklan for select using (status = 'tayang' or public.is_admin());
create policy "iklan dipasang publik"  on public.iklan for insert with check (status = 'tayang');
create policy "iklan dimoderasi admin" on public.iklan for update using (public.is_admin()) with check (public.is_admin());
create policy "iklan dihapus admin"    on public.iklan for delete using (public.is_admin());

-- ---------------------------------------------------------------------
-- 4. EXPERT CONNECT — pertanyaan dan jawaban
-- ---------------------------------------------------------------------
create table if not exists public.pertanyaan (
  id         bigint generated always as identity primary key,
  nama       text not null check (char_length(nama) between 2 and 40),
  komoditas  text not null check (char_length(komoditas) between 2 and 40),
  judul      text not null check (char_length(judul) between 5 and 120),
  isi        text not null check (char_length(isi) between 5 and 1000),
  status     text not null default 'tayang' check (status in ('tayang','disembunyikan')),
  created_at timestamptz not null default now()
);
alter table public.pertanyaan enable row level security;

drop policy if exists "pertanyaan dibaca publik"    on public.pertanyaan;
drop policy if exists "pertanyaan dikirim publik"   on public.pertanyaan;
drop policy if exists "pertanyaan dimoderasi admin" on public.pertanyaan;
drop policy if exists "pertanyaan dihapus admin"    on public.pertanyaan;
create policy "pertanyaan dibaca publik"    on public.pertanyaan for select using (status = 'tayang' or public.is_admin());
create policy "pertanyaan dikirim publik"   on public.pertanyaan for insert with check (status = 'tayang');
create policy "pertanyaan dimoderasi admin" on public.pertanyaan for update using (public.is_admin()) with check (public.is_admin());
create policy "pertanyaan dihapus admin"    on public.pertanyaan for delete using (public.is_admin());

create table if not exists public.jawaban (
  id            bigint generated always as identity primary key,
  pertanyaan_id bigint not null references public.pertanyaan(id) on delete cascade,
  nama          text not null check (char_length(nama) between 2 and 40),
  isi           text not null check (char_length(isi) between 2 and 1000),
  is_pakar      boolean not null default false,
  status        text not null default 'tayang' check (status in ('tayang','disembunyikan')),
  created_at    timestamptz not null default now()
);
create index if not exists jawaban_per_pertanyaan on public.jawaban (pertanyaan_id);
alter table public.jawaban enable row level security;

drop policy if exists "jawaban dibaca publik"    on public.jawaban;
drop policy if exists "jawaban dikirim publik"   on public.jawaban;
drop policy if exists "jawaban dimoderasi admin" on public.jawaban;
drop policy if exists "jawaban dihapus admin"    on public.jawaban;
create policy "jawaban dibaca publik"    on public.jawaban for select using (status = 'tayang' or public.is_admin());
-- Warga biasa boleh menjawab, tapi lencana "Pakar" hanya bisa diberikan admin
create policy "jawaban dikirim publik"   on public.jawaban for insert
  with check (status = 'tayang' and (is_pakar = false or public.is_admin()));
create policy "jawaban dimoderasi admin" on public.jawaban for update using (public.is_admin()) with check (public.is_admin());
create policy "jawaban dihapus admin"    on public.jawaban for delete using (public.is_admin());

-- ---------------------------------------------------------------------
-- 5. HAK AKSES TABEL
-- ---------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant select on public.harga, public.harga_terbaru to anon, authenticated;
grant insert, update, delete on public.harga to authenticated;
grant select, insert on public.iklan, public.pertanyaan, public.jawaban to anon, authenticated;
grant update, delete on public.iklan, public.pertanyaan, public.jawaban to authenticated;
grant select on public.admin to authenticated;
grant execute on function public.is_admin() to anon, authenticated;

-- ---------------------------------------------------------------------
-- 6. REALTIME — perubahan langsung terkirim ke semua pengunjung
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['harga','iklan','pertanyaan','jawaban'] loop
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 7. DATA AWAL — harga TBS Sumut (umur 10–20 tahun) hasil penetapan
--    Disbun Sumut, sesuai pemberitaan. Silakan lanjutkan tiap minggu
--    lewat halaman Admin di website.
-- ---------------------------------------------------------------------
insert into public.harga
  (komoditas, kategori, wilayah, satuan, harga, periode_mulai, periode_akhir, tingkat, sumber, sumber_url, metode, catatan)
values
  ('TBS kelapa sawit (umur 10–20 th)','Perkebunan','Sumatera Utara','kg',3632.42,'2026-10-07','2026-10-13','produsen',
   'Penetapan Disbun Sumut (via InfoSAWIT)',
   'https://www.infosawit.com/2026/10/12/harga-tbs-sawit-sumut-periode-7-13-oktober-2026-umur-10-20-tahun-rp3-63242-per-kg/','admin',null),
  ('TBS kelapa sawit (umur 10–20 th)','Perkebunan','Sumatera Utara','kg',3740.41,'2026-10-21','2026-10-27','produsen',
   'Penetapan Disbun Sumut (via InfoSAWIT)',
   'https://www.infosawit.com/2026/10/23/harga-tbs-sawit-sumut-periode-21-27-oktober-2026-naik-rp7023-per-kg-umur-10-20-tahun-rp3-74041/','admin',null),
  ('TBS kelapa sawit (umur 10–20 th)','Perkebunan','Sumatera Utara','kg',3477,'2026-10-28','2026-11-03','produsen',
   'Penetapan Disbun Sumut (via Bisnis.com)',
   'https://sumatra.bisnis.com/read/20261030/533/2017008/harga-tbs-sawit-sumut-28-oktober-3-november-turun-jadi-rp3477-per-kg','admin',
   'Angka dibulatkan sesuai judul berita; cocokkan dengan pengumuman resmi Disbun.')
on conflict on constraint harga_unik do nothing;

-- ---------------------------------------------------------------------
-- 8. DAFTARKAN AKUN ADMIN (jalankan terpisah setelah membuat akun)
--    Ganti email di bawah dengan email akun admin, hapus tanda --, Run.
-- ---------------------------------------------------------------------
-- insert into public.admin (user_id, nama)
-- select id, 'Admin Nadi Terra' from auth.users where email = 'email-admin@contoh.com'
-- on conflict do nothing;
