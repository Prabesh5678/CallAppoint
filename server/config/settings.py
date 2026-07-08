from decouple import config

SECRET_KEY = config('DJANGO_SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    'rest_framework',
    'corsheaders',

    'accounts',
    'doctors',
    'appointments',
    'prescriptions',
    'medical_reports',
    'reviews',
    'payments',
    'chat',
    'notifications',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    # ...rest of the default middleware...
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('SUPABASE_DB_NAME', default='postgres'),
        'USER': config('SUPABASE_DB_USER'),
        'PASSWORD': config('SUPABASE_DB_PASSWORD'),
        'HOST': config('SUPABASE_DB_HOST'),
        'PORT': config('SUPABASE_DB_PORT', default='5432'),
    }
}

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'accounts.authentication.SupabaseJWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

SUPABASE_JWT_SECRET = config('SUPABASE_JWT_SECRET')

# dev only — tighten before prod
CORS_ALLOW_ALL_ORIGINS = DEBUG