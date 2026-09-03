# Sprint 024 — Review

**Período**: 2026-08-28 a 2026-08-29 (dois dias)
**Features**: [047-mensagens-internacionalizadas](../../../specs/047-mensagens-internacionalizadas/spec.md) e
[048-botao-sem-chave-desabilitado](../../../specs/048-botao-sem-chave-desabilitado/spec.md)
**PRs**: [#593](https://github.com/The-Band-Solution/theband/pull/593) (047, squash) e
[#594](https://github.com/The-Band-Solution/theband/pull/594) (048, squash) — CI 2/2 verde
nos dois; revisão adversarial no #594 sem achado real.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 4 | 4 |
| Tarefas | 16 | 16 |
| Entregáveis aceitos | 4 | **2** (#575, #587) |

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| 047/T001–T004 | [#576](https://github.com/The-Band-Solution/theband/issues/576)–[#579](https://github.com/The-Band-Solution/theband/issues/579) | Catálogo configurado (en runtime via `:gettext`), verificador por AST nascido pela violação, gate novo — que nasceu vermelho com 137 achados | ver Aceitação |
| 047/T005–T007 | [#580](https://github.com/The-Band-Solution/theband/issues/580)–[#582](https://github.com/The-Band-Solution/theband/issues/582) | 139 mensagens migradas sem mudar um byte (97 errors + 40 sistema + 2 default); suíte 1447 verde SEM editar teste; recusa única da 045 intacta | ver Aceitação |
| 047/T008–T011 | [#583](https://github.com/The-Band-Solution/theband/issues/583)–[#586](https://github.com/The-Band-Solution/theband/issues/586) | pendencias.md medido por tela; `mensagens.lacunas` (en 0, pt 128); 11 recusas em pt com a troca provada por teste; 14 gates verdes | ver Aceitação |
| 048/T001–T005 | [#588](https://github.com/The-Band-Solution/theband/issues/588)–[#592](https://github.com/The-Band-Solution/theband/issues/592) | Guarda `:sem_chave` em `request/3` pela violação; botões `disabled` reais com frase por quem lê; assimetria ambiente/tenant dita na tela; 27ª consulta nomeada no guardião; 14 gates verdes | ver Aceitação |

**Aceitação** ([registro completo](aceitacao.md)): product-owner em 2026-08-29, 13
evidências executadas, confirmada pela pessoa mantenedora (leitura estrita; revisão
pós-merge). **2/4 aceitas**: #575 (idioma) e #587 (botão da chave), ambas com
ressalvas. **#573 e #574 NÃO ACEITAS** — contraexemplo real: mensagens em literal
via assign renderizado (`access_scopes_live`, `projects_live`, `humanizar/1`),
classe invisível ao verificador (que vigia `put_flash`) E ao `pendencias.md` (que
contava notices). O retrabalho é finito (~9 frases + ampliar a fronteira por AST) e
entra em primeiro lugar no sprint 025 — herança antes de escopo novo.

## O que não foi feito / não aceito

As 16 tarefas foram executadas e as issues fechadas à mão (PRs no padrão 1.6.0 não
fecham sozinhos) — mas **as US1 e US2 da 047 voltaram**: entregável executado cujo
resultado não atendeu ao critério não é entregue (a classe assign ficou fora do
catálogo e da enumeração). Destino: primeiras tarefas do sprint 025.

**Violações de processo** (registro em [aceitacao.md](aceitacao.md)): revisão nunca
pedida nos dois PRs (decisão: revisão pós-merge, pedida por comentário); PRs fora do
board; issues fechadas antes da aceitação.

## Defeitos encontrados e consertados no caminho

- **O grep do plano subcontava**: 55 literais viraram **137** quando o verificador por
  AST mediu — multilinha, concatenação e forma pipe eram invisíveis ao grep. Corrigido
  no tasks.md com a razão; virou o argumento definitivo do verificador por AST.
- **A forma qualificada escapou**: `Phoenix.Controller.put_flash` tem outra cabeça de
  AST e o verificador v1 não a via — a recusa do PLUG ficou de fora da primeira
  varredura. Quem pegou foi o teste de idioma (a frase não trocava). Verificador
  corrigido com teste próprio da forma qualificada.
- **`default_locale` do backend é compile-time**: o contrato previa a config no
  backend; o teste de idioma reprovou e a medição mostrou que só a config do app
  `:gettext` é lida em runtime. Contrato corrigido no mesmo commit, com a razão.
- **`rodada_test` clicava no botão que a 048 desabilitou**: o teste mudou de veículo
  (evento injetado por fora do botão) com o invariante intacto — L71 aplicada.

## Evidências

- Gates locais 14/14 com EXIT no log (L60) nas duas branches; CI verde 2/2 nos dois
  PRs; revisão adversarial postada no #594 (seis frentes, nenhum achado real).
- Suíte completa 1447 verde após a migração das 139 mensagens **sem tocar em teste
  algum** — a prova de que o msgid preservou cada byte.
- `login_test.exs` sem diff no sprint inteiro (SC-004 da 047).
- Captura da geração mensal com credencial (botões vivos, frase ausente — cenário 3
  da 048); os estados desabilitados provados por 5 testes de tela.

## Dívida gerada

- O verificador v1 não vê HEEx — fronteira declarada no contrato, com o backlog
  nomeado em `pendencias.md` (15 notices na página da pessoa, 8 no work item, …).
- pt tem 128 lacunas enumeradas — visíveis pelo relatório, preenchíveis por PR de
  tradução sem tocar código.
- A frase da lacuna da 048 usa `@operacao_menu` como aproximação de "quem opera" —
  se a gestão de marca de admin (#568) mudar a semântica, a frase acompanha.

## Lições deste sprint

No [registro acumulado](../licoes-aprendidas.md): **L76** (a ferramenta de medir
precisa da gramática do alvo — grep 55 vs AST 137), **L77** (verificador novo nasce
com teste de ponta que NÃO passa por ele — foi o teste de idioma que pegou a forma
qualificada), **L78** (config prometida como "troca em runtime" se prova com teste em
runtime antes de entrar no contrato), **L79** (agente com árvore compartilhada não
troca de branch — o PO deixou a árvore na main e os arquivos "sumiram"), **L80** (a
pendência medida com o grep do instrumento herda a cegueira dele — foi por ela que
duas US voltaram), e **L72 refinada** (iteration completada mantém o id mas os
valores dos itens se perdem, irrecuperáveis pela API — o registro de pertença é o
backlog no repositório).

E o flake pós-sprint que o CI do #596 expôs — `put_env` de teste sem restauração
simétrica vazava a `API_KEY` e o veredito dependia do seed — foi consertado na raiz
no PR #607, com três seeds fixos como prova.
