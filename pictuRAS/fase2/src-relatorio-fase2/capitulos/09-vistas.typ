#import "../template.typ": *

= Vista Arquitetural Antes e Depois

As duas vistas são diagramas de componentes do mesmo recorte da arquitetura (cadeia de carregamento e processamento de vídeo), com a mesma notação e a mesma escala (Graphviz; fontes em `diagramas/vista_antes.dot` e `diagramas/vista_depois.dot`). Os restantes serviços da Figura 1 não mudam e foram omitidos.

== Antes

#figure(
  image("../images/vista_antes.png", height: 10.5cm),
  caption: [Vista arquitetural antes das decisões DA-1 e DA-2],
) <fig-antes>

== Depois

#figure(
  image("../images/vista_depois.png", height: 12cm),
  caption: [Vista arquitetural depois das decisões DA-1 e DA-2],
) <fig-depois>

== Legenda e notas

*Legenda.* Verde, com contorno grosso: elemento ou interação novo ou alterado por uma tática, com o estereótipo «tática: …»; branco: elemento sem alterações; retângulo bege: fila do RabbitMQ; cilindro: armazenamento; componente cinzento: Docker Engine do anfitrião; linha tracejada: leitura de métricas ou controlo, não fluxo de dados.

*O que mudou e porquê.*

- *DA-1 (QS-01).* Os quatro saltos do carregamento passam de «receber tudo, depois enviar» a _stream_: o nginx deixa de bufferizar, o gateway verifica o token e faz _pipe_, o `projects` recusa cedo pelo `Content-Length` e trabalha sobre um ficheiro temporário, e o `img_storage` envia ao S3 em multipart. O frontend mostra o progresso. As setas entre os saltos são as mesmas: a API não mudou.
- *DA-2 (QS-02).* A fila única dá lugar a duas (`video_queue` para processamentos, `video_preview_queue` para pré-visualizações), cada uma com os seus consumidores. O `video_tool` passa de 1 instância fixa a 1–4 réplicas, criadas e removidas pelo novo `video_autoscaler`, que lê a profundidade da fila na API de gestão do RabbitMQ e comanda o Docker pelo `docker.sock`. O worker tem heartbeat ativo e devolve a mensagem à fila quando recebe SIGTERM.
