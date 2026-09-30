import { config } from "./config.js";
import { pool, ensureSchema } from "./db.js";
import { redis, rateKey } from "./cache.js";

type FxResponse = { base: string, date: string, rates: Record<string, number> };

const log = (level: string, msg: string, extra: object = {}) =>
    console.log(JSON.stringify({ level, msg, time: new Date().toISOString(), ...extra }));

// EURUSD, GBPUSD, USDJPY -> { EUR: [USD], GBP: [USD], USD: [JPY] }
function groupByBase(pairs: string[]): Map<string, string[]> {
    const groups = new Map<string, string[]>();
    for (const p of pairs) {
        const base = p.slice(0, 3);
        const qoute = p.slice(3, 6);
        groups.set(base, [...(groups.get(base) ?? []), qoute]);
    }
    return groups;
}

async function fetchRates(base: string, qoutes: string[]): Promise<FxResponse> {
    const url = `${config.fxApiUrl}/latest?base=${base}&symbols=${qoutes.join(",")}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) throw new Error(`FX API returned ${res.status} for base ${base}`);
    return (await res.json()) as FxResponse;
}

async function main() {
    await ensureSchema();
    let saved = 0;
    let failed = 0;

    for (const [base, qoutes] of groupByBase(config.pairs)) {
        try {
            const data = await fetchRates(base, qoutes);

            for (const qoute of qoutes) {
                const rate = data.rates[qoute];
                const pair = base + qoute;
                if (rate === undefined) {
                    log("warn", "rate missing in response", { pair });
                    failed++;
                    continue;
                }

                await pool.query(
                    `INSERT INTO fx_rates (pair, rate, rate_date) VALUES ($1, $2, $3)
                    ON CONFLICT (pair, rate_date)
                    DO UPDATE SET rate = EXCLUDED.rate, fetched_at = now()`,
                    [pair, rate, data.date],
                );

                await redis
                    .set(rateKey(pair), JSON.stringify({ pair, rate, date: data.date }), "EX", config.cacheTtlSeconds)
                    .catch((err) => log("warn", "cache write failed", { pair, error: err.message }));

                saved++;
            }
        } catch (err: any) {
            log("error", "fetch failed", { base, error: err.message });
            failed += qoutes.length;
        }
    }

    log("info", "run complete", { saved, failed });
    return failed;
}

try {
    const failed = await main();
    await pool.end();
    redis.disconnect();
    // Non zero exit marks the cron job run as failed, so it shows up in monitoring
    process.exit(failed > 0 ? 1 : 0);
} catch (err: any) {
    log("error", "worker crashed", { error: err.message });
    process.exit(1);
}