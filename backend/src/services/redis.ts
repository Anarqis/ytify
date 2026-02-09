/**
 * ============================================================================
 * Redis Service for YTFY Backend
 * ============================================================================
 * Purpose: Redis connection management and operations
 * Platform: Deno with redis npm package
 * ============================================================================
 */

import { createClient, type RedisClientType } from "npm:redis@^4.6.0";
import { config } from "../config.ts";

// ==========================================================================
// Types
// ==========================================================================

export interface RedisConfig {
  host: string;
  port: number;
  password?: string;
  db?: number;
  maxRetries?: number;
  retryDelay?: number;
}

// ==========================================================================
// Redis Client
// ==========================================================================

let redisClient: RedisClientType | null = null;
let isConnected = false;

/**
 * Initialize Redis connection
 */
export async function initRedis(redisConfig?: RedisConfig): Promise<void> {
  const cfg = redisConfig || {
    host: config.redisHost,
    port: config.redisPort,
    password: config.redisPassword,
    db: config.redisDb,
  };

  console.log(`[Redis] Connecting to ${cfg.host}:${cfg.port}...`);

  try {
    redisClient = createClient({
      socket: {
        host: cfg.host,
        port: cfg.port,
        reconnectStrategy: (retries: number) => {
          const maxRetries = cfg.maxRetries || 10;
          if (retries > maxRetries) {
            console.error(`[Redis] Max retries (${maxRetries}) exceeded`);
            return new Error("Max retries exceeded");
          }
          const delay = Math.min(retries * 100, 3000);
          console.log(
            `[Redis] Reconnecting in ${delay}ms (attempt ${retries})`,
          );
          return delay;
        },
      },
      password: cfg.password,
      database: cfg.db || 0,
    });

    redisClient.on("error", (err: Error) => {
      console.error("[Redis] Error:", err.message);
      isConnected = false;
    });

    redisClient.on("connect", () => {
      console.log("[Redis] Connected");
      isConnected = true;
    });

    redisClient.on("reconnecting", () => {
      console.log("[Redis] Reconnecting...");
      isConnected = false;
    });

    redisClient.on("ready", () => {
      console.log("[Redis] Ready");
      isConnected = true;
    });

    await redisClient.connect();
    console.log("[Redis] Initialization complete");
  } catch (error) {
    console.error("[Redis] Failed to initialize:", error);
    // Don't throw - allow app to run with in-memory cache fallback
    redisClient = null;
    isConnected = false;
  }
}

/**
 * Close Redis connection
 */
export async function closeRedis(): Promise<void> {
  if (redisClient) {
    console.log("[Redis] Closing connection...");
    await redisClient.quit();
    redisClient = null;
    isConnected = false;
    console.log("[Redis] Connection closed");
  }
}

/**
 * Check if Redis is connected
 */
export function isRedisConnected(): boolean {
  return isConnected && redisClient !== null;
}

/**
 * Get Redis client (for advanced operations)
 */
export function getRedisClient(): RedisClientType | null {
  return redisClient;
}

// ==========================================================================
// Cache Operations
// ==========================================================================

/**
 * Get value from Redis
 */
export async function get(key: string): Promise<string | null> {
  if (!isRedisConnected() || !redisClient) {
    return null;
  }

  try {
    return await redisClient.get(key);
  } catch (error) {
    console.error(`[Redis] GET error for key "${key}":`, error);
    return null;
  }
}

/**
 * Set value in Redis with optional TTL
 */
export async function set(
  key: string,
  value: string,
  ttlSeconds?: number,
): Promise<boolean> {
  if (!isRedisConnected() || !redisClient) {
    return false;
  }

  try {
    if (ttlSeconds) {
      await redisClient.setEx(key, ttlSeconds, value);
    } else {
      await redisClient.set(key, value);
    }
    return true;
  } catch (error) {
    console.error(`[Redis] SET error for key "${key}":`, error);
    return false;
  }
}

/**
 * Delete key from Redis
 */
export async function del(key: string): Promise<boolean> {
  if (!isRedisConnected() || !redisClient) {
    return false;
  }

  try {
    await redisClient.del(key);
    return true;
  } catch (error) {
    console.error(`[Redis] DEL error for key "${key}":`, error);
    return false;
  }
}

/**
 * Delete multiple keys matching a pattern
 */
export async function delPattern(pattern: string): Promise<number> {
  if (!isRedisConnected() || !redisClient) {
    return 0;
  }

  try {
    const keys = await redisClient.keys(pattern);
    if (keys.length === 0) return 0;

    await redisClient.del(keys);
    return keys.length;
  } catch (error) {
    console.error(`[Redis] DEL pattern error for "${pattern}":`, error);
    return 0;
  }
}

/**
 * Check if key exists
 */
export async function exists(key: string): Promise<boolean> {
  if (!isRedisConnected() || !redisClient) {
    return false;
  }

  try {
    const result = await redisClient.exists(key);
    return result === 1;
  } catch (error) {
    console.error(`[Redis] EXISTS error for key "${key}":`, error);
    return false;
  }
}

/**
 * Get TTL for a key
 */
export async function ttl(key: string): Promise<number> {
  if (!isRedisConnected() || !redisClient) {
    return -2;
  }

  try {
    return await redisClient.ttl(key);
  } catch (error) {
    console.error(`[Redis] TTL error for key "${key}":`, error);
    return -2;
  }
}

/**
 * Increment a counter
 */
export async function incr(key: string): Promise<number> {
  if (!isRedisConnected() || !redisClient) {
    return 0;
  }

  try {
    return await redisClient.incr(key);
  } catch (error) {
    console.error(`[Redis] INCR error for key "${key}":`, error);
    return 0;
  }
}

/**
 * Get Redis info/stats
 */
export async function getStats(): Promise<Record<string, string>> {
  if (!isRedisConnected() || !redisClient) {
    return { status: "disconnected" };
  }

  try {
    const info = await redisClient.info("stats");
    const dbSize = await redisClient.dbSize();

    return {
      status: "connected",
      dbSize: String(dbSize),
      info,
    };
  } catch (error) {
    console.error("[Redis] Stats error:", error);
    return { status: "error", error: String(error) };
  }
}
