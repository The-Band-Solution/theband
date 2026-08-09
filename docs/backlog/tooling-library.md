# Backlog — extrair a derivação como biblioteca

**Prioridade: baixa.** Não bloqueia nada do produto. Existe porque a
implementação tem valor fora deste projeto, e porque adiar indefinidamente faria
o código se enraizar em convenções nossas a ponto de a extração virar reescrita.

Relacionado: [RFC 0001, Q11](../rfc/0001-derivacao-do-modelo-de-informacao.md#q11) ·
[scripts/README.md](../../scripts/README.md) ·
[Extensões ao método](../research/extensions-to-one-table-per-kind.md)

## Por que existe

`scripts/derive_information_model.py` implementa `one table per kind` de
Guidoni, Almeida & Guizzardi (2020) mais cinco extensões nossas — nada disso é
específico do The Band. Os autores mantêm implementação de referência em
[nemo-ufes/ontouml2db](https://github.com/nemo-ufes/ontouml2db), sobre modelos
isolados; as extensões daqui tratam de redes de ontologias e de views.

**Contribuir para o `ontouml2db` provavelmente vale mais que manter
implementação paralela.** O coorientador da tese é coautor do paper e mantenedor
da linha — o caminho é curto, e uma conversa antes de escrever código pode
poupar o esforço inteiro se o grupo já tiver avançado nisso.

## Itens

| # | Item | Estado | Bloqueia |
|---|---|---|---|
| L1 | Fechar a classificação OntoUML da base | **a fazer** | tudo |
| L2 | Separar método de convenção deste projeto | **a fazer** | L3, L4 |
| L3 | Aceitar o JSON do padrão OntoUML como entrada | a fazer | adoção externa |
| L4 | Emitir DDL como saída | **implementação futura** | uso real da lib |
| L5 | Suíte de teste com os modelos públicos do paper | **a fazer** | confiança na generalização |

---

### L1 — Fechar a classificação OntoUML da base

**Estado**: 3 de 12 ontologias classificadas — EO, SPO e CMPO. Restam 163
conceitos sem `ontouml_stereotype`, o que é a Q4 do RFC.

Extrair uma biblioteca cujo método ainda não roda sobre a própria base seria
prematuro: não haveria como saber se as extensões cobrem os casos que faltam.

**Pronto quando**: `derive_information_model.py` roda sobre as doze ontologias
sem intervenção manual. É também o sinal de que a extração pode começar.

**Depende de**: Q4, Q5 e Q6 do RFC 0001.

---

### L2 — Separar método de convenção deste projeto

Hoje estão misturados no gerador. São convenção do The Band, não do método:

| Convenção | Origem |
|---|---|
| `tenant_id` | multitenancy da plataforma (ADR 0001) |
| `internal_id`, `record_version` | exigência da tese para rastreabilidade entre repositórios |
| `source_system`, `source_instance`, `external_id`, `collected_at` | Application Reference da tese |
| prefixo de tabela pelo id da ontologia | escolha nossa |
| plurais irregulares em inglês | escolha nossa |

Numa biblioteca isso vira configuração, com o método sem opinião sobre colunas
de infraestrutura.

**Pronto quando**: as regras em `transformations/` produzem o mesmo esquema com
`entity_conventions` vazio, apenas sem as colunas de infraestrutura.

---

### L3 — Aceitar o JSON do padrão OntoUML como entrada

Hoje a entrada é o YAML desta base. O `ontouml2db` e o editor OntoUML usam o
[ontouml-schema](https://github.com/OntoUML/ontouml-schema), que é o formato que
qualquer adotante externo teria.

Implica separar o carregamento da derivação — hoje `load_concepts()` conhece a
estrutura de diretórios da nossa base.

**Pronto quando**: o mesmo modelo, expresso nos dois formatos, produz esquema
idêntico.

---

### L4 — Emitir DDL como saída

**Implementação futura.** Adiado deliberadamente.

Hoje a saída é texto para leitura humana, que é o suficiente para o que a
ferramenta faz agora: apoiar decisão de modelagem e mostrar consequência de
classificação. Emitir DDL só passa a valer quando houver banco para receber, e
aí a pergunta *qual* DDL — PostgreSQL, migrações Ecto, ou representação
intermediária que gere ambos — depende de decisões do produto que ainda não
foram tomadas.

Gerar DDL antes disso significaria escolher o alvo cedo demais e provavelmente
refazer.

**Reavaliar quando**: a fundação Elixir existir e a feature 001 estiver em
implementação.

---

### L5 — Suíte de teste com os modelos públicos do paper

O paper avalia dez modelos OntoUML de domínios diversos — Cloud Vulnerability,
ECG, G.805, MPOG, Normative Acts, OpenBio, OpenFlow, Open Provenance, PAS 77,
Software Requirements.

Rodar a derivação sobre eles responderia a pergunta que hoje é hipótese: **as
extensões generalizam, ou estão moldadas a esta rede?**

Também daria comparação direta com os números do paper, que publica `n`, `h`,
`nl`, `nt` e `nk` para cada modelo — se nossos valores divergirem, ou a
implementação diverge do método, ou a interpretação diverge.

**Pronto quando**: os dez modelos derivam sem erro, e `nk` bate com o publicado.

**Observação**: este item é o que transforma a extração de "reorganização de
código" em "resultado verificável", e é pré-requisito de qualquer submissão.

---

## Ordem

```text
L1 fechar classificação        ← sinal de que a extração pode começar
  └─ L2 separar convenção
       ├─ L3 entrada OntoUML JSON
       └─ L5 suíte dos dez modelos
            └─ L4 emitir DDL      ← só quando houver banco para receber
```

L5 depende de L2 e L3 porque os modelos públicos vêm no formato OntoUML e sem as
nossas convenções — é exatamente o teste de que a separação funcionou.

## Antes de começar

Conversar com o grupo do NEMO. Três perguntas que mudam o plano inteiro:

1. Existe trabalho posterior cobrindo redes de ontologias? O artigo de 2021 sobre
   *forward engineering* pode já tratar disso.
2. Existe tratamento para perdurantes? É a Q1 do RFC, e a resposta define se E2 é
   contribuição ou reinvenção.
3. Há interesse em receber as extensões no `ontouml2db`?
