# Sprint 008 — Review

**Período**: 2026-08-12 a 2026-08-18
**Feature**: [009 — marca que se cura](../../specs/009-marca-que-se-cura/spec.md)
**PR**: [#230](https://github.com/The-Band-Solution/theband/pull/230), `MERGEABLE · CLEAN`,
CI verde em 2m4s

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 9 | 9 |
| Entregáveis aceitos | 9 | **9** |

**10 gates verdes por código de saída**, **430 testes**, 28 próprios da feature. A avaliação
critério por critério está em [aceitacao.md](../../specs/009-marca-que-se-cura/aceitacao.md): **12
de 12 SC atendidos**, dois com a ressalva de não terem sido exercitados em produção.

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T001 | [#220](https://github.com/The-Band-Solution/theband/issues/220) | `inaccessible_reason` de `varchar(255)` para `text`, truncagem na borda | sim |
| T002 | [#221](https://github.com/The-Band-Solution/theband/issues/221) | `transient?/1` julga erro de GraphQL, com o payload real no teste | sim |
| T003 | [#222](https://github.com/The-Band-Solution/theband/issues/222) | a falha do momento não marca — asserção no banco | sim |
| T004 | [#223](https://github.com/The-Band-Solution/theband/issues/223) | `list_collectable/2` rejeita só o excluído; 96 → **135** coletáveis | sim |
| T005 | [#224](https://github.com/The-Band-Solution/theband/issues/224) | a data preserva o começo; o motivo carrega a última falha | sim |
| T006 | [#225](https://github.com/The-Band-Solution/theband/issues/225) | a marca sai **e** as issues entram na mesma execução | sim |
| T007 | [#226](https://github.com/The-Band-Solution/theband/issues/226) | a coleta conclui com tudo falhando; o excluído não recebe requisição | sim |
| T008 | [#227](https://github.com/The-Band-Solution/theband/issues/227) | `repositories_unreachable`, incrementado a cada falha | sim |
| T009 | [#228](https://github.com/The-Band-Solution/theband/issues/228) | a lista diz desde quando e por quê, legível sem cor | sim |

## O que não foi feito

| Item | Motivo | Destino |
|---|---|---|
| a prova no dado real — as 39 marcas limpas por uma coleta | **exige a chave mestra e o token**, que são da pessoa mantenedora. Eu não os peço nem os recebo | pendente, com o procedimento em V2 e V3 do quickstart |
| iteration própria do sprint | configurar iterations recria as existentes — L11 | product backlog, #176 |
| verificação visual da tela em 360 px | a célula de estado cresceu, e ninguém **olhou** | conferir antes de fechar o próximo sprint |

## O que a análise mudou, antes do código

Seis correções, e a crítica **não era sobre a lógica da feature**:

`inaccessible_reason` era `varchar(255)`. O maior motivo gravado tem 181 caracteres, e o da falha
interna dá **~228** com o prefixo — **27 de folga**. Sem `validate_length`, o valor longo vai ao
banco e **levanta**; `registrar_ou_seguir/2` cobre changeset inválido, não exceção do driver: a fase
de coleta cairia.

O que tornou isso urgente foi a própria feature: ela faz a plataforma escrever esse campo **a cada
coleta que falhar**, em vez de uma vez.

E **três suspeitas foram derrubadas por medida** em vez de aceitas: o orçamento da origem
(`cost = 1`, 160 pontos de 5 000), outro consumidor de `list_collectable/2` (um de produção, zero em
teste), e `clear_inaccessible/2` deixando o motivo para trás (limpa os dois campos).

## Evidências

```
$ mix gates > /tmp/g9b.txt 2>&1; echo "código de saída: $?"
código de saída: 0
10 gates verdes.
Result: 430 passed
```

```sql
observados=135   coletáveis antes=96   coletáveis depois=135
voltam a ser tentados=39   issues dentro deles=899
```

**Dois defeitos conferidos por reprovação**, invertendo o código de propósito:

| defeito reintroduzido | testes que reprovaram |
|---|---|
| `list_collectable/2` voltando a filtrar o inacessível | **3** |
| erro de GraphQL sempre permanente | **3** |

## Dívida gerada

| Dívida | Por quê |
|---|---|
| repositório apagado na origem será consultado a cada coleta | é o preço de não desistir; o critério de revisão é a **natureza do erro**, nunca o tempo |
| a classificação da falha interna depende do **texto** da mensagem | texto de terceiro muda; o teste usa o payload real, e a cura torna a marca reversível |
| a prova no dado real é pendente | depende de credencial que não é minha |

## O defeito que este sprint achou fora dele

O `@doc` órfão que eu introduzi no commit da feature 008 **passou pelos dez gates e pelo CI**. Numa
compilação limpa, `main` reprova:

```
$ git stash && rm -rf _build/dev/lib/the_band && mix compile --warnings-as-errors
main limpo: código de saída 1
redefining @doc attribute previously set at line 395
```

**E o mecanismo que eu publiquei estava errado.** O experimento que o isolou, feito depois, mostrou
outra coisa: o aviso **é** emitido — três vezes na saída —, e o gate sai **zero** porque
`execute({:mix, ...})` **descartava o retorno** de `Mix.Task.run/2`. `mix compile
--warnings-as-errors` não levanta: devolve `{:error, diagnostics}`.

O gate de compilação **nunca reprovou por aviso**, nem local nem no CI. Registrado em
[#229](https://github.com/The-Band-Solution/theband/issues/229), **Bug, P0**, com o diagnóstico
corrigido, e a L36 reescrita.

A correção veio junto nesta branch porque sem ela a própria feature não passa nos gates — e está
declarado no PR.

## O defeito do gate, corrigido depois

O achado do `@doc` órfão levou a uma segunda correção, no
[PR #231](https://github.com/The-Band-Solution/theband/pull/231): **o gate de compilação nunca
reprovou por aviso**, porque `execute({:mix, ...})` descartava o retorno de `Mix.Task.run/2` — e isso
valia para todo gate `{:mix, ...}`.

O veredito passou a ser o **código de saída**, com cada gate em subprocesso. `mix gates` completo em
**78,6 s**, e **2,46 s** para reprovar com o defeito presente. O CI ficou verde com o gate honesto,
o que significa que nenhuma dívida invisível estava escondida atrás dele.

## Lições deste sprint

**L36** — gate que descarta o retorno da task não é gate. E o corolário sobre método: quando duas
medidas verdadeiras parecem se contradizer, o elo entre elas é **hipótese**, não conclusão.

**L37** — a coluna estreita só cai quando a escrita fica frequente.

Detalhamento em [licoes-aprendidas.md](../licoes-aprendidas.md).
