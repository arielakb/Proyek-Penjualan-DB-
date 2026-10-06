"""View Django. Seluruh data diperoleh/diubah hanya lewat db.panggil_prosedur / db.panggil_fungsi."""
from functools import wraps

from django.contrib import messages
from django.shortcuts import redirect, render
from django.views.decorators.http import require_POST

from .db import DBError, json_param, panggil_fungsi, panggil_prosedur


def wajib_login(view):
    @wraps(view)
    def wrapper(request, *a, **kw):
        if not request.session.get("user"):
            return redirect("login")
        return view(request, *a, **kw)
    return wrapper


def kosong_jadi_none(v):
    v = (v or "").strip()
    return v or None


def aksi(request, panggilan, pesan_sukses, tujuan):
    """Jalankan satu panggilan database; tampilkan pesan sukses/gagal."""
    try:
        panggilan()
        messages.success(request, pesan_sukses)
    except DBError as e:
        messages.error(request, f"Gagal: {e}")
    return redirect(tujuan)


def ambil(request, nama_fungsi, *args):
    try:
        return panggil_fungsi(nama_fungsi, *args)
    except DBError as e:
        messages.error(request, f"Gagal: {e}")
        return []


# ---------------- Login ----------------
def login_view(request):
    if request.method == "POST":
        user, pw = request.POST.get("username", ""), request.POST.get("password", "")
        try:
            ok = panggil_fungsi("fn_login", user, pw)[0]["fn_login"]
        except DBError as e:
            messages.error(request, f"Gagal: {e}")
            ok = None
        if ok:
            request.session["user"] = user
            return redirect("index")
        if ok is not None:
            messages.error(request, "Username atau password salah")
    return render(request, "penjualan/login.html")


def logout_view(request):
    request.session.flush()
    return redirect("login")


# ---------------- Dashboard ----------------
@wajib_login
def index(request):
    return render(request, "penjualan/index.html", {
        "pelanggan": ambil(request, "fn_laporan_pelanggan"),
        "produk": ambil(request, "fn_laporan_produk"),
    })


# ---------------- Pelanggan ----------------
@wajib_login
def pelanggan(request):
    q = request.GET.get("q", "").strip()
    data = ambil(request, "fn_cari_pelanggan", q) if q else ambil(request, "fn_tampil_pelanggan")
    return render(request, "penjualan/pelanggan.html", {"data": data, "q": q})


@wajib_login
@require_POST
def pelanggan_tambah(request):
    f = request.POST
    return aksi(request, lambda: panggil_prosedur(
        "sp_tambah_pelanggan", f.get("nama", ""), f.get("alamat", ""), f.get("telepon", ""),
        f.get("email", ""), None, ambil="one"), "Pelanggan ditambahkan", "pelanggan")


@wajib_login
@require_POST
def pelanggan_ubah(request, id):
    f = request.POST
    return aksi(request, lambda: panggil_prosedur(
        "sp_ubah_pelanggan", id, f.get("nama", ""), f.get("alamat", ""), f.get("telepon", ""),
        f.get("email", "")), "Pelanggan diubah", "pelanggan")


@wajib_login
@require_POST
def pelanggan_hapus(request, id):
    return aksi(request, lambda: panggil_prosedur("sp_hapus_pelanggan", id), "Pelanggan dihapus", "pelanggan")


# ---------------- Produk ----------------
@wajib_login
def produk(request):
    q = request.GET.get("q", "").strip()
    data = ambil(request, "fn_cari_produk", q) if q else ambil(request, "fn_tampil_produk")
    return render(request, "penjualan/produk.html", {"data": data, "q": q})


@wajib_login
@require_POST
def produk_tambah(request):
    f = request.POST
    return aksi(request, lambda: panggil_prosedur(
        "sp_tambah_produk", f.get("nama", ""), f.get("harga", ""), int(f.get("stok") or 0), None, ambil="one"),
        "Produk ditambahkan", "produk")


@wajib_login
@require_POST
def produk_ubah(request, id):
    f = request.POST
    return aksi(request, lambda: panggil_prosedur(
        "sp_ubah_produk", id, f.get("nama", ""), f.get("harga", ""), int(f.get("stok") or 0)),
        "Produk diubah", "produk")


@wajib_login
@require_POST
def produk_hapus(request, id):
    return aksi(request, lambda: panggil_prosedur("sp_hapus_produk", id), "Produk dihapus", "produk")


# ---------------- Penjualan ----------------
@wajib_login
def penjualan(request):
    dari = kosong_jadi_none(request.GET.get("dari"))
    sampai = kosong_jadi_none(request.GET.get("sampai"))
    nama = kosong_jadi_none(request.GET.get("nama"))
    if dari or sampai or nama:
        data = ambil(request, "fn_cari_penjualan", dari, sampai, nama)
    else:
        data = ambil(request, "fn_tampil_penjualan")
    return render(request, "penjualan/penjualan.html",
                  {"data": data, "dari": dari or "", "sampai": sampai or "", "nama": nama or ""})


@wajib_login
def penjualan_baru(request):
    if request.method == "POST":
        ids = request.POST.getlist("id_produk")
        jml = request.POST.getlist("jumlah")
        items = [{"id_produk": int(i), "jumlah": int(j)} for i, j in zip(ids, jml) if i and j]
        try:
            hasil = panggil_prosedur("sp_buat_penjualan", int(request.POST.get("id_pelanggan") or 0),
                                     json_param(items), None, ambil="one")
            messages.success(request, f"Penjualan #{hasil['p_id_penjualan']} berhasil disimpan")
            return redirect("penjualan_detail", id=hasil["p_id_penjualan"])
        except DBError as e:
            messages.error(request, f"Transaksi dibatalkan (ROLLBACK): {e}")
    return render(request, "penjualan/penjualan_baru.html", {
        "pelanggan": ambil(request, "fn_tampil_pelanggan"),
        "produk": ambil(request, "fn_tampil_produk"),
    })


@wajib_login
def penjualan_detail(request, id):
    try:
        header = [r for r in panggil_fungsi("fn_tampil_penjualan") if r["id_penjualan"] == id]
        detail = panggil_fungsi("fn_detail_penjualan", id)
    except DBError as e:
        messages.error(request, f"Gagal: {e}")
        return redirect("penjualan")
    if not header:
        messages.error(request, "Penjualan tidak ditemukan")
        return redirect("penjualan")
    return render(request, "penjualan/penjualan_detail.html", {"h": header[0], "detail": detail})


@wajib_login
@require_POST
def penjualan_batal(request, id):
    return aksi(request, lambda: panggil_prosedur("sp_batal_penjualan", id),
                "Penjualan dibatalkan, stok dikembalikan", "penjualan")
