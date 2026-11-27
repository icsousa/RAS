#import "../template.typ": *

= Vista Arquitetural Antes e Depois

#orientacao[
  *Origem:* Exercício 7, secção 4 do _template_.

  Duas vistas do mesmo diagrama: *antes* e *depois* das decisões. Usem o tipo de diagrama que melhor mostrar a alteração
  (componentes, implantação ou sequência). Destaquem os elementos ou as interações introduzidos ou alterados pelas
  táticas (com um estereótipo `«tática: …»` ou uma cor) e incluam uma *legenda*.

  As duas vistas devem ser comparáveis: mesma notação, mesma escala e os mesmos elementos de contexto, de modo a que a
  diferença se perceba a olho. A legenda e as notas explicam o que mudou entre elas e porquê.
]

== Antes

#figure(kind: image,
  image("../images/vista_antes.png", height: 10cm),
  caption: [Vista arquitetural antes das decisões DA-1 e DA-2],
)

== Depois

#figure(kind: image,
  image("../images/vista_depois.png", height: 11.5cm),
  caption: [Vista arquitetural depois das decisões DA-1 e DA-2],
)

== Legenda e notas

Diagramas de componentes do mesmo recorte (carregamento e processamento de vídeo), com a mesma notação (Graphviz; fontes em `diagramas/vista_antes.dot` e `diagramas/vista_depois.dot`). *Legenda:* verde com contorno grosso, elemento ou interação novo ou alterado por uma tática, com o estereótipo «tática: …»; branco, sem alterações; retângulo bege, fila do RabbitMQ; cilindro, armazenamento; linha tracejada, leitura de métricas ou controlo.

*DA-1:* os quatro saltos passam de «receber tudo, depois enviar» a _stream_ (nginx sem _buffering_, gateway com _token_ e _pipe_, `projects` com recusa antecipada e ficheiro temporário, `img_storage` com _multipart_), e o frontend mostra o progresso; as ligações entre saltos não mudam. *DA-2:* a fila única dá lugar a duas (`video_queue` e `video_preview_queue`); o `video_tool` passa de 1 instância a 1–4 réplicas, criadas e removidas pelo novo `video_autoscaler` através do `docker.sock`; o _worker_ tem _heartbeat_ ativo e devolve a mensagem à fila ao receber SIGTERM.
