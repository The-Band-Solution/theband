"""
Apoio dos testes do site construído (075).

Os testes leem o site que `mkdocs build --strict` já gerou; eles não constroem. O
diretório vem de SITE_DIR (o CI usa `site`). Sem o site, o teste REPROVA: pular em
silêncio seria a família do sucesso silencioso.

Rodar:  mkdocs build --strict && SITE_DIR=site python3 -m unittest discover -s test/site
"""

import glob
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = os.path.abspath(os.environ.get("SITE_DIR", os.path.join(RAIZ, "site")))
DOCS = os.path.join(RAIZ, "docs")

sys.path.insert(0, os.path.join(RAIZ, "scripts"))


def exigir_site():
    if not os.path.isfile(os.path.join(SITE, "index.html")):
        raise AssertionError(
            f"o site construído não está em {SITE}: rode `mkdocs build --strict` antes (ou SITE_DIR)"
        )


def ler(relativo):
    with open(os.path.join(SITE, relativo), encoding="utf-8") as f:
        return f.read()


def ler_repo(relativo):
    with open(os.path.join(RAIZ, relativo), encoding="utf-8") as f:
        return f.read()


def paginas_html():
    return sorted(glob.glob(os.path.join(SITE, "**", "*.html"), recursive=True))


def sem_comentarios_html(html):
    return re.sub(r"<!--.*?-->", "", html, flags=re.S)
