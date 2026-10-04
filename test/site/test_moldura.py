"""T008–T010, T012: topo, faixa do build, rodapé, larguras e os estados sem script."""

import re
import subprocess
import unittest
from unittest import mock

from apoio import exigir_site, ler, ler_repo

import mkdocs_hooks

PAGINAS = ["index.html", "adr/0008-vinculo-observado/index.html", "modelos/estados/conta/index.html"]
DESTINOS = [
    "https://theband.dev/",
    "https://theband.dev/docs/",
    "https://app.theband.dev/sign-in",
    "https://github.com/The-Band-Solution/theband",
]


def topo(html):
    return html.split('<header class="md-header"', 1)[1].split("</header>", 1)[0]


def rodape(html):
    return html.split('<footer class="md-footer"', 1)[1].split("</footer>", 1)[0]


class Topo(unittest.TestCase):
    def test_o_topo_de_tres_paginas_leva_aos_quatro_destinos(self):
        exigir_site()
        for pagina in PAGINAS:
            t = topo(ler(pagina))
            for destino in DESTINOS:
                self.assertIn(f'href="{destino}"', t, pagina)

    def test_a_ordem_do_topo_e_a_do_prototipo(self):
        exigir_site()
        t = topo(ler(PAGINAS[1]))
        ordem = [t.index(x) for x in ('>The Band<', "documentação técnica", 'for="__search"',
                                       ">O produto<", ">GitHub<", ">Entrar na plataforma<")]
        self.assertEqual(ordem, sorted(ordem))

    def test_sem_javascript_a_busca_diz_que_precisa_dele(self):
        exigir_site()
        self.assertRegex(topo(ler(PAGINAS[0])), r"<noscript>.*busca indisponível.*A busca precisa de JavaScript", )


class FaixaDoBuild(unittest.TestCase):
    def test_a_faixa_mostra_o_commit_observado_e_a_versao_ausente(self):
        exigir_site()
        html = ler(PAGINAS[0])
        self.assertRegex(html, r'tb-observado"[^>]*><span class="tb-q"></span>construída de main @ [0-9a-f]{7,} · \d{4}-\d{2}-\d{2}')
        self.assertIn("versão em produção: não informada nesta página", html)

    def test_sem_git_o_commit_e_nulo_e_nunca_inventado(self):
        with mock.patch.object(subprocess, "run", side_effect=OSError("sem git")):
            self.assertEqual(mkdocs_hooks._commit_do_build(), {"commit": None, "data": None})

    def test_o_template_diz_nao_informado_quando_o_commit_e_nulo(self):
        main = ler_repo("overrides/main.html")
        self.assertRegex(main, r"(?s){%- if build.commit -%}.*{%- else -%}.*textos.build_ausente")


class Rodape(unittest.TestCase):
    def test_o_rodape_tem_os_quatro_links_a_base_e_como_a_pagina_e_feita(self):
        exigir_site()
        for pagina in PAGINAS:
            r = rodape(ler(pagina))
            for destino in DESTINOS:
                self.assertIn(f'href="{destino}"', r, pagina)
            self.assertIn("UFES, 2023", r)
            self.assertIn("Construída com MkDocs", r)

    def test_a_pagina_termina_com_editar_no_github_e_o_caminho(self):
        exigir_site()
        html = ler(PAGINAS[1])
        self.assertRegex(html, r'class="tb-editar">\s*<a href="https://github.com/[^"]+/edit/development/docs/adr/0008-vinculo-observado.md">Editar esta página no GitHub</a>')


class Larguras(unittest.TestCase):
    def test_tabela_rola_no_proprio_quadro_e_empilha_no_telefone(self):
        css = ler_repo("docs/assets/stylesheets/theband.css")
        self.assertIn(".md-typeset__scrollwrap { overflow-x: auto; }", css)
        self.assertRegex(css, r"max-width: 40em\)[^@]*table\[data-tb-empilha\] td::before \{\s*content: attr\(data-label\)")
        self.assertIn("data-label", ler_repo("docs/assets/javascripts/theband.js"))

    def test_o_texto_nao_passa_de_44rem(self):
        self.assertRegex(ler_repo("docs/assets/stylesheets/theband.css"), r"max-width: 44rem")


class DiagramaSemScript(unittest.TestCase):
    def test_o_codigo_do_diagrama_fica_no_html_como_texto(self):
        exigir_site()
        html = ler("modelos/estados/conta/index.html")
        self.assertRegex(html, r'<pre class="mermaid"><code>stateDiagram-v2')
        self.assertRegex(html, r"<noscript><p><span class=\"tb-marca tb-ausente\">.*diagrama não desenhado")

    def test_sem_o_arquivo_do_mermaid_o_substituto_escapa_o_codigo(self):
        main = ler_repo("overrides/main.html")
        self.assertIn("tbAusente: true", main)
        self.assertIn('"<pre>" + esc(codigo) + "</pre>"', main)


if __name__ == "__main__":
    unittest.main()
