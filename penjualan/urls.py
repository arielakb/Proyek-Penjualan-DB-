from django.urls import path

from . import views

urlpatterns = [
    path("login/", views.login_view, name="login"),
    path("logout/", views.logout_view, name="logout"),
    path("", views.index, name="index"),

    path("pelanggan/", views.pelanggan, name="pelanggan"),
    path("pelanggan/tambah/", views.pelanggan_tambah, name="pelanggan_tambah"),
    path("pelanggan/<int:id>/ubah/", views.pelanggan_ubah, name="pelanggan_ubah"),
    path("pelanggan/<int:id>/hapus/", views.pelanggan_hapus, name="pelanggan_hapus"),

    path("produk/", views.produk, name="produk"),
    path("produk/tambah/", views.produk_tambah, name="produk_tambah"),
    path("produk/<int:id>/ubah/", views.produk_ubah, name="produk_ubah"),
    path("produk/<int:id>/hapus/", views.produk_hapus, name="produk_hapus"),

    path("penjualan/", views.penjualan, name="penjualan"),
    path("penjualan/baru/", views.penjualan_baru, name="penjualan_baru"),
    path("penjualan/<int:id>/", views.penjualan_detail, name="penjualan_detail"),
    path("penjualan/<int:id>/batal/", views.penjualan_batal, name="penjualan_batal"),
]
