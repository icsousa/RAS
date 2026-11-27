#import "../template.typ": *

= Trade-offs, Cenários de Qualidade e Prioridades

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 4 do _template_ (sem a justificação detalhada da matriz, que não faz parte
  deste relatório).

  *Objetivo do capítulo:* transformar o diagnóstico dos capítulos 2 a 4 em cenários de qualidade concretos e
  verificáveis, priorizá-los e perceber como os atributos se afetam uns aos outros.

  *Princípio central:* a caracterização dos cenários de qualidade *deve basear-se na identificação de fragilidades do
  sistema atual*. Cada cenário parte de uma fragilidade concreta, com evidência (`EV-nn`), observada na solução de
  base (e.g., uma falha sem recuperação, um ponto de contenção, uma dependência rígida). Um cenário sem fragilidade
  identificada é uma preferência, não uma necessidade. Reutilizem os `EV`, `H` e `ALT` já usados, sem os alterar.

  *Este é o único sítio onde os cenários de qualidade se caracterizam:* os capítulos 6 a 10 usam-nos sem os reescrever.
]

== Cenários de qualidade para a extensão de vídeo

#orientacao[
  Para cada fragilidade relevante, escrevam um cenário com os *seis elementos*:
  - *fonte do estímulo*: quem ou o que o origina (utilizador, serviço, falha de infraestrutura);
  - *estímulo*: o evento a que o sistema tem de reagir;
  - *artefacto*: a parte do sistema afetada;
  - *ambiente*: em que condições (carga normal, pico, degradado);
  - *resposta*: o que o sistema deve fazer;
  - *medida da resposta*: como se verifica, com métrica e escala. Definem-na vocês e tem de ser *verificável*.

  A coluna *Fragilidade* liga o cenário à evidência que o justifica. Não inventem valores de _baseline_, alvo ou
  mínimo: esses fixam-se após a medição inicial. A medida da resposta indica o que se mede, não o valor a atingir.
]

#paisagem[
#tab([Cenários de qualidade],
  tabela(
    colunas: (1.2cm, 3.4cm, 2.6cm, 2.2cm, 2.2cm, 2.4cm, 2.2cm, 2.6cm, 3cm),
    tamanho: 7.5pt,
    [ID], [Fragilidade na base (EV-nn)], [Característica (ISO/IEC 25010)], [Fonte do estímulo], [Estímulo], [Artefacto], [Ambiente], [Resposta], [Medida da resposta],
    [QS-01], [Cada salto do carregamento guarda o vídeo inteiro em memória (EV-02 a EV-05); 1 GB esgota a RAM do anfitrião (*EV-16*: `medicoes/resultados/base/rnf01_upload.json` e `journalctl` — 5/5 carregamentos de 1 GB falharam (502/504); o _kernel_ matou o `node` do `api_gateway` por OOM)], [Eficiência de desempenho: utilização de recursos; comportamento temporal], [Utilizador Premium, um ou vários em simultâneo], [Carrega vídeos de 100 MB a 1 GB (limite do perfil), ou um ficheiro acima do limite], [Cadeia de carregamento: nginx, `api_gateway`, `projects`, `img_storage`], [Operação normal; anfitrião sem _swap_], [O carregamento termina sem esgotar a memória de nenhum serviço; um ficheiro acima do limite é recusado antes de ser lido; o utilizador vê o progresso], [Pico de RAM adicional (MB) por tamanho de ficheiro; tempo ponta a ponta (s); n.º de carregamentos de 1 GB em simultâneo concluídos; _bytes_ lidos antes da recusa; progresso visível (sim/não)],
    [QS-02], [Um único `video_tool` com `prefetch=1`; pré-visualizações atrás dos processamentos (EV-09, EV-12, EV-13; *EV-17*: `medicoes/resultados/base/rnf02_elasticidade.json` — com 20 processamentos em fila, 0,95 processamentos/min e espera p95 de 1 258 s para uma pré-visualização)], [Eficiência de desempenho: capacidade], [Vários utilizadores a processar vídeo], [Rajada de 20 processamentos, com pedidos de pré-visualização durante a rajada], [`video_queue` e `video_tool`], [Pico de carga, seguido de repouso], [A capacidade aumenta automaticamente sob carga e volta ao mínimo em repouso; a pré-visualização não espera pelos processamentos], [Tempo de expansão (s); tempo de contração (s); débito (processamentos/min); espera da pré-visualização até começar (s, p95); CPU e RAM em repouso],
    [QS-03], [Um serviço do caminho do vídeo que termina não volta sozinho: o `nodemon` não relançou o gateway depois do OOM (EV-16) e o nginx guarda o IP antigo (*EV-21*: _logs_ do nginx durante as medições, _commit_ `45e4c87` — 502 até o nginx ser reiniciado)], [Fiabilidade: recuperabilidade; disponibilidade], [Infraestrutura (OOM, reinício de contentor)], [O processo do `api_gateway` termina inesperadamente], [`api_gateway`, nginx], [Operação normal], [O serviço volta a responder sem intervenção manual], [Tempo até voltar a responder (s); n.º de pedidos falhados nesse intervalo],
  ),
)
]

#orientacao[
  *Priorização.* Avaliem cada cenário em duas dimensões: a *importância para os stakeholders* (quem sofre com a
  fragilidade e quanto) e a *dificuldade ou risco técnico* de a resolver. Justifiquem cada avaliação em poucas palavras
  e atribuam uma ordem de prioridade (1 = mais prioritário). Os dois cenários mais prioritários, e que dão origem aos
  candidatos a RNF do capítulo 6, são os mais importantes e viáveis, não necessariamente os mais fáceis.
]

#tab([Priorização dos cenários],
  tabela(
    colunas: (1.6cm, 4.8cm, 4.8cm, 2cm),
    [ID], [Importância para os stakeholders], [Dificuldade / risco técnico], [Prioridade],
    [QS-01], [Alta — o Premium não consegue usar o limite que paga (1 GB) e o OOM derruba o serviço para todos (EV-16)], [Média — quatro serviços, mas sem mudar a API], [1],
    [QS-02], [Alta — a espera cresce com a carga; uma pré-visualização chega a 21 min (EV-17)], [Média — fila nova, serviço de escala e correções ao _worker_; contenção de CPU (H-02)], [2],
    [QS-03], [Média — afeta todos, mas só depois de uma falha; QS-01 elimina a causa mais frequente], [Baixa — política de reinício e resolução dinâmica do nome no nginx], [3],
  ),
)

== Atributos de qualidade por ordem de prioridade

#orientacao[
  Com base nos cenários mais importantes, ordenem os atributos de qualidade (ISO/IEC 25010) do mais para o menos
  prioritário, indicando os cenários que justificam cada posição. A ordem tem de ser coerente com a tabela de
  priorização acima.
]

+ *Eficiência de desempenho* (utilização de recursos, capacidade, comportamento temporal) — QS-01 e QS-02: as duas fragilidades com maior impacto medido (OOM e 21 min de espera).
+ *Fiabilidade* (recuperabilidade, disponibilidade) — QS-03: depende em parte de QS-01, que remove a causa do OOM.
+ *Segurança* (resistência) — sem cenário próprio: o gateway lê o corpo antes de verificar o _token_ (EV-03), o que fica resolvido pela mesma tática de QS-01.

== Pré-requisitos e efeitos colaterais entre atributos

#orientacao[
  Os atributos não são independentes. Identifiquem os pares em que melhorar um é *pré-requisito* do outro (e.g.,
  observabilidade antes de otimizar desempenho), em que há *sinergia*, ou em que há *conflito* (melhorar um degrada
  o outro). Expliquem a razão e, se possível, citem evidência.
]

#tab([Pré-requisitos e efeitos colaterais entre atributos],
  tabela(
    colunas: (2.8cm, 2.8cm, 4cm, 1fr),
    [Atributo A], [Atributo B], [Efeito (pré-requisito, sinergia ou conflito)], [Razão / evidência],
    [Utilização de recursos (QS-01)], [Recuperabilidade (QS-03)], [Pré-requisito], [Enquanto 1 GB derrubar o gateway, nenhuma política de reinício garante disponibilidade (EV-16).],
    [Utilização de recursos (QS-01)], [Segurança: resistência], [Sinergia], [Ler em _stream_ depois do _token_ impede que um pedido sem _token_ ocupe memória (EV-03).],
    [Utilização de recursos: memória], [Utilização de recursos: disco], [Conflito], [O _streaming_ troca RAM por ficheiros temporários e cache de página.],
    [Capacidade (QS-02)], [Segurança], [Conflito], [Escalar contentores a partir da _stack_ exige acesso à API do Docker (`docker.sock`).],
    [Capacidade (QS-02)], [Comportamento temporal (QS-02)], [Sinergia, com conflito no limite], [Mais réplicas reduzem a fila, mas sem quota de CPU disputam os mesmos núcleos (H-02).],
  ),
)

== Recomendações de melhoria à solução atual

#orientacao[
  Recomendações concretas que respondem às fragilidades identificadas, indicando o atributo que melhoram, o padrão
  (global ou vídeo) a que se aplicam, o esforço estimado e o risco de regressão. Esta fase é de _refactoring_: as
  recomendações têm de poder ser aplicadas sem acrescentar funcionalidades.
]

#tab([Recomendações de melhoria],
  tabela(
    colunas: (1fr, 2.6cm, 3cm, 1.8cm, 2.2cm),
    tamanho: 8.5pt,
    [Recomendação], [Atributo(s)], [Padrão a que se refere (global / vídeo)], [Esforço], [Risco de regressão],
    [Carregamento em _streaming_ em todos os saltos, com recusa antecipada pelo `Content-Length` e _token_ verificado antes do corpo], [Utilização de recursos; comportamento temporal; segurança], [Global (cadeia de carregamento), aplicada ao vídeo], [Médio], [Médio],
    [Progresso do carregamento no frontend], [Usabilidade: operabilidade], [Global], [Baixo], [Baixo],
    [Fila própria para pré-visualizações de vídeo, com _worker_ dedicado], [Comportamento temporal], [Vídeo], [Baixo], [Baixo],
    [Réplicas do `video_tool` ajustadas à profundidade da fila, com quota de CPU], [Capacidade], [Vídeo, dentro do padrão global], [Médio], [Médio],
    [_Heartbeat_ ativo e SIGTERM sem _ack_ no _worker_ de vídeo], [Fiabilidade: tolerância a falhas], [Vídeo], [Baixo], [Baixo],
    [Reinício automático dos serviços Node e resolução dinâmica do gateway no nginx], [Fiabilidade: recuperabilidade], [Global], [Baixo], [Baixo],
  ),
)
