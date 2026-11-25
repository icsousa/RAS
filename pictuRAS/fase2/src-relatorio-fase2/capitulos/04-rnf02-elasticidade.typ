#import "../template.typ": *

= RNF-02 — Elasticidade do processamento de vídeo

*Classificação ISO/IEC 25010:* eficiência de desempenho — capacidade (a edição de 2023 também lista a escalabilidade, em flexibilidade).

== Diagnóstico

Na base há um único `video_tool`, com `prefetch_count=1`, a consumir a `video_queue`. As pré-visualizações (3 s de vídeo) e os processamentos completos partilham essa fila, por isso uma pré-visualização espera por todos os vídeos que estão à frente (bloqueio na cabeça da fila). O worker usa `heartbeat=0`, pelo que o broker não deteta um worker pendurado. A secção 4 da análise tem as referências ao código e a medição exploratória (14,7 s de espera da pré-visualização com só 4 trabalhos à frente).

*Impacto para os stakeholders.* Com vários utilizadores a processar vídeo, o tempo de espera cresce linearmente e uma simples pré-visualização pode demorar dezenas de minutos. Em repouso, a capacidade é a mesma que em carga.

== Quantificação

*Enunciado.* O processamento de vídeo deve ajustar automaticamente o número de workers à carga, entre um mínimo e um máximo configuráveis. Uma pré-visualização não deve esperar por processamentos completos.

#tab([RNF-02: métricas, método, alvo e mínimo],
  tabela(
    colunas: (2.6cm, 2.8cm, 1fr, 1.8cm, 2cm),
    [Métrica], [Escala], [Método], [Alvo], [Mínimo],
    [E1 Expansão], [s até haver mais de um consumidor], [20 processamentos injetados de uma vez (vídeo de 60 s 720p, brilho 1,2)], [≤ 30 s], [≤ 60 s],
    [E2 Contração], [s desde a fila esvaziar até ao mínimo], [O mesmo ensaio, observado 300 s], [≤ 120 s], [≤ 300 s],
    [E3 Débito], [Processamentos concluídos por minuto], [20 processamentos], [≥ 3 × base], [≥ 2 × base],
    [E4 Espera da pré-visualização], [s até começar, p95], [10 pré-visualizações, uma a cada 5 s, durante o E3], [≤ 5 s], [≤ 10 s],
    [E5 Recursos em repouso], [CPU e RAM dos contentores de vídeo], [`docker stats` 5 min depois do fim], [Igual à base], [≤ base + 1 worker],
  ),
)

*Origem dos valores.*

- *E4 = 5 s.* O documento de requisitos da PL1-G4 tem o REQ-VID-PREVIEW-005 (eficiência de desempenho, comportamento temporal, prioridade _Should_): a pré-visualização deve ser produzida "num tempo muito inferior ao da edição completa", com a métrica "quase imediata" e a justificação de ficar pronta "em poucos segundos, mesmo para um vídeo longo". O teste TST-PREVIEW-02 desse documento mediu 2,2 a 4,4 s para o excerto de 3 s, com o worker livre. Fixámos 5 s como alvo para que, com a fila cheia, a pré-visualização continue no mesmo patamar que a PL1-G4 aceitou com a fila vazia; o mínimo de 10 s é o dobro.
- E1 e E2: são da ordem de grandeza de um processamento (≈ 60 s por vídeo na base): a capacidade extra deve chegar antes de o primeiro trabalho terminar, e a contração não deve deixar réplicas paradas mais de dois minutos.
- E3 e o máximo de 4 réplicas dependem dos núcleos do portátil (4 núcleos físicos).

== Decisões arquiteturais

#tab([RNF-02: alternativas consideradas],
  tabela(
    colunas: (3cm, 1fr, 1fr),
    [Alternativa], [Vantagens], [Custos e riscos],
    [B1 Réplicas fixas (`deploy.replicas: N`)], [Trivial.], [É escalabilidade, não elasticidade; desperdiça recursos em repouso; não resolve a pré-visualização.],
    [*B2 Autoscaler próprio (escolhida)*], [Elasticidade real, mensurável e reproduzível com Docker Compose.], [Precisa de `docker.sock` montado (Capítulo 5); a regra de escala é código novo de infraestrutura.],
    [B3 Kubernetes com HPA ou KEDA], [Solução padrão da indústria.], [Migrar todo o deploy no tempo da fase não é realista; difícil de reproduzir pelos docentes.],
    [*B4 Separar filas (escolhida)*], [Elimina o bloqueio na cabeça da fila.], [Mais uma fila em `definitions.json`; o `projects` passa a escolher a fila.],
  ),
)

*Decisão:* B2 + B4. *Consequências:* dois serviços novos para manter, acesso ao Docker do anfitrião pelo autoscaler, e o débito máximo passa a depender do CPU disponível para as réplicas.

== Refatoração

#tab([RNF-02: alterações (commit `3b8a8bd`)],
  tabela(
    colunas: (3cm, 1fr),
    [Componente], [Alteração],
    [Filas], [Nova `video_preview_queue` em `rabbitMQ/definitions.json`; o `projects` (`utils/project_msg.js`) publica as pré-visualizações de vídeo nela e os processamentos na `video_queue`.],
    [`video_preview_tool`], [Novo serviço com a mesma imagem do worker, a consumir só a fila de pré-visualizações.],
    [`video_autoscaler`], [Novo serviço (`Tools/autoscaler`). A cada 5 s lê `ready` e `unacked` da `video_queue` na API de gestão do RabbitMQ e cria ou remove réplicas do `video_tool` pela API do Docker. A regra (`scaling_rule.py`, função pura com testes unitários) expande de imediato até uma réplica por trabalho, entre 1 e 4, e contrai para o mínimo só depois de 60 s com a fila completamente vazia, para nunca remover réplicas ocupadas.],
    [Worker (`video.py`)], [Processamento numa thread, com o heartbeat da ligação ativo; ao receber SIGTERM termina sem ack, para a mensagem voltar à fila; `stop_grace_period: 30s`.],
  ),
)

*Desvio face à análise.* A análise previa réplicas "com limite de CPU e memória" e o método de E3 falava em "4 réplicas com 1 CPU cada". O `docker-compose.yaml` final não define `cpus` nem `mem_limit` para o `video_tool`; as réplicas partilham os 8 CPUs do portátil. Isto explica E3 e E4 (abaixo).

== Medição de base e final

#tab([RNF-02: base, final e avaliação],
  tabela(
    colunas: (2cm, 3cm, 3.6cm, 2.4cm, 1fr),
    [Métrica], [Base], [Final], [Alvo / mínimo], [Avaliação],
    [E1], [Não escala (1 worker)], [*16,5 s*], [≤ 30 s / ≤ 60 s], [#ok],
    [E2], [Não aplicável], [*70,4 s*], [≤ 120 s / ≤ 300 s], [#ok],
    [E3], [0,95 /min], [1,78 /min (1,87 ×)], [≥ 2,85 / ≥ 1,90 /min], [#falha],
    [E4 (p95)], [1 258 s], [30,4 s], [≤ 5 s / ≤ 10 s], [#falha (−97,6 %)],
    [E5], [1 contentor, 0 % CPU, 473 MiB], [3 contentores (worker, worker de pré-visualização, autoscaler), 0 % CPU, ≈ 113 MiB], [≤ base + 1 worker], [#okmin],
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
  caption: [E4 final: espera (s) de cada uma das 10 pré-visualizações, pela ordem de chegada (uma a cada 5 s). Verde ≤ 5 s, laranja ≤ 10 s, vermelho acima do mínimo. Fonte: `resultados/final/rnf02_elasticidade.json`.],
) <fig-e4>

== Análise

- *E1 e E2.* O autoscaler criou as 3 réplicas extra em cerca de 3 s, logo na primeira leitura em que viu 19 mensagens prontas; os 16,5 s de E1 incluem o tempo de injetar os trabalhos e de arrancar os contentores. A contração (70,4 s) é dominada pelos 60 s de espera configurados mais o intervalo de leitura de 5 s. Registo em `resultados/final/rnf02_autoscaler.log` e `rnf02_replicas_video_tool.txt`.
- *E3.* Os 20 trabalhos foram processados em lotes de 4 (a fila desce 16 → 12 → 8 → 4 → 0), mas cada vídeo demorou cerca do dobro do que com 1 worker (≈ 125 s por lote de 4, contra ≈ 63 s por vídeo na base). O `libx264` já usa vários núcleos, e 4 réplicas sem limite de CPU disputam os mesmos 8 threads do portátil. O débito subiu 1,87 ×, ligeiramente abaixo do mínimo de 2 ×. A medição exploratória da análise já antecipava este efeito.
- *E4.* A pré-visualização deixou de esperar pelos processamentos (de 21 min para segundos), mas há só um worker de pré-visualização e, com o CPU saturado pelas 4 réplicas, cada pré-visualização demorou ≈ 9 s. Como os pedidos chegam a cada 5 s, a fila de pré-visualizações cresce (@fig-e4). A primeira começou em 0,2 s: o problema é a acumulação na fila de um único worker, não a espera atrás dos processamentos.
- *E5.* Em repouso há mais 2 contentores do que na base, mas a memória total desceu de 473 MiB para ≈ 113 MiB. A diferença deve-se sobretudo a o worker da base ter acabado de processar 30 trabalhos; não deve ser lida como poupança da refatoração.
- *E3 da base recalculado.* O resumo original da base contava também as pré-visualizações (1,38 /min), porque a linha `ok` do worker não indica se é uma pré-visualização. Recalculámos a partir dos eventos gravados, com o mesmo critério da final (prefixo `preview-` no id da mensagem): 20 processamentos em 1 266 s, 0,95 /min (`resultados/base/rnf02_e3_recalculado.json`).

*O que fazer para cumprir E3 e E4* (não aplicado, para não alterar o método depois da medição):

- limitar o CPU de cada réplica (`cpus`), reservando núcleos para o worker de pré-visualização;
- escalar também a `video_preview_queue`, com o mesmo autoscaler;
- medir numa máquina com mais núcleos: o débito máximo está limitado pelo CPU do anfitrião, não pela arquitetura.
