# ARCO — Nuvem com Supabase (Etapa 2)

O banco está pronto em `supabase/migrations/0001_arco_schema.sql`: clubes isolados por
RLS, papéis da comissão, categorias, temporadas, atletas, jogos, scout com sincronização
offline, vídeos, clipes, relatórios com link privado, feedback ao atleta, planos,
assinaturas, teste de 14 dias e bloqueio de clientes.

## O que vocês precisam fazer (10 minutos)
1. Criar conta em https://supabase.com e um projeto (região São Paulo).
2. **SQL Editor** → colar o conteúdo de `0001_arco_schema.sql` → **Run**.
3. **Authentication → Providers → Email**: manter ativo (login por e-mail e senha;
   a recuperação de senha já vem pronta).
4. **Authentication → URL Configuration**: adicionar o endereço da versão Web e
   `com.arcoanalytics.app://login-callback` (link de recuperação de senha no app).
5. **Project Settings → API**: copiar **Project URL** e **anon public key**.
6. No GitHub do ARCO: **Settings → Secrets and variables → Actions → Variables**:
   - `ARCO_SUPABASE_URL` = Project URL
   - `ARCO_SUPABASE_ANON_KEY` = anon public key
   (a anon key é pública por design; a segurança vem das regras RLS do banco.)
7. Tornar vocês administradores da plataforma (depois de criar a conta no app):
   ```sql
   update profiles set is_platform_admin = true where user_id = (select id from auth.users where email = 'seu@email.com');
   ```

## Depois de configurar
Os builds passam a incluir a URL e a chave; o app mostra a tela de login real (Entrar, Criar
conta, Esqueci a senha). No primeiro acesso o treinador cria o clube, a equipe/categoria e a
temporada. Tudo é salvo no aparelho primeiro e enviado à nuvem quando houver internet
(Mais → Nuvem e backup mostra o que está pendente).

## Papéis
| Papel | Pode |
|---|---|
| owner / admin | tudo no clube, convidar e remover membros |
| coach / analyst / assistant | criar e editar jogos, scout, vídeos, relatórios, atletas |
| board (diretoria) | ver tudo, sem editar |
| athlete | ver jogos, vídeos/clipes, o próprio cadastro e o próprio feedback |

## Licenciamento
O acesso depende do status do **clube** (teste dentro do prazo ou ativo). Um APK copiado
não dá acesso a nada: sem conta vinculada a um clube liberado, o banco não devolve dados.
Bloquear um cliente: `update clubs set status = 'blocked' where id = '...'` (ou pelo painel
administrativo, próxima etapa).
