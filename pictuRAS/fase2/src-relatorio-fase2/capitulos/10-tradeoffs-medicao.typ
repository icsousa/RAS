#import "../template.typ": *

= Trade-offs, Medição e Preservação Funcional

== Matriz de efeitos

#tab([Matriz de efeitos das decisões],
  tabela(
    colunas: (1.2cm, 1.7cm, 1.9cm, 1.6cm, 1.6cm, 1.9cm, 1fr),
    tamanho: 8.5pt,
    [Decisão], [Desempenho], [Disponibilidade / Fiabilidade], [Segurança], [Usabilidade], [Manutenibilidade / Testabilidade], [Justificação],
    [DA-1], [↑ memória; = tempo; ↓ disco], [↑], [↑], [↑], [\= / ↑], [Memória constante e 1 GB deixa de provocar OOM (fiabilidade ↑); token antes do corpo e recusa pelo `Content-Length` (segurança ↑); barra de progresso (usabilidade ↑). Custo: disco temporário e cache de página (≈ 1 GB por carregamento de 1 GB em curso); o tempo fica ao nível da base em loopback. `mediaUpload.js` concentra a lógica e tem testes (testabilidade ↑). Gestão do custo: temporários apagados no fim e em erro; medir o pico de disco é trabalho futuro.],
    [DA-2], [↑ capacidade e espera; ↓ CPU disponível], [↑], [↓], [↑], [↓ / ↑], [Elasticidade e fim do bloqueio na cabeça da fila; heartbeat e SIGTERM sem ack (fiabilidade ↑); pré-visualização mais rápida (usabilidade ↑). Custos: `docker.sock` montado no _autoscaler_ (segurança ↓); mais dois serviços e uma fila (manutenibilidade ↓), mas a regra de escala é uma função pura com testes (testabilidade ↑). Gestão: o _autoscaler_ só cria/remove réplicas do `video_tool`; um proxy do socket com as operações necessárias fica como trabalho futuro.],
  ),
)

== Interação entre DA-1 e DA-2

#tab([Interação entre as decisões],
  tabela(
    colunas: (1.6cm, 1.6cm, 3cm, 1fr),
    [Decisão A], [Decisão B], [Efeito (pré-requisito, sinergia ou conflito)], [Razão / evidência],
    [DA-1], [DA-2], [Sinergia no fluxo, conflito nos recursos do anfitrião], [A DA-1 permite que vídeos grandes entrem no sistema, e a DA-2 dá-lhes capacidade de processamento; sem a DA-1 a DA-2 nunca receberia vídeos de 1 GB. Ambas usam o mesmo anfitrião: a DA-1 consome disco e I/O no `projects`, a DA-2 consome CPU com as réplicas. As medições foram feitas em separado (secção 10.3), pelo que o efeito combinado num pico simultâneo não foi medido.],
  ),
)

== Plano de medição

#tab([Plano de medição],
  tabela(
    colunas: (1.4cm, 3.6cm, 2.6cm, 3cm, 2.4cm, 1fr),
    tamanho: 8.5pt,
    [Cenário], [Cenário de teste e carga], [Ambiente (máquina, recursos, versões)], [O que se regista], [Repetições e agregação], [Onde ficam os scripts e os dados],
    [QS-01], [M1/M2: vídeos de 100 MB, 500 MB e 1 GB por `curl` em loopback, serviços reiniciados antes de cada repetição; M3: 1, 2, 4 e 8 em paralelo com 2 GB por serviço; M4: 300 MB com o perfil free; M5: 500 MB no browser], [Portátil da Tabela 3, mesmo dia (2026-11-18) para base e final, sem outras aplicações pesadas], [`memory.peak` − `memory.current` do cgroup de cada contentor; tempo até ao 204; códigos HTTP; bytes enviados até à recusa; progresso visível], [5 repetições, mediana (M1, M2, M4); 1 execução (M3, M5)], [`medicoes/medir.py` (`upload`, `concorrencia`), `medicoes/docker-compose.medicoes.yaml`; dados em `medicoes/resultados/base/` e `final/` (`rnf01_*.json`)],
    [QS-02], [20 processamentos de um vídeo de 60 s 720p injetados de uma vez; 10 pré-visualizações, uma a cada 5 s; observação 300 s após a fila esvaziar], [Igual], [Profundidade das filas e consumidores (API de gestão, 1 s); eventos `[video] msg=…` dos workers; decisões do _autoscaler_; `docker stats` em repouso], [1 execução; E4 em percentil 95], [`medicoes/medir.py elasticidade`; dados em `resultados/*/rnf02_elasticidade.json`, `rnf02_linha_tempo.csv`, `final/rnf02_autoscaler.log`],
  ),
)

== Resultados das medições

#tab([Resultados das medições],
  tabela(
    colunas: (1.3cm, 3.4cm, 2.3cm, 2.4cm, 1.9cm, 1.7cm, 1fr),
    tamanho: 8.5pt,
    [Cenário], [Medição (o que se mede, unidade)], [Antes (baseline)], [Depois], [Valor-alvo], [Mínimo aceitável], [Atingido?],
    [QS-01], [M1 RAM adicional, 100 MB (MB)], [898], [408], [≤ 300, sem crescer], [≤ 1 GB p/ 1 GB], [ver M1 1 GB],
    [QS-01], [M1 RAM adicional, 500 MB (MB)], [4 212], [1 050], [idem], [idem], [ver M1 1 GB],
    [QS-01], [M1 RAM adicional, 1 GB — `memory.peak` (MB)], [0/5 com sucesso; ≈ 8 GB até ao OOM], [2 253 (5/5)], [≤ 300], [≤ 1 024], [Não (inclui cache de página)],
    [QS-01], [M1 memória dos processos (`anon`), 1 GB (MB)], [—], [≈ 190], [≤ 300], [≤ 1 024], [#ok],
    [QS-01], [M2 tempo ponta a ponta, 100 MB (s)], [3,0], [3,4], [≤ base − 30 %], [≤ base], [#falha (+12 %)],
    [QS-01], [M2 tempo ponta a ponta, 500 MB (s)], [14,2], [13,5], [idem], [idem], [#okmin (−5 %)],
    [QS-01], [M2 tempo ponta a ponta, 1 GB (s)], [falha (502/504)], [25,5], [—], [—], [passa a funcionar],
    [QS-01], [M3 carregamentos de 1 GB em simultâneo (n.º)], [0], [4], [4], [2], [#ok],
    [QS-01], [M4 bytes lidos antes da recusa (MB)], [300 (400 ao fim de 5,1 s)], [10,8 (400 ao fim de 0,09 s)], [≤ 101], [≤ 200], [#ok],
    [QS-01], [M5 progresso visível], [Não (só _spinner_)], [Sim (percentagem)], [Sim, ≥ 1/s], [Sim], [#ok (atualizações/s não medidas)],
    [QS-02], [E1 expansão (s)], [Não escala], [16,5], [≤ 30], [≤ 60], [#ok],
    [QS-02], [E2 contração (s)], [Não aplicável], [70,4], [≤ 120], [≤ 300], [#ok],
    [QS-02], [E3 débito (processamentos/min)], [0,95], [1,78 (1,87 ×)], [≥ 2,85], [≥ 1,90], [#falha],
    [QS-02], [E4 espera da pré-visualização, p95 (s)], [1 258], [30,4], [≤ 5], [≤ 10], [#falha (−97,6 %)],
    [QS-02], [E5 recursos em repouso], [1 contentor, 0 % CPU, 473 MiB], [3 contentores, 0 % CPU, ≈ 113 MiB], [Igual à base], [≤ base + 1 worker], [#okmin],
  ),
)

#let esperas = (0.2, 1.5, 5.6, 8.5, 11.3, 13.8, 17.7, 22.4, 26.3, 30.4)
#figure(
  {
    set text(size: 8pt)
    let h-max = 3.2cm
    let escala = h-max / 32
    box(width: 100%, stack(
      dir: ttb,
      spacing: 4pt,
      grid(
        columns: (1fr,) * esperas.len(),
        column-gutter: 6pt,
        align: center + bottom,
        ..esperas.map(e => stack(
          spacing: 2pt,
          text(size: 7.5pt)[#str(e).replace(".", ",")],
          rect(width: 70%, height: e * escala, fill: if e <= 5 { rgb("#2E7D32") } else if e <= 10 { rgb("#C76C1B") } else { rgb("#B00020") }),
        )),
      ),
      line(length: 100%, stroke: 0.5pt),
      grid(columns: (1fr,) * esperas.len(), column-gutter: 6pt, align: center, ..range(1, 11).map(i => [#i])),
    ))
  },
  caption: [E4 depois da refatoração: espera (s) de cada uma das 10 pré-visualizações, pela ordem de chegada (uma a cada 5 s). Verde ≤ 5 s, laranja ≤ 10 s, vermelho acima do mínimo. Fonte: `resultados/final/rnf02_elasticidade.json`],
) <fig-e4>

*Análise dos resultados (por requisito não funcional).*

*CAND-1 (QS-01).*

- *Base, 1 GB.* As 5 repetições falharam (4 × 502, 1 × 504) por OOM global do anfitrião (EV-16). A memória extra cresce ≈ 8,5 vezes o tamanho do ficheiro (gateway 3,9 GB, `projects` 2,3 GB e `img_storage` 2,0 GB para 1 GB). É exatamente a fragilidade que motivou o QS-01.
- *M1 e cache de página.* O gateway ficou constante (45–68 MB). No `projects` e no `img_storage` o `memory.peak` ainda cresce ≈ 1,1 GB por GB de ficheiro, mas não é memória dos processos: é a cache de página do ficheiro temporário, que o cgroup contabiliza e o kernel pode libertar. Numa medição complementar (`resultados/final/rnf01_m1_anon.json`) separámos `anon` de `file` no `memory.stat`: para 1 GB, `anon` subiu 25 MB no gateway, 40 MB no `projects` e 125 MB no `img_storage` (≈ 190 MB), e `file` ≈ 1 GB em cada um dos dois últimos. A M3 confirma que esta cache não impede o funcionamento. Pela métrica original (`memory.peak`) o alvo não é atingido; pela memória dos processos, é.
- *M2.* Em loopback não há rede lenta a esconder, e o _streaming_ acrescenta escrita e leitura em disco no `projects`. O tempo fica ao nível da base e não atinge a redução de 30 %; a melhoria real de M2 é que 1 GB passa a terminar. A exploratória (EV-18) previa um ganho por salto que, ponta a ponta, o disco anula.
- *M3 com 8 em paralelo.* Os 8 carregamentos devolveram 504 ao fim de ≈ 137 s, *sem* OOM. O nginx regista `upstream timed out … while reading response header`: o `proxy_read_timeout` por omissão (60 s) passa a ser o limite, não a memória. Confirma o efeito previsto na matriz de efeitos (custo noutro ponto do comportamento temporal).
- *M4.* O `projects` recusa pelo `Content-Length` antes de ler o ficheiro: o `curl` só chegou a enviar 10,8 MB que já estavam em trânsito.

*CAND-2 (QS-02).*

- *E1 e E2.* O _autoscaler_ criou as 3 réplicas extra ≈ 3 s depois de ver 19 mensagens prontas; os 16,5 s incluem injetar os trabalhos e arrancar os contentores. A contração (70,4 s) é dominada pelos 60 s de espera configurados mais o intervalo de leitura de 5 s (`final/rnf02_autoscaler.log`, `rnf02_replicas_video_tool.txt`).
- *E3.* Os 20 trabalhos foram processados em lotes de 4 (fila 16 → 12 → 8 → 4 → 0), mas cada vídeo demorou cerca do dobro (≈ 125 s por lote de 4, contra ≈ 63 s por vídeo na base). O `libx264` já usa vários núcleos e 4 réplicas sem quota disputam os 8 threads: confirma a H-02. O débito subiu 1,87 ×, ligeiramente abaixo do mínimo de 2 ×.
- *E4.* A pré-visualização deixou de esperar pelos processamentos (de 21 min para segundos): a primeira começou em 0,2 s. Mas há um só worker de pré-visualização e, com o CPU saturado pelas réplicas, cada pré-visualização demorou ≈ 9 s; como os pedidos chegam a cada 5 s, a fila de pré-visualizações cresce (@fig-e4). O problema passou a ser a acumulação na fila de um único worker.
- *E5.* Em repouso há mais 2 contentores do que na base, mas a memória total desceu de 473 MiB para ≈ 113 MiB, sobretudo porque o worker da base tinha acabado de processar 30 trabalhos; não deve ser lida como poupança da refatoração.
- *Para cumprir E3 e E4* (não aplicado, para não alterar o método depois de medir): quota de CPU por réplica com núcleos reservados à pré-visualização (TAT-10); escalar também a `video_preview_queue`; medir numa máquina com mais núcleos.

*Efeitos noutros atributos.* Confirmam a matriz de efeitos: menos memória à custa de disco (DA-1), limite de concorrência deslocado para o _timeout_ do nginx (DA-1), contenção de CPU entre réplicas e pré-visualização (DA-2). Encontrámos também uma fragilidade *pré-existente* não corrigida: o nginx resolve o nome do gateway só no arranque (EV-22, QS-03).

*Ameaças à validade.*

- Um único portátil, sem swap; os valores absolutos dependem deste hardware.
- 5 repetições por tamanho em M1/M2, mas uma única execução de M3 e da elasticidade.
- A M1 por `memory.peak` inclui a cache de página; a medição da memória dos processos é complementar e teve uma só repetição.
- A M5 foi avaliada qualitativamente; não medimos as atualizações por segundo.
- Correções aos scripts durante as medições, todas em commits próprios e aplicadas por igual à base e à final: `45e4c87` (reiniciar também o nginx, por causa da EV-22), `78843bd` (gravar M1/M2 antes da M4 e reiniciar os serviços, porque o OOM da base perdia resultados) e `6e553e9` (recolher os logs das réplicas durante o ensaio, brilho diferente em cada pré-visualização para não acertar na cache, identificar pré-visualizações pelo id da mensagem, E2 «não aplicável» sem mudanças de workers). A primeira medição final da elasticidade foi descartada e repetida; na base nenhuma pré-visualização acertou na cache, pelo que só o E3 foi recalculado a partir dos dados brutos, contando apenas processamentos completos (0,95 /min em vez de 1,38 /min; `base/rnf02_e3_recalculado.json`).

== Preservação funcional

#tab([Preservação funcional e testes de regressão],
  tabela(
    colunas: (2.6cm, 3.2cm, 2.6cm, 3.4cm, 1fr),
    tamanho: 8.5pt,
    [Zona alterada], [Testes de regressão existentes (`Tools/video/tests`, `projects/tests`, …)], [Lacunas de teste], [Testes acrescentados], [Resultado (imagem e vídeo)],
    [DA-1: carregamento (gateway, `projects`, `img_storage`, frontend)], [`projects/tests` (processamento em lote, pipeline de vídeo, extração de fotogramas)], [Não havia testes de carregamento, de limites de perfil nem do hash], [9 testes em `projects/tests/rnf01-upload.test.js`: limites do perfil e mensagem de recusa iguais aos da base, recusa pelo tamanho declarado, `ffprobe` e `og_sha256` iguais aos calculados sobre o buffer, envio em _stream_, ficheiro temporário removido, leitura interrompida ao passar o limite; testes manuais TM-01, TM-02, TM-08], [`docker compose exec projects node --test`: 20 pass, 0 fail; TM-01, TM-08 passam; TM-02 passa depois de `aba322d`],
    [DA-2: filas, worker e _autoscaler_], [`Tools/video/tests` (efeitos, legendas, extração de fotogramas)], [Sem testes da escolha de fila, do comportamento do worker ao terminar, nem de escala], [3 testes em `projects/tests/rnf02-queues.test.js` (pré-visualização na fila nova); 8 testes da regra de escala (`Tools/autoscaler/tests`); 5 testes do worker (`test_worker_rnf02.py`: heartbeat, SIGTERM sem ack); TM-03, TM-06, TM-07], [`pytest -q Tools/video/tests`: 79 passed, 1 aviso; `unittest` do _autoscaler_: 8 OK; TM-03, TM-06, TM-07 passam],
    [Imagens (não alteradas, mas partilham o `projects`)], [`projects/tests`], [—], [TM-04 (brilho, rotação e _border_ em imagens) e TM-05 (partilha _View only_)], [Passam],
  ),
)

#tab([Riscos para a preservação funcional e mitigação],
  tabela(
    colunas: (1fr, 2.4cm, 1fr, 3.4cm),
    tamanho: 8.5pt,
    [Risco], [Funcionalidade afetada (imagem / vídeo)], [Mitigação], [Teste de regressão],
    [Mudança das mensagens de erro ou dos códigos HTTP ao recusar um carregamento], [Vídeo e imagem (carregamento)], [Mensagens e códigos copiados da base; recusa no mesmo serviço (`projects`)], [`rnf01-upload.test.js`; TM-08 (`too_long_90s.mp4`, `corrupted.mp4`)],
    [Hash diferente ao calcular em _stream_, quebrando a deteção de duplicados e a cache], [Vídeo], [Hash incremental sobre o mesmo conteúdo], [`rnf01-upload.test.js` (hash igual ao do buffer)],
    [Ficheiros temporários deixados em disco após erro ou aborto], [Vídeo], [Limpeza no fim e nos caminhos de erro], [`rnf01-upload.test.js` (ficheiro temporário removido)],
    [Pré-visualização perdida ou duplicada na fila nova], [Vídeo], [Mesmo formato de mensagem; só muda o nome da fila], [`rnf02-queues.test.js`; TM-03, TM-06],
    [Trabalho perdido quando o _autoscaler_ remove uma réplica a meio], [Vídeo], [Contração só com a fila vazia há 60 s; SIGTERM sem ack; `stop_grace_period: 30s`], [`test_worker_rnf02.py`; testes da regra de escala],
    [Regressão nas imagens por alterações no `projects`], [Imagem], [Alterações limitadas ao caminho do vídeo e à escolha da fila], [`projects/tests`; TM-04, TM-05],
  ),
)

As medições funcionam também como teste de regressão ponta a ponta: 30 processamentos e pré-visualizações e 15 carregamentos terminaram com sucesso na versão final.
