"""
Hook de build do MkDocs — os links que saem de `docs/` viram URL do GitHub.

## O problema

A documentação deste repositório é escrita para ser lida **no GitHub**, e aponta
para artefatos que ficam fora de `docs/`: as 58 pastas de `specs/`, os YAML de
`priv/knowledge_base/`, os `scripts/`, o `AGENTS.md`. São 118 links, e os
caminhos relativos deles estão corretos a partir da raiz do repositório.

O site publica só `docs/`. Sem este hook, cada um desses links vira 404 — e com
`--strict` o build inteiro reprova.

## Por que hook, e não mudar os arquivos

Reescrever os 118 links como URL absoluta no fonte quebraria a leitura offline e
o `git grep`, e amarraria os documentos a um domínio. O hook resolve no
**momento do build**: o fonte continua relativo e navegável no GitHub, e o site
recebe o link absoluto.

## Por que não incluir `specs/` no site

São 58 features × até 8 arquivos de spec-kit. Elas afogariam uma navegação que
existe para responder perguntas, e o público delas é quem está implementando —
que já está no repositório.
"""

import os
import posixpath
import re

BLOB = "https://github.com/The-Band-Solution/theband/blob/development/"

# Só o que casa com link markdown de caminho relativo. Âncora e query preservadas.
LINK = re.compile(r"(\[[^\]]*\]\()([^)\s]+?)((?:#[^)\s]*)?(?:\s+\"[^\"]*\")?\))")


def on_page_markdown(markdown, page, config, files, **kwargs):
    """Reescreve, nesta página, os links relativos que escapam de `docs_dir`."""
    dir_no_repo = posixpath.dirname("docs/" + page.file.src_uri)

    def reescreve(m):
        prefixo, alvo, sufixo = m.group(1), m.group(2), m.group(3)

        if alvo.startswith(("http://", "https://", "mailto:", "#", "/")):
            return m.group(0)

        # Caminho do alvo a partir da raiz do repositório.
        no_repo = posixpath.normpath(posixpath.join(dir_no_repo, alvo))

        # Subiu acima da raiz: não é para este hook resolver, e o build estrito
        # continua reclamando — que é o comportamento certo.
        if no_repo.startswith(".."):
            return m.group(0)

        # Continua dentro do site: o MkDocs resolve, e mexer aqui quebraria.
        if no_repo == "docs" or no_repo.startswith("docs/"):
            return m.group(0)

        return prefixo + BLOB + no_repo + sufixo

    return LINK.sub(reescreve, markdown)
