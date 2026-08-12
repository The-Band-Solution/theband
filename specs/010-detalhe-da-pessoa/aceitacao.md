# Aceitação — Feature 010: o detalhe da pessoa

**Avaliado em**: 2026-08-12, **depois** do merge — o sprint fechou sem esta avaliação, e é a **L44**
**Base**: os 13 critérios de sucesso da [spec](spec.md), um a um

**A suíte verde não é evidência** — é a L18. Cada linha aponta o teste, a consulta ou a medida.

| SC | O que exige | Veredito | Evidência |
|---|---|---|---|
| **SC-001** | as 75 pessoas alcançáveis por clique | **atendido** | `person_detail_test.exs` — "o nome na lista é link para ela" e "com identidade e proveniência" |
| **SC-002** | os dois números, e **nunca** a soma | **atendido** | teste "mostra os dois números e NUNCA a soma" — procura o número proibido com `refute` |
| **SC-003** | diz que nenhuma evidência foi promovida, e por quê | **atendido** | testes "diz que a evidência não foi promovida, e por quê" e "a explicação **muda** quando existe papel cadastrado" |
| **SC-004** | nenhum texto chama nível de acesso de **papel** | **atendido** | testes "nenhum texto chama nível de acesso de papel" e "nenhum campo devolvido se chama role" |
| **SC-005** | vínculo que saiu aparece com a data, não como atual | **atendido** | testes "o vínculo que saiu continua na lista, com a data" (consulta) e "o vínculo que saiu aparece, com a data" (tela) |
| **SC-006** | cada equipe diz de qual organização é | **atendido** | teste "cada linha diz de qual organização a equipe é" |
| **SC-007** | repositórios marcados como **derivados** | **atendido** | teste "o repositório aparece com nome e como derivado" |
| **SC-008** | pessoa sem designação e sem autoria com as duas ausências **nomeadas** | **atendido** | teste "as ausências são nomeadas, e não um zero solto" — o caso é montado, porque hoje não existe pessoa sem nada |
| **SC-009** | oito consultas, asseridas, e o número não cresce | **atendido, com o número corrigido** | teste "a página acrescenta oito consultas, e o número não cresce com o dado". **A primeira versão asseria 8 numa página que faz 24**: 16 são framework e autenticação, em dois renders. A medida passou a ser a **diferença** dividida por dois — e é a **L38** |
| **SC-009a** | a soma das autorias fecha com 4 241 | **atendido** | teste "a soma sobre as pessoas fecha com o total de issues com autor" |
| **SC-010** | estados distinguíveis com a cor removida | **atendido** | teste "os três estados se distinguem com a cor removida" |
| **SC-011** | legível e navegável em 360 px | **não verificado** | `data-label` está no HTML e os testes o alcançam. **Ninguém olhou a tela** — asserção em markup não é olhar |
| **SC-012** | um tenant não alcança pessoa de outro | **atendido** | testes "pessoa de outro tenant responde não encontrado", na consulta e na rota |

**12 de 13 atendidos. Um não verificado**, e é o mesmo item que atravessa os sprints 006 a 010.

## O que não foi verificado no dado real

| Item | Estado |
|---|---|
| a página de `vinicius-je` mostrando **350 e 609, nunca 959** | **não olhada** — precisa da plataforma no ar, e ela sobe com a chave mestra |
| a explicação da não promoção com as 88 evidências reais | **não olhada** — o mecanismo está asserido no teste, inclusive o caso em que a explicação muda |

## Dívida declarada na entrega

| Dívida | Registro |
|---|---|
| o componente `origem/1` tem **dois** usos, não os três que o plano previa | declarado no plano e no achado A6 da análise |
| `TeamsLive.Show` continua em português | dívida conhecida, fora do escopo da feature |
| as 88 evidências não viram vínculo | [#99](https://github.com/The-Band-Solution/theband/issues/99) e [#100](https://github.com/The-Band-Solution/theband/issues/100) |
