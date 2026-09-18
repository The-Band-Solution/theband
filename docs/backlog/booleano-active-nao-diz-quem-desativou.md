# O booleano `active` não diz quem desativou, nem quando

**Registrado em 2026-09-18**, ao derivar o modelo de dados. **Não é defeito** — nada está
errado hoje. É uma divergência de padrão que cobra o preço no dia em que alguém perguntar.

---

## O que existe

Duas tabelas guardam "isto está ligado?" como **booleano**:

| Tabela | Coluna | Onde |
|---|---|---|
| `tool_credentials` | `active` | `lib/the_band/sources/tool_credential.ex:33` |
| `issue_mapping_rules` | `active` | `priv/repo/migrations/20260811200000_create_issue_mapping_rules.exs:48` |

E **nove tabelas** guardam a mesma ideia como **data mais autor** — `revoked_at` e
`revoked_by_user_id` —, entre elas as três da feature 066. A máquina delas está em
[`docs/modelos/estados/declaracao-revogavel.md`](../modelos/estados/declaracao-revogavel.md).

## O que o booleano não responde

Um booleano responde *"está ligado?"* e nada mais. As três perguntas que ele perde:

1. **quem desligou** — e numa credencial de ferramenta isso é pergunta de segurança, não de
   curiosidade;
2. **quando** — sem instante não há linha do tempo, e "a coleta parou em algum momento de
   agosto" não se investiga;
3. **se já foi religado antes** — o booleano guarda o estado atual e apaga a história. Uma
   credencial que caiu três vezes conta a mesma coisa que uma que nunca caiu.

É o mesmo argumento que a casa já aplica em `issue_promotions`, onde o comentário diz que um
booleano *"responderia à primeira metade e perderia a segunda"*
(`lib/the_band/ontology/seon/spo/projects.ex:164`).

## Por que isto NÃO foi consertado junto com as chaves estrangeiras

As duas correções vieram do mesmo levantamento, e só uma entrou no
[PR das chaves](../modelos/banco/declaracoes-da-organizacao.md). A diferença é o custo:

| | chave estrangeira ausente | booleano `active` |
|---|---|---|
| mudança | `ALTER TABLE`, aditiva | migração de dados **mais** todo leitor |
| leitores a mudar | nenhum | toda consulta que filtra `active` |
| valor hoje | o banco passa a impedir o que só a aplicação impedia | nenhum, até alguém auditar |
| risco de adiar | cresce com cada caminho de escrita novo | nenhum — o dado atual não se perde |

Trocar booleano por data e autor **não recupera** o que já foi perdido: as desativações
passadas não têm autor nem instante em lugar nenhum, e a migração escreveria nulo nas duas
colunas. Ganha-se dali para frente.

## O que fazer, quando for a hora

1. acrescentar `revoked_at` e `revoked_by_user_id`, nulos;
2. preencher `revoked_at` das linhas com `active = false` com **nulo**, não com uma data
   inventada — e escrever na migração que a ausência é a resposta honesta para o que não foi
   registrado;
3. trocar os leitores de `active` por `is_nil(revoked_at)`;
4. remover `active` **numa migração posterior**, depois de a suíte passar sem ele.

O passo 4 é o único destrutivo, e por isso fica sozinho.

## O gatilho

**Não é uma data.** É a próxima vez que uma dessas duas tabelas for mexida por outro motivo, ou
a primeira vez que alguém perguntar *"quem desativou esta credencial?"* e a plataforma não puder
responder.
