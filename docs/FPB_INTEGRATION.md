# ARCO Analytics — Integração FPB

## Estratégia

O ARCO v0.3 trata dados externos como uma fonte substituível. A interface consome `FpbGameSnapshot`; a coleta fica isolada em `FpbLiveService`.

### Agora
- Consulta a página pública `https://fpb.com.br/online/`.
- Tentativa de interpretação tolerante a mudanças de HTML.
- Polling aproximado de 30 segundos enquanto o app está aberto.
- Cache do último snapshot no aparelho.
- Botão de atualização manual.

### Produção recomendada
Solicitar à FPB/Sportradar acesso oficial/licenciado a feed ou API. Ao obter endpoint e credenciais, criar um `FpbOfficialApiService` com a mesma saída (`FpbGameSnapshot`) e substituir a implementação, sem alterar telas ou analytics.

## O que não fazer
Não depender de endpoints privados descobertos por engenharia reversa, não contornar autenticação e não redistribuir feeds licenciados sem autorização.

## Próximas extensões
1. Box score por jogador em tempo real.
2. Play-by-play por posse.
3. Mapeamento automático de atletas FPB ↔ atletas ARCO.
4. Importação histórica por competição/temporada.
5. Alertas táticos em tempo real a partir do feed.
