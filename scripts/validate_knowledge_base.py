#!/usr/bin/env python3
"""Valida a base de conhecimento em priv/knowledge_base.

Precursor das Mix tasks knowledge.validate e knowledge.graph. Enquanto o projeto
Elixir não existe, este script é a porta de qualidade da base — e o CI o executa.

Verifica:
  1. sintaxe YAML de todos os arquivos;
  2. presença dos campos obrigatórios por tipo de artefato;
  3. integridade referencial (parent, is_role_of, source, target, CQs, medidas);
  4. direção das dependências entre ontologias e ausência de ciclos;
  5. ids únicos e estáveis;
  6. proveniência declarada;
  7. ausência de segredos aparentes.

Uso: python3 scripts/validate_knowledge_base.py [--kb priv/knowledge_base]
Saída: 0 se tudo válido; 1 com a lista de problemas caso contrário.
"""

import argparse
import glob
import os
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML necessário: pip install pyyaml")

SECRET_PATTERNS = [
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"(?i)\b(password|passwd|secret|api[_-]?key|access[_-]?token)\s*:\s*['\"]?[^\s'\"<{]{8,}"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
]

ID_RE = re.compile(r"^[a-z_]+\.[a-z0-9_]+$")


class KB:
    def __init__(self, root):
        self.root = root
        self.problems = []
        self.concepts = {}      # id -> (ontology, concept dict, file)
        self.relations = {}     # id -> (ontology, relation dict, file)
        self.ontologies = {}    # id -> (dict, dir)
        self.information_needs = set()
        self.measurements = {}
        self.derivation_rules = set()

    def fail(self, kind, msg, file=None):
        where = f" ({os.path.relpath(file, self.root)})" if file else ""
        self.problems.append(f"[{kind}] {msg}{where}")

    # ---------- carga ----------

    def load(self):
        files = sorted(glob.glob(f"{self.root}/**/*.yaml", recursive=True))
        docs = {}
        for f in files:
            raw = open(f, encoding="utf-8").read()
            for pat in SECRET_PATTERNS:
                if pat.search(raw):
                    self.fail("secret", "possível segredo no arquivo", f)
                    break
            try:
                docs[f] = yaml.safe_load(raw)
            except yaml.YAMLError as e:
                self.fail("yaml", str(e).splitlines()[0], f)
        self.files = docs
        return len(files)

    def index(self):
        for f, d in self.files.items():
            if not isinstance(d, dict):
                continue
            if "ontology" in d and isinstance(d["ontology"], dict):
                oid = d["ontology"]["id"]
                if oid in self.ontologies:
                    self.fail("duplicate", f"ontologia {oid} declarada duas vezes", f)
                self.ontologies[oid] = (d, os.path.dirname(f))
            if "module" in d:
                o = d["module"]["ontology"]
                for c in d.get("concepts") or []:
                    if c["id"] in self.concepts:
                        self.fail("duplicate", f"conceito {c['id']} duplicado", f)
                    self.concepts[c["id"]] = (o, c, f)
                for r in d.get("relations") or []:
                    if r["id"] in self.relations:
                        self.fail("duplicate", f"relação {r['id']} duplicada", f)
                    self.relations[r["id"]] = (o, r, f)
            if "information_need" in d:
                self.information_needs.add(d["information_need"]["id"])
            if "measurement" in d:
                self.measurements[d["measurement"]["id"]] = (d["measurement"], f)
            if "derivation_rule" in d:
                self.derivation_rules.add(d["derivation_rule"]["id"])

    # ---------- verificações ----------

    @staticmethod
    def onto_of(ident):
        return ident.split(".")[0]

    def deps(self, oid):
        d, _ = self.ontologies.get(oid, ({}, None))
        return set(d.get("dependencies") or [])

    def check_ids(self):
        for cid, (_, _, f) in self.concepts.items():
            if not ID_RE.match(cid):
                self.fail("id", f"id de conceito fora do padrão: {cid}", f)
        for rid, (_, _, f) in self.relations.items():
            if not ID_RE.match(rid):
                self.fail("id", f"id de relação fora do padrão: {rid}", f)

    def check_concept_refs(self):
        for cid, (o, c, f) in self.concepts.items():
            cls = c.get("classification") or {}
            for key in ("parent", "is_role_of"):
                ref = cls.get(key)
                if not ref:
                    continue
                if ref not in self.concepts:
                    self.fail("ref", f"{cid}.{key} aponta para {ref}, inexistente", f)
                elif self.onto_of(ref) != o and self.onto_of(ref) not in self.deps(o):
                    self.fail("dep", f"{cid} usa {ref}, mas {o} não declara dependência de {self.onto_of(ref)}", f)

    def check_relation_refs(self):
        for rid, (o, r, f) in self.relations.items():
            for side in ("source", "target"):
                ref = r.get(side)
                if ref not in self.concepts:
                    self.fail("ref", f"{rid}.{side} aponta para {ref}, inexistente", f)
                elif self.onto_of(ref) != o and self.onto_of(ref) not in self.deps(o):
                    self.fail("dep", f"{rid} usa {ref}, mas {o} não declara dependência de {self.onto_of(ref)}", f)

    def check_modules_exist(self):
        for oid, (d, dirname) in self.ontologies.items():
            for m in d.get("modules") or []:
                path = f"{dirname}/modules/{m}.yaml"
                if not os.path.exists(path):
                    self.fail("module", f"{oid}: modules/{m}.yaml declarado no ontology.yaml mas ausente")

    def check_cycles(self):
        def walk(oid, seen, path):
            for dep in self.deps(oid):
                if dep in seen:
                    self.fail("cycle", " -> ".join(path + [dep]))
                else:
                    walk(dep, seen | {dep}, path + [dep])
        for oid in self.ontologies:
            walk(oid, {oid}, [oid])

    def check_competency_questions(self):
        for f, d in self.files.items():
            if not isinstance(d, dict) or "competency_questions" not in d:
                continue
            # ontology.yaml lista apenas os nomes dos arquivos de CQ
            if isinstance(d.get("ontology"), dict):
                continue
            for q in d["competency_questions"]:
                for c in q.get("concepts") or []:
                    if c not in self.concepts:
                        self.fail("cq", f"{q['id']}: conceito {c} inexistente", f)
                for r in q.get("relations") or []:
                    if r not in self.relations:
                        self.fail("cq", f"{q['id']}: relação {r} inexistente", f)

    def check_measurements(self):
        for mid, (m, f) in self.measurements.items():
            for need in m.get("answers_information_need") or []:
                if need not in self.information_needs:
                    self.fail("measure", f"{mid} responde a {need}, que não existe em information_needs/", f)
            if not m.get("limitations"):
                self.fail("measure", f"{mid} não declara limitations", f)

    def check_mappings(self):
        for f, d in self.files.items():
            if not isinstance(d, dict) or "mapping" not in d:
                continue
            concept = d.get("target", {}).get("concept")
            if concept and concept not in self.concepts:
                self.fail("mapping", f"{d['mapping']['id']}: conceito alvo {concept} inexistente", f)
            if not d.get("limitations"):
                self.fail("mapping", f"{d['mapping']['id']}: limitations é obrigatório", f)
            sem = d.get("semantics") or {}
            if not sem.get("justification"):
                self.fail("mapping", f"{d['mapping']['id']}: justificativa semântica ausente", f)

            mid = d["mapping"]["id"]
            deriv = d.get("derivation")

            # Conceito inferido precisa dizer que foi inferido, e por qual regra.
            if sem.get("equivalence") == "derived" and not deriv:
                self.fail("mapping", f"{mid}: equivalência 'derived' exige bloco derivation", f)

            if deriv:
                rule = deriv.get("rule_id")
                if rule and rule not in self.derivation_rules:
                    self.fail("mapping", f"{mid}: derivation.rule_id '{rule}' não existe em rules/", f)
                if deriv.get("fallback") not in (None, "skip"):
                    self.fail("mapping", f"{mid}: fallback deve ser 'skip' — presumir conceito contamina a medida", f)

            # Selector que referencia regra: a regra precisa existir.
            sel = (d.get("source") or {}).get("selector") or {}
            ref = sel.get("rule_ref")
            if ref and ref not in self.derivation_rules:
                self.fail("mapping", f"{mid}: selector.rule_ref '{ref}' não existe em rules/", f)
            for key in ("children_of_concept", "parent_of_concept"):
                concept = (sel.get("structural_requirements") or {}).get(key)
                if concept and concept not in self.concepts:
                    self.fail("mapping", f"{mid}: selector.{key} '{concept}' inexistente", f)

    def check_provenance(self):
        for oid, (d, _) in self.ontologies.items():
            if not d.get("provenance"):
                self.fail("provenance", f"ontologia {oid} sem proveniência")
        for f, d in self.files.items():
            if isinstance(d, dict) and "module" in d and not d["module"].get("provenance"):
                self.fail("provenance", f"módulo {d['module']['id']} sem proveniência", f)

    def run(self):
        count = self.load()
        self.index()
        self.check_ids()
        self.check_concept_refs()
        self.check_relation_refs()
        self.check_modules_exist()
        self.check_cycles()
        self.check_competency_questions()
        self.check_measurements()
        self.check_mappings()
        self.check_provenance()
        return count


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kb", default="priv/knowledge_base")
    args = ap.parse_args()

    kb = KB(args.kb)
    count = kb.run()

    print(f"{count} arquivos YAML | {len(kb.ontologies)} ontologias | "
          f"{len(kb.concepts)} conceitos | {len(kb.relations)} relações | "
          f"{len(kb.measurements)} medidas")

    if kb.problems:
        print(f"\n{len(kb.problems)} problema(s):\n")
        for p in sorted(set(kb.problems)):
            print(" ", p)
        return 1

    print("base de conhecimento válida")
    return 0


if __name__ == "__main__":
    sys.exit(main())
