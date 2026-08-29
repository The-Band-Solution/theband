# Research — 051 Contas: cadastrar pessoas e associar o GitHub

Medições de 2026-08-29, na main pós-sprint 024.

## R1 — O terreno: quase tudo existe, e a feature é recomposição

**Medido**:

- `Tenants.create_user/2` é insert puro — a conta nasce SEM senha; a temporária vem
  de `Tenants.reset_password/3` (ato separado, mostrado uma vez na tela). O
  onboarding real hoje são DOIS cliques em `/accounts` + UMA visita à página da
  pessoa.
- `Tenants.declare_person/4` e `revoke_person/3` já são transacionais, auditados
  (quem declarou/revogou, quando), e devolvem `{:error, :taken}` quando a pessoa já
  tem elo vigente — imposto por índice único parcial no banco
  (`users_pessoa_observada_vigente_index`), não só por leitura.
- `EO.list_people/2` já busca por `ilike` em nome e login, com paginação.
- `accounts_live/index.ex` tem 161 linhas — a tela é pequena e cabe crescer sem
  ferir o princípio X (a coisa dela é contas, e o elo é atributo de conta).

**Decisão**: nenhuma entidade nova, nenhuma migração. A feature compõe o que existe.

## R2 — O cadastro emite a temporária no ato

**Decisão**: nasce `Tenants.cadastrar_conta/3` (tenant, attrs, actor) — cria a conta
E emite a temporária numa transação, devolvendo `{:ok, {user, temporaria}}`. A tela
mostra a temporária uma vez, como o reset já faz.

**Rationale**: o cenário 1 da US1 promete a temporária no cadastro; hoje ela exige o
segundo clique (reset). Compor na tela (criar + reset em sequência) deixaria a falha
do segundo ato criar conta sem senha em silêncio — transação no domínio é o
tudo-ou-nada que a spec exige (FR-003 análogo). `create_user/2` PERMANECE (seeds e
testes o usam); o contrato novo documenta os dois.

## R3 — O conflito nomeia a dona via leitura estreita

**Decisão**: nasce `Tenants.user_of_person/2` — a conta com elo VIGENTE para uma
pessoa, ou nil. A tela usa no caminho do `{:error, :taken}` para nomear a conta que
já tem a pessoa (cenário 3 da US2). `declare_person/4` NÃO muda: o `:taken` continua
vindo do banco (corrida segura), e a leitura só roda no caminho do conflito — zero
custo no caminho feliz.

**Alternativa rejeitada**: enriquecer o erro de `declare_person` com a struct da
dona — mudaria contrato vigente de função usada em outra tela, para servir uma
mensagem; a leitura estreita no chamador custa o mesmo e não mexe em contrato alheio.

## R4 — A lista diz quem tem GitHub, numa consulta

**Decisão**: a lista de contas carrega o elo vigente com a pessoa (login observado)
em UMA consulta com join — nunca uma consulta por linha (L38). Quem não tem elo
mostra ausência nomeada ("no GitHub account linked"), nunca célula vazia (FR-003).

**Medido**: `list_users/1` existente devolve as contas; o join com `eo_people` pelo
`person_id` vigente é a mesma forma que a página da pessoa já usa na direção oposta.

## R5 — A associação busca entre as coletadas, com o custo declarado

**Decisão**: o formulário de associação busca via `EO.list_people(tenant, q: texto,
limit: 8)` — a consulta roda no evento de busca (por digitação com debounce da casa),
nunca no mount. Resultado mostra nome, login e organização (edge case dos homônimos);
0 resultados é ausência nomeada.

## R6 — Mensagens novas nascem no catálogo

**Decisão**: toda frase nova desta feature nasce em `dgettext` (errors/sistema) — o
gate da 047 já reprova literal em `put_flash`, e as frases de tela novas entram no
catálogo por padrão para não crescer o `pendencias.md`.
