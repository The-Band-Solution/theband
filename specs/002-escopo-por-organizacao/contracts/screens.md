# Contrato — telas

**Feature**: 002 · **Requisitos**: FR-015 a FR-022

Complementa o [contrato de telas da feature 001](../../001-github-eo-ingestion/contracts/liveview-screens.md), que continua valendo.

## `/pessoas`

| Elemento | Comportamento |
|---|---|
| Coluna de organização | cada pessoa exibe **as** organizações observadas de onde veio, não uma |
| Filtro por organização | seletor com as organizações observadas do tenant; combina com a busca já existente |
| Contagem do cabeçalho | com filtro, conta as pessoas daquela organização; sem filtro, conta cada pessoa **uma vez** |
| Pessoa em mais de uma organização | sinalizada, com quais são — FR-021 |
| Estado vazio | distingue "nenhuma coleta ocorreu" de "nada corresponde ao filtro" |

**A nota que a tela precisa carregar**: a soma das contagens por organização é
maior que o total quando há pessoas sobrepostas, e isso está correto. Sem a nota,
o primeiro a somar conclui que há defeito.

## `/equipes`

| Elemento | Comportamento |
|---|---|
| Coluna de organização | cada equipe exibe a organização a que pertence |
| Filtro por organização | mesmo seletor de `/pessoas` |
| Equipe derivada | **identificada como derivada**, sempre. Selo visível, não nota de rodapé |
| Contagem | separa observadas de derivadas: "8 equipes, 1 derivada" |

O texto ao lado do selo diz o que ele significa: a equipe não existe na
ferramenta de origem; ela reúne quem é da organização e não está em nenhum time.

## `/equipes/:id` de uma equipe derivada

Mesma tela dos integrantes, com duas diferenças que a honestidade exige:

- a coluna de **acesso na plataforma** fica vazia, com a razão dita: a origem não
  informa nível de acesso para este vínculo, porque não conhece o vínculo;
- um aviso no topo explica de onde a equipe veio.

## O seletor de organização

Um só componente, usado nas duas telas. Lista as organizações observadas do
tenant, com a quantidade de pessoas de cada uma ao lado — quem escolhe precisa
saber o tamanho do que está escolhendo.

Organização conectada e ainda não sincronizada aparece com zero e a razão, não
some da lista: some da lista faria parecer que ela não foi cadastrada.

## O que estas telas NÃO fazem

| Ausente | Razão |
|---|---|
| filtrar por equipe derivada isoladamente | o filtro é por organização; a derivada é uma equipe dela, e separá-la sugeriria que é outra categoria de coisa |
| esconder a equipe derivada por padrão | esconder é pior que marcar: quem não a vê não sabe que ela existe, e a contagem de pessoas passa a não fechar sem explicação |
| permitir editar a equipe derivada | ela é consequência da coleta; editá-la seria alterar dado derivado à mão, e a próxima coleta desfaria |
