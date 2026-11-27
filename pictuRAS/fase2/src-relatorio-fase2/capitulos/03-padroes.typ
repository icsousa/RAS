#import "../template.typ": *

= Padrões Arquiteturais Atuais

== Padrão global da solução

#tabela-campos(
  [Nome(s) do padrão / estilo], [Microserviços com comunicação orientada a mensagens (_message broker_ RabbitMQ), _API Gateway_ e orquestração centralizada no `projects`],
  [Descrição], [Cada capacidade é um serviço num contentor próprio, com base de dados própria quando tem estado. O cliente fala só com o nginx e o `api_gateway` (HTTP síncrono). O trabalho pesado é assíncrono: o `projects` orquestra o pipeline e publica pedidos em filas, workers sem estado consomem-nos e respondem numa fila de resultados; o `ws_gateway` empurra os eventos para o browser.],
)

#tab([Decisões globais que condicionam o vídeo],
  tabela(
    colunas: (4.6cm, 3.6cm, 1fr),
    [Decisão global], [Evidência], [Efeito no vídeo],
    [Comunicação assíncrona por filas, com uma fila e um worker por ferramenta], [EV-08], [O vídeo herda a fila e o worker dedicados (`video_queue`, `video_tool`); a capacidade depende do número de consumidores dessa fila.],
    [Orquestração centralizada no `projects` (_process manager_ que encadeia os passos)], [EV-07, EV-11], [O `projects` decide o tipo de media e o que publicar; é também o ponto por onde passa o carregamento.],
    [Ficheiros trocados por um volume Docker partilhado (`image_data`)], [*EV-12*: `docker-compose.yaml:150-151,256-273` — `image_data:/app/images` montado no `projects`, nas ferramentas e no `video_tool`; um único `video_tool`, sem `deploy.replicas` nem limites de CPU/memória], [Os vídeos não viajam nas mensagens, só os caminhos; mas o `projects` e os workers têm de estar no mesmo anfitrião (H-01).],
    [Carregamento através de cadeia síncrona nginx → gateway → projects → img_storage], [EV-02 a EV-05], [Um ficheiro de 1 GB atravessa quatro saltos; cada um guarda-o inteiro antes de o passar (fragilidade de QS-01).],
    [Base de dados por serviço e armazenamento de objetos S3], [*EV-15*: `docker-compose.yaml:112-197` — um MongoDB por serviço (`projects`, `users`, `subscriptions`); SeaweedFS para os ficheiros], [O vídeo é guardado no S3 e copiado para o volume antes de cada processamento.],
  ),
)

#tab([Benefícios e desafios do padrão global],
  tabela(
    colunas: (1.8cm, 1fr, 3.6cm, 2.2cm),
    [Tipo], [Descrição], [Característica / subcaracterística (ISO/IEC 25010)], [Facto / hipótese],
    [Benefício], [Cada ferramenta pode ser alterada, reconstruída e reiniciada sem tocar nas outras.], [Manutenibilidade: modularidade, modificabilidade], [EV-08, EV-12],
    [Benefício], [O cliente não espera pelo processamento: o `POST /process` responde 201 e o resultado chega por WebSocket.], [Eficiência de desempenho: comportamento temporal], [EV-07, EV-14],
    [Benefício], [As filas absorvem picos: os pedidos acumulam-se em vez de serem recusados; vários consumidores de uma fila dividem o trabalho.], [Eficiência de desempenho: capacidade], [EV-08],
    [Desafio], [Os workers de imagem fazem ack na receção: se um worker morrer a meio, a mensagem perde-se.], [Fiabilidade: tolerância a falhas], [*EV-10*: `Tools/utils/rabbit_mq.py:37-40` — `auto_ack=True`; H-03],
    [Desafio], [O volume partilhado acopla os serviços ao mesmo anfitrião.], [Flexibilidade: escalabilidade], [EV-12; H-01],
    [Desafio], [Os saltos síncronos do carregamento somam memória e latência.], [Eficiência de desempenho: utilização de recursos], [EV-02 a EV-05, EV-16],
  ),
)

== Padrão do processamento de vídeo

#tabela-campos(
  [Nome do padrão], [Worker de lote dedicado com consumidores concorrentes (_competing consumers_) numa fila de trabalho, com o pipeline executado internamente como _pipes and filters_ (filtros do `ffmpeg`)],
  [Descrição], [Uma mensagem na `video_queue` transporta o vídeo e o pipeline inteiro. O `video_tool` aplica todos os efeitos de uma vez, envia o progresso em percentagem e responde uma vez. O padrão prevê várias réplicas a consumir a mesma fila («parallelism comes from replicas»), mas a base só tem uma, com `prefetch_count=1`.],
  [Contraste com o caminho de imagens], [Nas imagens, cada efeito é uma mensagem e é o `projects` que encadeia os passos (EV-11); no vídeo, o encadeamento passa para dentro do worker. As imagens fazem ack na receção (EV-10), o vídeo só no fim (EV-09). O vídeo envia progresso diretamente para a `ws_queue`, sem passar pelo `projects`. As pré-visualizações de vídeo usam a mesma `video_queue` que os processamentos completos (*EV-13*: `projects/routes/projects.js:1082-1121` — `tool = {procedure: "video"}` com `preview: true`).],
)

#tab([Benefícios e desafios do padrão do vídeo],
  tabela(
    colunas: (1.8cm, 1fr, 3.6cm, 2.2cm),
    [Tipo], [Descrição], [Característica / subcaracterística (ISO/IEC 25010)], [Facto / hipótese],
    [Benefício], [O vídeo é descodificado e codificado uma só vez, em vez de uma vez por efeito.], [Eficiência de desempenho: utilização de recursos], [EV-09],
    [Benefício], [Ack no fim: se o worker morrer, o RabbitMQ volta a entregar o trabalho.], [Fiabilidade: recuperabilidade], [EV-09],
    [Benefício], [O progresso em percentagem chega ao utilizador durante trabalhos longos.], [Usabilidade: operabilidade], [EV-09, EV-14],
    [Desafio], [Capacidade fixa: um worker, um vídeo de cada vez; nada aumenta quando a fila cresce nem diminui em repouso.], [Eficiência de desempenho: capacidade], [EV-09, EV-12, EV-17],
    [Desafio], [Uma pré-visualização de 3 s espera por todos os processamentos completos à frente (bloqueio na cabeça da fila).], [Eficiência de desempenho: comportamento temporal], [EV-13, EV-17, EV-19],
    [Desafio], [Com `heartbeat=0`, o broker não deteta um worker pendurado; a mensagem fica presa até a ligação cair.], [Fiabilidade: tolerância a falhas], [EV-09],
    [Desafio], [O `libx264` já usa vários núcleos; mais consumidores na mesma máquina não multiplicam o débito.], [Eficiência de desempenho: capacidade], [H-02 (EV-19)],
  ),
)

== Relação entre o padrão global e o padrão do vídeo

#tab([Relação entre o padrão global e o padrão do vídeo],
  tabela(
    colunas: (2.3cm, 3cm, 3cm, 1.6cm, 3.4cm, 1.5cm),
    [Aspeto], [O que o padrão global prescreve], [O que o vídeo faz], [Segue / afasta-se], [Consequência], [Evidência],
    [Comunicação entre serviços], [Pedido assíncrono numa fila por ferramenta; resposta na `project_queue`], [Igual: `video_queue` e `project_queue`], [Segue], [O vídeo é escalável pelo mesmo mecanismo (mais consumidores da fila), que a base não usa.], [EV-08, EV-09],
    [Encadeamento do pipeline], [O `projects` orquestra passo a passo], [O worker executa o pipeline inteiro numa mensagem], [Afasta-se], [Menos mensagens e uma só codificação, mas trabalhos longos e indivisíveis, que bloqueiam o worker durante minutos.], [EV-07, EV-11],
    [Confirmação (ack)], [Ack na receção (`auto_ack`)], [Ack só no fim], [Afasta-se], [O vídeo recupera da morte do worker; mas sem heartbeat um worker pendurado não é detetado.], [EV-09, EV-10],
    [Progresso e notificação], [O `projects` notifica o cliente pela `ws_queue`], [O worker publica o progresso diretamente na `ws_queue`], [Afasta-se parcialmente], [Melhor operabilidade; o worker passa a conhecer o canal do cliente.], [EV-09, EV-14],
    [Prioridade e filas], [Uma fila por ferramenta, sem prioridades], [Pré-visualizações e processamentos partilham a `video_queue`], [Segue], [Bloqueio na cabeça da fila: 1 258 s de espera p95 na base.], [EV-13, EV-17],
    [Armazenamento], [Volume partilhado e S3], [Igual; o vídeo inteiro é copiado do S3 para o volume], [Segue], [Réplicas presas ao mesmo anfitrião; mais disco e I/O por vídeo.], [EV-07, EV-12],
    [Carregamento], [Cadeia síncrona com `memoryStorage` em cada salto, pensada para imagens], [O vídeo (até 1 GB) usa a mesma cadeia], [Segue], [Memória proporcional ao tamanho do ficheiro; OOM do anfitrião com 1 GB.], [EV-02 a EV-05, EV-16],
  ),
)

O vídeo herda do padrão global a comunicação por filas, o orquestrador `projects`, o volume partilhado e a cadeia síncrona de carregamento. Estas decisões impõem-lhe duas restrições: o ficheiro passa inteiro por quatro serviços pensados para imagens pequenas, e a capacidade é o número de consumidores da `video_queue`. O desvio principal (pipeline inteiro numa mensagem, ack no fim) é adequado ao custo de codificar vídeo, mas torna cada trabalho longo; como a base tem um só consumidor e uma só fila, os trabalhos longos bloqueiam todos os outros, incluindo as pré-visualizações. As duas fragilidades mais graves vêm, portanto, do que o vídeo *segue* sem adaptação (carregamento e fila única) e não do que muda.

*Hipóteses registadas neste capítulo.*

- *H-01*: o volume `image_data` impede correr workers de vídeo noutro anfitrião. Confirmar: lançar um `video_tool` noutra máquina ligada ao mesmo RabbitMQ e verificar que falha ao abrir o ficheiro. Não confirmada; com Docker Compose num anfitrião é aceitável, mas limita a escalabilidade horizontal.
- *H-02*: o `libx264` já ocupa vários núcleos, pelo que réplicas na mesma máquina sem quota de CPU não multiplicam o débito. Suportada pela EV-19 e confirmada depois pela medição E3 (secção 10.4).
- *H-03*: com `auto_ack`, um worker de imagem que morra a meio perde a mensagem e o lote fica incompleto. Confirmar: matar um worker de imagem durante um processamento. Fora do âmbito desta fase.
