# Percurso da 044 na tela — o que a página mostra, medido

**Quando**: 2026-08-27. **Onde**: banco de desenvolvimento, tenant único, 4.233 avaliações
coletadas. **Como**: `Changes.participacao_da_pessoa/2` e `Verification.por_pessoa/2` —
as duas funções que a página chama, com os mesmos argumentos que ela passa.

## Os três percursos

| | `vinicius-je` | `fatasy` | `CaioLessaSimao` |
|---|---:|---:|---:|
| abriu | 793 | 176 | 51 |
| revisou | 627 | 20 | **0** |
| integrou | 844 | 96 | 64 |
| endossou | 634 | 19 | 0 |
| objetou | 57 | 0 | 0 |
| absteve | 30 | 1 | 0 |
| CI passou | 985 | 225 | 23 |
| CI quebrou | 79 | 26 | 3 |
| CI nem uma nem outra | 6 | 3 | 0 |

`sem autoria no tenant`: **7.313** execuções, igual para as três — porque é do tenant, e
não da pessoa. É a parcela que a tela mostra ao lado, e nunca desconta.

## O que o percurso mostrou, e que nenhum teste tinha dito

**Revisar e integrar são papéis separados, e o dado prova.** `CaioLessaSimao` integrou 64
mudanças e revisou zero. Se a tela somasse os três papéis num "participou de 115", essa
pessoa apareceria igual a alguém que revisou 115 — e são situações opostas. A spec recusa
a soma (US1), e este é o caso que justifica a recusa.

**Revisar não é uma avaliação por mudança.** `vinicius-je` revisou 627 mudanças com 721
avaliações — 634 + 57 + 30. As 94 de diferença são mudanças revisadas mais de uma vez:
objetou, a autora corrigiu, endossou. Por isso `revisou` conta MUDANÇAS com
`count(:distinct)`, e os três vereditos contam AVALIAÇÕES sem ele. Trocar um pelo outro
faria os quatro números pararem de fechar entre si — e fechariam errado dos dois lados.

**Objetar é raro, e zero objeções não é elogio.** `fatasy` tem 20 revisões e nenhuma
objeção; `CaioLessaSimao`, nenhuma revisão. Os dois zeros são visualmente iguais na tela e
significam coisas diferentes — quem revisa e nunca objeta, e quem não revisa. Os três
vereditos aparecem lado a lado exatamente para que a diferença se leia.

## O que confirmei na tela

- A seção **Checks on their commits** só aparece para quem a regra da #369 autoriza, e com
  a aba fechada `collected_verifications` **não é consultada** — asserção de custo em
  `test/the_band_web/live/painel_da_pessoa_test.exs`.
- O veredito aparece como `endorsed`, e nunca como `APPROVED`. O enum do GitHub não vaza
  para a tela.
- Sem execução alguma, a tela **nomeia** a ausência ("No check run on this person's
  commits") em vez de mostrar zero seco.
- As 7.313 execuções sem autoria aparecem como lacuna declarada, com a frase que diz que
  elas **não foram descontadas** dos números acima.

## O que continua de fora

47% das execuções de CI não casam com commit de pessoa identificada. A causa não é única —
evento sem commit, autor não promovido a pessoa, ou robô —, e separar as três exigiria
coletar o `event` de cada execução. Está dito na tela como uma parcela só, que é o que a
plataforma sabe hoje.
