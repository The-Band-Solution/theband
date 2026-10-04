# 075 — Avaliação de segurança da exposição, do 404 e do CI (antes do código)

Papel: Security (`AGENTS.md` §13, §14.0). Quem avalia não escreveu o desenho.
Escopo: (a) conteúdo público publicado pelo site; (b) `404.html` na raiz da `gh-pages`;
(c) o workflow novo `docs-pr.yml`. **Fora do escopo**: o resto da spec 075, o tema, o nav.
Data: 2026-10-03. Formato: o de `specs/072-papel-de-administrador/seguranca.md`.

## O que foi medido (e como)

| Fato | Comando | Resultado |
|---|---|---|
| visibilidade do repositório | `gh repo view The-Band-Solution/theband --json visibility` | `PUBLIC` |
| o inventário de segurança **já está no ar** | `curl -o /dev/null -w %{http_code} https://theband.dev/developers/seguranca/2026-09-24-inventario-antes-do-mcp/` | `200` |
| arquivo não-Markdown de `docs/` também é publicado | mesmo `curl` em `developers/seguranca/varreduras/varredura-20260928T193022.959915Z.txt` | `200` |
| índice de busca público | `curl … developers/search/search_index.json` | `200` |
| a varredura publicada carrega valor de segredo? | `grep -cE "[A-Za-z0-9_-]{40,}"` no `.txt` | `0` — só local (tabela, linha, deslocamento) e nome do banco `the_band_dev` |
| inventários com achado descrito como aberto | `grep -lE "em aberto\|ABERTO\|não corrigid" docs/seguranca/*.md` | 2 arquivos |
| endereço de origem em `docs/` | `grep -ohE` por IPv4 | `5.189.161.85` (é o próprio host do `sslip.io` de produção, já público pelo nome) |
| issues `security` abertas | `gh issue list --label security --state open` | 50 (limite da listagem); entre elas #1229 (sem limite por IP em `POST /session`) e #1221 |
| `docs.yml` hoje | leitura | `contents: write`, actions por SHA, guarda de `CNAME`, `index.html`, `developers/index.html`, `docs/index.html`; nada sobre `404.html` |

**Consequência para a leitura dos achados**: como o repositório é público, `docs/seguranca/`
já é legível no GitHub, e já está publicado em `theband.dev/developers/` hoje. Excluir do
build **não desfaz exposição** — reduz amplificação (indexação por buscador num domínio do
produto, busca interna do site, link a partir de páginas para quem usa). Isso define a
severidade abaixo como **Média**, e não Alta. Tirar os inventários do repositório público é
outra decisão, e não é desta spec.

## Achados

| Id | Severidade | Cenário | Mitigação exigida | Teste (defeito a injetar) | Bloqueante |
|---|---|---|---|---|---|
| E1 | Média | quem procura "theband" num buscador chega a `theband.dev/developers/seguranca/…` e lê, num domínio do produto e indexado, o inventário de achados com arquivo e linha — inclusive os 2 que se descrevem como abertos. O tema novo e a busca aumentam o alcance | `exclude_docs` no `mkdocs.yml` com `seguranca/` (inclui `varreduras/`) e `producao/prototipo-fila-parada/seguranca.md`; nenhuma página publicada linka para eles (o `--strict` acusa link para página excluída — é o que se quer) | pós-build no `docs-pr.yml`: `site/seguranca/` não existe, `site/producao/prototipo-fila-parada/seguranca*` não existe, e `search_index.json` não contém `docs/seguranca` nem os títulos dos inventários; o teste conta antes que `search_index.json` tem > 0 entradas. Defeito: tirar a linha do `exclude_docs` e ver reprovar | **sim** — antes de publicar o tema novo |
| E2 | Média | o deploy novo **não apaga** o que já foi publicado se a escrita for incremental; e as páginas antigas continuam em cache de buscador | o passo `rm -rf publicacao/developers` (linha 69 de `docs.yml`) **permanece**; depois do primeiro deploy, conferir `curl` = `404` nas três URLs da tabela acima e registrar a evidência | guarda no `docs.yml`: `test ! -e publicacao/developers/seguranca` | sim (o guarda); a remoção do índice do buscador não é controlável pelo repositório |
| E3 | Média | `mkdocs` copia todo arquivo não-Markdown de `docs/` (o `.txt` da varredura saiu assim). Arquivo de evidência futuro — dump, log, saída de varredura — entra no ar sem ninguém decidir | política explícita: `exclude_docs` cobre `*.txt`, `*.log`, `*.sql`, `*.dump`, `*.env*` em qualquer pasta; o que for público é listado | pós-build: nenhum arquivo em `site/` com essas extensões. Defeito: criar `docs/x.log` e ver reprovar | não |
| E4 | Baixa | 53 páginas fora do nav são publicadas e achadas pela busca: "fora do nav" é lido como "não publicado", e não é | cada página fora do nav ou é excluída, ou é declarada pública numa lista revisada (`not_in_nav` do mkdocs serve de lista, e é o que se revisa) | pós-build: conjunto publicado ⊆ nav ∪ lista declarada | não |
| E5 | Alta | página de funcionalidade de 064/070/071/072/073/074 escrita "para quem usa" descreve o que **ainda não** está protegido, ou o mecanismo da proteção — vira mapa de ataque, no domínio do produto, com link para a spec | as páginas **não dizem**: (1) achado ou issue `security` em aberto, nem o número dela (#1229, #1221…), nem "ainda não há limite de…"; (2) limite numérico, janela ou contagem de tentativas, nem o que não é limitado (por IP, por identificador); (3) nome de variável de ambiente, de chave, de papel do banco (071), de rótulo de cipher, de algoritmo e de rota interna; (4) o que é registrado, o que **não** é registrado, retenção e o destino dos traces (074); (5) como suspender/promover se faz por fora da tela (070, 072); (6) qualquer coisa de 073 e 074 enquanto o PR estiver aberto — página só depois do merge em `development`, dizendo o que existe, não o que se planeja. Podem dizer: o que a pessoa vê, o que pode fazer, quem pode, e o link para a spec (que já é pública no repositório) | teste de termos proibidos sobre `site/funcionalidades/**`: `THE_BAND_`, `#1229`, `#1221`, `em aberto`, `sem limite`, `por IP`, `tentativas`, `cipher`, `AES`, `the_band_app`/nomes de papel do 071. Defeito: inserir um termo numa página e ver reprovar. Mais revisão por Security de cada página antes do merge | **sim** |
| E6 | Média | o 404 da raiz reflete `location.pathname`. Caminho `/developers/%3Cimg%20src=x%20onerror=alert(1)%3E` com `innerHTML` executa script em `theband.dev` (mesma origem da página do produto em `/` e `/docs/`) | (1) o caminho entra **só** por `textContent` (nunca `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, `eval`, atributo `href`/`src`); (2) `decodeURIComponent` dentro de `try` — URI malformada mostra o caminho cru, não quebra a página; (3) limite de 200 caracteres, truncado com reticências; (4) os links da página são **fixos** (`/developers/` e `/`) — o caminho pedido nunca vira link, nem `meta refresh`, nem `location.assign` (redirecionamento a partir do caminho é redirect aberto); (5) só `pathname` — nunca `search` nem `hash`; (6) variante sem JS mostra texto neutro e funciona; (7) GitHub Pages não deixa mandar cabeçalho, então a página leva `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'sha256-…'; style-src 'self' 'unsafe-inline'; img-src 'self'">` com o hash do script inline (ou script externo com caminho **absoluto**, porque o 404 é servido em qualquer profundidade) | teste unitário sobre o `site/404.html` construído: não contém `innerHTML`/`outerHTML`/`insertAdjacentHTML`/`document.write`/`eval(`/`location.search`/`location.hash`/`http-equiv="refresh"`; contém `textContent` e a meta CSP; o hash da CSP confere com o script. Defeito: trocar `textContent` por `innerHTML` e ver reprovar. Verificação manual pós-deploy com o caminho hostil acima: o texto aparece literal | **sim** |
| E7 | Média | o `404.html` na raiz passa a valer para **todo** `theband.dev`, inclusive `/docs/` e a página do produto; um deploy que o perde ou o troca por outro conteúdo não acusa nada | guarda no `docs.yml`, junto aos que já existem: `test -f publicacao/404.html` e `cmp site/404.html publicacao/404.html`; o passo copia **apenas** esse arquivo para a raiz — nunca `cp -r site/* publicacao/` — e o guarda do `index.html` da raiz continua depois da cópia | injetar: apagar a cópia no passo e ver o guarda abortar; injetar: copiar o `index.html` do site para a raiz e ver o guarda (por `cmp` com o `index.html` anterior, ou por marcador do produto) abortar | sim (o guarda) |
| E8 | Baixa | `docs-pr.yml` roda código controlado pelo PR (plugins do mkdocs, `pip install`, o próprio Python de teste) | como desenhado: `pull_request` (nunca `pull_request_target`), `permissions: contents: read` no topo, actions por SHA, nenhum `secrets.*`; acrescentar `actions/checkout` com `persist-credentials: false`, `timeout-minutes`, dependências por `requirements` com versão fixa; a varredura de links é **offline** (só links internos ao `site/`) — um verificador que sai para a rede busca URL escolhida pelo autor do PR; sem `upload-artifact` consumido por `workflow_run` com escrita | teste de workflow (grep, no próprio CI ou em teste): `pull_request_target` ausente, `secrets.` ausente, `contents: write` ausente, todo `uses:` com SHA de 40. Defeito: trocar o gatilho e ver reprovar | não |
| E9 | Informativo | a página mostra commit curto e data do build, e "versão em produção: não informada" | aceitável: commit e data já são públicos no repositório. **Não** buscar a versão de produção durante o build (seria chamada de saída do CI para produção) | — | não |
| E10 | Informativo | `docs/` contém o IP `5.189.161.85` | é o host do endereço `sslip.io` de produção, público pelo próprio nome; não é segredo. Registrado para não ser reaberto | — | não |

## O que NÃO verifiquei

- o conteúdo das 229 páginas de `docs/` fora de `docs/seguranca/` e do protótipo — pode haver
  runbook, procedimento de backup ou descrição de defeito aberto fora dessas pastas (busquei
  só IPv4 e `sslip.io` em todo `docs/`);
- se os 2 achados descritos como "em aberto" nos inventários seguem abertos hoje;
- o `mkdocs.yml` do tema novo, os plugins e suas versões (não há ainda);
- o texto das páginas de 064/070–074 (não existem ainda) — E5 é requisito, não leitura;
- se buscadores já indexaram `developers/seguranca/` (não consultei buscador);
- a página do produto em `/` e `/docs/` (mesma origem do 404), e se ela tem CSP;
- as outras issues `security` além das 50 listadas;
- `mix gates` não foi rodado: esta avaliação não mudou código.

## Decisões da pessoa mantenedora

1. **os inventários de `docs/seguranca/` continuam no repositório público?** Excluí-los do site
   (E1) é o que esta spec pode fazer; o repositório público continua mostrando-os. Se a
   resposta for não, é tarefa separada, com histórico do git em conta;
2. **o que fazer com o que já está publicado e indexado** (E2): o deploy apaga do site;
   pedir remoção ao buscador é ação fora do repositório.

Veredito: **pode seguir para o código com quatro condições bloqueantes** — E1 (`exclude_docs`
com teste pós-build), E2/E7 (guardas no `docs.yml`, incluindo `404.html` e ausência de
`developers/seguranca`), E5 (as páginas de funcionalidade não descrevem defeito aberto nem
mecanismo, e 073/074 só depois do merge) e E6 (404 por `textContent`, limite, links fixos,
meta CSP). O CI (E8) está bem desenhado; as adições são endurecimento. Duas decisões são da
pessoa mantenedora (acima). Esta é recomendação; a aceitação é do Product Owner.
