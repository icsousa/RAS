#import "../template.typ": *

= Conclusão

O MVP valida que o PictuRAS consegue tratar vídeo de ponta a ponta sem alterar a sua natureza: o vídeo entra pelo mesmo projeto e pelas mesmas regras de perfil, é processado de forma assíncrona por um serviço dedicado e volta como uma nova versão, com estado e progresso visíveis e sem destruir o original. As cinco funcionalidades cobrem as dimensões que a extensão precisava de validar — temporal (recorte, velocidade), espacial ao longo do tempo (Pan & Crop), composição (legendas) e transformação de todos os fotogramas (cor) — e partilham uma base comum de submissão, trabalhos, quotas e versões especificada uma única vez.

*O que ficou por fazer.* A pré-visualização de LUT 3D e de gama no cliente (REQ-VID-COL-001 parcial), que exigiria _shaders_ WebGL; o encadeamento de ferramentas de vídeo e a aplicação de filtros por troços, deixados fora do âmbito do MVP; e o upload direto para o armazenamento, que retiraria o limite de 500 MB. Nos testes ponta a ponta todas as funcionalidades se comportaram como especificado, com uma exceção: a confirmação da submissão de um trabalho demora mais de 2 s (REQ-VID-PERF-001 não cumprido).

*Lições aprendidas.* A especificação feita por funcionalidade produziu regras repetidas e contraditórias (quotas, limites, falhas), que só a consolidação em requisitos transversais resolveu. Ler o código da _baseline_ antes de fixar as regras evitou um erro de especificação (o perfil Anónimo não tem contador de operações). E os testes com FFmpeg real revelaram problemas que a revisão de código não mostraria, como o bloqueio do FFmpeg sob limite de memória. #preencher[Lições da equipa.]

*Ligação à Fase 2.* Os requisitos não funcionais que consideramos prioritários para melhoria por _refactoring_ são:

- *Desempenho e escalabilidade do upload* (REQ-VID-SUBMIT-001, REQ-VID-PERF-001): upload direto para o S3 com URL assinado, sem passar o ficheiro em memória por três serviços.
- *Fiabilidade das mensagens* (REQ-VID-STATUS-001/005, T-07, T-08): uniformizar o acesso ao RabbitMQ (ligação persistente, _ack_ no fim do tratamento) em todos os serviços.
- *Segurança da comunicação interna* (T-09, RNF44): certificados válidos ou uma fronteira de rede de confiança.
- *Eficiência do processamento* (REQ-VID-TRIM-009, REQ-VID-TXT-006): aceleração por hardware e mais réplicas do `video_tool` com distribuição por tipo de operação.
