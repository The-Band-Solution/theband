# Tasks: o site de desenvolvedores

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md),
[contracts/build-do-site.md](contracts/build-do-site.md), [seguranca.md](seguranca.md),
[traducao.md](traducao.md), o protótipo aprovado em
[`docs/site-developers/prototipo/`](../../docs/site-developers/prototipo/README.md) (régua do `PROMPT.md`, seção 3)

**Testes**: `python3 -m unittest discover -s test/site` sobre o site construído em `site/`, mais o código
de saída de `mkdocs build --strict` e de `scripts/verificar_links_do_site.py`. Cada guarda é vista
reprovando com o defeito injetado antes de ser aceita.

**A base** (este sprint) são as fases 1 a 4. A fase 5 é o resto da régua do protótipo, e a fase 6 são os
lotes de tradução.

## Fase 1: Fundação

- [ ] T001 O build estrito volta a passar
  - **Pronta quando**: R5
  - **Descrição**: os quatro links `../../specs/` de `docs/sprints/036-papeis-do-banco/sprint-backlog.md`
    e `037-papel-de-administrador/sprint-backlog.md` ganham o `../` que falta.
  - **Feita quando**: `mkdocs build --strict` sai 0 com o `mkdocs.yml` de hoje
  - **Teste**: o próprio build. **Defeito a injetar**: voltar um dos links; o build sai 1.

- [ ] T002 Página fora da navegação reprova
  - **Pronta quando**: T001; FR-008; Q7
  - **Descrição**: `validation.nav.omitted_files: warn` e `not_in_nav` para `site-developers/prototipo/`
    e para o que [seguranca.md](seguranca.md) mandar tirar da navegação. As 51 páginas omitidas entram
    no `nav`, cada uma na seção dela.
  - **Feita quando**: o build estrito sai 0, e nenhuma página fica fora do `nav` sem estar em `not_in_nav`
  - **Teste**: o build. **Defeito a injetar**: um `.md` novo em `docs/backlog/` fora do `nav`; sai 1.

- [ ] T003 O site é construído e varrido em todo PR
  - **Pronta quando**: T001; FR-009; [seguranca.md](seguranca.md)
  - **Descrição**:
    - `scripts/verificar_links_do_site.py`, só biblioteca padrão: lê `site/`, resolve cada `href` e `src`
      interno contra o disco e sai 1 com a lista do que falta;
    - `.github/workflows/docs-pr.yml`: `pull_request`, `permissions: contents: read`, actions por SHA,
      sem segredo; instala `requirements-docs.txt`, roda o build estrito, a varredura e os testes.
  - **Feita quando**: o job roda no PR e o veredito é o código de saída de cada passo, sem pipe
  - **Teste**: `test/site/test_verificar_links.py`. **Defeito a injetar**: um `href` para página
    inexistente num HTML de fixture; o script sai 1.

- [ ] T004 Os dois idiomas, com o seletor
  - **Pronta quando**: plan.md, a dependência nova; [seguranca.md](seguranca.md)
  - **Descrição**: `mkdocs-static-i18n==1.3.1` em `requirements-docs.txt`; o plugin com
    `docs_structure: suffix`, PT padrão, EN com `nav_translations` dos títulos de seção; o seletor de
    idioma no topo, levando à mesma página.
  - **Feita quando**: `site/en/` existe; o seletor de uma página PT aponta para a mesma página em EN
  - **Teste**: `test/site/test_idiomas.py`. **Defeito a injetar**: tirar o idioma `en`; o teste reprova.

- [ ] T005 A página sem tradução diz que não tem
  - **Pronta quando**: T004; contrato, `on_page_markdown` e `on_post_build`
  - **Descrição**: no build `en`, a página servida do PT ganha a marca de ausente "translation pending" e
    a frase; o build escreve a contagem e `traducao-pendente.txt`; com `extra.traducao.exigir: true`,
    reprova. `.en.md` sem o PT reprova sempre.
  - **Feita quando**: uma página sem `.en.md` mostra a marca em `/en/`; a página com `.en.md` não mostra
  - **Teste**: `test/site/test_idiomas.py`. **Defeito a injetar**: o hook sem a marca; o teste reprova.

- [ ] T006 O Mermaid servido pelo site, com o hash conferido
  - **Pronta quando**: R2; [seguranca.md](seguranca.md)
  - **Descrição**: `docs/assets/javascripts/vendor/mermaid-11.17.2.min.js`, a licença ao lado; o hook
    confere o sha256 em `on_config`; o `<head>` o carrega antes do bundle do Material.
  - **Feita quando**: nenhuma página construída cita `unpkg` nem outro domínio em `src`
  - **Teste**: `test/site/test_terceiros.py`. **Defeitos a injetar**: um byte a mais no arquivo (o build
    reprova com os dois hashes, por erro e não aviso, D2); tirar o script do `<head>` (o HTML passa a
    depender do `unpkg`, e o teste reprova); `securityLevel: "loose"` em script do site (D3).

## Fase 2: US1 — a identidade e o caminho de volta (P1)

- [ ] T007 [US1] Os tokens de theband.dev, uma vez, com a data da cópia
  - **Pronta quando**: T004; M1, M2, M6
  - **Descrição**: `docs/assets/stylesheets/theband.css`: os nove tokens e `info`, nos dois temas, com o
    comentário de origem e data; as variáveis `--md-*` e `--md-mermaid-*` apontadas para eles;
    `font: false`; títulos em serifa, corpo humanista, mono com `tabular-nums`; as quatro marcas.
  - **Feita quando**: os valores do CSS publicado são os de `gh-pages:index.html`
  - **Teste**: `test/site/test_tokens.py`, contra `test/site/fixtures/tokens-da-landing.css` (a cópia
    datada). **Defeito a injetar**: trocar um hexadecimal; o teste reprova.

- [ ] T008 [US1] O topo e a faixa do build
  - **Pronta quando**: T007; M3, M4; contrato, `on_config`
  - **Descrição**: `overrides/partials/header.html` na ordem de M3, com os botões de 44 px abaixo de
    46 rem; a faixa no bloco `announce`: commit e data observados, versão em produção ausente.
  - **Feita quando**: três páginas têm os quatro destinos de AC3; sem `.git`, a faixa diz "não informado"
  - **Teste**: `test/site/test_moldura.py`. **Defeito a injetar**: o hook devolvendo commit `None`; a
    faixa precisa dizer "não informado", e nunca ficar vazia.

- [ ] T009 [US1] O rodapé, editar no GitHub, anterior e próxima
  - **Pronta quando**: T007; M5, M9
  - **Descrição**: `overrides/partials/footer.html`.
  - **Feita quando**: o rodapé tem os quatro links, a base científica e a linha de como a página é feita
  - **Teste**: `test_moldura.py`. **Defeito a injetar**: tirar o link da landing; o teste reprova.

- [ ] T010 [US1] Larguras e tabelas
  - **Pronta quando**: T007; M7, M8
  - **Descrição**: uma coluna por padrão, navegação a partir de 60 rem, sumário a partir de 76 rem,
    texto até 44 rem; tabela rola no próprio quadro; com mais de três colunas, empilha abaixo de 40 rem
    com o nome da coluna (o `data-label` é posto pelo `theband.js`).
  - **Feita quando**: as quatro páginas de AC4 não rolam na horizontal a 360 px
  - **Teste**: `test_moldura.py` confere as regras no CSS e o script; a captura a 360 px é do QA.
    **Defeito a injetar**: tirar o `overflow-x` do quadro da tabela.

- [ ] T011 [US1] A home
  - **Pronta quando**: T008; 1.1–1.5; contrato, `on_nav` e `on_page_context`
  - **Descrição**: `overrides/home.html` e `mkdocs-dados/funcionalidades.yml`; as contagens vêm do
    `nav` no build.
  - **Feita quando**: as treze seções aparecem com a contagem real, e a seção III lista as seis
    funcionalidades com as marcas
  - **Teste**: `test/site/test_home.py`. **Defeito a injetar**: a contagem fixa no template; o teste,
    que conta o `nav`, reprova.

- [ ] T012 [US1] Sem JavaScript e sem o script do Mermaid
  - **Pronta quando**: T006; 5.3, 5.4; FR-010
  - **Descrição**: `<noscript>` no topo com "A busca precisa de JavaScript" e a marca; o `theband.js` põe
    o aviso "diagrama não desenhado" e mostra o código quando o Mermaid não está definido; o atalho `/`.
  - **Feita quando**: o HTML tem o `<noscript>`; o fonte do diagrama continua no HTML como texto
  - **Teste**: `test_moldura.py`. **Defeito a injetar**: tirar o `<noscript>`.

- [ ] T013 [US3] A 404, na raiz e em /developers/
  - **Pronta quando**: T008; 5.1; FR-007; [seguranca.md](seguranca.md)
  - **Descrição**: `overrides/404.html`; o caminho pedido só por `textContent`, de `pathname`, com
    `decodeURIComponent` em `try` e limite de 200; links fixos; meta CSP com o hash do script; texto
    neutro sem JS (E6). O `docs.yml` copia **só** `site/404.html` para a raiz, e o guarda confere
    `404.html` (existe e é igual ao construído) e que `developers/seguranca` não existe, além dos três
    de hoje (E2, E7). **Bloqueante** da publicação.
  - **Feita quando**: `site/404.html` tem as duas variantes e os links de saída; o guarda tem as quatro
    conferências
  - **Teste**: `test/site/test_404.py`, inclusive que o guarda do `docs.yml` confere os quatro arquivos.
    **Defeitos a injetar**: `innerHTML` no lugar de `textContent`; o hash da CSP diferente do script.

## Fase 3: US3 — as funcionalidades novas (P1)

Cada página segue D14 e as regras de `docs/funcionalidades/README.md`: só o que está na tela; rótulos
em inglês, texto em português; nenhum número inventado; o link para a spec vai ao GitHub. O que
[seguranca.md](seguranca.md) proíbe dizer não entra.

- [ ] T014 [US3] A página da 064, segredo em repouso
- [ ] T015 [US3] A página da 070, suspender e reativar uma organização
- [ ] T016 [US3] A página da 071, os papéis do banco (em Operação, sem tela)
- [ ] T017 [US3] A página da 072, promover e rebaixar administradores (tela 6)
- [ ] T018 [US3] A página da 073, a rede de revisão — **só depois do merge do PR #1228** (E5)
- [ ] T019 [US3] A página da 074, entrar e sair vistos por quem opera — **só depois do merge do PR #1266** (E5)
  - **Pronta quando** (T014–T019): T002; a spec; a tela em `lib/`; [seguranca.md](seguranca.md), E5. Até
    o merge, a home lista 073 e 074 com "entra quando o PR for mergeado".
  - **Feita quando**: recibo, as três seções, o link para a spec; a página está no `nav`, e a seção
    `funcionalidades/README.md` (5.2) lista os grupos com "sem página ainda" onde couber
  - **Teste**: `test/site/test_funcionalidades.py`: as páginas existem, têm as três seções, nenhum link
    para `seguranca`, `tasks.md` ou `research.md`, e nenhum dos termos proibidos de E5 (`THE_BAND_`,
    `#1229`, `#1221`, `em aberto`, `sem limite`, `por IP`, `tentativas`, `cipher`, `AES`, nomes de papel
    do banco). **Defeitos a injetar**: um link para `specs/072-…/seguranca.md`; um termo proibido. Cada
    página passa por revisão do `security` antes do merge.

## Fase 4: as exigências da avaliação de segurança

- [ ] T020 A seção Segurança e os arquivos de evidência fora do site (E1, E3, E4)
  - **Pronta quando**: [seguranca.md](seguranca.md)
  - **Descrição**: `exclude_docs` com `seguranca/`, `producao/prototipo-fila-parada/seguranca.md` e as
    extensões `*.txt`, `*.log`, `*.sql`, `*.dump`, `*.env*`; a seção sai do `nav`; o hook leva ao GitHub
    os links para página excluída. **Bloqueante** da publicação.
  - **Feita quando**: `site/seguranca/` não existe, e o índice de busca não cita os inventários
  - **Teste**: `test/site/test_exposicao.py`, que antes confere que o índice tem entradas.
    **Defeito a injetar**: tirar `seguranca/` do `exclude_docs`; o teste reprova.

- [ ] T021 O build da documentação endurecido (D1, E8)
  - **Pronta quando**: [seguranca.md](seguranca.md)
  - **Descrição**: `requirements-docs.txt` com todas as dependências e `--hash`, gerado para Python
    3.13; `pip install --require-hashes`; `persist-credentials: false` e `timeout-minutes` nos dois
    workflows de documentação.
  - **Feita quando**: o CI instala com `--require-hashes`
  - **Teste**: `test/site/test_workflows.py`: nenhum `pull_request_target`, nenhum `secrets.` e nenhum
    `contents: write` no `docs-pr.yml`, todo `uses:` com SHA de 40, `persist-credentials: false`.
    **Defeito a injetar**: trocar o gatilho por `pull_request_target`.

## Fase 5: o resto da régua do protótipo (depois da base)

- [ ] T022 O recibo das ADRs (2.2), lido da seção *Status*
- [ ] T023 O recibo dos modelos (3.1, 3.3), lido do comentário `DERIVADO de …`
- [ ] T024 "Ver como tabela" e "ver o código Mermaid" em toda figura (3.4)
- [ ] T025 A busca diz o alcance e marca o que está fora da navegação (4.2, 4.3)
- [ ] T026 A conferência do QA, item a item, com captura (AC1, AC4, AC5, AC9)

## Fase 6: as traduções, por lote ([traducao.md](traducao.md))

- [ ] T027 L01 entrada e arquitetura (20)
- [ ] T028 L02 ontologias e decisões (27), com o gerador EN das páginas geradas
- [ ] T029 L03 modelos (30)
- [ ] T030 L04 operação e releases (24)
- [ ] T031 L05 backlog, parte 1 (25)
- [ ] T032 L06 backlog, parte 2 (20)
- [ ] T033 L07 sprints, parte 1 (25)
- [ ] T034 L08 sprints, parte 2 (25)
- [ ] T035 L09 sprints, parte 3 (25), e `extra.traducao.exigir: true`
  - **Feita quando** (cada lote): build estrito 0; a contagem de pendentes cai o número do lote;
    varredura 0 nos dois idiomas
