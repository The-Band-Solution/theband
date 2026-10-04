"""T007 / AC2: os tokens do tema são os da landing, nos dois temas, declarados uma vez."""

import os
import re
import unittest

from apoio import RAIZ, exigir_site, ler, ler_repo

TOKENS = ["papel", "tinta", "tinta-2", "verdete", "verdete-forte", "verdete-fundo", "latao", "pauta", "cartao"]


def blocos(css):
    """(seletor, corpo) de cada regra de primeiro nível, sem comentários."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    return re.findall(r"([^{}]+)\{([^{}]*)\}", css)


def valores(corpo):
    return dict(re.findall(r"--([a-z0-9-]+)\s*:\s*([^;]+);", corpo))


def tokens_por_tema(css):
    claro, escuro = {}, {}
    for seletor, corpo in blocos(css):
        v = {k: x.strip() for k, x in valores(corpo).items() if k in TOKENS}
        if not v:
            continue
        # `:root:not([data-theme="light"])` é o escuro da landing, dentro do @media.
        if "dark" in seletor or "slate" in seletor or 'not([data-theme="light"])' in seletor:
            escuro.update(v)
        else:
            claro.update(v)
    return claro, escuro


class TokensDaLanding(unittest.TestCase):
    def test_os_nove_tokens_sao_os_da_landing_nos_dois_temas(self):
        landing = ler_repo("test/site/fixtures/tokens-da-landing.css")
        # A landing declara o escuro duas vezes (media e data-theme), com os mesmos valores.
        l_claro, l_escuro = tokens_por_tema(re.sub(r"@media[^{]*\{", "", landing))
        tema = ler_repo("docs/assets/stylesheets/theband.css")
        t_claro, t_escuro = tokens_por_tema(tema)
        self.assertEqual(len(l_claro), 9, "a fixture precisa trazer os nove tokens claros")
        self.assertEqual({k: t_claro.get(k) for k in TOKENS}, l_claro)
        self.assertEqual({k: t_escuro.get(k) for k in l_escuro}, l_escuro)

    def test_cada_tema_e_declarado_uma_vez(self):
        tema = ler_repo("docs/assets/stylesheets/theband.css")
        declaracoes = [s for s, c in blocos(tema) if re.search(r"--papel\s*:", c)]
        self.assertEqual(len(declaracoes), 2, declaracoes)

    def test_a_data_da_copia_esta_no_css_e_no_rodape(self):
        tema = ler_repo("docs/assets/stylesheets/theband.css")
        self.assertIn("em 2026-10-03", tema)
        exigir_site()
        self.assertIn("Identidade copiada de theband.dev em 2026-10-03", ler("index.html"))

    def test_o_css_publicado_e_o_do_repositorio(self):
        exigir_site()
        self.assertEqual(ler("assets/stylesheets/theband.css"), ler_repo("docs/assets/stylesheets/theband.css"))


if __name__ == "__main__":
    unittest.main()
