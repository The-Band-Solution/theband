# Avaliação de segurança — dependências do site (spec 075)

**Papel**: Security (`AGENTS.md` §13, §14.0). **Quem avaliou não escreveu o desenho.**
**Data**: 2026-10-03. **Momento**: antes do código.
**Escopo, e só ele**: (a) a dependência de build `mkdocs-static-i18n==1.3.1`; (b) o Mermaid
11.17.2 vendorizado e servido pelo site. Tudo o mais da 075 está fora (ver "O que não foi
verificado").

## O que foi verificado, e como

| Verificação | Comando / fonte | Resultado |
|---|---|---|
| chamadas perigosas no plugin i18n | `grep -rnE 'subprocess\|os\.system\|requests\|urlopen\|eval\(\|exec\(\|pickle\|yaml\.load\('` em `site-packages/mkdocs_static_i18n/` | **zero ocorrências** (EXIT=1 do grep). Prova de que o grep leu: os mesmos arquivos têm 1, 8 e 15 linhas de `import`/`from` |
| como o Material inicializa o Mermaid | `grep -oE 'securityLevel…\|startOnLoad:…'` no bundle JS do Material 9.7.7 instalado | `startOnLoad:!1` presente; **nenhum `securityLevel`** no bundle → vale o padrão do Mermaid, `strict` |
| árvore efetivamente instalada | `pip freeze` no venv do site | **30 pacotes**; `requirements-docs.txt` fixa 3 (4 com o i18n) — **~26 transitivos sem versão fixada** |
| contexto do CI que instala | `.github/workflows/docs.yml` | `permissions: contents: write`; `actions/checkout` **sem** `persist-credentials: false`; `pip install -r` e `mkdocs build` rodam no mesmo job, depois do checkout; gatilho `push` em `main` + `workflow_dispatch` (nenhum `pull_request_target`) |
| fatos de procedência (recebidos, não remedidos) | relato da pessoa que preparou o plano | i18n 1.3.1 MIT, depende só de `mkdocs>=1.5.2`; tarball do Mermaid com sha512 igual ao `dist.integrity` do registro; sha256 do `mermaid.min.js` registrado; URLs do bundle só w3.org e documentação/licença |

## Achados

| Id | Severidade | Cenário | Mitigação exigida | Teste (defeito a injetar) | Bloqueante |
|---|---|---|---|---|---|
| D1 | **Média** | Atacante que publique versão maliciosa de qualquer um dos ~26 pacotes **transitivos não fixados** (ou que substitua um artefato no PyPI) executa código no `pip install`/`mkdocs build` do job `docs`. O job tem `contents: write` e o checkout deixa o `GITHUB_TOKEN` em `.git/config` (sem `persist-credentials: false`): ele obtém escrita no repositório e na `gh-pages` — que serve também a landing da raiz. Média, e não alta: exige comprometimento de pacote de terceiro, e o job só roda em `main` | (1) `requirements-docs.txt` com **toda a árvore fixada e `--hash`**, gerado por `pip-compile --generate-hashes` (ou `pip freeze` + `pip hash`), e `pip install --require-hashes -r` no workflow; (2) `persist-credentials: false` no checkout, passando o token só ao passo de publicação. Gerar os hashes **com Python 3.13** (o do CI), não 3.14 do venv local — wheels diferem por versão | (a) alterar um caractere de um hash no arquivo → `pip install --require-hashes` tem de reprovar; (b) remover uma linha transitiva → tem de reprovar com "hashes are required for all requirements"; ver as duas reprovações e desfazer | **Não** para o site entrar; **sim** como tarefa da 075 (a dependência nova é o que aumenta a superfície) — recomendo que entre no mesmo PR |
| D2 | Baixa | Alguém substitui `vendor/mermaid-11.17.2.min.js` por um arquivo alterado (PR ou commit direto em branch): o site passa a servir JS de terceiro modificado a todo visitante | o hook de sha256 já previsto no plano, **reprovando** o build (`--strict` não basta: tem de ser exceção/erro no hook, não aviso). Vendorizar é melhor que baixar no CI: o artefato é revisável no diff, não depende de npm/unpkg no momento do build, e o hash fica sob revisão. Baixar no CI só seria equivalente se também conferisse o sha512 do registro — e acrescentaria uma borda de rede ao build sem ganho | trocar 1 byte do arquivo vendorizado → `mkdocs build` sai ≠ 0 com mensagem nomeando o hash; trocar o hash esperado no hook → idem. Mais: teste que reprova se o HTML construído citar `unpkg` (já no plano) | Não |
| D3 | Baixa | O `securityLevel` hoje é `strict` **por omissão** (verificado: o Material não o passa). Uma atualização do Material ou um `mermaid.initialize` futuro em `extra_javascript` pode afrouxá-lo (`loose` permite HTML e `click` com `javascript:` nos rótulos) sem que nada acuse. Diagramas só vêm do repositório, então o atacante precisaria de commit — por isso baixa | declarar o nível explicitamente **não é trivial** com o loader do Material (ele chama `initialize` por conta própria); o barato e verificável é a **guarda**: teste que lê o bundle do Material e o `extrahead` e reprova se aparecer `securityLevel` diferente de `strict` ou `htmlLabels`/`loose` | injetar `securityLevel:"loose"` num `extra_javascript` de teste → a guarda reprova | Não |
| D4 | Informativo | SRI e CSP no GitHub Pages | **SRI**: possível e quase grátis — `integrity="sha384-…"` + `crossorigin` no `<script>` do `main.html`; protege contra adulteração **no servidor/CDN do Pages**, não contra commit (que o D2 cobre). Recomendado, não exigido. **CSP**: o Pages não permite cabeçalho; só `<meta http-equiv="Content-Security-Policy">`, que não aceita `frame-ancestors` e, com o Material (scripts inline de configuração e Mermaid gerando `style`), exigiria `'unsafe-inline'` — valor de proteção baixo. Não recomendo agora | se adotar SRI: alterar 1 byte do JS publicado localmente e ver o navegador recusar (ou teste que confere o `integrity` contra o hash do hook — os dois têm de vir da mesma constante) | Não |
| D5 | Informativo | ADR para `mkdocs-static-i18n`? | **Na minha leitura, não exige ADR.** §16 lista mudança de arquitetura (backend novo, broker, banco, frontend separado, etc.); uma dependência Python **de build da documentação**, que não entra na release Elixir nem roda em produção, não está na lista. Exige, sim, o que §3 e a constituição pedem: justificativa escrita no `plan.md` (manutenção, segurança, compatibilidade) — o plano já a tem. Observação: o extra `material` do plugin declara `mkdocs-material<9.7.2`, e usamos 9.7.7; não instalar o extra evita o conflito, mas a compatibilidade é **não declarada pelo autor** — risco de quebra, não de segurança | — | Não |

## O que NÃO foi verificado

- **avisos publicados** para os 30 pacotes Python: não rodei `pip-audit` (nem existe gate equivalente ao `mix hex.audit` para a árvore Python — lacuna a registrar);
- **avisos/CVEs do Mermaid 11.17.2** na base do GitHub/npm: não consultei;
- o conteúdo do `mermaid.min.js` além das URLs relatadas; não li o código do i18n além do grep (o grep só acha os padrões que procurei — import dinâmico ou `importlib` não estavam na lista);
- o hook `scripts/mkdocs_hooks.py` ainda não existe: a afirmação "reprova se diferir" é do plano, não do código;
- os 10 outros passos do `docs.yml` além dos lidos, o passo de publicação na `gh-pages` e o tratamento da landing da raiz;
- o resto da spec 075 (conteúdo publicado, links, dados que o site possa expor).

Veredito: **sem achado alto; nada bloqueia o desenho.** As duas dependências são aceitáveis como
estão desenhadas (Mermaid vendorizado com hash é a escolha certa). Recomendo que **D1** entre como
tarefa da própria 075, com hashes em toda a árvore e `persist-credentials: false`, porque é a
dependência nova que amplia o que roda num job com escrita no repositório; D2 e D3 como guardas
provadas com defeito injetado; D4 e D5 como registro. A decisão de prioridade é do Product Owner.
