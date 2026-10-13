from pathlib import Path
from datetime import timedelta
import os
import dj_database_url
from dotenv import load_dotenv
load_dotenv()


BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = os.environ.get(
    'DJANGO_SECRET_KEY',
    'django-insecure-apbqh$t6x&l7ig@-x@u5laj=j&40*_*t=v&9p678$sd%whc)gq',
)
# Set DJANGO_DEBUG=False in .env before deploying.
DEBUG = os.environ.get('DJANGO_DEBUG', 'True').lower() in ('1', 'true', 'yes')
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'corsheaders',
    'detection',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'backend.urls'
WSGI_APPLICATION = 'backend.wsgi.application'

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [],
    'APP_DIRS': True,
    'OPTIONS': {'context_processors': [
        'django.template.context_processors.request',
        'django.contrib.auth.context_processors.auth',
        'django.contrib.messages.context_processors.messages',
    ]},
}]


DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# ── DRF + JWT ───────────────────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ),
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=7),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=30),
    'AUTH_HEADER_TYPES': ('Bearer',),
}

CORS_ALLOW_ALL_ORIGINS = True

# ── Email (Gmail SMTP) — every OTP is delivered by email ───────────────────
# 1. Turn on 2-Step Verification for the Gmail account
# 2. Create an App Password: https://myaccount.google.com/apppasswords
# 3. Put the address and the 16-character app password in .env
EMAIL_HOST_USER     = os.environ.get('EMAIL_HOST_USER', '').strip()
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '').strip()

# The values in a fresh .env are placeholders, not real credentials. Treat them
# as "not configured" so we never attempt SMTP with an app password of "abc".
_EMAIL_PLACEHOLDERS = {
    '',
    'youremail@gmail.com',
    'your_email@gmail.com',
    'abcdefghijklmnop',
    'your_app_password',
    'your_auth_token_here',
}
EMAIL_IS_CONFIGURED = (
    EMAIL_HOST_USER not in _EMAIL_PLACEHOLDERS
    and EMAIL_HOST_PASSWORD not in _EMAIL_PLACEHOLDERS
)

EMAIL_HOST         = os.environ.get('EMAIL_HOST', 'smtp.gmail.com')
EMAIL_PORT         = int(os.environ.get('EMAIL_PORT', 587))
EMAIL_USE_TLS      = True
EMAIL_TIMEOUT = 15  # don't let the request hang if Gmail is unreachable
DEFAULT_FROM_EMAIL = EMAIL_HOST_USER or 'FuelSense <no-reply@fuelsense.local>'

if EMAIL_IS_CONFIGURED:
    EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
else:
    # No usable credentials: print the OTP email to the runserver console
    # instead of failing the request. Fill in .env to send real mail.
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# ── OTP ─────────────────────────────────────────────────────────────────────
OTP_EXPIRY_SECONDS = int(os.environ.get('OTP_EXPIRY_SECONDS', 300))   # 5 minutes
# While True, the OTP endpoints include the code in the response ("dev_otp") so
# signup and reset can be tested without a working mailbox.
# Set OTP_DEV_MODE=False in .env before deploying.
OTP_DEV_MODE = os.environ.get('OTP_DEV_MODE', 'True').lower() in ('1', 'true', 'yes')

# Shared secret the YOLO detector sends with POST /api/update_queue/
DETECTION_API_KEY = os.environ.get('DETECTION_API_KEY', 'fuelsense2024')

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Karachi'
USE_I18N = True
USE_TZ = True
STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
