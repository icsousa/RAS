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
    [TM-04], [Carregar imagens, aplicar brilho, rotação e border, processar e descarregar o resultado.], [Passou],
    [TM-05], [Criar um link de partilha (View only) e abri-lo com outro utilizador: o projeto aparece com os efeitos.], [Passou],
    [TM-06], [Legendagem automática (perfil premium, `speech_mandela_177s_1080p.webm`): pré-visualização pelo `video_preview_tool` e processamento pelas réplicas do `video_tool`; legendas visíveis no resultado.], [Passou],
    [TM-07], [Corte seguido de extração de 10 fotogramas: os fotogramas refletem o corte e uma ferramenta depois da extração é recusada.], [Passou],
    [TM-08], [Perfil free: `too_long_90s.mp4` e `corrupted.mp4` são recusados com a mesma mensagem de erro e o mesmo código HTTP da base.], [Passou (também coberto por M4 e pelos testes do `projects`)],
  ),
)

As medições funcionam também como teste de regressão ponta a ponta: 30 processamentos e pré-visualizações e 15 carregamentos terminaram com sucesso na versão final.
