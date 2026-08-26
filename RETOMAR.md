# Retomar

**Última sessão**: 2026-08-26, madrugada.

## O que ficou pronto

**Feature 042 — critério de início — está no `main`** (`ef46d9c`, PR #510). As 24 tarefas,
as 24 issues encerradas, e a **#370 fechou junto** — a decisão que estava aberta desde a
`FR-007` da feature 022 e travava `flow.throughput`, `flow.wip.count` e o cycle time por
pessoa.

O percurso do quickstart foi feito **na tela**, com navegador, contra o banco de
desenvolvimento: `specs/042-criterio-de-inicio/percurso-t024.md`. Cinco divergências
apareceram, quatro corrigidas ali mesmo.

**Feature 043 — papéis por organização** — já estava no `main` e as dezoito issues
continuavam abertas. Fechadas, com o commit que as entregou citado em cada uma.

## O que pode estar esperando quando tu voltar

Dois PRs pequenos, armados para mergear sozinhos quando o CI ficar verde:

| PR | o que é |
|---|---|
| [#511](https://github.com/The-Band-Solution/theband/pull/511) | marcar as dezesseis tarefas da 043 no `tasks.md` |
| [#512](https://github.com/The-Band-Solution/theband/pull/512) | #509 — o nome de projeto removido volta a ficar disponível |

**Conferir se mergearam.** Se algum reprovou, o motivo está nos checks.

## Pedido para amanhã: a documentação e o site

**Já achei uma divergência concreta**, e ela dá o tom do resto do trabalho.

O site (`origin/gh-pages:index.html`) diz:

> uma rede de ontologias de referência com **222 conceitos**

Os gates de hoje dizem:

> 116 arquivos YAML | **13 ontologias** | **231 conceitos** | **170 relações** | 5 medidas

Nove conceitos de diferença. A 042 entrou com `spo.activity_start_criterion` e a 043 mexeu
nos papéis; o número do site é de antes. Trocar `222` por `231` é uma linha — e é a parte
fácil.

**A parte que importa**: os outros números do site não foram conferidos.

| o que o site publica | conferido? |
|---|---|
| 222 conceitos | **não — são 231** |
| 5.216 issues coletadas | não |
| 160 repositórios | não |
| 46.435 promoções semânticas | não |
| 212 sprints reais | não |
| 21.365 commits | não |
| 2.024 sem check | conferido na recoleta de 2026-08-24 |

**Medir cada um contra a origem, e nunca contra a página.** Já custou caro duas vezes nesta
semana: a inversão do `statusCheckRollup` — que eu publiquei em quatro lugares antes de
medir — e a "correção" da L70, que afastou o número da verdade porque usei um total
parcialmente medido como denominador.

A ordem que funciona: rodar `mix gates` para os números da base de conhecimento, consultar
o banco para os de coleta, e só então mexer no HTML. Um número que não vier de uma consulta
nesta sessão não entra.

Além do site, o que a 042 e a 043 mudaram e a documentação ainda não diz:

- `docs/ontology/` — o conceito novo e as relações dele;
- o `README.md` da raiz, se ele carrega contagem;
- as medidas de fluxo que **deixaram de estar travadas**: `flow.throughput`,
  `flow.wip.count` e o cycle time por pessoa agora têm de onde partir, e a documentação
  ainda as descreve como bloqueadas pela `FR-007` da feature 022.

## O próximo passo

**#505 — o período de participação, e a interseção pessoa → equipe → projeto.**

É o que tu pediste com estas palavras: *"Uma pessoa fica na equipe e no projeto por um
período de tempo — precisamos colocar isso."*

Não depende de decisão tua, e é modelagem e não tela. Pode começar direto pelo ciclo do
Spec Kit.

Depois dele, **#508** — atividade por pessoa por mês. **Aviso que precisa estar na tela**:
não é throughput, e um bot fica em segundo lugar no ranking. Medir atividade e chamar de
produtividade é o erro que a medida convida.

## O que espera por ti, e por que eu não faço

**#506 — as perguntas que o painel da equipe responde.** Sem elas eu construiria o painel
adivinhando o que ele deve dizer, que é o defeito que a própria #506 existe para evitar.

E **#507** e **#504** dependem da #506.

Outras decisões abertas: #368, #369, #452, as três perguntas restantes da #367, e a #442
(ArgoCD, que tu excluiu de propósito).

## Solto, quando der

- **#501** — o guarda de 100 ms do `PatternValidator` está a 5 ms do que o PCRE já faz
  sozinho pelo `match_limit`. O teste reprova no `main` também.
- **#176** — decidida (opção b), ainda aberta. Fechar com o achado de que 21 sprints ocupam
  duas caixas de sete dias.
- **A análise semântica do Tech Lead** — mais a medida que separa quem delega de quem
  refina tecnicamente, cruzando os 2.051 comentários de issue com a autoria delas.

## Uma coisa que reincidiu, e agora está anotada

`git checkout -- <arquivo>` para desfazer injeção de defeito **destruiu trabalho não
commitado duas vezes**. Na segunda levou um `type(min(...), :utc_datetime)` que consertava
um `@type` mentiroso — e a suíte voltou a passar, porque o defeito só aparecia na tela.

O jeito certo é `cp` antes e `cp` depois.
