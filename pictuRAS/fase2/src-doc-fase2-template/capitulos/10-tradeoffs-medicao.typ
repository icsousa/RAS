#import "../template.typ": *

= Trade-offs, Medição e Preservação Funcional

#orientacao[
  *Origem:* Exercício 7, secção 5 do _template_ (e os riscos de preservação funcional do Bloco 2, secção 6).

  *Objetivo do capítulo:* mostrar que as decisões foram avaliadas além do atributo que melhoram (_trade-offs_), que a
  melhoria foi medida de forma comparável (antes e depois) e que o comportamento funcional foi preservado.

  A mesma medição é feita *antes e depois* do _refactoring_, no mesmo ambiente. *Não inventem valores* de _baseline_, alvo
  ou mínimo aceitável: fixam-se após a medição inicial. Guardem os _scripts_, os dados e o ambiente das medições para os
  reutilizar como _baseline_.
]

== Matriz de efeitos

#orientacao[
  Para cada decisão, indiquem se cada atributo *melhora* (↑), *degrada* (↓) ou fica *neutro* (=), e justifiquem. Incluam
  no mínimo quatro atributos, e entre eles a característica do outro cenário: uma melhoria num atributo costuma ter um
  custo noutro, e é isso que esta matriz deve revelar. Se uma decisão degradar um atributo, digam como a equipa vai
  gerir esse custo.
]

#paisagem[
#tab([Matriz de efeitos das decisões],
  tabela(
    colunas: (1.8cm, 2.6cm, 3.4cm, 2.4cm, 2.4cm, 3.6cm, 1fr),
    tamanho: 8.5pt,
    [Decisão], [Desempenho], [Disponibilidade / Fiabilidade], [Segurança], [Usabilidade], [Manutenibilidade / Testabilidade], [Justificação],
    [DA-1], [↑ memória; \= tempo; ↓ disco], [↑], [↑], [↑], [\= / ↑], [Memória constante e 1 GB deixa de provocar OOM (fiabilidade ↑); token verificado antes do corpo e recusa pelo `Content-Length` (segurança ↑); barra de progresso (usabilidade ↑). Custo: disco temporário e cache de página (≈ 1 GB por carregamento de 1 GB em curso); o tempo fica ao nível da base em _loopback_. `mediaUpload.js` concentra a lógica e tem testes (testabilidade ↑). Gestão do custo: temporários apagados no fim e em erro; medir o pico de disco fica como trabalho futuro.],
    [DA-2], [↑ capacidade e espera; ↓ CPU disponível], [↑], [↓], [↑], [↓ / ↑], [Elasticidade e fim do bloqueio na cabeça da fila; _heartbeat_ e SIGTERM sem _ack_ (fiabilidade ↑); pré-visualização mais rápida (usabilidade ↑). Custos: `docker.sock` montado no _autoscaler_ (segurança ↓); mais dois serviços e uma fila (manutenibilidade ↓), mas a regra de escala é uma função pura com testes (testabilidade ↑). Gestão: o _autoscaler_ só cria e remove réplicas do `video_tool`; um _proxy_ do _socket_ limitado às operações necessárias fica como trabalho futuro.],
  ),
)
]

== Interação entre DA-1 e DA-2

#tab([Interação entre as decisões],
  tabela(
    colunas: (2.2cm, 2.2cm, 4.4cm, 1fr),
    [Decisão A], [Decisão B], [Efeito (pré-requisito, sinergia ou conflito)], [Razão / evidência],
    [DA-1], [DA-2], [Sinergia no fluxo, conflito nos recursos do anfitrião], [A DA-1 permite que vídeos grandes entrem no sistema e a DA-2 dá-lhes capacidade de processamento; sem a DA-1 a DA-2 nunca receberia vídeos de 1 GB. Ambas usam o mesmo anfitrião: a DA-1 consome disco e I/O no `projects`, a DA-2 consome CPU com as réplicas. As medições foram feitas em separado, pelo que o efeito combinado num pico simultâneo não foi medido.],
  ),
)

== Plano de medição

#tab([Plano de medição],
  tabela(
    colunas: (1.6cm, 3.2cm, 3cm, 2.6cm, 2.4cm, 2.8cm),
    tamanho: 8pt,
    [Cenário], [Cenário de teste e carga], [Ambiente (máquina, recursos, versões)], [O que se regista], [Repetições e agregação], [Onde ficam os _scripts_ e os dados],
    [QS-01], [M1/M2: vídeos de 100 MB, 500 MB e 1 GB por `curl` em _loopback_, serviços reiniciados antes de cada repetição; M3: 1, 2, 4 e 8 em paralelo com 2 GB por serviço; M4: 300 MB com o perfil _free_; M5: 500 MB no _browser_], [Portátil da Tabela 3, mesmo dia (2026-11-18) para base e final, sem outras aplicações pesadas], [`memory.peak` − `memory.current` do _cgroup_ de cada contentor; tempo até ao 204; códigos HTTP; bytes enviados até à recusa; progresso visível], [5 repetições, mediana (M1, M2, M4); 1 execução (M3, M5)], [`medicoes/medir.py` (`upload`, `concorrencia`), `medicoes/docker-compose.medicoes.yaml`; dados em `medicoes/resultados/base/` e `final/` (`rnf01_*.json`)],
    [QS-02], [20 processamentos de um vídeo de 60 s 720p injetados de uma vez; 10 pré-visualizações, uma a cada 5 s; observação durante 300 s após a fila esvaziar], [Igual ao QS-01], [Profundidade das filas e consumidores (API de gestão do RabbitMQ, a cada 1 s); eventos `[video] msg=…` dos _workers_; decisões do _autoscaler_; `docker stats` em repouso], [1 execução; E4 em percentil 95], [`medicoes/medir.py elasticidade`; dados em `medicoes/resultados/*/rnf02_elasticidade.json`, `rnf02_linha_tempo.csv` e `final/rnf02_autoscaler.log`],
  ),
)

== Resultados das medições

#orientacao[
  Para cada requisito não funcional, apresentem os valores medidos *antes* (_baseline_) e *depois* do _refactoring_, com o
  mesmo método e nas mesmas condições (plano acima), e comparem-nos com o valor-alvo e o valor mínimo aceitável fixados no
  capítulo 6. Os dados brutos e os _scripts_ ficam no repositório entregue.

  Na análise, sejam críticos: o que melhorou, o que não foi atingido e porquê, que outros atributos foram afetados
  (confirmando ou não a matriz de efeitos) e que ameaças à validade das medições existem.
]

#tab([Resultados das medições],
  tabela(
    colunas: (1.6cm, 1fr, 2cm, 2cm, 2cm, 2cm, 2cm),
    tamanho: 8.5pt,
    [Cenário], [Medição (o que se mede, unidade)], [Antes (_baseline_)], [Depois], [Valor-alvo], [Mínimo aceitável], [Atingido?],
    [QS-01], [M1 RAM adicional, 100 MB (MB)], [898], [408], [≤ 300, sem crescer], [≤ 1 GB p/ 1 GB], [ver M1 1 GB],
    [QS-01], [M1 RAM adicional, 500 MB (MB)], [4 212], [1 050], [idem], [idem], [ver M1 1 GB],
    [QS-01], [M1 RAM adicional, 1 GB, `memory.peak` (MB)], [0/5 com sucesso; ≈ 8 GB até ao OOM], [2 253 (5/5)], [≤ 300], [≤ 1 024], [Não (inclui cache de página)],
    [QS-01], [M1 memória dos processos (`anon`), 1 GB (MB)], [—], [≈ 190], [≤ 300], [≤ 1 024], [Alvo],
    [QS-01], [M2 tempo ponta a ponta, 100 MB (s)], [3,0], [3,4], [≤ base − 30 %], [≤ base], [Não (+12 %)],
    [QS-01], [M2 tempo ponta a ponta, 500 MB (s)], [14,2], [13,5], [idem], [idem], [Mínimo (−5 %)],
    [QS-01], [M2 tempo ponta a ponta, 1 GB (s)], [falha (502/504)], [25,5], [—], [—], [Passa a funcionar],
    [QS-01], [M3 carregamentos de 1 GB em simultâneo (n.º)], [0], [4], [4], [2], [Alvo],
    [QS-01], [M4 bytes lidos antes da recusa (MB)], [300 (400 ao fim de 5,1 s)], [10,8 (400 ao fim de 0,09 s)], [≤ 101], [≤ 200], [Alvo],
    [QS-01], [M5 progresso visível], [Não (só _spinner_)], [Sim (percentagem)], [Sim, ≥ 1/s], [Sim], [Mínimo (atualizações/s não medidas)],
    [QS-02], [E1 expansão (s)], [Não escala], [16,5], [≤ 30], [≤ 60], [Alvo],
    [QS-02], [E2 contração (s)], [Não aplicável], [70,4], [≤ 120], [≤ 300], [Alvo],
    [QS-02], [E3 débito (processamentos/min)], [0,95], [1,78 (1,87 ×)], [≥ 2,85], [≥ 1,90], [Não],
    [QS-02], [E4 espera da pré-visualização, p95 (s)], [1 258], [30,4], [≤ 5], [≤ 10], [Não (−97,6 %)],
    [QS-02], [E5 recursos em repouso], [1 contentor, 0 % CPU, 473 MiB], [3 contentores, 0 % CPU, ≈ 113 MiB], [Igual à base], [≤ base + 1 _worker_], [Mínimo],
  ),
)

*Análise dos resultados* (por requisito não funcional):

*CAND-1 (QS-01).*

- *Base, 1 GB.* As 5 repetições falharam (4 × 502, 1 × 504) por falta de memória no anfitrião (EV-16). A memória extra cresce ≈ 8,5 vezes o tamanho do ficheiro (gateway 3,9 GB, `projects` 2,3 GB e `img_storage` 2,0 GB para 1 GB). É exatamente a fragilidade que motivou o QS-01.
- *M1 e cache de página.* O gateway ficou constante (45–68 MB). No `projects` e no `img_storage` o `memory.peak` ainda cresce ≈ 1,1 GB por GB de ficheiro, mas não é memória dos processos: é a cache de página do ficheiro temporário, que o _cgroup_ contabiliza e o _kernel_ pode libertar. Numa medição complementar (`resultados/final/rnf01_m1_anon.json`) separámos `anon` de `file` no `memory.stat`: para 1 GB, `anon` subiu 25 MB no gateway, 40 MB no `projects` e 125 MB no `img_storage` (≈ 190 MB), e `file` ≈ 1 GB em cada um dos dois últimos. A M3 confirma que esta cache não impede o funcionamento. Pela métrica original (`memory.peak`) o alvo não é atingido; pela memória dos processos, é.
- *M2.* Em _loopback_ não há rede lenta a esconder, e o _streaming_ acrescenta escrita e leitura em disco no `projects`. O tempo fica ao nível da base e não atinge a redução de 30 %; a melhoria real de M2 é que 1 GB passa a terminar. A medição exploratória (EV-18) previa um ganho por salto que, ponta a ponta, o disco anula.
- *M3 com 8 em paralelo.* Os 8 carregamentos devolveram 504 ao fim de ≈ 137 s, *sem* falta de memória. O nginx regista `upstream timed out … while reading response header`: o `proxy_read_timeout` por omissão (60 s) passa a ser o limite, e não a memória. Confirma o custo previsto na matriz de efeitos.
- *M4.* O `projects` recusa pelo `Content-Length` antes de ler o ficheiro: o `curl` só chegou a enviar 10,8 MB que já estavam em trânsito.

*CAND-2 (QS-02).*

- *E1 e E2.* O _autoscaler_ criou as 3 réplicas extra ≈ 3 s depois de ver 19 mensagens prontas; os 16,5 s incluem injetar os trabalhos e arrancar os contentores. A contração (70,4 s) é dominada pelos 60 s de espera configurados mais o intervalo de leitura de 5 s (`final/rnf02_autoscaler.log`, `rnf02_replicas_video_tool.txt`).
- *E3.* Os 20 trabalhos foram processados em lotes de 4 (fila 16 → 12 → 8 → 4 → 0), mas cada vídeo demorou cerca do dobro (≈ 125 s por lote de 4, contra ≈ 63 s por vídeo na base). O `libx264` já usa vários núcleos e 4 réplicas sem quota disputam os 8 _threads_: confirma a H-02. O débito subiu 1,87 ×, ligeiramente abaixo do mínimo de 2 ×.
- *E4.* A pré-visualização deixou de esperar pelos processamentos (de 21 min para segundos): a primeira começou em 0,2 s. Mas há um só _worker_ de pré-visualização e, com o CPU saturado pelas réplicas, cada pré-visualização demorou ≈ 9 s; como os pedidos chegam a cada 5 s, a fila cresce. As esperas das 10 pré-visualizações, por ordem de chegada, foram 0,2; 1,5; 5,6; 8,5; 11,3; 13,8; 17,7; 22,4; 26,3 e 30,4 s (`resultados/final/rnf02_elasticidade.json`). O problema passou a ser a acumulação na fila de um único _worker_.
- *E5.* Em repouso há mais 2 contentores do que na base, mas a memória total desceu de 473 MiB para ≈ 113 MiB, sobretudo porque o _worker_ da base tinha acabado de processar 30 trabalhos; não deve ser lida como poupança da refatoração.
- *Para cumprir E3 e E4* (não aplicado, para não alterar o método depois de medir): quota de CPU por réplica com núcleos reservados à pré-visualização (TAT-10); escalar também a `video_preview_queue`; medir numa máquina com mais núcleos.

*Efeitos noutros atributos.* Confirmam a matriz de efeitos: menos memória à custa de disco (DA-1), limite de concorrência deslocado para o _timeout_ do nginx (DA-1), contenção de CPU entre réplicas e pré-visualização (DA-2). Encontrámos também uma fragilidade *pré-existente*, não corrigida: o nginx resolve o nome do gateway só no arranque (EV-21, QS-03).

*Ameaças à validade.*

- Um único portátil, sem _swap_; os valores absolutos dependem deste _hardware_.
- 5 repetições por tamanho em M1/M2, mas uma única execução de M3 e da elasticidade.
- A M1 por `memory.peak` inclui a cache de página; a medição da memória dos processos é complementar e teve uma só repetição.
- A M5 foi avaliada qualitativamente; não medimos as atualizações por segundo.
- Correções aos _scripts_ durante as medições, todas em _commits_ próprios e aplicadas por igual à base e à final: `45e4c87` (reiniciar também o nginx, por causa da EV-21), `78843bd` (gravar M1/M2 antes da M4 e reiniciar os serviços, porque a falta de memória da base perdia resultados) e `6e553e9` (recolher os _logs_ das réplicas durante o ensaio, brilho diferente em cada pré-visualização para não acertar na cache, identificar pré-visualizações pelo id da mensagem). A primeira medição final da elasticidade foi descartada e repetida; na base só o E3 foi recalculado a partir dos dados brutos, contando apenas processamentos completos (0,95/min em vez de 1,38/min; `base/rnf02_e3_recalculado.json`).

== Preservação funcional

#tab([Preservação funcional e testes de regressão],
  tabela(
    colunas: (2.4cm, 3.8cm, 2.8cm, 3.2cm, 1fr),
    tamanho: 8.5pt,
    [Zona alterada], [Testes de regressão existentes (`Tools/video/tests`, `projects/tests`, …)], [Lacunas de teste], [Testes acrescentados], [Resultado (imagem e vídeo)],
    [DA-1: carregamento (gateway, `projects`, `img_storage`, _frontend_)], [`projects/tests` (processamento em lote, _pipeline_ de vídeo, extração de fotogramas)], [Não havia testes de carregamento, de limites de perfil nem do _hash_], [9 testes em `projects/tests/rnf01-upload.test.js`: limites do perfil e mensagem de recusa iguais aos da base, recusa pelo tamanho declarado, `ffprobe` e `og_sha256` iguais aos calculados sobre o _buffer_, envio em _stream_, ficheiro temporário removido, leitura interrompida ao passar o limite; testes manuais TM-01, TM-02, TM-08], [`node --test` no `projects`: 20 passam, 0 falham; TM-01 e TM-08 passam; TM-02 passa depois de `aba322d`],
    [DA-2: filas, _worker_ e _autoscaler_], [`Tools/video/tests` (efeitos, legendas, extração de fotogramas)], [Sem testes da escolha de fila, do comportamento do _worker_ ao terminar, nem da regra de escala], [3 testes em `projects/tests/rnf02-queues.test.js` (pré-visualização na fila nova); 8 testes da regra de escala (`Tools/autoscaler/tests`); 5 testes do _worker_ (`test_worker_rnf02.py`: _heartbeat_, SIGTERM sem _ack_); TM-03, TM-06, TM-07], [`pytest -q Tools/video/tests`: 79 passam; _autoscaler_: 8 OK; TM-03, TM-06 e TM-07 passam],
    [Imagens (não alteradas, mas partilham o `projects`)], [`projects/tests`], [—], [TM-04 (brilho, rotação e _border_ em imagens) e TM-05 (partilha _View only_)], [Passam],
  ),
)

#tab([Riscos para a preservação funcional e mitigação],
  tabela(
    colunas: (3.4cm, 3.2cm, 4cm, 3.2cm),
    tamanho: 8.5pt,
    [Risco], [Funcionalidade afetada (imagem / vídeo)], [Mitigação], [Teste de regressão],
    [Mudança das mensagens de erro ou dos códigos HTTP ao recusar um carregamento], [Vídeo e imagem (carregamento)], [Mensagens e códigos copiados da base; recusa no mesmo serviço (`projects`)], [`rnf01-upload.test.js`; TM-08 (`too_long_90s.mp4`, `corrupted.mp4`)],
    [_Hash_ diferente ao calcular em _stream_, quebrando a deteção de duplicados e a cache], [Vídeo], [_Hash_ incremental sobre o mesmo conteúdo], [`rnf01-upload.test.js` (_hash_ igual ao do _buffer_)],
    [Ficheiros temporários deixados em disco após erro ou aborto], [Vídeo], [Limpeza no fim e nos caminhos de erro], [`rnf01-upload.test.js` (ficheiro temporário removido)],
    [Pré-visualização perdida ou duplicada na fila nova], [Vídeo], [Mesmo formato de mensagem; só muda o nome da fila], [`rnf02-queues.test.js`; TM-03, TM-06],
    [Trabalho perdido quando o _autoscaler_ remove uma réplica a meio], [Vídeo], [Contração só com a fila vazia há 60 s; SIGTERM sem _ack_; `stop_grace_period: 30s`], [`test_worker_rnf02.py`; testes da regra de escala],
    [Regressão nas imagens por alterações no `projects`], [Imagem], [Alterações limitadas ao caminho do vídeo e à escolha da fila], [`projects/tests`; TM-04, TM-05],
  ),
)
