"""
Hook de build do MkDocs — os links que saem de `docs/` viram URL do GitHub.

## O problema

A documentação deste repositório é escrita para ser lida **no GitHub**, e aponta
para artefatos que ficam fora de `docs/`: as 58 pastas de `specs/`, os YAML de
`priv/knowledge_base/`, os `scripts/`, o `AGENTS.md`. São 118 links, e os
caminhos relativos deles estão corretos a partir da raiz do repositório.

O site publica só `docs/`. Sem este hook, cada um desses links vira 404 — e com
`--strict` o build inteiro reprova.

## Por que hook, e não mudar os arquivos

Reescrever os 118 links como URL absoluta no fonte quebraria a leitura offline e
o `git grep`, e amarraria os documentos a um domínio. O hook resolve no
**momento do build**: o fonte continua relativo e navegável no GitHub, e o site
recebe o link absoluto.

## Por que não incluir `specs/` no site

São 58 features × até 8 arquivos de spec-kit. Elas afogariam uma navegação que
existe para responder perguntas, e o público delas é quem está implementando —
que já está no repositório.
"""

import base64
import hashlib
import os
import posixpath
import re
import subprocess

import yaml
from mkdocs.exceptions import PluginError
from mkdocs.structure.nav import Section

BLOB = "https://github.com/The-Band-Solution/theband/blob/development/"

# Só o que casa com link markdown de caminho relativo. Âncora e query preservadas.
LINK = re.compile(r"(\[[^\]]*\]\()([^)\s]+?)((?:#[^)\s]*)?(?:\s+\"[^\"]*\")?\))")


def _reescrever_links(markdown, page, config):
    """Reescreve, nesta página, os links relativos que escapam de `docs_dir`."""
    dir_no_repo = posixpath.dirname("docs/" + _original(page.file.src_uri))

    def reescreve(m):
        prefixo, alvo, sufixo = m.group(1), m.group(2), m.group(3)

        if alvo.startswith(("http://", "https://", "mailto:", "#", "/")):
            return m.group(0)

        # Caminho do alvo a partir da raiz do repositório.
        no_repo = posixpath.normpath(posixpath.join(dir_no_repo, alvo))

        # Subiu acima da raiz: não é para este hook resolver, e o build estrito
        # continua reclamando — que é o comportamento certo.
        if no_repo.startswith(".."):
            return m.group(0)

        # Continua dentro do site: o MkDocs resolve, e mexer aqui quebraria. A
        # exceção é o que `exclude_docs` tira do site (a seção Segurança, E1 da
        # avaliação da 075): o arquivo existe no repositório público, e o link
        # vai para lá em vez de quebrar.
        if no_repo == "docs" or no_repo.startswith("docs/"):
            if not _excluido(no_repo[len("docs/"):], config):
                return m.group(0)

        return prefixo + BLOB + no_repo + sufixo

    return LINK.sub(reescreve, markdown)



# ════════════════════════════════════════════════════════════════════════════
# 075 — o site de desenvolvedores. O contrato destas funções está em
# specs/075-site-de-desenvolvedores/contracts/build-do-site.md.
# ════════════════════════════════════════════════════════════════════════════

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DADOS = os.path.join(RAIZ, "mkdocs-dados")

# O estado de um build. O plugin de idiomas constrói o site uma vez por idioma,
# e cada build passa por on_config → on_nav → on_env → páginas → on_post_build.
_build = {"secoes": {}, "paginas": {}, "pendentes": [], "traduzidas": set()}


def _original(src_uri):
    """`x.en.md` → `x.md`: o nome PT, que é a chave de toda página nos dois idiomas."""
    return re.sub(r"\.en\.md$", ".md", src_uri)


def _excluido(caminho, config):
    regras = config.get("exclude_docs")
    if not regras:
        return False
    return regras.match_file(caminho)


def _idioma(config):
    return "en" if str(config.theme.get("language", "pt")).startswith("en") else "pt"


def _ler_yaml(nome):
    with open(os.path.join(DADOS, nome), encoding="utf-8") as f:
        return yaml.safe_load(f)


def _conferir_mermaid(config):
    """O arquivo vendorizado tem o sha256 declarado, ou o build REPROVA (D2)."""
    m = config["extra"]["mermaid"]
    caminho = os.path.join(config["docs_dir"], m["arquivo"])
    if not os.path.isfile(caminho):
        raise PluginError(f"Mermaid: {m['arquivo']} não existe em docs/.")
    with open(caminho, "rb") as f:
        dados = f.read()
    obtido = hashlib.sha256(dados).hexdigest()
    if obtido != m["sha256"]:
        raise PluginError(
            f"Mermaid: o sha256 de {m['arquivo']} não confere. Esperado {m['sha256']}, obtido {obtido}."
        )
    m["integrity"] = "sha384-" + base64.b64encode(hashlib.sha384(dados).digest()).decode()


def _commit_do_build():
    """Commit curto e data do HEAD. Sem git, `None`: a faixa diz "não informado"."""
    try:
        saida = subprocess.run(
            ["git", "log", "-1", "--format=%h %cs"],
            cwd=RAIZ, capture_output=True, text=True, timeout=10, check=True,
        ).stdout.split()
    except (OSError, subprocess.SubprocessError):
        return {"commit": None, "data": None}
    if len(saida) != 2:
        return {"commit": None, "data": None}
    return {"commit": saida[0], "data": saida[1]}


def on_config(config, **kwargs):
    _conferir_mermaid(config)
    _build.update({"secoes": {}, "paginas": {}, "pendentes": [], "traduzidas": set()})
    _build["build"] = _commit_do_build()
    return config


def _paginas_de(item):
    if isinstance(item, Section):
        for filho in item.children:
            yield from _paginas_de(filho)
    elif getattr(item, "file", None) is not None:
        yield item


def on_nav(nav, config, files, **kwargs):
    """As contagens da home (1.4) vêm daqui: páginas por seção de topo, do `nav`."""
    for item in nav.items:
        paginas = list(_paginas_de(item))
        if not paginas:
            continue
        chave = _original(paginas[0].file.src_uri)
        _build["secoes"][chave] = {
            "titulo": item.title, "url": paginas[0].url, "paginas": len(paginas),
        }
    for pagina in nav.pages:
        _build["paginas"][_original(pagina.file.src_uri)] = {
            "titulo": pagina.title, "url": pagina.url,
        }
    return nav


def on_env(env, config, files, **kwargs):
    idioma = _idioma(config)
    env.globals.update({
        "idioma": idioma,
        "textos": _ler_yaml("textos.yml")[idioma],
        # A 404 é uma só para os dois idiomas (o build EN a escreve por cima da
        # PT, na raiz do site), e por isso ela recebe os dois conjuntos.
        "textos_todos": _ler_yaml("textos.yml"),
        "home": _ler_yaml("home.yml"),
        "funcionalidades": _ler_yaml("funcionalidades.yml"),
        "build": _build["build"],
        "secoes": _build["secoes"],
        "paginas": _build["paginas"],
    })
    return env


def on_page_markdown(markdown, page, config, files, **kwargs):
    original = _original(page.file.src_uri)
    if original == "README.md":
        page.meta["template"] = "home.html"
    if _idioma(config) == "en":
        if page.file.src_uri.endswith(".en.md"):
            _build["traduzidas"].add(original)
        else:
            # Servida do PT no build EN: o plugin caiu no idioma padrão.
            page.meta["traducao_pendente"] = True
            _build["pendentes"].append(original)
    return _reescrever_links(markdown, page, config)


def _hashes_inline(html):
    """sha256 de cada <script> inline executável, no formato da CSP."""
    hashes = []
    for atributos, corpo in re.findall(r"<script([^>]*)>(.*?)</script>", html, flags=re.S):
        if "src=" in atributos or "application/json" in atributos or not corpo.strip():
            continue
        digest = base64.b64encode(hashlib.sha256(corpo.encode("utf-8")).digest()).decode()
        hashes.append(f"'sha256-{digest}'")
    return " ".join(sorted(set(hashes)))


def on_post_build(config, **kwargs):
    # A CSP da 404 (E6): o hash de cada script inline, calculado sobre o HTML final.
    pagina_404 = os.path.join(config["site_dir"], "404.html")
    if os.path.isfile(pagina_404):
        with open(pagina_404, encoding="utf-8") as f:
            html = f.read()
        if "__TB_CSP_HASHES__" not in html:
            raise PluginError("404.html sem o marcador da CSP: o template mudou e a CSP sumiu.")
        with open(pagina_404, "w", encoding="utf-8") as f:
            f.write(html.replace("__TB_CSP_HASHES__", _hashes_inline(html)))

    if _idioma(config) != "en":
        return
    pendentes = sorted(set(_build["pendentes"]))
    total = len(pendentes) + len(_build["traduzidas"])
    with open(os.path.join(config["site_dir"], "traducao-pendente.txt"), "w", encoding="utf-8") as f:
        f.write("".join(p + "\n" for p in pendentes))
    print(f"INFO    -  tradução: {len(pendentes)} de {total} páginas sem versão EN (traducao-pendente.txt, na raiz do site)")
    if config["extra"].get("traducao", {}).get("exigir") and pendentes:
        raise PluginError(
            f"tradução exigida: {len(pendentes)} páginas sem .en.md: " + ", ".join(pendentes[:20])
        )
