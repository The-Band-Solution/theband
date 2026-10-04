"""T014–T019 (D14, 6.1–6.6; E5): as páginas de funcionalidade."""

import os
import re
import unittest

from apoio import DOCS, exigir_site, ler

PAGINAS = ["administradores", "operador-da-plataforma", "segredo-em-repouso", "papeis-do-banco"]
SECOES = ["O que você passa a conseguir fazer", "O que a tela recusa, e diz por quê", "O que ela não faz"]

# E5: o que uma página pública de funcionalidade não diz. Com borda de palavra:
# "AES" não pode reprovar "infraestrutura".
PROIBIDOS = [r"THE_BAND_", r"#1229\b", r"#1221\b", r"\bem aberto\b", r"\bsem limite\b", r"\bpor IP\b",
             r"\btentativas?\b", r"\bcipher\b", r"\bAES\b", r"\bGCM\b", r"\bthe_band_app\b",
             r"\bthe_band_migra\w*\b", r"/platform/"]


class Funcionalidades(unittest.TestCase):
    def test_cada_pagina_tem_a_forma_d14(self):
        for nome in PAGINAS:
            with open(os.path.join(DOCS, "funcionalidades", nome + ".md"), encoding="utf-8") as f:
                md = f.read()
            self.assertIn('<dl class="tb-recibo">', md, nome)
            self.assertIn("https://github.com/The-Band-Solution/theband/tree/development/specs/", md, nome)
            for secao in SECOES:
                self.assertIn("## " + secao, md, f"{nome}: falta '{secao}'")

    def test_nenhuma_pagina_diz_o_que_o_e5_proibe(self):
        for nome in PAGINAS:
            with open(os.path.join(DOCS, "funcionalidades", nome + ".md"), encoding="utf-8") as f:
                md = f.read()
            for padrao in PROIBIDOS:
                self.assertIsNone(re.search(padrao, md, flags=re.I), f"{nome}: {padrao}")

    def test_nenhuma_pagina_linka_artefato_interno_da_spec(self):
        exigir_site()
        for nome in PAGINAS:
            html = ler(f"funcionalidades/{nome}/index.html")
            self.assertNotRegex(html, r'href="[^"]*(seguranca[^"/]*\.md|tasks\.md|research\.md)"', nome)

    def test_a_073_e_a_074_nao_tem_pagina_ate_o_merge(self):
        for nome in os.listdir(os.path.join(DOCS, "funcionalidades")):
            self.assertNotRegex(nome, r"revisao|jornada|entrar-e-sair")


if __name__ == "__main__":
    unittest.main()
