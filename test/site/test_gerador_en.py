"""T028: o gerador das páginas da base escreve a versão inglesa, e ela não finge.

As páginas de `docs/ontology/`, `docs/integrations/mappings.md` e
`docs/metrics/README.md` são geradas por `scripts/generate_docs.py` e não se
traduzem à mão (traducao.md). Estes testes não precisam do site construído: rodam
o gerador num diretório temporário.

Rodar:  python3 -m unittest discover -s test/site -t test/site
"""

import os
import tempfile
import textwrap
import unittest

from apoio import DOCS

import generate_docs as g

KB = os.path.join(os.path.dirname(DOCS), "priv", "knowledge_base")

# A moldura portuguesa que não pode aparecer na página inglesa.
MOLDURA_PT = [
    "## Módulos", "### Conceitos", "### Relações", "## Perguntas de competência",
    "| Atributo | Tipo | Obrigatório |", "[← Rede de ontologias]", "# Índice de conceitos",
    "**Limitações**", "## Necessidades de informação", "categoria UFO:",
]


def _gerar(kb_dir, langs):
    saida = tempfile.mkdtemp(prefix="gerador-075-")
    escritos = g.gerar(g.load_kb(kb_dir), saida, langs)
    return saida, {os.path.relpath(p, saida): open(p, encoding="utf-8").read() for p in escritos}


def _base_minima():
    """Uma ontologia com dois conceitos: um só em português, e um com inglês."""
    raiz = tempfile.mkdtemp(prefix="kb-075-")
    with open(os.path.join(raiz, "ont.yaml"), "w", encoding="utf-8") as f:
        f.write(textwrap.dedent("""\
            ontology:
              id: xo
              acronym: XO
              name: Example Ontology
              description: {pt-BR: Ontologia de exemplo., en: An example ontology.}
              version: 1.0.0
              layer: core
              network: seon
              namespace: the_band.ontology.seon.xo
            modules: [base]
            provenance: {reference: "Tese, Seção 1"}
            """))
    with open(os.path.join(raiz, "mod.yaml"), "w", encoding="utf-8") as f:
        f.write(textwrap.dedent("""\
            module:
              id: xo.base
              ontology: xo
              name: Base
            concepts:
              - id: xo.so_portugues
                name: Only Portuguese
                definition: {pt-BR: Definição que a base ainda não tem em inglês.}
                classification: {ufo_category: kind}
              - id: xo.bilingue
                name: Bilingual
                definition: {pt-BR: Definição em português., en: Definition in English.}
                classification: {ufo_category: kind}
            """))
    return raiz


class PaginasDaBaseEmDia(unittest.TestCase):
    def test_toda_pagina_gerada_tem_a_versao_inglesa_no_repositorio(self):
        _, gerados = _gerar(KB, ["pt"])
        faltando = [p for p in gerados
                    if not os.path.isfile(os.path.join(DOCS, p[:-3] + ".en.md"))]
        self.assertEqual(faltando, [], "rode: python3 scripts/generate_docs.py")

    def test_o_que_esta_no_repositorio_e_o_que_o_gerador_produz_da_base_atual(self):
        # Divergir é a documentação descrevendo um modelo que não existe mais
        # (ADR 0002). Em 2026-10-03 o PT estava atrás da base em cinco páginas.
        _, gerados = _gerar(KB, ["pt", "en"])
        divergentes = []
        for relativo, conteudo in gerados.items():
            caminho = os.path.join(DOCS, relativo)
            if not os.path.isfile(caminho) or open(caminho, encoding="utf-8").read() != conteudo:
                divergentes.append(relativo)
        self.assertEqual(divergentes, [], "rode: python3 scripts/generate_docs.py")


class AVersaoInglesa(unittest.TestCase):
    def test_a_moldura_inglesa_nao_tem_moldura_portuguesa(self):
        _, gerados = _gerar(KB, ["en"])
        achados = [(p, m) for p, texto in gerados.items() for m in MOLDURA_PT if m in texto]
        self.assertEqual(achados, [])

    def test_o_texto_que_a_base_so_tem_em_portugues_vem_marcado_e_contado(self):
        _, gerados = _gerar(_base_minima(), ["en"])
        pagina = gerados["ontology/xo.en.md"]
        self.assertIn("`pt-BR` Definição que a base ainda não tem em inglês.", pagina)
        self.assertIn("`pt-BR` Tese, Seção 1", pagina)
        self.assertIn("**2 of 4** texts on this page exist in the base only in Portuguese", pagina)

    def test_o_texto_ingles_da_base_e_usado_sem_marca(self):
        _, gerados = _gerar(_base_minima(), ["en"])
        pagina = gerados["ontology/xo.en.md"]
        self.assertIn("\nDefinition in English.\n", pagina)
        self.assertIn("> An example ontology.", pagina)
        self.assertNotIn("Definição em português.", pagina)

    def test_a_pagina_portuguesa_nao_ganha_marca_nem_aviso(self):
        _, gerados = _gerar(_base_minima(), ["pt"])
        pagina = gerados["ontology/xo.md"]
        self.assertNotIn("`pt-BR`", pagina)
        self.assertNotIn("!!! note", pagina)
        self.assertIn("Definição em português.", pagina)

    def test_a_versao_inglesa_mora_ao_lado_com_o_sufixo(self):
        _, gerados = _gerar(_base_minima(), ["pt", "en"])
        self.assertIn("ontology/xo.md", gerados)
        self.assertIn("ontology/xo.en.md", gerados)
        self.assertIn("ontology/README.en.md", gerados)
        self.assertIn("integrations/mappings.en.md", gerados)
        self.assertIn("metrics/README.en.md", gerados)


if __name__ == "__main__":
    unittest.main()
