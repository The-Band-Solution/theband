# O protótipo das telas do operador da plataforma (070, T012)

[`platform-operator.html`](platform-operator.html) — abrir no navegador. Cinco telas, separadas
pelas faixas `screen N · nome`, uma nota sobre quem não é operador, e a seção final
`Decisions and open questions`. Tudo visível ao carregar; o único controle é *View in greyscale*.

Desenhado em **2026-10-01** pelo agente Design, tarefa T012 de [`../tasks.md`](../tasks.md).
Publicado em **<https://claude.ai/artifact/KWYR2rPJX1V4FukhszDVFA>**; **a cópia aqui é a que
vale** — o endereço pode mudar, a spec não pode depender dele.

**Estado: decisões da pessoa mantenedora de 2026-10-01 aplicadas e republicadas no mesmo endereço
(versão 2). A data de aprovação fica em aberto até ela olhar a versão republicada.** Bloqueia
T039, T040 e T056.

A estrutura seção a seção — **a régua do QA** — está na seção 3 do [`PROMPT.md`](PROMPT.md).

## O dado que a tela mostra

**Todo de exemplo**, marcado `example` na página: organizações `Acme Labs` (`acme-labs`),
`Example Org` (`example-org`), `Legacy Works` (`legacy-works`) e `Northwind Studio`
(`northwind`); operadores `Rui Example` e `Bia Example`, `ops@example.org`; segredo, URI e
códigos de recuperação inventados (o segredo é o vetor público `JBSWY3DPEHPK3PXP`, duplicado).
Nenhuma consulta ao banco: a feature não existe ainda, e a tela não mostra dado de domínio.

## As premissas que o protótipo herda da spec (já decididas)

| de onde | o que fixa na tela |
|---|---|
| FR-011 emendada, T005 (2026-10-01) | telas por controller, cookie próprio: toda recusa é página re-renderizada; sem script inline (CSP `script-src 'self'`) |
| FR-016 (2026-10-01) | o segundo fator é obrigatório; um formulário só com três campos |
| data-model §5, T014 (2026-10-01) | as razões, os rótulos em inglês, nota obrigatória em `suspected_compromise` e `other`, `investigation_closed_no_compromise` só contra `suspected_compromise` |
| FR-007 | a lista mostra nome, slug, estado e a data do último episódio; nada mais |
| FR-009, `rotas-da-plataforma.md` | quem não é operador recebe o `404` comum — nota, não tela |
| `credenciais-do-operador.md`, A3 | a espera tem a mesma frase da recusa |
| T009, research R13 | sem QR, como recomendação (Q1) |

## As decisões de desenho — *Decided 2026-10-01*, pela pessoa mantenedora, D1–D5 aprovadas

| # | decisão | a razão |
|---|---|---|
| **D1** | Uma frase de recusa por formulário, sem campo marcado: *"Not signed in. Check the email, password and code, then try again in a moment."* | marcar um campo diria qual estava certo; "in a moment" cobre a espera sem ser segunda mensagem (A3) |
| **D2** | "Shown once" vem **antes** do segredo e dos códigos; a recusa do código de cadastro diz que a chave não volta | o contrato não devolve o segredo no segundo passo: quem errou o código e não guardou a chave precisa de código novo |
| **D3** | Só o ato que cabe ao estado aparece; o outro não é botão desabilitado | não é recusa, é inaplicável; a corrida de duas abas cai nas recusas da 5c |
| **D4** | Cada episódio é um bloco com duas metades; a que falta é escrita (`not reactivated — still suspended`, `by: not recorded — …`) | ausência escrita, nunca em branco |
| **D5** | Uma linha acima da tabela diz o que o operador **não** vê | a FR-007 vira regra visível, e não lacuna que pareça defeito |

## As perguntas que estavam abertas — *Decided 2026-10-01*, pela pessoa mantenedora

| # | pergunta | opções | recomendação | decisão |
|---|---|---|---|---|
| **Q1** | QR code no cadastro do segundo fator? | (a) sem QR: chave em base32 e URI em texto; (b) QR em SVG, com `eqrcode 0.2.1` (não auditada), pesquisa e auditoria próprias e `qr_svg/1` no contrato | **(a)** — uma ou duas pessoas, uma vez por concessão; dependência nova na tela da conta mais poderosa para poupar 32 caracteres | **(a)**, com a recomendação |
| **Q2** | Como confirmar suspender e reativar? | (a) digitar o slug, com as consequências listadas acima, como desenhado; (b) caixa "I understand…"; (c) só o botão, cujo rótulo diz as consequências | **(a)** — o risco real é a organização errada, a uma linha de distância; caixa se marca sem ler. **(a) ou (b) emendam `contracts/rotas-da-plataforma.md`** com o campo (`confirm_slug`) e a recusa; `suspender/3` não muda | **(a)**, com a recomendação; `rotas-da-plataforma.md` emendado |
| **Q3** | Exigir confirmação de que os códigos de recuperação foram guardados? | (a) não: aviso e link para a entrada; (b) sim: caixa e um `POST` a mais | **(a)** — confirmar não guarda código; o caminho de volta é o comando de reinício | **(b), contra a recomendação**: terceiro passo `POST /platform/setup/recovery-codes`; o segundo fator e os códigos só valem depois dele (`segundo-fator-do-operador.md`, "O fluxo de cadastro") |
| **Q4** | Mostrar no histórico quantas sessões caíram e quantos tokens foram revogados? | (a) sim, na metade da suspensão (desenhado em Acme Labs); (b) não, ficam no log de acesso | **(b)** — `organizacao/2` não devolve contagem; guardá-la no episódio é coluna nova, e é o mais perto de número da organização que a página chegaria (FR-007). Se (b), a linha sai na republicação | **(b)**, com a recomendação; a linha saiu na versão 2 |

## Medidas novas

Nenhuma. Os rótulos de razão vêm de `platform.tenant_suspension` (T014). As frases das telas são
texto de interface nos controllers.

## O que o protótipo descobriu e a implementação precisa saber

- **Q3 (b) muda o estado do cadastro**: o código TOTP aceito não habilita a entrada; habilita o
  terceiro passo. O segundo fator e os códigos passam a valer só na confirmação da guarda. A
  escolha e a razão estão em `contracts/segundo-fator-do-operador.md`, seção "O fluxo de
  cadastro"; `credenciais-do-operador.md` e `data-model.md` §1 precisam da mesma emenda (não
  feita aqui: estavam sendo editados por outro agente).
- **A recusa da caixa não pode mostrar os códigos de novo**: eles só existem em claro na
  resposta do segundo passo. A tela diz isso, e a caixa é `required` no formulário.
- **A recusa do código de cadastro não pode mostrar o segredo de novo**: `confirmar_segundo_fator/3`
  não o devolve, e reenviá-lo em campo oculto seria pôr o segredo no corpo de um segundo `POST`.
  A tela diz isso (D2).
- **`ultimo_episodio_em`** do contrato é um instante só; a coluna é rotulada `last suspended` e
  mostra o `suspended_at` do último episódio. Se o contrato quiser outro instante, a coluna muda
  de rótulo — volta ao protótipo.
- **A UI do produto usa gettext com msgid em português**; estas telas são em inglês. Se a área
  `/platform` passar por gettext, o texto inglês deste protótipo é a tradução `en` que vale.
