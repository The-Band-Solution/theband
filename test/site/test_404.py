"""T013 (5.1; E2, E6, E7): a 404 da raiz e de /developers/, e o guarda do deploy."""

import base64
import hashlib
import re
import unittest

from apoio import exigir_site, ler, ler_repo


def scripts_inline(html):
    return [c for a, c in re.findall(r"<script([^>]*)>(.*?)</script>", html, flags=re.S)
            if "src=" not in a and "application/json" not in a and c.strip()]


class Pagina404(unittest.TestCase):
    def setUp(self):
        exigir_site()
        self.html = ler("404.html")

    def test_o_caminho_entra_so_como_texto(self):
        nosso = [c for c in scripts_inline(self.html) if "tb-caminho" in c]
        self.assertEqual(len(nosso), 1)
        for proibido in ("innerHTML", "outerHTML", "insertAdjacentHTML", "document.write", "eval(",
                         "location.search", "location.hash", 'http-equiv="refresh"', "location.assign",
                         "location.replace", "location.href ="):
            self.assertNotIn(proibido, nosso[0], proibido)
        self.assertIn('.textContent = caminho', self.html)
        self.assertIn("decodeURIComponent(bruto); } catch", self.html)
        self.assertIn("caminho.length > 200", self.html)

    def test_os_links_sao_fixos_e_nos_dois_idiomas(self):
        for destino in ("https://theband.dev/developers/", "https://theband.dev/developers/en/",
                        "https://theband.dev/docs/", "https://theband.dev/"):
            self.assertIn(f'href="{destino}"', self.html)
        self.assertIn("Esta página não existe em theband.dev.", self.html)
        self.assertIn("This page does not exist on theband.dev.", self.html)
        self.assertIn("Esta página não está publicada.", self.html)

    def test_sem_javascript_aparece_a_variante_neutra(self):
        self.assertRegex(self.html, r'data-variante="neutra">\s*<h1>')
        self.assertRegex(self.html, r'data-variante="developers" hidden>')

    def test_a_csp_tem_o_hash_de_cada_script_inline(self):
        csp = re.search(r'http-equiv="Content-Security-Policy" content="([^"]+)"', self.html).group(1)
        self.assertNotIn("__TB_CSP_HASHES__", csp)
        self.assertIn("default-src 'none'", csp)
        for corpo in scripts_inline(self.html):
            digest = base64.b64encode(hashlib.sha256(corpo.encode("utf-8")).digest()).decode()
            self.assertIn(f"'sha256-{digest}'", csp)

    def test_os_recursos_da_404_sao_absolutos_porque_ela_serve_em_qualquer_caminho(self):
        for alvo in re.findall(r'<link[^>]*rel="stylesheet"[^>]*href="([^"]+)"', self.html):
            self.assertTrue(alvo.startswith("/developers/"), alvo)


class GuardaDoDeploy(unittest.TestCase):
    def setUp(self):
        self.yml = ler_repo(".github/workflows/docs.yml")

    def test_o_guarda_confere_os_quatro_arquivos_da_raiz_e_a_ausencia_da_seguranca(self):
        for conferencia in ("test -f publicacao/CNAME", "test -f publicacao/index.html",
                            "test -f publicacao/docs/index.html", "test -f publicacao/404.html",
                            "cmp site/404.html publicacao/404.html",
                            "test ! -e publicacao/developers/seguranca"):
            self.assertIn(conferencia, self.yml)

    def test_a_copia_para_a_raiz_e_so_da_404(self):
        self.assertIn("cp site/404.html publicacao/404.html", self.yml)
        self.assertNotRegex(self.yml, r"cp -r site/\* publicacao/?\s")
        self.assertNotIn("gh-deploy", re.sub(r"#.*", "", self.yml))


if __name__ == "__main__":
    unittest.main()
