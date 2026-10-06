-- =====================================================================
-- 02_procedures.sql : stored procedure & function (seluruh CRUD + pencarian)
-- Semua objek SECURITY DEFINER: berjalan dengan hak pemilik, sehingga user
-- aplikasi cukup diberi GRANT EXECUTE (tanpa akses langsung ke tabel).
-- =====================================================================

-- ---------- PELANGGAN ----------
CREATE OR REPLACE PROCEDURE sp_tambah_pelanggan(p_nama TEXT, p_alamat TEXT, p_telepon TEXT, p_email TEXT,
                                                INOUT p_id INTEGER DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    INSERT INTO pelanggan(nama, alamat, telepon, email)
    VALUES (p_nama, p_alamat, p_telepon, NULLIF(p_email,''))
    RETURNING id_pelanggan INTO p_id;
END $$;

CREATE OR REPLACE FUNCTION fn_tampil_pelanggan()
RETURNS TABLE(id_pelanggan INT, nama VARCHAR, alamat TEXT, telepon VARCHAR, email VARCHAR)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT c.id_pelanggan, c.nama, c.alamat, c.telepon, c.email FROM pelanggan c ORDER BY c.id_pelanggan
$$;

CREATE OR REPLACE FUNCTION fn_cari_pelanggan(p_kata TEXT)
RETURNS TABLE(id_pelanggan INT, nama VARCHAR, alamat TEXT, telepon VARCHAR, email VARCHAR)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT c.id_pelanggan, c.nama, c.alamat, c.telepon, c.email
    FROM pelanggan c
    WHERE c.nama ILIKE '%' || p_kata || '%' OR c.email ILIKE '%' || p_kata || '%'
    ORDER BY c.id_pelanggan
$$;

CREATE OR REPLACE PROCEDURE sp_ubah_pelanggan(p_id INT, p_nama TEXT, p_alamat TEXT, p_telepon TEXT, p_email TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    UPDATE pelanggan SET nama = p_nama, alamat = p_alamat, telepon = p_telepon, email = NULLIF(p_email,'')
    WHERE id_pelanggan = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Pelanggan dengan id % tidak ditemukan', p_id; END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_hapus_pelanggan(p_id INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    DELETE FROM pelanggan WHERE id_pelanggan = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Pelanggan dengan id % tidak ditemukan', p_id; END IF;
EXCEPTION WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'Pelanggan % tidak dapat dihapus karena sudah memiliki transaksi', p_id;
END $$;

-- ---------- PRODUK ----------
CREATE OR REPLACE PROCEDURE sp_tambah_produk(p_nama TEXT, p_harga NUMERIC, p_stok INT, INOUT p_id INTEGER DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    INSERT INTO produk(nama_produk, harga, stok) VALUES (p_nama, p_harga, p_stok)
    RETURNING id_produk INTO p_id;
END $$;

CREATE OR REPLACE FUNCTION fn_tampil_produk()
RETURNS TABLE(id_produk INT, nama_produk VARCHAR, harga NUMERIC, stok INT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT p.id_produk, p.nama_produk, p.harga, p.stok FROM produk p ORDER BY p.id_produk
$$;

CREATE OR REPLACE FUNCTION fn_cari_produk(p_kata TEXT)
RETURNS TABLE(id_produk INT, nama_produk VARCHAR, harga NUMERIC, stok INT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT p.id_produk, p.nama_produk, p.harga, p.stok FROM produk p
    WHERE p.nama_produk ILIKE '%' || p_kata || '%' ORDER BY p.id_produk
$$;

CREATE OR REPLACE PROCEDURE sp_ubah_produk(p_id INT, p_nama TEXT, p_harga NUMERIC, p_stok INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    UPDATE produk SET nama_produk = p_nama, harga = p_harga, stok = p_stok WHERE id_produk = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Produk dengan id % tidak ditemukan', p_id; END IF;
END $$;

CREATE OR REPLACE PROCEDURE sp_hapus_produk(p_id INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    DELETE FROM produk WHERE id_produk = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Produk dengan id % tidak ditemukan', p_id; END IF;
EXCEPTION WHEN foreign_key_violation THEN
    RAISE EXCEPTION 'Produk % tidak dapat dihapus karena sudah dipakai di transaksi', p_id;
END $$;

-- ---------- FUNCTION BANTU ----------
-- Cek ketersediaan stok
CREATE OR REPLACE FUNCTION fn_cek_stok(p_id_produk INT, p_jumlah INT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT COALESCE((SELECT stok >= p_jumlah FROM produk WHERE id_produk = p_id_produk), FALSE)
$$;

-- Hitung total transaksi dari detailnya
CREATE OR REPLACE FUNCTION fn_hitung_total(p_id_penjualan INT)
RETURNS NUMERIC LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT COALESCE(SUM(subtotal), 0) FROM detail_penjualan WHERE id_penjualan = p_id_penjualan
$$;
-- p_items : JSON array, contoh [{"id_produk":1,"jumlah":2},{"id_produk":3,"jumlah":1}]
-- Blok EXCEPTION pada PL/pgSQL membuat subtransaksi (SAVEPOINT) yang otomatis
-- di-ROLLBACK bila terjadi error, sehingga transaksi penjualan bersifat atomik
-- (header + detail + pengurangan stok semuanya berhasil atau semuanya batal).
-- COMMIT/ROLLBACK eksplisit tidak diizinkan PostgreSQL di dalam prosedur
-- SECURITY DEFINER, sehingga batas transaksi (COMMIT/ROLLBACK) dikelola
-- oleh pemanggil (lihat 05_uji.sql dan app/db.py).

-- ---------- PENJUALAN ----------
CREATE OR REPLACE PROCEDURE sp_buat_penjualan(p_id_pelanggan INT, p_items JSONB,
                                              INOUT p_id_penjualan INT DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_item JSONB;
BEGIN
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Daftar item penjualan tidak boleh kosong';
    END IF;

    BEGIN
        INSERT INTO penjualan(id_pelanggan) VALUES (p_id_pelanggan)
        RETURNING id_penjualan INTO p_id_penjualan;

        FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
            INSERT INTO detail_penjualan(id_penjualan, id_produk, jumlah)
            VALUES (p_id_penjualan, (v_item->>'id_produk')::INT, (v_item->>'jumlah')::INT);
        END LOOP;
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE EXCEPTION 'Pelanggan atau produk tidak ditemukan (transaksi dibatalkan)';
        WHEN check_violation THEN
            RAISE EXCEPTION 'Data tidak valid: %. Transaksi dibatalkan', SQLERRM;
        WHEN OTHERS THEN
            RAISE EXCEPTION '%  (transaksi dibatalkan)', SQLERRM;
    END;
END $$;

CREATE OR REPLACE FUNCTION fn_tampil_penjualan()
RETURNS TABLE(id_penjualan INT, tanggal TIMESTAMP, id_pelanggan INT, nama_pelanggan VARCHAR, total NUMERIC)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT p.id_penjualan, p.tanggal, c.id_pelanggan, c.nama, p.total
    FROM penjualan p JOIN pelanggan c ON c.id_pelanggan = p.id_pelanggan
    ORDER BY p.id_penjualan DESC
$$;

CREATE OR REPLACE FUNCTION fn_detail_penjualan(p_id_penjualan INT)
RETURNS TABLE(id_detail INT, id_produk INT, nama_produk VARCHAR, jumlah INT, harga_satuan NUMERIC, subtotal NUMERIC)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT d.id_detail, d.id_produk, pr.nama_produk, d.jumlah, d.harga_satuan, d.subtotal
    FROM detail_penjualan d JOIN produk pr ON pr.id_produk = d.id_produk
    WHERE d.id_penjualan = p_id_penjualan ORDER BY d.id_detail
$$;

-- Pencarian transaksi berdasarkan rentang tanggal dan/atau nama pelanggan (parameter boleh NULL)
CREATE OR REPLACE FUNCTION fn_cari_penjualan(p_dari DATE, p_sampai DATE, p_nama TEXT)
RETURNS TABLE(id_penjualan INT, tanggal TIMESTAMP, id_pelanggan INT, nama_pelanggan VARCHAR, total NUMERIC)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT p.id_penjualan, p.tanggal, c.id_pelanggan, c.nama, p.total
    FROM penjualan p JOIN pelanggan c ON c.id_pelanggan = p.id_pelanggan
    WHERE (p_dari   IS NULL OR p.tanggal::date >= p_dari)
      AND (p_sampai IS NULL OR p.tanggal::date <= p_sampai)
      AND (p_nama   IS NULL OR c.nama ILIKE '%' || p_nama || '%')
    ORDER BY p.id_penjualan DESC
$$;

-- Batalkan transaksi: stok dikembalikan oleh trigger saat detail terhapus (cascade)
CREATE OR REPLACE PROCEDURE sp_batal_penjualan(p_id_penjualan INT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    DELETE FROM penjualan WHERE id_penjualan = p_id_penjualan;
    IF NOT FOUND THEN RAISE EXCEPTION 'Penjualan % tidak ditemukan', p_id_penjualan; END IF;
END $$;

-- ---------- LOGIN ----------
CREATE OR REPLACE PROCEDURE sp_daftar_pengguna(p_username TEXT, p_password TEXT)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    INSERT INTO pengguna_app(username, password_hash) VALUES (p_username, crypt(p_password, gen_salt('bf')));
END $$;

CREATE OR REPLACE FUNCTION fn_login(p_username TEXT, p_password TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT EXISTS (SELECT 1 FROM pengguna_app
                   WHERE username = p_username AND password_hash = crypt(p_password, password_hash))
$$;

CREATE OR REPLACE FUNCTION fn_laporan_pelanggan()
RETURNS TABLE(id_pelanggan INT, nama VARCHAR, jumlah_transaksi BIGINT, total_belanja NUMERIC)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT v.id_pelanggan, v.nama, v.jumlah_transaksi, v.total_belanja FROM vw_ringkasan_pelanggan v ORDER BY v.total_belanja DESC
$$;

CREATE OR REPLACE FUNCTION fn_laporan_produk()
RETURNS TABLE(id_produk INT, nama_produk VARCHAR, stok INT, total_terjual BIGINT, total_pendapatan NUMERIC)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT v.id_produk, v.nama_produk, v.stok, v.total_terjual, v.total_pendapatan FROM vw_ringkasan_produk v ORDER BY v.total_pendapatan DESC
$$;
