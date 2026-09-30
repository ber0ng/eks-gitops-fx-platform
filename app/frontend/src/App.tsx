import { useEffect, useState } from "react";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import "./App.css";

type Rate = { pair: string; rate: number; date: string };

const formatPair = (p: string) => `${p.slice(0, 3)}/${p.slice(3)}`;

export default function App() {
  const [rates, setRates] = useState<Rate[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [history, setHistory] = useState<Rate[]>([]);
  const [error, setError] = useState<string | null>(null);

  // Load latest rates once
  useEffect(() => {
    fetch("/api/rates")
      .then((res) => {
        if (!res.ok) throw new Error(`API returned ${res.status}`);
        return res.json();
      })
      .then((data: Rate[]) => {
        setRates(data);
        if (data.length > 0) setSelected(data[0].pair);
      })
      .catch((err) => setError(err.message));
  }, []);

  // Load history whenever the selected pair changes
  useEffect(() => {
    if (!selected) return;
    const controller = new AbortController();

    fetch(`/api/history/${selected}?days=90`, { signal: controller.signal })
      .then((res) => res.json())
      .then(setHistory)
      .catch(() => {});

    return () => controller.abort(); // ignore stale responses when switching fast
  }, [selected]);

  return (
    <main className="container">
      <header>
        <h1>fxwatch</h1>
        <p className="muted">
          Daily reference rates from the European Central Bank
        </p>
      </header>

      {error && <p className="error">Couldn't load rates: {error}</p>}

      <table>
        <thead>
          <tr>
            <th>Pair</th>
            <th>Rate</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          {rates.map((r) => (
            <tr
              key={r.pair}
              className={r.pair === selected ? "selected" : ""}
              onClick={() => setSelected(r.pair)}
            >
              <td>{formatPair(r.pair)}</td>
              <td className="num">{r.rate}</td>
              <td className="muted-cell">{r.date}</td>
            </tr>
          ))}
        </tbody>
      </table>

      {selected && (
        <section className="chart">
          <h2>{formatPair(selected)} history</h2>
          {history.length < 2 ? (
            <p className="muted">
              Not enough history yet. The worker adds one data point per day.
            </p>
          ) : (
            <ResponsiveContainer width="100%" height={260}>
              <LineChart data={history}>
                <XAxis dataKey="date" stroke="#8b8f98" fontSize={12} />
                <YAxis
                  domain={["auto", "auto"]}
                  stroke="#8b8f98"
                  fontSize={12}
                  width={70}
                />
                <Tooltip
                  contentStyle={{
                    background: "#171a20",
                    border: "1px solid #23262d",
                  }}
                />
                <Line
                  type="monotone"
                  dataKey="rate"
                  stroke="#6ea8fe"
                  strokeWidth={2}
                  dot={false}
                />
              </LineChart>
            </ResponsiveContainer>
          )}
        </section>
      )}
    </main>
  );
}
