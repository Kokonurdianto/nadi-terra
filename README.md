# Nadi Terra Smart Farming — panduan menghidupkan website

Website ini sudah bisa langsung dibuka dalam **Mode Demo**. Ikuti langkah di bawah supaya
datanya tersimpan online, bisa dipakai bersama semua pengunjung, dan harga pangan
diperbarui otomatis setiap hari. Semua layanan yang dipakai punya paket gratis.

## Isi folder

| File | Fungsi |
|---|---|
| `index.html` | Website lengkap (beranda, harga, diagnosa, pasar, forum, admin) |
| `config.js` | Tempat mengisi alamat dan kunci publik Supabase |
| `supabase/schema.sql` | Struktur database, aturan keamanan, realtime, dan data awal harga TBS |
| `scripts/tarik-pihps.mjs` | Robot penarik harga pangan dari PIHPS Bank Indonesia |
| `.github/workflows/tarik-harga.yml` | Jadwal robot: setiap hari pukul 09.17 WIB |

## Langkah 1 — Buat database di Supabase

1. Daftar di **supabase.com**, lalu buat proyek baru. Pilih region **Singapore** supaya cepat dari Indonesia. Simpan kata sandi database.
2. Buka **SQL Editor → New query**, tempel seluruh isi `supabase/schema.sql`, tekan **Run**.
3. Buat akun admin: **Authentication → Users → Add user**. Isi email dan kata sandi, centang *Auto confirm*.
4. Kembali ke SQL Editor, jalankan perintah ini (ganti emailnya):
   ```sql
   insert into public.admin (user_id, nama)
   select id, 'Admin Nadi Terra' from auth.users where email = 'email-admin@contoh.com'
   on conflict do nothing;
   ```
5. Supaya orang lain tidak bisa mendaftar akun sendiri, matikan pendaftaran publik di pengaturan **Authentication** (opsi *Allow new users to sign up*).

## Langkah 2 — Sambungkan website

1. Buka **Project Settings → API Keys**. Salin **Project URL** dan kunci **anon / public** (ada di tab *Legacy API keys*).
2. Buka `config.js`, isi kedua nilai itu, simpan.
3. **Jangan** pernah menaruh kunci `service_role` di `config.js`. Kunci itu hanya untuk robot (Langkah 4).

## Langkah 3 — Online-kan website

Pilih salah satu:

- **Netlify (paling mudah):** buka app.netlify.com/drop, seret seluruh folder ini ke sana. Ganti nama situs di *Site settings* menjadi misalnya `naditerra.netlify.app`.
- **GitHub Pages:** unggah folder ke repositori GitHub, lalu **Settings → Pages → Deploy from a branch → main / (root)**.

Domain sendiri (misalnya `naditerra.id`) bisa disambungkan belakangan dari pengaturan domain Netlify atau GitHub Pages.

## Langkah 4 — Nyalakan robot harga otomatis (GitHub Actions)

1. Unggah seluruh folder ke repositori GitHub (bisa repositori yang sama dengan Langkah 3).
   Folder `.github` kadang tersembunyi saat diseret dari komputer. Kalau tidak ikut, buat manual lewat
   **Add file → Create new file**, beri nama `.github/workflows/tarik-harga.yml`, lalu tempel isinya.
2. Buka **Settings → Secrets and variables → Actions → New repository secret**, buat dua secret:
   - `SUPABASE_URL` = Project URL
   - `SUPABASE_SERVICE_ROLE_KEY` = kunci **service_role** (tab *Legacy API keys*)
3. Buka tab **Actions → Tarik harga pangan (PIHPS BI) → Run workflow** untuk uji pertama. Lihat lognya:
   tanda ✔ berarti harga berhasil masuk dan langsung muncul di website.

Setelah itu robot berjalan sendiri setiap hari.

## Langkah 5 — Rutinitas mingguan admin

Harga TBS, CPO, karet, kakao, dan komoditas perkebunan lain **tidak punya API publik**. Disbun Sumut
menetapkan harga TBS setiap minggu. Setiap ada penetapan baru:

1. Buka `situs-anda/#admin`, masuk dengan akun admin.
2. Tab **Input harga** → pilih komoditas, isi harga, periode, sumber, dan tautan berita/pengumuman.
3. Simpan. Harga langsung tampil di layar semua pengunjung tanpa perlu dimuat ulang.

Tab **Moderasi** dipakai untuk menyembunyikan iklan atau pertanyaan yang melanggar aturan. Untuk menjawab
sebagai pakar, buka halaman Forum Pakar saat sedang masuk sebagai admin.

## Batasan yang perlu diketahui

- **PIHPS tidak punya API resmi terdokumentasi.** Robot memakai alamat data yang dipakai halaman tabel
  PIHPS. Bila Bank Indonesia mengubah situsnya, robot bisa gagal; log GitHub Actions akan menunjukkan
  penyebabnya dan harga tetap bisa diinput lewat admin.
- Harga PIHPS adalah **harga konsumen di pasar tradisional**, bukan harga di tingkat petani.
- GitHub menghentikan jadwal otomatis bila repositori tidak ada aktivitas selama 60 hari. Cukup buka
  tab Actions dan aktifkan lagi.
- Proyek Supabase gratis bisa dijeda bila lama tidak dipakai. Robot harian membantu menjaganya tetap aktif.
- Iklan dan pertanyaan bisa dikirim siapa saja tanpa akun. Pantau tab Moderasi secara berkala.
