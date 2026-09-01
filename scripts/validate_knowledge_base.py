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

# Os mesmos marcadores do validador Elixir (`YamlValidator.@secret_markers`). Divergir a
# lista faria os dois validadores discordarem sobre o que é segredo.
SECRET_MARKERS = ("ghp_", "github_pat_", "gho_", "xoxb-", "-----BEGIN")


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
        """Lê todos os YAMLs, varrendo segredos antes de qualquer parse.

        A varredura vem primeiro de propósito: um arquivo com token não deve
        sequer ser processado, e a falha precisa aparecer mesmo que o YAML esteja
        malformado.
        """
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
        """Indexa conceitos, relações, ontologias, medidas e regras de derivação.

        Detecta duplicidade de id no caminho — dois conceitos com o mesmo id
        tornariam a integridade referencial ambígua.
        """
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
        """Ids seguem ``ontologia.conceito``, em minúsculas.

        Id é contrato: mapeamentos, regras e perguntas de competência apontam
        para ele, e mudá-lo depois quebra referências silenciosamente.
        """
        for cid, (_, _, f) in self.concepts.items():
            if not ID_RE.match(cid):
                self.fail("id", f"id de conceito fora do padrão: {cid}", f)
        for rid, (_, _, f) in self.relations.items():
            if not ID_RE.match(rid):
                self.fail("id", f"id de relação fora do padrão: {rid}", f)

    def check_concept_refs(self):
        """``parent`` e ``is_role_of`` existem e respeitam a direção de dependência."""
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
        """Origem e destino de cada relação existem e são alcançáveis."""
        for rid, (o, r, f) in self.relations.items():
            for side in ("source", "target"):
                ref = r.get(side)
                if ref not in self.concepts:
                    self.fail("ref", f"{rid}.{side} aponta para {ref}, inexistente", f)
                elif self.onto_of(ref) != o and self.onto_of(ref) not in self.deps(o):
                    self.fail("dep", f"{rid} usa {ref}, mas {o} não declara dependência de {self.onto_of(ref)}", f)

    def check_role_grounding(self):
        """Todo papel precisa alcançar o tipo rígido que lhe dá identidade.

        Em UFO, um Role é um sortal antirrígido que especializa o Kind do qual
        herda o princípio de identidade: quem é membro de equipe é, antes disso,
        uma pessoa, e continua a mesma pessoa ao deixar a equipe.

        Um papel sem fundamentação é um papel sem dono — não dá para dizer o que
        exatamente assume aquele papel, nem em que tabela o registro vive. A
        cadeia é percorrida por is_role_of e, na falta dele, por parent.
        """
        for cid, (_, c, f) in self.concepts.items():
            cls = c.get("classification") or {}
            if cls.get("ufo_category") not in ("role", "social_role"):
                continue
            if cid.startswith("ufo."):
                continue  # categorias da UFO são metamodelo, não papéis instanciáveis

            seen, cur = [], cid
            while True:
                if cur in seen:
                    self.fail("role", f"{cid}: ciclo na cadeia de fundamentação: "
                                      f"{' -> '.join(seen + [cur])}", f)
                    break
                seen.append(cur)
                cur_cls = (self.concepts.get(cur, (None, {}, None))[1] or {}).get("classification") or {}
                if cur_cls.get("ufo_category") not in ("role", "social_role"):
                    break  # chegou a um tipo rígido
                nxt = cur_cls.get("is_role_of") or cur_cls.get("parent")
                if not nxt:
                    self.fail("role", f"{cid}: papel sem fundamentação — declare is_role_of "
                                      f"(cadeia: {' -> '.join(seen)})", f)
                    break
                cur = nxt

    def check_modules_exist(self):
        """Cada módulo listado no ``ontology.yaml`` tem arquivo correspondente."""
        for oid, (d, dirname) in self.ontologies.items():
            for m in d.get("modules") or []:
                path = f"{dirname}/modules/{m}.yaml"
                if not os.path.exists(path):
                    self.fail("module", f"{oid}: modules/{m}.yaml declarado no ontology.yaml mas ausente")

    def check_modules_declared(self):
        """Cada arquivo em ``modules/`` está declarado no ``ontology.yaml``.

        A direção inversa da anterior, e a que escapava. Um módulo escrito e não
        declarado **entra na contagem e no índice de conceitos** — porque ambos
        varrem o diretório — e **some da página da própria ontologia**, porque o
        gerador percorre a lista declarada. O número diz 238, o índice lista, e a
        ontologia omite: quem procura pelo caminho natural conclui que o conceito
        não existe.

        O gate de derivação reproduzível não pega, e por um motivo que vale
        registrar: ele compara a documentação gerada com os YAML, e os dois
        **concordam em omitir**. Encontrado em 2026-08-27 com
        ``qapo.evaluation_verdict`` (issue #527).
        """
        for oid, (d, dirname) in self.ontologies.items():
            declarados = {str(m) for m in (d.get("modules") or [])}
            diretorio = f"{dirname}/modules"
            if not os.path.isdir(diretorio):
                continue
            for arquivo in sorted(os.listdir(diretorio)):
                if not arquivo.endswith(".yaml"):
                    continue
                nome = arquivo[: -len(".yaml")]
                if nome not in declarados:
                    self.fail(
                        "module",
                        f"{oid}: modules/{arquivo} existe mas NÃO está em `modules:` do "
                        f"ontology.yaml — os conceitos dele contam e não aparecem na "
                        f"página da ontologia",
                    )

    def check_cycles(self):
        """Nenhum ciclo entre ontologias.

        A rede é estratificada: o específico depende do geral, nunca o contrário.
        Um ciclo tornaria impossível carregar a base em ordem.
        """
        def walk(oid, seen, path):
            for dep in self.deps(oid):
                if dep in seen:
                    self.fail("cycle", " -> ".join(path + [dep]))
                else:
                    walk(dep, seen | {dep}, path + [dep])
        for oid in self.ontologies:
            walk(oid, {oid}, [oid])

    def check_competency_questions(self):
        """Perguntas de competência referenciam conceitos e relações existentes.

        Uma CQ apontando para conceito inexistente é pergunta que o modelo não
        sabe responder — e que ninguém descobriria até tentar.
        """
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
        """Toda medida responde a necessidade declarada e expõe suas limitações."""
        for mid, (m, f) in self.measurements.items():
            for need in m.get("answers_information_need") or []:
                if need not in self.information_needs:
                    self.fail("measure", f"{mid} responde a {need}, que não existe em information_needs/", f)
            if not m.get("limitations"):
                self.fail("measure", f"{mid} não declara limitations", f)

    def check_mappings(self):
        """Mapeamentos declaram equivalência, justificativa, limitações e derivação.

        Semelhança de nome não basta para tratar conceitos como equivalentes, e
        conceito inferido precisa dizer que foi inferido — senão vira fato por
        acidente.
        """
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

            self.check_mapping_relations(mid, d, f, concept_alvo=d.get("target", {}).get("concept"))

    def check_mapping_relations(self, mid, d, f, concept_alvo):
        """Vínculo prometido por mapeamento precisa de lastro na ontologia.

        Cada entrada de `relations:` afirma que o conceito alvo do mapeamento se
        liga a outro conceito. Duas coisas têm de ser verdade, e nenhuma era
        verificada: o conceito do outro lado existe, e **existe relação declarada
        que sustente o vínculo**.

        Sem isto, um mapeamento promete um caminho que a ontologia não tem, o
        derivador não gera coluna alguma, e alguém acaba escrevendo a coluna à mão
        — que foi exatamente o que produziu `eo_people.organization_id` nula em
        100% dos registros. Achado F6 da feature 002.
        """
        for nome, rel in (d.get("relations") or {}).items():
            if not isinstance(rel, dict):
                continue

            outro = rel.get("target_concept")
            if not outro:
                continue

            if outro not in self.concepts:
                self.fail("mapping", f"{mid}: relations.{nome} aponta para conceito inexistente {outro}", f)
                continue

            onto = rel.get("target_ontology")
            if onto and self.onto_of(outro) != onto:
                self.fail(
                    "mapping",
                    f"{mid}: relations.{nome} declara target_ontology '{onto}' e conceito de '{self.onto_of(outro)}'",
                    f,
                )

            if not concept_alvo or concept_alvo not in self.concepts:
                continue

            # Vínculo derivado tem lastro na regra, não na ontologia: é evidência
            # observada, e a regra é que diz como foi obtida. Exigir relação
            # ontológica aqui forçaria a promover evidência a alocação, que é
            # justamente o que a base evita quando a origem não fornece papel.
            if (d.get("derivation") or {}).get("rule_id"):
                continue

            if self.relation_between(concept_alvo, outro):
                continue

            # Terceiro lastro: a lacuna declarada. A limitação precisa **nomear o
            # conceito** do outro lado, e não descrever o problema em geral — uma
            # frase genérica passaria em qualquer mapeamento e o gate viraria
            # carimbo. Exigir o id força quem escreve a dizer qual vínculo não tem
            # lastro, onde quem lê o mapeamento vê.
            if any(outro in str(lim) for lim in (d.get("limitations") or [])):
                continue

            self.fail(
                "mapping",
                f"{mid}: relations.{nome} promete vínculo {concept_alvo} → {outro} "
                f"sem relação declarada, sem derivation.rule_id, e sem limitação que nomeie {outro}",
                f,
            )

    def relation_between(self, a, b):
        """Existe relação declarada entre os dois conceitos, em qualquer direção?

        Considera também os supertipos de cada lado: a relação de EO sai de
        `eo.organizational_team`, e um mapeamento pode alvejar o subkind ou o kind.
        Ignorar a especialização faria a verificação reprovar vínculo legítimo.
        """
        lado_a = self.with_supertypes(a)
        lado_b = self.with_supertypes(b)

        return any(
            (r.get("source") in lado_a and r.get("target") in lado_b)
            or (r.get("source") in lado_b and r.get("target") in lado_a)
            for _o, r, _f in self.relations.values()
        )

    def with_supertypes(self, cid, vistos=None):
        """O conceito e a cadeia de supertipos acima dele.

        Sobe, e só sobe. Relação declarada no supertipo vale para o subtipo — toda
        equipe organizacional é equipe. O inverso é falso: relação declarada em
        `cmpo.target_branch` não vale para `cmpo.branch` em geral, e aceitar a
        descida transformaria a verificação em carimbo.
        """
        vistos = vistos or set()
        if cid in vistos or cid not in self.concepts:
            return {cid}
        vistos.add(cid)

        _o, c, _f = self.concepts[cid]
        cls = c.get("classification") or {}
        # A base usa `parent`; `specializes` fica aceito porque o schema o admite em
        # outros pontos e ler só um dos dois produziria falso positivo silencioso.
        acima = cls.get("parent") or cls.get("specializes")
        pais = acima if isinstance(acima, list) else ([acima] if acima else [])

        return {cid} | {s for p in pais for s in self.with_supertypes(p, vistos)}

    def check_against_schemas(self):
        """Valida cada artefato contra o JSON Schema do seu tipo.

        Sem isto, um campo inventado entra na base sem ninguém notar — e a base
        deixa de ser um contrato para virar convenção oral.
        """
        try:
            from jsonschema import Draft202012Validator
            from referencing import Registry, Resource
            from referencing.jsonschema import DRAFT202012
        except ImportError:
            self.fail("schema", "jsonschema não instalado — validação de forma NÃO executada "
                                "(pip install -r scripts/requirements.txt)")
            return

        schema_dir = f"{self.root}/schemas"
        schemas, resources = {}, []
        for f in glob.glob(f"{schema_dir}/*.schema.yaml"):
            s = yaml.safe_load(open(f, encoding="utf-8"))
            schemas[os.path.basename(f).replace(".schema.yaml", "")] = s
            if "$id" in s:
                resources.append((s["$id"], Resource(contents=s, specification=DRAFT202012)))
        registry = Registry().with_resources(resources)

        # Qual schema se aplica a qual documento, pela chave raiz.
        by_root_key = {
            "ontology": "ontology", "module": "module", "mapping": "mapping",
            "information_need": "information-need", "measurement": "measurement",
            "competency_questions": "competency-question",
        }

        for f, d in self.files.items():
            if not isinstance(d, dict):
                continue
            name = None
            for key, schema_name in by_root_key.items():
                if key in d:
                    # ontology.yaml e arquivos de CQ ambos têm a chave 'ontology'
                    if key == "ontology" and not isinstance(d["ontology"], dict):
                        continue
                    name = schema_name
                    break
            if not name or name not in schemas:
                continue
            try:
                validator = Draft202012Validator(schemas[name], registry=registry)
                for err in sorted(validator.iter_errors(d), key=lambda e: list(e.path)):
                    path = ".".join(str(p) for p in err.path) or "(raiz)"
                    self.fail("schema", f"{name}: {path}: {err.message[:160]}", f)
            except Exception as e:  # schema malformado é falha, não silêncio
                self.fail("schema", f"falha ao validar contra {name}: {e}", f)

    def check_provenance(self):
        """Ontologias e módulos declaram de onde vêm."""
        for oid, (d, _) in self.ontologies.items():
            if not d.get("provenance"):
                self.fail("provenance", f"ontologia {oid} sem proveniência")
        for f, d in self.files.items():
            if isinstance(d, dict) and "module" in d and not d["module"].get("provenance"):
                self.fail("provenance", f"módulo {d['module']['id']} sem proveniência", f)

    def check_secrets(self):
        """Nenhum segredo no YAML.

        A base é lida no boot e vive versionada: um token colado aqui vaza para
        todo mundo que der ``git clone``, e continua no histórico depois de
        removido. A verificação nasceu no validador Elixir; existir só de um lado
        significaria que o gate depende de qual dos dois rodou.
        """
        for f, d in self.files.items():
            texto = str(d)
            for marcador in SECRET_MARKERS:
                if marcador in texto:
                    self.fail("secret", f"possível segredo no YAML (marcador {marcador})", f)

    def run(self):
        """Executa todas as verificações; devolve o número de arquivos lidos."""
        count = self.load()
        self.index()
        self.check_ids()
        self.check_concept_refs()
        self.check_relation_refs()
        self.check_role_grounding()
        self.check_modules_exist()
        self.check_modules_declared()
        self.check_cycles()
        self.check_competency_questions()
        self.check_measurements()
        self.check_mappings()
        self.check_against_schemas()
        self.check_provenance()
        self.check_secrets()
        return count


def main():
    """Entrada de linha de comando. Código 1 quando há qualquer problema."""
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
