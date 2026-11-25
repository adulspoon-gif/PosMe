APLIKASI KASIR iOS (IPA) - PROYEK SIAP DIBUILD
===============================================
Ini aplikasi iOS ASLI (SwiftUI) untuk server kasir Anda, tampilan navy-biru yang
sama dengan versi web. Dibanding versi layar utama (PWA), aplikasi ini lebih
"mobile" dan lebih interaktif:
  - menu bawah melayang dengan pil biru yang meluncur
  - angka dashboard menghitung naik, grafik batang bisa disentuh
  - getar (haptic) dan suara "kring" saat transaksi tersimpan
  - kunci Face ID saat aplikasi dibuka kembali
  - keranjang kasir dengan tombol pembayaran cepat (uang pas, 50 rb, 100 rb)
  - ketuk-geser: edit / hapus transaksi, buat akses login pelanggan
  - cetak nota lewat AirPrint, bagikan nota ke WhatsApp
  - ubah tanggal dan jam transaksi, import/unduh backup, laporan 7/30/90 hari
  - tarik layar untuk menyegarkan data, login tersimpan aman di Keychain
Pelanggan yang login hanya melihat "Transaksi Saya" (daftar, detail, nota).

PENTING - YANG PERLU ANDA TAHU DULU
- Saya TIDAK bisa membuild aplikasi iOS di sini (butuh macOS + Xcode). Kodenya
  sudah saya periksa sintaksnya dan dicocokkan dengan data asli server, tetapi
  BELUM pernah dikompilasi. Pada build pertama bisa muncul pesan error kecil.
  Jika gagal, kirim isi log (lihat langkah 6) ke saya; saya perbaiki.
- Server harus sudah memakai update terbaru (KASIR-HARDWARESTORE-UPDATE-IPHONE).
  Aplikasi menolak server versi lama dan memberi pesan yang jelas.
- Minimal iOS 16 (iPhone 8 ke atas).

CARA 1 - TANPA MAC: BUILD DI GITHUB (GRATIS)
1. Punya akun GitHub (github.com, gratis). Buat repositori baru, misalnya
   "kasir-ios" (Private atau Public).
2. Ekstrak ZIP ini. Unggah ISI folder KasirIOS ke repositori: folder Kasir,
   folder .github, file project.yml dan .gitignore.
   - Mudah: pakai GitHub Desktop (Add local repository > Publish repository).
   - Lewat web: "uploading an existing file", seret semua isinya. Jika folder
     .github tidak ikut terunggah: Add file > Create new file, ketik nama
     .github/workflows/build-ipa.yml lalu tempel isi file itu.
3. Buka tab "Actions". Jika ada tombol untuk mengaktifkan workflow, klik.
4. Pilih "Build IPA" > "Run workflow" > Run. Tunggu sekitar 10-15 menit.
5. Buka hasil run yang berwarna hijau, lihat bagian "Artifacts", unduh "Kasir-IPA".
   Ekstrak: di dalamnya ada Kasir-tanpa-tanda-tangan.ipa
6. Jika merah (gagal): buka run itu, unduh artifact "build-log" atau salin baris
   yang berisi "error:", lalu kirim ke saya.
Catatan: repositori Public gratis tanpa batas. Repositori Private memakai jatah
menit gratis GitHub (build macOS dihitung lebih mahal), cukup untuk beberapa
build per bulan.

CARA 2 - JIKA PUNYA MAC
   brew install xcodegen
   cd KasirIOS && xcodegen generate && open Kasir.xcodeproj
   Pilih Team (Apple ID) di Signing & Capabilities, sambungkan iPhone, tekan Run.

MEMASANG IPA KE IPHONE (IPA dari Cara 1 belum bertanda tangan)
Pilihan A - Sideloadly (Windows, gratis): unduh dari sideloadly.io, pasang iTunes
  dan iCloud versi dari apple.com (bukan Microsoft Store), sambungkan iPhone,
  seret file .ipa ke Sideloadly, isi Apple ID, klik Start.
Pilihan B - 3uTools: menu Aplikasi > Instal IPA (tanda tangan dengan Apple ID).
Pilihan C - AltStore, atau akun Apple Developer berbayar + TestFlight.
Setelah terpasang:
  1. iPhone: Pengaturan > Umum > VPN & Manajemen Perangkat > percayai Apple ID Anda.
  2. iOS 16 ke atas: Pengaturan > Privasi & Keamanan > Mode Pengembang > aktifkan,
     lalu restart iPhone.
  3. Dengan Apple ID gratis, aplikasi kedaluwarsa setiap 7 hari dan harus dipasang
     ulang (Sideloadly bisa menyegarkan otomatis). Akun Developer berbayar
     berlaku 1 tahun.

PEMAKAIAN PERTAMA
- Buka aplikasi, buka bagian "Alamat server", isi alamat Funnel Anda (contoh
  https://neo.tail5bf676.ts.net), lalu login seperti di web.
- Hidupkan Face ID: Lainnya > Pengaturan > Kunci dengan Face ID.
- Suara mengikuti tombol senyap iPhone; getar dan suara bisa dimatikan di Pengaturan.

UNTUK PELANGGAN
Memasang IPA lewat sideload merepotkan untuk pelanggan. Untuk mereka lebih mudah
memakai versi layar utama (Safari > Bagikan > Tambahkan ke Layar Utama) dengan akun
yang Anda buat.
