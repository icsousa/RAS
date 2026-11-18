// Fase 2 — Relatório de refatoração para dois RNF (PL3-G7)
// Compilar: typst compile relatorio-fase2.typ
// Rascunho escrito com apoio de IA (Claude) e revisto pelo grupo (PL3-G7).

#set document(title: "Fase 2 — Refatoração para requisitos não funcionais", author: "Grupo PL3-G7")
#set page(paper: "a4", margin: (x: 2.2cm, y: 2.4cm), numbering: "1")
#set text(lang: "pt", region: "pt", size: 10.5pt)
#set par(justify: true)
#set heading(numbering: "1.1")
#show heading.where(level: 1): set block(above: 1.6em, below: 0.9em)
#show raw.where(block: false): box.with(fill: luma(240), inset: (x: 2pt), outset: (y: 2pt), radius: 2pt)
#show table: set text(size: 9pt)
#show table: set par(justify: false)
#show table.cell.where(y: 0): strong

#let tabela(cols, ..cells) = table(
  columns: cols,
  stroke: 0.5pt + luma(180),
  fill: (_, y) => if y == 0 { luma(230) },
  inset: 5pt,
  align: left + top,
  ..cells,
)

// Pontos que só o grupo pode confirmar; remover antes da entrega.
#let pendente(body) = box(fill: rgb("#FFF2CC"), inset: (x: 3pt, y: 1pt), radius: 2pt)[*A completar pelo grupo:* #body]

#let ok = text(fill: rgb("#2E7D32"), weight: "bold")[cumpre o alvo]
#let okmin = text(fill: rgb("#9A6700"), weight: "bold")[cumpre o mínimo]
#let falha = text(fill: rgb("#C62828"), weight: "bold")[abaixo do mínimo]

#align(center)[
  #text(size: 18pt, weight: "bold")[Fase 2 — Refatoração para requisitos não funcionais]
  #v(0.3em)
  Grupo PL3-G7 · Requisitos e Arquiteturas de Software 2026/27 · 20 de novembro de 2026
]

#v(1em)

= Resumo

Escolhemos dois requisitos não funcionais (RNF) da característica *eficiência de desempenho* da ISO/IEC 25010. Ambos partem de fragilidades do suporte a vídeo da solução de base (PL1-G4):

#tabela(
  (1.3fr, 1.3fr, 2.4fr),
  [RNF], [Subcaracterística ISO/IEC 25010], [Resultado em uma frase],
  [RNF-01 Carregamento de ficheiros grandes], [Utilização de recursos e comportamento temporal], [Um vídeo de 1 GB passou de *falhar sempre* (falta de memória no anfitrião) a carregar com ≈ 190 MB de memória dos processos; 4 carregamentos de 1 GB em paralelo passam com 2 GB por serviço.],
  [RNF-02 Elasticidade do processamento de vídeo], [Capacidade], [O processamento passou de 1 worker fixo a 1–4 réplicas automáticas (expansão em 16,5 s, contração em 70,4 s). A espera da pré-visualização desceu de 1 258 s para 30,4 s (p95), mas E3 e E4 ficam abaixo do mínimo por saturação de CPU.],
)

O ciclo seguido foi o das diretrizes: requisito → quantificação → medição de base → refatoração → medição final. O diagnóstico detalhado, as medições exploratórias e as alternativas estão no documento de análise (`analise-rnf.typ`); este relatório resume-os e acrescenta as medições oficiais, a refatoração e a análise crítica.

= Ponto de partida, ambiente e método

== Commits

#tabela(
  (1.6fr, 1.4fr, 2.4fr),
  [Papel], [Commit], [Notas],
  [Ponto de partida oficial], [`052310226c51fa57a17101c7bd1ad795674aac95`], [Repositório oficial `picturas-um/picturas-27` (solução PL1-G4 integrada).],
  [Medição de base], [`406c8e0`], [Repositório do grupo, branch `fase2/refatoracao`: código original + scripts de medição.],
  [Medição final], [`aba322d`], [Patches de refatoração (`5b2af25`, `3b8a8bd`) + correção do progresso na criação de projeto.],
  [Correções aos scripts], [`45e4c87`, `78843bd`, `6e553e9`], [Descritas na secção 6; aplicam-se por igual à base e à final.],
)

== Ambiente de medição

Base e final foram medidas no mesmo portátil, com a mesma configuração e no mesmo dia (18 de novembro de 2026), sem outras aplicações pesadas abertas.

#tabela(
  (1fr, 3fr),
  [Componente], [Valor],
  [Portátil], [ASUS VivoBook X515JA],
  [CPU], [Intel Core i7-1065G7 (4 núcleos, 8 threads)],
  [RAM], [12 GB (11 GiB utilizáveis), *sem swap*],
  [Sistema operativo], [Manjaro Linux, kernel 7.2.9],
  [Docker], [Docker Engine 29.8.2 nativo (não Docker Desktop), cgroup v2, Docker Compose 5.6.0; o Docker vê os 8 CPUs e toda a RAM],
)

O registo completo está em `medicoes/resultados/base/ambiente.txt`.

== Instrumentos

- `medicoes/medir.py` (só biblioteca padrão do Python, mais `docker`, `curl` e `ffmpeg`) gera os vídeos de teste e corre os ensaios contra a stack real em Docker. Os resultados ficam em JSON/CSV em `medicoes/resultados/base/` e `medicoes/resultados/final/`.
- A memória (M1) é lida do cgroup de cada contentor (`memory.peak` menos `memory.current` em repouso, depois de reiniciar o serviço). Foi sempre esta a fonte; o fallback por `docker stats` nunca foi usado.
- A M3 usa o override `medicoes/docker-compose.medicoes.yaml`, que limita a 2 GB o `api_gateway`, o `projects` e o `img_storage`.
- A elasticidade lê a API de gestão do RabbitMQ a cada segundo e os logs dos workers (`[video] msg=…`).
- A M5 é manual, no browser.

As instruções para repetir as medições estão em `medicoes/README.md`.

= RNF-01 — Carregamento de ficheiros grandes

== Diagnóstico

Na base, um vídeo atravessa quatro saltos e cada um espera pelo ficheiro inteiro antes de o passar ao seguinte:

- o nginx guarda o pedido em disco temporário;
- o `apiGateway`, o `projects` e o `imageStorageService` usam `multer.memoryStorage()` e fazem cópias adicionais (`FormData`, ficheiro para o `ffprobe`, hash sobre o buffer).

O limite do perfil só é verificado depois de o ficheiro estar todo em memória, e o multer do gateway corre antes da verificação do token. O frontend não mostra progresso. A análise (secção 2 de `analise-rnf.typ`) tem as referências ao código e a medição exploratória: cerca de 3 GB de RAM por salto para 1 GB.

*Impacto para os stakeholders.* Um utilizador Premium não consegue carregar o vídeo de 1 GB que o seu plano permite; o serviço cai para todos os utilizadores; e quem carrega um vídeo grande não sabe se o carregamento está a avançar.

== Quantificação

*Enunciado.* O carregamento de um vídeo deve usar memória constante, independente do tamanho do ficheiro. O carregamento de um vídeo Premium de 1 GB não pode levar nenhum serviço a ficar sem memória. O utilizador deve ver o progresso do carregamento.

#tabela(
  (1.4fr, 1.6fr, 2fr, 1fr, 1fr),
  [Métrica], [Escala], [Método], [Alvo], [Mínimo],
  [M1 Pico de RAM adicional], [MB acima do repouso, soma dos 3 serviços], [100 MB, 500 MB e 1 GB, 5 repetições, mediana; serviços reiniciados antes de cada uma], [≤ 300 MB, sem crescer com o tamanho], [≤ 1 GB para 1 GB],
  [M2 Tempo ponta a ponta], [s, do POST até ao 204], [`curl` em loopback, 5 repetições], [≤ base − 30 %], [≤ base],
  [M3 Carregamentos de 1 GB em simultâneo], [Número que termina com 204], [1, 2, 4 e 8 em paralelo; 2 GB por serviço], [4], [2],
  [M4 Rejeição acima do limite], [Bytes lidos antes do erro], [300 MB com perfil free (limite 100 MB)], [≤ limite + 1 MB], [≤ 2 × limite],
  [M5 Progresso visível], [Sim/Não], [Teste manual no browser, vídeo de 500 MB], [Sim, ≥ 1 atualização/s], [Sim],
)

*Origem dos valores.* O limite de 1 GB vem de `VIDEO_PREMIUM_MAX_SIZE_MB: 1024`. O alvo de M1 vem da medição exploratória (≈ 90 MB por salto em streaming × 3 saltos). #pendente[justificar o alvo de M3 = 4 (por exemplo, pico esperado de utilizadores Premium a carregar ao mesmo tempo).]

== Decisões arquiteturais e refatoração

Foram avaliadas três alternativas (secção 3 da análise): *A1* streaming em todos os saltos, *A2* carregamento direto para o S3 com URL pré-assinado, e *A3* carregamento por partes ao estilo tus. Escolhemos a *A1*:

- mantém a API e o contrato com o frontend;
- a mudança fica localizada nos serviços envolvidos;
- garante memória constante.

A A2 obrigaria a expor o S3 e a validar só depois do carregamento. A A3 aproximava-se de uma funcionalidade nova (retomar carregamentos).

#tabela(
  (1fr, 3.2fr),
  [Salto], [Alteração (commit `5b2af25`)],
  [nginx], [`proxy_request_buffering off` e `proxy_http_version 1.1` no bloco `/api-gateway/`: o corpo passa à medida que chega.],
  [apiGateway], [Na rota de vídeo, o pedido é enviado por pipe ao `projects`, sem multer. O token é verificado *antes* de ler qualquer byte do corpo.],
  [projects], [Novo `utils/mediaUpload.js`: recusa pelo `Content-Length` quando o tamanho declarado só pode exceder o limite do perfil; caso contrário grava em ficheiro temporário (`multer.diskStorage`) com `limits.fileSize`, que interrompe a leitura ao passar o limite. O `ffprobe` e o hash correm sobre o ficheiro; o envio ao armazenamento é um stream. O ficheiro temporário é apagado no fim e em caso de erro. As mensagens de erro e os códigos HTTP mantêm-se.],
  [imageStorageService], [Recebe em stream e envia ao SeaweedFS com `s3.upload` em multipart.],
  [frontend], [`onUploadProgress` do axios e barra "Uploading N %" / "Processing…" no diálogo Import. O commit `aba322d` acrescentou a mesma barra à criação de projeto com media, que o patch inicial não cobria (detetado no teste manual).],
)

== Medição de base e final

#tabela(
  (1.6fr, 1.4fr, 1.6fr, 1.2fr, 1.2fr),
  [Métrica], [Base], [Final], [Alvo / mínimo], [Avaliação],
  [M1, 100 MB], [898 MB], [408 MB], [], [],
  [M1, 500 MB], [4 212 MB], [1 050 MB], [], [],
  [M1, 1 GB (`memory.peak`)], [0/5 com sucesso; ≈ 8 GB até ao OOM], [2 253 MB (5/5)], [≤ 300 MB / ≤ 1 GB], [ver nota abaixo],
  [M1, 1 GB (memória dos processos)], [—], [*≈ 190 MB*], [≤ 300 MB / ≤ 1 GB], [#ok],
  [M2, 100 MB], [3,0 s], [3,4 s], [≤ base − 30 % / ≤ base], [#falha (+12 %)],
  [M2, 500 MB], [14,2 s], [13,5 s], [≤ base − 30 % / ≤ base], [#okmin (−5 %)],
  [M2, 1 GB], [falha (502/504)], [25,5 s], [], [passa a funcionar],
  [M3], [0], [*4*], [4 / 2], [#ok],
  [M4], [300 MB (400 ao fim de 5,1 s)], [*10,8 MB* (400 ao fim de 0,09 s)], [≤ 101 MB / ≤ 200 MB], [#ok],
  [M5], [Não (só um spinner)], [Sim (barra com percentagem)], [Sim], [#ok (atualizações/s não medidas)],
)

*Leitura dos resultados.*

- *Base, 1 GB.* As 5 repetições falharam (4× 502, 1× 504). O `journalctl` regista um *OOM global* do anfitrião: o kernel mata o `node` do `api_gateway`, que tinha cerca de 3 GB. Depois disso o `nodemon` não relança o processo e o gateway fica em baixo até ser reiniciado. É exatamente a fragilidade que motivou o RNF-01. A memória extra cresce ≈ 8,5 vezes o tamanho do ficheiro (gateway 3,9 GB, projects 2,3 GB e storage 2,0 GB para 1 GB).
- *M1 final e cache de página.* O gateway ficou constante (45–68 MB). No `projects` e no `img_storage` o `memory.peak` ainda cresce ≈ 1,1 GB por GB de ficheiro, mas não é memória dos processos: é a cache de página do ficheiro temporário, que o cgroup contabiliza e o kernel pode libertar. Numa medição complementar (`resultados/final/rnf01_m1_anon.json`) separámos `anon` (memória dos processos) de `file` (cache) no `memory.stat`: para 1 GB, `anon` subiu 25 MB no gateway, 40 MB no projects e 125 MB no storage (≈ 190 MB no total), e `file` ≈ 1 GB em cada um dos dois últimos. A M3 confirma que esta cache não impede o funcionamento: 4 carregamentos de 1 GB passam com 2 GB por serviço. Esta distinção não estava prevista no método da análise; fica registada como limitação do instrumento.
- *M2.* Em loopback não há rede lenta a esconder; o streaming acrescenta escrita e leitura em disco no `projects`, por isso o tempo fica ao nível da base (+12 % a 100 MB, −5 % a 500 MB) e não atinge a redução de 30 %. A melhoria real de M2 é que 1 GB passa a terminar.
- *M3 com 8 em paralelo.* Os 8 carregamentos devolveram 504 ao fim de ≈ 137 s, *sem* OOM. O nginx regista `upstream timed out … while reading response header`: o bloco `/api-gateway/` usa o `proxy_read_timeout` por omissão (60 s) e, com 8 GB a chegar ao mesmo tempo, o `projects` demora mais do que isso a responder depois de receber o corpo (`ffprobe`, hash e envio ao S3). O limite passou a ser o tempo, não a memória.
- *M4.* O `projects` recusa pelo `Content-Length` antes de ler o ficheiro: o `curl` só chegou a enviar 10,8 MB que já estavam em trânsito.

= RNF-02 — Elasticidade do processamento de vídeo

== Diagnóstico

Na base há um único `video_tool`, com `prefetch_count=1`, a consumir a `video_queue`. As pré-visualizações (3 s de vídeo) e os processamentos completos partilham essa fila, por isso uma pré-visualização espera por todos os vídeos que estão à frente. O worker usa `heartbeat=0`, por isso o broker não deteta um worker pendurado. A análise (secção 4 de `analise-rnf.typ`) tem as referências ao código e a medição exploratória.

*Impacto para os stakeholders.* Com vários utilizadores a processar vídeo, o tempo de espera cresce linearmente e uma simples pré-visualização pode demorar dezenas de minutos. Em repouso, a capacidade é a mesma que em carga.

== Quantificação

*Enunciado.* O processamento de vídeo deve ajustar automaticamente o número de workers à carga, entre um mínimo e um máximo configuráveis. Uma pré-visualização não deve esperar por processamentos completos.

#tabela(
  (1.4fr, 1.5fr, 2.1fr, 1fr, 1fr),
  [Métrica], [Escala], [Método], [Alvo], [Mínimo],
  [E1 Expansão], [s até haver mais de um consumidor], [20 processamentos injetados de uma vez (vídeo de 60 s 720p, brilho 1,2)], [≤ 30 s], [≤ 60 s],
  [E2 Contração], [s desde a fila esvaziar até ao mínimo], [O mesmo ensaio, observado 300 s], [≤ 120 s], [≤ 300 s],
  [E3 Débito], [Processamentos concluídos por minuto], [20 processamentos], [≥ 3 × base], [≥ 2 × base],
  [E4 Espera da pré-visualização], [s até começar, p95], [10 pré-visualizações, uma a cada 5 s, durante o E3], [≤ 5 s], [≤ 10 s],
  [E5 Recursos em repouso], [CPU e RAM dos contentores de vídeo], [`docker stats` 5 min depois do fim], [Igual à base], [≤ base + 1 worker],
)

#pendente[confirmar no relatório da PL1-G4 a origem do alvo de 5 s em E4.]

== Decisões arquiteturais e refatoração

Das quatro alternativas da análise (*B1* réplicas fixas, *B2* autoscaler próprio, *B3* Kubernetes com HPA/KEDA, *B4* filas separadas), escolhemos *B2 + B4*:

- a B1 é escalabilidade, não elasticidade;
- a B3 obrigaria a migrar todo o deploy e seria difícil de reproduzir pelos docentes.

#tabela(
  (1fr, 3.2fr),
  [Componente], [Alteração (commit `3b8a8bd`)],
  [Filas], [Nova `video_preview_queue` em `rabbitMQ/definitions.json`; o `projects` (`utils/project_msg.js`) publica as pré-visualizações de vídeo nela e os processamentos na `video_queue`.],
  [`video_preview_tool`], [Novo serviço com a mesma imagem do worker, a consumir só a fila de pré-visualizações.],
  [`video_autoscaler`], [Novo serviço (`Tools/autoscaler`). A cada 5 s lê `ready` e `unacked` da `video_queue` na API de gestão do RabbitMQ e cria ou remove réplicas do `video_tool` pela API do Docker. A regra (`scaling_rule.py`, função pura com testes unitários) é: expandir de imediato até uma réplica por trabalho, entre 1 e 4; contrair para o mínimo só depois de 60 s com a fila completamente vazia, para nunca remover réplicas ocupadas.],
  [Worker (`video.py`)], [Processamento numa thread, com o heartbeat da ligação ativo; ao receber SIGTERM, termina sem fazer ack, para a mensagem voltar à fila; `stop_grace_period: 30s`.],
)

*Desvio face à análise.* A análise previa réplicas "com limite de CPU e memória" e o método de E3 falava em "4 réplicas com 1 CPU cada". O `docker-compose.yaml` final não define `cpus` nem `mem_limit` para o `video_tool`; as réplicas partilham os 8 CPUs do portátil. Isto é relevante para E3 e E4 (abaixo).

== Medição de base e final

#tabela(
  (1.4fr, 1.6fr, 1.8fr, 1.1fr, 1.2fr),
  [Métrica], [Base], [Final], [Alvo / mínimo], [Avaliação],
  [E1], [Não escala (1 worker)], [*16,5 s*], [≤ 30 s / ≤ 60 s], [#ok],
  [E2], [Não aplicável], [*70,4 s*], [≤ 120 s / ≤ 300 s], [#ok],
  [E3], [0,95 /min], [1,78 /min (1,87 ×)], [≥ 2,85 / ≥ 1,90 /min], [#falha],
  [E4 (p95)], [1 258 s], [30,4 s], [≤ 5 s / ≤ 10 s], [#falha (−97,6 %)],
  [E5], [1 contentor, 0 % CPU, 473 MiB], [3 contentores (worker, worker de pré-visualização, autoscaler), 0 % CPU, ≈ 113 MiB], [≤ base + 1 worker], [#okmin],
)

*Leitura dos resultados.*

- *E1 e E2.* O autoscaler criou as 3 réplicas extra em cerca de 3 s, logo na primeira leitura em que viu 19 mensagens prontas; o E1 (16,5 s) inclui o tempo de injetar os trabalhos e de arrancar os contentores. A contração (70,4 s) é dominada pelos 60 s de espera configurados mais o intervalo de leitura de 5 s. O registo está em `resultados/final/rnf02_autoscaler.log` e `rnf02_replicas_video_tool.txt`.
- *E3.* Os 20 trabalhos foram processados em lotes de 4 (a fila desce 16 → 12 → 8 → 4 → 0), mas cada vídeo demorou cerca do dobro do que com 1 worker (≈ 125 s por lote de 4, contra ≈ 63 s por vídeo na base). O `libx264` já usa vários núcleos, e 4 réplicas sem limite de CPU disputam os mesmos 8 threads do portátil. O débito subiu 1,87 ×, ligeiramente abaixo do mínimo de 2 ×. A medição exploratória da análise já antecipava este efeito.
- *E4.* A pré-visualização deixou de esperar pelos processamentos (de 21 min para segundos), mas há só um worker de pré-visualização e, com o CPU saturado pelas 4 réplicas, cada pré-visualização demorou ≈ 9 s. Como os pedidos chegam a cada 5 s, a fila de pré-visualizações cresce: as esperas foram 0,2; 1,5; 5,6; 8,5; 11,3; 13,8; 17,7; 22,4; 26,3 e 30,4 s. A primeira pré-visualização começou em 0,2 s: o problema é a acumulação na fila de um único worker, não a espera atrás dos processamentos.
- *E5.* Em repouso há mais 2 contentores do que na base (o worker de pré-visualização e o autoscaler), mas a memória total desceu de 473 MiB para ≈ 113 MiB. A diferença deve-se sobretudo a o worker da base ter acabado de processar 30 trabalhos; não deve ser lida como poupança da refatoração.
- *E3 da base recalculado.* O resumo original da base contava também as pré-visualizações (1,38 /min), porque a linha `ok` do worker não indica se é uma pré-visualização. Recalculámos a partir dos eventos gravados, com o mesmo critério da final (prefixo `preview-` no id da mensagem): 20 processamentos em 1 266 s, 0,95 /min (`resultados/base/rnf02_e3_recalculado.json`).

*O que fazer para cumprir E3 e E4* (não aplicado, por estar fora do tempo e para não alterar o método depois da medição):

- limitar o CPU de cada réplica (`cpus`), reservando núcleos para o worker de pré-visualização;
- escalar também a `video_preview_queue`, com o mesmo autoscaler;
- medir numa máquina com mais núcleos: o débito máximo está limitado pelo CPU do anfitrião, não pela arquitetura.

= Efeitos colaterais noutros requisitos

#tabela(
  (1.2fr, 3.4fr),
  [Requisito], [Efeito],
  [Segurança (+)], [O gateway passa a verificar o token antes de ler o corpo; um pedido sem token deixa de obrigar a ler 1 GB. A recusa pelo `Content-Length` reduz o custo de pedidos abusivos.],
  [Segurança (−)], [O `video_autoscaler` monta `/var/run/docker.sock`, o que lhe dá controlo total sobre o Docker do anfitrião. Mitigações possíveis: um proxy do socket só com as operações necessárias, ou correr o autoscaler numa rede isolada. Não foram aplicadas.],
  [Utilização de disco], [O streaming troca RAM por disco temporário: ≈ 1 GB por carregamento de 1 GB em curso no `projects` (ficheiro temporário), mais a cache de página correspondente. Não medimos o pico de disco; com M3 = 4 estimamos ≈ 4 GB em simultâneo.],
  [Fiabilidade], [Os ficheiros temporários são apagados no fim e em caso de erro. Uma réplica removida a meio devolve a mensagem à fila (testado em `test_worker_rnf02.py`). Encontrámos uma fragilidade *pré-existente*: o nginx resolve o nome `api_gateway` só no arranque; se o gateway reiniciar e mudar de IP, o nginx responde 502 até ser reiniciado. A refatoração não a corrigiu.],
  [Comportamento temporal], [O `proxy_read_timeout` de 60 s do nginx passou a ser o limite de concorrência no carregamento (M3 com 8 em paralelo). Na base o limite era a memória.],
  [Manutenibilidade], [Mais dois serviços (`video_preview_tool`, `video_autoscaler`) e uma fila nova para documentar e manter. A regra de escala é uma função pura com testes, o que facilita alterá-la.],
  [Capacidade de CPU], [As réplicas extra disputam CPU com o resto da stack, incluindo o worker de pré-visualização (secção 4.4).],
)

= Preservação funcional

#tabela(
  (1.4fr, 1.6fr, 1.2fr),
  [Conjunto], [Comando], [Resultado],
  [`projects` (inclui 9 testes novos de RNF-01 e 3 de RNF-02)], [`docker compose exec projects node --test`], [20 pass, 0 fail],
  [Autoscaler (regra de escala)], [`python3 -m unittest discover -s Tools/autoscaler/tests`], [8 OK],
  [Worker de vídeo (inclui 5 testes novos do worker)], [`pytest -q Tools/video/tests`], [79 passed, 1 aviso],
)

Teste manual no browser, depois da refatoração:

1. carregar um vídeo pelo Import: aparece a barra de progresso;
2. criar um projeto com um vídeo: aparece a barra de progresso (depois do commit `aba322d`);
3. aplicar brilho, pré-visualizar e processar: o resultado aparece.

As medições também funcionam como teste de regressão de ponta a ponta: 30 processamentos e pré-visualizações e 15 carregamentos terminaram com sucesso na versão final.

#pendente[acrescentar outros testes manuais feitos pelo grupo (imagens, partilha, legendagem automática, extração de fotogramas).]

= Validade das medições

Durante as medições encontrámos e corrigimos problemas nos scripts. Todas as correções estão em commits próprios e aplicam-se por igual à base e à final:

1. *`45e4c87`* — o script reinicia os serviços de upload antes de cada repetição; como o nginx guarda o IP antigo do gateway (secção 5), passou a reiniciar também o nginx e a esperar que a API responda.
2. *`78843bd`* — os resultados de M1/M2 passaram a ser gravados antes da M4, e os serviços são reiniciados antes da M4, porque um OOM na base deixava o gateway em baixo e perdia os resultados.
3. *`6e553e9`* — na elasticidade:
  - os logs dos contentores de vídeo passaram a ser recolhidos durante o ensaio, porque o autoscaler apaga as réplicas (e os seus logs) antes do fim;
  - cada projeto de pré-visualização usa um brilho ligeiramente diferente (1,21 a 1,30), porque pré-visualizações iguais acertavam na cache e nunca chegavam à fila;
  - as pré-visualizações passaram a ser identificadas pelo id da mensagem;
  - E2 passa a "não aplicável" quando os workers nunca mudam.

  A primeira medição final da elasticidade foi descartada por estes problemas e repetida. Na base nenhuma pré-visualização acertou na cache (as 10 chegaram ao worker), por isso a base não precisou de ser repetida; apenas o E3 foi recalculado a partir dos dados brutos.

*Limitações.*

- Um único portátil, sem swap; os valores absolutos dependem deste hardware.
- 5 repetições por tamanho em M1/M2, mas uma única execução de M3 e da elasticidade.
- A M1 por `memory.peak` inclui a cache de página (secção 3.4); a medição de memória dos processos é complementar e foi feita com uma única repetição.
- A M5 foi avaliada qualitativamente; não medimos as atualizações por segundo.

= Utilização de IA

#tabela(
  (1.2fr, 3.4fr),
  [Aspeto], [Descrição],
  [Ferramenta], [Claude Code (modelo Claude Opus 5.5, Anthropic), num terminal com acesso ao repositório e ao Docker local.],
  [Tarefas apoiadas], [Diagnóstico e análise dos RNF; scripts de medição (`medir.py`); os patches de refatoração (RNF-01 e RNF-02) com os respetivos testes; execução das medições de base e final; investigação das anomalias (OOM, 502 do nginx, cache de pré-visualizações, cache de página); correções aos scripts; correção do progresso na criação de projeto; rascunho deste relatório.],
  [Marcação no código], [O código escrito com IA tem o comentário "Written with AI assistance (Claude) and reviewed by the group (PL3-G7)"; os commits gerados têm a linha `Co-Authored-By: Claude`.],
  [Validação pela equipa], [#pendente[descrever o que o grupo reviu e como: leitura dos diffs, testes manuais no browser (M5 e regressão), confirmação dos números, decisões tomadas pelo grupo (escolha dos RNF, alvos, alternativas).]],
  [Erros da IA detetados], [O patch inicial do RNF-01 não ligava a barra de progresso à criação de projeto (detetado pelo grupo no teste manual). Os scripts de medição iniciais tinham os problemas da secção 7, detetados ao analisar resultados incoerentes.],
)

= Conclusão

O *RNF-01* atingiu o objetivo principal: um vídeo de 1 GB, que na base derrubava o sistema, passa a carregar com memória dos processos constante (≈ 190 MB) e com 4 carregamentos em paralelo. A rejeição acima do limite passou de 300 MB para 10,8 MB lidos, e o utilizador vê o progresso. O tempo de carregamento não melhorou: ficou ao nível da base.

O *RNF-02* introduziu elasticidade real (expansão e contração dentro dos alvos) e separou as pré-visualizações dos processamentos, reduzindo a espera p95 de 21 minutos para 30 segundos. O débito (E3) e a espera da pré-visualização (E4) ficaram abaixo do mínimo neste portátil, por saturação de CPU. O caminho para os cumprir está identificado: limitar o CPU das réplicas e escalar também as pré-visualizações.

#pendente[rever a conclusão, os alvos não atingidos e se o grupo quer ajustar algum valor-alvo na análise (justificando).]
