# Sprint 021 — Review

**Período**: 2026-08-18 · **Feature**: 037 — coleta da verificação contínua
**Issue**: [#401](https://github.com/The-Band-Solution/theband/issues/401)
**PR**: [#435](https://github.com/The-Band-Solution/theband/pull/435)

> **Sprint aberto sem backlog.** A feature 037 saiu direto da conversa que fechou a #434, e
> a skill `sprint-backlog` exige o documento antes de implementar. Registrar isso aqui é o
> mínimo honesto: este review descreve o que ocorreu, e a ausência do backlog é dívida de
> processo, não omissão do documento.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| Coleta (execuções e jobs) | 1 | 1 |
| Telas | 3 | 3 |
| Testes novos | — | 27 |

## O que foi feito

| Entregável | Aceito |
|---|---|
| `TheBand.Verification.Classification` — subtipo, fase, componentes, tipo derivado | sim |
| `TheBand.Ingestion.GithubVerifications` — fase da mesma sincronização | sim |
| `TheBand.Verification` — leitura, com custo fixo provado em teste | sim |
| `/work/verifications` e `/work/verifications/:id` | sim |
| Seção "What the checks said" na página da mudança | sim |
| `GithubCommitFiles` finalmente ligada à sincronização | sim |

## O achado que reorientou a feature

Das 1.051 execuções coletadas do primeiro repositório:

| tipo derivado | execuções |
|---|---:|
| integração **e** implantação | 515 |
| **a rede não nomeia** | 399 |
| só implantação | 107 |
| só integração | 30 |

A primeira versão chamaria as 1.051 de integração contínua. As 399 são espelhamento
(`Sync to GitLab`) e automação de quadro (`Sprint Rollover`) — chamá-las de CI envenenaria
toda medida de verificação com execuções que nada verificam.

## As decisões de ontem, medidas

| fase | execuções |
|---|---:|
| bem-sucedida | 942 |
| malsucedida | 55 |
| **interrompida** (cancelada) | 54 |

Contar as 54 como falha levaria a taxa de quebra de **5,2% para 10,4%** — dobrada por
decisões humanas. A decisão da pessoa mantenedora se sustentou no dado.

## Os antipadrões, corrigidos pelo dado

| máxima | antes | depois |
|---|---:|---:|
| `ci.ap02.unnamed_components` | 751 disparos | **0** |
| `ci.ap01.monolithic_job` | 0 disparos | **502** |

O `ap02` disparava em `sync`, `deploy`, `rollover` — não são jobs mal escritos, são
execuções que não verificam nada. O `ap01` não via os 502 jobs `Deploy backoffice` que têm
`Build production bundle` e `Deploy to Vercel production` no mesmo job, porque contava só
processos da CIRO.

## Dois padrões saíram por inventarem

`artifact` casava com a etapa `Upload Pages artifact` de um job de build — **238 entregas
contínuas que não existem**. `package` casava com `Install npm packages`. Padrão largo demais
não coleta mais: inventa mais.

## Dívida gerada

- **A coleta não terminou.** 4 de 160 repositórios percorridos; 8.438 de 16.416 commits com
  arquivos. As duas competem pela mesma janela de 5.000 req/h e precisam rodar uma de cada vez.
- **Sprint sem backlog**, registrado acima.
- **`ciro.continuous_feedback_activity` não é roteada** — feedback no Actions é notificação,
  e a plataforma não coleta notificação. Limitação declarada, não resolvida.

## Evidências

- `mix gates` — 13 gates verdes
- coleta rodada contra dado real: 1.051 execuções, 1.530 jobs, 160 repositórios visitados
- capturas de `/work/verifications`, do detalhe e da seção na mudança, em desktop e 390px

## Lições deste sprint

- **L61** — uma limitação declarada no mapeamento não vira restrição no código sozinha
- **L62** — somar contadores por lista escrita à mão apaga a chave nova em silêncio
