# O plano de correções da API — o que ficou aberto na v0.9.0

**Escrito em 2026-09-23**, depois de a API pública chegar a produção.

Nada aqui é defeito que quebre quem usa. São **sete pendências**, cada uma medida e
declarada em algum PR, spec ou registro de aceitação — e a lista existe porque declarar
sete coisas em sete lugares diferentes é o mesmo que não declarar nenhuma.

## O resumo

| # | O que | Onde nasceu | Severidade | Estado |
|---|---|---|---|---|
| **1** | a janela do limite de taxa era fixa | PR #936, declarado | alta | **corrigido, aguardando release** |
| **2** | o CD compara `0.9.0` com `v0.9.0` | CD da v0.9.0 | alta | **corrigido, aguardando release** |
| **3** | ~~o log não distingue as causas de recusa~~ | SC-004 | — | **corrigido em 2026-09-23**: cinco motivos distintos |
| **4** | as medidas não trazem proveniência | SC-007 | média | depende da 062 |
| **5** | ~~ninguém poda `api_access_reads`~~ | PR #936 | — | **decidido em 2026-09-23: guardar indefinidamente** |
| **6** | nenhuma tela lê o registro de acesso | PR #936 | baixa | **sem item até hoje** |
| **7** | dois testes instáveis | gates | **baixa** | varredura não os reproduziu; diagnóstico acrescentado |

E uma que não é correção e não deve ser esquecida: **não houve revisão independente** do
desenho da API nem da avaliação de segurança. Quatro tentativas por agente falharam em 21 e
22 de setembro.

---

## A ordem, e a razão dela

### Primeiro — o que já está pronto e só espera uma release

**1 e 2 estão corrigidos na `development`.** Não há trabalho a fazer: há uma release a
soltar.

O item 2 tem urgência própria e não óbvia: **enquanto ele não chegar a `main`, toda release
termina vermelha** com o deploy funcionando. Um CD que reprova por engano treina quem lê a
ignorá-lo — e a próxima falha real passa despercebida.

> **Custo**: uma release. **Ganho**: o limite de taxa deixa de permitir o dobro na virada, e
> o CD volta a dizer a verdade.

### Segundo — ~~a poda~~ **fechado por decisão**, não por código

**5 — o registro de leitura é guardado indefinidamente.** Decidido pela pessoa mantenedora
em 2026-09-23, depois de a alternativa de 90 dias ser proposta e recusada. Registrado em
`api.access.thresholds`, regra `access_log_retention`.

**Nada a implementar.** O item existia porque ninguém tinha decidido o prazo — e agora foi
decidido. A diferença entre *"guardamos para sempre"* e *"ninguém pensou em podar"* é a
diferença entre escolha e descuido, e até aquela data era a segunda.

**Uma correção ao que este plano dizia antes**: eu havia listado isto como problema de
**crescimento**, afirmando que seria "a tabela que mais cresce na base". **Medi, e não é.**
190 bytes por linha; 100 mil linhas ocupam 18 MB, contra 68 MB de
`spo_performed_project_activities`. Chegar a 1 GB exige 5,5 milhões de leituras.

O argumento real nunca foi espaço — era **retenção de dado sobre pessoas**. Com o prazo
indefinido, o registro permite reconstruir sem limite de tempo que alguém consultou o painel
de outra pessoa. Está escrito na regra, para que seja consequência conhecida e não
descoberta.

### Terceiro — o que devolve visibilidade a quem opera

**6 — nenhuma tela lê o registro.** A tabela existe, `contar_por_rota/3` responde, e quem
opera precisa consultar à mão.

O valor não é conveniência: a FR-024 aponta o registro de acesso como o caminho para
**perceber agregação**. Um caminho que só existe por consulta manual é um caminho que
ninguém percorre.

> **Escopo mínimo**: na tela de tokens que já existe, por linha, quantas leituras na última
> janela e em quais rotas. Não precisa de tela nova.

### Quarto — o que a investigação de abuso precisa

**3 — o log não distingue inexistente, revogado e expirado.** Todas produzem
`motivo=credencial_recusada`.

A informação **existe e é descartada**: `Token.estado/2` já calcula, e o `_` do `else` em
`autenticar/1` joga fora. O conserto é de uma linha, e o cuidado é não quebrar o SC-003 — a
resposta ao cliente deve continuar byte a byte idêntica nos três casos.

> **Por que importa**: *"alguém está tentando um token que nunca existiu"* — varredura — é
> investigação diferente de *"alguém está usando um token revogado"* — credencial que vazou
> antes da revogação. Hoje as duas começam iguais.

### Quinto — o que corrói a confiança no instrumento

**7 — dois testes instáveis**, e não se sabe se há outros. Os dois passam sozinhos e
reprovam sob carga.

Não quebra produção. **Corrói o gate**, que é o instrumento com que tudo o mais é conferido:
um gate que reprova por acaso treina quem lê a reexecutar até passar, e a próxima reprovação
real vira mais uma instabilidade.

> **Primeiro passo, e ele não conserta nada**: fazer a próxima ocorrência **dizer o que
> aconteceu**, em vez de morrer numa asserção crua. Sem isso, cada reincidência custa a
> investigação do zero.
>
> **Segundo**: uma varredura — rodar a suíte N vezes e contar reprovações por arquivo —
> para saber se são dois ou vinte.

### Sexto — o que depende de outra feature

**4 — as medidas não trazem proveniência nem as limitações declaradas da base.**

É o SC-007, e **não é defeito**: o envelope de proveniência foi desenhado para o servidor
MCP, na feature 062, e não chegou à API. Consertar exige `KnowledgeBase.measurement/1`, que
não existe — é a tarefa T003 daquela feature.

> **Ordem natural**: quando a 062 for implementada, o envelope nasce lá. A API passa a usar
> o que já existir, em vez de duplicar.
>
> **O que a API tem hoje**: notas escritas à mão no controlador, e a janela declarada. São
> honestas, e não são proveniência declarada.

---

## O que esta lista NÃO inclui, de propósito

**As seis armadilhas do [documento da API](../api/README.md).** Elas não são erros a
corrigir: são a forma do dado.

Uma pessoa em duas organizações **é** uma pessoa. Uma espera em curso **não** tem duração
final. Ausência de leitura **não** é zero. Achatar qualquer uma delas daria uma API mais
simples e mentirosa.

O que se escolheu foi **dizer**, e a advertência viaja dentro da resposta — `medians_note`,
`counts_note`, `gaps.note`, `competencies_note`, `organizations.note` — e não em
documentação que ninguém abre.

**Uma exceção parcial**: a armadilha 4, os dois denominadores em `/projects`. Ela tem
`denominator_note`, mas a assimetria de fundo continua — `issues` conta por repositório,
`start_criterion` conta por quadro. Se algum dia os dois passarem a contar pelo mesmo
caminho, a nota some junto. Não está na lista porque ninguém pediu, e porque mudar o
denominador muda o significado de um número que já está publicado.

---

## A pendência que não é técnica

**Revisão independente não ocorreu.** Nem do desenho da API, nem da avaliação de segurança
que originou os itens 1 e 5, nem da aceitação da 061 — que foi percorrida por quem
implementou.

Quatro tentativas por agente falharam em 21 e 22 de setembro: duas travaram sem escrever
nada, duas foram recusadas por indisponibilidade da ferramenta.

**Nenhum merge cumpre isso**, e está declarado como lacuna em todos os PRs. Classificação
correta: *revisão não ocorreu*.

É a pendência mais barata de resolver e a mais fácil de esquecer, porque não tem código.
