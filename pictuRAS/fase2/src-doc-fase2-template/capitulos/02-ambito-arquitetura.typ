#import "../template.typ": *

= Âmbito e Vista da Arquitetura

#orientacao[
  *Origem:* Exercício 6, Bloco 1, secções 0 e 1 do _template_ (preparação, fontes, vista global e sequência).

  *Objetivo do capítulo:* situar o leitor. Mostra como a solução foi lançada, em que fontes se baseia a análise e como é
  a arquitetura da solução de base, com o caminho do vídeo em destaque. É a base factual dos capítulos seguintes.

  *Foco:* a *extensão de vídeo, enquadrada no padrão global* da solução. Não analisem o vídeo isoladamente: o que o vídeo
  faz só se percebe à luz do que a solução faz como um todo.

  *Rigor:* cada afirmação sobre o sistema atual cita uma evidência (`EV-nn`) ou é assumida como hipótese (`H-nn`). A
  secção 2.4 explica como se escreve uma evidência.
]

== Preparação e ambiente

#orientacao[
  Registem como a solução foi lançada, para que outra pessoa a consiga repetir e obtenha o mesmo resultado. Indiquem
  sempre o _commit_ de partida (o mesmo em todos os capítulos), os comandos exatos e o ambiente de execução. Se algum
  passo falhou ou exigiu um ajuste, escrevam-no: é informação útil para quem repetir o processo.

  A descrição do processamento em lote que se segue à tabela deve ser escrita pela equipa, com palavras próprias, e
  mostrar que perceberam o fluxo completo, do _Apply_ ao resultado, para imagens e vídeos.
]

#tab([Preparação e ambiente],
  tabela-campos(
    [Commit de partida], [`052310226c51fa57a17101c7bd1ad795674aac95` (`picturas-um/picturas-27`); cópia idêntica em `icsousa/RAS`, _commit_ `406c8e0`, pasta `pictuRAS/fase2/picturas-27`],
    [Comando(s) de arranque], [`docker compose down -v --remove-orphans` e `docker compose up -d --build` (esperar ≈ 2 min até o RabbitMQ e o `projects` ficarem _healthy_). Ajuste: durante as medições, depois de reiniciar o `api_gateway`, foi preciso reiniciar também o nginx, que guarda o IP antigo do gateway e responde 502 (ver QS-03)],
    [Ambiente (SO, CPU, RAM, versões de Docker e Compose)], [Portátil ASUS VivoBook X515JA; Intel Core i7-1065G7 (4 núcleos, 8 _threads_); 12 GB de RAM (11 GiB utilizáveis), sem _swap_; Manjaro Linux, _kernel_ 7.2.9; Docker Engine 29.8.2 nativo (cgroup v2); Docker Compose 5.6.0. Registo em `medicoes/resultados/base/ambiente.txt`],
  ),
)

*Como é orquestrado o processamento em lote de imagens e de vídeos* (5 a 8 linhas):

Quando o utilizador carrega em _Apply_, o `projects` copia os originais do S3 para o volume partilhado `image_data` e regista um `Process` por ficheiro antes de publicar qualquer mensagem, para que o lote fique completo. O tipo de _media_ é decidido pela extensão ou pelo tipo MIME (`isVideoMedia`). Uma *imagem* recebe uma mensagem só com o primeiro efeito, na fila dessa ferramenta; cada _worker_ de imagem responde na `project_queue` e é o `projects` que publica o efeito seguinte, até ao último. Um *vídeo* recebe uma única mensagem na `video_queue` com o _pipeline_ inteiro; o `video_tool` aplica todos os efeitos com o `ffmpeg`, envia o progresso diretamente para a `ws_queue` e responde uma só vez na `project_queue`. Nos dois casos, o `projects` guarda o resultado no armazenamento e avisa o cliente pela `ws_queue` e pelo `ws_gateway`.

== Fontes consultadas

#orientacao[
  Listem os documentos e o código que sustentam a análise, com a versão ou a data de cada um (_commit_, número de versão,
  data de acesso) e para que foram usados. Isto permite ao leitor perceber de onde vêm as afirmações e detetar
  fontes desatualizadas. Incluam os documentos de apoio da unidade curricular que influenciaram a análise.
]

#tab([Fontes consultadas],
  tabela(
    colunas: (5.5cm, 3cm, 1fr),
    [Fonte], [Versão / data], [Usada para],
    [`README.md`, `AGENTS.md`], [_commit_ `0523102`], [Arranque, serviços e filas; comportamento da legendagem e da extração de fotogramas],
    [`doc-ext-requisitos-2627.pdf`], [Fase 1, Grupo 4 (2026-10-23)], [Limites dos perfis; REQ-VID-PREVIEW-005 e TST-PREVIEW-02, origem do alvo do CAND-2],
    [`doc-sol-arquitetural.pdf`], [Versão disponibilizada pela equipa docente], [Enquadramento do padrão global; as afirmações sobre o sistema atual apoiam-se no código e na execução (`EV-nn`)],
    [Slides da aula 11 (_Arch. Styles_) e documento de apoio de padrões arquiteturais], [Documento de apoio do Exercício 6 (`RAS_support_doc_architectural_patterns_PT.html`); #preencher[data dos slides]], [Identificação dos estilos (microserviços, mensagens, consumidores concorrentes, _pipes and filters_) e escolha das alternativas],
    [Código da base (`projects`, `apiGateway`, `imageStorageService`, `Tools/video`, `Tools/utils`, `wsGateway`, `nginx`, `docker-compose.yaml`, `rabbitMQ/definitions.json`)], [_commit_ `0523102` (= `406c8e0`)], [Evidências `EV-01` a `EV-15`],
    [Enunciados dos Exercícios 6 (Bloco 1, v1.1) e 7 (_template_ v3.0) e diretrizes da Fase 2 (versão 1)], [2026-11-04 a 2026-11-17], [Estrutura do diagnóstico, dos cenários, das táticas e das decisões],
    [Medições do grupo (`medicoes/`)], [2026-11-11 (exploratórias) e 2026-11-18 (oficiais)], [Evidências `EV-16` a `EV-19` e capítulo 10],
  ),
)

== Vista da arquitetura global

#orientacao[
  A vista mostra o *padrão global* da solução (serviços, filas, armazenamento, fronteiras) com o *caminho do vídeo
  destacado*, de modo a que se veja onde o vídeo segue o resto do sistema e onde se afasta dele.

  Usem a notação e a ferramenta que preferirem (C4 de contentores, componentes UML, PlantUML, Mermaid, draw.io), mas
  incluam sempre uma *legenda* e indiquem a ferramenta. O diagrama tem de ser legível no documento impresso e
  consistente com o que foi observado na solução em execução, não apenas com a documentação.
]

#figure(kind: image,
  image("../images/arquitetura_global.png", width: 100%),
  caption: [Vista da arquitetura global com o caminho do vídeo destacado],
)

*Ferramenta / notação:* PlantUML, diagrama de componentes ao estilo C4 de contentores (fonte em `diagramas/arquitetura_global.puml`), construído a partir do `docker-compose.yaml` e confirmado com a solução em execução (`docker compose ps`, filas na consola do RabbitMQ).

#tab([Legenda da vista da arquitetura],
  tabela(
    colunas: (5cm, 1fr),
    [Elemento (cor, forma ou estilo)], [Significado],
    [Setas laranja, grossas; `video_tool` a laranja], [Caminho do vídeo (carregamento e processamento)],
    [Setas cinzentas], [Padrão global e caminho das imagens],
    [Linha tracejada azul; pasta azul], [Acesso ao volume partilhado `image_data`],
    [Fila (cilindro horizontal) dentro do pacote amarelo], [Fila do _exchange_ `picturas` do RabbitMQ],
    [Base de dados (cilindro vertical)], [MongoDB de cada serviço e SeaweedFS (S3)],
    [Pacote tracejado], [Agrupamento lógico de serviços (entrada, acesso, negócio, _workers_)],
  ),
)

== Sequência de um pedido completo

#orientacao[
  Descrevam, passo a passo, o que acontece num pedido completo para um projeto com vídeos: carregamento → definição do
  _pipeline_ → _Apply_ → progresso → resultado. O diagrama de sequência mostra a ordem das interações; a tabela
  identifica, para cada passo, quem fala com quem e através de que mensagem, _endpoint_ ou fila.

  *O que é uma evidência (`EV-nn`).* Uma evidência é a referência *verificável* que sustenta uma afirmação sobre o
  sistema atual. Deve permitir que outra pessoa, no _commit_ de partida, confirme o que afirmam sem ter de adivinhar.
  Pode ser:
  - *código*, com ficheiro e linhas (e.g., `video.py:8-9`);
  - *configuração*, com ficheiro e linha (e.g., `docker-compose.yml`, definição de uma fila ou de um volume);
  - *mensagem* observada (e.g., conteúdo de uma mensagem na fila, resposta de um _endpoint_);
  - *medição* ou *registo de execução*, com o comando usado e o resultado;
  - *documento*, com a secção (e.g., `doc-sol-arquitetural.pdf`, secção 3).

  Regras: o ID é sequencial (`EV-01`, `EV-02`, …), único, e nunca se reutiliza. Como o relatório não tem um registo
  separado, *descrevam a evidência no sítio onde a usam pela primeira vez* (formato: `EV-nn`: localização — o que
  mostra); nas ocorrências seguintes basta o ID. Uma afirmação sem evidência não é um facto: marquem-na como
  *hipótese* (`H-nn`) e indiquem como a confirmar ou refutar.
]

#figure(kind: image,
  image("../images/sequencia_pedido.png", width: 100%),
  caption: [Sequência do processamento em lote de um projeto com vídeos],
)

#tab([Passos do pedido completo],
  tabela(
    colunas: (3cm, 3.6cm, 1fr, 3.4cm),
    [Passo], [Origem → Destino], [Mensagem / _endpoint_ / fila], [Evidência],
    [Carregamento do vídeo (1–5)], [Frontend → nginx → `api_gateway` → `projects` → `img_storage` → SeaweedFS], [`POST /projects/:u/:p/video` (_multipart_), reenviado como `FormData` com o _buffer_; `POST /upload` ao `img_storage`; resposta 201], [*EV-01*: `frontend/lib/projects.ts:466-479` — vídeo enviado para `/video` sem `onUploadProgress`. *EV-02*: `nginx/nginx.conf:13,33-35` — `client_max_body_size 1100m`, sem `proxy_request_buffering off`. *EV-03*: `apiGateway/routes/projects.js:23,458-475` — `memoryStorage`; `upload.single("video")` antes de `auth.checkToken`. *EV-04*: `projects/routes/projects.js:1391-1393`, `projects/utils/video.js:84` — `memoryStorage`; `ffprobe` e limites só com o ficheiro todo em memória. *EV-05*: `imageStorageService/route/upload.js:6-10`, `services/uploadImage.js:15-20` — `memoryStorage` e `s3.upload({Body: file.buffer})`],
    [Definição do _pipeline_ (6)], [Frontend → `api_gateway` → `projects`], [`POST /projects/:u/:p/tool`], [*EV-06*: `projects/routes/projects.js:1397` — cada efeito é guardado em `project.tools`],
    [_Apply_ (7–10)], [Frontend → `projects` → RabbitMQ], [`POST /projects/:u/:p/process`; uma mensagem na `video_queue` por vídeo (imagens: fila do primeiro efeito)], [*EV-07*: `projects/routes/projects.js:1521-1660` — copia os originais para `image_data`, regista o lote e publica; vídeo com `tool_name = "video"` e o _pipeline_ inteiro. *EV-08*: `projects/utils/project_msg.js:3-24` — uma fila por ferramenta, mais `video_queue`, `project_queue` e `ws_queue`],
    [Progresso (11–15)], [`video_tool` → RabbitMQ → `ws_gateway` → Frontend], [`ws_queue` (`update-client-video-progress-…`); evento Socket.IO `video-progress`], [*EV-09*: `Tools/video/video.py:1-10,53-54,63,112-124,170` — _pipeline_ numa mensagem, `prefetch_count=1`, `heartbeat=0`, progresso direto para a `ws_queue`, _ack_ só no fim. *EV-14*: `wsGateway/index.js:55-100` — consome a `ws_queue` e emite para o utilizador],
    [Resultado (16–22)], [`video_tool` → RabbitMQ → `projects` → `img_storage`; `projects` → `ws_gateway` → Frontend], [`project_queue`; `POST` ao _stage_ `out`; `ws_queue` (`success`); `GET …/process/url`], [*EV-11*: `projects/routes/projects.js:168-530` (`process_msg`) — para um vídeo a resposta é a última da cadeia; para uma imagem publica o efeito seguinte],
  ),
)
