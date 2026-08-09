#!/usr/bin/env python3
"""Deriva o modelo de informação a partir da ontologia.

Aplica a estratégia one table per kind de Guidoni, Almeida & Guizzardi (2020),
conforme declarado em priv/knowledge_base/transformations/ e decidido na ADR 0004.

    Passo 1  Flattening  não-sortais achatados em direção aos sortais
    Passo 2  Lifting     sortais não-kind elevados até seus kinds
    Passo 3  Tabelas     uma tabela por classe remanescente

Refinamento adotado além do paper (ADR 0004): role é relacionalmente dependente,
então materializa por relator; phase é mudança intrínseca, então materializa por
discriminador.

Uso: python3 scripts/derive_information_model.py [--ontology eo]
"""

import argparse
import glob
import sys
from collections import defaultdict

try:
    import yaml
except ImportError:
    sys.exit("PyYAML necessário: pip install -r scripts/requirements.txt")

KB = "priv/knowledge_base"

NON_SORTAL = {"category", "role_mixin", "mixin"}
ANTI_RIGID_SORTAL = {"role", "phase"}
KIND_LIKE = {"kind", "relator"}

IRREGULAR_PLURAL = {
    "person": "people",
    "child": "children",
    "man": "men",
    "woman": "women",
    "datum": "data",
    "criterion": "criteria",
    "analysis": "analyses",
    "index": "indices",
}


def pluralize(name):
    """Nome de tabela a partir do nome do conceito.

    Plural irregular importa: eo_persons é errado em inglês, e o esquema é lido
    por gente.
    """
    base = name.lower().replace(" ", "_").replace("-", "_")
    head, _, last = base.rpartition("_")
    if last in IRREGULAR_PLURAL:
        last = IRREGULAR_PLURAL[last]
    elif last.endswith(("s", "x", "z", "ch", "sh")):
        last += "es"
    elif last.endswith("y") and len(last) > 1 and last[-2] not in "aeiou":
        last = last[:-1] + "ies"
    else:
        last += "s"
    return f"{head}_{last}" if head else last


def load_concepts():
    concepts, relations = {}, []
    for f in glob.glob(f"{KB}/ontology/**/modules/*.yaml", recursive=True):
        d = yaml.safe_load(open(f, encoding="utf-8"))
        for c in d.get("concepts") or []:
            concepts[c["id"]] = (d["module"]["ontology"], c)
        for r in d.get("relations") or []:
            relations.append((d["module"]["ontology"], r))
    return concepts, relations


def stereotype(c):
    return (c.get("classification") or {}).get("ontouml_stereotype")


def parent_of(c):
    cl = c.get("classification") or {}
    return cl.get("parent")


def derive(ontology, concepts, relations):
    scope = {cid: c for cid, (o, c) in concepts.items()}
    owned = {cid for cid, (o, _) in concepts.items() if o == ontology}
    unclassified = [cid for cid in owned if not stereotype(scope[cid])]
    if unclassified:
        return None, unclassified

    children = defaultdict(list)
    for cid, c in scope.items():
        p = parent_of(c)
        if p in scope:
            children[p].append(cid)

    tables, absorbed, notes, extensions, contributes = {}, {}, [], {}, {}

    for cid in owned:
        c = scope[cid]
        st = stereotype(c)

        # Passo 1 — não-sortal é achatado, não vira tabela
        if st in NON_SORTAL:
            absorbed[cid] = ("flattened", parent_of(c) or "—")
            notes.append(f"{cid}: não-sortal achatado para as subclasses sortais")
            continue

        # Passo 2 — sortal antirrígido é elevado até o kind
        if st in ANTI_RIGID_SORTAL:
            k = cid
            while stereotype(scope[k]) not in KIND_LIKE:
                nxt = (scope[k]["classification"].get("is_role_of")
                       or parent_of(scope[k]))
                if nxt not in scope:
                    break
                k = nxt
            absorbed[cid] = ("lifted", k)
            continue

        if st == "subkind":
            k = cid
            while stereotype(scope[k]) == "subkind":
                nxt = parent_of(scope[k])
                if nxt not in scope:
                    break
                k = nxt
            absorbed[cid] = ("lifted", k)
            continue

        # Passo 3 — kind e relator viram tabela
        if st in KIND_LIKE:
            tables[cid] = {
                "table": f"{ontology}_{pluralize(c['name'])}",
                "stereotype": st,
                "attributes": list(c.get("attributes") or []),
                "discriminators": [],
                "foreign_keys": [],
            }

    # discriminadores vindos do lifting de subkind e phase
    for cid, (how, target) in list(absorbed.items()):
        if how != "lifted":
            continue
        st = stereotype(scope[cid])

        # Kind em outra ontologia: é o caso da referência. O subtipo contribui
        # com um valor de discriminador na tabela dela, e se tiver atributos
        # próprios ganha tabela de extensão aqui, ligada por chave estrangeira.
        if target not in tables:
            own = scope[cid].get("attributes") or []
            contributes.setdefault(target, []).append(cid.split(".")[-1])
            if own:
                extensions[cid] = {
                    "table": f"{ontology}_{pluralize(scope[cid]['name'])}",
                    "extends": target,
                    "external": True,
                    "attributes": list(own),
                    "discriminator_value": cid.split(".")[-1],
                }
            continue
        if st in ("subkind", "phase"):
            name = "type" if st == "subkind" else "status"
            disc = next((d for d in tables[target]["discriminators"]
                         if d["name"] == name), None)
            if not disc:
                disc = {"name": name, "values": [], "form": "enum"}
                tables[target]["discriminators"].append(disc)
            disc["values"].append(cid.split(".")[-1])
        elif st == "role":
            # ADR 0004: role é relacional — não vira coluna, espera relator
            notes.append(
                f"{cid}: role elevado a {target}; materializa pelo relator, "
                f"não por discriminador")
        # Atributos próprios não sobem para o kind: viram tabela de extensão na
        # ontologia dona, ligada por FK. Mantém a tabela base estreita e permite
        # que uma ontologia nova se acople sem alterar o que já existe.
        own = scope[cid].get("attributes") or []
        if own:
            extensions[cid] = {
                "table": f"{cid.split('.')[0]}_{pluralize(scope[cid]['name'])}",
                "extends": target,
                "attributes": list(own),
                "discriminator_value": cid.split(".")[-1],
            }

    # parthood vira chave estrangeira na tabela da parte, não discriminador
    for o, r in relations:
        if o != ontology or r.get("type") != "part_whole":
            continue
        src, tgt = r.get("source"), r.get("target")
        if src in tables and tgt in tables:
            card = (r.get("cardinality") or {}).get("target", "one")
            fk = f"{tgt.split('.')[-1]}_id"
            if src == tgt:
                fk = f"parent_{fk}"
            tables[src]["foreign_keys"].append(
                {"column": fk, "required": card == "one", "kind": "parthood"})
            notes.append(f"{r['id']}: parthood → {tables[src]['table']}.{fk}")

    # chaves estrangeiras dos relators, a partir das relações declaradas
    for o, r in relations:
        if o != ontology:
            continue
        src = r.get("source")
        if src in tables and tables[src]["stereotype"] == "relator":
            tgt = r.get("target")
            root = absorbed.get(tgt, (None, tgt))[1] if tgt in absorbed else tgt
            if root in tables:
                fk = f"{root.split('.')[-1]}_id"
                if not any(x["column"] == fk for x in tables[src]["foreign_keys"]):
                    tables[src]["foreign_keys"].append(
                        {"column": fk, "required": True, "kind": "mediation"})

    return (tables, absorbed, notes, extensions, contributes), None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ontology", default="eo")
    args = ap.parse_args()

    concepts, relations = load_concepts()
    result, missing = derive(args.ontology, concepts, relations)

    if missing:
        print(f"não é possível derivar {args.ontology}: "
              f"{len(missing)} conceito(s) sem ontouml_stereotype\n")
        for m in missing:
            print("  ", m)
        return 1

    tables, absorbed, notes, extensions, contributes = result
    total = sum(1 for cid, (o, _) in concepts.items() if o == args.ontology)

    print(f"═══ modelo de informação: {args.ontology.upper()} ═══\n")
    print(f"{total} conceitos → {len(tables)} tabelas\n")

    for cid, t in sorted(tables.items()):
        print(f"┌─ {t['table']}   ({cid}, {t['stereotype']})")
        for a in t["attributes"]:
            req = "NOT NULL" if a.get("required") else "NULL    "
            origem = f"  ← {a['from_subtype']}" if a.get("from_subtype") else ""
            print(f"│    {a['name']:22s} {a['type']:9s} {req}{origem}")
        for d in t["discriminators"]:
            print(f"│    {d['name']:22s} {'enum':9s} NOT NULL  "
                  f"{{{', '.join(d['values'])}}}")
        for fk in t["foreign_keys"]:
            req = "NOT NULL" if fk["required"] else "NULL    "
            print(f"│    {fk['column']:22s} {'uuid':9s} {req}  → FK ({fk['kind']})")
        print("└─")
        print()

    if extensions:
        print("tabelas de extensão (atributos próprios do subtipo):\n")
        for cid, e in sorted(extensions.items()):
            ref = "outra ontologia" if e.get("external") else "mesma ontologia"
            print(f"┌─ {e['table']}   (estende {e['extends']} [{ref}] "
                  f"onde type='{e['discriminator_value']}')")
            fk = e["extends"].split(".")[-1] + "_id"
            print(f"│    {fk:22s} {'uuid':9s} NOT NULL  → FK (extension)")
            for a in e["attributes"]:
                req = "NOT NULL" if a.get("required") else "NULL    "
                print(f"│    {a['name']:22s} {a['type']:9s} {req}")
            print("└─")
            print()

    if contributes:
        print("valores de discriminador contribuídos a kinds de outras ontologias:\n")
        for target, vals in sorted(contributes.items()):
            print(f"   {target}.type += {{{', '.join(sorted(vals))}}}")
        print()

    print("absorvidos (não viram tabela):")
    for cid, (how, target) in sorted(absorbed.items()):
        print(f"   {cid:32s} {how:9s} → {target}")

    if notes:
        print("\nnotas:")
        for n in notes:
            print(f"   {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
