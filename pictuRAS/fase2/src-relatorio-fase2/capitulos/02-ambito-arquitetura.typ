#import "../template.typ": *

= Âmbito e Vista da Arquitetura

== Preparação e ambiente

#tab([Preparação e ambiente],
  tabela-campos(
    [Commit de partida], [`052310226c51fa57a17101c7bd1ad795674aac95` (`picturas-um/picturas-27`); cópia idêntica em `icsousa/RAS`, commit `406c8e0`, pasta `pictuRAS/fase2/picturas-27`],
    [Comando(s) de arranque], [`docker compose down -v --remove-orphans` \ `docker compose up -d --build` (esperar ≈ 2 min até o RabbitMQ e o `projects` ficarem _healthy_)],
    [Ambiente (SO, CPU, RAM, versões de Docker e Compose)], [Portátil ASUS VivoBook X515JA; Intel Core i7-1065G7 (4 núcleos, 8 threads); 12 GB de RAM (11 GiB utilizáveis), *sem swap*; Manjaro Linux, kernel 7.2.9; Docker Engine 29.8.2 nativo (cgroup v2), Docker Compose 5.6.0. Registo completo em `medicoes/resultados/base/ambiente.txt`],
    [Ajustes necessários], [Nenhum para arrancar. Durante as medições observámos que o nginx resolve o nome `api_gateway` só no arranque: quando o gateway reinicia e muda de IP, o nginx responde 502 até ser reiniciado (EV-22). Os scripts passaram a reiniciar também o nginx (commit `45e4c87`).],
  ),
)

*Como é orquestrado o processamento em lote de imagens e de vídeos.* Quando o utilizador carrega em _Apply_, o `projects` copia os originais do S3 para o volume partilhado `image_data` e cria um registo `Process` por ficheiro antes de publicar qualquer mensagem, para que o lote fique completo. O tipo de media decide o caminho: o `projects` reconhece um vídeo pela extensão ou pelo tipo MIME (`isVideoMedia`). Uma *imagem* recebe uma mensagem só com o primeiro efeito, na fila dessa ferramenta; cada worker de imagem devolve o resultado na `project_queue` e é o `projects` que publica o passo seguinte, até ao último efeito. Um *vídeo* recebe uma única mensagem na `video_queue` com o pipeline inteiro; o `video_tool` aplica todos os efeitos com o `ffmpeg`, envia o progresso diretamente para a `ws_queue` e responde uma só vez na `project_queue`. Em ambos os casos, o `projects` guarda o resultado no armazenamento e avisa o cliente pela `ws_queue` e pelo `ws_gateway`.

== Fontes consultadas

#tab([Fontes consultadas],
  tabela(
    colunas: (5.4cm, 3.6cm, 1fr),
    [Fonte], [Versão / data], [Usada para],
    [`README.md`, `AGENTS.md` da base], [commit `0523102`], [Arranque, serviços e convenções; identificação dos serviços e das filas],
    [Código da base (`projects`, `apiGateway`, `imageStorageService`, `Tools/video`, `Tools/utils`, `wsGateway`, `nginx`, `docker-compose.yaml`, `rabbitMQ/definitions.json`)], [commit `0523102` (= `406c8e0`)], [Evidências EV-01 a EV-15 sobre o fluxo, as filas e os padrões],
    [`doc-ext-requisitos-2627.pdf`], [Fase 1, Grupo 4, 2026-10-23], [Requisito REQ-VID-PREVIEW-005 e teste TST-PREVIEW-02 (origem do alvo de QS-02); limites dos perfis],
    [`doc-sol-arquitetural.pdf`], [Versão disponibilizada pela equipa docente], [Consulta de enquadramento sobre o padrão global; as afirmações sobre o sistema atual apoiam-se no código e na execução (EV-nn), porque a base PL1-G4 alterou a solução original],
    [Slides da aula 11 (_Arch. Styles_) e documento de apoio de padrões arquiteturais], [#preencher[versão / data]], [Identificação dos estilos (microserviços, mensagens, consumidores concorrentes, pipes and filters) e das alternativas],
    [`fase-2-guidelines.pdf`], [Versão 1], [Ciclo do trabalho e ideias indicativas de RNF],
    [Medições exploratórias (`medicoes/upload_rss.js`, `medicoes/fila.py`)], [2026-11-11], [Evidência exploratória EV-18 e EV-19 (secção 6.3)],
    [Medições oficiais (`medicoes/resultados/base` e `final`)], [2026-11-18], [Baseline e resultados (EV-16, EV-17 e capítulo 10)],
  ),
)

== Vista da arquitetura global

#figure(
  image("../images/arquitetura_global.png", width: 100%),
  caption: [Vista da arquitetura global com o caminho do vídeo destacado],
) <fig-global>

Ferramenta / notação: Graphviz (`dot`), diagrama de contentores ao estilo C4, construído a partir do `docker-compose.yaml` e confirmado com a stack em execução (`docker compose ps`, filas na consola do RabbitMQ). Fonte em `diagramas/arquitetura_global.dot`.

#tab([Legenda da vista da arquitetura],
  tabela(
    colunas: (5.4cm, 1fr),
    [Elemento (cor, forma ou estilo)], [Significado],
    [Setas e contornos laranja, grossos], [Caminho do vídeo: carregamento até ao S3 e processamento pelo `video_tool`],
    [Caixa arredondada branca], [Serviço (contentor) da solução],
    [Retângulo bege dentro de «RabbitMQ»], [Fila do exchange `picturas`],
    [Cilindro], [Armazenamento persistente (SeaweedFS/S3, MongoDB)],
    [Pasta], [Volume Docker partilhado `image_data`],
    [Linha tracejada sem seta], [Montagem do volume partilhado],
    [Linha pontilhada sem seta], [Base de dados própria de cada serviço],
    [Moldura tracejada], [Serviços que comunicam por HTTP síncrono],
  ),
)

== Sequência de um pedido completo

As evidências seguem o formato *EV-nn: localização — o que mostra*. Os caminhos são relativos a `pictuRAS/fase2/picturas-27/` no commit de partida.

#figure(
  sequencia(
    ([Frontend], [nginx + api_gateway], [projects], [img_storage + S3], [RabbitMQ], [video_tool], [ws_gateway]),
    (
      (0, 1, [POST /api-gateway/projects/:u/:p/video (multipart)]),
      (1, 2, [POST /projects/:u/:p/video (FormData com o buffer)]),
      (2, 2, [ffprobe + limites do perfil]),
      (2, 3, [POST /upload (buffer) → SeaweedFS]),
      (2, 0, [201: vídeo adicionado ao projeto], true),
      (0, 2, [POST …/tool (efeito e parâmetros, via gateway)]),
      (0, 2, [POST …/process (Apply, via gateway)]),
      (3, 2, [original copiado para o volume image_data]),
      (2, 4, [publish video_queue {procedure: video, tools[ ], preview: false}]),
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
  ),
  caption: [Sequência do processamento em lote de um projeto com vídeos],
) <fig-seq>

Notação: diagrama de sequência desenhado em Typst (`template.typ`, função `sequencia`). A laranja, as interações exclusivas do caminho do vídeo; a tracejado, respostas e eventos para o cliente.

#tab([Passos do pedido completo],
  tabela(
    colunas: (2.4cm, 3.2cm, 3.6cm, 1fr),
    [Passo], [Origem → Destino], [Mensagem / endpoint / fila], [Evidência],
    [Carregamento do vídeo (1–5)], [Frontend → nginx → api_gateway → projects → img_storage → SeaweedFS], [`POST /projects/:u/:p/video` (multipart), reenviado como `FormData`; `POST /upload`], [*EV-01*: `frontend/lib/projects.ts:466-479` — vídeos enviados para o endpoint `/video` com `api.post`, sem `onUploadProgress`. \ *EV-02*: `nginx/nginx.conf:13,33-35` — `client_max_body_size 1100m`; `/api-gateway/` sem `proxy_request_buffering off`, logo o pedido é guardado inteiro antes de seguir. \ *EV-03*: `apiGateway/routes/projects.js:23,458-475` — `multer.memoryStorage()`; `upload.single("video")` corre *antes* de `auth.checkToken`; reenvio com `req.file.buffer`. \ *EV-04*: `projects/routes/projects.js:1391-1393` e `projects/utils/video.js:84` — `memoryStorage`; `probeVideoBuffer` escreve o buffer num temporário para o `ffprobe`; validação só depois de o ficheiro estar todo em memória. \ *EV-05*: `imageStorageService/route/upload.js:6-10` e `services/uploadImage.js:15-20` — `memoryStorage` e `s3.upload({Body: file.buffer})`.],
    [Definição do pipeline (6)], [Frontend → api_gateway → projects], [`POST /projects/:u/:p/tool`], [*EV-06*: `projects/routes/projects.js:1397` — cada efeito é guardado em `project.tools` (MongoDB do `projects`).],
    [Apply (7–10)], [Frontend → projects → RabbitMQ], [`POST /projects/:u/:p/process`; mensagem na `video_queue` (vídeo) ou na fila do primeiro efeito (imagem)], [*EV-07*: `projects/routes/projects.js:1521-1660` — copia os originais do S3 para `image_data`, regista o lote inteiro e só depois publica; um vídeo recebe `tool_name = "video"` com `tools: videoPipeline(...)` numa só mensagem, uma imagem recebe só `imageTools(project)[0]`. \ *EV-08*: `projects/utils/project_msg.js:3-24` — uma fila por ferramenta de imagem, mais `video_queue`, `project_queue` e `ws_queue`.],
    [Progresso (11–15)], [video_tool → RabbitMQ → ws_gateway → Frontend], [`ws_queue` (`update-client-video-progress-…`); evento Socket.IO `video-progress`], [*EV-09*: `Tools/video/video.py:1-10,53-54,63,112-124,170` — o worker recebe o pipeline numa mensagem, consome com `prefetch_count=1`, liga com `heartbeat=0`, envia o progresso diretamente para a `ws_queue` e faz ack só no fim. \ *EV-14*: `wsGateway/index.js:55-100` — consome a `ws_queue` e emite para a sala do utilizador.],
    [Resultado (16–22)], [video_tool → RabbitMQ → projects → img_storage; projects → ws_gateway → Frontend], [`project_queue`; `POST` para o stage `out`; `ws_queue` (`success`); `GET …/process/url`], [*EV-11*: `projects/routes/projects.js:168-530` (`process_msg`) — para um vídeo, `chainEnd` é verdadeiro e a resposta é a última; para uma imagem, o `projects` cria o `Process` seguinte e publica o efeito seguinte. Guarda o resultado (linha 381) e notifica o cliente.],
  ),
)
