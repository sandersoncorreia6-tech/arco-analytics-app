// Proxy serverless (Vercel) para a versão Web/PWA.
// - páginas FPB: contorna CORS do site;
// - mode=schedule: lê o Schedule estruturado usado pelo calendário CBB/FPB.
const PAGES = ['https://fpb.com.br/online/', 'https://fpb.com.br/'];
const HOST = 'fpb.com.br';

const CBB_CALENDAR = 'https://www.cbb.com.br/calendario';
const CBB_ACTION_FALLBACK = '7fa44f483f0a4da7815d44be667b13a23d4fc7bc44';
let cachedScheduleAction = CBB_ACTION_FALLBACK;

const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36 ARCO-Analytics-Web/0.7',
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

async function fetchText(url, options = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 15000);
  try {
    const res = await fetch(url, {
      method: options.method || 'GET',
      headers: options.headers || HEADERS,
      body: options.body,
      redirect: 'follow',
      signal: controller.signal,
    });
    const body = await res.text();
    return { ok: res.ok, status: res.status, body };
  } finally {
    clearTimeout(timer);
  }
}

function parseScheduleRsc(body) {
  const trimmed = String(body || '').trim();
  if (trimmed.startsWith('[')) {
    try {
      const value = JSON.parse(trimmed);
      return Array.isArray(value) ? value : null;
    } catch (_) {
      return null;
    }
  }
  for (const line of String(body || '').split(/\r?\n/)) {
    const colon = line.indexOf(':');
    if (colon < 0) continue;
    const payload = line.slice(colon + 1).trimStart();
    if (!payload.startsWith('[')) continue;
    try {
      const value = JSON.parse(payload);
      if (Array.isArray(value)) return value;
    } catch (_) {
      // Continua procurando outro segmento RSC.
    }
  }
  return null;
}

function actionIdFromScript(js) {
  const marker = js.indexOf('getMatchesByRange');
  if (marker < 0) return null;
  const before = js.slice(Math.max(0, marker - 900), marker);
  const ids = [...before.matchAll(/["']([0-9a-f]{32,64})["']/gi)];
  return ids.length ? ids[ids.length - 1][1] : null;
}

async function discoverScheduleAction() {
  const page = await fetchText(CBB_CALENDAR);
  if (!page.ok) return null;
  const srcs = [...page.body.matchAll(/<script[^>]+src=["']([^"']+\.js)["']/gi)]
    .map((m) => new URL(m[1], CBB_CALENDAR).toString());

  // O chunk 8056 contém atualmente a action; calendário vem logo depois.
  srcs.sort((a, b) => {
    const rank = (s) => s.includes('/8056-') ? 0 : (s.includes('/calendario/') ? 1 : 2);
    return rank(a) - rank(b);
  });

  for (const src of srcs) {
    try {
      const chunk = await fetchText(src);
      if (!chunk.ok || !chunk.body.includes('getMatchesByRange')) continue;
      const id = actionIdFromScript(chunk.body);
      if (id) return id;
    } catch (_) {
      // Um chunk pode falhar sem impedir os demais.
    }
  }
  return null;
}

async function callScheduleAction(actionId, competitionId, year) {
  const payload = JSON.stringify([{
    competitionId,
    org: 'fpb',
    fromDate: `${year}-01-01`,
    toDate: `${year}-12-31`,
  }]);
  const response = await fetchText(CBB_CALENDAR, {
    method: 'POST',
    headers: {
      ...HEADERS,
      'Accept': 'text/x-component',
      'Content-Type': 'text/plain;charset=UTF-8',
      'Next-Action': actionId,
    },
    body: payload,
  });
  if (!response.ok) return { ok: false, status: response.status, games: null };
  const games = parseScheduleRsc(response.body);
  return { ok: games !== null, status: response.status, games };
}

async function fetchSchedule(competitionId, year) {
  let result = await callScheduleAction(cachedScheduleAction, competitionId, year);
  if (result.ok) return result;

  const discovered = await discoverScheduleAction();
  if (!discovered) return result;
  cachedScheduleAction = discovered;
  result = await callScheduleAction(discovered, competitionId, year);
  return result;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  if (req.method === 'OPTIONS') return res.status(204).end();

  if (req.query && req.query.mode === 'schedule') {
    const competitionId = String(req.query.competitionId || '');
    const year = Number(req.query.year || new Date().getFullYear());
    if (!/^[0-9a-f-]{20,64}$/i.test(competitionId) || !Number.isInteger(year) || year < 2020 || year > 2040) {
      return res.status(400).json({ error: 'Parâmetros de Schedule inválidos' });
    }
    try {
      const result = await fetchSchedule(competitionId, year);
      if (!result.ok || result.games === null) {
        return res.status(result.status >= 400 ? result.status : 502).json({ error: 'Schedule FPB indisponível' });
      }
      res.setHeader('Cache-Control', 's-maxage=60, stale-while-revalidate=300');
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      return res.status(200).send(JSON.stringify(result.games));
    } catch (e) {
      return res.status(502).json({ error: 'Schedule FPB indisponível', detail: String(e && e.message ? e.message : e) });
    }
  }

  const extra = req.query && req.query.url;
  if (extra && !allowed(extra)) return res.status(400).json({ error: `Somente páginas de ${HOST}` });
  const targets = extra ? [extra] : PAGES;

  const results = await Promise.allSettled(targets.map((url) => fetchText(url)));
  const bodies = [];
  let lastStatus = 502;
  for (const r of results) {
    if (r.status === 'fulfilled') {
      lastStatus = r.value.status;
      if (r.value.ok) bodies.push(r.value.body);
    }
  }
  if (!bodies.length) {
    return res.status(lastStatus >= 400 ? lastStatus : 502).json({ error: 'Fonte FPB indisponível', status: lastStatus });
  }
  res.setHeader('Cache-Control', 's-maxage=20, stale-while-revalidate=60');
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  return res.status(200).send(bodies.join('\n'));
}
