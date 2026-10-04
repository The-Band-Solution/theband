"""T003, T021 (E8, D1): os workflows da documentação."""

import re
import unittest

from apoio import ler_repo


def sem_comentarios(yml):
    return "\n".join(l.split(" #")[0] for l in yml.splitlines() if not l.strip().startswith("#"))


class WorkflowDoPR(unittest.TestCase):
    def setUp(self):
        self.yml = sem_comentarios(ler_repo(".github/workflows/docs-pr.yml"))

    def test_roda_em_pull_request_e_nunca_em_pull_request_target(self):
        self.assertIn("pull_request:", self.yml)
        self.assertNotIn("pull_request_target", self.yml)

    def test_so_le_e_nao_usa_segredo(self):
        self.assertIn("contents: read", self.yml)
        self.assertNotIn("contents: write", self.yml)
        self.assertNotIn("secrets.", self.yml)
        self.assertIn("persist-credentials: false", self.yml)
        self.assertIn("timeout-minutes:", self.yml)

    def test_roda_o_build_estrito_a_varredura_e_os_testes_sem_pipe(self):
        self.assertIn("mkdocs build --strict", self.yml)
        self.assertIn("scripts/verificar_links_do_site.py site", self.yml)
        self.assertIn("unittest discover -s test/site", self.yml)
        self.assertIn("--require-hashes", self.yml)
        for linha in self.yml.splitlines():
            if "mkdocs build" in linha or "verificar_links" in linha or "unittest" in linha:
                self.assertNotIn("|", linha, linha)


class TodosOsWorkflowsDeDocumentacao(unittest.TestCase):
    def test_toda_action_e_fixada_por_sha(self):
        for nome in ("docs.yml", "docs-pr.yml"):
            for uso in re.findall(r"uses:\s*(\S+)", ler_repo(f".github/workflows/{nome}")):
                self.assertRegex(uso, r"@[0-9a-f]{40}$", f"{nome}: {uso}")

    def test_o_checkout_nao_guarda_credencial(self):
        for nome in ("docs.yml", "docs-pr.yml"):
            self.assertIn("persist-credentials: false", ler_repo(f".github/workflows/{nome}"), nome)


if __name__ == "__main__":
    unittest.main()
