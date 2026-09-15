# O link para a issue na origem, onde o número aparece

**Aberto em**: 2026-09-14 · **Pedido de quem usa** (Conecta Fapes, no primeiro dia de uso):
*"colocar um link direto para issue no GitHub, o link que tem leva apenas para o repositório do
board"*.

## O que existe, medido

**Um único link externo para issue em toda a plataforma**, e ele é **composto**, não guardado:
`work_item_live/show.ex:1138` monta `"#{repositorio.url}/issues/#{issue.number}"` e o botão
*View at source* aparece no **detalhe** do item. Quando o repositório não é encontrado, o botão
some.

Onde **não** existe: a listagem `/work`, o painel da pessoa, a tela da equipe, o quadro, as
divergências, as sub-listas do detalhe — todos com link **interno** apenas.

**A `url` da issue não é coletada**: `issues.graphql` não a pede, e `grep -rn "html_url"` em
`lib/`, migrações e base de conhecimento devolve **zero**.

## A decisão que já existe, e que este item não desfaz

`work_item_live/index.ex:254-257` registra: *"The name opens the detail inside the platform, not
the source… The link to the source lives in there."* É decisão de desenho, e boa: o nome leva ao
que a plataforma sabe.

**O pedido é outro**: quem olha a lista quer ir à origem **sem passar pelo detalhe** — e hoje o
caminho é abrir o item, achar o botão, clicar. Três passos para um endereço que o número já
determina.

## O que fazer

- **coletar a `url` da issue** (a origem a oferece) em vez de compô-la — repositório renomeado
  ou transferido quebra o link composto, e o guardado acompanha;
- **um alvo externo por ocorrência de número**, ao lado do link interno, nunca no lugar dele: o
  número leva à origem, o título ao detalhe — o padrão que a listagem de rótulos já usa no `+N`;
- onde a `url` não foi coletada, **a ausência é escrita** e o link composto continua como hoje.

## O que este item NÃO é

- não muda a decisão de que o **nome** abre o detalhe;
- não é link para o **quadro** na origem (Projects v2) — isso não existe em lugar nenhum hoje, e
  é pedido separado se alguém quiser.
