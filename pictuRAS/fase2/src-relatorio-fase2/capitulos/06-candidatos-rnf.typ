#import "../template.typ": *
#paisagem[

= Candidatos a Requisitos Não Funcionais

#tab([Candidatos a requisitos não funcionais da Fase 2],
  tabela(
    colunas: (1.3fr, 2.2fr, 2.8fr, 2fr, 2.6fr, 2.4fr, 1.2fr, 3fr, 2.6fr),
    tamanho: 8pt,
    [\#], [Característica / subcaracterística (ISO/IEC 25010)], [Fragilidade na base (evidência)], [Origem (padrão global / vídeo / interação)], [Impacto nos stakeholders (pertinência)], [Exigência técnica (complexidade)], [Cenário (QS-nn, cap. 5)], [Escala e método de medição (esboço)], [Pré-requisitos / efeitos colaterais],
    [CAND-1 (RNF-01)], [Eficiência de desempenho: utilização de recursos (memória); comportamento temporal], [Quatro saltos com o vídeo inteiro em memória; OOM do anfitrião com 1 GB (EV-02 a EV-05, EV-16)], [Interação: cadeia de carregamento do padrão global usada pelo vídeo sem adaptação], [Premium não consegue carregar 1 GB; o OOM derruba o serviço para todos; sem progresso], [Média: _streaming_ em nginx, gateway, `projects` e `img_storage`, com a mesma API], [QS-01], [MB de RAM acima do repouso (cgroup) por tamanho; s ponta a ponta; n.º de carregamentos em simultâneo; bytes lidos antes da recusa; progresso sim/não], [Pré-requisito de QS-03; sinergia com segurança (QS-04); troca RAM por disco],
    [CAND-2 (RNF-02)], [Eficiência de desempenho: capacidade (escalabilidade, em flexibilidade na edição de 2023)], [Um worker fixo; pré-visualizações atrás dos processamentos (EV-09, EV-12, EV-13, EV-17)], [Padrão do vídeo (consumidor único, fila partilhada)], [Esperas que crescem linearmente com a carga; pré-visualização de minutos; recursos fixos em repouso], [Média: fila nova, _autoscaler_ e correções ao worker], [QS-02], [s de expansão e contração; processamentos/min; s de espera da pré-visualização (p95); CPU/RAM em repouso], [Conflito com segurança (`docker.sock`); contenção de CPU (H-02); mais um serviço a manter],
  ),
)

== Quantificação

*Enunciado do CAND-1.* O carregamento de um vídeo deve usar memória constante, independente do tamanho do ficheiro; o carregamento de um vídeo Premium de 1 GB não pode levar nenhum serviço a ficar sem memória; o utilizador deve ver o progresso do carregamento.

*Enunciado do CAND-2.* O processamento de vídeo deve ajustar automaticamente o número de workers à carga, entre um mínimo e um máximo configuráveis; uma pré-visualização não deve esperar por processamentos completos.

#tab([Quantificação dos requisitos não funcionais],
  tabela(
    colunas: (3.4cm, 1fr, 1fr),
    tamanho: 8.5pt,
    [], [CAND-1], [CAND-2],
    [Escala (o que se mede e em que unidade)], [M1 pico de RAM adicional (MB acima do repouso, soma dos 3 serviços Node); M2 tempo ponta a ponta (s, do POST ao 204); M3 carregamentos de 1 GB em simultâneo que terminam com 204 (n.º); M4 bytes lidos antes de recusar um ficheiro acima do limite (MB); M5 progresso visível (sim/não)], [E1 expansão (s até haver mais de um consumidor); E2 contração (s desde a fila esvaziar até ao mínimo); E3 débito (processamentos/min); E4 espera da pré-visualização até começar (s, p95); E5 CPU e RAM dos contentores de vídeo em repouso],
    [Cenário de medição], [M1/M2: ficheiros de 100 MB, 500 MB e 1 GB, serviços reiniciados antes de cada repetição; M3: 1, 2, 4 e 8 carregamentos em paralelo; M4: 300 MB com o perfil free (limite 100 MB); M5: vídeo de 500 MB no browser], [20 processamentos injetados de uma vez (vídeo de 60 s, 720p, brilho 1,2); 10 pré-visualizações, uma a cada 5 s, durante o ensaio; observação 300 s depois de a fila esvaziar],
    [Carga], [5 repetições por tamanho em M1/M2 (mediana); 1 execução de M3 com 2 GB por serviço (override `docker-compose.medicoes.yaml`)], [1 execução do ensaio completo (E1 a E5)],
    [Ambiente], [Portátil da Tabela 3, Docker nativo, loopback, sem swap], [Igual],
    [Instrumento], [`medicoes/medir.py` (`upload`, `concorrencia`); memória lida do cgroup (`memory.peak` − `memory.current`); `curl`; M5 manual], [`medicoes/medir.py elasticidade`; API de gestão do RabbitMQ a cada 1 s; logs `[video] msg=…` dos workers; `docker stats`],
    [Valor medido na base], [M1: 898 MB (100 MB), 4 212 MB (500 MB), 1 GB falha por OOM; M2: 3,0 s / 14,2 s / falha; M3: 0; M4: 300 MB; M5: não (medição de 2026-11-18, commit `406c8e0`)], [E1: não escala; E2: não aplicável; E3: 0,95 /min; E4: 1 258 s; E5: 1 contentor, 0 % CPU, 473 MiB (mesma data)],
    [Valor-alvo (e origem)], [M1 ≤ 300 MB e sem crescer com o tamanho (exploratória: ≈ 90 MB por salto em streaming × 3, EV-18); M2 ≤ base − 30 %; M3 = 4 (acima do ponto de rutura da base; 4 GB a passar por serviços com 2 GB prova memória independente do tamanho); M4 ≤ limite + 1 MB; M5 sim, ≥ 1 atualização/s], [E1 ≤ 30 s e E2 ≤ 120 s (ordem de grandeza de um processamento, ≈ 60 s na base); E3 ≥ 3 × base (máximo de 4 réplicas em 4 núcleos físicos); E4 ≤ 5 s (REQ-VID-PREVIEW-005 da PL1-G4, «quase imediata», e TST-PREVIEW-02, 2,2–4,4 s com o worker livre); E5 igual à base],
    [Valor mínimo aceitável (e origem)], [M1 ≤ 1 GB para 1 GB (não piorar face a uma cópia); M2 ≤ base (não piorar); M3 = 2 (o dobro do melhor caso da base); M4 ≤ 2 × limite; M5 sim], [E1 ≤ 60 s; E2 ≤ 300 s; E3 ≥ 2 × base; E4 ≤ 10 s (o dobro do alvo); E5 ≤ base + 1 worker],
  ),
)

O limite de 1 GB vem de `VIDEO_PREMIUM_MAX_SIZE_MB: 1024` (*EV-20*: `docker-compose.yaml:147`). M2 e M4 são relativos à base ou ao limite do perfil, para não dependerem do hardware. Os alvos foram fixados antes da medição final e não foram ajustados depois dela.

== Relação entre os dois candidatos

Os dois candidatos são independentes na implementação (serviços diferentes) mas estão ligados no fluxo: o CAND-1 permite que vídeos grandes cheguem ao sistema, e esses vídeos são precisamente os que mais carregam a `video_queue` do CAND-2. Nenhum é condição do outro. Ambos disputam recursos do anfitrião: o CAND-1 troca memória por disco temporário e o CAND-2 troca tempo de espera por CPU, pelo que um pico de carregamentos e de processamentos em simultâneo pode degradar ambos. Outros RNF afetados: segurança (melhora com o CAND-1, piora com o `docker.sock` do CAND-2), fiabilidade (melhora com ambos) e manutenibilidade (piora ligeiramente com o CAND-2).

== Evidência exploratória (se existir)

#tab([Evidência exploratória],
  tabela(
    colunas: (1fr, 4cm, 4.4cm),
    [Descrição], [Localização (scripts, dados, resultados)], [Como repetir],
    [*EV-18*: um salto que bufferiza (buffer + `FormData` + temporário + hash) chega a ≈ 3 062 MB de RSS para 1 000 MB; em streaming fica em ≈ 91 MB e é ≈ 2 × mais rápido (2,1 s contra 4,1 s)], [`medicoes/upload_rss.js`; ficheiros de 100, 500 e 1 000 MB; 2 vCPU, 8 GB, sem Docker, 1 execução por ponto, 2026-11-11], [`node medicoes/upload_rss.js` (Node 22, sem dependências)],
    [*EV-19*: com 4 trabalhos completos e 1 pré-visualização na fila, a pré-visualização espera 14,7 s; com 2 consumidores na mesma máquina de 2 núcleos espera 14,2 s e cada trabalho demora o dobro], [`medicoes/fila.py`; recodificação de 20 s em 720p com `libx264 -preset veryfast` (as opções do worker); 2 vCPU, 2026-11-11], [`python3 medicoes/fila.py` (requer `ffmpeg`)],
  ),
)

]
