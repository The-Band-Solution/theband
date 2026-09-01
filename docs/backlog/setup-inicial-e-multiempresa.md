# Setup inicial e a empresa com endereço próprio

Levantado em conversa com a pessoa mantenedora em 2026-09-01. **Ainda não é
spec** — é o desenho discutido, com as decisões que faltam marcadas como tal.

O pedido, na forma em que veio:

> *"Eu sou de uma empresa e possuo uma organização no GitHub — como fazer um
> wizard inicial para isso na tela inicial do The Band? E pessoas dessa
> organização podem logar e ver seus dados dela. Ao criar uma organização, ela
> pode ganhar a URL `<empresa>.theband.dev`."*
>
> E, corrigindo o modelo: *"uma empresa pode ter uma ou mais organizações no
> GitHub"*. E: *"ao acessar `empresa.theband.dev` e o login da pessoa, ela vê
> dados da empresa que logou"*.

---

## São quatro features, não uma

| # | o que é | existe hoje? |
|---|---|---|
| 1 | **a empresa se cria sozinha** — alguém de fora vira tenant sem console | não. A primeira conta nasce do ambiente (052); as demais, um admin cria (051) |
| 2 | **a empresa prova que a organização do GitHub é dela** | não existe nada disso |
| 3 | **as pessoas entram com a conta que já têm** | é a spec **049**, escrita e ainda não implementada |
| 4 | **cada empresa ganha endereço** — `<empresa>.theband.dev` | não |

**A 3 não é opcional.** Sem login pelo GitHub, *"as pessoas da organização
entram"* vira alguém digitando 88 senhas temporárias. A 049 deixa de ser item de
fila e vira **pré-requisito**.

---

## O que o esquema já suporta, e o que ele quebra

**Já suporta**: `connected_tools` tem `tenant_id` **e** `organization_login` na
mesma linha — uma empresa, N organizações conectadas, cada uma com sua
credencial e seu intervalo. O ensaio de restauração de 2026-08-31 mediu
`eo_organizations=3` num tenant só. **O modelo de uma empresa com várias
organizações já está de pé.**

**Quebra**: `lib/the_band/tenants/user.ex` diz na primeira linha do moduledoc —
*"Pessoa usuária da plataforma, ligada a **exatamente um tenant**"*. Ao entrar
pelo GitHub, a plataforma recebe uma identidade que pode pertencer a
organizações de **empresas diferentes** — alguém que presta serviço para duas,
ou contribui numa e trabalha noutra. Hoje não há representação para isso.

---

## A decisão que decide todas as outras: como a empresa prova a organização

Sem prova, qualquer um cria um tenant e passa a coletar dados de uma organização
que não é dele.

| resposta | o que prova | o que custa |
|---|---|---|
| **token pessoal** (o que existe hoje) | que **uma pessoa** tem acesso — não que a organização autorizou. Quando ela sai, a coleta morre | nada novo |
| **App do GitHub instalado na organização** | quem instala é admin da organização, e **a instalação é a prova**. Dá também o token de coleta, com escopo da organização | muda o modelo de credenciais: hoje `connected_tools` guarda segredo cifrado por tenant; um App gera token efêmero a partir de uma chave privada única da plataforma |

**A prova é por organização, não por empresa.** Conectar a segunda organização é
instalar de novo — o que é bom: a empresa cresce sem refazer nada.

---

## O subdomínio: por que ele não é enfeite

A leitura inicial era que `<empresa>.theband.dev` seria uma **segunda fonte da
verdade** competindo com a sessão — e duas fontes que podem divergir, sem
árbitro, são a classe de defeito que este projeto persegue.

Com a correção de que uma empresa tem várias organizações, o subdomínio vira
**outra coisa**: ele **seleciona** qual empresa a pessoa está acessando, e
antecede a sessão em vez de competir com ela.

```
empresa-a.theband.dev  →  a mesma conta do GitHub, escopo da empresa A
empresa-b.theband.dev  →  a mesma conta,           escopo da empresa B
```

Sem o subdomínio, essa escolha viraria um seletor dentro da tela — pior: o
endereço não diria onde a pessoa está, e um link colado num chat levaria ao
lugar errado.

### A inversão, e por que ela é a feature inteira

**Hoje** o tenant vem da sessão
(`lib/the_band_web/plugs/current_scope.ex`): a pessoa não consegue pedir outro,
porque não existe onde pedir. A garantia é **da construção**.

**Com o subdomínio** o tenant vem da URL — entrada não confiável, que qualquer
um digita. A pergunta *"esta pessoa pertence a esta empresa?"* deixa de ser
verdade por construção e vira **verificação que roda em toda requisição**.

O `AGENTS.md` já classifica o vizinho disso: *"Consulta sem tenant — não é bug de
correção, é bug de segurança"*. Com o host decidindo, a lista ganha o segundo
item: **consulta com o tenant errado**.

---

## Três invariantes que precisam estar na spec, não em comentário

**1. O cookie de sessão continua sem `domain`.**
`lib/the_band_web/endpoint.ex` define a sessão sem o campo `domain` — e por isso
o cookie é **do host**: a sessão aberta em `empresa-a.theband.dev` não é enviada
para `empresa-b.theband.dev`. O isolamento entre empresas já vem de graça.

Acrescentar `domain: ".theband.dev"` — que é o que alguém faz para "compartilhar
o login entre os subdomínios" — **entrega a sessão de uma empresa a todas as
outras**. Uma linha, e o isolamento acaba.

**2. A recusa não distingue os dois casos.**
Pessoa abre `empresa-x.theband.dev` e não é membro: a resposta **não pode**
diferenciar *"esta empresa não existe"* de *"você não faz parte dela"*. Se
diferenciar, o subdomínio vira oráculo — qualquer um descobre a lista de
clientes testando nomes.

**3. Nomes reservados.**
`app`, `www`, `api`, `admin`, `sign-in`. Hoje `app.theband.dev` **é** a
plataforma. Sem lista de reserva, a primeira empresa chamada `app` derruba o
produto.

---

## O que já está pronto, por acaso

- **o certificado** de origem instalado em 2026-09-01 cobre `*.theband.dev` —
  qualquer subdomínio já tem cifra válida;
- **a lista de origens** da feature 054 aceita `*.theband.dev` como entrada,
  então o socket funciona em subdomínio novo **sem release**;
- **o cookie** já é host-only, como acima.

---

## As perguntas em aberto

| # | pergunta | por que ela decide o desenho |
|---|---|---|
| 1 | **uma conta ou várias?** a mesma pessoa em duas empresas é uma conta com dois vínculos, ou duas contas? | o vínculo com dois é mais correto e mexe em `users`, hoje `belongs_to :tenant` |
| 2 | **quem entra numa empresa?** ser membro de **alguma** organização conectada basta, ou precisa ser declarado? | a primeira é automática e pode surpreender; a segunda é segura e dá trabalho |
| 3 | **membro privado** | o GitHub só entrega quem tornou a associação pública, salvo permissão do App. Metade da organização pode não conseguir entrar |
| 4 | **custo sem teto** | uma organização média custou 125 repositórios e 4.895 issues. Auto-serviço sem limite é conta aberta na API e no disco |
| 5 | **a primeira hora é vazia** | a pessoa termina o wizard e a coleta ainda não rodou. Mostrar zero faria o produto contradizer o próprio argumento: zero não é "ainda não sei" |

---

## Como decompor

| ordem | spec | por quê |
|---|---|---|
| 1 | **entrar com o GitHub** — a [049](../../specs/049-entrar-com-github/spec.md), já escrita | pré-requisito de tudo |
| 2 | **a empresa se instala** — App do GitHub, prova de posse, tenant declarado | a decisão do App é o coração |
| 3 | **o endereço por empresa** | depende da inversão do plug e do vínculo pessoa↔empresa |

**Onde as equipes entram**: a feature de declarar equipes (issue #397, ampliada
em 2026-09-01) é a estrutura **dentro** da empresa. Terminado o wizard, a
organização tem pessoas coletadas e precisa organizá-las — é a tela seguinte do
mesmo fluxo, e por isso vem antes na ordem de construção.
