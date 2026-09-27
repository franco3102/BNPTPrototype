// Logic validasi user (bcrypt compare) & generate JWT token.
// JWT payload menyertakan: user_id, role, dan daftar permission efektif
// (hasil gabungan role_permissions + override user_permissions) supaya
// frontend & guard tidak perlu query ulang saat setiap request.
// TODO: implement
