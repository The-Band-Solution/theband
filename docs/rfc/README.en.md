# RFCs

Technical proposals open for comment. An RFC exists to **discuss before
deciding**, when the choice is expensive to reverse, has defensible alternatives, or
depends on knowledge we do not have yet.

## Index

| # | Title | Status |
|---|---|---|
| [0001](0001-derivacao-do-modelo-de-informacao.md) | Derivation of the information model from the ontology network | Open for comments |

## RFC or ADR?

| | RFC | ADR |
|---|---|---|
| Moment | before deciding | when deciding |
| Content | alternatives, measurements, what remains to be known | the decision and why |
| State | can stay open indefinitely | accepted or superseded |
| Who reads it | whoever will give an opinion | whoever will implement or revisit it |

A resolved RFC becomes an ADR, when the decision is architectural, or becomes work in the
knowledge base, when it is a modeling matter. The RFC remains as a
record of how it got there.

## Format

File `NNNN-titulo-em-kebab-case.md`, with a header containing status, date and
relation to existing ADRs. The body is free, but open questions must have a
stable identifier (`Q1`, `Q2`, …) — numbers are not recycled, and a resolved question
stays on the list with its destination recorded.
