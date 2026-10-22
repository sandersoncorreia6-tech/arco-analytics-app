// Proxy serverless (Vercel) da estatística online FIBA LiveStats para a versão
// Web/PWA. Uso: /api/livestats?id=2512345. O app nativo (APK) não usa isto.
const DATA_HOST = 'https://fibalivestats.dcd.shared.geniussports.com';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();

  const id = String((req.query && req.query.id) || '');
  if (!/^\d{5,9}$/.test(id)) return res.status(400).json({ error: 'Parâmetro id inválido' });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);
  try {
    const upstream = await fetch(`${DATA_HOST}/data/${id}/data.json`, {
      headers: { 'User-Agent': 'Mozilla/5.0 ARCO-Analytics-Web/0.7', Accept: 'application/json' },
      signal: controller.signal,
    });
    if (!upstream.ok) return res.status(upstream.status).json({ error: 'Estatística indisponível', status: upstream.status });
    const body = await upstream.text();
    res.setHeader('Cache-Control', 's-maxage=15, stale-while-revalidate=30');
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    return res.status(200).send(body);
  } catch (error) {
    return res.status(502).json({ error: 'Falha ao consultar a estatística', detail: String(error) });
  } finally {
    clearTimeout(timer);
  }
}
