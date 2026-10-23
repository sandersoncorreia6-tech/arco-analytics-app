export default async function handler(req, res) {
  try {
    const headers = { 'User-Agent': 'ARCO-Analytics-Web/0.5', 'Accept': 'text/html' };
    const [online, home] = await Promise.allSettled([
      fetch('https://fpb.com.br/online/', { headers }),
      fetch('https://fpb.com.br/', { headers })
    ]);
    const bodies = [];
    for (const result of [online, home]) {
      if (result.status === 'fulfilled' && result.value.ok) bodies.push(await result.value.text());
    }
    if (!bodies.length) return res.status(502).json({ error: 'Fontes FPB indisponíveis' });
    res.setHeader('Cache-Control', 's-maxage=15, stale-while-revalidate=30');
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.status(200).send(bodies.join('\n'));
  } catch (error) {
    res.status(502).json({error: 'Falha ao consultar a fonte FPB', detail: String(error)});
  }
}
