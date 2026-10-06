"""
Pengaturan Django. Aplikasi ini TIDAK memakai ORM Django:
semua akses data lewat stored procedure/function (lihat penjualan/db.py),
sehingga DATABASES sengaja dikosongkan. Sesi memakai signed cookie
(tanpa tabel sesi di database).
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
SECRET_KEY = os.getenv("SECRET_KEY", "ganti-dengan-kunci-rahasia")
DEBUG = os.getenv("DEBUG", "1") == "1"
ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

# Koneksi khusus untuk db.py (user aplikasi: hanya GRANT EXECUTE)
DB_APP = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "dbname": os.getenv("DB_NAME", "db_penjualan"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "root"),
}

INSTALLED_APPS = [
    "django.contrib.sessions",
    "django.contrib.messages",
    "penjualan",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "konfigurasi.urls"
WSGI_APPLICATION = "konfigurasi.wsgi.application"

TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "APP_DIRS": True,
    "OPTIONS": {
        "context_processors": [
            "django.template.context_processors.request",
            "django.contrib.messages.context_processors.messages",
        ],
        "builtins": ["penjualan.templatetags.app_tags"],
    },
}]

DATABASES = {}                                   # tanpa ORM
SESSION_ENGINE = "django.contrib.sessions.backends.signed_cookies"
MESSAGE_STORAGE = "django.contrib.messages.storage.cookie.CookieStorage"

LANGUAGE_CODE = "id"
TIME_ZONE = "Asia/Jakarta"
USE_TZ = False
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
