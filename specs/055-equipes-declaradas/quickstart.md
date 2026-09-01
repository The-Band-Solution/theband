# Fase 1 — Como validar

**A medida que decide esta feature é o SC-003**: um painel de período anterior a
uma saída mostra o **mesmo número** antes e depois. É o que separa *sair* de *ser
apagado*, e nenhum teste de caminho feliz o alcança.

## Pré-requisitos

- gates verdes na branch, com o código de saída lido **dentro** do log (L60);
- banco de desenvolvimento com as 12 equipes e 88 pessoas da coleta.

## 1. Os invariantes, sem subir nada

```bash
MIX_ENV=test mix test test/the_band/ontology/seon/eo/team_composition_test.exs \
                      test/the_band/ontology/seon/eo/team_membership_test.exs
```

**Esperado**: verde, e entre eles os casos que reprovam se alguém trocar o
registro de equívoco por remoção da linha.

**As injeções que provam os testes** — cada uma tem de fazer reprovar:

| injeção | o que deve reprovar |
|---|---|
| trocar o registro de equívoco por `Repo.delete` | o caso do histórico preservado |
| detectar ciclo só no vizinho direto | o caso do ciclo de comprimento 3 |
| deixar "vigente" com uma condição só (`ended_at` nulo) | o caso de vincular quem foi invalidado |
| aceitar segundo vínculo vigente | o caso da duplicata |

Injeção que **passa** é a informativa: ela não diz que o código está certo, diz
que o teste não vê ali (L90).

## 2. O SC-003, medido — o histórico sobrevive

O caminho, contra o banco de desenvolvimento:

1. escolher uma equipe e uma pessoa com trabalho registrado num período passado;
2. anotar o número que o painel da equipe mostra **para aquele período**;
3. registrar a saída da pessoa **com data posterior** ao período;
4. **medir de novo o mesmo período**.

**Esperado**: o número não muda. Se mudar, a saída está apagando em vez de
encerrar — e é o defeito inteiro da feature aparecendo.

## 3. O ciclo, incluindo o caminho longo

```
A dentro de B  →  aceito
B dentro de C  →  aceito
C dentro de A  →  RECUSADO, dizendo o caminho: "A faz parte de B, que faz parte de C"
```

Uma recusa que diga apenas *"fecharia ciclo"* manda a pessoa procurar. O contrato
exige o caminho.

## 4. As telas

Com o servidor de pé, em `/teams`:

- **criar** uma equipe e vê-la na lista **marcada como declarada**, ao lado das
  observadas — e a distinção legível **sem cor** (SC-002);
- **vincular** três pessoas com papel, e cronometrar: **menos de 3 minutos** do
  início ao terceiro vínculo, sem console (SC-001);
- **registrar a saída** de uma, e conferir que ela aparece no histórico com o
  período, não some;
- **desfazer um engano**, e conferir que o registro do equívoco fica visível com
  a razão;
- **compor** duas equipes e ver a estrutura nas duas telas.

## 5. A discordância entre coleta e declaração (FR-012)

O caso: a coleta lista a pessoa na equipe, e a declaração diz que ela saiu.

**Esperado**: a tela mostra **as duas afirmações**, identificando a origem de
cada uma. Se ela mostrar só uma, o requisito não está atendido — mesmo que a que
sobrou seja a "mais recente".

## 6. O tenant

```bash
grep -rn "Repo\.\(all\|one\|get\)" lib/the_band/ontology/seon/eo/queries.ex | wc -l
```

Toda consulta desta feature recebe o tenant. A conferência é leitura dirigida das
funções novas, comparando com o que o `AGENTS.md` chama de bug de segurança.
