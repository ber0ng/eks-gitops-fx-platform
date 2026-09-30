export const config = {
    port: Number(process.env.PORT ?? 3000),
    redisUrl: process.env.REDIS_URL ?? "redis://localhost:6379",
    fxApiUrl: process.env.FX_API_URL ?? "https://api.frankfurter.dev/v1",
    pairs: (process.env.FX_PAIRS ?? "EURUSD, GBPUSD, USDJPY, AUDUSD, USDPHP")
        .split(",")
        .map((p) => p.trim().toUpperCase())
        .filter(Boolean),
    cacheTtlSeconds: Number(process.env.CACHE_TTL_SECONDS ?? 3600),
}