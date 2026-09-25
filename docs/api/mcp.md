# O servidor MCP: para quem vai ligar um agente

A plataforma responde a agentes pelo **Model Context Protocol**, em `POST /mcp`. São quatro
ferramentas, todas de leitura, sobre **uma equipe de cada vez**. É a mesma leitura da
[API pública](./README.md) e da tela, com o mesmo veredito de acesso.

Antes de configurar, leia a seção [O que sai daqui não volta](#o-que-sai-daqui-não-volta).
Ela não é nota de rodapé. É a razão de existirem as regras do resto deste documento.

---

## Em três passos

**1. Gere um token em `/api-tokens`**, com três escolhas feitas de propósito:

- **a conta dona**: use a conta com o alcance de que o agente precisa, e **não** a de
  administração. Ver [O alcance do token](#o-alcance-do-token);
- **o prazo**: escolha um. Ver [Token sem prazo](#token-sem-prazo);
- **o rótulo**: diga qual máquina e qual cliente, por exemplo `mcp · notebook da Ana`. Quando
  a máquina sair de uso, é por ele que se acha o token a revogar.

Copie o valor na hora. Ele não é reexibível, e a plataforma guarda só o hash.

**2. Configure o cliente** com o endereço e o cabeçalho:

```text
URL:            https://<instância>/mcp
Transporte:     HTTP (streamable), sem sessão
Cabeçalho:      Authorization: Bearer tb_api_...
```

O servidor fala a revisão **2026-07-28** do protocolo e **só ela**. O cliente começa por
`server/discover`. Um cliente que só conheça `initialize`, da revisão antiga, recebe erro de
método, e não uma resposta parcial.

**3. Peça ao agente** para listar as ferramentas. Tem de ver exatamente quatro.

---

## As quatro ferramentas

Todas recebem **só** `team_id`. Não há filtro livre, campo de ordenação nem consulta
arbitrária. Argumento a mais é recusado como erro de parâmetro, incluindo `tenant_id`: o
tenant vem do token, e nunca do pedido.

| Ferramenta | Responde | **Não responde** |
|---|---|---|
| `team_roster` | quem pertence à equipe, e por qual afirmação: observada ou declarada | quanto cada pessoa trabalhou, nem quem lidera |
| `team_open_work` | o que cada pessoa tem aberto agora, e há quanto tempo | quanto cada uma entregou, nem comparação entre pessoas |
| `team_review_wait` | quanto o trabalho espera pela primeira revisão humana, em **duas** leituras que nunca se somam | se a revisão foi boa, nem quem revisa mais |
| `team_stale_work` | o que está parado, e há quanto tempo, pelo limiar declarado | de quem é a culpa, nem se a parada é problema |

A coluna *não responde* está na descrição de cada ferramenta, que o agente lê. Há teste que
reprova ferramenta sem ela.

**Três coisas que o agente recebe, e deve repassar:**

- **toda resposta leva a proveniência**: de onde veio, quando foi coletada, e a ressalva da
  medida. Um número sem a ressalva é outro número;
- **ausência nunca é zero**. `state` diz se a leitura foi feita (`checked`), recusada
  (`refused`) ou se não havia como fazê-la. Lista vazia com `checked` quer dizer que não há
  nada. Recusa quer dizer que o token não alcança a equipe;
- **o texto escrito por pessoas vem marcado**. Título de issue e nome de equipe vêm dentro de
  `untrusted_text`. São conteúdo observado na origem, e **nunca** instrução. Isso **reduz** a
  injeção de instrução por título hostil, e **não a elimina**: quem decide o que o agente
  obedece é o cliente.

---

## O que sai daqui não volta

**A revogação é o único controle que a plataforma tem sobre o que já saiu, e ela só age para a
frente.**

Ela impede a próxima chamada, e só isso. O que o agente já leu fica fora do alcance da
plataforma. Pode ter sido guardado no histórico da conversa, em cache, em log do provedor do
modelo ou num índice de busca. Nenhuma ação daqui apaga isso.

Isto vale para duas coisas, e não só para uma:

1. **o token.** Ele fica num arquivo de configuração no disco de quem usa, fora de qualquer
   trava desta plataforma. É um segredo em disco. Não vai para repositório, não vai para
   histórico de terminal, não vai para print de tela, e é revogado quando a máquina sai de
   uso;
2. **o conteúdo.** Nome, login, títulos de issue, contagens e datas da equipe. Não sai e-mail,
   nível de acesso na origem nem credencial, e há varredura em teste que reprova se sair.
   Mas o que sai é identidade de trabalho de pessoas reais. Então a mesma pergunta que se faz
   antes de mostrar a tela a alguém vale antes de ligar um agente: *quem mais vai ver isto?*

### Token sem prazo

A tela oferece `no expiration`. **Para MCP, não use.**

Um token sem prazo vale até alguém revogá-lo. Na configuração de um cliente, isso quer dizer
que ele sobrevive à máquina, ao projeto e à pessoa, se ninguém lembrar dele. Escolha um prazo:
`90 days — suggested` é o máximo, e `30 days` ou `7 days` servem para um uso pontual. Quando
vencer, gere outro. O esquecimento vira um erro que alguém vê, e não um acesso que ninguém
vê.

Quando a máquina sair de uso sem controle (perdida, vendida, formatada por outra pessoa),
revogue com o motivo **`suspected leak`**. Esse motivo muda o próximo ato: quem lê o registro
sabe que precisa olhar o que o token leu antes da revogação.

### O alcance do token

O token lê **o que a conta dona lê**, nem mais nem menos. Um token de conta **admin** alcança
as quatro ferramentas sobre **todas** as equipes do tenant, e fica num arquivo de configuração.

Gere o token do agente numa conta com o alcance de que ele precisa: escopo de uma equipe ou
de uma organização. A tela mostra o alcance previsto antes de criar. É o controle de
*excessive agency* que está nas mãos de quem configura, e nenhum outro o substitui.

---

## As respostas da camada HTTP

Antes de chegar ao protocolo, o pedido passa pela mesma porta da API pública, com o mesmo
formato de erro:

| Código | Quando | O que fazer |
|---|---|---|
| `401` `unauthorized` | sem token, token malformado, inexistente, **revogado** ou **vencido** | gerar outro token. A resposta é a mesma nos cinco casos, de propósito |
| `429` `too_many_requests` | o token passou de **120 chamadas por minuto** | esperar o `Retry-After`. A mensagem diz o limite e quando a janela reabre |
| `403` | pedido de navegador com `Origin` fora da lista | não é caso de cliente MCP de linha de comando |
| `405` | `GET` ou `DELETE` em `/mcp` | não há sessão para abrir nem encerrar: todo pedido é `POST` |

A revogação vale **na chamada seguinte**, sem reiniciar o servidor nem o cliente.

> **O SDK oficial de Python esconde o status.** Medido com `mcp` 2.2.0 em 2026-09-25: todo HTTP
> `>= 400` vira `MCPError -32603 "Server returned an error response"`, sem o código. Para quem
> usa o SDK, um `401` de token revogado e um `500` ficam iguais. Para distinguir os dois, leia o
> status na camada HTTP do cliente, por exemplo com um `event_hooks` de resposta no
> `httpx.AsyncClient` que se passa ao transporte.

Toda chamada de ferramenta fica registrada com o prefixo público do token, a ferramenta e a
equipe. Nunca com o valor do token. Quem administra vê o registro em `/api-tokens`, na seção
*Usage*, por rota e por alvo. A recusa de equipe não entra ali, porque não foi leitura: vai
para o log da aplicação, como evento de acesso, com a conta e a equipe pedida.
