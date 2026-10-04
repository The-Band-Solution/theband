<div class="tb-assinatura">Funcionalidades · a operação</div>

# A aplicação serve com menos poder no banco

<dl class="tb-recibo">
<dt>a tela</dt><dd><span class="tb-marca tb-ausente"><span class="tb-q"></span>sem tela</span> mudança no banco, sem interface</dd>
<dt>a spec</dt><dd><span class="tb-marca tb-declarado"><span class="tb-q"></span>071 · Draft · 2026-10-02</span> <a href="https://github.com/The-Band-Solution/theband/tree/development/specs/071-papeis-do-banco">specs/071-papeis-do-banco, no GitHub</a></dd>
<dt>em produção</dt><dd><span class="tb-marca tb-ausente"><span class="tb-q"></span>ainda não</span> está em <code>development</code>, e chega na próxima release</dd>
<dt>a régua</dt><dd>só o que muda para quem usa e para quem opera; o mecanismo fica na spec</dd>
</dl>

Até aqui, a aplicação que atende as telas, a API e a coleta usava, no banco, o mesmo acesso que
cria e altera a estrutura das tabelas. Com esta mudança, são dois acessos separados: um que
**altera a estrutura**, usado só na hora de publicar uma versão, e outro, com menos poder, que
**serve** — lê e grava os dados, e nada além disso. As regras de integridade que o próprio banco
garante, como o registro que só aceita acréscimo, deixam de estar ao alcance de quem serve. É uma
página para quem opera a plataforma: quem só usa não vê diferença nenhuma.

## O que você passa a conseguir fazer

**Quem usa: nada muda na tela.** Nenhuma tela, nenhum rótulo, nenhuma permissão de pessoa muda.
Quem vê o quê continua decidido pelas mesmas regras de antes. O que muda é invisível: a aplicação
que atende você passa a rodar com menos poder no banco, e por isso as garantias que o banco dá
continuam valendo mesmo que algo dentro da aplicação falhe.

**Quem opera: a publicação continua sozinha.** Publicar uma versão continua aplicando as mudanças
de estrutura do banco no próprio deploy, sem passo manual a cada vez. A diferença é que essa etapa
usa o acesso que altera a estrutura, e a aplicação que fica de pé depois dela já não o tem.

**Quem opera: um passo, uma vez.** A separação só passa a valer em produção depois de quem opera
criar os dois acessos e configurar as credenciais no painel de implantação, seguindo o roteiro da
operação. Os valores são gerados por quem opera, e não passam por chat, commit nem mensagem.

**Quem opera: saber se está em vigor.** A plataforma não supõe que a separação está em vigor só
porque a configuração existe: ela confere no próprio banco, e diz se está em vigor, se não está, e
por quê.

**O backup continua restaurável.** Uma cópia feita antes da troca pode ser restaurada depois dela, e
a aplicação volta a servir com o acesso de menos poder, sem acerto manual.

## O que a tela recusa, e diz por quê

Não há tela, e portanto não há recusa visível. A única situação que quem opera percebe é no deploy:
se a credencial que altera a estrutura não estiver configurada **e** houver mudança de estrutura a
aplicar, a versão nova não sobe — em vez de servir sobre um banco pela metade. Sem mudança pendente,
ela sobe normalmente.

## O que ela não faz

- **Não muda o que cada pessoa pode ver ou fazer.** As permissões de quem usa são as mesmas; esta
  mudança é sobre o que a aplicação pode fazer com o banco, não sobre o que as pessoas podem fazer
  com a aplicação.
- **Não vale sozinha em produção.** Até quem opera seguir o roteiro, a plataforma continua
  funcionando como antes, e a conferência diz que a separação não está em vigor.
- **Não está em produção.** Está em `development`, sem release e sem aceitação registrada.
