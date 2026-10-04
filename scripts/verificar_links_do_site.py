"""
A varredura de links do site construído (075, AC7; T003).

O `mkdocs build --strict` confere os links do Markdown. Este script confere o que ele
não vê: o HTML final, depois dos templates, do plugin de idiomas e do hook. Cada `href`
e `src` interno precisa apontar para um arquivo que existe em `site/`.

Offline de propósito (avaliação de segurança da 075, E8): link para outro domínio não
é seguido nem contado. Um verificador que sai para a rede buscaria, no CI, uma URL
escolhida por quem escreveu o PR.

Uso:  python3 scripts/verificar_links_do_site.py site
Sai 0 sem link quebrado; 1 com a lista; 2 se o diretório não existe.
"""

import os
import sys
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit

# O prefixo sob o qual o site é servido (site_url). Link absoluto para ele é interno.
PREFIXO = "/developers/"
ATRIBUTOS = {"a": "href", "link": "href", "script": "src", "img": "src", "iframe": "src", "source": "src"}


class Coletor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.alvos = []

    def handle_starttag(self, tag, attrs):
        nome = ATRIBUTOS.get(tag)
        if not nome:
            return
        for chave, valor in attrs:
            if chave == nome and valor:
                self.alvos.append(valor)


def _interno(alvo):
    partes = urlsplit(alvo)
    if partes.scheme or partes.netloc:
        return None
    if alvo.startswith(("#", "mailto:", "javascript:", "data:")):
        return None
    return unquote(partes.path)


def resolver(raiz, arquivo_html, caminho):
    """O arquivo em disco a que o caminho leva, ou None se não leva a nenhum."""
    if caminho.startswith("/"):
        if not caminho.startswith(PREFIXO):
            return "fora"  # outro site em theband.dev: não é deste
        alvo = os.path.join(raiz, caminho[len(PREFIXO):])
    else:
        alvo = os.path.join(os.path.dirname(arquivo_html), caminho)
    alvo = os.path.normpath(alvo)
    candidatos = [alvo, os.path.join(alvo, "index.html")]
    for c in candidatos:
        if os.path.isfile(c):
            return c
    return None


def verificar(raiz):
    quebrados = []
    paginas = 0
    for pasta, _, arquivos in os.walk(raiz):
        for nome in arquivos:
            if not nome.endswith(".html"):
                continue
            arquivo = os.path.join(pasta, nome)
            # A 404 é servida em qualquer caminho, e por isso usa URLs absolutas:
            # é conferida como as outras, a partir da raiz do site.
            paginas += 1
            coletor = Coletor()
            with open(arquivo, encoding="utf-8") as f:
                coletor.feed(f.read())
            for alvo in coletor.alvos:
                caminho = _interno(alvo)
                if caminho is None or caminho == "":
                    continue
                if resolver(raiz, arquivo, caminho) is None:
                    quebrados.append((os.path.relpath(arquivo, raiz), alvo))
    return paginas, quebrados


def main(argv):
    if len(argv) != 2 or not os.path.isdir(argv[1]):
        print("uso: verificar_links_do_site.py <site/>", file=sys.stderr)
        return 2
    paginas, quebrados = verificar(argv[1])
    for pagina, alvo in quebrados:
        print(f"QUEBRADO  {pagina} -> {alvo}")
    print(f"{paginas} páginas varridas, {len(quebrados)} links internos quebrados")
    return 1 if quebrados else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
