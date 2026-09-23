# O teste do fluxo reprova de vez em quando, com o mesmo código e a mesma semente

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

## Por que isto importa mais do que um teste

**Um gate que reprova por acaso treina quem lê a reexecutar até passar.** A partir daí, a
próxima reprovação real é lida como mais uma instabilidade — e o gate deixa de ser veredito.

É a lição L60 pela outra ponta: lá o verde era presumido sem ser lido; aqui o vermelho passa
a ser descartado sem ser investigado.

## O que ainda não se sabe

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

**Prioridade**: média. Não quebra produção, e corrói a confiança no gate — que é o
instrumento com que tudo o mais é conferido.
