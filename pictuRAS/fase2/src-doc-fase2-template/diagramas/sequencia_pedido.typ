#set page(width: 17cm, height: auto, margin: 0.4cm)
#set text(font: "Carlito", lang: "pt")
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

#sequencia(
    ([Frontend], [nginx + api_gateway], [projects], [img_storage + S3], [RabbitMQ], [video_tool], [ws_gateway]),
    (
      (0, 1, [POST …/video (multipart)]),
      (1, 2, [POST /projects/:u/:p/video (FormData com o buffer)]),
      (2, 2, [ffprobe + limites do perfil]),
      (2, 3, [POST /upload (buffer) → SeaweedFS]),
      (2, 0, [201: vídeo adicionado ao projeto], true),
      (0, 2, [POST …/tool (efeito e parâmetros, via gateway)]),
      (0, 2, [POST …/process (Apply, via gateway)]),
      (3, 2, [original copiado para o volume image_data]),
      (2, 4, [publish video_queue (pipeline inteiro)]),
      (2, 0, [201: processamento iniciado], true),
      (4, 5, [entrega (prefetch = 1)]),
      (5, 5, [ffmpeg aplica o pipeline inteiro]),
      (5, 4, [publish ws_queue: progresso %]),
      (4, 6, [consome ws_queue]),
      (6, 0, [video-progress (WebSocket)], true),
      (5, 4, [publish project_queue: resultado; ack só no fim]),
      (4, 2, [process_msg consome project_queue]),
      (2, 3, [POST out (guarda o resultado)]),
      (2, 4, [publish ws_queue: success]),
      (6, 0, [process-update (WebSocket)], true),
      (0, 2, [GET …/process/url]),
      (2, 0, [URL do resultado], true),
    ),
    destaque: (9, 11, 12, 13, 16),
  )
