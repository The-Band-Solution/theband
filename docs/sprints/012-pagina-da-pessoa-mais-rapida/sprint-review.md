# Sprint 012 — Review

**Período**: 2026-08-12 · **Feature**: [013](../../specs/013-pagina-da-pessoa-mais-rapida/spec.md)
**Aceitação**: [aceitacao.md](../../specs/013-pagina-da-pessoa-mais-rapida/aceitacao.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 10 | **10** |
| Requisitos funcionais aceitos | 10 | **10** |
| Critérios de sucesso aceitos | 9 | **9** |

**A pior página do sistema caiu de 6,12 s para 0,031 s** — 197 vezes. A variação entre pessoas saiu
de setenta vezes para 1,4.

## O que foi feito

| Tarefa | Entregável | Aceito |
|---|---|---|
| T001 | a contagem de empates — **zero**, e a descoberta de que `inserted_at` é de microssegundo | sim |
| T002 | cinco casos travando a resposta antes da reescrita | sim |
| T003 | seis retratos determinísticos | sim |
| T004 | resolução lateral por issue, com `inner`/`left` preservados e bindings nomeados | sim |
| T005 | índice `(person_id, no_longer_observed_at)`, com ida e volta | sim |
| T006 | a segunda definição alinhada, e a duplicação declarada no código | sim |
| T007 | **seis `diff` vazios** | sim |
| T008 | a invariante `coletadas == promovidas + lacunas`, com e sem issue não promovida | sim |
| T009 | a medida das oito pessoas, `/work` e `/people`, cinco vezes cada | sim |
| T010 | histórico dobrado não dobra as linhas lidas | sim |

**Nenhuma tarefa ficou aberta**, e nenhuma dependeu da chave mestra — diferente dos dois sprints
anteriores.

## Evidências

```
mix gates → 10 gates verdes, código de saída 0
diff dos seis retratos → vazio
tadeuaugustovs: 6,12 s → 0,031 s   (5 medidas, variação < 8%)
/work: 322 ms → 120 ms
```

## Dívida gerada

| Dívida | Por quê foi aceita |
|---|---|
| `mapping/queries.ex` mantém a segunda definição de promoção vigente | reusar exigiria expor subconsulta pela fronteira, o que a ADR 0003 proíbe. As ordens foram alinhadas e a duplicação está escrita no código |
| `DISTINCT ON` permanece onde a pergunta é agregada | lateral por linha só ganha quando há poucas linhas para decorar |

## O que a análise e o plano acharam antes do código

**Sete achados, nenhum de rodar teste** — todos de medir o banco, ler o código ou olhar o plano:

| Fase | Achado |
|---|---|
| medida | paginar não resolve: `LIMIT 5` custa 6 300 ms e `LIMIT 100` custa 6 648 |
| medida | enxugar a projeção não resolve: 5 738 ms |
| análise | oito das catorze chamadas são `inner`, e `left` faria a tela ganhar linhas |
| análise | `parent_as` exige binding nomeado — a L39 |
| análise | o teste de `EXPLAIN` reprovaria com o código certo |
| análise | o teste de tempo media relógio dentro da suíte — L22 |
| análise | o retrato em HTML cru nunca daria `diff` vazio |

**Oitava feature seguida** em que a análise acha defeito de desenho antes da primeira linha.

## Lições deste sprint

- **L49** — uma medida não descreve uma tela cujo custo depende do plano de execução;
- **L50** — teste que compara duas medidas precisa provar que mediu alguma coisa;
- **L51** — afirmar sobre o schema sem conferir contradiz a documentação que já está no código.
