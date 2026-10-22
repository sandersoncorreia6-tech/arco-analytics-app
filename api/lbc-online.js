// Proxy serverless (Vercel) para a versão Web/PWA: o navegador não pode ler
// lbc.org.br diretamente por causa do CORS. O app nativo (APK) não usa isto.
const PAGES = ['https://www.lbc.org.br/'];
const HOST = 'lbc.org.br';

const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36 ARCO-Analytics-Web/0.6',
  'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
  'Accept-Language': 'pt-BR,pt;q=0.9',
};

function allowed(url) {
  try {
    const u = new URL(url);
    return (u.protocol === 'https:' || u.protocol === 'http:') && (u.hostname === HOST || u.hostname.endsWith('.' + HOST));
  } catch (_) {
    return false;
  }
}

async function fetchText(url) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 12000);
  try {
    const res = await fetch(url, { headers: HEADERS, redirect: 'follow', signal: controller.signal });
    return { ok: res.ok, status: res.status, body: res.ok ? await res.text() : '' };
  } finally {
    clearTimeout(timer);
  }
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();

  const extra = req.query && req.query.url;
  if (extra && !allowed(extra)) return res.status(400).json({ error: `Somente páginas de ${HOST}` });
  const targets = extra ? [extra] : PAGES;

  const results = await Promise.allSettled(targets.map(fetchText));
  const bodies = [];
  let lastStatus = 502;
  for (const r of results) {
    if (r.status === 'fulfilled') {
      lastStatus = r.value.status;
      if (r.value.ok) bodies.push(r.value.body);
    }
  }
  if (!bodies.length) {
    return res.status(lastStatus >= 400 ? lastStatus : 502).json({ error: 'Fonte LBC indisponível', status: lastStatus });
  }
  res.setHeader('Cache-Control', 's-maxage=20, stale-while-revalidate=60');
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  return res.status(200).send(bodies.join('\n'));
}
