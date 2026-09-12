# Rotacionar o token do GitHub que esteve legível no banco

**Aberto em**: 2026-09-12

**Severidade**: alta

**Quem executa**: a pessoa mantenedora, no GitHub. Nenhum código faz isto.

**Relacionado**: [spec 064](../../specs/064-segredo-em-repouso/spec.md) · [MinIO como destino do ensaio](minio-como-destino-do-ensaio-de-backup.md) · [backup restaurado de verdade](backup-restaurado-de-verdade.md)

## O que aconteceu

Um token de acesso do GitHub — o registrado com rótulo `teste`, terminado em `omAX` — ficou
gravado em **texto claro** dentro do registro de erro de um job, de 2026-09-04 a 2026-09-12.
Oito dias legível para qualquer pessoa com leitura no banco.

Medido, sem imprimir o valor: corrida de 40 caracteres logo após
`graphql("https://github.com", "`, com os quatro últimos casando com o `last_four` da
credencial guardada.

## Por que rotacionar, já que a linha foi limpa

A linha foi redigida em 2026-09-12 — o valor saiu, e o registro do erro continua lá para
investigação. **Isso não basta.**

Limpar o banco alcança o banco. Não alcança:

- qualquer `pg_dump` tirado entre 09-04 e 09-12;
- qualquer cópia desse dump;
- qualquer terminal, log de shell ou histórico onde o conteúdo tenha passado.

O que passa não se desfaz. **Só a rotação invalida o valor exposto.** Enquanto o token não for
rotacionado, o risco permanece aberto, e apagar a linha pode até piorar: dá a sensação de
resolvido.

## Como fazer

1. No GitHub, revogar o token terminado em `omAX`.
2. Gerar um novo, com os mesmos escopos.
3. Registrar o novo **pela interface da plataforma** — nunca por chat, nunca por variável de
   ambiente, nunca colado em arquivo.
4. Anotar aqui a data da rotação.

## Estado

- [x] Ocorrência encontrada e medida — 2026-09-12
- [x] Linha `oban_jobs` #697 redigida, registro do erro preservado — 2026-09-12
- [x] Banco varrido inteiro (259 colunas), zero ocorrências restantes — 2026-09-12
- [x] Varredura provada com caso positivo plantado (achou, e o plantio foi desfeito) — 2026-09-12
- [ ] **Token rotacionado no GitHub** — pendente, é o item que fecha isto
- [ ] Mecanismo corrigido para não vazar de novo — FR-006 da spec 064

## O que ainda vaza, se nada mudar no código

A redação tratou a ocorrência, não a causa. O token é argumento nu de `Client.graphql/5`:
qualquer exceção naquela chamada leva a lista de argumentos para o quadro de pilha, e o
executor de tarefas grava o texto. **Vai acontecer de novo na próxima falha.**

A FR-006 da spec 064 exige que a proibição venha do **tipo** do dado, e não da disciplina de
quem escreve. Até lá, esta varredura precisa ser repetida antes de cada cópia nova.
