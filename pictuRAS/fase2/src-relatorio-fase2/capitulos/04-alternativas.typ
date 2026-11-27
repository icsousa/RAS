#import "../template.typ": *

= Alternativas e Matriz de Comparação

== Alternativas consideradas

#tab([Alternativas consideradas],
  tabela(
    colunas: (1.4cm, 3cm, 1fr, 2.6cm, 2.6cm),
    [ID], [Nome / padrão], [Descrição breve], [Mantém ou altera o padrão global?], [Fonte],
    [ALT-1], [Consumidores concorrentes elásticos com filas separadas], [O `video_tool` mantém-se, mas passa a ter de 1 a N réplicas ajustadas à profundidade da fila por um _autoscaler_; as pré-visualizações passam para uma fila própria com worker dedicado.], [Mantém], [Aula 11 (mensagens, _competing consumers_); análise `analise-rnf`, B2 + B4],
    [ALT-2], [_Pipes and filters_ distribuído (um serviço por efeito de vídeo)], [Cada efeito de vídeo passa a ser um worker com fila própria e o `projects` encadeia os passos, como nas imagens.], [Mantém (alinha o vídeo com o caminho das imagens)], [Aula 11 (_pipes and filters_); EV-11],
    [ALT-3 (opcional)], [Um _job_ por vídeo numa plataforma de orquestração (Kubernetes Jobs / KEDA _ScaledJob_)], [Cada mensagem da `video_queue` cria um contentor efémero que processa o vídeo e termina; a plataforma gere a escala e os recursos.], [Afasta-se parcialmente (muda a plataforma de deploy, mantém filas e serviços)], [Documento de apoio de padrões; análise `analise-rnf`, B3],
  ),
)

== Análise de cada alternativa

*ALT-1 — Consumidores concorrentes elásticos com filas separadas*

#tabela-campos(
  [Coerência com o padrão global], [Total: usa o mecanismo que o padrão já prevê (vários consumidores por fila, EV-08) e o comentário do próprio worker («parallelism comes from replicas», EV-09). Acrescenta uma fila em `definitions.json` e um serviço de infraestrutura.],
  [Efeito nos atributos de qualidade], [Capacidade ↑ (réplicas sob carga); comportamento temporal ↑ para pré-visualizações (fim do bloqueio na cabeça da fila, EV-13); utilização de recursos = em repouso (volta ao mínimo); segurança ↓ se o _autoscaler_ controlar o Docker pelo `docker.sock`.],
  [Vantagens potenciais], [Mudança localizada no `projects` (escolha da fila), no `docker-compose.yaml` e no worker; reproduzível com Docker Compose num portátil; mensurável (expansão, contração, débito).],
  [Desvantagens ou riscos], [Réplicas sem quota de CPU disputam os mesmos núcleos (H-02); continuam presas ao mesmo anfitrião pelo volume (H-01); remover uma réplica a meio exige devolver a mensagem à fila e o heartbeat ativo (hoje `heartbeat=0`, EV-09).],
  [Custo e risco de migração (a funcionalidade existente tem de ser preservada)], [Baixo/médio: as mensagens e o contrato com o `projects` não mudam; risco de regressão nas pré-visualizações (nova fila) e no tratamento de SIGTERM, coberto por testes.],
)

*ALT-2 — _Pipes and filters_ distribuído*

#tabela-campos(
  [Coerência com o padrão global], [Alta: o vídeo passa a seguir exatamente o caminho das imagens (EV-11), eliminando o desvio do «pipeline numa mensagem».],
  [Efeito nos atributos de qualidade], [Capacidade ↑ por efeito (cada filtro escala sozinho); comportamento temporal ↓ (um vídeo é descodificado e codificado uma vez por efeito, mais cópias no volume); fiabilidade = ou ↓ (mais passos intermédios); manutenibilidade ↑ por efeito, ↓ no conjunto (mais serviços).],
  [Vantagens potenciais], [Um efeito lento (legendas com Whisper) deixa de bloquear efeitos rápidos; reutiliza a orquestração existente.],
  [Desvantagens ou riscos], [Perde a codificação única e o progresso global em percentagem (EV-09); multiplica o I/O de ficheiros grandes no volume partilhado; o corte seguido de extração de fotogramas e a ordem dos efeitos ficam mais difíceis de garantir.],
  [Custo e risco de migração], [Alto: reescrever o `video_processor` em vários serviços e o encadeamento no `projects`; risco elevado de regressão em todos os efeitos de vídeo.],
)

*ALT-3 — Um _job_ por vídeo numa plataforma de orquestração*

#tabela-campos(
  [Coerência com o padrão global], [Parcial: mantém filas e serviços, mas troca o Docker Compose por Kubernetes e o worker de longa duração por contentores efémeros.],
  [Efeito nos atributos de qualidade], [Capacidade e elasticidade ↑ (escala por mensagem, com quotas de CPU por _job_); utilização de recursos ↑ em repouso (zero _jobs_); comportamento temporal ↓ no arranque a frio de cada _job_ (carregar o modelo Whisper); manutenibilidade ↓ para a equipa (nova plataforma).],
  [Vantagens potenciais], [Solução padrão da indústria; isolamento de recursos por vídeo; resolve a contenção de CPU (H-02) com _requests/limits_.],
  [Desvantagens ou riscos], [O volume partilhado (H-01) teria de passar a um volume de rede ou ao S3; difícil de reproduzir pelos docentes num portátil.],
  [Custo e risco de migração], [Alto: migrar todo o deploy no tempo da fase não é realista; risco de regressão em toda a solução, não só no vídeo.],
)

#paisagem[
== Matriz de comparação de padrões

#tab([Matriz de comparação de padrões],
  tabela(
    colunas: (3.6cm, 1fr, 1fr, 1fr, 1fr, 1fr),
    tamanho: 8.5pt,
    [Atributo de qualidade (ISO/IEC 25010)], [Padrão global atual (referência)], [Padrão atual do vídeo], [ALT-1], [ALT-2], [ALT-3],
    [Relação com o padrão global], [—], [Afasta-se (pipeline numa mensagem, ack no fim)], [Mantém], [Mantém (segue as imagens)], [Altera parcialmente (plataforma)],
    [Eficiência de desempenho: comportamento temporal], [Médio — resposta assíncrona imediata (EV-07), mas carregamento em quatro saltos com buffer (EV-02 a EV-05)], [Baixo — pré-visualização espera pela fila inteira: 1 258 s p95 (EV-13, EV-17)], [Alto — fila de pré-visualização própria elimina a espera atrás dos processamentos], [Baixo — uma codificação por efeito e mais I/O no volume (EV-09)], [Médio — sem filas partilhadas, mas arranque a frio por _job_],
    [Eficiência de desempenho: capacidade / elasticidade], [Médio — escalável por consumidores, mas réplicas fixas definidas à mão (EV-08, EV-12)], [Baixo — 1 worker fixo, 0,95 processamentos/min (EV-12, EV-17)], [Alto — 1 a N réplicas automáticas; limitado pelo CPU do anfitrião (H-02)], [Médio — cada filtro escala, mas o filtro mais lento domina], [Alto — escala por mensagem com quota de CPU],
    [Fiabilidade: tolerância a falhas / recuperabilidade], [Baixo — `auto_ack` perde mensagens (EV-10, H-03); OOM derruba o gateway (EV-16)], [Médio — ack no fim recupera; `heartbeat=0` não deteta bloqueios (EV-09)], [Alto — ack no fim, heartbeat ativo e SIGTERM sem ack], [Médio — mais passos intermédios onde falhar], [Alto — _job_ repetido pela plataforma],
    [Manutenibilidade: modularidade / modificabilidade], [Alto — serviço por ferramenta (EV-08)], [Médio — um worker com todos os efeitos (EV-09)], [Médio — mais um serviço de infraestrutura e uma fila], [Médio — efeitos isolados, mas mais serviços e orquestração], [Baixo — nova plataforma para a equipa],
    [Segurança], [Médio — multer antes do token no gateway (EV-03)], [Médio — igual ao global], [Baixo — o _autoscaler_ precisa do `docker.sock`], [Médio — igual ao global], [Médio — RBAC da plataforma, mas mais superfície],
    [Usabilidade: operabilidade], [Médio — sem progresso no carregamento (EV-01)], [Alto — progresso em percentagem (EV-09)], [Alto — mantém o progresso; pré-visualização mais rápida], [Baixo — perde o progresso global], [Alto — mantém o progresso],
  ),
)
]

== Adequação do padrão atual

O padrão global (microserviços com filas e orquestrador) é adequado ao PictuRAS: o processamento é assíncrono, cada ferramenta é independente e a capacidade pode crescer acrescentando consumidores. O padrão do vídeo também é adequado no seu desvio principal (pipeline numa mensagem, ack no fim), porque evita codificar o vídeo várias vezes e permite recuperar trabalhos. O problema não está no padrão, mas em dois pontos em que o vídeo *não* foi adaptado: o carregamento usa a cadeia síncrona com buffer pensada para imagens, e a fila de vídeo tem um só consumidor partilhado por pré-visualizações e processamentos. A ALT-1 corrige o segundo ponto dentro do padrão, com custo e risco baixos; a ALT-2 resolveria um problema que não é o principal (efeitos lentos) à custa do desempenho, e a ALT-3 exige mudar a plataforma, o que não cabe numa fase de refactoring. Concluímos por manter o padrão global e o padrão do vídeo, evoluindo-os na direção da ALT-1 e corrigindo o carregamento por táticas locais (capítulo 7).
