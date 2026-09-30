import { Redis } from "ioredis";
import { config } from "./config.js";

export const redis = new Redis(config.redisUrl, {
    maxRetriesPerRequest: 1, // fail fast; API will falls back to Postgres
    connectTimeout: 5000,
});

redis.on("error", (err) => {
    console.warn(JSON.stringify({ level: "warn", msg: "redis error", error: err.message }));
});

export const rateKey = (pair: string) => `rate:${pair}`;