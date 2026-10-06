-- =====================================================================
-- 03_triggers.sql : aturan bisnis (stok, total) & jejak audit
-- =====================================================================

-- Hapus semua trigger lama (agar script aman dijalankan ulang)
DROP TRIGGER IF EXISTS trg_detail_before_insert ON detail_penjualan;
DROP TRIGGER IF EXISTS trg_detail_after_insert  ON detail_penjualan;
DROP TRIGGER IF EXISTS trg_detail_after_delete  ON detail_penjualan;
DROP TRIGGER IF EXISTS trg_detail_no_update     ON detail_penjualan;
DROP TRIGGER IF EXISTS trg_audit_pelanggan      ON pelanggan;
DROP TRIGGER IF EXISTS trg_audit_produk         ON produk;
DROP TRIGGER IF EXISTS trg_audit_penjualan      ON penjualan;
DROP TRIGGER IF EXISTS trg_audit_detail         ON detail_penjualan;

-- Sebelum insert detail: validasi stok, ambil harga dari master, hitung subtotal
CREATE OR REPLACE FUNCTION trg_fn_detail_before_insert() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_harga NUMERIC;
    v_stok  INT;
    v_nama  TEXT;
BEGIN
    SELECT harga, stok, nama_produk INTO v_harga, v_stok, v_nama
    FROM produk WHERE id_produk = NEW.id_produk FOR UPDATE;   -- kunci baris agar aman dari race condition
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Produk dengan id % tidak ditemukan', NEW.id_produk;
    END IF;
    IF v_stok < NEW.jumlah THEN
        RAISE EXCEPTION 'Stok % tidak cukup (tersedia %, diminta %)', v_nama, v_stok, NEW.jumlah;
    END IF;
    NEW.harga_satuan := v_harga;
    NEW.subtotal     := v_harga * NEW.jumlah;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_detail_before_insert
BEFORE INSERT ON detail_penjualan FOR EACH ROW EXECUTE FUNCTION trg_fn_detail_before_insert();

-- Setelah insert detail: kurangi stok dan hitung ulang total
CREATE OR REPLACE FUNCTION trg_fn_detail_after_insert() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    UPDATE produk SET stok = stok - NEW.jumlah WHERE id_produk = NEW.id_produk;
    UPDATE penjualan SET total = fn_hitung_total(NEW.id_penjualan) WHERE id_penjualan = NEW.id_penjualan;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_detail_after_insert
AFTER INSERT ON detail_penjualan FOR EACH ROW EXECUTE FUNCTION trg_fn_detail_after_insert();

-- Setelah hapus detail (termasuk cascade pembatalan): kembalikan stok dan hitung ulang total
CREATE OR REPLACE FUNCTION trg_fn_detail_after_delete() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
    UPDATE produk SET stok = stok + OLD.jumlah WHERE id_produk = OLD.id_produk;
    UPDATE penjualan SET total = fn_hitung_total(OLD.id_penjualan) WHERE id_penjualan = OLD.id_penjualan;
    RETURN OLD;
END $$;

CREATE TRIGGER trg_detail_after_delete
AFTER DELETE ON detail_penjualan FOR EACH ROW EXECUTE FUNCTION trg_fn_detail_after_delete();

-- Detail transaksi tidak boleh diubah langsung (batalkan lalu buat ulang)
CREATE OR REPLACE FUNCTION trg_fn_detail_no_update() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Detail penjualan tidak boleh diubah. Batalkan transaksi lalu buat ulang';
END $$;

CREATE TRIGGER trg_detail_no_update
BEFORE UPDATE ON detail_penjualan FOR EACH ROW EXECUTE FUNCTION trg_fn_detail_no_update();

-- Audit trail generik (argumen trigger = nama kolom primary key)
CREATE OR REPLACE FUNCTION trg_fn_audit() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
    v_pk TEXT := TG_ARGV[0];
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(nama_tabel, aksi, id_record, data_baru)
        VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(NEW)->>v_pk, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(nama_tabel, aksi, id_record, data_lama, data_baru)
        VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(NEW)->>v_pk, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        INSERT INTO audit_log(nama_tabel, aksi, id_record, data_lama)
        VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD)->>v_pk, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END $$;

CREATE TRIGGER trg_audit_pelanggan AFTER INSERT OR UPDATE OR DELETE ON pelanggan
    FOR EACH ROW EXECUTE FUNCTION trg_fn_audit('id_pelanggan');
CREATE TRIGGER trg_audit_produk AFTER INSERT OR UPDATE OR DELETE ON produk
    FOR EACH ROW EXECUTE FUNCTION trg_fn_audit('id_produk');
CREATE TRIGGER trg_audit_penjualan AFTER INSERT OR UPDATE OR DELETE ON penjualan
    FOR EACH ROW EXECUTE FUNCTION trg_fn_audit('id_penjualan');
CREATE TRIGGER trg_audit_detail AFTER INSERT OR DELETE ON detail_penjualan
    FOR EACH ROW EXECUTE FUNCTION trg_fn_audit('id_detail');
