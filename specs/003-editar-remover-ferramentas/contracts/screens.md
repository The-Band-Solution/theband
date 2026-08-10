# Contrato — telas

**Feature**: 003 · **Requisitos**: FR-020 a FR-024, FR-026

Complementa o [contrato de telas da feature 001](../../001-github-eo-ingestion/contracts/liveview-screens.md) e o [da 002](../../002-escopo-por-organizacao/contracts/screens.md), que continuam valendo.

## `/ferramentas` — a lista

| Elemento | Comportamento |
|---|---|
| Estado da ferramenta | distingue **observada**, **encerrada** e **precisa de atenção** — três estados, três aparências (FR-022) |
| Ferramenta encerrada | continua na lista, esmaecida, dizendo desde quando. Sumir faria parecer que foi apagada, e ela não foi |
| Ações por ferramenta | encerrar observação · editar credenciais · limpar atenção · retomar, quando encerrada |
| Estado vazio | distingue "nenhuma ferramenta conectada" de "todas as observações encerradas" (FR-024) |

**Por que a encerrada continua visível.** É a mesma razão pela qual a pessoa não mais
observada continua em `/pessoas`: o registro existe, e esconder produz a pergunta "onde
foi parar" sem oferecer resposta. E é como a retomada fica alcançável.

## Encerrar — o que a tela mostra antes de confirmar

A tela apresenta o impacto **calculado pela mesma função que o encerramento usa**, nunca
uma contagem escrita para exibição:

```text
Encerrar a observação de ifesserra-lab

Serão marcados como não mais observados:
   1 equipe          (1 derivada pela plataforma)
   5 vínculos
   4 pessoas         que só são conhecidas por esta organização

Permanecem vigentes:
   1 pessoa          Paulo — também observada em The-Band-Solution e leds-conectafapes

Serão destruídas:
   as credenciais desta ferramenta

NÃO serão apagados:
   24 payloads preservados, nem pessoa, equipe ou vínculo algum

Para confirmar, digite:  ifesserra-lab
```

Quatro decisões nesse texto, cada uma com razão:

**"Permanecem vigentes" aparece mesmo sendo boa notícia.** É a informação que impede o
mal-entendido central — quem não vê essa linha supõe que encerrar remove a pessoa de
todas as organizações.

**O "NÃO serão apagados" é explícito, com o número.** Sem ele, "encerrar" é lido como
"apagar", e a pessoa hesita ou desiste. O número existe para ser conferido depois.

**A pessoa que permanece é nomeada.** Um contador diria "1 pessoa permanece"; o nome
permite reconhecer quem é e decidir com conhecimento.

**A confirmação é digitar o nome da organização** (FR-003). Atrito deliberado: é a ação
de maior consequência da plataforma, e 62 registros de `leds-conectafapes` dependem de
ninguém errar um clique.

## Editar — e a ausência explicada

| Elemento | Comportamento |
|---|---|
| Credencial | renomear · desativar/ativar · **remover** |
| Remover a última ativa | recusado, dizendo que encerrar a observação é como se para de coletar |
| Segredo | apenas `last_four`; nenhuma tela de edição o exibe (FR-026) |
| Tipo, instância, organização | **não editáveis, e a tela diz por quê** (FR-020) |

O texto da ausência, no lugar onde alguém procuraria o campo:

```text
Tipo, instância e organização não são editáveis: são a identidade desta
ferramenta. Trocá-los faria os registros já coletados apontarem para uma
origem que não os produziu. Para observar outra organização, conecte outra
ferramenta.
```

**Explicar é diferente de não oferecer.** Um campo simplesmente ausente faz a pessoa
procurar, desistir e supor que é limitação. A explicação transforma a ausência em
decisão, e é o que FR-020 exige.

## `/pessoas` e `/equipes` — origem vigente ou encerrada

| Elemento | Comportamento |
|---|---|
| Registro de origem encerrada | marcado, com a data em que deixou de ser observado (FR-023) |
| Distinção da causa | a marca de origem encerrada é distinguível da marca por ausência na origem |

**Por que distinguir as duas causas na tela.** "A pessoa saiu do time no GitHub" e "nós
paramos de observar aquela organização" produzem a mesma marca e significam coisas
diferentes. A primeira é fato sobre o mundo; a segunda é fato sobre a plataforma. Quem
consulta precisa saber qual das duas está lendo.

## O que estas telas NÃO fazem

| Ausente | Razão |
|---|---|
| encerrar em lote | o impacto de cada ferramenta precisa estar à vista de quem confirma |
| botão de apagar ferramenta | não existe a operação. A tela não oferece o que a API recusa |
| esconder registro de origem encerrada | esconder produz "onde foi parar" sem resposta. Marcar responde |
| desfazer o encerramento | o caminho é retomar, e é ação distinta com credencial nova |
| exportar antes de encerrar | encerrar não perde nada, então não há o que salvar antes |
