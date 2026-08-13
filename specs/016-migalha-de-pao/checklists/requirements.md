# Specification Quality Checklist: a migalha de pão

**Criada em**: 2026-08-13 · **Feature**: [spec.md](../spec.md)

- [x] Sem detalhe de implementação nos requisitos
- [x] Focada no valor: saber onde estou e subir um nível
- [x] Nenhum `[NEEDS CLARIFICATION]`
- [x] Requisitos testáveis, inclusive os de acessibilidade
- [x] Critérios mensuráveis: 5 telas com, 6 sem, 3 formas viram 1
- [x] Casos de borda: telefone, título comprido, recurso apagado, outro tenant
- [x] Escopo delimitado — página de organização continua fora
- [x] Premissas identificadas

## Notas

**A medida achou um defeito que o pedido não mencionava**: o detalhe da equipe tem um botão
*"voltar"* **em português**, no meio de uma interface em inglês. Três telas resolvem a mesma
necessidade de três jeitos, e uma delas em outro idioma — é o sintoma que o design system existe
para curar.

**E o caso que decide a feature é o detalhe da issue**: ele pertence a um repositório *e* à lista de
trabalho. Uma migalha fixa diria um caminho que pode não ser o percorrido, e é por isso que a US2
existe separada.
