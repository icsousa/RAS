#import "../template.typ": *

= Alternativas e Matriz de Comparação

#orientacao[
  *Origem:* Exercício 6, Bloco 1, secção 3 do _template_.

  *Objetivo do capítulo:* comparar o padrão atual com alternativas relevantes *para o processamento de vídeo*, de forma
  fundamentada, e concluir se o padrão atual é adequado. Entre duas e três alternativas. O padrão global é o contexto da
  comparação: indiquem sempre se cada alternativa o *mantém* ou o *altera*.

  *Restrição da fase:* é de _refactoring_. As alternativas têm de preservar o comportamento funcional; por isso, o
  custo e o risco de migração têm de ser analisados para cada uma. Consultem os slides da aula 11 e o documento de apoio
  de padrões arquiteturais; se for relevante, incluam uma alternativa ao próprio padrão global como termo de comparação.
]

== Alternativas consideradas

#tab([Alternativas consideradas],
  tabela(
    colunas: (1.6cm, 3.4cm, 1fr, 3cm, 2.4cm),
    tamanho: 8.5pt,
    [ID], [Nome / padrão], [Descrição breve], [Mantém ou altera o padrão global?], [Fonte],
    [ALT-1], [Consumidores concorrentes elásticos com filas separadas], [O `video_tool` passa a ter de 1 a N réplicas, ajustadas à profundidade da fila por um _autoscaler_; as pré-visualizações passam para uma fila própria com _worker_ dedicado.], [Mantém], [Aula 11 e documento de apoio (mensagens, _competing consumers_)],
    [ALT-2], [_Pipes and filters_ distribuído (um serviço por efeito de vídeo)], [Cada efeito de vídeo passa a ser um _worker_ com fila própria e o `projects` encadeia os passos, como nas imagens.], [Mantém (o vídeo passa a seguir o caminho das imagens)], [Aula 11 e documento de apoio (_pipes and filters_); EV-11],
  ),
)

== Análise de cada alternativa

#orientacao[
  Copiem o bloco abaixo para cada alternativa. Para cada uma, descrevam a coerência com o padrão global, o efeito nos
  atributos de qualidade, as vantagens, as desvantagens ou riscos, e o custo e risco de migração. Evitem listas
  genéricas: cada ponto deve referir algo concreto da solução do PictuRAS (e citar evidência `EV-nn` ou hipótese `H-nn`).
]

*ALT-1 — Consumidores concorrentes elásticos com filas separadas*

#tabela-campos(
  [Coerência com o padrão global], [Total: usa o mecanismo que o padrão já prevê (vários consumidores por fila, EV-08) e o que o próprio _worker_ anuncia («_parallelism comes from replicas_», EV-09). Acrescenta uma fila e um serviço de infraestrutura.],
  [Efeito nos atributos de qualidade], [Capacidade ↑ (réplicas sob carga); comportamento temporal ↑ nas pré-visualizações (fim do bloqueio na cabeça da fila, EV-13); utilização de recursos = em repouso (volta ao mínimo); segurança ↓ se o _autoscaler_ controlar o Docker pelo `docker.sock`.],
  [Vantagens potenciais], [Mudança localizada no `projects` (escolha da fila), no `docker-compose.yaml` e no _worker_; reproduzível com Docker Compose num portátil; mensurável (expansão, contração, débito).],
  [Desvantagens ou riscos], [Réplicas sem quota de CPU disputam os mesmos núcleos (H-02); continuam presas ao mesmo anfitrião (H-01); remover uma réplica a meio exige _heartbeat_ ativo e devolver a mensagem à fila (hoje `heartbeat=0`, EV-09).],
  [Custo e risco de migração (a funcionalidade existente tem de ser preservada)], [Baixo/médio: as mensagens e o contrato com o `projects` não mudam; risco de regressão nas pré-visualizações (fila nova) e na remoção de réplicas, coberto por testes.],
)

*ALT-2 — _Pipes and filters_ distribuído*

#tabela-campos(
  [Coerência com o padrão global], [Alta: o vídeo passa a seguir exatamente o caminho das imagens (EV-11), sem o desvio do «_pipeline_ numa mensagem».],
  [Efeito nos atributos de qualidade], [Capacidade ↑ por efeito; comportamento temporal ↓ (o vídeo é descodificado e codificado uma vez por efeito, com mais cópias no volume); fiabilidade = ou ↓ (mais passos intermédios); manutenibilidade ↑ por efeito, ↓ no conjunto.],
  [Vantagens potenciais], [Um efeito lento (legendas com Whisper) deixa de bloquear efeitos rápidos; reutiliza a orquestração existente.],
  [Desvantagens ou riscos], [Perde a codificação única e o progresso global em percentagem (EV-09); multiplica o I/O de ficheiros grandes no volume; a ordem dos efeitos e o corte seguido de extração de fotogramas ficam mais difíceis de garantir.],
  [Custo e risco de migração], [Alto: reescrever o `video_processor` em vários serviços e o encadeamento no `projects`; risco elevado de regressão em todos os efeitos de vídeo.],
)

== Matriz de comparação de padrões

#orientacao[
  Atribuam um nível a cada atributo para o padrão global (referência), para o padrão atual do vídeo e para cada
  alternativa. A escala é à vossa escolha (e.g., Alto / Médio / Baixo) e deve ser a mesma em toda a matriz.

  *Justifiquem cada célula* com evidência da solução (`EV-nn` ou `H-nn`) numa frase curta, logo na própria célula: as
  avaliações sem fundamento não são valorizadas. A matriz inclui o padrão global como referência para se ver o que
  cada alternativa ganha ou perde em relação a ele. Os atributos e subcaracterísticas seguem a ISO/IEC 25010; podem
  acrescentar linhas para outros atributos relevantes.
]

#paisagem[
#tab([Matriz de comparação de padrões],
  tabela(
    colunas: (5.6cm, 4.2cm, 4cm, 4cm, 4cm),
    tamanho: 8.5pt,
    [Atributo de qualidade (ISO/IEC 25010)], [Padrão global atual (referência)], [Padrão atual do vídeo], [ALT-1], [ALT-2],
    [Relação com o padrão global], [—], [Afasta-se (_pipeline_ numa mensagem, _ack_ no fim)], [Mantém], [Mantém (segue as imagens)],
    [Eficiência de desempenho: comportamento temporal], [Médio — resposta assíncrona imediata (EV-07), mas carregamento em quatro saltos com _buffer_ (EV-02 a EV-05)], [Baixo — a pré-visualização espera pela fila inteira (EV-13)], [Alto — fila de pré-visualização própria], [Baixo — uma codificação por efeito, mais I/O (EV-09)],
    [Eficiência de desempenho: capacidade / elasticidade], [Médio — escalável por consumidores, mas réplicas fixas definidas à mão (EV-08, EV-12)], [Baixo — 1 _worker_ fixo (EV-12)], [Alto — 1 a N réplicas automáticas; limitado pelo CPU do anfitrião (H-02)], [Médio — cada filtro escala, mas o mais lento domina],
    [Fiabilidade: tolerância a falhas / recuperabilidade], [Baixo — `auto_ack` perde mensagens (EV-10, H-03)], [Médio — _ack_ no fim; `heartbeat=0` (EV-09)], [Alto — _ack_ no fim, _heartbeat_ ativo, SIGTERM sem _ack_], [Médio — mais passos intermédios onde falhar],
    [Manutenibilidade: modularidade / modificabilidade], [Alto — serviço por ferramenta (EV-08)], [Médio — um _worker_ com todos os efeitos (EV-09)], [Médio — mais um serviço e uma fila], [Médio — efeitos isolados, mas mais serviços e orquestração],
    [Segurança], [Médio — multer antes do _token_ no gateway (EV-03)], [Médio — igual ao global], [Baixo — o _autoscaler_ precisa do `docker.sock`], [Médio — igual ao global],
    [Usabilidade: operabilidade], [Médio — sem progresso no carregamento (EV-01)], [Alto — progresso em percentagem (EV-09)], [Alto — mantém o progresso; pré-visualização mais rápida], [Baixo — perde o progresso global],
  ),
)
]

== Adequação do padrão atual

O padrão global (microserviços com filas e orquestrador) é adequado ao PictuRAS: o processamento é assíncrono, as ferramentas são independentes e a capacidade cresce acrescentando consumidores. O desvio do vídeo (_pipeline_ numa mensagem, _ack_ no fim) também é adequado, porque evita codificar o vídeo várias vezes e permite recuperar trabalhos. O problema está em dois pontos em que o vídeo *não* foi adaptado: o carregamento usa a cadeia com _buffer_ em memória pensada para imagens, e a fila de vídeo tem um só consumidor, partilhado por pré-visualizações e processamentos. A ALT-1 corrige o segundo ponto dentro do padrão, com custo e risco baixos; a ALT-2 resolveria um problema secundário (efeitos lentos) à custa do desempenho e com risco alto de regressão. Uma terceira via, mudar a plataforma para Kubernetes com escala automática, foi afastada por não caber numa fase de _refactoring_ (TAT-11, cap. 7). Concluímos por manter os dois padrões, evoluindo o vídeo na direção da ALT-1 e corrigindo o carregamento com táticas locais.
