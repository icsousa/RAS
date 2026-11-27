#import "../template.typ": *

= Decisões Arquiteturais

== DA-1 — Carregamento em streaming com validação antecipada (cenário QS-01)

#tab([Decisão arquitetural DA-1],
  tabela-campos(
    [Contexto], [Cada salto do carregamento guarda o vídeo inteiro em memória e o limite do perfil só é verificado no fim (EV-02 a EV-05); 1 GB provoca OOM do anfitrião e derruba o gateway (EV-16). Restrições: refactoring, a API, as mensagens de erro e os códigos HTTP têm de se manter.],
    [Tática(s) escolhida(s)], [TAT-01 (_streaming_), TAT-02 (validação antecipada) e TAT-05 (progresso no frontend)],
    [Estrutura / padrão que a realiza], [_Pipeline_ de _streams_ ao longo da cadeia existente: nginx sem _buffering_ → `api_gateway` em _pipe_ depois do token → `projects` com ficheiro temporário em disco → `img_storage` com `s3.upload` multipart],
    [Alternativas consideradas e razão de rejeição], [TAT-03: muda o fluxo e o contrato da API, obriga a expor o S3 pelo nginx e só valida depois do carregamento; risco alto para a fase. · TAT-04: não resolve, só adia o OOM; a memória continua proporcional ao tamanho e à concorrência. · TAT-06: classe C (carregamentos retomáveis são funcionalidade nova).],
    [Consequências positivas], [Memória dos processos constante (≈ 190 MB para 1 GB); 4 carregamentos de 1 GB em paralelo; recusa acima do limite com 10,8 MB lidos; pedido sem token deixa de obrigar a ler o corpo (QS-04); progresso visível.],
    [Consequências negativas / riscos], [Troca RAM por disco temporário e cache de página no `projects` e no `img_storage`; ficheiros temporários a limpar em caso de erro; o `proxy_read_timeout` de 60 s do nginx passa a ser o limite com muitos carregamentos em simultâneo.],
    [Elementos arquiteturais afetados], [`nginx/nginx.conf` (bloco `/api-gateway/`); `apiGateway/routes/projects.js` (rota de vídeo); `projects/utils/mediaUpload.js` (novo) e `projects/routes/projects.js`; `imageStorageService/route/upload.js` e `services/uploadImage.js`; `frontend/lib/projects.ts` e diálogos Import e criação de projeto],
    [Origem e âmbito do refactoring], [Interação: cadeia de carregamento do padrão global, aplicada ao caminho do vídeo. Risco de regressão médio (quatro serviços), mitigado por testes de limite, de hash e de nome duplicado (secção 10.5).],
    [Classe (A/B/C)], [A para TAT-01 e TAT-02 (comportamento externo igual: mesmos endpoints, mensagens e códigos); B para TAT-05 (a barra de progresso é a alteração visível que concretiza M5).],
    [Implementação (commits / pull requests)], [`5b2af25` (_streaming_ e validação), `aba322d` (barra de progresso também na criação de projeto), integrados no PR \#1 (`fase2/refatoracao`); patch `entrega-refatoracao/0002-Stream-video-uploads-end-to-end-RNF-01.patch`],
    [Desvios face à decisão], [O patch inicial só ligava a barra de progresso ao diálogo Import; a criação de projeto com media foi acrescentada em `aba322d`, depois do teste manual TM-02.],
  ),
)

*Alterações por salto na DA-1 (commit `5b2af25`).*

#{
  tabela(
    colunas: (3cm, 1fr),
    [Salto], [Alteração],
    [nginx], [`proxy_request_buffering off` e `proxy_http_version 1.1` no bloco `/api-gateway/`: o corpo passa à medida que chega.],
    [api_gateway], [Na rota de vídeo, o pedido é enviado por _pipe_ ao `projects`, sem multer. O token é verificado *antes* de ler qualquer byte do corpo.],
    [projects], [`utils/mediaUpload.js`: recusa pelo `Content-Length` quando o tamanho declarado só pode exceder o limite do perfil; caso contrário grava em ficheiro temporário (`multer.diskStorage`) com `limits.fileSize`, que interrompe a leitura ao passar o limite. O `ffprobe` e o hash correm sobre o ficheiro; o envio ao armazenamento é um _stream_. O temporário é apagado no fim e em caso de erro.],
    [img_storage], [Recebe em _stream_ e envia ao SeaweedFS com `s3.upload` em multipart.],
    [frontend], [`onUploadProgress` do axios e barra «Uploading N %» / «Processing…» no diálogo Import e na criação de projeto.],
  )
}

== DA-2 — Réplicas elásticas do worker de vídeo e fila de pré-visualização (cenário QS-02)

#tab([Decisão arquitetural DA-2],
  tabela-campos(
    [Contexto], [Um único `video_tool` com `prefetch=1` processa todos os vídeos; as pré-visualizações esperam atrás dos processamentos (EV-09, EV-12, EV-13); na base, 0,95 processamentos/min e 1 258 s de espera p95 (EV-17). Restrições: refactoring, mesmas mensagens e mesmo contrato com o `projects`; reproduzível com Docker Compose.],
    [Tática(s) escolhida(s)], [TAT-08 (_autoscaler_), TAT-09 (fila de pré-visualização) e TAT-11 (heartbeat e SIGTERM sem ack, para poder remover réplicas em segurança)],
    [Estrutura / padrão que a realiza], [Consumidores concorrentes elásticos (ALT-1): `video_autoscaler` que lê a fila e ajusta as réplicas do `video_tool` pela API do Docker; `video_preview_queue` com o serviço `video_preview_tool` (mesma imagem do worker)],
    [Alternativas consideradas e razão de rejeição], [TAT-07: é escalabilidade, não elasticidade; desperdiça recursos em repouso e não resolve a pré-visualização. · TAT-12: migrar o deploy para Kubernetes não é realista na fase e é difícil de reproduzir pelos docentes. · TAT-10: aceite na análise, mas não aplicado (ver desvios).],
    [Consequências positivas], [Expansão em 16,5 s e contração em 70,4 s; a pré-visualização deixa de esperar pelos processamentos (p95 de 1 258 s para 30,4 s); débito 1,87 × a base; trabalhos de réplicas removidas voltam à fila.],
    [Consequências negativas / riscos], [O `video_autoscaler` monta `/var/run/docker.sock` (controlo total do Docker do anfitrião); dois serviços novos para manter; as réplicas sem quota disputam o CPU com o worker de pré-visualização (H-02).],
    [Elementos arquiteturais afetados], [`rabbitMQ/definitions.json` (nova fila); `projects/utils/project_msg.js` (escolha da fila); `Tools/autoscaler/` (novo: `autoscaler.py`, `scaling_rule.py`, testes); `Tools/video/video.py`; `docker-compose.yaml` (`video_tool`, `video_preview_tool`, `video_autoscaler`, `stop_grace_period: 30s`)],
    [Origem e âmbito do refactoring], [Padrão do vídeo, dentro do padrão global (mais consumidores e mais uma fila). Risco de regressão médio: pré-visualização numa fila nova e remoção de réplicas a meio, cobertos por testes do `projects`, do _autoscaler_ e do worker.],
    [Classe (A/B/C)], [A: o comportamento funcional não muda (mesmos efeitos, mesmas mensagens); muda só a capacidade e a forma de escalonamento.],
    [Implementação (commits / pull requests)], [`3b8a8bd`, integrado no PR \#1; patch `entrega-refatoracao/0003-Make-video-processing-elastic-RNF-02.patch`. Regra de escala: expande de imediato até uma réplica por trabalho (`ready` + `unacked`), entre 1 e 4; contrai para 1 só depois de 60 s com a fila vazia, para nunca remover réplicas ocupadas; leitura a cada 5 s.],
    [Desvios face à decisão], [A análise previa réplicas com limite de CPU e memória (TAT-10) e o método do E3 falava em «4 réplicas com 1 CPU cada»; o `docker-compose.yaml` final não define `cpus` nem `mem_limit` e as réplicas partilham os 8 threads do portátil. O desvio foi identificado só depois da medição final e explica E3 e E4 (secção 10.4); não foi corrigido para não alterar o método depois de medir. O _autoscaler_ escala só a `video_queue`; a fila de pré-visualizações tem um worker fixo.],
  ),
)
