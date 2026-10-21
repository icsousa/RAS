#import "../template.typ": *

= Alterações Arquiteturais

Este capítulo descreve apenas o _delta_ face à solução de base (repositório `picturas-27`, _commit_ `781a63e`): uma arquitetura de microserviços com Nginx, API Gateway, serviços Node.js (`users`, `projects`, `subscriptions`), armazenamento S3 (SeaweedFS) atrás do serviço `img_storage`, RabbitMQ e uma ferramenta Python por fila para o processamento de imagem. O suporte a vídeo segue os mesmos padrões e acrescenta um único serviço novo.

== Visão geral das alterações

#figure(
  image("../images/arquitetura_componentes.png", width: 100%),
  caption: [Vista de componentes da solução com suporte a vídeo; novo a laranja, alterado com contorno laranja],
) <fig-componentes>

#tab([Componentes novos e alterados],
  tabela(
    colunas: (3.2cm, 1.6cm, 1fr, 3.4cm),
    tamanho: 8.5pt,
    [Componente / serviço], [Estado], [Responsabilidade / alteração], [Requisitos],
    [`video_tool` (`Tools/video`)], [Novo], [Worker Python + FFmpeg das cinco operações. Consome `video_queue`, publica progresso, sucesso e erros em `video_results_queue`. Controla cancelamento, tempo e memória de cada trabalho e verifica o resultado (sincronismo, propriedades).], [REQ-VID-TRIM-\*, -CROP-\*, -SPD-\*, -TXT-003/005/006, -COL-007..010, -AUDIO-001, -STATUS-005, -SUBMIT-003],
    [`projects`: `routes/videos.js`, `services/videoService.js`], [Novo (no serviço existente)], [API REST de vídeo; submissão com `ffprobe`; criação, preparação, cancelamento e conclusão dos trabalhos; versões (reverter, _reset_); importação de LUT e de legendas; notificações para o WS Gateway.], [REQ-VID-SUBMIT-\*, -STATUS-001..004, -QUOTA-\*, -RESULT-\*, -PERF-001],
    [`projects`: `utils/videoRules.js`], [Novo], [Fonte única das regras por perfil (RNG-01, RNG-04 e RN dos casos de uso) e da validação de parâmetros, LUT `.cube` e ficheiros SRT/VTT. Módulo puro, testado sem dependências.], [REQ-VID-SUBMIT-001/002, -TRIM-004, -CROP-004/005/010, -SPD-002/009, -TXT-002/004/007/009/011/012, -COL-002/009],
    [`projects`: modelos `video`, `video_job`], [Novo], [Coleções MongoDB para vídeos (com versões) e trabalhos de processamento (estado, progresso, quota reservada, erros, avisos).], [REQ-VID-RESULT-001, -STATUS-001],
    [`projects` (imagem Docker, `app.js`, `routes/projects.js`)], [Alterado], [Instala FFmpeg/`ffprobe`; monta o router de vídeo e o consumidor de resultados; ao apagar um projeto apaga também os vídeos.], [REQ-VID-SUBMIT-001],
    [API Gateway (`routes/videos.js`)], [Alterado], [Encaminha as rotas de vídeo, incluindo uploads _multipart_ até 500 MB, depois de validar o JWT.], [REQ-VID-SUBMIT-001],
    [WS Gateway], [Alterado], [Novo evento `video-job` para a sala do utilizador e do projeto.], [REQ-VID-STATUS-001],
    [Nginx], [Alterado], [`client_max_body_size 512m` e tempos maiores em `/api-gateway/` (o limite por omissão era 1 MB).], [REQ-VID-SUBMIT-001],
    [RabbitMQ], [Alterado], [Filas `video_queue` e `video_results_queue` ligadas à _exchange_ `picturas`.], [REQ-VID-STATUS-001],
    [Frontend (`/dashboard/[pid]/videos`)], [Novo], [Página de vídeo: upload, reprodutor com pré-visualização no cliente, painéis das cinco ferramentas, estado do trabalho, versões e histórico; botão "Vídeos" na página do projeto.], [REQ-VID-TRIM-001/002/011, -CROP-001/003/009, -SPD-001/011, -TXT-001/008, -COL-001/006, -QUOTA-003],
    [`users`], [Mantido], [Reutilizados os _endpoints_ existentes de tipo de utilizador, reserva e devolução de operações.], [REQ-VID-QUOTA-001/002],
  ),
)

== Decisões arquiteturais

#tab([Decisões arquiteturais],
  tabela(
    colunas: (1.2cm, 2.8cm, 1fr, 3.4cm, 2.4cm),
    tamanho: 8.5pt,
    [ID], [Decisão], [Contexto e alternativas consideradas], [Consequências], [Requisitos / DQ],
    [DA-01], [Módulo de vídeo dentro do serviço `projects`], [Alternativa: novo microserviço de vídeo. O vídeo pertence a um projeto e precisa da mesma autenticação por partilha, limite de editores e armazenamento; um serviço novo obrigaria a duplicar isso e a alterar gateway, nginx e compose.], [Código isolado em ficheiros próprios; `projects` ganha a dependência do `ffprobe`. Pode ser extraído para um serviço na Fase 2.], [REQ-VID-SUBMIT-\*, REQ-VID-RESULT-\*],
    [DA-02], [Um único worker para as cinco operações], [A _baseline_ usa um serviço por ferramenta. As cinco operações partilham a lógica de FFmpeg, progresso, cancelamento, limites e verificação do resultado; cinco serviços repetiriam tudo isso e cinco imagens com FFmpeg e fontes.], [Uma fila e uma imagem; escala com réplicas (`--scale video_tool=N`). Uma operação lenta pode atrasar as outras numa só réplica.], [DQ-001, DQ-006],
    [DA-03], [Processamento assíncrono com filas dedicadas e progresso por mensagens], [Alternativas: pedido HTTP síncrono (bloqueia a interface e o gateway em operações de minutos) ou o worker escrever diretamente na `ws_queue` (o estado do trabalho deixaria de ter uma fonte única).], [O `projects` é o único que atualiza o estado do trabalho no MongoDB e notifica o browser; a submissão responde de imediato.], [DQ-001; REQ-VID-STATUS-001, REQ-VID-PERF-001],
    [DA-04], [S3 para versões, volume partilhado para o processamento], [O worker precisa de ficheiros locais para o FFmpeg; a _baseline_ já partilha `image_data` entre serviços. Upload direto do browser para o S3 com URL assinado foi considerado, mas exigiria mudar o `img_storage`.], [Cada trabalho tem a sua pasta `/app/images/videos/<job>`, apagada no fim. O upload atravessa o gateway em memória: limite de 500 MB (melhoria para a Fase 2).], [REQ-VID-RESULT-001, REQ-VID-STATUS-002],
    [DA-05], [Cancelamento por ficheiro `CANCEL` na pasta do trabalho], [Alternativas: mensagem de controlo numa fila _fanout_ ou remover a mensagem da fila. O ficheiro funciona com o trabalho em fila ou em execução e não precisa de nova infraestrutura.], [O worker verifica o ficheiro a cada 0,2 s e termina o FFmpeg. Mensagens tardias de um trabalho cancelado são ignoradas.], [REQ-VID-STATUS-003],
    [DA-06], [Quota: reserva ao criar o trabalho e devolução se falhar ou for cancelado], [Alternativa: debitar só no fim, o que exigiria um _endpoint_ novo no `users` e permitiria lançar vários trabalhos com uma só operação disponível. Os _endpoints_ de reserva e devolução já existem na _baseline_.], [Só os trabalhos concluídos contam; o contador desce durante o processamento e é reposto em caso de falha.], [RNG-01; REQ-VID-QUOTA-001/002],
    [DA-07], [Pan & Crop fotograma a fotograma em Python entre dois processos FFmpeg], [O filtro `zoompan` do FFmpeg só aplica zoom uniforme, tem interpolação própria e trepidação conhecida. Em Python (Pillow) a interpolação linear e o redimensionamento bilinear ficam exatamente como especificados.], [Mais lento do que um filtro nativo; o áudio é copiado do ficheiro original.], [DQ-007; REQ-VID-CROP-002/008/011],
    [DA-08], [Limite de memória por medição da memória residente], [A primeira versão usava `RLIMIT_AS`; nos testes o FFmpeg/libx264 bloqueava em vez de terminar quando lhe faltava memória, e o trabalho só acabaria pelo tempo máximo.], [O worker mede o RSS a cada 0,2 s e termina o processo ao exceder o limite (`VIDEO_MEMORY_LIMIT_MB`).], [DQ-006; REQ-VID-STATUS-005],
    [DA-09], [Pré-visualização no cliente com HTML5 e CSS], [Alternativas: _shaders_ WebGL (necessários para pré-visualizar LUT 3D) ou renderização de excertos no servidor (custo por ajuste). Os filtros CSS são acelerados por GPU e cobrem as predefinições e os ajustes manuais.], [Sem pré-visualização de LUT nem de gama; a pré-visualização é uma aproximação do resultado final.], [DQ-002; REQ-VID-COL-001/006],
  ),
)

== Fluxo de processamento de vídeo

#figure(
  image("../images/sequencia_processamento.png", width: 100%),
  caption: [Sequência de processamento de um vídeo entre componentes],
) <fig-sequencia>

O pedido de uma operação chega ao `projects` através do API Gateway, que valida o JWT. O `projects` recusa o pedido se já houver um trabalho ativo no vídeo, valida os parâmetros contra o perfil de quem o pede e, para um utilizador Registado, reserva uma operação no `users`. O trabalho é gravado no estado "Em fila" e a resposta é devolvida de imediato. Em segundo plano, o `projects` copia a versão de origem do S3 para a pasta do trabalho no volume partilhado e publica o pedido em `video_queue`.

O `video_tool` consome um pedido de cada vez, executa o FFmpeg e publica o progresso em `video_results_queue`; o `projects` atualiza o trabalho e reencaminha cada atualização para a `ws_queue`, de onde o WS Gateway a envia ao browser (com consulta periódica como alternativa). No sucesso, o `projects` guarda o resultado no S3 como nova versão ativa, derivada da origem. Em caso de falha, de tempo ou memória excedidos, ou de cancelamento, o trabalho termina com a causa, a operação reservada é devolvida e a versão de origem mantém-se. Em todos os casos a pasta temporária é apagada.

== Impacto na instalação e execução

- *Novo serviço* `video_tool` no `docker-compose.yaml` (imagem `python:3.11-slim` com FFmpeg, libass e fontes Noto/DejaVu/Liberation), ligado ao RabbitMQ e ao volume `image_data`.
- *Serviço* `projects`: a imagem instala FFmpeg (para `ffprobe`); novas variáveis `VIDEO_MAX_UPLOAD_MB` (500) e `VIDEO_SPEED_TIMEOUT_SEC` (120).
- *Worker*: `VIDEO_JOB_TIMEOUT_SEC` (1800), `VIDEO_SPEED_TIMEOUT_SEC` (120), `VIDEO_MEMORY_LIMIT_MB` (3072), `VIDEO_DATA_ROOT` (`/app/images`).
- *RabbitMQ*: filas `video_queue` e `video_results_queue` em `rabbitMQ/definitions.json`.
- *Nginx*: limite de upload de 512 MB em `/api-gateway/`.
- Instruções completas de execução no Anexo A.
