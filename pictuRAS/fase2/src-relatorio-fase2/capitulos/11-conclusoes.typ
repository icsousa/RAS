#import "../template.typ": *

= Conclusões e Recomendações

== Adequação do padrão atual (global e do vídeo)

O padrão global (microserviços com filas, orquestrador `projects` e _API Gateway_) mostrou-se adequado: as duas decisões foram implementadas *dentro* dele, sem mudar contratos nem a forma como os serviços comunicam. O padrão do vídeo (pipeline numa mensagem, ack no fim) também se mantém adequado; as fragilidades estavam nos pontos em que o vídeo herdou, sem adaptação, mecanismos pensados para imagens: a cadeia de carregamento com buffer em memória e um único consumidor numa fila partilhada. A comparação do capítulo 4 confirmou que evoluir para consumidores concorrentes elásticos (ALT-1) era a opção de menor custo e risco.

== Sugestões de otimização

- *Quota de CPU por réplica* (`cpus`), com núcleos reservados ao worker de pré-visualização (TAT-10), e *autoscaler também na* `video_preview_queue`: é o caminho identificado para cumprir E3 e E4.
- *`proxy_read_timeout`* do nginx adequado a carregamentos grandes, para que o limite de concorrência volte a ser a capacidade e não o _timeout_ (M3 com 8 em paralelo).
- *Proxy restrito para o `docker.sock`*, apenas com as operações de criar e remover réplicas do `video_tool`.
- *Resolução dinâmica do nome do gateway no nginx* e reinício automático dos serviços Node (QS-03, recomendação R-6).

== Considerações para evolução futura

O volume partilhado `image_data` prende o `projects` e todos os workers ao mesmo anfitrião (H-01). Enquanto a solução correr em Docker Compose num anfitrião isto é aceitável, mas impede escalar horizontalmente para vários anfitriões ou migrar para uma plataforma como a da ALT-3; a evolução natural é os workers lerem e escreverem diretamente no S3. Os workers de imagem continuam com `auto_ack` (H-03, R-7), o que contrasta com a robustez agora conseguida no vídeo.

== Trabalho futuro

*Ficou por fazer.* No CAND-1, a redução de 30 % no tempo de carregamento (M2) não foi atingida, porque em loopback o custo do disco temporário anula o ganho de não copiar o ficheiro em memória; a taxa de atualização do progresso e o pico de disco temporário não foram medidos. No CAND-2, o débito (1,87 × para um mínimo de 2 ×) e a espera da pré-visualização (30,4 s p95 para um alvo de 5 s) ficaram abaixo do mínimo por saturação de CPU. Mantivemos os valores-alvo sem os ajustar depois de medir: baixar E3 ou E4 nessa altura seria ajustar o requisito ao resultado. Ficam por confirmar H-01 e H-03, e o efeito combinado das duas decisões num pico simultâneo.

*Ligação à Fase 3.* O refactoring facilita a integração de novas funcionalidades de vídeo: novos efeitos continuam a entrar no `video_processor` e beneficiam automaticamente das réplicas elásticas; um novo tipo de trabalho com prioridade própria (por exemplo, legendagem longa) pode ganhar uma fila separada pelo mesmo mecanismo da `video_preview_queue`; e funcionalidades que exijam ficheiros maiores ou carregamentos retomáveis (TAT-06, hoje classe C) partem de uma cadeia que já não depende da memória.
