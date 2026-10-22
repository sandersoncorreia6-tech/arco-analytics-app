# Arquitetura — ARCO Analytics

## Estado atual

A v0.5 já separa modelos, serviços, estado, telas e widgets. Isso deve ser preservado, evitando concentrar novas regras dentro das telas.

## Direção recomendada

A evolução deve caminhar para estas camadas:

- **presentation**: telas e widgets;
- **domain**: entidades e regras de negócio;
- **data**: persistência, DTOs e fontes;
- **repositories**: contratos de acesso aos dados;
- **services/providers**: FPB, LBC, vídeo, autenticação e sincronização.

## Entidades centrais futuras

- User
- Organization
- Coach
- Team
- Player
- Season
- Competition
- Category
- Game
- GameEvent
- Lineup
- Shot
- Video

## Relação principal

Organization
→ Team
→ Season
→ Competition / Category
→ Game
→ Events / Lineups / Shots / Video

## Regras

1. Não identificar equipe apenas por texto como "Tupã" ou "Monstrinho"; usar IDs.
2. Não limitar histórico a uma quantidade fixa de partidas.
3. O app deve consultar dados persistentes; mocks ficam somente para desenvolvimento.
4. FPB e LBC devem permanecer desacopladas atrás de providers/repositories.
5. Scout precisa funcionar offline e sincronizar depois.
6. Insights devem carregar contexto e confiança de amostra, não apenas números.
