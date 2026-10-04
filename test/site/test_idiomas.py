"""T004, T005: o site nos dois idiomas, e a página sem tradução diz que não tem."""

import glob
import os
import re
import unittest

from apoio import DOCS, exigir_site, ler


class DoisIdiomas(unittest.TestCase):
    def test_o_site_ingles_existe(self):
        exigir_site()
        self.assertIn('<html lang="en"', ler("en/index.html"))
        self.assertIn('<html lang="pt', ler("index.html"))

    def test_o_seletor_leva_a_mesma_pagina_no_outro_idioma(self):
        exigir_site()
        pt = ler("adr/index.html")
        en = ler("en/adr/index.html")
        self.assertRegex(pt, r'<a href="\.\./en/adr/" hreflang="en"')
        self.assertRegex(en, r'<a href="\.\./\.\./adr/" hreflang="pt"')
        self.assertRegex(pt, r'hreflang="pt" lang="pt" aria-current="true"')
        self.assertRegex(en, r'hreflang="en" lang="en" aria-current="true"')

    def test_a_moldura_inglesa_fala_ingles(self):
        exigir_site()
        en = ler("en/index.html")
        self.assertIn("How The Band is built", en)
        self.assertIn("Sign in to the platform", en)
        self.assertNotIn("Entrar na plataforma", en)


class TraducaoPendente(unittest.TestCase):
    def test_pagina_sem_traducao_mostra_a_ausencia_nomeada_e_marca_o_texto_como_portugues(self):
        exigir_site()
        en = ler("en/adr/0008-vinculo-observado/index.html")
        self.assertIn("translation pending</span> This page has not been translated yet.", en)
        self.assertIn('<div lang="pt-BR">', en)

    def test_a_pagina_portuguesa_nao_mostra_a_marca(self):
        exigir_site()
        self.assertNotIn("translation pending", ler("adr/0008-vinculo-observado/index.html"))

    def test_o_build_lista_as_pendentes(self):
        exigir_site()
        pendentes = ler("traducao-pendente.txt").split()
        self.assertIn("adr/0008-vinculo-observado.md", pendentes)
        traduzidas = [p for p in glob.glob(os.path.join(DOCS, "**", "*.en.md"), recursive=True)]
        for t in traduzidas:
            self.assertNotIn(os.path.relpath(t, DOCS).replace(".en.md", ".md"), pendentes)

    def test_nao_existe_traducao_sem_o_original(self):
        orfas = [
            p for p in glob.glob(os.path.join(DOCS, "**", "*.en.md"), recursive=True)
            if not os.path.isfile(re.sub(r"\.en\.md$", ".md", p))
        ]
        self.assertEqual(orfas, [])


if __name__ == "__main__":
    unittest.main()
