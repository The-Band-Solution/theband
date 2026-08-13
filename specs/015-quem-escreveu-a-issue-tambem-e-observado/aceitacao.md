# Aceitação — feature 015, quem escreveu a issue também é observado

**Avaliada em**: 2026-08-13 · **Branch**: `020-clicar-leva-a-pagina`
**Método**: critério a critério, com a evidência ao lado.

## Requisitos funcionais — 13 de 13

| # | Requisito | Veredito | Evidência |
|---|---|---|---|
| FR-001 | pedir o identificador à origem | **aceito** | `issues.graphql` — `author { __typename login ... on User { id name } }` |
| FR-002 | registrar em `eo_people` pelo mapeamento existente | **aceito** | `autor_observado_test.exs` — "o autor que não é membro passa a existir" |
| FR-003 | identidade é o `id`, nunca o login | **aceito** | a asserção é sobre `external_id`, não sobre a existência |
| FR-004 | conta que não é de usuário não vira pessoa | **aceito** | o caso do `Bot`, com contagem inalterada |
| FR-005 | proveniência de onde veio | **aceito** | `RawData.store/1` com `github.user` e o `mapping_id` |
| FR-006 | contagem de membros não muda | **aceito** | "ninguém entra em equipe por ter escrito issue" |
| FR-007 | nenhuma evidência de equipe criada | **aceito** | idem |
| FR-008 | organização derivada do trabalho, dita como derivada | **aceito** | `trabalhou_nao_e_membro_test.exs` — o texto da evidência, e a ausência da afirmação de pertencimento |
| FR-009 | idempotente | **aceito** | duas coletas, mesma pessoa, `collected_at` intacto |
| FR-010 | login que a origem não resolve continua sem pessoa | **aceito** | o caso da conta apagada, sem `id` |
| FR-011 | nenhuma pessoa apagada | **aceito** | nada no caminho apaga; as 4 ausentes seguem |
| FR-012 | resolvível **na mesma execução**, inclusive em repositório coletado depois | **aceito** | o caso de dois repositórios — é o achado A1 da análise |
| FR-013 | designado grava `person_id` pela mesma regra | **aceito** | "o designado também" |

## Critérios de sucesso — 2 aceitos, 5 pendentes de coleta

| # | Critério | Veredito | O que falta |
|---|---|---|---|
| SC-001 | as 288 aparições caem | **pendente** | exige coleta com a origem respondendo |
| SC-002 | a contagem de pessoas cresce só por contas de usuário | **aceito em teste** | o número real muda na coleta |
| SC-003 | membros continuam 75 | **aceito em teste**, pendente no dado real | a asserção do que **não** muda |
| SC-004 | cada pessoa criada tem `external_id` | **aceito** | asserido diretamente |
| SC-005 | segunda coleta cria zero | **aceito** | teste de idempotência |
| SC-005b | pessoa do primeiro repositório resolvida no segundo | **aceito** | o caso de dois repositórios |
| SC-006 | a página mostra organização e evidência | **aceito** | o teste de tela; os números reais de `sofialctv` pendem da coleta |
| SC-007 | nenhuma pessoa some | **aceito** | nada apaga |

## Por que cinco continuam pendentes

**Dependem de uma coleta com a origem respondendo**, e portanto da chave mestra — que é da pessoa
mantenedora e não entra no chat. O mecanismo está aserido com a borda HTTP simulada; **os números
reais só mudam quando a coleta rodar**.

Contá-los como cumpridos seria afirmar o que não foi observado — o defeito que estas duas features
existem para corrigir, aplicado ao processo.

## O que a implementação achou, e a spec não previa

| # | Achado | Onde ficou |
|---|---|---|
| 1 | `platform_access_level` só aceita `MAINTAINER` e `MEMBER` | a fixture do teste, corrigida |
| 2 | a evidência de equipe é identificada pelo par **externo** pessoa/equipe, não pelos ids internos | idem |
| 3 | `repositories_of_person/2` devolve `observed_repository_id`, não `repo` | a composição na tela |

## Veredito

**Aceita quanto ao que pode ser verificado sem a origem.** Treze requisitos funcionais com
evidência; três critérios de sucesso aceitos e **cinco declarados pendentes** até a coleta.
