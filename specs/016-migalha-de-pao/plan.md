# Plano de implementação: a migalha de pão

**Feature**: `specs/016-migalha-de-pao/` · **Branch**: `025-migalha-e-tabela`
**Spec**: [spec.md](spec.md) · **Origem**: [#285](https://github.com/The-Band-Solution/theband/issues/285)

## Summary

Um componente `<.breadcrumb>` no design system, usado pelas **cinco** telas de detalhe. Os três
jeitos atuais de voltar — incluindo um botão `voltar` em português — viram um só.

## O que este plano decide

| Decisão | Escolha | O que a alternativa quebraria |
|---|---|---|
| onde vive | `core_components.ex`, ao lado do `<.header>` | espalhado, cada tela desenha o separador |
| como a tela declara | uma lista de `{rótulo, destino}`, com destino `nil` para o nível atual | booleano "é o último" faria a tela contar posição |
| o caminho da issue | **estrutural por padrão**, e pelo repositório quando a navegação veio dele | caminho fixo mentiria sobre o percurso |
| nível sem página | não vira ligação — mesma regra da feature 014 | clique que promete e não entrega |
| telefone | encurta o **último**, preserva o primeiro | cortar o começo tira justamente o que orienta |

## Constitution Check

**I, II, III, IV, IX** — não se aplicam: nenhum conceito, nenhuma escrita, nenhuma fronteira.

**V** — conforme: os destinos são rotas que já resolvem por tenant.

**VI** — conforme: spec e checklist antes deste plano.

**VII** — conforme, lacuna de revisão declarada.

**VIII** — o componente é o padrão, e o problema existe agora: três implementações divergentes,
uma em outro idioma. **O que fica pior**: mais um componente no design system, e uma tela que
esquecer de declarar o caminho fica sem migalha — e nada avisa. Por isso o teste percorre as cinco.

**X** — conforme: o componente faz uma coisa, e o `<.header>` continua fazendo a dele.

## Fases

| Fase | O que |
|---|---|
| **F1** | o componente, com o caso do nível sem destino |
| **F2** | as cinco telas, e a remoção dos dois botões |
| **F3** | a prova: cinco com, seis sem, e nenhuma consulta nova |

## Riscos

| Risco | Mitigação |
|---|---|
| tela nova nascer sem migalha | o teste percorre as cinco por rota, e falha se alguma não tiver |
| migalha para rota inexistente | os destinos são `~p`, verificados em compilação |
| o caminho da issue mentir | o padrão é o estrutural, e o teste cobre os dois |
| consulta nova por nível | o nome de cada nível já está carregado; o teste conta |
