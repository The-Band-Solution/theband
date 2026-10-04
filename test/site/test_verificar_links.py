"""T003 (AC7): a varredura de links reprova link interno quebrado, e ignora o externo."""

import os
import tempfile
import unittest

import verificar_links_do_site as v


def escrever(raiz, relativo, html):
    caminho = os.path.join(raiz, relativo)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "w", encoding="utf-8") as f:
        f.write(html)


class Varredura(unittest.TestCase):
    def test_link_interno_que_existe_passa(self):
        with tempfile.TemporaryDirectory() as raiz:
            escrever(raiz, "index.html", '<a href="adr/">x</a><script src="assets/a.js"></script>')
            escrever(raiz, "adr/index.html", "ok")
            escrever(raiz, "assets/a.js", "")
            self.assertEqual(v.verificar(raiz), (2, []))

    def test_link_interno_para_pagina_inexistente_reprova(self):
        with tempfile.TemporaryDirectory() as raiz:
            escrever(raiz, "index.html", '<a href="nao-existe/">x</a><a href="/developers/sumiu/">y</a>')
            paginas, quebrados = v.verificar(raiz)
            self.assertEqual([q[1] for q in quebrados], ["nao-existe/", "/developers/sumiu/"])
            self.assertEqual(v.main(["x", raiz]), 1)

    def test_link_externo_e_ancora_nao_sao_seguidos(self):
        with tempfile.TemporaryDirectory() as raiz:
            escrever(raiz, "index.html", '<a href="https://exemplo.invalid/">x</a><a href="#topo">y</a><a href="/docs/">z</a>')
            self.assertEqual(v.verificar(raiz), (1, []))


if __name__ == "__main__":
    unittest.main()
