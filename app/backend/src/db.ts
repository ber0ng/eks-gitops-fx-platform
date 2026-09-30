import fs from "node:fs";
import pg from "pg";

// Connection settings come from standard pg env vars: 

// On EKS, PGSSLROOTCERT points to the rds CA bundle baked into the image, so the connection is encrypted and the server certificate is verified
// Locally, it's unset, so we connect to the compose Postgres without TLS

const caPath = process.env.PGSSLROOTCERT;

export const pool = new pg.Pool({
    max: 10,
    ssl: caPath ? { ca: fs.readFileSync(caPath, "utf8") } : undefined,
})

const SCHEMA = `
    CREATE TABLE IF NOT EXISTS fx_rates (
        pair TEXT NOT NULL,
        rate NUMERIC(18,8) NOT NULL,
        rate_date DATE NOT NULL,
        fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        PRIMARY KEY (pair, rate_date)
    );
`;

export async function ensureSchema(): Promise<void> {
    try {
        await pool.query(SCHEMA)
    } catch (err: any) {
        // Several pods starting at once can race on CREATE TABLE; that's fine
        if (err.code !== "23505" && err.code !== "42P07") throw err;
    }
}

