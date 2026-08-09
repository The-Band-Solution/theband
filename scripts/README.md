# scripts/

Ferramentas que operam sobre a base de conhecimento em `priv/knowledge_base/`.

Nenhuma delas é a aplicação. São a porta de qualidade e a cadeia de derivação
enquanto o projeto Elixir não existe — e o contrato de cada uma já é o da Mix
task que vai substituí-la.

## O que existe

| Script | Faz | Vira |
|---|---|---|
| `validate_knowledge_base.py` | valida sintaxe, schemas, integridade referencial, direção de dependências, ciclos, fundamentação de papéis, proveniência e segredos | `mix knowledge.validate` + `mix knowledge.graph` |
| `generate_docs.py` | gera `docs/ontology/`, `docs/integrations/mappings.md` e `docs/metrics/` a partir da base | `mix knowledge.docs` |
| `derive_information_model.py` | aplica os cinco passos da transformação e produz o modelo de informação de uma ontologia | `mix knowledge.information_model` |

## Uso

```bash
python3 -m venv .venv
.venv/bin/pip install -r scripts/requirements.txt

.venv/bin/python scripts/validate_knowledge_base.py
.venv/bin/python scripts/generate_docs.py
.venv/bin/python scripts/derive_information_model.py --ontology eo
```

O ambiente Python do sistema costuma ser gerenciado (PEP 668), por isso o venv.

## Ordem que importa

`validate` roda antes de qualquer coisa. `generate_docs` e
`derive_information_model` assumem a base válida e não repetem as verificações —
gerar documentação a partir de base inválida produz documentação errada com cara
de certa.

---

## Nota: extrair como biblioteca independente

**Status: intenção registrada, não decidida.** Ver [RFC 0001](../docs/rfc/0001-derivacao-do-modelo-de-informacao.md)
quanto às questões que ainda bloqueiam a derivação.

`derive_information_model.py` não tem nada de específico do The Band. Ele
implementa `one table per kind` de Guidoni, Almeida & Guizzardi (2020) mais as
extensões deste projeto para redes de ontologias e views — e isso serve a
qualquer projeto que parta de um modelo OntoUML.

### Por que valeria extrair

O método é publicado e a implementação de referência dos autores
([nemo-ufes/ontouml2db](https://github.com/nemo-ufes/ontouml2db)) trabalha sobre
modelos OntoUML isolados. As duas extensões daqui — **rede de ontologias por
referência** em vez de réplica, e **geração de views** que devolvem o vocabulário
do domínio — resolvem problemas que aparecem em qualquer rede, não só nesta.

Havendo interesse do grupo do NEMO, o caminho natural seria contribuir para o
`ontouml2db` em vez de manter uma implementação paralela. O coorientador da tese
é coautor do paper e mantenedor da linha.

### O que precisa acontecer antes

1. **Fechar as questões abertas do RFC 0001**, sobretudo Q4 — 142 conceitos ainda
   sem `ontouml_stereotype`. Extrair uma biblioteca cujo método ainda não roda
   sobre a própria base seria prematuro.
2. **Separar o que é método do que é convenção deste projeto.** Hoje estão
   misturados: `tenant_id`, `internal_id`, `record_version` e o bloco de
   proveniência são exigência da tese e do The Band, não do método. Numa
   biblioteca virariam configuração.
3. **Definir o formato de entrada.** Hoje é o YAML desta base. Uma biblioteca
   precisaria aceitar também o JSON do padrão OntoUML, que é o formato do
   `ontouml2db` e do editor.
4. **Definir o formato de saída.** Hoje é texto para leitura humana. Precisaria
   emitir esquema — DDL, ou uma representação intermediária que gere DDL e
   migrações Ecto.
5. **Testes com os modelos públicos.** O paper avalia dez modelos OntoUML de
   domínios diversos; usá-los como suíte diria se a implementação generaliza ou
   se está moldada a esta base.

### O que ficaria de fora

`validate_knowledge_base.py` e `generate_docs.py` são específicos do formato
desta base e não têm por que sair daqui.

### Enquanto isso

O código fica neste repositório, documentado e com o método declarado em
`priv/knowledge_base/transformations/`, de forma que a extração seja um recorte
e não uma reescrita. O sinal de que chegou a hora é a derivação rodar sobre as
doze ontologias sem intervenção manual.
