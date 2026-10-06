-- =====================================================================
-- 01_ddl.sql : DDL database penjualan (PostgreSQL)
-- Jalankan di DBeaver sebagai user postgres (superuser).
-- Langkah 1 : buat database (jalankan di koneksi database "postgres"):
--     CREATE DATABASE db_penjualan;
-- Langkah 2 : buat koneksi baru ke db_penjualan, lalu jalankan script ini.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- untuk hash password

DROP TABLE IF EXISTS audit_log, detail_penjualan, penjualan, produk, pelanggan, pengguna_app CASCADE;

CREATE TABLE pelanggan (
    id_pelanggan  SERIAL PRIMARY KEY,
    nama          VARCHAR(100) NOT NULL,
    alamat        TEXT,
    telepon       VARCHAR(20),
    email         VARCHAR(100) UNIQUE,
    CONSTRAINT ck_pelanggan_nama CHECK (length(trim(nama)) > 0)
);

CREATE TABLE produk (
    id_produk     SERIAL PRIMARY KEY,
    nama_produk   VARCHAR(100) NOT NULL,
    harga         NUMERIC(12,2) NOT NULL CHECK (harga >= 0),
    stok          INTEGER NOT NULL DEFAULT 0 CHECK (stok >= 0),
    CONSTRAINT ck_produk_nama CHECK (length(trim(nama_produk)) > 0)
);

CREATE TABLE penjualan (
    id_penjualan  SERIAL PRIMARY KEY,
    id_pelanggan  INTEGER NOT NULL REFERENCES pelanggan(id_pelanggan),
    tanggal       TIMESTAMP NOT NULL DEFAULT now(),
    total         NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total >= 0)
);

CREATE TABLE detail_penjualan (
    id_detail     SERIAL PRIMARY KEY,
    id_penjualan  INTEGER NOT NULL REFERENCES penjualan(id_penjualan) ON DELETE CASCADE,
    id_produk     INTEGER NOT NULL REFERENCES produk(id_produk),
    jumlah        INTEGER NOT NULL CHECK (jumlah > 0),
    harga_satuan  NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (harga_satuan >= 0),
    subtotal      NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0)
);

CREATE TABLE audit_log (
    id_log      BIGSERIAL PRIMARY KEY,
    nama_tabel  VARCHAR(50) NOT NULL,
    aksi        VARCHAR(10) NOT NULL,
    id_record   TEXT,
    data_lama   JSONB,
    data_baru   JSONB,
    db_user     TEXT NOT NULL DEFAULT current_user,
    waktu       TIMESTAMP NOT NULL DEFAULT now()
);

-- Tabel login aplikasi: password disimpan sebagai hash bcrypt (pgcrypto)
CREATE TABLE pengguna_app (
    id_pengguna    SERIAL PRIMARY KEY,
    username       VARCHAR(50) NOT NULL UNIQUE,
    password_hash  TEXT NOT NULL
);

-- Index
CREATE INDEX idx_produk_nama        ON produk (nama_produk);
CREATE INDEX idx_pelanggan_nama     ON pelanggan (nama);
CREATE INDEX idx_penjualan_tanggal  ON penjualan (tanggal);
CREATE INDEX idx_penjualan_pelanggan ON penjualan (id_pelanggan);
CREATE INDEX idx_detail_penjualan   ON detail_penjualan (id_penjualan);
CREATE INDEX idx_detail_produk      ON detail_penjualan (id_produk);

-- View
CREATE OR REPLACE VIEW vw_detail_penjualan AS
SELECT p.id_penjualan, p.tanggal, c.id_pelanggan, c.nama AS nama_pelanggan,
       d.id_detail, pr.id_produk, pr.nama_produk, d.jumlah, d.harga_satuan, d.subtotal, p.total
FROM penjualan p
JOIN pelanggan c         ON c.id_pelanggan = p.id_pelanggan
JOIN detail_penjualan d  ON d.id_penjualan = p.id_penjualan
JOIN produk pr           ON pr.id_produk   = d.id_produk;

CREATE OR REPLACE VIEW vw_ringkasan_pelanggan AS
SELECT c.id_pelanggan, c.nama, COUNT(p.id_penjualan) AS jumlah_transaksi,
       COALESCE(SUM(p.total),0) AS total_belanja
FROM pelanggan c LEFT JOIN penjualan p ON p.id_pelanggan = c.id_pelanggan
GROUP BY c.id_pelanggan, c.nama;

CREATE OR REPLACE VIEW vw_ringkasan_produk AS
SELECT pr.id_produk, pr.nama_produk, pr.stok,
       COALESCE(SUM(d.jumlah),0) AS total_terjual,
       COALESCE(SUM(d.subtotal),0) AS total_pendapatan
FROM produk pr LEFT JOIN detail_penjualan d ON d.id_produk = pr.id_produk
GROUP BY pr.id_produk, pr.nama_produk, pr.stok;
