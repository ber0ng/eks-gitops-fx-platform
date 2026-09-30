import Fastify from "fastify";
import { config } from "./config.js";
import { pool, ensureSchema } from "./db.js";
import { redis, rateKey } from "./cache.js";

const app = Fastify({ logger: true });
const PAIR_RE = /^[A-Z]{6}$/;

type Row = { pair: string; rate: string; date: string };
const toRate = (r: Row) => ({ pair: r.pair, rate: Number(r.rate), date: r.date });

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

app.get("/rates", async () => {
    const { rows } = await pool.query<Row>(`
        SELECT DISTINCT ON (pair) pair, rate, rate_date::text AS date
        FROM fx_rates
        ORDER BY pair, rate_date DESC
    `);
    return rows.map(toRate);
});

app.get<{ Params: { pair: string } }>("/rates/:pair", async (req, reply) => {
    const pair = req.params.pair.toUpperCase();
    if (!PAIR_RE.test(pair)) {
        return reply.code(400).send({ error: "pair must look like EURUSD" });
    }

    const cached = await redis.get(rateKey(pair)).catch(() => null);
    if (cached) return { ...JSON.parse(cached), source: "cache" };

    const { rows } = await pool.query<Row>(`
       SELECT pair, rate, rate_date::text AS date
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

app.get<{ Params: { pair: string }; Querystring: { days?: string } }>(
    "/history/:pair",
    async (req, reply) => {
        const pair = req.params.pair.toUpperCase();
        if (!PAIR_RE.test(pair)) {
            return reply.code(400).send({ error: "pair must look like EURUSD " });
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
    }
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