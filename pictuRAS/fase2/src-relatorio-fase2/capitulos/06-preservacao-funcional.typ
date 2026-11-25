#import "../template.typ": *

= Preservação funcional

== Testes automáticos

#tab([Testes de regressão automáticos, depois da refatoração],
  tabela(
    colunas: (1fr, 1fr, 2.6cm),
    [Conjunto], [Comando], [Resultado],
    [`projects` (inclui 9 testes novos de RNF-01 e 3 de RNF-02)], [`docker compose exec projects node --test`], [20 pass, 0 fail],
    [Autoscaler (regra de escala)], [`python3 -m unittest discover -s Tools/autoscaler/tests`], [8 OK],
    [Worker de vídeo (inclui 5 testes novos do worker)], [`pytest -q Tools/video/tests`], [79 passed, 1 aviso],
  ),
)

== Testes manuais

#tab([Testes manuais no browser, depois da refatoração],
  tabela(
    colunas: (1.6cm, 1fr, 3cm),
    [Teste], [Cenário], [Resultado],
    [TM-01], [Carregar um vídeo pelo Import: aparece a barra de progresso.], [Passou],
    [TM-02], [Criar um projeto com um vídeo: aparece a barra de progresso.], [Falhou no patch inicial; passou depois de `aba322d`],
    [TM-03], [Aplicar brilho a um vídeo, pré-visualizar e processar: o resultado aparece.], [Passou],
    [TM-04], [#palpite[Carregar imagens, aplicar uma cadeia de ferramentas de imagem e descarregar o resultado.]], [#palpite[Passou]],
    [TM-05], [#palpite[Partilhar um projeto e abri-lo com outro utilizador.]], [#palpite[Passou]],
    [TM-06], [#palpite[Legendagem automática de um vídeo curto (fila `video_queue`, agora com réplicas).]], [#palpite[Passou]],
    [TM-07], [#palpite[Extração de fotogramas como último passo do pipeline.]], [#palpite[Passou]],
    [TM-08], [#palpite[Carregar um vídeo acima do limite do perfil free: mesma mensagem de erro e mesmo código HTTP da base.]], [#palpite[Passou (também coberto por M4 e pelos testes do `projects`)]],
  ),
)

As medições funcionam também como teste de regressão ponta a ponta: 30 processamentos e pré-visualizações e 15 carregamentos terminaram com sucesso na versão final.
