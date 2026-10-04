"""T011 (1.3–1.5): a home, com as contagens tiradas do nav e as funcionalidades novas."""

import re
import unittest

import yaml

from apoio import exigir_site, ler, ler_repo


class _Carregador(yaml.SafeLoader):
    pass


# O mkdocs.yml usa tags !!python/...; para contar o nav, elas viram nulo.
_Carregador.add_multi_constructor("tag:yaml.org,2002:python/", lambda l, s, n: None)


def contar(item):
    if isinstance(item, str):
        return 1
    if isinstance(item, dict):
        return sum(contar(v) for v in item.values())
    if isinstance(item, list):
        return sum(contar(v) for v in item)
    return 0


def nav():
    return yaml.load(ler_repo("mkdocs.yml"), Loader=_Carregador)["nav"]


class Home(unittest.TestCase):
    def test_cada_secao_do_nav_aparece_com_a_contagem_real(self):
        exigir_site()
        html = ler("index.html")
        achadas = dict(re.findall(r'class="tb-secao" href="[^"]*"><b>([^<]+)</b><span class="tb-n">(\d+) p', html))
        esperadas = {}
        for item in nav():
            (titulo, alvo), = item.items()
            if isinstance(alvo, list):
                esperadas[titulo] = contar(alvo)
        self.assertEqual(achadas, {k: str(v) for k, v in esperadas.items()})

    def test_por_onde_comecar_tem_as_oito_linhas_com_link(self):
        exigir_site()
        bloco = ler("index.html").split('class="tb-perguntas"', 1)[1].split("</ul>", 1)[0]
        self.assertEqual(len(re.findall(r"<li>.*?<a href=", bloco, flags=re.S)), 8)

    def test_a_secao_iii_lista_as_seis_funcionalidades_com_a_marca_de_onde_estao(self):
        exigir_site()
        bloco = ler("index.html").split('class="tb-curso"', 1)[1].split("</ul>", 1)[0]
        self.assertEqual(re.findall(r'class="tb-id">(\d{3})', bloco), ["072", "070", "064", "071", "073", "074"])
        self.assertEqual(bloco.count("entra quando o PR for mergeado"), 2)
        self.assertIn('href="funcionalidades/administradores/"', bloco)


if __name__ == "__main__":
    unittest.main()
