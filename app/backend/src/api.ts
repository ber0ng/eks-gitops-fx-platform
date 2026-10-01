import Fastify from "fastify";
import { config } from "./config.js";
import { pool, ensureSchema } from "./db.js";
import { redis, rateKey } from "./cache.js";
import client from "prom-client";

const app = Fastify({ logger: true });
const PAIR_RE = /^[A-Z]{6}$/;

type Row = { pair: string; rate: string; date: string };
const toRate = (r: Row) => ({ pair: r.pair, rate: Number(r.rate), date: r.date });

// Standard node.js process metrics: memory, CPU, event loop, lag, etc
client.collectDefaultMetrics();
const httpDuration = new client.Histogram({
    name: "http_request_duration_seconds",
    help: "HTTP request duration in seconds",
    labelNames: ["method", "route", "status_code"],
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
});

const SKIP_ROUTES = new Set(["/metrics", "/health", "/ready"]);

app.addHook("onResponse", async (req, reply) => {
    // Use the route template (/api/rates/:pair), not the real url (/api/rates/USDPHP)
    // so every pair shares one time series instead of creating a new one each
    const route = req.routeOptions.url ?? "unmatched";
    if (SKIP_ROUTES.has(route)) return;

    httpDuration
        .labels(req.method, route, String(reply.statusCode))
        .observe(reply.elapsedTime / 1000);
});

app.get("/metrics", async (_req, reply) => {
    reply.header("Content-Type", client.register.contentType);
    return client.register.metrics();
});

// Liveness: is the process alive?
app.get("/health", async () => ({ status: "ok" }));

// Readiness: can we serve traffic? Only postgres is required;
// if Redis is down we still serve from the database
app.get("/ready", async (_req, reply) => {
    try {
        await pool.query("SELECT 1");
        return { status: "ready" };
    } catch (err) {
        app.log.warn({ err }, "readiness check failed");
        return reply.code(503).send({ status: "not ready" });
    }
});

// Public api
app.register(
    async (api) => {
        api.get("/rates", async () => {
            const { rows } = await pool.query<Row>(`
        SELECT DISTINCT ON (pair) pair, rate, rate_date::text AS date
        FROM fx_rates
        ORDER BY pair, rate_date DESC
      `);
            return rows.map(toRate);
        });

        api.get<{ Params: { pair: string } }>("/rates/:pair", async (req, reply) => {
            const pair = req.params.pair.toUpperCase();
            if (!PAIR_RE.test(pair)) {
                return reply.code(400).send({ error: "pair must look like EURUSD" });
            }

            const cached = await redis.get(rateKey(pair)).catch(() => null);
            if (cached) return { ...JSON.parse(cached), source: "cache" };

            const { rows } = await pool.query<Row>(
                `SELECT pair, rate, rate_date::text AS date
         FROM fx_rates WHERE pair = $1
         ORDER BY rate_date DESC LIMIT 1`,
                [pair],
            );
            if (rows.length === 0) {
                return reply.code(404).send({ error: `no rates for ${pair}` });
            }

            const rate = toRate(rows[0]);
            await redis
                .set(rateKey(pair), JSON.stringify(rate), "EX", config.cacheTtlSeconds)
                .catch(() => { });
            return { ...rate, source: "db" };
        });

        api.get<{ Params: { pair: string }; Querystring: { days?: string } }>(
            "/history/:pair",
            async (req, reply) => {
                const pair = req.params.pair.toUpperCase();
                if (!PAIR_RE.test(pair)) {
                    return reply.code(400).send({ error: "pair must look like EURUSD" });
                }
                const days = Math.min(Math.max(Number(req.query.days ?? 30) || 30, 1), 365);

                const { rows } = await pool.query<Row>(
                    `SELECT pair, rate, rate_date::text AS date
           FROM fx_rates
           WHERE pair = $1 AND rate_date >= CURRENT_DATE - $2::int
           ORDER BY rate_date`,
                    [pair, days],
                );
                return rows.map(toRate);
            },
        );
    },
    { prefix: "/api" },
);

// Graceful shutdown: Kubernetes sends SIGTERM before killing the pod
const shutdown = async (signal: string) => {
    app.log.info({ signal }, "shutting down");
    await app.close();
    await pool.end();
    redis.disconnect();
    process.exit(0);
};

process.on("SIGTERM", () => void shutdown("SIGTERM"));
process.on("SIGINNT", () => void shutdown("SIGINT"));

await ensureSchema();
await app.listen({ host: "0.0.0.0", port: config.port });