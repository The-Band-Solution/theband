# Quickstart — validar a 052 de ponta a ponta

## 1. As violações primeiro, no domínio

```bash
mix test test/the_band/tenants/bootstrap_test.exs
```

Esperado: verde, com os dez invariantes do
[contrato](contracts/primeira-conta.md) provados — inclusive os quatro que só
falham se alguém reescrever a validação, deixar a senha vazar para o retorno,
esquecer a transação, ou trocar a pergunta de "existe algum admin" por "existe
este e-mail".

## 2. O percurso do release, contra um banco vazio

Usa o profile de produção do compose, que já sobe o Postgres com o banco criado:

```bash
docker compose --profile producao down -v          # banco VAZIO, de propósito
THE_BAND_TENANT_NOME="Organização de Ensaio" \
THE_BAND_TENANT_SLUG="ensaio" \
THE_BAND_ADMIN_EMAIL="ensaio@exemplo.test" \
THE_BAND_ADMIN_SENHA="$(openssl rand -base64 18)" \
  docker compose --profile producao up -d --build
docker compose --profile producao logs app | grep -E "migrações aplicadas|primeira conta"
```

Esperado, nesta ordem:

```
migrações aplicadas.
primeira conta criada: ensaio@exemplo.test, admin de ensaio.
```

> O `down -v` **apaga o volume** do banco de ensaio. É o que torna o passo
> válido — contra um banco povoado, ele provaria outra coisa.

**A senha não aparece.** Confira:

```bash
docker compose --profile producao logs app | grep -c "$THE_BAND_ADMIN_SENHA"
```

Esperado: `0`. Este é o SC-003.

## 3. Entrar com a conta criada

```bash
curl -s -o /dev/null -w "%{http_code}\n" localhost:4001/sign-in
```

Esperado: `200`. E, no navegador, entrar com o e-mail e a senha do passo 2 —
a sessão abre com poder de administração. Este é o SC-001.

## 4. Reiniciar não duplica nem sobrescreve

```bash
docker compose --profile producao restart app
docker compose --profile producao logs app --tail 20 | grep "já existe"
```

Esperado: `já existe administrador — nada a criar.`

Agora a prova que separa esta feature de um defeito — **trocar a senha pela
interface e reiniciar cinco vezes**, com a variável ainda no valor antigo:

```bash
for i in $(seq 1 5); do docker compose --profile producao restart app; sleep 20; done
```

Esperado: a senha que a pessoa escolheu na interface continua valendo, e a do
ambiente **não** volta. Este é o SC-005, e é o cenário que "roda em todo boot"
tornaria perigoso se não estivesse provado.

## 5. Sem as variáveis, a plataforma sobe assim mesmo

```bash
docker compose --profile producao down -v
docker compose --profile producao up -d --build        # nenhuma das quatro
docker compose --profile producao logs app | grep -E "sem THE_BAND|Running TheBandWeb"
curl -s -o /dev/null -w "%{http_code}\n" localhost:4001/sign-in
```

Esperado: o log **nomeia** as variáveis ausentes, o endpoint sobe, e `/sign-in`
responde `200` — sem conta alguma. Este é o SC-006, e é o que impede uma
variável esquecida de virar produção fora do ar.

## 6. A recusa nomeia a regra

```bash
docker compose --profile producao down -v
THE_BAND_TENANT_NOME="Ensaio" THE_BAND_TENANT_SLUG="Ensaio Com Espaço" \
THE_BAND_ADMIN_EMAIL="ensaio@exemplo.test" THE_BAND_ADMIN_SENHA="curta" \
  docker compose --profile producao up -d --build
docker compose --profile producao logs app | grep "recusada"
```

Esperado: a recusa diz **qual** campo e **qual** regra — slug fora do formato,
senha abaixo do mínimo — e a plataforma sobe. Note que são duas violações ao
mesmo tempo, de propósito: o slug com espaços e maiúsculas, e a senha de cinco
caracteres.

## 7. Em produção (o percurso real)

No painel de quem hospeda, acrescentar as quatro variáveis às que já existem,
implantar, e conferir no log do contêiner a linha `primeira conta criada`.
Depois entrar pela tela de entrada.

**E então remover `THE_BAND_ADMIN_SENHA` do painel.** Enquanto ela existir, a
senha é legível por quem tem acesso ao painel — é o custo declarado da escolha
por variáveis de ambiente, e o runbook §8 diz isso no lugar onde alguém vai ler.

Removê-la não afeta nada: no boot seguinte o log dirá `já existe administrador`.
