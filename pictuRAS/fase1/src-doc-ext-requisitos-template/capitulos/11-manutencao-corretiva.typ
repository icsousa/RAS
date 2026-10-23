#import "../template.typ": *

= Manutenção Corretiva da Solução de Base

Problemas encontrados na solução de base (`picturas-27`, _commit_ `781a63e`) durante o estudo e a integração do vídeo.

#tab([Tarefas de manutenção corretiva],
  tabela(
    colunas: (1.2cm, 1fr, 2.4cm, 1.6cm, 2.2cm, 1.8cm),
    tamanho: 8.5pt,
    [ID], [Descrição do problema], [Impacto], [Prioridade], [Rel. Req.], [Estado],
    [T-01], [Os erros das ferramentas de imagem nunca chegavam ao utilizador: em 12 ferramentas a chamada `send_msg` de erro tinha os argumentos deslocados (levantava uma exceção em vez de enviar), e em `ToolMSG` os campos `messageId`/`correlationId` da mensagem de erro estavam trocados, pelo que o `projects` não encontrava o pedido. O processamento ficava "a correr" para sempre.], [Funcional, Usabilidade], [Alta], [RF65 (erros), RNF43], [Corrigido],
    [T-02], [O `projects` lia `error.msg`, mas as ferramentas enviam `error.message`: a mensagem de erro chegava vazia ao browser.], [Usabilidade], [Média], [RF65], [Corrigido],
    [T-03], [O nginx não define `client_max_body_size` (por omissão 1 MB): pedidos de upload maiores são rejeitados com 413 antes de chegar ao gateway.], [Funcional], [Alta], [Carregar imagens; REQ-VID-SUBMIT-001], [Corrigido (512 MB em `/api-gateway/`)],
    [T-04], [O envio do `projects` para o `img_storage` usa o limite por omissão do axios (10 MB), pelo que ficheiros maiores falham.], [Funcional], [Alta], [REQ-VID-SUBMIT-001], [Corrigido],
    [T-05], [O serviço `users` chama o `projects` em `https://projects:10002/projects/` ao apagar uma conta, mas o `projects` escuta na porta 9001 e na raiz: os projetos de contas apagadas não eram removidos.], [Funcional, Privacidade (RGPD)], [Alta], [RF23, RNF38 (T-08 da _baseline_)], [Corrigido],
    [T-06], [`Tools/utils/env.py` lê `IMG_STORAGE_URL` da variável `RABBITMQ_PASSWORD` e as credenciais de `RABBITMQ_USERNAME`/`RABBITMQ_PASSWORD`, enquanto o compose define `RABBITMQ_USER`/`RABBITMQ_PASS`; só funciona porque os valores por omissão coincidem.], [Manutenção], [Baixa], [—], [Pendente],
    [T-07], [`Tools/utils/rabbit_mq.py` usa uma ligação bloqueante com `auto_ack`: tarefas longas impedem os _heartbeats_ (a ligação cai) e uma falha a meio perde a mensagem. O worker de vídeo usa uma ligação própria com _ack_ no fim.], [Fiabilidade], [Média], [RNF43], [Pendente (resolvido só no vídeo)],
    [T-08], [`projects/utils/rabbit_mq.js` abre uma ligação AMQP por mensagem e confirma (_ack_) a mensagem antes de o tratamento assíncrono terminar.], [Desempenho, Fiabilidade], [Média], [—], [Pendente (o vídeo usa `utils/videoQueue.js`)],
    [T-09], [Os certificados internos expiraram em janeiro de 2026 e todos os clientes usam `rejectUnauthorized: false` (assinalado no README da _baseline_): o tráfego interno é cifrado mas não autenticado.], [Segurança], [Média], [RNF44], [Pendente (Fase 2)],
  ),
)
