// =====================================================================
//  ROBOT PENARIK HARGA PANGAN — PIHPS Bank Indonesia
//  Mengambil harga pangan harian Sumatera Utara (pasar tradisional)
//  dari https://www.bi.go.id/hargapangan lalu menyimpannya ke tabel
//  "harga" di Supabase. Dijalankan otomatis oleh GitHub Actions.
//
//  Variabel lingkungan:
//    SUPABASE_URL               Project URL Supabase
//    SUPABASE_SERVICE_ROLE_KEY  kunci service_role (RAHASIA, hanya di GitHub Secrets)
//    DRY_RUN=1                  hanya menampilkan hasil, tidak menyimpan
//    HARI=14                    berapa hari ke belakang yang diambil (bawaan 14)
//
//  Catatan: PIHPS tidak menyediakan API resmi yang terdokumentasi. Robot
//  ini memakai alamat data yang dipakai halaman tabel PIHPS sendiri, jadi
//  bisa berubah sewaktu-waktu. Bila gagal, harga tetap bisa diinput admin.
// =====================================================================

const BASE = "https://www.bi.go.id/hargapangan";
const PROVINSI = { id: 2, nama: "Sumatera Utara" };
const KOMODITAS = [
  { id: "com_1",  nama: "Beras kualitas bawah I",  satuan: "kg" },
  { id: "com_3",  nama: "Beras kualitas medium I", satuan: "kg" },
  { id: "com_5",  nama: "Beras kualitas super I",  satuan: "kg" },
  { id: "com_8",  nama: "Daging sapi kualitas 1",  satuan: "kg" },
  { id: "com_21", nama: "Gula pasir lokal",        satuan: "kg" },
];
const SUMBER = "PIHPS Bank Indonesia";
const HARI = Number(process.env.HARI || 14);
const DRY = process.env.DRY_RUN === "1";
const HDRS = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
  "Accept": "application/json, text/javascript, */*; q=0.01",
  "Accept-Language": "id-ID,id;q=0.9,en;q=0.8",
  "X-Requested-With": "XMLHttpRequest",
  "Referer": `${BASE}/TabelHarga/PasarTradisionalKomoditas`,
};

const tunggu = (ms) => new Promise((r) => setTimeout(r, ms));
const ymd = (d) => d.toISOString().slice(0, 10);

// Tanggal hari ini menurut WIB
function hariIniWIB() {
  const d = new Date(Date.now() + 7 * 3600 * 1000);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

// "14,250" / "14.250" -> 14250 ; "-" / "" / "0" -> null
export function angka(v) {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  if (s === "" || s === "-" || s === "0") return null;
  const n = Number(s.replace(/[.,\s]/g, ""));
  return Number.isFinite(n) && n > 0 ? n : null;
}

// Ubah respons PIHPS menjadi baris tabel "harga"
export function olah(json, kom, wilayah = PROVINSI.nama) {
  const data = Array.isArray(json?.data) ? json.data : [];
  const baris = data.find((r) => r.level === 1) || null; // level 1 = provinsi
  if (!baris) return [];
  const out = [];
  for (const [k, v] of Object.entries(baris)) {
    const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(k);
    if (!m) continue;
    const h = angka(v);
    if (h === null) continue;
    out.push({
      komoditas: kom.nama,
      kategori: "Pangan",
      wilayah,
      satuan: kom.satuan,
      harga: h,
      periode_mulai: `${m[3]}-${m[2]}-${m[1]}`,
      periode_akhir: null,
      tingkat: "konsumen",
      sumber: SUMBER,
      sumber_url: `${BASE}/TabelHarga/PasarTradisionalKomoditas`,
      metode: "otomatis",
      catatan: "Rata-rata harga pasar tradisional tingkat provinsi.",
    });
  }
  return out.sort((a, b) => (a.periode_mulai < b.periode_mulai ? -1 : 1));
}

async function ambilCookie() {
  const res = await fetch(`${BASE}/TabelHarga/PasarTradisionalKomoditas`, { headers: HDRS });
  await res.text();
  const set = typeof res.headers.getSetCookie === "function" ? res.headers.getSetCookie() : [];
  return set.map((c) => c.split(";")[0]).join("; ");
}

async function ambilKomoditas(kom, cookie, mulai, akhir) {
  const p = new URLSearchParams({
    price_type_id: "1", comcat_id: kom.id, province_id: String(PROVINSI.id), regency_id: "",
    showKota: "false", showPasar: "false", tipe_laporan: "1",
    start_date: mulai, end_date: akhir, _: String(Date.now()),
  });
  const url = `${BASE}/WebSite/TabelHarga/GetGridDataKomoditas?${p}`;
  for (let coba = 1; coba <= 3; coba++) {
    try {
      const res = await fetch(url, { headers: { ...HDRS, Cookie: cookie } });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (e) {
      if (coba === 3) throw e;
      await tunggu(2000 * coba);
    }
  }
}

async function simpan(rows) {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY belum diisi di GitHub Secrets.");
  const headers = {
    apikey: key,
    "Content-Type": "application/json",
    Prefer: "resolution=merge-duplicates,return=minimal",
  };
  // Kunci lama (JWT) juga dikirim lewat Authorization; kunci baru sb_secret_ cukup lewat apikey
  if (!key.startsWith("sb_")) headers.Authorization = `Bearer ${key}`;
  const res = await fetch(
    `${url.replace(/\/$/, "")}/rest/v1/harga?on_conflict=komoditas,wilayah,periode_mulai,sumber`,
    { method: "POST", headers, body: JSON.stringify(rows) }
  );
  if (!res.ok) throw new Error(`Gagal menyimpan ke Supabase: HTTP ${res.status} ${await res.text()}`);
}

async function main() {
  const akhir = hariIniWIB();
  const mulai = new Date(akhir.getTime() - HARI * 86400000);
  console.log(`Menarik PIHPS ${PROVINSI.nama}, ${ymd(mulai)} s.d. ${ymd(akhir)}${DRY ? " (uji coba, tidak menyimpan)" : ""}`);

  let cookie = "";
  try { cookie = await ambilCookie(); } catch (e) { console.warn("Peringatan: gagal mengambil cookie awal:", e.message); }

  const semua = [];
  let gagal = 0;
  for (const kom of KOMODITAS) {
    try {
      const json = await ambilKomoditas(kom, cookie, ymd(mulai), ymd(akhir));
      const rows = olah(json, kom);
      const t = rows.at(-1);
      console.log(`  ✔ ${kom.nama}: ${rows.length} hari${t ? `, terakhir ${t.periode_mulai} Rp${t.harga.toLocaleString("id-ID")}` : ""}`);
      semua.push(...rows);
    } catch (e) {
      gagal++;
      console.error(`  ✘ ${kom.nama}: ${e.message}`);
    }
    await tunggu(1500);
  }

  if (!semua.length) {
    console.error("Tidak ada data yang berhasil diambil. Kemungkinan alamat PIHPS berubah atau sedang tidak bisa diakses.");
    process.exit(1);
  }
  if (DRY) { console.log(JSON.stringify(semua.slice(-3), null, 2)); return; }

  await simpan(semua);
  console.log(`Tersimpan ${semua.length} baris harga. Komoditas gagal: ${gagal}.`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => { console.error(e.message); process.exit(1); });
}
