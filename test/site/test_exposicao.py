"""T020 (E1, E3): a seção Segurança e os arquivos de evidência não são publicados."""

import glob
import json
import os
import unittest

from apoio import SITE, exigir_site, ler

# O que o próprio build escreve e é de propósito público.
GERADOS = {"traducao-pendente.txt"}


class Exposicao(unittest.TestCase):
    def test_a_secao_seguranca_nao_esta_no_site(self):
        exigir_site()
        self.assertFalse(os.path.exists(os.path.join(SITE, "seguranca")))
        self.assertFalse(os.path.exists(os.path.join(SITE, "en", "seguranca")))
        self.assertEqual(glob.glob(os.path.join(SITE, "producao", "prototipo-fila-parada", "seguranca*")), [])

    def test_o_indice_de_busca_nao_cita_os_inventarios(self):
        exigir_site()
        indice = json.loads(ler("search/search_index.json"))
        self.assertGreater(len(indice["docs"]), 100, "o índice precisa ter entradas para o teste valer")
        locais = [d["location"] for d in indice["docs"]]
        self.assertEqual([l for l in locais if l.startswith("seguranca/") or "prototipo-fila-parada/seguranca" in l], [])

    def test_nenhum_arquivo_de_evidencia_e_publicado(self):
        exigir_site()
        achados = []
        for ext in ("txt", "log", "sql", "dump"):
            for p in glob.glob(os.path.join(SITE, "**", f"*.{ext}"), recursive=True):
                if os.path.basename(p) not in GERADOS:
                    achados.append(os.path.relpath(p, SITE))
        achados += [os.path.relpath(p, SITE) for p in glob.glob(os.path.join(SITE, "**", "*.env*"), recursive=True)]
        self.assertEqual(achados, [])


if __name__ == "__main__":
    unittest.main()
