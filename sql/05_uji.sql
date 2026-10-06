-- =====================================================================
-- 05_uji.sql : data awal + skenario pengujian
-- Jalankan per blok (Alt+X untuk seluruh script di DBeaver; atau blok demi blok).
-- =====================================================================

-- ---- A. Data awal (lewat stored procedure) ----
CALL sp_tambah_pelanggan('Budi Santoso', 'Depok', '08123456789', 'budi@mail.com', NULL);
CALL sp_tambah_pelanggan('Siti Aminah',  'Bogor', '08129876543', 'siti@mail.com', NULL);
CALL sp_tambah_produk('Laptop',  8500000, 10, NULL);
CALL sp_tambah_produk('Mouse',    150000, 50, NULL);
CALL sp_tambah_produk('Keyboard', 350000, 3,  NULL);
CALL sp_daftar_pengguna('admin', 'admin123');

SELECT * FROM fn_tampil_pelanggan();
SELECT * FROM fn_tampil_produk();

-- ---- B. Transaksi penjualan BERHASIL (START TRANSACTION + COMMIT) ----
START TRANSACTION;
CALL sp_buat_penjualan(1, '[{"id_produk":1,"jumlah":2},{"id_produk":2,"jumlah":3}]'::jsonb, NULL);
COMMIT;

SELECT * FROM fn_tampil_penjualan();        -- total = 2*8.500.000 + 3*150.000 = 17.450.000
SELECT * FROM fn_detail_penjualan(1);
SELECT * FROM fn_tampil_produk();           -- stok Laptop 8, Mouse 47

-- ---- C. Transaksi GAGAL (stok Keyboard hanya 3, diminta 5) -> ROLLBACK ----
START TRANSACTION;
CALL sp_buat_penjualan(2, '[{"id_produk":2,"jumlah":1},{"id_produk":3,"jumlah":5}]'::jsonb, NULL);
-- error: Stok Keyboard tidak cukup ... -> jalankan ROLLBACK
ROLLBACK;

SELECT * FROM fn_tampil_penjualan();        -- tetap 1 transaksi
SELECT * FROM fn_tampil_produk();           -- stok Mouse tetap 47 (tidak ikut berkurang)

-- ---- D. Pembatalan transaksi: stok dikembalikan oleh trigger ----
START TRANSACTION;
CALL sp_batal_penjualan(1);
COMMIT;
SELECT * FROM fn_tampil_produk();           -- stok kembali: Laptop 10, Mouse 50

-- ---- E. Ubah, cari, hapus ----
CALL sp_ubah_produk(2, 'Mouse Wireless', 175000, 50);
SELECT * FROM fn_cari_produk('mouse');
SELECT * FROM fn_cari_pelanggan('budi');
CALL sp_hapus_produk(3);

-- Satu transaksi lagi agar laporan terisi
START TRANSACTION;
CALL sp_buat_penjualan(2, '[{"id_produk":2,"jumlah":4},{"id_produk":1,"jumlah":1}]'::jsonb, NULL);
COMMIT;

-- ---- F. Cek audit trail ----
SELECT id_log, nama_tabel, aksi, id_record, db_user, waktu FROM audit_log ORDER BY id_log;

-- ---- G. Laporan (view) ----
SELECT * FROM vw_ringkasan_pelanggan;
SELECT * FROM vw_ringkasan_produk;

-- ---- H. Uji hak akses (jalankan dengan koneksi user app_penjualan) ----
-- SELECT * FROM produk;                 -- HARUS GAGAL: permission denied for table produk
-- INSERT INTO produk(nama_produk,harga,stok) VALUES ('X',1,1);   -- HARUS GAGAL
-- SELECT * FROM fn_tampil_produk();     -- BERHASIL (hanya lewat function)

-- ---- I. Analisis performa (index & query plan) ----
EXPLAIN ANALYZE SELECT * FROM fn_cari_penjualan(CURRENT_DATE - 30, CURRENT_DATE, NULL);
EXPLAIN ANALYZE SELECT * FROM produk WHERE nama_produk = 'Mouse Wireless';
-- Konfigurasi pemantauan query lambat (butuh superuser):
-- ALTER SYSTEM SET log_min_duration_statement = '200ms'; SELECT pg_reload_conf();
-- Jumlah koneksi aktif:
SELECT datname, count(*) AS koneksi FROM pg_stat_activity GROUP BY datname;
