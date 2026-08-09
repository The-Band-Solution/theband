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
    scope = {cid: c for cid, (o, c) in concepts.items() if o == ontology}
    unclassified = [cid for cid, c in scope.items() if not stereotype(c)]
    if unclassified:
        return None, unclassified

    children = defaultdict(list)
    for cid, c in scope.items():
        p = parent_of(c)
        if p in scope:
            children[p].append(cid)

    tables, absorbed, notes = {}, {}, []

    for cid, c in scope.items():
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
                "table": f"{ontology}_{c['name'].lower().replace(' ', '_')}s",
                "stereotype": st,
                "attributes": list(c.get("attributes") or []),
                "discriminators": [],
                "foreign_keys": [],
            }

    # discriminadores vindos do lifting de subkind e phase
    for cid, (how, target) in absorbed.items():
        if how != "lifted" or target not in tables:
            continue
        st = stereotype(scope[cid])
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
        # atributos do subtipo sobem como opcionais
        for a in scope[cid].get("attributes") or []:
            opt = dict(a, required=False, from_subtype=cid)
            tables[target]["attributes"].append(opt)

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
                if fk not in tables[src]["foreign_keys"]:
                    tables[src]["foreign_keys"].append(fk)

    return (tables, absorbed, notes), None


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

    tables, absorbed, notes = result
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
            print(f"│    {fk:22s} {'uuid':9s} NOT NULL  → FK")
        print("└─")
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
