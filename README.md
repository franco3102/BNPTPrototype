# BNPT IPDR Vector Filtering Engine

Project gabungan frontend (AdminLTE static portal) + backend (NestJS API skeleton).

## Struktur

```
BNPTipdr/
├── index.html, css/, js/, pages/, partials/   <- FRONTEND (static, buka langsung di browser)
└── src/, package.json, nest-cli.json, ...     <- BACKEND (NestJS, belum ada logic, baru skeleton)
```

### Frontend
- `partials/header.html`, `partials/sidebar.html` - satu sumber untuk navbar & sidebar,
  di-include ke semua halaman lewat `js/layout.js` (tidak digandakan manual lagi).
- `pages/login/index.html` - halaman login standalone.
- `pages/users.html` - User Management + matriks permission per-halaman/per-aksi.
- `js/permissions.js` - demo sembunyikan tombol berdasarkan `data-permission="..."`.

Jalankan dengan static server, contoh: `python -m http.server 8000` dari folder ini.

### Backend
Lihat `README` bagian bawah file ini (sebelumnya di `backend/README.md`) untuk daftar
modul dan cara setup NestJS + MySQL.

## Database

Skema lengkap (MySQL, 10 tabel + seed data role/permission) ada di:
`src/database/schema.sql`

---

# BNPT IPDR API (Backend)

Struktur folder backend NestJS untuk sistem BNPT IPDR Vector Filtering Engine.
Belum ada implementasi kode - baru kerangka file/folder sesuai arsitektur modul.
Database: **MySQL 8** (lihat `src/database/schema.sql` untuk DDL lengkap + seed data).

## Modul

- `auth` - login & JWT (payload menyertakan role + permission efektif)
- `users` - manajemen akun user (Admin bisa tambah/nonaktifkan user)
- `permissions` - resolve hak akses per halaman & per aksi (view/create/edit/delete),
  gabungan default Role + override per User
- `whitelist` - MSISDN Whitelist Management (kuota, masking, import/export)
- `change-management` - Scheduled Change Management (alur approval 7 tahap)
- `vector-filter` - sinkronisasi whitelist aktif ke Redis (O(1) lookup)
- `ingestion` - Kafka consumer untuk stream IPDR dari Telco
- `dispatch` - pengiriman batch data ke SFTP customer (terjadwal)
- `audit` - log audit trail semua aksi approval & akses

## Struktur Permission

Permission = kombinasi `page_key` + `action` (view/create/edit/delete), contoh:
`whitelist.create`, `change-mgmt.edit`, `users.delete`.

Urutan resolve hak akses efektif seorang user:
1. Ambil semua permission bawaan dari **role** user (`role_permissions`)
2. Timpa dengan override di **user_permissions** kalau ada (bisa grant tambahan
   atau revoke permission bawaan role) - inilah yang bikin "tambah user custom
   permission per halaman per tombol" jadi mungkin, bukan cuma role generik.
3. Hasil akhir dikirim ke frontend lewat JWT payload saat login, dipakai untuk
   sembunyikan tombol (`data-permission="..."` di HTML) DAN divalidasi ulang
   di setiap endpoint lewat `PermissionGuard` (jangan pernah percaya validasi
   client-side saja).

## Setup selanjutnya

```bash
npm install @nestjs/core @nestjs/common @nestjs/platform-express \
  @nestjs/typeorm typeorm mysql2 \
  @nestjs/jwt @nestjs/passport passport passport-jwt bcrypt \
  @nestjs/config class-validator class-transformer
```

Lalu jalankan `src/database/schema.sql` di MySQL untuk membuat semua tabel +
seed data role/pages/permissions, dan mulai isi tiap file `.ts` sesuai
komentar `// TODO: implement` di dalamnya.
