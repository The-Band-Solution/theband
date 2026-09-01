# Português na interface que serve em inglês

Levantado em 2026-09-01, a pedido da pessoa mantenedora. **Ainda não é spec** — é
a medição, com o achado que muda o que precisa ser feito.

O locale padrão da plataforma é `en` (`config/config.exs`). Mesmo assim há
português em três lugares diferentes, e **só um deles é o que se costuma
procurar**.

---

## 1. O menu principal — em toda tela, para todo mundo

`lib/the_band_web/components/layouts.ex`, linhas 120 a 141. Os títulos das seções
são literais em português, **ao lado de itens em inglês**:

| título (pt) | itens (en) |
|---|---|
| `Trabalho` | Work |
| `Vocabulário` | Roles |
| `Operação` | Syncs, Tools |
| `Contas` | Accounts, Access scopes |

É a tela mais vista da plataforma, e ela é **bilíngue por linha**. Quem entra em
inglês lê metade.

---

## 2. Dezessete frases no catálogo cujo `msgid` é português e a tradução inglesa está vazia

**Pior do que parece**: quando a tradução falta, o gettext devolve o `msgid`.
Quem usa a plataforma em inglês recebe estas frases **em português**, e não há
erro em lugar nenhum — nem no log, nem na tela.

| domínio | quantas | exemplos |
|---|---:|---|
| `sistema` | 5 | *"Senha definida."*, *"Escopo %{nivel} concedido."*, *"Escopo revogado."* |
| `errors` | 12 | *"A senha precisa de pelo menos 12 caracteres."*, *"Conta não encontrada."*, *"Concessão recusada: %{motivo}."* |

---

## 3. Literais soltos nas telas

| arquivo | texto |
|---|---|
| `live/work_item_live/index.ex:53` | `"Trabalho"` |
| `components/work_charts.ex:284` | `"Trabalho acumulado e o que resta"` |
| `live/people_live/index.ex:268` | `"Nenhuma pessoa"` |
| `live/work_item_live/show.ex:506` | `"Nenhum encontrado"` |

E dois **híbridos** — frase em inglês com palavra portuguesa dentro, que são os
mais difíceis de achar por varredura:

> *"Configure it in AI provider, under **Operação**."*
> — em `live/profile_run_live/index.ex` e `live/people_live/show.ex`

---

## O achado que importa mais que a lista

**`mix mensagens.verificar` passa com `EXIT=0`.**

Ele existe desde a feature 047 exatamente para impedir frase de tela em literal —
e as 23 ocorrências acima passaram por ele. Isso quer dizer que a varredura tem
**classes que ela não cobre**: `menu-title`, título de página e estado vazio.

É a mesma forma da **L81** — *fechar o contraexemplo não fecha a classe*. O
verificador já foi ampliado duas vezes (classe assign na 047/T012, classe
função-origem na 047/T015), e **continua com classes de fora**.

**A correção verdadeira não é traduzir as 23 ocorrências.** É ampliar o
verificador para que a vigésima quarta não nasça. Traduzir sem isso resolve hoje
e reabre no próximo PR — e a próxima descoberta será por acaso de novo.

---

## Como isto deve ser feito, quando for puxado

Na ordem, e a ordem é o ponto:

1. **ampliar o verificador** para as classes que escaparam, e **vê-lo reprovar
   contra o código de hoje**. Verificador novo nasce com teste que NÃO passa por
   ele (L77) — se ele nascer verde, não está vendo nada;
2. **traduzir as 17 do catálogo** — é preencher `msgstr` em `en`, sem tocar em
   código;
3. **migrar os literais** para o catálogo, com o verificador já cobrindo.

Fazer 2 e 3 antes de 1 é o que garante a reincidência.

## A decisão, tomada em 2026-09-01

**O inglês é a língua-fonte do produto.** O `msgid` passa a ser sempre inglês, e
o `pt` continua existindo como tradução.

> *"quero tudo em inglês no sistema"* — pessoa mantenedora, 2026-09-01

### O que isso resolve por construção

A ausência de tradução deixa de ser um defeito. Quando falta `msgstr`, o gettext
devolve o `msgid` — e com a chave em inglês, **a falta cai no idioma padrão**, em
vez de mostrar português a quem escolheu inglês. O caso 2 acima deixa de ser
possível, e não por vigilância: por forma.

### O que ela custa

**Dezessete `msgid` são reescritos**, e reescrever chave não é traduzir: a chave
é o identificador. Trocar `"Senha definida."` por `"Password set."` **quebra o
vínculo** com a tradução `pt` existente, que precisa ser remapeada no mesmo
passo. Feito com `mix gettext.extract` sem cuidado, as traduções antigas viram
obsoletas e as novas nascem vazias — o defeito ao contrário.

### O que ela NÃO decide

**O `pt` fica.** Ele está hoje inalcançável — não existe troca de idioma em
runtime — e **90% vazio**: 18 traduções preenchidas de 173. Manter é decisão
consciente, e preserva a intenção do PR #637, que traduziu a tela de entrada
*"para quando o locale `pt` for servido"*.

**A consequência disso precisa estar dita**: enquanto não houver troca em
runtime, o `pt` é um catálogo que ninguém lê, e catálogos que ninguém lê
apodrecem. Se a troca não vier, a decisão honesta no futuro é removê-lo — e não
mantê-lo por hábito.

### O que muda no verificador

Com o inglês como fonte, o gate ganha uma regra a mais que ele não tinha: **`msgid`
em português é erro**, e não só literal fora do catálogo. É uma verificação
barata — a mesma varredura que hoje procura literais passa a olhar as chaves.
