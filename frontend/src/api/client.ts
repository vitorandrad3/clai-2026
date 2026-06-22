const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:8000";

export interface Health {
  status: string;
  env: string;
}

export async function getHealth(): Promise<Health> {
  const res = await fetch(`${BASE_URL}/health`);
  if (!res.ok) throw new Error(`API respondeu ${res.status}`);
  return res.json();
}
