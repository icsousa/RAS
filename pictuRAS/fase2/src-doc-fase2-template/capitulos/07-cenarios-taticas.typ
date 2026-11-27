#import "../template.typ": *

// Capítulo inteiro na horizontal (tabelas largas). Para voltar ao vertical, retirar o #paisagem[ ].
#paisagem[
= Cenários de Entrada e Táticas Candidatas

#orientacao[
  *Origem:* Exercício 7, secções 1 e 2 do _template_.

  *Objetivo do capítulo:* partir dos dois cenários já caracterizados e identificar as táticas arquiteturais que os podem
  melhorar. Os cenários vêm do capítulo 5 e os candidatos do capítulo 6 (`QS-nn`, `CAND-n`) e *não são reescritos*: o
  capítulo 5 é o único sítio onde os cenários se caracterizam. Se tiverem de corrigir uma medida da resposta, corrijam-na
  no capítulo 5 e registem a alteração na secção 7.2.

  Nas tabelas seguintes, `QS-01` e `QS-02` designam os cenários de `CAND-1` e `CAND-2`: substituam-nos pelos IDs reais.
]

== Candidatos e cenários de entrada

#tab([Candidatos e cenários de entrada],
  tabela(
    colunas: (1.8cm, 2.2cm, 3cm, 1.8cm, 2.8cm, 3cm, 3.4cm, 3.4cm),
    tamanho: 8pt,
    [Candidato], [Cenário (`QS-nn`)], [Característica / subcaracterística (ISO/IEC 25010)], [Evidência], [Origem (padrão global / vídeo / interação)], [Estímulo a que a tática reage], [Resposta e medida (resumo)], [Escala e método (cap. 6)],
    [CAND-1], [QS-01], [Eficiência de desempenho: utilização de recursos; comportamento temporal], [EV-02 a EV-05, EV-16], [Interação], [Carregamento de vídeos até 1 GB, em simultâneo, ou acima do limite do perfil], [Memória constante e independente do tamanho; recusa antes de ler; progresso visível (M1 a M5)], [MB (cgroup), s, n.º, MB lidos, sim/não; `medir.py upload` e `concorrencia`; 5 repetições],
    [CAND-2], [QS-02], [Eficiência de desempenho: capacidade], [EV-09, EV-12, EV-13, EV-17], [Padrão do vídeo], [Rajada de 20 processamentos com pré-visualizações a meio], [Réplicas sobem e descem sozinhas; a pré-visualização não espera (E1 a E5)], [s, /min, s p95, CPU/RAM; `medir.py elasticidade`; 1 execução],
  ),
)

== Alterações feitas ao capítulo 5 (se existirem)

#tab([Alterações aos cenários],
  tabela(
    colunas: (2cm, 1fr, 4cm),
    [Cenário], [O que mudou e porquê], [Onde foi atualizado],
    [QS-01, QS-02], [Nenhuma alteração à medida da resposta. Duas precisões de método, aplicadas por igual à base e à final: na M1 separa-se, de forma complementar, a memória dos processos (`anon`) da cache de página (`file`); no E3 contam-se só os processamentos completos, sem pré-visualizações.], [Secções 6.1 e 10.4],
  ),
)

== Táticas candidatas

#orientacao[
  Identifiquem *pelo menos três táticas por cenário*, de categorias de atributo adequadas (e.g., Desempenho → gerir
  recursos; Disponibilidade → recuperar de falhas). Para cada tática, expliquem como produz a resposta pretendida
  (estímulo → tática → resposta) e se já existe, total ou parcialmente, na base (com evidência).

  Classifiquem cada tática: *A* = _refactoring_ puro; *B* = alteração visível que é o objeto da melhoria; *C* =
  funcionalidade nova, a *rejeitar* nesta fase. Táticas de classe C podem constar da lista, mas não podem ser escolhidas.
]

#tab([Táticas candidatas],
  tabela(
    colunas: (1.6cm, 1.8cm, 3.6cm, 3.4cm, 5cm, 3.4cm, 1.8cm),
    tamanho: 8pt,
    [ID], [Cenário], [Atributo → categoria], [Tática], [Como produz a resposta (estímulo → tática → resposta)], [Já existe na base? (evidência)], [Classe (A/B/C)],
    [TAT-01], [QS-01], [Desempenho → gerir recursos], [_Streaming_ em todos os saltos (blocos de tamanho fixo)], [Vídeo de 1 GB → cada salto passa blocos ao seguinte, com disco temporário só onde é preciso o ficheiro inteiro (`ffprobe`) → memória constante], [Não — `memoryStorage` em três serviços e _buffer_ no nginx (EV-02 a EV-05)], [A],
    [TAT-02], [QS-01], [Desempenho → controlar a procura], [Validação antecipada: _token_ antes do corpo e recusa pelo `Content-Length`], [Ficheiro acima do limite ou sem _token_ → recusa antes de ler o corpo → _bytes_ lidos ≈ 0, mesmos códigos HTTP], [Parcial — o nginx recusa acima de 1 100 MB, mas o limite do perfil só é verificado com o ficheiro em memória (EV-02, EV-04)], [A],
    [TAT-03], [QS-01], [Desempenho → gerir recursos (remover intermediários)], [Carregamento direto para o S3 com URL pré-assinado], [Carregamento → o browser envia as partes ao SeaweedFS → o _backend_ não toca no ficheiro], [Não], [B (muda o fluxo e o contrato da API)],
    [TAT-04], [QS-02], [Desempenho → gerir recursos (várias cópias das computações)], [Réplicas fixas do `video_tool`], [Rajada → N consumidores dividem a fila → mais débito, mas capacidade fixa em repouso], [Parcial — o _worker_ está preparado para réplicas, mas há uma (EV-09, EV-12)], [A],
    [TAT-05], [QS-02], [Desempenho → gerir recursos (escalar dinamicamente)], [_Autoscaler_ pela profundidade da `video_queue`, entre 1 e 4 réplicas], [Fila cresce → cria réplicas pela API do Docker; fila vazia 60 s → volta a 1 → elasticidade], [Não], [A],
    [TAT-06], [QS-02], [Desempenho → gerir recursos (escalonamento / prioridade)], [Fila própria para pré-visualizações, com _worker_ dedicado], [Pedido de pré-visualização → `video_preview_queue` → não espera pelos processamentos], [Não — fila única (EV-13)], [A],
    [TAT-07], [QS-01], [Usabilidade → suporte à iniciativa do utilizador (_feedback_)], [Barra de progresso do carregamento (`onUploadProgress`)], [Carregamento longo → o browser mostra a percentagem → o utilizador sabe que avança], [Não — só um _spinner_ (EV-01)], [B],
    [TAT-08], [QS-01], [Disponibilidade → recuperar de falhas], [Carregamento retomável por partes (estilo _tus_)], [Ligação interrompida → retoma na última parte → memória limitada à parte], [Não], [C (retomar carregamentos é funcionalidade nova)],
    [TAT-09], [QS-02], [Disponibilidade → detetar e recuperar de falhas], [_Heartbeat_ ativo e SIGTERM sem _ack_], [Réplica removida ou pendurada → a mensagem volta à fila → nenhum trabalho perdido ao contrair], [Parcial — _ack_ no fim, mas `heartbeat=0` (EV-09)], [A],
    [TAT-10], [QS-02], [Desempenho → gerir recursos (limitar recursos)], [Quota de CPU por réplica e núcleos reservados à pré-visualização], [Várias réplicas → cada uma com CPU próprio → o débito cresce com as réplicas], [Não — sem `cpus` nem `mem_limit` (EV-12)], [A],
    [TAT-11], [QS-02], [Desempenho → gerir recursos (escalar dinamicamente)], [Kubernetes com HPA ou KEDA], [Fila cresce → a plataforma cria _pods_ com quota → elasticidade com isolamento], [Não], [A (mas muda a plataforma de _deploy_)],
  ),
)
]
