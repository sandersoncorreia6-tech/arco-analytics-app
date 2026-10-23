# Modelo federativo — CBB, FPB e ARCO

## O que significa “vinculado à CBB”

A CBB é a entidade nacional do basquete brasileiro. As federações estaduais integram esse sistema, e a Federação Paulista de Basketball (FPB) é uma federação filiada à CBB.

Para o ARCO, isso significa que os dados não devem ser organizados apenas pelo nome visual de uma equipe. A identidade precisa respeitar a hierarquia:

**CBB → Federação estadual (FPB) → clube/entidade → equipe/categoria → temporada → competição → jogo**

## Situação de Tupã no ARCO

O ARCO encontrou nomes públicos usados pela FPB para equipes de Tupã, incluindo:

- ATB - Associação Tupã Basquete;
- F.R. Tupã;
- Tupã Basquete;
- variações históricas como Indians Tupã Basquete.

Esses nomes são tratados como identidades externas e podem apontar para o mesmo contexto interno quando aplicável.

## Regra importante

O ARCO **não deve inventar um número de registro da CBB ou FPB**.

O campo de registro oficial permanece nulo/não verificado até existir uma fonte oficial que forneça esse identificador.

Participação pública em competição da FPB pode ser usada para reconhecer nomes e jogos, mas não substitui uma integração oficial de cadastro.

## Implementação

- `GoverningBody.cbb`: Confederação Brasileira de Basketball;
- `GoverningBody.fpb`: Federação Paulista de Basketball, vinculada à CBB no modelo;
- `FederativeLink`: ligação da organização/equipe ao sistema federativo;
- `ExternalTeamIdentity`: nomes oficiais vistos em cada fonte;
- `TeamContext`: mantém o ID interno do ARCO e usa os nomes externos apenas para correspondência.

## Próxima evolução

1. obter IDs oficiais de clube/equipe quando disponíveis;
2. separar identidades por categoria/naipe quando necessário;
3. mapear atleta ARCO ↔ registro federativo;
4. adicionar competições nacionais CBB quando houver fonte pública/licenciada adequada;
5. substituir correspondência textual por IDs oficiais sempre que possível.
