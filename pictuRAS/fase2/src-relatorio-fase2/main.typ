// =============================================================================
//  PictuRAS · RAS 2026/2027 · Relatório da Fase 2 — Melhoria de RNF
//  Compilar:  typst compile --font-path fonts main.typ relatorio-fase2.pdf
//  Estrutura e numeração de capítulos, secções, tabelas e figuras seguem o
//  template oficial da Fase 2 (template-fase2). Diagramas: pasta diagramas/
//  (Graphviz), exportados para images/. Antes de entregar:
//    grep -rn "preencher\[\|palpite\[" capitulos   -> não deve devolver nada
// =============================================================================
#import "cover.typ": cover
#import "template.typ": *

#show: project

#mostrar-orientacoes.update(false)

#cover(
  title: "Fase 2 — Melhoria de Requisitos Não Funcionais",
  subtitle: "Diagnóstico, decisões arquiteturais e avaliação",
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
#pagebreak()

#outline(title: [Índice], indent: auto, depth: 2)
#pagebreak()
#outline(title: [Lista de Figuras], target: figure.where(kind: image))
#pagebreak()
#outline(title: [Lista de Tabelas], target: figure.where(kind: table))

#set page(numbering: "1", number-align: center)
#counter(page).update(1)

// Parte I — Enquadramento
#include "capitulos/01-introducao.typ"
// Parte II — Diagnóstico (Exercício 6, Bloco 1)
#include "capitulos/02-ambito-arquitetura.typ"
#include "capitulos/03-padroes.typ"
#include "capitulos/04-alternativas.typ"
// Parte III — Qualidade (Exercício 6, Bloco 2)
#include "capitulos/05-cenarios-qualidade.typ"
#include "capitulos/06-candidatos-rnf.typ"
// Parte IV — Táticas, decisões, medição e resultados (Exercício 7)
#include "capitulos/07-taticas.typ"
#include "capitulos/08-decisoes.typ"
#include "capitulos/09-vistas.typ"
#include "capitulos/10-tradeoffs-medicao.typ"
// Parte V — Síntese
#include "capitulos/11-conclusoes.typ"
#include "capitulos/12-utilizacao-ia.typ"

#include "capitulos/99-anexos.typ"
