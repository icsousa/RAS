#import "../template.typ": *

= Validade das medições

== Correções aos scripts

Durante as medições encontrámos e corrigimos problemas nos scripts. Todas as correções estão em commits próprios e aplicam-se por igual à base e à final:

+ *`45e4c87`* - o script reinicia os serviços de upload antes de cada repetição; como o nginx guarda o IP antigo do gateway (Capítulo 5), passou a reiniciar também o nginx e a esperar que a API responda.
+ *`78843bd`* - os resultados de M1/M2 passaram a ser gravados antes da M4, e os serviços são reiniciados antes da M4, porque um OOM na base deixava o gateway em baixo e perdia os resultados.
+ *`6e553e9`* - na elasticidade:
  - os logs dos contentores de vídeo passaram a ser recolhidos durante o ensaio, porque o autoscaler apaga as réplicas (e os seus logs) antes do fim;
  - cada projeto de pré-visualização usa um brilho ligeiramente diferente (1,21 a 1,30), porque pré-visualizações iguais acertavam na cache e nunca chegavam à fila;
  - as pré-visualizações passaram a ser identificadas pelo id da mensagem;
  - E2 passa a "não aplicável" quando os workers nunca mudam.

A primeira medição final da elasticidade foi descartada por estes problemas e repetida. Na base nenhuma pré-visualização acertou na cache (as 10 chegaram ao worker), por isso a base não precisou de ser repetida; apenas o E3 foi recalculado a partir dos dados brutos.

== Limitações

- Um único portátil, sem swap; os valores absolutos dependem deste hardware.
- 5 repetições por tamanho em M1/M2, mas uma única execução de M3 e da elasticidade.
- A M1 por `memory.peak` inclui a cache de página (Secção 3.6); a medição de memória dos processos é complementar e foi feita com uma única repetição.
- A M5 foi avaliada qualitativamente; não medimos as atualizações por segundo.
