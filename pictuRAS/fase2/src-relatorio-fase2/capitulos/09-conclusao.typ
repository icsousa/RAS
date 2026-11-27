#import "../template.typ": *

= Conclusão

#tab([Síntese da avaliação],
  tabela(
    colunas: (2.4cm, 1fr, 3cm),
    [Métrica], [Resultado final], [Avaliação],
    [M1], [≈ 190 MB de memória dos processos para 1 GB (base: falha por OOM)], [#ok],
    [M2], [Ao nível da base; 1 GB passa a terminar], [#falha / #okmin],
    [M3], [4 carregamentos de 1 GB em paralelo (base: 0)], [#ok],
    [M4], [10,8 MB lidos antes de recusar (base: 300 MB)], [#ok],
    [M5], [Barra de progresso com percentagem], [#ok],
    [E1 / E2], [16,5 s / 70,4 s], [#ok],
    [E3], [1,87 × a base], [#falha],
    [E4], [30,4 s p95 (base: 1 258 s)], [#falha],
    [E5], [Mais 2 contentores leves em repouso], [#okmin],
  ),
)

O *RNF-01* atingiu o objetivo principal: um vídeo de 1 GB, que na base derrubava o sistema, passa a carregar com memória dos processos constante (≈ 190 MB) e com 4 carregamentos em paralelo. A rejeição acima do limite passou de 300 MB para 10,8 MB lidos, e o utilizador vê o progresso. O tempo de carregamento não melhorou: ficou ao nível da base, porque em loopback o custo do disco temporário anula o ganho de não copiar o ficheiro em memória.

O *RNF-02* introduziu elasticidade real (expansão e contração dentro dos alvos) e separou as pré-visualizações dos processamentos, reduzindo a espera p95 de 21 minutos para 30 segundos. O débito (E3) e a espera da pré-visualização (E4) ficaram abaixo do mínimo neste portátil, por saturação de CPU: as réplicas não têm quota de CPU e o worker de pré-visualização é um só. O caminho para os cumprir está identificado (limitar o CPU das réplicas e escalar também as pré-visualizações) e não foi aplicado para não alterar o método depois da medição.

Mantivemos os valores-alvo da análise sem os ajustar depois de medir: baixar E3 ou E4 nessa altura seria ajustar o requisito ao resultado. Os alvos não atingidos ficam registados como tais, com a causa e a correção proposta.

*Trabalho futuro:* Quota de CPU por réplica e autoscaler também na fila de pré-visualizações; proxy restrito para o `docker.sock`; `proxy_read_timeout` do nginx adequado a carregamentos grandes; resolução dinâmica do nome do gateway no nginx; medição do pico de disco temporário.
