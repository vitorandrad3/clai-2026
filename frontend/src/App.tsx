import { useEffect, useState } from "react";
import { getHealth } from "./api/client";

export default function App() {
  const [status, setStatus] = useState("verificando backend...");

  useEffect(() => {
    getHealth()
      .then((h) => setStatus(`backend: ${h.status} (${h.env})`))
      .catch(() => setStatus("backend indisponível"));
  }, []);

  return (
    <main style={{ fontFamily: "system-ui, sans-serif", padding: "2rem" }}>
      <h1>CLAI 2026</h1>
      <p>Plataforma de auditoria interna assistida por IA.</p>
      <p>Status: {status}</p>
    </main>
  );
}
