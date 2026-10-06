"""
Lapisan akses database.
ATURAN: modul ini HANYA memanggil stored procedure (CALL ...) dan function
(SELECT * FROM fn_...). Tidak ada query CRUD dan tidak ada logika bisnis.
Seluruh nilai dikirim sebagai parameter (psycopg2) -> aman dari SQL injection.
"""
import psycopg2
from django.conf import settings
from psycopg2 import sql
from psycopg2.extras import Json, RealDictCursor


class DBError(Exception):
    """Error dari database dengan pesan yang sudah dibersihkan untuk ditampilkan."""


def _pesan(e):
    return (e.diag.message_primary if e.diag and e.diag.message_primary else str(e)).strip()


def _jalankan(query, params, ambil):
    conn = None
    try:
        conn = psycopg2.connect(**settings.DB_APP)    # transaksi dimulai otomatis (START TRANSACTION)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, params)
            hasil = cur.fetchall() if ambil == "all" else (cur.fetchone() if ambil == "one" else None)
        conn.commit()                                 # COMMIT bila semua berhasil
        return hasil
    except psycopg2.Error as e:
        if conn:
            conn.rollback()                           # ROLLBACK bila terjadi error
        raise DBError(_pesan(e)) from e
    finally:
        if conn:
            conn.close()


def panggil_prosedur(nama, *args, ambil="none"):
    """CALL nama(arg1, ...). Pakai ambil='one' bila prosedur punya parameter INOUT."""
    ph = sql.SQL(", ").join(sql.Placeholder() * len(args))
    return _jalankan(sql.SQL("CALL {}({})").format(sql.Identifier(nama), ph), args, ambil)


def panggil_fungsi(nama, *args):
    """SELECT * FROM nama(arg1, ...) -> list of dict."""
    ph = sql.SQL(", ").join(sql.Placeholder() * len(args))
    return _jalankan(sql.SQL("SELECT * FROM {}({})").format(sql.Identifier(nama), ph), args, "all")


def json_param(obj):
    return Json(obj)
