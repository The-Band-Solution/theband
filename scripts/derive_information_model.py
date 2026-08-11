#!/usr/bin/env python3
"""Deriva o modelo de informação a partir da rede de ontologias.

Implementa a estratégia ``one table per kind`` de Guidoni, Almeida & Guizzardi
(2020), acrescida das extensões deste projeto para redes de ontologias e views.
As regras não vivem aqui: são declaradas em
``priv/knowledge_base/transformations/ontology_to_information_model.yaml`` e
decididas na ADR 0004. Este módulo apenas as executa.

Por que a redução existe
------------------------
A ontologia descreve o que existe no mundo real; o modelo de informação, o que
pode ser armazenado e trocado — a distinção é de Carraretto (2012). Sem ela,
cada distinção metafísica viraria uma tabela: 220 conceitos produziriam 220
tabelas, a maioria sem estrutura própria.

Os cinco passos
---------------
1. **Flattening** — não-sortais (``category``, ``role_mixin``, ``mixin``) são
   achatados. Classificam indivíduos de kinds diferentes, então não há tabela
   possível para eles sem misturar princípios de identidade.
2. **Lifting** — sortais que não são kinds (``subkind``, ``role``, ``phase``)
   sobem até o kind que lhes dá identidade.
3. **Tabelas** — uma por classe remanescente; dependentes ganham chave
   estrangeira.
4. **Rede** (extensão nossa, ADR 0004 D9) — o kind mora na ontologia que o
   define; as demais referenciam, contribuem discriminador e estendem.
5. **Views** (extensão nossa, ADR 0004 D10) — cada conceito absorvido reaparece
   como view com o seu nome.

O que decide cada caso
----------------------
Duas meta-propriedades, e só elas: **sortalidade** (fornece princípio de
identidade próprio?) e **rigidez** (vale para o indivíduo em toda a sua
existência?). O campo ``ontouml_stereotype`` de cada conceito as expressa; sem
ele, a derivação falha em vez de adivinhar.

Refinamento além do paper (ADR 0004 D5): ``role`` é relacionalmente dependente e
materializa por relator, enquanto ``phase`` é mudança intrínseca e materializa
por discriminador. Um booleano ``is_under_integration`` registraria a
classificação e perderia em qual processo, desde quando, e se há mais de um.

Uso
---
::

    python3 scripts/derive_information_model.py --ontology eo

Saída: tabelas, tabelas de extensão, valores de discriminador contribuídos a
kinds de outras ontologias, e a lista do que foi absorvido e por quê.

Estado
------
Precursor de ``mix knowledge.information_model``. Ver ``scripts/README.md``
quanto à intenção de extrair isto como biblioteca independente.
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

#: Não-sortais: classificam indivíduos de kinds diferentes, são abstratos e só
#: se instanciam por suas subclasses sortais. Eliminados no passo 1.
NON_SORTAL = {"category", "role_mixin", "mixin"}

#: Sortais antirrígidos: valem contingentemente e especializam exatamente um
#: kind, do qual herdam o princípio de identidade. Eliminados no passo 2.
ANTI_RIGID_SORTAL = {"role", "phase"}

#: Os que sobrevivem e viram tabela. ``relator`` é kind de entidade
#: existencialmente dependente, que reifica uma relação.
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
    """Carrega conceitos e relações de todos os módulos da base.

    :returns: ``(concepts, relations)``, onde ``concepts`` mapeia id para
        ``(ontologia, dicionário do conceito)`` e ``relations`` é uma lista de
        ``(ontologia, dicionário da relação)``.
    """
    concepts, relations = {}, []
    # Ordenado de propósito: `glob` devolve na ordem do sistema de arquivos, e a
    # ordem de leitura decide a ordem de `relations` e, por consequência, a ordem
    # das chaves estrangeiras na saída. Derivação tem de ser função da ontologia.
    for f in sorted(glob.glob(f"{KB}/ontology/**/modules/*.yaml", recursive=True)):
        d = yaml.safe_load(open(f, encoding="utf-8"))
        for c in d.get("concepts") or []:
            concepts[c["id"]] = (d["module"]["ontology"], c)
        for r in d.get("relations") or []:
            relations.append((d["module"]["ontology"], r))
    return concepts, relations


def stereotype(c):
    """Estereótipo OntoUML do conceito, ou ``None`` se não declarado.

    É o campo que decide toda a transformação. Distinto de ``ufo_category``, que
    é a categoria de topo e não expressa sortalidade nem rigidez.
    """
    return (c.get("classification") or {}).get("ontouml_stereotype")


def parent_of(c):
    """Supertipo direto do conceito, se houver.

    Para papéis, ``is_role_of`` costuma ser mais preciso: aponta o kind que
    fornece o princípio de identidade, que é o destino do lifting.
    """
    cl = c.get("classification") or {}
    return cl.get("parent")


def derive(ontology, concepts, relations):
    """Aplica os cinco passos e devolve o modelo de informação de uma ontologia.

    :param ontology: id da ontologia a derivar, por exemplo ``"eo"``.
    :param concepts: mapa ``{concept_id: (ontology_id, concept_dict)}`` de toda a
        rede. A rede inteira entra no escopo de leitura, mas só os conceitos da
        ontologia pedida geram tabelas — é o que permite a um subtipo de CMPO ser
        elevado a um kind de SPO sem replicá-lo (ADR 0004, D9).
    :param relations: lista ``[(ontology_id, relation_dict)]`` de toda a rede.

    :returns: ``(resultado, None)`` em caso de sucesso, onde ``resultado`` é a
        tupla ``(tables, absorbed, notes, extensions, contributes)``; ou
        ``(None, faltantes)`` quando algum conceito da ontologia não declara
        ``ontouml_stereotype``. Falhar é deliberado: sem sortalidade e rigidez
        não há como decidir, e adivinhar produziria esquema plausível e errado.

    Os cinco elementos do resultado:

    ``tables``
        Kinds e relators que viram tabela, com atributos, discriminadores e
        chaves estrangeiras.
    ``absorbed``
        ``{conceito: (como, alvo)}`` — o que não virou tabela e para onde foi.
        ``como`` é ``"flattened"`` ou ``"lifted"``.
    ``notes``
        Decisões que merecem explicação na saída, como um role que espera relator.
    ``extensions``
        Tabelas de extensão: subtipos com atributos próprios cujo kind está em
        outra ontologia. Mantêm a tabela do kind estreita.
    ``contributes``
        ``{kind_externo: [valores]}`` — o que esta ontologia acrescenta ao
        discriminador de kinds que não lhe pertencem.
    """
    # A rede inteira é visível para resolver o lifting entre ontologias, mas
    # apenas `owned` produz tabelas — ver ADR 0004, D9.
    scope = {cid: c for cid, (o, c) in concepts.items()}
    # `sorted` e não `set`: iterar um conjunto de strings varia entre execuções por
    # randomização de hash, e essa ordem decide a ordem de inserção em `absorbed`,
    # logo a ordem dos valores de discriminador, das notas e das colunas. Sem isto a
    # derivação não é reproduzível — duas execuções da mesma ontologia davam saídas
    # diferentes, e nenhuma regressão sobre a saída era verificável.
    owned = sorted(cid for cid, (o, _) in concepts.items() if o == ontology)
    unclassified = [cid for cid in owned if not stereotype(scope[cid])]
    if unclassified:
        return None, unclassified

    children = defaultdict(list)
    for cid, c in sorted(scope.items()):
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
            # A regra do role vale igual quando o kind está em outra ontologia. Sem
            # esta guarda, `sro.product_owner` viraria valor de discriminador em
            # `eo.person`, e a tabela de pessoas passaria a afirmar que alguém *é* um
            # Product Owner — o que a ADR 0004 D5 recusa. Papel é alocação: tem
            # contexto e duração, e vive no relator.
            if st == "role":
                notes.append(
                    f"{cid}: role elevado a {target} [outra ontologia]; materializa "
                    f"pelo relator, não por discriminador")
                continue

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

    # associação com destino em kind e cardinalidade many → one vira chave
    # estrangeira na tabela do kind de origem — regra t3d.association_foreign_keys.
    #
    # Sem ela, declarar a relação não produz coluna: a tese cobre parthood e
    # dependência de relator, e associação simples ficava de fora. Foi essa ausência
    # que levou alguém a escrever a coluna à mão, contra a ADR 0004 D4.
    for o, r in relations:
        if o != ontology or r.get("type") != "association":
            continue

        card = r.get("cardinality") or {}
        if card.get("target") != "one":
            # many → many exigiria tabela associativa, que é decisão de modelagem e
            # não de tradução. Fica de fora até virar regra própria.
            continue

        src, tgt = r.get("source"), r.get("target")

        # O destino precisa ter tabela própria: subkind não tem para onde apontar.
        if tgt not in tables:
            continue

        # Papel não vira coluna (ADR 0004, D5 e D6): materializa pelo relator, e o
        # relator já recebe as chaves por mediação. A relação de um papel com o kind
        # que lhe dá identidade — `eo.team_member_is_person` — é identidade, não
        # referência: gerar `eo_people.person_id` a partir dela faria a tabela
        # apontar para si mesma e sugeriria uma hierarquia que não existe.
        if src in scope and stereotype(scope[src]) == "role":
            continue

        # A origem pode ser o próprio kind ou um subkind elevado até ele. Quando é
        # elevado, a chave nasce anulável e a obrigatoriedade vira check_constraint
        # ligada ao discriminador — uma chave obrigatória na tabela do kind
        # forçaria todos os subtipos a tê-la, e isso é falso.
        elevado = absorbed.get(src, (None, None))
        raiz = elevado[1] if elevado[0] == "lifted" else src
        if raiz not in tables:
            continue

        # Origem elevada ao próprio destino é identidade, não referência. A coluna
        # apontaria a tabela para si mesma sem que nenhuma hierarquia exista.
        if raiz == tgt:
            continue

        # Relator já recebe chave por mediação, no laço seguinte. Gerar aqui também
        # produziria a mesma coluna com duas origens declaradas.
        if tables[raiz]["stereotype"] == "relator":
            continue

        fk = f"{tgt.split('.')[-1]}_id"
        if any(x["column"] == fk for x in tables[raiz]["foreign_keys"]):
            continue

        entrada = {"column": fk, "required": raiz == src, "kind": "association"}

        if raiz != src:
            valor = src.split(".")[-1]
            disc = next((d["name"] for d in tables[raiz]["discriminators"]
                         if valor in d["values"]), None)
            if disc:
                entrada["check"] = f"{fk} IS NOT NULL OR {disc} <> '{valor}'"
                notes.append(
                    f"{r['id']}: associação → {tables[raiz]['table']}.{fk} anulável, "
                    f"obrigatória quando {disc}='{valor}'")
            else:
                # Sem discriminador não há a que ligar a obrigatoriedade. A coluna
                # existe e a restrição fica declarada como ausente, em vez de
                # inventada.
                notes.append(
                    f"{r['id']}: associação → {tables[raiz]['table']}.{fk} anulável, "
                    f"sem discriminador para restringir a obrigatoriedade")
        else:
            notes.append(f"{r['id']}: associação → {tables[raiz]['table']}.{fk}")

        tables[raiz]["foreign_keys"].append(entrada)

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
    """Entrada de linha de comando: deriva uma ontologia e imprime o resultado."""
    ap = argparse.ArgumentParser()
    ap.add_argument("--ontology", default="eo")
    args = ap.parse_args()

    concepts, relations = load_concepts()
    result, missing = derive(args.ontology, concepts, relations)

    if missing:
        print(f"não é possível derivar {args.ontology}: "
              f"{len(missing)} conceito(s) sem ontouml_stereotype\n")
        for m in sorted(missing):
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
        for fk in t["foreign_keys"]:
            if fk.get("check"):
                print(f"│    check: {fk['check']}")
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
