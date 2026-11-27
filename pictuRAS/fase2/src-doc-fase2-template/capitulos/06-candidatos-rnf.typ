#import "../template.typ": *

// Capítulo inteiro na horizontal (tabelas largas). Para voltar ao vertical, retirar o #paisagem[ ].
#paisagem[
= Candidatos a Requisitos Não Funcionais

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 5 do _template_.

  *Objetivo do capítulo:* escolher *dois* requisitos não funcionais *distintos* a melhorar nesta fase, a partir dos
  cenários de qualidade mais prioritários do capítulo 5. Cada um é classificado segundo a ISO/IEC 25010 (característica e,
  quando aplicável, subcaracterística) e parte de uma fragilidade concreta da solução de base, com evidência.

  Cada candidato é depois especificado, implementado e avaliado por si, ainda que os dois possam estar relacionados.
  A coluna do cenário liga o candidato ao `QS-nn` do capítulo 5, que é a entrada do Exercício 7 (capítulo 7).
]

#tab([Candidatos a requisitos não funcionais da Fase 2],
  tabela(
    colunas: (1.6cm, 2.6cm, 3cm, 2.4cm, 2.8cm, 2.6cm, 2cm, 3cm, 2.8cm),
    tamanho: 7.5pt,
    [\#], [Característica / subcaracterística (ISO/IEC 25010)], [Fragilidade na base (evidência)], [Origem (padrão global / vídeo / interação)], [Impacto nos stakeholders (pertinência)], [Exigência técnica (complexidade)], [Cenário (`QS-nn`, cap. 5)], [Escala e método de medição (esboço)], [Pré-requisitos / efeitos colaterais],
    [CAND-1], [Eficiência de desempenho: utilização de recursos (memória); comportamento temporal], [Quatro saltos com o vídeo inteiro em memória; OOM com 1 GB (EV-02 a EV-05, EV-16)], [Interação: cadeia de carregamento do padrão global usada pelo vídeo sem adaptação], [O Premium não consegue carregar 1 GB; o OOM derruba o serviço para todos; sem progresso], [Média: _streaming_ em nginx, gateway, `projects` e `img_storage`, com a mesma API], [QS-01], [MB de RAM acima do repouso (cgroup) por tamanho; s ponta a ponta; n.º em simultâneo; MB lidos antes da recusa; progresso sim/não], [Pré-requisito de QS-03; sinergia com segurança; troca RAM por disco],
    [CAND-2], [Eficiência de desempenho: capacidade], [Um _worker_ fixo; pré-visualizações atrás dos processamentos (EV-09, EV-12, EV-13, EV-17)], [Padrão do vídeo (consumidor único, fila partilhada)], [Esperas que crescem com a carga; pré-visualização de minutos; recursos fixos em repouso], [Média: fila nova, _autoscaler_ e correções ao _worker_], [QS-02], [s de expansão e contração; processamentos/min; s de espera da pré-visualização (p95); CPU/RAM em repouso], [Conflito com segurança (`docker.sock`); contenção de CPU (H-02); mais um serviço],
  ),
)

== Quantificação

#orientacao[
  Indiquem a *escala* (o que se mede e em que unidade) e o *método de medição* (cenário, carga, ambiente e instrumento) de
  cada candidato. O objetivo é mostrar que o requisito é mensurável e que sabem como o medir.

  Os valores medidos na base, os valores-alvo e os valores mínimos aceitáveis *só são fixados após a medição inicial
  (_baseline_, capítulo 10)*. Não os inventem: preencham as três últimas linhas da tabela só depois de medir a base,
  indicando a origem de cada valor (e.g., medição, referência externa, necessidade de um _stakeholder_).
]

#tab([Quantificação dos requisitos não funcionais],
  tabela(
    colunas: (4.2cm, 1fr, 1fr),
    [], [CAND-1], [CAND-2],
    [Escala (o que se mede e em que unidade)], [M1 pico de RAM adicional (MB acima do repouso, soma dos 3 serviços Node); M2 tempo ponta a ponta (s, do POST ao 204); M3 carregamentos de 1 GB em simultâneo que terminam com 204 (n.º); M4 _bytes_ lidos antes de recusar um ficheiro acima do limite (MB); M5 progresso visível (sim/não)], [E1 expansão (s até haver mais de um consumidor); E2 contração (s desde a fila esvaziar até ao mínimo); E3 débito (processamentos/min); E4 espera da pré-visualização até começar (s, p95); E5 CPU e RAM dos contentores de vídeo em repouso],
    [Cenário de medição], [M1/M2: 100 MB, 500 MB e 1 GB, serviços reiniciados antes de cada repetição; M3: 1, 2, 4 e 8 em paralelo; M4: 300 MB com o perfil _free_ (limite 100 MB); M5: 500 MB no browser], [20 processamentos injetados de uma vez (vídeo de 60 s, 720p, brilho 1,2); 10 pré-visualizações, uma a cada 5 s; observação 300 s após a fila esvaziar],
    [Carga], [5 repetições por tamanho em M1/M2 (mediana); 1 execução de M3 com 2 GB por serviço], [1 execução do ensaio completo],
    [Ambiente], [Portátil da Tabela 3, Docker nativo, _loopback_, sem _swap_], [Igual],
    [Instrumento], [`medicoes/medir.py` (`upload`, `concorrencia`); memória do cgroup (`memory.peak` − `memory.current`); `curl`; M5 manual], [`medicoes/medir.py elasticidade`; API de gestão do RabbitMQ a cada 1 s; _logs_ dos _workers_; `docker stats`],
    [Valor medido na base], [M1: 898 MB (100 MB), 4 212 MB (500 MB), 1 GB falha por OOM; M2: 3,0 s / 14,2 s / falha; M3: 0; M4: 300 MB; M5: não (2026-11-18, _commit_ `406c8e0`)], [E1: não escala; E2: não aplicável; E3: 0,95 /min; E4: 1 258 s; E5: 1 contentor, 0 % CPU, 473 MiB (mesma data)],
    [Valor-alvo (e origem)], [M1 ≤ 300 MB, sem crescer com o tamanho (exploratória: ≈ 90 MB por salto × 3, EV-18); M2 ≤ base − 30 %; M3 = 4 (4 GB a passar por serviços com 2 GB prova memória independente do tamanho); M4 ≤ limite + 1 MB; M5 sim, ≥ 1 atualização/s. O limite de 1 GB vem de *EV-20*: `docker-compose.yaml:147` — `VIDEO_PREMIUM_MAX_SIZE_MB: 1024`], [E1 ≤ 30 s e E2 ≤ 120 s (ordem de grandeza de um processamento, ≈ 60 s na base); E3 ≥ 3 × base (máximo de 4 réplicas em 4 núcleos físicos); E4 ≤ 5 s (REQ-VID-PREVIEW-005 da PL1-G4, «quase imediata», e TST-PREVIEW-02, 2,2–4,4 s com o _worker_ livre); E5 igual à base],
    [Valor mínimo aceitável (e origem)], [M1 ≤ 1 GB para 1 GB; M2 ≤ base (não piorar); M3 = 2 (o dobro do melhor caso da base); M4 ≤ 2 × limite; M5 sim], [E1 ≤ 60 s; E2 ≤ 300 s; E3 ≥ 2 × base; E4 ≤ 10 s (o dobro do alvo); E5 ≤ base + 1 _worker_],
  ),
)

== Relação entre os dois candidatos

Os dois candidatos são independentes na implementação (serviços diferentes), mas ligados no fluxo: o CAND-1 deixa entrar vídeos grandes, que são precisamente os que mais carregam a `video_queue` do CAND-2. Nenhum é condição do outro. Ambos disputam recursos do anfitrião: o CAND-1 troca memória por disco temporário e o CAND-2 troca espera por CPU, pelo que um pico simultâneo pode degradar os dois. Outros RNF afetados: segurança (melhora com o CAND-1, piora com o `docker.sock` do CAND-2), fiabilidade (melhora com ambos) e manutenibilidade (piora ligeiramente com o CAND-2).

== Evidência exploratória (se existir)

#tab([Evidência exploratória],
  tabela(
    colunas: (4cm, 5cm, 1fr),
    [Descrição], [Localização (_scripts_, dados, resultados)], [Como repetir],
    [*EV-18*: um salto que guarda o ficheiro em _buffer_ (_buffer_ + `FormData` + temporário + _hash_) chega a ≈ 3 062 MB de RSS para 1 000 MB; em _streaming_ fica em ≈ 91 MB], [`medicoes/upload_rss.js`; 100, 500 e 1 000 MB; 2 vCPU, 8 GB, sem Docker, 1 execução por ponto, 2026-11-11], [`node medicoes/upload_rss.js` (Node 22, sem dependências)],
    [*EV-19*: com 4 trabalhos e 1 pré-visualização na fila, a pré-visualização espera 14,7 s; com 2 consumidores na mesma máquina de 2 núcleos espera 14,2 s e cada trabalho demora o dobro], [`medicoes/fila.py`; recodificação de 20 s em 720p com `libx264 -preset veryfast` (opções do _worker_); 2 vCPU, 2026-11-11], [`python3 medicoes/fila.py` (requer `ffmpeg`)],
  ),
)
]
