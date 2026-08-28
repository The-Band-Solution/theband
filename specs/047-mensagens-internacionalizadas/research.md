# Research — 047 Mensagens internacionalizadas

Medições feitas em 2026-08-28, na main pós-sprint 023. Nenhum número aqui é
estimativa: todos saíram de grep/inspeção no repositório.

## R1 — Estado do gettext: existe, ocioso

**Decisão**: adotar o backend que já existe (`TheBandWeb.Gettext`,
`use Gettext.Backend, otp_app: :the_band`), sem tecnologia nova.

**Medido**: `priv/gettext/` contém só `errors.pot` e `en/LC_MESSAGES/errors.po`
(esqueleto do Phoenix, sem uso real); 2 arquivos referenciam gettext; nenhuma
configuração de `default_locale` em `config/`.

**Alternativas**: nenhuma considerada — a assumption da spec fixa gettext, e ele já
é dependência.

## R2 — A língua fonte é o inglês, e o msgid é a frase atual

**Decisão**: o `msgid` de cada mensagem é **o texto que a tela mostra hoje**, na
língua em que está. O `default_locale` nasce **"en"**, configurável (FR-005);
português entra como segundo idioma em `priv/gettext/pt/`, preenchido
incrementalmente com lacunas visíveis (FR-006). Quando o catálogo pt fechar, tornar
pt o padrão é trocar UMA config — que é exatamente o que FR-005 exige que seja.

**Rationale (medido)**: as 55 chamadas de `put_flash` são majoritariamente inglês
("Board not found.", "Sync started.", "Grant revoked."); as telas inteiras (Work,
Checks, notices) são inglês; 5 arquivos de teste afirmam texto de flash e dezenas
afirmam texto de tela. Com msgid = frase atual, a migração é mecânica (embrulhar em
`gettext/dgettext`), a tela **não muda um byte**, e **nenhum teste quebra**. Com
msgid em pt (a assumption original da spec), cada string migrada trocaria o idioma
da tela, quebraria os testes que a afirmam e deixaria a interface bilíngue por
sprints — o big-bang que a própria spec proíbe.

**Correção de spec registrada**: a assumption "idioma padrão: português" da spec
foi escrita como palpite (o pedido original não fixa idioma) e conflita com o dado.
Corrigida na spec no mesmo commit deste plano, com esta razão. As mensagens da 045
que já são pt ("Credenciais inválidas.") mantêm o texto exato como msgid — a
invariante de forma (FR-004) vale mais que uniformidade de língua no catálogo.

**Alternativas**: msgid em pt (rejeitada acima); chaves abstratas tipo
`auth.invalid_credentials` (rejeitada: gettext usa msgid como fallback — chave
abstrata na tela em caso de lacuna viola FR-005 "nunca chave crua na tela").

## R3 — O verificador é mix task própria no gate, não check do Credo

**Decisão**: `mix mensagens.verificar` — task que percorre os arquivos de
`lib/the_band_web/` com `Code.string_to_quoted/2`, encontra os **ralos de mensagem**
(chamadas `put_flash/3` e `put_flash!/3` com terceiro argumento literal — string ou
interpolação — fora de `gettext/dgettext/ngettext`) e reprova apontando
`arquivo:linha`. Entra em `@gates` (`lib/mix/tasks/gates.ex`) logo após o credo.

**Rationale**: não existe `.credo.exs` no projeto — um check custom do Credo
exigiria materializar a configuração default inteira só para registrá-lo, e
qualquer divergência mudaria o veredito do gate `credo --strict` que hoje roda
puro. Task própria segue o precedente de `knowledge.validate` (gate custom da
casa), com AST de verdade (não regex — a lição de [[padrao-largo-inventa-mais]]:
regex de classificação erra para o lado caro).

**Fronteira declarada (a spec exige que a definição de "mensagem" seja do
verificador)**: v1 cobre `put_flash` — o ralo por onde TODA mensagem de
erro/confirmação passa — e as funções de recusa registradas no contrato. Texto de
HEEx (títulos de notice, estados vazios) fica FORA do verificador v1 e DENTRO da
lista de pendências por tela (R7): verificar HEEx exige análise de template que
não cabe no sprint sem virar regex larga.

**Alternativas**: check custom do Credo (rejeitado acima); grep no CI (rejeitado:
regex sobre string acha falso positivo em log/exceção e perde interpolação).

## R4 — A recusa única da 045 sobrevive por construção

**Decisão**: `@mensagem_unica` em `session_controller.ex:17` vira
`dgettext("errors", "Credenciais inválidas.")` avaliada **num único ponto** — o
atributo de módulo deixa de ser possível (gettext é runtime), então a mensagem
passa a função privada `defp mensagem_unica`, chamada nos mesmos três lugares.

**Rationale**: byte-idêntica entre os casos continua provada pelo teste existente
(`login_test.exs`, `Enum.uniq` sobre as respostas) — que NÃO muda (FR-004/SC-004).
Sem tradução `en` para esse msgid, gettext devolve o msgid intacto: zero mudança
de comportamento.

## R5 — Fallback: msgid é o fallback, por design do gettext

**Decisão**: nenhum código de fallback próprio. Chave sem tradução no idioma ativo
devolve o msgid (a frase fonte) — que é texto legível por construção (R2), nunca
chave crua. `default_locale` via `config :the_band, TheBandWeb.Gettext,
default_locale: "en"` + `allowed_locales: ["en", "pt"]`.

## R6 — Lacunas: `mix gettext.extract --merge` + task de relatório

**Decisão**: extração pelo mecanismo nativo (`mix gettext.extract --merge`), e o
relatório de lacunas (FR-006) é `mix mensagens.lacunas`: lê os `.po` de cada
idioma e lista msgids com msgstr vazio, por domínio. O gate NÃO exige pt completo
(seria reprovar o incremental que a spec pede); exige que a extração esteja em dia
(`--check-up-to-date`).

## R7 — Pendências por tela, queimadas, nunca permanentes

**Decisão**: o que o verificador v1 não cobre (texto HEEx das telas) vive
enumerado em `specs/047-mensagens-internacionalizadas/pendencias.md` — uma linha
por tela, com contagem medida, marcada quando a tela for migrada em sprint futuro.
Não é allowlist de código: o verificador não a lê; é backlog nomeado, visível no
repositório.

**Rationale**: a spec proíbe lista de exceções permanente; uma allowlist que o
gate consome tende a virar exatamente isso. Pendência como documento de backlog
mantém o gate estrito no que cobre e a dívida visível no que não cobre.
