#!/usr/bin/env python3
"""Gera a documentação das ontologias a partir da base de conhecimento.

Precursor da Mix task knowledge.docs. A base YAML é a fonte da verdade; os
arquivos em docs/ontology/ são derivados e NÃO devem ser editados à mão —
alterá-los faz a documentação divergir do modelo.

Gera:
  docs/ontology/README.md          visão da rede, camadas e dependências
  docs/ontology/<id>.md            uma página por ontologia
  docs/ontology/concept-index.md   índice alfabético de todos os conceitos
  docs/integrations/mappings.md    catálogo dos mapeamentos semânticos

Uso: python3 scripts/generate_docs.py [--kb priv/knowledge_base] [--out docs]
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

BANNER = ("<!-- GERADO POR scripts/generate_docs.py A PARTIR DE priv/knowledge_base/. "
          "NÃO EDITE À MÃO. -->\n\n")

NETWORK_LABEL = {"ufo": "UFO", "seon": "SEON", "continuum": "Continuum"}
LAYER_LABEL = {"foundational": "Fundacional", "core": "Core", "domain": "Domínio"}


def load_kb(root):
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
    """Extrai o texto pt-BR de um campo bilíngue."""
    if isinstance(node, dict):
        return (node.get("pt-BR") or node.get("en") or default).strip()
    return (node or default).strip() if isinstance(node, str) else default


def anchor(concept_id):
    return concept_id.replace(".", "").replace("_", "-")


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write(content)
    return path


# --------------------------------------------------------------------------- #

def gen_network_readme(kb, out):
    onts = kb["ontologies"]
    by_net = defaultdict(list)
    for oid, (d, _) in sorted(onts.items()):
        by_net[d["ontology"]["network"]].append((oid, d["ontology"]))

    lines = [BANNER, "# Rede de ontologias\n",
             "Documentação gerada a partir de `priv/knowledge_base/`. "
             "A base YAML é a fonte da verdade; esta página é derivada dela.\n"]

    total_c = sum(len(m.get("concepts") or []) for ms in kb["modules"].values() for m in ms)
    total_r = sum(len(m.get("relations") or []) for ms in kb["modules"].values() for m in ms)
    total_q = sum(len(v) for v in kb["cqs"].values())
    lines.append(f"**{len(onts)} ontologias · {total_c} conceitos · {total_r} relações · "
                 f"{total_q} perguntas de competência**\n")

    lines.append("## Arquitetura\n")
    lines.append("```mermaid\ngraph TD")
    for oid, (d, _) in sorted(onts.items()):
        o = d["ontology"]
        lines.append(f'  {oid}["{o["acronym"]}<br/><small>{o["name"]}</small>"]')
    for oid, (d, _) in sorted(onts.items()):
        for dep in d.get("dependencies") or []:
            lines.append(f"  {oid} --> {dep}")
    lines.append("```\n")
    lines.append("Cada seta significa *reusa conceitos de*. A direção vai sempre do módulo "
                 "mais específico para o mais geral; o caminho inverso é proibido e "
                 "verificado por `scripts/validate_knowledge_base.py`.\n")

    lines.append("## Ontologias\n")
    lines.append("| Ontologia | Camada | Rede | Depende de | Conceitos | Relações | CQs |")
    lines.append("|---|---|---|---|---:|---:|---:|")
    for oid, (d, _) in sorted(onts.items(), key=lambda kv: (
            ["foundational", "core", "domain"].index(kv[1][0]["ontology"]["layer"]), kv[0])):
        o = d["ontology"]
        mods = kb["modules"].get(oid, [])
        nc = sum(len(m.get("concepts") or []) for m in mods)
        nr = sum(len(m.get("relations") or []) for m in mods)
        deps = ", ".join(f"`{x}`" for x in (d.get("dependencies") or [])) or "—"
        lines.append(f"| [{o['acronym']}]({oid}.md) — {o['name']} | {LAYER_LABEL[o['layer']]} | "
                     f"{NETWORK_LABEL[o['network']]} | {deps} | {nc} | {nr} | {len(kb['cqs'].get(oid, []))} |")

    lines.append("\n## Distinções que o modelo preserva\n")
    lines.append("| Não confunda | Por quê |")
    lines.append("|---|---|")
    for a, b in [
        ("Pull Request ≠ Merge", "PR é solicitação de mudança (`cmpo.change_request`); merge é evento distinto"),
        ("Pessoa ≠ Membro de equipe", "`eo.team_member` é papel; `eo.team_membership` é a relação contextual"),
        ("Processo planejado ≠ executado", "SPO separa `intended_*` de `performed_*`"),
        ("Código ≠ Programa", "código constitui o programa sem ser idêntico a ele"),
        ("Documento de requisito ≠ Requisito", "o artefato descreve o requisito, não é o requisito"),
        ("Caso de teste ≠ Execução de teste", "ROoST separa planejamento de execução"),
        ("Code smell ≠ Defeito", "não conformidade (QAPO) não é defeito (OSDEF)"),
        ("Defect ≠ Fault ≠ Failure", "failure é evento; defect é disposição; fault é o defeito manifestado"),
    ]:
        lines.append(f"| {a} | {b} |")

    if kb["manifest"]:
        p = kb["manifest"]["knowledge_base"].get("provenance") or {}
        lines.append("\n## Origem\n")
        lines.append(f"{p.get('author', '')}. *{pt(p.get('title', ''))}*. "
                     f"{p.get('institution', '')}, {p.get('year', '')}.\n")

    return write(f"{out}/ontology/README.md", "\n".join(lines) + "\n")


def gen_ontology_page(kb, oid, out):
    d, _ = kb["ontologies"][oid]
    o = d["ontology"]
    mods = kb["modules"].get(oid, [])
    mod_by_id = {m["module"]["id"]: m for m in mods}
    ordered = [mod_by_id[f"{oid}.{name}"] for name in (d.get("modules") or [])
               if f"{oid}.{name}" in mod_by_id]

    L = [BANNER, f"# {o['acronym']} — {o['name']}\n"]
    L.append(f"> {pt(o.get('description', ''))}\n")
    L.append("| | |")
    L.append("|---|---|")
    L.append(f"| **Id** | `{o['id']}` |")
    L.append(f"| **Versão** | {o['version']} |")
    L.append(f"| **Camada** | {LAYER_LABEL[o['layer']]} |")
    L.append(f"| **Rede** | {NETWORK_LABEL[o['network']]} |")
    L.append(f"| **Namespace** | `{o['namespace']}` |")
    deps = d.get("dependencies") or []
    L.append(f"| **Depende de** | {', '.join(f'[{x}]({x}.md)' for x in deps) or '—'} |")
    prov = d.get("provenance") or {}
    ref = prov.get("reference", "")
    L.append(f"| **Origem** | {ref or prov.get('source_type', '')} |")
    if prov.get("note"):
        L.append(f"\n> **Nota.** {prov['note'].strip()}\n")

    L.append("\n## Módulos\n")
    for m in ordered:
        mid = m["module"]["id"].split(".", 1)[1]
        desc = pt(m["module"].get("description", ""))
        L.append(f"- **[{m['module']['name']}](#{anchor(mid)})** — {desc or 'conceitos e relações do módulo.'}")

    for m in ordered:
        mid = m["module"]["id"].split(".", 1)[1]
        L.append(f"\n---\n\n## {m['module']['name']}\n")
        L.append(f'<a id="{anchor(mid)}"></a>\n')
        if pt(m["module"].get("description", "")):
            L.append(f"{pt(m['module']['description'])}\n")
        mp = m["module"].get("provenance") or {}
        if mp.get("reference"):
            L.append(f"*Fonte: {mp['reference']}*\n")

        concepts = m.get("concepts") or []
        if concepts:
            L.append("### Conceitos\n")
            for c in concepts:
                cls = c.get("classification") or {}
                L.append(f"#### `{c['id']}` — {c['name']}\n")
                if c.get("label"):
                    L.append(f"*{pt(c['label'])}*\n")
                L.append(f"{pt(c.get('definition', ''))}\n")
                meta = [f"categoria UFO: `{cls.get('ufo_category')}`"]
                if cls.get("parent"):
                    meta.append(f"especializa `{cls['parent']}`")
                if cls.get("is_role_of"):
                    meta.append(f"papel de `{cls['is_role_of']}`")
                if c.get("automated"):
                    meta.append("automatizado")
                L.append(f"<sub>{' · '.join(meta)}</sub>\n")
                if c.get("attributes"):
                    L.append("| Atributo | Tipo | Obrigatório |")
                    L.append("|---|---|---|")
                    for a in c["attributes"]:
                        L.append(f"| `{a['name']}` | {a['type']} | {'sim' if a.get('required') else 'não'} |")
                    L.append("")
                if c.get("examples"):
                    L.append("Exemplos: " + "; ".join(f"*{e}*" for e in c["examples"]) + "\n")

        relations = m.get("relations") or []
        if relations:
            L.append("### Relações\n")
            L.append("| Relação | Origem | Destino | Cardinalidade | Tipo |")
            L.append("|---|---|---|---|---|")
            for r in relations:
                card = r.get("cardinality") or {}
                c_txt = f"{card.get('source', '?')} → {card.get('target', '?')}"
                L.append(f"| `{r['name']}` | `{r['source']}` | `{r['target']}` | {c_txt} | {r.get('type', '—')} |")
            L.append("")
            for r in relations:
                sem = (r.get("semantics") or {}).get("description")
                if sem:
                    L.append(f"- **`{r['id']}`** — {sem.strip()}")
            L.append("")

    cqs = kb["cqs"].get(oid, [])
    if cqs:
        L.append("\n---\n\n## Perguntas de competência\n")
        L.append("Perguntas que esta ontologia precisa saber responder. "
                 "São os requisitos funcionais do modelo, verificados por `mix knowledge.test`.\n")
        L.append("| # | Pergunta | Conceitos envolvidos |")
        L.append("|---|---|---|")
        for q in cqs:
            cs = ", ".join(f"`{c}`" for c in (q.get("concepts") or [])[:4])
            if len(q.get("concepts") or []) > 4:
                cs += ", …"
            L.append(f"| `{q['id'].split('.')[-1].upper()}` | {pt(q['question'])} | {cs} |")
        L.append("")
        for q in cqs:
            if q.get("rationale"):
                L.append(f"- **{q['id'].split('.')[-1].upper()}** — {q['rationale'].strip()}")
        L.append("")

    L.append("\n---\n\n[← Rede de ontologias](README.md)\n")
    return write(f"{out}/ontology/{oid}.md", "\n".join(L) + "\n")


def gen_concept_index(kb, out):
    rows = []
    for oid, mods in kb["modules"].items():
        for m in mods:
            for c in m.get("concepts") or []:
                rows.append((c["id"], c["name"], pt(c.get("label", "")), oid,
                             (c.get("classification") or {}).get("ufo_category", "")))
    rows.sort()
    L = [BANNER, "# Índice de conceitos\n",
         f"{len(rows)} conceitos na rede, em ordem alfabética de identificador.\n",
         "| Id | Conceito | pt-BR | Ontologia | Categoria UFO |", "|---|---|---|---|---|"]
    for cid, name, label, oid, cat in rows:
        L.append(f"| `{cid}` | {name} | {label} | [{oid}]({oid}.md) | `{cat}` |")
    L.append("\n[← Rede de ontologias](README.md)\n")
    return write(f"{out}/ontology/concept-index.md", "\n".join(L) + "\n")


def gen_mappings_doc(kb, out):
    L = [BANNER, "# Mapeamentos semânticos\n",
         "Como cada entidade das ferramentas externas se relaciona com os conceitos da rede.\n",
         "Nenhum dado externo entra no domínio sem um mapeamento declarado, com grau de "
         "equivalência, justificativa e limitações explícitas. Semelhança de nome nunca basta.\n"]
    L.append("| Origem | Entidade | Ontologia | Conceito | Equivalência | Status |")
    L.append("|---|---|---|---|---|---|")
    for d in sorted(kb["mappings"], key=lambda x: x["mapping"]["id"]):
        s, t, sem = d["source"], d["target"], d["semantics"]
        L.append(f"| {s['provider']} | `{s['entity']}` | `{t['ontology']}` | `{t['concept']}` | "
                 f"{sem['equivalence']} | {d['mapping']['status']} |")

    L.append("\n## Justificativas e limitações\n")
    for d in sorted(kb["mappings"], key=lambda x: x["mapping"]["id"]):
        m, s, t, sem = d["mapping"], d["source"], d["target"], d["semantics"]
        L.append(f"### `{m['id']}`\n")
        L.append(f"**{s['provider']}.{s['entity']} → {t['concept']}** · equivalência "
                 f"*{sem['equivalence']}* · versão {m['version']} · status *{m['status']}*\n")
        L.append(f"{sem['justification'].strip()}\n")
        L.append("**Limitações**\n")
        for lim in d.get("limitations") or []:
            L.append(f"- {lim}")
        L.append("")
    return write(f"{out}/integrations/mappings.md", "\n".join(L) + "\n")


def gen_metrics_doc(kb, out):
    L = [BANNER, "# Necessidades de informação e medidas\n",
         "Nenhuma medida existe sem uma necessidade de informação declarada, e nenhum "
         "dashboard existe sem medida rastreável até esta página.\n"]
    L.append("## Necessidades de informação\n")
    for n in sorted(kb["needs"], key=lambda x: x["id"]):
        L.append(f"### `{n['id']}` — {pt(n['name'])}\n")
        L.append(f"**Pergunta.** {pt(n['question'])}\n")
        L.append(f"**Decisão apoiada.** {pt(n.get('decision_supported', ''))}\n")
        L.append(f"**Stakeholders.** {', '.join(n.get('stakeholders') or [])}\n")
        L.append("**Conceitos necessários.** " + ", ".join(f"`{c}`" for c in n.get("required_concepts") or []) + "\n")
        L.append("**Medidas candidatas.** " + ", ".join(f"`{c}`" for c in n.get("candidate_measurements") or []) + "\n")

    L.append("## Medidas\n")
    for m in sorted(kb["measurements"], key=lambda x: x["id"]):
        L.append(f"### `{m['id']}` — {pt(m['name'])}\n")
        L.append(f"Responde a: {', '.join(f'`{x}`' for x in m['answers_information_need'])}\n")
        f = m["formula"]
        L.append(f"```text\n{f['expression']}\n```\n")
        L.append(f"Tipo: `{m['value_type']}` · unidade: `{m.get('unit', '—')}` · "
                 f"níveis: {', '.join(m['scope']['levels'])}\n")
        L.append("**Limitações**\n")
        for lim in m.get("limitations") or []:
            L.append(f"- {lim}")
        if m.get("misinterpretations"):
            L.append("\n**Interpretações incorretas possíveis**\n")
            for mi in m["misinterpretations"]:
                L.append(f"- {mi}")
        L.append("")
    return write(f"{out}/metrics/README.md", "\n".join(L) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kb", default="priv/knowledge_base")
    ap.add_argument("--out", default="docs")
    args = ap.parse_args()

    kb = load_kb(args.kb)
    written = [gen_network_readme(kb, args.out)]
    for oid in kb["ontologies"]:
        written.append(gen_ontology_page(kb, oid, args.out))
    written.append(gen_concept_index(kb, args.out))
    written.append(gen_mappings_doc(kb, args.out))
    written.append(gen_metrics_doc(kb, args.out))

    print(f"{len(written)} arquivos gerados:")
    for p in written:
        print("  ", p)


if __name__ == "__main__":
    main()
