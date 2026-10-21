#import "../template.typ": *

= Introdução

== Propósito do incremento

O PictuRAS é uma aplicação web de edição de imagem com perfis Anónimo, Registado e Premium. Este incremento acrescenta suporte a vídeo digital numa lógica de MVP: o objetivo não é ainda um editor de vídeo de produção, mas validar de ponta a ponta que a aplicação consegue receber um vídeo, aplicar-lhe operações de edição demoradas de forma assíncrona e devolver uma nova versão, respeitando as regras de perfis e quotas já existentes.

Foram escolhidas cinco funcionalidades que, em conjunto, exercitam as principais dimensões do processamento de vídeo: a dimensão temporal (recorte e alteração de velocidade), a dimensão espacial ao longo do tempo (enquadramento dinâmico com _keyframes_), a composição de camadas (legendas e texto) e a transformação de todos os fotogramas (filtros de cor). A justificação de cada uma no contexto do MVP está no Capítulo 3.

== _Baseline_ e repositório

Este relatório *estende* os documentos de base; não os reescreve. Os elementos da _baseline_ são referidos pelos seus identificadores (UCnn, RFnn, RNFnn) apenas quando são alterados.

#tabela(
  colunas: (5cm, 1fr),
  [Artefacto], [Versão / referência],
  [Documento de requisitos de base], [doc-ext-requisitos.pdf (PictuRAS, Fase 1 de 2025/2026)],
  [Documento de solução arquitetural de base], [doc-sol-arquitetural.pdf],
  [Repositório de partida], [#link("https://github.com/picturas-um/picturas-27")[`github.com/picturas-um/picturas-27`] — _commit_ `781a63e`],
  [Solução entregue], [solucao-ext-mvp.zip — ramo `feature/video-mvp` #preencher[(URL do repositório do grupo e _commit_ final)]],
)

== Resumo do trabalho realizado

Foram especificados cinco casos de uso de vídeo (UC-VID-001 a UC-VID-005), com os respetivos requisitos funcionais e não funcionais, seis regras de negócio transversais e doze decisões de qualidade. Os requisitos comuns às várias funcionalidades — submissão e validação do vídeo, estado e cancelamento dos trabalhos de processamento, quotas e versões — foram especificados uma única vez. Foram atualizados o diagrama de casos de uso e o modelo de domínio, e foi analisado o impacto no sistema existente. As cinco funcionalidades foram implementadas sobre a arquitetura existente: um novo serviço de processamento (`video_tool`, FFmpeg), um módulo de vídeo no serviço `projects`, ajustes no API Gateway, WS Gateway, nginx e RabbitMQ, e uma página de vídeo no frontend (Capítulo 8). Foram ainda corrigidos cinco defeitos da _baseline_ encontrados durante a integração (Capítulo 11). A verificação assenta em 56 testes automáticos, todos a passar, e em 9 testes manuais ponta a ponta e de interface, dos quais um falha (tempo de resposta da submissão, REQ-VID-PERF-001; Capítulo 10). A utilização de agentes de IA e a respetiva validação estão no Capítulo 9. O estado de implementação de cada funcionalidade consta da Tabela do Capítulo 3 e o de cada requisito da Secção 7.3.

== Organização do documento

O documento está organizado em três partes:

- *Parte I — Enquadramento e visão transversal* (Capítulos 1 a 3): perfis e _stakeholders_ revistos para vídeo, lista de funcionalidades do MVP, diagrama de casos de uso, modelo de domínio e regras de negócio transversais.
- *Parte II — Especificação das funcionalidades de vídeo* (Capítulos 4 a 7): casos de uso, especificação de requisitos do sistema, impacto no sistema existente e rastreabilidade. Cada capítulo reúne todas as funcionalidades.
- *Parte III — Arquitetura, IA e validação* (Capítulos 8 a 12): alterações arquiteturais, utilização de agentes de IA, testes, manutenção corretiva da solução de base e conclusão.

Os anexos contêm as instruções de execução da solução e dos testes e o glossário.
