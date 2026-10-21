#import "../template.typ": *

#heading(numbering: none, outlined: false)[Histórico de versões]

#tabela(
  colunas: (1.5cm, 2.3cm, 1fr, 3.5cm),
  [Versão], [Data], [Alterações], [Autores],
  [v1.0], [2026-10-05], [Casos de uso UC-VID-001 a UC-VID-005, especificados por funcionalidade], [Grupo PL3-G7],
  [v1.1], [2026-10-07], [Especificação de requisitos, impacto e rastreabilidade por funcionalidade], [Grupo PL3-G7],
  [v1.2], [2026-10-20], [Consolidação: requisitos transversais, regras de negócio RNG-01 a RNG-06, resolução das questões em aberto, diagrama de casos de uso, modelo de domínio, impacto e rastreabilidade globais], [Grupo PL3-G7],
  [v1.3], [2026-10-21], [Implementação do MVP de vídeo: worker `video_tool` (FFmpeg) com as cinco operações, módulo de vídeo no serviço `projects`, integração no API Gateway, WS Gateway, nginx e RabbitMQ, página de vídeo no frontend e correção dos defeitos T-01 a T-05; 56 testes automáticos; Capítulos 7.3 e 8 a 12 e Anexo A], [Grupo PL3-G7],
  [v2.0], [2026-10-23], [Versão entregue da Fase 1], [Grupo PL3-G7],
)
