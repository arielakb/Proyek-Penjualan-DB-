-- =====================================================================
-- 04_keamanan.sql : hak akses (GRANT / REVOKE)
-- User aplikasi hanya boleh EXECUTE objek program, tanpa akses langsung ke tabel.
-- GANTI PASSWORD (v_password) di bawah sebelum dipakai.
-- =====================================================================

-- Aman dijalankan berulang: buat role bila belum ada, bila sudah ada cukup set ulang password.
-- Ganti password di BARIS INI saja (v_password).
DO $$
DECLARE
    v_password TEXT := 'root1234';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_penjualan') THEN
        EXECUTE format('CREATE ROLE app_penjualan LOGIN PASSWORD %L', v_password);
    ELSE
        EXECUTE format('ALTER ROLE app_penjualan LOGIN PASSWORD %L', v_password);
    END IF;
END $$;

-- 1. Cabut semua hak bawaan
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC, app_penjualan;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC, app_penjualan;
REVOKE EXECUTE ON ALL FUNCTIONS  IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;

-- 2. Izinkan koneksi & pemakaian schema saja
GRANT CONNECT ON DATABASE db_penjualan TO app_penjualan;
GRANT USAGE ON SCHEMA public TO app_penjualan;

-- 3. GRANT EXECUTE hanya pada objek program yang dipanggil aplikasi
GRANT EXECUTE ON PROCEDURE sp_tambah_pelanggan(TEXT,TEXT,TEXT,TEXT,INTEGER) TO app_penjualan;
GRANT EXECUTE ON PROCEDURE sp_ubah_pelanggan(INT,TEXT,TEXT,TEXT,TEXT)       TO app_penjualan;
GRANT EXECUTE ON PROCEDURE sp_hapus_pelanggan(INT)                          TO app_penjualan;
GRANT EXECUTE ON PROCEDURE sp_tambah_produk(TEXT,NUMERIC,INT,INTEGER)       TO app_penjualan;
GRANT EXECUTE ON PROCEDURE sp_ubah_produk(INT,TEXT,NUMERIC,INT)             TO app_penjualan;
GRANT EXECUTE ON PROCEDURE sp_hapus_produk(INT)                             TO app_penjualan;
GRANT EXECUTE ON PROCEDURE sp_buat_penjualan(INT,JSONB,INT)                 TO app_penjualan;
GRANT EXECUTE ON PROCEDURE sp_batal_penjualan(INT)                          TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_tampil_pelanggan()                            TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_cari_pelanggan(TEXT)                          TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_tampil_produk()                               TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_cari_produk(TEXT)                             TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_tampil_penjualan()                            TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_detail_penjualan(INT)                         TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_cari_penjualan(DATE,DATE,TEXT)                TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_laporan_pelanggan()                           TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_laporan_produk()                              TO app_penjualan;
GRANT EXECUTE ON FUNCTION  fn_login(TEXT,TEXT)                              TO app_penjualan;
-- sp_daftar_pengguna sengaja TIDAK diberikan ke aplikasi (hanya admin DB yang mendaftarkan pengguna)
-- Trigger function tidak perlu GRANT: dijalankan otomatis oleh database.
