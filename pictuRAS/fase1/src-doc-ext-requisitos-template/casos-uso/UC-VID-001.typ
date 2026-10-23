#import "../template.typ": *

// =============================================================================
//  CASO DE USO — UC-VID-001: Recorte temporal de vídeo (trim)
// =============================================================================

== UC-VID-001 — Recorte temporal de vídeo (trim)

=== Cabeçalho

#tab([Caso de uso UC-VID-001 — Recorte temporal de vídeo (trim)],
  tabela-campos(
    [ID do Caso de Uso], [UC-VID-001],
    [Nome], [Recorte temporal de vídeo (trim)],
    [Versão], [v1.1],
    [Autor], [Grupo PL3-G7],
    [Data], [2026-10-21],
    [Objetivo], [Isolar e extrair um segmento temporal contínuo de um ficheiro de vídeo através da seleção de pontos de início e fim.],
    [Âmbito], [Módulo de Edição Multimédia / Pipeline de Vídeo do PictuRAS],
    [Ator Principal], [Utilizador (qualquer perfil de autenticação)],
    [_Stakeholders_ e Interesses], [
      - *Utilizador*: Deseja extrair um excerto temporal específico do vídeo com precisão e rapidez, preservando o sincronismo audiovisual.
      - *Operador da Infraestrutura*: Deseja minimizar o consumo de recursos computacionais através da cópia direta de fluxos (_stream copy_) sem transcodificação completa quando viável.
      - *Equipa de Produto PictuRAS*: Garantir a aplicação consistente dos limites e quotas definidos para cada perfil de utilizador.
    ],
    [Pré-condições], [
      - Um ficheiro de vídeo suportado encontra-se carregado e validado no editor PictuRAS.
      - O sistema extraiu os metadados do vídeo (duração, resolução, taxa de fotogramas e mapa de _keyframes_).
      - O utilizador dispõe de quota de operações diárias não esgotada.
    ],
    [_Trigger_], [O utilizador seleciona a ferramenta "Recorte Temporal" no painel de ferramentas de vídeo.],
  ),
)

=== Fluxo Principal

#tab([UC-VID-001 — Fluxo principal],
  tabela(
    colunas: (1.2cm, 1fr, 1fr),
    [Passo], [Ação do Ator], [Resposta do Sistema],
    [1], [O utilizador aciona a ferramenta de recorte temporal.], [O sistema apresenta os controlos de corte na timeline com dois delimitadores interativos de início ($t_"in"$) e fim ($t_"out"$) e campos numéricos para introdução direta de tempo.],
    [2], [O utilizador ajusta as marcas $t_"in"$ e $t_"out"$ na timeline ou insere os valores nos campos numéricos.], [O sistema valida os limites inseridos, atualiza a pré-visualização do fotograma de corte em tempo real e calcula a duração útil do excerto resultante.],
    [3], [O utilizador solicita a pré-visualização do segmento selecionado.], [O sistema reproduz o segmento delimitado na janela do reprodutor.],
    [4], [O utilizador confirma a operação de recorte.], [O sistema valida as quotas do perfil, bloqueia a interface de edição e despacha a tarefa de recorte para a fila de processamento assíncrono.],
    [5], [—], [O serviço de processamento executa a extração do intervalo audiovisual selecionado, preservando a sincronização entre faixas.],
    [6], [—], [O sistema disponibiliza o vídeo resultante no espaço de trabalho do projeto, atualiza o histórico de operações, debita uma operação da quota diária quando aplicável (RNG-01) e restaura o controlo da interface.],
  ),
)

=== Fluxos Alternativos

#tab([UC-VID-001 — Fluxos alternativos],
  tabela(
    colunas: (4cm, 1fr),
    [Fluxo], [Descrição (passo de origem: condição -> comportamento -> retorno)],
    [FA1 – Corte Rápido em Keyframes (Stream Copy)], [No Passo 2, se o utilizador ativar a opção "Corte Rápido", o sistema ajusta automaticamente $t_"in"$ e $t_"out"$ para os _keyframes_ (I-frames) imediatamente adjacentes. No Passo 5, a extração é efetuada sem recodificação de vídeo (_codec copy_), diminuindo o tempo de processamento.],
    [FA2 – Cancelamento da Operação], [Em qualquer momento antes da confirmação no Passo 4, o utilizador clica em "Cancelar". O sistema descarta a seleção de marcadores temporais e restaura o vídeo ao estado inicial.],
  ),
)

=== Exceções

#tab([UC-VID-001 — Exceções],
  tabela(
    colunas: (1fr, 1fr),
    [Condição], [Comportamento do Sistema],
    [Marcadores temporais inconsistentes ($t_"in"$ >= $t_"out"$ ou duração < 0.5 s)], [O sistema impede a confirmação no Passo 4, destaca os campos numéricos a vermelho, exibe uma mensagem informativa a indicar que o instante de término deve ser superior ao de início e mantém o utilizador no Passo 2.],
    [Quota diária de operações esgotada], [No Passo 4, se o utilizador Registado já tiver esgotado o limite diário de operações, o sistema não cria a tarefa, informa quantas operações estão disponíveis e quando o limite é reposto e convida ao registo ou à atualização da conta. Os marcadores definidos mantêm-se e o vídeo original permanece intacto.],
    [Falha de sincronismo ou fluxo de vídeo corrompido durante a extração], [No Passo 5, caso o decodificador detete corrupção de fotogramas ou perda irrecuperável de alinhamento áudio/vídeo, a operação é abortada. O sistema notifica o utilizador da impossibilidade de processar o corte por anomalia no ficheiro, não debita a quota diária e repõe a visualização do vídeo pré-existente.],
  ),
)

=== Pós-condições

#tabela(
  colunas: (4cm, 1fr),
  [Tipo], [Resultado],
  [Garantia de Sucesso], [Uma nova versão do vídeo, recortada com duração correspondente a $t_"out"$ − $t_"in"$, fica disponível no projeto, derivada do vídeo de origem, que se mantém (RNG-05); os fluxos de áudio e vídeo mantêm-se sincronizados; a operação é deduzida na quota do utilizador quando aplicável.],
  [Garantia Mínima], [O ficheiro original mantém-se inalterado e desimpedido; nenhum ficheiro corrompido é gravado no projeto; a quota de operações do utilizador não sofre qualquer débito.],
)

=== Regras de Negócio e Restrições

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Regra],
  [RN1], [O vídeo a recortar respeita os limites de duração do perfil (RNG-04: Anónimo ≤ 60 s; Registado ≤ 300 s; Premium ≤ 3600 s), verificados na submissão; um excerto nunca excede a duração do vídeo de origem.],
  [RN2], [Duração mínima absoluta de um segmento recortado fixada em 0.5 segundos.],
  [RN3], [Precisão de corte: no modo com re-encoding a precisão deve ser ao fotograma (_frame-accurate_); no modo rápido sem perdas o corte é circunscrito aos limites de _keyframe_.],
  [RN4], [Consumo de quota: cada recorte concluído com sucesso conta como uma operação do limite diário do perfil (RNG-01); falhas e cancelamentos não contam.],
)

=== Assunções

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Assunção],
  [A1], [O serviço de processamento multimédia do PictuRAS tem acesso direto por sistema de ficheiros ou armazenamento partilhado ao vídeo original carregado.],
  [A2], [Os ficheiros de vídeo contêm tabela de metadados íntegra para identificação expedita das posições dos fotogramas-chave (_I-frames_).],
  [A3], [O navegador do cliente suporta a reprodução HTML5 dos formatos e codecs padrão gerados (MP4/H.264/AAC) para pré-visualização.],
)

=== Questões em Aberto

#tabela(
  colunas: (1.4cm, 1fr, 5cm),
  [ID], [Questão], [Resolução],
  [Q1], [O corte rápido em _keyframe_ deve constituir a predefinição com transição automática para re-encoding, ou o utilizador deve escolher expressamente o modo?], [Decidida → por omissão o corte é preciso (com recodificação); o corte rápido em _keyframes_ é uma opção explícita do utilizador (FA1). REQ-VID-TRIM-003, REQ-VID-TRIM-010.],
  [Q2], [O artefacto recortado deve sobrepor-se ao vídeo na sessão atual ou gerar uma versão derivada preservando o nó anterior para reversão direta?], [Decidida → é criada uma nova versão derivada; o vídeo de origem mantém-se e pode ser reposto. RNG-05, REQ-VID-RESULT-001, REQ-VID-RESULT-002.],
)