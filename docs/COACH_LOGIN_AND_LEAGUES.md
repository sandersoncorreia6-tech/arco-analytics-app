# ARCO v0.5 — Treinador, FPB, LBC e vídeos

## Conta demo
A versão inclui uma sessão LOCAL de demonstração para:
- Treinador: Adriano Mião
- Clube: Tupã / Monstrinho
- Cidade: Tupã - SP

Acesso demo:
- e-mail: `adriano.miao@arco.app`
- senha: `ARCO-DEMO`

IMPORTANTE: estas credenciais não são autenticação de produção. Como o código pode ficar público, nenhuma senha real deve ser colocada no repositório. Antes de uso comercial, substituir por Firebase Auth, Supabase Auth ou backend próprio.

## Competições
A tela Competições unifica:
- FPB — Federação Paulista de Basketball
- LBC — Liga de Basquete do Centro-Oeste Paulista

Filtros previstos/implementados:
- federação/liga
- categoria
- busca por equipe
- status conforme informação recebida da fonte

A arquitetura usa adaptadores separados. Se uma fonte mudar de HTML para API/feed oficial, basta trocar o serviço daquela liga.

## Vídeos
Cada jogo pode receber um link do YouTube. O vínculo é salvo localmente no dispositivo/browser e aparece como botão de vídeo no calendário.

Próxima evolução recomendada:
- armazenar links em banco cloud por equipe
- permissões para técnico/auxiliar/analista
- anexar playlists/canal oficial
- análise automática do vídeo somente quando houver pipeline/licenciamento adequado
