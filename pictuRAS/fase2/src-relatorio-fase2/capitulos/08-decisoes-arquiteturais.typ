#import "../template.typ": *

= Decisões Arquiteturais

#orientacao[
  *Origem:* Exercício 7, secção 3 do _template_.

  Uma decisão por cenário (`DA-1` para `QS-01`, `DA-2` para `QS-02`). Cada decisão é um pequeno registo, ao estilo ADR: o
  contexto, a tática escolhida, a estrutura ou padrão que a realiza, as alternativas consideradas e a razão da sua
  rejeição, as consequências positivas e negativas, e os elementos arquiteturais afetados.

  Só vale a pena registar uma decisão se havia *alternativas reais* (as táticas do capítulo 7 que não foram escolhidas).
  Justifiquem a escolha pelo cenário e pelas restrições da fase: rejeitem as táticas de classe C, porque a fase é de
  _refactoring_, e avaliem o risco de regressão do âmbito da alteração.

  *Depois de implementada*, completem cada decisão com as referências da implementação (_commits_ ou _pull requests_ no
  repositório entregue) e com os desvios face ao que foi decidido, explicando porquê. A vista «depois» do capítulo 9
  deve corresponder ao que foi efetivamente implementado.
]

== DA-1 — Carregamento em _streaming_ com validação antecipada (cenário QS-01)

#tab([Decisão arquitetural DA-1],
  tabela-campos(
    [Contexto], [Cada salto do carregamento guarda o vídeo inteiro em memória e o limite do perfil só é verificado no fim (EV-02 a EV-05); 1 GB provoca OOM (EV-16). Cenário QS-01. Restrições: _refactoring_; API, mensagens de erro e códigos HTTP iguais.],
    [Tática(s) escolhida(s)], [TAT-01 (_streaming_), TAT-02 (validação antecipada) e TAT-07 (progresso)],
    [Estrutura / padrão que a realiza], [_Pipeline_ de _streams_ na cadeia existente: nginx sem _buffering_ (`proxy_request_buffering off`) → `api_gateway` em _pipe_ depois do _token_ → `projects` com ficheiro temporário (`utils/mediaUpload.js`, `multer.diskStorage` com `limits.fileSize`) → `img_storage` com `s3.upload` _multipart_; `onUploadProgress` no frontend],
    [Alternativas consideradas e razão de rejeição], [TAT-03: muda o fluxo e o contrato da API, obriga a expor o S3 e só valida depois do carregamento · TAT-08: classe C (carregamentos retomáveis são funcionalidade nova) · Aumentar a memória dos serviços: só adia o OOM, a memória continua proporcional ao tamanho],
    [Consequências positivas], [Memória dos processos constante (≈ 190 MB para 1 GB); 4 carregamentos de 1 GB em paralelo; recusa acima do limite com 10,8 MB lidos; um pedido sem _token_ deixa de obrigar a ler o corpo; progresso visível.],
    [Consequências negativas / riscos], [Troca RAM por disco temporário e cache de página; temporários a limpar em caso de erro; o `proxy_read_timeout` de 60 s do nginx passa a ser o limite com muitos carregamentos em simultâneo.],
    [Elementos arquiteturais afetados], [`nginx/nginx.conf`; `apiGateway/routes/projects.js`; `projects/utils/mediaUpload.js` (novo) e `projects/routes/projects.js`; `imageStorageService/route/upload.js` e `services/uploadImage.js`; `frontend/lib/projects.ts` e diálogos _Import_ e criação de projeto],
    [Origem e âmbito do _refactoring_], [Interação (cadeia de carregamento do padrão global aplicada ao vídeo); risco de regressão médio, coberto por testes de limites, _hash_ e temporários (secção 10.5)],
    [Classe (A/B/C)], [A para TAT-01 e TAT-02 (mesmos _endpoints_, mensagens e códigos); B para TAT-07 (a barra de progresso é a alteração visível que concretiza M5)],
    [Implementação (_commits_ / _pull requests_)], [`5b2af25` e `aba322d`, no PR \#1 (`fase2/refatoracao`); _patch_ `entrega-refatoracao/0002-Stream-video-uploads-end-to-end-RNF-01.patch`],
    [Desvios face à decisão], [O _patch_ inicial só ligava a barra de progresso ao diálogo _Import_; a criação de projeto foi acrescentada em `aba322d`, depois do teste manual TM-02.],
  ),
)

== DA-2 — Réplicas elásticas do _worker_ de vídeo e fila de pré-visualização (cenário QS-02)

#tab([Decisão arquitetural DA-2],
  tabela-campos(
    [Contexto], [Um único `video_tool` com `prefetch=1` processa tudo; as pré-visualizações esperam atrás dos processamentos (EV-09, EV-12, EV-13, EV-17). Cenário QS-02. Restrições: _refactoring_; mesmas mensagens e mesmo contrato com o `projects`; reproduzível com Docker Compose.],
    [Tática(s) escolhida(s)], [TAT-05 (_autoscaler_), TAT-06 (fila de pré-visualização) e TAT-09 (_heartbeat_ e SIGTERM sem _ack_)],
    [Estrutura / padrão que a realiza], [Consumidores concorrentes elásticos (ALT-1): serviço `video_autoscaler` que lê a fila na API de gestão do RabbitMQ a cada 5 s e ajusta as réplicas do `video_tool` pela API do Docker; `video_preview_queue` com o serviço `video_preview_tool`],
    [Alternativas consideradas e razão de rejeição], [TAT-04: é escalabilidade, não elasticidade, e não resolve a pré-visualização · TAT-11: migrar o _deploy_ para Kubernetes não cabe na fase e é difícil de reproduzir · TAT-10: aceite, mas não aplicada (ver desvios)],
    [Consequências positivas], [Expansão em 16,5 s e contração em 70,4 s; a pré-visualização deixa de esperar pelos processamentos (p95 de 1 258 s para 30,4 s); débito 1,87 × a base; trabalhos de réplicas removidas voltam à fila.],
    [Consequências negativas / riscos], [O `video_autoscaler` monta `/var/run/docker.sock` (controlo total do Docker do anfitrião); dois serviços novos para manter; réplicas sem quota disputam o CPU com a pré-visualização (H-02).],
    [Elementos arquiteturais afetados], [`rabbitMQ/definitions.json`; `projects/utils/project_msg.js`; `Tools/autoscaler/` (novo); `Tools/video/video.py`; `docker-compose.yaml` (`video_tool`, `video_preview_tool`, `video_autoscaler`, `stop_grace_period: 30s`)],
    [Origem e âmbito do _refactoring_], [Padrão do vídeo, dentro do padrão global; risco de regressão médio, coberto por testes do `projects`, do _autoscaler_ e do _worker_],
    [Classe (A/B/C)], [A: os efeitos e as mensagens não mudam; muda a capacidade e o escalonamento],
    [Implementação (_commits_ / _pull requests_)], [`3b8a8bd`, no PR \#1; _patch_ `entrega-refatoracao/0003-Make-video-processing-elastic-RNF-02.patch`. Regra: expande de imediato até uma réplica por trabalho (`ready` + `unacked`), entre 1 e 4; contrai para 1 após 60 s com a fila vazia],
    [Desvios face à decisão], [O plano previa réplicas com limite de CPU e memória (TAT-10) e o método do E3 falava em «4 réplicas com 1 CPU cada»; o `docker-compose.yaml` final não define `cpus` nem `mem_limit`. O desvio só foi detetado depois da medição final e explica E3 e E4; não foi corrigido para não mudar o método depois de medir. O _autoscaler_ escala só a `video_queue`.],
  ),
)
