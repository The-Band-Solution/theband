# Contrato — rotação da chave mestra

**Feature**: 001 · **Requisito**: FR-005b · **Depende de**: research.md R3

Escrito antes da implementação, conforme o princípio VI da constituição.

## O problema que resolve

A chave mestra é o segredo crítico único da plataforma: com ela, todas as
credenciais de todas as organizações são legíveis. Um segredo assim precisa poder
ser trocado — por suspeita de vazamento, por saída de quem tinha acesso, ou por
política de rotação periódica.

Sem este caminho, trocar a chave significaria perder todas as credenciais
cadastradas, o que na prática significa nunca trocar.

## Como o Cloak permite a troca

O `Cloak` decifra com **qualquer** cipher configurado e cifra sempre com o
marcado como `:default`. É isso que torna a rotação possível sem parada: durante
a janela, a chave nova cifra e as duas decifram.

```text
1. gerar a chave nova                    mix the_band.gen_key
2. THE_BAND_PREVIOUS_MASTER_KEY = antiga   (passa a decifrar o que já existe)
   THE_BAND_MASTER_KEY          = nova     (passa a cifrar o que for gravado)
3. reiniciar a aplicação
4. recifrar o que está no banco          mix the_band.rotate_key
5. remover THE_BAND_PREVIOUS_MASTER_KEY do ambiente
6. reiniciar a aplicação
```

O passo 5 é parte da rotação, não opcional: manter a chave antiga no ambiente
depois da recifragem mantém viva exatamente a chave que se quis aposentar.

## API pública

Mix task `mix the_band.rotate_key`.

```text
mix the_band.rotate_key            recifra todas as credenciais
mix the_band.rotate_key --dry-run  conta o que seria recifrado, sem gravar
```

Saída em sucesso:

```text
recifradas 12 credenciais de 3 organizações
```

## Garantias

**Idempotente.** Rodar duas vezes não estraga nada: a segunda execução recifra
com a mesma chave padrão e o resultado é idêntico. Não há estado "já rotacionado"
para consultar — e não deveria haver, porque ele mentiria depois de uma troca de
chave feita fora da task.

**Sem downtime de leitura.** A recifragem acontece registro a registro, e cada um
é lido com a chave que o cifrou. Uma credencial em uso durante a recifragem
continua legível antes e depois.

**Nunca escreve o segredo em log.** A task reporta contagens, jamais valores. O
`Inspect` do schema já é redigido; a task não desfaz isso por conveniência de
diagnóstico.

**Falha alto se a chave anterior não decifrar.** Se algum registro não puder ser
lido com nenhuma das chaves configuradas, a task **para** e diz quantos
registros ficaram para trás. Continuar em silêncio deixaria credenciais órfãs que
só apareceriam quando alguém tentasse usá-las — no meio de uma coleta.

## O que este contrato NÃO expõe, e por quê

| Ausente | Razão |
|---|---|
| rotação automática por agendamento | trocar chave mestra é ato deliberado, com quem opera acompanhando; agendar tornaria a falha silenciosa e noturna |
| rotação por organização | a chave é da plataforma, não do tenant. Chave por tenant é outra arquitetura, e exigiria ADR |
| gerar a chave nova dentro da própria task | a task recifra; quem gera a chave é `mix the_band.gen_key`, e quem decide onde guardá-la é quem opera. Juntar as duas convidaria a chave a passar por um pipe e parar num log |
| desfazer a rotação | não existe "voltar": basta inverter as variáveis de ambiente e rodar de novo. Um comando de undo daria a impressão de que a chave antiga continua válida |
