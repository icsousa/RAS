// =============================================================================
//  PictuRAS · RAS 2026/2027 · Relatório da Fase 2 (Melhoria de RNF)
//  Estilos de página e componentes reutilizáveis.
//  Em princípio NÃO precisam de alterar este ficheiro.
// =============================================================================

// -----------------------------------------------------------------------------
// Orientações do template
// -----------------------------------------------------------------------------
// As caixas de "Orientação" explicam o que escrever em cada secção.
// Antes de entregar, coloquem `mostrar-orientacoes` a `false` em `main.typ`
// (ou apaguem as caixas). Os marcadores #preencher[...] ficam a vermelho até
// serem substituídos — o relatório entregue não deve ter nenhum.
#let mostrar-orientacoes = state("mostrar-orientacoes", true)

#let orientacao(corpo) = context {
  if mostrar-orientacoes.get() {
    block(
      width: 100%,
      fill: rgb("#FFF4E5"),
      stroke: (left: 3pt + rgb("#C76C1B")),
      inset: (x: 10pt, y: 8pt),
      radius: 2pt,
      breakable: true,
    )[
      #set text(size: 9pt)
      #set par(justify: false)
      #text(weight: "bold", fill: rgb("#C76C1B"))[Orientação (apagar antes de entregar)] \
      #corpo
    ]
  }
}

// Texto a substituir pela equipa.
#let preencher(corpo) = text(fill: rgb("#B00020"), style: "italic")[{#corpo}]

// Espaço reservado para uma figura ainda não produzida.
#let figura-pendente(descricao, altura: 5cm) = rect(
  width: 100%,
  height: altura,
  stroke: (dash: "dashed", paint: gray),
  inset: 10pt,
)[
  #align(center + horizon)[
    #text(fill: gray)[Figura a produzir: #descricao]
  ]
]

// -----------------------------------------------------------------------------
// Tabelas
// -----------------------------------------------------------------------------
#let cor-cabecalho = rgb("#F3E3D3")

// Tabela genérica com cabeçalho sombreado.
//   #tabela(colunas: (auto, 1fr), [Cab 1], [Cab 2], ..celulas)
// `n-cabecalho` indica quantas células formam o cabeçalho (por omissão, uma linha).
#let tabela(colunas: (auto, 1fr), tamanho: 9pt, ..celulas) = {
  let c = celulas.pos()
  let n = if type(colunas) == int { colunas } else { colunas.len() }
  set text(size: tamanho)
  set par(justify: false)
  table(
    columns: colunas,
    stroke: 0.5pt + gray,
    inset: 5pt,
    align: left + top,
    fill: (x, y) => if y == 0 { cor-cabecalho },
    table.header(..c.slice(0, n).map(x => strong(x))),
    ..c.slice(n),
  )
}

// Tabela "Campo | Valor" (cabeçalho do caso de uso, identificação, etc.).
#let tabela-campos(..pares) = {
  set text(size: 9pt)
  set par(justify: false)
  table(
    columns: (4.2cm, 1fr),
    stroke: 0.5pt + gray,
    inset: 5pt,
    align: left + top,
    fill: (x, y) => if x == 0 { cor-cabecalho },
    ..pares.pos().enumerate().map(((i, x)) => if calc.even(i) { strong(x) } else { x }),
  )
}

// Páginas na horizontal (para tabelas largas):  #paisagem[ ...conteúdo... ]
#let quebra-capitulo = state("quebra-capitulo", true)
#let paisagem(corpo) = page(flipped: true)[
  #quebra-capitulo.update(false)
  #corpo
  #quebra-capitulo.update(true)
]

// Figura com tabela legendada (aparece na Lista de Tabelas).
#let tab(legenda, corpo) = figure(corpo, kind: table, caption: legenda)

// Prioridade MoSCoW com cor: Must have / Should have / Could have / Won't have (this time).
#let must = text(fill: rgb("#B00020"), weight: "bold")[Must]
#let should = text(fill: rgb("#C76C1B"), weight: "bold")[Should]
#let could = text(fill: rgb("#2E7D32"), weight: "bold")[Could]
#let wont = text(fill: gray.darken(30%), weight: "bold")[Won't]

// -----------------------------------------------------------------------------
// Página e tipografia
// -----------------------------------------------------------------------------
#let project(body) = {
  set document(title: "PictuRAS — Fase 2: Melhoria de Requisitos Não Funcionais")
  set page(paper: "a4", margin: (top: 2.5cm, bottom: 2.5cm, left: 2.5cm, right: 2.5cm))
  // Carlito: equivalente métrico livre (OFL) da Calibri, incluída em fonts/.
  set text(font: "Carlito", lang: "pt", region: "PT", size: 10.5pt)
  set par(justify: true)
  set heading(numbering: "1.")

  show heading: set block(above: 2em, below: 1em)
  show heading.where(level: 1): it => {
    context if quebra-capitulo.get() { pagebreak(weak: true) }
    text(size: 18pt, it)
  }
  show heading.where(level: 2): it => text(size: 14pt, it)
  show heading.where(level: 3): it => text(size: 12pt, it)

  show link: set text(fill: blue.darken(30%))
  show link: underline.with(evade: false)

  show figure.where(kind: table): set figure.caption(position: top)
  show figure: set block(breakable: true)

  body
}

// -----------------------------------------------------------------------------
// Acrescentos da Fase 2
// -----------------------------------------------------------------------------
// Texto escrito sem confirmação do grupo (palpite). Rever e retirar a marca antes
// de entregar:  grep -rn "palpite\[" capitulos  não deve devolver nada.
#let palpite(corpo) = highlight(fill: rgb("#FFF2CC"))[#text(weight: "bold", fill: rgb("#9A6700"))[\[Palpite, confirmar:\]] #corpo]

// Avaliação face ao alvo e ao mínimo.
#let ok = text(fill: rgb("#2E7D32"), weight: "bold")[cumpre o alvo]
#let okmin = text(fill: rgb("#9A6700"), weight: "bold")[cumpre o mínimo]
#let falha = text(fill: rgb("#C62828"), weight: "bold")[abaixo do mínimo]

// -----------------------------------------------------------------------------
// Diagrama de sequência simples (participantes e mensagens numeradas)
//   participantes: array de conteúdos
//   mensagens: array de (de, para, rótulo, tracejado?) com índices dos participantes
// -----------------------------------------------------------------------------
#let sequencia(participantes, mensagens, largura: 16cm, linha: 0.7cm, destaque: ()) = {
  let n = participantes.len()
  let dx = largura / n
  let xc(i) = dx * (i + 0.5)
  let topo = 1.2cm
  let altura = topo + mensagens.len() * linha + 0.3cm
  let seta(x, y, dir, cor) = place(top + left, dx: x, dy: y, polygon(
    fill: cor, stroke: none,
    (0pt, 0pt), (-dir * 5pt, -2.5pt), (-dir * 5pt, 2.5pt),
  ))
  set text(size: 7pt)
  block(width: largura, height: altura, breakable: false, {
    for (i, p) in participantes.enumerate() {
      place(top + left, dx: xc(i) - dx / 2 + 2pt, dy: 0pt,
        rect(width: dx - 4pt, height: 0.95cm, fill: rgb("#F3E3D3"), stroke: 0.5pt + gray, radius: 2pt,
          align(center + horizon, text(size: 7.5pt, weight: "bold", p))))
      place(top + left, dx: xc(i), dy: 0.95cm,
        line(length: altura - 0.95cm, angle: 90deg, stroke: (paint: gray, thickness: 0.5pt, dash: "dashed")))
    }
    for (k, m) in mensagens.enumerate() {
      let (a, b, rotulo, ..resto) = m
      let tracejado = resto.len() > 0 and resto.at(0)
      let y = topo + (k + 0.75) * linha
      let cor = if destaque.contains(k + 1) { rgb("#C76C1B") } else { black }
      let rot = [*#(k + 1).* #rotulo]
      if a == b {
        place(top + left, dx: xc(a), dy: y - 0.25cm,
          rect(width: 0.35cm, height: 0.25cm, stroke: 0.6pt + cor))
        place(top + left, dx: xc(a) + 0.45cm, dy: y - 0.42cm, box(fill: white, inset: 1pt, rot))
      } else {
        let x1 = calc.min(xc(a), xc(b))
        let x2 = calc.max(xc(a), xc(b))
        let dir = if b > a { 1 } else { -1 }
        place(top + left, dx: x1, dy: y,
          line(length: x2 - x1, stroke: (paint: cor, thickness: 0.7pt, dash: if tracejado { "dashed" } else { none })))
        seta(xc(b), y, dir, cor)
        let w = calc.max(x2 - x1, 5.6cm)
        place(top + left, dx: (x1 + x2) / 2 - w / 2, dy: y - 0.36cm,
          box(width: w, align(center, box(fill: white, inset: (x: 1.5pt, y: 0.5pt), text(fill: cor, rot)))))
      }
    }
  })
}
