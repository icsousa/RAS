#import "../template.typ": *

= RNF-01 — Carregamento de ficheiros grandes

*Classificação ISO/IEC 25010:* eficiência de desempenho — utilização de recursos (memória) e comportamento temporal.

== Diagnóstico

Na base, um vídeo atravessa quatro saltos e cada um espera pelo ficheiro inteiro antes de o passar ao seguinte:

- o nginx guarda o pedido em disco temporário;
- o `apiGateway`, o `projects` e o `imageStorageService` usam `multer.memoryStorage()` e fazem cópias adicionais (`FormData`, ficheiro para o `ffprobe`, hash sobre o buffer).

O limite do perfil só é verificado depois de o ficheiro estar todo em memória, e o multer do gateway corre antes da verificação do token. O frontend não mostra progresso. A secção 2 da análise tem as referências ao código e a medição exploratória: cerca de 3 GB de RAM por salto para um ficheiro de 1 GB.

*Impacto para os stakeholders.* Um utilizador Premium não consegue carregar o vídeo de 1 GB que o seu plano permite; o serviço cai para todos os utilizadores; e quem carrega um vídeo grande não sabe se o carregamento está a avançar.

== Quantificação

*Enunciado.* O carregamento de um vídeo deve usar memória constante, independente do tamanho do ficheiro. O carregamento de um vídeo Premium de 1 GB não pode levar nenhum serviço a ficar sem memória. O utilizador deve ver o progresso do carregamento.

#tab([RNF-01: métricas, método, alvo e mínimo],
  tabela(
    colunas: (2.6cm, 2.8cm, 1fr, 2.2cm, 2cm),
    [Métrica], [Escala], [Método], [Alvo], [Mínimo],
    [M1 Pico de RAM adicional], [MB acima do repouso, soma dos 3 serviços], [100 MB, 500 MB e 1 GB, 5 repetições, mediana; serviços reiniciados antes de cada uma], [≤ 300 MB, sem crescer com o tamanho], [≤ 1 GB para 1 GB],
    [M2 Tempo ponta a ponta], [s, do POST até ao 204], [`curl` em loopback, 5 repetições], [≤ base − 30 %], [≤ base],
    [M3 Carregamentos de 1 GB em simultâneo], [N.º que termina com 204], [1, 2, 4 e 8 em paralelo; 2 GB por serviço], [4], [2],
    [M4 Rejeição acima do limite], [Bytes lidos antes do erro], [300 MB com perfil free (limite 100 MB)], [≤ limite + 1 MB], [≤ 2 × limite],
    [M5 Progresso visível], [Sim/Não], [Teste manual no browser, vídeo de 500 MB], [Sim, ≥ 1 atualização/s], [Sim],
  ),
)

*Origem dos valores.*

- O limite de 1 GB vem de `VIDEO_PREMIUM_MAX_SIZE_MB: 1024` no `docker-compose.yaml`.
- O alvo de M1 vem da medição exploratória: cerca de 90 MB por salto em streaming, vezes três saltos.
- *M3 = 4.* A análise previa que três carregamentos Premium de 1 GB em simultâneo bastassem para esgotar a memória do anfitrião na base (a medição oficial mostrou que até um só o faz). Fixámos o alvo acima desse ponto de rutura: 4 carregamentos de 1 GB com só 2 GB por serviço provam que a memória deixou de depender do tamanho do ficheiro (4 GB de dados a passar por um serviço com 2 GB). O mínimo de 2 corresponde ao dobro do que a base suporta no melhor caso (1). Não temos dados de utilização real; 4 é uma estimativa conservadora para o pico de Premium a carregar ao mesmo tempo num MVP académico.
- M2 e M4 são relativos à base ou ao limite do perfil, para não dependerem do hardware.

== Decisões arquiteturais

Foram avaliadas três alternativas (secção 3 da análise).

#tab([RNF-01: alternativas consideradas],
  tabela(
    colunas: (3cm, 1fr, 1fr),
    [Alternativa], [Vantagens], [Custos e riscos],
    [*A1 Streaming em todos os saltos (escolhida)*], [Memória constante; mantém a API e o contrato com o frontend; mudança localizada nos serviços envolvidos.], [Ficheiros temporários a limpar; pedidos abortados a tratar.],
    [A2 Carregamento direto para o S3 com URL pré-assinado], [O backend não toca no ficheiro; permite retomar.], [Muda o fluxo e o contrato da API; obriga a expor o S3; a validação só acontece depois do carregamento.],
    [A3 Carregamento por partes (estilo tus)], [Permite retomar; memória limitada pelo tamanho da parte.], [Mais código nos dois lados; aproxima-se de uma funcionalidade nova (retomar carregamentos).],
  ),
)

*Decisão:* A1, com progresso no frontend (`onUploadProgress` do axios, sem funcionalidade de negócio nova) e validação antecipada do `Content-Length` contra o limite do perfil. *Consequências:* troca-se RAM por disco temporário no `projects` (Capítulo 5) e o tempo de carregamento passa a depender também do disco.

== Refatoração

#tab([RNF-01: alterações por salto (commit `5b2af25`)],
  tabela(
    colunas: (3cm, 1fr),
    [Salto], [Alteração],
    [nginx], [`proxy_request_buffering off` e `proxy_http_version 1.1` no bloco `/api-gateway/`: o corpo passa à medida que chega.],
    [apiGateway], [Na rota de vídeo, o pedido é enviado por pipe ao `projects`, sem multer. O token é verificado *antes* de ler qualquer byte do corpo.],
    [projects], [Novo `utils/mediaUpload.js`: recusa pelo `Content-Length` quando o tamanho declarado só pode exceder o limite do perfil; caso contrário grava em ficheiro temporário (`multer.diskStorage`) com `limits.fileSize`, que interrompe a leitura ao passar o limite. O `ffprobe` e o hash correm sobre o ficheiro; o envio ao armazenamento é um stream. O ficheiro temporário é apagado no fim e em caso de erro. As mensagens de erro e os códigos HTTP mantêm-se.],
    [imageStorageService], [Recebe em stream e envia ao SeaweedFS com `s3.upload` em multipart.],
    [frontend], [`onUploadProgress` do axios e barra "Uploading N %" / "Processing…" no diálogo Import. O commit `aba322d` acrescentou a mesma barra à criação de projeto com media, que o patch inicial não cobria (detetado no teste manual).],
  ),
)

== Medição de base e final

#tab([RNF-01: base, final e avaliação],
  tabela(
    colunas: (3.2cm, 2.6cm, 2.6cm, 2.4cm, 1fr),
    [Métrica], [Base], [Final], [Alvo / mínimo], [Avaliação],
    [M1, 100 MB], [898 MB], [408 MB], [], [],
    [M1, 500 MB], [4 212 MB], [1 050 MB], [], [],
    [M1, 1 GB (`memory.peak`)], [0/5 com sucesso; ≈ 8 GB até ao OOM], [2 253 MB (5/5)], [≤ 300 MB / ≤ 1 GB], [ver análise],
    [M1, 1 GB (memória dos processos)], [—], [*≈ 190 MB*], [≤ 300 MB / ≤ 1 GB], [#ok],
    [M2, 100 MB], [3,0 s], [3,4 s], [≤ base − 30 % / ≤ base], [#falha (+12 %)],
    [M2, 500 MB], [14,2 s], [13,5 s], [≤ base − 30 % / ≤ base], [#okmin (−5 %)],
    [M2, 1 GB], [falha (502/504)], [25,5 s], [—], [passa a funcionar],
    [M3], [0], [*4*], [4 / 2], [#ok],
    [M4], [300 MB (400 ao fim de 5,1 s)], [*10,8 MB* (400 ao fim de 0,09 s)], [≤ 101 MB / ≤ 200 MB], [#ok],
    [M5], [Não (só um spinner)], [Sim (barra com percentagem)], [Sim], [#ok (atualizações/s não medidas)],
  ),
)

== Análise

- *Base, 1 GB.* As 5 repetições falharam (4 × 502, 1 × 504). O `journalctl` regista um *OOM global* do anfitrião: o kernel mata o `node` do `api_gateway`, que tinha cerca de 3 GB. O `nodemon` não relança o processo e o gateway fica em baixo até ser reiniciado. É exatamente a fragilidade que motivou o RNF-01. A memória extra cresce ≈ 8,5 vezes o tamanho do ficheiro (gateway 3,9 GB, projects 2,3 GB e storage 2,0 GB para 1 GB).
- *M1 final e cache de página.* O gateway ficou constante (45–68 MB). No `projects` e no `img_storage` o `memory.peak` ainda cresce ≈ 1,1 GB por GB de ficheiro, mas não é memória dos processos: é a cache de página do ficheiro temporário, que o cgroup contabiliza e o kernel pode libertar. Numa medição complementar (`resultados/final/rnf01_m1_anon.json`) separámos `anon` (memória dos processos) de `file` (cache) no `memory.stat`: para 1 GB, `anon` subiu 25 MB no gateway, 40 MB no projects e 125 MB no storage (≈ 190 MB no total), e `file` ≈ 1 GB em cada um dos dois últimos. A M3 confirma que esta cache não impede o funcionamento. Esta distinção não estava prevista no método da análise; fica registada como limitação do instrumento.
- *M2.* Em loopback não há rede lenta a esconder, e o streaming acrescenta escrita e leitura em disco no `projects`. O tempo fica ao nível da base (+12 % a 100 MB, −5 % a 500 MB) e não atinge a redução de 30 %. A melhoria real de M2 é que 1 GB passa a terminar.
- *M3 com 8 em paralelo.* Os 8 carregamentos devolveram 504 ao fim de ≈ 137 s, *sem* OOM. O nginx regista `upstream timed out … while reading response header`: o bloco `/api-gateway/` usa o `proxy_read_timeout` por omissão (60 s) e, com 8 GB a chegar ao mesmo tempo, o `projects` demora mais do que isso a responder depois de receber o corpo (`ffprobe`, hash e envio ao S3). O limite passou a ser o tempo, não a memória.
- *M4.* O `projects` recusa pelo `Content-Length` antes de ler o ficheiro: o `curl` só chegou a enviar 10,8 MB que já estavam em trânsito.
