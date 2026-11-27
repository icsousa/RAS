#import "../template.typ": *

= Padrões Arquiteturais Atuais

#orientacao[
  *Origem:* Exercício 6, Bloco 1, secções 2.1 a 2.3 do _template_.

  *Objetivo do capítulo:* identificar o estilo (ou a combinação de estilos) arquitetural que organiza o PictuRAS como um
  todo, o padrão que o processamento de vídeo segue, e como os dois se relacionam. O padrão global é o *ponto de
  partida*: define o contexto e as restrições a que qualquer alternativa terá de responder (capítulo 4).

  *Rigor:* factos citam uma evidência (`EV-nn`, ver a explicação na secção 2.4); o que não tem evidência é uma hipótese
  (`H-nn`). Nunca reutilizem um ID eliminado. Benefícios e desafios classificam-se segundo a ISO/IEC 25010
  (característica e, quando aplicável, subcaracterística).
]

== Padrão global da solução

#orientacao[
  Nomeiem o estilo ou os estilos (e.g., microserviços, orientado a eventos, filas de mensagens) e descrevam-no em poucas
  linhas, com as vossas palavras. Depois, indiquem as *decisões globais* que condicionam o vídeo (e.g., comunicação
  assíncrona por filas, armazenamento partilhado) e o efeito que têm. Fechem com os benefícios e desafios do padrão,
  cada um ligado a um atributo de qualidade.
]

#tabela-campos(
  [Nome(s) do padrão / estilo], [Microserviços com comunicação orientada a mensagens (RabbitMQ), _API Gateway_ e orquestração centralizada no `projects`],
  [Descrição], [Cada capacidade é um serviço num contentor próprio, com base de dados própria quando tem estado. O cliente fala só com o nginx e o `api_gateway` (HTTP síncrono). O trabalho pesado é assíncrono: o `projects` orquestra o _pipeline_ e publica pedidos em filas; _workers_ sem estado consomem-nos e respondem numa fila de resultados; o `ws_gateway` envia os eventos ao browser.],
)

#tab([Decisões globais que condicionam o vídeo],
  tabela(
    colunas: (4.5cm, 2.6cm, 1fr),
    [Decisão global], [Evidência], [Efeito no vídeo],
    [Comunicação assíncrona por filas, com uma fila e um _worker_ por ferramenta], [EV-08], [O vídeo herda uma fila e um _worker_ dedicados (`video_queue`, `video_tool`); a capacidade é o número de consumidores dessa fila.],
    [Orquestração centralizada no `projects`], [EV-07, EV-11], [O `projects` decide o tipo de _media_ e o que publicar, e é também o ponto por onde passa o carregamento.],
    [Ficheiros trocados por um volume Docker partilhado], [*EV-12*: `docker-compose.yaml:150-151,256-273` — `image_data` montado no `projects`, nas ferramentas e no `video_tool`; um único `video_tool`, sem réplicas nem limites de CPU/memória], [As mensagens levam só caminhos; mas o `projects` e os _workers_ ficam presos ao mesmo anfitrião (H-01).],
    [Carregamento por uma cadeia síncrona nginx → gateway → `projects` → `img_storage`], [EV-02 a EV-05], [Um vídeo de 1 GB atravessa quatro saltos e cada um guarda-o inteiro antes de o passar.],
    [Base de dados por serviço e armazenamento de objetos S3], [*EV-15*: `docker-compose.yaml:112-197` — um MongoDB por serviço; SeaweedFS para os ficheiros], [O vídeo fica no S3 e é copiado para o volume antes de cada processamento.],
  ),
)

#tab([Benefícios e desafios do padrão global],
  tabela(
    colunas: (2cm, 1fr, 4.2cm, 2.4cm),
    tamanho: 8.5pt,
    [Tipo], [Descrição], [Característica / subcaracterística (ISO/IEC 25010)], [Facto / hipótese],
    [Benefício], [Cada ferramenta pode ser alterada, reconstruída e reiniciada sem tocar nas outras.], [Manutenibilidade: modularidade, modificabilidade], [EV-08, EV-12],
    [Benefício], [O cliente não espera pelo processamento: o `POST /process` responde 201 e o resultado chega por WebSocket.], [Eficiência de desempenho: comportamento temporal], [EV-07, EV-14],
    [Benefício], [As filas absorvem picos e vários consumidores de uma fila dividem o trabalho.], [Eficiência de desempenho: capacidade], [EV-08],
    [Desafio], [Os _workers_ de imagem fazem _ack_ na receção: se um morrer a meio, a mensagem perde-se.], [Fiabilidade: tolerância a falhas], [*EV-10*: `Tools/utils/rabbit_mq.py:37-40` — `auto_ack=True`. *H-03*: o lote fica incompleto; confirmar matando um _worker_ de imagem a meio de um processamento],
    [Desafio], [O volume partilhado acopla os serviços ao mesmo anfitrião.], [Flexibilidade: escalabilidade], [*H-01*: um `video_tool` noutro anfitrião não abre os ficheiros; confirmar lançando-o noutra máquina ligada ao mesmo RabbitMQ],
    [Desafio], [Os saltos síncronos do carregamento somam memória e latência.], [Eficiência de desempenho: utilização de recursos], [EV-02 a EV-05],
  ),
)

== Padrão do processamento de vídeo

#orientacao[
  Identifiquem o padrão que organiza o processamento de vídeo (que pode coincidir com o global ou ser diferente) e
  contrastem-no com o caminho de imagens. Se o padrão do vídeo for diferente do global, expliquem porquê e que custos
  isso traz. Indiquem benefícios e desafios, com o mesmo critério da secção anterior.
]

#tabela-campos(
  [Nome do padrão], [_Worker_ de lote dedicado com consumidores concorrentes (_competing consumers_) numa fila de trabalho; o _pipeline_ corre dentro do _worker_ como _pipes and filters_ (filtros do `ffmpeg`)],
  [Descrição], [Uma mensagem na `video_queue` leva o vídeo e o _pipeline_ inteiro. O `video_tool` aplica todos os efeitos de uma vez, envia o progresso em percentagem e responde uma vez. O padrão prevê várias réplicas a consumir a mesma fila («_parallelism comes from replicas_», EV-09), mas a base só tem uma, com `prefetch_count=1`.],
  [Contraste com o caminho de imagens], [Nas imagens cada efeito é uma mensagem e o `projects` encadeia os passos (EV-11); no vídeo o encadeamento passa para dentro do _worker_. As imagens fazem _ack_ na receção (EV-10), o vídeo só no fim (EV-09). As pré-visualizações de vídeo usam a mesma fila que os processamentos completos (*EV-13*: `projects/routes/projects.js:1082-1121` — `{procedure: "video"}` com `preview: true`). O desvio evita codificar o vídeo uma vez por efeito, mas torna cada trabalho longo e indivisível.],
)

#tab([Benefícios e desafios do padrão do vídeo],
  tabela(
    colunas: (2cm, 1fr, 4.2cm, 2.4cm),
    tamanho: 8.5pt,
    [Tipo], [Descrição], [Característica / subcaracterística (ISO/IEC 25010)], [Facto / hipótese],
    [Benefício], [O vídeo é descodificado e codificado uma só vez, em vez de uma vez por efeito.], [Eficiência de desempenho: utilização de recursos], [EV-09],
    [Benefício], [_Ack_ no fim: se o _worker_ morrer, o RabbitMQ volta a entregar o trabalho.], [Fiabilidade: recuperabilidade], [EV-09],
    [Benefício], [O progresso em percentagem chega ao utilizador durante trabalhos longos.], [Usabilidade: operabilidade], [EV-09, EV-14],
    [Desafio], [Capacidade fixa: um _worker_, um vídeo de cada vez; nada aumenta com a fila nem diminui em repouso.], [Eficiência de desempenho: capacidade], [EV-09, EV-12],
    [Desafio], [Uma pré-visualização de 3 s espera por todos os processamentos à frente (bloqueio na cabeça da fila).], [Eficiência de desempenho: comportamento temporal], [EV-13],
    [Desafio], [Com `heartbeat=0` o _broker_ não deteta um _worker_ pendurado.], [Fiabilidade: tolerância a falhas], [EV-09],
    [Desafio], [O `libx264` já usa vários núcleos: mais consumidores na mesma máquina não multiplicam o débito.], [Eficiência de desempenho: capacidade], [*H-02*: confirmar medindo o débito com 2 e 4 consumidores na mesma máquina (ver EV-19 e o E3, cap. 10)],
  ),
)

== Relação entre o padrão global e o padrão do vídeo

#orientacao[
  Esta secção responde a: em que pontos o vídeo *segue* o padrão global, em que pontos se *afasta* dele e com que
  consequências? Cada linha da tabela é um aspeto concreto (e.g., comunicação entre serviços, gestão de estado,
  tratamento de falhas, armazenamento). É aqui que costumam surgir as fragilidades que alimentam os cenários de
  qualidade do capítulo 5, por isso escrevam as consequências com cuidado e com evidência.

  Terminem com um parágrafo de síntese: o que o vídeo herda do padrão global, que restrições este lhe impõe e que
  fragilidades resultam do desvio.
]

#tab([Relação entre o padrão global e o padrão do vídeo],
  tabela(
    colunas: (2.4cm, 3cm, 3cm, 1.9cm, 2.6cm, 1.8cm),
    tamanho: 8pt,
    [Aspeto], [O que o padrão global prescreve], [O que o vídeo faz], [Segue / afasta-se], [Consequência], [Evidência],
    [Comunicação entre serviços], [Pedido assíncrono numa fila por ferramenta; resposta na `project_queue`], [Igual: `video_queue` e `project_queue`], [Segue], [Escalável pelo mesmo mecanismo (mais consumidores), que a base não usa.], [EV-08, EV-09],
    [Encadeamento do _pipeline_], [O `projects` orquestra passo a passo], [O _worker_ executa o _pipeline_ numa mensagem], [Afasta-se], [Uma só codificação, mas trabalhos longos que ocupam o _worker_ durante minutos.], [EV-07, EV-11],
    [Confirmação (_ack_)], [_Ack_ na receção], [_Ack_ só no fim], [Afasta-se], [Recupera da morte do _worker_; sem _heartbeat_ não deteta bloqueios.], [EV-09, EV-10],
    [Progresso e notificação], [O `projects` notifica pela `ws_queue`], [O _worker_ publica o progresso na `ws_queue`], [Afasta-se], [Melhor operabilidade; o _worker_ conhece o canal do cliente.], [EV-09, EV-14],
    [Prioridade e filas], [Uma fila por ferramenta, sem prioridades], [Pré-visualizações e processamentos na mesma fila], [Segue], [Bloqueio na cabeça da fila.], [EV-13],
    [Armazenamento], [Volume partilhado e S3], [Igual; o vídeo inteiro é copiado do S3 para o volume], [Segue], [Réplicas presas ao mesmo anfitrião; mais disco e I/O.], [EV-07, EV-12],
    [Carregamento], [Cadeia síncrona com `memoryStorage`, pensada para imagens], [O vídeo (até 1 GB) usa a mesma cadeia], [Segue], [Memória proporcional ao tamanho do ficheiro.], [EV-02 a EV-05],
  ),
)

O vídeo herda do padrão global a comunicação por filas, o orquestrador `projects`, o volume partilhado e a cadeia síncrona de carregamento. Estas decisões impõem-lhe duas restrições: o ficheiro passa inteiro por quatro serviços pensados para imagens pequenas, e a capacidade é o número de consumidores da `video_queue`. O desvio (_pipeline_ numa mensagem, _ack_ no fim) é adequado ao custo de codificar vídeo, mas torna cada trabalho longo; com um só consumidor e uma só fila, esses trabalhos bloqueiam todos os outros, incluindo as pré-visualizações. As fragilidades mais graves vêm, assim, do que o vídeo *segue* sem adaptação (carregamento e fila única), e não do que muda.
