#import "../template.typ": *

= Testes e Validação do MVP

== Estratégia e ambiente de testes

Os critérios de aceitação da ERS são a base dos testes, organizados em três níveis:

- *Testes do worker* (`Tools/video/tests`, `unittest`): executam as operações com FFmpeg real sobre vídeos gerados no próprio teste (`testsrc2` 1280×720 a 30 fps com tom de 440 Hz e _keyframe_ a cada 2 s; um vídeo cuja luminância identifica cada fotograma; um vídeo cinzento para medir cor). Os testes de desempenho correm com `RUN_PERF=1`.
- *Testes do serviço `projects`* (`projects/test`, `node --test`): regras por perfil, validação de parâmetros, LUT e legendas, e ciclo de vida dos trabalhos (quota, cancelamento, versões) com MongoDB, S3, RabbitMQ e `users` simulados.
- *Testes ponta a ponta e de interface* (manuais), com a stack completa (`docker compose up --build`) e o browser.

Ambiente dos testes automáticos: FFmpeg 6.1, Python 3.13 com Pillow e NumPy, Node.js 22. #preencher[Ambiente dos testes manuais: sistema operativo, browser, versão do Docker.]

== Testes realizados

#tab([Testes e resultados],
  tabela(
    colunas: (2.3cm, 1.5cm, 1fr, 3cm, 2.2cm),
    tamanho: 8pt,
    [ID], [Tipo], [Descrição (Dado… Quando… Então…)], [Requisito(s)], [Resultado],
    table.cell(colspan: 5, fill: luma(240))[*Transversais*],
    [TST-SUBMIT-01], [Auto (Node)], [Dado um AVI, HEVC ou áudio MP3, Quando é submetido, Então é rejeitado; MP4 H.264/AAC (com ou sem áudio) é aceite.], [REQ-VID-SUBMIT-001], [Passa],
    [TST-SUBMIT-02], [Auto (Node)], [Dado um vídeo de 75 s, Quando um Anónimo o submete, Então é rejeitado; um Registado aceita até 300 s e um Premium até 3600 s.], [REQ-VID-SUBMIT-002], [Passa],
    [TST-SUBMIT-03], [Auto (FFmpeg)], [Dado um vídeo 1280×720 e limite 480p, Quando processado, Então o resultado tem 852×480.], [REQ-VID-SUBMIT-003], [Passa],
    [TST-SUBMIT-04/05], [Auto (Node)], [Upload cria o vídeo com versão original e mapa de keyframes; acima do limite nada é guardado.], [REQ-VID-SUBMIT-001/002], [Passa],
    [TST-STATUS-01], [Auto (FFmpeg)], [Dado um trabalho em curso, Quando é criado o pedido de cancelamento, Então o FFmpeg é terminado com o código `cancelled`.], [REQ-VID-STATUS-003], [Passa],
    [TST-STATUS-02], [Auto (FFmpeg)], [Dado um limite de memória de 60 MB, Quando o trabalho o excede, Então termina com `out_of_memory` (filtros de cor e Pan & Crop).], [REQ-VID-STATUS-005], [Passa],
    [TST-STATUS-03..05], [Auto], [Mensagens de progresso, sucesso e erro com causa; trabalho cancelado antes de começar; caminhos fora da pasta de dados recusados.], [REQ-VID-STATUS-001/002], [Passa],
    [TST-STATUS-06], [Auto (Node)], [Dado um trabalho em fila, Quando se pede outro no mesmo vídeo ou se muda de versão, Então é recusado (409).], [REQ-VID-STATUS-004], [Passa],
    [TST-STATUS-07/08], [Auto (Node)], [Cancelar: estado Cancelado, quota devolvida, resultado tardio ignorado; cancelar antes da cópia não envia o pedido ao worker.], [REQ-VID-STATUS-003], [Passa],
    [TST-QUOTA-01], [Auto (Node)], [Dado um Registado com 5 operações, Quando um trabalho termina com sucesso, Então restam 4 e a nova versão deriva da origem; os temporários são apagados.], [REQ-VID-QUOTA-001, REQ-VID-RESULT-001], [Passa],
    [TST-QUOTA-02], [Auto (Node)], [Dado um trabalho que falha, Quando termina, Então a operação é devolvida, a origem mantém-se e o utilizador recebe a causa.], [REQ-VID-QUOTA-001, REQ-VID-STATUS-002], [Passa],
    [TST-QUOTA-03/04], [Auto (Node)], [Sem operações disponíveis nenhum trabalho é criado; Anónimo e Premium não consomem o contador.], [REQ-VID-QUOTA-002], [Passa],
    [TST-RESULT-01], [Auto (Node)], [Dadas versões V1→V2→V3, Quando se escolhe Reverter, Então a ativa é V2; Reset → V1; sem anterior → erro.], [REQ-VID-RESULT-002], [Passa],
    table.cell(colspan: 5, fill: luma(240))[*UC-VID-001 — Recorte temporal*],
    [TST-TRIM-01], [Auto (FFmpeg)], [Dado um vídeo a 30 fps e $t_"in"$ = 2,000 s, Quando é recortado, Então o primeiro fotograma é o 60 da origem.], [REQ-VID-TRIM-010], [Passa],
    [TST-TRIM-02], [Auto (FFmpeg)], [Dado um vídeo 1280×720 a 30 fps, Quando é recortado, Então mantém resolução e FPS e o desfasamento A/V é ≤ 50 ms.], [REQ-VID-TRIM-007/008], [Passa (0 ms medido)],
    [TST-TRIM-03], [Auto (FFmpeg)], [Dado o modo rápido com $t_"in"$ = 2,5 s, Quando o corte termina, Então começa no keyframe 2,0 s e o primeiro pacote é igual ao da origem.], [REQ-VID-TRIM-003], [Passa],
    [TST-TRIM-04/07], [Auto], [Intervalos com menos de 0,5 s, invertidos ou fora da duração são recusados; modo preciso por omissão.], [REQ-VID-TRIM-004], [Passa],
    [TST-TRIM-05], [Auto (FFmpeg)], [Dado um ficheiro com 60 KB corrompidos, Quando é recortado, Então o trabalho falha com a causa.], [REQ-VID-TRIM-006, REQ-VID-STATUS-002], [Passa],
    [TST-TRIM-06], [Auto (desemp.)], [Dado um vídeo de 101 MB, Quando é recortado em modo rápido, Então termina em menos de 10 s.], [REQ-VID-TRIM-009], [Passa (0,43 s)],
    table.cell(colspan: 5, fill: luma(240))[*UC-VID-002 — Pan & Crop*],
    [TST-CROP-01], [Auto], [Keyframes em 0 s $[0,0,640,360]$ e 4 s $[640,360,640,360]$: a 2 s a moldura é $[320,180,640,360]$.], [REQ-VID-CROP-002], [Passa],
    [TST-CROP-02], [Auto (FFmpeg)], [Resultado 1280×720 com interpolação bilinear e MD5 do áudio igual ao da origem.], [REQ-VID-CROP-008/011, REQ-VID-AUDIO-001], [Passa],
    [TST-CROP-03], [Auto (FFmpeg)], [Moldura 9:16 num vídeo 16:9 → resultado 404×720.], [REQ-VID-CROP-011], [Passa],
    [TST-CROP-04/05], [Auto], [Moldura < 320×240 recusada; Anónimo recusado; 6.º keyframe de um Registado recusado; rácios diferentes recusados.], [REQ-VID-CROP-003/004/005/010], [Passa],
    table.cell(colspan: 5, fill: luma(240))[*UC-VID-003 — Velocidade*],
    [TST-SPD-01], [Auto (FFmpeg)], [Dado um vídeo de 6 s a 2x, Então dura 3 s.], [REQ-VID-SPD-001], [Passa],
    [TST-SPD-02], [Auto (FFmpeg)], [Dado 0.5x, Então a duração duplica, mantém 30 fps e os pares de fotogramas são iguais.], [REQ-VID-SPD-007], [Passa],
    [TST-SPD-03], [Auto (FFmpeg)], [Dado um tom de 440 Hz a 1.5x com correção de tom, Então a frequência dominante está entre 431 e 449 Hz.], [REQ-VID-SPD-005], [Passa (439,8 Hz)],
    [TST-SPD-04], [Auto (FFmpeg)], [Dado o troço 2–4 s a 2x num vídeo de 6 s, Então o resultado dura 5 s.], [REQ-VID-SPD-003], [Passa],
    [TST-SPD-05], [Auto (FFmpeg)], [Dado um tempo máximo excedido, Então o trabalho termina com `timeout`.], [REQ-VID-SPD-006], [Passa],
    [TST-SPD-06/07], [Auto (FFmpeg)], [Remover áudio produz vídeo sem som; falha (simulada) do áudio produz vídeo sem som com aviso.], [REQ-VID-SPD-004/008], [Passa],
    [TST-SPD-09], [Auto (Node)], [Anónimo a 4x recusado; Registado com 200 s a 0.5x recusado (400 s > 300 s).], [REQ-VID-SPD-002/009], [Passa],
    table.cell(colspan: 5, fill: luma(240))[*UC-VID-004 — Legendas e texto*],
    [TST-TXT-01], [Auto (FFmpeg)], [Dado um bloco vermelho de 0,5–1,5 s em modo Hardcode, Então há vermelho a 1,0 s e não a 1,8 s; MD5 do áudio igual.], [REQ-VID-TXT-003, REQ-VID-AUDIO-001], [Passa],
    [TST-TXT-02], [Auto (FFmpeg)], [Modo Soft-sub → resultado com faixa `mov_text`.], [REQ-VID-TXT-004], [Passa],
    [TST-TXT-03], [Auto (FFmpeg)], [Texto "Ação — 漢字" numa fonte sem CJK é desenhado com a fonte de recurso.], [REQ-VID-TXT-005], [Passa],
    [TST-TXT-05], [Auto (Node)], [Anónimo recusado; Soft-sub só Premium; 21.º bloco de Registado recusado; intervalos inválidos recusados; blocos sobrepostos aceites.], [REQ-VID-TXT-004/007/010/011/012], [Passa],
    [TST-TXT-06/07], [Auto (Node)], [SRT e VTT em UTF-8 importados; Latin-1, numeração ou tempos inválidos rejeitados com a causa.], [REQ-VID-TXT-002/009], [Passa],
    [TST-TXT-08], [Auto (desemp.)], [Dado um vídeo 1080p de 60 s com 10 blocos, Quando aplicado Hardcode, Então termina em ≤ 150 s.], [REQ-VID-TXT-006], [Passa (28,8 s)],
    table.cell(colspan: 5, fill: luma(240))[*UC-VID-005 — Filtros de cor*],
    [TST-COL-01], [Auto (FFmpeg)], [Sépia a 100% torna o cinzento quente (R > G > B); a 0% não altera.], [REQ-VID-COL-007/010], [Passa],
    [TST-COL-02], [Auto (FFmpeg)], [Brilho +0,2 aumenta a luminância; MD5 do áudio igual.], [REQ-VID-COL-008, REQ-VID-AUDIO-001], [Passa],
    [TST-COL-03], [Auto (FFmpeg)], [LUT identidade 17³ não altera a cor.], [REQ-VID-COL-002], [Passa],
    [TST-COL-04/06], [Auto], [Grelha 20³, valores fora de [0; 1], entradas em falta e LUT 1D rejeitados.], [REQ-VID-COL-009], [Passa],
    [TST-COL-05/07], [Auto (Node)], [LUT recusado a Registado; Premium importa e o caminho chega ao worker.], [REQ-VID-COL-002], [Passa],
    table.cell(colspan: 5, fill: luma(240))[*Ponta a ponta e interface (manuais, com a stack completa)*],
    [TST-E2E-01], [Manual], [Dado um MP4 de 30 s, Quando um Registado o carrega, Então aparece na lista com duração e resolução; um AVI é rejeitado com mensagem.], [REQ-VID-SUBMIT-001/002], [#preencher[Passa / Falha]],
    [TST-E2E-02], [Manual], [Dado um recorte, Quando é aplicado, Então o estado passa Em fila → A processar (%) → Concluído em tempo real e a resposta chega em < 2 s.], [REQ-VID-STATUS-001, REQ-VID-PERF-001], [#preencher[…]],
    [TST-E2E-03], [Manual], [Dado um Registado com 5 operações, Quando conclui uma operação de vídeo, Então o contador mostra 4; se cancelar, mantém 5.], [REQ-VID-QUOTA-003], [#preencher[…]],
    [TST-E2E-04], [Manual], [Dado um trabalho em curso, Quando o utilizador cancela, Então o estado passa a Cancelado e não é criada versão.], [REQ-VID-STATUS-003], [#preencher[…]],
    [TST-UI-01], [Manual], [Marcadores com resolução de 1 ms, fotograma e duração atualizados, pré-visualização só do segmento.], [REQ-VID-TRIM-001/002/011], [#preencher[…]],
    [TST-UI-02], [Manual], [Moldura arrastável com rácio fixo e mínimo 320×240; adicionar, editar e remover keyframes; animação na pré-visualização.], [REQ-VID-CROP-001/002/003/009], [#preencher[…]],
    [TST-UI-03], [Manual], [Atalhos e controlo contínuo; duração final; aviso fora de 0.5x–2x; pré-visualização à velocidade escolhida.], [REQ-VID-SPD-001/010/011], [#preencher[…]],
    [TST-UI-04], [Manual], [Texto desenhado em tempo real; edição de blocos importados de SRT.], [REQ-VID-TXT-001/008], [#preencher[…]],
    [TST-UI-05], [Manual], [Pré-visualização dos filtros em pausa e em reprodução, medindo ≥ 24 fps num vídeo 1080p (ferramentas de desempenho do browser).], [REQ-VID-COL-001/006], [#preencher[…]],
  ),
)

Os testes automáticos executam-se com `python -m unittest discover -s tests -v` (em `Tools/video`) e `node --test test/*.test.js` (em `projects`); ver Anexo A. Resultado à data: 33 testes do worker e 23 do serviço `projects`, todos a passar.

== Limitações e defeitos conhecidos

- *Pré-visualização de cor aproximada*: feita com filtros CSS; não inclui LUT 3D nem gama (REQ-VID-COL-001 parcialmente cumprido).
- *Upload em memória*: o vídeo atravessa gateway, `projects` e `img_storage` em memória; daí o limite de 500 MB por ficheiro, inferior ao que um Premium de 3600 s em 4K pode precisar.
- *Modo Soft-sub*: posição, cor e fonte dos blocos não são preservadas (dependem do leitor).
- *Corte rápido*: indisponível quando o vídeo excede a resolução do perfil (é feito o corte preciso, com aviso).
- *Uma réplica do worker processa um trabalho de cada vez*; com muitos utilizadores, a fila cresce até se acrescentarem réplicas.
- *Testes ponta a ponta e de interface* por executar no momento desta versão do relatório. #preencher[Atualizar após a execução.]
