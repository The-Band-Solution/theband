<div class="tb-assinatura">Funcionalidades · as credenciais</div>

# Todo segredo protegido em repouso

<dl class="tb-recibo">
<dt>a tela</dt><dd><code>/tools</code>, as credenciais de cada ferramenta conectada, e <code>/ai</code>, a chave do provedor de modelos</dd>
<dt>a spec</dt><dd><span class="tb-marca tb-declarado"><span class="tb-q"></span>064 · Draft · 2026-09-12</span> <a href="https://github.com/The-Band-Solution/theband/tree/development/specs/064-segredo-em-repouso">specs/064-segredo-em-repouso, no GitHub</a></dd>
<dt>em produção</dt><dd><span class="tb-marca tb-observado"><span class="tb-q"></span>desde a v0.11.0</span> sem aceitação registrada; a idade da credencial na tela ainda não, está em <code>development</code></dd>
<dt>a régua</dt><dd>só o que a tela faz; o que a spec pede e não está na tela fica nomeado no fim</dd>
</dl>

O The Band guarda três tipos de segredo: a senha de quem entra, o que prova que uma sessão está
aberta, e as credenciais de terceiros — o token de uma ferramenta, a chave de um provedor de
modelos — que a plataforma precisa apresentar a quem coleta. Esta funcionalidade trata cada um do
jeito que ele pede, para que uma cópia do banco não sirva para entrar como ninguém nem para usar a
credencial de ninguém. Quase tudo isso acontece longe da tela. O que aparece nela é pouco, e está
descrito abaixo: o que muda ao entrar e sair, e a idade de cada credencial onde ela é administrada.

## O que você passa a conseguir fazer

**Sair passa a ser sair.** Quando você sai, a sessão termina de verdade, e não só neste navegador.
Uma conta desativada perde as sessões abertas na hora, e reativá-la não as devolve: quem estava
dentro entra de novo.

**Todo mundo entrou de novo uma vez.** Na chegada da v0.11.0, toda sessão aberta deixou de valer, e
cada pessoa precisou fazer login outra vez. Foi a única vez, e foi de propósito: nenhuma sessão de
antes da mudança volta a valer.

**Ver a credencial sem vê-la.** Na tabela de credenciais de `/tools`, a coluna `credential` mostra
só os últimos caracteres do token. A própria tela diz por quê:

> *"The credential is encrypted at rest and is never shown in usable form. The last four
> characters exist only to tell one credential from another."*

Em `/ai`, a chave do provedor segue a mesma regra: *"Checked against the provider before being
written, encrypted at rest"*.

**Saber há quanto tempo cada credencial está em uso** <span class="tb-marca tb-ausente"><span class="tb-q"></span>ainda não em produção</span>.
Em `development`, a coluna `registered` de `/tools` passa a mostrar a data em que a credencial foi
guardada, há quanto tempo, e uma marca com o estado, legível sem depender da cor:

| a marca | o que quer dizer |
|---|---|
| `within … months` | dentro do prazo; abaixo dela, a data a partir da qual a troca será pedida (`replacement asked from …`) |
| `replace · … in use` | passou do prazo e está ativa; a tela pede a troca |
| `past … months · inactive` | passou do prazo, mas está desativada; a tela não pede troca, pede para remover se não serve mais |
| `age unknown` | a plataforma não sabe quando ela foi guardada — e por isso **não** a conta como dentro do prazo |

Quando uma credencial ativa passa do prazo, o aviso aparece logo abaixo de `Credentials`, antes da
tabela: *"Replace the token “…”."*, com a data em que foi registrada e há quanto tempo. O aviso diz
três coisas que importam para decidir:

- **nada para**: *"Collection goes on with this token meanwhile. Nothing stops and nothing is
  blocked."* A plataforma pede a troca; ela nunca interrompe a coleta por causa da idade;
- **como trocar**: gerar um token novo no GitHub, adicioná-lo pelo botão `replace the token`, e,
  depois que ele funcionar, desativar ou remover o antigo — e revogá-lo também no GitHub, porque
  remover aqui não o revoga lá;
- **quem pode**: *"an administrator, or someone who answers for"* a organização da ferramenta.

Adicionado o token novo, enquanto o antigo continuar ativo, o aviso muda para *"The new token is in.
“…” is still active."* — a troca só está completa quando o antigo sai.

Em `/ai` vale o mesmo para a chave do provedor de modelos (*"Replace this key."*), e a tela guarda a
história da troca: em `previous key`, de quando a quando a chave anterior ficou em uso, com a frase
*"the date is kept; the secret is gone"*. A chave configurada no ambiente do servidor aparece como
`age unknown`, e a tela diz de quem é a ausência: *"The absence is the platform's, not the
provider's."*

## O que a tela recusa, e diz por quê

Esta funcionalidade não acrescenta recusa nova à tela. O que ela acrescenta são **pedidos** — trocar
a credencial, remover a inativa —, e nenhum deles bloqueia nada.

| situação | o que a tela diz |
|---|---|
| credencial ativa que passou do prazo | *"Replace the token “…”."* — e, logo abaixo, *"Nothing stops and nothing is blocked."* |
| credencial sem data conhecida | *"The age of “…” is unknown."* — *"The platform has no record of when it was saved, so it cannot tell whether it is due. Replacing it starts a dated count."* |
| credencial inativa que passou do prazo | *"“…” is inactive and was registered …. Its secret is still stored; remove it if it is no longer needed."* |
| remover uma credencial | pede confirmação: *"Destroy this credential? The secret stops existing, and this cannot be undone."* |

## O que ela não faz

- **Não expira credencial.** Passado o prazo, o token continua funcionando e a coleta continua. A
  troca é pedida, nunca imposta: quem decide trocar é quem administra a ferramenta.
- **Não revoga nada na origem.** Remover uma credencial no The Band apaga o segredo daqui; no GitHub
  ou no provedor, ela continua valendo até alguém revogá-la lá.
- **Não cifra a senha de quem entra.** A senha não é guardada de forma recuperável, nem pela
  plataforma — e cifrá-la criaria justamente esse caminho. É a primeira correção que a spec faz ao
  pedido que a originou.
- **Não mostra a idade da credencial em produção ainda.** A coluna `registered`, as marcas e os
  avisos de troca estão em `development` e chegam na próxima release.
- **Não tem aceitação registrada.** A parte que está no ar entrou na v0.11.0 por ser conserto de
  segurança, e a aceitação é feita depois, em produção. No ar e não aceita é diferente de aceita.
