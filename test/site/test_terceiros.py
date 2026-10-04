"""T006 / AC11 / F3: nenhuma requisição a terceiro, e o Mermaid conferido pelo hash."""

import os
import re
import shutil
import tempfile
import unittest

from apoio import RAIZ, exigir_site, ler, ler_repo, paginas_html, sem_comentarios_html

import mkdocs_hooks
from mkdocs.exceptions import PluginError

# Recurso carregado pela página (não link de navegação): script, folha de estilo, imagem, fonte.
RECURSO = re.compile(r'<(?:script|img|iframe|source)[^>]*\ssrc="([^"]+)"|<link[^>]*\shref="([^"]+)"', re.I)


class NenhumTerceiro(unittest.TestCase):
    def test_nenhuma_pagina_carrega_recurso_de_outro_dominio(self):
        exigir_site()
        fora = []
        for arquivo in paginas_html():
            with open(arquivo, encoding="utf-8") as f:
                html = sem_comentarios_html(f.read())
            for tag in re.finditer(r"<link[^>]*>", html):
                # `rel=alternate`/`canonical` é endereço, não recurso baixado.
                if re.search(r'rel="(alternate|canonical)"', tag.group(0)):
                    html = html.replace(tag.group(0), "")
            for m in RECURSO.finditer(html):
                alvo = m.group(1) or m.group(2)
                if alvo.startswith(("http://", "https://", "//")):
                    fora.append((os.path.relpath(arquivo), alvo))
        self.assertEqual(fora, [])

    def test_nenhuma_pagina_cita_o_cdn_do_mermaid_nem_o_google_fonts(self):
        exigir_site()
        for arquivo in paginas_html():
            with open(arquivo, encoding="utf-8") as f:
                html = f.read()
            # Como endereço de recurso; a prosa que cita o CDN (o protótipo) não carrega nada.
            self.assertNotRegex(
                html, r'(src|href)="[^"]*(unpkg\.com|fonts\.googleapis\.com|fonts\.gstatic\.com|cdn\.jsdelivr\.net)', arquivo)
            self.assertNotRegex(html, r'https://unpkg\.com/mermaid@[^"\s]*"\)', arquivo)

    def test_o_mermaid_e_carregado_no_head_com_integrity(self):
        exigir_site()
        html = ler("modelos/estados/conta/index.html")
        head = html.split("</head>")[0]
        self.assertRegex(head, r'<script src="[^"]*mermaid-11\.17\.2\.min\.js" integrity="sha384-[A-Za-z0-9+/=]+">')

    def test_nenhum_script_do_site_pede_securitylevel_loose(self):
        # D3: o padrão é `strict` por omissão; ninguém o afrouxa.
        for relativo in ("docs/assets/javascripts/theband.js", "overrides/main.html", "mkdocs.yml"):
            self.assertNotRegex(ler_repo(relativo), r"securityLevel\s*[:=]\s*['\"]?loose")


class HashDoMermaid(unittest.TestCase):
    def _config(self, docs):
        return {"docs_dir": docs, "extra": {"mermaid": {
            "arquivo": "assets/javascripts/vendor/mermaid-11.17.2.min.js",
            "sha256": "581ed7d74bd9048d0e3a91363927d72ef22942d7722546b27f7cc29e35390eb8",
        }}}

    def test_o_arquivo_do_repositorio_confere(self):
        config = self._config(os.path.join(RAIZ, "docs"))
        mkdocs_hooks._conferir_mermaid(config)
        self.assertTrue(config["extra"]["mermaid"]["integrity"].startswith("sha384-"))

    def test_um_byte_a_mais_reprova_o_build_com_os_dois_hashes(self):
        with tempfile.TemporaryDirectory() as tmp:
            destino = os.path.join(tmp, "assets", "javascripts", "vendor")
            os.makedirs(destino)
            alvo = os.path.join(destino, "mermaid-11.17.2.min.js")
            shutil.copy(os.path.join(RAIZ, "docs", "assets", "javascripts", "vendor", "mermaid-11.17.2.min.js"), alvo)
            with open(alvo, "ab") as f:
                f.write(b" ")
            with self.assertRaises(PluginError) as erro:
                mkdocs_hooks._conferir_mermaid(self._config(tmp))
            self.assertIn("Esperado 581ed7d7", str(erro.exception))
            self.assertIn("obtido", str(erro.exception))

    def test_arquivo_ausente_reprova(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(PluginError):
                mkdocs_hooks._conferir_mermaid(self._config(tmp))


if __name__ == "__main__":
    unittest.main()
