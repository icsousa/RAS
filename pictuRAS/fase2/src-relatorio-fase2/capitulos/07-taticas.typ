#import "../template.typ": *
#paisagem[

= Cenários de Entrada e Táticas Candidatas

== Candidatos e cenários de entrada

#tab([Candidatos e cenários de entrada],
  tabela(
    colunas: (1.4fr, 1.2fr, 2.4fr, 1.8fr, 2fr, 3fr, 3.4fr, 3fr),
    tamanho: 8.5pt,
    [Candidato], [Cenário (QS-nn)], [Característica / subcaracterística (ISO/IEC 25010)], [Evidência], [Origem (padrão global / vídeo / interação)], [Estímulo a que a tática reage], [Resposta e medida (resumo)], [Escala e método (cap. 6)],
    [CAND-1], [QS-01], [Eficiência de desempenho: utilização de recursos; comportamento temporal], [EV-02 a EV-05, EV-16], [Interação], [Carregamento de vídeos até 1 GB, em simultâneo, ou acima do limite do perfil], [Memória constante e independente do tamanho; recusa antes de ler; progresso visível — M1 a M5], [MB (cgroup), s, n.º, MB lidos, sim/não; `medir.py upload` e `concorrencia`; 5 repetições],
    [CAND-2], [QS-02], [Eficiência de desempenho: capacidade], [EV-09, EV-12, EV-13, EV-17], [Padrão do vídeo], [Rajada de 20 processamentos com pré-visualizações a meio], [Réplicas sobem e descem sozinhas; pré-visualização não espera — E1 a E5], [s, /min, s p95, CPU/RAM; `medir.py elasticidade`; 1 execução],
  ),
)

== Alterações feitas ao capítulo 5 (se existirem)

#tab([Alterações aos cenários],
  tabela(
    colunas: (2cm, 1fr, 3.4cm),
    [Cenário], [O que mudou e porquê], [Onde foi atualizado],
    [QS-01, QS-02], [Nenhuma alteração à medida da resposta. Registam-se apenas duas precisões de método, aplicadas por igual à base e à final: na M1 separa-se, de forma complementar, a memória dos processos (`anon`) da cache de página (`file`); no E3 contam-se só os processamentos completos, sem pré-visualizações (secção 10.4).], [Secções 6.1 e 10.4],
  ),
)

== Táticas candidatas

Classes: *A* = refactoring puro; *B* = alteração visível que é o objeto da melhoria; *C* = funcionalidade nova, a rejeitar nesta fase.

#tab([Táticas candidatas],
  tabela(
    colunas: (1.4cm, 1.3cm, 2.8cm, 3cm, 1fr, 3.2cm, 1.2cm),
    tamanho: 8pt,
    [ID], [Cenário], [Atributo → categoria], [Tática], [Como produz a resposta (estímulo → tática → resposta)], [Já existe na base? (evidência)], [Classe (A/B/C)],
    [TAT-01], [QS-01], [Desempenho → gerir recursos], [_Streaming_ em todos os saltos (processar em blocos de tamanho fixo)], [Vídeo de 1 GB → cada salto passa blocos ao seguinte, sem guardar o ficheiro em memória (disco temporário onde é preciso o ficheiro inteiro, para o `ffprobe`) → memória constante, independente do tamanho], [Não — `memoryStorage` em três serviços e buffer no nginx (EV-02 a EV-05)], [A],
    [TAT-02], [QS-01], [Desempenho → controlar a procura (limitar eventos)], [Validação antecipada: token antes do corpo e recusa pelo `Content-Length` contra o limite do perfil], [Ficheiro acima do limite ou sem token → recusa antes de ler o corpo → bytes lidos ≈ 0, mesmos códigos HTTP], [Parcial — o nginx recusa acima de 1 100 MB, mas o limite do perfil só é verificado com o ficheiro em memória (EV-02, EV-04)], [A],
    [TAT-03], [QS-01], [Desempenho → gerir recursos (remover intermediários)], [Carregamento direto para o S3 com URL pré-assinado (multipart)], [Carregamento → o browser envia as partes ao SeaweedFS → o backend não toca no ficheiro], [Não], [B (muda o fluxo e o contrato da API)],
    [TAT-04], [QS-01], [Desempenho → gerir recursos (aumentar recursos)], [Mais memória por serviço ou swap no anfitrião], [Carregamento → mais RAM disponível → adia o OOM, mas a memória continua a crescer com o tamanho e a concorrência], [Parcial — sem limites, os serviços usam toda a RAM do anfitrião (EV-12)], [A],
    [TAT-05], [QS-01], [Usabilidade → suporte à iniciativa do utilizador (feedback)], [Barra de progresso do carregamento (`onUploadProgress`)], [Carregamento longo → o browser mostra a percentagem enviada → o utilizador sabe que avança], [Não — só um _spinner_ (EV-01)], [B],
    [TAT-06], [QS-01], [Disponibilidade → recuperar de falhas], [Carregamento retomável por partes (estilo tus)], [Ligação interrompida → retoma a partir da última parte → memória limitada ao tamanho da parte], [Não], [C (retomar carregamentos é funcionalidade nova)],
    [TAT-07], [QS-02], [Desempenho → gerir recursos (manter várias cópias das computações)], [Réplicas fixas do `video_tool` (`deploy.replicas: N`)], [Rajada → N consumidores dividem a fila → mais débito; capacidade fixa em repouso], [Parcial — o worker está preparado («parallelism comes from replicas»), mas há 1 réplica (EV-09, EV-12)], [A],
    [TAT-08], [QS-02], [Desempenho → gerir recursos (escalar dinamicamente)], [_Autoscaler_ pela profundidade da `video_queue`, entre 1 e 4 réplicas], [Fila cresce → o _autoscaler_ cria réplicas pela API do Docker; fila vazia durante 60 s → volta a 1 → elasticidade], [Não], [A],
    [TAT-09], [QS-02], [Desempenho → gerir recursos (escalonamento / prioridade)], [Separar a fila de pré-visualizações, com worker dedicado], [Pedido de pré-visualização → vai para a `video_preview_queue` → não espera pelos processamentos completos], [Não — fila única (EV-13)], [A],
    [TAT-10], [QS-02], [Desempenho → gerir recursos (limitar / atribuir recursos)], [Quota de CPU por réplica (`cpus`) e núcleos reservados à pré-visualização], [Várias réplicas → cada uma com CPU próprio → o débito cresce com as réplicas sem roubar CPU à pré-visualização], [Não — sem `cpus` nem `mem_limit` (EV-12)], [A],
    [TAT-11], [QS-02], [Disponibilidade → detetar e recuperar de falhas], [Heartbeat ativo (processamento numa thread) e SIGTERM sem ack], [Réplica removida ou pendurada → a mensagem volta à fila → nenhum trabalho perdido ao contrair], [Parcial — ack no fim, mas `heartbeat=0` e sem tratamento de SIGTERM (EV-09)], [A],
    [TAT-12], [QS-02], [Desempenho → gerir recursos (escalar dinamicamente)], [Kubernetes com HPA ou KEDA (ALT-3)], [Fila cresce → a plataforma cria _pods_/_jobs_ com quota → elasticidade com isolamento], [Não], [A (mas muda a plataforma de deploy)],
  ),
)

]
