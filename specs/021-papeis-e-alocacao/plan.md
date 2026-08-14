# Implementation Plan: os papéis, e quem os desempenha

**Branch**: `044-papeis-e-alocacao` · **Data**: 2026-08-14
**Spec**: [spec.md](./spec.md) · **Pesquisa**: [research.md](./research.md)

## Summary

101 evidências de participação, zero vínculos, zero papéis — e os três números são o mesmo
fato: `eo_team_memberships.organizational_role_id` é `NOT NULL`.

O modelo inteiro já existe e está vazio. A feature entrega o cadastro, a alocação e as telas, e
o desenho gira em torno de **uma distinção que já está no banco e nunca teve consumidor**:
evidência é o que a origem mostrou; vínculo é o que alguém afirmou.

## Technical Context

**Linguagem**: Elixir 1.20 · OTP 27 · Phoenix LiveView
**Armazenamento**: PostgreSQL 16 — duas tabelas existentes e vazias, uma coluna a acrescentar
**Testes**: ExUnit; nenhum módulo de domínio mockado
**Escala hoje**: 88 pessoas · 101 evidências · 3 organizações · equipes derivadas incluídas

**Restrições**:
- a coleta **não pode** apagar nem encerrar vínculo declarado;
- nenhuma tela pode apresentar nível de acesso da origem como papel;
- a plataforma não cadastra papel sozinha.

**Nenhum NEEDS CLARIFICATION.** As três perguntas que a spec poderia ter deixado abertas — a
multiplicidade, o destino do vínculo quando a evidência acaba, e se a plataforma cadastra os
papéis do Scrum — foram decididas com fundamento, e estão em [research.md](./research.md).

## Constitution Check

| Princípio | Como esta feature se comporta |
|---|---|
| **I — domínio pelas ontologias** | `eo.organizational_role` e o vínculo saem direto da EO; os quatro papéis sugeridos vêm da SRO |
| **II — fonte externa não é domínio** | o papel **não vem de origem alguma** — é declaração, e a feature existe porque nenhuma ferramenta o fornece |
| **III — proveniência e idempotência** | evidência mantém a proveniência que já tem; o vínculo ganha **autor**, que é a proveniência de uma declaração |
| **IV — semântica em YAML versionado** | a lista sugerida é lida da base de conhecimento, não escrita em código |
| **V — monólito modular** | tudo dentro de `EO`; nenhuma fronteira nova |
| **VI — Spec Kit antes do código** | spec, pesquisa e plano antes da primeira linha, e a análise achou dois defeitos |
| **VII — gates e revisão** | treze gates; e a SC-006 vira teste que afirma a **ausência** de uma frase na tela |
| **VIII — desenho que o problema justifica** | ver abaixo |
| **IX — ontologias modulares** | a SRO é lida pela API pública da base de conhecimento, não por caminho de arquivo |
| **X — responsabilidade única** | tela de papéis separada da tela de alocação: cadastrar o catálogo e alocar uma pessoa são coisas diferentes |

### Princípio VIII — as três perguntas, por decisão introduzida

| Decisão | Qual problema concreto? | Existe agora? | O que fica pior? |
|---|---|---|---|
| **schema `TeamMembership`** | a tabela existe e não tem módulo; sem ele não há como gravar vínculo | **sim** — 101 evidências travadas | mais um schema para quem lê o módulo EO percorrer |
| **coluna `declared_by_user_id`** | declaração sem autor é indistinguível de observação | **sim** — é a FR-011, e a US3 inteira depende dela | uma coluna, e uma migração |
| **índice parcial `ended_at IS NULL`** | a mesma pessoa alocada duas vezes ao mesmo papel ao mesmo tempo | **sim**, e é a única duplicata sem sentido | índice parcial é menos óbvio que único simples — e o único simples proibiria o histórico |
| **tela de papéis separada da de alocação** | cadastrar catálogo e alocar pessoa são decisões diferentes, com público diferente | **sim** — princípio X | uma rota a mais |

**Nenhum padrão novo.** Sem behaviour, sem camada, sem indireção. O que entra é um schema para
uma tabela que já existe, uma coluna de autoria e duas telas.

**Nenhuma preparação para o que não foi pedido**: hierarquia de papéis e alocação em projeto
estão fora do escopo da spec, e nada neste plano as antecipa.

### Os antipadrões que este plano evita, e como

**Booleano no lugar do relator.** A alternativa recusada em R2 era uma coluna `origem` com
`observado`/`declarado` na mesma tabela. Evidência e vínculo têm campos diferentes — juntá-los
deixaria metade das colunas nulas em metade das linhas, e a distinção viraria um valor de texto
em vez de estrutura.

**A coleta apagando o que não produziu.** `mark_evidence_no_longer_observed/3` **não** toca no
vínculo. Encerrá-lo automaticamente seria a plataforma afirmando que a pessoa deixou o papel, e
o que ela sabe é que a origem parou de mostrar a participação.

**Estado como string livre.** O nível de acesso da origem já é texto, e continua sendo — mas ele
**não** vira papel. O papel é registro com código único por tenant.

## Fases

### Fase 1 — o catálogo *(US1, P1)*

Schema já existe; faltam comandos e tela. Cadastrar, renomear preservando o código, e recusar
remover papel em uso dizendo quantos vínculos apontam para ele.

A tela sugere os quatro da SRO, lidos da base de conhecimento, e **não cadastra nenhum**.

### Fase 2 — o vínculo *(US2, P1)*

Schema `TeamMembership`, migração da coluna de autor, índice parcial de vigência, e os comandos
de alocar e encerrar. A evidência passa a apontar para o vínculo criado.

**Encerrar grava `ended_at`, e nunca apaga.**

### Fase 3 — a tela que distingue *(US3, P1)*

`PeopleLive.Show` passa a mostrar as duas coisas separadas, cada uma com a origem visível. É a
fase que dá consumidor às duas anteriores — sem ela, o vínculo existe e ninguém vê.

**As três fases são P1 e vão no mesmo sprint.** Catálogo sem alocação não promove nada; alocação
sem tela é dado que ninguém alcança. É a **L21**.

## Artefatos gerados

| Arquivo | O que traz |
|---|---|
| [research.md](./research.md) | as cinco decisões, e o que já existia |
| [data-model.md](./data-model.md) | o que entra, o que muda de significado, e os invariantes |
| [contracts/papeis-e-alocacao.md](./contracts/papeis-e-alocacao.md) | as assinaturas, antes da implementação |
| [quickstart.md](./quickstart.md) | como provar, incluindo a prova de que a coleta não apaga |

## Constitution Check — reavaliação depois do desenho

**Nenhuma violação.** Duas observações:

**A US3 deixou de ser tela e virou o teto da feature.** Ela é o que impede a distinção de sumir
— e sem ela as fases 1 e 2 entregariam um papel que a tela apresentaria como se fosse observado.

**A prova mais importante desta feature é uma ausência.** A SC-006 diz que nenhuma tela
apresenta nível de acesso como papel, e a SC-003 diz que nenhuma evidência é apagada. As duas se
verificam por `refute`, e é onde uma feature de cadastro costuma escorregar sem que ninguém veja.
