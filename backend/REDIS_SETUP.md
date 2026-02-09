# Redis Configuration for YTFY Backend

## Environment Variables

Add these variables to your `.env` file or environment configuration:

```bash
# Redis Configuration
REDIS_ENABLED=true
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password_here
REDIS_DB=0
```

## Production Deployment

### Option 1: Local Redis on VPS

```bash
# Install Redis on Ubuntu/Debian
sudo apt update
sudo apt install redis-server

# Configure Redis
sudo nano /etc/redis/redis.conf

# Set password (recommended)
requirepass your_strong_password_here

# Bind to localhost only (for security)
bind 127.0.0.1

# Enable persistence
save 900 1
save 300 10
save 60 10000

# Restart Redis
sudo systemctl restart redis-server
sudo systemctl enable redis-server

# Test connection
redis-cli ping
# Should return: PONG
```

### Option 2: Redis Cloud (Managed Service)

Use a managed Redis service like:

- **Redis Cloud** (free tier available)
- **Upstash** (serverless Redis)
- **AWS ElastiCache**
- **DigitalOcean Managed Redis**

Update `.env.production`:

```bash
REDIS_ENABLED=true
REDIS_HOST=your-redis-cloud-host.com
REDIS_PORT=6379
REDIS_PASSWORD=your_cloud_password
REDIS_DB=0
```

## Cache Strategy

The backend uses a **hybrid caching approach**:

1. **Primary**: Redis (distributed, persistent)
2. **Fallback**: In-memory Map (when Redis unavailable)

### Cache TTLs by Route

| Route             | TTL      | Purpose               |
| ----------------- | -------- | --------------------- |
| `/api/v1/videos/` | 30 min   | Video metadata        |
| `/s/`             | 1 hour   | Link previews         |
| `/ss/`            | 24 hours | Static storage        |
| Default           | 5 min    | General API responses |

### Cache Headers

Responses include:

- `ETag`: Content hash for conditional requests
- `Cache-Control`: `public, max-age=X, stale-while-revalidate=60`
- `X-Cache`: `HIT`, `MISS`, or `STALE`
- `Age`: Seconds since cached

## Monitoring

### Check Redis Status

```bash
# Via health endpoint
curl https://ytify.ml4-lab.com/health

# Response includes:
{
  "status": "ok",
  "storage": "ok",
  "redis": "connected",
  "timestamp": "2026-02-09T19:30:00.000Z"
}
```

### Redis CLI Commands

```bash
# Connect to Redis
redis-cli -h localhost -p 6379 -a your_password

# Check cache keys
KEYS ytfy:cache:*

# Get cache stats
INFO stats

# Monitor cache operations (real-time)
MONITOR

# Check memory usage
INFO memory

# Clear all cache
FLUSHDB
```

## Performance Impact

### Expected Improvements

| Metric            | Before | After | Improvement    |
| ----------------- | ------ | ----- | -------------- |
| API Response Time | ~150ms | <50ms | 66% faster     |
| Cache Hit Rate    | 0%     | >80%  | New capability |
| Database Load     | 100%   | <20%  | 80% reduction  |
| Concurrent Users  | ~100   | ~500  | 5x capacity    |

### Cache Hit Rate Targets

- **Cold start**: 0-20% (first 5 minutes)
- **Warm**: 60-80% (after 30 minutes)
- **Hot**: 80-95% (steady state)

## Troubleshooting

### Redis Connection Failed

If Redis is unavailable, the app will:

1. Log warning: `[Redis] Failed to initialize`
2. Continue running with in-memory cache
3. Health endpoint shows `redis: "disconnected"`

### Clear Cache

```typescript
// Via API (add admin endpoint)
import { clearCache } from './middleware/cache.ts';
await clearCache();

// Via Redis CLI
redis-cli FLUSHDB
```

### Memory Issues

If Redis memory grows too large:

```bash
# Check memory
redis-cli INFO memory

# Set max memory limit (e.g., 256MB)
redis-cli CONFIG SET maxmemory 256mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru

# Make permanent in redis.conf
maxmemory 256mb
maxmemory-policy allkeys-lru
```

## Security Best Practices

1. **Always use password** in production
2. **Bind to localhost** if on same server
3. **Use TLS** for remote connections
4. **Limit max connections**: `maxclients 1000`
5. **Disable dangerous commands**:
   ```
   rename-command FLUSHDB ""
   rename-command FLUSHALL ""
   rename-command CONFIG ""
   ```

## Next Steps

1. Deploy Redis on VPS or use managed service
2. Update `.env.production` with Redis credentials
3. Restart backend: `sudo systemctl restart ytify-backend`
4. Monitor cache hit rates via health endpoint
5. Adjust TTLs based on usage patterns
