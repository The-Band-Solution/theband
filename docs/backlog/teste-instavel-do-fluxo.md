# Dois testes reprovam de vez em quando, com o mesmo código e a mesma semente

**Achado em 2026-09-22**, durante os gates da feature 062 — que não toca em nada disto.

## O que acontece

`test/the_band_web/live/fluxo_na_tela_test.exs:205` — *"período zero ou negativo também cai
no padrão"* — reprovou assim:

```
** (EXIT from #PID<0.7462.0>) an exception was raised:
    ** (MatchError) no match of right hand side value: {:error, :invalid}
        (phoenix_live_view 1.2.9) lib/phoenix_live_view/test/client_proxy.ex:847:
          Phoenix.LiveViewTest.ClientProxy.put_view/3
```

O teste percorre `["0", "-4", "abc", ""]` e monta a LiveView da equipe para cada um. Um
desses `live/2` devolveu `{:error, :invalid}` em vez de `{:ok, view, html}`.

## Por que não é ordem, e não é semente

Três execuções, o mesmo código, só markdown mudado entre elas:

| Execução | Semente | Resultado |
|---|---|---|
| gates, antes de escrever `seguranca.md` | — | **2314 passaram** |
| gates, depois | `855389` | **2313 de 2314** — esta |
| suíte inteira, **com a mesma semente `855389`** | `855389` | **2314 passaram** |

Mesma semente, resultados diferentes. A ordem dos testes é a mesma; o que varia é o tempo.
Em isolamento o arquivo passa 20 de 20.

## E um segundo, em 2026-09-23 — o que muda a leitura

`test/the_band/tenants/eventos_de_acesso_test.exs:134` — *"a espera crescente é registrada
quando dispara"* — reprovou numa execução dos gates:

```
assert {:error, {:throttled, _}} = Tenants.authenticate(ctx.alvo.email, @senha)
left:  {:error, {:throttled, _}}
right: {:ok, #TheBand.Tenants.User<...>}
```

A espera **não disparou**. Em isolamento, três execuções seguidas: 5 de 5, nas três.

**Dois testes, o mesmo padrão.** O primeiro monta LiveView; este mede uma janela de tempo.
Os dois passam sozinhos e reprovam sob carga, com `max_cases: 20`.

Isso muda o diagnóstico: **não é um teste mal escrito.** É a suíte competindo por CPU e
relógio, e dois pontos onde o código de teste supõe que o tempo de parede é confiável.

## Por que isto importa mais do que um teste

**Um gate que reprova por acaso treina quem lê a reexecutar até passar.** A partir daí, a
próxima reprovação real é lida como mais uma instabilidade — e o gate deixa de ser veredito.

É a lição L60 pela outra ponta: lá o verde era presumido sem ser lido; aqui o vermelho passa
a ser descartado sem ser investigado.

## A varredura foi feita em 2026-09-23 — e não achou nada

Seis execuções da suíte inteira, seguidas: **2361 de 2365 nas seis, sem variação nenhuma**.
Nenhum dos dois casos reapareceu.

Os quatro que reprovaram nas seis eram **determinísticos**, e de outra causa: uma mudança em
`autenticar/1` colidiu com um teste que afirmava o contrato antigo. Não é instabilidade.

**Isto não desmente os dois casos** — eles aconteceram, com o log colado acima. Diz que a
frequência é baixa o bastante para não aparecer em seis tentativas, e que **não há uma
terceira fonte escondida**, que era a pergunta aberta.

O diagnóstico foi acrescentado aos dois testes na mesma data: a próxima ocorrência **diz o
que aconteceu** — qual valor falhou, o que veio no lugar, e o apontamento para este
documento — em vez de morrer numa asserção crua.

## O que ainda não se sabe

- **a causa.** A varredura mostra que é raro; não mostra por quê. A suspeita continua sendo
  competição por CPU e relógio com `max_cases: 20`, e ela não foi confirmada;

- **qual dos quatro valores** falhou. A mensagem não diz, porque a asserção morre no
  `MatchError` do casamento, antes de qualquer mensagem própria;
- **por que `:invalid`.** É o que o `ClientProxy` devolve quando a montagem não produz view —
  exceção no `mount`, ou resposta que não é LiveView. Nenhuma das duas foi confirmada;
- **se outros testes de LiveView têm o mesmo**. Só este apareceu, uma vez.

## Primeiro passo, quando alguém pegar

Trocar o casamento direto por um `case` que **nomeia qual valor falhou e com quê**:

```elixir
for absurdo <- ["0", "-4", "abc", ""] do
  case live(ctx.conn, ~p"/teams/#{ctx.equipe.id}?periodos=#{absurdo}") do
    {:ok, _live, html} -> assert janela_do_titulo(html) == janela_do_titulo(padrao)
    outro -> flunk("periodos=#{inspect(absurdo)} não montou: #{inspect(outro)}")
  end
end
```

Isso não conserta nada — **faz a próxima ocorrência dizer o que aconteceu**, em vez de morrer
no casamento. Sem isso, cada reincidência custa a mesma investigação do zero.

**Prioridade**: **baixa**, rebaixada em 2026-09-23 pela varredura — era média e subindo
quando se suspeitava de uma fonte não descoberta. Não quebra produção. Corrói a confiança no gate — que
é o instrumento com que tudo o mais é conferido — e o segundo caso mostra que não é
incidente isolado.

O primeiro passo continua o mesmo em espírito: **fazer a próxima ocorrência dizer o que
aconteceu**, em vez de morrer numa asserção crua. No caso da espera, imprimir quantas
tentativas houve e qual era o limiar no instante da medição.
