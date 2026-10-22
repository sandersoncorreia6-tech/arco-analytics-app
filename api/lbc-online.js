export default async function handler(req, res) {
  try {
    const upstream = await fetch('https://www.lbc.org.br/', {
      headers: { 'user-agent': 'ARCO-Analytics/0.5', 'accept': 'text/html' }
    });
    const body = await upstream.text();
    res.setHeader('Cache-Control', 's-maxage=20, stale-while-revalidate=60');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.status(upstream.status).send(body);
  } catch (error) {
    res.status(502).json({ error: 'LBC indisponível', detail: String(error) });
  }
}
