#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

echo "Starting DefectDojo initialization..."

# Run database migrations
python manage.py migrate --noinput
echo "Migrations completed."

# Load initial data, continue if it fails
python manage.py loaddata system_settings initial_banner_conf product_type test_type development_environment benchmark_type || echo "Initial data load failed, continuing..."
echo "Initial data loaded."

# Create a superuser if one doesn't exist
python manage.py shell -c "
from django.contrib.auth import get_user_model
import os
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', os.environ['DD_ADMIN_PASSWORD'])
    print('Superuser created')
else:
    print('Superuser already exists')
" || echo "Superuser creation failed, continuing..."

echo "Starting uWSGI server..."
#!/bin/bash

# Debug: Show static files
echo "=== Static files debug ==="
ls -la /app/static/ || echo "No /app/static directory"
find /app -name "bootstrap.min.css" 2>/dev/null || echo "bootstrap.min.css not found"

# Start uWSGI with static file mappings and debugging
echo "=== Starting uWSGI ==="
exec uwsgi \
  --module=dojo.wsgi:application \
  --env DJANGO_SETTINGS_MODULE=dojo.settings.settings \
  --http=0.0.0.0:8081 \
  --processes=1 \
  --threads=2 \
  --static-map /static=/app/static \
  --static-map /media=/app/media \
  --check-static /app \
  --static-safe /app/static \
  --enable-threads \
  --die-on-term \
  --stats=127.0.0.1:9191 \
  --stats-http
