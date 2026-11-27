#import "../template.typ": *

= Trade-offs, Cenários de Qualidade e Prioridades

== Cenários de qualidade para a extensão de vídeo

Cada cenário parte de uma fragilidade com evidência nos capítulos 2 a 4. Duas evidências vêm da medição de base (secção 10.4), que confirmou as fragilidades encontradas no código:

- *EV-16*: `medicoes/resultados/base/rnf01_upload.json` e `journalctl` do anfitrião — as 5 tentativas de carregar 1 GB falharam (4 × 502, 1 × 504); o kernel matou o `node` do `api_gateway` (≈ 3 GB) por OOM global e o `nodemon` não relançou o processo, ficando o gateway em baixo até ser reiniciado à mão.
- *EV-17*: `medicoes/resultados/base/rnf02_elasticidade.json` — com 20 processamentos em fila, 1 worker, 0,95 processamentos/min e espera p95 de 1 258 s para uma pré-visualização.
- *EV-22*: logs do nginx durante as medições (commit `45e4c87`) — depois de o `api_gateway` reiniciar com outro IP, o nginx responde 502 até ser reiniciado, porque resolve o nome só no arranque.

#paisagem[
#tab([Cenários de qualidade],
  tabela(
    colunas: (1.2cm, 3.4cm, 2.4cm, 2cm, 2.6cm, 2.6cm, 2.2cm, 3cm, 1fr),
    tamanho: 8pt,
    [ID], [Fragilidade na base (EV-nn)], [Característica (ISO/IEC 25010)], [Fonte do estímulo], [Estímulo], [Artefacto], [Ambiente], [Resposta], [Medida da resposta],
    [QS-01], [Cada salto do carregamento guarda o vídeo inteiro em memória; 1 GB esgota a RAM do anfitrião e derruba o gateway (EV-02 a EV-05, EV-16)], [Eficiência de desempenho: utilização de recursos; comportamento temporal], [Utilizador Premium (um ou vários em simultâneo)], [Carrega vídeos de 100 MB a 1 GB (limite do perfil); ou envia um ficheiro acima do limite], [Cadeia de carregamento: nginx, `api_gateway`, `projects`, `img_storage`], [Operação normal, anfitrião sem swap; serviços com 2 GB de memória no ensaio de concorrência], [O carregamento termina sem esgotar a memória de nenhum serviço; um ficheiro acima do limite é recusado antes de ser lido; o utilizador vê o progresso], [Pico de RAM adicional (MB) por tamanho de ficheiro; tempo ponta a ponta (s); n.º de carregamentos de 1 GB em simultâneo concluídos; bytes lidos antes da recusa; progresso visível (sim/não)],
    [QS-02], [Um único `video_tool` com `prefetch=1`; pré-visualizações e processamentos na mesma fila (EV-09, EV-12, EV-13, EV-17)], [Eficiência de desempenho: capacidade (escalabilidade)], [Vários utilizadores a processar vídeo], [Rajada de 20 processamentos de vídeo, com pedidos de pré-visualização durante a rajada], [`video_queue` e `video_tool`], [Pico de carga, seguido de repouso], [A capacidade aumenta automaticamente sob carga e volta ao mínimo em repouso; a pré-visualização não espera pelos processamentos], [Tempo de expansão (s); tempo de contração (s); débito (processamentos/min); espera da pré-visualização até começar (s, p95); CPU e RAM dos contentores de vídeo em repouso],
    [QS-03], [Um serviço do caminho do vídeo que termina não volta sozinho; o nginx mantém o IP antigo (EV-16, EV-22)], [Fiabilidade: recuperabilidade; disponibilidade], [Infraestrutura (OOM, reinício de contentor)], [O processo do `api_gateway` termina inesperadamente], [`api_gateway`, nginx], [Operação normal], [O serviço volta a responder sem intervenção manual e o nginx volta a encaminhar], [Tempo até voltar a responder (s); n.º de pedidos falhados nesse intervalo],
    [QS-04], [O multer do gateway lê o corpo inteiro antes de verificar o token (EV-03)], [Segurança: resistência (ISO/IEC 25010:2023); autenticidade], [Cliente não autenticado ou abusivo], [Envia um vídeo grande sem token válido], [`api_gateway`], [Operação normal], [O pedido é recusado sem ler o corpo], [Bytes lidos antes da recusa; memória consumida pelo pedido (MB)],
  ),
)
]

#tab([Priorização dos cenários],
  tabela(
    colunas: (1.2cm, 1fr, 1fr, 1.8cm),
    [ID], [Importância para os stakeholders], [Dificuldade / risco técnico], [Prioridade],
    [QS-01], [Alta — o Premium não consegue usar o limite que paga (1 GB) e o OOM derruba o serviço para todos (EV-16)], [Média — mudança em quatro serviços, mas sem mudar a API nem o frontend além do progresso], [1],
    [QS-02], [Alta — com vários utilizadores a espera cresce linearmente; uma pré-visualização chega a 21 min (EV-17)], [Média — fila nova, serviço de escala e correções ao worker; risco de contenção de CPU (H-02)], [2],
    [QS-03], [Média — afeta todos, mas só depois de uma falha; QS-01 elimina a causa mais frequente], [Baixa — política `restart` e resolução dinâmica do nome no nginx], [3],
    [QS-04], [Média — abuso possível, mas exige conhecer a API], [Baixa — fica resolvido pela mesma alteração de QS-01 (token antes do corpo)], [4],
  ),
)

QS-01 e QS-02 são os mais importantes e ambos viáveis no tempo da fase; QS-03 e QS-04 são mais fáceis, mas de menor impacto, e QS-04 é coberto como efeito da solução de QS-01.

== Atributos de qualidade por ordem de prioridade

+ *Eficiência de desempenho* (utilização de recursos, capacidade, comportamento temporal) — QS-01 e QS-02: são as duas fragilidades com maior impacto medido (OOM e 21 min de espera).
+ *Fiabilidade* (recuperabilidade, disponibilidade) — QS-03: depende em parte de QS-01, que remove a causa do OOM.
+ *Segurança* (resistência) — QS-04: menor exposição e resolvido pela mesma tática de QS-01.

== Pré-requisitos e efeitos colaterais entre atributos

#tab([Pré-requisitos e efeitos colaterais entre atributos],
  tabela(
    colunas: (3.2cm, 3.2cm, 2.6cm, 1fr),
    [Atributo A], [Atributo B], [Efeito (pré-requisito, sinergia ou conflito)], [Razão / evidência],
    [Utilização de recursos (QS-01)], [Recuperabilidade / disponibilidade (QS-03)], [Pré-requisito], [Enquanto um vídeo de 1 GB derrubar o gateway, nenhuma política de reinício garante disponibilidade (EV-16).],
    [Utilização de recursos (QS-01)], [Segurança: resistência (QS-04)], [Sinergia], [Ler em stream depois do token impede que um pedido sem token ocupe memória (EV-03).],
    [Utilização de recursos: memória], [Utilização de recursos: disco], [Conflito], [O streaming troca RAM por ficheiros temporários e cache de página no `projects`.],
    [Capacidade (QS-02)], [Segurança], [Conflito], [Escalar contentores a partir de dentro da stack exige acesso à API do Docker (`docker.sock`).],
    [Capacidade (QS-02)], [Comportamento temporal (QS-02)], [Sinergia, com conflito no limite], [Mais réplicas reduzem a fila, mas sem quota de CPU disputam os mesmos núcleos e cada vídeo demora mais (H-02).],
    [Capacidade (QS-02)], [Manutenibilidade], [Conflito ligeiro], [Mais um serviço e mais uma fila para documentar e manter.],
  ),
)

== Recomendações de melhoria à solução atual

#tab([Recomendações de melhoria],
  tabela(
    colunas: (1fr, 3cm, 2.4cm, 1.6cm, 1.8cm),
    [Recomendação], [Atributo(s)], [Padrão a que se refere (global / vídeo)], [Esforço], [Risco de regressão],
    [R-1. Carregamento em _streaming_ em todos os saltos, com recusa antecipada pelo `Content-Length` e token verificado antes do corpo], [Utilização de recursos; comportamento temporal; segurança], [Global (cadeia de carregamento) aplicada ao vídeo], [Médio], [Médio],
    [R-2. Progresso do carregamento no frontend (`onUploadProgress`)], [Usabilidade: operabilidade], [Global], [Baixo], [Baixo],
    [R-3. Fila própria para pré-visualizações de vídeo, com worker dedicado], [Comportamento temporal], [Vídeo], [Baixo], [Baixo],
    [R-4. Réplicas do `video_tool` ajustadas à profundidade da fila, com quota de CPU], [Capacidade], [Vídeo, dentro do padrão global], [Médio], [Médio],
    [R-5. Heartbeat ativo e _graceful shutdown_ (SIGTERM sem ack) no worker de vídeo], [Fiabilidade: tolerância a falhas], [Vídeo], [Baixo], [Baixo],
    [R-6. Reinício automático dos serviços Node e resolução dinâmica do `api_gateway` no nginx], [Fiabilidade: recuperabilidade], [Global], [Baixo], [Baixo],
    [R-7. Ack manual nos workers de imagem], [Fiabilidade: tolerância a falhas], [Global (imagens)], [Baixo], [Médio],
  ),
)
