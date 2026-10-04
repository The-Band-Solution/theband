#!/usr/bin/env python3
"""Gera a documentação das ontologias a partir da base de conhecimento.

Precursor da Mix task knowledge.docs. A base YAML é a fonte da verdade; os
arquivos em docs/ontology/ são derivados e NÃO devem ser editados à mão —
alterá-los faz a documentação divergir do modelo.

Gera, em português (`.md`) e em inglês (`.en.md`, ao lado — convenção do site,
specs/075-site-de-desenvolvedores/traducao.md):
  docs/ontology/README.md          visão da rede, camadas e dependências
  docs/ontology/<id>.md            uma página por ontologia
  docs/ontology/concept-index.md   índice alfabético de todos os conceitos
  docs/integrations/mappings.md    catálogo dos mapeamentos semânticos
  docs/metrics/README.md           necessidades de informação e medidas

A versão inglesa traduz a moldura (títulos, rótulos, tabelas) e usa o texto `en`
da base quando ele existe. Quando a base só tem o português, o original aparece
MARCADO como `pt-BR`, e a página diz quantos são — nunca texto português fingindo
ser inglês, e nunca tradução inventada aqui: o texto inglês de um conceito é
artefato de domínio, e mora na base (AGENTS.md §8), não no gerador.

Uso: python3 scripts/generate_docs.py [--kb priv/knowledge_base] [--out docs]
                                      [--lang all|pt|en]
"""

import argparse
import glob
import os
import sys
from collections import defaultdict

try:
    import yaml
except ImportError:
    sys.exit("PyYAML necessário: pip install pyyaml")

BANNER = {
    "pt": ("<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. "
           "NÃO EDITE À MÃO. -->\n\n"),
    "en": ("<!-- GERADO POR scripts/generate_docs.py (--lang en) A PARTIR DE priv/knowledge_base/. "
           "NÃO EDITE À MÃO: o texto inglês de um conceito se escreve na base, no campo `en`. -->\n\n"),
}

NETWORK_LABEL = {"ufo": "UFO", "seon": "SEON", "continuum": "Continuum"}
LAYER_LABEL = {
    "pt": {"foundational": "Fundacional", "core": "Core", "domain": "Domínio"},
    "en": {"foundational": "Foundational", "core": "Core", "domain": "Domain"},
}

# A marca do texto que a base ainda só tem em português. É texto, e não só
# estilo, pela mesma razão das marcas de proveniência do design system.
MARCA_PT = "`pt-BR`"

# A moldura de cada página, nos dois idiomas. A chave é o português, que é o
# texto que o gerador sempre teve — o PT sai idêntico ao de antes.
EN = {
    "Rede de ontologias": "Ontology network",
    "Documentação gerada a partir de `priv/knowledge_base/`. "
    "A base YAML é a fonte da verdade; esta página é derivada dela.":
        "Documentation generated from `priv/knowledge_base/`. "
        "The YAML base is the source of truth; this page is derived from it.",
    "ontologias": "ontologies", "conceitos": "concepts", "relações": "relations",
    "perguntas de competência": "competency questions",
    "Arquitetura": "Architecture",
    "Cada seta significa *reusa conceitos de*. A direção vai sempre do módulo "
    "mais específico para o mais geral; o caminho inverso é proibido e "
    "verificado por `scripts/validate_knowledge_base.py`.":
        "Each arrow means *reuses concepts from*. The direction always goes from the more "
        "specific module to the more general one; the reverse path is forbidden and "
        "checked by `scripts/validate_knowledge_base.py`.",
    "Ontologias": "Ontologies",
    "| Ontologia | Camada | Rede | Depende de | Conceitos | Relações | CQs |":
        "| Ontology | Layer | Network | Depends on | Concepts | Relations | CQs |",
    "Distinções que o modelo preserva": "Distinctions the model preserves",
    "| Não confunda | Por quê |": "| Do not confuse | Why |",
    "Origem": "Origin",
    "Versão": "Version", "Camada": "Layer", "Rede": "Network",
    "Depende de": "Depends on",
    "Nota.": "Note.",
    "Módulos": "Modules",
    "conceitos e relações do módulo.": "the module's concepts and relations.",
    "Fonte:": "Source:",
    "Conceitos": "Concepts",
    "categoria UFO": "UFO category", "especializa": "specializes",
    "papel de": "role of", "automatizado": "automated",
    "| Atributo | Tipo | Obrigatório |": "| Attribute | Type | Required |",
    "sim": "yes", "não": "no",
    "Exemplos:": "Examples:",
    "Relações": "Relations",
    "| Relação | Origem | Destino | Cardinalidade | Tipo |":
        "| Relation | Source | Target | Cardinality | Type |",
    "Perguntas de competência": "Competency questions",
    "Perguntas que esta ontologia precisa saber responder. "
    "São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.":
        "Questions this ontology must be able to answer. "
        "They are the model's functional requirements, checked by `mix knowledge.test`.",
    "| # | Pergunta | Conceitos envolvidos |": "| # | Question | Concepts involved |",
    "[← Rede de ontologias](README.md)": "[← Ontology network](README.md)",
    "Índice de conceitos": "Concept index",
    "conceitos na rede, em ordem alfabética de identificador.":
        "concepts in the network, in alphabetical order of identifier.",
    "| Id | Conceito | pt-BR | Ontologia | Categoria UFO |":
        "| Id | Concept | pt-BR | Ontology | UFO category |",
    "Mapeamentos semânticos": "Semantic mappings",
    "Como cada entidade das ferramentas externas se relaciona com os conceitos da rede.":
        "How each entity of the external tools relates to the network's concepts.",
    "Nenhum dado externo entra no domínio sem um mapeamento declarado, com grau de "
    "equivalência, justificativa e limitações explícitas. Semelhança de nome nunca basta.":
        "No external data enters the domain without a declared mapping, with an explicit degree "
        "of equivalence, justification and limitations. Similarity of name is never enough.",
    "| Origem | Entidade | Ontologia | Conceito | Equivalência | Status |":
        "| Source | Entity | Ontology | Concept | Equivalence | Status |",
    "Justificativas e limitações": "Justifications and limitations",
    "equivalência": "equivalence", "versão": "version",
    "Limitações": "Limitations",
    "Necessidades de informação e medidas": "Information needs and measures",
    "Nenhuma medida existe sem uma necessidade de informação declarada, e nenhum "
    "dashboard existe sem medida rastreável até esta página.":
        "No measure exists without a declared information need, and no dashboard exists "
        "without a measure traceable to this page.",
    "Necessidades de informação": "Information needs",
    "Pergunta.": "Question.", "Decisão apoiada.": "Decision supported.",
    "Stakeholders.": "Stakeholders.", "Conceitos necessários.": "Required concepts.",
    "Medidas candidatas.": "Candidate measures.",
    "Medidas": "Measures", "Responde a:": "Answers:",
    "Tipo:": "Type:", "unidade:": "unit:", "níveis:": "levels:",
    "Interpretações incorretas possíveis": "Possible misinterpretations",
}

DISTINCOES = {
    "pt": [
        ("Pull Request ≠ Merge", "PR é solicitação de mudança (`cmpo.change_request`); merge é evento distinto"),
        ("Pessoa ≠ Membro de equipe", "`eo.team_member` é papel; `eo.team_membership` é a relação contextual"),
        ("Processo planejado ≠ executado", "SPO separa `intended_*` de `performed_*`"),
        ("Código ≠ Programa", "código constitui o programa sem ser idêntico a ele"),
        ("Documento de requisito ≠ Requisito", "o artefato descreve o requisito, não é o requisito"),
        ("Caso de teste ≠ Execução de teste", "ROoST separa planejamento de execução"),
        ("Code smell ≠ Defeito", "não conformidade (QAPO) não é defeito (OSDEF)"),
        ("Defect ≠ Fault ≠ Failure", "failure é evento; defect é disposição; fault é o defeito manifestado"),
    ],
    "en": [
        ("Pull Request ≠ Merge", "a PR is a change request (`cmpo.change_request`); a merge is a distinct event"),
        ("Person ≠ Team member", "`eo.team_member` is a role; `eo.team_membership` is the contextual relation"),
        ("Intended process ≠ performed process", "SPO separates `intended_*` from `performed_*`"),
        ("Code ≠ Program", "code constitutes the program without being identical to it"),
        ("Requirement document ≠ Requirement", "the artifact describes the requirement, it is not the requirement"),
        ("Test case ≠ Test execution", "ROoST separates planning from execution"),
        ("Code smell ≠ Defect", "a noncompliance (QAPO) is not a defect (OSDEF)"),
        ("Defect ≠ Fault ≠ Failure", "a failure is an event; a defect is a disposition; a fault is the manifested defect"),
    ],
}


class Idioma:
    """A moldura e o texto da base num idioma, contando o que caiu no português.

    ``t`` traduz a moldura; ``texto`` devolve o texto de um campo da base e,
    em inglês, marca como ``pt-BR`` o que a base ainda não tem em inglês. A
    contagem das marcas vai para o aviso no topo da página: a ausência é
    medida, e não só desenhada.
    """

    def __init__(self, lang):
        self.lang = lang
        self.em_portugues = 0
        self.campos = 0

    def t(self, s):
        return s if self.lang == "pt" else EN[s]

    def camada(self, layer):
        return LAYER_LABEL[self.lang][layer]

    def bruto(self, node, default=""):
        """O texto no idioma, e se ele caiu no português. Sem marca."""
        if self.lang == "pt":
            return pt(node, default), False
        if isinstance(node, dict):
            if (node.get("en") or "").strip():
                return node["en"].strip(), False
            texto = (node.get("pt-BR") or default).strip()
        elif isinstance(node, str):
            # Campo de idioma único na base (justificativa, limitação, semântica de
            # relação): escrito em português, e é como a base o declara.
            texto = node.strip()
        else:
            texto = default
        return texto, bool(texto)

    def texto(self, node, default="", cru=False):
        """O texto no idioma, com a marca ``pt-BR`` quando caiu no português.

        ``cru``: em português, o item de lista sai como está na base, sem
        ``strip`` — é o que o gerador sempre fez, e o PT não muda de byte.
        """
        if cru and self.lang == "pt":
            return node
        texto, caiu = self.bruto(node, default)
        if texto:
            self.campos += 1
        if caiu:
            self.em_portugues += 1
            return f"{MARCA_PT} {texto}"
        return texto

    def aviso(self):
        """O topo da página inglesa: o que é traduzido, e quanto ainda não é."""
        if self.lang == "pt":
            return []
        if not self.em_portugues:
            return ["!!! note \"Generated from the knowledge base\"",
                    "    Every text on this page comes from the English fields of "
                    "`priv/knowledge_base/`.\n"]
        return [
            "!!! note \"Generated from the knowledge base — part of the text is still in Portuguese\"",
            "    This page is generated from `priv/knowledge_base/`. The headings, labels and tables "
            "are in English. The texts of the base — definitions, descriptions, questions, "
            "justifications — are shown in English where the base has them in English; otherwise "
            f"the Portuguese original appears, marked {MARCA_PT}.",
            "",
            f"    **{self.em_portugues} of {self.campos}** texts on this page exist in the base "
            "only in Portuguese. The English text is written in the base, in the `en` field, "
            "and not on this page: the page is regenerated and would lose it.\n",
        ]

    def caminho(self, out, relativo):
        if self.lang == "pt":
            return f"{out}/{relativo}"
        return f"{out}/{relativo[:-3]}.en.md"


def load_kb(root):
    """Carrega a base inteira, agrupada por tipo de artefato.

    :returns: dicionário com ``ontologies``, ``modules``, ``cqs``, ``mappings``,
        ``measurements``, ``needs`` e ``manifest``. O tipo de cada arquivo é
        inferido pela chave raiz, não pelo caminho — assim mover um arquivo de
        pasta não quebra a geração.
    """
    kb = {"ontologies": {}, "modules": defaultdict(list), "cqs": defaultdict(list),
          "mappings": [], "manifest": None, "measurements": [], "needs": []}
    for f in sorted(glob.glob(f"{root}/**/*.yaml", recursive=True)):
        d = yaml.safe_load(open(f, encoding="utf-8"))
        if not isinstance(d, dict):
            continue
        if isinstance(d.get("knowledge_base"), dict):
            kb["manifest"] = d
        elif isinstance(d.get("ontology"), dict):
            kb["ontologies"][d["ontology"]["id"]] = (d, os.path.dirname(f))
        elif "module" in d:
            kb["modules"][d["module"]["ontology"]].append(d)
        elif "competency_questions" in d:
            kb["cqs"][d["ontology"]].extend(d["competency_questions"])
        elif "mapping" in d:
            kb["mappings"].append(d)
        elif "measurement" in d:
            kb["measurements"].append(d["measurement"])
        elif "information_need" in d:
            kb["needs"].append(d["information_need"])
    return kb


def pt(node, default=""):
    """Texto em pt-BR de um campo bilíngue, com queda para ``en``.

    Aceita string simples além do dicionário ``{pt-BR, en}``, porque nem todo
    campo da base é bilíngue.
    """
    if isinstance(node, dict):
        return (node.get("pt-BR") or node.get("en") or default).strip()
    return (node or default).strip() if isinstance(node, str) else default


def anchor(concept_id):
    """Âncora HTML estável para um id de conceito."""
    return concept_id.replace(".", "").replace("_", "-")


def write(path, content):
    """Grava criando diretórios intermediários; devolve o caminho escrito."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write(content)
    return path


def montar(i, lines):
    """BANNER, o aviso do idioma logo depois do título, e o corpo."""
    titulo, corpo = lines[0], lines[1:]
    return "\n".join([BANNER[i.lang], titulo] + i.aviso() + corpo) + "\n"


# --------------------------------------------------------------------------- #

def gen_network_readme(kb, out, lang="pt"):
    """Página da rede: contagens, diagrama de dependências e distinções-chave."""
    i = Idioma(lang)
    t = i.t
    onts = kb["ontologies"]
    by_net = defaultdict(list)
    for oid, (d, _) in sorted(onts.items()):
        by_net[d["ontology"]["network"]].append((oid, d["ontology"]))

    lines = [f"# {t('Rede de ontologias')}\n",
             t("Documentação gerada a partir de `priv/knowledge_base/`. "
               "A base YAML é a fonte da verdade; esta página é derivada dela.") + "\n"]

    total_c = sum(len(m.get("concepts") or []) for ms in kb["modules"].values() for m in ms)
    total_r = sum(len(m.get("relations") or []) for ms in kb["modules"].values() for m in ms)
    total_q = sum(len(v) for v in kb["cqs"].values())
    lines.append(f"**{len(onts)} {t('ontologias')} · {total_c} {t('conceitos')} · "
                 f"{total_r} {t('relações')} · {total_q} {t('perguntas de competência')}**\n")

    lines.append(f"## {t('Arquitetura')}\n")
    lines.append("```mermaid\ngraph TD")
    for oid, (d, _) in sorted(onts.items()):
        o = d["ontology"]
        lines.append(f'  {oid}["{o["acronym"]}<br/><small>{o["name"]}</small>"]')
    for oid, (d, _) in sorted(onts.items()):
        for dep in d.get("dependencies") or []:
            lines.append(f"  {oid} --> {dep}")
    lines.append("```\n")
    lines.append(t("Cada seta significa *reusa conceitos de*. A direção vai sempre do módulo "
                   "mais específico para o mais geral; o caminho inverso é proibido e "
                   "verificado por `scripts/validate_knowledge_base.py`.") + "\n")

    lines.append(f"## {t('Ontologias')}\n")
    lines.append(t("| Ontologia | Camada | Rede | Depende de | Conceitos | Relações | CQs |"))
    lines.append("|---|---|---|---|---:|---:|---:|")
    for oid, (d, _) in sorted(onts.items(), key=lambda kv: (
            ["foundational", "core", "domain"].index(kv[1][0]["ontology"]["layer"]), kv[0])):
        o = d["ontology"]
        mods = kb["modules"].get(oid, [])
        nc = sum(len(m.get("concepts") or []) for m in mods)
        nr = sum(len(m.get("relations") or []) for m in mods)
        deps = ", ".join(f"`{x}`" for x in (d.get("dependencies") or [])) or "—"
        lines.append(f"| [{o['acronym']}]({oid}.md) — {o['name']} | {i.camada(o['layer'])} | "
                     f"{NETWORK_LABEL[o['network']]} | {deps} | {nc} | {nr} | {len(kb['cqs'].get(oid, []))} |")

    lines.append(f"\n## {t('Distinções que o modelo preserva')}\n")
    lines.append(t("| Não confunda | Por quê |"))
    lines.append("|---|---|")
    for a, b in DISTINCOES[lang]:
        lines.append(f"| {a} | {b} |")

    if kb["manifest"]:
        p = kb["manifest"]["knowledge_base"].get("provenance") or {}
        titulo, _ = i.bruto(p.get("title", ""))
        lines.append(f"\n## {t('Origem')}\n")
        lines.append(f"{p.get('author', '')}. *{titulo}*. "
                     f"{p.get('institution', '')}, {p.get('year', '')}.\n")

    return write(i.caminho(out, "ontology/README.md"), montar(i, lines))


def gen_ontology_page(kb, oid, out, lang="pt"):
    """Uma página por ontologia: metadados, módulos, conceitos, relações e CQs."""
    i = Idioma(lang)
    t = i.t
    d, _ = kb["ontologies"][oid]
    o = d["ontology"]
    mods = kb["modules"].get(oid, [])
    mod_by_id = {m["module"]["id"]: m for m in mods}
    ordered = [mod_by_id[f"{oid}.{name}"] for name in (d.get("modules") or [])
               if f"{oid}.{name}" in mod_by_id]

    L = [f"# {o['acronym']} — {o['name']}\n"]
    L.append(f"> {i.texto(o.get('description', ''))}\n")
    L.append("| | |")
    L.append("|---|---|")
    L.append(f"| **Id** | `{o['id']}` |")
    L.append(f"| **{t('Versão')}** | {o['version']} |")
    L.append(f"| **{t('Camada')}** | {i.camada(o['layer'])} |")
    L.append(f"| **{t('Rede')}** | {NETWORK_LABEL[o['network']]} |")
    L.append(f"| **Namespace** | `{o['namespace']}` |")
    deps = d.get("dependencies") or []
    L.append(f"| **{t('Depende de')}** | {', '.join(f'[{x}]({x}.md)' for x in deps) or '—'} |")
    prov = d.get("provenance") or {}
    ref = prov.get("reference", "")
    # A referência é citação em português ("Tese, Seção 3.4"): marcada como o resto.
    L.append(f"| **{t('Origem')}** | {i.texto(ref or prov.get('source_type', ''), cru=True)} |")
    if prov.get("note"):
        L.append(f"\n> **{t('Nota.')}** {i.texto(prov['note'])}\n")

    L.append(f"\n## {t('Módulos')}\n")
    for m in ordered:
        mid = m["module"]["id"].split(".", 1)[1]
        desc = i.texto(m["module"].get("description", ""))
        L.append(f"- **[{m['module']['name']}](#{anchor(mid)})** — "
                 f"{desc or t('conceitos e relações do módulo.')}")

    for m in ordered:
        mid = m["module"]["id"].split(".", 1)[1]
        L.append(f"\n---\n\n## {m['module']['name']}\n")
        L.append(f'<a id="{anchor(mid)}"></a>\n')
        if pt(m["module"].get("description", "")):
            L.append(f"{i.texto(m['module']['description'])}\n")
        mp = m["module"].get("provenance") or {}
        if mp.get("reference"):
            L.append(f"*{t('Fonte:')} {i.texto(mp['reference'], cru=True)}*\n")

        concepts = m.get("concepts") or []
        if concepts:
            L.append(f"### {t('Conceitos')}\n")
            for c in concepts:
                cls = c.get("classification") or {}
                L.append(f"#### `{c['id']}` — {c['name']}\n")
                if c.get("label"):
                    # O rótulo é o nome do conceito em português, e é por isso que
                    # existe: a página inglesa o mostra como o que ele é.
                    rotulo = pt(c["label"]) if lang == "pt" else f"pt-BR: {pt(c['label'])}"
                    L.append(f"*{rotulo}*\n")
                L.append(f"{i.texto(c.get('definition', ''))}\n")
                meta = [f"{t('categoria UFO')}: `{cls.get('ufo_category')}`"]
                if cls.get("parent"):
                    meta.append(f"{t('especializa')} `{cls['parent']}`")
                if cls.get("is_role_of"):
                    meta.append(f"{t('papel de')} `{cls['is_role_of']}`")
                if c.get("automated"):
                    meta.append(t("automatizado"))
                L.append(f"<sub>{' · '.join(meta)}</sub>\n")
                if c.get("attributes"):
                    L.append(t("| Atributo | Tipo | Obrigatório |"))
                    L.append("|---|---|---|")
                    for a in c["attributes"]:
                        L.append(f"| `{a['name']}` | {a['type']} | "
                                 f"{t('sim') if a.get('required') else t('não')} |")
                    L.append("")
                if c.get("examples"):
                    exemplos = "; ".join(f"*{e}*" for e in c["examples"])
                    if lang == "en":
                        exemplos = i.texto(exemplos)
                    L.append(f"{t('Exemplos:')} " + exemplos + "\n")

        relations = m.get("relations") or []
        if relations:
            L.append(f"### {t('Relações')}\n")
            L.append(t("| Relação | Origem | Destino | Cardinalidade | Tipo |"))
            L.append("|---|---|---|---|---|")
            for r in relations:
                card = r.get("cardinality") or {}
                c_txt = f"{card.get('source', '?')} → {card.get('target', '?')}"
                L.append(f"| `{r['name']}` | `{r['source']}` | `{r['target']}` | {c_txt} | {r.get('type', '—')} |")
            L.append("")
            for r in relations:
                sem = (r.get("semantics") or {}).get("description")
                if sem:
                    L.append(f"- **`{r['id']}`** — {i.texto(sem)}")
            L.append("")

    cqs = kb["cqs"].get(oid, [])
    if cqs:
        L.append(f"\n---\n\n## {t('Perguntas de competência')}\n")
        L.append(t("Perguntas que esta ontologia precisa saber responder. "
                   "São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.") + "\n")
        L.append(t("| # | Pergunta | Conceitos envolvidos |"))
        L.append("|---|---|---|")
        for q in cqs:
            cs = ", ".join(f"`{c}`" for c in (q.get("concepts") or [])[:4])
            if len(q.get("concepts") or []) > 4:
                cs += ", …"
            L.append(f"| `{q['id'].split('.')[-1].upper()}` | {i.texto(q['question'])} | {cs} |")
        L.append("")
        for q in cqs:
            if q.get("rationale"):
                L.append(f"- **{q['id'].split('.')[-1].upper()}** — {i.texto(q['rationale'])}")
        L.append("")

    L.append(f"\n---\n\n{t('[← Rede de ontologias](README.md)')}\n")
    return write(i.caminho(out, f"ontology/{oid}.md"), montar(i, L))


def gen_concept_index(kb, out, lang="pt"):
    """Índice alfabético de todos os conceitos da rede."""
    i = Idioma(lang)
    t = i.t
    rows = []
    for oid, mods in kb["modules"].items():
        for m in mods:
            for c in m.get("concepts") or []:
                rows.append((c["id"], c["name"], pt(c.get("label", "")), oid,
                             (c.get("classification") or {}).get("ufo_category", "")))
    rows.sort()
    L = [f"# {t('Índice de conceitos')}\n",
         f"{len(rows)} {t('conceitos na rede, em ordem alfabética de identificador.')}\n",
         t("| Id | Conceito | pt-BR | Ontologia | Categoria UFO |"), "|---|---|---|---|---|"]
    for cid, name, label, oid, cat in rows:
        L.append(f"| `{cid}` | {name} | {label} | [{oid}]({oid}.md) | `{cat}` |")
    L.append(f"\n{t('[← Rede de ontologias](README.md)')}\n")
    return write(i.caminho(out, "ontology/concept-index.md"), montar(i, L))


def gen_mappings_doc(kb, out, lang="pt"):
    """Catálogo de mapeamentos, com equivalência, justificativa e limitações."""
    i = Idioma(lang)
    t = i.t
    L = [f"# {t('Mapeamentos semânticos')}\n",
         t("Como cada entidade das ferramentas externas se relaciona com os conceitos da rede.") + "\n",
         t("Nenhum dado externo entra no domínio sem um mapeamento declarado, com grau de "
           "equivalência, justificativa e limitações explícitas. Semelhança de nome nunca basta.") + "\n"]
    L.append(t("| Origem | Entidade | Ontologia | Conceito | Equivalência | Status |"))
    L.append("|---|---|---|---|---|---|")
    for d in sorted(kb["mappings"], key=lambda x: x["mapping"]["id"]):
        s, tg, sem = d["source"], d["target"], d["semantics"]
        L.append(f"| {s['provider']} | `{s['entity']}` | `{tg['ontology']}` | `{tg['concept']}` | "
                 f"{sem['equivalence']} | {d['mapping']['status']} |")

    L.append(f"\n## {t('Justificativas e limitações')}\n")
    for d in sorted(kb["mappings"], key=lambda x: x["mapping"]["id"]):
        m, s, tg, sem = d["mapping"], d["source"], d["target"], d["semantics"]
        L.append(f"### `{m['id']}`\n")
        L.append(f"**{s['provider']}.{s['entity']} → {tg['concept']}** · {t('equivalência')} "
                 f"*{sem['equivalence']}* · {t('versão')} {m['version']} · status *{m['status']}*\n")
        L.append(f"{i.texto(sem['justification'])}\n")
        L.append(f"**{t('Limitações')}**\n")
        for lim in d.get("limitations") or []:
            L.append(f"- {i.texto(lim, cru=True)}")
        L.append("")
    return write(i.caminho(out, "integrations/mappings.md"), montar(i, L))


def gen_metrics_doc(kb, out, lang="pt"):
    """Necessidades de informação e medidas, com fórmulas e limitações."""
    i = Idioma(lang)
    t = i.t
    L = [f"# {t('Necessidades de informação e medidas')}\n",
         t("Nenhuma medida existe sem uma necessidade de informação declarada, e nenhum "
           "dashboard existe sem medida rastreável até esta página.") + "\n"]
    L.append(f"## {t('Necessidades de informação')}\n")
    for n in sorted(kb["needs"], key=lambda x: x["id"]):
        L.append(f"### `{n['id']}` — {i.texto(n['name'])}\n")
        L.append(f"**{t('Pergunta.')}** {i.texto(n['question'])}\n")
        L.append(f"**{t('Decisão apoiada.')}** {i.texto(n.get('decision_supported', ''))}\n")
        L.append(f"**{t('Stakeholders.')}** {', '.join(n.get('stakeholders') or [])}\n")
        L.append(f"**{t('Conceitos necessários.')}** "
                 + ", ".join(f"`{c}`" for c in n.get("required_concepts") or []) + "\n")
        L.append(f"**{t('Medidas candidatas.')}** "
                 + ", ".join(f"`{c}`" for c in n.get("candidate_measurements") or []) + "\n")

    L.append(f"## {t('Medidas')}\n")
    for m in sorted(kb["measurements"], key=lambda x: x["id"]):
        L.append(f"### `{m['id']}` — {i.texto(m['name'])}\n")
        L.append(f"{t('Responde a:')} {', '.join(f'`{x}`' for x in m['answers_information_need'])}\n")
        f = m["formula"]
        L.append(f"```text\n{f['expression']}\n```\n")
        L.append(f"{t('Tipo:')} `{m['value_type']}` · {t('unidade:')} `{m.get('unit', '—')}` · "
                 f"{t('níveis:')} {', '.join(m['scope']['levels'])}\n")
        L.append(f"**{t('Limitações')}**\n")
        for lim in m.get("limitations") or []:
            L.append(f"- {i.texto(lim, cru=True)}")
        if m.get("misinterpretations"):
            L.append(f"\n**{t('Interpretações incorretas possíveis')}**\n")
            for mi in m["misinterpretations"]:
                L.append(f"- {i.texto(mi, cru=True)}")
        L.append("")
    return write(i.caminho(out, "metrics/README.md"), montar(i, L))


def gerar(kb, out, langs):
    """Todas as páginas, em cada idioma pedido; devolve os caminhos escritos."""
    written = []
    for lang in langs:
        written.append(gen_network_readme(kb, out, lang))
        for oid in kb["ontologies"]:
            written.append(gen_ontology_page(kb, oid, out, lang))
        written.append(gen_concept_index(kb, out, lang))
        written.append(gen_mappings_doc(kb, out, lang))
        written.append(gen_metrics_doc(kb, out, lang))
    return written


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kb", default="priv/knowledge_base")
    ap.add_argument("--out", default="docs")
    # Os dois por padrão: gerar só o PT é o caminho pelo qual o EN envelhece calado.
    ap.add_argument("--lang", choices=["all", "pt", "en"], default="all")
    args = ap.parse_args()

    langs = ["pt", "en"] if args.lang == "all" else [args.lang]
    written = gerar(load_kb(args.kb), args.out, langs)

    print(f"{len(written)} arquivos gerados:")
    for p in written:
        print("  ", p)


if __name__ == "__main__":
    main()
