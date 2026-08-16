# Retomar — feature 026, o perfil de competências

**Estado**: implementada e empurrada, **PR #330** com 4 commits, `MERGEABLE`, gates com
código de saída 0. Revisão pedida a `Adylla027` e `EduardoNFraiz`.
**Branch**: `056-perfil-de-competencias`

## O primeiro comando ao voltar

```bash
set -a && . ./.env && set +a      # a chave mestra e a API_KEY moram aqui
mix phx.server
```

Perfil real gravado no banco de desenvolvimento, gerado com a API de verdade:
<http://localhost:4000/people/fe70e4e6-b845-46e2-a18a-5394f15f9a6d>

---

## As duas coisas pedidas em 2026-08-16, e ainda não feitas

### 1. A página não recarrega quando a geração termina

**É defeito do que já foi entregue.** A tela diz *"Requested. The model takes about a
minute — reload to see it"* — a plataforma pedindo à pessoa que faça o trabalho dela. A
geração leva de 25 a 60 segundos, e quem clicou fica atualizando à mão.

O conserto é pequeno, e o projeto já tem o padrão: `TheBand.Ingestion` faz
`Phoenix.PubSub.subscribe/broadcast` num tópico por tenant, e `RecomputePromotions` também.

- `GenerateWorker` publica quando grava — e **também quando falha**, senão a tela fica
  esperando para sempre um evento que não vem;
- a aba assina no `mount`, e recarrega o perfil ao receber;
- o teste é o estado intermediário: pedir, mandar o evento, e afirmar que o perfil aparece
  **sem** um novo `live/2`.

Cuidado com o de sempre: o ramo de falha precisa publicar. Um `subscribe` que só recebe
sucesso transforma erro em espera infinita, e espera infinita é indistinguível de "ainda
rodando" — é a mesma família da lição do sucesso silencioso.

### 2. Geração automática e periódica — a feature 027

**Proposta medida em 2026-08-16, não escrita como spec.** A recomendação é **cron próprio,
não no sync**, e os números são a razão:

| medição | valor |
|---|---|
| pessoas que passam nos pisos | **34** de 41 |
| material mediano por pessoa | 191k chars ≈ **48k tokens** |
| rodada completa | **1,63M tokens** de entrada |
| fecharam 10+ tarefas nos últimos 30 dias | **6** |
| fecharam 1 a 9 | 14 |
| **fecharam nenhuma** | **14** |

Catorze das 34 não fecharam uma tarefa em 30 dias: o material é idêntico, e o texto novo
diria o mesmo. O sync roda muito mais que uma vez por mês, então atrelar ali multiplica
1,63M por coleta. E há a razão de conceito: **sync é coleta, perfil é interpretação** —
acoplar faz toda observação custar dinheiro.

**A regra proposta:**

```
regenera se  (tarefas_fechadas_hoje − tasks_closed_do_perfil) ≥ N
         ou  generated_at mais velho que M meses
```

O recorte já está em coluna exatamente para isso — foi a `FR-016`. Com N=10, hoje rodariam
**6 de 34**: ~290k tokens em vez de 1,63M. N e M em `profile.thresholds`, junto dos outros.

**De graça, o gate resolve outra coisa**: a tabela é somente-acréscimo, e sem regra de
mudança a geração automática a encheria de textos quase idênticos — o histórico, que existe
para comparar agosto com dezembro, viraria ruído.

**O que precisa ser decidido antes de escrever a spec**: hoje a geração é ato de alguém.
Automática, mais leitura aberta ao tenant (`FR-023`), mais sem contestação (`FR-024`),
significa que **ninguém decide** — o texto passa a existir sobre todo mundo por padrão. Não
é impeditivo, é decisão, e merece estar escrita como o resíduo das outras duas está.

---

## Dois achados soltos, que não viraram tarefa

- **48k tokens de material mediano**, o dobro do `AndreCoelhoS`. Quem tem 300 tarefas gera
  material grande demais — vale um teto por período, com o que ficou de fora declarado.
- **A `FR-024`** é o item que mais provavelmente volta como requisito, assim que alguém ler
  o próprio perfil.

---

## O que a feature 026 entregou

Uma aba na página da pessoa: habilidades como marcas, resumo em três parágrafos, trajetória
em três períodos, destaques com o critério visível, lacunas classificadas por forma, e o
contrapeso da linha de base.

**A decisão de modelagem** está em `research.md` R1: nenhum conceito de competência entra na
rede. Criar `eo.competence` faria a plataforma afirmar que a pessoa *tem* a habilidade — o
que a spec recusa — e licenciaria "quem sabe X", pergunta que a evidência não sustenta.

**O modelo responde em JSON Schema com `strict: true`**, e isso consertou três coisas que
não eram o objetivo: o modelo tinha largado os subtítulos numa geração e a limpeza apagara
dezenove citações em silêncio; a regra de não citar no resumo fora pedida quatro vezes e
ignorada nas quatro; e a regra de devolver lacunas vazias passou a ser obedecida ao virar
campo de array — o modelo devolveu `[]` em vez de inventar um ponto fraco.

## As issues abertas, triadas pela metade

| # | leitura |
|---|---|
| **320** | axiomas SRO como `unknown` — `rules:` não é tipo reconhecido pelo carregador. **Mordeu de novo em 2026-08-15**, ao escrever `profile_thresholds.yaml`. Pequena e isolada |
| **181** | a feature 024 coleta iterações e campos. Falta conferir cobertura antes de fechar |
| **180** | mapear campo de quadro para atributo da ontologia — a 024 grava `field_name` cru. **Trabalho de verdade** |
| **107, 108, 81, 82** | telas — cada uma precisa ser comparada com o que existe |
| **176, 317, 318** | features novas, não pendências |
