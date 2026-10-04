# Implementation Plan: o site de desenvolvedores

**Branch**: `feature/1267-site-de-desenvolvedores` | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

## Summary

O tema do MkDocs passa a ser o de theband.dev, com o protótipo aprovado como régua; o site é construído
em PT (padrão) e EN; o Mermaid sai do CDN e passa a ser servido pelo site; a 404 vai para a raiz da
`gh-pages`; todo PR constrói o site em modo estrito e varre os links.

## Technical Context

**Language/Version**: Python 3.13 no CI (3.14 local), só para o build da documentação.
**Dependencies**: `mkdocs==1.6.1`, `mkdocs-material==9.7.7` (as de hoje) e **uma nova,
`mkdocs-static-i18n==1.3.1`**. Mermaid 11.17.2 vendorizado (código de terceiro servido, não dependência
de build). **Storage**: nenhum. **Testing**: `unittest` da biblioteca padrão sobre o site construído, em
`test/site/`. **Project Type**: site estático, publicado em `gh-pages/developers/`.

## Constitution Check

| princípio | como cumpre |
|---|---|
| I, II, IV, IX | não toca ontologia nem base; os termos de domínio ficam como na ontologia também em EN (traducao.md) |
| III | o site diz de onde veio: commit do build observado, versão em produção ausente, spec declarada |
| V | sem dado por tenant; site estático |
| VI | spec, avaliação de segurança, plano, tarefas, issues e sprint backlog antes do código; a tela é o protótipo aprovado |
| VII | `mkdocs build --strict` e a varredura no CI de todo PR; cada guarda com o defeito injetado |
| VIII | uma dependência nova e quatro estruturas novas, justificadas abaixo |
| X | cada parcial faz uma coisa: topo, faixa do build, rodapé, home, 404 |
| XI | ausência nomeada: tradução pendente, commit não obtível, busca sem JS, diagrama sem script |

### A dependência nova (§3, VIII)

`mkdocs-static-i18n==1.3.1`. Comparação em [research.md](research.md), R1.

| pergunta | resposta |
|---|---|
| qual problema concreto resolve? | o site inteiro em dois idiomas, com o seletor levando **à mesma página** no outro idioma, e a página sem tradução **servida com a ausência nomeada** em vez de 404 |
| existe agora? | sim: decisão da pessoa mantenedora de 2026-10-03, o site inteiro em PT e EN |
| o que fica pior? | uma dependência a mais no build; o `nav` passa a ter `nav_translations`; o extra `material` do plugin declara `<9.7.2`, então subir o Material exige conferir o plugin; e o build dobra de tempo |

**Manutenção**: três versões em 21 meses, a última em 2026-02. **Licença**: MIT. **Segurança**: uma
dependência transitiva só (`mkdocs`, que já temos); roda só no build, não chega ao navegador. Fixada com
`==` em `requirements-docs.txt`, como as outras.

**ADR: não exige.** A lista do §16 trata da arquitetura do produto (monólito, banco, broker, contratos
públicos da aplicação). Uma ferramenta do build da documentação não está nela, e não muda nenhuma
fronteira do sistema. Exigiria se o MkDocs fosse trocado por outro gerador, o que mudaria o pipeline de
publicação; não é o caso. A própria #1267 já registrava essa leitura.

### Estruturas novas (VIII)

| estrutura | problema concreto | agora? | o que piora |
|---|---|---|---|
| `overrides/` (`custom_dir` do Material) com cinco parciais | o protótipo exige topo, faixa, rodapé, home e 404 que o tema padrão não tem | sim | cada atualização do Material pode mudar os blocos sobrescritos; o build estrito e os testes o pegam |
| `docs/assets/stylesheets/theband.css` | os tokens de theband.dev, declarados uma vez (M1) | sim | é CSS próprio; cada bloco leva a razão (§11.1) |
| Mermaid vendorizado + hash no hook | o AC11 recusa o CDN, e arquivo de terceiro sem conferência é substituível em silêncio | sim | 3,5 MB no repositório; trocar de versão é tarefa com hash |
| hooks novos em `scripts/mkdocs_hooks.py` | contagens do `nav`, commit do build, marca de tradução pendente e o hash só existem no build | sim | o arquivo cresce; cada função faz uma coisa e tem teste |

## Desenho

```text
mkdocs.yml            theme.custom_dir: overrides · font: false · extra_css · plugins: search, i18n
                      validation.nav.omitted_files: warn · not_in_nav: protótipos
overrides/
  main.html           extrahead: Mermaid local + estilo do estado sem JS · announce: a faixa do build
  partials/header.html  M3: The Band · documentação técnica · busca · O produto · GitHub · Entrar · idioma
  partials/footer.html  M5 e M9: rodapé de theband.dev, editar no GitHub, anterior e próxima
  home.html           1.1–1.5: assinatura, pauta, I, II (contagens do nav), III (funcionalidades)
  404.html            5.1: o caminho pedido, as duas variantes, os links de saída
  dados/funcionalidades.yml  as seis funcionalidades da seção III
docs/assets/stylesheets/theband.css     tokens com a data da cópia, mapeados em --md-*
docs/assets/javascripts/vendor/mermaid-11.17.2.min.js
docs/assets/javascripts/theband.js      estados sem script (5.3, 5.4), atalho "/"
scripts/mkdocs_hooks.py                 + hash do Mermaid, commit do build, contagens, home, tradução pendente
scripts/verificar_links_do_site.py      a varredura de AC7
test/site/                              unittest sobre o site construído
.github/workflows/docs-pr.yml           build estrito + varredura + testes em todo PR, sem publicar
.github/workflows/docs.yml              copia site/404.html para a raiz; o guarda confere o 404.html
```

A forma de cada hook, o que devolve e o que não expõe está em
[contracts/build-do-site.md](contracts/build-do-site.md).

## Riscos

| risco | mitigação |
|---|---|
| o plugin declara compatibilidade só até Material 9.7.1 | build estrito no CI de todo PR; versão fixada |
| a 404 da raiz passa a ser escrita pelo workflow | o guarda confere os quatro arquivos depois da cópia; a cópia escreve só `404.html` |
| a avaliação de segurança tirar páginas do site | FR-011; a tarefa vem antes da publicação |
| o Material mudar o loader do Mermaid | teste que reprova se o HTML construído citar `unpkg` |
