// =============================================================================
//  PictuRAS · RAS 2026/2027 · Relatório da Fase 2 — Melhoria de RNF
//  Compilar:  typst compile --font-path fonts main.typ relatorio-fase2.pdf
//  Feito a partir do template da Fase 1. Rascunho escrito com apoio de IA (Claude)
//  e a rever pelo grupo (PL3-G7). Antes de entregar:
//    grep -rn "palpite\[\|preencher\[" capitulos   -> não deve devolver nada
// =============================================================================
#import "cover.typ": cover
#import "template.typ": *

#show: project

#mostrar-orientacoes.update(false)

#cover(
  title: "Fase 2 — Melhoria de Requisitos Não Funcionais",
  subtitle: "Especificação, refatoração e avaliação",
  group: "Grupo PL3-G7",
  authors: (
    (name: "Duarte Pinto Bravo", number: "pg63951"),
    (name: "Ivo Costa Sousa", number: "pg63976"),
    (name: "João Afonso Almeida Sousa", number: "pg62405"),
    (name: "Ricardo Eusebio Cerqueira", number: "pg64022"),
    (name: "Tiago Gonçalves Melo", number: "pg65445"),
  ),
  "Novembro, 2026",
)

#set page(numbering: "i", number-align: center)
#counter(page).update(1)

#include "capitulos/00-historico-versoes.typ"

#outline(title: [Índice], indent: auto, depth: 3)
#pagebreak()
#outline(title: [Lista de Figuras], target: figure.where(kind: image))
#outline(title: [Lista de Tabelas], target: figure.where(kind: table))

#set page(numbering: "1", number-align: center)
#counter(page).update(1)

// Parte I — Enquadramento
#include "capitulos/01-introducao.typ"
#include "capitulos/02-ambiente-metodo.typ"

// Parte II — Os dois requisitos não funcionais
#include "capitulos/03-rnf01-carregamento.typ"
#include "capitulos/04-rnf02-elasticidade.typ"

// Parte III — Avaliação transversal, IA e conclusão
#include "capitulos/05-efeitos-colaterais.typ"
#include "capitulos/06-preservacao-funcional.typ"
#include "capitulos/07-validade-medicoes.typ"
#include "capitulos/08-utilizacao-ia.typ"
#include "capitulos/09-conclusao.typ"

#include "capitulos/99-anexos.typ"
