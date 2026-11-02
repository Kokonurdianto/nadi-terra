// =====================================================================
//  KONFIGURASI NADI TERRA
//  Isi dua nilai di bawah dari Supabase: Project Settings > API
//  - Project URL          -> supabaseUrl
//  - anon / public key    -> supabaseAnonKey
//  Kunci "anon" memang aman dipasang di website (data dilindungi aturan
//  keamanan di database). JANGAN pernah menaruh kunci "service_role" di sini.
//  Selama dua nilai ini kosong, website berjalan dalam Mode Demo.
// =====================================================================
window.NT_CONFIG = {
  supabaseUrl: "https://slkwsakfdjzromivbspc.supabase.co",
  supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNsa3dzYWtmZGp6cm9taXZic3BjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM2MzM3NDUsImV4cCI6MjEwOTIwOTc0NX0.6Bv29dmwenDDkvTEG5jPZXDYk9AW3dFVpnwawsaz_8Y"
};
