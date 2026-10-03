# O protótipo do pedido de troca da credencial (064, T018)

[`credential-age.html`](credential-age.html) — abrir no navegador. Quatro telas, separadas pelas
faixas `screen N · nome` (Connected tools, AI provider, telefone a 360 px, quem não administra),
e a seção final `Decisions and open questions`. Tudo visível ao carregar; o único controle é
*View in greyscale*.

Desenhado em **2026-10-03** pelo agente Design, tarefa T018 ([#883](https://github.com/The-Band-Solution/theband/issues/883))
de [`../tasks.md`](../tasks.md). Publicado em **<https://claude.ai/artifact/S5ZD8j7dsaDSH4QZsfYJUP>**;
**a cópia aqui é a que vale** — o endereço pode mudar, a spec não pode depender dele.

**Estado: versão 1, para aprovação.** D1–D9 propostas; Q1–Q4 abertas. Nenhuma data de aprovação
ainda: T018 continua bloqueada pelo protótipo até a pessoa mantenedora aprovar.

A estrutura seção a seção — **a régua do QA** — está na seção 3 do [`PROMPT.md`](PROMPT.md).

## O dado que a tela mostra

**Todo de exemplo**, marcado `example` na página: organizações observadas `example-org` e
`acme-labs`; rótulos `service account`, `read-only backup`, `new service account`, `main
credential`; dono `example-bot`; últimos quatro caracteres inventados; modelo `gpt-example-mini`.
"Hoje" é 2026-10-03. Nenhuma consulta ao banco (o pedido proibia rodar `mix`). A regra de três
meses de calendário é real: `TheBand.Credenciais.Idade.limite_em_meses/0`.

## As premissas que o protótipo herda (já decididas)

| de onde | o que fixa na tela |
|---|---|
| FR-016 | pedir, e não impedir: nenhuma ação desabilitada, coleta e geração seguem |
| FR-017 | o pedido diz **há quanto tempo**, e fica onde a credencial é administrada (`/tools`, `/ai`) |
| FR-018, T019 | depois da troca a contagem volta; a data anterior fica (`previous_secret_set_at`) |
| FR-019, SC-010 | sem data é `age unknown`, nunca dentro do prazo |
| `contracts/idade-da-credencial.md` | três estados, sem booleano, sem "dias restantes"; a data da chave antiga é inferida de `validated_at` e não preenchida pela migração |
| `seguranca-idade-da-credencial.md`, achados 3 e 4 | a `API_KEY` do ambiente é `age unknown`; o `case` enumera os três átomos, sem `_ ->` |
| router, 2026-08-28 | `/tools` e `/ai` são operacionais: administrador ou concessão organization; `/tools` recortado pelas organizações concedidas, `/ai` inteiro |
| `tool_credentials.validated_at` `NOT NULL` | a idade desconhecida não acontece hoje em credencial de ferramenta; desenhada (1d) porque o estado existe |

## As decisões de desenho — *propostas em 2026-10-03*, para aprovação

| # | decisão | a razão |
|---|---|---|
| **D1** | Data sempre, mais o intervalo: dias abaixo de um mês, meses de calendário inteiros (para baixo) a partir de um; no prazo, também a data em que o pedido começa | FR-017: "registrada há 4 meses" é acionável; a data liga o número ao registro |
| **D2** | Três marcas, três formas: `within 3 months` contorno fino; `replace · N months in use` borda dupla âmbar com "!"; `age unknown` tracejada e itálica | WCAG 1.4.1; "no prazo" não é sucesso a comemorar |
| **D3** | O pedido é um aviso no lugar da administração: em `/tools` sob "Credentials", um por credencial ativa vencida, pelo rótulo; em `/ai` dentro de "Key in use". Diz tempo, data, regra, que nada para, como trocar (inclusive revogar na origem) e quem pode. Nenhuma parte do segredo | FR-017, obrigação da avaliação de segurança |
| **D4** | Nenhuma ação nova, nada desabilitado, sem adiar/dispensar | FR-016; o pedido some quando a credencial é trocada ou desativada |
| **D5** | Em ferramenta, logo depois de adicionar o token novo o antigo segue ativo e vencido; o pedido muda para "deactivate or remove the old one" | a troca em `/tools` é linha nova, não reescrita |
| **D6** | Na chave do modelo, o flash diz que data foi substituída; "Key in use" ganha "previous key" com as duas datas | FR-018: a data anterior não se perde |
| **D7** | Data inferida (chave anterior à T019) leva a marca hachurada `inferred from the last check` | derivado, não registrado; o contrato deixou sem preencher para isso aparecer |
| **D8** | `API_KEY` do ambiente: `age unknown`, a ausência dita como da plataforma, dentro do aviso de ambiente que já existe | achado 3 |
| **D9** | Em `/tools`, a coluna `validated at` vira `registered` com data e marca; em `/ai`, `checked against the provider at` fica e `key registered` entra | na ferramenta os dois instantes coincidem; no modelo, não |

## As perguntas abertas — para o Product Owner levar

| # | pergunta | opções | recomendação |
|---|---|---|---|
| **Q1** | Credencial de ferramenta **inativa** com mais de três meses? | (a) o mesmo pedido; (b) sem pedido, a linha com data e marca, e uma linha discreta pedindo para **remover** se não serve mais; (c) só a data e a marca | **(b)** — o segredo continua em repouso (é do que a 064 trata), mas "trocar" é a ação errada para o que ninguém usa |
| **Q2** | `age unknown` pede alguma coisa? | (a) só a marca; (b) marca mais aviso tracejado com o caminho para uma data conhecida (trocar; para a do ambiente, quem opera o servidor ou gravar uma da organização) — desenhado em 1d e 2d | **(b)** — FR-019 proíbe contá-la como no prazo; a marca sozinha não diz o que fazer, e a do ambiente é a de maior alcance |
| **Q3** | Marca além da tela que administra? | (a) só nela, como a FR-017; (b) também na aba Connected tools / AI provider — desenhado em 2a e no telefone; (c) (b) mais navegação principal ou e-mail, escopo novo | **(b)** — um assign por tela; a SC-009 só se cumpre por inteiro com (c), que vai ao backlog como spec própria |
| **Q4** | Regravar a **mesma** chave: dizer? | (a) o flash diz que é a mesma e que conta desde a data antiga (2f), comparando `secret_set_at` antes e depois; (b) o flash de sempre | **(a)**, com o aval do agente `security` — sem isso quem só trocou o modelo lê "saved" e acha o pedido atendido; o achado 5 diz que a igualdade não dá nada a quem já pode sobrescrever, e as datas do cartão já a revelam |

## Medidas novas

Nenhuma. A idade não é medida da base de conhecimento: é metadado de credencial, classificado
por `TheBand.Credenciais.Idade` (regra de segurança, sem ontologia).

## O que o protótipo descobriu e a implementação precisa saber

- **Defeito no domínio já implementado (T019)**: uma chave do modelo **anterior** à migração
  (`secret_set_at` nulo) regravada com **a mesma chave** — para trocar o modelo — passa por
  `data_da_troca/3` sem mudança (`%{}`), mas `put/3` grava `validated_at: agora`. Como
  `em_uso_desde/1` cai em `validated_at` quando `secret_set_at` é nulo, **a idade zera sem troca
  nenhuma** — o exato caso que a FR-018 e o contrato descrevem. A tela 2c mostraria "today" para
  uma chave de meses. Conserto provável: no ramo "mesma chave" com `secret_set_at` nulo, gravar
  `secret_set_at` com o `validated_at` anterior. Precisa de teste com o defeito injetado, e é
  anterior à T018.
- **`/tools` não tem histórico da data depois de "remove"**: a linha removida leva a data junto
  com o segredo. A data da troca continua na linha nova (FR-018 atendida), mas "desde quando valia
  o anterior" some. Registrado na nota de 1c; não pede coluna nova enquanto ninguém precisar.
- **Dois textos em português nas telas atuais**, fora do escopo da T018 e mostrados como estão:
  o título `Ferramentas conectadas` de `/tools` e o flash do redirecionamento de
  `:require_operacao`. A interface fala inglês (§11.1); vale issue própria.
- **O "quem pode trocar" em `/tools` depende do recorte**: a frase cita a organização observada
  (`someone who answers for example-org`), que a tela já tem em `tool.organization_login`.
- **Data em `/ai` hoje é o timestamp cru** (`2026-09-15 10:41:07Z`); o protótipo mantém assim em
  `checked against the provider at` e usa só a data em `key registered`.
