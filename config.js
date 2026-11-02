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
  supabaseUrl: "",
  supabaseAnonKey: ""
};
