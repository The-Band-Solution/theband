# PROMPT — a tela da rede de revisão (073)

Protótipo: [`review-network.html`](review-network.html) · publicado em
<https://claude.ai/artifact/Ni1tRcrWPWXALXpvUxb9Uq> · 2026-10-03 · versão 2 · **APROVADO em 2026-10-03**
pela pessoa mantenedora, com as decisões de Q1–Q5 aplicadas e republicado no mesmo endereço.
Decisões e perguntas: [`README.md`](README.md).

## 1. Os pedidos, textuais e em ordem

**Da pessoa mantenedora** (os que regem esta tela):

1. 2026-09-07: *"quero exatamente a tela aprovada"*.
2. 2026-10-03, ao abrir a 073 (o `Input` da `spec.md`): *"Tela mobile-first com protótipo aprovado
   antes do código. Fora: rótulo de papel da pessoa, comparação com equipes, coautoria, índice de
   mundo pequeno. Toca dado de pessoa: avaliação de segurança antes do código."*
3. 2026-10-03, decisões sobre a avaliação de segurança (`seguranca.md`, fim): concentração sem
   nome e só no alcance (R1); não contar o que ficou fora do alcance (R2); rede por organização
   observada (R4); três janelas 30/90/180 calculadas ao fim da coleta, sem pedido de recálculo
   (R6); uma leitura vigente, sem histórico (R7).
4. 2026-10-03, o pedido que encomendou este protótipo: *"olhe os dados que ele gera e me faça uma
   proposta de tela"*.
5. 2026-10-03, aprovação da versão 1 com respostas (via coordenador, textual): *"D1–D10: aprovadas
   como propostas. Q1: não desenhar a rede nesta fatia. A tela 6 (matriz) sai da régua desta fatia
   e vai para a seção de esboço da fatia 2, junto da tela 7, marcada como 'não faz parte desta
   entrega'. Q2 (decidida pelas respostas da base): abaixo da amostra mínima a fração fica
   AUSENTE, com o motivo ('too few reviews…' com N de 10); a unidade é REVISÕES (uma pessoa
   revisando uma solicitação; uma solicitação com dois revisores conta duas). Tire a variante
   'mostra com aviso' da tela 4. Q3: além do instante e da idade da leitura, uma linha diz que uma
   coleta terminou depois da leitura (quando o fim da coleta for registrado por organização; a
   régua diz isso). Q4: para alcance parcial, os grupos que não se revisam entre si são contados
   SÓ entre as pessoas alcançadas. Ajuste a tela 3. Q5: com alcance parcial, a contagem de bot/app
   não aparece (como está desenhado). Base, também decidido: conta apagada no GitHub entra em 'sem
   pessoa ligada', não em bot; grupo mínimo = 3."*

**Do pedido que encomendou o protótipo** (2026-10-03, via coordenador, textual, trecho):

> Proposta de TELA para a spec 073 — Rede de revisão (épico #1182), como protótipo navegável
> publicado (artifact) e guardado na spec. […] Fontes obrigatórias: `spec.md` (emendada) e
> `seguranca.md` (R1–R14 e as decisões de 2026-10-03 no fim: concentração sem nome e só no
> alcance; não contar o que ficou fora do alcance; rede por organização observada; três janelas
> 30/90/180 calculadas ao fim da coleta, sem pedido de recálculo; uma leitura vigente sem
> histórico; lista ordenada por nome, sem ordenar por medida; sem exportação; sem rótulo de
> papel). `docs/design-system.md` […]. O que o repositório de referência GERA […]. Diga, no
> README, o que dessa saída a tela ADOTA, o que ADAPTA e o que RECUSA, e por quê. Problemas já
> observados que a tela não pode repetir: o grafo-novelo ilegível (53 nós sobrepostos); contas que
> não são pessoa como nós (`LEDS`, conta da organização, e `dependabot[bot]`); "Papel na rede" por
> percentil (julgamento de pessoa); números de centralidade com 4 casas sem significado para quem
> decide; "desconexo, contendo 1 componentes"; equipes somadas com sobreposição. […]
> Dados: use a FORMA e a ESCALA da saída de referência (≈50 pessoas, ≈150 arestas, 6 grupos), mas
> com nomes FICTÍCIOS ("Ana Example", "Bia Example"…). Nunca use os logins reais do relatório.
> Telas a desenhar (no mínimo): 1. Em repouso, quem administra, janela 90 dias […]; 2. Uma pessoa
> aberta: os pares […], com pesos; 3. Alcance parcial (líder de equipe) […]; 4. Ausências: janela
> sem revisão; amostra abaixo do mínimo; leitura ainda não calculada / falhou […]; 5. Telefone
> (360 px) […]; 6. (Proposta, opcional) uma visualização da rede que seja LEGÍVEL […] como
> pergunta aberta com recomendação, e explique o risco (R13 […]); 7. Um esboço (não para aprovação
> agora) de como as fatias seguintes encaixariam […].

## 2. O brief de design seguido

- **Herdar, não reinventar**: tokens de `specs/070-operador-da-plataforma/prototipo/` e de
  `specs/060-tela-da-equipe/prototipo/` (papel, tinta, verdete, `info`, âmbar, clay; serif no
  corpo, grotesca nos títulos, mono em números com `tabular-nums`; pilha do sistema, nenhuma
  webfont; dois temas por tokens).
- **Marcas**: `derived` âmbar hachurado em todo bloco com número e nas barras de concentração;
  `observed` verdete cheio só na linha da fonte (as revisões enviadas); `absent` tracejado, sempre
  dizendo de quem é a ausência; `your reach` contorno azul para o recorte; `declared` azul cheio só
  no esboço. Nenhuma distinção só por cor; botão *View in greyscale*.
- **Moldura de tela** com o método e a rota de research R15, e o estado de quem consulta.
- **Ausência escrita, nunca 0 nem travessão**; **nenhum total** sobre equipes; **nenhuma ordenação
  por medida**; **nenhum nome** na concentração.
- **Dado só de exemplo**, de um conjunto de revisões com semente fixa, para que os números batam
  entre si.
- **Telefone primeiro**: lista empilhada com `data-label` abaixo de 40 rem.

## 3. A estrutura aprovada, seção por seção — a régua do QA (versão 2, aprovada em 2026-10-03)

Cada item é conferido na tela entregue: **existe, na ordem, com o texto, com a marca, com a ação,
com a recusa**. Divergência é defeito. Texto entre aspas é literal (inglês, como a tela); números
são do exemplo e mudam com o dado, a forma não.

### Tela 1 — em repouso, quem administra, 90 dias

1.1 Barra do app: `The Band` · `Organisations › <organização>`; à direita, quem consulta.
1.2 Título **"Review network"** e, abaixo, **"Is code review concentrated in a few people?"**.
1.3 Quando o tenant observa mais de uma organização: rótulo "Observed organisation" e um link por
    organização, a atual destacada. Com uma só, a linha não aparece.
1.4 Seletor de janela com três opções, nesta ordem: "30 days", "90 days", "180 days"; 90 por
    padrão; a escolhida destacada; a troca muda `?window=` e não enfileira nada.
1.5 Logo abaixo: "Switching the window reads another stored reading. It computes nothing."
1.6 Linha da leitura: "Reading of <instante UTC> (<idade>), computed when the last review
    collection ended. Window: <início – fim>, <N> days." e "Every number on this page is derived
    from the submitted reviews observed at the source", com a marca `observed`.
1.7 Bloco **"Concentration"** com a marca `derived`: três linhas, nesta ordem — "The person who
    reviewed most did", "The two people who reviewed most did", "The three people who reviewed most
    did" —, cada uma com a porcentagem inteira, "<s> of <total> reviews", e uma barra hachurada na
    escala 0–100% com marca em 50%; legenda "0% · 50% · 100%". **Nenhum nome, nenhum limiar, nenhuma
    cor de faixa.**
1.8 Sob as barras: "No name here, for anyone. A review is one person reviewing one change request:
    a change request reviewed by two people counts as two reviews. Excluded reviews are in neither
    part of the fraction."
1.9 Bloco **"Reviews in this window"** (`derived`): "reviews" <n> "person × change request";
    "people who reviewed" <n>; "people reviewed" <n> "had at least one change request reviewed".
1.10 Sob ele: "<n> observed people of this organisation had no review activity in this window:
    they neither reviewed nor opened a change request. They are not in the list."
1.11 Bloco **"Groups that do not review each other"** (`derived`): "<n> groups. No review goes
    between them, in either direction." com um rótulo por tamanho ("40 people", "5 people"…), **ou**,
    com um grupo só, "Everyone in the network is linked by review, directly or through others."
1.12 Sob ele: "Only people who gave or received at least one review are in a group. A separate
    group can be a separate product on purpose; it is not a silo by itself."
1.13 Bloco **"Left out of the network"** (`derived`): "self-reviews", "bot or app", "not linked to
    a person", cada um com a contagem e a explicação curta; a de "not linked to a person" é "the
    account on either side matches no observed person, or was deleted at the source" (conta
    apagada na origem entra aqui, nunca em bot); abaixo, "Counted, never listed by
    account. A self-review is counted only here, never against a person." **Nenhum login.**
1.14 Bloco **"People"** (`derived`), e **antes da tabela**: "These counts do not assess a person.
    How much someone reviews follows who is asked to review, their role, time off and time zone; a
    quick approval and a long review count the same; only reviews made on the observed repositories
    are visible here."
1.15 Depois: "Ordered by name. No column sorts the list. Open a name to see their pairs."
1.16 Tabela de três colunas, "person", "reviewed", "was reviewed", **ordenada por nome**;
    **nenhum cabeçalho clicável para ordenar**. Cada nome é um controle que abre os pares (tela 2).
1.17 Célula "reviewed": "reviewed <n>, of <m> people" (singular "person"), ou a ausência tracejada
    "no review by them in this window".
1.18 Célula "was reviewed": "was reviewed on <n>, by <m> people", ou a ausência tracejada "no review
    on their change requests in this window". **Nunca 0, nunca travessão, nunca em branco.**
1.19 Rodapé de proveniência: as versões da regra da aresta, dos parâmetros e das medidas; a fonte;
    e "Not on this page: export, ordering by a count, role labels for people."
1.20 **Não existe** na tela: botão de exportar, cópia, impressão dedicada, rótulo de papel, faixa,
    centralidade, ranking, "top reviewer", desenho da rede de qualquer forma — grafo ou matriz (Q1).
1.21 Concentração com a amostra abaixo do mínimo: ver 4.2 (ausente; vale para qualquer conta e
    janela).

### Tela 2 — uma pessoa aberta

2.1 Os pares abrem **no lugar**, sob a linha, sem rota nova; o controle mostra aberto/fechado
    (`aria-expanded`).
2.2 Duas colunas: "<Nome> reviewed the change requests of" e "The change requests of <Nome> were
    reviewed by"; cada par com o nome e "on <n>"; **ordenados por nome**.
2.3 Lado vazio: ausência tracejada, "reviewed nobody in this window" ou "nobody reviewed them in
    this window".
2.4 "Ordered by name. The number is change requests in this window." e o link "Open <Nome>'s
    panel" para `/people/:id`.
2.5 Quando as solicitações revisadas e a soma dos pares diferem: "<n> change requests reviewed,
    <s> reviews: a change request reviewed by two people counts once in the row and once in each
    pair."

### Tela 3 — alcance parcial

3.1 Aviso de recorte, com ícone e palavra, antes da leitura: "This page shows only the people you
    reach. You reach your own record and the people on the teams you belong to or that an access
    scope grants you, including the teams of an organisation in your scope. Administrators of this
    tenant reach everyone. What you see is a slice, not the whole; the page does not say how much
    is outside it." **Sem** a cláusula de liderança declarada (D5).
3.2 Títulos de bloco com o recorte: "Concentration among the people you reach", "Reviews in this
    window among the people you reach", "People you reach".
3.3 Sob a concentração, além de 1.8: "Counted only over reviews where both the reviewer and the
    author are people you reach."
3.4 "<n> people you reach had no review activity in this window…" (sobre os alcançados).
3.5 Grupos **contados só entre as pessoas alcançadas** (Q4): título "Groups that do not review
    each other among the people you reach"; com um grupo, "Everyone you reach with a review between
    them is linked, directly or through others: <n> people."; com mais, "<n> groups among the people
    you reach. No review goes between them, in either direction." e um rótulo por tamanho; sem
    revisão entre alcançados, a ausência "no review between people you reach in this window". Abaixo:
    "Counted only among the people you reach: a review with someone outside your reach links nobody
    here, and people outside your reach are in no group on this page. Only people who gave or
    received at least one review are in a group." **Nenhum tamanho de grupo da organização inteira,
    nenhum "small group".**
3.6 "Left out of the network" **sem números**: "Self-reviews, reviews by bots or apps, and reviews
    by accounts not linked to a person are left out. Their counts are about the whole organisation,
    people you do not reach included, so they are shown only to those who reach everyone."
3.7 Lista só com pessoas alcançadas; acima dela, além de 1.14–1.15: "Each row shows the person's
    whole count in the window; the pairs show only people you reach."
3.8 Pares fora do alcance: **nenhuma linha e nenhum número**; uma linha com a marca `your reach`:
    "some pairs are outside your reach".
3.9 **Não existe** na tela: quantas revisões, pares ou pessoas ficaram fora; nome de quem está fora.

### Tela 4 — ausências

4.1 (4a) Janela sem revisão: concentração tracejada "no review in this window" e "The observed
    repositories show no submitted review between people in this window. There is no share to
    compute, and the page does not write 0%."; contagens tracejadas "none in this window"; grupos
    "With no review there is no group to count."; pessoas que abriram solicitação aparecem com as
    duas ausências.
4.2 (4b) Amostra abaixo do mínimo (Q2): **nenhuma fração, nenhuma barra**; a ausência tracejada
    "too few reviews to speak of concentration: <n> of the 10 needed" e "Below 10 reviews, one review
    more moves a share by more than ten points, so no share is shown. A review is one person
    reviewing one change request. The counts beside this block still hold." As contagens de 1.9
    continuam. A unidade do mínimo é **revisões** (pessoa × solicitação).
4.3 k maior que o número de revisores, com a amostra suficiente: a linha de k fica ausente "only
    <n> people reviewed", com "a share for <k> people says nothing when only <n> reviewed". (Regra
    sem desenho na versão 2: o dado de exemplo não tem esse caso acima do mínimo.)
4.4 (4c) Leitura não calculada: aviso tracejado "This reading has not been calculated yet. The
    platform calculates the 30, 90 and 180-day readings when a review collection for <org> ends.
    …" com a ausência "not calculated" da plataforma; **nenhum número, nenhum 0%, nunca a leitura
    de outra janela**.
4.5 (4d) Leitura não renovada (Q3): a leitura vigente com o instante e a idade dela (1.6) e, **quando
    o fim da coleta de revisões estiver registrado por organização e for posterior ao instante da
    leitura**, o aviso de borda dupla "A review collection ended on <data>, after this reading. The
    reading was not refreshed. The numbers below are from <data>." Sem esse registro, a linha não
    aparece; nunca vem de `oban_jobs`.
4.6 (4e) Organização de outro tenant ou inexistente: "Not found", o mesmo texto para os dois;
    nunca "permission denied". Janela fora da lista volta para 90.

### Tela 5 — telefone, 360 px

5.1 Tudo empilhado na ordem da tela 1: título, janela, leitura, concentração, contagens, grupos,
    exclusões, pessoas.
5.2 A tabela vira cartões, cada célula com o nome da coluna ("person", "reviewed", "was reviewed");
    os pares abrem dentro do cartão, uma coluna só. **Sem rolagem horizontal.**
5.3 Nenhum desenho da rede (Q1).

### Telas 6 e 7 — esboço, **não faz parte desta entrega**

6.1 Não é régua de QA (Q1, decidida em 2026-10-03). A tela 6 (matriz ordenada por grupo, SVG no
    servidor, sem `raw/1`, sem biblioteca JS — R13) e a tela 7 (grupo observado × equipe
    declarada, sem total; quem fica sem revisor) registram a direção das fatias 2 e 3. Se a tela
    entregue mostrar qualquer uma delas, é defeito.

### Seção final — "Decisions and open questions"

8.1 As decisões de 2026-10-03, D1–D10, Q1–Q5 e as da base são do protótipo, não da tela. A tela
    entregue não as mostra.

## 4. Como cada papel usa este arquivo

- **Product Owner**: registra a aprovação de 2026-10-03 e as respostas no item do backlog
  (épico #1182) com o link e este prompt, e aceita a tela **só** conferida item a item contra a
  seção 3, com captura da tela real ao lado.
- **Design**: marca *Decided <data>* em cada decisão e pergunta respondida, ajusta a seção 3 e
  republica **no mesmo endereço** (mesmo arquivo; de outra conversa, pela `url`).
- **Elixir/Phoenix Developer**: implementa a seção 3, nada além; o que não for possível ou honesto
  com o dado volta ao protótipo antes do código. Os textos da seção 3 são os da tela.
- **QA**: confere cada item da seção 3 na tela entregue — existe, na ordem, com o texto, com a
  marca, com a ação, com a recusa —, nas duas contas (administração e alcance parcial), em 360 px,
  e em tons de cinza.
- **Security**: confere 1.13, 1.20, 3.1, 3.5, 3.6, 3.8 e 3.9 contra R1, R2, R5 e R9.
