# As recusas falam português, e a tela fala inglês — mais o nome da coluna vazando

**Achado em 2026-09-10**, ao exercitar os caminhos felizes e infelizes do ato de declarar
equipe dentro de outra **pela tela** — lendo o que a pessoa de facto lê, e não o que a página
contém.

> Este item nasce do critério que o papel de Product Owner ganhou no mesmo dia: *"a frase está
> no idioma da tela — e o produto fala inglês"*. O critério encontrou o defeito na primeira
> vez em que foi aplicado, e encontrou-o no ato que acabara de ser consertado.

## O que a pessoa lê hoje

Medido no `flash-error` da aba de estrutura de `/teams/:id`:

| ato | o que aparece |
|---|---|
| nome vazio | `name: can't be blank` |
| nome só de espaços | `name: can't be blank` |
| nome de 300 caracteres | `name: should be at most 255 character(s)` |
| nome repetido | `já existe uma equipe declarada com este nome nesta organização` |

**Duas coisas erradas na mesma tela**, e nenhuma é o conteúdo da recusa: as três primeiras
estão em inglês e a quarta em português, e todas começam com o **nome da coluna**.

## Defeito 1 — o idioma

`DESIGN.md` e `PRODUCT.md` dizem a mesma coisa: *a interface fala inglês; código e documentação
falam português*. Estas frases são **copy de tela** — chegam ao flash —, e estão do lado
errado da regra.

São **dez**, todas em `lib/the_band/ontology/seon/eo/commands.ex`:

```
esta pessoa não tem vínculo vigente nesta equipe        (duas ocorrências)
a saída declarada exige quem a declarou
a saída não pode estar no futuro
o equívoco exige uma razão escrita
o equívoco exige quem o registrou
uma equipe não pode fazer parte de si mesma
isto fecharia um ciclo: <caminho>
esta composição não está vigente
já existe uma equipe declarada com este nome nesta organização
```

**O que NÃO fazer**: traduzir na tela. A frase nasce no domínio e o domínio é quem sabe o que
recusou; traduzir no consumidor espalha a mesma frase por cada tela que chamar o ato. A
tradução é na origem, e o catálogo (`gettext`) é onde ela mora se um dia houver segundo idioma.

## Defeito 2 — o nome da coluna na frase

`motivo_do_changeset/1` monta `"#{campo}: #{mensagem}"`. A pessoa lê `name:`, que é nome de
coluna do banco, não palavra de produto. E quando o changeset tem dois erros, lê os dois
concatenados por `; `.

**Oito consumidores** dessa função, e é por isso que o conserto não é de uma linha: cada ato
precisa decidir como a sua recusa se lê como frase. *"Name can't be blank"* é melhor que
*"name: can't be blank"* e pior que *"A team needs a name."*

## Por que não foi consertado junto

Dez frases e oito pontos de consumo. O PR que consertou os caminhos infelizes
(`fix/055-subequipe-numa-transacao`) já conta uma história — *a recusa recusa em vez de
levantar* —, e esta é outra: *a recusa fala a língua da tela*. Misturá-las faria a revisão de
uma esconder a outra.

## O que fecha este item

1. as dez frases em inglês, na origem;
2. `motivo_do_changeset/1` deixando de prefixar o nome do campo — ou cada ato declarando a sua
   frase, o que é melhor e mais caro;
3. teste que lê o **`flash-error`** (e não a página) em cada um dos caminhos infelizes dos atos
   da 055, como `subequipe_test.exs` passou a fazer;
4. e a pergunta que fica para a pessoa mantenedora: **as recusas viram `dgettext` com msgid em
   inglês, ou string literal em inglês?** A primeira prepara o segundo idioma e custa catálogo;
   a segunda é mais simples e adia. Recomendo `dgettext`, porque `errors.po` já existe e as
   telas já o usam — string literal criaria duas formas de dizer a mesma coisa.

## O que este item NÃO é

Não é sobre o conteúdo das recusas. As dez **dizem o que aconteceu e o que fazer**, que é o
difícil — *"já existe uma equipe declarada com este nome nesta organização"* é uma boa recusa
escrita no idioma errado.
